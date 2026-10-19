--!strict
-- The rooms around the open plan (Layout): the boardroom (project_desk interact on its table), two glass huddle
-- rooms, the lounge by the east windows (with the hidden briefcase corner), the rival's standing desk and the
-- open-plan dressing (aisle planters, print station). Bake-safe.
--
--   Rooms.conference(parent, style)   Rooms.huddles(parent, style)   Rooms.lounge(parent, style)
--   Rooms.rivalDesk(parent, style)    Rooms.openPlan(parent, style)

local Deps = require(script.Parent.Deps)
local Layout = require(script.Parent.Layout)
local Furniture = require(script.Parent.Furniture)
local Geo = require(script.Parent.Geo)
local Art = require(script.Parent.Art)
local Text = require(script.Parent.Text)
local Style = require(script.Parent.Style)

local Kit = Deps.Kit
local Rng = Deps.Rng
local M = Enum.Material
local V = Vector3.new

local Rooms = {}

local H = Layout.HEIGHT
local DOOR_TOP = 9.6

local function roomSign(parent: Instance, cf: CFrame, text: string, style: Style.Style)
	local sign =
		Kit.signPanel(parent, cf, V(3.4, 0.7, 0.06), text, if style.plain then style.stand else style.woodDark, {
			color = if style.plain then Color3.new(1, 1, 1) else style.brass,
			font = Enum.Font.GothamMedium,
			pixelsPerStud = 60,
		})
	sign.Name = "RoomSign"
end

---------------------------------------------------------------------------------------------------
-- Boardroom
---------------------------------------------------------------------------------------------------
function Rooms.conference(parent: Instance, style: Style.Style): Model
	local c = Layout.conference
	local rng = Rng.new(Deps.Hash.u32(style.id, "boardroom"))
	local m = Kit.model(parent, "Boardroom")
	local gx = c.maxX
	Geo.box(m, V(c.minX, 0, c.minZ - 0.5), V(gx + 0.15, H, c.minZ), style.wall, style.wallMat, true)
	Geo.box(m, V(c.minX, 0, c.maxZ), V(gx + 0.15, H, c.maxZ + 0.5), style.wall, style.wallMat, true)
	-- glass front with the door
	local g = style.partitionGlass
	Geo.glass(m, CFrame.new(gx, H / 2, (c.minZ + c.doorZ0) / 2), V(0.2, H, c.doorZ0 - c.minZ), g)
	Geo.glass(m, CFrame.new(gx, H / 2, (c.doorZ1 + c.maxZ) / 2), V(0.2, H, c.maxZ - c.doorZ1), g)
	Geo.glass(
		m,
		CFrame.new(gx, (DOOR_TOP + H) / 2, (c.doorZ0 + c.doorZ1) / 2),
		V(0.2, H - DOOR_TOP, c.doorZ1 - c.doorZ0),
		g
	)
	for _, z in { c.doorZ0, c.doorZ1 } do
		Kit.detail(m, CFrame.new(gx, H / 2, z), V(0.35, H, 0.25), style.mullion, M.Metal)
	end
	Geo.frost(m, CFrame.new(gx, 4.6, (c.minZ + c.doorZ0) / 2), V(0.24, 0.7, c.doorZ0 - c.minZ))
	Geo.frost(m, CFrame.new(gx, 4.6, (c.doorZ1 + c.maxZ) / 2), V(0.24, 0.7, c.maxZ - c.doorZ1))
	Geo.box(m, V(c.minX + 0.4, 0, c.minZ), V(gx - 0.1, 0.05, c.maxZ), style.walkway, style.carpetMat)

	-- the table: project_desk on its top
	local tx, tz = (c.minX + gx) / 2, (c.minZ + c.maxZ) / 2
	local top = Kit.block(
		m,
		CFrame.new(tx, 2.775, tz),
		V(7, 0.25, 24),
		if style.plain then style.deskTop else style.wood,
		if style.plain then M.SmoothPlastic else M.Wood
	)
	top.Name = "Top"
	Kit.interact(top, "project_desk")
	for _, dz in { -7, 7 } do
		Kit.block(m, CFrame.new(tx, 1.33, tz + dz), V(3, 2.65, 4), style.stand, M.Metal).Name = "Pedestal"
	end
	for _, side in { -1, 1 } do
		for _, dz in { -8, 0, 8 } do
			local pos = V(tx + side * 5, 0, tz + dz + rng:range(-0.3, 0.3))
			Furniture.guestChair(
				m,
				CFrame.lookAt(pos, V(tx, 0, pos.Z)) * Kit.rotY(rng:range(-8, 8)),
				if style.plain then style.upholstery else style.leather,
				"BoardChair"
			)
		end
	end

	-- the screen and credenza on the north wall, the deal board on the south wall
	local tv = Kit.detail(m, CFrame.new(tx, 7.6, c.maxZ - 0.2), V(10, 5.6, 0.25), style.bezel, M.SmoothPlastic)
	tv.Name = "Screen"
	Art.monitors(tv, 1, { "deck" }, rng, { pps = 30, bezel = 0.15, maxDistance = 120 })
	Kit.block(m, CFrame.new(tx, 1.2, c.maxZ - 1), V(12, 2.4, 1.6), style.woodDark, M.Wood).Name = "Credenza"
	local board =
		Kit.detail(m, CFrame.new(tx, 6.4, c.minZ + 0.1) * Kit.rotY(180), V(12, 5, 0.15), style.bezel, M.SmoothPlastic)
	board.Name = "DealBoard"
	Art.board(board, Enum.NormalId.Front, Text.get("deal_board_title"), Text.get("deal_board_lines"))

	Furniture.linear(
		m,
		CFrame.new(tx, 11, tz - 6) * Kit.rotY(90),
		9,
		H,
		style,
		{ kind = "surface", range = 16, brightness = 1 }
	)
	Furniture.linear(m, CFrame.new(tx, 11, tz + 6) * Kit.rotY(90), 9, H, style)
	Furniture.plant(m, V(c.minX + 2.6, 0, c.maxZ - 2.8), "tall", style)
	roomSign(m, CFrame.new(gx + 0.16, 6.4, c.doorZ1 + 2.2) * Kit.rotY(-90), Text.get("room_boardroom"), style)
	return m
