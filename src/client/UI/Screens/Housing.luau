--!strict
-- Housing screen (UI screen id "Housing", owned by `shop`; spec §11, v3 §13). Opened by ShopController (a
-- `housing_panel` prompt on your desk, office or room sends { context }, the "Home" menu tab, "Place it" in the
-- Shop) with optional args { context = "desk" | "office" | "apartment" | "dorm" }.
--
-- Layout: a tab per place the player holds (desk or office, apartment or dorm room), then for the selected one a
-- summary card (where it is, the detail budget, the deal plaques on display), the room theme picker (Office Theme
-- Pass themes show a lock), and one row per decor spot ("Desk spot 1 · Banker's Lamp" with Change / Remove).
-- Change opens a picker of owned pieces that fit that spot (Logic/Economy/Housing rules, re-checked by the server).
-- The view comes from Housing.Get (HousingService); placed / owned decor from the replicated `housing` key.
--
-- ctx (from UIController) = { Registry, Store, UI, close, ... }; every field is optional so the screen also opens
-- under Lune for tests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared.Config.Shop)
local Decor = require(Shared.Config.Decor)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Parts = script.Parent:WaitForChild("ShopParts")
local HousingView = require(Parts:WaitForChild("HousingView"))

local Screen = { id = "Housing", hideHud = true, View = HousingView }

local ROW_H = 56
local PICK_ROW_H = 48
local PICK_MAX_H = 330

