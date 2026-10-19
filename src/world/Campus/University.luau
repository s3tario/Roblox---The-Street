--!strict
-- Eastbridge State University, north of the avenue: Halvorsen Hall (faces the quad from the west), the Career Center
-- (faces south across the quad), Marlow House (the dorm block, faces west), the quad itself (patchy lawns, cracked
-- paths, the dead fountain, bare trees), the iron fence and gates on the avenue and the two service yards.
-- Also places this area's doors and exterior interacts (recruiting board, Wall of Fame leaderboard). Bake-safe.

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

local University = {}

local WALK = Plan.WALK
local LAWN = Plan.LAWN

local function L(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, y, z)
end

local STONE = hex("#C8BFA8")
local STONE_DARK = hex("#9E9682")

---------------------------------------------------------------------------------------------------
-- Shared entrance pieces
---------------------------------------------------------------------------------------------------
-- Steps rising toward the building: `front` = a CFrame on the facade plane (LookVector out), the landing runs from the
-- facade out to `depth`, then `steps` steps of 0.5 down to the plaza.
local function stoop(
	parent: Instance,
	front: CFrame,
	width: number,
	depth: number,
	steps: number,
	color: Color3
): number
	local top = steps * 0.5
	Kit.block(parent, L(front, 0, top / 2, -depth / 2), Vector3.new(width, top, depth), color, M.Concrete).Name =
		"Landing"
	local run = 1.4
	local outer = -depth - run * (steps - 1) - run / 2
	Kit.stairs(
		parent,
		L(front, 0, 0, outer) * CFrame.Angles(0, math.pi, 0),
		width - 2,
		steps - 1,
		0.5,
		run,
		Kit.shade(color, -0.05),
		M.Concrete
	).Name =
		"Steps"
	-- worn nosing strips
	for i = 0, steps - 2 do
		Kit.detail(
			parent,
			L(front, 0, 0.5 * (i + 1) + 0.02, outer + run * i - run / 2 + 0.2),
			Vector3.new(width - 2.2, 0.05, 0.3),
			hex("#B8962E"),
			M.DiamondPlate
		).Transparency =
			0.4
	end
	return top
end

-- Double doors in a stone surround on a facade (decorative: the Door trigger stands in front of them).
local function doubleDoor(parent: Instance, front: CFrame, y: number, color: Color3, surround: Color3)
	Kit.detail(parent, L(front, 0, y + 5, -0.15), Vector3.new(9.6, 10.6, 0.3), surround, M.Limestone)
	Kit.detail(parent, L(front, 0, y + 4.6, -0.32), Vector3.new(8, 9.2, 0.1), hex("#141414"), M.SmoothPlastic)
	for _, s in { -1, 1 } do
		local leaf = Kit.detail(parent, L(front, s * 2, y + 4.4, -0.42), Vector3.new(3.8, 8.6, 0.2), color, M.Wood)
		leaf.Name = "DoorLeaf"
		-- raised panels and a brass pull
		for _, py in { 2.2, 6.2 } do
			Kit.detail(
				parent,
				L(front, s * 2, y + py, -0.56),
				Vector3.new(2.8, 2.8, 0.08),
				Kit.shade(color, 0.08),
				M.Wood
			)
		end
		Kit.detail(parent, L(front, s * 0.5, y + 4.4, -0.6), Vector3.new(0.18, 1.6, 0.18), P.street.brass, M.Metal)
	end
	-- transom
	local tr = Kit.detail(parent, L(front, 0, y + 9.4, -0.4), Vector3.new(7.6, 1.0, 0.12), hex("#3A4248"), M.Glass)
	tr.Reflectance = 0.2
end

