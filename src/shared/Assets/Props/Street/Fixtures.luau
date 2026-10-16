--!strict
-- Wall Street district street fixtures (category "street", polished): classic lamps, traffic
-- lights, benches, planter trees, bollards, flag poles, brass hydrants, manholes and crosswalks.
-- "Front" (-Z) faces the sidewalk user or the road.

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
-- street_lamp_classic: black cast-iron post with brass rings and a glass lantern. The bulb is tagged
-- "StreetLight" and carries a warm PointLight when opts.lit (default true).
---------------------------------------------------------------------------------------------------
add({
	id = "street_lamp_classic",
	category = "street",
	footprint = V(2.0, 14.6, 2.0),
	maxParts = 22,
	tags = { "street", "light", "lamp" },
	build = function(c: Ctx)
		local iron = c.color("color", IRON)
		local brass = c.color("accent", S.brass)
		local lit = c.bool("lit", true)
		c.cyl(P(0, 0.25, 0), 0.5, 2.0, iron, M.Metal)
		c.cyl(P(0, 1.1, 0), 1.2, 1.4, iron, M.Metal)
		c.dcyl(P(0, 1.76, 0), 0.12, 1.55, brass, M.Metal)
		c.dcyl(P(0, 2.1, 0), 0.6, 0.95, iron, M.Metal)
		c.cyl(P(0, 7.0, 0), 9.2, 0.5, iron, M.Metal)
		c.dcyl(P(0, 5.0, 0), 0.12, 0.64, brass, M.Metal)
		c.dcyl(P(0, 11.55, 0), 0.3, 0.8, iron, M.Metal)
		c.dcyl(P(0, 11.82, 0), 0.2, 1.1, brass, M.Metal)
		c.dcyl(P(0, 12.03, 0), 0.22, 0.95, iron, M.Metal)
		c.glass(P(0, 12.95, 0), V(1.2, 1.6, 1.2), hex("#F6E7C6"), if lit then 0.45 else 0.3)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				c.detail(P(sx * 0.62, 12.95, sz * 0.62), V(0.1, 1.62, 0.1), iron, M.Metal)
			end
		end
		local bulb = Shapes.bulb(c, P(0, 12.9, 0), 0.7, S.warmLight, lit)
		bulb.Name = "Lamp"
		c.tag(bulb, "StreetLight")
		Shapes.lamp(bulb, lit, S.warmLight, 32, 1.4)
		c.dcyl(P(0, 13.85, 0), 0.2, 1.6, iron, M.Metal)
		c.dcyl(P(0, 14.1, 0), 0.3, 1.0, iron, M.Metal)
		c.dball(P(0, 14.4, 0), 0.4, brass, M.Metal)
	end,
})

---------------------------------------------------------------------------------------------------
-- traffic_light: post-mounted three-lamp signal facing -Z with a pedestrian head and push button.
-- opts.state "red" | "amber" | "green" picks the lit lamp. Lamps are named LampRed/LampAmber/LampGreen and
-- the housing is tagged "TrafficLight" so runtime code can cycle them.
---------------------------------------------------------------------------------------------------
local SIGNAL = {
	red = hex("#FF3B30"),
	amber = hex("#FFB000"),
	green = hex("#2BD67B"),
}

