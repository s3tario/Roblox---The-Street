--!strict
-- Wearables catalog (owned by `wardrobe`, docs/contracts.md §9). Every item is built in-house as fitted
-- 3D layers (Shared/Assets/Wardrobe) and, optionally, a generated 2D Shirt/Pants template
-- (tools/clothing). Pure data plus pure helpers: safe on server, client and in Lune.
--
--   Catalog.items[itemId] = { id, name, slot, category, price, currency = "cash" | "pass", pass?, minRank?,
--                             colors = { primary, secondary?, accent? } ("#RRGGBB"), builder, tier (1-5),
--                             desc, tags, style?, pattern?, text?, hidden? }
--   Catalog.get(id) -> Item?               Catalog.bySlot(slot, includeHidden?) -> { Item } (tier, price order)
--   Catalog.list(includeHidden?) -> { Item }
--   Catalog.starter[stage] = { [slot] = itemId }  free default outfit per career stage
--   Catalog.starterFor(rank) -> outfit       Catalog.starterItems(rank) -> { itemId }  (every stage <= rank)
--   Catalog.presets[npcRole] = { equipped, hairStyle, hairColor, skin, pose? }   NPC outfits
--   Catalog.access(item, viewer) -> state   "free" | "owned" | "buy" | "rank" | "pass" (see below)
--   Catalog.strings                          player-facing wardrobe UI text
--
-- Prices follow the spec §11 anchors (PRICE_RANGES). Premium items (currency "pass") come with a game
-- pass and cost 0 cash. minRank gates prestige pieces (ranks: student 0 ... md 6, partner 10).

export type Slot = "top" | "outer" | "bottom" | "shoes" | "neck" | "wrist" | "eyes" | "head" | "bag"
export type Colors = { primary: string, secondary: string?, accent: string? }
export type Item = {
	id: string,
	name: string,
	slot: Slot,
	category: string,
	price: number,
	currency: "cash" | "pass",
	pass: string?,
	minRank: number?,
	colors: Colors,
	builder: string,
	tier: number,
	desc: string,
	tags: { string },
	style: string?,
	pattern: string?,
	text: string?,
	hidden: boolean?,
}
export type Viewer = {
	owned: { [string]: any }?,
	rank: number?,
	passes: { [string]: any }?,
}
export type Preset = {
	equipped: { [string]: string },
	hairStyle: string?,
	hairColor: string?,
	skin: string?,
	pose: string?,
}

local Catalog = {}

-- Slot order is also the layer build order (later slots can sit on top of earlier ones).
Catalog.SLOTS = { "top", "bottom", "outer", "shoes", "neck", "wrist", "eyes", "head", "bag" } :: { Slot }
Catalog.SLOT_SET = {} :: { [string]: boolean }
for _, s in Catalog.SLOTS do
	Catalog.SLOT_SET[s] = true
end
-- Display order for the wardrobe tabs.
Catalog.TAB_ORDER = { "top", "outer", "bottom", "shoes", "neck", "wrist", "eyes", "head", "bag" } :: { Slot }
-- Slots that are never left empty (Wardrobe falls back to a plain base item).
Catalog.REQUIRED = { top = "base_tee", bottom = "base_trousers", shoes = "base_shoes" } :: { [string]: string }

Catalog.CATEGORIES = { "campus", "business", "womens", "suits", "shoes", "accessories", "watches", "premium", "npc" }
Catalog.PASSES = { CornerOffice = true, ExecutiveClub = true } :: { [string]: boolean }

-- Spec §11 price anchors per category (cash items with a price above 0).
Catalog.PRICE_RANGES = {
	campus = { 40, 250 },
	business = { 150, 600 },
	womens = { 150, 600 },
	suits = { 900, 6000 },
	shoes = { 120, 2500 },
	accessories = { 40, 3000 },
	watches = { 300, 80000 },
} :: { [string]: { number } }
Catalog.SHOE_RANGE = { 120, 2500 }

-- Preset slots: the first FREE are open to everyone, the rest need the Executive Club pass.
Catalog.PRESET_SLOTS = { free = 2, max = 5, pass = "ExecutiveClub", nameMax = 24 }

---------------------------------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------------------------------
local items: { [string]: Item } = {}
local order: { string } = {}

local function add(def: { [string]: any })
	local id = def.id :: string
	assert(items[id] == nil, "Catalog: duplicate item " .. id)
	local item: Item = {
		id = id,
		name = def.name,
		slot = def.slot,
		category = def.category,
		price = def.price or 0,
		currency = def.currency or (if def.pass then "pass" else "cash"),
		pass = def.pass,
		minRank = def.minRank,
		colors = def.colors,
		builder = def.builder,
		tier = def.tier or 1,
		desc = def.desc or "",
		tags = def.tags or {},
		style = def.style,
		pattern = def.pattern,
		text = def.text,
		hidden = def.hidden,
	}
	items[id] = item
	table.insert(order, id)
end

local function c(primary: string, secondary: string?, accent: string?): Colors
	return { primary = primary, secondary = secondary, accent = accent }
end

