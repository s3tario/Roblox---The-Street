--!strict
-- The Skyline Rooftop (venues feature; interior "rooftop", networking mixers in M3): an open teak deck on the 52nd
-- floor with the real sky above, a ring of painted skyline panels all round, a few neighbouring tower tops for depth
-- and the city spread out far below.
--
--   south      the express elevator pavilion: the elevator doors (door_rooftop_exit), the arrival point
--              (rooftop_entry) inside the pavilion and the SKYLINE sign on its roof; npc_mixer_host just outside
--   centre     the mixer lawn (EventSpot mixer_area) under criss-crossing string lights, with the DJ booth at its north
--              end and patio heaters at its corners
--   east       The High Note: a bar under a timber pergola hung with string lights, stools and a menu board
--   west       two lounges of outdoor sofas around fire pits
--   north      high-top tables along the parapet for taking in the view
--   edges      a stone border, a parapet with a glass balustrade and invisible boundary walls (nobody falls off)
--
-- String-light bulbs, heater glows and fire pits are tagged "StreetLight" (outdoor lights). build(parent?) -> Model
-- "Rooftop" (attributes Interior, LightingPreset). Bake-safe (contracts §15).

local Venue = script.Parent.CareerServices.Venue
local Deps = require(Venue.Deps)
local Shell = require(Venue.Shell)
local Paint = require(Venue.Paint)
local Markers = require(Venue.Markers)
local Furniture = require(Venue.Furniture)
local Text = require(Venue.Text)

local Kit = Deps.Kit
local Props = Deps.Props
local Core = Deps.Gui.Core
local hex = Deps.Palette.hex
local M = Enum.Material

local Rooftop = {}

Rooftop.ZONE = "rooftop"

-- deck extents (inside the parapet)
local X0, X1, Z0, Z1 = -60, 60, -50, 50
local PARAPET = 3.2
local RING_R = 178

local TEAK = hex("#9A6B45")
local STONE = hex("#B9B4AA")
local STONE_DARK = hex("#7D786F")
local STEEL = hex("#2E3236")
local BRASS = hex("#B8933F")
local CUSHION = hex("#E8E1D2")
local CUSHION_ALT = hex("#3E5B6B")
local BULB = hex("#FFD9A0")
local GLASS = hex("#CFE0E8")

local function outdoorLight(p: BasePart): BasePart
	p:AddTag("StreetLight")
	return p
end

