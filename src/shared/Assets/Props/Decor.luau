--!strict
-- Decor (category "decor"): small housing items for desks, apartments and offices. Desk items use
-- mount "desk" (cf on the table top). Tags carry the housing SlotKind each item fits:
-- desk_item, wall_art, floor, plant, lamp, rug.

local Common = require(script.Parent.Common)
local Shapes = require(script.Parent.Shapes)
local Gui = require(script.Parent.Gui)
local Words = require(script.Parent.Words)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)

type Ctx = Common.Ctx
type Def = Common.Def

local P, R = Common.P, Common.R
local V = Vector3.new
local M = Enum.Material
local col = Common.col
local S = Kit.Palette.street
local shade = Kit.shade
local hex = Kit.hex

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

---------------------------------------------------------------------------------------------------
-- Desk items
---------------------------------------------------------------------------------------------------
add({
	id = "nameplate",
	category = "decor",
	footprint = V(1.65, 0.34, 0.5),
	maxParts = 4,
	tags = { "desk_item", "text" },
	mount = "desk",
	build = function(c: Ctx)
		local wood = c.color("color", S.walnut)
		local brass = c.color("accent", S.brass)
		c.detail(P(0, 0.02, 0), V(1.65, 0.04, 0.5), shade(wood, -0.25), M.Wood)
		c.dwedge(P(0, 0.19, 0), V(1.6, 0.3, 0.45), wood, M.Wood)
		-- brass plate lying on the slope (slope normal = (0, 0.832, -0.555))
		local plate = c.detail(P(0, 0.19 + 0.01, -0.007) * R(56.3, 0, 0), V(1.4, 0.4, 0.02), brass, M.Metal)
		plate.Name = "Plate"
		c.sign(plate, c.str("text", Words.nameplate, 40), {
			font = Enum.Font.Bodoni,
			color = hex("#2A1C14"),
			pixelsPerStud = 120,
			padding = 0.1,
		})
	end,
})

add({
	id = "photo_frame",
	category = "decor",
	footprint = V(0.9, 0.7, 0.4),
	maxParts = 4,
	tags = { "desk_item", "photo" },
	mount = "desk",
	build = function(c: Ctx)
		local fw, fh = 0.9, 0.7
		local frameC = c.color("color", c.rng:pick({ S.walnut, S.gold, col.plasticBlack, S.white }))
		local base = P(0, 0.01, -0.05) * R(12, 0, 0)
		c.detail(base * P(0, fh / 2, 0), V(fw, fh, 0.06), frameC, M.Wood)
		local photo = c.detail(base * P(0, fh / 2, -0.035), V(fw - 0.14, fh - 0.14, 0.01), Color3.new(1, 1, 1))
		photo.Name = "Photo"
		local gui, gw, gh = Gui.Core.surface(photo, Enum.NormalId.Front, { pps = 120, maxDistance = 40 })
		Gui.Art.photo(gui, gw, gh, c.rng)
		c.detail(P(0, 0.24, 0.13) * R(-22, 0, 0), V(0.08, 0.5, 0.03), frameC, M.Wood)
	end,
})

add({
	id = "globe",
	category = "decor",
	footprint = V(1.0, 1.3, 0.85),
	maxParts = 14,
	tags = { "desk_item" },
	mount = "desk",
	build = function(c: Ctx)
		local wood = c.color("accent", S.walnut)
		local brass = S.brass
		c.dcyl(P(0, 0.04, 0), 0.08, 0.6, wood, M.Wood)
		c.dcyl(P(0, 0.18, 0), 0.2, 0.08, brass, M.Metal)
		local cy, r = 0.75, 0.48
		c.dball(P(0, cy, 0), 0.8, c.color("color", hex("#2E5E8C")), M.SmoothPlastic)
		-- continents: low bumps on the sphere (all fictional shapes)
		for _ = 1, 4 do
			local yaw = math.rad(c.rng:range(0, 360))
			local pitch = math.rad(c.rng:range(-50, 50))
			local dir = V(math.cos(pitch) * math.cos(yaw), math.sin(pitch), math.cos(pitch) * math.sin(yaw))
			local p = V(0, cy, 0) + dir * 0.28
			c.dball(P(p.X, p.Y, p.Z), c.rng:range(0.26, 0.36), c.rng:pick({ hex("#C9B27A"), hex("#6E8B4A") }), M.SmoothPlastic)
		end
		-- brass half meridian from the stem round the left side to the top pivot
		local pts = {}
		for i = 0, 5 do
			local a = math.rad(270 - i * 36)
			table.insert(pts, V(math.cos(a) * r, cy + math.sin(a) * r, 0))
		end
		for i = 1, 5 do
			Shapes.tube(c, pts[i], pts[i + 1], 0.05, brass, M.Metal)
		end
		c.dcyl(P(0, cy + r + 0.04, 0), 0.08, 0.06, brass, M.Metal)
	end,
})

