--!strict
-- Decor catalogue, housing slot kinds, housing contexts and room themes (owned by `shop`; contracts §7, spec §11,
-- v3 §13). Pure data plus lookups: safe on the server, the client and under Lune.
--
--   Decor.items[id] = { id, name, prop, opts?, slots = { SlotKind }, category, price, currency = "cash" | "pass",
--                       pass?, minRank?, contexts?, desc }
--       prop      a Shared/Assets/Props id; the item is drawn with Props.build(prop, parent, cf, opts)
--       slots     the slot kinds the item can stand in (see Decor.ACCEPTS for what each slot kind takes)
--       contexts  where it may be placed (nil = every context)
--   Decor.list() -> { Item } (display order)      Decor.get(id) -> Item?      Decor.byCategory(cat) -> { Item }
--   Decor.CATEGORIES = { {id, label} }            shop tabs, in order
--   Decor.PRICE_RANGES[category] = { lo, hi }     spec §11 anchors (desk items, furniture, art) + campus pieces
--
-- Slot kinds (the `SlotKind` attribute on DecorSlot markers in office floor templates and housing units):
--   desk_item  a spot on a desk top (Props mount "desk")      wall_art  a spot on a wall (mount "wall")
--   floor      a floor spot for furniture (also takes floor plants and lamps)
--   plant      a floor plant spot          lamp  a floor lamp spot          rug  a floor rug spot
--   plaque     deal plaques only (HousingService renders career.plaques there; never player decor)
--   Decor.MOUNT_FOR[kind] -> the Props mount an item standing in that slot must have
--
-- Contexts (where a player decorates): dorm (students), apartment (employed), desk (open-plan desk on the
-- company floor), office (a private office at rank >= 3). Decor.CONTEXTS[id] = { id, label, title, budget, themed }
--   budget   the most runtime parts that player's decor may add there (keeps servers inside the runtime budget)
--   themed   room themes (ThemeWall / ThemeFloor parts) apply in this context
--
-- Themes: Decor.themes = { {id, name, desc, pass?, wall?, floor?} }   Decor.theme(id) -> Theme?
--   wall/floor = { color = "#RRGGBB", material = Enum.Material }; "classic" keeps the template's own look.
--   Themes with pass = "OfficeThemes" need the Office Theme Pass (MonetizationService:OwnsPass).

local Decor = {}

export type SlotKind = "desk_item" | "wall_art" | "floor" | "plant" | "lamp" | "rug" | "plaque"
export type Item = {
	id: string,
	name: string,
	prop: string,
	opts: { [string]: any }?,
	slots: { string },
	category: string,
	price: number,
	currency: string,
	pass: string?,
	minRank: number?,
	contexts: { string }?,
	desc: string,
}
export type Surface = { color: string, material: Enum.Material }
export type Theme = {
	id: string,
	name: string,
	desc: string,
	pass: string?,
	wall: Surface?,
	floor: Surface?,
}
export type Context = {
	id: string,
	label: string,
	title: string,
	budget: number,
	themed: boolean,
}

Decor.SLOT_KINDS = { "desk_item", "wall_art", "floor", "plant", "lamp", "rug", "plaque" } :: { string }
-- Kinds a player can put decor into (plaque slots are filled by deal plaques).
Decor.PLACEABLE = { "desk_item", "wall_art", "floor", "plant", "lamp", "rug" } :: { string }
Decor.PLAQUE = "plaque"

-- What each slot kind accepts (item slot kinds).
Decor.ACCEPTS = {
	desk_item = { desk_item = true },
	wall_art = { wall_art = true },
	floor = { floor = true, plant = true, lamp = true },
	plant = { plant = true },
	lamp = { lamp = true },
	rug = { rug = true },
	plaque = {},
} :: { [string]: { [string]: boolean } }

-- The Props mount every item listing a slot kind must have (tests enforce it).
Decor.MOUNT_FOR = {
	desk_item = "desk",
	wall_art = "wall",
	floor = "floor",
	plant = "floor",
	lamp = "floor",
	rug = "floor",
	plaque = "desk",
} :: { [string]: string }

Decor.KIND_LABELS = {
	desk_item = "Desk spot",
	wall_art = "Wall",
	floor = "Floor spot",
	plant = "Plant spot",
	lamp = "Lamp spot",
	rug = "Rug",
	plaque = "Deal plaque",
} :: { [string]: string }

