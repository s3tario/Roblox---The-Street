--!strict
-- Logos primitives: basic shapes (rectangles, circles, rings and arcs, bars, lenses and petals, diamonds,
-- octagons, hexagons, shields, chevrons, peaks). Coordinates are canvas units; see Primitives/init.luau.

local Core = require(script.Parent.Core)

type Canvas = Core.Canvas
type Group = Core.Group
type Opts = Core.Opts

local NO_OPTS = Core.NO_OPTS
local WHITE = Core.WHITE
local frame = Core.frame
local corner = Core.corner
local stroke = Core.stroke
local maskGradient = Core.maskGradient

local Shapes = {}

-- Rectangle by its top-left corner.
function Shapes.rect(cv: Canvas, x: number, y: number, w: number, h: number, color: Color3, opts: Opts?): Frame
	local o = opts or NO_OPTS
	local f = frame(cv, o, x, y, w, h, color)
	if o.pill then
		corner(f, 0.5)
	elseif o.radius then
		corner(f, 0, o.radius, cv, math.min(w, h))
	end
	if o.colors or o.keep then
		maskGradient(f, o, o.colors)
	end
	return f
end

-- Rectangle by its centre.
function Shapes.box(cv: Canvas, cx: number, cy: number, w: number, h: number, color: Color3, opts: Opts?): Frame
	return Shapes.rect(cv, cx - w / 2, cy - h / 2, w, h, color, opts)
end

-- Rectangle outline (inner stroke of width th).
function Shapes.frameOutline(
	cv: Canvas,
	x: number,
	y: number,
	w: number,
	h: number,
	th: number,
	color: Color3,
	opts: Opts?
): Frame
	local o = opts or NO_OPTS
	local f = frame(cv, o, x, y, w, h, color, true)
	if o.pill then
		corner(f, 0.5)
	elseif o.radius then
		corner(f, 0, o.radius, cv, math.min(w, h))
	end
	local s = stroke(cv, f, th, math.min(w, h), color, o)
	if o.keep or o.colors then
		maskGradient(s, o, o.colors)
	end
	return f
end

-- Filled circle. `keep` + `dir` turn it into a disc segment or band.
function Shapes.circle(cv: Canvas, cx: number, cy: number, r: number, color: Color3, opts: Opts?): Frame
	local o = opts or NO_OPTS
	local f = frame(cv, o, cx - r, cy - r, 2 * r, 2 * r, color)
	corner(f, 0.5)
	if o.keep or o.colors then
		maskGradient(f, o, o.colors)
	end
	return f
end
Shapes.dot = Shapes.circle

-- Ring of outer radius r and thickness th (the hole stays transparent). `keep` + `dir` cut it into arcs.
function Shapes.ring(cv: Canvas, cx: number, cy: number, r: number, th: number, color: Color3, opts: Opts?): Frame
	local o = opts or NO_OPTS
	local f = frame(cv, o, cx - r, cy - r, 2 * r, 2 * r, color, true)
	corner(f, 0.5)
	local s = stroke(cv, f, th, 2 * r, color, o)
	if o.keep or o.colors then
		maskGradient(s, o, o.colors)
	end
	return f
end

-- Stadium (pill) outline or ellipse-like oval ring.
function Shapes.ovalRing(
	cv: Canvas,
	cx: number,
	cy: number,
	w: number,
	h: number,
	th: number,
	color: Color3,
	opts: Opts?
): Frame
	local o = opts or NO_OPTS
	local f = frame(cv, o, cx - w / 2, cy - h / 2, w, h, color, true)
	corner(f, 0.5)
	local s = stroke(cv, f, th, math.min(w, h), color, o)
	if o.keep or o.colors then
		maskGradient(s, o, o.colors)
	end
	return f
end

-- Straight stroke from (x1, y1) to (x2, y2). Round caps extend th/2 past each end; flat caps stop there.
function Shapes.bar(
	cv: Canvas,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	th: number,
	color: Color3,
	opts: Opts?
): Frame
	local o = opts or NO_OPTS
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	local round = o.cap ~= "flat"
	local full = if round then len + th else len
	local cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
	local angle = math.deg(math.atan2(dy, dx))
	local f = frame(cv, o, cx - full / 2, cy - th / 2, full, th, color)
	f.Rotation = angle
	if round then
		corner(f, 0.5)
	end
	if o.colors then
		maskGradient(f, o, o.colors)
	end
	return f
end