---------------------------------------------------------------------------------------------------
-- Halvorsen Hall (lecture): three-storey Georgian brick with a pedimented portico
---------------------------------------------------------------------------------------------------
local function halvorsen(m: Instance, mk: Instance)
	local H = Plan.halvorsen
	local w = H.z1 - H.z0
	local d = H.x1 - H.x0
	local cf = Plan.cf((H.x0 + H.x1) / 2, WALK, H.doorZ, Plan.E)
	local bm, fr = Buildings.block(m, {
		name = "HalvorsenHall",
		cf = cf,
		w = w,
		d = d,
		h = H.h,
		seed = "halvorsen",
		storeys = 3,
		groundH = 16,
		color = hex("#6A3428"),
		trim = STONE,
		windows = {
			cols = 15,
			w = 4.4,
			h = 8,
			from = 1,
			to = 3,
			lit = 0.22,
			style = "arched",
			margin = 6,
			skip = { { x0 = -14, x1 = 14, s0 = 1, s1 = 1 } },
		},
		painted = {
			Buildings.face("right", 8, 2, { lit = 0.15 }),
			Buildings.face("left", 8, 2, { lit = 0.1 }),
		},
		roof = { tanks = 1, ac = 4, vents = 5, hatch = true },
	})
	local rng = fr.rng
	local front = fr.front
	-- portico: landing + steps, four columns, entablature, pediment
	local top = stoop(bm, front, 26, 8, 4, hex("#9C978C"))
	for _, x in { -9, -3, 3, 9 } do
		Kit.cylinder(bm, L(front, x, top + 7, -6.5), 14, 2.2, STONE, M.Limestone)
		Kit.detail(bm, L(front, x, top + 0.4, -6.5), Vector3.new(2.9, 0.8, 2.9), STONE_DARK, M.Limestone)
		Kit.detail(bm, L(front, x, top + 13.6, -6.5), Vector3.new(2.9, 0.8, 2.9), STONE_DARK, M.Limestone)
	end
	local entY = top + 14.8
	Kit.block(bm, L(front, 0, entY, -4), Vector3.new(26, 1.6, 8), STONE, M.Limestone).Name = "Entablature"
	for _, s in { -1, 1 } do
		Kit.wedge(
			bm,
			L(front, s * 6.5, entY + 0.8 + 2.5, -4.2) * CFrame.Angles(0, math.rad(-90 * s), 0),
			Vector3.new(7.6, 5, 13),
			STONE,
			M.Limestone
		)
	end
	Signs.buildingName(bm, L(front, 0, entY - 0.6, -8.02), {
		text = Text.halvorsen,
		style = "stone",
		height = 1.1,
		width = 22,
		seed = "halvorsen-name",
	})
	doubleDoor(bm, front, top, hex("#3E2418"), STONE)
	Dress.lantern(bm, L(front, -6, top + 8.5, -0.1), true)
	Dress.lantern(bm, L(front, 6, top + 8.5, -0.1), false)
	Signs.plaque(bm, L(front, 11.5, top + 4, -0.05), {
		title = Text.halvorsen,
		text = Text.halvorsenSub .. "\n" .. Text.founded,
		width = 3.4,
		height = 2.4,
	})
	-- dead ivy creeping up the south corner
	for i = 1, 6 do
		local x = w / 2 - rng:range(1, 9)
		local y = rng:range(2, 22)
		Kit.detail(
			bm,
			L(front, x, y, -0.25) * CFrame.Angles(0, 0, math.rad(rng:range(-30, 30))),
			Vector3.new(rng:range(2, 4), rng:range(3, 8), 0.2),
			Geo.vary(hex("#4A3E28"), rng, 0.15),
			M.Grass
		).Name = "Ivy"
			.. i
	end
	-- cupola with a clock that stopped years ago
	local cup = L(fr.cf, 0, H.h + 0.6, 0)
	Kit.block(bm, L(cup, 0, 3, 0), Vector3.new(9, 6, 9), hex("#5E2E23"), M.Brick)
	Kit.detail(bm, L(cup, 0, 6.3, 0), Vector3.new(10, 0.6, 10), STONE, M.Limestone)
	Kit.cylinder(bm, L(cup, 0, 8.4, 0), 3.6, 6.4, hex("#E3DED0"), M.SmoothPlastic)
	Kit.ball(bm, L(cup, 0, 10.4, 0), 6.6, hex("#4E7A68"), M.Metal)
	Kit.detail(bm, L(cup, 0, 14.4, 0), Vector3.new(0.3, 3, 0.3), hex("#2A2A2A"), M.Metal)
	local face = Kit.detail(bm, L(cup, 0, 3.2, -4.6), Vector3.new(4, 4, 0.2), hex("#E9E2CF"), M.SmoothPlastic)
	local gui, W, Hh = Paint.surface(face, Enum.NormalId.Front, 30)
	Art.clockFace(gui, W, Hh, 4, 52, C.ink, hex("#E9E2CF"))
	-- fire escape on the end facing the avenue
	Props.build("fire_escape", bm, L(fr.cf, w / 2 + 0.1, 0, 12) * CFrame.Angles(0, math.rad(-90), 0), {
		floors = 2,
		storey = 14,
		seed = "halvorsen-fe",
	})
	-- the lecture door
	Markers.door(mk, "door_campus_lecture", L(front, 0, top + 5, -1.3))
	-- bike rack and a bench either side of the steps
	Props.build("bike_rack", bm, L(front, 17, 0, -5), { seed = "hh-bikes" })
	Props.build("bench_worn", bm, L(front, -18, 0, -6) * CFrame.Angles(0, math.pi, 0), { seed = "hh-bench" })
end

---------------------------------------------------------------------------------------------------
-- The Career Center: a 1970s brick box with a glass entrance pavilion, the recruiting board and the Wall of Fame
---------------------------------------------------------------------------------------------------
local function lobbyBackdrop(part: BasePart, rng: Deps.RngT)
	local gui, W, H = Paint.surface(part, Enum.NormalId.Front, 12, { glow = false })
	local bg = Core.bg(gui, hex("#3A3630"))
	Core.gradient(bg, hex("#4A443A"), hex("#25221E"), 90)
	-- reception desk, a lit welcome sign and the Life Roll kiosk's rarity glow down the hall
	Core.px(gui, W * 0.3, H * 0.62, W * 0.4, H * 0.2, hex("#6B4E35"))
	Core.label(gui, Text.cc.welcome, 0.2, 0.18, 0.6, 0.12, hex("#F2E6C0"), { font = Enum.Font.Oswald })
	local glow = { hex("#9AA0A6"), hex("#4CAF50"), hex("#3D7BD9"), hex("#9C4DD9"), hex("#E3B341"), hex("#FF6FD8") }
	for i, c in glow do
		Core.px(gui, W * (0.76 + i * 0.03), H * 0.35, W * 0.02, H * 0.3, c, 0.2)
	end
	for _ = 1, 4 do
		Core.px(
			gui,
			rng:range(0, W * 0.25),
			rng:range(H * 0.25, H * 0.5),
			W * 0.06,
			H * 0.14,
			rng:pick({
				hex("#E9E2CF"),
				hex("#C8553D"),
				hex("#2F5A3A"),
			})
		)
	end
	-- ceiling lights
	for i = 0, 3 do
		Core.px(gui, W * (0.12 + i * 0.22), H * 0.04, W * 0.12, H * 0.02, hex("#F7F0DA"))
	end
