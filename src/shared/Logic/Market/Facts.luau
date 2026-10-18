--!strict
-- Company facts (owned by `market`): the disclosed fundamentals work tasks and the Terminal show. PURE, shared by
-- the server (MarketService:GetCompanyFacts) and the client (the Terminal derives live ratios from the snapshot's
-- fundamentals and the latest price). Money figures are in $ millions except per-share values.
--
--   Facts.derive(fund, price, extra?) -> Facts
--     fund  = { ticker, name, sector, sectorName, desc, shares, eps, revenue, ebitda, netIncome, debt, cash, dps,
--               beta, growth, target }
--     extra = { prevClose?, open?, high?, low?, nextEarnings?, lastEarnings?, chart?, headline? }  copied through
--   Facts = fund + { price, marketCap, pe?, ev, evEbitda?, evRevenue?, netMargin, ebitdaMargin, netDebt,
--                    dividendYield, change?, changePct?, upside? }

export type Fund = {
	ticker: string,
	name: string,
	sector: string,
	sectorName: string,
	desc: string,
	shares: number,
	eps: number,
	revenue: number,
	ebitda: number,
	netIncome: number,
	debt: number,
	cash: number,
	dps: number,
	beta: number,
	growth: number,
	target: number,
}

local Facts = {}

local function round(x: number, places: number): number
	local m = 10 ^ places
	return math.floor(x * m + 0.5) / m
end
Facts.round = round

local function ratio(a: number, b: number): number?
	if b == 0 or b ~= b or a ~= a then
		return nil
	end
	return a / b
end

function Facts.derive(fund: Fund, price: number, extra: { [string]: any }?): { [string]: any }
	local mcap = fund.shares * price
	local ev = mcap + fund.debt - fund.cash
	local pe = if fund.eps > 0 then ratio(price, fund.eps) else nil
	local evEbitda = if fund.ebitda > 0 then ratio(ev, fund.ebitda) else nil
	local out: { [string]: any } = {
		ticker = fund.ticker,
		name = fund.name,
		sector = fund.sector,
		sectorName = fund.sectorName,
		desc = fund.desc,
		price = round(price, 2),
		shares = fund.shares,
		marketCap = round(mcap, 0),
		eps = round(fund.eps, 2),
		pe = if pe then round(pe, 1) else nil,
		revenue = round(fund.revenue, 0),
		ebitda = round(fund.ebitda, 0),
		netIncome = round(fund.netIncome, 0),
		debt = round(fund.debt, 0),
		cash = round(fund.cash, 0),
		netDebt = round(fund.debt - fund.cash, 0),
		ev = round(ev, 0),
		evEbitda = if evEbitda then round(evEbitda, 1) else nil,
		evRevenue = if fund.revenue > 0 then round(ev / fund.revenue, 2) else nil,
		netMargin = if fund.revenue > 0 then round(fund.netIncome / fund.revenue, 4) else 0,
		ebitdaMargin = if fund.revenue > 0 then round(fund.ebitda / fund.revenue, 4) else 0,
		dps = round(fund.dps, 2),
		dividendYield = if price > 0 then round(fund.dps / price, 4) else 0,
		beta = fund.beta,
		growth = fund.growth,
		target = round(fund.target, 2),
		upside = if price > 0 then round(fund.target / price - 1, 4) else 0,
	}
	if extra then
		for k, v in extra do
			if out[k] == nil then
				out[k] = v
			end
		end
		local prev = extra.prevClose
		if type(prev) == "number" and prev > 0 then
			out.change = round(price - prev, 2)
			out.changePct = round(price / prev - 1, 4)
		end
	end
	return out
end

return Facts
