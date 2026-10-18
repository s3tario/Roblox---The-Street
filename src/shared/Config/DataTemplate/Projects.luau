--!strict
-- Player big-deal data (owned by `projects`; docs/contracts.md §3 and §9). Saved as data.projects. ProjectService is
-- the only writer (RebirthService resets it to this default).
--
--   projects[projectId] = Record (normalized by Logic/Projects/_registry.record):
--     state          the deal in progress or the last finished one (the module's own state: JSON-safe; it holds the
--                    current stage's answer key, which is why this key is PRIVATE and never replicates)
--     runs           finished runs (closed or pulled)        closed     runs that closed (plaque earned)
--     best / last    best and latest quality (0..100)       lastAt     server time of the latest finish
--     startedAt      server time the current run started    stageAt    server time the current stage began
--     attempts       runs started                          abandoned  runs abandoned or cancelled
--     cooldownUntil  server time the deal can start again
--     history        { {at, quality, closed, name} } the latest few runs
-- The client never reads this table: Project.List / Project.View answer with the safe parts.

return {
	projects = {},
	_private = { projects = true },
}
