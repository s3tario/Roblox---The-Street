--!strict
-- Marker helpers for Eastbridge (exterior and interiors). Everything goes through Build/Kit so the attributes and tags
-- match what WorldService (anchors, doors, spawns), NpcService (npc spots), EventService (event spots), HousingService
-- (UnitSlot, DecorSlot, Nameplate, ThemeWall/ThemeFloor) and the interact owners look for. Bake-safe.
--
--   Markers.anchor(parent, id, cf)                 Kit.anchor; cf = root height (about 3 studs above the floor)
--   Markers.door(parent, id, cf, size?)            Kit.door trigger; its front (LookVector) faces the approaching player
--   Markers.npc(parent, id, cf)                    Kit.npcSpot (3 studs above the floor, facing the way the NPC looks)
--   Markers.event(parent, id, cf, size?)           Kit.eventSpot
--   Markers.interact(part, id, attrs?)             Kit.interact on an existing part
--   Markers.point(parent, id, cf, attrs?)          Kit.interactPoint (invisible prompt holder)
--   Markers.surfaceSlot(parent, kind, id, base, size, limits?)  DecorSlot standing on a surface
--   Markers.wallSlot(parent, kind, id, base, size, limits?)     DecorSlot hanging on a wall (base on the wall face,
--                                                                LookVector out of the wall)
--   Markers.nameplate(parent, cf, size, text, opts?)            Part "Nameplate" (front face readable)
--   Markers.theme(part, "wall" | "floor")          tags ThemeWall / ThemeFloor

local Deps = require(script.Parent.Deps)

local Kit = Deps.Kit

local Markers = {}

function Markers.anchor(parent: Instance, id: string, cf: CFrame): Part
	return Kit.anchor(parent, id, cf)
end

Markers.DOOR_SIZE = Vector3.new(8, 10, 2)

function Markers.door(parent: Instance, id: string, cf: CFrame, size: Vector3?): Part
	local d = Kit.door(parent, id, cf, size or Markers.DOOR_SIZE)
	d.Name = id
	return d
end

function Markers.npc(parent: Instance, id: string, cf: CFrame): Part
	return Kit.npcSpot(parent, id, cf)
end

function Markers.event(parent: Instance, id: string, cf: CFrame, size: Vector3?): Part
	return Kit.eventSpot(parent, id, cf, size)
end

function Markers.interact(part: BasePart, id: string, attrs: { [string]: any }?): BasePart
	return Kit.interact(part, id, attrs)
end

function Markers.point(parent: Instance, id: string, cf: CFrame, attrs: { [string]: any }?): Part
	return Kit.interactPoint(parent, id, cf, attrs)
end

export type Limits = { width: number?, height: number?, depth: number? }

local function slotPart(parent: Instance, kind: string, id: string, cf: CFrame, size: Vector3, limits: Limits?): Part
	local p = Kit.block(parent, cf, size, nil, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	p.Name = "DecorSlot"
	p:SetAttribute("SlotKind", kind)
	p:SetAttribute("SlotId", id)
	p:AddTag("DecorSlot")
	if limits then
		if limits.width then
			p:SetAttribute("MaxWidth", limits.width)
		end
		if limits.height then
			p:SetAttribute("MaxHeight", limits.height)
		end
		if limits.depth then
			p:SetAttribute("MaxDepth", limits.depth)
		end
	end
	return p
end

-- Floor, desk and shelf items stand on the slot's bottom face (base = the point on the surface).
function Markers.surfaceSlot(
	parent: Instance,
	kind: string,
	id: string,
	base: CFrame,
	size: Vector3,
	limits: Limits?
): Part
	return slotPart(parent, kind, id, base * CFrame.new(0, size.Y / 2, 0), size, limits)
end

-- Wall items hang from the slot's back face (+Z) and face its front (-Z). base = bottom-centre on the wall face.
function Markers.wallSlot(
	parent: Instance,
	kind: string,
	id: string,
	base: CFrame,
	size: Vector3,
	limits: Limits?
): Part
	return slotPart(parent, kind, id, base * CFrame.new(0, size.Y / 2, -size.Z / 2), size, limits)
end

export type PlateOpts = { color: Color3?, ink: Color3?, font: Enum.Font?, material: Enum.Material? }

function Markers.nameplate(parent: Instance, cf: CFrame, size: Vector3, text: string, opts: PlateOpts?): Part
	local o: PlateOpts = opts or {}
	local p = Kit.detail(parent, cf, size, o.color or Color3.fromRGB(38, 36, 33), o.material or Enum.Material.Metal)
	p.Name = "Nameplate"
	p.CanQuery = true
	p:AddTag("Nameplate")
	Kit.sign(p, text, {
		color = o.ink or Color3.fromRGB(236, 228, 206),
		font = o.font or Enum.Font.GothamMedium,
		pixelsPerStud = 80,
		padding = 0.1,
	})
	return p
end

function Markers.theme(part: BasePart, which: string): BasePart
	part:AddTag(if which == "floor" then "ThemeFloor" else "ThemeWall")
	return part
end

return Markers
