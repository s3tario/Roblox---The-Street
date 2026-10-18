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
-- shocks. Earnings and catalysts live in Logic/Market/Earnings, event overlays in Logic/Market/Events, the read-only
-- views in Logic/Market/Read (re-exported below), opening state in Logic/Market/Setup, shared helpers and constants
-- in Logic/Market/Core. Prices never go
-- below MIN_PRICE.
--
--   Model.new(seed, now) -> State
--   Model.step(state, now) -> { Out }        advance to `now`; Out = {kind = "news"|"earnings"|"phase"|"day"|
--                                            "event_start"|"event_end"|"catalyst", ...}
--   Model.trigger(state, id, params?, now) -> (ok, err?)     err "unknown_event" | "busy"
--   Model.stopEvent(state, now) -> boolean   Model.activeEvent(state) -> {id, startsAt, endsAt, params, data}?
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
local Core = require(script.Parent.Core)
local Schedule = require(script.Parent.Schedule)
local Events = require(script.Parent.Events)
local Earnings = require(script.Parent.Earnings)
local Read = require(script.Parent.Read)
local Setup = require(script.Parent.Setup)
local NewsText = require(script.Parent.News)
local Tickers = require(script.Parent.Parent.Parent.Config.Tickers)
local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Time = require(script.Parent.Parent.Parent.Util.Time)

export type State = Types.State
export type TickerState = Types.TickerState
export type NewsItem = Types.NewsItem
export type EventState = Types.EventState
export type Quote = Read.Quote

local Model = {}

-- tuning (Logic/Market/Core)
Model.TICK = Core.TICK
Model.OPEN_TICKS = Core.OPEN_TICKS
Model.HISTORY_DAYS = Core.HISTORY_DAYS
Model.NEWS_MAX = Core.NEWS_MAX
Model.MIN_PRICE = Core.MIN_PRICE
Model.HALF_LIFE_DAYS = Core.HALF_LIFE_DAYS
Model.MAX_CATCHUP = Core.MAX_CATCHUP
Model.CATALYST_CHANCE = Core.CATALYST_CHANCE
Model.CATALYST_TICK = Core.CATALYST_TICK
Model.SPREAD = Core.SPREAD
Model.BIG_MOVE = Core.BIG_MOVE
Model.SURPRISE_SD = Core.SURPRISE_SD
Model.SURPRISE_BIAS = Core.SURPRISE_BIAS
Model.MAX_REACTION = Core.MAX_REACTION

-- read-only views (Logic/Market/Read)
Model.relDay = Core.relDay
Model.addNews = Core.addNews
Model.isHoliday = Read.isHoliday
Model.isOpen = Read.isOpen
Model.phaseAt = Read.phaseAt
Model.price = Read.price
Model.prices = Read.prices
Model.priceList = Read.priceList
Model.indexLevel = Read.indexLevel
Model.quote = Read.quote
Model.fundamentals = Read.fundamentals
Model.facts = Read.facts
Model.research = Read.research
Model.calendar = Read.calendar
Model.news = Read.news
Model.activeEvent = Read.activeEvent
Model.catalystPublic = Read.catalystPublic
Model.snapshot = Read.snapshot
Model.tickPayload = Read.tickPayload

local round2 = Core.round2
local push = Core.push
local emit = Core.emit
local addNews = Core.addNews
local KAPPA = Core.KAPPA
local SQRT_TICKS = Core.SQRT_TICKS
local OPEN_TICKS = Core.OPEN_TICKS
local HISTORY_DAYS = Core.HISTORY_DAYS

