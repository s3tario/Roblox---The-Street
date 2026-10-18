--!strict
-- Shop screen view model (PURE: no services, no Instances; unit-tested in tests/shop/view.spec.luau). Every rule
-- comes from Logic/Economy/Purchase, so the screen shows exactly what ShopService will accept.
--
--   View.SHOP_ORDER                               the shop tabs, in Config/Shop order
--   View.defaultShop(requested?, student) -> id   the shop to open on
--   View.tabsFor(shopId) -> { { id, title } }     category tabs of a shop
--   View.entries(shopId, tabId) -> { Entry }      what a tab lists (Purchase.listFor)
--   View.cardState(entry, viewer, discount, equipped?) -> CardState
--   View.rarity(entry) -> { name, color, color2? }   wearables: their rarity; decor: a band by price
--   View.subtitle(entry) -> string                "Hartwell · Rare" or "Desk · Desk spot"
--   View.levelBadge(entry) -> string?             "Lv 3" (wearables only, v3 §5)
--   View.levelNote(entry, firmLevel?) -> (text?, ok?)   "Meets your firm's Level 4" / "Below your firm's Level 4"
--   View.dressLine(info) -> string?               "Your firm requires Level 4. You're Level 3."
--   View.saleBadge(discount) -> string?           "Sale -25%"
--   View.decorFits(item) -> string                View.decorWhere(item) -> string
--   View.previewLook(equipped?, item) -> { [slot] = itemId }   the look on the preview figure
--   View.errorText(err?) -> string
-- viewer = Purchase.Viewer = { owned, decor, rank, passes, cash } plus optional track for rank titles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared.Config.Shop)
local Decor = require(Shared.Config.Decor)
local Catalog = require(Shared.Config.Catalog)
local Rarity = require(Shared.Config.Rarity)
local Tracks = require(Shared.Config.Tracks)
local Format = require(Shared.Util.Format)
local Purchase = require(Shared.Logic.Economy.Purchase)

local View = {}

export type Entry = Purchase.Entry
export type Viewer = Purchase.Viewer & { track: string? }
export type Action = "buy" | "wear" | "place" | "pass" | "none"
export type CardState = {
	state: string, -- wearing | owned | free | buy | rank | pass | roll | heirloom
	badge: string,
	badgeColor: string, -- Theme colour key
	action: Action,
	actionText: string,
	enabled: boolean,
	locked: boolean,
	price: number,
	basePrice: number,
	wasText: string?,
	reason: string?, -- why the action is unavailable
}
export type RarityView = { name: string, color: Color3, color2: Color3? }

View.SHOP_ORDER = table.clone(Shop.ORDER)

function View.defaultShop(requested: any, student: boolean?): string
	if type(requested) == "string" and Shop.get(requested) then
		return requested
	end
	return if student then Shop.DEFAULT_STUDENT else Shop.DEFAULT
end

export type TabDef = { id: string, title: string, badge: string? }

function View.tabsFor(shopId: string): { TabDef }
	local shop = Shop.get(shopId)
	local out: { TabDef } = {}
	if shop then
		for _, tab in shop.tabs do
			table.insert(out, { id = tab.id, title = tab.label, badge = nil })
		end
	end
	return out
end

function View.entries(shopId: string, tabId: string?): { Entry }
	return Purchase.listFor(shopId, tabId)
end

local function rankTitle(track: string?, rank: number?): string
	local ok, def = pcall(Tracks.rankDef, track or "ib", rank)
	if ok and type(def) == "table" and type(def.title) == "string" then
		return def.title
	end
	return Shop.text("requires_rank_n", { rank = rank or 0 })
end

function View.cardState(entry: Entry, viewer: Viewer, discount: number?, equipped: { [string]: string }?): CardState
	local item = entry.item
	local kind = entry.kind
	local d = Purchase.discount(discount)
	local base = if type(item.price) == "number" and item.price > 0 then math.floor(item.price + 0.5) else 0
	local price = Purchase.price(base, d)
	local state = Purchase.state(kind, item, viewer)
	local out: CardState = {
		state = state,
		badge = "",
		badgeColor = "surface",
		action = "none",
		actionText = "",
		enabled = false,
		locked = false,
		price = price,
		basePrice = base,
		wasText = nil,
		reason = nil,
	}
	if kind == "wearable" and equipped and equipped[item.slot] == item.id then
		out.state = "wearing"
		out.badge = Shop.text("wearing")
		out.badgeColor = "good"
		return out
	end
	if state == "owned" then
		out.badge = Shop.text("owned")
		out.action = if kind == "decor" then "place" else "wear"
		out.actionText = if kind == "decor" then Shop.text("place_now") else Shop.text("wear_now")
		out.enabled = true
		return out
	end
	if state == "pass" then
		out.badge = Shop.passName(item.pass)
		out.badgeColor = "accent"
		out.action = "pass"
		out.actionText = Shop.text("open_store")
		out.enabled = true
		out.locked = true
		out.reason = Shop.text("pass_hint", { pass = Shop.passName(item.pass) })
		return out
	end
	if state == "rank" then
		local title = rankTitle(viewer.track, item.minRank)
		out.badge = Shop.text("requires_rank", { title = title })
		out.badgeColor = "warn"
		out.locked = true
		out.actionText = Shop.text("requires_rank", { title = title })
		out.reason = Shop.errorText("rank")
		return out
	end
	if state == "roll" or state == "heirloom" then
		out.badge = Shop.errorText(state)
		out.locked = true
		out.reason = Shop.errorText(state)
		return out
	end
	-- buy / free
	out.action = "buy"
	if price <= 0 then
		out.badge = Shop.text("free")
		out.badgeColor = "good"
		out.actionText = Shop.text("free")
		out.enabled = true
		return out
	end
	out.badge = Format.money(price)
	if d > 0 and price < base then
		out.wasText = Shop.text("price_was", { price = Format.money(base) })
	end
	local cash = viewer.cash
	local have = if type(cash) == "number" and cash == cash then cash else 0
	if have >= price then
		out.badgeColor = "accent"
		out.actionText = Shop.text("buy_price", { price = Format.money(price) })
		out.enabled = true
	else
		out.badgeColor = "bad"
		out.actionText = Shop.text("buy_short", { missing = Format.money(price - have) })
		out.reason = Shop.errorText("funds")
	end
	return out