add({
	id = "bonsai",
	category = "decor",
	footprint = V(1.2, 1.25, 0.8),
	maxParts = 12,
	tags = { "desk_item", "plant" },
	mount = "desk",
	build = function(c: Ctx)
		local pot = c.color("color", hex("#3B4A5C"))
		c.detail(P(0, 0.12, 0), V(1.1, 0.24, 0.7), pot, M.SmoothPlastic)
		c.detail(P(0, 0.255, 0), V(1.16, 0.03, 0.76), shade(pot, -0.2), M.SmoothPlastic)
		c.detail(P(0, 0.28, 0), V(1.0, 0.03, 0.6), hex("#5E7A3A"), M.Grass)
		local trunk = col.trunk
		local a, b, d, e = V(0, 0.28, 0), V(0.12, 0.58, 0.02), V(-0.1, 0.86, 0), V(0.08, 1.05, 0)
		Shapes.strut(c, a, b, 0.11, trunk, M.Wood)
		Shapes.strut(c, b, d, 0.09, trunk, M.Wood)
		Shapes.strut(c, d, e, 0.07, trunk, M.Wood)
		local greens = { hex("#3F6B3A"), hex("#4E7D3F"), hex("#355E30") }
		local pads = { { 0.3, 0.72, 0.05, 0.5 }, { -0.32, 0.95, -0.04, 0.55 }, { 0.08, 1.14, 0, 0.62 }, { 0.36, 1.0, 0.08, 0.38 } }
		for i, pd in pads do
			c.dcyl(P(pd[1], pd[2], pd[3]), 0.16, pd[4] * c.rng:range(0.9, 1.1), greens[(i - 1) % 3 + 1], M.Grass)
		end
		c.dball(P(-0.32, 0.36, 0.12), 0.16, hex("#7E7A72"), M.Slate)
	end,
})

add({
	id = "stress_ball",
	category = "decor",
	footprint = V(0.4, 0.42, 0.4),
	maxParts = 3,
	tags = { "desk_item" },
	mount = "desk",
	build = function(c: Ctx)
		c.dcyl(P(0, 0.02, 0), 0.04, 0.3, col.plasticBlack, M.SmoothPlastic)
		c.dball(P(0, 0.22, 0), 0.4, c.color("color", c.rng:pick({ hex("#E2532F"), S.gold, S.navyLight, hex("#2BA36B") })), M.SmoothPlastic)
	end,
})

add({
	id = "coffee_mug",
	category = "decor",
	footprint = V(0.48, 0.4, 0.32),
	maxParts = 6,
	tags = { "desk_item" },
	mount = "desk",
	build = function(c: Ctx)
		local mug = c.color("color", c.rng:pick({ col.ceramicWhite, S.navy, hex("#7A1F24"), hex("#2F5A3A") }))
		c.dcyl(P(0, 0.2, 0), 0.4, 0.32, mug, M.SmoothPlastic)
		c.dcyl(P(0, 0.37, 0), 0.02, 0.27, hex("#3B2416"), M.SmoothPlastic)
		c.detail(P(0.2, 0.3, 0), V(0.1, 0.05, 0.05), mug, M.SmoothPlastic)
		c.detail(P(0.2, 0.1, 0), V(0.1, 0.05, 0.05), mug, M.SmoothPlastic)
		c.detail(P(0.23, 0.2, 0), V(0.05, 0.25, 0.05), mug, M.SmoothPlastic)
	end,
})

