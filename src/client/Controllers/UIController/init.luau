--!strict
-- UIController (client, Priority 5): owns the one ScreenGui "TheStreetUI" and its layers
--   hud      HUD (HudController)
--   screens  one full screen at a time (UI/Screens/<Id>.luau, auto-discovered)
--   modal    modal stack (Kit.Confirm, Kit.Dropdown pickers, Kit.modal)
--   toast    toasts and banners (always on top)
-- plus Back handling (Escape, gamepad B, close buttons), the phone menu tabs, the theme (campus for
-- students, street once employed), player settings and the root UIScale.
--
-- API (contracts §12):
--   :Open(screenId, args?) -> boolean    args.hideHud hides the HUD while open
--   :Close(screenId?) -> boolean         nil closes whatever is open
--   :Toggle(screenId, args?)  :IsOpen(screenId?) -> boolean  :Current() -> string?
--   :Back() -> boolean                   top modal first, then the screen (returns to the screen it replaced)
--   :RegisterMenuTab({id, title, glyph, order, screen, quick?, onClick?, badge?, locked?})
--   :GetMenuTabs() -> {tab}  :ActivateTab(id)  :SetMenuBadge(id, text?)  :SetMenuLocked(id, bool)
--   :Confirm(opts, callback)             Kit.Confirm on the modal layer
--   :PushModal(close) -> release()       custom modals that Back should close
--   :GetLayer("hud" | "screens" | "modal" | "toast") -> Frame   :GetScreenGui() -> ScreenGui
--   :GetSettings()  :SetSetting(key, value, localOnly?)  :ResetSettings()
--   :Notify(text, kind?)                 local toast (HudController:Flash)
-- Signals: ScreenChanged(id?, hideHud), MenuTabsChanged(), SettingsChanged(settings), ThemeChanged(name)
--
-- Screens return { id = "Terminal", hideHud = false?, open = function(args, root, ctx) return {close = fn} end }.
-- `root` is a full-screen Frame created for that screen inside the screens layer (destroyed on close).
-- ctx = {Registry, Net, Theme, Kit, Store, Strings, Sfx, UI = UIController, id, close = fn, screenGui}.

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Strings = require(Shared.Config.Strings)
local SettingsDefaults = require(Shared.Config.DataTemplate.Settings)
local Registry = require(script.Parent.Parent.Registry)
local ScreenStack = require(script.ScreenStack)
local UIFolder = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UIFolder:WaitForChild("Theme"))
local Kit = require(UIFolder:WaitForChild("Kit"))
local Sfx = require(UIFolder:WaitForChild("Sfx"))

export type MenuTab = {
	id: string,
	title: string,
	glyph: string?,
	order: number?,
	screen: string?, -- screen id to open (default: id)
	quick: boolean?, -- also show as a HUD quick button
	onClick: (() -> ())?, -- custom action instead of opening a screen
	badge: string?,
	locked: boolean?,
}

local UIController = {
	Name = "UIController",
	Priority = 5,
	ScreenChanged = Signal.new(), -- (id: string?, hideHud: boolean)
	MenuTabsChanged = Signal.new(),
	SettingsChanged = Signal.new(), -- (settings)
	ThemeChanged = Signal.new(), -- (name)
}

local LAYERS = { "hud", "screens", "modal", "toast" }
local PENDING_HOLD = 3 -- seconds a local settings change wins over an older server echo

local built = false
local gui: ScreenGui = nil :: any
local root: Frame = nil :: any
local rootScale: UIScale = nil :: any
local layers: { [string]: Frame } = {}
local stack: ScreenStack.Stack = nil :: any
local menuTabs: { [string]: MenuTab } = {}

local defaults: { [string]: any } = table.clone(SettingsDefaults.settings)
local settings: { [string]: any } = table.clone(defaults)
local pending: { [string]: { value: any, at: number } } = {}
local currentScale = 1

-- The data feature's Store controller (optional: the UI works without it).
local warnedNoStore = false
local function store(): any
	local all = Registry.all()
	local s = all.Store or all.StoreController
	if s == nil and not warnedNoStore then
		warnedNoStore = true
		warn("[UIController] Store controller not found; using default settings and theme")
	end
	return s
end

---------------------------------------------------------------------------------------------------
-- Scale and safe-area insets
---------------------------------------------------------------------------------------------------
local function computeInsets(viewport: Vector2): Kit.Insets
	local top, left, right, bottom = 0, 0, 0, 0
	local ok, inset = pcall(function()
		return (GuiService:GetGuiInset())
	end)
	if ok and typeof(inset) == "Vector2" then
		top = inset.Y
	end
	local okArea, rect = pcall(function()
		return GuiService:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
	end)
	if okArea and typeof(rect) == "Rect" and viewport.X > 0 and viewport.Y > 0 then
		local r = rect :: Rect
		local t, l = r.Min.Y, r.Min.X
		local rr, b = viewport.X - r.Max.X, viewport.Y - r.Max.Y
		-- Only accept sane values (screen pixels); anything odd falls back to the plain GUI inset.
		if t >= 0 and t < viewport.Y * 0.3 then
			top = math.max(top, t)
		end
		if l >= 0 and l < viewport.X * 0.2 then
			left = l
		end
		if rr >= 0 and rr < viewport.X * 0.2 then
			right = rr
		end
		if b >= 0 and b < viewport.Y * 0.2 then
			bottom = b
		end
	end
	local s = if currentScale > 0 then currentScale else 1
	return { top = top / s, left = left / s, right = right / s, bottom = bottom / s }
