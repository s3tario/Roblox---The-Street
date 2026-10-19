--!strict
-- The lobby hall's shell: the marble floor (border, nave runner, compass medallion), limestone walls with a nero
-- skirting, the soffit band with recessed downlights and the cove-lit coffer, four round columns with brass bands,
-- and the glass street facade with interior bronze fins, the portal and the revolving door (the exit sign sits on
-- the portal's transom). Players can never leave through the glass: barriers seal the facade and the door drum.
-- Bake-safe.

local Deps = require(script.Parent.Deps)
local Plan = require(script.Parent.Plan)
local Look = require(script.Parent.Look)

local Kit = Deps.Kit
local Geo = Deps.Geo
local Art = Deps.Art
local Markers = Deps.Markers
local Text = Deps.Text
local Props = Deps.Props
local Rng = Deps.Rng
local M = Enum.Material
local V = Vector3.new

local Hall = {}

local HX, Z0, Z1 = Plan.HALF_X, Plan.MIN_Z, Plan.MAX_Z
local H, CH, W = Plan.HALL_H, Plan.COFFER_H, Plan.WALL
local E = Plan.elevatorHall

---------------------------------------------------------------------------------------------------
-- Floor
---------------------------------------------------------------------------------------------------
local function floor(m: Instance)
	local slab = Kit.block(m, CFrame.new(0, -0.5, 0), V(HX * 2 + W * 2, 1, (Z1 - Z0) + W * 2), Look.marble, M.Marble)
	slab.Name = "Floor"
	Art.tiles(slab, Enum.NormalId.Top, 6, 6, Look.marbleVein, { pps = 8, transparency = 0.6, offsetX = 3, offsetY = 3 })

	-- nero border band with a brass line on its inside edge
	local b0, b1 = 3.5, 5.2 -- distance of the band from the walls
	local x0, x1, z0, z1 = -HX + b0, HX - b0, Z0 + b0, Z1 - b0
	local t = b1 - b0
	for _, r in
		{
			{ V(x0, 0, z0), V(x1, 0.03, z0 + t) },
			{ V(x0, 0, z1 - t), V(x1, 0.03, z1) },
			{ V(x0, 0, z0 + t), V(x0 + t, 0.03, z1 - t) },
			{ V(x1 - t, 0, z0 + t), V(x1, 0.03, z1 - t) },
		}
	do
		Geo.box(m, r[1], r[2], Look.nero, M.Marble).Name = "Border"
	end
	local i0, i1, j0, j1 = x0 + t, x1 - t, z0 + t, z1 - t
	for _, r in
		{
			{ V(i0, 0, j0), V(i1, 0.04, j0 + 0.18) },
			{ V(i0, 0, j1 - 0.18), V(i1, 0.04, j1) },
			{ V(i0, 0, j0), V(i0 + 0.18, 0.04, j1) },
			{ V(i1 - 0.18, 0, j0), V(i1, 0.04, j1) },
		}
	do
		Geo.box(m, r[1], r[2], Look.brass, M.Metal).Name = "BrassInlay"
	end

	-- the nave runner from the door to reception, brass-edged
	local nz0, nz1 = Z0 + b1 + 0.2, Plan.reception.z - 2.6
	local runner = Geo.box(m, V(-4.6, 0, nz0), V(4.6, 0.05, nz1), Look.nero, M.Marble)
	runner.Name = "Runner"
	Art.veins(runner, Enum.NormalId.Top, "lobby-runner", Look.neroVein, { pps = 6, transparency = 0.7 })
	for _, sx in { -1, 1 } do
		Geo.box(m, V(sx * 4.6 - 0.12, 0, nz0), V(sx * 4.6 + 0.12, 0.06, nz1), Look.brass, M.Metal).Name = "BrassInlay"
	end

	-- the compass medallion (layered discs, each a touch higher so nothing flickers)
	local c = Plan.medallion
	local D = Plan.MEDALLION_D
	local function disc(y: number, d: number, color: Color3, mat: Enum.Material): Part
		local p = Geo.cyl(m, CFrame.new(c.X, y, c.Z), 0.02, d, color, mat)
		p.CastShadow = false
		return p
	end
	disc(0.07, D, Look.brass, M.Metal).Name = "Medallion"
	disc(0.09, D - 0.6, Look.nero, M.Marble)
	for k = 0, 3 do
		local bar = Kit.detail(
			m,
			CFrame.new(c.X, 0.1, c.Z) * Kit.rotY(k * 45),
			V(0.9, 0.02, D - 1.4),
			if k % 2 == 0 then Look.brass else Look.marbleWarm,
			M.Metal
		)
		bar.Name = "CompassPoint"
		bar.CastShadow = false
	end
	disc(0.12, D * 0.62, Look.brass, M.Metal)
	disc(0.14, D * 0.6, Look.marble, M.Marble)
	disc(0.16, 1.4, Look.brass, M.Metal)
end

---------------------------------------------------------------------------------------------------
-- Walls, soffit and coffer
---------------------------------------------------------------------------------------------------
local function stoneWall(m: Instance, a: Vector3, b: Vector3, face: Enum.NormalId, seed: string): Part
	local p = Geo.box(m, a, b, Look.limestone, M.Limestone, true)
	p.Name = "Wall"
	Art.tiles(p, face, 8, 4, Look.limestoneDark, { pps = 6, transparency = 0.45, offsetX = (#seed % 3) * 2 })
	return p
end

local function walls(m: Instance)
	-- north (behind the logo wall), west, and east around the elevator hall mouth
	stoneWall(m, V(-HX - W, 0, Z1), V(HX + W, CH, Z1 + W), Enum.NormalId.Front, "north")
	stoneWall(m, V(-HX - W, 0, Z0), V(-HX, CH, Z1), Enum.NormalId.Right, "west")
	stoneWall(m, V(HX, 0, Z0), V(HX + W, CH, E.minZ), Enum.NormalId.Left, "east-s")
	stoneWall(m, V(HX, 0, E.maxZ), V(HX + W, CH, Z1), Enum.NormalId.Left, "east-n")
	stoneWall(m, V(HX, E.height, E.minZ), V(HX + W, CH, E.maxZ), Enum.NormalId.Left, "east-lintel")

	-- nero skirting (the facade has its own plinth)
	local s = 0.9
	Geo.box(m, V(-HX, 0, Z1 - 0.12), V(HX, s, Z1), Look.nero, M.Marble).Name = "Skirting"
	Geo.box(m, V(-HX, 0, Z0), V(-HX + 0.12, s, Z1), Look.nero, M.Marble).Name = "Skirting"
	Geo.box(m, V(HX - 0.12, 0, Z0), V(HX, s, E.minZ), Look.nero, M.Marble).Name = "Skirting"
	Geo.box(m, V(HX - 0.12, 0, E.maxZ), V(HX, s, Z1), Look.nero, M.Marble).Name = "Skirting"

	-- the hall mouth's brass portal frame
	Geo.box(m, V(HX - 0.3, 0, E.minZ - 0.5), V(HX + 0.2, E.height + 0.5, E.minZ), Look.brass, M.Metal).Name =
		"PortalFrame"
	Geo.box(m, V(HX - 0.3, 0, E.maxZ), V(HX + 0.2, E.height + 0.5, E.maxZ + 0.5), Look.brass, M.Metal).Name =
		"PortalFrame"
	Geo.box(m, V(HX - 0.3, E.height, E.minZ), V(HX + 0.2, E.height + 0.5, E.maxZ), Look.brass, M.Metal).Name =
		"PortalFrame"

	-- a stone string course at the first-storey line ties the double-height walls together
	local y0, y1 = 16.4, 17.4
	local course = Kit.shade(Look.limestone, -0.08)
	Geo.box(m, V(-HX, y0, Z1 - 0.7), V(HX, y1, Z1), course, M.Limestone).Name = "StringCourse"
	Geo.box(m, V(-HX, y0, Z0 + 1), V(-HX + 0.7, y1, Z1 - 0.7), course, M.Limestone).Name = "StringCourse"
	Geo.box(m, V(HX - 0.7, y0, Z0 + 1), V(HX, y1, E.minZ - 0.5), course, M.Limestone).Name = "StringCourse"
	Geo.box(m, V(HX - 0.7, y0, E.maxZ + 0.5), V(HX, y1, Z1 - 0.7), course, M.Limestone).Name = "StringCourse"

	-- bronze sconces in the bays the furniture leaves free
	local sconces = {
		{ V(-HX + 0.15, 10.5, -30), V(1, 0, 0) },
		{ V(-HX + 0.15, 10.5, 12), V(1, 0, 0) },
		{ V(HX - 0.15, 10.5, -11.5), V(-1, 0, 0) },
		{ V(HX - 0.15, 10.5, 13), V(-1, 0, 0) },
		{ V(-30, 10.5, Z1 - 0.15), V(0, 0, -1) },
		{ V(30, 10.5, Z1 - 0.15), V(0, 0, -1) },
	}
	for i, s in sconces do
		local cf = CFrame.lookAt(s[1], s[1] + s[2])
		Kit.detail(m, cf * CFrame.new(0, 0, -0.08), V(0.9, 2.2, 0.16), Look.brassDark, M.Metal).Name = "SconcePlate"
		local glow = Geo.cyl(m, cf * CFrame.new(0, 0.2, -0.55), 1.6, 0.7, Look.onyx, M.Glass)
		glow.Name = "Sconce"
		glow.Transparency = 0.15
		glow:AddTag("InteriorLight")
		if i == 1 or i == 4 then
			Geo.light(glow, "point", { Range = 14, Brightness = 0.7, Color = Look.warmLight })
		end
	end

	-- a coir mat just inside the door
	local mat = Geo.box(m, V(-6, 0, Z0 + 1.2), V(6, 0.08, Z0 + 7), Look.nero, M.Fabric)
	mat.Name = "EntryMat"
	mat.Color = Kit.hex("#2E2A26")
end

local function ceiling(m: Instance)
	local top =
		Kit.block(m, CFrame.new(0, CH + 0.6, 0), V(HX * 2 + W * 2, 1.2, (Z1 - Z0) + W * 2), Look.plaster, M.Plaster)
	top.Name = "Coffer"
	-- the soffit band around the hall, 2 studs below the coffer, with recessed downlights painted on its underside
	local S = Plan.SOFFIT
	local bands = {
		{ V(-HX, H, Z0), V(HX, CH, Z0 + S) },
		{ V(-HX, H, Z1 - S), V(HX, CH, Z1) },
		{ V(-HX, H, Z0 + S), V(-HX + S, CH, Z1 - S) },
		{ V(HX - S, H, Z0 + S), V(HX, CH, Z1 - S) },
	}
	for i, r in bands do
		local band = Geo.box(m, r[1], r[2], Look.plaster, M.Plaster, true)
		band.Name = "Soffit"
		local gui, gw, gh =
			Deps.Gui.Core.surface(band, Enum.NormalId.Bottom, { pps = 4, glow = true, name = "Downlights" })
		local step = 6 * 4
		local along = math.max(gw, gh)
		local t = step / 2
		while t < along do
			if gw >= gh then
				Deps.Gui.Core.dot(gui, t, gh / 2, 3.2, Look.warmLight)
			else
				Deps.Gui.Core.dot(gui, gw / 2, t, 3.2, Look.warmLight)
			end
			t += step
		end
		-- a cove strip on the band's inner edge washes the coffer
		local a, b = r[1], r[2]
		local cove: Part
		if i == 1 then
			cove =
				Geo.box(m, V(a.X + S, CH - 0.35, b.Z - 0.05), V(b.X - S, CH - 0.05, b.Z + 0.25), Look.warmLight, M.Neon)
		elseif i == 2 then
			cove =
				Geo.box(m, V(a.X + S, CH - 0.35, a.Z - 0.25), V(b.X - S, CH - 0.05, a.Z + 0.05), Look.warmLight, M.Neon)
		elseif i == 3 then
			cove = Geo.box(m, V(b.X - 0.05, CH - 0.35, a.Z), V(b.X + 0.25, CH - 0.05, b.Z), Look.warmLight, M.Neon)
		else
			cove = Geo.box(m, V(a.X - 0.25, CH - 0.35, a.Z), V(a.X + 0.05, CH - 0.05, b.Z), Look.warmLight, M.Neon)
		end
		cove.Name = "Cove"
		cove:AddTag("InteriorLight")
		if i <= 2 then
			Geo.light(band, "surface", {
				Face = Enum.NormalId.Bottom,
				Range = 24,
				Brightness = 0.9,
				Angle = 120,
				Color = Look.warmLight,
			})
		end
	end
end

local function columns(m: Instance)
	local d = Plan.COLUMN_D
	for _, c in Plan.columns do
		local shaft = Geo.cyl(m, CFrame.new(c.X, H / 2, c.Z), H, d, Look.marbleWarm, M.Marble, true)
		shaft.Name = "Column"
		Geo.cyl(m, CFrame.new(c.X, 0.6, c.Z), 1.2, d + 0.7, Look.nero, M.Marble, true).Name = "Plinth"
		local ring = Geo.cyl(m, CFrame.new(c.X, 1.35, c.Z), 0.3, d + 0.3, Look.brass, M.Metal)
		ring.Reflectance = 0.2
		local cap = Geo.cyl(m, CFrame.new(c.X, H - 2.2, c.Z), 0.9, d + 0.4, Look.brass, M.Metal)
		cap.Name = "CapitalBand"
		cap.Reflectance = 0.2
	end
end

---------------------------------------------------------------------------------------------------
-- The street facade
---------------------------------------------------------------------------------------------------
local function curtainRun(m: Instance, x0: number, x1: number, seed: string)
	local width = x1 - x0
	local cx = (x0 + x1) / 2
	local grid = Kit.windowGrid(m, {
		cf = CFrame.lookAt(V(cx, H / 2, Z0), V(cx, H / 2, Z0 - 1)),
		width = width,
		height = H,
		cols = 6,
		rows = 2,
		glassColor = Look.glass,
		frameColor = Look.black,
		frameThickness = 0.35,
		depth = 0.5,
		glassTransparency = 0.72,
		glassReflectance = 0.1,
		seed = seed,
	})
	grid.Name = "CurtainWall"
	-- bronze fins on the inside of every mullion (the "brass mullions" of design §9)
	for c = 0, 6 do
		local x = x0 + width / 6 * c
		local fin = Kit.detail(m, CFrame.new(x, H / 2, Z0 + 0.65), V(0.3, H, 1.1), Look.brassDark, M.Metal)
		fin.Name = "Fin"
		fin.Reflectance = 0.12
	end
	Geo.box(m, V(x0, 0, Z0 + 0.1), V(x1, 0.7, Z0 + 0.9), Look.nero, M.Marble, true).Name = "Plinth"
end

local function facade(m: Instance)
	local d = Plan.door
	local ph = d.portalHalf
	curtainRun(m, -HX, -ph, "lobby-w")
	curtainRun(m, ph, HX, "lobby-e")

	-- the portal: stone pilasters, a brass transom carrying the exit sign, glass above to the soffit
	for _, sx in { -1, 1 } do
		Geo.box(
			m,
			V(sx * (d.radius + 0.25), 0, Z0 - 0.8),
			V(sx * ph, d.portalTop, Z0 + 0.8),
			Look.limestone,
			M.Limestone,
			true
		).Name =
			"Pilaster"
	end
	local transom = Geo.box(m, V(-ph, 9.7, Z0 - 0.6), V(ph, d.portalTop, Z0 + 0.6), Look.brass, M.Metal, true)
	transom.Name = "Transom"
	Kit.sign(transom, Text.get("lobby_exit"), {
		face = Enum.NormalId.Back,
		color = Look.nero,
		font = Enum.Font.GothamMedium,
		pixelsPerStud = 40,
		padding = 0.18,
	})
	local over = Geo.glass(m, CFrame.new(0, (d.portalTop + H) / 2, Z0), V(ph * 2, H - d.portalTop, 0.3), Look.glass)
	over.Transparency = 0.72
	Geo.box(m, V(-ph, H - 0.4, Z0 - 0.3), V(ph, H, Z0 + 0.3), Look.black, M.Metal).Name = "Head"

	-- the revolving door (Props), else a plain drum
	local drum = Props.tryBuild("revolving_door", m, CFrame.new(d.x, 0, d.z), { accent = Look.brass, seed = "lobby" })
	if not drum then
		local fallback = Geo.cyl(m, CFrame.new(d.x, 4.8, d.z), 9.6, d.radius * 2, Look.glass, M.Glass)
		fallback.Transparency = 0.6
		fallback.Name = "RevolvingDoor"
		Geo.cyl(m, CFrame.new(d.x, 9.75, d.z), 0.5, d.radius * 2 + 0.4, Look.brass, M.Metal)
	end

	-- the canopy outside over the door
	local canopy = Geo.box(m, V(-9, 12, Z0 - 7), V(9, 12.8, Z0 - 0.6), Look.nero, M.Marble)
	canopy.Name = "Canopy"
	Geo.box(m, V(-9.1, 11.8, Z0 - 7.1), V(9.1, 12.1, Z0 - 0.6), Look.brass, M.Metal).Name = "CanopyEdge"

	-- nobody walks out through the glass or the drum
	local b = Kit.folder(m, "Boundary")
	Markers.barrier(b, CFrame.new(0, H / 2 + 1, Z0 - 1.9), V(HX * 2 + 4, H + 6, 1))
	Markers.barrier(b, CFrame.new(d.x, 6, d.z), V(d.radius * 2 + 0.8, 12, 0.6))
end

function Hall.build(parent: Instance): Model
	local m = Kit.model(parent, "Hall")
	floor(m)
	walls(m)
	ceiling(m)
	columns(m)
	facade(m)
	-- a little variation in the stone so the hall doesn't read as one flat colour
	local rng = Rng.new("lobby-stone")
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") and d.Name == "Wall" then
			d.Color = Kit.shade(d.Color, rng:range(-0.04, 0.03))
		end
	end
	return m
end

return Hall
