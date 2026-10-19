--!strict
-- The Street's layout (all numbers in studs, world space; region "street" is x/z in [-450, 450], y in [-40, 700]).
--
-- A tight grid: two avenues run east-west (Bank Row at z = -140, Exchange Avenue at z = 150) and two cross streets
-- run north-south (Ledger Street at x = -200, Charter Street at x = 200). They cut the district into nine blocks.
-- The centre block is Exchange Plaza (the fountain, The Contest, the ten leaderboard monoliths and the subway), with
-- Career Services on its west side and the Galleria on its east side. Bank Row's north side is the canyon of the four
-- bulge-bracket towers; the elite boutiques face them across the avenue; the Metropolitan Exchange closes the plaza's
-- axis from the south. A ring of backdrop towers (|x| or |z| beyond EDGE) hides the region edge and invisible walls
-- keep players inside.
--
-- Lots are described by the side their front faces ("N" = -Z, "S" = +Z, "E" = +X, "W" = -X), the building line the
-- front sits on, the centre along that line, frontage width w, depth d and height h. Plan.frame turns that into the
-- lot frame: origin at the front-centre on the sidewalk (y = FLOOR), LookVector out of the building (toward the
-- street), local +Z into the building. Every World.towers id has a lot here; towers added to Config/World later take
-- the next spare lot (Plan.lotFor), so new tracks plug in without touching this file.

local Plan = {}

Plan.FLOOR = 0.6 -- sidewalk, plaza and lobby floor height (road top is ROAD_TOP)
Plan.ROAD_TOP = 0.1
Plan.SIDEWALK = 14
Plan.EDGE = 404 -- blocks end here; the backdrop ring stands beyond
Plan.WALL = 401 -- invisible boundary walls
Plan.HALF = 450 -- region half-size
Plan.STOREY = 15

export type Road = { id: string, axis: string, c: number, w: number, lanes: number, name: string }
export type Lot = {
	face: string,
	line: number,
	at: number,
	w: number,
	d: number,
	h: number,
	variant: number?,
	shops: { string }?,
}
export type Filler = {
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	h: number,
	look: string,
	front: string?, -- side with a street-level storefront ("N" | "S" | "E" | "W")
	shops: { string }?, -- Text keys for the storefront signs
	seed: string,
}

---------------------------------------------------------------------------------------------------
-- Roads
---------------------------------------------------------------------------------------------------
Plan.roads = {
	{ id = "bank_row", axis = "x", c = -140, w = 40, lanes = 4, name = "road_bank_row" },
	{ id = "exchange_ave", axis = "x", c = 150, w = 40, lanes = 4, name = "road_exchange_ave" },
	{ id = "ledger_st", axis = "z", c = -200, w = 30, lanes = 2, name = "road_ledger_st" },
	{ id = "charter_st", axis = "z", c = 200, w = 30, lanes = 2, name = "road_charter_st" },
} :: { Road }

function Plan.road(id: string): Road
	for _, r in Plan.roads do
		if r.id == id then
			return r
		end
	end
	error("Street.Plan: unknown road " .. id)
end

-- Intervals between the roads of the other axis: the block columns (for "x") or rows (for "z").
local function intervals(crossAxis: string, limit: number?): { { number } }
	local edge = limit or Plan.EDGE
	local cuts: { { number } } = {}
	for _, r in Plan.roads do
		if r.axis == crossAxis then
			table.insert(cuts, { r.c - r.w / 2, r.c + r.w / 2 })
		end
	end
	table.sort(cuts, function(a, b)
		return a[1] < b[1]
	end)
	local out: { { number } } = {}
	local cursor = -edge
	for _, c in cuts do
		table.insert(out, { cursor, c[1] })
		cursor = c[2]
	end
	table.insert(out, { cursor, edge })
	return out
end

-- Block columns along X (between the north-south roads) and rows along Z (between the east-west roads).
Plan.cols = intervals("z") -- N-S roads cut X
Plan.rows = intervals("x") -- E-W roads cut Z
-- The same cut out to the region edge: the ground slabs run under the backdrop ring.
Plan.groundCols = intervals("z", Plan.HALF)
Plan.groundRows = intervals("x", Plan.HALF)

Plan.COL_IDS = { "W", "C", "E" }
Plan.ROW_IDS = { "N", "M", "S" }

export type Block = { id: string, x0: number, x1: number, z0: number, z1: number, plaza: boolean }

