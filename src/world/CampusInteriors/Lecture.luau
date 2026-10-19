--!strict
-- Halvorsen Hall's interior (interior "lecture"): a 1911 building that was "rebuilt" in 1974 and still leaks.
--
--   foyer (south):     terrazzo, the deans' portraits, the trophy case, a bucket under the leak; the exit door
--                      (door_lecture_exit) and the arrival anchor (lecture_entry)
--   lecture hall 101:  sunk 4.5 studs below the main floor: a raked floor of five tiers with desk rows, ramped side
--                      aisles and half-steps down the middle, a stage with the lectern (npc_professor), chalkboards
--                      and the projector screen
--   Finance Club room: (east) three laptop desks (work_desk x3), two market terminals (terminal x2), the pitch
--                      whiteboard, a ticker band and npc_club_president
--   library nook:      (west) stacks, two reading tables (work_desk x2) with banker's lamps
--   lounges:           lockers, benches, notice boards and windows either side of the foyer
--
-- build(parent, mk, origin) -> Model. Bake-safe.

local Deps = require(script.Parent.Deps)
local Shell = require(script.Parent.Shell)

local Kit = Deps.Kit
local Props = Deps.Props
local Signs = Deps.Signs
local Paint = Deps.Paint
local Text = Deps.Text
local Markers = Deps.Markers
local Core = Deps.Gui.Core
local Art = Deps.Gui.Art
local P = Deps.Palette
local C = P.campus
local hex = P.hex
local M = Enum.Material

local Lecture = {}

local X0, X1, Z0, Z1, H = -76, 76, -64, 44, 16
local PIT = -4.5 -- the lecture hall's stage level
local HALL = { x0 = -36, x1 = 36, z0 = Z0, z1 = 8, walk = -7 } -- walk: the back walkway starts here
local WALL = hex("#D6CCB4")
local PLASTER = hex("#E3DCCA")
local WOOD = hex("#5A3A26")

Lecture.ENTRY = { x = 0, z = 37 }

