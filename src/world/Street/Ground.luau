--!strict
-- The Street's ground: one asphalt slab under the whole region, raised sidewalk slabs for every block (the centre
-- block is the granite Exchange Plaza), granite curbs with a darker paver strip where lamps and trees stand, lane
-- markings (double yellow centre lines, dashed lane lines, stop bars), zebra crosswalks at every intersection,
-- manholes, and the invisible boundary walls that keep players inside the district. Bake-safe.
--
--   Ground.build(parent) -> Model

local Deps = require(script.Parent.Deps)
local Look = require(script.Parent.Look)
local Plan = require(script.Parent.Plan)

local Kit = Deps.Kit
local Props = Deps.Props
local M = Enum.Material

local Ground = {}

local FLOOR = Plan.FLOOR
local ROAD = Plan.ROAD_TOP

local function paint(parent: Instance, x: number, z: number, sx: number, sz: number, color: Color3): Part
	local p = Kit.detail(parent, CFrame.new(x, ROAD + 0.01, z), Vector3.new(sx, 0.04, sz), color, M.SmoothPlastic)
	p.CastShadow = false
	return p
end

-- Road segments between intersections (along the road axis), trimmed back from the cross streets so the
-- markings stop before the crosswalks and stop bars.
local function segments(road: Plan.Road): { { number } }
	local cuts: { { number } } = {}
	for _, r in Plan.roads do
		if r.axis ~= road.axis then
			table.insert(cuts, { r.c - r.w / 2 - Plan.SIDEWALK - 3, r.c + r.w / 2 + Plan.SIDEWALK + 3 })
		end
	end
	table.sort(cuts, function(a, b)
		return a[1] < b[1]
	end)
	local out: { { number } } = {}
	local cursor = -Plan.HALF
	for _, c in cuts do
		table.insert(out, { cursor, c[1] })
		cursor = c[2]
	end
	table.insert(out, { cursor, Plan.HALF })
	return out
end

local function along(road: Plan.Road, a: number, across: number): (number, number)
	if road.axis == "x" then
		return a, road.c + across
	end
	return road.c + across, a
end

local function stripe(
	parent: Instance,
	road: Plan.Road,
	a0: number,
	a1: number,
	across: number,
	w: number,
	color: Color3
)
	local len = a1 - a0
	if len <= 0.5 then
		return
	end
	local x, z = along(road, (a0 + a1) / 2, across)
	if road.axis == "x" then
		paint(parent, x, z, len, w, color)
	else
		paint(parent, x, z, w, len, color)
	end
end

local function markings(parent: Instance)
	local m = Kit.model(parent, "Markings")
	for _, road in Plan.roads do
		for _, seg in segments(road) do
			local a0, a1 = seg[1], seg[2]
			-- double yellow centre line
			stripe(m, road, a0, a1, -0.4, 0.3, Look.lineYellow)
			stripe(m, road, a0, a1, 0.4, 0.3, Look.lineYellow)
			if road.lanes >= 4 then
				-- dashed lane lines, 10 on / 20 off
				for _, off in { -road.w / 4, road.w / 4 } do
					local a = a0 + 6
					while a + 10 <= a1 - 4 do
						stripe(m, road, a, a + 10, off, 0.35, Look.line)
						a += 30
					end
				end
			else
				-- parking-lane edge lines on the cross streets
				for _, off in { -(road.w / 2 - 4), road.w / 2 - 4 } do
					stripe(m, road, a0, a1, off, 0.3, Look.line)
				end
			end
		end
	end
	-- crosswalks and stop bars at every intersection
	for _, it in Plan.intersections() do
		local ew, ns = it.ew, it.ns
		local sideX = ns.w / 2 + Plan.SIDEWALK / 2
		local sideZ = ew.w / 2 + Plan.SIDEWALK / 2
		for _, sx in { -1, 1 } do
			-- across the avenue (pedestrians walk north-south), in line with the cross street's sidewalks
			Props.build(
				"crosswalk",
				m,
				CFrame.new(it.x + sx * sideX, ROAD, it.z) * Kit.rotY(90),
				{ length = ew.w - 2, width = 10, seed = "xw-ew" .. it.x .. it.z .. sx }
			)
			-- stop bar for traffic arriving on this side: eastbound (south lanes) from the west, westbound
			-- (north lanes) from the east
			local barX = it.x + sx * (ns.w / 2 + Plan.SIDEWALK + 1.5)
			local laneZ = it.z - sx * ew.w / 4
			paint(m, barX, laneZ, 1.2, ew.w / 2 - 1.5, Look.line)
		end
		for _, sz in { -1, 1 } do
			Props.build(
				"crosswalk",
				m,
				CFrame.new(it.x, ROAD, it.z + sz * sideZ),
				{ length = ns.w - 2, width = 10, seed = "xw-ns" .. it.x .. it.z .. sz }
			)
			-- northbound traffic (east lane) stops south of the crossing, southbound (west lane) north of it
			local barZ = it.z + sz * (ew.w / 2 + Plan.SIDEWALK + 1.5)
			local laneX = it.x + sz * ns.w / 4
			paint(m, laneX, barZ, ns.w / 2 - 1.5, 1.2, Look.line)
		end
	end
	return m