function Plan.blocks(): { Block }
	local out: { Block } = {}
	for ri, row in Plan.rows do
		for ci, col in Plan.cols do
			local id = (Plan.ROW_IDS[ri] or tostring(ri)) .. (Plan.COL_IDS[ci] or tostring(ci))
			table.insert(out, { id = id, x0 = col[1], x1 = col[2], z0 = row[1], z1 = row[2], plaza = id == "MC" })
		end
	end
	return out
end

-- Intersections: the asphalt squares where an E-W road crosses a N-S road.
function Plan.intersections(): { { x: number, z: number, ew: Road, ns: Road } }
	local out = {}
	for _, ew in Plan.roads do
		if ew.axis == "x" then
			for _, ns in Plan.roads do
				if ns.axis == "z" then
					table.insert(out, { x = ns.c, z = ew.c, ew = ew, ns = ns })
				end
			end
		end
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Lot frames
---------------------------------------------------------------------------------------------------
local FACE_DIR: { [string]: Vector3 } = {
	N = Vector3.new(0, 0, -1),
	S = Vector3.new(0, 0, 1),
	E = Vector3.new(1, 0, 0),
	W = Vector3.new(-1, 0, 0),
}
Plan.FACE_DIR = FACE_DIR

function Plan.frame(face: string, line: number, at: number, y: number?): CFrame
	local dir: Vector3? = FACE_DIR[face]
	if not dir then
		error("Street.Plan: bad face " .. tostring(face))
	end
	local yy = y or Plan.FLOOR
	local pos = if face == "N" or face == "S" then Vector3.new(at, yy, line) else Vector3.new(line, yy, at)
	return CFrame.lookAt(pos, pos + dir)
end

function Plan.lotFrame(lot: Lot): CFrame
	return Plan.frame(lot.face, lot.line, lot.at)
end

-- World-space axis-aligned rectangle a lot covers (x0, z0, x1, z1).
function Plan.lotRect(lot: Lot): (number, number, number, number)
	local hw = lot.w / 2
	if lot.face == "S" then
		return lot.at - hw, lot.line - lot.d, lot.at + hw, lot.line
	elseif lot.face == "N" then
		return lot.at - hw, lot.line, lot.at + hw, lot.line + lot.d
	elseif lot.face == "E" then
		return lot.line - lot.d, lot.at - hw, lot.line, lot.at + hw
	end
	return lot.line, lot.at - hw, lot.line + lot.d, lot.at + hw
end

---------------------------------------------------------------------------------------------------
-- Company towers (World.towers ids). Bank Row: the bulge brackets on the north side (z = -174 building line,
-- facing south), the elite boutiques on the south side (z = -106, facing north).
---------------------------------------------------------------------------------------------------
Plan.towerLots = {
	mg_freeman = { face = "S", line = -174, at = 0, w = 100, d = 96, h = 620, variant = 1 },
	goldfield_saxe = { face = "S", line = -174, at = -122.5, w = 97, d = 90, h = 540, variant = 2 },
	morrow_stanton = { face = "S", line = -174, at = 122.5, w = 97, d = 90, h = 570, variant = 3 },
	merriweather_lynch = { face = "S", line = -174, at = -277, w = 96, d = 90, h = 500, variant = 4 },
	funds_tower = { face = "S", line = -174, at = 274, w = 90, d = 86, h = 440, variant = 1 },
	evermoor = { face = "N", line = -106, at = -350, w = 70, d = 70, h = 270, variant = 1 },
	lazaro_freres = { face = "N", line = -106, at = -264, w = 70, d = 70, h = 240, variant = 2 },
	centerline = { face = "N", line = -106, at = 350, w = 70, d = 70, h = 290, variant = 3 },
	sterling_vance = { face = "S", line = 116, at = -259, w = 60, d = 66, h = 170, variant = 1 },
	middle_market = { face = "S", line = 116, at = -345, w = 80, d = 66, h = 330, variant = 1 },
	anaeio = { face = "N", line = 184, at = -137, w = 68, d = 70, h = 410, variant = 1 },
	applewood = { face = "N", line = 184, at = 137, w = 68, d = 70, h = 340, variant = 1 },
	wealth_house = { face = "N", line = 184, at = -252, w = 46, d = 50, h = 72, variant = 1 },
	venture_row = { face = "N", line = 184, at = -322, w = 60, d = 56, h = 86, variant = 1 },
	property_exchange = { face = "E", line = -229, at = 300, w = 60, d = 60, h = 150, variant = 1 },
	pe_tower = { face = "N", line = 184, at = 264, w = 70, d = 70, h = 300, variant = 1 },
} :: { [string]: Lot }

