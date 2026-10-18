--!strict
-- Read-only views of the market model (owned by `market`; contracts §6). PURE. Model re-exports every function here,
-- so callers use Model.quote, Model.snapshot and friends. Hidden values (fair values, surprises, reaction sizes, an
-- undecided Fed outcome) never appear in anything returned from this module.
--
--   Read.isHoliday(state, now) / isOpen(state, now) -> boolean     Read.phaseAt(state, now) -> "open"|"after"|"closed"
--   Read.price(state, id) -> number?    prices(state) -> {[id] = price}    priceList(state) -> {number} (Tickers order)
--   Read.indexLevel(state) -> number    quote(state, id) -> Quote?
--   Read.fundamentals(state, id) -> Facts.Fund?    facts(state, id, now?) -> {...}?
--   Read.research(state, id, quality, now?) -> {ticker, direction, beat, confidence, reportDay, inDays, consensus?}?
--   Read.calendar(state, days?) -> { {day, inDays, tickers = { {id, consensus?, frenzy} }} }
--   Read.news(state, limit?) -> { NewsItem } newest first
--   Read.activeEvent(state) -> {id, startsAt, endsAt, params, data}?     catalystPublic(state) -> {...}?
--   Read.snapshot(state, now) -> table   everything the Terminal needs     tickPayload(state, now) -> compact tick

local Types = require(script.Parent.Types)
local Core = require(script.Parent.Core)
local Schedule = require(script.Parent.Schedule)
local Earnings = require(script.Parent.Earnings)
local NewsText = require(script.Parent.News)
local Research = require(script.Parent.Research)
local Facts = require(script.Parent.Facts)
local Tickers = require(script.Parent.Parent.Parent.Config.Tickers)

type State = Types.State
type TickerState = Types.TickerState
type NewsItem = Types.NewsItem

export type Quote = {
	id: string,
	price: number,
	bid: number,
	ask: number,
	open: number,
	high: number,
	low: number,
	prevClose: number,
	close: number,
	change: number,
	changePct: number,
}

local Read = {}

local round2 = Core.round2
local relDay = Core.relDay

function Read.isHoliday(state: State, now: number): boolean
	local ev = state.event
	return ev ~= nil and ev.closes and now < ev.endsAt
end

function Read.isOpen(state: State, now: number): boolean
	return Schedule.phase(now) == "open" and state.phase == "open" and not Read.isHoliday(state, now)
end

function Read.phaseAt(state: State, now: number): string
	if Read.isHoliday(state, now) then
		return "closed"
	end
	return Schedule.phase(now)
end

function Read.price(state: State, id: string): number?
	local ts = state.byId[id]
	return if ts then ts.price else nil
end

function Read.prices(state: State): { [string]: number }
	local out: { [string]: number } = {}
	for _, ts in state.tickers do
		out[ts.id] = ts.price
	end
	return out
end