-- Campus wear (Eastbridge, gritty) ---------------------------------------------------------------
add({
	id = "hoodie_heather",
	name = "Heather Grey Hoodie",
	slot = "top",
	category = "campus",
	price = 85,
	builder = "hoodie",
	colors = c("#8D9096", "#74777D", "#E9E2CF"),
	tier = 1,
	tags = { "campus", "casual" },
	desc = "Brushed fleece with a kangaroo pocket. The unofficial uniform of the 8 a.m. lecture.",
})
add({
	id = "hoodie_maroon",
	name = "Eastbridge Maroon Hoodie",
	slot = "top",
	category = "campus",
	price = 110,
	builder = "hoodie",
	style = "college",
	colors = c("#6B1F2A", "#55161F", "#C9A13B"),
	tier = 1,
	tags = { "campus", "casual", "school" },
	desc = "Heavyweight fleece in Eastbridge maroon with a gold chest stripe.",
})
add({
	id = "tee_white",
	name = "Plain White Tee",
	slot = "top",
	category = "campus",
	price = 40,
	builder = "tee",
	colors = c("#EEEDE8", "#DAD9D3"),
	tier = 1,
	tags = { "campus", "casual" },
	desc = "A clean crew-neck tee. Goes with everything, including ramen.",
})
add({
	id = "crewneck_oatmeal",
	name = "Oatmeal Crewneck",
	slot = "top",
	category = "campus",
	price = 120,
	builder = "sweater",
	colors = c("#CDBFA3", "#B9AB8E"),
	tier = 2,
	tags = { "campus", "knit" },
	desc = "Chunky ribbed knit for long nights in the library.",
})
add({
	id = "flannel_red",
	name = "Red Flannel Overshirt",
	slot = "outer",
	category = "campus",
	price = 90,
	builder = "overshirt",
	pattern = "plaid",
	colors = c("#8E2B26", "#2B2425", "#C9B7A0"),
	tier = 1,
	tags = { "campus", "casual", "layer" },
	desc = "Brushed plaid flannel worn open over a tee.",
})
add({
	id = "denim_jacket",
	name = "Washed Denim Jacket",
	slot = "outer",
	category = "campus",
	price = 160,
	builder = "overshirt",
	style = "denim",
	colors = c("#4F6C8F", "#3E5675", "#C98A3B"),
	tier = 2,
	tags = { "campus", "casual", "layer" },
	desc = "Faded trucker jacket with copper stitching and flap pockets.",
})
add({
	id = "thrift_blazer",
	name = "Thrift-Store Corduroy Blazer",
	slot = "outer",
	category = "campus",
	price = 140,
	builder = "blazer",
	style = "elbow",
	colors = c("#6B4A33", "#5A3D29", "#3B2A20"),
	tier = 2,
	tags = { "campus", "smart" },
	desc = "Brown corduroy with suede elbow patches. Previous owner unknown.",
})
add({
	id = "jeans_indigo",
	name = "Indigo Jeans",
	slot = "bottom",
	category = "campus",
	price = 70,
	builder = "jeans",
	colors = c("#2C3C5A", "#3B2A1E", "#C98A3B"),
	tier = 1,
	tags = { "campus", "denim" },
	desc = "Dark rinse straight jeans with copper stitching and rolled cuffs.",
})
add({
	id = "jeans_black",
	name = "Black Slim Jeans",
	slot = "bottom",
	category = "campus",
	price = 75,
	builder = "jeans",
	colors = c("#232427", "#1A1A1A", "#6E6E6E"),
	tier = 1,
	tags = { "campus", "denim" },
	desc = "Slim black denim that survives the laundromat.",
})
add({
	id = "cargo_olive",
	name = "Olive Cargo Pants",
	slot = "bottom",
	category = "campus",
	price = 80,
	builder = "cargo",
	colors = c("#5A5E3E", "#2B2B2B", "#9A9A80"),
	tier = 1,
	tags = { "campus", "utility" },
	desc = "Ripstop cargos with flap pockets for highlighters and bus fare.",
})
add({
	id = "sneaker_white",
	name = "Court Sneakers",
	slot = "shoes",
	category = "campus",
	price = 120,
	builder = "sneaker",
	colors = c("#F1F0EB", "#FFFFFF", "#1F2A44"),
	tier = 1,
	tags = { "campus", "sneaker" },
	desc = "Leather court sneakers with a navy heel tab.",
})
add({
	id = "sneaker_canvas",
	name = "Black Canvas Low-Tops",
	slot = "shoes",
	category = "campus",
	price = 120,
	builder = "sneaker",
	style = "canvas",
	colors = c("#222326", "#F1F0EB", "#F1F0EB"),
	tier = 1,
	tags = { "campus", "sneaker" },
	desc = "Vulcanised canvas low-tops with a white toe cap.",
})
add({
	id = "beanie_charcoal",
	name = "Ribbed Beanie",
	slot = "head",
	category = "campus",
	price = 40,
	builder = "beanie",
	colors = c("#3A3C40", "#2E3034"),
	tier = 1,
	tags = { "campus", "winter" },
	desc = "Fold-over ribbed knit beanie.",
})
add({
	id = "cap_eastbridge",
	name = "Eastbridge Ball Cap",
	slot = "head",
	category = "campus",
	price = 45,
	builder = "cap",
	colors = c("#6B1F2A", "#55161F", "#C9A13B"),
	tier = 1,
	tags = { "campus", "school" },
	desc = "Six-panel cap with a gold Eastbridge patch.",
})
add({
	id = "backpack_canvas",
	name = "Canvas Backpack",
	slot = "bag",
	category = "campus",
	price = 90,
	builder = "backpack",
	colors = c("#4D5B48", "#3D4A39", "#6B4A33"),
	tier = 1,
	tags = { "campus" },
	desc = "Waxed canvas with leather trim. Fits a laptop and three textbooks you won't read.",
})
add({
	id = "backpack_commuter",
	name = "Commuter Backpack",
	slot = "bag",
	category = "campus",
	price = 150,
	builder = "backpack",
	style = "sleek",
	colors = c("#222326", "#2E3034", "#8E9397"),
	tier = 2,
	tags = { "campus", "commute" },
	desc = "Water-resistant nylon pack with a padded laptop sleeve.",
})
add({
	id = "lanyard_student",
	name = "Student ID Lanyard",
	slot = "neck",
	category = "campus",
	price = 0,
	builder = "lanyard",
	text = "STUDENT",
	colors = c("#2F8C8C", "#E9E2CF", "#2F8C8C"),
	tier = 1,
	tags = { "campus", "starter" },
	desc = "Your Eastbridge student ID. Opens the library and the dining hall.",
})
add({
	id = "lanyard_intern",
	name = "Intern ID Lanyard",
	slot = "neck",
	category = "campus",
	price = 0,
	builder = "lanyard",
	text = "INTERN",
	colors = c("#0B1F3A", "#F7F6F2", "#C9A54C"),
	tier = 1,
	tags = { "street", "starter" },
	desc = "Sterling & Vance summer intern badge. Wear it with pride (you have to).",
})
add({
	id = "band_pulse",
	name = "Pulse Fitness Band",
	slot = "wrist",
	category = "campus",
	price = 60,
	builder = "band",
	colors = c("#2B2D31", "#1A1B1E", "#2BD67B"),
	tier = 1,
	tags = { "campus", "tech" },
	desc = "Counts steps between lectures. Tells you to stand up.",
})
add({
	id = "scarf_varsity",
	name = "Varsity Stripe Scarf",
	slot = "neck",
	category = "campus",
	price = 45,
	builder = "scarf",
	pattern = "stripe",
	colors = c("#6B1F2A", "#55161F", "#C9A13B"),
	tier = 1,
	tags = { "campus", "winter", "school" },
	desc = "Eastbridge stripes for game days and cold bus stops.",
})

