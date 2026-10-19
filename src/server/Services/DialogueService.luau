--!strict
-- DialogueService (server, owned by `tutorial`; contracts §14 DialogueService:Open): server-authoritative NPC
-- conversations. Trees live in Config/Dialogue and run with Logic/Dialogue. The client only ever sees the current
-- node's text and the options whose conditions hold; every choice is re-validated against the node the player is
-- actually on, with fresh conditions, and the actions run here.
--
-- Actions: complete a chain step (TutorialService:CompleteStep), offer/start a work task (WorkService), open a screen
-- (the owning service's OpenFor, else the client screen), set a dialogue flag, train a stat (ProfileService:
-- AwardStatXp, once per real day per reward key), count a networking contact (TutorialService:AddContact), join the
-- Finance Club, add a company connection (OfferService, M3), a toast, the review explainer, reputation.
-- Talking to an NPC counts for side quests (QuestService:Progress talk) and achievements.
--
-- API:
--   DialogueService:Open(player, npcId, dialogueId, opts?) -> boolean
--       opts = { model?, origin?: Vector3, name?, title?, color?, companyId?, office? }
--   DialogueService:Close(player, reason?)       DialogueService:IsTalking(player) -> boolean
-- Signals: Talked(player, npcId)
-- Remotes: "Dialogue.Node"(payload) server -> client (open / update / { closed = true, reason });
--   "Dialogue.Choose"(token, optionId) -> payload; "Dialogue.Close"(token) client -> server;
--   "Dialogue.OpenScreen"(screenId, args?) server -> client (a screen with no server opener).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)
local Trees = require(Shared.Config.Dialogue)
local Npcs = require(Shared.Config.Npcs)
local Quests = require(Shared.Config.Quests)
local Companies = require(Shared.Config.Companies)
local Tracks = require(Shared.Config.Tracks)
local LifeRollConfig = require(Shared.Config.LifeRoll)
local CareerState = require(Shared.Logic.CareerState)
local Dialogue = require(Shared.Logic.Dialogue)
local QuestLine = require(Shared.Logic.QuestLine)
local Deps = require(script.Parent.TutorialService.Deps)

local DialogueService = {
	Name = "DialogueService",
	Priority = 55,
	Talked = Signal.new(), -- (player, npcId)
}

local NODE_REMOTE = "Dialogue.Node"
local SCREEN_REMOTE = "Dialogue.OpenScreen"
local RANGE_EVERY = 1
local OPEN_DELAY = 0.15
local DAY = 86400

type Session = {
	token: string,
	npcId: string,
	treeId: string,
	tree: any,
	node: string,
	name: string,
	title: string,
	color: string?,
	model: Model?,
	origin: Vector3?,
	companyId: string?,
	office: boolean,
}

local sessions: { [Player]: Session } = {}
local nextToken = 0

local function today(): number
	return math.floor(os.time() / DAY)
end

local function text(key: string, vars: { [string]: any }?): string
	return Quests.text(key, vars)
end

---------------------------------------------------------------------------------------------------
-- Context
---------------------------------------------------------------------------------------------------
local function headline(): string
	local ok, news = Deps.call("MarketService", "GetNews", 1)
	if ok and type(news) == "table" and type(news[1]) == "table" and type(news[1].headline) == "string" then
		return news[1].headline
	end
	return "Markets are quiet. Too quiet."
end

local function indexText(): string
	local ok, v = Deps.call("MarketService", "GetIndex")
	if ok and type(v) == "number" and v == v then
		return Format.commas(v, 2)
	end
	return "steady"
end

