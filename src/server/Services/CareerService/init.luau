--!strict
-- CareerService (server, owned by `careerPath`; docs/contracts.md §5, design v3 §4-§6 and §13): the career record.
-- Levels and XP, the role on a track at a company, status, the work week clock, reputation, deal plaques, offers,
-- firing and recovery. The weekly boss review itself runs in ReviewService; ActivityService supplies active time.
--
-- Data: data.career (Config/DataTemplate/Career). Derived HUD fields are refreshed by CareerService/Derive before
-- every replication (title, company name, "Week 12 · Wed", xpToNext, promotion checklist, fitScore, outfitLevel).
--
-- Signals (contracts §5):
--   LevelChanged(player, newLevel, oldLevel)   RoleChanged(player, newRoleId, oldRoleId, reason)
--   StatusChanged(player, new, old)            ReviewCompleted(player, review)   (fired by ReviewService)
--   DealRecorded(player, plaque)               OffersChanged(player)
-- API (contracts §5):
--   GetRole / GetRank / GetTrack / GetCompany / GetLevel / GetStatus / IsEmployed / IsEmployeeOf(player, companyId)
--   AddXP(player, amount, source) -> added      AddReputation(player, amount, source)
--   RecordWork(player, {taskId, quality, onTime, core, category, clientFacing?})
--   RecordDeal(player, dealId, name, quality) -> plaque?
--   GetRiskLimitMultiplier(player) -> number    GetWeek(player) -> (week, weekday)
--   GrantOffer(player, offer) -> offerId?       AcceptOffer(player, offerId) -> (ok, err)   DeclineOffer(...)
--   GetClientBonus(player) -> 1.0..1.1          GetOutfitLevel(player) -> 1..5
--   MassFiring(companyId, reason) -> { fired = {Player}, saved = {Player} }
--   GrantReinstatementCredit(player)            GetBoardValues(player) -> {prestige, deal, comeback, fastestRunSec?}
--   ResetForRebirth(player)
-- Extras: GetCareer(player) (a shallow copy), GetBossName(player), Touch(player) (re-derive + replicate),
--   OpenServices(player), Promote(player) / Fire(player, reason) (ReviewService), and the recovery actions.
-- Modules: Deps (guarded cross-feature calls), Derive (HUD fields), Normalize (save repair), Lifecycle (load, week
--   clock, prompts), Roles (promotion, mass firing), Deals (plaques), Offers, Recovery (firing and the way back),
--   Prompts (interact prompts), Remotes.
-- Interact: `career_services` (the Career Services venue) opens the CareerServices screen.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local Template = require(Shared.Config.DataTemplate.Career)
local Leveling = require(Shared.Logic.Leveling)
local CareerState = require(Shared.Logic.CareerState)
local FitScore = require(Shared.Logic.FitScore)
local Deps = require(script.Deps)
local Derive = require(script.Derive)
local Normalize = require(script.Normalize)
local Lifecycle = require(script.Lifecycle)
local Roles = require(script.Roles)
local Deals = require(script.Deals)
local Prompts = require(script.Prompts)
local Offers = require(script.Offers)
local Recovery = require(script.Recovery)
local Remotes = require(script.Remotes)

local CareerService = {
	Name = "CareerService",
	Priority = 30,
	LevelChanged = Signal.new(),
	RoleChanged = Signal.new(),
	StatusChanged = Signal.new(),
	ReviewCompleted = Signal.new(),
	DealRecorded = Signal.new(),
	OffersChanged = Signal.new(),
}

CareerService.Deps = Deps
CareerService.Derive = Derive
CareerService.Prompts = Prompts
CareerService._clearReentry = Recovery.clearReentry

local MAX_XP_PER_CALL = 100000
local MAX_REP_PER_CALL = 500

type PlayerState = {
	queued: boolean,
	lastCountdown: number,
	capNotified: { [string]: boolean },
	lastServicesOpen: number,
}

local states: { [Player]: PlayerState } = {}

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

local function str(x: any, default: string): string
	return if type(x) == "string" then x else default
end

local function careerOf(player: Player): { [string]: any }?
	return Deps.career(player)
end
CareerService._careerOf = careerOf

function CareerService._state(player: Player): PlayerState?
	return states[player]
end

function CareerService._ensureState(player: Player): PlayerState
	local st = states[player]
	if not st then
		st = { queued = false, lastCountdown = 0, capNotified = {}, lastServicesOpen = 0 }
		states[player] = st
	end
	return st
end

function CareerService._dropState(player: Player)
	states[player] = nil
end