add({
	id = "desk_organizer",
	category = "decor",
	footprint = V(1.25, 0.85, 1.0),
	maxParts = 10,
	tags = { "desk_item" },
	mount = "desk",
	build = function(c: Ctx)
		local black = c.color("color", col.plasticBlack)
		c.dcyl(P(-0.45, 0.25, 0), 0.5, 0.32, black, M.DiamondPlate)
		for i, pc in { hex("#1F4FB5"), hex("#C62828"), S.gold } do
			local tilt = (i - 2) * 9
			c.dcyl(P(-0.45 + (i - 2) * 0.07, 0.55, (i - 2) * 0.04) * R(tilt * 0.4, 0, tilt), 0.55, 0.04, pc, M.SmoothPlastic)
		end
		c.detail(P(0.25, 0.06, 0), V(0.8, 0.12, 1.0), black, M.SmoothPlastic)
		c.detail(P(0.25, 0.13, 0.02), V(0.7, 0.02, 0.9), col.paper, M.SmoothPlastic)
		c.detail(P(0.25, 0.36, 0), V(0.8, 0.08, 1.0), black, M.SmoothPlastic)
		c.detail(P(0.25, 0.24, 0.47), V(0.8, 0.24, 0.06), black, M.SmoothPlastic)
		c.detail(P(-0.45, 0.04, -0.38), V(0.3, 0.08, 0.3), hex("#F4E04D"), M.SmoothPlastic)
	end,
})

-- Fictional bronze desk sculpture: a stylised bull and bear squaring off on a marble block.
add({
	id = "mini_bull_bear",
	category = "decor",
	footprint = V(1.4, 0.78, 0.7),
	maxParts = 19,
	tags = { "desk_item", "sculpture" },
	mount = "desk",
	build = function(c: Ctx)
		local bronze = c.color("color", col.bronze)
		local dark = shade(bronze, -0.25)
		local B = M.Metal
		c.detail(P(0, 0.075, 0), V(1.4, 0.15, 0.7), c.color("accent", S.marble), M.Marble)
		local plate = c.detail(P(0, 0.075, -0.355), V(0.6, 0.08, 0.01), S.brass, M.Metal)
		c.sign(plate, Words.statue, { font = Enum.Font.Bodoni, color = hex("#2A1C14"), pixelsPerStud = 160 })
		-- bull (left, facing +X, head lowered)
		local y0 = 0.15
		c.detail(P(-0.22, y0 + 0.1, 0), V(0.08, 0.2, 0.2), dark, B)
		c.detail(P(-0.56, y0 + 0.1, 0), V(0.08, 0.2, 0.2), dark, B)
		c.detail(P(-0.4, y0 + 0.31, 0), V(0.52, 0.24, 0.24), bronze, B)
		c.detail(P(-0.27, y0 + 0.45, 0), V(0.22, 0.1, 0.22), bronze, B)
		c.detail(P(-0.08, y0 + 0.28, 0) * R(0, 0, -20), V(0.18, 0.16, 0.18), bronze, B)
		for _, sz in { -1, 1 } do
			c.detail(P(-0.04, y0 + 0.4, sz * 0.1) * R(sz * 25, 0, -30), V(0.035, 0.14, 0.035), S.goldBright, B)
		end
		c.detail(P(-0.68, y0 + 0.3, 0) * R(0, 0, 30), V(0.03, 0.18, 0.03), dark, B)
		-- bear (right, facing -X, rearing)
		c.detail(P(0.56, y0 + 0.11, 0), V(0.12, 0.22, 0.22), dark, B)
		c.detail(P(0.25, y0 + 0.16, 0), V(0.1, 0.32, 0.2), dark, B)
		c.detail(P(0.42, y0 + 0.32, 0) * R(0, 0, 15), V(0.42, 0.3, 0.26), bronze, B)
		c.detail(P(0.17, y0 + 0.43, 0), V(0.18, 0.18, 0.18), bronze, B)
		c.detail(P(0.06, y0 + 0.4, 0), V(0.08, 0.08, 0.1), dark, B)
		for _, sz in { -1, 1 } do
			c.detail(P(0.19, y0 + 0.54, sz * 0.06), V(0.05, 0.05, 0.04), bronze, B)
		end
	end,
})

