--!strict
-- HudController (client, Priority 10): the always-on HUD.
--   top-left   career card (role, level, XP bar, cash, review status) + objective line
--   top-right  phone menu button + quick buttons for menu tabs registered with quick = true
--   bottom     news ticker band
--   toast layer: toast stack (bottom-right) and banners (top-centre)
-- Listens to UI.Notify (text, kind, count?), UI.Banner ({title, subtitle, style, duration}),
-- UI.Ticker (text) and Quest.Objective (owned by tutorial). Pulls ticker history from UI.TickerHistory.
--
-- API:
--   HudController:SetObjective(text?)     nil/"" hides the objective line
--   HudController:Flash(text, kind?, count?)  local toast (kinds info good bad warn cash xp)
--   HudController:Banner({title, subtitle?, style?, duration?})   styles event promotion warning celebration
--   HudController:Ticker(text)            local ticker line
--   HudController:SetVisible(visible)     manual HUD hide (screens use args.hideHud instead)
-- Signals: ObjectiveChanged(text?)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Strings = require(Shared.Config.Strings)
local Registry = require(script.Parent.Parent.Registry)
local UIFolder = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UIFolder:WaitForChild("Kit"))
local Sfx = require(UIFolder:WaitForChild("Sfx"))
local CareerCard = require(script.CareerCard)
local Toasts = require(script.Toasts)
local BannerModule = require(script.Banner)
local TickerModule = require(script.Ticker)

local HudController = {
	Name = "HudController",
	Priority = 10,
	ObjectiveChanged = Signal.new(), -- (text?)
}

local KIND_SOUND = {
	info = "notify",
	good = "good",
	bad = "bad",
	warn = "error",
	cash = "cash",
	xp = "chime",
}
local MAX_TEXT = 240
local MOBILE_TOAST_LIFT = 150 -- keep toasts above the touch jump button

local built = false
local hudLayer: Frame = nil :: any
local safe: Frame = nil :: any
local safePad: UIPadding = nil :: any
local card: CareerCard.Card = nil :: any
local objectivePanel: Frame = nil :: any
local objectiveLabel: Kit.Label = nil :: any
local quickColumn: Frame = nil :: any
local toasts: Toasts.Stack = nil :: any
local banner: BannerModule.Banner = nil :: any
local ticker: TickerModule.Ticker = nil :: any

local objectiveText: string? = nil
local manualHidden = false
local screenHidesHud = false
local tickerSetting = true
local quickButtons: { Instance } = {}

local function uiController(): any
	return Registry.all().UIController
end

local function store(): any
	local all = Registry.all()
	return all.Store or all.StoreController
end

local function cleanText(v: any): string?
	if type(v) == "number" then
		v = tostring(v)
	end
	if type(v) ~= "string" or v == "" then
		return nil
	end
	if #v > MAX_TEXT then
		local cut = utf8.offset(v, MAX_TEXT + 1)
		v = string.sub(v, 1, if cut then cut - 1 else MAX_TEXT)
	end
	return v
end

---------------------------------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------------------------------
local function isTouchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function applyInsets()
	if not built then
		return
	end
	local i = Kit.insets()
	safePad.PaddingTop = UDim.new(0, Kit.Core.px(i.top + 8))
	safePad.PaddingLeft = UDim.new(0, Kit.Core.px(i.left + 10))
	safePad.PaddingRight = UDim.new(0, Kit.Core.px(i.right + 10))
	safePad.PaddingBottom = UDim.new(0, Kit.Core.px(i.bottom + 6))
	ticker.setBottom(i.bottom)
	local lift = if isTouchOnly() then MOBILE_TOAST_LIFT else 0
	toasts.setOffsets(i.right + 12, i.bottom + TickerModule.HEIGHT + 12 + lift)
	banner.setTop(i.top + 12)
end

local function applyVisibility()
	if not built then
		return
	end
	hudLayer.Visible = not (manualHidden or screenHidesHud)
	ticker.setEnabled(tickerSetting)
end

