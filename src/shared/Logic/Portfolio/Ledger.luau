--!strict
-- The trading book ledger (owned by `market`; spec §7, design v3 §11, contracts §3 and §6). PURE: callers pass prices
-- and times. Shared by PortfolioService (the only writer) and the Terminal (previews only).
--
-- Book (data.portfolio): cash, positions = { [ticker] = {shares, avgCost} } (negative shares = short), bookSize,
-- realized, trades (ring), weekReturns, peak, violations, credits = {capital}, paidCapital, plus paper (the student
-- account), stops, flows, tradeCount, tradeSeq, limits, risk, lastWipe, sessionStart.
--
-- Fills: market orders at mid +- half the 0.05% spread. Equity = cash + sum(shares x price). Invested (live) = the
-- gross market value of open positions. External flows (book top-ups, wipeouts, paid capital) go through flow() so
-- returns stay time-weighted. Flattening at mid is not a flow and doesn't change equity.
--
--   Ledger.new(bookSize?, paper?) -> Book          Ledger.normalize(raw) -> Book (repairs saved data in place)
--   Ledger.limits({rank, mult, headroom}) -> Limits
--   Ledger.equity / invested / gross / net / unrealized (book, prices) -> number
--   Ledger.summary(book, prices) -> { equity, cash, invested, net, unrealized, realized, sessionPnl, drawdown }
--   Ledger.project(book, prices, ticker, delta) -> Projection      the book right after a fill (previews)
--   Ledger.check(book, prices, ticker, delta, limits) -> (ok, err?, Projection?)
--   Ledger.maxDelta(book, prices, ticker, dir, limits) -> integer  largest |delta| in direction dir (+1 buy, -1 sell)
--   Ledger.fill(book, ticker, delta, mid, at, kind, opts?) -> Trade
--   Ledger.flatten(book, prices, at, kind) -> ({ Trade }, realized)   closes everything at mid (no spread)
--   Ledger.flow(book, amount) -> amount           Ledger.setBookSize(book, size, reason, prices, at) -> flow
--   Ledger.wipe(book, prices, at) -> (lost, newBook)   Ledger.restoreCapital(book, lostBook?, at) -> (amount?, err?)
--   Ledger.resetForRebirth(book, prices, at) -> Book

local Tickers = require(script.Parent.Parent.Parent.Config.Tickers)

export type Position = { shares: number, avgCost: number }
export type Stop = { stop: number?, take: number? }
export type Trade = {
	id: number,
	t: number,
	tk: string,
	q: number, -- signed shares (+ buy, - sell)
	px: number, -- fill price
	mid: number,
	fee: number, -- spread paid
	pnl: number, -- realized on this fill
	kind: string, -- "trade" | "stop" | "take" | "trim" | "flatten" | "leave" | "restore" | "wipe" | "rebirth" | "paper"
}
export type Limits = {
	rank: number,
	concentration: number, -- max |position value| / equity
	gross: number, -- max gross exposure / equity
	short: boolean,
	margin: boolean, -- cash may go negative (within the gross limit)
	mult: number, -- CareerService risk multiplier (probation 0.6)
	headroom: number, -- Risk Sense headroom added to the concentration limit
}
export type Book = { [string]: any }
export type Projection = {
	ticker: string,
	shares: number, -- position after the fill
	fill: number, -- fill price
	cost: number, -- cash out (negative = proceeds)
	cash: number,
	equity: number,
	value: number, -- |position value| after
	weight: number, -- value / equity
	gross: number,
	grossRatio: number,
	reducing: boolean,
}

local Ledger = {}

Ledger.STUDENT_BOOK = 5000
Ledger.SPREAD = 0.0005
Ledger.TRADE_RING = 25
Ledger.WIPE_FRACTION = 0.1
Ledger.WIPE_MIN = 5000
Ledger.CAPITAL_SHARE = 0.5
Ledger.CAPITAL_CAP = 250000
Ledger.CONC_JUNIOR = 0.4 -- students, interns and analysts
Ledger.CONC_SENIOR = 0.5 -- associate and up
Ledger.GROSS_JUNIOR = 1.0
Ledger.GROSS_SENIOR = 1.5
Ledger.SHORT_RANK = 2
Ledger.MAX_SHARES = 10000000
local EPS = 1e-9

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end
Ledger.num = num

