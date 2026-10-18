--!strict
-- Shop feature: guarded access to the other features EconomyService, ShopService and HousingService talk to
-- (RUNTIME ONLY, server). Every call goes through Registry.get plus pcall, so a missing or erroring feature never
-- breaks the economy; each failure is logged once.
--
--   Deps.call(service, method, ...) -> (ok, result)     Deps.has(service, method) -> boolean
--   Deps.connect(service, signal, fn) -> boolean          connects to another service's Signal when it exists
--   Data:      Deps.data(player) / Deps.isLoaded(player) / Deps.waitFor(player, timeout) / Deps.replicate(player, key)
--              Deps.audit(player, kind, details) / Deps.save(player, reason)   (save yields: call it in a thread)
--   Notify:    Deps.notify(player, text, kind?)
--   Career:    Deps.career(player) -> CareerInfo   (CareerService getters, falling back to the saved career)
--              Deps.isEmployeeOf(player, companyId) -> boolean   Deps.outfitLevel(player) -> 1..5
--              Deps.plaques(player) -> { plaque }   the saved career.plaques ring
--   Profile:   Deps.displayName(player) -> string   "First Family" from the Life Roll, else the Roblox display name
--              Deps.incomeMult(player) -> number?   ProfileService:GetIncomeMult (rebirth multiplier)
--   Boosts:    Deps.dailyMult(player, kind) -> number?   DailyService:GetBoostMult(player, "money" | "xp")
--   Events:    Deps.modifier(name) -> number?   EventService:GetModifier      Deps.eventActive(id) -> boolean
--   Passes:    Deps.ownsPass(player, passKey) -> boolean   MonetizationService:OwnsPass (may yield), else entitlements

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Companies = require(Shared.Config.Companies)
local Tracks = require(Shared.Config.Tracks)
local Registry = require(script.Parent.Parent.Parent.Registry)

local Deps = {}

export type CareerInfo = {
	student: boolean,
	employed: boolean,
	status: string,
	rank: number,
	companyId: string?,
	companyName: string?,
	track: string?,
	title: string,
	minOutfitLevel: number?,
	office: boolean?,
}

local warned: { [string]: boolean } = {}

local function warnOnce(key: string, err: any)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(("[Shop] %s failed: %s"):format(key, tostring(err)))
end

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Deps.has(serviceName: string, method: string): boolean
	local svc = Registry.all()[serviceName]
	return type(svc) == "table" and type(svc[method]) == "function"
end

-- service:method(...) guarded: (true, firstResult) on success, (false, nil) when missing or erroring.
function Deps.call(serviceName: string, method: string, ...: any): (boolean, any)
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
local call = Deps.call

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
				warn(("[Shop] %s.%s handler failed: %s"):format(serviceName, signalName, tostring(problem)))
			end
		end)
	end)
	if not ok then
		warnOnce(serviceName .. "." .. signalName, err)
	end
	return ok
end

---------------------------------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------------------------------
function Deps.data(player: Player): { [string]: any }?
	local ok, data = call("DataService", "Get", player)
	return if ok and type(data) == "table" then data else nil
end

function Deps.isLoaded(player: Player): boolean
	local ok, loaded = call("DataService", "IsLoaded", player)
	return ok and loaded == true
end

function Deps.waitFor(player: Player, timeout: number): { [string]: any }?
	local ok, data = call("DataService", "WaitFor", player, timeout)
	return if ok and type(data) == "table" then data else nil
end

function Deps.replicate(player: Player, key: string)
	call("DataService", "Replicate", player, key)
end

function Deps.audit(player: Player, kind: string, details: { [string]: any })
	call("DataService", "Audit", player, kind, details)
end

function Deps.save(player: Player, reason: string)
	if player.Parent == Players then
		call("DataService", "Save", player, reason)
	end
end

---------------------------------------------------------------------------------------------------
-- Notify
---------------------------------------------------------------------------------------------------
function Deps.notify(player: Player, text: string, kind: string?)
	if player.Parent == Players then
		call("NotifyService", "Notify", player, text, kind)
	end
end

---------------------------------------------------------------------------------------------------
-- Career (careerPath)
---------------------------------------------------------------------------------------------------
local function savedCareer(player: Player): { [string]: any }
	local data = Deps.data(player)
	local career = if data then data.career else nil
	return if type(career) == "table" then career else {}
end

