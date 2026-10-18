--!strict
-- ProfileService (server, owned by `careerCore`; docs/contracts.md §3-§4, design v3 §1-§3): the Life Roll, the
-- eight attributes, OVR, archetype, focus and perks. Rules live in Shared/Logic/LifeRoll and Shared/Logic/Stats;
-- this service validates, applies, persists (data.profile) and replicates.
--
-- Life Roll flow (v3 §2): a first join with profile.built = false opens the LifeRoll screen (CareerCoreController
-- reads the replicated profile; the campus "profile_builder" interact reopens it). SetName filters the first name
-- (TextService; a filter outage falls back to "Rookie") and, the first time, rolls every field into
-- profile.pending (saved, so rejoining never re-rolls). The client spins its reels to the server's results. Each
-- RerollField re-rolls ONE field, paid with a free reroll (3, +1 with a Legacy Seat), then a Profile Refresh token,
-- then a Profile Reroll credit; with none left it answers "needs_purchase". Lock applies stats + boosts + perks,
-- pays the family's starting cash (EconomyService:AddCash "reward"; retried on later loads if the economy is
-- down), grants and equips the rolled outfit and heirloom (WardrobeService:Grant with equip) and fires
-- ProfileLocked. A Mythic result triggers a server-wide banner timed to land with the reel.
--
-- API (contracts §4):
--   :GetProfile(player) -> profile?                 live table: read-only for other features
--   :GetPublicProfile(player) -> PublicProfile?     the profile-card view (Logic/LifeRoll.publicView)
--   :GetStats(player) -> {knowledge, skill, speed, charisma, network, discipline, risk, luck}   (copy)
--   :GetStat(player, statId) -> 1..99               :GetOVR(player) -> 1..99
--   :GetStatEffects(player) -> Stats.effects(...)   timerMult, hints, toleranceMult, charismaBonus, ...
--   :AwardStatXp(player, statIds, quality 0..100, source?) -> AwardResult?   the ONLY stat growth path (focus
--       applied inside; source "review" | "project" | "deal" | "task" scales the XP); toasts "+1 Skill"
--   :HasPerk(player, perkId) -> boolean             :ConsumePerk(player, perkId) -> boolean
--   :GrantCredit(player, "reroll" | "rebuild", n?) -> boolean   (monetization)
--   :AddRefreshToken(player, n, source) -> boolean
--   :GetIncomeMult(player) -> 1.0..3.0              (1 + 0.1 x rebirths; rebirths stay 0 until M4)
--   :GetSchoolTierOrder(player) -> 1..6             (+1 with Boardroom Pedigree; 1 before lock-in)
--   :GetFocus(player) -> focusId?                   :OpenFor(player, args?)   opens the Life Roll screen
--   :SetName / :RerollField / :Lock / :SetFocus / :Rebuild   (remotes, see Remotes.luau)
-- Signals:
--   ProfileLocked(player)                     life roll finished (first time; M4: after each rebirth)
--   ProfileChanged(player, reason)            "rebuild" | "perk" | "focus"
--   StatChanged(player, statId, new, old)     OvrChanged(player, new, old)     PerkConsumed(player, perkId, left)
-- Player attributes (for nameplates, auras and profile cards on every client): ProfileBuilt, OVR, Archetype,
-- FullName, SchoolId, SchoolRarity, Rebirths.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.LifeRoll)
local Catalog = require(Shared.Config.Catalog)
local LifeRoll = require(Shared.Logic.LifeRoll)
local Stats = require(Shared.Logic.Stats)
local Signal = require(Shared.Util.Signal)
local Rng = require(Shared.Util.Rng)
local Hash = require(Shared.Util.Hash)
local Time = require(Shared.Util.Time)
local Format = require(Shared.Util.Format)
local TableUtil = require(Shared.Util.TableUtil)
local Deps = require(script.Deps)
local Names = require(script.Names)
local Prompts = require(script.Prompts)
local Remotes = require(script.Remotes)

local ProfileService = { Name = "ProfileService", Priority = 30 }

ProfileService.ProfileLocked = Signal.new() -- (player)
ProfileService.ProfileChanged = Signal.new() -- (player, reason)
ProfileService.StatChanged = Signal.new() -- (player, statId, newValue, oldValue)
ProfileService.OvrChanged = Signal.new() -- (player, newOvr, oldOvr)
ProfileService.PerkConsumed = Signal.new() -- (player, perkId, usesLeft)

