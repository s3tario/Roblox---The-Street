--!strict
-- CareerService/Recovery (server, runtime only): the firing and the way back (spec §6 "Wipeout" and "Recovery",
-- design v3 §6). No pop-ups and no timers: the Career Services screen lists the options calmly.
--
--   Recovery.fire(svc, player, career, reason) -> Wipeout     the wipeout (job, pipeline, 25% band XP, book to 10%)
--   Recovery.info(svc, player) -> table                       everything the CareerServices screen shows
--   Recovery.reentry(svc, player, action, answers?) -> (ok, err?, view?, result?)
--       action "start" (new attempt, or the one in progress) | "view" | "submit" (grades the current stage)
--       passing rejoins the former firm one rank lower with a modest book
--   Recovery.reinstate(svc, player) -> (ok, err?)             spends a Career Reinstatement credit
--   Recovery.useCapital(svc, player) -> (ok, err?)            Capital Reconstruction (PortfolioService)
--   Recovery.freshStart(svc, player) -> (ok, err?)            back to campus recruiting
-- Error keys: not_loaded | not_fired | no_credit | capital_unavailable | no_reentry | done | bad_answers

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Hash = require(Shared.Util.Hash)
local Rng = require(Shared.Util.Rng)
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local CareerState = require(Shared.Logic.CareerState)
local Leveling = require(Shared.Logic.Leveling)
local Reentry = require(Shared.Logic.Projects.reentry)
local Deps = require(script.Parent.Deps)

local Recovery = {}

Recovery.FALLBACK_COMPANY = "sterling_vance"
Recovery.REENTRY_BOOK = 0.5
Recovery.RENDERABLE = { mcq = true, dialogue = true } :: { [string]: boolean }

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

local function companyName(id: any): string
	local c = Companies.get(id)
	return if c then c.name else ""
end

-- The firm a comeback returns to: the former one while it still hires for the track.
local function returnCompany(fired: { [string]: any }): string
	local id = fired.companyId
	if type(id) == "string" and Companies.hiring(id, fired.track) then
		return id
	end
	return Recovery.FALLBACK_COMPANY
end

---------------------------------------------------------------------------------------------------
-- Firing
---------------------------------------------------------------------------------------------------
function Recovery.fire(svc: any, player: Player, career: { [string]: any }, reason: string): CareerState.Wipeout
	local data = Deps.data(player)
	local portfolio = if data then data.portfolio else nil
	local role = Tracks.rankDef(career.track, career.rank)
	local company = Companies.get(career.companyId)
	local bookSize = if type(portfolio) == "table" and num(portfolio.bookSize, 0) > 0
		then portfolio.bookSize
		else (if role then role.book else 0) * (if company then company.bookMult else 1)
	local oldRole = if type(career.roleId) == "string" then career.roleId else ""
	local oldStatus = if type(career.status) == "string" then career.status else "active"
	local oldLevel = math.floor(num(career.level, 1))
	local w = CareerState.wipeout(career, { reason = reason, now = os.time(), bookSize = bookSize })
	if career.level ~= oldLevel then
		svc.LevelChanged:Fire(player, career.level, oldLevel)
	end
	task.spawn(function()
		Deps.call("PortfolioService", "WipeBook", player)
	end)
	-- the active deal pipeline goes with the job (projects feature)
	Deps.call("ProjectService", "CancelActive", player, "fired")
	CareerState.history(career, "fired", os.time(), {
		reason = reason,
		title = w.title,
		companyId = w.companyId,
	})
	svc.StatusChanged:Fire(player, "fired", oldStatus)
	svc.RoleChanged:Fire(player, Tracks.UNEMPLOYED_ROLE, oldRole, "fired")
	Deps.objective(player, Tracks.text("fired_objective"))
	Deps.call("EmailService", "Send", player, {
		from = Tracks.text("mail_hr_from", { company = companyName(w.companyId) }),
		subject = Tracks.text("mail_fired_subject"),
		body = Tracks.text("mail_fired_body", { title = w.title, company = companyName(w.companyId) }),
		kind = "hr",
	})
	Deps.audit(player, "career_fired", { reason = reason, companyId = w.companyId, lostXp = w.lostXp })
	svc:Touch(player)
	Deps.save(player, "fired")
	return w
end

---------------------------------------------------------------------------------------------------
-- Career Services info
---------------------------------------------------------------------------------------------------
local function reentryCtx(player: Player): Reentry.Ctx
	local tasks: { [string]: any } = {}
	local logic = Shared:FindFirstChild("Logic")
	local folder = if logic then logic:FindFirstChild("Tasks") else nil
	if folder then
		for _, taskId in Reentry.TASKS do
			local mod = folder:FindFirstChild(taskId)
			if mod and mod:IsA("ModuleScript") then
				local ok, res = pcall(require, mod)
				if ok and type(res) == "table" then
					tasks[taskId] = res
				end
			end
		end
	end
	local data = Deps.data(player)
	local profile = if data and type(data.profile) == "table" then data.profile else {}
	local stats = if type(profile.stats) == "table" then profile.stats else {}
	local charisma = num(stats.charisma, 50)
	local career = Deps.career(player)
	local fired = if career and type(career.fired) == "table" then career.fired else {}
	return {
		tasks = tasks,
		canRender = function(kind: string): boolean
			return Recovery.RENDERABLE[kind] == true
		end,
		taskCtx = {
			level = if career then num(career.level, 1) else 1,
			rank = num(fired.rank, 1),
			track = if type(fired.track) == "string" then fired.track else "ib",
			stats = stats,
			ovr = num(profile.ovr, 50),
			difficulty = 0.4,
			hints = 1,
			toleranceMult = 1,
			charismaBonus = math.clamp((charisma - 50) / 49 * 8, 0, 8),
		},
		charismaBonus = math.clamp((charisma - 50) / 49 * 8, 0, 8),
	}
