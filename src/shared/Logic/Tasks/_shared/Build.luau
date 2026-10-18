--!strict
-- Payload builders for work task modules (owned by `work`; contracts §8 payload kinds). PURE.
-- Every builder shuffles with the module's Rng and assigns ids AFTER shuffling (by display position), so the
-- payload the client sees never leaks the answer through id order. Each returns the payload part plus the
-- matching secret part in the standard shape Grade.auto understands (see _shared/Grade).
--
--   Build.mcq(rng, specs, opts?) -> (questions, secret)
--       specs = { { id?, text, correct, wrong = {string}, explain?, context? } }; opts.options = 4 (count shown)
--   Build.dialogue(rng, lines) -> (lines, secret)
--       lines = { { id?, text, options = { { text, score (0..100), note? } } } }
--   Build.order(rng, steps, note?) -> (items, secret)          steps = { string } in the CORRECT order
--   Build.match(rng, pairs, extraRight?) -> (left, right, secret)
--       pairs = { { left = string, right = string, note? } }; extraRight = decoy strings
--   Build.call(rng, items, options) -> (items, secret)
--       items = { { label, chart = {number}, news = {string}, credit = { [optionIndex] = 0..1 }, note? } }
--   Build.format(rng, elements, issues) -> (elements, issues, secret)
--       elements = { { text, kind?, issues = { issueId }, note? } }; issues = { { id, text } } (vocabulary)
--   Build.spotTable(columns, rows, groups, maxPicks?) -> (table, secret)
--       groups = { { cells = { {row, col} }, note } } (a pick inside a group's cells finds that error)
--   Build.fillField(id, label, value, opts) -> (field, secretField)
--       opts = { unit?, hint?, tol (relative), floor? (absolute scale floor), scales? = {1, 100}, note? }
--   Build.alloc(items, total, step, targets, opts?) -> (payload part, secret)
--       targets[i] = { lo, hi } (full credit inside the band)
--   Build.letters[i] -> "a".."h"

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)

local Build = {}

Build.letters = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l" }

local function letter(i: number): string
	return Build.letters[i] or ("x" .. tostring(i))
end

---------------------------------------------------------------------------------------------------
-- mcq
---------------------------------------------------------------------------------------------------
export type McqSpec = {
	id: string?,
	text: string,
	correct: string,
	wrong: { string },
	explain: string?,
	context: string?,
}

function Build.mcq(rng: Rng.Rng, specs: { McqSpec }, opts: { options: number? }?): ({ any }, { [string]: any })
	local nOpts = if opts and opts.options then opts.options else 4
	local questions: { any } = {}
	local key: { [string]: number } = {}
	local explain: { [string]: string } = {}
	for i, spec in specs do
		local qid = spec.id or ("q" .. tostring(i))
		local wrong = rng:shuffle(spec.wrong)
		local pool: { string } = { spec.correct }
		-- distractors that repeat the answer (or each other) are dropped, so every option is distinct
		for _, w in wrong do
			if #pool >= nOpts then
				break
			end
			if table.find(pool, w) == nil then
				table.insert(pool, w)
			end
		end
		local shown = rng:shuffle(pool)
		local correctIndex = table.find(shown, spec.correct) or 1
		local q: { [string]: any } = { id = qid, text = spec.text, options = shown }
		if spec.context then
			q.context = spec.context
		end
		table.insert(questions, q)
		key[qid] = correctIndex
		if spec.explain then
			explain[qid] = spec.explain
		end
	end
	return questions, { kind = "mcq", key = key, explain = explain }
end

---------------------------------------------------------------------------------------------------
-- dialogue
---------------------------------------------------------------------------------------------------
export type DialogueOption = { text: string, score: number, note: string? }
export type DialogueSpec = { id: string?, text: string, options: { DialogueOption } }

