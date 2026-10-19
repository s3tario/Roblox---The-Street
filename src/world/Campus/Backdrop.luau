--!strict
-- Beyond the playable streets (behind the invisible boundary): rows of low-detail brick blocks with painted facades on
-- the north, south and west, the roads carrying on out of town behind barricades, distant painted townscapes at the
-- region edge, and across the river the hazy Wall Street skyline: a near row of real towers in silhouette plus a
-- painted skyline panel behind them, so the city reads with some parallax. Bake-safe.

local Deps = require(script.Parent.Deps)
local Plan = require(script.Parent.Plan)
local Geo = require(script.Parent.Geo)
local Paint = require(script.Parent.Paint)

local Kit = Deps.Kit
local Core = Deps.Gui.Core
local P = Deps.Palette
local C = P.campus
local hex = P.hex
local M = Enum.Material

local Backdrop = {}

local WALK = Plan.WALK
local EDGE = 398 -- the region's edge in Plan coordinates is +/- 400
local FAR_BANK = 310 -- where the river ends and the city begins

-- A row of blocks along one axis. along = "x" (row at fixed z, facing `face`) or "z".
type Row = {
	along: string,
	from: number,
	to: number,
	at: number,
	depth: number,
	face: Enum.NormalId,
	skip: { { number } }?,
}

local function blocks(m: Instance, row: Row, rng: Deps.RngT)
	local cursor = row.from
	while cursor < row.to do
		local w = rng:range(22, 44)
		local a, b = cursor, math.min(cursor + w, row.to)
		cursor = b + rng:range(0, 3)
		local skipped = false
		local skips = row.skip
		if skips then
			for _, s in skips do
				if b > s[1] and a < s[2] then
					skipped = true
				end
			end
		end
		if skipped or b - a < 8 then
			continue
		end
		local h = rng:range(18, 58)
		local color = if rng:chance(0.7) then Geo.brick(rng) else Geo.vary(C.concrete, rng, 0.1)
		local mat = if rng:chance(0.7) then M.Brick else M.Concrete
		local d = row.depth
		local part: Part
		if row.along == "x" then
			-- the block stands behind its painted face: a row facing +Z (Back) extends to -Z from `at`
			local z0 = if row.face == Enum.NormalId.Back then row.at - d else row.at
			part = Geo.lbox(m, a, WALK - 1, z0, b, WALK + h, z0 + d, color, mat)
		else
			local x0 = if row.face == Enum.NormalId.Right then row.at - d else row.at
			part = Geo.lbox(m, x0, WALK - 1, a, x0 + d, WALK + h, b, color, mat)
		end
		part.Name = "BackdropBlock"
		part.CastShadow = false
		local gui, W, H = Paint.surface(part, row.face, 3)
		Paint.windows(gui, W, H, rng, {
			cols = math.max(2, math.floor((b - a) / 8)),
			rows = math.max(1, math.floor(h / 12)),
			top = 0.08,
			bottom = 0.1,
			lit = 0.2,
			boarded = 0.08,
			acUnits = 0.2,
		})
		Paint.grime(gui, W, H, rng, { streaks = 6 })
		-- cornice and the odd water tank silhouette
		Kit.detail(
			m,
			part.CFrame * CFrame.new(0, part.Size.Y / 2 + 0.4, 0),
			part.Size * Vector3.new(1, 0, 1) + Vector3.new(1, 0.8, 1),
			Kit.shade(color, -0.2),
			M.Concrete
		).CastShadow =
			false
		if rng:chance(0.25) then
			local top = part.CFrame * CFrame.new(rng:range(-4, 4), part.Size.Y / 2 + 0.8, 0)
			Kit.detail(m, top * CFrame.new(0, 3, 0), Vector3.new(0.4, 6, 6), C.rustDark, M.CorrodedMetal)
			Kit.cylinder(m, top * CFrame.new(0, 9, 0), 6, 6.5, hex("#5A4636"), M.WoodPlanks).CanCollide = false
		end
	end
end

local function farPanel(m: Instance, cf: CFrame, size: Vector3, rng: Deps.RngT, town: boolean)
	local p = Kit.detail(m, cf, size, hex("#9AA3A8"), M.SmoothPlastic)
	p.Name = if town then "TownscapePanel" else "SkylinePanel"
	p.CastShadow = false
	local gui, W, H = Paint.surface(p, Enum.NormalId.Front, if town then 2 else 2.5, { glow = false })
	if town then
		local sky = Core.bg(gui, hex("#9AA3A8"))
		Core.gradient(sky, hex("#8A949B"), hex("#B9B8AE"), 90)
		Paint.townscape(gui, W, H, rng, { horizon = 0.9, haze = hex("#A3A9AA"), near = hex("#6E6862") })
	else
		Paint.skyline(gui, W, H, rng, {
			horizon = 0.93,
			layers = 3,
			haze = hex("#B4B9BC"),
			near = hex("#5E6870"),
			litChance = 0.3,
			landmarks = true,
			maxHeight = 0.8,
		})
	end