local function buildCtx(player: Player, s: Session): Dialogue.Ctx
	local data: { [string]: any } = Deps.data(player) or {}
	local profile = if type(data.profile) == "table" then data.profile else {}
	local career = if type(data.career) == "table" then data.career else {}
	local campus = Deps.campus(player) or QuestLine.normalize({})
	local employed = CareerState.isEmployed(career)
	local fired = career.status == "fired"
	local offers = if type(career.offers) == "table" then #career.offers else 0
	local visitor = false
	if s.office then
		visitor = s.companyId == nil or not Deps.isEmployeeOf(player, s.companyId :: string)
	end
	local okStats, stats = Deps.call("ProfileService", "GetStats", player)
	local first = if type(profile.firstName) == "string" and profile.firstName ~= ""
		then profile.firstName
		else player.DisplayName
	local fullAttr = player:GetAttribute("FullName")
	local school = if type(profile.school) == "table" then LifeRollConfig.school(profile.school.id) else nil
	local companyName = if type(career.companyName) == "string" and career.companyName ~= ""
		then career.companyName
		else nil
	local companyDef = Companies.get(career.companyId)
	local company = companyName or (if companyDef then companyDef.name else nil) or text("your_firm")
	local boss = if type(career.bossName) == "string" and career.bossName ~= ""
		then career.bossName
		elseif employed then Companies.bossName(career.companyId, career.track)
		else text("your_boss")
	local track = Tracks.get(career.track)
	local placeCompany = if s.companyId then Companies.get(s.companyId) else nil
	local day = today()
	return {
		seed = ("%d:%s:%d"):format(player.UserId, s.npcId, day),
		step = campus.step,
		done = campus.done,
		flags = campus.flags,
		built = profile.built == true,
		student = not (employed or fired),
		employed = employed,
		fired = fired,
		hired = employed or fired,
		club = campus.club == true,
		hasOffer = offers > 0,
		offers = offers,
		visitor = visitor,
		reviewDue = employed and career.reviewDue == true,
		talkedToday = campus.talked["talk:" .. s.npcId] == day,
		onboarded = career.onboarded == true,
		probation = career.status == "probation",
		firstTalk = campus.flags["met_" .. s.npcId] ~= true,
		status = career.status,
		lastBand = career.lastBand,
		rank = Deps.num(career.rank, 0),
		level = Deps.num(career.level, 1),
		reviews = if type(career.reviews) == "table" then #career.reviews else 0,
		networked = Deps.num(campus.network.count, 0),
		stats = if okStats and type(stats) == "table"
			then stats
			elseif type(profile.stats) == "table" then profile.stats
			else {},
		vars = {
			name = first,
			full = if type(fullAttr) == "string" and fullAttr ~= "" then fullAttr else first,
			npc = s.name,
			company = company,
			boss = boss,
			school = if school then school.name else "Eastbridge",
			title = if type(career.title) == "string" and career.title ~= "" then career.title else "student",
			department = if track then track.name else text("department_ib"),
			headline = headline(),
			index = indexText(),
			level = math.floor(Deps.num(career.level, 1)),
			week = math.floor(Deps.num(career.week, 0)),
			apps = QuestLine.Recruit.slotsUsed(campus.applications),
			max = Quests.recruiting.maxApplications,
			networked = Deps.num(campus.network.count, 0),
			goal = Quests.NETWORK_GOAL,
			place = if placeCompany then placeCompany.name else s.title,
		},
	}
end

---------------------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------------------
local SCREEN_FOR = {
	wardrobe = "Wardrobe",
	shop = "Shop",
	work = "Work",
	careerServices = "CareerServices",
	lifeRoll = "LifeRoll",
	terminal = "Terminal",
	housing = "Housing",
	directory = "Directory",
	recruiting = "Recruiting",
	offers = "Offers",
	quests = "Quests",
	career = "Career",
} :: { [string]: string }

local function openScreen(player: Player, target: string, args: { [string]: any }?)
	local a = if type(args) == "table" then table.clone(args) else {}
	local served = false
	if target == "wardrobe" then
		served = Deps.call("WardrobeService", "OpenFor", player, a)
	elseif target == "shop" then
		served = Deps.call("ShopService", "OpenFor", player, a)
	elseif target == "work" then
		served = Deps.call("WorkService", "OpenFor", player, a)
	elseif target == "careerServices" then
		served = Deps.call("CareerService", "OpenServices", player)
	elseif target == "lifeRoll" then
		served = Deps.call("ProfileService", "OpenFor", player, a)
	elseif target == "terminal" then
		served = Deps.call("MarketService", "OpenTerminal", player, "trade", "dialogue")
	elseif target == "housing" then
		served = Deps.call("HousingService", "OpenFor", player, a)
	elseif target == "directory" then
		served = Deps.call("OfficeService", "OpenDirectory", player, a)
	elseif target == "recruiting" then
		served = Deps.call("TutorialService", "OpenRecruiting", player)
	end
	if not served then
		local screen = SCREEN_FOR[target]
		if screen then
			pcall(Net.fire, SCREEN_REMOTE, player, screen, a)
		end
	end
end

local function dailyOnce(player: Player, key: string): boolean
	local campus = Deps.campus(player)
	if not campus then
		return false
	end
	local day = today()
	if campus.talked[key] == day then
		return false
	end
	-- keep the log small: only today's keys matter
	for k, d in campus.talked do
		if d ~= day then
			campus.talked[k] = nil
		end
	end
	campus.talked[key] = day
	return true
