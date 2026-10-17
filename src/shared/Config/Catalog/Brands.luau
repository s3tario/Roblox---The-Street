--!strict
-- Catalog: clothing brands and rarity tiers (owner v2, spec §4 "Starting outfit roll"). All names are fictional
-- parodies. Every catalog item carries a `brand` id from this table and a `rarity`.
--
--   brands[brandId] = { id, name, rarity, blurb, roll, signature }
--     roll = true      a Life Roll brand: its items are currency "roll" and always have the brand's rarity
--     roll = false     a house label sold in the world's shops (or a premium/family line); item rarity follows
--                      the item's tier unless the item sets one
--     signature        the details that make the brand recognisable (shown in the wardrobe's brand line)
--   RARITIES           ids in ascending order
--   RARITY[id]         { id, order, name, color ("#RRGGBB"), color2? (second gradient colour, mythic) }
-- Pure data. The career-owned Config/Rarity (odds and the shared rarity UI) matches these ids and colours.

export type Brand = {
	id: string,
	name: string,
	rarity: string,
	blurb: string,
	roll: boolean,
	signature: string,
}
export type RarityDef = { id: string, order: number, name: string, color: string, color2: string? }

local Brands = {}

Brands.RARITIES = { "common", "uncommon", "rare", "legendary", "mythic" }

Brands.RARITY = {
	common = { id = "common", order = 1, name = "Common", color = "#9AA0A6" },
	uncommon = { id = "uncommon", order = 2, name = "Uncommon", color = "#4CAF6A" },
	rare = { id = "rare", order = 3, name = "Rare", color = "#3D7DD8" },
	legendary = { id = "legendary", order = 4, name = "Legendary", color = "#D4AF37" },
	mythic = { id = "mythic", order = 5, name = "Mythic", color = "#D946EF", color2 = "#22D3EE" },
} :: { [string]: RarityDef }

-- Rarity of a house-label item by tier (1-5). Mythic is reserved for the William Kingsley look and the
-- Vanderfeller heirloom.
Brands.TIER_RARITY = { "common", "uncommon", "rare", "legendary", "legendary" }

local list: { Brand } = {
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
		id = "william_kingsley",
		name = "William Kingsley",
		rarity = "mythic",
		roll = true,
		blurb = "One look, cut by hand, worn by very few.",
		signature = "Chalk-stripe double-breasted, gold buttons, crest lapel pin, claret silk square.",
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

Brands.list = list
Brands.brands = {} :: { [string]: Brand }
for _, b in list do
	assert(Brands.brands[b.id] == nil, "Brands: duplicate brand " .. b.id)
	assert(Brands.RARITY[b.rarity] ~= nil, "Brands: bad rarity for " .. b.id)
	Brands.brands[b.id] = b
end

return Brands