---------------------------------------------------------------------------------------------------
-- String lights: a sagging wire from a to b with evenly spaced bulbs (world positions)
---------------------------------------------------------------------------------------------------
local function strand(parent: Instance, a: Vector3, b: Vector3, sag: number, bulbs: number)
	local m = Kit.model(parent, "StringLights")
	local function at(t: number): Vector3
		return a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
	end
	local segs = 4
	for i = 0, segs - 1 do
		local p0, p1 = at(i / segs), at((i + 1) / segs)
		local len = (p1 - p0).Magnitude
		Kit.detail(m, CFrame.lookAt((p0 + p1) / 2, p1), Vector3.new(0.08, 0.08, len), hex("#1A1A1A"), M.SmoothPlastic).Name =
			"Wire"
	end
	for i = 1, bulbs do
		local p = at(i / (bulbs + 1)) - Vector3.new(0, 0.3, 0)
		local bulb = Kit.ball(m, CFrame.new(p), 0.5, BULB, M.Neon, {
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		bulb.Name = "Bulb"
		outdoorLight(bulb)
	end
end

local function pole(parent: Instance, F: Shell.Frame, x: number, z: number, h: number): Vector3
	Kit.cylinder(parent, F.cf(x, h / 2, z), h, 0.4, STEEL, M.Metal).Name = "LightPole"
	Kit.cylinder(parent, F.cf(x, 0.15, z), 0.3, 1.4, STEEL, M.Metal, { CanCollide = false }).Name = "PoleFoot"
	return F.v(x, h - 0.2, z)
end

---------------------------------------------------------------------------------------------------
-- The deck, its edges and the view
---------------------------------------------------------------------------------------------------
local function deck(m: Instance, F: Shell.Frame)
	local d = Kit.model(m, "Deck")
	Shell.box(d, F, X0 - 4, -1, Z0 - 4, X1 + 4, 0, Z1 + 4, STONE, M.Slate).Name = "RoofSlab"
	local teak = Shell.box(d, F, X0 + 4, 0, Z0 + 4, X1 - 4, 0.12, Z1 - 4, TEAK, M.WoodPlanks, false)
	teak.Name = "Decking"
	teak.CastShadow = false
	local tg, TW, TH = Paint.surface(teak, Enum.NormalId.Top, 2, { maxDistance = 0 })
	Paint.grid(tg, TW, TH, 28, hex("#6E4A2E"), 0.7)
	-- the parapet with a glass balustrade and a steel handrail (the south side stops at the pavilion)
	local edge = Kit.model(m, "Parapet")
	local function run(x0: number, z0: number, x1: number, z1: number)
		Shell.box(edge, F, x0, 0, z0, x1, PARAPET, z1, STONE_DARK, M.Concrete).Name = "Parapet"
		local cx0, cx1 = math.min(x0, x1), math.max(x0, x1)
		local cz0, cz1 = math.min(z0, z1), math.max(z0, z1)
		local alongX = (cx1 - cx0) > (cz1 - cz0)
		local mx, mz = (cx0 + cx1) / 2, (cz0 + cz1) / 2
		local glass = if alongX
			then Shell.box(edge, F, cx0, PARAPET, mz - 0.1, cx1, PARAPET + 3, mz + 0.1, GLASS, M.Glass)
			else Shell.box(edge, F, mx - 0.1, PARAPET, cz0, mx + 0.1, PARAPET + 3, cz1, GLASS, M.Glass)
		glass.Name = "Balustrade"
		glass.Transparency = 0.7
		glass.Reflectance = 0.15
		local rail = if alongX
			then Shell.box(edge, F, cx0, PARAPET + 3, mz - 0.25, cx1, PARAPET + 3.3, mz + 0.25, STEEL, M.Metal, false)
			else Shell.box(
				edge,
				F,
				mx - 0.25,
				PARAPET + 3,
				cz0,
				mx + 0.25,
				PARAPET + 3.3,
				cz1,
				STEEL,
				M.Metal,
				false
			)
		rail.Name = "Handrail"
	end
	run(X0 - 1.5, Z0 - 1.5, X1 + 1.5, Z0)
	run(X0 - 1.5, Z0, X0, Z1 + 1.5)
	run(X1, Z0, X1 + 1.5, Z1 + 1.5)
	run(X0, Z1, -12.5, Z1 + 1.5)
	run(12.5, Z1, X1, Z1 + 1.5)
	Shell.boundary(m, F, X0 - 1.5, Z0 - 1.5, X1 + 1.5, Z1 + 1.5, -1, 40)
	-- our own tower dropping away below the deck
	local tower = Shell.box(d, F, X0 - 3, -19, Z0 - 3, X1 + 3, -1, Z1 + 3, hex("#5E7385"), M.Glass, false)
	tower.Name = "TowerBelow"
	tower.Transparency = 0
	local rng = Deps.Rng.new("roof-tower")
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui, W, H = Paint.surface(tower, face, 2, { maxDistance = 0 })
		Paint.facade(gui, W, H, rng, hex("#5E7385"), "day")
	end
end

local function view(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local v = Kit.model(m, "View")
	-- the city far below
	local city = Shell.box(v, F, -280, -20, -280, 280, -19, 280, hex("#6E7781"), M.SmoothPlastic, false)
	city.Name = "CityBelow"
	city.CastShadow = false
	local cg, CW, CH = Paint.surface(city, Enum.NormalId.Top, 1, { maxDistance = 0 })
	Paint.cityBelow(cg, CW, CH, rng, "day")
	-- the skyline ring: transparent panels painted with towers (no sky, so the real sky shows above them)
	local n = 16
	local w = 2 * math.pi * RING_R / n + 1.5
	local top, bottom = 72, -19
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local pos = F.v(math.cos(a) * RING_R, (top + bottom) / 2, math.sin(a) * RING_R)
		local panel = Kit.detail(
			v,
			CFrame.lookAt(pos, F.v(0, (top + bottom) / 2, 0)),
			Vector3.new(w, top - bottom, 0.2),
			hex("#8FA6B8"),
			M.SmoothPlastic
		)
		panel.Name = "SkylinePanel"
		panel.Transparency = 1
		panel.CastShadow = false
		local gui, W, H = Paint.surface(
			panel,
			Enum.NormalId.Front,
			3,
			{ glow = true, brightness = 1, maxDistance = 0, name = "Skyline" }
		)
		Paint.skyline(
			gui,
			W,
			H,
			rng,
			{ mood = "day", view = "high", sky = false, horizon = (top - 4) / (top - bottom), density = 1.2 }
		)
	end
	-- three neighbouring tower tops for parallax: a slim crown with a mast, a water-tower roof and a stepped spire
	local towers = {
		{ x = -118, z = -64, w = 30, d = 30, h = 46, color = hex("#7B8C99"), kind = "mast" },
		{ x = 128, z = 42, w = 34, d = 28, h = 24, color = hex("#9A8E7E"), kind = "water" },
		{ x = 44, z = -142, w = 26, d = 26, h = 70, color = hex("#5F7488"), kind = "spire" },
	}
	for i, t in towers do
		local tm = Kit.model(v, "NeighbourTower" .. i)
		local body = Shell.box(
			tm,
			F,
			t.x - t.w / 2,
			-19,
			t.z - t.d / 2,
			t.x + t.w / 2,
			t.h,
			t.z + t.d / 2,
			t.color,
			M.Concrete,
			false
		)
		body.Name = "TowerBody"
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
			local gui, W, H = Paint.surface(body, face, 1.5, { maxDistance = 0 })
			Paint.facade(gui, W, H, rng, t.color, "day")
		end
		Shell.box(
			tm,
			F,
			t.x - t.w / 2 - 0.5,
			t.h,
			t.z - t.d / 2 - 0.5,
			t.x + t.w / 2 + 0.5,
			t.h + 1.5,
			t.z + t.d / 2 + 0.5,
			Kit.shade(t.color, -0.2),
			M.Concrete,
			false
		).Name =
			"Coping"
		if t.kind == "mast" then
			Kit.detail(tm, F.cf(t.x, t.h + 12, t.z), Vector3.new(0.8, 22, 0.8), hex("#C9CDD2"), M.Metal).Name = "Mast"
			outdoorLight(Kit.detail(tm, F.cf(t.x, t.h + 23.3, t.z), Vector3.new(1, 1, 1), hex("#FF3B30"), M.Neon)).Name =
				"AviationLight"
		elseif t.kind == "water" then
			Kit.cylinder(tm, F.cf(t.x + 6, t.h + 9, t.z - 2), 8, 8, hex("#6B4A32"), M.WoodPlanks).Name = "WaterTank"
			Kit.cylinder(tm, F.cf(t.x + 6, t.h + 3, t.z - 2), 4, 6, STEEL, M.Metal).Name = "TankStand"
			Shell.box(
				tm,
				F,
				t.x - 12,
				t.h + 1.5,
				t.z + 2,
				t.x - 4,
				t.h + 6,
				t.z + 9,
				Kit.shade(t.color, -0.1),
				M.Concrete,
				false
			).Name =
				"Bulkhead"
		else
			Shell.box(
				tm,
				F,
				t.x - 8,
				t.h + 1.5,
				t.z - 8,
				t.x + 8,
				t.h + 12,
				t.z + 8,
				Kit.shade(t.color, 0.08),
				M.Glass,
				false
			).Name =
				"Setback"
			Kit.detail(tm, F.cf(t.x, t.h + 24, t.z), Vector3.new(2, 24, 2), hex("#D9DDE0"), M.Metal).Name = "Spire"
			outdoorLight(Kit.detail(tm, F.cf(t.x, t.h + 36.3, t.z), Vector3.new(1, 1, 1), hex("#FF3B30"), M.Neon)).Name =
				"AviationLight"
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The elevator pavilion (south)
---------------------------------------------------------------------------------------------------
local function pavilion(m: Instance, mk: Instance, F: Shell.Frame)
	local p = Kit.model(m, "Pavilion")
	local pz0 = 37
	local roofY = 13
	-- back wall (the elevator wall) runs across the gap in the parapet
	Shell.box(p, F, -12.5, 0, Z1, 12.5, roofY, Z1 + 1.5, hex("#2B2D30"), M.Granite).Name = "ElevatorWall"
	-- glass side walls on steel frames
	for _, sx in { -1, 1 } do
		local x = sx * 12
		local g = Shell.box(p, F, x - 0.15, 0, pz0, x + 0.15, roofY, Z1, GLASS, M.Glass)
		g.Name = "PavilionGlass"
		g.Transparency = 0.6
		g.Reflectance = 0.15
		Shell.box(p, F, x - 0.5, 0, pz0 - 0.5, x + 0.5, roofY, pz0 + 0.5, STEEL, M.Metal).Name = "PavilionPost"
	end
	Shell.box(p, F, -13, roofY, pz0 - 1, 13, roofY + 1.2, Z1 + 1.5, STEEL, M.Metal).Name = "PavilionRoof"
	Shell.box(p, F, -12, 0.12, pz0, 12, 0.2, Z1, hex("#2B2D30"), M.Granite, false).Name = "PavilionFloor"
	Shell.glow(p, F.cf(0, roofY - 0.1, 43.5), Vector3.new(16, 0.1, 6), hex("#FFF1D6"), { range = 22, brightness = 0.8 })
	Shell.exit(p, mk, "door_rooftop_exit", F.cf(0, 0, Z1, Shell.N), {
		label = Text.get("roof_elevator"),
		style = "elevator",
		doorColor = hex("#9EA3A8"),
		frameColor = BRASS,
		signColor = hex("#14161A"),
		inkColor = BULB,
	})
	Markers.anchor(mk, "rooftop_entry", F.cf(0, 3, 42, Shell.N))
	-- the SKYLINE sign on the roof's front edge, lit, facing the deck
	local sign =
		Kit.detail(p, F.cf(0, roofY + 3.2, pz0 - 0.6), Vector3.new(22, 4, 0.4), hex("#14161A"), M.SmoothPlastic)
	sign.Name = "SkylineSign"
	Kit.sign(sign, Text.get("roof_name"), {
		font = Enum.Font.Michroma,
		color = BULB,
		pixelsPerStud = 30,
		glow = true,
		padding = 0.06,
	})
	outdoorLight(sign)
	local sub =
		Kit.detail(p, F.cf(0, roofY + 0.6, pz0 - 1.05), Vector3.new(14, 0.9, 0.1), hex("#14161A"), M.SmoothPlastic)
	sub.Name = "SkylineSub"
	Kit.sign(sub, Text.get("roof_sub"), {
		font = Enum.Font.GothamMedium,
		color = hex("#F2E6C4"),
		pixelsPerStud = 40,
		glow = true,
	})
	-- planters flanking the pavilion mouth
	for _, sx in { -1, 1 } do
		Furniture.planter(p, F.cf(sx * 16, 0, 46), Vector3.new(5, 2.6, 5), { box = STONE_DARK })
	end
end

---------------------------------------------------------------------------------------------------
-- The mixer lawn, DJ booth and heaters
---------------------------------------------------------------------------------------------------
local function lawn(m: Instance, mk: Instance, F: Shell.Frame)
	local l = Kit.model(m, "MixerLawn")
	local lx0, lx1, lz0, lz1 = -18, 18, -22, 14
	local turf = Shell.box(l, F, lx0, 0.12, lz0, lx1, 0.22, lz1, hex("#4C7A3F"), M.Grass, false)
	turf.Name = "Turf"
	Shell.box(l, F, lx0 - 0.6, 0, lz0 - 0.6, lx1 + 0.6, 0.3, lz1 + 0.6, STONE_DARK, M.Concrete, false).Name = "TurfEdge"
	Markers.event(mk, "mixer_area", F.cf(0, 1, (lz0 + lz1) / 2), Vector3.new(lx1 - lx0, 1, lz1 - lz0))
	Markers.npc(mk, "npc_mixer_host", F.cf(8, 3, 24, 200))
	-- the DJ booth at the north end of the lawn
	local dj = Kit.model(l, "DJBooth")
	local dc = F.cf(0, 0, lz0 - 4.5, Shell.S)
	Kit.block(dj, dc * CFrame.new(0, 1.9, 0), Vector3.new(8, 3.8, 2.6), hex("#1A1C1F"), M.Metal).Name = "Booth"
	local front =
		Kit.detail(dj, dc * CFrame.new(0, 1.9, -1.32), Vector3.new(7.6, 3.2, 0.06), hex("#14161A"), M.SmoothPlastic)
	front.Name = "BoothFront"
	Kit.sign(
		front,
		Text.get("roof_dj"),
		{ font = Enum.Font.Michroma, color = hex("#7FD4FF"), pixelsPerStud = 30, glow = true }
	)
	outdoorLight(front)
	for _, sx in { -1, 1 } do
		Kit.detail(dj, dc * CFrame.new(sx * 1.9, 3.9, 0.2), Vector3.new(2.2, 0.15, 1.6), hex("#2B2D30"), M.Metal).Name =
			"Deck"
		Kit.block(dj, dc * CFrame.new(sx * 6, 2.6, 0.3), Vector3.new(2.2, 5.2, 2.2), hex("#141414"), M.SmoothPlastic).Name =
			"Speaker"
		Kit.cylinder(
			dj,
			dc * CFrame.new(sx * 6, 2, -0.82) * CFrame.Angles(math.rad(90), 0, 0),
			0.1,
			1.6,
			hex("#3A3A3A"),
			M.Metal,
			{
				CanCollide = false,
			}
		).Name =
			"Cone"
	end
	-- patio heaters at the lawn corners
	for _, c in { { lx0 - 3, lz0 - 2 }, { lx1 + 3, lz0 - 2 }, { lx0 - 3, lz1 + 2 }, { lx1 + 3, lz1 + 2 } } do
		local hm = Kit.model(l, "Heater")
		Kit.cylinder(hm, F.cf(c[1], 4.2, c[2]), 8.4, 0.35, STEEL, M.Metal).Name = "HeaterPole"
		Kit.cylinder(hm, F.cf(c[1], 0.2, c[2]), 0.4, 1.6, STEEL, M.Metal, { CanCollide = false }).Name = "HeaterBase"
		Kit.cylinder(hm, F.cf(c[1], 8.5, c[2]), 0.4, 3, STEEL, M.Metal, { CanCollide = false }).Name = "HeaterHood"
		outdoorLight(Kit.cylinder(hm, F.cf(c[1], 7.6, c[2]), 1.4, 0.9, hex("#FF8A3D"), M.Neon, {
			CanCollide = false,
			CanQuery = false,
		})).Name =
			"HeaterGlow"
	end
	-- string lights criss-crossing the lawn between eight poles
	local h = 14
	local nw, ne = pole(l, F, lx0 - 2, lz0 - 6, h), pole(l, F, lx1 + 2, lz0 - 6, h)
	local sw, se = pole(l, F, lx0 - 2, lz1 + 6, h), pole(l, F, lx1 + 2, lz1 + 6, h)
	local wm, em = pole(l, F, lx0 - 6, (lz0 + lz1) / 2, h), pole(l, F, lx1 + 6, (lz0 + lz1) / 2, h)
	strand(l, nw, se, 2.2, 16)
	strand(l, ne, sw, 2.2, 16)
	strand(l, wm, em, 1.6, 12)
	strand(l, nw, ne, 1.2, 10)
	strand(l, sw, se, 1.2, 10)
end

---------------------------------------------------------------------------------------------------
-- The High Note bar under its pergola (east)
---------------------------------------------------------------------------------------------------
local function bar(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local b = Kit.model(m, "HighNote")
	local bx, bz = 46, -6
	Props.build(
		"bar_counter",
		b,
		F.cf(bx, 0.12, bz, Shell.W),
		{ length = 22, color = hex("#2E2A26"), accent = BRASS, top = hex("#ECEAE6"), seed = "roof-bar" }
	)
	for i = 0, 5 do
		Furniture.stool(b, F.cf(bx - 3.6, 0.12, bz - 9 + i * 3.6), 3.4, CUSHION_ALT, STEEL)
	end
	-- back bar: a low cabinet with bottles and an ice well, and the bar's name on a lit fascia
	Shell.box(b, F, X1 - 3.2, 0, bz - 10, X1 - 0.6, 3.4, bz + 10, hex("#2E2A26"), M.Wood).Name = "BackBar"
	local bottles =
		Kit.detail(b, F.cf(X1 - 1.9, 4.3, bz, Shell.W), Vector3.new(19, 1.8, 0.1), hex("#2E2A26"), M.SmoothPlastic)
	bottles.Name = "Bottles"
	bottles.Transparency = 1
	local gui, W, H = Core.surface(bottles, Enum.NormalId.Front, { pps = 16, glow = true, maxDistance = 140 })
	local x = 4
	local palette = { hex("#2F5A3A"), hex("#C9A54C"), hex("#D9E4E8"), hex("#B5482F"), hex("#7FD4FF") }
	while x < W - 6 do
		local bw = rng:range(W * 0.012, W * 0.02)
		local bh = rng:range(H * 0.55, H * 0.95)
		local col = palette[rng:int(1, #palette)]
		Core.px(gui, x, H - bh, bw, bh, col, 0.05)
		Core.px(gui, x + bw * 0.3, H - bh - H * 0.12, bw * 0.4, H * 0.13, col, 0.05)
		x += bw + rng:range(2, W * 0.012)
	end
	-- the pergola: four posts, two beams, slats; string lights along it
	local px0, px1, pz0, pz1, ph = bx - 9, X1 - 0.5, bz - 13, bz + 13, 12
	for _, c in { { px0, pz0 }, { px1, pz0 }, { px0, pz1 }, { px1, pz1 } } do
		Shell.box(b, F, c[1] - 0.5, 0, c[2] - 0.5, c[1] + 0.5, ph, c[2] + 0.5, TEAK, M.Wood).Name = "PergolaPost"
	end
	for _, z in { pz0, pz1 } do
		Shell.box(b, F, px0 - 1, ph, z - 0.5, px1, ph + 1, z + 0.5, TEAK, M.Wood, false).Name = "PergolaBeam"
	end
	for i = 0, 7 do
		local sx = px0 + 0.5 + i * (px1 - px0 - 1) / 7
		Shell.box(b, F, sx - 0.25, ph + 1, pz0 - 1, sx + 0.25, ph + 1.6, pz1 + 1, TEAK, M.Wood, false).Name =
			"PergolaSlat"
	end
	local fascia = Kit.detail(
		b,
		F.cf(px0 - 0.6, ph + 0.5, bz, Shell.W),
		Vector3.new(12, 1.2, 0.2),
		hex("#14161A"),
		M.SmoothPlastic
	)
	fascia.Name = "BarSign"
	Kit.sign(fascia, Text.get("roof_bar"), { font = Enum.Font.Michroma, color = BULB, pixelsPerStud = 30, glow = true })
	outdoorLight(fascia)
	strand(b, F.v(px0, ph - 0.2, pz0), F.v(px0, ph - 0.2, pz1), 1.4, 12)
	strand(b, F.v(px1, ph - 0.2, pz0), F.v(px0, ph - 0.2, pz1), 1.8, 12)
	local glow = Shell.glow(
		b,
		F.cf(bx, ph - 0.2, bz),
		Vector3.new(0.4, 0.2, 0.4),
		BULB,
		{ range = 26, brightness = 1, color = BULB }
	)
	glow.Transparency = 1
	glow:RemoveTag("InteriorLight")
	outdoorLight(glow)
	-- the menu board on an easel by the bar's south end
	-- turned south-west, toward guests arriving from the elevator pavilion
	local menu = Kit.detail(b, F.cf(bx - 6, 3.6, bz + 15, 135), Vector3.new(3.2, 4.4, 0.2), hex("#1A1C1F"), M.Wood)
	menu.Name = "Menu"
	Kit.detail(b, F.cf(bx - 6, 1.3, bz + 15, 135) * CFrame.new(0, 0, 0.3), Vector3.new(2.6, 2.6, 0.2), TEAK, M.Wood).Name =
		"Easel"
	local mg = Core.surface(menu, Enum.NormalId.Front, { pps = 40, maxDistance = 100 })
	Core.bg(mg, hex("#1A1C1F"))
	Core.label(
		mg,
		Text.get("roof_menu_title"),
		0.08,
		0.06,
		0.84,
		0.14,
		BULB,
		{ font = Enum.Font.Michroma, align = Enum.TextXAlignment.Center }
	)
	for i, line in Text.list("roof_menu") do
		Core.label(mg, line, 0.08, 0.26 + (i - 1) * 0.16, 0.84, 0.1, hex("#F2E6C4"), { font = Enum.Font.GothamMedium })
	end
end

---------------------------------------------------------------------------------------------------
-- West lounges and north high-tops
---------------------------------------------------------------------------------------------------
local function lounges(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local l = Kit.model(m, "Lounges")
	for i, cz in { -24, 16 } do
		local g = Kit.model(l, "Lounge" .. i)
		local cx = -40
		Props.build("rug_modern", g, F.cf(cx, 0.13, cz), { color = hex("#D9D2C3"), seed = "roof-rug" .. i })
		Furniture.sofa(g, F.cf(cx - 7, 0.12, cz, Shell.E), 9, CUSHION, { accent = CUSHION_ALT, depth = 3.6 })
		Furniture.sofa(g, F.cf(cx, 0.12, cz - 7, Shell.S), 9, CUSHION, { accent = CUSHION_ALT, depth = 3.6 })
		Furniture.armchair(g, F.cf(cx + 6.5, 0.12, cz + 4, 45), CUSHION, { accent = CUSHION_ALT })
		-- the fire pit: a stone drum with an ember bed and a warm light
		Kit.cylinder(g, F.cf(cx, 0.9, cz), 1.8, 5, STONE_DARK, M.Slate).Name = "FirePit"
		local embers = Kit.cylinder(g, F.cf(cx, 1.85, cz), 0.15, 3.8, hex("#FF8A3D"), M.Neon, {
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		embers.Name = "Embers"
		embers:SetAttribute("Flicker", true)
		outdoorLight(embers)
		Kit.light(embers, "point", { Color = hex("#FF9A4D"), Range = 16, Brightness = 1.1 })
		Furniture.plant(g, F.cf(cx - 14, 0.12, cz - 9), 1.2, rng)
	end
	-- high-top tables along the north parapet
	for i = 0, 3 do
		local x = -21 + i * 14
		local t = Kit.model(l, "HighTop")
		Furniture.roundTable(t, F.cf(x, 0.12, Z0 + 4), 3, 3.6, hex("#ECEAE6"), STEEL)
		Furniture.stool(t, F.cf(x - 2.4, 0.12, Z0 + 5), 3.2, CUSHION_ALT, STEEL)
		Furniture.stool(t, F.cf(x + 2.4, 0.12, Z0 + 5), 3.2, CUSHION_ALT, STEEL)
	end
	-- planters with trees at the deck corners and box hedges along the parapet
	for i, c in { { X0 + 4, Z0 + 4 }, { X1 - 4, Z0 + 4 }, { X0 + 4, Z1 - 4 }, { X1 - 4, Z1 - 4 } } do
		Props.build("planter_tree", l, F.cf(c[1], 0.12, c[2]), { seed = "roof-tree" .. i })
	end
	for _, z in { -10, 2 } do
		Furniture.planter(l, F.cf(X0 + 2.6, 0.12, z), Vector3.new(3.2, 2.4, 8), { box = STONE_DARK })
	end
	for _, x in { -40, 40 } do
		Furniture.planter(l, F.cf(x, 0.12, Z0 + 2.6), Vector3.new(8, 2.4, 3.2), { box = STONE_DARK })
	end
	-- compass plaques on the parapet naming what lies each way
	for _, spec in
		{
			{ key = "roof_compass_n", cf = F.cf(0, PARAPET - 0.6, Z0, Shell.S) },
			{ key = "roof_compass_e", cf = F.cf(X1, PARAPET - 0.6, 30, Shell.W) },
			{ key = "roof_compass_w", cf = F.cf(X0, PARAPET - 0.6, -38, Shell.E) },
		}
	do
		Shell.plate(l, spec.cf, 6, 0.9, Text.get(spec.key), { color = hex("#2B2D30"), ink = BRASS, pps = 40 })
	end
end

---------------------------------------------------------------------------------------------------
local function origin(): Vector3
	return Deps.World.slotOrigin(Deps.World.interiors[Rooftop.ZONE].slot)
end

function Rooftop.build(parent: Instance?): Model
	local root = Kit.model(nil, "Rooftop")
	root:SetAttribute("Interior", Rooftop.ZONE)
	root:SetAttribute("LightingPreset", Deps.World.interiors[Rooftop.ZONE].lighting)
	local mk = Kit.folder(root, "Markers")
	local F = Shell.frame(origin())
	local rng = Deps.Rng.new("venue:rooftop")
	deck(root, F)
	view(root, F, rng)
	pavilion(root, mk, F)
	lawn(root, mk, F)
	bar(root, F, rng)
	lounges(root, F, rng)
	Shell.settle(root)
	root.Parent = parent
	return root
end

return Rooftop
