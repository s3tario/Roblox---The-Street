--!strict
-- The trading desk (owned by `market`): the operations PortfolioService performs on a book, composed from Ledger,
-- Orders, Risk and Txn so they can be unit-tested. PURE.
--
--   Desk.parseOrder(raw) -> (Order?, err?)            shape check of a client order (the service also Guards it)
--   Desk.trade(book, prices, order, limits, now, open) -> Result
--   Desk.submit(cache, txnId, book, prices, order, limits, now, open) -> (Result, replayed)
--       idempotent trade: a txn id seen before returns the original Result and changes nothing
--   Desk.setStops(book, prices, ticker, stop?, take?) -> (ok, err?)
--   Desk.process(book, risk, prices, limits, now, open) -> Tick     stops, take-profits and the risk ladder
--   Desk.leave(book, prices, now) -> { Trade }         end the session flat at mid (not a flow)
--   Desk.restore(book, now) -> { Trade }               a book left open by a crashed server closes at cost
--   Desk.errorVars(result, limits) -> vars             placeholders for the Tickers.text("err_" .. err) strings
--
--   Order = { ticker, side = "buy" | "sell" | "close", qty?, fit?, stop?, take? }
--       fit = true shrinks qty to the largest size the limits allow (the ticket's "Max" preset)
--   Result = { ok, err?, trade?, projection?, qty? }

local Tickers = require(script.Parent.Parent.Parent.Config.Tickers)
local Ledger = require(script.Parent.Ledger)
local Orders = require(script.Parent.Orders)
local Risk = require(script.Parent.Risk)
local Txn = require(script.Parent.Txn)

export type Order = {
	ticker: string,
	side: string,
	qty: number?,
	fit: boolean?,
	stop: number?,
	take: number?,
}
export type Result = {
	ok: boolean,
	err: string?,
	trade: Ledger.Trade?,
	projection: Ledger.Projection?,
	qty: number?,
}
export type Fill = { trade: Ledger.Trade, reason: string, breach: Risk.Active? }
export type Tick = {
	fills: { Fill },
	warn: { Risk.Active },
	violate: { Risk.Active },
	resolved: { Risk.Active },
	major: boolean,
	changed: boolean,
}

local Desk = {}

Desk.SIDES = { buy = true, sell = true, close = true }

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Desk.parseOrder(raw: any): (Order?, string?)
	if type(raw) ~= "table" then
		return nil, "generic"
	end
	local ticker = raw.ticker
	if type(ticker) ~= "string" or not Tickers.get(ticker) then
		return nil, "bad_ticker"
	end
	local side = raw.side
	if type(side) ~= "string" or not Desk.SIDES[side] then
		return nil, "generic"
	end
	local qty: number? = nil
	if side ~= "close" then
		local q = raw.qty
		if not finite(q) or q < 1 or q ~= math.floor(q) or q > Ledger.MAX_SHARES then
			return nil, "bad_qty"
		end
		qty = q
	end
	local stop: number? = nil
	if raw.stop ~= nil then
		if not finite(raw.stop) or raw.stop <= 0 then
			return nil, "bad_stop"
		end
		stop = raw.stop
	end
	local take: number? = nil
	if raw.take ~= nil then
		if not finite(raw.take) or raw.take <= 0 then
			return nil, "bad_take"
		end
		take = raw.take
	end
	return { ticker = ticker, side = side, qty = qty, fit = raw.fit == true, stop = stop, take = take }, nil
end

function Desk.trade(
	book: Ledger.Book,
	prices: { [string]: number },
	order: Order,
	limits: Ledger.Limits,
	now: number,
	open: boolean
): Result
	if not open then
		return { ok = false, err = "closed" }
	end
	local mid = prices[order.ticker]
	if type(mid) ~= "number" or mid <= 0 then
		return { ok = false, err = "no_price" }
	end
	local pos = (book.positions :: { [string]: Ledger.Position })[order.ticker]
	local held = if pos then pos.shares else 0
	local delta: number
	if order.side == "close" then
		if held == 0 then
			return { ok = false, err = "no_position" }
		end
		delta = -held
	else
		local dir = if order.side == "buy" then 1 else -1
		local qty = order.qty or 0
		if order.fit then
			local most = Ledger.maxDelta(book, prices, order.ticker, dir, limits)
			if most <= 0 then
				local _, err, p = Ledger.check(book, prices, order.ticker, dir, limits)
				return { ok = false, err = err or "generic", projection = p }
			end
			qty = math.min(qty, most)
		end
		delta = dir * qty
	end
	local ok, err, projection = Ledger.check(book, prices, order.ticker, delta, limits)
	if not ok then
		return { ok = false, err = err, projection = projection }
	end
	local after = held + delta
	if order.stop ~= nil or order.take ~= nil then
		local fine, stopErr = Orders.validate(after, mid, order.stop, order.take)
		if not fine then
			return { ok = false, err = stopErr, projection = projection }
		end
	end
	local trade = Ledger.fill(book, order.ticker, delta, mid, now, "trade")
	if after ~= 0 and (order.stop ~= nil or order.take ~= nil) then
		book.stops[order.ticker] = { stop = order.stop, take = order.take }
	end
	return { ok = true, trade = trade, projection = projection, qty = math.abs(delta) }
end

function Desk.submit(
	cache: Txn.Cache,
	txnId: string,
	book: Ledger.Book,
	prices: { [string]: number },
	order: Order,
	limits: Ledger.Limits,
	now: number,
	open: boolean
): (Result, boolean)
	local seen = Txn.get(cache, txnId)
	if seen ~= nil then
		return seen, true
	end
	local result = Desk.trade(book, prices, order, limits, now, open)
	Txn.put(cache, txnId, result)
	return result, false
end

function Desk.setStops(
	book: Ledger.Book,
	prices: { [string]: number },
	ticker: string,
	stop: number?,
	take: number?
): (boolean, string?)
	local pos = (book.positions :: { [string]: Ledger.Position })[ticker]
	if not pos then
		return false, "no_position"
	end
	local mid = prices[ticker]
	if type(mid) ~= "number" or mid <= 0 then
		return false, "no_price"
	end
	local ok, err = Orders.validate(pos.shares, mid, stop, take)
	if not ok then
		return false, err
	end
	if stop == nil and take == nil then
		book.stops[ticker] = nil
	else
		book.stops[ticker] = { stop = stop, take = take }
	end
	return true, nil
end

function Desk.process(
	book: Ledger.Book,
	risk: Risk.State,
	prices: { [string]: number },
	limits: Ledger.Limits,
	now: number,
	open: boolean
): Tick
	local tick: Tick = { fills = {}, warn = {}, violate = {}, resolved = {}, major = false, changed = false }
	if open then
		for _, hit in Orders.triggered(book, prices) do
			local mid = prices[hit.ticker]
			local trade = Ledger.fill(book, hit.ticker, -hit.shares, mid, now, hit.kind)
			table.insert(tick.fills, { trade = trade, reason = hit.kind })
			tick.changed = true
		end
	end
	local actions = Risk.update(risk, Risk.breaches(book, prices, limits), now, open)
	tick.warn = actions.warn
	tick.resolved = actions.resolved
	tick.violate = actions.violate
	if #actions.warn > 0 or #actions.resolved > 0 then
		tick.changed = true
	end
	for _, a in actions.violate do
		tick.changed = true
		book.violations = Ledger.num(book.violations, 0) + 1
		if a.kind == "equity" then
			for _, trade in (Ledger.flatten(book, prices, now, "trim")) do
				table.insert(tick.fills, { trade = trade, reason = "trim", breach = a })
			end
		else
			local tk, delta = Risk.trim(book, prices, a, limits)
			local mid = if tk then prices[tk] else nil
			if tk and delta ~= 0 and type(mid) == "number" then
				local trade = Ledger.fill(book, tk, delta, mid, now, "trim", { counts = false })
				table.insert(tick.fills, { trade = trade, reason = "trim", breach = a })
			end
		end
	end
	if #actions.violate > 0 then
		-- the desk fixed what it trimmed: a later breach starts again with a fresh warning
		local still: { [string]: boolean } = {}
		for _, b in Risk.breaches(book, prices, limits) do
			still[b.key] = true
		end
		for _, a in actions.violate do
			if not still[a.key] then
				risk.active[a.key] = nil
			end
		end
	end
	if #actions.violate > 0 and Risk.isMajor(risk) then
		tick.major = true
	end
	if tick.changed then
		Ledger.updatePeak(book, Ledger.equity(book, prices))
	end
	return tick
end

function Desk.leave(book: Ledger.Book, prices: { [string]: number }, now: number): { Ledger.Trade }
	local trades = Ledger.flatten(book, prices, now, "leave")
	return trades
end

function Desk.restore(book: Ledger.Book, now: number): { Ledger.Trade }
	local trades = Ledger.flatten(book, {}, now, "restore")
	return trades
end

local function pct(x: number): string
	return string.format("%d%%", math.floor(x * 100 + 0.5))
end
Desk.pct = pct

function Desk.errorVars(result: Result, limits: Ledger.Limits): { [string]: any }
	local p = result.projection
	return {
		ticker = if p then p.ticker else "",
		pct = if p then pct(if result.err == "gross" then p.grossRatio else p.weight) else "",
		limit = pct(if result.err == "gross" then limits.gross else limits.concentration),
	}
end

return Desk
