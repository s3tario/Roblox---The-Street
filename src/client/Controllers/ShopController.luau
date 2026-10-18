--!strict
-- ShopController (client, owned by `shop`): opens the Shop and Housing screens and talks to ShopService and
-- HousingService.
--
--   * "Shop.Open" / "Housing.Open" (sent by the server after a `shop` / `housing_panel` prompt is accepted) open the
--     matching screen; "Housing.Changed" tells an open Housing screen to reload.
--   * Menu tabs: "Shop" and "Home" (UIController:RegisterMenuTab).
--   * Prompts, client side: EmployeesOnly shop / housing_panel prompts are hidden for visitors of that office
--     (OfficeController:IsEmployeeOf, else Store career.companyId); a housing_panel that belongs to a desk, office or
--     room (OwnerUserId on its container) only shows for its owner. The server refuses everything else anyway.
--     Streaming-safe: prompts are found through the replicated "Interact" tag as parts stream in.
--
-- API (used by UI/Screens/Shop and UI/Screens/Housing):
--   ShopController:Open(shopId?) / :OpenHousing(context?)
--   ShopController:GetInfo(force?) -> Info        cached Shop.GetInfo answer (refreshed in the background)
--   ShopController:Buy(itemId, shopId?) -> (ok, errKey?, receipt?)
--   ShopController:Equip(slot, itemId) -> (ok, errKey?)      through WardrobeController when it is running
--   ShopController:GetHousing() -> (view?, errKey?)         Housing.Get (yields)
--   ShopController:Place(context, slotId, decorId?) -> (ok, errKey?)
--   ShopController:SetTheme(context, themeId) -> (ok, errKey?)
--   ShopController:OpenStore()                    the Store screen (monetization) when it exists
--   ShopController.InfoChanged : Signal(info)    ShopController.HousingChanged : Signal()

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Shop = require(Shared.Config.Shop)
local Registry = require(script.Parent.Parent.Registry)

local ShopController = {
	Name = "ShopController",
	Priority = 45,
	InfoChanged = Signal.new(),
	HousingChanged = Signal.new(),
}

local SHOP_SCREEN = "Shop"
local HOUSING_SCREEN = "Housing"
local INFO_TTL = 15
local PROMPT_IDS = { shop = true, housing_panel = true }
local CONTAINERS = { "DeskSlot", "OfficeSlot", "UnitSlot" }

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

local info: Info? = nil
local infoAt = -math.huge
local infoInFlight = false

local function store(): any
	return Registry.get("Store")
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

local function ui(): any
	return Registry.get("UIController")
end

-- Best guess from replicated data until the server answers.
local function localInfo(): Info
	local career = storeGet("career")
	local wallet = storeGet("wallet")
	local c = if type(career) == "table" then career else {}
	local status = if type(c.status) == "string" then c.status else "student"
	local player = Players.LocalPlayer
	local level = if player then player:GetAttribute("OutfitLevel") else nil
	return {
		cash = if type(wallet) == "table" and type(wallet.cash) == "number" then wallet.cash else 0,
		discount = 0,
		saleText = nil,
		rank = if type(c.rank) == "number" then c.rank else 0,
		student = status == "student",
		employed = status ~= "student" and status ~= "fired",
		title = if type(c.title) == "string" then c.title else "",
		companyName = if type(c.companyName) == "string" and c.companyName ~= "" then c.companyName else nil,
		firmLevel = nil,
		outfitLevel = if type(level) == "number" then level else 1,
		passes = {},
	}
end

local function sanitizeInfo(raw: any): Info?
	if type(raw) ~= "table" or type(raw.cash) ~= "number" then
		return nil
	end
	local passes: { [string]: boolean } = {}
	if type(raw.passes) == "table" then
		for k, v in raw.passes do
			if type(k) == "string" then
				passes[k] = v == true
			end
		end
	end
	return {
		cash = raw.cash,
		discount = if type(raw.discount) == "number" then raw.discount else 0,
		saleText = if type(raw.saleText) == "string" then raw.saleText else nil,
		rank = if type(raw.rank) == "number" then raw.rank else 0,
		student = raw.student == true,
		employed = raw.employed == true,
		title = if type(raw.title) == "string" then raw.title else "",
		companyName = if type(raw.companyName) == "string" then raw.companyName else nil,
		firmLevel = if type(raw.firmLevel) == "number" then raw.firmLevel else nil,
		outfitLevel = if type(raw.outfitLevel) == "number" then raw.outfitLevel else 1,
		passes = passes,
	}
