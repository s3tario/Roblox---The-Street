--!strict
-- The fenced construction lot behind the strip ("Eastbridge Commons", coming 2027, maybe): a plywood hoarding
-- plastered with posters along the back alley, chain-link on the other sides with a sagging bay you can slip through,
-- churned dirt with tyre ruts and mounds, a half-poured concrete frame with rebar and scaffolding, a parked excavator,
-- a tower crane that is visible from the whole town, the site trailer, a porta-john and the usual clutter. Bake-safe.

local Deps = require(script.Parent.Deps)
local Plan = require(script.Parent.Plan)
local Geo = require(script.Parent.Geo)
local Paint = require(script.Parent.Paint)
local Text = require(script.Parent.Text)
local Dress = require(script.Parent.Dress)

local Kit = Deps.Kit
local Props = Deps.Props
local Core = Deps.Gui.Core
local Art = Deps.Gui.Art
local P = Deps.Palette
local C = P.campus
local hex = P.hex
local M = Enum.Material

local Lot = {}

local WALK = Plan.WALK
local T = Plan.lot

local function L(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, y, z)
end

local YELLOW = hex("#C9A227")

---------------------------------------------------------------------------------------------------
local function ground(m: Instance, rng: Deps.RngT)
	local dirt =
		Geo.lbox(m, T.x0 + 0.5, WALK - 0.3, T.z0 + 0.5, T.x1 - 0.5, WALK + 0.06, T.z1 - 0.5, hex("#5E4C38"), M.Ground)
	dirt.Name = "Dirt"
	local gui, W, H = Paint.surface(dirt, Enum.NormalId.Top, 3)
	-- tyre ruts from the gate to the frame, gravel patches
	for _ = 1, 6 do
		local y = rng:range(H * 0.2, H * 0.8)
		Core.line(gui, rng:range(0, W * 0.2), y, rng:range(W * 0.6, W), y + rng:range(-40, 40), 8, hex("#3E3226"), 0.35)
	end
	for _ = 1, 10 do
		Core.dot(gui, rng:range(0, W), rng:range(0, H), rng:range(20, 60), hex("#7A7064"), 0.5)
	end
	-- mounds of spoil and sand (half-buried balls you can run over)
	local mounds: { { x: number, z: number, d: number, mat: Enum.Material } } = {
		{ x = -128, z = 120, d = 16, mat = M.Mud },
		{ x = -20, z = 186, d = 14, mat = M.Ground },
		{ x = 30, z = 128, d = 10, mat = M.Sand },
		{ x = -60, z = 112, d = 9, mat = M.Mud },
	}
	for i, mo in mounds do
		local color = if mo.mat == M.Sand then hex("#B39A6A") else Geo.vary(hex("#6A5640"), rng, 0.1)
		local b = Kit.ball(m, Plan.cf(mo.x, WALK - mo.d * 0.32, mo.z), mo.d, color, mo.mat)
		b.Name = "Mound" .. i
	end
	-- puddles in the ruts
	for i, pd in { { -80, 130, 2.6 }, { 0, 150, 1.8 }, { -120, 170, 2.2 } } do
		Props.build(
			"puddle",
			m,
			Plan.cf(pd[1], WALK + 0.07, pd[2], rng:range(0, 180)),
			{ size = pd[3], seed = "lot-puddle" .. i }
		)
	end
end

