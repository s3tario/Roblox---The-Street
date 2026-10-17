--!strict
-- OfficeService/Template: everything done to a freshly cloned office template before it goes into Workspace.
-- No services and no yields, so it also runs under Lune (tests/offices).
--
--   Template.prepare(model, company, floor, logos?) -> BrandResult
--       sets CompanyId / Department / Floor / LightingPreset on the root, brands it (Template.brand) and stamps
--       CompanyId / Department on every Interact, Door, OfficeAnchor and OfficeDoor part inside
--   Template.brand(model, company, logos?) -> BrandResult
--       parts tagged CompanyLogo  -> logos.surface(part, face, company.logo) (face = attribute LogoFace or Front),
--                                    falling back to a SurfaceGui with the company name
--       TextLabels named CompanyName (any GUI inside) -> the company name
--       parts tagged FirmColor / FirmAccent -> colors.primary / colors.accent
--   Template.anchors(model) -> { [name] = BasePart }   OfficeAnchor markers (AnchorId as a fallback)
--   Template.doors(model) -> { { part, kind } }        OfficeDoor markers ("exit" | "to_lobby")
--   Template.deskSlots(model) -> { Instance }          the floor's DeskSlot models in slot order
--   Template.chairOf(desk) -> (seat: BasePart?, chair: Model?)   a real Seat, else a chair prop model
--   Template.isTaken(desk) -> boolean                  a desk some feature assigned to a player
--   Template.lightingFor(model, floor) -> string

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)

local Template = {}

Template.TAG_LOGO = "CompanyLogo"
Template.TAG_PRIMARY = "FirmColor"
Template.TAG_ACCENT = "FirmAccent"
Template.NAME_LABEL = "CompanyName"
Template.LOGO_GUI = "CompanyLogoGui"
-- Attributes another feature may set on a DeskSlot it gave to a player (NPCs never take those desks).
Template.OWNER_ATTRS =
	{ "OwnerUserId", "Owner", "OwnerId", "OwnerName", "AssignedTo", "Assigned", "Occupied", "UserId" }

local DEFAULT_GOLD = Color3.fromRGB(201, 165, 76)

export type BrandResult = { logos: number, names: number, colors: number }

local function faceOf(part: Instance): Enum.NormalId
	local name = part:GetAttribute("LogoFace")
	if type(name) == "string" then
		for _, item in Enum.NormalId:GetEnumItems() do
			if item.Name == name then
				return item
			end
		end
	end
	return Enum.NormalId.Front
end

local function fallbackLogo(part: BasePart, face: Enum.NormalId, company: OfficeAlloc.Company): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = Template.LOGO_GUI
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.6
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.7)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Text = company.name
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
	label.TextColor3 = company.primary or DEFAULT_GOLD
	label.TextStrokeTransparency = 0.75
	label.Parent = gui
	gui:SetAttribute("OfficeLogo", true)
	gui.Parent = part
	return gui
end

local function logoOn(part: BasePart, company: OfficeAlloc.Company, logos: any): boolean
	local face = faceOf(part)
	for _, old in part:GetChildren() do
		if old:GetAttribute("OfficeLogo") == true then
			old:Destroy()
		end
	end
	if type(logos) == "table" and type(logos.surface) == "function" then
		local ok, gui = pcall(logos.surface, part, face, company.logo)
		if ok and typeof(gui) == "Instance" then
			gui:SetAttribute("OfficeLogo", true)
			if gui.Parent == nil then
				gui.Parent = part
			end
			return true
		end
		if not ok then
			warn(("[OfficeService] Logos.surface(%s) failed: %s"):format(company.logo, tostring(gui)))
		end
	end
	fallbackLogo(part, face, company)
	return true
end

function Template.brand(model: Instance, company: OfficeAlloc.Company, logos: any?): BrandResult
	local result: BrandResult = { logos = 0, names = 0, colors = 0 }
	local primary = company.primary
	local accent = company.accent or company.primary
	-- Collect first, then change: drawing a logo replaces GUI that the descendant snapshot would still list.
	local logoParts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d:HasTag(Template.TAG_LOGO) then
				table.insert(logoParts, d)
			end
			if primary and d:HasTag(Template.TAG_PRIMARY) then
				d.Color = primary
				result.colors += 1
			elseif accent and d:HasTag(Template.TAG_ACCENT) then
				d.Color = accent
				result.colors += 1
			end
		elseif d:IsA("TextLabel") and d.Name == Template.NAME_LABEL then
			d.Text = company.name
			result.names += 1
		end
	end
	for _, p in logoParts do
		if logoOn(p, company, logos) then
			result.logos += 1
		end
	end
	return result
