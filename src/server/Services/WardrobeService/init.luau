--!strict
-- WardrobeService (server, owned by `wardrobe`; docs/contracts.md §10, design v3 §5 and §16): the player's Career
-- Look.
--
-- On every character (spawn, respawn) it waits for the avatar and the profile to load, remembers the avatar's own
-- HumanoidDescription, then (unless inventory.wearAvatar is on) standardizes the body and dresses it in
-- inventory.equipped with fitted 3D layers (Look.luau). A vest or quarter-zip shows the player's company logo on
-- the left chest (CareerService:GetCompany(player).logo); the look is redrawn when CareerService.RoleChanged fires.
-- If something rebuilds the body parts later, the layers are rebuilt on the new parts.
--
-- Data: the `inventory` key (Config/DataTemplate/Inventory). Starter outfits are granted per career stage; the
-- Life Roll outfit and the family heirloom (profile.outfitRoll, profile.family) are granted on load and put on when
-- ProfileService.ProfileLocked fires (a new life).
--
-- Modules: Character.luau (the per-character body state machine), Look.luau (HumanoidDescription and layers),
-- Inventory.luau (pure rules), Deps.luau (guarded calls into other features), Remotes.luau (Wardrobe.Equip /
-- SavePreset / LoadPreset / SetWearAvatar / GetAccess, Wardrobe.Open) and Prompts.luau ("wardrobe" prompts; inside
-- office instances only employees may use them).
--
-- API:
--   WardrobeService:ApplyLook(player) -> boolean            re-dress (yields while the body is standardized)
--   WardrobeService:Equip(player, slot, itemId?) -> ok, err
--   WardrobeService:Grant(player, itemId, source, opts?) -> boolean   true when the player owns it afterwards
--       opts = { equip: boolean?, notify: boolean? }  (shop, monetization, season, events)
--   WardrobeService:GrantLook(player, lookIdOrItemIds, source, opts?) -> boolean   Life Roll (equips by default)
--   WardrobeService:Owns(player, itemId) -> boolean         (may yield for pass items)
--   WardrobeService:GetEquipped(player) -> { [slot] = itemId }   what the Career Look is wearing
--   WardrobeService:GetOutfitLevel(player) -> level 1..5, parts  (v3 §5: lowest of torso, bottom, shoes)
--   WardrobeService:SavePreset(player, index, name?) / :LoadPreset(player, index) / :SetWearAvatar(player, on)
--   WardrobeService:GetAccess(player) -> { rank, passes, companyLogo?, outfitLevel }
--   WardrobeService:OpenFor(player, args?)                  opens the Wardrobe screen on that client
--   WardrobeService:RefreshAccess(player)                   forget cached pass ownership (after a pass purchase)
--   WardrobeService.LookChanged : Signal(player, equipped, outfitLevel, wearAvatar)   fired when either changes
-- The Player attribute "OutfitLevel" (1..5) mirrors GetOutfitLevel for UI on every client (profile cards).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Signal = require(Shared.Util.Signal)
local Character = require(script.Character)
local Deps = require(script.Deps)
local Inventory = require(script.Inventory)
local Look = require(script.Look)
local Prompts = require(script.Prompts)
local Remotes = require(script.Remotes)

type PlayerState = {
	conns: { RBXScriptConnection },
	char: Character.State?,
	passes: { [string]: boolean }?,
	passesAt: number,
	lastOpen: number,
	lookSig: string?,
}

local WardrobeService = { Name = "WardrobeService" }

WardrobeService.Inventory = Inventory
WardrobeService.Look = Look
WardrobeService.LookChanged = Signal.new() -- (player, equipped, outfitLevel, wearAvatar)
WardrobeService.OUTFIT_ATTR = "OutfitLevel"

local PASS_CACHE_SEC = 30
local LOAD_TIMEOUT = 60
local WORKSPACE_TIMEOUT = 15
local OPEN_COOLDOWN = 0.5

local states: { [Player]: PlayerState } = {}

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
-- The player's inventory, repaired in place (nil until the profile has loaded).
local function inventoryOf(player: Player): Inventory.Inv?
	local data = Deps.data(player)
	if not data then
		return nil
	end
	local inv = Inventory.normalize(data.inventory)
	data.inventory = inv
	return inv
end

local function replicate(player: Player)
	Deps.replicate(player, "inventory")
end

-- Pass ownership for the catalog's passes (cached briefly; MonetizationService may yield).
local function passesOf(player: Player, fresh: boolean?): { [string]: boolean }
	local ps = states[player]
	if ps and ps.passes and not fresh and os.clock() - ps.passesAt < PASS_CACHE_SEC then
		return ps.passes
	end
	local out: { [string]: boolean } = {}
	for passKey in Catalog.PASSES do
		out[passKey] = Deps.ownsPass(player, passKey)
	end
	if ps then
		ps.passes = out
		ps.passesAt = os.clock()
	end
	return out
