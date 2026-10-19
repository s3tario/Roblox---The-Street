--!strict
-- The Eastbridge site plan: every coordinate the campus builders share, in LOCAL studs around the region centre
-- (Plan.ORIGIN, the middle of Config/World.regions.campus). +X runs east toward the river and the city, +Z runs
-- south. Ground: streets top out at y = 0, sidewalks, lots, plazas and paths at y = WALK (0.5).
--
--   Plan.cf(x, y, z, yaw?) -> CFrame       world CFrame; yaw in degrees (0 faces north (-Z), -90 east, 90 west,
--                                           180 south)
--   Plan.v(x, y, z) -> Vector3              world position
--   Plan.facing(x, y, z, tx, tz) -> CFrame  world CFrame at (x, y, z) looking toward (tx, y, tz)
--
-- Layout (north at the top):
--
--     backdrop row ............................................................... backdrop row
--     | Halvorsen |  Career Center (faces S)   | service yard |  Mill  | storage          | river
--     |   Hall    |  quad: lawns, dead fountain | Marlow House |  St    | viaduct+station  |   & the
--     | (faces E) |  gate on the avenue         |  (faces W)   |        | plaza            | skyline
--     ============================ Eastbridge Avenue (E-W) ==================================== overlook
--     | bus depot | diner | laundromat | pawn | alley | Grind House | vacant | Co-op |  | hardware | court
--     | + garage  | back alley ......................................................|  | parking + billboard
--     |           | construction lot (fenced) ................................. |    |
--     backdrop row ............................................................... backdrop row

local Deps = require(script.Parent.Deps)

local World = Deps.World

local Plan = {}

local region = World.regions.campus
Plan.ORIGIN = Vector3.new((region.min.X + region.max.X) / 2, 0, (region.min.Z + region.max.Z) / 2)
Plan.HALF = Vector3.new((region.max.X - region.min.X) / 2, 0, (region.max.Z - region.min.Z) / 2) -- 400 x 400

local O = Plan.ORIGIN

function Plan.v(x: number, y: number, z: number): Vector3
	return Vector3.new(O.X + x, O.Y + y, O.Z + z)
end

function Plan.cf(x: number, y: number, z: number, yaw: number?): CFrame
	local c = CFrame.new(O.X + x, O.Y + y, O.Z + z)
	if yaw and yaw ~= 0 then
		c *= CFrame.Angles(0, math.rad(yaw), 0)
	end
	return c
end

function Plan.facing(x: number, y: number, z: number, tx: number, tz: number): CFrame
	local p = Plan.v(x, y, z)
	return CFrame.lookAt(p, Vector3.new(O.X + tx, p.Y, O.Z + tz))
end

-- Yaw (degrees) whose LookVector points along each compass direction.
Plan.N, Plan.E, Plan.S, Plan.W = 0, -90, 180, 90

Plan.ROAD = 0
Plan.WALK = 0.5
Plan.LAWN = 0.56

-- Where players can walk (invisible boundary walls stand just outside)
Plan.PLAY = { x0 = -250, x1 = 232, z0 = -242, z1 = 200 }

---------------------------------------------------------------------------------------------------
-- Streets
---------------------------------------------------------------------------------------------------
Plan.avenue = { x0 = -262, x1 = 214, z0 = -14, z1 = 14, walkN = { -26, -14 }, walkS = { 14, 26 } }
Plan.mill = { x0 = 80, x1 = 108, z0 = -250, z1 = 208, walkW = { 68, 80 }, walkE = { 108, 120 } }
-- Crosswalks: { x, z, along = "x"|"z" (the direction people walk), length }
Plan.crosswalks = {
	{ x = -85, z = 0, along = "z", width = 10, length = 28 },
	{ x = -200, z = 0, along = "z", width = 10, length = 28 },
	{ x = 94, z = -20, along = "x", width = 8, length = 28 },
	{ x = 94, z = 20, along = "x", width = 8, length = 28 },
	{ x = 60, z = 0, along = "z", width = 10, length = 28 },
	{ x = 158, z = 0, along = "z", width = 10, length = 28 },
}

