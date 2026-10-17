--!strict
-- OfficeService (server, Priority 20, owned by `offices`; docs/contracts.md §11, spec v3 §14).
-- One office instance per company present on this server: a branded lobby (floor 0) plus one floor per
-- department, cloned lazily from ServerStorage.FirmTemplates and placed at World.officeOrigin(index, floor).
-- Instance indices come from Logic/OfficeAlloc (freed indices are reused); floors nobody has been inside for
-- 3 minutes are destroyed, and the instance slot is freed with its last floor.
--
-- API (contracts §11):
--   OfficeService:EnterCompany(player, companyId, floor?, opts?) -> (ok, errKey?, message?)
--       floor = "lobby" (default) or a department (track id) the company runs. Unknown or not-yet-open companies
--       and floors fail with "opening_soon". Creates the instance/floor lazily and teleports (WorldService).
--       opts = { source = "door" | "directory" | "elevator" | "phone", entryAnchor = exterior anchor id?,
--                arrive = OfficeAnchor name? }
--   OfficeService:GetInstance(companyId) -> Model?          the instance (attribute CompanyId), floors inside
--   OfficeService:GetFloor(companyId, trackId | "lobby") -> Model?   attributes CompanyId, Department, LightingPreset
--   OfficeService:GetPlayerLocation(player) -> { companyId, floor }?
--   OfficeService.FloorCreated : Signal(companyId, trackId | "lobby", model)
--   OfficeService.FloorRemoved : Signal(companyId, trackId | "lobby")
-- Extras:
--   OfficeService.LocationChanged : Signal(player, location?)
--   OfficeService:GetCompany(companyId) -> Company?          normalized Config/Companies entry (OfficeAlloc)
--   OfficeService:GetDirectory() -> { Entry }                what the Directory screen shows
--   OfficeService:IsAvailable(companyId, floor?) -> boolean
--   OfficeService:GetCompanyAt(instance) -> (companyId?, floor?)   for any part inside an office instance
--   OfficeService:GetLocationAt(position) -> (companyId?, floor?)  the live floor at a world position
--   OfficeService:GetAnchor(companyId, floor, name) -> BasePart?   OfficeAnchor marker on a live floor
--   OfficeService:GetBossName(companyId, trackId) -> string   the name the boss NPC wears
--   OfficeService:GetBossNpc(companyId, trackId) -> Model?
--   OfficeService:ResolveExit(player, companyId) -> anchorId  where the lobby "exit" door leads this player
--   OfficeService:SetPickerContext(player, doorId, tenants, anchorId?)   WorldService, when a tower picker opens
--   OfficeService:EnterFromRemote(player, companyId, floor?) / :RideElevator(player, floor)   remote entry points
-- Remotes: see OfficeService/Remotes ("Office.Enter", "Office.Elevator", "Office.Directory", "Office.OpenElevator",
-- "Office.OpenDirectory"). Interacts owned here: `elevator_panel` (lobby) and `company_directory` (street kiosks),
-- wired in OfficeService/Prompts.
-- Player attributes set here: OfficeCompany, OfficeFloor (the office the player is standing in).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Time = require(Shared.Util.Time)
local World = require(Shared.Config.World)
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)
local DoorRules = require(Shared.Logic.DoorRules)
local Registry = require(script.Parent.Parent.Registry)
local Catalog = require(script.Catalog)
local Template = require(script.Template)
local Npcs = require(script.Npcs)
local Prompts = require(script.Prompts)
local Remotes = require(script.Remotes)

local Text = DoorRules.Text
local LOBBY = OfficeAlloc.LOBBY

local OfficeService = {
	Name = "OfficeService",
	Priority = 20,
	FloorCreated = Signal.new(),
	FloorRemoved = Signal.new(),
	LocationChanged = Signal.new(),
}

OfficeService.Template = Template
OfficeService.Npcs = Npcs
OfficeService.Catalog = Catalog

local POLL_EVERY = 1
local PICKER_TTL = 120
local OPEN_COOLDOWN = 0.75
local ROOT_NAME = "Offices"
local ARRIVE_LIFT = Vector3.new(0, 0.25, 0)
local STAIRS_DELAY = 3
local ARRIVAL_FALLBACKS = { "entry", "floor_entry", "elevators", "review_spot" }

