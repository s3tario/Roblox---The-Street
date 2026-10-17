--!strict
-- WardrobeService rules (PURE: no services, no clocks, no Instances; unit-tested in tests/wardrobe).
-- Every function works on the player's `inventory` table (Config/DataTemplate/Inventory) and a Catalog viewer
-- { owned, rank, passes } that the service builds from live state.
--
--   Inventory.normalize(inv) -> inv                    repairs a loaded table (types, unknown items, bad slots,
--                                                      renamed ids -> Catalog.canonical)
--   Inventory.viewer(inv, rank, passes) -> Viewer
--   Inventory.equip(inv, slot, itemId?, viewer) -> ok, errKey?
--   Inventory.wearable(inv, viewer) -> equipped, droppedSlots   what to put on the character right now
--   Inventory.grant(inv, itemId) -> isNew, errKey?
--   Inventory.grantStarters(inv, rank) -> newItemIds, newStages, equippedStarter
--   Inventory.wearLook(inv, itemIds, viewer) -> changedSlots      put a granted look on (Life Roll)
--   Inventory.profilePieces(profile) -> itemIds, lookId?   the Life Roll outfit + family heirloom a profile earned
--   Inventory.reconcile(inv, profile) -> newItemIds         grants those pieces if missing (never equips)
--   Inventory.savePreset(inv, index, name, viewer) -> ok, errKey?
--   Inventory.loadPreset(inv, index, viewer) -> ok, errKey?, droppedSlots?
--   Inventory.presetKey(index) -> "1".."5"
-- Error keys are Catalog.strings suffixes after "err_".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)

export type Preset = { name: string, equipped: { [string]: string } }
export type Inv = {
	owned: { [string]: boolean },
	equipped: { [string]: string },
	presets: { [string]: Preset },
	wearAvatar: boolean,
	stages: { [string]: boolean },
}
export type Viewer = Catalog.Viewer

local Inventory = {}

function Inventory.presetKey(index: number): string
	return tostring(math.floor(index))
end

local function cleanEquippedMap(raw: any): { [string]: string }
	local out: { [string]: string } = {}
	if type(raw) ~= "table" then
		return out
	end
	for slot, id in raw do
		local item = Catalog.get(Catalog.canonical(id))
		if type(slot) == "string" and Catalog.SLOT_SET[slot] and item and item.slot == slot and not item.hidden then
			out[slot] = item.id
		end
	end
	return out
end

-- Repairs whatever came out of the DataStore so later code can trust the shape. Unknown item ids (removed from
-- the catalog) are dropped; everything else is kept as is.
function Inventory.normalize(raw: any): Inv
	local inv: any = if type(raw) == "table" then raw else {}
	local owned: { [string]: boolean } = {}
	if type(inv.owned) == "table" then
		for id, v in inv.owned do
			local current = Catalog.canonical(id)
			if v and type(current) == "string" and Catalog.get(current) ~= nil then
				owned[current] = true
			end
		end
	end
	inv.owned = owned
	inv.equipped = cleanEquippedMap(inv.equipped)
	local presets: { [string]: Preset } = {}
	if type(inv.presets) == "table" then
		for key, p in inv.presets do
			local index = tonumber(key)
			if
				index
				and index == math.floor(index)
				and index >= 1
				and index <= Catalog.PRESET_SLOTS.max
				and type(p) == "table"
			then
				presets[Inventory.presetKey(index)] = {
					name = Catalog.presetName(p.name, index),
					equipped = cleanEquippedMap(p.equipped),
				}
			end
		end
	end
	inv.presets = presets
	inv.wearAvatar = inv.wearAvatar == true
	local stages: { [string]: boolean } = {}
	if type(inv.stages) == "table" then
		for id, v in inv.stages do
			if v and type(id) == "string" and Catalog.starter[id] ~= nil then
				stages[id] = true
			end
		end
	end
	inv.stages = stages
	return inv :: Inv
end

function Inventory.viewer(inv: Inv, rank: number?, passes: { [string]: boolean }?): Viewer
	return { owned = inv.owned, rank = rank or 0, passes = passes or {} }
end

function Inventory.equip(inv: Inv, slot: any, itemId: any, viewer: Viewer): (boolean, string?)
	local ok, err = Catalog.checkEquip(slot, itemId, viewer)
	if not ok then
		return false, err
	end
	if itemId == nil then
		inv.equipped[slot] = nil
	else
		inv.equipped[slot] = (Catalog.get(itemId) :: Catalog.Item).id
	end
	return true, nil
end

-- The look to put on the character: the saved equipped map minus anything the viewer can't wear right now
-- (a pass that lapsed, a rank lost after a firing). Does not modify the saved data, so the pieces come back
-- when the requirement is met again.
function Inventory.wearable(inv: Inv, viewer: Viewer): ({ [string]: string }, { string })
	return Catalog.sanitizeEquipped(inv.equipped, viewer)
end

function Inventory.grant(inv: Inv, itemId: any): (boolean, string?)
	local item = Catalog.get(Catalog.canonical(itemId))
	if not item or item.hidden then
		return false, "unknown_item"
	end
	if inv.owned[item.id] then
		return false, nil
	end
	inv.owned[item.id] = true
	return true, nil
end