-- Ground lots (top at WALK). Each lists its surface: concrete plaza, asphalt yard, dirt lot.
Plan.lots = {
	{ id = "university", x0 = -252, x1 = 68, z0 = -244, z1 = -26, surface = "plaza" },
	{ id = "station", x0 = 120, x1 = 232, z0 = -244, z1 = -26, surface = "plaza" },
	{ id = "south", x0 = -252, x1 = 68, z0 = 26, z1 = 202, surface = "asphalt" },
	{ id = "southeast", x0 = 120, x1 = 232, z0 = 26, z1 = 202, surface = "asphalt" },
}

---------------------------------------------------------------------------------------------------
-- University (north of the avenue)
---------------------------------------------------------------------------------------------------
Plan.quad = { x0 = -162, x1 = -8, z0 = -172, z1 = -38, cx = -85, cz = -105 }
Plan.fountain = { x = -85, z = -105, r = 8.5 }
Plan.lawns = {
	{ x0 = -154, x1 = -92, z0 = -164, z1 = -112 },
	{ x0 = -78, x1 = -16, z0 = -164, z1 = -112 },
	{ x0 = -154, x1 = -92, z0 = -98, z1 = -46 },
	{ x0 = -78, x1 = -16, z0 = -98, z1 = -46 },
}
-- Buildings: footprint (x0..x1, z0..z1), height, and the direction the front faces.
Plan.halvorsen = { x0 = -240, x1 = -172, z0 = -178, z1 = -32, h = 44, front = "E", doorZ = -105 }
Plan.careerCenter = { x0 = -140, x1 = -30, z0 = -234, z1 = -182, h = 30, front = "S", doorX = -85 }
Plan.dorm = { x0 = 2, x1 = 62, z0 = -170, z1 = -40, h = 56, front = "W", doorZ = -105 }
-- The quad's iron fence along the avenue and its openings (x centre, width)
Plan.quadFence =
	{ z = -30, x0 = -172, x1 = 62, gates = { { x = -85, w = 16 }, { x = -167, w = 10 }, { x = -3, w = 10 } } }

---------------------------------------------------------------------------------------------------
-- The commercial strip (south side of the avenue; storefronts face north at z = 26)
---------------------------------------------------------------------------------------------------
Plan.STRIP_Z = 26
Plan.strip = {
	diner = { x0 = -150, x1 = -110, d = 40, h = 17 },
	laundromat = { x0 = -110, x1 = -80, d = 58, h = 43 },
	pawn = { x0 = -80, x1 = -56, d = 58, h = 39 },
	-- alley x -56 .. -44
	grind = { x0 = -44, x1 = -14, d = 58, h = 31 },
	vacant = { x0 = -14, x1 = 18, d = 58, h = 57 },
	coop = { x0 = 18, x1 = 68, d = 58, h = 29 },
}
Plan.alley = { x0 = -56, x1 = -44 }
Plan.backAlley = { x0 = -150, x1 = 68, z0 = 84, z1 = 98 }
-- The Co-op's walk-in shop (local to the building footprint)
Plan.coopShop = { x0 = 22, x1 = 54, z0 = 27, z1 = 52, h = 12, doorX = 38 }

---------------------------------------------------------------------------------------------------
-- Bus depot (south-west), with the spawn on the boarding island
---------------------------------------------------------------------------------------------------
Plan.depot = {
	yard = { x0 = -250, x1 = -150, z0 = 26, z1 = 140 },
	canopy = { x0 = -246, x1 = -164, z0 = 40, z1 = 96, y = 17 },
	island = { x0 = -240, x1 = -170, z0 = 60, z1 = 76, top = 1.0 },
	busZ = 52, -- bay 1 centreline (the bus faces east)
	busX = -216,
	building = { x0 = -244, x1 = -178, z0 = 106, z1 = 136, h = 18 },
	garage = { x0 = -250, x1 = -152, z0 = 146, z1 = 198, h = 26 },
	spawn = { x = -214, z = 68 },
}