local function round(x: number, places: number): number
	local m = 10 ^ places
	return math.floor(x * m + 0.5) / m
end
Ledger.round = round

local function sign(x: number): number
	return if x > 0 then 1 elseif x < 0 then -1 else 0
end

function Ledger.defaultLimits(): Limits
	return Ledger.limits({ rank = 0, mult = 1, headroom = 0 })
end

function Ledger.new(bookSize: number?, paper: boolean?): Book
	local size = math.max(0, math.floor(num(bookSize, Ledger.STUDENT_BOOK)))
	return {
		cash = size,
		positions = {},
		bookSize = size,
		realized = 0,
		trades = {},
		weekReturns = {},
		peak = size,
		violations = 0,
		credits = { capital = 0 },
		paidCapital = 0,
		paper = paper ~= false,
		stops = {},
		flows = 0,
		tradeCount = 0,
		tradeSeq = 0,
		limits = Ledger.defaultLimits(),
		risk = { weekViolations = 0, breaches = {} },
		lastWipe = { lost = 0, at = 0, restored = true },
		sessionStart = size,
	}
end

-- Repairs a saved book in place (and returns it): bad numbers, unknown tickers, malformed positions.
function Ledger.normalize(raw: any): Book
	local b: Book = if type(raw) == "table" then raw else Ledger.new()
	b.bookSize = math.max(0, num(b.bookSize, Ledger.STUDENT_BOOK))
	b.cash = num(b.cash, b.bookSize)
	b.realized = num(b.realized, 0)
	b.peak = math.max(0, num(b.peak, b.cash))
	b.violations = math.max(0, math.floor(num(b.violations, 0)))
	b.paidCapital = math.max(0, num(b.paidCapital, 0))
	b.flows = num(b.flows, 0)
	b.tradeCount = math.max(0, math.floor(num(b.tradeCount, 0)))
	b.tradeSeq = math.max(0, math.floor(num(b.tradeSeq, 0)))
	b.sessionStart = num(b.sessionStart, b.cash)
	b.paper = b.paper == true
	if type(b.credits) ~= "table" then
		b.credits = { capital = 0 }
	end
	b.credits.capital = math.max(0, math.floor(num(b.credits.capital, 0)))
	if type(b.trades) ~= "table" then
		b.trades = {}
	end
	if type(b.weekReturns) ~= "table" then
		b.weekReturns = {}
	end
	if type(b.stops) ~= "table" then
		b.stops = {}
	end
	if type(b.limits) ~= "table" then
		b.limits = Ledger.defaultLimits()
	end
	if type(b.risk) ~= "table" then
		b.risk = { weekViolations = 0, breaches = {} }
	end
	if type(b.lastWipe) ~= "table" then
		b.lastWipe = { lost = 0, at = 0, restored = true }
	end
	local clean: { [string]: Position } = {}
	if type(b.positions) == "table" then
		for tk, pos in b.positions do
			if type(tk) == "string" and Tickers.get(tk) and type(pos) == "table" then
				local shares = num(pos.shares, 0)
				local avg = num(pos.avgCost, 0)
				if shares ~= 0 and shares == math.floor(shares) and avg > 0 then
					clean[tk] = { shares = shares, avgCost = avg }
				end
			end
		end
	end
	b.positions = clean
	for tk, s in b.stops do
		if type(tk) ~= "string" or clean[tk] == nil or type(s) ~= "table" then
			b.stops[tk] = nil
		end
	end
	return b
end

---------------------------------------------------------------------------------------------------
-- Limits
---------------------------------------------------------------------------------------------------
function Ledger.limits(input: { rank: number?, mult: number?, headroom: number? }): Limits
	local rank = math.max(0, math.floor(num(input.rank, 0)))
	local mult = math.clamp(num(input.mult, 1), 0.1, 2)
	local headroom = math.clamp(num(input.headroom, 0), 0, 0.1)
	local senior = rank >= Ledger.SHORT_RANK
	return {
		rank = rank,
		concentration = round((if senior then Ledger.CONC_SENIOR else Ledger.CONC_JUNIOR) * mult + headroom, 4),
		gross = round((if senior then Ledger.GROSS_SENIOR else Ledger.GROSS_JUNIOR) * mult, 4),
		short = senior,
		margin = senior,
		mult = mult,
		headroom = headroom,
	}
end

