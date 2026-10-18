--!strict
-- Small helpers every big-deal module shares (owned by `projects`; contracts §9). PURE: no services, no clocks, no
-- Instances. Deal modules (Logic/Projects/<id>) build their stages with these so numbers, names and difficulty
-- tiers read the same across deals.
--
--   DealKit.round5(x) -> number                 nearest $5M (at least 5)
--   DealKit.halfDollar(x) / DealKit.cents(x)    share prices: nearest $0.50 (at least $0.50) / nearest cent
--   DealKit.dollars(x) -> "12.50"               DealKit.compact(m) -> "$640M" / "$1.2B" (m in $M)
--   DealKit.pctText(ratio) -> "17%"             (absolute value)
--   DealKit.count(ctx, easy, medium, hard)      pick by the difficulty tier (Common.tier)
--   DealKit.band(score) -> "great"|"good"|"weak"   debrief bands (85+, 60+, below)
--   DealKit.with(base, extra) -> table          a copy of base with extra's fields on top
--   DealKit.section(answers, i) -> table        one section of a multi submission ({[i]} or {["i"]} after JSON)
--   DealKit.dialogueSpecs(rng, lines, n, vars) -> { Build.DialogueSpec }   n random lines, templates filled
--   DealKit.formatSpecs(rng, elements, broken, vars, words) -> { Build.FormatElement }
--       the document-check stage: `broken` random elements get one of their broken variants (a typo variant
--       misspells words[variant.typo], e.g. { firm = ..., company = ... }); the rest stay clean

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent.Parent.Parent.Tasks._shared.Common)
local Build = require(script.Parent.Parent.Parent.Tasks._shared.Build)

local DealKit = {}

local fill = Common.fill

function DealKit.round5(x: number): number
	return math.max(5, math.floor(x / 5 + 0.5) * 5)
end

function DealKit.halfDollar(x: number): number
	return math.max(0.5, math.floor(x * 2 + 0.5) / 2)
end

function DealKit.cents(x: number): number
	return math.floor(x * 100 + 0.5) / 100
end

function DealKit.dollars(x: number): string
	return string.format("%.2f", x)
end

-- "$640M" below a billion, "$1.2B" above (deal names, headlines, figures).
function DealKit.compact(m: number): string
	if m >= 1000 then
		local s = string.format("%.1f", m / 1000)
		s = string.gsub(s, "%.0$", "")
		return "$" .. s .. "B"
	end
	return "$" .. Common.commas(m) .. "M"
end

function DealKit.pctText(ratio: number): string
	return string.format("%d%%", math.floor(math.abs(ratio) * 100 + 0.5))
end

function DealKit.count(ctx: Common.Ctx, easy: number, medium: number, hard: number): number
	local tier = Common.tier(ctx)
	return if tier == 1 then easy elseif tier == 2 then medium else hard
end

function DealKit.band(score: number): string
	return if score >= 85 then "great" elseif score >= 60 then "good" else "weak"
end

function DealKit.with(base: { [string]: any }, extra: { [string]: any }): { [string]: any }
	local out = table.clone(base)
	for k, v in extra do
		out[k] = v
	end
	return out
end

-- A section's answers inside a multi submission ({[i] = answers}, or string keys after a JSON round trip).
function DealKit.section(answers: any, i: number): { [string]: any }
	if type(answers) ~= "table" then
		return {}
	end
	local a = answers[i]
	if a == nil then
		a = answers[tostring(i)]
	end
	return if type(a) == "table" then a else {}
end

function DealKit.dialogueSpecs(rng: Rng.Rng, lines: { any }, n: number, v: { [string]: any }): { Build.DialogueSpec }
	local out: { Build.DialogueSpec } = {}
	for _, line in Common.pickN(rng, lines, n) do
		local options: { Build.DialogueOption } = {}
		for _, o in line.options do
			table.insert(options, {
				text = fill(o.text, v),
				score = o.score,
				note = if o.note then fill(o.note, v) else nil,
			})
		end
		table.insert(out, { id = line.id, text = fill(line.text, v), options = options })
	end
	return out
end

function DealKit.formatSpecs(
	rng: Rng.Rng,
	elements: { any },
	brokenCount: number,
	v: { [string]: any },
	words: { [string]: string }
): { Build.FormatElement }
	local order: { number } = {}
	for i = 1, #elements do
		order[i] = i
	end
	local brokenSet: { [number]: boolean } = {}
	for i, idx in rng:shuffle(order) do
		if i <= brokenCount then
			brokenSet[idx] = true
		end
	end
	local specs: { Build.FormatElement } = {}
	for i, el in elements do
		if brokenSet[i] then
			local variant = rng:pick(el.broken)
			local text: string
			if variant.typo then
				local clean = fill(el.clean, v)
				local word = words[variant.typo] or ""
				local misspelt = Common.typo(rng, word)
				local a, b = string.find(clean, word, 1, true)
				text = if word ~= ""
						and a
						and b
						and misspelt ~= word
					then string.sub(clean, 1, a - 1) .. misspelt .. string.sub(clean, b + 1)
					else clean .. " " .. Common.typo(rng, "Confidential")
			else
				text = fill(variant.text or el.clean, v)
			end
			table.insert(specs, {
				text = text,
				kind = el.kind,
				issues = { variant.issue },
				note = fill(variant.note, v),
			})
		else
			table.insert(specs, { text = fill(el.clean, v), kind = el.kind, issues = {} })
		end
	end
	return specs
end

return DealKit
