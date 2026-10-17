--!strict
-- Wearables catalog (owned by `wardrobe`, docs/contracts.md §9). Every item is built in-house as fitted
-- 3D layers (Shared/Assets/Wardrobe) and, optionally, a generated 2D Shirt/Pants template
-- (tools/clothing). Pure data plus pure helpers: safe on server, client and in Lune.
-- Item definitions live in Casual.luau, Essentials.luau, Formal.luau, Luxury.luau, Premium.luau and Rolls/ (Life
-- Roll looks per tier and family heirlooms); brands and rarity tiers in Brands.luau; NPC outfits in Presets.luau;
-- UI text in Strings.luau.
--
--   Catalog.items[itemId] = { id, name, slot, category, price, currency = "cash" | "pass" | "roll" | "heirloom",
--                             pass?, minRank?, colors = { primary, secondary?, accent?, trim? } ("#RRGGBB"),
--                             builder, tier (= clothing level 1-5, v3 §5), brand, rarity, desc, tags, style?,
--                             pattern?, finish?,
--                             details?, text?, hidden? }
--       currency "roll"      Life Roll pieces (granted by career through WardrobeService:Grant, never sold)
--       currency "heirloom"  family heirlooms (granted by the family roll, never sold)
--       finish               "suede" | "patent" | "velvet" (surface of the main fabric/leather)
--       details              signature details drawn on top of the garment (Assets/Wardrobe/Details.luau)
--   Catalog.brands[brandId] = { id, name, rarity, blurb, roll, signature, logo }   Catalog.brand(id) -> Brand?
--   Catalog.RARITIES / Catalog.RARITY[rarity] = { id, order, name, color, color2? }
--       common uncommon rare epic legendary mythic (v3 §1)
--   Catalog.rollPools[rarity] = { { id, brand, name, rarity, itemIds = { ... } }, ... }   (mythic has exactly one)
--   Catalog.pickLook(rarity, u) -> look?   u in [0, 1) picks an entry (Logic/LifeRoll supplies u)
--   Catalog.heirloomFor(familyRarity) -> itemId?   the family heirloom at Rare and above
--   Catalog.levelOf(itemOrId) -> 1..5      Catalog.outfitLevel(equipped) -> 1..5, parts   (v3 §5 Outfit Level)
--   Catalog.logoEligible(item) -> boolean  vests and quarter-zips carry the company logo (v3 §16)
--   Catalog.canonical(id) -> id            renamed ids (Catalog.ALIASES, e.g. the v2 Kingsley pieces) -> current
--   Catalog.get(id) -> Item?               Catalog.bySlot(slot, includeHidden?) -> { Item } (tier, price order)
--   Catalog.list(includeHidden?) -> { Item }   Catalog.shopItems() -> { Item }   Catalog.isShopItem(item)
--   Catalog.visibleFor(slot, viewer) -> { Item }   what the wardrobe lists: shop items + owned exclusives
--   Catalog.starter[stage] = { [slot] = itemId }  free default outfit per career stage (student, analyst, associate)
--   Catalog.starterFor(rank) -> outfit       Catalog.starterItems(rank) -> { itemId }  (every stage <= rank)
--   Catalog.presets[npcRole] = { equipped, hairStyle, hairColor, skin, pose? }   NPC outfits
--   Catalog.access(item, viewer) -> state   "free" | "owned" | "buy" | "rank" | "pass" (see below)
--   Catalog.canWear(item, viewer) -> ok, err      Catalog.checkEquip(slot, itemId?, viewer) -> ok, err
--   Catalog.sanitizeEquipped(equipped, viewer) -> cleaned, droppedSlots
--   Catalog.presetName(raw, index) -> string      Catalog.presetSlotsFor(viewer) -> number
--   Catalog.strings / Catalog.text(key, vars?)    player-facing wardrobe UI text
--   viewer = { owned = {[itemId] = true}, rank = number, passes = {[passKey] = true} }
--
-- Prices follow the spec §11 anchors (PRICE_RANGES), with v3 §5 levels: level 3 suits about $1-2k, level 4 about
-- $3-6k, level 5 about $8-25k. Every slot sells cash items at every level 1-5. Premium items (currency "pass") come
-- with a game pass and cost 0 cash. minRank gates prestige pieces by career rank (v3: 0 student, 1 entry, 2
-- Associate, 3 VP, 4 Director, 5 MD on the IB ladder); a dress level the next promotion needs is never gated
-- above the rank it is bought at.