---------------------------------------------------------------------------------------------------
-- Valuation
---------------------------------------------------------------------------------------------------
local function priceOf(prices: { [string]: number }, tk: string, pos: Position): number
	local p = prices[tk]
	if type(p) == "number" and p > 0 then
		return p
	end
	return pos.avgCost
end

function Ledger.equity(book: Book, prices: { [string]: number }): number
	local e = num(book.cash, 0)
	for tk, pos in book.positions :: { [string]: Position } do
		e += pos.shares * priceOf(prices, tk, pos)
	end
	return e
end

function Ledger.gross(book: Book, prices: { [string]: number }): number
	local g = 0
	for tk, pos in book.positions :: { [string]: Position } do
		g += math.abs(pos.shares * priceOf(prices, tk, pos))
	end
	return g
end
Ledger.invested = Ledger.gross

function Ledger.net(book: Book, prices: { [string]: number }): number
	local n = 0
	for tk, pos in book.positions :: { [string]: Position } do
		n += pos.shares * priceOf(prices, tk, pos)
	end
	return n
end

function Ledger.unrealized(book: Book, prices: { [string]: number }): number
	local u = 0
	for tk, pos in book.positions :: { [string]: Position } do
		u += pos.shares * (priceOf(prices, tk, pos) - pos.avgCost)
	end
	return u
end

function Ledger.summary(book: Book, prices: { [string]: number }): { [string]: number }
	local equity = Ledger.equity(book, prices)
	local peak = math.max(num(book.peak, equity), equity)
	return {
		equity = round(equity, 2),
		cash = round(num(book.cash, 0), 2),
		invested = round(Ledger.gross(book, prices), 2),
		net = round(Ledger.net(book, prices), 2),
		unrealized = round(Ledger.unrealized(book, prices), 2),
		realized = round(num(book.realized, 0), 2),
		sessionPnl = round(equity - num(book.sessionStart, equity), 2),
		drawdown = if peak > 0 then round(math.max(0, 1 - equity / peak), 4) else 0,
		bookSize = num(book.bookSize, 0),
	}
end

function Ledger.updatePeak(book: Book, equity: number)
	if equity > num(book.peak, 0) then
		book.peak = equity
	end
end

function Ledger.fillPrice(mid: number, delta: number, spread: number?): number
	return mid * (1 + sign(delta) * (spread or Ledger.SPREAD) / 2)
end

---------------------------------------------------------------------------------------------------
-- Pre-trade checks
---------------------------------------------------------------------------------------------------
function Ledger.project(book: Book, prices: { [string]: number }, ticker: string, delta: number): Projection?
	local mid = prices[ticker]
	if type(mid) ~= "number" or mid <= 0 then
		return nil
	end
	local positions = book.positions :: { [string]: Position }
	local pos = positions[ticker]
	local old = if pos then pos.shares else 0
	local new = old + delta
	local px = Ledger.fillPrice(mid, delta)
	local equity0 = Ledger.equity(book, prices)
	local spreadCost = math.abs(delta) * math.abs(px - mid)
	local equity = equity0 - spreadCost
	local gross = Ledger.gross(book, prices) - math.abs(old * mid) + math.abs(new * mid)
	local value = math.abs(new * mid)
	local reducing = old ~= 0 and (new == 0 or sign(new) == sign(old)) and math.abs(new) < math.abs(old)
	return {
		ticker = ticker,
		shares = new,
		fill = px,
		cost = delta * px,
		cash = num(book.cash, 0) - delta * px,
		equity = equity,
		value = value,
		weight = if equity > 0 then value / equity else math.huge,
		gross = gross,
		grossRatio = if equity > 0 then gross / equity else math.huge,
		reducing = reducing,
	}
end

function Ledger.check(
	book: Book,
	prices: { [string]: number },
	ticker: string,
	delta: number,
	limits: Limits
): (boolean, string?, Projection?)
	if type(delta) ~= "number" or delta == 0 or delta ~= math.floor(delta) or math.abs(delta) > Ledger.MAX_SHARES then
		return false, "bad_qty", nil
	end
	if not Tickers.get(ticker) then
		return false, "bad_ticker", nil
	end
	local p = Ledger.project(book, prices, ticker, delta)
	if not p then
		return false, "no_price", nil
	end
	if p.reducing then
		return true, nil, p -- trimming or closing is always allowed
	end
	if p.shares < 0 and not limits.short then
		return false, "no_short", p
	end
	if p.equity <= 0 then
		return false, "equity", p
	end
	if p.weight > limits.concentration + EPS then
		return false, "concentration", p
	end
	if p.grossRatio > limits.gross + EPS then
		return false, "gross", p
	end
	if not limits.margin and p.cash < -1e-6 then
		return false, "cash", p
	end
	return true, nil, p
