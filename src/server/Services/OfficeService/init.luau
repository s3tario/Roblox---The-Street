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
--   OfficeService:GetAnchor(companyId, floor, name) -> BasePart?   OfficeAnchor marker on a live floor
--   OfficeService:GetBossName(companyId, trackId) -> string   the name the boss NPC wears
--   OfficeService:GetBossNpc(companyId, trackId) -> Model?
--   OfficeService:ResolveExit(player, companyId) -> anchorId  where the lobby "exit" door leads this player
--   OfficeService:SetPickerContext(player, doorId, tenants, anchorId)   WorldService, when a tower picker opens
-- Remotes (RemoteFunctions, Guard-validated):
--   "Office.Enter"(companyId, floor?) -> ok, errKey?, message?      Directory screen / Phone
--   "Office.Elevator"(trackId | "lobby") -> ok, errKey?, message?   lobby elevator panel (visitors may ride)
--   "Office.Directory"() -> { Entry }                                companies with availability
-- Interacts owned here: `elevator_panel` (lobby) and `company_directory` (street kiosks) get ProximityPrompts
-- (attribute InteractId); OfficeController opens the Elevator / Directory screen when they trigger.
-- Player attributes set here: OfficeCompany, OfficeFloor (the office the player is standing in).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local Signal = require(Shared.Util.Signal)
local Time = require(Shared.Util.Time)
local World = require(Shared.Config.World)
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)
local DoorRules = require(Shared.Logic.DoorRules)
local Registry = require(script.Parent.Parent.Registry)
local Template = require(script.Template)
local Npcs = require(script.Npcs)

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

local POLL_EVERY = 1
local PICKER_TTL = 120
local ROOT_NAME = "Offices"
local PROMPT_NAME = "OfficesPrompt"
local OWNED_INTERACTS = { elevator_panel = true, company_directory = true }
local ARRIVE_LIFT = Vector3.new(0, 0.25, 0)
local STAIRS_DELAY = 3

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
local rootFolder: Folder? = nil
local warnedTemplates: { [string]: boolean } = {}

---------------------------------------------------------------------------------------------------
-- Catalog: companies, tracks, templates (loaded once)
---------------------------------------------------------------------------------------------------
type Catalog = {
	loaded: boolean,
	byId: { [string]: OfficeAlloc.Company },
	list: { OfficeAlloc.Company },
	tracks: { [string]: OfficeAlloc.Track },
	templates: { [string]: boolean },
	directory: { OfficeAlloc.Entry },
}
local catalog: Catalog = { loaded = false, byId = {}, list = {}, tracks = {}, templates = {}, directory = {} }

local function optionalModule(parent: Instance?, name: string): any
	local mod = if parent then parent:FindFirstChild(name) else nil
	if not (mod and mod:IsA("ModuleScript")) then
		return nil
	end
	local ok, result = pcall(function()
		return (require :: any)(mod)
	end)
	if not ok then
		warn(("[OfficeService] couldn't load %s: %s"):format(mod:GetFullName(), tostring(result)))
		return nil
	end
	return result
end

local function templatesFolder(): Instance?
	return ServerStorage:FindFirstChild("FirmTemplates")
end

local function ensureCatalog(): Catalog
	if catalog.loaded then
		return catalog
	end
	catalog.loaded = true
	local config = Shared:FindFirstChild("Config")
	local byId, list = OfficeAlloc.normalizeCompanies(optionalModule(config, "Companies"))
	if #list == 0 then
		-- Config/Companies isn't there yet: list the Street's firms by their tower names, all "Opening soon".
		warn("[OfficeService] Config/Companies missing or empty; every office shows as opening soon")
		for _, t in World.towers do
			local ids: { [string]: string } = {}
			if t.company then
				ids[t.company] = t.label
			end
			for _, id in t.picker or {} do
				ids[id] = ids[id] or DoorRules.prettify(id)
			end
			for id, label in ids do
				local c = OfficeAlloc.normalizeCompany({ id = id, name = label, departments = {} })
				if c and byId[id] == nil then
					byId[id] = c
					table.insert(list, c)
				end
			end
		end
	end
	catalog.byId = byId
	catalog.list = list
	catalog.tracks = OfficeAlloc.normalizeTracks(optionalModule(config, "Tracks"))
	local templates: { [string]: boolean } = {}
	local folder = templatesFolder()
	if folder then
		for _, child in folder:GetChildren() do
			templates[child.Name] = true
		end
	else
		warn("[OfficeService] ServerStorage.FirmTemplates is missing; offices can't open")
	end
	catalog.templates = templates
	catalog.directory = OfficeAlloc.directory(list, templates, catalog.tracks)
	return catalog
end

local logosModule: any = nil
local function logos(): any
	if logosModule == nil then
		local assets = Shared:FindFirstChild("Assets")
		logosModule = optionalModule(assets, "Logos") or false
	end
	return if logosModule then logosModule else nil
end

local function departmentName(floor: string): string
	if floor == LOBBY then
		return Text.get("lobby")
	end
	return OfficeAlloc.departmentName(floor, ensureCatalog().tracks)
end

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