-- Connected strokes through the points (round joints).
function Shapes.polyline(cv: Canvas, pts: { { number } }, th: number, color: Color3, opts: Opts?)
	for i = 1, #pts - 1 do
		Shapes.bar(cv, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], th, color, opts)
	end
end

-- Disc segment: the part of a disc between bands of its local x axis, the disc rotated by `angle` degrees.
function Shapes.segment(
	cv: Canvas,
	cx: number,
	cy: number,
	r: number,
	color: Color3,
	angle: number,
	lo: number,
	hi: number,
	opts: Opts?
): Frame
	local o = opts or NO_OPTS
	local f = frame(cv, o, cx - r, cy - r, 2 * r, 2 * r, color)
	f.Rotation = angle
	corner(f, 0.5)
	local g = Instance.new("UIGradient")
	g.Transparency = Core.bandSequence({ { lo, hi } }, Core.segmentEdge(r))
	g.Rotation = 0
	if o.colors and #o.colors > 1 then
		local kps = {}
		for i, c in o.colors do
			table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#o.colors - 1), c))
		end
		g.Color = ColorSequence.new(kps)
		f.BackgroundColor3 = WHITE
	end
	g.Parent = f
	return f
end

-- Pointed lens (vesica): a petal or leaf `len` long and `wid` wide, centred at (cx, cy), its long axis
-- pointing `angle` degrees clockwise from straight up. Built from two disc segments.
function Shapes.lens(
	cv: Canvas,
	cx: number,
	cy: number,
	len: number,
	wid: number,
	angle: number,
	color: Color3,
	opts: Opts?
)
	local o = opts or NO_OPTS
	local a = len / 2
	local b = math.min(wid / 2, a * 0.999)
	local R = (a * a / b + b) / 2
	local d = R - b
	-- The perpendicular to the long axis (local +x of a frame rotated by `angle`).
	local rad = math.rad(angle)
	local nx, ny = math.cos(rad), math.sin(rad)
	-- Each half overlaps the axis by half a mask edge: both are fully opaque on the axis (no seam) and the
	-- overlap past the tip stays far below a pixel.
	local overlap = Core.segmentEdge(R) / 2
	-- The discs are much larger than the lens, so they sit in a clip group around the lens's bounding box
	-- (cut to the parent group) and nothing extends past the logo. The masks alone already shape the lens,
	-- so it stays correct where Roblox ignores clipping (inside a rotated layer).
	local parent = o.g or cv.top
	local ex = a * math.abs(math.sin(rad)) + b * math.abs(math.cos(rad)) + 0.6
	local ey = a * math.abs(math.cos(rad)) + b * math.abs(math.sin(rad)) + 0.6
	local x0 = math.max(cx - ex, parent.x)
	local y0 = math.max(cy - ey, parent.y)
	local x1 = math.min(cx + ex, parent.x + parent.w)
	local y1 = math.min(cy + ey, parent.y + parent.h)
	if x1 <= x0 or y1 <= y0 then
		return
	end
	local g = Core.clip(cv, x0, y0, x1 - x0, y1 - y0, { g = parent, name = "Lens" })
	local sub: Opts = { g = g, t = o.t, colors = o.colors, name = o.name }
	-- Disc on the -n side keeps the +n half of the lens, and vice versa.
	Shapes.segment(cv, cx - d * nx, cy - d * ny, R, color, angle, (d + R) / (2 * R) - overlap, 1, sub)
	Shapes.segment(cv, cx + d * nx, cy + d * ny, R, color, angle, 0, (R - d) / (2 * R) + overlap, sub)
end

-- A lens whose base sits at (bx, by), growing `len` units in direction `angle`.
function Shapes.petal(
	cv: Canvas,
	bx: number,
	by: number,
	len: number,
	wid: number,
	angle: number,
	color: Color3,
	opts: Opts?
)
	local cx, cy = Core.polar(bx, by, len / 2, angle)
	Shapes.lens(cv, cx, cy, len, wid, angle, color, opts)
end

-- Square rotated 45 degrees, `half` from centre to each corner.
function Shapes.diamond(cv: Canvas, cx: number, cy: number, half: number, color: Color3, opts: Opts?): Frame
	local o = opts or NO_OPTS
	local side = half * math.sqrt(2)
	local f = frame(cv, o, cx - side / 2, cy - side / 2, side, side, color)
	f.Rotation = 45 + (o.rot or 0)
	if o.radius then
		corner(f, 0, o.radius, cv, side)
	end
	if o.colors then
		maskGradient(f, o, o.colors)
	end
	return f
end

