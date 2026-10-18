--!strict
-- ProjectService/Handlers (server, runtime only): what each Project.* remote and the deal desk prompt do. Every
-- handler answers (true, value) or (false, errKey, vars?) and never throws for bad input (the remotes validate
-- arguments first; ProjectService wraps mutating calls in Core.exclusive).
--
--   Handlers.list(player)                          Project.List
--   Handlers.start(player, id)                     Project.Start (a run in progress resumes)
--   Handlers.view(player, id)                      Project.View
--   Handlers.act(player, id, answers, stageIndex?) Project.Act (grades the stage; the last one pays out)
--   Handlers.abandon(player, id)                   Project.Abandon
--   Handlers.prompt(player, prompt, companyId?)    the project_desk interact (employees only inside offices)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Hash = require(Shared.Util.Hash)
local Time = require(Shared.Util.Time)
local ProjectsFolder = Shared:WaitForChild("Logic"):WaitForChild("Projects")
local Registry = require(ProjectsFolder:WaitForChild("_registry"))
local Deps = require(script.Parent.Deps)
local Flow = require(script.Parent.Flow)
local Core = require(script.Parent.Core)

local Runs = Registry.Runs
local text = Registry.text
local num = Deps.num

local PROMPT_COOLDOWN = 1

local Handlers = {}

local function stringsOf(list: any, max: number): { string }
	local out: { string } = {}
	if type(list) == "table" then
		for _, line in list do
			if type(line) == "string" and #out < max then
				table.insert(out, line)
			end
		end
	end
	return out
end

