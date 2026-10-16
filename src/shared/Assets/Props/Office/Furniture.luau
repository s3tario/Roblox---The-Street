--!strict
-- Office furniture: filing cabinet, bookshelf, conference table (with chairs), mobile whiteboard, coffee
-- table, office rug, floor and desk plants, divider planter and the deal-toy trophy shelf.

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
local S = Kit.Palette.street
local shade = Kit.shade
local hex = Kit.hex

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

---------------------------------------------------------------------------------------------------
-- filing_cabinet: four-drawer steel cabinet with label holders
---------------------------------------------------------------------------------------------------
add({
	id = "filing_cabinet",
	category = "office",
	footprint = V(1.65, 4.45, 2.55),
	maxParts = 16,
	tags = { "storage", "furniture" },
	build = function(c: Ctx)
		local body = c.color("color", hex("#7D8288"))
		local W, Hh, D = 1.6, 4.4, 2.4
		local n = 4
		local h = Hh - 0.16
		local cy = 0.16 + h / 2
		c.detail(P(0, 0.08, 0), V(W - 0.1, 0.16, D - 0.1), col.frameDark, M.SmoothPlastic)
		Shapes.drawers(c, P(0, cy, 0), V(W, h, D), n, body, M.Metal, shade(body, 0.07), M.Metal, col.chrome, true)
		local gap = 0.06
		local fh = (h - gap * (n + 1)) / n
		for i = 1, n do
			local y = cy - h / 2 + gap * i + fh * (i - 0.5)
			c.detail(P(0, y + fh * 0.36, -D / 2 - 0.07), V(0.45, 0.16, 0.02), col.paper, M.SmoothPlastic)
		end
		c.detail(P(0, Hh + 0.02, 0), V(W + 0.04, 0.04, D + 0.04), shade(body, -0.12), M.Metal)
		c.use(V(0, 3, -D / 2 - 0.5))
	end,
})

---------------------------------------------------------------------------------------------------
-- bookshelf: crowned bookcase with five levels of books (and the odd vase); opts.tier = wood
---------------------------------------------------------------------------------------------------
add({
	id = "bookshelf",
	category = "office",
	footprint = V(5.25, 7.35, 1.5),
	maxParts = 38,
	tags = { "storage", "furniture", "books" },
	build = function(c: Ctx)
		local f = Common.finish(c.int("tier", 3, 1, 4))
		local wood = c.color("color", f.wood)
		local W, Hh, D = 5, 7.2, 1.4
		for _, sx in { -1, 1 } do
			c.part(P(sx * (W / 2 - 0.1), Hh / 2, 0), V(0.2, Hh, D), wood, f.woodMat)
		end
		c.part(P(0, Hh - 0.1, 0), V(W, 0.2, D), wood, f.woodMat)
		c.detail(P(0, Hh + 0.07, -0.03), V(W + 0.24, 0.14, D + 0.1), shade(wood, -0.15), f.woodMat)
		c.part(P(0, 0.25, 0), V(W - 0.4, 0.5, D - 0.05), shade(wood, -0.2), f.woodMat)
		c.detail(P(0, Hh / 2, D / 2 - 0.04), V(W - 0.4, Hh - 0.3, 0.06), shade(wood, -0.35), f.woodMat)
		local step = (Hh - 0.2 - 0.5) / 5
		for i = 1, 4 do
			c.detail(P(0, 0.5 + i * step, -0.02), V(W - 0.4, 0.12, D - 0.12), wood, f.woodMat)
		end
		for i = 0, 4 do
			local base = 0.5 + i * step + (if i > 0 then 0.06 else 0)
			if i > 0 and c.rng:chance(0.22) then
				-- a vase and a keepsake box instead of books
				local vx = c.rng:range(-1.2, 1.2)
				c.dcyl(P(vx, base + 0.35, -0.1), 0.7, 0.45, c.rng:pick({ col.ceramicWhite, S.navy, col.terracotta }))
				c.dball(P(vx, base + 0.72, -0.1), 0.3, col.leafDark, M.Grass)
				c.detail(P(vx + 1.1, base + 0.15, -0.05), V(0.6, 0.3, 0.5), S.leather, M.Leather)
			else
				Shapes.books(c, P(0, base, -0.05), W - 0.5, step * 0.75, D - 0.35, 5)
			end
		end
		c.use(V(0, 3.5, -D / 2 - 0.5))
	end,
})