---------------------------------------------------------------------------------------------------
local function fences(m: Instance, rng: Deps.RngT)
	local h = 8
	local y = WALK
	-- the hoarding along the back alley (x -120..20), then chain-link to the corners with the sagging gap at gapX
	local hx0, hx1 = -120, 20
	local hoard = Geo.lbox(m, hx0, y, T.z0 - 0.3, hx1, y + h, T.z0 + 0.3, hex("#8E7A5A"), M.WoodPlanks)
	hoard.Name = "Hoarding"
	local gui, W, H = Paint.surface(hoard, Enum.NormalId.Front, 6)
	local bg = Core.bg(gui, hex("#E9E4D8"))
	Core.gradient(bg, hex("#F2EEE4"), hex("#CFC8B6"), 90)
	-- the developer's glossy render: a smug glass box under a blue sky
	local art = Core.frame(gui, 0.02, 0.08, 0.3, 0.84, hex("#7FB0D9"))
	Core.px(art, W * 0.05, H * 0.2, W * 0.15, H * 0.62, hex("#3E5E73"))
	Core.px(art, W * 0.08, H * 0.24, W * 0.09, H * 0.54, hex("#8FB3C9"))
	Core.px(art, 0, H * 0.75, W * 0.3, H * 0.1, hex("#3F6B3A"))
	Core.label(
		gui,
		Text.lotHoarding,
		0.34,
		0.12,
		0.62,
		0.42,
		hex("#1F2A44"),
		{ font = Enum.Font.GothamBlack, weight = Enum.FontWeight.Bold }
	)
	Core.label(gui, "LIVE · WORK · INVEST", 0.34, 0.58, 0.4, 0.14, hex("#C9A13B"), { font = Enum.Font.GothamBlack })
	-- fly-posting and tags over the top of it
	Paint.flyers(Core.frame(gui, 0.7, 0.5, 0.28, 0.45, Color3.new(1, 1, 1), 1), W * 0.28, H * 0.45, rng, {
		Text.flyers[8],
		Text.flyers[12],
		Text.flyers[3],
		Text.flyers[10],
	})
	Paint.graffiti(gui, W, H, rng, "WALL ST OR BUST", { x = 0.5, y = 0.74, w = 0.3, h = 0.2 })
	Paint.grime(gui, W, H, rng, { streaks = 12, soot = 0.15 })
	for i, t in Text.lotWarnings do
		local s = Kit.detail(
			m,
			Plan.cf(hx0 + 25 + (i - 1) * 45, y + 4.5, T.z0 - 0.35),
			Vector3.new(4, 2, 0.06),
			hex("#E9E2CF"),
			M.Metal
		)
		Kit.sign(s, t, { font = Enum.Font.Highway, color = hex("#8A2C2C"), pixelsPerStud = 30 })
	end
	-- the hoarding's back face (inside the lot) is bare plywood with bracing
	for x = hx0 + 6, hx1 - 6, 12 do
		Kit.detail(
			m,
			Plan.cf(x, y + h / 2, T.z0 + 1.2) * CFrame.Angles(math.rad(-25), 0, 0),
			Vector3.new(0.4, h, 0.4),
			hex("#6B5A40"),
			M.Wood
		).Name =
			"Brace"
	end
	local gap0, gap1 = T.gapX - 3, T.gapX + 3
	local z0, z1 = T.z0, T.z1
	local runs = {
		{ Plan.v(T.x0, y, z0), Plan.v(hx0, y, z0) },
		{ Plan.v(hx1, y, z0), Plan.v(gap0, y, z0) },
		{ Plan.v(gap1, y, z0), Plan.v(T.x1, y, z0) },
		{ Plan.v(T.x1, y, z0), Plan.v(T.x1, y, z1) },
		{ Plan.v(T.x1, y, z1), Plan.v(T.x0, y, z1) },
		{ Plan.v(T.x0, y, z1), Plan.v(T.x0, y, z0) },
	}
	for i, r in runs do
		Dress.chainRun(m, r[1], r[2], h, rng, {
			barbed = i >= 4,
			signs = if i == 4 then { Text.lotWarnings[2] } else nil,
		})
	end
	-- the sagging bay: its panel peeled down and lying in the dirt
	local torn = Kit.detail(
		m,
		Plan.cf(T.gapX, WALK + 0.6, T.z0 + 3) * CFrame.Angles(math.rad(-78), 0, 0),
		Vector3.new(6, 7, 0.1),
		C.chainlink,
		M.Metal
	)
	torn.Name = "TornMesh"
	torn.Transparency = 1
	local tg, TW, TH = Paint.surface(torn, Enum.NormalId.Front, 8)
	Art.chainlink(tg, TW, TH, 9, C.chainlink)
