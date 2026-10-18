--!strict
-- CareerCoreController (client, owned by `careerCore`): the Life Roll and Stats screens' link to ProfileService.
--   * On a first join (profile.built = false) it opens the LifeRoll screen as soon as the player's data arrives;
--     the campus "profile_builder" interact reopens it (server -> "Profile.Open").
--   * Registers the "Stats" menu tab (quick button; badge "!" until the Life Roll is locked in).
--   * Hides EmployeesOnly "profile_builder" prompts for visitors inside office instances (the server refuses them
--     either way), streaming-safe through the replicated "Interact" tag.
--
-- API (used by UI/Screens/LifeRoll, UI/Screens/Stats and other features' screens):
--   :GetProfile() -> profile?                       replicated profile (Store "profile"); read-only
--   :PublicView(profile?) -> PublicProfile          own profile in the StatCard / profile-card shape
--   :GetPublic(player) -> PublicProfile?            any player in the server (yields; cached 10 s). For
--                                                   UI/Screens/LifeRollParts/StatCard.mount(container, view)
--   :SetName(name) / :Reroll(field) / :Lock() / :SetFocus(focusId) / :Rebuild(edits) / :FetchState()
--       -> (ok, errKey?, payload?)                  errKey = Config/LifeRoll err_<key>; see ProfileService/Remotes
--   :BuyReroll()                                    opens the Store on the Profile Reroll product (guarded)
--   :OpenLifeRoll(args?) / :OpenStats(args?)
--   .ProfileChanged : Signal(profile)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Config = require(Shared.Config.LifeRoll)
local LifeRoll = require(Shared.Logic.LifeRoll)
local Registry = require(script.Parent.Parent.Registry)

local CareerCoreController = { Name = "CareerCoreController" }

CareerCoreController.ProfileChanged = Signal.new()

local INTERACT_ID = "profile_builder"
local PROMPT_NAME = "LifeRollPrompt"
local LIFEROLL = "LifeRoll"
local STATS = "Stats"
local TAB_ID = "stats"
local PUBLIC_TTL = 10
local AUTO_OPEN_DELAY = 0.75

local publicCache: { [number]: { at: number, view: any } } = {}
local autoOpened = false

local function store(): any
	return Registry.get("Store")
end

local function uiController(): any
	return Registry.get("UIController")
end

local function storeGet(key: string): any
	local s = store()
	if not s then
		return nil
	end
	local ok, v = pcall(function()
		return s:Get(key)
	end)
	return if ok then v else nil
end

local function notify(text: string, kind: string?)
	local ui = uiController()
	if ui and type(ui.Notify) == "function" then
		ui:Notify(text, kind)
	end
end

-- RemoteFunction results arrive as (ok, err, payload) or (nil, "timeout" | "error" | "rate_limited" | "missing").
local function call(name: string, ...: any): (boolean, string?, any)
	local ok, a, b, c = pcall(Net.invoke, name, ...)
	if not ok then
		return false, "generic", nil
	end
	if a == true then
		return true, nil, c
	end
	if a == nil and type(b) == "string" then
		if b == "timeout" or b == "rate_limited" then
			return false, b, nil
		end
		return false, "generic", nil
	end
	return false, if type(b) == "string" then b else "generic", c
end

---------------------------------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------------------------------
function CareerCoreController:GetProfile(): any
	local p = storeGet("profile")
	return if type(p) == "table" then p else nil
end

function CareerCoreController:PublicView(profile: any?): LifeRoll.PublicProfile
	local me = Players.LocalPlayer
	return LifeRoll.publicView(
		profile or self:GetProfile(),
		{ userId = me and me.UserId, displayName = me and me.DisplayName }
	)
end

function CareerCoreController:GetPublic(player: Player): LifeRoll.PublicProfile?
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return nil
	end
	if player == Players.LocalPlayer then
		return self:PublicView()
	end
	local hit = publicCache[player.UserId]
	if hit and os.clock() - hit.at < PUBLIC_TTL then
		return hit.view
	end
	local ok, _err, view = call("Profile.GetPublic", player)
	if ok and type(view) == "table" then
		publicCache[player.UserId] = { at = os.clock(), view = view }
		return view
	end
	return if hit then hit.view else nil
end

function CareerCoreController:SetName(name: string): (boolean, string?, any)
	return call("Profile.SetName", name)
end

function CareerCoreController:Reroll(field: string): (boolean, string?, any)
	return call("Profile.RerollField", field)
end

function CareerCoreController:Lock(): (boolean, string?, any)
	return call("Profile.Lock")
end

function CareerCoreController:SetFocus(focusId: string): (boolean, string?, any)
	return call("Profile.SetFocus", focusId)
end

function CareerCoreController:Rebuild(edits: { [string]: any }): (boolean, string?, any)
	return call("Profile.Rebuild", edits)
end

function CareerCoreController:FetchState(): (boolean, string?, any)
	return call("Profile.Get")
end

function CareerCoreController:BuyReroll()
	local ui = uiController()
	local opened = false
	if ui and type(ui.Open) == "function" then
		local ok, result = pcall(function()
			return ui:Open("Store", { product = "ProfileReroll", from = LIFEROLL })
		end)
		opened = ok and result == true
	end
	if not opened then
		notify(Config.text("store_closed"), "info")
	end
end

function CareerCoreController:OpenLifeRoll(args: any?)
	local ui = uiController()
	if ui and type(ui.Open) == "function" then
		ui:Open(LIFEROLL, if type(args) == "table" then args else { source = "menu" })
	end
end

function CareerCoreController:OpenStats(args: any?)
	local ui = uiController()
	if ui and type(ui.Open) == "function" then
		ui:Open(STATS, if type(args) == "table" then args else { from = "LifeRoll" })
	end
end

---------------------------------------------------------------------------------------------------
-- EmployeesOnly prompts (hidden locally for visitors; the server refuses them either way)
---------------------------------------------------------------------------------------------------
local function canUse(companyId: any): boolean
	if type(companyId) ~= "string" or companyId == "" then
		return true
	end
	local career = storeGet("career")
	local mine = if type(career) == "table" then career.companyId else nil
	if type(mine) ~= "string" or mine == "" then
		return false
	end
	if mine == companyId then
		return true
	end
	-- Merger Mania pairs two companies (global `events`): both may use each other's office
	local s = store()
	local events = nil
	if s then
		local ok, v = pcall(function()
			return s:GetGlobal("events")
		end)
		events = if ok then v else nil
	end
	local corporate = if type(events) == "table" then events.corporate else nil
	if type(corporate) == "table" and corporate.id == "merger_mania" and type(corporate.data) == "table" then
		local found = { mine = false, theirs = false }
		local function scan(v: any, depth: number)
			if v == mine then
				found.mine = true
			elseif v == companyId then
				found.theirs = true
			elseif type(v) == "table" and depth < 3 then
				for _, x in v do
					scan(x, depth + 1)
				end
			end
		end
		scan(corporate.data, 0)
		return found.mine and found.theirs
	end
	return false
end

local prompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Instance]: RBXScriptConnection } = {}