add({
	id = "cactus",
	category = "decor",
	footprint = V(0.6, 1.45, 0.55),
	maxParts = 13,
	tags = { "desk_item", "plant" },
	mount = "desk",
	build = function(c: Ctx)
		local green = c.color("color", hex("#4F7A43"))
		local soil = Shapes.pot(c, CFrame.identity, 0.5, 0.45, c.color("accent", col.terracotta), M.SmoothPlastic)
		c.dcyl(P(0, soil + 0.4, 0), 0.8, 0.26, green, M.Grass)
		c.dball(P(0, soil + 0.8, 0), 0.26, green, M.Grass)
		c.dcylX(P(0.18, soil + 0.38, 0), 0.18, 0.12, green, M.Grass)
		c.dcyl(P(0.26, soil + 0.52, 0), 0.3, 0.12, green, M.Grass)
		c.dball(P(0.26, soil + 0.67, 0), 0.12, green, M.Grass)
		c.dcylX(P(-0.17, soil + 0.25, 0), 0.16, 0.11, green, M.Grass)
		c.dcyl(P(-0.24, soil + 0.36, 0), 0.24, 0.11, green, M.Grass)
		c.dball(P(-0.24, soil + 0.48, 0), 0.11, green, M.Grass)
		c.dball(P(0, soil + 0.94, 0), 0.1, hex("#E86FA0"), M.SmoothPlastic)
	end,
})

