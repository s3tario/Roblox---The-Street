--!strict
-- Wardrobe: dresses an R15 character (a player, an NpcRig, a viewport preview) in its Career Look.
-- docs/contracts.md §9; spec §10.
--
--   Wardrobe.apply(character, equipped, opts?) -> Result
--       Clears any previous look, then builds fitted 3D layers for every equipped item into the Folder
--       "CareerLook" under the character and recolours body parts per item (jacket colour on torso and
--       arms, trouser colour on legs, shoe colour on feet; hands and head keep the skin). Each body part's
--       original Color/Material is kept in attributes so clear() can restore it.
--       equipped = { [slot] = itemId } (Catalog ids; unknown ids, wrong slots and hidden mismatches are
--       ignored). Missing top/bottom/shoes fall back to plain base pieces unless opts.fallbacks == false.
--       opts = {
--         anchored: boolean?   -- true: layers are anchored and positioned (baked mannequins, viewports);
--                              --       false/nil: layers are welded (WeldConstraint) to their body part
--         glint: boolean?      -- shop-display sparkle on watches
--         skin: Color3?        -- skin tone for bare areas (default: the LeftHand/Head colour)
--         fallbacks: boolean?  -- default true
--         strict: boolean?     -- let builder errors propagate (tests); default: warn and skip the item
--       }
--   Wardrobe.clear(character)  removes "CareerLook" and restores every recoloured body part.
--   Wardrobe.resolve(equipped, fallbacks?) -> { [slot] = Item }    Wardrobe.isApplied(character) -> boolean
--   Wardrobe.bodyParts(character) -> { [name] = BasePart }         Wardrobe.builders / Wardrobe.hasBuilder(id)
--
-- Every layer part is Massless with CanCollide/CanQuery/CanTouch off, named "<slot>_<Piece>", and carries
-- the attribute CareerLookPart = <body part name>. Bake-safe (contracts §13): no services, no clocks.

local Catalog = require(script.Parent.Parent.Config.Catalog)
local Fit = require(script.Fit)

export type Result = {
	ok: boolean,
	count: number, -- layer parts built
	items: { [string]: string }, -- slot -> item id actually worn (fallbacks included)
	failed: { string }, -- item ids whose builder errored (non-strict mode)
}
export type ApplyOpts = {
	anchored: boolean?,
	glint: boolean?,
	skin: Color3?,
	fallbacks: boolean?,
	strict: boolean?,
}
type Builder = { build: (Fit.Ctx) -> (), covers: any }

local Wardrobe = {}
Wardrobe.Fit = Fit
Wardrobe.FOLDER = Fit.FOLDER
Wardrobe.ATTR_PART = Fit.ATTR_PART
Wardrobe.ATTR_EQUIPPED = "CareerLookItems" -- on the folder: "slot=id;slot=id" (sorted) for quick checks

local builders: { [string]: Builder } = {}
for _, group in
	{
		require(script.Tops),
		require(script.Outer),
		require(script.Bottoms),
		require(script.Shoes),
		require(script.Neck),
		require(script.Accessories),
		require(script.Hats),
		require(script.Bags),
	} :: { any }
do
	for id, b in group do
		assert(builders[id] == nil, "Wardrobe: duplicate builder " .. tostring(id))
		builders[id] = b
	end
end
Wardrobe.builders = builders

function Wardrobe.hasBuilder(id: any): boolean
	return type(id) == "string" and builders[id] ~= nil
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
function Wardrobe.bodyParts(character: Instance): { [string]: BasePart }
	local parts: { [string]: BasePart } = {}
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and Fit.BODY_SET[child.Name] then
			parts[child.Name] = child
		end
	end
	return parts
end

-- Items to build per slot (Catalog items), with the plain fallbacks for required slots.
function Wardrobe.resolve(equipped: any, fallbacks: boolean?): { [string]: Catalog.Item }
	local out: { [string]: Catalog.Item } = {}
	if type(equipped) == "table" then
		for slot, id in equipped do
			local item = Catalog.get(id)
			if type(slot) == "string" and item and item.slot == slot and builders[item.builder] then
				out[slot] = item
			end
		end
	end
	if fallbacks ~= false then
		for slot, id in Catalog.REQUIRED do
			if out[slot] == nil then
				local item = Catalog.get(id)
				if item then
					out[slot] = item
				end
			end
		end
	end
	return out
end

local function coversOf(item: Catalog.Item): { [string]: boolean }
	local b = builders[item.builder]
	if not b then
		return {}
	end
	local c = b.covers
	if type(c) == "function" then
		local ok, result = pcall(c, item)
		return if ok and type(result) == "table" then result else {}
	end
	return if type(c) == "table" then c else {}
