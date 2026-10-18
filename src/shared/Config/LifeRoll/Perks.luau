--!strict
-- Config/LifeRoll: perks carried by Legendary and Mythic schools and clubs (design v3 §2). Pure data.
--
--   { id, name, desc, glyph, kind, stacks }
--     kind    "consumable"  used up by ConsumePerk (each source grants one use)
--             "passive"     always on while owned
--             "future"      takes effect on every later Life Roll (kept through rebirths: profile.legacySeat)
--     stacks  true when each source adds a use (count), false when owning it once is all that matters
-- profile.perks = { [perkId] = count } holds the perks of the current life (count = remaining uses).

export type PerkDef = {
	id: string,
	name: string,
	desc: string,
	glyph: string,
	kind: string,
	stacks: boolean,
}

local list: { PerkDef } = {
	{
		id = "alumni_lifeline",
		name = "Alumni Lifeline",
		desc = "One free revive when fired: you keep your job on probation instead.",
		glyph = "🛟",
		kind = "consumable",
		stacks = true,
	},
	{
		id = "ivy_network",
		name = "Ivy Network",
		desc = "+8% job-offer odds at every firm.",
		glyph = "🌿",
		kind = "passive",
		stacks = false,
	},
	{
		id = "legacy_seat",
		name = "Legacy Seat",
		desc = "+1 extra reroll on every future Life Roll.",
		glyph = "🪑",
		kind = "future",
		stacks = false,
	},
	{
		id = "boardroom_pedigree",
		name = "Boardroom Pedigree",
		desc = "Top-title school requirements are one tier easier for you.",
		glyph = "🎩",
		kind = "passive",
		stacks = false,
	},
}

return list