end

local function viewerFor(player: Player, inv: Inventory.Inv, fresh: boolean?): Catalog.Viewer
	return Inventory.viewer(inv, Deps.rank(player), passesOf(player, fresh))
end

local function charState(player: Player): Character.State?
	local ps = states[player]
	local cs = ps and ps.char
	if cs and Character.alive(cs) then
		return cs
	end
	return nil
end

local function disconnectAll(list: { RBXScriptConnection })
	for _, c in list do
		c:Disconnect()
	end
	table.clear(list)
end

local function lookSignature(equipped: { [string]: string }, wearAvatar: boolean): string
	local list = {}
	for slot, id in equipped do
		table.insert(list, slot .. "=" .. id)
	end
	table.sort(list)
	return table.concat(list, ";") .. (if wearAvatar then "|avatar" else "|career")
end

-- Mirrors the worn look for other features: the OutfitLevel attribute and LookChanged (only when it changed).
local function publish(player: Player, inv: Inventory.Inv, equipped: { [string]: string })
	local ps = states[player]
	if not ps or player.Parent ~= Players then
		return
	end
	local level = Catalog.outfitLevel(equipped)
	if player:GetAttribute(WardrobeService.OUTFIT_ATTR) ~= level then
		player:SetAttribute(WardrobeService.OUTFIT_ATTR, level)
	end
	local sig = lookSignature(equipped, inv.wearAvatar)
	if ps.lookSig ~= sig then
		ps.lookSig = sig
		WardrobeService.LookChanged:Fire(player, table.clone(equipped), level, inv.wearAvatar)
	end
end

---------------------------------------------------------------------------------------------------
-- Dressing (Character.luau runs the body; this decides what it should wear)
---------------------------------------------------------------------------------------------------
-- What the data asks the character to wear right now (nil until the profile has loaded).
local function wantFor(player: Player): Character.Want?
	local inv = inventoryOf(player)
	if not inv then
		return nil
	end
	local equipped = Inventory.wearable(inv, viewerFor(player, inv))
	local logoId, monogram = Deps.companyLogo(player)
	return {
		wearAvatar = inv.wearAvatar,
		equipped = equipped,
		logo = if logoId then { id = logoId, monogram = monogram } else nil,
	}
end

function WardrobeService:ApplyLook(player: Player): boolean
	local cs = charState(player)
	if not cs then
		return false
	end
	return Character.apply(cs)
end

-- Re-dress after a data change and republish the outfit level (also between characters).
local function refresh(player: Player)
	local inv = inventoryOf(player)
	if not inv then
		return
	end
	publish(player, inv, (Inventory.wearable(inv, viewerFor(player, inv))))
	local cs = charState(player)
	if cs then
		Character.refresh(cs)
	end
end

local function onCharacter(player: Player, character: Model)
	local ps = states[player]
	if not ps then
		return
	end
	if ps.char then
		Character.drop(ps.char)
	end
	local cs = Character.new(player, character, wantFor)
	ps.char = cs
	if not Look.inWorkspace(character, WORKSPACE_TIMEOUT) or cs.dead then
		return
	end
	Deps.waitFor(player, LOAD_TIMEOUT)
	if not Character.alive(cs) or not Deps.data(player) then
		return
	end
	-- the first pass captures the avatar, standardizes the body and dresses it (or joins a pass already running)
	Character.apply(cs)
end

---------------------------------------------------------------------------------------------------
-- Inventory API
---------------------------------------------------------------------------------------------------
function WardrobeService:GetEquipped(player: Player): { [string]: string }
	local inv = inventoryOf(player)
	if not inv then
		return {}
	end
	return (Inventory.wearable(inv, viewerFor(player, inv)))
end

function WardrobeService:GetOutfitLevel(player: Player): (number, Catalog.OutfitParts)
	return Catalog.outfitLevel(WardrobeService:GetEquipped(player))
end

function WardrobeService:Owns(player: Player, itemId: string): boolean
	local item = Catalog.get(Catalog.canonical(itemId))
	local inv = inventoryOf(player)
	if not item or not inv then
		return false
	end
	return Catalog.access(item, viewerFor(player, inv)) == "owned"
end

function WardrobeService:RefreshAccess(player: Player)
	local ps = states[player]
	if ps then
		ps.passes = nil
	end
	refresh(player)
end

