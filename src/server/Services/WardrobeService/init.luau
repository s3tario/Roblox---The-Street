--!strict
-- WardrobeService (server, owned by `wardrobe`; docs/contracts.md §9): the player's Career Look.
--
-- On every character (spawn, respawn) it waits for the avatar and the profile to load, remembers the avatar's
-- own HumanoidDescription, then (unless inventory.wearAvatar is on) standardizes the body and dresses it in
-- inventory.equipped with fitted 3D layers (Look.luau). If something rebuilds the body parts later, the layers
-- are rebuilt on the new parts.
--
-- Remotes (RemoteFunctions; every argument validated with Guard):
--   "Wardrobe.Equip"(slot, itemId | nil) -> ok, errKey?
--   "Wardrobe.SavePreset"(index 1-5, name?) -> ok, errKey?
--   "Wardrobe.LoadPreset"(index 1-5) -> ok, errKey?, droppedCount?
--   "Wardrobe.SetWearAvatar"(on: boolean) -> ok
--   "Wardrobe.GetAccess"() -> { rank, passes = { [passKey] = boolean } }
-- errKeys are Catalog.strings suffixes ("err_<key>").
--
-- API:
--   WardrobeService:ApplyLook(player) -> boolean            re-dress (yields while the body is standardized)
--   WardrobeService:Equip(player, slot, itemId?) -> ok, err
--   WardrobeService:Grant(player, itemId, source, opts?) -> boolean   true when the player owns it afterwards
--       opts = { equip: boolean?, notify: boolean? }  (shop, monetization, season, events)
--   WardrobeService:GrantLook(player, lookIdOrItemIds, source, opts?) -> boolean   Life Roll (equips by default)
--   WardrobeService:Owns(player, itemId) -> boolean         (yields for pass items)
--   WardrobeService:GetEquipped(player) -> { [slot] = itemId }   what the Career Look is wearing
--   WardrobeService:RefreshAccess(player)                   forget cached pass ownership (after a pass purchase)
-- Interact: every "Interact" part with InteractId "wardrobe" gets a ProximityPrompt (attribute InteractId =
-- "wardrobe"); the client opens the Wardrobe screen when it triggers (WardrobeController).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Guard = require(Shared.Guard)
local Catalog = require(Shared.Config.Catalog)
local Wardrobe = require(Shared.Assets.Wardrobe)
local Fit = require(Shared.Assets.Wardrobe.Fit)
local Registry = require(script.Parent.Parent.Registry)
local Inventory = require(script.Inventory)
local Look = require(script.Look)

type Mode = "native" | "career" | "avatar"
type CharState = {
	character: Model,
	original: HumanoidDescription?,
	mode: Mode,
	busy: boolean,
	dirty: boolean,
	parts: { [string]: BasePart },
	conns: { RBXScriptConnection },
	repairQueued: boolean,
	dead: boolean,
}
type PlayerState = {
	conns: { RBXScriptConnection },
	char: CharState?,
	passes: { [string]: boolean }?,
	passesAt: number,
}

local WardrobeService = { Name = "WardrobeService" }

WardrobeService.Inventory = Inventory
WardrobeService.Look = Look

local PASS_CACHE_SEC = 30
local LOAD_TIMEOUT = 60
local WORKSPACE_TIMEOUT = 15
local INTERACT_ID = "wardrobe"
local PROMPT_NAME = "WardrobePrompt"

local states: { [Player]: PlayerState } = {}

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
local function dataService(): any
	return Registry.get("DataService")
end

local function getData(player: Player): any
	local ds = dataService()
	if not ds then
		return nil
	end
	local ok, data = pcall(function()
		return ds:Get(player)
	end)
	return if ok and type(data) == "table" then data else nil
end

-- The player's inventory, repaired in place (nil until the profile has loaded).
local function inventoryOf(player: Player): Inventory.Inv?
	local data = getData(player)
	if not data then
		return nil
	end
	local inv = Inventory.normalize(data.inventory)
	data.inventory = inv
	return inv
end

local function replicate(player: Player)
	local ds = dataService()
	if ds then
		pcall(function()
			ds:Replicate(player, "inventory")
		end)
	end
end

local function audit(player: Player, kind: string, details: { [string]: any })
	local ds = dataService()
	if ds and type(ds.Audit) == "function" then
		pcall(function()
			ds:Audit(player, kind, details)
		end)
	end
end

local function notify(player: Player, text: string, kind: string?)
	local ns = Registry.get("NotifyService")
	if ns then
		pcall(function()
			ns:Notify(player, text, kind)
		end)
	end
