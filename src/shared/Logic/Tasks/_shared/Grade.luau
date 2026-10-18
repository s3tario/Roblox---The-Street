--!strict
-- Generic grading for work task modules (owned by `work`; contracts §8). PURE.
-- Modules build their secret with _shared/Build (or by hand in the same shape) and grade with Grade.auto, which
-- never errors on malformed answers: anything unreadable simply scores 0 for that item.
--
--   Grade.auto(secret, answers, ctx) -> Result   Result = { quality 0..100, correct, total, feedback = {string},
--                                                           sections = { {kind, score, correct, total} } }
--   Grade.section(secret, answers, ctx) -> Section   one kind (multi handled by auto)
--   Grade.closeness(given, expected, tol, floor?) -> 0..1   full credit within tol (relative), linear to 0 at 6x
--   Grade.number(x) -> number?                    reads numbers and numeric strings ("1,250", "$40", "12%")
--   Grade.show(v) -> string                        display rounding used in feedback
--
-- Secret shapes (kind field required):
--   mcq      { key = {[qid] = optionIndex}, explain = {[qid] = string} }
--   fill     { fields = {[fieldId] = {value, tol, floor?, scales?, label, note?, shown?, unit?}}, fieldOrder = {id} }
--   order    { order = {itemId in correct order}, texts = {string}, note? }
--   match    { key = {[leftId] = rightId}, notes = {[leftId] = string}, labels = {[leftId] = string} }
--   spot     { groups = { {cells = {"row:col"}, note} }, maxPicks }
--   alloc    { target = {[itemId] = {lo, hi}}, total, notes, labels, unit? }
--   dialogue { scores = {[lineId] = {[optId] = 0..100}}, notes = {[lineId] = {[optId] = string}}, best = {[lineId] = optId} }
--   call     { credit = {[itemId] = {[optionIndex] = 0..1}}, notes = {[itemId] = string}, labels }
--   format   { issues = {[elemId] = {issueId}}, notes = {[elemId] = string}, labels, valid = {[issueId] = text} }
--   multi    { sections = {secret}, weights = {number}? }
-- Any secret may carry summary = { great?, good?, ok?, weak?, bad? } to replace the generic summary line.
-- ctx.toleranceMult widens fill tolerance and softens false spot flags; ctx.charismaBonus adds quality points to
-- dialogue sections (only for the lines answered).

local Config = require(script.Parent.Parent.Parent.Parent.Config.Tasks)
local Format = require(script.Parent.Parent.Parent.Parent.Util.Format)

export type Section = { kind: string, score: number, correct: number, total: number, notes: { string } }
export type Result = {
	quality: number,
	correct: number,
	total: number,
	feedback: { string },
	sections: { { kind: string, score: number, correct: number, total: number } },
}

local Grade = {}

local MAX_NOTES = 5

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function clamp01(x: number): number
	if x ~= x then
		return 0
	end
	return if x < 0 then 0 elseif x > 1 then 1 else x
end

function Grade.number(x: any): number?
	if finite(x) then
		return x
	end
	if type(x) == "string" and #x <= 40 then
		local cleaned = string.gsub(x, "[,%s%$%%x]", "")
		local n = tonumber(cleaned)
		if n and finite(n) then
			return n
		end
	end
	return nil
end

function Grade.show(v: number): string
	local a = math.abs(v)
	if a >= 1000 then
		return Format.commas(v, 0)
	elseif a >= 100 then
		return string.format("%.0f", v)
	elseif a >= 10 then
		return (string.gsub(string.format("%.1f", v), "%.0$", ""))
	end
	return (string.gsub(string.gsub(string.format("%.2f", v), "0+$", ""), "%.$", ""))
end

-- 1240, "$M" -> "$1,240M"; 12.5, "%" -> "12.5%"; 8.2, "x" -> "8.2x"; 3, "years" -> "3 years"
function Grade.withUnit(v: number, unit: string?): string
	local shown = Grade.show(v)
	local u = unit or ""
	if u == "" then
		return shown
	elseif u == "%" or u == "x" then
		return shown .. u
	elseif u == "$" then
		return (if v < 0 then "-$" .. Grade.show(-v) else "$" .. shown)
	elseif string.sub(u, 1, 1) == "$" then
		return (if v < 0 then "-$" .. Grade.show(-v) else "$" .. shown) .. string.sub(u, 2)
	end
	return shown .. " " .. u
end

