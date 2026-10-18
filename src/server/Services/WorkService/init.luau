--!strict
-- WorkService (server, owned by `work`; docs/contracts.md §8, design v3 §3 and §6): the daily work board and the
-- graded tasks behind it. Server-authoritative: payloads are generated here, the answer key never leaves the server,
-- and every reward is computed here.
--
-- Modules: every ModuleScript in Shared/Logic/Tasks (names starting with "_" are helpers) that passes
-- Logic/Tasks/_shared/Catalog.check. A broken module is skipped with a warning; the rest keep working.
--
-- The board (data.work.board, replicated): each workday (8 active minutes; the career week for employees, lifetime
-- active time for students) draws 3-5 tasks valid for the player's track and rank (campus work while a student,
-- practice and re-entry while between jobs), plus anything other features offered (interviews, events). Unfinished
-- core tasks carry over until done. One task is active at a time; it lives in server memory only.
--
-- Remotes (RemoteFunctions return (true, value) or (false, errKey); Config/Tasks.ERRORS maps errKey to text):
--   Work.Board()                       -> board view (cards, day label, desk bonus, the active task to resume)
--   Work.Start(taskId)                 -> active view { instanceId, taskId, title, payload, startedAt, limit, endsAt }
--   Work.Submit(instanceId, answers)   -> result { quality, correct, total, feedback, onTime, xp, pay, rep, ... }
--   Work.Abandon(instanceId)           -> true
--   Work.Open (server -> client)       open the Work screen: { source = "desk" } or { instanceId, taskId }
--   Work.Changed (server -> client)    the board or the active task changed outside a remote call: refetch
-- API (contracts §8):
--   WorkService:OfferTask(player, taskId, opts?) -> boolean
--       opts = { source?, data? = { companyId?, companyName?, label?, ... } (plain, saved), ttl?, expiresAt?, silent? }
--   WorkService:StartTask(player, taskId, opts?) -> (instanceId?, err?)   offers it if needed, starts it, and opens
--       the Work screen (opts.open = false to skip)
--   WorkService.TaskCompleted : Signal(player, taskId, result)
--       result = { quality, onTime, xp, pay, category, stats, core, clientFacing, source?, data?, correct, total }
--   WorkService:GetLastTaskTime(player) -> number?
-- Extras: TaskStarted(player, taskId, instanceId), TaskOffered(player, taskId, entry), :IsWorking(player),
--   :IsAtDesk(player), :OpenFor(player, args?), :GetTaskModule(taskId), :ListTasks() -> { Catalog.Summary }
-- Parts: Deps (guarded cross-feature calls), Core (state, data, board upkeep, desks), Flow (task context and
--   rewards), Runner (start/submit/abandon), View (the board view), Prompts (work_desk prompts).
-- Interact: "work_desk" (WorkService/Prompts). Office desks are employees-only; campus desks serve students (and
-- players between jobs). The board itself also opens from the menu anywhere; working at a desk you may use adds
-- the desk XP bonus.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local Time = require(Shared.Util.Time)
local Config = require(Shared.Config.Tasks)
local SharedTasks = Shared:WaitForChild("Logic"):WaitForChild("Tasks"):WaitForChild("_shared")
local Board = require(SharedTasks:WaitForChild("Board"))
local Rewards = require(SharedTasks:WaitForChild("Rewards"))
local Catalog = require(SharedTasks:WaitForChild("Catalog"))
local Deps = require(script.Deps)
local Flow = require(script.Flow)
local Prompts = require(script.Prompts)
local Core = require(script.Core)
local Runner = require(script.Runner)
local View = require(script.View)

local WorkService = {
	Name = "WorkService",
	Priority = 40,
	TaskCompleted = Core.TaskCompleted, -- (player, taskId, result)
	TaskStarted = Core.TaskStarted, -- (player, taskId, instanceId)
	TaskOffered = Core.TaskOffered, -- (player, taskId, entry)
}

