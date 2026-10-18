--!strict
-- ib_sellside (owned by `projects`; contracts §9): the Investment Banking big deal for Analysts and Associates
-- (ranks 1-2). Run the sale of a founder-owned private company from the teaser to the signed contract. PURE: no
-- services, no clocks, no Instances. Built on the shared stage Machine (_registry/Machine); every line of text lives
-- in Content.luau.
--
-- Stages (each a contracts §8 work payload, drawn by UI/WorkKinds):
--   1 teaser       multi: teaser/process mcq + buyer long list (match)  -> how many buyers sign NDAs
--   2 cim          format: flag every error on the CIM page            -> buyer confidence
--   3 management   dialogue: coach the CEO through the buyer's Q&A      -> buyer confidence
--   4 bids         multi: LOI maths (fill) + pick the lead and backup (mcq) -> who leads, whether a backup stays warm
--   5 negotiation  dialogue: the final round with the lead bidder        -> price uplift (-6% .. +8%)
-- Outcome: the final price against the board's reserve. A clean, competitive process closes well above it; a sloppy
-- one closes below it (the board takes the certainty) or falls apart. Picking a bidder who can't close is punished
-- in the outcome: the uncommitted fund re-trades the price (unless a backup was kept warm) and the stock offer
-- loses value as its shares slide.
--
--   ib_sellside.new / view / act / score       (Machine.build; contracts §9)
--   ib_sellside.facts(state) -> facts          (tests and the results story)

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Hash = require(script.Parent.Parent.Parent.Util.Hash)
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

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
local function round5(x: number): number
	return math.max(5, math.floor(x / 5 + 0.5) * 5)
end

-- "$640M" below a billion, "$1.2B" above (deal names and headlines).
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

local function lower(s: string): string
	return string.lower(s)
end

local function count(ctx: Ctx, easy: number, medium: number, hard: number): number
	local tier = Common.tier(ctx)
	return if tier == 1 then easy elseif tier == 2 then medium else hard
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

local function with(base: { [string]: any }, extra: { [string]: any }): { [string]: any }
	local out = table.clone(base)
	for k, v in extra do
		out[k] = v
	end
	return out
end

local function band(score: number): string
	return if score >= 85 then "great" elseif score >= 60 then "good" else "weak"
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

-- A section's answers inside a multi submission ({[i] = answers}, or string keys after a JSON round trip).
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

