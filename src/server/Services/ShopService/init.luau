--!strict
-- ShopService (server, owned by `shop`; contracts §7, spec §11, v3 §5): the cash shops.
--   tailor (Hartwell Tailors), watch (Vanta Watches & Eyewear), shoes (Strider Shoes & Leather), decor (Galleria Home &
--   Office) and campus_store (Eastbridge Campus Store); stock and rules in Config/Shop, Config/Catalog and
--   Config/Decor, validation in Logic/Economy/Purchase. Wearables are delivered through WardrobeService:Grant, decor
--   goes into data.housing.owned (placed later through HousingService).
--
-- A purchase: the save must be loaded -> one purchase per player at a time -> Purchase.quote (rank, pass, owned,
-- afford, the EventService "shopDiscount" sale) -> EconomyService:SpendCash -> grant. If the grant fails the cash is
-- refunded exactly. Every purchase is audited; big ones ask DataService for an early save.
--
-- API:
--   ShopService:GrantItem(player, itemId, source) -> boolean   wearable or decor (idempotent; true when owned after)
--   ShopService:Buy(player, itemId, shopId?) -> (ok, errKey?, receipt?)   receipt = { itemId, kind, price, cash }
--   ShopService:GetInfo(player) -> Info     what the Shop screen shows (cash, sale, dress code, rank, passes)
--   ShopService:GetDiscount() -> fraction   ShopService:OwnsDecor(player, decorId) -> boolean
--   ShopService:OpenFor(player, args?)      opens the Shop screen on that client ({ shopId? })
--   ShopService.Purchased : Signal(player, receipt)
-- Remotes (validated with Guard):
--   "Shop.Buy"(itemId, shopId?) -> (ok, errKey?, receipt?)   errKey = a Config/Shop "err_" suffix (the Wardrobe
--                                                             screen reads the same keys from Config/Catalog)
--   "Shop.GetInfo"() -> Info
--   "Shop.Open"(args) server -> client (after a `shop` prompt)
-- Interact: `shop` (attribute Shop = shop id); inside office instances only employees may use it.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)
local Shop = require(Shared.Config.Shop)
local Decor = require(Shared.Config.Decor)
local Catalog = require(Shared.Config.Catalog)
local Purchase = require(Shared.Logic.Economy.Purchase)
local Housing = require(Shared.Logic.Economy.Housing)
local Deps = require(script.Deps)
local Prompts = require(script.Prompts)

local ShopService = {
	Name = "ShopService",
	Purchased = Signal.new(), -- (player, receipt)
}

ShopService.Prompts = Prompts
ShopService.Deps = Deps

local OPEN_REMOTE = "Shop.Open"
local OPEN_COOLDOWN = 0.5
local PASS_CACHE_SEC = 30
local PASS_KEYS = { "CornerOffice", "ExecutiveClub", "OfficeThemes" }

export type Receipt = { itemId: string, kind: string, price: number, cash: number, shopId: string? }
export type Info = {
	cash: number,
	discount: number,
	saleText: string?,
	rank: number,
	student: boolean,
	employed: boolean,
	title: string,
	companyName: string?,
	firmLevel: number?,
	outfitLevel: number,
	passes: { [string]: boolean },
}

type PlayerState = { busy: boolean, lastOpen: number, passes: { [string]: boolean }?, passesAt: number }

local states: { [Player]: PlayerState } = {}

local function stateOf(player: Player): PlayerState?
	if player.Parent ~= Players then
		return nil
	end
	local ps = states[player]
	if not ps then
		ps = { busy = false, lastOpen = 0, passes = nil, passesAt = -math.huge }
		states[player] = ps
	end
	return ps
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
-- Pass ownership (MonetizationService:OwnsPass may yield; cached briefly).
local function passesOf(player: Player, fresh: boolean?): { [string]: boolean }
	local ps = states[player]
	if ps and ps.passes and not fresh and os.clock() - ps.passesAt < PASS_CACHE_SEC then
		return ps.passes
	end
	local out: { [string]: boolean } = {}
	for _, key in PASS_KEYS do
		out[key] = Deps.ownsPass(player, key)
	end
	local live = states[player]
	if live then
		live.passes = out
		live.passesAt = os.clock()
	end
	return out
end

-- Saved pass flags only (never yields): used inside the purchase critical section.
local function savedPasses(player: Player): { [string]: boolean }
	local ps = states[player]
	if ps and ps.passes then
		return ps.passes
	end
	local out: { [string]: boolean } = {}
	for _, key in PASS_KEYS do
		out[key] = Deps.savedPass(player, key)
	end
	return out