-- Spare lots: built as filler towers unless a tower that has no lot above claims them (in order).
Plan.spareLots = {
	{ face = "N", line = 184, at = 358, w = 92, d = 80, h = 320, variant = 2, shops = { "shop_bistro" } },
	{
		face = "S",
		line = -174,
		at = -364.5,
		w = 79,
		d = 80,
		h = 380,
		variant = 2,
		shops = { "shop_bank", "shop_cafe" },
	},
	{ face = "S", line = -174, at = 361.5, w = 85, d = 80, h = 360, variant = 3, shops = { "shop_deli", "shop_wine" } },
} :: { Lot }

-- The lot for a tower, or nil. Unknown towers take spare lots in World.towers order.
function Plan.assignLots(towers: { any }): ({ [string]: Lot }, { Lot })
	local out: { [string]: Lot } = {}
	local spare = table.clone(Plan.spareLots)
	for _, t in towers do
		local id = t.id :: string
		local lot = Plan.towerLots[id]
		if lot then
			out[id] = lot
		elseif #spare > 0 then
			out[id] = table.remove(spare, 1) :: Lot
		end
	end
	return out, spare
end

---------------------------------------------------------------------------------------------------
-- Venues (doors door_street_<id>, anchors street_<anchor>_front)
---------------------------------------------------------------------------------------------------
Plan.venueLots = {
	career_services = { face = "E", line = -121, at = 0, w = 110, d = 50, h = 64 },
	galleria = { face = "W", line = 121, at = 0, w = 130, d = 50, h = 72 },
	club = { face = "N", line = -106, at = 261, w = 64, d = 60, h = 62 },
	apartments = { face = "S", line = 116, at = 264, w = 70, d = 66, h = 300 },
	rooftop = { face = "S", line = 116, at = 349, w = 66, d = 66, h = 380 },
} :: { [string]: Lot }

---------------------------------------------------------------------------------------------------
-- Infill buildings inside the blocks (behind and between the lots) so every block reads as solid city fabric.
-- Rectangles may overlap lots (hidden) but never leave slivers players could get stuck in.
---------------------------------------------------------------------------------------------------
Plan.fillers = {
	-- NW (the spare lot fronts Bank Row west of Merriweather Lynch)
	{ x0 = -404, z0 = -404, x1 = -325, z1 = -254, h = 260, look = "limestone", seed = "nw-a" },
	{ x0 = -325, z0 = -404, x1 = -229, z1 = -264, h = 210, look = "glass", front = "E", seed = "nw-b" },
	-- NC (behind the bulge towers)
	{ x0 = -171, z0 = -404, x1 = -40, z1 = -262, h = 330, look = "glassDark", seed = "nc-a" },
	{ x0 = -40, z0 = -404, x1 = 171, z1 = -262, h = 290, look = "limestone", seed = "nc-b" },
	-- NE (the spare lot fronts Bank Row east of the Funds & Credit Tower)
	{ x0 = 319, z0 = -404, x1 = 404, z1 = -254, h = 280, look = "brick", seed = "ne-a" },
	{ x0 = 229, z0 = -404, x1 = 319, z1 = -258, h = 220, look = "glass", front = "W", seed = "ne-b" },
	-- MW
	{
		x0 = -309,
		z0 = -36,
		x1 = -229,
		z1 = 50,
		h = 110,
		look = "limestoneWarm",
		front = "E",
		shops = { "shop_cafe", "shop_pharmacy" },
		seed = "mw-a",
	},
	{ x0 = -404, z0 = -36, x1 = -309, z1 = 50, h = 150, look = "brick", seed = "mw-b" },
	{ x0 = -404, z0 = -106, x1 = -385, z1 = 116, h = 190, look = "limestone", seed = "mw-c" },
	-- ME
	{
		x0 = 229,
		z0 = -46,
		x1 = 309,
		z1 = 50,
		h = 120,
		look = "sandstone",
		front = "W",
		shops = { "shop_bistro", "shop_florist" },
		seed = "me-a",
	},
	{ x0 = 309, z0 = -36, x1 = 404, z1 = 50, h = 160, look = "glassDark", seed = "me-b" },
	{ x0 = 382, z0 = -106, x1 = 404, z1 = 116, h = 200, look = "limestone", seed = "me-c" },
	-- SW
	{ x0 = -404, z0 = 184, x1 = -352, z1 = 262, h = 200, look = "limestone", seed = "sw-a" },
	{
		x0 = -289,
		z0 = 234,
		x1 = -229,
		z1 = 270,
		h = 60,
		look = "brownstone",
		front = "E",
		shops = { "shop_books" },
		seed = "sw-b",
	},
	{
		x0 = -309,
		z0 = 330,
		x1 = -229,
		z1 = 404,
		h = 220,
		look = "glass",
		front = "E",
		shops = { "shop_watch" },
		seed = "sw-c",
	},
	{ x0 = -404, z0 = 234, x1 = -286, z1 = 404, h = 260, look = "glassDark", seed = "sw-d" },
	-- SC
	{ x0 = -171, z0 = 254, x1 = -90, z1 = 404, h = 190, look = "limestone", front = "W", seed = "sc-a" },
	{ x0 = 90, z0 = 254, x1 = 171, z1 = 404, h = 210, look = "glass", front = "E", seed = "sc-b" },
	{ x0 = -90, z0 = 306, x1 = 90, z1 = 404, h = 150, look = "limestoneWarm", seed = "sc-c" },
	-- SE
	{ x0 = 229, z0 = 254, x1 = 404, z1 = 404, h = 240, look = "brick", front = "W", seed = "se-a" },
} :: { Filler }