function Grade.closeness(given: any, expected: number, tol: number, floor: number?): number
	local g = Grade.number(given)
	if g == nil or not finite(expected) then
		return 0
	end
	local scale = math.max(math.abs(expected), floor or 1e-6)
	local err = math.abs(g - expected) / scale
	local t = math.max(tol, 1e-9)
	if err <= t then
		return 1
	end
	local zeroAt = math.max(t * 6, t + 0.05)
	return clamp01(1 - (err - t) / (zeroAt - t))
end

local function tableOr(x: any): { [any]: any }
	return if type(x) == "table" then x else {}
end

local function str(x: any): string?
	if type(x) == "string" and #x <= 64 then
		return x
	end
	return nil
end

local function section(kind: string, score01: number, correct: number, total: number, notes: { string }): Section
	return { kind = kind, score = clamp01(score01) * 100, correct = correct, total = total, notes = notes }
end

---------------------------------------------------------------------------------------------------
-- Kinds
---------------------------------------------------------------------------------------------------
local function gradeMcq(secret: { [string]: any }, answers: any): Section
	local key = tableOr(secret.key)
	local explain = tableOr(secret.explain)
	local a = tableOr(answers)
	local total, correct = 0, 0
	local notes: { string } = {}
	local ids: { string } = {}
	for qid in key do
		table.insert(ids, qid)
	end
	table.sort(ids)
	for _, qid in ids do
		total += 1
		local given = Grade.number(a[qid])
		if given ~= nil and given == key[qid] then
			correct += 1
		elseif type(explain[qid]) == "string" then
			table.insert(notes, explain[qid])
		end
	end
	return section("mcq", if total > 0 then correct / total else 0, correct, total, notes)
end

local function gradeFill(secret: { [string]: any }, answers: any, ctx: any): Section
	local fields = tableOr(secret.fields)
	local a = tableOr(answers)
	local tolMult = if type(ctx) == "table" and finite(ctx.toleranceMult)
		then math.clamp(ctx.toleranceMult, 1, 1.5)
		else 1
	local order: { string } = {}
	if type(secret.fieldOrder) == "table" then
		for _, id in secret.fieldOrder do
			if type(id) == "string" and fields[id] then
				table.insert(order, id)
			end
		end
	end
	if #order == 0 then
		for id in fields do
			table.insert(order, id)
		end
		table.sort(order)
	end
	local sum, correct = 0, 0
	local notes: { string } = {}
	for _, id in order do
		local f = fields[id]
		local value = if type(f) == "table" and finite(f.value) then f.value else 0
		local tol = (if type(f) == "table" and finite(f.tol) then f.tol else 0.02) * tolMult
		local floor = if type(f) == "table" and finite(f.floor) then f.floor else nil
		local given = Grade.number(a[id])
		local best = 0
		if given ~= nil then
			local scales = if type(f) == "table" and type(f.scales) == "table" then f.scales else { 1 }
			for _, s in scales do
				if finite(s) then
					best = math.max(best, Grade.closeness(given * s, value, tol, floor))
				end
			end
		end
		sum += best
		if best >= 0.999 then
			correct += 1
		else
			local label = if type(f) == "table" and type(f.short) == "string"
				then f.short
				elseif type(f) == "table" and type(f.label) == "string" then f.label
				else id
			local unit = if type(f) == "table" and type(f.unit) == "string" then f.unit else ""
			local shown = if type(f) == "table" and type(f.shown) == "string"
				then f.shown
				else Grade.withUnit(value, unit)
			local vars = {
				label = label,
				expected = shown,
				given = if given ~= nil then Grade.withUnit(given, unit) else "",
			}
			table.insert(notes, Config.text(if given == nil then "note_fill_blank" else "note_fill_miss", vars))
			if type(f) == "table" and type(f.note) == "string" then
				table.insert(notes, f.note)
			end
		end
	end
	local n = #order
	return section("fill", if n > 0 then sum / n else 0, correct, n, notes)
end

