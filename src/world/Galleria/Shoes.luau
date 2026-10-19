--!strict
-- Strider Shoes & Leather (the Galleria's north-east boutique; Config/Shop "shoes"). Bake-safe. Light oak, white
-- walls and sage green.
--
--   windows      stepped marble plinths, each showing a pair of shoes
--   back         two backlit shoe walls with the fitting sign between them
--   north wall   the new-season sneaker wall
--   centre       two leather fitting benches with a try-on stool and low floor mirrors; a round display table
--   south        the cash counter with npc_shoe_clerk behind it, the `shop` interact (Shop = "shoes") on its service
--                card, and a stack of shoe boxes
--
--   Shoes.build(parent, mk, spot, F, rng) -> Model

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

local Shoes = {}

local SAGE = hex("#34483E")
local OAK = hex("#A07A52")
local STONE = hex("#ECEAE6")
local STONE_DARK = hex("#D9D2C3")
local STEEL = hex("#2B2B2D")
local LEATHER = hex("#5A3E2E")
local CREAM = hex("#F2E6C4")

local STYLE: Boutique.Style = {
	name = Text.get("gal_shoes"),
	sub = Text.get("gal_shoes_sub"),
	logo = "brand_strider",
	monogram = Text.get("gal_mono_shoes"),
	font = Enum.Font.GothamBold,
	floor = hex("#C29C70"),
	floorMat = M.WoodPlanks,
	wall = hex("#EFEDE6"),
	rail = OAK,
	ceiling = hex("#F4F1EA"),
	frame = STEEL,
	fascia = SAGE,
	ink = CREAM,
	plinth = STONE_DARK,
	plinthMat = M.Marble,
	light = hex("#FFE9C9"),
}

Shoes.STYLE = STYLE

local FACE_OUT = Boutique.FLIP -- toward the door
local FACE_LEFT = CFrame.Angles(0, math.pi / 2, 0) -- LookVector -sx

local UPPERS = { hex("#1A1614"), hex("#4A2F22"), hex("#8A4F2A"), hex("#5A1E1E"), hex("#F2F2EE"), hex("#1B2A44") }

-- One shoe standing on cf (toe toward cf.LookVector): a sole and a wedge upper, heel high at the back.
local function shoe(parent: Instance, cf: CFrame, upper: Color3)
	local sneaker = upper.R + upper.G + upper.B > 2.4
	Kit.detail(
		parent,
		cf * CFrame.new(0, 0.06, 0),
		Vector3.new(0.55, 0.12, 1.15),
		if sneaker then STONE else hex("#2A1E16"),
		M.Rubber
	).Name =
		"Sole"
	Kit.wedge(
		parent,
		cf * CFrame.new(0, 0.33, 0.08),
		Vector3.new(0.5, 0.42, 1.0),
		upper,
		if sneaker then M.Fabric else M.Leather,
		{
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}
	).Name =
		"Upper"
end

-- A window display: a low and a high marble step, a shoe angled on each.
local function showcase(parent: Instance, cf: CFrame, rng: Deps.RngT)
	local g = Kit.model(parent, "Showcase")
	local low = cf * CFrame.new(-1.7, 0, 0)
	local high = cf * CFrame.new(1.5, 0, 0.3)
	Kit.block(g, low * CFrame.new(0, 0.3, 0), Vector3.new(2.6, 0.6, 2.4), STONE, M.Marble).Name = "ShowStep"
	Kit.block(g, high * CFrame.new(0, 0.7, 0), Vector3.new(2.2, 1.4, 1.8), STONE_DARK, M.Marble).Name = "ShowStep"
	shoe(g, low * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.rad(-30), 0), rng:pick(UPPERS))
	shoe(g, high * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, math.rad(25), 0), rng:pick(UPPERS))
end

local function sneakerWall(m: Instance, P: Boutique.PFn, rng: Deps.RngT)
	local panel = Boutique.box(m, P, -21.9, 1, 7, -21.6, 10, 21, hex("#F7F6F2"), M.SmoothPlastic, false)
	panel.Name = "SneakerWall"
	panel:AddTag("InteriorLight")
	-- the panel's Right face looks into the shop (+sx)
	local gui, W, H = Paint.surface(panel, Enum.NormalId.Right, 12, { glow = true, brightness = 1, maxDistance = 160 })
	Core.bg(gui, hex("#F7F6F2"))
	local rows, cols = 5, 7
	local colors =
		{ hex("#F2F2EE"), hex("#3A3D42"), hex("#1B2A44"), hex("#C0392B"), SAGE, hex("#D9A441"), hex("#7FA7D9") }
	for r = 0, rows - 1 do
		local y = H * (r + 1) / rows - 6
		Core.px(gui, 0, y, W, 4, hex("#D5D1C8"))
		for c = 0, cols - 1 do
			local cx = W * (c + 0.5) / cols + rng:range(-4, 4)
			local sw, sh = W / cols * 0.62, H / rows * 0.34
			local body = Core.px(gui, cx - sw / 2, y - sh, sw, sh, rng:pick(colors))
			Core.round(body, 0.45)
			Core.px(gui, cx - sw / 2, y - sh * 0.3, sw, sh * 0.3, hex("#FFFFFF"))
			Core.px(gui, cx - sw * 0.1, y - sh * 0.8, sw * 0.42, 2, hex("#FFFFFF"), 0.2)
		end
	end
	Shell.plate(m, P(-21.9, 11, 14) * CFrame.Angles(0, -math.pi / 2, 0), 8, 1, Text.get("gal_new_season"), {
		color = SAGE,
		ink = CREAM,
		font = Enum.Font.GothamBold,
		pps = 40,
	}).Name =
		"SneakerPlate"
