--!strict
-- Retail fixtures (category "retail") for Hartwell Tailors, Vanta Watches, Strider Shoes and the Galleria:
-- clothing rack, display table, abstract mannequin stand, shoe wall, watch case, cash counter, cheval mirror
-- and shopping bag. Customers stand at -Z.

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

-- Tasteful garment colours used when opts.colors is not given.
local GARMENTS = {
	hex("#1B2A44"),
	hex("#3A3D42"),
	hex("#8A7A66"),
	hex("#F2F0EA"),
	hex("#6E1A1F"),
	hex("#4A5A3A"),
	hex("#B9AD98"),
	hex("#2B2B2B"),
	hex("#7FA7D9"),
}

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

---------------------------------------------------------------------------------------------------
-- clothing_rack: chrome rolling rack with opts.count (3-12, default 8) garments on hangers.
-- opts.colors = list of Color3 / "#RRGGBB" strings, cycled across the garments.
---------------------------------------------------------------------------------------------------
add({
	id = "clothing_rack",
	category = "retail",
	footprint = V(5.3, 5.55, 2.3),
	maxParts = 36,
	tags = { "retail", "display", "clothing" },
	scales = { count = 12 },
	build = function(c: Ctx)
		local L = 5
		local n = c.int("count", 8, 3, 12)
		local chrome = c.color("accent", col.chrome)
		local colors = c.colors("colors", c.rng:shuffle(GARMENTS))
		for _, sx in { -1, 1 } do
			local x = sx * L / 2
			c.detail(P(x, 0.25, 0), V(0.2, 0.15, 2.2), chrome, M.Metal)
			for _, sz in { -1, 1 } do
				c.dball(P(x, 0.15, sz * 1.0), 0.3, col.rubber, M.Rubber)
			end
			c.cyl(P(x, 2.95, 0), 5.2, 0.2, chrome, M.Metal)
		end
		c.dcylX(P(0, 5.45, 0), L + 0.3, 0.16, chrome, M.Metal)
		local span = L - 0.8
		for i = 1, n do
			local x = -span / 2 + span * (i - 1) / math.max(n - 1, 1)
			local yaw = c.rng:range(-8, 8)
			local long = c.rng:chance(0.35)
			local h = if long then 3.3 else 2.5
			local g = colors[(i - 1) % #colors + 1]
			c.detail(P(x, 5.25, 0) * R(0, yaw, 0), V(0.06, 0.08, 1.5), hex("#5A3A26"), M.Wood)
			c.detail(P(x, 5.2 - h / 2, 0) * R(0, yaw, 0), V(0.22, h, 1.55), g, M.Fabric)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- display_table: walnut nesting table on white plinths with stacks of folded shirts and a small sign
---------------------------------------------------------------------------------------------------
add({
	id = "display_table",
	category = "retail",
	footprint = V(6.0, 3.6, 3.4),
	maxParts = 20,
	tags = { "retail", "display", "table", "clothing" },
	surface = 3.0,
	build = function(c: Ctx)
		local wood = c.color("color", S.walnut)
		local base = c.color("accent", S.white)
		local colors = c.colors("colors", c.rng:shuffle(GARMENTS))
		c.part(P(0, 2.9, 0), V(6, 0.2, 3.4), wood, M.Wood)
		for _, sx in { -1, 1 } do
			c.part(P(sx * 2.0, 1.4, 0), V(1.4, 2.8, 2.6), base, M.SmoothPlastic)
		end
		for i, x in { -2.1, -0.7, 0.7, 2.1 } do
			local g = colors[(i - 1) % #colors + 1]
			for k = 0, 2 do
				local shirt = c.detail(
					P(x + c.rng:range(-0.05, 0.05), 3.09 + k * 0.19, -0.3 + c.rng:range(-0.05, 0.05))
						* R(0, c.rng:range(-4, 4), 0),
					V(1.0, 0.18, 1.2),
					shade(g, k * 0.04),
					M.Fabric
				)
				if k == 2 then
					-- collar on the top shirt (centred, so it reads the same from either side)
					local gui = Gui.Core.surface(shirt, Enum.NormalId.Top, { pps = 60, maxDistance = 30 })
					local collar = Gui.Core.frame(gui, 0.3, 0.06, 0.4, 0.16, shade(g, 0.25))
					Gui.Core.round(collar, 0.4)
					Gui.Core.frame(gui, 0.49, 0.2, 0.02, 0.7, shade(g, -0.2), 0.4)
				end
			end
		end
		local sign = c.detail(P(0, 3.25, 1.0) * R(-12, 0, 0), V(1.0, 0.5, 0.04), S.white, M.Glass)
		c.sign(
			sign,
			Words.newSeason,
			{ font = Enum.Font.Garamond, color = S.black, pixelsPerStud = 80, padding = 0.08 }
		)
		c.use(V(0, 3.2, -2))
	end,
})

---------------------------------------------------------------------------------------------------
-- mannequin_stand: abstract dress form (hips, waist, chest, shoulder bar, egg head) on a chrome pole.
-- The wardrobe feature builds dressed mannequins; this is the bare display form.
---------------------------------------------------------------------------------------------------
add({
	id = "mannequin_stand",
	category = "retail",
	footprint = V(2.0, 6.8, 1.8),
	maxParts = 10,
	tags = { "retail", "display", "clothing" },
	build = function(c: Ctx)
		local form = c.color("color", hex("#E8E4DC"))
		local metal = c.color("accent", col.chrome)
		c.dcyl(P(0, 0.06, 0), 0.12, 1.8, col.plasticBlack, M.Metal)
		c.cyl(P(0, 1.6, 0), 3.0, 0.14, metal, M.Metal)
		c.part(P(0, 3.4, 0), V(1.5, 0.8, 0.85), form, M.SmoothPlastic)
		c.detail(P(0, 4.0, 0), V(1.25, 0.6, 0.75), form, M.SmoothPlastic)
		c.part(P(0, 4.8, 0), V(1.7, 1.2, 0.9), form, M.SmoothPlastic)
		c.dcylX(P(0, 5.35, 0), 2.0, 0.6, form, M.SmoothPlastic)
		c.dcyl(P(0, 5.8, 0), 0.45, 0.35, form, M.SmoothPlastic)
		c.dball(P(0, 6.37, 0), 0.85, form, M.SmoothPlastic)
		c.use(V(0, 4, -1))
	end,
})

---------------------------------------------------------------------------------------------------
-- shoe_wall (mount "wall"): backlit panel with five glass shelves of seeded dress shoes and sneakers
---------------------------------------------------------------------------------------------------
local LEATHERS = { hex("#1A1614"), hex("#4A2F22"), hex("#8A4F2A"), hex("#5A1E1E") }
local SNEAKERS = { hex("#F2F2EE"), hex("#3A3D42"), hex("#1B2A44"), hex("#C0392B") }

add({
	id = "shoe_wall",
	category = "retail",
	footprint = V(8.2, 8.0, 1.31),
	maxParts = 46,
	tags = { "retail", "display", "wall", "shoes" },
	mount = "wall",
	build = function(c: Ctx)
		local W, H = 8, 8
		local panel = c.color("color", hex("#F4F1EA"))
		local trim = c.color("accent", S.walnut)
		c.part(P(0, H / 2, -0.1), V(W, H, 0.2), panel, M.SmoothPlastic)
		c.detail(P(0, H - 0.1, -0.15), V(W + 0.2, 0.2, 0.3), trim, M.Wood)
		for row = 0, 4 do
			local y = 1.4 + row * 1.5
			local shelf = c.detail(P(0, y, -0.75), V(W - 0.4, 0.08, 1.1), hex("#EAF4FA"), M.Glass)
			shelf.Transparency = 0.35
			c.glow(P(0, y - 0.07, -0.25), V(W - 0.6, 0.04, 0.08), S.warmLight, 0.25)
			for k = 0, 2 do
				local x = -2.6 + k * 2.6 + c.rng:range(-0.2, 0.2)
				local sneaker = c.rng:chance(0.4)
				local upper = if sneaker then c.rng:pick(SNEAKERS) else c.rng:pick(LEATHERS)
				local yaw = c.rng:range(-25, 25)
				local base = P(x, y + 0.04, -0.75) * R(0, yaw, 0)
				c.detail(
					base * P(0, 0.05, 0),
					V(0.5, 0.1, 1.0),
					if sneaker then S.white else shade(upper, -0.3),
					M.Rubber
				)
				c.dwedge(
					base * P(0, 0.1 + 0.19, 0.05),
					V(0.45, 0.38, 0.9),
					upper,
					if sneaker then M.Fabric else M.Leather
				)
			end
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- watch_case: walnut display counter with a glass case of six watches on navy velvet and a light strip
---------------------------------------------------------------------------------------------------
local CASES = { S.gold, S.steelBrushed, hex("#C9967A"), hex("#2B2B2B") }
local DIALS = { hex("#F7F6F2"), hex("#0B1F3A"), hex("#121417"), hex("#1F4D3A") }
local STRAPS = { col.leatherBlack, col.leatherBrown, col.leatherCognac, S.steelBrushed }

add({
	id = "watch_case",
	category = "retail",
	footprint = V(5.1, 4.11, 2.3),
	maxParts = 30,
	tags = { "retail", "display", "counter", "watches" },
	surface = 4.08,
	build = function(c: Ctx)
		local wood = c.color("color", S.walnut)
		local brass = c.color("accent", S.brass)
		c.part(P(0, 1.45, 0), V(5, 2.9, 2.2), wood, M.Wood)
		c.detail(P(0, 1.55, -1.12), V(4.6, 2.0, 0.05), shade(wood, 0.1), M.Wood)
		c.detail(P(0, 2.95, 0), V(5.1, 0.1, 2.3), brass, M.Metal)
		c.detail(P(0, 3.04, 0), V(4.7, 0.08, 1.9), hex("#14213D"), M.Fabric)
		c.glass(P(0, 3.55, 0), V(4.8, 1.0, 2.0), hex("#EAF4FA"), 0.8, true)
		-- brass rim around the glass lid (the lid itself stays clear)
		for _, sz in { -1, 1 } do
			c.detail(P(0, 4.08, sz * 1.02), V(4.9, 0.06, 0.08), brass, M.Metal)
			c.detail(P(sz * 2.42, 4.08, 0), V(0.08, 0.06, 2.1), brass, M.Metal)
		end
		local strip = c.glow(P(0, 3.98, 0.85), V(4.5, 0.04, 0.1), S.warmLight, 0.2)
		Shapes.lamp(strip, c.bool("lit", true), S.warmLight, 6, 0.7)
		for row = 0, 1 do
			for k = 0, 2 do
				local x, z = -1.5 + k * 1.5, -0.45 + row * 0.9
				local base = P(x, 3.08, z) * R(0, c.rng:range(-12, 12), 0)
				c.detail(base * P(0, 0.03, 0), V(0.26, 0.05, 0.85), c.rng:pick(STRAPS), M.Leather)
				c.dcyl(base * P(0, 0.1, 0), 0.1, 0.42, c.rng:pick(CASES), M.Metal)
				c.dcyl(base * P(0, 0.16, 0), 0.02, 0.32, c.rng:pick(DIALS), M.SmoothPlastic)
			end
		end
		c.use(V(0, 3.5, -1.8))
	end,
})

---------------------------------------------------------------------------------------------------
-- cash_counter: walnut counter with a marble top, brass band and logo plate (opts.text), a POS terminal
-- facing the clerk (+Z), a card reader for the customer, a receipt printer and a shopping bag.
---------------------------------------------------------------------------------------------------
add({
	id = "cash_counter",
	category = "retail",
	footprint = V(8.3, 5.6, 2.7),
	maxParts = 28,
	tags = { "retail", "counter", "shop" },
	surface = 3.55,
	build = function(c: Ctx)
		local wood = c.color("color", S.walnut)
		local brass = c.color("accent", S.brass)
		c.detail(P(0, 0.15, 0.25), V(7.8, 0.3, 2.2), shade(wood, -0.45), M.Wood)
		c.part(P(0, 1.85, 0.15), V(8, 3.1, 2.4), wood, M.Wood)
		c.part(P(0, 3.475, 0.05), V(8.3, 0.15, 2.7), S.marble, M.Marble)
		c.detail(P(0, 2.8, -1.07), V(8, 0.1, 0.04), brass, M.Metal)
		local logo = c.detail(P(0, 1.9, -1.08), V(3.2, 1.0, 0.05), S.navy, M.SmoothPlastic)
		c.sign(logo, c.str("text", c.rng:pick(Words.retailBrands), 40), {
			font = Enum.Font.Bodoni,
			color = S.goldBright,
			pixelsPerStud = 50,
			padding = 0.1,
		})
		-- POS terminal turned toward the clerk
		local px = -1.6
		c.detail(P(px, 3.62, 0.4), V(0.7, 0.14, 0.55), col.plasticBlack, M.SmoothPlastic)
		c.detail(P(px, 3.95, 0.45), V(0.14, 0.6, 0.14), col.plasticGrey, M.Metal)
		local posCf = P(px, 4.5, 0.4) * R(0, 180, 0) * R(-12, 0, 0)
		c.detail(posCf, V(1.5, 1.0, 0.1), col.plasticBlack, M.SmoothPlastic)
		local screen = c.detail(posCf * P(0, 0, -0.055), V(1.36, 0.86, 0.02), hex("#0B1622"), M.Glass)
		local gui = Gui.Core.surface(screen, Enum.NormalId.Front, { glow = true, pps = 80, maxDistance = 30 })
		Gui.Core.bg(gui, hex("#F7F8FA"))
		Gui.Core.frame(gui, 0, 0, 1, 0.2, S.navy)
		Gui.Core.label(gui, Words.posTotal, 0.06, 0.3, 0.4, 0.25, hex("#4A5260"), { font = Enum.Font.GothamBold })
		Gui.Core.label(gui, string.format("$%d.00", c.rng:int(120, 4800)), 0.4, 0.28, 0.55, 0.3, S.navy, {
			font = Enum.Font.RobotoMono,
			align = Enum.TextXAlignment.Right,
		})
		Gui.Core.frame(gui, 0.06, 0.7, 0.4, 0.18, hex("#2BD67B"))
		-- customer card reader and receipt printer
		c.detail(P(0.6, 3.66, -0.9) * R(25, 0, 0), V(0.4, 0.14, 0.6), col.plasticBlack, M.SmoothPlastic)
		c.glow(P(0.6, 3.75, -0.95) * R(25, 0, 0), V(0.26, 0.02, 0.2), hex("#7FD1FF"), 0.2)
		c.detail(P(-0.4, 3.7, 0.6), V(0.5, 0.3, 0.55), col.plasticWhite, M.SmoothPlastic)
		c.sub("shopping_bag", P(2.9, 3.55, 0.5) * R(0, c.rng:range(-20, 20), 0))
		c.use(V(0, 3.8, -1.8))
	end,
})

---------------------------------------------------------------------------------------------------
-- mirror_full: cheval mirror with a gilt frame tilting between walnut uprights. The glass is a reflective
-- part named "Mirror".
---------------------------------------------------------------------------------------------------
add({
	id = "mirror_full",
	category = "retail",
	footprint = V(2.8, 6.0, 1.5),
	maxParts = 14,
	tags = { "retail", "mirror", "furniture" },
	build = function(c: Ctx)
		local frame = c.color("color", S.gold)
		local wood = c.color("accent", S.walnut)
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 1.25, 0.075, 0), V(0.25, 0.15, 1.5), wood, M.Wood)
			c.part(P(sx * 1.25, 2.95, 0), V(0.2, 5.6, 0.2), wood, M.Wood)
			c.dball(P(sx * 1.25, 5.85, 0), 0.3, frame, M.Metal)
		end
		local tilt = P(0, 3.15, 0) * R(6, 0, 0)
		local mirror = c.part(tilt, V(1.9, 5.0, 0.05), hex("#DDE3E8"), M.Glass)
		mirror.Name = "Mirror"
		mirror.Reflectance = 0.65
		mirror.Transparency = 0
		c.detail(tilt * P(0, 0, 0.06), V(2.0, 5.1, 0.06), shade(wood, -0.3), M.Wood)
		Shapes.frameRect(c, tilt * P(0, 0, -0.02), 1.9, 5.0, 0.14, 0.12, frame, M.Metal)
	end,
})

---------------------------------------------------------------------------------------------------
-- shopping_bag: paper boutique bag with rope handles, tissue paper and a brand (opts.text, else seeded)
---------------------------------------------------------------------------------------------------
local BAG_COLORS = { S.navy, hex("#F4F1EA"), hex("#121417"), hex("#7A1F24"), hex("#1F4D3A") }

add({
	id = "shopping_bag",
	category = "retail",
	footprint = V(1.32, 2.06, 0.62),
	maxParts = 10,
	tags = { "retail", "decor", "desk_item" },
	build = function(c: Ctx)
		local W, H, D = 1.3, 1.6, 0.6
		local bag = c.color("color", c.rng:pick(BAG_COLORS))
		local ink = if bag.R + bag.G + bag.B > 1.8 then S.navy else S.goldBright
		local body = c.detail(P(0, H / 2, 0), V(W, H, D), bag, M.SmoothPlastic)
		body.Name = "Bag"
		local brand = c.str("text", c.rng:pick(Words.retailBrands), 30)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			c.sign(
				body,
				brand,
				{ face = face, font = Enum.Font.Bodoni, color = ink, pixelsPerStud = 80, padding = 0.18 }
			)
		end
		c.detail(P(0, H - 0.06, 0), V(W + 0.02, 0.12, D + 0.02), shade(bag, -0.15), M.SmoothPlastic)
		for _, sz in { -1, 1 } do
			local z = sz * (D / 2 - 0.08)
			Shapes.tube(c, V(-0.32, H, z), V(0, H + 0.45, z), 0.05, ink, M.Fabric)
			Shapes.tube(c, V(0, H + 0.45, z), V(0.32, H, z), 0.05, ink, M.Fabric)
		end
		local tissue = c.rng:pick({ hex("#F7F6F2"), hex("#F2D7DE"), hex("#DCEBF0") })
		c.dwedge(P(-0.2, H + 0.12, 0) * R(0, 20, 8), V(0.6, 0.3, 0.4), tissue, M.SmoothPlastic)
		c.dwedge(P(0.22, H + 0.1, 0) * R(0, 200, -6), V(0.5, 0.26, 0.36), tissue, M.SmoothPlastic)
	end,
})

return defs
