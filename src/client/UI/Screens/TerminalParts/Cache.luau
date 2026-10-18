--!strict
-- The client's market cache (owned by `market`). PURE: TerminalController feeds it the Market.Snapshot answer and the
-- 2-second Market.Tick broadcasts (unreliable: drops are fine, gaps carry the last price); the Terminal reads it.
-- It never sees hidden values (fair values, surprises): only what the server publishes.
--
--   Cache.new() -> Cache
--   Cache.applySnapshot(cache, snap)                    replace everything with a fresh snapshot
--   Cache.applyTick(cache, tick) -> (stale, dayChanged) prices, quotes, intraday paths; stale = refetch the snapshot
--   Cache.addNews(cache, item) -> boolean               newest first, deduplicated by id (max NEWS_MAX)
--   Cache.prices(cache) -> { [ticker] = price }         live prices (also before the first snapshot)
--   Cache.ticker(cache, id) -> TickerView?              Cache.ids(cache) -> { string }

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)

export type Quote = {
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
export type TickerView = {
	id: string,
	name: string,
	sector: string,
	sectorName: string,
	quote: Quote,
	intraday: { number },
	daily: { number },
	fund: { [string]: any }?,
	next: { [string]: any }?,
	last: { [string]: any }?,
}
export type IndexView = {
	level: number,
	open: number,
	high: number,
	low: number,
	prevClose: number,
	intraday: { number },
	daily: { number },
}
export type Cache = {
	loaded: boolean,
	day: number,
	phase: string,
	k: number,
	openTicks: number,
	lastTick: number,
	tickers: { TickerView },
	byId: { [string]: TickerView },
	index: IndexView,
	news: { { [string]: any } },
	calendar: { { [string]: any } },
	event: { [string]: any }?,
	eventId: string?,
	catalyst: { [string]: any }?,
	prices: { [string]: number },
	indexLevel: number,
	snapshotAt: number,
}

local Cache = {}

Cache.NEWS_MAX = 40
Cache.SPREAD = 0.0005

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

local function numList(v: any): { number }
	local out: { number } = {}
	if type(v) == "table" then
		for _, x in v do
			if type(x) == "number" and x == x then
				table.insert(out, x)
			end
		end
	end
	return out
end

function Cache.new(): Cache
	return {
		loaded = false,
		day = 0,
		phase = "open",
		k = -1,
		openTicks = 150,
		lastTick = 0,
		tickers = {},
		byId = {},
		index = { level = 0, open = 0, high = 0, low = 0, prevClose = 0, intraday = {}, daily = {} },
		news = {},
		calendar = {},
		event = nil,
		eventId = nil,
		catalyst = nil,
		prices = {},
		indexLevel = 0,
		snapshotAt = 0,
	}
end

local function quoteFrom(q: any, fallback: number): Quote
	local t = if type(q) == "table" then q else {}
	local price = num(t.price, fallback)
	local prev = num(t.prevClose, price)
	return {
		price = price,
		bid = num(t.bid, price * (1 - Cache.SPREAD / 2)),
		ask = num(t.ask, price * (1 + Cache.SPREAD / 2)),
		open = num(t.open, price),
		high = num(t.high, price),
		low = num(t.low, price),
		prevClose = prev,
		close = num(t.close, prev),
		change = price - prev,
		changePct = if prev > 0 then price / prev - 1 else 0,
	}
end

function Cache.applySnapshot(cache: Cache, snap: any)
	if type(snap) ~= "table" or type(snap.tickers) ~= "table" then
		return
	end
	local tickers: { TickerView } = {}
	local byId: { [string]: TickerView } = {}
	for _, entry in snap.tickers do
		if type(entry) == "table" and type(entry.id) == "string" and Tickers.get(entry.id) then
			local def = Tickers.get(entry.id) :: Tickers.TickerDef
			local view: TickerView = {
				id = entry.id,
				name = if type(entry.name) == "string" then entry.name else def.name,
				sector = if type(entry.sector) == "string" then entry.sector else def.sector,
				sectorName = if type(entry.sectorName) == "string" then entry.sectorName else def.sector,
				quote = quoteFrom(entry.quote, cache.prices[entry.id] or 0),
				intraday = numList(entry.intraday),
				daily = numList(entry.daily),
				fund = if type(entry.fund) == "table" then entry.fund else nil,
				next = if type(entry.next) == "table" then entry.next else nil,
				last = if type(entry.last) == "table" then entry.last else nil,
			}
			table.insert(tickers, view)
			byId[view.id] = view
			cache.prices[view.id] = view.quote.price
		end
	end
	-- keep Config order (the tick payload's order)
	table.sort(tickers, function(a, b)
		return (Tickers.index(a.id) or 99) < (Tickers.index(b.id) or 99)
	end)
	cache.tickers = tickers
	cache.byId = byId
	local idx = if type(snap.index) == "table" then snap.index else {}
	local level = num(idx.level, cache.indexLevel)
	cache.index = {
		level = level,
		open = num(idx.open, level),
		high = num(idx.high, level),
		low = num(idx.low, level),
		prevClose = num(idx.prevClose, level),
		intraday = numList(idx.intraday),
		daily = numList(idx.daily),
	}
	cache.indexLevel = level
	cache.news = {}
	if type(snap.news) == "table" then
		for _, item in snap.news do
			if type(item) == "table" and type(item.headline) == "string" then
				table.insert(cache.news, item)
			end
		end
	end
	cache.calendar = if type(snap.calendar) == "table" then snap.calendar else {}
	cache.event = if type(snap.event) == "table" then snap.event else nil
	cache.eventId = if cache.event then cache.event.id else nil
	cache.catalyst = if type(snap.catalyst) == "table" then snap.catalyst else nil
	cache.day = math.floor(num(snap.day, cache.day))
	cache.phase = if type(snap.phase) == "string" then snap.phase else cache.phase
	cache.k = math.floor(num(snap.k, -1))
	cache.openTicks = math.floor(num(snap.openTicks, 150))
	cache.snapshotAt = num(snap.serverTime, num(snap.t, 0))
	cache.loaded = #tickers > 0
end

local function fillPath(path: { number }, k: number, value: number, open: number)
	local n = #path
	local last = if n > 0 then path[n] else open
	for j = n + 1, k do
		path[j] = last -- dropped ticks carry the last price
	end
	if k + 1 >= #path then
		path[k + 1] = value -- only the newest point moves; a stray older index never rewrites history
	end
end

function Cache.applyTick(cache: Cache, tick: any): (boolean, boolean)
	if type(tick) ~= "table" or type(tick.p) ~= "table" then
		return false, false
	end
	local t = num(tick.t, 0)
	if t > 0 and t < cache.lastTick then
		return false, false -- an older packet arriving late
	end
	cache.lastTick = t
	for i, id in Tickers.IDS do
		local p = tick.p[i]
		if type(p) == "number" and p > 0 then
			cache.prices[id] = p
		end
	end
	local ix = tick.ix
	if type(ix) == "number" and ix > 0 then
		cache.indexLevel = ix
	end
	local phase = if type(tick.ph) == "string" then tick.ph else cache.phase
	local k = math.floor(num(tick.k, -1))
	local eventId = if type(tick.ev) == "string" then tick.ev else nil
	local stale = false
	local dayChanged = false
	if cache.loaded then
		local day = math.floor(num(tick.d, cache.day))
		if day ~= cache.day then
			dayChanged = true
			stale = true
			cache.day = day
			for _, view in cache.tickers do
				local q = view.quote
				q.prevClose = q.price
				q.close = q.price
				q.open = q.price
				q.high = q.price
				q.low = q.price
				view.intraday = {}
			end
			local idx = cache.index
			idx.prevClose = idx.level
			idx.open = idx.level
			idx.high = idx.level
			idx.low = idx.level
			idx.intraday = {}
		end
		if eventId ~= cache.eventId then
			stale = true
			cache.eventId = eventId
		end
		for _, view in cache.tickers do
			local p = cache.prices[view.id]
			local q = view.quote
			if p and p > 0 then
				q.price = p
				q.bid = p * (1 - Cache.SPREAD / 2)
				q.ask = p * (1 + Cache.SPREAD / 2)
				q.change = p - q.prevClose
				q.changePct = if q.prevClose > 0 then p / q.prevClose - 1 else 0
				if k >= 0 then
					if p > q.high then
						q.high = p
					end
					if p < q.low then
						q.low = p
					end
					fillPath(view.intraday, k, p, q.open)
				end
			end
		end
		local idx = cache.index
		idx.level = cache.indexLevel
		if k >= 0 then
			idx.high = math.max(idx.high, idx.level)
			idx.low = math.min(idx.low, idx.level)
			fillPath(idx.intraday, k, idx.level, idx.open)
		end
	end
	cache.phase = phase
	cache.k = k
	return stale, dayChanged
end

function Cache.addNews(cache: Cache, item: any): boolean
	if type(item) ~= "table" or type(item.headline) ~= "string" then
		return false
	end
	for _, existing in cache.news do
		if existing.id ~= nil and existing.id == item.id then
			return false
		end
	end
	table.insert(cache.news, 1, item)
	while #cache.news > Cache.NEWS_MAX do
		table.remove(cache.news)
	end
	return true
end

function Cache.prices(cache: Cache): { [string]: number }
	return cache.prices
end

function Cache.ticker(cache: Cache, id: string): TickerView?
	return cache.byId[id]
end

function Cache.ids(_cache: Cache): { string }
	return Tickers.IDS
end

return Cache
