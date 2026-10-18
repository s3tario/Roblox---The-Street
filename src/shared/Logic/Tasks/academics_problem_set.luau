--!strict
-- academics_problem_set (owned by `work`; contracts §8): the weekly corporate-finance problem set at Halvorsen Hall.
-- Kind "fill": three to five time-value-of-money and ratio problems with fresh numbers every attempt. Answers
-- within tolerance score full marks, near misses partial credit; percentages accept 12.5 or 0.125.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Grade = require(script.Parent._shared.Grade)

local Task = {
	id = "academics_problem_set",
	title = "Problem Set",
	desc = "Corporate finance homework: compounding, discounting, growth and margins. Show the professor you can do the math.",
	kind = "fill",
	student = true,
	category = "academics",
	core = true,
	stats = { "knowledge", "discipline" },
	clientFacing = false,
	timeLimit = 240,
	baseXp = 60,
	basePay = 300,
	cooldown = 240,
}

type Problem = {
	key: string,
	label: string,
	value: number,
	unit: string,
	tol: number,
	short: string,
	hint: string,
	note: string,
	scales: { number }?,
	floor: number?,
}

local commas = Common.commas

local function fv(rng: Rng.Rng): Problem
	local p = rng:int(2, 24) * 500
	local r = rng:int(3, 9)
	local n = rng:int(2, 6)
	local v = p * (1 + r / 100) ^ n
	return {
		key = "fv",
		label = Common.fill(
			"You invest ${p} at {r}% a year, compounded yearly. What is it worth after {n} years?",
			{ p = commas(p), r = r, n = n }
		),
		value = v,
		unit = "$",
		tol = 0.01,
		short = "Future value",
		hint = "Future value = amount × (1 + rate)^years.",
		note = Common.fill("${p} × 1.{rr}^{n} ≈ ${v}.", { p = commas(p), rr = string.format("%02d", r), n = n, v = commas(v) }),
	}
end

local function pv(rng: Rng.Rng): Problem
	local f = rng:int(4, 30) * 1000
	local r = rng:int(4, 10)
	local n = rng:int(2, 5)
	local v = f / (1 + r / 100) ^ n
	return {
		key = "pv",
		label = Common.fill(
			"A bond pays ${f} in {n} years and nothing before. At a {r}% discount rate, what is it worth today?",
			{ f = commas(f), r = r, n = n }
		),
		value = v,
		unit = "$",
		tol = 0.01,
		short = "Present value",
		hint = "Present value = future amount ÷ (1 + rate)^years.",
		note = Common.fill("${f} ÷ 1.{rr}^{n} ≈ ${v}.", { f = commas(f), rr = string.format("%02d", r), n = n, v = commas(v) }),
	}
end

local function growth(rng: Rng.Rng): Problem
	local a = rng:int(40, 400) * 5
	local pctChange = rng:int(-12, 35)
	if pctChange == 0 then
		pctChange = 8
	end
	local b = math.floor(a * (1 + pctChange / 100) + 0.5)
	local v = (b - a) / a * 100
	return {
		key = "growth",
		label = Common.fill(
			"Revenue went from ${a}M last year to ${b}M this year. What was the growth rate?",
			{ a = commas(a), b = commas(b) }
		),
		value = v,
		unit = "%",
		tol = 0.02,
		floor = 1,
		scales = { 1, 100 },
		short = "Growth",
		hint = "Growth = (new − old) ÷ old.",
		note = Common.fill("({b} − {a}) ÷ {a} ≈ {v}%.", { a = commas(a), b = commas(b), v = string.format("%.1f", v) }),
	}
end

local function margin(rng: Rng.Rng): Problem
	local revenue = rng:int(20, 160) * 10
	local m = rng:int(6, 38)
	local op = math.floor(revenue * m / 100 + 0.5)
	local v = op / revenue * 100
	return {
		key = "margin",
		label = Common.fill(
			"A company has revenue of ${rev}M and operating income of ${op}M. What is its operating margin?",
			{ rev = commas(revenue), op = commas(op) }
		),
		value = v,
		unit = "%",
		tol = 0.02,
		scales = { 1, 100 },
		short = "Operating margin",
		hint = "Margin = profit ÷ revenue.",
		note = Common.fill("{op} ÷ {rev} ≈ {v}%.", { op = commas(op), rev = commas(revenue), v = string.format("%.1f", v) }),
	}
end

local function pe(rng: Rng.Rng): Problem
	local eps = rng:int(8, 60) / 10
	local mult = rng:int(9, 32)
	local price = math.floor(eps * mult * 100 + 0.5) / 100
	local v = price / eps
	return {
		key = "pe",
		label = Common.fill(
			"A stock trades at ${price} and earned ${eps} per share last year. What is its P/E ratio?",
			{ price = string.format("%.2f", price), eps = string.format("%.2f", eps) }
		),
		value = v,
		unit = "x",
		tol = 0.02,
		short = "P/E ratio",
		hint = "P/E = share price ÷ earnings per share.",
		note = Common.fill("{p} ÷ {e} ≈ {v}x.", { p = string.format("%.2f", price), e = string.format("%.2f", eps), v = string.format("%.1f", v) }),
	}
