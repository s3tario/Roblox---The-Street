--!strict
-- Catalog: clothing brands and rarity tiers (owner v2, spec §4 "Starting outfit roll"). All names are fictional
-- parodies. Every catalog item carries a `brand` id from this table and a `rarity`.
--
--   brands[brandId] = { id, name, rarity, blurb, roll, signature, logo }
--     roll = true      a Life Roll brand: its items are currency "roll" and always have the brand's rarity
--     roll = false     a house label sold in the world's shops (or a premium/family line); item rarity follows
--                      the item's tier unless the item sets one
--     signature        the details that make the brand recognisable (shown in the wardrobe's brand line)
--     logo             the brand mark's logo id for Shared/Assets/Logos ("brand_<brandId>", contracts §16)
--   RARITIES           ids in ascending order
--   RARITY[id]         { id, order, name, color ("#RRGGBB"), color2? (second gradient colour, mythic) }
--   LEVEL_OF_RARITY    clothing level (1-5) of a Life Roll piece by its rarity (v3 §5)
-- Pure data. The career-owned Config/Rarity (odds and the shared rarity UI) uses the same six ids (v3 §1:
-- common uncommon rare epic legendary mythic) and the same grey/green/blue/purple/gold/prismatic colours.

export type Brand = {
	id: string,
	name: string,
	rarity: string,
	blurb: string,
	roll: boolean,
	signature: string,
	logo: string,
}
export type RarityDef = { id: string, order: number, name: string, color: string, color2: string? }

local Brands = {}

Brands.RARITIES = { "common", "uncommon", "rare", "epic", "legendary", "mythic" }

Brands.RARITY = {
	common = { id = "common", order = 1, name = "Common", color = "#9AA0A6" },
	uncommon = { id = "uncommon", order = 2, name = "Uncommon", color = "#4CAF6A" },
	rare = { id = "rare", order = 3, name = "Rare", color = "#3D7DD8" },
	epic = { id = "epic", order = 4, name = "Epic", color = "#9B5DE5" },
	legendary = { id = "legendary", order = 5, name = "Legendary", color = "#D4AF37" },
	mythic = { id = "mythic", order = 6, name = "Mythic", color = "#D946EF", color2 = "#22D3EE" },
} :: { [string]: RarityDef }

-- Rarity of a house-label item by tier (1-5). Mythic is reserved for the Pan Miller Signature look and the
-- Vanderfeller heirloom.
Brands.TIER_RARITY = { "common", "uncommon", "rare", "epic", "legendary" }

-- Clothing level of a Life Roll piece by its rarity: a better roll is a head start on dress codes (v3 §5).
Brands.LEVEL_OF_RARITY = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 5 } :: {
	[string]: number,
}

type BrandDef = { id: string, name: string, rarity: string, blurb: string, roll: boolean, signature: string }

