--!strict
-- The edge of the district: a ring of backdrop towers outside the boundary walls (between Plan.EDGE and the region
-- edge) that fills the skyline above the city blocks, a closing building across the far end of every street so
-- avenues read as continuing into the city, and striped barricades with "street closed" boards just inside the
-- boundary walls so the invisible walls never surprise anyone. Backdrop facades only get windows where they rise
-- above the buildings in front of them. Bake-safe.
--
--   Backdrop.build(parent, rects) -> Model

local Deps = require(script.Parent.Deps)
local Look = require(script.Parent.Look)
local Mass = require(script.Parent.Mass)
local Plan = require(script.Parent.Plan)
local Text = require(script.Parent.Text)

local Kit = Deps.Kit
local Rng = Deps.Rng
local Gui = Deps.Gui
local M = Enum.Material

local Backdrop = {}

local RING_LOOKS = { "glassDark", "limestone", "glass", "granite", "glassSilver", "sandstone", "glassBlack" }
local NEAR = Plan.EDGE + 6 -- ring front line (distance from the centre)
local FAR = Plan.HALF - 2

local function box(x0: number, x1: number, z0: number, z1: number, y0: number, y1: number): Mass.Box
	return { x0 = x0, x1 = x1, z0 = z0, z1 = z1, y0 = y0, y1 = y1 }
end

-- Lot frame of a backdrop building on `side` whose front faces the district, centred at `along`.
local function sideFrame(side: string, along: number, line: number): CFrame
	if side == "N" then
		return Plan.frame("S", -line, along)
	elseif side == "S" then
		return Plan.frame("N", line, along)
	elseif side == "W" then
		return Plan.frame("E", -line, along)
	end
	return Plan.frame("W", line, along)
end

-- Height of the city in front of a backdrop front face (sampled just inside the district edge).
local function cityHeight(frame: CFrame, w: number, rects: { Plan.Rect }, depthIn: number): number
	local best = math.huge
	for _, t in { -0.38, 0, 0.38 } do
		local wp = frame:PointToWorldSpace(Vector3.new(w * t, 0, -depthIn))
		local hgt = Plan.heightAt(
			rects,
			math.clamp(wp.X, -Plan.EDGE + 1, Plan.EDGE - 1),
			math.clamp(wp.Z, -Plan.EDGE + 1, Plan.EDGE - 1)
		)
		best = math.min(best, hgt)
	end
	return if best == math.huge then 0 else best
end

-- Road corridors (road plus both sidewalks) crossing a side of the district.
local function corridors(side: string): { { number } }
	local axis = if side == "N" or side == "S" then "z" else "x"
	local out: { { number } } = {}
	for _, r in Plan.roads do
		if r.axis == axis then
			table.insert(out, { r.c - r.w / 2 - Plan.SIDEWALK, r.c + r.w / 2 + Plan.SIDEWALK })
		end
	end
	table.sort(out, function(a, b)
		return a[1] < b[1]
	end)
	return out
end

