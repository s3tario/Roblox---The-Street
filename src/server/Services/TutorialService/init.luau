--!strict
-- TutorialService (server, owned by `tutorial`; design v1 §2, v3 §2 and §19 M1): the onboarding chain from the
-- Eastbridge bus depot to the first weekly review, then ongoing guidance from the promotion checklist.
-- Rules: Logic/QuestLine (pure). Steps: Config/Quests. Data: data.campus (Config/DataTemplate/Campus).
--
-- Each player's chain is reconciled from real signals (Life Roll locked, tasks finished, trades, offers, the player's
-- zone and office location, NPC conversations) plus a 1 s poll, so a missed signal only delays a step. Every step
-- sets the HUD objective (QuestService:SetObjective "onboarding") and a waypoint (QuestService:SetWaypoint). A
-- non-core step offers a skip after 10 active minutes, and street steps step back to recruiting when the player is
-- no longer hired (a fresh start), so nothing soft-locks.
--
-- API:
--   TutorialService:GetStep(player) -> stepId?           TutorialService:GetStatus(player) -> Status?
--   TutorialService:CompleteStep(player, stepId, how?) -> boolean   (NPC conversations; marks it when not current)
--   TutorialService:Skip(player) -> (ok, errKey?)        TutorialService:Ack(player, infoId)
--   TutorialService:ShowInfo(player, infoId)             ("review_intro": how weekly reviews work)
--   TutorialService:JoinClub(player) -> boolean          TutorialService:AddContact(player, key) -> (added, count)
--   TutorialService:ResetRecruiting(player)              careerPath: a fresh start after a firing
--   TutorialService:OpenRecruiting(player)               TutorialService:GetRecruitingBoard(player) -> board?
--   TutorialService:Refresh(player)                      re-evaluate soon (other services call this after a change)
-- Signals: StepCompleted(player, stepId, how)   ChainFinished(player)
-- Remotes: "Tutorial.Info"(info) and "Tutorial.Skippable"(stepId) server -> client; the recruiting remotes live in
--   TutorialService/Recruiting.
-- Interact: `bulletin` (the campus Recruiting Board).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Quests = require(Shared.Config.Quests)
local Tracks = require(Shared.Config.Tracks)
local CareerState = require(Shared.Logic.CareerState)
local QuestLine = require(Shared.Logic.QuestLine)
local Deps = require(script.Deps)
local Facts = require(script.Facts)
local Waypoints = require(script.Waypoints)
local Recruiting = require(script.Recruiting)

local TutorialService = {
	Name = "TutorialService",
	Priority = 50,
	StepCompleted = Signal.new(), -- (player, stepId, how)
	ChainFinished = Signal.new(), -- (player)
}

TutorialService.Deps = Deps
TutorialService.Facts = Facts
TutorialService.Waypoints = Waypoints
TutorialService.Recruiting = Recruiting
TutorialService.Interacts = require(script.Interacts)

local POLL = 1
local WAYPOINT_EVERY = 3
local BANNER_DELAY = 2.5
local INFO_REMOTE = "Tutorial.Info"
local SKIP_REMOTE = "Tutorial.Skippable"

type PState = {
	primed: boolean, -- the first reconcile after load is silent (an old save may finish many steps at once)
	ready: boolean, -- setup ran (character hooks connected)
	queued: boolean,
	lastStep: string?,
	lastWaypoint: number,
	skipNotified: string?,
	activeTicks: boolean,
	conns: { RBXScriptConnection },
}

local states: { [Player]: PState } = {}

local function stateOf(player: Player): PState
	local st = states[player]
	if not st then
		st = {
			primed = false,
			ready = false,
			queued = false,
			lastStep = nil,
			lastWaypoint = -math.huge,
			skipNotified = nil,
			activeTicks = false,
			conns = {},
		}
		states[player] = st
	end
	return st
end

local function text(key: string, vars: { [string]: any }?): string
	return Quests.text(key, vars)
end

local function firstName(data: { [string]: any }, player: Player): string
	local p = data.profile
	if type(p) == "table" and type(p.firstName) == "string" and p.firstName ~= "" then
		return p.firstName
	end
	return player.DisplayName
end

---------------------------------------------------------------------------------------------------
-- Objectives and waypoints
---------------------------------------------------------------------------------------------------
local function guideText(career: { [string]: any }): string?
	if not CareerState.isEmployed(career) then
		return nil
	end
	local promo = if type(career.promotion) == "table" then career.promotion else {}
	if promo.ready == true then
		return text("guide_ready", { boss = Facts.bossName(career) or text("your_boss") })
	end
	local missing = if type(promo.missing) == "table" then promo.missing else {}
	local need = missing[1]
	if type(need) == "string" and need ~= "" then
		local nextTitle = if type(promo.next) == "string" and promo.next ~= "" then promo.next else nil
		if nextTitle then
			return text("guide_next", { title = nextTitle, need = need })
		end
		return need
	end
	if Deps.num(career.rank, 0) >= Tracks.topRank(career.track) and Deps.num(career.rank, 0) > 0 then
		return text("guide_top")
	end
	return text("guide_default")
