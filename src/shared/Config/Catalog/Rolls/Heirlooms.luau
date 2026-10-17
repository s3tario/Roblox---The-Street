--!strict
-- Catalog/Rolls: family heirlooms (granted by the Life Roll family result at Rare and above; never sold).
-- Rolls/init.luau marks them currency "heirloom", brand "family_heirloom", price 0.
--   byRarity[familyRarity] = itemId   the heirloom a family of that rarity hands down (Catalog.heirloomFor)

local function c(primary: string, secondary: string?, accent: string?, trim: string?): { [string]: string? }
	return { primary = primary, secondary = secondary, accent = accent, trim = trim }
end

local items: { { [string]: any } } = {
	{
		id = "heirloom_signet_ring",
		name = "Family Signet Ring",
		slot = "wrist",
		builder = "ring",
		rarity = "rare",
		tier = 3,
		colors = c("#D4AF37", "#B8933F", "#6E5320"),
		desc = "A worn gold signet with the family crest. Rare families only.",
	},
	{
		id = "heirloom_family_scarf",
		name = "Family Crest Cashmere Scarf",
		slot = "neck",
		builder = "scarf",
		pattern = "stripe",
		rarity = "epic",
		tier = 4,
		colors = c("#2B3A5C", "#22304D", "#B8933F"),
		desc = "Navy cashmere woven with the family colours in old gold. Epic families only.",
	},
	{
		id = "heirloom_family_watch",
		name = "Vintage Family Watch",
		slot = "wrist",
		builder = "watch",
		style = "gold",
		rarity = "legendary",
		tier = 5,
		colors = c("#C9A54C", "#4A2E1C", "#F1E7CF"),
		desc = "Grandfather's gold dress watch on a fresh brown strap.",
	},
	{
		id = "heirloom_vanderfeller_crest_blazer",
		name = "The Vanderfeller Crest Blazer",
		slot = "outer",
		builder = "blazer",
		style = "heirloom",
		rarity = "mythic",
		tier = 5,
		colors = c("#13213B", "#0E1A30", "#D4AF37", "#7A1428"),
		desc = "Midnight navy with gold crest buttons, gold piping and the Vanderfeller crest.",
	},
}

local byRarity: { [string]: string } = {
	rare = "heirloom_signet_ring",
	epic = "heirloom_family_scarf",
	legendary = "heirloom_family_watch",
	mythic = "heirloom_vanderfeller_crest_blazer",
}

return { items = items, byRarity = byRarity }