add({
	id = "traffic_light",
	category = "street",
	footprint = V(1.8, 12.7, 2.3),
	offset = V(0, 0, -0.55),
	maxParts = 18,
	tags = { "street", "light", "traffic" },
	build = function(c: Ctx)
		local body = c.color("color", IRON)
		local state = c.pick("state", { "red", "amber", "green" }, c.rng:pick({ "red", "amber", "green" }))
		c.cyl(P(0, 0.3, 0), 0.6, 1.2, body, M.Metal)
		c.cyl(P(0, 6.3, 0), 11.4, 0.55, body, M.Metal)
		c.dball(P(0, 12.05, 0), 0.6, body, M.Metal)
		c.detail(P(0, 10.6, -0.3), V(1.8, 4.2, 0.06), body, M.Metal)
		local head = c.part(P(0, 10.6, -0.78), V(1.3, 3.6, 0.9), hex("#2A2D31"), M.Metal)
		head.Name = "SignalHead"
		head:SetAttribute("State", state)
		c.tag(head, "TrafficLight")
		local order = { "red", "amber", "green" }
		for i, name in order do
			local y = 10.6 + (2 - i) * 1.15
			local on = name == state
			local lens = c.dcylZ(
				P(0, y, -1.24),
				0.06,
				0.85,
				if on then SIGNAL[name] else shade(SIGNAL[name], -0.7),
				if on then M.Neon else M.SmoothPlastic
			)
			lens.Name = "Lamp" .. string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
			if on then
				c.light(lens, "point", { Range = 9, Brightness = 1.2, Color = SIGNAL[name] })
			end
			c.detail(P(0, y + 0.5, -1.47), V(1.0, 0.08, 0.46), hex("#2A2D31"), M.Metal)
		end
		-- pedestrian head and push button
		c.detail(P(0, 7.4, -0.62), V(1.1, 1.1, 0.6), hex("#2A2D31"), M.Metal)
		local walk = state == "red"
		local ped = c.detail(P(0, 7.4, -0.93), V(0.9, 0.9, 0.02), Color3.new(0, 0, 0), M.SmoothPlastic)
		ped.Name = "PedSignal"
		c.sign(ped, if walk then Words.walk else Words.dontWalk, {
			font = Enum.Font.GothamBlack,
			color = if walk then hex("#F2F2F2") else hex("#FF8A2B"),
			glow = true,
			pixelsPerStud = 60,
			padding = 0.1,
		})
		local btn = c.detail(P(0, 3.8, -0.4), V(0.45, 0.6, 0.25), hex("#C9A13B"), M.Metal)
		c.sign(btn, Words.pushButton, { font = Enum.Font.GothamBold, color = IRON, pixelsPerStud = 80, padding = 0.15 })
		c.use(V(0, 3.8, -1.2))
	end,
})

---------------------------------------------------------------------------------------------------
-- bench_classic: black cast-iron ends, oak slats on a leaning back and a small brass dedication plate.
-- Hidden seat pads under the slats become Seats when opts.seat = true.
---------------------------------------------------------------------------------------------------
add({
	id = "bench_classic",
	category = "street",
	footprint = V(6.1, 3.4, 2.1),
	maxParts = 24,
	tags = { "street", "seat", "bench" },
	build = function(c: Ctx)
		local L = 6
		local iron = c.color("accent", IRON)
		local wood = c.color("color", S.oak)
		for _, sx in { -1, 1 } do
			local x = sx * (L / 2 - 0.1)
			c.detail(P(x, 0.8, -0.75), V(0.22, 1.6, 0.25), iron, M.Metal)
			Shapes.strut(c, V(x, 0.05, 0.7), V(x, 3.25, 0.98), 0.22, iron, M.Metal)
			c.detail(P(x, 1.55, 0), V(0.2, 0.16, 1.75), iron, M.Metal)
			c.detail(P(x, 2.45, -0.15), V(0.24, 0.12, 1.5), iron, M.Metal)
		end
		c.detail(P(0, 0.78, -0.1), V(0.18, 1.55, 0.2), iron, M.Metal)
		for _, z in { -0.62, -0.21, 0.2, 0.61 } do
			c.detail(P(0, 1.69, z), V(L, 0.12, 0.34), shade(wood, c.rng:range(-0.06, 0.04)), M.Wood)
		end
		-- back slats follow the rear uprights' lean (0.28 back over 3.2 up), just in front of them
		local tilt = math.deg(math.atan2(0.28, 3.2))
		for i, y in { 2.2, 2.62, 3.04 } do
			local z = 0.73 + (y - 0.05) * (0.28 / 3.2) - 0.14
			local slatCf = P(0, y, z) * R(tilt, 0, 0)
			c.detail(slatCf, V(L, 0.3, 0.1), shade(wood, c.rng:range(-0.06, 0.04)), M.Wood)
			if i == 2 then
				local plate = c.detail(slatCf * P(0, 0, -0.06), V(1.1, 0.18, 0.02), S.brass, M.Metal)
				c.sign(plate, Words.benchPlaque, {
					font = Enum.Font.Garamond,
					color = S.black,
					pixelsPerStud = 120,
					padding = 0.05,
				})
			end
		end
		for _, sx in { -1, 1 } do
			local pad = c.seat(P(sx * (L / 4), 1.57, 0), V(L / 2 - 0.4, 0.1, 1.4), wood, M.Wood)
			pad.Transparency = 1
			pad.Name = "SeatPad"
		end
		c.use(V(0, 2, -0.6))
	end,
})