-- The stage result the client may see (the module's Result minus anything unexpected).
local function stageResult(r: { [string]: any }): { [string]: any }
	local sections: { { [string]: any } } = {}
	if type(r.sections) == "table" then
		for _, s in r.sections do
			if type(s) == "table" then
				table.insert(sections, {
					kind = if type(s.kind) == "string" then s.kind else "",
					score = num(s.score, 0),
					correct = num(s.correct, 0),
					total = num(s.total, 0),
				})
			end
		end
	end
	return {
		stageId = if type(r.stageId) == "string" then r.stageId else "",
		stageTitle = if type(r.stageTitle) == "string" then r.stageTitle else "",
		score = math.floor(num(r.score, 0) + 0.5),
		feedback = stringsOf(r.feedback, 6),
		debrief = if type(r.debrief) == "string" then r.debrief else nil,
		done = r.done == true,
		quality = math.floor(num(r.quality, 0) + 0.5),
		nextStage = if type(r.nextStage) == "string" then r.nextStage else nil,
		sections = sections,
	}
end

local function seedFor(player: Player, id: string, record: Registry.Record): number
	return Hash.u32("project", player.UserId, id, record.attempts, Time.now(), os.clock())
end

function Handlers.list(player: Player): (boolean, any, any)
	local data = Deps.data(player)
	if not data then
		return false, "not_loaded", nil
	end
	local who = Flow.who(data)
	local now = Time.now()
	local m = Flow.mults(player, who, nil)
	local cards = Runs.list(Core.moduleList, data.projects, who, now, {
		payMult = m.payMult,
		xpMult = m.xpMult,
		eventMults = Flow.eventMults(Core.moduleList),
	})
	return true,
		{
			who = {
				employed = who.employed,
				student = who.student,
				fired = who.fired,
				status = who.status,
				track = who.track,
				rank = who.rank,
				title = if who.employed then Registry.rankTitle(who.track, who.rank) else nil,
				trackName = Core.trackName(who.track),
				company = if who.employed then Core.companyName(Core.careerCompany(data)) else nil,
			},
			cards = cards,
			activeCount = Core.activeCount(data),
			maxActive = Registry.TUNING.maxActive,
			now = now,
		},
		nil
end

function Handlers.start(player: Player, id: string): (boolean, any, any)
	local mod = Core.modules[id]
	if not mod then
		return false, "unknown", nil
	end
	local data = Deps.data(player)
	if not data then
		return false, "not_loaded", nil
	end
	local record = Core.recordOf(data, id)
	if Runs.stale(mod, record) then
		Core.cancelOne(player, id, record, "reset")
	end
	local who = Flow.who(data)
	local ctx = Flow.context(player, data, who)
	local now = Time.now()
	local others = Core.activeCount(data) - (if Runs.isActive(record) then 1 else 0)
	local ok, err, vars, resumed = Runs.start(mod, record, who, now, {
		seed = seedFor(player, id, record),
		ctx = ctx,
		activeCount = others,
		companyId = Core.careerCompany(data),
	})
	if not ok then
		if err == "broken" then
			Deps.warnOnce("start " .. id, if vars then vars.detail else nil)
			return false, "broken", nil
		end
		return false, err, vars
	end
	local view = Runs.publicView(mod, record, ctx, { resumed = resumed == true })
	if not view then
		Core.cancelOne(player, id, record, "reset")
		return false, "broken", nil
	end
	if not resumed then
		Deps.notify(player, text("toast_started", { title = mod.title }), "info")
		Core.ProjectStarted:Fire(player, id)
		Deps.audit(player, "project_start", { id = id })
	end
	return true, view, nil
end

function Handlers.view(player: Player, id: string): (boolean, any, any)
	local mod = Core.modules[id]
	if not mod then
		return false, "unknown", nil
	end
	local data = Deps.data(player)
	if not data then
		return false, "not_loaded", nil
	end
	local record = Core.recordOf(data, id)
	if record.state == nil then
		return false, "not_active", nil
	end
	if Runs.stale(mod, record) then
		Core.cancelOne(player, id, record, "reset")
		return false, "broken", nil
	end
	local who = Flow.who(data)
	local view = Runs.publicView(mod, record, Flow.context(player, data, who))
	if not view then
		if Runs.isActive(record) then
			Core.cancelOne(player, id, record, "reset")
			return false, "broken", nil
		end
		-- a finished run from an older version of the deal: nothing left to show
		record.state = nil
		return false, "not_active", nil
	end
	return true, view, nil
end

function Handlers.act(player: Player, id: string, answers: any, stageIndex: number?): (boolean, any, any)
	local mod = Core.modules[id]
	if not mod then
		return false, "unknown", nil
	end
	local data = Deps.data(player)
	if not data then
		return false, "not_loaded", nil
	end
	local record = Core.recordOf(data, id)
	if Runs.stale(mod, record) then
		Core.cancelOne(player, id, record, "reset")
		Core.changed(player, { id = id, reason = "reset" })
		return false, "broken", nil
	end
	local who = Flow.who(data)
	local ctx = Flow.context(player, data, who)
	local now = Time.now()
	local ok, err, result, completion = Runs.act(mod, record, answers, ctx, now, stageIndex)
	if not ok or not result then
		if err == "broken" then
			Deps.warnOnce("act " .. id, if result then result.detail else nil)
			Deps.audit(player, "project_cancel", { id = id, reason = "broken" })
			Core.changed(player, { id = id, reason = "reset" })
		end
		return false, err or "generic", nil
	end
	local res = stageResult(result)
	if res.stageId ~= "" then
		Flow.stageStats(player, mod, res.stageId, res.score)
	end
	local rewards: Flow.Rewards? = nil
	if completion then
		local paid = Flow.reward(player, mod, completion, who)
		rewards = paid
		record.lastRewards = {
			xp = paid.xp,
			xpCapped = paid.xpCapped,
			pay = paid.pay,
			paid = paid.paid,
			rep = paid.rep,
			repeatRun = paid.repeatRun,
			repeatPct = paid.repeatPct,
			pulled = paid.pulled,
			plaque = paid.plaque,
			stats = table.clone(paid.stats),
		}
		local outcome = completion.outcome
		Core.ProjectCompleted:Fire(player, id, {
			quality = completion.quality,
			closed = completion.closed,
			dealName = completion.dealName,
			signature = mod.signature == true,
			repeatRun = completion.repeatRun,
			xp = paid.xp,
			pay = paid.pay,
			rep = paid.rep,
			plaque = paid.plaque,
			outcomeScore = if outcome then num(outcome.score, 0) else 0,
		})
		Deps.audit(player, "project_done", {
			id = id,
			quality = completion.quality,
			closed = completion.closed,
			xp = paid.xp,
			pay = paid.pay,
		})
		-- CareerService saves after recording a plaque; a pulled deal still deserves a save
		if not paid.plaque then
			Deps.save(player, "project")
		end
		Core.changed(player, { id = id, reason = "completed" })
	end
	local view = Runs.publicView(mod, record, ctx)
	return true, { result = res, view = view, rewards = rewards, completed = completion ~= nil }, nil
end

function Handlers.abandon(player: Player, id: string): (boolean, any, any)
	local mod = Core.modules[id]
	if not mod then
		return false, "unknown", nil
	end
	local data = Deps.data(player)
	if not data then
		return false, "not_loaded", nil
	end
	local record = Core.recordOf(data, id)
	if not Core.cancelOne(player, id, record, "abandoned") then
		return false, "not_active", nil
	end
	Deps.notify(player, text("toast_abandoned"), "info")
	return true, true, nil
end

---------------------------------------------------------------------------------------------------
-- Deal desk prompts
---------------------------------------------------------------------------------------------------
local function isEmployeeOf(player: Player, data: { [string]: any }, companyId: string): boolean
	local ok, yes = Deps.call("CareerService", "IsEmployeeOf", player, companyId)
	if ok then
		return yes == true
	end
	-- careerPath missing: fall back to the saved career record
	local who = Flow.who(data)
	return who.employed and Core.careerCompany(data) == companyId
end

function Handlers.prompt(player: Player, _prompt: ProximityPrompt, companyId: string?)
	local st = Core.stateOf(player)
	local clock = os.clock()
	if clock - st.lastPrompt < PROMPT_COOLDOWN then
		return
	end
	st.lastPrompt = clock
	local data = Deps.data(player)
	if not data then
		Deps.notify(player, text("err_not_loaded"), "warn")
		return
	end
	if companyId and not isEmployeeOf(player, data, companyId) then
		local name = Core.companyName(companyId)
		Deps.notify(
			player,
			if name then text("employees_only", { company = name }) else text("employees_only_generic"),
			"warn"
		)
		return
	end
	local who = Flow.who(data)
	if not who.employed then
		Deps.notify(player, text("no_job"), "warn")
		return
	end
	pcall(Net.fire, "Project.Open", player, { source = "desk", filter = who.track })
end

return Handlers