local defs: { BrandDef } = {
	-- Life Roll brands: Common ---------------------------------------------------------------------
	{
		id = "kevin_kroos",
		name = "Kevin Kroos",
		rarity = "common",
		roll = true,
		blurb = "Minimal basics in black, white and grey.",
		signature = "Clean monochrome cuts with a small chest wordmark.",
	},
	{
		id = "old_harbor",
		name = "Old Harbor",
		rarity = "common",
		roll = true,
		blurb = "Weekend staples in bright, easy colours.",
		signature = "Pocket tees, flannels and canvas low-tops.",
	},
	{
		id = "gapline",
		name = "Gapline",
		rarity = "common",
		roll = true,
		blurb = "Denim, khaki and the arch-logo hoodie.",
		signature = "The arch logo across the chest.",
	},
	{
		id = "hanesworth",
		name = "Hanesworth",
		rarity = "common",
		roll = true,
		blurb = "Heather cotton you can live in.",
		signature = "Heather tees, crew sweats and ribbed joggers.",
	},
	-- Uncommon -------------------------------------------------------------------------------------
	{
		id = "j_crewson",
		name = "J. Crewson",
		rarity = "uncommon",
		roll = true,
		blurb = "Preppy colour and soft tailoring.",
		signature = "Pink oxfords, gingham and suede loafers.",
	},
	{
		id = "plantain_republic",
		name = "Plantain Republic",
		rarity = "uncommon",
		roll = true,
		blurb = "Commuter-smart in olive, stone and navy.",
		signature = "Utility overshirts and merino quarter-zips.",
	},
	{
		id = "tommy_hillford",
		name = "Tommy Hillford",
		rarity = "uncommon",
		roll = true,
		blurb = "Red, white and navy prep.",
		signature = "The little flag emblem and tipped sleeves.",
	},
	-- Rare -----------------------------------------------------------------------------------------
	{
		id = "ralph_lorenzo",
		name = "Ralph Lorenzo",
		rarity = "rare",
		roll = true,
		blurb = "Country-club heritage.",
		signature = "The polo-player emblem and cream cable knits.",
	},
	{
		id = "brooks_brethren",
		name = "Brooks Brethren",
		rarity = "rare",
		roll = true,
		blurb = "The original button-down.",
		signature = "Button-down oxford shirts and repp-stripe ties.",
	},
	{
		id = "vineyard_wines",
		name = "Vineyard Wines",
		rarity = "rare",
		roll = true,
		blurb = "Island weekends in pastel.",
		signature = "Pastel quarter-zips with the whale emblem, boat shoes.",
	},
	{
		id = "patagonio",
		name = "Patagonio",
		rarity = "rare",
		roll = true,
		blurb = "Mountain gear that never leaves Midtown.",
		signature = "The fleece vest with the peak patch.",
	},
	-- Epic -----------------------------------------------------------------------------------------
	{
		id = "briani",
		name = "Briani",
		rarity = "epic",
		roll = true,
		blurb = "Roman tailoring, finished entirely by hand.",
		signature = "Hand-picked lapel stitching, a silk-lined barchetta pocket and horn buttons.",
	},
	{
		id = "canale",
		name = "Canalé",
		rarity = "epic",
		roll = true,
		blurb = "Soft Milanese suiting from a family atelier.",
		signature = "A crescent breast pocket, a rolled lapel and the gold C at the throat.",
	},
	-- Legendary ------------------------------------------------------------------------------------
	{
		id = "tom_fordham",
		name = "Tom Fordham",
		rarity = "legendary",
		roll = true,
		blurb = "Black-tie glamour.",
		signature = "Emerald velvet tuxedo with satin shawl lapels.",
	},
	{
		id = "zegnatti",
		name = "Zegnatti",
		rarity = "legendary",
		roll = true,
		blurb = "Italian mill-to-tailor suiting.",
		signature = "Feather-light blue-grey wool and suede tassel loafers.",
	},
	{
		id = "bruno_cucina",
		name = "Bruno Cucina",
		rarity = "legendary",
		roll = true,
		blurb = "Quiet luxury in cashmere neutrals.",
		signature = "Taupe cashmere layers and suede sneakers.",
	},
	-- Mythic ---------------------------------------------------------------------------------------
	{
		id = "pan_miller",
		name = "Pan Miller",
		rarity = "mythic",
		roll = true,
		blurb = "One look, cut by hand, worn by very few.",
		signature = "Chalk-stripe double-breasted, gold buttons, crest lapel pin, claret silk square and the windmill.",
	},
	-- House labels (shops in the world), premium lines and family pieces -------------------------------
	{
		id = "eastbridge",
		name = "Eastbridge Campus Store",
		rarity = "common",
		roll = false,
		blurb = "Everything a student needs, mostly hoodies.",
		signature = "Maroon and gold school colours.",
	},
	{
		id = "standard_issue",
		name = "Standard Issue",
		rarity = "common",
		roll = false,
		blurb = "Badges and basics handed out on your first day.",
		signature = "Printed ID badges on woven lanyards.",
	},
	{
		id = "hartwell",
		name = "Hartwell Tailors",
		rarity = "rare",
		roll = false,
		blurb = "The Street's tailor since forever.",
		signature = "Worsted suits, shirts, ties and leather goods.",
	},
	{
		id = "hartwell_bespoke",
		name = "Hartwell Bespoke",
		rarity = "legendary",
		roll = false,
		blurb = "Three fittings, one cutter, no two alike.",
		signature = "Hand-padded chests, working cuffs and your initials inside.",
	},
	{
		id = "strider",
		name = "Strider Shoes",
		rarity = "uncommon",
		roll = false,
		blurb = "From court sneakers to bespoke wholecuts.",
		signature = "Hand-burnished leather.",
	},
	{
		id = "vanta",
		name = "Vanta Watches",
		rarity = "rare",
		roll = false,
		blurb = "The status ladder, one wrist at a time.",
		signature = "Steel, bronze, gold and platinum.",
	},
	{
		id = "corner_office",
		name = "Corner Office Collection",
		rarity = "legendary",
		roll = false,
		blurb = "Premium evening and tailoring pieces.",
		signature = "Midnight velvet, cashmere and gold.",
	},
	{
		id = "executive_club",
		name = "Executive Club",
		rarity = "legendary",
		roll = false,
		blurb = "Members only.",
		signature = "Navy and gold with the club crest.",
	},
	{
		id = "family_heirloom",
		name = "Family Heirloom",
		rarity = "rare",
		roll = false,
		blurb = "Passed down, never sold.",
		signature = "Old gold and family crests.",
	},
	{
		id = "staff",
		name = "Staff Uniform",
		rarity = "common",
		roll = false,
		blurb = "Work clothes for the people who keep the city running.",
		signature = "Hard-wearing uniforms.",
	},
}

local list: { Brand } = {}
Brands.list = list
Brands.brands = {} :: { [string]: Brand }
for _, d in defs do
	assert(Brands.brands[d.id] == nil, "Brands: duplicate brand " .. d.id)
	assert(Brands.RARITY[d.rarity] ~= nil, "Brands: bad rarity for " .. d.id)
	local b: Brand = {
		id = d.id,
		name = d.name,
		rarity = d.rarity,
		blurb = d.blurb,
		roll = d.roll,
		signature = d.signature,
		logo = "brand_" .. d.id,
	}
	table.insert(list, b)
	Brands.brands[b.id] = b
end

return Brands