---------------------------------------------------------------------------------------------------
-- The scenario
---------------------------------------------------------------------------------------------------
local function init(rng: Rng.Rng, ctx: Ctx): Facts
	local sectorId = rng:pick(Content.sectors)
	local co = Universe.company(rng, sectorId)
	local sector = Universe.sector(sectorId)
	local adjacentPool: { string } = {}
	for _, id in Content.adjacent do
		if id ~= sectorId then
			table.insert(adjacentPool, id)
		end
	end
	local adjacentId = rng:pick(adjacentPool)
	local adjacent = Universe.sector(adjacentId)

	-- financials ($M): a founder-owned business worth a few hundred million to a few billion
	local rev = Common.round(rng:range(140, 820), 5)
	local margin = math.floor(rng:range(sector.margin[1], sector.margin[2]) * 100 + 0.5)
	local ebitda = math.max(10, math.floor(rev * margin / 100 + 0.5))
	margin = math.floor(ebitda / rev * 100 + 0.5) -- the shown margin always ties to the shown numbers
	local growth = math.max(3, math.floor(rng:range(sector.growth[1], sector.growth[2]) * 100 + 0.5) + rng:int(1, 4))
	local prevRev = math.floor(rev / (1 + growth / 100) + 0.5)
	growth = math.floor((rev / prevRev - 1) * 100 + 0.5)
	local multiple = Common.round(rng:range(sector.evEbitda[1], sector.evEbitda[2]), 0.5)
	local fairEv = round5(ebitda * multiple)
	local reserve = round5(fairEv * rng:range(0.96, 0.99))
	local addback = math.max(2, math.floor(ebitda * rng:range(0.05, 0.09) + 0.5))
	local planUp = rng:int(18, 32)
	local projEbitda = math.floor(ebitda * (1 + planUp / 100) + 0.5)
	local year = Common.year(ctx)

	-- the long list
	local lastNames = rng:shuffle({
		"Whitcombe",
		"Okoro",
		"Lindqvist",
		"Castellano",
		"Brandt",
		"Mercer",
		"Halloway",
		"Nakamura",
		"Delacroix",
		"Fairbanks",
		"Osei",
		"Ramsay",
		"Thornbury",
		"Vasquez",
	})
	local peers = Universe.peers(rng, sectorId, 2, { co.name })
	local strategicName = peers[1] or (Universe.company(rng, sectorId).name)
	local addonTarget = peers[2] or (Universe.company(rng, sectorId).name)
	local adjacentName = Universe.company(rng, adjacentId).name
	if adjacentName == co.name or adjacentName == strategicName then
		adjacentName = adjacentName .. " Group"
	end
	local longList = {
		{ angle = "strategic", name = strategicName },
		{ angle = "addon", name = lastNames[1] .. " " .. rng:pick(Content.fundSuffixes) },
		{ angle = "platform", name = lastNames[2] .. " " .. rng:pick(Content.fundSuffixes) },
		{ angle = "adjacent", name = adjacentName },
		{ angle = "family", name = lastNames[3] .. " " .. rng:pick(Content.familySuffixes) },
	}
	if longList[2].name == longList[3].name then
		longList[3].name = lastNames[4] .. " " .. Content.fundSuffixes[1]
	end

	local customer = Universe.company(rng, rng:pick(Universe.sectorIds)).name
	if customer == co.name then
		customer = customer .. " Group"
	end
	local firm = ctx.companyName or Universe.firm(rng)
	local badMargin = margin + rng:pick({ -4, -3, 3, 4, 5 })
	local badGrowth = growth + rng:pick({ 4, 5, 6, 8 })

	return {
		company = co.name,
		sector = sectorId,
		sectorName = co.sectorName,
		adjacentSector = adjacentId,
		adjacentSectorName = adjacent.name,
		founder = Universe.person(rng),
		codename = Universe.codename(rng),
		firm = firm,
		rev = rev,
		prevRev = prevRev,
		growth = growth,
		badGrowth = badGrowth,
		margin = margin,
		badMargin = badMargin,
		ebitda = ebitda,
		reported = ebitda - addback,
		addback = addback,
		netDebt = round5(ebitda * rng:range(1.2, 2.4)),
		multiple = multiple,
		fairEv = fairEv,
		reserve = reserve,
		projEbitda = projEbitda,
		bigEbitda = math.floor(projEbitda * 1.6 + 0.5),
		planUp = planUp,
		top10 = rng:int(32, 48),
		top1 = rng:int(9, 16),
		customer = customer,
		market = rng:int(3, 7),
		month = Universe.month(rng),
		year = year,
		oldYear = year - 2,
		year2 = year + 2,
		year3 = year + 3,
		addonTarget = addonTarget,
		fundSize = rng:int(4, 12),
		longList = longList,
		-- process state (filled in as stages finish)
		buyersIn = 0,
		confidence = 1,
		confidenceSeen = false,
		bids = {},
		winner = "",
		backupWarm = false,
		uplift = 0,
	}
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

local function applyTeaser(state: State, graded: Grade.Result, _answers: any, _meta: { [string]: any }, _ctx: Ctx): string?
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
local function dialogueSpecs(rng: Rng.Rng, lines: { any }, n: number, v: { [string]: any }): { Build.DialogueSpec }
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

