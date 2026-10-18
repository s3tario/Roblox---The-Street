--!strict
-- ib_sellside (owned by `projects`; contracts §9): the Investment Banking big deal for Analysts and Associates
-- (ranks 1-2). Run the sale of a founder-owned private company from the teaser to the signed contract. PURE: no
-- services, no clocks, no Instances. Built on the shared stage Machine (_registry/Machine); every line of text lives
-- in Content.luau; the stage builders live in Stages.luau.
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
local Universe = require(script.Parent.Parent.Tasks._shared.Universe)
local Machine = require(script.Parent._registry.Machine)
local DealKit = require(script.Parent._registry.DealKit)
local Content = require(script.Content)
local Stages = require(script.Stages)

type Facts = { [string]: any }
type State = Machine.State
type Ctx = Machine.Ctx

local fill = Common.fill
local round5 = DealKit.round5
local compact = DealKit.compact
local pctText = DealKit.pctText
local with = DealKit.with
local vars = Stages.vars
local bidOf = Stages.bidOf
local winnerVars = Stages.winnerVars

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
	local strategicName = peers[1] or Universe.company(rng, sectorId).name
	local addonTarget = peers[2] or Universe.company(rng, sectorId).name
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
			stats = { "knowledge", "network" },
			build = Stages.teaser.build,
			apply = Stages.teaser.apply,
		},
		{
			id = "cim",
			title = S.cim.title,
			brief = S.cim.brief,
			kind = "format",
			stats = { "discipline", "skill" },
			build = Stages.cim.build,
			apply = Stages.cim.apply,
		},
		{
			id = "management",
			title = S.management.title,
			brief = S.management.brief,
			kind = "dialogue",
			stats = { "charisma", "knowledge" },
			build = Stages.management.build,
			apply = Stages.management.apply,
		},
		{
			id = "bids",
			title = S.bids.title,
			brief = S.bids.brief,
			kind = "multi",
			weight = 1.2,
			stats = { "skill", "risk" },
			build = Stages.bids.build,
			apply = Stages.bids.apply,
		},
		{
			id = "negotiation",
			title = S.negotiation.title,
			brief = S.negotiation.brief,
			kind = "dialogue",
			stats = { "charisma", "risk" },
			build = Stages.negotiation.build,
			apply = Stages.negotiation.apply,
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
