--!strict
-- Catalog: clothing levels 4 and 5 in every slot (v3 §5): the pieces Elite Boutique, Private Equity and Wealth
-- Management dress codes ask for (Level 4) and what VP-and-up promotions ask for (Level 5). Level 5 suits are the
-- Hartwell Bespoke line at about $8-25k. Cash items; minRank never blocks the next promotion's dress level
-- (a Level 5 piece is never gated above VP, rank 3).
-- Item definitions only (see Catalog/init.luau for the schema). Each entry becomes Catalog.items[id].

local function c(primary: string, secondary: string?, accent: string?, trim: string?): { [string]: string? }
	return { primary = primary, secondary = secondary, accent = accent, trim = trim }
end

local items: { { [string]: any } } = {}
local function add(def: { [string]: any })
	table.insert(items, def)
end

---------------------------------------------------------------------------------------------------
-- Level 4
---------------------------------------------------------------------------------------------------
add({
	id = "shirt_sea_island",
	name = "Sea Island Cotton Dress Shirt",
	slot = "top",
	category = "luxury",
	price = 650,
	builder = "shirt",
	colors = c("#FBFAF7", "#EDECE7", "#FFFFFF"),
	tier = 4,
	tags = { "luxury", "shirt", "formal" },
	desc = "The rarest long-staple cotton, with a cutaway collar and mother-of-pearl buttons.",
})
add({
	id = "qzip_cashmere_camel",
	name = "Baby Cashmere Quarter-Zip, Camel",
	slot = "top",
	category = "luxury",
	price = 1100,
	builder = "quarterzip",
	colors = c("#B48D5C", "#9C7A4E", "#D4AF37"),
	tier = 4,
	tags = { "luxury", "knit", "logo" },
	desc = "Cloud-soft camel cashmere with a gold zip. Shows your company's logo on the chest.",
})
add({
	id = "blouse_charmeuse",
	name = "Silk Charmeuse Blouse, Champagne",
	slot = "top",
	category = "luxury",
	price = 780,
	builder = "blouse",
	colors = c("#E9DCC3", "#DACBAE", "#F7F3EA"),
	tier = 4,
	tags = { "luxury", "womens", "silk" },
	desc = "Liquid champagne silk with covered buttons.",
})
add({
	id = "vest_cashmere_gilet",
	name = "Cashmere Gilet, Charcoal",
	slot = "outer",
	category = "luxury",
	price = 1600,
	builder = "vest",
	style = "fleece",
	colors = c("#34373D", "#2A2D32", "#B8BCC2"),
	tier = 4,
	tags = { "luxury", "layer", "finance", "logo" },
	desc = "Charcoal cashmere gilet with a two-way zip. Shows your company's logo on the chest.",
})
add({
	id = "trousers_fresco",
	name = "Fresco Wool Trousers, Navy",
	slot = "bottom",
	category = "suits",
	price = 1200,
	builder = "trousers",
	style = "suit",
	colors = c("#1E2A47", "#1A1512", "#C0C4C8"),
	tier = 4,
	tags = { "suits", "tailoring" },
	desc = "High-twist fresco wool that never wrinkles, cut with a side-adjuster waist.",
})
add({
	id = "skirt_crepe_navy",
	name = "Wool Crepe Pencil Skirt, Navy",
	slot = "bottom",
	category = "luxury",
	price = 1100,
	builder = "pencil_skirt",
	colors = c("#1F2A44", "#18213A", "#141414"),
	tier = 4,
	tags = { "luxury", "womens", "tailoring" },
	desc = "Navy wool crepe, lined in silk, with a hand-finished back vent.",
})
add({
	id = "loafer_tassel_burgundy",
	name = "Tassel Loafers, Burgundy",
	slot = "shoes",
	category = "shoes",
	price = 1100,
	builder = "loafer",
	style = "tassel",
	colors = c("#4E1A22", "#24100F", "#6A2A30"),
	tier = 4,
	tags = { "shoes", "leather" },
	desc = "Burgundy calf tassel loafers, Blake-stitched and feather-light.",
})
add({
	id = "derby_calf_brown",
	name = "Calf Derbies, Dark Brown",
	slot = "shoes",
	category = "shoes",
	price = 950,
	builder = "oxford",
	style = "derby",
	colors = c("#3E2618", "#1C110A", "#5A3A26"),
	tier = 4,
	tags = { "shoes", "leather" },
	desc = "Hand-lasted dark brown derbies with a double leather sole.",
})
add({
	id = "heels_slingback",
	name = "Slingback Pumps, Nude",
	slot = "shoes",
	category = "shoes",
	price = 950,
	builder = "heel",
	style = "pump",
	colors = c("#D2B49A", "#B89A80", "#C0C4C8"),
	tier = 4,
	tags = { "shoes", "womens", "leather" },
	desc = "Nude calf slingbacks on a slim mid heel.",
})
add({
	id = "tie_sevenfold",
	name = "Seven-Fold Silk Tie, Burgundy",
	slot = "neck",
	category = "accessories",
	price = 320,
	builder = "tie",
	colors = c("#5A1E28", "#46161F", "#7A2A36"),
	tier = 4,
	tags = { "tie", "formal" },
	desc = "Unlined seven-fold burgundy silk, folded by hand.",
})
add({
	id = "bowtie_silk",
	name = "Silk Bow Tie, Black",
	slot = "neck",
	category = "accessories",
	price = 280,
	builder = "bowtie",
	colors = c("#0E0E10", "#08080A", "#1A1A1C"),
	tier = 4,
	tags = { "tie", "evening" },
	desc = "A self-tie black barathea bow tie for black-tie dinners.",
})
add({
	id = "glasses_horn",
	name = "Horn-Rim Frames",
	slot = "eyes",
	category = "accessories",
	price = 650,
	builder = "glasses",
	style = "tortoise",
	colors = c("#3A2416", "#8C5A2E", "#1E120A"),
	tier = 4,
	tags = { "eyewear" },
	desc = "Dark horn frames polished by hand. Instantly senior.",
})
add({
	id = "beanie_cashmere",
	name = "Cashmere Beanie, Camel",
	slot = "head",
	category = "accessories",
	price = 420,
	builder = "beanie",
	colors = c("#B08A5A", "#9C7A4E"),
	tier = 4,
	tags = { "hat", "winter" },
	desc = "Ribbed camel cashmere for the walk from the car.",
})

