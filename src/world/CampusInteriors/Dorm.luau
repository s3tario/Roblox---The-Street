--!strict
-- Marlow House, inside (interior "dorm"): a 1960s residence hall that smells like instant noodles.
--
--   hub:     the lobby (mailboxes, the RA desk, quiet-hours notices; the exit door door_dorm_exit and the arrival
--            anchor dorm_entry) opening onto the common room (couches, the TV on MARKET CLOSE, a beat-up terminal,
--            ping-pong, vending, npc_roommate)
--   wings:   Wing A (west, rooms 101-112) and Wing B (east, rooms 113-124): a corridor with six rooms either side,
--            EXACTLY 24 rooms in all (DormRoom: UnitSlot 1..24), an alarmed emergency exit at each end
--
-- build(parent, mk, origin) -> Model. Bake-safe.

local Deps = require(script.Parent.Deps)
local Shell = require(script.Parent.Shell)
local Room = require(script.Parent.DormRoom)

local Kit = Deps.Kit
local Props = Deps.Props
local Signs = Deps.Signs
local Paint = Deps.Paint
local Text = Deps.Text
local Markers = Deps.Markers
local Core = Deps.Gui.Core
local P = Deps.Palette
local C = P.campus
local hex = P.hex
local M = Enum.Material

local Dorm = {}

-- hub (lobby + common room) and wings
local HX = 24 -- hub half width
local HZ0, HZ1 = -36, 40 -- hub north / south inner faces
local HH = 14 -- hub ceiling
local CW = 6 -- corridor half width (clear)
local ROOM_W = 14 -- room pitch along the corridor
local ROOMS = 6 -- per side per wing
local WING_LEN = ROOM_W * ROOMS -- 84
local RD = Room.DEPTH
local WH = Room.HEIGHT
local WALL = hex("#CFC9B8")
local CINDER = hex("#BDB6A4")

Dorm.ENTRY = { x = 0, z = 33 }
Dorm.UNITS = ROOMS * 2 * 2