end

local function careerCenter(m: Instance, mk: Instance)
	local CC = Plan.careerCenter
	local w = CC.x1 - CC.x0
	local d = CC.z1 - CC.z0
	local cf = Plan.cf(CC.doorX, WALK, (CC.z0 + CC.z1) / 2, Plan.S)
	local bm, fr = Buildings.block(m, {
		name = "CareerCenter",
		cf = cf,
		w = w,
		d = d,
		h = CC.h,
		seed = "career-center",
		storeys = 2,
		groundH = 15,
		color = hex("#8A5040"),
		trim = hex("#A49C8C"),
		windows = {
			cols = 12,
			w = 6,
			h = 6.5,
			from = 1,
			to = 2,
			lit = 0.4,
			margin = 5,
			ac = 0.15,
			skip = { { x0 = -13, x1 = 13, s0 = 1, s1 = 1 } },
		},
		painted = { Buildings.face("left", 5, 1), Buildings.face("right", 5, 1) },
		roof = { ac = 5, vents = 4 },
	})
	local rng = fr.rng
	local front = fr.front
	-- the glass entrance pavilion (with a painted lobby behind the glass)
	local pv = L(front, 0, 0, -5)
	local frameC = hex("#2B2D2F")
	Kit.block(bm, L(front, 0, 12.5, -4), Vector3.new(22, 1, 10), hex("#B9B4A8"), M.Concrete).Name = "Canopy"
	for _, x in { -8.6, 8.6 } do
		Kit.block(bm, L(front, x, 6, -5), Vector3.new(0.8, 12, 0.8), frameC, M.Metal)
		local side = Kit.block(bm, L(front, x, 6, -2.5), Vector3.new(0.3, 12, 5), hex("#6E8088"), M.Glass)
		side.Transparency = 0.55
		side.CastShadow = false
	end
	local back = Kit.detail(bm, L(front, 0, 6, -0.3), Vector3.new(17, 12, 0.2), hex("#3A3630"), M.SmoothPlastic)
	lobbyBackdrop(back, rng)
	for _, x in { -5.6, 5.6 } do
		local g = Kit.block(bm, L(pv, x, 6, 0), Vector3.new(5.2, 12, 0.3), hex("#6E8088"), M.Glass)
		g.Transparency = 0.5
		g.Reflectance = 0.12
		g.CastShadow = false
	end
	for _, s in { -1, 1 } do
		local leaf = Kit.block(bm, L(pv, s * 1.5, 4.75, 0), Vector3.new(3, 8.5, 0.25), hex("#7A8C94"), M.Glass)
		leaf.Name = "GlassDoor"
		leaf.Transparency = 0.4
		Kit.detail(bm, L(pv, s * 0.4, 4.5, -0.25), Vector3.new(0.15, 2.4, 0.15), hex("#C0C0B8"), M.Metal)
	end
	Kit.detail(bm, L(pv, 0, 9.4, 0), Vector3.new(17, 0.4, 0.4), frameC, M.Metal)
	Signs.buildingName(bm, L(front, 0, 13, -9.02), {
		text = Text.careerCenter,
		style = "lightbox",
		height = 2.2,
		width = 18,
		lit = true,
		seed = "cc-sign",
	})
	-- recruiting banners hanging from the brick
	for i, x in { -30, 30 } do
		local ban = Kit.detail(bm, L(front, x, 19, -0.6), Vector3.new(4, 9, 0.1), hex("#1F2A44"), M.Fabric)
		local gui = Paint.surface(ban, Enum.NormalId.Front, 30)
		Core.bg(gui, hex("#1F2A44"))
		Core.label(
			gui,
			"RECRUITING\nSEASON",
			0.08,
			0.1,
			0.84,
			0.45,
			C.mustard,
			{ font = Enum.Font.Oswald, align = Enum.TextXAlignment.Center }
		)
		Core.label(gui, Text.university, 0.08, 0.62, 0.84, 0.28, C.paper, {
			font = Enum.Font.SourceSans,
			align = Enum.TextXAlignment.Center,
		})
		Kit.detail(bm, L(front, x, 23.6, -0.9), Vector3.new(4.6, 0.25, 0.8), hex("#2A2A2A"), M.Metal).Name = "BannerArm"
			.. i
	end
	Markers.door(mk, "door_campus_career_center", L(front, 0, 5, -6.4))
	Signs.plaque(bm, L(front, -11.2, 3.5, -0.05), {
		title = Text.careerCenter,
		text = Text.cc.hours,
		width = 3.2,
		height = 2.4,
	})

	-- The campus RECRUITING BOARD (bulletin): a roofed corkboard on posts, just east of the entrance
	local bb = L(front, -17, 0, -7)
	local post = hex("#3A2E24")
	for _, x in { -4.4, 4.4 } do
		Kit.block(bm, L(bb, x, 4, 0), Vector3.new(0.6, 8, 0.6), post, M.Wood)
	end
	Kit.detail(
		bm,
		L(bb, 0, 8.4, 0.3) * CFrame.Angles(math.rad(-12), 0, 0),
		Vector3.new(10.4, 0.3, 2.2),
		hex("#4A3A2C"),
		M.WoodPlanks
	)
	local board = Kit.block(bm, L(bb, 0, 4.9, 0), Vector3.new(8.4, 5, 0.4), hex("#9A7650"), M.Wood)
	board.Name = "RecruitingBoard"
	Markers.interact(board, "bulletin")
	local bgui = Paint.surface(board, Enum.NormalId.Front, 24)
	Core.bg(bgui, hex("#A07C55"))
	Core.label(bgui, Text.recruitingBoard, 0.05, 0.02, 0.9, 0.14, C.ink, {
		font = Enum.Font.Oswald,
		align = Enum.TextXAlignment.Center,
	})
	local pins = Kit.detail(bm, L(bb, 0, 4.4, -0.22), Vector3.new(8, 3.9, 0.02), Color3.new(1, 1, 1), M.SmoothPlastic)
	pins.Transparency = 1
	local pg, PW, PH = Paint.surface(pins, Enum.NormalId.Front, 24)
	Paint.flyers(pg, PW, PH, Deps.Rng.new("recruiting-pins"), Text.recruitingPins)
	local sub = Kit.detail(bm, L(bb, 0, 7.75, -0.22), Vector3.new(8, 0.5, 0.02), Color3.new(1, 1, 1), M.SmoothPlastic)
	sub.Transparency = 1
	Kit.sign(sub, Text.recruitingBoardSub, { font = Enum.Font.SpecialElite, color = C.ink, pixelsPerStud = 40 })

	-- The Wall of Fame leaderboard (BoardId CareerPrestige; LeaderboardService draws on the part named "Screen")
	local lb = L(front, 26, 0, -6)
	local steel = hex("#3A3D40")
	for _, x in { -6.6, 6.6 } do
		Kit.block(bm, L(lb, x, 6, 0.4), Vector3.new(0.8, 12, 0.8), steel, M.Metal)
	end
	Kit.block(bm, L(lb, 0, 0.4, 0.4), Vector3.new(15, 0.8, 2.4), C.concreteDark, M.Concrete)
	Kit.block(bm, L(lb, 0, 6.6, 0.55), Vector3.new(13, 9, 0.5), hex("#1C1E20"), M.Metal).Name = "ScreenHousing"
	local screen = Kit.block(bm, L(lb, 0, 6.4, 0.2), Vector3.new(12, 8, 0.2), hex("#0E1A24"), M.SmoothPlastic)
	screen.Name = "Screen"
	Markers.interact(screen, "leaderboard", { BoardId = "CareerPrestige" })
	local header = Kit.detail(bm, L(lb, 0, 11.6, 0.3), Vector3.new(13, 1.6, 0.3), hex("#24262A"), M.Metal)
	Kit.sign(header, Text.wallOfFame, {
		font = Enum.Font.Oswald,
		color = C.mustard,
		pixelsPerStud = 30,
		glow = true,
	})
	local hsub = Kit.detail(bm, L(lb, 0, 1.6, 0.15), Vector3.new(12, 0.9, 0.05), hex("#24262A"), M.Metal)
	Kit.sign(hsub, Text.wallOfFameSub, { font = Enum.Font.SourceSansBold, color = C.paper, pixelsPerStud = 30 })

	-- planters (dead shrubs) and an ashtray bin flank the entrance
	for _, x in { -13.5, 13.5 } do
		Kit.block(bm, L(front, x, 1.2, -3), Vector3.new(4, 2.4, 3), C.concreteDark, M.Concrete)
		Kit.detail(bm, L(front, x, 2.5, -3), Vector3.new(3.4, 0.3, 2.4), C.dirt, M.Ground)
		Kit.detail(bm, L(front, x, 3.4, -3), Vector3.new(2.2, 1.8, 1.6), hex("#5A5038"), M.Grass)
	end
	Props.build("trash_can", bm, L(front, 9.8, 0, -10), { seed = "cc-bin" })
