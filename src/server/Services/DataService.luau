--!strict
-- DataService: player persistence and state replication (docs/contracts.md §2 "Replicated player state", §3).
--
-- Storage: DataStore "PlayerData_v1", key "u_<userId>", record { data, session = {jobId, placeId, lockedAt},
-- writeId }. Every write is an UpdateAsync through Logic/SessionLock, so a server only ever writes a record it
-- holds the session lock for, and never overwrites a newer write.
--
-- Lifecycle per player: wait for any previous session of the same user in this server to finish -> acquire the
-- lock (wait/retry, steal when stale, kick on timeout) -> migrate -> deep-fill the template -> ProfileLoaded ->
-- autosave every 120 s (lock heartbeat) -> ProfileReleasing -> final save + release.
--
-- Studio without API access (or ServerStorage attribute DataMock = true in Studio) uses an in-memory mock store.
-- `data._session` is a per-session scratch table: never saved, never replicated.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local Hash = require(Shared.Util.Hash)
local Signal = require(Shared.Util.Signal)
local TableUtil = require(Shared.Util.TableUtil)
local Time = require(Shared.Util.Time)
local DataTemplate = require(Shared.Config.DataTemplate)
local DataUtil = require(Shared.Logic.DataUtil)
local Migrations = require(Shared.Logic.Migrations)
local SessionLock = require(Shared.Logic.SessionLock)

local Registry = require(script.Parent.Parent.Registry)

export type Data = { [string]: any }
type Store = {
	GetAsync: (self: any, key: string) -> any,
	UpdateAsync: (self: any, key: string, transform: (any, any) -> any) -> any,
}
type Session = {
	player: Player,
	userId: number,
	key: string,
	sid: string, -- unique per session; stamped into the lock so an older session of this user can never write
	state: "loading" | "active" | "closed",
	data: Data?,
	leaving: boolean, -- the player left the server
	closing: boolean, -- the server is shutting down
	dead: string?, -- why this session may no longer save ("stolen", "conflict", "missing", "restored")
	lockHeld: boolean,
	writeId: number,
	writeUncertain: boolean, -- a write attempt errored since the last confirmed write (it may have committed)
	seq: number, -- replication sequence number (Data.Key)
	nextAutosave: number,
	lastWriteAt: number,
	saving: boolean,
	saveWaiters: { thread },
	lastSaveBegan: number,
	lastSaveOk: boolean,
	finalized: boolean,
	finalSaved: boolean, -- the final (release) save wrote the profile
	backupSlot: number?,
	backupSnapshot: Data?,
	stolenFrom: { [string]: any }?,
	reported: { [string]: boolean },
	sizeWarned: boolean,
	oversize: boolean,
	loadedSignal: Signal.Signal,
	leftSignal: Signal.Signal,
	closedSignal: Signal.Signal,
}

local PROFILE_STORE = "PlayerData_v1"
local BACKUP_STORE = "PlayerBackup_v1"
local BACKUP_SLOTS = 3
local AUTOSAVE_EVERY = 120
local FLUSH_EVERY = 0.2
local MIN_WRITE_GAP = 6 -- DataStore allows one write per key every 6 s
local SHUTDOWN_BUDGET = 25
local SNAPSHOT_WAIT = 10
local FINAL_WAIT = 40 -- a save requested while the player is leaving waits this long for the final save
local LOAD_ERROR_RETRIES = 5
local SAVE_RETRIES = 4
local FINAL_SAVE_RETRIES = 5
local WARN_BYTES = 3.5 * 1024 * 1024
local MAX_BYTES = 4 * 1024 * 1024 - 4096 -- DataStore value limit minus room for the session wrapper
local AUDIT_RING = 100

local TRANSIENT: { [string]: boolean } = { _session = true }
local HIDDEN: { [string]: boolean } = table.clone(DataTemplate.private)
for k in TRANSIENT do
	HIDDEN[k] = true
end

local IS_STUDIO = RunService:IsStudio()
local STUDIO_PREFIX = "studio-"
local JOB_ID = if game.JobId ~= "" then game.JobId else STUDIO_PREFIX .. HttpService:GenerateGUID(false)
-- In Studio, a lock left by an earlier Studio session (force-closed without BindToClose) is taken over at once.
local STEAL_PREFIX: string? = if IS_STUDIO then STUDIO_PREFIX else nil

local DataService = { Name = "DataService", Priority = 1 }

DataService.ProfileLoaded = Signal.new() -- (player, data)
DataService.ProfileReleasing = Signal.new() -- (player, data), before the final save on leave/shutdown