---------------------------------------------------------------------------------------------------
-- Construction lot (behind the strip)
---------------------------------------------------------------------------------------------------
Plan.lot = { x0 = -146, x1 = 60, z0 = 102, z1 = 194, gapX = 40 } -- gapX: a sagging fence bay you can slip through

---------------------------------------------------------------------------------------------------
-- East of Mill Street: the elevated line, Eastbridge Station, storage, the court and the river
---------------------------------------------------------------------------------------------------
Plan.viaduct = { x0 = 124, x1 = 398, z0 = -100, z1 = -72, bottom = 22, top = 25.5, bents = 32, trackZ = -92 }
Plan.platform = { x0 = 132, x1 = 214, z0 = -84, z1 = -73, top = 28.5 }
Plan.station = { x0 = 128, x1 = 188, z0 = -112, z1 = -60, h = 18, doorX = 158, hall = { x0 = 142, x1 = 174, z0 = -78 } }
Plan.stationPlaza = { x0 = 120, x1 = 210, z0 = -60, z1 = -26 }
Plan.storage = { x0 = 132, x1 = 228, z0 = -234, z1 = -134, h = 22 }
Plan.hardware = { x0 = 120, x1 = 168, z0 = 26, z1 = 80, h = 42 }
Plan.court = { x0 = 176, x1 = 226, z0 = 30, z1 = 84 }
Plan.parking = { x0 = 120, x1 = 226, z0 = 90, z1 = 196 }
Plan.river = { x0 = 232, x1 = 398, surface = -6 }
Plan.overlook = { x0 = 212, x1 = 232, z0 = -26, z1 = 26 }

---------------------------------------------------------------------------------------------------
-- Markers (Config/World: campus anchors, doors, NPC spots, event spots, interacts)
---------------------------------------------------------------------------------------------------
local W = Plan.WALK
Plan.anchors = {
	campus_spawn = Plan.cf(Plan.depot.spawn.x, Plan.depot.island.top + 3, Plan.depot.spawn.z, Plan.E),
	campus_station_platform = Plan.cf(158, W + 3, -68, Plan.S),
	campus_career_center_front = Plan.cf(-85, W + 3, -168, Plan.S),
	campus_lecture_front = Plan.cf(-158, W + 3, -105, Plan.E),
	campus_dorm_front = Plan.cf(-12, W + 3, -105, Plan.W),
	campus_quad = Plan.cf(-85, W + 3, -82, Plan.N),
} :: { [string]: CFrame }

Plan.npcs = {
	npc_bus_driver = Plan.facing(-200, Plan.depot.island.top + 3, 63, Plan.depot.spawn.x, Plan.depot.spawn.z),
	npc_barista = Plan.cf(-29, W + 3, 31.5, Plan.N),
	npc_alum = Plan.facing(-66, W + 3, -92, -85, -82),
} :: { [string]: CFrame }

Plan.events = {
	recruiting_booths = { cf = Plan.cf(-85, W + 0.5, -166), size = Vector3.new(60, 1, 10) },
	muster_campus = { cf = Plan.cf(-123, Plan.LAWN + 0.5, -72), size = Vector3.new(24, 1, 24) },
	pigeon_area_campus = { cf = Plan.cf(-85, W + 0.5, -70), size = Vector3.new(12, 1, 40) },
	briefcase_c1 = { cf = Plan.cf(-50.5, W + 0.5, 95.5), size = Vector3.new(2, 1, 2) },
	briefcase_c2 = { cf = Plan.cf(-36, W + 0.5, 152), size = Vector3.new(2, 1, 2) },
} :: { [string]: { cf: CFrame, size: Vector3 } }

return Plan
