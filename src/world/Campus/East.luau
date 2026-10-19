--!strict
-- East of Mill Street: the elevated Route 9 line (riveted steel girders on bents, running out over the river toward
-- the city), Eastbridge Station under it (the subway door at the turnstiles, the beat-up company directory kiosk on
-- the plaza, a train waiting at the platform above), U-Stor-It self storage, Eastbridge Hardware (closing down), the
-- rec court, the pay lot with its loan-shark billboard, and the overlook at the river's edge. Bake-safe.

local Deps = require(script.Parent.Deps)
local Plan = require(script.Parent.Plan)
local Geo = require(script.Parent.Geo)
local Paint = require(script.Parent.Paint)
local Text = require(script.Parent.Text)
local Buildings = require(script.Parent.Buildings)
local Markers = require(script.Parent.Markers)
local Dress = require(script.Parent.Dress)

local Kit = Deps.Kit
local Props = Deps.Props
local Signs = Deps.Signs
local Core = Deps.Gui.Core
local Art = Deps.Gui.Art
local P = Deps.Palette
local C = P.campus
local hex = P.hex
local M = Enum.Material

local East = {}

local WALK = Plan.WALK

local function L(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, y, z)
end

local GIRDER = hex("#3E4A42")

---------------------------------------------------------------------------------------------------
-- The elevated line
---------------------------------------------------------------------------------------------------
local function rivets(part: BasePart, face: Enum.NormalId, rng: Deps.RngT)
	local gui, W, H = Paint.surface(part, face, 4)
	for _, y in { 3, H - 5 } do
		for x = 2, W, 6 do
			Core.px(gui, x, y, 2, 2, Kit.shade(GIRDER, -0.3), 0.2)
		end
	end
	for x = 0, W, 40 do
		Core.px(gui, x, 0, 3, H, Kit.shade(GIRDER, -0.2), 0.3)
	end
	-- rust bleeding from the joints
	for _ = 1, math.floor(W / 30) do
		local s = Core.px(gui, rng:range(0, W), rng:range(0, H * 0.3), rng:range(3, 9), rng:range(H * 0.4, H), C.rust, rng:range(0.3, 0.6))
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new(0.1, 1)
		g.Parent = s
	end
end

local function viaduct(m: Instance, rng: Deps.RngT)
	local V = Plan.viaduct
	local S = Plan.station
	local v = Kit.model(m, "ElevatedLine")
	local len = V.x1 - V.x0
	-- two box girders and the deck plate
	for i, z in { V.z0 + 1, V.z1 - 1 } do
		local g = Geo.lbox(v, V.x0, V.bottom, z - 1, V.x1, V.top, z + 1, GIRDER, M.CorrodedMetal)
		g.Name = "Girder" .. i
		rivets(g, if i == 1 then Enum.NormalId.Back else Enum.NormalId.Front, rng)
		rivets(g, if i == 1 then Enum.NormalId.Front else Enum.NormalId.Back, rng)
	end
	local deck = Geo.lbox(v, V.x0, V.top - 0.6, V.z0 + 2, V.x1, V.top, V.z1 - 2, hex("#4A4E50"), M.DiamondPlate)
	deck.Name = "Deck"
	-- ties and rails painted on a strip, two real rails on top
	local ties = Geo.lbox(v, V.x0, V.top, V.trackZ - 4, V.x1, V.top + 0.3, V.trackZ + 4, hex("#3A2E24"), M.Wood, false)
	ties.Name = "Ties"
	local tg, TW, TH = Paint.surface(ties, Enum.NormalId.Top, 3)
	Core.bg(tg, hex("#4A4E50"))
	for x = 0, TW, 6 do
		Core.px(tg, x, TH * 0.1, 3, TH * 0.8, hex("#3A2E24"))
	end
	for _, dz in { -2.5, 2.5 } do
		Geo.lbox(v, V.x0, V.top + 0.3, V.trackZ + dz - 0.2, V.x1, V.top + 0.7, V.trackZ + dz + 0.2, hex("#7A7E80"), M.Metal, false).Name =
			"Rail"
	end
	-- the bumper at the end of the line
	Geo.lbox(v, V.x0 + 1, V.top, V.trackZ - 3, V.x0 + 3, V.top + 3, V.trackZ + 3, hex("#C9A227"), M.Metal).Name = "Bumper"
	-- bents: column pairs and a cross beam (over the station they stand on its roof; in the river on the bed)
	for i = 0, V.bents - 1 do
		local x = V.x0 + (i + 0.5) * len / V.bents
		local foot = WALK
		if x >= S.x0 and x <= S.x1 then
			foot = WALK + S.h
		elseif x > Plan.PLAY.x1 then
			foot = -15
		end
		for _, z in { V.z0 + 1.5, V.z1 - 1.5 } do
			local col = Geo.lbox(v, x - 0.9, foot, z - 0.9, x + 0.9, V.bottom, z + 0.9, Geo.vary(GIRDER, rng, 0.05), M.CorrodedMetal)
			col.Name = "Column"
			if foot == WALK then
				Geo.lbox(v, x - 1.4, WALK, z - 1.4, x + 1.4, WALK + 1.2, z + 1.4, C.concreteDark, M.Concrete).Name = "Footing"
			end
		end
		Geo.lbox(v, x - 0.7, V.bottom - 2.4, V.z0 + 1, x + 0.7, V.bottom, V.z1 - 1, GIRDER, M.CorrodedMetal, false).Name =
			"CrossBeam"
	end
	-- sodium lamps bolted under the girders (only over the walkable side)
	for i, x in { 196, 214 } do
		local lamp = Geo.lbox(v, x - 0.6, V.bottom - 0.5, V.z1 - 3, x + 0.6, V.bottom, V.z1 - 1.5, C.sodium, M.Neon, false)
		lamp.Name = "UnderLamp" .. i
		lamp:AddTag("StreetLight")
		Kit.light(lamp, "point", { Color = C.sodium, Range = 28, Brightness = 1.2 })
	end