end

-- Decor has no rarity: its price band borrows the rarity colours (common up to mythic) so the grid reads the same.
local DECOR_BANDS = { 500, 3000, 10000, 30000, 100000 }

function View.rarity(entry: Entry): RarityView
	local id: string
	if entry.kind == "wearable" then
		id = if type(entry.item.rarity) == "string" then entry.item.rarity else "common"
	else
		local band = 1
		for i, limit in DECOR_BANDS do
			if entry.item.price >= limit then
				band = i + 1
			end
		end
		id = Rarity.ids[math.clamp(band, 1, #Rarity.ids)]
	end
	local def = Rarity.get(id) or Rarity.get("common")
	local d = def :: Rarity.RarityDef
	return { name = d.name, color = d.color, color2 = d.color2 }
end

function View.subtitle(entry: Entry): string
	local item = entry.item
	if entry.kind == "wearable" then
		local brand = Catalog.brand(item.brand)
		return (if brand then brand.name else tostring(item.brand)) .. " · " .. View.rarity(entry).name
	end
	local category = ""
	for _, c in Decor.CATEGORIES do
		if c.id == item.category then
			category = c.label
		end
	end
	local kinds: { string } = {}
	for _, k in item.slots do
		table.insert(kinds, Decor.KIND_LABELS[k] or k)
	end
	return category .. " · " .. table.concat(kinds, ", ")
end

function View.levelBadge(entry: Entry): string?
	local level = Purchase.levelOf(entry.kind, entry.item)
	return if level then Shop.text("level_badge", { level = level }) else nil
end

function View.levelNote(entry: Entry, firmLevel: number?): (string?, boolean?)
	local level = Purchase.levelOf(entry.kind, entry.item)
	if not level or type(firmLevel) ~= "number" then
		return nil, nil
	end
	local firm = math.clamp(math.floor(firmLevel), 1, 5)
	if level >= firm then
		return Shop.text("level_meets", { level = firm }), true
	end
	return Shop.text("level_below", { level = firm }), false
end

export type Info = {
	firmLevel: number?,
	outfitLevel: number?,
	student: boolean?,
}

function View.dressLine(info: Info?): string?
	if not info then
		return nil
	end
	local key, vars = Purchase.levelHint(info.firmLevel, info.outfitLevel, info.student)
	return if key then Shop.text(key, vars) else nil
end

function View.saleBadge(discount: number?): string?
	if type(discount) ~= "number" or discount <= 0 then
		return nil
	end
	return Shop.text("sale_badge", { pct = math.floor(discount * 100 + 0.5) })
end

function View.decorFits(item: Decor.Item): string
	local kinds: { string } = {}
	for _, k in item.slots do
		table.insert(kinds, Decor.KIND_LABELS[k] or k)
		if k == "plant" or k == "lamp" then
			table.insert(kinds, Decor.KIND_LABELS.floor)
		end
	end
	return Shop.text("decor_fits", { kinds = table.concat(kinds, ", ") })
end

function View.decorWhere(item: Decor.Item): string
	if item.contexts == nil then
		return Shop.text("decor_everywhere")
	end
	local labels: { string } = {}
	for _, ctx in Decor.CONTEXT_ORDER do
		if table.find(item.contexts, ctx) then
			table.insert(labels, Decor.CONTEXTS[ctx].label)
		end
	end
	return Shop.text("decor_where", { contexts = table.concat(labels, ", ") })
end

function View.previewLook(equipped: { [string]: string }?, item: any): { [string]: string }
	local look: { [string]: string } = if equipped then table.clone(equipped) else {}
	if type(item) == "table" and type(item.slot) == "string" and type(item.id) == "string" then
		look[item.slot] = item.id
	end
	return look
end

function View.errorText(err: string?): string
	return Shop.errorText(err)
end

return View