---------------------------------------------------------------------------------------------------
-- Level 5: Hartwell Bespoke and friends
---------------------------------------------------------------------------------------------------
add({
	id = "shirt_bespoke",
	name = "Bespoke Monogrammed Dress Shirt",
	slot = "top",
	category = "luxury",
	brand = "hartwell_bespoke",
	price = 1400,
	builder = "shirt",
	details = { "monogram_cuff" },
	colors = c("#FAF9F6", "#ECEBE6", "#FFFFFF", "#1F2A4A"),
	tier = 5,
	tags = { "luxury", "shirt", "formal" },
	desc = "Cut from your own paper pattern, with your initials in navy on the cuff.",
})
add({
	id = "qzip_vicuna",
	name = "Vicuña Quarter-Zip",
	slot = "top",
	category = "luxury",
	price = 6500,
	builder = "quarterzip",
	colors = c("#A58A68", "#8E7658", "#D4AF37"),
	tier = 5,
	tags = { "luxury", "knit", "logo" },
	desc = "The rarest fibre on earth, in its natural fawn. Shows your company's logo on the chest.",
})
add({
	id = "blouse_couture",
	name = "Couture Silk Blouse, Ivory",
	slot = "top",
	category = "luxury",
	price = 1900,
	builder = "blouse",
	colors = c("#F6F1E6", "#E8E1D2", "#FBF8F1"),
	tier = 5,
	tags = { "luxury", "womens", "silk" },
	desc = "Hand-rolled seams and pearl buttons, made to measure.",
})
add({
	id = "bespoke_midnight_2b",
	name = "Bespoke Two-Button Jacket, Midnight",
	slot = "outer",
	category = "suits",
	brand = "hartwell_bespoke",
	price = 9500,
	builder = "jacket",
	style = "two_button",
	colors = c("#141C2E", "#10172A", "#F4F4F0"),
	tier = 5,
	tags = { "suits", "tailoring", "bespoke" },
	desc = "Super 180s midnight wool, cut and basted on you over three fittings.",
})
add({
	id = "bespoke_chalk_db",
	name = "Bespoke Double-Breasted Jacket, Chalk Stripe",
	slot = "outer",
	category = "suits",
	brand = "hartwell_bespoke",
	price = 14000,
	builder = "jacket",
	style = "double_breasted",
	pattern = "pinstripe",
	colors = c("#1C2436", "#151C2B", "#F4F4F0"),
	tier = 5,
	tags = { "suits", "tailoring", "bespoke" },
	desc = "Chalk-stripe flannel with peak lapels and working cuffs, made by one cutter from start to finish.",
})
add({
	id = "bespoke_flannel_3p",
	name = "Bespoke Three-Piece Jacket, Charcoal Flannel",
	slot = "outer",
	category = "suits",
	brand = "hartwell_bespoke",
	price = 18500,
	builder = "jacket",
	style = "three_piece",
	colors = c("#35383E", "#2B2E33", "#F4F4F0"),
	tier = 5,
	tags = { "suits", "tailoring", "bespoke" },
	desc = "Charcoal flannel three-piece with a hand-padded chest. The boardroom uniform.",
})
add({
	id = "bespoke_vicuna_3p",
	name = "Bespoke Vicuña Three-Piece Jacket",
	slot = "outer",
	category = "suits",
	brand = "hartwell_bespoke",
	price = 25000,
	builder = "jacket",
	style = "three_piece",
	minRank = 3,
	colors = c("#A68B69", "#8F775A", "#3B2A20"),
	tier = 5,
	tags = { "suits", "tailoring", "bespoke", "prestige" },
	desc = "Natural vicuña, the softest cloth Hartwell has ever cut. Vice Presidents and above.",
})
add({
	id = "bespoke_midnight_trousers",
	name = "Bespoke Trousers, Midnight",
	slot = "bottom",
	category = "suits",
	brand = "hartwell_bespoke",
	price = 3500,
	builder = "trousers",
	style = "suit",
	colors = c("#141C2E", "#1A1512", "#C0C4C8"),
	tier = 5,
	tags = { "suits", "tailoring", "bespoke" },
	desc = "Midnight Super 180s trousers with a hand-felled waistband.",
})
add({
	id = "bespoke_chalk_trousers",
	name = "Bespoke Trousers, Chalk Stripe",
	slot = "bottom",
	category = "suits",
	brand = "hartwell_bespoke",
	price = 4800,
	builder = "trousers",
	style = "suit",
	pattern = "pinstripe",
	colors = c("#1C2436", "#1A1512", "#C0C4C8"),
	tier = 5,
	tags = { "suits", "tailoring", "bespoke" },
	desc = "Chalk-stripe flannel trousers with brace buttons.",
})
add({
	id = "bespoke_flannel_trousers",
	name = "Bespoke Trousers, Charcoal Flannel",
	slot = "bottom",
	category = "suits",
	brand = "hartwell_bespoke",
	price = 5500,
	builder = "trousers",
	style = "suit",
	colors = c("#35383E", "#1A1512", "#C0C4C8"),
	tier = 5,
	tags = { "suits", "tailoring", "bespoke" },
	desc = "Charcoal flannel trousers cut high, with a fishtail back.",
})
add({
	id = "trousers_couture_wide",
	name = "Couture Wide-Leg Trousers, Ivory",
	slot = "bottom",
	category = "luxury",
	price = 3800,
	builder = "trousers",
	style = "wide",
	colors = c("#EDE6D8", "#DDD5C5", "#B8933F"),
	tier = 5,
	tags = { "luxury", "womens", "tailoring" },
	desc = "Ivory wool-silk trousers that move like water.",
})
add({
	id = "oxford_bespoke_black",
	name = "Bespoke Cap-Toe Oxfords",
	slot = "shoes",
	category = "shoes",
	price = 2200,
	builder = "oxford",
	colors = c("#121111", "#0A0909", "#2A2727"),
	tier = 5,
	tags = { "shoes", "leather", "bespoke" },
	desc = "Black museum calf on a last carved for your feet.",
})
add({
	id = "heels_couture",
	name = "Couture Satin Pumps, Black",
	slot = "shoes",
	category = "shoes",
	price = 1900,
	builder = "heel",
	style = "pump",
	finish = "patent",
	colors = c("#121214", "#0A0A0B", "#D4AF37"),
	tier = 5,
	tags = { "shoes", "womens", "evening" },
	desc = "Black lacquered pumps with a gold-tipped heel.",
})
add({
	id = "tie_bar_gold",
	name = "Grenadine Tie & 18k Gold Bar",
	slot = "neck",
	category = "accessories",
	price = 1200,
	builder = "tie",
	style = "bar",
	colors = c("#1A2440", "#141C33", "#D4AF37"),
	tier = 5,
	tags = { "tie", "prestige" },
	desc = "Midnight grenadine held by a solid gold bar.",
})
add({
	id = "scarf_vicuna",
	name = "Vicuña Scarf, Natural",
	slot = "neck",
	category = "accessories",
	price = 2800,
	builder = "scarf",
	colors = c("#A58A68", "#8E7658", "#BFA383"),
	tier = 5,
	tags = { "scarf", "winter", "prestige" },
	desc = "A whisper-light natural vicuña scarf.",
})
add({
	id = "aviators_gold",
	name = "18k Gold Aviators",
	slot = "eyes",
	category = "accessories",
	price = 1800,
	builder = "glasses",
	style = "aviator",
	colors = c("#D4AF37", "#3A4A3A", "#B8933F"),
	tier = 5,
	tags = { "eyewear", "prestige" },
	desc = "Solid gold aviators with mineral-glass lenses.",
})
add({
	id = "panama_montecristi",
	name = "Montecristi Panama Hat",
	slot = "head",
	category = "accessories",
	price = 1500,
	builder = "fedora",
	colors = c("#E6DCC2", "#D6CAAD", "#1E1E21"),
	tier = 5,
	tags = { "hat", "summer", "prestige" },
	desc = "Hand-woven straw so fine it takes months to make, with a black grosgrain band.",
})
add({
	id = "attache_calf",
	name = "Calfskin Attaché, Black",
	slot = "bag",
	category = "accessories",
	price = 3000,
	builder = "briefcase",
	style = "attache",
	colors = c("#121111", "#0A0909", "#C0C4C8"),
	tier = 5,
	tags = { "bag", "leather", "prestige" },
	desc = "A hard-sided black calf attaché with palladium locks.",
})

return items
