--!strict
-- Street life: classic black-and-brass lamps (bulbs tagged "StreetLight") and street trees in iron grates along
-- every curb, traffic signals and street-name blades at the intersections, brass hydrants and litter bins,
-- bollards along the plaza, parked taxis, town cars, sedans and a bus, food carts, the bike-share dock, a phone
-- booth, ATMs, the post clock, the sidewalk shed, rooftop billboards, striped steam stacks, and the Golden
-- Briefcase hiding spots. Furniture never lands in front of a door, on a crosswalk or on another fixture.
-- Bake-safe.
--
--   Life.build(parent) -> Model

local Deps = require(script.Parent.Deps)
local Look = require(script.Parent.Look)
local Plan = require(script.Parent.Plan)
local Text = require(script.Parent.Text)

local Kit = Deps.Kit
local Props = Deps.Props
local Signs = Deps.Signs
local Rng = Deps.Rng
local World = Deps.World
local M = Enum.Material

local Life = {}

local FLOOR = Plan.FLOOR
local ROAD = Plan.ROAD_TOP
local CURB_IN = 1.8 -- furniture line: this far in from the curb
local SPACING = 24 -- lamp, tree, lamp, tree...
local LIGHT_EVERY = 4 -- one lamp in four carries a real light

local function floorAt(v: Vector3, dir: Vector3): CFrame
	local pos = Vector3.new(v.X, FLOOR, v.Z)
	return CFrame.lookAt(pos, pos + dir)
end

local function faceAt(v: Vector3, face: string): CFrame
	return floorAt(v, Plan.FACE_DIR[face])
end

---------------------------------------------------------------------------------------------------
-- Keep-out zones
---------------------------------------------------------------------------------------------------
type Zone = { x: number, z: number, r: number }

local function reserve(list: { Zone }, v: Vector3, r: number)
	table.insert(list, { x = v.X, z = v.Z, r = r })
end

local function blocked(list: { Zone }, x: number, z: number, pad: number): boolean
	for _, k in list do
		local dx, dz = x - k.x, z - k.z
		if dx * dx + dz * dz < (k.r + pad) * (k.r + pad) then
			return true
		end
	end
	return false
end

local function keepOuts(): { Zone }
	local list: { Zone } = {}
	local function lotDoor(lot: Plan.Lot, r: number)
		local frame = Plan.lotFrame(lot)
		reserve(list, frame:PointToWorldSpace(Vector3.new(0, 0, -(Plan.SIDEWALK - CURB_IN))), r)
		reserve(list, frame:PointToWorldSpace(Vector3.new(0, 0, -6)), r)
	end
	local assigned, spare = Plan.assignLots(World.towers)
	for _, lot in assigned do
		lotDoor(lot, 10)
	end
	for _, lot in spare do
		lotDoor(lot, 6)
	end
	for id, lot in Plan.venueLots do
		lotDoor(lot, if id == "apartments" then 12 else 10)
	end
	-- the Exchange steps and the plaza's furniture
	local ex = Plan.lotFrame(Plan.exchange)
	for x = -50, 50, 25 do
		reserve(list, ex:PointToWorldSpace(Vector3.new(x, 0, -(Plan.SIDEWALK - CURB_IN))), 9)
	end
	for _, c in Plan.foodCarts do
		reserve(list, c.pos, 6)
	end
	reserve(list, Plan.bikeDock.pos, 9)
	reserve(list, Plan.phoneBooth.pos, 4)
	reserve(list, Plan.busStop.pos, 9)
	reserve(list, Plan.streetClock, 4)
	reserve(list, Plan.scaffold.pos, 10)
	reserve(list, Plan.newsstand.pos, 8)
	reserve(list, Plan.subway.pos, 10)
	for _, a in Plan.atms do
		reserve(list, a.pos, 4)
	end
	for _, d in Plan.directories do
		reserve(list, d.pos, 4)
	end
	for _, b in Plan.briefcases do
		reserve(list, b, 3)
	end
	return list
end

