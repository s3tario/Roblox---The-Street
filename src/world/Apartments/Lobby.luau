--!strict
-- The Ashford Residences' lobby: a double-height marble hall with the street doors (door_apartments_exit) and the
-- arrival point (apartments_entry), the concierge desk with npc_concierge behind it under the building's name, the
-- resident mailboxes, a fireside lounge, four marble columns, a grand chandelier and, in the north-east corner, the
-- opening to the stair hall with the residences directory beside it. Bake-safe.
--
--   Lobby.build(parent, mk, F, rng) -> ()

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
local hex = Deps.Palette.hex
local M = Enum.Material

local Lobby = {}

local X0, X1, Z0, Z1, H = Plan.LOBBY_X0, Plan.LOBBY_X1, Plan.LOBBY_Z0, Plan.LOBBY_Z1, Plan.LOBBY_H
local EX = Plan.ENTRY_X

local MARBLE = hex("#ECEAE6")
local VEIN = hex("#B9B4AA")
local WALL = hex("#E4DED2")
local WALNUT = hex("#4A2E1E")
local GOLD = hex("#C9A54C")
local GOLD_BRIGHT = hex("#E3C46F")
local NAVY = hex("#1B2A44")
local CEILING = hex("#F4F1EA")

function Lobby.build(parent: Instance, mk: Instance, F: Shell.Frame, rng: Deps.RngT)
	local m = Kit.model(parent, "Lobby")
	-- shell: walls (the stair hall's wall closes the north side east of x = -96), the ceiling, a marble floor
	Shell.box(m, F, X0 - 1, 0, Z0 - 1, Plan.STAIR_X0 - 1, H, Z0, WALL, M.SmoothPlastic).Name = "Wall"
	Shell.box(m, F, X0 - 1, 0, Z0 - 1, X0, H, Z1 + 1, WALL, M.SmoothPlastic).Name = "Wall"
	Shell.box(m, F, X0 - 1, 0, Z1, X1 + 1, H, Z1 + 1, WALL, M.SmoothPlastic).Name = "Wall"
	Shell.box(m, F, X1, 0, Z0, X1 + 1, H, Z1 + 1, WALL, M.SmoothPlastic).Name = "Wall"
	Shell.box(m, F, X0 - 1, H, Z0 - 1, X1 + 1, H + 1, Z1 + 1, CEILING, M.SmoothPlastic).Name = "Ceiling"
	local floor = Shell.box(m, F, X0, 0, Z0, X1, 0.06, Z1, MARBLE, M.Marble, false)
	floor.Name = "MarbleFloor"
	floor.CastShadow = false
	local fg, FW, FH = Paint.surface(floor, Enum.NormalId.Top, 2, { maxDistance = 0 })
	Paint.grid(fg, FW, FH, 16, VEIN, 0.6)
	Paint.marble(fg, FW, FH, rng, VEIN, 14)
	local inlay = Kit.cylinder(m, F.cf(EX, 0.07, 33), 0.04, 18, MARBLE, M.Marble, { CanCollide = false })
	inlay.Name = "Medallion"
	local ig, IW, IH = Paint.surface(inlay, Enum.NormalId.Right, 6, { maxDistance = 0 })
	Paint.medallion(ig, IW, IH, { hex("#2B3A55"), MARBLE, hex("#7A6A55"), MARBLE, GOLD })

	-- trim: a walnut dado, a gold rail and a deep cornice
	local trim = Kit.model(m, "Trim")
	for _, r in
		{ { X0, Z0, X1, Z0 + 0.2 }, { X0, Z1 - 0.2, X1, Z1 }, { X0, Z0, X0 + 0.2, Z1 }, { X1 - 0.2, Z0, X1, Z1 } }
	do
		Shell.box(trim, F, r[1], 0, r[2], r[3], 4, r[4], WALNUT, M.Wood, false).Name = "Dado"
		Shell.box(trim, F, r[1], H - 1.2, r[2], r[3], H, r[4], hex("#D4CCBC"), M.SmoothPlastic, false).Name = "Cornice"
	end

	-- four marble columns with gold capitals
	for _, c in { { -122, 22 }, { -84, 22 }, { -122, 44 }, { -84, 44 } } do
		Kit.cylinder(m, F.cf(c[1], H / 2, c[2]), H, 3, MARBLE, M.Marble).Name = "Column"
		Kit.cylinder(m, F.cf(c[1], H - 1.6, c[2]), 1.2, 3.8, GOLD, M.Metal, { CanCollide = false }).Name = "Capital"
		Kit.cylinder(m, F.cf(c[1], 0.5, c[2]), 1, 3.8, hex("#2B2D30"), M.Granite).Name = "Plinth"
	end

	-- the street doors and the tall windows either side of them
	Shell.exit(m, mk, "door_apartments_exit", F.cf(EX, 0, Z1, Shell.N), {
		label = Text.get("exit"),
		style = "glass",
		frameColor = GOLD,
		signColor = hex("#14161A"),
		inkColor = GOLD_BRIGHT,
		font = Enum.Font.Garamond,
	})
	Markers.anchor(mk, "apartments_entry", F.cf(EX, 3, Z1 - 8, Shell.N))
	Shell.box(m, F, EX - 5, 0.06, Z1 - 7, EX + 5, 0.12, Z1 - 0.5, NAVY, M.Carpet, false).Name = "EntryMat"
	for _, dx in { -17, 17 } do
		Shell.window(m, F.cf(EX + dx, 11, Z1, Shell.N), 10, 16, rng, {
			view = "street",
			mood = "day",
			frame = GOLD,
			transom = true,
			glass = true,
		})
	end
	for _, dx in { -7.5, 7.5 } do
		Props.build("plant_floor", m, F.cf(EX + dx, 0, Z1 - 2.5, Shell.N), { seed = "apt-door-plant" .. dx })
	end

	-- the concierge desk under the building's name
	local desk = Kit.model(m, "Concierge")
	Props.build(
		"reception_desk",
		desk,
		F.cf(-110, 0, 18, Shell.S),
		{ text = Text.get("apt_concierge"), color = MARBLE, accent = WALNUT, seed = "apt-desk" }
	)
	Markers.npc(mk, "npc_concierge", F.cf(-110, 3, 14.6, Shell.S))
	local panel = Shell.box(desk, F, -124, 1, Z0, -96, 22, Z0 + 0.4, WALNUT, M.Wood, false)
	panel.Name = "NamePanel"
	local ng = Core.surface(panel, Enum.NormalId.Back, { pps = 10, maxDistance = 260 })
	Core.label(
		ng,
		Text.get("apt_name"),
		0.08,
		0.36,
		0.84,
		0.2,
		GOLD_BRIGHT,
		{ font = Enum.Font.Bodoni, align = Enum.TextXAlignment.Center }
	)
	Core.label(
		ng,
		Text.get("apt_sub"),
		0.25,
		0.58,
		0.5,
		0.08,
		GOLD,
		{ font = Enum.Font.GothamMedium, align = Enum.TextXAlignment.Center }
	)
	Core.label(
		ng,
		Text.get("apt_address"),
		0.3,
		0.7,
		0.4,
		0.05,
		hex("#D9D2C3"),
		{ font = Enum.Font.Garamond, italic = true, align = Enum.TextXAlignment.Center }
	)
	Core.frame(ng, 0.2, 0.32, 0.6, 0.006, GOLD)
	Core.frame(ng, 0.2, 0.82, 0.6, 0.006, GOLD)
	Shell.glow(desk, F.cf(-110, 22.2, Z0 + 0.6), Vector3.new(28, 0.2, 0.4), hex("#FFE2B0"))

	-- the stair opening (north-east corner): its sign and the residences directory
	local sx = (Plan.NEAR_X0 + X1) / 2
	Shell.plate(m, F.cf(sx, 11.2, Z0, Shell.S), 9, 1.2, Text.get("apt_stairs_up"), {
		color = NAVY,
		ink = GOLD_BRIGHT,
		font = Enum.Font.GothamMedium,
		pps = 40,
	})
	local dir = Kit.detail(m, F.cf(-82, 6, Z0 + 0.15, Shell.S), Vector3.new(6, 7, 0.3), NAVY, M.SmoothPlastic)
	dir.Name = "Directory"
	local dg = Core.surface(dir, Enum.NormalId.Front, { pps = 40, glow = true, brightness = 1, maxDistance = 160 })
	local dbg = Core.bg(dg, NAVY)
	Paint.gradient(dbg, hex("#24385A"), hex("#121C2C"), 90)
	Core.label(
		dg,
		Text.get("apt_directory_title"),
		0.08,
		0.06,
		0.84,
		0.12,
		GOLD_BRIGHT,
		{ font = Enum.Font.Bodoni, align = Enum.TextXAlignment.Center }
	)
	Core.frame(dg, 0.1, 0.2, 0.8, 0.005, GOLD)
	for i = 1, 3 do
		Core.label(
			dg,
			Text.get("apt_directory_" .. i),
			0.1,
			0.26 + (i - 1) * 0.13,
			0.8,
			0.09,
			hex("#F2E6C4"),
			{ font = Enum.Font.GothamMedium }
		)
	end
	Core.label(
		dg,
		Text.get("apt_directory_hint"),
		0.1,
		0.7,
		0.8,
		0.2,
		hex("#B9C8D8"),
		{ font = Enum.Font.GothamMedium }
	)
	dir:AddTag("InteriorLight")

	-- resident mailboxes on the west wall
	local mail = Shell.box(m, F, X0, 1.5, 17, X0 + 0.4, 9.5, 31, GOLD, M.Metal, false)
	mail.Name = "Mailboxes"
	local mg, MW, MH = Paint.surface(mail, Enum.NormalId.Right, 12, { maxDistance = 120 })
	Core.bg(mg, hex("#8E7234"))
	local cols, rows = 12, 6
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local f = Core.px(mg, MW * c / cols + 3, MH * r / rows + 3, MW / cols - 6, MH / rows - 6, GOLD, 0)
			Core.stroke(f, hex("#5E4A1E"), 1.5)
			Core.dot(mg, MW * (c + 0.75) / cols, MH * (r + 0.5) / rows, 4, hex("#3A2E14"))
		end
	end
	Shell.plate(m, F.cf(X0, 10.6, 24, Shell.E), 7, 1, Text.get("apt_mail"), {
		color = NAVY,
		ink = GOLD_BRIGHT,
		font = Enum.Font.GothamMedium,
		pps = 40,
	})

	-- the fireside lounge (south-west)
	local lounge = Kit.model(m, "Lounge")
	Props.build("fireplace", lounge, F.cf(X0, 0, 44, Shell.E), { seed = "apt-fire" })
	local mirror =
		Kit.detail(lounge, F.cf(X0 + 0.15, 11, 44, Shell.E), Vector3.new(6.5, 7, 0.15), hex("#C9D6DC"), M.Glass)
	mirror.Name = "OvermantelMirror"
	mirror.Reflectance = 0.4
	Kit.detail(lounge, F.cf(X0 + 0.08, 11, 44, Shell.E), Vector3.new(7.3, 7.8, 0.12), GOLD, M.Metal).Name =
		"MirrorFrame"
	Props.build("rug_persian", lounge, F.cf(-131, 0.07, 44, 90), { seed = "apt-rug" })
	Props.build("leather_sofa", lounge, F.cf(-131, 0.06, 38, Shell.S), { color = hex("#3B2A20"), seed = "apt-sofa1" })
	Props.build("leather_sofa", lounge, F.cf(-131, 0.06, 50, Shell.N), { color = hex("#3B2A20"), seed = "apt-sofa2" })
	Props.build("armchair", lounge, F.cf(-125.6, 0.06, 44, Shell.W), { color = hex("#6B7480"), seed = "apt-arm" })
	Props.build("coffee_table", lounge, F.cf(-131, 0.06, 44, 90), { seed = "apt-coffee" })

	-- a quiet corner by the east wall
	local corner = Kit.model(m, "ReadingCorner")
	Furniture.armchair(corner, F.cf(-72, 0.06, 40, 225), hex("#6B7480"), { accent = WALNUT })
	Furniture.armchair(corner, F.cf(-72, 0.06, 48, 315), hex("#6B7480"), { accent = WALNUT })
	Furniture.roundTable(corner, F.cf(-70, 0.06, 44), 2.4, 2.2, MARBLE, GOLD)
	Props.build("lamp_floor", corner, F.cf(-68.5, 0.06, 37), { lit = false, seed = "apt-lamp" })
	for i, z in { 22, 34 } do
		Props.build("wall_art", corner, F.cf(X1, 7, z, Shell.W), {
			variant = rng:int(1, 8),
			width = 7,
			height = 5,
			color = GOLD,
			seed = "apt-art" .. i,
		})
	end
	Furniture.plant(corner, F.cf(-77, 0.06, 12.5), 1.2, rng)
	Furniture.plant(corner, F.cf(X0 + 2.5, 0.06, 13), 1.2, rng)

	-- the grand chandelier and recessed lights
	Props.build("chandelier", m, F.cf(EX, H - 9, 33), { arms = 8, drop = 9, seed = "apt-chandelier" })
	for _, c in { { -122, 33 }, { -84, 33 }, { EX, 16 }, { EX, 50 } } do
		Shell.downlight(
			m,
			F.cf(c[1], H - 0.06, c[2]),
			1.6,
			if c[2] == 33 then { range = 30, brightness = 0.8 } else nil
		)
	end
end

return Lobby