end

local function signature(items: { [string]: string }): string
	local list = {}
	for slot, id in items do
		table.insert(list, slot .. "=" .. id)
	end
	table.sort(list)
	return table.concat(list, ";")
end

local function materialFromName(name: any): Enum.Material?
	if type(name) ~= "string" then
		return nil
	end
	local ok, mat = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	if ok and typeof(mat) == "EnumItem" then
		return mat :: any
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- Clear
---------------------------------------------------------------------------------------------------
function Wardrobe.clear(character: Instance)
	if typeof(character) ~= "Instance" then
		return
	end
	local folder = character:FindFirstChild(Fit.FOLDER)
	while folder do
		folder:Destroy()
		folder = character:FindFirstChild(Fit.FOLDER)
	end
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") then
			local color = child:GetAttribute(Fit.ATTR_COLOR)
			if typeof(color) == "Color3" then
				child.Color = color
			end
			local mat = materialFromName(child:GetAttribute(Fit.ATTR_MATERIAL))
			if mat then
				child.Material = mat
			end
			if color ~= nil then
				child:SetAttribute(Fit.ATTR_COLOR, nil)
			end
			if child:GetAttribute(Fit.ATTR_MATERIAL) ~= nil then
				child:SetAttribute(Fit.ATTR_MATERIAL, nil)
			end
		end
	end
end

function Wardrobe.isApplied(character: Instance): boolean
	return typeof(character) == "Instance" and character:FindFirstChild(Fit.FOLDER) ~= nil
end

-- The "slot=id;..." signature of the look currently applied (nil when none).
function Wardrobe.appliedSignature(character: Instance): string?
	if typeof(character) ~= "Instance" then
		return nil
	end
	local folder = character:FindFirstChild(Fit.FOLDER)
	if not folder then
		return nil
	end
	local sig = folder:GetAttribute(Wardrobe.ATTR_EQUIPPED)
	return if type(sig) == "string" then sig else nil
end

---------------------------------------------------------------------------------------------------
-- Apply
---------------------------------------------------------------------------------------------------
function Wardrobe.apply(character: Instance, equipped: { [string]: string }?, opts: ApplyOpts?): Result
	local o: ApplyOpts = opts or {}
	local result: Result = { ok = false, count = 0, items = {}, failed = {} }
	if typeof(character) ~= "Instance" then
		return result
	end
	Wardrobe.clear(character)
	local parts = Wardrobe.bodyParts(character)
	if not parts.UpperTorso then
		return result -- not an R15 rig (or not built yet)
	end

	-- remember the original look of every body part
	for _, p in parts do
		p:SetAttribute(Fit.ATTR_COLOR, p.Color)
		p:SetAttribute(Fit.ATTR_MATERIAL, p.Material.Name)
	end
	local skinPart = parts.LeftHand or parts.RightHand or parts.Head
	local skin = o.skin or (if skinPart then skinPart.Color else Color3.fromRGB(209, 154, 106))

	local folder = Instance.new("Folder")
	folder.Name = Fit.FOLDER

	local items = Wardrobe.resolve(equipped, o.fallbacks)
	local covers: { [string]: { [string]: boolean } } = {}
	for slot, item in items do
		covers[slot] = coversOf(item)
	end

	local ctx: Fit.Ctx = {
		character = character :: any,
		folder = folder,
		anchored = o.anchored == true,
		glint = o.glint == true,
		skin = skin,
		parts = parts,
		items = items :: any,
		covers = covers,
		item = nil,
		slot = "",
		colors = Fit.colorsOf(nil),
		state = {},
		count = 0,
		painted = {},
	}

	for _, slot in Catalog.SLOTS do
		local item = items[slot]
		if not item then
			continue
		end
		local b = builders[item.builder]
		ctx.item = item
		ctx.slot = slot
		ctx.colors = Fit.colorsOf(item)
		if o.strict then
			b.build(ctx)
		else
			local ok, err = pcall(function()
				b.build(ctx)
			end)
			if not ok then
				table.insert(result.failed, item.id)
				warn(("[Wardrobe] %s (%s) failed: %s"):format(item.id, item.builder, tostring(err)))
				continue
			end
		end
		result.items[slot] = item.id
	end

	-- hands always show the skin
	for _, name in { "LeftHand", "RightHand" } do
		local hand = parts[name]
		if hand and ctx.painted[name] then
			hand.Color = skin
			hand.Material = Enum.Material.SmoothPlastic
		end
	end

	folder:SetAttribute(Wardrobe.ATTR_EQUIPPED, signature(result.items))
	folder.Parent = character
	result.ok = true
	result.count = ctx.count
	return result
end

return Wardrobe