function Read.priceList(state: State): { number }
	local out: { number } = table.create(#state.tickers, 0)
	for i, ts in state.tickers do
		out[i] = round2(ts.price)
	end
	return out
end

function Read.indexLevel(state: State): number
	return state.index.level
end

function Read.quote(state: State, id: string): Quote?
	local ts = state.byId[id]
	if not ts then
		return nil
	end
	local half = Core.SPREAD / 2
	return {
		id = ts.id,
		price = round2(ts.price),
		bid = round2(ts.price * (1 - half)),
		ask = round2(ts.price * (1 + half)),
		open = round2(ts.open),
		high = round2(ts.high),
		low = round2(ts.low),
		prevClose = round2(ts.prevClose),
		close = round2(ts.close),
		change = round2(ts.price - ts.prevClose),
		changePct = if ts.prevClose > 0 then math.floor((ts.price / ts.prevClose - 1) * 10000 + 0.5) / 10000 else 0,
	}
end

local function nextPublic(state: State, ts: TickerState): { [string]: any }
	local e = ts.next
	return {
		day = relDay(state, e.day),
		inDays = math.max(0, e.day - state.day),
		consensus = if e.published then e.consensus else nil,
		frenzy = e.frenzy,
	}
end

local function lastPublic(state: State, ts: TickerState): { [string]: any }?
	local r = ts.last
	if not r then
		return nil
	end
	return {
		day = relDay(state, r.day),
		eps = r.eps,
		consensus = r.consensus,
		surprise = r.surprise,
		reaction = r.reaction,
		result = r.result,
	}
end

function Read.fundamentals(state: State, id: string): Facts.Fund?
	local ts = state.byId[id]
	if not ts then
		return nil
	end
	local def = ts.def
	local sector = Tickers.sectors[def.sector]
	return {
		ticker = def.id,
		name = def.name,
		sector = def.sector,
		sectorName = if sector then sector.name else def.sector,
		desc = def.desc,
		shares = def.shares,
		eps = ts.eps,
		revenue = ts.revenue,
		ebitda = ts.ebitda,
		netIncome = ts.netIncome,
		debt = def.debt,
		cash = def.cash,
		dps = ts.dps,
		beta = def.beta,
		growth = def.growth,
		target = ts.target,
	}
end

function Read.facts(state: State, id: string, _now: number?): { [string]: any }?
	local ts = state.byId[id]
	local fund = Read.fundamentals(state, id)
	if not ts or not fund then
		return nil
	end
	local headline: string? = nil
	for i = #state.news, 1, -1 do
		if state.news[i].ticker == id then
			headline = state.news[i].headline
			break
		end
	end
	local chart = table.clone(ts.daily)
	table.insert(chart, round2(ts.price))
	return Facts.derive(fund, ts.price, {
		prevClose = ts.prevClose,
		open = round2(ts.open),
		high = round2(ts.high),
		low = round2(ts.low),
		nextEarnings = nextPublic(state, ts),
		lastEarnings = lastPublic(state, ts),
		chart = chart,
		headline = headline,
	})
end

function Read.research(state: State, id: string, quality: any, _now: number?): { [string]: any }?
	local ts = state.byId[id]
	if not ts then
		return nil
	end
	local e = ts.next
	local s = Research.signal(state.seed, id, e.day, e.surprise, quality)
	return {
		ticker = id,
		direction = s.direction,
		beat = s.beat,
		confidence = s.confidence,
		reportDay = relDay(state, e.day),
		inDays = math.max(0, e.day - state.day),
		consensus = if e.published then e.consensus else nil,
	}
end

function Read.calendar(state: State, days: number?): { { [string]: any } }
	local horizon = days or Tickers.EARNINGS_EVERY
	local byDay: { [number]: { { [string]: any } } } = {}
	for _, ts in state.tickers do
		local e = ts.next
		if e.day - state.day <= horizon then
			local list = byDay[e.day]
			if not list then
				list = {}
				byDay[e.day] = list
			end
			table.insert(list, { id = ts.id, consensus = if e.published then e.consensus else nil, frenzy = e.frenzy })
		end
	end
	local out: { { [string]: any } } = {}
	for d, list in byDay do
		table.sort(list, function(a, b)
			return a.id < b.id
		end)
		table.insert(out, { day = relDay(state, d), inDays = math.max(0, d - state.day), tickers = list })
	end
	table.sort(out, function(a, b)
		return a.day < b.day
	end)
	return out
end

function Read.news(state: State, limit: number?): { NewsItem }
	local n = math.clamp(math.floor(limit or Core.NEWS_MAX), 0, Core.NEWS_MAX)
	local out: { NewsItem } = {}
	for i = #state.news, math.max(1, #state.news - n + 1), -1 do
		table.insert(out, table.clone(state.news[i]))
	end
	return out
end

function Read.activeEvent(state: State): { [string]: any }?
	local ev = state.event
	if not ev then
		return nil
	end
	local data: { [string]: any } = {}
	for k, v in ev.data do
		local tv = type(v)
		if tv == "string" or tv == "number" or tv == "boolean" then
			data[k] = v
		end
	end
	-- an unfinished fed decision's outcome stays hidden
	data.outcome = if ev.id == "fed_day" and ev.data.decided ~= true then nil else data.outcome
	return {
		id = ev.id,
		startsAt = ev.startsAt,
		endsAt = ev.endsAt,
		params = table.clone(ev.params),
		data = data,
	}
end

function Read.catalystPublic(state: State): { [string]: any }?
	local c = state.catalyst
	if not c then
		return nil
	end
	local sector = Tickers.sectors[c.sector]
	local phase = if c.resolved then (if c.good then "good" else "bad") else "announce"
	return {
		day = relDay(state, c.day),
		sector = c.sector,
		sectorName = if sector then sector.name else c.sector,
		key = c.key,
		odds = c.odds,
		up = c.up,
		down = c.down,
		resolved = c.resolved,
		good = c.good,
		text = NewsText.catalyst(c.key, phase, Earnings.catalystVars(c)),
	}
end

function Read.snapshot(state: State, now: number): { [string]: any }
	local tickers: { { [string]: any } } = {}
	for _, ts in state.tickers do
		local q = Read.quote(state, ts.id) :: Quote
		local sector = Tickers.sectors[ts.def.sector]
		table.insert(tickers, {
			id = ts.id,
			name = ts.def.name,
			sector = ts.def.sector,
			sectorName = if sector then sector.name else ts.def.sector,
			quote = q,
			intraday = Core.roundList(ts.intraday, 2),
			daily = table.clone(ts.daily),
			fund = Read.fundamentals(state, ts.id),
			next = nextPublic(state, ts),
			last = lastPublic(state, ts),
		})
	end
	local idx = state.index
	return {
		t = now,
		day = relDay(state),
		phase = Read.phaseAt(state, now),
		k = state.k,
		openTicks = Core.OPEN_TICKS,
		tickers = tickers,
		index = {
			level = math.floor(idx.level * 10 + 0.5) / 10,
			open = math.floor(idx.open * 10 + 0.5) / 10,
			high = math.floor(idx.high * 10 + 0.5) / 10,
			low = math.floor(idx.low * 10 + 0.5) / 10,
			prevClose = idx.prevClose,
			intraday = Core.roundList(idx.intraday, 1),
			daily = table.clone(idx.daily),
		},
		news = Read.news(state, 25),
		calendar = Read.calendar(state),
		event = Read.activeEvent(state),
		catalyst = Read.catalystPublic(state),
	}
end

function Read.tickPayload(state: State, now: number): { [string]: any }
	local ev = state.event
	return {
		t = now,
		d = relDay(state),
		ph = Read.phaseAt(state, now),
		k = if Schedule.phase(now) == "open" and state.phase == "open" then state.k else -1,
		p = Read.priceList(state),
		ix = math.floor(state.index.level * 10 + 0.5) / 10,
		ev = if ev then ev.id else nil,
	}
end

return Read
