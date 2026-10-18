--!strict
-- Market model internals shared by Logic/Market/{Model, Earnings, Read} (owned by `market`). PURE: no services, no
-- clocks, no Instances. Holds the model's tuning constants and the small state helpers every part of the model uses
-- (news posting, impulses, the outbox, the STREET 10 maths).
--
--   Core.<CONSTANT>                       tuning (Model re-exports them: Model.HISTORY_DAYS, Model.MIN_PRICE, ...)
--   Core.round2 / clamp / push / roundList
--   Core.emit(state, item)                queue an Out item for Model.step's caller
--   Core.relDay(state, day?) -> number    server-relative day (1 = the day the server started)
--   Core.addNews(state, kind, headline, tone, at, extra?) -> NewsItem
--   Core.addImpulse(state, scope, key?, total, ticks, opts?)
--   Core.kitFor(state, now) -> Types.Kit  the helpers event overlays use
--   Core.SECTOR_IDS                       sorted sector ids (deterministic iteration)
--   Core.computeIndex(state) / capWeightedBeta(state) / dailyVol(def)

local Types = require(script.Parent.Types)
local Schedule = require(script.Parent.Schedule)
local NewsText = require(script.Parent.News)
local Tickers = require(script.Parent.Parent.Parent.Config.Tickers)
local Time = require(script.Parent.Parent.Parent.Util.Time)

type State = Types.State
type NewsItem = Types.NewsItem

local Core = {}

Core.TICK = Time.TICK
Core.OPEN_TICKS = Schedule.OPEN_TICKS
Core.HISTORY_DAYS = 30
Core.NEWS_MAX = 40
Core.MIN_PRICE = 0.5
Core.HALF_LIFE_DAYS = 4
Core.MAX_CATCHUP = 450 -- ticks simulated per step; a longer stall skips ahead
Core.CATALYST_CHANCE = 0.3
Core.CATALYST_TICK = 30 -- catalysts resolve one minute into the session
Core.SPREAD = 0.0005 -- quoted bid/ask spread (ratio)
Core.BIG_MOVE = 0.04 -- daily move that makes the news at the close
Core.SURPRISE_SD = 0.045
Core.SURPRISE_BIAS = 0.006
Core.MAX_REACTION = 0.22

Core.KAPPA = math.log(2) / (Core.HALF_LIFE_DAYS * Core.OPEN_TICKS)
Core.SQRT_TICKS = math.sqrt(Core.OPEN_TICKS)

function Core.round2(x: number): number
	return math.floor(x * 100 + 0.5) / 100
end

function Core.clamp(x: number, lo: number, hi: number): number
	return if x < lo then lo elseif x > hi then hi else x
end

function Core.push(list: { number }, v: number, max: number)
	table.insert(list, v)
	while #list > max do
		table.remove(list, 1)
	end
end

function Core.roundList(list: { number }, places: number): { number }
	local m = 10 ^ places
	local out: { number } = table.create(#list, 0)
	for i, v in list do
		out[i] = math.floor(v * m + 0.5) / m
	end
	return out
end

function Core.emit(state: State, item: { [string]: any })
	table.insert(state.outbox, item)
end

function Core.relDay(state: State, day: number?): number
	return (day or state.day) - state.startDay + 1
end

---------------------------------------------------------------------------------------------------
-- News
---------------------------------------------------------------------------------------------------
function Core.addNews(
	state: State,
	kind: string,
	headline: string,
	tone: string,
	at: number,
	extra: { [string]: any }?
): NewsItem
	state.newsSeq += 1
	local item: NewsItem = {
		id = state.newsSeq,
		at = at,
		day = Core.relDay(state),
		kind = kind,
		ticker = if extra and type(extra.ticker) == "string" then extra.ticker else nil,
		sector = if extra and type(extra.sector) == "string" then extra.sector else nil,
		headline = headline,
		tone = tone,
	}
	table.insert(state.news, item)
	while #state.news > Core.NEWS_MAX do
		table.remove(state.news, 1)
	end
	Core.emit(state, { kind = "news", item = item })
	return item
end

---------------------------------------------------------------------------------------------------
-- Impulses (the toolkit event overlays and catalysts use)
---------------------------------------------------------------------------------------------------
function Core.addImpulse(
	state: State,
	scope: string,
	key: string?,
	total: number,
	ticks: number,
	opts: { fvShare: number?, noMR: boolean?, delay: number? }?
)
	local n = math.max(1, math.floor(ticks))
	table.insert(state.impulses, {
		scope = scope,
		key = key,
		perTick = total / n,
		left = n,
		delay = math.max(0, math.floor(if opts and opts.delay then opts.delay else 0)),
		fvShare = Core.clamp(if opts and opts.fvShare then opts.fvShare else 0, 0, 1),
		noMR = opts ~= nil and opts.noMR == true,
	})
end

function Core.kitFor(state: State, now: number): Types.Kit
	return {
		impulse = function(scope, key, total, ticks, opts)
			Core.addImpulse(state, scope, key, total, ticks, opts)
		end,
		news = function(kind, vars, tone, extra)
			Core.addNews(state, kind, NewsText.pick(kind, vars, state.rng), tone, now, extra)
		end,
		now = now,
	}
end

---------------------------------------------------------------------------------------------------
-- Sectors and the STREET 10
---------------------------------------------------------------------------------------------------
Core.SECTOR_IDS = {} :: { string }
for id in Tickers.sectors do
	table.insert(Core.SECTOR_IDS, id)
end
table.sort(Core.SECTOR_IDS)

function Core.capWeightedBeta(state: State): number
	local num, den = 0, 0
	for _, ts in state.tickers do
		local cap = ts.def.shares * ts.price
		num += cap * ts.def.beta
		den += cap
	end
	return if den > 0 then num / den else 1
end

function Core.computeIndex(state: State): number
	local sum = 0
	for _, ts in state.tickers do
		sum += ts.def.shares * ts.price
	end
	return sum / state.divisor
end

-- Total daily volatility of a ticker (market, sector and idiosyncratic factors combined).
function Core.dailyVol(def: Tickers.TickerDef): number
	local sector = Tickers.sectors[def.sector]
	local m = def.beta * Tickers.MARKET_VOL
	local s = if sector then sector.vol else 0
	return math.sqrt(m * m + s * s + def.vol * def.vol)
end

return Core