end

-- The attempt in progress lives in the private data.careerPrivate (it holds the answer key).
local function privateOf(player: Player): { [string]: any }?
	local data = Deps.data(player)
	if not data then
		return nil
	end
	if type(data.careerPrivate) ~= "table" then
		data.careerPrivate = { reentry = {} }
	end
	return data.careerPrivate
end

local function currentReentry(player: Player): Reentry.State?
	local priv = privateOf(player)
	local state = if priv then priv.reentry else nil
	if type(state) == "table" and type(state.stages) == "table" and type(state.stageIndex) == "number" then
		return state :: Reentry.State
	end
	return nil
end

local function setReentry(player: Player, state: Reentry.State?)
	local priv = privateOf(player)
	if priv then
		priv.reentry = if state then state else {}
	end
end
Recovery.clearReentry = function(player: Player)
	setReentry(player, nil)
end

local function capitalCredits(player: Player): number
	local data = Deps.data(player)
	local portfolio = if data then data.portfolio else nil
	local credits = if type(portfolio) == "table" then portfolio.credits else nil
	return if type(credits) == "table" then math.floor(num(credits.capital, 0)) else 0
end

function Recovery.info(_svc: any, player: Player): { [string]: any }
	local career = Deps.career(player)
	if not career then
		return { loaded = false }
	end
	local info: { [string]: any } = {
		loaded = true,
		status = career.status,
		employed = CareerState.isEmployed(career),
		title = career.title,
		companyName = companyName(career.companyId),
		reinstateCredits = math.floor(num(career.reinstateCredits, 0)),
		capitalCredits = capitalCredits(player),
		capitalUsable = Deps.has("PortfolioService", "UseCapitalCredit"),
		storeAvailable = Deps.has("MonetizationService", "OwnsPass"),
		offers = if type(career.offers) == "table" then #career.offers else 0,
	}
	local f = career.fired
	if career.status == "fired" and type(f) == "table" then
		local formerRank = math.max(1, math.floor(num(f.rank, 1)))
		local lower = Tracks.rankDef(f.track, math.max(1, formerRank - 1))
		local returnTo = returnCompany(f)
		info.fired = {
			reason = f.reason,
			companyName = companyName(f.companyId),
			title = f.title,
			lostXp = math.floor(num(f.lostXp, 0)),
			lostBook = math.floor(num(f.lostBook, 0)),
			newBook = math.floor(num(f.newBook, 0)),
			reentryTitle = if lower then lower.title else "",
			returnCompany = companyName(returnTo),
			capitalUsed = f.capitalUsed == true,
		}
		local state = currentReentry(player)
		if state then
			info.reentry = Reentry.view(state, nil)
		end
	end
	local okCan, can, reason = Deps.call2("RebirthService", "CanRebirth", player)
	info.rebirth = {
		available = okCan,
		can = okCan and can == true,
		reason = if type(reason) == "string" then reason else nil,
	}
	return info
end

---------------------------------------------------------------------------------------------------
-- Re-entry
---------------------------------------------------------------------------------------------------
local function comeback(svc: any, player: Player, career: { [string]: any }, kind: string): (boolean, string?)
	local f = career.fired
	if career.status ~= "fired" or type(f) ~= "table" then
		return false, "not_fired"
	end
	local companyId = returnCompany(f)
	local oldLevel = math.floor(num(career.level, 1))
	local ok, err = CareerState.restore(career, {
		kind = kind,
		now = os.time(),
		active = Deps.activeSeconds(player),
		companyId = companyId,
	})
	if not ok then
		return false, err
	end
	if career.level ~= oldLevel then
		svc.LevelChanged:Fire(player, career.level, oldLevel)
	end
	career.onboarded = false
	setReentry(player, nil)
	svc._topBook(player, career, kind, Recovery.REENTRY_BOOK)
	CareerState.history(career, kind, os.time(), { title = career.title })
	svc.StatusChanged:Fire(player, career.status, "fired")
	svc.RoleChanged:Fire(player, career.roleId, Tracks.UNEMPLOYED_ROLE, kind)
	local company = companyName(companyId)
	Deps.banner(player, {
		title = Tracks.text(if kind == "reentry" then "reentry_passed_title" else "reinstated_title"),
		subtitle = Tracks.text("hired_subtitle", { title = career.title, company = company }),
		style = "celebration",
		duration = 6,
	})
	Deps.objective(player, Tracks.text("objective_report", { company = company }))
	Deps.audit(player, "career_" .. kind, { companyId = companyId, roleId = career.roleId })
	svc._submitBoards(player)
	svc:Touch(player)
	Deps.save(player, kind)
	return true, nil
