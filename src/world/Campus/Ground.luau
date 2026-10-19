--!strict
-- Eastbridge ground: the lot slabs, Eastbridge Avenue and Mill Street (cracked asphalt, tar patches, faded lines,
-- manholes, drains), sidewalks with joints and curbs, curb-cut ramps and worn crosswalks, puddles, the riverside
-- embankment with its railing, the river itself and the invisible boundary walls. Bake-safe.

local Deps = require(script.Parent.Deps)
local Plan = require(script.Parent.Plan)
local Geo = require(script.Parent.Geo)
local Paint = require(script.Parent.Paint)

local Kit = Deps.Kit
local Props = Deps.Props
local Core = Deps.Gui.Core
local P = Deps.Palette
local C = P.campus
local hex = P.hex
local M = Enum.Material

local Ground = {}

local WALK = Plan.WALK
local v = Plan.v

local function lbox(parent: Instance, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3, mat: Enum.Material?, solid: boolean?): Part
	return Geo.lbox(parent, x0, y0, z0, x1, y1, z1, color, mat, solid)
end

local SURFACES: { [string]: { color: Color3, mat: Enum.Material } } = {
	plaza = { color = hex("#86827A"), mat = M.Concrete },
	asphalt = { color = hex("#34353A"), mat = M.Asphalt },
}

local function roadCracks(part: BasePart, rng: Deps.RngT, n: number)
	local gui, W, H = Paint.surface(part, Enum.NormalId.Top, 4)
	gui.Name = "Cracks"
	Paint.cracks(gui, W, H, rng, n, { color = hex("#17181A") })
	-- oil stains in the lanes
	for _ = 1, math.floor(n / 4) do
		local d = Core.dot(gui, rng:range(0, W), rng:range(H * 0.2, H * 0.8), rng:range(8, 22), hex("#1C1D20"), rng:range(0.4, 0.7))
		d.Name = "Stain"
	end
end

local function sidewalkJoints(part: BasePart, along: string, rng: Deps.RngT)
	local gui, W, H = Paint.surface(part, Enum.NormalId.Top, 4)
	gui.Name = "Joints"
	local long = if along == "x" then W else H
	local step = 6 * 4
	local n = math.floor(long / step)
	for i = 1, n do
		local t = i * step
		if along == "x" then
			Core.px(gui, t, 0, 2, H, hex("#5E5B55"), 0.35)
		else
			Core.px(gui, 0, t, W, 2, hex("#5E5B55"), 0.35)
		end
	end
	Paint.cracks(gui, W, H, rng, math.floor(n / 3) + 1, { color = hex("#4A4843"), thick = 1 })
	-- old gum and stains
	for _ = 1, math.floor(n / 2) do
		Core.dot(gui, rng:range(0, W), rng:range(0, H), rng:range(2, 6), hex("#3E3C38"), 0.4)
	end
end

local function line(parent: Instance, x0: number, z0: number, x1: number, z1: number, color: Color3, rng: Deps.RngT, gaps: number)
	-- a painted line split into segments; some fade, a few are missing entirely
	local along = if math.abs(x1 - x0) > math.abs(z1 - z0) then "x" else "z"
	local len = if along == "x" then x1 - x0 else z1 - z0
	local seg = len / gaps
	for i = 0, gaps - 1 do
		if rng:chance(0.85) then
			local a = i * seg + rng:range(0, seg * 0.08)
			local b = (i + 1) * seg - rng:range(0, seg * 0.25)
			local p: Part
			if along == "x" then
				p = lbox(parent, x0 + a, 0.0, z0, x0 + b, 0.05, z1, color, M.SmoothPlastic, false)
			else
				p = lbox(parent, x0, 0.0, z0 + a, x1, 0.05, z0 + b, color, M.SmoothPlastic, false)
			end
			p.Transparency = rng:range(0.15, 0.55)
			p.CastShadow = false
			p.Name = "Line"
		end
	end
end

