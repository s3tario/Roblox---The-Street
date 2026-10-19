--!strict
-- One Galleria boutique's shell (bake-safe): the glazed shopfront on the atrium (stall riser, plate glass with a
-- transom, piers, the doorway with a brass head and threshold, a lit fascia carrying the shop's name and mark), two
-- display-window plinths behind the glass, the floor finish, wall liners with a rail and crown, the ceiling and its
-- lights. The shop modules (Tailor, Watches, Shoes, Maison) dress the rest.
--
-- Boutique-local coordinates (Plan.point): sx along the front, sd = depth from the atrium face. The shopfront wall
-- takes sd 0..FRONT_T; the shop floor runs sd FRONT_T..DEPTH and sx -HALF_L..HALF_L.
--
--   Boutique.shell(parent, spot, F, style) -> Shop
--       Shop = { model, P = (sx, y, sd) -> CFrame (world), windows = { CFrame }, style }
--       windows[i] = the top centre of display-window plinth i (1 at sx < 0, 2 at sx > 0), LookVector out toward
--       the atrium, so a display stands on it facing the passers-by
--   Boutique.box(parent, P, sx0, y0, sd0, sx1, y1, sd1, color, mat?, solid?) -> Part   a box between two corners in
--       boutique-local coordinates (solid = false -> a non-colliding Kit.detail)
--   Boutique.serviceCard(parent, cf, shopId, style) -> Part   the `shop` interact (attribute Shop = shopId): a lit
--       "Service" card and a brass bell standing on a counter (cf = the point on the counter top, LookVector toward
--       the customer)
--   Boutique.FLIP                                           a half turn (turns a frame to face the atrium)

local Venue = script.Parent.Parent.CareerServices.Venue
local Deps = require(Venue.Deps)
local Shell = require(Venue.Shell)
local Paint = require(Venue.Paint)
local Markers = require(Venue.Markers)
local Text = require(Venue.Text)
local Plan = require(script.Parent.Plan)

local Kit = Deps.Kit
local hex = Deps.Palette.hex
local M = Enum.Material

local Boutique = {}

export type Style = {
	name: string, -- fascia text
	sub: string, -- the line under it
	logo: string, -- Logos id (falls back to the monogram)
	monogram: string,
	font: Enum.Font,
	floor: Color3,
	floorMat: Enum.Material,
	floorSeam: Color3?, -- painted tile seams (stone floors)
	wall: Color3,
	wallMat: Enum.Material?,
	rail: Color3,
	ceiling: Color3,
	frame: Color3, -- shopfront metalwork
	fascia: Color3,
	ink: Color3,
	plinth: Color3,
	plinthMat: Enum.Material?,
	light: Color3?,
}

export type PFn = (sx: number, y: number, sd: number) -> CFrame

export type Shop = {
	model: Model,
	P: PFn,
	windows: { CFrame },
	style: Style,
}

Boutique.FLIP = CFrame.Angles(0, math.pi, 0)

local GLASS = hex("#CFE0E8")
local BRASS = hex("#B8933F")
local WARM = hex("#FFE2B0")

local HL = Plan.HALF_L
local D = Plan.DEPTH
local FT = Plan.FRONT_T
local SH = Plan.SHOP_H
local DOOR_HALF = Plan.DOOR_W / 2
local BAY0 = DOOR_HALF + Plan.PIER -- inner edge of a glass bay
local BAY1 = HL - Plan.PIER -- outer edge of a glass bay
local BAY_C = (BAY0 + BAY1) / 2

function Boutique.box(
	parent: Instance,
	P: PFn,
	sx0: number,
	y0: number,
	sd0: number,
	sx1: number,
	y1: number,
	sd1: number,
	color: Color3,
	mat: Enum.Material?,
	solid: boolean?
): Part
	local cf = P((sx0 + sx1) / 2, (y0 + y1) / 2, (sd0 + sd1) / 2)
	local size = Vector3.new(math.abs(sx1 - sx0), math.abs(y1 - y0), math.abs(sd1 - sd0))
	if solid == false then
		return Kit.detail(parent, cf, size, color, mat or M.SmoothPlastic)
	end
	return Kit.block(parent, cf, size, color, mat or M.SmoothPlastic)
end

