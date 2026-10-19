--!strict
-- Construction helpers shared by the venue interiors (bake-safe). Every venue is built in a local frame around its
-- Config/World interior slot origin: +X east, +Z south, floor top at y = 0; yaw 0 looks north (-Z).
--
--   Shell.frame(origin) -> Frame                       F.v(x, y, z) -> Vector3, F.cf(x, y, z, yaw?) -> CFrame
--   Shell.N, Shell.E, Shell.S, Shell.W                 yaws (degrees) whose LookVector points that way
--   Shell.box(parent, F, x0, y0, z0, x1, y1, z1, color, mat?, solid?) -> Part    axis-aligned block from two corners
--                                                       (solid = false -> a non-colliding Kit.detail)
--   Shell.wallX(parent, F, z, x0, x1, y0, y1, t, color, mat?, gaps?) -> { Part }   wall along X centred on z
--   Shell.wallZ(parent, F, x, z0, z1, y0, y1, t, color, mat?, gaps?) -> { Part }   wall along Z centred on x
--       gaps = { { c = centre along the wall, w = width, h = height above y0 } } (doorways: w >= 6, h >= 9)
--   Shell.glow(parent, cf, size, color?, light?) -> Part   a Neon fixture (tag InteriorLight); light = PointLight props
--   Shell.downlight(parent, cf, d?, light?) -> Part        a round recessed ceiling light (tag InteriorLight)
--   Shell.plate(parent, cf, w, h, text, o?) -> Part        a sign plate (cf on the wall face, LookVector out)
--   Shell.exit(parent, mk, doorId, cf, o?) -> Part         the way out: the doors on the wall, a lit sign above and
--                                                          the Door trigger in front (cf = the doorway's centre at
--                                                          floor level on the wall face, LookVector into the room)
--   Shell.boundary(parent, F, x0, z0, x1, z1, y0, y1)      four invisible, colliding walls around a rectangle
--   Shell.settle(root)                                     copies every part's CFrame position into Position (Lune
--                                                          keeps them separate; the bake reads Position)

local Deps = require(script.Parent.Deps)
local Markers = require(script.Parent.Markers)
local Paint = require(script.Parent.Paint)

local Kit = Deps.Kit
local hex = Deps.Palette.hex
local M = Enum.Material

local Shell = {}

export type Frame = {
	origin: Vector3,
	v: (x: number, y: number, z: number) -> Vector3,
	cf: (x: number, y: number, z: number, yaw: number?) -> CFrame,
}

export type Gap = { c: number, w: number, h: number }

function Shell.frame(origin: Vector3): Frame
	local function v(x: number, y: number, z: number): Vector3
		return origin + Vector3.new(x, y, z)
	end
	local function cf(x: number, y: number, z: number, yaw: number?): CFrame
		local c = CFrame.new(origin + Vector3.new(x, y, z))
		if yaw and yaw ~= 0 then
			c *= CFrame.Angles(0, math.rad(yaw), 0)
		end
		return c
	end
	return { origin = origin, v = v, cf = cf }
end

Shell.N, Shell.E, Shell.S, Shell.W = 0, -90, 180, 90

