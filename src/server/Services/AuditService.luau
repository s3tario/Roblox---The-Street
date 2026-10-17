--!strict
-- AuditService: support/anti-abuse evidence trail (docs/contracts.md §3, design §12-13).
--   * Every entry { t, kind, d } goes into the player's private profile ring `data.audit` (last 100).
--   * Severe kinds are also persisted to DataStore "Audit_v1", key "a_<userId>" (last 200), so they survive
--     profile restores and can be read while the player is offline. Writes are batched per user, flushed every
--     15 s (respecting the per-key write limit and the request budget) and on shutdown.
-- Entries recorded before the profile has loaded are held and appended once it loads.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local TableUtil = require(Shared.Util.TableUtil)
local Time = require(Shared.Util.Time)
local DataUtil = require(Shared.Logic.DataUtil)

local Registry = require(script.Parent.Parent.Registry)

export type Entry = DataUtil.AuditEntry

local AuditService = { Name = "AuditService", Priority = 2 }

AuditService.SEVERE = {
	purchase = true,
	wipeout = true,
	restore = true,
	lock_steal = true,
	flag = true,
	admin = true,
} :: { [string]: boolean }

local STORE_NAME = "Audit_v1"
local RING = 100 -- profile ring size
local STORE_KEEP = 200 -- entries kept per user in Audit_v1
local FLUSH_EVERY = 15
local MAX_PENDING = 50 -- per user between flushes; older ones are dropped (and counted)
local MAX_WRITES_PER_FLUSH = 20
local PRELOAD_MAX = 20
local SHUTDOWN_BUDGET = 20

local pending: { [number]: { Entry } } = {}
local dropped: { [number]: number } = {}
local preload: { [Player]: { Entry } } = {}
local flushing = false
local closing = false

local function dataService(): any
	return Registry.get("DataService")
end

local function storeKey(userId: number): string
	return "a_" .. tostring(userId)
end

local function appendToProfile(player: Player, entry: Entry)
	local ds = dataService()
	local data = if ds then ds:Get(player) else nil
	if data then
		if type(data.audit) ~= "table" then
			data.audit = {}
		end
		DataUtil.pushRing(data.audit, entry, RING)
	elseif player.Parent == Players then
		local list = preload[player]
		if not list then
			list = {}
			preload[player] = list
		end
		if #list < PRELOAD_MAX then
			table.insert(list, entry)
		end
	end
end

local function enqueue(userId: number, entry: Entry)
	local list = pending[userId]
	if not list then
		list = {}
		pending[userId] = list
	end
	table.insert(list, entry)
	while #list > MAX_PENDING do
		table.remove(list, 1)
		dropped[userId] = (dropped[userId] or 0) + 1
	end
end

local function budgetOk(): boolean
	local ds = dataService()
	if ds == nil or ds:IsMock() then
		return true
	end
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
	end)
	return not ok or type(budget) ~= "number" or budget >= 4
end

-- Write every user's pending batch (one UpdateAsync each). Without a deadline at most
-- MAX_WRITES_PER_FLUSH users are written; the rest wait for the next flush.
local function flush(deadline: number?)
	if flushing or next(pending) == nil then
		return
	end
	local ds = dataService()
	if ds == nil then
		return
	end
	flushing = true
	local ok, err = pcall(function()
		local store = ds:GetStore(STORE_NAME)
		local ids = {}
		for id in pending do
			table.insert(ids, id)
		end
		local writes = 0
		for _, id in ids do
			if deadline then
				if os.clock() >= deadline then
					break
				end
			elseif writes >= MAX_WRITES_PER_FLUSH or not budgetOk() then
				break
			end
			local batch = pending[id]
			pending[id] = nil
			local lost = dropped[id]
			dropped[id] = nil
			if batch and #batch > 0 then
				if lost then
					table.insert(batch, 1, { t = batch[1].t, kind = "audit_overflow", d = { dropped = lost } })
				end
				writes += 1
				local wrote, writeErr = pcall(function()
					store:UpdateAsync(storeKey(id), function(old)
						local out = {}
						if type(old) == "table" and (next(old) == nil or TableUtil.isArray(old)) then
							for _, e in old do
								table.insert(out, e)
							end
						end
						for _, e in batch do
							table.insert(out, e)
						end
						TableUtil.trimFront(out, STORE_KEEP)
						return out
					end)
				end)
				if not wrote then
					warn(("[AuditService] writing audit log for %d failed: %s"):format(id, tostring(writeErr)))
					-- put the batch back in front of anything recorded meanwhile
					local merged = batch
					local newer = pending[id]
					if newer then
						for _, e in newer do
							table.insert(merged, e)
						end
					end
					while #merged > MAX_PENDING do
						table.remove(merged, 1)
						dropped[id] = (dropped[id] or 0) + 1
					end
					pending[id] = merged
				end
			end
		end
	end)
	flushing = false
	if not ok then
		warn("[AuditService] flush failed: " .. tostring(err))
	end