end

local function perform(player: Player, s: Session, action: Dialogue.Action)
	local kind = action.kind
	if kind == "complete" then
		Deps.call("TutorialService", "CompleteStep", player, action.step, "auto")
	elseif kind == "offerTask" then
		Deps.call("WorkService", "OfferTask", player, action.task, { source = "dialogue" })
	elseif kind == "startTask" then
		Deps.call("WorkService", "StartTask", player, action.task, { source = "dialogue" })
	elseif kind == "open" then
		local target = action.target
		local args = action.args
		task.delay(OPEN_DELAY, function()
			if Deps.isLive(player) then
				openScreen(player, target, args)
			end
		end)
	elseif kind == "flag" then
		local campus = Deps.campus(player)
		if campus then
			campus.flags[action.flag] = true
		end
	elseif kind == "statXp" then
		if dailyOnce(player, "xp:" .. tostring(action.key)) then
			Deps.call("ProfileService", "AwardStatXp", player, action.stats, Deps.num(action.quality, 50), "task")
		end
	elseif kind == "network" then
		Deps.call("TutorialService", "AddContact", player, "npc:" .. tostring(action.key))
	elseif kind == "joinClub" then
		Deps.call("TutorialService", "JoinClub", player)
	elseif kind == "connection" then
		local career = Deps.career(player)
		local companyId = action.companyId or (if career then career.companyId else nil)
		if type(companyId) == "string" and companyId ~= "" and dailyOnce(player, "conn:" .. s.npcId) then
			Deps.call("OfferService", "AddConnection", player, companyId, Deps.num(action.amount, 1), "dialogue")
		end
	elseif kind == "notify" then
		Deps.notify(player, tostring(action.text), action.style or "info")
	elseif kind == "info" then
		Deps.call("TutorialService", "ShowInfo", player, action.id)
	elseif kind == "reputation" then
		if dailyOnce(player, "rep:" .. tostring(action.key)) then
			Deps.call("CareerService", "AddReputation", player, Deps.num(action.amount, 1), "dialogue")
		end
	end
end

local function performAll(player: Player, s: Session, actions: { Dialogue.Action })
	for _, a in actions do
		local ok, err = pcall(function()
			perform(player, s, a)
		end)
		if not ok then
			Deps.warnOnce("dialogue action " .. tostring(a.kind), err)
		end
	end
	if #actions > 0 then
		Deps.replicate(player, "campus")
	end
end

---------------------------------------------------------------------------------------------------
-- Sessions
---------------------------------------------------------------------------------------------------
local function payload(s: Session, view: Dialogue.View): { [string]: any }
	return {
		token = s.token,
		npcId = s.npcId,
		name = s.name,
		title = s.title,
		color = s.color,
		node = view.node,
		text = view.text,
		options = view.options,
	}
end

local function nodePayload(player: Player, s: Session): { [string]: any }?
	local view = Dialogue.view(s.tree, s.node, buildCtx(player, s))
	if not view or #view.options == 0 then
		return nil
	end
	return payload(s, view)
end

local function rootPos(player: Player): Vector3?
	local root = Deps.root(player)
	return if root then root.Position else nil
end

function DialogueService:IsTalking(player: Player): boolean
	return sessions[player] ~= nil
end

function DialogueService:Close(player: Player, reason: string?)
	local s = sessions[player]
	if not s then
		return
	end
	sessions[player] = nil
	if Deps.isLive(player) then
		pcall(Net.fire, NODE_REMOTE, player, { token = s.token, closed = true, reason = reason or "closed" })
	end
end

