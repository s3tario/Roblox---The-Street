--!strict
-- CareerService/Deps (server, runtime only): guarded access to every other feature careerPath talks to. Each call
-- goes through Registry.get plus pcall, so a missing or erroring feature never breaks the career; failures are
-- logged once per service method. ReviewService and ActivityService use this module too.
--
--   Deps.call(service, method, ...) -> (ok, result)       (false, nil) when missing or erroring
--   Deps.call2(service, method, ...) -> (ok, a, b)        two results
--   Deps.has(service, method) -> boolean
--   Deps.connect(service, signal, fn) -> boolean          connects to another service's Signal / RBXScriptSignal
--   Deps.data(player) -> data?   Deps.career(player) -> career?   Deps.waitFor(player, timeout)
--   Deps.replicate(player, key)  Deps.save(player, reason)  Deps.audit(player, kind, details)
--   Deps.notify(player, text, kind?)  Deps.banner(player, opts)  Deps.ticker(text)
--   Deps.objective(player, text?)  Quest objective (QuestService, else the Career.Objective remote)
--   Deps.activeSeconds(player) -> number                 ActivityService:GetActiveSeconds (0 when missing)
--   Deps.isLive(player) -> boolean                        still in the game

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Parent.Registry)

local Deps = {}

Deps.QUEST_ID = "career"
Deps.OBJECTIVE_REMOTE = "Career.Objective"

local warned: { [string]: boolean } = {}

local function warnOnce(key: string, err: any)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(("[CareerService] %s failed: %s"):format(key, tostring(err)))
end

local function method(serviceName: string, name: string): (any, any)
	local svc = Registry.get(serviceName)
	if type(svc) ~= "table" then
		return nil, nil
	end
	local fn = svc[name]
	if type(fn) ~= "function" then
		return nil, nil
	end
	return svc, fn
end

function Deps.has(serviceName: string, name: string): boolean
	local svc = method(serviceName, name)
	return svc ~= nil
end

function Deps.call(serviceName: string, name: string, ...: any): (boolean, any)
	local svc, fn = method(serviceName, name)
	if not svc then
		return false, nil
	end
	local args = table.pack(...)
	local ok, result = pcall(function()
		return fn(svc, table.unpack(args, 1, args.n))
	end)
	if not ok then
		warnOnce(serviceName .. ":" .. name, result)
		return false, nil
	end
	return true, result
end

function Deps.call2(serviceName: string, name: string, ...: any): (boolean, any, any)
	local svc, fn = method(serviceName, name)
	if not svc then
		return false, nil, nil
	end
	local args = table.pack(...)
	local results = table.pack(pcall(function()
		return fn(svc, table.unpack(args, 1, args.n))
	end))
	if not results[1] then
		warnOnce(serviceName .. ":" .. name, results[2])
		return false, nil, nil
	end
	return true, results[2], results[3]
end

function Deps.connect(serviceName: string, signalName: string, fn: (...any) -> ()): boolean
	local svc = Registry.get(serviceName)
	local sig = if type(svc) == "table" then svc[signalName] else nil
	if type(sig) ~= "table" and typeof(sig) ~= "RBXScriptSignal" then
		return false
	end
	local ok, err = pcall(function()
		(sig :: any):Connect(function(...: any)
			local args = table.pack(...)
			local fine, problem = pcall(function()
				fn(table.unpack(args, 1, args.n))
			end)
			if not fine then
				warn(("[CareerService] %s.%s handler failed: %s"):format(serviceName, signalName, tostring(problem)))
			end
		end)
	end)
	if not ok then
		warnOnce(serviceName .. "." .. signalName, err)
	end
	return ok
end

function Deps.isLive(player: any): boolean
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end

---------------------------------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------------------------------
function Deps.data(player: Player): { [string]: any }?
	local ok, data = Deps.call("DataService", "Get", player)
	return if ok and type(data) == "table" then data else nil
end

function Deps.career(player: Player): { [string]: any }?
	local data = Deps.data(player)
	local career = if data then data.career else nil
	return if type(career) == "table" then career else nil
end

function Deps.waitFor(player: Player, timeout: number)
	Deps.call("DataService", "WaitFor", player, timeout)
end

function Deps.isLoaded(player: Player): boolean
	local ok, loaded = Deps.call("DataService", "IsLoaded", player)
	return ok and loaded == true
end

function Deps.replicate(player: Player, key: string)
	Deps.call("DataService", "Replicate", player, key)
end

function Deps.save(player: Player, reason: string)
	task.spawn(function()
		Deps.call("DataService", "Save", player, reason)
	end)
end

function Deps.audit(player: Player, kind: string, details: { [string]: any }?)
	Deps.call("DataService", "Audit", player, kind, details or {})
end

function Deps.global(key: string): any
	local ok, v = Deps.call("DataService", "GetGlobal", key)
	return if ok then v else nil
end

---------------------------------------------------------------------------------------------------
-- Notifications and objectives
---------------------------------------------------------------------------------------------------
function Deps.notify(player: Player, text: string, kind: string?)
	Deps.call("NotifyService", "Notify", player, text, kind)
end

function Deps.banner(player: Player?, opts: { title: string, subtitle: string?, style: string?, duration: number? })
	Deps.call("NotifyService", "Banner", player, opts)
end

function Deps.ticker(text: string)
	Deps.call("NotifyService", "Ticker", text)
end

-- The tutorial owns the quest tracker; until it exists the objective goes straight to CareerController.
function Deps.objective(player: Player, text: string?)
	if not Deps.isLive(player) then
		return
	end
	local ok = Deps.call("QuestService", "SetObjective", player, Deps.QUEST_ID, text)
	if ok then
		return
	end
	pcall(Net.fire, Deps.OBJECTIVE_REMOTE, player, text or "")
end

---------------------------------------------------------------------------------------------------
-- Activity
---------------------------------------------------------------------------------------------------
function Deps.activeSeconds(player: Player): number
	local ok, v = Deps.call("ActivityService", "GetActiveSeconds", player)
	if ok and type(v) == "number" and v == v then
		return v
	end
	local data = Deps.data(player)
	local meta = if data then data.meta else nil
	local saved = if type(meta) == "table" then meta.activeSec else nil
	return if type(saved) == "number" and saved == saved then saved else 0
end

return Deps