end

local function platform(m: Instance)
	local PL = Plan.platform
	local V = Plan.viaduct
	local p = Kit.model(m, "Platform")
	Geo.lbox(p, PL.x0, V.top, PL.z0, PL.x1, PL.top, PL.z1, hex("#8A8780"), M.Concrete).Name = "PlatformDeck"
	Kit.detail(p, Plan.cf((PL.x0 + PL.x1) / 2, PL.top + 0.02, PL.z0 + 0.5), Vector3.new(PL.x1 - PL.x0, 0.04, 1), hex("#C9A93E"), M.SmoothPlastic).Name =
		"Edge"
	-- canopy on posts
	local roofY = PL.top + 10
	for x = PL.x0 + 4, PL.x1 - 4, 13 do
		Kit.block(p, Plan.cf(x, (PL.top + roofY) / 2, PL.z1 - 2), Vector3.new(0.6, roofY - PL.top, 0.6), GIRDER, M.Metal).Name =
			"Post"
	end
	Geo.lbox(p, PL.x0 + 2, roofY, PL.z0 - 1, PL.x1 - 2, roofY + 0.5, PL.z1 + 0.5, hex("#5F6366"), M.CorrodedMetal).Name = "Canopy"
	-- railing on the street side
	Geo.lbox(p, PL.x0, PL.top, PL.z1 - 0.3, PL.x1, PL.top + 3.6, PL.z1, GIRDER, M.Metal, false).Name = "Railing"
	-- station name boards and lamps
	for i, x in { 150, 196 } do
		local b = Kit.detail(p, Plan.cf(x, PL.top + 7, PL.z1 - 2.4, Plan.N), Vector3.new(10, 1.6, 0.2), hex("#1F2A44"), M.Metal)
		b.Name = "NameBoard" .. i
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local g = Paint.surface(b, face, 24)
			Core.bg(g, hex("#1F2A44"))
			Core.label(g, "EASTBRIDGE", 0.03, 0.1, 0.94, 0.8, hex("#F4F1E6"), { font = Enum.Font.Highway, align = Enum.TextXAlignment.Center })
		end
	end
	for i, x in { 140, 172, 204 } do
		local l = Kit.detail(p, Plan.cf(x, roofY - 0.3, (PL.z0 + PL.z1) / 2), Vector3.new(5, 0.25, 0.7), hex("#EDEBE0"), M.Neon)
		l.Name = "PlatformLight" .. i
		l:AddTag("StreetLight")
		if i == 2 then
			Kit.light(l, "point", { Color = hex("#EDEBE0"), Range = 24, Brightness = 1 })
		end
	end
end

-- A two-car Route 9 train waiting at the platform
local function train(m: Instance, rng: Deps.RngT)
	local V = Plan.viaduct
	local t = Kit.model(m, "Train")
	local silver = hex("#A7ABB0")
	local z = V.trackZ + 1
	for car = 0, 1 do
		local x = 150 + car * 31
		local cf = Plan.cf(x, V.top + 0.7, z, Plan.E)
		Kit.block(t, L(cf, 0, 6, 0), Vector3.new(9.6, 10, 30), Geo.vary(silver, rng, 0.04), M.Metal).Name = "Car" .. car
		Kit.detail(t, L(cf, 0, 11.2, 0), Vector3.new(9, 0.8, 29.6), hex("#8E9397"), M.Metal).Name = "Roof"
		Kit.detail(t, L(cf, 0, 1.2, 0), Vector3.new(8.6, 1.6, 26), hex("#2A2A2A"), M.Metal).Name = "Bogies"
		-- the window band and doors on the platform side (painted, lit)
		local band = Kit.detail(
			t,
			L(cf, 4.85, 6.8, 0) * CFrame.Angles(0, math.rad(-90), 0),
			Vector3.new(28, 3.4, 0.1),
			hex("#E8D9A8"),
			M.SmoothPlastic
		)
		band.Name = "WindowBand"
		local bg, BW, BH = Paint.surface(band, Enum.NormalId.Front, 8, { glow = true, brightness = 0.8 })
		Core.bg(bg, hex("#A7ABB0"))
		for k = 0, 6 do
			local wx = BW * (0.04 + k * 0.137)
			Core.px(bg, wx, BH * 0.1, BW * 0.1, BH * 0.8, hex("#E8D9A8"))
			Core.px(bg, wx + BW * 0.1, 0, BW * 0.037, BH, hex("#5A5F63"))
		end
		local sign = Kit.detail(t, L(cf, 0, 9.6, -15.05), Vector3.new(4, 1, 0.1), hex("#141414"), M.SmoothPlastic)
		Kit.sign(sign, "9 · DOWNTOWN", { font = Enum.Font.Code, color = hex("#FFB547"), pixelsPerStud = 40, glow = true })
		Kit.detail(t, L(cf, 0, 6, 15.1), Vector3.new(2, 0.6, 0.3), hex("#2A2A2A"), M.Metal).Name = "Coupler"
	end
