--!strict
-- The Street seen through the lobby glass (contracts §15: templates are enclosed and their views are faked): the
-- granite sidewalk with trees, lamps and bollards, the kerb and the road with its markings, a town car and a cab at
-- the kerb, a row of painted building fronts across the road (ground-floor shops from Text.lobby_storefronts) and
-- the painted skyline behind them. Nothing out here is reachable (Hall seals the facade). Bake-safe.

local Deps = require(script.Parent.Deps)
local Plan = require(script.Parent.Plan)
local Look = require(script.Parent.Look)

local Kit = Deps.Kit
local Geo = Deps.Geo
local Art = Deps.Art
local Text = Deps.Text
local Props = Deps.Props
local Shell = Deps.Shell
local Rng = Deps.Rng
local GuiCore = Deps.Gui.Core
local M = Enum.Material
local V = Vector3.new

type Rng = typeof(Rng.new(0))

local Street = {}

local S = Plan.street

local function roadMarkings(road: Part)
	local gui, W, H = GuiCore.surface(road, Enum.NormalId.Top, { pps = 2.5, name = "Markings" })
	-- double yellow centre line and dashed white lane lines (the road runs along X; canvas y = world z)
	local cy = H / 2
	GuiCore.px(gui, 0, cy - 2, W, 1, Look.laneYellow)
	GuiCore.px(gui, 0, cy + 1, W, 1, Look.laneYellow)
	for _, f in { 0.25, 0.75 } do
		local y = H * f
		local x = 0
		while x < W do
			GuiCore.px(gui, x, y, 10, 1, Look.laneWhite, 0.1)
			x += 25
		end
	end
	-- a crosswalk in front of the door
	local cx = W / 2
	for i = -4, 4 do
		GuiCore.px(gui, cx + i * 5 - 1.5, 3, 3, H - 6, Look.laneWhite, 0.15)
	end
end

local function tree(m: Instance, x: number, z: number, rng: Rng)
	Geo.box(m, V(x - 2.4, 0, z - 2.4), V(x + 2.4, 0.08, z + 2.4), Look.granite, M.Metal).Name = "TreeGrate"
	local h = rng:range(9, 12)
	Geo.cyl(m, CFrame.new(x, h / 2, z), h, 0.8, Look.bark, M.Wood).Name = "Trunk"
	local a = Kit.ball(m, CFrame.new(x, h + 1.5, z), rng:range(7, 8.5), Look.leaf, M.LeafyGrass)
	Geo.ghost(a).Name = "Canopy"
	local b = Kit.ball(
		m,
		CFrame.new(x + rng:range(-1.5, 1.5), h + 3.6, z + rng:range(-1.5, 1.5)),
		rng:range(5, 6.5),
		Look.leafLight,
		M.LeafyGrass
	)
	Geo.ghost(b).Name = "Canopy"
end

local function lamp(m: Instance, x: number, z: number)
	if Props.tryBuild("street_lamp_classic", m, CFrame.lookAt(V(x, 0, z), V(x, 0, z + 1)), { seed = "lobby" .. x }) then
		return
	end
	Geo.cyl(m, CFrame.new(x, 7, z), 14, 0.5, Look.black, M.Metal).Name = "LampPole"
	local head = Kit.ball(m, CFrame.new(x, 14.4, z), 1.4, Look.warmLight, M.Neon)
	Geo.ghost(head).Name = "LampHead"
	head:AddTag("StreetLight")
end