-- Hands out every starter outfit for the stages this rank has reached (once per stage). When nothing is
-- equipped yet (a brand-new profile), the current stage's outfit goes on.
function Inventory.grantStarters(inv: Inv, rank: number?): ({ string }, { string }, boolean)
	local r = if type(rank) == "number" and rank == rank then rank else 0
	local newItems: { string } = {}
	local newStages: { string } = {}
	for _, stage in Catalog.STAGES do
		if r >= stage.rank and not inv.stages[stage.id] then
			inv.stages[stage.id] = true
			table.insert(newStages, stage.id)
			local outfit = Catalog.starter[stage.id]
			local ids = {}
			for _, id in outfit do
				table.insert(ids, id)
			end
			table.sort(ids)
			for _, id in ids do
				if not inv.owned[id] then
					inv.owned[id] = true
					table.insert(newItems, id)
				end
			end
		end
	end
	local equippedStarter = false
	if next(inv.equipped) == nil then
		for slot, id in Catalog.starterFor(r) do
			inv.equipped[slot] = id
		end
		equippedStarter = true
	end
	return newItems, newStages, equippedStarter
end

-- Puts a granted look on: each piece replaces its slot; an outer layer the look doesn't include comes off so the
-- new outfit shows. Pieces the viewer can't wear are skipped. Returns the slots that changed.
function Inventory.wearLook(inv: Inv, itemIds: { string }, viewer: Viewer): { string }
	local changed: { string } = {}
	local covered: { [string]: boolean } = {}
	for _, id in itemIds do
		local item = Catalog.get(Catalog.canonical(id))
		if item and Catalog.canWear(item, viewer) then
			covered[item.slot] = true
			if inv.equipped[item.slot] ~= item.id then
				inv.equipped[item.slot] = item.id
				table.insert(changed, item.slot)
			end
		end
	end
	if next(covered) ~= nil and not covered.outer and inv.equipped.outer ~= nil then
		(inv.equipped :: any).outer = nil
		table.insert(changed, "outer")
	end
	table.sort(changed)
	return changed
end

-- The exclusive pieces a careerCore profile (contracts §3 `profile`) has earned: its starting-outfit roll
-- (profile.outfitRoll.itemIds, or the look named by outfitRoll.lookId / .look) and the family heirloom for
-- profile.family.rarity. Only Life Roll and heirloom catalog pieces count, so a profile can never hand out shop
-- items. Returns canonical ids (sorted, unique) and the look id when one matched.
function Inventory.profilePieces(profile: any): ({ string }, string?)
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	local lookId: string? = nil
	local function add(id: any)
		local item = Catalog.get(Catalog.canonical(id))
		if item and Catalog.isExclusive(item) and not seen[item.id] then
			seen[item.id] = true
			table.insert(out, item.id)
		end
	end
	if type(profile) ~= "table" then
		return out, nil
	end
	local roll = profile.outfitRoll
	if type(roll) == "table" then
		local named = Catalog.canonical(roll.lookId or roll.look)
		local look = if type(named) == "string" then Catalog.looks[named] else nil
		if look then
			lookId = look.id
			for _, id in look.itemIds do
				add(id)
			end
		end
		if type(roll.itemIds) == "table" then
			for _, id in roll.itemIds do
				add(id)
			end
			if not lookId then
				local first = if type(roll.itemIds[1]) == "string"
					then Catalog.lookOf(Catalog.canonical(roll.itemIds[1]))
					else nil
				lookId = if first then first.id else nil
			end
		end
	end
	local family = profile.family
	if type(family) == "table" then
		add(Catalog.heirloomFor(family.rarity))
	end
	table.sort(out)
	return out, lookId
end

function Inventory.reconcile(inv: Inv, profile: any): { string }
	local granted: { string } = {}
	for _, id in (Inventory.profilePieces(profile)) do
		if Inventory.grant(inv, id) then
			table.insert(granted, id)
		end
	end
	return granted
end

local function presetIndex(index: any, viewer: Viewer): (number?, string?)
	if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > Catalog.PRESET_SLOTS.max then
		return nil, "locked"
	end
	if index > Catalog.presetSlotsFor(viewer) then
		return nil, "locked"
	end
	return index, nil
end

function Inventory.savePreset(inv: Inv, index: any, name: any, viewer: Viewer): (boolean, string?)
	local i, err = presetIndex(index, viewer)
	if not i then
		return false, err
	end
	if name ~= nil and type(name) ~= "string" then
		return false, "bad_name"
	end
	inv.presets[Inventory.presetKey(i)] = {
		name = Catalog.presetName(name, i),
		equipped = table.clone(inv.equipped),
	}
	return true, nil
end

-- Loading replaces the whole look with the preset, minus pieces the viewer can no longer wear.
function Inventory.loadPreset(inv: Inv, index: any, viewer: Viewer): (boolean, string?, { string }?)
	local i, err = presetIndex(index, viewer)
	if not i then
		return false, err, nil
	end
	local preset = inv.presets[Inventory.presetKey(i)]
	if not preset then
		return false, "empty", nil
	end
	local cleaned, dropped = Catalog.sanitizeEquipped(preset.equipped, viewer)
	inv.equipped = cleaned
	return true, nil, dropped
end

return Inventory
