--!strict
-- WardrobeController (client, owned by `wardrobe`): opens the Wardrobe screen and talks to WardrobeService.
--
-- Interact wiring (the pattern other features follow):
--   1. The server (WardrobeService/Prompts) creates a ProximityPrompt with attribute InteractId = "wardrobe" on every
--      "Interact"-tagged wardrobe point. Inside an office instance it also sets CompanyId and EmployeesOnly = true.
--   2. When a prompt fires, the SERVER decides: employees (or anyone, outside offices) get "Wardrobe.Open", which
--      opens the screen here; visitors get a polite "Employees only" toast instead.
--   3. This controller hides EmployeesOnly wardrobe prompts locally for visitors (Store `career.companyId`, plus a
--      Merger Mania pairing in the global `events`), re-checked whenever career or events change. Streaming-safe:
--      prompts are found through the replicated "Interact" tag as parts stream in, and dropped when they stream out.
-- It also adds the "Wardrobe" menu tab.
--
-- API (used by UI/Screens/Wardrobe):
--   WardrobeController:Open(args?)                       UIController:Open("Wardrobe", args)
--   WardrobeController:GetAccess(force?) -> Access       cached server answer (falls back to Store data)
--       Access = { rank, passes = { [passKey] = boolean }, companyLogo: string?, outfitLevel: number? }
--   WardrobeController:Equip(slot, itemId?) -> ok, errKey?
--   WardrobeController:SavePreset(index, name?) -> ok, errKey?
--   WardrobeController:LoadPreset(index) -> ok, errKey?, droppedCount?
--   WardrobeController:SetWearAvatar(on) -> ok, errKey?
--   WardrobeController:Buy(itemId) -> ok, errKey?        Net.invoke("Shop.Buy", itemId); "shop_closed" when the
--                                                        shop feature isn't running
--   WardrobeController.AccessChanged : Signal(access)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Catalog = require(Shared.Config.Catalog)
local Registry = require(script.Parent.Parent.Registry)
local View = require(
	script.Parent.Parent:WaitForChild("UI"):WaitForChild("Screens"):WaitForChild("Wardrobe"):WaitForChild("View")
)

local WardrobeController = { Name = "WardrobeController" }

WardrobeController.AccessChanged = Signal.new()

local INTERACT_ID = "wardrobe"
local PROMPT_NAME = "WardrobePrompt"
local SCREEN_ID = "Wardrobe"
local ACCESS_TTL = 20

export type Access = {
	rank: number,
	passes: { [string]: boolean },
	companyLogo: string?,
	outfitLevel: number?,
}

local access: Access? = nil
local accessAt = -math.huge
local accessInFlight = false

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

-- Best guess from replicated data until the server answers.
local function localAccess(): Access
	local rank = 0
	local passes: { [string]: boolean } = {}
	local career = storeGet("career")
	if type(career) == "table" and type(career.rank) == "number" then
		rank = career.rank
	end
	local ent = storeGet("entitlements")
	local saved = if type(ent) == "table" then ent.passes else nil
	if type(saved) == "table" then
		for passKey in Catalog.PASSES do
			passes[passKey] = saved[passKey] == true or table.find(saved, passKey) ~= nil
		end
	end
	return { rank = rank, passes = passes, companyLogo = nil, outfitLevel = nil }
end

function WardrobeController:GetAccess(force: boolean?): Access
	local now = os.clock()
	if access and not force and now - accessAt < ACCESS_TTL then
		return access
	end
	if not accessInFlight then
		accessInFlight = true
		task.spawn(function()
			local ok, result = pcall(function()
				return Net.invoke("Wardrobe.GetAccess")
			end)
			accessInFlight = false
			if ok and type(result) == "table" and type(result.rank) == "number" and type(result.passes) == "table" then
				local passes: { [string]: boolean } = {}
				for passKey in Catalog.PASSES do
					passes[passKey] = result.passes[passKey] == true
				end
				local logo = result.companyLogo
				local level = result.outfitLevel
				access = {
					rank = result.rank,
					passes = passes,
					companyLogo = if type(logo) == "string" and logo ~= "" then logo else nil,
					outfitLevel = if type(level) == "number" then level else nil,
				}
				accessAt = os.clock()
				WardrobeController.AccessChanged:Fire(access)
			end
		end)
	end
	return access or localAccess()
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

function WardrobeController:Equip(slot: string, itemId: string?): (boolean, string?)
	local ok, err = call("Wardrobe.Equip", slot, itemId)
	return ok, err
end

