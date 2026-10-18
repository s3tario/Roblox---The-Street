--!strict
-- Content banks for work task modules (owned by `work`; contracts §8). PURE.
-- Modules keep their questions and conversations as data; Bank picks fresh variants with the module's Rng and fills
-- "{var}" placeholders, then hands specs to _shared/Build (which shuffles and ids them without leaking answers).
--
--   McqEntry = { text, correct, wrong = {string}, explain?, hint?, context? }
--   Bank.mcq(rng, entries, n, vars?) -> (specs: {Build.McqSpec}, hints: {string})
--       n distinct entries in a random order; every string filled with vars
--   Bank.mcqOne(entry, vars?) -> Build.McqSpec       one entry, filled (for hand-built numeric questions)
--
--   Opt  = { text, note?, score? }                     default scores: best 100, good 70, weak 40, bad 8
--   Turn = { says = {string}, best = {Opt}, good = {Opt}?, weak = {Opt}?, bad = {Opt}, hint? }
--   Bank.turn(rng, turn, vars?, nOpts?) -> Build.DialogueSpec
--       one line: a random "says" variant, one best answer, then good / weak / bad answers up to nOpts (default 4);
--       at least one bad answer is always shown, so the worst choice on every line scores low
--   Bank.dialogue(rng, turns, vars?, nOpts?) -> (specs, hints)   every turn in order
--   Bank.fill(value, vars) -> value                   deep "{var}" substitution (strings inside tables too)

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)
local Config = require(script.Parent.Parent.Parent.Parent.Config.Tasks)
local Build = require(script.Parent.Build)
local Common = require(script.Parent.Common)

export type McqEntry = {
	text: string,
	correct: string,
	wrong: { string },
	explain: string?,
	hint: string?,
	context: string?,
}
export type Opt = { text: string, note: string?, score: number? }
export type Turn = {
	says: { string },
	best: { Opt },
	good: { Opt }?,
	weak: { Opt }?,
	bad: { Opt },
	hint: string?,
}

local Bank = {}

Bank.SCORES = { best = 100, good = 70, weak = 40, bad = 8 }

local function fillStr(s: string, vars: { [string]: any }?): string
	if not vars then
		return s
	end
	return Common.fill(s, vars)
end

function Bank.fill(value: any, vars: { [string]: any }?): any
	if type(value) == "string" then
		return fillStr(value, vars)
	elseif type(value) == "table" then
		local out: { [any]: any } = {}
		for k, v in value do
			out[k] = Bank.fill(v, vars)
		end
		return out
	end
	return value
end

function Bank.mcqOne(entry: McqEntry, vars: { [string]: any }?): Build.McqSpec
	local wrong: { string } = {}
	for _, w in entry.wrong do
		table.insert(wrong, fillStr(w, vars))
	end
	return {
		text = fillStr(entry.text, vars),
		correct = fillStr(entry.correct, vars),
		wrong = wrong,
		explain = if entry.explain then fillStr(entry.explain, vars) else nil,
		context = if entry.context then fillStr(entry.context, vars) else nil,
	}
end

function Bank.mcq(
	rng: Rng.Rng,
	entries: { McqEntry },
	n: number,
	vars: { [string]: any }?
): ({ Build.McqSpec }, { string })
	local picks = Common.pickN(rng, entries, n)
	local specs: { Build.McqSpec } = {}
	local hints: { string } = {}
	for _, e in picks do
		table.insert(specs, Bank.mcqOne(e, vars))
		if e.hint then
			table.insert(hints, fillStr(e.hint, vars))
		end
	end
	return specs, hints
end

local function option(o: Opt, default: number, vars: { [string]: any }?, fallbackNote: string?): Build.DialogueOption
	local note = if o.note then fillStr(o.note, vars) else fallbackNote
	return { text = fillStr(o.text, vars), score = o.score or default, note = note }
end

function Bank.turn(rng: Rng.Rng, turn: Turn, vars: { [string]: any }?, nOpts: number?): Build.DialogueSpec
	local want = math.max(2, nOpts or 4)
	local weakNote = Config.text("note_dialogue_weak")
	local options: { Build.DialogueOption } = {}
	table.insert(options, option(rng:pick(turn.best), Bank.SCORES.best, vars, nil))
	local bad = rng:shuffle(turn.bad)
	local good = rng:shuffle(turn.good or {})
	local weak = rng:shuffle(turn.weak or {})
	-- always one bad answer; then alternate good / weak / more bad until full
	table.insert(options, option(table.remove(bad, 1) :: Opt, Bank.SCORES.bad, vars, weakNote))
	local pools: { { list: { Opt }, score: number } } = {
		{ list = good, score = Bank.SCORES.good },
		{ list = weak, score = Bank.SCORES.weak },
		{ list = bad, score = Bank.SCORES.bad },
	}
	local guard = 0
	while #options < want and guard < 12 do
		guard += 1
		local added = false
		for _, pool in pools do
			if #options < want and #pool.list > 0 then
				table.insert(options, option(table.remove(pool.list, 1) :: Opt, pool.score, vars, weakNote))
				added = true
			end
		end
		if not added then
			break
		end
	end
	return { text = fillStr(rng:pick(turn.says), vars), options = options }
end

function Bank.dialogue(
	rng: Rng.Rng,
	turns: { Turn },
	vars: { [string]: any }?,
	nOpts: number?
): ({ Build.DialogueSpec }, { string })
	local specs: { Build.DialogueSpec } = {}
	local hints: { string } = {}
	for _, t in turns do
		table.insert(specs, Bank.turn(rng, t, vars, nOpts))
		if t.hint then
			table.insert(hints, fillStr(t.hint, vars))
		end
	end
	return specs, hints
end

return Bank