function Screen.open(args: any, root: Instance, ctx: any): { close: () -> () }
	local c: { [string]: any } = if type(ctx) == "table" then ctx else {}
	local registry = c.Registry
	local storeApi = c.Store
	local ui = c.UI
	local closeScreen = if type(c.close) == "function" then c.close else nil
	local api: any = nil
	if registry and type(registry.get) == "function" then
		api = registry.get("ShopController")
	end
	local a: { [string]: any } = if type(args) == "table" then args else {}

	local conns: { any } = {}
	local closed = false
	local busy = false
	local view: any = nil
	local loading = false
	local selected: string? = if type(a.context) == "string" and Decor.CONTEXTS[a.context] then a.context else nil

	local function toast(text: string, kind: string?)
		if ui and type(ui.Notify) == "function" then
			ui:Notify(text, kind)
		end
	end

	local function housing(): any
		if not storeApi or type(storeApi.Get) ~= "function" then
			return nil
		end
		local ok, v = pcall(storeApi.Get, storeApi, "housing")
		return if ok then v else nil
	end

	-- Window -----------------------------------------------------------------------------------------
	local win = Kit.Window({
		title = Shop.text("housing_title"),
		subtitle = Shop.text("housing_subtitle"),
		onClose = closeScreen,
		name = "HousingWindow",
		maxSize = Vector2.new(820, 700),
	})
	win.frame.Parent = root

	local render: () -> ()
	local load: () -> ()

	local tabs = Kit.Tabs({
		tabs = {},
		name = "ContextTabs",
		onSelect = function(id: string)
			selected = id
			render()
		end,
	})
	tabs.frame.Parent = win.content

	local scroll = Kit.Scroll({ gap = 10, name = "Content", padding = 4 })
	scroll.frame.Position = UDim2.fromOffset(0, Kit.TAP + 8)
	scroll.frame.Size = UDim2.new(1, 0, 1, -(Kit.TAP + 8))
	scroll.frame.Parent = win.content

	-- Actions ----------------------------------------------------------------------------------------
	local function run(fn: () -> ())
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local ok, err = pcall(function()
				fn()
			end)
			if not ok then
				warn("[Housing] action failed: " .. tostring(err))
			end
			busy = false
			if not closed then
				render()
			end
		end)
	end

	local function shopDecor()
		if api then
			api:Open("decor")
		end
	end

	local function place(ctxId: string, slotId: string, decorId: string?)
		if not api then
			return
		end
		run(function()
			local ok, err = api:Place(ctxId, slotId, decorId)
			if closed then
				return
			end
			if ok then
				local item = if decorId then Decor.get(decorId) else nil
				toast(
					if item then Shop.text("housing_saved", { name = item.name }) else Shop.text("housing_removed"),
					"good"
				)
				load()
			else
				toast(Shop.errorText(err), "bad")
			end
		end)
	end

	local function setTheme(ctxId: string, themeId: string)
		if not api then
			return
		end
		run(function()
			local ok, err = api:SetTheme(ctxId, themeId)
			if closed then
				return
			end
			if ok then
				local th = Decor.theme(themeId)
				toast(Shop.text("housing_theme_set", { name = if th then th.name else themeId }), "good")
				load()
			else
				toast(Shop.errorText(err), "bad")
			end
		end)
	end

	local function openPicker(cv: HousingView.ContextView, row: HousingView.Row)
		local rank = if type(view) == "table" and type(view.rank) == "number" then view.rank else 0
		local list = HousingView.candidates(cv.id, row.kind, housing(), rank)
		Kit.modal({ width = 440, name = "DecorPicker" }, function(card: Frame, close: () -> ())
			Kit.list(card, false, 10)
			local title = Kit.Heading({ text = Shop.text("housing_pick_title", { slot = row.label }), level = 3 })
			title.frame.LayoutOrder = 1
			title.frame.Parent = card
			if #list == 0 then
				local none = Kit.Label({ text = Shop.text("housing_pick_none"), color = "textDim", layoutOrder = 2 })
				none.frame.Parent = card
				local go = Kit.Button({
					text = Shop.text("housing_shop_decor"),
					fill = true,
					layoutOrder = 3,
					onClick = function()
						close()
						shopDecor()
					end,
				})
				go.frame.Parent = card
				return
			end
			local height = math.min(PICK_MAX_H, #list * (PICK_ROW_H + 6))
			local pickScroll = Kit.Scroll({ gap = 6, name = "Choices", size = UDim2.new(1, 0, 0, height) })
			pickScroll.frame.LayoutOrder = 2
			pickScroll.frame.Parent = card
			for i, item in list do
				local current = row.item ~= nil and row.item.id == item.id
				local b = Kit.Button({
					text = item.name,
					style = if current then "primary" else "secondary",
					fill = true,
					name = "Pick_" .. item.id,
					layoutOrder = i,
					onClick = function()
						close()
						if not current then
							place(cv.id, row.slotId, item.id)
						end
					end,
				})
				b.frame.Size = UDim2.new(1, 0, 0, PICK_ROW_H)
				pickScroll.add(b)
			end
			local cancel = Kit.Button({
				text = Shop.text("housing_shop_decor"),
				style = "ghost",
				fill = true,
				layoutOrder = 3,
				onClick = function()
					close()
					shopDecor()
				end,
			})
			cancel.frame.Parent = card
		end)
	end

	-- Drawing ----------------------------------------------------------------------------------------
	local lastTabs = ""

	local function sectionHeading(text: string, order: number)
		local h = Kit.Heading({ text = text, level = 3, layoutOrder = order })
		scroll.add(h)
	end

	function render()
		if closed then
			return
		end
		scroll.clear()
		if view == nil then
			scroll.add(Kit.Label({ text = Shop.text("busy"), color = "textDim", layoutOrder = 1 }))
			return
		end
		local contexts = HousingView.contexts(view)
		-- tabs
		local defs: { { id: string, title: string, badge: string? } } = {}
		for _, cv in contexts do
			table.insert(defs, { id = cv.id, title = cv.label, badge = nil })
		end
		local sig = ""
		for _, d in defs do
			sig ..= d.id .. ","
		end
		if sig ~= lastTabs then
			lastTabs = sig
			tabs.setTabs(defs)
		end
		if #contexts == 0 then
			scroll.add(Kit.Label({ text = Shop.text("housing_none"), color = "textDim", layoutOrder = 1 }))
			scroll.add(Kit.Button({
				text = Shop.text("housing_shop_decor"),
				style = "secondary",
				layoutOrder = 2,
				onClick = shopDecor,
			}))
			return
		end
		local cv: HousingView.ContextView = contexts[1]
		for _, x in contexts do
			if x.id == selected then
				cv = x
			end
		end
		selected = cv.id
		if tabs.getSelected() ~= cv.id then
			tabs.select(cv.id, true)
		end

		-- summary
		local summary = Kit.Card({ title = cv.title, subtitle = HousingView.status(cv), layoutOrder = 1 })
		scroll.add(summary)
		if cv.live then
			local fraction, text = HousingView.budget(cv)
			summary.add(Kit.ProgressBar({ value = fraction, height = 18, label = text, name = "Budget" }))
		end
		local total = if type(view.plaqueCount) == "number" then view.plaqueCount else 0
		local plaqueLine = HousingView.plaqueLine(cv, total)
		if plaqueLine then
			summary.add(Kit.Label({ text = plaqueLine, size = "sm", color = "textDim", name = "Plaques" }))
		end

		-- themes
		local order = 2
		local themes = HousingView.themes(cv, if type(view.passes) == "table" then view.passes else {})
		if #themes > 0 then
			sectionHeading(Shop.text("housing_theme"), order)
			order += 1
			local row =
				Kit.List({ direction = "horizontal", gap = 8, wraps = true, name = "Themes", layoutOrder = order })
			row.frame.Size = UDim2.new(1, 0, 0, 0)
			row.frame.AutomaticSize = Enum.AutomaticSize.Y
			order += 1
			scroll.add(row)
			for i, th in themes do
				local label = if th.locked then "🔒 " .. th.name else th.name
				row.add(Kit.Button({
					text = label,
					style = if th.selected then "primary" else (if th.locked then "ghost" else "secondary"),
					textSize = "sm",
					disabled = busy,
					name = "Theme_" .. th.id,
					layoutOrder = i,
					onClick = function()
						if th.selected then
							return
						end
						if th.locked then
							toast(Shop.text("pass_hint", { pass = Shop.passName(Decor.THEME_PASS) }), "info")
							if api then
								api:OpenStore()
							end
							return
						end
						setTheme(cv.id, th.id)
					end,
				}))
			end
		end

		-- spots
		sectionHeading(Shop.text("housing_slots"), order)
		order += 1
		local rows = HousingView.rows(cv, housing())
		if not cv.live then
			scroll.add(Kit.Label({ text = HousingView.status(cv), color = "textDim", layoutOrder = order }))
			order += 1
		elseif #rows == 0 then
			scroll.add(Kit.Label({ text = Shop.text("housing_none"), color = "textDim", layoutOrder = order }))
			order += 1
		end
		for _, r in rows do
			local panel = Kit.Panel({ name = "Spot_" .. r.slotId, layoutOrder = order, padding = 8 })
			order += 1
			panel.frame.Size = UDim2.new(1, 0, 0, ROW_H + 16)
			panel.frame.AutomaticSize = Enum.AutomaticSize.None
			scroll.add(panel)
			local text = Kit.Label({
				text = r.label .. "\n" .. r.text,
				size = "sm",
				autoSize = "none",
				name = "Text",
			})
			text.frame.Size = UDim2.new(1, -220, 1, 0)
			text.frame.TextYAlignment = Enum.TextYAlignment.Center
			text.frame.Parent = panel.frame
			local buttons = Kit.List({ direction = "horizontal", gap = 6, justify = "end", name = "Buttons" })
			buttons.frame.AnchorPoint = Vector2.new(1, 0.5)
			buttons.frame.Position = UDim2.fromScale(1, 0.5)
			buttons.frame.Parent = panel.frame
			buttons.add(Kit.Button({
				text = Shop.text("housing_change"),
				style = "secondary",
				size = UDim2.fromOffset(104, Kit.TAP),
				disabled = busy or not cv.live,
				layoutOrder = 1,
				onClick = function()
					openPicker(cv, r)
				end,
			}))
			if r.item then
				buttons.add(Kit.Button({
					text = Shop.text("housing_remove"),
					style = "ghost",
					size = UDim2.fromOffset(104, Kit.TAP),
					disabled = busy or not cv.live,
					layoutOrder = 2,
					onClick = function()
						place(cv.id, r.slotId, nil)
					end,
				}))
			end
		end

		scroll.add(Kit.Button({
			text = Shop.text("housing_shop_decor"),
			style = "secondary",
			fill = true,
			layoutOrder = order,
			name = "ShopDecor",
			onClick = shopDecor,
		}))
	end

	function load()
		if loading or closed or not api then
			return
		end
		loading = true
		task.spawn(function()
			local v, err = api:GetHousing()
			loading = false
			if closed then
				return
			end
			if type(v) == "table" then
				view = v
			elseif view == nil then
				toast(Shop.errorText(err), "bad")
				view = { loaded = false, contexts = {} }
			end
			render()
		end)
	end

	-- Live data ----------------------------------------------------------------------------------------
	if storeApi and type(storeApi.Changed) == "function" then
		local ok, sig = pcall(storeApi.Changed, storeApi, "housing")
		if ok and sig then
			table.insert(
				conns,
				sig:Connect(function()
					if not closed and not busy then
						render()
					end
				end)
			)
		end
	end
	if api and api.HousingChanged then
		table.insert(
			conns,
			api.HousingChanged:Connect(function()
				load()
			end)
		)
	end

	render()
	if api then
		load()
	else
		view = { loaded = false, contexts = {} }
		render()
	end

	return {
		close = function()
			if closed then
				return
			end
			closed = true
			for _, conn in conns do
				if conn then
					conn:Disconnect()
				end
			end
			table.clear(conns)
			win.close()
		end,
	}
end

return Screen
