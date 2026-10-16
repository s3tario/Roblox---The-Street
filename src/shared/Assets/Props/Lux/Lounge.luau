--!strict
-- Luxury lounge pieces (category "lux"): chandelier, chesterfield, fireplace, pool table, grand
-- piano, art pedestal and lounge chair.

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

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

---------------------------------------------------------------------------------------------------
-- chandelier (mount "ceiling"): gilt column with opts.arms (5-8, default 6) candle arms, crystal drops and
-- a warm PointLight on the column (tagged "InteriorLight") when opts.lit (default true). cf = lowest point;
-- the canopy reaches opts.drop (3-12, default 5) studs up to the ceiling.
---------------------------------------------------------------------------------------------------
add({
	id = "chandelier",
	category = "lux",
	footprint = V(4.6, 5.0, 4.05),
	maxParts = 50,
	tags = { "light", "lamp", "ceiling" },
	mount = "ceiling",
	scales = { arms = 8, drop = 12 },
	build = function(c: Ctx)
		local gold = c.color("color", S.gold)
		local lit = c.bool("lit", true)
		local arms = c.int("arms", 6, 5, 8)
		local drop = c.num("drop", 5, 3, 12)
		local crystal = hex("#EAF4FA")
		c.dcyl(P(0, drop - 0.1, 0), 0.2, 1.0, gold, M.Metal)
		local rodLen = drop - 0.2 - 3.4
		c.dcyl(P(0, 3.4 + rodLen / 2, 0), rodLen, 0.12, gold, M.Metal)
		c.dcyl(P(0, 3.0, 0), 0.8, 0.25, gold, M.Metal)
		c.dball(P(0, 2.5, 0), 0.7, gold, M.Metal)
		local column = c.dcyl(P(0, 1.4, 0), 1.8, 0.4, gold, M.Metal)
		column.Name = "Column"
		c.tag(column, "InteriorLight")
		Shapes.lamp(column, lit, S.warmLight, 24, 1.3)
		c.dcyl(P(0, 1.4, 0), 0.2, 1.4, gold, M.Metal)
		c.dball(P(0, 0.3, 0), 0.6, gold, M.Metal)
		for k = 0, arms - 1 do
			local a = math.rad(k * 360 / arms)
			local ca, sa = math.cos(a), math.sin(a)
			local tip = V(ca * 2.1, 1.85, sa * 2.1)
			Shapes.tube(c, V(ca * 0.2, 1.3, sa * 0.2), tip, 0.1, gold, M.Metal)
			c.dcyl(P(tip.X, tip.Y + 0.07, tip.Z), 0.14, 0.4, gold, M.Metal)
			c.dcyl(P(tip.X, tip.Y + 0.36, tip.Z), 0.45, 0.16, IVORY, M.SmoothPlastic)
			Shapes.bulb(c, P(tip.X, tip.Y + 0.68, tip.Z), 0.22, S.warmLight, lit)
			local b = a + math.pi / arms
			local drip = c.dball(P(math.cos(b) * 1.25, 0.95, math.sin(b) * 1.25), 0.3, crystal, M.Glass)
			drip.Transparency = 0.3
			drip.Reflectance = 0.3
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- leather_sofa: deep-buttoned chesterfield with rolled arms, bun feet and brass nailhead trim
---------------------------------------------------------------------------------------------------
add({
	id = "leather_sofa",
	category = "lux",
	footprint = V(8.25, 3.4, 3.4),
	maxParts = 18,
	tags = { "sofa", "seat", "furniture" },
	build = function(c: Ctx)
		local W, D = 8, 3.4
		local leather = c.color("color", col.oxblood)
		local feet = c.color("accent", col.ebony)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				c.dcyl(P(sx * (W / 2 - 0.45), 0.15, sz * (D / 2 - 0.4)), 0.3, 0.4, feet, M.Wood)
			end
		end
		local base = c.part(P(0, 0.8, 0), V(W, 1.0, D), leather, M.Leather)
		local nails = Gui.Core.surface(base, Enum.NormalId.Front, { pps = 30, maxDistance = 40 })
		for i = 0, 39 do
			Gui.Core.dot(nails, (i + 0.5) / 40 * W * 30, 0.82 * 30, 4, S.brass)
		end
		local inner = W - 1.4
		for i = 1, 3 do
			c.seat(
				P(-inner / 2 + inner / 3 * (i - 0.5), 1.5, -0.25),
				V(inner / 3 - 0.04, 0.4, D - 1.0),
				leather,
				M.Leather
			)
		end
		local back = c.part(P(0, 2.15, D / 2 - 0.35), V(W - 0.2, 1.7, 0.7), leather, M.Leather)
		local gui, gw, gh = Gui.Core.surface(back, Enum.NormalId.Front, { pps = 30, maxDistance = 50 })
		local tuft = shade(leather, -0.45)
		for row = 0, 2 do
			local n = 14
			for i = 0, n - 1 do
				local x = (i + 0.5 + (row % 2) * 0.5) / (n + 0.5) * gw
				Gui.Core.dot(gui, x, (0.22 + row * 0.25) * gh, 6, tuft, 0.1)
			end
		end
		c.dcylX(P(0, 3.0, D / 2 - 0.35), W - 0.2, 0.75, leather, M.Leather)
		for _, sx in { -1, 1 } do
			c.part(P(sx * (W / 2 - 0.35), 2.075, 0), V(0.7, 1.55, D), leather, M.Leather)
			c.dcylZ(P(sx * (W / 2 - 0.3), 2.85, 0), D, 0.85, leather, M.Leather)
		end
		c.use(V(0, 2, -0.5))
	end,
})

---------------------------------------------------------------------------------------------------
-- fireplace (mount "wall"): marble surround with pilasters, mantel shelf and overmantel panel, an iron
-- grate with logs and a Neon ember bed + flames (no Fire instance). The ember part carries an orange
-- PointLight (attribute Flicker = true) when opts.lit (default true).
---------------------------------------------------------------------------------------------------
add({
	id = "fireplace",
	category = "lux",
	footprint = V(7.6, 5.5, 1.7),
	maxParts = 24,
	tags = { "fireplace", "wall", "light" },
	mount = "wall",
	build = function(c: Ctx)
		local W, H = 7, 5.5
		local marble = c.color("color", S.marble)
		local accent = c.color("accent", S.marbleVein)
		local lit = c.bool("lit", true)
		c.part(P(0, 0.15, -1.2), V(W + 0.6, 0.3, 1.0), S.granite, M.Granite)
		c.part(P(0, H / 2, -0.3), V(W, H, 0.6), marble, M.Marble)
		c.detail(P(0, 1.55, -0.62), V(3.4, 2.5, 0.06), hex("#0B0B0C"), M.Slate)
		for _, sx in { -1, 1 } do
			c.part(P(sx * (W / 2 - 0.55), 1.8, -0.85), V(1.0, 3.0, 0.5), marble, M.Marble)
		end
		c.part(P(0, 3.45, -0.9), V(W + 0.4, 0.3, 1.0), marble, M.Marble)
		c.detail(P(0, 3.05, -0.66), V(W - 2.2, 0.4, 0.12), accent, M.Marble)
		c.detail(P(0, 4.55, -0.63), V(W - 1.6, 1.4, 0.06), shade(marble, -0.05), M.Marble)
		-- grate, logs, embers and flames
		c.detail(P(0, 0.38, -0.95), V(2.8, 0.1, 0.5), hex("#1A1A1A"), M.Metal)
		for _, sx in { -1, 1 } do
			c.dcyl(P(sx * 1.5, 0.55, -1.15), 0.5, 0.14, S.brass, M.Metal)
		end
		local wood = hex("#4A3020")
		c.dcylX(P(0, 0.62, -0.8) * R(0, 4, 0), 2.6, 0.36, wood, M.Wood)
		c.dcylX(P(0.1, 0.62, -1.05) * R(0, -5, 0), 2.4, 0.34, shade(wood, 0.1), M.Wood)
		c.dcylX(P(-0.1, 0.92, -0.92) * R(0, 8, 0), 2.2, 0.32, shade(wood, -0.1), M.Wood)
		local ember = c.glow(P(0, 0.45, -0.9), V(2.6, 0.06, 0.6), hex("#FF7A1A"), if lit then 0.05 else 0.7)
		ember.Name = "Embers"
		if lit then
			ember:SetAttribute("Flicker", true)
			c.light(ember, "point", { Range = 16, Brightness = 1.6, Color = hex("#FF9A4A") })
			for i = -1, 1 do
				c.glow(
					P(i * 0.7, 1.3 - math.abs(i) * 0.15, -0.85) * R(0, 0, i * -8),
					V(0.45, 1.0 - math.abs(i) * 0.25, 0.05),
					if i == 0 then hex("#FFC14A") else hex("#FF8A2B"),
					0.35
				)
			end
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- pool_table: walnut table with green felt, cushions, six pockets, a racked triangle, cue ball and cue
---------------------------------------------------------------------------------------------------
local BALLS = {
	hex("#F2C230"),
	hex("#1F4E8C"),
	hex("#C0392B"),
	hex("#5B2C83"),
	hex("#E67E22"),
	hex("#121212"),
}

add({
	id = "pool_table",
	category = "lux",
	footprint = V(9, 2.95, 4.8),
	maxParts = 36,
	tags = { "table", "game", "furniture" },
	surface = 2.7,
	build = function(c: Ctx)
		local L, Wd = 9, 4.8
		local wood = c.color("color", S.walnut)
		local felt = c.color("accent", col.felt)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				c.part(P(sx * (L / 2 - 0.8), 0.95, sz * (Wd / 2 - 0.6)), V(0.7, 1.7, 0.7), wood, M.Wood)
				c.detail(P(sx * (L / 2 - 0.8), 0.1, sz * (Wd / 2 - 0.6)), V(0.9, 0.2, 0.9), shade(wood, -0.3), M.Wood)
			end
		end
		c.part(P(0, 2.15, 0), V(L, 0.7, Wd), wood, M.Wood)
		c.part(P(0, 2.6, 0), V(L - 0.9, 0.2, Wd - 0.9), felt, M.Fabric)
		for _, sz in { -1, 1 } do
			local rail = c.part(P(0, 2.65, sz * (Wd / 2 - 0.225)), V(L, 0.3, 0.45), wood, M.Wood)
			local gui, gw, gh = Gui.Core.surface(rail, Enum.NormalId.Top, { pps = 20, maxDistance = 30 })
			for i = 1, 7 do
				if i ~= 4 then
					Gui.Core.dot(gui, i / 8 * gw, gh / 2, 4, IVORY)
				end
			end
			c.detail(P(0, 2.76, sz * (Wd / 2 - 0.49)), V(L - 0.9, 0.12, 0.08), shade(felt, -0.2), M.Fabric)
		end
		for _, sx in { -1, 1 } do
			c.part(P(sx * (L / 2 - 0.225), 2.65, 0), V(0.45, 0.3, Wd - 0.9), wood, M.Wood)
			c.detail(P(sx * (L / 2 - 0.49), 2.76, 0), V(0.08, 0.12, Wd - 0.9), shade(felt, -0.2), M.Fabric)
		end
		for _, x in { -(L / 2 - 0.45), 0, L / 2 - 0.45 } do
			for _, sz in { -1, 1 } do
				c.dcyl(P(x, 2.72, sz * (Wd / 2 - 0.45)), 0.06, 0.45, hex("#0A0A0A"), M.SmoothPlastic)
			end
		end
		local apex = L / 4 - 0.3
		local i = 0
		for row = 0, 2 do
			for k = 0, row do
				i += 1
				c.dball(P(apex + row * 0.27, 2.85, (k - row / 2) * 0.31), 0.3, BALLS[i], M.SmoothPlastic)
			end
		end
		c.dball(P(-L / 4, 2.85, c.rng:range(-0.4, 0.4)), 0.3, IVORY, M.SmoothPlastic)
		c.dcylX(P(-0.6, 2.75, -0.9) * R(0, c.rng:range(8, 18), 0), L * 0.55, 0.08, hex("#D9B97A"), M.Wood)
		c.use(V(0, 3, -Wd / 2 - 0.5))
	end,
})

---------------------------------------------------------------------------------------------------
-- piano_grand: black lacquer grand with a rounded tail, propped lid over a gold harp plate, music desk,
-- keyboard (black keys painted on), lyre and pedals, and a matching bench at -Z
---------------------------------------------------------------------------------------------------
add({
	id = "piano_grand",
	category = "lux",
	footprint = V(5.05, 6.37, 9.05),
	offset = V(0, 0, -0.6),
	maxParts = 26,
	tags = { "piano", "music", "furniture" },
	build = function(c: Ctx)
		local black = c.color("color", LACQUER)
		local gold = c.color("accent", S.gold)
		local case = c.part(P(0, 2.85, -0.6), V(5.0, 1.1, 4.0), black, M.SmoothPlastic)
		case.Reflectance = 0.12
		c.cyl(P(0, 2.85, 1.4), 1.1, 5.0, black, M.SmoothPlastic).Reflectance = 0.12
		c.detail(P(0, 3.42, 0.2), V(4.3, 0.04, 3.6), gold, M.Metal)
		local hinge = P(2.5, 3.44, 0.5)
		local lid = c.detail(hinge * R(0, 0, -35) * P(-2.5, 0.04, 0), V(5.0, 0.08, 5.8), black, M.SmoothPlastic)
		lid.Reflectance = 0.15
		lid.Name = "Lid"
		Shapes.strut(c, V(-0.9, 3.42, 0.9), V(-0.75, 5.62, 0.9), 0.08, black, M.Wood)
		c.detail(P(0, 3.95, -2.25) * R(15, 0, 0), V(2.4, 0.9, 0.08), black, M.SmoothPlastic)
		c.part(P(0, 2.55, -3.05), V(4.6, 0.5, 0.9), black, M.SmoothPlastic)
		-- keys: a slab turned so its Front face points up with the GUI's top edge toward the piano (+Z),
		-- which puts the painted black keys at the back of the keyboard
		local keys = c.detail(P(0, 2.85, -3.1) * R(90, 0, 0), V(4.2, 0.8, 0.1), IVORY, M.SmoothPlastic)
		keys.Name = "Keys"
		local kg, kw, kh = Gui.Core.surface(keys, Enum.NormalId.Front, { pps = 40, maxDistance = 30 })
		local white = 36
		for k = 1, white - 1 do
			Gui.Core.px(kg, k / white * kw, 0, 1, kh, hex("#BDB6A6"))
			local m = k % 7
			if m ~= 3 and m ~= 0 then
				Gui.Core.px(kg, k / white * kw - kw / white * 0.3, 0, kw / white * 0.6, kh * 0.6, LACQUER)
			end
		end
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 2.2, 2.95, -3.05), V(0.2, 0.35, 0.9), black, M.SmoothPlastic)
		end
		c.detail(P(0, 3.05, -2.66), V(4.2, 0.35, 0.08), black, M.SmoothPlastic)
		for _, lp in { V(-2.0, 0, -2.2), V(2.0, 0, -2.2), V(0, 0, 3.0) } do
			c.part(P(lp.X, 1.3, lp.Z), V(0.45, 2.3, 0.45), black, M.SmoothPlastic)
			c.dball(P(lp.X, 0.15, lp.Z), 0.3, gold, M.Metal)
		end
		c.detail(P(0, 1.15, -2.3), V(0.5, 1.7, 0.15), black, M.SmoothPlastic)
		c.detail(P(0, 0.3, -2.45), V(0.9, 0.06, 0.3), gold, M.Metal)
		c.seat(P(0, 1.65, -4.6), V(2.8, 0.3, 1.1), black, M.Leather)
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 1.2, 0.75, -4.6), V(0.2, 1.5, 0.9), black, M.SmoothPlastic)
		end
		c.use(V(0, 2.5, -4.6))
	end,
})

