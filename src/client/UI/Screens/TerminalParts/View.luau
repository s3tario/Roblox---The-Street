--!strict
-- Terminal view model (owned by `market`). PURE: turns the market cache and the replicated book into rows and text
-- for the Terminal's parts. Previews reuse Shared/Logic/Portfolio/Ledger, the same maths the server enforces.
--
--   View.layoutMode(width) -> "wide" | "phone"           View.variant(themeName) -> "terminal" | "laptop"
--   View.canUsePrompt(career, events, companyId?) -> boolean   hide EmployeesOnly prompts for visitors
--   View.positions(book, prices) -> { PositionRow }      sorted by value
--   View.account(book, prices) -> Ledger.summary
--   View.side(held, side) -> "buy" | "sell" | "short" | "cover"
--   View.preview(book, prices, ticker, side, qty, limits) -> Preview
--   View.presetQty(book, prices, ticker, side, preset, limits) -> number   preset "p10" | "p25" | "p50" | "max" | "close"
--   View.series(view, range) -> { number }              "1d" intraday path (or the last close), "30d" closes + now
--   View.calendar(rows) -> { {label, when, tickers, frenzy} }
--   View.news(items, ticker?) -> items                   View.breaches(risk, now) -> rows with secondsLeft
--   View.price / pct / money / compact / signedMoney / changeColor / phaseLine   formatting

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Format = require(Shared.Util.Format)
local Ledger = require(Shared.Logic.Portfolio.Ledger)
local Schedule = require(Shared.Logic.Market.Schedule)

export type PositionRow = {
	ticker: string,
	name: string,
	shares: number,
	avgCost: number,
	price: number,
	value: number,
	pnl: number,
	pnlPct: number,
	weight: number,
	stop: number?,
	take: number?,
	long: boolean,
}
export type Preview = {
	ok: boolean,
	err: string?,
	side: string,
	qty: number,
	delta: number,
	fill: number,
	cost: number,
	weight: number,
	limit: number,
	grossRatio: number,
	grossLimit: number,
	sharesAfter: number,
}

local View = {}

View.WIDE_MIN = 880
View.PRESETS = { "p10", "p25", "p50", "max", "close" }
View.PRESET_FRACTION = { p10 = 0.1, p25 = 0.25, p50 = 0.5 } :: { [string]: number }

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function View.layoutMode(width: number?): string
	if type(width) ~= "number" or width <= 0 then
		return "wide"
	end
	return if width >= View.WIDE_MIN then "wide" else "phone"
end

function View.variant(themeName: string?): string
	return if themeName == "campus" then "laptop" else "terminal"
end

function View.canUsePrompt(career: any, events: any, companyId: any): boolean
	if type(companyId) ~= "string" or companyId == "" then
		return true
	end
	local mine = if type(career) == "table" then career.companyId else nil
	if type(mine) ~= "string" or mine == "" then
		return false
	end
	if type(career) == "table" and career.status == "fired" then
		return false
	end
	if mine == companyId then
		return true
	end
	-- Merger Mania: two companies share both offices (the events feature lists both ids in the event data)
	local corporate = if type(events) == "table" then events.corporate else nil
	if type(corporate) == "table" and corporate.id == "merger_mania" and type(corporate.data) == "table" then
		local seen: { [string]: boolean } = {}
		local function scan(v: any, depth: number)
			if type(v) == "string" then
				seen[v] = true
			elseif type(v) == "table" and depth < 3 then
				for _, x in v do
					scan(x, depth + 1)
				end
			end
		end
		scan(corporate.data, 0)
		return seen[mine] == true and seen[companyId] == true
	end
	return false
end

---------------------------------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------------------------------
function View.price(x: number?): string
	if type(x) ~= "number" or x ~= x then
		return "--"
	end
	return Format.commas(x, 2)
end

function View.pct(ratio: number?, decimals: number?): string
	if type(ratio) ~= "number" or ratio ~= ratio then
		return "--"
	end
	return Format.pct(ratio, decimals or 2)
end

function View.plainPct(ratio: number?, decimals: number?): string
	if type(ratio) ~= "number" or ratio ~= ratio then
		return "--"
	end
	return Format.pct(ratio, decimals or 0, false)
end

function View.money(x: number?, decimals: number?): string
	if type(x) ~= "number" or x ~= x then
		return "--"
	end
	return Format.money(x, decimals or 0)
end

function View.compact(x: number?): string
	if type(x) ~= "number" or x ~= x then
		return "--"
	end
	return Format.compactMoney(x)
