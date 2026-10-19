--!strict
-- The Executive Club (venues feature; interior "exec_club", reached with the Executive Club pass): a members' lounge
-- in dark walnut and gold, double height under a coffered ceiling and three chandeliers, with a floor-to-ceiling
-- window wall onto the night skyline.
--
--   south      the doors (door_exec_club_exit), the arrival point (exec_club_entry) inside a velvet-rope lane and
--              the host's podium with npc_club_host behind it; the Members' Dressing Room in the south-west corner
--              (interact wardrobe on its cheval mirror) and the cigar nook in the south-east
--   centre     chesterfields and club chairs on a Persian rug under the main chandelier
--   west       the fireplace between two bookcases, with club chairs drawn up to it and the founders' portrait above
--   east       The Ledger Bar: a 24-stud walnut bar, a mirrored back bar with lit shelves, wine racks and stools
--   north      the window wall onto the skyline, the grand piano on its dais (north-west) and the billiards table
--              under its lamp (north-east)
--
-- build(parent?) -> Model "ExecClub" (attributes Interior, LightingPreset). Bake-safe (contracts §15).

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

local ExecClub = {}

ExecClub.ZONE = "exec_club"

local X0, X1, Z0, Z1, H = -48, 48, -34, 34, 22
local PANEL_TOP = 9

local WALNUT = hex("#4A2E1E")
local WALNUT_DARK = hex("#2F1C12")
local GOLD = hex("#C9A54C")
local GOLD_BRIGHT = hex("#E3C46F")
local GREEN = hex("#22352C")
local GREEN_DARK = hex("#172520")
local OXBLOOD = hex("#5E1F1A")
local FLOOR = hex("#3A2418")
local CEILING = hex("#2A1C14")
local CREAM = hex("#EFE6D2")

---------------------------------------------------------------------------------------------------
local function shell(m: Instance, F: Shell.Frame)
	local s = Kit.model(m, "Shell")
	-- the floor stops under the sill so it never overlaps the terrace slab seen through the glass
	local floor = Shell.box(s, F, X0 - 1, -1, Z0 - 0.4, X1 + 1, 0, Z1 + 1, FLOOR, M.WoodPlanks)
	floor.Name = "Floor"
	Shell.box(s, F, X0 - 1, H, Z0 - 12, X1 + 1, H + 1, Z1 + 1, CEILING, M.Wood).Name = "Ceiling"
	-- walls: walnut panelling below the picture rail, deep green silk above it
	Shell.wallX(s, F, Z1 + 0.5, X0 - 1, X1 + 1, 0, H, 1, WALNUT, M.Wood)
	Shell.wallZ(s, F, X0 - 0.5, Z0, Z1, 0, H, 1, WALNUT, M.Wood)
	Shell.wallZ(s, F, X1 + 0.5, Z0, Z1, 0, H, 1, WALNUT, M.Wood)
	local upper = Kit.model(m, "Silk")
	Shell.box(upper, F, X0, PANEL_TOP, Z1 - 0.1, X1, H, Z1, GREEN, M.Fabric, false)
	Shell.box(upper, F, X0, PANEL_TOP, Z0, X0 + 0.1, H, Z1, GREEN, M.Fabric, false)
	Shell.box(upper, F, X1 - 0.1, PANEL_TOP, Z0, X1, H, Z1, GREEN, M.Fabric, false)
	-- the gold picture rail, a skirting board and a crown, all round three walls
	local trim = Kit.model(m, "Trim")
	for _, y in { PANEL_TOP, H - 0.6 } do
		local t = if y == PANEL_TOP then 0.35 else 0.6
		Shell.box(trim, F, X0, y, Z1 - 0.3, X1, y + t, Z1, GOLD, M.Metal, false)
		Shell.box(trim, F, X0, y, Z0, X0 + 0.3, y + t, Z1, GOLD, M.Metal, false)
		Shell.box(trim, F, X1 - 0.3, y, Z0, X1, y + t, Z1, GOLD, M.Metal, false)
	end
	-- raised walnut panels below the rail (one long inset per wall run)
	Shell.box(trim, F, X0 + 1, 1.2, Z1 - 0.2, X1 - 1, PANEL_TOP - 1, Z1 - 0.1, WALNUT_DARK, M.Wood, false).Name =
		"Inset"
	Shell.box(trim, F, X0 + 0.1, 1.2, Z0 + 1, X0 + 0.2, PANEL_TOP - 1, Z1 - 1, WALNUT_DARK, M.Wood, false).Name =
		"Inset"
	Shell.box(trim, F, X1 - 0.2, 1.2, Z0 + 1, X1 - 0.1, PANEL_TOP - 1, Z1 - 1, WALNUT_DARK, M.Wood, false).Name =
		"Inset"
	-- the coffered ceiling: walnut beams with gold fillets
	local coffers = Kit.model(m, "Coffers")
	for _, x in { -32, -16, 0, 16, 32 } do
		Shell.box(coffers, F, x - 0.7, H - 1.4, Z0, x + 0.7, H, Z1, WALNUT, M.Wood, false).Name = "Beam"
	end
	for _, z in { -17, 0, 17 } do
		Shell.box(coffers, F, X0, H - 1.4, z - 0.7, X1, H, z + 0.7, WALNUT, M.Wood, false).Name = "Beam"
		Shell.box(coffers, F, X0, H - 1.45, z - 0.15, X1, H - 1.4, z + 0.15, GOLD, M.Metal, false).Name = "Fillet"
	end
	-- wall sconces along the east and west walls
	for _, spot in { { -1, -24 }, { -1, 10 }, { 1, -24 }, { 1, 24 } } do
		local side, z = spot[1], spot[2]
		do
			local x = if side < 0 then X0 + 0.5 else X1 - 0.5
			Kit.detail(coffers, F.cf(x, 11.5, z), Vector3.new(0.5, 1.4, 0.5), GOLD, M.Metal).Name = "Sconce"
			Shell.glow(
				coffers,
				F.cf(x + (if side < 0 then 0.5 else -0.5), 12.6, z),
				Vector3.new(0.7, 1, 0.7),
				hex("#FFD9A0")
			)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The window wall onto the skyline (north)
