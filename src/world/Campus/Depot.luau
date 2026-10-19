--!strict
-- Eastbridge Transit Depot (south-west): the yard with its worn bay markings, the steel canopy over the boarding
-- island (where new players spawn), the Route 9 bus at bay 1, the waiting room (walk in), the bus garage with one bay
-- rolled open and a second bus inside, driveway aprons on the avenue, and the store kiosk (store_kiosk) by the spawn.
-- Bake-safe.

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

local Depot = {}

local WALK = Plan.WALK
local D = Plan.depot

local function L(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, y, z)
end

---------------------------------------------------------------------------------------------------
-- Yard paint, island, canopy
---------------------------------------------------------------------------------------------------
local function yardPaint(m: Instance, rng: Deps.RngT)
	local Y = D.yard
	local sheet = Geo.lbox(m, Y.x0, WALK, Y.z0, Y.x1, WALK + 0.03, Y.z1, Color3.new(1, 1, 1), M.SmoothPlastic, false)
	sheet.Name = "YardMarkings"
	sheet.Transparency = 1
	sheet.CastShadow = false
	local gui, W, H = Paint.surface(sheet, Enum.NormalId.Top, 4)
	local ppsX = W / (Y.x1 - Y.x0)
	local function zpx(z: number): number
		return (z - Y.z0) * ppsX
	end
	local function xpx(x: number): number
		return (x - Y.x0) * ppsX
	end
	local paint = hex("#C9B458")
	-- bay edge lines either side of the island and the bus lane
	for _, z in { 45, 59, 77, 92 } do
		local a = xpx(-246)
		Core.px(gui, a, zpx(z), xpx(-166) - a, 3, paint, rng:range(0.35, 0.6))
	end
	-- "BUS ONLY" stencils
	for _, s in { { -232, 50 }, { -232, 84 } } do
		Core.label(gui, "BUS ONLY", (s[1] - Y.x0) / (Y.x1 - Y.x0), (s[2] - Y.z0) / (Y.z1 - Y.z0) - 0.02, 0.14, 0.05, hex("#D8D4C8"), {
			font = Enum.Font.Highway,
			transparency = 0.45,
		})
	end
	-- oil stains under where buses idle
	for _ = 1, 9 do
		Core.dot(gui, xpx(rng:range(-240, -180)), zpx(rng:pick({ 52, 84, 120 }) + rng:range(-3, 3)), rng:range(14, 34), hex("#1C1D20"), rng:range(0.45, 0.7))
	end
	Paint.cracks(gui, W, H, rng, 18, { color = hex("#17181A") })
end

local function island(m: Instance)
	local I = D.island
	local top = I.top
	Geo.lbox(m, I.x0, WALK - 0.2, I.z0, I.x1, top, I.z1, hex("#8A8780"), M.Concrete).Name = "BoardingIsland"
	-- yellow safety edges
	for _, z in { I.z0 + 0.4, I.z1 - 0.4 } do
		Kit.detail(m, Plan.cf((I.x0 + I.x1) / 2, top + 0.02, z), Vector3.new(I.x1 - I.x0, 0.04, 0.8), hex("#C9A93E"), M.SmoothPlastic).Name =
			"SafetyEdge"
	end
	-- ramps at both ends (the island is half a stud up)
	for _, e in { { I.x0 - 1.5, Plan.E }, { I.x1 + 1.5, Plan.W } } do
		Kit.wedge(m, Plan.cf(e[1], WALK + (top - WALK) / 2, (I.z0 + I.z1) / 2, e[2] + 180), Vector3.new(I.z1 - I.z0, top - WALK, 3), hex("#8A8780"), M.Concrete).Name =
			"IslandRamp"
	end
end