local OPEN_COOLDOWN = 0.5
local BANNER_MARGIN = 0.35 -- seconds after the reel lands (network latency)
local CASH_RETRY = 4
local MAX_GRANT = 100
local DEFAULT_STAT = 40

type PState = { busy: boolean, lastOpen: number, rollSeq: number }

local states: { [Player]: PState } = {}

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
local function inGame(player: Player): boolean
	return player.Parent == Players
end

local function stateOf(player: Player): PState?
	local st = states[player]
	if st == nil and inGame(player) then
		st = { busy = false, lastOpen = 0, rollSeq = 0 }
		states[player] = st
	end
	return st
end

-- loaded data tables whose profile has been repaired (weak: a reload brings a new table)
local normalized: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function profileOf(player: Player): any
	local data = Deps.data(player)
	if not data then
		return nil
	end
	if not normalized[data] or type(data.profile) ~= "table" then
		normalized[data] = true
		data.profile = LifeRoll.normalize(data.profile)
	end
	return data.profile
end

local function ctxFor(p: any): LifeRoll.Ctx
	return { rebirths = p.rebirths }
end

local function rngFor(player: Player, st: PState): Rng.Rng
	st.rollSeq += 1
	return Rng.new(Hash.u32("liferoll", player.UserId, Time.now(), os.clock(), st.rollSeq, game.JobId))
end

local function weekKey(player: Player): string
	return LifeRoll.weekKey(Deps.careerWeek(player), Deps.activeSeconds(player))
end

local function replicate(player: Player)
	Deps.replicate(player, "profile")
end

local function setAttributes(player: Player, p: any)
	if not inGame(player) then
		return
	end
	local view = LifeRoll.publicView(p, { userId = player.UserId, displayName = player.DisplayName })
	local attrs: { [string]: any } = {
		ProfileBuilt = view.built,
		OVR = view.ovr,
		Archetype = if view.built then view.archetype.name else "",
		FullName = if view.built then view.fullName else "",
		SchoolId = if view.school then view.school.id else "",
		SchoolRarity = if view.school then view.school.rarity else "",
		Rebirths = view.rebirths,
	}
	for name, value in attrs do
		if player:GetAttribute(name) ~= value then
			player:SetAttribute(name, value)
		end
	end
end

local function statName(statId: string): string
	local def = Config.stat(statId)
	return if def then def.name else statId
end

-- Server-wide Mythic banners, each delayed until its reel has landed on the client.
local function announceMythics(player: Player, mythics: { { field: string, text: string } }, firstSpin: boolean)
	for _, m in mythics do
		local delay = Config.SPIN.reroll
		if firstSpin then
			delay = Config.revealDelay(table.find(Config.FIELDS, m.field) or 1)
		end
		Deps.audit(player, "mythic_roll", { field = m.field, value = m.text })
		task.delay(delay + BANNER_MARGIN, function()
			if not inGame(player) then
				return
			end
			local p = profileOf(player)
			local name = if p and p.firstName ~= "" then p.firstName else player.DisplayName
			Deps.banner(nil, {
				title = Config.text("mythic_title"),
				subtitle = Config.text("mythic_sub", { name = name, value = m.text }),
				style = "celebration",
				duration = 5,
			})
		end)
	end
end

local function rollSummary(roll: any): { [string]: any }
	local out: { [string]: any } = {}
	if type(roll) ~= "table" then
		return out
	end
	for _, field in Config.FIELDS do
		out[field] = LifeRoll.describe(field, roll[field])
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Lock-in rewards
---------------------------------------------------------------------------------------------------
local function payCash(player: Player)
	local p = profileOf(player)
	if not p or p.built ~= true or p.cashPaid == true or (tonumber(p.startCash) or 0) <= 0 then
		return
	end
	if not inGame(player) then
		return
	end
	if Deps.addCash(player, p.startCash, "life_roll") then
		p.cashPaid = true
		replicate(player)
		Deps.notify(player, Config.text("cash_paid", { cash = Format.money(p.startCash) }), "cash")
		Deps.audit(player, "life_roll_cash", { amount = p.startCash })
	end
end

local function grantOutfit(player: Player, result: LifeRoll.LockResult)
	local slots: { [string]: boolean } = {}
	for _, id in result.itemIds do
		local item = Catalog.get(Catalog.canonical(id))
		if item then
			slots[item.slot] = true
			Deps.grantItem(player, item.id, item.slot, "life_roll", true)
		end
	end
	local heirloom = if result.heirloom then Catalog.get(result.heirloom) else nil
	if heirloom then
		-- worn when the rolled look leaves its slot free (the look is what WardrobeService puts on at lock-in)
		Deps.grantItem(player, heirloom.id, heirloom.slot, "heirloom", not slots[heirloom.slot])
	end