---------------------------------------------------------------------------------------------------
-- conference_table: racetrack boardroom table. opts.seats (2-16, default 8) meeting chairs around it,
-- opts.chairs = false for the bare table; opts.tier for the wood.
---------------------------------------------------------------------------------------------------
add({
	id = "conference_table",
	category = "office",
	footprint = V(17.8, 3.85, 8.25),
	maxParts = 100,
	tags = { "table", "furniture", "meeting" },
	surface = 2.8,
	scales = { seats = 16 },
	build = function(c: Ctx)
		local f = Common.finish(c.int("tier", 3, 1, 4))
		local wood = c.color("color", f.wood)
		local seats = c.int("seats", 8, 2, 16)
		local perSide = math.ceil(seats / 2)
		local pitch, D, H = 3.2, 5, 2.8
		local Ls = perSide * pitch
		c.part(P(0, H - 0.1, 0), V(Ls, 0.2, D), wood, f.woodMat)
		c.detail(P(0, H - 0.24, 0), V(Ls, 0.08, D - 0.3), shade(wood, -0.25), f.woodMat)
		for _, sx in { -1, 1 } do
			c.cyl(P(sx * Ls / 2, H - 0.1, 0), 0.2, D, wood, f.woodMat)
			c.dcyl(P(sx * Ls / 2, H - 0.24, 0), 0.08, D - 0.3, shade(wood, -0.25), f.woodMat)
		end
		c.detail(P(0, H + 0.003, 0), V(Ls, 0.006, D * 0.3), c.color("accent", col.leatherBlack), M.Leather)
		local peds = math.max(2, math.floor(Ls / 7) + 1)
		for i = 1, peds do
			local x = -Ls / 2 + 1.5 + (Ls - 3) * (i - 1) / (peds - 1)
			c.part(P(x, 0.15 + (H - 0.48) / 2, 0), V(1.2, H - 0.48, 2.4), col.frameDark, M.Metal)
			c.detail(P(x, 0.075, 0), V(2.2, 0.15, 3.4), f.metal, f.metalMat)
		end
		c.detail(P(0, H + 0.05, 0) * R(0, 45, 0), V(0.8, 0.1, 0.8), col.plasticBlack, M.SmoothPlastic)
		if c.bool("chairs", true) then
			local fabric = c.color("fabric", col.leatherBlack)
			local placed = 0
			for _, side in { -1, 1 } do
				for i = 1, perSide do
					if placed < seats then
						placed += 1
						local x = -Ls / 2 + pitch * (i - 0.5)
						local rot = if side < 0 then R(0, 180, 0) else CFrame.identity
						Shapes.meetingChair(c, P(x, 0, side * (D / 2 + 0.55)) * rot, fabric, col.frameDark)
					end
				end
			end
		end
		c.use(V(0, H + 0.5, 0))
	end,
})

---------------------------------------------------------------------------------------------------
-- whiteboard: mobile whiteboard with a scribbled deal-flow diagram and a hand-drawn chart
---------------------------------------------------------------------------------------------------
add({
	id = "whiteboard",
	category = "office",
	footprint = V(7.6, 6.5, 2.0),
	maxParts = 20,
	tags = { "board", "meeting" },
	build = function(c: Ctx)
		local W, Hb, y0 = 7, 4, 2.3
		local frameC = c.color("accent", col.aluminum)
		local board = c.part(P(0, y0 + Hb / 2, 0), V(W, Hb, 0.12), c.color("color", hex("#F7F8F6")))
		board.Name = "Board"
		local gui, gw, gh = Gui.Core.surface(board, Enum.NormalId.Front, { pps = 40, maxDistance = 90 })
		Gui.Art.whiteboard(gui, gw, gh, c.rng)
		Shapes.frameRect(c, P(0, y0 + Hb / 2, 0), W, Hb, 0.12, 0.18, frameC, M.Metal)
		local postH = y0 + Hb + 0.2 - 0.3
		for _, sx in { -1, 1 } do
			local x = sx * (W / 2 + 0.2)
			c.dcyl(P(x, 0.3 + postH / 2, 0), postH, 0.14, frameC, M.Metal)
			c.detail(P(x, 0.3, 0), V(0.18, 0.12, 2.0), frameC, M.Metal)
			for _, sz in { -1, 1 } do
				c.dball(P(x, 0.12, sz * 0.85), 0.24, col.plasticBlack, M.SmoothPlastic)
			end
		end
		c.detail(P(0, y0 - 0.08, -0.12), V(W * 0.6, 0.06, 0.25), frameC, M.Metal)
		for i, mc in { hex("#1F4FB5"), hex("#C62828"), hex("#202124") } do
			c.dcylX(P(-1.2 + i * 0.6, y0 - 0.01, -0.15), 0.5, 0.08, mc, M.SmoothPlastic)
		end
		c.detail(P(1.4, y0, -0.14), V(0.45, 0.12, 0.18), col.plasticBlack, M.SmoothPlastic)
		c.use(V(0, 3.5, -1.2))
	end,
})

