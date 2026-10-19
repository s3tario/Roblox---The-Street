--!strict
-- Interior construction helpers for the Eastbridge venues (bake-safe). Every interior is built in a local frame around
-- its slot origin (Config/World.slotOrigin): +X east, +Z south, floor top at y = 0, LookVector of yaw 0 = north (-Z).
--
--   Shell.frame(origin) -> Frame                      F.v(x, y, z) -> Vector3, F.cf(x, y, z, yaw?) -> CFrame,
--                                                      F.facing(x, z, tx, tz, y?) -> CFrame looking at (tx, tz)
--   Shell.box(parent, F, x0, y0, z0, x1, y1, z1, color, mat?, solid?) -> Part     axis-aligned block (local corners)
--   Shell.wallX(parent, F, z, x0, x1, y0, y1, t, color, mat?, gaps?) -> { Part }  wall along X centred on z
--   Shell.wallZ(parent, F, x, z0, z1, y0, y1, t, color, mat?, gaps?) -> { Part }  wall along Z centred on x
--       gaps = { { c = centre along the wall, w = width, h = height above y0 } } (doorways: w >= 6, h >= 9)
--   Shell.troffer(parent, cf, size?, light?) -> Part   fluorescent ceiling panel (tag InteriorLight), optional light
--   Shell.window(parent, cf, w, h, rng, kind) -> Part  a framed window with a painted view (Paint.view kinds);
--                                                      cf = centre on the wall face, LookVector into the room
--   Shell.sign(parent, cf, w, h, text, o?) -> Part     a sign plate on a wall (cf on the wall, LookVector out)
--   Shell.chair(parent, cf, color?, back?) -> Part    a cheap 3-part chair (cf = floor point, facing LookVector)
--   Shell.exit(parent, mk, doorId, cf, o?) -> Part     the way out: double doors on the wall (decor), a lit EXIT sign
--                                                      above and the Door trigger in front (cf = the door's centre
--                                                      at floor level on the wall face, LookVector into the room)

local Deps = require(script.Parent.Deps)

local Kit = Deps.Kit
local Paint = Deps.Paint
local Markers = Deps.Markers
local hex = Deps.Palette.hex
local M = Enum.Material

local Shell = {}

