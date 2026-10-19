--!strict
-- Campus and onboarding data (owned by `tutorial`; docs/contracts.md §3). Saved as data.campus and replicated to its
-- owner. TutorialService is the only writer, except `offer`, which careerPath sets when an offer is accepted (it opens
-- the subway downtown) and clears on a fresh start. RebirthService resets the whole key to these defaults.
--
--   step          current onboarding step id (Config/Quests.steps); "" before the chain starts, "done" after it
--   done          { [stepId] = unix time } finished steps        skipped  { [stepId] = true } steps the player skipped
--   marks         { [stepId] = true } steps finished out of order (an NPC conversation, an acknowledgement); the
--                 chain completes them when it gets there
--   stuck         active seconds spent on the current step (a skip is offered after Config/Quests.SKIP_AFTER)
--   startedAt     unix time the chain started
--   quests        side quests { [questId] = { n = progress, done = unix time?, seen = { [key] = true } } }
--   offer         an offer was accepted (careerPath)            club  joined the Finance Club
--   applications  the Recruiting Board pipeline (Logic/QuestLine/Recruit): { { companyId, stage, q1?, q2?, quality?,
--                 chance?, at, seed, tries, walkOn, offerId? } }
--   pending       { [taskId] = companyId } the interview last started from the Recruiting screen (a fallback when a
--                 TaskCompleted result arrives without its company)
--   network       { count, ids = { [contactKey] = true } } people met for the networking step
--   exchanges     { [userId as string] = day } business cards exchanged today (once per pair per real day)
--   flags         { [flag] = true } dialogue flags               talked  { [rewardKey] = day } daily dialogue rewards
--   jobTasks      graded tasks finished while employed           trades  trades made (first-trade step)
--   xpBoost       { mult, left, source } mentorship XP boost (SocialService:GetXpBoost; granted from M3)
--   bannerShown   the Eastbridge arrival banner was shown once

return {
	campus = {
		step = "",
		done = {},
		skipped = {},
		marks = {},
		stuck = 0,
		startedAt = 0,
		quests = {},
		offer = false,
		applications = {},
		pending = {},
		club = false,
		network = { count = 0, ids = {} },
		exchanges = {},
		flags = {},
		talked = {},
		jobTasks = 0,
		trades = 0,
		xpBoost = { mult = 1, left = 0, source = "" },
		bannerShown = false,
	},
}
