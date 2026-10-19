--!strict
-- Geometry shorthands on top of Build/Kit for the office templates (bake-safe):
--   Geo.box(parent, min, max, color, mat?, solid?)      axis-aligned block from two corners (solid = collides)
--   Geo.cyl(parent, cf, height, d, color, mat?, solid?)  upright cylinder (axis = cf.UpVector)
--   Geo.pipe(parent, a, b, d, color, mat?)              non-colliding cylinder from point a to point b
--   Geo.ghost(part) -> part                             makes a part non-colliding, non-queryable decoration
--   Geo.light(part, kind, props)                        Kit.light with shadows off (point lights drop Face/Angle)
--   Geo.glass(parent, cf, size, color)                  colliding partition glass
--   Geo.frost(parent, cf, size)                         frosted manifestation band (decoration)
--   Geo.settle(root)                                    writes every part's Position from its CFrame (see below)

local Deps = require(script.Parent.Deps)

local Kit = Deps.Kit

local Geo = {}

function Geo.ghost<T>(part: T): T
	local p = (part :: any) :: BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return part
end

function Geo.box(parent: Instance, a: Vector3, b: Vector3, color: Color3, mat: Enum.Material?, solid: boolean?): Part
	local mn = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local mx = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	local size = mx - mn
	local cf = CFrame.new((mn + mx) / 2)
	if solid then
		return Kit.block(parent, cf, size, color, mat or Enum.Material.SmoothPlastic)
	end
	return Kit.detail(parent, cf, size, color, mat or Enum.Material.SmoothPlastic)
end

function Geo.cyl(
	parent: Instance,
	cf: CFrame,
	height: number,
	d: number,
	color: Color3,
	mat: Enum.Material?,
	solid: boolean?
): Part
	local p = Kit.cylinder(parent, cf, height, d, color, mat or Enum.Material.SmoothPlastic)
	if not solid then
		Geo.ghost(p)
		p.CastShadow = height > 2 or d > 2
	end
	return p
end

function Geo.pipe(parent: Instance, a: Vector3, b: Vector3, d: number, color: Color3, mat: Enum.Material?): Part
	local dir = b - a
	local len = dir.Magnitude
	local mid = (a + b) / 2
	-- the cylinder's axis is the part's X axis; lookAt degenerates for vertical runs, so those turn about Z
	local cf = if len > 1e-6 and math.abs(dir.Unit.Y) < 0.999
		then CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
		else CFrame.new(mid) * CFrame.Angles(0, 0, math.rad(90))
	local p = Kit.detail(parent, cf, Vector3.new(math.max(len, 0.05), d, d), color, mat or Enum.Material.Metal)
	p.Shape = Enum.PartType.Cylinder
	p.CastShadow = d > 1
	return p
end

-- Face and Angle only exist on SpotLight / SurfaceLight, so they are dropped for point lights.
function Geo.light(part: BasePart, kind: string, props: { [string]: any }): Light
	local p = table.clone(props)
	if kind ~= "spot" and kind ~= "surface" then
		p.Face = nil
		p.Angle = nil
	end
	return Kit.light(part, kind, p)
end

function Geo.glass(parent: Instance, cf: CFrame, size: Vector3, color: Color3): Part
	local g = Kit.block(parent, cf, size, color, Enum.Material.Glass, {
		Transparency = 0.78,
		Reflectance = 0.06,
		CastShadow = false,
	})
	g.Name = "Glass"
	return g
end

function Geo.frost(parent: Instance, cf: CFrame, size: Vector3): Part
	local f = Kit.detail(parent, cf, size, Color3.new(1, 1, 1), Enum.Material.Glass)
	f.Transparency = 0.5
	f.CastShadow = false
	f.Name = "Frost"
	return f
end

-- Lune's Roblox DOM keeps Position and CFrame as separate stored properties and has no default for Position, so
-- tools reading part.Position (tools/bake, OfficeService/Template) fail on parts that only had their CFrame set.
-- Writing Position = CFrame.Position is a no-op in Roblox, and the binary .rbxm writer drops it (CFrame is the
-- serialized property), so this only makes the baked model readable under Lune.
function Geo.settle(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Position = d.CFrame.Position
		end
	end
	if root:IsA("BasePart") then
		root.Position = root.CFrame.Position
	end
end

return Geo
