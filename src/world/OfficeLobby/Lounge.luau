--!strict
-- The lobby's furnished corners:
--   Lounge.lounge(parent)    west: walnut-panelled art wall with two lit canvases, sofas and armchairs on a rug,
--                            side lamps and an abstract sculpture
--   Lounge.vitrine(parent)   north-west: the deal vitrine (lucite tombstones under glass) and a big canvas
--   Lounge.cafe(parent)      south-east by the glass: The Ticker Café (back bar, menu board, counter, stools,
--                            bistro tables) with its hanging sign
--   Lounge.waiting(parent)   north-east: a waiting group and the floor directory board
--   Lounge.plants(parent)    tall planters around the hall
-- Bake-safe.

local Deps = require(script.Parent.Deps)
local Plan = require(script.Parent.Plan)
local Look = require(script.Parent.Look)

local Kit = Deps.Kit
local Geo = Deps.Geo
local Art = Deps.Art
local Text = Deps.Text
local Furniture = Deps.Furniture
local Style = Deps.Style
local Props = Deps.Props
local Rng = Deps.Rng
local GuiCore = Deps.Gui.Core
local GuiArt = Deps.Gui.Art
local hex = Deps.Palette.hex
local M = Enum.Material
local V = Vector3.new

local Lounge = {}

local function rug(parent: Instance, a: Vector3, b: Vector3, style: string, seed: string, base: Color3, accent: Color3)
	local r = Geo.box(parent, a, b, base, M.Fabric)
	r.Name = "Rug"
	r.CastShadow = false
	local gui, W, H = GuiCore.surface(r, Enum.NormalId.Top, { pps = 6, maxDistance = 160, name = "Pattern" })
	GuiArt.rug(gui, W, H, style, Rng.new(seed), base, accent)
	return r
end

-- A canvas in a dark frame with a brass picture light. cf = centre of the canvas, LookVector out of the wall.
local function canvas(parent: Instance, cf: CFrame, w: number, h: number, variant: number, seed: string)
	Kit.detail(parent, cf * CFrame.new(0, 0, 0.12), V(w + 0.7, h + 0.7, 0.2), Look.black, M.Wood).Name = "Frame"
	local art = Kit.detail(parent, cf, V(w, h, 0.12), Color3.new(1, 1, 1), M.Fabric)
	art.Name = "Painting"
	Art.painting(art, Enum.NormalId.Front, variant, Rng.new(seed))
	local lamp =
		Kit.detail(parent, cf * CFrame.new(0, h / 2 + 0.75, -0.55), V(w * 0.55, 0.22, 0.35), Look.brass, M.Metal)
	lamp.Name = "PictureLight"
	lamp:AddTag("InteriorLight")
	Art.glow(lamp, Enum.NormalId.Bottom, Look.warmLight, 2.2)
end

local function sideLamp(parent: Instance, pos: Vector3): Part
	Kit.block(parent, CFrame.new(pos + V(0, 1.1, 0)), V(1.8, 2.2, 1.8), Look.walnut, M.Wood).Name = "SideTable"
	Geo.cyl(parent, CFrame.new(pos + V(0, 2.9, 0)), 1.4, 0.5, Look.brass, M.Metal)
	local shade = Geo.cyl(parent, CFrame.new(pos + V(0, 4.1, 0)), 1.1, 1.5, Look.onyx, M.Fabric)
	shade.Name = "LampShade"
	shade:AddTag("InteriorLight")
	return shade
end

