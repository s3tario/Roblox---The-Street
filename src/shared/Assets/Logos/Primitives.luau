--!strict
-- Logos: a small vector kit built from GUI objects only (Frames, UICorner, UIStroke, UIGradient, UIScale,
-- TextLabels). Bake-safe (contracts §15): no services, no clocks, no asset ids.
--
-- Every logo is drawn on a Canvas measured in abstract units (H = 100, W = 100 * aspect). Primitives take
-- unit coordinates and write Position/Size in scale space, so a logo looks identical at 64 px and 512 px.
-- Stroke widths are scale-correct too: UIStroke uses ScaledSize (a fraction of the frame's smaller side)
-- unless the canvas knows its exact pixel size (SurfaceGuis), in which case strokes are set in pixels.
--
-- Techniques
--   ring      a transparent circle with an inner UIStroke (the hole stays transparent)
--   arcs      a ring or disc with a hard-edged UIGradient transparency mask: `keep` lists the visible bands
--             along the mask direction (chord cuts, as in typeface terminals); clip groups mask rectangles
--   lens      a pointed petal/leaf: two disc segments meeting on the long axis (intersection of two discs)
--   shield    a rectangle over a lens: straight sides that curve into a point
--   peak      a rotated square inside a clip group (a triangle with the square's corner as its apex)
--   text      a TextLabel with TextScaled inside a UIScale, so glyphs can exceed the 100 px TextSize cap
--
-- Every GuiObject gets an increasing ZIndex (the canvas counter), so drawing order is painter's order in
-- both Sibling and Global ZIndexBehavior.

local P = {}

export type Group = { frame: GuiObject, x: number, y: number, w: number, h: number }

export type Canvas = {
	root: GuiObject,
	W: number,
	H: number,
	ppu: number?, -- exact pixels per unit (SurfaceGui canvases): strokes use FixedSize pixels
	textPpu: number?, -- pixel hint for sizing text (exact or measured)
	z: number,
	count: number,
	top: Group,
	simple: boolean, -- drop fine detail (stipple, tiny captions)
}

export type Opts = {
	g: Group?, -- clip group to draw into (default: the canvas)
	t: number?, -- transparency
	rot: number?, -- rotation in degrees, clockwise
	radius: number?, -- corner radius in units
	pill: boolean?, -- fully rounded ends
	keep: { { number } }?, -- visible bands {lo, hi} along the mask direction (0..1 across the shape)
	dir: number?, -- mask direction in degrees: 0 = left to right, 90 = top to bottom
	cap: string?, -- bar ends: "round" (default) | "flat"
	name: string?,
	font: Enum.Font?,
	weight: Enum.FontWeight?,
	italic: boolean?,
	align: string?, -- text: "center" (default) | "left" | "right"
	rich: boolean?,
	colors: { Color3 }?, -- colour gradient across the shape (prismatic trims)
	gradRot: number?,
}

-- Draw context handed to every logo's draw function.
export type Ctx = {
	theme: string, -- "light" | "dark" | "color"
	tinted: boolean, -- single-ink rendering: skip multi-colour effects (prismatic gradients)
	simple: boolean,
	name: string, -- display name of the logo
	initials: string,
}

-- A logo definition. Colours are role-named (see Colors.luau); `draw` receives them resolved for the theme.
export type Spec = {
	id: string,
	kind: string, -- "company" | "school" | "brand" | "monogram"
	name: string,
	aspect: number?, -- width / height (default 1); the canvas is 100 * aspect by 100 units
	rarity: string?, -- schools and brands: adds the `tier` colour role
	initials: string?,
	colors: { [string]: Color3 },
	themes: { [string]: { [string]: Color3 } }?, -- per-theme role overrides
	draw: (cv: Canvas, c: { [string]: Color3 }, ctx: Ctx) -> (),
}

local NO_OPTS: Opts = {}
local WHITE = Color3.new(1, 1, 1)
local EDGE = 0.003 -- width of a mask's hard edge (fraction of the shape)
local TEXT_PX = 96 -- largest glyph box rendered without a UIScale boost

function P.new(
	root: GuiObject,
	W: number,
	H: number,
	ppu: number?,
	textPpu: number?,
	baseZ: number?,
	simple: boolean?
): Canvas
	return {
		root = root,
		W = W,
		H = H,
		ppu = ppu,
		textPpu = textPpu,
		z = baseZ or 1,
		count = 0,
		top = { frame = root, x = 0, y = 0, w = W, h = H },
		simple = simple == true,
	}
end

---------------------------------------------------------------------------------------------------
-- Geometry helpers
---------------------------------------------------------------------------------------------------
-- Point at `dist` from (cx, cy) in direction `angle` (degrees clockwise from straight up).
function P.polar(cx: number, cy: number, dist: number, angle: number): (number, number)
	local a = math.rad(angle)
	return cx + dist * math.sin(a), cy - dist * math.cos(a)
end

-- Hard-edged transparency mask: visible (0) inside the bands, hidden (1) elsewhere.
function P.bandSequence(bands: { { number } }): NumberSequence
	local sorted = table.clone(bands)
	table.sort(sorted, function(a, b)
		return a[1] < b[1]
	end)
	local pts: { { number } } = {}
	local function push(t: number, v: number)
		local time = math.clamp(t, 0, 1)
		local last = pts[#pts]
		if last and time <= last[1] then
			time = last[1] + 1e-4
		end
		if time < 1 then
			table.insert(pts, { time, v })
		end
	end
	local first = sorted[1]
	local visibleAtZero = first ~= nil and first[1] <= 0
	push(0, if visibleAtZero then 0 else 1)
	local lastValue = if visibleAtZero then 0 else 1
	for _, b in sorted do
		local lo, hi = b[1], b[2]
		if lo > 0 then
			push(lo - EDGE / 2, 1)
			push(lo + EDGE / 2, 0)
			lastValue = 0
		end
		if hi < 1 then
			push(hi - EDGE / 2, 0)
			push(hi + EDGE / 2, 1)
			lastValue = 1
		else
			lastValue = 0
		end
	end
	local kps = {}
	for _, p in pts do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	table.insert(kps, NumberSequenceKeypoint.new(1, lastValue))
	return NumberSequence.new(kps)
end

---------------------------------------------------------------------------------------------------
-- Instance plumbing
---------------------------------------------------------------------------------------------------
local function nextZ(cv: Canvas): number
	local z = cv.z
	cv.z += 1
	cv.count += 1
	return z
end

local function place(g: Group, f: GuiObject, x: number, y: number, w: number, h: number)
	f.Position = UDim2.fromScale((x - g.x) / g.w, (y - g.y) / g.h)
	f.Size = UDim2.fromScale(w / g.w, h / g.h)
end

local function corner(f: GuiObject, scale: number, offsetUnits: number?, cv: Canvas?, minSide: number?)
	local c = Instance.new("UICorner")
	if offsetUnits and cv and minSide and minSide > 0 then
		-- Corner radius as a fraction of the smaller side keeps it scale-correct.
		c.CornerRadius = UDim.new(math.clamp(offsetUnits / minSide, 0, 0.5), 0)
	else
		c.CornerRadius = UDim.new(scale, 0)
	end
	c.Parent = f
end

local function colorGradient(parent: Instance, colors: { Color3 }, rot: number?): UIGradient
	local g = Instance.new("UIGradient")
	local kps = {}
	local n = math.max(#colors, 1)
	if n == 1 then
		g.Color = ColorSequence.new(colors[1])
	else
		for i, c in colors do
			table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (n - 1), c))
		end
		g.Color = ColorSequence.new(kps)
	end
	g.Rotation = rot or 0
	g.Parent = parent
	return g
end
P.colorGradient = colorGradient

local function frame(
	cv: Canvas,
	o: Opts,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	transparentFill: boolean?
): Frame
	local g = o.g or cv.top
	local f = Instance.new("Frame")
	f.Name = o.name or "Shape"
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = if transparentFill then 1 else (o.t or 0)
	place(g, f, x, y, w, h)
	f.Rotation = o.rot or 0
	f.ZIndex = nextZ(cv)
	f.Parent = g.frame
	return f
end

local function maskGradient(parent: Instance, o: Opts, extraColors: { Color3 }?)
	local keep = o.keep
	if not keep and not extraColors then
		return
	end
	local g = Instance.new("UIGradient")
	if keep then
		g.Transparency = P.bandSequence(keep)
	end
	if extraColors and #extraColors > 1 then
		local kps = {}
		for i, c in extraColors do
			table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#extraColors - 1), c))
		end
		g.Color = ColorSequence.new(kps)
		-- Gradient colours multiply the base colour, so the base goes white.
		if parent:IsA("UIStroke") then
			(parent :: UIStroke).Color = WHITE
		elseif parent:IsA("GuiObject") then
			(parent :: GuiObject).BackgroundColor3 = WHITE
		end
	end
	g.Rotation = if o.keep then (o.dir or 0) else (o.gradRot or o.dir or 0)
	g.Parent = parent
end

local function stroke(cv: Canvas, f: GuiObject, th: number, side: number, color: Color3, o: Opts): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Color = color
	s.Transparency = o.t or 0
	if cv.ppu then
		s.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
		s.Thickness = math.max(th * cv.ppu, 1)
	else
		s.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		s.Thickness = math.clamp(th / math.max(side, 1e-3), 0, 0.5)
	end
	s.Parent = f
	return s
end

---------------------------------------------------------------------------------------------------
-- Shapes
---------------------------------------------------------------------------------------------------
-- Rectangle by its top-left corner.
function P.rect(cv: Canvas, x: number, y: number, w: number, h: number, color: Color3, opts: Opts?): Frame
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
function P.box(cv: Canvas, cx: number, cy: number, w: number, h: number, color: Color3, opts: Opts?): Frame
	return P.rect(cv, cx - w / 2, cy - h / 2, w, h, color, opts)
end

-- Rectangle outline (inner stroke of width th).
function P.frameOutline(
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
function P.circle(cv: Canvas, cx: number, cy: number, r: number, color: Color3, opts: Opts?): Frame
	local o = opts or NO_OPTS
	local f = frame(cv, o, cx - r, cy - r, 2 * r, 2 * r, color)
	corner(f, 0.5)
	if o.keep or o.colors then
		maskGradient(f, o, o.colors)
	end
	return f
end
P.dot = P.circle

-- Ring of outer radius r and thickness th (the hole stays transparent). `keep` + `dir` cut it into arcs.
function P.ring(cv: Canvas, cx: number, cy: number, r: number, th: number, color: Color3, opts: Opts?): Frame
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
function P.ovalRing(
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
function P.bar(
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
function P.polyline(cv: Canvas, pts: { { number } }, th: number, color: Color3, opts: Opts?)
	for i = 1, #pts - 1 do
		P.bar(cv, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], th, color, opts)
	end
end

-- Disc segment: the part of a disc between bands of its local x axis, the disc rotated by `angle` degrees.
function P.segment(
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
	g.Transparency = P.bandSequence({ { lo, hi } })
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
function P.lens(
	cv: Canvas,
	cx: number,
	cy: number,
	len: number,
	wid: number,
	angle: number,
	color: Color3,
	opts: Opts?
)
	local a = len / 2
	local b = math.min(wid / 2, a * 0.999)
	local R = (a * a / b + b) / 2
	local d = R - b
	-- The perpendicular to the long axis (local +x of a frame rotated by `angle`).
	local rad = math.rad(angle)
	local nx, ny = math.cos(rad), math.sin(rad)
	local overlap = EDGE * 1.5
	-- Disc on the -n side keeps the +n half of the lens, and vice versa.
	P.segment(cv, cx - d * nx, cy - d * ny, R, color, angle, (d + R) / (2 * R) - overlap, 1, opts)
	P.segment(cv, cx + d * nx, cy + d * ny, R, color, angle, 0, (R - d) / (2 * R) + overlap, opts)
end

-- A lens whose base sits at (bx, by), growing `len` units in direction `angle`.
function P.petal(
	cv: Canvas,
	bx: number,
	by: number,
	len: number,
	wid: number,
	angle: number,
	color: Color3,
	opts: Opts?
)
	local cx, cy = P.polar(bx, by, len / 2, angle)
	P.lens(cv, cx, cy, len, wid, angle, color, opts)
end

-- Square rotated 45 degrees, `half` from centre to each corner.
function P.diamond(cv: Canvas, cx: number, cy: number, half: number, color: Color3, opts: Opts?): Frame
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
function P.diamondRing(
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
function P.octagon(cv: Canvas, cx: number, cy: number, w: number, color: Color3, opts: Opts?): Group
	local o = opts or NO_OPTS
	local s = w / (1 + math.sqrt(2)) -- side length
	local g = P.clip(cv, cx - w / 2, cy - w / 2, w, w, o)
	local half = (w + s) / 2 -- centre to diamond corner
	P.diamond(cv, cx, cy, half, color, { g = g, t = o.t, colors = o.colors, gradRot = o.gradRot })
	return g
end

-- Regular hexagon with circumradius R. Flat top by default; rot = 30 points it up.
function P.hexagon(cv: Canvas, cx: number, cy: number, R: number, color: Color3, opts: Opts?)
	local o = opts or NO_OPTS
	local base = o.rot or 0
	for i = 0, 2 do
		local f = frame(cv, o, cx - R / 2, cy - R * math.sqrt(3) / 2, R, R * math.sqrt(3), color)
		f.Rotation = base + i * 60
	end
end

-- Heater shield in the box (x, y, w, h): straight sides curving into a point at the bottom.
function P.shield(cv: Canvas, x: number, y: number, w: number, h: number, color: Color3, opts: Opts?)
	local o = opts or NO_OPTS
	local depth = math.min(w * 0.62, h * 0.5)
	local mid = y + h - depth
	local rectOpts: Opts = { g = o.g, t = o.t, colors = o.colors, dir = o.dir, name = o.name }
	if o.radius then
		rectOpts.radius = o.radius
	end
	P.rect(cv, x, y, w, mid - y + 0.01, color, rectOpts)
	P.lens(cv, x + w / 2, mid, depth * 2, w, 0, color, { g = o.g, t = o.t, colors = o.colors, name = o.name })
end

-- Inverted V (apex up) with legs to the bottom corners of the w x h box centred at (cx, cy).
function P.chevron(
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
	P.bar(cv, cx, ay, cx - w / 2, ly, th, color, barOpts)
	P.bar(cv, cx, ay, cx + w / 2, ly, th, color, barOpts)
end

-- Triangle (a mountain peak) with its apex at (ax, ay) and its base on the line y = baseY: a corner of a
-- rotated square, cut off by the clip group `g`, whose bottom edge must be at baseY (and top above ay).
-- `tilt` (5..85 degrees, default 45) is the right-hand slope; the left-hand slope is 90 - tilt.
function P.peak(
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
	local cx, cy = P.polar(ax, ay, half, 180 + (t - 45))
	local f = frame(cv, { g = g, t = o.t, name = o.name }, cx - size / 2, cy - size / 2, size, size, color)
	f.Rotation = t
	if o.colors then
		maskGradient(f, o, o.colors)
	end
	return f
end

-- Five-pointed star of outer radius r: a thick pentagram with its centre filled.
function P.star(cv: Canvas, cx: number, cy: number, r: number, color: Color3, opts: Opts?)
	local o = opts or NO_OPTS
	local th = r * 0.3
	local pts = {}
	for i = 0, 4 do
		local x, y = P.polar(cx, cy, r - th * 0.62, i * 72)
		pts[i] = { x, y }
	end
	local barOpts: Opts = { g = o.g, t = o.t, cap = "round" }
	for i = 0, 4 do
		local a, b = pts[i], pts[(i + 2) % 5]
		P.bar(cv, a[1], a[2], b[1], b[2], th, color, barOpts)
	end
	P.circle(cv, cx, cy, r * 0.42, color, { g = o.g, t = o.t })
end

-- Four-pointed twinkle.
function P.sparkle(cv: Canvas, cx: number, cy: number, r: number, color: Color3, opts: Opts?)
	local o = opts or NO_OPTS
	local rot = o.rot or 0
	P.lens(cv, cx, cy, 2 * r, r * 0.42, rot, color, { g = o.g, t = o.t })
	P.lens(cv, cx, cy, 1.5 * r, r * 0.36, rot + 90, color, { g = o.g, t = o.t })
end

-- Dots evenly spaced along an arc (angles in degrees clockwise from up, inclusive).
function P.arcDots(
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
		local x, y = P.polar(cx, cy, r, a)
		P.circle(cv, x, y, d / 2, color, opts)
	end
end

-- Laurel branch along an arc of radius r from angle `from` to `to` (degrees clockwise from up): a thin stem
-- with `n` pairs of leaves angled out and in, and a single leaf at the tip.
function P.laurel(
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
	local px, py = P.polar(cx, cy, r, from)
	for i = 1, steps do
		local x, y = P.polar(cx, cy, r, from + (to - from) * i / steps)
		P.bar(cv, px, py, x, y, leaf * 0.09, color, sub)
		px, py = x, y
	end
	local wid = leaf * 0.42
	for i = 0, n - 1 do
		local a = from + (to - from) * (i + 0.35) / n
		local sx, sy = P.polar(cx, cy, r, a)
		local tangent = a + 90 * sgn
		for _, tilt in { -40 * sgn, 34 * sgn } do
			local heading = tangent + tilt
			local lx, ly = P.polar(sx, sy, leaf * 0.46, heading)
			P.lens(cv, lx, ly, leaf, wid, heading, color, sub)
		end
	end
	local tx, ty = P.polar(cx, cy, r, to)
	local tip = to + 90 * sgn
	local lx, ly = P.polar(tx, ty, leaf * 0.4, tip)
	P.lens(cv, lx, ly, leaf * 0.9, wid * 0.9, tip, color, sub)
end

---------------------------------------------------------------------------------------------------
-- Groups and text
---------------------------------------------------------------------------------------------------
-- A transparent, clipping frame. Shapes drawn into it (opts.g) are cut to its rectangle.
function P.clip(cv: Canvas, x: number, y: number, w: number, h: number, opts: Opts?): Group
	local o = opts or NO_OPTS
	local parent = o.g or cv.top
	local f = Instance.new("Frame")
	f.Name = o.name or "Clip"
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ClipsDescendants = true
	place(parent, f, x, y, w, h)
	f.ZIndex = nextZ(cv)
	f.Parent = parent.frame
	return { frame = f, x = x, y = y, w = w, h = h }
end

-- A transparent, non-clipping layer covering (x, y, w, h), rotated `rot` degrees about its centre. Shapes
-- drawn into it (opts.g) rotate with it. Never put clip groups or peaks inside a rotated layer: Roblox
-- ignores ClipsDescendants under rotation.
function P.layer(cv: Canvas, x: number, y: number, w: number, h: number, rot: number, opts: Opts?): Group
	local o = opts or NO_OPTS
	local parent = o.g or cv.top
	local f = Instance.new("Frame")
	f.Name = o.name or "Layer"
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	place(parent, f, x, y, w, h)
	f.Rotation = rot
	f.ZIndex = nextZ(cv)
	f.Parent = parent.frame
	return { frame = f, x = x, y = y, w = w, h = h }
end

local function fontFace(o: Opts): Font
	local base = Font.fromEnum(o.font or Enum.Font.GothamBold)
	return Font.new(
		base.Family,
		o.weight or base.Weight,
		if o.italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal
	)
end

-- Text fitted into the box (x, y, w, h). Long boxes shrink the text to fit their width.
function P.text(
	cv: Canvas,
	str: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	opts: Opts?
): TextLabel
	local o = opts or NO_OPTS
	local g = o.g or cv.top
	local ppu = cv.ppu or cv.textPpu
	local k = if ppu then math.max(1, math.ceil(h * ppu / TEXT_PX)) else 3
	k = math.min(k, 6)
	local l = Instance.new("TextLabel")
	l.Name = o.name or "Text"
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale((x + w / 2 - g.x) / g.w, (y + h / 2 - g.y) / g.h)
	l.Size = UDim2.fromScale(w / g.w / k, h / g.h / k)
	l.Rotation = o.rot or 0
	l.FontFace = fontFace(o)
	l.Text = str
	l.RichText = o.rich == true
	l.TextColor3 = color
	l.TextTransparency = o.t or 0
	l.TextScaled = true
	l.TextWrapped = false
	l.AutoLocalize = false -- brand names are never machine-translated
	l.TextXAlignment = if o.align == "left"
		then Enum.TextXAlignment.Left
		elseif o.align == "right" then Enum.TextXAlignment.Right
		else Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.ZIndex = nextZ(cv)
	if k > 1 then
		local s = Instance.new("UIScale")
		s.Scale = k
		s.Parent = l
	end
	l.Parent = g.frame
	return l
end

return P
