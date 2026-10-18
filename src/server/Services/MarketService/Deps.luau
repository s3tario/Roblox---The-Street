--!strict
-- MarketService / PortfolioService: guarded access to other features (RUNTIME ONLY, server). Every call goes through
-- Registry.get plus pcall, so a missing or erroring feature never breaks the market; each failure is logged once.
--
--   Deps.call(service, method, ...) -> (ok, firstResult)     Deps.has(service, method) -> boolean
--   Deps.connect(service, signal, fn) -> boolean             Deps.data(player) / Deps.isLoaded(player)
--   Deps.replicate(player, key)   Deps.audit(player, kind, details)   Deps.setGlobal(key, value)
--   Deps.notify(player, text, kind?)   Deps.ticker(text)
--   Deps.isEmployeeOf(player, companyId) -> boolean   Deps.companyName(companyId) -> string?
--   Deps.rank(player) -> number   Deps.riskMult(player) -> number   Deps.riskHeadroom(player, data?) -> number
--   Deps.active(player) -> number?   Deps.submitBoard(player, boardId, value)   (spawned: may yield)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Registry = require(script.Parent.Parent.Parent.Registry)

local Deps = {}

local warned: { [string]: boolean } = {}

local function warnOnce(key: string, err: any)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(("[Market] %s failed: %s"):format(key, tostring(err)))
end

function Deps.service(name: string): any
	local svc = Registry.get(name)
	return if type(svc) == "table" then svc else nil
end

function Deps.has(name: string, method: string): boolean
	local svc = Deps.service(name)
	return svc ~= nil and type(svc[method]) == "function"
end

function Deps.call(name: string, method: string, ...: any): (boolean, any)
	local svc = Deps.service(name)
	if not svc then
		return false, nil
	end
	local fn = svc[method]
	if type(fn) ~= "function" then
		return false, nil
	end
	local args = table.pack(...)
	local ok, result = pcall(function()
		return fn(svc, table.unpack(args, 1, args.n))
	end)
	if not ok then
		warnOnce(name .. ":" .. method, result)
		return false, nil
	end
	return true, result
end

function Deps.connect(name: string, signalName: string, fn: (...any) -> ()): boolean
	local svc = Deps.service(name)
	local sig = if svc then svc[signalName] else nil
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
				warn(("[Market] %s.%s handler failed: %s"):format(name, signalName, tostring(problem)))
			end
		end)
	end)
	if not ok then
		warnOnce(name .. "." .. signalName, err)
	end
	return ok
end

---------------------------------------------------------------------------------------------------
-- Data, notifications
---------------------------------------------------------------------------------------------------
function Deps.data(player: Player): { [string]: any }?
	local ok, data = Deps.call("DataService", "Get", player)
	return if ok and type(data) == "table" then data else nil
end

function Deps.isLoaded(player: Player): boolean
	local ok, loaded = Deps.call("DataService", "IsLoaded", player)
	return ok and loaded == true
end

function Deps.replicate(player: Player, key: string)
	Deps.call("DataService", "Replicate", player, key)
end

function Deps.audit(player: Player, kind: string, details: { [string]: any })
	Deps.call("DataService", "Audit", player, kind, details)
end

function Deps.setGlobal(key: string, value: any)
	Deps.call("DataService", "SetGlobal", key, value)
end

function Deps.notify(player: Player, text: string, kind: string?)
	Deps.call("NotifyService", "Notify", player, text, kind)
end

function Deps.ticker(text: string)
	Deps.call("NotifyService", "Ticker", text)
end

---------------------------------------------------------------------------------------------------
-- Career (careerPath) and profile (careerCore)
---------------------------------------------------------------------------------------------------
function Deps.isEmployeeOf(player: Player, companyId: string): boolean
	local ok, yes = Deps.call("CareerService", "IsEmployeeOf", player, companyId)
	return ok and yes == true
end

local companies: any = false
function Deps.companyName(companyId: string?): string?
	if not companyId then
		return nil
	end
	if companies == false then
		companies = nil
		local config = Shared:FindFirstChild("Config")
		local mod = config and config:FindFirstChild("Companies")
		if mod and mod:IsA("ModuleScript") then
			local ok, res = pcall(require, mod)
			if ok and type(res) == "table" then
				companies = res
			end
		end
	end
	if companies and type(companies.get) == "function" then
		local ok, def = pcall(companies.get, companyId)
		if ok and type(def) == "table" and type(def.name) == "string" then
			return def.name
		end
	end
	return nil
end

local function careerOf(player: Player): { [string]: any }?
	local data = Deps.data(player)
	local career = if data then data.career else nil
	return if type(career) == "table" then career else nil
end

function Deps.rank(player: Player): number
	local ok, r = Deps.call("CareerService", "GetRank", player)
	if ok and type(r) == "number" and r == r then
		return math.max(0, math.floor(r))
	end
	local career = careerOf(player)
	local saved = if career then tonumber(career.rank) else nil
	return if saved and saved == saved then math.max(0, math.floor(saved)) else 0
end

function Deps.riskMult(player: Player): number
	local ok, m = Deps.call("CareerService", "GetRiskLimitMultiplier", player)
	if ok and type(m) == "number" and m == m and m > 0 then
		return m
	end
	local career = careerOf(player)
	return if career and career.status == "probation" then 0.6 else 1
end

-- Risk Sense headroom (careerCore Logic/Stats.riskHeadroom; 0 when that module is missing).
local stats: any = false
function Deps.riskHeadroom(player: Player, data: { [string]: any }?): number
	if stats == false then
		stats = nil
		local logic = Shared:FindFirstChild("Logic")
		local mod = logic and logic:FindFirstChild("Stats")
		if mod and mod:IsA("ModuleScript") then
			local ok, res = pcall(require, mod)
			if ok and type(res) == "table" and type(res.riskHeadroom) == "function" then
				stats = res
			end
		end
	end
	if not stats then
		return 0
	end
	local risk: any = nil
	local okStat, v = Deps.call("ProfileService", "GetStat", player, "risk")
	if okStat and type(v) == "number" then
		risk = v
	else
		local d = data or Deps.data(player)
		local profile = if d then d.profile else nil
		local s = if type(profile) == "table" then profile.stats else nil
		risk = if type(s) == "table" then s.risk else nil
	end
	if type(risk) ~= "number" then
		return 0
	end
	local ok, h = pcall(stats.riskHeadroom, risk)
	return if ok and type(h) == "number" and h == h then math.clamp(h, 0, 0.1) else 0
end

function Deps.weekStart(player: Player): number?
	local career = careerOf(player)
	local v = if career then career.weekStartActive else nil
	return if type(v) == "number" and v == v then v else nil
end

---------------------------------------------------------------------------------------------------
-- Activity and leaderboards
---------------------------------------------------------------------------------------------------
function Deps.active(player: Player): number?
	local ok, a = Deps.call("ActivityService", "GetActiveSeconds", player)
	if ok and type(a) == "number" and a == a then
		return a
	end
	return nil
end

function Deps.submitBoard(player: Player, boardId: string, value: number)
	if not Deps.has("LeaderboardService", "Submit") then
		return
	end
	task.spawn(function()
		Deps.call("LeaderboardService", "Submit", player, boardId, value)
	end)
end

return Deps
