--!strict
-- Store: the client's read-only mirror of its replicated player data and global state (docs/contracts.md §2).
--   Store:Get(key) / Store:GetPath("campus.offer")      current value (nil until loaded); treat as read-only
--   Store:Changed(key) -> Signal(newValue)               fires on every update of that top-level key
--   Store:Wait(key, timeout?) -> value?                  yields until the key has a value (default 30 s)
--   Store:GetGlobal(key) / Store:GlobalChanged(key)      global keys (events, serverInfo)
--   Store.Loaded (Signal) / Store:IsLoaded()
-- Updates carry a per-player sequence number; the snapshot carries the sequence it was taken at, so updates
-- that arrive before the snapshot (or race it) are applied in the right order and never rolled back.

local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local DataUtil = require(Shared.Logic.DataUtil)

local Store = { Name = "Store", Priority = 1 }

Store.Loaded = Signal.new()

local DEFAULT_WAIT = 30

local data: { [string]: any } = {}
local dataSeq: { [string]: number } = {}
local globals: { [string]: any } = {}
local globalSeq: { [string]: number } = {}
local changed: { [string]: Signal.Signal } = {}
local globalChanged: { [string]: Signal.Signal } = {}
local loaded = false

local function signalFor(map: { [string]: Signal.Signal }, key: string): Signal.Signal
	local s = map[key]
	if not s then
		s = Signal.new()
		map[key] = s
	end
	return s
end

local function fire(map: { [string]: Signal.Signal }, key: string, value: any)
	local s = map[key]
	if s then
		s:Fire(value)
	end
end

local accept = DataUtil.acceptSeq

local function onKey(key: any, value: any, seq: any)
	if type(key) ~= "string" or not accept(dataSeq, key, seq) then
		return
	end
	data[key] = value
	if loaded then
		fire(changed, key, value)
	end
end

local function onGlobal(key: any, value: any, seq: any)
	if type(key) ~= "string" or not accept(globalSeq, key, seq) then
		return
	end
	globals[key] = value
	if loaded then
		fire(globalChanged, key, value)
	end
end

local function applySnapshot(snap: { [string]: any })
	local player = if type(snap.player) == "table" then snap.player else {}
	local global = if type(snap.global) == "table" then snap.global else {}
	local seq = if type(snap.seq) == "number" then snap.seq else 0
	local gseq = if type(snap.gseq) == "number" then snap.gseq else 0
	DataUtil.mergeSnapshot(data, dataSeq, player, seq)
	DataUtil.mergeSnapshot(globals, globalSeq, global, gseq)
	loaded = true
	-- Listeners connected before the load get every initial value.
	for key, value in data do
		fire(changed, key, value)
	end
	for key, value in globals do
		fire(globalChanged, key, value)
	end
	Store.Loaded:Fire()
end

---------------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------------
function Store:Get(key: string): any
	return data[key]
end

function Store:GetPath(path: string): any
	return DataUtil.getPath(data, path)
end

function Store:Changed(key: string): Signal.Signal
	return signalFor(changed, key)
end

function Store:GetGlobal(key: string): any
	return globals[key]
end

function Store:GlobalChanged(key: string): Signal.Signal
	return signalFor(globalChanged, key)
end

function Store:IsLoaded(): boolean
	return loaded
end

-- Yields until `key` has a value after the initial load, or `timeout` seconds pass (returns nil).
function Store:Wait(key: string, timeout: number?): any
	if loaded and data[key] ~= nil then
		return data[key]
	end
	local limit = timeout or DEFAULT_WAIT
	local thread = coroutine.running()
	local done = false
	local conns: { Signal.Connection } = {}
	local timer: thread? = nil
	local function stop()
		done = true
		for _, c in conns do
			c:Disconnect()
		end
		task.spawn(thread)
	end
	local function check()
		if done or not loaded or data[key] == nil then
			return
		end
		if timer then
			task.cancel(timer)
		end
		stop()
	end
	table.insert(conns, signalFor(changed, key):Connect(check))
	table.insert(conns, Store.Loaded:Connect(check))
	timer = task.delay(limit, function()
		if not done then
			stop()
		end
	end)
	coroutine.yield()
	if loaded then
		return data[key]
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function Store:Init()
	Net.listen("Data.Key", onKey)
	Net.listen("Data.Global", onGlobal)
end

function Store:Start()
	local attempt = 0
	while not loaded do
		attempt += 1
		local ok, snap, err = pcall(Net.invoke, "Data.Snapshot")
		if ok and type(snap) == "table" and type(snap.player) == "table" then
			applySnapshot(snap)
			break
		end
		if attempt == 1 or attempt % 10 == 0 then
			warn(("[Store] waiting for player data (%s)"):format(tostring(if ok then err or snap else snap)))
		end
		task.wait(math.min(attempt, 5))
	end
end

return Store
