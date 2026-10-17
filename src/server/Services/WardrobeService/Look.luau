--!strict
-- WardrobeService runtime: puts the Career Look on a live player character (RUNTIME ONLY, server).
--
-- A Career Look is a standardized blocky R15 body (HumanoidDescription: default body parts, standard scales, the
-- player's skin tone on every part, their face and hair kept, their own shirts/pants/graphic tee, layered
-- clothing and non-hair accessories removed), optional uploaded Shirt/Pants templates (Config/ClothingIds) and
-- the fitted 3D layers from Shared/Assets/Wardrobe on top. "Wear my avatar" puts the player's own description
-- back.
--
--   Look.capture(player, character, timeout?) -> HumanoidDescription?   the avatar as Roblox loaded it
--   Look.fetch(player) -> HumanoidDescription?                         the avatar from the web (fallback)
--   Look.standardize(character, original) -> boolean                    yields (ApplyDescription)
--   Look.restore(character, original) -> boolean                        yields (ApplyDescription)
--   Look.dress(character, equipped, skin?) -> Wardrobe.Result           sync: templates + 3D layers
--   Look.undress(character)                                             sync: removes templates + layers
--   Look.skinOf(description) -> Color3
--   Look.inWorkspace(character, timeout) -> boolean                     waits until parented under Workspace
-- Never trusts that a character survives a yield: every function re-checks before touching it.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Config.Catalog)
local ClothingIds = require(Shared.Config.ClothingIds)
local Wardrobe = require(Shared.Assets.Wardrobe)
local Fit = require(Shared.Assets.Wardrobe.Fit)

local Look = {}

Look.SHIRT_NAME = "CareerShirt"
Look.PANTS_NAME = "CareerPants"
Look.DEFAULT_SKIN = Color3.fromRGB(209, 154, 106)

local function alive(character: Model): boolean
	return character.Parent ~= nil and character:FindFirstChildOfClass("Humanoid") ~= nil
end

function Look.inWorkspace(character: Model, timeout: number): boolean
	local deadline = os.clock() + timeout
	while not character:IsDescendantOf(workspace) do
		if os.clock() > deadline then
			return false
		end
		task.wait(0.1)
	end
	return true
end

-- ApplyDescriptionAsync (current API) with a fallback to the older name.
local function applyDescription(humanoid: Humanoid, desc: HumanoidDescription): (boolean, string?)
	local h: any = humanoid
	local ok, err = pcall(function()
		h:ApplyDescriptionAsync(desc)
	end)
	if not ok and string.find(tostring(err), "not a valid member", 1, true) then
		ok, err = pcall(function()
			h:ApplyDescription(desc)
		end)
	end
	return ok, if ok then nil else tostring(err)
end

function Look.skinOf(desc: HumanoidDescription?): Color3
	if desc then
		return desc.HeadColor
	end
	return Look.DEFAULT_SKIN
end

-- The description Roblox applied to this character (call before standardizing). Waits for the avatar to load.
function Look.capture(player: Player, character: Model, timeout: number?): HumanoidDescription?
	local deadline = os.clock() + (timeout or 10)
	while not player:HasAppearanceLoaded() and os.clock() < deadline do
		if player.Parent == nil or player.Character ~= character then
			return nil
		end
		task.wait(0.2)
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or player.Character ~= character then
		return nil
	end
	local ok, desc = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if ok and desc then
		return desc:Clone()
	end
	return nil
end

