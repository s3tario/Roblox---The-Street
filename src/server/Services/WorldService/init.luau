--!strict
-- WorldService (server, owned by `offices`; docs/contracts.md §11, Config/World doors/anchors/spawns).
-- Doors, teleports, stage spawns and world safety:
--   * every "Door"-tagged part gets a server-side ProximityPrompt (WorldService/Doors):
--       target   teleport to that anchor
--       ride     board (the `via` anchor), a "Next stop" banner for `seconds`, then arrive at `to`
--       company  OfficeService:EnterCompany(player, company) (the lobby; the exit leads back to this tower)
--       picker   the Directory screen filtered to the tower's tenants (unavailable ones "Opening soon")
--     plus the office template doors: OfficeDoor "exit" (back to the tower front the player came in through, else
--     the company's tower) and "to_lobby" (the lobby's OfficeAnchor "elevators").
--     Door requirements (minRank, employed, flag/orMinRank, pass) are checked with Logic/DoorRules; locked doors
--     tell the client why ("World.DoorLocked").
--   * Teleport: client fade ("World.Fade"), RequestStreamAroundAsync, PivotTo, a 2 s cooldown (WorldService/Teleport)
--   * RespawnLocation Spawn_campus for students, Spawn_street once hired (WorldService/Stage)
--   * falls below y = -50 or > 3 s out of every zone return the player to the stage spawn; implausible moves are
--     reported to AntiCheatService (WorldService/Safety)
--
-- API:
--   WorldService:Teleport(player, cframe, opts?) -> (ok, errKey?)       contracts §11
--       opts = { label?, sublabel?, message?, delay?, force? (skip the cooldown), fade? (default true), reason? }
--   WorldService:TeleportToAnchor(player, anchorId, opts?) -> (ok, errKey?)
--   WorldService:CanTeleport(player) -> (ok, errKey?)                    "busy" | "cooldown" | "no_character"
--   WorldService:CanReachStreet(player) -> (ok, lockedText?)             the campus -> Street gate (subway rules)
--   WorldService:ReturnToStage(player, reason?) -> ok
--   WorldService:GetZone(player) -> zoneId?        WorldService.ZoneChanged : Signal(player, zoneId)
--   WorldService:GetStage(player) -> "campus" | "street"   WorldService.StageChanged : Signal(player, stage, old?)
--   WorldService:GetAnchor(anchorId) -> BasePart?
--   WorldService:ExpectMove(player, seconds?)      another feature is about to move this character itself
-- Remotes (server -> client): "World.Fade"(phase, info), "World.DoorLocked"(info), "World.Ride"(info).
-- Player attributes: Zone, Stage.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local DoorRules = require(Shared.Logic.DoorRules)
local Registry = require(script.Parent.Parent.Registry)
local Access = require(script.Access)
local Anchors = require(script.Anchors)
local Doors = require(script.Doors)
local Teleport = require(script.Teleport)
local Stage = require(script.Stage)
local Safety = require(script.Safety)

local Text = DoorRules.Text

local WorldService = {
	Name = "WorldService",
	Priority = 25,
	ZoneChanged = Safety.ZoneChanged,
	StageChanged = Stage.Changed,
}

WorldService.REMOTE_LOCKED = "World.DoorLocked"
WorldService.REMOTE_RIDE = "World.Ride"
WorldService.REMOTE_FADE = Teleport.FADE

local STAGE_REFRESH = 5
local RIDE_STEP = 0.25

local riding: { [Player]: number } = {}
local rideSeq = 0
local seen: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
local function isLive(player: Player): boolean
	return player.Parent == Players
end

local function notify(player: Player, text: string, kind: string?)
	local ns = Registry.get("NotifyService")
	if ns and type(ns.Notify) == "function" then
		local ok, err = pcall(ns.Notify, ns, player, text, kind)
		if not ok then
			warn("[WorldService] NotifyService:Notify failed: " .. tostring(err))
		end
	end
end

local function officeService(): any
	return Registry.get("OfficeService")
end

