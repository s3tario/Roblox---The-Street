--!strict
-- Executive Club bar pieces (category "lux"): bar counter, bar stool, wine rack, cigar humidor and
-- velvet rope. Walnut, brass, marble and leather.

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

local LACQUER = hex("#0E0E10")
local IVORY = hex("#F3EEDF")
local CEDAR = hex("#B5764A")

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

---------------------------------------------------------------------------------------------------
-- bar_counter: walnut bar with raised panels, a marble top, leather arm rail, brass foot rail, a tap tower
-- and a back speed rail of bottles. Guests stand at -Z; the bartender works at +Z. opts.length (4-30).
---------------------------------------------------------------------------------------------------
add({
	id = "bar_counter",
	category = "lux",
	footprint = V(12.2, 4.75, 3.5),
	offset = V(0, 0, -0.18),
	maxParts = 52,
	tags = { "bar", "counter", "furniture" },
	surface = 3.6,
	scales = { length = 30 },
	build = function(c: Ctx)
		local L = c.num("length", 12, 4, 30)
		local wood = c.color("color", S.walnut)
		local brass = c.color("accent", S.brass)
		local H, D = 3.6, 2.6
		c.part(P(0, 0.2, 0.2), V(L - 0.3, 0.4, 1.6), shade(wood, -0.45), M.Wood)
		c.part(P(0, (0.4 + H - 0.15) / 2, 0.1), V(L, H - 0.55, D - 0.6), wood, M.Wood)
		local n = math.max(2, math.floor(L / 2))
		local pw = (L - 0.4) / n
		for i = 1, n do
			c.detail(P(-L / 2 + 0.2 + pw * (i - 0.5), 1.75, -0.93), V(pw - 0.35, 2.0, 0.06), shade(wood, 0.1), M.Wood)
		end
		c.part(P(0, H - 0.075, -0.05), V(L + 0.2, 0.15, D), c.color("top", S.marble), M.Marble)
		c.dcylX(P(0, H - 0.08, -D / 2 - 0.08), L + 0.2, 0.32, col.leatherBrown, M.Leather)
		c.dcylX(P(0, 0.75, -D / 2 - 0.5), L - 0.6, 0.22, brass, M.Metal)
		local nb = math.floor(L / 3) + 1
		for i = 0, nb - 1 do
			local x = -L / 2 + 0.6 + (L - 1.2) * i / math.max(nb - 1, 1)
			c.dcylZ(P(x, 0.75, -D / 2 - 0.3), 0.45, 0.12, brass, M.Metal)
		end
		-- bartender side: speed rail with bottles, tap tower
		c.detail(P(0, 2.6, 1.3), V(L - 0.6, 0.1, 0.5), S.steelBrushed, M.Metal)
		local bottleColors = { hex("#2F5A3A"), hex("#6E1A1F"), hex("#C9A54C"), hex("#D9E4E8") }
		for i = 1, 4 do
			Shapes.bottle(c, P(-L / 2 + 1 + i * 0.5, 2.65, 1.3), 1.1, 0.3, bottleColors[i], true)
		end
		c.detail(P(L / 4, H + 0.5, 0.45), V(0.3, 1.0, 0.3), brass, M.Metal)
		for i = -1, 1 do
			c.dcyl(P(L / 4 + i * 0.35, H + 0.85, 0.2), 0.6, 0.12, if i == 0 then S.walnut else col.plasticBlack, M.Wood)
		end
		c.glow(P(0, H - 0.2, -1.0), V(L - 0.4, 0.04, 0.05), S.warmLight, 0.2)
		c.use(V(0, 3.8, -D / 2 - 0.6))
	end,
})

---------------------------------------------------------------------------------------------------
-- bar_stool: brass and leather counter stool with a low back (hidden Seat pad when opts.seat)
---------------------------------------------------------------------------------------------------
add({
	id = "bar_stool",
	category = "lux",
	footprint = V(1.75, 4.0, 1.75),
	maxParts = 16,
	tags = { "chair", "seat", "bar" },
	build = function(c: Ctx)
		local leather = c.color("color", col.leatherBlack)
		local metal = c.color("accent", S.brass)
		c.dcyl(P(0, 0.05, 0), 0.1, 1.5, LACQUER, M.Metal)
		c.cyl(P(0, 1.45, 0), 2.7, 0.22, metal, M.Metal)
		-- square foot ring on a cross brace
		for _, sx in { -1, 1 } do
			c.dcylZ(P(sx * 0.55, 1.1, 0), 1.18, 0.08, metal, M.Metal)
			c.dcylX(P(0, 1.1, sx * 0.55), 1.18, 0.08, metal, M.Metal)
		end
		c.dcylX(P(0, 1.1, 0), 1.1, 0.06, metal, M.Metal)
		c.dcylZ(P(0, 1.1, 0), 1.1, 0.06, metal, M.Metal)
		c.dcyl(P(0, 2.82, 0), 0.06, 1.75, metal, M.Metal)
		c.dcyl(P(0, 3.0, 0), 0.4, 1.7, leather, M.Leather)
		local pad = c.seat(P(0, 3.08, 0), V(1.2, 0.2, 1.2), leather, M.Leather)
		pad.Transparency = 1
		pad.Name = "SeatPad"
		c.detail(P(0, 3.7, 0.72) * R(8, 0, 0), V(1.3, 0.6, 0.14), leather, M.Leather)
		for _, sx in { -1, 1 } do
			Shapes.strut(c, V(sx * 0.5, 3.1, 0.62), V(sx * 0.5, 3.5, 0.74), 0.08, metal, M.Metal)
		end
		c.use(V(0, 3, 0))
	end,
})