local Types = require(script.Types)
export type Slot = Types.Slot
export type Colors = Types.Colors
export type Currency = Types.Currency
export type Item = Types.Item
export type Look = Types.Look
export type Viewer = Types.Viewer
export type Preset = Types.Preset

local Brands = require(script.Brands)

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

Catalog.CATEGORIES = {
	"campus",
	"business",
	"womens",
	"suits",
	"shoes",
	"accessories",
	"watches",
	"luxury",
	"premium",
	"roll",
	"heirloom",
	"npc",
}
Catalog.PASSES = { CornerOffice = true, ExecutiveClub = true } :: { [string]: boolean }
Catalog.CURRENCIES = { cash = true, pass = true, roll = true, heirloom = true } :: { [string]: boolean }
-- Exclusive currencies: owned only through a grant (never bought).
Catalog.EXCLUSIVE = { roll = true, heirloom = true } :: { [string]: boolean }
Catalog.FINISHES = { suede = true, patent = true, velvet = true } :: { [string]: boolean }

-- Brands and rarity tiers (Catalog/Brands.luau).
Catalog.brands = Brands.brands
Catalog.brandList = Brands.list
Catalog.RARITIES = Brands.RARITIES
Catalog.RARITY = Brands.RARITY
Catalog.TIER_RARITY = Brands.TIER_RARITY

function Catalog.brand(id: any): Brands.Brand?
	if type(id) ~= "string" then
		return nil
	end
	return Brands.brands[id]
end

function Catalog.rarityOrder(rarity: any): number
	local def = if type(rarity) == "string" then Brands.RARITY[rarity] else nil
	return if def then def.order else 0
end

-- Spec §11 price anchors per category (cash items with a price above 0).
Catalog.PRICE_RANGES = {
	campus = { 40, 250 },
	business = { 150, 600 },
	womens = { 150, 600 },
	suits = { 900, 25000 },
	luxury = { 300, 25000 },
	shoes = { 120, 2500 },
	accessories = { 40, 3000 },
	watches = { 300, 80000 },
} :: { [string]: { number } }
Catalog.SHOE_RANGE = { 120, 2500 }

-- Preset slots: the first FREE are open to everyone, the rest need the Executive Club pass.
Catalog.PRESET_SLOTS = { free = 2, max = 5, pass = "ExecutiveClub", nameMax = 24 }

---------------------------------------------------------------------------------------------------
-- Items and Life Roll pools (Catalog/Items.luau)
---------------------------------------------------------------------------------------------------
local Items = require(script.Items)
local items = Items.items
local order = Items.order
local rollPools = Items.rollPools
Catalog.items = items
Catalog.order = order
Catalog.rollPools = rollPools
Catalog.looks = Items.looks