function WardrobeController:SavePreset(index: number, name: string?): (boolean, string?)
	local ok, err = call("Wardrobe.SavePreset", index, name)
	return ok, err
end

function WardrobeController:LoadPreset(index: number): (boolean, string?, number?)
	local ok, err, dropped = call("Wardrobe.LoadPreset", index)
	if ok then
		return true, nil, if type(dropped) == "number" then dropped else 0
	end
	return false, err, nil
end

function WardrobeController:SetWearAvatar(on: boolean): (boolean, string?)
	local ok, err = call("Wardrobe.SetWearAvatar", on)
	return ok, err
end

-- Shop.Buy belongs to the shop feature. Its result may be (true) / (false, err) / ({ok, err}); a missing remote
-- means the shop isn't running yet (checked first, so the player never waits on a remote that will not appear).
function WardrobeController:Buy(itemId: string): (boolean, string?)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local folder = remotes and remotes:FindFirstChild("F")
	if not folder or not folder:FindFirstChild("Shop.Buy") then
		return false, "shop_closed"
	end
	local ok, a, b = pcall(Net.invoke, "Shop.Buy", itemId)
	if not ok then
		return false, "shop"
	end
	if a == true then
		return true, nil
	end
	if type(a) == "table" then
		if a.ok == true then
			return true, nil
		end
		local err = a.err or a.error or a.reason
		return false, if type(err) == "string" then err else "shop"
	end
	if a == nil and (b == "timeout" or b == "rate_limited") then
		return false, b
	end
	if a == nil and b == "missing" then
		return false, "shop_closed"
	end
	return false, if type(b) == "string" and b ~= "error" then b else "shop"
end

function WardrobeController:Open(args: any?)
	local ui = Registry.get("UIController")
	if ui then
		ui:Open(SCREEN_ID, args)
	end
end

---------------------------------------------------------------------------------------------------
-- EmployeesOnly prompts: hidden locally for visitors (the server refuses them either way)
---------------------------------------------------------------------------------------------------
local prompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Instance]: { RBXScriptConnection } } = {}

local function evaluate(prompt: ProximityPrompt)
	if prompt:GetAttribute("EmployeesOnly") ~= true then
		return
	end
	local s = store()
	local events = nil
	if s then
		local ok, v = pcall(function()
			return s:GetGlobal("events")
		end)
		events = if ok then v else nil
	end
	local allowed = View.canUsePrompt(storeGet("career"), events, prompt:GetAttribute("CompanyId"))
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

local function track(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") or prompts[prompt] then
		return
	end
	if prompt.Name ~= PROMPT_NAME and prompt:GetAttribute("InteractId") ~= INTERACT_ID then
		return
	end
	prompts[prompt] = true
	prompt:GetAttributeChangedSignal("EmployeesOnly"):Connect(function()
		evaluate(prompt)
	end)
	prompt:GetAttributeChangedSignal("CompanyId"):Connect(function()
		evaluate(prompt)
	end)
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
	if inst:GetAttribute("InteractId") ~= INTERACT_ID or watched[inst] then
		return
	end
	local conns: { RBXScriptConnection } = {}
	watched[inst] = conns
	-- the server parents the prompt under the part (or a Model's PrimaryPart); it may replicate a moment later
	table.insert(conns, inst.DescendantAdded:Connect(track))
	for _, d in inst:GetDescendants() do
		track(d)
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
				access = nil -- rank / company may have changed: the next GetAccess asks the server again
				WardrobeController:GetAccess(true)
			end)
			s:GlobalChanged("events"):Connect(evaluateAll)
			s.Loaded:Connect(evaluateAll)
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function WardrobeController:Init() end

function WardrobeController:Start()
	local ui = Registry.get("UIController")
	if ui and type(ui.RegisterMenuTab) == "function" then
		ui:RegisterMenuTab({
			id = "wardrobe",
			title = Catalog.text("menu"),
			glyph = "👔",
			order = 40,
			screen = SCREEN_ID,
		})
	end
	-- the server accepted a wardrobe prompt (or another feature asked WardrobeService:OpenFor)
	Net.listen("Wardrobe.Open", function(args: any)
		local a = if type(args) == "table" then args else nil
		local open: { [string]: any } = {}
		if a then
			if type(a.slot) == "string" and Catalog.SLOT_SET[a.slot] then
				open.slot = a.slot
			end
			if type(a.item) == "string" then
				open.item = a.item
			end
		end
		WardrobeController:Open(open)
	end)
	startPromptWatch()
end

return WardrobeController