local num = Deps.num
local modules = Core.modules
local infos = Core.infos
local states = Core.states
local stateOf = Core.stateOf
local ensureBoard = Core.ensureBoard
local changed = Core.changed
local companyNameOf = Core.companyNameOf
local mayUseDesk = Core.mayUseDesk
local deskNear = Core.deskNear
local start = Runner.start
local submit = Runner.submit
local abandon = Runner.abandon
local boardView = View.board
local TICK = Core.TICK
local MAX_OFFER_KEYS = Core.MAX_OFFER_KEYS

---------------------------------------------------------------------------------------------------
-- Desk prompts
---------------------------------------------------------------------------------------------------
local function onDeskPrompt(player: Player, _part: BasePart, companyId: string?)
	local st = stateOf(player)
	local clock = os.clock()
	if clock - st.lastPrompt < 1 then
		return
	end
	st.lastPrompt = clock
	local data = Deps.data(player)
	if not data then
		Deps.notify(player, Config.text("err_not_loaded"), "warn")
		return
	end
	local who = Flow.who(data)
	if companyId then
		if not mayUseDesk(player, who, companyId) then
			local name = companyNameOf(companyId)
			local text = if who.student
				then (if name
					then Config.text("office_students", { company = name })
					else Config.text("employees_only_generic"))
				else (if name
					then Config.text("employees_only", { company = name })
					else Config.text("employees_only_generic"))
			Deps.notify(player, text, "warn")
			return
		end
	elseif not who.student and not who.unemployed then
		local ok, company = Deps.call("CareerService", "GetCompany", player)
		local name = if ok and type(company) == "table" and type(company.name) == "string" then company.name else nil
		Deps.notify(
			player,
			if name
				then Config.text("campus_students_only", { company = name })
				else Config.text("campus_students_only_generic"),
			"warn"
		)
		return
	end
	pcall(Net.fire, "Work.Open", player, { source = "desk" })
end