---------------------------------------------------------------------------------------------------
local function windowWall(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local w = Kit.model(m, "WindowWall")
	local glassH = H - 2
	Kit.windowGrid(w, {
		cf = F.cf(0, 1 + glassH / 2, Z0, Shell.S),
		width = X1 - X0,
		height = glassH,
		cols = 8,
		rows = 3,
		glassColor = hex("#3A4660"),
		frameColor = WALNUT_DARK,
		frameMaterial = M.Wood,
		frameThickness = 0.6,
		depth = 0.6,
		glassTransparency = 0.82,
		glassReflectance = 0.12,
	})
	-- the sill under the glass and the stone terrace beyond it (seen through the glass, never reached)
	Shell.box(w, F, X0, 0, Z0 - 0.4, X1, 1, Z0 + 0.6, WALNUT_DARK, M.Wood).Name = "Sill"
	Shell.box(w, F, X0 - 1, -1, Z0 - 12, X1 + 1, 0, Z0 - 0.4, hex("#4A4C50"), M.Slate).Name = "Terrace"
	local rail = Shell.box(w, F, X0, 0, Z0 - 7.2, X1, 3.4, Z0 - 6.8, hex("#2B2D30"), M.Metal, false)
	rail.Name = "TerraceRail"
	-- side closers so the gap between the glass and the backdrop reads as night air
	Shell.box(w, F, X0 - 1, -1, Z0 - 12, X0, H + 1, Z0, hex("#0C1020"), M.SmoothPlastic).Name = "Closer"
	Shell.box(w, F, X1, -1, Z0 - 12, X1 + 1, H + 1, Z0, hex("#0C1020"), M.SmoothPlastic).Name = "Closer"
	-- the painted skyline: lit towers, a dusky horizon, the city glowing far below
	local backdrop =
		Shell.box(w, F, X0 - 1, -1, Z0 - 13, X1 + 1, H + 1, Z0 - 12, hex("#0C1020"), M.SmoothPlastic, false)
	backdrop.Name = "Skyline"
	backdrop.CastShadow = false
	local gui, W, Hh = Paint.surface(backdrop, Enum.NormalId.Back, 5, { glow = true, brightness = 1, name = "Skyline" })
	Paint.skyline(gui, W, Hh, rng, { mood = "night", view = "high", horizon = 0.66, density = 1.3 })
	-- heavy drapes at the ends of the glass
	for _, sx in { -1, 1 } do
		Shell.box(
			w,
			F,
			sx * (X1 - 0.6) - 1.8,
			0,
			Z0 + 0.6,
			sx * (X1 - 0.6) + 1.8,
			H - 0.8,
			Z0 + 1.6,
			OXBLOOD,
			M.Fabric,
			false
		).Name =
			"Drape"
	end
end

---------------------------------------------------------------------------------------------------
-- Entrance, host podium, velvet ropes
---------------------------------------------------------------------------------------------------
local function entrance(m: Instance, mk: Instance, F: Shell.Frame)
	local e = Kit.model(m, "Entrance")
	Shell.exit(e, mk, "door_exec_club_exit", F.cf(0, 0, Z1, Shell.N), {
		label = Text.get("exit"),
		doorColor = WALNUT_DARK,
		frameColor = GOLD,
		signColor = hex("#14100C"),
		inkColor = GOLD_BRIGHT,
		font = Enum.Font.Garamond,
	})
	Markers.anchor(mk, "exec_club_entry", F.cf(0, 3, Z1 - 9, Shell.N))
	-- the club's name and crest over the doors on the inside
	local crest = Kit.detail(e, F.cf(0, 15.5, Z1 - 0.15), Vector3.new(4.2, 4.2, 0.2), WALNUT_DARK, M.Wood)
	crest.Name = "Crest"
	local crestId = "brand_executive_club"
	if
		not (
			Deps.hasLogo(crestId)
			and Deps.logo(crest, Enum.NormalId.Front, crestId, { theme = "dark", padding = 0.08 })
		)
	then
		Kit.sign(crest, "EC", { font = Enum.Font.Bodoni, color = GOLD_BRIGHT, pixelsPerStud = 40 })
	end
	local name = Shell.plate(e, F.cf(0, 13, Z1, Shell.N), 16, 1.4, Text.get("club_name"), {
		color = WALNUT_DARK,
		ink = GOLD_BRIGHT,
		font = Enum.Font.Bodoni,
		pps = 40,
	})
	name.Name = "ClubName"
	-- runner carpet and the velvet-rope lane
	Shell.box(e, F, -3.5, 0, 14, 3.5, 0.08, Z1 - 0.5, OXBLOOD, M.Carpet, false).Name = "Runner"
	for _, sx in { -1, 1 } do
		Props.build("velvet_rope", e, F.cf(sx * 5, 0, Z1 - 7, 90), { length = 8, seed = "club-rope" .. sx })
	end
	-- the host's podium (lamp, reservation book) with the host behind it, facing the doors
	local p = Kit.model(e, "HostPodium")
	local pc = F.cf(0, 0, 19, Shell.S)
	Kit.block(p, pc * CFrame.new(0, 1.9, 0), Vector3.new(3.4, 3.8, 1.8), WALNUT_DARK, M.Wood).Name = "Podium"
	Kit.detail(p, pc * CFrame.new(0, 3.86, -0.05), Vector3.new(3.6, 0.12, 2), GOLD, M.Metal).Name = "PodiumTop"
	Kit.detail(
		p,
		pc * CFrame.new(-0.6, 4.0, 0.1) * CFrame.Angles(math.rad(-12), 0, 0),
		Vector3.new(1.6, 0.12, 1.2),
		CREAM,
		M.SmoothPlastic
	).Name =
		"ReservationBook"
	Shell.glow(
		p,
		pc * CFrame.new(1, 4.5, 0.4),
		Vector3.new(0.7, 0.5, 0.7),
		hex("#FFD9A0"),
		{ range = 10, brightness = 0.6 }
	)
	Markers.npc(mk, "npc_club_host", F.cf(0, 3, 16.6, Shell.S))
	-- house rules plaque by the doors
	Shell.plate(e, F.cf(7.5, 5.5, Z1, Shell.N), 4.2, 2.2, Text.get("club_rules"), {
		color = WALNUT_DARK,
		ink = CREAM,
		font = Enum.Font.Garamond,
		pps = 50,
	})
end

---------------------------------------------------------------------------------------------------
-- Lounges: the centre group, the fireside group and the cigar nook
---------------------------------------------------------------------------------------------------
local function lounges(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local l = Kit.model(m, "Lounge")
	-- centre: two chesterfields facing across a Persian rug, club chairs at the ends
	Props.build("rug_persian", l, F.cf(0, 0.02, 0), { seed = "club-rug-c" })
	Props.build("leather_sofa", l, F.cf(0, 0, -5.2, Shell.S), { seed = "club-sofa1" })
	Props.build("leather_sofa", l, F.cf(0, 0, 5.2, Shell.N), { seed = "club-sofa2" })
	Furniture.armchair(l, F.cf(-7.5, 0, 0, Shell.E), OXBLOOD, { material = M.Leather, accent = WALNUT_DARK })
	Furniture.armchair(l, F.cf(7.5, 0, 0, Shell.W), OXBLOOD, { material = M.Leather, accent = WALNUT_DARK })
	Props.build("coffee_table", l, F.cf(0, 0, 0), { seed = "club-coffee" })
	Props.build("chandelier", l, F.cf(0, H - 7, 0), { arms = 8, drop = 7, seed = "club-chand-c" })

	-- west: the fireplace between bookcases, the founders' portrait above, two club chairs drawn up
	local f = Kit.model(m, "Fireside")
	local fz = -4
	Props.build("fireplace", f, F.cf(X0, 0, fz, Shell.E), { seed = "club-fire" })
	Props.build(
		"wall_art",
		f,
		F.cf(X0, 10.2, fz, Shell.E),
		{ variant = 3, width = 8, height = 6, lit = true, color = GOLD, seed = "club-portrait" }
	)
	Shell.plate(f, F.cf(X0 + 0.15, 9.75, fz, Shell.E), 3.6, 0.6, Text.get("club_portrait_1"), {
		color = GOLD,
		ink = WALNUT_DARK,
		font = Enum.Font.Garamond,
		pps = 60,
	})
	for _, dz in { -9.5, 9.5 } do
		Props.build("bookshelf", f, F.cf(X0 + 0.9, 0, fz + dz, Shell.E), { tier = 3, seed = "club-shelf" .. dz })
	end
	Props.build("rug_round", f, F.cf(-36, 0.02, fz), { seed = "club-rug-f" })
	for _, dz in { -4.2, 4.2 } do
		-- both chairs face west toward the hearth, angled in toward its centre line
		Props.build(
			"lounge_chair",
			f,
			F.cf(-35, 0, fz + dz) * CFrame.Angles(0, math.rad(90 + (if dz < 0 then 25 else -25)), 0),
			{
				color = OXBLOOD,
				seed = "club-lounge" .. dz,
			}
		)
	end
	Furniture.table(f, F.cf(-33, 0, fz), Vector3.new(2, 2.2, 2), WALNUT_DARK, GOLD)
	Props.build("chandelier", f, F.cf(-32, H - 6, -4), { arms = 6, drop = 6, seed = "club-chand-w" })

	-- two conversation corners either side of the entrance lane
	for _, sx in { -1, 1 } do
		local g = Kit.model(l, "Conversation")
		local cx, cz = sx * 18, 13
		Props.build("rug_round", g, F.cf(cx, 0.02, cz), { seed = "club-rug-s" .. sx })
		Furniture.armchair(g, F.cf(cx - 3, 0, cz - 2, 225), OXBLOOD, { material = M.Leather, accent = WALNUT_DARK })
		Furniture.armchair(g, F.cf(cx + 3, 0, cz + 2, 45), OXBLOOD, { material = M.Leather, accent = WALNUT_DARK })
		Furniture.roundTable(g, F.cf(cx, 0, cz), 2.4, 2.2, hex("#2F4A3C"), GOLD)
		Props.build("lamp_floor", g, F.cf(cx + sx * 5.5, 0, cz - 3.5), { lit = false, seed = "club-lamp-s" .. sx })
	end

	-- south-east: the cigar nook
	local c = Kit.model(m, "CigarNook")
	Props.build("cigar_humidor", c, F.cf(X1 - 1.2, 0, 22, Shell.W), { seed = "club-humidor" })
	Furniture.armchair(c, F.cf(38, 0, 26, 45), OXBLOOD, { material = M.Leather, accent = WALNUT_DARK })
	Furniture.armchair(c, F.cf(32, 0, 21, 225), OXBLOOD, { material = M.Leather, accent = WALNUT_DARK })
	Furniture.roundTable(c, F.cf(35, 0, 23.5), 2.4, 2.2, hex("#2F4A3C"), GOLD)
	Props.build(
		"wall_art",
		c,
		F.cf(X1, 5, 28, Shell.W),
		{ variant = rng:int(1, 8), width = 5, height = 3.5, color = GOLD, seed = "club-art-se" }
	)
	Props.build("plant_floor", c, F.cf(44.5, 0, 31, Shell.W), { seed = "club-plant-se" })
end

---------------------------------------------------------------------------------------------------
-- The Ledger Bar (east wall)
---------------------------------------------------------------------------------------------------
local function bar(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local b = Kit.model(m, "LedgerBar")
	local bz = -6
	Props.build(
		"bar_counter",
		b,
		F.cf(36, 0, bz, Shell.W),
		{ length = 24, color = WALNUT, accent = GOLD, seed = "club-bar" }
	)
	for i = 0, 4 do
		Furniture.stool(b, F.cf(32.6, 0, bz - 9.6 + i * 4.8), 3.4, OXBLOOD, GOLD)
	end
	-- the back bar: a walnut cabinet, a long mirror, three lit shelves of bottles and a cornice with the bar's name
	local bx = X1 - 1.2
	Shell.box(b, F, bx - 1.2, 0, bz - 12, X1, 3.6, bz + 12, WALNUT_DARK, M.Wood).Name = "BackBarCabinet"
	Shell.box(b, F, bx - 1.25, 3.6, bz - 12.1, X1, 3.8, bz + 12.1, hex("#2F4A3C"), M.Marble, false).Name = "BackBarTop"
	local mirror = Shell.box(b, F, X1 - 0.3, 3.8, bz - 11, X1 - 0.2, 12.6, bz + 11, hex("#9AA6AE"), M.Glass, false)
	mirror.Name = "BackBarMirror"
	mirror.Reflectance = 0.45
	for i, y in { 5.2, 7.6, 10 } do
		local shelf =
			Shell.box(b, F, X1 - 1.6, y - 0.12, bz - 10.5, X1 - 0.3, y, bz + 10.5, hex("#D9E4E8"), M.Glass, false)
		shelf.Name = "Shelf"
		shelf.Transparency = 0.4
		local bottles = Kit.detail(
			b,
			F.cf(X1 - 0.95, y + 0.85, bz, Shell.W),
			Vector3.new(20.6, 1.7, 0.1),
			WALNUT_DARK,
			M.SmoothPlastic
		)
		bottles.Name = "Bottles"
		bottles.Transparency = 1
		local gui, W, Hh =
			Core.surface(bottles, Enum.NormalId.Front, { pps = 16, glow = true, brightness = 1.1, maxDistance = 140 })
		local x = rng:range(2, 6)
		local palette =
			{ hex("#2F5A3A"), hex("#6E1A1F"), hex("#C9A54C"), hex("#D9E4E8"), hex("#8A5A2E"), hex("#3B2A5C") }
		while x < W - 6 do
			local bw = rng:range(W * 0.012, W * 0.02)
			local bh = rng:range(Hh * 0.55, Hh * 0.95)
			local col = palette[rng:int(1, #palette)]
			Core.px(gui, x, Hh - bh, bw, bh, col, 0.05)
			Core.px(gui, x + bw * 0.3, Hh - bh - Hh * 0.12, bw * 0.4, Hh * 0.13, col, 0.05)
			Core.px(gui, x + bw * 0.15, Hh - bh * 0.6, bw * 0.7, bh * 0.25, CREAM, 0.3)
			x += bw + rng:range(2, W * 0.01)
		end
		Shell.glow(
			b,
			F.cf(X1 - 0.95, y + 0.02, bz),
			Vector3.new(0.6, 0.04, 20.6),
			hex("#FFD9A0"),
			if i == 2 then { range = 16, brightness = 0.7, color = hex("#FFD9A0") } else nil
		)
	end
	Shell.box(b, F, X1 - 2, 12.6, bz - 12.2, X1, 13.6, bz + 12.2, WALNUT_DARK, M.Wood, false).Name = "Cornice"
	Shell.plate(b, F.cf(X1 - 2, 13.1, bz, Shell.W), 12, 0.9, Text.get("club_bar"), {
		color = WALNUT_DARK,
		ink = GOLD_BRIGHT,
		font = Enum.Font.Bodoni,
		pps = 40,
		depth = 0.05,
	})
	-- wine racks at the ends of the back bar and the menu board between the bar and the windows
	Props.build("wine_rack", b, F.cf(X1 - 1.1, 0, bz - 14.6, Shell.W), { seed = "club-wine1" })
	Props.build("wine_rack", b, F.cf(X1 - 1.1, 0, bz + 14.6, Shell.W), { seed = "club-wine2" })
	local menu = Kit.detail(b, F.cf(X1 - 0.2, 6, 14, Shell.W), Vector3.new(4, 5, 0.2), hex("#1A1410"), M.Wood)
	menu.Name = "Menu"
	local mg = Core.surface(menu, Enum.NormalId.Front, { pps = 40, maxDistance = 120 })
	Core.bg(mg, hex("#1A1410"))
	Core.frame(mg, 0.05, 0.04, 0.9, 0.004, GOLD)
	Core.label(mg, Text.get("club_menu_title"), 0.08, 0.06, 0.84, 0.12, GOLD_BRIGHT, {
		font = Enum.Font.Bodoni,
		align = Enum.TextXAlignment.Center,
	})
	for i, line in Text.list("club_menu") do
		Core.label(mg, line, 0.1, 0.22 + (i - 1) * 0.14, 0.8, 0.09, CREAM, { font = Enum.Font.Garamond })
	end
	Props.build("chandelier", b, F.cf(30, H - 6, bz), { arms = 6, drop = 6, seed = "club-chand-e" })
end

---------------------------------------------------------------------------------------------------
-- Piano (north-west) and billiards (north-east)
---------------------------------------------------------------------------------------------------
local function music(m: Instance, F: Shell.Frame)
	local p = Kit.model(m, "Piano")
	Kit.cylinder(p, F.cf(-32, 0.15, -24), 0.3, 15.2, GOLD, M.Metal).Name = "DaisRim"
	local dais = Kit.cylinder(p, F.cf(-32, 0.25, -24), 0.5, 14.4, WALNUT_DARK, M.Wood)
	dais.Name = "Dais"
	Props.build("piano_grand", p, F.cf(-32, 0.5, -24, 200), { seed = "club-piano" })
	Props.build("lamp_floor", p, F.cf(-41, 0, -29), { lit = false, seed = "club-lamp-piano" })

	local g = Kit.model(m, "Billiards")
	Props.build("pool_table", g, F.cf(30, 0, -22), { seed = "club-pool" })
	-- the billiards lamp: a long green shade on two rods
	for _, sx in { -1, 1 } do
		Kit.detail(g, F.cf(30 + sx * 2.5, H - 3.5, -22), Vector3.new(0.1, 7, 0.1), GOLD, M.Metal).Name = "LampRod"
	end
	Kit.detail(g, F.cf(30, H - 7.4, -22), Vector3.new(7, 0.8, 1.6), hex("#1F4D3A"), M.Glass).Name = "LampShade"
	Shell.glow(g, F.cf(30, H - 7.85, -22), Vector3.new(6.6, 0.1, 1.2), hex("#FFF1D0"), {
		kind = "spot",
		range = 14,
		brightness = 1.2,
		face = Enum.NormalId.Bottom,
	})
	-- cue rack on the east wall, with the room's name above it
	Kit.detail(g, F.cf(X1 - 0.3, 5, -29), Vector3.new(0.4, 6, 3.4), WALNUT_DARK, M.Wood).Name = "CueRack"
	Shell.plate(g, F.cf(X1 - 0.1, 8.3, -29, Shell.W), 3.4, 0.6, Text.get("club_billiards"), {
		color = WALNUT_DARK,
		ink = GOLD_BRIGHT,
		font = Enum.Font.Bodoni,
		pps = 60,
	})
	for i = 0, 4 do
		Kit.detail(g, F.cf(X1 - 0.65, 5, -30.4 + i * 0.7), Vector3.new(0.12, 5.6, 0.12), hex("#C8A27A"), M.Wood).Name =
			"Cue"
	end
end

---------------------------------------------------------------------------------------------------
-- The Members' Dressing Room (south-west corner): the cheval mirror is the wardrobe interact
---------------------------------------------------------------------------------------------------
local DX0, DX1, DZ0 = X0, -30, 16

local function dressingRoom(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local d = Kit.model(m, "DressingRoom")
	local roomH = 12
	-- partition walls (north and east) with a doorway on the east side, and a ceiling
	Shell.wallX(d, F, DZ0 - 0.5, DX0, DX1 + 1, 0, roomH, 1, WALNUT, M.Wood)
	Shell.wallZ(d, F, DX1 + 0.5, DZ0 - 1, Z1, 0, roomH, 1, WALNUT, M.Wood, { { c = 24, w = 7, h = 10 } })
	Shell.box(d, F, DX0, roomH, DZ0 - 1, DX1 + 1, roomH + 1, Z1, CEILING, M.Wood).Name = "DressingCeiling"
	-- the sign above the doorway (room side)
	Shell.plate(d, F.cf(DX1 + 1, 11, 24, Shell.E), 9, 1, Text.get("club_dressing"), {
		color = WALNUT_DARK,
		ink = GOLD_BRIGHT,
		font = Enum.Font.Bodoni,
		pps = 40,
	})
	-- inside: a carpet, the cheval mirror, member lockers, a bench and a valet stand
	Shell.box(d, F, DX0, 0, DZ0, DX1, 0.06, Z1, GREEN_DARK, M.Carpet, false).Name = "DressingCarpet"
	local mm = Props.build("mirror_full", d, F.cf(DX0 + 1.4, 0.06, 25, Shell.E), { seed = "club-mirror" })
	local mirror = mm:FindFirstChild("Mirror", true)
	if mirror and mirror:IsA("BasePart") then
		Markers.interact(mirror, "wardrobe")
	else
		local glass = Kit.block(d, F.cf(DX0 + 0.4, 4, 25, Shell.E), Vector3.new(2.4, 6, 0.2), hex("#DDE3E8"), M.Glass)
		glass.Name = "Mirror"
		glass.Reflectance = 0.6
		Markers.interact(glass, "wardrobe")
	end
	local lockers = Shell.box(d, F, DX0 + 1, 0, DZ0, DX1 - 2, 9, DZ0 + 2.2, WALNUT_DARK, M.Wood)
	lockers.Name = "Lockers"
	local lg, LW, LH = Core.surface(lockers, Enum.NormalId.Back, { pps = 12, maxDistance = 100 })
	local n = 6
	for i = 0, n - 1 do
		local f = Core.px(lg, LW * (i / n) + 3, 3, LW / n - 6, LH - 6, WALNUT, 0)
		Core.stroke(f, GOLD, 1.5, 0.3)
		Core.label(
			lg,
			Text.get("club_locker") .. " " .. (101 + i),
			i / n + 0.02,
			0.08,
			1 / n - 0.04,
			0.06,
			GOLD_BRIGHT,
			{
				font = Enum.Font.Garamond,
				align = Enum.TextXAlignment.Center,
			}
		)
		Core.dot(lg, LW * (i / n + 0.8 / n), LH * 0.5, 5, GOLD)
	end
	Furniture.bench(d, F.cf(-39, 0, 23.5), 7, OXBLOOD, { material = M.Leather, legs = GOLD, depth = 1.8 })
	-- the valet stand: a pole, a jacket shoulder bar and a tray
	Kit.detail(d, F.cf(-34, 2.6, 30.5), Vector3.new(0.2, 5.2, 0.2), WALNUT_DARK, M.Wood).Name = "ValetPole"
	Kit.detail(d, F.cf(-34, 5.1, 30.5), Vector3.new(2.6, 0.3, 0.4), WALNUT_DARK, M.Wood).Name = "ValetShoulders"
	Kit.detail(d, F.cf(-34, 4.1, 30.5), Vector3.new(2.2, 2, 0.6), hex("#1B2A44"), M.Fabric).Name = "ValetJacket"
	Shell.glow(d, F.cf(-39, roomH - 0.1, 25), Vector3.new(4, 0.1, 4), hex("#FFE7C4"), { range = 18, brightness = 0.8 })
	Props.build(
		"wall_art",
		d,
		F.cf(DX0, 5.5, 31, Shell.E),
		{ variant = rng:int(1, 8), width = 3.5, height = 3, color = GOLD, seed = "club-art-dress" }
	)
end

---------------------------------------------------------------------------------------------------
local function origin(): Vector3
	return Deps.World.slotOrigin(Deps.World.interiors[ExecClub.ZONE].slot)
end

function ExecClub.build(parent: Instance?): Model
	local root = Kit.model(nil, "ExecClub")
	root:SetAttribute("Interior", ExecClub.ZONE)
	root:SetAttribute("LightingPreset", Deps.World.interiors[ExecClub.ZONE].lighting)
	local mk = Kit.folder(root, "Markers")
	local F = Shell.frame(origin())
	local rng = Deps.Rng.new("venue:exec_club")
	shell(root, F)
	windowWall(root, F, rng)
	entrance(root, mk, F)
	lounges(root, F, rng)
	bar(root, F, rng)
	music(root, F)
	dressingRoom(root, F, rng)
	Shell.settle(root)
	root.Parent = parent
	return root
end

return ExecClub
