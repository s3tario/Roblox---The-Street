--!strict
-- Earnings and sector catalysts (owned by `market`; spec §7). PURE, driven by Logic/Market/Model.
--
-- Every company reports every Tickers.EARNINGS_EVERY market days after the close, staggered by earningsOffset.
-- The consensus is published Tickers.CONSENSUS_LEAD days ahead; the surprise is drawn from the server seed when the
-- report is scheduled and stays hidden (research reads it through an honest, noisy signal). A release gaps the price
-- (and the fair value) by the surprise times a per-report sensitivity, refreshes the trailing fundamentals and
-- schedules the next report. Sector catalysts are announced a day ahead with stated odds and resolve one minute
-- into the session.
--
--   Earnings.naturalDay(def, fromDay) -> day        the next report day on or after fromDay
--   Earnings.schedule(state, ts, fromDay)           Earnings.publishConsensus(state, ts, at)
--   Earnings.release(state, ts, day, at)            Earnings.lastQuarter(ts) -> number
--   Earnings.catalystVars(c) -> vars                Earnings.scheduleCatalyst(state, day, at)
--   Earnings.resolveCatalyst(state, c, at)

local Types = require(script.Parent.Types)
local Core = require(script.Parent.Core)
local Events = require(script.Parent.Events)
local NewsText = require(script.Parent.News)
local Tickers = require(script.Parent.Parent.Parent.Config.Tickers)
local Hash = require(script.Parent.Parent.Parent.Util.Hash)

type State = Types.State
type TickerState = Types.TickerState

local Earnings = {}

local round2 = Core.round2
local clamp = Core.clamp

function Earnings.lastQuarter(ts: TickerState): number
	return ts.quarters[#ts.quarters] or (ts.eps / 4)
end

function Earnings.naturalDay(def: Tickers.TickerDef, fromDay: number): number
	local every = Tickers.EARNINGS_EVERY
	local r = (fromDay - def.earningsOffset) % every
	return if r == 0 then fromDay else fromDay + (every - r)
end

function Earnings.schedule(state: State, ts: TickerState, fromDay: number)
	local def = ts.def
	local e = Earnings.naturalDay(def, fromDay)
	local growth = def.growth + state.rng:normal(0, 0.006)
	local surprise =
		clamp(Hash.normal(state.seed, "surprise", def.id, e) * Core.SURPRISE_SD + Core.SURPRISE_BIAS, -0.25, 0.25)
	ts.next = {
		day = e,
		natural = e,
		consensus = round2(Earnings.lastQuarter(ts) * (1 + growth)),
		published = e - state.day <= Tickers.CONSENSUS_LEAD,
		surprise = surprise,
		mult = 2.2 + 0.8 * Hash.unit(state.seed, "sens", def.id, e),
		frenzy = false,
	}
end

function Earnings.publishConsensus(state: State, ts: TickerState, at: number)
	local e = ts.next
	e.published = true
	local days = math.max(0, e.day - state.day)
	Core.addNews(
		state,
		"consensus",
		NewsText.pick("consensus", {
			name = ts.def.name,
			ticker = ts.id,
			days = days,
			cons = NewsText.money(e.consensus),
		}, state.rng),
		"info",
		at,
		{ ticker = ts.id }
	)
end

function Earnings.release(state: State, ts: TickerState, day: number, at: number)
	local e = ts.next
	local actual = e.consensus * (1 + e.surprise)
	local surprise = e.surprise * (if e.frenzy then Events.FRENZY_MULT else 1)
	local react = clamp(e.mult * surprise, -Core.MAX_REACTION, Core.MAX_REACTION)
	ts.price = math.max(Core.MIN_PRICE, ts.price * math.exp(react))
	ts.fv *= math.exp(react)
	local prevQ = Earnings.lastQuarter(ts)
	Core.push(ts.quarters, actual, 4)
	local eps = 0
	for _, q in ts.quarters do
		eps += q
	end
	ts.eps = eps
	local growth = if prevQ > 0 then clamp(actual / prevQ - 1, -0.2, 0.2) else 0
	ts.revenue *= 1 + growth * 0.8
	ts.netIncome = eps * ts.def.shares
	ts.ebitda = ts.revenue * ts.def.ebitdaMargin
	local result = if e.surprise >= 0.01 then "beat" elseif e.surprise <= -0.01 then "miss" else "inline"
	ts.last = {
		day = day,
		eps = round2(actual),
		consensus = e.consensus,
		surprise = math.floor(e.surprise * 10000 + 0.5) / 10000,
		reaction = math.floor((math.exp(react) - 1) * 10000 + 0.5) / 10000,
		result = result,
	}
	local move = NewsText.pct(math.exp(react) - 1)
	Core.addNews(
		state,
		"earnings",
		NewsText.pick(result, {
			name = ts.def.name,
			ticker = ts.id,
			eps = NewsText.money(actual),
			cons = NewsText.money(e.consensus),
			move = move,
		}, state.rng),
		if result == "beat" then "good" elseif result == "miss" then "bad" else "info",
		at,
		{ ticker = ts.id }
	)
	Core.emit(state, { kind = "earnings", ticker = ts.id, result = table.clone(ts.last :: Types.Result) })
	-- the next report follows the natural cycle (after a frenzy, after the cycle it pulled forward)
	Earnings.schedule(state, ts, math.max(day + 1, e.natural + 1))
end

---------------------------------------------------------------------------------------------------
-- Catalysts
---------------------------------------------------------------------------------------------------
function Earnings.catalystVars(c: Types.Catalyst): { [string]: any }
	local sector = Tickers.sectors[c.sector]
	return {
		sector = if sector then sector.name else c.sector,
		odds = string.format("%d%%", math.floor(c.odds * 100 + 0.5)),
		up = NewsText.pct(c.up),
		down = NewsText.pct(c.down),
	}
end

function Earnings.scheduleCatalyst(state: State, day: number, at: number)
	local sectorId = state.rng:pick(Core.SECTOR_IDS)
	local sector = Tickers.sectors[sectorId]
	local key = state.rng:pick(sector.catalysts)
	local c: Types.Catalyst = {
		day = day,
		key = key,
		sector = sectorId,
		odds = math.floor(state.rng:range(0.35, 0.8) * 20 + 0.5) / 20,
		up = math.floor(state.rng:range(0.02, 0.045) * 1000 + 0.5) / 1000,
		down = -math.floor(state.rng:range(0.02, 0.045) * 1000 + 0.5) / 1000,
		resolved = false,
		good = nil,
	}
	state.catalyst = c
	Core.addNews(
		state,
		"catalyst",
		NewsText.catalyst(key, "announce", Earnings.catalystVars(c)),
		"warn",
		at,
		{ sector = sectorId }
	)
	Core.emit(state, { kind = "catalyst", catalyst = table.clone(c) })
end

function Earnings.resolveCatalyst(state: State, c: Types.Catalyst, at: number)
	c.resolved = true
	local good = Hash.unit(state.seed, "catalyst", c.day, c.sector, c.key) < c.odds
	c.good = good
	local move = if good then c.up else c.down
	Core.addImpulse(state, "sector", c.sector, math.log(1 + move), 10, { fvShare = 0.6 })
	Core.addNews(
		state,
		"catalyst",
		NewsText.catalyst(c.key, if good then "good" else "bad", Earnings.catalystVars(c)),
		if good then "good" else "bad",
		at,
		{ sector = c.sector }
	)
	Core.emit(state, { kind = "catalyst", catalyst = table.clone(c) })
end

return Earnings
