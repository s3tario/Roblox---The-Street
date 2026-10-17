--!strict
-- OfficeService (server, Priority 20, owned by `offices`; docs/contracts.md §11, spec v3 §14).
-- One office instance per company present on this server: a branded lobby (floor 0) plus one floor per
-- department, cloned lazily from ServerStorage.FirmTemplates and placed at World.officeOrigin(index, floor)
-- (OfficeService/Floors). Floors nobody has been inside for 3 minutes are destroyed, and the instance slot is
-- freed with its last floor. Anyone may visit any company; interactions inside are each feature's job
-- (CareerService:IsEmployeeOf), and the client hides EmployeesOnly prompts for visitors (OfficeController).
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
--   OfficeService:GetFloors() -> { { companyId, floor, model } }   every live floor (WorldService wires its doors)
--   OfficeService:GetBossName(companyId, trackId) -> string   the name the boss NPC wears
--   OfficeService:GetBossNpc(companyId, trackId) -> Model?
--   OfficeService:ResolveExit(player, companyId) -> anchorId  where the lobby "exit" door leads this player
--   OfficeService:SetPickerContext(player, doorId, tenants, anchorId?)   WorldService, when a tower picker opens
--   OfficeService:OpenDirectory(player, args?)               opens the Directory screen on that client
--   OfficeService:EnterFromRemote(player, companyId, floor?) / :RideElevator(player, floor)   remote entry points
-- Remotes: OfficeService/Remotes ("Office.Enter", "Office.Elevator", "Office.Directory", "Office.OpenElevator",
-- "Office.OpenDirectory"). Interacts owned here: `elevator_panel` (lobby) and `company_directory` (street kiosks),
-- wired in OfficeService/Prompts.
-- Player attributes set here: OfficeCompany, OfficeFloor (the office the player is standing in).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Time = require(Shared.Util.Time)
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)
local DoorRules = require(Shared.Logic.DoorRules)
local Registry = require(script.Parent.Parent.Registry)
local Catalog = require(script.Catalog)
local Template = require(script.Template)
local Npcs = require(script.Npcs)
local Floors = require(script.Floors)
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
OfficeService.ROOT_NAME = Floors.ROOT_NAME

local POLL_EVERY = 1
local PICKER_TTL = 120
local OPEN_COOLDOWN = 0.75
local STAIRS_DELAY = 3

export type Location = { companyId: string, floor: string }
export type EnterOpts = { source: string?, entryAnchor: string?, arrive: string? }

type Picker = { doorId: string, tenants: { [string]: boolean }, anchor: string?, at: number }

local locations: { [Player]: Location } = {}
local memory: { [Player]: DoorRules.Memory } = {}
local pickers: { [Player]: Picker } = {}
local lastOpen: { [Player]: number } = {}

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
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
		local ok, err = pcall(ns.Notify, ns, player, text, kind)
		if not ok then
			warn("[OfficeService] NotifyService:Notify failed: " .. tostring(err))
		end
	end
end

local function eventActive(eventId: string): boolean
	local es = Registry.get("EventService")
	if es and type(es.IsActive) == "function" then
		local ok, active = pcall(es.IsActive, es, eventId)
		return ok and active == true
	end
	return false
end

local function worldService(): any
	return Registry.get("WorldService")
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
	local c, f = Floors.locate(hrp.Position)
	if c and f then
		return { companyId = c, floor = f }
	end
	return nil
end

local function errorText(errKey: string?, company: OfficeAlloc.Company?, floor: string?): string
	if errKey == "opening_soon" then
		if company and floor and floor ~= LOBBY then
			return Text.format("floor_opening_soon", { department = Catalog.departmentName(floor) })
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