export type Location = { companyId: string, floor: string }
export type EnterOpts = { source: string?, entryAnchor: string?, arrive: string? }

type FloorState = {
	key: string,
	companyId: string,
	floor: string,
	floorIndex: number,
	model: Model,
	anchors: { [string]: BasePart },
	rec: OfficeAlloc.FloorRec,
	alive: boolean,
}
type InstanceState = { companyId: string, index: number, model: Model, floors: { [string]: FloorState } }
type Picker = { doorId: string, tenants: { [string]: boolean }, anchor: string?, at: number }

local alloc = OfficeAlloc.new()
local instances: { [string]: InstanceState } = {}
local floorRecs: { [string]: OfficeAlloc.FloorRec } = {}
local floorsByKey: { [string]: FloorState } = {}
local locations: { [Player]: Location } = {}
local memory: { [Player]: DoorRules.Memory } = {}
local pickers: { [Player]: Picker } = {}
local lastOpen: { [Player]: number } = {}
local rootFolder: Folder? = nil
local warnedAnchors: { [string]: boolean } = {}

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
local function root(): Folder
	local f = rootFolder
	if f and f.Parent then
		return f
	end
	local existing = workspace:FindFirstChild(ROOT_NAME)
	if existing and existing:IsA("Folder") then
		rootFolder = existing
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = ROOT_NAME
	created.Parent = workspace
	rootFolder = created
	return created
end

local function isLive(player: Player): boolean
	return player.Parent == Players
end

local function rootPart(player: Player): BasePart?
	local char = player.Character
	local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

-- Runs fn in a pcall and logs a failure (fn returns nothing, so the error is the only second value).
local function safely(label: string, fn: () -> ())
	local ok, err = pcall(function(): string?
		fn()
		return nil
	end)
	if not ok then
		warn(("[OfficeService] %s failed: %s"):format(label, tostring(err)))
	end
end

local function notify(player: Player, text: string, kind: string?)
	local ns = Registry.get("NotifyService")
	if ns and type(ns.Notify) == "function" then
		safely("NotifyService:Notify", function()
			ns:Notify(player, text, kind)
		end)
	end
end

local function eventActive(eventId: string): boolean
	local es = Registry.get("EventService")
	if es and type(es.IsActive) == "function" then
		local ok, active = pcall(function()
			return es:IsActive(eventId)
		end)
		return ok and active == true
	end
	return false
end

-- (companyId, floor) of the live floor at a world position.
local function locate(pos: Vector3): (string?, string?)
	local i, f = World.officeAt(pos)
	if i == nil or f == nil then
		return nil, nil
	end
	local companyId = OfficeAlloc.companyAt(alloc, i)
	local inst = if companyId then instances[companyId] else nil
	if not inst then
		return nil, nil
	end
	for floorId, fs in inst.floors do
		if fs.floorIndex == f and fs.alive then
			return inst.companyId, floorId
		end
	end
	return nil, nil
end

local function setLocation(player: Player, loc: Location?)
	local old = locations[player]
	local same = (old == nil and loc == nil)
		or (old ~= nil and loc ~= nil and old.companyId == loc.companyId and old.floor == loc.floor)
	if same or not isLive(player) then
		return
	end
	if loc then
		locations[player] = loc
	else
		locations[player] = nil
	end
	player:SetAttribute("OfficeCompany", if loc then loc.companyId else nil)
	player:SetAttribute("OfficeFloor", if loc then loc.floor else nil)
	OfficeService.LocationChanged:Fire(player, if loc then table.clone(loc) else nil)
end

local function currentLocation(player: Player): Location?
	local hrp = rootPart(player)
	if not hrp then
		return nil
	end
	local c, f = locate(hrp.Position)
	if c and f then
		return { companyId = c, floor = f }
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- Instances and floors
---------------------------------------------------------------------------------------------------
local function releaseInstance(inst: InstanceState)
	if instances[inst.companyId] == inst then
		instances[inst.companyId] = nil
	end
	inst.model:Destroy()
	OfficeAlloc.release(alloc, inst.companyId)
end

