--!strict
-- Private offices and the boss's corner office (contracts §11; World.floorSlots).
--
-- Offices.private(parent, index, cf, style) -> Model "Office_N"   (attribute OfficeSlot = N, tag "OfficeSlot")
--   cf = centre of the office floor, LookVector = out through the glass front. Inside:
--     Floor (ThemeFloor, PrimaryPart), side walls (ThemeWall), glass front with a 6.5-stud doorway,
--     exec desk (Top = work_desk), dual monitor (terminal), exec chair, guest chair, linear pendant,
--     Bookshelf model with 24 plaque DecorSlots (SlotId plaque_1..24, top-left first),
--     6 more DecorSlots (2 desk_item, wall_art, plant, floor, rug), a Nameplate on the corridor side and a
--     housing_panel (Context "office") by the door.
-- Offices.boss(parent, style) -> Model "BossOffice"
--   OfficeAnchor boss_chair (over the boss's chair, so the boss NPC sits), OfficeAnchor review_spot (in front of the
--   desk) and the boss_review interact on the desk top.

local Deps = require(script.Parent.Deps)
local Layout = require(script.Parent.Layout)
local Markers = require(script.Parent.Markers)
local Furniture = require(script.Parent.Furniture)
local Geo = require(script.Parent.Geo)
local Art = require(script.Parent.Art)
local Text = require(script.Parent.Text)
local Style = require(script.Parent.Style)

local Kit = Deps.Kit
local Rng = Deps.Rng
local M = Enum.Material

local Offices = {}

local H = Layout.HEIGHT

local function glass(parent: Instance, cf: CFrame, size: Vector3, style: Style.Style): Part
	return Geo.glass(parent, cf, size, style.partitionGlass)
end

local frost = Geo.frost

---------------------------------------------------------------------------------------------------
-- Private office
---------------------------------------------------------------------------------------------------
local PLAQUE_ROWS = { 6.12, 4.32, 2.52, 0.6 } -- shelf surfaces, top row first
local PLAQUE_COLS = 6

