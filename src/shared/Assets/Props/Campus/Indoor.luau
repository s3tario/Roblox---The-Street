--!strict
-- Eastbridge interiors (gritty): cafeteria table, lecture-hall desk row, chalkboard, lockers, dorm bunk bed,
-- dorm desk, mini fridge, poster wall, pizza boxes, laundromat washer, diner booth and counter stool.

local Common = require(script.Parent.Parent.Common)
local Shapes = require(script.Parent.Parent.Shapes)
local Gui = require(script.Parent.Parent.Gui)
local Words = require(script.Parent.Parent.Words)
local Kit = require(script.Parent.Parent.Parent.Parent.Build.Kit)

type Ctx = Common.Ctx
type Def = Common.Def

local P, R = Common.P, Common.R
local V = Vector3.new
local M = Enum.Material
local col = Common.col
local C = Kit.Palette.campus
local shade = Kit.shade
local hex = Kit.hex

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

local VINYL_RED = hex("#A3242C")
local CREAM = hex("#EDE3CC")

---------------------------------------------------------------------------------------------------
-- cafeteria_table: laminate table with six attached swing-out stools and an abandoned lunch tray
---------------------------------------------------------------------------------------------------
add({
	id = "cafeteria_table",
	category = "campus",
	footprint = V(8, 2.8, 5.1),
	maxParts = 22,
	tags = { "table", "seat", "gritty" },
	surface = 2.76,
	build = function(c: Ctx)
		local top = c.color("color", hex("#D8CDB4"))
		local frame = c.color("accent", C.steel)
		c.part(P(0, 2.7, 0), V(8, 0.12, 3), top, M.SmoothPlastic)
		c.detail(P(0, 2.7, 0), V(8.04, 0.06, 3.04), shade(top, -0.3), M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 2.5, 1.35, 0), V(0.2, 2.6, 0.2), frame, M.Metal)
			c.detail(P(sx * 2.5, 0.06, 0), V(0.25, 0.12, 4.2), frame, M.Metal)
		end
		local stool = c.color("fabric", c.rng:pick({ hex("#2C5E8A"), hex("#C9A13B"), hex("#8A2C2C") }))
		for _, sz in { -1, 1 } do
			for _, x in { -2.6, 0, 2.6 } do
				c.dcyl(P(x, 0.85, sz * 2.0), 1.7, 0.15, frame, M.Metal)
				c.cyl(P(x, 1.72, sz * 2.0), 0.15, 1.1, stool, M.SmoothPlastic)
			end
		end
		if c.rng:chance(0.6) then
			local tx = c.rng:range(-2.5, 2.5)
			c.detail(P(tx, 2.79, -0.6), V(1.6, 0.06, 1.1), hex("#8C6A3E"), M.SmoothPlastic)
			c.detail(P(tx - 0.4, 2.97, -0.6), V(0.3, 0.32, 0.3), hex("#F4F1EA"), M.SmoothPlastic)
			c.dball(P(tx + 0.35, 2.94, -0.5), 0.26, hex("#B5202B"), M.SmoothPlastic)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- lecture_desk_row: auditorium row with a continuous writing desk and fold-down seats facing -Z (the
-- lectern). opts.seats (1-12, default 5); some seats are folded up.
---------------------------------------------------------------------------------------------------
add({
	id = "lecture_desk_row",
	category = "campus",
	footprint = V(13.75, 3.3, 3.1),
	maxParts = 46,
	tags = { "seat", "desk", "classroom" },
	scales = { seats = 12 },
	build = function(c: Ctx)
		local n = c.int("seats", 5, 1, 12)
		local pitch = 2.6
		local L = n * pitch + 0.6
		local wood = c.color("color", hex("#A07A52"))
		local seatC = c.color("fabric", hex("#3C4A5E"))
		local metal = C.steel
		c.part(P(0, 3.0, -1.0) * R(8, 0, 0), V(L, 0.12, 1.2), wood, M.Wood)
		c.part(P(0, 1.5, -1.6), V(L, 3.0, 0.12), shade(wood, -0.15), M.Wood)
		for _, sx in { -1, 1 } do
			c.part(P(sx * (L / 2 + 0.07), 1.6, -0.3), V(0.15, 3.2, 2.7), shade(wood, -0.2), M.Wood)
		end
		for i = 0, n do
			c.detail(P(-L / 2 + 0.3 + i * pitch, 1.0, 0.75), V(0.15, 2.0, 0.3), metal, M.Metal)
		end
		for i = 1, n do
			local x = -L / 2 + 0.3 + (i - 0.5) * pitch
			if c.rng:chance(0.25) then
				c.detail(P(x, 1.95, 0.85) * R(75, 0, 0), V(2.2, 0.16, 1.3), seatC, M.Fabric)
			else
				c.seat(P(x, 1.7, 0.4), V(2.2, 0.16, 1.4), seatC, M.Fabric)
			end
			c.detail(P(x, 2.6, 1.15) * R(10, 0, 0), V(2.2, 1.5, 0.12), shade(seatC, -0.1), M.Fabric)
		end
		if c.rng:chance(0.5) then
			c.detail(
				P(c.rng:range(-L / 2 + 1, L / 2 - 1), 3.1, -1.0) * R(8, c.rng:range(-30, 30), 0),
				V(0.7, 0.01, 0.9),
				col.paper,
				M.SmoothPlastic
			)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- chalkboard: wall-mounted slate in a worn wood frame, covered in formulas, with chalk and an eraser
---------------------------------------------------------------------------------------------------
add({
	id = "chalkboard",
	category = "campus",
	footprint = V(12.4, 5.4, 0.45),
	maxParts = 11,
	tags = { "board", "classroom", "wall" },
	mount = "wall",
	build = function(c: Ctx)
		local W, Hb, fw = 12, 5, 0.2
		local cy = Hb / 2 + fw
		local slate = c.detail(P(0, cy, -0.1), V(W, Hb, 0.1), c.color("color", hex("#2F4A3A")), M.Slate)
		slate.Name = "Board"
		local gui, gw, gh = Gui.Core.surface(slate, Enum.NormalId.Front, { pps = 30, maxDistance = 100 })
		Gui.Art.chalkboard(gui, gw, gh, c.rng)
		local wood = c.color("accent", C.woodWorn)
		Shapes.frameRect(c, P(0, cy, -0.1), W, Hb, fw, 0.2, wood, M.Wood)
		c.detail(P(0, fw + 0.03, -0.32), V(W * 0.8, 0.06, 0.26), wood, M.Wood)
		for i, cc in { hex("#F4F4EF"), hex("#F1E28A"), hex("#F2A6C0") } do
			c.dcylX(P(-2 + i * 0.5, fw + 0.1, -0.33), 0.35, 0.08, cc, M.SmoothPlastic)
		end
		c.detail(P(2.5, fw + 0.13, -0.33), V(0.6, 0.14, 0.22), hex("#3A3A3A"), M.Fabric)
	end,
})

---------------------------------------------------------------------------------------------------
-- lockers: a run of opts.count (1-12, default 4) steel lockers; dents, padlocks, repainted doors and
-- the occasional door left ajar
---------------------------------------------------------------------------------------------------
add({
	id = "lockers",
	category = "campus",
	footprint = V(6.15, 6.6, 1.9),
	maxParts = 56,
	tags = { "storage", "gritty", "school" },
	scales = { count = 12 },
	build = function(c: Ctx)
		local n = c.int("count", 4, 1, 12)
		local pitch, Hh, D = 1.5, 6.5, 1.6
		local W = n * pitch
		local body = c.color("color", hex("#4F6B7A"))
		c.part(P(0, 0.3 + (Hh - 0.3) / 2, 0), V(W + 0.1, Hh - 0.3, D), shade(body, -0.15), M.Metal)
		c.detail(P(0, 0.15, 0.05), V(W, 0.3, D - 0.1), col.frameDark, M.SmoothPlastic)
		c.detail(P(0, Hh + 0.05, -0.02), V(W + 0.14, 0.1, D + 0.06), shade(body, -0.3), M.Metal)
		local ajar = if c.rng:chance(0.35) then c.rng:int(1, n) else 0
		for i = 1, n do
			local x = -W / 2 + (i - 0.5) * pitch
			local tone = if c.rng:chance(0.15)
				then c.rng:pick({ hex("#7A3B2E"), hex("#C9A13B") })
				else shade(body, c.rng:range(-0.08, 0.08))
			local hinge = P(x - 0.7, 3.4, -D / 2 - 0.01)
			local door = hinge * R(0, if i == ajar then 16 else c.rng:range(-0.6, 0.6), 0) * P(0.7, 0, -0.01)
			c.detail(door, V(1.4, 6.0, 0.04), tone, M.Metal)
			c.detail(door * P(0, 2.2, -0.025), V(0.9, 0.5, 0.01), shade(tone, -0.45), M.DiamondPlate)
			c.detail(door * P(0.5, -0.1, -0.05), V(0.08, 0.5, 0.06), col.chrome, M.Metal)
			if c.rng:chance(0.45) then
				c.detail(
					door * P(0.5, -0.45, -0.08),
					V(0.18, 0.22, 0.08),
					c.rng:pick({ hex("#B8933F"), col.plasticBlack }),
					M.Metal
				)
			end
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- bunk_bed: steel dorm bunk with mattresses, rumpled blankets, pillows, ladder and a guard rail
---------------------------------------------------------------------------------------------------
add({
	id = "bunk_bed",
	category = "campus",
	footprint = V(7.05, 6.5, 3.6),
	maxParts = 26,
	tags = { "bed", "dorm", "furniture" },
	build = function(c: Ctx)
		local metal = c.color("accent", hex("#3E4A52"))
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				c.part(P(sx * 3.4, 3.25, sz * 1.6), V(0.25, 6.5, 0.25), metal, M.Metal)
			end
		end
		for _, y in { 1.2, 4.4 } do
			for _, sz in { -1, 1 } do
				c.detail(P(0, y, sz * 1.6), V(6.8, 0.25, 0.15), metal, M.Metal)
			end
			c.part(P(0, y + 0.37, 0), V(6.6, 0.5, 3.0), hex("#E8E4DA"), M.Fabric)
			c.detail(
				P(c.rng:range(0.4, 0.9), y + 0.67, c.rng:range(-0.1, 0.1)) * R(0, c.rng:range(-4, 4), 0),
				V(5.0, 0.12, 3.05),
				c.color("color", c.rng:pick({ hex("#2C5E8A"), hex("#7A3B2E"), hex("#56613A"), hex("#5C6168") })),
				M.Fabric
			)
			c.detail(P(-2.75, y + 0.76, c.rng:range(-0.3, 0.3)), V(1.0, 0.25, 2.0), hex("#F2EFE8"), M.Fabric)
		end
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 3.4, 5.6, 0), V(0.15, 0.25, 3.0), metal, M.Metal)
			c.detail(P(sx * 3.4, 2.0, 0), V(0.1, 1.2, 3.0), shade(metal, 0.1), M.Metal)
		end
		c.detail(P(-0.4, 5.6, -1.6), V(5.6, 0.15, 0.12), metal, M.Metal)
		for _, x in { 2.2, 3.0 } do
			c.detail(P(x, 2.7, -1.75), V(0.12, 5.4, 0.12), metal, M.Metal)
		end
		for _, y in { 1.4, 2.4, 3.4, 4.4 } do
			c.detail(P(2.6, y, -1.75), V(0.8, 0.1, 0.1), metal, M.Metal)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- dorm_desk: cheap laminate desk with a hutch, books, a glowing laptop, energy drinks and sticky notes
---------------------------------------------------------------------------------------------------
add({
	id = "dorm_desk",
	category = "campus",
	footprint = V(5.15, 5.05, 2.4),
	maxParts = 24,
	tags = { "desk", "dorm", "furniture" },
	surface = 2.76,
	build = function(c: Ctx)
		local lam = c.color("color", hex("#B8956A"))
		c.part(P(0, 2.7, 0), V(5, 0.12, 2.4), lam, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			c.part(P(sx * 2.43, 1.32, 0), V(0.15, 2.64, 2.3), shade(lam, -0.08), M.SmoothPlastic)
		end
		Shapes.drawers(
			c,
			P(1.6, 2.32, -0.05),
			V(1.4, 0.6, 2.2),
			1,
			shade(lam, -0.08),
			M.SmoothPlastic,
			lam,
			M.SmoothPlastic,
			col.plasticGrey,
			true
		)
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 2.43, 3.91, 0.85), V(0.15, 2.3, 0.7), shade(lam, -0.08), M.SmoothPlastic)
		end
		c.detail(P(0, 4.0, 0.85), V(4.8, 0.1, 0.7), lam, M.SmoothPlastic)
		c.detail(P(0, 5.0, 0.85), V(5.0, 0.1, 0.7), lam, M.SmoothPlastic)
		c.detail(P(0, 3.91, 1.18), V(4.8, 2.3, 0.04), shade(lam, -0.2), M.SmoothPlastic)
		Shapes.books(c, P(-0.6, 4.05, 0.85), 3.0, 0.85, 0.5, 4)
		c.detail(P(-0.6, 2.79, -0.3), V(1.3, 0.06, 0.9), col.plasticGrey, M.SmoothPlastic)
		local screen =
			c.detail(P(-0.6, 3.21, 0.14) * R(12, 0, 0), V(1.3, 0.85, 0.04), col.plasticBlack, M.SmoothPlastic)
		if c.bool("lit", true) then
			local face = c.detail(
				P(-0.6, 3.21, 0.14) * R(12, 0, 0) * P(0, 0, -0.025),
				V(1.2, 0.75, 0.01),
				hex("#0E1622"),
				M.SmoothPlastic
			)
			face.Name = "Screen"
			Gui.Screens.screen(face, c.rng:pick({ "sheet", "email", "chart" }), c.rng)
		end
		screen.Name = "Laptop"
		for i = 1, 2 do
			c.dcyl(
				P(1.1 + i * 0.35, 2.76 + 0.2, -0.5 + i * 0.1),
				0.4,
				0.2,
				c.rng:pick({ hex("#2BD67B"), hex("#C0392B"), hex("#1F4E8C") }),
				M.Metal
			)
		end
		for _ = 1, 2 do
			c.detail(
				P(c.rng:range(-2, 2), c.rng:range(3.2, 3.8), 1.155) * R(0, 0, c.rng:range(-10, 10)),
				V(0.3, 0.3, 0.01),
				hex("#F4E04D"),
				M.SmoothPlastic
			)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- mini_fridge: dorm fridge with magnets, a can and a cereal box on top
---------------------------------------------------------------------------------------------------
add({
	id = "mini_fridge",
	category = "campus",
	footprint = V(1.8, 3.7, 1.9),
	maxParts = 10,
	tags = { "appliance", "dorm" },
	build = function(c: Ctx)
		local body = c.color("color", c.rng:pick({ hex("#E9E7E2"), hex("#2B2B2B") }))
		c.part(P(0, 1.4, 0), V(1.8, 2.8, 1.8), body, M.SmoothPlastic)
		c.detail(P(0, 1.38, -0.915), V(1.74, 2.64, 0.03), shade(body, -0.05), M.SmoothPlastic)
		c.detail(P(0, 2.2, -0.935), V(1.7, 0.03, 0.02), shade(body, -0.35), M.SmoothPlastic)
		c.detail(P(0.72, 1.6, -0.96), V(0.08, 0.9, 0.06), col.plasticGrey, M.SmoothPlastic)
		for _ = 1, 3 do
			c.detail(
				P(c.rng:range(-0.6, 0.4), c.rng:range(0.6, 2.0), -0.94) * R(0, 0, c.rng:range(-15, 15)),
				V(0.22, 0.22, 0.03),
				c.rng:pick({ hex("#C0392B"), hex("#2E86C1"), hex("#F1C40F"), hex("#27AE60") }),
				M.SmoothPlastic
			)
		end
		c.dcyl(P(-0.45, 3.0, -0.2), 0.4, 0.22, hex("#C0392B"), M.Metal)
		c.detail(P(0.3, 3.25, 0.1) * R(0, c.rng:range(-15, 15), 0), V(0.75, 0.9, 0.3), hex("#E8B23A"), M.SmoothPlastic)
	end,
})

---------------------------------------------------------------------------------------------------
-- poster_wall: corkboard of taped campus flyers (wall mount). opts.board = false for flyers only.
---------------------------------------------------------------------------------------------------
add({
	id = "poster_wall",
	category = "campus",
	footprint = V(8.4, 5.4, 0.16),
	maxParts = 20,
	tags = { "wall", "wall_art", "gritty", "poster" },
	mount = "wall",
	build = function(c: Ctx)
		local W, Hh, fw = 8, 5, 0.2
		if c.bool("board", true) then
			c.detail(P(0, Hh / 2 + fw, -0.06), V(W, Hh, 0.12), hex("#B08A5A"), M.Fabric)
			Shapes.frameRect(c, P(0, Hh / 2 + fw, -0.07), W, Hh, fw, 0.14, C.woodWorn, M.Wood)
		end
		local flyers = c.rng:shuffle(Words.flyers)
		local palettes = {
			{ C.paper, C.graffitiMagenta, C.ink },
			{ hex("#F4E04D"), C.ink, C.ink },
			{ hex("#9ED2E6"), C.ink, C.ink },
			{ C.paper, hex("#2F5A3A"), C.ink },
			{ hex("#F2A6C0"), C.ink, C.ink },
		}
		local k = 0
		for row = 0, 1 do
			for colI = 0, 3 do
				if not (row == 1 and colI == 3) then
					k += 1
					local fwid = c.rng:range(1.4, 1.75)
					local fh = c.rng:range(1.7, 2.1)
					local x = -W / 2 + 1.05 + colI * 1.95 + c.rng:range(-0.12, 0.12)
					local y = fw + 0.25 + (1 - row) * 2.45 + fh / 2 + c.rng:range(-0.08, 0.04)
					local rot = R(0, 0, c.rng:range(-7, 7))
					local flyer = c.detail(P(x, y, -0.135) * rot, V(fwid, fh, 0.01), C.paper, M.SmoothPlastic)
					flyer.Name = "Flyer"
					local f = flyers[(k - 1) % #flyers + 1]
					local gui = Gui.Core.surface(flyer, Enum.NormalId.Front, { pps = 50, maxDistance = 60 })
					Gui.Art.poster(gui, f[1], f[2], c.rng:pick(palettes), c.rng, Enum.Font.SpecialElite)
					c.detail(
						P(x, y, -0.142) * rot * P(0, fh / 2 - 0.04, 0),
						V(0.5, 0.16, 0.005),
						hex("#EDE7D0"),
						M.SmoothPlastic
					)
				end
			end
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- pizza_box: a stack of opts.count (1-4, default 2) delivery boxes, the top one open on a half-eaten pie
---------------------------------------------------------------------------------------------------
add({
	id = "pizza_box",
	category = "campus",
	footprint = V(2.1, 2.6, 2.45),
	maxParts = 14,
	tags = { "clutter", "food", "desk_item" },
	scales = { count = 4 },
	build = function(c: Ctx)
		local n = c.int("count", 2, 1, 4)
		local card = c.color("color", hex("#D9C3A0"))
		local bh = 0.3
		for i = 1, n - 1 do
			local box = c.detail(
				P(c.rng:range(-0.05, 0.05), (i - 0.5) * bh, c.rng:range(-0.05, 0.05)) * R(0, c.rng:range(-6, 6), 0),
				V(2, bh - 0.01, 2),
				shade(card, c.rng:range(-0.08, 0.02)),
				M.Cardboard
			)
			c.sign(box, Words.pizza, {
				face = Enum.NormalId.Top,
				font = Enum.Font.LuckiestGuy,
				color = hex("#B5202B"),
				pixelsPerStud = 30,
				padding = 0.18,
			})
		end
		local y0 = (n - 1) * bh
		c.detail(P(0, y0 + 0.06, 0), V(2, 0.12, 2), card, M.Cardboard)
		local lid = c.detail(P(0, y0 + 0.12, 1.0) * R(100, 0, 0) * P(0, 0.02, -1.0), V(2, 0.04, 2), card, M.Cardboard)
		c.sign(lid, Words.pizza, {
			face = Enum.NormalId.Top,
			font = Enum.Font.LuckiestGuy,
			color = hex("#B5202B"),
			pixelsPerStud = 30,
			padding = 0.18,
		})
		c.dcyl(P(0, y0 + 0.14, 0), 0.04, 1.8, hex("#E3A857"), M.SmoothPlastic)
		c.dcyl(P(0, y0 + 0.165, 0), 0.02, 1.6, hex("#D9572B"), M.SmoothPlastic)
		for _ = 1, 4 do
			local a = c.rng:range(0, math.pi * 2)
			local r = c.rng:range(0.2, 0.6)
			c.dcyl(P(math.cos(a) * r, y0 + 0.185, math.sin(a) * r), 0.02, 0.22, hex("#9E2A22"), M.SmoothPlastic)
		end
		c.detail(P(0.5, y0 + 0.124, -0.4), V(0.6, 0.004, 0.5), shade(card, -0.25), M.Cardboard)
	end,
})

---------------------------------------------------------------------------------------------------
-- laundry_machine: front-load laundromat washer with coin box, porthole door and maybe an OUT OF ORDER sign
---------------------------------------------------------------------------------------------------
add({
	id = "laundry_machine",
	category = "campus",
	footprint = V(2.6, 3.8, 2.75),
	maxParts = 12,
	tags = { "appliance", "laundromat" },
	build = function(c: Ctx)
		local body = c.color("color", hex("#E6E1D3"))
		c.part(P(0, 1.9, 0), V(2.6, 3.8, 2.6), body, M.SmoothPlastic)
		c.detail(P(0, 3.55, -1.31), V(2.5, 0.5, 0.04), C.steel, M.Metal)
		c.glow(P(0.3, 3.55, -1.335), V(0.5, 0.2, 0.02), hex("#FF5A3C"), 0.2)
		c.dcylZ(P(-0.5, 3.55, -1.36), 0.08, 0.3, col.plasticGrey, M.SmoothPlastic)
		c.dcylZ(P(0, 1.8, -1.34), 0.12, 1.6, col.chrome, M.Metal)
		local glass = c.dcylZ(P(0, 1.8, -1.38), 0.06, 1.25, hex("#2E4A66"), M.Glass)
		glass.Transparency = 0.35
		c.dball(P(0, 1.6, -0.75), 1.0, c.rng:pick({ hex("#2C5E8A"), hex("#C0392B"), hex("#E8E4DA") }), M.Fabric)
		c.detail(P(0.85, 3.0, -1.33), V(0.4, 0.5, 0.06), C.steel, M.Metal)
		c.detail(P(-0.8, 3.55, -1.345), V(0.6, 0.3, 0.04), shade(body, -0.1), M.SmoothPlastic)
		c.detail(P(0, 0.12, -1.31), V(2.5, 0.24, 0.04), shade(body, -0.2), M.SmoothPlastic)
		if c.rng:chance(0.2) then
			local sign =
				c.detail(P(0, 2.95, -1.335) * R(0, 0, c.rng:range(-5, 5)), V(1.2, 0.5, 0.01), C.paper, M.SmoothPlastic)
			c.sign(
				sign,
				Words.laundry[1],
				{ font = Enum.Font.PermanentMarker, color = hex("#B22222"), pixelsPerStud = 50 }
			)
		end
		c.use(V(0, 2, -1.8))
	end,
})

---------------------------------------------------------------------------------------------------
-- diner_booth: two vinyl benches facing across a chrome-edged table (benches along Z, open ends at +/-Z)
---------------------------------------------------------------------------------------------------
add({
	id = "diner_booth",
	category = "campus",
	footprint = V(7.2, 4.05, 4.5),
	maxParts = 20,
	tags = { "seat", "table", "diner" },
	surface = 2.76,
	build = function(c: Ctx)
		local vinyl = c.color("color", VINYL_RED)
		local chrome = col.chrome
		for _, sx in { -1, 1 } do
			c.part(P(sx * 2.2, 0.75, 0), V(1.8, 1.5, 4.5), shade(vinyl, -0.2), M.Leather)
			c.detail(P(sx * 2.2, 0.2, 0), V(1.82, 0.4, 4.52), chrome, M.Metal)
			c.seat(P(sx * 2.2, 1.65, 0), V(1.8, 0.3, 4.5), vinyl, M.Leather)
			c.part(P(sx * 3.35, 2.6, 0), V(0.5, 2.2, 4.5), vinyl, M.Leather)
			c.dcylZ(P(sx * 3.35, 3.75, 0), 4.5, 0.55, c.color("accent", CREAM), M.Leather)
		end
		c.part(P(0, 2.7, 0), V(2.6, 0.12, 4.0), CREAM, M.SmoothPlastic)
		c.detail(P(0, 2.7, 0), V(2.64, 0.08, 4.04), chrome, M.Metal)
		c.dcyl(P(0, 1.35, 0), 2.6, 0.3, chrome, M.Metal)
		c.dcyl(P(0, 0.05, 0), 0.1, 1.4, chrome, M.Metal)
		c.detail(P(0, 2.96, 1.6), V(0.4, 0.4, 0.3), chrome, M.Metal)
		c.dcyl(P(0.35, 2.99, 1.62), 0.46, 0.16, hex("#C0392B"), M.SmoothPlastic)
		c.dcyl(P(-0.35, 2.99, 1.62), 0.46, 0.16, hex("#E3B505"), M.SmoothPlastic)
		if c.rng:chance(0.4) then
			local sx = if c.rng:chance(0.5) then -1 else 1
			c.detail(
				P(sx * 2.2, 1.805, c.rng:range(-1.5, 1.5)) * R(0, c.rng:range(-30, 30), 0),
				V(0.6, 0.01, 0.3),
				hex("#9A9DA1"),
				M.Fabric
			)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- diner_counter_stool: chrome pedestal stool with a red vinyl cushion (opts.seat adds a hidden Seat)
---------------------------------------------------------------------------------------------------
add({
	id = "diner_counter_stool",
	category = "campus",
	footprint = V(1.3, 2.71, 1.3),
	maxParts = 7,
	tags = { "seat", "diner" },
	build = function(c: Ctx)
		local chrome = col.chrome
		c.dcyl(P(0, 0.06, 0), 0.12, 1.3, chrome, M.Metal)
		c.dcyl(P(0, 1.2, 0), 2.2, 0.25, chrome, M.Metal)
		c.dcyl(P(0, 2.33, 0), 0.1, 1.2, chrome, M.Metal)
		c.dcyl(P(0, 2.43, 0), 0.1, 1.3, chrome, M.Metal)
		c.cyl(P(0, 2.55, 0), 0.32, 1.25, c.color("color", VINYL_RED), M.Leather)
		if c.o.seat == true then
			local s = c.seat(P(0, 2.55, 0), V(1.0, 0.3, 1.0), VINYL_RED, M.Leather)
			s.Transparency = 1
		end
	end,
})

return defs