end

local function marketCap(rng: Rng.Rng): Problem
	local shares = rng:int(20, 400)
	local price = rng:int(8, 140)
	local v = shares * price
	return {
		key = "mcap",
		label = Common.fill(
			"A company has {s} million shares outstanding at ${p} each. What is its market capitalization?",
			{ s = shares, p = price }
		),
		value = v,
		unit = "$M",
		tol = 0.01,
		short = "Market cap",
		hint = "Market cap = share price × shares outstanding.",
		note = Common.fill("{s}M × ${p} = ${v}M.", { s = shares, p = price, v = commas(v) }),
	}
end

local function portfolio(rng: Rng.Rng): Problem
	local w = rng:int(3, 8) * 10
	local rs = rng:int(6, 14)
	local rb = rng:int(2, 5)
	local v = (w * rs + (100 - w) * rb) / 100
	return {
		key = "portfolio",
		label = Common.fill(
			"Your portfolio is {w}% stocks returning {rs}% and {wb}% bonds returning {rb}%. What is the portfolio return?",
			{ w = w, rs = rs, wb = 100 - w, rb = rb }
		),
		value = v,
		unit = "%",
		tol = 0.02,
		scales = { 1, 100 },
		short = "Portfolio return",
		hint = "A portfolio's return is the weighted average of its parts.",
		note = Common.fill("{w}% × {rs}% + {wb}% × {rb}% = {v}%.", { w = w, rs = rs, wb = 100 - w, rb = rb, v = string.format("%.1f", v) }),
	}
end

local function npv(rng: Rng.Rng): Problem
	local c0 = rng:int(10, 40) * 100
	local r = rng:int(5, 12)
	local c = math.floor(c0 * rng:range(0.5, 0.7) / 50 + 0.5) * 50
	local v = -c0 + c / (1 + r / 100) + c / (1 + r / 100) ^ 2
	return {
		key = "npv",
		label = Common.fill(
			"A project costs ${c0} today and pays ${c} at the end of each of the next 2 years. At {r}%, what is its NPV?",
			{ c0 = commas(c0), c = commas(c), r = r }
		),
		value = v,
		unit = "$",
		tol = 0.03,
		floor = c0 * 0.08,
		short = "NPV",
		hint = "NPV = −cost + each cash flow ÷ (1 + rate)^year.",
		note = Common.fill(
			"−${c0} + ${c} ÷ 1.{rr} + ${c} ÷ 1.{rr}² ≈ ${v}.",
			{ c0 = commas(c0), c = commas(c), rr = string.format("%02d", r), v = commas(v) }
		),
	}
end

local function doubling(rng: Rng.Rng): Problem
	local r = rng:pick({ 3, 4, 6, 8, 9, 12 })
	local v = 72 / r
	return {
		key = "rule72",
		label = Common.fill(
			"Using the Rule of 72, roughly how many years does money take to double at {r}% a year?",
			{ r = r }
		),
		value = v,
		unit = "years",
		tol = 0.03,
		short = "Doubling time",
		hint = "Rule of 72: years to double ≈ 72 ÷ rate (in %).",
		note = Common.fill("72 ÷ {r} = {v} years.", { r = r, v = string.format("%.0f", v) }),
	}
end

local EASY = { growth, margin, pe, marketCap, doubling }
local MEDIUM = { fv, pv, portfolio }
local HARD = { npv }

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local count = 3 + (tier - 1) -- 3 / 4 / 5
	local makers: { (Rng.Rng) -> Problem } = {}
	local easy = Common.pickN(rng, EASY, #EASY)
	local medium = Common.pickN(rng, MEDIUM, #MEDIUM)
	if tier == 1 then
		makers = { easy[1], easy[2], medium[1] }
	elseif tier == 2 then
		makers = { easy[1], easy[2], medium[1], medium[2] }
	else
		makers = { easy[1], medium[1], medium[2], easy[2], HARD[1] }
	end
	local fields: { any } = {}
	local secretFields: { [string]: any } = {}
	local order: { string } = {}
	local hintLines: { string } = {}
	for i = 1, math.min(count, #makers) do
		local p = makers[i](rng)
		local id = p.key
		local field, sf = Build.fillField(id, p.label, p.value, {
			unit = p.unit,
			tol = p.tol,
			floor = p.floor,
			scales = p.scales,
			note = p.note,
			short = p.short,
			hint = if ctx.hints >= 3 then p.hint else nil,
		})
		table.insert(fields, field)
		secretFields[id] = sf
		table.insert(order, id)
		table.insert(hintLines, p.hint)
	end
	local payload: { [string]: any } = {
		kind = "fill",
		title = Task.title,
		prompt = "Professor Halvorsen wants these by the end of class. Round sensibly; close answers earn partial credit.",
		fields = fields,
		hints = Common.hints(ctx, hintLines),
	}
	return payload,
		{
			kind = "fill",
			fields = secretFields,
			fieldOrder = order,
			summary = {
				great = "Full marks. The professor writes “See me about the Finance Club” on your sheet.",
				bad = "The professor circles most of it in red. Review the formulas and try again.",
			},
		}
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
