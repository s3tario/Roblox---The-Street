--!strict
-- dcf_build (owned by `work`; contracts §8): building the discounted cash flow for a client's valuation.
-- Kind "multi": (1) "fill" on a projection table: year-1 unlevered free cash flow (EBIT after tax + D&A − capex
-- − change in working capital), the Gordon-growth terminal value, its present value and (hard) the enterprise
-- value; (2) "mcq" on DCF judgement (WACC, terminal growth, add-backs).

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "dcf_build",
	title = "DCF Build",
	desc = "Finish the DCF: free cash flow, terminal value and what it's all worth today.",
	kind = "multi",
	tracks = { "ib" },
	ranks = { 1, 2 },
	category = "work",
	core = true,
	stats = { "skill", "knowledge" },
	clientFacing = false,
	timeLimit = 300,
	baseXp = 85,
	basePay = 560,
	cooldown = 300,
}

local CONCEPTS: { Bank.McqEntry } = {
	{
		text = "The MD wants a sensitivity: if WACC rises from {w}% to {w2}%, the enterprise value…",
		correct = "Falls",
		wrong = { "Rises", "Stays the same", "Can't change: WACC only affects equity value" },
		explain = "A higher discount rate shrinks the present value of every future cash flow.",
		hint = "Higher discount rate → lower present value.",
	},
	{
		text = "Which terminal growth rate is most defensible?",
		correct = "About 2–3%, close to long-run economic growth",
		wrong = { "{g2}%, this year's revenue growth", "Higher than the WACC", "Exactly 0% for every company" },
		explain = "No business outgrows the economy forever; the Gordon formula also breaks if g ≥ WACC.",
		hint = "Terminal growth should sit near long-run economic growth.",
	},
	{
		text = "Why add depreciation back when going from EBIT to free cash flow?",
		correct = "It's a non-cash expense that lowered EBIT",
		wrong = { "Because it's a cash inflow", "To double count it for safety", "Because taxes are paid on it" },
		explain = "D&A reduces accounting profit without any cash leaving, so it's added back.",
	},
	{
		text = "Unlevered free cash flow is the cash available to…",
		correct = "All capital providers, before interest payments",
		wrong = { "Only shareholders, after interest", "Only lenders", "The tax authority" },
		explain = "Unlevered FCF ignores financing, so it's discounted at the WACC to get enterprise value.",
	},
	{
		text = "The terminal value is {pct}% of the enterprise value. What should you tell the MD?",
		correct = "That's typical, but the value is very sensitive to the growth and WACC assumptions",
		wrong = {
			"The model is broken: it should be under 10%",
			"Drop the terminal value entirely",
			"Nothing: it doesn't matter",
		},
		explain = "Terminal value is usually most of a DCF, which is why its assumptions get stress-tested.",
	},
}

