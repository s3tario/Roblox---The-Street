--!strict
-- WorkService/Runner (server, runtime only): one task attempt from start to reward.
--   Runner.start(player, taskId, opts?) -> (true, ActiveView) | (false, errKey)
--       resumes the attempt in progress for the same task; opts = { server?, source? } (server skips the start
--       cooldown, for WorkService:StartTask)
--   Runner.submit(player, instanceId, answers) -> (true, ResultView) | (false, errKey)
--       Guard.map'd answers; late work is graded but pays less; a grading error voids the attempt with an apology
--   Runner.abandon(player, instanceId?) -> (true) | (false, errKey)
--   Runner.activeView(active) -> the client's view of an attempt (payload, timer; never the secret)

local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Guard = require(Shared.Guard)
local Rng = require(Shared.Util.Rng)
local Hash = require(Shared.Util.Hash)
local Time = require(Shared.Util.Time)
local Config = require(Shared.Config.Tasks)
local SharedTasks = Shared:WaitForChild("Logic"):WaitForChild("Tasks"):WaitForChild("_shared")
local Board = require(SharedTasks:WaitForChild("Board"))
local Rewards = require(SharedTasks:WaitForChild("Rewards"))
local Kinds = require(SharedTasks:WaitForChild("Kinds"))
local Deps = require(script.Parent.Deps)
local Flow = require(script.Parent.Flow)
local Core = require(script.Parent.Core)

type Active = Core.Active

local Runner = {}

local num = Deps.num
local modules = Core.modules
local states = Core.states
local stateOf = Core.stateOf
local workOf = Core.workOf
local ensureBoard = Core.ensureBoard
local deskNear = Core.deskNear
local SALT = Core.SALT
local RECENT_KEPT = Core.RECENT_KEPT
local MAX_ANSWER_KEYS = Core.MAX_ANSWER_KEYS
local MAX_ANSWER_DEPTH = Core.MAX_ANSWER_DEPTH

local function activeView(a: Active): { [string]: any }
	local kind = a.payload.kind
	local how = Config.kinds[kind]
	return {
		instanceId = a.instanceId,
		taskId = a.taskId,
		title = a.payload.title,
		kind = kind,
		category = a.mod.category,
		payload = a.payload,
		startedAt = a.startedAt,
		limit = a.limit,
		grace = a.grace,
		endsAt = a.startedAt + a.limit,
		how = if how then how.how else "",
		desk = a.desk,
		answerTotal = Kinds.answerTotal(a.payload),
	}
end

type StartOpts = { server: boolean?, source: string? }