function Street.build(parent: Instance): Model
	local m = Kit.model(parent, "StreetView")
	local rng = Rng.new("lobby-street")
	local z0 = Plan.MIN_Z - 0.7
	local hx = S.halfX

	-- near sidewalk, kerb, road, far kerb and sidewalk
	local walk = Geo.box(m, V(-hx, -1, S.sidewalkZ), V(hx, 0, z0), Look.pavement, M.Pavement, true)
	walk.Name = "Sidewalk"
	Art.tiles(walk, Enum.NormalId.Top, 5, 5, Look.kerb, { pps = 2.5, transparency = 0.5 })
	Geo.box(m, V(-hx, -0.7, S.sidewalkZ - 0.8), V(hx, 0, S.sidewalkZ), Look.kerb, M.Granite).Name = "Kerb"
	local road = Geo.box(m, V(-hx, -1.6, S.roadZ + 0.8), V(hx, -0.6, S.sidewalkZ - 0.8), Look.asphalt, M.Asphalt, true)
	road.Name = "Road"
	roadMarkings(road)
	Geo.box(m, V(-hx, -0.7, S.roadZ), V(hx, 0, S.roadZ + 0.8), Look.kerb, M.Granite).Name = "Kerb"
	local far = Geo.box(m, V(-hx, -1, S.farZ), V(hx, 0, S.roadZ), Look.pavement, M.Pavement, true)
	far.Name = "Sidewalk"
	Art.tiles(far, Enum.NormalId.Top, 5, 5, Look.kerb, { pps = 2.5, transparency = 0.5 })

	-- trees, lamps and bollards along the near kerb
	for _, x in { -96, -44, 44, 96, -150, 150 } do
		tree(m, x, S.sidewalkZ + 4.5, rng)
	end
	for _, x in { -20, 20, -70, 70 } do
		lamp(m, x, S.sidewalkZ + 2.2)
	end
	for _, x in { -12, -8, 8, 12 } do
		Geo.cyl(m, CFrame.new(x, 1.5, Plan.MIN_Z - 10), 3, 1, Look.black, M.Metal, true).Name = "Bollard"
		Geo.cyl(m, CFrame.new(x, 3.05, Plan.MIN_Z - 10), 0.1, 1.1, Look.brass, M.Metal)
	end

	-- cars at the kerb
	Props.tryBuild(
		"town_car",
		m,
		CFrame.lookAt(V(-30, -0.6, S.sidewalkZ - 5.5), V(-20, -0.6, S.sidewalkZ - 5.5)),
		{ seed = "lobby" }
	)
	Props.tryBuild("taxi", m, CFrame.lookAt(V(58, -0.6, S.roadZ + 6), V(48, -0.6, S.roadZ + 6)), { seed = "lobby" })

	-- the building fronts across the road
	local shops = Text.list("lobby_storefronts")
	local x = -hx
	local i = 0
	while x < hx do
		i += 1
		local w = math.min(rng:range(28, 46), hx - x)
		if w < 8 then
			break
		end
		local h = rng:range(44, 118)
		local depth = 18
		local body = Kit.block(
			m,
			CFrame.new(x + w / 2, h / 2 - 1, S.farZ - depth / 2),
			V(w, h, depth),
			Look.facades[(i - 1) % #Look.facades + 1],
			M.SmoothPlastic
		)
		body.Name = "Building"
		Art.facade(body, Enum.NormalId.Back, {
			seed = "lobby-bldg-" .. i,
			base = body.Color,
			floorH = rng:range(9, 11),
			bays = rng:int(6, 10),
			shopH = 12,
			shop = shops[(i - 1) % math.max(#shops, 1) + 1],
			awning = Look.awnings[(i - 1) % #Look.awnings + 1],
			litChance = 0.08,
		})
		local cornice = Kit.detail(
			m,
			CFrame.new(x + w / 2, h - 1.6, S.farZ + 0.6),
			V(w, 1.2, 1.2),
			Kit.shade(body.Color, -0.2),
			M.Concrete
		)
		cornice.Name = "Cornice"
		local awning = Kit.wedge(
			m,
			CFrame.new(x + w / 2, 12.2, S.farZ + 1.8) * Kit.rotY(180),
			V(w - 4, 1.4, 3.6),
			Look.awnings[(i - 1) % #Look.awnings + 1],
			M.Fabric,
			{ CanCollide = false, CanQuery = false, CanTouch = false }
		)
		awning.Name = "Awning"
		x += w
	end

	-- the skyline beyond (street-level horizon)
	Shell.backdrops(m, {
		seed = "lobby-skyline",
		halfX = Plan.HALF_X,
		halfZ = -Plan.MIN_Z,
		distance = 124,
		bottom = -2,
		top = 132,
		eyeY = 4,
		sides = { "south" },
		density = 1.4,
	})
	return m
end

return Street
