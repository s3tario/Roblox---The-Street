--!strict
-- Economy/Purchase: what an item costs and whether a player may buy it (PURE: no services, no clocks, no Instances;
-- unit-tested in tests/shop). ShopService runs Purchase.quote before it takes any cash; the Shop screen runs the
-- same rules on replicated data to show prices, badges and the reason a Buy button is disabled.
--
--   Purchase.resolve(itemId) -> (kind?, item?)        "wearable" (Config/Catalog, renamed ids resolved) or "decor"
--   Purchase.discount(raw) -> fraction                 EventService:GetModifier("shopDiscount") sanitized (see below)
--   Purchase.price(base, discount) -> whole dollars    a positive base price never drops below $1
--   Purchase.shopSells(shop, kind, item) -> boolean    Config/Shop rules (wearables) or the decor shop
--   Purchase.shopsFor(kind, item) -> { shopId }        every shop selling it, in Shop.ORDER
--   Purchase.inTab(tab, kind, item) -> boolean         the shop screen tab the item is listed under
--   Purchase.listFor(shopId, tabId?) -> { Entry }      the stock of a shop (tab), in display order
--   Purchase.state(kind, item, viewer) -> state        "owned" | "free" | "buy" | "rank" | "pass" | "roll" | "heirloom"
--   Purchase.quote(itemId, shopId?, viewer, discount) -> Quote
--       err (first failing rule): unknown_item, not_for_sale, roll, heirloom, bad_shop, owned, pass, rank, funds
--   Purchase.levelOf(kind, item) -> number?            clothing level 1..5 (v3 §5; nil for decor)
--   Purchase.levelHint(firmLevel?, current, student) -> (key, vars)   the dress-code line of the shop screen
--
-- viewer = { owned = { [itemId] = true }, decor = { [decorId] = true }, rank = number, passes = { [passKey] = true },
--            cash = number }
-- Discount: the fraction taken off (Fashion Week = 0.25). A value in (0, maxDiscount] is used as the fraction; a
-- value in (maxDiscount, 1) is read as a price multiplier (0.75 = 25% off); 0, 1 and anything else mean no sale.
-- The result is capped at Shop.economy.maxDiscount.

local Config = script.Parent.Parent.Parent.Config
local Shop = require(Config.Shop)
local Decor = require(Config.Decor)
local Catalog = require(Config.Catalog)

export type Kind = string -- "wearable" | "decor"
export type Viewer = {
	owned: { [string]: any }?,
	decor: { [string]: any }?,
	rank: number?,
	passes: { [string]: any }?,
	cash: number?,
}
export type Quote = {
	ok: boolean,
	err: string?,
	kind: Kind?,
	item: any,
	itemId: string?,
	name: string?,
	shopId: string?,
	basePrice: number,
	price: number,
	discount: number,
	state: string?,
	level: number?,
}
export type Entry = { kind: Kind, item: any }

local Purchase = {}

local E = Shop.economy

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function rankOf(viewer: Viewer): number
	local r = viewer.rank
	return if finite(r) then r :: number else 0
end

function Purchase.resolve(itemId: any): (Kind?, any)
	if type(itemId) ~= "string" or itemId == "" or #itemId > 64 then
		return nil, nil
	end
	local wearable = Catalog.get(Catalog.canonical(itemId))
	if wearable and not wearable.hidden then
		return "wearable", wearable
	end
	local decor = Decor.get(itemId)
	if decor then
		return "decor", decor
	end
	return nil, nil
end

function Purchase.discount(raw: any): number
	if not finite(raw) or raw <= 0 or raw >= 1 then
		return 0
	end
	local d = if raw <= E.maxDiscount then raw else 1 - raw
	return math.clamp(d, 0, E.maxDiscount)
end

function Purchase.price(base: any, discount: number?): number
	if not finite(base) or base <= 0 then
		return 0
	end
	local d = math.clamp(if finite(discount) then discount :: number else 0, 0, E.maxDiscount)
	return math.max(1, math.floor(base * (1 - d) + 0.5))
end

local function ruleMatches(rule: Shop.Rule, item: any): boolean
	if rule.category ~= item.category then
		return false
	end
	local slots = rule.slots
	return slots == nil or table.find(slots, item.slot) ~= nil
end

function Purchase.shopSells(shop: Shop.ShopDef?, kind: Kind?, item: any): boolean
	if shop == nil or kind == nil or type(item) ~= "table" then
		return false
	end
	if kind == "decor" then
		return shop.kind == "decor"
	end
	if shop.kind ~= "wearable" or not Catalog.isShopItem(item) then
		return false
	end
	local rules: { Shop.Rule } = shop.rules or {}
	for _, rule in rules do
		if ruleMatches(rule, item) then
			return true
		end
	end
	return false
end

function Purchase.shopsFor(kind: Kind?, item: any): { string }
	local out: { string } = {}
	for _, id in Shop.ORDER do
		if Purchase.shopSells(Shop.get(id), kind, item) then
			table.insert(out, id)
		end
	end
	return out
end

