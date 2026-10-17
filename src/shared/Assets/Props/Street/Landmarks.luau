--!strict
-- Wall Street district landmarks (category "street"): subway entrance, fountain and the
-- bull-and-bear sculpture "The Contest".

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
local S = Kit.Palette.street
local shade = Kit.shade
local hex = Kit.hex

local IRON_GREEN = hex("#1F3B2E")

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

---------------------------------------------------------------------------------------------------
-- subway_entrance: granite-walled stair opening with green iron railings, two globe lamps and a SUBWAY
-- sign. The descending stairs are painted (props never cut the ground); people enter from -Z.
---------------------------------------------------------------------------------------------------
add({
	id = "subway_entrance",
	category = "street",
	footprint = V(7.7, 7.8, 13.15),
	maxParts = 30,
	tags = { "street", "transit", "light" },
	build = function(c: Ctx)
		local iron = c.color("color", IRON_GREEN)
		local stone = c.color("accent", S.granite)
		local lit = c.bool("lit", true)
		local W, L = 6, 12
		local well = c.part(P(0, 0.03, 0) * R(90, 0, 0) * R(0, 0, 180), V(W, L, 0.06), hex("#3A3C40"), M.Concrete)
		well.Name = "Stairwell"
		Gui.Art.stairwell(
			(Gui.Core.surface(well, Enum.NormalId.Front, { pps = 16, maxDistance = 150 })),
			14,
			hex("#B9B6AE"),
			hex("#101114")
		)
		for _, sx in { -1, 1 } do
			c.part(P(sx * 3.3, 0.5, 0), V(0.6, 1.0, L), stone, M.Granite)
		end
		c.part(P(0, 0.5, 6.3), V(W + 1.2, 1.0, 0.6), stone, M.Granite)
		c.detail(P(0, 0.07, -5.9), V(W, 0.04, 0.2), hex("#C9B458"), M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			Shapes.rail(c, V(sx * 3.3, 1.0, -5.5), V(sx * 3.3, 1.0, 6.0), 2.6, 4, 0.16, iron, M.Metal)
		end
		Shapes.rail(c, V(-3.0, 1.0, 6.3), V(3.0, 1.0, 6.3), 2.6, 3, 0.16, iron, M.Metal)
		for _, sx in { -1, 1 } do
			c.dcyl(P(sx * 3.3, 3.75, -6.0), 5.5, 0.3, iron, M.Metal)
			local globe = Shapes.bulb(c, P(sx * 3.3, 7.05, -6.0), 1.1, hex("#9FE3A8"), lit, 0.15)
			globe.Name = "Globe"
			c.tag(globe, "StreetLight")
			Shapes.lamp(globe, lit, hex("#D9FFE0"), 20, 1.0)
			c.dcyl(P(sx * 3.3, 7.68, -6.0), 0.15, 0.6, iron, M.Metal)
		end
		local sign = c.detail(P(0, 5.6, -6.0), V(6.3, 0.9, 0.12), S.black, M.SmoothPlastic)
		sign.Name = "SubwaySign"
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			c.sign(
				sign,
				Words.subway,
				{ face = face, font = Enum.Font.GothamBold, color = S.white, pixelsPerStud = 40, glow = lit }
			)
		end
		c.use(V(0, 2.5, -6.5))
	end,
})

---------------------------------------------------------------------------------------------------
-- fountain: granite basin with a segmented rim, a limestone pedestal and bowl, a water curtain, a jet and
-- underwater lights (opts.lit, default true). The water discs are named "Water".
---------------------------------------------------------------------------------------------------
add({
	id = "fountain",
	category = "street",
	footprint = V(14.2, 8.85, 14.2),
	maxParts = 34,
	tags = { "street", "water", "landmark" },
	build = function(c: Ctx)
		local stone = c.color("color", S.granite)
		local lime = c.color("accent", S.limestone)
		local waterC = col.water
		local lit = c.bool("lit", true)
		c.cyl(P(0, 0.9, 0), 1.8, 14, stone, M.Granite)
		for k = 0, 11 do
			c.detail(R(0, k * 30, 0) * P(6.75, 1.95, 0), V(0.7, 0.3, 3.7), shade(stone, 0.2), M.Granite)
		end
		local water = c.dcyl(P(0, 1.82, 0), 0.06, 12.8, waterC, M.Glass)
		water.Name = "Water"
		water.Transparency = 0.25
		water.Reflectance = 0.2
		c.dcyl(P(0, 2.0, 0), 0.4, 2.0, lime, M.Limestone)
		c.cyl(P(0, 3.4, 0), 3.2, 1.2, lime, M.Limestone)
		c.dcyl(P(0, 4.82, 0), 0.3, 3.0, lime, M.Limestone)
		c.dcyl(P(0, 5.2, 0), 0.5, 4.6, lime, M.Limestone)
		local bowl = c.dcyl(P(0, 5.47, 0), 0.04, 4.2, waterC, M.Glass)
		bowl.Name = "Water"
		bowl.Transparency = 0.25
		local curtain = c.dcyl(P(0, 3.6, 0), 3.5, 4.3, shade(waterC, 0.45), M.Glass)
		curtain.Transparency = 0.8
		c.dcyl(P(0, 6.2, 0), 1.5, 0.5, lime, M.Limestone)
		c.dball(P(0, 7.1, 0), 0.8, S.brass, M.Metal)
		local jet = c.dcyl(P(0, 7.9, 0), 1.0, 0.25, shade(waterC, 0.6), M.Glass)
		jet.Transparency = 0.4
		local spray = c.dball(P(0, 8.4, 0), 0.9, shade(waterC, 0.6), M.Glass)
		spray.Transparency = 0.6
		for k = 0, 3 do
			local a = math.rad(k * 90 + 45)
			local pos = P(math.cos(a) * 4.6, 1.76, math.sin(a) * 4.6)
			if lit then
				c.glow(pos, V(0.5, 0.05, 0.5), S.warmLight, 0.3)
			else
				c.detail(pos, V(0.5, 0.05, 0.5), S.steelBrushed, M.Metal)
			end
		end
		for _ = 1, 3 do
			local a = c.rng:range(0, math.pi * 2)
			local rr = c.rng:range(2.5, 5.5)
			c.dcyl(P(math.cos(a) * rr, 1.8, math.sin(a) * rr), 0.02, 0.22, S.gold, M.Metal)
		end
		c.use(V(0, 2.2, -7.4))
	end,
})

---------------------------------------------------------------------------------------------------
-- bull_bear_statue: "The Contest", a large fictional bronze of a charging bull meeting a rearing bear on a
-- granite plinth with a brass plaque. An original stylized composition, not a copy of any real artwork.
---------------------------------------------------------------------------------------------------
add({
	id = "bull_bear_statue",
	category = "street",
	footprint = V(16.6, 8.75, 7.6),
	maxParts = 44,
	tags = { "street", "landmark", "art", "statue" },
	build = function(c: Ctx)
		local stone = c.color("accent", S.granite)
		local bronze = c.color("color", col.bronze)
		local dark = shade(bronze, -0.3)
		local B = M.Metal
		c.detail(P(0, 0.15, 0), V(16.6, 0.3, 7.6), shade(stone, -0.15), M.Granite)
		c.part(P(0, 1.15, 0), V(16, 1.7, 7), stone, M.Granite)
		c.detail(P(0, 2.1, 0), V(16.4, 0.25, 7.4), shade(stone, 0.2), M.Granite)
		local plaque = c.detail(P(0, 1.15, -3.53), V(4.4, 1.1, 0.06), S.brass, M.Metal)
		plaque.Name = "Plaque"
		local gui = Gui.Core.surface(plaque, Enum.NormalId.Front, { pps = 60, maxDistance = 60 })
		Gui.Core.label(gui, Words.statueTitle, 0.05, 0.08, 0.9, 0.45, S.black, {
			font = Enum.Font.Bodoni,
			align = Enum.TextXAlignment.Center,
		})
		Gui.Core.label(gui, Words.statueSub, 0.05, 0.58, 0.9, 0.3, S.black, {
			font = Enum.Font.Garamond,
			align = Enum.TextXAlignment.Center,
		})
		-- Both animals are modelled from capsules (a cylinder capped by balls) so the bronze reads as
		-- smooth cast metal rather than boxes. The big masses collide; limbs, horns and ears are trim.
		local top = 2.225 -- plinth cap surface
		-- the bull (left), shoulders high and head low, charging toward +X with its tail whipping up
		local bull = -4.3
		c.cylX(P(bull, 5.0, 0) * R(0, 0, 7), 3.3, 2.7, bronze, B) -- barrel
		c.ball(P(bull + 1.65, 5.35, 0), 3.05, bronze, B) -- shoulder hump
		c.ball(P(bull - 1.75, 4.85, 0), 2.6, bronze, B) -- haunch
		Shapes.tube(c, V(bull + 2.4, 5.5, 0), V(bull + 3.75, 4.35, 0), 1.75, bronze, B) -- neck
		c.detail(P(bull + 4.1, 3.95, 0) * R(0, 0, -38), V(1.25, 1.35, 1.3), bronze, B) -- head
		c.dball(P(bull + 4.55, 3.45, 0), 1.0, shade(bronze, -0.12), B) -- muzzle
		for _, sz in { -1, 1 } do
			-- horns sweep out from the poll, then forward and up toward the bear
			local root = V(bull + 3.9, 4.6, sz * 0.5)
			local bend = V(bull + 3.95, 4.95, sz * 1.35)
			Shapes.tube(c, root, bend, 0.42, dark, B)
			Shapes.tube(c, bend, V(bull + 4.85, 5.55, sz * 1.5), 0.28, dark, B)
			-- forelegs braced back under the hump, hind legs driving out behind
			Shapes.tube(c, V(bull + 1.5, 4.3, sz * 0.8), V(bull + 2.5, top + 0.3, sz * 0.85), 0.88, bronze, B)
			c.dcyl(P(bull + 2.55, top + 0.15, sz * 0.85), 0.3, 0.85, dark, B)
			Shapes.tube(c, V(bull - 1.6, 4.3, sz * 0.8), V(bull - 3.0, top + 0.3, sz * 0.9), 0.98, bronze, B)
			c.dcyl(P(bull - 3.05, top + 0.15, sz * 0.9), 0.3, 0.9, dark, B)
		end
		Shapes.tube(c, V(bull - 2.9, 5.5, 0), V(bull - 3.5, 6.75, 0.25), 0.22, dark, B) -- tail
		c.dball(P(bull - 3.55, 6.85, 0.27), 0.42, dark, B)
		-- the bear (right), reared up on its haunches toward -X, one paw raised to swipe
		local bear = 4.4
		c.ball(P(bear + 0.4, 3.75, 0), 3.0, dark, B) -- haunches
		Shapes.tube(c, V(bear + 0.4, 4.1, 0), V(bear - 0.55, 6.45, 0), 2.45, dark, B) -- torso
		c.ball(P(bear - 0.6, 6.4, 0), 2.6, dark, B) -- chest and shoulders
		c.dball(P(bear - 1.35, 7.65, 0), 1.75, dark, B) -- head
		c.dcylX(P(bear - 2.3, 7.5, 0), 0.8, 0.8, shade(dark, 0.08), B) -- snout
		c.dball(P(bear - 2.72, 7.55, 0), 0.36, shade(dark, -0.35), B) -- nose
		for _, sz in { -1, 1 } do
			c.dball(P(bear - 1.15, 8.4, sz * 0.62), 0.55, dark, B) -- ears
			-- hind leg and broad foot planted on the plinth
			Shapes.tube(c, V(bear + 0.2, 3.5, sz * 0.95), V(bear - 0.35, top + 0.35, sz * 1.0), 1.0, dark, B)
			c.detail(P(bear - 0.55, top + 0.18, sz * 1.0), V(1.4, 0.36, 0.85), dark, B)
		end
		-- near arm (-Z) raised high for the swipe; far arm (+Z) guarding low
		Shapes.tube(c, V(bear - 0.7, 6.75, -1.0), V(bear - 2.3, 7.35, -1.3), 0.85, dark, B)
		c.dball(P(bear - 2.45, 7.4, -1.32), 0.95, dark, B)
		Shapes.tube(c, V(bear - 0.8, 6.3, 1.0), V(bear - 2.1, 5.55, 1.25), 0.85, dark, B)
		c.dball(P(bear - 2.25, 5.5, 1.27), 0.9, dark, B)
		c.use(V(0, 2.5, -4.3))
	end,
})

return defs
