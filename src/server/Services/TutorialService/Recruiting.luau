--!strict
-- TutorialService/Recruiting (server, runtime only; spec v2 §4b, design v3 §2-§4): the campus Recruiting Board.
-- Eligibility and odds: careerPath's Logic/Recruiting. Stages: Logic/QuestLine/Recruit. Interviews are real graded
-- work tasks (WorkService interview_ib / superday_interview, offered with { companyId, companyName } so the result
-- says which application it belongs to). The offer roll uses the exact odds the board showed, decided by a Hash of
-- the application's seed (asking again gives the same answer), and an offer goes to CareerService:GrantOffer.
--
--   Recruiting.bind(svc)                    remotes (in TutorialService:Init)
--   Recruiting.start(svc)                   bulletin prompts + WorkService.TaskCompleted (in TutorialService:Start)
--   Recruiting.board(player) -> Board?      what the Recruiting screen shows
--   Recruiting.open(player)                 opens the screen on that client ("Recruiting.Open")
--   Recruiting.offerNext(player)            puts the next pending interview on the Work board
-- Remotes (RemoteFunctions return (ok, errKey?, board?)):
--   "Recruiting.Board"() -> board?   "Recruiting.Apply"(companyId)   "Recruiting.Start"(companyId)
--   "Recruiting.Retry"(companyId)    "Recruiting.Decide"(companyId) -> (ok, errKey?, board?, result?)
--   "Recruiting.Open" (server -> client)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local Hash = require(Shared.Util.Hash)
local Time = require(Shared.Util.Time)
local Companies = require(Shared.Config.Companies)
local World = require(Shared.Config.World)
local Quests = require(Shared.Config.Quests)
local CareerState = require(Shared.Logic.CareerState)
local RecruitingRules = require(Shared.Logic.Recruiting)
local QuestLine = require(Shared.Logic.QuestLine)
local Deps = require(script.Parent.Deps)
local Interacts = require(script.Parent.Interacts)

local Recruit = QuestLine.Recruit
local CFG = Quests.recruiting

local Recruiting = {}

Recruiting.OPEN_REMOTE = "Recruiting.Open"
Recruiting.INTERACT_ID = "bulletin"
Recruiting.PROMPT_NAME = "RecruitingPrompt"

local svcRef: any = nil
local lastOpen: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
local busy: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function text(key: string, vars: { [string]: any }?): string
	return Quests.text(key, vars)
end

local function nameOf(companyId: string): string
	local c = Companies.get(companyId)
	return if c then c.name else companyId
end

local function pendingOfferFrom(career: { [string]: any }, companyId: string): boolean
	if type(career.offers) ~= "table" then
		return false
	end
	for _, o in career.offers do
		if type(o) == "table" and o.companyId == companyId then
			return true
		end
	end
	return false
end

local function hired(career: { [string]: any }): boolean
	return CareerState.isEmployed(career) or career.status == "fired"
end

local function mods(player: Player, companyId: string): RecruitingRules.Mods
	local m: RecruitingRules.Mods = {}
	local okI, interview = Deps.call("EventService", "GetModifier", "interviewBonus")
	if okI and type(interview) == "number" and interview == interview then
		m.interviewBonus = math.clamp(interview, 0, 30)
	end
	local okO, offer = Deps.call("EventService", "GetModifier", "offerBonus")
	if okO and type(offer) == "number" and offer == offer then
		m.offerBonus = math.clamp(offer, 0, 0.5)
	end
	local okC, conns = Deps.call("OfferService", "GetConnections", player)
	if okC and type(conns) == "table" then
		local n = conns[companyId]
		if type(n) == "number" and n == n then
			m.connections = math.clamp(n, 0, 100)
		end
	end
	return m
end

local function changed(player: Player)
	Deps.replicate(player, "campus")
	if svcRef then
		svcRef:Refresh(player)
	end
end

---------------------------------------------------------------------------------------------------
-- The board view
---------------------------------------------------------------------------------------------------
local ACTIONS = {
	first_round = "interview",
	superday = "superday",
	retry = "retry",
	decision = "decide",
	offer = "offers",
} :: { [string]: string }

