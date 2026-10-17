--!strict
-- The free re-entry project (owned by `careerPath`; spec §6 "Recovery", contracts §9 project shape). PURE: no
-- services, no clocks, no Instances. CareerService runs it from the Career Services screen for players between
-- jobs; passing (60+ overall) rejoins the former firm one rank lower.
--
--   reentry.new(rng, ctx?) -> State          generates all three stages up front (the state is saved as is)
--   reentry.view(state, ctx?) -> View        { stage, stageIndex, stageCount, summary, payload } (no answers)
--   reentry.act(state, answers, ctx?) -> (state, Result)   grades the current stage and moves on
--   reentry.score(state) -> { quality, metrics }
--
-- Stages: a case study (mcq), a risk review (mcq) and a hiring-committee interview (dialogue). When the work
-- feature ships the task modules "reentry_case_study" / "mock_interview", ctx.tasks[taskId] supplies them and the
-- stage uses the task's own generate/grade, but only when ctx.canRender(kind) says the client can draw its
-- payload and the payload/secret are plain data (they are saved with the career).
--   ctx = { tasks = { [taskId] = TaskModule }?, canRender = (kind) -> boolean?, taskCtx = {...}?,
--           charismaBonus = 0..8? }

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Content = require(script.Parent.Parent.Parent.Config.Tracks.Reentry)

export type Stage = {
	id: string,
	kind: string,
	taskId: string?,
	payload: { [string]: any },
	secret: { [string]: any },
	score: number?,
	feedback: { string }?,
}
export type State = {
	version: number,
	stageIndex: number,
	stages: { Stage },
	done: boolean,
	passed: boolean,
	quality: number,
}
export type Ctx = {
	tasks: { [string]: any }?,
	canRender: ((kind: string) -> boolean)?,
	taskCtx: { [string]: any }?,
	charismaBonus: number?,
}
export type View = {
	stage: { id: string, title: string },
	stageIndex: number,
	stageCount: number,
	summary: string,
	payload: { [string]: any }?,
	done: boolean,
	passed: boolean,
	quality: number,
	scores: { number },
}
export type Result = {
	ok: boolean,
	err: string?,
	stageId: string?,
	score: number,
	feedback: { string },
	done: boolean,
	passed: boolean,
	quality: number,
}

local reentry = {
	id = "reentry",
	title = Content.title,
	track = nil :: string?,
	ranks = nil :: { number }?,
	signature = false,
	stages = Content.stages,
	PASS = Content.pass,
	TASKS = { case_study = "reentry_case_study", interview = "mock_interview" } :: { [string]: string },
}

local function stageDef(id: string): { [string]: any }
	for _, s in Content.stages do
		if s.id == id then
			return s
		end
	end
	return Content.stages[1]
end

-- Plain, saveable data only: tables of strings/numbers/booleans with string or integer keys.
local function plain(v: any, depth: number, budget: { n: number }): boolean
	budget.n += 1
	if budget.n > 600 or depth > 8 then
		return false
	end
	local t = type(v)
	if t == "string" then
		return #v <= 2000
	elseif t == "number" then
		return v == v and v ~= math.huge and v ~= -math.huge
	elseif t == "boolean" then
		return true
	elseif t == "table" then
		if getmetatable(v) ~= nil then
			return false
		end
		for k, x in v do
			local kt = type(k)
			if kt ~= "string" and not (kt == "number" and k == math.floor(k)) then
				return false
			end
			if not plain(x, depth + 1, budget) then
				return false
			end
		end
		return true
	end
	return false
end

