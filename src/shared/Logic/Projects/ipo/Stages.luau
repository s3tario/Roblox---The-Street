--!strict
-- ipo/Stages (owned by `projects`): the five stages of taking a company public (see init.luau for the deal) and the
-- deal helpers the outcome and summary share. PURE: no services, no clocks, no Instances. Every line of text lives
-- in Content.luau.
--
--   Stages.<stageId> = { build(state, rng, ctx) -> (payload, secret, meta?), apply(state, graded, answers, meta, ctx)
--                        -> debrief? }   for pick, valuation, pitchbook, roadshow, pricing
--   Stages.vars(facts) -> { [string]: any }    every template variable of the deal, as display strings
--   Stages.hype(facts) -> number               how hot the order book is (the client, the work so far, the market)
--   Stages.IDEAL_LO / IDEAL_HI / IDEAL_MID / FLOAT / FEE / FLAWED_APPETITE

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent.Parent.Parent.Tasks._shared.Common)
local Build = require(script.Parent.Parent.Parent.Tasks._shared.Build)
local Universe = require(script.Parent.Parent.Parent.Tasks._shared.Universe)
local Grade = require(script.Parent.Parent.Parent.Tasks._shared.Grade)
local Machine = require(script.Parent.Parent._registry.Machine)
local DealKit = require(script.Parent.Parent._registry.DealKit)
local Content = require(script.Parent.Content)

type Facts = { [string]: any }
type State = Machine.State
type Ctx = Machine.Ctx

local fill = Common.fill
local round5 = DealKit.round5
local halfDollar = DealKit.halfDollar
local cents = DealKit.cents
local dollars = DealKit.dollars
local count = DealKit.count
local band = DealKit.band
local with = DealKit.with
local section = DealKit.section

local Stages = {}

local IDEAL_LO, IDEAL_HI = 0.10, 0.25
local IDEAL_MID = 0.175
local FLOAT = 0.2
local FEE = 0.05 -- the underwriters' gross spread
local FLAWED_APPETITE = 0.84

---------------------------------------------------------------------------------------------------
-- Deal helpers
---------------------------------------------------------------------------------------------------
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
-- Stage 1: choose the client
---------------------------------------------------------------------------------------------------
local function buildPick(
	state: State,
	rng: Rng.Rng,
	ctx: Ctx
): ({ [string]: any }, { [string]: any }, { [string]: any }?)
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
local function buildValuation(
	state: State,
	rng: Rng.Rng,
	ctx: Ctx
): ({ [string]: any }, { [string]: any }, { [string]: any }?)
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
local function buildPitchbook(
	state: State,
	rng: Rng.Rng,
	ctx: Ctx
): ({ [string]: any }, { [string]: any }, { [string]: any }?)
	local f = state.facts
	local v = vars(f)
	local elements = Content.elements
	local brokenCount = count(ctx, 3, 4, 5)
	local specs = DealKit.formatSpecs(rng, elements, brokenCount, v, { firm = f.firm, company = f.company })
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
local function buildRoadshow(
	state: State,
	rng: Rng.Rng,
	ctx: Ctx
): ({ [string]: any }, { [string]: any }, { [string]: any }?)
	local f = state.facts
	local v = with(vars(f), { person = Universe.person(rng), fund = rng:pick(Content.fundNames) })
	local speaker = fill(Content.roadshowSpeaker, v)
	local specs = DealKit.dialogueSpecs(rng, Content.roadshowLines, count(ctx, 4, 5, 6), v)
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

local function applyRoadshow(
	state: State,
	graded: Grade.Result,
	_answers: any,
	_meta: { [string]: any },
	ctx: Ctx
): string?
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

local function buildPricing(
	state: State,
	_rng: Rng.Rng,
	ctx: Ctx
): ({ [string]: any }, { [string]: any }, { [string]: any }?)
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
				if showOrders then string.format("%.1f", coverage * f.sold) else string.format("%.1fx", coverage),
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

local function applyPricing(
	state: State,
	graded: Grade.Result,
	answers: any,
	meta: { [string]: any },
	_ctx: Ctx
): string?
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

Stages.IDEAL_LO = IDEAL_LO
Stages.IDEAL_HI = IDEAL_HI
Stages.IDEAL_MID = IDEAL_MID
Stages.FLOAT = FLOAT
Stages.FEE = FEE
Stages.FLAWED_APPETITE = FLAWED_APPETITE
Stages.vars = vars
Stages.hype = hype
Stages.pick = { build = buildPick, apply = applyPick }
Stages.valuation = { build = buildValuation, apply = applyValuation }
Stages.pitchbook = { build = buildPitchbook, apply = applyPitchbook }
Stages.roadshow = { build = buildRoadshow, apply = applyRoadshow }
Stages.pricing = { build = buildPricing, apply = applyPricing }

return Stages