function Purchase.inTab(tab: Shop.Tab, kind: Kind, item: any): boolean
	if kind == "decor" then
		local cats = tab.categories
		return cats ~= nil and table.find(cats, item.category) ~= nil
	end
	local slots = tab.slots
	return slots ~= nil and table.find(slots, item.slot) ~= nil
end

local function wearableOrder(a: Catalog.Item, b: Catalog.Item): boolean
	if a.tier ~= b.tier then
		return a.tier < b.tier
	end
	if a.price ~= b.price then
		return a.price < b.price
	end
	return a.id < b.id
end

-- Stock of a shop (optionally one tab). Wearables sort by level then price; decor keeps the catalogue order.
function Purchase.listFor(shopId: string, tabId: string?): { Entry }
	local shop = Shop.get(shopId)
	if not shop then
		return {}
	end
	local tab: Shop.Tab? = nil
	if tabId then
		for _, t in shop.tabs do
			if t.id == tabId then
				tab = t
			end
		end
		if tab == nil then
			return {}
		end
	end
	local out: { Entry } = {}
	if shop.kind == "decor" then
		for _, it in Decor.list() do
			if tab == nil or Purchase.inTab(tab, "decor", it) then
				table.insert(out, { kind = "decor", item = it })
			end
		end
		return out
	end
	local list: { Catalog.Item } = {}
	for _, it in Catalog.shopItems() do
		if Purchase.shopSells(shop, "wearable", it) and (tab == nil or Purchase.inTab(tab, "wearable", it)) then
			table.insert(list, it)
		end
	end
	table.sort(list, wearableOrder)
	for _, it in list do
		table.insert(out, { kind = "wearable", item = it })
	end
	return out
end

function Purchase.state(kind: Kind, item: any, viewer: Viewer): string
	if kind == "wearable" then
		return Catalog.access(item, {
			owned = viewer.owned or {},
			rank = rankOf(viewer),
			passes = viewer.passes or {},
		})
	end
	local owned = viewer.decor or {}
	if owned[item.id] then
		return "owned"
	end
	if item.currency == "pass" then
		local passes = viewer.passes or {}
		if item.pass and passes[item.pass] then
			return "owned"
		end
		return "pass"
	end
	if item.minRank and rankOf(viewer) < item.minRank then
		return "rank"
	end
	if not finite(item.price) or item.price <= 0 then
		return "free"
	end
	return "buy"
end

function Purchase.levelOf(kind: Kind?, item: any): number?
	if kind ~= "wearable" or type(item) ~= "table" then
		return nil
	end
	return Catalog.levelOf(item)
end

local function fail(q: Quote, err: string): Quote
	q.ok = false
	q.err = err
	return q
end

function Purchase.quote(itemId: any, shopId: any, viewer: Viewer, discount: number?): Quote
	local d = math.clamp(if finite(discount) then discount :: number else 0, 0, E.maxDiscount)
	local q: Quote = { ok = false, basePrice = 0, price = 0, discount = d }
	local kind, item = Purchase.resolve(itemId)
	if kind == nil or item == nil then
		return fail(q, "unknown_item")
	end
	q.kind = kind
	q.item = item
	q.itemId = item.id
	q.name = item.name
	q.level = Purchase.levelOf(kind, item)
	if kind == "wearable" then
		if Catalog.isExclusive(item) then
			return fail(q, item.currency)
		end
		if not Catalog.isShopItem(item) then
			return fail(q, "not_for_sale")
		end
	end
	local shops = Purchase.shopsFor(kind, item)
	if #shops == 0 then
		return fail(q, "not_for_sale")
	end
	if shopId ~= nil then
		if type(shopId) ~= "string" or table.find(shops, shopId) == nil then
			return fail(q, "bad_shop")
		end
		q.shopId = shopId
	else
		q.shopId = shops[1]
	end
	q.basePrice = if finite(item.price) and item.price > 0 then math.floor(item.price + 0.5) else 0
	q.price = Purchase.price(q.basePrice, d)
	local state = Purchase.state(kind, item, viewer)
	q.state = state
	if state == "owned" then
		return fail(q, "owned")
	elseif state == "pass" then
		return fail(q, "pass")
	elseif state == "rank" then
		return fail(q, "rank")
	elseif state ~= "buy" and state ~= "free" then
		return fail(q, state)
	end
	local cash = viewer.cash
	local have = if finite(cash) then cash :: number else 0
	if q.price > have then
		return fail(q, "funds")
	end
	q.ok = true
	return q
end

-- The dress-code line shown on the shop screen (v3 §5). firmLevel = the player's company minOutfitLevel (nil when
-- not employed); current = their Outfit Level; students see the Street's usual bar instead.
function Purchase.levelHint(firmLevel: number?, current: number?, student: boolean?): (string?, { [string]: any })
	local cur = if finite(current) then math.clamp(math.floor(current :: number), 1, 5) else 1
	if finite(firmLevel) then
		local lvl = math.clamp(math.floor(firmLevel :: number), 1, 5)
		if cur >= lvl then
			return "dress_firm_ok", { level = lvl, current = cur }
		end
		return "dress_firm_short", { level = lvl, current = cur }
	end
	if student then
		return "dress_student", { level = Shop.STUDENT_TARGET_LEVEL, current = cur }
	end
	return nil, {}
end

return Purchase
