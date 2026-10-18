--!strict
-- CareerService/Normalize (server, runtime only): repairs a saved career in place when it loads, so every reader can
-- trust its shape (types, statuses, role ids, counters). Missing fields come from Config/DataTemplate/Career; an
-- unknown track or firm (an old save, a renamed config) sends the player back to campus recruiting and nothing
-- else is lost; offers whose firm stopped hiring are dropped.
--
--   Normalize.apply(career)
--   Normalize.fresh(value) -> deep copy of a template value

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local Template = require(Shared.Config.DataTemplate.Career)
local Leveling = require(Shared.Logic.Leveling)
local CareerState = require(Shared.Logic.CareerState)

local Normalize = {}

local WEEK_FIELDS = { "count", "qualitySum", "core", "clientCount", "clientSum", "best" }

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function Normalize.fresh(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = Normalize.fresh(x)
	end
	return out
end

function Normalize.apply(career: { [string]: any })
	local t: { [string]: any } = Template.career :: any
	for k, v in t do
		if career[k] == nil or type(career[k]) ~= type(v) then
			career[k] = Normalize.fresh(v)
		end
	end
	career.level = math.clamp(math.floor(num(career.level, 1)), 1, Leveling.MAX_LEVEL)
	career.xp = math.max(0, num(career.xp, 0))
	career.rank = math.max(0, math.floor(num(career.rank, 0)))
	career.week = math.max(0, math.floor(num(career.week, 0)))
	career.weekActive = math.clamp(num(career.weekActive, 0), 0, CareerState.WINDOW)
	career.overdueActive = math.max(0, num(career.overdueActive, 0))
	for _, key in WEEK_FIELDS do
		career.weekWork[key] = num(career.weekWork[key], 0)
	end
	if not CareerState.STATUSES[career.status] then
		career.status = if career.rank >= 1 and career.companyId ~= "" then "active" else "student"
	end
	if career.status ~= "fired" and career.status ~= "student" then
		local role = Tracks.rankDef(career.track, career.rank)
		local company = Companies.get(career.companyId)
		if not role or not company then
			CareerState.freshStart(career)
		else
			career.roleId = role.roleId
			career.title = role.title
		end
	elseif career.status == "student" then
		career.rank = 0
		career.roleId = Tracks.STUDENT.roleId
		career.title = Tracks.STUDENT.title
		career.companyId = ""
	else
		career.roleId = Tracks.UNEMPLOYED_ROLE
		career.companyId = ""
		if type(career.fired.track) ~= "string" then
			career.fired.track = career.track
		end
	end
	-- a phone review that never happened (the server closed mid-call) rings again soon after the next join
	if career.reviewDue == true and career.remoteCalled == true then
		career.remoteCalled = false
		career.overdueActive = math.min(career.overdueActive, CareerState.REMOTE_AFTER - 60)
	end
	local kept = {}
	for _, offer in career.offers do
		if type(offer) == "table" and type(offer.id) == "string" and Companies.hiring(offer.companyId, offer.track) then
			table.insert(kept, offer)
		end
	end
	career.offers = kept
end

return Normalize