end

---------------------------------------------------------------------------------------------------
-- Huddle rooms (south-east)
---------------------------------------------------------------------------------------------------
function Rooms.huddles(parent: Instance, style: Style.Style): Model
	local m = Kit.model(parent, "Huddles")
	local g = style.partitionGlass
	for i, h in Layout.huddles do
		local rng = Rng.new(Deps.Hash.u32(style.id, "huddle", i))
		local r = Kit.model(m, "Huddle_" .. i)
		local fz = h.maxZ
		Geo.glass(r, CFrame.new((h.minX + h.doorX0) / 2, H / 2, fz), V(h.doorX0 - h.minX, H, 0.2), g)
		Geo.glass(r, CFrame.new((h.doorX1 + h.maxX) / 2, H / 2, fz), V(h.maxX - h.doorX1, H, 0.2), g)
		Geo.glass(
			r,
			CFrame.new((h.doorX0 + h.doorX1) / 2, (DOOR_TOP + H) / 2, fz),
			V(h.doorX1 - h.doorX0, H - DOOR_TOP, 0.2),
			g
		)
		for _, x in { h.doorX0, h.doorX1 } do
			Kit.detail(r, CFrame.new(x, H / 2, fz), V(0.25, H, 0.35), style.mullion, M.Metal)
		end
		Geo.frost(r, CFrame.new((h.doorX1 + h.maxX) / 2, 4.6, fz), V(h.maxX - h.doorX1, 0.7, 0.24))
		if i < #Layout.huddles then
			Geo.box(r, V(h.maxX - 0.25, 0, h.minZ), V(h.maxX + 0.25, H, fz), style.wall, style.wallMat, true)
		end
		local cx, cz = (h.minX + h.maxX) / 2 + 2, (h.minZ + fz) / 2
		Kit.block(
			r,
			CFrame.new(cx, 2.8, cz),
			V(10, 0.2, 4.4),
			if style.plain then style.deskTop else style.stone,
			if style.plain then M.SmoothPlastic else style.stoneMat
		).Name =
			"Table"
		Kit.block(r, CFrame.new(cx, 1.35, cz), V(3, 2.7, 1.6), style.stand, M.Metal)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local pos = V(cx + sx * 2.6, 0, cz + sz * 3.7)
				Furniture.guestChair(
					r,
					CFrame.lookAt(pos, V(pos.X, 0, cz)) * Kit.rotY(rng:range(-10, 10)),
					style.upholstery,
					"HuddleChair"
				)
			end
		end
		local tv = Kit.detail(
			r,
			CFrame.new(h.minX + 0.65, 7, cz) * Kit.rotY(-90),
			V(8, 4.5, 0.2),
			style.bezel,
			M.SmoothPlastic
		)
		tv.Name = "Screen"
		Art.monitors(tv, 1, { if i == 1 then "deck" else "chart" }, rng, { pps = 30, bezel = 0.12, maxDistance = 110 })
		Furniture.linear(r, CFrame.new(cx, 11, cz), 8, H, style, { kind = "surface", range = 14, brightness = 0.9 })
		roomSign(
			r,
			CFrame.new((h.minX + h.doorX0) / 2, 6.4, fz + 0.15) * Kit.rotY(180),
			Text.get("room_huddle_" .. i),
			style
		)
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- Lounge by the east windows
---------------------------------------------------------------------------------------------------
function Rooms.lounge(parent: Instance, style: Style.Style): Model
	local m = Kit.model(parent, "Lounge")
	local rng = Rng.new(Deps.Hash.u32(style.id, "lounge"))
	local cz = -8
	Geo.box(
		m,
		V(67, 0, cz - 6),
		V(81, 0.05, cz + 6),
		if style.plain then style.walkway else style.upholsteryAlt,
		M.Fabric
	).Name =
		"Rug"
	Furniture.sofa(m, CFrame.lookAt(V(84.6, 0, cz), V(83, 0, cz)), 9, style.upholstery)
	for _, dz in { -3.6, 3.6 } do
		Furniture.guestChair(
			m,
			CFrame.lookAt(V(69.2, 0, cz + dz), V(72, 0, cz + dz * 0.6)),
			if style.plain then style.upholstery else style.upholsteryAlt,
			"Armchair"
		)
	end
	Furniture.coffeeTable(m, CFrame.new(76.6, 0, cz), 4.6, 2.8, style.stone, style.stand)
	-- the market wall: a big screen on legs facing the lounge
	local tv =
		Kit.detail(m, CFrame.lookAt(V(72, 6.6, -36.6), V(72, 6.6, -30)), V(12, 6.8, 0.3), style.bezel, M.SmoothPlastic)
	tv.Name = "MarketWall"
	Art.monitors(tv, 2, { "chart", "quotes" }, rng, { pps = 26, bezel = 0.12, maxDistance = 140 })
	for _, sx in { -1, 1 } do
		Kit.block(m, CFrame.new(72 + sx * 4.5, 1.6, -36.8), V(0.4, 3.2, 0.5), style.stand, M.Metal).Name = "Leg"
	end
	-- plants (the NE one hides the briefcase corner) and a floor lamp
	Furniture.plant(m, V(85.2, 0, 17.6), "tall", style)
	Furniture.plant(m, V(60.5, 0, -34.5), "tall", style)
	Furniture.plant(m, V(86.8, 0, -34.8), "floor", style)
	Geo.cyl(m, CFrame.new(86.6, 2.8, cz - 6), 5.6, 0.2, style.stand, M.Metal)
	local shade = Geo.cyl(m, CFrame.new(86.6, 6, cz - 6), 1.4, 1.8, style.lamp, M.Fabric)
	shade:AddTag("InteriorLight")
	Furniture.pendant(m, V(76.6, H, cz), 9.8, style, { kind = "point", range = 16, brightness = 0.8 })
	return m