---------------------------------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------------------------------
function Model.new(seed: number, now: number): State
	local day, into = Time.dayIndex(now)
	local openNow = into < Time.OPEN_LEN
	local k = if openNow then math.floor(into / Time.TICK) else -1
	local state: State = {
		seed = seed,
		rng = Rng.new(seed),
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
		local ts = Setup.newTicker(state, def, openNow, k)
		table.insert(state.tickers, ts)
		state.byId[def.id] = ts
	end
	Setup.initIndex(state, openNow)
	-- earnings: today's report still counts while today's close hasn't happened
	for _, ts in state.tickers do
		Earnings.schedule(state, ts, if openNow then day else day + 1)
	end
	return state
end

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------
local function endEvent(state: State, now: number, reason: string)
	local ev = state.event
	if not ev then
		return
	end
	state.event = nil
	emit(state, { kind = "event_end", id = ev.id, at = now, reason = reason })
end

-- Keeps only plain values from caller params (EventService may pass anything).
local function cleanParams(params: { [string]: any }?): { [string]: any }
	local p: { [string]: any } = {}
	if type(params) ~= "table" then
		return p
	end
	for k, v in params do
		local tv = type(v)
		if type(k) == "string" and (tv == "number" or tv == "string" or tv == "boolean") then
			if tv ~= "number" or (v == v and v ~= math.huge and v ~= -math.huge) then
				p[k] = v
			end
		elseif type(k) == "string" and tv == "table" then
			local list: { any } = {}
			for _, x in v :: { any } do
				if type(x) == "string" or (type(x) == "number" and x == x) then
					table.insert(list, x)
				end
			end
			p[k] = list
		end
	end
	return p
end

function Model.trigger(state: State, id: string, params: { [string]: any }?, now: number): (boolean, string?)
	local def = Events.get(id)
	if not def then
		return false, "unknown_event"
	end
	local p = cleanParams(params)
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
	def.start(state, ev, Core.kitFor(state, now))
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
	emit(state, { kind = "event_start", event = Read.activeEvent(state) })
	if def.closes and state.phase ~= "closed" then
		state.phase = "closed"
		emit(state, { kind = "phase", phase = "closed", at = now })
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
		ts.price = math.max(Core.MIN_PRICE, ts.price * math.exp(gap))
		ts.open = ts.price
		ts.high = ts.price
		ts.low = ts.price
		ts.intraday = {}
		ts.fv *= math.exp(ts.def.growth / Tickers.EARNINGS_EVERY + state.rng:normal(0, 0.004))
		ts.target = ts.fv * math.exp(state.rng:normal(0, 0.05))
		ts.dps = ts.def.dividendYield * ts.fv
		if not ts.next.published and ts.next.day - day <= Tickers.CONSENSUS_LEAD then
			Earnings.publishConsensus(state, ts, now)
		end
	end
	local idx = state.index
	idx.prevClose = idx.close
	idx.level = Core.computeIndex(state)
	idx.open = idx.level
	idx.high = idx.level
	idx.low = idx.level
	idx.intraday = {}
	local c = state.catalyst
	if c and not c.resolved and c.day < day then
		c.day = day -- missed (holiday): resolves today instead
	end
	if (not c or c.resolved) and state.rng:next() < Core.CATALYST_CHANCE then
		Earnings.scheduleCatalyst(state, day + 1, now)
	end
	emit(state, { kind = "day", day = day, rel = Core.relDay(state, day), at = now })
end

local function closingNews(state: State, now: number)
	local best: { { id: string, pct: number } } = {}
	for _, ts in state.tickers do
		ts.close = ts.price
		push(ts.daily, round2(ts.price), HISTORY_DAYS)
		table.insert(best, { id = ts.id, pct = if ts.prevClose > 0 then ts.price / ts.prevClose - 1 else 0 })
	end
	local idx = state.index
	idx.close = idx.level
	push(idx.daily, math.floor(idx.level * 10 + 0.5) / 10, HISTORY_DAYS)
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
		if math.abs(entry.pct) >= Core.BIG_MOVE then
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

local function onClose(state: State, day: number, now: number, closed: boolean)
	if state.openedDay == day then
		closingNews(state, now)
	end
	for _, ts in state.tickers do
		if ts.next.day <= day then
			if closed then
				ts.next.day = day + 1 -- the exchange is shut: the report waits for the next close
			else
				Earnings.release(state, ts, day, now)
			end
		end
	end
end

type Drift = { move: { [string]: number }, fv: { [string]: number }, noMR: { [string]: boolean } }

-- Applies one open tick of every running impulse; returns the per-ticker log moves.
local function impulseDrift(state: State): Drift
	local out: Drift = { move = {}, fv = {}, noMR = {} }
	if #state.impulses == 0 then
		return out
	end
	local avgBeta = Core.capWeightedBeta(state)
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
					out.move[ts.id] = (out.move[ts.id] or 0) + move
					out.fv[ts.id] = (out.fv[ts.id] or 0) + move * imp.fvShare
					if imp.noMR then
						out.noMR[ts.id] = true
					end
				end
			end
			imp.left -= 1
			if imp.left <= 0 then
				table.remove(state.impulses, i)
			end
		end
	end
	return out
end

local function recordIndex(state: State, k: number)
	local idx = state.index
	idx.level = Core.computeIndex(state)
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
			def.tick(state, ev, Core.kitFor(state, now))
		end
	end
	local vm, tvm = Events.vol(state, state.event)
	local u = Schedule.uShape(k / (OPEN_TICKS - 1)) * vm
	local market = Tickers.MARKET_VOL / SQRT_TICKS * u * rng:normal()
	local sectors: { [string]: number } = {}
	for _, id in Core.SECTOR_IDS do
		sectors[id] = Tickers.sectors[id].vol / SQRT_TICKS * u * rng:normal()
	end
	local drift = impulseDrift(state)

	for _, ts in state.tickers do
		local def = ts.def
		local mr = if drift.noMR[ts.id] then 0 else KAPPA * math.log(ts.fv / ts.price)
		local tickerMult = if tvm and tvm[ts.id] then tvm[ts.id] else 1
		local idio = def.vol / SQRT_TICKS * u * tickerMult * rng:normal()
		local lnr = mr + def.beta * market + (sectors[def.sector] or 0) + idio + (drift.move[ts.id] or 0)
		ts.price = math.max(Core.MIN_PRICE, ts.price * math.exp(lnr))
		local fd = drift.fv[ts.id]
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
	recordIndex(state, k)

	local c = state.catalyst
	if c and not c.resolved and c.day == state.day and k >= Core.CATALYST_TICK then
		Earnings.resolveCatalyst(state, c, now)
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
	local closed = Read.isHoliday(state, t)
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
	if (target - state.tickT) / Time.TICK > Core.MAX_CATCHUP then
		state.tickT = target - Core.MAX_CATCHUP * Time.TICK
	end
	while state.tickT + Time.TICK <= target do
		state.tickT += Time.TICK
		processTick(state, state.tickT)
	end
	local out = state.outbox
	state.outbox = {}
	return out
end

return Model
