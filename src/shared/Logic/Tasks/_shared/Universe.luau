--!strict
-- The fictional business world work tasks draw from (owned by `work`). PURE. Fictional names only: the ten
-- listed companies are the per-server market's tickers (spec §7); everything else is generated from parts.
--
--   Universe.LISTED = { {ticker, name, sector} }          the market's ten companies
--   Universe.SECTORS[sectorId] = { name, evEbitda = {lo, hi}, margin = {lo, hi}, growth = {lo, hi}, pe = {lo, hi} }
--   Universe.company(rng, sectorId?) -> { name, sector, sectorName }   a private company (deal target, client)
--   Universe.peers(rng, sectorId, n, exclude?) -> { string }           distinct peer names in one sector
--   Universe.person(rng) -> "Priya Lindqvist"                          Universe.first(rng) / Universe.last(rng)
--   Universe.sectorIds -> { string }
--   Universe.listed(rng) -> { ticker, name, sector }
--   Universe.FIRMS / Universe.firm(rng, exclude?) -> string            the parody IB firms (design v3 §4)
--   Universe.codename(rng) -> "Project Falcon"                        deal codenames
--   Universe.month(rng) -> "March"

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)

export type Sector = {
	name: string,
	evEbitda: { number },
	margin: { number },
	growth: { number },
	pe: { number },
	suffixes: { string },
}

local Universe = {}

Universe.LISTED = {
	{ ticker = "APX", name = "Apex AI", sector = "tech" },
	{ ticker = "NMB", name = "Nimbus Cloud", sector = "software" },
	{ ticker = "MRB", name = "Meridian Bank", sector = "financials" },
	{ ticker = "VLT", name = "Volt Automotive", sector = "autos" },
	{ ticker = "SMT", name = "Summit Properties", sector = "realestate" },
	{ ticker = "TTN", name = "Titan Energy", sector = "energy" },
	{ ticker = "HBR", name = "Harbor Health", sector = "healthcare" },
	{ ticker = "CRL", name = "Crestline Retail", sector = "consumer" },
	{ ticker = "ORN", name = "Orion Aerospace", sector = "industrials" },
	{ ticker = "BLF", name = "Bluefin Foods", sector = "staples" },
}

Universe.SECTORS = {
	tech = {
		name = "Technology",
		evEbitda = { 16, 24 },
		margin = { 0.22, 0.34 },
		growth = { 0.12, 0.25 },
		pe = { 24, 36 },
		suffixes = { "Robotics", "Analytics", "Systems", "Semiconductor" },
	},
	software = {
		name = "Software",
		evEbitda = { 15, 22 },
		margin = { 0.24, 0.36 },
		growth = { 0.14, 0.28 },
		pe = { 26, 40 },
		suffixes = { "Software", "Cloud", "Labs", "Data" },
	},
	healthcare = {
		name = "Healthcare",
		evEbitda = { 11, 16 },
		margin = { 0.16, 0.26 },
		growth = { 0.05, 0.12 },
		pe = { 18, 26 },
		suffixes = { "Health", "Medical", "Biotech", "Diagnostics" },
	},
	industrials = {
		name = "Industrials",
		evEbitda = { 8, 12 },
		margin = { 0.12, 0.2 },
		growth = { 0.03, 0.08 },
		pe = { 14, 20 },
		suffixes = { "Industrial", "Machinery", "Aerospace", "Controls" },
	},
	consumer = {
		name = "Consumer",
		evEbitda = { 8, 12 },
		margin = { 0.1, 0.18 },
		growth = { 0.03, 0.09 },
		pe = { 15, 22 },
		suffixes = { "Retail", "Brands", "Outfitters", "Home" },
	},
	staples = {
		name = "Consumer Staples",
		evEbitda = { 10, 14 },
		margin = { 0.14, 0.2 },
		growth = { 0.02, 0.05 },
		pe = { 17, 23 },
		suffixes = { "Foods", "Beverages", "Household", "Farms" },
	},
	energy = {
		name = "Energy",
		evEbitda = { 5, 8 },
		margin = { 0.18, 0.32 },
		growth = { 0.0, 0.06 },
		pe = { 8, 13 },
		suffixes = { "Energy", "Power", "Renewables", "Midstream" },
	},
	logistics = {
		name = "Logistics",
		evEbitda = { 8, 11 },
		margin = { 0.09, 0.15 },
		growth = { 0.04, 0.09 },
		pe = { 14, 19 },
		suffixes = { "Logistics", "Freight", "Shipping", "Distribution" },
	},
	media = {
		name = "Media",
		evEbitda = { 7, 11 },
		margin = { 0.15, 0.25 },
		growth = { 0.02, 0.08 },
		pe = { 12, 18 },
		suffixes = { "Media", "Studios", "Publishing", "Broadcast" },
	},
	autos = {
		name = "Autos",
		evEbitda = { 6, 9 },
		margin = { 0.08, 0.14 },
		growth = { 0.02, 0.1 },
		pe = { 8, 14 },
		suffixes = { "Motors", "Mobility", "Auto Parts", "EV" },
	},
	financials = {
		name = "Financials",
		evEbitda = { 8, 12 },
		margin = { 0.25, 0.35 },
		growth = { 0.03, 0.07 },
		pe = { 9, 13 },
		suffixes = { "Financial", "Payments", "Insurance", "Capital" },
	},
	realestate = {
		name = "Real Estate",
		evEbitda = { 14, 19 },
		margin = { 0.45, 0.6 },
		growth = { 0.02, 0.05 },
		pe = { 16, 24 },
		suffixes = { "Properties", "Realty", "Estates", "Storage" },
	},
} :: { [string]: Sector }