end

function Recovery.reentry(svc: any, player: Player, action: string, answers: any): (boolean, string?, any, any)
	local career = Deps.career(player)
	if not career then
		return false, "not_loaded", nil, nil
	end
	if career.status ~= "fired" or type(career.fired) ~= "table" then
		return false, "not_fired", nil, nil
	end
	local f = career.fired
	local state = currentReentry(player)
	if action == "view" then
		return true, nil, if state then Reentry.view(state, nil) else nil, nil
	end
	if action == "start" then
		if state and not state.done then
			return true, nil, Reentry.view(state, nil), nil
		end
		f.attempts = math.floor(num(f.attempts, 0)) + 1
		local rng = Rng.new(Hash.u32("reentry", player.UserId, os.time(), f.attempts))
		local fresh = Reentry.new(rng, reentryCtx(player))
		setReentry(player, fresh)
		Deps.notify(player, Tracks.text("reentry_started"), "info")
		svc:Touch(player)
		return true, nil, Reentry.view(fresh, nil), nil
	end
	-- submit
	if not state then
		return false, "no_reentry", nil, nil
	end
	if state.done then
		return false, "done", Reentry.view(state, nil), nil
	end
	local ctx = reentryCtx(player)
	local nextState, result = Reentry.act(state, answers, ctx)
	setReentry(player, nextState)
	if not result.ok then
		return false, result.err or "bad_answers", Reentry.view(nextState, nil), result
	end
	if result.done then
		if result.passed then
			local ok, err = comeback(svc, player, career, "reentry")
			if not ok then
				return false, err, nil, result
			end
			local view = Reentry.view(nextState, nil)
			return true, nil, view, result
		end
		Deps.notify(player, Tracks.text("reentry_failed", { score = result.quality, need = Reentry.PASS }), "warn")
	end
	svc:Touch(player)
	return true, nil, Reentry.view(nextState, nil), result
end

---------------------------------------------------------------------------------------------------
-- Reinstatement, capital, fresh start
---------------------------------------------------------------------------------------------------
function Recovery.reinstate(svc: any, player: Player): (boolean, string?)
	local career = Deps.career(player)
	if not career then
		return false, "not_loaded"
	end
	if career.status ~= "fired" then
		return false, "not_fired"
	end
	local credits = math.floor(num(career.reinstateCredits, 0))
	if credits <= 0 then
		return false, "no_credit"
	end
	career.reinstateCredits = credits - 1
	local ok, err = comeback(svc, player, career, "reinstated")
	if not ok then
		career.reinstateCredits = credits
		return false, err
	end
	return true, nil
end

function Recovery.useCapital(svc: any, player: Player): (boolean, string?)
	local career = Deps.career(player)
	if not career then
		return false, "not_loaded"
	end
	local f = career.fired
	if career.status ~= "fired" or type(f) ~= "table" then
		return false, "not_fired"
	end
	if capitalCredits(player) <= 0 then
		return false, "no_credit"
	end
	local ok, result = Deps.call("PortfolioService", "UseCapitalCredit", player, math.floor(num(f.lostBook, 0)))
	if not ok or result == false then
		return false, "capital_unavailable"
	end
	f.capitalUsed = true
	Deps.notify(player, Tracks.text("capital_used"), "good")
	Deps.audit(player, "career_capital_credit", { lostBook = f.lostBook })
	svc:Touch(player)
	return true, nil
end

function Recovery.freshStart(svc: any, player: Player): (boolean, string?)
	local career = Deps.career(player)
	if not career then
		return false, "not_loaded"
	end
	if career.status ~= "fired" then
		return false, "not_fired"
	end
	local oldRole = if type(career.roleId) == "string" then career.roleId else Tracks.UNEMPLOYED_ROLE
	CareerState.freshStart(career)
	setReentry(player, nil)
	-- the level stays; banked XP stays capped by the student band until the next job
	career.xp = math.min(num(career.xp, 0), Leveling.xpForLevel(math.floor(num(career.level, 1))))
	local data = Deps.data(player)
	if data and type(data.campus) == "table" then
		data.campus.offer = false
		Deps.replicate(player, "campus")
	end
	Deps.call("TutorialService", "ResetRecruiting", player)
	CareerState.history(career, "fresh_start", os.time())
	svc.StatusChanged:Fire(player, "student", "fired")
	svc.RoleChanged:Fire(player, Tracks.STUDENT.roleId, oldRole, "fresh_start")
	Deps.objective(player, Tracks.text("fresh_start_done"))
	Deps.notify(player, Tracks.text("fresh_start_done"), "info")
	Deps.audit(player, "career_fresh_start", {})
	svc:Touch(player)
	Deps.save(player, "fresh_start")
	return true, nil
end

return Recovery