end

---------------------------------------------------------------------------------------------------
-- Life Roll
---------------------------------------------------------------------------------------------------
function ProfileService:SetName(player: Player, raw: string): (boolean, string?, any)
	local st = stateOf(player)
	local p = profileOf(player)
	if not st or not p then
		return false, "not_loaded", nil
	end
	if p.built then
		return false, "already_built", nil
	end
	if st.busy then
		return false, "busy", nil
	end
	local name, err = LifeRoll.validName(raw)
	if not name then
		return false, err, nil
	end
	st.busy = true
	local filtered, status = Names.filter(name, player.UserId, Config.rules.nameFallback)
	st.busy = false
	-- the filter yields: the player may have left, or the profile may have been released meanwhile
	if not inGame(player) or states[player] ~= st then
		return false, "not_loaded", nil
	end
	p = profileOf(player)
	if not p then
		return false, "not_loaded", nil
	end
	if p.built then
		return false, "already_built", nil
	end
	if status == "blocked" then
		return false, "name_filtered", nil
	end
	p.firstName = filtered
	local started = LifeRoll.startRoll(p, rngFor(player, st), ctxFor(p))
	replicate(player)
	setAttributes(player, p)
	if started then
		Deps.audit(player, "life_roll_start", rollSummary(p.pending))
		local roll = LifeRoll.normalizeRoll(p.pending)
		if roll then
			announceMythics(player, LifeRoll.mythics(roll), true)
		end
	end
	if status == "failed" then
		Deps.notify(player, Config.text("name_fallback"), "warn")
	end
	return true,
		nil,
		{
			name = filtered,
			fallback = status == "failed",
			started = started,
			pending = TableUtil.deepCopy(p.pending),
			rerollsLeft = p.rerollsLeft,
		}
end

function ProfileService:RerollField(player: Player, field: string): (boolean, string?, any)
	local st = stateOf(player)
	local p = profileOf(player)
	if not st or not p then
		return false, "not_loaded", nil
	end
	if st.busy then
		return false, "busy", nil
	end
	local ok, err, source, value = LifeRoll.reroll(p, field, rngFor(player, st), ctxFor(p))
	if not ok then
		return false, err, { field = field, needsPurchase = err == "needs_purchase" }
	end
	replicate(player)
	Deps.audit(player, "life_roll_reroll", { field = field, source = source, value = LifeRoll.describe(field, value) })
	local roll = LifeRoll.normalizeRoll(p.pending)
	if roll then
		announceMythics(player, LifeRoll.mythics(roll, { field }), false)
	end
	return true,
		nil,
		{
			field = field,
			value = TableUtil.deepCopy(value),
			source = source,
			rerollsLeft = p.rerollsLeft,
			refreshTokens = p.refreshTokens,
			credits = { reroll = p.credits.reroll, rebuild = p.credits.rebuild },
		}
end

function ProfileService:Lock(player: Player): (boolean, string?, any)
	local st = stateOf(player)
	local p = profileOf(player)
	if not st or not p then
		return false, "not_loaded", nil
	end
	if st.busy then
		return false, "busy", nil
	end
	local result, err = LifeRoll.lock(p, Time.now())
	if not result then
		return false, err, nil
	end
	replicate(player)
	setAttributes(player, p)
	local summary = rollSummary(p)
	summary.ovr = p.ovr
	summary.archetype = p.archetype
	Deps.audit(player, "life_roll_lock", summary)
	-- rewards may yield (wardrobe pass checks): answer the client now, finish them in their own thread
	st.busy = true
	task.spawn(function()
		payCash(player)
		local fresh = profileOf(player)
		if fresh and not fresh.cashPaid then
			task.delay(CASH_RETRY * 3, payCash, player)
		end
		grantOutfit(player, result)
		st.busy = false
		if inGame(player) then
			ProfileService.ProfileLocked:Fire(player)
		end
	end)
	local view = LifeRoll.publicView(p, { userId = player.UserId, displayName = player.DisplayName })
	Deps.banner(player, {
		title = Config.text("locked_banner", { name = view.fullName }),
		subtitle = Config.text("locked_banner_sub", {
			school = if view.school then view.school.name else "",
			archetype = view.archetype.name,
			ovr = view.ovr,
		}),
		style = "celebration",
		duration = 6,
	})
	Deps.submitBoard(player, "TopStats", p.ovr)
	return true, nil, view
