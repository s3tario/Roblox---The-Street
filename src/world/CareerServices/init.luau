--!strict
-- Career Services (venues feature; interior "career_services", v1 §6 recovery, v3 §9): the Street's quiet, dignified
-- place for second acts. A warm-grey hall with oak wainscot, a coffered ceiling, carpet and tall windows onto the
-- Street, laid out around three consultation booths.
--
--   south      the exit doors (door_career_services_exit) and the arrival point (career_services_entry) inside them;
--              the reception counter with npc_career_counselor behind it and the motto wall
--   north      three consultation booths behind frosted glass, each with a desk, two guest chairs and a lit
--              consultation screen (interact career_services, x3)
--   west       the waiting area: sofas, armchairs, a coffee table, a water cooler and the "Now serving" board
--   east       the resource library (bookcases, reading table, an open-roles board) and, in the south-east corner, a
--              discreet Street Store kiosk (interact store_kiosk)
--
-- build(parent?) -> Model "CareerServices" (attributes Interior, LightingPreset). Bake-safe (contracts §15).
-- The shared venue helpers (Deps, Shell, Paint, Markers, Furniture, Text) live in the Venue folder beside this module.

local Venue = script.Venue
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

local CareerServices = {}

CareerServices.ZONE = "career_services"

-- room extents (inner faces) and the ceiling height
local X0, X1, Z0, Z1, H = -44, 44, -32, 32, 15

local WALL = hex("#C9C5BC")
local WALL_DARK = hex("#B4AFA4")
local OAK = hex("#A07A52")
local OAK_DARK = hex("#7A5A3A")
local CARPET = hex("#4A5260")
local CARPET_EDGE = hex("#353B46")
local NAVY = hex("#1E2B3F")
local BRASS = hex("#B8933F")
local CEILING = hex("#EEEBE4")
local LEATHER = hex("#5A3E2E")
local FABRIC = hex("#6E7A86")
local GLASS = hex("#DCE6EA")

