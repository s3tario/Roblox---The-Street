--!strict
-- QuestService (server, owned by `tutorial`; contracts §14): the one HUD objective line, the quest waypoint and the
-- side quests.
--
-- Any feature may set an objective under its own quest id; the HUD shows the highest-priority one
-- (Config/Quests.priority: career 100 > onboarding 50 > guide 20 > side 10, others 30), ties going to the most
-- recent. Waypoints work the same way: the shown objective's waypoint, else the best one any quest set.
-- Side quests (Config/Quests.side) advance from WorkService, PortfolioService, CareerService and WardrobeService
-- signals plus NPC conversations (DialogueService calls :Progress), and pay XP and cash once.
--
-- API (contracts §14):
--   QuestService:SetObjective(player, questId, text?)      nil or "" clears that quest's objective
--   QuestService:Complete(player, questId) -> boolean      clears it; finishes a side quest or a chain step
--   QuestService:GetObjective(player) -> (text?, questId?)
--   QuestService:SetWaypoint(player, questId, position?, label?)
--   QuestService:Progress(player, event) -> { questId }    side-quest events (Logic/QuestLine/Side)
--   QuestService:GetView(player) -> view?                  what the Quests screen shows
-- Signals: SideCompleted(player, questId)
-- Remotes: "Quest.Objective"({ questId, text? }) and "Quest.Waypoint"(position?, label?) server -> client;
--   "Quest.Current"() -> { text?, questId?, position?, label? }; "Quest.Get"() -> view; "Quest.Skip"() -> (ok, err?);
--   "Quest.Ack"(infoId) client -> server.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local Signal = require(Shared.Util.Signal)
local Quests = require(Shared.Config.Quests)
local QuestLine = require(Shared.Logic.QuestLine)
local Deps = require(script.Parent.TutorialService.Deps)

local QuestService = {
	Name = "QuestService",
	Priority = 45,
	SideCompleted = Signal.new(), -- (player, questId)
}

local MAX_TEXT = 240
local DEFAULT_PRIORITY = 30

type Entry = { text: string, seq: number }
type Mark = { position: Vector3, label: string?, seq: number }
type PState = {
	objectives: { [string]: Entry },
	waypoints: { [string]: Mark },
	shownText: string?,
	shownQuest: string?,
	shownPos: Vector3?,
	shownLabel: string?,
}

local states: { [Player]: PState } = {}
local seq = 0

local function stateOf(player: Player): PState
	local st = states[player]
	if not st then
		st = { objectives = {}, waypoints = {} }
		states[player] = st
	end
	return st
end

local function priorityOf(questId: string): number
	local p = Quests.priority[questId]
	if p then
		return p
	end
	if Quests.sideById[questId] then
		return Quests.priority.side or 10
	end
	return DEFAULT_PRIORITY
end

local function best(map: { [string]: any }): (string?, any)
	local bestId: string? = nil
	local bestEntry: any = nil
	local bestP = -math.huge
	for id, e in map do
		local p = priorityOf(id)
		if p > bestP or (p == bestP and bestEntry and e.seq > bestEntry.seq) then
			bestId, bestEntry, bestP = id, e, p
		end
	end
	return bestId, bestEntry
end

local function sameVec(a: Vector3?, b: Vector3?): boolean
	if a == nil or b == nil then
		return a == b
	end
	return (a - b).Magnitude < 0.5
end

local function publish(player: Player)
	if not Deps.isLive(player) then
		return
	end
	local st = stateOf(player)
	local questId, entry = best(st.objectives)
	local text = if entry then entry.text else nil
	if text ~= st.shownText or questId ~= st.shownQuest then
		st.shownText = text
		st.shownQuest = questId
		pcall(Net.fire, "Quest.Objective", player, { questId = questId or "", text = text })
	end
	local mark: Mark? = if questId then st.waypoints[questId] else nil
	if not mark then
		local _, m = best(st.waypoints)
		mark = m
	end
	local pos = if mark then mark.position else nil
	local label = if mark then mark.label else nil
	if not sameVec(pos, st.shownPos) or label ~= st.shownLabel then
		st.shownPos = pos
		st.shownLabel = label
		pcall(Net.fire, "Quest.Waypoint", player, pos, label)
	end
end

local function clean(text: any): string?
	if type(text) ~= "string" then
		return nil
	end
	local t = string.gsub(text, "^%s+", "")
	t = string.gsub(t, "%s+$", "")
	if t == "" then
		return nil
	end
	if #t > MAX_TEXT then
		t = string.sub(t, 1, MAX_TEXT)
	end
	return t
end

---------------------------------------------------------------------------------------------------
-- Objectives and waypoints
---------------------------------------------------------------------------------------------------
function QuestService:SetObjective(player: Player, questId: string, text: string?)
	if not Deps.isLive(player) or type(questId) ~= "string" or questId == "" then
		return
	end
	local st = stateOf(player)
	local t = clean(text)
	local existing = st.objectives[questId]
	if t == nil then
		if existing then
			st.objectives[questId] = nil
			publish(player)
		end
		return
	end
	if existing and existing.text == t then
		return
	end
	seq += 1
	st.objectives[questId] = { text = t, seq = seq }
	publish(player)
end

function QuestService:GetObjective(player: Player): (string?, string?)
	local st = states[player]
	if not st then
		return nil, nil
	end
	local questId, entry = best(st.objectives)
	return if entry then entry.text else nil, questId
end

