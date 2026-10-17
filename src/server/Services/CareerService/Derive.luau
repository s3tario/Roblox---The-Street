--!strict
-- CareerService/Derive (server, runtime only): the derived fields stored on data.career before each replication so
-- the HUD, profile cards and the Career screens never need server calls (contracts §3 career):
--   title, roleTitle, companyName, bossName, weekLabel ("Week 12 · Wed"), xpToNext, windowRemaining,
--   promotion = { ready, missing = { string }, next, headline, checklist = { {id, ok, pending, text} } },
--   fitScore, outfitLevel, dressLevel
-- plus the player inputs promotion needs (school tier, OVR) and the outfit (WardrobeService, else the saved
-- inventory through Logic/FitScore).
--
--   Derive.apply(player, career)
--   Derive.profileInfo(player) -> { schoolTier, ovr?, firstName, perks }
--   Derive.outfit(player, career) -> (outfitLevel, fitScore, requiredLevel)
--   Derive.promotion(player, career, band?) -> Promotion.Result
--   Derive.weekLabel(career) -> string

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local Leveling = require(Shared.Logic.Leveling)
local CareerState = require(Shared.Logic.CareerState)
local Promotion = require(Shared.Logic.Promotion)
local FitScore = require(Shared.Logic.FitScore)
local Deps = require(script.Parent.Deps)

local Derive = {}

local catalogModule: any = false
local function catalog(): any
	if catalogModule == false then
		catalogModule = nil
		local config = Shared:FindFirstChild("Config")
		local mod = config and config:FindFirstChild("Catalog")
		if mod and mod:IsA("ModuleScript") then
			local ok, res = pcall(require, mod)
			if ok and type(res) == "table" and type(res.get) == "function" then
				catalogModule = res
			end
		end
	end
	return catalogModule
end

local function getItem(id: string): any
	local c = catalog()
	if not c then
		return nil
	end
	return c.get(if type(c.canonical) == "function" then c.canonical(id) else id)
end

local function num(x: any): number?
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- Profile (careerCore)
---------------------------------------------------------------------------------------------------
export type ProfileInfo = { schoolTier: number, ovr: number?, firstName: string, perks: { [string]: any } }

function Derive.profileInfo(player: Player): ProfileInfo
	local data = Deps.data(player)
	local profile = if data and type(data.profile) == "table" then data.profile else {}
	local info: ProfileInfo = {
		schoolTier = 1,
		ovr = nil,
		firstName = if type(profile.firstName) == "string" and profile.firstName ~= ""
			then profile.firstName
			else player.DisplayName,
		perks = if type(profile.perks) == "table" then profile.perks else {},
	}
	local okTier, tier = Deps.call("ProfileService", "GetSchoolTierOrder", player)
	if okTier and num(tier) then
		info.schoolTier = math.clamp(math.floor(tier), 1, 6)
	else
		local school = profile.school
		info.schoolTier = Tracks.rarityOrder(if type(school) == "table" then school.rarity else nil)
		local pedigree = info.perks.boardroom_pedigree
		if pedigree == true or (type(pedigree) == "number" and pedigree > 0) then
			info.schoolTier = math.min(6, info.schoolTier + 1)
		end
	end
	local okOvr, ovr = Deps.call("ProfileService", "GetOVR", player)
	if okOvr and num(ovr) then
		info.ovr = ovr
	elseif num(profile.ovr) and profile.ovr > 0 then
		info.ovr = profile.ovr
	elseif type(profile.stats) == "table" then
		local sum, n = 0, 0
		for _, v in profile.stats do
			if num(v) then
				sum += v
				n += 1
			end
		end
		if n > 0 then
			info.ovr = math.floor(sum / n + 0.5)
		end
	end
	return info
end

---------------------------------------------------------------------------------------------------
-- Outfit (wardrobe)
---------------------------------------------------------------------------------------------------
function Derive.requiredLevel(career: { [string]: any }): number
	local company = Companies.get(career.companyId)
	local role = Tracks.rankDef(career.track, career.rank)
	return FitScore.requiredLevel(company, role)
end

