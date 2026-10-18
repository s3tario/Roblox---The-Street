--!strict
-- WorkService/Deps (server, runtime only): guarded access to every other feature work talks to. Each call goes
-- through Registry.get plus pcall, so a missing or erroring feature never breaks work; failures are logged once
-- per service method.
--
--   Deps.call(service, method, ...) -> (ok, result)       (false, nil) when missing or erroring
--   Deps.has(service, method) -> boolean
--   Deps.connect(service, signal, fn) -> boolean          another service's Signal (Connect)
--   Deps.data(player) -> data?                             DataService:Get
--   Deps.replicate(player, key)   Deps.notify(player, text, kind?)   Deps.audit(player, kind, details?)
--   Deps.num(x, default) -> number   Deps.require(inst?) -> module?   (pcall require, nil on failure)

local Registry = require(script.Parent.Parent.Parent.Registry)

local Deps = {}

local warned: { [string]: boolean } = {}

local function warnOnce(key: string, err: any)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(("[WorkService] %s failed: %s"):format(key, tostring(err)))
end
Deps.warnOnce = warnOnce

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

function Deps.connect(serviceName: string, signalName: string, fn: (...any) -> ()): boolean
	local svc = Registry.get(serviceName)
	if type(svc) ~= "table" then
		return false
	end
	local sig = svc[signalName]
	if type(sig) ~= "table" or type(sig.Connect) ~= "function" then
		return false
	end
	local ok, err = pcall(function()
		sig:Connect(function(...)
			local okInner, errInner = pcall(fn :: any, ...)
			if not okInner then
				warnOnce(serviceName .. "." .. signalName .. " handler", errInner)
			end
		end)
	end)
	if not ok then
		warnOnce(serviceName .. "." .. signalName, err)
	end
	return ok
end

function Deps.num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function Deps.data(player: Player): { [string]: any }?
	local ok, data = Deps.call("DataService", "Get", player)
	if ok and type(data) == "table" then
		return data
	end
	return nil
end

function Deps.replicate(player: Player, key: string)
	Deps.call("DataService", "Replicate", player, key)
end

function Deps.notify(player: Player, text: string, kind: string?)
	Deps.call("NotifyService", "Notify", player, text, kind)
end

function Deps.audit(player: Player, kind: string, details: { [string]: any }?)
	-- DataService:Audit forwards to AuditService when it exists, else keeps the player's audit ring itself
	Deps.call("DataService", "Audit", player, kind, details)
end

function Deps.require(inst: Instance?): any
	if inst == nil or not inst:IsA("ModuleScript") then
		return nil
	end
	local ok, mod = pcall(require, inst :: ModuleScript)
	if ok then
		return mod
	end
	warnOnce("require " .. inst:GetFullName(), mod)
	return nil
end

return Deps
