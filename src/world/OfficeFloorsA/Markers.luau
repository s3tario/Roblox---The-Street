--!strict
-- Marker helpers for office templates (Config/World.templateMarkers, floorSlots, templateEventSpots; contracts §11).
-- Everything goes through Build/Kit so attributes and tags match what OfficeService, WorldService and
-- HousingService look for:
--   Markers.anchor(parent, id, cf)            OfficeAnchor (Kit.anchor + attribute OfficeAnchor); cf = root height
--   Markers.door(parent, kind, cf, size)      OfficeDoor trigger (Kit.door + attribute OfficeDoor = kind)
--   Markers.eventSpot(parent, id, cf, size?)  Kit.eventSpot
--   Markers.surfaceSlot(parent, kind, base, size, opts?)   DecorSlot standing on a surface (floor, desk, shelf):
--                                             base = the point on the surface, LookVector = the item's front
--   Markers.wallSlot(parent, kind, base, size, opts?)      DecorSlot hanging on a wall: base = bottom-centre on the
--                                             wall face, LookVector out of the wall
--   Markers.nameplate(parent, cf, size, text, opts?)       Part "Nameplate" (front face = readable side)
--   Markers.barrier(parent, cf, size)         invisible collision wall
-- Bake-safe.

local Deps = require(script.Parent.Deps)

local Kit = Deps.Kit

local Markers = {}

export type SlotOpts = {
	id: string?,
	index: number?,
	maxWidth: number?,
	maxHeight: number?,
	maxDepth: number?,
}

function Markers.anchor(parent: Instance, id: string, cf: CFrame): Part
	local p = Kit.anchor(parent, id, cf)
	p.Name = "OfficeAnchor_" .. id
	p:SetAttribute("OfficeAnchor", id)
	return p
end

function Markers.door(parent: Instance, kind: string, cf: CFrame, size: Vector3): Part
	local p = Kit.door(parent, "office_" .. kind, cf, size)
	p.Name = "OfficeDoor_" .. kind
	p:SetAttribute("OfficeDoor", kind)
	return p
end

function Markers.eventSpot(parent: Instance, id: string, cf: CFrame, size: Vector3?): Part
	return Kit.eventSpot(parent, id, cf, size)
end

local function slotPart(parent: Instance, kind: string, cf: CFrame, size: Vector3, opts: SlotOpts?): Part
	local p = Kit.block(parent, cf, size, nil, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	p.Name = "DecorSlot"
	p:SetAttribute("SlotKind", kind)
	p:AddTag("DecorSlot")
	local o = opts
	if o then
		if o.id then
			p:SetAttribute("SlotId", o.id)
			p:SetAttribute("DecorSlot", o.id)
		end
		if o.index then
			p:SetAttribute("SlotIndex", o.index)
		end
		if o.maxWidth then
			p:SetAttribute("MaxWidth", o.maxWidth)
		end
		if o.maxHeight then
			p:SetAttribute("MaxHeight", o.maxHeight)
		end
		if o.maxDepth then
			p:SetAttribute("MaxDepth", o.maxDepth)
		end
	end
	return p
end

-- Floor, desk and shelf items stand on the slot's bottom face.
function Markers.surfaceSlot(parent: Instance, kind: string, base: CFrame, size: Vector3, opts: SlotOpts?): Part
	return slotPart(parent, kind, base * CFrame.new(0, size.Y / 2, 0), size, opts)
end

-- Wall items hang from the slot's back face (+Z) and face its front (-Z).
function Markers.wallSlot(parent: Instance, kind: string, base: CFrame, size: Vector3, opts: SlotOpts?): Part
	return slotPart(parent, kind, base * CFrame.new(0, size.Y / 2, -size.Z / 2), size, opts)
end

export type PlateOpts = {
	color: Color3?,
	material: Enum.Material?,
	ink: Color3?,
	font: Enum.Font?,
}

-- A thin plate with its default text on the front face. HousingService writes "name / title" into its TextLabels
-- and restores this text when the desk or office is released.
function Markers.nameplate(parent: Instance, cf: CFrame, size: Vector3, text: string, opts: PlateOpts?): Part
	local o: PlateOpts = opts or {}
	local p = Kit.detail(parent, cf, size, o.color or Color3.fromRGB(32, 33, 36), o.material or Enum.Material.Metal)
	p.Name = "Nameplate"
	p.CanQuery = true
	p:AddTag("Nameplate")
	Kit.sign(p, text, {
		color = o.ink or Color3.fromRGB(236, 230, 214),
		font = o.font or Enum.Font.GothamMedium,
		pixelsPerStud = 80,
		padding = 0.1,
	})
	return p
end

function Markers.barrier(parent: Instance, cf: CFrame, size: Vector3): Part
	local p = Kit.block(parent, cf, size, nil, nil, {
		Transparency = 1,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	p.Name = "Boundary"
	return p
end

return Markers