local function start(player: Player, taskId: string, opts: StartOpts?): (boolean, any)
	local mod = modules[taskId]
	if not mod then
		return false, "unknown_task"
	end
	local o: StartOpts = opts or {}
	local st = stateOf(player)
	local now = Time.now()
	local current = st.active
	if current then
		if Rewards.expired(now - current.startedAt, current.limit) then
			st.active = nil
		elseif current.taskId == taskId then
			return true, activeView(current) -- resume the attempt in progress
		else
			return false, "busy"
		end
	end
	if not o.server and os.clock() - st.lastStart < Config.timing.startCooldown then
		return false, "rate_limited"
	end
	local board, data = ensureBoard(player, now)
	if not board or not data then
		return false, "not_loaded"
	end
	local w = workOf(data)
	local entry = Board.find(board, taskId)
	if not entry then
		return false, "not_on_board"
	end
	if entry.done then
		return false, "done"
	end
	if entry.offered ~= true and num(w.cooldowns[taskId], 0) > now then
		return false, "cooldown"
	end
	local who = Flow.who(data)
	local ctx, effects = Flow.context(player, data, mod, entry, who)
	w.attempts += 1
	local rng = Rng.new(Hash.u32(SALT, player.UserId, w.attempts, taskId, math.floor(now * 1000)))
	local okGen, payload, secret = pcall(mod.generate, rng, ctx)
	if okGen and type(payload) == "table" and (type(payload.title) ~= "string" or payload.title == "") then
		payload.title = mod.title
	end
	local valid, why = false, nil
	if okGen and type(payload) == "table" then
		valid, why = Kinds.validate(payload)
		if valid and not Kinds.plain(secret) then
			valid, why = false, "secret is not plain data"
		end
	else
		why = tostring(payload)
	end
	if not valid then
		Deps.warnOnce("generate " .. taskId, why)
		Deps.audit(player, "work_generate_failed", { taskId = taskId, err = string.sub(tostring(why), 1, 200) })
		return false, "generate"
	end
	local limit, grace = Flow.timer(player, mod, effects)
	local atDesk = deskNear(player, who)
	local active: Active = {
		instanceId = HttpService:GenerateGUID(false),
		taskId = taskId,
		mod = mod,
		payload = payload,
		secret = secret,
		ctx = ctx,
		startedAt = now,
		limit = limit,
		grace = grace,
		desk = atDesk,
		who = who,
		mults = Flow.multipliers(player, who, atDesk),
		source = o.source or (if entry.offered then entry.source or "offer" else "board"),
		entryData = if type(entry.data) == "table" then table.clone(entry.data) else nil,
	}
	st.active = active
	st.lastStart = os.clock()
	Deps.replicate(player, "work")
	Core.TaskStarted:Fire(player, taskId, active.instanceId)
	return true, activeView(active)
end

local function cooldownMult(): number
	local ok, v = Deps.call("EventService", "GetModifier", "taskCooldownMult")
	if ok and type(v) == "number" and v == v and v > 0 then
		return math.clamp(v, 0.1, 5)
	end
	return 1
end

local function record(w: { [string]: any }, mod: any, quality: number, onTime: boolean, now: number)
	local id = mod.id
	w.completed[id] = num(w.completed[id], 0) + 1
	w.quality[id] = quality
	w.best[id] = math.max(num(w.best[id], 0), quality)
	if mod.core == true then
		w.coreDone += 1
	end
	w.lastTaskAt = now
	if num(mod.cooldown, 0) > 0 then
		w.cooldowns[id] = now + mod.cooldown * cooldownMult()
	end
	local totals = w.totals
	totals.tasks = num(totals.tasks, 0) + 1
	if not onTime then
		totals.late = num(totals.late, 0) + 1
	end
end

local function speedCheck(player: Player, a: Active, quality: number, elapsed: number)
	local items = Kinds.answerTotal(a.payload)
	if quality >= 90 and items > 0 and elapsed < items * Config.timing.minPerItem then
		Deps.call("AntiCheatService", "Flag", player, "work_speed", {
			taskId = a.taskId,
			quality = quality,
			elapsed = math.floor(elapsed * 10) / 10,
			items = items,
		})
	end
end

