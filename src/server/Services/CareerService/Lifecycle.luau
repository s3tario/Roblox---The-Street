--!strict
-- CareerService/Lifecycle (server, runtime only): when the career loads, resumes and ticks.
--   * profile loaded: repair the save (Normalize), derive + replicate, then resume the objective a moment later
--     (review ready, "find your tower", or Career Services after a firing)
--   * ActivityService.ActiveTick: the work week clock (CareerState.tickWeek). Friday afternoon tells ReviewService
--     the review is due; after 10 overdue active minutes the boss phones (ReviewService:RunReview "phone"). A call
--     that fails rings again two active minutes later, so the week can never stall.
--   * OfficeService.LocationChanged: the first visit to the player's own firm ends the onboarding objective
--   * the `career_services` interact opens the Career Services screen
--
--   Lifecycle.bind(svc)     in CareerService:Init (DataService.ProfileLoaded)
--   Lifecycle.start(svc)    in CareerService:Start

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local CareerState = require(Shared.Logic.CareerState)
local Deps = require(script.Parent.Deps)
local Normalize = require(script.Parent.Normalize)
local Prompts = require(script.Parent.Prompts)

local Lifecycle = {}

Lifecycle.COUNTDOWN_REFRESH = 60 -- re-replicate the HUD countdown about once an active minute
Lifecycle.RESUME_DELAY = 3
Lifecycle.SERVICES_COOLDOWN = 1
Lifecycle.CALL_RETRY = 120 -- active seconds before a failed phone review rings again

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

local function resume(svc: any, player: Player)
	local career = svc._careerOf(player)
	if not career then
		return
	end
	if career.status == "fired" then
		Deps.objective(player, Tracks.text("fired_objective"))
	elseif CareerState.isEmployed(career) then
		if career.reviewDue then
			Deps.call("ReviewService", "OnDue", player, true)
		elseif career.onboarded ~= true then
			Deps.objective(player, Tracks.text("objective_report", { company = companyName(career.companyId) }))
		end
	end
end

local function onProfileLoaded(svc: any, player: Player)
	local career = svc._careerOf(player)
	if not career or not Deps.isLive(player) then
		return
	end
	svc._ensureState(player)
	local ok, err = pcall(function()
		Normalize.apply(career)
	end)
	if not ok then
		warn("[CareerService] normalize failed: " .. tostring(err))
	end
	svc:Touch(player)
	task.delay(Lifecycle.RESUME_DELAY, function()
		if Deps.isLive(player) then
			resume(svc, player)
		end
	end)
end

local function phoneReview(svc: any, player: Player)
	local ok, outcome = Deps.call("ReviewService", "RunReview", player, "phone")
	if ok and outcome ~= nil then
		return
	end
	local career = svc._careerOf(player)
	if career and career.reviewDue == true and Deps.isLive(player) then
		career.remoteCalled = false
		career.overdueActive = math.min(num(career.overdueActive, 0), CareerState.REMOTE_AFTER - Lifecycle.CALL_RETRY)
	end
end

local function onActiveTick(svc: any, player: Player, dt: number)
	local career = svc._careerOf(player)
	local st = svc._state(player)
	if not career or not st or not CareerState.isEmployed(career) then
		return
	end
	local ev = CareerState.tickWeek(career, dt)
	if ev.dayChanged then
		Deps.notify(player, Tracks.text("new_day", { day = Tracks.text("day_long_" .. ev.dayChanged) }), "info")
		svc:Touch(player)
	end
	if ev.reviewDue then
		Deps.call("ReviewService", "OnDue", player, false)
		svc:Touch(player)
	end
	if ev.remoteReview then
		task.spawn(phoneReview, svc, player)
	end
	local now = os.clock()
	if now - st.lastCountdown >= Lifecycle.COUNTDOWN_REFRESH then
		st.lastCountdown = now
		svc:Touch(player)
	end
end

local function onLocationChanged(svc: any, player: Player, location: any)
	local career = svc._careerOf(player)
	if not career or not CareerState.isEmployed(career) or career.onboarded == true then
		return
	end
	if type(location) == "table" and location.companyId == career.companyId then
		career.onboarded = true
		if not career.reviewDue then
			Deps.objective(player, nil)
		end
		svc:Touch(player)
	end
end

local function onServicesPrompt(svc: any, player: Player, companyId: string?)
	local st = svc._state(player)
	if not st then
		return
	end
	local now = os.clock()
	if now - st.lastServicesOpen < Lifecycle.SERVICES_COOLDOWN then
		return
	end
	st.lastServicesOpen = now
	-- a Career Services point placed inside an office only serves that firm's employees
	if companyId and not svc:IsEmployeeOf(player, companyId) then
		Deps.notify(player, Tracks.text("employees_only", { company = companyName(companyId) }), "warn")
		return
	end
	svc:OpenServices(player)
end

function Lifecycle.bind(svc: any)
	Deps.connect("DataService", "ProfileLoaded", function(player: Player)
		onProfileLoaded(svc, player)
	end)
end

function Lifecycle.start(svc: any)
	Players.PlayerRemoving:Connect(function(player: Player)
		svc._dropState(player)
	end)
	for _, player in Players:GetPlayers() do
		if Deps.isLoaded(player) and not svc._state(player) then
			task.spawn(onProfileLoaded, svc, player)
		end
	end
	Deps.connect("ActivityService", "ActiveTick", function(player: Player, dt: number)
		onActiveTick(svc, player, dt)
	end)
	Deps.connect("WardrobeService", "LookChanged", function(player: Player)
		svc:Touch(player)
	end)
	Deps.connect("ProfileService", "ProfileLocked", function(player: Player)
		svc:Touch(player)
	end)
	Deps.connect("OfficeService", "LocationChanged", function(player: Player, location: any)
		onLocationChanged(svc, player, location)
	end)
	Deps.connect("PortfolioService", "RiskViolation", function(player: Player, info: any)
		Deps.call("ReviewService", "OnRiskViolation", player, info)
	end)
	Prompts.start({
		interactId = "career_services",
		promptName = "CareerServicesPrompt",
		actionText = Tracks.text("prompt_services_action"),
		objectText = Tracks.text("prompt_services_object"),
		onTriggered = function(player: Player, _prompt: ProximityPrompt, companyId: string?, _inst: Instance)
			onServicesPrompt(svc, player, companyId)
		end,
	})
end

return Lifecycle