---------------------------------------------------------------------------------------------------
-- coffee_table: marble top on a brass frame with a walnut shelf, a couple of books and a bowl
---------------------------------------------------------------------------------------------------
add({
	id = "coffee_table",
	category = "office",
	footprint = V(4.5, 1.75, 2.5),
	maxParts = 12,
	tags = { "table", "furniture", "floor" },
	surface = 1.45,
	build = function(c: Ctx)
		local f = Common.finish(c.int("tier", 3, 1, 4))
		local W, D, Ht = 4.5, 2.5, 1.45
		c.part(P(0, Ht - 0.08, 0), V(W, 0.16, D), c.color("color", S.marble), M.Marble)
		local brass = c.color("accent", S.brass)
		c.detail(P(0, Ht - 0.19, 0), V(W - 0.1, 0.06, D - 0.1), brass, M.Metal)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				c.detail(P(sx * (W / 2 - 0.2), (Ht - 0.22) / 2, sz * (D / 2 - 0.2)), V(0.12, Ht - 0.22, 0.12), brass, M.Metal)
			end
		end
		c.detail(P(0, 0.35, 0), V(W - 0.3, 0.08, D - 0.3), f.wood, f.woodMat)
		c.detail(P(-0.9, Ht + 0.06, 0.1) * R(0, 8, 0), V(1.1, 0.12, 0.8), S.awningRed, M.SmoothPlastic)
		c.detail(P(-0.9, Ht + 0.17, 0.1) * R(0, -5, 0), V(0.9, 0.1, 0.7), S.navy, M.SmoothPlastic)
		c.dcyl(P(1.0, Ht + 0.12, -0.1), 0.24, 0.8, col.ceramicWhite, M.SmoothPlastic)
	end,
})

---------------------------------------------------------------------------------------------------
-- rug_office: bordered carpet; opts.width/depth, opts.color (field) and opts.accent (border)
---------------------------------------------------------------------------------------------------
add({
	id = "rug_office",
	category = "office",
	footprint = V(10, 0.06, 7),
	maxParts = 2,
	tags = { "rug", "floor_covering" },
	build = function(c: Ctx)
		local W = c.num("width", 10, 3, 30)
		local D = c.num("depth", 7, 3, 24)
		local base = c.color("color", S.carpetNavy)
		local rug = c.detail(P(0, 0.03, 0), V(W, 0.06, D), base, M.Carpet)
		rug.Name = "Rug"
		local gui, gw, gh = Gui.Core.surface(rug, Enum.NormalId.Top, { pps = 12, maxDistance = 140 })
		Gui.Art.rug(gui, gw, gh, "office", c.rng, base, c.color("accent", S.gold))
	end,
})

---------------------------------------------------------------------------------------------------
-- Plants
---------------------------------------------------------------------------------------------------
add({
	id = "plant_floor",
	category = "office",
	footprint = V(2.4, 5.9, 2.3),
	maxParts = 18,
	tags = { "plant", "floor" },
	build = function(c: Ctx)
		local variant = c.pick("variant", { "fig", "snake", "palm" }, "fig")
		local soil = Shapes.pot(c, CFrame.identity, 1.7, 1.8, c.color("color", hex("#2E3033")), M.Plaster, true)
		if variant == "snake" then
			Shapes.blades(c, P(0, soil, 0), 9, 2.8, 0.34, col.leafDark, 14)
		elseif variant == "palm" then
			Shapes.blades(c, P(0, soil, 0), 8, 3.4, 0.5, col.leafLight, 40)
			Shapes.blades(c, P(0, soil, 0), 5, 2.4, 0.4, col.leaf, 18)
		else
			Shapes.strut(c, V(0, soil, 0), V(0.15, soil + 2.6, 0.08), 0.16, col.trunk, M.Wood)
			Shapes.foliage(c, P(0.12, soil + 3.3, 0.05), 8, 0.85, 0.85, 1.3)
		end
	end,
})