end

---------------------------------------------------------------------------------------------------
-- Marlow House: the four-storey dorm block
---------------------------------------------------------------------------------------------------
local function marlow(m: Instance, mk: Instance)
	local D = Plan.dorm
	local w = D.z1 - D.z0
	local d = D.x1 - D.x0
	local cf = Plan.cf((D.x0 + D.x1) / 2, WALK, D.doorZ, Plan.W)
	local bm, fr = Buildings.block(m, {
		name = "MarlowHouse",
		cf = cf,
		w = w,
		d = d,
		h = D.h,
		seed = "marlow",
		storeys = 4,
		groundH = 14,
		color = hex("#7E4232"),
		trim = hex("#8E8A80"),
		windows = {
			cols = 16,
			w = 4,
			h = 6,
			from = 1,
			to = 4,
			lit = 0.3,
			ac = 0.25,
			margin = 5,
			skip = { { x0 = -10, x1 = 10, s0 = 1, s1 = 1 } },
		},
		painted = {
			Buildings.face("left", 7, 3, { lit = 0.3, ac = 0.3 }),
			Buildings.face("right", 7, 3, { lit = 0.25 }),
			Buildings.face("back", 14, 3, { lit = 0.3, ac = 0.35 }),
		},
		roof = { tanks = 2, ac = 4, vents = 6, hatch = true },
	})
	local front = fr.front
	-- the entrance: a concrete canopy on steel posts, glass doors, the name board and a card reader
	Kit.block(bm, L(front, 0, 11.5, -4.5), Vector3.new(16, 0.8, 9), hex("#9C988F"), M.Concrete).Name = "Canopy"
	for _, x in { -7.2, 7.2 } do
		Kit.block(bm, L(front, x, 5.6, -8.4), Vector3.new(0.5, 11.2, 0.5), C.steel, M.CorrodedMetal)
	end
	Kit.detail(bm, L(front, 0, 5, -0.15), Vector3.new(9, 10, 0.3), hex("#3A3A38"), M.Metal)
	for _, s in { -1, 1 } do
		local g = Kit.detail(bm, L(front, s * 2, 4.6, -0.35), Vector3.new(3.8, 8.8, 0.15), hex("#5A6A70"), M.Glass)
		g.Transparency = 0.3
		g.Name = "GlassDoor"
		Kit.detail(bm, L(front, s * 0.5, 4.4, -0.5), Vector3.new(0.15, 2.6, 0.15), hex("#B0B0A8"), M.Metal)
	end
	Signs.buildingName(bm, L(front, 0, 11.9, -9.02), {
		text = Text.dorm,
		style = "paint",
		height = 1.8,
		width = 14,
		seed = "marlow-sign",
	})
	Kit.detail(bm, L(front, 5.6, 4.6, -0.4), Vector3.new(0.6, 0.9, 0.3), hex("#1A1A1A"), M.Metal).Name = "CardReader"
	Kit.detail(bm, L(front, 5.6, 4.85, -0.56), Vector3.new(0.3, 0.12, 0.05), hex("#E04040"), M.Neon).Name = "ReaderLed"
	local sub = Kit.detail(bm, L(front, -6, 7.6, -0.25), Vector3.new(3, 1.2, 0.05), hex("#E9E2CF"), M.SmoothPlastic)
	Kit.sign(sub, Text.dormInside.quiet, { font = Enum.Font.SpecialElite, color = C.ink, pixelsPerStud = 50 })
	Dress.lantern(bm, L(front, 0, 10.4, -0.1), true)
	Markers.door(mk, "door_campus_dorm", L(front, 0, 5, -1.3))
	-- fire escapes on the front's north end and on the south end
	Props.build("fire_escape", bm, L(front, 44, 0, -0.1), { floors = 3, storey = 13.3, seed = "marlow-fe1" })
	Props.build("fire_escape", bm, L(fr.cf, -w / 2 - 0.1, 0, 4) * CFrame.Angles(0, math.rad(90), 0), {
		floors = 3,
		storey = 13.3,
		seed = "marlow-fe2",
	})
	-- smokers' bench, overflowing bin, bikes
	Props.build("bench_worn", bm, L(front, -14, 0, -4) * CFrame.Angles(0, math.pi, 0), { seed = "marlow-bench" })
	Props.build("trash_can", bm, L(front, -10, 0, -3), { seed = "marlow-bin" })
	Props.build("bike_rack", bm, L(front, 14, 0, -4), { seed = "marlow-bikes" })
	-- a bedsheet banner hung from a window: dorm life
	local sheet = Kit.detail(bm, L(front, -26, 30, -0.5), Vector3.new(7, 5, 0.1), hex("#ECE6DA"), M.Fabric)
	local gui = Paint.surface(sheet, Enum.NormalId.Front, 20)
	Core.label(gui, "FINALS WEEK\nSEND COFFEE", 0.05, 0.05, 0.9, 0.9, hex("#2C5E8A"), {
		font = Enum.Font.PermanentMarker,
		align = Enum.TextXAlignment.Center,
		rotation = -3,
	})
