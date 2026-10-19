--!strict
-- Hartwell Tailors (the Galleria's north-west boutique; Config/Shop "tailor"). Bake-safe.
--
--   windows      two dressed mannequins (NpcRig + Wardrobe, anchored) on marble plinths behind the glass
--   left wall    two rolling racks of suits in the house colours
--   centre       a walnut display table of folded shirts on a Persian rug; the Hartwell Bespoke look on a round
--                plinth with its card
--   back         the fabric wall (bolts of cloth in walnut cubbies), the cash counter with npc_tailor behind it and
--                the `shop` interact (Shop = "tailor") on its service card
--   back right   the fitting room (a curtained booth) and, in front of it, a three-way mirror on a dais: the cheval
--                glass is the `wardrobe` interact
--
--   Tailor.build(parent, mk, spot, F, rng) -> Model
--   Tailor.LOOKS = { window_a, window_b, bespoke }   the Config/Catalog outfits on the mannequins

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

local Tailor = {}

local WALNUT = hex("#5A3A26")
local WALNUT_DARK = hex("#3E2819")
local BRASS = hex("#B8933F")
local MARBLE = hex("#ECEAE6")
local NAVY = hex("#1B2A44")
local CREAM = hex("#F2E6C4")

local STYLE: Boutique.Style = {
	name = Text.get("gal_tailor"),
	sub = Text.get("gal_tailor_sub"),
	logo = "brand_hartwell",
	monogram = Text.get("gal_mono_tailor"),
	font = Enum.Font.Bodoni,
	floor = hex("#6B4A32"),
	floorMat = M.WoodPlanks,
	wall = hex("#2F3D35"),
	wallMat = M.Fabric,
	rail = WALNUT,
	ceiling = hex("#EDE6D8"),
	frame = hex("#22302A"),
	fascia = NAVY,
	ink = hex("#E3C46F"),
	plinth = MARBLE,
	plinthMat = M.Marble,
	light = hex("#FFE2B0"),
}

Tailor.STYLE = STYLE

Tailor.LOOKS = {
	window_a = {
		outer = "suit_navy_2b",
		bottom = "suit_navy_trousers",
		top = "shirt_poplin_white",
		neck = "tie_navy",
		shoes = "oxford_black",
	},
	window_b = {
		outer = "blazer_navy",
		top = "blouse_tieneck_navy",
		bottom = "skirt_pencil_charcoal",
		shoes = "heels_slingback",
	},
	bespoke = {
		outer = "bespoke_chalk_db",
		bottom = "bespoke_chalk_trousers",
		top = "shirt_bespoke",
		neck = "tie_sevenfold",
		shoes = "oxford_bespoke_black",
	},
} :: { [string]: { [string]: string } }

-- suit cloths on the racks and in the cubbies
local CLOTHS = {
	hex("#1D2A47"),
	hex("#3A3D44"),
	hex("#6C7078"),
	hex("#16171A"),
	hex("#A9834F"),
	hex("#1B2742"),
	hex("#5A4A3A"),
	hex("#7A1F24"),
}

local FACE_OUT = Boutique.FLIP -- toward the door
local FACE_RIGHT = CFrame.Angles(0, -math.pi / 2, 0) -- LookVector +sx

local function fabricWall(m: Instance, P: Boutique.PFn, rng: Deps.RngT)
	local wall = Boutique.box(m, P, -21.9, 0, 26.6, 13.6, 11, 27.9, WALNUT_DARK, M.Wood)
	wall.Name = "FabricWall"
	-- the cubbies face the shop (the part's Back face looks toward the door)
	local gui, W, H = Paint.surface(wall, Enum.NormalId.Back, 6, { maxDistance = 220, name = "Bolts" })
	Core.bg(gui, WALNUT_DARK)
	local cols, rows = 10, 4
	local cw, ch = W / cols, H / rows
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local x, y = c * cw, r * ch
			Core.px(gui, x + 3, y + 3, cw - 6, ch - 6, hex("#24170F"))
			-- two or three bolts of cloth lying in each cubby
			local n = rng:int(2, 3)
			local bh = (ch - 10) / 3
			for k = 0, n - 1 do
				local cloth = rng:pick(CLOTHS)
				local bolt = Core.px(gui, x + 6, y + ch - 5 - bh * (k + 1), cw - 12, bh - 1, cloth)
				Core.round(bolt, 0.3)
				Core.px(gui, x + 6, y + ch - 5 - bh * (k + 1), 4, bh - 1, Kit.shade(cloth, 0.25))
			end
		end
	end
	Shell.plate(m, P(-4, 12.4, 27.9) * FACE_OUT, 22, 0.9, Text.get("gal_fabric"), {
		color = NAVY,
		ink = CREAM,
		font = Enum.Font.Garamond,
		pps = 40,
	}).Name =
		"FabricPlate"
end

local function fittingRoom(m: Instance, P: Boutique.PFn)
	local f = Kit.model(m, "FittingRoom")
	-- the curtained booth in the back-right corner: a walnut side wall, a header and a curtain drawn aside (the
	-- opening stays over 6 studs wide)
	Boutique.box(f, P, 13.8, 0, 19.5, 14.2, 10, 27.9, WALNUT, M.Wood).Name = "BoothWall"
	Boutique.box(f, P, 13.8, 10, 19.3, 21.9, 14, 19.7, WALNUT, M.Wood).Name = "BoothHeader"
	local curtain = Boutique.box(f, P, 14.2, 0.3, 19.4, 15.8, 9.8, 19.7, hex("#6E1A1F"), M.Fabric, false)
	curtain.Name = "Curtain"
	local cg = Core.surface(curtain, Enum.NormalId.Back, { pps = 20, maxDistance = 120 })
	Core.stripes(Core.bg(cg, hex("#6E1A1F")), { hex("#7E2228"), hex("#5A1418") }, 5, 0)
	Boutique.box(f, P, 14.2, 9.8, 19.45, 21.9, 10, 19.65, BRASS, M.Metal, false).Name = "CurtainRail"
	Shell.plate(f, P(18, 12, 19.3) * FACE_OUT, 7, 1, Text.get("gal_tailor_fitting"), {
		color = NAVY,
		ink = hex("#E3C46F"),
		font = Enum.Font.Bodoni,
		pps = 40,
	}).Name =
		"FittingSign"
	Furniture.stool(f, P(18.5, 0.06, 25.5), 2.1, hex("#3B2A20"), BRASS)
	Kit.detail(f, P(21.6, 6.5, 23), Vector3.new(0.3, 0.3, 1.6), BRASS, M.Metal).Name = "Hook"

	-- the three-way mirror on its dais
	local dais = Kit.cylinder(f, P(9, 0.25, 17.4), 0.5, 5.2, MARBLE, M.Marble)
	dais.Name = "MirrorDais"
	Kit.cylinder(f, P(9, 0.03, 17.4), 0.06, 5.6, BRASS, M.Metal, { CanCollide = false }).Name = "DaisRim"
	local mm =
		Props.build("mirror_full", f, P(9, 0.06, 21.4) * FACE_OUT, { color = hex("#C9A54C"), seed = "gal-mirror" })
	local mirror = mm:FindFirstChild("Mirror", true)
	if mirror and mirror:IsA("BasePart") then
		Markers.interact(mirror, "wardrobe")
	else
		local glass = Kit.block(f, P(9, 3.2, 21.4) * FACE_OUT, Vector3.new(2, 5, 0.1), hex("#DDE3E8"), M.Glass, {
			CanCollide = false,
		})
		glass.Name = "Mirror"
		glass.Reflectance = 0.6
		Markers.interact(glass, "wardrobe")
	end
	for _, s in { -1, 1 } do
		local wing = Kit.detail(
			f,
			P(9 + s * 2.6, 3.4, 20.6) * FACE_OUT * CFrame.Angles(0, math.rad(s * 32), 0),
			Vector3.new(2, 5.6, 0.1),
			hex("#D5DEE4"),
			M.Glass
		)
		wing.Name = "MirrorWing"
		wing.Reflectance = 0.5
	end
	Furniture.pendant(f, P(9, Plan.SHOP_H, 17.4), 3.6, hex("#FFE7BF"))
end

function Tailor.build(parent: Instance, mk: Instance, spot: Plan.ShopSpot, F: Shell.Frame, rng: Deps.RngT): Model
	local shop = Boutique.shell(parent, spot, F, STYLE)
	local m, P = shop.model, shop.P

	-- the window mannequins face the atrium
	Deps.mannequin(m, shop.windows[1], Tailor.LOOKS.window_a, "Mannequin_WindowA")
	Deps.mannequin(m, shop.windows[2], Tailor.LOOKS.window_b, "Mannequin_WindowB")

	-- racks of suits along the left wall
	for i, sd in { 9.5, 16 } do
		Props.build("clothing_rack", m, P(-19.8, 0.06, sd) * FACE_RIGHT, {
			count = 9,
			colors = rng:shuffle(table.clone(CLOTHS)),
			seed = "gal-rack" .. i,
		})
	end

	-- the display table on its rug, and the bespoke look on a round plinth
	Props.build("rug_persian", m, P(-6.5, 0.07, 12.5) * FACE_RIGHT, { seed = "gal-tailor-rug" })
	Props.build(
		"display_table",
		m,
		P(-6.5, 0.07, 12.5) * FACE_OUT,
		{ colors = { "#F2F0EA", "#7FA7D9", "#F4F1EA", "#B9AD98" }, seed = "gal-shirts" }
	)
	local plinth = Kit.cylinder(m, P(7.5, 0.4, 9.5), 0.8, 3.4, MARBLE, M.Marble)
	plinth.Name = "BespokePlinth"
	Kit.cylinder(m, P(7.5, 0.82, 9.5), 0.04, 3.5, BRASS, M.Metal, { CanCollide = false }).Name = "PlinthRim"
	Deps.mannequin(m, P(7.5, 0.8, 9.5) * FACE_OUT, Tailor.LOOKS.bespoke, "Mannequin_Bespoke")
	Kit.detail(m, P(10.4, 1.6, 8.2), Vector3.new(0.18, 3.2, 0.18), BRASS, M.Metal).Name = "CardStand"
	Shell.plate(
		m,
		P(10.4, 3.6, 8.1) * FACE_OUT * CFrame.Angles(math.rad(-12), 0, 0),
		2.6,
		1.1,
		Text.get("gal_bespoke"),
		{
			color = NAVY,
			ink = hex("#E3C46F"),
			font = Enum.Font.Bodoni,
			pps = 60,
		}
	).Name =
		"BespokeCard"

	-- the back: fabric wall, counter, tailor, service card
	fabricWall(m, P, rng)
	Props.build("cash_counter", m, P(-7, 0.06, 22.5) * FACE_OUT, {
		text = STYLE.name,
		color = WALNUT,
		accent = BRASS,
		seed = "gal-tailor-counter",
	})
	Boutique.serviceCard(m, P(-4.2, 0.06 + 3.55, 22.0) * FACE_OUT, spot.id, STYLE)
	Markers.npc(mk, "npc_tailor", P(-7, 3, 25.4) * FACE_OUT)
	Furniture.pendant(m, P(-6.5, Plan.SHOP_H, 12.5), 4.2, hex("#FFE7BF"))
	Props.build("plant_floor", m, P(-19.5, 0.06, 25), { seed = "gal-tailor-plant" })

	fittingRoom(m, P)
	return m
end

return Tailor
