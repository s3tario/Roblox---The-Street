--!strict
-- Tickers (owned by `market`; spec §7, design v3 §11, contracts §6): the ten fictional listed companies, their
-- sectors and the STREET 10 benchmark. Pure data plus small lookup helpers: safe on the server, the client and
-- under Lune. Every name here is fictional.
--
--   Tickers.IDS = { "APX", ..., "BLF" }        display order (also the order of prices in Market.Tick)
--   Tickers.list = { TickerDef }               Tickers.get(id) -> TickerDef?   Tickers.index(id) -> 1..10?
--   Tickers.sectors[id] = SectorDef            Tickers.sector(id) -> SectorDef?
--   Tickers.BENCHMARK = { id = "ST10", name, base }
--   Tickers.EARNINGS_EVERY (8 market days)     Tickers.CONSENSUS_LEAD (2 days before the report)
--   Tickers.basePrice(def) -> number           EPS x P/E at the fundamentals below
--   Tickers.text(key, vars?) -> string         player-facing strings (Tickers/Strings)
--   Tickers.news                               headline templates (Tickers/News)
--   Tickers.events[id] = EventInfo             market event names and blurbs (Tickers/Events)
--
--   TickerDef = {
--     id, name, sector, desc,
--     shares,          -- shares outstanding (millions)
--     revenue,         -- trailing revenue ($M)
--     netMargin,       -- net income / revenue (drives EPS)
--     ebitdaMargin,    -- EBITDA / revenue
--     debt, cash,      -- balance sheet ($M), for EV
--     pe,              -- the P/E the market pays at fair value
--     beta,            -- sensitivity to the market factor
--     vol,             -- idiosyncratic daily volatility (one market day = 6 minutes)
--     growth,          -- expected EPS growth per quarter (one earnings cycle)
--     dividendYield,
--     earningsOffset,  -- reports on market days where (day - offset) % EARNINGS_EVERY == 0 (staggered)
--     memeable,        -- candidate for a Meme Rally
--   }

local Strings: { [string]: string } = require(script.Strings) :: any
local News = require(script.News)
local Events = require(script.Events)

export type TickerDef = {
	id: string,
	name: string,
	sector: string,
	desc: string,
	shares: number,
	revenue: number,
	netMargin: number,
	ebitdaMargin: number,
	debt: number,
	cash: number,
	pe: number,
	beta: number,
	vol: number,
	growth: number,
	dividendYield: number,
	earningsOffset: number,
	memeable: boolean,
}

export type SectorDef = {
	id: string,
	name: string,
	vol: number, -- daily volatility of the sector factor
	rateSens: number, -- move per unit of a rate shock (negative = falls when rates jump)
	catalysts: { string }, -- catalyst template keys (Tickers/News.catalysts)
}

local Tickers = {}

Tickers.EARNINGS_EVERY = 8
Tickers.CONSENSUS_LEAD = 2
Tickers.BENCHMARK = { id = "ST10", name = "STREET 10", base = 5000 }
Tickers.MARKET_VOL = 0.008 -- daily volatility of the market factor

Tickers.sectors = {
	tech = {
		id = "tech",
		name = "Technology",
		vol = 0.009,
		rateSens = -0.6,
		catalysts = { "chip_export", "ai_summit" },
	},
	financials = {
		id = "financials",
		name = "Financials",
		vol = 0.008,
		rateSens = -1.0,
		catalysts = { "stress_test", "capital_rules" },
	},
	autos = {
		id = "autos",
		name = "Automotive",
		vol = 0.012,
		rateSens = -0.5,
		catalysts = { "ev_credit", "auto_sales" },
	},
	realestate = {
		id = "realestate",
		name = "Real Estate",
		vol = 0.008,
		rateSens = -1.3,
		catalysts = { "housing_data", "zoning_vote" },
	},
	energy = { id = "energy", name = "Energy", vol = 0.012, rateSens = 0.3, catalysts = { "opex_meeting", "pipeline" } },
	healthcare = {
		id = "healthcare",
		name = "Healthcare",
		vol = 0.007,
		rateSens = -0.2,
		catalysts = { "drug_panel", "pricing_bill" },
	},
	consumer = {
		id = "consumer",
		name = "Consumer",
		vol = 0.008,
		rateSens = -0.4,
		catalysts = { "holiday_sales", "consumer_mood" },
	},
	industrials = {
		id = "industrials",
		name = "Industrials",
		vol = 0.009,
		rateSens = -0.3,
		catalysts = { "defense_budget", "airline_orders" },
	},
	staples = { id = "staples", name = "Consumer Staples", vol = 0.006, rateSens = 0.1, catalysts = { "crop_report" } },
} :: { [string]: SectorDef }