---------------------------------------------------------------------------------------------------
-- Lamps and trees
---------------------------------------------------------------------------------------------------
local function lamp(parent: Instance, cf: CFrame, twin: boolean, withLight: boolean)
	local g = Kit.model(parent, "StreetLamp")
	Kit.cylinder(g, cf * CFrame.new(0, 0.6, 0), 1.2, 1.5, Look.iron, M.Metal).Name = "Base"
	Kit.cylinder(g, cf * CFrame.new(0, 7.2, 0), 12, 0.45, Look.iron, M.Metal).Name = "Post"
	Kit.cylinder(g, cf * CFrame.new(0, 2.1, 0), 0.25, 0.8, Look.brass, M.Metal, { CanCollide = false })
	local heads: { CFrame } = if twin
		then { cf * CFrame.new(-2.1, 12.4, 0), cf * CFrame.new(2.1, 12.4, 0) }
		else { cf * CFrame.new(0, 14.0, 0) }
	if twin then
		Kit.detail(g, cf * CFrame.new(0, 13.35, 0), Vector3.new(4.6, 0.25, 0.25), Look.iron, M.Metal)
	end
	for i, h in heads do
		local bulb = Kit.detail(g, h, Vector3.new(1.0, 1.4, 1.0), Look.lampGlow, M.Neon)
		bulb.Name = "Lamp"
		bulb.Transparency = 0.1
		bulb.CastShadow = false
		bulb:AddTag("StreetLight")
		Kit.detail(g, h * CFrame.new(0, 0.85, 0), Vector3.new(1.4, 0.3, 1.4), Look.iron, M.Metal)
		if withLight and i == 1 then
			Kit.light(bulb, "point", { Color = Look.lampGlow, Range = 26, Brightness = 0.9 })
		end
	end
end

local function tree(parent: Instance, cf: CFrame, rng: Deps.RngT)
	local g = Kit.model(parent, "StreetTree")
	local grate = Kit.detail(g, cf * CFrame.new(0, 0.03, 0), Vector3.new(4.2, 0.06, 4.2), Look.iron, M.DiamondPlate)
	grate.CastShadow = false
	local trunkH = rng:range(6.5, 8)
	Kit.cylinder(g, cf * CFrame.new(0, trunkH / 2, 0), trunkH, 0.7, Look.trunk, M.Wood).Name = "Trunk"
	local tones = { Look.foliage, Look.foliageLight, Look.foliageDark }
	for k = 1, 3 do
		local d = rng:range(5, 7.5)
		local off = Vector3.new(rng:range(-1.4, 1.4), trunkH + rng:range(1.2, 3.2), rng:range(-1.4, 1.4))
		local leaf =
			Kit.ball(g, cf * CFrame.new(off), d, tones[k], M.LeafyGrass, { CanCollide = false, CanQuery = false })
		leaf.Name = "Canopy"
	end
end

-- Lamps and trees along the curb of every road, both sides, between the intersections.
local function curbs(m: Instance, zones: { Zone })
	local g = Kit.model(m, "Curbs")
	local rng = Rng.new("street-trees")
	local lampCount = 0
	for _, road in Plan.roads do
		local twin = road.lanes >= 4
		for _, s in { -1, 1 } do
			local across = road.c + s * (road.w / 2 + CURB_IN)
			-- intervals along the road between cross streets (keeping clear of crosswalks and corners)
			local cuts: { { number } } = {}
			for _, r in Plan.roads do
				if r.axis ~= road.axis then
					table.insert(cuts, { r.c - r.w / 2 - Plan.SIDEWALK - 4, r.c + r.w / 2 + Plan.SIDEWALK + 4 })
				end
			end
			table.sort(cuts, function(a, b)
				return a[1] < b[1]
			end)
			local lo = -Plan.WALL + 8
			local runs: { { number } } = {}
			for _, c in cuts do
				table.insert(runs, { lo, c[1] })
				lo = c[2]
			end
			table.insert(runs, { lo, Plan.WALL - 8 })
			for _, run in runs do
				local len = run[2] - run[1]
				if len < 10 then
					continue
				end
				local n = math.floor(len / SPACING)
				local start = run[1] + (len - n * SPACING) / 2
				for i = 0, n do
					local a = start + i * SPACING
					local x, z = if road.axis == "x" then a else across, if road.axis == "x" then across else a
					if blocked(zones, x, z, 1.5) then
						continue
					end
					-- lamps and trees face the road
					local toRoad = if road.axis == "x" then Vector3.new(0, 0, -s) else Vector3.new(-s, 0, 0)
					local cf = floorAt(Vector3.new(x, 0, z), toRoad)
					if i % 2 == 0 then
						lampCount += 1
						lamp(g, cf, twin, lampCount % LIGHT_EVERY == 1)
					else
						tree(g, cf, rng)
					end
					reserve(zones, Vector3.new(x, 0, z), 2)
				end
			end
		end
	end
	return g
end

