--!strict
-- Catalog: Life Roll starting outfits (owner v2, spec §4; v3 §1-2) and family heirlooms. Definitions live in one
-- module per tier group; this module fills in the shared roll fields and hands Catalog/init.luau plain lists.
--   items     roll pieces (currency "roll", category "roll", price 0, never sold) and heirlooms (currency
--             "heirloom"); a roll piece's rarity is its brand's rarity and its clothing level (tier) comes from
--             Brands.LEVEL_OF_RARITY unless the piece sets one
--   looks     the starting-outfit pools: { id, brand, name, itemIds } with top + bottom + shoes (optionally outer,
--             neck, wrist). Pool sizes (v3 §1): 12 common, 8 uncommon, 6 rare, 4 epic, 3 legendary, exactly
--             1 mythic (the Pan Miller Signature).
--   heirlooms { [familyRarity] = itemId } (Rare and above)

local Brands = require(script.Parent.Brands)

local items: { { [string]: any } } = {}
local looks: { { id: string, brand: string, name: string, itemIds: { string } } } = {}

for _, group in
	{
		require(script.Common),
		require(script.Uncommon),
		require(script.Rare),
		require(script.Epic),
		require(script.Luxury),
	} :: { any }
do
	for _, d in group.items do
		d.tier = d.tier or Brands.LEVEL_OF_RARITY[d.rarity] or 1
		d.currency = "roll"
		d.category = "roll"
		d.price = 0
		d.tags = d.tags or { "roll", d.rarity }
		table.insert(items, d)
	end
	for _, l in group.looks do
		table.insert(looks, l)
	end
end

local Heirlooms = require(script.Heirlooms) :: any
for _, d in Heirlooms.items do
	d.brand = "family_heirloom"
	d.currency = "heirloom"
	d.category = "heirloom"
	d.price = 0
	d.tags = { "heirloom", d.rarity }
	table.insert(items, d)
end

return { items = items, looks = looks, heirlooms = Heirlooms.byRarity :: { [string]: string } }