---------------------------------------------------------------------------------------------------
-- Exchange Plaza (the centre block) and the Metropolitan Exchange
---------------------------------------------------------------------------------------------------
Plan.exchange = { face = "N", line = 184, at = 0, w = 180, d = 122, h = 104 } :: Lot

Plan.plaza = {
	x0 = -121,
	x1 = 121,
	z0 = -106,
	z1 = 116,
	anchor = Vector3.new(0, 0, 12), -- street_plaza (faces north toward the fountain and The Contest)
	fountain = Vector3.new(0, 0, -26),
	statue = Vector3.new(0, 0, -84),
	flags = { Vector3.new(-48, 0, -100), Vector3.new(0, 0, -101), Vector3.new(48, 0, -100) },
	boardX = 64, -- monolith rows at x = +/-64
	boardZ = { -52, -26, 0, 26, 52 },
	runway = { z = 78, x0 = -46, x1 = 46, w = 8 },
	muster = Vector3.new(-90, 0, -78),
	pigeons = Vector3.new(34, 0, 30),
}

-- The ten leaderboard monoliths (v3 §17), west row first (north to south), then east row.
Plan.boards = {
	"CareerPrestige",
	"MarketSkill",
	"DealMastery",
	"FastestRun",
	"Comeback",
	"TopStats",
	"Rebirths",
	"TimePlayed",
	"LiveInvested",
	"RobuxSpent",
}

---------------------------------------------------------------------------------------------------
-- Street life placements (world space; y = 0 means "on the floor")
---------------------------------------------------------------------------------------------------
Plan.subway = { pos = Vector3.new(-100, 0, 94), face = "N" } -- the stair opening faces north onto the plaza
-- street_station_platform + Spawn_street (facing north), far enough from the stair-top door trigger that the
-- "Subway" prompt is not already showing when a player arrives.
Plan.station = Vector3.new(-100, 0, 72)
Plan.newsstand = { pos = Vector3.new(-62, 0, 104), face = "N" }
Plan.storeKiosk = { pos = Vector3.new(-80, 0, 64), face = "E" }
Plan.directories = {
	{ pos = Vector3.new(-80, 0, 86), face = "N" }, -- by the subway exit
	{ pos = Vector3.new(40, 0, -112), face = "N" }, -- Bank Row sidewalk, across from the towers
}
Plan.foodCarts = {
	{ pos = Vector3.new(98, 0, 90), face = "W", variant = "coffee" },
	{ pos = Vector3.new(-58, 0, -113), face = "S", variant = "hotdog" },
	{ pos = Vector3.new(64, 0, 123), face = "N", variant = "pretzel" },
}
Plan.bikeDock = { pos = Vector3.new(-178, 0, 86), face = "E" }
Plan.phoneBooth = { pos = Vector3.new(-150, 0, 123), face = "N" }
Plan.busStop = { pos = Vector3.new(-318, 0, 122.5), face = "S" } -- glass shelter facing Exchange Ave, by the bus
-- A sidewalk shed against the Ledger St infill (x = -229), north of its shop row (no awnings under it).
Plan.scaffold = { pos = Vector3.new(-226.5, 0, 42.6), face = "E" }
Plan.streetClock = Vector3.new(-112, 0, -113)
Plan.atms = {
	{ pos = Vector3.new(-372, 0, -167), face = "S" },
	{ pos = Vector3.new(-262, 0, 123), face = "N" },
}
-- Striped steam stacks standing in a traffic lane (lane centres, clear of the parked and waiting cars).
Plan.steamVents = {
	Vector3.new(-62, 0, -145),
	Vector3.new(92, 0, 135),
	Vector3.new(-192.5, 0, -42),
	Vector3.new(207.5, 0, 38),
	Vector3.new(300, 0, -125),
}
Plan.manholes = {
	Vector3.new(160, 0, -146),
	Vector3.new(-300, 0, 156),
	Vector3.new(-200, 0, 250),
	Vector3.new(200, 0, -300),
}
-- Rooftop billboards stand on the cornice slab of their building (roof height + 1.4).
Plan.billboards = {
	{ pos = Vector3.new(-280, 111.4, 7), face = "E", brand = "billboard_brand", slogan = "billboard_slogan" },
	{ pos = Vector3.new(269, 121.4, 2), face = "W", brand = "billboard_brand2", slogan = "billboard_slogan2" },
}