end

---------------------------------------------------------------------------------------------------
-- The quad
---------------------------------------------------------------------------------------------------
local function fountain(m: Instance, rng: Deps.RngT)
	local F = Plan.fountain
	local f = Kit.model(m, "DeadFountain")
	local c = Plan.cf(F.x, WALK, F.z)
	local stone = hex("#8E897E")
	-- rim: 12 stained blocks around the basin
	Kit.ring(f, L(c, 0, 1.1, 0), F.r - 0.7, 12, function(i, rcf)
		local seg = Kit.block(f, rcf, Vector3.new(4.6, 2.2, 1.4), Geo.vary(stone, rng, 0.06), M.Concrete)
		seg.Name = "Rim"
		if i % 5 == 2 then
			-- a chipped segment
			seg.Size = Vector3.new(4.6, 1.6, 1.4)
			seg.CFrame = rcf * CFrame.new(0, -0.3, 0)
		end
	end)
	-- the basin floor, scummy water and leaves
	Kit.cylinder(f, L(c, 0, 0.3, 0), 0.6, (F.r - 1.2) * 2, hex("#5E5A50"), M.Concrete)
	Geo.water(f, L(c, 0.8, 0.62, -1.2), Vector3.new(6.5, 0.1, 4.8)).Name = "StagnantWater"
	for _ = 1, 6 do
		Kit.detail(
			f,
			L(c, rng:range(-5, 5), 0.66, rng:range(-5, 5)) * CFrame.Angles(0, rng:range(0, 6), 0),
			Vector3.new(rng:range(0.8, 1.6), 0.05, rng:range(0.6, 1.2)),
			Geo.vary(hex("#6B5A3A"), rng, 0.2),
			M.Grass
		).Name =
			"Leaves"
	end
	-- pedestal and the cracked urn, a rusty spout that hasn't run in years
	Kit.cylinder(f, L(c, 0, 2.3, 0), 3.6, 3.4, stone, M.Concrete)
	Kit.cylinder(f, L(c, 0, 4.4, 0), 0.6, 4.4, Kit.shade(stone, -0.1), M.Concrete)
	Kit.cylinder(f, L(c, 0, 5.9, 0), 2.4, 3.2, hex("#7D786E"), M.Concrete)
	Kit.detail(
		f,
		L(c, 0.8, 6.0, 0.6) * CFrame.Angles(0, 0, math.rad(25)),
		Vector3.new(0.12, 2.2, 0.08),
		hex("#2A2826"),
		M.SmoothPlastic
	).Name =
		"Crack"
	Geo.pipe(f, Plan.v(F.x, WALK + 7, F.z), Plan.v(F.x + 0.4, WALK + 8.4, F.z), 0.35, C.rust, M.CorrodedMetal, false)
	-- the "out of order" notice taped to the rim
	local notePos = Plan.v(F.x, WALK + 1.4, F.z + F.r + 0.04)
	local note = Kit.detail(
		f,
		CFrame.lookAt(notePos, notePos + Vector3.new(0, 0, 1)),
		Vector3.new(1.4, 1, 0.04),
		C.paper,
		M.SmoothPlastic
	)
	Kit.sign(note, "OUT OF ORDER\n— FACILITIES", { font = Enum.Font.SpecialElite, color = C.ink, pixelsPerStud = 60 })
	Kit.detail(f, L(c, 0, 4, 0), Vector3.new(0.1, 0.1, 0.1), stone, M.Concrete).Name = "Centre"