end

function Template.lightingFor(model: Instance, floor: string): string
	local preset = model:GetAttribute("LightingPreset")
	if type(preset) == "string" and table.find(World.lightingPresets, preset) then
		return preset
	end
	if floor == "st" then
		return "trading_floor"
	end
	return "office_interior"
end

local function isMarker(d: Instance): boolean
	return d:HasTag("Interact")
		or d:HasTag("Door")
		or d:GetAttribute("OfficeAnchor") ~= nil
		or d:GetAttribute("OfficeDoor") ~= nil
		or d:GetAttribute("InteractId") ~= nil
end

function Template.prepare(model: Instance, company: OfficeAlloc.Company, floor: string, logos: any?): BrandResult
	model:SetAttribute("CompanyId", company.id)
	model:SetAttribute("CompanyName", company.name)
	model:SetAttribute("Department", floor)
	model:SetAttribute("Floor", floor)
	model:SetAttribute("LightingPreset", Template.lightingFor(model, floor))
	for _, d in model:GetDescendants() do
		if isMarker(d) then
			d:SetAttribute("CompanyId", company.id)
			d:SetAttribute("Department", floor)
		end
	end
	return Template.brand(model, company, logos)
end

function Template.anchors(model: Instance): { [string]: BasePart }
	local out: { [string]: BasePart } = {}
	local fallback: { [string]: BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local name = d:GetAttribute("OfficeAnchor")
			if type(name) == "string" and not out[name] then
				out[name] = d
			end
			local id = d:GetAttribute("AnchorId")
			if type(id) == "string" and not fallback[id] then
				fallback[id] = d
			end
		end
	end
	for id, part in fallback do
		if not out[id] then
			out[id] = part
		end
	end
	return out
end

export type DoorMarker = { part: BasePart, kind: string }

function Template.doors(model: Instance): { DoorMarker }
	local out: { DoorMarker } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local kind = d:GetAttribute("OfficeDoor")
			if type(kind) == "string" then
				table.insert(out, { part = d, kind = kind })
			end
		end
	end
	return out
end

local function isDesk(d: Instance): boolean
	return d.Name == "DeskSlot" or d:GetAttribute("DeskSlot") ~= nil or d:HasTag("DeskSlot")
end

local function slotNumber(d: Instance): number?
	for _, attr in { "DeskSlot", "SlotIndex", "Index", "Slot" } do
		local v = d:GetAttribute(attr)
		if type(v) == "number" then
			return v
		end
	end
	local n = string.match(d.Name, "(%d+)$")
	return if n then tonumber(n) else nil
end

local function positionOf(d: Instance): Vector3
	if d:IsA("BasePart") then
		return d.Position
	end
	for _, c in d:GetDescendants() do
		if c:IsA("BasePart") then
			return c.Position
		end
	end
	return Vector3.zero
end

function Template.deskSlots(model: Instance): { Instance }
	local out: { Instance } = {}
	for _, d in model:GetDescendants() do
		if isDesk(d) and not (d.Parent and isDesk(d.Parent)) then
			table.insert(out, d)
		end
	end
	local keys: { [Instance]: { number } } = {}
	for _, d in out do
		local p = positionOf(d)
		keys[d] = { slotNumber(d) or math.huge, p.X, p.Z }
	end
	table.sort(out, function(a, b)
		local ka, kb = keys[a], keys[b]
		for i = 1, 3 do
			if ka[i] ~= kb[i] then
				return ka[i] < kb[i]
			end
		end
		return false
	end)
	return out
end

function Template.isTaken(desk: Instance): boolean
	for _, attr in Template.OWNER_ATTRS do
		local v = desk:GetAttribute(attr)
		if v ~= nil and v ~= false and v ~= 0 and v ~= "" then
			return true
		end
	end
	return false
end

local function isChairModel(m: Instance): boolean
	if not m:IsA("Model") then
		return false
	end
	local prop = m:GetAttribute("PropId")
	if type(prop) == "string" and string.sub(prop, 1, 5) == "chair" then
		return true
	end
	return string.find(string.lower(m.Name), "chair", 1, true) ~= nil
end

-- A real Seat at the desk (preferred) or a chair prop model.
function Template.chairOf(desk: Instance): (BasePart?, Model?)
	local chair: Model? = nil
	for _, d in desk:GetDescendants() do
		if d:IsA("Seat") then
			return d, nil
		end
		if chair == nil and isChairModel(d) then
			chair = d :: Model
		end
	end
	return nil, chair
end

return Template
