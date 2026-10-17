--!strict
-- Catalog: everyday pieces that fill clothing levels 1-3 in every slot (v3 §5), so a student on a Common family's
-- $500 can reach Outfit Level 2 (the regional walk-on desk) and a first paycheck reaches Level 3. Cash items.
-- Item definitions only (see Catalog/init.luau for the schema). Each entry becomes Catalog.items[id].

local function c(primary: string, secondary: string?, accent: string?): { [string]: string? }
	return { primary = primary, secondary = secondary, accent = accent }
end

local items: { { [string]: any } } = {}
local function add(def: { [string]: any })
	table.insert(items, def)
end

-- Level 1-2 basics ----------------------------------------------------------------------------------
add({
	id = "chore_jacket_canvas",
	name = "Canvas Chore Jacket",
	slot = "outer",
	category = "campus",
	price = 75,
	builder = "overshirt",
	colors = c("#8A7A5C", "#6E6148", "#3B2A20"),
	tier = 1,
	tags = { "campus", "casual", "layer" },
	desc = "A boxy canvas work jacket with patch pockets. Survives bike locks and bus seats.",
})
add({
	id = "polo_campus",
	name = "Campus Pique Polo",
	slot = "top",
	category = "campus",
	price = 75,
	builder = "polo",
	colors = c("#F2F1EC", "#E1E0DA", "#6B1F2A"),
	tier = 2,
	tags = { "campus", "smart" },
	desc = "A white pique polo with a maroon emblem. Your first interview shirt, probably.",
})
add({
	id = "chinos_campus",
	name = "Campus Chinos, Stone",
	slot = "bottom",
	category = "campus",
	price = 90,
	builder = "chinos",
	colors = c("#C3B697", "#4A3424", "#B8933F"),
	tier = 2,
	tags = { "campus", "smart" },
	desc = "Pressed stone chinos and a brown belt: the interview-day default.",
})
add({
	id = "derby_suede_sand",
	name = "Suede Derbies, Sand",
	slot = "shoes",
	category = "shoes",
	price = 130,
	builder = "oxford",
	style = "derby",
	finish = "suede",
	colors = c("#B59A76", "#3B2A1E", "#8C7356"),
	tier = 2,
	tags = { "shoes", "smart" },
	desc = "Sand suede derbies on a crepe-look sole. Smart enough, cheap enough.",
})
add({
	id = "glasses_clear",
	name = "Clear Acetate Frames",
	slot = "eyes",
	category = "campus",
	price = 40,
	builder = "glasses",
	style = "rect",
	colors = c("#B9BDC2", "#D6D9DC"),
	tier = 1,
	tags = { "eyewear", "campus" },
	desc = "See-through frames with blue-light lenses for all-night problem sets.",
})
add({
	id = "cap_wool_navy",
	name = "Wool Ball Cap, Navy",
	slot = "head",
	category = "accessories",
	price = 85,
	builder = "cap",
	colors = c("#1F2A44", "#18213A", "#C9A54C"),
	tier = 2,
	tags = { "hat" },
	desc = "A clean navy wool cap with a tonal strap. No logo, no comment.",
})

-- Level 3: business formal ------------------------------------------------------------------------
add({
	id = "shirt_poplin_white",
	name = "White Poplin Dress Shirt",
	slot = "top",
	category = "business",
	price = 260,
	builder = "shirt",
	colors = c("#F8F8F5", "#E8E8E3", "#FFFFFF"),
	tier = 3,
	tags = { "business", "shirt", "formal" },
	desc = "Two-ply poplin with a semi-spread collar. Made to be worn under a suit.",
})
add({
	id = "shirt_twill_blue",
	name = "Blue Twill Dress Shirt",
	slot = "top",
	category = "business",
	price = 280,
	builder = "shirt",
	colors = c("#C3D6EC", "#B0C6E0", "#F4F4F0"),
	tier = 3,
	tags = { "business", "shirt", "formal" },
	desc = "Pale blue twill with a crisp collar. The second shirt every analyst buys.",
})
add({
	id = "blouse_tieneck_navy",
	name = "Tie-Neck Silk Blouse, Navy",
	slot = "top",
	category = "womens",
	price = 320,
	builder = "blouse",
	colors = c("#22304F", "#1A2640", "#F7F3EA"),
	tier = 3,
	tags = { "womens", "silk", "formal" },
	desc = "Navy silk crepe de chine with a soft tie at the neck.",
})
add({
	id = "qzip_cashmere_charcoal",
	name = "Cashmere Quarter-Zip, Charcoal",
	slot = "top",
	category = "business",
	price = 480,
	builder = "quarterzip",
	colors = c("#3C3F45", "#30333A", "#C0C4C8"),
	tier = 3,
	tags = { "business", "knit", "logo" },
	desc = "Charcoal cashmere quarter-zip. Shows your company's logo on the chest.",
})
add({
	id = "vest_gilet_navy",
	name = "Quilted Gilet, Navy",
	slot = "outer",
	category = "business",
	price = 340,
	builder = "vest",
	style = "fleece",
	colors = c("#1F2A44", "#18213A", "#C0C4C8"),
	tier = 3,
	tags = { "business", "layer", "finance", "logo" },
	desc = "A slim quilted gilet for cold trading floors. Shows your company's logo on the chest.",
})
add({
	id = "glasses_titanium",
	name = "Titanium Round Frames",
	slot = "eyes",
	category = "accessories",
	price = 340,
	builder = "glasses",
	style = "round",
	colors = c("#8E9399", "#A7ACB2"),
	tier = 3,
	tags = { "eyewear" },
	desc = "Feather-light titanium rounds. Nobody notices them, which is the point.",
})
add({
	id = "briefcase_nylon",
	name = "Ballistic Nylon Briefcase",
	slot = "bag",
	category = "accessories",
	price = 420,
	builder = "briefcase",
	colors = c("#222326", "#18191B", "#8E9397"),
	tier = 3,
	tags = { "bag", "commute" },
	desc = "A slim black nylon briefcase with leather handles and a laptop sleeve.",
})

return items