local function tpText(errKey: string?): string
	if errKey == "cooldown" then
		return Text.get("tp_cooldown")
	elseif errKey == "busy" then
		return Text.get("tp_busy")
	elseif errKey == "no_character" then
		return Text.get("tp_no_character")
	end
	return Text.get("tp_failed")
end

-- Explains a failed move unless it's the quiet kind (a double tap during the cooldown or a ride).
local function explain(player: Player, errKey: string?)
	if errKey == "no_player" or errKey == "busy" or errKey == "cooldown" then
		return
	end
	notify(player, tpText(errKey), "warn")
end

---------------------------------------------------------------------------------------------------
-- Teleports
---------------------------------------------------------------------------------------------------
function WorldService:CanTeleport(player: Player): (boolean, string?)
	if riding[player] then
		return false, "busy"
	end
	return Teleport.canTeleport(player, false)
end

function WorldService:Teleport(player: Player, cframe: CFrame, opts: { [string]: any }?): (boolean, string?)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or typeof(cframe) ~= "CFrame" then
		return false, "error"
	end
	local o: Teleport.Opts = (opts or {}) :: any
	if riding[player] and not o.force then
		return false, "busy"
	end
	Safety.expect(player, Teleport.FADE_OUT + Teleport.STREAM_TIMEOUT + (o.delay or 0) + 2)
	return Teleport.run(player, cframe, o)
end

function WorldService:TeleportToAnchor(player: Player, anchorId: string, opts: { [string]: any }?): (boolean, string?)
	local cf = Anchors.cframe(anchorId)
	if not cf then
		return false, "no_anchor"
	end
	local o: { [string]: any } = if opts then table.clone(opts) else {}
	if o.label == nil then
		o.label = DoorRules.zoneLabel(DoorRules.anchorZone(anchorId))
	end
	return self:Teleport(player, cf, o)
end

function WorldService:CanReachStreet(player: Player): (boolean, string?)
	return DoorRules.streetAccess(Access.state(player))
end

function WorldService:GetZone(player: Player): string?
	return Safety.getZone(player)
end

function WorldService:GetStage(player: Player): string
	return Stage.get(player)
end

function WorldService:GetAnchor(anchorId: string): BasePart?
	return Anchors.get(anchorId)
end

function WorldService:ExpectMove(player: Player, seconds: number?)
	Safety.expect(player, seconds)
end

function WorldService:ReturnToStage(player: Player, reason: string?): boolean
	if not isLive(player) then
		return false
	end
	local stage = Stage.refresh(player)
	local cf = Stage.spawnCFrame(stage)
	if not cf then
		-- No spawn or anchor in this place at all: a respawn is the last resort.
		local char = player.Character
		local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		if hum and reason == "fall" then
			player:LoadCharacter()
			return true
		end
		return false
	end
	riding[player] = nil
	local ok = self:Teleport(player, cf, { label = DoorRules.zoneLabel(stage), force = true, reason = reason })
	if ok and reason then
		notify(player, Text.get("tp_returned"), "info")
	end
	return ok
end

---------------------------------------------------------------------------------------------------
-- Doors
---------------------------------------------------------------------------------------------------
local function locked(player: Player, doorId: string, text: string)
	if isLive(player) then
		Net.fire(WorldService.REMOTE_LOCKED, player, { doorId = doorId, text = text })
	end
end

