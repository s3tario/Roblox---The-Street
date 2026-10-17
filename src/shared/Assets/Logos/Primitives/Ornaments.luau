--!strict
-- Logos primitives: ornaments built from the basic shapes (stars, sparkles, dotted arcs, laurels).

local Core = require(script.Parent.Core)

type Canvas = Core.Canvas
type Opts = Core.Opts

local NO_OPTS = Core.NO_OPTS
local Shapes = require(script.Parent.Shapes)

local Ornaments = {}

-- Five-pointed star of outer radius r: a thick pentagram with round caps (soft tips) and its centre filled.
-- `rot` turns it.
function Ornaments.star(cv: Canvas, cx: number, cy: number, r: number, color: Color3, opts: Opts?)
	local o = opts or NO_OPTS
	local th = r * 0.3
	local base = o.rot or 0
	local pts = {}
	for i = 0, 4 do
		local x, y = Core.polar(cx, cy, r - th * 0.62, base + i * 72)
		pts[i] = { x, y }
	end
	local barOpts: Opts = { g = o.g, t = o.t, cap = "round" }
	for i = 0, 4 do
		local a, b = pts[i], pts[(i + 2) % 5]
		Shapes.bar(cv, a[1], a[2], b[1], b[2], th, color, barOpts)
	end
	Shapes.circle(cv, cx, cy, r * 0.42, color, { g = o.g, t = o.t })
end

-- Four-pointed twinkle.
function Ornaments.sparkle(cv: Canvas, cx: number, cy: number, r: number, color: Color3, opts: Opts?)
	local o = opts or NO_OPTS
	local rot = o.rot or 0
	Shapes.lens(cv, cx, cy, 2 * r, r * 0.42, rot, color, { g = o.g, t = o.t })
	Shapes.lens(cv, cx, cy, 1.5 * r, r * 0.36, rot + 90, color, { g = o.g, t = o.t })
end

-- Dots evenly spaced along an arc (angles in degrees clockwise from up, inclusive).
function Ornaments.arcDots(
	cv: Canvas,
	cx: number,
	cy: number,
	r: number,
	from: number,
	to: number,
	n: number,
	d: number,
	color: Color3,
	opts: Opts?
)
	for i = 0, n - 1 do
		local a = if n == 1 then from else from + (to - from) * i / (n - 1)
		local x, y = Core.polar(cx, cy, r, a)
		Shapes.circle(cv, x, y, d / 2, color, opts)
	end
end

-- Laurel branch along an arc of radius r from angle `from` to `to` (degrees clockwise from up): a thin stem
-- with `n` pairs of leaves angled out and in, and a single leaf at the tip.
function Ornaments.laurel(
	cv: Canvas,
	cx: number,
	cy: number,
	r: number,
	from: number,
	to: number,
	n: number,
	leaf: number,
	color: Color3,
	opts: Opts?
)
	local o = opts or NO_OPTS
	local sub: Opts = { g = o.g, t = o.t }
	local sgn = if to >= from then 1 else -1
	local steps = math.max(4, n)
	local px, py = Core.polar(cx, cy, r, from)
	for i = 1, steps do
		local x, y = Core.polar(cx, cy, r, from + (to - from) * i / steps)
		Shapes.bar(cv, px, py, x, y, leaf * 0.09, color, sub)
		px, py = x, y
	end
	local wid = leaf * 0.42
	for i = 0, n - 1 do
		local a = from + (to - from) * (i + 0.35) / n
		local sx, sy = Core.polar(cx, cy, r, a)
		local tangent = a + 90 * sgn
		for _, tilt in { -40 * sgn, 34 * sgn } do
			local heading = tangent + tilt
			local lx, ly = Core.polar(sx, sy, leaf * 0.46, heading)
			Shapes.lens(cv, lx, ly, leaf, wid, heading, color, sub)
		end
	end
	local tx, ty = Core.polar(cx, cy, r, to)
	local tip = to + 90 * sgn
	local lx, ly = Core.polar(tx, ty, leaf * 0.4, tip)
	Shapes.lens(cv, lx, ly, leaf * 0.9, wid * 0.9, tip, color, sub)
end

return Ornaments
