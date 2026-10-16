--!strict
-- Office desks, from the intern bullpen to the MD partner desk, plus the long trading-floor desk.
-- Desk convention: the user sits on the FRONT side (-Z); monitors and modesty panels sit at the back (+Z).
-- Every desk top is at `surface` studs (2.8), so desk props (mount "desk") go at cf * (x, 2.8, z).

local Common = require(script.Parent.Parent.Common)
local Shapes = require(script.Parent.Parent.Shapes)
local Kit = require(script.Parent.Parent.Parent.Parent.Build.Kit)

type Ctx = Common.Ctx
type Def = Common.Def

local P, R = Common.P, Common.R
local V = Vector3.new
local M = Enum.Material
local col = Common.col
local shade = Kit.shade

local H = 2.8 -- desk surface height

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

---------------------------------------------------------------------------------------------------
-- desk_bullpen: laminate bench desk with a fabric privacy screen and a mobile pedestal (tier 1)
---------------------------------------------------------------------------------------------------
add({
	id = "desk_bullpen",
	category = "office",
	footprint = V(6, 4.1, 3.1),
	maxParts = 24,
	tags = { "desk", "furniture", "bullpen" },
	surface = H,
	build = function(c: Ctx)
		local f = Common.finish(c.int("tier", 1, 1, 4))
		local top = c.color("color", f.top)
		local frame = c.color("accent", f.metal)
		local W, D, T = 6, 3, 0.12
		c.part(P(0, H - T / 2, 0), V(W, T, D), top, f.topMat)
		c.detail(P(0, H - T / 2, -D / 2 - 0.02), V(W + 0.04, T + 0.02, 0.04), shade(top, -0.35), M.SmoothPlastic)
		local legH = H - T
		for _, sx in { -1, 1 } do
			local x = sx * (W / 2 - 0.25)
			c.detail(P(x, 0.06, 0), V(0.3, 0.12, D - 0.2), frame, M.Metal)
			c.part(P(x, 0.12 + (legH - 0.22) / 2, 0.35), V(0.16, legH - 0.22, 0.32), frame, M.Metal)
			c.detail(P(x, legH - 0.05, 0), V(0.18, 0.1, D - 0.3), frame, M.Metal)
		end
		-- perforated modesty panel
		c.detail(P(0, 1.95, D / 2 - 0.35), V(W - 0.9, 1.1, 0.05), shade(frame, 0.2), M.DiamondPlate)
		if c.bool("divider", true) then
			c.part(P(0, H + 0.6, D / 2 - 0.06), V(W, 1.2, 0.1), c.color("fabric", col.fabricGrey), M.Fabric)
			c.detail(P(0, H + 1.23, D / 2 - 0.06), V(W + 0.02, 0.06, 0.16), col.aluminum, M.Metal)
		end
		-- mobile pedestal (three drawers) on a recessed plinth
		local px = W / 2 - 1.05
		c.detail(P(px, 0.08, -0.15), V(1.2, 0.16, 2.0), col.frameDark, M.SmoothPlastic)
		Shapes.drawers(
			c,
			P(px, 0.16 + 0.9, -0.15),
			V(1.3, 1.8, 2.2),
			3,
			col.laminateGrey,
			M.SmoothPlastic,
			shade(top, -0.04),
			M.SmoothPlastic,
			col.aluminum
		)
		-- cable grommet
		c.dcyl(P(-W / 2 + 0.6, H + 0.005, D / 2 - 0.5), 0.01, 0.32, col.plasticBlack, M.SmoothPlastic)
		c.use(V(0, H + 0.6, -D / 2))
	end,
})

