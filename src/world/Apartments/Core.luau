--!strict
-- The Ashford Residences' structure: floor slabs, the three corridors with their unit-front walls (door openings),
-- party walls, the corridor finishes and the stair hall (a U-stair per storey: two flights of 8 steps with a landing
-- between them, landings in line with each corridor, a guard rail at the top). Bake-safe.
--
--   Core.build(parent, F, rng) -> ()

local Venue = script.Parent.Parent.CareerServices.Venue
local Deps = require(Venue.Deps)
local Shell = require(Venue.Shell)
local Paint = require(Venue.Paint)
local Text = require(Venue.Text)
local Plan = require(script.Parent.Plan)

local Kit = Deps.Kit
local Core = Deps.Gui.Core
local hex = Deps.Palette.hex
local M = Enum.Material

local Building = {}

local LH = Plan.LEVEL_H
local CH = Plan.CLEAR_H
local TOP = Plan.LEVELS * LH -- underside of the roof slab
local NZ = Plan.BACK_Z + Plan.BACK_T -- outer face of the window walls

local SLAB = hex("#EEEBE4") -- slabs show their underside as the ceiling
local CORRIDOR_WALL = hex("#D8D2C4")
local RUNNER = hex("#2B3A55")
local STONE = hex("#CFC9BC")
local BRASS = hex("#B8933F")
local NAVY = hex("#1B2A44")

