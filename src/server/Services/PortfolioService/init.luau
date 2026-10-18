--!strict
-- PortfolioService (server, owned by `market`, Priority 12; contracts §3 and §6, design v3 §11, spec §6-§7): session
-- trading books.
--
-- Data: `portfolio` (replicated; Shared/Logic/Portfolio/Ledger) and `portfolioLog` (private equity samples).
-- Rules live in Shared/Logic/Portfolio (Ledger, Orders, Risk, Metrics, Desk); this service validates, calls them,
-- persists, replicates and notifies. Session.luau holds per-player state, Tick.luau the per-tick processing,
-- Remotes.luau the client remotes.
--   * Market orders, open session only, 0.05% spread, idempotent by client transaction id (Portfolio.Trade).
--   * Limits by rank (40% single name / 100% gross for students, interns and analysts; 50% / 150% with shorting from
--     Associate), times CareerService:GetRiskLimitMultiplier (probation 0.6), plus Risk Sense headroom
--     (careerCore Logic/Stats.riskHeadroom). Optional stop-loss / take-profit per position.
--   * Breaches from market moves: warning -> violation + desk trim -> the third violation in a week is major
--     (RiskViolation with major = true). ReviewService turns violations into consequences.
--   * Desk policy: the session ends flat. Positions close at mid on DataService.ProfileReleasing (leave and
--     BindToClose) before the final save; a book left open by a crashed server closes at cost on the next load.
--   * Equity samples keyed by ACTIVE seconds (ActivityService) chain per-session returns with the STREET 10 over the
--     same intervals: GetWindowMetrics(fromActive, toActive). Flows (top-ups, wipeouts, paid capital) never count.
--   * Live invested (gross market value) goes to LeaderboardService "LiveInvested" every 60 s while online, 0 on
--     leave. Each completed review records the week; the season's Market Skill goes to "MarketSkill".
--   * Students trade a $5,000 paper account; the first job replaces it with the real book.
--
-- API (contracts §6, plus extras)
--   PortfolioService.Traded : Signal(player, trade)            player orders, stops and take-profits
--   PortfolioService.RiskViolation : Signal(player, info)      info = {kind, ticker?, value, limit, count, major,
--                                                               severity = "violation" | "major"}
--   :GetEquity(player) -> number    :GetInvested(player) -> number    :GetSummary(player) -> {...}?
--   :GetWindowMetrics(player, fromActive, toActive) -> {twr, benchReturn, excess, maxDrawdown, volatility, trades,
--       violations, active, sessions}
--   :SetBookSize(player, size, reason) -> flow     :WipeBook(player) -> lost equity     :GrantCapitalCredit(player)
--   :UseCapitalCredit(player, lostBook?) -> amount | false, err?      :FlattenAll(player, reason?) -> closed count
--   :GetSeasonSkill(player) -> number?   :GetLimits(player) -> Limits?   :ResetForRebirth(player)
--   :Trade(player, order, txnId) -> (ok, err?, payload?)   :SetStops(player, ticker, stop?, take?) -> (ok, err?)
--   :GetPanel(player) -> { week, curve, skill, summary, limits }?     :IsInSession(player) -> boolean

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Time = require(Shared.Util.Time)
local Tickers = require(Shared.Config.Tickers)
local Ledger = require(Shared.Logic.Portfolio.Ledger)
local Desk = require(Shared.Logic.Portfolio.Desk)
local Risk = require(Shared.Logic.Portfolio.Risk)
local Metrics = require(Shared.Logic.Portfolio.Metrics)
local Txn = require(Shared.Logic.Portfolio.Txn)
local Deps = require(script.Parent.MarketService.Deps)
local Session = require(script.Session)
local Tick = require(script.Tick)
local Remotes = require(script.Remotes)

local PortfolioService = {
	Name = "PortfolioService",
	Priority = 12,
	Traded = Signal.new(),
	RiskViolation = Signal.new(),
}

PortfolioService.Session = Session

