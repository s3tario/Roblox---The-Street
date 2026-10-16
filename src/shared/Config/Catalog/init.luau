--!strict
-- Wearables catalog (owned by `wardrobe`, docs/contracts.md §9). Every item is built in-house as fitted
-- 3D layers (Shared/Assets/Wardrobe) and, optionally, a generated 2D Shirt/Pants template
-- (tools/clothing). Pure data plus pure helpers: safe on server, client and in Lune.
-- Item definitions live in Casual.luau, Formal.luau and Premium.luau; NPC outfits in Presets.luau; UI text
-- in Strings.luau.
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
--   Catalog.canWear(item, viewer) -> ok, err      Catalog.checkEquip(slot, itemId?, viewer) -> ok, err
--   Catalog.sanitizeEquipped(equipped, viewer) -> cleaned, droppedSlots
--   Catalog.presetName(raw, index) -> string      Catalog.presetSlotsFor(viewer) -> number
--   Catalog.strings / Catalog.text(key, vars?)    player-facing wardrobe UI text
--   viewer = { owned = {[itemId] = true}, rank = number, passes = {[passKey] = true} }
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

-- Item lists live in sibling modules so each file stays focused (and under ~600 lines).
for _, list in { require(script.Casual), require(script.Formal), require(script.Premium) } do
	for _, def in list do
		add(def)
	end
end

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
-- NPC outfit presets (Catalog/Presets.luau)
---------------------------------------------------------------------------------------------------
Catalog.presets = (require(script.Presets) :: any) :: { [string]: Preset }

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

-- Keeps only the equipped entries this viewer may wear: known, visible items in the right slot that pass
-- Catalog.canWear. Returns the cleaned map and the list of slots that were dropped (pure).
function Catalog.sanitizeEquipped(equipped: any, viewer: Viewer): ({ [string]: string }, { string })
	local out: { [string]: string } = {}
	local dropped: { string } = {}
	if type(equipped) ~= "table" then
		return out, dropped
	end
	for slot, id in equipped do
		local item = Catalog.get(id)
		if type(slot) ~= "string" or not Catalog.SLOT_SET[slot] or item == nil or item.slot ~= slot then
			table.insert(dropped, tostring(slot))
			continue
		end
		if Catalog.canWear(item, viewer) then
			out[slot] = item.id
		else
			table.insert(dropped, slot)
		end
	end
	table.sort(dropped)
	return out, dropped
end

-- Validates a full equip request (pure). Returns ok, errKey (a Catalog.strings key suffix after "err_").
--   itemId nil = unequip (always allowed for any known slot).
function Catalog.checkEquip(slot: any, itemId: any, viewer: Viewer): (boolean, string?)
	if type(slot) ~= "string" or not Catalog.SLOT_SET[slot] then
		return false, "bad_slot"
	end
	if itemId == nil then
		return true, nil
	end
	local item = Catalog.get(itemId)
	if item == nil or item.hidden then
		return false, "unknown_item"
	end
	if item.slot ~= slot then
		return false, "bad_slot"
	end
	return Catalog.canWear(item, viewer)
end

-- Cleans a player-typed preset name: collapses whitespace, strips control characters, caps the length.
-- Empty results fall back to "Outfit <index>".
function Catalog.presetName(raw: any, index: number): string
	local fallback = Catalog.text("preset_name", { index = index })
	if type(raw) ~= "string" then
		return fallback
	end
	local s = string.gsub(raw, "%c", " ")
	s = string.gsub(s, "%s+", " ")
	s = string.match(s, "^%s*(.-)%s*$") or ""
	if utf8.len(s) == nil then
		return fallback
	end
	local maxLen = Catalog.PRESET_SLOTS.nameMax
	if (utf8.len(s) :: number) > maxLen then
		local cut = utf8.offset(s, maxLen + 1)
		s = if cut then string.sub(s, 1, cut - 1) else s
	end
	if s == "" then
		return fallback
	end
	return s
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
-- Player-facing text (Catalog/Strings.luau)
---------------------------------------------------------------------------------------------------
Catalog.strings = require(script.Strings) :: { [string]: string }

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