-- Business casual -----------------------------------------------------------------------------------
add({
	id = "oxford_white",
	name = "White Oxford Shirt",
	slot = "top",
	category = "business",
	price = 150,
	builder = "shirt",
	colors = c("#F4F4F0", "#E4E4DE", "#FFFFFF"),
	tier = 2,
	tags = { "business", "shirt" },
	desc = "Crisp button-down oxford cloth. The foundation of every look on the Street.",
})
add({
	id = "oxford_blue",
	name = "Light Blue Oxford",
	slot = "top",
	category = "business",
	price = 150,
	builder = "shirt",
	colors = c("#BBD0E6", "#A9C0D9", "#F4F4F0"),
	tier = 2,
	tags = { "business", "shirt" },
	desc = "The banker's blue. Hides coffee better than white.",
})
add({
	id = "shirt_bengal",
	name = "Bengal Stripe Shirt",
	slot = "top",
	category = "business",
	price = 180,
	builder = "shirt",
	pattern = "stripe",
	colors = c("#F6F6F2", "#E4E4DE", "#5C7FB3"),
	tier = 2,
	tags = { "business", "shirt", "pattern" },
	desc = "Bold blue bengal stripes on a white poplin ground.",
})
add({
	id = "polo_navy",
	name = "Pique Polo, Navy",
	slot = "top",
	category = "business",
	price = 150,
	builder = "polo",
	colors = c("#1F2A44", "#18213A", "#C9A54C"),
	tier = 2,
	tags = { "business", "casual" },
	desc = "Cotton pique polo with a small gold emblem.",
})
add({
	id = "qzip_navy",
	name = "Merino Quarter-Zip, Navy",
	slot = "top",
	category = "business",
	price = 220,
	builder = "quarterzip",
	colors = c("#1D2840", "#151E33", "#B8BCC2"),
	tier = 2,
	tags = { "business", "knit" },
	desc = "Fine merino quarter-zip. Standard issue for Friday at the fund.",
})
add({
	id = "sweater_camel_v",
	name = "Camel V-Neck Sweater",
	slot = "top",
	category = "business",
	price = 240,
	builder = "sweater",
	style = "vneck",
	colors = c("#B8915E", "#F4F4F0", "#A27E4F"),
	tier = 2,
	tags = { "business", "knit" },
	desc = "Lambswool V-neck layered over a white collar.",
})
add({
	id = "vest_fleece",
	name = "Midtown Fleece Vest",
	slot = "outer",
	category = "business",
	price = 180,
	builder = "vest",
	style = "fleece",
	colors = c("#2A2F38", "#22262D", "#B8BCC2"),
	tier = 2,
	tags = { "business", "layer", "finance" },
	desc = "Zip-up fleece vest. If you know, you know.",
})
add({
	id = "vest_waistcoat",
	name = "Grey Wool Waistcoat",
	slot = "outer",
	category = "business",
	price = 260,
	builder = "vest",
	style = "waistcoat",
	colors = c("#5E6168", "#3A3C40", "#2A2B2E"),
	tier = 3,
	tags = { "business", "tailoring" },
	desc = "Five-button worsted waistcoat with welt pockets.",
})
add({
	id = "blazer_navy",
	name = "Navy Unstructured Blazer",
	slot = "outer",
	category = "business",
	price = 560,
	builder = "blazer",
	colors = c("#1E2A45", "#17213A", "#C9C5BE"),
	tier = 3,
	tags = { "business", "smart" },
	desc = "Soft-shouldered hopsack blazer with patch pockets and horn buttons.",
})
add({
	id = "chinos_khaki",
	name = "Khaki Chinos",
	slot = "bottom",
	category = "business",
	price = 160,
	builder = "chinos",
	colors = c("#B7A27C", "#5A3A26", "#C9A54C"),
	tier = 2,
	tags = { "business", "casual" },
	desc = "Garment-dyed cotton chinos with a tan leather belt.",
})
add({
	id = "trousers_flannel",
	name = "Grey Flannel Trousers",
	slot = "bottom",
	category = "business",
	price = 280,
	builder = "trousers",
	colors = c("#6E7076", "#2A2522", "#C0C4C8"),
	tier = 3,
	tags = { "business", "tailoring" },
	desc = "Mid-grey flannel with a pressed crease and turn-ups.",
})
add({
	id = "loafer_cognac",
	name = "Penny Loafers, Cognac",
	slot = "shoes",
	category = "business",
	price = 380,
	builder = "loafer",
	colors = c("#7A4526", "#3A2618", "#5E341C"),
	tier = 2,
	tags = { "business", "leather" },
	desc = "Hand-burnished cognac calf penny loafers.",
})

-- Women's tailoring -----------------------------------------------------------------------------
add({
	id = "blouse_ivory",
	name = "Silk Blouse, Ivory",
	slot = "top",
	category = "womens",
	price = 240,
	builder = "blouse",
	colors = c("#F3EEE3", "#E3DCCD", "#F7F3EA"),
	tier = 2,
	tags = { "womens", "silk" },
	desc = "Fluid silk with a rounded collar and pearl buttons.",
})
add({
	id = "blouse_blush",
	name = "Silk Blouse, Blush",
	slot = "top",
	category = "womens",
	price = 240,
	builder = "blouse",
	colors = c("#E8C7C1", "#D7B2AB", "#F7F3EA"),
	tier = 2,
	tags = { "womens", "silk" },
	desc = "Soft blush silk with gathered cuffs.",
})
add({
	id = "shell_black",
	name = "Crepe Shell Top, Black",
	slot = "top",
	category = "womens",
	price = 180,
	builder = "shell",
	colors = c("#1E1E21", "#151517"),
	tier = 2,
	tags = { "womens", "sleeveless" },
	desc = "Sleeveless crepe shell with a scoop neckline. Layers under any jacket.",
})
add({
	id = "skirt_pencil_charcoal",
	name = "Charcoal Pencil Skirt",
	slot = "bottom",
	category = "womens",
	price = 380,
	builder = "pencil_skirt",
	colors = c("#3A3C42", "#2E3035", "#1E1E21"),
	tier = 3,
	tags = { "womens", "tailoring" },
	desc = "Knee-length worsted pencil skirt with a back vent.",
})
add({
	id = "skirt_aline_camel",
	name = "Camel A-Line Skirt",
	slot = "bottom",
	category = "womens",
	price = 340,
	builder = "aline_skirt",
	colors = c("#B08A5A", "#987447", "#3B2A20"),
	tier = 2,
	tags = { "womens" },
	desc = "Wool A-line skirt that flares just above the knee.",
})
add({
	id = "trousers_wide_black",
	name = "Black Tailored Trousers",
	slot = "bottom",
	category = "womens",
	price = 420,
	builder = "trousers",
	style = "wide",
	colors = c("#1E1E21", "#151517", "#B8933F"),
	tier = 3,
	tags = { "womens", "tailoring" },
	desc = "High-waisted wide-leg trousers with a sharp front crease.",
})
add({
	id = "heels_block_black",
	name = "Black Block Heels",
	slot = "shoes",
	category = "womens",
	price = 340,
	builder = "heel",
	style = "block",
	colors = c("#1E1D1C", "#141313", "#C0C4C8"),
	tier = 2,
	tags = { "womens", "leather" },
	desc = "Comfortable block heels for twelve-hour days.",
})
add({
	id = "pumps_black",
	name = "Black Patent Pumps",
	slot = "shoes",
	category = "womens",
	price = 520,
	builder = "heel",
	style = "pump",
	colors = c("#141414", "#0C0C0C", "#2A2A2A"),
	tier = 3,
	tags = { "womens", "patent" },
	desc = "Pointed patent pumps with a slim heel.",
})

