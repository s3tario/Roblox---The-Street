--!strict
-- Player work data (owned by `work`; docs/contracts.md §3 and §8). Saved as data.work and replicated to its owner.
-- WorkService is the only writer; answer keys never live here (the task in progress is server memory only).
--
--   completed   { [taskId] = count }            finished tasks (graded, not voided)
--   quality     { [taskId] = last quality }     the latest quality per task
--   best        { [taskId] = best quality }
--   coreDone    number                           core tasks finished (all time)
--   lastTaskAt  number                           server time of the latest finished task (0 = never)
--   cooldowns   { [taskId] = server time }       a task can't be drawn or started again before this
--   board       { key, role, day, at, tasks = { {id, core, done, offered?, carried?, source?, data?, expiresAt?,
--                 quality?, at?} } }             today's board (Logic/Tasks/_shared/Board)
--   recent      { {taskId, quality, xp, pay, onTime, at} }   ring of the latest 12 results
--   totals      { tasks, xp, pay, late }         lifetime counters (profile cards, achievements)
--   attempts    number                           tasks started (fresh variants are seeded with it)

return {
	work = {
		completed = {},
		quality = {},
		best = {},
		coreDone = 0,
		lastTaskAt = 0,
		cooldowns = {},
		board = { key = "", role = "", day = 0, at = 0, tasks = {} },
		recent = {},
		totals = { tasks = 0, xp = 0, pay = 0, late = 0 },
		attempts = 0,
	},
}
