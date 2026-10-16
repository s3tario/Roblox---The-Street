--!strict
-- Parked vehicles (category "street", tag "vehicle"): taxi, sedan, town car and city bus. The vehicle's
-- nose points along cf.LookVector (-Z); cf is the centre of its footprint on the road. Every vehicle is
-- static scenery: anchored parts, collidable body and glass, non-colliding trim. opts.lit (default true)
-- lights the head/tail lamps, the taxi's roof sign and the bus destination board.

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

local HEAD = hex("#FFF6DD")
local TAIL = hex("#C8102E")
local GLASS = hex("#2B3A46")

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

type CarSpec = {
	L: number,
	W: number,
	wheelD: number,
	axleF: number,
	axleR: number,
	belt: number, -- top of the lower body
	roof: number, -- underside of the roof panel
	cabFront: number, -- z where the windshield meets the cabin glass
	cabBack: number, -- z where the cabin glass meets the rear window
	ws: number, -- windshield run (along Z)
	rw: number, -- rear window run
	body: Color3,
	trim: Color3,
	chrome: boolean,
	grille: Color3,
	glassT: number,
}

export type CarInfo = { roofY: number, cabMid: number, cabLen: number }

local function plateText(c: Ctx): string
	return string.format("%s %04d", c.rng:pick(Words.platePrefix), c.rng:int(1000, 9999))
end

-- Shared sedan-shaped body: ~47 parts. Returns roof/cabin measurements for extras.
local function car(c: Ctx, s: CarSpec): CarInfo
	local L, W = s.L, s.W
	local r = s.wheelD / 2
	local belt, roofY = s.belt, s.roof
	local cabH = roofY - belt
	local lit = c.bool("lit", true)
	local trimMat = if s.chrome then M.Metal else M.SmoothPlastic
	c.detail(P(0, 0.75, 0), V(W - 0.8, 0.5, L - 1.4), col.frameDark, M.SmoothPlastic)
	local shell = c.part(P(0, (1.0 + belt) / 2, 0), V(W, belt - 1.0, L), s.body, M.SmoothPlastic)
	shell.Name = "Body"
	shell.Reflectance = 0.06
	for _, sz in { -1, 1 } do
		c.detail(P(0, 1.25, sz * (L / 2 + 0.12)), V(W - 0.1, 0.55, 0.3), s.trim, trimMat)
		local plate = c.detail(P(0, 1.25, sz * (L / 2 + 0.29)), V(1.3, 0.42, 0.04), S.white, M.SmoothPlastic)
		c.sign(plate, plateText(c), {
			face = if sz < 0 then Enum.NormalId.Front else Enum.NormalId.Back,
			font = Enum.Font.RobotoMono,
			color = S.navy,
			pixelsPerStud = 90,
			padding = 0.08,
		})
	end
	c.detail(P(0, 1.95, -L / 2 - 0.03), V(W * 0.42, 0.65, 0.06), s.grille, M.DiamondPlate)
	for _, sx in { -1, 1 } do
		local hx = sx * (W / 2 - 0.75)
		if lit then
			c.glow(P(hx, 2.05, -L / 2 - 0.03), V(1.0, 0.42, 0.06), HEAD, 0.05)
		else
			c.detail(P(hx, 2.05, -L / 2 - 0.03), V(1.0, 0.42, 0.06), hex("#D8DDE0"), M.Glass)
		end
		c.glow(P(hx, 2.15, L / 2 + 0.03), V(1.0, 0.38, 0.06), TAIL, if lit then 0.1 else 0.55)
	end
	-- greenhouse: windshield wedge, cabin glass box, rear window wedge, roof
	local gw = W - 0.5
	local cabLen = s.cabBack - s.cabFront
	local cabMid = (s.cabFront + s.cabBack) / 2
	local midY = belt + cabH / 2
	local ws = c.wedge(P(0, midY, s.cabFront - s.ws / 2), V(gw, cabH, s.ws), GLASS, M.Glass)
	local cabin = c.part(P(0, midY, cabMid), V(gw, cabH, cabLen), GLASS, M.Glass)
	local rw = c.wedge(P(0, midY, s.cabBack + s.rw / 2) * R(0, 180, 0), V(gw, cabH, s.rw), GLASS, M.Glass)
	local panes: { BasePart } = { ws, cabin, rw }
	for _, g in panes do
		g.Transparency = s.glassT
		g.Reflectance = 0.15
		g.CastShadow = false
	end
	cabin.Name = "Cabin"
	c.part(P(0, roofY + 0.1, cabMid), V(W - 0.4, 0.2, cabLen + 0.3), s.body, M.SmoothPlastic).Reflectance = 0.06
	-- seats seen through the glass
	c.detail(P(0, belt + 0.55, s.cabFront + 0.9), V(gw - 0.6, 1.1, 0.5), col.leatherBlack, M.Leather)
	c.detail(P(0, belt + 0.5, s.cabBack - 0.4), V(gw - 0.4, 1.0, 0.5), col.leatherBlack, M.Leather)
	-- pillars, trim and doors
	local px = gw / 2 + 0.02
	for _, sx in { -1, 1 } do
		local x = sx * px
		Shapes.strut(c, V(x, belt, s.cabFront - s.ws), V(x, roofY, s.cabFront), 0.18, s.body, M.SmoothPlastic)
		Shapes.strut(c, V(x, roofY, s.cabBack), V(x, belt, s.cabBack + s.rw), 0.18, s.body, M.SmoothPlastic)
		c.detail(P(x, midY, s.cabFront + cabLen * 0.48), V(0.06, cabH, 0.3), s.body, M.SmoothPlastic)
		local sideX = sx * (W / 2 + 0.015)
		c.detail(P(sideX, belt - 0.35, 0), V(0.04, 0.08, L - 2.0), s.trim, trimMat)
		for _, z in { s.cabFront - 0.4, s.cabBack + 0.2 } do
			c.detail(P(sideX, (1.15 + belt) / 2, z), V(0.04, belt - 1.3, 0.05), shade(s.body, -0.5), M.SmoothPlastic)
		end
		for _, z in { cabMid - 0.4, s.cabBack - 0.3 } do
			c.detail(P(sx * (W / 2 + 0.03), belt - 0.5, z), V(0.05, 0.1, 0.4), S.steelBrushed, M.Metal)
		end
		c.detail(
			P(sx * (W / 2 + 0.18), belt + 0.3, s.cabFront - s.ws * 0.6),
			V(0.45, 0.3, 0.22),
			s.body,
			M.SmoothPlastic
		)
		-- wheels just proud of the body, dark wheel wells behind them
		for _, z in { s.axleF, s.axleR } do
			Shapes.wheel(c, P(sx * (W / 2 - 0.4), r, z), s.wheelD, 0.9, S.steelBrushed)
			c.detail(P(sx * (W / 2 + 0.01), 1.65, z), V(0.04, 1.3, s.wheelD + 0.3), col.rubber, M.SmoothPlastic)
		end
	end
	c.use(V(-W / 2 - 1, 2.5, cabMid))
	return { roofY = roofY + 0.2, cabMid = cabMid, cabLen = cabLen }