end

local function fitting(m: Instance, P: Boutique.PFn, rng: Deps.RngT)
	local f = Kit.model(m, "Fitting")
	for _, sx in { -5, 5 } do
		Furniture.bench(f, P(sx, 0.06, 15), 7, LEATHER, { material = M.Leather, legs = STEEL, depth = 2.2 })
		-- a low mirror leaning toward the bench
		local mirror = Kit.detail(
			f,
			P(sx, 1.3, 18.4) * FACE_OUT * CFrame.Angles(math.rad(-14), 0, 0),
			Vector3.new(2.6, 2.4, 0.1),
			hex("#D5DEE4"),
			M.Glass
		)
		mirror.Name = "FloorMirror"
		mirror.Reflectance = 0.5
		Kit.detail(f, P(sx, 0.2, 18.6), Vector3.new(2.8, 0.4, 0.6), OAK, M.Wood).Name = "MirrorFoot"
	end
	Furniture.stool(f, P(0, 0.06, 15), 1.6, LEATHER, STEEL)
	-- the round display table with a pair on it
	Furniture.roundTable(f, P(-12, 0.06, 9), 3.4, 3, STONE, STEEL)
	shoe(f, P(-12.5, 3.06, 9) * CFrame.Angles(0, math.rad(200), 0), rng:pick(UPPERS))
	shoe(f, P(-11.6, 3.06, 9.3) * CFrame.Angles(0, math.rad(160), 0), rng:pick(UPPERS))
end

function Shoes.build(parent: Instance, mk: Instance, spot: Plan.ShopSpot, F: Shell.Frame, rng: Deps.RngT): Model
	local shop = Boutique.shell(parent, spot, F, STYLE)
	local m, P = shop.model, shop.P

	for _, cf in shop.windows do
		showcase(m, cf, rng)
	end

	-- the shoe walls on the back wall and the fitting sign between them
	for i, sx in { -5, 5 } do
		Props.build(
			"shoe_wall",
			m,
			P(sx, 0.06, Plan.DEPTH - 0.1) * FACE_OUT,
			{ color = hex("#F4F1EA"), accent = OAK, seed = "gal-shoewall" .. i }
		)
	end
	Shell.plate(m, P(0, 9.5, Plan.DEPTH - 0.1) * FACE_OUT, 14, 0.9, Text.get("gal_try_on"), {
		color = SAGE,
		ink = CREAM,
		font = Enum.Font.GothamMedium,
		pps = 40,
	}).Name =
		"FittingSign"

	sneakerWall(m, P, rng)
	fitting(m, P, rng)

	-- the counter, the clerk and the service card
	Props.build("cash_counter", m, P(13.5, 0.06, 21.5) * FACE_OUT, {
		text = STYLE.name,
		color = OAK,
		accent = SAGE,
		seed = "gal-shoes-counter",
	})
	Boutique.serviceCard(m, P(16.2, 0.06 + 3.55, 21.0) * FACE_OUT, spot.id, STYLE)
	Markers.npc(mk, "npc_shoe_clerk", P(13.5, 3, 24.6) * FACE_OUT)
	Shell.plate(m, P(21.9, 7, 21.5) * FACE_LEFT, 6, 0.8, Text.get("gal_shoe_care"), {
		color = SAGE,
		ink = CREAM,
		font = Enum.Font.GothamMedium,
		pps = 40,
	}).Name =
		"ShoeCarePlate"
	-- shoe boxes stacked by the counter
	local boxes = { hex("#E9DFC6"), SAGE, hex("#E9DFC6"), hex("#C8553D") }
	for i, c in boxes do
		local b = Kit.detail(
			m,
			P(19.8, 0.06 + 0.5 + (i - 1) * 1.0, 25.2) * CFrame.Angles(0, math.rad(rng:range(-6, 6)), 0),
			Vector3.new(2.2, 0.95, 1.4),
			c,
			M.Cardboard
		)
		b.Name = "ShoeBox"
	end
	Props.build("plant_floor", m, P(-19.5, 0.06, 25), { seed = "gal-shoes-plant" })
	return m
end

return Shoes