local function evaluate(prompt: ProximityPrompt)
	if prompt:GetAttribute("EmployeesOnly") ~= true then
		return
	end
	local allowed = canUse(prompt:GetAttribute("CompanyId"))
	if prompt.Enabled ~= allowed then
		prompt.Enabled = allowed
	end
end

local function evaluateAll()
	for prompt in prompts do
		if prompt.Parent then
			evaluate(prompt)
		end
	end
end

local function track(inst: Instance)
	if not inst:IsA("ProximityPrompt") or prompts[inst] then
		return
	end
	if inst.Name ~= PROMPT_NAME and inst:GetAttribute("InteractId") ~= INTERACT_ID then
		return
	end
	prompts[inst] = true
	inst:GetAttributeChangedSignal("EmployeesOnly"):Connect(function()
		evaluate(inst)
	end)
	inst:GetAttributeChangedSignal("CompanyId"):Connect(function()
		evaluate(inst)
	end)
	evaluate(inst)
end

local function watch(inst: Instance)
	if inst:GetAttribute("InteractId") ~= INTERACT_ID or watched[inst] then
		return
	end
	watched[inst] = inst.DescendantAdded:Connect(track)
	for _, d in inst:GetDescendants() do
		track(d)
	end
end

local function unwatch(inst: Instance)
	local conn = watched[inst]
	if conn then
		watched[inst] = nil
		conn:Disconnect()
	end
end

local function startPromptWatch()
	CollectionService:GetInstanceAddedSignal("Interact"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("Interact"):Connect(unwatch)
	for _, inst in CollectionService:GetTagged("Interact") do
		watch(inst)
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
local function updateBadge(profile: any)
	local ui = uiController()
	if ui and type(ui.SetMenuBadge) == "function" then
		local built = type(profile) == "table" and profile.built == true
		ui:SetMenuBadge(TAB_ID, if built then nil else "!")
	end
end

local function maybeAutoOpen()
	if autoOpened then
		return
	end
	local p = CareerCoreController:GetProfile()
	if type(p) ~= "table" or p.built == true then
		return
	end
	autoOpened = true
	task.delay(AUTO_OPEN_DELAY, function()
		local fresh = CareerCoreController:GetProfile()
		if type(fresh) == "table" and fresh.built ~= true then
			CareerCoreController:OpenLifeRoll({ source = "first_join" })
		end
	end)
end

function CareerCoreController:Init() end

function CareerCoreController:Start()
	local ui = uiController()
	if ui and type(ui.RegisterMenuTab) == "function" then
		ui:RegisterMenuTab({
			id = TAB_ID,
			title = Config.text("menu_stats"),
			glyph = "📊",
			order = 15,
			screen = STATS,
			quick = true,
		})
	end

	Net.listen("Profile.Open", function(args: any)
		local source = if type(args) == "table" and type(args.source) == "string" then args.source else "server"
		CareerCoreController:OpenLifeRoll({ source = source })
	end)

	local s = store()
	if s then
		pcall(function()
			s:Changed("profile"):Connect(function(profile: any)
				updateBadge(profile)
				CareerCoreController.ProfileChanged:Fire(profile)
				maybeAutoOpen()
			end)
			s:Changed("career"):Connect(evaluateAll)
			s:GlobalChanged("events"):Connect(evaluateAll)
			s.Loaded:Connect(function()
				evaluateAll()
				updateBadge(CareerCoreController:GetProfile())
				maybeAutoOpen()
			end)
		end)
		local loaded = false
		pcall(function()
			loaded = s:IsLoaded()
		end)
		if loaded then
			updateBadge(CareerCoreController:GetProfile())
			maybeAutoOpen()
		end
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		publicCache[player.UserId] = nil
	end)
	startPromptWatch()
end

return CareerCoreController