local function structure(m: Instance, F: Shell.Frame)
	local s = Kit.model(m, "Structure")
	-- the ground slab under everything, the upper floor slabs (corridors + units) and the roof
	Shell.box(s, F, Plan.LOBBY_X0 - 1, -1, -NZ - 1, Plan.COR_X1 + 1, 0, Plan.LOBBY_Z1 + 1, STONE, M.Concrete).Name =
		"GroundSlab"
	for level = 2, Plan.LEVELS do
		local y = (level - 1) * LH
		Shell.box(s, F, Plan.COR_X0 - 1, y - Plan.SLAB, -NZ, Plan.COR_X1 + 1, y, NZ, SLAB, M.SmoothPlastic).Name =
			"FloorSlab"
		Shell.box(s, F, Plan.NEAR_X0, y - Plan.SLAB, -Plan.STAIR_HALF, Plan.COR_X0, y, Plan.STAIR_HALF, SLAB, M.SmoothPlastic).Name =
			"LandingSlab"
	end
	Shell.box(s, F, Plan.STAIR_X0 - 1, TOP - Plan.SLAB, -NZ, Plan.COR_X1 + 1, TOP, NZ, SLAB, M.SmoothPlastic).Name =
		"Roof"
	-- party walls run the full height (their units' liners cover the faces)
	for i = 0, Plan.PER_SIDE do
		local x = Plan.ROW_X0 + Plan.PITCH * i
		for _, side in { -1, 1 } do
			local z0, z1 = side * Plan.COR_HALF, side * NZ
			Shell.box(s, F, x - Plan.PARTY_T / 2, 0, math.min(z0, z1), x + Plan.PARTY_T / 2, TOP, math.max(z0, z1), CORRIDOR_WALL, M.SmoothPlastic).Name =
				"PartyWall"
		end
	end
	-- the corridors' east end wall
	Shell.box(s, F, Plan.COR_X1, 0, -Plan.COR_HALF, Plan.COR_X1 + 1, TOP, Plan.COR_HALF, CORRIDOR_WALL, M.SmoothPlastic).Name =
		"CorridorEnd"
end

local function corridors(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local spots = Plan.units()
	for level = 1, Plan.LEVELS do
		local c = Kit.model(m, "Corridor" .. level)
		local y = (level - 1) * LH
		-- unit-front walls with a doorway per unit
		for _, side in { -1, 1 } do
			local gaps: { Shell.Gap } = {}
			for _, u in spots do
				if u.level == level and (u.side == "north") == (side < 0) then
					local dx = if u.side == "north" then Plan.DOOR_UX else -Plan.DOOR_UX
					table.insert(gaps, { c = u.cx + dx, w = Plan.DOOR_W, h = Plan.DOOR_H })
				end
			end
			local z = side * (Plan.COR_HALF + Plan.FRONT_T / 2)
			Shell.wallX(c, F, z, Plan.COR_X0, Plan.COR_X1, y, y + CH, Plan.FRONT_T, CORRIDOR_WALL, M.SmoothPlastic, gaps)
		end
		-- the runner carpet, a brass-edged base and the ceiling light strip
		local runner = Shell.box(c, F, Plan.NEAR_X0 + 1, y, -3.2, Plan.COR_X1 - 0.5, y + 0.06, 3.2, RUNNER, M.Carpet, false)
		runner.Name = "Runner"
		runner.CastShadow = false
		local rg, RW, RH = Paint.surface(runner, Enum.NormalId.Top, 2, { maxDistance = 120 })
		Core.px(rg, 0, 4, RW, 3, BRASS, 0.2)
		Core.px(rg, 0, RH - 7, RW, 3, BRASS, 0.2)
		-- a walnut dado rail along both walls and brass sconces at every party wall
		for _, side in { -1, 1 } do
			local z = side * (Plan.COR_HALF - 0.1)
			Shell.box(c, F, Plan.COR_X0, y + 3.6, z - 0.1, Plan.COR_X1, y + 3.9, z + 0.1, hex("#4A2E1E"), M.Wood, false).Name =
				"DadoRail"
			for i = 0, Plan.PER_SIDE do
				local x = Plan.ROW_X0 + Plan.PITCH * i
				local sconce = Shell.glow(c, F.cf(x, y + 7.5, z - side * 0.3), Vector3.new(0.6, 1.2, 0.4), hex("#FFD9A0"))
				sconce.Name = "Sconce"
			end
		end
		for i = 0, 3 do
			local x = -48 + i * 32
			Shell.glow(c, F.cf(x, y + CH - 0.06, 0), Vector3.new(10, 0.1, 1.6), hex("#FFF1DA"), if i % 2 == 0
				then { range = 30, brightness = 0.75 }
				else nil)
		end
		-- the corridor's end: a skyline photograph on the east wall and the floor's sign at the stairs
		local photo = Kit.detail(c, F.cf(Plan.COR_X1 - 0.1, y + 6.5, 0, Shell.W), Vector3.new(8, 6, 0.2), hex("#1C1E22"), M.SmoothPlastic)
		photo.Name = "SkylinePhoto"
		local pg, PW, PH = Paint.surface(photo, Enum.NormalId.Front, 8, { maxDistance = 120 })
		Paint.skyline(pg, PW, PH, rng, { mood = if level == 2 then "dusk" else "day", view = "high" })
		Core.stroke(Core.bg(pg, hex("#000000"), 1), BRASS, 4)
		local a, b = (level - 1) * 8 + 1, level * 8
		Shell.plate(c, F.cf(-59, y + 11.4, -Plan.COR_HALF, Shell.S), 7, 1.2, Text.get("apt_floor", { n = level }) .. "  ·  " .. Text.get("apt_floor_units", { a = a, b = b }), {
			color = NAVY,
			ink = hex("#E3C46F"),
			font = Enum.Font.Bodoni,
			pps = 40,
		})
	end
end

---------------------------------------------------------------------------------------------------
-- The stair hall
---------------------------------------------------------------------------------------------------
local function stairs(m: Instance, F: Shell.Frame)
	local s = Kit.model(m, "StairHall")
	local X0, X1, HZ = Plan.STAIR_X0, Plan.STAIR_X1, Plan.STAIR_HALF
	local laneW = HZ - Plan.LANE_GAP
	local laneN = -(Plan.LANE_GAP + laneW / 2)
	local laneS = Plan.LANE_GAP + laneW / 2
	-- enclosing walls: north, west, and south (shared with the lobby, with the lobby's opening on the ground floor)
	Shell.box(s, F, X0 - 1, 0, -HZ - 1, X1, TOP, -HZ, CORRIDOR_WALL, M.SmoothPlastic).Name = "StairWall"
	Shell.box(s, F, X0 - 1, 0, -HZ, X0, TOP, HZ, CORRIDOR_WALL, M.SmoothPlastic).Name = "StairWall"
	Shell.wallX(s, F, HZ + 0.5, X0 - 1, X1, 0, TOP, 1, CORRIDOR_WALL, M.SmoothPlastic, {
		{ c = (Plan.NEAR_X0 + Plan.LOBBY_X1) / 2, w = Plan.LOBBY_X1 - Plan.NEAR_X0, h = 10 },
	})
	-- the wall between the two lanes, along the flights only
	Shell.box(s, F, Plan.FAR_X1, 0, -Plan.LANE_GAP, Plan.NEAR_X0, TOP, Plan.LANE_GAP, STONE, M.SmoothPlastic).Name =
		"LaneWall"
	local stepC = hex("#BDB6A8")
	for storey = 0, Plan.LEVELS - 2 do
		local yb = storey * LH
		-- flight 1: the north lane, rising west from the near landing
		Kit.stairs(s, F.cf(Plan.NEAR_X0 - Plan.RUN / 2, yb, laneN, Shell.W), laneW, Plan.STEPS, Plan.RISE, Plan.RUN, stepC, M.Marble)
		-- the far landing (solid on the ground floor, a slab above it)
		local farY0 = if storey == 0 then 0 else yb + Plan.STEPS * Plan.RISE - Plan.SLAB
		Shell.box(s, F, X0, farY0, -HZ, Plan.FAR_X1, yb + Plan.STEPS * Plan.RISE, HZ, stepC, M.Marble).Name = "FarLanding"
		-- flight 2: the south lane, rising east back to the next floor's landing
		Kit.stairs(s, F.cf(Plan.FAR_X1 + Plan.RUN / 2, yb + Plan.STEPS * Plan.RISE, laneS, Shell.E), laneW, Plan.STEPS, Plan.RISE, Plan.RUN, stepC, M.Marble)
		if storey == 0 then
			-- nothing to see under the first flight 2: fill it so no one wanders into a low crawlspace
			Shell.box(s, F, Plan.FAR_X1, 0, Plan.LANE_GAP, Plan.NEAR_X0, Plan.STEPS * Plan.RISE, HZ, stepC, M.Marble).Name =
				"UnderStair"
		end
		-- handrails along the lane wall
		for _, z in { -Plan.LANE_GAP - 0.2, Plan.LANE_GAP + 0.2 } do
			local rising = z < 0
			local x0, x1 = Plan.NEAR_X0, Plan.FAR_X1
			local y0 = if rising then yb + 3 else yb + Plan.STEPS * Plan.RISE + 3
			local y1 = y0 + Plan.STEPS * Plan.RISE * (if rising then 1 else 1)
			local a = F.v(x0, if rising then y0 else y1, z)
			local b = F.v(x1, if rising then y1 else y0, z)
			Kit.detail(s, CFrame.lookAt((a + b) / 2, b), Vector3.new(0.25, 0.25, (b - a).Magnitude), BRASS, M.Metal).Name =
				"Handrail"
		end
	end
	-- the top landing's guard rail across the north lane (nothing above flight 1 there)
	local top = TOP - LH
	Shell.box(s, F, Plan.NEAR_X0 - 0.4, top, -HZ, Plan.NEAR_X0, top + 3.6, -Plan.LANE_GAP, BRASS, M.Metal).Name = "GuardRail"
	local glass = Shell.box(s, F, Plan.NEAR_X0 - 0.3, top + 0.4, -HZ, Plan.NEAR_X0 - 0.1, top + 3.4, -Plan.LANE_GAP, hex("#CFE0E8"), M.Glass, false)
	glass.Transparency = 0.6
	-- a light on every landing and the floor signs on the north wall of each near landing
	for level = 1, Plan.LEVELS do
		local y = (level - 1) * LH
		Shell.glow(s, F.cf((Plan.NEAR_X0 + Plan.STAIR_X1) / 2, y + CH - 0.06, 0), Vector3.new(4, 0.1, 4), hex("#FFF1DA"), if level == 2
			then { range = 40, brightness = 0.8 }
			else nil)
		Shell.plate(s, F.cf((Plan.NEAR_X0 + Plan.STAIR_X1) / 2, y + 7, -HZ, Shell.S), 6.4, 1.6, Text.get("apt_floor", { n = level }), {
			color = NAVY,
			ink = hex("#E3C46F"),
			font = Enum.Font.Bodoni,
			pps = 40,
		})
	end
	Shell.glow(s, F.cf((X0 + Plan.FAR_X1) / 2, TOP - Plan.SLAB - 0.06, 0), Vector3.new(4, 0.1, 4), hex("#FFF1DA"), {
		range = 40,
		brightness = 0.7,
	})
end

function Building.build(parent: Instance, F: Shell.Frame, rng: Deps.RngT)
	structure(parent, F)
	corridors(parent, F, rng)
	stairs(parent, F)
end

return Building