add({
	id = "book_stack",
	category = "decor",
	footprint = V(1.15, 0.44, 0.9),
	maxParts = 8,
	tags = { "desk_item", "books" },
	mount = "desk",
	build = function(c: Ctx)
		local n = c.int("count", 4, 1, 6)
		local y = 0
		for _ = 1, n do
			local h = c.rng:range(0.09, 0.13)
			local w = c.rng:range(0.8, 1.05)
			local d = c.rng:range(0.6, 0.78)
			c.detail(
				P(c.rng:range(-0.06, 0.06), y + h / 2, c.rng:range(-0.05, 0.05)) * R(0, c.rng:range(-14, 14), 0),
				V(w, h, d),
				c.rng:pick(Shapes.BOOK_COLORS),
				M.SmoothPlastic
			)
			y += h
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- Wall items
---------------------------------------------------------------------------------------------------
add({
	id = "award_plaque",
	category = "decor",
	footprint = V(1.6, 2.0, 0.2),
	maxParts = 5,
	tags = { "wall_art", "wall", "trophy", "text" },
	mount = "wall",
	build = function(c: Ctx)
		local wood = c.color("color", S.walnut)
		local brass = c.color("accent", S.brass)
		c.detail(P(0, 1.0, -0.06), V(1.6, 2.0, 0.12), wood, M.Wood)
		c.detail(P(0, 1.0, -0.13), V(1.44, 1.84, 0.02), shade(wood, -0.25), M.Wood)
		local plate = c.detail(P(0, 0.88, -0.15), V(1.24, 1.3, 0.02), brass, M.Metal)
		plate.Name = "Plate"
		c.sign(plate, c.str("text", c.rng:pick(Words.awards), 60), {
			font = Enum.Font.Bodoni,
			color = hex("#2A1C14"),
			pixelsPerStud = 80,
			padding = 0.12,
		})
		c.dcylZ(P(0, 1.73, -0.15), 0.03, 0.28, S.goldBright, M.Metal)
	end,
})

add({
	id = "art_canvas_large",
	category = "decor",
	footprint = V(8.36, 5.36, 0.35),
	maxParts = 6,
	tags = { "art", "wall_art", "wall" },
	mount = "wall",
	build = function(c: Ctx)
		local W, Hh, t = 8, 5, 0.08
		local cy = Hh / 2 + 0.1 + t
		local canvas = c.detail(P(0, cy, -0.15), V(W, Hh, 0.3), Color3.new(1, 1, 1), M.Fabric)
		canvas.Name = "Canvas"
		local gui, gw, gh = Gui.Core.surface(canvas, Enum.NormalId.Front, { pps = 24, maxDistance = 160 })
		Gui.Art.painting(gui, gw, gh, c.int("variant", c.rng:int(1, 8), 1, 8), c.rng)
		Shapes.frameRect(c, P(0, cy, -0.175), W + 0.2, Hh + 0.2, t, 0.35, c.color("color", col.plasticBlack), M.SmoothPlastic)
	end,
})

---------------------------------------------------------------------------------------------------
-- Rugs
---------------------------------------------------------------------------------------------------
add({
	id = "rug_round",
	category = "decor",
	footprint = V(8, 0.06, 8),
	maxParts = 5,
	tags = { "rug" },
	build = function(c: Ctx)
		local d = c.num("size", 8, 3, 16)
		local base = c.color("color", hex("#C9B28A"))
		local accent = c.color("accent", S.navyLight)
		for i, k in { 1, 0.8, 0.55, 0.3 } do
			local h = 0.04 + (i - 1) * 0.006
			c.dcyl(P(0, h / 2, 0), h, d * k, if i % 2 == 1 then base else accent, M.Fabric)
		end
	end,
})

add({
	id = "rug_persian",
	category = "decor",
	footprint = V(9.6, 0.05, 6),
	maxParts = 4,
	tags = { "rug" },
	build = function(c: Ctx)
		local W, D = 9, 6
		local base = c.color("color", hex("#7A1F24"))
		local rug = c.detail(P(0, 0.025, 0), V(W, 0.05, D), base, M.Fabric)
		rug.Name = "Rug"
		local gui, gw, gh = Gui.Core.surface(rug, Enum.NormalId.Top, { pps = 14, maxDistance = 140 })
		Gui.Art.rug(gui, gw, gh, "persian", c.rng, base, c.color("accent", S.gold))
		for _, sx in { -1, 1 } do
			c.detail(P(sx * (W / 2 + 0.15), 0.015, 0), V(0.3, 0.03, D - 0.3), hex("#E8D8B8"), M.Fabric)
		end
	end,
})

add({
	id = "rug_modern",
	category = "decor",
	footprint = V(9, 0.06, 6),
	maxParts = 2,
	tags = { "rug" },
	build = function(c: Ctx)
		local base = c.color("color", hex("#D9D4CA"))
		local rug = c.detail(P(0, 0.03, 0), V(9, 0.06, 6), base, M.Carpet)
		rug.Name = "Rug"
		local gui, gw, gh = Gui.Core.surface(rug, Enum.NormalId.Top, { pps = 14, maxDistance = 140 })
		Gui.Art.rug(gui, gw, gh, "modern", c.rng, base, c.color("accent", hex("#C8553D")))
	end,
})

---------------------------------------------------------------------------------------------------
-- Lamps (opts.lit, default true)
---------------------------------------------------------------------------------------------------
add({
	id = "lamp_floor",
	category = "decor",
	footprint = V(1.7, 6.1, 1.7),
	maxParts = 7,
	tags = { "lamp", "floor", "light" },
	build = function(c: Ctx)
		local lit = c.bool("lit", true)
		local metal = c.color("accent", S.brass)
		c.dcyl(P(0, 0.08, 0), 0.16, 1.2, col.plasticBlack, M.Marble)
		c.dcyl(P(0, 2.6, 0), 5.0, 0.12, metal, M.Metal)
		c.dcyl(P(0, 1.6, 0), 0.08, 0.2, metal, M.Metal)
		local shadePart = c.dcyl(P(0, 5.4, 0), 1.3, 1.7, c.color("color", hex("#EFE6D2")), M.Fabric)
		shadePart.Transparency = 0.15
		local bulb = if lit
			then c.glow(P(0, 5.2, 0), V(0.4, 0.5, 0.4), col.warmBulb, 0.1)
			else c.detail(P(0, 5.2, 0), V(0.4, 0.5, 0.4), shade(col.warmBulb, -0.2), M.SmoothPlastic)
		Shapes.lamp(bulb, lit, col.warmBulb, 14, 1.2)
		c.dball(P(0, 6.1, 0), 0.14, metal, M.Metal)
	end,
})

add({
	id = "lamp_arc",
	category = "decor",
	footprint = V(6.2, 7.0, 1.6),
	maxParts = 12,
	tags = { "lamp", "floor", "light" },
	build = function(c: Ctx)
		local lit = c.bool("lit", true)
		local steel = c.color("accent", col.chrome)
		local x0 = -2.4
		c.part(P(x0, 0.3, 0), V(1.2, 0.6, 1.2), c.color("color", S.marble), M.Marble)
		local A, B = 2.75, 6.3
		local pts = {}
		for i = 0, 6 do
			local t = (i / 6) * math.pi * 0.72
			table.insert(pts, V(x0 + A * (1 - math.cos(t)), 0.6 + B * math.sin(t), 0))
		end
		for i = 1, 6 do
			Shapes.tube(c, pts[i], pts[i + 1], 0.12, steel, M.Metal)
		end
		local tip = pts[7]
		c.dcyl(P(tip.X, tip.Y - 0.25, 0), 0.5, 0.1, steel, M.Metal)
		local dome = c.dcyl(P(tip.X, tip.Y - 0.75, 0), 0.6, 1.5, steel, M.Metal)
		dome.Name = "Shade"
		local bulb = if lit
			then c.glow(P(tip.X, tip.Y - 1.07, 0), V(1.0, 0.04, 1.0), col.warmBulb, 0.1)
			else c.detail(P(tip.X, tip.Y - 1.07, 0), V(1.0, 0.04, 1.0), shade(col.warmBulb, -0.2), M.SmoothPlastic)
		if lit then
			c.light(bulb, "spot", { Face = Enum.NormalId.Bottom, Angle = 120, Range = 16, Brightness = 1.6, Color = col.warmBulb })
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- Floor pieces
---------------------------------------------------------------------------------------------------
add({
	id = "sculpture_abstract",
	category = "decor",
	footprint = V(1.7, 6.0, 1.7),
	maxParts = 9,
	tags = { "floor", "sculpture", "art" },
	build = function(c: Ctx)
		local metal = c.color("color", c.rng:pick({ col.bronze, S.brass, S.steelBrushed }))
		c.part(P(0, 1.6, 0), V(1.6, 3.2, 1.6), c.color("accent", S.white), M.SmoothPlastic)
		c.detail(P(0, 3.24, 0), V(1.7, 0.08, 1.7), shade(S.white, -0.08), M.Marble)
		if c.rng:chance(0.5) then
			-- twisted stack of cubes topped by a sphere
			local y = 3.28
			for i, s in { 0.9, 0.7, 0.5 } do
				c.detail(P(0, y + s / 2, 0) * R(0, i * 22, 0), V(s, s, s), metal, M.Metal)
				y += s
			end
			c.dball(P(0, y + 0.3, 0), 0.6, S.goldBright, M.Metal)
		else
			-- leaning blade, counterweight and orb
			c.detail(P(-0.15, 3.28 + 1.2, 0) * R(0, 30, 14), V(0.25, 2.4, 0.7), metal, M.Metal)
			c.detail(P(0.3, 3.28 + 0.3, 0.1), V(0.6, 0.6, 0.6), shade(metal, -0.2), M.Metal)
			c.dball(P(0.42, 3.28 + 2.1, 0), 0.55, S.goldBright, M.Metal)
			c.detail(P(0.15, 3.28 + 1.3, 0) * R(0, 0, -35), V(0.08, 1.6, 0.08), metal, M.Metal)
		end
	end,
})

add({
	id = "aquarium",
	category = "decor",
	footprint = V(5.05, 5.3, 1.85),
	maxParts = 24,
	tags = { "floor", "aquarium" },
	build = function(c: Ctx)
		local stand = c.color("color", col.plasticBlack)
		c.part(P(0, 1.35, 0), V(5, 2.7, 1.8), stand, M.Wood)
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 1.24, 1.35, -0.91), V(2.4, 2.4, 0.03), shade(stand, 0.08), M.Wood)
		end
		local tank = c.glass(P(0, 2.7 + 1.25, 0), V(5, 2.5, 1.8), hex("#DDEFF5"), 0.75, true)
		tank.Name = "Tank"
		local water = c.detail(P(0, 2.7 + 1.1, 0), V(4.85, 2.1, 1.65), hex("#4FA6C9"), M.Glass)
		water.Transparency = 0.55
		c.detail(P(0, 2.78, 0), V(4.85, 0.14, 1.65), hex("#D8C9A3"), M.Pebble)
		Shapes.blades(c, P(-1.6, 2.85, 0.3), 4, 1.4, 0.14, col.leafLight, 12)
		Shapes.blades(c, P(1.7, 2.85, 0.4), 4, 1.1, 0.14, col.leaf, 12)
		c.dball(P(1.0, 2.98, 0.2), 0.6, hex("#7E7A72"), M.Slate)
		for _ = 1, 4 do
			local fish = c.detail(
				P(c.rng:range(-2, 2), c.rng:range(3.3, 4.4), c.rng:range(-0.5, 0.5)) * R(0, c.rng:range(-30, 30), 0),
				V(0.3, 0.16, 0.08),
				c.rng:pick({ hex("#F28F3B"), hex("#F4D35E"), hex("#2E86C1"), hex("#E04F5F") }),
				M.SmoothPlastic
			)
			fish.Name = "Fish"
		end
		c.detail(P(0, 5.25, 0), V(5.05, 0.1, 1.85), stand, M.SmoothPlastic)
		c.glow(P(0, 5.18, 0), V(4.6, 0.03, 0.3), hex("#CFE8FF"), 0.3)
	end,
})

add({
	id = "record_player",
	category = "decor",
	footprint = V(4, 2.32, 1.65),
	maxParts = 16,
	tags = { "floor", "music" },
	surface = 2.1,
	build = function(c: Ctx)
		local wood = c.color("color", S.walnut)
		c.part(P(0, 1.35, 0), V(4, 1.5, 1.6), wood, M.Wood)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				c.detail(P(sx * 1.8, 0.3, sz * 0.6), V(0.12, 0.6, 0.12), shade(wood, -0.2), M.Wood)
			end
			c.detail(P(sx * 1.25, 1.35, -0.81), V(1.2, 1.1, 0.03), col.fabricOat, M.Fabric)
		end
		c.detail(P(0, 1.35, -0.81), V(1.1, 1.1, 0.03), shade(wood, -0.1), M.Wood)
		c.detail(P(0, 2.16, 0), V(1.6, 0.12, 1.3), shade(wood, -0.3), M.Wood)
		c.dcyl(P(-0.15, 2.25, 0), 0.06, 1.0, S.steelBrushed, M.Metal)
		c.dcyl(P(-0.15, 2.29, 0), 0.02, 0.95, col.plasticBlack, M.SmoothPlastic)
		c.dcyl(P(-0.15, 2.305, 0), 0.01, 0.3, c.color("accent", hex("#C0392B")), M.SmoothPlastic)
		c.dcyl(P(0.5, 2.27, 0.4), 0.1, 0.16, col.chrome, M.Metal)
		c.detail(P(0.35, 2.3, 0.05) * R(0, -20, 0), V(0.04, 0.04, 0.8), col.chrome, M.Metal)
	end,
})

add({
	id = "bar_cart",
	category = "decor",
	footprint = V(2.8, 3.3, 1.4),
	maxParts = 24,
	tags = { "floor", "bar" },
	build = function(c: Ctx)
		local brass = c.color("accent", S.brass)
		for _, sz in { -1, 1 } do
			c.detail(P(-1.1, 0.3 + 1.45, sz * 0.6), V(0.08, 2.9, 0.08), brass, M.Metal)
			c.detail(P(1.1, 1.6, sz * 0.6), V(0.08, 3.2, 0.08), brass, M.Metal)
			c.dcylZ(P(-1.1, 0.3, sz * 0.66), 0.08, 0.6, col.plasticBlack, M.Rubber)
		end
		local trayC = c.color("color", hex("#2B2E33"))
		for _, y in { 0.8, 2.4 } do
			local tray = c.detail(P(0, y, 0), V(2.3, 0.06, 1.3), trayC, M.Glass)
			tray.Reflectance = 0.3
		end
		c.dcylZ(P(1.35, 3.0, 0), 1.2, 0.08, brass, M.Metal)
		c.detail(P(1.22, 3.0, 0.55), V(0.28, 0.06, 0.06), brass, M.Metal)
		c.detail(P(1.22, 3.0, -0.55), V(0.28, 0.06, 0.06), brass, M.Metal)
		local bottles = { hex("#3B5E2B"), hex("#6B3A1E"), hex("#D8E6EA"), hex("#5A1E2A") }
		for i, bc in bottles do
			Shapes.bottle(c, P(-0.8 + (i - 1) * 0.5, 2.43, c.rng:range(-0.25, 0.25)), c.rng:range(0.7, 0.95), 0.24, bc, true)
		end
		for i = 1, 2 do
			local g = c.dcyl(P(-0.5 + i * 0.4, 0.83 + 0.13, -0.3), 0.26, 0.18, hex("#E6F2F5"), M.Glass)
			g.Transparency = 0.5
		end
		c.dcyl(P(0.5, 0.83 + 0.2, 0.2), 0.4, 0.4, S.steelBrushed, M.Metal)
	end,
})

return defs