function WardrobeService:GetAccess(player: Player): { [string]: any }
	local ps = states[player]
	local fresh = ps ~= nil and os.clock() - ps.passesAt > 10
	local inv = inventoryOf(player)
	local logoId = Deps.companyLogo(player)
	local level = if inv then Catalog.outfitLevel((Inventory.wearable(inv, viewerFor(player, inv, fresh)))) else 1
	return {
		rank = Deps.rank(player),
		passes = passesOf(player, false),
		companyLogo = logoId,
		outfitLevel = level,
	}
end

function WardrobeService:OpenFor(player: Player, args: { [string]: any }?)
	if player.Parent == Players then
		Remotes.open(player, args)
	end
end

function WardrobeService:Equip(player: Player, slot: any, itemId: any): (boolean, string?)
	local inv = inventoryOf(player)
	if not inv then
		return false, "not_loaded"
	end
	local before = inv.equipped[slot]
	local ok, err = Inventory.equip(inv, slot, itemId, viewerFor(player, inv))
	if not ok then
		return false, err
	end
	if inv.equipped[slot] ~= before then
		replicate(player)
		refresh(player)
	end
	return true, nil
end

function WardrobeService:SavePreset(player: Player, index: number, name: string?): (boolean, string?)
	local inv = inventoryOf(player)
	if not inv then
		return false, "not_loaded"
	end
	local ok, err = Inventory.savePreset(inv, index, name, viewerFor(player, inv))
	if ok then
		replicate(player)
	end
	return ok, err
end

function WardrobeService:LoadPreset(player: Player, index: number): (boolean, string?, number)
	local inv = inventoryOf(player)
	if not inv then
		return false, "not_loaded", 0
	end
	local ok, err, dropped = Inventory.loadPreset(inv, index, viewerFor(player, inv))
	if ok then
		replicate(player)
		refresh(player)
	end
	return ok, err, if dropped then #dropped else 0
end

function WardrobeService:SetWearAvatar(player: Player, on: boolean): (boolean, string?)
	local inv = inventoryOf(player)
	if not inv then
		return false, "not_loaded"
	end
	if inv.wearAvatar ~= on then
		inv.wearAvatar = on
		replicate(player)
		refresh(player)
	end
	return true, nil
end

export type GrantOpts = { equip: boolean?, notify: boolean? }

function WardrobeService:Grant(player: Player, itemId: any, source: any, opts: GrantOpts?): boolean
	local inv = inventoryOf(player)
	if not inv then
		return false
	end
	local isNew, err = Inventory.grant(inv, itemId)
	if err then
		warn(("[WardrobeService] Grant(%s, %s) refused: %s"):format(player.Name, tostring(itemId), err))
		return false
	end
	local item = Catalog.get(Catalog.canonical(itemId)) :: Catalog.Item
	local o: GrantOpts = opts or {}
	if isNew then
		Deps.audit(player, "wardrobe_grant", { item = item.id, source = tostring(source or "unknown") })
	end
	local changed = isNew
	if o.equip then
		local before = inv.equipped[item.slot]
		local ok = Inventory.equip(inv, item.slot, item.id, viewerFor(player, inv))
		if ok and before ~= item.id then
			changed = true
		end
	end
	if changed then
		replicate(player)
		refresh(player)
	end
	if isNew and o.notify then
		Deps.notify(player, Catalog.text("granted", { name = item.name }), "good")
	end
	return true
end

-- Grants a Life Roll look (Catalog.looks id) or a list of item ids, and by default puts it on.
function WardrobeService:GrantLook(player: Player, look: any, source: any, opts: GrantOpts?): boolean
	local itemIds: { string } = {}
	local name: string? = nil
	if type(look) == "string" then
		local entry = Catalog.looks[Catalog.canonical(look)]
		if not entry then
			warn("[WardrobeService] GrantLook: unknown look " .. look)
			return false
		end
		itemIds = entry.itemIds
		name = entry.name
	elseif type(look) == "table" then
		for _, id in look do
			if type(id) == "string" then
				table.insert(itemIds, id)
			end
		end
	end
	local inv = inventoryOf(player)
	if not inv or #itemIds == 0 then
		return false
	end
	local o: GrantOpts = opts or {}
	local anyNew = false
	for _, id in itemIds do
		local isNew, err = Inventory.grant(inv, id)
		if err then
			warn("[WardrobeService] GrantLook: skipping " .. tostring(id) .. " (" .. err .. ")")
		elseif isNew then
			anyNew = true
			Deps.audit(
				player,
				"wardrobe_grant",
				{ item = Catalog.canonical(id), source = tostring(source or "unknown") }
			)
		end
	end
	local changed = anyNew
	if o.equip ~= false then
		changed = #Inventory.wearLook(inv, itemIds, viewerFor(player, inv)) > 0 or changed
	end
	if changed then
		replicate(player)
		refresh(player)
	end
	if anyNew and o.notify then
		local first = Catalog.get(Catalog.canonical(itemIds[1]))
		Deps.notify(
			player,
			if name
				then Catalog.text("granted_look", { look = name })
				else Catalog.text("granted", { name = if first then first.name else "" }),
			"good"
		)
	end
	return true