---------------------------------------------------------------------------------------------------
-- wine_rack: walnut rack (back against the wall at +Z) with five rows of bottle ends, three bottles
-- pulled forward and a warm strip light under the crown
---------------------------------------------------------------------------------------------------
add({
	id = "wine_rack",
	category = "lux",
	footprint = V(4.4, 7.35, 2.05),
	offset = V(0, 0, -0.15),
	maxParts = 28,
	tags = { "storage", "bar", "furniture" },
	build = function(c: Ctx)
		local W, H, D = 4.2, 7.2, 1.6
		local wood = c.color("color", S.walnut)
		for _, sx in { -1, 1 } do
			c.part(P(sx * (W / 2 - 0.1), H / 2, 0), V(0.2, H, D), wood, M.Wood)
		end
		c.part(P(0, H - 0.1, 0), V(W, 0.2, D), wood, M.Wood)
		c.detail(P(0, H + 0.075, 0), V(W + 0.2, 0.15, D + 0.1), shade(wood, -0.15), M.Wood)
		c.part(P(0, 0.2, 0), V(W, 0.4, D), shade(wood, -0.25), M.Wood)
		c.detail(P(0, H / 2, D / 2 - 0.03), V(W - 0.4, H - 0.6, 0.06), shade(wood, -0.35), M.Wood)
		local wines = { hex("#1F3A24"), hex("#3A0F14"), hex("#24301E"), hex("#4A1A20") }
		local foil = { hex("#C9A54C"), hex("#7A1F24"), hex("#1A1A1A"), hex("#D9D2C3") }
		for row = 0, 4 do
			local y = 0.4 + row * 1.32
			c.detail(P(0, y + 0.04, 0), V(W - 0.4, 0.08, D - 0.1), shade(wood, 0.05), M.Wood)
			local panel = c.detail(P(0, y + 0.66, -D / 2 + 0.35), V(W - 0.4, 1.1, 0.04), hex("#120D0A"), M.Wood)
			local gui, gw, gh = Gui.Core.surface(panel, Enum.NormalId.Front, { pps = 40, maxDistance = 45 })
			for r = 0, 1 do
				for k = 0, 6 do
					local cx, cy = (k + 0.5) / 7 * gw, (r + 0.5) / 2 * gh
					Gui.Core.dot(gui, cx, cy, gh * 0.42, c.rng:pick(wines))
					Gui.Core.dot(gui, cx, cy, gh * 0.16, c.rng:pick(foil))
				end
			end
		end
		for i = 1, 3 do
			local row = c.rng:int(0, 4)
			local x = -1.4 + (i - 1) * 1.4 + c.rng:range(-0.2, 0.2)
			local y = 0.4 + row * 1.32 + 0.66
			local glassC = c.rng:pick(wines)
			c.dcylZ(P(x, y, -D / 2 + 0.05), 0.9, 0.36, glassC, M.Glass).Transparency = 0.1
			c.dcylZ(P(x, y, -D / 2 - 0.12), 0.35, 0.15, c.rng:pick(foil), M.Metal)
		end
		c.glow(P(0, H - 0.24, -D / 2 + 0.25), V(W - 0.5, 0.04, 0.06), S.warmLight, 0.2)
	end,
})

