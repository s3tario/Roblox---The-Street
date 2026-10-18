--!strict
-- ProfileService: guarded access to the other features it talks to (RUNTIME ONLY, server). Every call goes through
-- Registry.get plus pcall, so a missing or erroring feature never breaks the Life Roll; each failure is logged once.
--
--   Deps.call(service, method, ...) -> (ok, result)     Deps.has(service, method) -> boolean
--   Deps.data(player) / Deps.isLoaded(player) / Deps.replicate(player, key) / Deps.audit(player, kind, details)
--   Deps.notify(player, text, kind?) / Deps.banner(playerOrNil, opts) / Deps.ticker(text)
--   Deps.careerWeek(player) -> number          CareerService:GetWeek, else data.career.week, else 0
--   Deps.activeSeconds(player) -> number       ActivityService:GetActiveSeconds, else data.meta.activeSec, else 0
--   Deps.isEmployeeOf(player, companyId) -> boolean
--   Deps.addCash(player, amount, source) -> boolean   EconomyService:AddCash(..., "reward"); false when missing
--   Deps.grantItem(player, itemId, slot, source, equip) -> boolean   WardrobeService:Grant, then :Equip if needed
--   Deps.submitBoard(player, boardId, value)   LeaderboardService:Submit
--   Deps.connect(service, signal, fn) -> boolean

local Registry = require(script.Parent.Parent.Parent.Registry)

local Deps = {}

local warned: { [string]: boolean } = {}

local function warnOnce(key: string, err: any)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(("[ProfileService] %s failed: %s"):format(key, tostring(err)))
end

function Deps.has(serviceName: string, method: string): boolean
	local svc = Registry.get(serviceName)
	return type(svc) == "table" and type(svc[method]) == "function"
end

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

local function num(x: any): number?
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- Data
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

function Deps.audit(player: Player, kind: string, details: { [string]: any }?)
	Deps.call("DataService", "Audit", player, kind, details or {})
end

---------------------------------------------------------------------------------------------------
-- Notify
---------------------------------------------------------------------------------------------------
function Deps.notify(player: Player, text: string, kind: string?)
	Deps.call("NotifyService", "Notify", player, text, kind)
end

function Deps.banner(player: Player?, opts: { [string]: any })
	Deps.call("NotifyService", "Banner", player, opts)
end

function Deps.ticker(text: string)
	Deps.call("NotifyService", "Ticker", text)
end

---------------------------------------------------------------------------------------------------
-- Career and activity (careerPath)
---------------------------------------------------------------------------------------------------
function Deps.careerWeek(player: Player): number
	local ok, week = Deps.call("CareerService", "GetWeek", player)
	local w = if ok then num(week) else nil
	if w then
		return math.max(0, math.floor(w))
	end
	local data = Deps.data(player)
	local career = if data then data.career else nil
	local saved = if type(career) == "table" then num(career.week) else nil
	return if saved then math.max(0, math.floor(saved)) else 0
end

function Deps.activeSeconds(player: Player): number
	local ok, sec = Deps.call("ActivityService", "GetActiveSeconds", player)
	local s = if ok then num(sec) else nil
	if s then
		return math.max(0, s)
	end
	local data = Deps.data(player)
	local meta = if data then data.meta else nil
	local saved = if type(meta) == "table" then num(meta.activeSec) else nil
	return if saved then math.max(0, saved) else 0
end

function Deps.isEmployeeOf(player: Player, companyId: string): boolean
	local ok, yes = Deps.call("CareerService", "IsEmployeeOf", player, companyId)
	return ok and yes == true
end

---------------------------------------------------------------------------------------------------
-- Economy, wardrobe, leaderboards
---------------------------------------------------------------------------------------------------
function Deps.addCash(player: Player, amount: number, source: string): boolean
	if not Deps.has("EconomyService", "AddCash") then
		return false
	end
	local ok, result = Deps.call("EconomyService", "AddCash", player, amount, source, "reward")
	return ok and result ~= false
end

function Deps.grantItem(player: Player, itemId: string, slot: string, source: string, equip: boolean): boolean
	local ok, granted = Deps.call("WardrobeService", "Grant", player, itemId, source, { equip = equip, notify = false })
	if not (ok and granted == true) then
		return false
	end
	if equip then
		local okWorn, worn = Deps.call("WardrobeService", "GetEquipped", player)
		if not (okWorn and type(worn) == "table" and worn[slot] == itemId) then
			Deps.call("WardrobeService", "Equip", player, slot, itemId)
		end
	end
	return true
end

function Deps.submitBoard(player: Player, boardId: string, value: number)
	if Deps.has("LeaderboardService", "Submit") then
		task.spawn(Deps.call, "LeaderboardService", "Submit", player, boardId, value)
	end
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
				warn(("[ProfileService] %s.%s handler failed: %s"):format(serviceName, signalName, tostring(problem)))
			end
		end)
	end)
	if not ok then
		warnOnce(serviceName .. "." .. signalName, err)
	end
	return ok
end

return Deps
