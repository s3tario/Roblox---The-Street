--!strict
-- merger_model_check (owned by `work`; contracts §8): an accretion/dilution check on a proposed acquisition.
-- Kind "fill" with an input table. All-stock deals at easier tiers (new shares, pro forma EPS, accretion); the hard
-- tier is half cash (funded with new debt) and half stock, adding the after-tax interest cost. Percentages accept
-- 4.2 or 0.042.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "merger_model_check",
	title = "Merger Model Check",
	desc = "Is the deal accretive? Check the merger model's pro forma EPS before the client call.",
	kind = "fill",
	tracks = { "ib" },
	ranks = { 2, 3 },
	category = "work",
	core = true,
	stats = { "skill", "knowledge" },
	clientFacing = false,
	timeLimit = 270,
	baseXp = 85,
	basePay = 560,
	cooldown = 300,
}

local function r2(x: number): number
	return math.floor(x * 100 + 0.5) / 100
end

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local buyer = Universe.company(rng).name
	local target = Universe.company(rng).name
	if target == buyer then
		target = Universe.company(rng, "logistics").name
	end
	local niA = rng:int(30, 120) * 10
	local sharesA = rng:int(10, 60) * 10
	local epsA = r2(niA / sharesA)
	local peA = rng:int(14, 24)
	local priceA = r2(epsA * peA)
	local niT = rng:int(6, 30) * 5
	local peT = rng:int(10, 22)
	local purchase = niT * peT
	local cashShare = if tier >= 3 then 0.5 else 0
	local rate = rng:pick({ 5, 6, 7, 8 })
	local tax = 25
	local stockPart = purchase * (1 - cashShare)
	local cashPart = purchase * cashShare
	local newShares = stockPart / priceA
	local interest = cashPart * rate / 100 * (1 - tax / 100)
	local pfNi = niA + niT - interest
	local pfEps = pfNi / (sharesA + newShares)
	local accretion = (pfEps / epsA - 1) * 100

	local fields: { any } = {}
	local secretFields: { [string]: any } = {}
	local order: { string } = {}
	local function add(id: string, label: string, value: number, opts: Build.FillOpts)
		local field, sf = Build.fillField(id, label, value, opts)
		table.insert(fields, field)
		secretFields[id] = sf
		table.insert(order, id)
	end
	add("new_shares", "New shares issued (millions)", newShares, {
		unit = "M",
		tol = 0.02,
		short = "New shares",
		note = Common.fill("Stock paid ÷ the buyer's share price = ${s}M ÷ ${p} ≈ {v}M shares.", {
			s = Common.commas(stockPart),
			p = string.format("%.2f", priceA),
			v = string.format("%.1f", newShares),
		}),
	})
	if tier >= 3 then
		add("interest", "After-tax interest on the new debt", interest, {
			unit = "$M",
			tol = 0.02,
			short = "After-tax interest",
			note = Common.fill("${c}M × {r}% × (1 − {t}%) = ${v}M.", {
				c = Common.commas(cashPart),
				r = rate,
				t = tax,
				v = string.format("%.1f", interest),
			}),
		})
	end
	add("pf_eps", "Pro forma EPS", pfEps, {
		unit = "$",
		tol = 0.015,
		short = "Pro forma EPS",
		note = Common.fill("(Buyer NI + target NI{minus}) ÷ (buyer shares + new shares) = ${v}.", {
			minus = if tier >= 3 then " − after-tax interest" else "",
			v = string.format("%.2f", pfEps),
		}),
	})
	if tier >= 2 then
		add("accretion", "Accretion (+) or dilution (−), %", accretion, {
			unit = "%",
			tol = 0.1,
			floor = 2,
			scales = { 1, 100 },
			short = "Accretion / dilution",
			note = Common.fill("Pro forma EPS ÷ standalone EPS − 1 = {v}%: the deal is {word}.", {
				v = string.format("%.1f", accretion),
				word = if accretion >= 0 then "accretive" else "dilutive",
			}),
		})
	end

	local rows: { { string } } = {
		{ "Net income ($M)", Common.commas(niA), Common.commas(niT) },
		{ "Shares outstanding (M)", Common.commas(sharesA), "—" },
		{ "Share price ($)", string.format("%.2f", priceA), "—" },
		{ "EPS ($)", string.format("%.2f", epsA), "—" },
		{ "Purchase price ($M)", "—", Common.commas(purchase) },
	}
	local structure = if tier >= 3
		then Common.fill(
			"Half cash (new debt at {r}%, {t}% tax), half new {b} shares.",
			{ r = rate, t = tax, b = buyer }
		)
		else Common.fill("All stock: {b} issues new shares at its current price.", { b = buyer })
	local hintLines = {
		"New shares = the stock part of the price ÷ the buyer's share price.",
		"Pro forma EPS = combined net income ÷ combined share count.",
		"Accretion % = pro forma EPS ÷ standalone EPS − 1.",
	}
	if tier >= 3 then
		table.insert(
			hintLines,
			2,
			"Debt costs interest × (1 − tax rate) after tax; subtract it from combined net income."
		)
	end
	return {
		kind = "fill",
		title = Task.title,
		prompt = Common.fill("{b} is buying {t}. {s} No synergies.", { b = buyer, t = target, s = structure }),
		table = { columns = { "", buyer, target }, rows = rows },
		fields = fields,
		hints = Common.hints(ctx, hintLines),
	}, {
		kind = "fill",
		fields = secretFields,
		fieldOrder = order,
		summary = {
			great = "Model checked and tied. The MD quotes your accretion number on the client call.",
			bad = "The pro forma maths is off. Rebuild it: share count, combined income, then EPS.",
		},
	}
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
