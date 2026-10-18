--!strict
-- Big-deal stage machine (owned by `projects`; contracts §9). PURE: no services, no clocks, no Instances.
-- Turns a data-driven deal definition (a scenario, an ordered list of stages and an outcome) into the contract's
-- project-module functions, so every big deal (Investment Banking's now, later tracks' in M5+) plugs in the same way.
--
--   Machine.build(def) -> module          def gains new / view / act / score and is returned
--     module.new(rng, ctx) -> State
--     module.view(state, ctx?) -> View    { id, title, dealName, stage, stageIndex, stageCount, stages, summary,
--                                           payload?, done, quality, outcome? }  (never the answer key)
--     module.act(state, answers, ctx?) -> (State, Result)   grades the current stage, applies it, moves on
--     module.score(state) -> { quality, metrics }
--   Machine.ctx(raw) -> Ctx                Common.ctx (work's task context) plus marketMood (0.8..1.2)
--   Machine.stageAverage(def, state) -> 0..100   weighted stage scores (a stage not played yet counts 0)
--   Machine.combine(stageAvg, outcomeScore, outcomeWeight) -> 0..100 (whole number)
--
-- Def = {
--   id, title, version?, outcomeWeight? (0..1, default 0.25),
--   stages = { StageDef },   StageDef = { id, title, kind, brief?, weight?, build, apply? }
--     build(state, rng, ctx) -> (payload, secret, meta?)   payload: a contracts §8 work payload (kind and title are
--         filled in when missing); secret: the Logic/Tasks/_shared/Grade secret; meta: plain data kept for apply
--     apply(state, graded, answers, meta, ctx) -> debrief?   updates state.facts after grading and returns one line
--         telling the player what happened ("6 buyers signed NDAs and received the CIM.")
--   init(rng, ctx) -> facts    the scenario (plain data)
--   dealName(state) -> string  the plaque name (also shown while the deal runs)
--   summary(state, ctx) -> { text, metrics = { {id, label, value, tone?} } }   must never reveal an answer
--   finish(state, ctx) -> Outcome   { closed, score 0..100, headline, lines = {string}, figures = { {label, value,
--       tone?} }, dealName? }
-- }
--
-- State (saved as is in data.projects[id].state, so JSON-safe: string-keyed maps and dense arrays only):
--   { version, id, seed, stageIndex, stageCount, done, quality, scores = {[stageId] = n},
--     feedback = {[stageId] = {string}}, debrief = {[stageId] = string}, facts, current = {id, payload, secret,
--     meta}?, outcome?, dealName }
-- A stage is generated when it is entered, from Rng(Hash(id, seed, stageId)) and the facts so far: later stages
-- react to earlier choices, and a saved deal rebuilds exactly the same stage if its `current` is ever lost.

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)
local Hash = require(script.Parent.Parent.Parent.Parent.Util.Hash)
local TableUtil = require(script.Parent.Parent.Parent.Parent.Util.TableUtil)
local Grade = require(script.Parent.Parent.Parent.Tasks._shared.Grade)
local Common = require(script.Parent.Parent.Parent.Tasks._shared.Common)

export type Ctx = {
	level: number,
	rank: number,
	track: string?,
	student: boolean,
	stats: { [string]: number },
	ovr: number,
	difficulty: number,
	facts: { [string]: any }?,
	now: number,
	hints: number,
	toleranceMult: number,
	charismaBonus: number,
	offer: { [string]: any }?,
	companyName: string?,
	firstName: string?,
	marketMood: number,
}
export type Metric = { id: string, label: string, value: string, tone: string? }
export type Summary = { text: string, metrics: { Metric } }
export type Figure = { label: string, value: string, tone: string? }
export type Outcome = {
	closed: boolean,
	score: number,
	headline: string,
	lines: { string },
	figures: { Figure },
	dealName: string?,
}
export type Current = {
	id: string,
	payload: { [string]: any },
	secret: { [string]: any },
	meta: { [string]: any },
}
export type State = {
	version: number,
	id: string,
	seed: number,
	stageIndex: number,
	stageCount: number,
	done: boolean,
	quality: number,
	scores: { [string]: number },
	feedback: { [string]: { string } },
	debrief: { [string]: string },
	facts: { [string]: any },
	current: Current?,
	outcome: Outcome?,
	dealName: string,
}
export type Graded = Grade.Result
export type StageDef = {
	id: string,
	title: string,
	kind: string,
	brief: string?,
	weight: number?,
	build: (state: State, rng: Rng.Rng, ctx: Ctx) -> ({ [string]: any }, { [string]: any }, { [string]: any }?),
	apply: ((state: State, graded: Graded, answers: any, meta: { [string]: any }, ctx: Ctx) -> string?)?,
}
export type StageEntry = {
	id: string,
	title: string,
	kind: string,
	brief: string?,
	status: string,
	score: number?,
	debrief: string?,
}
export type View = {
	id: string,
	title: string,
	dealName: string,
	stage: { id: string, title: string, kind: string, brief: string? },
	stageIndex: number,
	stageCount: number,
	stages: { StageEntry },
	summary: Summary,
	payload: { [string]: any }?,
	done: boolean,
	quality: number,
	outcome: Outcome?,
}
export type Result = {
	ok: boolean,
	err: string?,
	stageId: string?,
	stageTitle: string?,
	score: number,
	feedback: { string },
	sections: { { kind: string, score: number, correct: number, total: number } },
	debrief: string?,
	done: boolean,
	quality: number,
	outcome: Outcome?,
	nextStage: string?,
}
export type Def = {
	id: string,
	title: string,
	version: number?,
	outcomeWeight: number?,
	stages: { StageDef },
	init: (rng: Rng.Rng, ctx: Ctx) -> { [string]: any },
	dealName: (state: State) -> string,
	summary: (state: State, ctx: Ctx) -> Summary,
	finish: (state: State, ctx: Ctx) -> Outcome,
	[string]: any,
}

