--!strict
-- Logos: Lotus Private Wealth (design v3 §16): a lotus of seven pointed petals (a tall centre petal and three
-- layers of side petals opening outwards) over a fine waterline, with an optional dot stipple that shades
-- each petal from its base. Stipple dots come from a fixed hash, so every render is identical; `simple`
-- (small icons) drops them. Canvas: 100 units tall.

local P = require(script.Parent.Primitives)
local Colors = require(script.Parent.Colors)
local Hash = require(script.Parent.Parent.Parent.Util.Hash)

local hex = Colors.hex

type Petal = { bx: number, by: number, len: number, wid: number, angle: number, shade: number, dots: number }

-- Back to front. `shade` blends the plum towards the blush accent; `dots` is the stipple budget.
local BASE_Y = 80
local PETALS: { Petal } = {
	{ bx = 50, by = BASE_Y, len = 64, wid = 23, angle = 0, shade = 0.0, dots = 26 },
	{ bx = 47.5, by = BASE_Y, len = 54, wid = 21, angle = -27, shade = 0.16, dots = 20 },
	{ bx = 52.5, by = BASE_Y, len = 54, wid = 21, angle = 27, shade = 0.16, dots = 20 },
	{ bx = 45.5, by = BASE_Y - 0.5, len = 43, wid = 17.5, angle = -53, shade = 0.3, dots = 15 },
	{ bx = 54.5, by = BASE_Y - 0.5, len = 43, wid = 17.5, angle = 53, shade = 0.3, dots = 15 },
	{ bx = 44, by = BASE_Y - 1, len = 33, wid = 13.5, angle = -79, shade = 0.44, dots = 10 },
	{ bx = 56, by = BASE_Y - 1, len = 33, wid = 13.5, angle = 79, shade = 0.44, dots = 10 },
}

local DOT = 1.15 -- stipple dot diameter
local STEP = 2.5 -- stipple grid pitch

-- Half-width of a lens of length `len` and width `wid` at distance `u` from its middle.
local function halfWidth(len: number, wid: number, u: number): number
	local a, b = len / 2, wid / 2
	local R = (a * a / b + b) / 2
	local inside = R * R - u * u
	if inside <= 0 then
		return 0
	end
	return math.sqrt(inside) - (R - b)
end

-- Stipple points for one petal: a staggered grid over the lower part of the petal, thinning out towards the
-- tip, kept clear of the petal's edge. Returns at most `budget` points as {x, y}.
local function stipple(index: number, p: Petal): { { number } }
	local out: { { number } } = {}
	local rad = math.rad(p.angle)
	local ax, ay = math.sin(rad), -math.cos(rad) -- along the petal
	local nx, ny = math.cos(rad), math.sin(rad) -- across it
	local reach = p.len * 0.56
	local row = 0
	local s = p.len * 0.07
	while s <= reach and #out < p.dots do
		local u = s - p.len / 2
		local hw = halfWidth(p.len, p.wid, u) - DOT
		local offset = if row % 2 == 0 then 0 else STEP / 2
		local t = -hw + offset
		local col = 0
		while t <= hw and #out < p.dots do
			-- Density falls off linearly from the base to `reach`.
			local keep = 1 - (s / reach) ^ 1.3
			if Hash.unit("lotus-stipple", index, row, col) < keep then
				table.insert(out, { p.bx + ax * s + nx * t, p.by + ay * s + ny * t })
			end
			t += STEP
			col += 1
		end
		s += STEP * 0.87
		row += 1
	end
	return out
end

-- Precomputed once: the stipple never changes.
local STIPPLE: { { { number } } } = {}
for i, p in PETALS do
	STIPPLE[i] = stipple(i, p)
end

local list: { P.Spec } = {
	{
		id = "lotus_wealth",
		kind = "company",
		name = "Lotus Private Wealth",
		initials = "LW",
		colors = { main = hex("#3D2C4E"), accent = hex("#E8A9C1"), water = hex("#B98AA6") },
		draw = function(cv, c, ctx)
			for i, p in PETALS do
				local ink = if ctx.tinted then c.main else Colors.mix(c.main, c.accent, p.shade)
				P.petal(cv, p.bx, p.by, p.len, p.wid, p.angle, ink, { name = "Petal" })
				if not ctx.simple then
					local dotInk = if ctx.tinted then c.counter else c.accent
					for _, pt in STIPPLE[i] do
						P.circle(cv, pt[1], pt[2], DOT / 2, dotInk, { name = "Stipple", t = 0.1 })
					end
				end
			end
			-- The cup the petals rise from, and a waterline.
			P.circle(cv, 50, BASE_Y - 1, 4.2, c.main)
			P.rect(cv, 27, 87.5, 46, 1.6, c.water, { pill = true })
			P.rect(cv, 37, 92, 26, 1.6, c.water, { pill = true })
		end,
	},
}

return list
