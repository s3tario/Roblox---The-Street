--!strict
-- Remote registry. See docs/contracts.md §2.
-- Server: Net.on / Net.handle / Net.fire / Net.fireAll / Net.fireList / Net.fireUnreliable / Net.fireAllUnreliable
-- Client: Net.send / Net.invoke / Net.listen
-- Remotes are created lazily by the server under ReplicatedStorage.Remotes.{E,F,U}.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local IS_SERVER = RunService:IsServer()
local INVOKE_TIMEOUT = 15
local WAIT_TIMEOUT = 30

local Net = {}

-- Optional hook set by AntiCheatService: function(player, remoteName)
Net.onRateLimited = nil :: ((Player, string) -> ())?

local KIND_FOLDER = { RemoteEvent = "E", RemoteFunction = "F", UnreliableRemoteEvent = "U" }

local root: Folder? = nil
local function getRoot(): Folder
	local existing = root
	if existing then
		return existing
	end
	local found: Folder
	if IS_SERVER then
		local r = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
		if r then
			found = r
		else
			local created = Instance.new("Folder")
			created.Name = "Remotes"
			for _, sub in { "E", "F", "U" } do
				local f = Instance.new("Folder")
				f.Name = sub
				f.Parent = created
			end
			created.Parent = ReplicatedStorage
			found = created
		end
	else
		found = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	root = found
	return found
end

local cache: { [string]: Instance } = {}

local function getRemote(name: string, className: string, wait: boolean?): Instance?
	local key = className .. "|" .. name
	local cached = cache[key]
	if cached then
		return cached
	end
	local folder = getRoot():WaitForChild(KIND_FOLDER[className]) :: Folder
	local inst = folder:FindFirstChild(name)
	if not inst then
		if IS_SERVER then
			local created = Instance.new(className)
			created.Name = name
			created.Parent = folder
			inst = created
		elseif wait then
			inst = folder:WaitForChild(name, WAIT_TIMEOUT)
			if not inst then
				warn(("[Net] remote %s (%s) did not appear within %ds"):format(name, className, WAIT_TIMEOUT))
				return nil
			end
		else
			return nil
		end
	end
	cache[key] = inst :: Instance
	return inst
end

---------------------------------------------------------------------------------------------------
-- Rate limiting (token bucket per player per remote)
---------------------------------------------------------------------------------------------------
type Bucket = { tokens: number, last: number }
local buckets: { [Player]: { [string]: Bucket } } = {}

if IS_SERVER then
	Players.PlayerRemoving:Connect(function(p)
		buckets[p] = nil
	end)
end

local function allow(player: Player, name: string, rate: number, burst: number): boolean
	local per = buckets[player]
	if not per then
		per = {}
		buckets[player] = per
	end
	local now = os.clock()
	local b = per[name]
	if not b then
		b = { tokens = burst, last = now }
		per[name] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.last) * rate)
	b.last = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	local hook = Net.onRateLimited
	if hook then
		task.spawn(hook, player, name)
	end
	return false
end

type Opts = { rate: number?, burst: number? }

local function limits(opts: Opts?): (number, number)
	local rate = (opts and opts.rate) or 8
	local burst = (opts and opts.burst) or rate * 3
	return rate, burst
end

---------------------------------------------------------------------------------------------------
-- Server API
---------------------------------------------------------------------------------------------------
function Net.on(name: string, handler: (Player, ...any) -> (), opts: Opts?)
	assert(IS_SERVER, "Net.on is server-only")
	local remote = getRemote(name, "RemoteEvent") :: RemoteEvent
	local rate, burst = limits(opts)
	remote.OnServerEvent:Connect(function(player, ...)
		if not allow(player, name, rate, burst) then
			return
		end
		local ok, err = pcall(handler :: any, player, ...)
		if not ok then
			warn(("[Net] handler %s errored for %s: %s"):format(name, player.Name, tostring(err)))
		end
	end)
end