local function canopy(m: Instance, rng: Deps.RngT)
	local K = D.canopy
	local I = D.island
	local cm = Kit.model(m, "Canopy")
	local steel = hex("#4E5A5E")
	local cx, cz = (K.x0 + K.x1) / 2, (K.z0 + K.z1) / 2
	local roof = Geo.lbox(cm, K.x0, K.y, K.z0, K.x1, K.y + 0.6, K.z1, hex("#5F6366"), M.CorrodedMetal)
	roof.Name = "Roof"
	-- fascia with the depot name on the avenue side
	local fascia = Geo.lbox(cm, K.x0, K.y - 1.8, K.z0 - 0.4, K.x1, K.y + 0.9, K.z0, hex("#2C5E8A"), M.Metal)
	fascia.Name = "Fascia"
	local fg = Paint.surface(fascia, Enum.NormalId.Front, 20)
	Core.bg(fg, hex("#2C5E8A"))
	Core.label(fg, Text.depot, 0.02, 0.1, 0.96, 0.8, hex("#E9E2CF"), { font = Enum.Font.Highway, align = Enum.TextXAlignment.Center })
	Paint.grime(fg, 1, 1, rng, { streaks = 6, soot = 0.0 })
	Geo.lbox(cm, K.x0, K.y - 1.8, K.z1, K.x1, K.y + 0.9, K.z1 + 0.4, hex("#2C5E8A"), M.Metal, false).Name = "FasciaBack"
	-- columns down the island, beams across
	local iz = (I.z0 + I.z1) / 2
	for _, x in { -234, -205, -176 } do
		Kit.block(cm, Plan.cf(x, I.top + (K.y - I.top) / 2, iz), Vector3.new(1.2, K.y - I.top, 1.2), steel, M.CorrodedMetal).Name =
			"Column"
		Kit.detail(cm, Plan.cf(x, K.y - 0.6, cz), Vector3.new(0.8, 1.2, K.z1 - K.z0), steel, M.Metal).Name = "Beam"
		Kit.detail(cm, Plan.cf(x, I.top + 0.6, iz), Vector3.new(2, 1.2, 2), C.concreteDark, M.Concrete)
	end
	Kit.detail(cm, Plan.cf(cx, K.y - 0.6, iz), Vector3.new(K.x1 - K.x0, 1, 0.8), steel, M.Metal).Name = "Spine"
	-- fluorescent tubes under the roof, two of them throwing light
	local n = 0
	for _, x in { -226, -212, -198, -184 } do
		for _, z in { 52, 84 } do
			n += 1
			local t = Kit.detail(cm, Plan.cf(x, K.y - 0.3, z), Vector3.new(6, 0.25, 0.8), hex("#EDEBE0"), M.Neon)
			t.Name = "CanopyLight"
			t.Transparency = if n == 3 then 0.75 else 0.15
			t:AddTag("StreetLight")
			if n == 3 then
				t:SetAttribute("Flicker", true)
			end
			if n == 2 or n == 7 then
				Kit.light(t, "point", { Color = hex("#EDEBE0"), Range = 30, Brightness = 1.2 })
			end
		end
	end
	-- the bay signs hanging from the beams
	for i, z in { 52, 84 } do
		local sg = Kit.detail(cm, Plan.cf(-205, K.y - 2.6, z, Plan.N), Vector3.new(14, 1.6, 0.2), hex("#1A1A1A"), M.Metal)
		sg.Name = "BaySign" .. i
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local g = Paint.surface(sg, face, 24, { glow = true, brightness = 0.9 })
			Core.bg(g, hex("#141414"))
			Core.label(g, Text.depotBays[i], 0.03, 0.1, 0.94, 0.8, if i == 1 then hex("#FFB547") else hex("#8E8A82"), {
				font = Enum.Font.Code,
				align = Enum.TextXAlignment.Center,
			})
		end
	end
	-- rainwater downpipes
	for _, x in { K.x0 + 0.4, K.x1 - 0.4 } do
		Geo.pipe(cm, Plan.v(x, WALK, K.z1 + 0.6), Plan.v(x, K.y, K.z1 + 0.6), 0.6, C.rustDark, M.CorrodedMetal, false)
	end
	return cm
end