local function removeFloor(key: string)
	local fs = floorsByKey[key]
	floorsByKey[key] = nil
	floorRecs[key] = nil
	if not fs then
		return
	end
	fs.alive = false
	local inst = instances[fs.companyId]
	if inst and inst.floors[fs.floor] == fs then
		inst.floors[fs.floor] = nil
	end
	fs.model:Destroy()
	OfficeService.FloorRemoved:Fire(fs.companyId, fs.floor)
	if inst and next(inst.floors) == nil then
		releaseInstance(inst)
	end
end

local function ensureInstance(company: OfficeAlloc.Company): (InstanceState?, string?)
	local inst = instances[company.id]
	if inst and inst.model.Parent then
		return inst, nil
	elseif inst then
		-- something destroyed the instance model behind our back: drop its floors and start over
		local keys: { string } = {}
		for _, fs in inst.floors do
			table.insert(keys, fs.key)
		end
		for _, key in keys do
			removeFloor(key)
		end
		if instances[company.id] == inst then
			releaseInstance(inst)
		end
	end
	local index = OfficeAlloc.acquire(alloc, company.id)
	if index == nil then
		return nil, "full"
	end
	local model = Instance.new("Model")
	model.Name = "Office_" .. company.id
	model:SetAttribute("CompanyId", company.id)
	model:SetAttribute("CompanyName", company.name)
	model:SetAttribute("InstanceIndex", index)
	model.Parent = root()
	local fresh: InstanceState = { companyId = company.id, index = index, model = model, floors = {} }
	instances[company.id] = fresh
	return fresh, nil
end

local function liveFloorCount(): number
	local n = 0
	for _ in floorsByKey do
		n += 1
	end
	return n
end

local function spawnNpcs(fs: FloorState, company: OfficeAlloc.Company)
	local track = Catalog.get().tracks[fs.floor]
	local ctx: Npcs.Ctx = {
		model = fs.model,
		company = company,
		floor = fs.floor,
		departmentName = Catalog.departmentName(fs.floor),
		bossTitle = if track then track.topTitle else nil,
		anchors = fs.anchors,
		liveFloors = liveFloorCount(),
		alive = function(): boolean
			return fs.alive and fs.model.Parent ~= nil
		end,
	}
	task.spawn(function()
		safely(("office NPCs for %s/%s"):format(company.id, fs.floor), function()
			Npcs.populate(ctx)
		end)
	end)
end

local function ensureFloor(company: OfficeAlloc.Company, floor: string): (FloorState?, string?)
	local key = OfficeAlloc.floorKey(company.id, floor)
	local existing = floorsByKey[key]
	if existing and existing.alive and existing.model.Parent then
		existing.rec.lastOccupied = math.max(existing.rec.lastOccupied, Time.now())
		return existing, nil
	elseif existing then
		removeFloor(key) -- something destroyed it behind our back
	end
	local floorIndex = OfficeAlloc.floorIndex(company.departments, floor)
	if floorIndex == nil then
		return nil, "no_floor"
	end
	local template = Catalog.template(floor)
	if not template then
		return nil, "opening_soon"
	end
	local inst, err = ensureInstance(company)
	if not inst then
		return nil, err
	end

	local ok, cloned = pcall(function()
		return template:Clone()
	end)
	if not ok or typeof(cloned) ~= "Instance" then
		warn(("[OfficeService] couldn't clone template %s: %s"):format(floor, tostring(cloned)))
		if next(inst.floors) == nil then
			releaseInstance(inst)
		end
		return nil, "error"
	end
	local model: Model
	if cloned:IsA("Model") then
		model = cloned
	else
		model = Instance.new("Model")
		cloned.Parent = model
	end
	model.Name = if floor == LOBBY then "Lobby" else "Floor_" .. floor

	safely(("branding %s/%s"):format(company.id, floor), function()
		Template.prepare(model, company, floor, Catalog.logos())
	end)
	model:SetAttribute("InstanceIndex", inst.index)
	model:SetAttribute("FloorIndex", floorIndex)
	-- Streamed as one unit, so a client never sees half a floor (and anchors arrive with their room).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- Templates are baked around the world origin: shift the clone's pivot (PrimaryPart-relative, rotation kept)
	-- by this instance/floor's origin.
	local origin = World.officeOrigin(inst.index, floorIndex)
	model:PivotTo(CFrame.new(origin) * model:GetPivot())
	local anchors = Template.anchors(model)
	model.Parent = inst.model

	local rec = OfficeAlloc.newFloor(company.id, floor, Time.now())
	local fs: FloorState = {
		key = key,
		companyId = company.id,
		floor = floor,
		floorIndex = floorIndex,
		model = model,
		anchors = anchors,
		rec = rec,
		alive = true,
	}
	floorsByKey[key] = fs
	floorRecs[key] = rec
	inst.floors[floor] = fs

	OfficeService.FloorCreated:Fire(company.id, floor, model)
	spawnNpcs(fs, company)
	return fs, nil
