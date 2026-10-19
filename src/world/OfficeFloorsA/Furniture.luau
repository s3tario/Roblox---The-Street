--!strict
-- Bespoke office furniture for the templates, built cheap (few parts) because a floor holds hundreds of pieces.
-- Every cf is the floor point under the piece's centre with LookVector = the piece's front (the way a sitter faces).
-- Chairs are Models named "...Chair" whose PrimaryPart "Root" carries the facing and whose seat top is queryable, so
-- OfficeService's NPCs can sit on them (OfficeService/Npcs seatPoint). Seats never collide (nobody gets stuck).
--
--   Furniture.taskChair(parent, cf, colors)      mesh task chair       (4 parts)
--   Furniture.execChair(parent, cf, colors)      high-back leather     (4 parts)
--   Furniture.guestChair(parent, cf, color, accent?)   upholstered cube chair (2 parts)
--   Furniture.stool(parent, cf, seat, frame)     bar stool             (2 parts)
--   Furniture.sofa(parent, cf, width, color)     (4 parts)    Furniture.coffeeTable(parent, cf, w, d, top, base) (2)
--   Furniture.plant(parent, pos, kind, style)    "floor" | "tall"      (2-3 parts)
--   Furniture.pendant(parent, top, bottomY, style, light?)   black cylinder pendant on a rod (3 parts)
--   Furniture.linear(parent, cf, length, style, light?)      linear pendant with a glowing underside (2 parts)

local Deps = require(script.Parent.Deps)
local Geo = require(script.Parent.Geo)
local Art = require(script.Parent.Art)
local Style = require(script.Parent.Style)

local Kit = Deps.Kit
local M = Enum.Material

local Furniture = {}

export type ChairColors = { mesh: Color3, seat: Color3, base: Color3, name: string? }

local function chairModel(parent: Instance, name: string): Model
	return Kit.model(parent, name)
end

function Furniture.taskChair(parent: Instance, cf: CFrame, c: ChairColors): Model
	local m = chairModel(parent, c.name or "Chair")
	local root = Geo.cyl(m, cf * CFrame.new(0, 0.12, 0), 0.24, 2.1, c.base, M.Metal)
	root.Name = "Root"
	Geo.cyl(m, cf * CFrame.new(0, 0.95, 0), 1.45, 0.28, c.base, M.Metal)
	local seat = Kit.block(m, cf * CFrame.new(0, 1.85, 0.05), Vector3.new(2, 0.36, 1.95), c.seat, M.Fabric, {
		CanCollide = false,
		CanTouch = false,
	})
	seat.Name = "Cushion"
	local back =
		Kit.detail(m, cf * CFrame.new(0, 3.3, 1.05) * Kit.rot(-8, 0, 0), Vector3.new(1.9, 2.3, 0.2), c.mesh, M.Fabric)
	back.Name = "Back"
	m.PrimaryPart = root
	return m
end

function Furniture.execChair(parent: Instance, cf: CFrame, c: ChairColors): Model
	local m = chairModel(parent, c.name or "Chair")
	local root = Geo.cyl(m, cf * CFrame.new(0, 0.12, 0), 0.24, 2.3, c.base, M.Metal)
	root.Name = "Root"
	Geo.cyl(m, cf * CFrame.new(0, 0.95, 0), 1.45, 0.32, c.base, M.Metal)
	local seat = Kit.block(m, cf * CFrame.new(0, 1.9, 0), Vector3.new(2.3, 0.45, 2.2), c.seat, M.Leather, {
		CanCollide = false,
		CanTouch = false,
	})
	seat.Name = "Cushion"
	local back = Kit.detail(
		m,
		cf * CFrame.new(0, 3.75, 1.15) * Kit.rot(-7, 0, 0),
		Vector3.new(2.2, 3.4, 0.45),
		c.mesh,
		M.Leather
	)
	back.Name = "Back"
	m.PrimaryPart = root
	return m
end

function Furniture.guestChair(parent: Instance, cf: CFrame, color: Color3, name: string?): Model
	local m = chairModel(parent, name or "GuestChair")
	local seat = Kit.block(m, cf * CFrame.new(0, 0.85, 0), Vector3.new(2.2, 1.7, 2.1), color, M.Fabric, {
		CanCollide = false,
		CanTouch = false,
	})
	seat.Name = "Root"
	Kit.detail(m, cf * CFrame.new(0, 2.25, 0.85), Vector3.new(2.2, 1.6, 0.4), Kit.shade(color, -0.12), M.Fabric)
	m.PrimaryPart = seat
	return m
end

function Furniture.stool(parent: Instance, cf: CFrame, seat: Color3, frame: Color3): Model
	local m = chairModel(parent, "Stool")
	local root = Geo.cyl(m, cf * CFrame.new(0, 1.6, 0), 3.2, 0.3, frame, M.Metal)
	root.Name = "Root"
	Geo.cyl(m, cf * CFrame.new(0, 3.3, 0), 0.3, 1.5, seat, M.Leather)
	m.PrimaryPart = root
	return m
end