function Offices.private(parent: Instance, index: number, cf: CFrame, style: Style.Style): Model
	local rng = Rng.new(Deps.Hash.u32(style.id, "office", index))
	local m = Kit.model(parent, "Office_" .. index)
	m:SetAttribute("OfficeSlot", index)
	m:AddTag("OfficeSlot")
	local hw, hd = Layout.OFFICE_W / 2, Layout.OFFICE_D / 2
	local at = function(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	local floor = Kit.block(
		m,
		at(0, 0.05, 0),
		Vector3.new(Layout.OFFICE_W - 1, 0.1, Layout.OFFICE_D - 0.4),
		style.officeFloor,
		style.officeFloorMat
	)
	floor.Name = "Floor"
	floor:AddTag("ThemeFloor")
	m.PrimaryPart = floor
	for _, sx in { -1, 1 } do
		local wall = Kit.block(
			m,
			at(sx * (hw - 0.25), H / 2, 0),
			Vector3.new(0.5, H, Layout.OFFICE_D),
			style.officeWall,
			style.officeWallMat
		)
		wall.Name = "Wall"
		wall:AddTag("ThemeWall")
	end

	-- glass front: doorway x -8.5..-2 (6.5 wide, 9.6 tall), main pane to the right
	local fz = -hd
	local doorL, doorR, doorTop = -hw + 0.5, -2, 9.6
	local paneW = (hw - 0.5) - doorR
	glass(m, at(doorR + paneW / 2, H / 2, fz), Vector3.new(paneW, H, 0.2), style)
	glass(m, at((doorL + doorR) / 2, (doorTop + H) / 2, fz), Vector3.new(doorR - doorL, H - doorTop, 0.2), style)
	Kit.detail(m, at(doorR, H / 2, fz), Vector3.new(0.25, H, 0.35), style.mullion, M.Metal)
	Kit.detail(m, at((doorL + doorR) / 2, doorTop, fz), Vector3.new(doorR - doorL, 0.25, 0.35), style.mullion, M.Metal)
	frost(m, at(doorR + paneW / 2, 4.6, fz), Vector3.new(paneW, 0.7, 0.24))

	-- nameplate on the corridor side next to the door; customize panel inside by the door
	Markers.nameplate(m, at(-0.85, 5.6, fz - 0.16), Vector3.new(1.5, 0.5, 0.05), Text.get("office_nameplate"), {
		color = if style.plain then style.stand else style.brass,
		ink = if style.plain then Color3.fromRGB(236, 236, 236) else Color3.fromRGB(28, 22, 16),
	})
	local panel = Kit.detail(
		m,
		at(-hw + 0.56, 4.4, fz + 2.4) * Kit.rotY(-90),
		Vector3.new(0.65, 0.9, 0.1),
		style.stand,
		M.SmoothPlastic
	)
	panel.Name = "CustomizePanel"
	Art.glow(panel, Enum.NormalId.Front, Color3.fromRGB(38, 70, 112), 1.2)
	Kit.interact(panel, "housing_panel", { Context = "office" })

	-- desk, monitor, chairs
	local dz = 1.2
	local top = Kit.block(
		m,
		at(0, 2.68, dz),
		Vector3.new(7.6, 0.24, 3.4),
		if style.plain then style.deskTop else style.wood,
		if style.plain then M.SmoothPlastic else M.Wood
	)
	top.Name = "Top"
	Kit.interact(top, "work_desk")
	for _, sx in { -1, 1 } do
		Kit.block(m, at(sx * 3.5, 1.28, dz), Vector3.new(0.3, 2.56, 3.2), style.stand, M.Metal).Name = "Leg"
	end
	Kit.detail(
		m,
		at(0, 1.6, dz - 1.45),
		Vector3.new(6.8, 1.7, 0.12),
		if style.plain then style.deskFrame else style.woodDark,
		M.Wood
	)
	local mon = Kit.detail(
		m,
		cf * CFrame.lookAt(Vector3.new(0, 4.1, dz - 0.9), Vector3.new(0, 4.1, dz + 1)),
		Vector3.new(2 * 1.55, 0.95, 0.1),
		style.bezel,
		M.SmoothPlastic
	)
	mon.Name = "TerminalScreens"
	mon.CanQuery = true
	Art.monitors(mon, 2, { "terminal", rng:pick(Art.screenKinds) }, rng)
	Kit.interact(mon, "terminal")
	Kit.detail(m, at(0, 3.25, dz - 1.02), Vector3.new(0.2, 0.9, 0.14), style.stand, M.Metal)
	local pad = Kit.detail(m, at(0, 2.84, dz + 0.75), Vector3.new(3.6, 0.08, 1.15), style.keyboard, M.Leather)
	pad.Name = "DeskPad"
	Art.keyboard(pad)
	Furniture.execChair(m, at(0, 0.1, dz + 3.2) * Kit.rotY(rng:range(-10, 10)), {
		mesh = style.leather,
		seat = style.leather,
		base = style.chairBase,
	})
	Furniture.guestChair(
		m,
		at(rng:range(-0.6, 0.6), 0.1, dz - 3.6) * Kit.rotY(180 + rng:range(-12, 12)),
		style.upholstery
	)

	-- bookshelf on the right wall with 24 plaque slots
	local shelf = Kit.model(m, "Bookshelf")
	local sx0 = hw - 0.5 - 0.65 -- shelf centre (x); 1.3 deep against the wall
	local wood = if style.plain then style.wood else style.woodDark
	for _, sz in { -1, 1 } do
		Kit.block(shelf, at(sx0, 4, sz * 3.7), Vector3.new(1.3, 8, 0.2), wood, M.Wood)
	end
	Kit.detail(shelf, at(sx0, 7.9, 0), Vector3.new(1.3, 0.2, 7.6), wood, M.Wood)
	Kit.block(shelf, at(sx0, 0.3, 0), Vector3.new(1.3, 0.6, 7.2), wood, M.Wood)
	for i = 1, #PLAQUE_ROWS - 1 do -- boards under the upper rows; the plinth carries the bottom row
		Kit.detail(shelf, at(sx0, PLAQUE_ROWS[i] - 0.06, 0), Vector3.new(1.3, 0.12, 7.2), wood, M.Wood)
	end
	local n = 0
	for _, y in PLAQUE_ROWS do
		for c = 1, PLAQUE_COLS do
			n += 1
			Markers.surfaceSlot(
				shelf,
				"plaque",
				at(sx0 - 0.05, y, -3.0 + (c - 1) * 1.2) * Kit.rotY(90),
				Vector3.new(0.9, 0.2, 0.42),
				{ id = "plaque_" .. n, index = n }
			)
		end
	end

	-- decor slots
	Markers.surfaceSlot(
		m,
		"desk_item",
		at(-2.8, 2.8, dz + 0.4),
		Vector3.new(1.2, 0.2, 1.2),
		{ id = "desk_left", index = 1, maxWidth = 1.6, maxDepth = 1.4 }
	)
	Markers.surfaceSlot(
		m,
		"desk_item",
		at(2.8, 2.8, dz + 0.4),
		Vector3.new(1.2, 0.2, 1.2),
		{ id = "desk_right", index = 2, maxWidth = 1.6, maxDepth = 1.4 }
	)
	Markers.wallSlot(
		m,
		"wall_art",
		at(-hw + 0.5, 4.6, 1) * Kit.rotY(-90),
		Vector3.new(6, 4, 0.3),
		{ id = "wall_art", maxWidth = 6.5, maxHeight = 4.5 }
	)
	Markers.surfaceSlot(m, "plant", at(hw - 2.4, 0.1, -hd + 2.4), Vector3.new(2.4, 0.2, 2.4), { id = "plant" })
	Markers.surfaceSlot(m, "floor", at(-hw + 2.4, 0.1, hd - 2.6), Vector3.new(2.4, 0.2, 2.4), { id = "corner" })
	Markers.surfaceSlot(m, "rug", at(0, 0.1, -1.6), Vector3.new(9, 0.1, 6), { id = "rug", maxWidth = 10, maxDepth = 7 })

	Furniture.linear(m, at(0, 11, dz), 6, H, style, { kind = "surface", range = 14, brightness = 0.9, angle = 120 })
	return m
end

---------------------------------------------------------------------------------------------------
-- Boss corner office
---------------------------------------------------------------------------------------------------
function Offices.boss(parent: Instance, style: Style.Style): Model
	local b = Layout.boss
	local rng = Rng.new(Deps.Hash.u32(style.id, "boss"))
	local m = Kit.model(parent, "BossOffice")
	local cx, cz = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
	local floor = Geo.box(
		m,
		Vector3.new(b.minX + 0.5, 0, b.minZ + 0.2),
		Vector3.new(b.maxX - 0.5, 0.1, b.maxZ - 0.5),
		if style.plain then style.officeFloor else style.wood,
		if style.plain then style.officeFloorMat else M.WoodPlanks,
		true
	)
	floor.Name = "Floor"
	m.PrimaryPart = floor

	-- west wall with the doorway at the end of the corridor (office 8's wall closes the rest)
	local wx0, wx1 = b.minX, b.minX + 0.5
	Geo.box(m, Vector3.new(wx0, 0, b.minZ), Vector3.new(wx1, H, b.doorZ0), style.officeWall, style.officeWallMat, true)
	Geo.box(
		m,
		Vector3.new(wx0, 0, b.doorZ1),
		Vector3.new(wx1, H, Layout.OFFICE_FRONT_Z),
		style.officeWall,
		style.officeWallMat,
		true
	)
	Geo.box(
		m,
		Vector3.new(wx0, 10, b.doorZ0),
		Vector3.new(wx1, H, b.doorZ1),
		style.officeWall,
		style.officeWallMat,
		true
	)
	-- panelling over office 8's wall (so office themes never repaint the boss's side)
	Geo.box(
		m,
		Vector3.new(wx1, 0, Layout.OFFICE_FRONT_Z),
		Vector3.new(wx1 + 0.2, H, b.maxZ - 0.5),
		if style.plain then style.officeWall else style.woodDark,
		M.Wood
	)
	-- glass front facing the floor
	glass(m, CFrame.new((wx1 + b.maxX) / 2, H / 2, b.minZ), Vector3.new(b.maxX - wx1, H, 0.2), style)
	frost(m, CFrame.new((wx1 + b.maxX) / 2, 4.6, b.minZ), Vector3.new(b.maxX - wx1, 0.7, 0.24))

	-- the desk: the boss sits on the east side facing the door, the player stands on the west side
	local dx, dz = 76, 44
	local top = Kit.block(
		m,
		CFrame.new(dx, 2.75, dz),
		Vector3.new(4.6, 0.3, 10),
		if style.plain then style.deskTop else style.wood,
		if style.plain then M.SmoothPlastic else M.Wood
	)
	top.Name = "Top"
	Kit.interact(top, "boss_review")
	for _, sz in { -1, 1 } do
		Kit.block(m, CFrame.new(dx + 0.2, 1.3, dz + sz * 3.9), Vector3.new(4, 2.6, 1.8), style.woodDark, M.Wood).Name =
			"Pedestal"
	end
	Kit.detail(m, CFrame.new(dx - 2.05, 1.5, dz), Vector3.new(0.2, 2.2, 6.2), style.woodDark, M.Wood)
	if not style.plain then
		Kit.detail(m, CFrame.new(dx - 2.32, 2.75, dz), Vector3.new(0.06, 0.12, 10), style.brass, M.Metal)
		-- deal toys and a brass lamp
		for i = 1, 3 do
			Kit.detail(
				m,
				CFrame.new(dx + 0.6 - i * 0.55, 3.35 + (i % 2) * 0.1, dz + 3.4),
				Vector3.new(0.4, 0.9 + (i % 2) * 0.2, 0.3),
				Color3.fromRGB(224, 236, 240),
				M.Glass
			).Transparency =
				0.35
		end
		Geo.cyl(m, CFrame.new(dx + 1.2, 3.6, dz - 4.1), 1.4, 0.12, style.brass, M.Metal)
		Geo.cyl(m, CFrame.new(dx + 1.2, 4.45, dz - 4.1), 0.5, 0.9, Color3.fromRGB(28, 60, 44), M.SmoothPlastic)
	end
	local mon = Kit.detail(
		m,
		CFrame.lookAt(Vector3.new(dx + 0.9, 4.15, dz - 2.6), Vector3.new(dx + 2.2, 4.15, dz - 2.1)),
		Vector3.new(3.1, 0.95, 0.1),
		style.bezel,
		M.SmoothPlastic
	)
	mon.Name = "Screens"
	Art.monitors(mon, 2, { "deck", "comps" }, rng)
	Furniture.execChair(m, CFrame.lookAt(Vector3.new(dx + 4.2, 0.1, dz), Vector3.new(dx + 3.2, 0.1, dz)), {
		mesh = style.leather,
		seat = style.leather,
		base = style.chairBase,
		name = "BossChair",
	})
	Markers.anchor(m, "boss_chair", CFrame.lookAt(Vector3.new(dx + 4.2, 3, dz), Vector3.new(dx + 3.2, 3, dz)))
	Markers.anchor(m, "review_spot", CFrame.lookAt(Vector3.new(dx - 5.4, 3, dz), Vector3.new(dx - 4.4, 3, dz)))
	for _, sz in { -1, 1 } do
		Furniture.guestChair(
			m,
			CFrame.lookAt(Vector3.new(dx - 4.6, 0.1, dz + sz * 3.6), Vector3.new(dx - 3.6, 0.1, dz + sz * 3.2)),
			if style.plain then style.upholstery else style.leather
		)
	end

	-- bookcase and art on the west panelling
	local bx = wx1 + 0.2 + 0.7
	local wood = if style.plain then style.wood else style.woodDark
	for _, y in { 0.3, 2.6, 4.9, 7.2, 9.5 } do
		Kit.block(m, CFrame.new(bx, y, 53.5), Vector3.new(1.4, if y < 1 then 0.6 else 0.16, 11), wood, M.Wood)
	end
	for _, sz in { -1, 1 } do
		Kit.detail(m, CFrame.new(bx, 4.9, 53.5 + sz * 5.6), Vector3.new(1.4, 9.8, 0.2), wood, M.Wood)
	end
	local bookColors =
		{ style.upholstery, style.leather, style.pipeRed, style.upholsteryAlt, style.firmPlaceholder, style.brass }
	for i, y in { 0.6, 2.68, 4.98, 7.28 } do
		for j = 1, if i % 2 == 0 then 1 else 2 do
			local len = rng:range(2.6, 3.8)
			local z = 53.5 + (if j == 1 then -2.6 else 2.4) + rng:range(-0.6, 0.6)
			Kit.detail(
				m,
				CFrame.new(bx, y + 0.75, z),
				Vector3.new(1.0, 1.5, len),
				bookColors[(i + j) % #bookColors + 1],
				M.SmoothPlastic
			)
		end
	end
	local art = Kit.detail(
		m,
		CFrame.new(wx1 + 0.3, 6.5, 43) * Kit.rotY(-90),
		Vector3.new(7.5, 5, 0.2),
		Color3.new(1, 1, 1),
		M.Fabric
	)
	art.Name = "Painting"
	Art.painting(art, Enum.NormalId.Front, rng:int(1, 8), rng)

	-- seating by the front glass
	Furniture.sofa(
		m,
		CFrame.lookAt(Vector3.new(80, 0.1, 28.8), Vector3.new(80, 0.1, 30)),
		9,
		if style.plain then style.upholstery else style.upholsteryAlt
	)
	Furniture.coffeeTable(m, CFrame.new(80, 0.1, 32.6), 4.5, 2.6, style.stone, style.stand)
	Furniture.guestChair(
		m,
		CFrame.lookAt(Vector3.new(73.6, 0.1, 32.6), Vector3.new(75, 0.1, 32.6)),
		style.upholstery,
		"Armchair"
	)
	Furniture.plant(m, Vector3.new(87.4, 0.1, 57.2), "tall", style)
	Furniture.plant(m, Vector3.new(57.6, 0.1, 27.4), "tall", style)
	if not style.plain then
		Geo.box(m, Vector3.new(68, 0.1, 37.5), Vector3.new(84, 0.16, 50.5), style.upholstery, M.Fabric).Name = "Rug"
	end

	Furniture.linear(m, CFrame.new(dx, 11.5, dz), 7, H, style, { kind = "surface", range = 16, brightness = 1 })
	Furniture.pendant(m, Vector3.new(80, H, 32.6), 9.5, style, { kind = "point", range = 14, brightness = 0.7 })

	-- the sign over the door, on the corridor side
	local sign = Kit.signPanel(
		m,
		CFrame.new(wx0 - 0.06, 11.2, (b.doorZ0 + b.doorZ1) / 2) * Kit.rotY(90),
		Vector3.new(7, 1.1, 0.1),
		Text.get("room_boss"),
		if style.plain then style.stand else style.woodDark,
		{
			color = if style.plain then Color3.new(1, 1, 1) else style.brass,
			font = Enum.Font.GothamMedium,
		}
	)
	sign.Name = "RoomSign"
	return m
end

return Offices
