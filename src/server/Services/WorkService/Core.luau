--!strict
-- WorkService/Core (server, runtime only): shared state for the work service. Task modules, per-player state,
-- the data.work record and the daily board upkeep, plus desk checks. Runner (start/submit/abandon), View (the
-- board view) and init (API, remotes, lifecycle) all build on it.
--
--   Core.loadModules()                       requires Shared/Logic/Tasks/* and keeps those that pass Catalog.check
--   Core.modules / Core.infos / Core.states  task modules by id, board infos, per-player state
--   Core.stateOf(player) -> PState            Core.workOf(data) -> data.work (repaired in place)
--   Core.ensureBoard(player, now) -> (board?, data?)   today's board (rebuilt on a new workday or role)
--   Core.activeSeconds(player, data) -> number         Core.changed(player)   fires Work.Changed
--   Core.companyNameOf(companyId) -> string?           Core.mayUseDesk(player, who, companyId?) -> boolean
--   Core.deskNear(player, who) -> boolean              at a desk this player may use (desk XP bonus)
--   Core.TaskCompleted / TaskStarted / TaskOffered     the service's signals

local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Rng = require(Shared.Util.Rng)
local Hash = require(Shared.Util.Hash)
local TableUtil = require(Shared.Util.TableUtil)
local Config = require(Shared.Config.Tasks)
local Template = require(Shared.Config.DataTemplate.Work)
local TasksFolder = Shared:WaitForChild("Logic"):WaitForChild("Tasks")
local SharedTasks = TasksFolder:WaitForChild("_shared")
local Board = require(SharedTasks:WaitForChild("Board"))
local Catalog = require(SharedTasks:WaitForChild("Catalog"))
local Deps = require(script.Parent.Deps)
local Flow = require(script.Parent.Flow)
local Prompts = require(script.Parent.Prompts)

local Companies = Deps.require(Shared.Config:FindFirstChild("Companies"))

local Core = {
	TaskCompleted = Signal.new(), -- (player, taskId, result)
	TaskStarted = Signal.new(), -- (player, taskId, instanceId)
	TaskOffered = Signal.new(), -- (player, taskId, entry)
}

export type Active = {
	instanceId: string,
	taskId: string,
	mod: any,
	payload: { [string]: any },
	secret: any,
	ctx: { [string]: any },
	startedAt: number,
	limit: number,
	grace: number,
	desk: boolean,
	who: Board.Who,
	mults: Flow.Mults,
	source: string,
	entryData: { [string]: any }?,
}
export type PState = { active: Active?, lastStart: number, lastPrompt: number }

local TICK = 5
local RECENT_KEPT = 12
local MAX_ANSWER_KEYS = 400
local MAX_ANSWER_DEPTH = 5
local MAX_OFFER_KEYS = 16

-- server-only salt: payload seeds can't be predicted from anything a client knows
local SALT = HttpService:GenerateGUID(false)

local modules: { [string]: any } = {}
local infos: { Board.ModuleInfo } = {}
local states: { [Player]: PState } = {}

local num = Deps.num

---------------------------------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------------------------------
local function loadModules()
	for _, child in TasksFolder:GetChildren() do
		if child:IsA("ModuleScript") and string.sub(child.Name, 1, 1) ~= "_" then
			local mod = Deps.require(child)
			local ok, err = Catalog.check(mod, child.Name)
			if ok then
				modules[mod.id] = mod
				table.insert(infos, Catalog.info(mod) :: any)
			else
				warn(("[WorkService] skipped task module %s: %s"):format(child.Name, tostring(err)))
			end
		end
	end
	table.sort(infos, function(a, b)
		return a.id < b.id
	end)
end

---------------------------------------------------------------------------------------------------
-- State and data
---------------------------------------------------------------------------------------------------
local function stateOf(player: Player): PState
	local st = states[player]
	if not st then
		st = { active = nil, lastStart = -math.huge, lastPrompt = -math.huge }
		states[player] = st
	end
	return st
end

local function workOf(data: { [string]: any }): { [string]: any }
	local w = data.work
	if type(w) ~= "table" then
		w = TableUtil.deepCopy(Template.work)
		data.work = w
	end
	for k, v in Template.work do
		if type(w[k]) ~= type(v) then
			w[k] = TableUtil.deepCopy(v)
		end
	end
	local board = w.board
	if type(board.tasks) ~= "table" then
		board.tasks = {}
	end
	if type(board.key) ~= "string" then
		board.key = ""
	end
	for i = #board.tasks, 1, -1 do
		local e = board.tasks[i]
		if type(e) ~= "table" or type(e.id) ~= "string" or modules[e.id] == nil then
			table.remove(board.tasks, i)
		else
			e.core = e.core == true
			e.done = e.done == true
		end
	end
	for _, key in { "attempts", "coreDone", "lastTaskAt" } do
		w[key] = num(w[key], 0)
	end
	return w
end

local function activeSeconds(player: Player, data: { [string]: any }): number
	local ok, v = Deps.call("ActivityService", "GetActiveSeconds", player)
	if ok and type(v) == "number" and v == v then
		return v
	end
	local meta = if type(data.meta) == "table" then data.meta else {}
	return num(meta.activeSec, 0)
end

local function pruneCooldowns(w: { [string]: any }, now: number)
	for id, at in w.cooldowns do
		if type(at) ~= "number" or at <= now then
			w.cooldowns[id] = nil
		end
	end
end

-- Builds today's board when the workday (or the role) changed and drops expired offers. Replicates on change.
local function ensureBoard(player: Player, now: number): (Board.BoardState?, { [string]: any }?)
	local data = Deps.data(player)
	if not data then
		return nil, nil
	end
	local w = workOf(data)
	local who, career = Flow.who(data)
	local key, day = Board.dayKey(who, career, activeSeconds(player, data))
	local board: Board.BoardState = w.board
	local changed = false
	if board.key ~= key then
		local prevKey = board.key
		pruneCooldowns(w, now)
		local rng = Rng.new(Hash.u32("work-board", player.UserId, key))
		board = Board.build(if prevKey ~= "" then board else nil, infos, who, key, day, rng, w.cooldowns, now)
		w.board = board
		changed = true
		if prevKey ~= "" and #board.tasks > 0 then
			Deps.notify(player, Config.text("toast_new_day", { n = Board.remaining(board) }), "info")
		end
	end
	if Board.prune(board, now) then
		changed = true
	end
	if changed then
		Deps.replicate(player, "work")
	end
	return board, data
end

local function changed(player: Player)
	pcall(Net.fire, "Work.Changed", player)
end

---------------------------------------------------------------------------------------------------
-- Desks
---------------------------------------------------------------------------------------------------
local function companyNameOf(companyId: string): string?
	if type(Companies) == "table" and type(Companies.get) == "function" then
		local ok, def = pcall(Companies.get, companyId)
		if ok and type(def) == "table" and type(def.name) == "string" then
			return def.name
		end
	end
	return nil
end

local function mayUseDesk(player: Player, who: Board.Who, companyId: string?): boolean
	if companyId then
		local ok, yes = Deps.call("CareerService", "IsEmployeeOf", player, companyId)
		return ok and yes == true
	end
	return who.student or who.unemployed
end

local function deskNear(player: Player, who: Board.Who): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return false
	end
	local pos = root.Position
	local radius = Config.rewards.deskRadius
	for part in Prompts.desks() do
		if (part.Position - pos).Magnitude <= radius and mayUseDesk(player, who, Prompts.companyOf(part)) then
			return true
		end
	end
	return false
end

Core.TICK = TICK
Core.RECENT_KEPT = RECENT_KEPT
Core.MAX_ANSWER_KEYS = MAX_ANSWER_KEYS
Core.MAX_ANSWER_DEPTH = MAX_ANSWER_DEPTH
Core.MAX_OFFER_KEYS = MAX_OFFER_KEYS
Core.SALT = SALT
Core.modules = modules
Core.infos = infos
Core.states = states
Core.loadModules = loadModules
Core.stateOf = stateOf
Core.workOf = workOf
Core.activeSeconds = activeSeconds
Core.ensureBoard = ensureBoard
Core.changed = changed
Core.companyNameOf = companyNameOf
Core.mayUseDesk = mayUseDesk
Core.deskNear = deskNear

return Core
