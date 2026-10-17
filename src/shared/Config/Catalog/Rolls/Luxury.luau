--!strict
-- Catalog/Rolls: Legendary and Mythic Life Roll brands (Tom Fordham, Zegnatti, Bruno Cucina; Pan Miller). Item and look definitions only; Rolls/init.luau fills in the roll fields
-- (currency "roll", category, price 0, the level from the rarity) and Catalog/init.luau the rest of the schema.
-- colors.trim is the colour of the brand's signature details (emblems, monograms, pocket squares).

local function c(primary: string, secondary: string?, accent: string?, trim: string?): { [string]: string? }
	return { primary = primary, secondary = secondary, accent = accent, trim = trim }
end

local items: { { [string]: any } } = {}
local looks: { { id: string, brand: string, name: string, itemIds: { string } } } = {}

local function brand(brandId: string, rarity: string, defs: { { [string]: any } })
	for _, d in defs do
		d.brand = brandId
		d.rarity = rarity
		table.insert(items, d)
	end
end

local function look(id: string, brandId: string, name: string, itemIds: { string })
	table.insert(looks, { id = id, brand = brandId, name = name, itemIds = itemIds })
end

brand("tom_fordham", "legendary", {
	{
		id = "tf_velvet_tux",
		name = "Tom Fordham Velvet Tuxedo Jacket",
		slot = "outer",
		builder = "jacket",
		style = "shawl",
		finish = "velvet",
		colors = c("#0F4A3A", "#0C0C0E", "#F4F4F0"),
		desc = "Emerald velvet with black satin shawl lapels.",
	},
	{
		id = "tf_dress_shirt",
		name = "Tom Fordham Dress Shirt",
		slot = "top",
		builder = "shirt",
		colors = c("#F7F7F4", "#E9E9E5", "#1A1A1C"),
		desc = "Crisp white cotton with onyx studs.",
	},
	{
		id = "tf_bowtie",
		name = "Tom Fordham Silk Bow Tie",
		slot = "neck",
		builder = "bowtie",
		colors = c("#0E0E10", "#08080A", "#1A1A1C"),
		desc = "Black barathea silk bow tie.",
	},
	{
		id = "tf_evening_trousers",
		name = "Tom Fordham Evening Trousers",
		slot = "bottom",
		builder = "trousers",
		style = "evening",
		colors = c("#121214", "#0A0A0B", "#0A0A0B"),
		desc = "Black trousers with a satin side stripe.",
	},
	{
		id = "tf_patent_oxford",
		name = "Tom Fordham Patent Oxfords",
		slot = "shoes",
		builder = "oxford",
		finish = "patent",
		colors = c("#0C0C0D", "#070707", "#1C1C1E"),
		desc = "Mirror-black patent oxfords.",
	},
})
look(
	"tf_black_tie",
	"tom_fordham",
	"Tom Fordham Black Tie",
	{ "tf_dress_shirt", "tf_velvet_tux", "tf_evening_trousers", "tf_patent_oxford", "tf_bowtie" }
)

brand("zegnatti", "legendary", {
	{
		id = "zg_jacket",
		name = "Zegnatti Trofeo Suit Jacket",
		slot = "outer",
		builder = "jacket",
		style = "two_button",
		colors = c("#46566E", "#3A4860", "#E9EEF5"),
		desc = "Feather-light blue-grey wool from the family mill.",
	},
	{
		id = "zg_trousers",
		name = "Zegnatti Trofeo Suit Trousers",
		slot = "bottom",
		builder = "trousers",
		style = "suit",
		colors = c("#46566E", "#2A1E16", "#C0C4C8"),
		desc = "Matching blue-grey trousers, pressed sharp.",
	},
	{
		id = "zg_shirt_sky",
		name = "Zegnatti Sky Poplin Shirt",
		slot = "top",
		builder = "shirt",
		colors = c("#CFE0F2", "#BDD0E6", "#F4F4F0"),
		desc = "Sky-blue two-ply poplin.",
	},
	{
		id = "zg_knit_tie",
		name = "Zegnatti Silk Knit Tie, Navy",
		slot = "neck",
		builder = "tie",
		style = "knit",
		colors = c("#1C2846", "#141E36", "#26345A"),
		desc = "Square-ended navy silk knit.",
	},
	{
		id = "zg_tassel_suede",
		name = "Zegnatti Suede Tassel Loafers",
		slot = "shoes",
		builder = "loafer",
		style = "tassel",
		finish = "suede",
		colors = c("#4A3022", "#21150E", "#6B4A33"),
		desc = "Chocolate suede tassel loafers.",
	},
})
look(
	"zg_milano",
	"zegnatti",
	"Zegnatti Milano",
	{ "zg_shirt_sky", "zg_jacket", "zg_trousers", "zg_tassel_suede", "zg_knit_tie" }
)