end

---------------------------------------------------------------------------------------------------
-- The concrete frame: two storeys of columns, one poured slab, rebar and a scaffold
---------------------------------------------------------------------------------------------------
local function frame(m: Instance, rng: Deps.RngT)
	local f = Kit.model(m, "ConcreteFrame")
	local x0, x1, z0, z1 = -104, -60, 136, 176
	local con = hex("#9A968C")
	local slabY = 13
	-- ground-floor slab (a step up: ramped at the front)
	Geo.lbox(f, x0 - 2, WALK, z0 - 2, x1 + 2, WALK + 0.8, z1 + 2, hex("#8A8780"), M.Concrete).Name = "Footing"
	Kit.wedge(f, Plan.cf(x1 - 8, WALK + 0.4, z0 - 3.5, 0), Vector3.new(14, 0.8, 3), hex("#8A8780"), M.Concrete).Name =
		"FootingRamp"
	for ix = 0, 3 do
		for iz = 0, 2 do
			local x = x0 + (x1 - x0) * ix / 3
			local z = z0 + (z1 - z0) * iz / 2
			Geo.lbox(
				f,
				x - 0.8,
				WALK + 0.8,
				z - 0.8,
				x + 0.8,
				WALK + slabY,
				z + 0.8,
				Geo.vary(con, rng, 0.05),
				M.Concrete
			).Name =
				"Column"
			-- the upper storey is only half done: some columns, the rest is rebar
			if (ix + iz) % 2 == 0 then
				Geo.lbox(
					f,
					x - 0.8,
					WALK + slabY + 1,
					z - 0.8,
					x + 0.8,
					WALK + slabY + 1 + rng:range(6, 11),
					z + 0.8,
					Geo.vary(con, rng, 0.05),
					M.Concrete
				).Name =
					"Column"
			else
				for _, d in { -0.4, 0.4 } do
					Kit.detail(
						f,
						Plan.cf(x + d, WALK + slabY + 3, z + d),
						Vector3.new(0.15, 4, 0.15),
						C.rust,
						M.CorrodedMetal
					).Name =
						"Rebar"
				end
			end
		end
	end
	local slab = Geo.lbox(
		f,
		x0 - 1.5,
		WALK + slabY,
		z0 - 1.5,
		x1 + 1.5,
		WALK + slabY + 1,
		z1 + 1.5,
		Geo.vary(con, rng, 0.04),
		M.Concrete
	)
	slab.Name = "Slab"
	-- formwork and a tarp flapping on the edge
	Kit.detail(
		f,
		Plan.cf(x1 + 1.6, WALK + slabY - 1, (z0 + z1) / 2),
		Vector3.new(0.3, 2, z1 - z0),
		hex("#7F6A55"),
		M.WoodPlanks
	).Name =
		"Formwork"
	local tarp = Kit.detail(
		f,
		Plan.cf(x0 + 8, WALK + slabY - 3, z1 + 1.7) * CFrame.Angles(math.rad(8), 0, 0),
		Vector3.new(14, 6, 0.1),
		C.tarp,
		M.Fabric
	)
	tarp.Name = "Tarp"
	-- scaffold up the north face, so the slab can actually be reached
	Props.build("scaffold", f, Plan.cf(-82, WALK, z0 - 4.5, 0), { bays = 3, levels = 2, seed = "lot-scaffold" })
	-- rebar bundles on the ground
	for i = 0, 5 do
		Kit.detail(
			f,
			Plan.cf(-52, WALK + 0.2 + (i % 2) * 0.2, 150 + i * 0.4),
			Vector3.new(16, 0.18, 0.18),
			C.rust,
			M.CorrodedMetal
		).Name =
			"RebarBundle"
	end
end