end

local function pushObjective(player: Player, campus: { [string]: any }, facts: QuestLine.Facts, career: any)
	if QuestLine.finished(campus) then
		Deps.call("QuestService", "SetObjective", player, Quests.CHAIN_ID, nil)
		Deps.call("QuestService", "SetObjective", player, Quests.GUIDE_ID, guideText(career))
	else
		Deps.call("QuestService", "SetObjective", player, Quests.GUIDE_ID, nil)
		Deps.call("QuestService", "SetObjective", player, Quests.CHAIN_ID, QuestLine.objective(campus, facts))
	end
end

local function pushWaypoint(player: Player, campus: { [string]: any }, facts: QuestLine.Facts, career: any)
	local st = stateOf(player)
	st.lastWaypoint = os.clock()
	local step = QuestLine.current(campus)
	if not step or not step.waypoint or QuestLine.paused(campus, facts) then
		Deps.call("QuestService", "SetWaypoint", player, Quests.CHAIN_ID, nil, nil)
		return
	end
	local ok, pos, label = pcall(Waypoints.resolve, player, step.waypoint, { career = career, campus = campus })
	if not ok then
		Deps.warnOnce("waypoint " .. step.id, pos)
		pos, label = nil, nil
	end
	Deps.call("QuestService", "SetWaypoint", player, Quests.CHAIN_ID, pos, label or step.title)
end

---------------------------------------------------------------------------------------------------
-- Steps
---------------------------------------------------------------------------------------------------
local function onEnter(player: Player, step: Quests.StepDef, silent: boolean)
	local offer = if step.enter then step.enter.offerTask else nil
	if offer then
		Deps.call("WorkService", "OfferTask", player, offer, { source = "tutorial", silent = silent })
	end
	if step.id == "review_intro" then
		TutorialService:ShowInfo(player, "review_intro")
	elseif step.id == "recruiting" then
		Recruiting.offerNext(player)
	end
end

local function announce(player: Player, completed: { QuestLine.Completed }, quiet: boolean)
	for _, c in completed do
		local step = Quests.stepById[c.id]
		if step then
			TutorialService.StepCompleted:Fire(player, c.id, c.how)
			if c.how == "auto" or c.how == "skip" then
				Deps.call("AchievementService", "Record", player, { kind = "step", step = c.id })
			end
			if not quiet and (c.how == "auto" or c.how == "skip") then
				Deps.notify(
					player,
					text(if c.how == "skip" then "step_skipped" else "step_done", { title = step.title }),
					"good"
				)
				if step.milestone and c.how == "auto" then
					Deps.banner(player, {
						title = step.title,
						subtitle = step.hint,
						style = "celebration",
						duration = 4,
					})
				end
			end
		end
	end
end

local function finishChain(player: Player, data: { [string]: any }, quiet: boolean)
	TutorialService.ChainFinished:Fire(player)
	Deps.call("AchievementService", "Record", player, { kind = "step", step = Quests.DONE })
	if not quiet then
		Deps.banner(player, {
			title = text("chain_done_title"),
			subtitle = text("chain_done_sub", { name = firstName(data, player) }),
			style = "celebration",
			duration = 6,
		})
	end
	Deps.audit(player, "tutorial_finished", {})
end

local function process(player: Player)
	if not Deps.isLive(player) then
		return
	end
	local data = Deps.data(player)
	local campus = Deps.campus(player)
	if not data or not campus then
		return
	end
	local st = stateOf(player)
	local career = if type(data.career) == "table" then data.career else {}
	local facts = Facts.gather(player, data)
	local before = campus.step
	local result = QuestLine.reconcile(campus, facts, os.time())
	local quiet = not st.primed
	announce(player, result.completed, quiet)
	local entered = campus.step ~= st.lastStep
	if entered then
		local stepNow = QuestLine.current(campus)
		if stepNow then
			onEnter(player, stepNow, quiet)
		end
		st.skipNotified = nil
	end
	-- finished just now (this reconcile, or a CompleteStep/Skip since the last one), not merely loaded finished
	local changedNow = campus.step ~= before or (st.primed and entered)
	if result.finished and changedNow then
		finishChain(player, data, quiet)
	end
	pushObjective(player, campus, facts, career)
	if entered or os.clock() - st.lastWaypoint >= WAYPOINT_EVERY then
		pushWaypoint(player, campus, facts, career)
	end
	if entered or #result.completed > 0 then
		Deps.replicate(player, "campus")
	end
	st.lastStep = campus.step
	st.primed = true