local METRICS_CACHE = 120 -- a review's window metrics are reused when its ReviewCompleted arrives
local states = Session.states
local bookOf = Session.bookOf
local logOf = Session.logOf
local replicate = Session.replicate
local prices = Session.prices

---------------------------------------------------------------------------------------------------
-- Trading API
---------------------------------------------------------------------------------------------------
function PortfolioService:Trade(player: Player, order: Desk.Order, txnId: string): (boolean, string?, { [string]: any }?)
	local ps = states[player]
	local book = bookOf(player)
	if not ps or not book then
		return false, "not_loaded", nil
	end
	local p = prices()
	local open = Session.marketOpen()
	local limits = Session.refreshLimits(player, true) or ps.limits
	local result, replayed = Desk.submit(ps.cache, txnId, book, p, order, limits, Time.now(), open)
	if not result.ok then
		local err = result.err or "generic"
		if err == "closed" and Session.marketPhase() == "closed" then
			err = "holiday"
		end
		return false, err, { vars = Desk.errorVars(result, limits) }
	end
	local trade = result.trade :: Ledger.Trade
	if not replayed then
		Ledger.updatePeak(book, Ledger.equity(book, p))
		Session.publishRisk(book, ps.risk, Time.now())
		replicate(player)
		PortfolioService.Traded:Fire(player, table.clone(trade))
	end
	return true, nil, { trade = trade, summary = Ledger.summary(book, p), replayed = replayed }
end

function PortfolioService:SetStops(player: Player, ticker: string, stop: number?, take: number?): (boolean, string?)
	local book = bookOf(player)
	if not book or not states[player] then
		return false, "not_loaded"
	end
	local ok, err = Desk.setStops(book, prices(), ticker, stop, take)
	if ok then
		replicate(player)
	end
	return ok, err
end

-- Closes every position at mid ("Flatten all" in the Terminal; the leave/shutdown path calls Session.flatten).
function PortfolioService:FlattenAll(player: Player, reason: string?): number
	local data = Deps.data(player)
	if not data then
		return 0
	end
	local n = Session.flatten(player, data, reason or "flatten")
	if n > 0 then
		replicate(player)
	end
	return n
end

---------------------------------------------------------------------------------------------------
-- Reading API
---------------------------------------------------------------------------------------------------
function PortfolioService:GetEquity(player: Player): number
	local book = bookOf(player)
	return if book then Ledger.equity(book, prices()) else 0
end

function PortfolioService:GetInvested(player: Player): number
	local book = bookOf(player)
	if not book or not states[player] then
		return 0 -- offline books are flat
	end
	return Ledger.invested(book, prices())
end

function PortfolioService:GetSummary(player: Player): { [string]: number }?
	local book = bookOf(player)
	return if book then Ledger.summary(book, prices()) else nil
end

function PortfolioService:GetLimits(player: Player): Ledger.Limits?
	if not states[player] then
		return nil
	end
	return Session.refreshLimits(player)
end

function PortfolioService:IsInSession(player: Player): boolean
	return states[player] ~= nil
end

function PortfolioService:GetWindowMetrics(player: Player, fromActive: number, toActive: number): { [string]: number }
	local book, data = bookOf(player)
	local empty = {
		twr = 0,
		benchReturn = 0,
		excess = 0,
		maxDrawdown = 0,
		volatility = 0,
		trades = 0,
		violations = 0,
		active = 0,
		sessions = 0,
	}
	if not book or not data then
		return empty
	end
	local from = Ledger.num(fromActive, 0)
	local to = math.max(from, Ledger.num(toActive, from))
	local live = Session.liveSample(player, data, book)
	if live and live.a > to then
		live = nil -- the window ended before now
	end
	local w = Metrics.window(logOf(data).samples, from, to, live)
	local ps = states[player]
	if ps then
		ps.lastMetrics = { at = os.clock(), from = from, to = to, m = w }
	end
	return {
		twr = w.twr,
		benchReturn = w.benchReturn,
		excess = w.excess,
		maxDrawdown = w.maxDrawdown,
		volatility = w.volatility,
		trades = w.trades,
		violations = w.violations,
		active = w.active,
		sessions = w.sessions,
	}