---------------------------------------------------------------------------------------------------
-- West lounge
---------------------------------------------------------------------------------------------------
function Lounge.lounge(parent: Instance): Model
	local L = Plan.lounge
	local m = Kit.model(parent, "Lounge")
	local wx = -Plan.HALF_X
	-- walnut panelling with brass reveals behind the art
	local panel = Geo.box(m, V(wx, 0, L.minZ - 2), V(wx + 0.4, 16, L.maxZ + 2), Look.walnut, M.Wood, true)
	panel.Name = "Panelling"
	for i = 0, 4 do
		local z = L.minZ - 2 + (L.maxZ - L.minZ + 4) / 4 * i
		Geo.box(m, V(wx + 0.4, 0, z - 0.1), V(wx + 0.5, 16, z + 0.1), Look.brass, M.Metal).Name = "Reveal"
	end
	Geo.box(m, V(wx + 0.4, 15.8, L.minZ - 2), V(wx + 0.55, 16.1, L.maxZ + 2), Look.brass, M.Metal).Name = "Reveal"
	canvas(m, CFrame.lookAt(V(wx + 0.75, 8.5, -21), V(wx + 2, 8.5, -21)), 10, 7, 3, "lobby-art-1")
	canvas(m, CFrame.lookAt(V(wx + 0.75, 8.5, -5), V(wx + 2, 8.5, -5)), 10, 7, 6, "lobby-art-2")

	-- the seating group
	local cx, cz = -38, -13
	rug(m, V(cx - 10, 0, cz - 8), V(cx + 8, 0.06, cz + 8), "persian", "lobby-rug", Look.rugBase, Look.rugAccent)
	Furniture.sofa(m, CFrame.lookAt(V(cx, 0, cz - 5.4), V(cx, 0, cz)), 10, Look.navy)
	Furniture.sofa(m, CFrame.lookAt(V(cx, 0, cz + 5.4), V(cx, 0, cz)), 10, Look.navy)
	Furniture.coffeeTable(m, CFrame.new(cx, 0, cz), 6, 3, Look.marble, Look.brass)
	for _, dz in { -2.6, 2.6 } do
		Furniture.guestChair(
			m,
			CFrame.lookAt(V(cx - 8, 0, cz + dz), V(cx, 0, cz + dz * 0.4)),
			Look.leatherTan,
			"Armchair"
		)
	end
	local lit = sideLamp(m, V(cx + 6.6, 0, cz - 5.6))
	Geo.light(lit, "point", { Range = 14, Brightness = 0.6, Color = Look.warmLight })
	sideLamp(m, V(cx - 6.6, 0, cz + 5.6))
	local book =
		Kit.detail(m, CFrame.new(cx - 1.2, 1.75, cz + 0.3) * Kit.rotY(12), V(1.6, 0.3, 1.2), Look.velvet, M.Fabric)
	book.Name = "BookStack"

	-- an abstract sculpture on a plinth at the nave's edge
	local sx, sz = -28, 9
	Kit.block(m, CFrame.new(sx, 1.6, sz), V(3, 3.2, 3), Look.nero, M.Marble).Name = "Plinth"
	if
		not Props.tryBuild(
			"sculpture_abstract",
			m,
			CFrame.new(sx, 3.2, sz) * Kit.rotY(30),
			{ color = Look.brass, seed = "lobby" }
		)
	then
		Geo.cyl(m, CFrame.new(sx, 5.2, sz), 4, 1, Look.brass, M.Metal).Name = "Sculpture"
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- Deal vitrine
---------------------------------------------------------------------------------------------------
function Lounge.vitrine(parent: Instance): Model
	local R = Plan.vitrine
	local m = Kit.model(parent, "Vitrine")
	local x0, x1 = R.minX + 4, R.maxX - 2
	local z0, z1 = 22.4, 25.6
	local base = Geo.box(m, V(x0, 0, z0), V(x1, 3, z1), Look.walnut, M.Wood, true)
	base.Name = "VitrineBase"
	Geo.box(m, V(x0 - 0.1, 3, z0 - 0.1), V(x1 + 0.1, 3.15, z1 + 0.1), Look.brass, M.Metal).Name = "VitrineRim"
	local glass = Geo.glass(m, CFrame.new((x0 + x1) / 2, 4.6, (z0 + z1) / 2), V(x1 - x0, 2.9, z1 - z0), Look.coolLight)
	glass.Name = "VitrineGlass"
	glass.Transparency = 0.82
	local strip = Geo.box(m, V(x0 + 0.3, 5.95, z0 + 0.6), V(x1 - 0.3, 6.05, z1 - 0.6), Look.warmLight, M.Neon)
	strip.Name = "VitrineLight"
	strip:AddTag("InteriorLight")
	local titles = Text.list("lobby_tombstones")
	local n = #titles
	for i, title in titles do
		local x = x0 + (x1 - x0) * (i - 0.5) / n
		local t = Kit.detail(
			m,
			CFrame.new(x, 3.95, (z0 + z1) / 2) * Kit.rotY((i % 3 - 1) * 8),
			V(1.2, 1.6, 0.45),
			hex("#E4F1F6"),
			M.Glass
		)
		t.Name = "Tombstone"
		t.Transparency = 0.3
		Art.tombstone(t, Enum.NormalId.Front, title, "tomb" .. i)
	end
	local plaque = Kit.detail(m, CFrame.new((x0 + x1) / 2, 2.2, z0 - 0.05), V(7, 0.8, 0.08), Look.brass, M.Metal)
	plaque.Name = "VitrinePlaque"
	Kit.sign(plaque, Text.get("lobby_vitrine"), {
		color = Look.nero,
		font = Enum.Font.GothamMedium,
		pixelsPerStud = 50,
		padding = 0.12,
	})
	-- the firm's motto over it and a big canvas on the north wall
	canvas(m, CFrame.lookAt(V((x0 + x1) / 2, 13, Plan.MAX_Z - 0.4), V((x0 + x1) / 2, 13, 0)), 14, 9, 5, "lobby-art-3")
	local motto = Kit.detail(
		m,
		CFrame.lookAt(V((x0 + x1) / 2, 7, Plan.MAX_Z - 0.1), V((x0 + x1) / 2, 7, 0)),
		V(12, 1.1, 0.08),
		Look.walnut,
		M.Wood
	)
	motto.Name = "Motto"
	Kit.sign(motto, Text.get("firm_tagline"), {
		color = Look.brass,
		font = Enum.Font.Garamond,
		pixelsPerStud = 40,
		padding = 0.12,
	})
	return m