end

local function flat(cf: CFrame): CFrame
	local lv = cf.LookVector
	local f = Vector3.new(lv.X, 0, lv.Z)
	if f.Magnitude < 1e-3 then
		return CFrame.new(cf.Position)
	end
	return CFrame.lookAt(cf.Position, cf.Position + f.Unit)
end

local function arrivalCFrame(fs: FloorState, name: string): CFrame
	local anchor = fs.anchors[name]
	if not (anchor and anchor.Parent) then
		anchor = nil
		for _, alt in ARRIVAL_FALLBACKS do
			local a = fs.anchors[alt]
			if a and a.Parent then
				anchor = a
				break
			end
		end
	end
	if anchor then
		return flat(anchor.CFrame) + ARRIVE_LIFT
	end
	local warnKey = fs.floor .. "/" .. name
	if not warnedAnchors[warnKey] then
		warnedAnchors[warnKey] = true
		warn(("[OfficeService] template %s has no OfficeAnchor %q; arriving at the floor origin"):format(fs.floor, name))
	end
	local index = OfficeAlloc.indexOf(alloc, fs.companyId) or 1
	return CFrame.new(World.officeOrigin(index, fs.floorIndex) + Vector3.new(0, 5, 0))
end

---------------------------------------------------------------------------------------------------
-- Entering
---------------------------------------------------------------------------------------------------
local function errorText(errKey: string?, company: OfficeAlloc.Company?, floor: string?): string
	if errKey == "opening_soon" then
		if company and floor and floor ~= LOBBY then
			return Text.format("floor_opening_soon", { department = Catalog.departmentName(floor) })
		end
		return if company then Text.format("opening_soon_named", { name = company.name }) else Text.get("unknown_company")
	elseif errKey == "no_floor" then
		return Text.format("no_floor", { name = if company then company.name else "" })
	elseif errKey == "full" then
		return Text.get("offices_full")
	elseif errKey == "cooldown" then
		return Text.get("tp_cooldown")
	elseif errKey == "busy" then
		return Text.get("tp_busy")
	elseif errKey == "no_character" then
		return Text.get("tp_no_character")
	elseif errKey == "not_in_office" then
		return Text.get("not_in_office")
	end
	return Text.get("tp_failed")
end

local function worldService(): any
	return Registry.get("WorldService")
end

local function teleport(player: Player, cf: CFrame, opts: { [string]: any }): (boolean, string?)
	local world = worldService()
	if world and type(world.Teleport) == "function" then
		local ok, a, b = pcall(function()
			return world:Teleport(player, cf, opts)
		end)
		if not ok then
			warn("[OfficeService] WorldService:Teleport errored: " .. tostring(a))
			return false, "error"
		end
		if a == true then
			return true, nil
		end
		return false, if type(b) == "string" then b else "error"
	end
	-- No WorldService: a plain, streaming-safe move.
	local char = player.Character
	if not char or not rootPart(player) then
		return false, "no_character"
	end
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 5)
	end)
	if not isLive(player) or player.Character ~= char or char.Parent == nil then
		return false, "no_character"
	end
	char:PivotTo(cf)
	return true, nil
end