---------------------------------------------------------------------------------------------------
-- desk_associate: oak desk, panel leg + three-drawer pedestal, monitor riser and blotter (tier 2)
---------------------------------------------------------------------------------------------------
add({
	id = "desk_associate",
	category = "office",
	footprint = V(6.5, 3.25, 3.2),
	maxParts = 20,
	tags = { "desk", "furniture" },
	surface = H,
	build = function(c: Ctx)
		local f = Common.finish(c.int("tier", 2, 1, 4))
		local wood = c.color("color", f.wood)
		local accent = c.color("accent", f.accent)
		local W, D, T = 6.5, 3.2, 0.16
		c.part(P(0, H - T / 2, 0), V(W, T, D), wood, f.woodMat)
		c.detail(P(0, H - T / 2, -D / 2 - 0.015), V(W - 0.2, 0.04, 0.03), accent, M.Metal)
		c.detail(P(0, H - T - 0.03, 0), V(W - 0.12, 0.06, D - 0.12), shade(wood, -0.3), f.woodMat)
		local legH = H - T - 0.06
		c.part(P(-W / 2 + 0.14, legH / 2, 0), V(0.28, legH, D - 0.1), wood, f.woodMat)
		Shapes.drawers(
			c,
			P(W / 2 - 0.9, legH / 2, 0),
			V(1.75, legH, D - 0.1),
			3,
			wood,
			f.woodMat,
			shade(wood, -0.08),
			f.woodMat,
			accent
		)
		-- recessed modesty panel between leg and pedestal
		local x0, x1 = -W / 2 + 0.28, W / 2 - 1.775
		c.detail(P((x0 + x1) / 2, legH - 0.85, D / 2 - 0.45), V(x1 - x0, 1.6, 0.08), shade(wood, -0.12), f.woodMat)
		-- monitor riser shelf on two metal blocks
		c.detail(P(0, H + 0.36, D / 2 - 0.55), V(4, 0.08, 0.9), wood, f.woodMat)
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 1.8, H + 0.16, D / 2 - 0.55), V(0.12, 0.32, 0.8), f.metal, f.metalMat)
		end
		-- leather desk blotter
		c.detail(P(0, H + 0.01, -0.55), V(2.6, 0.02, 1.3), col.leatherBlack, M.Leather)
		c.use(V(0, H + 0.6, -D / 2))
	end,
})

---------------------------------------------------------------------------------------------------
-- desk_vp: walnut double-pedestal executive desk with brass inlay and leather writing surface (tier 3)
---------------------------------------------------------------------------------------------------
add({
	id = "desk_vp",
	category = "office",
	footprint = V(7.5, 2.8, 3.6),
	maxParts = 28,
	tags = { "desk", "furniture", "executive" },
	surface = H,
	build = function(c: Ctx)
		local f = Common.finish(c.int("tier", 3, 1, 4))
		local wood = c.color("color", f.wood)
		local accent = c.color("accent", f.accent)
		local W, D, T = 7.5, 3.6, 0.18
		c.part(P(0, H - T / 2, 0), V(W, T, D), wood, f.woodMat)
		-- stepped under-lip reads as a bevelled edge
		c.detail(P(0, H - T - 0.03, 0), V(W - 0.14, 0.06, D - 0.14), shade(wood, -0.25), f.woodMat)
		c.detail(P(0, H - T / 2, -D / 2 - 0.01), V(W - 0.4, 0.04, 0.02), accent, M.Metal)
		c.detail(P(0, H + 0.005, -0.35), V(3.6, 0.01, 1.8), c.color("fabric", col.leatherBrown), M.Leather)
		local pedH = H - T - 0.06 - 0.2
		for i, sx in { -1, 1 } do
			local x = sx * (W / 2 - 0.95)
			c.detail(P(x, 0.1, 0), V(1.7, 0.2, D - 0.3), shade(wood, -0.35), f.woodMat)
			Shapes.drawers(
				c,
				P(x, 0.2 + pedH / 2, 0),
				V(1.85, pedH, D - 0.2),
				if i == 1 then 3 else 2,
				wood,
				f.woodMat,
				shade(wood, -0.1),
				f.woodMat,
				accent,
				i == 2
			)
		end
		-- modesty panel on the visitor side with a raised field
		local mw = W - 3.8
		c.part(P(0, 1.55, D / 2 - 0.35), V(mw, 2.1, 0.12), wood, f.woodMat)
		c.detail(P(0, 1.55, D / 2 - 0.27), V(mw - 0.5, 1.5, 0.04), shade(wood, 0.08), f.woodMat)
		c.use(V(0, H + 0.6, -D / 2))
	end,
})