function Build.dialogue(rng: Rng.Rng, specs: { DialogueSpec }): ({ any }, { [string]: any })
	local lines: { any } = {}
	local scores: { [string]: { [string]: number } } = {}
	local notes: { [string]: { [string]: string } } = {}
	local best: { [string]: string } = {}
	for i, spec in specs do
		local lineId = spec.id or ("l" .. tostring(i))
		local shown = rng:shuffle(spec.options)
		local options: { any } = {}
		local lineScores: { [string]: number } = {}
		local lineNotes: { [string]: string } = {}
		local top, topScore = "", -1
		for j, opt in shown do
			local optId = letter(j)
			table.insert(options, { id = optId, text = opt.text })
			lineScores[optId] = opt.score
			if opt.note then
				lineNotes[optId] = opt.note
			end
			if opt.score > topScore then
				top, topScore = optId, opt.score
			end
		end
		table.insert(lines, { id = lineId, text = spec.text, options = options })
		scores[lineId] = lineScores
		notes[lineId] = lineNotes
		best[lineId] = top
	end
	return lines, { kind = "dialogue", scores = scores, notes = notes, best = best }
end

---------------------------------------------------------------------------------------------------
-- order
---------------------------------------------------------------------------------------------------
function Build.order(rng: Rng.Rng, steps: { string }, note: string?): ({ any }, { [string]: any })
	local indices: { number } = {}
	for i = 1, #steps do
		indices[i] = i
	end
	local shown = rng:shuffle(indices)
	local items: { any } = {}
	local idOf: { [number]: string } = {}
	for displayPos, original in shown do
		local id = letter(displayPos)
		idOf[original] = id
		table.insert(items, { id = id, text = steps[original] })
	end
	local order: { string } = {}
	local texts: { string } = {}
	for i = 1, #steps do
		order[i] = idOf[i]
		texts[i] = steps[i]
	end
	return items, { kind = "order", order = order, texts = texts, note = note }
end

---------------------------------------------------------------------------------------------------
-- match
---------------------------------------------------------------------------------------------------
export type MatchPair = { left: string, right: string, note: string? }

function Build.match(rng: Rng.Rng, pairs: { MatchPair }, extraRight: { string }?): ({ any }, { any }, { [string]: any })
	local leftOrder = rng:shuffle(pairs)
	local left: { any } = {}
	local rightTexts: { string } = {}
	for _, p in pairs do
		table.insert(rightTexts, p.right)
	end
	if extraRight then
		for _, s in extraRight do
			table.insert(rightTexts, s)
		end
	end
	local rightShown = rng:shuffle(rightTexts)
	local right: { any } = {}
	local rightId: { [string]: string } = {}
	for i, text in rightShown do
		local id = "r" .. letter(i)
		table.insert(right, { id = id, text = text })
		if rightId[text] == nil then
			rightId[text] = id
		end
	end
	local key: { [string]: string } = {}
	local notes: { [string]: string } = {}
	local labels: { [string]: string } = {}
	for i, p in leftOrder do
		local id = "l" .. letter(i)
		table.insert(left, { id = id, text = p.left })
		key[id] = rightId[p.right]
		labels[id] = p.left .. " → " .. p.right
		if p.note then
			notes[id] = p.note
		end
	end
	return left, right, { kind = "match", key = key, notes = notes, labels = labels }
end

---------------------------------------------------------------------------------------------------
-- call
---------------------------------------------------------------------------------------------------
export type CallSpec = {
	label: string,
	chart: { number },
	news: { string },
	credit: { [number]: number },
	note: string?,
}

function Build.call(rng: Rng.Rng, specs: { CallSpec }): ({ any }, { [string]: any })
	local shown = rng:shuffle(specs)
	local items: { any } = {}
	local credit: { [string]: { [number]: number } } = {}
	local notes: { [string]: string } = {}
	local labels: { [string]: string } = {}
	for i, spec in shown do
		local id = "c" .. letter(i)
		table.insert(items, { id = id, label = spec.label, chart = spec.chart, news = spec.news })
		credit[id] = spec.credit
		labels[id] = spec.label
		if spec.note then
			notes[id] = spec.note
		end
	end
	return items, { kind = "call", credit = credit, notes = notes, labels = labels }
end

---------------------------------------------------------------------------------------------------
-- format
---------------------------------------------------------------------------------------------------
export type FormatElement = { text: string, kind: string?, issues: { string }, note: string? }
export type FormatIssue = { id: string, text: string }

