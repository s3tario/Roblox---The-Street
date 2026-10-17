--!strict
-- Catalog: builds the item table from the item lists (Casual, Essentials, Formal, Luxury, Premium, Rolls) and the
-- Life Roll pools from Rolls/. Fills defaults: house brand, currency, rarity from the tier (house labels) or the
-- brand (Life Roll brands). Catalog/init.luau re-exports everything; require Catalog, not this module.

local Brands = require(script.Parent.Brands)
local Types = require(script.Parent.Types)

type Item = Types.Item
type Look = Types.Look

---------------------------------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------------------------------
local items: { [string]: Item } = {}
local order: { string } = {}

-- House label for shop items that don't name a brand.
local function defaultBrand(def: { [string]: any }): string
	if def.pass == "CornerOffice" then
		return "corner_office"
	elseif def.pass == "ExecutiveClub" then
		return "executive_club"
	elseif def.category == "npc" then
		return "staff"
	elseif def.builder == "lanyard" then
		return "standard_issue"
	elseif def.slot == "shoes" then
		return "strider"
	elseif def.category == "watches" then
		return "vanta"
	elseif def.category == "campus" then
		return "eastbridge"
	end
	return "hartwell"
end

local function add(def: { [string]: any })
	local id = def.id :: string
	assert(items[id] == nil, "Catalog: duplicate item " .. id)
	local brandId = def.brand or defaultBrand(def)
	local brand = Brands.brands[brandId]
	assert(brand ~= nil, ("Catalog: %s has unknown brand %s"):format(id, tostring(brandId)))
	local tier = def.tier or 1
	local rarity = def.rarity
		or (if brand.roll then brand.rarity else nil)
		or Brands.TIER_RARITY[math.clamp(tier, 1, 5)]
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
		tier = tier,
		brand = brandId,
		rarity = rarity,
		desc = def.desc or "",
		tags = def.tags or {},
		style = def.style,
		pattern = def.pattern,
		finish = def.finish,
		details = def.details,
		text = def.text,
		hidden = def.hidden,
	}
	items[id] = item
	table.insert(order, id)
end

-- Item lists live in sibling modules so each file stays focused (and under ~600 lines).
local Rolls = require(script.Parent.Rolls) :: any
for _, list in
	{
		require(script.Parent.Casual),
		require(script.Parent.Essentials),
		require(script.Parent.Formal),
		require(script.Parent.Luxury),
		require(script.Parent.Premium),
		Rolls.items,
	} :: { { { [string]: any } } }
do
	for _, def in list do
		add(def)
	end
end

---------------------------------------------------------------------------------------------------
-- Life Roll starting-outfit pools (Catalog/Rolls.luau)
---------------------------------------------------------------------------------------------------
local rollPools: { [string]: { Look } } = {}
local looks: { [string]: Look } = {}
for _, r in Brands.RARITIES do
	rollPools[r] = {}
end
for _, def in Rolls.looks do
	local brand = Brands.brands[def.brand]
	assert(brand ~= nil and brand.roll, "Catalog: look " .. def.id .. " has a non-roll brand")
	assert(looks[def.id] == nil, "Catalog: duplicate look " .. def.id)
	local entry: Look = {
		id = def.id,
		brand = def.brand,
		name = def.name,
		rarity = brand.rarity,
		itemIds = table.clone(def.itemIds),
	}
	looks[def.id] = entry
	table.insert(rollPools[brand.rarity], entry)
end

return {
	items = items,
	order = order,
	rollPools = rollPools,
	looks = looks,
	heirlooms = Rolls.heirlooms :: { [string]: string },
}