function Recruiting.board(player: Player): { [string]: any }?
	local data = Deps.data(player)
	local campus = Deps.campus(player)
	if not data or not campus then
		return nil
	end
	local profile = if type(data.profile) == "table" then data.profile else {}
	local career = if type(data.career) == "table" then data.career else {}
	local apps = campus.applications
	local isHired = hired(career)
	local built = profile.built == true
	local firms = {}
	for _, company in Companies.forTrack(CFG.track) do
		local eligible, reasons = RecruitingRules.eligibility(profile, company, CFG.track)
		local app = Recruit.find(apps, company.id)
		local pending = pendingOfferFrom(career, company.id)
		local canApply, applyErr = Recruit.canApply(apps, company, {
			built = built,
			hired = isHired,
			eligible = eligible,
			pendingOffer = pending,
		})
		local m = mods(player, company.id)
		local row: { [string]: any } = {
			id = company.id,
			name = company.name,
			short = company.short,
			type = company.type,
			typeName = company.typeName,
			tier = company.tier,
			tagline = company.tagline,
			culture = company.culture,
			logo = company.logo,
			colors = { primary = company.hex.primary, accent = company.hex.accent, text = company.hex.text },
			minOutfitLevel = company.minOutfitLevel,
			eligible = eligible,
			reasons = reasons,
			walkOn = Recruit.isWalkOn(company, CFG.track),
			walkOnBar = Recruit.walkOnBar(company, CFG.track),
			canApply = canApply,
			applyErr = applyErr,
			pendingOffer = pending,
			preview = if eligible then Recruit.preview(profile, company, m, CFG.track) else {},
		}
		if app then
			row.stage = app.stage
			row.q1 = app.q1
			row.q2 = app.q2
			row.quality = app.quality
			row.tries = app.tries
			if app.stage == "decision" then
				row.chance = (Recruit.chance(app, profile, company, m, CFG.track))
			elseif type(app.chance) == "number" then
				row.chance = app.chance
			end
			row.action = if app.stage == "offer" and not pending and canApply then "apply" else ACTIONS[app.stage]
		elseif canApply then
			row.action = "apply"
		end
		table.insert(firms, row)
	end
	return {
		track = CFG.track,
		max = CFG.maxApplications,
		used = Recruit.slotsUsed(apps),
		built = built,
		hired = isHired,
		offers = if type(career.offers) == "table" then #career.offers else 0,
		firms = firms,
	}
end

---------------------------------------------------------------------------------------------------
-- Interviews on the Work board
---------------------------------------------------------------------------------------------------
local function taskOpts(companyId: string): { [string]: any }
	return {
		source = "recruiting",
		data = { companyId = companyId, companyName = nameOf(companyId), label = nameOf(companyId) },
		ttl = CFG.interviewTtl,
	}
end

function Recruiting.offerNext(player: Player)
	local campus = Deps.campus(player)
	if not campus then
		return
	end
	local app, taskId = Recruit.nextTask(campus.applications)
	if app and taskId then
		local opts = taskOpts(app.companyId)
		opts.silent = true
		Deps.call("WorkService", "OfferTask", player, taskId, opts)
	end
end

local function onTask(player: Player, taskId: string, result: any)
	if taskId ~= CFG.interviewTask and taskId ~= CFG.superdayTask then
		return
	end
	local campus = Deps.campus(player)
	local data = Deps.data(player)
	if not campus or not data then
		return
	end
	local r = if type(result) == "table" then result else {}
	local rdata = if type(r.data) == "table" then r.data else {}
	local companyId = if type(rdata.companyId) == "string" then rdata.companyId else nil
	local app = Recruit.forTask(campus.applications, taskId, companyId, campus.pending[taskId])
	if not app then
		return
	end
	local company = Companies.get(app.companyId)
	if not company then
		return
	end
	campus.pending[taskId] = nil
	local q = Deps.num(r.quality, 0)
	local name = company.name
	if taskId == CFG.interviewTask then
		local stage = Recruit.firstRound(app, q, company, CFG.track)
		if stage == "superday" then
			Deps.notify(player, text("recruit_first_round_done", { company = name, q = app.q1 }), "good")
		else
			Deps.notify(player, text("recruit_first_round_cut", { company = name, q = app.q1 }), "warn")
		end
	else
		local stage = Recruit.superday(app, q, company, CFG.track)
		if stage == "retry" then
			Deps.notify(
				player,
				text("recruit_superday_retry", { company = name, q = app.q2, bar = Recruit.walkOnBar(company) or 0 }),
				"warn"
			)
		else
			Deps.notify(player, text("recruit_superday_done", { company = name, q = app.q2 }), "good")
		end
	end
	Deps.audit(player, "recruiting_round", { companyId = app.companyId, taskId = taskId, q = q, stage = app.stage })
	changed(player)
	-- a walk-on seat that was passed needs no decision: grant it straight away
	if app.stage == "decision" and app.sure then
		task.defer(function()
			if Deps.isLive(player) then
				Recruiting.decide(player, app.companyId)
			end
		end)
	end
	Recruiting.offerNext(player)