-- Suits: three cuts (two-button, double-breasted, three-piece) in six colours ------------------------
local SUITS = {
	{ key = "navy", label = "Navy", primary = "#1D2A47", secondary = "#17213A", trousers = 900 },
	{ key = "charcoal", label = "Charcoal", primary = "#3A3D44", secondary = "#2F3238", trousers = 900 },
	{ key = "black", label = "Black", primary = "#16171A", secondary = "#101113", trousers = 950 },
	{ key = "grey", label = "Mid-Grey", primary = "#6C7078", secondary = "#5B5F66", trousers = 900 },
	{
		key = "pinstripe",
		label = "Navy Pinstripe",
		primary = "#1B2742",
		secondary = "#151F36",
		trousers = 1400,
		pattern = "pinstripe",
		minRank = 4,
	},
	{ key = "camel", label = "Camel", primary = "#A9834F", secondary = "#8F6E41", trousers = 1000 },
}
local CUTS = {
	two_button = { label = "Two-Button Jacket", price = 1600, tier = 3 },
	double_breasted = { label = "Double-Breasted Jacket", price = 2400, tier = 4, minRank = 3 },
	three_piece = { label = "Three-Piece Jacket", price = 2900, tier = 4, minRank = 3 },
}
local SUIT_JACKETS: { { color: string, cut: string, price: number? } } = {
	{ color = "navy", cut = "two_button" },
	{ color = "navy", cut = "double_breasted" },
	{ color = "charcoal", cut = "two_button" },
	{ color = "charcoal", cut = "three_piece" },
	{ color = "black", cut = "two_button", price = 1800 },
	{ color = "grey", cut = "two_button", price = 1500 },
	{ color = "pinstripe", cut = "double_breasted", price = 3400 },
	{ color = "camel", cut = "two_button", price = 2000 },
}
local SUIT_IDS = { two_button = "2b", double_breasted = "db", three_piece = "3p" }
for _, j in SUIT_JACKETS do
	local colour: any = nil
	for _, s in SUITS do
		if s.key == j.color then
			colour = s
		end
	end
	local cut = (CUTS :: any)[j.cut]
	add({
		id = "suit_" .. j.color .. "_" .. SUIT_IDS[j.cut],
		name = colour.label .. " " .. cut.label,
		slot = "outer",
		category = "suits",
		price = j.price or cut.price,
		builder = "jacket",
		style = j.cut,
		pattern = colour.pattern,
		minRank = colour.minRank or cut.minRank,
		colors = c(colour.primary, colour.secondary, "#F4F4F0"),
		tier = if colour.pattern then 5 else cut.tier,
		tags = { "suits", "tailoring", j.cut },
		desc = "Hartwell Tailors "
			.. string.lower(colour.label)
			.. " worsted, "
			.. string.gsub(j.cut, "_", "-")
			.. " cut. Pair with the matching trousers.",
	})
end
for _, s in SUITS do
	add({
		id = "suit_" .. s.key .. "_trousers",
		name = s.label .. " Suit Trousers",
		slot = "bottom",
		category = "suits",
		price = s.trousers,
		builder = "trousers",
		style = "suit",
		pattern = s.pattern,
		minRank = s.minRank,
		colors = c(s.primary, "#1A1512", "#C0C4C8"),
		tier = if s.pattern then 4 else 3,
		tags = { "suits", "tailoring" },
		desc = "Flat-front " .. string.lower(s.label) .. " suit trousers with a pressed crease.",
	})
end
add({
	id = "overcoat_charcoal",
	name = "Charcoal Overcoat",
	slot = "outer",
	category = "suits",
	price = 1800,
	builder = "overcoat",
	minRank = 2,
	colors = c("#3C3E44", "#2F3136", "#1E1E21"),
	tier = 4,
	tags = { "suits", "outerwear", "winter" },
	desc = "Knee-length wool overcoat for the walk from the subway.",
})

-- Formal shoes ------------------------------------------------------------------------------------
add({
	id = "oxford_black",
	name = "Black Cap-Toe Oxfords",
	slot = "shoes",
	category = "shoes",
	price = 450,
	builder = "oxford",
	colors = c("#151414", "#0E0D0D", "#2A2828"),
	tier = 3,
	tags = { "shoes", "leather" },
	desc = "Closed-lacing calf oxfords. Never wrong.",
})
add({
	id = "oxford_oxblood",
	name = "Oxblood Cap-Toe Oxfords",
	slot = "shoes",
	category = "shoes",
	price = 520,
	builder = "oxford",
	colors = c("#4A1C1E", "#1E1414", "#5E2729"),
	tier = 3,
	tags = { "shoes", "leather" },
	desc = "Deep oxblood shine with a cap toe.",
})
add({
	id = "wholecut_bespoke",
	name = "Strider Bespoke Wholecuts",
	slot = "shoes",
	category = "shoes",
	price = 2500,
	builder = "oxford",
	style = "wholecut",
	minRank = 4,
	colors = c("#2A1A12", "#120C08", "#4A3020"),
	tier = 5,
	tags = { "shoes", "leather", "prestige" },
	desc = "Cut from a single hide and mirror-polished by hand.",
})

-- Accessories -------------------------------------------------------------------------------------
add({
	id = "tie_navy",
	name = "Navy Grenadine Tie",
	slot = "neck",
	category = "accessories",
	price = 120,
	builder = "tie",
	colors = c("#1E2A4A", "#172039", "#2A3A63"),
	tier = 2,
	tags = { "tie" },
	desc = "Textured navy silk grenadine. The default answer.",
})
add({
	id = "tie_regimental",
	name = "Regimental Stripe Tie",
	slot = "neck",
	category = "accessories",
	price = 140,
	builder = "tie",
	pattern = "stripe",
	colors = c("#1E2A4A", "#172039", "#C9A54C"),
	tier = 2,
	tags = { "tie", "pattern" },
	desc = "Navy and gold repp stripes.",
})
add({
	id = "tie_knit_black",
	name = "Black Silk Knit Tie",
	slot = "neck",
	category = "accessories",
	price = 160,
	builder = "tie",
	style = "knit",
	colors = c("#1A1A1C", "#121214", "#2A2A2E"),
	tier = 2,
	tags = { "tie", "knit" },
	desc = "Square-ended silk knit. Casual Friday's secret weapon.",
})
add({
	id = "tie_silver",
	name = "Silver Satin Tie",
	slot = "neck",
	category = "accessories",
	price = 220,
	builder = "tie",
	style = "satin",
	colors = c("#B5B8BD", "#9EA2A8", "#D8DADD"),
	tier = 3,
	tags = { "tie", "formal" },
	desc = "High-sheen silver satin for deal closings and weddings.",
})
add({
	id = "scarf_cashmere",
	name = "Cashmere Scarf, Camel",
	slot = "neck",
	category = "accessories",
	price = 260,
	builder = "scarf",
	colors = c("#B08A5A", "#9C7A4E", "#C9A46E"),
	tier = 3,
	tags = { "scarf", "winter" },
	desc = "Two-ply cashmere, looped once.",
})
add({
	id = "glasses_round_wire",
	name = "Round Wire Frames",
	slot = "eyes",
	category = "accessories",
	price = 150,
	builder = "glasses",
	style = "round",
	colors = c("#B8933F", "#9A7A33"),
	tier = 2,
	tags = { "eyewear" },
	desc = "Thin gold wire frames with keyhole bridge.",
})
add({
	id = "glasses_black_rect",
	name = "Black Rectangular Frames",
	slot = "eyes",
	category = "accessories",
	price = 180,
	builder = "glasses",
	style = "rect",
	colors = c("#151515", "#2A2A2A"),
	tier = 2,
	tags = { "eyewear" },
	desc = "Bold black acetate rectangles. Instantly 20% more quantitative.",
})
add({
	id = "fedora_charcoal",
	name = "Charcoal Felt Fedora",
	slot = "head",
	category = "accessories",
	price = 280,
	builder = "fedora",
	colors = c("#3A3C40", "#2E3034", "#151515"),
	tier = 3,
	tags = { "hat", "winter" },
	desc = "Rabbit-felt fedora with a grosgrain band.",
})
add({
	id = "messenger_waxed",
	name = "Waxed Canvas Messenger",
	slot = "bag",
	category = "accessories",
	price = 220,
	builder = "messenger",
	colors = c("#5C5A3E", "#4A4832", "#3B2A20"),
	tier = 2,
	tags = { "bag" },
	desc = "Cross-body messenger with leather straps and brass buckles.",
})
add({
	id = "briefcase_leather",
	name = "Leather Briefcase",
	slot = "bag",
	category = "accessories",
	price = 950,
	builder = "briefcase",
	minRank = 2,
	colors = c("#4A2E1C", "#3A2416", "#C9A54C"),
	tier = 4,
	tags = { "bag", "leather", "prestige" },
	desc = "Full-grain leather briefcase with brass clasps.",
})