---------------------------------------------------------------------------------------------------
-- desk_md: the MD's partner desk. Drawers on the user side, cupboards on the visitor side, gold banding,
-- tooled leather top and a toe-plinth with gold kick strips (tier 4).
---------------------------------------------------------------------------------------------------
add({
	id = "desk_md",
	category = "office",
	footprint = V(9, 2.8, 4.45),
	maxParts = 40,
	tags = { "desk", "furniture", "executive", "partner" },
	surface = H,
	build = function(c: Ctx)
		local f = Common.finish(c.int("tier", 4, 1, 4))
		local wood = c.color("color", f.wood)
		local gold = c.color("accent", f.metal)
		local W, D, T = 9, 4.4, 0.2
		c.part(P(0, H - T / 2, 0), V(W, T, D), wood, f.woodMat)
		c.detail(P(0, H - T - 0.04, 0), V(W - 0.16, 0.08, D - 0.16), shade(wood, -0.2), f.woodMat)
		-- gold edge banding on all four sides
		for _, sz in { -1, 1 } do
			c.detail(P(0, H - T / 2, sz * (D / 2 + 0.01)), V(W + 0.02, 0.05, 0.02), gold, M.Metal)
			c.detail(P(sz * (W / 2 + 0.01), H - T / 2, 0), V(0.02, 0.05, D), gold, M.Metal)
		end
		-- tooled leather top with a thin gold border line
		c.detail(P(0, H + 0.003, 0), V(W - 1.1, 0.006, D - 1.1), gold, M.Metal)
		c.detail(P(0, H + 0.006, 0), V(W - 1.2, 0.01, D - 1.2), c.color("fabric", col.oxblood), M.Leather)
		local plinthH = 0.35
		local pedH = H - T - 0.08 - plinthH
		local pedY = plinthH + pedH / 2
		local pedD = D - 0.3
		for _, sx in { -1, 1 } do
			local x = sx * (W / 2 - 1.1)
			c.part(P(x, plinthH / 2, 0), V(2.05, plinthH, pedD - 0.1), shade(wood, -0.3), f.woodMat)
			c.detail(P(x, 0.07, 0), V(2.08, 0.06, pedD - 0.04), gold, M.Metal)
			c.part(P(x, pedY, 0), V(2.2, pedH, pedD), wood, f.woodMat)
			Shapes.drawerFronts(
				c,
				P(x, pedY, -pedD / 2),
				2.2,
				pedH,
				3,
				shade(wood, -0.06),
				f.woodMat,
				gold,
				true
			)
			-- visitor side: a panelled cupboard door
			c.detail(P(x, pedY, pedD / 2 + 0.03), V(2.0, pedH - 0.2, 0.06), shade(wood, -0.06), f.woodMat)
			c.detail(P(x + sx * -0.75, pedY + 0.2, pedD / 2 + 0.09), V(0.06, 0.45, 0.06), gold, M.Metal)
		end
		-- centre apron with a wide drawer on the user side and a matching panel on the visitor side
		local aw = W - 4.4
		local ay = H - T - 0.08 - 0.3
		c.part(P(0, ay, 0), V(aw, 0.6, D - 0.5), wood, f.woodMat)
		c.detail(P(0, ay, -(D - 0.5) / 2 - 0.03), V(aw - 0.2, 0.46, 0.06), shade(wood, -0.06), f.woodMat)
		c.detail(P(0, ay + 0.05, -(D - 0.5) / 2 - 0.09), V(0.9, 0.06, 0.06), gold, M.Metal)
		c.detail(P(0, ay, (D - 0.5) / 2 + 0.03), V(aw - 0.2, 0.46, 0.06), shade(wood, -0.06), f.woodMat)
		c.use(V(0, H + 0.6, -D / 2))
	end,
})

