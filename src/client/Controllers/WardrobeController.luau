--!strict
-- WardrobeController (client, owned by `wardrobe`): opens the Wardrobe screen and talks to WardrobeService.
--
-- Interact wiring: the server (WardrobeService) creates a ProximityPrompt with attribute InteractId =
-- "wardrobe" on every "Interact"-tagged wardrobe point; this controller listens to
-- ProximityPromptService.PromptTriggered and opens the screen for those prompts. It also adds the
-- "Wardrobe" menu tab.
--
-- API (used by UI/Screens/Wardrobe):
--   WardrobeController:Open(args?)                       UIController:Open("Wardrobe", args)
--   WardrobeController:GetAccess(force?) -> { rank, passes }   cached server answer (falls back to Store data)
--   WardrobeController:Equip(slot, itemId?) -> ok, errKey?
--   WardrobeController:SavePreset(index, name?) -> ok, errKey?
--   WardrobeController:LoadPreset(index) -> ok, errKey?, droppedCount?
--   WardrobeController:SetWearAvatar(on) -> ok, errKey?
--   WardrobeController:Buy(itemId) -> ok, errKey?        Net.invoke("Shop.Buy", itemId); "shop_closed" when the
--                                                        shop feature isn't running
--   WardrobeController.AccessChanged : Signal(access)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Catalog = require(Shared.Config.Catalog)
local Registry = require(script.Parent.Parent.Registry)

local WardrobeController = { Name = "WardrobeController" }

WardrobeController.AccessChanged = Signal.new()

local INTERACT_ID = "wardrobe"
local SCREEN_ID = "Wardrobe"
local ACCESS_TTL = 20

export type Access = { rank: number, passes: { [string]: boolean } }

local access: Access? = nil
local accessAt = -math.huge
local accessInFlight = false

local function store(): any
	return Registry.get("Store")
end

-- Best guess from replicated data until the server answers.
local function localAccess(): Access
	local s = store()
	local rank = 0
	local passes: { [string]: boolean } = {}
	if s then
		local career = s:Get("career")
		if type(career) == "table" and type(career.rank) == "number" then
			rank = career.rank
		end
		local ent = s:Get("entitlements")
		local saved = if type(ent) == "table" then ent.passes else nil
		if type(saved) == "table" then
			for passKey in Catalog.PASSES do
				passes[passKey] = saved[passKey] == true or table.find(saved, passKey) ~= nil
			end
		end
	end
	return { rank = rank, passes = passes }
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
				access = { rank = result.rank, passes = passes }
				accessAt = os.clock()
				WardrobeController.AccessChanged:Fire(access)
			end
		end)
	end
	return access or localAccess()
end

-- RemoteFunction results arrive as (ok, err, ...) or (nil, "timeout"/"error"/"rate_limited").
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
		if b == "missing" then
			return false, "generic", nil
		end
		return false, if b == "error" then "generic" else b, nil
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
	local ok, a, b, c = pcall(Net.invoke, "Wardrobe.LoadPreset", index)
	if not ok then
		return false, "generic", nil
	end
	if a == true then
		return true, nil, if type(c) == "number" then c else 0
	end
	return false, if type(b) == "string" and b ~= "error" then b else "generic", nil
end

function WardrobeController:SetWearAvatar(on: boolean): (boolean, string?)
	local ok, err = call("Wardrobe.SetWearAvatar", on)
	return ok, err
end

-- Shop.Buy belongs to the shop feature. Its result may be (true) / (false, err) / ({ok, err}); a missing remote
-- means the shop isn't running yet.
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
		return false, if type(a.err) == "string" then a.err else "shop"
	end
	if a == nil and (b == "timeout" or b == "rate_limited") then
		return false, b
	end
	return false, if type(b) == "string" and b ~= "error" then b else "shop"
end

function WardrobeController:Open(args: any?)
	local ui = Registry.get("UIController")
	if ui then
		ui:Open(SCREEN_ID, args)
	end
end

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
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt:GetAttribute("InteractId") == INTERACT_ID then
			WardrobeController:Open()
		end
	end)
end

return WardrobeController