end

---------------------------------------------------------------------------------------------------
-- The Ticker Café
---------------------------------------------------------------------------------------------------
function Lounge.cafe(parent: Instance): Model
	local C = Plan.cafe
	local m = Kit.model(parent, "Cafe")
	local rng = Rng.new("lobby-cafe")
	local wx = Plan.HALF_X
	-- back bar on the east wall
	Geo.box(m, V(wx - 2.6, 0, C.minZ + 1), V(wx, 3.1, C.maxZ - 1), Look.walnutDark, M.Wood, true).Name = "BackBar"
	Geo.box(m, V(wx - 2.8, 3.1, C.minZ + 0.9), V(wx, 3.3, C.maxZ - 0.9), Look.marble, M.Marble, true).Name =
		"BackCounter"
	local tiles = Geo.box(m, V(wx - 0.15, 3.3, C.minZ + 1), V(wx, 9.5, C.maxZ - 1), hex("#2F4A3F"), M.CeramicTiles)
	tiles.Name = "Backsplash"
	Art.tiles(tiles, Enum.NormalId.Left, 1, 0.5, hex("#DCD6C8"), { pps = 10, transparency = 0.3 })
	for _, y in { 6, 8 } do
		Geo.box(m, V(wx - 1.2, y, C.minZ + 2), V(wx - 0.15, y + 0.15, C.maxZ - 2), Look.oak, M.Wood).Name = "Shelf"
	end
	local menu = Kit.detail(
		m,
		CFrame.lookAt(V(wx - 0.2, 12.2, (C.minZ + C.maxZ) / 2), V(0, 12.2, (C.minZ + C.maxZ) / 2)),
		V(9, 4.6, 0.1),
		Look.black,
		M.SmoothPlastic
	)
	menu.Name = "MenuBoard"
	Art.board(menu, Enum.NormalId.Front, Text.get("lobby_cafe_menu_title"), Text.get("lobby_cafe_menu"), {
		bg = hex("#141414"),
		accent = Look.brass,
		ink = hex("#EDE6D6"),
		bodyFont = Enum.Font.RobotoMono,
	})
	-- espresso machine and cups on the back counter
	local mz = C.minZ + 6
	Kit.detail(m, CFrame.new(wx - 1.4, 4.2, mz), V(1.8, 1.8, 3.2), Look.steel, M.Metal).Name = "Espresso"
	Kit.detail(m, CFrame.new(wx - 1.4, 5.15, mz), V(1.6, 0.12, 2.8), Look.brass, M.Metal)
	for i = 0, 3 do
		Geo.cyl(
			m,
			CFrame.new(wx - 1.2, 6.4, C.minZ + 10 + i * 1.1),
			0.6,
			0.6,
			if i % 2 == 0 then Look.coolLight else Look.nero,
			M.SmoothPlastic
		)
	end
	-- the front counter with stools
	local fx = 43.6
	local front = Geo.box(m, V(fx - 1.1, 0, C.minZ + 3), V(fx + 1.1, 3.8, C.maxZ - 3), Look.marbleWarm, M.Marble, true)
	front.Name = "Counter"
	Art.veins(front, Enum.NormalId.Left, "cafe-counter", Look.marbleVein, { pps = 12, count = 8 })
	Geo.box(m, V(fx - 1.6, 3.8, C.minZ + 2.8), V(fx + 1.4, 4.0, C.maxZ - 2.8), Look.walnut, M.Wood, true).Name =
		"CounterTop"
	Geo.box(m, V(fx - 1.16, 2.6, C.minZ + 3), V(fx - 1.1, 2.75, C.maxZ - 3), Look.brass, M.Metal).Name = "BrassBand"
	local pastry = Kit.detail(m, CFrame.new(fx, 4.6, C.minZ + 6), V(1.6, 1.2, 3), Look.coolLight, M.Glass)
	pastry.Name = "PastryCase"
	pastry.Transparency = 0.5
	for i = 0, 3 do
		local z = C.minZ + 5 + i * 3.2
		Furniture.stool(m, CFrame.lookAt(V(fx - 3, 0, z), V(fx, 0, z)), Look.leather, Look.brass)
	end
	-- bistro tables by the window
	for i, z in { C.minZ + 3.5, C.minZ + 12 } do
		local tx = 34 + (i - 1) * 1.5
		Geo.cyl(m, CFrame.new(tx, 1.35, z), 2.7, 0.3, Look.black, M.Metal, true).Name = "TableLeg"
		Geo.cyl(m, CFrame.new(tx, 2.8, z), 0.15, 3, Look.marble, M.Marble, true).Name = "TableTop"
		for _, dx in { -2.3, 2.3 } do
			Furniture.guestChair(
				m,
				CFrame.lookAt(V(tx + dx, 0, z + rng:range(-0.4, 0.4)), V(tx, 0, z)),
				if i == 1 then Look.velvet else Look.leatherTan,
				"CafeChair"
			)
		end
	end
	-- the hanging sign
	local sx, sz = fx, (C.minZ + C.maxZ) / 2
	local sign = Kit.signPanel(
		m,
		CFrame.lookAt(V(sx, 12, sz), V(sx - 5, 12, sz)),
		V(9, 1.6, 0.15),
		Text.get("lobby_cafe"),
		Look.walnutDark,
		{ color = Look.brass, font = Enum.Font.Garamond, pixelsPerStud = 40 }
	)
	sign.Name = "CafeSign"
	for _, dz in { -3.5, 3.5 } do
		Geo.pipe(m, V(sx, Plan.HALL_H, sz + dz), V(sx, 12.8, sz + dz), 0.06, Look.black).Name = "SignRod"
	end
	for _, z in { C.minZ + 5, C.minZ + 13 } do
		Furniture.pendant(
			m,
			V(36, Plan.HALL_H, z),
			11,
			Style.ib,
			if z == C.minZ + 5 then { kind = "point", range = 16, brightness = 0.8 } else nil
		)
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- North-east waiting area and the directory
---------------------------------------------------------------------------------------------------
function Lounge.waiting(parent: Instance): Model
	local R = Plan.waiting
	local m = Kit.model(parent, "Waiting")
	local cx, cz = (R.minX + R.maxX) / 2 - 2, (R.minZ + R.maxZ) / 2 + 1
	rug(m, V(cx - 8, 0, cz - 6.5), V(cx + 8, 0.06, cz + 6.5), "modern", "lobby-rug-2", Look.rugBase, Look.rugAccent)
	Furniture.sofa(m, CFrame.lookAt(V(cx, 0, cz + 4.6), V(cx, 0, cz)), 9, Look.leather)
	for _, dx in { -5.2, 5.2 } do
		Furniture.guestChair(m, CFrame.lookAt(V(cx + dx, 0, cz - 2.4), V(cx, 0, cz + 0.6)), Look.velvet, "Armchair")
	end
	Furniture.coffeeTable(m, CFrame.new(cx, 0, cz), 5, 2.6, Look.nero, Look.brass)
	local paper = Kit.detail(
		m,
		CFrame.new(cx + 0.8, 1.66, cz) * Kit.rotY(-15),
		V(1.6, 0.06, 1.2),
		hex("#E9E2CF"),
		M.SmoothPlastic
	)
	paper.Name = "Newspaper"
	GuiArt.newspaper(GuiCore.surface(paper, Enum.NormalId.Top, { pps = 40, maxDistance = 30 }), Rng.new("lobby-paper"))
	-- the floor directory on the east wall
	local wx = Plan.HALF_X
	local dz = 22
	local board =
		Kit.detail(m, CFrame.lookAt(V(wx - 0.2, 7.5, dz), V(0, 7.5, dz)), V(7, 8, 0.15), Look.black, M.SmoothPlastic)
	board.Name = "Directory"
	Art.board(board, Enum.NormalId.Front, Text.get("lobby_directory_title"), Text.get("lobby_directory"), {
		bg = hex("#15171B"),
		accent = Look.brass,
		ink = hex("#E8EEF5"),
		bodyFont = Enum.Font.GothamMedium,
		glow = true,
	})
	Kit.detail(m, CFrame.lookAt(V(wx - 0.1, 7.5, dz), V(0, 7.5, dz)), V(7.5, 8.5, 0.1), Look.brass, M.Metal).Name =
		"DirectoryFrame"
	local hours =
		Kit.detail(m, CFrame.lookAt(V(wx - 0.2, 2.8, dz), V(0, 2.8, dz)), V(4, 0.6, 0.06), Look.brass, M.Metal)
	hours.Name = "HoursPlate"
	Kit.sign(hours, Text.get("lobby_hours"), { color = Look.nero, font = Enum.Font.GothamMedium, pixelsPerStud = 50 })
	return m
end

---------------------------------------------------------------------------------------------------
-- Planters
---------------------------------------------------------------------------------------------------
function Lounge.plants(parent: Instance): Model
	local m = Kit.model(parent, "Planters")
	local spots = {
		V(-48.5, 0, -32.5),
		V(-48.5, 0, 32.5),
		V(-26.5, 0, 32.5),
		V(26.5, 0, 32.5),
		V(48.5, 0, 32.5),
		V(48.5, 0, -11.5),
		V(-8, 0, -32.5),
		V(8, 0, -32.5),
		V(-21, 0, 21),
		V(21, 0, 21),
	}
	for i, p in spots do
		Furniture.plant(m, p, if i <= 6 then "tall" else "floor", Style.ib)
	end
	return m
end

return Lounge
