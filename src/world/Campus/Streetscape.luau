--!strict
-- Eastbridge's street furniture along the avenue and Mill Street: sodium lamps (a few dead, a few flickering), creosote
-- utility poles with sagging wires and flyers, parked beaters in the parking lanes, hydrants, mailboxes, newspaper
-- boxes and bins, street-name signs and a blinking signal at the Mill Street crossing, the Route 9 stop by the quad,
-- tree pits with dead trees, posters on the walls, and barricades where the roads leave town. Bake-safe.

local Deps = require(script.Parent.Deps)
local Plan = require(script.Parent.Plan)
local Geo = require(script.Parent.Geo)
local Text = require(script.Parent.Text)
local Dress = require(script.Parent.Dress)

local Kit = Deps.Kit
local Props = Deps.Props
local Signs = Deps.Signs
local P = Deps.Palette
local C = P.campus
local hex = P.hex
local M = Enum.Material

local Streetscape = {}

local WALK = Plan.WALK

local function lamps(m: Instance)
	local north = { -232, -190, -140, -104, -50, 0, 40, 132, 175, 206 }
	local south = { -244, -204, -160, -116, -70, -32, 10, 50, 140, 190 }
	local dead = { [-140] = true, [10] = true, [175] = true }
	-- every other working lamp casts real light; the rest only glow
	for i, x in north do
		Dress.lamp(m, x, -15.6, Plan.S, { lit = not dead[x], light = i % 2 == 1, seed = "av-n" .. x })
	end
	for i, x in south do
		Dress.lamp(m, x, 15.6, Plan.N, { lit = not dead[x], light = i % 2 == 0, seed = "av-s" .. x })
	end
	local mill = Plan.mill
	for i, z in { -200, -120, -56, 60, 150 } do
		Dress.lamp(m, mill.walkW[2] - 0.8, z, Plan.E, { lit = z ~= -120, light = i % 2 == 1, seed = "mill-w" .. z })
	end
	for i, z in { -180, -40, 104, 184 } do
		Dress.lamp(m, mill.walkE[1] + 0.8, z, Plan.W, { light = i % 2 == 0, seed = "mill-e" .. z })
	end
end

local function poles(m: Instance, rng: Deps.RngT)
	-- one run along the south side of the avenue (wires sag between the poles), one up Mill Street
	local runs = {
		{ { -240, 17.4 }, { -180, 17.4 }, { -122, 17.4 }, { -62, 17.4 }, { -2, 17.4 }, { 56, 17.4 } },
		{ { 136, 17.4 }, { 196, 17.4 } },
		{ { 118.6, -60 }, { 118.6, -120 }, { 118.6, -180 }, { 118.6, -236 } },
	}
	local tops: { Vector3 } = {}
	for r, run in runs do
		local prev: Vector3? = nil
		for i, pt in run do
			local top = Dress.pole(m, pt[1], pt[2], rng, { transformer = i == 3, flyers = if r == 3 then 1 else nil })
			if r == 1 then
				tops[i] = top
			end
			if prev then
				for _, dx in { -3, -1.2, 1.2 } do
					local off = if r == 3 then Vector3.new(0, 0, dx) else Vector3.new(dx, 0, 0)
					Dress.wire(m, prev + off, top + off, rng:range(1.4, 2.6))
				end
			end
			prev = top
		end
	end
	-- a service drop crossing the avenue to Halvorsen Hall, and one into the Grind House
	Dress.wire(m, tops[2] + Vector3.new(3, 0, 0), Plan.v(-176, WALK + 24, -31.8), 2.5)
	Dress.wire(m, tops[5] + Vector3.new(-3, 0, 0), Plan.v(-18, WALK + 22, 25.8), 1.2)
end

local function cars(m: Instance, rng: Deps.RngT)
	local list: { { x: number, z: number, yaw: number, color: Color3 } } = {
		{ x = -170, z = -10.5, yaw = Plan.W, color = hex("#5B4A3A") },
		{ x = -22, z = -10.5, yaw = Plan.W, color = hex("#3E5A6E") },
		{ x = 140, z = -10.5, yaw = Plan.W, color = hex("#8A8780") },
		{ x = -104, z = 10.5, yaw = Plan.E, color = hex("#6E2E2A") },
		{ x = 30, z = 10.5, yaw = Plan.E, color = hex("#2E3A2E") },
		{ x = 182, z = 10.5, yaw = Plan.E, color = hex("#B8B09A") },
	}
	for i, c in list do
		Props.build("sedan", m, Plan.cf(c.x, 0, c.z, c.yaw + rng:range(-2, 2)), { color = c.color, seed = "parked" .. i })
	end
end