---------------------------------------------------------------------------------------------------
-- Intersections: signals, street-name blades, hydrants and bins
---------------------------------------------------------------------------------------------------
local function intersections(m: Instance, zones: { Zone })
	local g = Kit.model(m, "Intersections")
	for _, it in Plan.intersections() do
		local ew, ns = it.ew, it.ns
		local ox, oz = ns.w / 2 + 1.4, ew.w / 2 + 1.4
		-- signals on two diagonal corners, facing the traffic that arrives at them
		local signals: { { sx: number, sz: number, dir: Vector3 } } = {
			{ sx = 1, sz = -1, dir = Vector3.new(1, 0, 0) },
			{ sx = -1, sz = 1, dir = Vector3.new(-1, 0, 0) },
		}
		for _, sg in signals do
			local p = Vector3.new(it.x + sg.sx * ox, 0, it.z + sg.sz * oz)
			Props.build("traffic_light", g, floorAt(p, sg.dir), {
				state = if sg.sx > 0 then "green" else "red",
				seed = ("signal:%d:%d"):format(it.x, it.z),
			})
			-- a litter bin a few strides back along the sidewalk
			Props.build(
				"trash_bin_street",
				g,
				floorAt(p + Vector3.new(sg.sx * 3.6, 0, sg.sz * 0.4), Vector3.new(0, 0, -sg.sz)),
				{
					seed = ("bin:%d:%d"):format(it.x, it.z),
				}
			)
			reserve(zones, p, 5)
		end
		-- street-name blades and a hydrant on the other two corners
		for _, c in { { 1, 1 }, { -1, -1 } } do
			local p = Vector3.new(it.x + c[1] * ox, 0, it.z + c[2] * oz)
			Signs.streetName(g, floorAt(p, Vector3.new(0, 0, c[2])), {
				text = Text.get(ns.name),
				text2 = Text.get(ew.name),
				seed = ("blade:%d:%d"):format(it.x, it.z),
			})
			Props.build(
				"hydrant_brass",
				g,
				floorAt(p + Vector3.new(c[1] * 0.2, 0, c[2] * 4), Vector3.new(-c[1], 0, 0)),
				{
					seed = ("hydrant:%d:%d"):format(it.x, it.z),
				}
			)
			reserve(zones, p, 6)
		end
	end
	return g
end

---------------------------------------------------------------------------------------------------
-- Vehicles, kiosks, fixtures
---------------------------------------------------------------------------------------------------
local VEHICLE_DIR: { [string]: Vector3 } = Plan.FACE_DIR

local function vehicles(m: Instance)
	local g = Kit.model(m, "Vehicles")
	for i, v in Plan.vehicles do
		local pos = Vector3.new(v.pos.X, ROAD, v.pos.Z)
		local cf = CFrame.lookAt(pos, pos + VEHICLE_DIR[v.dir])
		Props.build(v.id, g, cf, { lit = v.id == "taxi" or v.id == "city_bus", seed = "vehicle" .. i })
	end
	return g
end

local function steamStack(parent: Instance, pos: Vector3, i: number)
	local g = Kit.model(parent, "SteamStack")
	local base = CFrame.new(pos.X, ROAD, pos.Z)
	local orange = Look.hex("#F28C28")
	Kit.cylinder(g, base * CFrame.new(0, 3.2, 0), 6.4, 2.2, Look.white, M.SmoothPlastic).Name = "Stack"
	for k = 0, 2 do
		Kit.cylinder(
			g,
			base * CFrame.new(0, 1.0 + k * 2.1, 0),
			0.9,
			2.3,
			orange,
			M.SmoothPlastic,
			{ CanCollide = false }
		)
	end
	local mouth = Kit.cylinder(g, base * CFrame.new(0, 6.5, 0), 0.3, 1.8, Look.iron, M.Metal, { CanCollide = false })
	mouth.Name = "Mouth"
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "Steam"
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Rate = 5
	steam.Lifetime = NumberRange.new(2.5, 4)
	steam.Speed = NumberRange.new(3, 5)
	steam.SpreadAngle = Vector2.new(10, 10)
	steam.Acceleration = Vector3.new(0.6, 0.8, 0.3)
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 7) })
	steam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	steam.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
	steam.LightInfluence = 1
	steam.EmissionDirection = Enum.NormalId.Right -- a Kit cylinder's local +X is its axis (straight up here)
	steam.Parent = mouth
	-- a couple of baked puffs so the stack reads as steaming even before particles start
	local rng = Rng.new("steam" .. i)
	for k = 1, 2 do
		local puff = Kit.ball(
			g,
			base * CFrame.new(rng:range(-0.5, 0.5), 7.6 + k * 1.6, rng:range(-0.5, 0.5)),
			2 + k,
			Look.white,
			M.SmoothPlastic,
			{
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
			}
		)
		puff.Transparency = 0.55 + k * 0.12
	end
end