---------------------------------------------------------------------------------------------------
-- art_pedestal: white gallery plinth with a small sculpture and a brass label. opts.variant 1-4
-- ("orb", "stack", "ring", "figure"), opts.vitrine = true adds a glass cover, opts.text sets the label.
---------------------------------------------------------------------------------------------------
add({
	id = "art_pedestal",
	category = "lux",
	footprint = V(1.95, 5.3, 1.95),
	maxParts = 12,
	tags = { "art", "gallery", "display" },
	surface = 3.88,
	build = function(c: Ctx)
		local white = c.color("color", S.white)
		local metal = c.color("accent", S.gold)
		local styles = { "orb", "stack", "ring", "figure" }
		local style = c.pick("variant", styles, styles[c.rng:int(1, 4)])
		c.detail(P(0, 0.075, 0), V(1.95, 0.15, 1.95), hex("#2A2A2D"), M.SmoothPlastic)
		c.part(P(0, 1.95, 0), V(1.8, 3.6, 1.8), white, M.SmoothPlastic)
		c.detail(P(0, 3.8, 0), V(1.95, 0.08, 1.95), white, M.SmoothPlastic)
		local label = c.detail(P(0, 3.2, -0.91), V(0.8, 0.3, 0.02), S.brass, M.Metal)
		c.sign(label, c.str("text", c.rng:pick(Words.artTitles), 40), {
			font = Enum.Font.Garamond,
			color = S.black,
			pixelsPerStud = 120,
			padding = 0.08,
		})
		local top = 3.84
		if style == "orb" then
			c.detail(P(0, top + 0.2, 0), V(0.7, 0.4, 0.7), hex("#1A1A1A"), M.Marble)
			c.dball(P(0, top + 0.9, 0), 1.0, metal, M.Metal)
		elseif style == "stack" then
			for i = 0, 2 do
				c.detail(
					P(0, top + 0.2 + i * 0.42, 0) * R(0, i * 28, 0),
					V(0.9 - i * 0.12, 0.38, 0.9 - i * 0.12),
					if i == 1 then metal else S.marble,
					if i == 1 then M.Metal else M.Marble
				)
			end
		elseif style == "ring" then
			c.detail(P(0, top + 0.1, 0), V(0.8, 0.2, 0.5), hex("#1A1A1A"), M.Marble)
			c.dcylZ(P(0, top + 0.85, 0), 0.15, 1.3, metal, M.Metal)
			local core = c.dball(P(0, top + 0.85, -0.12), 0.5, hex("#9FD3E8"), M.Glass)
			core.Transparency = 0.2
		else
			c.dcyl(P(0, top + 0.35, 0), 0.7, 0.12, metal, M.Metal)
			c.dball(P(0, top + 0.75, 0), 0.6, S.marble, M.Marble)
			c.dball(P(0.05, top + 1.12, 0), 0.42, S.marble, M.Marble)
			c.dball(P(0.08, top + 1.4, 0), 0.26, metal, M.Metal)
		end
		if c.bool("vitrine", false) then
			c.glass(P(0, top + 0.9, 0), V(1.6, 1.8, 1.6), hex("#EAF4FA"), 0.82, true)
		end
		c.use(V(0, 3.5, -1.3))
	end,
})

