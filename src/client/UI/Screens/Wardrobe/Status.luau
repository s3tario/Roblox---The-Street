--!strict
-- Wardrobe screen: the status overlay on the preview. Shows the Outfit Level of the look on the figure ("Outfit
-- Lv 3", v3 §5), which part holds it down, and the player's firm dress code (Config/Companies minOutfitLevel) in
-- green when the look meets it and red when it doesn't. Builds only GUI instances, so it constructs under Lune.
--
--   Status.build(parent) -> Status        parent = Preview.overlay (a vertical list)
--   status.update(look, companyId?)       look = { [slot] = itemId } on the preview
--   Status.companyInfo(companyId) -> name?, minOutfitLevel?   (guarded: nil when careerPath's config is missing)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local View = require(script.Parent.View)

local Status = {}

export type Status = { update: (look: { [string]: string }, companyId: any) -> () }

-- Config/Companies (careerPath), loaded lazily and guarded: the dress-code line simply hides without it.
local companiesModule: any = nil
local companiesTried = false

function Status.companyInfo(companyId: any): (string?, number?)
	if type(companyId) ~= "string" or companyId == "" then
		return nil, nil
	end
	if not companiesTried then
		companiesTried = true
		local ok, mod = pcall(function(): any
			local config = Shared:FindFirstChild("Config")
			local m = config and config:FindFirstChild("Companies")
			return if m and m:IsA("ModuleScript") then (require :: any)(m) else nil
		end)
		companiesModule = if ok and type(mod) == "table" and type(mod.get) == "function" then mod else nil
	end
	local Companies = companiesModule
	if not Companies then
		return nil, nil
	end
	local ok, c = pcall(Companies.get, companyId)
	if not ok or type(c) ~= "table" then
		return nil, nil
	end
	local name = if type(c.short) == "string" and c.short ~= "" then c.short else c.name
	local minLevel = if type(c.minOutfitLevel) == "number" then c.minOutfitLevel else nil
	return if type(name) == "string" then name else nil, minLevel
end

function Status.build(parent: Instance): Status
	local levelBadge = Kit.Badge({ text = "", color = "accent", size = "sm", name = "OutfitLevel", layoutOrder = 1 })
	levelBadge.frame.Parent = parent
	local heldLabel = Kit.Label({ text = "", size = "xs", color = "textDim", name = "OutfitHeld", layoutOrder = 2 })
	heldLabel.frame.Parent = parent
	local codeBadge = Kit.Badge({ text = "", color = "good", name = "DressCode", layoutOrder = 3 })
	codeBadge.frame.Parent = parent

	local function update(look: { [string]: string }, companyId: any)
		local outfit = View.outfit(look)
		levelBadge.setText(outfit.text)
		heldLabel.setText(outfit.held or "")
		heldLabel.frame.Visible = outfit.held ~= nil
		local companyName, minLevel = Status.companyInfo(companyId)
		local code = View.dressCode(outfit.level, minLevel, companyName)
		codeBadge.frame.Visible = code ~= nil
		if code then
			codeBadge.setText(code.text)
			codeBadge.setColor(code.color)
		end
	end

	return { update = update }
end

return Status
