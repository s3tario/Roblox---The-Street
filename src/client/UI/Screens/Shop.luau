--!strict
-- Shop screen (UI screen id "Shop", owned by `shop`; spec §11, v3 §5). Opened by ShopController (a `shop` prompt
-- sends { shopId }, the "Shop" menu tab) with optional args { shopId = "tailor", item = "suit_navy_2b" }.
--
-- Layout: the five shops as tabs (Hartwell Tailors, Vanta Watches, Strider Shoes, Galleria Home & Office, Eastbridge
-- Campus Store), a status line (cash, the sale badge during Fashion Week, the dress code: "Your firm requires Level
-- 4. You're Level 3."), the category tabs of the shop, a grid of item cards (rarity strip, "Lv N", price / Owned /
-- Wearing / lock) and the selected item: a live 3D preview (a figure wearing the current look with the piece
-- swapped in, or the decor piece itself; drag to turn) above its details and one action button. Wide screens put
-- the preview and details on the right; narrow ones stack them on top. Buying asks for confirmation and goes
-- through ShopController (ShopService validates everything again).
--
-- ctx (from UIController) = { Registry, Store, UI, close, ... }; every field is optional so the screen also opens
-- under Lune for tests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared.Config.Shop)
local Companies = require(Shared.Config.Companies)
local Format = require(Shared.Util.Format)
local Purchase = require(Shared.Logic.Economy.Purchase)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Parts = script.Parent:WaitForChild("ShopParts")
local View = require(Parts:WaitForChild("View"))
local Cards = require(Parts:WaitForChild("Cards"))
local Detail = require(Parts:WaitForChild("Detail"))
local Preview = require(Parts:WaitForChild("Preview"))

local Screen = { id = "Shop", hideHud = true, View = View }

local STATUS_H = 30
local PREVIEW_SHARE = 0.52

type Data = {
	owned: { [string]: any },
	equipped: { [string]: string },
	decor: { [string]: any },
	cash: number,
	rank: number,
	track: string?,
	companyId: string?,
}

local function readData(storeApi: any): Data
	local function get(key: string): any
		if not storeApi or type(storeApi.Get) ~= "function" then
			return nil
		end
		local ok, v = pcall(storeApi.Get, storeApi, key)
		return if ok then v else nil
	end
	local inv = get("inventory")
	local housing = get("housing")
	local wallet = get("wallet")
	local career = get("career")
	local c = if type(career) == "table" then career else {}
	return {
		owned = if type(inv) == "table" and type(inv.owned) == "table" then inv.owned else {},
		equipped = if type(inv) == "table" and type(inv.equipped) == "table" then inv.equipped else {},
		decor = if type(housing) == "table" and type(housing.owned) == "table" then housing.owned else {},
		cash = if type(wallet) == "table" and type(wallet.cash) == "number" then wallet.cash else 0,
		rank = if type(c.rank) == "number" then c.rank else 0,
		track = if type(c.track) == "string" and c.track ~= "" then c.track else nil,
		companyId = if type(c.companyId) == "string"
				and c.companyId ~= ""
				and c.status ~= "fired"
			then c.companyId
			else nil,
	}
end

-- The local player's skin tone (their character's head) for the preview figure.
local function playerSkin(): (string, Color3?)
	if not Kit.Core.LIVE then
		return "Preview", nil
	end
	local player = game:GetService("Players").LocalPlayer
	if not player then
		return "Preview", nil
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local saved = head:GetAttribute("CareerLookColor")
		return player.Name, if typeof(saved) == "Color3" then saved else head.Color
	end
	return player.Name, nil