---------------------------------------------------------------------------------------------------
-- cigar_humidor: cherry display cabinet with glass doors, cedar lining, shelves of cigar boxes, a
-- hygrometer and a warm interior light. Back against the wall at +Z.
---------------------------------------------------------------------------------------------------
add({
	id = "cigar_humidor",
	category = "lux",
	footprint = V(3.2, 6.25, 1.85),
	maxParts = 28,
	tags = { "storage", "display", "furniture" },
	build = function(c: Ctx)
		local W, D = 3, 1.7
		local wood = c.color("color", col.cherry)
		local brass = c.color("accent", S.brass)
		c.detail(P(0, 0.2, 0), V(W - 0.1, 0.4, D - 0.1), shade(wood, -0.4), M.Wood)
		c.part(P(0, 0.5, 0), V(W, 0.2, D), wood, M.Wood)
		c.part(P(0, 6.0, 0), V(W, 0.2, D), wood, M.Wood)
		c.detail(P(0, 6.175, 0), V(W + 0.2, 0.15, D + 0.15), shade(wood, -0.15), M.Wood)
		c.part(P(0, 3.25, D / 2 - 0.1), V(W, 5.3, 0.2), wood, M.Wood)
		for _, sx in { -1, 1 } do
			c.part(P(sx * (W / 2 - 0.1), 3.25, 0), V(0.2, 5.3, D), wood, M.Wood)
		end
		c.detail(P(0, 3.25, D / 2 - 0.22), V(W - 0.4, 5.3, 0.04), CEDAR, M.Wood)
		local boxColors = { hex("#6B3A1E"), hex("#7A1F24"), hex("#1A1A1A"), hex("#C9A54C"), hex("#3D2A1C") }
		for i, y in { 0.6, 2.0, 3.4 } do
			if i > 1 then
				c.detail(P(0, y - 0.04, 0.05), V(W - 0.4, 0.08, D - 0.4), CEDAR, M.Wood)
			end
			for _, sx in { -1, 1 } do
				c.detail(
					P(sx * 0.6 + c.rng:range(-0.05, 0.05), y + 0.2, 0.1),
					V(1.0, 0.35, 0.8),
					c.rng:pick(boxColors),
					M.Wood
				)
			end
		end
		c.detail(P(0, 4.76, 0.05), V(W - 0.4, 0.08, D - 0.4), CEDAR, M.Wood)
		local dial = c.detail(P(0, 5.35, D / 2 - 0.26), V(0.6, 0.6, 0.04), brass, M.Metal)
		local dg, dw, dh = Gui.Core.surface(dial, Enum.NormalId.Front, { pps = 100, maxDistance = 25 })
		Gui.Core.dot(dg, dw / 2, dh / 2, dw * 0.86, IVORY)
		Gui.Core.label(dg, Words.humidor, 0.2, 0.55, 0.6, 0.2, hex("#2A1C14"), {
			font = Enum.Font.Garamond,
			align = Enum.TextXAlignment.Center,
		})
		Gui.Core.line(dg, dw / 2, dh / 2, dw * 0.72, dh * 0.3, 3, hex("#7A1F24"))
		for _, sx in { -1, 1 } do
			c.glass(P(sx * 0.65, 3.25, -D / 2 + 0.03), V(1.3, 5.3, 0.05), hex("#E6EEF0"), 0.7, true)
			c.detail(P(sx * 0.14, 3.3, -D / 2 - 0.04), V(0.06, 0.5, 0.06), brass, M.Metal)
		end
		c.detail(P(0, 3.25, -D / 2 + 0.03), V(0.1, 5.3, 0.08), wood, M.Wood)
		local lamp = c.glow(P(0, 5.86, 0), V(W - 0.5, 0.04, 0.1), S.warmLight, 0.2)
		Shapes.lamp(lamp, c.bool("lit", true), S.warmLight, 6, 0.6)
		c.use(V(0, 3.5, -D / 2 - 0.8))
	end,
})

---------------------------------------------------------------------------------------------------
-- velvet_rope: two brass stanchions with a red velvet rope sagging between them. opts.length = gap (2-16).
---------------------------------------------------------------------------------------------------
add({
	id = "velvet_rope",
	category = "lux",
	footprint = V(7.1, 3.2, 1.1),
	maxParts = 16,
	tags = { "barrier", "vip" },
	build = function(c: Ctx)
		local gap = c.num("length", 6, 2, 16)
		local brass = c.color("accent", S.brass)
		local rope = c.color("color", col.velvetRed)
		for _, sx in { -1, 1 } do
			local x = sx * gap / 2
			c.dcyl(P(x, 0.06, 0), 0.12, 1.1, brass, M.Metal)
			c.dcyl(P(x, 0.2, 0), 0.16, 0.8, brass, M.Metal)
			c.cyl(P(x, 1.6, 0), 2.6, 0.18, brass, M.Metal)
			c.dball(P(x, 3.0, 0), 0.38, brass, M.Metal)
			c.dcylX(P(x - sx * 0.14, 2.75, 0), 0.12, 0.26, brass, M.Metal)
		end
		Shapes.rope(
			c,
			V(-gap / 2 + 0.2, 2.75, 0),
			V(gap / 2 - 0.2, 2.75, 0),
			math.min(0.9, gap * 0.1),
			4,
			0.22,
			rope,
			M.Fabric
		)
	end,
})

return defs
