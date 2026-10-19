--!strict
-- Geometry shorthands for the Eastbridge builders (bake-safe):
--   Geo.box(parent, a, b, color, mat?, solid?)          axis-aligned block between two world corners
--   Geo.lbox(parent, x0, y0, z0, x1, y1, z1, ...)       the same in Plan's local coordinates
--   Geo.ghost(part) -> part                             non-colliding, non-queryable decoration
--   Geo.pipe(parent, a, b, d, color, mat?, solid?)      cylinder from world point a to b
--   Geo.vary(color, rng, amount)                        a seeded light/dark variation of a colour
--   Geo.brick(rng) -> Color3                            one of Eastbridge's red-brown bricks, varied
--   Geo.bareTree(parent, base, rng, scale?)             a leafless street tree (trunk collides, branches don't)
--   Geo.water(parent, cf, size)                         dark reflective water
--   Geo.barrier(parent, a, b)                           invisible collision wall between two world corners
--   Geo.settle(root)                                    writes each part's Position from its CFrame (Lune DOM)

local Deps = require(script.Parent.Deps)

local Kit = Deps.Kit
local P = Deps.Palette
local C = P.campus
local hex = P.hex

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
	if solid == false then
		return Kit.detail(parent, cf, size, color, mat or Enum.Material.SmoothPlastic)
	end
	return Kit.block(parent, cf, size, color, mat or Enum.Material.SmoothPlastic)
end

local origin = require(script.Parent.Plan).ORIGIN

function Geo.lbox(
	parent: Instance,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number,
	color: Color3,
	mat: Enum.Material?,
	solid: boolean?
): Part
	return Geo.box(parent, origin + Vector3.new(x0, y0, z0), origin + Vector3.new(x1, y1, z1), color, mat, solid)
end

function Geo.pipe(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	d: number,
	color: Color3,
	mat: Enum.Material?,
	solid: boolean?
): Part
	local dir = b - a
	local len = dir.Magnitude
	local mid = (a + b) / 2
	local cf: CFrame
	if len < 1e-4 then
		cf = CFrame.new(mid)
	elseif math.abs(dir.Unit.Y) > 0.999 then
		cf = CFrame.new(mid) * CFrame.Angles(0, 0, math.rad(90))
	else
		cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
	end
	-- Roblox cylinders run along their X axis: lookAt points -Z at b, the 90 degree turn lines X up with it
	local p = Kit.block(parent, cf, Vector3.new(math.max(len, 0.05), d, d), color, mat or Enum.Material.Metal)
	p.Shape = Enum.PartType.Cylinder
	if not solid then
		Geo.ghost(p)
		p.CastShadow = d > 0.6
	end
	return p
end

function Geo.vary(color: Color3, rng: Deps.RngT, amount: number): Color3
	return Kit.shade(color, rng:range(-amount, amount))
end

local BRICKS = { C.brick, C.brickDark, C.brickFaded, hex("#6E3326"), hex("#8A4632"), hex("#6A4034") }

function Geo.brick(rng: Deps.RngT): Color3
	return Geo.vary(rng:pick(BRICKS), rng, 0.06)
end

-- A leafless tree: trunk (collides), forked limbs and twigs. base = world point on the ground.
function Geo.bareTree(parent: Instance, base: Vector3, rng: Deps.RngT, scale: number?): Model
	local s = scale or 1
	local m = Kit.model(parent, "BareTree")
	local bark = Geo.vary(hex("#3E342C"), rng, 0.1)
	local h = rng:range(9, 13) * s
	local lean = Vector3.new(rng:range(-0.6, 0.6), 0, rng:range(-0.6, 0.6)) * s
	local top = base + Vector3.new(0, h, 0) + lean
	Geo.pipe(m, base + Vector3.new(0, -0.5, 0), top, 1.1 * s, bark, Enum.Material.Wood, true)
	local limbs = rng:int(3, 5)
	for i = 1, limbs do
		local a = (i / limbs) * math.pi * 2 + rng:range(-0.4, 0.4)
		local from = base + Vector3.new(0, h * rng:range(0.55, 0.9), 0) + lean * 0.8
		local reach = rng:range(3.5, 6.5) * s
		local to = from + Vector3.new(math.cos(a) * reach, rng:range(2.5, 5) * s, math.sin(a) * reach)
		Geo.pipe(m, from, to, 0.45 * s, bark, Enum.Material.Wood, false)
		if rng:chance(0.6) then
			local b = a + rng:range(-0.9, 0.9)
			local twig = to + Vector3.new(math.cos(b) * 2.2 * s, rng:range(1.2, 2.6) * s, math.sin(b) * 2.2 * s)
			Geo.pipe(m, to, twig, 0.22 * s, bark, Enum.Material.Wood, false)
		end
	end
	-- a few dead leaves clinging on
	if rng:chance(0.5) then
		Kit.detail(
			m,
			CFrame.new(top + Vector3.new(0, 1, 0)),
			Vector3.new(2.4, 1.2, 2.2) * s,
			hex("#6B5A3A"),
			Enum.Material.Grass
		).Transparency =
			0.35
	end
	return m
end

function Geo.water(parent: Instance, cf: CFrame, size: Vector3): Part
	local w = Kit.block(parent, cf, size, hex("#2C3A40"), Enum.Material.Glass)
	w.Name = "Water"
	w.Transparency = 0.12
	w.Reflectance = 0.32
	w.CastShadow = false
	w.CanCollide = true
	return w
end

function Geo.barrier(parent: Instance, a: Vector3, b: Vector3): Part
	local p = Geo.box(parent, a, b, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, true)
	p.Name = "Boundary"
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

function Geo.settle(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Position = d.CFrame.Position
		end
	end
end

return Geo
