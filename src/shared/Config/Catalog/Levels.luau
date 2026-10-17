--!strict
-- Catalog: clothing levels (v3 §5), the company-logo rule (v3 §16) and renamed ids. Pure; re-exported by
-- Catalog/init.luau (Catalog.levelOf, Catalog.outfitLevel, Catalog.logoEligible, Catalog.canonical).

local Items = require(script.Parent.Items)
local Types = require(script.Parent.Types)

local Levels = {}

-- Slots that are never left empty: the plain base pieces count as level 1 (mirrors Catalog.REQUIRED).
local REQUIRED = { top = true, bottom = true, shoes = true } :: { [string]: boolean }

local function get(id: any): Types.Item?
	if type(id) ~= "string" then
		return nil
	end
	return Items.items[id]
end

---------------------------------------------------------------------------------------------------
-- Clothing level and Outfit Level (v3 §5)
---------------------------------------------------------------------------------------------------
Levels.LEVELS = 5
-- The core slots that set the Outfit Level: the torso (the better of top and outer), bottom and shoes.
Levels.CORE_SLOTS = { "top", "outer", "bottom", "shoes" } :: { Types.Slot }

-- An item's clothing level (its tier), 0 for unknown ids.
function Levels.levelOf(itemOrId: any): number
	local item = if type(itemOrId) == "table" then itemOrId else get(itemOrId)
	if type(item) ~= "table" or type(item.tier) ~= "number" then
		return 0
	end
	return math.clamp(math.floor(item.tier), 1, Levels.LEVELS)
end

export type OutfitParts = { torso: number, bottom: number, shoes: number, level: number, lowest: string }

-- Outfit Level = the lowest level among the core slots (v3 §5). The torso counts the better of the top and the
-- outer layer (a suit jacket over a tee is dressed for work); empty required slots wear the plain base pieces
-- (level 1). Unknown or wrong-slot ids count as empty. Returns the level and the per-part breakdown (lowest is
-- the part holding the level down: "torso" | "bottom" | "shoes").
function Levels.outfitLevel(equipped: any): (number, OutfitParts)
	local eq = if type(equipped) == "table" then equipped else {}
	local function slotLevel(slot: string): number
		local item = get(eq[slot])
		if item and item.slot == slot and not item.hidden then
			return Levels.levelOf(item)
		end
		return if REQUIRED[slot] then 1 else 0
	end
	local torso = math.max(slotLevel("top"), slotLevel("outer"), 1)
	local bottom = math.max(slotLevel("bottom"), 1)
	local shoes = math.max(slotLevel("shoes"), 1)
	local level = math.min(torso, bottom, shoes)
	local lowest = if torso == level then "torso" elseif bottom == level then "bottom" else "shoes"
	return level, { torso = torso, bottom = bottom, shoes = shoes, level = level, lowest = lowest }
end

---------------------------------------------------------------------------------------------------
-- Company logo on clothing (v3 §16): only vests and quarter-zips, never suits, shirts, blouses or hoodies
---------------------------------------------------------------------------------------------------
function Levels.logoEligible(item: any): boolean
	if type(item) ~= "table" or item.hidden then
		return false
	end
	if item.builder == "quarterzip" then
		return item.slot == "top"
	end
	-- fleece vests and gilets; a tailored waistcoat is part of a suit
	return item.builder == "vest" and item.slot == "outer" and item.style ~= "waistcoat"
end

---------------------------------------------------------------------------------------------------
-- Renamed ids (saved inventories and other features may still hold the old ones)
---------------------------------------------------------------------------------------------------
Levels.ALIASES = {
	wk_jacket = "pm_jacket",
	wk_shirt = "pm_shirt",
	wk_trousers = "pm_trousers",
	wk_tie = "pm_tie",
	wk_oxford = "pm_oxford",
	wk_watch = "pm_watch",
	wk_signature = "pm_signature",
	lanyard_intern = "lanyard_staff",
} :: { [string]: string }

function Levels.canonical(id: any): any
	if type(id) == "string" then
		return Levels.ALIASES[id] or id
	end
	return id
end

return Levels
