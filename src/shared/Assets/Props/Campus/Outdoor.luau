--!strict
-- Eastbridge street furniture (gritty): dumpster, trash can, worn bench, bus shelter, sodium street lamp,
-- fire hydrant, newspaper box, vending machine, picnic table, mailbox and traffic cone.
-- Weathering (rust patches, missing slats, ajar lids, leaning poles) comes from the seeded Rng, so the
-- same seed (or the same placement) always looks the same. "Front" (-Z) faces the street or the user.

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

-- Rust or grime patch on a face: lcf is the patch centre on the surface, facing -Z.
local function patch(c: Ctx, lcf: CFrame, w: number, h: number, color: Color3?)
	c.detail(
		lcf * R(0, 0, c.rng:range(-20, 20)),
		V(w, h, 0.02),
		color or c.rng:pick({ C.rust, C.rustDark }),
		M.CorrodedMetal
	)
end

-- Painted or marker text on a transparent carrier just in front of a surface.
local function stencil(c: Ctx, lcf: CFrame, w: number, h: number, text: string, color: Color3, font: Enum.Font)
	local carrier = c.detail(lcf, V(w, h, 0.01), color)
	carrier.Transparency = 1
	carrier.Name = "Stencil"
	c.sign(carrier, text, { font = font, color = color, pixelsPerStud = 40, padding = 0.04 })
end

---------------------------------------------------------------------------------------------------
-- dumpster: front-load waste bin, black lids (one usually ajar), fork pockets, rust and a stencil
---------------------------------------------------------------------------------------------------
add({
	id = "dumpster",
	category = "campus",
	footprint = V(6.7, 4.6, 3.8),
	maxParts = 18,
	tags = { "street", "gritty", "trash" },
	build = function(c: Ctx)
		local body = c.color("color", C.dumpster)
		c.part(P(0, 2.2, 0), V(6.2, 3.6, 3.6), body, M.Metal)
		c.detail(P(0, 4.05, 0), V(6.4, 0.12, 3.8), shade(body, -0.25), M.Metal)
		local ajar = c.rng:int(0, 2)
		for i, sx in { -1, 1 } do
			local open = if i == ajar then c.rng:range(6, 10) else c.rng:range(0, 1.5)
			c.detail(
				P(sx * 1.57, 4.11, 1.9) * R(open, 0, 0) * P(0, 0.06, -1.9),
				V(3.1, 0.12, 3.8),
				col.plasticBlack,
				M.Plastic
			)
		end
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 3.2, 2.6, 0), V(0.3, 0.5, 3.0), shade(body, -0.3), M.Metal)
			for _, sz in { -1, 1 } do
				c.detail(P(sx * 2.7, 0.2, sz * 1.45), V(0.5, 0.4, 0.5), C.steel, M.Metal)
			end
		end
		for _ = 1, 3 do
			patch(
				c,
				P(c.rng:range(-2.6, 2.6), c.rng:range(0.9, 3.4), -1.81),
				c.rng:range(0.5, 1.4),
				c.rng:range(0.3, 0.9)
			)
		end
		stencil(c, P(0, 2.9, -1.82), 4, 0.6, Words.waste, hex("#E9E2CF"), Enum.Font.SpecialElite)
	end,
})