---------------------------------------------------------------------------------------------------
-- planter_tree: granite planter box with coping, brass band, groundcover and a street tree.
-- opts.variant "maple" (default) | "topiary"
---------------------------------------------------------------------------------------------------
add({
	id = "planter_tree",
	category = "street",
	footprint = V(7.2, 13.4, 7.3),
	maxParts = 24,
	tags = { "street", "plant", "tree" },
	build = function(c: Ctx)
		local stone = c.color("color", S.granite)
		local variant = c.pick("variant", { "maple", "topiary" }, "maple")
		c.part(P(0, 1.1, 0), V(4.4, 2.2, 4.4), stone, M.Granite)
		local cope = shade(stone, 0.25)
		for _, sz in { -1, 1 } do
			c.detail(P(0, 2.3, sz * 2.2), V(4.8, 0.2, 0.4), cope, M.Granite)
			c.detail(P(sz * 2.2, 2.3, 0), V(0.4, 0.2, 4.0), cope, M.Granite)
		end
		c.detail(P(0, 1.85, 0), V(4.46, 0.12, 4.46), c.color("accent", S.brass), M.Metal)
		c.detail(P(0, 2.2, 0), V(4.0, 0.1, 4.0), col.soil, M.Ground)
		for i = 1, 3 do
			local a = i * 2.1 + c.rng:range(-0.3, 0.3)
			c.dball(P(math.cos(a) * 1.25, 2.35, math.sin(a) * 1.25), c.rng:range(0.9, 1.2), S.foliageLight, M.Grass)
		end
		local pal = { S.foliage, S.foliageLight, col.leafDark }
		if variant == "topiary" then
			c.cyl(P(0, 4.6, 0), 4.8, 0.35, col.trunk, M.Wood)
			c.dball(P(0, 8.2, 0), 4.4, S.foliage, M.Grass)
			c.dball(P(0, 5.8, 0), 0.9, S.foliage, M.Grass)
			return
		end
		c.cyl(P(0, 5.7, 0), 7.0, 0.55, col.trunk, M.Wood)
		Shapes.strut(c, V(0, 7.2, 0), V(1.3, 9.2, 0.5), 0.3, col.trunk, M.Wood)
		Shapes.strut(c, V(0, 7.6, 0), V(-1.1, 9.5, -0.6), 0.3, col.trunk, M.Wood)
		local j = function(): number
			return c.rng:range(-0.2, 0.2)
		end
		c.dball(P(0, 10.5, 0), 4.6, pal[1], M.Grass)
		c.dball(P(1.9 + j(), 9.8, 0.4), 3.4, pal[2], M.Grass)
		c.dball(P(-1.7 + j(), 10.1, -0.6), 3.4, pal[3], M.Grass)
		c.dball(P(0.3, 10.2, 1.9 + j()), 3.4, pal[2], M.Grass)
		c.dball(P(-0.4, 9.9, -1.8 + j()), 3.4, pal[1], M.Grass)
		c.dball(P(0.2 + j(), 11.9, 0.1), 3.0, pal[2], M.Grass)
	end,
})