Universe.sectorIds = {
	"tech",
	"software",
	"healthcare",
	"industrials",
	"consumer",
	"staples",
	"energy",
	"logistics",
	"media",
	"autos",
	"financials",
	"realestate",
}

-- Name parts chosen to read as invented businesses, not real ones.
local PREFIXES = {
	"Ashgrove",
	"Brightmoor",
	"Calderon",
	"Duskwater",
	"Emberly",
	"Fernhollow",
	"Glasswing",
	"Hollowpine",
	"Ironvale",
	"Juniper Ridge",
	"Kestrelmark",
	"Larkspur",
	"Moorfield",
	"Nettlecombe",
	"Oakhaven",
	"Pemberton",
	"Quillmont",
	"Rookwood",
	"Saltmarsh",
	"Thistledown",
	"Umberfield",
	"Vexley",
	"Wrenfield",
	"Yarrowby",
	"Cobblestone",
	"Driftmark",
	"Foxglove",
	"Heronsgate",
}

local FIRST = {
	"Avery",
	"Jordan",
	"Priya",
	"Marcus",
	"Elena",
	"Tomas",
	"Grace",
	"Kenji",
	"Olivia",
	"Rafael",
	"Noor",
	"Daniel",
	"Sofia",
	"Malik",
	"Hannah",
	"Victor",
	"Leah",
	"Omar",
	"Chloe",
	"Felix",
	"Imani",
	"Henrik",
	"Mei",
	"Callum",
}

local LAST = {
	"Whitcombe",
	"Okoro",
	"Lindqvist",
	"Castellano",
	"Brandt",
	"Mercer",
	"Halloway",
	"Nakamura",
	"Delacroix",
	"Fairbanks",
	"Osei",
	"Ramsay",
	"Thornbury",
	"Vasquez",
	"Kowalczyk",
	"Abernathy",
	"Sinclaire",
	"Moreau",
	"Ashdown",
	"Pellegrini",
	"Adeyemi",
	"Hargreave",
}

function Universe.first(rng: Rng.Rng): string
	return rng:pick(FIRST)
end

function Universe.last(rng: Rng.Rng): string
	return rng:pick(LAST)
end

function Universe.person(rng: Rng.Rng): string
	return rng:pick(FIRST) .. " " .. rng:pick(LAST)
end

function Universe.sector(id: string): Sector
	return Universe.SECTORS[id] or Universe.SECTORS.industrials
end

function Universe.company(rng: Rng.Rng, sectorId: string?): { name: string, sector: string, sectorName: string }
	local sid = sectorId or rng:pick(Universe.sectorIds)
	local s = Universe.sector(sid)
	return { name = rng:pick(PREFIXES) .. " " .. rng:pick(s.suffixes), sector = sid, sectorName = s.name }
end

function Universe.peers(rng: Rng.Rng, sectorId: string, n: number, exclude: { string }?): { string }
	local s = Universe.sector(sectorId)
	local seen: { [string]: boolean } = {}
	if exclude then
		for _, name in exclude do
			seen[name] = true
		end
	end
	local out: { string } = {}
	local prefixes = rng:shuffle(PREFIXES)
	local i = 0
	while #out < n and i < #prefixes do
		i += 1
		local name = prefixes[i] .. " " .. s.suffixes[((i - 1) % #s.suffixes) + 1]
		if not seen[name] then
			seen[name] = true
			table.insert(out, name)
		end
	end
	return out
end

function Universe.listed(rng: Rng.Rng): { ticker: string, name: string, sector: string }
	return rng:pick(Universe.LISTED)
end

-- Parody bank names from design v3 §4 (Config/Companies owns the full records; tasks only need names).
Universe.FIRMS = {
	"MG Freeman",
	"Goldfield Saxe",
	"Morrow Stanton",
	"Merriweather Lynch",
	"Evermoor",
	"Lazaro Frères",
	"Centerline",
	"Harrow Williams",
	"Blairmont",
	"Houlton Lockey",
	"Sterling & Vance",
	"Eastbridge Capital",
}

function Universe.firm(rng: Rng.Rng, exclude: string?): string
	local pool: { string } = {}
	for _, f in Universe.FIRMS do
		if f ~= exclude then
			table.insert(pool, f)
		end
	end
	return rng:pick(pool)
end

local CODENAMES = {
	"Falcon",
	"Bluebird",
	"Granite",
	"Lantern",
	"Meridian",
	"Northstar",
	"Orchid",
	"Pinnacle",
	"Quartz",
	"Redwood",
	"Sapphire",
	"Tidewater",
	"Wildcat",
	"Atlas",
	"Beacon",
	"Copperhead",
	"Driftwood",
	"Evergreen",
	"Harbor",
	"Ironbark",
}

function Universe.codename(rng: Rng.Rng): string
	return "Project " .. rng:pick(CODENAMES)
end

local MONTHS = {
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
}
Universe.MONTHS = MONTHS

function Universe.month(rng: Rng.Rng): string
	return rng:pick(MONTHS)
end

return Universe