-- Player-facing messages (kick reasons, notices). Kept together so they can be localized.
DataService.Messages = {
	lockTimeout = "Your save is still open in another server. Please wait a few seconds and rejoin.",
	loadFailed = "We couldn't load your save right now. Your progress is safe. Please rejoin in a minute.",
	futureSchema = "This server is running an older version of The Street. Please rejoin to get the latest version.",
	lockLost = "Your save was opened in another server, so this session was closed to protect your progress. Please rejoin.",
	restored = "Support has restored your save. Please rejoin to continue.",
	oversize = "Your save has grown too large to store, so recent progress can't be saved. Please contact support.",
}

---------------------------------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------------------------------
local sessions: { [Player]: Session } = {}
local byUser: { [number]: Session } = {}
local dirty: { [Player]: { [string]: boolean } } = {}
local globals: { [string]: any } = {}
local globalSeq = 0
local shuttingDown = false
local shutdownDeadline: number? = nil
local warnedPrivate: { [string]: boolean } = {}

local backendMode: "pending" | "real" | "mock" = "pending"
local backendDetecting = false
local backendReady = Signal.new()
local stores: { [string]: Store } = {}
local mockValues: { [string]: { [string]: any } } = {}

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
local function profileKey(userId: number): string
	return "u_" .. tostring(userId)
end

local function backupKey(userId: number, slot: number | string): string
	return ("u_%d_%s"):format(userId, tostring(slot))
end

local function inGame(player: Player): boolean
	return player.Parent == Players
end

local function kick(player: Player, messageKey: string)
	if inGame(player) then
		local message = (DataService.Messages :: any)[messageKey] or DataService.Messages.loadFailed
		pcall(player.Kick, player, message)
	end
end

-- Wait for `signal` to fire, at most `timeout` seconds. Returns true if it fired.
local function waitSignal(signal: Signal.Signal, timeout: number): boolean
	local thread = coroutine.running()
	local done = false
	local timer: thread? = nil
	local conn = signal:Once(function()
		if done then
			return
		end
		done = true
		if timer then
			task.cancel(timer)
		end
		task.spawn(thread, true)
	end)
	timer = task.delay(timeout, function()
		if done then
			return
		end
		done = true
		conn:Disconnect()
		task.spawn(thread, false)
	end)
	local fired = coroutine.yield()
	return fired == true
end

local function audit(target: Player | number, kind: string, details: { [string]: any }?)
	local ok, err = pcall(function()
		(DataService :: any):Audit(target, kind, details)
	end)
	if not ok then
		warn("[DataService] audit failed: " .. tostring(err))
	end
end

---------------------------------------------------------------------------------------------------
-- Backend (real DataStores, or an in-memory mock in Studio)
---------------------------------------------------------------------------------------------------
local function newMockStore(name: string): Store
	local values = mockValues[name]
	if not values then
		values = {}
		mockValues[name] = values
	end
	local store = {}
	function store.GetAsync(_self: any, key: string): any
		task.wait()
		return TableUtil.deepCopy(values[key])
	end
	function store.UpdateAsync(_self: any, key: string, transform: (any, any) -> any): any
		task.wait()
		local result = transform(TableUtil.deepCopy(values[key]), nil)
		if result ~= nil then
			values[key] = TableUtil.deepCopy(result)
		end
		return TableUtil.deepCopy(result)
	end
	-- The rest of the common GlobalDataStore surface, for other server code using DataService:GetStore.
	function store.SetAsync(_self: any, key: string, value: any): string
		task.wait()
		values[key] = TableUtil.deepCopy(value)
		return ""
	end
	function store.RemoveAsync(_self: any, key: string): any
		task.wait()
		local old = values[key]
		values[key] = nil
		return TableUtil.deepCopy(old)
	end
	function store.IncrementAsync(_self: any, key: string, delta: number?): number
		task.wait()
		local cur = values[key]
		local n = (if type(cur) == "number" then cur else 0) + (delta or 1)
		values[key] = n
		return n
	end
	return store :: any
end

local function waitBackend()
	if backendMode == "pending" then
		backendReady:Wait()
	end
end

local function getStore(name: string): Store
	waitBackend()
	local existing = stores[name]
	if existing then
		return existing
	end
	local created: Store = if backendMode == "mock"
		then newMockStore(name)
		else DataStoreService:GetDataStore(name) :: any
	stores[name] = created
	return created
end

local function detectBackend()
	if backendDetecting then
		return
	end
	backendDetecting = true
	local mode: "real" | "mock" = "real"
	local reason = ""
	if IS_STUDIO then
		if ServerStorage:GetAttribute("DataMock") == true then
			mode, reason = "mock", "ServerStorage attribute DataMock is true"
		elseif game.PlaceId == 0 then
			mode, reason = "mock", "the place is not published"
		end
	end
	if mode == "real" then
		local ok, err = pcall(function()
			DataStoreService:GetDataStore(PROFILE_STORE):GetAsync("probe")
		end)
		if not ok then
			if IS_STUDIO then
				mode, reason = "mock", tostring(err)
			else
				warn("[DataService] DataStore probe failed; continuing with retries: " .. tostring(err))
			end
		end
	end
	if mode == "mock" then
		warn(
			(
				"[DataService] Using an IN-MEMORY MOCK DataStore (%s). Progress will NOT persist after this session. "
				.. "Enable Studio access to API services in Game Settings > Security to use real data."
			):format(reason)
		)
	end
	backendMode = mode
	backendReady:Fire()
