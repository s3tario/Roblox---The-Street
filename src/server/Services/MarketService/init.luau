--!strict
-- MarketService (server, owned by `market`, Priority 10; contracts §6, design v3 §11, spec §7): the per-server
-- fictional market. Seeds Shared/Logic/Market/Model from a random server seed in Init (so every other service can
-- read prices from its own Init/Start), steps it on 2-second ticks aligned to server time, and broadcasts.
--
-- Broadcasts
--   "Market.Tick"   (unreliable, every 2 s)   { t, d, ph, k, p = {prices in Tickers.IDS order}, ix, ev? }
--   "Market.News"   (reliable)                one news item as it posts
--   "Market.Open"   (reliable, one player)    { mode = "trade" | "news", source } after a terminal / news stand prompt
--   global "market" (DataService:SetGlobal)  { day, phase, st10, st10Pct, event?, eventName?, at } (light summary)
--   NotifyService:Ticker lines for earnings, catalysts, Fed decisions and the closing bell
--   every "TickerBand" / "TickerDisplay" LED label ("TickerText") rewritten each tick (MarketService/Bands)
-- RemoteFunctions "Market.NewsList"(limit?) -> { item } and "Market.Snapshot"() -> Model.snapshot (quotes, intraday + 30-day history, fundamentals, news,
--   earnings calendar, catalyst, active event). Future prices and hidden values are never sent.
-- Interacts: `terminal` (opens the Terminal) and `news_stand` (opens it read-only). Inside office instances only
--   employees may use them (CareerService:IsEmployeeOf); visitors get a polite toast and a hidden prompt.
--
-- API (contracts §6, plus extras)
--   MarketService.Tick : Signal(now, prices)               every tick, prices = { [ticker] = price }
--   MarketService.NewsPosted : Signal(item)   .EarningsReleased : Signal(ticker, result)   .DayChanged : Signal(day)
--   MarketService.PhaseChanged : Signal(phase)   .EventStarted : Signal(event)   .EventEnded : Signal(eventId)
--   :GetPrice(ticker) -> number?   :GetPrices() -> {[ticker] = price}   :GetQuote(ticker) -> Quote?
--   :GetIndex() -> number          :IsOpen() -> boolean   :GetPhase() -> "open"|"after"|"closed"   :GetDay() -> n
--   :GetCompanyFacts(ticker) -> facts?    :GetAllFacts() -> {[ticker] = facts}
--   :GetResearchSignal(ticker, quality 0..100) -> {direction = "up"|"down", beat, confidence, reportDay, inDays,
--       consensus?}?    honest: right with probability 0.55 + 0.35 * quality / 100, never re-rollable
--   :GetNews(limit?) -> { item }   :GetCalendar() -> { {day, inDays, tickers} }   :GetSnapshot() -> table
--   :TriggerEvent(eventId, params?) -> boolean   :StopEvent() -> boolean
--   :GetActiveEvent() -> {id, startsAt, endsAt, params, data}?
--   :OpenTerminal(player, mode?)   opens the Terminal on that client

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Hash = require(Shared.Util.Hash)
local Time = require(Shared.Util.Time)
local Tickers = require(Shared.Config.Tickers)
local Model = require(Shared.Logic.Market.Model)
local Band = require(Shared.Logic.Market.Band)
local Deps = require(script.Deps)
local Prompts = require(script.Prompts)
local Bands = require(script.Bands)

local MarketService = {
	Name = "MarketService",
	Priority = 10,
	Tick = Signal.new(),
	NewsPosted = Signal.new(),
	EarningsReleased = Signal.new(),
	DayChanged = Signal.new(),
	PhaseChanged = Signal.new(),
	EventStarted = Signal.new(),
	EventEnded = Signal.new(),
}

MarketService.Deps = Deps
MarketService.TICK_REMOTE = "Market.Tick"
MarketService.NEWS_REMOTE = "Market.News"
MarketService.OPEN_REMOTE = "Market.Open"

local GLOBAL_EVERY = 30
local SNAPSHOT_CACHE = 1
local OPEN_COOLDOWN = 0.6
local TICKER_KINDS: { [string]: boolean } = {
	earnings = true,
	catalyst = true,
	close = true,
	fed_hike = true,
	fed_cut = true,
	fed_hold = true,
	reopen = true,
	mover = true,
}

local state: Model.State = nil :: any
local seed = 0
local lastGlobal = -math.huge
local snapshotCache: { at: number, value: { [string]: any } }? = nil
local lastOpen: { [Player]: number } = {}
local running = false

---------------------------------------------------------------------------------------------------
-- Reading API
---------------------------------------------------------------------------------------------------
function MarketService:GetPrice(ticker: string): number?
	if type(ticker) ~= "string" then
		return nil
	end
	return Model.price(state, ticker)