local function rideTo(player: Player, doorId: string, def: { [string]: any })
	local r = def.ride
	if type(r) ~= "table" or type(r.to) ~= "string" then
		return
	end
	local toCf = Anchors.cframe(r.to)
	if not toCf then
		notify(player, Text.get("tp_failed"), "warn")
		return
	end
	local toLabel = DoorRules.zoneLabel(DoorRules.anchorZone(r.to))
	local viaCf = if type(r.via) == "string" then Anchors.cframe(r.via) else nil
	if not viaCf then
		local ok, err = WorldService:Teleport(player, toCf, { label = toLabel, reason = "ride" })
		if not ok then
			explain(player, err)
		end
		return
	end
	local ok, err = WorldService:Teleport(player, viaCf, {
		label = if type(def.label) == "string" then def.label else nil,
		sublabel = Text.get("ride_now_boarding"),
		reason = "ride",
	})
	if not ok then
		explain(player, err)
		return
	end
	rideSeq += 1
	local token = rideSeq
	riding[player] = token
	local seconds = math.clamp(if type(r.seconds) == "number" then r.seconds else 8, 1, 60)
	local char = player.Character
	Net.fire(WorldService.REMOTE_RIDE, player, {
		doorId = doorId,
		title = Text.get("ride_next_stop"),
		subtitle = toLabel,
		seconds = seconds,
	})
	local started = os.clock()
	while os.clock() - started < seconds do
		task.wait(RIDE_STEP)
		if not isLive(player) or riding[player] ~= token or player.Character ~= char then
			if riding[player] == token then
				riding[player] = nil
			end
			return
		end
	end
	local arrived, aerr = WorldService:Teleport(player, toCf, { label = toLabel, force = true, reason = "ride" })
	if riding[player] == token then
		riding[player] = nil
	end
	if not arrived then
		explain(player, aerr)
	end
end

local function enterCompany(player: Player, def: { [string]: any })
	local offices = officeService()
	if not offices or type(offices.EnterCompany) ~= "function" then
		notify(player, Text.get("opening_soon"), "info")
		return
	end
	local ok, err, message = offices:EnterCompany(player, def.company, "lobby", {
		source = "door",
		entryAnchor = def.frontAnchor,
	})
	if not ok then
		if type(message) == "string" and message ~= "" then
			notify(player, message, if err == "opening_soon" then "info" else "warn")
		else
			explain(player, err)
		end
	end
end

local function openPicker(player: Player, doorId: string, def: { [string]: any })
	local tenants: { string } = {}
	for _, id in def.picker do
		if type(id) == "string" then
			table.insert(tenants, id)
		end
	end
	local offices = officeService()
	if not offices or type(offices.OpenDirectory) ~= "function" then
		notify(player, Text.get("opening_soon"), "info")
		return
	end
	if type(offices.SetPickerContext) == "function" then
		offices:SetPickerContext(player, doorId, tenants, def.frontAnchor)
	end
	offices:OpenDirectory(player, {
		source = "tower",
		doorId = doorId,
		title = if type(def.label) == "string" then def.label else nil,
		tenants = tenants,
	})
end

local function onWorldDoor(player: Player, doorId: string, def: { [string]: any }, _part: BasePart)
	if riding[player] or Teleport.isBusy(player) then
		return
	end
	local ok, reason = DoorRules.check(def.requires, Access.state(player, def.requires))
	if not ok then
		locked(player, doorId, DoorRules.lockedText(def, reason))
		return
	end
	local kind = DoorRules.kind(def)
	if kind == "target" then
		local okTp, err = WorldService:TeleportToAnchor(player, def.target, { reason = "door" })
		if not okTp then
			explain(player, err)
		end
	elseif kind == "ride" then
		rideTo(player, doorId, def)
	elseif kind == "company" then
		enterCompany(player, def)
	elseif kind == "picker" then
		openPicker(player, doorId, def)
	end
end

local function onOfficeDoor(player: Player, kind: string, part: BasePart)
	if riding[player] or Teleport.isBusy(player) then
		return
	end
	local companyId = Doors.companyOf(part)
	local offices = officeService()
	if kind == "to_lobby" then
		if companyId and offices and type(offices.EnterCompany) == "function" then
			local ok, err, message = offices:EnterCompany(player, companyId, "lobby", {
				source = "elevator",
				arrive = "elevators",
			})
			if not ok then
				if type(message) == "string" and message ~= "" then
					notify(player, message, "warn")
				else
					explain(player, err)
				end
			end
		end
		return
	end
	-- "exit": back to the Street, through the tower the player came in by
	local anchorId = DoorRules.FALLBACK_EXIT
	if companyId and offices and type(offices.ResolveExit) == "function" then
		local ok, resolved = pcall(offices.ResolveExit, offices, player, companyId)
		if ok and type(resolved) == "string" then
			anchorId = resolved
		end
	elseif companyId then
		anchorId = DoorRules.resolveExit(nil, companyId)
	end
	local cf = Anchors.cframe(anchorId) or Anchors.cframe(DoorRules.FALLBACK_EXIT) or Stage.spawnCFrame("street")
	if not cf then
		notify(player, Text.get("tp_failed"), "warn")
		return
	end
	local ok, err = WorldService:Teleport(player, cf, { label = DoorRules.zoneLabel("street"), reason = "door" })
	if not ok then
		explain(player, err)
	end