Tickers.list = {
	{
		id = "APX",
		name = "Apex AI",
		sector = "tech",
		desc = "Designs the chips and models behind half the city's chatbots. Loved by growth funds, feared by short sellers.",
		shares = 820,
		revenue = 24000,
		netMargin = 0.22,
		ebitdaMargin = 0.34,
		debt = 3000,
		cash = 12000,
		pe = 34,
		beta = 1.35,
		vol = 0.022,
		growth = 0.025,
		dividendYield = 0,
		earningsOffset = 0,
		memeable = false,
	},
	{
		id = "NMB",
		name = "Nimbus Cloud",
		sector = "tech",
		desc = "Rents servers and software by the minute to every startup on Venture Row.",
		shares = 540,
		revenue = 11500,
		netMargin = 0.18,
		ebitdaMargin = 0.29,
		debt = 2200,
		cash = 4800,
		pe = 38,
		beta = 1.25,
		vol = 0.02,
		growth = 0.022,
		dividendYield = 0,
		earningsOffset = 4,
		memeable = true,
	},
	{
		id = "MRB",
		name = "Meridian Bank",
		sector = "financials",
		desc = "A sprawling deposit bank with branches on every corner and a balance sheet the size of a small country.",
		shares = 2100,
		revenue = 62000,
		netMargin = 0.24,
		ebitdaMargin = 0.38,
		debt = 90000,
		cash = 140000,
		pe = 11,
		beta = 1.1,
		vol = 0.015,
		growth = 0.01,
		dividendYield = 0.034,
		earningsOffset = 1,
		memeable = false,
	},
	{
		id = "VLT",
		name = "Volt Automotive",
		sector = "autos",
		desc = "Electric cars, big promises and a founder who posts at 3 a.m. Priced for perfection.",
		shares = 1350,
		revenue = 41000,
		netMargin = 0.07,
		ebitdaMargin = 0.14,
		debt = 9000,
		cash = 16000,
		pe = 42,
		beta = 1.6,
		vol = 0.028,
		growth = 0.03,
		dividendYield = 0,
		earningsOffset = 5,
		memeable = true,
	},
	{
		id = "SMT",
		name = "Summit Properties",
		sector = "realestate",
		desc = "Owns office towers and apartment blocks across downtown. Collects rent, pays a fat dividend.",
		shares = 610,
		revenue = 6800,
		netMargin = 0.3,
		ebitdaMargin = 0.62,
		debt = 21000,
		cash = 900,
		pe = 19,
		beta = 0.85,
		vol = 0.013,
		growth = 0.008,
		dividendYield = 0.045,
		earningsOffset = 2,
		memeable = false,
	},
	{
		id = "TTN",
		name = "Titan Energy",
		sector = "energy",
		desc = "Oil fields, refineries and a growing wind farm business. Moves with crude and politics.",
		shares = 3900,
		revenue = 182000,
		netMargin = 0.085,
		ebitdaMargin = 0.19,
		debt = 38000,
		cash = 22000,
		pe = 10.5,
		beta = 0.95,
		vol = 0.019,
		growth = 0.006,
		dividendYield = 0.038,
		earningsOffset = 6,
		memeable = false,
	},
	{
		id = "HBR",
		name = "Harbor Health",
		sector = "healthcare",
		desc = "Hospitals, clinics and a drug pipeline. Steady earnings with the odd regulatory scare.",
		shares = 1020,
		revenue = 58000,
		netMargin = 0.16,
		ebitdaMargin = 0.27,
		debt = 24000,
		cash = 9000,
		pe = 22,
		beta = 0.75,
		vol = 0.014,
		growth = 0.014,
		dividendYield = 0.017,
		earningsOffset = 3,
		memeable = false,
	},
	{
		id = "CRL",
		name = "Crestline Retail",
		sector = "consumer",
		desc = "Department stores and an online marketplace. Lives and dies by the holiday season.",
		shares = 980,
		revenue = 96000,
		netMargin = 0.045,
		ebitdaMargin = 0.09,
		debt = 12000,
		cash = 7500,
		pe = 24,
		beta = 1.05,
		vol = 0.017,
		growth = 0.012,
		dividendYield = 0.012,
		earningsOffset = 7,
		memeable = true,
	},
	{
		id = "ORN",
		name = "Orion Aerospace",
		sector = "industrials",
		desc = "Builds jet engines, satellites and the occasional rocket. Order books stretch out for years.",
		shares = 430,
		revenue = 31000,
		netMargin = 0.09,
		ebitdaMargin = 0.16,
		debt = 11000,
		cash = 5500,
		pe = 27,
		beta = 1.15,
		vol = 0.018,
		growth = 0.015,
		dividendYield = 0.011,
		earningsOffset = 3,
		memeable = true,
	},
	{
		id = "BLF",
		name = "Bluefin Foods",
		sector = "staples",
		desc = "Canned tuna, frozen dinners and breakfast cereal. Boring on purpose, and that's the point.",
		shares = 1450,
		revenue = 52000,
		netMargin = 0.11,
		ebitdaMargin = 0.19,
		debt = 14000,
		cash = 3200,
		pe = 20,
		beta = 0.6,
		vol = 0.011,
		growth = 0.009,
		dividendYield = 0.029,
		earningsOffset = 1,
		memeable = true,
	},
} :: { TickerDef }