-- Diamond outline.
function Shapes.diamondRing(
	cv: Canvas,
	cx: number,
	cy: number,
	half: number,
	th: number,
	color: Color3,
	opts: Opts?
): Frame
	local o = opts or NO_OPTS
	local side = half * math.sqrt(2)
	local f = frame(cv, o, cx - side / 2, cy - side / 2, side, side, color, true)
	f.Rotation = 45 + (o.rot or 0)
	if o.radius then
		corner(f, 0, o.radius, cv, side)
	end
	stroke(cv, f, th, side, color, o)
	return f
end

-- Regular octagon `w` across the flats.
function Shapes.octagon(cv: Canvas, cx: number, cy: number, w: number, color: Color3, opts: Opts?): Group
	local o = opts or NO_OPTS
	local s = w / (1 + math.sqrt(2)) -- side length
	local g = Core.clip(cv, cx - w / 2, cy - w / 2, w, w, o)
	local half = (w + s) / 2 -- centre to diamond corner
	Shapes.diamond(cv, cx, cy, half, color, { g = g, t = o.t, colors = o.colors, gradRot = o.gradRot })
	return g
end

-- Regular hexagon with circumradius R. Flat top by default; rot = 30 points it up.
function Shapes.hexagon(cv: Canvas, cx: number, cy: number, R: number, color: Color3, opts: Opts?)
	local o = opts or NO_OPTS
	local base = o.rot or 0
	for i = 0, 2 do
		local f = frame(cv, o, cx - R / 2, cy - R * math.sqrt(3) / 2, R, R * math.sqrt(3), color)
		f.Rotation = base + i * 60
	end
end

-- Heater shield in the box (x, y, w, h): straight sides curving into a point at the bottom.
function Shapes.shield(cv: Canvas, x: number, y: number, w: number, h: number, color: Color3, opts: Opts?)
	local o = opts or NO_OPTS
	local depth = math.min(w * 0.62, h * 0.5)
	local mid = y + h - depth
	local rectOpts: Opts = { g = o.g, t = o.t, colors = o.colors, dir = o.dir, name = o.name }
	if o.radius then
		rectOpts.radius = o.radius
	end
	Shapes.rect(cv, x, y, w, mid - y + 0.01, color, rectOpts)
	Shapes.lens(cv, x + w / 2, mid, depth * 2, w, 0, color, { g = o.g, t = o.t, colors = o.colors, name = o.name })
end

-- Inverted V (apex up) with legs to the bottom corners of the w x h box centred at (cx, cy).
function Shapes.chevron(
	cv: Canvas,
	cx: number,
	cy: number,
	w: number,
	h: number,
	th: number,
	color: Color3,
	opts: Opts?
)
	local o = opts or NO_OPTS
	local down = o.rot == 180
	local ay = if down then cy + h / 2 else cy - h / 2
	local ly = if down then cy - h / 2 else cy + h / 2
	local barOpts: Opts = { g = o.g, t = o.t, cap = o.cap, colors = o.colors }
	Shapes.bar(cv, cx, ay, cx - w / 2, ly, th, color, barOpts)
	Shapes.bar(cv, cx, ay, cx + w / 2, ly, th, color, barOpts)
end

-- Triangle (a mountain peak) with its apex at (ax, ay) and its base on the line y = baseY: a corner of a
-- rotated square, cut off by the clip group `g`, whose bottom edge must be at baseY (and top above ay).
-- `tilt` (5..85 degrees, default 45) is the right-hand slope; the left-hand slope is 90 - tilt.
function Shapes.peak(
	cv: Canvas,
	g: Group,
	ax: number,
	ay: number,
	baseY: number,
	color: Color3,
	tilt: number?,
	opts: Opts?
): Frame
	local o = opts or NO_OPTS
	local t = math.clamp(tilt or 45, 5, 85)
	-- Rotating a square clockwise by t puts its topmost corner at angle (t - 45) from straight up; its two
	-- edges leave that corner at t (right) and 90 - t (left) below horizontal. The neighbouring corners sit
	-- size * sin(t) and size * cos(t) below the apex, so the square must be big enough to reach baseY.
	local rad = math.rad(t)
	local size = (baseY - ay) / math.min(math.sin(rad), math.cos(rad)) * 1.02
	local half = size * math.sqrt(2) / 2
	local cx, cy = Core.polar(ax, ay, half, 180 + (t - 45))
	local f = frame(cv, { g = g, t = o.t, name = o.name }, cx - size / 2, cy - size / 2, size, size, color)
	f.Rotation = t
	if o.colors then
		maskGradient(f, o, o.colors)
	end
	return f
end

return Shapes