local function gradeOrder(secret: { [string]: any }, answers: any): Section
	local order: { string } = {}
	for _, id in tableOr(secret.order) do
		if type(id) == "string" then
			table.insert(order, id)
		end
	end
	local n = #order
	if n == 0 then
		return section("order", 0, 0, 0, {})
	end
	local known: { [string]: boolean } = {}
	for _, id in order do
		known[id] = true
	end
	local pos: { [string]: number } = {}
	local given: { string } = {}
	if type(answers) == "table" then
		for i = 1, math.min(#answers, n * 2) do
			local id = str(answers[i])
			if id and known[id] and pos[id] == nil then
				table.insert(given, id)
				pos[id] = #given
			end
		end
	end
	local pairs, concordant = 0, 0
	for i = 1, n - 1 do
		for j = i + 1, n do
			pairs += 1
			local pi, pj = pos[order[i]], pos[order[j]]
			if pi and pj and pi < pj then
				concordant += 1
			end
		end
	end
	local tau = if pairs > 0 then (2 * concordant - pairs) / pairs else 1
	local exact = 0
	for i, id in order do
		if given[i] == id then
			exact += 1
		end
	end
	local score = 0.7 * math.max(0, tau) + 0.3 * exact / n
	local notes: { string } = {}
	if exact < n then
		local texts: { string } = {}
		for _, t in tableOr(secret.texts) do
			if type(t) == "string" then
				table.insert(texts, t)
			end
		end
		if #texts > 0 then
			table.insert(notes, Config.text("note_order", { list = table.concat(texts, " → ") }))
		end
		if type(secret.note) == "string" then
			table.insert(notes, secret.note)
		end
	end
	return section("order", score, exact, n, notes)
end

local function gradeMatch(secret: { [string]: any }, answers: any): Section
	local key = tableOr(secret.key)
	local notes = tableOr(secret.notes)
	local labels = tableOr(secret.labels)
	local a = tableOr(answers)
	local ids: { string } = {}
	for id in key do
		table.insert(ids, id)
	end
	table.sort(ids)
	local correct = 0
	local out: { string } = {}
	for _, id in ids do
		if str(a[id]) == key[id] then
			correct += 1
		elseif type(notes[id]) == "string" then
			table.insert(out, notes[id])
		elseif type(labels[id]) == "string" then
			table.insert(out, Config.text("note_match_miss", { label = labels[id] }))
		end
	end
	local n = #ids
	return section("match", if n > 0 then correct / n else 0, correct, n, out)
end

local function cellKey(pick: any): string?
	if type(pick) ~= "table" then
		return nil
	end
	local r = Grade.number(pick[1] or pick.row)
	local c = Grade.number(pick[2] or pick.col)
	if r == nil or c == nil or r ~= math.floor(r) or c ~= math.floor(c) then
		return nil
	end
	return tostring(r) .. ":" .. tostring(c)
end

local function gradeSpot(secret: { [string]: any }, answers: any, ctx: any): Section
	local groups = tableOr(secret.groups)
	-- Skill (ctx.toleranceMult 1..1.5) softens the cost of a false flag: 0.5 of an error at 1x, 0.33 at 1.5x
	local tolMult = if type(ctx) == "table" and finite(ctx.toleranceMult)
		then math.clamp(ctx.toleranceMult, 1, 1.5)
		else 1
	local penalty = 0.5 / tolMult
	local maxPicks = if finite(secret.maxPicks) then math.floor(secret.maxPicks) else #groups + 2
	local groupOf: { [string]: number } = {}
	for gi, g in groups do
		if type(g) == "table" then
			for _, cell in tableOr(g.cells) do
				if type(cell) == "string" then
					groupOf[cell] = gi
				end
			end
		end
	end
	local picked: { [string]: boolean } = {}
	local found: { [number]: boolean } = {}
	local falsePicks, used = 0, 0
	if type(answers) == "table" then
		for i = 1, math.min(#answers, 64) do
			local k = cellKey(answers[i])
			if k and not picked[k] then
				picked[k] = true
				used += 1
				if used > maxPicks then
					break
				end
				local gi = groupOf[k]
				if gi then
					found[gi] = true
				else
					falsePicks += 1
				end
			end
		end
	end
	local hits = 0
	local notes: { string } = {}
	for gi, g in groups do
		if found[gi] then
			hits += 1
		elseif type(g) == "table" and type(g.note) == "string" then
			table.insert(notes, g.note)
		end
	end
	if falsePicks > 0 then
		table.insert(notes, Config.text("note_spot_false", { n = falsePicks }))
	end
	local n = #groups
	local score = if n > 0 then (hits - penalty * falsePicks) / n else (if falsePicks == 0 then 1 else 0)
	return section("spot", score, hits, n, notes)
end

local function gradeAlloc(secret: { [string]: any }, answers: any): Section
	local target = tableOr(secret.target)
	local notes = tableOr(secret.notes)
	local labels = tableOr(secret.labels)
	local unit = if type(secret.unit) == "string" then secret.unit else ""
	local total = if finite(secret.total) and secret.total > 0 then secret.total else 1
	local a = tableOr(answers)
	local ids: { string } = {}
	for id in target do
		table.insert(ids, id)
	end
	table.sort(ids)
	local values: { [string]: number } = {}
	local sum = 0
	for _, id in ids do
		local v = Grade.number(a[id])
		local x = if v ~= nil and v > 0 then v else 0
		values[id] = x
		sum += x
	end
	local over = sum > total * 1.001
	local dist, inBand = 0, 0
	local out: { string } = {}
	for _, id in ids do
		local band = tableOr(target[id])
		local lo = if finite(band[1]) then band[1] else 0
		local hi = if finite(band[2]) then band[2] else lo
		local x = values[id]
		local d = if x < lo then lo - x elseif x > hi then x - hi else 0
		dist += d
		if d <= 1e-6 then
			inBand += 1
		else
			local label = if type(labels[id]) == "string" then labels[id] else id
			table.insert(
				out,
				if type(notes[id]) == "string"
					then notes[id]
					else Config.text(
						"note_alloc_band",
						{ label = label, lo = Grade.show(lo), hi = Grade.show(hi), unit = unit, given = Grade.show(x) }
					)
			)
		end
	end
	local score = 1 - dist / (0.5 * total)
	if over then
		score *= total / sum
		table.insert(
			out,
			1,
			Config.text("note_alloc_over", { given = Grade.show(sum), total = Grade.show(total), unit = unit })
		)
	end
	return section("alloc", score, inBand, #ids, out)
end

local function gradeDialogue(secret: { [string]: any }, answers: any, ctx: any): Section
	local scores = tableOr(secret.scores)
	local notes = tableOr(secret.notes)
	local best = tableOr(secret.best)
	local a = tableOr(answers)
	local ids: { string } = {}
	for id in scores do
		table.insert(ids, id)
	end
	table.sort(ids)
	local sum, correct, answered = 0, 0, 0
	local out: { string } = {}
	for _, lineId in ids do
		local opts = tableOr(scores[lineId])
		local chosen = str(a[lineId])
		local s = if chosen and finite(opts[chosen]) then opts[chosen] else 0
		if chosen and finite(opts[chosen]) then
			answered += 1
		end
		sum += math.clamp(s, 0, 100)
		local top = best[lineId]
		local topScore = if type(top) == "string" and finite(opts[top]) then opts[top] else 100
		if chosen and s >= topScore - 1e-6 then
			correct += 1
		else
			local lineNotes = tableOr(notes[lineId])
			local note = if chosen then lineNotes[chosen] else nil
			if type(note) == "string" then
				table.insert(out, note)
			end
		end
	end
	local n = #ids
	-- Charisma (ctx.charismaBonus 0..8) adds quality points, earned only on the lines actually answered
	local maxBonus = if type(ctx) == "table" and finite(ctx.charismaBonus)
		then math.clamp(ctx.charismaBonus, 0, 8)
		else 0
	local bonus = if n > 0 then maxBonus * answered / n else 0
	local avg = if n > 0 then sum / n else 0
	if n > 0 and correct == n then
		table.insert(out, Config.text("note_dialogue_good"))
	end
	return section("dialogue", (if n > 0 then avg + bonus else 0) / 100, correct, n, out)
end

local function gradeCall(secret: { [string]: any }, answers: any): Section
	local credit = tableOr(secret.credit)
	local notes = tableOr(secret.notes)
	local a = tableOr(answers)
	local ids: { string } = {}
	for id in credit do
		table.insert(ids, id)
	end
	table.sort(ids)
	local sum, correct = 0, 0
	local out: { string } = {}
	for _, id in ids do
		local given = Grade.number(a[id])
		local table_ = tableOr(credit[id])
		local c = if given ~= nil and given == math.floor(given) and finite(table_[given]) then table_[given] else 0
		c = clamp01(c)
		sum += c
		if c >= 0.999 then
			correct += 1
		elseif type(notes[id]) == "string" then
			table.insert(out, notes[id])
		end
	end
	local n = #ids
	if n > 0 and correct == n then
		table.insert(out, Config.text("note_call_perfect"))
	end
	return section("call", if n > 0 then sum / n else 0, correct, n, out)
end

local function gradeFormat(secret: { [string]: any }, answers: any): Section
	local issues = tableOr(secret.issues)
	local notes = tableOr(secret.notes)
	local labels = tableOr(secret.labels)
	local valid = tableOr(secret.valid)
	local a = tableOr(answers)
	local ids: { string } = {}
	for id in issues do
		table.insert(ids, id)
	end
	table.sort(ids)
	local hits, falseFlags, total = 0, 0, 0
	local out: { string } = {}
	for _, elemId in ids do
		local truth: { [string]: boolean } = {}
		local truthList = tableOr(issues[elemId])
		for _, issueId in truthList do
			if type(issueId) == "string" then
				truth[issueId] = true
				total += 1
			end
		end
		local raw = a[elemId]
		local chosen: { [string]: boolean } = {}
		if type(raw) == "string" then
			chosen[raw] = true
		elseif type(raw) == "table" then
			for i = 1, math.min(#raw, 12) do
				local issueId = str(raw[i])
				if issueId and valid[issueId] ~= nil then
					chosen[issueId] = true
				end
			end
		end
		for issueId in chosen do
			if valid[issueId] ~= nil then
				if truth[issueId] then
					hits += 1
				else
					falseFlags += 1
				end
			end
		end
		local missedHere = false
		for _, issueId in truthList do
			if type(issueId) == "string" and not chosen[issueId] then
				missedHere = true
				if type(notes[elemId]) ~= "string" then
					local element = if type(labels[elemId]) == "string" then labels[elemId] else elemId
					if #element > 48 then
						element = string.sub(element, 1, 45) .. "…"
					end
					local issueText = valid[issueId]
					table.insert(
						out,
						Config.text(
							"note_format_missed",
							{ element = element, issue = if type(issueText) == "string" then issueText else issueId }
						)
					)
				end
			end
		end
		if missedHere and type(notes[elemId]) == "string" then
			table.insert(out, notes[elemId])
		end
	end
	if falseFlags > 0 then
		table.insert(out, Config.text("note_format_false", { n = falseFlags }))
	end
	local score: number
	if total > 0 then
		score = (hits - 0.5 * falseFlags) / total
	else
		score = 1 - 0.25 * falseFlags
	end
	return section("format", score, hits, total, out)
end

local GRADERS: { [string]: (secret: { [string]: any }, answers: any, ctx: any) -> Section } = {
	mcq = gradeMcq,
	fill = gradeFill,
	order = gradeOrder,
	match = gradeMatch,
	spot = gradeSpot,
	alloc = gradeAlloc,
	dialogue = gradeDialogue,
	call = gradeCall,
	format = gradeFormat,
}

function Grade.section(secret: any, answers: any, ctx: any): Section
	if type(secret) ~= "table" or type(secret.kind) ~= "string" then
		return section("unknown", 0, 0, 0, {})
	end
	local grader = GRADERS[secret.kind]
	if not grader then
		return section(secret.kind, 0, 0, 0, {})
	end
	return grader(secret, answers, ctx)
end

---------------------------------------------------------------------------------------------------
-- Result
---------------------------------------------------------------------------------------------------
local function summary(quality: number, override: any): string
	local band = if quality >= 90
		then "great"
		elseif quality >= 75 then "good"
		elseif quality >= 55 then "ok"
		elseif quality >= 35 then "weak"
		else "bad"
	if type(override) == "table" and type(override[band]) == "string" then
		return override[band]
	end
	return Config.text("result_" .. band)
end

function Grade.auto(secret: any, answers: any, ctx: any): Result
	local sections: { Section } = {}
	local weights: { number } = {}
	if type(secret) == "table" and secret.kind == "multi" and type(secret.sections) == "table" then
		local list = if type(answers) == "table" then answers else {}
		for i, sub in secret.sections do
			local sub_answers = list[i]
			if sub_answers == nil then
				sub_answers = list[tostring(i)]
			end
			table.insert(sections, Grade.section(sub, sub_answers, ctx))
			local w = if type(secret.weights) == "table" then secret.weights[i] else nil
			table.insert(weights, if finite(w) and (w :: number) > 0 then w :: number else 1)
		end
	else
		table.insert(sections, Grade.section(secret, answers, ctx))
		table.insert(weights, 1)
	end
	local wsum, qsum, correct, total = 0, 0, 0, 0
	for i, s in sections do
		wsum += weights[i]
		qsum += weights[i] * s.score
		correct += s.correct
		total += s.total
	end
	local quality = if wsum > 0 then math.floor(math.clamp(qsum / wsum, 0, 100) + 0.5) else 0
	local feedback: { string } = { summary(quality, if type(secret) == "table" then secret.summary else nil) }
	-- interleave section notes so every part gets a say
	local cursor: { number } = {}
	for i = 1, #sections do
		cursor[i] = 1
	end
	local added = true
	while added and #feedback < MAX_NOTES do
		added = false
		for i, s in sections do
			local note = s.notes[cursor[i]]
			if note and #feedback < MAX_NOTES then
				cursor[i] += 1
				if not table.find(feedback, note) then
					table.insert(feedback, note)
				end
				added = true
			end
		end
	end
	local brief: { { kind: string, score: number, correct: number, total: number } } = {}
	for _, s in sections do
		table.insert(brief, { kind = s.kind, score = math.floor(s.score + 0.5), correct = s.correct, total = s.total })
	end
	return { quality = quality, correct = correct, total = total, feedback = feedback, sections = brief }
end

return Grade
