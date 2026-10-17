--!strict
-- Career data defaults (owned by `careerPath`; docs/contracts.md §3 and §5). Saved in data.career and replicated
-- to the owner. CareerService keeps the derived HUD fields (title, roleTitle, companyName, weekLabel, xpToNext,
-- promotion, fitScore, outfitLevel, windowRemaining, bossName) up to date before every replication.
--
--   level, xp                 global level 1..100 and XP into the current level
--   track, companyId, roleId  "" / "" / "student" until hired; roleId "unemployed" between jobs
--   rank                      0 student, 1 entry .. N (kept while between jobs so cosmetics stay unlocked)
--   status                    "student" | "active" | "coaching" | "probation" | "fired"
--   week, weekday             career week (0 until hired) and workday 1..5 (Mon..Fri)
--   weekActive                active seconds into the work week (persists across sessions)
--   weekStartActive           ActivityService active seconds when the week began (review window start)
--   reviewDue, overdueActive  Friday review pending, and active seconds it has been waiting
--   weekWork, weekRep         this week's graded work and reputation (review inputs)
--   coreAtRank                core assignments completed at the current rank (promotion requirement)
--   criticalStreak            consecutive Critical reviews (two in a row = fired)
--   reviews                   ring of the last 26 reviews {id, week, score, band, outcome, components, at, ...}
--   plaques                   ring of the latest 100 deal plaques {id, dealId, name, at, quality, companyId}
--   plaqueCount, dealMastery, prestige, signatures = {[dealId] = n}
--   history                   ring of the latest 60 timeline entries {kind, at, week, roleId, companyId, title}
--   offers                    pending job offers {id, companyId, track, rank, source, at}
--   fired                     the last wipeout while between jobs (empty table otherwise)
--   reinstateCredits          Career Reinstatement credits (monetization: GrantReinstatementCredit)
--   applications, connections, rival   reserved for milestone 3 (OfferService, RivalService)
--   lifeStartActive, topTitleAt, fastestRunSec   Fastest Run board (active seconds from a life start)
--   onboarded                 false until the player first reaches their firm's office after a hire
--
-- careerPrivate (never replicated): server-only career state, e.g. the re-entry interview in progress (it holds
-- the answer key, so it must not reach the client).

return {
	career = {
		level = 1,
		xp = 0,
		track = "",
		companyId = "",
		roleId = "student",
		rank = 0,
		title = "College Student",
		status = "student",
		reputation = 0,
		week = 0,
		weekday = 1,
		weekActive = 0,
		weekStartActive = 0,
		reviewDue = false,
		overdueActive = 0,
		remoteCalled = false,
		weekWork = { count = 0, qualitySum = 0, core = 0, clientCount = 0, clientSum = 0, best = 0 },
		weekRep = 0,
		weekViolations = 0,
		coreAtRank = 0,
		criticalStreak = 0,
		lastBand = "",
		reviews = {},
		signatures = {},
		plaques = {},
		plaqueCount = 0,
		dealMastery = 0,
		prestige = 0,
		wipeouts = 0,
		comebacks = 0,
		history = {},
		offers = {},
		nextOfferId = 1,
		nextReviewId = 1,
		nextPlaqueId = 1,
		fired = {},
		reinstateCredits = 0,
		applications = {},
		connections = {},
		rival = {},
		onboarded = false,
		lifeStartActive = 0,
		topTitleAt = 0,
		fastestRunSec = 0,

		-- derived (recomputed by CareerService before replication)
		roleTitle = "College Student",
		companyName = "",
		weekLabel = "Campus",
		xpToNext = 0,
		windowRemaining = -1, -- active seconds to the Friday review (-1 when not counting)
		bossName = "",
		promotion = { ready = false, missing = {}, next = "", checklist = {} },
		fitScore = 0,
		outfitLevel = 1,
		dressLevel = 1,
		levelCap = 8,
	},
	careerPrivate = {
		reentry = {},
	},
	_private = { careerPrivate = true },
}
