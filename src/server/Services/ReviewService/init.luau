--!strict
-- ReviewService (server, owned by `careerPath`; spec §6, design v3 §6 and §10): the weekly boss review.
--
-- Friday afternoon (CareerState: 36 active minutes into the week) CareerService calls OnDue: the objective says
-- "Your weekly review is ready. Head to <Boss>'s office." and CareerController draws a waypoint from
-- "Career.ReviewTarget" (Target.luau). The `boss_review` interact on the player's floor (employees only) runs the
-- meeting; after 10 overdue active minutes the boss phones and the review runs remotely, so nothing soft-locks.
--
-- A review: 35% risk-adjusted investment (PortfolioService:GetWindowMetrics over the week's active window), 25% risk,
-- 25% work quality, 15% reputation (Logic/Review) -> band -> Logic/Promotion (level cap, core work, score, outfit
-- level, school gate, OVR) -> Logic/CareerState.decide (promotion, coaching, probation, firing, Alumni Lifeline) ->
-- Friday pay (salary x company payMult + bonus by band, EconomyService) and living costs -> the next week.
-- The result is applied on the server at once (a disconnect mid-cinematic loses nothing); the client then plays the
-- ReviewMeeting screen from the "Career.Meeting" payload.
--
-- API:
--   ReviewService:OnDue(player, resumed)              objective + toast (CareerService week clock)
--   ReviewService:RunReview(player, mode) -> outcome?  mode "office" | "phone"
--   ReviewService:Dismiss(player, reason, info?) -> "saved" | "fired" | nil   forced firing: "risk" | "mass"
--   ReviewService:OnRiskViolation(player, info)       PortfolioService.RiskViolation (3 in a week or a major one fires)
--   ReviewService:GetTarget(player) -> Target.Info?
-- Remotes: "Career.ReviewTarget"() -> {kind, position, label}?   "Career.Meeting"(payload) (server -> client)
-- Interact: `boss_review` (OfficeAnchor review_spot / boss_chair on every floor).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local Leveling = require(Shared.Logic.Leveling)
local Review = require(Shared.Logic.Review)
local CareerState = require(Shared.Logic.CareerState)
local Promotion = require(Shared.Logic.Promotion)
local Registry = require(script.Parent.Parent.Registry)
local Deps = require(script.Parent.CareerService.Deps)
local Derive = require(script.Parent.CareerService.Derive)
local Prompts = require(script.Parent.CareerService.Prompts)
local Meeting = require(script.Meeting)
local Target = require(script.Target)

local ReviewService = { Name = "ReviewService", Priority = 35 }

ReviewService.Meeting = Meeting
ReviewService.Target = Target

local PROMPT_COOLDOWN = 1.5
local MAX_VIOLATIONS = 3
local COMPONENT_STATS: { [string]: { string } } = {
	investment = { "knowledge", "risk" },
	risk = { "risk", "discipline" },
	work = { "skill", "speed" },
	reputation = { "charisma", "network" },
}
local BAND_REP: { [string]: number } = { star = 6, on_track = 3, under = 0, probation = -2, critical = -4 }

local busy: { [Player]: boolean } = {}
local lastPrompt: { [Player]: number } = {}

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

local function career(): any
	return Registry.get("CareerService")
end

local function careerOf(player: Player): { [string]: any }?
	return Deps.career(player)
end

local function touch(player: Player)
	local svc = career()
	if svc then
		svc:Touch(player)
	end
end

---------------------------------------------------------------------------------------------------
-- Friday
---------------------------------------------------------------------------------------------------
function ReviewService:OnDue(player: Player, resumed: boolean?)
	local c = careerOf(player)
	if not c or not CareerState.isEmployed(c) or c.reviewDue ~= true then
		return
	end
	local boss = Companies.bossName(c.companyId, c.track)
	Deps.objective(player, Tracks.text("review_ready", { boss = boss }))
	Deps.notify(player, Tracks.text(if resumed then "review_ready" else "review_ready_toast", { boss = boss }), "info")
end

function ReviewService:GetTarget(player: Player): Target.Info?
	local c = careerOf(player)
	if not c or not CareerState.isEmployed(c) then
		return nil
	end
	return Target.get(player, c)
end

---------------------------------------------------------------------------------------------------
-- The review
---------------------------------------------------------------------------------------------------
local function hasBook(player: Player): boolean
	if not Deps.has("PortfolioService", "GetWindowMetrics") then
		return false
	end
	local data = Deps.data(player)
	local portfolio = if data then data.portfolio else nil
	if type(portfolio) == "table" and type(portfolio.bookSize) == "number" then
		return portfolio.bookSize > 0
	end
	return true
end

local function lastViolations(c: { [string]: any }): number
	local reviews = c.reviews
	local last = if type(reviews) == "table" then reviews[#reviews] else nil
	return if type(last) == "table" then num(last.violations, 0) else 0
end

local function tryLifeline(player: Player): boolean
	local okHas, has = Deps.call("ProfileService", "HasPerk", player, "alumni_lifeline")
	if not okHas or has ~= true then
		return false
	end
	local okUse, used = Deps.call("ProfileService", "ConsumePerk", player, "alumni_lifeline")
	return okUse and used == true
end

local function payWeek(
	player: Player,
	role: Tracks.RoleDef,
	company: Companies.CompanyDef?,
	band: string,
	fired: boolean
): { salary: number, bonus: number, living: number }
	local okMult, mult = Deps.call("EventService", "GetModifier", "bonusMult")
	local bonusMult = if okMult and type(mult) == "number" and mult == mult and mult > 0 then mult else 1
	local pay = Review.pay(role, company, band, { bonusMult = bonusMult, fired = fired })
	if pay.salary > 0 then
		Deps.call("EconomyService", "AddCash", player, pay.salary, "weekly_salary", "salary")
	end
	if pay.bonus > 0 then
		Deps.call("EconomyService", "AddCash", player, pay.bonus, "weekly_bonus", "bonus")
	end
	local data = Deps.data(player)
	local profile = if data and type(data.profile) == "table" then data.profile else {}
	local stats = if type(profile.stats) == "table" then profile.stats else {}
	local cost = Review.livingCost(role, company, num(stats.discipline, 50))
	local charged = 0
	if cost > 0 then
		local okLiving, result = Deps.call("EconomyService", "ChargeLiving", player, cost)
		charged = if okLiving and type(result) == "number" then math.max(0, math.floor(result)) else 0
	end
	return { salary = pay.salary, bonus = pay.bonus, living = charged }
end

local function strongest(components: Review.Components): string
	local best, score = "work", -1
	for _, id in Review.COMPONENTS do
		local v = (components :: any)[id] :: number
		if v > score then
			best, score = id, v
		end
	end
	return best
end

local function runReview(player: Player, c: { [string]: any }, mode: string): string?
	local svc = career()
	local company = Companies.get(c.companyId)
	local role = Tracks.rankDef(c.track, c.rank)
	if not svc or not role then
		return nil
	end
	local active = Deps.activeSeconds(player)
	local fromActive = num(c.weekStartActive, 0)
	local workCount = math.floor(num(if type(c.weekWork) == "table" then c.weekWork.count else 0, 0))
	local metrics: Review.Metrics? = nil
	local book = hasBook(player)
	if book then
		local okM, m =
			Deps.call("PortfolioService", "GetWindowMetrics", player, fromActive, math.max(fromActive, active))
		metrics = if okM and type(m) == "table" then m else nil
	end
	if not Deps.isLive(player) or careerOf(player) ~= c or c.reviewDue ~= true then
		return nil
	end
	local outfitLevel, _, required = Derive.outfit(player, c)
	local result = Review.evaluate({
		metrics = metrics,
		hasBook = book,
		work = c.weekWork,
		repWeek = num(c.weekRep, 0),
		meetsDress = outfitLevel >= required,
		recentViolations = num(if metrics then metrics.violations else 0, 0) + lastViolations(c),
	})
	c.outfitLevel = outfitLevel
	-- Firing depends only on the band and the streak; a week that keeps the job earns its review XP first, so a
	-- bonus that reaches the level cap counts toward this week's promotion (as in the Logic/Leveling simulator).
	local firing = CareerState.decide({
		status = c.status,
		criticalStreak = c.criticalStreak,
		band = result.band,
		promotable = false,
	})
	local xp = 0
	if not firing.fired then
		xp = svc:AddXP(player, Leveling.reviewXp(num(c.level, 1), result.band), "review")
	end
	local promo = Derive.promotion(player, c, result.band)
	local decision = CareerState.decide({
		status = c.status,
		criticalStreak = c.criticalStreak,
		band = result.band,
		promotable = promo.ready,
	})
	local lifeline = false
	if decision.fired and tryLifeline(player) then
		lifeline = true
		decision = CareerState.decide({
			status = c.status,
			criticalStreak = c.criticalStreak,
			band = result.band,
			promotable = false,
			hasLifeline = true,
		})
	end

	-- Friday pay (the week was worked even when it ends in a firing; no bonus then)
	local pay = payWeek(player, role, company, result.band, decision.fired)
	local prestige = 0
	if not decision.fired then
		prestige = Review.prestige(role, company, result.band)
		c.prestige = num(c.prestige, 0) + prestige
	end
	local rep = BAND_REP[result.band] or 0
	if rep ~= 0 then
		svc:AddReputation(player, rep, "review")
	end
	Deps.call(
		"ProfileService",
		"AwardStatXp",
		player,
		COMPONENT_STATS[strongest(result.components)],
		result.score,
		"review"
	)

	local reviewId = "r" .. math.floor(num(c.nextReviewId, 1))
	c.nextReviewId = math.floor(num(c.nextReviewId, 1)) + 1
	local entry = {
		id = reviewId,
		week = math.floor(num(c.week, 1)),
		score = result.score,
		band = result.band,
		outcome = decision.outcome,
		components = result.components,
		at = os.time(),
		companyId = c.companyId,
		roleId = c.roleId,
		title = c.title,
		investmentKind = result.investmentKind,
		alternative = result.alternative,
		lifeline = lifeline,
		fireReason = decision.fireReason,
		violations = math.floor(num(if metrics then metrics.violations else 0, 0)),
		pay = pay.salary + pay.bonus,
	}
	CareerState.recordReview(c, entry)
	c.criticalStreak = decision.criticalStreak

	local oldTitle = c.title
	local oldOffice = role.office == true
	local newRole: Tracks.RoleDef? = nil
	local blocked = if decision.outcome ~= "promoted" then Promotion.blocker(promo) else nil
	if decision.outcome == "promoted" then
		newRole = svc:Promote(player)
	end
	if decision.fired then
		svc:Fire(player, decision.fireReason or "critical")
	else
		svc:_setStatus(player, c, decision.status)
		if lifeline then
			CareerState.history(c, "lifeline", os.time())
		end
		CareerState.startWeek(c, Deps.activeSeconds(player))
		c.onboarded = true
		Deps.objective(player, nil)
	end

	local okCareer = career()
	if okCareer then
		okCareer.ReviewCompleted:Fire(player, table.clone(entry))
		okCareer._submitBoards(player)
	end
	Deps.audit(player, "career_review", { score = result.score, band = result.band, outcome = decision.outcome })
	touch(player)
	Deps.save(player, "review")

	local info = Derive.profileInfo(player)
	local nextRole = promo.nextRole
	local payload = Meeting.build({
		player = player,
		mode = mode,
		reviewId = reviewId,
		week = entry.week,
		companyId = entry.companyId,
		trackId = role.track,
		firstName = info.firstName,
		title = oldTitle,
		newTitle = if newRole then newRole.title else nil,
		newOffice = newRole ~= nil and newRole.office == true and not oldOffice,
		score = result.score,
		band = result.band,
		components = result.components,
		investmentKind = result.investmentKind,
		workCount = workCount,
		excess = if metrics then metrics.excess else nil,
		outcome = decision.outcome,
		status = if decision.fired then "fired" else decision.status,
		lifeline = lifeline,
		fireReason = decision.fireReason,
		blocked = blocked,
		blockedNeed = if blocked == "outfit" then promo.needOutfit else nil,
		blockedTier = if blocked == "school"
				and nextRole
				and nextRole.schoolGate
			then Tracks.tierName(nextRole.schoolGate)
			else nil,
		missing = if decision.outcome == "keep_going" then promo.missing else {},
		pay = pay,
		xp = xp,
		prestige = prestige,
		breakdown = true,
	})
	Meeting.send(player, payload)
	return decision.outcome
end

function ReviewService:RunReview(player: Player, mode: string?): string?
	if busy[player] then
		return nil
	end
	local c = careerOf(player)
	if not c or not CareerState.isEmployed(c) or c.reviewDue ~= true then
		return nil
	end
	busy[player] = true
	local ok, res = pcall(function()
		return runReview(player, c, if mode == "office" then "office" else "phone")
	end)
	busy[player] = nil
	if not ok then
		warn("[ReviewService] review failed: " .. tostring(res))
		return nil
	end
	return res
end

---------------------------------------------------------------------------------------------------
-- Forced dismissals: major risk violations and mass firings (design v3 §6, §10)
---------------------------------------------------------------------------------------------------
function ReviewService:Dismiss(player: Player, reason: string, _info: any?): string?
	local svc = career()
	local c = careerOf(player)
	if not svc or not c or not CareerState.isEmployed(c) then
		return nil
	end
	local waited = 0
	while busy[player] and waited < 10 do
		task.wait(0.25)
		waited += 0.25
	end
	c = careerOf(player)
	if not c or not CareerState.isEmployed(c) or not Deps.isLive(player) then
		return nil
	end
	busy[player] = true
	local ok, res = pcall(function(): string
		local cc = c :: { [string]: any }
		local lifeline = tryLifeline(player)
		local decision = CareerState.decide({
			status = cc.status,
			criticalStreak = cc.criticalStreak,
			band = if type(cc.lastBand) == "string" and cc.lastBand ~= "" then cc.lastBand else "under",
			promotable = false,
			hasLifeline = lifeline,
			forceFire = reason,
		})
		local title = cc.title
		local companyId = cc.companyId
		local track = cc.track
		local week = math.floor(num(cc.week, 1))
		if decision.lifelineUsed then
			svc:_setStatus(player, cc, "probation")
			cc.criticalStreak = 0
			cc.weekViolations = 0
			CareerState.history(cc, "lifeline", os.time(), { reason = reason })
			touch(player)
		else
			svc:Fire(player, reason)
		end
		local info = Derive.profileInfo(player)
		Meeting.send(
			player,
			Meeting.build({
				player = player,
				mode = "phone",
				opening = if reason == "risk" then "discipline" else "layoff",
				reviewId = nil,
				week = week,
				companyId = companyId,
				trackId = track,
				firstName = info.firstName,
				title = title,
				outcome = decision.outcome,
				status = if decision.fired then "fired" else "probation",
				band = nil,
				lifeline = decision.lifelineUsed,
				fireReason = reason,
				breakdown = false,
			})
		)
		return if decision.lifelineUsed then "saved" else "fired"
	end)
	busy[player] = nil
	if not ok then
		warn("[ReviewService] dismissal failed: " .. tostring(res))
		return nil
	end
	return res
end

function ReviewService:OnRiskViolation(player: Player, info: any)
	local c = careerOf(player)
	if not c or not CareerState.isEmployed(c) then
		return
	end
	local major = type(info) == "table"
		and (info.major == true or info.severity == "major" or info.level == "major" or info.kind == "major")
	c.weekViolations = math.floor(num(c.weekViolations, 0)) + 1
	if major or c.weekViolations >= MAX_VIOLATIONS then
		local company = Companies.get(c.companyId)
		Deps.notify(
			player,
			Tracks.text("risk_violation_meeting", {
				boss = Companies.bossName(c.companyId, c.track),
				company = if company then company.name else "",
			}),
			"bad"
		)
		task.spawn(function()
			ReviewService:Dismiss(player, "risk", info)
		end)
	else
		Deps.notify(player, Tracks.text("risk_warning", { count = c.weekViolations, max = MAX_VIOLATIONS }), "warn")
		touch(player)
	end
end

---------------------------------------------------------------------------------------------------
-- The boss_review interact
---------------------------------------------------------------------------------------------------
local function onBossPrompt(player: Player, _prompt: ProximityPrompt, companyId: string?, _inst: Instance)
	local now = os.clock()
	if now - (lastPrompt[player] or 0) < PROMPT_COOLDOWN then
		return
	end
	lastPrompt[player] = now
	local svc = career()
	local c = careerOf(player)
	if not svc or not c then
		return
	end
	local company = if companyId then Companies.get(companyId) else nil
	if companyId and not svc:IsEmployeeOf(player, companyId) then
		Deps.notify(player, Tracks.text("employees_only", { company = if company then company.name else "" }), "warn")
		return
	end
	if not CareerState.isEmployed(c) then
		Deps.notify(player, Tracks.text("review_not_employed"), "info")
		return
	end
	if companyId and c.companyId ~= companyId then
		Deps.notify(
			player,
			Tracks.text("review_wrong_firm", { company = if company then company.name else "" }),
			"info"
		)
		return
	end
	if busy[player] then
		Deps.notify(player, Tracks.text("review_busy"), "info")
		return
	end
	if c.reviewDue ~= true then
		local minutes = math.max(1, math.ceil(CareerState.windowRemaining(c) / 60))
		Deps.notify(player, Tracks.text("review_not_due", { minutes = minutes }), "info")
		return
	end
	ReviewService:RunReview(player, "office")
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function ReviewService:Init()
	Net.declare(Meeting.REMOTE)
	Net.handle("Career.ReviewTarget", function(player: Player): any
		local info = ReviewService:GetTarget(player)
		if not info then
			return nil
		end
		return { kind = info.kind, position = info.position, label = info.label }
	end, { rate = 1, burst = 4 })
end

-- Floors whose template has no boss_review interact still get a review prompt, on the boss NPC itself.
local function onFloorCreated(spec: Prompts.Spec, companyId: any, trackId: any, model: any)
	if type(companyId) ~= "string" or type(trackId) ~= "string" or trackId == "lobby" then
		return
	end
	if typeof(model) ~= "Instance" then
		return
	end
	for _ = 1, 30 do
		task.wait(1)
		if not model.Parent then
			return
		end
		for _, part in Prompts.find("boss_review", companyId, trackId) do
			if part:IsDescendantOf(model) then
				return
			end
		end
		local ok, npc = Deps.call("OfficeService", "GetBossNpc", companyId, trackId)
		if ok and typeof(npc) == "Instance" and npc:IsDescendantOf(model) then
			Prompts.wireInstance(npc, spec)
			return
		end
	end
end

function ReviewService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		busy[player] = nil
		lastPrompt[player] = nil
	end)
	local spec: Prompts.Spec = {
		interactId = "boss_review",
		promptName = "BossReviewPrompt",
		actionText = Tracks.text("prompt_review_action"),
		objectText = Tracks.text("prompt_review_object"),
		objectTextFor = function(inst: Instance, companyId: string?): string?
			if not companyId then
				return nil
			end
			return Companies.bossName(companyId, Prompts.departmentOf(inst) or "ib")
		end,
		onTriggered = onBossPrompt,
	}
	Prompts.start(spec)
	Deps.connect("OfficeService", "FloorCreated", function(companyId: any, trackId: any, model: any)
		task.spawn(onFloorCreated, spec, companyId, trackId, model)
	end)
end

return ReviewService
