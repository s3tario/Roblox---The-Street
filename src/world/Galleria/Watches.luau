--!strict
-- Vanta Watches & Eyewear (the Galleria's south-west boutique; Config/Shop "watch"). Bake-safe. A dark, glittering
-- room: black granite, walnut and brass.
--
--   windows      a glass vitrine in each window, a single watch turning its dial to the atrium
--   centre       three lit glass watch cases in a U; the centre one is the counter, with npc_watchmaker behind it and
--                the `shop` interact (Shop = "watch") on its service card
--   back         the Astra Collection: five lit niches in the back wall; the watchmaker's bench in the corner
--   south wall   the eyewear wall
--   north        a consultation corner: two club chairs and a marble table on a round rug
--
--   Watches.build(parent, mk, spot, F, rng) -> Model

local Venue = script.Parent.Parent.CareerServices.Venue
local Deps = require(Venue.Deps)
local Shell = require(Venue.Shell)
local Paint = require(Venue.Paint)
local Markers = require(Venue.Markers)
local Furniture = require(Venue.Furniture)
local Text = require(Venue.Text)
local Plan = require(script.Parent.Plan)
local Boutique = require(script.Parent.Boutique)

local Kit = Deps.Kit
local Props = Deps.Props
local Core = Deps.Gui.Core
local Art = Deps.Gui.Art
local hex = Deps.Palette.hex
local M = Enum.Material

local Watches = {}

local GRANITE = hex("#1C1D20")
local WALNUT = hex("#3A2618")
local BRASS = hex("#B8933F")
local GOLD = hex("#C9A54C")
local GOLD_BRIGHT = hex("#E3C46F")
local MARBLE = hex("#ECEAE6")
local VELVET = hex("#14213D")
local CREAM = hex("#F2E6C4")
local GLASS = hex("#EAF4FA")
local WARM = hex("#FFE2B0")

local STYLE: Boutique.Style = {
	name = Text.get("gal_watch"),
	sub = Text.get("gal_watch_sub"),
	logo = "brand_vanta",
	monogram = Text.get("gal_mono_watch"),
	font = Enum.Font.Bodoni,
	floor = GRANITE,
	floorMat = M.Granite,
	floorSeam = hex("#34363C"),
	wall = WALNUT,
	wallMat = M.Wood,
	rail = BRASS,
	ceiling = hex("#1E1A17"),
	frame = hex("#121417"),
	fascia = hex("#121417"),
	ink = GOLD_BRIGHT,
	plinth = GRANITE,
	plinthMat = M.Granite,
	light = hex("#F4EEE2"),
}

Watches.STYLE = STYLE

local FACE_IN = CFrame.identity -- LookVector +sd (toward the back wall)
local FACE_OUT = Boutique.FLIP -- toward the door
local FACE_RIGHT = CFrame.Angles(0, -math.pi / 2, 0) -- LookVector +sx
local FACE_LEFT = CFrame.Angles(0, math.pi / 2, 0) -- LookVector -sx

-- A window vitrine: a granite column, a glass hood and one watch on a velvet cushion, its dial facing cf.LookVector.
local function vitrine(parent: Instance, cf: CFrame, hour: number)
	local g = Kit.model(parent, "Vitrine")
	Kit.block(g, cf * CFrame.new(0, 1.6, 0), Vector3.new(1.8, 3.2, 1.8), GRANITE, M.Granite).Name = "VitrineBase"
	Kit.detail(g, cf * CFrame.new(0, 3.24, 0), Vector3.new(1.95, 0.08, 1.95), BRASS, M.Metal).Name = "VitrineRim"
	local hood = Kit.detail(g, cf * CFrame.new(0, 4.4, 0), Vector3.new(1.7, 2.2, 1.7), GLASS, M.Glass)
	hood.Name = "VitrineGlass"
	hood.Transparency = 0.8
	hood.Reflectance = 0.2
	hood.CastShadow = false
	Kit.detail(g, cf * CFrame.new(0, 3.5, 0.15), Vector3.new(1, 0.45, 0.7), VELVET, M.Fabric).Name = "Cushion"
	Kit.detail(g, cf * CFrame.new(0, 4.35, 0.08), Vector3.new(0.42, 1.9, 0.1), hex("#3B2418"), M.Leather).Name = "Strap"
	Kit.cylinder(g, cf * CFrame.new(0, 4.35, 0) * CFrame.Angles(math.rad(90), 0, 0), 0.24, 1.1, GOLD, M.Metal, {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}).Name =
		"WatchCase"
	local dial = Kit.detail(g, cf * CFrame.new(0, 4.35, -0.13), Vector3.new(0.92, 0.92, 0.02), MARBLE, M.SmoothPlastic)
	dial.Name = "WatchDial"
	dial.Transparency = 1
	local dg, DW, DH = Core.surface(dial, Enum.NormalId.Front, { pps = 120, maxDistance = 60, name = "Dial" })
	Art.clockFace(dg, DW, DH, hour, 9, hex("#1B1B1F"), hex("#F7F6F2"))
	Shell.glow(g, cf * CFrame.new(0, 5.42, 0), Vector3.new(1.2, 0.05, 1.2), WARM).Name = "VitrineLight"
end

local function collection(m: Instance, P: Boutique.PFn, rng: Deps.RngT)
	local panel = Boutique.box(m, P, -10, 3.4, 27.4, 10, 10.6, 27.9, hex("#1A120C"), M.Wood, false)
	panel.Name = "AstraNiches"
	panel:AddTag("InteriorLight")
	local gui, W, H = Paint.surface(panel, Enum.NormalId.Back, 12, { glow = true, brightness = 1, maxDistance = 220 })
	Core.bg(gui, hex("#1A120C"))
	local names = Text.list("gal_watch_lines")
	local n = 5
	for i = 0, n - 1 do
		local x = W * (0.03 + i * 0.194)
		local w = W * 0.164
		local niche = Core.px(gui, x, H * 0.08, w, H * 0.74, hex("#5A4030"))
		Paint.gradient(niche, hex("#8A6A48"), hex("#2A1C12"), 90)
		Core.stroke(niche, BRASS, 2)
		-- the watch on its cushion
		local cx, cy = x + w / 2, H * 0.4
		Core.px(gui, cx - w * 0.12, cy - H * 0.22, w * 0.24, H * 0.44, hex("#2B1A12"))
		Core.dot(gui, cx, cy, w * 0.52, rng:pick({ GOLD, hex("#A7ABB0"), hex("#C9967A") }))
		Core.dot(gui, cx, cy, w * 0.42, rng:pick({ hex("#F7F6F2"), hex("#0B1F3A"), hex("#121417"), hex("#1F4D3A") }))
		Core.px(gui, cx - w * 0.3, H * 0.62, w * 0.6, H * 0.08, VELVET)
		Core.label(gui, names[i + 1] or "", (x + w * 0.05) / W, 0.84, (w * 0.9) / W, 0.1, CREAM, {
			font = Enum.Font.Garamond,
			align = Enum.TextXAlignment.Center,
		})
	end
	Shell.plate(m, P(0, 11.7, 27.9) * FACE_OUT, 14, 1, Text.get("gal_watch_case"), {
		color = hex("#121417"),
		ink = GOLD_BRIGHT,
		font = Enum.Font.Bodoni,
		pps = 40,
	}).Name =
		"CollectionPlate"
end

local function eyewear(m: Instance, P: Boutique.PFn)
	local panel = Boutique.box(m, P, -21.9, 3, 8, -21.6, 9.6, 17, hex("#2A1E16"), M.Wood, false)
	panel.Name = "EyewearWall"
	-- the panel's Right face looks into the shop (+sx)
	local gui, W, H = Paint.surface(panel, Enum.NormalId.Right, 20, { maxDistance = 140, name = "Frames" })
	Core.bg(gui, hex("#2A1E16"))
	local rows, cols = 4, 4
	local frames = { hex("#121417"), hex("#6B4A2E"), GOLD, hex("#A7ABB0"), hex("#3A2A5C") }
	for r = 0, rows - 1 do
		local y = H * (r + 0.5) / rows
		Core.px(gui, 0, y + H * 0.08, W, 4, BRASS, 0.2)
		for c = 0, cols - 1 do
			local cx = W * (c + 0.5) / cols
			local lw = W * 0.07
			local color = frames[(r * cols + c) % #frames + 1]
			for _, s in { -1, 1 } do
				local lens = Core.px(gui, cx + s * lw * 0.62 - lw / 2, y - lw * 0.35, lw, lw * 0.7, hex("#9FB8C6"), 0.5)
				Core.round(lens, 0.35)
				Core.stroke(lens, color, 3)
			end
			Core.px(gui, cx - lw * 0.15, y - lw * 0.2, lw * 0.3, 3, color)
		end
	end
	Shell.plate(m, P(-21.9, 10.7, 12.5) * FACE_RIGHT, 6, 0.9, Text.get("gal_eyewear"), {
		color = hex("#121417"),
		ink = GOLD_BRIGHT,
		font = Enum.Font.Bodoni,
		pps = 40,
	}).Name =
		"EyewearPlate"
end

local function bench(m: Instance, P: Boutique.PFn)
	local b = Kit.model(m, "WatchmakersBench")
	Furniture.desk(b, P(-16, 0.06, 25.6) * FACE_IN, 6, 2.4, hex("#4A2E1E"), { legs = BRASS })
	Furniture.chair(b, P(-16, 0.06, 23.2) * FACE_IN, hex("#3B2A20"), { material = M.Leather, leg = BRASS })
	Props.build("desk_lamp", b, P(-17.8, 3.16, 25.9) * FACE_OUT, { lit = true, seed = "gal-bench-lamp" })
	Kit.cylinder(b, P(-15.6, 3.2, 25.3), 0.12, 0.7, hex("#121417"), M.Metal, { CanCollide = false }).Name = "Loupe"
	Kit.detail(b, P(-14.4, 3.19, 25.7), Vector3.new(1.6, 0.06, 0.9), hex("#14213D"), M.Fabric).Name = "WorkMat"
	for i = 0, 3 do
		Kit.detail(b, P(-14.9 + i * 0.35, 3.24, 25.6), Vector3.new(0.06, 0.04, 0.6), hex("#A7ABB0"), M.Metal).Name =
			"Tool"
	end
	Shell.plate(b, P(-16, 7.6, 27.9) * FACE_OUT, 7, 0.9, Text.get("gal_bench"), {
		color = hex("#121417"),
		ink = GOLD_BRIGHT,
		font = Enum.Font.Bodoni,
		pps = 40,
	}).Name =
		"BenchPlate"
	Shell.plate(b, P(-16, 6.7, 27.9) * FACE_OUT, 7, 0.6, Text.get("gal_bench_sub"), {
		color = hex("#121417"),
		ink = CREAM,
		font = Enum.Font.Garamond,
		pps = 40,
	}).Name =
		"BenchSub"
end

function Watches.build(parent: Instance, mk: Instance, spot: Plan.ShopSpot, F: Shell.Frame, rng: Deps.RngT): Model
	local shop = Boutique.shell(parent, spot, F, STYLE)
	local m, P = shop.model, shop.P

	vitrine(m, shop.windows[1], 10)
	vitrine(m, shop.windows[2], 2)

	-- the U of watch cases; the centre case is the counter
	Props.build("watch_case", m, P(0, 0.06, 19) * FACE_OUT, { seed = "gal-case-centre" })
	Props.build("watch_case", m, P(-8, 0.06, 12.5) * FACE_RIGHT, { seed = "gal-case-left" })
	Props.build("watch_case", m, P(8, 0.06, 12.5) * FACE_LEFT, { seed = "gal-case-right" })
	for _, c in { { 0, 19, 5.4, 1.4 }, { -8, 12.5, 1.4, 5.4 }, { 8, 12.5, 1.4, 5.4 } } do
		Shell.glow(m, P(c[1], Plan.SHOP_H - 0.06, c[2]), Vector3.new(c[3], 0.1, c[4]), WARM).Name = "CaseLight"
	end
	Boutique.serviceCard(m, P(1.5, 0.06 + 4.08, 18.6) * FACE_OUT, spot.id, STYLE)
	Markers.npc(mk, "npc_watchmaker", P(0, 3, 22.2) * FACE_OUT)

	collection(m, P, rng)
	eyewear(m, P)
	bench(m, P)

	-- the consultation corner by the partition
	local corner = Kit.model(m, "Consultation")
	Props.build("rug_round", corner, P(15, 0.07, 22), { color = hex("#2A1E16"), seed = "gal-watch-rug" })
	Furniture.armchair(
		corner,
		P(12.2, 0.07, 22) * FACE_RIGHT,
		hex("#5E1F1A"),
		{ material = M.Leather, accent = hex("#3B1410") }
	)
	Furniture.armchair(
		corner,
		P(17.8, 0.07, 22) * FACE_LEFT,
		hex("#5E1F1A"),
		{ material = M.Leather, accent = hex("#3B1410") }
	)
	Furniture.roundTable(corner, P(15, 0.07, 22), 2.2, 2.2, MARBLE, BRASS)
	Props.build("plant_floor", m, P(19.5, 0.06, 8), { seed = "gal-watch-plant" })
	return m
end

return Watches