-- Watches: the status ladder (Vanta Watches) ------------------------------------------------------
add({
	id = "watch_meridian_steel",
	name = "Meridian Steel",
	slot = "wrist",
	category = "watches",
	price = 300,
	builder = "watch",
	style = "steel",
	colors = c("#C0C4C8", "#2A2D33", "#F2F2EE"),
	tier = 1,
	tags = { "watch" },
	desc = "A clean steel three-hander on black calf. Your first real watch.",
})
add({
	id = "watch_corso_bronze",
	name = "Corso Bronze Field",
	slot = "wrist",
	category = "watches",
	price = 1200,
	builder = "watch",
	style = "bronze",
	colors = c("#9C6B3C", "#4A3A2A", "#1F2A24"),
	tier = 2,
	tags = { "watch" },
	desc = "Bronze field watch with a green dial that patinas with you.",
})
add({
	id = "watch_halden_chrono",
	name = "Halden Chronograph",
	slot = "wrist",
	category = "watches",
	price = 4500,
	builder = "watch",
	style = "steel",
	minRank = 2,
	colors = c("#D2D5D9", "#C0C4C8", "#1E2A4A"),
	tier = 3,
	tags = { "watch", "chronograph" },
	desc = "Steel chronograph on a bracelet with a sunburst blue dial.",
})
add({
	id = "watch_vanta_gold",
	name = "Vanta Gold Dress",
	slot = "wrist",
	category = "watches",
	price = 18000,
	builder = "watch",
	style = "gold",
	minRank = 4,
	colors = c("#D4AF37", "#2A1A12", "#F4EEDC"),
	tier = 4,
	tags = { "watch", "prestige" },
	desc = "Thin 18k gold dress watch on brown alligator.",
})
add({
	id = "watch_astra_moonphase",
	name = "Astra Platinum Moonphase",
	slot = "wrist",
	category = "watches",
	price = 80000,
	builder = "watch",
	style = "platinum",
	minRank = 6,
	colors = c("#E5E4E2", "#1B2233", "#0E1A33"),
	tier = 5,
	tags = { "watch", "prestige", "md" },
	desc = "Platinum perpetual moonphase. Sold only to managing directors and above.",
})

-- Premium: Corner Office Collection (game pass "CornerOffice") ------------------------------------
add({
	id = "co_velvet_dinner",
	name = "Velvet Dinner Jacket",
	slot = "outer",
	category = "premium",
	pass = "CornerOffice",
	builder = "jacket",
	style = "dinner",
	colors = c("#1B1530", "#0E0E10", "#F4F4F0"),
	tier = 5,
	tags = { "premium", "evening" },
	desc = "Midnight velvet with black satin peak lapels.",
})
add({
	id = "co_midnight_3p",
	name = "Midnight Three-Piece Jacket",
	slot = "outer",
	category = "premium",
	pass = "CornerOffice",
	builder = "jacket",
	style = "three_piece",
	colors = c("#141B2D", "#10172A", "#C9A54C"),
	tier = 5,
	tags = { "premium", "tailoring" },
	desc = "Midnight navy three-piece with a gold silk pocket square.",
})
add({
	id = "co_midnight_trousers",
	name = "Midnight Evening Trousers",
	slot = "bottom",
	category = "premium",
	pass = "CornerOffice",
	builder = "trousers",
	style = "evening",
	colors = c("#141B2D", "#0E0E10", "#0E0E10"),
	tier = 5,
	tags = { "premium", "evening" },
	desc = "Midnight trousers with a satin side stripe.",
})
add({
	id = "co_cashmere_overcoat",
	name = "Cashmere Overcoat, Camel",
	slot = "outer",
	category = "premium",
	pass = "CornerOffice",
	builder = "overcoat",
	style = "chesterfield",
	colors = c("#B48D5C", "#9C7A4E", "#3B2A20"),
	tier = 5,
	tags = { "premium", "outerwear", "winter" },
	desc = "Double-faced camel cashmere, cut long.",
})
add({
	id = "co_tortoiseshell",
	name = "Tortoiseshell Frames",
	slot = "eyes",
	category = "premium",
	pass = "CornerOffice",
	builder = "glasses",
	style = "tortoise",
	colors = c("#5A3418", "#B9782F", "#2E1A0C"),
	tier = 4,
	tags = { "premium", "eyewear" },
	desc = "Hand-polished tortoiseshell acetate.",
})
add({
	id = "co_tiebar_tie",
	name = "Midnight Silk Tie & Gold Bar",
	slot = "neck",
	category = "premium",
	pass = "CornerOffice",
	builder = "tie",
	style = "bar",
	colors = c("#141B2D", "#10172A", "#D4AF37"),
	tier = 5,
	tags = { "premium", "tie" },
	desc = "Midnight silk tie held by an 18k gold tie bar.",
})
add({
	id = "co_bowtie",
	name = "Midnight Silk Bow Tie",
	slot = "neck",
	category = "premium",
	pass = "CornerOffice",
	builder = "bowtie",
	colors = c("#0E0E10", "#08080A", "#1B1530"),
	tier = 4,
	tags = { "premium", "evening" },
	desc = "Self-tie black silk bow tie for black-tie dinners.",
})
add({
	id = "co_corner_briefcase",
	name = "Corner Office Attaché",
	slot = "bag",
	category = "premium",
	pass = "CornerOffice",
	builder = "briefcase",
	style = "attache",
	colors = c("#151414", "#0E0D0D", "#D4AF37"),
	tier = 5,
	tags = { "premium", "bag", "leather" },
	desc = "Hard-sided black attaché with gold hardware.",
})

-- Premium: Executive Club set (game pass "ExecutiveClub") ------------------------------------------
add({
	id = "ec_club_blazer",
	name = "Executive Club Blazer",
	slot = "outer",
	category = "premium",
	pass = "ExecutiveClub",
	builder = "blazer",
	style = "club",
	colors = c("#0F1C33", "#0B1529", "#D4AF37"),
	tier = 5,
	tags = { "premium", "club" },
	desc = "Navy club blazer with gold buttons and the club crest.",
})
add({
	id = "ec_gold_watch",
	name = "Vanta Executive Gold",
	slot = "wrist",
	category = "premium",
	pass = "ExecutiveClub",
	builder = "watch",
	style = "gold",
	colors = c("#D4AF37", "#D4AF37", "#0E0E10"),
	tier = 4,
	tags = { "premium", "club", "watch" },
	desc = "Solid gold bracelet watch with an onyx dial.",
})
add({
	id = "ec_club_tie",
	name = "Club Stripe Tie",
	slot = "neck",
	category = "premium",
	pass = "ExecutiveClub",
	builder = "tie",
	pattern = "stripe",
	colors = c("#0F1C33", "#0B1529", "#D4AF37"),
	tier = 4,
	tags = { "premium", "club", "tie" },
	desc = "Members' navy and gold stripe.",
})
add({
	id = "ec_gold_aviators",
	name = "Club Gold Aviators",
	slot = "eyes",
	category = "premium",
	pass = "ExecutiveClub",
	builder = "glasses",
	style = "aviator",
	colors = c("#D4AF37", "#2E3B2E", "#B8933F"),
	tier = 4,
	tags = { "premium", "club", "eyewear" },
	desc = "Gold aviators with green lenses.",
})
add({
	id = "ec_horsebit_loafers",
	name = "Gold-Bit Loafers",
	slot = "shoes",
	category = "premium",
	pass = "ExecutiveClub",
	builder = "loafer",
	style = "bit",
	colors = c("#2A1A12", "#140D09", "#D4AF37"),
	tier = 4,
	tags = { "premium", "club", "leather" },
	desc = "Dark brown calf loafers with a gold horsebit.",
})