end

local function updateScale()
	if not built then
		return
	end
	local viewport = gui.AbsoluteSize
	if viewport.Y <= 0 then
		local cam = workspace.CurrentCamera
		if cam then
			viewport = cam.ViewportSize
		end
	end
	local s = Theme.uiScale(viewport.Y, settings.uiScale)
	currentScale = s
	rootScale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
	Kit.setInsets(computeInsets(viewport))
end

---------------------------------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------------------------------
local function applySettings()
	Kit.setReducedMotion(settings.reducedMotion == true)
	Sfx.setVolume("sfx", tonumber(settings.sfx) or defaults.sfx)
	Sfx.setVolume("music", tonumber(settings.music) or defaults.music)
	updateScale()
	UIController.SettingsChanged:Fire(table.clone(settings))
end

local function mergeStoreSettings(value: any)
	local now = os.clock()
	local merged = table.clone(defaults)
	if type(value) == "table" then
		for k, v in value do
			if defaults[k] ~= nil and type(v) == type(defaults[k]) then
				merged[k] = v
			end
		end
	end
	-- Keep recent local changes until the server echoes them (no slider flicker).
	for k, p in pending do
		if merged[k] == p.value or now - p.at > PENDING_HOLD then
			pending[k] = nil
		else
			merged[k] = p.value
		end
	end
	settings = merged
	applySettings()
end

function UIController:GetSettings(): { [string]: any }
	return table.clone(settings)
end

function UIController:SetSetting(key: string, value: any, localOnly: boolean?)
	if defaults[key] == nil or type(value) ~= type(defaults[key]) then
		warn("[UIController] unknown setting " .. tostring(key))
		return
	end
	settings[key] = value
	pending[key] = { value = value, at = os.clock() }
	applySettings()
	if not localOnly then
		Net.send("Settings.Set", key, value)
	end
end

function UIController:ResetSettings()
	settings = table.clone(defaults)
	table.clear(pending)
	applySettings()
	Net.send("Settings.Reset")
end

---------------------------------------------------------------------------------------------------
-- Theme by career rank
---------------------------------------------------------------------------------------------------
local function rankFromCareer(career: any): number?
	if type(career) ~= "table" then
		return nil
	end
	if type(career.rank) == "number" then
		return career.rank
	end
	if type(career.roleId) == "string" then
		return if career.roleId == "student" then 0 else 1
	end
	return nil
end

local function applyCareerTheme(career: any)
	local name = Theme.forRank(rankFromCareer(career))
	if Theme.set(name) then
		UIController.ThemeChanged:Fire(name)
	end
end

---------------------------------------------------------------------------------------------------
-- Screens (delegated to ScreenStack)
---------------------------------------------------------------------------------------------------
function UIController:Open(id: string, args: any?): boolean
	return stack.open(id, args)
end

function UIController:Close(id: string?): boolean
	return stack.close(id)
end

function UIController:Toggle(id: string, args: any?)
	if stack.isOpen(id) then
		stack.close(id)
	else
		stack.open(id, args)
	end
end

function UIController:IsOpen(id: string?): boolean
	return stack.isOpen(id)
end

function UIController:Current(): string?
	return stack.current()
end

function UIController:Back(): boolean
	return stack.back()
end

function UIController:PushModal(close: () -> ()): () -> ()
	return stack.pushModal(close)
end

function UIController:HasModal(): boolean
	return stack.hasModal()
end

function UIController:Confirm(opts: Kit.ConfirmOpts?, callback: ((boolean) -> ())?)
	return Kit.Confirm(opts, callback)
end

function UIController:GetScreenIds(): { string }
	return stack.known()
end

---------------------------------------------------------------------------------------------------
-- Menu tabs
---------------------------------------------------------------------------------------------------
function UIController:RegisterMenuTab(tab: MenuTab)
	if type(tab) ~= "table" or type(tab.id) ~= "string" or tab.id == "" then
		warn("[UIController] RegisterMenuTab needs an id")
		return
	end
	menuTabs[tab.id] = {
		id = tab.id,
		title = if type(tab.title) == "string" then tab.title else tab.id,
		glyph = tab.glyph,
		order = if type(tab.order) == "number" then tab.order else 100,
		screen = tab.screen,
		quick = tab.quick == true,
		onClick = tab.onClick,
		badge = tab.badge,
		locked = tab.locked == true,
	}
	UIController.MenuTabsChanged:Fire()
end

function UIController:UnregisterMenuTab(id: string)
	if menuTabs[id] then
		menuTabs[id] = nil
		UIController.MenuTabsChanged:Fire()
	end
end