Decor.CONTEXT_ORDER = { "desk", "office", "apartment", "dorm" } :: { string }
Decor.CONTEXTS = {
	dorm = { id = "dorm", label = "Dorm", title = "Your Dorm Room", budget = 160, themed = true },
	apartment = { id = "apartment", label = "Apartment", title = "Your Apartment", budget = 320, themed = true },
	desk = { id = "desk", label = "Desk", title = "Your Desk", budget = 90, themed = false },
	office = { id = "office", label = "Office", title = "Your Office", budget = 320, themed = true },
} :: { [string]: Context }

Decor.CATEGORIES = {
	{ id = "desk", label = "Desk" },
	{ id = "art", label = "Art" },
	{ id = "furniture", label = "Furniture" },
	{ id = "plants", label = "Plants" },
	{ id = "lighting", label = "Lighting" },
	{ id = "rugs", label = "Rugs" },
	{ id = "campus", label = "Dorm" },
} :: { { id: string, label: string } }

-- Spec §11 anchors: desk items $50-$3,000, furniture $400-$25,000, art $2,000-$150,000. Plants, lamps and rugs
-- are furnishings ($400 and up); campus dorm pieces stay student-priced.
Decor.PRICE_RANGES = {
	desk = { 50, 3000 },
	furniture = { 400, 25000 },
	art = { 2000, 150000 },
	plants = { 400, 25000 },
	lighting = { 400, 25000 },
	rugs = { 400, 25000 },
	campus = { 40, 400 },
} :: { [string]: { number } }

---------------------------------------------------------------------------------------------------
-- Items (display order inside each category = list order)
---------------------------------------------------------------------------------------------------
local HOME_AND_OFFICE = { "apartment", "office" }
local NOT_DESK = { "dorm", "apartment", "office" }
local HOME = { "dorm", "apartment" }

