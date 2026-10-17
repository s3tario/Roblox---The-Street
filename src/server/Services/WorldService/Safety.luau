--!strict
-- WorldService/Safety (server, runtime): a 0.5 s sample of every character.
--   * zone tracking: World.zoneAt(position) -> player attribute "Zone" + the ZoneChanged signal
--   * falls below y = -50, or more than 3 s outside every zone -> back to the stage spawn (Logic/DoorRules.safety)
--   * implausible horizontal jumps between samples that no sanctioned teleport explains -> AntiCheatService:Flag
--     (guarded, at most one report per player per REPORT_GAP seconds; evidence only, never a punishment here)
--
--   Safety.bind({ returnToStage = fn(player, reason), isBusy = fn(player) -> boolean, flag = fn(player, details) })
--   Safety.start()
--   Safety.expect(player, seconds?)   a sanctioned move is coming (teleports call it; other features may too)
--   Safety.moved(player, cframe)      a sanctioned move just happened
--   Safety.getZone(player) -> zoneId?
--   Safety.clear(player)
--   Safety.ZoneChanged : Signal(player, zoneId)

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local World = require(Shared.Config.World)
local DoorRules = require(Shared.Logic.DoorRules)

local Safety = {}

Safety.ZoneChanged = Signal.new()
Safety.SAMPLE = 0.5
Safety.REPORT_GAP = 30
Safety.EXPECT_DEFAULT = 3

export type Hooks = {
	returnToStage: (player: Player, reason: string) -> (),
	isBusy: (player: Player) -> boolean,
	flag: (player: Player, details: { [string]: any }) -> (),
}

type Track = { pos: Vector3, at: number }

local hooks: Hooks? = nil
local zones: { [Player]: string } = {}
local outSince: { [Player]: number } = {}
local lastSample: { [Player]: Track } = {}
local expectUntil: { [Player]: number } = {}
local lastReport: { [Player]: number } = {}
local returning: { [Player]: boolean } = {}

function Safety.bind(h: Hooks)
	hooks = h
end

function Safety.getZone(player: Player): string?
	return zones[player]
end

function Safety.expect(player: Player, seconds: number?)
	local untilAt = os.clock() + math.clamp(seconds or Safety.EXPECT_DEFAULT, 0, 30)
	expectUntil[player] = math.max(expectUntil[player] or 0, untilAt)
	lastSample[player] = nil
end

function Safety.moved(player: Player, cf: CFrame)
	lastSample[player] = { pos = cf.Position, at = os.clock() }
	outSince[player] = nil
end

function Safety.clear(player: Player)
	zones[player] = nil
	outSince[player] = nil
	lastSample[player] = nil
	expectUntil[player] = nil
	lastReport[player] = nil
	returning[player] = nil
end

local function setZone(player: Player, zone: string)
	if zones[player] == zone then
		return
	end
	zones[player] = zone
	player:SetAttribute("Zone", zone)
	Safety.ZoneChanged:Fire(player, zone)
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then
		return nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp else nil
end

local function sendBack(player: Player, reason: string)
	local h = hooks
	if not h or returning[player] then
		return
	end
	returning[player] = true
	lastSample[player] = nil
	outSince[player] = nil
	task.spawn(function()
		local ok, err = pcall(function(): string?
			h.returnToStage(player, reason)
			return nil
		end)
		if not ok then
			warn("[WorldService] return to stage failed: " .. tostring(err))
		end
		returning[player] = nil
	end)
end

local function sample(player: Player, now: number)
	local hrp = rootOf(player)
	if not hrp then
		lastSample[player] = nil
		outSince[player] = nil
		return
	end
	local pos = hrp.Position
	local zone = World.zoneAt(pos)
	if zone then
		setZone(player, zone)
	end
	local h = hooks
	if (h and h.isBusy(player)) or returning[player] then
		lastSample[player] = nil
		outSince[player] = nil
		return
	end

	local action, since = DoorRules.safety(pos.Y, zone, outSince[player], now)
	if since then
		outSince[player] = since
	else
		outSince[player] = nil
	end
	if action then
		sendBack(player, action)
		return
	end

	local last = lastSample[player]
	lastSample[player] = { pos = pos, at = now }
	if not last or now < (expectUntil[player] or 0) then
		return
	end
	if DoorRules.impossibleMove(last.pos, pos, now - last.at) then
		if now - (lastReport[player] or -math.huge) >= Safety.REPORT_GAP and h then
			lastReport[player] = now
			local details = {
				from = { math.floor(last.pos.X), math.floor(last.pos.Y), math.floor(last.pos.Z) },
				to = { math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z) },
				dt = math.floor((now - last.at) * 100) / 100,
				zone = zone,
			}
			local ok, err = pcall(function(): string?
				h.flag(player, details)
				return nil
			end)
			if not ok then
				warn("[WorldService] impossible-move report failed: " .. tostring(err))
			end
		end
	end
end

function Safety.start()
	task.spawn(function()
		while true do
			task.wait(Safety.SAMPLE)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function(): string?
					sample(player, now)
					return nil
				end)
				if not ok then
					warn("[WorldService] safety sample failed: " .. tostring(err))
				end
			end
		end
	end)
end

return Safety