local Machine = {}

Machine.MAX_NOTES = 5
Machine.DEFAULT_OUTCOME_WEIGHT = 0.25

function Machine.ctx(raw: any): Ctx
	local c = Common.ctx(raw)
	local mood = if type(raw) == "table" then Common.num(raw.marketMood, 1) else 1
	return {
		level = c.level,
		rank = c.rank,
		track = c.track,
		student = c.student,
		stats = c.stats,
		ovr = c.ovr,
		difficulty = c.difficulty,
		facts = c.facts,
		now = c.now,
		hints = c.hints,
		toleranceMult = c.toleranceMult,
		charismaBonus = c.charismaBonus,
		offer = c.offer,
		companyName = c.companyName,
		firstName = c.firstName,
		marketMood = Common.clamp(mood, 0.8, 1.2),
	}
end

function Machine.stageAverage(def: Def, state: State): number
	local wsum, sum = 0, 0
	for _, s in def.stages do
		local w = if type(s.weight) == "number" and s.weight > 0 then s.weight else 1
		wsum += w
		local score = state.scores[s.id]
		sum += w * (if type(score) == "number" then score else 0)
	end
	return if wsum > 0 then sum / wsum else 0
end

function Machine.combine(stageAvg: number, outcomeScore: number, outcomeWeight: number?): number
	local w = math.clamp(if type(outcomeWeight) == "number" then outcomeWeight else Machine.DEFAULT_OUTCOME_WEIGHT, 0, 1)
	local q = (1 - w) * Common.num(stageAvg, 0) + w * Common.num(outcomeScore, 0)
	return math.floor(math.clamp(q, 0, 100) + 0.5)
end

local function stageRng(state: State, stageId: string): Rng.Rng
	return Rng.new(Hash.u32("project", state.id, state.seed, stageId))
end

-- Builds the stage at state.stageIndex into state.current.
local function enter(def: Def, state: State, ctx: Ctx)
	local stage = def.stages[state.stageIndex]
	if not stage then
		state.current = nil
		return
	end
	local payload, secret, meta = stage.build(state, stageRng(state, stage.id), ctx)
	if type(payload.kind) ~= "string" then
		payload.kind = stage.kind
	end
	if type(payload.title) ~= "string" or payload.title == "" then
		payload.title = stage.title
	end
	state.current = { id = stage.id, payload = payload, secret = secret, meta = meta or {} }
end

-- Repairs a saved state whose current stage is missing or stale (deterministic: same seed, same facts).
local function ensure(def: Def, state: State, ctx: Ctx)
	if state.done then
		return
	end
	local count = #def.stages
	if type(state.stageIndex) ~= "number" or state.stageIndex < 1 or state.stageIndex > count then
		state.stageIndex = math.clamp(math.floor(Common.num(state.stageIndex, 1)), 1, math.max(1, count))
	end
	local stage = def.stages[state.stageIndex]
	local current = state.current
	if stage and (current == nil or current.id ~= stage.id) then
		enter(def, state, ctx)
	end
end

local function newState(def: Def, rng: Rng.Rng, ctx: Ctx): State
	local seed = rng:int(1, 2147483646)
	local facts = def.init(rng, ctx)
	local state: State = {
		version = def.version or 1,
		id = def.id,
		seed = seed,
		stageIndex = 1,
		stageCount = #def.stages,
		done = false,
		quality = 0,
		scores = {},
		feedback = {},
		debrief = {},
		facts = facts,
		current = nil,
		outcome = nil,
		dealName = "",
	}
	state.dealName = def.dealName(state)
	enter(def, state, ctx)
	return state
end