end

function PortfolioService:GetSeasonSkill(player: Player): number?
	local book = bookOf(player)
	if not book then
		return nil
	end
	return Metrics.seasonSkill(book.weekReturns, Time.season(Time.now()))
end

-- The Terminal's account panel: this review window, this session's equity curve and the season skill.
function PortfolioService:GetPanel(player: Player): { [string]: any }?
	local book, data = bookOf(player)
	local ps = states[player]
	if not book or not data or not ps then
		return nil
	end
	local active = Session.activeOf(player, data)
	local from = Deps.weekStart(player) or logOf(data).weekFrom
	local week = self:GetWindowMetrics(player, math.min(from, active), active)
	return {
		week = week,
		curve = Metrics.series(logOf(data).samples, ps.segment, 60),
		skill = self:GetSeasonSkill(player),
		summary = Ledger.summary(book, prices()),
		limits = table.clone(ps.limits),
	}
end

---------------------------------------------------------------------------------------------------
-- Flows (careerPath, monetization, careerCore)
---------------------------------------------------------------------------------------------------
function PortfolioService:SetBookSize(player: Player, size: number, reason: string?): number
	local target = math.max(0, math.floor(Ledger.num(size, 0)))
	local why = if type(reason) == "string" then reason else "set"
	local flow = Session.withFlow(player, function(book, p, now)
		return Ledger.setBookSize(book, target, why, p, now)
	end)
	if type(flow) ~= "number" then
		return 0
	end
	Deps.audit(player, "book_size", { size = target, reason = why, flow = math.floor(flow) })
	if flow ~= 0 then
		Deps.notify(player, Tickers.text("book_topped", { amount = Session.money(target) }), "good")
	end
	Session.refreshLimits(player, true)
	return flow
end

function PortfolioService:WipeBook(player: Player): number
	local outcome = Session.withFlow(player, function(book, p, now)
		local lost, newBook = Ledger.wipe(book, p, now)
		return { lost = lost, book = newBook }
	end)
	if type(outcome) ~= "table" then
		return 0
	end
	local ps = states[player]
	local book = bookOf(player)
	if ps then
		ps.risk = Risk.new()
		if book then
			Session.publishRisk(book, ps.risk, Time.now())
		end
	end
	Deps.audit(player, "book_wipe", { lost = math.floor(outcome.lost), book = outcome.book })
	Deps.notify(player, Tickers.text("book_wiped", { amount = Session.money(outcome.book) }), "warn")
	replicate(player)
	return outcome.lost
end

function PortfolioService:GrantCapitalCredit(player: Player)
	local book = bookOf(player)
	if not book then
		return
	end
	book.credits.capital = Ledger.num(book.credits.capital, 0) + 1
	Deps.audit(player, "capital_credit", { credits = book.credits.capital })
	Deps.notify(player, Tickers.text("capital_credit"), "good")
	replicate(player)
end

-- Capital Reconstruction: 50% of the lost book (capped at $250,000) as flagged paid capital. Returns the amount, or
-- false and an error key ("no_credit" | "nothing_lost" | "used" | "not_loaded").
function PortfolioService:UseCapitalCredit(player: Player, lostBook: number?): (number | boolean, string?)
	if not bookOf(player) then
		return false, "not_loaded"
	end
	local outcome = Session.withFlow(player, function(b, _p, now)
		local amount, err = Ledger.restoreCapital(b, lostBook, now)
		return { amount = amount, err = err }
	end)
	if type(outcome) ~= "table" or not outcome.amount then
		return false, if type(outcome) == "table" then outcome.err else "not_loaded"
	end
	Deps.audit(player, "capital_restored", { amount = outcome.amount, paid = true })
	Deps.notify(player, Tickers.text("capital_restored", { amount = Session.money(outcome.amount) }), "good")
	return outcome.amount, nil
end