end

local function lawn(m: Instance, lw: { x0: number, x1: number, z0: number, z1: number }, rng: Deps.RngT, i: number)
	local g = Geo.lbox(m, lw.x0, WALK - 0.3, lw.z0, lw.x1, LAWN, lw.z1, Geo.vary(C.grass, rng, 0.06), M.Grass)
	g.Name = "Lawn" .. i
	-- concrete edging
	local edge = hex("#7C786F")
	Geo.lbox(m, lw.x0 - 0.4, WALK - 0.2, lw.z0 - 0.4, lw.x1 + 0.4, LAWN + 0.06, lw.z0, edge, M.Concrete, false)
	Geo.lbox(m, lw.x0 - 0.4, WALK - 0.2, lw.z1, lw.x1 + 0.4, LAWN + 0.06, lw.z1 + 0.4, edge, M.Concrete, false)
	-- bald, muddy patches and a worn shortcut diagonal
	for k = 1, rng:int(3, 5) do
		local x = rng:range(lw.x0 + 4, lw.x1 - 4)
		local z = rng:range(lw.z0 + 4, lw.z1 - 4)
		local p = Kit.detail(
			m,
			Plan.cf(x, LAWN + 0.01, z, rng:range(0, 180)),
			Vector3.new(rng:range(4, 11), 0.04, rng:range(3, 8)),
			Geo.vary(C.dirt, rng, 0.1),
			if rng:chance(0.5) then M.Ground else M.Mud
		)
		p.Name = "Patch" .. k
		p.CastShadow = false
	end
	local a = Vector3.new(lw.x0 + 2, 0, lw.z0 + 2)
	local b = Vector3.new(lw.x1 - 2, 0, lw.z1 - 2)
	if i % 2 == 0 then
		a = Vector3.new(lw.x1 - 2, 0, lw.z0 + 2)
		b = Vector3.new(lw.x0 + 2, 0, lw.z1 - 2)
	end
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local desire = Kit.detail(
		m,
		CFrame.lookAt(Plan.v(mid.X, LAWN + 0.015, mid.Z), Plan.v(b.X, LAWN + 0.015, b.Z)),
		Vector3.new(2.6, 0.04, len),
		Geo.vary(hex("#6A5840"), rng, 0.08),
		M.Ground
	)
	desire.Name = "DesireLine"
	desire.CastShadow = false
end