end

function View.signedMoney(x: number?): string
	if type(x) ~= "number" or x ~= x then
		return "--"
	end
	local s = Format.money(math.abs(x), 0)
	if x > 0.5 then
		return "+" .. s
	elseif x < -0.5 then
		return "-" .. s
	end
	return s
end

-- $M figures from the facts card ("$24,000M" -> "$24.0B").
function View.millions(x: number?): string
	if type(x) ~= "number" or x ~= x then
		return "--"
	end
	return Format.compactMoney(x * 1e6)
end

function View.changeColor(x: number?): string
	if type(x) ~= "number" or x ~= x or math.abs(x) < 1e-9 then
		return "textDim"
	end
	return if x > 0 then "good" else "bad"
end

function View.phaseLine(phase: string, now: number): string
	if phase == "closed" then
		return Tickers.text("phase_closed_long")
	elseif phase == "after" or Schedule.phase(now) == "after" then
		return Tickers.text("phase_after_long", { time = Format.clock(Schedule.nextOpenAt(now) - now) })
	end
	return Tickers.text("phase_open_long", { time = Format.clock(Schedule.closeAt(now) - now) })
end

---------------------------------------------------------------------------------------------------
-- Book
---------------------------------------------------------------------------------------------------
function View.positions(book: any, prices: { [string]: number }): { PositionRow }
	local rows: { PositionRow } = {}
	if type(book) ~= "table" or type(book.positions) ~= "table" then
		return rows
	end
	local equity = Ledger.equity(book, prices)
	local stops = if type(book.stops) == "table" then book.stops else {}
	for tk, pos in book.positions do
		if type(tk) == "string" and type(pos) == "table" and num(pos.shares, 0) ~= 0 then
			local def = Tickers.get(tk)
			local shares = num(pos.shares, 0)
			local avg = num(pos.avgCost, 0)
			local price = num(prices[tk], avg)
			local value = shares * price
			local pnl = shares * (price - avg)
			local s = stops[tk]
			table.insert(rows, {
				ticker = tk,
				name = if def then def.name else tk,
				shares = shares,
				avgCost = avg,
				price = price,
				value = value,
				pnl = pnl,
				pnlPct = if avg > 0 then (price / avg - 1) * (if shares > 0 then 1 else -1) else 0,
				weight = if equity > 0 then math.abs(value) / equity else 0,
				stop = if type(s) == "table" then s.stop else nil,
				take = if type(s) == "table" then s.take else nil,
				long = shares > 0,
			})
		end
	end
	table.sort(rows, function(a, b)
		if math.abs(a.value) == math.abs(b.value) then
			return a.ticker < b.ticker
		end
		return math.abs(a.value) > math.abs(b.value)
	end)
	return rows
end

function View.account(book: any, prices: { [string]: number }): { [string]: number }
	if type(book) ~= "table" then
		return Ledger.summary(Ledger.new(0, true), prices)
	end
	local ok, summary = pcall(Ledger.summary, book, prices)
	if ok then
		return summary
	end
	return Ledger.summary(Ledger.new(0, true), prices)
end

function View.held(book: any, ticker: string): number
	if type(book) ~= "table" or type(book.positions) ~= "table" then
		return 0
	end
	local pos = book.positions[ticker]
	return if type(pos) == "table" then num(pos.shares, 0) else 0
end

function View.side(held: number, side: string): string
	if side == "buy" then
		return if held < 0 then "cover" else "buy"
	end
	return if held > 0 then "sell" else "short"
end

function View.preview(
	book: any,
	prices: { [string]: number },
	ticker: string,
	side: string,
	qty: number,
	limits: Ledger.Limits
): Preview
	local held = View.held(book, ticker)
	local q = math.max(0, math.floor(num(qty, 0)))
	local delta = if side == "buy" then q else -q
	local out: Preview = {
		ok = false,
		err = nil,
		side = View.side(held, side),
		qty = q,
		delta = delta,
		fill = 0,
		cost = 0,
		weight = 0,
		limit = limits.concentration,
		grossRatio = 0,
		grossLimit = limits.gross,
		sharesAfter = held,
	}
	if type(book) ~= "table" then
		out.err = "not_loaded"
		return out
	end
	if q <= 0 then
		out.err = "bad_qty"
		local cur = Ledger.project(book, prices, ticker, 0)
		if cur then
			out.weight = cur.weight
			out.grossRatio = cur.grossRatio
		end
		return out
	end
	local ok, err, p = Ledger.check(book, prices, ticker, delta, limits)
	out.ok = ok
	out.err = err
	if p then
		out.fill = p.fill
		out.cost = p.cost
		out.weight = if p.weight == math.huge then 0 else p.weight
		out.grossRatio = if p.grossRatio == math.huge then 0 else p.grossRatio
		out.sharesAfter = p.shares
	end
	return out