---------------------------------------------------------------------------------------------------
-- Store kiosk (store_kiosk) on the island, facing the spawn
---------------------------------------------------------------------------------------------------
local function storeKiosk(m: Instance)
	local I = D.island
	local cf = Plan.cf(-188, I.top, 71, Plan.W)
	local k = Kit.model(m, "StoreKiosk")
	local body = Kit.block(k, L(cf, 0, 3, 0), Vector3.new(3.4, 6, 2.2), hex("#24262A"), M.Metal)
	body.Name = "KioskBody"
	Markers.interact(body, "store_kiosk")
	Kit.block(k, L(cf, 0, 0.2, 0), Vector3.new(4, 0.4, 2.8), C.concreteDark, M.Concrete)
	local screen = Kit.detail(k, L(cf, 0, 4.2, -1.12) * CFrame.Angles(math.rad(-10), 0, 0), Vector3.new(2.8, 2.4, 0.1), hex("#0E1A24"), M.SmoothPlastic)
	screen.Name = "KioskScreen"
	local g = Paint.surface(screen, Enum.NormalId.Front, 60, { glow = true, brightness = 1.2 })
	local bg = Core.bg(g, hex("#13243A"))
	Core.gradient(bg, hex("#1F3A5C"), hex("#0E1A24"), 90)
	Core.label(g, Text.storeKiosk, 0.06, 0.1, 0.88, 0.3, C.mustard, { font = Enum.Font.Oswald, align = Enum.TextXAlignment.Center })
	Core.label(g, Text.storeKioskSub, 0.06, 0.45, 0.88, 0.2, hex("#E8EEF5"), { font = Enum.Font.SourceSansBold, align = Enum.TextXAlignment.Center })
	local btn = Core.frame(g, 0.25, 0.72, 0.5, 0.16, C.mustard)
	Core.round(btn, 0.3)
	Core.label(btn, "TAP TO BROWSE", 0.05, 0.1, 0.9, 0.8, hex("#13243A"), { font = Enum.Font.GothamBold, align = Enum.TextXAlignment.Center })
	-- a lit header on top
	local hd = Kit.detail(k, L(cf, 0, 6.6, 0), Vector3.new(3.6, 1.2, 2.4), C.mustard, M.Neon)
	hd.Transparency = 0.25
	hd.Name = "KioskHeader"
	hd:AddTag("StreetLight")
end

---------------------------------------------------------------------------------------------------
-- Waiting room and garage
---------------------------------------------------------------------------------------------------
local function waitingRoom(m: Instance)
	local B = D.building
	local w, d = B.x1 - B.x0, B.z1 - B.z0
	local depth, sh = 20, 13
	local bm, fr = Buildings.block(m, {
		name = "DepotWaitingRoom",
		cf = Plan.cf((B.x0 + B.x1) / 2, WALK, (B.z0 + B.z1) / 2, Plan.N),
		w = w,
		d = d,
		h = B.h,
		seed = "depot-building",
		storeys = 1,
		color = hex("#8A8780"),
		material = M.Concrete,
		trim = hex("#6E6A5F"),
		shop = { depth = depth, height = sh },
		painted = { Buildings.face("left", 3, 1), Buildings.face("right", 3, 1) },
		roof = { ac = 3, vents = 2 },
		graffiti = { "RENT IS DUE" },
		graffitiFace = "right",
	})
	local front = fr.front
	Buildings.storefront(bm, front, w, {
		height = sh,
		sign = Text.depotWaiting,
		signColor = hex("#2C5E8A"),
		signInk = hex("#E9E2CF"),
		door = -18,
		open = true,
		frame = hex("#4E5A5E"),
		seed = "depot-front",
	})
	local floor = Kit.block(bm, L(front, 0, 0.05, depth / 2), Vector3.new(w - 2.4, 0.1, depth - 0.2), hex("#A8A296"), M.Slate)
	floor.Name = "WaitingFloor"
	-- rows of bolted seats, the ticket window, a vending machine and the departures board
	for r = 0, 1 do
		for i = 0, 3 do
			local sc = L(front, -6 + i * 7, 0, 7 + r * 5)
			Kit.block(bm, L(sc, 0, 1.6, 0), Vector3.new(6, 0.3, 1.8), hex("#C9A13B"), M.Plastic).Name = "Seats"
			Kit.detail(bm, L(sc, 0, 2.6, 0.8), Vector3.new(6, 1.8, 0.2), hex("#C9A13B"), M.Plastic)
			Kit.detail(bm, L(sc, 0, 0.8, 0), Vector3.new(0.4, 1.6, 1.2), C.steel, M.Metal)
		end
	end
	local tw = L(front, 22, 0, depth - 0.1)
	Kit.block(bm, L(tw, 0, 2, -1.2), Vector3.new(10, 4, 2.4), hex("#6B4E35"), M.Wood).Name = "TicketCounter"
	local glass = Kit.detail(bm, L(tw, 0, 6.5, -1.2), Vector3.new(10, 5, 0.2), hex("#AFC4CC"), M.Glass)
	glass.Transparency = 0.55
	local tsign = Kit.detail(bm, L(tw, 0, 10, -0.1), Vector3.new(9, 1.4, 0.1), hex("#1A1A1A"), M.Metal)
	Kit.sign(tsign, "TICKETS · ROUTE 9", { font = Enum.Font.Highway, color = hex("#FFB547"), pixelsPerStud = 30, glow = true })
	Props.build("vending_machine", bm, L(front, -27, 0, depth - 1.6), { seed = "depot-vend" })
	local board = Kit.detail(bm, L(front, -4, 9.6, depth - 0.12), Vector3.new(14, 4, 0.1), hex("#141414"), M.SmoothPlastic)
	board.Name = "Departures"
	local bg = Paint.surface(board, Enum.NormalId.Front, 24, { glow = true, brightness = 1 })
	Core.bg(bg, hex("#141414"))
	local rows = {
		"ROUTE   DESTINATION            BAY  STATUS",
		"9       DOWNTOWN LOOP          1    BOARDING",
		"9X      WALL ST EXPRESS        —    SUBWAY ONLY",
		"14      RIVERSIDE / CANAL ST   2    CANCELLED",
		"22      MIDVALE MALL           2    DELAYED",
	}
	for i, r in rows do
		Core.label(bg, r, 0.03, 0.04 + (i - 1) * 0.19, 0.94, 0.16, if i == 1 then hex("#8E8A82") else hex("#FFB547"), {
			font = Enum.Font.Code,
			align = Enum.TextXAlignment.Left,
		})
	end
	local clock = Kit.detail(bm, L(front, 13, 10, depth - 0.12), Vector3.new(2.4, 2.4, 0.1), hex("#E9E2CF"), M.SmoothPlastic)
	local cg, CW, CH = Paint.surface(clock, Enum.NormalId.Front, 40)
	Art.clockFace(cg, CW, CH, 6, 10, C.ink, hex("#E9E2CF"))
	for i, x in { -12, 0, 12 } do
		local t = Kit.detail(bm, L(front, x, sh - 0.4, 10), Vector3.new(0.8, 0.2, 6), hex("#F4F1E6"), M.Neon)
		t.Name = "Fluorescent"
		t:AddTag("InteriorLight")
		if i == 2 then
			Kit.light(t, "point", { Color = hex("#F4F1E6"), Range = 22, Brightness = 0.8 })
		end
	end