end

-- UpdateAsync with exponential backoff. Returns (ok, lastError). `onError` runs after every failed attempt
-- (a failed UpdateAsync may still have committed). Retries stop at `deadline`, or at the shutdown deadline
-- once the server starts closing (so a save that began earlier can't eat the BindToClose budget).
local function updateWithRetry(
	store: Store,
	key: string,
	transform: (any, any) -> any,
	attempts: number,
	deadline: number?,
	onError: (() -> ())?
): (boolean, string?)
	local lastErr: string? = nil
	for attempt = 1, attempts do
		local ok, err = pcall(function()
			store:UpdateAsync(key, transform)
		end)
		if ok then
			return true, nil
		end
		lastErr = tostring(err)
		if onError then
			onError()
		end
		warn(("[DataService] UpdateAsync %s failed (attempt %d/%d): %s"):format(key, attempt, attempts, tostring(err)))
		if attempt == attempts then
			break
		end
		local delay = DataUtil.backoff(attempt, 1, 8)
		local limit = deadline or shutdownDeadline
		if limit and os.clock() + delay >= limit then
			break
		end
		task.wait(delay)
	end
	return false, lastErr
end

local function getWithRetry(store: Store, key: string, attempts: number): (boolean, any)
	local lastErr: any = nil
	for attempt = 1, attempts do
		local ok, value = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			return true, value
		end
		lastErr = value
		if attempt < attempts then
			task.wait(DataUtil.backoff(attempt, 1, 4))
		end
	end
	return false, tostring(lastErr)
end

local function updateBudget(): number
	if backendMode ~= "real" then
		return math.huge
	end
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
	end)
	return if ok and type(budget) == "number" then budget else math.huge
end

---------------------------------------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------------------------------------
local function acquireSaveLock(s: Session)
	if s.saving then
		table.insert(s.saveWaiters, coroutine.running())
		coroutine.yield()
	end
	s.saving = true
end

local function releaseSaveLock(s: Session)
	local nextThread = table.remove(s.saveWaiters, 1)
	if nextThread then
		task.spawn(nextThread) -- ownership passes straight to the next waiter (s.saving stays true)
	else
		s.saving = false
	end
end

local function lockLost(s: Session, status: string, holder: any)
	if s.dead then
		return
	end
	s.dead = status
	s.lockHeld = false
	local by = if type(holder) == "table" then holder.jobId else nil
	warn(
		("[DataService] lost the session lock for %d (%s, now held by %s); saving stopped"):format(
			s.userId,
			status,
			tostring(by)
		)
	)
	audit(s.userId, "lock_steal", { lost = true, status = status, by = by, job = JOB_ID })
	if not s.leaving and not s.closing then
		kick(s.player, "lockLost")
	end
end

local function reportIssues(s: Session, issues: { DataUtil.Issue })
	local fresh = {}
	for _, issue in issues do
		local tag = issue.path .. "|" .. issue.reason
		if not s.reported[tag] then
			s.reported[tag] = true
			table.insert(fresh, issue)
			warn(
				("[DataService] unsaveable value in %d's data at %s: %s (fixed in the saved copy)"):format(
					s.userId,
					issue.path,
					issue.reason
				)
			)
		end
	end
	if #fresh > 0 then
		audit(s.player, "save_repaired", { issues = fresh })
	end
end

local function writeBackup(userId: number, slot: number, data: Data, now: number)
	local record = DataUtil.backupRecord(data, now, slot, "daily")
	local ok, err = updateWithRetry(getStore(BACKUP_STORE), backupKey(userId, slot), function()
		return record
	end, 3)
	if not ok then
		warn(("[DataService] daily backup of %d (slot %d) failed: %s"):format(userId, slot, tostring(err)))
	end
end

