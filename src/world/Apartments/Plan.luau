--!strict
-- The Ashford Residences floor plan (local frame: +X east, +Z south, ground floor at y = 0). Pure numbers: the
-- builders and the tests both read it. Bake-safe.
--
--   three residential floors (y = 0, 16, 32), each a double-loaded corridor running east along z = 0 with four units
--   on its north side and four on its south side (8 per floor, 24 in all, numbered 1..24 floor by floor, odd numbers
--   north and even numbers south, rising eastward from the stairs)
--   west of the corridors: the stair hall (a U-stair per storey, landings in line with the corridors)
--   south-west: the double-height lobby with the street doors
--
--   Plan.units() -> { UnitSpot }   UnitSpot = { n, level, floorY, side = "north" | "south", index (0..3), cx, frame }
--       frame = CFrame (relative to the venue origin) at the unit's centre on the corridor wall's inner face, at floor
--       level, LookVector pointing into the unit. Unit-local: ux across (-HALF_W..HALF_W), ud depth (0..DEPTH).
--   Plan.unitPoint(frame, ux, uy, ud) -> CFrame     a point in a unit's frame (same orientation as the frame)

local Plan = {}

Plan.LEVELS = 3
Plan.LEVEL_H = 16 -- floor to floor
Plan.SLAB = 1
Plan.CLEAR_H = Plan.LEVEL_H - Plan.SLAB -- unit and corridor clear height

-- corridor
Plan.COR_X0, Plan.COR_X1 = -65, 65
Plan.COR_HALF = 5 -- corridor z in [-5, 5]
Plan.FRONT_T = 1.5 -- corridor walls (unit fronts)

-- units
Plan.UNIT_W = 30 -- clear width
Plan.PARTY_T = 2 -- party walls between units
Plan.PITCH = Plan.UNIT_W + Plan.PARTY_T
Plan.DEPTH = 34 -- clear depth from the corridor wall to the window wall
Plan.BACK_T = 1.5
Plan.HALF_W = Plan.UNIT_W / 2
Plan.PER_SIDE = 4
Plan.UNITS = Plan.LEVELS * Plan.PER_SIDE * 2
Plan.ROW_X0 = -64 -- west edge (party wall centre) of the first unit
Plan.FRONT_Z = Plan.COR_HALF + Plan.FRONT_T -- inner face of the corridor wall, measured from z = 0
Plan.BACK_Z = Plan.FRONT_Z + Plan.DEPTH -- inner face of the window wall

-- doorways (unit-local ux of the door centre)
Plan.DOOR_UX = -10.5
Plan.DOOR_W = 6
Plan.DOOR_H = 9.5

-- the stair hall: near landing at the corridor end, flights, far landing
Plan.STAIR_X0, Plan.STAIR_X1 = -95, -65
Plan.NEAR_X0 = -73 -- near landing x in [-73, -65]
Plan.FAR_X1 = -87 -- far landing x in [-95, -87]
Plan.STAIR_HALF = 8 -- stair hall z in [-8, 8]
Plan.LANE_GAP = 0.5 -- the centre wall z in [-0.5, 0.5]
Plan.STEPS = 8 -- per flight (two flights per storey)
Plan.RISE = 1
Plan.RUN = 1.75

-- the lobby
Plan.LOBBY_X0, Plan.LOBBY_X1 = -140, -66
Plan.LOBBY_Z0, Plan.LOBBY_Z1 = 9, 57
Plan.LOBBY_H = 28
Plan.ENTRY_X = -103

export type UnitSpot = {
	n: number,
	level: number,
	floorY: number,
	side: string,
	index: number,
	cx: number,
	frame: CFrame,
}

function Plan.unitNumber(level: number, index: number, side: string): number
	return (level - 1) * Plan.PER_SIDE * 2 + index * 2 + (if side == "north" then 1 else 2)
end

function Plan.units(): { UnitSpot }
	local out: { UnitSpot } = {}
	for level = 1, Plan.LEVELS do
		local y = (level - 1) * Plan.LEVEL_H
		for index = 0, Plan.PER_SIDE - 1 do
			local cx = Plan.ROW_X0 + Plan.PITCH * index + Plan.PITCH / 2
			for _, side in { "north", "south" } do
				local z = if side == "north" then -Plan.FRONT_Z else Plan.FRONT_Z
				local yaw = if side == "north" then 0 else math.pi
				table.insert(out, {
					n = Plan.unitNumber(level, index, side),
					level = level,
					floorY = y,
					side = side,
					index = index,
					cx = cx,
					frame = CFrame.new(cx, y, z) * CFrame.Angles(0, yaw, 0),
				})
			end
		end
	end
	table.sort(out, function(a, b)
		return a.n < b.n
	end)
	return out
end

function Plan.unitPoint(frame: CFrame, ux: number, uy: number, ud: number): CFrame
	return frame * CFrame.new(ux, uy, -ud)
end

return Plan
