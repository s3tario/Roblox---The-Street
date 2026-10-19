--!strict
-- AchievementService (server, owned by `tutorial`): about 35 permanent achievements (Config/Achievements) unlocked
-- from other features' signals. Rules: Logic/QuestLine/Awards (pure). Data: data.achievements { [id] = unix time }
-- and data.achievementProgress (counters), both kept through rebirths, firings and fresh starts.
--
-- Events come from: ProfileService.ProfileLocked (the Life Roll), WorkService.TaskCompleted, PortfolioService.Traded,
-- CareerService (OffersChanged, RoleChanged, StatusChanged, ReviewCompleted, DealRecorded, LevelChanged),
-- ProfileService.PerkConsumed (Alumni Lifeline), ProjectService.ProjectCompleted, WardrobeService.LookChanged, and the
-- tutorial itself (chain steps, NPC talks, card exchanges). On load a catch-up pass unlocks anything the current
-- state already earned (e.g. a save from before achievements existed).
--
-- API:
--   AchievementService:Record(player, event) -> { id }     any feature may report an event (Awards event kinds)
--   AchievementService:Unlock(player, id) -> boolean       direct unlock (admin, scripted moments)
--   AchievementService:Has(player, id) -> boolean          AchievementService:Count(player) -> number
-- Signals: Unlocked(player, id)

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Achievements = require(Shared.Config.Achievements)
local Companies = require(Shared.Config.Companies)
local CareerState = require(Shared.Logic.CareerState)
local QuestLine = require(Shared.Logic.QuestLine)
local Deps = require(script.Parent.TutorialService.Deps)

local Awards = QuestLine.Awards

local AchievementService = {
	Name = "AchievementService",
	Priority = 65,
	Unlocked = Signal.new(), -- (player, id)
}

type PState = { offers: number, comebacks: number }
local states: { [Player]: PState } = {}

local function stores(player: Player): ({ [string]: any }?, { [string]: any }?)
	local data = Deps.data(player)
	if not data then
		return nil, nil
	end
	if type(data.achievements) ~= "table" then
		data.achievements = {}
	end
	if type(data.achievementProgress) ~= "table" then
		data.achievementProgress = {}
	end
	return data.achievements, data.achievementProgress
end

local function announce(player: Player, def: Achievements.Def)
	Deps.notify(player, Achievements.text("unlocked", { name = def.name }), "good")
	local tier = Achievements.TIERS[def.tier]
	if tier and tier.banner then
		Deps.banner(player, {
			title = Achievements.text("banner_title"),
			subtitle = Achievements.text("banner_sub", { glyph = def.glyph, name = def.name, desc = def.desc }),
			style = "celebration",
			duration = 5,
		})
	end
end

local function stamp(player: Player, unlocked: { [string]: any }, ids: { string }, quiet: boolean)
	if #ids == 0 then
		return
	end
	local now = os.time()
	for _, id in ids do
		local def = Achievements.get(id)
		if def and unlocked[id] == nil then
			unlocked[id] = now
			if not quiet then
				announce(player, def)
			end
			Deps.audit(player, "achievement", { id = id })
			AchievementService.Unlocked:Fire(player, id)
		end
	end
	Deps.replicate(player, "achievements")
end

function AchievementService:Record(player: Player, event: { [string]: any }): { string }
	if not Deps.isLive(player) or type(event) ~= "table" or type(event.kind) ~= "string" then
		return {}
	end
	local unlocked, progress = stores(player)
	if not unlocked or not progress then
		return {}
	end
	local ids = Awards.process(Achievements.list, unlocked, progress, event)
	Deps.replicate(player, "achievementProgress")
	stamp(player, unlocked, ids, false)
	return ids
end

function AchievementService:Unlock(player: Player, id: string): boolean
	local unlocked = stores(player)
	if not unlocked or not Achievements.get(id) or unlocked[id] ~= nil then
		return false
	end
	stamp(player, unlocked, { id }, false)
	return true
end

function AchievementService:Has(player: Player, id: string): boolean
	local unlocked = stores(player)
	return unlocked ~= nil and unlocked[id] ~= nil
end

function AchievementService:Count(player: Player): number
	local unlocked = stores(player)
	return Awards.count(unlocked)
end

---------------------------------------------------------------------------------------------------
-- Events from the current state
---------------------------------------------------------------------------------------------------
local function lifeRollEvent(profile: any): { [string]: any }?
	if type(profile) ~= "table" or profile.built ~= true then
		return nil
	end
	local rarities: { string } = {}
	local function add(x: any)
		if type(x) == "table" and type(x.rarity) == "string" then
			table.insert(rarities, x.rarity)
		end
	end
	add(profile.school)
	add(profile.family)
	if type(profile.clubs) == "table" then
		for _, c in profile.clubs do
			add(c)
		end
	end
	add(profile.outfitRoll)
	return {
		kind = "life_roll",
		rarities = rarities,
		schoolRarity = if type(profile.school) == "table" then profile.school.rarity else nil,
		gpa = Deps.num(profile.gpa, 0),
	}
end

local function outfitEvent(player: Player, level: number): { [string]: any }
	local career = Deps.career(player)
	local required: number? = nil
	if career and CareerState.isEmployed(career) then
		local company = Companies.get(career.companyId)
		required = if company then company.minOutfitLevel else nil
	end
	return { kind = "outfit", level = level, required = required }
end

local function currentOutfit(player: Player): number
	local ok, level = Deps.call("WardrobeService", "GetOutfitLevel", player)
	if ok and type(level) == "number" then
		return level
	end
	return Deps.num(player:GetAttribute("OutfitLevel"), 1)
end

