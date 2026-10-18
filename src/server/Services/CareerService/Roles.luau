--!strict
-- CareerService/Roles (server, runtime only): rank changes decided elsewhere.
--   Roles.promote(svc, player) -> RoleDef?       ReviewService decided it: the new title, banked XP settles under
--                                                the new cap, a book top-up (PortfolioService:SetBookSize), the
--                                                plaques move to the bookshelf with an office (HousingService), the
--                                                Fastest Run time at the top title, RoleChanged "promotion"
--   Roles.massFiring(svc, companyId, reason) -> { fired = {Player}, saved = {Player} }
--       design v3 §10: employees present on this server whose last review was below On track are let go (the
--       Alumni Lifeline saves its owner once); everyone else gets a morale bonus. ReviewService plays the meeting.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local CareerState = require(Shared.Logic.CareerState)
local Deps = require(script.Parent.Deps)
local Derive = require(script.Parent.Derive)

local Roles = {}

Roles.SURVIVOR_REP = 8

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function Roles.promote(svc: any, player: Player): Tracks.RoleDef?
	local career = svc._careerOf(player)
	if not career or not CareerState.isEmployed(career) then
		return nil
	end
	local nextRole = Tracks.rankDef(career.track, num(career.rank, 0) + 1)
	if not nextRole then
		return nil
	end
	local oldRole = CareerState.setRole(career, career.track, nextRole.rank, {})
	svc:_settleLevel(player)
	svc._topBook(player, career, "promotion")
	task.spawn(function()
		Deps.call("HousingService", "RefreshPlaques", player)
	end)
	CareerState.history(career, "promotion", os.time(), { title = nextRole.title })
	local company = Companies.get(career.companyId)
	local companyName = if company then company.name else ""
	if nextRole.rank == Tracks.topRank(career.track) then
		local active = Deps.activeSeconds(player)
		career.topTitleAt = active
		local run = math.max(1, active - num(career.lifeStartActive, 0))
		if num(career.fastestRunSec, 0) <= 0 or run < career.fastestRunSec then
			career.fastestRunSec = math.floor(run)
		end
		CareerState.history(career, "top_title", os.time(), { title = nextRole.title })
		local info = Derive.profileInfo(player)
		Deps.ticker(Tracks.text("ticker_top_title", {
			name = info.firstName,
			title = nextRole.title,
			company = companyName,
		}))
	end
	svc.RoleChanged:Fire(player, nextRole.roleId, oldRole, "promotion")
	Deps.call("EmailService", "Send", player, {
		from = Companies.bossName(career.companyId, career.track),
		subject = Tracks.text("mail_promoted_subject", { title = nextRole.title }),
		body = Tracks.text("mail_promoted_body", { title = nextRole.title, company = companyName }),
		kind = "hr",
	})
	Deps.audit(player, "career_promoted", { roleId = nextRole.roleId, companyId = career.companyId })
	svc._submitBoards(player)
	svc:Touch(player)
	return nextRole
end

function Roles.massFiring(svc: any, companyId: any, reason: any): { fired: { Player }, saved: { Player } }
	local result = { fired = {} :: { Player }, saved = {} :: { Player } }
	local company = if type(companyId) == "string" then Companies.get(companyId) else nil
	if not company then
		return result
	end
	local entries = {}
	for _, p in Players:GetPlayers() do
		local career = svc._careerOf(p)
		if career and CareerState.isEmployed(career) and career.companyId == company.id then
			local ok, has = Deps.call("ProfileService", "HasPerk", p, "alumni_lifeline")
			table.insert(entries, { id = p, lastBand = career.lastBand, hasLifeline = ok and has == true })
		end
	end
	local selection = CareerState.massFiringSelect(entries)
	local why = if type(reason) == "string" then reason else nil

	-- Without ReviewService (or when it fails): the Lifeline still saves its owner once, everyone else is let go.
	local function direct(p: Player, tryLifeline: boolean): boolean
		local career = svc._careerOf(p)
		if not career or not CareerState.isEmployed(career) then
			return false -- left the firm (or the game) in the meantime
		end
		if tryLifeline then
			local okUse, used = Deps.call("ProfileService", "ConsumePerk", p, "alumni_lifeline")
			if okUse and used == true then
				svc:_setStatus(p, career, "probation")
				career.criticalStreak = 0
				CareerState.history(career, "lifeline", os.time(), { reason = "mass" })
				Deps.banner(p, { title = Tracks.text("lifeline_title"), subtitle = Tracks.text("lifeline_subtitle") })
				svc:Touch(p)
				return true
			end
		end
		svc:Fire(p, "mass")
		return false
	end

	-- ReviewService:Dismiss consumes the Lifeline itself and plays the meeting (phone call) for the player.
	local function dismiss(p: Player, tryLifeline: boolean)
		local saved: boolean
		local ok, outcome = Deps.call("ReviewService", "Dismiss", p, "mass", { reason = why })
		if ok and (outcome == "saved" or outcome == "fired") then
			saved = outcome == "saved"
		else
			saved = direct(p, tryLifeline)
		end
		table.insert(if saved then result.saved else result.fired, p)
	end
	for _, p in selection.fire do
		dismiss(p, false)
	end
	for _, p in selection.save do
		dismiss(p, true)
	end
	for _, p in selection.spare do
		svc:AddReputation(p, Roles.SURVIVOR_REP, "mass_firing_survivor")
		Deps.notify(p, Tracks.text("mass_firing_spared", { company = company.name, rep = Roles.SURVIVOR_REP }), "good")
	end
	return result
end

return Roles