---------------------------------------------------------------------------------------------------
-- trash_can: banded municipal can, often missing its lid, with trash poking out and litter at its foot
---------------------------------------------------------------------------------------------------
add({
	id = "trash_can",
	category = "campus",
	footprint = V(2.1, 3.4, 2.1),
	maxParts = 12,
	tags = { "street", "gritty", "trash" },
	build = function(c: Ctx)
		local body = c.color("color", hex("#3D4A3B"))
		c.cyl(P(0, 1.5, 0), 3.0, 2.0, body, M.CorrodedMetal)
		c.dcyl(P(0, 3.0, 0), 0.12, 2.1, shade(body, -0.3), M.Metal)
		for _, y in { 0.8, 2.2 } do
			c.dcyl(P(0, y, 0), 0.1, 2.05, shade(body, -0.3), M.Metal)
		end
		if c.rng:chance(0.5) then
			c.dcyl(P(0, 3.14, 0) * R(c.rng:range(-4, 4), 0, c.rng:range(-4, 4)), 0.16, 2.1, shade(body, -0.15), M.Metal)
		else
			c.dball(P(c.rng:range(-0.3, 0.3), 2.95, c.rng:range(-0.3, 0.3)), 1.1, col.plasticBlack, M.Plastic)
			c.dball(P(0.45, 3.05, -0.2), 0.35, C.paper, M.SmoothPlastic)
			c.dcyl(P(-0.4, 3.12, 0.3) * R(25, 0, 10), 0.4, 0.22, hex("#C0392B"), M.SmoothPlastic)
		end
		for _ = 1, c.rng:int(0, 2) do
			local a = c.rng:range(0, math.pi * 2)
			c.dball(P(math.cos(a) * 1.05, 0.12, math.sin(a) * 1.05), 0.24, C.paper, M.SmoothPlastic)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- bench_worn: weathered slat bench on rusty iron ends; a slat may be missing, some sit crooked, and the
-- back may carry marker graffiti
---------------------------------------------------------------------------------------------------
add({
	id = "bench_worn",
	category = "campus",
	footprint = V(6.1, 3.45, 2.0),
	maxParts = 15,
	tags = { "street", "gritty", "seat", "bench" },
	build = function(c: Ctx)
		local L = 6
		local iron = c.color("accent", C.steel)
		local wood = c.color("color", C.woodWorn)
		for _, sx in { -1, 1 } do
			local x = sx * (L / 2 - 0.5)
			c.detail(P(x, 0.85, -0.7), V(0.2, 1.7, 0.2), iron, M.CorrodedMetal)
			c.detail(P(x, 1.58, 0.72) * R(10, 0, 0), V(0.2, 3.1, 0.2), iron, M.CorrodedMetal)
			c.detail(P(x, 1.65, 0), V(0.2, 0.15, 1.7), iron, M.CorrodedMetal)
		end
		local missing = if c.rng:chance(0.3) then c.rng:int(1, 4) else 0
		for i, z in { -0.6, -0.2, 0.2, 0.6 } do
			if i ~= missing then
				local tone = shade(wood, c.rng:range(-0.15, 0.08))
				c.seat(
					P(c.rng:range(-0.08, 0.08), 1.79, z) * R(0, c.rng:range(-1.5, 1.5), c.rng:range(-0.6, 0.6)),
					V(L, 0.12, 0.32),
					tone,
					M.WoodPlanks
				)
			end
		end
		for i, y in { 2.3, 2.75, 3.2 } do
			local z = 0.8 + (y - 1.58) * math.tan(math.rad(10))
			local slat = c.detail(
				P(0, y, z) * R(10, 0, c.rng:range(-0.8, 0.8)),
				V(L, 0.3, 0.1),
				shade(wood, c.rng:range(-0.15, 0.05)),
				M.WoodPlanks
			)
			if i == 2 and c.rng:chance(0.45) then
				c.sign(slat, c.rng:pick(Words.graffiti), {
					font = Enum.Font.PermanentMarker,
					color = c.rng:pick({ C.graffitiTeal, C.graffitiMagenta, hex("#F2F2F2") }),
					pixelsPerStud = 30,
					padding = 0.02,
				})
			end
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- bus_shelter: corroded frame, scratched glass (one pane sometimes boarded with plywood), a side advert,
-- bench, route sign "9 EASTBRIDGE" and a taped timetable
---------------------------------------------------------------------------------------------------
add({
	id = "bus_shelter",
	category = "campus",
	footprint = V(10.6, 8.6, 5.0),
	maxParts = 20,
	tags = { "street", "gritty", "transit", "seat" },
	build = function(c: Ctx)
		local frame = c.color("accent", C.steel)
		c.part(P(0, 0.1, 0), V(10.6, 0.2, 5), C.concrete, M.Concrete)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				c.part(P(sx * 4.8, 4.1, sz * 2.0), V(0.3, 7.8, 0.3), frame, M.CorrodedMetal)
			end
		end
		c.part(P(0, 8.15, 0), V(10.4, 0.3, 5), frame, M.CorrodedMetal)
		c.detail(P(0, 7.95, -2.45), V(10.4, 0.6, 0.1), c.color("color", C.busYellow), M.Metal)
		local boarded = if c.rng:chance(0.3) then c.rng:int(1, 2) else 0
		for i, sx in { -1, 1 } do
			if i == boarded then
				c.part(P(sx * 2.4, 4.4, 2.0), V(4.7, 6.4, 0.12), C.woodWorn, M.WoodPlanks)
			else
				local g = c.glass(P(sx * 2.4, 4.4, 2.0), V(4.7, 6.4, 0.1), hex("#A9B7BD"), 0.55, true)
				g.Reflectance = 0.15
			end
		end
		local side = c.part(P(-4.8, 4.4, 0), V(0.12, 6.4, 3.7), C.charcoal, M.Metal)
		local adGui, adW, adH = Gui.Core.surface(side, Enum.NormalId.Left, { glow = true, pps = 16, maxDistance = 120 })
		local ad = c.rng:pick(Words.ads)
		Gui.Art.ad(adGui, ad[1], ad[2], c.rng, adW, adH)
		c.seat(P(0, 1.7, 1.4), V(6, 0.2, 1.0), C.woodWorn, M.WoodPlanks)
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 2.6, 0.95, 1.4), V(0.2, 1.5, 0.8), frame, M.CorrodedMetal)
		end
		local sign = c.detail(P(4.8, 6.6, -2.4), V(1.3, 1.1, 0.06), hex("#1F4E8C"), M.Metal)
		c.sign(sign, Words.campusBus, { font = Enum.Font.GothamBold, pixelsPerStud = 50, padding = 0.1 })
		local sched = c.detail(P(2.4, 4.2, 1.93), V(1.2, 1.6, 0.02), C.paper, M.SmoothPlastic)
		c.sign(
			sched,
			Words.busSchedule,
			{ font = Enum.Font.SpecialElite, color = C.ink, pixelsPerStud = 50, padding = 0.1 }
		)
		if c.rng:chance(0.6) then
			c.dball(P(c.rng:range(-3, 3), 0.32, c.rng:range(-1.5, 0)), 0.24, C.paper, M.SmoothPlastic)
		end
		c.use(V(0, 2.5, -2))
	end,
})

---------------------------------------------------------------------------------------------------
-- street_lamp_sodium: cobra-head lamp on a corroded pole. The pole stands at cf; the head reaches toward
-- -Z (the road). Lens part is tagged "StreetLight" (warm orange PointLight); some lamps get attribute
-- Flicker = true for EnvironmentController. opts.lit (default true).
---------------------------------------------------------------------------------------------------
add({
	id = "street_lamp_sodium",
	category = "campus",
	footprint = V(1.4, 17.0, 5.6),
	offset = V(0, 0, -2.1),
	maxParts = 10,
	tags = { "street", "gritty", "light", "lamp" },
	build = function(c: Ctx)
		local lit = c.bool("lit", true)
		local steel = c.color("color", C.steel)
		c.part(P(0, 0.6, 0), V(1.4, 1.2, 1.4), C.concreteStain, M.Concrete)
		local lean = P(0, 1.2, 0) * R(c.rng:range(-1.5, 1.5), 0, c.rng:range(-1.5, 1.5))
		c.cyl(lean * P(0, 7.6, 0), 15.2, 0.5, steel, M.CorrodedMetal)
		c.detail(lean * P(0, 3.0, -0.27), V(0.45, 0.9, 0.08), shade(steel, 0.1), M.Metal)
		local top = lean * P(0, 15.0, 0)
		Shapes.tube(c, top.Position, (top * P(0, 0.7, -2.6)).Position, 0.22, steel, M.CorrodedMetal)
		local head = top * P(0, 0.55, -3.4)
		c.detail(head, V(1.0, 0.45, 1.8), steel, M.Metal)
		local lens = if lit
			then c.glow(head * P(0, -0.26, 0), V(0.8, 0.06, 1.4), C.sodium, 0.05)
			else c.detail(head * P(0, -0.26, 0), V(0.8, 0.06, 1.4), shade(C.sodium, -0.4), M.SmoothPlastic)
		lens.Name = "Lamp"
		c.tag(lens, "StreetLight")
		Shapes.lamp(lens, lit, C.sodium, 45, 1.6)
		if c.rng:chance(0.25) then
			lens:SetAttribute("Flicker", true)
		end
		if c.rng:chance(0.6) then
			local flyer = c.detail(lean * P(0, 4.6, -0.26), V(0.7, 0.9, 0.01), C.paper, M.SmoothPlastic)
			local f = c.rng:pick(Words.flyers)
			c.sign(flyer, f[1], { font = Enum.Font.SpecialElite, color = C.ink, pixelsPerStud = 60 })
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- fire_hydrant: chipped red paint over rust, faded yellow bonnet
---------------------------------------------------------------------------------------------------
add({
	id = "fire_hydrant",
	category = "campus",
	footprint = V(1.5, 2.5, 1.3),
	offset = V(0, 0, -0.1),
	maxParts = 12,
	tags = { "street", "gritty" },
	build = function(c: Ctx)
		local red = c.color("color", hex("#8E2B22"))
		local cap = c.color("accent", hex("#B8963A"))
		c.dcyl(P(0, 0.12, 0), 0.24, 1.1, shade(red, -0.25), M.CorrodedMetal)
		c.cyl(P(0, 1.0, 0), 1.6, 0.8, red, M.CorrodedMetal)
		c.dcyl(P(0, 1.85, 0), 0.15, 0.95, shade(red, -0.2), M.CorrodedMetal)
		c.dball(P(0, 1.95, 0), 0.8, cap, M.CorrodedMetal)
		c.dcyl(P(0, 2.4, 0), 0.16, 0.22, shade(cap, -0.3), M.Metal)
		for _, sx in { -1, 1 } do
			c.dcylX(P(sx * 0.5, 1.2, 0), 0.35, 0.36, red, M.CorrodedMetal)
			c.dcylX(P(sx * 0.7, 1.2, 0), 0.08, 0.42, cap, M.Metal)
		end
		c.dcylZ(P(0, 1.1, -0.5), 0.35, 0.5, red, M.CorrodedMetal)
		c.dcylZ(P(0, 1.1, -0.7), 0.08, 0.56, cap, M.Metal)
	end,
})

---------------------------------------------------------------------------------------------------
-- newspaper_box: coin-op box on a pedestal with today's front page behind scratched glass
---------------------------------------------------------------------------------------------------
add({
	id = "newspaper_box",
	category = "campus",
	footprint = V(1.65, 3.1, 1.5),
	maxParts = 12,
	tags = { "street", "gritty" },
	build = function(c: Ctx)
		local body = c.color("color", c.rng:pick({ hex("#2C5E8A"), hex("#8A2C2C"), hex("#2F5A3A") }))
		c.detail(P(0, 0.03, 0), V(1.2, 0.06, 1.0), C.steel, M.Metal)
		c.part(P(0, 0.6, 0), V(0.25, 1.2, 0.25), C.steel, M.Metal)
		c.part(P(0, 2.1, 0), V(1.6, 1.8, 1.4), body, M.Metal)
		local paper = c.detail(P(0, 2.4, -0.705), V(1.2, 0.8, 0.01), C.paper, M.SmoothPlastic)
		paper.Name = "FrontPage"
		local gui = Gui.Core.surface(paper, Enum.NormalId.Front, { pps = 90, maxDistance = 50 })
		Gui.Art.newspaper(gui, c.rng)
		c.glass(P(0, 2.4, -0.72), V(1.26, 0.86, 0.02), hex("#C9D3D6"), 0.65)
		c.detail(P(0.48, 1.6, -0.72), V(0.3, 0.3, 0.06), C.steel, M.Metal)
		c.detail(P(0, 1.85, -0.75), V(0.6, 0.08, 0.08), C.steel, M.Metal)
		c.detail(P(0, 3.05, 0), V(1.65, 0.1, 1.45), shade(body, -0.25), M.Metal)
		local band = c.detail(P(0, 2.9, -0.705), V(1.5, 0.2, 0.01), C.paper, M.SmoothPlastic)
		c.sign(band, Words.paperName, { font = Enum.Font.Bodoni, color = C.ink, pixelsPerStud = 60, padding = 0.04 })
		patch(c, P(c.rng:range(-0.5, 0.5), c.rng:range(1.4, 2.0), -0.71), 0.4, 0.3)
	end,
})

---------------------------------------------------------------------------------------------------
-- vending_machine: glowing product window (SurfaceLight when lit), keypad, coin slot, stickers and,
-- sometimes, an OUT OF ORDER sign
---------------------------------------------------------------------------------------------------
add({
	id = "vending_machine",
	category = "campus",
	footprint = V(3.2, 6.5, 2.6),
	maxParts = 15,
	tags = { "appliance", "gritty", "light" },
	build = function(c: Ctx)
		local lit = c.bool("lit", true)
		local body = c.color("color", c.rng:pick({ hex("#A3242C"), hex("#1F4E8C"), hex("#2B2B2B") }))
		local brand = c.rng:pick(Words.vending)
		c.part(P(0, 3.25, 0.1), V(3.2, 6.5, 2.4), body, M.Metal)
		local window = c.detail(P(-0.4, 3.9, -1.11), V(2.1, 4.4, 0.04), hex("#0E1116"), M.SmoothPlastic)
		window.Name = "Window"
		local gui = Gui.Core.surface(window, Enum.NormalId.Front, { glow = lit, pps = 30, maxDistance = 120 })
		Gui.Art.vending(gui, brand, c.rng)
		if lit then
			c.light(
				window,
				"surface",
				{ Face = Enum.NormalId.Front, Range = 10, Brightness = 1.2, Color = hex("#DCEBFF") }
			)
		end
		c.glass(P(-0.4, 3.9, -1.14), V(2.2, 4.5, 0.03), hex("#DDEFF5"), 0.75)
		c.detail(P(1.1, 3.9, -1.11), V(0.8, 4.4, 0.04), shade(body, -0.35), M.Metal)
		c.glow(P(1.1, 4.4, -1.135), V(0.45, 0.6, 0.02), hex("#7CFC9A"), if lit then 0.2 else 0.7)
		c.detail(P(1.1, 3.4, -1.14), V(0.3, 0.4, 0.03), C.steel, M.Metal)
		c.detail(P(-0.4, 1.0, -1.12), V(2.0, 0.6, 0.06), col.plasticBlack, M.SmoothPlastic)
		local header = c.detail(P(0, 6.2, -1.11), V(3.0, 0.5, 0.04), hex("#F4F1EA"), M.SmoothPlastic)
		c.sign(header, brand, { font = Enum.Font.LuckiestGuy, color = body, pixelsPerStud = 40, glow = lit })
		c.detail(P(0, 0.1, 0.1), V(3.0, 0.2, 2.3), col.plasticBlack, M.SmoothPlastic)
		c.detail(
			P(c.rng:range(-1.2, 1.2), c.rng:range(1.6, 2.4), -1.12) * R(0, 0, c.rng:range(-15, 15)),
			V(0.5, 0.35, 0.01),
			c.rng:pick({ C.mustard, C.graffitiTeal, C.paper }),
			M.SmoothPlastic
		)
		if c.rng:chance(0.15) then
			local sign = c.detail(P(-0.4, 4.6, -1.17) * R(0, 0, -4), V(1.4, 0.6, 0.01), C.paper, M.SmoothPlastic)
			c.sign(
				sign,
				Words.outOfOrder,
				{ font = Enum.Font.PermanentMarker, color = hex("#B22222"), pixelsPerStud = 50 }
			)
		end
		c.use(V(0, 3.5, -1.8))
	end,
})

---------------------------------------------------------------------------------------------------
-- picnic_table: weathered plank table with attached benches on A-frame legs
---------------------------------------------------------------------------------------------------
add({
	id = "picnic_table",
	category = "campus",
	footprint = V(6.0, 2.6, 4.7),
	maxParts = 16,
	tags = { "table", "gritty", "seat" },
	build = function(c: Ctx)
		local wood = c.color("color", C.woodWorn)
		local gap = if c.rng:chance(0.25) then c.rng:int(1, 4) else 0
		for i, z in { -0.9, -0.3, 0.3, 0.9 } do
			if i ~= gap then
				c.part(
					P(0, 2.5, z) * R(0, c.rng:range(-1, 1), 0),
					V(6, 0.15, 0.55),
					shade(wood, c.rng:range(-0.15, 0.06)),
					M.WoodPlanks
				)
			end
		end
		for _, sz in { -1, 1 } do
			-- both benches face the table (the -Z bench turns round)
			local face = if sz < 0 then R(0, 180, 0) else CFrame.identity
			c.seat(P(0, 1.5, sz * 1.9) * face, V(6, 0.15, 0.8), shade(wood, c.rng:range(-0.12, 0.04)), M.WoodPlanks)
		end
		local legC = shade(wood, -0.25)
		for _, sx in { -1, 1 } do
			local x = sx * 2.3
			for _, sz in { -1, 1 } do
				Shapes.strut(c, V(x, 2.42, sz * 0.5), V(x, 0.06, sz * 2.2), 0.18, legC, M.WoodPlanks)
			end
			c.detail(P(x, 1.37, 0), V(0.15, 0.12, 4.6), legC, M.WoodPlanks)
			c.detail(P(x, 2.35, 0), V(0.2, 0.15, 2.3), legC, M.WoodPlanks)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- mailbox: fictional "EASTBRIDGE POST" collection box with a domed top, pull-down chute and stickers
---------------------------------------------------------------------------------------------------
add({
	id = "mailbox",
	category = "campus",
	footprint = V(1.8, 4.1, 1.75),
	maxParts = 12,
	tags = { "street", "gritty" },
	build = function(c: Ctx)
		local body = c.color("color", hex("#2E4A6B"))
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				c.detail(P(sx * 0.7, 0.4, sz * 0.6), V(0.2, 0.8, 0.2), shade(body, -0.3), M.Metal)
			end
		end
		c.part(P(0, 2.0, 0), V(1.8, 2.4, 1.6), body, M.Metal)
		c.cylZ(P(0, 3.2, 0), 1.6, 1.8, body, M.Metal)
		c.detail(P(0, 3.3, -0.86) * R(-20, 0, 0), V(1.1, 0.3, 0.12), shade(body, -0.2), M.Metal)
		c.detail(P(0, 3.08, -0.81), V(1.0, 0.1, 0.02), col.plasticBlack, M.SmoothPlastic)
		local label = c.detail(P(0, 2.2, -0.81), V(1.4, 0.6, 0.02), shade(C.paper, -0.05), M.SmoothPlastic)
		c.sign(label, Words.mail, { font = Enum.Font.GothamBold, color = body, pixelsPerStud = 50, padding = 0.08 })
		patch(c, P(c.rng:range(-0.5, 0.5), c.rng:range(1.1, 1.6), -0.81), 0.5, 0.4)
		c.detail(
			P(c.rng:range(-0.5, 0.5), c.rng:range(2.6, 2.9), -0.815) * R(0, 0, c.rng:range(-20, 20)),
			V(0.35, 0.25, 0.01),
			c.rng:pick({ C.mustard, C.graffitiMagenta }),
			M.SmoothPlastic
		)
	end,
})

---------------------------------------------------------------------------------------------------
-- traffic_cone: scuffed orange cone with a reflective band
---------------------------------------------------------------------------------------------------
add({
	id = "traffic_cone",
	category = "campus",
	footprint = V(1.1, 1.92, 1.1),
	maxParts = 9,
	tags = { "street", "gritty" },
	build = function(c: Ctx)
		local orange = shade(c.color("color", hex("#E8641E")), c.rng:range(-0.2, 0))
		c.detail(P(0, 0.06, 0), V(1.1, 0.12, 1.1), shade(orange, -0.25), M.Rubber)
		-- seven short tiers tapering evenly read as a cone; the fifth is the reflective collar
		local tiers, y0, h = 7, 0.12, 1.8
		local th = h / tiers
		for i = 1, tiers do
			local d = 0.84 - (i - 1) * (0.84 - 0.2) / (tiers - 1)
			local white = i == 5
			c.dcyl(
				P(0, y0 + th * (i - 0.5), 0),
				th + 0.01,
				d,
				if white then hex("#E8E8E8") else orange,
				if white then M.SmoothPlastic else M.Plastic
			)
		end
	end,
})

return defs
