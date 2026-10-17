--!strict
-- WorldService/Stage (server, runtime): which part of the world a player belongs to and where they respawn.
--   campus  students (and anyone who never started a career): RespawnLocation = Spawn_campus
--   street  everyone who has been hired: RespawnLocation = Spawn_street
-- (Logic/DoorRules.stageFor decides from CareerService / saved career data.) The stage is refreshed when the
-- profile loads, on CareerService.RoleChanged / StatusChanged and periodically as a fallback.
-- New players get Spawn_campus before their first spawn; a returning employee whose first spawn happened on
-- campus before their data arrived is moved to the Street once it loads.
--
--   Stage.bind(teleport)            teleport(player, cframe, opts) -> ok (WorldService:Teleport)
--   Stage.onPlayerAdded(player)     default RespawnLocation before the first spawn
--   Stage.refresh(player, initial?) -> stage   recompute; sets player attribute "Stage"
--   Stage.get(player) -> "campus" | "street"
--   Stage.spawnCFrame(stage) -> CFrame?   where a "return to the stage spawn" lands
--   Stage.clear(player)
--   Stage.Changed : Signal(player, stage, oldStage?)

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local World = require(Shared.Config.World)
local DoorRules = require(Shared.Logic.DoorRules)
local Access = require(script.Parent.Access)
local Anchors = require(script.Parent.Anchors)

local Stage = {}

Stage.Changed = Signal.new()
Stage.RELOCATE_WINDOW = 45 -- seconds after a spawn in which a wrong-stage first spawn is corrected

type Teleporter = (player: Player, cf: CFrame, opts: { [string]: any }) -> boolean

local stages: { [Player]: string } = {}
local spawnedAt: { [Player]: number } = {}
local relocated: { [Player]: boolean } = {}
local teleportFn: Teleporter? = nil

function Stage.bind(teleport: Teleporter)
	teleportFn = teleport
end

local function spawnName(stage: string): string
	return DoorRules.STAGE_SPAWNS[stage] or DoorRules.STAGE_SPAWNS.campus
end

function Stage.spawnCFrame(stage: string): CFrame?
	local cf = Anchors.spawnCFrame(spawnName(stage))
	if cf then
		return cf
	end
	-- no stage spawn in this place: any anchor of that stage's region
	local def = (World.spawns :: { [string]: any })[spawnName(stage)]
	local anchor = if type(def) == "table" then def.anchor else nil
	return if type(anchor) == "string" then Anchors.cframe(anchor) else nil
end

local function applyRespawn(player: Player, stage: string)
	local spawn = Anchors.spawnLocation(spawnName(stage))
	if spawn then
		if player.RespawnLocation ~= spawn then
			player.RespawnLocation = spawn
		end
	elseif (player :: any).RespawnLocation ~= nil then
		(player :: any).RespawnLocation = nil
	end
end

function Stage.get(player: Player): string
	return stages[player] or "campus"
end

function Stage.onPlayerAdded(player: Player)
	if stages[player] == nil then
		applyRespawn(player, "campus")
	end
	player.CharacterAdded:Connect(function(char: Model)
		spawnedAt[player] = os.clock()
		-- Without a SpawnLocation for the stage, place the character on the stage anchor instead.
		if Anchors.spawnLocation(spawnName(Stage.get(player))) == nil then
			task.defer(function()
				local cf = Stage.spawnCFrame(Stage.get(player))
				if cf and player.Character == char and char.Parent then
					char:PivotTo(cf)
				end
			end)
		end
	end)
end

-- The first spawn happened before the data said "street": move the character there once.
local function relocate(player: Player, stage: string)
	if relocated[player] or stage ~= "street" then
		return
	end
	local char = player.Character
	local hrp = if char then char:FindFirstChild("HumanoidRootPart") else nil
	if not (hrp and hrp:IsA("BasePart")) then
		return
	end
	if os.clock() - (spawnedAt[player] or -math.huge) > Stage.RELOCATE_WINDOW then
		return
	end
	if not DoorRules.isCampusSide(World.zoneAt(hrp.Position)) then
		return
	end
	local cf = Stage.spawnCFrame(stage)
	local tp = teleportFn
	if cf and tp then
		relocated[player] = true
		tp(player, cf, { label = DoorRules.zoneLabel("street"), force = true, reason = "stage" })
	end
end

function Stage.refresh(player: Player, initial: boolean?): string
	if player.Parent ~= Players then
		return Stage.get(player)
	end
	local stage = DoorRules.stageFor(Access.stageInfo(player))
	local old = stages[player]
	stages[player] = stage
	applyRespawn(player, stage)
	if player:GetAttribute("Stage") ~= stage then
		player:SetAttribute("Stage", stage)
	end
	if old ~= stage then
		Stage.Changed:Fire(player, stage, old)
	end
	if initial then
		task.spawn(relocate, player, stage)
	end
	return stage
end

function Stage.clear(player: Player)
	stages[player] = nil
	spawnedAt[player] = nil
	relocated[player] = nil
end

return Stage
