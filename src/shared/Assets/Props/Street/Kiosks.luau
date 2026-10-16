--!strict
-- Wall Street district kiosks and storefront pieces (category "street"): newsstand, food carts,
-- revolving door, awning, phone booth, bike-share dock and scaffold.

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

local IRON = hex("#1A1C1F")

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

---------------------------------------------------------------------------------------------------
-- newsstand: green kiosk with a lit eave, NEWS fascia, magazine racks and newspaper stacks.
---------------------------------------------------------------------------------------------------
add({
	id = "newsstand",
	category = "street",
	footprint = V(8.6, 7.7, 7.0),
	offset = V(0, 0, -0.4),
	maxParts = 22,
	tags = { "street", "shop", "kiosk" },
	build = function(c: Ctx)
		local green = c.color("color", S.awningGreen)
		local trim = c.color("accent", S.gold)
		local lit = c.bool("lit", true)
		c.part(P(0, 0.15, 0), V(8, 0.3, 5.3), shade(green, -0.3), M.Metal)
		c.part(P(0, 3.85, 2.4), V(8, 7.1, 0.5), green, M.Metal)
		for _, sx in { -1, 1 } do
			c.part(P(sx * 3.8, 3.85, 0.15), V(0.4, 7.1, 4.0), green, M.Metal)
		end
		c.part(P(0, 1.75, -2.3), V(7.2, 2.9, 0.6), green, M.Metal)
		c.detail(P(0, 3.25, -2.25), V(7.6, 0.1, 1.0), S.steelBrushed, M.Metal)
		c.part(P(0, 7.55, 0.1), V(8.6, 0.3, 6.0), shade(green, -0.2), M.Metal)
		c.detail(P(0, 7.15, -3.15) * R(-20, 0, 0), V(8.6, 0.12, 1.6), green, M.Metal)
		c.part(P(0, 6.65, -2.4), V(8, 1.5, 0.4), green, M.Metal)
		local fascia = c.detail(P(0, 6.65, -2.63), V(5.2, 1.0, 0.06), S.navy, M.SmoothPlastic)
		c.sign(fascia, Words.newsstand, { font = Enum.Font.Bodoni, color = trim, pixelsPerStud = 40, glow = lit })
		local racks = c.detail(P(0, 4.7, 2.12), V(7.0, 3.0, 0.06), hex("#2A2A2A"), M.SmoothPlastic)
		Gui.Art.covers((Gui.Core.surface(racks, Enum.NormalId.Front, { pps = 24, maxDistance = 90 })), 7, 3, c.rng)
		local side = c.detail(P(-4.03, 3.4, 0.2), V(0.06, 3.4, 3.4), hex("#2A2A2A"), M.SmoothPlastic)
		Gui.Art.covers((Gui.Core.surface(side, Enum.NormalId.Left, { pps = 20, maxDistance = 80 })), 4, 3, c.rng)
		for i, x in { -2.6, -1.2, 2.4 } do
			local stack = c.detail(
				P(x, 3.45 + i * 0.05, -2.2) * R(0, c.rng:range(-6, 6), 0),
				V(1.2, 0.3 + i * 0.1, 0.8),
				col.paper
			)
			if i == 1 then
				local gui = Gui.Core.surface(stack, Enum.NormalId.Top, { pps = 60, maxDistance = 40 })
				Gui.Art.newspaper(gui, c.rng)
			end
		end
		local strip = if lit
			then c.glow(P(0, 7.32, -2.9), V(7.8, 0.06, 0.12), S.warmLight, 0.1)
			else c.detail(P(0, 7.32, -2.9), V(7.8, 0.06, 0.12), shade(S.warmLight, -0.4), M.SmoothPlastic)
		Shapes.lamp(strip, lit, S.warmLight, 14, 0.8)
		local tag = c.detail(P(0, 5.5, -2.62), V(4.2, 0.5, 0.04), trim, M.Metal)
		c.sign(
			tag,
			Words.newsTagline,
			{ font = Enum.Font.GothamBold, color = S.navy, pixelsPerStud = 60, padding = 0.06 }
		)
		c.use(V(0, 3.5, -3.2))
	end,
})

