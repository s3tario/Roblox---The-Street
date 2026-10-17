--!strict
-- ActivityService (server, owned by `careerPath`; contracts §5, spec §3): counts each player's ACTIVE play time.
-- The work week, review windows and the Fastest Run board run on active time, so AFK time never counts.
--
-- A player is active while either signal is fresh (Time.AFK_AFTER = 120 s):
--   * input: CareerController sends "Activity.Ping"(idleSeconds) every 15 s with the seconds since the last
--     input (keyboard, mouse, touch, gamepad, thumbstick); the server never trusts it beyond that window
--   * movement: the server samples the character root every 5 s; walking 3+ studs counts as activity
-- Joining counts as fresh input, so the first two minutes always count.
--
-- Data: data.meta.activeSec (lifetime active seconds; contracts §3 says ActivityService owns it).
--
-- API (contracts §5):
--   ActivityService:GetActiveSeconds(player) -> number     lifetime active seconds (the review-window clock)
--   ActivityService.ActiveTick : Signal(player, dt)        fired about once a second while active
-- Extras:
--   ActivityService:IsActive(player) -> boolean
--   ActivityService:GetSessionSeconds(player) -> number    active seconds this session

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local Signal = require(Shared.Util.Signal)
local Time = require(Shared.Util.Time)
local Registry = require(script.Parent.Parent.Registry)

local ActivityService = {
	Name = "ActivityService",
	Priority = 25,
	ActiveTick = Signal.new(),
}

ActivityService.AFK_AFTER = Time.AFK_AFTER
ActivityService.PING_REMOTE = "Activity.Ping"

local TICK = 1
local MAX_DT = 5
local MOVE_SAMPLE = 5
local MOVE_MIN = 3
local REPLICATE_EVERY = 60

type State = {
	lastInputAt: number,
	lastMoveAt: number,
	lastSampleAt: number,
	lastPos: Vector3?,
	session: number,
	lastReplicate: number,
	active: boolean,
}

local states: { [Player]: State } = {}
local warned = false

local function dataOf(player: Player): { [string]: any }?
	local ds = Registry.get("DataService")
	if type(ds) ~= "table" or type(ds.Get) ~= "function" then
		return nil
	end
	local ok, data = pcall(ds.Get, ds, player)
	return if ok and type(data) == "table" then data else nil
end

local function replicateMeta(player: Player)
	local ds = Registry.get("DataService")
	if type(ds) == "table" and type(ds.Replicate) == "function" then
		pcall(ds.Replicate, ds, player, "meta")
	end
end

local function onPlayer(player: Player)
	if states[player] then
		return
	end
	local now = os.clock()
	states[player] = {
		lastInputAt = now,
		lastMoveAt = now,
		lastSampleAt = 0,
		lastPos = nil,
		session = 0,
		lastReplicate = now,
		active = true,
	}
end

local function sampleMovement(player: Player, st: State, now: number)
	if now - st.lastSampleAt < MOVE_SAMPLE then
		return
	end
	st.lastSampleAt = now
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		st.lastPos = nil
		return
	end
	local pos = root.Position
	local last = st.lastPos
	if last and (pos - last).Magnitude >= MOVE_MIN then
		st.lastMoveAt = now
	end
	st.lastPos = pos
end

local function step(dt: number)
	local now = os.clock()
	for player, st in states do
		if player.Parent ~= Players then
			continue
		end
		sampleMovement(player, st, now)
		local active = now - st.lastInputAt <= ActivityService.AFK_AFTER
			or now - st.lastMoveAt <= ActivityService.AFK_AFTER
		st.active = active
		if not active then
			continue
		end
		local data = dataOf(player)
		if not data then
			continue
		end
		local meta = data.meta
		if type(meta) ~= "table" then
			continue
		end
		local before = meta.activeSec
		meta.activeSec = (if type(before) == "number" and before == before then before else 0) + dt
		st.session += dt
		ActivityService.ActiveTick:Fire(player, dt)
		if now - st.lastReplicate >= REPLICATE_EVERY then
			st.lastReplicate = now
			replicateMeta(player)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------------------------------
function ActivityService:GetActiveSeconds(player: Player): number
	local data = dataOf(player)
	local meta = if data then data.meta else nil
	local v = if type(meta) == "table" then meta.activeSec else nil
	if type(v) == "number" and v == v then
		return v
	end
	local st = states[player]
	return if st then st.session else 0
end

function ActivityService:GetSessionSeconds(player: Player): number
	local st = states[player]
	return if st then st.session else 0
end

function ActivityService:IsActive(player: Player): boolean
	local st = states[player]
	return st ~= nil and st.active
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function ActivityService:Init()
	Net.on(ActivityService.PING_REMOTE, function(player: Player, idle: any)
		local st = states[player]
		if not st then
			return
		end
		local seconds = Guard.num(idle, 0, 86400)
		if seconds == nil then
			return
		end
		local at = os.clock() - seconds
		if at > st.lastInputAt then
			st.lastInputAt = at
		end
	end, { rate = 0.5, burst = 4 })
end

function ActivityService:Start()
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	local last = os.clock()
	while true do
		task.wait(TICK)
		local now = os.clock()
		local dt = math.clamp(now - last, 0, MAX_DT)
		last = now
		local ok, err = pcall(function()
			step(dt)
		end)
		if not ok and not warned then
			warned = true
			warn("[ActivityService] tick failed: " .. tostring(err))
		end
	end
end

return ActivityService