-- The player's avatar straight from Roblox (when no description was captured at spawn). Yields; nil on failure.
function Look.fetch(player: Player): HumanoidDescription?
	local p: any = Players
	local ok, desc = pcall(function()
		return p:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
	end)
	if not ok and string.find(tostring(desc), "not a valid member", 1, true) then
		ok, desc = pcall(function()
			return p:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
	end
	if ok and typeof(desc) == "Instance" and desc:IsA("HumanoidDescription") then
		return desc
	end
	return nil
end

-- A copy of `original` reduced to the Career Look body.
function Look.standardDescription(original: HumanoidDescription): HumanoidDescription
	local desc = original:Clone()
	local skin = original.HeadColor
	desc.HeadColor = skin
	desc.TorsoColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.LeftLegColor = skin
	desc.RightLegColor = skin
	-- default blocky body parts and standard proportions
	desc.Head = 0
	desc.Torso = 0
	desc.LeftArm = 0
	desc.RightArm = 0
	desc.LeftLeg = 0
	desc.RightLeg = 0
	desc.HeightScale = 1
	desc.WidthScale = 1
	desc.DepthScale = 1
	desc.HeadScale = 1
	desc.BodyTypeScale = 0
	desc.ProportionScale = 0
	-- own clothing off (an uploaded template is added as a separate Shirt/Pants by Look.dress)
	desc.Shirt = 0
	desc.Pants = 0
	desc.GraphicTShirt = 0
	-- keep rigid hair only: no hats, glasses, layered clothing or other accessories
	local ok, list = pcall(function()
		return desc:GetAccessories(true)
	end)
	if ok and type(list) == "table" then
		local keep = {}
		for _, acc in list do
			if acc.AccessoryType == Enum.AccessoryType.Hair and not acc.IsLayered then
				table.insert(keep, acc)
			end
		end
		pcall(function()
			desc:SetAccessories(keep, true)
		end)
	else
		desc.HatAccessory = ""
		desc.FaceAccessory = ""
		desc.NeckAccessory = ""
		desc.ShouldersAccessory = ""
		desc.FrontAccessory = ""
		desc.BackAccessory = ""
		desc.WaistAccessory = ""
	end
	return desc
end

-- Removes the player's own clothing and non-hair accessories without a description (fallback path).
local function stripManually(character: Model, skin: Color3)
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") and child.Name ~= Look.SHIRT_NAME then
			child:Destroy()
		elseif child:IsA("Pants") and child.Name ~= Look.PANTS_NAME then
			child:Destroy()
		elseif child:IsA("ShirtGraphic") then
			child:Destroy()
		elseif child:IsA("Accessory") then
			if child.AccessoryType ~= Enum.AccessoryType.Hair then
				child:Destroy()
			end
		elseif child:IsA("BasePart") and Fit.BODY_SET[child.Name] then
			child.Color = skin
		end
	end
end

-- Puts the standardized body on. Returns false if the character went away or isn't an R15 rig.
function Look.standardize(character: Model, original: HumanoidDescription?): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not alive(character) then
		return false
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return false
	end
	-- the old layers would be orphaned when ApplyDescription rebuilds body parts
	Wardrobe.clear(character)
	local skin = Look.skinOf(original)
	if original then
		local desc = Look.standardDescription(original)
		local ok, err = applyDescription(humanoid, desc)
		desc:Destroy()
		if not alive(character) then
			return false
		end
		if not ok then
			warn("[WardrobeService] ApplyDescription failed, stripping manually: " .. tostring(err))
		end
	end
	-- catches anything a description can't express (and the no-description fallback)
	stripManually(character, skin)
	return alive(character)
end

-- Puts the player's own avatar back.
function Look.restore(character: Model, original: HumanoidDescription?): boolean
	Look.undress(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not original or not alive(character) then
		return false
	end
	local ok, err = applyDescription(humanoid, original)
	if not ok then
		warn("[WardrobeService] couldn't restore the avatar: " .. tostring(err))
	end
	return ok and alive(character)
end

local function templateFor(equipped: { [string]: string }, kind: "shirt" | "pants"): number
	local ids: any = ClothingIds
	if kind == "pants" then
		local id = equipped.bottom
		local n = if id then ids.pants[id] else nil
		return if type(n) == "number" then n else 0
	end
	for _, slot in { "outer", "top" } do
		local id = equipped[slot]
		local n = if id then ids.shirts[id] else nil
		if type(n) == "number" and n > 0 then
			return n
		end
	end
	return 0
end

local function setTemplate(character: Model, className: "Shirt" | "Pants", name: string, assetId: number)
	local existing = character:FindFirstChild(name)
	if assetId <= 0 then
		if existing then
			existing:Destroy()
		end
		return
	end
	local content = "rbxassetid://" .. tostring(math.floor(assetId))
	if className == "Shirt" then
		local shirt: Shirt
		if existing and existing:IsA("Shirt") then
			shirt = existing
		else
			if existing then
				existing:Destroy()
			end
			shirt = Instance.new("Shirt")
			shirt.Name = name
			shirt.Parent = character
		end
		shirt.ShirtTemplate = content
	else
		local pants: Pants
		if existing and existing:IsA("Pants") then
			pants = existing
		else
			if existing then
				existing:Destroy()
			end
			pants = Instance.new("Pants")
			pants.Name = name
			pants.Parent = character
		end
		pants.PantsTemplate = content
	end
end

-- Hair accessories hide under a Career Look hat (they'd clip through the crown) and come back without one.
local HAIR_ATTR = "CareerLookHairT"
local function hatHair(character: Model, hatted: boolean)
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and child.AccessoryType == Enum.AccessoryType.Hair then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local saved = handle:GetAttribute(HAIR_ATTR)
				if hatted then
					if saved == nil then
						handle:SetAttribute(HAIR_ATTR, handle.Transparency)
					end
					handle.Transparency = 1
				elseif type(saved) == "number" then
					handle.Transparency = saved
					handle:SetAttribute(HAIR_ATTR, nil)
				end
			end
		end
	end
end

-- Templates and fitted layers for `equipped` (already validated). Synchronous.
function Look.dress(character: Model, equipped: { [string]: string }, skin: Color3?): Wardrobe.Result
	-- the look actually worn includes the plain base pieces for empty required slots
	local worn: { [string]: string } = table.clone(equipped)
	for slot, id in Catalog.REQUIRED do
		if worn[slot] == nil then
			worn[slot] = id
		end
	end
	setTemplate(character, "Shirt", Look.SHIRT_NAME, templateFor(worn, "shirt"))
	setTemplate(character, "Pants", Look.PANTS_NAME, templateFor(worn, "pants"))
	hatHair(character, equipped.head ~= nil)
	return Wardrobe.apply(character, equipped, { anchored = false, skin = skin })
end

function Look.undress(character: Model)
	Wardrobe.clear(character)
	hatHair(character, false)
	for _, name in { Look.SHIRT_NAME, Look.PANTS_NAME } do
		local inst = character:FindFirstChild(name)
		if inst then
			inst:Destroy()
		end
	end
end

-- The player's current character, if it's still the one we started with.
function Look.current(player: Player, character: Model): boolean
	return player.Parent == Players and player.Character == character and character.Parent ~= nil
end

return Look