local function rebuildQuickButtons()
	if not built then
		return
	end
	for _, b in quickButtons do
		b:Destroy()
	end
	table.clear(quickButtons)
	local ui = uiController()
	if ui == nil then
		return
	end
	local ok, tabs = pcall(function()
		return ui:GetMenuTabs()
	end)
	if not ok or type(tabs) ~= "table" then
		return
	end
	local order = 10
	for _, tab in tabs do
		if tab.quick then
			order += 1
			local glyph = if type(tab.glyph) == "string" and tab.glyph ~= ""
				then tab.glyph
				else string.upper(string.sub(tab.title or tab.id, 1, 1))
			local id = tab.id
			local btn = Kit.IconButton({
				glyph = glyph,
				style = "secondary",
				size = 48,
				name = "Quick_" .. id,
				layoutOrder = order,
				onClick = function()
					ui:ActivateTab(id)
				end,
			})
			btn.frame.Parent = quickColumn
			table.insert(quickButtons, btn.frame)
		end
	end
end

local function build()
	local ui = uiController()
	hudLayer = ui:GetLayer("hud")
	local toastLayer = ui:GetLayer("toast")

	safe = Kit.frame("Safe")
	safe.Parent = hudLayer
	safePad = Instance.new("UIPadding")
	safePad.Parent = safe

	-- Top-left column: career card + objective.
	local left = Kit.frame("Left", UDim2.fromOffset(300, 0))
	left.AutomaticSize = Enum.AutomaticSize.Y
	left.Parent = safe
	Kit.list(left, false, 6)
	card = CareerCard.new(function()
		Sfx.play("levelup")
	end)
	card.frame.LayoutOrder = 1
	card.frame.Parent = left

	local objective = Kit.Panel({ name = "Objective", size = UDim2.fromOffset(300, 0), autoSize = "y", padding = 10 })
	objectivePanel = objective.frame
	objectivePanel.LayoutOrder = 2
	objectivePanel.Visible = false
	objectivePanel.Parent = left
	Kit.list(objectivePanel, false, 2)
	local objectiveTitle = Kit.Label({
		text = string.upper(Strings.get("hud_objective")),
		size = "xs",
		font = "bodyBold",
		color = "accent",
		name = "Heading",
		layoutOrder = 1,
	})
	objectiveTitle.frame.Parent = objectivePanel
	objectiveLabel = Kit.Label({ text = "", size = "md", font = "bodyBold", name = "Text", layoutOrder = 2 })
	objectiveLabel.frame.Parent = objectivePanel

	-- Top-right column: menu + quick buttons.
	quickColumn = Kit.frame("Right", UDim2.fromOffset(56, 0))
	quickColumn.AutomaticSize = Enum.AutomaticSize.Y
	quickColumn.AnchorPoint = Vector2.new(1, 0)
	quickColumn.Position = UDim2.fromScale(1, 0)
	quickColumn.Parent = safe
	local rightList = Kit.list(quickColumn, false, 8)
	rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	local menu = Kit.IconButton({
		glyph = "📱",
		style = "primary",
		size = 56,
		name = "MenuButton",
		layoutOrder = 1,
		onClick = function()
			local u = uiController()
			if u then
				u:Toggle("Menu")
			end
		end,
	})
	menu.frame.Parent = quickColumn

	-- Bottom ticker.
	ticker = TickerModule.new()
	ticker.frame.Parent = hudLayer

	-- Toast layer: toasts + banner.
	toasts = Toasts.new()
	toasts.frame.Parent = toastLayer
	banner = BannerModule.new()
	banner.frame.Parent = toastLayer

	built = true
	applyInsets()
	applyVisibility()
end

---------------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------------
function HudController:SetObjective(text: string?)
	local clean = cleanText(text)
	if clean == objectiveText then
		return
	end
	objectiveText = clean
	if built then
		objectiveLabel.setText(clean or "")
		objectivePanel.Visible = clean ~= nil
		if clean then
			-- Brief highlight so a new step is noticed.
			local stroke = objectivePanel:FindFirstChildOfClass("UIStroke")
			if stroke then
				local t = Kit.Theme.get()
				stroke.Color = t.colors.accent
				stroke.Thickness = t.stroke + 2
				task.delay(1.2, function()
					local now = Kit.Theme.get()
					stroke.Color = now.colors.border
					stroke.Thickness = now.stroke
				end)
			end
		end
	end
	HudController.ObjectiveChanged:Fire(clean)