local DEFS: { { [string]: any } } = {
	-- Desk items ---------------------------------------------------------------------------------
	{
		id = "desk_mug_navy",
		name = "Street Mug",
		prop = "coffee_mug",
		opts = { color = "#1D2A47" },
		slots = { "desk_item" },
		category = "desk",
		price = 50,
		desc = "Navy ceramic. Holds the fourth coffee of the day.",
	},
	{
		id = "desk_stress_ball",
		name = "Stress Ball",
		prop = "stress_ball",
		opts = { color = "#E2532F" },
		slots = { "desk_item" },
		category = "desk",
		price = 60,
		desc = "For the hour before the model is due.",
	},
	{
		id = "desk_succulent",
		name = "Desk Succulent",
		prop = "plant_desk",
		opts = { variant = "succulent" },
		slots = { "desk_item" },
		category = "desk",
		price = 80,
		desc = "Survives on fluorescent light and neglect.",
	},
	{
		id = "desk_cactus",
		name = "Terracotta Cactus",
		prop = "cactus",
		slots = { "desk_item" },
		category = "desk",
		price = 90,
		desc = "Low maintenance, high attitude.",
	},
	{
		id = "desk_fern",
		name = "Desk Fern",
		prop = "plant_desk",
		opts = { variant = "fern" },
		slots = { "desk_item" },
		category = "desk",
		price = 120,
		desc = "A little green between the monitors.",
	},
	{
		id = "desk_photo_walnut",
		name = "Walnut Photo Frame",
		prop = "photo_frame",
		opts = { color = "#5A3A24" },
		slots = { "desk_item" },
		category = "desk",
		price = 150,
		desc = "Proof you have a life outside the office.",
	},
	{
		id = "desk_book_stack",
		name = "Finance Classics",
		prop = "book_stack",
		opts = { count = 4 },
		slots = { "desk_item" },
		category = "desk",
		price = 180,
		desc = "Valuation, credit and a well-thumbed memoir.",
	},
	{
		id = "desk_organizer",
		name = "Desk Organizer",
		prop = "desk_organizer",
		slots = { "desk_item" },
		category = "desk",
		price = 220,
		desc = "Pens, sticky notes and a calculator that has seen things.",
	},
	{
		id = "desk_lamp_banker",
		name = "Banker's Lamp",
		prop = "desk_lamp",
		opts = { lit = true },
		slots = { "desk_item" },
		category = "desk",
		price = 450,
		desc = "Green glass, brass stem, late nights.",
	},
	{
		id = "desk_photo_gold",
		name = "Gilded Photo Frame",
		prop = "photo_frame",
		opts = { color = "#C9A54C" },
		slots = { "desk_item" },
		category = "desk",
		price = 650,
		desc = "The closing dinner, framed in gold.",
	},
	{
		id = "desk_globe",
		name = "Desk Globe",
		prop = "globe",
		slots = { "desk_item" },
		category = "desk",
		price = 900,
		desc = "Spin it during cross-border calls.",
	},
	{
		id = "desk_bonsai",
		name = "Bonsai Juniper",
		prop = "bonsai",
		slots = { "desk_item" },
		category = "desk",
		price = 1200,
		desc = "Patient, deliberate, perfectly pruned.",
	},
	{
		id = "desk_bull_bear",
		name = "Bronze Bull & Bear",
		prop = "mini_bull_bear",
		slots = { "desk_item" },
		category = "desk",
		price = 2500,
		minRank = 2,
		desc = "Both sides of every market, on a marble base.",
	},

	-- Art ----------------------------------------------------------------------------------------
	{
		id = "art_print_skyline",
		name = "Skyline Print",
		prop = "wall_art",
		opts = { variant = 1, width = 4, height = 3 },
		slots = { "wall_art" },
		category = "art",
		price = 2000,
		desc = "The Street at dusk, signed and numbered.",
	},
	{
		id = "art_award",
		name = "Framed Industry Award",
		prop = "award_plaque",
		slots = { "wall_art" },
		category = "art",
		price = 2200,
		desc = "Walnut and brass, for a year worth remembering.",
	},
	{
		id = "art_print_abstract",
		name = "Abstract Print",
		prop = "wall_art",
		opts = { variant = 3, width = 4.5, height = 3.2 },
		slots = { "wall_art" },
		category = "art",
		price = 3500,
		desc = "Bold blocks of colour for a quiet office.",
	},
	{
		id = "art_print_gallery",
		name = "Gallery-Lit Print",
		prop = "wall_art",
		opts = { variant = 6, width = 6, height = 4, lit = true },
		slots = { "wall_art" },
		category = "art",
		price = 9500,
		desc = "A picture light makes anything look expensive.",
	},
	{
		id = "art_canvas_harbor",
		name = "Harbor at Dawn",
		prop = "art_canvas_large",
		opts = { variant = 2 },
		slots = { "wall_art" },
		category = "art",
		price = 18000,
		contexts = NOT_DESK,
		desc = "A large canvas of the old harbor before the bell.",
	},
	{
		id = "art_canvas_modern",
		name = "Composition in Navy",
		prop = "art_canvas_large",
		opts = { variant = 4 },
		slots = { "wall_art" },
		category = "art",
		price = 28000,
		contexts = NOT_DESK,
		desc = "The curator called it confident. So is your book.",
	},
	{
		id = "art_canvas_gold",
		name = "Gold Leaf Triptych",
		prop = "art_canvas_large",
		opts = { variant = 5 },
		slots = { "wall_art" },
		category = "art",
		price = 45000,
		minRank = 3,
		contexts = HOME_AND_OFFICE,
		desc = "Warm gold for a corner office.",
	},
	{
		id = "art_canvas_masterwork",
		name = "The Closing Bell (Masterwork)",
		prop = "art_canvas_large",
		opts = { variant = 8 },
		slots = { "wall_art" },
		category = "art",
		price = 150000,
		minRank = 4,
		contexts = HOME_AND_OFFICE,
		desc = "The painting every managing director pretends not to want.",
	},
	{
		id = "art_sculpture",
		name = "Abstract Sculpture",
		prop = "sculpture_abstract",
		slots = { "floor" },
		category = "art",
		price = 16000,
		contexts = NOT_DESK,
		desc = "Brushed metal on a white plinth. Clients always ask.",
	},
	{
		id = "art_pedestal",
		name = "Gallery Pedestal",
		prop = "art_pedestal",
		slots = { "floor" },
		category = "art",
		price = 22000,
		minRank = 3,
		contexts = HOME_AND_OFFICE,
		desc = "A small masterpiece under a spotlight.",
	},

	-- Furniture ----------------------------------------------------------------------------------
	{
		id = "furn_filing_cabinet",
		name = "Steel Filing Cabinet",
		prop = "filing_cabinet",
		slots = { "floor" },
		category = "furniture",
		price = 400,
		desc = "Four drawers of signed engagement letters.",
	},
	{
		id = "furn_wall_clock",
		name = "Station Wall Clock",
		prop = "wall_clock",
		slots = { "wall_art" },
		category = "furniture",
		price = 450,
		desc = "Never late for the 7 a.m. call.",
	},
	{
		id = "furn_armchair",
		name = "Club Armchair",
		prop = "armchair",
		slots = { "floor" },
		category = "furniture",
		price = 1200,
		desc = "Deep, soft and always occupied by a visitor.",
	},
	{
		id = "furn_bookshelf",
		name = "Oak Bookshelf",
		prop = "bookshelf",
		opts = { tier = 2 },
		slots = { "floor" },
		category = "furniture",
		price = 1800,
		desc = "Room for annual reports and the books you meant to read.",
	},
	{
		id = "furn_coffee_table",
		name = "Marble Coffee Table",
		prop = "coffee_table",
		slots = { "floor" },
		category = "furniture",
		price = 2400,
		contexts = NOT_DESK,
		desc = "White marble with a brass trim.",
	},
	{
		id = "furn_record_player",
		name = "Walnut Record Player",
		prop = "record_player",
		slots = { "floor" },
		category = "furniture",
		price = 2800,
		contexts = NOT_DESK,
		desc = "Vinyl for the weekend you will eventually have.",
	},
	{
		id = "furn_bar_cart",
		name = "Brass Bar Cart",
		prop = "bar_cart",
		slots = { "floor" },
		category = "furniture",
		price = 3200,
		contexts = NOT_DESK,
		desc = "Crystal decanters for closing toasts.",
	},
	{
		id = "furn_office_sofa",
		name = "Office Sofa",
		prop = "sofa_office",
		slots = { "floor" },
		category = "furniture",
		price = 3800,
		contexts = NOT_DESK,
		desc = "For the all-nighter power nap.",
	},
	{
		id = "furn_trophy_shelf",
		name = "Trophy Shelf",
		prop = "trophy_shelf",
		slots = { "floor" },
		category = "furniture",
		price = 4200,
		contexts = NOT_DESK,
		desc = "Glass shelves lit for your achievements.",
	},
	{
		id = "furn_lounge_chair",
		name = "Leather Lounge Chair",
		prop = "lounge_chair",
		slots = { "floor" },
		category = "furniture",
		price = 6500,
		contexts = NOT_DESK,
		desc = "Molded walnut and black leather. A design classic.",
	},
	{
		id = "furn_wine_rack",
		name = "Walnut Wine Rack",
		prop = "wine_rack",
		slots = { "floor" },
		category = "furniture",
		price = 7500,
		minRank = 2,
		contexts = HOME_AND_OFFICE,
		desc = "Vintages from every deal you closed.",
	},
	{
		id = "furn_leather_sofa",
		name = "Chesterfield Sofa",
		prop = "leather_sofa",
		slots = { "floor" },
		category = "furniture",
		price = 9500,
		contexts = HOME_AND_OFFICE,
		desc = "Oxblood leather, buttoned and studded.",
	},
	{
		id = "furn_humidor",
		name = "Cedar Humidor Cabinet",
		prop = "cigar_humidor",
		slots = { "floor" },
		category = "furniture",
		price = 11000,
		minRank = 3,
		contexts = HOME_AND_OFFICE,
		desc = "Lit cherry cabinet for the corner office.",
	},
	{
		id = "furn_aquarium",
		name = "Saltwater Aquarium",
		prop = "aquarium",
		slots = { "floor" },
		category = "furniture",
		price = 12000,
		contexts = HOME_AND_OFFICE,
		desc = "Calm blue water. The fish don't take meetings.",
	},
	{
		id = "furn_fireplace",
		name = "Marble Fireplace",
		prop = "fireplace",
		slots = { "wall_art" },
		category = "furniture",
		price = 24000,
		minRank = 3,
		contexts = HOME_AND_OFFICE,
		desc = "Carrara marble surround with a real glow.",
	},
	{
		id = "furn_grand_piano",
		name = "Concert Grand Piano",
		prop = "piano_grand",
		slots = { "floor" },
		category = "furniture",
		price = 25000,
		minRank = 4,
		contexts = HOME_AND_OFFICE,
		desc = "Black lacquer and gold. Lessons not included.",
	},

	-- Plants -------------------------------------------------------------------------------------
	{
		id = "plant_fig",
		name = "Fiddle-Leaf Fig",
		prop = "plant_floor",
		opts = { variant = "fig" },
		slots = { "plant" },
		category = "plants",
		price = 450,
		desc = "Big leaves, bigger presence.",
	},
	{
		id = "plant_snake",
		name = "Snake Plant",
		prop = "plant_floor",
		opts = { variant = "snake" },
		slots = { "plant" },
		category = "plants",
		price = 520,
		desc = "Thrives on long hours and no daylight.",
	},
	{
		id = "plant_palm",
		name = "Parlor Palm",
		prop = "plant_floor",
		opts = { variant = "palm" },
		slots = { "plant" },
		category = "plants",
		price = 800,
		desc = "A touch of the tropics by the window.",
	},

	-- Lighting -----------------------------------------------------------------------------------
	{
		id = "lamp_floor_brass",
		name = "Brass Floor Lamp",
		prop = "lamp_floor",
		slots = { "lamp" },
		category = "lighting",
		price = 600,
		desc = "Warm light for reading term sheets.",
	},
	{
		id = "lamp_floor_black",
		name = "Matte Black Floor Lamp",
		prop = "lamp_floor",
		opts = { accent = "#1A1A1A", color = "#F4F1EA" },
		slots = { "lamp" },
		category = "lighting",
		price = 750,
		desc = "Minimal, modern, quietly expensive.",
	},
	{
		id = "lamp_arc_chrome",
		name = "Chrome Arc Lamp",
		prop = "lamp_arc",
		slots = { "lamp" },
		category = "lighting",
		price = 1900,
		desc = "A marble base and a long chrome arc.",
	},

	-- Rugs ---------------------------------------------------------------------------------------
	{
		id = "rug_round_sand",
		name = "Round Sand Rug",
		prop = "rug_round",
		opts = { size = 8 },
		slots = { "rug" },
		category = "rugs",
		price = 900,
		desc = "Soft wool in sand and navy.",
	},
	{
		id = "rug_office_navy",
		name = "Navy Office Rug",
		prop = "rug_office",
		opts = { width = 8, depth = 6 },
		slots = { "rug" },
		category = "rugs",
		price = 1400,
		desc = "The firm's carpet, but yours.",
	},
	{
		id = "rug_modern_terracotta",
		name = "Terracotta Modern Rug",
		prop = "rug_modern",
		slots = { "rug" },
		category = "rugs",
		price = 2600,
		desc = "Geometric lines in warm terracotta.",
	},
	{
		id = "rug_persian_crimson",
		name = "Crimson Persian Rug",
		prop = "rug_persian",
		slots = { "rug" },
		category = "rugs",
		price = 6800,
		desc = "Hand-knotted crimson and gold.",
	},
	{
		id = "rug_persian_navy",
		name = "Midnight Persian Rug",
		prop = "rug_persian",
		opts = { color = "#1D2A47", accent = "#C9A54C" },
		slots = { "rug" },
		category = "rugs",
		price = 7200,
		desc = "Deep navy with a gold medallion.",
	},

	-- Dorm pieces (campus) -----------------------------------------------------------------------
	{
		id = "campus_pizza_box",
		name = "Cold Pizza Stack",
		prop = "pizza_box",
		slots = { "floor" },
		category = "campus",
		price = 40,
		contexts = HOME,
		desc = "Decorative. Mostly.",
	},
	{
		id = "campus_poster_wall",
		name = "Poster Wall",
		prop = "poster_wall",
		slots = { "wall_art" },
		category = "campus",
		price = 60,
		contexts = HOME,
		desc = "Band posters, a pennant and a bull market print.",
	},
	{
		id = "campus_mini_fridge",
		name = "Mini Fridge",
		prop = "mini_fridge",
		slots = { "floor" },
		category = "campus",
		price = 180,
		contexts = NOT_DESK,
		desc = "Energy drinks, cold brew and one sad lemon.",
	},
	{
		id = "campus_trash_can",
		name = "Dented Trash Can",
		prop = "trash_can",
		slots = { "floor" },
		category = "campus",
		price = 45,
		contexts = HOME,
		desc = "Authentic Eastbridge grit.",
	},
	{
		id = "campus_lockers",
		name = "Salvaged Lockers",
		prop = "lockers",
		slots = { "floor" },
		category = "campus",
		price = 260,
		contexts = HOME,
		desc = "Rescued from the old gym. Smells faintly of it.",
	},
	{
		id = "campus_vending_machine",
		name = "Retro Vending Machine",
		prop = "vending_machine",
		slots = { "floor" },
		category = "campus",
		price = 400,
		contexts = HOME,
		desc = "It still takes quarters. It still keeps them.",
	},
}