---------------------------------------------------------------------------------------------------
-- Replication
---------------------------------------------------------------------------------------------------
local function flush(player: Player)
	local st = states[player]
	if not st then
		return
	end
	st.queued = false
	local career = careerOf(player)
	if not career then
		return
	end
	local ok, err = pcall(function()
		Derive.apply(player, career)
	end)
	if not ok then
		warn("[CareerService] derive failed: " .. tostring(err))
	end
	if Deps.isLive(player) then
		Deps.replicate(player, "career")
	end
end

-- Re-derives the HUD fields and replicates data.career (coalesced: at most once per frame per player).
function CareerService:Touch(player: Player)
	local st = states[player]
	if not st or st.queued then
		return
	end
	st.queued = true
	task.defer(flush, player)
end

---------------------------------------------------------------------------------------------------
-- Queries (contracts §5)
---------------------------------------------------------------------------------------------------
function CareerService:GetCareer(player: Player): { [string]: any }?
	local career = careerOf(player)
	return if career then table.clone(career) else nil
end

function CareerService:GetRole(player: Player): Tracks.RoleDef?
	local career = careerOf(player)
	if not career then
		return nil
	end
	if career.status == "student" then
		return Tracks.STUDENT
	end
	return Tracks.role(career.roleId)
end

function CareerService:GetRank(player: Player): number
	local career = careerOf(player)
	return if career then math.floor(num(career.rank, 0)) else 0
end

function CareerService:GetTrack(player: Player): string?
	local career = careerOf(player)
	if not career or career.track == "" or career.status == "student" then
		return nil
	end
	return career.track
end

function CareerService:GetCompany(player: Player): Companies.CompanyDef?
	local career = careerOf(player)
	if not career or not CareerState.isEmployed(career) then
		return nil
	end
	return Companies.get(career.companyId)
end

function CareerService:GetLevel(player: Player): number
	local career = careerOf(player)
	return if career then math.floor(num(career.level, 1)) else 1
end

function CareerService:GetStatus(player: Player): string
	local career = careerOf(player)
	return if career then str(career.status, "student") else "student"
end

function CareerService:IsEmployed(player: Player): boolean
	return CareerState.isEmployed(careerOf(player))
end

function CareerService:IsEmployeeOf(player: Player, companyId: string): boolean
	local career = careerOf(player)
	if not career or not CareerState.isEmployed(career) or type(companyId) ~= "string" then
		return false
	end
	if career.companyId == companyId then
		return true
	end
	-- Merger Mania pairs two companies' offices (contracts §11)
	local ok, isActive = Deps.call("EventService", "IsActive", "merger_mania")
	if ok and isActive ~= true then
		return false
	end
	local partners = CareerState.mergerPartners(Deps.global("events"), career.companyId, os.time())
	return CareerState.isEmployee(career, companyId, partners)
end

function CareerService:GetWeek(player: Player): (number, number)
	local career = careerOf(player)
	if not career then
		return 0, 1
	end
	return math.floor(num(career.week, 0)), CareerState.weekday(num(career.weekActive, 0))
end

function CareerService:GetRiskLimitMultiplier(player: Player): number
	local career = careerOf(player)
	if career and career.status == "probation" then
		return 0.6
	end
	return 1
end

function CareerService:GetBossName(player: Player): string
	local career = careerOf(player)
	if not career or not CareerState.isEmployed(career) then
		return Companies.bossName(nil, nil)
	end
	return Companies.bossName(career.companyId, career.track)
end

function CareerService:GetOutfitLevel(player: Player): number
	local career = careerOf(player)
	if not career then
		return 1
	end
	local level = Derive.outfit(player, career)
	return level
end

function CareerService:GetClientBonus(player: Player): number
	local career = careerOf(player)
	if not career or not CareerState.isEmployed(career) then
		return 1
	end
	local level, score, required = Derive.outfit(player, career)
	return FitScore.clientBonus(score, level, required)
end

function CareerService:GetBoardValues(player: Player): { [string]: number }
	local career = careerOf(player)
	if not career then
		return { prestige = 0, deal = 0, comeback = 0 }
	end
	local out: { [string]: number } = {
		prestige = math.floor(num(career.prestige, 0)),
		deal = math.floor(num(career.dealMastery, 0)),
		comeback = math.floor(num(career.comebacks, 0)),
	}
	local fastest = num(career.fastestRunSec, 0)
	if fastest > 0 then
		out.fastestRunSec = math.floor(fastest)
	end
	return out
end