end

-- data.housing, repaired once per save table (HousingService does the same with its own cache).
local repaired: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function housingOf(data: { [string]: any }): Housing.HousingData
	local raw = data.housing
	if type(raw) == "table" and repaired[raw] then
		return raw :: Housing.HousingData
	end
	local h = Housing.normalize(raw)
	data.housing = h
	repaired[h] = true
	return h
end

local function inventoryOwned(data: { [string]: any }): { [string]: any }
	local inv = data.inventory
	local owned = if type(inv) == "table" then inv.owned else nil
	return if type(owned) == "table" then owned else {}
end

local function walletCash(data: { [string]: any }): number
	local w = data.wallet
	local c = if type(w) == "table" then w.cash else nil
	return if type(c) == "number" and c == c then c else 0
end

function ShopService:GetDiscount(): number
	return Purchase.discount(Deps.modifier("shopDiscount"))
end

local function saleText(discount: number): string?
	if discount <= 0 then
		return nil
	end
	local pct = math.floor(discount * 100 + 0.5)
	if Deps.eventActive("fashion_week") then
		return Shop.text("sale_hint", { event = Shop.text("sale_event"), pct = pct })
	end
	return Shop.text("sale_generic", { pct = pct })
end

local function viewerFor(player: Player, data: { [string]: any }): Purchase.Viewer
	local career = Deps.career(player)
	local cashNow = walletCash(data)
	local okCash, cash = Deps.call("EconomyService", "GetCash", player)
	if okCash and type(cash) == "number" then
		cashNow = cash
	end
	return {
		owned = inventoryOwned(data),
		decor = housingOf(data).owned,
		rank = career.rank,
		passes = savedPasses(player),
		cash = cashNow,
	}
end

---------------------------------------------------------------------------------------------------
-- Granting
---------------------------------------------------------------------------------------------------
function ShopService:OwnsDecor(player: Player, decorId: string): boolean
	local data = Deps.data(player)
	if not data then
		return false
	end
	return housingOf(data).owned[decorId] == true
end

local function grantDecor(player: Player, item: Decor.Item, source: string): boolean
	local data = Deps.data(player)
	if not data then
		return false
	end
	local h = housingOf(data)
	if h.owned[item.id] then
		return true
	end
	h.owned[item.id] = true
	Deps.replicate(player, "housing")
	Deps.audit(player, "decor_grant", { item = item.id, source = source })
	return true
end

function ShopService:GrantItem(player: Player, itemId: string, source: string?): boolean
	local kind, item = Purchase.resolve(itemId)
	local src = if type(source) == "string" and source ~= "" then string.sub(source, 1, 40) else "unknown"
	if kind == "decor" then
		return grantDecor(player, item :: Decor.Item, src)
	elseif kind == "wearable" then
		local ok, granted = Deps.call("WardrobeService", "Grant", player, item.id, src, { notify = false })
		return ok and granted == true
	end
	-- hidden or exclusive wearables are still the wardrobe's to grant (Life Roll pieces, heirlooms)
	local wearable = if type(itemId) == "string" then Catalog.get(Catalog.canonical(itemId)) else nil
	if wearable then
		local ok, granted = Deps.call("WardrobeService", "Grant", player, wearable.id, src, { notify = false })
		return ok and granted == true
	end
	return false
end