end

-- Real towers across the river (dark, hazy, lit windows), the near layer of the Wall Street skyline.
local function cityTowers(m: Instance, rng: Deps.RngT)
	local towers = Kit.model(m, "CityTowers")
	-- the far bank and its quay wall (the river runs between the overlook and here)
	Geo.lbox(towers, FAR_BANK, -15, -400, 400, 1, 400, hex("#4E4C46"), M.Concrete).Name = "FarBank"
	Geo.lbox(towers, FAR_BANK - 1, -8, -400, FAR_BANK, 2.4, 400, hex("#6E6B63"), M.Concrete).Name = "QuayWall"
	local z = -360
	while z < 336 do
		local w = rng:range(24, 46)
		local h = rng:range(70, 190)
		local x = rng:range(FAR_BANK + 30, 372)
		local col = hex("#59636B"):Lerp(hex("#8E989E"), rng:range(0, 0.5))
		local t = Geo.lbox(
			towers,
			x - w / 2,
			-6,
			z,
			x + w / 2,
			h,
			z + w,
			col,
			if rng:chance(0.5) then M.Glass else M.Concrete
		)
		t.Name = "Tower"
		t.CastShadow = false
		t.Reflectance = 0.05
		local gui, W, H = Paint.surface(t, Enum.NormalId.Left, 1.5)
		for r = 0, math.floor(H / 5) do
			if rng:chance(0.35) then
				local seg = rng:range(0.2, 0.9)
				Core.px(gui, W * rng:range(0, 1 - seg), r * 5, W * seg, 2, hex("#E9D9A8"), rng:range(0.3, 0.7))
			end
		end
		if rng:chance(0.35) then
			Kit.detail(towers, t.CFrame * CFrame.new(0, h / 2 + 10, 0), Vector3.new(1, 20, 1), col, M.Metal).CastShadow =
				false
		end
		z += w + rng:range(4, 18)
	end
end

local function roads(m: Instance)
	-- the avenue and Mill Street carry on out of town
	local av = Plan.avenue
	local mill = Plan.mill
	Geo.lbox(m, -400, -4, av.z0, av.x0, 0, av.z1, C.asphalt, M.Asphalt).Name = "AvenueWest"
	Geo.lbox(m, mill.x0, -4, -400, mill.x1, 0, mill.z0, C.asphalt, M.Asphalt).Name = "MillNorth"
	Geo.lbox(m, mill.x0, -4, mill.z1, mill.x1, 0, 400, C.asphalt, M.Asphalt).Name = "MillSouth"
end

function Backdrop.build(parent: Instance): Model
	local m = Kit.model(parent, "Backdrop")
	local rng = Deps.Rng.new("backdrop")
	local mill = Plan.mill
	local av = Plan.avenue
	roads(m)
	-- north and south rows (facing the town), the west row (facing east), leaving the roads open
	blocks(m, {
		along = "x",
		from = -400,
		to = 228,
		at = -252,
		depth = 30,
		face = Enum.NormalId.Back,
		skip = { { mill.x0 - 2, mill.x1 + 2 } },
	}, rng)
	blocks(m, {
		along = "x",
		from = -400,
		to = 228,
		at = 210,
		depth = 30,
		face = Enum.NormalId.Front,
		skip = { { mill.x0 - 2, mill.x1 + 2 } },
	}, rng)
	blocks(m, {
		along = "z",
		from = -250,
		to = 210,
		at = -258,
		depth = 30,
		face = Enum.NormalId.Right,
		skip = { { av.z0 - 2, av.z1 + 2 } },
	}, rng)
	-- the far townscapes at the region edge
	farPanel(m, Plan.cf(-84, WALK + 40, -EDGE, Plan.S), Vector3.new(632, 80, 1), rng, true)
	farPanel(m, Plan.cf(-84, WALK + 40, EDGE, Plan.N), Vector3.new(632, 80, 1), rng, true)
	farPanel(m, Plan.cf(-EDGE, WALK + 40, 0, Plan.E), Vector3.new(800, 80, 1), rng, true)
	-- across the river: towers, then the skyline panel
	cityTowers(m, rng)
	farPanel(m, Plan.cf(EDGE, 120, 0, Plan.W), Vector3.new(800, 250, 1), rng, false)
	return m
end

return Backdrop