local function furniture(m: Instance, rng: Deps.RngT)
	for i, h in { { -210, -17.4 }, { -60, 17.4 }, { 66, -17.4 }, { 110, 17.4 }, { 200, -17.4 }, { 70, 120 } } do
		Props.build("fire_hydrant", m, Plan.cf(h[1], WALK, h[2], rng:range(0, 360)), { seed = "hyd" .. i })
	end
	Props.build("mailbox", m, Plan.cf(-118, WALK, -18, Plan.S), { seed = "mail1" })
	Props.build("mailbox", m, Plan.cf(64, WALK, 18, Plan.N), { seed = "mail2" })
	for i, n in { { -64, -24.5, Plan.S }, { -62, -24.5, Plan.S }, { 112, 22, Plan.N } } do
		Props.build("newspaper_box", m, Plan.cf(n[1], WALK, n[2], n[3]), { seed = "news" .. i })
	end
	for i, t in { { -170, -18 }, { -14, 18 }, { 76, -24 }, { 112, -60 }, { 160, 18 }, { -232, 18 } } do
		Props.build("trash_can", m, Plan.cf(t[1], WALK, t[2], rng:range(0, 360)), { seed = "bin" .. i })
	end
	-- the Route 9 stop on the north walk by the quad gate
	Props.build("bus_shelter", m, Plan.cf(-44, WALK, -21.5, Plan.S), { seed = "route9-stop" })
	local post = Plan.cf(-34, WALK, -16.4)
	Kit.block(m, post * CFrame.new(0, 4.5, 0), Vector3.new(0.3, 9, 0.3), C.steel, M.Metal).Name = "StopPole"
	local sign = Kit.detail(m, post * CFrame.new(0, 8, -0.2), Vector3.new(1.6, 1.8, 0.06), hex("#1F4E8C"), M.Metal)
	Kit.sign(sign, "BUS\n9", { font = Enum.Font.Highway, color = hex("#F4F1E6"), pixelsPerStud = 40 })
	-- street names and the blinking signal at the Mill Street crossing
	local mill = Plan.mill
	Signs.streetName(m, Plan.cf(mill.walkW[1] + 1, WALK, -24.5, 0), { text = Text.streets.avenue, text2 = Text.streets.mill })
	Signs.streetName(m, Plan.cf(mill.walkE[2] - 1, WALK, 24.5, 180), { text = Text.streets.avenue, text2 = Text.streets.mill })
	Props.build("traffic_light", m, Plan.cf(mill.walkW[2] - 1, WALK, -15.4, Plan.S), { seed = "signal1" })
	Props.build("traffic_light", m, Plan.cf(mill.walkE[1] + 1, WALK, 15.4, Plan.N), { seed = "signal2" })
	-- tree pits with dead trees on the north walk
	for _, x in { -216, -160, -124, 20, 150 } do
		Kit.detail(m, Plan.cf(x, WALK + 0.03, -22), Vector3.new(4, 0.06, 4), C.dirt, M.Ground).Name = "TreePit"
		Geo.bareTree(m, Plan.v(x, WALK, -22), rng, 0.8)
	end
	Props.build("bike_rack", m, Plan.cf(-140, WALK, 22, Plan.N), { seed = "av-bikes" })
	Props.build("bench_worn", m, Plan.cf(190, WALK, -22, Plan.S), { seed = "av-bench" })
end

local function barricades(m: Instance)
	local mill = Plan.mill
	local av = Plan.avenue
	local function closed(cf: CFrame, span: number, seed: string)
		Props.build("jersey_barrier", m, cf * CFrame.new(-span / 4, 0, 0), { length = span / 2 - 0.5, seed = seed .. "a" })
		Props.build("jersey_barrier", m, cf * CFrame.new(span / 4, 0, 0), { length = span / 2 - 0.5, seed = seed .. "b" })
		-- a sawhorse sign on the town side
		local s = cf * CFrame.new(0, 0, -3)
		for _, dx in { -2.2, 2.2 } do
			Kit.detail(m, s * CFrame.new(dx, 1.6, 0), Vector3.new(0.3, 3.2, 1.4), hex("#E9E2CF"), M.Wood)
		end
		local board = Kit.block(m, s * CFrame.new(0, 2.8, 0), Vector3.new(6, 1.4, 0.2), hex("#E86A1E"), M.Wood)
		board.Name = "RoadClosed"
		Kit.sign(board, Text.roadClosed, { font = Enum.Font.Highway, color = hex("#141414"), pixelsPerStud = 30 })
	end
	closed(Plan.cf((mill.x0 + mill.x1) / 2, 0, Plan.PLAY.z0 + 4, Plan.S), mill.x1 - mill.x0, "mill-n")
	closed(Plan.cf((mill.x0 + mill.x1) / 2, 0, Plan.PLAY.z1 - 4, Plan.N), mill.x1 - mill.x0, "mill-s")
	closed(Plan.cf(Plan.PLAY.x0 + 4, 0, (av.z0 + av.z1) / 2, Plan.E), av.z1 - av.z0, "av-w")
end

local function posters(m: Instance)
	-- (cf on a wall face, LookVector out of the wall)
	local spots = {
		Plan.cf(-171.97, WALK + 6, -40, Plan.E), -- Halvorsen, by the side gate
		Plan.cf(119.95, WALK + 6, 40, Plan.W), -- the hardware store on Mill Street
		Plan.cf(119.95, WALK + 6, 46, Plan.W),
		Plan.cf(2 - 0.05, WALK + 6, -60, Plan.W), -- Marlow House
		Plan.cf(-55.97, WALK + 6, 34, Plan.E), -- the alley walls
		Plan.cf(-44.03, WALK + 6, 50, Plan.W),
		Plan.cf(128 - 0.05, WALK + 6, -90, Plan.W), -- the station's Mill Street wall
	}
	for i, cf in spots do
		Dress.poster(m, cf, i, "wall-poster" .. i)
	end
	Dress.flyerSheet(m, Plan.cf(-44.04, WALK + 4.5, 40, Plan.W), 5, 3, {
		Text.flyers[2],
		Text.flyers[6],
		Text.flyers[9],
	}, "alley-flyers")
end

function Streetscape.build(parent: Instance): Model
	local m = Kit.model(parent, "Streetscape")
	local rng = Deps.Rng.new("streetscape")
	lamps(m)
	poles(m, rng)
	cars(m, rng)
	furniture(m, rng)
	barricades(m)
	posters(m)
	return m
end

return Streetscape
