--!strict
-- The company lobby plan (top view, +Z = north, origin = centre of the hall floor's top surface, y = 0).
--
--   main hall   x -52..52, z -36..36, double height (HALL_H = 30 to the soffit, the coffer rises to 32)
--   south       the glass street facade with the revolving door on the axis (x = 0); the Street beyond it is painted
--   north       the logo wall (x -24..24) behind the reception desk
--   east        the security gates in the mouth of the elevator hall (x 52..84, z -8..10, 6 cars)
--   west        lounge (sofas, art wall) and the deal vitrine; south-east the coffee bar; north-east a waiting area
-- Bake-safe (pure data + CFrame maths).

local Plan = {}

Plan.HALF_X = 52
Plan.MIN_Z = -36
Plan.MAX_Z = 36
Plan.HALL_H = 30 -- floor to the soffit band
Plan.COFFER_H = 32 -- floor to the coffer ceiling
Plan.WALL = 1.2
Plan.SOFFIT = 8 -- soffit band width around the hall

-- The revolving door on the facade axis and the portal it sits in.
Plan.door = { x = 0, z = -36, radius = 4.4, portalHalf = 6, portalTop = 11.5 }

-- Columns flanking the nave from the door to reception.
Plan.columns = {
	Vector3.new(-17, 0, -18),
	Vector3.new(17, 0, -18),
	Vector3.new(-17, 0, 6),
	Vector3.new(17, 0, 6),
}
Plan.COLUMN_D = 3.8

Plan.medallion = Vector3.new(0, 0, -8)
Plan.MEDALLION_D = 15

-- Logo wall (its face is at z = LOGO_FACE_Z, facing south) and reception in front of it.
Plan.logoWall = { minX = -24, maxX = 24, faceZ = 34.4 }
Plan.reception = { x = 0, z = 18, length = 18, depth = 3.6 }

-- Elevator hall east of the gates.
Plan.elevatorHall = { minX = 52, maxX = 84, minZ = -8, maxZ = 10, height = 14 }
Plan.cars = { 60, 68, 76 } -- car centres (x) on both long walls
Plan.CAR_W = 5.4 -- clear door width
Plan.CAR_H = 9.6 -- clear door height
Plan.panelX = 64 -- call-button panels between the first two cars on each wall
Plan.gateX = 48 -- centre line of the security gates (in the main hall, in front of the hall mouth)
Plan.GATE_LEN = 5

-- Zones dressed by Lounge.
Plan.lounge = { minX = -50, maxX = -26, minZ = -30, maxZ = 4 }
Plan.vitrine = { minX = -50, maxX = -28, minZ = 14, maxZ = 34 }
Plan.cafe = { minX = 30, maxX = 52, minZ = -34, maxZ = -14 }
Plan.waiting = { minX = 26, maxX = 50, minZ = 16, maxZ = 34 }

-- The Street painted beyond the glass.
Plan.street = {
	sidewalkZ = -64, -- near kerb line
	roadZ = -92, -- far kerb line
	farZ = -104, -- facades across the road
	halfX = 178,
}

---------------------------------------------------------------------------------------------------
-- Markers
---------------------------------------------------------------------------------------------------
local function facing(pos: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(pos, pos + dir)
end

Plan.anchors = {
	entry = facing(Vector3.new(0, 3, -25), Vector3.new(0, 0, 1)),
	elevators = facing(Vector3.new(66, 3, 1), Vector3.new(-1, 0, 0)),
	receptionist = facing(Vector3.new(0, 3, 21.6), Vector3.new(0, 0, -1)),
}

-- The OfficeDoor "exit" trigger in the revolving door's inner mouth (front face toward the hall).
Plan.exitDoor = facing(Vector3.new(0, 5, -31.4), Vector3.new(0, 0, 1))
Plan.EXIT_SIZE = Vector3.new(10, 10, 3)

return Plan