end

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

	local function toast(text: string, kind: string?)
		if ui and type(ui.Notify) == "function" then
			ui:Notify(text, kind)
		end
	end

	-- State -----------------------------------------------------------------------------------------
	local data = readData(storeApi)
	local info: any = if api then api:GetInfo() else nil
	if type(info) ~= "table" then
		info = { cash = data.cash, discount = 0, passes = {}, rank = data.rank, student = data.rank <= 0 }
	end
	local shopId = View.defaultShop(a.shopId, info.student == true)
	local tabId: string? = nil
	local selected: string? = nil
	if type(a.item) == "string" then
		local kind, item = Purchase.resolve(a.item)
		if kind and item then
			local shops = Purchase.shopsFor(kind, item)
			if #shops > 0 then
				if not table.find(shops, shopId) then
					shopId = shops[1]
				end
				selected = item.id
				local shop = Shop.get(shopId) :: Shop.ShopDef
				for _, tab in shop.tabs do
					if Purchase.inTab(tab, kind, item) then
						tabId = tab.id
					end
				end
			end
		end
	end

	local function viewer(): View.Viewer
		return {
			owned = data.owned,
			decor = data.decor,
			rank = math.max(data.rank, if type(info.rank) == "number" then info.rank else 0),
			passes = if type(info.passes) == "table" then info.passes else {},
			cash = data.cash,
			track = data.track,
		}
	end

	-- Window and regions ----------------------------------------------------------------------------
	local firstShop = Shop.get(shopId) :: Shop.ShopDef
	local win = Kit.Window({
		title = firstShop.name,
		subtitle = firstShop.tagline,
		onClose = closeScreen,
		name = "ShopWindow",
		maxSize = Vector2.new(1100, 720),
	})
	win.frame.Parent = root

	local shopTabDefs: { View.TabDef } = {}
	for _, id in View.SHOP_ORDER do
		local s = Shop.get(id) :: Shop.ShopDef
		table.insert(shopTabDefs, { id = id, title = s.short, badge = nil })
	end
	-- assigned below (the controls are built before the functions they call)
	local selectShop: (id: string) -> ()
	local rebuildGrid: () -> ()
	local refresh: () -> ()
	local onAction: (entry: View.Entry, state: View.CardState) -> ()

	local shopTabs = Kit.Tabs({
		tabs = shopTabDefs,
		selected = shopId,
		name = "ShopTabs",
		onSelect = function(id: string)
			selectShop(id)
		end,
	})
	shopTabs.frame.Parent = win.content

	local status = Kit.List({ direction = "horizontal", gap = 8, name = "Status" })
	status.frame.Position = UDim2.fromOffset(0, Kit.TAP + 6)
	status.frame.Size = UDim2.new(1, 0, 0, STATUS_H)
	status.frame.AutomaticSize = Enum.AutomaticSize.None
	status.frame.Parent = win.content
	local cashLabel = Kit.Label({ text = "", font = "mono", autoSize = "xy", name = "Cash", layoutOrder = 1 })
	status.add(cashLabel)
	local saleBadge = Kit.Badge({ text = "", color = "good", name = "Sale", layoutOrder = 2 })
	status.add(saleBadge)
	local dressLabel = Kit.Label({
		text = "",
		size = "xs",
		color = "textDim",
		autoSize = "xy",
		name = "Dress",
		layoutOrder = 3,
	})
	dressLabel.frame.TextWrapped = false
	status.add(dressLabel)

	local bodyTop = Kit.TAP + 6 + STATUS_H + 6
	local body = Kit.frame("Body", UDim2.new(1, 0, 1, -bodyTop))
	body.Position = UDim2.fromOffset(0, bodyTop)
	body.Parent = win.content

	local catalogArea = Kit.frame("CatalogArea")
	catalogArea.Parent = body
	local detailArea = Kit.frame("DetailArea")
	detailArea.Parent = body

	local categoryTabs = Kit.Tabs({
		tabs = View.tabsFor(shopId),
		selected = tabId,
		name = "CategoryTabs",
		onSelect = function(id: string)
			tabId = id
			rebuildGrid()
		end,
	})
	categoryTabs.frame.Parent = catalogArea
	tabId = tabId or categoryTabs.getSelected()

	local scroll = Kit.Scroll({ gap = 8, name = "Items" })
	scroll.frame.Position = UDim2.fromOffset(0, Kit.TAP + 8)
	scroll.frame.Size = UDim2.new(1, 0, 1, -(Kit.TAP + 8))
	scroll.frame.Parent = catalogArea
	local grid = Kit.Grid({ columns = 2, cellHeight = 128, gap = 8, name = "Grid" })
	scroll.add(grid)
	local emptyLabel = Kit.Label({ text = Shop.text("empty_tab"), color = "textDim", name = "Empty" })
	scroll.add(emptyLabel)

	local playerName, skin = playerSkin()
	local preview = Preview.new({ name = playerName, skin = skin, hint = Shop.text("preview_hint") })
	preview.frame.Parent = detailArea
	local detail = Detail.build({
		onAction = function(entry: View.Entry, state: View.CardState)
			onAction(entry, state)
		end,
	})
	detail.frame.Parent = detailArea

	-- Behaviour -------------------------------------------------------------------------------------
	local entries: { View.Entry } = {}
	local cards: { [string]: Cards.Card } = {}
	local shownPreview: string? = nil

	local function entryById(id: string?): View.Entry?
		if not id then
			return nil
		end
		for _, e in entries do
			if e.item.id == id then
				return e
			end
		end
		return nil
	end

	local function stateOf(entry: View.Entry): View.CardState
		return View.cardState(entry, viewer(), info.discount, data.equipped)
	end

	local function companyLogo(): string?
		local company = if data.companyId then Companies.get(data.companyId) else nil
		return if company then company.logo else nil
	end

	local function showPreview(entry: View.Entry?)
		local key = if entry
			then entry.item.id .. "|" .. (if entry.kind == "wearable"
				then tostring(data.equipped[entry.item.slot])
				else "")
			else nil
		if key == shownPreview then
			return
		end
		shownPreview = key
		if not entry then
			preview.clear()
		elseif entry.kind == "decor" then
			preview.showDecor(entry.item)
		else
			preview.showWearable(View.previewLook(data.equipped, entry.item), entry.item.slot, companyLogo())
		end
	end

	function refresh()
		if closed then
			return
		end
		cashLabel.setText(Shop.text("cash_label") .. "  " .. Format.money(data.cash))
		local sale = View.saleBadge(info.discount)
		saleBadge.setText(if type(info.saleText) == "string" then info.saleText else sale or "")
		saleBadge.frame.Visible = sale ~= nil
		local dress = View.dressLine({
			firmLevel = info.firmLevel,
			outfitLevel = info.outfitLevel,
			student = info.student == true,
		})
		dressLabel.setText(dress or "")
		dressLabel.frame.Visible = dress ~= nil
		for _, e in entries do
			local card = cards[e.item.id]
			if card then
				card.update(stateOf(e), e.item.id == selected)
			end
		end
		local current = entryById(selected)
		detail.show(current, if current then stateOf(current) else nil, info.firmLevel)
		detail.setBusy(busy)
		showPreview(current)
	end

	local function select(id: string)
		selected = id
		refresh()
	end

	function rebuildGrid()
		grid.clear()
		cards = {}
		entries = View.entries(shopId, tabId)
		if selected and entryById(selected) == nil then
			selected = nil
		end
		if selected == nil and #entries > 0 then
			selected = entries[1].item.id
		end
		for i, e in entries do
			local id = e.item.id
			local card = Cards.item(e, stateOf(e), {
				selected = id == selected,
				onClick = function()
					select(id)
				end,
			})
			card.frame.LayoutOrder = i
			grid.add(card.frame)
			cards[id] = card
		end
		emptyLabel.frame.Visible = #entries == 0
		scroll.scrollToTop()
		refresh()
	end

	function selectShop(id: string)
		local shop = Shop.get(id)
		if not shop then
			return
		end
		shopId = id
		win.setTitle(shop.name)
		win.setSubtitle(shop.tagline)
		local defs = View.tabsFor(id)
		categoryTabs.setTabs(defs)
		tabId = if #defs > 0 then defs[1].id else nil
		if tabId then
			categoryTabs.select(tabId, true)
		end
		selected = nil
		rebuildGrid()
	end

	local function run(fn: () -> ())
		if busy then
			return
		end
		busy = true
		refresh()
		task.spawn(function()
			local ok, err = pcall(function()
				fn()
			end)
			if not ok then
				warn("[Shop] action failed: " .. tostring(err))
			end
			busy = false
			if not closed then
				refresh()
			end
		end)
	end

	local function buy(entry: View.Entry, state: View.CardState)
		if not api then
			toast(View.errorText("shop"), "bad")
			return
		end
		local function go()
			run(function()
				local ok, err = api:Buy(entry.item.id, shopId)
				if closed then
					return
				end
				if not ok then
					toast(View.errorText(err), "bad")
					return
				end
				-- the server's toast confirms the purchase; reflect it at once (Store catches up a moment later)
				-- (copies: the Store's tables are read-only)
				if entry.kind == "decor" then
					data.decor = table.clone(data.decor)
					data.decor[entry.item.id] = true
				else
					data.owned = table.clone(data.owned)
					data.owned[entry.item.id] = true
				end
				data.cash = math.max(0, data.cash - state.price)
			end)
		end
		local confirm: any = if ui and type(ui.Confirm) == "function" then ui else nil
		if not confirm or state.price <= 0 then
			go()
			return
		end
		confirm:Confirm({
			title = Shop.text("buy_confirm_title", { name = entry.item.name }),
			body = Shop.text("buy_confirm_body", {
				price = Format.money(state.price),
				cash = Format.money(math.max(0, data.cash - state.price)),
			}),
			confirmText = Shop.text("buy_confirm_yes"),
		}, function(yes: boolean)
			if yes and not closed then
				go()
			end
		end)
	end

	function onAction(entry: View.Entry, state: View.CardState)
		if state.action == "buy" then
			buy(entry, state)
		elseif state.action == "wear" then
			if not api then
				return
			end
			run(function()
				local ok, err = api:Equip(entry.item.slot, entry.item.id)
				if closed then
					return
				end
				if ok then
					data.equipped = table.clone(data.equipped)
					data.equipped[entry.item.slot] = entry.item.id
					toast(Shop.text("worn"), "good")
				else
					toast(View.errorText(err), "bad")
				end
			end)
		elseif state.action == "place" then
			if api then
				api:OpenHousing(nil)
			end
		elseif state.action == "pass" then
			if api then
				api:OpenStore()
			end
		end
	end

	-- Layout ----------------------------------------------------------------------------------------
	local function layout()
		-- in Offset units (UIScale undone); nil before the first layout pass (and under Lune): assume a wide window
		local size = Kit.Core.unscaledSize(body) or Vector2.new(960, 560)
		local wide = size.X >= 640 and size.X > size.Y * 0.9
		local catalogWidth: number
		if wide then
			catalogArea.Position = UDim2.fromScale(0, 0)
			catalogArea.Size = UDim2.new(0.6, -6, 1, 0)
			detailArea.Position = UDim2.new(0.6, 6, 0, 0)
			detailArea.Size = UDim2.new(0.4, -6, 1, 0)
			preview.frame.Size = UDim2.new(1, 0, PREVIEW_SHARE, -4)
			detail.frame.Position = UDim2.new(0, 0, PREVIEW_SHARE, 4)
			detail.frame.Size = UDim2.new(1, 0, 1 - PREVIEW_SHARE, -4)
			catalogWidth = size.X * 0.6
		else
			-- phones: preview and details side by side on top, the catalogue below
			detailArea.Position = UDim2.fromScale(0, 0)
			detailArea.Size = UDim2.new(1, 0, 0.42, 0)
			catalogArea.Position = UDim2.new(0, 0, 0.42, 8)
			catalogArea.Size = UDim2.new(1, 0, 0.58, -8)
			preview.frame.Size = UDim2.new(0.42, -4, 1, 0)
			detail.frame.Position = UDim2.new(0.42, 4, 0, 0)
			detail.frame.Size = UDim2.new(0.58, -4, 1, 0)
			catalogWidth = size.X
		end
		grid.setColumns(if catalogWidth >= 760 then 4 elseif catalogWidth >= 500 then 3 else 2)
	end
	layout()
	table.insert(conns, Kit.propChanged(body, "AbsoluteSize", layout))

	-- Live data -------------------------------------------------------------------------------------
	local function watchKey(key: string)
		if not storeApi or type(storeApi.Changed) ~= "function" then
			return
		end
		local ok, sig = pcall(storeApi.Changed, storeApi, key)
		if ok and sig then
			table.insert(
				conns,
				sig:Connect(function()
					data = readData(storeApi)
					if not closed then
						refresh()
					end
				end)
			)
		end
	end
	for _, key in { "inventory", "housing", "wallet", "career" } do
		watchKey(key)
	end
	if api and api.InfoChanged then
		table.insert(
			conns,
			api.InfoChanged:Connect(function(newInfo: any)
				if type(newInfo) == "table" then
					info = newInfo
					if not closed then
						refresh()
					end
				end
			end)
		)
	end

	rebuildGrid()

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