add({
	id = "plant_desk",
	category = "office",
	footprint = V(0.65, 0.9, 0.65),
	maxParts = 10,
	tags = { "plant", "desk_item" },
	mount = "desk",
	build = function(c: Ctx)
		local variant = c.pick("variant", { "succulent", "fern" }, "succulent")
		local soil = Shapes.pot(c, CFrame.identity, 0.6, 0.5, c.color("color", col.ceramicWhite), M.SmoothPlastic)
		if variant == "fern" then
			Shapes.blades(c, P(0, soil, 0), 6, 0.45, 0.12, col.leafLight, 35)
		else
			Shapes.foliage(c, P(0, soil + 0.14, 0), 6, 0.15, 0.18, 0.26, { hex("#6E9A5C"), hex("#8DB37A"), hex("#5B7F4E") })
		end
	end,
})

add({
	id = "divider_planter",
	category = "office",
	footprint = V(8.1, 3.7, 1.8),
	maxParts = 30,
	tags = { "plant", "divider" },
	scales = { width = 24 },
	build = function(c: Ctx)
		local W = c.num("width", 8, 3, 24)
		c.part(P(0, 1.0, 0), V(W, 2.0, 1.6), c.color("color", hex("#2E3033")), M.Plaster)
		c.detail(P(0, 2.04, 0), V(W + 0.1, 0.08, 1.7), c.color("accent", S.oak), M.Wood)
		c.detail(P(0, 2.1, 0), V(W - 0.3, 0.04, 1.3), col.soil, M.Ground)
		local n = math.clamp(math.floor(W / 1.4), 2, 16)
		for i = 1, n do
			local x = -W / 2 + W * (i - 0.5) / n
			local d = c.rng:range(1.3, 1.75)
			c.dball(P(x, 2.12 + d * 0.35, c.rng:range(-0.1, 0.1)), d, c.rng:pick({ col.leaf, col.leafDark, col.leafLight }), M.Grass)
		end
		Shapes.blades(c, P(-W / 4, 2.12, 0), 4, 1.5, 0.12, col.leafLight, 18)
		Shapes.blades(c, P(W / 4, 2.12, 0), 4, 1.5, 0.12, col.leafLight, 18)
	end,
})

---------------------------------------------------------------------------------------------------
-- trophy_shelf: walnut etagere with glass shelves of lucite deal toys and a gold cup on top
---------------------------------------------------------------------------------------------------
add({
	id = "trophy_shelf",
	category = "office",
	footprint = V(4.5, 6.0, 1.2),
	maxParts = 40,
	tags = { "storage", "furniture", "trophy" },
	build = function(c: Ctx)
		local f = Common.finish(c.int("tier", 3, 1, 4))
		local wood = c.color("color", f.wood)
		local W, Hh, D = 4.5, 6, 1.2
		for _, sx in { -1, 1 } do
			c.part(P(sx * (W / 2 - 0.1), Hh / 2, 0), V(0.2, Hh, D), wood, f.woodMat)
		end
		c.part(P(0, Hh - 0.1, 0), V(W, 0.2, D), wood, f.woodMat)
		c.part(P(0, 0.2, 0), V(W - 0.4, 0.4, D), shade(wood, -0.2), f.woodMat)
		c.detail(P(0, Hh / 2, D / 2 - 0.04), V(W - 0.4, Hh - 0.4, 0.06), shade(wood, -0.4), f.woodMat)
		local levels = { 0.4, 1.75, 3.1, 4.45 }
		for i = 2, 4 do
			c.glass(P(0, levels[i] - 0.04, 0), V(W - 0.4, 0.08, D - 0.1), hex("#CFE3EA"), 0.45)
		end
		local styles = { "tombstone", "cube" }
		local deals = c.rng:shuffle(Words.deals)
		local k = 0
		for i = 1, 3 do
			for j = -1, 1 do
				k += 1
				Shapes.tombstone(
					c,
					P(j * 1.25 + c.rng:range(-0.1, 0.1), levels[i], c.rng:range(-0.15, 0.1)) * R(0, c.rng:range(-10, 10), 0),
					c.rng:pick(styles),
					deals[(k - 1) % #deals + 1],
					f.wood
				)
			end
		end
		-- gold cup on the top shelf
		local gold = c.color("accent", S.gold)
		local y = levels[4]
		c.detail(P(0, y + 0.12, 0), V(0.6, 0.24, 0.6), col.ebony, M.Wood)
		c.dcyl(P(0, y + 0.45, 0), 0.42, 0.14, gold, M.Metal)
		c.dcyl(P(0, y + 0.9, 0), 0.5, 0.6, gold, M.Metal)
	end,
})

return defs