end

-- Starter outfits for every stage the player's rank has reached.
local function grantStarters(player: Player, announce: boolean)
	local inv = inventoryOf(player)
	if not inv then
		return
	end
	local rank = Deps.rank(player)
	local newItems, newStages, equippedStarter = Inventory.grantStarters(inv, rank)
	if #newItems > 0 or #newStages > 0 or equippedStarter then
		replicate(player)
		for _, id in newItems do
			Deps.audit(player, "wardrobe_grant", { item = id, source = "starter" })
		end
		refresh(player)
	end
	if announce and #newItems > 0 then
		local stageId = newStages[#newStages]
		local title = Catalog.rankTitle(rank)
		for _, stage in Catalog.STAGES do
			if stage.id == stageId then
				title = Catalog.rankTitle(stage.rank)
			end
		end
		Deps.notify(player, Catalog.text("stage_granted", { stage = title }), "good")
	end
end

-- The Life Roll outfit and family heirloom the profile earned (careerCore may also grant them through GrantLook:
-- both paths are idempotent). wear = true puts the rolled look on (a freshly locked-in life).
local function reconcileProfile(player: Player, wear: boolean)
	local data = Deps.data(player)
	local inv = inventoryOf(player)
	if not data or not inv then
		return
	end
	local granted = Inventory.reconcile(inv, data.profile)
	for _, id in granted do
		Deps.audit(player, "wardrobe_grant", { item = id, source = "life_roll" })
	end
	local changed = #granted > 0
	local _, lookId = Inventory.profilePieces(data.profile)
	local look = if lookId then Catalog.looks[lookId] else nil
	if wear and look then
		changed = #Inventory.wearLook(inv, look.itemIds, viewerFor(player, inv)) > 0 or changed
	end
	if changed then
		replicate(player)
		refresh(player)
	end
	if #granted > 0 and wear then
		Deps.notify(
			player,
			if look then Catalog.text("granted_look", { look = look.name }) else Catalog.text("starter_granted"),
			"good"
		)
	end
end

local function onProfileLoaded(player: Player)
	grantStarters(player, false)
	reconcileProfile(player, false)
	local inv = inventoryOf(player)
	if inv then
		publish(player, inv, (Inventory.wearable(inv, viewerFor(player, inv))))
	end
end

---------------------------------------------------------------------------------------------------
-- Interact prompts
---------------------------------------------------------------------------------------------------
local function onPromptTriggered(player: Player, _prompt: ProximityPrompt, companyId: string?)
	local ps = states[player]
	if not ps then
		return
	end
	local now = os.clock()
	if now - ps.lastOpen < OPEN_COOLDOWN then
		return
	end
	ps.lastOpen = now
	if companyId and not Deps.isEmployeeOf(player, companyId) then
		Deps.notify(player, Catalog.text("employees_only"), "warn")
		return
	end
	Remotes.open(player, { source = "prompt" })
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
local function onPlayer(player: Player)
	if states[player] then
		return
	end
	local ps: PlayerState = { conns = {}, char = nil, passes = nil, passesAt = 0, lastOpen = 0, lookSig = nil }
	states[player] = ps
	table.insert(
		ps.conns,
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	)
	local existing = player.Character
	if existing then
		task.spawn(onCharacter, player, existing)
	end
end

local function onPlayerRemoving(player: Player)
	local ps = states[player]
	if not ps then
		return
	end
	states[player] = nil
	disconnectAll(ps.conns)
	if ps.char then
		Character.drop(ps.char)
	end
	ps.char = nil
end

function WardrobeService:Init()
	Remotes.bind(WardrobeService)
	Deps.connect("DataService", "ProfileLoaded", function(player: Player)
		if states[player] == nil and player.Parent == Players then
			onPlayer(player)
		end
		onProfileLoaded(player)
	end)
end

function WardrobeService:Start()
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
		if Deps.isLoaded(player) then
			task.spawn(onProfileLoaded, player)
		end
	end

	-- a rank change can unlock (or lock) equipped pieces; a new company changes the vest / quarter-zip logo
	Deps.connect("CareerService", "RoleChanged", function(player: Player)
		if states[player] then
			grantStarters(player, true)
			refresh(player)
		end
	end)
	-- a newly locked-in life (first time and after every rebirth) comes with its rolled outfit
	Deps.connect("ProfileService", "ProfileLocked", function(player: Player)
		if states[player] then
			reconcileProfile(player, true)
		end
	end)

	Prompts.start(onPromptTriggered)
end

return WardrobeService