end

function ShopController:GetInfo(force: boolean?): Info
	local now = os.clock()
	if info and not force and now - infoAt < INFO_TTL then
		return info
	end
	if not infoInFlight then
		infoInFlight = true
		task.spawn(function()
			local ok, result = pcall(Net.invoke, "Shop.GetInfo")
			infoInFlight = false
			local clean = if ok then sanitizeInfo(result) else nil
			if clean then
				info = clean
				infoAt = os.clock()
				ShopController.InfoChanged:Fire(clean)
			end
		end)
	end
	return info or localInfo()
end

-- RemoteFunction results arrive as (ok, err, ...) or (nil, "timeout"/"error"/"rate_limited"/"missing").
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

function ShopController:Buy(itemId: string, shopId: string?): (boolean, string?, any)
	local ok, err, receipt = call("Shop.Buy", itemId, shopId)
	if ok then
		infoAt = -math.huge -- cash changed: ask again next time
		ShopController:GetInfo(true)
	end
	return ok, err, receipt
end

function ShopController:Equip(slot: string, itemId: string): (boolean, string?)
	local wardrobe = Registry.get("WardrobeController")
	if wardrobe and type(wardrobe.Equip) == "function" then
		local ok, a, b = pcall(wardrobe.Equip, wardrobe, slot, itemId)
		if ok then
			return a == true, if type(b) == "string" then b else nil
		end
		return false, "generic"
	end
	local ok, err = call("Wardrobe.Equip", slot, itemId)
	return ok, err
end

function ShopController:GetHousing(): (any, string?)
	local ok, view, err = pcall(Net.invoke, "Housing.Get")
	if not ok then
		return nil, "generic"
	end
	if type(view) ~= "table" then
		return nil, if type(err) == "string" then err else "generic"
	end
	return view, nil
end

function ShopController:Place(ctx: string, slotId: string, decorId: string?): (boolean, string?)
	local ok, err = call("Housing.Place", ctx, slotId, decorId)
	return ok, err
end

function ShopController:SetTheme(ctx: string, themeId: string): (boolean, string?)
	local ok, err = call("Housing.SetTheme", ctx, themeId)
	return ok, err
end

function ShopController:Open(shopId: string?)
	local u = ui()
	if u then
		u:Open(SHOP_SCREEN, { shopId = shopId })
	end
end

function ShopController:OpenHousing(ctx: string?)
	local u = ui()
	if u then
		u:Open(HOUSING_SCREEN, { context = ctx })
	end
end

function ShopController:OpenStore()
	local storeController = Registry.get("StoreController")
	if storeController and type(storeController.Open) == "function" then
		pcall(storeController.Open, storeController)
		return
	end
	local u = ui()
	if u and type(u.GetScreenIds) == "function" then
		local ok, ids = pcall(u.GetScreenIds, u)
		if ok and type(ids) == "table" and table.find(ids, "Store") then
			u:Open("Store")
			return
		end
	end
	if u then
		u:Notify(Shop.text("store_soon"), "info")
	end
end

---------------------------------------------------------------------------------------------------
-- Prompt visibility (the server refuses visitors and non-owners either way)
---------------------------------------------------------------------------------------------------
local prompts: { [ProximityPrompt]: Instance } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Instance]: { RBXScriptConnection } } = {}

local function isEmployeeOf(companyId: any): boolean
	if type(companyId) ~= "string" or companyId == "" then
		return true
	end
	local office = Registry.get("OfficeController")
	if office and type(office.IsEmployeeOf) == "function" then
		local ok, yes = pcall(office.IsEmployeeOf, office, companyId)
		if ok and type(yes) == "boolean" then
			return yes
		end
	end
	local career = storeGet("career")
	return type(career) == "table" and career.companyId == companyId and career.status ~= "fired"
end

local function containerOf(inst: Instance): Instance?
	local node: Instance? = inst
	while node and node ~= workspace and node ~= game do
		for _, name in CONTAINERS do
			if node.Name == name or node:GetAttribute(name) ~= nil or node:HasTag(name) then
				return node
			end
		end
		node = node.Parent
	end
	return nil
end