export type Frame = {
	origin: Vector3,
	v: (x: number, y: number, z: number) -> Vector3,
	cf: (x: number, y: number, z: number, yaw: number?) -> CFrame,
	facing: (x: number, z: number, tx: number, tz: number, y: number?) -> CFrame,
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
	local function facing(x: number, z: number, tx: number, tz: number, y: number?): CFrame
		local p = origin + Vector3.new(x, y or 0, z)
		return CFrame.lookAt(p, origin + Vector3.new(tx, y or 0, tz))
	end
	return { origin = origin, v = v, cf = cf, facing = facing }
end

-- Yaw (degrees) whose LookVector points along each compass direction (same as the exterior Plan).
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

function Shell.troffer(parent: Instance, cf: CFrame, size: Vector3?, light: boolean?): Part
	local s = size or Vector3.new(2, 0.2, 4)
	local p = Kit.detail(parent, cf, s, hex("#F4F1E6"), M.Neon)
	p.Name = "Troffer"
	p.Transparency = 0.15
	p.CastShadow = false
	p:AddTag("InteriorLight")
	if light then
		Kit.light(p, "point", { Color = hex("#F4EEDC"), Range = 26, Brightness = 0.9 })
	end
	return p
end

function Shell.window(
	parent: Instance,
	cf: CFrame,
	w: number,
	h: number,
	rng: Deps.RngT,
	kind: string,
	frameColor: Color3?
): Part
	local fc = frameColor or hex("#E9E4D8")
	-- the view sits flush on the wall; frame and sill stand proud of it
	local view =
		Kit.detail(parent, cf * CFrame.new(0, 0, -0.06), Vector3.new(w, h, 0.1), hex("#9AA2A6"), M.SmoothPlastic)
	view.Name = "WindowView"
	view.CastShadow = false
	local gui, W, H = Paint.surface(view, Enum.NormalId.Front, 10, { maxDistance = 200 })
	Paint.view(gui, W, H, rng, kind)
	Paint.muntins(gui, 2, 2, fc, 0.03)
	Kit.detail(parent, cf * CFrame.new(0, -h / 2 - 0.2, -0.3), Vector3.new(w + 0.8, 0.3, 0.6), fc, M.SmoothPlastic).Name =
		"Sill"
	for _, sx in { -1, 1 } do
		Kit.detail(
			parent,
			cf * CFrame.new(sx * (w / 2 + 0.15), 0, -0.15),
			Vector3.new(0.3, h + 0.4, 0.3),
			fc,
			M.SmoothPlastic
		)
	end
	Kit.detail(parent, cf * CFrame.new(0, h / 2 + 0.15, -0.15), Vector3.new(w + 0.6, 0.3, 0.3), fc, M.SmoothPlastic)
	return view
end

export type SignOpts = { color: Color3?, ink: Color3?, font: Enum.Font?, glow: boolean?, pps: number? }

function Shell.sign(parent: Instance, cf: CFrame, w: number, h: number, text: string, o: SignOpts?): Part
	local opts: SignOpts = o or {}
	local p = Kit.detail(
		parent,
		cf * CFrame.new(0, 0, -0.06),
		Vector3.new(w, h, 0.12),
		opts.color or hex("#24262A"),
		M.SmoothPlastic
	)
	p.Name = "Sign"
	Kit.sign(p, text, {
		font = opts.font or Enum.Font.Oswald,
		color = opts.ink or hex("#F4F1E6"),
		pixelsPerStud = opts.pps or 30,
		glow = opts.glow,
		padding = 0.1,
	})
	return p
end

function Shell.chair(parent: Instance, cf: CFrame, color: Color3?, backColor: Color3?): Part
	local c = color or hex("#3C4A5E")
	local seat = Kit.block(parent, cf * CFrame.new(0, 1.75, 0), Vector3.new(1.9, 0.3, 1.9), c, M.Fabric)
	seat.Name = "Chair"
	Kit.detail(parent, cf * CFrame.new(0, 3.1, 0.85), Vector3.new(1.9, 2.4, 0.25), backColor or c, M.Fabric).Name =
		"ChairBack"
	Kit.detail(parent, cf * CFrame.new(0, 0.8, 0), Vector3.new(0.3, 1.6, 0.3), hex("#2A2A2A"), M.Metal).Name =
		"ChairLeg"
	return seat
end

export type ExitOpts = { label: string?, doorColor: Color3?, glass: boolean? }

function Shell.exit(parent: Instance, mk: Instance, doorId: string, cf: CFrame, o: ExitOpts?): Part
	local opts: ExitOpts = o or {}
	local dc = opts.doorColor or hex("#4A3A2C")
	-- frame, two leaves with push bars, a transom
	Kit.detail(parent, cf * CFrame.new(0, 4.9, -0.1), Vector3.new(8.6, 9.8, 0.2), hex("#2A2826"), M.Metal).Name =
		"DoorFrame"
	for _, s in { -1, 1 } do
		local leaf = Kit.detail(
			parent,
			cf * CFrame.new(s * 1.95, 4.5, -0.25),
			Vector3.new(3.8, 8.8, 0.2),
			dc,
			if opts.glass then M.Glass else M.Wood
		)
		leaf.Name = "DoorLeaf"
		if opts.glass then
			leaf.Transparency = 0.3
		end
		Kit.detail(parent, cf * CFrame.new(s * 1.95, 4, -0.42), Vector3.new(3, 0.25, 0.2), hex("#B8B8B0"), M.Metal).Name =
			"PushBar"
	end
	local sign =
		Kit.detail(parent, cf * CFrame.new(0, 10.8, -0.2), Vector3.new(4.4, 1.2, 0.25), hex("#1A1A1A"), M.SmoothPlastic)
	sign.Name = "ExitSign"
	Kit.sign(sign, opts.label or Deps.Text.exit, {
		font = Enum.Font.Highway,
		color = hex("#FF3B30"),
		pixelsPerStud = 40,
		glow = true,
	})
	sign:AddTag("InteriorLight")
	return Markers.door(mk, doorId, cf * CFrame.new(0, 5, -1.3))
end

return Shell
