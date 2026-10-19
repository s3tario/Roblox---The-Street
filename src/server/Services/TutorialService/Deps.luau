--!strict
-- TutorialService/Deps (server, runtime only): guarded access to every feature the tutorial talks to, shared by the
-- six tutorial services (TutorialService, QuestService, NpcService, DialogueService, SocialService,
-- AchievementService). Each call goes through Registry.get plus pcall, so a missing or erroring feature never breaks
-- ours; failures are logged once per service method.
--
--   Deps.call(service, method, ...) -> (ok, result)        (false, nil) when missing or erroring
--   Deps.call2(service, method, ...) -> (ok, a, b)
--   Deps.has(service, method) -> boolean
--   Deps.connect(service, signal, fn) -> boolean           another service's Signal / RBXScriptSignal
--   Deps.data(player) -> data?        Deps.campus(player) -> campus? (normalized)   Deps.career(player) -> career?
--   Deps.replicate(player, key)       Deps.audit(player, kind, details)
--   Deps.notify(player, text, kind?)  Deps.banner(player, opts)
--   Deps.isLive(player) -> boolean    Deps.root(player) -> BasePart?      Deps.distance(a, b) -> number
--   Deps.isEmployeeOf(player, companyId) -> boolean        Deps.activeSeconds(player) -> number
--   Deps.num(x, default) -> number    Deps.warnOnce(key, err)

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local QuestLine = require(Shared.Logic.QuestLine)
local Registry = require(script.Parent.Parent.Parent.Registry)

local Deps = {}

local warned: { [string]: boolean } = {}

function Deps.warnOnce(key: string, err: any)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(("[Tutorial] %s failed: %s"):format(key, tostring(err)))
end

function Deps.num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
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
	local ok, result = pcall(fn, svc, ...)
	if not ok then
		Deps.warnOnce(serviceName .. ":" .. name, result)
		return false, nil
	end
	return true, result
end

function Deps.call2(serviceName: string, name: string, ...: any): (boolean, any, any)
	local svc, fn = method(serviceName, name)
	if not svc then
		return false, nil, nil
	end
	local ok, a, b = pcall(fn, svc, ...)
	if not ok then
		Deps.warnOnce(serviceName .. ":" .. name, a)
		return false, nil, nil
	end
	return true, a, b
end

function Deps.connect(serviceName: string, signalName: string, fn: (...any) -> ()): boolean
	local svc = Registry.get(serviceName)
	if type(svc) ~= "table" then
		return false
	end
	local signal = svc[signalName]
	if signal == nil then
		return false
	end
	local ok, err = pcall(function()
		signal:Connect(function(...)
			local args = table.pack(...)
			local okRun, runErr = pcall(function()
				fn(table.unpack(args, 1, args.n))
			end)
			if not okRun then
				Deps.warnOnce(serviceName .. "." .. signalName .. " handler", runErr)
			end
		end)
	end)
	if not ok then
		Deps.warnOnce(serviceName .. "." .. signalName, err)
		return false
	end
	return true
end

function Deps.isLive(player: any): boolean
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end

function Deps.data(player: Player): { [string]: any }?
	local ok, data = Deps.call("DataService", "Get", player)
	if ok and type(data) == "table" then
		return data
	end
	return nil
end

function Deps.campus(player: Player): { [string]: any }?
	local data = Deps.data(player)
	if not data then
		return nil
	end
	if type(data.campus) ~= "table" then
		data.campus = {}
	end
	return QuestLine.normalize(data.campus)
end

function Deps.career(player: Player): { [string]: any }?
	local data = Deps.data(player)
	return if data and type(data.career) == "table" then data.career else nil
end

function Deps.replicate(player: Player, key: string)
	Deps.call("DataService", "Replicate", player, key)
end

function Deps.audit(player: Player, kind: string, details: { [string]: any }?)
	Deps.call("DataService", "Audit", player, kind, details)
end

function Deps.notify(player: Player, text: string, kind: string?)
	if Deps.isLive(player) then
		Deps.call("NotifyService", "Notify", player, text, kind)
	end
end

function Deps.banner(player: Player?, opts: { title: string, subtitle: string?, style: string?, duration: number? })
	Deps.call("NotifyService", "Banner", player, opts)
end

function Deps.root(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	local primary = character.PrimaryPart
	return primary
end

function Deps.distance(a: Vector3, b: Vector3): number
	return (a - b).Magnitude
end

function Deps.isEmployeeOf(player: Player, companyId: string): boolean
	local ok, result = Deps.call("CareerService", "IsEmployeeOf", player, companyId)
	return ok and result == true
end

function Deps.activeSeconds(player: Player): number
	local ok, v = Deps.call("ActivityService", "GetActiveSeconds", player)
	if ok and type(v) == "number" and v == v then
		return v
	end
	return 0
end

return Deps