local function quad(m: Instance)
	local q = Kit.model(m, "Quad")
	local rng = Deps.Rng.new("quad")
	for i, lw in Plan.lawns do
		lawn(q, lw, rng, i)
	end
	fountain(q, rng)
	-- path surface: cracked concrete paving with the joints painted on one overlay per path
	local Q = Plan.quad
	local paths = {
		Geo.lbox(q, -92, WALK - 0.1, Q.z0, -78, WALK + 0.02, Q.z1, hex("#8E8A80"), M.Concrete, false),
		Geo.lbox(q, Q.x0, WALK - 0.1, -112, Q.x1, WALK + 0.02, -98, hex("#8E8A80"), M.Concrete, false),
	}
	for i, p in paths do
		p.Name = "QuadPath" .. i
		local gui, W, H = Paint.surface(p, Enum.NormalId.Top, 4)
		local along = if i == 1 then H else W
		for t = 24, along, 24 do
			if i == 1 then
				Core.px(gui, 0, t, W, 2, hex("#5E5B55"), 0.3)
			else
				Core.px(gui, t, 0, 2, H, hex("#5E5B55"), 0.3)
			end
		end
		Paint.cracks(gui, W, H, rng, 10, { color = hex("#4A4843"), thick = 1 })
	end
	-- bare trees, benches, lamps, bins
	local trees = {
		{ -146, -156 },
		{ -104, -150 },
		{ -66, -158 },
		{ -24, -150 },
		{ -140, -126 },
		{ -30, -120 },
		{ -148, -86 },
		{ -102, -56 },
		{ -64, -64 },
		{ -22, -84 },
		{ -128, -52 },
	}
	for _, t in trees do
		Geo.bareTree(q, Plan.v(t[1], LAWN, t[2]), rng, rng:range(0.9, 1.25))
	end
	local benches = {
		{ -96, -134, Plan.E },
		{ -74, -134, Plan.W },
		{ -96, -76, Plan.E },
		{ -74, -80, Plan.W },
		{ -128, -114, Plan.S },
		{ -42, -96, Plan.N },
	}
	for i, b in benches do
		Props.build("bench_worn", q, Plan.cf(b[1], WALK, b[2], b[3]), { seed = "quad-bench" .. i })
	end
	local lamps: { { x: number, z: number, yaw: number, lit: boolean } } = {
		{ x = -93, z = -150, yaw = Plan.E, lit = true },
		{ x = -77, z = -124, yaw = Plan.W, lit = false },
		{ x = -93, z = -64, yaw = Plan.E, lit = true },
		{ x = -77, z = -46, yaw = Plan.W, lit = true },
		{ x = -140, z = -113, yaw = Plan.S, lit = true },
		{ x = -36, z = -97, yaw = Plan.N, lit = true },
		{ x = -12, z = -113, yaw = Plan.S, lit = false },
	}
	for i, l in lamps do
		Dress.lamp(q, l.x, l.z, l.yaw, { lit = l.lit, light = i % 2 == 1, seed = "quad-lamp" .. i })
	end
	for i, t in { { -94, -96 }, { -76, -114 }, { -60, -40 } } do
		Props.build("trash_can", q, Plan.cf(t[1], WALK, t[2], rng:range(0, 360)), { seed = "quad-bin" .. i })
	end
	Props.build("newspaper_box", q, Plan.cf(-94, WALK, -40, Plan.S), { seed = "quad-news" })
	Dress.litter(q, Q.x0, Q.z0, Q.x1, Q.z1, 28, rng)
	-- a sandwich board for the Finance Club on the path
	local sb = Plan.cf(-81, WALK, -122, Plan.S)
	for _, s in { -1, 1 } do
		local leaf = Kit.block(
			q,
			sb * CFrame.new(0, 1.7, s * 0.45) * CFrame.Angles(math.rad(12 * s), 0, 0),
			Vector3.new(2.4, 3.4, 0.12),
			hex("#2A2A2A"),
			M.Wood
		)
		leaf.CanCollide = false
		if s < 0 then
			local gui = Paint.surface(leaf, Enum.NormalId.Front, 40)
			Core.bg(gui, hex("#2F3A32"))
			Core.label(gui, Text.flyers[1], 0.08, 0.08, 0.84, 0.84, hex("#ECE6DA"), {
				font = Enum.Font.PatrickHand,
				align = Enum.TextXAlignment.Center,
			})
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The fence and gates on the avenue
---------------------------------------------------------------------------------------------------
local function fence(m: Instance)
	local F = Plan.quadFence
	local rng = Deps.Rng.new("quad-fence")
	local gates = {}
	for _, g in F.gates do
		table.insert(gates, { x = g.x, w = g.w })
	end
	Dress.ironFence(m, F.x0, F.x1, F.z, 6, gates, rng)
	-- the main gate arch: EASTBRIDGE STATE UNIVERSITY in iron letters on a lit sign band
	local main = F.gates[1]
	local arch = Plan.cf(main.x, WALK, F.z, Plan.S)
	local iron = hex("#1F2122")
	Kit.detail(m, L(arch, 0, 12.2, 0), Vector3.new(main.w + 2.4, 0.5, 0.4), iron, M.Metal)
	Kit.detail(m, L(arch, 0, 9.8, 0), Vector3.new(main.w + 2.4, 0.4, 0.4), iron, M.Metal)
	for _, x in { -main.w / 2 - 0.4, main.w / 2 + 0.4 } do
		Kit.detail(m, L(arch, x, 10.3, 0), Vector3.new(0.4, 4.4, 0.4), iron, M.Metal)
	end
	local band = Kit.detail(m, L(arch, 0, 11, 0), Vector3.new(main.w, 1.8, 0.2), iron, M.Metal)
	band.Transparency = 0.3
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Paint.surface(band, face, 30)
		Core.label(gui, Text.university, 0.02, 0.1, 0.96, 0.8, hex("#D6CDB4"), {
			font = Enum.Font.Garamond,
			weight = Enum.FontWeight.Bold,
			align = Enum.TextXAlignment.Center,
		})
	end
	-- a crest plaque on each main gate pier (the logos module draws the school crest when it is available)
	for _, x in { -main.w / 2, main.w / 2 } do
		local plate = Kit.detail(m, L(arch, x, 4.2, -1.25), Vector3.new(1.8, 2.2, 0.1), hex("#C8BFA8"), M.Limestone)
		plate.Name = "CrestPlate"
		if not Deps.logo(plate, Enum.NormalId.Front, "eastbridge_state") then
			Kit.sign(
				plate,
				"ES\n" .. Text.founded,
				{ font = Enum.Font.Garamond, color = hex("#5C2A21"), pixelsPerStud = 60 }
			)
		end
	end
	-- the side gates are chained shut but the chain is long enough to squeeze past (decorative only)
	for i = 2, #F.gates do
		local g = F.gates[i]
		Kit.detail(m, Plan.cf(g.x, WALK + 3.2, F.z), Vector3.new(g.w - 2.4, 0.15, 0.15), hex("#6E6E6E"), M.Metal).Name =
			"Chain"
	end