-- One write of the profile (or, when it can't be stored, a lock heartbeat that keeps the last good save).
-- Returns true only if the profile data itself was written.
local function writeProfile(s: Session, release: boolean, deadline: number?): boolean
	local data = s.data :: Data
	local now = Time.now()
	local meta = data.meta
	if type(meta) == "table" then
		meta.lastSeen = math.floor(now)
	end

	local payload: any, issues = DataUtil.toSaveable(data, TRANSIENT)
	if #issues > 0 then
		reportIssues(s, issues)
	end
	local okEncode, json = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	local size = if okEncode and type(json) == "string" then #json else DataUtil.estimateSize(payload)
	if size > MAX_BYTES then
		if not s.oversize then
			s.oversize = true
			warn(
				("[DataService] %d's save is %d bytes (limit %d); keeping the last good save"):format(
					s.userId,
					size,
					MAX_BYTES
				)
			)
			audit(s.player, "save_oversize", { bytes = size })
			local notify = Registry.get("NotifyService")
			if notify then
				pcall(function()
					notify:Notify(s.player, DataService.Messages.oversize, "bad")
				end)
			end
		end
		payload = nil
	elseif size > WARN_BYTES and not s.sizeWarned then
		s.sizeWarned = true
		warn(("[DataService] %d's save is large: %d bytes"):format(s.userId, size))
		audit(s.player, "save_large", { bytes = size })
	end

	local backupSlot, backupData = s.backupSlot, s.backupSnapshot
	if payload ~= nil and backupSlot ~= nil and backupData ~= nil and type(payload.meta) == "table" then
		payload.meta.backupDay = DataUtil.utcDay(now)
		payload.meta.backupSlot = backupSlot
	end

	local status: SessionLock.WriteStatus? = nil
	local committed: SessionLock.Record? = nil
	local holder: any = nil
	local ok, err = updateWithRetry(
		getStore(PROFILE_STORE),
		s.key,
		function(raw)
			local st: SessionLock.WriteStatus, rec = SessionLock.write(
				raw,
				Time.now(),
				JOB_ID,
				game.PlaceId,
				s.writeId,
				payload,
				release,
				s.writeUncertain,
				s.sid
			)
			status, committed = st, rec
			if st ~= "ok" then
				local current = SessionLock.normalize(raw)
				holder = if current then current.session else nil
			end
			return rec
		end,
		if release then FINAL_SAVE_RETRIES else SAVE_RETRIES,
		deadline,
		function()
			s.writeUncertain = true
		end
	)

	if not ok then
		warn(("[DataService] save of %d failed: %s"):format(s.userId, tostring(err)))
		return false
	end
	if status ~= "ok" or committed == nil then
		lockLost(s, status or "stolen", holder)
		return false
	end
	s.writeId = committed.writeId
	s.writeUncertain = false
	s.lastWriteAt = os.clock()
	if release then
		s.lockHeld = false
	end
	if payload == nil then
		return false
	end
	if backupSlot ~= nil and backupData ~= nil then
		s.backupSlot, s.backupSnapshot = nil, nil
		if type(meta) == "table" then
			meta.backupDay = DataUtil.utcDay(now)
			meta.backupSlot = backupSlot
		end
		task.spawn(writeBackup, s.userId, backupSlot, backupData, now)
	end
	return true
end

-- Result of the final (release) save, for a save requested while the player is leaving or the server is
-- closing: that final save is moments away and will include everything, so don't spend a write (or the
-- BindToClose budget) on a separate one.
local function awaitFinalSave(s: Session): boolean
	if s.state ~= "closed" then
		waitSignal(s.closedSignal, FINAL_WAIT)
	end
	return s.finalSaved
end

-- Serialized per session; concurrent requests coalesce into a save that started after they were made.
local function saveSession(s: Session, reason: string, release: boolean, deadline: number?): boolean
	if s.data == nil or not s.lockHeld or s.dead then
		return false
	end
	if not release and (s.leaving or s.closing) then
		return awaitFinalSave(s)
	end
	local requestedAt = os.clock()
	acquireSaveLock(s)
	if s.dead or not s.lockHeld then
		releaseSaveLock(s)
		return false
	end
	if not release and s.lastSaveBegan > requestedAt then
		local result = s.lastSaveOk
		releaseSaveLock(s)
		return result
	end
	if not release then
		local gap = s.lastWriteAt + MIN_WRITE_GAP - os.clock()
		if gap > 0 then
			task.wait(gap)
		end
		if s.dead or not s.lockHeld then
			releaseSaveLock(s)
			return false
		end
		if s.leaving or s.closing then
			-- The player left (or the server began closing) while this save waited: hand over to the final save.
			releaseSaveLock(s)
			return awaitFinalSave(s)
		end
	end
	s.lastSaveBegan = os.clock()
	local ok, result = pcall(writeProfile, s, release, deadline)
	if not ok then
		warn(("[DataService] save (%s) of %d errored: %s"):format(reason, s.userId, tostring(result)))
		result = false
	end
	s.lastSaveOk = result == true
	releaseSaveLock(s)
	return s.lastSaveOk
end

