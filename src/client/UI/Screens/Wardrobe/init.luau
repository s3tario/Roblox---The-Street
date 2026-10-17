--!strict
-- Wardrobe screen (UI screen id "Wardrobe", owned by `wardrobe`). Opened by WardrobeController (wardrobe
-- interact prompts, the menu tab) with optional args { slot = "outer", item = "pm_jacket" } to pre-select.
--
-- Layout: a live 3D preview (drag to turn) with the Outfit Level of the look on it ("Outfit Lv 3", v3 §5), the
-- firm's dress code when the player has one, and the "Wear my avatar" toggle; and the catalogue: slot tabs plus
-- "Outfits" (presets), a grid of item cards (rarity strip, "Lv N" badge, brand line, price / Owned / Wearing /
-- lock badge) and a details bar with the action for the selected item (Wear, Take off, Buy). Wide screens put the
-- preview on the left; narrow ones stack it on top. Tapping a card tries the item on in the preview only; the
-- action button makes it real through WardrobeController (server-validated). The preview wears the company logo
-- on vests and quarter-zips exactly like the real character (v3 §16).
--
-- ctx (from UIController) = { Registry, Store, UI, close, ... }; every field is optional so the screen also
-- opens under Lune for tests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local View = require(script.View)
local Cards = require(script.Cards)
local Preview = require(script.Preview)
local PresetsPanel = require(script.Presets)
local Status = require(script.Status)

local Screen = { id = "Wardrobe", hideHud = true, View = View }

type Inv = {
	owned: { [string]: boolean },
	equipped: { [string]: string },
	presets: { [string]: any },
	wearAvatar: boolean,
}

type ToggleLike = { frame: TextButton, set: (value: boolean, silent: boolean?) -> () }

local DETAIL_H = 116
local CONTROLS_H = 52

local function emptyInv(): Inv
	return { owned = {}, equipped = {}, presets = {}, wearAvatar = false }
end

local function readInv(raw: any): Inv
	if type(raw) ~= "table" then
		return emptyInv()
	end
	return {
		owned = if type(raw.owned) == "table" then raw.owned else {},
		equipped = if type(raw.equipped) == "table" then raw.equipped else {},
		presets = if type(raw.presets) == "table" then raw.presets else {},
		wearAvatar = raw.wearAvatar == true,
	}
end

-- The local player's skin tone (their character's head), for the preview figure.
local function playerLook(): (string, Color3?)
	if not Kit.Core.LIVE then
		return "Preview", nil
	end
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	if not player then
		return "Preview", nil
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local skin: Color3? = nil
	if head and head:IsA("BasePart") then
		local saved = head:GetAttribute("CareerLookColor")
		skin = if typeof(saved) == "Color3" then saved else head.Color
	end
	return player.Name, skin
end

