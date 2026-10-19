--!strict
-- The Galleria's structure and atrium (bake-safe): the shell (granite floor slab, end walls, the boutiques' outer
-- walls and partitions, the upper atrium walls), the glass barrel vault on iron ribs under a painted sky box (fully
-- enclosed: the "daylight" is painted and glows), a painted arcade of arched windows above the shopfronts with stone
-- pilasters and cornices, a marble floor with a compass medallion, the street doors (door_galleria_exit) and the
-- arrival point (galleria_entry), the great clock on the north wall, a fountain court with benches and planters, the
-- directory totem, the boutiques' hanging banners and four globe pendants.
--
--   Atrium.build(parent, mk, F, rng) -> ()

local Venue = script.Parent.Parent.CareerServices.Venue
local Deps = require(Venue.Deps)
local Shell = require(Venue.Shell)
local Paint = require(Venue.Paint)
local Markers = require(Venue.Markers)
local Furniture = require(Venue.Furniture)
local Text = require(Venue.Text)
local Plan = require(script.Parent.Plan)

local Kit = Deps.Kit
local Props = Deps.Props
local Core = Deps.Gui.Core
local Art = Deps.Gui.Art
local hex = Deps.Palette.hex
local M = Enum.Material

local Atrium = {}

local X, Z, AX = Plan.X, Plan.Z, Plan.AX
local AH = Plan.ATRIUM_H
local R = Plan.VAULT_R
local SPRING = Plan.VAULT_SPRING
local VZ = Plan.VAULT_Z
local SKY_X, SKY_TOP = Plan.SKY_X, Plan.SKY_TOP
local SH = Plan.SHOP_H

local MARBLE = hex("#ECEAE6")
local VEIN = hex("#C2BCB0")
local STONE = hex("#D9D2C3")
local STONE_DARK = hex("#BEB5A3")
local GRANITE = hex("#3A3C40")
local IRON = hex("#34362F")
local BRASS = hex("#B8933F")
local GOLD_BRIGHT = hex("#E3C46F")
local NAVY = hex("#1B2A44")
local CREAM = hex("#F2E6C4")
local GLASS = hex("#BFD6E2")
local CEILING = hex("#E9E4D8")
local WALNUT = hex("#5A3A26")
local WINDOW_DARK = hex("#2E3A44")
local WINDOW_LIT = hex("#F3D9A4")

---------------------------------------------------------------------------------------------------
-- Painted surfaces
---------------------------------------------------------------------------------------------------
-- The arcade above the shopfronts: one arched window per bay between the pilasters, a balustrade under each.
local function arcade(part: BasePart, face: Enum.NormalId)
	local gui, W, H = Paint.surface(part, face, 3, { maxDistance = 420, name = "Arcade" })
	Core.bg(gui, STONE)
	local bays = #Plan.PILASTER_Z - 1
	local bw = W / bays
	for i = 0, bays - 1 do
		local x0 = i * bw
		Core.px(gui, x0 + bw * 0.08, H * 0.08, bw * 0.84, H * 0.84, STONE_DARK, 0.6).Name = "Recess"
		local ww = bw * 0.56
		local wx = x0 + (bw - ww) / 2
		local top, bottom = H * 0.16, H * 0.84
		local r = ww / 2
		Core.dot(gui, wx + r, top + r, ww, WINDOW_DARK)
		Core.px(gui, wx, top + r, ww, bottom - top - r, WINDOW_DARK)
		local inset = ww * 0.08
		Core.dot(gui, wx + r, top + r, ww - inset * 2, WINDOW_LIT)
		local pane = Core.px(gui, wx + inset, top + r, ww - inset * 2, bottom - top - r - inset, WINDOW_LIT)
		Core.gradient(pane, hex("#F7E3B8"), hex("#C99A5A"), 90)
		Core.px(gui, wx + r - 1, top + inset, 3, bottom - top - inset * 2, IRON).Name = "Mullion"
		Core.px(gui, wx + inset, top + r + (bottom - top) * 0.22, ww - inset * 2, 3, IRON).Name = "Transom"
		-- keystone and the balustrade
		Core.px(gui, wx + r - 4, top - 3, 8, 10, STONE_DARK).Name = "Keystone"
		Core.px(gui, x0 + bw * 0.12, H * 0.86, bw * 0.76, 3, STONE_DARK).Name = "Rail"
		local n = 11
		for k = 0, n - 1 do
			local bx = x0 + bw * 0.14 + (bw * 0.72) * k / (n - 1)
			local b = Core.px(gui, bx - 2, H * 0.88, 4, H * 0.1, STONE_DARK)
			Core.round(b, 0.4)
		end
	end