brand("bruno_cucina", "legendary", {
	{
		id = "bc_blazer_taupe",
		name = "Bruno Cucina Cashmere Blazer",
		slot = "outer",
		builder = "blazer",
		colors = c("#8C7B68", "#7A6A58", "#5A4A3A"),
		desc = "Unlined taupe cashmere that drapes like a cardigan.",
	},
	{
		id = "bc_cashmere_crew",
		name = "Bruno Cucina Cashmere Crew",
		slot = "top",
		builder = "sweater",
		colors = c("#D8CCB6", "#C8BBA3", "#D8CCB6"),
		desc = "Oatmeal twelve-ply cashmere.",
	},
	{
		id = "bc_flannel_cream",
		name = "Bruno Cucina Cream Flannel Trousers",
		slot = "bottom",
		builder = "trousers",
		colors = c("#E3DACA", "#6B4A33", "#B8933F"),
		desc = "Winter-white flannel on a suede belt.",
	},
	{
		id = "bc_suede_sneaker",
		name = "Bruno Cucina Suede Sneakers",
		slot = "shoes",
		builder = "sneaker",
		finish = "suede",
		colors = c("#C8B79C", "#F1EEE6", "#8C7B68"),
		desc = "Sand suede low-tops on cream soles.",
	},
	{
		id = "bc_scarf",
		name = "Bruno Cucina Cashmere Scarf",
		slot = "neck",
		builder = "scarf",
		colors = c("#9A9590", "#86817C", "#B3AEA8"),
		desc = "A fog-grey cashmere scarf, looped once.",
	},
})
look(
	"bc_quiet_luxury",
	"bruno_cucina",
	"Bruno Cucina Quiet Luxury",
	{ "bc_cashmere_crew", "bc_blazer_taupe", "bc_flannel_cream", "bc_suede_sneaker", "bc_scarf" }
)

---------------------------------------------------------------------------------------------------
-- Mythic: the Pan Miller Signature look (exactly one)
---------------------------------------------------------------------------------------------------
brand("pan_miller", "mythic", {
	{
		id = "pm_jacket",
		name = "Pan Miller Signature Jacket",
		slot = "outer",
		builder = "jacket",
		style = "pan_miller",
		pattern = "pinstripe",
		details = { "lapel_pin", "emblem_windmill" },
		colors = c("#1A2233", "#141B2A", "#D4AF37", "#7A1428"),
		desc = "Hand-cut chalk-stripe double-breasted: gold crest buttons, a crest lapel pin, a claret silk square "
			.. "and the little Pan Miller windmill.",
	},
	{
		id = "pm_shirt",
		name = "Pan Miller Monogrammed Shirt",
		slot = "top",
		builder = "shirt",
		details = { "monogram_cuff", "emblem_windmill" },
		colors = c("#FAF9F5", "#ECEAE3", "#F4F1E8", "#7A1428"),
		desc = "Sea-island cotton with a claret PM monogram on the cuff and a windmill on the chest.",
	},
	{
		id = "pm_trousers",
		name = "Pan Miller Signature Trousers",
		slot = "bottom",
		builder = "trousers",
		style = "suit",
		pattern = "pinstripe",
		colors = c("#1A2233", "#2A1E16", "#D4AF37"),
		desc = "Chalk-stripe trousers with a gold buckle.",
	},
	{
		id = "pm_tie",
		name = "Pan Miller Silk Tie & Gold Bar",
		slot = "neck",
		builder = "tie",
		style = "bar",
		colors = c("#7A1428", "#5E0F1F", "#D4AF37"),
		desc = "Claret seven-fold silk held by a windmill-engraved gold bar.",
	},
	{
		id = "pm_oxford",
		name = "Pan Miller Mirror-Shine Wholecuts",
		slot = "shoes",
		builder = "oxford",
		style = "wholecut",
		colors = c("#3A1416", "#140809", "#5A2024"),
		desc = "Oxblood wholecuts polished to a mirror.",
	},
	{
		id = "pm_watch",
		name = "Pan Miller Signature Chronometer",
		slot = "wrist",
		builder = "watch",
		style = "gold",
		colors = c("#D4AF37", "#2A1A12", "#F4EEDC"),
		desc = "Rose-gold chronometer on oxblood alligator.",
	},
})
look(
	"pm_signature",
	"pan_miller",
	"The Pan Miller Signature",
	{ "pm_shirt", "pm_jacket", "pm_trousers", "pm_oxford", "pm_tie", "pm_watch" }
)

return { items = items, looks = looks }
