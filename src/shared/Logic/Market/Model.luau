--!strict
-- The per-server market model (owned by `market`; spec §7, design v3 §11, contracts §6). PURE: no services, no clocks,
-- no Instances. MarketService seeds it once per server and steps it forward in time; the same seed and the same
-- sequence of step/trigger calls always produce the same prices (tests rely on it).
--
-- Each open tick (Time.TICK = 2 s, 150 per 300 s session) every ticker's log price moves by
--     kappa * ln(fair / price)                       mean reversion to fair value (half-life HALF_LIFE_DAYS)
--   + beta * market + sector + idio                  factor shocks, scaled by the U-shaped intraday curve
--   + impulses                                       scheduled moves (catalysts, earnings gaps, event overlays)
-- Fair value grows with expected EPS growth, jumps with earnings surprises and absorbs the persistent share of
-- shocks. Every company reports every Tickers.EARNINGS_EVERY market days after the close (staggered by
-- earningsOffset); consensus is published Tickers.CONSENSUS_LEAD days ahead and the surprise is drawn from the seed
-- when the report is scheduled (hidden; research reads it through an honest noisy signal). Sector catalysts are
-- announced a day ahead with stated odds. Prices never go below MIN_PRICE.
--
--   Model.new(seed, now) -> State
--   Model.step(state, now) -> { Out }        advance to `now`; Out = {kind = "news"|"earnings"|"phase"|"day"|
--                                            "event_start"|"event_end"|"catalyst", ...}
--   Model.trigger(state, id, params?, now) -> (ok, err?)     err "unknown_event" | "busy"
--   Model.stopEvent(state, now) -> boolean   Model.activeEvent(state) -> {id, startsAt, endsAt, params}?
--   Model.isOpen(state, now) / Model.isHoliday(state, now) -> boolean     Model.phaseAt(state, now) -> string
--   Model.price(state, id) -> number?   Model.prices(state) -> {[id] = price}   Model.priceList(state) -> {number}
--   Model.quote(state, id) -> Quote?    Model.indexLevel(state) -> number
--   Model.facts(state, id, now) -> {...}?    Model.research(state, id, quality, now) -> {...}?
--   Model.calendar(state, days?) -> { {day, inDays, tickers = { {id, consensus?} }} }
--   Model.news(state, limit?) -> { NewsItem } newest first
--   Model.snapshot(state, now) -> table       everything the Terminal needs (never hidden values)
--   Model.tickPayload(state, now) -> table    the compact Market.Tick broadcast
--   Model.relDay(state, day?) -> number       server-relative day number (1 = the start day)

local Types = require(script.Parent.Types)
local Schedule = require(script.Parent.Schedule)
local Events = require(script.Parent.Events)
local NewsText = require(script.Parent.News)
local Research = require(script.Parent.Research)
local Facts = require(script.Parent.Facts)
local Tickers = require(script.Parent.Parent.Parent.Config.Tickers)
local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Hash = require(script.Parent.Parent.Parent.Util.Hash)
local Time = require(script.Parent.Parent.Parent.Util.Time)

export type State = Types.State
export type TickerState = Types.TickerState
export type NewsItem = Types.NewsItem
export type EventState = Types.EventState
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

local Model = {}

Model.TICK = Time.TICK
Model.OPEN_TICKS = Schedule.OPEN_TICKS
Model.HISTORY_DAYS = 30
Model.NEWS_MAX = 40
Model.MIN_PRICE = 0.5
Model.HALF_LIFE_DAYS = 4
Model.MAX_CATCHUP = 450 -- ticks simulated per step; a longer stall skips ahead
Model.CATALYST_CHANCE = 0.3
Model.CATALYST_TICK = 30 -- catalysts resolve one minute into the session
Model.SPREAD = 0.0005 -- quoted bid/ask spread (ratio)
Model.BIG_MOVE = 0.04 -- daily move that makes the news at the close
Model.SURPRISE_SD = 0.045
Model.SURPRISE_BIAS = 0.006
Model.MAX_REACTION = 0.22

local KAPPA = math.log(2) / (Model.HALF_LIFE_DAYS * Model.OPEN_TICKS)
local SQRT_TICKS = math.sqrt(Model.OPEN_TICKS)

local function round2(x: number): number
	return math.floor(x * 100 + 0.5) / 100
end