-- NPC wardrobe and fallbacks (hidden from the shop) -----------------------------------------------
add({
	id = "base_tee",
	name = "Base Tee",
	slot = "top",
	category = "npc",
	builder = "tee",
	colors = c("#D9D9D4", "#C8C8C2"),
	hidden = true,
	tags = { "base" },
	desc = "Plain base layer.",
})
add({
	id = "base_trousers",
	name = "Base Trousers",
	slot = "bottom",
	category = "npc",
	builder = "trousers",
	style = "plain",
	colors = c("#3A3C40", "#2A2B2E", "#8E9397"),
	hidden = true,
	tags = { "base" },
	desc = "Plain base trousers.",
})
add({
	id = "base_shoes",
	name = "Base Shoes",
	slot = "shoes",
	category = "npc",
	builder = "oxford",
	style = "derby",
	colors = c("#2A2B2E", "#1A1A1C", "#3A3B3E"),
	hidden = true,
	tags = { "base" },
	desc = "Plain base shoes.",
})
add({
	id = "apron_barista",
	name = "Barista Apron",
	slot = "outer",
	category = "npc",
	builder = "apron",
	colors = c("#3B2A20", "#2E2018", "#C9A13B"),
	hidden = true,
	tags = { "npc" },
	desc = "Canvas bib apron.",
})
add({
	id = "trader_jacket",
	name = "Exchange Floor Jacket",
	slot = "outer",
	category = "npc",
	builder = "blazer",
	style = "trader",
	colors = c("#2F6FB0", "#24588E", "#F2C230"),
	hidden = true,
	tags = { "npc" },
	desc = "Bright trading-floor jacket with a badge pocket.",
})
add({
	id = "doorman_coat",
	name = "Doorman's Greatcoat",
	slot = "outer",
	category = "npc",
	builder = "overcoat",
	style = "doorman",
	colors = c("#1E2A45", "#17213A", "#C9A54C"),
	hidden = true,
	tags = { "npc" },
	desc = "Double-breasted greatcoat with gold buttons and epaulettes.",
})
add({
	id = "doorman_cap",
	name = "Doorman's Cap",
	slot = "head",
	category = "npc",
	builder = "cap",
	style = "doorman",
	colors = c("#1E2A45", "#111111", "#C9A54C"),
	hidden = true,
	tags = { "npc" },
	desc = "Peaked cap with gold braid.",
})
add({
	id = "measuring_tape",
	name = "Tailor's Tape",
	slot = "neck",
	category = "npc",
	builder = "tape",
	colors = c("#E3C46F", "#C9A54C", "#2A2522"),
	hidden = true,
	tags = { "npc" },
	desc = "Draped measuring tape.",
})

Catalog.items = items
Catalog.order = order

---------------------------------------------------------------------------------------------------
-- Starter outfits (free, granted when a player reaches the stage)
---------------------------------------------------------------------------------------------------
Catalog.STAGES = {
	{ id = "student", rank = 0 },
	{ id = "intern", rank = 1 },
	{ id = "analyst", rank = 2 },
}
Catalog.starter = {
	student = {
		top = "hoodie_heather",
		bottom = "jeans_indigo",
		shoes = "sneaker_white",
		neck = "lanyard_student",
		bag = "backpack_canvas",
	},
	intern = { top = "oxford_blue", bottom = "chinos_khaki", shoes = "loafer_cognac", neck = "lanyard_intern" },
	analyst = { top = "oxford_white", bottom = "trousers_flannel", shoes = "oxford_black", neck = "tie_navy" },
} :: { [string]: { [string]: string } }

local function rankNumber(rank: any): number
	if type(rank) == "number" and rank == rank then
		return rank
	end
	return 0
end

-- Stage id for a rank (the highest stage whose rank <= rank).
function Catalog.stageFor(rank: number?): string
	local r = rankNumber(rank)
	local best = Catalog.STAGES[1].id
	for _, s in Catalog.STAGES do
		if r >= s.rank then
			best = s.id
		end
	end
	return best
end

function Catalog.starterFor(rank: number?): { [string]: string }
	return table.clone(Catalog.starter[Catalog.stageFor(rank)])
end

-- Every starter item for the stages a player of this rank has reached (sorted, unique).
function Catalog.starterItems(rank: number?): { string }
	local r = rankNumber(rank)
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	for _, s in Catalog.STAGES do
		if r >= s.rank then
			for _, id in Catalog.starter[s.id] do
				if not seen[id] then
					seen[id] = true
					table.insert(out, id)
				end
			end
		end
	end
	table.sort(out)
	return out
end

function Catalog.isStarter(itemId: string, rank: number?): boolean
	for _, id in Catalog.starterItems(rank) do
		if id == itemId then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------------------------------