end

function HudController:GetObjective(): string?
	return objectiveText
end

function HudController:Flash(text: string, kind: string?, count: number?)
	local clean = cleanText(text)
	if clean == nil or not built then
		return
	end
	local k = if type(kind) == "string" and Kit.kinds[kind] then kind else "info"
	local n = if type(count) == "number" and count >= 1 then math.floor(count) else nil
	local fresh = toasts.push(clean, k, n)
	Sfx.play(if fresh then (KIND_SOUND[k] or "notify") else "type")
end

function HudController:Banner(opts: BannerModule.Opts)
	if built and type(opts) == "table" then
		banner.show(opts)
	end
end

function HudController:Ticker(text: string)
	local clean = cleanText(text)
	if clean and built then
		ticker.push(clean)
	end
end

function HudController:SetVisible(visible: boolean)
	manualHidden = not visible
	applyVisibility()
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function HudController:Init()
	build()
end

local function bindStore()
	local s = store()
	if s == nil then
		return
	end
	local ok, err = pcall(function()
		card.setCareer(s:Get("career"))
		s:Changed("career"):Connect(function(v: any)
			card.setCareer(v)
		end)
		local function onWallet(w: any)
			card.setCash(if type(w) == "table" then w.cash else nil)
		end
		onWallet(s:Get("wallet"))
		s:Changed("wallet"):Connect(onWallet)
	end)
	if not ok then
		warn("[HudController] Store wiring failed: " .. tostring(err))
	end
end

local function onQuestObjective(...: any)
	local n = select("#", ...)
	local a, b = ...
	local text: any
	if type(a) == "table" then
		text = a.text or a.objective
	elseif n >= 2 then
		text = b -- (questId, text): text nil clears
	elseif type(a) == "string" and string.find(a, "^[%w_%-:]+$") and string.find(a, "[_:]") then
		-- (questId, nil) arrives as just the id (remotes drop trailing nils): treat as "clear".
		text = nil
	else
		text = a -- (text)
	end
	HudController:SetObjective(if type(text) == "string" then text else nil)
end

function HudController:Start()
	local ui = uiController()
	if ui then
		ui.ScreenChanged:Connect(function(_id: string?, hideHud: boolean)
			screenHidesHud = hideHud == true
			applyVisibility()
		end)
		ui.MenuTabsChanged:Connect(rebuildQuickButtons)
		ui.SettingsChanged:Connect(function(settings: any)
			tickerSetting = type(settings) ~= "table" or settings.showTicker ~= false
			applyVisibility()
		end)
		local okSettings, current = pcall(function()
			return ui:GetSettings()
		end)
		if okSettings and type(current) == "table" then
			tickerSetting = current.showTicker ~= false
		end
	end
	Kit.InsetsChanged:Connect(applyInsets)
	UserInputService.LastInputTypeChanged:Connect(applyInsets)
	applyInsets()
	applyVisibility()
	rebuildQuickButtons()

	Net.listen("UI.Notify", function(text: any, kind: any, count: any)
		HudController:Flash(text, kind, count)
	end)
	Net.listen("UI.Banner", function(opts: any)
		HudController:Banner(opts)
	end)
	Net.listen("UI.Ticker", function(text: any)
		HudController:Ticker(text)
	end)
	Net.listen("Quest.Objective", onQuestObjective)

	bindStore()

	task.spawn(function()
		local lines = Net.invoke("UI.TickerHistory")
		if type(lines) == "table" then
			local clean: { string } = {}
			for _, line in lines do
				local c = cleanText(line)
				if c then
					table.insert(clean, c)
				end
			end
			ticker.setHistory(clean)
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		ticker.step(math.min(dt, 0.1))
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(toasts.tick :: any, os.clock())
			if not ok then
				warn("[HudController] toast tick failed: " .. tostring(err))
			end
		end
	end)
end

return HudController
