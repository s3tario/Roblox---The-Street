--!strict
-- SurfaceGui primitives for props and signs: surfaces, frames, dots, lines, labels, gradients, plus
-- fictional market data (random-walk series, quotes, ticker lines, line and candle charts).
-- Only GUI Frames and TextLabels (no image ids). Bake-safe (contracts §13).

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)
local Words = require(script.Parent.Parent.Words)

local Core = {}

export type SurfOpts = {
	glow: boolean?,
	brightness: number?,
	pps: number?,
	maxDistance: number?,
	name: string?,
}

local function hex(s: string): Color3
	s = string.gsub(s, "#", "")
	return Color3.fromRGB(
		tonumber(string.sub(s, 1, 2), 16) or 0,
		tonumber(string.sub(s, 3, 4), 16) or 0,
		tonumber(string.sub(s, 5, 6), 16) or 0
	)
end
Core.hex = hex

Core.UP = hex("#2BD67B")
Core.DOWN = hex("#FF5A5F")
Core.TEXT = hex("#E8EEF5")
Core.DIM = hex("#7D8FA6")
Core.AMBER = hex("#FFB547")
Core.NAVY = hex("#0B1622")
Core.NAVY2 = hex("#13243A")
Core.MONO = Enum.Font.RobotoMono

local function toHex(c: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end
Core.toHex = toHex

---------------------------------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------------------------------
-- SurfaceGui on `part`'s `face`. Returns the gui and its canvas size in pixels.
function Core.surface(part: BasePart, face: Enum.NormalId?, o: SurfOpts?): (SurfaceGui, number, number)
	local opts: SurfOpts = o or {}
	local f = face or Enum.NormalId.Front
	local pps = opts.pps or 40
	local s = part.Size
	local w, h
	if f == Enum.NormalId.Front or f == Enum.NormalId.Back then
		w, h = s.X, s.Y
	elseif f == Enum.NormalId.Left or f == Enum.NormalId.Right then
		w, h = s.Z, s.Y
	else
		w, h = s.X, s.Z
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = opts.name or "Surface"
	gui.Face = f
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = if opts.glow then 0 else 1
	gui.Brightness = if opts.glow then (opts.brightness or 1.3) else 1
	gui.MaxDistance = opts.maxDistance or 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ClipsDescendants = true
	gui.ResetOnSpawn = false
	gui.Parent = part
	return gui, w * pps, h * pps
end

-- Frame in scale coordinates (top-left origin).
function Core.frame(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	transparency: number?
): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.Parent = parent
	return f
end

-- Frame in pixel coordinates (top-left origin).
function Core.px(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.Parent = parent
	return f
end

function Core.round(obj: GuiObject, scale: number?, offset: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0, offset or 0)
	c.Parent = obj
	return c
end

-- Circle/ellipse of pixel diameter `d` centred at pixel (cx, cy).
function Core.dot(parent: Instance, cx: number, cy: number, d: number, color: Color3, transparency: number?): Frame
	local f = Core.px(parent, cx - d / 2, cy - d / 2, d, d, color, transparency)
	Core.round(f, 0.5)
	return f
end

function Core.stroke(obj: GuiObject, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = if obj:IsA("TextLabel") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

function Core.gradient(obj: GuiObject, a: Color3, b: Color3, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation or 90
	g.Parent = obj
	return g
end

-- Hard-edged stripes using a gradient with paired keypoints (max 9 bands, ColorSequence allows 20 keypoints).
function Core.stripes(obj: GuiObject, colors: { Color3 }, bands: number, rotation: number): UIGradient
	local n = math.clamp(math.floor(bands), 2, 9)
	local kps = {}
	for i = 0, n - 1 do
		local col = colors[i % #colors + 1]
		local t0 = i / n
		local t1 = (i + 1) / n
		table.insert(kps, ColorSequenceKeypoint.new(if i == 0 then 0 else t0 + 0.0005, col))
		table.insert(kps, ColorSequenceKeypoint.new(if i == n - 1 then 1 else t1, col))
	end
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(kps)
	g.Rotation = rotation
	g.Parent = obj
	return g
end

export type LabelOpts = {
	font: Enum.Font?,
	weight: Enum.FontWeight?,
	italic: boolean?,
	align: Enum.TextXAlignment?,
	yAlign: Enum.TextYAlignment?,
	scaled: boolean?,
	size: number?,
	rich: boolean?,
	stroke: Color3?,
	strokeT: number?,
	strokeW: number?,
	name: string?,
	rotation: number?,
	transparency: number?,
	wrap: boolean?,
}

-- TextLabel in scale coordinates with a transparent background.
function Core.label(
	parent: Instance,
	text: string,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	o: LabelOpts?
): TextLabel
	local opts: LabelOpts = o or {}
	local l = Instance.new("TextLabel")
	l.Name = opts.name or "Label"
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Position = UDim2.fromScale(x, y)
	l.Size = UDim2.fromScale(w, h)
	l.FontFace = Font.fromEnum(opts.font or Enum.Font.GothamBold)
	if opts.weight or opts.italic then
		l.FontFace = Font.new(
			l.FontFace.Family,
			opts.weight or l.FontFace.Weight,
			if opts.italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal
		)
	end
	l.Text = text
	l.RichText = opts.rich == true
	l.TextColor3 = color
	l.TextTransparency = opts.transparency or 0
	l.TextScaled = if opts.scaled == nil then true else opts.scaled
	l.TextSize = math.clamp(opts.size or 24, 1, 100)
	l.TextWrapped = if opts.wrap == nil then true else opts.wrap
	l.TextXAlignment = opts.align or Enum.TextXAlignment.Left
	l.TextYAlignment = opts.yAlign or Enum.TextYAlignment.Center
	l.Rotation = opts.rotation or 0
	if opts.stroke then
		local s = Instance.new("UIStroke")
		s.Color = opts.stroke
		s.Thickness = opts.strokeW or 1.5
		s.Transparency = opts.strokeT or 0
		s.Parent = l
	end
	l.Parent = parent
	return l
end

-- Straight line segment between pixel points.
function Core.line(
	parent: Instance,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	thick: number,
	color: Color3,
	transparency: number?
): Frame
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
	f.Size = UDim2.fromOffset(len + thick * 0.6, thick)
	f.Rotation = math.deg(math.atan2(dy, dx))
	f.Parent = parent
	return f
end

-- Arrow from (x1,y1) to (x2,y2) in pixels.
function Core.arrow(parent: Instance, x1: number, y1: number, x2: number, y2: number, thick: number, color: Color3)
	Core.line(parent, x1, y1, x2, y2, thick, color)
	local a = math.atan2(y2 - y1, x2 - x1)
	local head = thick * 4
	for _, s in { 1, -1 } do
		local b = a + math.pi + s * 0.5
		Core.line(parent, x2, y2, x2 + math.cos(b) * head, y2 + math.sin(b) * head, thick, color)
	end
end

-- Full-canvas background frame.
function Core.bg(parent: Instance, color: Color3, transparency: number?): Frame
	local f = Core.frame(parent, 0, 0, 1, 1, color, transparency)
	f.Name = "Background"
	return f
end

---------------------------------------------------------------------------------------------------
-- Market data (fictional)
---------------------------------------------------------------------------------------------------
-- Random-walk price series.
function Core.series(rng: Rng.Rng, n: number, start: number, vol: number, drift: number): { number }
	local out = { start }
	local v = start
	for _ = 2, n do
		v = math.max(start * 0.2, v * (1 + drift + rng:normal(0, vol)))
		table.insert(out, v)
	end
	return out
end

function Core.price(v: number): string
	return string.format("%.2f", v)
end

-- One RichText quote: "APX 104.20 +1.24%". Returns (text, isUp).
function Core.quote(rng: Rng.Rng, ticker: string?): (string, boolean)
	local t = ticker or rng:pick(Words.tickers)
	local price = rng:range(18, 420)
	local chg = rng:normal(0.2, 1.6)
	local up = chg >= 0
	local col = toHex(if up then Core.UP else Core.DOWN)
	local sign = if up then "+" else "-"
	return string.format(
		'<font color="#E8EEF5">%s</font> %s <font color="%s">%s%.2f%%</font>',
		t,
		Core.price(price),
		col,
		sign,
		math.abs(chg)
	),
		up
end

-- Long RichText ticker line for LED bands (all tickers plus the benchmark).
function Core.tickerLine(rng: Rng.Rng, count: number?): string
	local parts = {}
	local order = rng:shuffle(Words.tickers)
	for i = 1, math.min(count or #order, #order) do
		local q = Core.quote(rng, order[i])
		table.insert(parts, q)
	end
	local idx = rng:range(4200, 5600)
	table.insert(parts, string.format('<font color="#E3C46F">%s %.1f</font>', Words.benchmark, idx))
	return table.concat(parts, "     ")
end

-- Polyline chart of `values` inside the pixel box (x0, y0, w, h).
function Core.lineChart(
	parent: Instance,
	x0: number,
	y0: number,
	w: number,
	h: number,
	values: { number },
	color: Color3,
	thick: number
)
	local lo, hi = math.huge, -math.huge
	for _, v in values do
		lo = math.min(lo, v)
		hi = math.max(hi, v)
	end
	local span = math.max(hi - lo, 1e-6)
	local n = #values
	local function pt(i: number): (number, number)
		local x = x0 + (i - 1) / math.max(n - 1, 1) * w
		local y = y0 + h - (values[i] - lo) / span * h
		return x, y
	end
	for i = 1, n - 1 do
		local ax, ay = pt(i)
		local bx, by = pt(i + 1)
		Core.line(parent, ax, ay, bx, by, thick, color)
	end
end

-- Candlestick chart (2 frames per candle).
function Core.candles(parent: Instance, x0: number, y0: number, w: number, h: number, rng: Rng.Rng, n: number)
	local opens, closes, highs, lows = {}, {}, {}, {}
	local v = 100
	for i = 1, n do
		local o = v
		local c = o * (1 + rng:normal(0.004, 0.025))
		opens[i], closes[i] = o, c
		highs[i] = math.max(o, c) * (1 + rng:range(0.002, 0.018))
		lows[i] = math.min(o, c) * (1 - rng:range(0.002, 0.018))
		v = c
	end
	local lo, hi = math.huge, -math.huge
	for i = 1, n do
		lo = math.min(lo, lows[i])
		hi = math.max(hi, highs[i])
	end
	local span = math.max(hi - lo, 1e-6)
	local step = w / n
	local function y(val: number): number
		return y0 + h - (val - lo) / span * h
	end
	for i = 1, n do
		local up = closes[i] >= opens[i]
		local col = if up then Core.UP else Core.DOWN
		local cx = x0 + step * (i - 0.5)
		local wick = math.max(1, step * 0.08)
		Core.px(parent, cx - wick / 2, y(highs[i]), wick, math.max(1, y(lows[i]) - y(highs[i])), col)
		local top = y(math.max(opens[i], closes[i]))
		local bot = y(math.min(opens[i], closes[i]))
		Core.px(parent, cx - step * 0.32, top, step * 0.64, math.max(2, bot - top), col)
	end
end

return Core