end

function MarketService:GetPrices(): { [string]: number }
	return Model.prices(state)
end

function MarketService:GetQuote(ticker: string): Model.Quote?
	if type(ticker) ~= "string" then
		return nil
	end
	return Model.quote(state, ticker)
end

function MarketService:GetIndex(): number
	return Model.indexLevel(state)
end

function MarketService:IsOpen(): boolean
	return Model.isOpen(state, Time.now())
end

function MarketService:GetPhase(): string
	return Model.phaseAt(state, Time.now())
end

function MarketService:GetDay(): number
	return Model.relDay(state)
end

function MarketService:GetSeed(): number
	return seed
end

function MarketService:GetCompanyFacts(ticker: string): { [string]: any }?
	if type(ticker) ~= "string" then
		return nil
	end
	return Model.facts(state, ticker, Time.now())
end

function MarketService:GetAllFacts(): { [string]: { [string]: any } }
	local out: { [string]: { [string]: any } } = {}
	for _, id in Tickers.IDS do
		local f = Model.facts(state, id, Time.now())
		if f then
			out[id] = f
		end
	end
	return out
end

function MarketService:GetResearchSignal(ticker: string, quality: number?): { [string]: any }?
	if type(ticker) ~= "string" then
		return nil
	end
	return Model.research(state, ticker, quality, Time.now())
end

function MarketService:GetNews(limit: number?): { Model.NewsItem }
	return Model.news(state, limit)
end

function MarketService:GetCalendar(): { { [string]: any } }
	return Model.calendar(state)
end

function MarketService:GetSnapshot(): { [string]: any }
	local now = Time.now()
	local cached = snapshotCache
	if cached and now - cached.at < SNAPSHOT_CACHE then
		return cached.value
	end
	local value = Model.snapshot(state, now)
	value.serverTime = now
	snapshotCache = { at = now, value = value }
	return value
end

function MarketService:GetActiveEvent(): { [string]: any }?
	return Model.activeEvent(state)
end

---------------------------------------------------------------------------------------------------
-- Events (EventService, events feature)
---------------------------------------------------------------------------------------------------
local function publishGlobal(now: number)
	lastGlobal = now
	local idx = state.index
	local ev = state.event
	local info = if ev then Tickers.events[ev.id] else nil
	Deps.setGlobal("market", {
		day = Model.relDay(state),
		phase = Model.phaseAt(state, now),
		st10 = math.floor(idx.level * 10 + 0.5) / 10,
		st10Pct = if idx.prevClose > 0 then math.floor((idx.level / idx.prevClose - 1) * 10000 + 0.5) / 10000 else 0,
		event = if ev then ev.id else nil,
		eventName = if info then info.name else nil,
		eventEndsAt = if ev then ev.endsAt else nil,
		at = now,
	})
end

local function handleOutbox(out: { { [string]: any } }, now: number)
	local globalDirty = false
	for _, o in out do
		local kind = o.kind
		if kind == "news" then
			local item = o.item
			pcall(function()
				Net.fireAll(MarketService.NEWS_REMOTE, item)
			end)
			MarketService.NewsPosted:Fire(item)
			if TICKER_KINDS[item.kind] then
				Deps.ticker(item.headline)
			end
		elseif kind == "earnings" then
			MarketService.EarningsReleased:Fire(o.ticker, o.result)
		elseif kind == "day" then
			MarketService.DayChanged:Fire(o.rel)
			globalDirty = true
		elseif kind == "phase" then
			MarketService.PhaseChanged:Fire(o.phase)
			globalDirty = true
		elseif kind == "event_start" then
			MarketService.EventStarted:Fire(o.event)
			globalDirty = true
		elseif kind == "event_end" then
			MarketService.EventEnded:Fire(o.id)
			globalDirty = true
		end
	end
	if globalDirty then
		snapshotCache = nil
		publishGlobal(now)
	end
end

function MarketService:TriggerEvent(eventId: string, params: { [string]: any }?): boolean
	if type(eventId) ~= "string" then
		return false
	end
	local now = Time.now()
	local ok, err = Model.trigger(state, eventId, params, now)
	if not ok then
		warn(("[MarketService] TriggerEvent(%s) refused: %s"):format(eventId, tostring(err)))
		return false
	end
	local out = state.outbox
	state.outbox = {}
	handleOutbox(out, now)
	return true
end

function MarketService:StopEvent(): boolean
	local now = Time.now()
	local stopped = Model.stopEvent(state, now)
	if stopped then
		local out = state.outbox
		state.outbox = {}
		handleOutbox(out, now)
	end
	return stopped