function PortfolioService:ResetForRebirth(player: Player)
	local data = Deps.data(player)
	Session.withFlow(player, function(book, p, now)
		Ledger.resetForRebirth(book, p, now)
		return true
	end)
	local ps = states[player]
	if ps then
		ps.risk = Risk.new()
		ps.cache = Txn.new()
	end
	if data then
		logOf(data).weekFrom = Session.activeOf(player, data)
		local book = data.portfolio
		if type(book) == "table" then
			book.sessionStart = Ledger.equity(book, {})
			if ps then
				Session.publishRisk(book, ps.risk, Time.now())
			end
		end
	end
	Session.refreshLimits(player, true)
	replicate(player)
end

---------------------------------------------------------------------------------------------------
-- Weekly records (CareerService.ReviewCompleted)
---------------------------------------------------------------------------------------------------
local function onReviewCompleted(player: Player, review: any)
	local book, data = bookOf(player)
	local ps = states[player]
	if not book or not data then
		return
	end
	local log = logOf(data)
	local active = Session.activeOf(player, data)
	local m: { [string]: number }
	local cached = if ps then ps.lastMetrics else nil
	if cached and os.clock() - cached.at < METRICS_CACHE then
		m = {
			twr = cached.m.twr,
			benchReturn = cached.m.benchReturn,
			excess = cached.m.excess,
			maxDrawdown = cached.m.maxDrawdown,
			volatility = cached.m.volatility,
			trades = cached.m.trades,
		}
	else
		m = PortfolioService:GetWindowMetrics(player, math.min(log.weekFrom, active), active)
	end
	local now = Time.now()
	local function r5(x: number): number
		return math.floor(x * 1e5 + 0.5) / 1e5
	end
	Metrics.recordWeek(book.weekReturns, {
		s = Time.season(now),
		w = if type(review) == "table" and type(review.week) == "number" then review.week else 0,
		at = now,
		twr = r5(m.twr),
		bench = r5(m.benchReturn),
		excess = r5(m.excess),
		dd = r5(m.maxDrawdown),
		vol = r5(m.volatility),
		trades = m.trades,
	})
	log.weekFrom = active
	if ps then
		Risk.resetWeek(ps.risk)
		ps.lastMetrics = nil
		Session.publishRisk(book, ps.risk, now)
	end
	replicate(player)
	local skill = Metrics.seasonSkill(book.weekReturns, Time.season(now))
	if skill then
		Deps.submitBoard(player, "MarketSkill", skill)
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function PortfolioService:Init()
	Remotes.bind(PortfolioService)
	Deps.connect("DataService", "ProfileLoaded", function(player: Player, data: any)
		if type(data) == "table" then
			Session.onLoaded(player, data)
		end
	end)
	Deps.connect("DataService", "ProfileReleasing", function(player: Player, data: any)
		if type(data) == "table" then
			Session.onReleasing(player, data)
		end
	end)
end

function PortfolioService:Start()
	local market = Deps.service("MarketService")
	if market and market.Tick then
		market.Tick:Connect(function(now: number, p: { [string]: number })
			Tick.process(PortfolioService, now, p)
		end)
	else
		warn("[PortfolioService] MarketService missing: books can't trade")
	end
	for _, player in Players:GetPlayers() do
		local data = Deps.data(player)
		if data and not states[player] then
			task.spawn(Session.onLoaded, player, data)
		end
	end
	Deps.connect("CareerService", "RoleChanged", function(player: Player)
		local ps = states[player]
		if ps then
			Risk.resetWeek(ps.risk)
			Session.refreshLimits(player, true)
		end
	end)
	Deps.connect("CareerService", "StatusChanged", function(player: Player)
		Session.refreshLimits(player, true)
	end)
	Deps.connect("CareerService", "ReviewCompleted", onReviewCompleted)
	Deps.connect("ProfileService", "ProfileLocked", function(player: Player)
		Session.refreshLimits(player, true)
	end)
	-- without DataService there's nothing to save, but never keep a session for a player who left
	Players.PlayerRemoving:Connect(function(player: Player)
		task.defer(function()
			if states[player] and not Deps.has("DataService", "Get") then
				states[player] = nil
			end
		end)
	end)
end

return PortfolioService
