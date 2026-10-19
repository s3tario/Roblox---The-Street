--!strict
-- SocialService (server, owned by `tutorial`; design v3 §14b, contracts §14): name tags, profile cards and business
-- card exchanges between players, plus the mentorship XP boost hook WorkService reads.
--
--   * Name tags: every player carries attributes the clients draw tags from (SocialController): FullName (filtered
--     first name + family name, set by ProfileService), TagTitle, TagCompany, TagCompanyId, TagPrimary, TagAccent
--     ("#RRGGBB" company colours), TagLevel. Refreshed on load, role/level/status changes and every 10 s.
--   * Profile cards: "Social.GetCard"(userId) -> Card? returns only public data (the Life Roll public view, title,
--     company, level, Fit Score, outfit level, plaques, rebirths, achievements count, aura tier).
--   * Exchanging cards: "Social.Network"(userId) -> (ok, errKey?, card?): within 15 studs, once per pair per real
--     (UTC) day (Logic/QuestLine/Network, logged on both players). Both get Network stat XP and a little reputation,
--     and the exchange counts as a contact for the campus networking step.
--
-- API:
--   SocialService:GetCard(viewer, target) -> Card?        SocialService:Exchange(player, target) -> (ok, errKey?)
--   SocialService:RefreshTag(player)
--   SocialService:GetXpBoost(player) -> number            1 when none (contracts §14; WorkService multiplies XP)
--   SocialService:ConsumeXpBoost(player)                  one boosted task used
--   SocialService:GrantXpBoost(player, mult, tasks, source)   mentorship (M3) and events
-- Signals: Exchanged(player, other)

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local Signal = require(Shared.Util.Signal)
local Companies = require(Shared.Config.Companies)
local Quests = require(Shared.Config.Quests)
local Achievements = require(Shared.Config.Achievements)
local CareerState = require(Shared.Logic.CareerState)
local LifeRoll = require(Shared.Logic.LifeRoll)
local QuestLine = require(Shared.Logic.QuestLine)
local Deps = require(script.Parent.TutorialService.Deps)

local Network = QuestLine.Network

local SocialService = {
	Name = "SocialService",
	Priority = 60,
	Exchanged = Signal.new(), -- (player, other)
}

local TAG_EVERY = 10
local EXCHANGE_XP_QUALITY = 70
local EXCHANGE_REPUTATION = 2
local MAX_BOOST = 2

local busy: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function text(key: string, vars: { [string]: any }?): string
	return Quests.text(key, vars)
end

local function setAttr(player: Player, name: string, value: any)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

local function displayName(player: Player): string
	local full = player:GetAttribute("FullName")
	if type(full) == "string" and full ~= "" then
		return full
	end
	return player.DisplayName
end

---------------------------------------------------------------------------------------------------
-- Name tags
---------------------------------------------------------------------------------------------------
function SocialService:RefreshTag(player: Player)
	if not Deps.isLive(player) then
		return
	end
	local career = Deps.career(player)
	if not career then
		return
	end
	local employed = CareerState.isEmployed(career)
	local company = if employed then Companies.get(career.companyId) else nil
	local title = if type(career.title) == "string" and career.title ~= "" then career.title else text("tag_student")
	setAttr(player, "TagTitle", title)
	setAttr(player, "TagCompany", if company then company.name else "")
	setAttr(player, "TagCompanyId", if company then company.id else "")
	setAttr(player, "TagPrimary", if company then company.hex.primary else "")
	setAttr(player, "TagAccent", if company then company.hex.accent else "")
	setAttr(player, "TagLevel", math.floor(Deps.num(career.level, 1)))
end

---------------------------------------------------------------------------------------------------
-- Profile cards
---------------------------------------------------------------------------------------------------
local function distanceBetween(a: Player, b: Player): number
	local ra, rb = Deps.root(a), Deps.root(b)
	if not ra or not rb then
		return math.huge
	end
	return (ra.Position - rb.Position).Magnitude