-- Vehicles: lane centres. Right-hand traffic: eastbound uses the south lanes of an E-W road, northbound the east
-- lane of a N-S road.
Plan.vehicles = {
	{ id = "town_car", pos = Vector3.new(26, 0, -155), dir = "W" }, -- waiting at MG Freeman
	{ id = "town_car", pos = Vector3.new(-104, 0, -155), dir = "W" }, -- Goldfield Saxe
	{ id = "taxi", pos = Vector3.new(-160, 0, -125), dir = "E" },
	{ id = "taxi", pos = Vector3.new(252, 0, -145), dir = "W" },
	{ id = "sedan", pos = Vector3.new(120, 0, -125), dir = "E" },
	{ id = "town_car", pos = Vector3.new(34, 0, 165), dir = "E" }, -- at the Exchange
	{ id = "taxi", pos = Vector3.new(-56, 0, 155), dir = "E" },
	{ id = "taxi", pos = Vector3.new(282, 0, 135), dir = "W" }, -- dropping off at The Ashford
	{ id = "city_bus", pos = Vector3.new(-330, 0, 135), dir = "W" },
	{ id = "taxi", pos = Vector3.new(-192.5, 0, 46), dir = "N" },
	{ id = "taxi", pos = Vector3.new(192.5, 0, 70), dir = "S" },
	{ id = "sedan", pos = Vector3.new(207.5, 0, -66), dir = "N" },
	{ id = "sedan", pos = Vector3.new(-207.5, 0, 300), dir = "S" },
}

-- Golden Briefcase hiding spots (events) and other street event spots.
Plan.briefcases = {
	briefcase_s1 = Vector3.new(-62, 0, 111), -- behind the newsstand
	briefcase_s2 = Vector3.new(-225.5, 0, 40), -- under the sidewalk shed on Ledger St
	briefcase_s3 = Vector3.new(-62, 0, -232), -- the alley between Goldfield Saxe and MG Freeman
	briefcase_s4 = Vector3.new(-96.5, 0, 204), -- beside the Exchange steps
} :: { [string]: Vector3 }

---------------------------------------------------------------------------------------------------
-- Coverage: every building footprint on the plan (lots, venues, the Exchange and the infill), used to decide
-- which facades face open ground (and get windows) and to keep street furniture off buildings.
---------------------------------------------------------------------------------------------------
export type Rect = { x0: number, z0: number, x1: number, z1: number, h: number, id: string }

function Plan.rects(towers: { any }): { Rect }
	local out: { Rect } = {}
	local function addLot(id: string, lot: Lot)
		local x0, z0, x1, z1 = Plan.lotRect(lot)
		table.insert(out, { x0 = x0, z0 = z0, x1 = x1, z1 = z1, h = lot.h, id = id })
	end
	local assigned, spare = Plan.assignLots(towers)
	for id, lot in assigned do
		addLot("tower:" .. id, lot)
	end
	for i, lot in spare do
		addLot("spare:" .. i, lot)
	end
	for id, lot in Plan.venueLots do
		addLot("venue:" .. id, lot)
	end
	addLot("exchange", Plan.exchange)
	for _, f in Plan.fillers do
		table.insert(out, { x0 = f.x0, z0 = f.z0, x1 = f.x1, z1 = f.z1, h = f.h, id = "filler:" .. f.seed })
	end
	return out
end

-- The tallest building covering (x, z), or 0 for open ground. `ignore` skips one rect id (a building testing
-- its own faces).
function Plan.heightAt(rects: { Rect }, x: number, z: number, ignore: string?): number
	local best = 0
	for _, r in rects do
		if r.id ~= ignore and x > r.x0 and x < r.x1 and z > r.z0 and z < r.z1 then
			best = math.max(best, r.h)
		end
	end
	return best
end

function Plan.inRoad(x: number, z: number, margin: number?): boolean
	local m = margin or 0
	for _, r in Plan.roads do
		local v = if r.axis == "x" then z else x
		if math.abs(v - r.c) <= r.w / 2 + m then
			return true
		end
	end
	return false
end

return Plan