---------------------------------------------------------------------------------------------------
local function excavator(m: Instance, rng: Deps.RngT)
	local e = Kit.model(m, "Excavator")
	local cf = Plan.cf(-10, WALK, 128, 30)
	local paint = Geo.vary(YELLOW, rng, 0.06)
	local dark = hex("#2A2A2A")
	for _, sx in { -2.8, 2.8 } do
		Kit.block(e, L(cf, sx, 1.3, 0), Vector3.new(2, 2.6, 12), dark, M.DiamondPlate).Name = "Track"
	end
	Kit.block(e, L(cf, 0, 3.2, 1), Vector3.new(7.2, 1.4, 8), paint, M.Metal).Name = "Deck"
	Kit.block(e, L(cf, 0, 5.1, 3), Vector3.new(7, 2.6, 4.4), paint, M.Metal).Name = "Engine"
	local cab = Kit.block(e, L(cf, -1.8, 6.2, -1.4), Vector3.new(3.4, 5, 3.6), paint, M.Metal)
	cab.Name = "Cab"
	local glass = Kit.detail(e, L(cf, -1.8, 6.8, -3.25), Vector3.new(3, 3, 0.1), hex("#3A4248"), M.Glass)
	glass.Reflectance = 0.2
	-- boom, stick and bucket resting in the dirt
	local boomBase = L(cf, 1.4, 4.5, -2)
	Kit.block(
		e,
		boomBase * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 0, -5),
		Vector3.new(1.4, 1.6, 10.5),
		paint,
		M.Metal
	).Name =
		"Boom"
	local elbow = boomBase * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 0, -10)
	Kit.block(
		e,
		elbow * CFrame.Angles(math.rad(-110), 0, 0) * CFrame.new(0, 0, -3.6),
		Vector3.new(1.2, 1.2, 7.4),
		paint,
		M.Metal
	).Name =
		"Stick"
	Kit.wedge(e, L(cf, 1.4, 1.2, -12.4), Vector3.new(3, 2.4, 2.6), dark, M.CorrodedMetal).Name = "Bucket"
	-- rust and mud
	Kit.detail(e, L(cf, 0, 3.95, 4.9), Vector3.new(7, 0.6, 0.2), C.rust, M.CorrodedMetal)
	Kit.detail(e, L(cf, 0, 0.3, 0), Vector3.new(8, 0.4, 12.4), hex("#4A3A2C"), M.Mud)
end

