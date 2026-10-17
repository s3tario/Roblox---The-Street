--!strict
-- Companies (owned by `careerPath`; design v3 §4, contracts §5 and §16). Fictional parodies only. Pure data plus
-- lookup helpers: safe on the server, the client and under Lune.
--
--   Companies.list = { CompanyDef }      every company id from contracts §16 (display order)
--   Companies.get(id) -> CompanyDef?     Companies.byId[id]
--   Companies.hiring(id, trackId) -> HiringDef?
--   Companies.forTrack(trackId) -> { CompanyDef }   available companies that hire for a track
--   Companies.TYPES[type] = { name, payMult, bookMult, prestigeMult, minOutfitLevel, tier }
--
--   CompanyDef = {
--     id, name, short, type, available,
--     departments = { trackId },          tracks it hires for NOW (empty while available = false)
--     plannedDepartments = { trackId },   tracks it will run once its milestone ships
--     colors = { primary, accent, text }  Color3 (hex = the same as "#RRGGBB" strings)
--     logo = id,                          Shared/Assets/Logos id (= company id)
--     tier,                               prestige tier (1 = top)
--     payMult, bookMult, prestigeMult, minOutfitLevel,
--     culture, tagline,
--     bossNames = { [trackId] = name },   the department head who runs your weekly review
--     hiring = { [trackId] = HiringDef },
--   }
--   HiringDef = {
--     anyOf = { Criteria },              eligible when ANY alternative passes ({} = anyone)
--     baseOdds,                          offer chance for an on-bar interview from an average candidate
--     bar,                               interview quality the firm expects (0..100)
--     walkOn = { bar }?,                 always offers to anyone whose Superday reaches `bar`
--   }
--   Criteria = { schoolTier?, gpa?, degree?, stats? = { [statId] = min } }   (all fields must pass)

local Palette = require(script.Parent.Parent.Build.Palette)
local Ib = require(script.IB)
local Others = require(script.Others)

export type Colors = { primary: Color3, accent: Color3, text: Color3 }
export type Criteria = { schoolTier: number?, gpa: number?, degree: string?, stats: { [string]: number }? }
export type HiringDef = { anyOf: { Criteria }, baseOdds: number, bar: number, walkOn: { bar: number }? }
export type TypeDef = {
	name: string,
	payMult: number,
	bookMult: number,
	prestigeMult: number,
	minOutfitLevel: number,
	tier: number,
}
export type CompanyDef = {
	id: string,
	name: string,
	short: string,
	type: string,
	typeName: string,
	available: boolean,
	departments: { string },
	plannedDepartments: { string },
	colors: Colors,
	hex: { primary: string, accent: string, text: string },
	logo: string,
	tier: number,
	payMult: number,
	bookMult: number,
	prestigeMult: number,
	minOutfitLevel: number,
	culture: string,
	tagline: string,
	bossNames: { [string]: string },
	hiring: { [string]: HiringDef },
}

local Companies = {}

-- Company types: v2 §4b multipliers, v3 §5 minimum outfit levels.
Companies.TYPES = {
	bulge = {
		name = "Bulge Bracket",
		payMult = 1.0,
		bookMult = 1.2,
		prestigeMult = 1.3,
		minOutfitLevel = 3,
		tier = 1,
	},
	elite = {
		name = "Elite Boutique",
		payMult = 1.15,
		bookMult = 1.0,
		prestigeMult = 1.4,
		minOutfitLevel = 4,
		tier = 1,
	},
	middle = {
		name = "Middle Market",
		payMult = 0.9,
		bookMult = 0.9,
		prestigeMult = 1.0,
		minOutfitLevel = 3,
		tier = 2,
	},
	regional = {
		name = "Regional",
		payMult = 0.8,
		bookMult = 0.8,
		prestigeMult = 0.8,
		minOutfitLevel = 2,
		tier = 3,
	},
	-- Later milestones (M5+): values are provisional until those tracks ship.
	asset_manager = {
		name = "Asset Manager",
		payMult = 1.05,
		bookMult = 1.3,
		prestigeMult = 1.2,
		minOutfitLevel = 3,
		tier = 1,
	},
	private_equity = {
		name = "Private Equity",
		payMult = 1.2,
		bookMult = 1.1,
		prestigeMult = 1.4,
		minOutfitLevel = 4,
		tier = 1,
	},
	private_credit = {
		name = "Private Credit",
		payMult = 1.05,
		bookMult = 1.1,
		prestigeMult = 1.1,
		minOutfitLevel = 3,
		tier = 2,
	},
	hedge_fund = {
		name = "Hedge Fund",
		payMult = 1.15,
		bookMult = 1.4,
		prestigeMult = 1.3,
		minOutfitLevel = 3,
		tier = 1,
	},
	wealth = {
		name = "Wealth Management",
		payMult = 1.0,
		bookMult = 1.0,
		prestigeMult = 1.1,
		minOutfitLevel = 4,
		tier = 2,
	},
	venture = {
		name = "Venture Capital",
		payMult = 1.0,
		bookMult = 0.9,
		prestigeMult = 1.2,
		minOutfitLevel = 3,
		tier = 1,
	},
	real_estate = {
		name = "Real Estate",
		payMult = 0.95,
		bookMult = 1.0,
		prestigeMult = 1.0,
		minOutfitLevel = 3,
		tier = 2,
	},
	corporate = {
		name = "Corporation",
		payMult = 0.85,
		bookMult = 0.8,
		prestigeMult = 0.9,
		minOutfitLevel = 2,
		tier = 3,
	},
} :: { [string]: TypeDef }