end

function TutorialService:Refresh(player: Player)
	local st = states[player]
	if not st or st.queued then
		return
	end
	st.queued = true
	task.defer(function()
		st.queued = false
		local ok, err = pcall(function()
			process(player)
		end)
		if not ok then
			Deps.warnOnce("process", err)
		end
	end)
end

local function tick(player: Player, dt: number)
	local data = Deps.data(player)
	local campus = Deps.campus(player)
	if not data or not campus then
		return
	end
	local facts = Facts.gather(player, data)
	QuestLine.tick(campus, dt, facts)
	local step = QuestLine.current(campus)
	local st = stateOf(player)
	if step and st.skipNotified ~= step.id and QuestLine.canSkip(campus, facts) then
		st.skipNotified = step.id
		Deps.notify(player, text("skip_offer", { title = step.title }), "info")
		pcall(Net.fire, SKIP_REMOTE, player, step.id)
		Deps.replicate(player, "campus")
	end
end

---------------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------------
function TutorialService:GetStep(player: Player): string?
	local campus = Deps.campus(player)
	if not campus then
		return nil
	end
	return if campus.step ~= "" then campus.step else nil
end

function TutorialService:GetStatus(player: Player): { [string]: any }?
	local data = Deps.data(player)
	local campus = Deps.campus(player)
	if not data or not campus then
		return nil
	end
	local facts = Facts.gather(player, data)
	local ok, err = QuestLine.canSkip(campus, facts)
	return {
		step = campus.step,
		finished = QuestLine.finished(campus),
		paused = QuestLine.paused(campus, facts),
		canSkip = ok,
		skipErr = err,
		stuck = math.floor(Deps.num(campus.stuck, 0)),
		skipAfter = Quests.SKIP_AFTER,
		objective = QuestLine.objective(campus, facts),
	}
end

function TutorialService:CompleteStep(player: Player, stepId: string, how: string?): boolean
	local campus = Deps.campus(player)
	if not campus or Quests.stepById[stepId] == nil then
		return false
	end
	local wasCurrent = campus.step == stepId
	QuestLine.complete(campus, stepId, os.time(), how)
	if wasCurrent then
		local st = stateOf(player)
		announce(player, { { id = stepId, how = how or "auto" } }, false)
		st.skipNotified = nil
	end
	Deps.replicate(player, "campus")
	self:Refresh(player)
	return wasCurrent
end

local function skipMove(player: Player, step: Quests.StepDef, career: { [string]: any })
	local move = step.skip
	if not move then
		return
	end
	if move.teleport then
		Deps.call("WorldService", "TeleportToAnchor", player, move.teleport, { reason = "tutorial_skip" })
	elseif move.enter and CareerState.isEmployed(career) then
		local floor = if move.enter == "track" then career.track else "lobby"
		Deps.call("OfficeService", "EnterCompany", player, career.companyId, floor, { source = "phone" })
	end
end

function TutorialService:Skip(player: Player): (boolean, string?)
	local data = Deps.data(player)
	local campus = Deps.campus(player)
	if not data or not campus then
		return false, "skip_none"
	end
	local facts = Facts.gather(player, data)
	local ok, err = QuestLine.canSkip(campus, facts)
	if not ok then
		return false, err
	end
	local skipped = QuestLine.skip(campus, os.time())
	if not skipped then
		return false, "skip_none"
	end
	announce(player, { { id = skipped.id, how = "skip" } }, false)
	Deps.audit(player, "tutorial_skip", { step = skipped.id })
	Deps.replicate(player, "campus")
	local career = if type(data.career) == "table" then data.career else {}
	task.spawn(skipMove, player, skipped, career)
	self:Refresh(player)
	return true, nil
end

function TutorialService:Ack(player: Player, infoId: string)
	if infoId == "review_intro" then
		self:CompleteStep(player, "review_intro", "auto")
	end
end

function TutorialService:ShowInfo(player: Player, infoId: string)
	if infoId ~= "review_intro" or not Deps.isLive(player) then
		return
	end
	local info = Quests.reviewIntro
	pcall(Net.fire, INFO_REMOTE, player, { id = infoId, title = info.title, lines = info.lines })
end

function TutorialService:JoinClub(player: Player): boolean
	local campus = Deps.campus(player)
	if not campus then
		return false
	end
	if campus.club ~= true then
		campus.club = true
		Deps.notify(player, text("club_joined"), "good")
		Deps.replicate(player, "campus")
		self:Refresh(player)
	end
	return true
end