function UIController:SetMenuBadge(id: string, text: string?)
	local tab = menuTabs[id]
	if tab and tab.badge ~= text then
		tab.badge = text
		UIController.MenuTabsChanged:Fire()
	end
end

function UIController:SetMenuLocked(id: string, locked: boolean)
	local tab = menuTabs[id]
	if tab and tab.locked ~= locked then
		tab.locked = locked
		UIController.MenuTabsChanged:Fire()
	end
end

function UIController:GetMenuTabs(): { MenuTab }
	local list: { MenuTab } = {}
	for _, tab in menuTabs do
		table.insert(list, table.clone(tab))
	end
	table.sort(list, function(a, b)
		local oa, ob = a.order or 100, b.order or 100
		if oa == ob then
			return a.title < b.title
		end
		return oa < ob
	end)
	return list
end

-- Runs a tab's action: its onClick, or opening its screen (Back then returns to the menu).
function UIController:ActivateTab(id: string)
	local tab = menuTabs[id]
	if tab == nil then
		return
	end
	if tab.locked then
		Sfx.play("error")
		self:Notify(Strings.get("locked"), "warn")
		return
	end
	if tab.onClick then
		local ok, err = pcall(tab.onClick :: any)
		if not ok then
			warn(("[UIController] menu tab %s failed: %s"):format(id, tostring(err)))
		end
		return
	end
	self:Open(tab.screen or tab.id, { from = "Menu" })
end

---------------------------------------------------------------------------------------------------
-- Misc
---------------------------------------------------------------------------------------------------
function UIController:GetLayer(name: string): Frame
	local layer = layers[name]
	assert(layer, "unknown UI layer " .. tostring(name))
	return layer
end

function UIController:GetScreenGui(): ScreenGui
	return gui
end

function UIController:GetScale(): number
	return currentScale
end

function UIController:Notify(text: string, kind: string?)
	local hud = Registry.all().HudController
	if hud and type(hud.Flash) == "function" then
		hud:Flash(text, kind)
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "TheStreetUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10

	-- Root is sized 1/scale and scaled by `scale`, so it always covers exactly the screen.
	root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	rootScale = Instance.new("UIScale")
	rootScale.Name = "RootScale"
	rootScale.Parent = root

	for i, name in LAYERS do
		local layer = Instance.new("Frame")
		layer.Name = name
		layer.BackgroundTransparency = 1
		layer.BorderSizePixel = 0
		layer.Size = UDim2.fromScale(1, 1)
		layer.ZIndex = i
		layer.Parent = root
		layers[name] = layer
	end
	built = true
end

local function parentGui()
	local player = Players.LocalPlayer
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		gui.Parent = playerGui
		return
	end
	task.spawn(function()
		local pg = player:WaitForChild("PlayerGui", 60)
		if pg then
			gui.Parent = pg
			updateScale()
		else
			warn("[UIController] PlayerGui never appeared")
		end
	end)
end

function UIController:Init()
	buildGui()
	stack = ScreenStack.new({
		layer = layers.screens,
		folder = UIFolder:FindFirstChild("Screens"),
		makeCtx = function(id: string, close: () -> ())
			return {
				Registry = Registry,
				Net = Net,
				Theme = Theme,
				Kit = Kit,
				Store = store(),
				Strings = Strings,
				Sfx = Sfx,
				UI = UIController,
				id = id,
				screenGui = gui,
				close = close,
			}
		end,
		onChanged = function(id: string?, hideHud: boolean)
			UIController.ScreenChanged:Fire(id, hideHud)
		end,
		sound = Sfx.play,
		onOpenError = function(_id: string)
			UIController:Notify(Strings.get("error_screen"), "bad")
		end,
	})
	Kit.setHost({
		modal = layers.modal,
		push = function(close: () -> ())
			return stack.pushModal(close)
		end,
		sound = Sfx.play,
	})
	parentGui()
	updateScale()

	self:RegisterMenuTab({
		id = "settings",
		title = Strings.get("settings"),
		glyph = "⚙",
		order = 1000,
		screen = "Settings",
	})
end

function UIController:Start()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
	updateScale()
	Sfx.preload()

	-- Escape closes the top modal/screen (gamepad B is bound by the stack while something is open).
	UserInputService.InputBegan:Connect(function(input: InputObject, _gameProcessed: boolean)
		if input.KeyCode ~= Enum.KeyCode.Escape then
			return
		end
		if UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		if stack.isOpen(nil) or stack.hasModal() then
			stack.back()
		end
	end)

	local s = store()
	if s then
		local ok, err = pcall(function()
			applyCareerTheme(s:Get("career"))
			s:Changed("career"):Connect(applyCareerTheme)
			mergeStoreSettings(s:Get("settings"))
			s:Changed("settings"):Connect(mergeStoreSettings)
		end)
		if not ok then
			warn("[UIController] Store wiring failed: " .. tostring(err))
		end
	end
	applySettings()

	-- Load every screen module in the background so load errors surface early and screens whose id
	-- differs from their file name resolve.
	task.defer(stack.loadAll)
end

return UIController