---------------------------------------------------------------------------------------------------
-- bollard: black steel bollard with a brass ring and dome cap. opts.lit adds a glowing LED band.
---------------------------------------------------------------------------------------------------
add({
	id = "bollard",
	category = "street",
	footprint = V(1.0, 3.3, 1.0),
	maxParts = 8,
	tags = { "street", "barrier" },
	build = function(c: Ctx)
		local body = c.color("color", IRON)
		local brass = c.color("accent", S.brass)
		c.dcyl(P(0, 0.06, 0), 0.12, 1.0, shade(body, -0.2), M.Metal)
		c.cyl(P(0, 1.45, 0), 2.7, 0.85, body, M.Metal)
		c.dcyl(P(0, 2.45, 0), 0.14, 0.9, brass, M.Metal)
		c.dball(P(0, 2.8, 0), 0.85, body, M.Metal)
		c.dball(P(0, 3.2, 0), 0.22, brass, M.Metal)
		if c.bool("lit", false) then
			c.dcyl(P(0, 2.15, 0), 0.1, 0.87, S.warmLight, M.Neon)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- flag_pole: granite plinth, white pole, gold finial and a fictional flag flying toward +X.
-- opts.variant 1-4 (see Gui.Art.flag): 1 Street district, 2 Metropolitan Exchange, 3 city, 4 Eastbridge.
---------------------------------------------------------------------------------------------------
add({
	id = "flag_pole",
	category = "street",
	footprint = V(8.45, 30.6, 2.4),
	offset = V(3.0, 0, 0),
	maxParts = 12,
	tags = { "street", "flag" },
	build = function(c: Ctx)
		local variant = c.int("variant", c.rng:int(1, 4), 1, 4)
		c.part(P(0, 0.5, 0), V(2.4, 1.0, 2.4), S.granite, M.Granite)
		c.detail(P(0, 1.1, 0), V(2.0, 0.2, 2.0), S.graniteLight, M.Granite)
		c.cyl(P(0, 15.6, 0), 29.0, 0.4, c.color("color", S.white), M.Metal)
		c.dcyl(P(0, 1.35, 0), 0.3, 0.6, S.brass, M.Metal)
		c.dcyl(P(0, 30.1, 0), 0.2, 0.5, S.gold, M.Metal)
		c.dball(P(0, 30.3, 0), 0.6, S.gold, M.Metal)
		local swing = c.rng:range(-8, 8)
		local fcf = P(0.22, 27.5, 0) * R(0, swing, c.rng:range(-1.5, 0)) * P(3.5, 0, 0)
		local flag = c.detail(fcf, V(7.0, 4.2, 0.05), Color3.new(1, 1, 1), M.Fabric)
		flag.Name = "Flag"
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui, W, H = Gui.Core.surface(flag, face, { pps = 20, maxDistance = 300 })
			Gui.Art.flag(gui, W, H, variant, c.rng)
		end
		for _, y in { 29.4, 25.6 } do
			c.detail(P(0.25, y, 0), V(0.12, 0.12, 0.12), S.steelBrushed, M.Metal)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- hydrant_brass: polished black hydrant with brass caps, flange and a chained nozzle cap
---------------------------------------------------------------------------------------------------
add({
	id = "hydrant_brass",
	category = "street",
	footprint = V(1.55, 2.4, 1.4),
	offset = V(0, 0, -0.09),
	maxParts = 14,
	tags = { "street" },
	build = function(c: Ctx)
		local body = c.color("color", S.black)
		local brass = c.color("accent", S.brass)
		c.dcyl(P(0, 0.1, 0), 0.2, 1.2, brass, M.Metal)
		c.cyl(P(0, 0.95, 0), 1.5, 0.85, body, M.SmoothPlastic)
		c.dcyl(P(0, 1.75, 0), 0.14, 1.0, brass, M.Metal)
		c.dball(P(0, 1.85, 0), 0.85, body, M.SmoothPlastic)
		c.dcyl(P(0, 2.3, 0), 0.18, 0.28, brass, M.Metal)
		for _, sx in { -1, 1 } do
			c.dcylX(P(sx * 0.5, 1.15, 0), 0.35, 0.38, body, M.SmoothPlastic)
			c.dcylX(P(sx * 0.72, 1.15, 0), 0.1, 0.44, brass, M.Metal)
		end
		c.dcylZ(P(0, 1.05, -0.5), 0.35, 0.52, body, M.SmoothPlastic)
		c.dcylZ(P(0, 1.05, -0.72), 0.1, 0.6, brass, M.Metal)
		Shapes.tube(c, V(0.2, 1.0, -0.74), V(0.38, 0.85, -0.42), 0.03, brass, M.Metal)
	end,
})

---------------------------------------------------------------------------------------------------
-- manhole: cast-iron cover and frame flush with the street, embossed "METRO WATER". opts.steam = true adds
-- a few rising puffs.
---------------------------------------------------------------------------------------------------
add({
	id = "manhole",
	category = "street",
	footprint = V(3.3, 0.11, 3.3),
	maxParts = 8,
	tags = { "street", "ground" },
	build = function(c: Ctx)
		local iron = c.color("color", hex("#2B2C2E"))
		c.dcyl(P(0, 0.03, 0), 0.06, 3.3, shade(iron, -0.2), M.Metal)
		c.cyl(P(0, 0.065, 0), 0.06, 3.0, iron, M.DiamondPlate)
		local face = c.detail(P(0, 0.1, 0), V(2.1, 0.01, 2.1), iron)
		face.Transparency = 1
		face.Name = "Emboss"
		local gui = Gui.Core.surface(face, Enum.NormalId.Top, { pps = 60, maxDistance = 60 })
		local ink = shade(iron, 0.25)
		for i = 0, 4 do
			Gui.Core.frame(gui, 0.1 + i * 0.2 - 0.01, 0.12, 0.02, 0.76, ink, 0.2)
		end
		local band = Gui.Core.frame(gui, 0.06, 0.38, 0.88, 0.24, iron)
		Gui.Core.label(band, Words.sewer, 0.04, 0.05, 0.92, 0.9, ink, {
			font = Enum.Font.GothamBlack,
			align = Enum.TextXAlignment.Center,
		})
		if c.bool("steam", false) then
			for i = 1, 3 do
				local puff = c.dball(
					P(c.rng:range(-0.4, 0.4), 0.6 + i * 0.9, c.rng:range(-0.4, 0.4)),
					0.8 + i * 0.5,
					S.white,
					M.SmoothPlastic
				)
				puff.Transparency = 0.6 + i * 0.1
			end
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- crosswalk: zebra bars across the road. The crossing runs along X for opts.length (8-120, default 40);
-- bars are 2 studs wide and opts.width (4-16, default 8) long, flush with the asphalt.
---------------------------------------------------------------------------------------------------
add({
	id = "crosswalk",
	category = "street",
	footprint = V(38, 0.04, 8),
	maxParts = 32,
	tags = { "street", "ground", "road" },
	scales = { length = 120 },
	build = function(c: Ctx)
		local L = c.num("length", 40, 8, 120)
		local Wd = c.num("width", 8, 4, 16)
		local paint = c.color("color", S.asphaltLine)
		local n = math.max(2, math.floor(L / 4 + 0.5))
		local pitch = L / n
		for i = 1, n do
			local bar = c.detail(
				P(-L / 2 + pitch * (i - 0.5), 0.02, 0),
				V(2, 0.04, Wd),
				shade(paint, c.rng:range(-0.12, 0)),
				M.SmoothPlastic
			)
			bar.CastShadow = false
		end
	end,
})

return defs