local function mark(parent: Instance, cf: CFrame, logo: string, monogram: string, style: Style): Part
	local plate =
		Kit.detail(parent, cf * CFrame.new(0, 0, -0.06), Vector3.new(2.6, 2.6, 0.12), style.fascia, M.SmoothPlastic)
	plate.Name = "ShopMark"
	if not (Deps.hasLogo(logo) and Deps.logo(plate, Enum.NormalId.Front, logo, { theme = "dark", padding = 0.1 })) then
		Kit.sign(plate, monogram, { font = style.font, color = style.ink, pixelsPerStud = 40, padding = 0.14 })
	end
	return plate
end

local function shopfront(m: Model, P: PFn, style: Style)
	local f = Kit.model(m, "Shopfront")
	local riser = Kit.shade(style.frame, -0.25)
	for _, s in { -1, 1 } do
		-- stall riser, plate glass, a mullion and a transom in each bay
		local a, b = s * BAY0, s * BAY1
		Boutique.box(f, P, a, 0, 0, b, Plan.GLASS_Y0, FT, riser, M.Granite).Name = "StallRiser"
		local glass = Boutique.box(f, P, a, Plan.GLASS_Y0, 0.4, b, Plan.DOOR_H, 0.6, GLASS, M.Glass)
		glass.Name = "ShopWindow"
		glass.Transparency = 0.74
		glass.Reflectance = 0.18
		glass.CastShadow = false
		Boutique.box(
			f,
			P,
			s * BAY_C - 0.15,
			Plan.GLASS_Y0,
			-0.1,
			s * BAY_C + 0.15,
			Plan.DOOR_H,
			0.4,
			style.frame,
			M.Metal,
			false
		).Name =
			"Mullion"
		Boutique.box(f, P, a, 8.4, -0.1, b, 8.7, 0.4, style.frame, M.Metal, false).Name = "Transom"
		-- piers at the ends and either side of the door
		Boutique.box(f, P, s * HL, 0, 0, s * BAY1, Plan.FRONT_H, FT, style.frame, M.Metal).Name = "Pier"
		Boutique.box(f, P, s * DOOR_HALF, 0, 0, s * BAY0, Plan.DOOR_H, FT, style.frame, M.Metal).Name = "DoorJamb"
	end
	-- the header over the glass and the door, its fascia sign and the shop's mark either side
	Boutique.box(f, P, -HL, Plan.DOOR_H, 0, HL, Plan.FRONT_H, FT, style.fascia, M.SmoothPlastic).Name = "Header"
	local outward = Boutique.FLIP
	local name = Shell.plate(f, P(0, 13.2, 0) * outward, 17, 2.4, style.name, {
		color = style.fascia,
		ink = style.ink,
		font = style.font,
		pps = 40,
		glow = true,
		padding = 0.08,
	})
	name.Name = "Fascia"
	name:AddTag("InteriorLight")
	Shell.plate(f, P(0, 11.35, 0) * outward, 12, 0.9, style.sub, {
		color = style.fascia,
		ink = Kit.shade(style.ink, -0.15),
		font = Enum.Font.GothamMedium,
		pps = 40,
		padding = 0.1,
	}).Name =
		"FasciaSub"
	for _, s in { -1, 1 } do
		mark(f, P(s * 13.5, 13.2, 0) * outward, style.logo, style.monogram, style)
	end
	-- brass door head and threshold, and the lighting strip under the fascia
	Boutique.box(f, P, -DOOR_HALF, Plan.DOOR_H - 0.3, -0.12, DOOR_HALF, Plan.DOOR_H, FT + 0.12, BRASS, M.Metal, false).Name =
		"DoorHead"
	Boutique.box(f, P, -DOOR_HALF, 0, 0, DOOR_HALF, 0.05, FT, BRASS, M.Metal, false).Name = "Threshold"
	local strip = Shell.glow(f, P(0, 10.62, -0.25), Vector3.new(2 * BAY1, 0.12, 0.3), WARM)
	strip.Name = "FasciaLight"
end

