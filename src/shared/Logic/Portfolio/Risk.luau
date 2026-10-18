--!strict
-- Risk desk rules (owned by `market`; spec §6-§7: concentration limits, warnings, review windows long enough that
-- one move doesn't decide employment). PURE.
--
-- Trades that would breach a limit are refused up front (Ledger.check), so breaches only come from the market:
-- a winner growing past the single-name limit, equity falling, or limits shrinking (probation, a demotion).
-- Ladder: breach -> WARNING with a GRACE-second deadline (paused while the market is closed) -> unresolved at the
-- deadline: a VIOLATION (counted for the week) and the desk trims the position back inside the limit -> the
-- MAX_WEEK-th violation inside one week is MAJOR (PortfolioService reports it with major = true).
--
--   Risk.new() -> State                  Risk.normalize(raw) -> State
--   Risk.breaches(book, prices, limits) -> { Breach }
--   Risk.update(state, breaches, now, open) -> { warn = {Active}, violate = {Active}, resolved = {Active} }
--   Risk.trim(book, prices, breach, limits) -> (ticker?, delta)   the reducing trade that clears the breach
--   Risk.isMajor(state) -> boolean       Risk.resetWeek(state)    Risk.grace(state, now, seconds)
--   Risk.public(state, now) -> { weekViolations, breaches = { {kind, ticker, value, limit, secondsLeft} } }

local Ledger = require(script.Parent.Ledger)

export type Breach = { key: string, kind: string, ticker: string?, value: number, limit: number }
export type Active = {
	key: string,
	kind: string, -- "concentration" | "gross" | "cash" | "short" | "equity"
	ticker: string?,
	value: number,
	limit: number,
	since: number,
	deadline: number,
	strikes: number,
}
export type State = {
	active: { [string]: Active },
	weekViolations: number,
	total: number,
	lastAt: number,
	graceUntil: number,
}

local Risk = {}

Risk.GRACE = 60
Risk.LIMIT_CUT_GRACE = 120 -- extra time after limits shrink (probation)
Risk.MAX_WEEK = 3
Risk.TRIM_BUFFER = 0.02
local EPS = 1e-6

local function num(x: any, default: number): number
	return Ledger.num(x, default)
end

function Risk.new(): State
	return { active = {}, weekViolations = 0, total = 0, lastAt = 0, graceUntil = 0 }
end

function Risk.normalize(raw: any): State
	if type(raw) ~= "table" then
		return Risk.new()
	end
	local s = raw :: { [string]: any }
	local active: { [string]: Active } = {}
	if type(s.active) == "table" then
		for key, a in s.active do
			if type(key) == "string" and type(a) == "table" and type(a.kind) == "string" then
				active[key] = {
					key = key,
					kind = a.kind,
					ticker = if type(a.ticker) == "string" then a.ticker else nil,
					value = num(a.value, 0),
					limit = num(a.limit, 0),
					since = num(a.since, 0),
					deadline = num(a.deadline, 0),
					strikes = math.max(0, math.floor(num(a.strikes, 0))),
				}
			end
		end
	end
	return {
		active = active,
		weekViolations = math.max(0, math.floor(num(s.weekViolations, 0))),
		total = math.max(0, math.floor(num(s.total, 0))),
		lastAt = num(s.lastAt, 0),
		graceUntil = num(s.graceUntil, 0),
	}
end

function Risk.breaches(book: Ledger.Book, prices: { [string]: number }, limits: Ledger.Limits): { Breach }
	local out: { Breach } = {}
	local positions = book.positions :: { [string]: Ledger.Position }
	if next(positions) == nil then
		return out
	end
	local equity = Ledger.equity(book, prices)
	if equity <= 0 then
		table.insert(out, { key = "equity", kind = "equity", value = equity, limit = 0 })
		return out
	end
	local ids: { string } = {}
	for tk in positions do
		table.insert(ids, tk)
	end
	table.sort(ids)
	for _, tk in ids do
		local pos = positions[tk]
		local p = prices[tk] or pos.avgCost
		if pos.shares < 0 and not limits.short then
			table.insert(out, { key = "short:" .. tk, kind = "short", ticker = tk, value = pos.shares, limit = 0 })
		else
			local w = math.abs(pos.shares * p) / equity
			if w > limits.concentration + EPS then
				table.insert(out, {
					key = "conc:" .. tk,
					kind = "concentration",
					ticker = tk,
					value = w,
					limit = limits.concentration,
				})
			end
		end
	end
	local g = Ledger.gross(book, prices) / equity
	if g > limits.gross + EPS then
		table.insert(out, { key = "gross", kind = "gross", value = g, limit = limits.gross })
	end
	if not limits.margin and num(book.cash, 0) < -0.01 then
		table.insert(out, { key = "cash", kind = "cash", value = book.cash, limit = 0 })
	end
	return out
end

export type Actions = { warn: { Active }, violate: { Active }, resolved: { Active } }

function Risk.update(state: State, breaches: { Breach }, now: number, open: boolean): Actions
	local actions: Actions = { warn = {}, violate = {}, resolved = {} }
	local dt = if state.lastAt > 0 then math.max(0, now - state.lastAt) else 0
	state.lastAt = now
	if not open and dt > 0 then
		-- the clock stops while the market is shut: nobody can trade their way out
		for _, a in state.active do
			a.deadline += dt
		end
		state.graceUntil = if state.graceUntil > 0 then state.graceUntil + dt else 0
	end
	local seen: { [string]: boolean } = {}
	for _, b in breaches do
		seen[b.key] = true
		local a = state.active[b.key]
		if not a then
			local fresh: Active = {
				key = b.key,
				kind = b.kind,
				ticker = b.ticker,
				value = b.value,
				limit = b.limit,
				since = now,
				deadline = math.max(now + Risk.GRACE, state.graceUntil),
				strikes = 0,
			}
			state.active[b.key] = fresh
			table.insert(actions.warn, fresh)
		else
			a.value = b.value
			a.limit = b.limit
			if open and now >= a.deadline then
				a.strikes += 1
				a.deadline = now + Risk.GRACE
				state.weekViolations += 1
				state.total += 1
				table.insert(actions.violate, a)
			end
		end
	end
	for key, a in state.active do
		if not seen[key] then
			state.active[key] = nil
			table.insert(actions.resolved, a)
		end
	end
	return actions
end

function Risk.isMajor(state: State): boolean
	return state.weekViolations >= Risk.MAX_WEEK
end

function Risk.resetWeek(state: State)
	state.weekViolations = 0
end

-- Extra time for breaches that appear before `now + seconds` (limits just shrank).
function Risk.grace(state: State, now: number, seconds: number)
	state.graceUntil = math.max(state.graceUntil, now + seconds)
	for _, a in state.active do
		a.deadline = math.max(a.deadline, now + seconds)
	end
end

local function largest(book: Ledger.Book, prices: { [string]: number }, longOnly: boolean): (string?, number)
	local best: string? = nil
	local bestValue = 0
	for tk, pos in book.positions :: { [string]: Ledger.Position } do
		if not longOnly or pos.shares > 0 then
			local v = math.abs(pos.shares * (prices[tk] or pos.avgCost))
			if v > bestValue or (v == bestValue and best ~= nil and tk < best) then
				best = tk
				bestValue = v
			end
		end
	end
	return best, bestValue
end

-- The (reducing) trade the desk makes to clear a breach. Returns (ticker?, delta).
function Risk.trim(
	book: Ledger.Book,
	prices: { [string]: number },
	breach: Breach | Active,
	limits: Ledger.Limits
): (string?, number)
	local positions = book.positions :: { [string]: Ledger.Position }
	local equity = Ledger.equity(book, prices)
	if breach.kind == "concentration" or breach.kind == "short" then
		local tk = breach.ticker
		local pos = if tk then positions[tk] else nil
		if not tk or not pos then
			return nil, 0
		end
		if breach.kind == "short" then
			return tk, -pos.shares
		end
		local p = prices[tk] or pos.avgCost
		local target = math.max(0, math.floor((limits.concentration - Risk.TRIM_BUFFER) * math.max(equity, 0) / p))
		local keep = if pos.shares > 0 then target else -target
		return tk, keep - pos.shares
	elseif breach.kind == "gross" then
		local tk, value = largest(book, prices, false)
		if not tk then
			return nil, 0
		end
		local pos = positions[tk]
		local p = prices[tk] or pos.avgCost
		local excess = Ledger.gross(book, prices) - (limits.gross - Risk.TRIM_BUFFER) * math.max(equity, 0)
		local cut = math.min(math.abs(pos.shares), math.ceil(math.min(excess, value) / p))
		return tk, if pos.shares > 0 then -cut else cut
	elseif breach.kind == "cash" then
		local tk = largest(book, prices, true)
		if not tk then
			return nil, 0
		end
		local pos = positions[tk]
		local p = prices[tk] or pos.avgCost
		local cut = math.min(pos.shares, math.ceil(-num(book.cash, 0) / (p * (1 - Ledger.SPREAD))))
		return tk, -cut
	end
	return nil, 0
end

function Risk.public(state: State, now: number): { [string]: any }
	local list: { { [string]: any } } = {}
	for _, a in state.active do
		table.insert(list, {
			kind = a.kind,
			ticker = a.ticker,
			value = math.floor(a.value * 10000 + 0.5) / 10000,
			limit = a.limit,
			deadline = a.deadline,
			secondsLeft = math.max(0, math.floor(a.deadline - now)),
		})
	end
	table.sort(list, function(x, y)
		return x.deadline < y.deadline
	end)
	return { weekViolations = state.weekViolations, breaches = list, max = Risk.MAX_WEEK }
end

return Risk