-- WorldService:Teleport (fade, streaming, cooldown), or a plain streaming-safe move when it is missing.
local function teleport(player: Player, cf: CFrame, opts: { [string]: any }): (boolean, string?)
	local world = worldService()
	if world and type(world.Teleport) == "function" then
		local ok, a, b = pcall(world.Teleport, world, player, cf, opts)
		if not ok then
			warn("[OfficeService] WorldService:Teleport errored: " .. tostring(a))
			return false, "error"
		end
		if a == true then
			return true, nil
		end
		return false, if type(b) == "string" then b else "error"
	end
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

---------------------------------------------------------------------------------------------------
-- Entering
---------------------------------------------------------------------------------------------------
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
		if OfficeAlloc.floorIndex(company.departments, target) == nil then
			return false, "no_floor", errorText("no_floor", company, target)
		end
		if not OfficeAlloc.floorOpen(company, target, cat.templates, cat.tracks) then
			return false, "opening_soon", errorText("opening_soon", company, target)
		end
	end
	local world = worldService()
	if world and type(world.CanTeleport) == "function" then
		local ok, can, why = pcall(world.CanTeleport, world, player)
		if ok and can == false then
			local key = if type(why) == "string" then why else "busy"
			return false, key, errorText(key, company, target)
		end
	end

	local fs, err = Floors.ensure(company, target)
	if not fs then
		return false, err, errorText(err, company, target)
	end
	Floors.touch(fs, Time.now())
	local defaultArrive = if target == LOBBY
		then (if o.source == "elevator" then "elevators" else "entry")
		else "floor_entry"
	local cf = Floors.arrival(fs, o.arrive or defaultArrive)

	local tpOpts: { [string]: any } = {
		label = company.name,
		sublabel = Catalog.departmentName(target),
		reason = "office",
		companyId = company.id,
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
	Floors.touch(fs, Time.now())
	-- Remember where the player came in from the Street (the lobby "exit" door leads back there).
	if o.entryAnchor then
		memory[player] = { companyId = company.id, anchor = o.entryAnchor }
	elseif o.source ~= "elevator" then
		local prev = memory[player]
		if not (prev and prev.companyId == company.id) then
			memory[player] = { companyId = company.id, anchor = nil }
		end
	end
	setLocation(player, { companyId = company.id, floor = target })
	return true, nil, nil
end

-- Office.Enter (Directory / Phone / tower picker). Students without street access stay on campus.
function OfficeService:EnterFromRemote(player: Player, companyId: string, floor: string?): (boolean, string?, string?)
	local world = worldService()
	if world and type(world.CanReachStreet) == "function" then
		local ok, can, text = pcall(world.CanReachStreet, world, player)
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

function OfficeService:OpenDirectory(player: Player, args: { [string]: any }?)
	if isLive(player) then
		Remotes.openDirectory(player, args)
	end
end

---------------------------------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------------------------------
function OfficeService:GetInstance(companyId: string): Model?
	local inst = Floors.instance(companyId)
	return if inst then inst.model else nil
end

function OfficeService:GetFloor(companyId: string, trackId: string): Model?
	local fs = Floors.get(companyId, trackId)
	return if fs then fs.model else nil
end

function OfficeService:GetFloors(): { { companyId: string, floor: string, model: Model } }
	local out = {}
	for _, fs in Floors.all() do
		table.insert(out, { companyId = fs.companyId, floor = fs.floor, model = fs.model })
	end
	return out
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
	return Floors.locate(position)
end

function OfficeService:GetAnchor(companyId: string, floor: string, name: string): BasePart?
	local fs = Floors.get(companyId, floor)
	if not fs then
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
	local fs = Floors.get(companyId, trackId)
	if not fs then
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
	Floors.sweep(occupied, Time.now())
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
	Floors.bind(OfficeService.FloorCreated, OfficeService.FloorRemoved)
	Floors.root()
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
		local ok, err = pcall(function(): string?
			poll()
			return nil
		end)
		if not ok then
			warn("[OfficeService] occupancy poll failed: " .. tostring(err))
		end
	end
end

return OfficeService
