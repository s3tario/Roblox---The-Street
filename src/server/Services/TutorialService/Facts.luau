--!strict
-- TutorialService/Facts (server, runtime only): reads the player's data and live position into the Facts snapshot
-- that Logic/QuestLine runs on. Every cross-feature read is guarded, with player attributes as the fallback (Zone,
-- OfficeCompany, OfficeFloor are set by WorldService / OfficeService).
--
--   Facts.gather(player, data) -> QuestLine.Facts
--   Facts.location(player) -> { companyId, floor }?
--   Facts.companyName(id) -> string?   Facts.bossName(career) -> string?   Facts.department(track) -> string?

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Companies = require(Shared.Config.Companies)
local Tracks = require(Shared.Config.Tracks)
local CareerState = require(Shared.Logic.CareerState)
local QuestLine = require(Shared.Logic.QuestLine)
local Deps = require(script.Parent.Deps)

local Facts = {}

function Facts.location(player: Player): { companyId: string, floor: string }?
	local ok, loc = Deps.call("OfficeService", "GetPlayerLocation", player)
	if ok and type(loc) == "table" and type(loc.companyId) == "string" and loc.companyId ~= "" then
		return { companyId = loc.companyId, floor = if type(loc.floor) == "string" then loc.floor else "lobby" }
	end
	if ok then
		return nil
	end
	local company = player:GetAttribute("OfficeCompany")
	if type(company) == "string" and company ~= "" then
		local floor = player:GetAttribute("OfficeFloor")
		return { companyId = company, floor = if type(floor) == "string" then floor else "lobby" }
	end
	return nil
end

local function zoneOf(player: Player): string?
	local ok, zone = Deps.call("WorldService", "GetZone", player)
	if ok and type(zone) == "string" then
		return zone
	end
	local attr = player:GetAttribute("Zone")
	return if type(attr) == "string" and attr ~= "" then attr else nil
end

function Facts.companyName(id: any): string?
	local c = Companies.get(id)
	return if c then c.name else nil
end

function Facts.bossName(career: any): string?
	if type(career) ~= "table" then
		return nil
	end
	if type(career.bossName) == "string" and career.bossName ~= "" then
		return career.bossName
	end
	if type(career.companyId) == "string" and career.companyId ~= "" then
		return Companies.bossName(career.companyId, career.track)
	end
	return nil
end

function Facts.department(track: any): string?
	local def = Tracks.get(track)
	return if def then def.name else nil
end

local function count(list: any): number
	return if type(list) == "table" then #list else 0
end

function Facts.gather(player: Player, data: { [string]: any }): QuestLine.Facts
	local profile = if type(data.profile) == "table" then data.profile else {}
	local career = if type(data.career) == "table" then data.career else {}
	local campus = if type(data.campus) == "table" then data.campus else {}
	local work = if type(data.work) == "table" then data.work else {}
	local employed = CareerState.isEmployed(career)
	local fired = career.status == "fired"
	local loc = Facts.location(player)
	local inOwn = employed and loc ~= nil and loc.companyId == career.companyId
	local net = if type(campus.network) == "table" then campus.network else {}
	return QuestLine.facts({
		built = profile.built == true,
		employed = employed,
		fired = fired,
		hasOffer = count(career.offers) > 0,
		inOffice = loc ~= nil,
		inOwnOffice = inOwn,
		onOwnFloor = inOwn and loc ~= nil and loc.floor == career.track,
		onboarded = career.onboarded == true,
		club = campus.club == true,
		zone = zoneOf(player),
		tasksDone = if type(work.completed) == "table" then work.completed else {},
		networked = Deps.num(net.count, 0),
		jobTasks = Deps.num(campus.jobTasks, 0),
		trades = Deps.num(campus.trades, 0),
		reviews = count(career.reviews),
		rebirths = Deps.num(profile.rebirths, 0),
		company = if employed or fired then Facts.companyName(career.companyId) else nil,
		boss = if employed then Facts.bossName(career) else nil,
		department = if employed then Facts.department(career.track) else nil,
	})
end

return Facts