---------------------------------------------------------------------------------------------------
-- food_cart: stainless cart with a striped umbrella and menu board. opts.variant "hotdog" | "coffee" |
-- "pretzel" (default: seeded pick) changes colours, menu and the goods on top.
---------------------------------------------------------------------------------------------------
local CART = {
	hotdog = { a = hex("#C0392B"), b = hex("#F2C230") },
	coffee = { a = hex("#1F4D3A"), b = hex("#F4F1EA") },
	pretzel = { a = hex("#1F4E8C"), b = hex("#F4F1EA") },
}

add({
	id = "food_cart",
	category = "street",
	footprint = V(6.5, 8.6, 6.4),
	maxParts = 32,
	tags = { "street", "shop", "food" },
	build = function(c: Ctx)
		local kinds = { "hotdog", "coffee", "pretzel" }
		local kind = c.pick("variant", kinds, c.rng:pick(kinds))
		local scheme = CART[kind]
		local a = c.color("color", scheme.a)
		local b = c.color("accent", scheme.b)
		local steel = S.steelBrushed
		c.part(P(0, 2.2, 0), V(5.6, 2.4, 2.8), steel, M.Metal)
		local skirt = c.detail(P(0, 2.15, -1.42), V(5.2, 1.9, 0.04), a, M.SmoothPlastic)
		skirt.Name = "Menu"
		local gui = Gui.Core.surface(skirt, Enum.NormalId.Front, { pps = 40, maxDistance = 80 })
		Gui.Art.menu(gui, Words.foodCart[kind], Words.cartMenus[kind], b, hex("#1A1A1A"), a)
		c.detail(P(0, 3.45, 0), V(5.8, 0.1, 3.0), steel, M.Metal)
		for _, sz in { -1, 1 } do
			Shapes.wheel(c, P(-1.7, 1.0, sz * 1.5) * R(0, 90, 0), 2.0, 0.28, steel)
			c.detail(P(2.3, 0.5, sz * 1.0), V(0.2, 1.0, 0.2), steel, M.Metal)
		end
		c.dcylZ(P(3.15, 3.05, 0), 2.4, 0.16, col.rubber, M.Rubber)
		for _, sz in { -1, 1 } do
			Shapes.strut(c, V(2.8, 3.0, sz * 1.1), V(3.15, 3.05, sz * 1.1), 0.1, steel, M.Metal)
		end
		-- umbrella: pole through the cart centre, stepped two-tone canopy
		c.dcyl(P(0, 5.6, 0), 4.3, 0.15, steel, M.Metal)
		c.dcyl(P(0, 7.85, 0), 0.22, 6.4, a, M.Fabric)
		c.dcyl(P(0, 8.05, 0), 0.22, 4.6, b, M.Fabric)
		c.dcyl(P(0, 8.25, 0), 0.22, 2.6, a, M.Fabric)
		c.dball(P(0, 8.45, 0), 0.32, b, M.SmoothPlastic)
		local sign = c.detail(P(0, 4.35, 1.3), V(3.0, 0.7, 0.08), b, M.SmoothPlastic)
		c.sign(sign, Words.foodCart[kind], { font = Enum.Font.LuckiestGuy, color = a, pixelsPerStud = 50 })
		c.detail(P(0, 3.9, 1.3), V(0.08, 0.9, 0.08), steel, M.Metal)
		if kind == "hotdog" then
			c.detail(P(-1.6, 3.65, 0.1), V(1.8, 0.3, 1.5), shade(steel, 0.15), M.Metal)
			c.detail(P(-1.6, 3.82, 0.1), V(1.7, 0.04, 1.4), shade(steel, -0.2), M.DiamondPlate)
			Shapes.bottle(c, P(1.3, 3.5, -0.6), 0.9, 0.3, hex("#E5B92A"))
			Shapes.bottle(c, P(1.75, 3.5, -0.6), 0.9, 0.3, hex("#B5202B"))
			c.detail(P(1.6, 3.65, 0.5), V(1.0, 0.3, 0.7), hex("#D9A55A"), M.Fabric)
		elseif kind == "coffee" then
			for _, x in { -1.8, -0.9 } do
				c.dcyl(P(x, 4.0, 0.3), 1.0, 0.7, steel, M.Metal)
				c.dcyl(P(x, 4.55, 0.3), 0.1, 0.5, IRON, M.Metal)
			end
			c.dcyl(P(1.5, 3.85, -0.4), 0.7, 0.32, col.paper, M.SmoothPlastic)
			c.detail(P(1.6, 3.6, 0.6), V(0.9, 0.2, 0.6), hex("#D9A55A"), M.SmoothPlastic)
		else
			c.glass(P(-1.4, 4.15, 0.1), V(2.2, 1.3, 1.5), hex("#E8F2F5"), 0.6)
			for i = 1, 3 do
				c.detail(
					P(-2.1 + i * 0.45, 3.6 + (i % 2) * 0.35, 0.1) * R(0, 0, c.rng:range(-10, 10)),
					V(0.4, 0.4, 0.12),
					hex("#8A5A2B"),
					M.SmoothPlastic
				)
			end
			c.detail(P(1.6, 3.65, 0.3), V(1.2, 0.3, 0.9), col.paper, M.SmoothPlastic)
		end
		c.use(V(0, 3.6, -2))
	end,
})