function OfficeService:EnterCompany(
	player: Player,
	companyId: string,
	floor: string?,
	opts: EnterOpts?
): (boolean, string?, string?)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not isLive(player) then
		return false, "no_player", Text.get("tp_failed")
	end
	local o: EnterOpts = opts or {}
	local cat = Catalog.get()
	local company = Catalog.company(companyId)
	local target = floor or LOBBY
	if not company or not OfficeAlloc.isAvailable(company, cat.templates, cat.tracks) then
		return false, "opening_soon", errorText("opening_soon", company, nil)
	end
	if target ~= LOBBY then
		if not table.find(company.departments, target) or OfficeAlloc.floorIndex(company.departments, target) == nil then
			return false, "no_floor", errorText("no_floor", company, target)
		end
		if not OfficeAlloc.floorOpen(company, target, cat.templates, cat.tracks) then
			return false, "opening_soon", errorText("opening_soon", company, target)
		end
	end
	local world = worldService()
	if world and type(world.CanTeleport) == "function" then
		local ok, can, why = pcall(function()
			return world:CanTeleport(player)
		end)
		if ok and can == false then
			local key = if type(why) == "string" then why else "busy"
			return false, key, errorText(key, company, target)
		end
	end

	local fs, err = ensureFloor(company, target)
	if not fs then
		return false, err, errorText(err, company, target)
	end
	local defaultArrive = if target == LOBBY
		then (if o.source == "elevator" then "elevators" else "entry")
		else "floor_entry"
	local arrive: string = o.arrive or defaultArrive
	local cf = arrivalCFrame(fs, arrive)

	local tpOpts: { [string]: any } = {
		label = company.name,
		sublabel = Catalog.departmentName(target),
		reason = "office",
	}
	if o.source == "elevator" and eventActive("elevator_outage") then
		notify(player, Text.get("elevator_outage"), "warn")
		tpOpts.delay = STAIRS_DELAY
		tpOpts.message = Text.get("tp_stairs")
	end
	local ok, terr = teleport(player, cf, tpOpts)
	if not ok then
		return false, terr, errorText(terr, company, target)
	end
	if not isLive(player) then
		return false, "no_player", nil
	end
	fs.rec.lastOccupied = Time.now()
	-- Remember where the player came in from the Street (the lobby "exit" door leads back there).
	if o.entryAnchor then
		memory[player] = { companyId = company.id, anchor = o.entryAnchor }
	elseif o.source ~= "elevator" then
		memory[player] = { companyId = company.id, anchor = nil }
	end
	setLocation(player, { companyId = company.id, floor = target })
	return true, nil, nil
end

-- Office.Enter (Directory / Phone / tower picker). Students without street access stay on campus.
function OfficeService:EnterFromRemote(player: Player, companyId: string, floor: string?): (boolean, string?, string?)
	local world = worldService()
	if world and type(world.CanReachStreet) == "function" then
		local ok, can, text = pcall(function()
			return world:CanReachStreet(player)
		end)
		if ok and can == false then
			return false, "locked", if type(text) == "string" then text else Text.get("locked_flag")
		end
	end
	local pick = pickers[player]
	local entryAnchor: string? = nil
	if pick and Time.now() - pick.at <= PICKER_TTL and pick.tenants[companyId] then
		entryAnchor = pick.anchor
	end
	local ok, err, message = self:EnterCompany(player, companyId, floor, {
		source = if entryAnchor then "door" else "directory",
		entryAnchor = entryAnchor,
	})
	if ok and pick and pickers[player] == pick then
		pickers[player] = nil
	end
	return ok, err, message
end

-- Office.Elevator: ride to another floor of the office the player is standing in (visitors included).
function OfficeService:RideElevator(player: Player, floor: string): (boolean, string?, string?)
	local loc = currentLocation(player) or locations[player]
	if not loc then
		return false, "not_in_office", errorText("not_in_office", nil, nil)
	end
	if loc.floor == floor then
		return true, nil, nil
	end
	return self:EnterCompany(player, loc.companyId, floor, { source = "elevator" })
end

---------------------------------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------------------------------
function OfficeService:GetInstance(companyId: string): Model?
	local inst = instances[companyId]
	return if inst and inst.model.Parent then inst.model else nil
end

function OfficeService:GetFloor(companyId: string, trackId: string): Model?
	local fs = floorsByKey[OfficeAlloc.floorKey(companyId, trackId)]
	return if fs and fs.alive then fs.model else nil
end

function OfficeService:GetPlayerLocation(player: Player): Location?
	local loc = locations[player]
	return if loc then table.clone(loc) else nil
end

function OfficeService:GetCompany(companyId: string): OfficeAlloc.Company?
	return Catalog.company(companyId)
end

function OfficeService:GetDirectory(): { OfficeAlloc.Entry }
	return Catalog.get().directory
