--!strict
-- PortfolioService remotes (RUNTIME ONLY, server). Every argument is validated with Guard (and the order shape with
-- Logic/Portfolio/Desk.parseOrder) before it reaches the service; the service re-checks everything against live
-- prices, limits and the book. Error keys are Tickers.strings suffixes after "err_".
--
--   "Portfolio.Trade"(order, txnId) -> ok, errKey?, payload?
--       order = { ticker, side = "buy" | "sell" | "close", qty?, fit?, stop?, take? }; txnId = Guard.id string
--       payload = { trade, summary, replayed } on success, { vars } on refusal (placeholders for the message)
--   "Portfolio.SetStops"(ticker, stop?, take?) -> ok, errKey?          nil levels clear them
--   "Portfolio.Flatten"(txnId) -> ok, errKey?, closedCount?            "Flatten all" (open session only)
--   "Portfolio.Panel"() -> { week, curve, skill, summary, limits }?    the Terminal's account / risk panel
--   "Portfolio.UseCapitalCredit"() -> ok, errKey?, amount?             Capital Reconstruction after a wipeout

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local Tickers = require(Shared.Config.Tickers)
local Desk = require(Shared.Logic.Portfolio.Desk)
local Txn = require(Shared.Logic.Portfolio.Txn)
local Deps = require(script.Parent.Parent.MarketService.Deps)
local Session = require(script.Parent.Session)

local Remotes = {}

local function level(x: any): (boolean, number?)
	if x == nil then
		return true, nil
	end
	local n = Guard.num(x, 0.01, 1e7)
	if n == nil then
		return false, nil
	end
	return true, n
end

function Remotes.bind(service: any)
	Net.handle("Portfolio.Trade", function(player: Player, rawOrder: any, rawTxn: any): (boolean, string?, any)
		local txn = Guard.id(rawTxn)
		if not txn then
			return false, "generic", nil
		end
		local raw = Guard.map(rawOrder, 12, 1)
		if not raw then
			return false, "generic", nil
		end
		local order, err = Desk.parseOrder(raw)
		if not order then
			return false, err or "generic", nil
		end
		return service:Trade(player, order, txn)
	end, { rate = 3, burst = 8 })

	Net.handle("Portfolio.SetStops", function(player: Player, rawTicker: any, rawStop: any, rawTake: any): (boolean, string?)
		local ticker = Guard.id(rawTicker)
		if not ticker or not Tickers.get(ticker) then
			return false, "bad_ticker"
		end
		local okStop, stop = level(rawStop)
		if not okStop then
			return false, "bad_stop"
		end
		local okTake, take = level(rawTake)
		if not okTake then
			return false, "bad_take"
		end
		return service:SetStops(player, ticker, stop, take)
	end, { rate = 2, burst = 6 })

	Net.handle("Portfolio.Flatten", function(player: Player, rawTxn: any): (boolean, string?, number?)
		local txn = Guard.id(rawTxn)
		local ps = Session.get(player)
		if not txn or not ps then
			return false, if ps then "generic" else "not_loaded", nil
		end
		local key = "flatten:" .. txn
		local seen = Txn.get(ps.cache, key)
		if seen ~= nil then
			return true, nil, seen
		end
		if not Session.marketOpen() then
			return false, if Session.marketPhase() == "closed" then "holiday" else "closed", nil
		end
		local n = service:FlattenAll(player, "flatten")
		Txn.put(ps.cache, key, n)
		return true, nil, n
	end, { rate = 1, burst = 3 })

	Net.handle("Portfolio.Panel", function(player: Player): any
		return service:GetPanel(player)
	end, { rate = 1, burst = 4 })

	Net.handle("Portfolio.UseCapitalCredit", function(player: Player): (boolean, string?, number?)
		-- CareerService owns the recovery bookkeeping (career.fired.capitalUsed) and calls back into this service
		local career = Deps.service("CareerService")
		if career and type(career.UseCapitalCredit) == "function" then
			local ok, a, b = pcall(career.UseCapitalCredit, career, player)
			if ok and a == true then
				return true, nil, nil
			end
			local key = if ok and type(b) == "string" then b else "generic"
			return false, if Tickers.hasText("err_" .. key) then key else "generic", nil
		end
		local result, err = service:UseCapitalCredit(player, nil)
		if type(result) == "number" then
			return true, nil, result
		end
		return false, err or "generic", nil
	end, { rate = 0.5, burst = 2 })
end

return Remotes