end

function ProfileService:SetFocus(player: Player, focusId: string): (boolean, string?, any)
	local p = profileOf(player)
	if not p then
		return false, "not_loaded", nil
	end
	local before = p.focus
	local ok, err = LifeRoll.setFocus(p, focusId, weekKey(player))
	if not ok then
		return false, err, nil
	end
	if p.focus ~= before then
		replicate(player)
		local def = Config.focusDef(p.focus)
		Deps.notify(player, Config.text("focus_set", { focus = if def then def.name else p.focus }), "good")
		Deps.audit(player, "profile_focus", { from = before, to = p.focus })
		ProfileService.ProfileChanged:Fire(player, "focus")
	end
	return true, nil, nil
end

function ProfileService:Rebuild(player: Player, edits: { [string]: any }): (boolean, string?, any)
	local st = stateOf(player)
	local p = profileOf(player)
	if not st or not p then
		return false, "not_loaded", nil
	end
	if st.busy then
		return false, "busy", nil
	end
	if not p.built then
		return false, "not_built", nil
	end
	if (tonumber(p.credits.rebuild) or 0) < 1 then
		return false, "no_credit", nil
	end
	local before = rollSummary(p)
	local ok, err = LifeRoll.rebuild(p, edits)
	if not ok then
		return false, err, nil
	end
	p.credits.rebuild -= 1
	replicate(player)
	setAttributes(player, p)
	Deps.audit(player, "profile_rebuild", { before = before, after = rollSummary(p) })
	Deps.notify(player, Config.text("rebuild_done"), "good")
	ProfileService.ProfileChanged:Fire(player, "rebuild")
	return true, nil, nil
end

function ProfileService:RemoteGet(player: Player): (boolean, string?, any)
	local p = profileOf(player)
	if not p then
		return false, "not_loaded", nil
	end
	local key = weekKey(player)
	return true,
		nil,
		{
			profile = TableUtil.deepCopy(p),
			weekKey = key,
			canChangeFocus = LifeRoll.canChangeFocus(p, key),
		}
end

function ProfileService:OpenFor(player: Player, args: { [string]: any }?)
	Remotes.open(player, args)
end

---------------------------------------------------------------------------------------------------
-- Stats and perks
---------------------------------------------------------------------------------------------------
function ProfileService:GetProfile(player: Player): any
	return profileOf(player)
end

function ProfileService:GetPublicProfile(player: Player): LifeRoll.PublicProfile?
	local p = profileOf(player)
	if not p then
		return nil
	end
	return LifeRoll.publicView(p, { userId = player.UserId, displayName = player.DisplayName })
end

function ProfileService:GetStats(player: Player): { [string]: number }
	local p = profileOf(player)
	local out: { [string]: number } = {}
	local src = if p and type(p.stats) == "table" then p.stats else {}
	for _, id in Config.STAT_IDS do
		out[id] = if type(src[id]) == "number" then Stats.clamp(src[id]) else DEFAULT_STAT
	end
	return out
end

function ProfileService:GetStat(player: Player, statId: string): number
	local stats = self:GetStats(player)
	return stats[statId] or DEFAULT_STAT
end

function ProfileService:GetOVR(player: Player): number
	return Stats.ovr(self:GetStats(player))
end

function ProfileService:GetStatEffects(player: Player): { [string]: number }
	return Stats.effects(self:GetStats(player))
end

function ProfileService:GetFocus(player: Player): string?
	local p = profileOf(player)
	return if p and Config.focusDef(p.focus) then p.focus else nil
end

