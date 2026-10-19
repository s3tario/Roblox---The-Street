--!strict
-- One Ashford Residences apartment: a UnitSlot container for HousingService (contracts §7). Model "Apartment_NN" with
-- attributes UnitSlot = n, UnitKind = "apartment", Floor, tag "UnitSlot" and PrimaryPart "Root" at the doorway.
--
-- Layout (unit-local: ux across the unit, ud depth from the corridor wall, so every unit shares the same plan):
--   front (ud 0..18)     the entry and its foyer (left), a kitchenette along the right wall and a small dining table
--   centre wall (ud 18)  the closet with its mirror doors (interact wardrobe) and the home panel (interact
--                        housing_panel, Context "apartment") on its front face
--   back left            the bed nook behind the centre wall, screened from the living area by oak slats
--   back right           the home office desk (interact terminal) and the living area: a sofa facing the full-width
--                        window onto the city (a painted skyline backdrop)
-- Interacts sit near the unit's centre line and deep inside it, so neighbours and corridor walkers never get this
-- unit's prompts through a wall (prompt range 10).
-- Housing markers: the Nameplate on the corridor side of the door, ThemeFloor (the oak floor) and ThemeWall (the side
-- wall liners, the centre wall and the window wall), and Unit.SLOTS (8 DecorSlots, unique SlotIds, the same ids in
-- every unit so a resident's decor follows them to whichever unit they are given).
--
--   Unit.build(parent, frame, n, level, rng) -> Model    frame = Plan.units()[i].frame in world space

local Venue = script.Parent.Parent.CareerServices.Venue
local Deps = require(Venue.Deps)
local Shell = require(Venue.Shell)
local Paint = require(Venue.Paint)
local Markers = require(Venue.Markers)
local Furniture = require(Venue.Furniture)
local Text = require(Venue.Text)
local Plan = require(script.Parent.Plan)

local Kit = Deps.Kit
local Core = Deps.Gui.Core
local hex = Deps.Palette.hex
local M = Enum.Material

local Unit = {}

Unit.SLOTS = {
	{ id = "wall_entry", kind = "wall_art" },
	{ id = "wall_bed", kind = "wall_art" },
	{ id = "wall_living", kind = "wall_art" },
	{ id = "desk_top", kind = "desk_item" },
	{ id = "rug_living", kind = "rug" },
	{ id = "floor_corner", kind = "floor" },
	{ id = "plant_entry", kind = "plant" },
	{ id = "lamp_bed", kind = "lamp" },
}

local HW, D, CH = Plan.HALF_W, Plan.DEPTH, Plan.CLEAR_H
local WALL_A = 18 -- the centre wall's front face (ud)
local WALL_A_END = 2 -- it runs from the left wall to ux = 2

local FACE_IN = CFrame.identity
local FACE_OUT = CFrame.Angles(0, math.pi, 0)
local FACE_RIGHT = CFrame.Angles(0, -math.pi / 2, 0) -- LookVector +ux
local FACE_LEFT = CFrame.Angles(0, math.pi / 2, 0) -- LookVector -ux

-- seeded per-unit finishes (the "classic" theme keeps these; room themes recolour the theme surfaces)
local FLOORS = { hex("#B48A60"), hex("#A57C55"), hex("#C29C70"), hex("#8E6B4A") }
local WALLS = { hex("#E8E3D8"), hex("#E2DED6"), hex("#DCD8CE"), hex("#E9E1D2") }
local CABINETS = { hex("#F2F0EB"), hex("#3E4A44"), hex("#5A3A26"), hex("#2B3A55") }
local SOFAS = { hex("#7A8590"), hex("#C9BCA6"), hex("#3E5B6B"), hex("#5E4A3A"), hex("#6B6F5A") }
local DUVETS = { hex("#2C3E5C"), hex("#E8E1D2"), hex("#7A1F24"), hex("#4A5D4F"), hex("#8A7A66") }

function Unit.build(parent: Instance, frame: CFrame, n: number, level: number, rng: Deps.RngT): Model
	local function P(ux: number, uy: number, ud: number): CFrame
		return frame * CFrame.new(ux, uy, -ud)
	end
	local m = Kit.model(nil, string.format("Apartment_%02d", n))
	m:SetAttribute("UnitSlot", n)
	m:SetAttribute("UnitKind", "apartment")
	m:SetAttribute("Floor", level)
	m:AddTag("UnitSlot")
	local root = Kit.block(m, P(Plan.DOOR_UX, 0.5, 0.5), Vector3.new(1, 1, 1), nil, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	root.Name = "Root"
	m.PrimaryPart = root

	local wallC = rng:pick(WALLS)
	local cab = rng:pick(CABINETS)

	-- theme surfaces: the oak floor, the side-wall liners, the centre wall and the window wall
	local floor = Kit.detail(m, P(0, 0.03, D / 2), Vector3.new(Plan.UNIT_W, 0.06, D), rng:pick(FLOORS), M.WoodPlanks)
	floor.Name = "Floor"
	floor.CastShadow = false
	Markers.theme(floor, "floor")
	for _, sx in { -1, 1 } do
		local liner = Kit.detail(m, P(sx * (HW - 0.05), CH / 2, D / 2), Vector3.new(0.1, CH, D), wallC, M.SmoothPlastic)
		liner.Name = "WallLiner"
		liner.CastShadow = false
		Markers.theme(liner, "wall")
	end
	local back = Kit.block(
		m,
		P(0, CH / 2, D + Plan.BACK_T / 2),
		Vector3.new(Plan.UNIT_W + Plan.PARTY_T, CH, Plan.BACK_T),
		wallC,
		M.SmoothPlastic
	)
	back.Name = "WindowWall"
	Markers.theme(back, "wall")
	local wallA = Kit.block(
		m,
		P((-HW + WALL_A_END) / 2, CH / 2, WALL_A + 0.5),
		Vector3.new(WALL_A_END + HW, CH, 1),
		wallC,
		M.SmoothPlastic
	)
	wallA.Name = "CentreWall"
	Markers.theme(wallA, "wall")
	-- the oak slat screen between the bed nook and the living area
	local screen = Kit.block(m, P(-3, 4.5, WALL_A + 5), Vector3.new(0.3, 9, 8), hex("#A07A52"), M.Wood)
	screen.Name = "SlatScreen"
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local sg, SW, SH = Paint.surface(screen, face, 6, { maxDistance = 80 })
		local x = 4
		while x < SW do
			Core.px(sg, x, 0, 3, SH, hex("#6B4E35"), 0.2)
			x += 9
		end
	end

	-- the entry: the door leaf standing open, a head trim and the nameplate on the corridor side
	Kit.detail(m, P(Plan.DOOR_UX - 2.9, 4.75, 3.1), Vector3.new(0.2, Plan.DOOR_H, 5.8), hex("#3E2C20"), M.Wood).Name =
		"DoorLeaf"
	Kit.detail(
		m,
		P(Plan.DOOR_UX, Plan.DOOR_H + 0.35, -Plan.FRONT_T - 0.1) * FACE_OUT,
		Vector3.new(Plan.DOOR_W + 1.2, 0.7, 0.2),
		hex("#B8933F"),
		M.Metal
	).Name =
		"DoorHead"
	Markers.nameplate(
		m,
		P(Plan.DOOR_UX + 4.9, 6.2, -Plan.FRONT_T - 0.06) * FACE_OUT,
		Vector3.new(2.8, 0.9, 0.1),
		Text.get("apt_unit", { n = n }),
		{
			color = hex("#1C1E22"),
			ink = hex("#E3C46F"),
			font = Enum.Font.Bodoni,
		}
	)

	-- the window onto the city with its curtains
	Shell.window(m, P(0, 7.4, D - 0.02) * FACE_OUT, Plan.UNIT_W - 2, 11.6, rng, {
		mood = "day",
		view = "high",
		horizon = 0.55,
		mullions = 2,
		frame = hex("#2B2B2D"),
		pps = 6,
		maxDistance = 160,
	})
	for _, sx in { -1, 1 } do
		Kit.detail(m, P(sx * (HW - 1.4), 7.2, D - 0.6), Vector3.new(2.4, 13.8, 0.4), hex("#D9D2C3"), M.Fabric).Name =
			"Curtain"
	end

	-- the kitchenette along the right wall and the dining table
	Furniture.kitchen(m, P(HW - 2.4, 0, 8) * FACE_LEFT, 14, {
		cabinet = cab,
		counter = hex("#ECEAE6"),
		splash = hex("#DCD6CC"),
	})
	Furniture.roundTable(m, P(4.5, 0, 8.5), 3.4, 3, hex("#ECEAE6"), hex("#2B2B2D"))
	for _, dd in { -2.5, 2.5 } do
		Furniture.stool(m, P(4.5, 0, 8.5 + dd), 2.1, rng:pick(SOFAS), hex("#2B2B2D"))
	end
	Furniture.pendant(m, P(4.5, CH, 8.5), 5.6, hex("#FFE7BF"))

	-- the closet (mirror doors = wardrobe) and the home panel on the centre wall's front face
	Kit.detail(m, P(-7, 4.8, WALL_A - 0.05) * FACE_OUT, Vector3.new(11, 9.6, 0.1), Kit.shade(cab, 0.05), M.Wood).Name =
		"ClosetDoors"
	local mirror =
		Kit.block(m, P(-6.5, 4.6, WALL_A - 0.15) * FACE_OUT, Vector3.new(3, 7.6, 0.1), hex("#D5DEE4"), M.Glass, {
			CanCollide = false,
		})
	mirror.Name = "ClosetMirror"
	mirror.Reflectance = 0.5
	Markers.interact(mirror, "wardrobe")
	local panel = Kit.block(
		m,
		P(0.6, 4.8, WALL_A - 0.08) * FACE_OUT,
		Vector3.new(1.5, 2.2, 0.16),
		hex("#14161A"),
		M.SmoothPlastic,
		{
			CanCollide = false,
		}
	)
	panel.Name = "HomePanel"
	Markers.interact(panel, "housing_panel", { Context = "apartment" })
	local pg = Core.surface(panel, Enum.NormalId.Front, { pps = 60, glow = true, brightness = 1, maxDistance = 90 })
	local pbg = Core.bg(pg, hex("#13243A"))
	Core.gradient(pbg, hex("#1F3A5C"), hex("#0E1A24"), 90)
	Core.label(
		pg,
		Text.get("apt_panel"),
		0.1,
		0.2,
		0.8,
		0.22,
		hex("#E3C46F"),
		{ font = Enum.Font.GothamBold, align = Enum.TextXAlignment.Center }
	)
	Core.label(
		pg,
		Text.get("apt_panel_sub"),
		0.1,
		0.5,
		0.8,
		0.14,
		hex("#D9E2EC"),
		{ font = Enum.Font.GothamMedium, align = Enum.TextXAlignment.Center }
	)

	-- the bed nook: bed against the centre wall's back face, a nightstand with its lamp
	Furniture.bed(m, P(-9, 0, WALL_A + 1 + 4.5), 6, 8, {
		frame = hex("#5A3A26"),
		duvet = rng:pick(DUVETS),
		headboard = hex("#CFC6B6"),
		headboardHeight = 4.4,
	})
	Furniture.nightstand(m, P(-13.4, 0, WALL_A + 2.2), hex("#5A3A26"), true)

	-- the home office: a desk against the centre wall, its monitor (terminal) and a chair
	Furniture.desk(m, P(-0.6, 0, WALL_A + 2.2), 4, 2.2, hex("#3A2A20"))
	local monitor = Furniture.monitor(m, P(-1.1, 3.1, WALL_A + 1.6), 2.4, rng, "candles")
	Markers.interact(monitor, "terminal")
	Furniture.chair(m, P(-0.6, 0, WALL_A + 4.6) * FACE_OUT, hex("#2B2B2D"), { back = hex("#2B2B2D") })

	-- the living area: the sofa facing the view and a coffee table
	local sofaC = rng:pick(SOFAS)
	Furniture.sofa(m, P(8.5, 0, 24.5), 9, sofaC)
	Furniture.table(m, P(8.5, 0, 29), Vector3.new(4.6, 1.6, 2.4), hex("#2B2B2D"), hex("#ECEAE6"), M.Marble)

	-- ceiling lights: the living area (lit) and the foyer
	Shell.glow(m, P(8.5, CH - 0.06, 26), Vector3.new(3, 0.1, 3), hex("#FFF1DA"), { range = 28, brightness = 0.85 })
	Shell.glow(m, P(-7, CH - 0.06, 9), Vector3.new(2.2, 0.1, 2.2), hex("#FFF1DA"))

	-- decor slots (same ids in every unit)
	Markers.wallSlot(
		m,
		"wall_art",
		"wall_entry",
		P(3, 5.5, 0) * FACE_IN,
		Vector3.new(6, 4, 0.5),
		{ width = 7, height = 5 }
	)
	Markers.wallSlot(m, "wall_art", "wall_bed", P(-9, 5.6, WALL_A + 1) * FACE_IN, Vector3.new(6, 3.6, 0.5), {
		width = 7,
		height = 4.5,
	})
	Markers.wallSlot(m, "wall_art", "wall_living", P(HW - 0.1, 5.5, 26) * FACE_LEFT, Vector3.new(7, 4.5, 0.5), {
		width = 8.5,
		height = 5.5,
	})
	Markers.surfaceSlot(m, "desk_item", "desk_top", P(0.8, 3.1, WALL_A + 1.9) * FACE_IN, Vector3.new(1.1, 1.2, 1.2), {
		width = 1.3,
		depth = 1.6,
		height = 2,
	})
	Markers.surfaceSlot(m, "rug", "rug_living", P(8.2, 0.07, 28.8), Vector3.new(9.6, 0.1, 6.6), {
		width = 10,
		depth = 7,
		height = 0.5,
	})
	Markers.surfaceSlot(m, "floor", "floor_corner", P(13.2, 0.07, 31.8) * FACE_LEFT, Vector3.new(2.6, 6, 2.6), {
		width = 3,
		depth = 3,
		height = 8,
	})
	Markers.surfaceSlot(m, "plant", "plant_entry", P(-13, 0.07, 14.5) * FACE_RIGHT, Vector3.new(2.6, 6, 2.6), {
		width = 3,
		depth = 3,
		height = 8,
	})
	Markers.surfaceSlot(m, "lamp", "lamp_bed", P(-4.6, 0.07, WALL_A + 2.4) * FACE_IN, Vector3.new(2, 6, 2), {
		width = 2.4,
		depth = 2.4,
		height = 8,
	})

	m.Parent = parent
	return m
end

return Unit