local function viewOf(def: Def, state: State, ctx: Ctx): View
	ensure(def, state, ctx)
	local count = #def.stages
	local index = math.clamp(state.stageIndex, 1, math.max(1, count))
	local stage = def.stages[index]
	local list: { StageEntry } = {}
	for i, s in def.stages do
		local status = if state.done or i < index then "done" elseif i == index then "current" else "next"
		local entry: StageEntry = { id = s.id, title = s.title, kind = s.kind, status = status }
		local score = state.scores[s.id]
		if type(score) == "number" then
			entry.score = score
		end
		if s.brief then
			entry.brief = s.brief
		end
		local line = state.debrief[s.id]
		if type(line) == "string" then
			entry.debrief = line
		end
		table.insert(list, entry)
	end
	local current = state.current
	return {
		id = def.id,
		title = def.title,
		dealName = state.dealName,
		stage = { id = stage.id, title = stage.title, kind = stage.kind, brief = stage.brief },
		stageIndex = index,
		stageCount = count,
		stages = list,
		summary = def.summary(state, ctx),
		payload = if not state.done and current then TableUtil.deepCopy(current.payload) else nil,
		done = state.done,
		quality = state.quality,
		outcome = if state.done and state.outcome then TableUtil.deepCopy(state.outcome) else nil,
	}
end

local function actOn(def: Def, state: State, answers: any, ctx: Ctx): (State, Result)
	local result: Result = {
		ok = false,
		err = nil,
		stageId = nil,
		stageTitle = nil,
		score = 0,
		feedback = {},
		sections = {},
		debrief = nil,
		done = state.done,
		quality = state.quality,
		outcome = nil,
		nextStage = nil,
	}
	if state.done then
		result.err = "done"
		return state, result
	end
	ensure(def, state, ctx)
	local stage = def.stages[state.stageIndex]
	local current = state.current
	if not stage or not current then
		result.err = "broken"
		return state, result
	end
	local graded = Grade.auto(current.secret, answers, ctx)
	local score = math.clamp(math.floor(Common.num(graded.quality, 0) + 0.5), 0, 100)
	state.scores[stage.id] = score
	local notes: { string } = {}
	for _, line in graded.feedback do
		if type(line) == "string" and #notes < Machine.MAX_NOTES then
			table.insert(notes, line)
		end
	end
	state.feedback[stage.id] = notes
	local debrief: string? = nil
	local apply = stage.apply
	if apply then
		debrief = apply(state, graded, answers, current.meta or {}, ctx)
		if debrief then
			state.debrief[stage.id] = debrief
		end
	end
	state.current = nil
	if state.stageIndex >= #def.stages then
		local outcome = def.finish(state, ctx)
		outcome.score = math.floor(math.clamp(Common.num(outcome.score, 0), 0, 100) + 0.5)
		if not outcome.closed then
			outcome.closed = false
		end
		state.outcome = outcome
		if type(outcome.dealName) == "string" and outcome.dealName ~= "" then
			state.dealName = outcome.dealName
		else
			state.dealName = def.dealName(state)
		end
		state.quality = Machine.combine(Machine.stageAverage(def, state), outcome.score, def.outcomeWeight)
		state.done = true
		result.outcome = TableUtil.deepCopy(outcome)
	else
		state.stageIndex += 1
		enter(def, state, ctx)
		local nextDef = def.stages[state.stageIndex]
		result.nextStage = if nextDef then nextDef.title else nil
	end
	result.ok = true
	result.stageId = stage.id
	result.stageTitle = stage.title
	result.score = score
	result.feedback = notes
	result.sections = graded.sections
	result.debrief = debrief
	result.done = state.done
	result.quality = state.quality
	return state, result
end

local function scoreOf(def: Def, state: State): { quality: number, metrics: { [string]: any } }
	local outcome = state.outcome
	local stages: { [string]: number } = {}
	for _, s in def.stages do
		stages[s.id] = state.scores[s.id] or 0
	end
	local quality = if state.done
		then state.quality
		else Machine.combine(Machine.stageAverage(def, state), 0, def.outcomeWeight)
	return {
		quality = quality,
		metrics = {
			stages = stages,
			outcome = if outcome then outcome.score else 0,
			closed = outcome ~= nil and outcome.closed == true,
			dealName = state.dealName,
			done = state.done,
		},
	}
end

function Machine.build(def: Def): Def
	assert(type(def.id) == "string" and def.id ~= "", "project def needs an id")
	assert(type(def.stages) == "table" and #def.stages > 0, "project def needs stages")
	def.new = function(rng: Rng.Rng, rawCtx: any): State
		return newState(def, rng, Machine.ctx(rawCtx))
	end
	def.view = function(state: State, rawCtx: any): View
		return viewOf(def, state, Machine.ctx(rawCtx))
	end
	def.act = function(state: State, answers: any, rawCtx: any): (State, Result)
		return actOn(def, state, answers, Machine.ctx(rawCtx))
	end
	def.score = function(state: State): { quality: number, metrics: { [string]: any } }
		return scoreOf(def, state)
	end
	return def
end

return Machine