-- Give the lock back without touching the stored data (aborted load, failed load, oversize release).
local function releaseOnly(s: Session)
	if not s.lockHeld then
		return
	end
	local status: string? = nil
	local ok = updateWithRetry(
		getStore(PROFILE_STORE),
		s.key,
		function(raw)
			local st, rec =
				SessionLock.write(raw, Time.now(), JOB_ID, game.PlaceId, s.writeId, nil, true, s.writeUncertain, s.sid)
			status = st
			return rec
		end,
		FINAL_SAVE_RETRIES,
		shutdownDeadline,
		function()
			s.writeUncertain = true
		end
	)
	s.lockHeld = false
	if ok and status ~= "ok" then
		warn(("[DataService] lock for %d was already gone on release (%s)"):format(s.userId, tostring(status)))
	end
end

---------------------------------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------------------------------
local function aborted(s: Session): boolean
	return s.leaving or s.closing
end

-- Acquire the lock and build the in-memory profile. Returns (ok, kickMessageKey?).
local function load(s: Session): (boolean, string?)
	local store = getStore(PROFILE_STORE)
	local errors, waits = 0, 0
	local committed: SessionLock.Record? = nil
	local reason = ""
	local previous: any = nil
	while true do
		if aborted(s) then
			return false, nil
		end
		local decision: SessionLock.Decision? = nil
		local ok, err = pcall(function()
			store:UpdateAsync(s.key, function(raw)
				local d: SessionLock.Decision, r: string, rec =
					SessionLock.acquire(raw, Time.now(), JOB_ID, game.PlaceId, STEAL_PREFIX, s.sid)
				decision, reason, committed = d, r, rec
				local current = SessionLock.normalize(raw)
				previous = if current then current.session else nil
				return rec
			end)
		end)
		if not ok or decision == nil then
			errors += 1
			warn(
				("[DataService] loading %d failed (%d/%d): %s"):format(
					s.userId,
					errors,
					LOAD_ERROR_RETRIES,
					tostring(err)
				)
			)
			if errors >= LOAD_ERROR_RETRIES then
				return false, "loadFailed"
			end
			task.wait(DataUtil.backoff(errors, 1, 8))
		elseif decision == "wait" then
			waits += 1
			local delay = SessionLock.retryDelay(waits)
			if delay == nil then
				warn(
					("[DataService] %d is still locked by %s; giving up"):format(
						s.userId,
						tostring(previous and previous.jobId)
					)
				)
				return false, "lockTimeout"
			end
			task.wait(delay)
		else
			break
		end
	end

	local record = committed :: SessionLock.Record
	s.lockHeld = true
	s.writeId = record.writeId
	s.lastWriteAt = os.clock() -- acquiring was a write: the next one must respect the per-key gap
	if aborted(s) then
		return false, nil
	end
	if reason == "stale" or reason == "corrupt" or reason == "prefix" then
		s.stolenFrom = { from = previous and previous.jobId, lockedAt = previous and previous.lockedAt, why = reason }
	end

	local prep = DataUtil.prepareLoaded(record.data, DataTemplate.template, Time.now(), {
		transient = TRANSIENT,
		backupSlots = BACKUP_SLOTS,
	})
	if prep.status == "future" then
		warn(
			("[DataService] %d's save has schema %d (> %d); refusing to load"):format(
				s.userId,
				prep.fromSchema,
				Migrations.CURRENT_SCHEMA
			)
		)
		return false, "futureSchema"
	elseif prep.status == "error" or prep.data == nil then
		warn(("[DataService] migrating %d failed: %s"):format(s.userId, tostring(prep.err)))
		return false, "loadFailed"
	end
	if not prep.isNew and prep.fromSchema ~= Migrations.CURRENT_SCHEMA then
		print(
			("[DataService] migrated %d from schema %d to %d"):format(
				s.userId,
				prep.fromSchema,
				Migrations.CURRENT_SCHEMA
			)
		)
	end
	if #prep.repaired > 0 then
		warn(("[DataService] reset malformed fields for %d: %s"):format(s.userId, table.concat(prep.repaired, ", ")))
	end
	s.backupSlot, s.backupSnapshot = prep.backupSlot, prep.backupSnapshot
	s.data = prep.data
	return true, nil
end

local function finish(s: Session)
	if s.state == "closed" then
		return
	end
	s.state = "closed"
	if byUser[s.userId] == s then
		byUser[s.userId] = nil
	end
	dirty[s.player] = nil
	s.backupSnapshot = nil
	if s.leaving or not inGame(s.player) then
		if sessions[s.player] == s then
			sessions[s.player] = nil
		end
	end
	s.loadedSignal:Fire(nil) -- wake any WaitFor still waiting (load failed or aborted)
	s.closedSignal:Fire()
end

local function finalize(s: Session)
	if s.finalized then
		return
	end
	s.finalized = true
	local data = s.data
	if data ~= nil then
		local ok, err = pcall(function()
			DataService.ProfileReleasing:Fire(s.player, data)
		end)
		if not ok then
			warn("[DataService] ProfileReleasing failed: " .. tostring(err))
		end
		local saved = saveSession(s, if s.closing then "shutdown" else "leave", true, shutdownDeadline)
		s.finalSaved = saved
		if not saved and s.lockHeld then
			releaseOnly(s) -- e.g. oversize: the heartbeat path already released; this covers write errors
		end
	elseif s.lockHeld then
		releaseOnly(s)
	end