-- The pool entry for a uniform number u in [0, 1) (nil for an unknown rarity).
function Catalog.pickLook(rarity: any, u: number): Look?
	local pool = if type(rarity) == "string" then rollPools[rarity] else nil
	if not pool or #pool == 0 then
		return nil
	end
	local x = if type(u) == "number" and u == u then u else 0
	local i = math.clamp(math.floor(x * #pool) + 1, 1, #pool)
	return pool[i]
end

-- The look (if any) whose pieces include itemId.
function Catalog.lookOf(itemId: string): Look?
	for _, r in Brands.RARITIES do
		for _, entry in rollPools[r] do
			if table.find(entry.itemIds, itemId) then
				return entry
			end
		end
	end
	return nil
end

-- Family heirlooms by family rarity (Rare and above; Catalog/Rolls/Heirlooms.luau).
Catalog.HEIRLOOMS = Items.heirlooms

function Catalog.heirloomFor(rarity: any): string?
	if type(rarity) ~= "string" then
		return nil
	end
	return Catalog.HEIRLOOMS[rarity]
end

function Catalog.heirlooms(): { Item }
	local out: { Item } = {}
	for _, id in order do
		if items[id].currency == "heirloom" then
			table.insert(out, items[id])
		end
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Starter outfits (free, granted when a player reaches the stage)
---------------------------------------------------------------------------------------------------
-- v3 ranks: 0 student, 1 the entry title (Analyst on most ladders), 2 Associate.
Catalog.STAGES = {
	{ id = "student", rank = 0 },
	{ id = "analyst", rank = 1 },
	{ id = "associate", rank = 2 },
}
Catalog.starter = {
	student = {
		top = "hoodie_heather",
		bottom = "jeans_indigo",
		shoes = "sneaker_white",
		neck = "lanyard_student",
		bag = "backpack_canvas",
	},
	analyst = { top = "oxford_blue", bottom = "chinos_khaki", shoes = "loafer_cognac", neck = "lanyard_staff" },
	associate = { top = "oxford_white", bottom = "trousers_flannel", shoes = "oxford_black", neck = "tie_navy" },
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

-- What the wardrobe lists for a slot: every shop item, plus the exclusive pieces (Life Roll, heirlooms) the
-- viewer owns, which come first (rarest first).
function Catalog.visibleFor(slot: string, viewer: Viewer): { Item }
	local owned = viewer.owned or {}
	local exclusive: { Item } = {}
	local shop: { Item } = {}
	for _, id in order do
		local it = items[id]
		if it.slot == slot and not it.hidden then
			if Catalog.EXCLUSIVE[it.currency] then
				if owned[it.id] then
					table.insert(exclusive, it)
				end
			else
				table.insert(shop, it)
			end
		end
	end
	table.sort(exclusive, function(a, b)
		local ra, rb = Catalog.rarityOrder(a.rarity), Catalog.rarityOrder(b.rarity)
		if ra ~= rb then
			return ra > rb
		end
		return a.id < b.id
	end)
	sortItems(shop)
	for _, it in shop do
		table.insert(exclusive, it)
	end
	return exclusive
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

-- Sold or unlocked in the shops (cash or game pass, not an NPC piece).
function Catalog.isShopItem(item: Item): boolean
	return not item.hidden and (item.currency == "cash" or item.currency == "pass")
end

-- Only obtainable through a grant (Life Roll pieces and family heirlooms).
function Catalog.isExclusive(item: Item): boolean
	return Catalog.EXCLUSIVE[item.currency] == true
end

function Catalog.shopItems(): { Item }
	local out: { Item } = {}
	for _, id in order do
		if Catalog.isShopItem(items[id]) then
			table.insert(out, items[id])
		end
	end
	return out
end

-- What a viewer can do with an item (pure; used by WardrobeService and the Wardrobe screen):
--   "owned"  in inventory.owned (or a starter piece for their stage)
--   "free"   costs nothing (and has no requirement)
--   "pass"   needs a game pass the viewer lacks
--   "rank"   needs a higher career rank
--   "buy"    can be bought with cash
--   "roll" / "heirloom"   exclusive pieces the viewer hasn't been granted
function Catalog.access(item: Item, viewer: Viewer): string
	local owned = viewer.owned or {}
	local rank = rankNumber(viewer.rank)
	if Catalog.EXCLUSIVE[item.currency] then
		return if owned[item.id] then "owned" else item.currency
	end
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
	if state == "roll" or state == "heirloom" then
		return false, state
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

-- Rank titles for "requires" labels: the IB ladder (v3 §4). Career owns the real per-track titles (Config/Tracks);
-- the wardrobe screen prefers those when they exist.
Catalog.RANK_TITLES = {
	[0] = "Student",
	[1] = "Analyst",
	[2] = "Associate",
	[3] = "Vice President",
	[4] = "Director",
	[5] = "Managing Director",
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
-- Clothing level, Outfit Level, company-logo pieces and renamed ids (Catalog/Levels.luau)
---------------------------------------------------------------------------------------------------
local Levels = require(script.Levels)
export type OutfitParts = Levels.OutfitParts
Catalog.LEVELS = Levels.LEVELS
Catalog.CORE_SLOTS = Levels.CORE_SLOTS
Catalog.ALIASES = Levels.ALIASES
Catalog.levelOf = Levels.levelOf
Catalog.outfitLevel = Levels.outfitLevel
Catalog.logoEligible = Levels.logoEligible
Catalog.canonical = Levels.canonical

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
