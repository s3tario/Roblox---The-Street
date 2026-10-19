--!strict
-- The floor's shell: the invisible Root at the template origin, the carpet slab with walkway inlays, the ceiling
-- slab, glass curtain walls on every side but the core, window upstands, invisible boundary walls, the setback roof
-- ledges below the windows and the skyline backdrops that fake the view (contracts §15: templates are fully
-- enclosed; the view is painted). Shared by the lobby (Shell.root, Shell.backdrops). Bake-safe.

local Deps = require(script.Parent.Deps)
local Layout = require(script.Parent.Layout)
local Markers = require(script.Parent.Markers)
local Geo = require(script.Parent.Geo)
local Art = require(script.Parent.Art)
local Style = require(script.Parent.Style)

local Kit = Deps.Kit
local M = Enum.Material
local V = Vector3.new

local Shell = {}

local H = Layout.HEIGHT
local HX, HZ = Layout.HALF_X, Layout.HALF_Z

-- The invisible PrimaryPart at the template origin (OfficeService pivots the clone by it).
function Shell.root(model: Model): Part
	local root = Kit.block(model, CFrame.new(0, 0, 0), V(2, 1, 2), nil, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	root.Name = "Root"
	model.PrimaryPart = root
	return root
end

export type BackdropOpts = {
	seed: any,
	halfX: number,
	halfZ: number,
	distance: number, -- how far outside the glass the painted city stands
	bottom: number,
	top: number,
	eyeY: number,
	sides: { string }?, -- default all four: "north" | "south" | "east" | "west"
	density: number?,
}

-- Four transparent planes painted with a skyline, facing inward. The sky stays clear so the real sky shows above.
function Shell.backdrops(parent: Instance, o: BackdropOpts): Folder
	local f = Kit.folder(parent, "Backdrops")
	local h = o.top - o.bottom
	local cy = (o.top + o.bottom) / 2
	local horizon = (o.top - o.eyeY) / h
	local dx, dz = o.halfX + o.distance, o.halfZ + o.distance
	local spanX, spanZ = (dx + 30) * 2, (dz + 30) * 2
	local defs = {
		north = { cf = CFrame.new(0, cy, dz), size = V(spanX, h, 0.2), face = Enum.NormalId.Front },
		south = { cf = CFrame.new(0, cy, -dz), size = V(spanX, h, 0.2), face = Enum.NormalId.Back },
		east = { cf = CFrame.new(dx, cy, 0), size = V(0.2, h, spanZ), face = Enum.NormalId.Left },
		west = { cf = CFrame.new(-dx, cy, 0), size = V(0.2, h, spanZ), face = Enum.NormalId.Right },
	}
	local sides: { string } = o.sides or { "north", "south", "east", "west" }
	for _, side in sides do
		local d = defs[side]
		local p = Kit.block(f, d.cf, d.size, Color3.fromRGB(150, 175, 195), M.SmoothPlastic, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		p.Name = "Skyline_" .. side
		Art.skyline(p, d.face, { seed = Deps.Hash.u32(tostring(o.seed), side), horizon = horizon, density = o.density })
	end
	return f
end

-- One curtain-wall run with its upstand. cf faces OUT of the building.
local function windowRun(parent: Instance, cf: CFrame, width: number, cols: number, style: Style.Style, seed: any)
	local grid = Kit.windowGrid(parent, {
		cf = cf,
		width = width,
		height = H,
		cols = cols,
		rows = 1,
		glassColor = style.windowGlass,
		frameColor = style.mullion,
		frameThickness = 0.35,
		depth = 0.5,
		glassTransparency = 0.6,
		glassReflectance = 0.12,
		seed = seed,
	})
	grid.Name = "CurtainWall"
	local up = Kit.block(parent, cf * CFrame.new(0, -H / 2 + 0.45, 0.45), V(width, 0.9, 0.7), style.mullion, M.Metal)
	up.Name = "Upstand"
end

function Shell.build(parent: Instance, style: Style.Style, seed: any): Model
	local m = Kit.model(parent, "Shell")
	local floor = Kit.block(m, CFrame.new(0, -0.5, 0), V(HX * 2 + 1, 1, HZ * 2 + 1), style.carpet, style.carpetMat)
	floor.Name = "Floor"
	local slab = Kit.block(
		m,
		CFrame.new(0, H + Layout.SLAB / 2, 0),
		V(HX * 2 + 1, Layout.SLAB, HZ * 2 + 1),
		style.slab,
		style.slabMat
	)
	slab.Name = "CeilingSlab"
	if not style.plain then
		Art.formwork(slab, Enum.NormalId.Bottom, 8, Kit.shade(style.slab, -0.35))
	end

	-- walkway inlays: the corridor, the centre aisle and the south aisle
	local c = Layout.corridor
	Geo.box(m, V(c.minX + 0.5, 0, c.minZ + 0.6), V(c.maxX - 0.5, 0.04, c.maxZ - 0.6), style.walkway, style.carpetMat).Name =
		"Walkway"
	Geo.box(m, V(-63.5, 0, -11), V(55, 0.04, -1), style.walkway, style.carpetMat).Name = "Walkway"
	Geo.box(m, V(-63.5, 0, -37.5), V(55, 0.04, -30.6), style.walkway, style.carpetMat).Name = "Walkway"

	-- glass on every side; the south side stops at the core
	local y = H / 2
	windowRun(m, CFrame.lookAt(V(0, y, HZ), V(0, y, HZ + 1)), HX * 2, 20, style, Deps.Hash.u32(seed, "n"))
	windowRun(m, CFrame.lookAt(V(HX, y, 0), V(HX + 1, y, 0)), HZ * 2, 10, style, Deps.Hash.u32(seed, "e"))
	windowRun(m, CFrame.lookAt(V(-HX, y, 0), V(-HX - 1, y, 0)), HZ * 2, 10, style, Deps.Hash.u32(seed, "w"))
	local core = Layout.lobby
	local wWest = (core.minX - 0.5) - -HX
	local wEast = HX - (core.maxX + 0.5)
	windowRun(
		m,
		CFrame.lookAt(V(-HX + wWest / 2, y, -HZ), V(-HX + wWest / 2, y, -HZ - 1)),
		wWest,
		6,
		style,
		Deps.Hash.u32(seed, "sw")
	)
	windowRun(
		m,
		CFrame.lookAt(V(HX - wEast / 2, y, -HZ), V(HX - wEast / 2, y, -HZ - 1)),
		wEast,
		6,
		style,
		Deps.Hash.u32(seed, "se")
	)

	-- safety net just outside the glass
	local b = Kit.folder(m, "Boundary")
	Markers.barrier(b, CFrame.new(0, H / 2, HZ + 1.5), V(HX * 2 + 6, H + 4, 1))
	Markers.barrier(b, CFrame.new(0, H / 2, -HZ - 1.5), V(HX * 2 + 6, H + 4, 1))
	Markers.barrier(b, CFrame.new(HX + 1.5, H / 2, 0), V(1, H + 4, HZ * 2 + 6))
	Markers.barrier(b, CFrame.new(-HX - 1.5, H / 2, 0), V(1, H + 4, HZ * 2 + 6))

	-- the setback roof one storey down: what you see when you look down out of the window
	local roof = if style.plain then Color3.fromRGB(120, 122, 124) else Color3.fromRGB(104, 106, 108)
	local L = 12
	Geo.box(m, V(-HX - L, -3, HZ + 0.6), V(HX + L, -2, HZ + L), roof, M.Pebble).Name = "Setback"
	Geo.box(m, V(-HX - L, -3, -HZ - L), V(HX + L, -2, -HZ - 0.6), roof, M.Pebble).Name = "Setback"
	Geo.box(m, V(HX + 0.6, -3, -HZ), V(HX + L, -2, HZ), roof, M.Pebble).Name = "Setback"
	Geo.box(m, V(-HX - L, -3, -HZ), V(-HX - 0.6, -2, HZ), roof, M.Pebble).Name = "Setback"

	Shell.backdrops(m, {
		seed = seed,
		halfX = HX,
		halfZ = HZ,
		distance = 32,
		bottom = -30,
		top = 105,
		eyeY = 5,
	})
	return m
end

return Shell