end

-- Which sides of a ground slab face a road (inside the boundary): those get curbs and a paver strip.
local function roadSides(x0: number, x1: number, z0: number, z1: number): { { string } }
	local out = {}
	for _, r in Plan.roads do
		local lo, hi = r.c - r.w / 2, r.c + r.w / 2
		if r.axis == "x" then
			if math.abs(z1 - lo) < 0.01 then
				table.insert(out, { "z1" })
			elseif math.abs(z0 - hi) < 0.01 then
				table.insert(out, { "z0" })
			end
		else
			if math.abs(x1 - lo) < 0.01 then
				table.insert(out, { "x1" })
			elseif math.abs(x0 - hi) < 0.01 then
				table.insert(out, { "x0" })
			end
		end
	end
	return out
end

local function curb(parent: Instance, x0: number, x1: number, z0: number, z1: number, side: string)
	local W = Plan.WALL
	-- curbs stop at the boundary walls: nobody sees past them up close
	local cx0, cx1 = math.max(x0, -W - 4), math.min(x1, W + 4)
	local cz0, cz1 = math.max(z0, -W - 4), math.min(z1, W + 4)
	local h = 0.56
	local strip = 3.2
	-- strips along X and along Z overlap at the block corners: lift one set a hair so their tops never coincide
	local lift = if side == "x0" or side == "x1" then 0.006 else 0
	local y = FLOOR + 0.02 + lift - h / 2
	if side == "z0" or side == "z1" then
		local z = if side == "z0" then z0 + 0.47 else z1 - 0.47
		local zs = if side == "z0" then z0 + 1 + strip / 2 else z1 - 1 - strip / 2
		local len = cx1 - cx0
		Kit.detail(parent, CFrame.new((cx0 + cx1) / 2, y, z), Vector3.new(len, h, 1), Look.graniteLight, M.Granite).Name =
			"Curb"
		Kit.detail(
			parent,
			CFrame.new((cx0 + cx1) / 2, FLOOR + 0.005, zs),
			Vector3.new(len, 0.03, strip),
			Look.plazaDark,
			M.Slate
		).Name =
			"Pavers"
	else
		local x = if side == "x0" then x0 + 0.47 else x1 - 0.47
		local xs = if side == "x0" then x0 + 1 + strip / 2 else x1 - 1 - strip / 2
		local len = cz1 - cz0
		Kit.detail(parent, CFrame.new(x, y, (cz0 + cz1) / 2), Vector3.new(1, h, len), Look.graniteLight, M.Granite).Name =
			"Curb"
		Kit.detail(
			parent,
			CFrame.new(xs, FLOOR + 0.005 + lift, (cz0 + cz1) / 2),
			Vector3.new(strip, 0.03, len),
			Look.plazaDark,
			M.Slate
		).Name =
			"Pavers"
	end
end

local function slabs(parent: Instance)
	local m = Kit.model(parent, "Blocks")
	for ri, row in Plan.groundRows do
		for ci, col in Plan.groundCols do
			local x0, x1, z0, z1 = col[1], col[2], row[1], row[2]
			local plaza = ri == 2 and ci == 2
			local slab = Kit.block(
				m,
				CFrame.new((x0 + x1) / 2, FLOOR - 0.5, (z0 + z1) / 2),
				Vector3.new(x1 - x0, 1, z1 - z0),
				if plaza then Look.plaza else Look.sidewalk,
				if plaza then M.Pavement else M.Concrete
			)
			slab.Name = if plaza then "PlazaSlab" else "Sidewalk"
			for _, s in roadSides(x0, x1, z0, z1) do
				curb(m, x0, x1, z0, z1, s[1])
			end
		end
	end
	return m
end

local function boundary(parent: Instance)
	local m = Kit.model(parent, "Boundary")
	local W = Plan.WALL
	local H = 320
	local function wall(cf: CFrame, size: Vector3)
		local p = Kit.block(m, cf, size, Look.white, M.SmoothPlastic, {
			Transparency = 1,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		p.Name = "InvisibleWall"
	end
	wall(CFrame.new(0, H / 2, -W - 0.5), Vector3.new(2 * W + 2, H, 1))
	wall(CFrame.new(0, H / 2, W + 0.5), Vector3.new(2 * W + 2, H, 1))
	wall(CFrame.new(-W - 0.5, H / 2, 0), Vector3.new(1, H, 2 * W + 2))
	wall(CFrame.new(W + 0.5, H / 2, 0), Vector3.new(1, H, 2 * W + 2))
	return m
end

function Ground.build(parent: Instance): Model
	local m = Kit.model(parent, "Ground")
	local asphalt =
		Kit.block(m, CFrame.new(0, ROAD - 1, 0), Vector3.new(Plan.HALF * 2, 2, Plan.HALF * 2), Look.asphalt, M.Asphalt)
	asphalt.Name = "Asphalt"
	slabs(m)
	markings(m)
	for i, pos in Plan.manholes do
		Props.build("manhole", m, CFrame.new(pos.X, ROAD, pos.Z) * Kit.rotY(i * 37), { seed = "manhole" .. i })
	end
	boundary(m)
	return m
end

return Ground