function Deps.career(player: Player): CareerInfo
	local saved = savedCareer(player)
	local okStatus, status = call("CareerService", "GetStatus", player)
	local st: string = if okStatus and type(status) == "string"
		then status
		elseif type(saved.status) == "string" then saved.status
		else "student"
	local okRank, rank = call("CareerService", "GetRank", player)
	local r: number = if okRank and finite(rank) then rank elseif finite(saved.rank) then saved.rank else 0
	local okEmp, employed = call("CareerService", "IsEmployed", player)
	local emp: boolean
	if okEmp and type(employed) == "boolean" then
		emp = employed
	else
		emp = st ~= "student" and st ~= "fired" and type(saved.companyId) == "string" and saved.companyId ~= ""
	end
	local companyId: string? = nil
	local companyName: string? = nil
	local minLevel: number? = nil
	if emp then
		local okCo, company = call("CareerService", "GetCompany", player)
		local co = if okCo and type(company) == "table" then company else nil
		if co == nil and type(saved.companyId) == "string" then
			co = Companies.get(saved.companyId)
		end
		if co then
			companyId = if type(co.id) == "string" then co.id else nil
			companyName = if type(co.name) == "string" then co.name else nil
			minLevel = if finite(co.minOutfitLevel) then co.minOutfitLevel else nil
		end
	end
	local track: string? = nil
	if emp then
		local okTrack, t = call("CareerService", "GetTrack", player)
		if okTrack and type(t) == "string" and t ~= "" then
			track = t
		elseif type(saved.track) == "string" and saved.track ~= "" then
			track = saved.track
		end
	end
	local title = if type(saved.title) == "string" then saved.title else ""
	local okRole, role = call("CareerService", "GetRole", player)
	if okRole and type(role) == "table" and type(role.title) == "string" and role.title ~= "" then
		title = role.title
	end
	-- the role's own private-office flag (Config/Tracks), nil when the ladder doesn't say
	local office: boolean? = nil
	if emp and track then
		local def = if okRole
				and type(role) == "table"
				and role.rank == math.floor(r)
			then role
			else Tracks.rankDef(track, math.floor(r))
		if type(def) == "table" and def.office ~= nil then
			office = def.office == true
		end
	end
	return {
		student = st == "student",
		employed = emp,
		status = st,
		rank = math.floor(r),
		companyId = companyId,
		companyName = companyName,
		track = track,
		title = title,
		minOutfitLevel = minLevel,
		office = office,
	}
end

function Deps.isEmployeeOf(player: Player, companyId: string): boolean
	local ok, yes = call("CareerService", "IsEmployeeOf", player, companyId)
	return ok and yes == true
end

function Deps.outfitLevel(player: Player): number
	local ok, level = call("CareerService", "GetOutfitLevel", player)
	if ok and finite(level) then
		return math.clamp(math.floor(level), 1, 5)
	end
	local okW, wl = call("WardrobeService", "GetOutfitLevel", player)
	if okW and finite(wl) then
		return math.clamp(math.floor(wl), 1, 5)
	end
	local attr = player:GetAttribute("OutfitLevel")
	return if finite(attr) then math.clamp(math.floor(attr :: number), 1, 5) else 1
end

function Deps.plaques(player: Player): { any }
	local saved = savedCareer(player)
	return if type(saved.plaques) == "table" then saved.plaques else {}
end

---------------------------------------------------------------------------------------------------
-- Profile, boosts, events
---------------------------------------------------------------------------------------------------
function Deps.displayName(player: Player): string
	local ok, profile = call("ProfileService", "GetProfile", player)
	if ok and type(profile) == "table" then
		local first = if type(profile.firstName) == "string" then profile.firstName else ""
		local family = if type(profile.familyName) == "string" then profile.familyName else ""
		local full = string.gsub(first .. " " .. family, "^%s+", "")
		full = string.gsub(full, "%s+$", "")
		if full ~= "" then
			return full
		end
	end
	return player.DisplayName
end

function Deps.incomeMult(player: Player): number?
	local ok, m = call("ProfileService", "GetIncomeMult", player)
	return if ok and finite(m) then m else nil
end

function Deps.dailyMult(player: Player, kind: string): number?
	local ok, m = call("DailyService", "GetBoostMult", player, kind)
	return if ok and finite(m) then m else nil
end

function Deps.modifier(name: string): number?
	local ok, m = call("EventService", "GetModifier", name)
	return if ok and finite(m) then m else nil
end

function Deps.eventActive(eventId: string): boolean
	local ok, active = call("EventService", "IsActive", eventId)
	return ok and active == true
end

---------------------------------------------------------------------------------------------------
-- Passes (monetization)
---------------------------------------------------------------------------------------------------
function Deps.savedPass(player: Player, passKey: string): boolean
	local data = Deps.data(player)
	local ent = if data then data.entitlements else nil
	local saved = if type(ent) == "table" then ent.passes else nil
	if type(saved) == "table" then
		return saved[passKey] == true or table.find(saved, passKey) ~= nil
	end
	return false
end

function Deps.ownsPass(player: Player, passKey: string): boolean
	local ok, owns = call("MonetizationService", "OwnsPass", player, passKey)
	if ok and owns == true then
		return true
	end
	return Deps.savedPass(player, passKey)
end

return Deps