local function submit(player: Player, instanceId: string, rawAnswers: any): (boolean, any)
	local st = states[player]
	local a = if st then st.active else nil
	if not st or not a then
		return false, "no_active"
	end
	if a.instanceId ~= instanceId then
		return false, "wrong_task"
	end
	local answers: any = {}
	if rawAnswers ~= nil then
		local checked = Guard.map(rawAnswers, MAX_ANSWER_KEYS, MAX_ANSWER_DEPTH)
		if checked == nil then
			return false, "bad_answers" -- the attempt stays open so the player can resend
		end
		answers = checked
	end
	local now = Time.now()
	local elapsed = math.max(0, now - a.startedAt)
	st.active = nil -- claim the attempt: a second submit finds nothing
	if Rewards.expired(elapsed, a.limit) then
		Deps.notify(player, Config.text("toast_expired"), "warn")
		return false, "expired"
	end
	local okGrade, graded = pcall(a.mod.grade, a.secret, answers, a.ctx)
	local quality = if okGrade and type(graded) == "table" then graded.quality else nil
	if type(quality) ~= "number" or quality ~= quality then
		Deps.warnOnce("grade " .. a.taskId, graded)
		Deps.audit(player, "work_grade_failed", { taskId = a.taskId, err = string.sub(tostring(graded), 1, 200) })
		Deps.notify(player, Config.text("toast_void"), "warn")
		return false, "void"
	end
	local q = math.floor(math.clamp(quality, 0, 100) + 0.5)
	local onTime = Rewards.onTime(elapsed, a.limit, a.grace)
	local mod = a.mod

	-- 1. the player's work record (owned here), before anything that could fail elsewhere
	local data = Deps.data(player)
	local w = if data then workOf(data) else nil
	local entry: Board.Entry? = nil
	if w then
		local e = Board.find(w.board, a.taskId)
		if e and not e.done then
			entry = e
			Board.complete(w.board, a.taskId, q, now)
		end
		record(w, mod, q, onTime, now)
	end

	-- 2. rewards through the other features (guarded)
	local reward = Flow.reward(player, mod, {
		quality = q,
		onTime = onTime,
		who = a.who,
		mults = a.mults,
		entry = entry,
		taskId = a.taskId,
	})
	if w then
		w.totals.xp = num(w.totals.xp, 0) + reward.xp
		w.totals.pay = num(w.totals.pay, 0) + reward.pay
		table.insert(w.recent, 1, {
			taskId = a.taskId,
			quality = q,
			xp = reward.xp,
			pay = reward.pay,
			onTime = onTime,
			at = math.floor(now),
		})
		while #w.recent > RECENT_KEPT do
			table.remove(w.recent)
		end
		Deps.replicate(player, "work")
	end
	speedCheck(player, a, q, elapsed)

	local feedback: { string } = {}
	if type(graded.feedback) == "table" then
		for _, line in graded.feedback do
			if type(line) == "string" and #feedback < 6 then
				table.insert(feedback, line)
			end
		end
	end
	local sections: { any } = {}
	if type(graded.sections) == "table" then
		for _, s in graded.sections do
			if type(s) == "table" then
				table.insert(sections, {
					kind = tostring(s.kind),
					score = num(s.score, 0),
					correct = num(s.correct, 0),
					total = num(s.total, 0),
				})
			end
		end
	end
	local correct = math.floor(num(graded.correct, 0))
	local total = math.floor(num(graded.total, 0))

	Core.TaskCompleted:Fire(player, a.taskId, {
		quality = q,
		onTime = onTime,
		xp = reward.xp,
		pay = reward.pay,
		category = mod.category,
		stats = table.clone(mod.stats),
		core = mod.core == true,
		clientFacing = mod.clientFacing == true,
		source = a.source,
		data = a.entryData,
		correct = correct,
		total = total,
		instanceId = a.instanceId,
	})
	Deps.notify(player, Flow.toast(mod, q, reward), "xp")
	if not onTime then
		Deps.notify(player, Config.text("toast_late"), "warn")
	end
	if reward.rep > 0 then
		Deps.notify(player, Config.text("toast_client_rep", { rep = reward.rep }), "good")
	end
	return true,
		{
			instanceId = a.instanceId,
			taskId = a.taskId,
			title = a.payload.title,
			category = mod.category,
			quality = q,
			correct = correct,
			total = total,
			feedback = feedback,
			sections = sections,
			onTime = onTime,
			elapsed = math.floor(elapsed),
			limit = a.limit,
			xp = reward.xp,
			xpCapped = reward.xpCapped,
			pay = reward.pay,
			paid = reward.paid,
			rep = reward.rep,
			stats = reward.stats,
			desk = a.desk,
		}
end

local function abandon(player: Player, instanceId: string?): (boolean, any)
	local st = states[player]
	if not st or not st.active then
		return true, nil
	end
	if instanceId ~= nil and st.active.instanceId ~= instanceId then
		return false, "wrong_task"
	end
	st.active = nil
	return true, nil
end

Runner.start = start
Runner.submit = submit
Runner.abandon = abandon
Runner.activeView = activeView

return Runner