local function submitBoards(player: Player)
	local values = CareerService:GetBoardValues(player)
	Deps.call("LeaderboardService", "Submit", player, "CareerPrestige", values.prestige)
	Deps.call("LeaderboardService", "Submit", player, "DealMastery", values.deal)
	Deps.call("LeaderboardService", "Submit", player, "Comeback", values.comeback)
	if values.fastestRunSec then
		Deps.call("LeaderboardService", "Submit", player, "FastestRun", values.fastestRunSec)
	end
end
CareerService._submitBoards = submitBoards

---------------------------------------------------------------------------------------------------
-- XP, reputation, work
---------------------------------------------------------------------------------------------------
function CareerService:AddXP(player: Player, amount: number, source: string?): number
	local career = careerOf(player)
	local st = states[player]
	local amt = num(amount, 0)
	if not career or not st or amt <= 0 then
		return 0
	end
	amt = math.min(amt, MAX_XP_PER_CALL)
	local cap = CareerState.capFor(career)
	local oldLevel = math.floor(num(career.level, 1))
	local level, xp, added = Leveling.addXp(oldLevel, num(career.xp, 0), amt, cap)
	career.level = level
	career.xp = xp
	if level ~= oldLevel then
		CareerService.LevelChanged:Fire(player, level, oldLevel)
		Deps.notify(player, Tracks.text("level_up", { level = level }), "xp")
	end
	if added < amt and level >= cap and level < Leveling.MAX_LEVEL then
		local key = tostring(career.roleId) .. ":" .. cap
		if not st.capNotified[key] then
			st.capNotified[key] = true
			Deps.notify(player, Tracks.text("level_capped", { title = str(career.title, "") }), "info")
		end
	end
	CareerService:Touch(player)
	return added
end

-- Settles banked XP after the cap changed (promotion). Fires LevelChanged for the levels gained.
function CareerService:_settleLevel(player: Player)
	local career = careerOf(player)
	if not career then
		return
	end
	local oldLevel = math.floor(num(career.level, 1))
	local level, xp = Leveling.addXp(oldLevel, num(career.xp, 0), 0, CareerState.capFor(career))
	career.level = level
	career.xp = xp
	if level ~= oldLevel then
		CareerService.LevelChanged:Fire(player, level, oldLevel)
	end
end

function CareerService:AddReputation(player: Player, amount: number, source: string?)
	local career = careerOf(player)
	local amt = math.clamp(num(amount, 0), -MAX_REP_PER_CALL, MAX_REP_PER_CALL)
	if not career or amt == 0 then
		return
	end
	if amt > 0 then
		local ok, mult = Deps.call("EventService", "GetModifier", "reputationMult")
		if ok and type(mult) == "number" and mult == mult and mult > 0 then
			amt *= math.clamp(mult, 0, 5)
		end
	end
	amt = math.floor(amt * 10 + 0.5) / 10
	career.reputation = num(career.reputation, 0) + amt
	career.weekRep = num(career.weekRep, 0) + amt
	CareerService:Touch(player)
end

export type WorkInfo = {
	taskId: string?,
	quality: number?,
	onTime: boolean?,
	core: boolean?,
	category: string?,
	clientFacing: boolean?,
}

function CareerService:RecordWork(player: Player, info: WorkInfo)
	local career = careerOf(player)
	if not career or type(info) ~= "table" then
		return
	end
	local quality = math.clamp(num(info.quality, 0), 0, 100)
	local credited = if info.onTime == false then quality * 0.8 else quality
	local w = career.weekWork
	w.count = num(w.count, 0) + 1
	w.qualitySum = num(w.qualitySum, 0) + credited
	w.best = math.max(num(w.best, 0), quality)
	if info.core == true then
		w.core = num(w.core, 0) + 1
		if CareerState.isEmployed(career) then
			career.coreAtRank = num(career.coreAtRank, 0) + 1
		end
	end
	local rep = if quality >= 60 then 1 else 0
	if info.clientFacing == true then
		w.clientCount = num(w.clientCount, 0) + 1
		w.clientSum = num(w.clientSum, 0) + quality
		-- dress code and Fit Score nudge the reputation of client-facing work, never its graded quality
		rep += 2 * CareerService:GetClientBonus(player)
	end
	if rep > 0 then
		CareerService:AddReputation(player, rep, "work")
	end
	CareerService:Touch(player)
end

function CareerService:RecordDeal(player: Player, dealId: string, name: string, quality: number): { [string]: any }?
	return Deals.record(CareerService, player, dealId, name, quality)
end

---------------------------------------------------------------------------------------------------
-- Role changes (used by offers, reviews and recovery)
---------------------------------------------------------------------------------------------------
function CareerService:_setStatus(player: Player, career: { [string]: any }, status: string)
	local old = str(career.status, "student")
	career.status = status
	if old ~= status then
		CareerService.StatusChanged:Fire(player, status, old)
	end
