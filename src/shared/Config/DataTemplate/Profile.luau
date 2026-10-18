--!strict
-- Player profile defaults (owned by `careerCore`; docs/contracts.md §3 and §4, design v3 §1-§3). Saved as data.profile
-- and replicated to its owner. ProfileService is the only writer.
--
--   built                   false until the Life Roll is locked in
--   firstName, familyName   filtered first name; family name from the family roll ("Maya" "Kennerly")
--   school, family          { id, rarity } (Config/LifeRoll ids; rarity = common .. mythic)
--   degree, gpa             "bs" | "ms", 2.70 .. 4.00
--   clubs                   { {id, rarity} } 1..3
--   stats                   the eight attributes 1..99 = baseStats + school/club/degree/family boosts + growth
--   baseStats               the rolled package (25..55 each)
--   growth                  { [statId] = points earned from performance } (AwardStatXp is the only growth path)
--   statXp                  { [statId] = xp toward the next point }
--   weekGrowth              { key, gains = { [statId] = points } } growth during the current week (key = week id)
--   ovr, archetype          rounded mean of the stats; archetype id from the top two stats
--   focus, focusKey         focus area id ("" = none) and the week it was last changed
--   perks                   { [perkId] = count } perks of this life (count = remaining uses)
--   perksUsed               { [perkId] = uses consumed this life } (a rebuild recomputes perks minus these)
--   outfitRoll              { lookId, brand, rarity, itemIds, name } the rolled starting outfit (WardrobeService)
--   rerollsLeft             free single-field rerolls left in the current Life Roll
--   refreshTokens           earned Profile Refresh tokens (one single-field reroll each)
--   credits                 { reroll, rebuild } bought credits (monetization: ProfileService:GrantCredit)
--   rebirths, incomeMult    rebirth count and income multiplier (M4; 0 and 1.0 until then)
--   legacySeat              true once any life owned the Legacy Seat (+1 reroll on every later Life Roll)
--   startCash, cashPaid     the family's starting cash and whether EconomyService has paid it (retried on load)
--   lockedAt                server time of the latest lock-in
--   pending                 the Life Roll in progress (Logic/LifeRoll Roll: school, degree, gpa, family, clubs,
--                           stats, outfit), {} when none

return {
	profile = {
		built = false,
		firstName = "",
		familyName = "",
		school = { id = "", rarity = "common" },
		degree = "bs",
		gpa = 0,
		family = { id = "", rarity = "common" },
		clubs = {},
		stats = {
			knowledge = 40,
			skill = 40,
			speed = 40,
			charisma = 40,
			network = 40,
			discipline = 40,
			risk = 40,
			luck = 40,
		},
		baseStats = {},
		growth = {},
		statXp = {},
		weekGrowth = { key = "", gains = {} },
		ovr = 40,
		archetype = "",
		focus = "",
		focusKey = "",
		perks = {},
		perksUsed = {},
		outfitRoll = { lookId = "", brand = "", rarity = "", itemIds = {}, name = "" },
		rerollsLeft = 3,
		refreshTokens = 0,
		credits = { reroll = 0, rebuild = 0 },
		rebirths = 0,
		incomeMult = 1,
		legacySeat = false,
		startCash = 0,
		cashPaid = true,
		lockedAt = 0,
		pending = {},
	},
}