local items: { [string]: Item } = {}
local order: { Item } = {}
for _, d in DEFS do
	assert(items[d.id] == nil, "Decor: duplicate item id " .. tostring(d.id))
	local item: Item = {
		id = d.id,
		name = d.name,
		prop = d.prop,
		opts = d.opts,
		slots = d.slots,
		category = d.category,
		price = d.price,
		currency = d.currency or "cash",
		pass = d.pass,
		minRank = d.minRank,
		contexts = d.contexts,
		desc = d.desc,
	}
	items[item.id] = item
	table.insert(order, item)
end
Decor.items = items

function Decor.get(id: any): Item?
	if type(id) ~= "string" then
		return nil
	end
	return items[id]
end

function Decor.list(): { Item }
	return table.clone(order)
end

function Decor.byCategory(category: string): { Item }
	local out: { Item } = {}
	for _, it in order do
		if it.category == category then
			table.insert(out, it)
		end
	end
	return out
end

-- True when the item may be placed in this context (nil contexts = everywhere).
function Decor.allowedIn(item: Item, context: string): boolean
	local list = item.contexts
	if list == nil then
		return Decor.CONTEXTS[context] ~= nil
	end
	return table.find(list, context) ~= nil
end

---------------------------------------------------------------------------------------------------
-- Room themes (ThemeWall / ThemeFloor parts in offices, apartments and dorm rooms)
---------------------------------------------------------------------------------------------------
Decor.THEME_PASS = "OfficeThemes"
Decor.DEFAULT_THEME = "classic"