---------------------------------------------------------------------------------------------------
-- Buying
---------------------------------------------------------------------------------------------------
function ShopService:Buy(player: Player, itemId: string, shopId: string?): (boolean, string?, Receipt?)
	local ps = stateOf(player)
	local data = Deps.data(player)
	if not ps or not data then
		return false, "not_loaded", nil
	end
	if ps.busy then
		return false, "busy", nil
	end
	ps.busy = true
	local fine, ok, err, receipt = pcall(function(): (boolean, string?, Receipt?)
		local discount = ShopService:GetDiscount()
		local q = Purchase.quote(itemId, shopId, viewerFor(player, data), discount)
		if not q.ok then
			return false, q.err, nil
		end
		local item = q.item
		local kind = q.kind :: string
		local reason = "shop:" .. item.id
		if q.price > 0 then
			local okSpend, spent = Deps.call("EconomyService", "SpendCash", player, q.price, reason)
			if not okSpend then
				return false, "shop", nil
			end
			if spent ~= true then
				return false, "funds", nil
			end
		end
		local granted = ShopService:GrantItem(player, item.id, "shop")
		if not granted then
			if q.price > 0 then
				Deps.call("EconomyService", "AddCash", player, q.price, "refund:" .. item.id, "refund")
			end
			Deps.audit(player, "shop_refund", { item = item.id, price = q.price })
			return false, "grant", nil
		end
		local okCash, cashAfter = Deps.call("EconomyService", "GetCash", player)
		local r: Receipt = {
			itemId = item.id,
			kind = kind,
			price = q.price,
			cash = if okCash and type(cashAfter) == "number" then cashAfter else 0,
			shopId = q.shopId,
		}
		Deps.audit(player, "shop_buy", {
			item = item.id,
			kind = kind,
			price = q.price,
			base = q.basePrice,
			discount = q.discount,
			shop = q.shopId or "",
		})
		local text = if kind == "decor"
			then Shop.text("bought_decor", { name = item.name })
			else Shop.text("bought", { name = item.name, price = Format.money(q.price) })
		Deps.notify(player, text, "cash")
		ShopService.Purchased:Fire(player, table.clone(r))
		return true, nil, r
	end)
	ps.busy = false
	if not fine then
		warn(("[ShopService] Buy(%s, %s) failed: %s"):format(player.Name, tostring(itemId), tostring(ok)))
		return false, "shop", nil
	end
	return ok == true, err, receipt
end

---------------------------------------------------------------------------------------------------
-- Info for the Shop screen
---------------------------------------------------------------------------------------------------
function ShopService:GetInfo(player: Player): Info
	local data = Deps.data(player)
	local career = Deps.career(player)
	local discount = ShopService:GetDiscount()
	local okCash, cash = Deps.call("EconomyService", "GetCash", player)
	return {
		cash = if okCash and type(cash) == "number" then cash elseif data then walletCash(data) else 0,
		discount = discount,
		saleText = saleText(discount),
		rank = career.rank,
		student = career.student,
		employed = career.employed,
		title = career.title,
		companyName = career.companyName,
		firmLevel = career.minOutfitLevel,
		outfitLevel = Deps.outfitLevel(player),
		passes = passesOf(player),
	}
end

function ShopService:OpenFor(player: Player, args: { [string]: any }?)
	if player.Parent == Players then
		Net.fire(OPEN_REMOTE, player, args or {})
	end
end

---------------------------------------------------------------------------------------------------
-- Prompts
---------------------------------------------------------------------------------------------------
local function shopIdOf(inst: Instance): string?
	local id = inst:GetAttribute("Shop")
	return if type(id) == "string" and Shop.get(id) then id else nil
end

local function onShopPrompt(player: Player, inst: Instance, _prompt: ProximityPrompt, companyId: string?)
	local ps = stateOf(player)
	if not ps then
		return
	end
	local now = os.clock()
	if now - ps.lastOpen < OPEN_COOLDOWN then
		return
	end
	ps.lastOpen = now
	if companyId and not Deps.isEmployeeOf(player, companyId) then
		Deps.notify(player, Shop.text("employees_only"), "warn")
		return
	end
	local shopId = shopIdOf(inst)
	if not shopId then
		shopId = if Deps.career(player).student then Shop.DEFAULT_STUDENT else Shop.DEFAULT
	end
	ShopService:OpenFor(player, { shopId = shopId, source = "prompt" })
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function ShopService:Init()
	Net.declare(OPEN_REMOTE)

	Net.handle("Shop.Buy", function(player: Player, itemId: any, shopId: any): (boolean, string?, Receipt?)
		local id = Guard.id(itemId)
		if not id then
			return false, "unknown_item", nil
		end
		local shop: string? = nil
		if shopId ~= nil then
			shop = Guard.id(shopId)
			if not shop or not Shop.get(shop) then
				return false, "bad_shop", nil
			end
		end
		return ShopService:Buy(player, id, shop)
	end, { rate = 3, burst = 6 })

	Net.handle("Shop.GetInfo", function(player: Player): Info
		return ShopService:GetInfo(player)
	end, { rate = 2, burst = 6 })
end

function ShopService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)
	Prompts.watch({
		interactId = "shop",
		promptName = "ShopPrompt",
		actionText = Shop.text("prompt_shop"),
		objectText = function(inst: Instance): string?
			local shop = Shop.get(shopIdOf(inst))
			return if shop then shop.name else nil
		end,
		onTriggered = onShopPrompt,
	})
end

return ShopService
