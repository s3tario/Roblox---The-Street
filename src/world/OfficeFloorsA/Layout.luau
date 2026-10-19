--!strict
-- The department floor plan shared by every floor template in this module (top view, +Z = north, origin = centre of
-- the floor's top surface, y = 0). Floors differ in style, not in plan, so every template carries the same markers
-- in the same places and later tracks plug in by adding a style.
--
--   north band  z 38..60   8 private offices (OfficeSlot 1..8, west to east), boss corner office x 54..90, z 26..60
--   corridor    z 30..38   in front of the offices
--   open plan   4 benches x 6 workstations (DeskSlot 1..24), 9 columns, lounge by the east windows
--   west        boardroom (conference) x -90..-64, z -28..18
--   south band  z -60..-40 pantry (west), elevator lobby (centre, x -26..26), two huddle rooms (east)
-- Bake-safe (pure data + CFrame maths).

local Layout = {}

Layout.HALF_X = 90
Layout.HALF_Z = 60
Layout.HEIGHT = 17 -- floor top to the underside of the ceiling slab
Layout.SLAB = 1.2

---------------------------------------------------------------------------------------------------
-- Workstations
---------------------------------------------------------------------------------------------------
Layout.WS_WIDTH = 7
Layout.WS_DEPTH = 4
Layout.DESK_HEIGHT = 2.8
Layout.DIVIDER = 0.3
Layout.PER_SIDE = 3

-- Bench centres. A bench runs along X; side A sits on its south (-Z) side facing north, side B faces south.
-- Two benches meet end to end (terrazzo panels back to back at x = -4), so each row reads as one long desk run of
-- 6 seats a side, like the reference photo.
Layout.benches = {
	Vector3.new(-15.3, 0, -20),
	Vector3.new(7.3, 0, -20),
	Vector3.new(-15.3, 0, 8),
	Vector3.new(7.3, 0, 8),
}
Layout.ROW_WEST, Layout.ROW_EAST = -26.6, 18.6

Layout.BENCH_LENGTH = Layout.WS_WIDTH * Layout.PER_SIDE

export type Workstation = { slot: number, bench: number, side: number, index: number, cf: CFrame }

-- Desk surface centre of each workstation (y = DESK_HEIGHT). LookVector = the way the sitter faces (toward the
-- bench's divider), so the chair stands at +Z in that frame and the monitors at -Z.
function Layout.workstations(): { Workstation }
	local out: { Workstation } = {}
	local slot = 0
	local zOff = Layout.WS_DEPTH / 2 + Layout.DIVIDER / 2
	for b, centre in Layout.benches do
		for side = 1, 2 do
			local s = if side == 1 then -1 else 1 -- side 1 = south side (z < centre)
			for i = 1, Layout.PER_SIDE do
				slot += 1
				local x = centre.X + (i - (Layout.PER_SIDE + 1) / 2) * Layout.WS_WIDTH
				local pos = Vector3.new(x, Layout.DESK_HEIGHT, centre.Z + s * zOff)
				local facing = Vector3.new(0, 0, -s) -- toward the divider
				table.insert(out, {
					slot = slot,
					bench = b,
					side = side,
					index = i,
					cf = CFrame.lookAt(pos, pos + facing),
				})
			end
		end
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Offices (north band). Office frames sit at the centre of the office floor, LookVector = out through the glass
-- front (south, toward the corridor).
---------------------------------------------------------------------------------------------------
Layout.OFFICE_COUNT = 8
Layout.OFFICE_W = 18
Layout.OFFICE_D = 22
Layout.OFFICE_FRONT_Z = 38
Layout.OFFICE_WEST_X = -90

function Layout.offices(): { CFrame }
	local out: { CFrame } = {}
	local cz = Layout.OFFICE_FRONT_Z + Layout.OFFICE_D / 2
	for i = 1, Layout.OFFICE_COUNT do
		local cx = Layout.OFFICE_WEST_X + Layout.OFFICE_W / 2 + (i - 1) * Layout.OFFICE_W
		table.insert(out, CFrame.new(cx, 0, cz))
	end
	return out
end

-- Boss corner office (NE): x 54..90, z 26..60. Door in its west wall at the end of the corridor.
Layout.boss = { minX = 54, maxX = 90, minZ = 26, maxZ = 60, doorZ0 = 28.5, doorZ1 = 35.5 }

Layout.corridor = { minX = -90, maxX = 54, minZ = 30, maxZ = 38 }

---------------------------------------------------------------------------------------------------
-- Rooms
---------------------------------------------------------------------------------------------------
Layout.conference = { minX = -90, maxX = -64, minZ = -28, maxZ = 18, doorZ0 = -8.25, doorZ1 = -1.75 }
Layout.pantry = { minX = -90, maxX = -26, minZ = -60, maxZ = -40 }
Layout.lobby = { minX = -26, maxX = 26, minZ = -60, maxZ = -38, coreZ = -59.5, wallZ = -38.4 }
Layout.huddles = {
	{ minX = 26, maxX = 58, minZ = -60, maxZ = -42, doorX0 = 30, doorX1 = 36.5 },
	{ minX = 58, maxX = 90, minZ = -60, maxZ = -42, doorX0 = 62, doorX1 = 68.5 },
}
Layout.lounge = { minX = 56, maxX = 88, minZ = -38, maxZ = 22 }

Layout.elevators = { -15, -5, 5, 15 } -- door centres (x) on the core wall

Layout.columns = {
	Vector3.new(-52, 0, -30),
	Vector3.new(-6, 0, -30),
	Vector3.new(40, 0, -30),
	Vector3.new(-52, 0, -6),
	Vector3.new(-6, 0, -6),
	Vector3.new(40, 0, -6),
	Vector3.new(-52, 0, 22),
	Vector3.new(-6, 0, 22),
	Vector3.new(40, 0, 22),
}
Layout.COLUMN_D = 3.2

---------------------------------------------------------------------------------------------------
-- Markers
---------------------------------------------------------------------------------------------------
local function facing(pos: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(pos, pos + dir)
end

Layout.anchors = {
	floor_entry = facing(Vector3.new(0, 3, -50), Vector3.new(0, 0, 1)),
	rival_desk = facing(Vector3.new(28.4, 3, 8), Vector3.new(-1, 0, 0)),
}

-- The rival's standing desk past the east end of the north row (its user stands on its east side, facing west).
Layout.rivalDesk = facing(Vector3.new(25.6, 0, 8), Vector3.new(1, 0, 0))

-- The CEO walkthrough loop (corridor -> east aisle -> south aisle -> west aisle); straight legs stay clear.
Layout.ceoPath = {
	Vector3.new(-56, 3, 34),
	Vector3.new(46, 3, 34),
	Vector3.new(46, 3, -34),
	Vector3.new(-56, 3, -34),
}

Layout.toLobby = facing(Vector3.new(0, 5, -58.4), Vector3.new(0, 0, 1))
Layout.TO_LOBBY_SIZE = Vector3.new(16, 10, 1.6)

Layout.briefcase = Vector3.new(86.5, 0.6, 19.5)
Layout.fireAlarm = facing(Vector3.new(-25.2, 4.6, -43), Vector3.new(1, 0, 0))

-- Pantry communal table (top surface centre) for the pizza party.
Layout.pantryTable = Vector3.new(-72, 2.9, -53.5)

return Layout