end

local function garage(m: Instance)
	local G = D.garage
	local w, d = G.x1 - G.x0, G.z1 - G.z0
	local depth, sh = 28, 17
	local bm, fr = Buildings.block(m, {
		name = "BusGarage",
		cf = Plan.cf((G.x0 + G.x1) / 2, WALK, (G.z0 + G.z1) / 2, Plan.N),
		w = w,
		d = d,
		h = G.h,
		seed = "garage",
		storeys = 1,
		color = hex("#6E3326"),
		trim = hex("#8E8A80"),
		shop = { depth = depth, height = sh },
		painted = { Buildings.face("right", 4, 1, { lit = 0 }) },
		roof = { ac = 2, vents = 4 },
		graffiti = { "HODL", "EB 4 LIFE" },
		graffitiFace = "right",
	})
	local front = fr.front
	local rng = fr.rng
	-- three bays: two shutters down, the middle one rolled up
	local pierW = 2.4
	local bayW = (w - pierW * 4) / 3
	for i = 0, 3 do
		local x = -w / 2 + pierW / 2 + i * (bayW + pierW)
		Kit.block(bm, L(front, x, sh / 2, -0.6), Vector3.new(2.4, sh, 1.6), Geo.vary(hex("#6E3326"), rng, 0.05), M.Brick).Name =
			"Pier"
	end
	for b = 0, 2 do
		local x = -w / 2 + pierW + bayW / 2 + b * (bayW + pierW)
		if b ~= 2 then
			local sh2 = Kit.block(bm, L(front, x, sh / 2, -0.3), Vector3.new(bayW, sh, 0.4), Geo.vary(hex("#7A7E80"), rng, 0.08), M.CorrodedMetal)
			sh2.Name = "Shutter"
			local g, GW, GH = Paint.surface(sh2, Enum.NormalId.Front, 6)
			for y = 4, GH, 6 do
				Core.px(g, 0, y, GW, 2, hex("#4E5254"), 0.3)
			end
			Core.label(g, "BAY " .. (b + 1) .. " · KEEP CLEAR", 0.25, 0.42, 0.5, 0.12, hex("#C9B458"), { font = Enum.Font.Highway, align = Enum.TextXAlignment.Center })
		else
			-- the open (east) bay: shutter rolled up into its housing, a bus nosed out of the dark (the only bay with
			-- room in front of it: the waiting room stands before the other two)
			Kit.detail(bm, L(front, x, sh - 0.8, -0.8), Vector3.new(bayW, 1.6, 1.6), hex("#5A5F63"), M.CorrodedMetal).Name =
				"ShutterRoll"
			Props.build("city_bus", bm, L(front, x, 0, depth - 0.5 - 19.6), {
				seed = "garage-bus",
				color = hex("#9A8A3A"),
			})
		end
	end
	Kit.block(bm, L(front, 0, 0.05, depth / 2), Vector3.new(w - 2.4, 0.1, depth - 0.2), hex("#6A6862"), M.Concrete).Name =
		"GarageFloor"
	local dark = Kit.detail(bm, L(front, 0, sh / 2, depth - 0.1), Vector3.new(w - 2.4, sh, 0.1), hex("#1A1B1C"), M.SmoothPlastic)
	dark.Name = "BackWall"
	local lamp = Kit.detail(bm, L(front, 0, sh - 0.6, 10), Vector3.new(1.2, 0.4, 6), hex("#E8D9A8"), M.Neon)
	lamp:AddTag("InteriorLight")
	Kit.light(lamp, "point", { Color = hex("#E8D9A8"), Range = 24, Brightness = 0.6 })
	Signs.buildingName(bm, L(front, 0, sh + 1.2, -0.3), {
		text = Text.garage,
		style = "paint",
		height = 2.4,
		width = 34,
		seed = "garage-name",
	})
