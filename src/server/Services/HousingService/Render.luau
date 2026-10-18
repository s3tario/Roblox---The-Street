--!strict
-- HousingService/Render: draws a player's housing into a container (desk, office, dorm room, apartment) and puts it
-- back the way the template had it. No services and no yields, so it also runs under Lune (tests/shop).
--
--   Render.setOwner(container, userId?, name?)        OwnerUserId / OwnerName attributes (OfficeService's NPCs leave
--                                                     owned desks); nil clears them
--   Render.decor(container, slots, visible) -> parts   rebuilds folder "HousingDecor": Props.build per placed item
--   Render.plaques(container, placements) -> count     rebuilds folder "HousingPlaques": a lucite "deal_toy" per
--                                                     plaque, engraved with Plaques.label (deal name + date)
--   Render.nameplate(container, text?)                 writes every Nameplate's text (nil restores the template's)
--   Render.theme(container, theme?)                    recolours ThemeWall / ThemeFloor parts (nil or the house
--                                                     style restores the template's colour and material)
--   Render.clear(container)                            all of the above back to the template

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Props = require(Shared.Assets.Props)
local Decor = require(Shared.Config.Decor)
local Palette = require(Shared.Build.Palette)
local Plaques = require(Shared.Logic.Economy.Plaques)
local Markers = require(script.Parent.Markers)

local Render = {}

Render.DECOR_FOLDER = "HousingDecor"
Render.PLAQUE_FOLDER = "HousingPlaques"
Render.NAMEPLATE_GUI = "HousingNameplate"
Render.OWNER_ATTRS = { "OwnerUserId", "OwnerName" }

local ORIG_TEXT = "HousingOrigText"
local ORIG_COLOR = "HousingOrigColor"
local ORIG_MATERIAL = "HousingOrigMaterial"
local PLAQUE_PROP = "deal_toy"

local materialByName: { [string]: Enum.Material } = {}
for _, item in Enum.Material:GetEnumItems() do
	materialByName[item.Name] = item :: any
end

-- Where a container's generated content lives: inside the container when it can hold children, else beside it.
local function holder(container: Instance): Instance?
	if container:IsA("Model") or container:IsA("Folder") then
		return container
	end
	return container.Parent
end

local function folderName(container: Instance, base: string): string
	if container:IsA("Model") or container:IsA("Folder") then
		return base
	end
	return base .. "_" .. container.Name
end

local function clearFolder(container: Instance, base: string)
	local parent = holder(container)
	if not parent then
		return
	end
	local existing = parent:FindFirstChild(folderName(container, base))
	if existing then
		existing:Destroy()
	end
end

local function freshFolder(container: Instance, base: string): Folder?
	local parent = holder(container)
	if not parent then
		return nil
	end
	clearFolder(container, base)
	local f = Instance.new("Folder")
	f.Name = folderName(container, base)
	f.Parent = parent
	return f
end

function Render.setOwner(container: Instance, userId: number?, name: string?)
	if userId then
		container:SetAttribute("OwnerUserId", userId)
		container:SetAttribute("OwnerName", name or "")
	else
		for _, attr in Render.OWNER_ATTRS do
			container:SetAttribute(attr, nil)
		end
	end
end

function Render.decor(container: Instance, slots: { Markers.Slot }, visible: { [string]: Decor.Item }): number
	local any = false
	for _ in visible do
		any = true
		break
	end
	if not any then
		clearFolder(container, Render.DECOR_FOLDER)
		return 0
	end
	local folder = freshFolder(container, Render.DECOR_FOLDER)
	if not folder then
		return 0
	end
	local parts = 0
	for _, slot in slots do
		local item = visible[slot.id]
		local info = if item then Props.get(item.prop) else nil
		if item and info then
			local cf = Markers.mountCFrame(slot.part, info.mount)
			local opts: { [string]: any } = if item.opts then table.clone(item.opts) else {}
			opts.seed = opts.seed or item.id
			local model = Props.tryBuild(item.prop, nil, cf, opts)
			if model then
				model.Name = item.id
				model:SetAttribute("DecorId", item.id)
				model:SetAttribute("HousingSlot", slot.id)
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						parts += 1
					end
				end
				model.Parent = folder
			end
		end
	end
	return parts
end

local function plaqueVariant(quality: number?): string
	local q = if type(quality) == "number" and quality == quality then quality else 0
	if q >= 90 then
		return "obelisk"
	elseif q >= 70 then
		return "tombstone"
	end
	return "cube"
end

function Render.plaques(container: Instance, slots: { Markers.Slot }, placements: { Plaques.Placement }): number
	if #placements == 0 then
		clearFolder(container, Render.PLAQUE_FOLDER)
		return 0
	end
	local folder = freshFolder(container, Render.PLAQUE_FOLDER)
	if not folder then
		return 0
	end
	local partOf: { [string]: BasePart } = {}
	for _, slot in slots do
		partOf[slot.id] = slot.part
	end
	local count = 0
	for _, placement in placements do
		local part = partOf[placement.slotId]
		if part then
			local p = placement.plaque
			local model = Props.tryBuild(PLAQUE_PROP, nil, Markers.mountCFrame(part, "desk"), {
				text = Plaques.label(p),
				variant = plaqueVariant(p.quality),
				seed = p.id,
			})
			if model then
				model.Name = "Plaque_" .. p.id
				model:SetAttribute("PlaqueId", p.id)
				model:SetAttribute("DealName", p.name)
				model.Parent = folder
				count += 1
			end
		end
	end
	return count
end

local function labelsIn(inst: Instance): { TextLabel }
	local out: { TextLabel } = {}
	if inst:IsA("TextLabel") then
		table.insert(out, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("TextLabel") then
			table.insert(out, d)
		end
	end
	return out
end

local function makePlateGui(part: BasePart): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = Render.NAMEPLATE_GUI
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.LightInfluence = 0.5
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.TextScaled = true
	label.TextWrapped = true
	label.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	label.TextColor3 = Palette.hex("#1D1A16")
	label.Text = ""
	label.Parent = gui
	gui.Parent = part
	return label
end

function Render.nameplate(container: Instance, text: string?)
	for _, plate in Markers.nameplates(container) do
		if text == nil then
			for _, label in labelsIn(plate) do
				local orig = label:GetAttribute(ORIG_TEXT)
				if type(orig) == "string" then
					label.Text = orig
					label:SetAttribute(ORIG_TEXT, nil)
				end
			end
			for _, d in plate:GetDescendants() do
				if d:IsA("SurfaceGui") and d.Name == Render.NAMEPLATE_GUI then
					d:Destroy()
				end
			end
		else
			local labels = labelsIn(plate)
			if #labels == 0 then
				local part: BasePart? = if plate:IsA("BasePart")
					then plate
					else plate:FindFirstChildWhichIsA("BasePart", true)
				if part then
					table.insert(labels, makePlateGui(part))
				end
			end
			for _, label in labels do
				if label:GetAttribute(ORIG_TEXT) == nil then
					label:SetAttribute(ORIG_TEXT, label.Text)
				end
				label.Text = text
			end
		end
	end
end

local function restoreSurface(part: BasePart)
	local color = part:GetAttribute(ORIG_COLOR)
	if typeof(color) == "Color3" then
		part.Color = color
		part:SetAttribute(ORIG_COLOR, nil)
	end
	local mat = part:GetAttribute(ORIG_MATERIAL)
	if type(mat) == "string" then
		local m = materialByName[mat]
		if m then
			part.Material = m
		end
		part:SetAttribute(ORIG_MATERIAL, nil)
	end
end

local function paint(part: BasePart, surface: Decor.Surface)
	if part:GetAttribute(ORIG_COLOR) == nil then
		part:SetAttribute(ORIG_COLOR, part.Color)
		part:SetAttribute(ORIG_MATERIAL, part.Material.Name)
	end
	part.Color = Palette.hex(surface.color)
	part.Material = surface.material
end

function Render.theme(container: Instance, theme: Decor.Theme?)
	local walls, floors = Markers.themeParts(container)
	local wall = if theme then theme.wall else nil
	local floor = if theme then theme.floor else nil
	for _, part in walls do
		if wall then
			paint(part, wall)
		else
			restoreSurface(part)
		end
	end
	for _, part in floors do
		if floor then
			paint(part, floor)
		else
			restoreSurface(part)
		end
	end
end

function Render.clear(container: Instance)
	clearFolder(container, Render.DECOR_FOLDER)
	clearFolder(container, Render.PLAQUE_FOLDER)
	Render.nameplate(container, nil)
	Render.theme(container, nil)
	Render.setOwner(container, nil, nil)
end

return Render