local function interior(m: Model, P: PFn, style: Style)
	local s = Kit.model(m, "Interior")
	local floor = Boutique.box(s, P, -HL, 0, FT, HL, 0.06, D, style.floor, style.floorMat, false)
	floor.Name = "ShopFloor"
	floor.CastShadow = false
	if style.floorSeam then
		local gui, W, H = Paint.surface(floor, Enum.NormalId.Top, 2, { maxDistance = 160 })
		Paint.grid(gui, W, H, 12, style.floorSeam, 0.55)
	end
	-- wall liners in the shop's colour (left, right, back), a rail and a crown on each
	local wm = style.wallMat or M.SmoothPlastic
	Boutique.box(s, P, -HL, 0, FT, -HL + 0.1, SH, D, style.wall, wm, false).Name = "WallLiner"
	Boutique.box(s, P, HL - 0.1, 0, FT, HL, SH, D, style.wall, wm, false).Name = "WallLiner"
	Boutique.box(s, P, -HL, 0, D - 0.1, HL, SH, D, style.wall, wm, false).Name = "WallLiner"
	for _, y in { 3.4, SH - 0.6 } do
		local h = if y < 5 then 0.3 else 0.6
		Boutique.box(s, P, -HL, y, FT, -HL + 0.25, y + h, D, style.rail, M.Wood, false).Name = "Rail"
		Boutique.box(s, P, HL - 0.25, y, FT, HL, y + h, D, style.rail, M.Wood, false).Name = "Rail"
		Boutique.box(s, P, -HL, y, D - 0.25, HL, y + h, D, style.rail, M.Wood, false).Name = "Rail"
	end
	Boutique.box(s, P, -HL, SH, FT, HL, SH + 1, D, style.ceiling, M.SmoothPlastic).Name = "ShopCeiling"
	-- two ceiling panels; the deeper one carries the shop's light
	Shell.glow(s, P(0, SH - 0.06, 9), Vector3.new(16, 0.1, 3.4), hex("#FFF4E2")).Transparency = 0.2
	Shell.glow(s, P(0, SH - 0.06, 20), Vector3.new(16, 0.1, 3.4), hex("#FFF4E2"), {
		range = 38,
		brightness = 0.95,
		color = style.light or WARM,
	}).Transparency =
		0.2
	-- the display-window plinths behind the glass, lit from the header
	for _, sgn in { -1, 1 } do
		local plinth = Boutique.box(
			s,
			P,
			sgn * (BAY0 + 0.4),
			0,
			FT,
			sgn * (BAY1 - 0.4),
			0.8,
			FT + Plan.WINDOW_D,
			style.plinth,
			style.plinthMat or M.Marble
		)
		plinth.Name = "WindowPlinth"
		Shell.glow(s, P(sgn * BAY_C, SH - 0.06, FT + 1.5), Vector3.new(BAY1 - BAY0 - 1, 0.1, 0.6), WARM).Name =
			"WindowLight"
	end
end

function Boutique.shell(parent: Instance, spot: Plan.ShopSpot, F: Shell.Frame, style: Style): Shop
	local base = CFrame.new(F.origin) * spot.frame
	local function P(sx: number, y: number, sd: number): CFrame
		return Plan.point(base, sx, y, sd)
	end
	local m = Kit.model(parent, spot.model)
	m:SetAttribute("Shop", spot.id)
	m:SetAttribute("Boutique", true)
	shopfront(m, P, style)
	interior(m, P, style)
	local outward = Boutique.FLIP
	local windows = {
		P(-BAY_C, 0.8, FT + Plan.WINDOW_D / 2) * outward,
		P(BAY_C, 0.8, FT + Plan.WINDOW_D / 2) * outward,
	}
	return { model = m, P = P, windows = windows, style = style }
end

function Boutique.serviceCard(parent: Instance, cf: CFrame, shopId: string, style: Style): Part
	local g = Kit.model(parent, "Service")
	Kit.cylinder(g, cf * CFrame.new(1.1, 0.04, 0), 0.08, 0.8, Kit.shade(BRASS, -0.2), M.Metal, {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}).Name =
		"BellBase"
	Kit.ball(g, cf * CFrame.new(1.1, 0.12, 0), 0.6, BRASS, M.Metal, {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}).Name =
		"Bell"
	local card = Kit.block(
		g,
		cf * CFrame.new(-0.2, 0.62, 0) * CFrame.Angles(math.rad(-10), 0, 0),
		Vector3.new(1.9, 1.2, 0.08),
		style.fascia,
		M.SmoothPlastic,
		{ CanCollide = false, CanTouch = false, CastShadow = false }
	)
	card.Name = "ServiceCard"
	Kit.sign(card, Text.get("gal_counter"), {
		font = style.font,
		color = style.ink,
		pixelsPerStud = 80,
		glow = true,
		padding = 0.14,
	})
	Markers.interact(card, "shop", { Shop = shopId })
	return card
end

return Boutique