---------------------------------------------------------------------------------------------------
local function hubShell(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local floor = Shell.box(m, F, -HX - 1, -1, HZ0 - 1, HX + 1, 0, HZ1 + 1, hex("#9C9482"), M.Slate)
	floor.Name = "HubFloor"
	local fg, FW, FH = Paint.surface(floor, Enum.NormalId.Top, 2, { maxDistance = 0 })
	Core.checker(Core.frame(fg, 0, 0, 1, 1, hex("#9C9482")), 25, 39, hex("#9C9482"), hex("#8A826F"))
	for _ = 1, 12 do
		Core.dot(fg, rng:range(0, FW), rng:range(0, FH), rng:range(4, 12), hex("#6E6858"), 0.6)
	end
	Shell.box(m, F, -HX - 1, HH, HZ0 - 1, HX + 1, HH + 1, HZ1 + 1, hex("#E6E2D6"), M.SmoothPlastic).Name = "HubCeiling"
	Shell.wallX(m, F, HZ0 - 0.5, -HX - 1, HX + 1, 0, HH, 1, CINDER, M.Concrete)
	Shell.wallX(m, F, HZ1 + 0.5, -HX - 1, HX + 1, 0, HH, 1, CINDER, M.Concrete)
	for _, sx in { -1, 1 } do
		Shell.wallZ(m, F, sx * (HX + 0.5), HZ0, HZ1, 0, HH, 1, CINDER, M.Concrete, { { c = 0, w = CW * 2, h = WH } })
	end
	-- painted cinder-block coursing on the hub walls (one gui per long wall)
	for _, d in m:GetChildren() do
		if d:IsA("BasePart") and d.Name == "Wall" and d.Size.Y >= HH - 0.1 and math.max(d.Size.X, d.Size.Z) > 30 then
			local face = if d.Size.X > d.Size.Z then Enum.NormalId.Front else Enum.NormalId.Right
			local g, W, H = Paint.surface(d, face, 2, { maxDistance = 0 })
			for y = 0, H, 2 do
				Core.px(g, 0, y, W, 1, hex("#A9A292"), 0.55)
			end
			local other = if face == Enum.NormalId.Front then Enum.NormalId.Back else Enum.NormalId.Left
			local g2, W2, H2 = Paint.surface(d, other, 2, { maxDistance = 0 })
			for y = 0, H2, 2 do
				Core.px(g2, 0, y, W2, 1, hex("#A9A292"), 0.55)
			end
		end
	end
	-- lights
	for i, z in { -26, -10, 12, 28 } do
		for _, x in { -12, 12 } do
			Shell.troffer(m, F.cf(x, HH - 0.1, z), Vector3.new(2.4, 0.15, 4.4), x < 0 and (i == 1 or i == 3))
		end
	end
end

---------------------------------------------------------------------------------------------------
local function lobby(m: Instance, F: Shell.Frame, mk: Instance, rng: Deps.RngT)
	local l = Kit.model(m, "Lobby")
	-- mailboxes on the east wall
	local mb = Shell.box(l, F, HX - 0.6, 2, 16, HX, 9, 32, hex("#9A8E6E"), M.Metal)
	mb.Name = "Mailboxes"
	local mg, MW, MH = Paint.surface(mb, Enum.NormalId.Left, 10)
	for cx = 0, 15 do
		for cy = 0, 6 do
			local box = Core.px(mg, 4 + cx * (MW - 8) / 16, 4 + cy * (MH - 8) / 7, (MW - 8) / 16 - 3, (MH - 8) / 7 - 3, hex("#B8AD8A"))
			Core.px(box, 2, 2, 8, 3, hex("#2A2622"))
		end
	end
	Shell.sign(l, F.cf(HX, 10.2, 24, Shell.W), 6, 1, Text.dormInside.mail, { color = hex("#24262A") })
	-- the RA desk
	Shell.box(l, F, -HX + 2, 0, 20, -HX + 4.6, 3.8, 30, hex("#6B4E35"), M.Wood).Name = "RADesk"
	Shell.box(l, F, -HX + 1.8, 3.8, 19.8, -HX + 5, 4.1, 30.2, hex("#D8D2C2"), M.SmoothPlastic).Name = "RADeskTop"
	Shell.sign(l, F.cf(-HX, 8.2, 25, Shell.E), 8, 1.2, Text.dormInside.ra, { color = hex("#2C5E8A") })
	Props.build("desk_lamp", l, F.cf(-HX + 3.3, 4.1, 28.4, Shell.E), { seed = "ra-lamp", lit = true })
	-- the name over the door, notices, a bench and a bin
	Shell.sign(l, F.cf(0, 12.8, HZ1, Shell.N), 18, 1.6, Text.dormInside.lobby, { color = hex("#24262A"), ink = hex("#E9E2CF") })
	Shell.sign(l, F.cf(14, 6.5, HZ1, Shell.N), 6, 1.6, Text.dormInside.quiet, {
		color = hex("#E9E2CF"),
		ink = C.ink,
		font = Enum.Font.SpecialElite,
	})
	local fl = Kit.detail(l, F.cf(-14, 6, HZ1 - 0.05, Shell.N), Vector3.new(6, 4, 0.04), Color3.new(1, 1, 1), M.SmoothPlastic)
	fl.Transparency = 1
	local flg, FLW, FLH = Paint.surface(fl, Enum.NormalId.Front, 20)
	Paint.flyers(flg, FLW, FLH, rng, { Text.flyers[2], Text.flyers[11], Text.flyers[8], Text.flyers[6] })
	Shell.box(l, F, 8, 1.6, 36.6, 16, 1.9, 38.4, hex("#5A5F63"), M.Metal).Name = "Bench"
	Shell.box(l, F, 11.8, 0, 37.3, 12.2, 1.6, 37.7, hex("#2A2A2A"), M.Metal, false)
	Props.build("trash_can", l, F.cf(-6, 0, 38, 0), { seed = "dorm-lobby-bin" })
	Props.build("plant_floor", l, F.cf(20, 0, 37.5, 0), { seed = "dorm-plant", color = hex("#5A6A3A") })
	Shell.box(l, F, -5, 0, 34, 5, 0.06, 39.4, hex("#3A3A38"), M.Fabric, false).Name = "DoorMat"
	Shell.exit(l, mk, "door_dorm_exit", F.cf(0, 0, HZ1, Shell.N), { label = Text.exitTo.dorm, glass = true, doorColor = hex("#5A6A70") })
	-- the wing signs over the corridor openings
	Shell.sign(l, F.cf(-HX, WH + 1, 0, Shell.E), 11, 1.6, Text.dormInside.wingA, { color = hex("#2C5E8A") })
	Shell.sign(l, F.cf(HX, WH + 1, 0, Shell.W), 11, 1.6, Text.dormInside.wingB, { color = hex("#2C5E8A") })
end

---------------------------------------------------------------------------------------------------
local function commonRoom(m: Instance, F: Shell.Frame, mk: Instance, rng: Deps.RngT)
	local c = Kit.model(m, "CommonRoom")
	Shell.box(c, F, -16, 0, -32, 16, 0.06, -12, hex("#6E4A3A"), M.Fabric, false).Name = "Rug"
	Shell.sign(c, F.cf(0, 12.2, HZ0, Shell.S), 14, 1.4, Text.dormInside.common, { color = hex("#24262A") })
	-- the TV on the north wall, permanently on the market close
	Shell.box(c, F, -6, 4, HZ0, 6, 11, HZ0 + 0.4, hex("#141414"), M.SmoothPlastic).Name = "TVBezel"
	local tv = Shell.box(c, F, -5.6, 4.4, HZ0 + 0.42, 5.6, 10.6, HZ0 + 0.5, hex("#0B1622"), M.SmoothPlastic, false)
	tv.Name = "TVScreen"
	local tg, TW, TH = Paint.surface(tv, Enum.NormalId.Back, 24, { glow = true, brightness = 1.1 })
	local tbg = Core.bg(tg, hex("#0B1622"))
	Core.label(tbg, Text.dormInside.tv, 0.04, 0.02, 0.92, 0.14, hex("#FF5A5F"), { font = Enum.Font.GothamBold })
	Core.candles(tbg, TW * 0.05, TH * 0.2, TW * 0.9, TH * 0.55, rng, 22)
	Core.label(tbg, Core.tickerLine(rng, 6), 0.02, 0.82, 0.96, 0.14, hex("#E8EEF5"), { font = Enum.Font.Code, rich = true })
	Kit.light(tv, "point", { Color = hex("#9FC2FF"), Range = 16, Brightness = 0.6 })
	-- two tired couches facing the TV and a coffee table with takeout
	for i, z in { -20, -14 } do
		local cf = F.cf(0, 0, z, Shell.N)
		local col = if i == 1 then hex("#4A5A3A") else hex("#6E2E2A")
		Kit.block(c, cf * CFrame.new(0, 1, 0), Vector3.new(10, 2, 3.4), col, M.Fabric).Name = "Couch"
		Kit.detail(c, cf * CFrame.new(0, 2.7, 1.4), Vector3.new(10, 2.8, 0.8), Kit.shade(col, -0.1), M.Fabric)
		for _, s in { -1, 1 } do
			Kit.detail(c, cf * CFrame.new(s * 5.1, 1.8, 0), Vector3.new(0.8, 1.6, 3.4), Kit.shade(col, -0.1), M.Fabric)
		end
	end
	Shell.box(c, F, -3, 1.6, -27, 3, 1.9, -24, hex("#8E7A5A"), M.Wood).Name = "CoffeeTable"
	Shell.box(c, F, -2.6, 0, -26.6, 2.6, 1.6, -24.4, hex("#6B5A40"), M.Wood, false)
	Props.build("pizza_box", c, F.cf(1.2, 1.9, -25.5, 15), { count = 2, seed = "dorm-pizza" })
	-- the beat-up terminal (terminal) on a desk by the west wall
	Shell.box(c, F, -HX, 2.8, -30, -HX + 3, 3.1, -24, hex("#B8956A"), M.Wood).Name = "TerminalDesk"
	Shell.box(c, F, -HX + 0.2, 0, -29.6, -HX + 2.8, 2.8, -29.2, hex("#5A5F63"), M.Metal, false)
	Shell.box(c, F, -HX + 0.2, 0, -24.8, -HX + 2.8, 2.8, -24.4, hex("#5A5F63"), M.Metal, false)
	local mon = Shell.box(c, F, -HX + 0.8, 3.4, -28.6, -HX + 1.1, 5.6, -25.4, hex("#141414"), M.SmoothPlastic)
	mon.Name = "TerminalScreen"
	Markers.interact(mon, "terminal")
	local mg = Paint.surface(mon, Enum.NormalId.Right, 50, { glow = true })
	local mbg = Core.bg(mg, hex("#0B1622"))
	Core.lineChart(mbg, 6, 22, 148, 70, Core.series(rng, 26, 80, 2, 0.15), Core.UP, 2)
	Core.label(mbg, "MARLOW HOUSE PC · DO NOT INSTALL GAMES", 0.03, 0.02, 0.94, 0.14, Core.AMBER, { font = Enum.Font.Code })
	local sticky = Kit.detail(c, F.cf(-HX + 1.15, 5.9, -26, Shell.E), Vector3.new(0.6, 0.6, 0.02), hex("#F2D95C"), M.SmoothPlastic)
	sticky.Name = "StickyNote"
	Shell.chair(c, F.cf(-HX + 5, 0, -27, Shell.W), hex("#2A2A2A"))
	-- ping-pong, vending, a mini fridge, windows
	local pp = F.cf(14, 0, -26, Shell.N)
	Kit.block(c, pp * CFrame.new(0, 2.6, 0), Vector3.new(5, 0.25, 9), hex("#2F5A3A"), M.SmoothPlastic).Name = "PingPong"
	Kit.detail(c, pp * CFrame.new(0, 3.1, 0), Vector3.new(5.4, 0.7, 0.05), hex("#E9E2CF"), M.Fabric).Name = "Net"
	Kit.detail(c, pp * CFrame.new(0, 1.25, 0), Vector3.new(3.6, 2.5, 7), hex("#2A2A2A"), M.Metal)
	Props.build("vending_machine", c, F.cf(HX - 1.6, 0, -18, Shell.W), { seed = "dorm-vend" })
	Props.build("mini_fridge", c, F.cf(HX - 1.4, 0, -12.5, Shell.W), { seed = "dorm-fridge" })
	for _, x in { -16, 16 } do
		Shell.window(c, F.cf(x, 7.5, HZ0, Shell.S), 7, 6, rng, "night")
	end
	Markers.npc(mk, "npc_roommate", F.cf(-9, 3, -17, Shell.E))
end

---------------------------------------------------------------------------------------------------
-- A wing: corridor, rooms both sides, the emergency exit at the end
---------------------------------------------------------------------------------------------------
local function emergencyExit(parent: Instance, cf: CFrame)
	Kit.detail(parent, cf * CFrame.new(0, 4.7, -0.1), Vector3.new(4.6, 9.4, 0.2), hex("#2A2826"), M.Metal).Name = "ExitFrame"
	Kit.detail(parent, cf * CFrame.new(0, 4.5, -0.25), Vector3.new(4, 8.8, 0.2), hex("#8A2C2C"), M.Metal).Name = "ExitDoor"
	Kit.detail(parent, cf * CFrame.new(0, 4, -0.42), Vector3.new(3.2, 0.25, 0.2), hex("#B8B8B0"), M.Metal).Name = "PushBar"
	local sign = Kit.detail(parent, cf * CFrame.new(0, 6.6, -0.38), Vector3.new(3.4, 1.4, 0.05), hex("#C83A2A"), M.SmoothPlastic)
	Kit.sign(sign, Text.dormInside.alarm, { font = Enum.Font.Highway, color = hex("#F4F1E6"), pixelsPerStud = 40 })
	local lit = Kit.detail(parent, cf * CFrame.new(0, 10.2, -0.2), Vector3.new(2.6, 0.9, 0.25), hex("#1A1A1A"), M.SmoothPlastic)
	Kit.sign(lit, Text.exit, { font = Enum.Font.Highway, color = hex("#FF3B30"), pixelsPerStud = 40, glow = true })
	lit:AddTag("InteriorLight")
end

local function wing(m: Instance, F: Shell.Frame, side: number, firstUnit: number, firstNumber: number, rng: Deps.RngT)
	local name = if side < 0 then "WingA" else "WingB"
	local w = Kit.model(m, name)
	local inner = side * (HX + 1) -- the hub wall's outer face
	local outer = side * (HX + 1 + WING_LEN)
	local x0, x1 = math.min(inner, outer), math.max(inner, outer)
	local backZ = CW + 1 + RD -- inner face of the back walls
	-- floor (linoleum with a stripe down the corridor), ceilings
	local floor = Shell.box(w, F, x0 - 1, -1, -backZ - 1, x1 + 1, 0, backZ + 1, hex("#A39A86"), M.SmoothPlastic)
	floor.Name = "WingFloor"
	Shell.box(w, F, x0, 0, -CW, x1, 0.04, CW, hex("#8E8572"), M.SmoothPlastic, false).Name = "CorridorRunner"
	Shell.box(w, F, x0, 0.04, -0.4, x1, 0.06, 0.4, hex("#7A3B2E"), M.SmoothPlastic, false).Name = "Stripe"
	Shell.box(w, F, x0, WH, -backZ - 1, x1, WH + 1, backZ + 1, hex("#E6E2D6"), M.SmoothPlastic).Name = "WingCeiling"
	-- corridor walls with a doorway per room, back walls, the end wall
	local gaps: { Shell.Gap } = {}
	for k = 0, ROOMS - 1 do
		table.insert(gaps, { c = inner + side * (ROOM_W * k + ROOM_W / 2), w = 6, h = 9.2 })
	end
	for _, z in { -(CW + 0.5), CW + 0.5 } do
		Shell.wallX(w, F, z, x0, x1, 0, WH, 1, WALL, M.Concrete, gaps)
	end
	for _, z in { -(backZ + 0.5), backZ + 0.5 } do
		Shell.wallX(w, F, z, x0, x1, 0, WH, 1, WALL, M.Concrete)
	end
	Shell.wallZ(w, F, outer + side * 0.5, -backZ - 1, backZ + 1, 0, WH, 1, WALL, M.Concrete)
	-- (the first rooms' hub-side walls are the hub's own side walls, built by hubShell)
	-- partitions between rooms
	for k = 1, ROOMS - 1 do
		local x = inner + side * ROOM_W * k
		for _, zr in { { -backZ, -(CW + 1) }, { CW + 1, backZ } } do
			Shell.wallZ(w, F, x, zr[1], zr[2], 0, WH, 1, WALL, M.Concrete)
		end
	end
	-- the rooms: north side first, then south, numbered from the hub outward
	local unit, number = firstUnit, firstNumber
	for _, north in { true, false } do
		for k = 0, ROOMS - 1 do
			local cx = inner + side * (ROOM_W * k + ROOM_W / 2)
			local rc = if north then F.cf(cx, 0, -(CW + 1), Shell.N) else F.cf(cx, 0, CW + 1, Shell.S)
			Room.build(w, rc, unit, number, Deps.Rng.new("dorm-room-" .. unit))
			unit += 1
			number += 1
		end
	end
	-- corridor lights, one real light per wing; a fire extinguisher and posters; the emergency exit
	for k = 0, ROOMS - 1 do
		local x = inner + side * (ROOM_W * k + ROOM_W / 2)
		local t = Shell.troffer(w, F.cf(x, WH - 0.1, 0), Vector3.new(1.4, 0.15, 5), k == 2)
		if rng:chance(0.15) then
			t.Transparency = 0.7
			t:SetAttribute("Flicker", true)
		end
	end
	local ext = F.cf(inner + side * (ROOM_W * 3), 3.4, -(CW - 0.3))
	Kit.cylinder(w, ext, 2.4, 0.8, hex("#C83A2A"), M.Metal).Name = "Extinguisher"
	for i = 0, 1 do
		local x = inner + side * (ROOM_W * (2 + i * 2)) -- on a partition line, between two doorways
		local spec = Text.posters[((i + (if side > 0 then 2 else 0)) % #Text.posters) + 1]
		Signs.poster(w, F.cf(x, 4.4, CW, Shell.N), {
			title = spec.title,
			body = spec.body,
			colors = { hex("#E9E2CF"), hex("#2C5E8A"), hex("#1A1A1A") },
			width = 2.6,
			height = 3.6,
			seed = name .. "-poster" .. i,
		})
	end
	emergencyExit(w, F.cf(outer, 0, 0, if side < 0 then Shell.E else Shell.W))
	return w
end

---------------------------------------------------------------------------------------------------
function Dorm.build(parent: Instance, mk: Instance, origin: Vector3): Model
	local m = Kit.model(parent, "dorm")
	m:SetAttribute("Interior", "dorm")
	m:SetAttribute("LightingPreset", "campus_interior")
	local F = Shell.frame(origin)
	local rng = Deps.Rng.new("marlow-interior")
	hubShell(m, F, rng)
	lobby(m, F, mk, rng)
	commonRoom(m, F, mk, rng)
	wing(m, F, -1, 1, 101, rng)
	wing(m, F, 1, 13, 113, rng)
	Markers.anchor(mk, "dorm_entry", F.cf(Dorm.ENTRY.x, 3, Dorm.ENTRY.z, Shell.N))
	return m
end

return Dorm