---------------------------------------------------------------------------------------------------
-- lounge_chair: walnut-shell recliner with leather cushions on a swivel base, plus its ottoman at -Z
---------------------------------------------------------------------------------------------------
add({
	id = "lounge_chair",
	category = "lux",
	footprint = V(2.95, 4.05, 5.5),
	offset = V(0, 0, -0.75),
	maxParts = 18,
	tags = { "chair", "seat", "furniture" },
	build = function(c: Ctx)
		local leather = c.color("color", col.leatherBlack)
		local shell = c.color("accent", S.walnut)
		local metal = col.chrome
		c.dcyl(P(0, 0.06, 0.1), 0.12, 1.9, LACQUER, M.Metal)
		c.dcyl(P(0, 0.42, 0.1), 0.6, 0.3, metal, M.Metal)
		c.detail(P(0, 0.85, 0.1) * R(10, 0, 0), V(2.4, 0.18, 2.3), shell, M.Wood)
		c.seat(P(0, 1.1, 0.05) * R(10, 0, 0), V(2.2, 0.36, 2.1), leather, M.Leather)
		c.detail(P(0, 2.25, 1.3) * R(25, 0, 0), V(2.4, 2.4, 0.18), shell, M.Wood)
		c.detail(P(0, 2.3, 1.12) * R(25, 0, 0), V(2.2, 2.2, 0.34), leather, M.Leather)
		c.detail(P(0, 3.6, 1.65) * R(32, 0, 0), V(2.0, 0.75, 0.35), leather, M.Leather)
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 1.3, 1.75, 0.3) * R(5, 0, 0), V(0.35, 0.18, 2.0), leather, M.Leather)
			Shapes.strut(c, V(sx * 1.1, 0.95, 0.4), V(sx * 1.3, 1.66, 0.4), 0.1, metal, M.Metal)
		end
		local oz = -2.6
		c.dcyl(P(0, 0.06, oz), 0.12, 1.5, LACQUER, M.Metal)
		c.dcyl(P(0, 0.35, oz), 0.5, 0.25, metal, M.Metal)
		c.detail(P(0, 0.66, oz), V(2.1, 0.12, 1.8), shell, M.Wood)
		c.part(P(0, 0.92, oz), V(2.0, 0.4, 1.7), leather, M.Leather)
		c.use(V(0, 2, 0))
	end,
})

return defs