function Screen.open(args: any, root: Instance, ctx: any): { close: () -> () }
	local c: { [string]: any } = if type(ctx) == "table" then ctx else {}
	local registry = c.Registry
	local storeApi = c.Store
	local ui = c.UI
	local closeScreen = if type(c.close) == "function" then c.close else nil
	local api: any = nil
	if registry and type(registry.get) == "function" then
		api = registry.get("WardrobeController")
	end

	local conns: { any } = {}
	local closed = false

	local function toast(text: string, kind: string?)
		if ui and type(ui.Notify) == "function" then
			ui:Notify(text, kind)
		end
	end

	-- State ---------------------------------------------------------------------------------------
	local inv = readInv(if storeApi then storeApi:Get("inventory") else nil)
	local access = if api then api:GetAccess() else { rank = 0, passes = {} }
	local a: { [string]: any } = if type(args) == "table" then args else {}
	local tab: string = if type(a.slot) == "string" and Catalog.SLOT_SET[a.slot] then a.slot else View.TABS[1]
	local selected: string? = nil
	if type(a.item) == "string" then
		local item = Catalog.get(Catalog.canonical(a.item))
		if item and not item.hidden then
			selected = item.id
			tab = item.slot
		end
	end
	local busy = false
	-- assigned below (the controls are built before the functions they call)
	local refresh: () -> ()
	local rebuildList: () -> ()
	local act: () -> ()
	local takeOff: () -> ()

	local function viewer(): Catalog.Viewer
		return { owned = inv.owned, rank = access.rank, passes = access.passes }
	end

	-- Window and regions -------------------------------------------------------------------------
	local win = Kit.Window({
		title = Catalog.text("title"),
		subtitle = Catalog.text("subtitle"),
		onClose = closeScreen,
		name = "WardrobeWindow",
		maxSize = Vector2.new(1100, 720),
	})
	win.frame.Parent = root

	local body = Kit.frame("Body", UDim2.fromScale(1, 1))
	body.Parent = win.content

	local previewArea = Kit.frame("PreviewArea")
	previewArea.Parent = body
	local catalogArea = Kit.frame("CatalogArea")
	catalogArea.Parent = body

	-- Preview + controls
	local playerName, skin = playerLook()
	local preview = Preview.new({
		name = playerName,
		skin = skin,
		hint = Catalog.text("preview_hint"),
		companyLogo = (access :: any).companyLogo,
	})
	preview.frame.Size = UDim2.new(1, 0, 1, -CONTROLS_H)
	preview.frame.Parent = previewArea

	-- Outfit Level of the look on the preview, what holds it down, and the firm's dress code
	local status = Status.build(preview.overlay)

	local controls = Kit.List({ direction = "horizontal", gap = 8, name = "Controls" })
	controls.frame.AnchorPoint = Vector2.new(0, 1)
	controls.frame.Position = UDim2.fromScale(0, 1)
	controls.frame.Size = UDim2.new(1, 0, 0, CONTROLS_H - 6)
	controls.frame.AutomaticSize = Enum.AutomaticSize.None
	controls.frame.Parent = previewArea

	local avatarToggle: ToggleLike
	avatarToggle = Kit.Toggle({
		label = Catalog.text("wear_avatar"),
		value = inv.wearAvatar,
		name = "WearAvatar",
		onChange = function(v: boolean)
			if not api then
				toast(View.errorText("generic"), "bad")
				avatarToggle.set(not v, true)
				return
			end
			task.spawn(function()
				local ok, err = api:SetWearAvatar(v)
				if closed then
					return
				end
				if not ok then
					avatarToggle.set(not v, true)
					toast(View.errorText(err), "bad")
				end
			end)
		end,
	})
	avatarToggle.frame.Size = UDim2.new(1, -112, 0, Kit.TAP)
	controls.add(avatarToggle)
	local resetButton = Kit.Button({
		text = Catalog.text("reset_preview"),
		style = "ghost",
		size = UDim2.fromOffset(104, Kit.TAP),
		name = "ResetPreview",
		onClick = function()
			selected = nil
			preview.reset()
			refresh()
		end,
	})
	controls.add(resetButton)

	-- Catalogue: tabs, list area, details bar
	local tabDefs: { { id: string, title: string, badge: string? } } = {}
	for _, id in View.TABS do
		table.insert(tabDefs, { id = id, title = View.tabTitle(id), badge = nil })
	end
	local tabs = Kit.Tabs({
		tabs = tabDefs,
		selected = tab,
		name = "SlotTabs",
		onSelect = function(id: string)
			tab = id
			rebuildList()
		end,
	})
	tabs.frame.Parent = catalogArea

	local scroll = Kit.Scroll({ gap = 8, name = "Items" })
	scroll.frame.Position = UDim2.fromOffset(0, Kit.TAP + 10)
	scroll.frame.Size = UDim2.new(1, 0, 1, -(Kit.TAP + 10 + DETAIL_H + 8))
	scroll.frame.Parent = catalogArea

	local grid = Kit.Grid({ columns = 2, cellHeight = 132, gap = 8, name = "Grid" })
	scroll.add(grid)
	local emptyLabel = Kit.Label({ text = Catalog.text("empty_slot"), color = "textDim", name = "Empty" })
	scroll.add(emptyLabel)
	local presets = PresetsPanel.build({
		onSave = function(index: number, name: string?)
			if busy or not api then
				return
			end
			busy = true
			refresh()
			task.spawn(function()
				local ok, err = api:SavePreset(index, name)
				busy = false
				if closed then
					return
				end
				toast(if ok then Catalog.text("preset_saved") else View.errorText(err), if ok then "good" else "bad")
				refresh()
			end)
		end,
		onLoad = function(index: number)
			if busy or not api then
				return
			end
			busy = true
			refresh()
			task.spawn(function()
				local ok, err = api:LoadPreset(index)
				busy = false
				if closed then
					return
				end
				if ok then
					selected = nil
				end
				toast(if ok then Catalog.text("preset_loaded") else View.errorText(err), if ok then "good" else "bad")
				refresh()
			end)
		end,
	})
	scroll.add(presets)

	-- details bar
	local detail = Kit.Panel({ color = "panelAlt", name = "Detail", padding = 10 })
	detail.frame.AnchorPoint = Vector2.new(0, 1)
	detail.frame.Position = UDim2.fromScale(0, 1)
	detail.frame.Size = UDim2.new(1, 0, 0, DETAIL_H)
	detail.frame.AutomaticSize = Enum.AutomaticSize.None
	detail.frame.Parent = catalogArea
	local detailText = Kit.List({ gap = 2, name = "Texts", size = UDim2.new(1, -168, 1, 0) })
	detail.add(detailText)
	local dName =
		Kit.Label({ text = "", size = "md", font = "bodyBold", autoSize = "none", height = 24, name = "Name" })
	dName.frame.TextTruncate = Enum.TextTruncate.AtEnd
	detailText.add(dName)
	local dBrand = Kit.Label({ text = "", size = "xs", autoSize = "none", height = 16, name = "Brand" })
	detailText.add(dBrand)
	local dDesc =
		Kit.Label({ text = "", size = "xs", color = "textDim", autoSize = "none", height = 34, name = "Desc" })
	dDesc.frame.TextTruncate = Enum.TextTruncate.AtEnd
	detailText.add(dDesc)
	local buttons = Kit.List({ gap = 6, name = "Buttons", size = UDim2.new(0, 160, 1, 0) })
	buttons.frame.AnchorPoint = Vector2.new(1, 0)
	buttons.frame.Position = UDim2.fromScale(1, 0)
	buttons.frame.Parent = detail.frame
	local actionButton: Kit.Button
	actionButton = Kit.Button({
		text = "",
		style = "primary",
		size = UDim2.new(1, 0, 0, Kit.TAP),
		name = "Action",
		onClick = function()
			act()
		end,
	})
	buttons.add(actionButton)
	local secondButton = Kit.Button({
		text = Catalog.text("unequip"),
		style = "secondary",
		size = UDim2.new(1, 0, 0, Kit.TAP),
		name = "TakeOff",
		onClick = function()
			takeOff()
		end,
	})
	buttons.add(secondButton)

	-- Rendering ----------------------------------------------------------------------------------
	local cards: { [string]: Cards.Card } = {}

	local function selectedItem(): Catalog.Item?
		local item = if selected then Catalog.get(selected) else nil
		if item and item.slot == tab then
			return item
		end
		return nil
	end

	local function refreshDetail()
		local item = selectedItem()
		local v = viewer()
		if item then
			local st = View.state(item, v, inv.equipped)
			local rarity = View.rarity(item.rarity)
			dName.setText(item.name)
			dBrand.setText(View.brandLine(item) .. "  ·  " .. Catalog.text("tier", { tier = item.tier }))
			dBrand.setColor(rarity.color)
			dDesc.setText(item.desc)
			actionButton.setText(if busy then Catalog.text("buying") else st.actionText)
			actionButton.setStyle(if st.action == "unequip" then "secondary" else "primary")
			actionButton.setDisabled(busy or st.action == "none")
			actionButton.frame.Visible = true
			local worn = inv.equipped[tab]
			secondButton.frame.Visible = worn ~= nil and worn ~= item.id
			secondButton.setDisabled(busy)
		else
			local worn = if tab ~= "presets" then Catalog.get(inv.equipped[tab]) else nil
			dName.setText(if worn then worn.name else View.tabTitle(tab))
			dBrand.setText(if worn then View.brandLine(worn) else "")
			dBrand.setColor(if worn then View.rarity(worn.rarity).color else "textDim")
			dDesc.setText(if tab == "presets" then "" else Catalog.text("select_hint"))
			actionButton.frame.Visible = false
			secondButton.frame.Visible = worn ~= nil
			secondButton.setDisabled(busy)
		end
		detail.frame.Visible = tab ~= "presets"
		scroll.frame.Size = if tab == "presets"
			then UDim2.new(1, 0, 1, -(Kit.TAP + 10))
			else UDim2.new(1, 0, 1, -(Kit.TAP + 10 + DETAIL_H + 8))
	end

	local function refreshCards()
		local v = viewer()
		for id, card in cards do
			local item = Catalog.get(id)
			if item then
				card.update(View.state(item, v, inv.equipped), id == selected)
			end
		end
	end

	local function refreshPreview()
		local item = selectedItem()
		local look = if item then View.preview(inv.equipped, item.slot, item.id) else View.preview(inv.equipped)
		preview.set(look)
		preview.setLogo((access :: any).companyLogo)
		local career = if storeApi then storeApi:Get("career") else nil
		status.update(look, if type(career) == "table" then career.companyId else nil)
	end

	function refresh()
		if closed then
			return
		end
		refreshCards()
		refreshDetail()
		refreshPreview()
		presets.update(inv.presets, Catalog.presetSlotsFor(viewer()), busy)
		avatarToggle.set(inv.wearAvatar, true)
	end
	function rebuildList()
		if closed then
			return
		end
		grid.clear()
		table.clear(cards)
		local isPresets = tab == "presets"
		grid.frame.Visible = not isPresets
		presets.frame.Visible = isPresets
		emptyLabel.frame.Visible = false
		if not isPresets then
			local v = viewer()
			local list = View.items(tab, v)
			emptyLabel.frame.Visible = #list == 0
			for _, item in list do
				local id = item.id
				local card = Cards.item(item, View.state(item, v, inv.equipped), {
					selected = id == selected,
					onClick = function()
						selected = if selected == id then nil else id
						refresh()
					end,
				})
				grid.add(card)
				cards[id] = card
			end
		end
		scroll.scrollToTop()
		refresh()
	end

	-- Actions -----------------------------------------------------------------------------------
	local function run(work: () -> ())
		if busy then
			return
		end
		if not api then
			toast(View.errorText("generic"), "bad")
			return
		end
		busy = true
		refresh()
		task.spawn(function()
			local ok, err = pcall(function()
				work()
			end)
			busy = false
			if not ok then
				warn("[Wardrobe] action failed: " .. tostring(err))
				toast(View.errorText("generic"), "bad")
			end
			if not closed then
				refresh()
			end
		end)
	end

	function act()
		local item = selectedItem()
		if not item then
			return
		end
		local st = View.state(item, viewer(), inv.equipped)
		if st.action == "equip" then
			run(function()
				local ok, err = api:Equip(item.slot, item.id)
				if not ok then
					toast(View.errorText(err), "bad")
				end
			end)
		elseif st.action == "unequip" then
			run(function()
				local ok, err = api:Equip(item.slot, nil)
				if not ok then
					toast(View.errorText(err), "bad")
				end
			end)
		elseif st.action == "buy" then
			run(function()
				local ok, err = api:Buy(item.id)
				if not ok then
					toast(View.errorText(err), "bad")
					return
				end
				toast(Catalog.text("purchased", { name = item.name }), "cash")
				-- the purchase replicates inventory.owned; wear it straight away
				local worn, werr = api:Equip(item.slot, item.id)
				if not worn and werr ~= "not_owned" then
					toast(View.errorText(werr), "bad")
				end
			end)
		end
	end

	function takeOff()
		if tab == "presets" or inv.equipped[tab] == nil then
			return
		end
		run(function()
			local ok, err = api:Equip(tab, nil)
			if not ok then
				toast(View.errorText(err), "bad")
			end
		end)
	end

	-- Layout ------------------------------------------------------------------------------------
	local function layout()
		-- in Offset units (UIScale undone); nil before the first layout pass (and under Lune): assume a wide window
		local size = Kit.Core.unscaledSize(body) or Vector2.new(960, 600)
		local wide = size.X >= 640 and size.X > size.Y * 0.9
		local catalogWidth: number
		if wide then
			previewArea.Position = UDim2.fromScale(0, 0)
			previewArea.Size = UDim2.new(0.38, -6, 1, 0)
			catalogArea.Position = UDim2.new(0.38, 6, 0, 0)
			catalogArea.Size = UDim2.new(0.62, -6, 1, 0)
			catalogWidth = size.X * 0.62
		else
			previewArea.Position = UDim2.fromScale(0, 0)
			previewArea.Size = UDim2.new(1, 0, 0.36, 0)
			catalogArea.Position = UDim2.new(0, 0, 0.36, 8)
			catalogArea.Size = UDim2.new(1, 0, 0.64, -8)
			catalogWidth = size.X
		end
		grid.setColumns(if catalogWidth >= 760 then 4 elseif catalogWidth >= 520 then 3 else 2)
	end
	layout()
	table.insert(conns, Kit.propChanged(body, "AbsoluteSize", layout))

	-- Live data ---------------------------------------------------------------------------------
	if storeApi and type(storeApi.Changed) == "function" then
		local sig = storeApi:Changed("inventory")
		if sig then
			table.insert(
				conns,
				sig:Connect(function(value: any)
					local before = inv.owned
					inv = readInv(value)
					if closed then
						return
					end
					-- newly owned Life Roll / heirloom pieces add cards; anything else just repaints
					local changed = false
					for id in inv.owned do
						if not before[id] then
							changed = true
						end
					end
					if changed then
						rebuildList()
					else
						refresh()
					end
				end)
			)
		end
	end
	if storeApi and type(storeApi.Changed) == "function" then
		local sig = storeApi:Changed("career")
		if sig then
			table.insert(
				conns,
				sig:Connect(function()
					if closed then
						return
					end
					refresh()
					if api then
						api:GetAccess(true) -- rank and company may have changed; AccessChanged repaints
					end
				end)
			)
		end
	end
	if api and api.AccessChanged then
		table.insert(
			conns,
			api.AccessChanged:Connect(function(newAccess: any)
				if type(newAccess) == "table" then
					access = newAccess
					if not closed then
						rebuildList()
					end
				end
			end)
		)
	end

	rebuildList()

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
			preview.destroy()
			win.close()
		end,
	}
end

return Screen
