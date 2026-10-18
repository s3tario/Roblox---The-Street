--!strict
-- ib_sellside/Stages (owned by `projects`): the five stages of the sell-side process (see init.luau for the deal)
-- and the deal helpers the outcome and summary share. PURE: no services, no clocks, no Instances. Every line of
-- text lives in Content.luau.
--
--   Stages.<stageId> = { build(state, rng, ctx) -> (payload, secret, meta?), apply(state, graded, answers, meta, ctx)
--                        -> debrief? }   for teaser, cim, management, bids, negotiation
--   Stages.vars(facts) -> { [string]: any }        every template variable of the deal, as display strings
--   Stages.bidOf(facts, kind) / Stages.buyerOf(facts, angle) / Stages.winnerVars(facts)

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
local count = DealKit.count
local band = DealKit.band
local with = DealKit.with
local section = DealKit.section

local Stages = {}

---------------------------------------------------------------------------------------------------
-- Deal helpers
---------------------------------------------------------------------------------------------------
local function lower(s: string): string
	return string.lower(s)
end

-- Every template variable of the deal, as display strings.
local function vars(f: Facts): { [string]: any }
	return {
		company = f.company,
		founder = f.founder,
		codename = f.codename,
		firm = f.firm,
		sector = f.sectorName,
		sectorLower = lower(f.sectorName),
		adjacentSector = lower(f.adjacentSectorName),
		rev = Common.commas(f.rev),
		prevRev = Common.commas(f.prevRev),
		growth = f.growth,
		badGrowth = f.badGrowth,
		margin = f.margin,
		badMargin = f.badMargin,
		ebitda = Common.commas(f.ebitda),
		reported = Common.commas(f.reported),
		addback = Common.commas(f.addback),
		netDebt = Common.commas(f.netDebt),
		reserve = Common.commas(f.reserve),
		projEbitda = Common.commas(f.projEbitda),
		bigEbitda = Common.commas(f.bigEbitda),
		planUp = f.planUp,
		top10 = f.top10,
		top1 = f.top1,
		customer = f.customer,
		market = f.market,
		month = f.month,
		year = f.year,
		oldYear = f.oldYear,
		year2 = f.year2,
		year3 = f.year3,
		addonTarget = f.addonTarget,
		fundSize = f.fundSize,
		buyers = if f.buyersIn > 0 then f.buyersIn else #f.longList,
	}
end

local function bidOf(f: Facts, kind: string): { [string]: any }?
	for _, b in f.bids do
		if b.kind == kind then
			return b
		end
	end
	return nil
end