end

---------------------------------------------------------------------------------------------------
function Depot.build(parent: Instance, mk: Instance): Model
	local m = Kit.model(parent, "Depot")
	local rng = Deps.Rng.new("depot")
	yardPaint(m, rng)
	island(m)
	canopy(m, rng)
	storeKiosk(m)
	waitingRoom(m)
	garage(m)
	-- the Route 9 bus at bay 1, door side to the island
	Props.build("city_bus", m, Plan.cf(D.busX, WALK, D.busZ, Plan.E), { seed = "route9" })
	-- driveway aprons onto the avenue (road -> sidewalk)
	for _, x in { -236, -168 } do
		Kit.wedge(m, Plan.cf(x, WALK / 2, 12.75, 0), Vector3.new(14, WALK, 2.5), hex("#8E8A82"), M.Concrete).Name =
			"Driveway"
	end
	-- benches, a shelter and the timetable on the island
	local I = D.island
	Props.build("bus_shelter", m, Plan.cf(-232, I.top, 71.5, Plan.N), { seed = "depot-shelter" })
	Props.build("bench_worn", m, Plan.cf(-222, I.top, 72.5, Plan.N), { seed = "depot-bench1" })
	Props.build("bench_worn", m, Plan.cf(-180, I.top, 64, Plan.N), { seed = "depot-bench2" })
	Props.build("trash_can", m, Plan.cf(-207, I.top, 74, 0), { seed = "depot-bin" })
	Props.build("newspaper_box", m, Plan.cf(-174, I.top, 73.5, Plan.W), { seed = "depot-news" })
	-- no idling sign on a post at the yard entrance, and a chain-link fence on the west edge
	local post = Plan.cf(-152, WALK, 30, Plan.N)
	Kit.block(m, L(post, 0, 4, 0), Vector3.new(0.3, 8, 0.3), C.steel, M.Metal)
	local ns = Kit.detail(m, L(post, 0, 7, -0.2), Vector3.new(2.6, 1.6, 0.08), hex("#E9E2CF"), M.Metal)
	Kit.sign(ns, Text.depotNoIdle, { font = Enum.Font.Highway, color = hex("#8A2C2C"), pixelsPerStud = 40 })
	for i, z in { 48, 84, 120 } do
		Props.build("chainlink_fence", m, Plan.cf(-249, WALK, z, Plan.E), { length = 36, barbed = true, seed = "depot-fence" .. i })
	end
	Props.build("jersey_barrier", m, Plan.cf(-160, WALK, 120, Plan.E), { seed = "depot-jb" })
	Dress.cone(m, -166, 100, rng)
	Dress.cone(m, -163, 102, rng)
	Dress.litter(m, D.yard.x0, D.yard.z0, D.yard.x1, D.yard.z1, 22, rng)
	return m
end

return Depot