local function crane(m: Instance, rng: Deps.RngT)
	local c = Kit.model(m, "TowerCrane")
	local base = Plan.cf(-130, WALK, 186, 0)
	local mastH = 92
	local yellow = Geo.vary(YELLOW, rng, 0.05)
	Kit.block(c, L(base, 0, 1, 0), Vector3.new(9, 2, 9), C.concreteDark, M.Concrete).Name = "CraneBase"
	-- the lattice mast: four chords and a painted lattice on an invisible core
	for _, sx in { -1.8, 1.8 } do
		for _, sz in { -1.8, 1.8 } do
			Kit.block(c, L(base, sx, 2 + mastH / 2, sz), Vector3.new(0.45, mastH, 0.45), yellow, M.Metal).Name = "Chord"
		end
	end
	local core = Kit.detail(c, L(base, 0, 2 + mastH / 2, 0), Vector3.new(3.6, mastH, 3.6), yellow, M.Metal)
	core.Name = "Lattice"
	core.Transparency = 1
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui, W, H = Paint.surface(core, face, 5)
		for y = 0, H, 18 do
			Core.px(gui, 0, y, W, 2, yellow)
			Core.line(gui, 0, y, W, y + 18, 2, yellow)
		end
	end
	-- slewing unit, cab, jib, counter-jib, counterweights, trolley and hook
	local top = L(base, 0, 2 + mastH, 0)
	Kit.block(c, L(top, 0, 1, 0), Vector3.new(4.4, 2, 4.4), yellow, M.Metal).Name = "Slew"
	local cab = Kit.block(c, L(top, 2.8, 2.4, -1), Vector3.new(2.4, 2.6, 2.6), hex("#E9E7E2"), M.Metal)
	cab.Name = "CraneCab"
	local yaw = CFrame.Angles(0, math.rad(-58), 0)
	local jibLen, cjLen = 70, 22
	local jib =
		Kit.detail(c, top * yaw * CFrame.new(0, 3.2, -jibLen / 2), Vector3.new(2.4, 2.4, jibLen), yellow, M.Metal)
	jib.Name = "Jib"
	jib.Transparency = 1
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui, W, H = Paint.surface(jib, face, 5)
		Core.px(gui, 0, 0, W, 2, yellow)
		Core.px(gui, 0, H - 2, W, 2, yellow)
		for x = 0, W, 12 do
			Core.line(gui, x, 0, x + 12, H, 2, yellow)
		end
	end
	for _, dy in { 2.1, 4.3 } do
		Kit.detail(c, top * yaw * CFrame.new(0, dy, -jibLen / 2), Vector3.new(0.4, 0.4, jibLen), yellow, M.Metal).Name =
			"JibChord"
	end
	Kit.detail(c, top * yaw * CFrame.new(0, 3.2, cjLen / 2), Vector3.new(2.4, 1, cjLen), yellow, M.Metal).Name =
		"CounterJib"
	Kit.block(c, top * yaw * CFrame.new(0, 2.6, cjLen - 3), Vector3.new(3.4, 3.4, 4), C.concreteDark, M.Concrete).Name =
		"Counterweight"
	Kit.detail(c, top * yaw * CFrame.new(0, 7, 0), Vector3.new(0.5, 6, 0.5), yellow, M.Metal).Name = "Apex"
	local trolleyAt = -jibLen * 0.62
	Kit.detail(c, top * yaw * CFrame.new(0, 1.6, trolleyAt), Vector3.new(1.6, 0.6, 1.6), hex("#2A2A2A"), M.Metal).Name =
		"Trolley"
	local hookY = 30
	Kit.detail(
		c,
		top * yaw * CFrame.new(0, 1.3 - hookY / 2, trolleyAt),
		Vector3.new(0.12, hookY, 0.12),
		hex("#1A1A1A"),
		M.Metal
	).Name =
		"Cable"
	Kit.detail(
		c,
		top * yaw * CFrame.new(0, 1.3 - hookY - 0.6, trolleyAt),
		Vector3.new(1, 1.2, 0.6),
		hex("#C83A2A"),
		M.Metal
	).Name =
		"Hook"
	-- aircraft warning lights
	for _, z in { -jibLen + 0.5, cjLen - 0.5 } do
		local l = Kit.detail(c, top * yaw * CFrame.new(0, 4.8, z), Vector3.new(0.6, 0.6, 0.6), hex("#FF3B30"), M.Neon)
		l.Name = "WarningLight"
		l:AddTag("StreetLight")
	end
end

