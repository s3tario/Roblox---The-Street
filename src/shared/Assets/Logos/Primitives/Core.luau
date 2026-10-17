--!strict
-- Logos primitives: the core (types, the canvas, geometry helpers, instance plumbing, groups and text). The
-- plumbing (frame, stroke, corner, masks) is exported for the sibling shape modules only; logo modules use
-- the re-exports in Primitives/init.luau. Bake-safe: GUI instances only.

local Core = {}

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
	-- Full-colour marks with their own edge (crests, patches): keep the brand colours on dark and colour
	-- backgrounds instead of lifting or reversing them.
	keepColors: boolean?,
	draw: (cv: Canvas, c: { [string]: Color3 }, ctx: Ctx) -> (),
}

local NO_OPTS: Opts = {}
local WHITE = Color3.new(1, 1, 1)
local EDGE = 0.003 -- width of a mask's hard edge (fraction of the shape)
local TEXT_PX = 96 -- largest glyph box rendered without a UIScale boost

function Core.new(
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
function Core.polar(cx: number, cy: number, dist: number, angle: number): (number, number)
	local a = math.rad(angle)
	return cx + dist * math.sin(a), cy - dist * math.cos(a)
end

-- Hard-edged transparency mask: visible (0) inside the bands, hidden (1) elsewhere.
function Core.bandSequence(bands: { { number } }, edge: number?): NumberSequence
	local e = edge or EDGE
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
			push(lo - e / 2, 1)
			push(lo + e / 2, 0)
			lastValue = 0
		end
		if hi < 1 then
			push(hi - e / 2, 0)
			push(hi + e / 2, 1)
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

-- Mask edge of a disc segment of radius r: about a third of a unit wide whatever the disc's size, so the
-- big discs behind slender petals keep crisp tips.
function Core.segmentEdge(r: number): number
	return math.min(EDGE, 0.35 / math.max(2 * r, 1e-3))
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
Core.colorGradient = colorGradient

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
		g.Transparency = Core.bandSequence(keep)
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
-- Groups and text
---------------------------------------------------------------------------------------------------
-- A transparent, clipping frame. Shapes drawn into it (opts.g) are cut to its rectangle.
function Core.clip(cv: Canvas, x: number, y: number, w: number, h: number, opts: Opts?): Group
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
function Core.layer(cv: Canvas, x: number, y: number, w: number, h: number, rot: number, opts: Opts?): Group
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
function Core.text(
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

-- Plumbing shared with the sibling shape modules.
Core.NO_OPTS = NO_OPTS
Core.WHITE = WHITE
Core.EDGE = EDGE
Core.nextZ = nextZ
Core.place = place
Core.corner = corner
Core.frame = frame
Core.maskGradient = maskGradient
Core.stroke = stroke

return Core
