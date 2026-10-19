--!strict
-- The building core on the south side of every floor (Layout.lobby / Layout.pantry):
--   Core.lobby(parent, style)    elevator lobby: 4 elevators on the core wall, the hanging "Elevators · Lobby" sign
--                                over the OfficeDoor to_lobby trigger (placed by Floor), FirmColor accent panels, the
--                                welcome wall facing the elevators with the CompanyLogo sign and a FirmColor band
--                                (TextLabel CompanyName), world clocks on its back, and the fire alarm pull station
--   Core.pantry(parent, style)   kitchen run, terrazzo island with stools, the communal table (pizza_table spot is
--                                placed by Floor), water cooler, pendants and the planter divider
-- Bake-safe.

local Deps = require(script.Parent.Deps)
local Layout = require(script.Parent.Layout)
local Furniture = require(script.Parent.Furniture)
local Geo = require(script.Parent.Geo)
local Art = require(script.Parent.Art)
local Text = require(script.Parent.Text)
local Style = require(script.Parent.Style)

local Kit = Deps.Kit
local hex = Deps.Palette.hex
local M = Enum.Material
local V = Vector3.new

local Core = {}

local H = Layout.HEIGHT
local CEIL = 12 -- the elevator lobby's dropped ceiling

-- A FirmColor-tagged band with the company name (branded at runtime by OfficeService).
function Core.nameBand(parent: Instance, cf: CFrame, size: Vector3, style: Style.Style, textColor: Color3?): Part
	local band = Kit.detail(parent, cf, size, style.firmPlaceholder, M.SmoothPlastic)
	band.Name = "FirmBand"
	band:AddTag("FirmColor")
	local label = Kit.sign(band, Text.get("company_placeholder"), {
		color = textColor or Color3.fromRGB(246, 240, 226),
		font = Enum.Font.GothamBold,
		pixelsPerStud = 40,
		padding = 0.12,
	})
	label.Name = "CompanyName"
	return band
end

-- A CompanyLogo-tagged panel; OfficeService draws the logo on its Front face.
function Core.logoPanel(parent: Instance, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?): Part
	local p = Kit.block(parent, cf, size, color, mat or M.Marble, { CanCollide = false })
	p.Name = "CompanyLogo"
	p:AddTag("CompanyLogo")
	p:SetAttribute("LogoFace", "Front")
	return p
end

