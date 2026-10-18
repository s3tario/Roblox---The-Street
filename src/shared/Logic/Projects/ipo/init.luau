--!strict
-- ipo (owned by `projects`; contracts §9 signature deal "ipo", spec §7 "IB signature: take a company public"): the
-- Investment Banking signature deal for VPs and up (ranks >= 3). PURE: no services, no clocks, no Instances. Built on
-- the shared stage Machine (_registry/Machine); every line of text lives in Content.luau.
--
-- Stages (each a contracts §8 work payload, drawn by UI/WorkKinds):
--   1 pick       mcq: which of three private companies is ready to list, plus offering structure questions
--                -> the client (a flawed pick cools investor appetite)
--   2 valuation  fill: peer median, comps EV, DCF EV, value per share  -> the filed price range
--   3 pitchbook  format: flag every error in the board deck           -> credibility
--   4 roadshow   dialogue: investor Q&A                                -> depth of the order book
--   5 pricing    multi: read the order book and set the offer price (fill) + allocate the shares (alloc)
-- Outcome: the IPO-day pop = day-one close / offer price - 1. The day-one close is where the order book clears
-- (set by the stages above and the market mood), trimmed when fast money got too many shares. 10-25% is ideal;
-- below that the deal is priced rich (a negative pop "breaks issue"); above it the client left money on the table;
-- pricing above the book's clearing price means the book isn't covered and the IPO is postponed.
--
--   ipo.new / view / act / score       (Machine.build; contracts §9)
--   ipo.popScore(pop) -> 0..100        the outcome curve (tests)

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent.Parent.Tasks._shared.Common)
local Build = require(script.Parent.Parent.Tasks._shared.Build)
local Universe = require(script.Parent.Parent.Tasks._shared.Universe)
local Grade = require(script.Parent.Parent.Tasks._shared.Grade)
local Machine = require(script.Parent._registry.Machine)
local Content = require(script.Content)

type Facts = { [string]: any }
type State = Machine.State
type Ctx = Machine.Ctx

local fill = Common.fill

local IDEAL_LO, IDEAL_HI = 0.10, 0.25
local IDEAL_MID = 0.175
local FLOAT = 0.2
local FEE = 0.05 -- the underwriters' gross spread
local FLAWED_APPETITE = 0.84

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
local function round5(x: number): number
	return math.max(5, math.floor(x / 5 + 0.5) * 5)
end

local function halfDollar(x: number): number
	return math.max(0.5, math.floor(x * 2 + 0.5) / 2)
end

local function cents(x: number): number
	return math.floor(x * 100 + 0.5) / 100
end

local function dollars(x: number): string
	return string.format("%.2f", x)
end

-- "$640M" below a billion, "$1.2B" above (deal names, headlines, figures).
local function compact(m: number): string
	if m >= 1000 then
		local s = string.format("%.1f", m / 1000)
		s = string.gsub(s, "%.0$", "")
		return "$" .. s .. "B"
	end
	return "$" .. Common.commas(m) .. "M"
end

local function pctText(ratio: number): string
	return string.format("%d%%", math.floor(math.abs(ratio) * 100 + 0.5))
end

local function count(ctx: Ctx, easy: number, medium: number, hard: number): number
	local tier = Common.tier(ctx)
	return if tier == 1 then easy elseif tier == 2 then medium else hard
end

local function band(score: number): string
	return if score >= 85 then "great" elseif score >= 60 then "good" else "weak"
end

local function with(base: { [string]: any }, extra: { [string]: any }): { [string]: any }
	local out = table.clone(base)
	for k, v in extra do
		out[k] = v
	end
	return out
end

local function section(answers: any, i: number): { [string]: any }
	if type(answers) ~= "table" then
		return {}
	end
	local a = answers[i]
	if a == nil then
		a = answers[tostring(i)]
	end
	return if type(a) == "table" then a else {}
end

