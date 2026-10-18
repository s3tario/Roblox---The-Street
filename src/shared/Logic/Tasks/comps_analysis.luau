--!strict
-- comps_analysis (owned by `work`; contracts §8): valuing a private company on trading comparables.
-- Kind "fill" with a peer table (EV, EBITDA, EV/EBITDA). Easy: take the median multiple and apply it. Medium: a
-- peer's multiple is blank, so compute it first, then go from enterprise value to equity value. Hard: six peers
-- (average the middle two) and finish at a value per share. Close answers earn partial credit; Skill widens the
-- tolerance (ctx.toleranceMult).

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "comps_analysis",
	title = "Trading Comps",
	desc = "Spread the comparable companies and value the client on the median EV/EBITDA multiple.",
	kind = "fill",
	tracks = { "ib" },
	ranks = { 1, 2 },
	category = "work",
	core = true,
	stats = { "skill", "knowledge" },
	clientFacing = false,
	timeLimit = 270,
	baseXp = 75,
	basePay = 520,
	cooldown = 240,
}

local function median(values: { number }): number
	local sorted = table.clone(values)
	table.sort(sorted)
	local n = #sorted
	if n % 2 == 1 then
		return sorted[(n + 1) // 2]
	end
	return (sorted[n // 2] + sorted[n // 2 + 1]) / 2
end

local function r1(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local sectorId = rng:pick(Universe.sectorIds)
	local sector = Universe.sector(sectorId)
	local target = Universe.company(rng, sectorId).name
	local nPeers = if tier >= 3 then 6 else 5
	local names = Universe.peers(rng, sectorId, nPeers, { target })
	local rows: { { string } } = {}
	local multiples: { number } = {}
	local hidden = if tier >= 2 then rng:int(1, #names) else 0
	local hiddenName = ""
	local hiddenValue = 0
	for i, name in names do
		local ebitda = rng:int(16, 180) * 5
		local m = rng:range(sector.evEbitda[1], sector.evEbitda[2])
		local ev = math.floor(ebitda * m / 10 + 0.5) * 10
		local multiple = r1(ev / ebitda)
		table.insert(multiples, multiple)
		local shown = string.format("%.1fx", multiple)
		if i == hidden then
			shown = "?"
			hiddenName = name
			hiddenValue = ev / ebitda
		end
		table.insert(rows, { name, Common.commas(ev), Common.commas(ebitda), shown })
	end
	local med = median(multiples)
	local targetEbitda = rng:int(12, 90) * 5
	local netDebt = math.floor(targetEbitda * rng:range(0.5, 2.5) / 5 + 0.5) * 5
	local shares = rng:int(20, 160)
	local ev = med * targetEbitda
	local equity = ev - netDebt
	local perShare = equity / shares

	local fields: { any } = {}
	local secretFields: { [string]: any } = {}
	local order: { string } = {}
	local function add(id: string, label: string, value: number, opts: Build.FillOpts)
		local field, sf = Build.fillField(id, label, value, opts)
		table.insert(fields, field)
		secretFields[id] = sf
		table.insert(order, id)
	end
	if hidden > 0 then
		add("peer_multiple", Common.fill("{name}'s EV/EBITDA", { name = hiddenName }), hiddenValue, {
			unit = "x",
			tol = 0.02,
			short = hiddenName .. " multiple",
			note = Common.fill(
				"EV ÷ EBITDA for {name} = {v}x.",
				{ name = hiddenName, v = string.format("%.1f", hiddenValue) }
			),
			hint = if ctx.hints >= 3 then "EV ÷ EBITDA" else nil,
		})
	end
	add("median", "Median peer EV/EBITDA", med, {
		unit = "x",
		tol = 0.015,
		short = "Median multiple",
		note = if nPeers % 2 == 0
			then "With six peers, the median is the average of the 3rd and 4th multiples once sorted."
			else "The median is the middle multiple once the five are sorted.",
		hint = if ctx.hints >= 3 then "Sort the multiples first" else nil,
	})
	add("ev", Common.fill("Implied enterprise value of {t}", { t = target }), ev, {
		unit = "$M",
		tol = 0.02,
		short = "Implied EV",
		note = Common.fill("{m}x × ${e}M = ${v}M.", {
			m = string.format("%.2f", med),
			e = Common.commas(targetEbitda),
			v = Common.commas(ev),
		}),
	})
	if tier >= 2 then
		add("equity", "Implied equity value", equity, {
			unit = "$M",
			tol = 0.025,
			floor = math.abs(ev) * 0.1,
			short = "Equity value",
			note = Common.fill("EV − net debt = {ev} − {nd} = ${v}M.", {
				ev = Common.commas(ev),
				nd = Common.commas(netDebt),
				v = Common.commas(equity),
			}),
		})
	end
	if tier >= 3 then
		add("per_share", "Implied value per share", perShare, {
			unit = "$",
			tol = 0.03,
			floor = 1,
			short = "Value per share",
			note = Common.fill("${eq}M ÷ {s}M shares = ${v}.", {
				eq = Common.commas(equity),
				s = shares,
				v = string.format("%.2f", perShare),
			}),
		})
	end

	local prompt = Common.fill(
		"{t} ({sector}) has LTM EBITDA of ${e}M, net debt of ${nd}M and {s}M shares. Value it on the median peer multiple. All figures in $M.",
		{
			t = target,
			sector = string.lower(sector.name),
			e = Common.commas(targetEbitda),
			nd = Common.commas(netDebt),
			s = shares,
		}
	)
	local hintLines = {
		"EV/EBITDA = enterprise value ÷ EBITDA.",
		if nPeers % 2 == 0
			then "Median of an even count: sort, then average the two middle values."
			else "Median: sort the multiples and take the middle one.",
		"Implied EV = median multiple × the target's EBITDA; equity value = EV − net debt.",
	}
	return {
		kind = "fill",
		title = Task.title,
		prompt = prompt,
		table = { columns = { "Company", "EV ($M)", "EBITDA ($M)", "EV/EBITDA" }, rows = rows },
		fields = fields,
		hints = Common.hints(ctx, hintLines),
	}, {
		kind = "fill",
		fields = secretFields,
		fieldOrder = order,
		summary = {
			great = "The VP checks your comps and forwards them to the MD unchanged.",
			bad = "The VP sends the sheet back: recheck the multiples and the bridge to equity value.",
		},
	}
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