end

local function rankOf(player: Player): number
	local cs = Registry.get("CareerService")
	if cs and type(cs.GetRank) == "function" then
		local ok, r = pcall(function()
			return cs:GetRank(player)
		end)
		if ok and type(r) == "number" and r == r then
			return r
		end
	end
	local data = getData(player)
	local career = data and data.career
	local r = if type(career) == "table" then tonumber(career.rank) else nil
	return r or 0
end

-- Pass ownership for the catalog's passes (MonetizationService, falling back to saved entitlements).
local function passesOf(player: Player, fresh: boolean?): { [string]: boolean }
	local ps = states[player]
	local now = os.clock()
	if ps and ps.passes and not fresh and now - ps.passesAt < PASS_CACHE_SEC then
		return ps.passes
	end
	local out: { [string]: boolean } = {}
	local ms = Registry.get("MonetizationService")
	local data = getData(player)
	local saved = if data and type(data.entitlements) == "table" then data.entitlements.passes else nil
	for passKey in Catalog.PASSES do
		local owns = false
		if ms and type(ms.OwnsPass) == "function" then
			local ok, r = pcall(function()
				return ms:OwnsPass(player, passKey)
			end)
			owns = ok and r == true
		end
		if not owns and type(saved) == "table" then
			owns = saved[passKey] == true or table.find(saved, passKey) ~= nil
		end
		out[passKey] = owns
	end
	if ps then
		ps.passes = out
		ps.passesAt = os.clock()
	end
	return out
end

local function viewerFor(player: Player, inv: Inventory.Inv, fresh: boolean?): Catalog.Viewer
	return Inventory.viewer(inv, rankOf(player), passesOf(player, fresh))
end

local function charState(player: Player): CharState?
	local ps = states[player]
	local cs = ps and ps.char
	if cs and not cs.dead and Look.current(player, cs.character) then
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

local function dropCharState(cs: CharState?)
	if not cs then
		return
	end
	cs.dead = true
	disconnectAll(cs.conns)
	local original = cs.original
	cs.original = nil
	if original then
		original:Destroy()
	end
end

---------------------------------------------------------------------------------------------------
-- Dressing
---------------------------------------------------------------------------------------------------
-- Puts the current equipped look on (synchronous). Only acts on a standardized character.
local function dress(player: Player, cs: CharState)
	if cs.mode ~= "career" or cs.dead then
		return
	end
	local inv = inventoryOf(player)
	if not inv then
		return
	end
	local equipped = Inventory.wearable(inv, viewerFor(player, inv))
	if not Look.current(player, cs.character) then
		return
	end
	Look.dress(cs.character, equipped, Look.skinOf(cs.original))
	cs.parts = Wardrobe.bodyParts(cs.character)
end

-- One pass of ApplyLook: brings the character to the mode the data asks for, then dresses it. May yield.
local function step(player: Player, cs: CharState)
	local inv = inventoryOf(player)
	if not inv then
		return
	end
	if not cs.original and cs.mode == "native" then
		-- the profile loaded after this character spawned: remember the avatar before changing it
		cs.original = Look.capture(player, cs.character, 10)
		if cs.dead or not Look.current(player, cs.character) then
			return
		end
	end
	if inv.wearAvatar then
		if cs.mode == "career" then
			if not cs.original then
				cs.original = Look.fetch(player)
				if cs.dead or not Look.current(player, cs.character) then
					return
				end
			end
			Look.restore(cs.character, cs.original)
		end
		cs.mode = "avatar"
		return
	end
	if cs.mode ~= "career" then
		local ok = Look.standardize(cs.character, cs.original)
		if not Look.current(player, cs.character) then
			return
		end
		if not ok then
			-- not an R15 rig (or ApplyDescription is unavailable): still dress what we can
			warn("[WardrobeService] couldn't standardize " .. player.Name .. "'s body; dressing as is")
		end
		cs.mode = "career"
	end
	dress(player, cs)
end

function WardrobeService:ApplyLook(player: Player): boolean
	local cs = charState(player)
	if not cs then
		return false
	end
	if cs.busy then
		cs.dirty = true -- the running pass picks the latest data up
		return true
	end
	cs.busy = true
	local ok, err = pcall(function()
		local passes = 0
		repeat
			cs.dirty = false
			step(player, cs)
			passes += 1
		until not cs.dirty or cs.dead or not Look.current(player, cs.character) or passes >= 5
	end)
	cs.busy = false
	if not ok then
		warn("[WardrobeService] ApplyLook failed for " .. player.Name .. ": " .. tostring(err))
		return false
	end
	return true