local M = Enum.Material
Decor.themes = {
	{ id = "classic", name = "House Style", desc = "The building's own finish." },
	{
		id = "walnut",
		name = "Walnut Study",
		desc = "Warm walnut panels over navy carpet.",
		wall = { color = "#5A3A24", material = M.Wood },
		floor = { color = "#1D2A47", material = M.Carpet },
	},
	{
		id = "slate",
		name = "Slate Modern",
		desc = "Cool grey plaster and polished concrete.",
		wall = { color = "#6C7078", material = M.SmoothPlastic },
		floor = { color = "#8A8D91", material = M.Concrete },
	},
	{
		id = "ivory",
		name = "Ivory Loft",
		desc = "Bright white walls and pale oak.",
		wall = { color = "#EFEBE2", material = M.SmoothPlastic },
		floor = { color = "#C8A97E", material = M.WoodPlanks },
	},
	{
		id = "art_deco",
		name = "Art Deco",
		desc = "Black lacquer walls and a gold-veined marble floor.",
		pass = "OfficeThemes",
		wall = { color = "#16171A", material = M.Glass },
		floor = { color = "#E8DFC9", material = M.Marble },
	},
	{
		id = "penthouse",
		name = "Penthouse Marble",
		desc = "Marble from wall to floor.",
		pass = "OfficeThemes",
		wall = { color = "#F2EFEA", material = M.Marble },
		floor = { color = "#D9D4CA", material = M.Marble },
	},
	{
		id = "library",
		name = "Old Library",
		desc = "Mahogany and oxblood, like a founding partner's study.",
		pass = "OfficeThemes",
		wall = { color = "#4A2318", material = M.Wood },
		floor = { color = "#5C1F24", material = M.Carpet },
	},
	{
		id = "emerald",
		name = "Emerald Club",
		desc = "Deep green fabric walls over herringbone oak.",
		pass = "OfficeThemes",
		wall = { color = "#1F4D3A", material = M.Fabric },
		floor = { color = "#8B6A43", material = M.WoodPlanks },
	},
	{
		id = "midnight",
		name = "Midnight Trading",
		desc = "Dark slate and black granite, lit by screens.",
		pass = "OfficeThemes",
		wall = { color = "#0E1B2E", material = M.Slate },
		floor = { color = "#101215", material = M.Granite },
	},
	{
		id = "terrazzo",
		name = "Terrazzo Gallery",
		desc = "Gallery white with a speckled terrazzo floor.",
		pass = "OfficeThemes",
		wall = { color = "#F7F5F0", material = M.Plaster },
		floor = { color = "#CFC8BC", material = M.Pebble },
	},
} :: { Theme }

local themeById: { [string]: Theme } = {}
for _, th in Decor.themes do
	assert(themeById[th.id] == nil, "Decor: duplicate theme id " .. th.id)
	themeById[th.id] = th
end

function Decor.theme(id: any): Theme?
	if type(id) ~= "string" then
		return nil
	end
	return themeById[id]
end

return Decor