function Build.format(
	_rng: Rng.Rng,
	specs: { FormatElement },
	vocabulary: { FormatIssue }
): ({ any }, { any }, { [string]: any })
	local elements: { any } = {}
	local issues: { [string]: { string } } = {}
	local notes: { [string]: string } = {}
	local labels: { [string]: string } = {}
	for i, spec in specs do
		local id = "e" .. letter(i)
		local el: { [string]: any } = { id = id, text = spec.text }
		if spec.kind then
			el.kind = spec.kind
		end
		table.insert(elements, el)
		issues[id] = table.clone(spec.issues)
		labels[id] = spec.text
		if spec.note then
			notes[id] = spec.note
		end
	end
	local vocab: { any } = {}
	local valid: { [string]: string } = {}
	for _, issue in vocabulary do
		table.insert(vocab, { id = issue.id, text = issue.text })
		valid[issue.id] = issue.text
	end
	return elements, vocab, { kind = "format", issues = issues, notes = notes, labels = labels, valid = valid }
end

---------------------------------------------------------------------------------------------------
-- spot
---------------------------------------------------------------------------------------------------
export type SpotGroup = { cells: { { number } }, note: string }

function Build.spotTable(
	columns: { string },
	rows: { { string } },
	groups: { SpotGroup },
	maxPicks: number?
): ({ [string]: any }, { [string]: any })
	local secretGroups: { any } = {}
	for _, g in groups do
		local cells: { string } = {}
		for _, cell in g.cells do
			table.insert(cells, tostring(cell[1]) .. ":" .. tostring(cell[2]))
		end
		table.insert(secretGroups, { cells = cells, note = g.note })
	end
	local picks = maxPicks or (#groups + 2)
	return { columns = columns, rows = rows }, {
		kind = "spot",
		groups = secretGroups,
		maxPicks = picks,
		rows = #rows,
		cols = #columns,
	}
end

---------------------------------------------------------------------------------------------------
-- fill
---------------------------------------------------------------------------------------------------
export type FillOpts = {
	unit: string?,
	hint: string?,
	tol: number?,
	floor: number?,
	scales: { number }?,
	note: string?,
	shown: string?, -- how the correct value is written in feedback (default: rounded number with unit)
	short: string?, -- short label for feedback when the field label is a long question
}

function Build.fillField(
	id: string,
	label: string,
	value: number,
	opts: FillOpts?
): ({ [string]: any }, { [string]: any })
	local o: FillOpts = opts or {}
	local field: { [string]: any } = { id = id, label = label }
	if o.unit then
		field.unit = o.unit
	end
	if o.hint then
		field.hint = o.hint
	end
	local secret: { [string]: any } = {
		value = value,
		tol = o.tol or 0.02,
		floor = o.floor,
		scales = o.scales,
		label = label,
		note = o.note,
		shown = o.shown,
		unit = o.unit,
		short = o.short,
	}
	return field, secret
end

---------------------------------------------------------------------------------------------------
-- alloc
---------------------------------------------------------------------------------------------------
export type AllocItem = { text: string, detail: string? }
export type AllocOpts = { minEach: number?, maxEach: number?, unit: string?, notes: { string }? }

function Build.alloc(
	items: { AllocItem },
	total: number,
	step: number,
	targets: { { number } },
	opts: AllocOpts?
): ({ [string]: any }, { [string]: any })
	local o: AllocOpts = opts or {}
	local shown: { any } = {}
	local target: { [string]: { number } } = {}
	local notes: { [string]: string } = {}
	local labels: { [string]: string } = {}
	for i, item in items do
		local id = "a" .. letter(i)
		local entry: { [string]: any } = { id = id, text = item.text }
		if item.detail then
			entry.detail = item.detail
		end
		table.insert(shown, entry)
		target[id] = targets[i]
		labels[id] = item.text
		if o.notes and o.notes[i] then
			notes[id] = o.notes[i]
		end
	end
	local part: { [string]: any } = { items = shown, total = total, step = step }
	if o.minEach then
		part.minEach = o.minEach
	end
	if o.maxEach then
		part.maxEach = o.maxEach
	end
	if o.unit then
		part.unit = o.unit
	end
	return part, { kind = "alloc", target = target, total = total, notes = notes, labels = labels }
end

return Build
