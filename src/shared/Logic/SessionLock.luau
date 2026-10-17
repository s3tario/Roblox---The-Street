--!strict
-- Session-lock protocol for the PlayerData_v1 record. PURE: no services, no clocks; callers pass `now`.
--
-- Stored record (one DataStore key per user, "u_<userId>"):
--   { data = <profile>?, session = { jobId, placeId, lockedAt }?, writeId = <number> }
--
-- Every write goes through UpdateAsync and one of the transforms below, so the decision about whether a
-- server may touch the record is always made against the freshest stored value:
--   * acquire(): on load. Free or own lock -> take it; stale lock (no heartbeat for STALE_AFTER) -> steal it;
--     otherwise -> wait and retry with retryDelay().
--   * write():   on every save. Only the lock holder whose writeId chain is intact may write. Each write
--     refreshes `lockedAt` (the heartbeat) and bumps `writeId`; `release = true` clears the session.
-- `sid` (optional everywhere) is a per-session id stamped into the lock. A server re-acquires its own job's
-- lock at once when the same user rejoins it, so the job id alone can't tell an old session of that user from
-- the new one; with sids, the old session's writes are refused as "conflict" even when its own last attempt
-- was uncertain (see checkWrite).

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local SessionLock = {}

SessionLock.STALE_AFTER = 600 -- seconds without a heartbeat before another server may steal the lock
SessionLock.BACKOFF = { 1, 2, 3, 5, 8 } -- waits between lock attempts: 6 attempts over ~19 s
SessionLock.MAX_ATTEMPTS = #SessionLock.BACKOFF + 1

export type Session = { jobId: string, placeId: number, lockedAt: number, sid: string? }
export type Record = { data: any?, session: Session?, writeId: number }
export type Decision = "acquire" | "steal" | "wait"
export type WriteStatus = "ok" | "missing" | "stolen" | "conflict"

local function isValidSession(s: any): boolean
	return type(s) == "table" and type(s.jobId) == "string" and type(s.lockedAt) == "number"
end

-- Coerce whatever is stored under the key into a Record (or nil when the key is empty).
-- A bare profile written without the wrapper (legacy/manual edits) is adopted as `data`.
function SessionLock.normalize(raw: any): Record?
	if raw == nil then
		return nil
	end
	if type(raw) ~= "table" then
		return { data = nil, session = nil, writeId = 0 }
	end
	local isWrapper = raw.data ~= nil or raw.session ~= nil or raw.writeId ~= nil
	if not isWrapper then
		if next(raw) == nil then
			return { data = nil, session = nil, writeId = 0 }
		end
		return { data = raw, session = nil, writeId = 0 }
	end
	return {
		data = if type(raw.data) == "table" then raw.data else nil,
		session = if isValidSession(raw.session) then raw.session else nil,
		writeId = if type(raw.writeId) == "number" then raw.writeId else 0,
	}
end