---------------------------------------------------------------------------------------------------
-- Public API (contracts §8)
---------------------------------------------------------------------------------------------------
local function sanitizeData(raw: any): { [string]: any }?
	if type(raw) ~= "table" then
		return nil
	end
	local out: { [string]: any } = {}
	local n = 0
	for k, v in raw do
		if type(k) == "string" and #k <= 32 and n < MAX_OFFER_KEYS then
			local t = type(v)
			if (t == "string" and #v <= 200) or t == "boolean" or (t == "number" and v == v and math.abs(v) < 1e12) then
				out[k] = v
				n += 1
			end
		end
	end
	return if n > 0 then out else nil
end

function WorkService:OfferTask(player: Player, taskId: string, opts: { [string]: any }?): boolean
	local mod = if type(taskId) == "string" then modules[taskId] else nil
	if not mod or typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	local now = Time.now()
	local board = ensureBoard(player, now)
	if not board then
		return false
	end
	local o: { [string]: any } = if type(opts) == "table" then opts else {}
	local ttl = o.ttl
	local expiresAt = o.expiresAt
	local entry = Board.offer(board, taskId, {
		source = if type(o.source) == "string" then string.sub(o.source, 1, 40) else nil,
		data = sanitizeData(o.data),
		ttl = if type(ttl) == "number" and ttl == ttl and ttl > 0 then math.min(ttl, 7 * 24 * 3600) else nil,
		expiresAt = if type(expiresAt) == "number"
				and expiresAt == expiresAt
				and expiresAt > now
			then expiresAt
			else nil,
	}, now)
	Deps.replicate(player, "work")
	if o.silent ~= true then
		Deps.notify(player, Config.text("toast_offered", { title = mod.title }), "info")
	end
	changed(player)
	WorkService.TaskOffered:Fire(player, taskId, table.clone(entry))
	return true
end

function WorkService:StartTask(player: Player, taskId: string, opts: { [string]: any }?): (string?, string?)
	if type(taskId) ~= "string" or not modules[taskId] then
		return nil, "unknown_task"
	end
	local o: { [string]: any } = if type(opts) == "table" then opts else {}
	local data = Deps.data(player)
	if not data then
		return nil, "not_loaded"
	end
	local board = ensureBoard(player, Time.now())
	local entry = if board then Board.find(board, taskId) else nil
	if not entry or entry.done or o.data ~= nil then
		local offerOpts = table.clone(o)
		offerOpts.silent = true
		if not WorkService:OfferTask(player, taskId, offerOpts) then
			return nil, "not_loaded"
		end
	end
	local ok, view =
		start(player, taskId, { server = true, source = if type(o.source) == "string" then o.source else nil })
	if not ok then
		return nil, view
	end
	if o.open ~= false then
		pcall(Net.fire, "Work.Open", player, { instanceId = view.instanceId, taskId = taskId })
	end
	return view.instanceId, nil
end

function WorkService:GetLastTaskTime(player: Player): number?
	local data = Deps.data(player)
	if not data or type(data.work) ~= "table" then
		return nil
	end
	local at = num(data.work.lastTaskAt, 0)
	return if at > 0 then at else nil
end

function WorkService:IsWorking(player: Player): boolean
	local st = states[player]
	return st ~= nil and st.active ~= nil
end

function WorkService:IsAtDesk(player: Player): boolean
	local data = Deps.data(player)
	if not data then
		return false
	end
	return deskNear(player, (Flow.who(data)))
end

function WorkService:OpenFor(player: Player, args: { [string]: any }?)
	pcall(Net.fire, "Work.Open", player, if type(args) == "table" then args else {})
end

function WorkService:GetTaskModule(taskId: string): any
	return if type(taskId) == "string" then modules[taskId] else nil
end

function WorkService:ListTasks(): { Catalog.Summary }
	local out: { Catalog.Summary } = {}
	for _, info in infos do
		table.insert(out, Catalog.summary(modules[info.id]))
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
local function tickPlayer(player: Player)
	local now = Time.now()
	ensureBoard(player, now)
	local st = states[player]
	local a = if st then st.active else nil
	if st and a and Rewards.expired(now - a.startedAt, a.limit) then
		st.active = nil
		Deps.notify(player, Config.text("toast_expired"), "warn")
		changed(player)
	end
end

function WorkService:Init()
	Core.loadModules()
	Net.declare("Work.Open")
	Net.declare("Work.Changed")
	Net.handle("Work.Board", function(player: Player)
		return boardView(player)
	end, { rate = 2, burst = 6 })
	Net.handle("Work.Start", function(player: Player, taskId: any)
		local id = Guard.id(taskId)
		if not id then
			return false, "unknown_task"
		end
		return start(player, id, nil)
	end, { rate = 1, burst = 3 })
	Net.handle("Work.Submit", function(player: Player, instanceId: any, answers: any)
		local id = Guard.id(instanceId)
		if not id then
			return false, "wrong_task"
		end
		return submit(player, id, answers)
	end, { rate = 1, burst = 3 })
	Net.handle("Work.Abandon", function(player: Player, instanceId: any)
		return abandon(player, Guard.id(instanceId))
	end, { rate = 1, burst = 4 })
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
end

function WorkService:Start()
	Prompts.start(onDeskPrompt)
	local function refresh(player: Player)
		local ok, err = pcall(ensureBoard :: any, player, Time.now())
		if not ok then
			Deps.warnOnce("board refresh", err)
		end
		changed(player)
	end
	Deps.connect("DataService", "ProfileLoaded", function(player: Player)
		refresh(player)
	end)
	-- a promotion, a hire or a firing changes which tasks belong on the board
	Deps.connect("CareerService", "RoleChanged", function(player: Player)
		task.defer(refresh, player)
	end)
	Deps.connect("RebirthService", "Rebirthed", function(player: Player)
		local st = states[player]
		if st then
			st.active = nil
		end
		task.defer(refresh, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(refresh, player)
	end
	while true do
		task.wait(TICK)
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(tickPlayer :: any, player)
			if not ok then
				Deps.warnOnce("tick", err)
			end
		end
	end
end

return WorkService
