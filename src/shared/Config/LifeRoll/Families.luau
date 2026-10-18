--!strict
-- Config/LifeRoll: families (design v2 §4 dynasty parodies, v3 §1-§2). Pure data. All names are fictional parodies.
-- A family is lifestyle and connections, never performance: it never touches grades, market returns or reviews.
--
--   { id, name, rarity, cash, network, offerBonus, heirloom?, blurb }
--     cash        starting cash paid once at lock-in (EconomyService:AddCash "reward")
--     network     + this many Network points (connections)
--     offerBonus  job-offer odds edge (the same numbers as careerPath's Recruiting.FAMILY_BONUS)
--     heirloom    Config/Catalog item id handed down at Rare and above (granted at lock-in)

export type FamilyDef = {
	id: string,
	name: string,
	rarity: string,
	cash: number,
	network: number,
	offerBonus: number,
	heirloom: string?,
	blurb: string,
}

-- Per-tier economics (every family of a tier shares them).
local TIERS: { [string]: { cash: number, network: number, offerBonus: number, heirloom: string? } } = {
	common = { cash = 500, network = 0, offerBonus = 0 },
	uncommon = { cash = 2000, network = 2, offerBonus = 0.03 },
	rare = { cash = 6000, network = 3, offerBonus = 0.06, heirloom = "heirloom_signet_ring" },
	epic = { cash = 10000, network = 4, offerBonus = 0.08, heirloom = "heirloom_family_scarf" },
	legendary = { cash = 15000, network = 5, offerBonus = 0.10, heirloom = "heirloom_family_watch" },
	mythic = { cash = 40000, network = 7, offerBonus = 0.15, heirloom = "heirloom_vanderfeller_crest_blazer" },
}

local COMMON_BLURB = "A hard-working family that taught you the value of a dollar."

local list: { FamilyDef } = {}

local function f(name: string, rarity: string, blurb: string?)
	local tier = TIERS[rarity]
	table.insert(list, {
		id = string.lower((string.gsub(name, "[^%a]", ""))),
		name = name,
		rarity = rarity,
		cash = tier.cash,
		network = tier.network,
		offerBonus = tier.offerBonus,
		heirloom = tier.heirloom,
		blurb = blurb or COMMON_BLURB,
	})
end

-- Common
for _, name in { "Williams", "Johnson", "Smith", "Garcia", "Nguyen", "Brown" } do
	f(name, "common")
end
for _, name in { "Miller", "Davis", "Martinez", "Lee", "Patel", "Okafor" } do
	f(name, "common")
end

-- Uncommon
f("Carnaby", "uncommon", "Railroad money, three generations back. The summer house still has a name.")
f("Hiltop", "uncommon", "Hotels on every hilltop and a ballroom in every hotel.")
f("Hurst", "uncommon", "Newspapers first, then everything the newspapers wrote about.")
f("Gettis", "uncommon", "Oil wells out west and a marble museum on the hill.")

-- Rare
f("Vandermont", "rare", "Ferries, railroads and a mansion on Fifth with too many staircases.")
f("DuMont", "rare", "Chemicals, a château and a very old signet ring.")
f("Mellonby", "rare", "Bankers and bridge builders. Grandfather had a portrait in the lobby.")

-- Epic
f("Carrington", "epic", "A tobacco fortune turned into libraries, scholarships and one famous ballroom.")
f("Whitfield", "epic", "Steel mills, concert halls and a scarf for every winter gala.")

-- Legendary
f("Kennerly", "legendary", "A political dynasty with a compound by the sea and a sailboat for every cousin.")
f("Rockwell", "legendary", "Oil, refineries and the tallest skating rink downtown.")
f("Morganthal", "legendary", "The banker who once bailed out the banks. The vault still has the family name.")

-- Mythic
f("Vanderfeller", "mythic", "The richest name on the Street. Their crest is carved over half the doorways in town.")

return { list = list, tiers = TIERS }