---------------------------------------------------------------------------------------------------
local function shell(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local s = Kit.model(m, "Shell")
	Shell.box(s, F, X0 - 1, -1, Z0 - 1, X1 + 1, 0, Z1 + 1, OAK, M.WoodPlanks).Name = "Floor"
	local carpet = Shell.box(s, F, X0 + 4, 0, Z0 + 4, X1 - 4, 0.06, Z1 - 4, CARPET, M.Carpet, false)
	carpet.Name = "Carpet"
	carpet.CastShadow = false
	local cg, CW, CH = Paint.surface(carpet, Enum.NormalId.Top, 2, { maxDistance = 0 })
	Paint.grid(cg, CW, CH, 16, CARPET_EDGE, 0.75)
	Shell.box(s, F, X0 + 3.4, 0, Z0 + 3.4, X1 - 3.4, 0.04, Z1 - 3.4, CARPET_EDGE, M.Carpet, false).Name = "CarpetBorder"
	local ceil = Shell.box(s, F, X0 - 1, H, Z0 - 1, X1 + 1, H + 1, Z1 + 1, CEILING, M.SmoothPlastic)
	ceil.Name = "Ceiling"
	Shell.wallX(s, F, Z0 - 0.5, X0 - 1, X1 + 1, 0, H, 1, WALL)
	Shell.wallX(s, F, Z1 + 0.5, X0 - 1, X1 + 1, 0, H, 1, WALL)
	Shell.wallZ(s, F, X0 - 0.5, Z0, Z1, 0, H, 1, WALL)
	Shell.wallZ(s, F, X1 + 0.5, Z0, Z1, 0, H, 1, WALL)
	-- oak wainscot, a brass chair rail and a crown moulding all round
	local trim = Kit.model(m, "Trim")
	Shell.box(trim, F, X0, 0, Z0, X1, 3.6, Z0 + 0.2, OAK, M.Wood, false)
	Shell.box(trim, F, X0, 0, Z1 - 0.2, X1, 3.6, Z1, OAK, M.Wood, false)
	Shell.box(trim, F, X0, 0, Z0, X0 + 0.2, 3.6, Z1, OAK, M.Wood, false)
	Shell.box(trim, F, X1 - 0.2, 0, Z0, X1, 3.6, Z1, OAK, M.Wood, false)
	Shell.box(trim, F, X0, 3.6, Z0, X1, 3.8, Z0 + 0.3, BRASS, M.Metal, false)
	Shell.box(trim, F, X0, 3.6, Z1 - 0.3, X1, 3.8, Z1, BRASS, M.Metal, false)
	Shell.box(trim, F, X0, 3.6, Z0, X0 + 0.3, 3.8, Z1, BRASS, M.Metal, false)
	Shell.box(trim, F, X1 - 0.3, 3.6, Z0, X1, 3.8, Z1, BRASS, M.Metal, false)
	Shell.box(trim, F, X0, H - 0.8, Z0, X1, H, Z0 + 0.5, WALL_DARK, M.SmoothPlastic, false)
	Shell.box(trim, F, X0, H - 0.8, Z1 - 0.5, X1, H, Z1, WALL_DARK, M.SmoothPlastic, false)
	Shell.box(trim, F, X0, H - 0.8, Z0, X0 + 0.5, H, Z1, WALL_DARK, M.SmoothPlastic, false)
	Shell.box(trim, F, X1 - 0.5, H - 0.8, Z0, X1, H, Z1, WALL_DARK, M.SmoothPlastic, false)
	-- the coffered ceiling: deep beams on a 26 x 19 grid, a glowing panel in the middle of each coffer
	local ceiling = Kit.model(m, "Coffers")
	for _, x in { -22, 0, 22 } do
		Shell.box(ceiling, F, x - 0.6, H - 1.2, Z0, x + 0.6, H, Z1, CEILING, M.SmoothPlastic, false).Name = "Beam"
	end
	for _, z in { -16, 0, 16 } do
		Shell.box(ceiling, F, X0, H - 1.2, z - 0.6, X1, H, z + 0.6, CEILING, M.SmoothPlastic, false).Name = "Beam"
	end
	local lit: { [string]: boolean } = { ["-33,-24"] = true, ["11,-24"] = true, ["-11,8"] = true, ["33,8"] = true }
	for _, x in { -33, -11, 11, 33 } do
		for _, z in { -24, -8, 8, 24 } do
			local key = x .. "," .. z
			Shell.glow(
				ceiling,
				F.cf(x, H - 0.08, z),
				Vector3.new(8, 0.1, 5.4),
				hex("#FFF6E6"),
				if lit[key] then { range = 34, brightness = 0.85, color = hex("#FFF0DA") } else nil
			).Transparency =
				0.25
		end
	end
	-- tall windows onto the Street (west and east walls)
	for i, z in { -18, 4 } do
		Shell.window(m, F.cf(X0, 7.6, z, Shell.E), 12, 8.4, rng, {
			view = "street",
			mood = "day",
			frame = OAK_DARK,
			frameMaterial = M.Wood,
			transom = true,
			glass = true,
		}).Name =
			"WindowView" .. i
		Shell.window(m, F.cf(X1, 7.6, z, Shell.W), 12, 8.4, rng, {
			view = "street",
			mood = "day",
			frame = OAK_DARK,
			frameMaterial = M.Wood,
			transom = true,
			glass = true,
		})
	end
end

---------------------------------------------------------------------------------------------------
-- The entrance, the reception counter and the motto wall
---------------------------------------------------------------------------------------------------
local function entrance(m: Instance, mk: Instance, F: Shell.Frame)
	local e = Kit.model(m, "Entrance")
	Shell.exit(e, mk, "door_career_services_exit", F.cf(0, 0, Z1, Shell.N), {
		label = Text.get("exit"),
		doorColor = OAK_DARK,
		frameColor = hex("#2E2A26"),
	})
	Markers.anchor(mk, "career_services_entry", F.cf(0, 3, Z1 - 10, Shell.N))
	-- entry mat and a pair of planters flanking the doors
	Shell.box(e, F, -5, 0.06, Z1 - 7, 5, 0.12, Z1 - 1.5, hex("#2A2E34"), M.Carpet, false).Name = "EntryMat"
	for _, sx in { -1, 1 } do
		Props.build("plant_floor", e, F.cf(sx * 8, 0, Z1 - 2.5, Shell.N), { seed = "cs-door-plant" .. sx })
	end
	-- the reception counter, the counselor behind it, a welcome sign on its front
	local r = Kit.model(m, "Reception")
	Props.build("reception_desk", r, F.cf(0, 0, 11, Shell.S), { text = Text.get("cs_reception"), seed = "cs-reception" })
	Markers.npc(mk, "npc_career_counselor", F.cf(0, 3, 7.6, Shell.S))
	-- the motto wall behind reception: oak slats with brass lettering, screening the booths
	local w = Kit.model(m, "MottoWall")
	local wall = Shell.box(w, F, -13, 0, 2, 13, 11, 3.2, OAK, M.Wood)
	wall.Name = "MottoWall"
	local wg, WW, WH = Paint.surface(wall, Enum.NormalId.Back, 12, { maxDistance = 200 })
	for x = 0, WW, 18 do
		Core.px(wg, x, 0, 3, WH, OAK_DARK, 0.35)
	end
	Core.label(wg, Text.get("cs_name"), 0.1, 0.18, 0.8, 0.2, BRASS, { font = Enum.Font.Bodoni, align = Enum.TextXAlignment.Center })
	Core.label(wg, Text.get("cs_motto"), 0.15, 0.42, 0.7, 0.1, hex("#F2E6C4"), {
		font = Enum.Font.Garamond,
		italic = true,
		align = Enum.TextXAlignment.Center,
	})
	Core.label(wg, Text.get("cs_sub"), 0.2, 0.56, 0.6, 0.07, hex("#E9DFC6"), {
		font = Enum.Font.GothamMedium,
		align = Enum.TextXAlignment.Center,
	})
	Shell.glow(w, F.cf(0, 11.2, 3.6), Vector3.new(25, 0.2, 0.4), hex("#FFE2B0"))
	-- the back of the wall (booth side) wears a plain oak face with a clock
	Props.build("wall_clock", w, F.cf(0, 7, 2, Shell.N), { hour = 10, minute = 10, seed = "cs-clock" })
	-- the welcome plate on a stand beside the counter
	Kit.detail(w, F.cf(9.5, 1.8, 14.5), Vector3.new(0.25, 3.6, 0.25), BRASS, M.Metal).Name = "SignStand"
	local plate = Shell.plate(w, F.cf(9.5, 4.4, 14.6, Shell.S), 3.6, 2.2, Text.get("cs_welcome"), {
		color = NAVY,
		ink = hex("#F2E6C4"),
		pps = 50,
	})
	plate.CanCollide = false
end

---------------------------------------------------------------------------------------------------
-- The three consultation booths (career_services x3)
---------------------------------------------------------------------------------------------------
local function consultScreen(part: BasePart, n: number)
	local gui = Core.surface(part, Enum.NormalId.Front, { pps = 60, glow = true, brightness = 1.1, maxDistance = 120 })
	local bg = Core.bg(gui, hex("#13243A"))
	Core.gradient(bg, hex("#1F3A5C"), hex("#0E1A28"), 90)
	Core.dot(gui, 0.5 * 2.6 * 60, 0.32 * 1.6 * 60, 0.34 * 1.6 * 60, hex("#8FB8DE"), 0.1)
	Core.label(gui, Text.get("cs_desk", { n = n }), 0.05, 0.56, 0.9, 0.16, hex("#F2E6C4"), {
		font = Enum.Font.GothamBold,
		align = Enum.TextXAlignment.Center,
	})
	Core.label(gui, Text.get("cs_desk_sub"), 0.08, 0.74, 0.84, 0.12, hex("#B9C8D8"), {
		font = Enum.Font.GothamMedium,
		align = Enum.TextXAlignment.Center,
	})
end

local function booths(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local root = Kit.model(m, "Consultation")
	-- frosted glass partitions between and around the booths
	for _, x in { -37, -12.5, 12.5, 37 } do
		local g = Shell.box(root, F, x - 0.15, 0, Z0, x + 0.15, 9, Z0 + 14, GLASS, M.Glass)
		g.Name = "Partition"
		g.Transparency = 0.35
		g.Reflectance = 0.1
		Shell.box(root, F, x - 0.25, 9, Z0, x + 0.25, 9.4, Z0 + 14, BRASS, M.Metal, false).Name = "PartitionCap"
		Shell.box(root, F, x - 0.3, 3.4, Z0, x + 0.3, 5, Z0 + 14, hex("#F4F6F6"), M.SmoothPlastic, false).Name =
			"FrostBand"
	end
	for i, cx in { -24.75, 0, 24.75 } do
		local b = Kit.model(root, "Booth" .. i)
		-- an oak back panel on the north wall with the booth's number
		Shell.box(b, F, cx - 11.5, 0, Z0, cx + 11.5, 11, Z0 + 0.3, OAK, M.Wood, false).Name = "BoothPanel"
		Shell.plate(b, F.cf(cx, 9.2, Z0 + 0.3, Shell.S), 9, 1.4, Text.get("cs_desk", { n = i }), {
			color = NAVY,
			ink = BRASS,
			font = Enum.Font.Bodoni,
			pps = 40,
		})
		Furniture.screen(b, F.cf(cx + 7, 5.5, Z0 + 0.3, Shell.S), 5, 3.4, "art", rng)
		-- the consultant's desk, its chair and the consultation screen facing the guests
		local deskCf = F.cf(cx, 0, Z0 + 8, Shell.S)
		Furniture.desk(b, deskCf, 9, 3.6, OAK_DARK, { legs = hex("#2E2A26") })
		Props.build("chair_exec", b, F.cf(cx, 0, Z0 + 4.2, Shell.S), { seed = "cs-exec" .. i })
		Props.build("desk_lamp", b, deskCf * CFrame.new(3.4, 3.1, 0.8), { lit = false, seed = "cs-lamp" .. i })
		Props.build("book_stack", b, deskCf * CFrame.new(-3.3, 3.1, 0.6), { seed = "cs-books" .. i })
		Kit.detail(b, deskCf * CFrame.new(0, 3.6, 0.6), Vector3.new(0.25, 1, 0.25), hex("#2B2B2D"), M.Metal).Name =
			"ScreenArm"
		local screen = Kit.block(b, deskCf * CFrame.new(0, 4.75, 0.6) * CFrame.Angles(math.rad(-8), 0, 0), Vector3.new(2.6, 1.6, 0.18), hex("#101215"), M.SmoothPlastic, {
			CanCollide = false,
		})
		screen.Name = "ConsultationScreen"
		consultScreen(screen, i)
		-- the screen faces the guests (south): its Front face points along the desk's LookVector
		Markers.interact(screen, "career_services", { DeskIndex = i })
		for _, sx in { -1, 1 } do
			Props.build("chair_visitor", b, F.cf(cx + sx * 2.4, 0, Z0 + 12.4, Shell.N), { seed = "cs-guest" .. i .. sx })
		end
		Furniture.plant(b, F.cf(cx - 9.5, 0, Z0 + 2.4), 0.9, rng)
	end
	-- a privacy note on the back of the motto wall, facing the booths
	Shell.plate(root, F.cf(0, 4.4, 2, Shell.N), 14, 0.9, Text.get("cs_privacy"), {
		color = NAVY,
		ink = hex("#E9DFC6"),
		pps = 40,
	}).Name =
		"PrivacyPlate"
end

---------------------------------------------------------------------------------------------------
-- The waiting area (west)
---------------------------------------------------------------------------------------------------
local function waiting(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local w = Kit.model(m, "Waiting")
	Props.build("rug_office", w, F.cf(-29, 0.07, 10), { width = 20, depth = 16, color = hex("#6B7480"), accent = NAVY })
	Props.build("sofa_office", w, F.cf(-29, 0.06, 16.5, Shell.N), { color = FABRIC, seed = "cs-sofa1" })
	Props.build("sofa_office", w, F.cf(-29, 0.06, 3.5, Shell.S), { color = FABRIC, seed = "cs-sofa2" })
	Props.build("armchair", w, F.cf(-37.5, 0.06, 10, Shell.E), { color = LEATHER, seed = "cs-arm1" })
	Props.build("armchair", w, F.cf(-20.5, 0.06, 10, Shell.W), { color = LEATHER, seed = "cs-arm2" })
	Props.build("coffee_table", w, F.cf(-29, 0.06, 10), { seed = "cs-coffee" })
	Props.build("water_cooler", w, F.cf(-42, 0, 28.5, Shell.E), { seed = "cs-water" })
	Props.build("plant_floor", w, F.cf(-41.5, 0, -28.5, Shell.E), { seed = "cs-plant-w" })
	Props.build("plant_floor", w, F.cf(-38, 0, 29.5, Shell.N), { seed = "cs-plant-sw" })
	-- the waiting-area sign and the "Now serving" board on the west wall
	Shell.plate(w, F.cf(X0 + 0.25, 12.4, 17, Shell.E), 10, 1.3, Text.get("cs_waiting"), {
		color = NAVY,
		ink = BRASS,
		font = Enum.Font.Bodoni,
		pps = 40,
	})
	local board = Kit.detail(w, F.cf(X0 + 0.3, 7.7, 22.5, Shell.E), Vector3.new(7, 3.4, 0.3), hex("#0E1116"), M.SmoothPlastic)
	board.Name = "NowServing"
	local bgui = Core.surface(board, Enum.NormalId.Front, { pps = 40, glow = true, brightness = 1.2, maxDistance = 160 })
	Core.bg(bgui, hex("#0E1116"))
	Core.label(bgui, Text.get("cs_now_serving"), 0.06, 0.08, 0.88, 0.3, hex("#B9C8D8"), {
		font = Enum.Font.GothamBold,
		align = Enum.TextXAlignment.Center,
	})
	Core.label(bgui, Text.get("cs_now_serving_no", { n = 17 }), 0.06, 0.4, 0.88, 0.52, hex("#FFB547"), {
		font = Enum.Font.RobotoMono,
		align = Enum.TextXAlignment.Center,
	})
	board:AddTag("InteriorLight")
	-- side tables with lamps and a magazine rack
	for _, z in { 16.5, 3.5 } do
		Furniture.table(w, F.cf(-38, 0, z), Vector3.new(2.2, 2.2, 2.2), OAK_DARK)
		local shade = Shell.glow(w, F.cf(-38, 3.1, z), Vector3.new(1.1, 1.3, 1.1), hex("#FFE7BF"))
		shade.Name = "LampShade"
	end
	local rack = Shell.box(w, F, X0 + 0.2, 0, 11, X0 + 1.4, 4.2, 15, OAK_DARK, M.Wood)
	rack.Name = "MagazineRack"
	local rg, RW, RH = Paint.surface(rack, Enum.NormalId.Right, 20, { maxDistance = 90 })
	for i = 0, 2 do
		Core.px(rg, RW * 0.08, RH * (0.1 + i * 0.3), RW * 0.84, RH * 0.22, ({ hex("#C8553D"), hex("#22577A"), hex("#D9A441") })[i + 1])
	end
	Props.build("wall_art", w, F.cf(X0, 5.5, -7, Shell.E), { variant = rng:int(1, 8), width = 7, height = 4.5, seed = "cs-art-w" })
end

---------------------------------------------------------------------------------------------------
-- The resource library (east) and the store kiosk (south-east corner)
---------------------------------------------------------------------------------------------------
local function library(m: Instance, F: Shell.Frame)
	local l = Kit.model(m, "Library")
	Shell.plate(l, F.cf(X1 - 0.25, 12.4, 18.4, Shell.W), 12, 1.3, Text.get("cs_resources"), {
		color = NAVY,
		ink = BRASS,
		font = Enum.Font.Bodoni,
		pps = 40,
	})
	for i, z in { 13, 18.4, 23.8 } do
		Props.build("bookshelf", l, F.cf(X1 - 1, 0, z, Shell.W), { tier = 2, seed = "cs-shelf" .. i })
	end
	-- the reading table with its chairs and the career guides on it
	local tableCf = F.cf(28, 0, 4)
	Furniture.table(l, tableCf, Vector3.new(12, 3, 4.4), OAK, OAK_DARK)
	for _, x in { -3.5, 3.5 } do
		Furniture.chair(l, tableCf * CFrame.new(x, 0, -3.4), NAVY, { back = NAVY })
		Furniture.chair(l, tableCf * CFrame.new(x, 0, 3.4) * CFrame.Angles(0, math.pi, 0), NAVY, { back = NAVY })
	end
	for i, key in { "cs_guide_1", "cs_guide_2", "cs_guide_3" } do
		local book = Kit.detail(l, tableCf * CFrame.new(-4 + i * 2.4, 3.1, 0) * CFrame.Angles(0, math.rad(i * 17), 0), Vector3.new(1.4, 0.2, 1.9), ({ NAVY, hex("#7A1F24"), hex("#1F4D3A") })[i], M.SmoothPlastic)
		book.Name = "Guide"
		Kit.sign(book, Text.get(key), { face = Enum.NormalId.Top, font = Enum.Font.Garamond, color = BRASS, pixelsPerStud = 60 })
	end
	Furniture.pendant(l, F.cf(28, H, 4), 4.5, hex("#FFE7BF"), { range = 20, brightness = 0.7 })
	-- the open-roles board on the east wall and two program posters on the south wall
	local board = Kit.detail(l, F.cf(X1 - 0.2, 7, -7, Shell.W), Vector3.new(9, 5.6, 0.25), hex("#B08A5A"), M.Wood)
	board.Name = "OpenRolesBoard"
	local bg = Core.surface(board, Enum.NormalId.Front, { pps = 40, maxDistance = 140 })
	Core.bg(bg, hex("#C9A77A"))
	Core.frame(bg, 0.05, 0.05, 0.9, 0.9, hex("#F4F1EA"))
	Core.label(bg, Text.get("cs_board_title"), 0.08, 0.08, 0.84, 0.14, NAVY, { font = Enum.Font.GothamBold, align = Enum.TextXAlignment.Center })
	Core.label(bg, Text.get("cs_board_lines"), 0.1, 0.25, 0.8, 0.64, hex("#2A2622"), { font = Enum.Font.Garamond, align = Enum.TextXAlignment.Left })
	for i, keys in { { "cs_poster_title", "cs_poster_body" }, { "cs_poster2_title", "cs_poster2_body" } } do
		local x = 18 + (i - 1) * 6.4
		local p = Kit.detail(l, F.cf(x, 7, Z1 - 0.2, Shell.N), Vector3.new(5, 6.4, 0.2), NAVY, M.SmoothPlastic)
		p.Name = "Poster"
		local pg = Core.surface(p, Enum.NormalId.Front, { pps = 40, maxDistance = 140 })
		local pb = Core.bg(pg, NAVY)
		Core.gradient(pb, hex("#24385A"), hex("#121C2C"), 90)
		Core.frame(pg, 0.08, 0.08, 0.84, 0.006, BRASS)
		Core.label(pg, Text.get(keys[1]), 0.08, 0.14, 0.84, 0.16, BRASS, { font = Enum.Font.Bodoni, align = Enum.TextXAlignment.Center })
		Core.label(pg, Text.get(keys[2]), 0.1, 0.4, 0.8, 0.4, hex("#E9DFC6"), { font = Enum.Font.GothamMedium, align = Enum.TextXAlignment.Center })
	end
	Props.build("plant_floor", l, F.cf(41.5, 0, -28.5, Shell.W), { seed = "cs-plant-ne" })

	-- the discreet Street Store kiosk in the south-east corner
	local k = Kit.model(m, "StoreKiosk")
	local kc = F.cf(39.5, 0, 27.5, 225)
	Kit.block(k, kc * CFrame.new(0, 0.2, 0), Vector3.new(3.2, 0.4, 2.4), hex("#1C1E22"), M.Metal).Name = "KioskBase"
	Kit.block(k, kc * CFrame.new(0, 3.2, 0.3), Vector3.new(2.6, 5.6, 1.2), hex("#24262A"), M.Metal).Name = "KioskBody"
	local screen = Kit.block(k, kc * CFrame.new(0, 4.1, -0.32), Vector3.new(2.2, 3, 0.1), hex("#0E1116"), M.SmoothPlastic, {
		CanCollide = false,
	})
	screen.Name = "KioskScreen"
	local sg = Core.surface(screen, Enum.NormalId.Front, { pps = 50, glow = true, brightness = 1.1, maxDistance = 100 })
	local sb = Core.bg(sg, hex("#0E1116"))
	Core.gradient(sb, hex("#1D2A3E"), hex("#0B0F16"), 90)
	Core.label(sg, Text.get("cs_kiosk"), 0.1, 0.36, 0.8, 0.22, BRASS, { font = Enum.Font.GothamBold, align = Enum.TextXAlignment.Center })
	Markers.interact(screen, "store_kiosk")
	Shell.glow(k, kc * CFrame.new(0, 6.1, -0.32), Vector3.new(2.2, 0.12, 0.1), BRASS)
end

---------------------------------------------------------------------------------------------------
local function origin(): Vector3
	return Deps.World.slotOrigin(Deps.World.interiors[CareerServices.ZONE].slot)
end

function CareerServices.build(parent: Instance?): Model
	local root = Kit.model(nil, "CareerServices")
	root:SetAttribute("Interior", CareerServices.ZONE)
	root:SetAttribute("LightingPreset", Deps.World.interiors[CareerServices.ZONE].lighting)
	local mk = Kit.folder(root, "Markers")
	local F = Shell.frame(origin())
	local rng = Deps.Rng.new("venue:career_services")
	shell(root, F, rng)
	entrance(root, mk, F)
	booths(root, F, rng)
	waiting(root, F, rng)
	library(root, F)
	Shell.settle(root)
	root.Parent = parent
	return root
end

return CareerServices