end

function Ledger.maxDelta(book: Book, prices: { [string]: number }, ticker: string, dir: number, limits: Limits): number
	local mid = prices[ticker]
	if type(mid) ~= "number" or mid <= 0 then
		return 0
	end
	local d = if dir >= 0 then 1 else -1
	local pos = (book.positions :: { [string]: Position })[ticker]
	local old = if pos then math.abs(pos.shares) else 0
	local equity = math.max(0, Ledger.equity(book, prices))
	local hi = math.min(Ledger.MAX_SHARES, math.floor(4 * equity / mid) + old + 1)
	local lo = 0
	if not (Ledger.check(book, prices, ticker, d, limits)) then
		return 0
	end
	lo = 1
	while lo < hi do
		local m = (lo + hi + 1) // 2
		if Ledger.check(book, prices, ticker, d * m, limits) then
			lo = m
		else
			hi = m - 1
		end
	end
	return lo
end

---------------------------------------------------------------------------------------------------
-- Fills
---------------------------------------------------------------------------------------------------
local function pushTrade(book: Book, trade: Trade)
	local ring = book.trades :: { Trade }
	table.insert(ring, trade)
	while #ring > Ledger.TRADE_RING do
		table.remove(ring, 1)
	end
end

export type FillOpts = { spread: number?, counts: boolean? }

function Ledger.fill(
	book: Book,
	ticker: string,
	delta: number,
	mid: number,
	at: number,
	kind: string,
	opts: FillOpts?
): Trade
	local spread = if opts and opts.spread then opts.spread else Ledger.SPREAD
	local px = Ledger.fillPrice(mid, delta, spread)
	local positions = book.positions :: { [string]: Position }
	local pos = positions[ticker]
	local old = if pos then pos.shares else 0
	local avg = if pos then pos.avgCost else 0
	local new = old + delta
	local pnl = 0
	if old == 0 or sign(old) == sign(delta) then
		avg = (math.abs(old) * avg + math.abs(delta) * px) / math.abs(new)
	else
		local closing = math.min(math.abs(delta), math.abs(old))
		pnl = closing * (px - avg) * sign(old)
		if math.abs(delta) > math.abs(old) then
			avg = px -- flipped through zero: the remainder opens at the fill
			book.stops[ticker] = nil
		end
	end
	book.cash = num(book.cash, 0) - delta * px
	book.realized = num(book.realized, 0) + pnl
	if new == 0 then
		positions[ticker] = nil
		book.stops[ticker] = nil
	else
		positions[ticker] = { shares = new, avgCost = avg }
	end
	book.tradeSeq = num(book.tradeSeq, 0) + 1
	if not opts or opts.counts ~= false then
		book.tradeCount = num(book.tradeCount, 0) + 1
	end
	local trade: Trade = {
		id = book.tradeSeq,
		t = at,
		tk = ticker,
		q = delta,
		px = round(px, 4),
		mid = round(mid, 4),
		fee = round(math.abs(delta) * math.abs(px - mid), 2),
		pnl = round(pnl, 2),
		kind = kind,
	}
	pushTrade(book, trade)
	return trade
end

-- Closes every position at mid (no spread: "desk policy, end the session flat"). Missing prices close at cost.
function Ledger.flatten(book: Book, prices: { [string]: number }, at: number, kind: string): ({ Trade }, number)
	local trades: { Trade } = {}
	local realized = 0
	local ids: { string } = {}
	for tk in book.positions :: { [string]: Position } do
		table.insert(ids, tk)
	end
	table.sort(ids)
	for _, tk in ids do
		local pos = (book.positions :: { [string]: Position })[tk]
		local mid = priceOf(prices, tk, pos)
		local trade = Ledger.fill(book, tk, -pos.shares, mid, at, kind, { spread = 0, counts = false })
		realized += trade.pnl
		table.insert(trades, trade)
	end
	book.stops = {}
	return trades, realized
