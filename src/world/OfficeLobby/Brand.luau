--!strict
-- The lobby's branded heart (contracts §11: OfficeService re-skins these parts on every clone):
--   Brand.logoWall(parent)    black marble feature wall with brass reveals, the big backlit onyx "CompanyLogo" panel
--                             (LogoFace Front) and, below it, the FirmColor band with the "CompanyName" TextLabel;
--                             a planted light trough uplights it
--   Brand.reception(parent)   the marble reception desk (CompanyName plate, FirmColor inset, screens, orchid) and the
--                             walnut credenza behind it; OfficeAnchor "receptionist" stands between them (init)
--   Brand.chandelier(parent)  two brass light rings over the compass medallion
--   Brand.banners(parent)     four FirmColor banners on the upper walls, each with a CompanyLogo plate
-- Bake-safe.

local Deps = require(script.Parent.Deps)
local Plan = require(script.Parent.Plan)
local Look = require(script.Parent.Look)

local Kit = Deps.Kit
local Geo = Deps.Geo
local Art = Deps.Art
local Text = Deps.Text
local Core = Deps.Core
local Style = Deps.Style
local Rng = Deps.Rng
local M = Enum.Material
local V = Vector3.new

local Brand = {}

---------------------------------------------------------------------------------------------------
-- Logo wall
---------------------------------------------------------------------------------------------------
function Brand.logoWall(parent: Instance): Model
	local L = Plan.logoWall
	local m = Kit.model(parent, "LogoWall")
	local fz = L.faceZ
	local body = Geo.box(m, V(L.minX, 0, fz), V(L.maxX, Plan.COFFER_H, Plan.MAX_Z), Look.nero, M.Marble, true)
	body.Name = "FeatureWall"
	Art.veins(body, Enum.NormalId.Front, "logo-wall", Look.neroVein, { pps = 6, count = 18 })
	-- brass reveals framing the panel zone
	for _, x in { L.minX + 4, L.maxX - 4 } do
		Geo.box(m, V(x - 0.15, 0, fz - 0.1), V(x + 0.15, Plan.HALL_H, fz), Look.brass, M.Metal).Name = "Reveal"
	end
	Geo.box(m, V(L.minX + 4, 26.5, fz - 0.1), V(L.maxX - 4, 26.8, fz), Look.brass, M.Metal).Name = "Reveal"

	-- the logo panel: warm onyx, framed in brass, with a glowing halo behind it
	local lw, lh, ly = 26, 11, 18.5
	local halo = Kit.detail(m, CFrame.new(0, ly, fz - 0.15), V(lw + 1.2, lh + 1.2, 0.2), Look.warmLight, M.Neon)
	halo.Name = "Halo"
	halo:AddTag("InteriorLight")
	local logo = Core.logoPanel(m, CFrame.new(0, ly, fz - 0.6), V(lw, lh, 0.5), Look.onyx, M.SmoothPlastic)
	logo.CastShadow = false
	for _, r in
		{
			{ V(-lw / 2 - 0.3, ly - lh / 2 - 0.3, fz - 0.95), V(lw / 2 + 0.3, ly - lh / 2, fz - 0.3) },
			{ V(-lw / 2 - 0.3, ly + lh / 2, fz - 0.95), V(lw / 2 + 0.3, ly + lh / 2 + 0.3, fz - 0.3) },
			{ V(-lw / 2 - 0.3, ly - lh / 2, fz - 0.95), V(-lw / 2, ly + lh / 2, fz - 0.3) },
			{ V(lw / 2, ly - lh / 2, fz - 0.95), V(lw / 2 + 0.3, ly + lh / 2, fz - 0.3) },
		}
	do
		Geo.box(m, r[1], r[2], Look.brass, M.Metal).Name = "LogoFrame"
	end

	-- the company name on the FirmColor band
	Core.nameBand(m, CFrame.new(0, 10.4, fz - 0.25), V(30, 2.8, 0.3), Style.ib, Look.onyx)
	Geo.box(m, V(-15, 11.8, fz - 0.42), V(15, 11.95, fz - 0.1), Look.brass, M.Metal).Name = "BandEdge"
	Geo.box(m, V(-15, 8.85, fz - 0.42), V(15, 9.0, fz - 0.1), Look.brass, M.Metal).Name = "BandEdge"

	-- a planted light trough uplights the wall
	local trough = Geo.box(m, V(L.minX + 2, 0, fz - 2.4), V(L.maxX - 2, 1.6, fz), Look.nero, M.Marble, true)
	trough.Name = "Trough"
	Geo.box(m, V(L.minX + 2.3, 1.6, fz - 2.1), V(L.maxX - 2.3, 2.3, fz - 0.3), Look.leaf, M.LeafyGrass).Name =
		"Greenery"
	for _, x in { -11, 11 } do
		local up = Kit.detail(m, CFrame.new(x, 1.65, fz - 0.6), V(1.4, 0.1, 0.6), Look.warmLight, M.Neon)
		up.Name = "Uplight"
		up:AddTag("InteriorLight")
		Geo.light(
			up,
			"spot",
			{ Face = Enum.NormalId.Top, Range = 26, Brightness = 2.2, Angle = 55, Color = Look.warmLight }
		)
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- Reception
---------------------------------------------------------------------------------------------------
function Brand.reception(parent: Instance): Model
	local R = Plan.reception
	local m = Kit.model(parent, "Reception")
	local rng = Rng.new("lobby-reception")
	local hl, hd = R.length / 2, R.depth / 2
	local fz = R.z - hd -- the visitors' side
	-- marble front and returns
	local front = Geo.box(m, V(-hl, 0.4, fz), V(hl, 3.8, fz + 1.1), Look.marbleWarm, M.Marble, true)
	front.Name = "DeskFront"
	Art.veins(front, Enum.NormalId.Front, "reception", Look.marbleVein, { pps = 12, count = 10 })
	Geo.box(m, V(-hl + 0.3, 0, fz + 0.3), V(hl - 0.3, 0.4, fz + 1.1), Look.nero, M.Marble, true).Name = "Kick"
	for _, sx in { -1, 1 } do
		Geo.box(m, V(sx * hl, 0, fz), V(sx * (hl - 1.2), 3.8, fz + R.depth), Look.marbleWarm, M.Marble, true).Name =
			"Return"
	end
	-- the FirmColor inset and the brass name plate
	local inset = Geo.box(m, V(-hl + 1, 1.2, fz - 0.06), V(hl - 1, 1.5, fz), Look.firm, M.SmoothPlastic)
	inset.Name = "FirmInset"
	inset:AddTag("FirmColor")
	local plate = Kit.detail(m, CFrame.new(0, 2.55, fz - 0.05), V(8, 1, 0.08), Look.brass, M.Metal)
	plate.Name = "NamePlate"
	local label = Kit.sign(plate, Text.get("company_placeholder"), {
		color = Look.nero,
		font = Enum.Font.GothamBold,
		pixelsPerStud = 40,
		padding = 0.14,
	})
	label.Name = "CompanyName"
	-- walnut transaction ledge, the inner worktop and the receptionist's screens
	Geo.box(m, V(-hl - 0.2, 3.8, fz - 0.4), V(hl + 0.2, 4.0, fz + 1.2), Look.walnut, M.Wood, true).Name = "Ledge"
	Geo.box(m, V(-hl + 0.6, 2.55, fz + 1.1), V(hl - 0.6, 2.7, fz + R.depth - 0.2), Look.walnut, M.Wood, true).Name =
		"Worktop"
	for _, x in { -3.2, 3.2 } do
		local screen = Kit.detail(
			m,
			CFrame.lookAt(V(x, 3.55, fz + 1.6), V(x, 3.55, fz + 3)),
			V(2.2, 1.3, 0.1),
			Look.black,
			M.SmoothPlastic
		)
		screen.Name = "Screens"
		Art.monitors(screen, 1, { if x < 0 then "email" else "quotes" }, rng, { pps = 60 })
	end
	-- visitors sign and an orchid on the ledge
	local sign =
		Kit.detail(m, CFrame.new(-6.2, 4.4, fz + 0.2) * Kit.rot(-10, 0, 0), V(3.6, 0.75, 0.08), Look.brass, M.Metal)
	sign.Name = "VisitorSign"
	Kit.sign(sign, Text.get("lobby_visitors"), {
		color = Look.nero,
		font = Enum.Font.GothamMedium,
		pixelsPerStud = 60,
		padding = 0.08,
	})
	local vase = Geo.cyl(m, CFrame.new(6.4, 4.45, fz + 0.4), 0.9, 0.6, Look.coolLight, M.Glass)
	vase.Transparency = 0.35
	Geo.cyl(m, CFrame.new(6.4, 5.4, fz + 0.4), 1.2, 0.06, Look.leaf, M.SmoothPlastic)
	local bloom = Kit.ball(m, CFrame.new(6.45, 6.0, fz + 0.3), 0.6, Kit.hex("#F2E3EE"), M.SmoothPlastic)
	Geo.ghost(bloom)

	-- walnut credenza on the logo-wall side (the receptionist stands between desk and credenza)
	local cz = R.z + 7
	Geo.box(m, V(-7, 0, cz), V(7, 3.1, cz + 1.8), Look.walnut, M.Wood, true).Name = "Credenza"
	Geo.box(m, V(-7.1, 3.1, cz - 0.05), V(7.1, 3.25, cz + 1.85), Look.nero, M.Marble).Name = "CredenzaTop"
	Geo.box(m, V(-6.9, 1.5, cz - 0.04), V(6.9, 1.6, cz), Look.brass, M.Metal).Name = "CredenzaLine"
	for i, x in { -4.5, 4.5 } do
		local pot = Geo.cyl(m, CFrame.new(x, 3.85, cz + 0.9), 1.2, 1, Look.black, M.SmoothPlastic)
		pot.Name = "Pot"
		local leaves = Kit.ball(m, CFrame.new(x, 5, cz + 0.9), 1.8 + i * 0.1, Look.leaf, M.LeafyGrass)
		Geo.ghost(leaves)
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- Banners: tall FirmColor drops on the upper walls, each carrying a CompanyLogo plate
---------------------------------------------------------------------------------------------------
function Brand.banners(parent: Instance): Model
	local m = Kit.model(parent, "Banners")
	local hx = Plan.HALF_X
	local spots = {
		{ V(hx - 0.35, 0, -22), V(-1, 0, 0) },
		{ V(hx - 0.35, 0, 23), V(-1, 0, 0) },
		{ V(-hx + 0.35, 0, -13), V(1, 0, 0) },
		{ V(-hx + 0.35, 0, 21), V(1, 0, 0) },
	}
	local y0, y1 = 18.2, 29.2
	for _, s in spots do
		local base: Vector3, n: Vector3 = s[1], s[2]
		local cf = CFrame.lookAt(base + V(0, (y0 + y1) / 2, 0), base + V(0, (y0 + y1) / 2, 0) + n)
		local banner = Kit.detail(m, cf, V(6, y1 - y0, 0.12), Look.firm, M.Fabric)
		banner.Name = "Banner"
		banner:AddTag("FirmColor")
		local plate = Core.logoPanel(
			m,
			cf * CFrame.new(0, (y1 - y0) / 2 - 3.4, -0.12),
			V(4.6, 4.6, 0.1),
			Look.onyx,
			M.SmoothPlastic
		)
		plate.CastShadow = false
		local rodA = (cf * CFrame.new(-3.5, (y1 - y0) / 2 + 0.15, -0.1)).Position
		local rodB = (cf * CFrame.new(3.5, (y1 - y0) / 2 + 0.15, -0.1)).Position
		Geo.pipe(m, rodA, rodB, 0.22, Look.brass, M.Metal).Name = "BannerRod"
		local tail =
			Kit.detail(m, cf * CFrame.new(0, -(y1 - y0) / 2 + 0.6, -0.1), V(6, 0.3, 0.06), Look.firmAccent, M.Metal)
		tail.Name = "BannerTrim"
		tail:AddTag("FirmAccent")
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- Chandelier
---------------------------------------------------------------------------------------------------
local function ring(m: Instance, centre: Vector3, radius: number, segments: number, lit: { number })
	for i = 0, segments - 1 do
		local a = (i + 0.5) / segments * math.pi * 2
		local pos = centre + V(math.cos(a) * radius, 0, math.sin(a) * radius)
		local len = 2 * math.pi * radius / segments + 0.12
		local seg = Kit.detail(
			m,
			CFrame.lookAt(pos, centre), -- X runs along the ring
			V(len, 0.55, 0.45),
			Look.brass,
			M.Metal
		)
		seg.Name = "RingSegment"
		seg.Reflectance = 0.25
		seg:AddTag("InteriorLight")
		Art.glow(seg, Enum.NormalId.Bottom, Look.warmLight, 2.4)
		if table.find(lit, i) then
			Geo.light(seg, "point", { Range = 30, Brightness = 1.1, Color = Look.warmLight })
		end
	end
end

function Brand.chandelier(parent: Instance): Model
	local m = Kit.model(parent, "Chandelier")
	local c = Plan.medallion
	local outer = V(c.X, 21, c.Z)
	local inner = V(c.X, 18.6, c.Z)
	ring(m, outer, 8, 20, { 0, 10 })
	ring(m, inner, 4.8, 12, {})
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local p = outer + V(math.cos(a) * 8, 0, math.sin(a) * 8)
		Geo.pipe(m, V(p.X, Plan.COFFER_H, p.Z), V(p.X, p.Y + 0.27, p.Z), 0.08, Look.black).Name = "Cable"
		local q = inner + V(math.cos(a) * 4.8, 0, math.sin(a) * 4.8)
		Geo.pipe(m, V(q.X, Plan.COFFER_H, q.Z), V(q.X, q.Y + 0.27, q.Z), 0.06, Look.black).Name = "Cable"
	end
	Geo.cyl(m, CFrame.new(c.X, Plan.COFFER_H - 0.1, c.Z), 0.2, 3, Look.brass, M.Metal).Name = "Canopy"
	return m
end

return Brand