end

---------------------------------------------------------------------------------------------------
-- sedan: four-door saloon in a seeded colour (opts.color overrides)
---------------------------------------------------------------------------------------------------
local SEDAN_COLORS = {
	hex("#1B2A44"),
	hex("#121417"),
	hex("#A7ABB0"),
	hex("#6E1A1F"),
	hex("#E8E8E4"),
	hex("#2F4A3A"),
	hex("#4A4F55"),
}

local function sedanSpec(body: Color3): CarSpec
	return {
		L = 14.5,
		W = 6.2,
		wheelD = 2.4,
		axleF = -4.6,
		axleR = 4.6,
		belt = 2.75,
		roof = 4.6,
		cabFront = -2.0,
		cabBack = 2.6,
		ws = 1.8,
		rw = 1.5,
		body = body,
		trim = col.plasticBlack,
		chrome = false,
		grille = col.frameDark,
		glassT = 0.3,
	}
end

add({
	id = "sedan",
	category = "street",
	footprint = V(7.0, 4.8, 15.1),
	maxParts = 52,
	tags = { "street", "vehicle", "car" },
	build = function(c: Ctx)
		car(c, sedanSpec(c.color("color", c.rng:pick(SEDAN_COLORS))))
	end,
})

---------------------------------------------------------------------------------------------------
-- taxi: yellow cab with a checker band, METRO CAB door lettering and a roof sign (lit = available)
---------------------------------------------------------------------------------------------------
add({
	id = "taxi",
	category = "street",
	footprint = V(7.0, 5.55, 15.1),
	maxParts = 58,
	tags = { "street", "vehicle", "car", "taxi" },
	build = function(c: Ctx)
		local body = c.color("color", S.taxi)
		local spec = sedanSpec(body)
		local info = car(c, spec)
		local lit = c.bool("lit", true)
		c.detail(P(0, info.roofY + 0.06, info.cabMid), V(1.6, 0.12, 0.5), col.plasticBlack, M.SmoothPlastic)
		local roofSign = c.detail(P(0, info.roofY + 0.44, info.cabMid), V(2.2, 0.64, 0.7), S.white, M.SmoothPlastic)
		roofSign.Name = "RoofSign"
		roofSign:SetAttribute("Available", lit)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			c.sign(roofSign, Words.taxi, {
				face = face,
				font = Enum.Font.GothamBlack,
				color = hex("#1A1A1A"),
				bg = if lit then hex("#FFF3B0") else S.white,
				glow = lit,
				pixelsPerStud = 40,
				padding = 0.02,
			})
		end
		for _, sx in { -1, 1 } do
			local face = if sx < 0 then Enum.NormalId.Left else Enum.NormalId.Right
			local band =
				c.detail(P(sx * (spec.W / 2 + 0.02), spec.belt - 0.8, 0), V(0.03, 0.34, 6.2), S.black, M.SmoothPlastic)
			band.Name = "Checker"
			local gui = Gui.Core.surface(band, face, { pps = 20, maxDistance = 120 })
			Gui.Core.checker(gui, 36, 2, S.black, S.white)
			local door = c.detail(
				P(sx * (spec.W / 2 + 0.03), spec.belt - 0.35 - 0.32, spec.cabFront + 0.9),
				V(0.02, 0.4, 1.8),
				body
			)
			door.Transparency = 1
			c.sign(
				door,
				Words.cab,
				{ face = face, font = Enum.Font.GothamBlack, color = hex("#1A1A1A"), pixelsPerStud = 50 }
			)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- town_car: long black executive car with chrome grille, window trim, hood ornament and dark glass
---------------------------------------------------------------------------------------------------
add({
	id = "town_car",
	category = "street",
	footprint = V(7.2, 4.9, 17.6),
	maxParts = 54,
	tags = { "street", "vehicle", "car", "luxury" },
	build = function(c: Ctx)
		local body = c.color("color", S.black)
		local chrome = c.color("accent", col.chrome)
		local spec: CarSpec = {
			L = 17,
			W = 6.4,
			wheelD = 2.5,
			axleF = -5.9,
			axleR = 5.7,
			belt = 2.8,
			roof = 4.7,
			cabFront = -2.4,
			cabBack = 3.6,
			ws = 1.9,
			rw = 1.4,
			body = body,
			trim = chrome,
			chrome = true,
			grille = chrome,
			glassT = 0.12,
		}
		car(c, spec)
		c.dcyl(P(0, spec.belt + 0.12, -spec.L / 2 + 0.6), 0.25, 0.14, chrome, M.Metal)
		for _, sx in { -1, 1 } do
			c.detail(
				P(sx * (spec.W / 2 - 0.22), spec.belt + 0.03, (spec.cabFront - spec.ws + spec.cabBack + spec.rw) / 2),
				V(0.06, 0.06, spec.ws + (spec.cabBack - spec.cabFront) + spec.rw),
				chrome,
				M.Metal
			)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- city_bus: M15 low-floor bus, doors on the curb side (+X), LED destination board, side advert (-X)
---------------------------------------------------------------------------------------------------
add({
	id = "city_bus",
	category = "street",
	footprint = V(9.8, 11.1, 39.15),
	offset = V(0, 0, -0.28),
	maxParts = 52,
	tags = { "street", "vehicle", "bus", "transit" },
	build = function(c: Ctx)
		local L, W = 38, 8.4
		local body = c.color("color", hex("#F4F4F0"))
		local stripe = c.color("accent", hex("#1F4E8C"))
		local lit = c.bool("lit", true)
		local glass = hex("#22303B")
		local amber = hex("#FFB000")
		local wd = 3.4
		c.detail(P(0, 1.05, 0), V(W - 1, 0.5, L - 2), col.frameDark, M.SmoothPlastic)
		local shell = c.part(P(0, 5.75, 0), V(W, 8.9, L), body, M.SmoothPlastic)
		shell.Name = "Body"
		c.detail(P(0, 10.3, 0), V(W - 0.4, 0.2, L - 1), shade(body, -0.08), M.SmoothPlastic)
		c.detail(P(0, 10.75, 4), V(W - 2.4, 0.7, 6), shade(body, -0.12), M.Metal)
		-- side window bands with mullions
		for _, sx in { -1, 1 } do
			local face = if sx < 0 then Enum.NormalId.Left else Enum.NormalId.Right
			local band = c.detail(P(sx * (W / 2 + 0.02), 6.9, 1.5), V(0.04, 3.0, L - 7), glass, M.Glass)
			band.Reflectance = 0.2
			local gui = Gui.Core.surface(band, face, { pps = 8, maxDistance = 250 })
			for i = 1, 7 do
				Gui.Core.frame(gui, i / 8 - 0.006, 0, 0.012, 1, shade(body, -0.1))
			end
			c.detail(P(sx * (W / 2 + 0.02), 1.8, 0), V(0.04, 0.6, L - 0.4), stripe, M.SmoothPlastic)
			c.detail(P(sx * (W / 2 + 0.02), 5.05, 0), V(0.04, 0.12, L - 0.4), stripe, M.SmoothPlastic)
		end
		for _, z in { -L / 2 + 3.2, 2.0 } do
			local door = c.detail(P(W / 2 + 0.03, 4.8, z), V(0.06, 7.0, 2.8), glass, M.Glass)
			door.Name = "Door"
			door.Reflectance = 0.15
		end
		local ad = c.detail(P(-W / 2 - 0.03, 3.8, 5), V(0.04, 2.4, 14), S.navy, M.SmoothPlastic)
		ad.Name = "Advert"
		local brand = c.rng:pick(Words.ads)
		Gui.Art.ad(
			(Gui.Core.surface(ad, Enum.NormalId.Left, { pps = 12, maxDistance = 200 })),
			brand[1],
			brand[2],
			c.rng
		)
		-- front: windshield, destination board, lamps, bumper, mirrors
		local ws = c.detail(P(0, 6.6, -L / 2 - 0.03), V(W - 0.6, 4.2, 0.08), glass, M.Glass)
		ws.Reflectance = 0.2
		local dest = c.detail(P(0, 9.5, -L / 2 - 0.04), V(W - 2, 0.9, 0.06), hex("#0A0A0A"), M.SmoothPlastic)
		dest.Name = "Destination"
		c.sign(dest, Words.busRoute, {
			font = Enum.Font.Arcade,
			color = if lit then amber else shade(amber, -0.6),
			glow = lit,
			pixelsPerStud = 30,
			padding = 0.06,
		})
		local side = c.detail(P(W / 2 + 0.04, 8.9, -L / 2 + 6.5), V(0.04, 0.7, 3.2), hex("#0A0A0A"), M.SmoothPlastic)
		c.sign(side, Words.busRoute, {
			face = Enum.NormalId.Right,
			font = Enum.Font.Arcade,
			color = if lit then amber else shade(amber, -0.6),
			glow = lit,
			pixelsPerStud = 30,
		})
		for _, sx in { -1, 1 } do
			local x = sx * (W / 2 - 1.0)
			if lit then
				c.glow(P(x, 2.6, -L / 2 - 0.04), V(1.3, 0.5, 0.06), HEAD, 0.05)
			else
				c.detail(P(x, 2.6, -L / 2 - 0.04), V(1.3, 0.5, 0.06), hex("#D8DDE0"), M.Glass)
			end
			c.glow(P(x, 2.8, L / 2 + 0.04), V(1.0, 1.0, 0.06), TAIL, if lit then 0.1 else 0.55)
			local tip = V(sx * (W / 2 + 0.55), 8.7, -L / 2 - 0.6)
			Shapes.strut(c, V(sx * (W / 2 - 0.1), 9.4, -L / 2 + 0.3), tip, 0.14, col.plasticBlack, M.SmoothPlastic)
			c.detail(P(tip.X, tip.Y - 0.6, tip.Z), V(0.3, 1.2, 0.5), col.plasticBlack, M.SmoothPlastic)
		end
		for _, sz in { -1, 1 } do
			c.detail(P(0, 1.5, sz * (L / 2 + 0.15)), V(W - 0.2, 0.7, 0.3), col.plasticBlack, M.SmoothPlastic)
		end
		-- rear: engine grille, small rear window, route number
		c.detail(P(0, 3.6, L / 2 + 0.03), V(W - 2.4, 1.6, 0.05), col.frameDark, M.DiamondPlate)
		c.detail(P(0, 8.0, L / 2 + 0.03), V(W - 3, 1.8, 0.05), glass, M.Glass)
		local rear = c.detail(P(0, 9.5, L / 2 + 0.04), V(2.4, 0.7, 0.05), hex("#0A0A0A"), M.SmoothPlastic)
		c.sign(rear, string.match(Words.busRoute, "^%S+") or Words.busRoute, {
			face = Enum.NormalId.Back,
			font = Enum.Font.Arcade,
			color = if lit then amber else shade(amber, -0.6),
			glow = lit,
			pixelsPerStud = 30,
		})
		for _, sx in { -1, 1 } do
			for _, z in { -L / 2 + 7.2, L / 2 - 9 } do
				Shapes.wheel(c, P(sx * (W / 2 - 0.65), wd / 2, z), wd, 1.4, S.steelBrushed)
				c.detail(P(sx * (W / 2 + 0.01), 2.3, z), V(0.04, 2.0, wd + 0.5), col.rubber, M.SmoothPlastic)
			end
		end
		c.use(V(W / 2 + 1.5, 3, -L / 2 + 3.2))
	end,
})

return defs