---------------------------------------------------------------------------------------------------
local function trailer(m: Instance, rng: Deps.RngT)
	local t = Kit.model(m, "SiteTrailer")
	local cf = Plan.cf(28, WALK, 180, 0)
	Kit.block(t, L(cf, 0, 5.6, 0), Vector3.new(30, 9, 10), Geo.vary(hex("#D8D2C2"), rng, 0.05), M.CorrodedMetal).Name =
		"Body"
	for _, x in { -12, -4, 4, 12 } do
		Kit.detail(t, L(cf, x, 0.6, 0), Vector3.new(1.4, 1.2, 9), C.concreteDark, M.Concrete).Name = "Block"
	end
	for _, x in { -9, 9 } do
		local w = Kit.detail(t, L(cf, x, 6.4, -5.05), Vector3.new(5, 3, 0.1), hex("#3A4248"), M.Glass)
		w.Reflectance = 0.15
		Kit.detail(t, L(cf, x, 6.4, -5.15), Vector3.new(5.2, 0.15, 0.1), hex("#5A5F63"), M.Metal)
	end
	Kit.detail(t, L(cf, 1, 5.2, -5.05), Vector3.new(3.4, 7.2, 0.1), hex("#6E7173"), M.Metal).Name = "Door"
	Kit.stairs(t, L(cf, 1, 0, -8.3) * CFrame.Angles(0, math.pi, 0), 4, 2, 0.5, 1.2, hex("#8E7A5A"), M.WoodPlanks).Name =
		"Steps"
	local s = Kit.detail(t, L(cf, 1, 9.6, -5.06), Vector3.new(6, 1.2, 0.05), hex("#1F2A44"), M.Metal)
	Kit.sign(s, "SITE OFFICE", { font = Enum.Font.Highway, color = hex("#E9E2CF"), pixelsPerStud = 30 })
	local lamp = Kit.detail(t, L(cf, 1, 9.2, -5.4), Vector3.new(1.2, 0.5, 0.5), C.sodium, M.Neon)
	lamp.Name = "SiteLamp"
	lamp:AddTag("StreetLight")
	Kit.light(lamp, "spot", { Color = C.sodium, Range = 26, Brightness = 1.4, Angle = 80, Face = Enum.NormalId.Bottom })
	-- the porta-john
	local pj = Plan.cf(52, WALK, 164, Plan.W)
	Kit.block(t, L(pj, 0, 3.8, 0), Vector3.new(4, 7.6, 4), hex("#2C5E8A"), M.Plastic).Name = "PortaJohn"
	Kit.detail(t, L(pj, 0, 7.8, 0), Vector3.new(4.2, 0.4, 4.2), hex("#E9E7E2"), M.Plastic)
	local d = Kit.detail(t, L(pj, 0, 4, -2.05), Vector3.new(3, 6.8, 0.1), hex("#24527A"), M.Plastic)
	Kit.sign(d, "VACANT", { font = Enum.Font.Highway, color = hex("#3CFF8A"), pixelsPerStud = 40, padding = 0.42 })
end

local function clutter(m: Instance, rng: Deps.RngT)
	Props.build("pallet_stack", m, Plan.cf(-40, WALK, 172, 18), { count = 4, seed = "lot-p1" })
	Props.build("pallet_stack", m, Plan.cf(-34, WALK, 176, -12), { count = 2, seed = "lot-p2" })
	Props.build("dumpster", m, Plan.cf(10, WALK, 150, Plan.E), { color = hex("#8A3B1E"), seed = "lot-roll-off" })
	Props.build("jersey_barrier", m, Plan.cf(-130, WALK, 150, Plan.N), { seed = "lot-jb1" })
	Props.build("jersey_barrier", m, Plan.cf(-118, WALK, 152, 8), { seed = "lot-jb2" })
	for _, c in { { -96, 118 }, { -92, 121 }, { -20, 138 }, { 4, 112 }, { 22, 160 }, { -112, 182 } } do
		Dress.cone(m, c[1], c[2], rng)
	end
	-- a stack of storm-drain pipes
	for i, p in { { 0, 0 }, { 3.2, 0 }, { 1.6, 2.6 } } do
		Kit.cylinder(
			m,
			Plan.cf(-140, WALK + 1.6 + p[2], 120 + p[1]) * CFrame.Angles(0, 0, math.rad(90)),
			10,
			3.2,
			Geo.vary(C.concrete, rng, 0.05),
			M.Concrete
		).Name = "Pipe"
			.. i
	end
	Dress.litter(m, T.x0, T.z0, T.x1, T.z1, 26, rng)
end

---------------------------------------------------------------------------------------------------
function Lot.build(parent: Instance): Model
	local m = Kit.model(parent, "ConstructionLot")
	local rng = Deps.Rng.new("lot")
	ground(m, rng)
	fences(m, rng)
	frame(m, rng)
	excavator(m, rng)
	crane(m, rng)
	trailer(m, rng)
	clutter(m, rng)
	return m
end

return Lot