local function crosswalk(parent: Instance, cw: { [string]: any }, rng: Deps.RngT)
	local size = if cw.along == "z" then Vector3.new(cw.width, 0.06, cw.length) else Vector3.new(cw.length, 0.06, cw.width)
	local p = Kit.detail(parent, Plan.cf(cw.x, 0.02, cw.z), size, Color3.new(1, 1, 1), M.SmoothPlastic)
	p.Name = "Crosswalk"
	p.Transparency = 1
	local gui, W, H = Paint.surface(p, Enum.NormalId.Top, 6)
	-- bars parallel to the traffic, spaced along the walking direction
	local walkLen = if cw.along == "z" then H else W
	local bars = math.floor(cw.length / 2.4)
	for i = 0, bars - 1 do
		if rng:chance(0.9) then
			local t0 = (i + 0.2) * (walkLen / bars)
			local th = (walkLen / bars) * 0.55
			local f = if cw.along == "z"
				then Core.px(gui, 0, t0, W, th, hex("#E6E2D6"), rng:range(0.25, 0.6))
				else Core.px(gui, t0, 0, th, H, hex("#E6E2D6"), rng:range(0.25, 0.6))
			f.Name = "Bar"
		end
	end
	-- curb-cut ramps at both ends (road 0 -> sidewalk 0.5)
	for _, s in { -1, 1 } do
		local cf: CFrame
		local rsize = Vector3.new(cw.width, WALK, 2.5)
		if cw.along == "z" then
			local zc = cw.z + s * (cw.length / 2 - 1.25)
			cf = Plan.cf(cw.x, WALK / 2, zc, if s < 0 then 180 else 0)
		else
			local xc = cw.x + s * (cw.length / 2 - 1.25)
			cf = Plan.cf(xc, WALK / 2, cw.z, if s < 0 then -90 else 90)
		end
		local r = Kit.wedge(parent, cf, rsize, hex("#8E8A82"), M.Concrete)
		r.Name = "CurbRamp"
		-- tactile warning strip
		local strip = Kit.detail(parent, cf * CFrame.new(0, WALK / 2 + 0.01, 0.6), Vector3.new(cw.width * 0.6, 0.04, 0.9), hex("#B8962E"), M.DiamondPlate)
		strip.CastShadow = false
	end
end

