--!strict
-- Market construction (owned by `market`). PURE: builds the opening state of each ticker and the STREET 10 for
-- Logic/Market/Model.new. Every ticker starts near its fundamental value (EPS x P/E) with a seeded offset, 30 days of
-- backfilled closes (so charts are never empty) and, when the server starts mid-session, a walk from today's open to
-- the current price. The index divisor is set so the STREET 10 opens near Tickers.BENCHMARK.base.
--
--   Setup.newTicker(state, def, openNow, k) -> TickerState
--   Setup.initIndex(state, openNow)

local Types = require(script.Parent.Types)
local Core = require(script.Parent.Core)
local Tickers = require(script.Parent.Parent.Parent.Config.Tickers)

type State = Types.State
type TickerState = Types.TickerState

local Setup = {}

local round2 = Core.round2
local SQRT_TICKS = Core.SQRT_TICKS
local HISTORY_DAYS = Core.HISTORY_DAYS

function Setup.newTicker(state: State, def: Tickers.TickerDef, openNow: boolean, k: number): TickerState
	local rng = state.rng
	local base = Tickers.basePrice(def)
	local fv = base * math.exp(rng:normal(0, 0.06))
	local price = fv * math.exp(rng:normal(0, 0.03))
	local epsAnnual = Tickers.baseEps(def) * (fv / base) ^ 0.5
	local quarters: { number } = {}
	for i = 1, 4 do
		quarters[i] = epsAnnual / 4 * (1 + def.growth) ^ (i - 2.5)
	end
	local eps = 0
	for _, q in quarters do
		eps += q
	end
	local revenue = def.revenue * (eps / Tickers.baseEps(def))
	local vol = Core.dailyVol(def)
	-- backfilled history so charts are never empty: a random walk ending at today's open
	local daily: { number } = table.create(HISTORY_DAYS, 0)
	local p = price * math.exp(rng:normal(0, 0.006))
	for i = HISTORY_DAYS, 1, -1 do
		daily[i] = round2(p)
		p = math.max(Core.MIN_PRICE, p * math.exp(-rng:normal(def.growth / Tickers.EARNINGS_EVERY, vol)))
	end
	local ts: TickerState = {
		id = def.id,
		def = def,
		price = price,
		fv = fv,
		target = fv * math.exp(rng:normal(0, 0.05)),
		open = price,
		high = price,
		low = price,
		prevClose = daily[HISTORY_DAYS],
		close = daily[HISTORY_DAYS],
		intraday = {},
		daily = daily,
		quarters = quarters,
		eps = eps,
		revenue = revenue,
		ebitda = revenue * def.ebitdaMargin,
		netIncome = eps * def.shares,
		dps = def.dividendYield * fv,
		next = {
			day = 0,
			natural = 0,
			consensus = 0,
			published = false,
			surprise = 0,
			mult = 2.5,
			frenzy = false,
		},
		last = nil,
	}
	-- the open session so far (a walk from the open to the current price)
	if openNow and k > 0 then
		local tickVol = vol / SQRT_TICKS
		local walk: { number } = table.create(k + 1, 0)
		local q = price
		for j = k + 1, 1, -1 do
			walk[j] = q
			q = math.max(Core.MIN_PRICE, q * math.exp(-rng:normal(0, tickVol)))
		end
		ts.intraday = walk
		ts.open = walk[1]
		local hi, lo = -math.huge, math.huge
		for _, v in walk do
			hi = math.max(hi, v)
			lo = math.min(lo, v)
		end
		ts.high, ts.low = hi, lo
	elseif openNow then
		ts.intraday = { price }
	end
	return ts
end

function Setup.initIndex(state: State, openNow: boolean)
	-- STREET 10: cap-weighted, starting near its base level
	local base = Tickers.BENCHMARK.base * math.exp(state.rng:normal(0, 0.04))
	local caps = 0
	for _, ts in state.tickers do
		caps += ts.def.shares * ts.price
	end
	state.divisor = caps / base
	local idx = state.index
	idx.level = Core.computeIndex(state)
	for i = 1, HISTORY_DAYS do
		local sum = 0
		for _, ts in state.tickers do
			sum += ts.def.shares * ts.daily[i]
		end
		idx.daily[i] = math.floor(sum / state.divisor * 10 + 0.5) / 10
	end
	idx.prevClose = idx.daily[HISTORY_DAYS]
	idx.close = idx.prevClose
	if openNow then
		local n = #state.tickers[1].intraday
		for j = 1, n do
			local sum = 0
			for _, ts in state.tickers do
				sum += ts.def.shares * (ts.intraday[j] or ts.price)
			end
			idx.intraday[j] = sum / state.divisor
		end
		local first = 0
		for _, ts in state.tickers do
			first += ts.def.shares * ts.open
		end
		idx.open = first / state.divisor
	else
		idx.open = idx.level
	end
	idx.high, idx.low = idx.level, idx.level
	for _, v in idx.intraday do
		idx.high = math.max(idx.high, v)
		idx.low = math.min(idx.low, v)
	end
end

return Setup