Tickers.IDS = {} :: { string }
Tickers.byId = {} :: { [string]: TickerDef }
local indexOf: { [string]: number } = {}
for i, def in Tickers.list do
	table.insert(Tickers.IDS, def.id)
	Tickers.byId[def.id] = def
	indexOf[def.id] = i
end

function Tickers.get(id: any): TickerDef?
	if type(id) ~= "string" then
		return nil
	end
	return Tickers.byId[id]
end

function Tickers.index(id: any): number?
	if type(id) ~= "string" then
		return nil
	end
	return indexOf[id]
end

function Tickers.sector(id: any): SectorDef?
	if type(id) ~= "string" then
		return nil
	end
	return Tickers.sectors[id]
end

-- Annual EPS from the fundamentals.
function Tickers.baseEps(def: TickerDef): number
	return def.revenue * def.netMargin / def.shares
end

-- Fair price at the listed fundamentals: EPS x P/E.
function Tickers.basePrice(def: TickerDef): number
	return Tickers.baseEps(def) * def.pe
end

Tickers.strings = Strings
Tickers.news = News
Tickers.events = Events.info
Tickers.EVENT_IDS = Events.IDS

local function fill(template: string, vars: { [string]: any }?): string
	if not vars then
		return template
	end
	return (
		string.gsub(template, "{(%w+)}", function(key: string): string
			local v = vars[key]
			if v == nil then
				return "{" .. key .. "}"
			end
			return tostring(v)
		end)
	)
end
Tickers.fill = fill

-- Player-facing text: Tickers.text("err_closed") / Tickers.text("risk_warn", { ticker = "APX" }).
function Tickers.text(key: string, vars: { [string]: any }?): string
	local s = Strings[key]
	if type(s) ~= "string" then
		return key
	end
	return fill(s, vars)
end

function Tickers.hasText(key: string): boolean
	return type(Strings[key]) == "string"
end

return Tickers