---------------------------------------------------------------------------------------------------
-- revolving_door: brass-capped glass drum with four wings ("Wing1".."Wing4", non-colliding) around a brass
-- "Hub". The curved side walls collide; the openings face -Z and +Z. WorldService doors go in the opening.
---------------------------------------------------------------------------------------------------
add({
	id = "revolving_door",
	category = "street",
	footprint = V(8.8, 9.6, 8.8),
	maxParts = 28,
	tags = { "door", "structure", "lobby", "glass" },
	build = function(c: Ctx)
		local brass = c.color("accent", S.brass)
		local glassC = c.color("color", hex("#CFE3EA"))
		local Rr, H = 4, 9
		c.dcyl(P(0, 0.06, 0), 0.12, 8.6, S.granite, M.Granite)
		c.cyl(P(0, 9.25, 0), 0.5, 8.8, brass, M.Metal)
		c.dcyl(P(0, 9.55, 0), 0.1, 8.2, S.black, M.Metal)
		local hub = c.cyl(P(0, H / 2, 0), H, 0.5, brass, M.Metal)
		hub.Name = "Hub"
		local spin = c.rng:range(0, 90)
		for k = 1, 4 do
			local wcf = P(0, H / 2 + 0.06, 0) * R(0, spin + k * 90, 0)
			local wing = c.glass(wcf * P((Rr - 0.3) / 2 + 0.25, 0, 0), V(Rr - 0.3, H - 0.6, 0.1), glassC, 0.6)
			wing.Name = "Wing" .. k
			c.detail(wcf * P(Rr - 0.12, 0, 0), V(0.12, H - 0.6, 0.16), brass, M.Metal)
		end
		-- curved side walls: four chords per side between 40 and 140 degrees off the opening axis
		for _, side in { 0, 180 } do
			for i = 0, 3 do
				local ang = side - 37.5 + i * 25
				local w = c.glass(
					P(0, H / 2, 0) * R(0, ang, 0) * P(Rr + 0.1, 0, 0),
					V(0.1, H - 0.1, 1.78),
					glassC,
					0.55,
					true
				)
				w.Reflectance = 0.15
			end
			for _, e in { -50, 50 } do
				c.detail(P(0, H / 2, 0) * R(0, side + e, 0) * P(Rr + 0.1, 0, 0), V(0.22, H, 0.22), brass, M.Metal)
			end
		end
		c.use(V(0, 3, -Rr - 0.5))
	end,
})