function Shell.box(
	parent: Instance,
	F: Frame,
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
	local a, b = F.v(x0, y0, z0), F.v(x1, y1, z1)
	local mn = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local mx = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	local cf = CFrame.new((mn + mx) / 2)
	if solid == false then
		return Kit.detail(parent, cf, mx - mn, color, mat or M.SmoothPlastic)
	end
	return Kit.block(parent, cf, mx - mn, color, mat or M.SmoothPlastic)
end

local function runs(from: number, to: number, gaps: { Gap }?): ({ { number } }, { Gap })
	local list: { Gap } = {}
	if gaps then
		for _, g in gaps do
			table.insert(list, g)
		end
	end
	table.sort(list, function(a, b)
		return a.c < b.c
	end)
	local out: { { number } } = {}
	local cursor = from
	for _, g in list do
		local a, b = g.c - g.w / 2, g.c + g.w / 2
		if a > cursor then
			table.insert(out, { cursor, a })
		end
		cursor = math.max(cursor, b)
	end
	if to > cursor then
		table.insert(out, { cursor, to })
	end
	return out, list
end

function Shell.wallX(
	parent: Instance,
	F: Frame,
	z: number,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	t: number,
	color: Color3,
	mat: Enum.Material?,
	gaps: { Gap }?
): { Part }
	local parts: { Part } = {}
	local solid, list = runs(math.min(x0, x1), math.max(x0, x1), gaps)
	for _, r in solid do
		if r[2] - r[1] > 0.05 then
			local p = Shell.box(parent, F, r[1], y0, z - t / 2, r[2], y1, z + t / 2, color, mat)
			p.Name = "Wall"
			table.insert(parts, p)
		end
	end
	for _, g in list do
		if y0 + g.h < y1 - 0.05 then
			local p = Shell.box(parent, F, g.c - g.w / 2, y0 + g.h, z - t / 2, g.c + g.w / 2, y1, z + t / 2, color, mat)
			p.Name = "Lintel"
			table.insert(parts, p)
		end
	end
	return parts
end

function Shell.wallZ(
	parent: Instance,
	F: Frame,
	x: number,
	z0: number,
	z1: number,
	y0: number,
	y1: number,
	t: number,
	color: Color3,
	mat: Enum.Material?,
	gaps: { Gap }?
): { Part }
	local parts: { Part } = {}
	local solid, list = runs(math.min(z0, z1), math.max(z0, z1), gaps)
	for _, r in solid do
		if r[2] - r[1] > 0.05 then
			local p = Shell.box(parent, F, x - t / 2, y0, r[1], x + t / 2, y1, r[2], color, mat)
			p.Name = "Wall"
			table.insert(parts, p)
		end
	end
	for _, g in list do
		if y0 + g.h < y1 - 0.05 then
			local p = Shell.box(parent, F, x - t / 2, y0 + g.h, g.c - g.w / 2, x + t / 2, y1, g.c + g.w / 2, color, mat)
			p.Name = "Lintel"
			table.insert(parts, p)
		end
	end
	return parts
end

export type LightProps = { range: number?, brightness: number?, color: Color3?, kind: string?, face: Enum.NormalId? }

local WARM = hex("#FFE2B0")

local function addLight(part: BasePart, l: LightProps)
	local kind = l.kind or "point"
	local props: { [string]: any } = {
		Color = l.color or WARM,
		Range = l.range or 24,
		Brightness = l.brightness or 0.9,
	}
	if kind ~= "point" then
		props.Face = l.face or Enum.NormalId.Bottom
	end
	if kind == "spot" then
		props.Angle = 70
	end
	Kit.light(part, kind, props)
end

function Shell.glow(parent: Instance, cf: CFrame, size: Vector3, color: Color3?, light: LightProps?): Part
	local p = Kit.detail(parent, cf, size, color or hex("#FFF1D6"), M.Neon)
	p.Name = "LightFixture"
	p.CastShadow = false
	p:AddTag("InteriorLight")
	if light then
		addLight(p, light)
	end
	return p
end

function Shell.downlight(parent: Instance, cf: CFrame, d: number?, light: LightProps?): Part
	local p = Kit.cylinder(parent, cf, 0.12, d or 1.4, hex("#FFF4DE"), M.Neon, {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	p.Name = "Downlight"
	p:AddTag("InteriorLight")
	if light then
		addLight(p, light)
	end
	return p
end

export type PlateOpts = {
	color: Color3?,
	ink: Color3?,
	font: Enum.Font?,
	glow: boolean?,
	pps: number?,
	material: Enum.Material?,
	depth: number?,
	align: Enum.TextXAlignment?,
	padding: number?,
}

function Shell.plate(parent: Instance, cf: CFrame, w: number, h: number, text: string, o: PlateOpts?): Part
	local opts: PlateOpts = o or {}
	local depth = opts.depth or 0.12
	local p = Kit.detail(
		parent,
		cf * CFrame.new(0, 0, -depth / 2),
		Vector3.new(w, h, depth),
		opts.color or hex("#1C1E22"),
		opts.material or M.SmoothPlastic
	)
	p.Name = "Sign"
	Kit.sign(p, text, {
		font = opts.font or Enum.Font.GothamMedium,
		color = opts.ink or hex("#F4F1E6"),
		pixelsPerStud = opts.pps or 30,
		glow = opts.glow,
		padding = opts.padding or 0.1,
		align = opts.align,
	})
	return p
end

export type ExitOpts = {
	label: string,
	style: string?, -- "double" (default) | "glass" | "elevator"
	doorColor: Color3?,
	frameColor: Color3?,
	signColor: Color3?,
	inkColor: Color3?,
	font: Enum.Font?,
}

function Shell.exit(parent: Instance, mk: Instance, doorId: string, cf: CFrame, o: ExitOpts): Part
	local style = o.style or "double"
	local frameC = o.frameColor or hex("#2A2826")
	local dc = o.doorColor or hex("#3E2C20")
	local g = Kit.model(parent, "ExitDoor")
	Kit.detail(g, cf * CFrame.new(0, 4.9, 0.1), Vector3.new(8.6, 9.8, 0.4), frameC, M.Metal).Name = "DoorFrame"
	if style == "elevator" then
		for _, s in { -1, 1 } do
			Kit.detail(g, cf * CFrame.new(s * 1.9, 4.5, -0.2), Vector3.new(3.75, 8.8, 0.2), dc, M.Metal).Name =
				"ElevatorLeaf"
		end
		Kit.detail(g, cf * CFrame.new(0, 4.5, -0.32), Vector3.new(0.08, 8.8, 0.05), hex("#1A1A1A"), M.Metal).Name =
			"LeafSeam"
		local call = Kit.detail(g, cf * CFrame.new(5.6, 4.2, -0.15), Vector3.new(0.9, 1.6, 0.15), frameC, M.Metal)
		call.Name = "CallPanel"
		Shell.glow(g, cf * CFrame.new(5.6, 4.2, -0.26), Vector3.new(0.4, 0.4, 0.05), hex("#FFD27A"))
	else
		local glass = style == "glass"
		for _, s in { -1, 1 } do
			local leaf = Kit.detail(
				g,
				cf * CFrame.new(s * 1.95, 4.5, -0.2),
				Vector3.new(3.8, 8.8, 0.2),
				if glass then hex("#9FB8C6") else dc,
				if glass then M.Glass else M.Wood
			)
			leaf.Name = "DoorLeaf"
			if glass then
				leaf.Transparency = 0.45
			end
			Kit.detail(g, cf * CFrame.new(s * 0.5, 4.2, -0.42), Vector3.new(0.2, 2.6, 0.2), hex("#C9A54C"), M.Metal).Name =
				"Handle"
		end
	end
	local sign = Kit.detail(
		g,
		cf * CFrame.new(0, 10.9, -0.2),
		Vector3.new(6.4, 1.3, 0.25),
		o.signColor or hex("#14161A"),
		M.SmoothPlastic
	)
	sign.Name = "ExitSign"
	Kit.sign(sign, o.label, {
		font = o.font or Enum.Font.GothamMedium,
		color = o.inkColor or hex("#F2E6C4"),
		pixelsPerStud = 40,
		glow = true,
		padding = 0.12,
	})
	sign:AddTag("InteriorLight")
	return Markers.door(mk, doorId, cf * CFrame.new(0, 5, -1.3))
end

export type WindowOpts = {
	frame: Color3?,
	frameMaterial: Enum.Material?,
	mullions: number?, -- vertical mullions between panes (default: one per ~8 studs)
	transom: boolean?, -- a horizontal bar at two thirds of the height
	mood: string?,
	view: string?,
	horizon: number?,
	density: number?,
	pps: number?,
	sill: boolean?,
	glass: boolean?, -- a faint reflective pane in front of the painting
	maxDistance: number?,
}

-- A framed window onto a painted view. cf = the opening's centre on the wall face, LookVector into the room.
-- Returns the view panel (its SurfaceGui is named "View").
function Shell.window(parent: Instance, cf: CFrame, w: number, h: number, rng: Deps.RngT, o: WindowOpts?): Part
	local opts: WindowOpts = o or {}
	local fc = opts.frame or hex("#2B2B2D")
	local fm = opts.frameMaterial or M.Metal
	local view =
		Kit.detail(parent, cf * CFrame.new(0, 0, -0.05), Vector3.new(w, h, 0.1), hex("#9AB4C8"), M.SmoothPlastic)
	view.Name = "WindowView"
	view.CastShadow = false
	local gui, W, H = Paint.surface(view, Enum.NormalId.Front, opts.pps or 6, {
		glow = true,
		brightness = 1,
		maxDistance = opts.maxDistance or 260,
		name = "View",
	})
	Paint.skyline(gui, W, H, rng, {
		mood = opts.mood,
		view = opts.view,
		horizon = opts.horizon,
		density = opts.density,
	})
	if opts.glass then
		local pane = Kit.detail(parent, cf * CFrame.new(0, 0, -0.3), Vector3.new(w, h, 0.05), hex("#C9D8E2"), M.Glass)
		pane.Name = "WindowGlass"
		pane.Transparency = 0.82
		pane.Reflectance = 0.2
		pane.CastShadow = false
	end
	local t = 0.45
	for _, s in { -1, 1 } do
		Kit.detail(parent, cf * CFrame.new(s * (w / 2 + t / 2), 0, -0.2), Vector3.new(t, h + t * 2, 0.4), fc, fm).Name =
			"WindowJamb"
	end
	Kit.detail(parent, cf * CFrame.new(0, h / 2 + t / 2, -0.2), Vector3.new(w + t * 2, t, 0.4), fc, fm).Name =
		"WindowHead"
	if opts.sill ~= false then
		Kit.detail(parent, cf * CFrame.new(0, -h / 2 - 0.2, -0.45), Vector3.new(w + 1, 0.4, 0.9), fc, fm).Name =
			"WindowSill"
	end
	local n = opts.mullions or math.max(0, math.floor(w / 8 + 0.5) - 1)
	for i = 1, n do
		local x = -w / 2 + w * i / (n + 1)
		Kit.detail(parent, cf * CFrame.new(x, 0, -0.15), Vector3.new(0.25, h, 0.25), fc, fm).Name = "Mullion"
	end
	if opts.transom then
		Kit.detail(parent, cf * CFrame.new(0, h / 6, -0.15), Vector3.new(w, 0.25, 0.25), fc, fm).Name = "Transom"
	end
	return view
end

function Shell.boundary(
	parent: Instance,
	F: Frame,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	y0: number,
	y1: number
)
	local t = 2
	local function wall(a: Vector3, b: Vector3)
		local mn = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
		local mx = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
		local p = Kit.block(parent, CFrame.new((mn + mx) / 2), mx - mn, nil, nil, {
			Transparency = 1,
			CastShadow = false,
			CanQuery = false,
			CanTouch = false,
		})
		p.Name = "Boundary"
	end
	wall(F.v(x0 - t, y0, z0 - t), F.v(x1 + t, y1, z0))
	wall(F.v(x0 - t, y0, z1), F.v(x1 + t, y1, z1 + t))
	wall(F.v(x0 - t, y0, z0), F.v(x0, y1, z1))
	wall(F.v(x1, y0, z0), F.v(x1 + t, y1, z1))
end

function Shell.settle(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Position = d.CFrame.Position
		end
	end
end

return Shell