-- Lock decision for a server that wants to load this record.
-- Returns the decision plus a reason: "free" | "own" | "stale" | "corrupt" | "prefix" | "held".
-- `stealPrefix` (Studio only): a live lock whose jobId starts with it is taken over at once, so a Studio
-- session that was force-closed doesn't block the next Play for 10 minutes. Live job ids never match it.
function SessionLock.decide(record: any, now: number, myJobId: string, stealPrefix: string?): (Decision, string)
	local rec = SessionLock.normalize(record)
	if rec == nil or rec.session == nil then
		return "acquire" :: Decision, "free"
	end
	local s = rec.session :: Session
	if s.jobId == myJobId then
		return "acquire" :: Decision, "own"
	end
	local age = now - s.lockedAt
	if age > SessionLock.STALE_AFTER then
		return "steal" :: Decision, "stale"
	end
	-- A lockedAt far in the future can never go stale; treat it as corrupt rather than locking forever.
	if age < -SessionLock.STALE_AFTER then
		return "steal" :: Decision, "corrupt"
	end
	if stealPrefix and stealPrefix ~= "" and string.sub(s.jobId, 1, #stealPrefix) == stealPrefix then
		return "steal" :: Decision, "prefix"
	end
	return "wait" :: Decision, "held"
end

-- Seconds to wait before lock attempt `attempt + 1`, or nil when attempts are exhausted.
function SessionLock.retryDelay(attempt: number): number?
	return SessionLock.BACKOFF[attempt]
end

-- UpdateAsync transform for loading. Returns the decision, its reason, and the record to store
-- (nil when the decision is "wait", which cancels the UpdateAsync).
function SessionLock.acquire(
	record: any,
	now: number,
	myJobId: string,
	placeId: number,
	stealPrefix: string?,
	sid: string?
): (Decision, string, Record?)
	local decision: Decision, reason: string = SessionLock.decide(record, now, myJobId, stealPrefix)
	if decision == "wait" then
		return decision, reason, nil
	end
	local rec = SessionLock.normalize(record)
	local out: Record = {
		data = if rec then rec.data else nil,
		session = { jobId = myJobId, placeId = placeId, lockedAt = math.floor(now), sid = sid },
		writeId = (if rec then rec.writeId else 0) + 1,
	}
	return decision, reason, out
end

-- May the holder of `expectedWriteId` write this record?
--   "missing"  the key was removed (e.g. a data-erasure request): never recreate it
--   "stolen"   another server holds the lock, or it was released by someone else
--   "conflict" someone wrote without going through our session (writeId chain broken, or the lock carries
--              another session's sid), e.g. a newer session of the same user on the same server
-- With `uncertain` (one of our earlier write attempts errored, so it may have committed anyway)
-- `expectedWriteId + 1` is accepted too: that is our own write. Pass `sid` so that this allowance can never
-- let an older session write over a newer session that re-acquired the lock on the same server.
function SessionLock.checkWrite(
	record: any,
	myJobId: string,
	expectedWriteId: number,
	uncertain: boolean?,
	sid: string?
): WriteStatus
	local rec = SessionLock.normalize(record)
	if rec == nil then
		return "missing" :: WriteStatus
	end
	local s = rec.session
	if s == nil or s.jobId ~= myJobId then
		return "stolen" :: WriteStatus
	end
	if sid ~= nil and type(s.sid) == "string" and s.sid ~= sid then
		return "conflict" :: WriteStatus
	end
	if rec.writeId ~= expectedWriteId and not (uncertain and rec.writeId == expectedWriteId + 1) then
		return "conflict" :: WriteStatus
	end
	return "ok" :: WriteStatus
end

-- UpdateAsync transform for saving. `payload` nil keeps the stored data (heartbeat or release only).
-- `uncertain` and `sid` as in checkWrite.
-- Returns the status and the record to store (nil unless status is "ok").
function SessionLock.write(
	record: any,
	now: number,
	myJobId: string,
	placeId: number,
	expectedWriteId: number,
	payload: any?,
	release: boolean?,
	uncertain: boolean?,
	sid: string?
): (WriteStatus, Record?)
	local status: WriteStatus = SessionLock.checkWrite(record, myJobId, expectedWriteId, uncertain, sid)
	if status ~= "ok" then
		return status, nil
	end
	local rec = SessionLock.normalize(record) :: Record
	local out: Record = {
		data = if payload ~= nil then payload else rec.data,
		session = if release
			then nil
			else { jobId = myJobId, placeId = placeId, lockedAt = math.floor(now), sid = sid },
		writeId = expectedWriteId + 1,
	}
	return "ok" :: WriteStatus, out
end

-- True when the record is locked by a live session of some other server.
function SessionLock.heldElsewhere(record: any, now: number, myJobId: string, stealPrefix: string?): boolean
	local decision = SessionLock.decide(record, now, myJobId, stealPrefix)
	return decision == "wait"
end

-- UpdateAsync transform for a support restore. Refused ("held") while another server's live session holds
-- the lock (`stealPrefix` as in decide). The restored copy keeps the CURRENT save's backup rotation (meta.backupDay/backupSlot) so restoring
-- an old copy never rewinds it, gets `note` appended to its audit ring, and is written with the lock released.
function SessionLock.restore(
	record: any,
	now: number,
	myJobId: string,
	restored: { [string]: any },
	note: any?,
	ringMax: number?,
	stealPrefix: string?
): ("ok" | "held", Record?)
	if SessionLock.heldElsewhere(record, now, myJobId, stealPrefix) then
		return "held", nil
	end
	local rec = SessionLock.normalize(record)
	local data = TableUtil.deepCopy(restored)
	if type(data.meta) ~= "table" then
		data.meta = {}
	end
	local current = if rec and type(rec.data) == "table" then rec.data.meta else nil
	if type(current) == "table" then
		data.meta.backupDay = current.backupDay
		data.meta.backupSlot = current.backupSlot
	end
	if note ~= nil then
		if type(data.audit) ~= "table" then
			data.audit = {}
		end
		table.insert(data.audit, note)
		TableUtil.trimFront(data.audit, ringMax or 100)
	end
	return "ok", { data = data, session = nil, writeId = (if rec then rec.writeId else 0) + 1 }
end

return SessionLock
