--!strict
-- WardrobeService: guarded access to the other features it talks to (RUNTIME ONLY, server). Every call goes through
-- Registry.get plus pcall, so a missing or erroring feature never breaks the wardrobe; each failure is logged once.
--
--   Deps.data(player) -> data?                 DataService:Get
--   Deps.waitFor(player, timeout)              DataService:WaitFor (yields)
--   Deps.isLoaded(player) -> boolean
--   Deps.replicate(player, key)                DataService:Replicate
--   Deps.audit(player, kind, details)          DataService:Audit
--   Deps.notify(player, text, kind?)           NotifyService:Notify
--   Deps.rank(player) -> number                CareerService:GetRank, else data.career.rank, else 0
--   Deps.company(player) -> CompanyDef?        CareerService:GetCompany (contracts §5; nil when not employed)
--   Deps.companyLogo(player) -> logoId?, monogram?   the logo a vest / quarter-zip shows (v3 §16)
--   Deps.isEmployeeOf(player, companyId) -> boolean  CareerService:IsEmployeeOf (false when career is missing)
--   Deps.ownsPass(player, passKey) -> boolean  MonetizationService:OwnsPass, falling back to saved entitlements
--   Deps.connect(serviceName, signalName, fn) -> boolean   connects to another service's Signal if it exists

local Registry = require(script.Parent.Parent.Parent.Registry)

local Deps = {}

local warned: { [string]: boolean } = {}

local function warnOnce(key: string, err: any)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(("[WardrobeService] %s failed: %s"):format(key, tostring(err)))
end

-- service:method(...) guarded. Returns (true, firstResult) on success, (false, nil) when the service or method is
-- missing or the call errored.
local function call(serviceName: string, method: string, ...: any): (boolean, any)
	local svc = Registry.get(serviceName)
	if type(svc) ~= "table" then
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
		warnOnce(serviceName .. ":" .. method, result)
		return false, nil
	end
	return true, result
end
Deps.call = call

---------------------------------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------------------------------
function Deps.data(player: Player): { [string]: any }?
	local ok, data = call("DataService", "Get", player)
	return if ok and type(data) == "table" then data else nil
end

function Deps.waitFor(player: Player, timeout: number)
	call("DataService", "WaitFor", player, timeout)
end

function Deps.isLoaded(player: Player): boolean
	local ok, loaded = call("DataService", "IsLoaded", player)
	return ok and loaded == true
end

function Deps.replicate(player: Player, key: string)
	call("DataService", "Replicate", player, key)
end

function Deps.audit(player: Player, kind: string, details: { [string]: any })
	call("DataService", "Audit", player, kind, details)
end

---------------------------------------------------------------------------------------------------
-- Notify
---------------------------------------------------------------------------------------------------
function Deps.notify(player: Player, text: string, kind: string?)
	call("NotifyService", "Notify", player, text, kind)
end

---------------------------------------------------------------------------------------------------
-- Career (careerPath)
---------------------------------------------------------------------------------------------------
function Deps.rank(player: Player): number
	local ok, r = call("CareerService", "GetRank", player)
	if ok and type(r) == "number" and r == r then
		return r
	end
	local data = Deps.data(player)
	local career = if data then data.career else nil
	local saved = if type(career) == "table" then tonumber(career.rank) else nil
	return if saved and saved == saved then saved else 0
end

function Deps.company(player: Player): { [string]: any }?
	local ok, company = call("CareerService", "GetCompany", player)
	return if ok and type(company) == "table" then company else nil
end

-- The company logo for the left-chest emblem: the company's logo id (contracts §16: logo = company id) and a
-- short monogram for the fallback drawing. nil when the player has no company.
function Deps.companyLogo(player: Player): (string?, string?)
	local company = Deps.company(player)
	if not company then
		return nil, nil
	end
	local logo = company.logo
	if type(logo) ~= "string" or logo == "" then
		logo = if type(company.id) == "string" and company.id ~= "" then company.id else nil
	end
	local short = company.short
	local monogram = if type(short) == "string" and #short >= 1 and #short <= 4 then short else nil
	return logo, monogram
end

function Deps.isEmployeeOf(player: Player, companyId: string): boolean
	local ok, yes = call("CareerService", "IsEmployeeOf", player, companyId)
	return ok and yes == true
end

---------------------------------------------------------------------------------------------------
-- Passes (monetization)
---------------------------------------------------------------------------------------------------
function Deps.ownsPass(player: Player, passKey: string): boolean
	local ok, owns = call("MonetizationService", "OwnsPass", player, passKey)
	if ok and owns == true then
		return true
	end
	local data = Deps.data(player)
	local ent = if data then data.entitlements else nil
	local saved = if type(ent) == "table" then ent.passes else nil
	if type(saved) == "table" then
		return saved[passKey] == true or table.find(saved, passKey) ~= nil
	end
	return false
end

---------------------------------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------------------------------
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
				warn(("[WardrobeService] %s.%s handler failed: %s"):format(serviceName, signalName, tostring(problem)))
			end
		end)
	end)
	if not ok then
		warnOnce(serviceName .. "." .. signalName, err)
	end
	return ok
end

return Deps