---------------------------------------------------------------------------------------------------
local function shell(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	-- main floor (everything but the hall pit), the pit floor, the ceiling
	local oak = hex("#8A6A48")
	Shell.box(m, F, X0 - 1, -1, HALL.walk, X1 + 1, 0, Z1 + 1, oak, M.WoodPlanks).Name = "Floor"
	Shell.box(m, F, X0 - 1, -1, Z0 - 1, HALL.x0, 0, HALL.walk, oak, M.WoodPlanks).Name = "Floor"
	Shell.box(m, F, HALL.x1, -1, Z0 - 1, X1 + 1, 0, HALL.walk, oak, M.WoodPlanks).Name = "Floor"
	Shell.box(m, F, HALL.x0, PIT - 1, Z0 - 1, HALL.x1, PIT, HALL.walk, hex("#6E5A44"), M.WoodPlanks).Name = "PitFloor"
	local ceil = Shell.box(m, F, X0 - 1, H, Z0 - 1, X1 + 1, H + 1, Z1 + 1, PLASTER, M.SmoothPlastic)
	ceil.Name = "Ceiling"
	local cg, CW, CH = Paint.surface(ceil, Enum.NormalId.Bottom, 1.5, { maxDistance = 0 })
	-- water stains spreading from the leak over the foyer
	for _ = 1, 8 do
		Core.dot(
			cg,
			rng:range(CW * 0.4, CW * 0.6),
			rng:range(CH * 0.7, CH * 0.95),
			rng:range(8, 26),
			hex("#C9B98A"),
			0.45
		)
	end
	-- exterior walls
	Shell.wallX(m, F, Z0 - 0.5, X0 - 1, X1 + 1, PIT, H, 1, WALL)
	Shell.wallX(m, F, Z1 + 0.5, X0 - 1, X1 + 1, 0, H, 1, WALL)
	Shell.wallZ(m, F, X0 - 0.5, Z0, Z1, 0, H, 1, WALL)
	Shell.wallZ(m, F, X1 + 0.5, Z0, Z1, 0, H, 1, WALL)
	-- the hall's walls (down into the pit) and its south wall with two doorways into the foyer
	Shell.wallZ(m, F, HALL.x0 - 0.5, Z0, HALL.z1 + 1, PIT, H, 1, WALL)
	Shell.wallZ(m, F, HALL.x1 + 0.5, Z0, HALL.z1 + 1, PIT, H, 1, WALL)
	Shell.wallX(m, F, HALL.z1 + 0.5, HALL.x0, HALL.x1, 0, H, 1, WALL, nil, {
		{ c = -12, w = 8, h = 10 },
		{ c = 12, w = 8, h = 10 },
	})
	-- the foyer's side walls with doorways into the lounges
	Shell.wallZ(m, F, -24.5, HALL.z1 + 1, Z1, 0, H, 1, WALL, nil, { { c = 30, w = 8, h = 10 } })
	Shell.wallZ(m, F, 24.5, HALL.z1 + 1, Z1, 0, H, 1, WALL, nil, { { c = 30, w = 8, h = 10 } })
	-- the library's and the club room's front walls
	Shell.wallX(m, F, -10.5, X0, HALL.x0 - 1, 0, H, 1, WALL, nil, { { c = -56, w = 8, h = 10 } })
	Shell.wallX(m, F, -10.5, HALL.x1 + 1, X1, 0, H, 1, WALL, nil, { { c = 56, w = 8, h = 10 } })
	-- dark wood wainscot along the public walls
	Shell.box(m, F, X0, 0, Z1 - 0.15, X1, 4, Z1, WOOD, M.Wood, false)
	Shell.box(m, F, -24, 0, HALL.z1 + 1, -23.85, 4, Z1, WOOD, M.Wood, false)
	Shell.box(m, F, 23.85, 0, HALL.z1 + 1, 24, 4, Z1, WOOD, M.Wood, false)
end

---------------------------------------------------------------------------------------------------
-- Lecture hall 101
---------------------------------------------------------------------------------------------------
local function hall(m: Instance, F: Shell.Frame, mk: Instance, rng: Deps.RngT)
	local h = Kit.model(m, "LectureHall")
	local tierC = hex("#7A5E44")
	local seatC = hex("#3C4A5E")
	-- the raked floor: five tiers, each 0.9 up and 7 deep
	for i = 0, 4 do
		local front = -42 + 7 * i
		local top = PIT + 0.9 * (i + 1)
		Shell.box(h, F, -30, PIT, front, 30, top, HALL.walk, Kit.shade(tierC, i * 0.02), M.WoodPlanks).Name = "Tier"
			.. i
		-- half-steps down the centre aisle so nobody has to jump
		Shell.box(h, F, -3, PIT, front - 1.4, 3, top - 0.45, front, Kit.shade(tierC, -0.05), M.WoodPlanks).Name =
			"AisleStep"
		-- a desk row either side of the aisle: writing desk, modesty panel, bench seat (all facing the stage)
		for _, side in { { -29.5, -3.5 }, { 3.5, 29.5 } } do
			local z = front + 1.6
			Shell.box(h, F, side[1], top + 2.4, z - 0.8, side[2], top + 2.7, z + 0.8, hex("#A07A52"), M.Wood).Name =
				"DeskRow"
			Shell.box(h, F, side[1], top, z - 0.9, side[2], top + 2.4, z - 0.7, hex("#6B4E35"), M.Wood, false)
			Shell.box(h, F, side[1], top, z + 2, side[2], top + 1.5, z + 3.4, seatC, M.Fabric).Name = "BenchSeat"
			Shell.box(h, F, side[1], top + 1.5, z + 3.2, side[2], top + 3.6, z + 3.4, seatC, M.Fabric, false)
		end
		-- a forgotten notebook or coffee cup here and there
		if rng:chance(0.7) then
			local x = rng:range(-26, 26)
			Shell.box(h, F, x, top + 2.7, front + 1.2, x + 1.2, top + 2.8, front + 2, C.paper, M.SmoothPlastic, false).Name =
				"Notebook"
		end
	end
	-- side aisles: long ramps from the back walkway down to the stage level
	for _, x in { -33, 33 } do
		local len = HALL.walk - -42
		Kit.wedge(h, F.cf(x, PIT + 2.25, -42 + len / 2, 0), Vector3.new(6, 4.5, len), hex("#6E5A44"), M.WoodPlanks).Name =
			"AisleRamp"
	end
	-- the stage, the lectern and the professor behind it
	Shell.box(h, F, -20, PIT, -62, 20, PIT + 0.6, -48, WOOD, M.WoodPlanks).Name = "Stage"
	Shell.box(h, F, -4, PIT, -48, 4, PIT + 0.3, -46.8, WOOD, M.WoodPlanks).Name = "StageStep"
	local st = PIT + 0.6
	Shell.box(h, F, -1.6, st, -51.8, 1.6, st + 3.8, -50.2, hex("#4A3022"), M.Wood).Name = "Lectern"
	Kit.detail(
		h,
		F.cf(0, st + 4, -50.9) * CFrame.Angles(math.rad(18), 0, 0),
		Vector3.new(3.4, 0.25, 2),
		hex("#5A3A26"),
		M.Wood
	)
	Kit.detail(
		h,
		F.cf(0.9, st + 4.6, -50.4) * CFrame.Angles(math.rad(-30), 0, 0),
		Vector3.new(0.12, 1.4, 0.12),
		hex("#2A2A2A"),
		M.Metal
	).Name =
		"Mic"
	local seal =
		Kit.detail(h, F.cf(0, st + 2.2, -50.15, Shell.S), Vector3.new(2, 2, 0.05), hex("#C8BFA8"), M.SmoothPlastic)
	if not Deps.logo(seal, Enum.NormalId.Front, "eastbridge_state") then
		Kit.sign(seal, "ES", { font = Enum.Font.Garamond, color = hex("#5C2A21"), pixelsPerStud = 50 })
	end
	Markers.npc(mk, "npc_professor", F.cf(0, st + 3, -53.6, Shell.S))
	-- chalkboards either side of the projector screen, windows high in the north wall
	for i, x in { -15, 15 } do
		Props.build("chalkboard", h, F.cf(x, PIT + 2.2, Z0, Shell.S), { seed = "hall-chalk" .. i })
	end
	local screen =
		Kit.detail(h, F.cf(0, PIT + 6.2, Z0 + 0.15, Shell.S), Vector3.new(9, 6, 0.1), hex("#F4F4F0"), M.SmoothPlastic)
	screen.Name = "ProjectorScreen"
	local sg = Paint.surface(screen, Enum.NormalId.Front, 20, { glow = true, brightness = 0.7 })
	Core.bg(sg, hex("#EDEDE6"))
	Core.label(
		sg,
		Text.lecture.course,
		0.05,
		0.05,
		0.9,
		0.18,
		hex("#1F2A44"),
		{ font = Enum.Font.SourceSansBold, align = Enum.TextXAlignment.Center }
	)
	Core.label(sg, Text.lecture.board, 0.08, 0.28, 0.84, 0.66, hex("#2A2622"), { font = Enum.Font.SourceSans })
	for _, x in { -26, 0, 26 } do
		Shell.window(h, F.cf(x, 10.5, Z0, Shell.S), 9, 7, rng, "campus")
	end
	Shell.sign(
		h,
		F.cf(-26, 3.5, Z0, Shell.S),
		8,
		1.4,
		Text.lecture.hall,
		{ color = hex("#24262A"), ink = hex("#E3DCCA") }
	)
	-- pendant lights on long rods
	for i, x in { -18, 0, 18 } do
		for k, z in { -48, -24 } do
			Kit.detail(h, F.cf(x, H - 2, z), Vector3.new(0.1, 4, 0.1), hex("#2A2A2A"), M.Metal).Name = "Rod"
			local shade = Kit.cylinder(h, F.cf(x, H - 4.4, z), 0.9, 2.6, hex("#E8D9A8"), M.Neon)
			shade.Name = "Pendant"
			shade.CanCollide = false
			shade:AddTag("InteriorLight")
			if (i == 1 and k == 1) or (i == 3 and k == 2) then
				Kit.light(shade, "point", { Color = hex("#FFE2B0"), Range = 34, Brightness = 1 })
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The foyer
---------------------------------------------------------------------------------------------------
local function portrait(parent: Instance, cf: CFrame, name: string, i: number)
	Kit.detail(parent, cf * CFrame.new(0, 0, -0.1), Vector3.new(4.4, 5.6, 0.2), hex("#6B4A1E"), M.Wood).Name =
		"PortraitFrame"
	local canvas =
		Kit.detail(parent, cf * CFrame.new(0, 0.2, -0.22), Vector3.new(3.6, 4.4, 0.05), hex("#3A2E24"), M.SmoothPlastic)
	canvas.Name = "Portrait"
	local g, W, Hh = Paint.surface(canvas, Enum.NormalId.Front, 30)
	local bg = Core.bg(g, hex("#2E2620"))
	Core.gradient(bg, hex("#4A3A2C"), hex("#1E1814"), 90)
	-- a dour dean: head, shoulders, a hint of a collar
	Core.dot(g, W / 2, Hh * 0.38, W * 0.34, hex("#C9A68A"), 0.05)
	Core.px(g, W * 0.18, Hh * 0.58, W * 0.64, Hh * 0.42, hex("#1E1E22"))
	Core.px(g, W * 0.44, Hh * 0.58, W * 0.12, Hh * 0.14, hex("#E9E2CF"))
	Core.px(g, W * 0.36, Hh * 0.2, W * 0.28, Hh * 0.06, if i == 2 then hex("#8E8A80") else hex("#3A2E24"))
	local plate = Kit.detail(parent, cf * CFrame.new(0, -3.3, -0.2), Vector3.new(3, 0.6, 0.05), P.street.brass, M.Metal)
	Kit.sign(plate, name, { font = Enum.Font.Garamond, color = hex("#2A2622"), pixelsPerStud = 50 })
end

local function foyer(m: Instance, F: Shell.Frame, mk: Instance, rng: Deps.RngT)
	local f = Kit.model(m, "Foyer")
	-- terrazzo with a brass-inlaid medallion
	local tz = Shell.box(f, F, -24, 0, HALL.z1 + 1, 24, 0.04, Z1, hex("#BDB5A3"), M.Marble, false)
	tz.Name = "Terrazzo"
	local tg, TW, TH = Paint.surface(tz, Enum.NormalId.Top, 4, { maxDistance = 0 })
	Core.checker(Core.frame(tg, 0, 0, 1, 1, hex("#BDB5A3")), 12, 9, hex("#BDB5A3"), hex("#A39A86"))
	local med = Core.dot(tg, TW / 2, TH * 0.55, TH * 0.4, hex("#8E3B2E"), 0.1)
	Core.stroke(med, P.street.brass, 6)
	Core.label(
		tg,
		"ES · 1911",
		0.35,
		0.47,
		0.3,
		0.16,
		P.street.brass,
		{ font = Enum.Font.Garamond, align = Enum.TextXAlignment.Center }
	)
	-- the deans
	local P3 = Text.lecture.portraits
	portrait(f, F.cf(-23.85, 8, 18, Shell.E), P3[1], 1)
	portrait(f, F.cf(23.85, 8, 18, Shell.W), P3[2], 2)
	portrait(f, F.cf(-23.85, 8, 38, Shell.E), P3[3], 3)
	-- the trophy case
	local tc = F.cf(22.6, 0, 38, Shell.W)
	Kit.block(f, tc * CFrame.new(0, 1.5, 0), Vector3.new(7, 3, 2.4), WOOD, M.Wood).Name = "TrophyCase"
	local glass = Kit.detail(f, tc * CFrame.new(0, 4.6, 0), Vector3.new(7, 3.2, 2.4), hex("#AFC4CC"), M.Glass)
	glass.Transparency = 0.6
	for k = -1, 1 do
		Kit.detail(
			f,
			tc * CFrame.new(k * 2.2, 3.8 + (k + 1) * 0.2, 0),
			Vector3.new(0.6, 1.2 + k * 0.2, 0.6),
			P.street.gold,
			M.Metal
		).Name =
			"Trophy"
	end
	local plaque = Kit.detail(f, tc * CFrame.new(0, 2.2, -1.25), Vector3.new(5, 0.8, 0.05), P.street.brass, M.Metal)
	Kit.sign(plaque, Text.lecture.trophies, { font = Enum.Font.Garamond, color = hex("#2A2622"), pixelsPerStud = 40 })
	-- benches, the leak and its bucket
	for _, x in { -14, 14 } do
		Shell.box(f, F, x - 3, 1.6, 41.6, x + 3, 1.9, 43.4, WOOD, M.Wood).Name = "Bench"
		Shell.box(f, F, x - 2.8, 0, 42.3, x + 2.8, 1.6, 42.7, hex("#2A2A2A"), M.Metal, false)
	end
	local bucket = Kit.cylinder(f, F.cf(6, 0.9, 20), 1.8, 1.6, hex("#E2B93B"), M.Plastic)
	bucket.Name = "Bucket"
	Kit.cylinder(f, F.cf(6, 1.5, 20), 0.05, 1.4, hex("#4A5A62"), M.Glass).CanCollide = false
	local wet = Kit.detail(f, F.cf(9, 1.5, 21.6, 25), Vector3.new(1.6, 3, 0.1), hex("#E2B93B"), M.Plastic)
	wet.Name = "WetFloorSign"
	Kit.sign(wet, "CAUTION\nWET FLOOR", { font = Enum.Font.Highway, color = hex("#141414"), pixelsPerStud = 40 })
	-- signs: the hall's name over its doors, directions
	Shell.sign(f, F.cf(0, 12.4, HALL.z1 + 1, Shell.S), 30, 1.8, Text.lecture.foyer .. " · " .. Text.lecture.foyerSub, {
		color = hex("#2A2622"),
		ink = hex("#D6CDB4"),
		font = Enum.Font.Garamond,
	})
	for _, x in { -12, 12 } do
		Shell.sign(f, F.cf(x, 10.8, HALL.z1 + 1, Shell.S), 7, 0.9, Text.lecture.hall, { color = hex("#24262A") })
	end
	Shell.sign(f, F.cf(-23.9, 10.8, 30, Shell.E), 7, 0.9, "← " .. Text.lecture.library, { color = hex("#24262A") })
	Shell.sign(f, F.cf(23.9, 10.8, 30, Shell.W), 7, 0.9, Text.lecture.club .. " →", { color = hex("#24262A") })
	-- the way out to the quad (the arrival anchor stands just inside it)
	Shell.exit(
		f,
		mk,
		"door_lecture_exit",
		F.cf(0, 0, Z1, Shell.N),
		{ label = Text.exitTo.lecture, doorColor = hex("#3E2418") }
	)
	for _, x in { -14, 14 } do
		Shell.window(f, F.cf(x, 8.5, Z1, Shell.N), 6, 7, rng, "campus")
	end
	local hang = Kit.detail(f, F.cf(0, H - 0.4, 26), Vector3.new(0.2, 0.8, 0.2), hex("#2A2A2A"), M.Metal)
	hang.Name = "ChandelierRod"
	Props.build("chandelier", f, F.cf(0, H - 5.8, 26), { seed = "foyer-chandelier", lit = true })
end

---------------------------------------------------------------------------------------------------
-- The Finance Club room
---------------------------------------------------------------------------------------------------
local function club(m: Instance, F: Shell.Frame, mk: Instance, rng: Deps.RngT)
	local c = Kit.model(m, "FinanceClub")
	local rug = Shell.box(c, F, 42, 0, -54, 70, 0.06, -20, hex("#1F2A44"), M.Fabric, false)
	rug.Name = "ClubRug"
	-- three laptop desks along the north wall (work_desk)
	for i, x in { 46, 56, 66 } do
		local desk = Shell.box(c, F, x - 3.5, 2.8, Z0, x + 3.5, 3.1, Z0 + 3.2, hex("#3E2A1E"), M.Wood)
		desk.Name = "ClubDesk"
		Markers.interact(desk, "work_desk")
		for _, dx in { -3.2, 3.2 } do
			Shell.box(c, F, x + dx - 0.2, 0, Z0 + 0.2, x + dx + 0.2, 2.8, Z0 + 3, hex("#2A2A2A"), M.Metal, false)
		end
		-- an open laptop
		Shell.box(c, F, x - 1.1, 3.1, Z0 + 1.2, x + 1.1, 3.18, Z0 + 2.6, hex("#9AA0A6"), M.Metal, false).Name = "Laptop"
		local lid = Kit.detail(
			c,
			F.cf(x, 3.9, Z0 + 1.1) * CFrame.Angles(math.rad(-12), 0, 0),
			Vector3.new(2.2, 1.5, 0.08),
			hex("#9AA0A6"),
			M.Metal
		)
		local lg = Paint.surface(lid, Enum.NormalId.Back, 50, { glow = true })
		local lbg = Core.bg(lg, hex("#0B1622"))
		Core.lineChart(lbg, 6, 10, 98, 55, Core.series(rng, 24, 50, 1.5, 0.2), Core.UP, 2)
		Shell.chair(c, F.cf(x, 0, Z0 + 5, Shell.N), hex("#5C2A21"))
	end
	-- two market terminals on the east wall (terminal)
	for i, z in { -42, -32 } do
		Shell.box(c, F, X1 - 3, 2.8, z - 3, X1, 3.1, z + 3, hex("#2A2A2A"), M.Metal).Name = "TerminalDesk"
		local mon = Shell.box(c, F, X1 - 1.2, 3.4, z - 2.2, X1 - 0.9, 6, z + 2.2, hex("#141414"), M.SmoothPlastic)
		mon.Name = "TerminalScreen"
		Markers.interact(mon, "terminal")
		local g = Paint.surface(mon, Enum.NormalId.Left, 40, { glow = true, brightness = 1.1 })
		local bg = Core.bg(g, hex("#0B1622"))
		Core.candles(bg, 8, 24, 150, 70, rng, 18)
		Core.label(bg, "EB TERMINAL " .. i, 0.04, 0.02, 0.6, 0.14, Core.AMBER, { font = Enum.Font.Code })
		Shell.chair(c, F.cf(X1 - 5, 0, z, Shell.E), hex("#2A2A2A"))
	end
	-- the pitch whiteboard, the ticker, the trophy shelf, the couch
	local wb =
		Kit.detail(c, F.cf(HALL.x1 + 1.1, 6, -38, Shell.E), Vector3.new(12, 5, 0.1), hex("#F4F4F0"), M.SmoothPlastic)
	wb.Name = "PitchBoard"
	local wg, WW, WH = Paint.surface(wb, Enum.NormalId.Front, 20)
	Art.whiteboard(wg, WW, WH, rng)
	Core.label(wg, Text.lecture.clubBoard, 0.55, 0.08, 0.42, 0.8, hex("#1F4E8C"), { font = Enum.Font.PermanentMarker })
	Signs.tickerBand(c, F.cf(56, 11.2, Z0, Shell.S), { width = 34, height = 1.4, seed = "club-ticker" })
	Props.build("trophy_shelf", c, F.cf(HALL.x1 + 2, 0, -22, Shell.E), { seed = "club-trophies" })
	-- a sagging couch and the pizza from last pitch night
	local couch = F.cf(56, 0, -16, Shell.N)
	Kit.block(c, couch * CFrame.new(0, 1, 0), Vector3.new(9, 2, 3.4), hex("#6E2E2A"), M.Fabric).Name = "Couch"
	Kit.detail(c, couch * CFrame.new(0, 2.6, 1.4), Vector3.new(9, 2.6, 0.8), hex("#5C2622"), M.Fabric)
	for _, s in { -1, 1 } do
		Kit.detail(c, couch * CFrame.new(s * 4.6, 1.8, 0), Vector3.new(0.8, 1.6, 3.4), hex("#5C2622"), M.Fabric)
	end
	Props.build("pizza_box", c, F.cf(48, 0, -18, 30), { count = 3, seed = "club-pizza" })
	Props.build("mini_fridge", c, F.cf(70, 0, -13, Shell.N), { seed = "club-fridge" })
	-- the club's name over the door (lounge side) and inside
	Shell.sign(c, F.cf(56, 11, -10, Shell.S), 14, 1.8, Text.lecture.club, { color = hex("#1F2A44"), ink = C.mustard })
	Shell.sign(
		c,
		F.cf(56, 11.6, -11, Shell.N),
		22,
		1.6,
		Text.lecture.clubSub,
		{ color = hex("#1F2A44"), ink = C.mustard }
	)
	for _, z in { -52, -24 } do
		Shell.window(c, F.cf(X1, 8, z, Shell.W), 7, 6, rng, "campus")
	end
	Markers.npc(mk, "npc_club_president", F.cf(54, 3, -36, Shell.S))
	Shell.troffer(c, F.cf(56, H - 0.1, -36), Vector3.new(3, 0.15, 6), true)
	Shell.troffer(c, F.cf(56, H - 0.1, -54), Vector3.new(3, 0.15, 6))
end

---------------------------------------------------------------------------------------------------
-- The library nook
---------------------------------------------------------------------------------------------------
local BOOK_COLORS =
	{ hex("#5C2A21"), hex("#1F2A44"), hex("#2F5A3A"), hex("#6B4E35"), hex("#8A2C2C"), hex("#3E4A52"), hex("#C9A13B") }

local function shelf(
	parent: Instance,
	F: Shell.Frame,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	faces: { Enum.NormalId },
	label: string?,
	rng: Deps.RngT
)
	local s = Shell.box(parent, F, x0, 0, z0, x1, 9, z1, WOOD, M.Wood)
	s.Name = "Stack"
	for _, face in faces do
		local g, W, Hh = Paint.surface(s, face, 6)
		Core.bg(g, hex("#3E2A1E"))
		for r = 0, 4 do
			local y = Hh * (r / 5)
			Core.px(g, 0, y + Hh / 5 - 3, W, 3, hex("#2A1C12"))
			local x = 2
			while x < W - 3 do
				local bw = rng:range(1.5, 3.5)
				local bh = rng:range(Hh / 5 * 0.55, Hh / 5 * 0.85)
				Core.px(g, x, y + Hh / 5 - 3 - bh, bw, bh, rng:pick(BOOK_COLORS))
				x += bw + rng:range(0, 0.6)
			end
		end
		if label then
			Core.label(
				g,
				label,
				0.1,
				0.0,
				0.8,
				0.06,
				P.street.brass,
				{ font = Enum.Font.Garamond, align = Enum.TextXAlignment.Center }
			)
		end
	end
	return s
end

local function library(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local l = Kit.model(m, "LibraryNook")
	local S = Text.lecture.stacks
	-- stacks along the west and north walls, two freestanding double-sided runs
	shelf(l, F, X0, Z0, X0 + 2, -46, { Enum.NormalId.Right }, S[1], rng)
	shelf(l, F, -72, Z0, -40, Z0 + 2, { Enum.NormalId.Back }, S[2], rng)
	shelf(l, F, -66, -50, -64, -30, { Enum.NormalId.Left, Enum.NormalId.Right }, S[3], rng)
	shelf(l, F, -58, -50, -56, -30, { Enum.NormalId.Left, Enum.NormalId.Right }, S[4], rng)
	-- two reading tables with banker's lamps (work_desk)
	for i, z in { -40, -22 } do
		local t = Shell.box(l, F, -50, 2.8, z - 2.5, -40, 3.1, z + 2.5, hex("#6B4A2E"), M.Wood)
		t.Name = "ReadingTable"
		Markers.interact(t, "work_desk")
		for _, x in { -49.4, -40.6 } do
			Shell.box(l, F, x - 0.25, 0, z - 2, x + 0.25, 2.8, z + 2, hex("#4A3022"), M.Wood, false)
		end
		Props.build(
			"desk_lamp",
			l,
			F.cf(-45, 3.1, z - 1.6, 0),
			{ color = hex("#2F5A3A"), lit = true, seed = "lib-lamp" .. i }
		)
		Props.build("book_stack", l, F.cf(-48, 3.1, z + 1, 20), { seed = "lib-books" .. i })
		Shell.chair(l, F.cf(-45, 0, z + 4, Shell.N), WOOD)
		Shell.chair(l, F.cf(-45, 0, z - 4, Shell.S), WOOD)
	end
	Props.build("globe", l, F.cf(-42, 3.1, -22, 0), { seed = "lib-globe" })
	-- the card catalogue and the rolling ladder
	Shell.box(l, F, -40, 0, -60, -37.2, 4.2, -54, hex("#6B4A2E"), M.Wood).Name = "CardCatalogue"
	Kit.detail(
		l,
		F.cf(-71, 4.5, -36, Shell.E) * CFrame.Angles(math.rad(-12), 0, 0),
		Vector3.new(2, 9, 0.3),
		hex("#8A6A48"),
		M.Wood
	).Name =
		"Ladder"
	Shell.sign(
		l,
		F.cf(-56, 11, -10, Shell.S),
		14,
		1.6,
		Text.lecture.library,
		{ color = hex("#2A2622"), ink = hex("#D6CDB4"), font = Enum.Font.Garamond }
	)
	for _, z in { -40, -22 } do
		Shell.window(l, F.cf(X0, 8, z, Shell.E), 6, 6, rng, "campus")
	end
	local t = Shell.troffer(l, F.cf(-50, H - 0.1, -36), Vector3.new(3, 0.15, 6), true)
	t.Color = hex("#FFE9C2")
end

---------------------------------------------------------------------------------------------------
-- Lounges either side of the foyer
---------------------------------------------------------------------------------------------------
local function lounges(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local l = Kit.model(m, "Lounges")
	-- west: lockers, benches, a notice board, vending
	Props.build("lockers", l, F.cf(-50, 0, Z1 - 1, Shell.N), { count = 8, seed = "hh-lockers1" })
	Props.build("lockers", l, F.cf(X0 + 1, 0, 10, Shell.E), { count = 6, seed = "hh-lockers2" })
	Shell.box(l, F, -60, 1.6, 24, -50, 1.9, 26, WOOD, M.Wood).Name = "Bench"
	Shell.box(l, F, -55.2, 0, 24.6, -54.8, 1.6, 25.4, hex("#2A2A2A"), M.Metal, false)
	Props.build("vending_machine", l, F.cf(-40, 0, -8.4, Shell.S), { seed = "hh-vend" })
	local nb = Kit.block(l, F.cf(X0 + 0.3, 6, 30, Shell.E), Vector3.new(10, 5, 0.4), hex("#9A7650"), M.Wood)
	nb.Name = "NoticeBoard"
	local nf = Kit.detail(
		l,
		F.cf(X0 + 0.55, 6, 30, Shell.E),
		Vector3.new(9.4, 4.4, 0.02),
		Color3.new(1, 1, 1),
		M.SmoothPlastic
	)
	nf.Transparency = 1
	local ng, NW, NH = Paint.surface(nf, Enum.NormalId.Front, 20)
	Paint.flyers(
		ng,
		NW,
		NH,
		rng,
		{ Text.flyers[1], Text.flyers[5], Text.flyers[7], Text.flyers[9], Text.flyers[10], Text.flyers[4] }
	)
	for _, x in { -60, -40 } do
		Shell.window(l, F.cf(x, 8, Z1, Shell.N), 7, 7, rng, "campus")
	end
	Shell.window(l, F.cf(X0, 8, 0, Shell.E), 7, 7, rng, "campus")
	-- east: posters, a drinking fountain, radiators under the windows
	for i, z in { 16, 40 } do
		local spec = Text.posters[i + 2]
		Signs.poster(l, F.cf(24 + 1.02, 5, z, Shell.E), {
			title = spec.title,
			body = spec.body,
			colors = { hex("#E9E2CF"), hex("#8E3B2E"), hex("#2A2622") },
			width = 3.2,
			height = 4.4,
			seed = "hh-poster" .. i,
		})
	end
	Shell.box(l, F, 60, 2.4, Z1 - 1.4, 62.4, 3, Z1, hex("#B8B8B0"), M.Metal).Name = "DrinkingFountain"
	Shell.box(l, F, 60.8, 0, Z1 - 0.8, 61.6, 2.4, Z1, hex("#9A9A92"), M.Metal, false)
	for _, x in { 50, 70 } do
		Shell.window(l, F.cf(x, 8, Z1, Shell.N), 7, 7, rng, "campus")
		Shell.box(l, F, x - 3, 0.6, Z1 - 0.9, x + 3, 3, Z1 - 0.3, hex("#A9A396"), M.CorrodedMetal).Name = "Radiator"
	end
	Shell.window(l, F.cf(X1, 8, 10, Shell.W), 7, 7, rng, "campus")
	Shell.box(l, F, 40, 1.6, 2, 50, 1.9, 4, WOOD, M.Wood).Name = "Bench"
	Shell.box(l, F, 44.8, 0, 2.6, 45.2, 1.6, 3.4, hex("#2A2A2A"), M.Metal, false)
	Shell.troffer(l, F.cf(-50, H - 0.1, 18), Vector3.new(3, 0.15, 6), true)
	Shell.troffer(l, F.cf(50, H - 0.1, 18), Vector3.new(3, 0.15, 6), true)
	Shell.troffer(l, F.cf(-50, H - 0.1, 0), Vector3.new(3, 0.15, 6))
	Shell.troffer(l, F.cf(50, H - 0.1, 0), Vector3.new(3, 0.15, 6))
end

---------------------------------------------------------------------------------------------------
-- Lounge furniture: study tables (west), the Finance Club's recruiting corner (east), the foyer's pilasters
---------------------------------------------------------------------------------------------------
local function studyTable(parent: Instance, F: Shell.Frame, x: number, z: number, rng: Deps.RngT)
	Kit.cylinder(parent, F.cf(x, 2.95, z), 0.25, 4.6, hex("#8A6A48"), M.Wood).Name = "StudyTable"
	Kit.cylinder(parent, F.cf(x, 1.4, z), 2.8, 0.6, hex("#2A2A2A"), M.Metal).Name = "TablePedestal"
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local cx, cz = x + math.cos(a) * 3.4, z + math.sin(a) * 3.4
		Shell.chair(parent, F.facing(cx, cz, x, z), hex("#5C2A21"))
	end
	if rng:chance(0.7) then
		Props.build(
			"book_stack",
			parent,
			F.cf(x + 0.6, 3.07, z - 0.4, rng:range(0, 90)),
			{ seed = "hh-table-books" .. x .. z }
		)
	end
end

local function loungeExtras(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local l = Kit.model(m, "LoungeExtras")
	-- west: two round study tables and a rug between the lockers
	studyTable(l, F, -38, 2, rng)
	studyTable(l, F, -38, 18, rng)
	Props.build("rug_office", l, F.cf(-38, 0, 10, 0), { color = hex("#5C2A21"), seed = "hh-rug" })
	-- east: the Finance Club's recruiting table, an easel by the club door, a pair of sofas
	Shell.box(l, F, 42, 2.7, -6.6, 50, 3, -3.4, hex("#D8CDB4"), M.SmoothPlastic).Name = "ClubTable"
	for _, x in { 42.6, 49.4 } do
		Shell.box(l, F, x - 0.15, 0, -6.2, x + 0.15, 2.7, -3.8, hex("#5A5F63"), M.Metal, false)
	end
	local cloth = Shell.box(l, F, 41.9, 0.6, -3.42, 50.1, 3, -3.3, hex("#1F2A44"), M.Fabric, false)
	cloth.Name = "TableBanner"
	local cg = Paint.surface(cloth, Enum.NormalId.Back, 20)
	Core.bg(cg, hex("#1F2A44"))
	Core.label(
		cg,
		Text.lecture.joinClub,
		0.03,
		0.08,
		0.94,
		0.5,
		C.mustard,
		{ font = Enum.Font.Oswald, align = Enum.TextXAlignment.Center }
	)
	Core.label(cg, Text.lecture.joinClubSub, 0.03, 0.6, 0.94, 0.32, hex("#E9E2CF"), {
		font = Enum.Font.SourceSansBold,
		align = Enum.TextXAlignment.Center,
	})
	Props.build("pizza_box", l, F.cf(48, 3, -5, 8), { count = 1, seed = "hh-club-pizza" })
	for i = 0, 3 do
		Shell.box(
			l,
			F,
			43 + i * 0.5,
			3,
			-5.6 + i * 0.1,
			44.2 + i * 0.5,
			3.04 + i * 0.02,
			-4.2 + i * 0.1,
			C.paper,
			M.SmoothPlastic,
			false
		).Name =
			"SignupSheet"
	end
	-- the easel
	local easel = F.cf(64, 0, -5, Shell.S + 20)
	for _, s in { -1, 1 } do
		Kit.detail(
			l,
			easel * CFrame.new(s * 1.1, 2.9, 0) * CFrame.Angles(math.rad(-8), 0, math.rad(s * 6)),
			Vector3.new(0.2, 5.8, 0.2),
			hex("#6B4E35"),
			M.Wood
		)
	end
	local board = Kit.detail(
		l,
		easel * CFrame.new(0, 4.4, -0.35) * CFrame.Angles(math.rad(-8), 0, 0),
		Vector3.new(3, 3.6, 0.1),
		hex("#F4F1E6"),
		M.SmoothPlastic
	)
	board.Name = "EaselBoard"
	Kit.sign(
		board,
		Text.lecture.easel,
		{ font = Enum.Font.PermanentMarker, color = hex("#1F4E8C"), pixelsPerStud = 40, padding = 0.1 }
	)
	-- sofas facing each other over a coffee table
	Props.build("sofa_office", l, F.cf(62, 0, 14, Shell.N), { color = hex("#6E2E2A"), seed = "hh-sofa1" })
	Props.build("sofa_office", l, F.cf(62, 0, 26, Shell.S), { color = hex("#4A5A3A"), seed = "hh-sofa2" })
	Props.build("coffee_table", l, F.cf(62, 0, 20, 0), { seed = "hh-coffee" })
	Props.build("trash_can", l, F.cf(27, 0, -8.2, 0), { seed = "hh-bin" })
	-- pilasters down the foyer's side walls (it was a grand building once)
	for _, x in { -23.4, 23.4 } do
		for _, z in { 12, 24, 42.5 } do
			Shell.box(l, F, x - 0.6, 0, z - 1, x + 0.6, H, z + 1, hex("#CFC5AE"), M.Concrete, false).Name = "Pilaster"
		end
	end
end

---------------------------------------------------------------------------------------------------
function Lecture.build(parent: Instance, mk: Instance, origin: Vector3): Model
	local m = Kit.model(parent, "lecture")
	m:SetAttribute("Interior", "lecture")
	m:SetAttribute("LightingPreset", "campus_interior")
	local F = Shell.frame(origin)
	local rng = Deps.Rng.new("halvorsen-interior")
	shell(m, F, rng)
	hall(m, F, mk, rng)
	foyer(m, F, mk, rng)
	club(m, F, mk, rng)
	library(m, F, rng)
	lounges(m, F, rng)
	loungeExtras(m, F, rng)
	Markers.anchor(mk, "lecture_entry", F.cf(Lecture.ENTRY.x, 3, Lecture.ENTRY.z, Shell.N))
	return m
end

return Lecture
