--!strict
-- Data-owned profile keys (docs/contracts.md §3).
--   meta   bookkeeping. DataService sets schema/createdAt/lastSeen/sessions and the backup fields;
--          ActivityService owns activeSec.
--   audit  private ring buffer of the last 100 { t, kind, d } entries, written by AuditService.

local Migrations = require(script.Parent.Parent.Parent.Logic.Migrations)

return {
	meta = {
		schema = Migrations.CURRENT_SCHEMA,
		createdAt = 0, -- unix seconds, set when the profile is first created
		lastSeen = 0, -- unix seconds of the latest load or save
		sessions = 0, -- number of sessions (loads) so far
		activeSec = 0, -- lifetime active seconds, AFK excluded (ActivityService)
		backupDay = -1, -- UTC day of the latest rolling backup (-1 = never)
		backupSlot = 0, -- slot (1..3) of the latest rolling backup (0 = none yet)
	},
	audit = {},
	_private = { audit = true },
}