---------------------------------------------------------------------------------------------------
-- Elevator lobby
---------------------------------------------------------------------------------------------------
function Core.lobby(parent: Instance, style: Style.Style): Model
	local L = Layout.lobby
	local m = Kit.model(parent, "ElevatorLobby")
	local x0, x1 = L.minX, L.maxX
	local cz = L.coreZ
	local wz = L.wallZ
	-- core walls
	Geo.box(m, V(x0 - 0.5, 0, cz - 1.5), V(x1 + 0.5, H, cz), style.wall, style.wallMat, true).Name = "CoreWall"
	for _, sx in { -1, 1 } do
		local x = sx * x1
		Geo.box(m, V(x - 0.5, 0, cz), V(x + 0.5, H, wz - 0.6), style.wall, style.wallMat, true).Name = "CoreWall"
	end
	-- finishes: stone floor, walnut cladding, the dropped ceiling and its fascia
	Geo.box(m, V(x0 + 0.5, 0, cz), V(x1 - 0.5, 0.06, wz - 0.6), style.stone, style.stoneMat).Name = "StoneFloor"
	local clad = if style.plain then style.officeWall else style.woodDark
	Geo.box(m, V(x0 + 0.5, 0, cz), V(x1 - 0.5, CEIL, cz + 0.2), clad, M.Wood).Name = "Cladding"
	for _, sx in { -1, 1 } do
		local x = sx * (x1 - 0.5)
		Geo.box(m, V(x, 0, cz), V(x - sx * 0.2, CEIL, wz - 0.6), clad, M.Wood).Name = "Cladding"
		-- FirmColor accent panels flanking the lobby
		local accent = Geo.box(
			m,
			V(x - sx * 0.2, 0.6, -53),
			V(x - sx * 0.3, CEIL - 0.6, -45),
			style.firmPlaceholder,
			M.SmoothPlastic
		)
		accent.Name = "FirmAccentPanel"
		accent:AddTag("FirmColor")
	end
	local ceiling =
		Geo.box(m, V(x0 + 0.5, CEIL, cz), V(x1 - 0.5, CEIL + 0.6, wz - 0.6), style.wall, M.SmoothPlastic, true)
	ceiling.Name = "DropCeiling"
	Geo.box(m, V(x0 - 0.5, CEIL, wz - 0.6), V(x1 + 0.5, H, wz + 0.6), style.wall, style.wallMat, true).Name = "Fascia"
	for i, x in { -15, -5, 5, 15 } do
		local d = Geo.cyl(m, CFrame.new(x, CEIL - 0.02, -49), 0.06, 1.2, style.lamp, M.Neon)
		d:AddTag("InteriorLight")
		if i == 2 or i == 3 then
			Geo.light(d, "point", { Range = 18, Brightness = 0.9, Color = style.lampWarm })
		end
	end

	-- elevators: brass surround, steel leaves, floor indicator
	for _, x in Layout.elevators do
		Kit.detail(
			m,
			CFrame.new(x, 5.3, cz + 0.32),
			V(7.2, 10.6, 0.25),
			if style.plain then style.mullion else style.brass,
			M.Metal
		).Name =
			"Surround"
		local door = Kit.block(m, CFrame.new(x, 5, cz + 0.52), V(6, 10, 0.18), style.duct, M.Metal)
		door.Name = "ElevatorDoor"
		Art.elevatorDoor(door, Enum.NormalId.Back)
		local ind =
			Kit.detail(m, CFrame.new(x, 11.2, cz + 0.3) * Kit.rotY(180), V(2, 0.55, 0.1), style.bezel, M.SmoothPlastic)
		ind.Name = "Indicator"
		Art.indicator(ind, Enum.NormalId.Front, Text.get("elevator_indicator"))
	end
	-- call buttons between the middle cars (the to_lobby trigger sits here)
	local panel = Kit.detail(
		m,
		CFrame.new(0, 4.6, cz + 0.3) * Kit.rotY(180),
		V(0.9, 1.6, 0.12),
		if style.plain then style.stand else style.brass,
		M.Metal
	)
	panel.Name = "CallPanel"
	Art.board(panel, Enum.NormalId.Front, "▲", "▼", {
		bg = hex("#2A2620"),
		accent = hex("#FFE7B0"),
		ink = hex("#FFE7B0"),
		align = Enum.TextXAlignment.Center,
		pps = 40,
	})
	local sign = Kit.signPanel(
		m,
		CFrame.new(0, CEIL - 1.1, cz + 6) * Kit.rotY(180),
		V(13, 1.1, 0.15),
		Text.get("elevators_lobby"),
		style.bezel,
		{
			color = if style.plain then Color3.new(1, 1, 1) else style.brass,
			font = Enum.Font.GothamMedium,
			glow = true,
		}
	)
	sign.Name = "ElevatorSign"
	Geo.pipe(m, V(-5, CEIL, cz + 6), V(-5, CEIL - 0.55, cz + 6), 0.06, style.stand)
	Geo.pipe(m, V(5, CEIL, cz + 6), V(5, CEIL - 0.55, cz + 6), 0.06, style.stand)

	-- the welcome wall: logo facing the elevators, clocks facing the floor
	local wall = Kit.block(
		m,
		CFrame.new(0, CEIL / 2, wz),
		V(28, CEIL, 1.2),
		if style.plain then style.wall else style.stone,
		if style.plain then style.wallMat else style.stoneMat
	)
	wall.Name = "WelcomeWall"
	Core.logoPanel(m, CFrame.new(0, 7.2, wz - 0.7), V(16, 6, 0.2), style.deskTop, M.Marble)
	Core.nameBand(m, CFrame.new(0, 3.2, wz - 0.68), V(16, 1.1, 0.15), style)
	if not style.plain then
		Geo.box(m, V(-14, 0, wz - 0.62), V(14, 0.5, wz - 0.7), style.brass, M.Metal).Name = "Kick"
	end
	local cities = if style.plain then {} else Text.list("clock_cities")
	local hours = { 9, 14, 21, 22 }
	for i = 1, #cities do
		local c = Kit.detail(
			m,
			CFrame.new(-9 + (i - 1) * 6, 8.6, wz + 0.66) * Kit.rotY(180),
			V(2.2, 2.9, 0.1),
			style.bezel,
			M.SmoothPlastic
		)
		c.Name = "Clock"
		Art.clock(c, Enum.NormalId.Front, cities[i], hours[i] or 12, 10)
	end

	-- the fire alarm pull station by the lobby mouth
	local fa = Layout.fireAlarm
	local box = Kit.detail(m, fa, V(0.6, 0.9, 0.2), hex("#C3261F"), M.SmoothPlastic)
	box.Name = "FireAlarm"
	Art.board(box, Enum.NormalId.Front, Text.get("fire_alarm"), Text.get("fire_alarm_pull"), {
		bg = hex("#C3261F"),
		accent = hex("#FFFFFF"),
		ink = hex("#FFFFFF"),
		align = Enum.TextXAlignment.Center,
		font = Enum.Font.GothamBlack,
		bodyFont = Enum.Font.GothamBold,
		pps = 60,
	})
	Kit.detail(m, fa * CFrame.new(0, 1.2, 0), V(0.4, 0.35, 0.25), hex("#F4F4F4"), M.Neon).Name = "Strobe"
	return m