end

function OfficeService:IsAvailable(companyId: string, floor: string?): boolean
	local cat = Catalog.get()
	local company = Catalog.company(companyId)
	if not company then
		return false
	end
	return OfficeAlloc.floorOpen(company, floor or LOBBY, cat.templates, cat.tracks)
end

function OfficeService:GetCompanyAt(inst: Instance): (string?, string?)
	if typeof(inst) ~= "Instance" then
		return nil, nil
	end
	return Prompts.companyOf(inst)
end

function OfficeService:GetLocationAt(position: Vector3): (string?, string?)
	if typeof(position) ~= "Vector3" then
		return nil, nil
	end
	return locate(position)
end

function OfficeService:GetAnchor(companyId: string, floor: string, name: string): BasePart?
	local fs = floorsByKey[OfficeAlloc.floorKey(companyId, floor)]
	if not fs or not fs.alive then
		return nil
	end
	local a = fs.anchors[name]
	return if a and a.Parent then a else nil
end

function OfficeService:GetBossName(companyId: string, trackId: string): string
	local company = Catalog.company(companyId)
	if not company then
		return Text.bossNames[1]
	end
	return Npcs.bossName(company, trackId)
end

function OfficeService:GetBossNpc(companyId: string, trackId: string): Model?
	local fs = floorsByKey[OfficeAlloc.floorKey(companyId, trackId)]
	if not fs or not fs.alive then
		return nil
	end
	local folder = fs.model:FindFirstChild(Npcs.FOLDER)
	if not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OfficeNpc") == "boss" then
			return m
		end
	end
	return nil
end

function OfficeService:ResolveExit(player: Player, companyId: string): string
	return DoorRules.resolveExit(memory[player], companyId)
end

function OfficeService:SetPickerContext(player: Player, doorId: string, tenants: { string }, anchor: string?)
	if not isLive(player) then
		return
	end
	local set: { [string]: boolean } = {}
	for _, id in tenants do
		set[id] = true
	end
	pickers[player] = { doorId = doorId, tenants = set, anchor = anchor, at = Time.now() }
end

---------------------------------------------------------------------------------------------------
-- Interact prompts (elevator_panel, company_directory)
---------------------------------------------------------------------------------------------------
local function onPromptTriggered(player: Player, interactId: string, inst: Instance, _prompt: ProximityPrompt)
	if not isLive(player) then
		return
	end
	local now = os.clock()
	if now - (lastOpen[player] or -math.huge) < OPEN_COOLDOWN then
		return
	end
	lastOpen[player] = now
	if interactId == "company_directory" then
		Remotes.openDirectory(player, { source = "kiosk" })
		return
	end
	local companyId, dept = Prompts.companyOf(inst)
	local company = Catalog.company(companyId)
	if not company then
		notify(player, Text.get("not_in_office"), "warn")
		return
	end
	local loc = currentLocation(player) or locations[player]
	local current = dept or (if loc and loc.companyId == company.id then loc.floor else LOBBY)
	Remotes.openElevator(player, Catalog.elevatorPayload(company, current, eventActive("elevator_outage")) :: any)
end

---------------------------------------------------------------------------------------------------
-- Occupancy and cleanup
---------------------------------------------------------------------------------------------------
local function poll()
	local occupied: { [string]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local loc = currentLocation(player)
		if loc then
			occupied[OfficeAlloc.floorKey(loc.companyId, loc.floor)] = true
		end
		setLocation(player, loc)
	end
	for _, key in OfficeAlloc.sweep(floorRecs, occupied, Time.now()) do
		removeFloor(key)
	end
end

local function onPlayerRemoving(player: Player)
	local had = locations[player] ~= nil
	locations[player] = nil
	memory[player] = nil
	pickers[player] = nil
	lastOpen[player] = nil
	if had then
		OfficeService.LocationChanged:Fire(player, nil)
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function OfficeService:Init()
	root()
	Remotes.bind(OfficeService)
end

function OfficeService:Start()
	Catalog.get()
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Prompts.start(onPromptTriggered, function(companyId: string): string?
		local c = Catalog.company(companyId)
		return if c then c.name else nil
	end)
	while true do
		task.wait(POLL_EVERY)
		safely("occupancy poll", poll)
	end
end

return OfficeService