end

local function runSession(s: Session)
	local previous = byUser[s.userId]
	byUser[s.userId] = s
	if previous and previous ~= s and previous.state ~= "closed" then
		-- Same user rejoined this server while their last session is still saving: let it release first.
		waitSignal(previous.closedSignal, 45)
	end
	waitBackend()
	local ok, failure = false, nil
	if not aborted(s) then
		local success, a, b = pcall(load, s)
		if success then
			ok, failure = a, b
		else
			warn(("[DataService] load of %d errored: %s"):format(s.userId, tostring(a)))
			failure = "loadFailed"
		end
	end
	if not ok or aborted(s) then
		s.data = nil -- never save a profile that didn't finish loading
		if s.lockHeld then
			releaseOnly(s)
		end
		finish(s)
		if failure and not aborted(s) then
			kick(s.player, failure)
		end
		return
	end

	s.state = "active"
	-- Staggered first autosave (60-120 s), spread by user so a full server doesn't save in one burst.
	s.nextAutosave = os.clock() + AUTOSAVE_EVERY * (0.5 + 0.5 * Hash.unit("autosave", s.userId, JOB_ID))
	local data = s.data :: Data
	s.loadedSignal:Fire(data)
	DataService.ProfileLoaded:Fire(s.player, data)
	if s.stolenFrom then
		audit(s.player, "lock_steal", s.stolenFrom)
	end

	if not aborted(s) then
		s.leftSignal:Wait()
	end
	local okFinal: boolean, errFinal: any = (pcall :: any)(finalize, s)
	if not okFinal then
		warn(("[DataService] final save of %d errored: %s"):format(s.userId, tostring(errFinal)))
	end
	finish(s)
end

local function ensureSession(player: Player): Session?
	local existing = sessions[player]
	if existing then
		return existing
	end
	if shuttingDown or not inGame(player) then
		return nil
	end
	local s: Session = {
		player = player,
		userId = player.UserId,
		key = profileKey(player.UserId),
		sid = HttpService:GenerateGUID(false),
		state = "loading",
		data = nil,
		leaving = false,
		closing = false,
		dead = nil,
		lockHeld = false,
		writeId = 0,
		writeUncertain = false,
		seq = 0,
		nextAutosave = math.huge,
		lastWriteAt = -math.huge,
		saving = false,
		saveWaiters = {},
		lastSaveBegan = -math.huge,
		lastSaveOk = false,
		finalized = false,
		finalSaved = false,
		backupSlot = nil,
		backupSnapshot = nil,
		stolenFrom = nil,
		reported = {},
		sizeWarned = false,
		oversize = false,
		loadedSignal = Signal.new(),
		leftSignal = Signal.new(),
		closedSignal = Signal.new(),
	}
	sessions[player] = s
	task.spawn(runSession, s)
	return s
end