---------------------------------------------------------------------------------------------------
-- awning: striped fabric shop awning (mount "wall"). opts.width (3-40), opts.depth (2-8), opts.color and
-- opts.accent (stripes), opts.stripes (default true), opts.text (lettering on the valance).
---------------------------------------------------------------------------------------------------
add({
	id = "awning",
	category = "street",
	footprint = V(10.0, 2.75, 4.06),
	maxParts = 10,
	tags = { "street", "shop", "wall", "awning" },
	mount = "wall",
	scales = { width = 40 },
	build = function(c: Ctx)
		local W = c.num("width", 10, 3, 40)
		local D = c.num("depth", 4, 2, 8)
		local a = c.color("color", S.awningGreen)
		local b = c.color("accent", S.white)
		local stripes = c.bool("stripes", true)
		local rise = 1.8
		local front = 0.9
		local len = math.sqrt(D * D + rise * rise)
		local ang = math.deg(math.atan2(rise, D))
		local canopy = c.detail(P(0, front + rise / 2, -D / 2) * R(-ang, 0, 0), V(W, 0.1, len), a, M.Fabric)
		canopy.Name = "Canopy"
		local valance = c.detail(P(0, front / 2, -D), V(W, front, 0.08), a, M.Fabric)
		valance.Name = "Valance"
		if stripes then
			local n = math.max(3, math.floor(W / 1.0 + 0.5))
			local function paint(part: BasePart, face: Enum.NormalId)
				local gui = Gui.Core.surface(part, face, { pps = 12, maxDistance = 200 })
				for i = 0, n - 1 do
					if i % 2 == 1 then
						Gui.Core.frame(gui, i / n, 0, 1 / n, 1, b)
					end
				end
			end
			paint(canopy, Enum.NormalId.Top)
			paint(valance, Enum.NormalId.Front)
		end
		local text = c.str("text", "", 40)
		if text ~= "" then
			local band = c.detail(
				P(0, front / 2, -D - 0.05),
				V(math.min(W - 1, #text * 0.55 + 1), front * 0.7, 0.02),
				a,
				M.Fabric
			)
			c.sign(band, text, { font = Enum.Font.Garamond, color = b, pixelsPerStud = 40, bg = a, padding = 0.06 })
		end
		for _, sx in { -1, 1 } do
			c.dwedge(P(sx * (W / 2 - 0.04), front + rise / 2, -D / 2), V(0.08, rise, D), shade(a, -0.1), M.Fabric)
			Shapes.strut(
				c,
				V(sx * (W / 2 - 0.3), front + 0.05, -0.05),
				V(sx * (W / 2 - 0.3), front + 0.1, -D + 0.15),
				0.08,
				IRON,
				M.Metal
			)
		end
		c.detail(P(0, front + rise - 0.05, -0.08), V(W, 0.2, 0.15), IRON, M.Metal)
	end,
})

---------------------------------------------------------------------------------------------------
-- phone_booth: metro-blue booth with glass walls, glowing TELEPHONE headers, a payphone and directory.
---------------------------------------------------------------------------------------------------
add({
	id = "phone_booth",
	category = "street",
	footprint = V(3.6, 8.3, 3.6),
	maxParts = 24,
	tags = { "street", "booth" },
	build = function(c: Ctx)
		local frame = c.color("color", hex("#1D3557"))
		local lit = c.bool("lit", true)
		local glassC = hex("#DCEAF0")
		c.part(P(0, 0.15, 0), V(3.4, 0.3, 3.4), S.steelBrushed, M.DiamondPlate)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				c.part(P(sx * 1.55, 3.95, sz * 1.55), V(0.3, 7.3, 0.3), frame, M.Metal)
			end
		end
		c.part(P(0, 7.85, 0), V(3.6, 0.5, 3.6), frame, M.Metal)
		c.detail(P(0, 8.2, 0), V(3.0, 0.2, 3.0), shade(frame, -0.2), M.Metal)
		for _, sz in { -1, 1 } do
			local head = c.detail(P(0, 7.25, sz * 1.72), V(2.8, 0.55, 0.04), S.white, M.SmoothPlastic)
			c.sign(head, Words.phone, {
				face = if sz < 0 then Enum.NormalId.Front else Enum.NormalId.Back,
				font = Enum.Font.GothamBold,
				color = frame,
				pixelsPerStud = 50,
				glow = lit,
			})
		end
		c.glass(P(-1.55, 3.95, 0), V(0.08, 6.4, 2.8), glassC, 0.55, true)
		c.glass(P(1.55, 3.95, 0), V(0.08, 6.4, 2.8), glassC, 0.55, true)
		c.glass(P(0, 3.95, 1.55), V(2.8, 6.4, 0.08), glassC, 0.55, true)
		local door = c.glass(P(0, 3.95, -1.55), V(2.8, 6.4, 0.08), glassC, 0.6, true)
		door.Name = "Door"
		c.detail(P(1.1, 3.8, -1.62), V(0.08, 1.2, 0.08), S.steelBrushed, M.Metal)
		c.detail(P(0, 4.7, 1.32), V(1.0, 1.5, 0.35), S.steelBrushed, M.Metal)
		c.detail(P(-0.6, 4.7, 1.25), V(0.22, 0.95, 0.22), IRON, M.SmoothPlastic)
		local keys = c.detail(P(0.12, 4.55, 1.13), V(0.5, 0.6, 0.02), IRON, M.SmoothPlastic)
		local kg = Gui.Core.surface(keys, Enum.NormalId.Front, { pps = 80, maxDistance = 25 })
		for r = 0, 3 do
			for k = 0, 2 do
				Gui.Core.frame(kg, 0.12 + k * 0.28, 0.08 + r * 0.23, 0.2, 0.16, S.steelBrushed)
			end
		end
		c.detail(P(0, 3.55, 1.15), V(1.8, 0.1, 0.7), S.steelBrushed, M.Metal)
		c.detail(P(0.45, 3.68, 1.1), V(0.7, 0.16, 0.5), hex("#E3C46F"), M.SmoothPlastic)
		local strip = if lit
			then c.glow(P(0, 7.56, 0), V(2.2, 0.06, 2.2), S.warmLight, 0.2)
			else c.detail(P(0, 7.56, 0), V(2.2, 0.06, 2.2), S.white, M.SmoothPlastic)
		Shapes.lamp(strip, lit, S.warmLight, 10, 0.8)
		c.use(V(0, 3.5, -2.2))
	end,
})

---------------------------------------------------------------------------------------------------
-- bike_share_dock: STREETCYCLE docking spine with opts.count (2-8, default 4) docks, seeded bikes and a
-- payment kiosk at the -X end. Bikes point their front wheels into the docks at +Z.
---------------------------------------------------------------------------------------------------
add({
	id = "bike_share_dock",
	category = "street",
	footprint = V(11.4, 6.35, 6.5),
	offset = V(0, 0, 0.35),
	maxParts = 90,
	tags = { "street", "transit", "bike" },
	scales = { count = 8 },
	build = function(c: Ctx)
		local n = c.int("count", 4, 2, 8)
		local brand = c.color("color", hex("#1E6FD9"))
		local lit = c.bool("lit", true)
		local pitch = 2.2
		local total = 2.4 + n * pitch
		local x0 = -total / 2
		c.part(P(x0 + 2.4 + n * pitch / 2, 0.12, 3.1), V(n * pitch, 0.24, 1.0), hex("#3A3D42"), M.Metal)
		local bikes = 0
		for i = 1, n do
			local x = x0 + 2.4 + pitch * (i - 0.5)
			c.part(P(x, 1.4, 3.1), V(0.5, 2.6, 0.5), hex("#4A4F55"), M.Metal)
			local docked = c.rng:chance(0.75) or (i == n and bikes == 0)
			c.glow(P(x, 2.4, 2.84), V(0.2, 0.2, 0.02), if docked then hex("#2BD67B") else hex("#FFB000"), 0.15)
			if docked then
				bikes += 1
				Shapes.bike(c, P(x, 0, 0) * R(0, 180, 0), brand, { simple = true, basket = true })
			end
		end
		local xk = x0 + 0.8
		c.part(P(xk, 3.0, 2.6), V(1.6, 6.0, 1.0), brand, M.Metal)
		local screen = c.detail(P(xk, 3.9, 2.08), V(1.2, 1.6, 0.04), hex("#0B1622"), M.Glass)
		local gui = Gui.Core.surface(screen, Enum.NormalId.Front, { glow = lit, pps = 60, maxDistance = 40 })
		Gui.Core.bg(gui, hex("#0B1622"))
		for i, line in Words.bikeKiosk do
			Gui.Core.label(
				gui,
				line,
				0.08,
				0.08 + (i - 1) * 0.3,
				0.84,
				0.24,
				if i == 1 then hex("#7FB8FF") else S.white,
				{
					font = Enum.Font.GothamBold,
					align = Enum.TextXAlignment.Center,
				}
			)
		end
		local logo = c.detail(P(xk, 5.5, 2.08), V(1.4, 0.4, 0.02), S.white, M.SmoothPlastic)
		c.sign(logo, Words.bikeShare, { font = Enum.Font.GothamBlack, color = brand, pixelsPerStud = 60 })
		c.detail(P(xk, 6.12, 2.5) * R(-12, 0, 0), V(2.0, 0.1, 1.6), hex("#1B2A44"), M.Glass)
		c.use(V(xk, 3.5, 1.5))
	end,
})

---------------------------------------------------------------------------------------------------
-- scaffold: steel tube scaffold with plank decks, guard rails, braces, green safety netting, a notice and
-- a warning lamp. opts.bays (1-4, default 2) x opts.levels (1-4, default 2). It stands in front of a facade
-- with its back (+Z) against the wall. Decks and uprights collide.
---------------------------------------------------------------------------------------------------
add({
	id = "scaffold",
	category = "street",
	footprint = V(14.3, 16.3, 5.0),
	maxParts = 42,
	tags = { "street", "structure", "construction" },
	scales = { bays = 4, levels = 4 },
	build = function(c: Ctx)
		local bays = c.int("bays", 2, 1, 4)
		local levels = c.int("levels", 2, 1, 4)
		local steel = c.color("color", hex("#8C9196"))
		local plank = c.color("accent", hex("#9C7A4E"))
		local bw, lh, D = 7, 6.5, 4.5
		local X = bays * bw
		local Ht = levels * lh + 3.3
		for i = 0, bays do
			local x = -X / 2 + i * bw
			for _, sz in { -1, 1 } do
				c.cyl(P(x, Ht / 2, sz * D / 2), Ht, 0.3, steel, M.Metal)
			end
		end
		for l = 1, levels do
			local y = l * lh
			c.part(P(0, y, 0), V(X, 0.25, D - 0.3), shade(plank, c.rng:range(-0.1, 0.05)), M.WoodPlanks)
			c.dcylX(P(0, y - 0.25, -D / 2), X, 0.2, steel, M.Metal)
			c.dcylX(P(0, y - 0.25, D / 2), X, 0.2, steel, M.Metal)
			c.dcylX(P(0, y + 1.6, -D / 2), X, 0.2, steel, M.Metal)
			c.dcylX(P(0, y + 3.2, -D / 2), X, 0.2, steel, M.Metal)
		end
		for i = 0, bays - 1 do
			local xa, xb = -X / 2 + i * bw, -X / 2 + (i + 1) * bw
			if i % 2 == 1 then
				xa, xb = xb, xa
			end
			Shapes.tube(c, V(xa, 0.3, -D / 2), V(xb, levels * lh, -D / 2), 0.18, steel, M.Metal)
		end
		local net = c.detail(P(0, Ht / 2, -D / 2 - 0.22), V(X, Ht, 0.05), hex("#3D6B3A"), M.Fabric)
		net.Transparency = 0.55
		net.Name = "Netting"
		local notice = c.detail(P(0, 3.0, -D / 2 - 0.3), V(4, 1.2, 0.08), hex("#B99D6B"), M.WoodPlanks)
		c.sign(notice, Words.scaffold, { font = Enum.Font.SpecialElite, color = hex("#1A1A1A"), pixelsPerStud = 40 })
		local lamp = c.glow(P(-X / 2 + 0.3, lh + 0.5, -D / 2 - 0.25), V(0.3, 0.3, 0.1), hex("#FF8A2B"), 0.1)
		lamp:SetAttribute("Flicker", true)
	end,
})

return defs
