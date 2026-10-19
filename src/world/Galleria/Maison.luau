--!strict
-- Atelier Maison, Galleria Home & Office (the Galleria's south-east boutique; Config/Shop "decor"). Bake-safe. A
-- gallery-white showroom of staged room vignettes, each on a low platform against its own painted wall:
--
--   back left    The Park Avenue Living Room (sofa, club chair, coffee table, rug, arc lamp, a large canvas)
--   back right   The Corner Office (desk and chair, a bookcase, a globe, a canvas)
--   south wall   The Penthouse Suite (a bed against an upholstered wall, a nightstand and lamp, a painting)
--   windows      a sculpture on one plinth, a reading chair and floor lamp on the other
--   partition    the design counter with npc_decorator behind it, the `shop` interact (Shop = "decor") on its
--                service card, and the swatch wall of fabrics and finishes
--
--   Maison.build(parent, mk, spot, F, rng) -> Model

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
local hex = Deps.Palette.hex
local M = Enum.Material

local Maison = {}

local TERRACOTTA = hex("#7A3E2E")
local IVORY = hex("#F7EEDD")
local BRONZE = hex("#6E5A40")
local WALNUT = hex("#5A3A26")
local BRASS = hex("#B8933F")
local MARBLE = hex("#ECEAE6")

local STYLE: Boutique.Style = {
	name = Text.get("gal_decor"),
	sub = Text.get("gal_decor_sub"),
	logo = "brand_atelier_maison",
	monogram = Text.get("gal_mono_decor"),
	font = Enum.Font.Garamond,
	floor = hex("#D1B38A"),
	floorMat = M.WoodPlanks,
	wall = hex("#F3EFE7"),
	rail = hex("#CDBFA8"),
	ceiling = hex("#F7F5F0"),
	frame = BRONZE,
	fascia = TERRACOTTA,
	ink = IVORY,
	plinth = hex("#EFE9DF"),
	plinthMat = M.SmoothPlastic,
	light = hex("#FFE9C9"),
}

Maison.STYLE = STYLE

local FACE_OUT = Boutique.FLIP -- toward the door
local FACE_RIGHT = CFrame.Angles(0, -math.pi / 2, 0) -- LookVector +sx
local FACE_LEFT = CFrame.Angles(0, math.pi / 2, 0) -- LookVector -sx

local PLATFORM_H = 0.35

-- A vignette's stage: a low platform and its painted wall panel, with a brass label stand at the front corner.
local function stage(
	parent: Instance,
	P: Boutique.PFn,
	name: string,
	box: { number }, -- sx0, sd0, sx1, sd1 of the platform
	wall: { number }, -- sx0, sd0, sx1, sd1 of the wall panel (thin along one axis)
	wallColor: Color3,
	label: string,
	labelAt: { number }, -- sx, sd of the label stand
	labelFace: CFrame -- which way the label reads
): Model
	local g = Kit.model(parent, name)
	Boutique.box(g, P, box[1], 0, box[2], box[3], PLATFORM_H, box[4], hex("#E6DCCB"), M.Wood).Name = "Platform"
	Boutique.box(g, P, wall[1], PLATFORM_H, wall[2], wall[3], 10.5, wall[4], wallColor, M.Fabric).Name = "VignetteWall"
	Kit.detail(g, P(labelAt[1], 1.5, labelAt[2]), Vector3.new(0.16, 3, 0.16), BRASS, M.Metal).Name = "LabelStand"
	Shell.plate(
		g,
		P(labelAt[1], 3.3, labelAt[2]) * labelFace * CFrame.new(0, 0, -0.1) * CFrame.Angles(math.rad(-10), 0, 0),
		3.6,
		0.9,
		label,
		{
			color = TERRACOTTA,
			ink = IVORY,
			font = Enum.Font.Garamond,
			pps = 60,
		}
	).Name =
		"VignetteLabel"
	return g
end

local function livingRoom(m: Instance, P: Boutique.PFn, rng: Deps.RngT)
	local y = PLATFORM_H
	local g = stage(
		m,
		P,
		"LivingRoom",
		{ -20.5, 17.5, -5.5, 27.8 },
		{ -20.5, 27.4, -5.5, 27.8 },
		hex("#2F4A3C"),
		Text.get("gal_vignette_living"),
		{ -6.6, 17.1 },
		FACE_OUT
	)
	Props.build("rug_persian", g, P(-13, y + 0.01, 22.4), { seed = "gal-living-rug" })
	Furniture.sofa(g, P(-13, y, 25.2) * FACE_OUT, 8.5, hex("#C9BCA6"), { accent = hex("#E3D9C6") })
	Furniture.armchair(g, P(-18.4, y, 21) * FACE_RIGHT, hex("#7A1F24"), { material = M.Leather })
	Furniture.table(g, P(-13, y, 21.6), Vector3.new(4.6, 1.5, 2.4), hex("#2B2B2D"), MARBLE, M.Marble)
	-- the arc lamp's base stands beside the sofa; turned round, its arm (local +X) reaches over the seat
	Props.build("lamp_arc", g, P(-8.6, y, 25) * FACE_OUT, { seed = "gal-living-lamp" })
	Props.build(
		"art_canvas_large",
		g,
		P(-13, y + 5, 27.4) * FACE_OUT,
		{ variant = rng:int(1, 8), seed = "gal-living-art" }
	)
end

local function cornerOffice(m: Instance, P: Boutique.PFn)
	local y = PLATFORM_H
	local g = stage(
		m,
		P,
		"CornerOffice",
		{ 5.5, 17.5, 20.5, 27.8 },
		{ 5.5, 27.4, 20.5, 27.8 },
		hex("#1B2A44"),
		Text.get("gal_vignette_office"),
		{ 6.6, 17.1 },
		FACE_OUT
	)
	Furniture.desk(g, P(12, y, 21.8) * FACE_OUT, 7, 3.2, WALNUT, { legs = BRASS })
	Furniture.chair(g, P(12, y, 24.2) * FACE_OUT, hex("#3B2A20"), { material = M.Leather, leg = BRASS })
	Props.build("globe", g, P(9.6, y + 3.1, 21.8) * FACE_OUT, { seed = "gal-office-globe" })
	Props.build("book_stack", g, P(14.3, y + 3.1, 22) * FACE_OUT, { seed = "gal-office-books" })
	Props.build("bookshelf", g, P(17.6, y, 26.5) * FACE_OUT, { tier = 3, seed = "gal-office-shelf" })
end

local function bedroom(m: Instance, P: Boutique.PFn, rng: Deps.RngT)
	local y = PLATFORM_H
	-- between the display window (sd < 5.5) and the corner office (sd > 17.5), along the south wall, with an aisle
	-- on both sides; its open side faces the shop's centre aisle (-sx)
	local g = stage(
		m,
		P,
		"PenthouseSuite",
		{ 12, 6, 21.9, 15.4 },
		{ 21.4, 6, 21.8, 15.4 },
		hex("#4A3F55"),
		Text.get("gal_vignette_bedroom"),
		{ 11.4, 6.6 },
		FACE_LEFT
	)
	-- the bed's headboard against the upholstered wall (its foot toward the aisle)
	Furniture.bed(g, P(16.8, y, 10.2) * FACE_LEFT, 6, 8, {
		frame = WALNUT,
		duvet = hex("#E8E1D2"),
		pillow = hex("#FAF8F3"),
		headboard = hex("#5E5070"),
		headboardHeight = 5,
	})
	Furniture.nightstand(g, P(20.2, y, 14.3) * FACE_LEFT, WALNUT, true)
	Furniture.screen(g, P(21.4, 7.6, 10.2) * FACE_LEFT, 5, 3.2, "art", rng).Name = "BedroomArt"
end

local function counter(m: Instance, mk: Instance, P: Boutique.PFn, spot: Plan.ShopSpot, rng: Deps.RngT)
	Props.build("cash_counter", m, P(-15, 0.06, 11) * FACE_RIGHT, {
		text = STYLE.name,
		color = hex("#EFE9DF"),
		accent = TERRACOTTA,
		seed = "gal-decor-counter",
	})
	Boutique.serviceCard(m, P(-14.5, 0.06 + 3.55, 13.4) * FACE_RIGHT, spot.id, STYLE)
	Markers.npc(mk, "npc_decorator", P(-18.6, 3, 11) * FACE_RIGHT)
	-- the swatch wall behind the counter: fabrics, woods and stones in a grid
	local board = Boutique.box(m, P, -21.9, 4.4, 6.5, -21.7, 9.8, 15.5, hex("#FBF8F2"), M.SmoothPlastic, false)
	board.Name = "SwatchWall"
	local gui, W, H = Paint.surface(board, Enum.NormalId.Right, 16, { maxDistance = 140, name = "Swatches" })
	Core.bg(gui, hex("#FBF8F2"))
	local swatches = {
		hex("#2F4A3C"),
		hex("#7A3E2E"),
		hex("#C9BCA6"),
		hex("#1B2A44"),
		hex("#5E5070"),
		hex("#D9A441"),
		hex("#8A6A48"),
		hex("#3B2A20"),
		hex("#B9B4AA"),
		hex("#ECEAE6"),
		hex("#6E1A1F"),
		hex("#4C7A3F"),
	}
	local cols, rows = 6, 3
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local x, yy = W * (c + 0.1) / cols, H * (r + 0.12) / rows
			local sw = Core.px(gui, x, yy, W / cols * 0.8, H / rows * 0.72, rng:pick(swatches))
			Core.stroke(sw, hex("#CDBFA8"), 2)
		end
	end
	Shell.plate(m, P(-21.9, 10.8, 11) * FACE_RIGHT, 8, 0.9, Text.get("gal_swatches"), {
		color = TERRACOTTA,
		ink = IVORY,
		font = Enum.Font.Garamond,
		pps = 40,
	}).Name =
		"SwatchPlate"
	Shell.plate(m, P(-21.9, 3.8, 11) * FACE_RIGHT, 8, 0.6, Text.get("gal_design"), {
		color = TERRACOTTA,
		ink = IVORY,
		font = Enum.Font.Garamond,
		pps = 40,
	}).Name =
		"DesignPlate"
end

function Maison.build(parent: Instance, mk: Instance, spot: Plan.ShopSpot, F: Shell.Frame, rng: Deps.RngT): Model
	local shop = Boutique.shell(parent, spot, F, STYLE)
	local m, P = shop.model, shop.P

	-- the windows: a sculpture, and a reading chair with its lamp
	Props.build("sculpture_abstract", m, shop.windows[1], { seed = "gal-window-sculpture" })
	local w2 = shop.windows[2]
	Furniture.armchair(
		m,
		w2 * CFrame.new(-1.2, 0, 0) * CFrame.Angles(0, math.rad(20), 0),
		hex("#C9A54C"),
		{ material = M.Fabric, accent = hex("#8A6A48") }
	)
	Props.build("lamp_floor", m, w2 * CFrame.new(2.2, 0, 0.6), { lit = true, seed = "gal-window-lamp" })

	livingRoom(m, P, rng)
	cornerOffice(m, P)
	bedroom(m, P, rng)
	counter(m, mk, P, spot, rng)
	return m
end

return Maison