function QuestService:SetWaypoint(player: Player, questId: string, position: Vector3?, label: string?)
	if not Deps.isLive(player) or type(questId) ~= "string" then
		return
	end
	local st = stateOf(player)
	local existing = st.waypoints[questId]
	if typeof(position) ~= "Vector3" then
		if existing then
			st.waypoints[questId] = nil
			publish(player)
		end
		return
	end
	local l = clean(label)
	if existing and sameVec(existing.position, position) and existing.label == l then
		return
	end
	seq += 1
	st.waypoints[questId] = { position = position :: Vector3, label = l, seq = if existing then existing.seq else seq }
	publish(player)
end

---------------------------------------------------------------------------------------------------
-- Side quests
---------------------------------------------------------------------------------------------------
local function reward(player: Player, def: Quests.SideDef)
	local r = def.reward
	if r.xp and r.xp > 0 then
		Deps.call("CareerService", "AddXP", player, r.xp, "quest")
	end
	if r.cash and r.cash > 0 then
		Deps.call("EconomyService", "AddCash", player, r.cash, "quest", "reward")
	end
	local rewardText = QuestLine.Side.rewardText(r)
	local line = Quests.text("side_complete", { title = def.title })
	Deps.notify(player, if rewardText ~= "" then line .. " (" .. rewardText .. ")" else line, "good")
	Deps.call("AchievementService", "Record", player, { kind = "side", questId = def.id })
	Deps.audit(player, "side_quest", { id = def.id })
	QuestService.SideCompleted:Fire(player, def.id)
end

function QuestService:Progress(player: Player, event: { [string]: any }): { string }
	local campus = Deps.campus(player)
	if not campus or type(event) ~= "table" then
		return {}
	end
	local done = QuestLine.Side.apply(campus.quests, Quests.side, event, os.time())
	local ids: { string } = {}
	for _, def in done do
		table.insert(ids, def.id)
		reward(player, def)
	end
	-- progress shows on the Quests screen (replication is batched, so a no-op event costs nothing much)
	Deps.replicate(player, "campus")
	return ids
end

function QuestService:Complete(player: Player, questId: string): boolean
	if type(questId) ~= "string" then
		return false
	end
	self:SetObjective(player, questId, nil)
	self:SetWaypoint(player, questId, nil, nil)
	local def = Quests.sideById[questId]
	if def then
		local campus = Deps.campus(player)
		if not campus then
			return false
		end
		local s = campus.quests[questId]
		if type(s) == "table" and type(s.done) == "number" and s.done > 0 then
			return false
		end
		campus.quests[questId] = { n = def.goal, done = os.time(), seen = if type(s) == "table" then s.seen else {} }
		Deps.replicate(player, "campus")
		reward(player, def)
		return true
	end
	if Quests.stepById[questId] then
		local ok, result = Deps.call("TutorialService", "CompleteStep", player, questId, "auto")
		return ok and result == true
	end
	return true
end

function QuestService:GetView(player: Player): { [string]: any }?
	local campus = Deps.campus(player)
	if not campus then
		return nil
	end
	local text, questId = self:GetObjective(player)
	local okStatus, status = Deps.call("TutorialService", "GetStatus", player)
	return {
		objective = text,
		questId = questId,
		status = if okStatus then status else nil,
		side = QuestLine.Side.view(campus.quests, Quests.side),
	}
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function QuestService:Init()
	Net.declare("Quest.Objective")
	Net.declare("Quest.Waypoint")
	Net.handle("Quest.Current", function(player: Player)
		local st = states[player]
		local text, questId = QuestService:GetObjective(player)
		return {
			text = text,
			questId = questId,
			position = if st then st.shownPos else nil,
			label = if st then st.shownLabel else nil,
		}
	end, { rate = 1, burst = 4 })
	Net.handle("Quest.Get", function(player: Player)
		return QuestService:GetView(player)
	end, { rate = 2, burst = 6 })
	Net.handle("Quest.Skip", function(player: Player): (boolean, string?)
		local ok, a, b = Deps.call2("TutorialService", "Skip", player)
		if not ok then
			return false, "skip_none"
		end
		return a == true, if type(b) == "string" then b else nil
	end, { rate = 0.5, burst = 2 })
	Net.on("Quest.Ack", function(player: Player, infoId: any)
		local id = Guard.id(infoId)
		if id then
			Deps.call("TutorialService", "Ack", player, id)
		end
	end, { rate = 1, burst = 3 })
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
end

function QuestService:Start()
	Deps.connect("WorkService", "TaskCompleted", function(player: Player, taskId: string, result: any)
		local q = if type(result) == "table" then Deps.num(result.quality, 0) else 0
		QuestService:Progress(player, { kind = "task", taskId = taskId, quality = q })
	end)
	Deps.connect("PortfolioService", "Traded", function(player: Player, trade: any)
		if not QuestLine.Awards.isPlayerTrade(trade) then
			return
		end
		local pnl = if type(trade) == "table" then Deps.num(trade.pnl, 0) else 0
		QuestService:Progress(player, { kind = "trade", pnl = pnl })
	end)
	Deps.connect("CareerService", "ReviewCompleted", function(player: Player, review: any)
		local band = if type(review) == "table" then review.band else nil
		QuestService:Progress(player, { kind = "review", band = band })
	end)
	Deps.connect("CareerService", "DealRecorded", function(player: Player, _plaque: any)
		QuestService:Progress(player, { kind = "deal" })
	end)
	Deps.connect("WardrobeService", "LookChanged", function(player: Player, _equipped: any, level: any)
		QuestService:Progress(player, { kind = "outfit", level = Deps.num(level, 0) })
	end)
end

return QuestService