-- On load: unlock what the saved state already shows (no counters bumped, no toasts).
local function catchUp(player: Player)
	local data = Deps.data(player)
	local unlocked, progress = stores(player)
	if not data or not unlocked or not progress then
		return
	end
	local career = if type(data.career) == "table" then data.career else {}
	local events: { { [string]: any } } = {}
	local roll = lifeRollEvent(data.profile)
	if roll then
		table.insert(events, roll)
	end
	table.insert(events, { kind = "level", level = Deps.num(career.level, 1) })
	if Deps.num(career.rank, 0) >= 2 then
		table.insert(events, { kind = "promotion", rank = Deps.num(career.rank, 0) })
	end
	if Deps.num(career.plaqueCount, 0) > 0 then
		table.insert(events, { kind = "plaque" })
	end
	if Deps.num(career.comebacks, 0) > 0 then
		table.insert(events, { kind = "comeback" })
	end
	local campus = if type(data.campus) == "table" then data.campus else {}
	if campus.step == "done" then
		table.insert(events, { kind = "step", step = "done" })
	end
	if campus.club == true then
		table.insert(events, { kind = "step", step = "club" })
	end
	table.insert(events, outfitEvent(player, currentOutfit(player)))
	local found: { string } = {}
	for _, e in events do
		for _, id in Awards.check(Achievements.list, unlocked, progress, e) do
			if not table.find(found, id) then
				table.insert(found, id)
			end
		end
	end
	stamp(player, unlocked, found, true)
end

local function stateOf(player: Player): PState
	local st = states[player]
	if not st then
		local career = Deps.career(player)
		st = {
			offers = if career and type(career.offers) == "table" then #career.offers else 0,
			comebacks = if career then Deps.num(career.comebacks, 0) else 0,
		}
		states[player] = st
	end
	return st
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function AchievementService:Init()
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
end

function AchievementService:Start()
	local function record(player: Player, event: { [string]: any })
		AchievementService:Record(player, event)
	end
	Deps.connect("DataService", "ProfileLoaded", function(player: Player)
		stateOf(player)
		task.delay(4, function()
			if Deps.isLive(player) then
				catchUp(player)
			end
		end)
	end)
	Deps.connect("ProfileService", "ProfileLocked", function(player: Player)
		local data = Deps.data(player)
		local e = if data then lifeRollEvent(data.profile) else nil
		if e then
			record(player, e)
		end
	end)
	Deps.connect("ProfileService", "PerkConsumed", function(player: Player, perkId: string)
		if perkId == "alumni_lifeline" then
			record(player, { kind = "lifeline" })
		end
	end)
	Deps.connect("WorkService", "TaskCompleted", function(player: Player, taskId: string, result: any)
		local q = if type(result) == "table" then Deps.num(result.quality, 0) else 0
		record(player, { kind = "task", taskId = taskId, quality = q })
	end)
	Deps.connect("PortfolioService", "Traded", function(player: Player, trade: any)
		if Awards.isPlayerTrade(trade) then
			record(player, { kind = "trade", pnl = if type(trade) == "table" then Deps.num(trade.pnl, 0) else 0 })
		end
	end)
	Deps.connect("CareerService", "OffersChanged", function(player: Player)
		local st = stateOf(player)
		local career = Deps.career(player)
		local n = if career and type(career.offers) == "table" then #career.offers else 0
		if n > st.offers then
			record(player, { kind = "offer", held = n })
		end
		st.offers = n
	end)
	Deps.connect("CareerService", "RoleChanged", function(player: Player, _new: string, _old: string, reason: string)
		local career = Deps.career(player)
		if not career then
			return
		end
		local st = stateOf(player)
		local comebacks = Deps.num(career.comebacks, 0)
		if comebacks > st.comebacks or reason == "reentry" or reason == "reinstated" then
			record(player, { kind = "comeback" })
		end
		st.comebacks = comebacks
		local company = Companies.get(career.companyId)
		if reason == "hired" or reason == "lateral" then
			local hiring = if company then Companies.hiring(company.id, career.track) else nil
			record(player, {
				kind = "hired",
				source = if hiring and hiring.walkOn then "walk_on" else "recruiting",
				companyType = if company then company.type else nil,
				companyId = career.companyId,
			})
			record(player, outfitEvent(player, currentOutfit(player)))
		elseif reason == "promotion" then
			record(player, { kind = "promotion", rank = Deps.num(career.rank, 0) })
		end
	end)
	Deps.connect("CareerService", "StatusChanged", function(player: Player, new: string, old: string)
		record(player, { kind = "status", from = old, to = new })
	end)
	Deps.connect("CareerService", "ReviewCompleted", function(player: Player, review: any)
		if type(review) ~= "table" then
			return
		end
		record(player, { kind = "review", band = review.band })
		if review.lifeline == true then
			record(player, { kind = "lifeline" })
		end
	end)
	Deps.connect("CareerService", "DealRecorded", function(player: Player)
		record(player, { kind = "plaque" })
	end)
	Deps.connect("CareerService", "LevelChanged", function(player: Player, newLevel: number)
		record(player, { kind = "level", level = Deps.num(newLevel, 1) })
	end)
	Deps.connect("ProjectService", "ProjectCompleted", function(player: Player, projectId: string, result: any)
		local closed = type(result) == "table" and result.closed == true
		record(player, { kind = "project", projectId = projectId, closed = closed })
	end)
	Deps.connect("WardrobeService", "LookChanged", function(player: Player, _equipped: any, level: any)
		record(player, outfitEvent(player, Deps.num(level, 1)))
	end)
	for _, player in Players:GetPlayers() do
		if Deps.data(player) then
			stateOf(player)
			task.spawn(catchUp, player)
		end
	end
end

return AchievementService