function Furniture.sofa(parent: Instance, cf: CFrame, width: number, color: Color3): Model
	local m = Kit.model(parent, "Sofa")
	local base = Kit.block(m, cf * CFrame.new(0, 0.8, 0), Vector3.new(width, 1.6, 3), color, M.Fabric)
	base.Name = "Root"
	Kit.detail(m, cf * CFrame.new(0, 2.2, 1.2), Vector3.new(width, 1.6, 0.7), Kit.shade(color, -0.1), M.Fabric)
	for _, sx in { -1, 1 } do
		Kit.detail(
			m,
			cf * CFrame.new(sx * (width / 2 - 0.35), 2.0, 0.05),
			Vector3.new(0.7, 0.9, 2.9),
			Kit.shade(color, -0.06),
			M.Fabric
		)
	end
	m.PrimaryPart = base
	return m
end

function Furniture.coffeeTable(parent: Instance, cf: CFrame, w: number, d: number, top: Color3, base: Color3): Model
	local m = Kit.model(parent, "Table")
	local t = Kit.block(m, cf * CFrame.new(0, 1.5, 0), Vector3.new(w, 0.2, d), top, M.Marble)
	t.Name = "Root"
	Kit.detail(m, cf * CFrame.new(0, 0.7, 0), Vector3.new(w * 0.7, 1.4, d * 0.6), base, M.Metal)
	m.PrimaryPart = t
	return m
end

function Furniture.plant(parent: Instance, pos: Vector3, kind: string, style: Style.Style): Model
	local m = Kit.model(parent, "Plant")
	local tall = kind == "tall"
	local potD = if tall then 2 else 1.6
	local potH = if tall then 1.8 else 1.4
	local pot = Geo.cyl(m, CFrame.new(pos + Vector3.new(0, potH / 2, 0)), potH, potD, style.pot, M.Concrete, true)
	pot.Name = "Root"
	local leaf = if tall then 3.2 else 2.4
	local ball = Kit.ball(m, CFrame.new(pos + Vector3.new(0, potH + leaf * 0.42, 0)), leaf, style.plant, M.LeafyGrass)
	Geo.ghost(ball)
	if tall then
		local top = Kit.ball(
			m,
			CFrame.new(pos + Vector3.new(0.3, potH + leaf * 0.95, -0.2)),
			leaf * 0.7,
			style.plantLight,
			M.LeafyGrass
		)
		Geo.ghost(top)
	end
	m.PrimaryPart = pot
	return m
end

export type LightOpts = { range: number?, brightness: number?, angle: number?, color: Color3?, kind: string? }

-- Black cylinder pendant: rod from the slab (topY) down to the shade, glowing disc at bottomY.
function Furniture.pendant(
	parent: Instance,
	top: Vector3,
	bottomY: number,
	style: Style.Style,
	light: LightOpts?
): Model
	local m = Kit.model(parent, "Pendant")
	local shadeH, shadeD = 2.2, 1.5
	local shadeY = bottomY + shadeH / 2
	Geo.pipe(m, Vector3.new(top.X, top.Y, top.Z), Vector3.new(top.X, bottomY + shadeH, top.Z), 0.1, style.pendant)
	local shade = Geo.cyl(m, CFrame.new(top.X, shadeY, top.Z), shadeH, shadeD, style.pendant, M.Metal)
	shade.Name = "Shade"
	local disc = Geo.cyl(m, CFrame.new(top.X, bottomY + 0.05, top.Z), 0.1, shadeD - 0.2, style.lamp, M.Neon)
	disc.Name = "Diffuser"
	disc:AddTag("InteriorLight")
	if light then
		-- the disc's Left face points down (Kit.cylinder lays the part's X axis along the world up)
		Geo.light(disc, light.kind or "spot", {
			Face = Enum.NormalId.Left,
			Range = light.range or 18,
			Brightness = light.brightness or 1.3,
			Angle = light.angle or 110,
			Color = light.color or style.lampWarm,
		})
	end
	return m
end

-- Linear pendant (meeting rooms, offices): a slim black housing hung on one cable, glowing underneath.
function Furniture.linear(
	parent: Instance,
	cf: CFrame,
	length: number,
	slabY: number,
	style: Style.Style,
	light: LightOpts?
): Model
	local m = Kit.model(parent, "LinearPendant")
	local body = Kit.detail(m, cf, Vector3.new(length, 0.3, 0.6), style.pendant, M.Metal)
	body.Name = "Housing"
	body:AddTag("InteriorLight")
	Art.glow(body, Enum.NormalId.Bottom, style.lamp, 2.2)
	local p = cf.Position
	Geo.pipe(m, Vector3.new(p.X, slabY, p.Z), Vector3.new(p.X, p.Y + 0.15, p.Z), 0.08, style.pendant)
	if light then
		Geo.light(body, light.kind or "surface", {
			Face = Enum.NormalId.Bottom,
			Range = light.range or 14,
			Brightness = light.brightness or 1.2,
			Angle = light.angle or 110,
			Color = light.color or style.lampWarm,
		})
	end
	return m
end

return Furniture