local function vars(f: Facts): { [string]: any }
	return {
		company = if f.company ~= "" then f.company else "",
		codename = f.codename,
		firm = f.firm,
		sector = f.sectorName,
		rev = Common.commas(f.rev),
		growth = f.growth,
		margin = f.margin,
		badMargin = f.badMargin,
		ebitda = Common.commas(f.ebitda),
		month = f.month,
		year = f.year,
		oldYear = f.oldYear,
		median = Grade.show(f.median),
		rangeMult = Grade.show(f.rangeMult),
		valueLo = dollars(f.valueLo),
		valueHi = dollars(f.valueHi),
		shares = Common.commas(f.shares),
		sold = Common.commas(f.sold),
		floatPct = f.floatPct,
		badFloat = f.badFloat,
		loan = Common.commas(f.loan),
		anchor = f.anchor,
		peer = f.peer,
		retention = f.retention,
		top1 = f.top1,
		netDebt = Common.commas(f.netDebt),
	}
end

---------------------------------------------------------------------------------------------------
-- The scenario
---------------------------------------------------------------------------------------------------
local FLAWS = { "governance", "slowing", "early", "cyclical" }

local function candidate(rng: Rng.Rng, kind: string, sectorId: string, taken: { [string]: boolean }): Facts
	local sector = Universe.sector(sectorId)
	local name = Universe.company(rng, sectorId).name
	local guard = 0
	while taken[name] and guard < 10 do
		guard += 1
		name = Universe.company(rng, sectorId).name
	end
	if taken[name] then
		name = name .. " Group"
	end
	taken[name] = true
	local rev = Common.round(rng:range(900, 4200), 10)
	local margin = math.floor(rng:range(sector.margin[1], sector.margin[2]) * 100 + 0.5)
	local growth = math.floor(rng:range(sector.growth[1], sector.growth[2]) * 100 + 0.5) + rng:int(3, 6)
	if kind == "slowing" then
		growth = rng:int(2, 4)
		margin = math.max(6, margin - rng:int(4, 7))
	elseif kind == "cyclical" then
		margin += rng:int(6, 10)
	end
	local ebitda = math.max(20, math.floor(rev * margin / 100 + 0.5))
	margin = math.floor(ebitda / rev * 100 + 0.5)
	return {
		kind = kind,
		name = name,
		sector = sectorId,
		sectorName = sector.name,
		rev = rev,
		growth = growth,
		margin = margin,
		ebitda = ebitda,
	}
end

local function init(rng: Rng.Rng, ctx: Ctx): Facts
	local taken: { [string]: boolean } = {}
	local flaws = Common.pickN(rng, FLAWS, 2)
	local candidates = {
		candidate(rng, "ready", rng:pick(Content.sectors), taken),
		candidate(rng, flaws[1], rng:pick(Content.sectors), taken),
		candidate(rng, flaws[2], rng:pick(Content.sectors), taken),
	}
	local year = Common.year(ctx)
	return {
		codename = Universe.codename(rng),
		firm = ctx.companyName or Universe.firm(rng),
		month = Universe.month(rng),
		year = year,
		oldYear = year - 2,
		anchor = rng:pick(Content.fundNames),
		retention = rng:int(91, 97),
		top1 = rng:int(8, 14),
		candidates = candidates,
		-- the client (set by stage 1)
		pickedKind = "",
		company = "",
		sector = "",
		sectorName = "",
		rev = 0,
		growth = 0,
		margin = 0,
		badMargin = 0,
		ebitda = 0,
		appetite = 1,
		-- valuation (set by stage 2)
		valued = false,
		median = 0,
		compsEv = 0,
		dcfEv = 0,
		netDebt = 0,
		shares = 0,
		perShare = 0,
		valueLo = 0,
		valueHi = 0,
		rangeMult = 0,
		peer = "",
		sold = 0,
		floatPct = 0,
		badFloat = 0,
		loan = 0,
		-- scores that drive the order book
		valuationScore = 0,
		pitchbookScore = 0,
		roadshowScore = -1,
		mood = 1,
		-- pricing (set by stage 5)
		priced = false,
		clearing = 0,
		ideal = 0,
		offer = 0,
		allocScore = 0,
	}
end