end

---------------------------------------------------------------------------------------------------
-- The rival's standing desk (OfficeAnchor rival_desk is where its user stands)
---------------------------------------------------------------------------------------------------
function Rooms.rivalDesk(parent: Instance, style: Style.Style): Model
	local m = Kit.model(parent, "RivalDesk")
	local cf = Layout.rivalDesk
	local rng = Rng.new(Deps.Hash.u32(style.id, "rival"))
	local top = Kit.block(m, cf * CFrame.new(0, 3.85, 0), V(4.6, 0.15, 2.4), style.deskTop, M.SmoothPlastic)
	top.Name = "Top"
	m.PrimaryPart = top
	for _, sx in { -1, 1 } do
		Kit.block(m, cf * CFrame.new(sx * 2, 1.9, 0), V(0.3, 3.8, 2), style.deskFrame, M.Metal).Name = "Leg"
	end
	local mon = Kit.detail(m, cf * CFrame.new(0, 5.15, 0.75), V(3.1, 0.95, 0.1), style.bezel, M.SmoothPlastic)
	mon.Name = "Screens"
	Art.monitors(mon, 2, { "sheet", "email" }, rng)
	Kit.detail(m, cf * CFrame.new(0, 4.4, 0.9), V(0.2, 1.1, 0.15), style.stand, M.Metal)
	return m
