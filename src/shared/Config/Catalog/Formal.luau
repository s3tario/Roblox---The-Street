--!strict
-- Catalog: suits, formal shoes, accessories and the watch ladder (cash items).
-- Item definitions only (see Catalog/init.luau for the schema). Each entry becomes Catalog.items[id].

local function c(primary: string, secondary: string?, accent: string?): { [string]: string? }
	return { primary = primary, secondary = secondary, accent = accent }
end

local items: { { [string]: any } } = {}
local function add(def: { [string]: any })
	table.insert(items, def)
end

-- Suits: three cuts (two-button, double-breasted, three-piece) x six colours, Hartwell Tailors -----------
-- Jackets are "outer" items; the matching trousers are sold separately as "bottom" items.
local SUITS = {
	{ key = "navy", label = "Navy", primary = "#1D2A47", secondary = "#17213A", premium = 0, trousers = 900 },
	{ key = "charcoal", label = "Charcoal", primary = "#3A3D44", secondary = "#2F3238", premium = 0, trousers = 900 },
	{ key = "black", label = "Black", primary = "#16171A", secondary = "#101113", premium = 200, trousers = 950 },
	{ key = "grey", label = "Mid-Grey", primary = "#6C7078", secondary = "#5B5F66", premium = -100, trousers = 900 },
	{
		key = "pinstripe",
		label = "Navy Pinstripe",
		primary = "#1B2742",
		secondary = "#151F36",
		premium = 1000,
		trousers = 1400,
		pattern = "pinstripe",
		minRank = 4,
	},
	{ key = "camel", label = "Camel", primary = "#A9834F", secondary = "#8F6E41", premium = 400, trousers = 1000 },
}
local CUTS = {
	{
		key = "two_button",
		short = "2b",
		label = "Two-Button Jacket",
		text = "classic two-button",
		price = 1600,
		tier = 3,
	},
	{
		key = "double_breasted",
		short = "db",
		label = "Double-Breasted Jacket",
		text = "double-breasted, peak-lapel",
		price = 2400,
		tier = 4,
		minRank = 3,
	},
	{
		key = "three_piece",
		short = "3p",
		label = "Three-Piece Jacket",
		text = "three-piece (waistcoat included)",
		price = 2900,
		tier = 4,
		minRank = 3,
	},
}
for _, colour in SUITS do
	for _, cut in CUTS do
		local minRank: number? = cut.minRank
		if colour.minRank and (minRank == nil or colour.minRank > minRank) then
			minRank = colour.minRank
		end
		add({
			id = "suit_" .. colour.key .. "_" .. cut.short,
			name = colour.label .. " " .. cut.label,
			slot = "outer",
			category = "suits",
			price = cut.price + colour.premium,
			builder = "jacket",
			style = cut.key,
			pattern = colour.pattern,
			minRank = minRank,
			colors = c(colour.primary, colour.secondary, "#F4F4F0"),
			tier = if colour.pattern then 5 else cut.tier,
			tags = { "suits", "tailoring", cut.key, colour.key },
			desc = "Hartwell Tailors "
				.. string.lower(colour.label)
				.. " worsted, "
				.. cut.text
				.. ". Pair it with the matching trousers.",
		})
	end
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
		tags = { "suits", "tailoring", s.key },
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

return items