end

-- The fan window painted on a gable: a semicircle of glass on the spring line with radiating iron bars.
local function lunette(part: BasePart, face: Enum.NormalId)
	local pps = 4
	local gui, W, H =
		Paint.surface(part, face, pps, { maxDistance = 420, glow = true, brightness = 1, name = "Lunette" })
	Core.bg(gui, STONE)
	local cx, cy = W / 2, H
	local r = R * pps
	Core.dot(gui, cx, cy, r * 2, IRON)
	local glass = Core.dot(gui, cx, cy, r * 2 - 8, hex("#DCEBF3"))
	Core.gradient(glass, hex("#9CC2E2"), hex("#E8F1F5"), 90)
	for k = 1, 11 do
		local a = math.rad(k * 15)
		Core.line(gui, cx, cy, cx + math.cos(a) * r, cy - math.sin(a) * r, 3, IRON)
	end
	Core.dot(gui, cx, cy, r * 0.9, IRON)
	Core.dot(gui, cx, cy, r * 0.9 - 6, hex("#E8F1F5"))
	Core.dot(gui, cx, cy, r * 0.3, IRON)
end

---------------------------------------------------------------------------------------------------
-- Structure
---------------------------------------------------------------------------------------------------
local function structure(m: Instance, F: Shell.Frame)
	local s = Kit.model(m, "Structure")
	Shell.box(s, F, -X - 1, -1, -Z - 1, X + 1, 0, Z + 1, GRANITE, M.Slate).Name = "FloorSlab"
	for _, sz in { -1, 1 } do
		local z0, z1 = if sz < 0 then -Z - 1 else Z, if sz < 0 then -Z else Z + 1
		-- the atrium's end walls run to the ceiling; the boutiques' end walls stop just above their ceilings
		Shell.box(s, F, -AX - 1, 0, z0, AX + 1, AH + Plan.SLAB, z1, STONE, M.Limestone).Name = "EndWall"
		for _, sx in { -1, 1 } do
			Shell.box(s, F, sx * (AX + 1), 0, z0, sx * (X + 1), SH + 1, z1, STONE, M.SmoothPlastic).Name = "ShopEndWall"
		end
		-- the atrium ceiling: a slab at each end beyond the vault, strips along its sides
		Shell.box(s, F, -AX - 1, AH, sz * VZ, AX + 1, AH + Plan.SLAB, sz * Z, CEILING, M.SmoothPlastic).Name =
			"CeilingSlab"
		Shell.box(s, F, sz * R, AH, -VZ, sz * (AX + 1), AH + Plan.SLAB, VZ, CEILING, M.SmoothPlastic).Name =
			"CeilingSlab"
	end
	for _, sx in { -1, 1 } do
		Shell.box(s, F, sx * X, 0, -Z, sx * (X + 1), SH + 1, Z, STONE, M.SmoothPlastic).Name = "BackWall"
		Shell.box(s, F, sx * (AX + 1), 0, -Plan.PART_HALF, sx * X, SH + 1, Plan.PART_HALF, STONE, M.SmoothPlastic).Name =
			"Partition"
		local upper = Shell.box(s, F, sx * AX, Plan.FRONT_H, -Z, sx * (AX + 1), AH + Plan.SLAB, Z, STONE, M.Limestone)
		upper.Name = "UpperWall"
		arcade(upper, if sx < 0 then Enum.NormalId.Right else Enum.NormalId.Left)
		-- the stone pilaster between the two shopfronts, full height (it also closes the partition's end)
		Shell.box(s, F, sx * (AX - 0.6), 0, -Plan.PART_HALF, sx * (AX + 1), AH, Plan.PART_HALF, STONE_DARK, M.Limestone).Name =
			"Pilaster"
		Shell.box(s, F, sx * (AX - 1), 0, -1.5, sx * AX, 1.2, 1.5, GRANITE, M.Granite).Name = "PilasterBase"
	end
end

---------------------------------------------------------------------------------------------------
-- Upper walls: pilasters and cornices
---------------------------------------------------------------------------------------------------
local function upperTrim(m: Instance, F: Shell.Frame)
	local t = Kit.model(m, "UpperTrim")
	for _, sx in { -1, 1 } do
		for _, z in Plan.PILASTER_Z do
			if z ~= 0 then
				Shell.box(
					t,
					F,
					sx * (AX - 0.6),
					Plan.FRONT_H,
					z - 0.8,
					sx * AX,
					AH,
					z + 0.8,
					STONE_DARK,
					M.Limestone,
					false
				).Name =
					"Pilaster"
			end
		end
		-- the gallery cornice over the shopfronts and the crown under the ceiling
		Shell.box(t, F, sx * (AX - 1), Plan.FRONT_H, -Z, sx * AX, Plan.FRONT_H + 0.9, Z, STONE_DARK, M.Limestone, false).Name =
			"Cornice"
		Shell.box(t, F, sx * (AX - 0.8), AH - 0.8, -Z, sx * AX, AH, Z, STONE_DARK, M.Limestone, false).Name = "Crown"
	end
end

---------------------------------------------------------------------------------------------------
-- The glass barrel vault and its sky
---------------------------------------------------------------------------------------------------
local function vault(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local v = Kit.model(m, "Vault")
	local n = Plan.VAULT_SEGMENTS
	local L = VZ * 2
	local function at(theta: number, radius: number, z: number): Vector3
		return F.v(radius * math.cos(theta), SPRING + radius * math.sin(theta), z)
	end
	for i = 0, n - 1 do
		local a, b = math.pi * i / n, math.pi * (i + 1) / n
		-- one glass panel per segment, the full length of the vault (local X runs along the vault)
		local pa, pb = at(a, R, 0), at(b, R, 0)
		local glass =
			Kit.detail(v, CFrame.lookAt((pa + pb) / 2, pb), Vector3.new(L, 0.15, (pb - pa).Magnitude), GLASS, M.Glass)
		glass.Name = "VaultGlass"
		glass.Transparency = 0.62
		glass.Reflectance = 0.12
		glass.CastShadow = false
		-- the iron ribs: one arc segment per rib line
		for _, rz in Plan.RIB_Z do
			local z = math.clamp(rz, -VZ + 0.3, VZ - 0.3)
			local ra, rb = at(a, R - 0.35, z), at(b, R - 0.35, z)
			Kit.detail(
				v,
				CFrame.lookAt((ra + rb) / 2, rb),
				Vector3.new(0.6, 0.7, (rb - ra).Magnitude + 0.25),
				IRON,
				M.Metal
			).Name =
				"Rib"
		end
		-- purlins along the joints between panels
		if i > 0 then
			Kit.detail(v, CFrame.new(at(a, R - 0.3, 0)), Vector3.new(0.35, 0.35, L), IRON, M.Metal).Name = "Purlin"
		end
	end
	for _, sx in { -1, 1 } do
		Kit.detail(v, CFrame.new(F.v(sx * R, SPRING + 0.2, 0)), Vector3.new(0.9, 0.4, L), IRON, M.Metal).Name =
			"SpringBeam"
	end
	Kit.detail(v, CFrame.new(F.v(0, SPRING + R, 0)), Vector3.new(1.2, 0.5, L), IRON, M.Metal).Name = "Ridge"
	-- the gables close the vault's ends; their faces carry a painted fan window
	for _, sz in { -1, 1 } do
		local g = Shell.box(v, F, -SKY_X, SPRING, sz * VZ, SKY_X, SKY_TOP, sz * (VZ + 1), STONE, M.Limestone, false)
		g.Name = "Gable"
		lunette(g, if sz < 0 then Enum.NormalId.Back else Enum.NormalId.Front)
	end
	-- the sky box: a lid and two sides around the vault, painted sky that glows like daylight
	local lid = Shell.box(v, F, -SKY_X, SKY_TOP - 1, -VZ, SKY_X, SKY_TOP, VZ, hex("#9CC2E2"), M.SmoothPlastic, false)
	lid.Name = "SkyLid"
	lid.CastShadow = false
	local lg, LW, LH = Paint.surface(lid, Enum.NormalId.Bottom, 2, { glow = true, brightness = 1.1, name = "Sky" })
	Paint.sky(lg, LW, LH, rng, "day")
	for _, sx in { -1, 1 } do
		local side = Shell.box(
			v,
			F,
			sx * (SKY_X - 0.5),
			SPRING,
			-VZ,
			sx * SKY_X,
			SKY_TOP - 1,
			VZ,
			hex("#9CC2E2"),
			M.SmoothPlastic,
			false
		)
		side.Name = "SkySide"
		side.CastShadow = false
		local sg, SW, SHh = Paint.surface(side, if sx < 0 then Enum.NormalId.Right else Enum.NormalId.Left, 2, {
			glow = true,
			brightness = 1.1,
			name = "Sky",
		})
		Paint.sky(sg, SW, SHh, rng, "day")
	end
end

---------------------------------------------------------------------------------------------------
-- Floors
---------------------------------------------------------------------------------------------------
local function floors(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local f = Kit.model(m, "Floors")
	local marble = Shell.box(f, F, -AX, 0, -Z, AX, 0.06, Z, MARBLE, M.Marble, false)
	marble.Name = "AtriumFloor"
	marble.CastShadow = false
	local gui, W, H = Paint.surface(marble, Enum.NormalId.Top, 4, { maxDistance = 0 })
	Paint.grid(gui, W, H, 24, VEIN, 0.5)
	Paint.marble(gui, W, H, rng, VEIN, 22)
	-- a granite border with a brass inlay line
	for _, r in { { 0, 0, W, 10 }, { 0, H - 10, W, 10 }, { 0, 0, 10, H }, { W - 10, 0, 10, H } } do
		Core.px(gui, r[1], r[2], r[3], r[4], GRANITE)
	end
	Core.stroke(Core.px(gui, 14, 14, W - 28, H - 28, MARBLE, 1), BRASS, 2)
	-- the compass medallion in the entrance court
	local med = Shell.box(f, F, -9, 0.06, 9, 9, 0.09, 27, MARBLE, M.Marble, false)
	med.Name = "Medallion"
	med.CastShadow = false
	local mg, MW, MH = Paint.surface(med, Enum.NormalId.Top, 6, { maxDistance = 0 })
	Paint.medallion(mg, MW, MH, { NAVY, MARBLE, hex("#7A6A55"), MARBLE, BRASS })
end

---------------------------------------------------------------------------------------------------
-- The entrance (south)
---------------------------------------------------------------------------------------------------
local function entrance(m: Instance, mk: Instance, F: Shell.Frame, rng: Deps.RngT)
	local e = Kit.model(m, "Entrance")
	Shell.exit(e, mk, "door_galleria_exit", F.cf(0, 0, Z, Shell.N), {
		label = Text.get("exit"),
		style = "glass",
		frameColor = BRASS,
		signColor = hex("#14161A"),
		inkColor = GOLD_BRIGHT,
		font = Enum.Font.Garamond,
	})
	Markers.anchor(mk, "galleria_entry", F.cf(0, 3, Plan.ENTRY_Z, Shell.N))
	Shell.box(e, F, -6, 0.06, Z - 8, 6, 0.12, Z - 0.5, NAVY, M.Carpet, false).Name = "EntryMat"
	Shell.plate(e, F.cf(0, 14.2, Z, Shell.N), 18, 2.2, Text.get("gal_name"), {
		color = NAVY,
		ink = GOLD_BRIGHT,
		font = Enum.Font.Bodoni,
		pps = 40,
	}).Name =
		"EntranceName"
	Shell.plate(e, F.cf(0, 12.6, Z, Shell.N), 14, 0.8, Text.get("gal_sub"), {
		color = NAVY,
		ink = CREAM,
		font = Enum.Font.GothamMedium,
		pps = 40,
	}).Name =
		"EntranceSub"
	-- the tall window over the doors, looking out across the Street
	Shell.window(e, F.cf(0, 24, Z, Shell.N), 16, 12, rng, {
		view = "street",
		mood = "day",
		frame = BRASS,
		transom = true,
		glass = true,
		mullions = 3,
		pps = 8,
	}).Name =
		"StreetWindow"
	for _, sx in { -1, 1 } do
		Furniture.plant(e, F.cf(sx * 9, 0, Z - 3), 1.3, rng)
	end
end

---------------------------------------------------------------------------------------------------
-- The north end: the great clock, the name band, a sculpture and two trees
---------------------------------------------------------------------------------------------------
local function northEnd(m: Instance, F: Shell.Frame)
	local n = Kit.model(m, "NorthEnd")
	local wz = -Z
	Kit.cylinder(n, F.cf(0, 25, wz + 0.15) * CFrame.Angles(math.rad(90), 0, 0), 0.3, 10.6, BRASS, M.Metal, {
		CanCollide = false,
	}).Name =
		"ClockRing"
	local dial = Kit.detail(n, F.cf(0, 25, wz + 0.36), Vector3.new(9.6, 9.6, 0.1), MARBLE, M.SmoothPlastic)
	dial.Name = "ClockDial"
	dial.Transparency = 1
	local dg, DW, DH = Core.surface(dial, Enum.NormalId.Back, { pps = 20, maxDistance = 400, name = "Dial" })
	Art.clockFace(dg, DW, DH, 10, 10, NAVY, hex("#F7F3EA"))
	Shell.plate(n, F.cf(0, 32.6, wz, Shell.S), 22, 2.6, Text.get("gal_name"), {
		color = NAVY,
		ink = GOLD_BRIGHT,
		font = Enum.Font.Bodoni,
		pps = 30,
	}).Name =
		"NameBand"
	Shell.plate(n, F.cf(0, 18.6, wz, Shell.S), 14, 1, Text.get("gal_hours"), {
		color = NAVY,
		ink = CREAM,
		font = Enum.Font.Garamond,
		pps = 40,
	}).Name =
		"Hours"
	Props.build("art_pedestal", n, F.cf(0, 0, wz + 4, Shell.S), { variant = "figure", seed = "gal-sculpture" })
	for _, sx in { -1, 1 } do
		Props.build("planter_tree", n, F.cf(sx * 11.5, 0, -38), { seed = "gal-tree" .. sx })
	end
end

---------------------------------------------------------------------------------------------------
-- The fountain court, benches, planters and the directory totem
---------------------------------------------------------------------------------------------------
local function court(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local c = Kit.model(m, "Court")
	Props.build("fountain", c, F.cf(0, 0, -12), { seed = "gal-fountain" })
	for _, sx in { -1, 1 } do
		for _, z in { -12, 22 } do
			Furniture.bench(c, F.cf(sx * 12.5, 0, z, 90), 8, WALNUT, { legs = BRASS, depth = 2.2 })
		end
		Furniture.planter(c, F.cf(sx * 12.5, 0, -27), Vector3.new(2.4, 2.2, 6), { box = GRANITE })
		Furniture.plant(c, F.cf(sx * 12.5, 0, 6), 1.2, rng)
	end
	-- the directory totem, facing the doors
	local d = Kit.model(c, "Directory")
	local cf = F.cf(9, 0, 31, Shell.S)
	Kit.block(d, cf * CFrame.new(0, 0.5, 0), Vector3.new(4.4, 1, 1.6), GRANITE, M.Granite).Name = "TotemBase"
	local panel = Kit.block(d, cf * CFrame.new(0, 4.6, 0), Vector3.new(3.8, 7.2, 0.8), NAVY, M.SmoothPlastic)
	panel.Name = "DirectoryPanel"
	panel:AddTag("InteriorLight")
	local pg = Core.surface(panel, Enum.NormalId.Front, { pps = 40, glow = true, brightness = 1, maxDistance = 160 })
	local bg = Core.bg(pg, NAVY)
	Core.gradient(bg, hex("#24385A"), hex("#121C2C"), 90)
	Core.label(pg, Text.get("gal_directory_title"), 0.08, 0.05, 0.84, 0.1, GOLD_BRIGHT, {
		font = Enum.Font.Bodoni,
		align = Enum.TextXAlignment.Center,
	})
	Core.frame(pg, 0.12, 0.17, 0.76, 0.004, BRASS)
	Core.label(pg, Text.get("gal_directory"), 0.08, 0.22, 0.84, 0.5, CREAM, { font = Enum.Font.GothamMedium })
	Core.label(pg, Text.get("gal_hours"), 0.08, 0.78, 0.84, 0.14, hex("#B9C8D8"), {
		font = Enum.Font.Garamond,
		italic = true,
		align = Enum.TextXAlignment.Center,
	})
	Kit.detail(d, cf * CFrame.new(0, 8.35, 0), Vector3.new(4.2, 0.3, 1.2), BRASS, M.Metal).Name = "TotemCap"
end

---------------------------------------------------------------------------------------------------
-- Banners (one per boutique) and the globe pendants
---------------------------------------------------------------------------------------------------
local BANNERS: { [string]: { color: Color3, name: string, logo: string, mono: string } } = {
	tailor = { color = NAVY, name = "gal_tailor", logo = "brand_hartwell", mono = "gal_mono_tailor" },
	watch = { color = hex("#15161A"), name = "gal_watch", logo = "brand_vanta", mono = "gal_mono_watch" },
	shoes = { color = hex("#34483E"), name = "gal_shoes", logo = "brand_strider", mono = "gal_mono_shoes" },
	decor = { color = hex("#7A3E2E"), name = "gal_decor", logo = "brand_atelier_maison", mono = "gal_mono_decor" },
}

local function banners(m: Instance, F: Shell.Frame)
	local b = Kit.model(m, "Banners")
	for _, spot in Plan.shops do
		local def = BANNERS[spot.id]
		if def then
			local west = spot.side == "west"
			local x = if west then -(AX - 0.9) else AX - 0.9
			local cf = F.cf(x, 25, spot.cz, if west then Shell.E else Shell.W)
			Kit.detail(b, cf * CFrame.new(0, 6.25, 0.25), Vector3.new(5.4, 0.25, 0.25), BRASS, M.Metal).Name =
				"BannerRod"
			local cloth = Kit.detail(b, cf, Vector3.new(4.6, 12, 0.12), def.color, M.Fabric)
			cloth.Name = "Banner"
			local gui = Core.surface(cloth, Enum.NormalId.Front, { pps = 30, maxDistance = 300 })
			Core.stroke(Core.frame(gui, 0.06, 0.03, 0.88, 0.94, def.color, 1), GOLD_BRIGHT, 2).Name = "Inset"
			Core.label(gui, Text.get(def.name), 0.1, 0.5, 0.8, 0.36, CREAM, {
				font = Enum.Font.Bodoni,
				align = Enum.TextXAlignment.Center,
			})
			local mark = Kit.detail(b, cf * CFrame.new(0, 3, -0.08), Vector3.new(3.2, 3.2, 0.05), def.color, M.Fabric)
			mark.Name = "BannerMark"
			if
				not (
					Deps.hasLogo(def.logo)
					and Deps.logo(mark, Enum.NormalId.Front, def.logo, { theme = "dark", padding = 0.06 })
				)
			then
				Kit.sign(mark, Text.get(def.mono), { font = Enum.Font.Bodoni, color = GOLD_BRIGHT, pixelsPerStud = 30 })
			end
		end
	end
end

local function pendants(m: Instance, F: Shell.Frame)
	local p = Kit.model(m, "Pendants")
	local top = SPRING + R - 0.3
	local y = 25
	for _, z in { -30, -10, 10, 30 } do
		local cordLen = top - (y + 1.5)
		Kit.detail(p, F.cf(0, y + 1.5 + cordLen / 2, z), Vector3.new(0.12, cordLen, 0.12), IRON, M.Metal).Name =
			"PendantCord"
		Kit.cylinder(p, F.cf(0, y + 1.4, z), 0.5, 1.1, BRASS, M.Metal, {
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}).Name =
			"PendantCap"
		local globe = Kit.ball(p, F.cf(0, y, z), 2.6, hex("#FFF3DC"), M.Neon, {
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		globe.Name = "PendantGlobe"
		globe:AddTag("InteriorLight")
		Kit.light(globe, "point", { Color = hex("#FFE7C2"), Range = 46, Brightness = 0.85 })
	end
end

function Atrium.build(parent: Instance, mk: Instance, F: Shell.Frame, rng: Deps.RngT)
	local m = Kit.model(parent, "Atrium")
	structure(m, F)
	upperTrim(m, F)
	vault(m, F, rng)
	floors(m, F, rng)
	entrance(m, mk, F, rng)
	northEnd(m, F)
	court(m, F, rng)
	banners(m, F)
	pendants(m, F)
end

return Atrium
