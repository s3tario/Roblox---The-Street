--!strict
-- Config/LifeRoll: schools (design v3 §1-§2; contracts §16 school ids). Pure data.
--
--   { id, name, short, rarity, initials, motto, blurb, colors = {primary, secondary}, logo, boosts, perks }
--     logo     the crest logo id for Shared/Assets/Logos (= the school id; drawn by the logos feature)
--     colors   "#RRGGBB" strings, the same field/ordinary colours the crest uses
--     boosts   stat ids in order; each gets Rarity.boostAmounts[rarity][i] (Uncommon 1 stat, Rare 2, Epic and up 3;
--              Mythic +8 to the first, +5 to the rest)
--     perks    perk ids (Config/LifeRoll/Perks), Legendary and Mythic only
-- The school's rarity also caps the highest title the player can reach (careerPath reads
-- ProfileService:GetSchoolTierOrder).

export type SchoolDef = {
	id: string,
	name: string,
	short: string,
	rarity: string,
	initials: string,
	motto: string,
	blurb: string,
	colors: { primary: string, secondary: string },
	logo: string,
	boosts: { string },
	perks: { string },
}

local function s(
	id: string,
	name: string,
	short: string,
	rarity: string,
	initials: string,
	primary: string,
	secondary: string,
	motto: string,
	blurb: string,
	boosts: { string },
	perks: { string }?
): SchoolDef
	return {
		id = id,
		name = name,
		short = short,
		rarity = rarity,
		initials = initials,
		motto = motto,
		blurb = blurb,
		colors = { primary = primary, secondary = secondary },
		logo = id,
		boosts = boosts,
		perks = perks or {},
	}
end

local list: { SchoolDef } = {
	-- Common ------------------------------------------------------------------------------------
	s(
		"eastbridge_state",
		"Eastbridge State",
		"Eastbridge",
		"common",
		"ES",
		"#6E1F2B",
		"#D4A537",
		"Grit Before Glory",
		"The home team. Night classes, a cracked quad and the cheapest coffee in town.",
		{}
	),
	s(
		"coastal_cc",
		"Coastal Community College",
		"Coastal",
		"common",
		"CC",
		"#13616B",
		"#E9D8A6",
		"Every Tide Rises",
		"Two years of credits and a sea breeze. Plenty of bankers started here.",
		{}
	),
	s(
		"midvale",
		"Midvale University",
		"Midvale",
		"common",
		"M",
		"#2F5D3A",
		"#5E8F68",
		"Steady in the Middle",
		"Solid, sensible and right in the middle of everything.",
		{}
	),
	s(
		"riverbend",
		"Riverbend College",
		"Riverbend",
		"common",
		"RC",
		"#1F4E79",
		"#8EC5E8",
		"Follow the Current",
		"A small campus on the river with a loyal alumni barbecue.",
		{}
	),
	s(
		"pinecrest_state",
		"Pinecrest State",
		"Pinecrest",
		"common",
		"PS",
		"#234F3A",
		"#C9B37E",
		"Rooted and Rising",
		"Big lecture halls, bigger pine trees.",
		{}
	),
	s(
		"union_valley_tech",
		"Union Valley Tech",
		"Union Valley",
		"common",
		"UV",
		"#3E4A59",
		"#E07A2F",
		"Built to Work",
		"Engineers, accountants and people who fix things.",
		{}
	),
	-- Uncommon ----------------------------------------------------------------------------------
	s(
		"lakeshore",
		"Lakeshore University",
		"Lakeshore",
		"uncommon",
		"L",
		"#1D5C8C",
		"#5FA8D3",
		"Clear Water, Clear Minds",
		"Lake views and a famous public speaking program.",
		{ "charisma" }
	),
	s(
		"granite_tech",
		"Granite Institute of Technology",
		"Granite Tech",
		"uncommon",
		"GT",
		"#3F444A",
		"#8E979F",
		"Solid Under Pressure",
		"Problem sets until sunrise. Spreadsheets hold no fear.",
		{ "skill" }
	),
	s(
		"harborview",
		"Harborview College",
		"Harborview",
		"uncommon",
		"HC",
		"#14365E",
		"#E3E7EC",
		"Ships Come In",
		"A port-city college with alumni on every trading desk.",
		{ "network" }
	),
	-- Rare --------------------------------------------------------------------------------------
	s(
		"northfield",
		"Northfield University",
		"Northfield",
		"rare",
		"N",
		"#1B2F5E",
		"#F2F2F2",
		"Ad Astra per Labores",
		"Old stone, cold winters and a library that never closes.",
		{ "knowledge", "discipline" }
	),
	s(
		"ridgemont",
		"Ridgemont University",
		"Ridgemont",
		"rare",
		"R",
		"#3C2F5C",
		"#9C8FC4",
		"Altius Cogita",
		"A hilltop campus known for its quant and economics departments.",
		{ "skill", "risk" }
	),
	-- Epic --------------------------------------------------------------------------------------
	s(
		"kingsbridge",
		"Kingsbridge College",
		"Kingsbridge",
		"epic",
		"K",
		"#8C1C2B",
		"#E8C25A",
		"Cross Every Bridge",
		"Ivy-covered and well connected. Recruiters know the name.",
		{ "knowledge", "charisma", "network" }
	),
	s(
		"ashworth",
		"Ashworth University",
		"Ashworth",
		"epic",
		"A",
		"#1E5A5A",
		"#E7D8B0",
		"Ex Cinere Aurum",
		"Rigorous, quiet and full of future fund managers.",
		{ "skill", "discipline", "risk" }
	),
	-- Legendary ---------------------------------------------------------------------------------
	s(
		"whartonia",
		"Whartonia School of Business",
		"Whartonia",
		"legendary",
		"W",
		"#0B2545",
		"#A61C2E",
		"Capital Never Sleeps",
		"The business school. Half of Bank Row has the diploma on the wall.",
		{ "knowledge", "skill", "network" },
		{ "ivy_network" }
	),
	s(
		"stanfjord",
		"Stanfjord University",
		"Stanfjord",
		"legendary",
		"S",
		"#8C1515",
		"#D8C9A8",
		"Ventus Novi Spirat",
		"Palm trees, founders and an alumni network that looks after its own.",
		{ "skill", "speed", "risk" },
		{ "alumni_lifeline" }
	),
	-- Mythic ------------------------------------------------------------------------------------
	s(
		"harvale",
		"Harvale University",
		"Harvale",
		"mythic",
		"H",
		"#A51C30",
		"#F4E6C8",
		"Veritas et Capitalis",
		"The oldest name in the game. Every door on the Street opens.",
		{ "network", "knowledge", "charisma" },
		{ "ivy_network", "legacy_seat" }
	),
}

return list