-- NPC outfit presets (NpcRig.build({ preset = "barista" }) or Catalog.presets.barista.equipped)
---------------------------------------------------------------------------------------------------
Catalog.presets = {
	barista = {
		equipped = { top = "tee_white", outer = "apron_barista", bottom = "jeans_black", shoes = "sneaker_canvas" },
		hairStyle = "bun",
		hairColor = "#3B2A1E",
		skin = "#B07A4F",
	},
	professor = {
		equipped = {
			top = "oxford_blue",
			outer = "thrift_blazer",
			bottom = "chinos_khaki",
			shoes = "oxford_oxblood",
			neck = "tie_knit_black",
			eyes = "glasses_round_wire",
		},
		hairStyle = "side_part",
		hairColor = "#C8C8C8",
		skin = "#F1D2B6",
	},
	recruiter = {
		equipped = {
			top = "blouse_ivory",
			outer = "suit_navy_2b",
			bottom = "skirt_pencil_charcoal",
			shoes = "heels_block_black",
			wrist = "watch_meridian_steel",
		},
		hairStyle = "long",
		hairColor = "#1C1712",
		skin = "#8D5A3A",
	},
	receptionist = {
		equipped = {
			top = "shell_black",
			outer = "blazer_navy",
			bottom = "trousers_wide_black",
			shoes = "pumps_black",
			eyes = "glasses_black_rect",
		},
		hairStyle = "ponytail",
		hairColor = "#5C3D25",
		skin = "#E6B98F",
	},
	trader = {
		equipped = {
			top = "oxford_white",
			outer = "trader_jacket",
			bottom = "chinos_khaki",
			shoes = "sneaker_white",
			neck = "tie_regimental",
			wrist = "watch_halden_chrono",
		},
		hairStyle = "buzz",
		hairColor = "#1C1712",
		skin = "#D19A6A",
	},
	md = {
		equipped = {
			top = "oxford_white",
			outer = "suit_charcoal_3p",
			bottom = "suit_charcoal_trousers",
			shoes = "wholecut_bespoke",
			neck = "tie_silver",
			wrist = "watch_astra_moonphase",
		},
		hairStyle = "side_part",
		hairColor = "#6E6E6E",
		skin = "#F4DCC8",
	},
	tailor = {
		equipped = {
			top = "oxford_white",
			outer = "vest_waistcoat",
			bottom = "trousers_flannel",
			shoes = "oxford_oxblood",
			neck = "measuring_tape",
			eyes = "glasses_round_wire",
		},
		hairStyle = "bald",
		hairColor = "#6E6E6E",
		skin = "#B07A4F",
	},
	doorman = {
		equipped = {
			top = "oxford_white",
			outer = "doorman_coat",
			bottom = "suit_navy_trousers",
			shoes = "oxford_black",
			head = "doorman_cap",
		},
		hairStyle = "short",
		hairColor = "#1C1712",
		skin = "#6B4128",
	},
	analyst = {
		equipped = {
			top = "oxford_white",
			outer = "suit_navy_2b",
			bottom = "suit_navy_trousers",
			shoes = "oxford_black",
			neck = "tie_navy",
			wrist = "watch_meridian_steel",
		},
		hairStyle = "short",
		hairColor = "#3B2A1E",
		skin = "#E6B98F",
	},
	associate = {
		equipped = {
			top = "oxford_blue",
			outer = "suit_grey_2b",
			bottom = "suit_grey_trousers",
			shoes = "oxford_black",
			neck = "tie_regimental",
			wrist = "watch_corso_bronze",
			bag = "briefcase_leather",
		},
		hairStyle = "curly",
		hairColor = "#1C1712",
		skin = "#4E2E1C",
	},
	banker = {
		equipped = {
			top = "blouse_blush",
			outer = "suit_charcoal_2b",
			bottom = "trousers_wide_black",
			shoes = "pumps_black",
			wrist = "watch_vanta_gold",
		},
		hairStyle = "bun",
		hairColor = "#1C1712",
		skin = "#D19A6A",
	},
	vp = {
		equipped = {
			top = "oxford_white",
			outer = "suit_navy_db",
			bottom = "suit_navy_trousers",
			shoes = "oxford_oxblood",
			neck = "tie_navy",
			wrist = "watch_vanta_gold",
		},
		hairStyle = "short",
		hairColor = "#5C3D25",
		skin = "#F1D2B6",
	},
	mentor = {
		equipped = {
			top = "oxford_blue",
			outer = "vest_fleece",
			bottom = "chinos_khaki",
			shoes = "loafer_cognac",
			wrist = "watch_halden_chrono",
		},
		hairStyle = "side_part",
		hairColor = "#3B2A1E",
		skin = "#8D5A3A",
	},
	advisor = {
		equipped = {
			top = "sweater_camel_v",
			bottom = "chinos_khaki",
			shoes = "loafer_cognac",
			eyes = "glasses_black_rect",
		},
		hairStyle = "short",
		hairColor = "#7A2E1E",
		skin = "#F1D2B6",
	},
	counselor = {
		equipped = {
			top = "blouse_ivory",
			outer = "blazer_navy",
			bottom = "skirt_aline_camel",
			shoes = "heels_block_black",
			eyes = "glasses_round_wire",
		},
		hairStyle = "curly",
		hairColor = "#3B2A1E",
		skin = "#6B4128",
	},
	club_host = {
		equipped = {
			top = "oxford_white",
			outer = "co_velvet_dinner",
			bottom = "co_midnight_trousers",
			shoes = "oxford_black",
			neck = "co_bowtie",
		},
		hairStyle = "side_part",
		hairColor = "#1C1712",
		skin = "#B07A4F",
	},
	concierge = {
		equipped = {
			top = "oxford_white",
			outer = "vest_waistcoat",
			bottom = "suit_black_trousers",
			shoes = "oxford_black",
			neck = "co_bowtie",
		},
		hairStyle = "short",
		hairColor = "#3B2A1E",
		skin = "#E6B98F",
	},
	watchmaker = {
		equipped = {
			top = "oxford_white",
			outer = "vest_waistcoat",
			bottom = "trousers_flannel",
			shoes = "oxford_black",
			eyes = "glasses_round_wire",
			wrist = "watch_corso_bronze",
		},
		hairStyle = "buzz",
		hairColor = "#C8C8C8",
		skin = "#F4DCC8",
	},
	shoe_clerk = {
		equipped = { top = "polo_navy", bottom = "chinos_khaki", shoes = "loafer_cognac" },
		hairStyle = "ponytail",
		hairColor = "#B98A52",
		skin = "#F1D2B6",
	},
	decorator = {
		equipped = { top = "crewneck_oatmeal", bottom = "trousers_wide_black", shoes = "heels_block_black" },
		hairStyle = "long",
		hairColor = "#8A5A33",
		skin = "#D19A6A",
	},
	bus_driver = {
		equipped = { top = "polo_navy", bottom = "cargo_olive", shoes = "base_shoes", head = "cap_eastbridge" },
		hairStyle = "short",
		hairColor = "#6E6E6E",
		skin = "#8D5A3A",
	},
	newsie = {
		equipped = { top = "tee_white", outer = "denim_jacket", bottom = "cargo_olive", shoes = "sneaker_canvas" },
		hairStyle = "curly",
		hairColor = "#5C3D25",
		skin = "#E6B98F",
	},
	alum = {
		equipped = {
			top = "qzip_navy",
			bottom = "chinos_khaki",
			shoes = "loafer_cognac",
			wrist = "watch_halden_chrono",
		},
		hairStyle = "side_part",
		hairColor = "#3B2A1E",
		skin = "#B07A4F",
	},
	club_president = {
		equipped = {
			top = "oxford_white",
			outer = "thrift_blazer",
			bottom = "chinos_khaki",
			shoes = "loafer_cognac",
			neck = "tie_regimental",
		},
		hairStyle = "short",
		hairColor = "#1C1712",
		skin = "#4E2E1C",
	},
	student_a = {
		equipped = {
			top = "hoodie_maroon",
			bottom = "jeans_indigo",
			shoes = "sneaker_white",
			bag = "backpack_canvas",
			head = "beanie_charcoal",
		},
		hairStyle = "short",
		hairColor = "#1C1712",
		skin = "#8D5A3A",
	},
	student_b = {
		equipped = {
			top = "tee_white",
			outer = "flannel_red",
			bottom = "jeans_black",
			shoes = "sneaker_canvas",
			bag = "backpack_commuter",
		},
		hairStyle = "ponytail",
		hairColor = "#D9B97A",
		skin = "#F1D2B6",
	},
	student_c = {
		equipped = {
			top = "crewneck_oatmeal",
			bottom = "cargo_olive",
			shoes = "sneaker_white",
			neck = "scarf_varsity",
			eyes = "glasses_black_rect",
		},
		hairStyle = "curly",
		hairColor = "#3B2A1E",
		skin = "#6B4128",
	},
	student_d = {
		equipped = {
			top = "hoodie_heather",
			bottom = "jeans_black",
			shoes = "sneaker_white",
			head = "cap_eastbridge",
			wrist = "band_pulse",
		},
		hairStyle = "buzz",
		hairColor = "#1C1712",
		skin = "#D19A6A",
	},
	roommate = {
		equipped = { top = "tee_white", bottom = "cargo_olive", shoes = "sneaker_canvas", head = "beanie_charcoal" },
		hairStyle = "long",
		hairColor = "#5C3D25",
		skin = "#E6B98F",
	},
	intern = {
		equipped = Catalog.starter.intern,
		hairStyle = "short",
		hairColor = "#3B2A1E",
		skin = "#D19A6A",
	},
	mannequin = {
		equipped = {
			top = "oxford_white",
			outer = "suit_navy_2b",
			bottom = "suit_navy_trousers",
			shoes = "oxford_black",
			neck = "tie_navy",
		},
		hairStyle = "bald",
		skin = "#E8E4DC",
	},
} :: { [string]: Preset }