end

-- Re-dress after a data change: immediate when the body is ready, otherwise via ApplyLook.
local function refresh(player: Player)
	local cs = charState(player)
	if not cs then
		return
	end
	if cs.busy then
		cs.dirty = true
		return
	end
	local inv = inventoryOf(player)
	if not inv then
		return
	end
	local want: Mode = if inv.wearAvatar then "avatar" else "career"
	if cs.mode == "career" and want == "career" then
		local ok, err = pcall(function()
			dress(player, cs)
		end)
		if not ok then
			warn("[WardrobeService] dress failed for " .. player.Name .. ": " .. tostring(err))
		end
	else
		task.spawn(function()
			WardrobeService:ApplyLook(player)
		end)
	end
end

-- Something replaced a body part (a script applying a description, a scale change): rebuild the layers on the
-- new parts. Our own standardize marks the state busy, and the snapshot taken after dressing filters out the
-- (deferred) ChildAdded events it caused.
local function onBodyPartAdded(player: Player, cs: CharState, child: Instance)
	if cs.dead or cs.mode ~= "career" or not child:IsA("BasePart") or not Fit.BODY_SET[child.Name] then
		return
	end
	if cs.parts[child.Name] == child or cs.repairQueued then
		return
	end
	cs.repairQueued = true
	task.delay(0.3, function()
		cs.repairQueued = false
		if cs.dead or not Look.current(player, cs.character) then
			return
		end
		local parts = Wardrobe.bodyParts(cs.character)
		local changed = false
		for name, p in parts do
			if cs.parts[name] ~= p then
				changed = true
			end
		end
		if changed then
			refresh(player)
		end
	end)
end

local function onCharacter(player: Player, character: Model)
	local ps = states[player]
	if not ps then
		return
	end
	dropCharState(ps.char)
	local cs: CharState = {
		character = character,
		original = nil,
		mode = "native",
		busy = false,
		dirty = false,
		parts = {},
		conns = {},
		repairQueued = false,
		dead = false,
	}
	ps.char = cs
	table.insert(
		cs.conns,
		character.ChildAdded:Connect(function(child)
			onBodyPartAdded(player, cs, child)
		end)
	)
	table.insert(
		cs.conns,
		character.Destroying:Connect(function()
			if ps.char == cs then
				ps.char = nil
			end
			dropCharState(cs)
		end)
	)

	if not Look.inWorkspace(character, WORKSPACE_TIMEOUT) or cs.dead then
		return
	end
	local ds = dataService()
	if ds then
		pcall(function()
			ds:WaitFor(player, LOAD_TIMEOUT)
		end)
	end
	if cs.dead or not Look.current(player, character) or not getData(player) then
		return
	end
	local original = Look.capture(player, character, 10)
	if cs.dead or not Look.current(player, character) then
		if original then
			original:Destroy()
		end
		return
	end
	cs.original = original
	WardrobeService:ApplyLook(player)
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

function WardrobeService:Owns(player: Player, itemId: string): boolean
	local item = Catalog.get(itemId)
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
	local item = Catalog.get(itemId) :: Catalog.Item
	local o: GrantOpts = opts or {}
	if isNew then
		audit(player, "wardrobe_grant", { item = item.id, source = tostring(source or "unknown") })
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
		notify(player, Catalog.text("granted", { name = item.name }), "good")
	end
	return true
end