function Ground.build(parent: Instance)
	local m = Kit.model(parent, "Ground")
	local rng = Deps.Rng.new("campus-ground")

	-- the wider world beyond the boundary (under the backdrops)
	local outer = lbox(m, -400, -6, -400, 236, 0.3, 400, hex("#45443F"), M.Concrete)
	outer.Name = "OuterGround"

	-- lots
	for _, lot in Plan.lots do
		local s = SURFACES[lot.surface]
		local p = lbox(m, lot.x0, -4, lot.z0, lot.x1, WALK, lot.z1, s.color, s.mat)
		p.Name = "Lot_" .. lot.id
	end

	-- Eastbridge Avenue
	local av = Plan.avenue
	local road = lbox(m, av.x0, -4, av.z0, av.x1, 0, av.z1, C.asphalt, M.Asphalt)
	road.Name = "EastbridgeAve"
	roadCracks(road, rng, 46)
	-- Mill Street (north and south of the intersection; the avenue covers the crossing)
	local mill = Plan.mill
	for _, seg in { { mill.z0, av.z0 }, { av.z1, mill.z1 } } do
		local r = lbox(m, mill.x0, -4, seg[1], mill.x1, 0, seg[2], Geo.vary(C.asphalt, rng, 0.04), M.Asphalt)
		r.Name = "MillSt"
		roadCracks(r, rng, 22)
	end

	-- sidewalks and curbs (curb strips sit on the road side, same top as the walk)
	local curbC = hex("#7A7770")
	local walkC = hex("#9C988F")
	local walks = {
		{ x0 = Plan.PLAY.x0 - 2, x1 = mill.walkW[2], z0 = av.walkN[1], z1 = av.walkN[2], curb = "z1" },
		{ x0 = mill.walkE[1], x1 = Plan.overlook.x0, z0 = av.walkN[1], z1 = av.walkN[2], curb = "z1" },
		{ x0 = Plan.PLAY.x0 - 2, x1 = mill.walkW[2], z0 = av.walkS[1], z1 = av.walkS[2], curb = "z0" },
		{ x0 = mill.walkE[1], x1 = Plan.overlook.x0, z0 = av.walkS[1], z1 = av.walkS[2], curb = "z0" },
		{ x0 = mill.walkW[1], x1 = mill.walkW[2], z0 = Plan.PLAY.z0 - 2, z1 = av.walkN[1], curb = "x1" },
		{ x0 = mill.walkE[1], x1 = mill.walkE[2], z0 = Plan.PLAY.z0 - 2, z1 = av.walkN[1], curb = "x0" },
		{ x0 = mill.walkW[1], x1 = mill.walkW[2], z0 = av.walkS[2], z1 = Plan.PLAY.z1 + 2, curb = "x1" },
		{ x0 = mill.walkE[1], x1 = mill.walkE[2], z0 = av.walkS[2], z1 = Plan.PLAY.z1 + 2, curb = "x0" },
	}
	for i, w in walks do
		local x0, x1, z0, z1 = w.x0, w.x1, w.z0, w.z1
		local cx0, cx1, cz0, cz1 = x0, x1, z0, z1
		if w.curb == "z1" then
			z1 -= 0.8
			cz0 = z1
		elseif w.curb == "z0" then
			z0 += 0.8
			cz1 = z0
		elseif w.curb == "x1" then
			x1 -= 0.8
			cx0 = x1
		else
			x0 += 0.8
			cx1 = x0
		end
		local walk = lbox(m, x0, -2, z0, x1, WALK, z1, Geo.vary(walkC, rng, 0.03), M.Pavement)
		walk.Name = "Sidewalk"
		sidewalkJoints(walk, if (x1 - x0) > (z1 - z0) then "x" else "z", Deps.Rng.new("walk" .. i))
		local curb = lbox(m, cx0, -2, cz0, cx1, WALK, cz1, curbC, M.Concrete)
		curb.Name = "Curb"
	end

	-- lane markings: faded double yellow, broken parking-lane edges
	local yellow = hex("#C9A93E")
	local white = hex("#D8D4C8")
	line(m, av.x0, -0.35, av.x1, -0.15, yellow, rng, 9)
	line(m, av.x0, 0.15, av.x1, 0.35, yellow, rng, 9)
	line(m, av.x0, -7.1, av.x1, -6.9, white, rng, 14)
	line(m, av.x0, 6.9, av.x1, 7.1, white, rng, 14)
	for _, seg in { { mill.z0, av.z0 - 9 }, { av.z1 + 9, mill.z1 } } do
		line(m, 93.65, seg[1], 93.85, seg[2], yellow, rng, 5)
		line(m, 94.15, seg[1], 94.35, seg[2], yellow, rng, 5)
	end
	-- stop bars at the Mill Street crossing
	for _, z in { av.z0 - 9, av.z1 + 9 } do
		local p = lbox(m, mill.x0 + 1, 0, z - 0.4, mill.x1 - 1, 0.05, z + 0.4, white, M.SmoothPlastic, false)
		p.Transparency = 0.4
	end

	for _, cw in Plan.crosswalks do
		crosswalk(m, cw :: any, rng)
	end

	-- tar patches and utility cuts
	for _ = 1, 22 do
		local onMill = rng:chance(0.3)
		local x = if onMill then rng:range(mill.x0 + 2, mill.x1 - 6) else rng:range(av.x0 + 10, av.x1 - 10)
		local z = if onMill then rng:range(-230, 190) else rng:range(av.z0 + 1, av.z1 - 6)
		if not (onMill and z > av.z0 - 2 and z < av.z1 + 2) then
			local w, d = rng:range(3, 9), rng:range(2, 6)
			local p = lbox(m, x, -0.02, z, x + w, 0.03, z + d, Geo.vary(if rng:chance(0.5) then C.asphaltPatch else hex("#232427"), rng, 0.05), M.Asphalt, false)
			p.Name = "Patch"
			p.CastShadow = false
		end
	end
	-- manholes and storm drains
	for _, mh in { { -150, -4 }, { -20, 5 }, { 94, -60 }, { 94, 120 }, { 170, -3 } } do
		local c = Kit.cylinder(m, Plan.cf(mh[1], 0.03, mh[2]), 0.08, 3.2, hex("#2A2826"), M.DiamondPlate)
		Geo.ghost(c).Name = "Manhole"
	end
	for _, dr in { { -230, -13.2 }, { -120, 13.2 }, { -10, -13.2 }, { 40, 13.2 }, { 150, -13.2 }, { 79.2, 60 }, { 108.8, -120 } } do
		local alongX = math.abs(dr[2]) > 13
		local size = if alongX then Vector3.new(3, 0.08, 1.2) else Vector3.new(1.2, 0.08, 3)
		local g = Kit.detail(m, Plan.cf(dr[1], 0.03, dr[2]), size, hex("#1E1F21"), M.DiamondPlate)
		g.Name = "Drain"
	end
	-- puddles collect in the gutters, the back alley and the yards
	for i, pd in {
		{ -190, 11.5, 1.6 },
		{ -60, -11.5, 1.2 },
		{ 30, 12, 1.4 },
		{ 140, -11, 2.0 },
		{ -100, 91, 1.5 },
		{ -20, 90, 2.2 },
		{ 40, 92, 1.3 },
		{ -230, 120, 2.4 },
		{ 180, 150, 2.6 },
		{ 200, -112, 1.8 },
		{ 92, 70, 1.1 },
	} do
		local y = if math.abs(pd[2]) < 14 then 0.02 else WALK + 0.02
		Props.build("puddle", m, Plan.cf(pd[1], y, pd[2], rng:range(0, 180)), { size = pd[3], seed = "puddle" .. i })
	end

	-- the riverside: embankment, railing, the river
	local riv = Plan.river
	lbox(m, Plan.PLAY.x1, -16, -400, Plan.PLAY.x1 + 4, WALK, 400, hex("#6E6B63"), M.Concrete).Name = "Embankment"
	local water = Geo.water(m, CFrame.new(v((riv.x0 + 4 + riv.x1) / 2, riv.surface - 4, 0)), Vector3.new(riv.x1 - riv.x0 - 4, 8, 800))
	water.Name = "River"
	local rail = hex("#3E4347")
	local rx = Plan.PLAY.x1 + 0.6
	local z0, z1 = Plan.PLAY.z0, Plan.PLAY.z1
	for z = z0, z1, 24 do
		Kit.block(m, Plan.cf(rx, WALK + 1.8, z), Vector3.new(0.4, 3.6, 0.4), rail, M.Metal).Name = "RailPost"
	end
	for _, y in { 1.8, 3.5 } do
		local r = Geo.pipe(m, v(rx, WALK + y, z0), v(rx, WALK + y, z1), 0.3, rail, M.Metal, true)
		r.Name = "Rail"
	end

	-- invisible boundary walls just outside the walkable area (tall enough that nobody hops them from a roof)
	local B = Plan.PLAY
	local top = 200
	Geo.barrier(m, v(B.x0 - 3, -4, B.z0 - 4), v(B.x0 - 1, top, B.z1 + 4))
	Geo.barrier(m, v(B.x1 + 1, -4, B.z0 - 4), v(B.x1 + 2, top, B.z1 + 4))
	Geo.barrier(m, v(B.x0 - 3, -4, B.z0 - 3), v(B.x1 + 2, top, B.z0 - 1))
	Geo.barrier(m, v(B.x0 - 3, -4, B.z1 + 1), v(B.x1 + 2, top, B.z1 + 3))
	-- and a lid over the far end of the viaduct so nothing walks off along the tracks into the painted city
	return m
end

return Ground
