--!strict
-- PortfolioService: per-player session state (RUNTIME ONLY, server). A session starts when the profile loads and ends
-- in DataService.ProfileReleasing (leave or shutdown), where the book is closed flat BEFORE the final save.
--
--   Session.states[player] = PState        Session.get(player) -> PState?
--   Session.bookOf(player) -> (book?, data?)   Session.logOf(data) -> Log   Session.replicate(player)
--   Session.prices() / marketOpen() / marketPhase() / indexLevel()        live market reads (guarded)
--   Session.activeOf(player, data) -> number       active seconds (ActivityService, else the log's own clock)
--   Session.sample(player, data, book, prices, segment)       one equity sample (Logic/Portfolio/Metrics)
--   Session.liveSample(player, data, book) -> Sample?         the "now" sample for window metrics
--   Session.publishRisk(book, risk, now)                       the replicated risk summary
--   Session.refreshLimits(player, force?) -> Limits?           cached 5 s; tighter limits grant extra grace
--   Session.withFlow(player, fn) -> any                        a flow between two samples in different segments
--   Session.onLoaded(player, data)   Session.flatten(player, data, reason) -> n   Session.onReleasing(player, data)

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Time = require(Shared.Util.Time)
local Format = require(Shared.Util.Format)
local Tickers = require(Shared.Config.Tickers)
local Ledger = require(Shared.Logic.Portfolio.Ledger)
local Desk = require(Shared.Logic.Portfolio.Desk)
local Risk = require(Shared.Logic.Portfolio.Risk)
local Metrics = require(Shared.Logic.Portfolio.Metrics)
local Txn = require(Shared.Logic.Portfolio.Txn)
local Deps = require(script.Parent.Parent.MarketService.Deps)

export type PState = {
	player: Player,
	cache: Txn.Cache,
	risk: Risk.State,
	limits: Ledger.Limits,
	limitsAt: number,
	segment: number,
	lastSample: number,
	lastLive: number,
	clockStart: number,
	lastMetrics: { at: number, from: number, to: number, m: Metrics.Window }?,
}

local Session = {}

Session.KEY = "portfolio"
Session.SAMPLE_EVERY = 10 -- seconds between equity samples
Session.LIVE_EVERY = 60 -- LiveInvested leaderboard cadence
Session.LIMITS_EVERY = 5 -- seconds a computed limit set stays fresh

local states: { [Player]: PState } = {}
Session.states = states

function Session.get(player: Player): PState?
	return states[player]
end

---------------------------------------------------------------------------------------------------
-- Market reads
---------------------------------------------------------------------------------------------------
function Session.prices(): { [string]: number }
	local ok, p = Deps.call("MarketService", "GetPrices")
	return if ok and type(p) == "table" then p else {}
end

function Session.marketOpen(): boolean
	local ok, open = Deps.call("MarketService", "IsOpen")
	return ok and open == true
end

function Session.marketPhase(): string
	local ok, phase = Deps.call("MarketService", "GetPhase")
	return if ok and type(phase) == "string" then phase else "closed"
end

function Session.indexLevel(): number
	local ok, v = Deps.call("MarketService", "GetIndex")
	return if ok and type(v) == "number" and v > 0 then v else 1
end

---------------------------------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------------------------------
function Session.bookOf(player: Player): (Ledger.Book?, { [string]: any }?)
	local data = Deps.data(player)
	if not data or type(data.portfolio) ~= "table" then
		return nil, data
	end
	return data.portfolio, data
end

function Session.logOf(data: { [string]: any }): Metrics.Log
	local log = data.portfolioLog
	if type(log) ~= "table" then
		log = Metrics.newLog()
		data.portfolioLog = log
	end
	return log :: Metrics.Log
end

function Session.replicate(player: Player)
	Deps.replicate(player, Session.KEY)
end

function Session.activeOf(player: Player, data: { [string]: any }): number
	local a = Deps.active(player)
	if a then
		return math.floor(a)
	end
	local log = Session.logOf(data)
	local ps = states[player]
	local session = if ps then os.clock() - ps.clockStart else 0
	return math.floor(log.clock + session)
end

function Session.sample(
	player: Player,
	data: { [string]: any },
	book: Ledger.Book,
	p: { [string]: number },
	segment: number
)
	Metrics.sample(Session.logOf(data), {
		a = Session.activeOf(player, data),
		e = math.floor(Ledger.equity(book, p) * 100 + 0.5) / 100,
		b = math.floor(Session.indexLevel() * 100 + 0.5) / 100,
		g = segment,
		n = Ledger.num(book.tradeCount, 0),
		v = Ledger.num(book.violations, 0),
	})
end

function Session.liveSample(player: Player, data: { [string]: any }, book: Ledger.Book): Metrics.Sample?
	local ps = states[player]
	if not ps then
		return nil
	end
	return {
		a = Session.activeOf(player, data),
		e = Ledger.equity(book, Session.prices()),
		b = Session.indexLevel(),
		g = ps.segment,
		n = Ledger.num(book.tradeCount, 0),
		v = Ledger.num(book.violations, 0),
	}
end

function Session.publishRisk(book: Ledger.Book, risk: Risk.State, now: number)
	local pub = Risk.public(risk, now)
	book.risk = { weekViolations = pub.weekViolations, breaches = pub.breaches, max = pub.max }
end

function Session.money(n: number): string
	return Format.money(n, 0)
end

---------------------------------------------------------------------------------------------------
-- Limits
---------------------------------------------------------------------------------------------------
local function computeLimits(player: Player, data: { [string]: any }?): Ledger.Limits
	return Ledger.limits({
		rank = Deps.rank(player),
		mult = Deps.riskMult(player),
		headroom = Deps.riskHeadroom(player, data),
	})
end

function Session.refreshLimits(player: Player, force: boolean?): Ledger.Limits?
	local ps = states[player]
	local book, data = Session.bookOf(player)
	if not ps or not book then
		return nil
	end
	local now = os.clock()
	if not force and now - ps.limitsAt < Session.LIMITS_EVERY then
		return ps.limits
	end
	local old = ps.limits
	local fresh = computeLimits(player, data)
	ps.limits = fresh
	ps.limitsAt = now
	local changed = old.concentration ~= fresh.concentration
		or old.gross ~= fresh.gross
		or old.short ~= fresh.short
		or old.margin ~= fresh.margin
	if changed then
		if fresh.concentration < old.concentration or fresh.gross < old.gross or (old.short and not fresh.short) then
			Risk.grace(ps.risk, Time.now(), Risk.LIMIT_CUT_GRACE)
			if fresh.mult < 1 and old.mult >= 1 then
				Deps.notify(player, Tickers.text("limits_cut", { mult = fresh.mult }), "warn")
			end
		end
		book.limits = table.clone(fresh)
		Session.replicate(player)
	end
	return fresh
end

---------------------------------------------------------------------------------------------------
-- Flows
---------------------------------------------------------------------------------------------------
-- Runs fn(book, prices, now) between a sample in the current segment and one in a new segment, so the flow never
-- counts as a return. Returns fn's result (nil when the book isn't loaded).
function Session.withFlow(player: Player, fn: (book: Ledger.Book, p: { [string]: number }, now: number) -> any): any
	local book, data = Session.bookOf(player)
	if not book or not data then
		return nil
	end
	local now = Time.now()
	local p = Session.prices()
	local ps = states[player]
	local log = Session.logOf(data)
	if ps then
		Session.sample(player, data, book, p, ps.segment)
	end
	local result = fn(book, p, now)
	local seg = Metrics.newSegment(log)
	if ps then
		ps.segment = seg
		Session.sample(player, data, book, p, seg)
	end
	Session.replicate(player)
	return result
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function Session.onLoaded(player: Player, data: { [string]: any })
	if player.Parent ~= Players or states[player] then
		return
	end
	local now = Time.now()
	local book = Ledger.normalize(data.portfolio)
	data.portfolio = book
	local log = Metrics.normalize(data.portfolioLog)
	data.portfolioLog = log
	-- desk policy: books end each session flat; one left open by a crashed server closes at cost (no P/L)
	local hadPositions = next(book.positions) ~= nil
	if hadPositions then
		Desk.restore(book, now)
	end
	book.stops = {}
	if book.paper and Ledger.num(book.bookSize, 0) <= 0 then
		Ledger.setBookSize(book, Ledger.STUDENT_BOOK, "paper", {}, now)
	end
	local risk = Risk.new()
	risk.weekViolations = math.floor(Ledger.num(if type(book.risk) == "table" then book.risk.weekViolations else 0, 0))
	risk.total = math.floor(Ledger.num(book.violations, 0))
	local ps: PState = {
		player = player,
		cache = Txn.new(),
		risk = risk,
		limits = computeLimits(player, data),
		limitsAt = os.clock(),
		segment = Metrics.newSegment(log),
		lastSample = os.clock(),
		lastLive = -math.huge,
		clockStart = os.clock(),
		lastMetrics = nil,
	}
	states[player] = ps
	book.limits = table.clone(ps.limits)
	book.sessionStart = Ledger.equity(book, {})
	Ledger.updatePeak(book, book.sessionStart)
	Session.publishRisk(book, risk, now)
	if log.weekFrom < 0 then
		log.weekFrom = Deps.weekStart(player) or Session.activeOf(player, data)
	end
	Session.sample(player, data, book, Session.prices(), ps.segment)
	Session.replicate(player)
	if hadPositions then
		Deps.notify(player, Tickers.text("session_flat"), "info")
	end
end

-- Closes every position at mid. Never yields: it runs inside DataService.ProfileReleasing right before the save.
function Session.flatten(player: Player, data: { [string]: any }, reason: string): number
	local book = data.portfolio
	if type(book) ~= "table" or type(book.positions) ~= "table" or next(book.positions) == nil then
		return 0
	end
	local p = Session.prices()
	local trades = Ledger.flatten(book, p, Time.now(), reason)
	local ps = states[player]
	Session.sample(player, data, book, p, if ps then ps.segment else Session.logOf(data).seg)
	return #trades
end

function Session.onReleasing(player: Player, data: { [string]: any })
	local ok, err = pcall(function()
		Session.flatten(player, data, "leave")
	end)
	if not ok then
		warn("[PortfolioService] flatten on leave failed: " .. tostring(err))
	end
	local ps = states[player]
	if ps then
		if not Deps.active(player) then
			local log = Session.logOf(data)
			log.clock += os.clock() - ps.clockStart
		end
		if type(data.portfolio) == "table" then
			Session.publishRisk(data.portfolio, ps.risk, Time.now())
		end
	end
	states[player] = nil
	Deps.submitBoard(player, "LiveInvested", 0)
end

return Session