end

---------------------------------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	if seen[player] then
		return
	end
	seen[player] = true
	Stage.onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		riding[player] = nil
		Safety.expect(player, 3)
	end)
end

local function onPlayerRemoving(player: Player)
	seen[player] = nil
	riding[player] = nil
	Teleport.clear(player)
	Stage.clear(player)
	Safety.clear(player)
	Doors.forget(player)
end

local function connectCareer()
	local career = Registry.get("CareerService")
	if type(career) ~= "table" then
		return
	end
	for _, name in { "RoleChanged", "StatusChanged" } do
		local sig = career[name]
		if type(sig) == "table" and type(sig.Connect) == "function" then
			local ok, err = pcall(function()
				sig:Connect(function(player: any)
					if typeof(player) == "Instance" and player:IsA("Player") then
						Stage.refresh(player)
					end
				end)
			end)
			if not ok then
				warn(("[WorldService] couldn't listen to CareerService.%s: %s"):format(name, tostring(err)))
			end
		end
	end
end

local function connectData()
	local data = Registry.get("DataService")
	local sig = if type(data) == "table" then data.ProfileLoaded else nil
	if type(sig) == "table" and type(sig.Connect) == "function" then
		sig:Connect(function(player: any)
			if typeof(player) == "Instance" and player:IsA("Player") then
				Stage.refresh(player, true)
			end
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function WorldService:Init()
	Net.declare(Teleport.FADE)
	Net.declare(WorldService.REMOTE_LOCKED)
	Net.declare(WorldService.REMOTE_RIDE)
	Teleport.bind(function(player: Player, cf: CFrame)
		Safety.moved(player, cf)
	end)
	Stage.bind(function(player: Player, cf: CFrame, opts: { [string]: any }): boolean
		local ok = WorldService:Teleport(player, cf, opts)
		return ok
	end)
	Safety.bind({
		returnToStage = function(player: Player, reason: string)
			WorldService:ReturnToStage(player, reason)
		end,
		isBusy = function(player: Player): boolean
			return riding[player] ~= nil or Teleport.isBusy(player)
		end,
		flag = function(player: Player, details: { [string]: any })
			local ac = Registry.get("AntiCheatService")
			if ac and type(ac.Flag) == "function" then
				ac:Flag(player, "impossible_move", details)
			end
		end,
	})
	-- New players must get the campus spawn before their first character loads.
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	-- Office floors are cloned at runtime: wire their template doors as each floor appears.
	local offices = officeService()
	local created = if type(offices) == "table" then offices.FloorCreated else nil
	if type(created) == "table" and type(created.Connect) == "function" then
		created:Connect(function(_companyId: string, _floor: string, model: Instance)
			if typeof(model) == "Instance" then
				Doors.wireModel(model)
			end
		end)
	end
	connectData()
end

function WorldService:Start()
	local offices = officeService()
	local officeRoot = workspace:FindFirstChild(if offices and offices.ROOT_NAME then offices.ROOT_NAME else "Offices")
	Anchors.start(officeRoot)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
		Stage.refresh(player, true)
	end
	connectCareer()
	Doors.start({ world = onWorldDoor, office = onOfficeDoor })
	if offices and type(offices.GetFloors) == "function" then
		local ok, floors = pcall(offices.GetFloors, offices)
		if ok and type(floors) == "table" then
			for _, f in floors do
				if type(f) == "table" and typeof(f.model) == "Instance" then
					Doors.wireModel(f.model)
				end
			end
		end
	end
	Safety.start()
	while true do
		task.wait(STAGE_REFRESH)
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(Stage.refresh, player)
			if not ok then
				warn("[WorldService] stage refresh failed: " .. tostring(err))
			end
		end
	end
end

return WorldService