end

---------------------------------------------------------------------------------------------------
-- Tick loop
---------------------------------------------------------------------------------------------------
local function bandLine(now: number): string
	local quotes: { { id: string, price: number, changePct: number } } = {}
	for _, ts in state.tickers do
		table.insert(quotes, {
			id = ts.id,
			price = ts.price,
			changePct = if ts.prevClose > 0 then ts.price / ts.prevClose - 1 else 0,
		})
	end
	local idx = state.index
	local phase = Model.phaseAt(state, now)
	local phaseText = if phase == "after"
		then Tickers.text("phase_after")
		elseif phase == "closed" then Tickers.text("phase_closed")
		else nil
	return Band.line(
		quotes,
		{ level = idx.level, changePct = if idx.prevClose > 0 then idx.level / idx.prevClose - 1 else 0 },
		phaseText
	)
end

local function stepOnce()
	local now = Time.now()
	local out = Model.step(state, now)
	handleOutbox(out, now)
	snapshotCache = nil
	local payload = Model.tickPayload(state, now)
	local ok, err = pcall(function()
		Net.fireAllUnreliable(MarketService.TICK_REMOTE, payload)
	end)
	if not ok then
		warn("[MarketService] tick broadcast failed: " .. tostring(err))
	end
	MarketService.Tick:Fire(now, Model.prices(state))
	local line = bandLine(now)
	local okBands, errBands = pcall(function()
		Bands.update(line)
	end)
	if not okBands then
		warn("[MarketService] ticker bands failed: " .. tostring(errBands))
	end
	if now - lastGlobal >= GLOBAL_EVERY then
		publishGlobal(now)
	end
end

local function loop()
	if running then
		return
	end
	running = true
	while true do
		local now = Time.now()
		local nextTick = (math.floor(now / Time.TICK) + 1) * Time.TICK
		task.wait(math.max(0.05, nextTick - now + 0.02))
		local ok, err = pcall(function()
			stepOnce()
		end)
		if not ok then
			warn("[MarketService] tick failed: " .. tostring(err))
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Prompts
---------------------------------------------------------------------------------------------------
function MarketService:OpenTerminal(player: Player, mode: string?, source: string?)
	if player.Parent ~= Players then
		return
	end
	local payload = { mode = if mode == "news" then "news" else "trade", source = source or "server" }
	pcall(function()
		Net.fire(MarketService.OPEN_REMOTE, player, payload)
	end)
end

local function onPrompt(mode: string)
	return function(player: Player, _prompt: ProximityPrompt, companyId: string?)
		local now = os.clock()
		if now - (lastOpen[player] or 0) < OPEN_COOLDOWN then
			return
		end
		lastOpen[player] = now
		if companyId and not Deps.isEmployeeOf(player, companyId) then
			local name = Deps.companyName(companyId)
			Deps.notify(
				player,
				if name
					then Tickers.text("employees_only", { company = name })
					else Tickers.text("employees_only_generic"),
				"warn"
			)
			return
		end
		MarketService:OpenTerminal(player, mode, if mode == "news" then "news_stand" else "terminal")
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function MarketService:Init()
	local now = Time.now()
	seed = Hash.u32("market", game.JobId, os.time(), math.floor(os.clock() * 1e6), now)
	state = Model.new(seed, now)
	state.outbox = {}

	Net.declare(MarketService.TICK_REMOTE, "unreliable")
	Net.declare(MarketService.NEWS_REMOTE)
	Net.declare(MarketService.OPEN_REMOTE)
	Net.handle("Market.Snapshot", function(_player: Player): { [string]: any }
		return MarketService:GetSnapshot()
	end, { rate = 1, burst = 5 })
	Net.handle("Market.NewsList", function(_player: Player, limit: any): { Model.NewsItem }
		local n = if type(limit) == "number" and limit == limit then math.clamp(math.floor(limit), 1, 40) else 25
		return MarketService:GetNews(n)
	end, { rate = 1, burst = 4 })
end

function MarketService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		lastOpen[player] = nil
	end)
	Bands.start()
	Prompts.start({
		interactId = "terminal",
		promptName = "TerminalPrompt",
		actionText = Tickers.text("prompt_terminal"),
		objectText = Tickers.text("prompt_terminal_object"),
		onTriggered = onPrompt("trade"),
	})
	Prompts.start({
		interactId = "news_stand",
		promptName = "NewsStandPrompt",
		actionText = Tickers.text("prompt_news"),
		objectText = Tickers.text("prompt_news_object"),
		onTriggered = onPrompt("news"),
	})
	publishGlobal(Time.now())
	loop()
end

return MarketService