---------------------------------------------------------------------------------------------------
-- Lookups
---------------------------------------------------------------------------------------------------
function Catalog.get(id: any): Item?
	if type(id) ~= "string" then
		return nil
	end
	return items[id]
end

local function sortItems(list: { Item })
	table.sort(list, function(a, b)
		if a.tier ~= b.tier then
			return a.tier < b.tier
		end
		if a.price ~= b.price then
			return a.price < b.price
		end
		return a.id < b.id
	end)
end

function Catalog.bySlot(slot: string, includeHidden: boolean?): { Item }
	local out: { Item } = {}
	for _, id in order do
		local it = items[id]
		if it.slot == slot and (includeHidden or not it.hidden) then
			table.insert(out, it)
		end
	end
	sortItems(out)
	return out
end

function Catalog.list(includeHidden: boolean?): { Item }
	local out: { Item } = {}
	for _, id in order do
		local it = items[id]
		if includeHidden or not it.hidden then
			table.insert(out, it)
		end
	end
	return out
end

-- Free to wear without buying (price 0 cash items: lanyards, base layers).
function Catalog.isFree(item: Item): boolean
	return item.currency == "cash" and item.price == 0
end

-- What a viewer can do with an item (pure; used by WardrobeService and the Wardrobe screen):
--   "owned"  in inventory.owned (or a starter piece for their stage)
--   "free"   costs nothing (and has no requirement)
--   "pass"   needs a game pass the viewer lacks
--   "rank"   needs a higher career rank
--   "buy"    can be bought with cash
function Catalog.access(item: Item, viewer: Viewer): string
	local owned = viewer.owned or {}
	local rank = rankNumber(viewer.rank)
	if item.currency == "pass" then
		local passes = viewer.passes or {}
		if item.pass and passes[item.pass] then
			return "owned"
		end
		return "pass"
	end
	if owned[item.id] or Catalog.isStarter(item.id, rank) then
		return "owned"
	end
	if item.minRank and rank < item.minRank then
		return "rank"
	end
	if Catalog.isFree(item) then
		return "free"
	end
	return "buy"
end

-- Can this viewer wear the item right now? (owned/free and the rank requirement is met)
function Catalog.canWear(item: Item, viewer: Viewer): (boolean, string?)
	if item.hidden then
		return false, "unknown_item"
	end
	local state = Catalog.access(item, viewer)
	if state == "pass" then
		return false, "pass"
	end
	if item.minRank and rankNumber(viewer.rank) < item.minRank then
		return false, "rank"
	end
	if state == "owned" or state == "free" then
		return true, nil
	end
	if state == "rank" then
		return false, "rank"
	end
	return false, "not_owned"
end

-- Number of preset slots open to a viewer.
function Catalog.presetSlotsFor(viewer: Viewer): number
	local passes = viewer.passes or {}
	if passes[Catalog.PRESET_SLOTS.pass] then
		return Catalog.PRESET_SLOTS.max
	end
	return Catalog.PRESET_SLOTS.free
end

-- Rank titles for "requires" labels (career owns the real role table; these are display fallbacks).
Catalog.RANK_TITLES = {
	[0] = "Student",
	[1] = "Intern",
	[2] = "Analyst",
	[3] = "Associate",
	[4] = "Vice President",
	[5] = "Director",
	[6] = "Managing Director",
	[10] = "Partner",
}

function Catalog.rankTitle(rank: number): string
	local best = Catalog.RANK_TITLES[0]
	local bestRank = -1
	for r, title in Catalog.RANK_TITLES do
		if r <= rank and r > bestRank then
			best, bestRank = title, r
		end
	end
	return best
end

---------------------------------------------------------------------------------------------------
-- Player-facing text (wardrobe UI and server messages)
---------------------------------------------------------------------------------------------------
Catalog.strings = {
	title = "Wardrobe",
	subtitle = "Your Career Look",
	menu = "Wardrobe",
	prompt = "Wardrobe",
	slot_top = "Tops",
	slot_outer = "Jackets",
	slot_bottom = "Bottoms",
	slot_shoes = "Shoes",
	slot_neck = "Neckwear",
	slot_wrist = "Watches",
	slot_eyes = "Eyewear",
	slot_head = "Hats",
	slot_bag = "Bags",
	tab_presets = "Outfits",
	equip = "Wear",
	unequip = "Take off",
	equipped = "Wearing",
	owned = "Owned",
	free = "Free",
	buy = "Buy {price}",
	buying = "Buying...",
	locked_rank = "Requires {role}",
	locked_pass = "{pass} pass",
	pass_CornerOffice = "Corner Office",
	pass_ExecutiveClub = "Executive Club",
	tier = "Tier {tier}",
	wear_avatar = "Wear my avatar",
	wear_avatar_hint = "Show your own Roblox avatar instead of your Career Look.",
	preview_hint = "Drag to turn",
	reset_preview = "Reset",
	preset_name = "Outfit {index}",
	preset_empty = "Empty slot",
	preset_save = "Save current",
	preset_load = "Wear",
	preset_locked = "Executive Club",
	preset_saved = "Outfit saved.",
	preset_loaded = "Outfit on.",
	purchased = "Bought {name}.",
	starter_granted = "New outfit pieces added to your wardrobe.",
	empty_slot = "Nothing in this category yet.",
	err_unknown_item = "That item doesn't exist.",
	err_bad_slot = "That doesn't go there.",
	err_not_owned = "You don't own that yet.",
	err_rank = "Your career rank is too low for that.",
	err_pass = "That needs a game pass.",
	err_not_loaded = "Your wardrobe is still loading.",
	err_locked = "That outfit slot is locked.",
	err_empty = "That outfit slot is empty.",
	err_bad_name = "Pick a shorter name.",
	err_shop_closed = "The shop is closed right now. Try again soon.",
	err_shop = "Couldn't buy that.",
	err_generic = "Something went wrong. Please try again.",
	err_timeout = "The server took too long to answer.",
	err_rate_limited = "Slow down a little.",
}

-- "{key}" substitution over Catalog.strings.
function Catalog.text(key: string, vars: { [string]: any }?): string
	local s = Catalog.strings[key]
	if s == nil then
		return key
	end
	if vars then
		s = (
			string.gsub(s, "{(%w+)}", function(k)
				local v = vars[k]
				return if v ~= nil then tostring(v) else "{" .. k .. "}"
			end)
		)
	end
	return s
end

return Catalog