end

---------------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------------
local function loaded(player: Player): ({ [string]: any }?, { [string]: any }?, string?)
	local data = Deps.data(player)
	local campus = Deps.campus(player)
	if not data or not campus then
		return nil, nil, "not_loaded"
	end
	return data, campus, nil
end

function Recruiting.apply(player: Player, companyId: string): (boolean, string?)
	local data, campus, err = loaded(player)
	if not data or not campus then
		return false, err
	end
	local company = Companies.get(companyId)
	if not company or not Companies.hires(company, CFG.track) then
		return false, "unknown"
	end
	local profile = if type(data.profile) == "table" then data.profile else {}
	local career = if type(data.career) == "table" then data.career else {}
	local eligible = RecruitingRules.eligibility(profile, company, CFG.track)
	local ok, why = Recruit.canApply(campus.applications, company, {
		built = profile.built == true,
		hired = hired(career),
		eligible = eligible,
		pendingOffer = pendingOfferFrom(career, company.id),
	})
	if not ok then
		return false, why
	end
	local now = Time.now()
	local seed = Hash.u32("recruit", player.UserId, company.id, now, #campus.applications)
	local app = Recruit.apply(campus.applications, company, now, seed, CFG.track)
	Deps.notify(player, text("recruit_applied", { company = company.name }), "good")
	Deps.call("WorkService", "OfferTask", player, CFG.interviewTask, taskOpts(app.companyId))
	Deps.audit(player, "recruiting_apply", { companyId = company.id, walkOn = app.walkOn })
	changed(player)
	return true, nil
end

function Recruiting.begin(player: Player, companyId: string): (boolean, string?)
	local _, campus, err = loaded(player)
	if not campus then
		return false, err
	end
	local app = Recruit.find(campus.applications, companyId)
	if not app or (app.stage ~= "first_round" and app.stage ~= "superday") then
		return false, "stage"
	end
	local taskId = if app.stage == "first_round" then CFG.interviewTask else CFG.superdayTask
	if not Deps.has("WorkService", "StartTask") then
		return false, "work"
	end
	local ok, instanceId, startErr = Deps.call2("WorkService", "StartTask", player, taskId, taskOpts(companyId))
	if not ok or instanceId == nil then
		return false, if type(startErr) == "string" and startErr == "busy" then "busy" else "work"
	end
	campus.pending[taskId] = companyId
	Deps.replicate(player, "campus")
	return true, nil
end

function Recruiting.retry(player: Player, companyId: string): (boolean, string?)
	local _, campus, err = loaded(player)
	if not campus then
		return false, err
	end
	local app = Recruit.find(campus.applications, companyId)
	if not app or not Recruit.retry(app) then
		return false, "stage"
	end
	Deps.call("WorkService", "OfferTask", player, CFG.superdayTask, taskOpts(companyId))
	changed(player)
	return true, nil
end

function Recruiting.decide(player: Player, companyId: string): (boolean, string?, { [string]: any }?)
	local data, campus, err = loaded(player)
	if not data or not campus then
		return false, err, nil
	end
	if busy[player] then
		return false, "busy", nil
	end
	local app = Recruit.find(campus.applications, companyId)
	local company = Companies.get(companyId)
	if not app or not company or app.stage ~= "decision" then
		return false, "stage", nil
	end
	local profile = if type(data.profile) == "table" then data.profile else {}
	local chance = Recruit.chance(app, profile, company, mods(player, companyId), CFG.track)
	local u = Hash.unit("tutorial_offer", player.UserId, company.id, app.seed, app.tries)
	local outcome = Recruit.decide(app, chance, u)
	app.chance = chance
	local result = { outcome = outcome, chance = chance, company = company.name }
	if outcome == "offer" then
		busy[player] = true
		local ok, offerId = Deps.call("CareerService", "GrantOffer", player, {
			companyId = company.id,
			track = CFG.track,
			rank = 1,
			source = if app.walkOn then "walk_on" else "recruiting",
		})
		busy[player] = nil
		if not ok or type(offerId) ~= "string" then
			-- careerPath is down: keep the decision open (the same roll comes back next time)
			changed(player)
			return false, "no_offer_service", nil
		end
		Recruit.settle(app, "offer", offerId)
		Deps.notify(player, text("recruit_offer", { company = company.name }), "good")
	else
		Recruit.settle(app, "rejected")
		Deps.notify(player, text("recruit_rejected", { company = company.name, chance = math.floor(chance * 100 + 0.5) .. "%" }), "bad")
	end
	Deps.audit(player, "recruiting_decision", { companyId = company.id, chance = chance, outcome = outcome })
	changed(player)
	Deps.call("DataService", "Save", player, "recruiting")
	return true, nil, result
end

function Recruiting.open(player: Player)
	if Deps.isLive(player) then
		pcall(Net.fire, Recruiting.OPEN_REMOTE, player, {})
	end
end

---------------------------------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------------------------------
local function guarded(fn: (Player, string) -> (boolean, string?, any?)): (Player, any) -> (boolean, string?, any, any)
	return function(player: Player, rawId: any): (boolean, string?, any, any)
		local id = Guard.id(rawId)
		if not id then
			return false, "unknown", nil, nil
		end
		local ok, err, extra = fn(player, id)
		return ok, err, Recruiting.board(player), extra
	end
end

function Recruiting.bind(svc: any)
	svcRef = svc
	Net.declare(Recruiting.OPEN_REMOTE)
	Net.handle("Recruiting.Board", function(player: Player)
		return Recruiting.board(player)
	end, { rate = 2, burst = 6 })
	Net.handle("Recruiting.Apply", guarded(Recruiting.apply), { rate = 1, burst = 4 })
	Net.handle("Recruiting.Start", guarded(Recruiting.begin), { rate = 1, burst = 3 })
	Net.handle("Recruiting.Retry", guarded(Recruiting.retry), { rate = 1, burst = 3 })
	Net.handle("Recruiting.Decide", guarded(Recruiting.decide), { rate = 1, burst = 3 })
end

local function onBulletin(inst: Instance)
	local parent = Interacts.promptParent(inst)
	if not parent then
		return
	end
	local def = World.interactIds[Recruiting.INTERACT_ID]
	local companyId = Interacts.companyOf(inst)
	local prompt = Interacts.prompt(parent, {
		name = Recruiting.PROMPT_NAME,
		action = if def then def.prompt else text("recruit_title"),
		object = text("recruit_title"),
		interactId = Recruiting.INTERACT_ID,
		companyId = companyId,
		employeesOnly = companyId ~= nil,
	})
	prompt.Triggered:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastOpen[player] or 0) < 0.75 then
			return
		end
		lastOpen[player] = now
		local company = Interacts.companyOf(inst)
		if company and not Deps.isEmployeeOf(player, company) then
			Deps.notify(
				player,
				text("dialogue_employees_only", { name = text("recruit_title"), company = nameOf(company) }),
				"warn"
			)
			return
		end
		Recruiting.open(player)
	end)
end

function Recruiting.start(_svc: any)
	Interacts.watch(Recruiting.INTERACT_ID, onBulletin)
	Deps.connect("WorkService", "TaskCompleted", function(player: Player, taskId: string, result: any)
		onTask(player, taskId, result)
	end)
end

return Recruiting