end

---------------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------------
-- Record an audit entry for a player (or a userId, online or not). `details` is copied in a bounded,
-- saveable form (at most ~2 KB of JSON per entry). Never yields.
function AuditService:Record(target: Player | number, kind: string, details: { [string]: any }?)
	local entry: Entry? = DataUtil.auditEntry(Time.now(), kind, details)
	if entry == nil then
		return
	end
	local k = entry.kind
	local player: Player? = nil
	local userId: number? = nil
	if typeof(target) == "number" then
		if target > 0 and target == math.floor(target) then
			userId = target
			player = Players:GetPlayerByUserId(target)
		end
	elseif typeof(target) == "Instance" and target:IsA("Player") then
		player = target
		userId = target.UserId
	end
	if userId == nil then
		warn("[AuditService] Record: target must be a Player or a userId")
		return
	end
	if player then
		appendToProfile(player, entry)
	end
	if AuditService.SEVERE[k] then
		enqueue(userId, table.clone(entry :: Entry))
	end
end

-- Severe entries for a user, oldest first: what is stored in Audit_v1 plus anything not yet flushed.
-- Yields (DataStore read). The full profile ring is in DataService:Get(player).audit.
function AuditService:GetRecent(userId: number, limit: number?): { Entry }
	assert(type(userId) == "number" and userId > 0, "GetRecent: userId must be a positive number")
	local out: { Entry } = {}
	local ds = dataService()
	if ds then
		local store = ds:GetStore(STORE_NAME)
		local ok, value = pcall(function()
			return store:GetAsync(storeKey(userId))
		end)
		if not ok then
			warn(("[AuditService] reading audit log for %d failed: %s"):format(userId, tostring(value)))
		elseif type(value) == "table" then
			for _, e in value do
				table.insert(out, e)
			end
		end
	end
	local unflushed = pending[userId]
	if unflushed then
		for _, e in unflushed do
			table.insert(out, e)
		end
	end
	if limit then
		TableUtil.trimFront(out, limit)
	end
	return out
end

-- Write pending severe entries now (support tools; also runs on shutdown).
function AuditService:Flush()
	flush(os.clock() + SHUTDOWN_BUDGET)
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function AuditService:Init()
	local ds = dataService()
	if ds then
		ds.ProfileLoaded:Connect(function(player: Player, data: any)
			local held = preload[player]
			preload[player] = nil
			if held and type(data) == "table" then
				if type(data.audit) ~= "table" then
					data.audit = {}
				end
				for _, entry in held do
					DataUtil.pushRing(data.audit, entry, RING)
				end
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		preload[player] = nil
	end)
	game:BindToClose(function()
		closing = true
		local deadline = os.clock() + SHUTDOWN_BUDGET
		-- DataService's shutdown saves may still record entries (e.g. a lost lock), so keep flushing until
		-- they are done and nothing is pending.
		while os.clock() < deadline do
			flush(deadline)
			local data = dataService()
			local saving = if data then data:OpenSessions() else 0
			if next(pending) == nil and saving == 0 then
				break
			end
			task.wait(0.5)
		end
	end)
end

function AuditService:Start()
	while not closing do
		task.wait(FLUSH_EVERY)
		if not closing then
			flush(nil)
		end
	end
end

return AuditService