end

---------------------------------------------------------------------------------------------------
-- Flows
---------------------------------------------------------------------------------------------------
function Ledger.flow(book: Book, amount: number): number
	local a = num(amount, 0)
	if a == 0 then
		return 0
	end
	book.cash = num(book.cash, 0) + a
	book.flows = num(book.flows, 0) + a
	book.peak = math.max(0, num(book.peak, 0) + a)
	book.sessionStart = num(book.sessionStart, 0) + a
	return a
end

-- Re-allocates the book to `size` (hire, promotion, re-entry, lateral). The allocation change is an external flow,
-- so P/L earned so far stays in the book. Leaving the student paper account (any non-paper reason) closes it: the
-- real book starts fresh at `size`.
function Ledger.setBookSize(book: Book, size: number, reason: string, prices: { [string]: number }, at: number): number
	local target = math.max(0, math.floor(num(size, 0)))
	local flowAmount: number
	if book.paper == true and reason ~= "paper" then
		Ledger.flatten(book, prices, at, "paper")
		flowAmount = target - num(book.cash, 0)
		book.paper = false
		book.bookSize = target
		Ledger.flow(book, flowAmount)
		book.peak = target
		return flowAmount
	end
	flowAmount = target - num(book.bookSize, 0)
	local equity = Ledger.equity(book, prices)
	if equity + flowAmount < 0 then
		flowAmount = -equity
	end
	book.bookSize = target
	Ledger.flow(book, flowAmount)
	book.peak = math.max(num(book.peak, 0), Ledger.equity(book, prices))
	return flowAmount
end

-- The firing wipeout (spec §6): the book resets to 10% of its size (minimum $5,000). Returns the equity lost.
function Ledger.wipe(book: Book, prices: { [string]: number }, at: number): (number, number)
	Ledger.flatten(book, prices, at, "wipe")
	local equity = num(book.cash, 0)
	local oldSize = num(book.bookSize, 0)
	local newBook = math.max(Ledger.WIPE_MIN, math.floor(oldSize * Ledger.WIPE_FRACTION))
	local lost = math.max(0, equity - newBook)
	Ledger.flow(book, newBook - equity)
	book.bookSize = newBook
	book.peak = newBook
	book.paper = false
	book.lastWipe = { lost = round(lost, 2), book = oldSize, at = at, restored = false }
	return lost, newBook
end

-- Capital Reconstruction (79 R$, spec §6): restores 50% of the lost book, capped at $250,000, as flagged paid capital.
function Ledger.restoreCapital(book: Book, lostBook: number?, _at: number): (number?, string?)
	local credits = book.credits
	if type(credits) ~= "table" or num(credits.capital, 0) <= 0 then
		return nil, "no_credit"
	end
	local wipe = book.lastWipe
	local lost = num(lostBook, 0)
	if lost <= 0 then
		if type(wipe) ~= "table" or wipe.restored == true then
			return nil, if type(wipe) == "table" and num(wipe.lost, 0) > 0 then "used" else "nothing_lost"
		end
		lost = num(wipe.lost, 0)
	end
	if lost <= 0 then
		return nil, "nothing_lost"
	end
	local amount = math.min(Ledger.CAPITAL_CAP, math.floor(lost * Ledger.CAPITAL_SHARE))
	credits.capital = num(credits.capital, 0) - 1
	book.paidCapital = num(book.paidCapital, 0) + amount
	book.bookSize = num(book.bookSize, 0) + amount
	Ledger.flow(book, amount)
	if type(wipe) == "table" then
		wipe.restored = true
	end
	return amount, nil
end

-- Rebirth: back to the student paper account. Paid credits and the season's week records are kept.
function Ledger.resetForRebirth(book: Book, prices: { [string]: number }, at: number): Book
	Ledger.flatten(book, prices, at, "rebirth")
	local fresh = Ledger.new(Ledger.STUDENT_BOOK, true)
	fresh.credits = { capital = num(if type(book.credits) == "table" then book.credits.capital else 0, 0) }
	fresh.weekReturns = if type(book.weekReturns) == "table" then book.weekReturns else {}
	fresh.violations = 0
	fresh.tradeSeq = num(book.tradeSeq, 0)
	for k in book do
		book[k] = nil
	end
	for k, v in fresh do
		book[k] = v
	end
	return book
end

return Ledger
