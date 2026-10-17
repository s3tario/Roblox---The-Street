--!strict
-- Eastbridge yards, lots and back alleys (gritty): chain-link fence, bike rack, jersey barrier, fire escape,
-- AC condenser, pallet stack and puddle.

local Common = require(script.Parent.Parent.Common)
local Shapes = require(script.Parent.Parent.Shapes)
local Gui = require(script.Parent.Parent.Gui)
local Words = require(script.Parent.Parent.Words)
local Kit = require(script.Parent.Parent.Parent.Parent.Build.Kit)

type Ctx = Common.Ctx
type Def = Common.Def

local P, R = Common.P, Common.R
local V = Vector3.new
local M = Enum.Material
local col = Common.col
local C = Kit.Palette.campus
local shade = Kit.shade
local hex = Kit.hex

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

---------------------------------------------------------------------------------------------------
-- chainlink_fence: opts.length (4-40, default 12) along X, posts every ~8 studs (some leaning), top
-- rail, and a collidable mesh panel per bay whose wire diamonds are SurfaceGui lines on both faces.
-- opts.barbed = true adds barbed-wire arms on top.
---------------------------------------------------------------------------------------------------
add({
	id = "chainlink_fence",
	category = "campus",
	footprint = V(12.4, 7.55, 0.5),
	maxParts = 40,
	tags = { "fence", "gritty", "structure" },
	scales = { length = 40, barbed = true },
	build = function(c: Ctx)
		local L = c.num("length", 12, 4, 40)
		local Hh = 7
		local metal = c.color("color", C.chainlink)
		local panels = math.max(1, math.ceil(L / 8 - 1e-6))
		local pw = L / panels
		local barbed = c.bool("barbed", false)
		for i = 0, panels do
			local x = -L / 2 + i * pw
			local lean = P(x, 0.02, 0) * R(c.rng:range(-2, 2), 0, c.rng:range(-2, 2))
			c.cyl(lean * P(0, (Hh + 0.4) / 2, 0), Hh + 0.4, 0.22, shade(metal, c.rng:range(-0.2, 0)), M.Metal)
			c.dcyl(lean * P(0, Hh + 0.45, 0), 0.1, 0.3, shade(metal, -0.2), M.Metal)
			if barbed then
				c.detail(lean * P(0, Hh + 0.75, 0.25) * R(45, 0, 0), V(0.08, 0.9, 0.08), shade(metal, -0.3), M.Metal)
			end
		end
		for i = 1, panels do
			local x = -L / 2 + (i - 0.5) * pw
			c.dcylX(P(x, Hh, 0), pw, 0.14, metal, M.Metal)
			local mesh = c.part(
				P(x, Hh / 2 + 0.15, 0) * R(0, 0, c.rng:range(-0.5, 0.5)),
				V(pw - 0.1, Hh - 0.3, 0.06),
				metal,
				M.Metal
			)
			mesh.Name = "Mesh"
			mesh.Transparency = 0.88
			mesh.CastShadow = false
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local gui, gw, gh = Gui.Core.surface(mesh, face, { pps = 8, maxDistance = 110, name = "Wire" })
				Gui.Art.chainlink(gui, gw, gh, 5, shade(metal, -0.1))
			end
			if barbed then
				for _, k in { 1, 2 } do
					Shapes.tube(
						c,
						V(x - pw / 2, Hh + 0.6 + k * 0.25, 0.1 + k * 0.18),
						V(x + pw / 2, Hh + 0.6 + k * 0.25, 0.1 + k * 0.18),
						0.05,
						shade(metal, -0.35),
						M.Metal
					)
				end
			end
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- bike_rack: three galvanised hoops with a bike locked to the middle one, and sometimes a lone wheel
-- left chained to another
---------------------------------------------------------------------------------------------------
add({
	id = "bike_rack",
	category = "campus",
	footprint = V(5.0, 2.85, 5.8),
	maxParts = 24,
	tags = { "street", "gritty", "bike" },
	build = function(c: Ctx)
		local metal = c.color("accent", C.chainlink)
		for i = -1, 1 do
			local x = i * 2.4
			for _, sz in { -1, 1 } do
				c.cyl(P(x, 1.35, sz * 0.6), 2.7, 0.18, metal, M.Metal)
			end
			c.cylZ(P(x, 2.7, 0), 1.38, 0.18, metal, M.Metal)
		end
		local frame = c.color("color", c.rng:pick({ hex("#2C5E8A"), hex("#8A2C2C"), hex("#3F6B3A"), hex("#C9A13B") }))
		Shapes.bike(c, P(0.4, 0, 0), frame, { basket = c.rng:chance(0.4) })
		if c.rng:chance(0.4) then
			c.dcylX(P(-2.25, 1.16, 0.25), 0.14, 2.3, col.rubber, M.Rubber)
			c.dcylX(P(-2.25, 1.16, 0.25), 0.18, 0.5, col.chrome, M.Metal)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- jersey_barrier: concrete safety-shape barrier with stains, a chipped edge, lifting slots and maybe a
-- spray-painted tag. opts.length (4-20, default 10)
---------------------------------------------------------------------------------------------------
add({
	id = "jersey_barrier",
	category = "campus",
	footprint = V(10, 2.7, 2.0),
	maxParts = 14,
	tags = { "street", "gritty", "barrier" },
	build = function(c: Ctx)
		local L = c.num("length", 10, 4, 20)
		local con = c.color("color", C.concrete)
		c.part(P(0, 0.15, 0), V(L, 0.3, 2.0), con, M.Concrete)
		c.part(P(0, 0.55, 0), V(L, 0.5, 1.4), con, M.Concrete)
		c.part(P(0, 1.75, 0), V(L, 1.9, 0.6), con, M.Concrete)
		for _, sz in { -1, 1 } do
			local flip = if sz > 0 then R(0, 180, 0) else CFrame.identity
			c.wedge(P(0, 0.55, sz * 0.85) * flip, V(L, 0.5, 0.3), con, M.Concrete)
			c.wedge(P(0, 1.75, sz * 0.5) * flip, V(L, 1.9, 0.4), con, M.Concrete)
		end
		-- weathering on the front face (upper slope leans back 11.9 degrees)
		local function onSlope(x: number, y: number): CFrame
			return P(x, y, -0.3 - (2.7 - y) / 1.9 * 0.4 - 0.012) * R(11.9, 0, 0)
		end
		for _ = 1, 2 do
			c.detail(
				onSlope(c.rng:range(-L / 2 + 1, L / 2 - 1), c.rng:range(1.2, 2.2)),
				V(c.rng:range(0.3, 0.8), c.rng:range(0.6, 1.2), 0.02),
				C.concreteStain,
				M.Concrete
			)
		end
		for _, sx in { -1, 1 } do
			c.detail(P(sx * L / 4, 0.15, -1.005), V(0.8, 0.2, 0.02), C.concreteDark, M.Concrete)
		end
		c.detail(P(c.rng:range(-L / 2 + 0.5, L / 2 - 0.5), 2.68, 0), V(0.5, 0.06, 0.62), C.concreteDark, M.Concrete)
		if c.rng:chance(0.5) then
			local carrier = c.detail(onSlope(c.rng:range(-L / 4, L / 4), 1.8), V(3, 1, 0.01), Color3.new(1, 1, 1))
			carrier.Transparency = 1
			c.sign(carrier, c.rng:pick(Words.graffiti), {
				font = Enum.Font.PermanentMarker,
				color = c.rng:pick({ C.graffitiTeal, C.graffitiMagenta }),
				pixelsPerStud = 30,
			})
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- fire_escape: rusty platforms, railings, zig-zag stairs and a drop ladder for a brick facade.
-- Wall mount (cf = foot of the wall at ground level). opts.floors (1-8, default 3) platforms, starting
-- one storey up; opts.storey (8-16, default 12) floor-to-floor height.
---------------------------------------------------------------------------------------------------
add({
	id = "fire_escape",
	category = "campus",
	footprint = V(12.2, 39.6, 4.15),
	maxParts = 150,
	tags = { "structure", "gritty", "wall" },
	mount = "wall",
	scales = { floors = 8, storey = 16 },
	build = function(c: Ctx)
		local floors = c.int("floors", 3, 1, 8)
		local storey = c.num("storey", 12, 8, 16)
		local W, D = 12, 4
		local rust = c.color("color", C.rust)
		local function tone(): Color3
			return shade(rust, c.rng:range(-0.25, 0.1))
		end
		for k = 1, floors do
			local y = storey * k
			c.part(P(0, y, -D / 2 - 0.05), V(W, 0.2, D), tone(), M.DiamondPlate)
			Shapes.rail(
				c,
				V(-W / 2, y + 0.1, -D - 0.05),
				V(W / 2, y + 0.1, -D - 0.05),
				3.4,
				4,
				0.14,
				tone(),
				M.CorrodedMetal
			)
			for _, sx in { -1, 1 } do
				Shapes.tube(
					c,
					V(sx * W / 2, y + 3.5, -D - 0.05),
					V(sx * W / 2, y + 3.5 + c.rng:range(-0.15, 0.03), -0.1),
					0.14,
					tone(),
					M.CorrodedMetal
				)
				Shapes.strut(
					c,
					V(sx * (W / 2 - 0.8), y - 0.1, -D + 0.2),
					V(sx * (W / 2 - 0.8), y - 2.6, -0.06),
					0.18,
					tone(),
					M.CorrodedMetal
				)
			end
			if k > 1 then
				local y0 = storey * (k - 1) + 0.1
				local x0, x1 = -4.6, 3.6
				for _, z in { -1.6, -3.0 } do
					Shapes.strut(c, V(x0, y0, z), V(x1, y, z), 0.16, tone(), M.CorrodedMetal)
				end
				for i = 1, 6 do
					local t = i / 7
					c.detail(P(x0 + (x1 - x0) * t, y0 + (y - y0) * t, -2.3), V(0.9, 0.08, 1.4), tone(), M.DiamondPlate)
				end
			end
		end
		-- drop ladder hanging from the first platform (stops 3 studs above the ground)
		local top, bottom = storey, 3
		for _, sx in { -1, 1 } do
			c.detail(P(4.6 + sx * 0.6, (top + bottom) / 2, -3.6), V(0.12, top - bottom, 0.12), tone(), M.CorrodedMetal)
		end
		local rungs = math.max(2, math.floor((top - bottom) / 1.6))
		for i = 1, rungs do
			c.detail(
				P(4.6, bottom + (top - bottom) * (i - 0.5) / rungs, -3.6),
				V(1.2, 0.1, 0.1),
				tone(),
				M.CorrodedMetal
			)
		end
		c.use(V(4.6, storey + 2, -3))
	end,
})

---------------------------------------------------------------------------------------------------
-- ac_unit: condenser box on concrete pads with a fan grille, coil panels, copper lines and rust streaks
---------------------------------------------------------------------------------------------------
add({
	id = "ac_unit",
	category = "campus",
	footprint = V(3.6, 3.27, 3.6),
	maxParts = 16,
	tags = { "structure", "gritty", "rooftop" },
	build = function(c: Ctx)
		local body = c.color("color", hex("#B9B4A6"))
		for _, sz in { -1, 1 } do
			c.detail(P(0, 0.05, sz * 1.3), V(3.6, 0.1, 0.4), C.concrete, M.Concrete)
		end
		c.part(P(0, 1.6, 0), V(3.4, 3.0, 3.4), body, M.Metal)
		c.dcyl(P(0, 3.15, 0), 0.1, 2.6, col.plasticBlack, M.DiamondPlate)
		c.detail(P(0, 3.22, 0), V(2.6, 0.06, 0.08), C.steel, M.Metal)
		c.detail(P(0, 3.22, 0), V(0.08, 0.06, 2.6), C.steel, M.Metal)
		c.dcyl(P(0, 3.2, 0), 0.1, 0.5, C.steel, M.Metal)
		c.detail(P(0, 1.5, -1.71), V(3.0, 2.5, 0.02), shade(body, -0.45), M.DiamondPlate)
		c.detail(P(-1.71, 1.5, 0), V(0.02, 2.5, 3.0), shade(body, -0.45), M.DiamondPlate)
		c.detail(P(1.2, 2.2, -1.72), V(0.6, 0.8, 0.03), shade(body, 0.08), M.Metal)
		for _, z in { 0.6, 1.0 } do
			c.dcyl(P(1.76, 0.9, z), 1.4, 0.15, hex("#B87333"), M.Metal)
		end
		for _ = 1, 2 do
			c.detail(
				P(c.rng:range(-1.2, 1.2), c.rng:range(1.2, 2.6), -1.73),
				V(0.18, c.rng:range(0.6, 1.4), 0.01),
				C.rust,
				M.CorrodedMetal
			)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- pallet_stack: opts.count (1-5, default 3) wooden pallets stacked a little askew
---------------------------------------------------------------------------------------------------
add({
	id = "pallet_stack",
	category = "campus",
	footprint = V(4.4, 1.62, 3.6),
	maxParts = 36,
	tags = { "gritty", "clutter" },
	scales = { count = 5 },
	build = function(c: Ctx)
		local n = c.int("count", 3, 1, 5)
		local wood = c.color("color", hex("#9C7A52"))
		local y = 0
		for _ = 1, n do
			local base = P(c.rng:range(-0.12, 0.12), y, c.rng:range(-0.1, 0.1)) * R(0, c.rng:range(-4, 4), 0)
			local tone = shade(wood, c.rng:range(-0.2, 0.05))
			for _, z in { -1.4, 0, 1.4 } do
				c.part(base * P(0, 0.2, z), V(4, 0.4, 0.45), shade(tone, -0.1), M.WoodPlanks)
			end
			for _, x in { -1.6, -0.55, 0.55, 1.6 } do
				c.detail(base * P(x, 0.47, 0), V(0.7, 0.14, 3.3), tone, M.WoodPlanks)
			end
			y += 0.54
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- puddle: overlapping glossy discs; opts.size scales it (0.3-4)
---------------------------------------------------------------------------------------------------
add({
	id = "puddle",
	category = "campus",
	footprint = V(4.6, 0.03, 3.1),
	maxParts = 5,
	tags = { "gritty", "ground" },
	build = function(c: Ctx)
		local s = c.num("size", 1, 0.3, 4)
		local blobs = { { 0, 0, 3.2 }, { 1.5, 0.3, 2.0 }, { -1.4, -0.2, 1.7 }, { 0.4, -1.1, 1.1 } }
		for i, b in blobs do
			local p = c.dcyl(
				P((b[1] + c.rng:range(-0.15, 0.15)) * s, 0.011 + i * 0.002, (b[2] + c.rng:range(-0.15, 0.15)) * s),
				0.02,
				b[3] * s * c.rng:range(0.9, 1.05),
				c.color("color", C.puddle),
				M.Glass
			)
			p.Transparency = 0.25
			p.Reflectance = 0.35
		end
	end,
})

return defs