-- Grants a Life Roll look (Catalog.looks id) or a list of item ids, and by default puts it on.
function WardrobeService:GrantLook(player: Player, look: any, source: any, opts: GrantOpts?): boolean
	local itemIds: { string } = {}
	local name: string? = nil
	if type(look) == "string" then
		local entry = Catalog.looks[look]
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
			audit(player, "wardrobe_grant", { item = id, source = tostring(source or "unknown") })
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
		local first = Catalog.get(itemIds[1])
		notify(
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
	local newItems, newStages, equippedStarter = Inventory.grantStarters(inv, rankOf(player))
	if #newItems > 0 or #newStages > 0 or equippedStarter then
		replicate(player)
		for _, id in newItems do
			audit(player, "wardrobe_grant", { item = id, source = "starter" })
		end
		refresh(player)
	end
	if announce and #newItems > 0 then
		local stageId = newStages[#newStages]
		local title = Catalog.rankTitle(rankOf(player))
		for _, stage in Catalog.STAGES do
			if stage.id == stageId then
				title = Catalog.rankTitle(stage.rank)
			end
		end
		notify(player, Catalog.text("stage_granted", { stage = title }), "good")
	end
end

---------------------------------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------------------------------
local function slotArg(x: any): string?
	local id = Guard.id(x)
	if id and Catalog.SLOT_SET[id] then
		return id
	end
	return nil
end

local function bindRemotes()
	local Net = require(Shared.Net)
	Net.handle("Wardrobe.Equip", function(player: Player, slot: any, itemId: any)
		local s = slotArg(slot)
		if not s then
			return false, "bad_slot"
		end
		local id: string? = nil
		if itemId ~= nil then
			id = Guard.id(itemId)
			if not id then
				return false, "unknown_item"
			end
		end
		return WardrobeService:Equip(player, s, id)
	end, { rate = 6, burst = 14 })

	Net.handle("Wardrobe.SavePreset", function(player: Player, index: any, name: any)
		local i = Guard.int(index, 1, Catalog.PRESET_SLOTS.max)
		if not i then
			return false, "locked"
		end
		local n: string? = nil
		if name ~= nil then
			n = Guard.str(name, 200)
			if not n then
				return false, "bad_name"
			end
		end
		local inv = inventoryOf(player)
		if not inv then
			return false, "not_loaded"
		end
		local ok, err = Inventory.savePreset(inv, i, n, viewerFor(player, inv))
		if ok then
			replicate(player)
		end
		return ok, err
	end, { rate = 2, burst = 4 })

	Net.handle("Wardrobe.LoadPreset", function(player: Player, index: any)
		local i = Guard.int(index, 1, Catalog.PRESET_SLOTS.max)
		if not i then
			return false, "locked"
		end
		local inv = inventoryOf(player)
		if not inv then
			return false, "not_loaded"
		end
		local ok, err, dropped = Inventory.loadPreset(inv, i, viewerFor(player, inv))
		if ok then
			replicate(player)
			refresh(player)
		end
		return ok, err, if dropped then #dropped else 0
	end, { rate = 2, burst = 4 })

	Net.handle("Wardrobe.SetWearAvatar", function(player: Player, on: any)
		local b = Guard.bool(on)
		if b == nil then
			return false, "generic"
		end
		local inv = inventoryOf(player)
		if not inv then
			return false, "not_loaded"
		end
		if inv.wearAvatar ~= b then
			inv.wearAvatar = b
			replicate(player)
			task.spawn(function()
				WardrobeService:ApplyLook(player)
			end)
		end
		return true, nil
	end, { rate = 1, burst = 3 })

	Net.handle("Wardrobe.GetAccess", function(player: Player)
		local ps = states[player]
		local fresh = ps ~= nil and os.clock() - ps.passesAt > 10
		return { rank = rankOf(player), passes = passesOf(player, fresh) }
	end, { rate = 1, burst = 3 })
end

---------------------------------------------------------------------------------------------------
-- Interact prompts
---------------------------------------------------------------------------------------------------
local function promptParent(inst: Instance): Instance?
	if inst:IsA("BasePart") or inst:IsA("Attachment") then
		return inst
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function wirePrompt(inst: Instance)
	if inst:GetAttribute("InteractId") ~= INTERACT_ID then
		return
	end
	local parent = promptParent(inst)
	if not parent or parent:FindFirstChild(PROMPT_NAME) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = Catalog.text("prompt")
	prompt.ObjectText = Catalog.text("title")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("InteractId", INTERACT_ID)
	prompt.Parent = parent
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
local function onPlayer(player: Player)
	if states[player] then
		return
	end
	local ps: PlayerState = { conns = {}, char = nil, passes = nil, passesAt = 0 }
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
	dropCharState(ps.char)
	ps.char = nil
end

function WardrobeService:Init()
	bindRemotes()
	local ds = dataService()
	if ds and ds.ProfileLoaded then
		ds.ProfileLoaded:Connect(function(player: Player)
			grantStarters(player, false)
		end)
	end
end

function WardrobeService:Start()
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
		local ds = dataService()
		if ds and ds:IsLoaded(player) then
			task.spawn(grantStarters, player, false)
		end
	end

	local career = Registry.get("CareerService")
	if career and type(career.RoleChanged) == "table" then
		career.RoleChanged:Connect(function(player: Player)
			grantStarters(player, true)
			refresh(player) -- a rank change can unlock (or lock) equipped pieces
		end)
	end

	CollectionService:GetInstanceAddedSignal("Interact"):Connect(wirePrompt)
	for _, inst in CollectionService:GetTagged("Interact") do
		wirePrompt(inst)
	end
end

return WardrobeService