local function tower(
	parent: Instance,
	frame: CFrame,
	w: number,
	d: number,
	h: number,
	seed: string,
	visibleFrom: number
)
	local rng = Rng.new(seed)
	local look = Mass.vary(Mass.look(RING_LOOKS[rng:int(1, #RING_LOOKS)], { storey = 22, bay = 11, lit = 0.06 }), seed)
	local b = box(-w / 2, w / 2, 0, d, 0, h)
	Mass.tier(parent, frame, b, look, {
		hidden = { front = visibleFrom, left = math.huge, right = math.huge, back = math.huge },
		seed = seed,
		name = "Backdrop",
		noTop = true,
	})
	Mass.cornice(parent, frame, b, h - 0.4, 1.6, 0.6, if look.curtain then Look.steelDark else look.pier, M.Concrete)
	if rng:chance(0.35) then
		Mass.roofKit(parent, frame, b, seed .. ":roof", Look.slate)
	end
end

local function ring(m: Instance, rects: { Plan.Rect })
	local g = Kit.model(m, "Ring")
	for _, side in { "N", "S", "W", "E" } do
		local rng = Rng.new("ring:" .. side)
		local cuts = corridors(side)
		local spans: { { number } } = {}
		-- the north and south rows stop at the corners; the east and west rows cover them
		local reach = if side == "N" or side == "S" then NEAR else Plan.HALF
		local cursor = -reach
		for _, c in cuts do
			table.insert(spans, { cursor, c[1] })
			cursor = c[2]
		end
		table.insert(spans, { cursor, reach })
		for _, span in spans do
			local a = span[1]
			while span[2] - a > 8 do
				local w = math.min(rng:range(55, 105), span[2] - a)
				if span[2] - (a + w) < 20 then
					w = span[2] - a
				end
				local along = a + w / 2
				local depth = rng:range(26, FAR - NEAR)
				local h = rng:range(150, 430)
				local frame = sideFrame(side, along, NEAR)
				local city = cityHeight(frame, w, rects, 10)
				if h > city + 20 then
					tower(g, frame, w, depth, h, ("ring:%s:%d"):format(side, math.floor(along)), city)
				else
					-- hidden behind the city: a plain mass keeps the horizon closed
					Mass.slab(g, frame, box(-w / 2, w / 2, 0, depth, 0, h), Look.slate, M.Concrete).Name =
						"BackdropMass"
				end
				a += w
			end
		end
	end
	return g
end

-- A striped sawhorse barricade (cf = floor point, facing along its LookVector).
local function barricade(parent: Instance, cf: CFrame, width: number, seed: string)
	for _, sx in { -1, 1 } do
		Kit.detail(
			parent,
			cf * CFrame.new(sx * (width / 2 - 0.3), 1.6, 0) * CFrame.Angles(math.rad(14), 0, 0),
			Vector3.new(0.3, 3.3, 0.3),
			Look.white,
			M.SmoothPlastic
		)
		Kit.detail(
			parent,
			cf * CFrame.new(sx * (width / 2 - 0.3), 1.6, 0) * CFrame.Angles(math.rad(-14), 0, 0),
			Vector3.new(0.3, 3.3, 0.3),
			Look.white,
			M.SmoothPlastic
		)
	end
	local board = Kit.block(parent, cf * CFrame.new(0, 2.6, 0), Vector3.new(width, 1, 0.2), Look.white, M.SmoothPlastic)
	board.Name = "Barricade"
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Gui.Core.surface(board, face, { pps = 10, maxDistance = 250 })
		Gui.Core.stripes(Gui.Core.frame(gui, 0, 0, 1, 1, Look.white), { Look.hex("#F28C28"), Look.white }, 8, 45)
	end
	local lamp = Kit.ball(parent, cf * CFrame.new(width / 2 - 0.6, 3.4, 0), 0.6, Look.hex("#FFB547"), M.Neon, {
		CanCollide = false,
		CastShadow = false,
	})
	lamp:AddTag("StreetLight")
	lamp.Name = "Blinker_" .. seed
end

local function roadEnds(m: Instance)
	local g = Kit.model(m, "RoadEnds")
	for _, r in Plan.roads do
		for _, s in { -1, 1 } do
			local half = r.w / 2 + Plan.SIDEWALK
			-- the closing building across the far end
			local side = if r.axis == "x" then (if s < 0 then "W" else "E") else (if s < 0 then "N" else "S")
			local frame = sideFrame(side, r.c, Plan.HALF - 14)
			local seed = ("end:%s:%d"):format(r.id, s)
			local rng = Rng.new(seed)
			local look =
				Mass.vary(Mass.look(RING_LOOKS[rng:int(1, #RING_LOOKS)], { storey = 16, bay = 9, lit = 0.08 }), seed)
			local w = 2 * half + 24
			local h = rng:range(160, 260)
			local b = box(-w / 2, w / 2, 0, 12, 0, h)
			Mass.tier(g, frame, b, look, {
				hidden = { front = 0, left = math.huge, right = math.huge, back = math.huge },
				seed = seed,
				name = "StreetEnd",
				noTop = true,
			})
			Mass.cornice(g, frame, b, h - 0.4, 1.6, 0.8, if look.curtain then Look.steelDark else look.pier, M.Concrete)
			-- barricades across the street just inside the boundary wall, facing into the district
			local wallFrame = sideFrame(side, r.c, Plan.WALL - 2.5)
			local n = 5
			for i = 1, n do
				local x = -half + 2 * half * (i - 0.5) / n
				local ground = if math.abs(x) > r.w / 2 then 0 else Plan.ROAD_TOP - Plan.FLOOR
				barricade(g, wallFrame * CFrame.new(x, ground, -0.5), 2 * half / n - 3, seed .. i)
			end
			local sign = Kit.detail(
				g,
				wallFrame * CFrame.new(0, 4.6, -0.6),
				Vector3.new(10, 2.2, 0.2),
				Look.hex("#F28C28"),
				M.SmoothPlastic
			)
			sign.Name = "StreetClosed"
			Kit.sign(
				sign,
				Text.get("street_closed"),
				{ color = Look.black, font = Enum.Font.GothamBlack, pixelsPerStud = 40 }
			)
		end
	end
	return g
end

function Backdrop.build(parent: Instance, rects: { Plan.Rect }): Model
	local m = Kit.model(parent, "Backdrop")
	m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	ring(m, rects)
	roadEnds(m)
	return m
end

return Backdrop