---------------------------------------------------------------------------------------------------
-- desk_trading: long trading-floor bench. opts.seats (1-6, default 3) positions, each with three screens
-- (two low, one high on a centre post), a keyboard, mouse and dealer-board phone turret.
-- opts.screens = kind or list of kinds (see Gui.Screens.KINDS); opts.lit (default true).
---------------------------------------------------------------------------------------------------
local SEAT_W = 4.5
local TRADING_MIX = { "chart", "candles", "quotes", "terminal", "news", "chart", "sheet", "quotes" }

add({
	id = "desk_trading",
	category = "office",
	footprint = V(14, 5.6, 4.1),
	maxParts = 95,
	tags = { "desk", "furniture", "trading", "screens" },
	surface = H,
	scales = { seats = 6 },
	build = function(c: Ctx)
		local seats = c.int("seats", 3, 1, 6)
		local W, D, T = seats * SEAT_W + 0.5, 4, 0.14
		local top = c.color("color", Kit.hex("#2B2F36"))
		local frame = c.color("accent", col.frameDark)
		local lit = c.bool("lit", true)
		c.part(P(0, H - T / 2, 0), V(W, T, D), top, M.SmoothPlastic)
		c.dcylX(P(0, H - T / 2, -D / 2), W, 0.18, col.plasticBlack, M.Rubber)
		-- end panels and a cable spine cabinet at the back
		for _, sx in { -1, 1 } do
			c.part(P(sx * (W / 2 - 0.12), (H - T) / 2, 0), V(0.24, H - T, D - 0.3), frame, M.Metal)
		end
		c.part(P(0, 1.3, D / 2 - 0.55), V(W - 0.5, 2.5, 0.8), shade(frame, 0.1), M.Metal)
		-- monitor bridge: a rail on posts between the positions
		local bridgeZ = D / 2 - 0.55
		c.detail(P(0, H + 0.9, bridgeZ + 0.12), V(W - 0.6, 0.12, 0.12), frame, M.Metal)
		for i = 0, seats do
			local x = -W / 2 + 0.25 + i * SEAT_W
			c.detail(P(x, H + 0.45, bridgeZ + 0.12), V(0.14, 0.9, 0.14), frame, M.Metal)
		end
		local kinds = Shapes.screenKinds(c, seats * 3, c.rng:shuffle(TRADING_MIX))
		for s = 1, seats do
			local cx = -W / 2 + 0.25 + (s - 0.5) * SEAT_W
			Shapes.display(c, P(cx - 1.0, H + 1.0, bridgeZ) * R(0, -6, 0), 1.95, 1.15, kinds[s * 3 - 2], lit, c.rng)
			Shapes.display(c, P(cx + 1.0, H + 1.0, bridgeZ) * R(0, 6, 0), 1.95, 1.15, kinds[s * 3 - 1], lit, c.rng)
			c.detail(P(cx, H + 1.6, bridgeZ + 0.22), V(0.12, 1.2, 0.12), frame, M.Metal)
			Shapes.display(c, P(cx, H + 2.25, bridgeZ) * R(-8, 0, 0), 1.95, 1.15, kinds[s * 3], lit, c.rng)
			-- keyboard, mouse and dealer-board turret
			c.detail(P(cx - 0.2, H + 0.04, -0.85), V(1.6, 0.08, 0.55), col.plasticBlack, M.SmoothPlastic)
			c.detail(P(cx + 0.95, H + 0.04, -0.8), V(0.18, 0.08, 0.3), col.plasticGrey, M.SmoothPlastic)
			c.detail(P(cx + 1.65, H + 0.14, -0.35) * R(-24, 0, 0), V(0.9, 0.22, 0.65), col.frame, M.SmoothPlastic)
		end
		c.use(V(0, H + 0.6, -D / 2))
	end,
})

return defs
