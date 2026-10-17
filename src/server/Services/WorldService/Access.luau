--!strict
-- WorldService/Access (server, runtime): what the world rules need to know about a player, read from the
-- features that own it. Every cross-feature call is guarded: CareerService (careerPath), MonetizationService
-- (monetization) and DataService (data) may be missing or erroring, and the player's saved data is the fallback.
--
--   Access.state(player, requires?) -> DoorRules.ReqState   rank, employed, data (for `flag` dot paths) and, when
--                                                          `requires.pass` is set, that pass
--   Access.stageInfo(player) -> DoorRules.StageInfo          employed, rank, status
--   Access.ownsPass(player, passKey) -> boolean
--   Access.data(player) -> { [string]: any }?               DataService:Get(player)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DoorRules = require(Shared.Logic.DoorRules)
local Registry = require(script.Parent.Parent.Parent.Registry)

local Access = {}

-- Calls service:method(player, ...) when the service and method exist; returns (ok, value).
local function ask(serviceName: string, method: string, player: Player, ...: any): (boolean, any)
	local svc = Registry.get(serviceName)
	if svc == nil then
		return false, nil
	end
	local fn = svc[method]
	if type(fn) ~= "function" then
		return false, nil
	end
	local ok, value = pcall(fn, svc, player, ...)
	if not ok then
		warn(("[WorldService] %s:%s failed: %s"):format(serviceName, method, tostring(value)))
		return false, nil
	end
	return true, value
end

function Access.data(player: Player): { [string]: any }?
	local ok, data = ask("DataService", "Get", player)
	if ok and type(data) == "table" then
		return data
	end
	return nil
end

local function careerOf(data: { [string]: any }?): { [string]: any }?
	local career = if data then data.career else nil
	return if type(career) == "table" then career else nil
end

local function rankOf(player: Player, career: { [string]: any }?): number
	local ok, rank = ask("CareerService", "GetRank", player)
	if ok and type(rank) == "number" and rank == rank then
		return rank
	end
	if career and type(career.rank) == "number" then
		return career.rank
	end
	return 0
end

local function employedOf(player: Player, career: { [string]: any }?): boolean
	local ok, employed = ask("CareerService", "IsEmployed", player)
	if ok and type(employed) == "boolean" then
		return employed
	end
	return DoorRules.isEmployedCareer(career)
end

function Access.ownsPass(player: Player, passKey: string): boolean
	local ok, owns = ask("MonetizationService", "OwnsPass", player, passKey)
	if ok then
		return owns == true
	end
	-- Without the monetization feature, the saved entitlements decide (server data, never the client).
	local data = Access.data(player)
	local ent = if data then data.entitlements else nil
	local passes = if type(ent) == "table" then ent.passes else nil
	if type(passes) == "table" then
		return passes[passKey] == true or table.find(passes, passKey) ~= nil
	end
	return false
end

function Access.state(player: Player, requires: any?): DoorRules.ReqState
	local data = Access.data(player)
	local career = careerOf(data)
	local state: DoorRules.ReqState = {
		rank = rankOf(player, career),
		employed = employedOf(player, career),
		data = data,
	}
	if type(requires) == "table" and type(requires.pass) == "string" then
		state.passes = { [requires.pass] = Access.ownsPass(player, requires.pass) }
	end
	return state
end

function Access.stageInfo(player: Player): DoorRules.StageInfo
	local data = Access.data(player)
	local career = careerOf(data)
	local status: string? = nil
	local ok, s = ask("CareerService", "GetStatus", player)
	if ok and type(s) == "string" then
		status = s
	elseif career and type(career.status) == "string" then
		status = career.status
	end
	return { employed = employedOf(player, career), rank = rankOf(player, career), status = status }
end

return Access