local function mcqStage(rng: Rng.Rng, id: string, bank: { any }, count: number): Stage
	local def = stageDef(id)
	local picks = rng:shuffle(table.clone(bank))
	local questions = {}
	local answers: { [string]: number } = {}
	local explain: { [string]: string } = {}
	for i = 1, math.min(count, #picks) do
		local q = picks[i]
		local order = rng:shuffle({ 1, 2, 3, 4 })
		local options: { string } = {}
		local correct = 1
		for displayIndex, original in order do
			options[displayIndex] = q.options[original]
			if original == q.correct then
				correct = displayIndex
			end
		end
		table.insert(questions, { id = q.id, text = q.text, options = options })
		answers[q.id] = correct
		explain[q.id] = q.explain
	end
	return {
		id = id,
		kind = "mcq",
		payload = { kind = "mcq", title = def.title, prompt = def.prompt, questions = questions },
		secret = { answers = answers, explain = explain },
	}
end

local function interviewStage(rng: Rng.Rng, count: number): Stage
	local def = stageDef("interview")
	local picks = rng:shuffle(table.clone(Content.interview))
	local lines = {}
	local scores: { [string]: { [string]: number } } = {}
	for i = 1, math.min(count, #picks) do
		local line = picks[i]
		local order = rng:shuffle({ 1, 2, 3, 4 })
		local options = {}
		local lineScores: { [string]: number } = {}
		for _, original in order do
			local opt = line.options[original]
			local optId = "o" .. original
			table.insert(options, { id = optId, text = opt.text })
			lineScores[optId] = opt.score
		end
		table.insert(lines, { id = line.id, text = line.text, options = options })
		scores[line.id] = lineScores
	end
	return {
		id = "interview",
		kind = "dialogue",
		payload = {
			kind = "dialogue",
			title = def.title,
			prompt = def.prompt,
			speaker = Content.speaker,
			lines = lines,
		},
		secret = { scores = scores },
	}
end

-- A stage built from the work feature's task module, when it exists and its payload is usable here.
local function taskStage(rng: Rng.Rng, stageId: string, ctx: Ctx?): Stage?
	local c: Ctx = ctx or {}
	local taskId = reentry.TASKS[stageId]
	local tasks = c.tasks
	local mod = if taskId and tasks then tasks[taskId] else nil
	if type(mod) ~= "table" or type(mod.generate) ~= "function" or type(mod.grade) ~= "function" then
		return nil
	end
	local ok, payload, secret = pcall(mod.generate, rng:clone(), c.taskCtx or {})
	if not ok or type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return nil
	end
	local canRender = c.canRender
	if not canRender or not canRender(payload.kind) then
		return nil
	end
	local sec = if type(secret) == "table" then secret else {}
	if not plain(payload, 1, { n = 0 }) or not plain(sec, 1, { n = 0 }) then
		return nil
	end
	local def = stageDef(stageId)
	if type(payload.title) ~= "string" then
		payload.title = def.title
	end
	return { id = stageId, kind = payload.kind, taskId = taskId, payload = payload, secret = sec }
end

function reentry.new(rng: Rng.Rng, ctx: Ctx?): State
	local stages: { Stage } = {}
	for _, def in Content.stages do
		local stage: Stage? = taskStage(rng, def.id, ctx)
		if not stage then
			if def.id == "interview" then
				stage = interviewStage(rng, def.count)
			elseif def.id == "risk_review" then
				stage = mcqStage(rng, def.id, Content.riskReview, def.count)
			else
				stage = mcqStage(rng, def.id, Content.caseStudy, def.count)
			end
		end
		table.insert(stages, stage :: Stage)
	end
	return { version = 1, stageIndex = 1, stages = stages, done = false, passed = false, quality = 0 }
end

local function scoresOf(state: State): { number }
	local out: { number } = {}
	for _, s in state.stages do
		if type(s.score) == "number" then
			table.insert(out, s.score)
		end
	end
	return out
end

function reentry.view(state: State, _ctx: Ctx?): View
	local count = #state.stages
	local index = math.clamp(state.stageIndex, 1, math.max(1, count))
	local stage = state.stages[index]
	local def = stageDef(if stage then stage.id else "case_study")
	return {
		stage = { id = def.id, title = def.title },
		stageIndex = index,
		stageCount = count,
		summary = Content.summary,
		payload = if stage and not state.done then stage.payload else nil,
		done = state.done,
		passed = state.passed,
		quality = state.quality,
		scores = scoresOf(state),
	}
end

local function gradeMcq(stage: Stage, answers: any): (number, { string })
	local key = stage.secret.answers
	local explain = stage.secret.explain or {}
	local total, correct = 0, 0
	local notes: { string } = {}
	if type(key) ~= "table" then
		return 0, notes
	end
	for qid, right in key do
		total += 1
		local given = if type(answers) == "table" then answers[qid] else nil
		if type(given) == "number" and given == right then
			correct += 1
		elseif type(explain[qid]) == "string" then
			table.insert(notes, explain[qid])
		end
	end
	if total == 0 then
		return 0, notes
	end
	return correct / total * 100, notes
end

local function gradeDialogue(stage: Stage, answers: any, ctx: Ctx?): (number, { string })
	local scores = stage.secret.scores
	if type(scores) ~= "table" then
		return 0, {}
	end
	local total, n = 0, 0
	for lineId, opts in scores do
		n += 1
		local given = if type(answers) == "table" then answers[lineId] else nil
		local s = if type(given) == "string" and type(opts) == "table" then opts[given] else nil
		total += if type(s) == "number" then s else 0
	end
	if n == 0 then
		return 0, {}
	end
	local bonus = if ctx and type(ctx.charismaBonus) == "number" then math.clamp(ctx.charismaBonus, 0, 8) else 0
	local quality = math.clamp(total / n + bonus, 0, 100)
	local fb = Content.feedback
	return quality, { if quality >= 70 then fb.interviewGood else fb.interviewWeak }
end

function reentry.act(state: State, answers: any, ctx: Ctx?): (State, Result)
	local result: Result = {
		ok = false,
		err = nil,
		stageId = nil,
		score = 0,
		feedback = {},
		done = state.done,
		passed = state.passed,
		quality = state.quality,
	}
	if state.done then
		result.err = "done"
		return state, result
	end
	local stage = state.stages[state.stageIndex]
	if not stage then
		result.err = "no_stage"
		return state, result
	end
	local score: number
	local notes: { string }
	if stage.taskId then
		local tasks = if ctx then ctx.tasks else nil
		local mod = if tasks then tasks[stage.taskId] else nil
		local graded: any = nil
		if type(mod) == "table" and type(mod.grade) == "function" then
			local ok, res = pcall(mod.grade, stage.secret, answers, (ctx and ctx.taskCtx) or {})
			graded = if ok then res else nil
		end
		if type(graded) == "table" and type(graded.quality) == "number" then
			score = math.clamp(graded.quality, 0, 100)
			notes = {}
			if type(graded.feedback) == "string" then
				table.insert(notes, graded.feedback)
			elseif type(graded.feedback) == "table" then
				for _, line in graded.feedback do
					if type(line) == "string" and #notes < 3 then
						table.insert(notes, line)
					end
				end
			end
		else
			-- the task module disappeared between sessions: give the stage the passing mark rather than a dead end
			score, notes = reentry.PASS, {}
		end
	elseif stage.kind == "dialogue" then
		score, notes = gradeDialogue(stage, answers, ctx)
	else
		score, notes = gradeMcq(stage, answers)
	end
	score = math.floor(score + 0.5)
	stage.score = score
	local fb = Content.feedback
	if stage.kind == "mcq" and #notes == 0 then
		table.insert(notes, fb.perfect)
	elseif stage.kind == "mcq" then
		table.insert(notes, 1, if score >= 60 then fb.good else fb.weak)
	end
	while #notes > 4 do
		table.remove(notes)
	end
	stage.feedback = notes
	state.stageIndex += 1
	if state.stageIndex > #state.stages then
		state.done = true
		local s = reentry.score(state)
		state.quality = s.quality
		state.passed = s.quality >= reentry.PASS
	end
	result.ok = true
	result.stageId = stage.id
	result.score = score
	result.feedback = notes
	result.done = state.done
	result.passed = state.passed
	result.quality = state.quality
	return state, result
end

function reentry.score(state: State): { quality: number, metrics: { [string]: any } }
	local scores = scoresOf(state)
	local sum = 0
	for _, s in scores do
		sum += s
	end
	local quality = if #state.stages > 0 then math.floor(sum / #state.stages + 0.5) else 0
	local metrics: { [string]: any } = { stages = {} }
	for _, s in state.stages do
		metrics.stages[s.id] = s.score or 0
	end
	return { quality = quality, metrics = metrics }
end

return reentry