function TutorialService:AddContact(player: Player, key: string): (boolean, number)
	local campus = Deps.campus(player)
	if not campus or type(key) ~= "string" then
		return false, 0
	end
	local added, count = QuestLine.Network.addContact(campus.network, key)
	if added then
		if campus.step == "network" then
			Deps.notify(
				player,
				text("networked", { n = math.min(count, Quests.NETWORK_GOAL), goal = Quests.NETWORK_GOAL }),
				"good"
			)
		end
		Deps.replicate(player, "campus")
		self:Refresh(player)
	end
	return added, count
end

function TutorialService:ResetRecruiting(player: Player)
	local campus = Deps.campus(player)
	if not campus then
		return
	end
	QuestLine.resetRecruiting(campus)
	Deps.replicate(player, "campus")
	self:Refresh(player)
end

function TutorialService:OpenRecruiting(player: Player)
	Recruiting.open(player)
end

function TutorialService:GetRecruitingBoard(player: Player): { [string]: any }?
	return Recruiting.board(player)
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
local function arrivalBanner(player: Player)
	local campus = Deps.campus(player)
	if not campus or campus.bannerShown == true then
		return
	end
	local step = campus.step
	if step ~= "" and step ~= "career_center" and step ~= "life_roll" then
		campus.bannerShown = true -- an existing player: no first-arrival moment
		return
	end
	campus.bannerShown = true
	Deps.replicate(player, "campus")
	Deps.banner(player, {
		title = Quests.arrival.title,
		subtitle = Quests.arrival.subtitle,
		style = "event",
		duration = 6,
	})
end

local function setup(player: Player)
	if not Deps.isLive(player) then
		return
	end
	local st = stateOf(player)
	if st.ready then
		TutorialService:Refresh(player)
		return
	end
	st.ready = true
	local function onCharacter()
		task.delay(BANNER_DELAY, function()
			if Deps.isLive(player) then
				local ok, err = pcall(function()
					arrivalBanner(player)
				end)
				if not ok then
					Deps.warnOnce("arrival banner", err)
				end
			end
		end)
	end
	table.insert(st.conns, player.CharacterAdded:Connect(onCharacter))
	if player.Character then
		onCharacter()
	end
	TutorialService:Refresh(player)
end

function TutorialService:Init()
	Net.declare(INFO_REMOTE)
	Net.declare(SKIP_REMOTE)
	Recruiting.bind(self)
	Players.PlayerRemoving:Connect(function(player: Player)
		local st = states[player]
		states[player] = nil
		if st then
			for _, c in st.conns do
				c:Disconnect()
			end
		end
	end)
end

function TutorialService:Start()
	Recruiting.start(self)
	local function refresh(player: any)
		if Deps.isLive(player) then
			TutorialService:Refresh(player)
		end
	end
	Deps.connect("DataService", "ProfileLoaded", function(player: Player)
		setup(player)
	end)
	Deps.connect("ProfileService", "ProfileLocked", refresh)
	Deps.connect("WorkService", "TaskCompleted", function(player: Player, _taskId: string, _result: any)
		local career = Deps.career(player)
		local campus = Deps.campus(player)
		if campus and career and CareerState.isEmployed(career) then
			campus.jobTasks = Deps.num(campus.jobTasks, 0) + 1
		end
		refresh(player)
	end)
	Deps.connect("PortfolioService", "Traded", function(player: Player, _trade: any)
		local campus = Deps.campus(player)
		if campus then
			campus.trades = Deps.num(campus.trades, 0) + 1
		end
		refresh(player)
	end)
	for _, name in { "RoleChanged", "StatusChanged", "OffersChanged", "ReviewCompleted", "LevelChanged" } do
		Deps.connect("CareerService", name, refresh)
	end
	Deps.connect("OfficeService", "LocationChanged", refresh)
	Deps.connect("WorldService", "ZoneChanged", refresh)
	Deps.connect("RebirthService", "Rebirthed", refresh)
	local hasActivity = Deps.connect("ActivityService", "ActiveTick", function(player: Player, dt: number)
		local st = states[player]
		if st then
			st.activeTicks = true
			tick(player, Deps.num(dt, 0))
		end
	end)
	for _, player in Players:GetPlayers() do
		if Deps.data(player) then
			task.spawn(setup, player)
		end
	end
	while true do
		task.wait(POLL)
		for player, st in states do
			if Deps.isLive(player) and st.primed then
				local ok, err = pcall(function()
					process(player)
				end)
				if not ok then
					Deps.warnOnce("poll", err)
				end
				if not hasActivity or not st.activeTicks then
					-- no ActivityService: count wall time while in game, so the skip offer still arrives
					local okTick, tickErr = pcall(function()
						tick(player, POLL)
					end)
					if not okTick then
						Deps.warnOnce("tick", tickErr)
					end
				end
			end
		end
	end
end

return TutorialService