local function r1(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local company = Universe.company(rng)
	local years = 2 + tier -- 3 / 4 / 5 projection years
	local tax = rng:pick({ 21, 24, 25, 27 })
	local wacc = rng:int(8, 12)
	local g = rng:pick({ 2, 2.5, 3 })
	local ebit = rng:int(40, 240)
	local da = math.floor(ebit * rng:range(0.15, 0.3) + 0.5)
	local capex = math.floor(da * rng:range(1.0, 1.4) + 0.5)
	local nwc = rng:int(2, math.max(3, math.floor(ebit * 0.08)))
	local growth = rng:range(0.04, 0.09)

	local rows: { { string } } = {}
	local fcfs: { number } = {}
	for y = 1, years do
		local e = r1(ebit * (1 + growth) ^ (y - 1))
		local d = r1(da * (1 + growth) ^ (y - 1))
		local c = r1(capex * (1 + growth) ^ (y - 1))
		local w = r1(nwc * (1 + growth * 0.5) ^ (y - 1))
		local taxes = r1(e * tax / 100)
		local fcf = e - taxes + d - c - w
		table.insert(fcfs, fcf)
		table.insert(rows, {
			"Year " .. y,
			string.format("%.1f", e),
			string.format("%.1f", taxes),
			string.format("%.1f", d),
			string.format("%.1f", c),
			string.format("%.1f", w),
			if y == 1 then "?" else string.format("%.1f", fcf),
		})
	end
	local fcfN = r1(fcfs[years])
	local tv = fcfN * (1 + g / 100) / ((wacc - g) / 100)
	local pvTv = tv / (1 + wacc / 100) ^ years
	local pvFcf = 0
	for y, f in fcfs do
		pvFcf += f / (1 + wacc / 100) ^ y
	end
	pvFcf = r1(pvFcf)
	local ev = pvFcf + pvTv

	local fields: { any } = {}
	local secretFields: { [string]: any } = {}
	local order: { string } = {}
	local function add(id: string, label: string, value: number, opts: Build.FillOpts)
		local field, sf = Build.fillField(id, label, value, opts)
		table.insert(fields, field)
		secretFields[id] = sf
		table.insert(order, id)
	end
	add("fcf1", "Year 1 unlevered free cash flow", fcfs[1], {
		unit = "$M",
		tol = 0.02,
		floor = 5,
		short = "Year 1 FCF",
		note = Common.fill("EBIT − taxes + D&A − capex − ΔNWC: {a} − {b} + {c} − {d} − {e} = {v}.", {
			a = rows[1][2],
			b = rows[1][3],
			c = rows[1][4],
			d = rows[1][5],
			e = rows[1][6],
			v = string.format("%.1f", fcfs[1]),
		}),
	})
	add("tv", Common.fill("Terminal value at the end of year {n}", { n = years }), tv, {
		unit = "$M",
		tol = 0.025,
		short = "Terminal value",
		note = Common.fill("FCF × (1 + g) ÷ (WACC − g) = {f} × {gg} ÷ {d} ≈ ${v}M.", {
			f = string.format("%.1f", fcfN),
			gg = string.format("%.3f", 1 + g / 100),
			d = string.format("%.3f", (wacc - g) / 100),
			v = Common.commas(tv),
		}),
	})
	if tier >= 2 then
		add("pv_tv", "Present value of the terminal value", pvTv, {
			unit = "$M",
			tol = 0.03,
			short = "PV of terminal value",
			note = Common.fill("TV ÷ (1 + WACC)^{n} = {tv} ÷ {f} ≈ ${v}M.", {
				n = years,
				tv = Common.commas(tv),
				f = string.format("%.3f", (1 + wacc / 100) ^ years),
				v = Common.commas(pvTv),
			}),
		})
	end
	if tier >= 3 then
		add("ev", "Enterprise value", ev, {
			unit = "$M",
			tol = 0.03,
			short = "Enterprise value",
			note = Common.fill("PV of the cash flows + PV of the terminal value = {a} + {b} ≈ ${v}M.", {
				a = Common.commas(pvFcf),
				b = Common.commas(pvTv),
				v = Common.commas(ev),
			}),
		})
	end

	local vars =
		{ w = wacc, w2 = wacc + 1, g2 = math.floor(growth * 100 + 0.5) + 10, pct = math.floor(pvTv / ev * 100 + 0.5) }
	local specs, conceptHints = Bank.mcq(rng, CONCEPTS, if tier >= 3 then 2 else 1, vars)
	local questions, mcqSecret = Build.mcq(rng, specs)
	local hints: { string } = {
		"Unlevered FCF = EBIT − taxes + D&A − capex − increase in working capital.",
		"Terminal value = final-year FCF × (1 + g) ÷ (WACC − g).",
		"Discount a value received in year n by dividing by (1 + WACC)^n.",
	}
	for _, h in conceptHints do
		table.insert(hints, h)
	end

	local prompt = Common.fill("{c}: WACC {w}%, terminal growth {g}%, tax rate {t}%. Figures in $M.{pv}", {
		c = company.name,
		w = wacc,
		g = g,
		t = tax,
		pv = if tier >= 3
			then Common.fill(" PV of the projected cash flows: ${v}M.", { v = Common.commas(pvFcf, 1) })
			else "",
	})
	return {
		kind = "multi",
		title = Task.title,
		prompt = prompt,
		sections = {
			{
				kind = "fill",
				title = "The model",
				prompt = "Fill in the blanks. Close answers earn partial credit.",
				table = {
					columns = { "Year", "EBIT", "Taxes", "D&A", "Capex", "ΔNWC", "UFCF" },
					rows = rows,
				},
				fields = fields,
			},
			{ kind = "mcq", title = "Judgement", prompt = "The MD has questions.", questions = questions },
		} :: { any },
		hints = Common.hints(ctx, hints),
	}, {
		kind = "multi",
		sections = { { kind = "fill", fields = secretFields, fieldOrder = order }, mcqSecret },
		weights = { 0.75, 0.25 },
		summary = {
			great = "The DCF ties out. The VP drops it straight into the pitch.",
			bad = "The VP finds the cash flow and terminal value off. Walk the formulas again.",
		},
	}
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
