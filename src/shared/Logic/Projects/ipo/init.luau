--!strict
-- ipo (owned by `projects`; contracts §9 signature deal "ipo", spec §7 "IB signature: take a company public"): the
-- Investment Banking signature deal for VPs and up (ranks >= 3). PURE: no services, no clocks, no Instances. Built on
-- the shared stage Machine (_registry/Machine); every line of text lives in Content.luau and the stage builders in
-- Stages.luau.
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
local Universe = require(script.Parent.Parent.Tasks._shared.Universe)
local Machine = require(script.Parent._registry.Machine)
local DealKit = require(script.Parent._registry.DealKit)
local Content = require(script.Content)
local Stages = require(script.Stages)

type Facts = { [string]: any }
type State = Machine.State
type Ctx = Machine.Ctx

local fill = Common.fill
local cents = DealKit.cents
local dollars = DealKit.dollars
local compact = DealKit.compact
local pctText = DealKit.pctText
local with = DealKit.with
local vars = Stages.vars
local hype = Stages.hype

local IDEAL_LO, IDEAL_HI = Stages.IDEAL_LO, Stages.IDEAL_HI
local FEE = Stages.FEE

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
		{
			id = "pick",
			title = S.pick.title,
			brief = S.pick.brief,
			kind = "mcq",
			stats = { "knowledge", "risk" },
			build = Stages.pick.build,
			apply = Stages.pick.apply,
		},
		{
			id = "valuation",
			title = S.valuation.title,
			brief = S.valuation.brief,
			kind = "fill",
			weight = 1.2,
			stats = { "skill", "knowledge" },
			build = Stages.valuation.build,
			apply = Stages.valuation.apply,
		},
		{
			id = "pitchbook",
			title = S.pitchbook.title,
			brief = S.pitchbook.brief,
			kind = "format",
			stats = { "discipline", "skill" },
			build = Stages.pitchbook.build,
			apply = Stages.pitchbook.apply,
		},
		{
			id = "roadshow",
			title = S.roadshow.title,
			brief = S.roadshow.brief,
			kind = "dialogue",
			stats = { "charisma", "network" },
			build = Stages.roadshow.build,
			apply = Stages.roadshow.apply,
		},
		{
			id = "pricing",
			title = S.pricing.title,
			brief = S.pricing.brief,
			kind = "multi",
			weight = 1.2,
			stats = { "skill", "risk" },
			build = Stages.pricing.build,
			apply = Stages.pricing.apply,
		},
	},
	init = init,
	dealName = dealName,
	summary = summary,
	finish = finish,
})

ipo.popScore = popScore

return ipo