---------------------------------------------------------------------------------------------------
-- Stage 1: choose the client
---------------------------------------------------------------------------------------------------
local function buildPick(state: State, rng: Rng.Rng, ctx: Ctx): ({ [string]: any }, { [string]: any }, { [string]: any }?)
	local f = state.facts
	local shown = rng:shuffle(f.candidates)
	local context: { string } = {}
	local nameToIndex: { [string]: number } = {}
	local readyName = ""
	local wrong: { string } = {}
	for _, c in shown do
		table.insert(
			context,
			fill(Content.candidateLine, {
				name = c.name,
				sector = c.sectorName,
				rev = Common.commas(c.rev),
				growth = c.growth,
				margin = c.margin,
				note = Content.candidateNotes[c.kind] or "",
			})
		)
		for i, original in f.candidates do
			if original.name == c.name then
				nameToIndex[c.name] = i
			end
		end
		if c.kind == "ready" then
			readyName = c.name
		else
			table.insert(wrong, c.name)
		end
	end
	local specs: { Build.McqSpec } = {
		{
			id = "q_pick",
			text = Content.pickQuestion,
			context = table.concat(context, "\n\n"),
			correct = readyName,
			wrong = wrong,
			explain = fill(Content.pickExplain, { ready = readyName }),
		},
	}
	for _, q in Common.pickN(rng, Content.structureQuestions, count(ctx, 1, 2, 3)) do
		table.insert(specs, {
			id = q.id,
			text = q.text,
			correct = q.correct,
			wrong = q.wrong,
			explain = q.explain,
		})
	end
	local questions, secret = Build.mcq(rng, specs)
	local optionIndex: { number } = {}
	for i, text in questions[1].options do
		optionIndex[i] = nameToIndex[text] or 1
	end
	local payload: { [string]: any } = {
		kind = "mcq",
		title = Content.stages.pick.title,
		prompt = Content.prompts.pick,
		hints = Common.hints(ctx, Content.pickHints),
		questions = questions,
	}
	return payload, secret, { optionIndex = optionIndex }
end

local function applyPick(state: State, _graded: Grade.Result, answers: any, meta: { [string]: any }, _ctx: Ctx): string?
	local f = state.facts
	local a = if type(answers) == "table" then answers else {}
	local chosen = Grade.number(a.q_pick)
	local map = if type(meta.optionIndex) == "table" then meta.optionIndex else {}
	-- no pick: the MD takes the first company on the list
	local index = if chosen and map[chosen] then map[chosen] else (map[1] or 1)
	local c = f.candidates[index] or f.candidates[1]
	f.pickedKind = c.kind
	f.company = c.name
	f.sector = c.sector
	f.sectorName = c.sectorName
	f.rev = c.rev
	f.growth = c.growth
	f.margin = c.margin
	f.badMargin = c.margin + (if c.margin > 12 then -4 else 4)
	f.ebitda = c.ebitda
	f.appetite = if c.kind == "ready" then 1 else FLAWED_APPETITE
	return fill(if c.kind == "ready" then Content.pickDebrief.ready else Content.pickDebrief.flawed, vars(f))
end