end

---------------------------------------------------------------------------------------------------
-- Pantry
---------------------------------------------------------------------------------------------------
function Core.pantry(parent: Instance, style: Style.Style): Model
	local P = Layout.pantry
	local m = Kit.model(parent, "Pantry")
	local cabinet = if style.plain then style.deskFrame else hex("#2F4A3F")
	local quartz = if style.plain then style.deskTop else hex("#F2F0EB")
	local oak = if style.plain then style.wood else hex("#B48E63")
	Geo.box(m, V(P.minX + 0.2, 0, P.minZ + 0.6), V(P.maxX - 0.5, 0.06, P.maxZ - 0.2), oak, M.WoodPlanks).Name = "Floor"

	-- kitchen run along the core wall
	local wx = P.maxX - 0.5
	Geo.box(m, V(wx - 2.5, 0, -58.5), V(wx, 2.75, -45), cabinet, M.Wood, true).Name = "Cabinets"
	Geo.box(m, V(wx - 2.7, 2.75, -58.7), V(wx, 2.95, -44.8), quartz, M.Marble, true).Name = "Counter"
	Geo.box(m, V(wx - 0.1, 2.95, -58.5), V(wx, 4.7, -45), Color3.fromRGB(240, 240, 236), M.CeramicTiles).Name =
		"Backsplash"
	Geo.box(m, V(wx - 1.5, 6, -58.5), V(wx, 8.4, -45), cabinet, M.Wood).Name = "UpperCabinets"
	Geo.box(m, V(wx - 3, 0, -44.6), V(wx, 7.2, -41.4), style.duct, M.Metal, true).Name = "Fridge"
	Geo.box(m, V(wx - 1.6, 2.95, -52.2), V(wx - 0.1, 4.6, -50.4), style.bezel, M.SmoothPlastic).Name = "CoffeeMachine"
	Geo.box(m, V(wx - 2.1, 2.9, -55.6), V(wx - 0.6, 2.97, -53.6), style.ductJoint, M.Metal).Name = "Sink"
	local menu =
		Kit.detail(m, CFrame.new(wx - 0.06, 10.4, -51.8) * Kit.rotY(90), V(5.4, 3.2, 0.1), style.bezel, M.SmoothPlastic)
	menu.Name = "MenuBoard"
	Art.board(
		menu,
		Enum.NormalId.Front,
		Text.get("pantry_menu_title"),
		Text.get("pantry_menu"),
		{ bodyFont = Enum.Font.GothamMedium }
	)

	-- island with terrazzo faces and three stools
	local ix, iz = -42, -50
	local island = Kit.block(
		m,
		CFrame.new(ix, 1.375, iz),
		V(8, 2.75, 3),
		if style.plain then cabinet else style.endPanel,
		if style.plain then M.Wood else style.endPanelMat
	)
	island.Name = "Island"
	if style.terrazzo then
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
			Art.terrazzo(island, face, Deps.Hash.u32("island", face.Name), { density = 2.5 })
		end
	end
	Kit.block(m, CFrame.new(ix, 2.84, iz), V(8.6, 0.18, 3.6), quartz, M.Marble).Name = "IslandTop"
	for _, dx in { -2.6, 0, 2.6 } do
		Furniture.stool(m, CFrame.lookAt(V(ix + dx, 0, iz + 2.7), V(ix + dx, 0, iz)), style.leather, style.stand)
	end
	for _, dx in { -3, 0, 3 } do
		Furniture.pendant(
			m,
			V(ix + dx, H, iz),
			8.6,
			style,
			if dx == 0 then { kind = "point", range = 16, brightness = 0.9 } else nil
		)
	end

	-- the communal table by the windows (pizza parties)
	local t = Layout.pantryTable
	Kit.block(m, CFrame.new(t.X, t.Y - 0.1, t.Z), V(16, 0.2, 4), oak, M.Wood).Name = "CommunalTable"
	for _, dx in { -6.5, 6.5 } do
		Kit.block(m, CFrame.new(t.X + dx, 1.35, t.Z), V(0.4, 2.7, 3.4), style.stand, M.Metal).Name = "Leg"
	end
	for _, dz in { -3.1, 3.1 } do
		Kit.block(
			m,
			CFrame.new(t.X, 0.85, t.Z + dz),
			V(15, 1.7, 1.4),
			if style.plain then style.upholstery else style.upholsteryAlt,
			M.Fabric
		).Name =
			"Bench"
	end

	-- water cooler, plants and the planter divider toward the open plan
	Kit.block(m, CFrame.new(-88.2, 1.6, -42.6), V(1.4, 3.2, 1.4), style.wall, M.SmoothPlastic).Name = "WaterCooler"
	local bottle = Geo.cyl(m, CFrame.new(-88.2, 4, -42.6), 1.6, 1.1, hex("#9CC9E8"), M.Glass)
	bottle.Transparency = 0.35
	Furniture.plant(m, V(-87.6, 0, -57.6), "tall", style)
	Furniture.plant(m, V(-31.8, 0, -42.4), "floor", style)
	Geo.box(m, V(P.minX + 0.5, 0, P.maxZ - 1.2), V(-62, 2.6, P.maxZ + 0.2), oak, M.Wood, true).Name = "Planter"
	Geo.box(m, V(P.minX + 0.7, 2.6, P.maxZ - 1.0), V(-62.2, 3.7, P.maxZ), style.plant, M.LeafyGrass).Name = "Greenery"
	local sign = Kit.signPanel(
		m,
		CFrame.new(-48, 11, P.maxZ + 0.2) * Kit.rotY(180),
		V(6, 1.1, 0.12),
		Text.get("room_pantry"),
		if style.plain then style.stand else style.woodDark,
		{
			color = if style.plain then Color3.new(1, 1, 1) else style.brass,
			font = Enum.Font.GothamMedium,
		}
	)
	sign.Name = "RoomSign"
	Geo.pipe(m, V(-50.5, H, P.maxZ + 0.2), V(-50.5, 11.55, P.maxZ + 0.2), 0.06, style.stand)
	Geo.pipe(m, V(-45.5, H, P.maxZ + 0.2), V(-45.5, 11.55, P.maxZ + 0.2), 0.06, style.stand)
	return m
end

return Core