function Net.handle(name: string, handler: (Player, ...any) -> ...any, opts: Opts?)
	assert(IS_SERVER, "Net.handle is server-only")
	local remote = getRemote(name, "RemoteFunction") :: RemoteFunction
	local rate, burst = limits(opts)
	remote.OnServerInvoke = (
		function(player: Player, ...: any): ...any
			if not allow(player, name, rate, burst) then
				return nil, "rate_limited"
			end
			local results = table.pack(pcall(handler, player, ...))
			if not results[1] then
				warn(("[Net] function %s errored for %s: %s"):format(name, player.Name, tostring(results[2])))
				return nil, "error"
			end
			return table.unpack(results, 2, results.n)
		end
	) :: any
end

-- Pre-create a server->client remote so clients can connect before the first fire.
function Net.declare(name: string, kind: ("event" | "unreliable")?)
	assert(IS_SERVER, "Net.declare is server-only")
	getRemote(name, if kind == "unreliable" then "UnreliableRemoteEvent" else "RemoteEvent")
end

function Net.fire(name: string, player: Player, ...: any)
	assert(IS_SERVER, "Net.fire is server-only");
	(getRemote(name, "RemoteEvent") :: RemoteEvent):FireClient(player, ...)
end

function Net.fireAll(name: string, ...: any)
	assert(IS_SERVER, "Net.fireAll is server-only");
	(getRemote(name, "RemoteEvent") :: RemoteEvent):FireAllClients(...)
end

function Net.fireList(name: string, players: { Player }, ...: any)
	assert(IS_SERVER, "Net.fireList is server-only")
	local remote = getRemote(name, "RemoteEvent") :: RemoteEvent
	for _, p in players do
		remote:FireClient(p, ...)
	end
end

function Net.fireUnreliable(name: string, player: Player, ...: any)
	assert(IS_SERVER, "Net.fireUnreliable is server-only");
	(getRemote(name, "UnreliableRemoteEvent") :: UnreliableRemoteEvent):FireClient(player, ...)
end

function Net.fireAllUnreliable(name: string, ...: any)
	assert(IS_SERVER, "Net.fireAllUnreliable is server-only");
	(getRemote(name, "UnreliableRemoteEvent") :: UnreliableRemoteEvent):FireAllClients(...)
end

---------------------------------------------------------------------------------------------------
-- Client API
---------------------------------------------------------------------------------------------------
function Net.send(name: string, ...: any)
	assert(not IS_SERVER, "Net.send is client-only")
	local remote = getRemote(name, "RemoteEvent", true) :: RemoteEvent?
	if remote then
		remote:FireServer(...)
	end
end

function Net.invoke(name: string, ...: any): ...any
	assert(not IS_SERVER, "Net.invoke is client-only")
	local remote = getRemote(name, "RemoteFunction", true) :: RemoteFunction?
	if not remote then
		return nil, "missing"
	end
	local args = table.pack(...)
	local done = false
	local results: { [number]: any, n: number } = { n = 0 }
	local caller = coroutine.running()
	local timedOut = false
	task.spawn(function()
		results = table.pack(pcall(remote.InvokeServer, remote, table.unpack(args, 1, args.n)))
		done = true
		if not timedOut and coroutine.status(caller) == "suspended" then
			task.spawn(caller)
		end
	end)
	if not done then
		task.delay(INVOKE_TIMEOUT, function()
			if not done then
				timedOut = true
				task.spawn(caller)
			end
		end)
		coroutine.yield()
	end
	if not done then
		return nil, "timeout"
	end
	if not results[1] then
		return nil, "error"
	end
	return table.unpack(results, 2, results.n)
end

-- Non-blocking: connects as soon as the remote exists. Returns an object with :Disconnect().
function Net.listen(name: string, handler: (...any) -> (), unreliable: boolean?): any
	assert(not IS_SERVER, "Net.listen is client-only")
	local handle = { _conn = nil :: RBXScriptConnection?, _dead = false }
	function handle:Disconnect()
		self._dead = true
		if self._conn then
			self._conn:Disconnect()
		end
	end
	task.spawn(function()
		local className = if unreliable then "UnreliableRemoteEvent" else "RemoteEvent"
		local folder = getRoot():WaitForChild(KIND_FOLDER[className]) :: Folder
		-- Effectively no timeout (server may create it on first fire); explicit value silences the infinite-yield warning.
		local inst = folder:WaitForChild(name, 1e9)
		if handle._dead then
			return
		end
		handle._conn = (inst :: any).OnClientEvent:Connect(handler)
	end)
	return handle
end

return Net