function ProfileService:AwardStatXp(player: Player, statIds: any, quality: any, source: any): Stats.AwardResult?
	local p = profileOf(player)
	if not p or p.built ~= true then
		return nil
	end
	local ids: { string } = {}
	if type(statIds) == "string" then
		ids = { statIds }
	elseif type(statIds) == "table" then
		for _, id in statIds do
			if type(id) == "string" then
				table.insert(ids, id)
			end
		end
	end
	if #ids == 0 then
		return nil
	end
	local q = if type(quality) == "number" and quality == quality then math.clamp(quality, 0, 100) else 0
	local src = if type(source) == "string" and Stats.SOURCE_MULT[source] then source else "task"
	local result = Stats.award(p, ids, q, src, weekKey(player))
	replicate(player)
	for _, up in result.ups do
		Deps.notify(player, Config.text("stat_up", { stat = statName(up.stat) }), "xp")
		ProfileService.StatChanged:Fire(player, up.stat, up.to, up.from)
	end
	if result.ovrTo ~= result.ovrFrom then
		setAttributes(player, p)
		ProfileService.OvrChanged:Fire(player, result.ovrTo, result.ovrFrom)
		if result.ovrTo > result.ovrFrom then
			Deps.notify(player, Config.text("ovr_up", { ovr = result.ovrTo }), "good")
		end
		Deps.submitBoard(player, "TopStats", result.ovrTo)
	end
	return result
end

function ProfileService:HasPerk(player: Player, perkId: string): boolean
	return LifeRoll.hasPerk(profileOf(player), perkId)
end

function ProfileService:ConsumePerk(player: Player, perkId: string): boolean
	local p = profileOf(player)
	if not p or not LifeRoll.consumePerk(p, perkId) then
		return false
	end
	local left = tonumber(p.perks[perkId]) or 0
	replicate(player)
	Deps.audit(player, "perk_consumed", { perk = perkId, left = left })
	ProfileService.PerkConsumed:Fire(player, perkId, left)
	ProfileService.ProfileChanged:Fire(player, "perk")
	return true
end

local function grantCount(n: any): number?
	if type(n) ~= "number" or n ~= n then
		return nil
	end
	local c = math.floor(n)
	if c < 1 or c > MAX_GRANT then
		return nil
	end
	return c
end

function ProfileService:GrantCredit(player: Player, kind: string, amount: number?): boolean
	if kind ~= "reroll" and kind ~= "rebuild" then
		return false
	end
	local n = grantCount(amount or 1)
	local p = profileOf(player)
	if not p or not n then
		return false
	end
	p.credits[kind] = (tonumber(p.credits[kind]) or 0) + n
	replicate(player)
	Deps.audit(player, "profile_credit", { kind = kind, n = n })
	Deps.notify(player, Config.text("credit_" .. kind), "good")
	return true
end

function ProfileService:AddRefreshToken(player: Player, n: number, source: string?): boolean
	local c = grantCount(n)
	local p = profileOf(player)
	if not p or not c then
		return false
	end
	p.refreshTokens = (tonumber(p.refreshTokens) or 0) + c
	replicate(player)
	Deps.audit(player, "refresh_token", { n = c, source = tostring(source or "unknown") })
	Deps.notify(player, Config.text("token_added", { n = c }), "good")
	return true
end

function ProfileService:GetIncomeMult(player: Player): number
	local p = profileOf(player)
	return LifeRoll.incomeMult(if p then p.rebirths else 0)
end

function ProfileService:GetSchoolTierOrder(player: Player): number
	return LifeRoll.schoolTierOrder(profileOf(player))
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
local function onLoaded(player: Player, loaded: any)
	local data = if type(loaded) == "table" then loaded else Deps.data(player)
	if not data or not inGame(player) then
		return
	end
	stateOf(player)
	normalized[data] = true
	data.profile = LifeRoll.normalize(data.profile)
	local p = data.profile
	if not p.built and next(p.pending) ~= nil and not LifeRoll.hasPending(p) then
		p.pending = {} -- unreadable after a config change: the next SetName rolls a fresh life
	end
	setAttributes(player, p)
	replicate(player)
	if p.built and not p.cashPaid then
		task.delay(CASH_RETRY, payCash, player)
	end
end

local function onPrompt(player: Player, _prompt: ProximityPrompt, companyId: string?)
	local st = stateOf(player)
	if not st then
		return
	end
	local now = os.clock()
	if now - st.lastOpen < OPEN_COOLDOWN then
		return
	end
	st.lastOpen = now
	if companyId and not Deps.isEmployeeOf(player, companyId) then
		Deps.notify(player, Config.text("employees_only"), "warn")
		return
	end
	Remotes.open(player, { source = "prompt" })
end

function ProfileService:Init()
	Remotes.bind(ProfileService)
	Deps.connect("DataService", "ProfileLoaded", onLoaded)
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
end

function ProfileService:Start()
	for _, player in Players:GetPlayers() do
		if Deps.isLoaded(player) then
			task.spawn(onLoaded, player, nil)
		end
	end
	Prompts.start(onPrompt)
end

return ProfileService