end

function SocialService:GetCard(viewer: Player, target: Player): { [string]: any }?
	local data = Deps.data(target)
	if not data then
		return nil
	end
	local profile = if type(data.profile) == "table" then data.profile else {}
	local career = if type(data.career) == "table" then data.career else {}
	local okPublic, public = Deps.call("ProfileService", "GetPublicProfile", target)
	if not okPublic or type(public) ~= "table" then
		local okView, view =
			pcall(LifeRoll.publicView, profile, { userId = target.UserId, displayName = target.DisplayName })
		public = if okView then view else nil
	end
	local employed = CareerState.isEmployed(career)
	local company = if employed then Companies.get(career.companyId) else nil
	local outfit = target:GetAttribute("OutfitLevel")
	local character = target.Character
	local aura = if character then character:GetAttribute("AuraTier") else nil
	local viewerCampus = Deps.campus(viewer)
	local isSelf = viewer == target
	local dist = if isSelf then 0 else distanceBetween(viewer, target)
	local exchanged = viewerCampus ~= nil and Network.exchangedToday(viewerCampus.exchanges, target.UserId, os.time())
	local plaques = Deps.num(career.plaqueCount, if type(career.plaques) == "table" then #career.plaques else 0)
	return {
		userId = target.UserId,
		displayName = target.DisplayName,
		name = displayName(target),
		public = public,
		career = {
			title = if type(career.title) == "string" then career.title else text("card_student"),
			level = math.floor(Deps.num(career.level, 1)),
			rank = math.floor(Deps.num(career.rank, 0)),
			track = if type(career.track) == "string" then career.track else "",
			status = if type(career.status) == "string" then career.status else "student",
			employed = employed,
		},
		company = if company
			then {
				id = company.id,
				name = company.name,
				logo = company.logo,
				typeName = company.typeName,
				primary = company.hex.primary,
				accent = company.hex.accent,
			}
			else nil,
		fitScore = math.floor(Deps.num(career.fitScore, 0)),
		outfitLevel = math.floor(Deps.num(outfit, Deps.num(career.outfitLevel, 1))),
		plaques = math.floor(plaques),
		rebirths = math.floor(Deps.num(profile.rebirths, 0)),
		achievements = QuestLine.Awards.count(data.achievements),
		achievementsTotal = #Achievements.list,
		aura = math.floor(Deps.num(aura, 0)),
		isSelf = isSelf,
		exchangedToday = exchanged,
		inRange = dist <= Network.RANGE,
		range = Network.RANGE,
	}
end

---------------------------------------------------------------------------------------------------
-- Exchanging cards
---------------------------------------------------------------------------------------------------
local function rewardExchange(player: Player, other: Player)
	Deps.call("ProfileService", "AwardStatXp", player, { "network" }, EXCHANGE_XP_QUALITY, "task")
	local career = Deps.career(player)
	if career and CareerState.isEmployed(career) then
		Deps.call("CareerService", "AddReputation", player, EXCHANGE_REPUTATION, "networking")
	end
	Deps.call("TutorialService", "AddContact", player, "player:" .. Network.key(other.UserId))
	Deps.call("AchievementService", "Record", player, { kind = "exchange" })
end

function SocialService:Exchange(player: Player, target: Player): (boolean, string?)
	if player == target then
		return false, "self"
	end
	if not Deps.isLive(target) then
		return false, "gone"
	end
	local a = Deps.campus(player)
	local b = Deps.campus(target)
	if not a or not b then
		return false, "loading"
	end
	if busy[player] or busy[target] then
		return false, "generic"
	end
	local now = os.time()
	Network.prune(a.exchanges, now)
	Network.prune(b.exchanges, now)
	local ok, err = Network.check(
		{ userId = player.UserId, log = a.exchanges },
		{ userId = target.UserId, log = b.exchanges },
		distanceBetween(player, target),
		now
	)
	if not ok then
		return false, err
	end
	busy[player], busy[target] = true, true
	Network.record(a.exchanges, target.UserId, now)
	Network.record(b.exchanges, player.UserId, now)
	Deps.replicate(player, "campus")
	Deps.replicate(target, "campus")
	local okReward, rewardErr = pcall(function()
		rewardExchange(player, target)
		rewardExchange(target, player)
	end)
	busy[player], busy[target] = nil, nil
	if not okReward then
		Deps.warnOnce("exchange rewards", rewardErr)
	end
	Deps.notify(player, text("exchange_done", { name = displayName(target) }), "good")
	Deps.notify(target, text("exchange_received", { name = displayName(player) }), "good")
	Deps.audit(player, "card_exchange", { other = target.UserId })
	SocialService.Exchanged:Fire(player, target)
	return true, nil
end

---------------------------------------------------------------------------------------------------
-- XP boost (mentorship hook)
---------------------------------------------------------------------------------------------------
function SocialService:GetXpBoost(player: Player): number
	local campus = Deps.campus(player)
	local b = if campus then campus.xpBoost else nil
	if type(b) == "table" and Deps.num(b.left, 0) > 0 and Deps.num(b.mult, 1) > 1 then
		return math.clamp(Deps.num(b.mult, 1), 1, MAX_BOOST)
	end
	return 1
end

function SocialService:ConsumeXpBoost(player: Player)
	local campus = Deps.campus(player)
	local b = if campus then campus.xpBoost else nil
	if type(b) == "table" and Deps.num(b.left, 0) > 0 then
		b.left = math.max(0, math.floor(Deps.num(b.left, 0)) - 1)
		if b.left == 0 then
			b.mult = 1
		end
		Deps.replicate(player, "campus")
	end
end

function SocialService:GrantXpBoost(player: Player, mult: number, tasks: number, source: string?): boolean
	local campus = Deps.campus(player)
	if not campus then
		return false
	end
	local m = math.clamp(Deps.num(mult, 1), 1, MAX_BOOST)
	local n = math.clamp(math.floor(Deps.num(tasks, 0)), 0, 20)
	if m <= 1 or n <= 0 then
		return false
	end
	campus.xpBoost = { mult = m, left = n, source = if type(source) == "string" then string.sub(source, 1, 32) else "" }
	Deps.replicate(player, "campus")
	return true
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
local function targetFrom(raw: any): Player?
	local userId = Guard.int(raw, 1, 2 ^ 53)
	if not userId then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

function SocialService:Init()
	Net.handle("Social.GetCard", function(player: Player, rawUserId: any)
		local target = targetFrom(rawUserId)
		if not target then
			return nil, "gone"
		end
		local card = SocialService:GetCard(player, target)
		if not card then
			return nil, "loading"
		end
		return card, nil
	end, { rate = 2, burst = 6 })
	Net.handle("Social.Network", function(player: Player, rawUserId: any)
		local target = targetFrom(rawUserId)
		if not target then
			return false, "gone", nil
		end
		local ok, err = SocialService:Exchange(player, target)
		return ok, err, SocialService:GetCard(player, target)
	end, { rate = 0.5, burst = 3 })
end

function SocialService:Start()
	local function refresh(player: any)
		if Deps.isLive(player) then
			SocialService:RefreshTag(player)
		end
	end
	Deps.connect("DataService", "ProfileLoaded", refresh)
	for _, name in { "RoleChanged", "LevelChanged", "StatusChanged" } do
		Deps.connect("CareerService", name, function(player: Player)
			task.defer(refresh, player)
		end)
	end
	for _, player in Players:GetPlayers() do
		refresh(player)
	end
	while true do
		task.wait(TAG_EVERY)
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(function()
				refresh(player)
			end)
			if not ok then
				Deps.warnOnce("tag refresh", err)
			end
		end
	end
end

return SocialService