function DialogueService:Open(player: Player, npcId: string, dialogueId: string, opts: { [string]: any }?): boolean
	if not Deps.isLive(player) or type(npcId) ~= "string" then
		return false
	end
	local tree = Trees.get(dialogueId)
	if not tree then
		Deps.warnOnce("dialogue " .. tostring(dialogueId), "no such tree")
		return false
	end
	if not Deps.data(player) then
		Deps.notify(player, text("recruit_err_not_loaded"), "warn")
		return false
	end
	local o: { [string]: any } = if type(opts) == "table" then opts else {}
	local def = Npcs.get(npcId)
	nextToken += 1
	local s: Session = {
		token = "d" .. nextToken,
		npcId = npcId,
		treeId = dialogueId,
		tree = tree,
		node = "",
		name = if type(o.name) == "string" then o.name elseif def then def.name else npcId,
		title = if type(o.title) == "string" then o.title elseif def then def.title else "",
		color = if type(o.color) == "string" then o.color elseif def then def.color else nil,
		model = if typeof(o.model) == "Instance" and (o.model :: Instance):IsA("Model") then o.model :: Model else nil,
		origin = if typeof(o.origin) == "Vector3" then o.origin else nil,
		companyId = if type(o.companyId) == "string" then o.companyId else nil,
		office = o.office == true,
	}
	local ctx = buildCtx(player, s)
	local start = Dialogue.start(tree, ctx)
	if not start then
		return false
	end
	if sessions[player] then
		sessions[player] = nil -- replaced silently: the client swaps to the new conversation
	end
	s.node = start
	sessions[player] = s
	performAll(player, s, Dialogue.enterActions(tree, start))

	-- first meeting, side quests and achievements
	local campus = Deps.campus(player)
	if campus then
		campus.flags["met_" .. npcId] = true
		campus.talked["talk:" .. npcId] = today()
		Deps.replicate(player, "campus")
	end
	Deps.call("QuestService", "Progress", player, { kind = "talk", npcId = npcId })
	Deps.call("AchievementService", "Record", player, { kind = "talk", npcId = npcId })
	DialogueService.Talked:Fire(player, npcId)
	local pos = rootPos(player)
	if s.model and pos then
		Deps.call("NpcService", "FaceToward", s.model, pos)
	end

	local p = nodePayload(player, s)
	if not p then
		sessions[player] = nil
		return false
	end
	pcall(Net.fire, NODE_REMOTE, player, p)
	return true
end

local function choose(player: Player, token: string, optionId: string): { [string]: any }
	local s = sessions[player]
	if not s or s.token ~= token then
		return { token = token, closed = true, reason = "gone" }
	end
	local origin = s.origin
	local pos = rootPos(player)
	if origin and pos and (pos - origin).Magnitude > Npcs.STAY_RANGE then
		sessions[player] = nil
		return { token = token, closed = true, reason = "far" }
	end
	local ok, step = Dialogue.choose(s.tree, s.node, optionId, buildCtx(player, s))
	if not ok then
		-- stale or forged choice: resend the node the player is really on
		local current = nodePayload(player, s)
		if current then
			return current
		end
		sessions[player] = nil
		return { token = token, closed = true, reason = "gone" }
	end
	performAll(player, s, step.actions)
	if step.exit or step.next == nil then
		if sessions[player] == s then
			sessions[player] = nil
		end
		return { token = token, closed = true, reason = "done" }
	end
	if sessions[player] ~= s then
		return { token = token, closed = true, reason = "gone" }
	end
	s.node = step.next :: string
	local p = nodePayload(player, s)
	if not p then
		sessions[player] = nil
		return { token = token, closed = true, reason = "done" }
	end
	return p
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function DialogueService:Init()
	Net.declare(NODE_REMOTE)
	Net.declare(SCREEN_REMOTE)
	Net.handle("Dialogue.Choose", function(player: Player, rawToken: any, rawOption: any)
		local token = Guard.id(rawToken)
		local optionId = Guard.id(rawOption)
		if not token or not optionId then
			return { closed = true, reason = "gone" }
		end
		return choose(player, token, optionId)
	end, { rate = 4, burst = 8 })
	Net.on("Dialogue.Close", function(player: Player, rawToken: any)
		local token = Guard.id(rawToken)
		local s = sessions[player]
		if s and s.token == token then
			sessions[player] = nil
		end
	end, { rate = 4, burst = 8 })
	Players.PlayerRemoving:Connect(function(player: Player)
		sessions[player] = nil
	end)
	-- trees are data: report any that a config edit broke (tests enforce this too)
	for _, id in Trees.ids() do
		local problems = Dialogue.validate(Trees.get(id))
		if #problems > 0 then
			warn(("[DialogueService] dialogue %s has problems:\n  %s"):format(id, table.concat(problems, "\n  ")))
		end
	end
end

function DialogueService:Start()
	while true do
		task.wait(RANGE_EVERY)
		for player, s in sessions do
			if not Deps.isLive(player) then
				sessions[player] = nil
			else
				local origin = s.origin
				local pos = rootPos(player)
				if origin and pos and (pos - origin).Magnitude > Npcs.STAY_RANGE then
					DialogueService:Close(player, "far")
				elseif s.model and s.model.Parent == nil then
					DialogueService:Close(player, "gone")
				end
			end
		end
	end
end

return DialogueService
