--!strict
-- Catalog: premium game-pass collections and hidden NPC pieces.
-- Item definitions only (see Catalog/init.luau for the schema). Each entry becomes Catalog.items[id].

local function c(primary: string, secondary: string?, accent: string?): { [string]: string? }
	return { primary = primary, secondary = secondary, accent = accent }
end

local items: { { [string]: any } } = {}
local function add(def: { [string]: any })
	table.insert(items, def)
end

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

return items