end

---------------------------------------------------------------------------------------------------
-- Eastbridge Station
---------------------------------------------------------------------------------------------------
local function station(m: Instance, mk: Instance, rng: Deps.RngT)
	local S = Plan.station
	local Hl = S.hall
	local st = Kit.model(m, "EastbridgeStation")
	local brick = hex("#7A3B2E")
	local h = S.h
	local blocks = {
		{ S.x0, S.z0, Hl.x0, S.z1 },
		{ Hl.x1, S.z0, S.x1, S.z1 },
		{ Hl.x0, S.z0, Hl.x1, Hl.z0 },
	}
	local wings: { BasePart } = {}
	for i, b in blocks do
		local p = Geo.lbox(st, b[1], WALK, b[2], b[3], WALK + h, b[4], Geo.vary(brick, rng, 0.04), M.Brick)
		p.Name = "Wing" .. i
		wings[i] = p
		if i < 3 then
			-- the plaza side (+Z) of each wing
			local gui, W, H = Paint.surface(p, Enum.NormalId.Back, 6)
			gui.Name = "Facade_front"
			Paint.windows(gui, W, H, rng, { cols = 1, rows = 1, top = 0.2, bottom = 0.25, winW = 0.6, winH = 0.8, lit = 0.6 })
			Paint.grime(gui, W, H, rng, { streaks = 4 })
		end
	end
	-- the side walls of the station face Mill Street and the lot: painted with grime and a mural
	local wg, WW, WH = Paint.surface(wings[1], Enum.NormalId.Left, 6)
	Paint.grime(wg, WW, WH, rng, { streaks = 8 })
	Paint.graffiti(wg, WW, WH, rng, "EB 4 LIFE", { y = 0.7 })
	-- the lintel over the hall and its two piers, a stone cornice and the name
	Geo.lbox(st, Hl.x0, WALK + 14, Hl.z0, Hl.x1, WALK + h, S.z1, Geo.vary(brick, rng, 0.04), M.Brick).Name = "Lintel"
	Geo.lbox(st, Hl.x0, WALK + 13.6, Hl.z0, Hl.x1, WALK + 14, S.z1, hex("#D8D2C2"), M.SmoothPlastic).Name = "HallCeiling"
	for _, x in { 152, 164 } do
		Geo.lbox(st, x - 1, WALK, S.z1 - 2, x + 1, WALK + 14, S.z1, Geo.vary(brick, rng, 0.04), M.Brick).Name = "Pier"
	end
	Geo.lbox(st, S.x0 - 0.5, WALK + h - 0.8, S.z0 - 0.5, S.x1 + 0.5, WALK + h, S.z1 + 0.6, hex("#A49C8C"), M.Concrete, false).Name =
		"Cornice"
	Signs.buildingName(st, Plan.cf(S.doorX, WALK + 15.2, S.z1 + 0.02, Plan.S), {
		text = Text.station,
		style = "stone",
		height = 1.6,
		width = 24,
		seed = "station-name",
	})
	local sub = Kit.detail(st, Plan.cf(S.doorX, WALK + 14.4, S.z1 + 0.04, Plan.S), Vector3.new(20, 0.7, 0.05), hex("#24262A"), M.SmoothPlastic)
	Kit.sign(sub, Text.stationSub, { font = Enum.Font.Highway, color = hex("#E9E2CF"), pixelsPerStud = 30 })
	-- hall floor and white subway tile walls
	Geo.lbox(st, Hl.x0, WALK, Hl.z0, Hl.x1, WALK + 0.08, S.z1, hex("#8E8A80"), M.Slate, true).Name = "HallFloor"
	local tileSides: { { part: BasePart, face: Enum.NormalId } } = {
		{ part = wings[1], face = Enum.NormalId.Right },
		{ part = wings[2], face = Enum.NormalId.Left },
	}
	for _, side in tileSides do
		local g, GW, GH = Paint.surface(side.part, side.face, 8)
		local tile = Core.frame(g, 0, 0, 1, 14 / h, hex("#E4E0D4"))
		tile.Position = UDim2.fromScale(0, 1 - 14 / h)
		for x = 0, GW, 8 do
			Core.px(tile, x, 0, 1, GH, hex("#B8B2A4"), 0.4)
		end
		for y = 0, GH, 4 do
			Core.px(tile, 0, y, GW, 1, hex("#B8B2A4"), 0.4)
		end
		Core.px(tile, 0, GH * 0.4, GW, 6, hex("#2F5A3A"))
	end
	-- the painted stairwell up to the platform behind the turnstiles
	local sg = Paint.surface(wings[3], Enum.NormalId.Back, 10)
	local well = Core.frame(sg, 0.3, 1 - 14 / h, 0.4, 13.4 / h, hex("#1A1B1C"))
	Art.stairwell(well, 12, hex("#E8D9A8"), hex("#1A1B1C"))
	Core.label(sg, "↑ TO PLATFORM · DOWNTOWN", 0.3, 1 - 14 / h - 0.05, 0.4, 0.05, hex("#E9E2CF"), {
		font = Enum.Font.Highway,
		align = Enum.TextXAlignment.Center,
	})
	-- turnstiles, then the door trigger in front of them
	local tz = Hl.z0 + 2
	for i = 0, 4 do
		local x = Hl.x0 + 4 + i * 6
		if math.abs(x - S.doorX) > 3 then
			Kit.block(st, Plan.cf(x, WALK + 1.8, tz), Vector3.new(1.2, 3.6, 3), hex("#5A5F63"), M.Metal).Name = "Turnstile"
			Kit.detail(st, Plan.cf(x + 1.4, WALK + 3, tz), Vector3.new(1.8, 0.2, 0.2), hex("#B0B0A8"), M.Metal)
		end
	end
	-- an invisible wall over the turnstiles up to the ceiling, so nobody hops into the painted stairwell
	local bar = Geo.lbox(st, Hl.x0, WALK, tz - 0.3, Hl.x1, WALK + 13.6, tz + 0.3, hex("#5A5F63"), M.Metal, true)
	bar.Name = "FareLine"
	bar.Transparency = 1
	bar.CastShadow = false
	local gate = Kit.block(st, Plan.cf(S.doorX, WALK + 2.4, tz), Vector3.new(4, 4.8, 0.3), hex("#8E9397"), M.Metal)
	gate.Name = "FareGate"
	gate.Transparency = 0.5
	Markers.door(mk, "door_campus_subway", Plan.cf(S.doorX, WALK + 5, tz + 2.2, Plan.S))
	local over = Kit.detail(st, Plan.cf(S.doorX, WALK + 10.6, tz + 0.4, Plan.S), Vector3.new(9, 1.6, 0.3), hex("#141414"), M.Metal)
	over.Name = "GateSign"
	Kit.sign(over, "SUBWAY · DOWNTOWN · WALL ST", { font = Enum.Font.Highway, color = hex("#3CBF6A"), pixelsPerStud = 30, glow = true })
	-- fare machines, a bench and the service advisory
	for i = 0, 1 do
		local fm = Plan.cf(Hl.x0 + 1.4, WALK, -72 + i * 4, Plan.E)
		Kit.block(st, L(fm, 0, 3, 0), Vector3.new(2.6, 6, 1.6), hex("#2C5E8A"), M.Metal).Name = "FareMachine"
		local scr = Kit.detail(st, L(fm, 0, 4.2, -0.85), Vector3.new(1.6, 1.2, 0.1), hex("#5CB8D6"), M.Neon)
		scr.Transparency = 0.3
	end
	Props.build("bench_worn", st, Plan.cf(Hl.x1 - 1.6, WALK, -68, Plan.W), { seed = "station-bench" })
	Dress.poster(st, Plan.cf(Hl.x1 - 0.1, WALK + 5, -74, Plan.W), 2, "station-poster", 3, 4)
	for i, x in { 148, 158, 168 } do
		local t = Kit.detail(st, Plan.cf(x, WALK + 13.3, -69), Vector3.new(0.8, 0.2, 6), hex("#F4F1E6"), M.Neon)
		t.Name = "HallLight"
		t:AddTag("InteriorLight")
		if i == 2 then
			Kit.light(t, "point", { Color = hex("#F4F1E6"), Range = 22, Brightness = 1 })
		end
	end
	-- the green subway globes at the entrance
	for _, x in { Hl.x0 - 1.5, Hl.x1 + 1.5 } do
		local pc = Plan.cf(x, WALK, S.z1 + 1.5)
		Kit.block(st, L(pc, 0, 4.5, 0), Vector3.new(0.5, 9, 0.5), hex("#1F2122"), M.Metal).Name = "GlobePost"
		local globe = Kit.ball(st, L(pc, 0, 9.6, 0), 1.6, hex("#3CBF6A"), M.Neon)
		globe.Name = "SubwayGlobe"
		globe.Transparency = 0.15
		globe.CanCollide = false
		globe:AddTag("StreetLight")
		local lbl = Kit.detail(st, L(pc, 0, 7.6, -0.3), Vector3.new(1.6, 0.6, 0.05), hex("#1F2122"), M.Metal)
		Kit.sign(lbl, Text.stationGlobe, { font = Enum.Font.Highway, color = hex("#E9E2CF"), pixelsPerStud = 60 })
	end
	-- roof clutter on the wings (under the tracks)
	Props.build("ac_unit", st, Plan.cf(134, WALK + h, -100, Plan.S), { seed = "station-ac1" })
	Props.build("ac_unit", st, Plan.cf(182, WALK + h, -64, Plan.S), { seed = "station-ac2" })
