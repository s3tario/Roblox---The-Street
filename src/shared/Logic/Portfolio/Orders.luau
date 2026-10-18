--!strict
-- Optional stop-loss and take-profit levels on open positions (owned by `market`; spec §7). PURE.
-- A long's stop sits below the price and its take-profit above; a short's the other way round. Levels must sit within
-- MIN_RATIO..MAX_RATIO of the current price. Triggered levels close the whole position at market.
--
--   Orders.validate(shares, price, stop?, take?) -> (ok, err?)    err "bad_stop" | "bad_take"
--   Orders.triggered(book, prices) -> { {ticker, kind = "stop" | "take", shares} }   sorted by ticker

local Ledger = require(script.Parent.Ledger)

local Orders = {}

Orders.MIN_RATIO = 0.2
Orders.MAX_RATIO = 5

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Orders.validate(shares: number, price: number, stop: number?, take: number?): (boolean, string?)
	if shares == 0 or not finite(price) or price <= 0 then
		if stop ~= nil then
			return false, "bad_stop"
		elseif take ~= nil then
			return false, "bad_take"
		end
		return true, nil
	end
	local lo, hi = price * Orders.MIN_RATIO, price * Orders.MAX_RATIO
	if stop ~= nil then
		if not finite(stop) or stop < lo or stop > hi then
			return false, "bad_stop"
		end
		if (shares > 0 and stop >= price) or (shares < 0 and stop <= price) then
			return false, "bad_stop"
		end
	end
	if take ~= nil then
		if not finite(take) or take < lo or take > hi then
			return false, "bad_take"
		end
		if (shares > 0 and take <= price) or (shares < 0 and take >= price) then
			return false, "bad_take"
		end
	end
	return true, nil
end

export type Hit = { ticker: string, kind: string, shares: number }

function Orders.triggered(book: Ledger.Book, prices: { [string]: number }): { Hit }
	local out: { Hit } = {}
	local stops = book.stops :: { [string]: Ledger.Stop }
	for tk, s in stops do
		local pos = (book.positions :: { [string]: Ledger.Position })[tk]
		local p = prices[tk]
		if pos and type(p) == "number" and p > 0 then
			local long = pos.shares > 0
			local stop, take = s.stop, s.take
			if stop and ((long and p <= stop) or (not long and p >= stop)) then
				table.insert(out, { ticker = tk, kind = "stop", shares = pos.shares })
			elseif take and ((long and p >= take) or (not long and p <= take)) then
				table.insert(out, { ticker = tk, kind = "take", shares = pos.shares })
			end
		end
	end
	table.sort(out, function(a, b)
		return a.ticker < b.ticker
	end)
	return out
end

return Orders