local function buildManagement(state: State, rng: Rng.Rng, ctx: Ctx)
	local f = state.facts
	local strategic = buyerOf(f, "strategic")
	local v = with(vars(f), {
		person = Universe.person(rng),
		buyer = if strategic then strategic.name else f.company,
	})
	local speaker = fill(Content.managementSpeaker, v)
	local lines, secret = Build.dialogue(rng, dialogueSpecs(rng, Content.managementLines, count(ctx, 4, 5, 6), v))
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
	return payload,
		secret,
		{ bids = bids, leadKinds = leadKinds, backupKey = mcqSecret.key.q_backup }
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
	local lines, secret = Build.dialogue(rng, dialogueSpecs(rng, Content.negotiationLines, count(ctx, 4, 5, 6), v))
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

---------------------------------------------------------------------------------------------------
-- Outcome
---------------------------------------------------------------------------------------------------
local function outcomeScore(ratio: number, closed: boolean): number
	if not closed then
		return Common.clamp((ratio - 0.8) / 0.15 * 30, 0, 30)
	end
	return Common.clamp(40 + (ratio - 0.95) / 0.25 * 60, 40, 100)
end

local function finish(state: State, _ctx: Ctx): Machine.Outcome
	local f = state.facts
	local O = Content.outcome
	local bid = bidOf(f, f.winner) or bidOf(f, "clean") or { kind = "clean", name = f.company, ev = f.fairEv }
	local rng = Rng.new(Hash.u32("ib_sellside_outcome", state.seed))
	local lines: { string } = {}
	local buyerName = bid.name
	local price = bid.ev
	if bid.kind == "trap" then
		if f.backupWarm then
			local backup = bidOf(f, "clean") or bid
			price = backup.ev * 0.98
			buyerName = backup.name
			table.insert(lines, fill(O.retradePivot, { winner = bid.name, buyer = backup.name }))
		else
			local cut = rng:int(12, 18)
			price = bid.ev * (1 - cut / 100)
			table.insert(lines, fill(O.retradeCut, { winner = bid.name, cut = cut }))
		end
	elseif bid.kind == "stock" then
		local cut = rng:int(9, 14)
		price = bid.ev * (1 - cut / 100)
		table.insert(lines, fill(O.stockSlide, { winner = bid.name, cut = cut }))
	elseif bid.kind == "family" then
		table.insert(lines, fill(O.familyLow, { winner = bid.name }))
	end
	local uplift = Common.num(f.uplift, 0)
	price = round5(price * (1 + uplift))
	local ratio = price / f.reserve
	local closed = ratio >= 0.95
	local priceText = compact(price)
	local reserveText = compact(f.reserve)
	local v = with(vars(f), { buyer = buyerName, price = priceText, reserve = reserveText })

	if closed then
		if ratio >= 1 then
			table.insert(lines, 1, fill(O.above, with(v, { pct = pctText(ratio - 1) })))
		else
			table.insert(lines, 1, fill(O.below, with(v, { pct = pctText(1 - ratio) })))
		end
	else
		table.insert(lines, 1, fill(O.short, with(v, { pct = pctText(1 - ratio) })))
	end
	table.insert(lines, fill(if f.buyersIn >= 7 then O.competition else O.thin, v))
	if math.abs(uplift) >= 0.005 then
		table.insert(lines, fill(if uplift > 0 then O.negotiationUp else O.negotiationDown, { pct = pctText(uplift) }))
	end

	local fee = if closed then price * 0.0125 else 0
	local figures: { Machine.Figure } = {
		{ label = O.figures.price, value = priceText, tone = if closed then "good" else "bad" },
		{
			label = O.figures.reserve,
			value = (if ratio >= 1 then "+" else "−") .. pctText(ratio - 1),
			tone = if ratio >= 1.05 then "good" elseif ratio >= 0.97 then "warn" else "bad",
		},
		{ label = O.figures.multiple, value = Common.mult(price / f.ebitda) },
		{ label = O.figures.buyers, value = tostring(f.buyersIn) },
		{ label = O.figures.fee, value = if closed then Common.money(fee, "M", 1) else "—" },
	}
	return {
		closed = closed,
		score = outcomeScore(ratio, closed),
		headline = fill(if closed then O.closedHeadline else O.pulledHeadline, v),
		lines = lines,
		figures = figures,
		dealName = fill(if closed then O.dealName else O.dealNamePulled, v),
		data = {
			price = price,
			reserve = f.reserve,
			ratio = math.floor(ratio * 1000 + 0.5) / 1000,
			buyer = buyerName,
			winner = bid.kind,
		},
	}