local function buyerOf(f: Facts, angle: string): { [string]: any }?
	for _, b in f.longList do
		if b.angle == angle then
			return b
		end
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- Stage 1: teaser + buyer list
---------------------------------------------------------------------------------------------------
local function buildTeaser(state: State, rng: Rng.Rng, ctx: Ctx)
	local f = state.facts
	local v = vars(f)
	local specs: { Build.McqSpec } = {}
	local picks = Common.pickN(rng, Content.teaserQuestions, count(ctx, 2, 3, 3))
	for _, q in picks do
		local wrong: { string } = {}
		for _, w in q.wrong do
			table.insert(wrong, fill(w, v))
		end
		table.insert(specs, {
			id = q.id,
			text = fill(q.text, v),
			correct = fill(q.correct, v),
			wrong = wrong,
			explain = fill(q.explain, v),
		})
	end
	local questions, mcqSecret = Build.mcq(rng, specs)

	local angles = { "strategic", "addon", "platform", "adjacent", "family" }
	local n = count(ctx, 4, 5, 5)
	local pairs: { Build.MatchPair } = {}
	for i = 1, n do
		local angle = angles[i]
		local buyer = buyerOf(f, angle)
		if buyer then
			local bv = with(v, { name = buyer.name })
			table.insert(pairs, {
				left = fill(Content.buyerDesc[angle], bv),
				right = Content.angles[angle],
				note = fill(Content.matchNotes[angle], bv),
			})
		end
	end
	local extra: { string } = { Content.angleDecoy }
	if n < #angles then
		table.insert(extra, Content.angles[angles[#angles]])
	end
	local left, right, matchSecret = Build.match(rng, pairs, extra)

	local payload: { [string]: any } = {
		kind = "multi",
		title = Content.stages.teaser.title,
		prompt = fill(Content.prompts.teaser, v),
		hints = Common.hints(ctx, Content.teaserHints),
		sections = {
			{
				kind = "mcq",
				title = Content.sections.teaserMcq,
				prompt = Content.prompts.teaserMcq,
				questions = questions,
			} :: any,
			{
				kind = "match",
				title = Content.sections.teaserMatch,
				prompt = Content.prompts.teaserMatch,
				left = left,
				right = right,
			} :: any,
		},
	}
	local secret = { kind = "multi", sections = { mcqSecret, matchSecret }, weights = { 1, 1.4 } }
	return payload, secret, { buyers = n }
end

local function applyTeaser(
	state: State,
	graded: Grade.Result,
	_answers: any,
	_meta: { [string]: any },
	_ctx: Ctx
): string?
	local f = state.facts
	local q = graded.quality
	f.buyersIn = math.clamp(math.floor(3 + 9 * q / 100 + 0.5), 3, 12)
	return fill(Content.teaserDebrief[band(q)], vars(f))
end

---------------------------------------------------------------------------------------------------
-- Stage 2: the CIM
---------------------------------------------------------------------------------------------------
local function buildCim(state: State, rng: Rng.Rng, ctx: Ctx)
	local f = state.facts
	local v = vars(f)
	local elements = Content.cimElements
	local brokenCount = count(ctx, 3, 4, 5)
	local specs = DealKit.formatSpecs(rng, elements, brokenCount, v, { firm = f.firm, company = f.company })
	local shown, issues, secret = Build.format(rng, specs, Content.cimIssues)
	secret.summary = Content.cimSummary
	local payload = {
		kind = "format",
		title = Content.stages.cim.title,
		prompt = fill(Content.prompts.cim, v),
		hints = Common.hints(ctx, Content.cimHints),
		elements = shown,
		issues = issues,
	}
	return payload, secret, nil
end

local function confidenceShift(q: number): number
	-- 60 is neutral; a flawless stage lifts confidence 4%, a disaster cuts it 6%
	return math.clamp((q - 60) / 100 * 0.1, -0.06, 0.04)
end

local function applyCim(state: State, graded: Grade.Result, _answers: any, _meta: { [string]: any }, _ctx: Ctx): string?
	local f = state.facts
	f.confidence = Common.clamp(f.confidence + confidenceShift(graded.quality), 0.85, 1.1)
	f.confidenceSeen = true
	return fill(Content.cimDebrief[band(graded.quality)], vars(f))
end

---------------------------------------------------------------------------------------------------
-- Dialogue stages (management Q&A, final negotiation)
---------------------------------------------------------------------------------------------------
local function buildManagement(state: State, rng: Rng.Rng, ctx: Ctx)
	local f = state.facts
	local strategic = buyerOf(f, "strategic")
	local v = with(vars(f), {
		person = Universe.person(rng),
		buyer = if strategic then strategic.name else f.company,
	})
	local speaker = fill(Content.managementSpeaker, v)
	local lines, secret =
		Build.dialogue(rng, DealKit.dialogueSpecs(rng, Content.managementLines, count(ctx, 4, 5, 6), v))
	local payload = {
		kind = "dialogue",
		title = Content.stages.management.title,
		prompt = fill(Content.prompts.management, with(v, { speaker = speaker })),
		hints = Common.hints(ctx, Content.managementHints),
		speaker = speaker,
		lines = lines,
	}
	return payload, secret, nil
end

local function applyManagement(
	state: State,
	graded: Grade.Result,
	_answers: any,
	_meta: { [string]: any },
	_ctx: Ctx
): string?
	local f = state.facts
	f.confidence = Common.clamp(f.confidence + confidenceShift(graded.quality), 0.85, 1.1)
	f.confidenceSeen = true
	return fill(Content.managementDebrief[band(graded.quality)], vars(f))
end

---------------------------------------------------------------------------------------------------
-- Stage 4: the bid round
---------------------------------------------------------------------------------------------------
local BIDDERS = {
	{ kind = "clean", angle = "strategic", terms = "clean" },
	{ kind = "trap", angle = "platform", terms = "trap" },
	{ kind = "stock", angle = "adjacent", terms = "stock" },
	{ kind = "family", angle = "family", terms = "family" },
	{ kind = "addon", angle = "addon", terms = "addon" },
}

local function makeBids(f: Facts, rng: Rng.Rng, withAddon: boolean): { { [string]: any } }
	local competition = 0.94 + 0.08 * Common.clamp((f.buyersIn - 4) / 8, 0, 1)
	local clean = f.fairEv * f.confidence * competition * rng:range(1.02, 1.05)
	local evs: { [string]: number } = {
		clean = round5(clean),
		trap = round5(clean * rng:range(1.09, 1.13)),
		stock = round5(clean * rng:range(1.05, 1.08)),
		addon = round5(clean * rng:range(0.94, 0.97)),
		family = round5(clean * rng:range(0.86, 0.9)),
	}
	-- headline order is fixed (trap > stock > clean > addon > family) whatever the rounding did
	if evs.stock <= evs.clean then
		evs.stock = evs.clean + 5
	end
	if evs.trap <= evs.stock then
		evs.trap = evs.stock + 5
	end
	if evs.addon >= evs.clean then
		evs.addon = evs.clean - 5
	end
	if evs.family >= evs.addon then
		evs.family = evs.addon - 5
	end
	local out: { { [string]: any } } = {}
	for _, b in BIDDERS do
		if b.kind ~= "addon" or withAddon then
			local buyer = buyerOf(f, b.angle)
			local terms = Content.bidTerms[b.terms]
			table.insert(out, {
				kind = b.kind,
				name = if buyer then buyer.name else b.kind,
				ev = evs[b.kind],
				payment = terms.payment,
				conditions = terms.conditions,
			})
		end
	end
	return out
end

local function buildBids(state: State, rng: Rng.Rng, ctx: Ctx)
	local f = state.facts
	local bids = makeBids(f, rng, Common.tier(ctx) >= 3)
	local cleanBid = bids[1]
	local v = with(vars(f), { clean = cleanBid.name })

	-- the LOI table (shuffled so the answer isn't always on top)
	local rows: { { string } } = {}
	for _, b in rng:shuffle(bids) do
		table.insert(rows, { b.name, Common.money(b.ev), b.payment, b.conditions })
	end

	local fields: { any } = {}
	local fillSecret: { [string]: any } = {}
	local fieldOrder: { string } = {}
	local function add(id: string, label: string, value: number, opts: { [string]: any })
		local field, sec = Build.fillField(id, label, value, opts :: any)
		table.insert(fields, field)
		fillSecret[id] = sec
		table.insert(fieldOrder, id)
	end
	add("mult", fill(Content.bidFields.mult, v), cleanBid.ev / f.ebitda, {
		unit = "x",
		tol = 0.03,
		short = "EV / EBITDA",
		note = fill("{ev} ÷ {ebitda} = {mult}x.", {
			ev = Common.commas(cleanBid.ev),
			ebitda = Common.commas(f.ebitda),
			mult = Grade.show(cleanBid.ev / f.ebitda),
		}),
	})
	add("equity", fill(Content.bidFields.equity, v), cleanBid.ev - f.netDebt, {
		unit = "$M",
		tol = 0.02,
		short = "Equity value",
		note = fill("Equity value = {ev} − {debt} of net debt.", {
			ev = Common.money(cleanBid.ev),
			debt = Common.money(f.netDebt),
		}),
	})
	if Common.tier(ctx) >= 2 then
		local premium = (cleanBid.ev / f.reserve - 1) * 100
		add("premium", fill(Content.bidFields.premium, v), premium, {
			unit = "%",
			tol = 0.08,
			floor = 1,
			scales = { 1, 100 },
			short = "Premium to reserve",
		})
	end

	-- lead and backup
	local textToKind: { [string]: string } = {}
	local leadWrong: { string } = {}
	local leadCorrect = ""
	for _, b in bids do
		local text = fill(Content.leadOption, { name = b.name, ev = Common.commas(b.ev), payment = b.payment })
		textToKind[text] = b.kind
		if b.kind == "clean" then
			leadCorrect = text
		else
			table.insert(leadWrong, text)
		end
	end
	local questions, mcqSecret = Build.mcq(rng, {
		{
			id = "q_lead",
			text = Content.leadQuestion,
			correct = leadCorrect,
			wrong = leadWrong,
			explain = fill(Content.leadExplain, v),
		},
		{
			id = "q_backup",
			text = Content.backupQuestion,
			correct = Content.backupCorrect,
			wrong = Content.backupWrong,
			explain = Content.backupExplain,
		},
	}, { options = #bids })
	local leadKinds: { string } = {}
	for i, text in questions[1].options do
		leadKinds[i] = textToKind[text] or "trap"
	end

	local payload: { [string]: any } = {
		kind = "multi",
		title = Content.stages.bids.title,
		prompt = Content.narrative.bids,
		hints = Common.hints(ctx, Content.bidHints),
		sections = {
			{
				kind = "fill",
				title = Content.sections.bidsFill,
				prompt = fill(Content.prompts.bidsFill, v),
				table = { columns = Content.bidColumns, rows = rows },
				fields = fields,
			} :: any,
			{
				kind = "mcq",
				title = Content.sections.bidsMcq,
				prompt = Content.prompts.bidsMcq,
				questions = questions,
			} :: any,
		},
	}
	local secret = {
		kind = "multi",
		sections = { { kind = "fill", fields = fillSecret, fieldOrder = fieldOrder } :: any, mcqSecret },
		weights = { 1, 1.2 },
	}
	return payload, secret, { bids = bids, leadKinds = leadKinds, backupKey = mcqSecret.key.q_backup }
end

local function applyBids(state: State, _graded: Grade.Result, answers: any, meta: { [string]: any }, _ctx: Ctx): string?
	local f = state.facts
	f.bids = if type(meta.bids) == "table" then meta.bids else {}
	local mcq = section(answers, 2)
	local lead = Grade.number(mcq.q_lead)
	local kinds = if type(meta.leadKinds) == "table" then meta.leadKinds else {}
	-- no pick: the board goes with the biggest headline number
	local winner = if lead and kinds[lead] then kinds[lead] else "trap"
	if bidOf(f, winner) == nil then
		winner = "clean"
	end
	f.winner = winner
	local backup = Grade.number(mcq.q_backup)
	f.backupWarm = backup ~= nil and backup == meta.backupKey
	local bid = bidOf(f, winner)
	return fill(Content.bidDebrief, {
		winner = if bid then bid.name else "",
		ev = if bid then Common.commas(bid.ev) else "",
	})
end

---------------------------------------------------------------------------------------------------
-- Stage 5: final negotiation
---------------------------------------------------------------------------------------------------
local function winnerVars(f: Facts): { [string]: any }
	local bid = bidOf(f, f.winner) or f.bids[1]
	local ev = if bid then bid.ev else f.fairEv
	return with(vars(f), {
		winner = if bid then bid.name else f.company,
		bid = Common.commas(ev),
		ask = Common.commas(round5(ev * 1.06)),
	})
end

local function buildNegotiation(state: State, rng: Rng.Rng, ctx: Ctx)
	local f = state.facts
	local v = with(winnerVars(f), { person = Universe.person(rng) })
	local speaker = fill(Content.negotiationSpeaker, v)
	local lines, secret =
		Build.dialogue(rng, DealKit.dialogueSpecs(rng, Content.negotiationLines, count(ctx, 4, 5, 6), v))
	local payload = {
		kind = "dialogue",
		title = Content.stages.negotiation.title,
		prompt = fill(Content.prompts.negotiation, with(v, { speaker = speaker })),
		hints = Common.hints(ctx, Content.negotiationHints),
		speaker = speaker,
		lines = lines,
	}
	return payload, secret, nil
end

local function applyNegotiation(
	state: State,
	graded: Grade.Result,
	_answers: any,
	_meta: { [string]: any },
	_ctx: Ctx
): string?
	local f = state.facts
	f.uplift = -0.06 + 0.14 * Common.clamp(graded.quality, 0, 100) / 100
	return fill(Content.negotiationDebrief[band(graded.quality)], winnerVars(f))
end

Stages.vars = vars
Stages.bidOf = bidOf
Stages.buyerOf = buyerOf
Stages.winnerVars = winnerVars
Stages.teaser = { build = buildTeaser, apply = applyTeaser }
Stages.cim = { build = buildCim, apply = applyCim }
Stages.management = { build = buildManagement, apply = applyManagement }
Stages.bids = { build = buildBids, apply = applyBids }
Stages.negotiation = { build = buildNegotiation, apply = applyNegotiation }

return Stages