---------------------------------------------------------------------------------------------------
-- Stage 2: valuation
---------------------------------------------------------------------------------------------------
local function buildValuation(state: State, rng: Rng.Rng, ctx: Ctx): ({ [string]: any }, { [string]: any }, { [string]: any }?)
	local f = state.facts
	local sector = Universe.sector(f.sector)
	local e = f.ebitda
	local mid = (sector.evEbitda[1] + sector.evEbitda[2]) / 2
	local offsets = rng:shuffle({ -2.2, -0.6, 0.9, 2.6 })
	local peers = Universe.peers(rng, f.sector, 4, { f.company })
	while #peers < 4 do
		table.insert(peers, Universe.company(rng, f.sector).name .. " " .. tostring(#peers + 1))
	end
	local rows: { { string } } = {}
	local multiples: { number } = {}
	local hard = Common.tier(ctx) >= 3
	local biggest, biggestEbitda = peers[1], 0
	for i, name in peers do
		local mult = math.max(3, Common.round(mid + offsets[i] + rng:range(-0.3, 0.3), 0.1))
		local peerEbitda = math.max(10, Common.round(e * rng:range(0.6, 3.2), 5))
		local ev = Common.round(peerEbitda * mult, 5)
		local exact = ev / peerEbitda
		table.insert(multiples, exact)
		if peerEbitda > biggestEbitda then
			biggest, biggestEbitda = name, peerEbitda
		end
		table.insert(rows, {
			name,
			Common.commas(ev),
			Common.commas(peerEbitda),
			if hard then "?" else Common.mult(exact),
		})
	end
	local sorted = table.clone(multiples)
	table.sort(sorted)
	local median = (sorted[2] + sorted[3]) / 2
	local compsEv = median * e
	local fcf = math.max(5, Common.round(e * rng:range(0.55, 0.7), 1))
	local wacc = rng:int(8, 10)
	local g = rng:pick({ 2, 2.5, 3 })
	local dcfEv = fcf / ((wacc - g) / 100)
	local netDebt = round5(e * rng:range(0.4, 1.4))
	local equity = math.max(e, (compsEv + dcfEv) / 2 - netDebt)
	local shares = math.max(10, math.floor(equity / rng:range(18, 42) + 0.5))
	local perShare = equity / shares

	local v = with(vars(f), {
		fcf = Common.commas(fcf),
		wacc = wacc,
		g = Grade.show(g),
		netDebt = Common.commas(netDebt),
		shares = Common.commas(shares),
	})
	local notes = Content.valuationNotes
	local fields: { any } = {}
	local fieldSecret: { [string]: any } = {}
	local order: { string } = {}
	local function add(id: string, value: number, opts: { [string]: any })
		local field, sec = Build.fillField(id, fill((Content.valuationFields :: any)[id], v), value, opts :: any)
		table.insert(fields, field)
		fieldSecret[id] = sec
		table.insert(order, id)
	end
	add("median", median, {
		unit = "x",
		tol = 0.02,
		short = Content.valuationShort.median,
		note = fill(notes.median, { a = Grade.show(sorted[2]), b = Grade.show(sorted[3]) }),
	})
	add("comps", compsEv, { unit = "$M", tol = 0.03, short = Content.valuationShort.comps })
	add("dcf", dcfEv, {
		unit = "$M",
		tol = 0.03,
		short = Content.valuationShort.dcf,
		note = fill(notes.dcf, {
			fcf = Common.money(fcf),
			wacc = wacc,
			g = Grade.show(g),
			dcf = Common.money(dcfEv),
		}),
	})
	add("perShare", perShare, {
		unit = "$",
		tol = 0.04,
		short = Content.valuationShort.perShare,
		note = fill(notes.perShare, {
			comps = Common.money(compsEv),
			dcf = Common.money(dcfEv),
			netDebt = Common.money(netDebt),
			shares = Common.commas(shares),
			perShare = "$" .. dollars(perShare),
		}),
	})
	local payload: { [string]: any } = {
		kind = "fill",
		title = Content.stages.valuation.title,
		prompt = fill(Content.prompts.valuation, v),
		hints = Common.hints(ctx, Content.valuationHints),
		table = { columns = Content.compColumns, rows = rows },
		fields = fields,
	}
	local secret = { kind = "fill", fields = fieldSecret, fieldOrder = order }
	return payload,
		secret,
		{
			median = median,
			compsEv = compsEv,
			dcfEv = dcfEv,
			netDebt = netDebt,
			shares = shares,
			perShare = perShare,
			peer = biggest,
		}
end

local function applyValuation(
	state: State,
	graded: Grade.Result,
	_answers: any,
	meta: { [string]: any },
	_ctx: Ctx
): string?
	local f = state.facts
	f.valued = true
	f.median = Common.num(meta.median, 10)
	f.compsEv = Common.num(meta.compsEv, f.ebitda * 10)
	f.dcfEv = Common.num(meta.dcfEv, f.ebitda * 10)
	f.netDebt = Common.num(meta.netDebt, 0)
	f.shares = math.max(1, Common.num(meta.shares, 100))
	f.perShare = math.max(1, Common.num(meta.perShare, 20))
	f.peer = if type(meta.peer) == "string" then meta.peer else f.company
	f.valueLo = halfDollar(f.perShare * 0.92)
	f.valueHi = math.max(f.valueLo + 1, halfDollar(f.perShare * 1.04))
	local midValue = (f.valueLo + f.valueHi) / 2
	f.rangeMult = Common.round((midValue * f.shares + f.netDebt) / f.ebitda, 0.1)
	f.sold = math.max(1, math.floor(f.shares * FLOAT + 0.5))
	f.floatPct = math.floor(f.sold / f.shares * 100 + 0.5)
	f.badFloat = f.floatPct + 7
	f.loan = round5(f.netDebt * 0.6)
	f.valuationScore = graded.quality
	local range = "$" .. dollars(f.valueLo) .. "–$" .. dollars(f.valueHi)
	return fill(Content.valuationDebrief[band(graded.quality)], { range = range })
end

---------------------------------------------------------------------------------------------------
-- Stage 3: the pitchbook
---------------------------------------------------------------------------------------------------
local function buildPitchbook(state: State, rng: Rng.Rng, ctx: Ctx): ({ [string]: any }, { [string]: any }, { [string]: any }?)
	local f = state.facts
	local v = vars(f)
	local elements = Content.elements
	local brokenCount = count(ctx, 3, 4, 5)
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
				local word = if variant.typo == "firm" then f.firm else f.company
				local misspelt = Common.typo(rng, word)
				local a, b = string.find(clean, word, 1, true)
				text = if a and b and misspelt ~= word
					then string.sub(clean, 1, a - 1) .. misspelt .. string.sub(clean, b + 1)
					else clean .. " " .. Common.typo(rng, "Confidential")
			else
				text = fill(variant.text or el.clean, v)
			end
			table.insert(specs, { text = text, kind = el.kind, issues = { variant.issue }, note = fill(variant.note, v) })
		else
			table.insert(specs, { text = fill(el.clean, v), kind = el.kind, issues = {} })
		end
	end
	local shownElements, issues, secret = Build.format(rng, specs, Content.issues)
	secret.summary = Content.pitchbookSummary
	local payload: { [string]: any } = {
		kind = "format",
		title = Content.stages.pitchbook.title,
		prompt = fill(Content.prompts.pitchbook, v),
		hints = Common.hints(ctx, Content.pitchbookHints),
		elements = shownElements,
		issues = issues,
	}
	return payload, secret, nil
end

local function applyPitchbook(
	state: State,
	graded: Grade.Result,
	_answers: any,
	_meta: { [string]: any },
	_ctx: Ctx
): string?
	local f = state.facts
	f.pitchbookScore = graded.quality
	return Content.pitchbookDebrief[band(graded.quality)]
end

---------------------------------------------------------------------------------------------------
-- Stage 4: the roadshow
---------------------------------------------------------------------------------------------------
local function buildRoadshow(state: State, rng: Rng.Rng, ctx: Ctx): ({ [string]: any }, { [string]: any }, { [string]: any }?)
	local f = state.facts
	local v = with(vars(f), { person = Universe.person(rng), fund = rng:pick(Content.fundNames) })
	local speaker = fill(Content.roadshowSpeaker, v)
	local specs: { Build.DialogueSpec } = {}
	for _, line in Common.pickN(rng, Content.roadshowLines, count(ctx, 4, 5, 6)) do
		local options: { Build.DialogueOption } = {}
		for _, o in line.options do
			table.insert(options, {
				text = fill(o.text, v),
				score = o.score,
				note = if o.note then fill(o.note, v) else nil,
			})
		end
		table.insert(specs, { id = line.id, text = fill(line.text, v), options = options })
	end
	local lines, secret = Build.dialogue(rng, specs)
	local payload: { [string]: any } = {
		kind = "dialogue",
		title = Content.stages.roadshow.title,
		prompt = fill(Content.prompts.roadshow, with(v, { speaker = speaker })),
		hints = Common.hints(ctx, Content.roadshowHints),
		speaker = speaker,
		lines = lines,
	}
	return payload, secret, nil
end

local function applyRoadshow(state: State, graded: Grade.Result, _answers: any, _meta: { [string]: any }, ctx: Ctx): string?
	local f = state.facts
	f.roadshowScore = graded.quality
	f.mood = Common.clamp(ctx.marketMood, 0.8, 1.2)
	return Content.roadshowDebrief[band(graded.quality)]
end

---------------------------------------------------------------------------------------------------
-- Stage 5: pricing and allocation
---------------------------------------------------------------------------------------------------
-- How hot the book is: the client, the work so far and the market (about 0.75 .. 1.32).
local function hype(f: Facts): number
	local rs = math.max(0, Common.num(f.roadshowScore, 0)) / 100
	local pb = Common.num(f.pitchbookScore, 0) / 100
	local val = Common.num(f.valuationScore, 0) / 100
	local mood = 1 + (Common.clamp(Common.num(f.mood, 1), 0.8, 1.2) - 1) * 0.5
	return Common.num(f.appetite, 1) * (0.92 + 0.18 * rs + 0.06 * pb + 0.04 * val) * mood
end

local BOOK_STEPS = { 1.16, 1.08, 1.0, 0.93, 0.86, 0.79, 0.72 }

local function buildPricing(state: State, _rng: Rng.Rng, ctx: Ctx): ({ [string]: any }, { [string]: any }, { [string]: any }?)
	local f = state.facts
	local clearing = halfDollar(f.perShare * hype(f))
	local ideal = cents(clearing / (1 + IDEAL_MID))
	local showOrders = Common.tier(ctx) >= 3
	local rows: { { string } } = {}
	local seen: { [number]: boolean } = {}
	for _, step in BOOK_STEPS do
		local price = if step == 1 then clearing else halfDollar(clearing * step)
		if not seen[price] then
			seen[price] = true
			local coverage = (clearing / price) ^ 3
			table.insert(rows, {
				"$" .. dollars(price),
				if showOrders
					then string.format("%.1f", coverage * f.sold)
					else string.format("%.1fx", coverage),
			})
		end
	end
	local v = with(vars(f), { sold = Common.commas(f.sold) })
	local clearField, clearSecret = Build.fillField("clearing", Content.pricingFields.clearing, clearing, {
		unit = "$",
		tol = 0.02,
		short = Content.pricingShort.clearing,
	})
	local offerField, offerSecret = Build.fillField("offer", Content.pricingFields.offer, ideal, {
		unit = "$",
		tol = 0.06,
		hint = Content.offerHint,
		short = Content.pricingShort.offer,
		note = fill(Content.offerNote, { ideal = dollars(ideal) }),
	})
	local allocItems: { Build.AllocItem } = {}
	local targets: { { number } } = {}
	local notes: { string } = {}
	for _, item in Content.allocItems do
		table.insert(allocItems, { text = item.text, detail = item.detail })
		local b = (Content.allocBands :: any)[item.id]
		table.insert(targets, { b[1], b[2] })
		table.insert(notes, (Content.allocNotes :: any)[item.id])
	end
	local allocPart, allocSecret = Build.alloc(allocItems, 100, 5, targets, { unit = "%", notes = notes })
	local allocPayload: { [string]: any } = {
		kind = "alloc",
		title = Content.sections.alloc,
		prompt = Content.prompts.alloc,
	}
	for k, x in allocPart do
		allocPayload[k] = x
	end
	local payload: { [string]: any } = {
		kind = "multi",
		title = Content.stages.pricing.title,
		prompt = Content.narrative.pricing,
		hints = Common.hints(ctx, Content.pricingHints),
		sections = {
			{
				kind = "fill",
				title = Content.sections.bookFill,
				prompt = fill(if showOrders then Content.prompts.bookFillOrders else Content.prompts.bookFill, v),
				table = {
					columns = if showOrders then Content.bookColumnsOrders else Content.bookColumns,
					rows = rows,
				},
				fields = { clearField, offerField },
			} :: any,
			allocPayload,
		},
	}
	local secret = {
		kind = "multi",
		sections = {
			{
				kind = "fill",
				fields = { clearing = clearSecret, offer = offerSecret },
				fieldOrder = { "clearing", "offer" },
			} :: any,
			allocSecret,
		},
		weights = { 1.2, 1 },
	}
	return payload, secret, { clearing = clearing, ideal = ideal }
end

local function applyPricing(state: State, graded: Grade.Result, answers: any, meta: { [string]: any }, _ctx: Ctx): string?
	local f = state.facts
	f.priced = true
	f.clearing = math.max(0.5, Common.num(meta.clearing, f.perShare))
	f.ideal = Common.num(meta.ideal, f.clearing / (1 + IDEAL_MID))
	local given = Grade.number(section(answers, 1).offer)
	-- no price entered: the syndicate desk prices at the middle of the filed range
	local offer = if given and given > 0 then given else (f.valueLo + f.valueHi) / 2
	f.offer = cents(Common.clamp(offer, f.clearing * 0.25, f.clearing * 4))
	local allocSection = graded.sections[2]
	f.allocScore = if allocSection then Common.clamp(allocSection.score, 0, 100) else 0
	return fill(Content.pricingDebrief, { offer = dollars(f.offer) })
end

---------------------------------------------------------------------------------------------------
-- Outcome
---------------------------------------------------------------------------------------------------
local function popScore(pop: number): number
	if pop < -0.02 then
		return Common.clamp(40 + pop * 400, 0, 40)
	elseif pop < IDEAL_LO then
		return 50 + 40 * (pop + 0.02) / (IDEAL_LO + 0.02)
	elseif pop <= IDEAL_HI then
		return 100
	elseif pop <= 0.6 then
		return 100 - 80 * (pop - IDEAL_HI) / (0.6 - IDEAL_HI)
	end
	return 15
end

local function finish(state: State, _ctx: Ctx): Machine.Outcome
	local f = state.facts
	local O = Content.outcome
	local F = O.figures
	local offer = math.max(0.01, f.offer)
	local clearing = f.clearing
	local lines: { string } = {}
	if f.pickedKind ~= "ready" and Content.flaws[f.pickedKind] then
		table.insert(lines, Content.flaws[f.pickedKind])
	end
	table.insert(lines, if Common.num(f.roadshowScore, 0) >= 70 then O.roadshowGood else O.roadshowWeak)

	if offer > clearing * 1.02 then
		local v = with(vars(f), { offer = dollars(offer), clearing = dollars(clearing) })
		table.insert(lines, 1, fill(O.pulledLine, v))
		return {
			closed = false,
			score = Common.clamp(20 - (offer / clearing - 1.02) * 200, 0, 20),
			headline = fill(O.pulled, v),
			lines = lines,
			figures = {
				{ label = F.offer, value = "$" .. dollars(offer), tone = "bad" },
				{ label = F.pop, value = "—" },
				{ label = F.raised, value = "—" },
			},
			dealName = fill(O.dealNamePulled, v),
			data = { pop = 0, offer = offer, clearing = clearing, trade = 0, pulled = true },
		}
	end

	local trade = cents(clearing * (0.9 + 0.1 * Common.clamp(f.allocScore, 0, 100) / 100))
	local pop = trade / offer - 1
	local raised = offer * f.sold
	local left = math.max(0, (trade - offer) * f.sold)
	local v = with(vars(f), {
		offer = dollars(offer),
		trade = dollars(trade),
		pop = pctText(pop),
		popWord = if pop >= 0 then O.up else O.down,
		left = compact(math.floor(left + 0.5)),
		raised = compact(math.floor(raised + 0.5)),
	})
	local headline: string
	if pop < -0.02 then
		headline = fill(O.broke, v)
		table.insert(lines, 1, O.brokeLine)
	elseif pop < IDEAL_LO then
		headline = fill(O.quiet, v)
		table.insert(lines, 1, O.quietLine)
	elseif pop <= IDEAL_HI then
		headline = fill(O.ideal, v)
		table.insert(lines, 1, O.idealLine)
	else
		headline = fill(O.table, v)
		table.insert(lines, 1, O.tableLine)
	end
	table.insert(lines, if f.allocScore >= 70 then O.allocGood else O.allocBad)
	local figures: { Machine.Figure } = {
		{ label = F.offer, value = "$" .. dollars(offer) },
		{ label = F.close, value = "$" .. dollars(trade) },
		{
			label = F.pop,
			value = (if pop >= 0 then "+" else "−") .. pctText(pop),
			tone = if pop >= IDEAL_LO and pop <= IDEAL_HI then "good" elseif pop < 0 or pop > 0.4 then "bad" else "warn",
		},
		{ label = F.raised, value = compact(math.floor(raised + 0.5)) },
		if pop > IDEAL_HI
			then { label = F.left, value = compact(math.floor(left + 0.5)), tone = "bad" }
			else { label = F.marketCap, value = compact(math.floor(trade * f.shares + 0.5)) },
		{ label = F.fees, value = Common.money(raised * FEE, "M", 1) },
	}
	return {
		closed = true,
		score = popScore(pop),
		headline = headline,
		lines = lines,
		figures = figures,
		dealName = fill(O.dealName, v),
		data = {
			pop = math.floor(pop * 1000 + 0.5) / 1000,
			offer = offer,
			clearing = clearing,
			trade = trade,
			raised = math.floor(raised + 0.5),
			pulled = false,
		},
	}
end

---------------------------------------------------------------------------------------------------
-- Running summary (never reveals an answer)
---------------------------------------------------------------------------------------------------
local function dealName(state: State): string
	local f = state.facts
	local O = Content.outcome
	if f.company == "" then
		return fill(O.dealNameMandate, { codename = f.codename })
	end
	return fill(O.dealNameRunning, { codename = f.codename, company = f.company })
end

local function summary(state: State, ctx: Ctx): Machine.Summary
	local f = state.facts
	local M = Content.metrics
	local text: string
	if state.done and state.outcome then
		text = state.outcome.headline
	else
		local current = state.current
		local id = if current then current.id else "pick"
		local template = (Content.narrative :: any)[id]
		text = if type(template) == "string" then fill(template, vars(f)) else ""
	end
	local mood = Common.num(ctx.marketMood, 1)
	local metrics: { Machine.Metric } = {
		{ id = "client", label = M.client, value = if f.company ~= "" then f.company else M.pending },
		{
			id = "value",
			label = M.value,
			value = if f.valued then "$" .. dollars(f.perShare) else M.pending,
		},
		{
			id = "range",
			label = M.range,
			value = if f.valued then "$" .. dollars(f.valueLo) .. "–$" .. dollars(f.valueHi) else M.pending,
		},
	}
	if Common.num(f.roadshowScore, -1) >= 0 then
		local h = hype(f)
		table.insert(metrics, {
			id = "demand",
			label = M.demand,
			value = if h >= 1.12 then M.hot elseif h >= 0.98 then M.healthy else M.lukewarm,
			tone = if h >= 1.12 then "good" elseif h >= 0.98 then nil else "warn",
		})
	else
		table.insert(metrics, { id = "demand", label = M.demand, value = M.pending })
	end
	table.insert(metrics, {
		id = "market",
		label = M.market,
		value = if mood >= 1.05 then M.riskOn elseif mood <= 0.95 then M.riskOff else M.steady,
		tone = if mood >= 1.05 then "good" elseif mood <= 0.95 then "warn" else nil,
	})
	table.insert(metrics, {
		id = "offer",
		label = M.offer,
		value = if f.priced then "$" .. dollars(f.offer) else M.pending,
	})
	return { text = text, metrics = metrics }
end

---------------------------------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------------------------------
local S = Content.stages

local ipo = Machine.build({
	id = "ipo",
	title = Content.title,
	desc = Content.desc,
	glyph = "🔔",
	track = "ib",
	ranks = { 3, 4, 5 },
	signature = true,
	version = 1,
	stats = { "knowledge", "skill", "charisma" },
	clientFacing = true,
	baseXp = 380,
	basePay = 2600,
	cooldown = 900,
	payModifier = "ipoMult", -- EventService modifier: IPO Frenzy pays IPO work x2 (design v3 §10)
	outcomeWeight = 0.3,
	stages = {
		{ id = "pick", title = S.pick.title, brief = S.pick.brief, kind = "mcq", build = buildPick, apply = applyPick },
		{
			id = "valuation",
			title = S.valuation.title,
			brief = S.valuation.brief,
			kind = "fill",
			weight = 1.2,
			build = buildValuation,
			apply = applyValuation,
		},
		{
			id = "pitchbook",
			title = S.pitchbook.title,
			brief = S.pitchbook.brief,
			kind = "format",
			build = buildPitchbook,
			apply = applyPitchbook,
		},
		{
			id = "roadshow",
			title = S.roadshow.title,
			brief = S.roadshow.brief,
			kind = "dialogue",
			build = buildRoadshow,
			apply = applyRoadshow,
		},
		{
			id = "pricing",
			title = S.pricing.title,
			brief = S.pricing.brief,
			kind = "multi",
			weight = 1.2,
			build = buildPricing,
			apply = applyPricing,
		},
	},
	init = init,
	dealName = dealName,
	summary = summary,
	finish = finish,
})

ipo.popScore = popScore

return ipo