local function notify(player: Player, text: string, kind: string?)
	local ns = Registry.get("NotifyService")
	if ns and type(ns.Notify) == "function" then
		pcall(function()
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

local function companyOf(inst: Instance): (string?, string?)
	local node: Instance? = inst
	while node and node ~= workspace do
		local id = node:GetAttribute("CompanyId")
		if type(id) == "string" then
			local floor = node:GetAttribute("Department")
			return id, if type(floor) == "string" then floor else nil
		end
		node = node.Parent
	end
	return nil, nil
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
	if same then
		return
	end
	locations[player] = loc
	if isLive(player) then
		player:SetAttribute("OfficeCompany", if loc then loc.companyId else nil)
		player:SetAttribute("OfficeFloor", if loc then loc.floor else nil)
	end
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
local function ensureInstance(company: OfficeAlloc.Company): (InstanceState?, string?)
	local inst = instances[company.id]
	if inst and inst.model.Parent then
		return inst, nil
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
		instances[fs.companyId] = nil
		inst.model:Destroy()
		OfficeAlloc.release(alloc, fs.companyId)
	end
end

local function liveFloorCount(): number
	local n = 0
	for _ in floorsByKey do
		n += 1
	end
	return n
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
	local folder = templatesFolder()
	local template = if folder then folder:FindFirstChild(floor) else nil
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
			instances[company.id] = nil
			inst.model:Destroy()
			OfficeAlloc.release(alloc, company.id)
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

	local brandOk, brandErr = pcall(Template.prepare, model, company, floor, logos())
	if not brandOk then
		warn(("[OfficeService] branding %s/%s failed: %s"):format(company.id, floor, tostring(brandErr)))
	end
	model:SetAttribute("InstanceIndex", inst.index)
	model:SetAttribute("FloorIndex", floorIndex)

	-- Templates are built around the origin: move the whole clone by the instance/floor origin.
	local origin = World.officeOrigin(inst.index, floorIndex)
	model:PivotTo(CFrame.new(origin) * model:GetPivot())
	local anchors = Template.anchors(model)
	model.Parent = inst.model

	local now = Time.now()
	local rec = OfficeAlloc.newFloor(company.id, floor, now)
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

	local track = ensureCatalog().tracks[floor]
	task.spawn(function()
		local npcOk, npcErr = pcall(Npcs.populate, {
			model = model,
			company = company,
			floor = floor,
			departmentName = departmentName(floor),
			bossTitle = if track then track.topTitle else nil,
			anchors = anchors,
			liveFloors = liveFloorCount(),
			alive = function()
				return fs.alive and model.Parent ~= nil
			end,
		})
		if not npcOk then
			warn(("[OfficeService] office NPCs for %s/%s failed: %s"):format(company.id, floor, tostring(npcErr)))
		end
	end)
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

local ARRIVAL_FALLBACKS = { "entry", "floor_entry", "elevators", "review_spot" }

local function arrivalCFrame(fs: FloorState, name: string): CFrame
	local anchor = fs.anchors[name]
	if not anchor then
		for _, alt in ARRIVAL_FALLBACKS do
			anchor = fs.anchors[alt]
			if anchor then
				break
			end
		end
	end
	if anchor and anchor.Parent then
		return flat(anchor.CFrame) + ARRIVE_LIFT
	end
	local warnKey = fs.floor .. "/" .. name
	if not warnedTemplates[warnKey] then
		warnedTemplates[warnKey] = true
		warn(("[OfficeService] template %s has no OfficeAnchor %q; arriving at the floor origin"):format(fs.floor, name))
	end
	return CFrame.new(World.officeOrigin(OfficeAlloc.indexOf(alloc, fs.companyId) or 1, fs.floorIndex))
		+ Vector3.new(0, 5, 0)
end

---------------------------------------------------------------------------------------------------
-- Entering
---------------------------------------------------------------------------------------------------
local function errorText(errKey: string?, company: OfficeAlloc.Company?, floor: string?): string
	if errKey == "opening_soon" then
		if company and floor and floor ~= LOBBY then
			return Text.format("floor_opening_soon", { department = departmentName(floor) })
		end
		return if company
			then Text.format("opening_soon_named", { name = company.name })
			else Text.get("unknown_company")
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
		return a == true, if a == true then nil else (if type(b) == "string" then b else "error")
	end
	-- No WorldService: plain move.
	local char = player.Character
	if not char or not rootPart(player) then
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
	local cat = ensureCatalog()
	local company = if type(companyId) == "string" then cat.byId[companyId] else nil
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
	local arrive = o.arrive
	if arrive == nil then
		arrive = if target == LOBBY then (if o.source == "elevator" then "elevators" else "entry") else "floor_entry"
	end
	local cf = arrivalCFrame(fs, arrive)

	if o.entryAnchor then
		memory[player] = { companyId = company.id, anchor = o.entryAnchor }
	elseif o.source ~= "elevator" then
		memory[player] = { companyId = company.id, anchor = nil }
	end

	local tpOpts: { [string]: any } = {
		label = company.name,
		sublabel = departmentName(target),
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
	fs.rec.lastOccupied = Time.now()
	setLocation(player, { companyId = company.id, floor = target })
	return true, nil, nil
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
	return ensureCatalog().byId[companyId]
end

function OfficeService:GetDirectory(): { OfficeAlloc.Entry }
	return ensureCatalog().directory
end

function OfficeService:IsAvailable(companyId: string, floor: string?): boolean
	local cat = ensureCatalog()
	local company = cat.byId[companyId]
	if not company then
		return false
	end
	return OfficeAlloc.floorOpen(company, floor or LOBBY, cat.templates, cat.tracks)
end

function OfficeService:GetCompanyAt(inst: Instance): (string?, string?)
	if typeof(inst) ~= "Instance" then
		return nil, nil
	end
	return companyOf(inst)
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
	local company = ensureCatalog().byId[companyId]
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
	local set: { [string]: boolean } = {}
	for _, id in tenants do
		set[id] = true
	end
	pickers[player] = { doorId = doorId, tenants = set, anchor = anchor, at = Time.now() }
end

---------------------------------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------------------------------
local function canReachStreet(player: Player): (boolean, string?)
	local world = worldService()
	if world and type(world.CanReachStreet) == "function" then
		local ok, can, text = pcall(function()
			return world:CanReachStreet(player)
		end)
		if ok and can == false then
			return false, if type(text) == "string" then text else Text.get("locked_flag")
		end
	end
	return true, nil
end

local function bindRemotes()
	Net.handle("Office.Enter", function(player: Player, companyId: any, floor: any)
		local id = Guard.id(companyId)
		if not id then
			return false, "opening_soon", Text.get("unknown_company")
		end
		local fl: string? = nil
		if floor ~= nil then
			fl = Guard.id(floor)
			if not fl then
				return false, "no_floor", errorText("no_floor", ensureCatalog().byId[id], nil)
			end
		end
		local reach, text = canReachStreet(player)
		if not reach then
			return false, "locked", text
		end
		local pick = pickers[player]
		local entryAnchor: string? = nil
		if pick and Time.now() - pick.at <= PICKER_TTL and pick.tenants[id] then
			entryAnchor = pick.anchor
		end
		local ok, err, message = OfficeService:EnterCompany(player, id, fl, {
			source = if entryAnchor then "door" else "directory",
			entryAnchor = entryAnchor,
		})
		if ok and pick and pickers[player] == pick then
			pickers[player] = nil
		end
		return ok, err, message
	end, { rate = 1, burst = 3 })

	Net.handle("Office.Elevator", function(player: Player, trackId: any)
		local fl = Guard.id(trackId)
		if not fl then
			return false, "no_floor", errorText("no_floor", nil, nil)
		end
		local loc = currentLocation(player) or locations[player]
		if not loc then
			return false, "not_in_office", errorText("not_in_office", nil, nil)
		end
		if loc.floor == fl then
			return true, nil, nil
		end
		return OfficeService:EnterCompany(player, loc.companyId, fl, { source = "elevator" })
	end, { rate = 1, burst = 3 })

	Net.handle("Office.Directory", function(_player: Player)
		return ensureCatalog().directory
	end, { rate = 1, burst = 5 })
end

---------------------------------------------------------------------------------------------------
-- Interact prompts (elevator_panel, company_directory)
---------------------------------------------------------------------------------------------------
local function promptParent(inst: Instance): Instance?
	local base: Instance? = nil
	if inst:IsA("BasePart") or inst:IsA("Attachment") then
		base = inst
	elseif inst:IsA("Model") then
		base = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	if base and base:IsA("BasePart") then
		local use = base:FindFirstChild("Use")
		if use and use:IsA("Attachment") then
			return use
		end
	end
	return base
end

local function wireInteract(inst: Instance)
	local id = inst:GetAttribute("InteractId")
	if type(id) ~= "string" or not OWNED_INTERACTS[id] or not inst:IsDescendantOf(workspace) then
		return
	end
	local parent = promptParent(inst)
	if not parent or parent:FindFirstChild(PROMPT_NAME) then
		return
	end
	local def = World.interactIds[id]
	local companyId = companyOf(inst)
	local company = if companyId then ensureCatalog().byId[companyId] else nil
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = if def then def.prompt else Text.get("office_elevator")
	prompt.ObjectText = if id == "elevator_panel"
		then (if company then company.name else Text.get("elevator_title"))
		else Text.get("directory_title")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("InteractId", id)
	if companyId then
		prompt:SetAttribute("CompanyId", companyId)
	end
	prompt.Parent = parent
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
	if had then
		OfficeService.LocationChanged:Fire(player, nil)
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function OfficeService:Init()
	root()
	bindRemotes()
end

function OfficeService:Start()
	ensureCatalog()
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	CollectionService:GetInstanceAddedSignal("Interact"):Connect(wireInteract)
	for _, inst in CollectionService:GetTagged("Interact") do
		wireInteract(inst)
	end
	while true do
		task.wait(POLL_EVERY)
		local ok, err = pcall(poll)
		if not ok then
			warn("[OfficeService] occupancy poll failed: " .. tostring(err))
		end
	end
end

return OfficeService
