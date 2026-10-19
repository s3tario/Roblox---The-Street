--!strict
-- Achievement data (owned by `tutorial`; docs/contracts.md §3). Saved and replicated to its owner; permanent: rebirth,
-- firing and fresh starts never touch either key.
--
--   achievements          { [achievementId] = unix time unlocked }   (Config/Achievements)
--   achievementProgress   { [counter] = number }   counters behind the count-based achievements
--                         (Logic/QuestLine/Awards.bump: "task", "trade", "trade:win", "review:star", "talk:<npcId>", ...)

return {
	achievements = {},
	achievementProgress = {},
}