function Derive.outfit(player: Player, career: { [string]: any }): (number, number, number)
	local required = Derive.requiredLevel(career)
	local equipped: any = nil
	local okEq, eq = Deps.call("WardrobeService", "GetEquipped", player)
	if okEq and type(eq) == "table" then
		equipped = eq
	else
		local data = Deps.data(player)
		local inv = if data then data.inventory else nil
		equipped = if type(inv) == "table" then inv.equipped else nil
	end
	local level = FitScore.outfitLevel(equipped, getItem)
	local okLevel, wardrobeLevel = Deps.call("WardrobeService", "GetOutfitLevel", player)
	if okLevel and num(wardrobeLevel) then
		level = math.clamp(math.floor(wardrobeLevel), 1, FitScore.MAX_LEVEL)
	end
	local score = FitScore.score(equipped, getItem, required)
	return level, score, required
end

---------------------------------------------------------------------------------------------------
-- Promotion checklist
---------------------------------------------------------------------------------------------------
function Derive.promotion(player: Player, career: { [string]: any }, band: string?): Promotion.Result
	local info = Derive.profileInfo(player)
	local outfitLevel = num(career.outfitLevel) or 1
	if band ~= nil then
		-- the review decides with a fresh outfit reading
		outfitLevel = (Derive.outfit(player, career))
	end
	local lastBand = if type(career.lastBand) == "string" then career.lastBand else nil
	return Promotion.evaluate({
		trackId = career.track,
		rank = num(career.rank) or 0,
		level = num(career.level) or 1,
		coreDone = num(career.coreAtRank) or 0,
		band = band,
		fastTrack = band == nil and lastBand == "star",
		outfitLevel = outfitLevel,
		schoolTier = info.schoolTier,
		ovr = info.ovr,
	})
end

---------------------------------------------------------------------------------------------------
-- Labels
---------------------------------------------------------------------------------------------------
function Derive.weekLabel(career: { [string]: any }): string
	if career.status == "fired" then
		return Tracks.text("week_between")
	end
	if not CareerState.isEmployed(career) then
		return Tracks.text("week_campus")
	end
	local day = CareerState.weekday(num(career.weekActive) or 0)
	return Tracks.text("week_label", { week = math.max(1, num(career.week) or 1), day = Tracks.text("day_" .. day) })
end

function Derive.apply(player: Player, career: { [string]: any })
	local employed = CareerState.isEmployed(career)
	local company = if employed then Companies.get(career.companyId) else nil
	local title = if type(career.title) == "string" and career.title ~= "" then career.title else Tracks.STUDENT.title
	if career.status == "fired" then
		title = Tracks.text("role_unemployed")
	elseif not employed then
		title = Tracks.STUDENT.title
	end
	career.title = title
	career.roleTitle = title
	career.companyName = if company then company.name else ""
	career.bossName = if company then Companies.bossName(company.id, career.track) else ""
	career.weekLabel = Derive.weekLabel(career)
	career.weekday = CareerState.weekday(num(career.weekActive) or 0)
	career.windowRemaining = CareerState.windowRemaining(career)
	career.xpToNext = Leveling.xpForLevel(num(career.level) or 1)
	career.levelCap = CareerState.capFor(career)

	local level, fit, required = Derive.outfit(player, career)
	career.outfitLevel = level
	career.fitScore = fit
	career.dressLevel = required

	local promo = Derive.promotion(player, career, nil)
	local checklist = {}
	for _, item in promo.items do
		table.insert(checklist, { id = item.id, ok = item.ok, pending = item.pending, text = item.text })
	end
	local missing = table.clone(promo.missing)
	if not promo.applicable then
		missing = {}
		if career.status == "fired" then
			table.insert(missing, Tracks.text("promo_fired"))
		elseif not employed then
			table.insert(missing, Tracks.text("promo_student"))
		end
	end
	career.promotion = {
		ready = promo.ready,
		missing = missing,
		next = if promo.nextRole then promo.nextRole.title else "",
		headline = promo.headline,
		top = promo.top,
		fastTrack = promo.fastTrack,
		checklist = checklist,
	}
end

return Derive