-- A glass bus shelter: steel posts, a glass back and end panel, a bench, a lit advert and the stop's sign.
local function busShelter(parent: Instance, cf: CFrame)
	local g = Kit.model(parent, "BusShelter")
	local W, D, H = 12, 4.4, 8.4
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.block(
				g,
				cf * CFrame.new(sx * (W / 2 - 0.2), H / 2, sz * (D / 2 - 0.2)),
				Vector3.new(0.35, H, 0.35),
				Look.steelDark,
				M.Metal
			)
		end
	end
	Kit.block(g, cf * CFrame.new(0, H + 0.2, 0), Vector3.new(W + 0.6, 0.4, D + 0.8), Look.steelDark, M.Metal).Name =
		"Roof"
	local back = Kit.block(
		g,
		cf * CFrame.new(0, H / 2 + 0.4, D / 2 - 0.2),
		Vector3.new(W - 0.5, H - 1.6, 0.15),
		Look.lobbyGlass,
		M.Glass,
		{
			Transparency = 0.6,
			CastShadow = false,
		}
	)
	back.Name = "BackGlass"
	local ad = Kit.block(
		g,
		cf * CFrame.new(-W / 2 + 0.2, H / 2 + 0.4, 0),
		Vector3.new(0.3, H - 1.6, D - 0.6),
		Look.white,
		M.SmoothPlastic
	)
	ad.Name = "Advert"
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui, gw, gh = Deps.Gui.Core.surface(ad, face, { glow = true, pps = 30, maxDistance = 120 })
		Deps.Gui.Art.ad(gui, Text.get("billboard_brand2"), Text.get("billboard_slogan2"), Rng.new("shelter-ad"), gw, gh)
	end
	Kit.block(g, cf * CFrame.new(1, 1.6, D / 2 - 0.9), Vector3.new(W - 4, 0.3, 1.2), Look.steel, M.Metal).Name = "Bench"
	local sign = Kit.detail(
		g,
		cf * CFrame.new(0, H + 0.95, -D / 2 - 0.3),
		Vector3.new(W * 0.7, 1.1, 0.12),
		Look.navy,
		M.SmoothPlastic
	)
	Kit.sign(
		sign,
		Text.get("bus_stop"),
		{ color = Look.white, font = Enum.Font.GothamBold, glow = true, pixelsPerStud = 40 }
	)
	local glow = Kit.detail(g, cf * CFrame.new(0, H - 0.05, 0), Vector3.new(W - 1, 0.1, 1), Look.coolLight, M.Neon)
	glow.CastShadow = false
	glow:AddTag("StreetLight")
end

local function fixtures(m: Instance)
	local g = Kit.model(m, "Fixtures")
	for i, c in Plan.foodCarts do
		Props.build("food_cart", g, faceAt(c.pos, c.face), { variant = c.variant, seed = "cart" .. i })
	end
	Props.build("bike_share_dock", g, faceAt(Plan.bikeDock.pos, Plan.bikeDock.face), { count = 6, seed = "bikes" })
	Props.build("phone_booth", g, faceAt(Plan.phoneBooth.pos, Plan.phoneBooth.face), { seed = "phone" })
	busShelter(g, faceAt(Plan.busStop.pos, Plan.busStop.face))
	Props.build("street_clock", g, floorAt(Plan.streetClock, Vector3.new(0, 0, -1)), { seed = "post-clock" })
	for i, a in Plan.atms do
		Props.build("atm", g, faceAt(a.pos, a.face), { seed = "atm" .. i })
	end
	local shed = Props.build(
		"scaffold",
		g,
		faceAt(Plan.scaffold.pos, Plan.scaffold.face),
		{ bays = 2, levels = 2, seed = "shed" }
	)
	shed.Name = "SidewalkShed"
	for i, b in Plan.billboards do
		local pos = b.pos
		local cf = CFrame.lookAt(pos, pos + Plan.FACE_DIR[b.face])
		Signs.billboard(g, cf, {
			brand = Text.get(b.brand),
			slogan = Text.get(b.slogan),
			width = 36,
			height = 14,
			legs = 6,
			seed = "billboard" .. i,
		})
	end
	for i, v in Plan.steamVents do
		steamStack(g, v, i)
	end
	-- bollards where the plaza meets the avenue sidewalks
	for _, z in { Plan.plaza.z0 + 1.5, Plan.plaza.z1 - 1.5 } do
		for x = -40, 40, 10 do
			Props.build("bollard", g, CFrame.new(x, FLOOR, z), { seed = ("bollard:%d:%d"):format(x, z) })
		end
	end
	return g
end

local function briefcases(m: Instance)
	local g = Kit.model(m, "BriefcaseSpots")
	local ids: { string } = {}
	for id in Plan.briefcases do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local v = Plan.briefcases[id]
		Kit.eventSpot(g, id, CFrame.new(v.X, FLOOR + 0.5, v.Z), Vector3.new(3, 1, 3))
	end
	return g
end

function Life.build(parent: Instance): Model
	local m = Kit.model(parent, "StreetLife")
	local zones = keepOuts()
	intersections(m, zones)
	curbs(m, zones)
	vehicles(m)
	fixtures(m)
	briefcases(m)
	return m
end

return Life