end

-- Sets the trading book to the rank's size x the firm's book multiplier (x fraction), off-thread.
local function topBook(player: Player, career: { [string]: any }, reason: string, fraction: number?)
	local role = Tracks.rankDef(career.track, career.rank)
	local company = Companies.get(career.companyId)
	if not role then
		return
	end
	local size = math.floor(role.book * (if company then company.bookMult else 1) * (fraction or 1))
	task.spawn(function()
		Deps.call("PortfolioService", "SetBookSize", player, size, reason)
	end)
end
CareerService._topBook = topBook

-- Promotion to the next rank (ReviewService decided it). Returns the new role.
function CareerService:Promote(player: Player): Tracks.RoleDef?
	return Roles.promote(CareerService, player)
end

-- The firing itself (ReviewService and MassFiring decided it, after the Alumni Lifeline check).
function CareerService:Fire(player: Player, reason: string): CareerState.Wipeout?
	local career = careerOf(player)
	if not career or not CareerState.isEmployed(career) then
		return nil
	end
	return Recovery.fire(CareerService, player, career, reason)
end

function CareerService:MassFiring(companyId: string, reason: string?): { fired: { Player }, saved: { Player } }
	return Roles.massFiring(CareerService, companyId, reason)
end

---------------------------------------------------------------------------------------------------
-- Offers (CareerService/Offers)
---------------------------------------------------------------------------------------------------
function CareerService:GrantOffer(player: Player, offer: { [string]: any }): string?
	return Offers.grant(CareerService, player, offer)
end

function CareerService:AcceptOffer(player: Player, offerId: string): (boolean, string?)
	return Offers.accept(CareerService, player, offerId)
end

function CareerService:DeclineOffer(player: Player, offerId: string): (boolean, string?)
	return Offers.decline(CareerService, player, offerId)
end

---------------------------------------------------------------------------------------------------
-- Recovery (CareerService/Recovery)
---------------------------------------------------------------------------------------------------
function CareerService:GrantReinstatementCredit(player: Player)
	local career = careerOf(player)
	if not career then
		return
	end
	career.reinstateCredits = math.floor(num(career.reinstateCredits, 0)) + 1
	Deps.notify(player, Tracks.text("reinstate_credit_granted"), "good")
	Deps.audit(player, "career_reinstate_credit", { credits = career.reinstateCredits })
	CareerService:Touch(player)
	Deps.save(player, "reinstate_credit")
end

function CareerService:GetServicesInfo(player: Player): { [string]: any }
	return Recovery.info(CareerService, player)
end

function CareerService:Reentry(player: Player, action: string, answers: any): (boolean, string?, any, any)
	return Recovery.reentry(CareerService, player, action, answers)
end

function CareerService:Reinstate(player: Player): (boolean, string?)
	return Recovery.reinstate(CareerService, player)
end

function CareerService:UseCapitalCredit(player: Player): (boolean, string?)
	return Recovery.useCapital(CareerService, player)
end

function CareerService:FreshStart(player: Player): (boolean, string?)
	return Recovery.freshStart(CareerService, player)
end

function CareerService:OpenServices(player: Player)
	if Deps.isLive(player) then
		pcall(Net.fire, Remotes.OPEN, player, "CareerServices", {})
	end
end

---------------------------------------------------------------------------------------------------
-- Rebirth (careerCore's RebirthService calls this)
---------------------------------------------------------------------------------------------------
function CareerService:ResetForRebirth(player: Player)
	local career = careerOf(player)
	if not career then
		return
	end
	local oldRole = str(career.roleId, "student")
	local oldStatus = str(career.status, "student")
	CareerState.resetForRebirth(career, Normalize.fresh(Template.career), Deps.activeSeconds(player))
	Recovery.clearReentry(player)
	CareerState.history(career, "rebirth", os.time())
	if oldStatus ~= career.status then
		CareerService.StatusChanged:Fire(player, career.status, oldStatus)
	end
	CareerService.RoleChanged:Fire(player, career.roleId, oldRole, "rebirth")
	Deps.objective(player, nil)
	Deps.audit(player, "career_rebirth", {})
	CareerService:Touch(player)
end

---------------------------------------------------------------------------------------------------
-- Lifecycle (CareerService/Lifecycle)
---------------------------------------------------------------------------------------------------
function CareerService:Init()
	Remotes.bind(CareerService)
	Lifecycle.bind(CareerService)
end

function CareerService:Start()
	Lifecycle.start(CareerService)
end

return CareerService