end

function View.presetQty(
	book: any,
	prices: { [string]: number },
	ticker: string,
	side: string,
	preset: string,
	limits: Ledger.Limits
): number
	if type(book) ~= "table" then
		return 0
	end
	local price = prices[ticker]
	if type(price) ~= "number" or price <= 0 then
		return 0
	end
	local held = View.held(book, ticker)
	if preset == "close" then
		if side == "buy" and held < 0 then
			return -held
		elseif side == "sell" and held > 0 then
			return held
		end
		return math.abs(held)
	end
	local dir = if side == "buy" then 1 else -1
	local most = Ledger.maxDelta(book, prices, ticker, dir, limits)
	if preset == "max" then
		return most
	end
	local f = View.PRESET_FRACTION[preset]
	if not f then
		return 0
	end
	local equity = math.max(0, Ledger.equity(book, prices))
	local q = math.floor(equity * f / price)
	return math.max(0, math.min(q, most))
end

---------------------------------------------------------------------------------------------------
-- Market
---------------------------------------------------------------------------------------------------
function View.series(view: any, range: string): { number }
	if type(view) ~= "table" then
		return {}
	end
	local q = view.quote
	local price = if type(q) == "table" then num(q.price, 0) else 0
	if range == "30d" then
		local out = if type(view.daily) == "table" then table.clone(view.daily) else {}
		if price > 0 then
			table.insert(out, price)
		end
		return out
	end
	local path = if type(view.intraday) == "table" then table.clone(view.intraday) else {}
	if #path == 0 and price > 0 then
		local prev = if type(q) == "table" then num(q.prevClose, price) else price
		path = { prev, price }
	end
	return path
end

function View.calendar(rows: any): { { [string]: any } }
	local out: { { [string]: any } } = {}
	if type(rows) ~= "table" then
		return out
	end
	for _, r in rows do
		if type(r) == "table" and type(r.tickers) == "table" then
			local names: { string } = {}
			local frenzy = false
			for _, t in r.tickers do
				if type(t) == "table" and type(t.id) == "string" then
					local cons = if type(t.consensus) == "number"
						then " " .. Tickers.text("cal_cons", { cons = Format.money(t.consensus, 2) })
						else ""
					table.insert(names, t.id .. cons)
					frenzy = frenzy or t.frenzy == true
				end
			end
			local inDays = math.floor(num(r.inDays, 0))
			table.insert(out, {
				label = Tickers.text("day_label", { day = math.floor(num(r.day, 0)) }),
				when = if inDays <= 0 then Tickers.text("cal_today") else Tickers.text("cal_in", { days = inDays }),
				tickers = table.concat(names, " · "),
				frenzy = frenzy,
				inDays = inDays,
			})
		end
	end
	return out
end

function View.news(items: any, ticker: string?): { { [string]: any } }
	local out: { { [string]: any } } = {}
	if type(items) ~= "table" then
		return out
	end
	for _, item in items do
		if type(item) == "table" and type(item.headline) == "string" then
			if not ticker or item.ticker == ticker then
				table.insert(out, item)
			end
		end
	end
	return out
end

function View.breaches(risk: any, now: number): { { [string]: any } }
	local out: { { [string]: any } } = {}
	if type(risk) ~= "table" or type(risk.breaches) ~= "table" then
		return out
	end
	for _, b in risk.breaches do
		if type(b) == "table" and type(b.kind) == "string" then
			local key = if b.kind == "gross"
				then "breach_gross"
				elseif b.kind == "cash" then "breach_cash"
				else "breach_conc"
			local text = Tickers.text(key, {
				ticker = if type(b.ticker) == "string" then b.ticker else "",
				value = if b.kind == "cash" then Format.money(num(b.value, 0), 0) else View.plainPct(num(b.value, 0)),
				limit = View.plainPct(num(b.limit, 0)),
			})
			table.insert(out, {
				kind = b.kind,
				ticker = b.ticker,
				text = text,
				secondsLeft = math.max(0, math.floor(num(b.deadline, now) - now)),
			})
		end
	end
	return out
end

return View