end

---------------------------------------------------------------------------------------------------
-- Open-plan dressing
---------------------------------------------------------------------------------------------------
function Rooms.openPlan(parent: Instance, style: Style.Style): Model
	local m = Kit.model(parent, "OpenPlan")
	local rng = Rng.new(Deps.Hash.u32(style.id, "openplan"))
	Furniture.plant(m, V(Layout.ROW_WEST - 3, 0, -20), "tall", style)
	Furniture.plant(m, V(Layout.ROW_EAST + 3, 0, -20), "tall", style)
	Furniture.plant(m, V(Layout.ROW_WEST - 3, 0, 8), "tall", style)

	-- low lockers along the column line, between the desks and the corridor (gap at the middle column)
	local lockerColor = if style.plain then style.deskFrame else style.wall
	for _, run in { { -46, -14 }, { 2, 34 } } do
		local body = Geo.box(m, V(run[1], 0, 21.2), V(run[2], 3.6, 22.8), lockerColor, M.SmoothPlastic, true)
		body.Name = "Lockers"
		Art.lockers(body, Enum.NormalId.Front)
		Art.lockers(body, Enum.NormalId.Back)
		Geo.box(
			m,
			V(run[1] - 0.05, 3.6, 21.15),
			V(run[2] + 0.05, 3.76, 22.85),
			if style.plain then style.wood else style.woodDark,
			M.Wood
		).Name =
			"LockerTop"
	end

	-- the deal team table east of the rows
	local tx, tz = 36, -20
	Kit.block(m, CFrame.new(tx, 2.9, tz), V(4.2, 0.2, 10), if style.plain then style.deskTop else style.wood, M.Wood).Name =
		"DealTable"
	Kit.block(m, CFrame.new(tx, 1.4, tz), V(1.2, 2.8, 6), style.stand, M.Metal)
	for _, sx in { -1, 1 } do
		for _, dz in { -2.8, 2.8 } do
			local pos = V(tx + sx * 3.6, 0, tz + dz)
			Furniture.guestChair(
				m,
				CFrame.lookAt(pos, V(tx, 0, pos.Z)) * Kit.rotY(rng:range(-12, 12)),
				style.upholstery,
				"TeamChair"
			)
		end
	end

	-- a mobile whiteboard in the west bay
	local wb = Kit.detail(
		m,
		CFrame.new(-44, 5.2, -6) * Kit.rotY(-90),
		V(7, 4, 0.15),
		Color3.fromRGB(248, 248, 246),
		M.SmoothPlastic
	)
	wb.Name = "Whiteboard"
	Art.whiteboard(wb, Enum.NormalId.Front, rng)
	for _, dz in { -3.3, 3.3 } do
		Kit.detail(m, CFrame.new(-44.1, 3.6, -6 + dz), V(0.25, 7.2, 0.25), style.stand, M.Metal)
	end

	-- print station south of the boardroom
	local px, pz = -72, -31.5
	Kit.block(
		m,
		CFrame.new(px, 1.9, pz),
		V(3.4, 3.8, 2.6),
		if style.plain then style.deskFrame else style.wall,
		M.SmoothPlastic
	).Name =
		"Printer"
	Kit.detail(m, CFrame.new(px, 3.85, pz - 0.4), V(2.6, 0.12, 1.4), style.stand, M.SmoothPlastic)
	Kit.block(m, CFrame.new(px + 4.4, 1.6, pz), V(4.4, 3.2, 2.2), style.woodDark, M.Wood).Name = "PaperCabinet"
	return m
end

return Rooms