local function hexColor(s: string): Color3
	return Palette.hex(s)
end

Companies.list = {} :: { CompanyDef }
Companies.byId = {} :: { [string]: CompanyDef }

local function add(def: { [string]: any })
	local id = def.id :: string
	assert(Companies.byId[id] == nil, "Companies: duplicate id " .. id)
	local typeDef = Companies.TYPES[def.type]
	assert(typeDef ~= nil, ("Companies: %s has unknown type %s"):format(id, tostring(def.type)))
	local available = def.available ~= false
	local hex = def.colors :: { primary: string, accent: string, text: string }
	local hiring: { [string]: HiringDef } = {}
	for trackId, h in (def.hiring or {}) :: { [string]: any } do
		local anyOf: { Criteria } = {}
		for _, c in (h.anyOf or { {} }) :: { any } do
			table.insert(anyOf, {
				schoolTier = c.schoolTier,
				gpa = c.gpa,
				degree = c.degree,
				stats = c.stats,
			})
		end
		hiring[trackId] = {
			anyOf = anyOf,
			baseOdds = h.baseOdds or 0.3,
			bar = h.bar or 60,
			walkOn = h.walkOn,
		}
	end
	local company: CompanyDef = {
		id = id,
		name = def.name,
		short = def.short or def.name,
		type = def.type,
		typeName = typeDef.name,
		available = available,
		departments = if available then table.clone(def.departments or {}) else {},
		plannedDepartments = table.clone(def.plannedDepartments or def.departments or {}),
		colors = {
			primary = hexColor(hex.primary),
			accent = hexColor(hex.accent),
			text = hexColor(hex.text),
		},
		hex = { primary = hex.primary, accent = hex.accent, text = hex.text },
		logo = id,
		tier = def.tier or typeDef.tier,
		payMult = def.payMult or typeDef.payMult,
		bookMult = def.bookMult or typeDef.bookMult,
		prestigeMult = def.prestigeMult or typeDef.prestigeMult,
		minOutfitLevel = def.minOutfitLevel or typeDef.minOutfitLevel,
		culture = def.culture or "",
		tagline = def.tagline or "",
		bossNames = table.clone(def.bossNames or {}),
		hiring = if available then hiring else {},
	}
	table.insert(Companies.list, company)
	Companies.byId[id] = company
end

for _, def in Ib do
	add(def)
end
for _, def in Others do
	add(def)
end

function Companies.get(id: any): CompanyDef?
	if type(id) ~= "string" then
		return nil
	end
	return Companies.byId[id]
end

function Companies.hires(company: CompanyDef, trackId: string): boolean
	return company.available and table.find(company.departments, trackId) ~= nil
end

function Companies.hiring(id: any, trackId: any): HiringDef?
	local c = Companies.get(id)
	if not c or type(trackId) ~= "string" or not Companies.hires(c, trackId) then
		return nil
	end
	return c.hiring[trackId]
end

function Companies.forTrack(trackId: string): { CompanyDef }
	local out: { CompanyDef } = {}
	for _, c in Companies.list do
		if Companies.hires(c, trackId) then
			table.insert(out, c)
		end
	end
	return out
end

-- The department head for a company and track (falls back to a neutral title).
function Companies.bossName(id: any, trackId: any): string
	local c = Companies.get(id)
	if c and type(trackId) == "string" then
		local n = c.bossNames[trackId]
		if n then
			return n
		end
	end
	return "your managing director"
end

return Companies