end

---------------------------------------------------------------------------------------------------
-- Service yards behind the quad buildings
---------------------------------------------------------------------------------------------------
local function yards(m: Instance)
	local y = Kit.model(m, "ServiceYards")
	local rng = Deps.Rng.new("uni-yards")
	-- between Halvorsen and the Career Center
	Props.build("dumpster", y, Plan.cf(-160, WALK, -228, Plan.S), { seed = "yard-d1" })
	Props.build("dumpster", y, Plan.cf(-151, WALK, -229, Plan.S), { seed = "yard-d2" })
	Props.build("pallet_stack", y, Plan.cf(-164, WALK, -198, 20), { count = 4, seed = "yard-p1" })
	Props.build("ac_unit", y, Plan.cf(-146, WALK, -200, Plan.E), { seed = "yard-ac1" })
	Props.build("ac_unit", y, Plan.cf(-146, WALK, -192, Plan.E), { seed = "yard-ac2" })
	Props.build("chainlink_fence", y, Plan.cf(-162, WALK, -180, Plan.S), { length = 18, seed = "yard-f1" })
	-- between the Career Center and Marlow House: a maintenance shed and a generator
	local shed = Plan.cf(-14, WALK, -222, Plan.S)
	Kit.block(y, L(shed, 0, 5, 0), Vector3.new(16, 10, 12), Geo.vary(hex("#6E6A5F"), rng, 0.05), M.CorrodedMetal).Name =
		"Shed"
	Kit.detail(y, L(shed, 0, 10.3, 0), Vector3.new(17, 0.6, 13), C.rustDark, M.CorrodedMetal)
	local door = Kit.detail(y, L(shed, -3, 4.5, -6.05), Vector3.new(6, 9, 0.1), hex("#5A5F63"), M.DiamondPlate)
	Kit.sign(
		door,
		"FACILITIES\nAUTHORIZED ONLY",
		{ font = Enum.Font.SpecialElite, color = hex("#E9E2CF"), pixelsPerStud = 20 }
	)
	Kit.block(y, L(shed, 12, 2.5, -2), Vector3.new(6, 5, 4), hex("#4F6B4A"), M.Metal).Name = "Generator"
	Props.build("dumpster", y, Plan.cf(-20, WALK, -196, Plan.S), { seed = "yard-d3" })
	Props.build("trash_can", y, Plan.cf(-8, WALK, -190, 0), { seed = "yard-t1" })
	Props.build(
		"chainlink_fence",
		y,
		Plan.cf(-14, WALK, -176, Plan.S),
		{ length = 24, barbed = true, seed = "yard-f2" }
	)
	-- behind Marlow House on Mill Street's side: a cracked lot with a couple of beaters
	Props.build("sedan", y, Plan.cf(52, WALK, -210, 0), { color = hex("#5B4A3A"), seed = "beater-1" })
	Props.build("sedan", y, Plan.cf(36, WALK, -214, 4), { color = hex("#3E4A52"), seed = "beater-2" })
	Props.build("dumpster", y, Plan.cf(60, WALK, -184, Plan.W), { seed = "yard-d4" })
	Dress.litter(y, -30, -234, 66, -172, 18, rng)
end

---------------------------------------------------------------------------------------------------
function University.build(parent: Instance, mk: Instance): Model
	local m = Kit.model(parent, "University")
	halvorsen(m, mk)
	careerCenter(m, mk)
	marlow(m, mk)
	quad(m)
	fence(m)
	yards(m)
	return m
end

return University
