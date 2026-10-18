--!strict
-- Config/LifeRoll: campus clubs (design v2 §4 "Clubs", v3 §1-§2). Pure data.
-- A Life Roll rolls 1-3 clubs; each club roll picks a rarity tier with the Rarity odds, then a club of that tier.
--
--   { id, name, rarity, blurb, boosts, perks, glyph }
--     boosts   stat ids in order; each gets Rarity.boostAmounts[rarity][i] (same rule as schools)
--     perks    Legendary and Mythic clubs only
-- Pool sizes shrink with rarity: 4 Common, 3 Uncommon, 2 Rare, 1 Epic, 1 Legendary, exactly 1 Mythic.

export type ClubDef = {
	id: string,
	name: string,
	rarity: string,
	blurb: string,
	boosts: { string },
	perks: { string },
	glyph: string,
}

local function c(
	id: string,
	name: string,
	rarity: string,
	glyph: string,
	blurb: string,
	boosts: { string },
	perks: { string }?
): ClubDef
	return { id = id, name = name, rarity = rarity, glyph = glyph, blurb = blurb, boosts = boosts, perks = perks or {} }
end

local list: { ClubDef } = {
	-- Common
	c("debate_team", "Debate Team", "common", "🎙", "Arguing for sport. Interviews feel familiar.", {}),
	c("model_un", "Model UN", "common", "🌐", "Three days in a hotel pretending to be a diplomat.", {}),
	c("startup_club", "Startup Club", "common", "🚀", "Pitch decks, pizza and an app nobody downloaded.", {}),
	c("real_estate_club", "Real Estate Club", "common", "🏢", "Cap rates over coffee on Thursday nights.", {}),
	-- Uncommon
	c("finance_club", "Finance Club", "uncommon", "💼", "Mock stock pitches and the first suit.", { "knowledge" }),
	c("trading_club", "Trading Club", "uncommon", "📈", "A paper portfolio and strong opinions about rates.", {
		"risk",
	}),
	c("varsity_rowing", "Varsity Rowing", "uncommon", "🚣", "5 a.m. practice. Every single day.", { "discipline" }),
	-- Rare
	c(
		"investment_society",
		"Investment Society",
		"rare",
		"🏦",
		"Alumni-run, with a real fund and Superday tips.",
		{ "knowledge", "skill" }
	),
	c("quant_society", "Quant Society", "rare", "🧮", "Brain teasers, Python and probability puzzles.", {
		"skill",
		"speed",
	}),
	-- Epic
	c(
		"wealth_management_society",
		"Wealth Management Society",
		"epic",
		"💎",
		"Client dinners and a rolodex before graduation.",
		{ "charisma", "network", "discipline" }
	),
	-- Legendary
	c(
		"student_government",
		"Student Government",
		"legendary",
		"🏛",
		"President of the student body. Boards love a leader.",
		{ "charisma", "network", "discipline" },
		{ "boardroom_pedigree" }
	),
	-- Mythic
	c(
		"golf_team",
		"Golf Team",
		"mythic",
		"⛳",
		"Deals get done on the back nine. The alumni always take your call.",
		{ "network", "charisma", "luck" },
		{ "alumni_lifeline" }
	),
}

return list