local hiddenByUs: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function allowedFor(prompt: ProximityPrompt): boolean
	local inst = prompts[prompt]
	if not inst then
		return true
	end
	if prompt:GetAttribute("EmployeesOnly") == true and not isEmployeeOf(prompt:GetAttribute("CompanyId")) then
		return false
	end
	if inst:GetAttribute("InteractId") == "housing_panel" then
		local container = containerOf(inst)
		if container then
			local player = Players.LocalPlayer
			return player ~= nil and container:GetAttribute("OwnerUserId") == player.UserId
		end
	end
	return true
end

-- Only ever re-enables prompts this controller hid (OfficeController hides visitors' prompts the same way).
local function evaluate(prompt: ProximityPrompt)
	if prompt.Parent == nil then
		return
	end
	if not allowedFor(prompt) then
		if prompt.Enabled then
			prompt.Enabled = false
			hiddenByUs[prompt] = true
		end
	elseif hiddenByUs[prompt] then
		hiddenByUs[prompt] = nil
		prompt.Enabled = true
	end
end

local function evaluateAll()
	for prompt in prompts do
		if prompt.Parent then
			evaluate(prompt)
		end
	end
end

local function track(inst: Instance, prompt: Instance, conns: { RBXScriptConnection })
	if not prompt:IsA("ProximityPrompt") or prompts[prompt] then
		return
	end
	if not PROMPT_IDS[prompt:GetAttribute("InteractId") :: any] then
		return
	end
	prompts[prompt] = inst
	table.insert(
		conns,
		prompt:GetAttributeChangedSignal("EmployeesOnly"):Connect(function()
			evaluate(prompt)
		end)
	)
	table.insert(
		conns,
		prompt:GetAttributeChangedSignal("CompanyId"):Connect(function()
			evaluate(prompt)
		end)
	)
	-- something else re-enabled a prompt this player may not use: hide it again once that settles
	table.insert(
		conns,
		prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			if prompt.Enabled and not allowedFor(prompt) then
				task.defer(evaluate, prompt)
			end
		end)
	)
	evaluate(prompt)
end

local function unwatch(inst: Instance)
	local conns = watched[inst]
	if conns then
		watched[inst] = nil
		for _, c in conns do
			c:Disconnect()
		end
	end
end

local function watch(inst: Instance)
	if not PROMPT_IDS[inst:GetAttribute("InteractId") :: any] or watched[inst] then
		return
	end
	local conns: { RBXScriptConnection } = {}
	watched[inst] = conns
	-- the server parents the prompt under the part (or a Model's PrimaryPart); it may replicate a moment later
	table.insert(
		conns,
		inst.DescendantAdded:Connect(function(d: Instance)
			track(inst, d, conns)
		end)
	)
	for _, d in inst:GetDescendants() do
		track(inst, d, conns)
	end
	if inst:GetAttribute("InteractId") == "housing_panel" then
		local container = containerOf(inst)
		if container then
			table.insert(
				conns,
				container:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
					for prompt, owner in prompts do
						if owner == inst then
							evaluate(prompt)
						end
					end
				end)
			)
		end
	end
end

local function startPromptWatch()
	CollectionService:GetInstanceAddedSignal("Interact"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("Interact"):Connect(unwatch)
	for _, inst in CollectionService:GetTagged("Interact") do
		watch(inst)
	end
	local s = store()
	if s then
		pcall(function()
			s:Changed("career"):Connect(function()
				evaluateAll()
				infoAt = -math.huge
			end)
			s:GlobalChanged("events"):Connect(evaluateAll)
			s.Loaded:Connect(evaluateAll)
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function ShopController:Init() end

function ShopController:Start()
	Net.listen("Shop.Open", function(args: any)
		local a = if type(args) == "table" then args else {}
		ShopController:Open(if type(a.shopId) == "string" then a.shopId else nil)
	end)
	Net.listen("Housing.Open", function(args: any)
		local a = if type(args) == "table" then args else {}
		ShopController:OpenHousing(if type(a.context) == "string" then a.context else nil)
	end)
	Net.listen("Housing.Changed", function()
		ShopController.HousingChanged:Fire()
	end)

	local u = ui()
	if u and type(u.RegisterMenuTab) == "function" then
		pcall(function()
			u:RegisterMenuTab({
				id = "shop",
				title = Shop.text("menu_shop"),
				glyph = "🛍",
				order = 40,
				screen = SHOP_SCREEN,
			})
			u:RegisterMenuTab({
				id = "home",
				title = Shop.text("menu_home"),
				glyph = "🏠",
				order = 41,
				screen = HOUSING_SCREEN,
			})
		end)
	end

	startPromptWatch()
end

return ShopController