end

---------------------------------------------------------------------------------------------------
-- Running summary (never reveals an answer)
---------------------------------------------------------------------------------------------------
local function dealName(state: State): string
	local f = state.facts
	return fill(Content.outcome.dealNameRunning, { codename = f.codename, company = f.company })
end

local function summary(state: State, _ctx: Ctx): Machine.Summary
	local f = state.facts
	local M = Content.metrics
	local v = winnerVars(f)
	local text: string
	if state.done and state.outcome then
		text = state.outcome.headline
	else
		local current = state.current
		local id = if current then current.id else "teaser"
		local template = (Content.narrative :: any)[id]
		text = if type(template) == "string" then fill(template, v) else ""
	end
	local confidence = f.confidence
	local confText = if not f.confidenceSeen
		then M.pending
		elseif confidence >= 1.02 then M.high
		elseif confidence >= 0.98 then M.steady
		else M.cautious
	local lead = bidOf(f, f.winner)
	return {
		text = text,
		metrics = {
			{ id = "client", label = M.client, value = f.company },
			{ id = "ebitda", label = M.ebitda, value = Common.money(f.ebitda) },
			{ id = "reserve", label = M.reserve, value = Common.money(f.reserve) },
			{
				id = "buyers",
				label = M.buyers,
				value = if f.buyersIn > 0 then tostring(f.buyersIn) else M.pending,
				tone = if f.buyersIn >= 7 then "good" elseif f.buyersIn > 0 then "warn" else nil,
			},
			{
				id = "confidence",
				label = M.confidence,
				value = confText,
				tone = if not f.confidenceSeen
					then nil
					elseif confidence >= 1.02 then "good"
					elseif confidence >= 0.98 then nil
					else "warn",
			},
			{ id = "lead", label = M.lead, value = if lead then lead.name else M.pending },
		},
	}
end

---------------------------------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------------------------------
local S = Content.stages

local ib_sellside = Machine.build({
	id = "ib_sellside",
	title = Content.title,
	desc = Content.desc,
	glyph = "🤝",
	track = "ib",
	ranks = { 1, 2 },
	signature = false,
	version = 1,
	stats = { "knowledge", "charisma", "skill" },
	clientFacing = true,
	baseXp = 340,
	basePay = 2200,
	cooldown = 600,
	outcomeWeight = 0.25,
	stages = {
		{
			id = "teaser",
			title = S.teaser.title,
			brief = S.teaser.brief,
			kind = "multi",
			build = buildTeaser,
			apply = applyTeaser,
		},
		{ id = "cim", title = S.cim.title, brief = S.cim.brief, kind = "format", build = buildCim, apply = applyCim },
		{
			id = "management",
			title = S.management.title,
			brief = S.management.brief,
			kind = "dialogue",
			build = buildManagement,
			apply = applyManagement,
		},
		{
			id = "bids",
			title = S.bids.title,
			brief = S.bids.brief,
			kind = "multi",
			weight = 1.2,
			build = buildBids,
			apply = applyBids,
		},
		{
			id = "negotiation",
			title = S.negotiation.title,
			brief = S.negotiation.brief,
			kind = "dialogue",
			build = buildNegotiation,
			apply = applyNegotiation,
		},
	},
	init = init,
	dealName = dealName,
	summary = summary,
	finish = finish,
})

function ib_sellside.facts(state: any): { [string]: any }?
	return if type(state) == "table" and type(state.facts) == "table" then state.facts else nil
end

return ib_sellside