local function clamp(x: number, lo: number, hi: number): number
	return if x < lo then lo elseif x > hi then hi else x
end

local function push(list: { number }, v: number, max: number)
	table.insert(list, v)
	while #list > max do
		table.remove(list, 1)
	end
end

local function emit(state: State, item: { [string]: any })
	table.insert(state.outbox, item)
end

function Model.relDay(state: State, day: number?): number
	return (day or state.day) - state.startDay + 1
end

---------------------------------------------------------------------------------------------------
-- News
---------------------------------------------------------------------------------------------------
local function addNews(
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
		day = Model.relDay(state),
		kind = kind,
		ticker = if extra and type(extra.ticker) == "string" then extra.ticker else nil,
		sector = if extra and type(extra.sector) == "string" then extra.sector else nil,
		headline = headline,
		tone = tone,
	}
	table.insert(state.news, item)
	while #state.news > Model.NEWS_MAX do
		table.remove(state.news, 1)
	end
	emit(state, { kind = "news", item = item })
	return item
end
Model.addNews = addNews

---------------------------------------------------------------------------------------------------
-- Earnings schedule
---------------------------------------------------------------------------------------------------
local function lastQuarter(ts: TickerState): number
	return ts.quarters[#ts.quarters] or (ts.eps / 4)
end

local function naturalDay(def: Tickers.TickerDef, fromDay: number): number
	local every = Tickers.EARNINGS_EVERY
	local r = (fromDay - def.earningsOffset) % every
	return if r == 0 then fromDay else fromDay + (every - r)
end

local function schedule(state: State, ts: TickerState, fromDay: number)
	local def = ts.def
	local e = naturalDay(def, fromDay)
	local growth = def.growth + state.rng:normal(0, 0.006)
	local surprise = clamp(
		Hash.normal(state.seed, "surprise", def.id, e) * Model.SURPRISE_SD + Model.SURPRISE_BIAS,
		-0.25,
		0.25
	)
	ts.next = {
		day = e,
		natural = e,
		consensus = round2(lastQuarter(ts) * (1 + growth)),
		published = e - state.day <= Tickers.CONSENSUS_LEAD,
		surprise = surprise,
		mult = 2.2 + 0.8 * Hash.unit(state.seed, "sens", def.id, e),
		frenzy = false,
	}
end

local function publishConsensus(state: State, ts: TickerState, at: number)
	local e = ts.next
	e.published = true
	local days = math.max(0, e.day - state.day)
	addNews(
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

local function release(state: State, ts: TickerState, day: number, at: number)
	local e = ts.next
	local actual = e.consensus * (1 + e.surprise)
	local surprise = e.surprise * (if e.frenzy then Events.FRENZY_MULT else 1)
	local react = clamp(e.mult * surprise, -Model.MAX_REACTION, Model.MAX_REACTION)
	ts.price = math.max(Model.MIN_PRICE, ts.price * math.exp(react))
	ts.fv *= math.exp(react)
	local prevQ = lastQuarter(ts)
	push(ts.quarters, actual, 4)
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
	addNews(
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
	emit(state, { kind = "earnings", ticker = ts.id, result = table.clone(ts.last :: Types.Result) })
	-- the next report follows the natural cycle (after a frenzy, after the cycle it pulled forward)
	schedule(state, ts, math.max(day + 1, e.natural + 1))
end

---------------------------------------------------------------------------------------------------
-- Impulses (the toolkit event overlays and catalysts use)
---------------------------------------------------------------------------------------------------
local function addImpulse(
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
		fvShare = clamp(if opts and opts.fvShare then opts.fvShare else 0, 0, 1),
		noMR = opts ~= nil and opts.noMR == true,
	})
end

local function kitFor(state: State, now: number): Types.Kit
	return {
		impulse = function(scope, key, total, ticks, opts)
			addImpulse(state, scope, key, total, ticks, opts)
		end,
		news = function(kind, vars, tone, extra)
			addNews(state, kind, NewsText.pick(kind, vars, state.rng), tone, now, extra)
		end,
		now = now,
	}
end

---------------------------------------------------------------------------------------------------
-- Catalysts
---------------------------------------------------------------------------------------------------
local SECTOR_IDS: { string } = {}
for id in Tickers.sectors do
	table.insert(SECTOR_IDS, id)
end
table.sort(SECTOR_IDS)

local function catalystVars(c: Types.Catalyst): { [string]: any }
	local sector = Tickers.sectors[c.sector]
	return {
		sector = if sector then sector.name else c.sector,
		odds = string.format("%d%%", math.floor(c.odds * 100 + 0.5)),
		up = NewsText.pct(c.up),
		down = NewsText.pct(c.down),
	}
end

local function scheduleCatalyst(state: State, day: number, at: number)
	local sectorId = state.rng:pick(SECTOR_IDS)
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
	addNews(state, "catalyst", NewsText.catalyst(key, "announce", catalystVars(c)), "warn", at, { sector = sectorId })
	emit(state, { kind = "catalyst", catalyst = table.clone(c) })
end

local function resolveCatalyst(state: State, c: Types.Catalyst, at: number)
	c.resolved = true
	local good = Hash.unit(state.seed, "catalyst", c.day, c.sector, c.key) < c.odds
	c.good = good
	local move = if good then c.up else c.down
	addImpulse(state, "sector", c.sector, math.log(1 + move), 10, { fvShare = 0.6 })
	addNews(
		state,
		"catalyst",
		NewsText.catalyst(c.key, if good then "good" else "bad", catalystVars(c)),
		if good then "good" else "bad",
		at,
		{ sector = c.sector }
	)
	emit(state, { kind = "catalyst", catalyst = table.clone(c) })
end

---------------------------------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------------------------------
local function capWeightedBeta(state: State): number
	local num, den = 0, 0
	for _, ts in state.tickers do
		local cap = ts.def.shares * ts.price
		num += cap * ts.def.beta
		den += cap
	end
	return if den > 0 then num / den else 1
end

local function computeIndex(state: State): number
	local sum = 0
	for _, ts in state.tickers do
		sum += ts.def.shares * ts.price
	end
	return sum / state.divisor
end

local function dailyVol(def: Tickers.TickerDef): number
	local sector = Tickers.sectors[def.sector]
	local m = def.beta * Tickers.MARKET_VOL
	local s = if sector then sector.vol else 0
	return math.sqrt(m * m + s * s + def.vol * def.vol)
end

function Model.new(seed: number, now: number): State
	local rng = Rng.new(seed)
	local day, into = Time.dayIndex(now)
	local openNow = into < Time.OPEN_LEN
	local k = if openNow then math.floor(into / Time.TICK) else -1
	local state: State = {
		seed = seed,
		rng = rng,
		divisor = 1,
		startDay = day,
		day = day,
		phase = if openNow then "open" else "after",
		k = k,
		tickT = math.floor(now / Time.TICK) * Time.TICK,
		openedDay = if openNow then day else -1,
		closedDay = if openNow then day - 1 else day,
		tickers = {},
		byId = {},
		index = {
			level = 0,
			open = 0,
			high = 0,
			low = 0,
			prevClose = 0,
			close = 0,
			intraday = {},
			daily = {},
		},
		news = {},
		newsSeq = 0,
		event = nil,
		impulses = {},
		catalyst = nil,
		outbox = {},
	}

	for _, def in Tickers.list do
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
		local vol = dailyVol(def)
		-- backfilled history so charts are never empty: a random walk ending at today's open
		local daily: { number } = table.create(Model.HISTORY_DAYS, 0)
		local p = price * math.exp(rng:normal(0, 0.006))
		for i = Model.HISTORY_DAYS, 1, -1 do
			daily[i] = round2(p)
			p = math.max(Model.MIN_PRICE, p * math.exp(-rng:normal(def.growth / Tickers.EARNINGS_EVERY, vol)))
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
			prevClose = daily[Model.HISTORY_DAYS],
			close = daily[Model.HISTORY_DAYS],
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
				q = math.max(Model.MIN_PRICE, q * math.exp(-rng:normal(0, tickVol)))
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
		table.insert(state.tickers, ts)
		state.byId[def.id] = ts
	end

	-- STREET 10: cap-weighted, starting near its base level
	local base = Tickers.BENCHMARK.base * math.exp(rng:normal(0, 0.04))
	local caps = 0
	for _, ts in state.tickers do
		caps += ts.def.shares * ts.price
	end
	state.divisor = caps / base
	local idx = state.index
	idx.level = computeIndex(state)
	for i = 1, Model.HISTORY_DAYS do
		local sum = 0
		for _, ts in state.tickers do
			sum += ts.def.shares * ts.daily[i]
		end
		idx.daily[i] = math.floor(sum / state.divisor * 10 + 0.5) / 10
	end
	idx.prevClose = idx.daily[Model.HISTORY_DAYS]
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

	-- earnings: today's report still counts while today's close hasn't happened
	for _, ts in state.tickers do
		schedule(state, ts, if openNow then day else day + 1)
	end
	return state
end

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------
function Model.isHoliday(state: State, now: number): boolean
	local ev = state.event
	return ev ~= nil and ev.closes and now < ev.endsAt
end

local function endEvent(state: State, now: number, reason: string)
	local ev = state.event
	if not ev then
		return
	end
	state.event = nil
	emit(state, { kind = "event_end", id = ev.id, at = now, reason = reason })
end

function Model.trigger(state: State, id: string, params: { [string]: any }?, now: number): (boolean, string?)
	local def = Events.get(id)
	if not def then
		return false, "unknown_event"
	end
	local p: { [string]: any } = {}
	if type(params) == "table" then
		for k, v in params do
			local tv = type(v)
			if type(k) == "string" and (tv == "number" or tv == "string" or tv == "boolean") then
				p[k] = v
			elseif type(k) == "string" and tv == "table" then
				local list: { any } = {}
				for _, x in v :: { any } do
					if type(x) == "string" or type(x) == "number" then
						table.insert(list, x)
					end
				end
				p[k] = list
			end
		end
	end
	if state.event then
		if p.force ~= true then
			return false, "busy"
		end
		endEvent(state, now, "replaced")
	end
	local ev: EventState = {
		id = id,
		startsAt = now,
		endsAt = now,
		params = p,
		ticks = 0,
		openTicks = def.openTicks,
		closes = def.closes,
		data = {},
	}
	def.start(state, ev, kitFor(state, now))
	if ev.openTicks then
		ev.endsAt = Schedule.afterOpenTicks(now, ev.openTicks)
	end
	state.event = ev
	local info = Tickers.events[id]
	if info then
		local vars: { [string]: any } = {}
		for k, v in ev.data do
			if type(v) == "string" or type(v) == "number" then
				vars[k] = v
			end
		end
		addNews(state, "event", Tickers.fill(info.headline, vars), info.tone, now, {
			ticker = if type(ev.data.ticker) == "string" then ev.data.ticker else nil,
		})
	end
	emit(state, { kind = "event_start", event = Model.activeEvent(state) })
	if def.closes and state.phase ~= "closed" then
		state.phase = "closed"
		emit(state, { kind = "phase", phase = "closed" })
	end
	return true, nil
end

function Model.stopEvent(state: State, now: number): boolean
	if not state.event then
		return false
	end
	endEvent(state, now, "stopped")
	return true
end

function Model.activeEvent(state: State): { [string]: any }?
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

---------------------------------------------------------------------------------------------------
-- Stepping
---------------------------------------------------------------------------------------------------
local function setPhase(state: State, phase: string, now: number)
	if state.phase == phase then
		return
	end
	local old = state.phase
	state.phase = phase
	if old == "closed" and phase == "open" then
		addNews(state, "reopen", NewsText.pick("reopen", {}, state.rng), "info", now)
	end
	emit(state, { kind = "phase", phase = phase, at = now })
end

local function rollover(state: State, day: number, now: number)
	state.day = day
	state.k = -1
	local common = state.rng:normal(0, 0.0025)
	for _, ts in state.tickers do
		ts.prevClose = ts.close
		local gap = ts.def.beta * common + state.rng:normal(0, 0.004)
		ts.price = math.max(Model.MIN_PRICE, ts.price * math.exp(gap))
		ts.open = ts.price
		ts.high = ts.price
		ts.low = ts.price
		ts.intraday = {}
		ts.fv *= math.exp(ts.def.growth / Tickers.EARNINGS_EVERY + state.rng:normal(0, 0.004))
		ts.target = ts.fv * math.exp(state.rng:normal(0, 0.05))
		ts.dps = ts.def.dividendYield * ts.fv
		if not ts.next.published and ts.next.day - day <= Tickers.CONSENSUS_LEAD then
			publishConsensus(state, ts, now)
		end
	end
	local idx = state.index
	idx.prevClose = idx.close
	idx.level = computeIndex(state)
	idx.open = idx.level
	idx.high = idx.level
	idx.low = idx.level
	idx.intraday = {}
	local c = state.catalyst
	if c and not c.resolved and c.day < day then
		c.day = day -- missed (holiday): resolves today instead
	end
	if (not c or c.resolved) and state.rng:next() < Model.CATALYST_CHANCE then
		scheduleCatalyst(state, day + 1, now)
	end
	emit(state, { kind = "day", day = day, rel = Model.relDay(state, day), at = now })
end

local function onClose(state: State, day: number, now: number, closed: boolean)
	if state.openedDay == day then
		local best: { { id: string, pct: number } } = {}
		for _, ts in state.tickers do
			ts.close = ts.price
			push(ts.daily, round2(ts.price), Model.HISTORY_DAYS)
			table.insert(best, { id = ts.id, pct = if ts.prevClose > 0 then ts.price / ts.prevClose - 1 else 0 })
		end
		local idx = state.index
		idx.close = idx.level
		push(idx.daily, math.floor(idx.level * 10 + 0.5) / 10, Model.HISTORY_DAYS)
		table.sort(best, function(a, b)
			return a.pct > b.pct
		end)
		local function fmt(entry: { id: string, pct: number }): string
			return entry.id .. " " .. NewsText.pct(entry.pct)
		end
		local idxPct = if idx.prevClose > 0 then idx.level / idx.prevClose - 1 else 0
		addNews(
			state,
			"close",
			NewsText.pick("close", {
				level = NewsText.level(idx.level),
				pct = NewsText.pct(idxPct),
				leaders = fmt(best[1]) .. ", " .. fmt(best[2]),
				laggards = fmt(best[#best]) .. ", " .. fmt(best[#best - 1]),
			}, state.rng),
			if idxPct >= 0 then "good" else "bad",
			now
		)
		for _, entry in best do
			if math.abs(entry.pct) >= Model.BIG_MOVE then
				local ts = state.byId[entry.id]
				local up = entry.pct > 0
				addNews(
					state,
					"mover",
					NewsText.pick(if up then "mover_up" else "mover_down", {
						name = ts.def.name,
						ticker = ts.id,
						pct = NewsText.pct(math.abs(entry.pct)),
						reason = NewsText.reason(ts.def.sector, up, state.rng),
					}, state.rng),
					if up then "good" else "bad",
					now,
					{ ticker = ts.id }
				)
			end
		end
	end
	for _, ts in state.tickers do
		if ts.next.day <= day then
			if closed then
				ts.next.day = day + 1 -- the exchange is shut: the report waits for the next close
			else
				release(state, ts, day, now)
			end
		end
	end
end

local function openTick(state: State, k: number, now: number)
	state.openedDay = state.day
	state.k = k
	local rng = state.rng
	local ev = state.event
	if ev then
		ev.ticks += 1
		local def = Events.get(ev.id)
		if def and def.tick then
			def.tick(state, ev, kitFor(state, now))
		end
	end
	local vm, tvm = Events.vol(state, state.event)
	local u = Schedule.uShape(k / (Model.OPEN_TICKS - 1)) * vm
	local market = Tickers.MARKET_VOL / SQRT_TICKS * u * rng:normal()
	local sectors: { [string]: number } = {}
	for _, id in SECTOR_IDS do
		sectors[id] = Tickers.sectors[id].vol / SQRT_TICKS * u * rng:normal()
	end

	-- impulses
	local drift: { [string]: number } = {}
	local fvDrift: { [string]: number } = {}
	local noMR: { [string]: boolean } = {}
	if #state.impulses > 0 then
		local avgBeta = capWeightedBeta(state)
		for i = #state.impulses, 1, -1 do
			local imp = state.impulses[i]
			if imp.delay > 0 then
				imp.delay -= 1
			else
				for _, ts in state.tickers do
					local scale = 0
					if imp.scope == "market" then
						scale = ts.def.beta / avgBeta
					elseif imp.scope == "sector" and ts.def.sector == imp.key then
						scale = 1
					elseif imp.scope == "ticker" and ts.id == imp.key then
						scale = 1
					end
					if scale ~= 0 then
						local move = imp.perTick * scale
						drift[ts.id] = (drift[ts.id] or 0) + move
						fvDrift[ts.id] = (fvDrift[ts.id] or 0) + move * imp.fvShare
						if imp.noMR then
							noMR[ts.id] = true
						end
					end
				end
				imp.left -= 1
				if imp.left <= 0 then
					table.remove(state.impulses, i)
				end
			end
		end
	end

	for _, ts in state.tickers do
		local def = ts.def
		local mr = if noMR[ts.id] then 0 else KAPPA * math.log(ts.fv / ts.price)
		local tickerMult = if tvm and tvm[ts.id] then tvm[ts.id] else 1
		local idio = def.vol / SQRT_TICKS * u * tickerMult * rng:normal()
		local lnr = mr + def.beta * market + (sectors[def.sector] or 0) + idio + (drift[ts.id] or 0)
		ts.price = math.max(Model.MIN_PRICE, ts.price * math.exp(lnr))
		local fd = fvDrift[ts.id]
		if fd then
			ts.fv *= math.exp(fd)
		end
		if ts.price > ts.high then
			ts.high = ts.price
		end
		if ts.price < ts.low then
			ts.low = ts.price
		end
		local n = #ts.intraday
		local last = if n > 0 then ts.intraday[n] else ts.open
		for j = n + 1, k do
			ts.intraday[j] = last -- ticks skipped by a stall carry the last price
		end
		ts.intraday[k + 1] = ts.price
	end

	local idx = state.index
	idx.level = computeIndex(state)
	if idx.level > idx.high then
		idx.high = idx.level
	end
	if idx.level < idx.low then
		idx.low = idx.level
	end
	local n = #idx.intraday
	local lastLevel = if n > 0 then idx.intraday[n] else idx.open
	for j = n + 1, k do
		idx.intraday[j] = lastLevel
	end
	idx.intraday[k + 1] = idx.level

	local c = state.catalyst
	if c and not c.resolved and c.day == state.day and k >= Model.CATALYST_TICK then
		resolveCatalyst(state, c, now)
	end

	local live = state.event
	if live and live.openTicks then
		if live.ticks >= live.openTicks then
			endEvent(state, now, "done")
		else
			live.endsAt = Schedule.afterOpenTicks(now, live.openTicks - live.ticks)
		end
	end
end

local function processTick(state: State, t: number)
	local day, into = Time.dayIndex(t)
	if day ~= state.day then
		rollover(state, day, t)
	end
	local ev = state.event
	if ev and not ev.openTicks and t >= ev.endsAt then
		endEvent(state, t, "done")
	end
	local closed = Model.isHoliday(state, t)
	if into < Time.OPEN_LEN then
		if closed then
			setPhase(state, "closed", t)
		else
			setPhase(state, "open", t)
			openTick(state, math.floor(into / Time.TICK), t)
		end
	else
		if state.closedDay ~= day then
			state.closedDay = day
			onClose(state, day, t, closed)
		end
		setPhase(state, if closed then "closed" else "after", t)
	end
end

function Model.step(state: State, now: number): { { [string]: any } }
	local target = math.floor(now / Time.TICK) * Time.TICK
	if (target - state.tickT) / Time.TICK > Model.MAX_CATCHUP then
		state.tickT = target - Model.MAX_CATCHUP * Time.TICK
	end
	while state.tickT + Time.TICK <= target do
		state.tickT += Time.TICK
		processTick(state, state.tickT)
	end
	local out = state.outbox
	state.outbox = {}
	return out
end

---------------------------------------------------------------------------------------------------
-- Reading
---------------------------------------------------------------------------------------------------
function Model.isOpen(state: State, now: number): boolean
	return Schedule.phase(now) == "open" and state.phase == "open" and not Model.isHoliday(state, now)
end

function Model.phaseAt(state: State, now: number): string
	if Model.isHoliday(state, now) then
		return "closed"
	end
	return Schedule.phase(now)
end

function Model.price(state: State, id: string): number?
	local ts = state.byId[id]
	return if ts then ts.price else nil
end

function Model.prices(state: State): { [string]: number }
	local out: { [string]: number } = {}
	for _, ts in state.tickers do
		out[ts.id] = ts.price
	end
	return out
end

function Model.priceList(state: State): { number }
	local out: { number } = table.create(#state.tickers, 0)
	for i, ts in state.tickers do
		out[i] = round2(ts.price)
	end
	return out
end

function Model.indexLevel(state: State): number
	return state.index.level
end

function Model.quote(state: State, id: string): Quote?
	local ts = state.byId[id]
	if not ts then
		return nil
	end
	local half = Model.SPREAD / 2
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
		day = Model.relDay(state, e.day),
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
		day = Model.relDay(state, r.day),
		eps = r.eps,
		consensus = r.consensus,
		surprise = r.surprise,
		reaction = r.reaction,
		result = r.result,
	}
end

function Model.fundamentals(state: State, id: string): Facts.Fund?
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

function Model.facts(state: State, id: string, _now: number?): { [string]: any }?
	local ts = state.byId[id]
	local fund = Model.fundamentals(state, id)
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

function Model.research(state: State, id: string, quality: any, _now: number?): { [string]: any }?
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
		reportDay = Model.relDay(state, e.day),
		inDays = math.max(0, e.day - state.day),
		consensus = if e.published then e.consensus else nil,
	}
end

function Model.calendar(state: State, days: number?): { { [string]: any } }
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
		table.insert(out, { day = Model.relDay(state, d), inDays = math.max(0, d - state.day), tickers = list })
	end
	table.sort(out, function(a, b)
		return a.day < b.day
	end)
	return out
end

function Model.news(state: State, limit: number?): { NewsItem }
	local n = math.clamp(math.floor(limit or Model.NEWS_MAX), 0, Model.NEWS_MAX)
	local out: { NewsItem } = {}
	for i = #state.news, math.max(1, #state.news - n + 1), -1 do
		table.insert(out, table.clone(state.news[i]))
	end
	return out
end

local function roundList(list: { number }, places: number): { number }
	local m = 10 ^ places
	local out: { number } = table.create(#list, 0)
	for i, v in list do
		out[i] = math.floor(v * m + 0.5) / m
	end
	return out
end

function Model.catalystPublic(state: State): { [string]: any }?
	local c = state.catalyst
	if not c then
		return nil
	end
	local sector = Tickers.sectors[c.sector]
	return {
		day = Model.relDay(state, c.day),
		sector = c.sector,
		sectorName = if sector then sector.name else c.sector,
		key = c.key,
		odds = c.odds,
		up = c.up,
		down = c.down,
		resolved = c.resolved,
		good = c.good,
		text = NewsText.catalyst(c.key, if c.resolved then (if c.good then "good" else "bad") else "announce", catalystVars(c)),
	}
end

function Model.snapshot(state: State, now: number): { [string]: any }
	local tickers: { { [string]: any } } = {}
	for _, ts in state.tickers do
		local q = Model.quote(state, ts.id) :: Quote
		table.insert(tickers, {
			id = ts.id,
			name = ts.def.name,
			sector = ts.def.sector,
			sectorName = (Tickers.sectors[ts.def.sector] or { name = ts.def.sector }).name,
			quote = q,
			intraday = roundList(ts.intraday, 2),
			daily = table.clone(ts.daily),
			fund = Model.fundamentals(state, ts.id),
			next = nextPublic(state, ts),
			last = lastPublic(state, ts),
		})
	end
	local idx = state.index
	return {
		t = now,
		day = Model.relDay(state),
		phase = Model.phaseAt(state, now),
		k = state.k,
		openTicks = Model.OPEN_TICKS,
		tickers = tickers,
		index = {
			level = math.floor(idx.level * 10 + 0.5) / 10,
			open = math.floor(idx.open * 10 + 0.5) / 10,
			high = math.floor(idx.high * 10 + 0.5) / 10,
			low = math.floor(idx.low * 10 + 0.5) / 10,
			prevClose = idx.prevClose,
			intraday = roundList(idx.intraday, 1),
			daily = table.clone(idx.daily),
		},
		news = Model.news(state, 25),
		calendar = Model.calendar(state),
		event = Model.activeEvent(state),
		catalyst = Model.catalystPublic(state),
	}
end

function Model.tickPayload(state: State, now: number): { [string]: any }
	local ev = state.event
	return {
		t = now,
		d = Model.relDay(state),
		ph = Model.phaseAt(state, now),
		k = if Schedule.phase(now) == "open" and state.phase == "open" then state.k else -1,
		p = Model.priceList(state),
		ix = math.floor(state.index.level * 10 + 0.5) / 10,
		ev = if ev then ev.id else nil,
	}
end

return Model