end

-- The beat-up company directory kiosk on the station plaza
local function directoryKiosk(m: Instance)
	local cf = Plan.cf(186, WALK, -48, 135)
	local k = Kit.model(m, "DirectoryKiosk")
	local steel = hex("#3A3D40")
	Kit.block(k, L(cf, 0, 0.3, 0), Vector3.new(4.2, 0.6, 2.6), C.concreteDark, M.Concrete)
	local body = Kit.block(k, L(cf, 0, 4.2, 0), Vector3.new(3.6, 7.2, 1.6), steel, M.CorrodedMetal)
	body.Name = "KioskBody"
	local screen = Kit.block(k, L(cf, 0, 4.6, -0.85), Vector3.new(3, 4, 0.12), hex("#0E1A24"), M.SmoothPlastic)
	screen.Name = "DirectoryScreen"
	Markers.interact(screen, "company_directory")
	local g, W, H = Paint.surface(screen, Enum.NormalId.Front, 50, { glow = true, brightness = 1 })
	local bg = Core.bg(g, hex("#13243A"))
	Core.gradient(bg, hex("#1A2E48"), hex("#0B1622"), 90)
	Core.label(g, Text.directory, 0.06, 0.04, 0.88, 0.14, hex("#F4F1E6"), { font = Enum.Font.Oswald, align = Enum.TextXAlignment.Center })
	Core.label(g, Text.directorySub, 0.06, 0.18, 0.88, 0.08, C.mustard, { font = Enum.Font.SourceSansBold, align = Enum.TextXAlignment.Center })
	-- a little map of the line and the Street's blocks
	Core.px(g, W * 0.1, H * 0.5, W * 0.8, 4, hex("#3CBF6A"))
	for i = 0, 3 do
		Core.dot(g, W * (0.1 + i * 0.266), H * 0.5 + 2, 14, hex("#F4F1E6"))
	end
	for i = 0, 5 do
		Core.px(g, W * (0.55 + (i % 3) * 0.12), H * (0.62 + (i // 3) * 0.1), W * 0.1, H * 0.08, hex("#2C4A6E"))
	end
	Core.label(g, "YOU ARE HERE", 0.02, 0.56, 0.4, 0.06, hex("#FFB547"), { font = Enum.Font.Code })
	-- cracks across the glass and a sun-bleached sticker
	Core.line(g, W * 0.6, H * 0.05, W * 0.9, H * 0.45, 2, hex("#C8D0D8"), 0.3)
	Core.line(g, W * 0.75, H * 0.25, W * 0.98, H * 0.3, 1, hex("#C8D0D8"), 0.4)
	local hdr = Kit.detail(k, L(cf, 0, 8.4, 0), Vector3.new(3.8, 1.2, 1.8), hex("#2C5E8A"), M.Metal)
	Kit.sign(hdr, Text.transitInfo, { font = Enum.Font.Highway, color = hex("#F4F1E6"), pixelsPerStud = 40 })
	Kit.detail(k, L(cf, 0.9, 2, -0.82), Vector3.new(1.2, 1.2, 0.05), hex("#C83A2A"), M.SmoothPlastic).Name = "Sticker"
end

---------------------------------------------------------------------------------------------------
-- Storage, hardware, court, parking, overlook
---------------------------------------------------------------------------------------------------
local function storage(m: Instance, rng: Deps.RngT)
	local S = Plan.storage
	local w, d = S.x1 - S.x0, S.z1 - S.z0
	local cf = Plan.cf((S.x0 + S.x1) / 2, WALK, (S.z0 + S.z1) / 2, Plan.S)
	local bm, fr = Buildings.block(m, {
		name = "SelfStorage",
		cf = cf,
		w = w,
		d = d,
		h = S.h,
		seed = "storage",
		storeys = 1,
		color = hex("#B8B2A4"),
		material = M.CorrodedMetal,
		trim = hex("#C8553D"),
		plinth = false,
		roof = { ac = 2, vents = 3 },
	})
	local front = fr.front
	-- rows of orange roll-up unit doors on a painted band
	local band = Kit.detail(bm, L(front, 0, 5.5, -0.1), Vector3.new(w - 4, 10, 0.1), hex("#B8B2A4"), M.Metal)
	band.Name = "UnitDoors"
	local g, W, H = Paint.surface(band, Enum.NormalId.Front, 5)
	local n = 14
	for i = 0, n - 1 do
		local x = W * (i + 0.1) / n
		local door = Core.px(g, x, H * 0.08, W * 0.8 / n, H * 0.92, hex("#C8553D"))
		for y = 4, H, 5 do
			Core.px(door, 0, y, W, 1, hex("#9A3E2A"), 0.3)
		end
		Core.label(door, tostring(100 + i), 0.2, 0.02, 0.6, 0.1, hex("#F4F1E6"), { font = Enum.Font.Highway, align = Enum.TextXAlignment.Center })
	end
	Signs.buildingName(bm, L(front, 0, 14, -0.2), {
		text = Text.storage,
		style = "paint",
		height = 3,
		width = 40,
		seed = "storage-name",
	})
	local sub = Kit.detail(bm, L(front, 18, 18.6, -0.15), Vector3.new(14, 1.4, 0.05), hex("#C8553D"), M.SmoothPlastic)
	Kit.sign(sub, Text.storageSub, { font = Enum.Font.Oswald, color = hex("#F4F1E6"), pixelsPerStud = 30 })
	-- the drive in front, gated with barbed chain-link
	Dress.chainRun(m, Plan.v(S.x0, WALK, S.z1 + 6), Plan.v(170, WALK, S.z1 + 6), 8, rng, { barbed = true })
	Dress.chainRun(m, Plan.v(184, WALK, S.z1 + 6), Plan.v(S.x1, WALK, S.z1 + 6), 8, rng, { barbed = true, signs = { "NO TRESPASSING" } })
	Kit.detail(m, Plan.cf(177, WALK + 4, S.z1 + 6), Vector3.new(14, 0.3, 0.3), C.chainlink, M.Metal).Name = "GateBar"
end

local function hardware(m: Instance)
	local S = Plan.hardware
	local w, d = S.x1 - S.x0, S.z1 - S.z0
	local bm, fr = Buildings.block(m, {
		name = "EastbridgeHardware",
		cf = Plan.cf((S.x0 + S.x1) / 2, WALK, (S.z0 + S.z1) / 2, Plan.N),
		w = w,
		d = d,
		h = S.h,
		seed = "hardware",
		storeys = 3,
		groundH = 14,
		color = hex("#8E5A4A"),
		shop = { depth = 14, height = 13 },
		windows = { cols = 6, from = 2, to = 3, lit = 0.1, ac = 0.2 },
		painted = {
			Buildings.face("left", 6, 2, { lit = 0.1, ghost = { "EASTBRIDGE HARDWARE", "PAINT · TOOLS · KEYS CUT" } }),
			Buildings.face("back", 6, 2),
		},
		roof = { tanks = 1, ac = 2, vents = 3, hatch = true },
		fireEscape = { x = 12, floors = 2 },
	})
	local front = fr.front
	Buildings.storefront(bm, front, w, {
		height = 13,
		sign = Text.hardware,
		signColor = hex("#8A2C2C"),
		signInk = hex("#F4F1E6"),
		door = -14,
		grille = 0.35,
		seed = "hardware-front",
	})
	for i, x in { -6, 6, 16 } do
		Buildings.windowPoster(bm, L(front, x, 5.2, 0.15), Vector3.new(6, 3.2, 0.05), "EVERYTHING MUST GO", "Store closing · 70% off", "hw-poster" .. i)
	end
	local banner = Kit.detail(bm, L(front, 0, 17.5, -0.4), Vector3.new(30, 3, 0.1), hex("#F2D95C"), M.Fabric)
	local bg = Paint.surface(banner, Enum.NormalId.Front, 12)
	Core.bg(bg, hex("#F2D95C"))
	Core.label(bg, Text.hardwareSub, 0.02, 0.1, 0.96, 0.8, hex("#8A2C2C"), { font = Enum.Font.Bangers, align = Enum.TextXAlignment.Center })
end

local function court(m: Instance, rng: Deps.RngT)
	local K = Plan.court
	local c = Kit.model(m, "RecCourt")
	local surf = Geo.lbox(c, K.x0, WALK - 0.1, K.z0, K.x1, WALK + 0.04, K.z1, hex("#3C4A44"), M.Asphalt, false)
	surf.Name = "CourtSurface"
	local g, W, H = Paint.surface(surf, Enum.NormalId.Top, 5)
	local line = hex("#D8D4C8")
	local pad = 3 * 5
	Core.px(g, pad, pad, W - pad * 2, 3, line, 0.4)
	Core.px(g, pad, H - pad, W - pad * 2, 3, line, 0.4)
	Core.px(g, pad, pad, 3, H - pad * 2, line, 0.4)
	Core.px(g, W - pad, pad, 3, H - pad * 2, line, 0.4)
	Core.px(g, pad, H / 2, W - pad * 2, 3, line, 0.4)
	local ring = Core.dot(g, W / 2, H / 2, 60, line, 0.6)
	ring.BackgroundTransparency = 1
	Core.stroke(ring, line, 3, 0.4)
	for _, y in { pad, H - pad - 90 } do
		local key = Core.px(g, W / 2 - 40, y, 80, 90, hex("#8A3B2E"), 0.5)
		Core.stroke(key, line, 3, 0.4)
	end
	Paint.cracks(g, W, H, rng, 12, { color = hex("#1E2422") })
	-- hoops at both ends
	for i, z in { K.z0 + 3, K.z1 - 3 } do
		local yaw = if i == 1 then Plan.S else Plan.N
		local cf = Plan.cf((K.x0 + K.x1) / 2, WALK, z, yaw)
		Kit.block(c, L(cf, 0, 6, 0), Vector3.new(0.6, 12, 0.6), hex("#2A2A2A"), M.Metal).Name = "HoopPole"
		Kit.detail(c, L(cf, 0, 11.5, -1.2), Vector3.new(0.4, 0.4, 2.4), hex("#2A2A2A"), M.Metal)
		local board = Kit.block(c, L(cf, 0, 12, -2.4), Vector3.new(6, 3.6, 0.2), hex("#E9E7E2"), M.SmoothPlastic)
		board.Name = "Backboard"
		local bgui = Paint.surface(board, Enum.NormalId.Front, 20)
		local sq = Core.frame(bgui, 0.35, 0.4, 0.3, 0.4, Color3.new(1, 1, 1), 1)
		Core.stroke(sq, hex("#C8553D"), 3)
		local rim = Kit.cylinder(c, L(cf, 0, 10.4, -3.4), 0.12, 1.8, hex("#C8553D"), M.Metal)
		rim.Name = "Rim"
		rim.CanCollide = false
		if i == 1 then
			Kit.detail(c, L(cf, 0, 9.9, -3.4), Vector3.new(1.2, 0.9, 1.2), hex("#C9C9C0"), M.Fabric).Transparency = 0.5
		end
	end
	Kit.ball(c, Plan.cf(196, WALK + 0.9, 70), 1.8, hex("#C8652D"), M.Leather).Name = "Ball"
	-- fence with a gap for the gate
	local h = 10
	Dress.chainRun(c, Plan.v(K.x0, WALK, K.z0), Plan.v(K.x1, WALK, K.z0), h, rng, { signs = { Text.court } })
	Dress.chainRun(c, Plan.v(K.x1, WALK, K.z0), Plan.v(K.x1, WALK, K.z1), h, rng)
	Dress.chainRun(c, Plan.v(K.x1, WALK, K.z1), Plan.v(K.x0, WALK, K.z1), h, rng)
	Dress.chainRun(c, Plan.v(K.x0, WALK, K.z1), Plan.v(K.x0, WALK, 64), h, rng)
	Dress.chainRun(c, Plan.v(K.x0, WALK, 56), Plan.v(K.x0, WALK, K.z0), h, rng)
	Props.build("bench_worn", c, Plan.cf(K.x0 + 3, WALK, 44, Plan.E), { seed = "court-bench" })
end

local function parking(m: Instance, rng: Deps.RngT)
	local K = Plan.parking
	local p = Kit.model(m, "PayLot")
	local marks = Geo.lbox(p, K.x0, WALK, K.z0, K.x1, WALK + 0.03, K.z1, Color3.new(1, 1, 1), M.SmoothPlastic, false)
	marks.Name = "LotMarkings"
	marks.Transparency = 1
	local g, W, H = Paint.surface(marks, Enum.NormalId.Top, 3)
	for row = 0, 1 do
		local y = H * (0.18 + row * 0.5)
		for x = 0, W, 30 do
			Core.px(g, x, y, 2, H * 0.22, hex("#D8D4C8"), rng:range(0.35, 0.65))
		end
	end
	Paint.cracks(g, W, H, rng, 20, { color = hex("#17181A") })
	for _ = 1, 8 do
		Core.dot(g, rng:range(0, W), rng:range(0, H), rng:range(12, 28), hex("#1C1D20"), 0.5)
	end
	local cars: { { x: number, z: number, yaw: number, color: Color3 } } = {
		{ x = 140, z = 116, yaw = 0, color = hex("#6E2E2A") },
		{ x = 182, z = 118, yaw = 0, color = hex("#4A5A3A") },
		{ x = 160, z = 168, yaw = 180, color = hex("#8E8A82") },
	}
	for i, c in cars do
		Props.build("sedan", p, Plan.cf(c.x, WALK, c.z, c.yaw), { color = c.color, seed = "lot-car" .. i })
	end
	-- the pay station and the billboard looming over the lot
	local ps = Plan.cf(124, WALK, 96, Plan.E)
	Kit.block(p, L(ps, 0, 2.5, 0), Vector3.new(1.6, 5, 1.2), hex("#2C5E8A"), M.Metal).Name = "PayStation"
	local pss = Kit.detail(p, L(ps, 0, 4.4, -0.62), Vector3.new(1.2, 0.8, 0.05), hex("#E9E2CF"), M.SmoothPlastic)
	Kit.sign(pss, Text.parking, { font = Enum.Font.Highway, color = C.ink, pixelsPerStud = 40 })
	Signs.billboard(p, Plan.cf(196, WALK, 186, Plan.N), {
		brand = Text.billboard.brand,
		slogan = Text.billboard.slogan,
		width = 36,
		height = 14,
		legs = 18,
		lit = true,
		seed = "quikloan",
	})
	for i, x in { 150, 204 } do
		Dress.lamp(p, x, 142, Plan.N, { lit = i == 1, seed = "lot-lamp" .. i })
	end
	Props.build("jersey_barrier", p, Plan.cf(124, WALK, 140, Plan.E), { seed = "pay-jb" })
end

local function overlook(m: Instance, rng: Deps.RngT)
	local O = Plan.overlook
	local o = Kit.model(m, "Overlook")
	Geo.lbox(o, O.x0, -2, O.z0, O.x1, WALK, O.z1, hex("#8A867D"), M.Pavement).Name = "OverlookDeck"
	-- the dead end: a curb, barriers and a stencil
	for i, z in { -8, 0, 8 } do
		Props.build("jersey_barrier", o, Plan.cf(O.x0 + 1.4, WALK, z, Plan.W), { length = 7, seed = "ov-jb" .. i })
	end
	-- coin binoculars facing the skyline, a bench and the sign
	for i, z in { -10, 10 } do
		local b = Plan.cf(O.x1 - 4, WALK, z, Plan.E)
		Kit.block(o, L(b, 0, 2, 0), Vector3.new(0.6, 4, 0.6), hex("#2C5E8A"), M.Metal).Name = "ScopePost"
		Kit.block(o, L(b, 0, 4.6, 0), Vector3.new(1.6, 1.2, 2.2), hex("#2C5E8A"), M.Metal).Name = "Scope" .. i
		for _, dx in { -0.4, 0.4 } do
			Kit.cylinder(o, L(b, dx, 4.8, -1.3) * CFrame.Angles(math.rad(90), 0, 0), 0.6, 0.5, hex("#1A1A1A"), M.Metal).CanCollide =
				false
		end
	end
	Props.build("bench_worn", o, Plan.cf(O.x1 - 6, WALK, 0, Plan.E), { seed = "ov-bench" })
	local sign = Plan.cf(O.x0 + 6, WALK, -20, Plan.W)
	Kit.block(o, L(sign, -2.4, 3, 0), Vector3.new(0.3, 6, 0.3), hex("#3A2E24"), M.Wood)
	Kit.block(o, L(sign, 2.4, 3, 0), Vector3.new(0.3, 6, 0.3), hex("#3A2E24"), M.Wood)
	local board = Kit.detail(o, L(sign, 0, 4.6, 0), Vector3.new(5.6, 2.4, 0.2), hex("#2F5A3A"), M.Wood)
	local bg = Paint.surface(board, Enum.NormalId.Front, 30)
	Core.bg(bg, hex("#2F5A3A"))
	Core.label(bg, Text.overlook, 0.05, 0.08, 0.9, 0.45, hex("#F4F1E6"), { font = Enum.Font.Oswald, align = Enum.TextXAlignment.Center })
	Core.label(bg, Text.overlookSub, 0.05, 0.55, 0.9, 0.35, C.mustard, { font = Enum.Font.SourceSansItalic, align = Enum.TextXAlignment.Center })
	Dress.lamp(o, O.x0 + 10, 20, Plan.S, { seed = "ov-lamp" })
	Dress.litter(o, O.x0, O.z0, O.x1, O.z1, 8, rng)
end

local function plaza(m: Instance, rng: Deps.RngT)
	local Z = Plan.stationPlaza
	local p = Kit.model(m, "StationPlaza")
	Props.build("newspaper_box", p, Plan.cf(130, WALK, -32, Plan.S), { seed = "plaza-news1" })
	Props.build("newspaper_box", p, Plan.cf(132, WALK, -32, Plan.S), { seed = "plaza-news2" })
	Props.build("bike_rack", p, Plan.cf(200, WALK, -54, Plan.W), { seed = "plaza-bikes" })
	Props.build("bench_worn", p, Plan.cf(140, WALK, -40, Plan.E), { seed = "plaza-bench1" })
	Props.build("trash_can", p, Plan.cf(142, WALK, -46, 0), { seed = "plaza-bin" })
	Props.build("vending_machine", p, Plan.cf(126, WALK, -56, Plan.E), { seed = "plaza-vend" })
	Dress.lamp(p, 170, -30, Plan.S, { seed = "plaza-lamp1" })
	Dress.lamp(p, 124, -42, Plan.E, { lit = false, seed = "plaza-lamp2" })
	Dress.litter(p, Z.x0, Z.z0, Z.x1, Z.z1, 18, rng)
end

---------------------------------------------------------------------------------------------------
function East.build(parent: Instance, mk: Instance): Model
	local m = Kit.model(parent, "East")
	local rng = Deps.Rng.new("east")
	viaduct(m, rng)
	platform(m)
	train(m, rng)
	station(m, mk, rng)
	directoryKiosk(m)
	plaza(m, rng)
	storage(m, rng)
	hardware(m)
	court(m, rng)
	parking(m, rng)
	overlook(m, rng)
	return m
end

return East