local function onPlayerRemoving(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	s.leaving = true
	if s.state == "closed" then
		sessions[player] = nil
		return
	end
	s.leftSignal:Fire()
end

---------------------------------------------------------------------------------------------------
-- Replication
---------------------------------------------------------------------------------------------------
local function flushDirty()
	if next(dirty) == nil then
		return
	end
	local batch = dirty
	dirty = {}
	for player, keys in batch do
		local s = sessions[player]
		local data = if s then s.data else nil
		if s and data and inGame(player) then
			for key in keys do
				s.seq += 1
				local ok, err = pcall(function()
					Net.fire("Data.Key", player, key, TableUtil.deepCopy(data[key]), s.seq)
				end)
				if not ok then
					warn(("[DataService] replicating %s to %s failed: %s"):format(key, player.Name, tostring(err)))
				end
			end
		end
	end
end

local function autosaveTick()
	local now = os.clock()
	local budgetChecked, budget = false, 0
	for _, s in sessions do
		if
			s.state == "active"
			and not s.dead
			and not s.leaving
			and not s.closing
			and not s.saving
			and now >= s.nextAutosave
		then
			if not budgetChecked then
				budgetChecked, budget = true, updateBudget()
			end
			if budget < 2 then
				s.nextAutosave = now + 5 -- DataStore budget is exhausted; try again shortly
			else
				budget -= 1
				s.nextAutosave = now + AUTOSAVE_EVERY
				task.spawn(saveSession, s, "autosave", false, nil)
			end
		end
	end
end

local function onClose()
	shuttingDown = true
	local deadline = os.clock() + SHUTDOWN_BUDGET
	shutdownDeadline = deadline
	for _, s in sessions do
		if s.state ~= "closed" then
			s.closing = true
			s.leftSignal:Fire()
		end
	end
	while os.clock() < deadline do
		local pending = false
		for _, s in sessions do
			if s.state ~= "closed" then
				pending = true
				break
			end
		end
		if not pending then
			break
		end
		task.wait(0.1)
	end
end

---------------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------------
function DataService:Get(player: Player): Data?
	local s = sessions[player]
	return if s then s.data else nil
end

function DataService:IsLoaded(player: Player): boolean
	local s = sessions[player]
	return s ~= nil and s.data ~= nil
end

function DataService:WaitFor(player: Player, timeout: number?): Data?
	local s = ensureSession(player)
	if not s then
		return nil
	end
	if s.data ~= nil or s.state == "closed" then
		return s.data
	end
	waitSignal(s.loadedSignal, timeout or 60)
	return s.data
end

function DataService:Replicate(player: Player, key: string)
	if type(key) ~= "string" then
		return
	end
	if HIDDEN[key] then
		if not warnedPrivate[key] then
			warnedPrivate[key] = true
			warn(("[DataService] Replicate('%s') ignored: private keys never replicate"):format(key))
		end
		return
	end
	local s = sessions[player]
	if not s or s.data == nil or s.state == "closed" then
		return
	end
	local set = dirty[player]
	if not set then
		set = {}
		dirty[player] = set
	end
	set[key] = true
end

function DataService:Save(player: Player, reason: string?): boolean
	local s = sessions[player]
	if not s or s.state ~= "active" then
		return false
	end
	return saveSession(s, reason or "manual", false, nil)
end

function DataService:Audit(target: Player | number, kind: string, details: { [string]: any }?)
	local auditService = Registry.get("AuditService")
	if auditService then
		auditService:Record(target, kind, details)
		return
	end
	local player = if typeof(target) == "number" then Players:GetPlayerByUserId(target) else target
	local data = if player then self:Get(player) else nil
	local entry = DataUtil.auditEntry(Time.now(), kind, details)
	if data and entry then
		if type(data.audit) ~= "table" then
			data.audit = {}
		end
		DataUtil.pushRing(data.audit, entry, AUDIT_RING)
	end
end

function DataService:SetGlobal(key: string, value: any)
	globals[key] = value
	globalSeq += 1
	local ok, err = pcall(function()
		Net.fireAll("Data.Global", key, value, globalSeq)
	end)
	if not ok then
		warn(("[DataService] replicating global %s failed: %s"):format(key, tostring(err)))
	end
end

function DataService:GetGlobal(key: string): any
	return globals[key]
end

-- DataStore (or the Studio mock) by name, for other server code that persists to its own store.
-- Yields until the backend has been detected.
function DataService:GetStore(name: string): any
	return getStore(name)
end

function DataService:IsMock(): boolean
	waitBackend()
	return backendMode == "mock"
end

-- Number of sessions that have not finished their final save yet (used by shutdown coordination).
function DataService:OpenSessions(): number
	local n = 0
	for _, s in sessions do
		if s.state ~= "closed" then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------------------------------------------
-- Support tools (server-only; no remote exposes these). Run from the command bar or an admin script.
---------------------------------------------------------------------------------------------------
local function validUserId(userId: any): number?
	if type(userId) == "number" and userId > 0 and userId == math.floor(userId) then
		return userId
	end
	return nil
end

local function validSlot(slot: any): (number | string)?
	if slot == "pre" then
		return slot
	end
	if type(slot) == "number" and slot >= 1 and slot <= BACKUP_SLOTS and slot == math.floor(slot) then
		return slot
	end
	return nil
end

-- Lists the rolling backups (slots 1..3) plus "pre" (the save as it was before the latest restore).
function DataService:AdminListBackups(userId: number): { { [string]: any } }
	local id = validUserId(userId)
	assert(id, "AdminListBackups: userId must be a positive integer")
	local store = getStore(BACKUP_STORE)
	local out: { { [string]: any } } = {}
	local slots: { number | string } = { "pre" }
	for i = 1, BACKUP_SLOTS do
		table.insert(slots, i)
	end
	for _, slot in slots do
		local ok, value = getWithRetry(store, backupKey(id, slot), 2)
		if not ok then
			table.insert(out, { slot = slot, error = value })
		else
			local summary = DataUtil.backupSummary(slot, value)
			if summary then
				table.insert(out, summary)
			end
		end
	end
	table.sort(out, function(a, b)
		return (tonumber(a.savedAt) or 0) > (tonumber(b.savedAt) or 0)
	end)
	return out
end

-- Restores a backup slot (1..3 or "pre") over the player's save. The current save is first copied to "pre".
-- Refused while the player is online in another server. If they're in this server they're kicked afterwards
-- so every service reloads the restored profile. Returns (ok, message).
function DataService:AdminRestore(userId: number, slot: number | string): (boolean, string)
	local id = validUserId(userId)
	if not id then
		return false, "userId must be a positive integer"
	end
	local which = validSlot(slot)
	if not which then
		return false, ('slot must be 1..%d or "pre"'):format(BACKUP_SLOTS)
	end
	local backupStore = getStore(BACKUP_STORE)
	local profileStore = getStore(PROFILE_STORE)
	local okBackup, backup = getWithRetry(backupStore, backupKey(id, which), 3)
	if not okBackup then
		return false, "could not read the backup: " .. tostring(backup)
	end
	if type(backup) ~= "table" or type(backup.data) ~= "table" then
		return false, "no backup in slot " .. tostring(which)
	end
	local _, _, migrateStatus, migrateErr = Migrations.run(TableUtil.deepCopy(backup.data))
	if migrateStatus ~= "ok" then
		return false, "backup cannot be loaded by this build: " .. tostring(migrateErr or migrateStatus)
	end

	local mine = byUser[id]
	if mine and mine.state == "loading" then
		return false, "the player is still loading in this server; try again in a few seconds"
	end
	local own = mine ~= nil and mine.state == "active" and not mine.dead
	if own and mine then
		acquireSaveLock(mine) -- let any in-flight save finish, then stop all further saves
		mine.dead = "restored"
		releaseSaveLock(mine)
	end
	local function undo()
		if own and mine and mine.dead == "restored" then
			mine.dead = nil
		end
	end

	local okCurrent, raw = getWithRetry(profileStore, profileKey(id), 3)
	if not okCurrent then
		undo()
		return false, "could not read the current save: " .. tostring(raw)
	end
	local current = SessionLock.normalize(raw)
	if current and SessionLock.heldElsewhere(current, Time.now(), JOB_ID, STEAL_PREFIX) then
		undo()
		local s = current.session
		return false,
			("the player is online in another server (%s); try after they leave"):format(tostring(s and s.jobId))
	end
	if which ~= "pre" and current and current.data then
		local pre = DataUtil.backupRecord(current.data, Time.now(), "pre", "prerestore")
		local okPre, errPre = updateWithRetry(backupStore, backupKey(id, "pre"), function()
			return pre
		end, 3)
		if not okPre then
			undo()
			return false, "could not keep an undo copy of the current save: " .. tostring(errPre)
		end
	end

	local refused = false
	local okWrite, errWrite = updateWithRetry(profileStore, profileKey(id), function(rawNow)
		local now = Time.now()
		local note = { t = math.floor(now), kind = "restore", d = { slot = which, savedAt = backup.savedAt } }
		local status, rec = SessionLock.restore(rawNow, now, JOB_ID, backup.data, note, AUDIT_RING, STEAL_PREFIX)
		refused = status ~= "ok"
		return rec
	end, 3)
	if not okWrite then
		undo()
		return false, "could not write the restored save: " .. tostring(errWrite)
	end
	if refused then
		undo()
		return false, "the player joined another server during the restore; try again after they leave"
	end
	if own and mine then
		mine.lockHeld = false
		kick(mine.player, "restored")
	end
	audit(id, "restore", { slot = which, savedAt = backup.savedAt })
	return true, ("restored slot %s (saved at %s)"):format(tostring(which), tostring(backup.savedAt))
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function DataService:Init()
	Net.declare("Data.Key")
	Net.declare("Data.Global")
	Net.handle("Data.Snapshot", function(player: Player)
		local data = DataService:WaitFor(player, SNAPSHOT_WAIT)
		local s = sessions[player]
		if data == nil or s == nil then
			return nil, "not_loaded"
		end
		return {
			player = DataUtil.filterPrivate(data, HIDDEN),
			global = globals,
			seq = s.seq,
			gseq = globalSeq,
		}
	end, { rate = 1, burst = 6 })

	Players.PlayerAdded:Connect(function(player)
		ensureSession(player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		ensureSession(player)
	end
	game:BindToClose(onClose)
	-- Detect the backend as soon as Init returns (not in Start), so a GetStore / IsMock / WaitFor call made from
	-- another service's Init can never wait on a detection that only starts after every Init has finished.
	task.defer(detectBackend)
end

function DataService:Start()
	task.spawn(function()
		while true do
			task.wait(FLUSH_EVERY)
			local ok, err = pcall(function()
				flushDirty()
			end)
			if not ok then
				warn("[DataService] replication flush failed: " .. tostring(err))
			end
		end
	end)
	detectBackend() -- no-op when the deferred detection from Init is already running
	while not shuttingDown do
		task.wait(1)
		local ok, err = pcall(function()
			autosaveTick()
		end)
		if not ok then
			warn("[DataService] autosave tick failed: " .. tostring(err))
		end
	end
end

return DataService
