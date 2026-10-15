--!strict
-- SurfaceGui content for props and signs: monitor screens (charts, quotes, terminals, inboxes), LED
-- tickers, abstract paintings, whiteboard/chalkboard scribbles, clock faces and posters. Only GUI
-- Frames and TextLabels (no image ids). Bake-safe (contracts §13).

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Words = require(script.Parent.Words)

local Gui = {}

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
Gui.hex = hex

local UP = hex("#2BD67B")
local DOWN = hex("#FF5A5F")
Gui.UP = UP
Gui.DOWN = DOWN

local function toHex(c: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end
Gui.toHex = toHex

---------------------------------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------------------------------
-- SurfaceGui on `part`'s `face`. Returns the gui and its canvas size in pixels.
function Gui.surface(part: BasePart, face: Enum.NormalId?, o: SurfOpts?): (SurfaceGui, number, number)
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
function Gui.frame(
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
function Gui.px(
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
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.Parent = parent
	return f
end

-- Circle/ellipse of pixel diameter `d` centred at pixel (cx, cy).
function Gui.dot(parent: Instance, cx: number, cy: number, d: number, color: Color3, transparency: number?): Frame
	local f = Gui.px(parent, cx - d / 2, cy - d / 2, d, d, color, transparency)
	Gui.round(f, 0.5)
	return f
end

function Gui.round(obj: GuiObject, scale: number?, offset: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0, offset or 0)
	c.Parent = obj
	return c
end

function Gui.stroke(obj: GuiObject, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = if obj:IsA("TextLabel") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

function Gui.gradient(obj: GuiObject, a: Color3, b: Color3, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation or 90
	g.Parent = obj
	return g
end

-- Hard-edged stripes using a gradient with paired keypoints (max 9 bands).
function Gui.stripes(obj: GuiObject, colors: { Color3 }, bands: number, rotation: number): UIGradient
	local n = math.clamp(bands, 2, 9)
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
	align: Enum.TextXAlignment?,
	yAlign: Enum.TextYAlignment?,
	scaled: boolean?,
	size: number?,
	rich: boolean?,
	stroke: Color3?,
	strokeT: number?,
	name: string?,
	rotation: number?,
	transparency: number?,
}

-- TextLabel in scale coordinates with a transparent background.
function Gui.label(
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
	if opts.weight then
		l.FontFace = Font.new(l.FontFace.Family, opts.weight, Enum.FontStyle.Normal)
	end
	l.Text = text
	l.RichText = opts.rich == true
	l.TextColor3 = color
	l.TextTransparency = opts.transparency or 0
	l.TextScaled = if opts.scaled == nil then true else opts.scaled
	l.TextSize = opts.size or 24
	l.TextWrapped = true
	l.TextXAlignment = opts.align or Enum.TextXAlignment.Left
	l.TextYAlignment = opts.yAlign or Enum.TextYAlignment.Center
	l.Rotation = opts.rotation or 0
	if opts.stroke then
		local s = Instance.new("UIStroke")
		s.Color = opts.stroke
		s.Thickness = 1.5
		s.Transparency = opts.strokeT or 0
		s.Parent = l
	end
	l.Parent = parent
	return l
end

-- Straight line segment between pixel points.
function Gui.line(
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
function Gui.arrow(parent: Instance, x1: number, y1: number, x2: number, y2: number, thick: number, color: Color3)
	Gui.line(parent, x1, y1, x2, y2, thick, color)
	local a = math.atan2(y2 - y1, x2 - x1)
	local head = thick * 4
	for _, s in { 1, -1 } do
		local b = a + math.pi + s * 0.5
		Gui.line(parent, x2, y2, x2 + math.cos(b) * head, y2 + math.sin(b) * head, thick, color)
	end
end

-- Full-canvas background frame.
function Gui.bg(parent: Instance, color: Color3, transparency: number?): Frame
	local f = Gui.frame(parent, 0, 0, 1, 1, color, transparency)
	f.Name = "Background"
	return f
end

---------------------------------------------------------------------------------------------------
-- Market data (fictional)
---------------------------------------------------------------------------------------------------
-- Random-walk price series.
function Gui.series(rng: Rng.Rng, n: number, start: number, vol: number, drift: number): { number }
	local out = { start }
	local v = start
	for _ = 2, n do
		v = math.max(start * 0.2, v * (1 + drift + rng:normal(0, vol)))
		table.insert(out, v)
	end
	return out
end

local function fmtPrice(v: number): string
	return string.format("%.2f", v)
end

-- One RichText quote: "APX 104.20 +1.24%".
function Gui.quote(rng: Rng.Rng, ticker: string?): (string, boolean)
	local t = ticker or rng:pick(Words.tickers)
	local price = rng:range(18, 420)
	local chg = rng:normal(0.2, 1.6)
	local up = chg >= 0
	local col = toHex(if up then UP else DOWN)
	local sign = if up then "+" else ""
	return string.format(
		'<font color="#E8EEF5">%s</font> %s <font color="%s">%s%.2f%%</font>',
		t,
		fmtPrice(price),
		col,
		sign,
		chg
	),
		up
end

-- Long ticker line for LED bands.
function Gui.tickerLine(rng: Rng.Rng, count: number?): string
	local parts = {}
	local order = rng:shuffle(Words.tickers)
	for i = 1, math.min(count or #order, #order) do
		local q = Gui.quote(rng, order[i])
		table.insert(parts, q)
	end
	local idx = rng:range(4200, 5600)
	table.insert(parts, string.format('<font color="#E3C46F">%s %.1f</font>', Words.benchmark, idx))
	return table.concat(parts, "     ")
end

-- Polyline chart of `values` inside the pixel box (x0, y0, w, h).
function Gui.lineChart(
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
		Gui.line(parent, ax, ay, bx, by, thick, color)
	end
end

-- Candlestick chart (2 frames per candle).
function Gui.candles(parent: Instance, x0: number, y0: number, w: number, h: number, rng: Rng.Rng, n: number)
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
		local col = if up then UP else DOWN
		local cx = x0 + step * (i - 0.5)
		local wick = math.max(1, step * 0.08)
		Gui.px(parent, cx - wick / 2, y(highs[i]), wick, math.max(1, y(lows[i]) - y(highs[i])), col)
		local top = y(math.max(opens[i], closes[i]))
		local bot = y(math.min(opens[i], closes[i]))
		Gui.px(parent, cx - step * 0.32, top, step * 0.64, math.max(2, bot - top), col)
	end
end

---------------------------------------------------------------------------------------------------
-- Monitor screens
---------------------------------------------------------------------------------------------------
Gui.SCREEN_KINDS = { "chart", "candles", "quotes", "terminal", "email", "sheet", "deck", "news" }

local NAVY = hex("#0B1622")
local NAVY2 = hex("#13243A")
local TEXT = hex("#E8EEF5")
local DIM = hex("#7D8FA6")
local AMBER = hex("#FFB547")
local MONO = Enum.Font.RobotoMono

local function header(gui: Instance, title: string, right: string, rightColor: Color3)
	Gui.frame(gui, 0, 0, 1, 0.14, NAVY2)
	Gui.label(gui, title, 0.03, 0.015, 0.6, 0.11, TEXT, { font = MONO })
	Gui.label(gui, right, 0.55, 0.015, 0.42, 0.11, rightColor, { font = MONO, align = Enum.TextXAlignment.Right })
end

local function screenChart(gui: Instance, W: number, H: number, rng: Rng.Rng)
	Gui.bg(gui, NAVY)
	local t = rng:pick(Words.tickers)
	local vals = Gui.series(rng, 18, rng:range(40, 300), 0.02, rng:range(-0.006, 0.01))
	local up = vals[#vals] >= vals[1]
	local pct = (vals[#vals] / vals[1] - 1) * 100
	header(gui, t .. "  " .. fmtPrice(vals[#vals]), string.format("%+.2f%%", pct), if up then UP else DOWN)
	for i = 1, 3 do
		Gui.frame(gui, 0.03, 0.14 + i * 0.17, 0.94, 0.006, DIM, 0.75)
	end
	Gui.lineChart(gui, W * 0.04, H * 0.2, W * 0.92, H * 0.5, vals, if up then UP else DOWN, math.max(2, H * 0.018))
	for i = 1, 8 do
		local bh = rng:range(0.03, 0.13)
		Gui.frame(gui, 0.04 + (i - 1) * 0.118, 0.97 - bh, 0.08, bh, DIM, 0.45)
	end
end

local function screenCandles(gui: Instance, W: number, H: number, rng: Rng.Rng)
	Gui.bg(gui, hex("#0A0F17"))
	local t = rng:pick(Words.tickers)
	local q = rng:range(30, 260)
	local chg = rng:normal(0.3, 1.5)
	header(gui, t .. " 1D  " .. fmtPrice(q), string.format("%+.2f%%", chg), if chg >= 0 then UP else DOWN)
	Gui.frame(gui, 0.03, 0.5, 0.94, 0.005, DIM, 0.8)
	Gui.candles(gui, W * 0.04, H * 0.2, W * 0.92, H * 0.72, rng, 14)
end

local function screenQuotes(gui: Instance, _W: number, _H: number, rng: Rng.Rng)
	Gui.bg(gui, NAVY)
	Gui.label(gui, "WATCHLIST", 0.03, 0.02, 0.6, 0.11, AMBER, { font = MONO })
	local order = rng:shuffle(Words.tickers)
	local rows = 7
	for i = 1, rows do
		local y = 0.15 + (i - 1) * 0.12
		if i % 2 == 0 then
			Gui.frame(gui, 0, y, 1, 0.12, NAVY2)
		end
		local q = Gui.quote(rng, order[i])
		Gui.label(gui, q, 0.04, y + 0.015, 0.92, 0.09, TEXT, { font = MONO, rich = true })
	end
end

local function screenTerminal(gui: Instance, W: number, H: number, rng: Rng.Rng)
	Gui.bg(gui, hex("#050505"))
	local keys = { { "EQ", hex("#E8B04A") }, { "FX", hex("#3A7BD5") }, { "NEWS", hex("#C0392B") }, { "MKT", hex("#27AE60") } }
	for i, k in keys do
		local f = Gui.frame(gui, 0.02 + (i - 1) * 0.16, 0.025, 0.145, 0.1, k[2])
		Gui.label(f, k[1], 0.08, 0.08, 0.84, 0.84, hex("#0A0A0A"), { font = MONO, align = Enum.TextXAlignment.Center })
	end
	local lines = {}
	for i = 1, 5 do
		local t = Words.tickers[(rng:int(1, #Words.tickers) + i) % #Words.tickers + 1]
		table.insert(lines, string.format("%-4s %8.2f  %+5.2f%%", t, rng:range(20, 400), rng:normal(0, 1.4)))
	end
	Gui.label(gui, table.concat(lines, "\n"), 0.03, 0.17, 0.6, 0.78, AMBER, {
		font = MONO,
		yAlign = Enum.TextYAlignment.Top,
	})
	local vals = Gui.series(rng, 9, 100, 0.03, 0.004)
	Gui.frame(gui, 0.66, 0.2, 0.31, 0.5, hex("#101010"))
	Gui.lineChart(gui, W * 0.67, H * 0.24, W * 0.29, H * 0.4, vals, AMBER, math.max(2, H * 0.015))
	Gui.label(gui, "STREET TERMINAL", 0.66, 0.78, 0.31, 0.1, DIM, { font = MONO, align = Enum.TextXAlignment.Right })
end

local function screenEmail(gui: Instance, _W: number, _H: number, rng: Rng.Rng)
	Gui.bg(gui, hex("#F7F8FA"))
	Gui.frame(gui, 0, 0, 1, 0.13, hex("#1F4E8C"))
	Gui.label(gui, "Inbox (" .. rng:int(12, 140) .. ")", 0.03, 0.015, 0.6, 0.1, hex("#FFFFFF"))
	Gui.frame(gui, 0, 0.13, 0.22, 0.87, hex("#E4E8EE"))
	local mails = rng:shuffle(Words.emails)
	for i = 1, 6 do
		local y = 0.16 + (i - 1) * 0.14
		local m = mails[(i - 1) % #mails + 1]
		local unread = i <= 2
		if unread then
			Gui.frame(gui, 0.22, y - 0.015, 0.78, 0.14, hex("#E3EDFB"))
		end
		Gui.label(gui, m[1], 0.25, y, 0.24, 0.1, hex("#1A1D21"), {
			font = if unread then Enum.Font.GothamBold else Enum.Font.Gotham,
		})
		Gui.label(gui, m[2], 0.5, y, 0.48, 0.1, hex("#4A5260"), { font = Enum.Font.Gotham })
	end
end

local function screenSheet(gui: Instance, _W: number, _H: number, rng: Rng.Rng)
	Gui.bg(gui, hex("#FFFFFF"))
	Gui.frame(gui, 0, 0, 1, 0.1, hex("#1E7145"))
	Gui.label(gui, "Model_v" .. rng:int(3, 41) .. ".xlsx", 0.03, 0.01, 0.6, 0.08, hex("#FFFFFF"), {
		font = Enum.Font.Gotham,
	})
	Gui.frame(gui, 0, 0.1, 1, 0.08, hex("#E6E6E6"))
	local grid = hex("#D0D4D9")
	for i = 1, 4 do
		Gui.frame(gui, i * 0.2, 0.1, 0.004, 0.9, grid)
	end
	for i = 1, 7 do
		Gui.frame(gui, 0, 0.18 + i * 0.115, 1, 0.004, grid)
	end
	local labels = { "Revenue", "EBITDA", "Margin", "Capex", "FCF", "EV/EBITDA", "IRR" }
	Gui.label(gui, table.concat(labels, "\n"), 0.02, 0.19, 0.18, 0.8, hex("#1A1D21"), {
		font = Enum.Font.Gotham,
		yAlign = Enum.TextYAlignment.Top,
		scaled = true,
	})
	for col = 1, 4 do
		local vals = {}
		local base = rng:range(200, 900)
		for row = 1, 7 do
			if row == 3 then
				table.insert(vals, string.format("%.1f%%", rng:range(12, 38)))
			elseif row >= 6 then
				table.insert(vals, string.format("%.1fx", rng:range(6, 14)))
			else
				table.insert(vals, string.format("%.0f", base * (1 + col * 0.07) / row))
			end
		end
		Gui.label(gui, table.concat(vals, "\n"), 0.2 * col + 0.015, 0.19, 0.17, 0.8, hex("#0B3D91"), {
			font = MONO,
			yAlign = Enum.TextYAlignment.Top,
			align = Enum.TextXAlignment.Right,
		})
	end
	local sel = Gui.frame(gui, 0.6, 0.18 + 0.115 * rng:int(1, 6), 0.2, 0.115, hex("#FFFFFF"), 1)
	Gui.stroke(sel, hex("#1E7145"), 2)
end

local function screenDeck(gui: Instance, _W: number, _H: number, rng: Rng.Rng)
	Gui.bg(gui, hex("#FFFFFF"))
	Gui.frame(gui, 0, 0, 1, 0.16, hex("#0B1F3A"))
	Gui.label(gui, "Situation Overview", 0.04, 0.025, 0.7, 0.11, hex("#FFFFFF"))
	Gui.frame(gui, 0, 0.16, 1, 0.012, hex("#C9A54C"))
	for i = 1, 5 do
		local bh = 0.12 + i * 0.07 + rng:range(-0.03, 0.03)
		Gui.frame(gui, 0.06 + (i - 1) * 0.085, 0.88 - bh, 0.06, bh, if i == 5 then hex("#C9A54C") else hex("#173459"))
	end
	Gui.label(gui, "- Market leader\n- 22% EBITDA margin\n- Clear path to IPO", 0.52, 0.28, 0.45, 0.5, hex("#1A1D21"), {
		font = Enum.Font.Gotham,
		yAlign = Enum.TextYAlignment.Top,
	})
	Gui.label(gui, "STRICTLY CONFIDENTIAL", 0.04, 0.91, 0.5, 0.06, hex("#8A8F98"), { font = Enum.Font.Gotham })
end

local function screenNews(gui: Instance, _W: number, _H: number, rng: Rng.Rng)
	Gui.bg(gui, hex("#0E1A2B"))
	local tag = Gui.frame(gui, 0.03, 0.08, 0.3, 0.14, hex("#C0392B"))
	Gui.label(tag, "BREAKING", 0.06, 0.1, 0.88, 0.8, hex("#FFFFFF"), { align = Enum.TextXAlignment.Center })
	Gui.label(gui, rng:pick(Words.headlines), 0.03, 0.28, 0.94, 0.4, hex("#FFFFFF"), {
		font = Enum.Font.GothamBlack,
	})
	Gui.frame(gui, 0, 0.8, 1, 0.2, hex("#06101D"))
	Gui.label(gui, Gui.tickerLine(rng, 3), 0.02, 0.83, 1.4, 0.14, TEXT, { font = MONO, rich = true })
end

local SCREENS: { [string]: (Instance, number, number, Rng.Rng) -> () } = {
	chart = screenChart,
	candles = screenCandles,
	quotes = screenQuotes,
	terminal = screenTerminal,
	email = screenEmail,
	sheet = screenSheet,
	deck = screenDeck,
	news = screenNews,
}

-- Fills a monitor display part with a glowing screen of `kind` (see SCREEN_KINDS).
function Gui.screen(part: BasePart, kind: string, rng: Rng.Rng): SurfaceGui
	local gui, W, H = Gui.surface(part, Enum.NormalId.Front, {
		glow = true,
		brightness = 1.2,
		pps = 60,
		maxDistance = 90,
		name = "Screen",
	})
	local fn = SCREENS[kind] or screenChart
	fn(gui, W, H, rng)
	gui:SetAttribute("ScreenKind", kind)
	return gui
end

-- LED ticker: SurfaceGui > Frame "Viewport" (clipping) > TextLabel "TickerText". Runtime code may replace
-- TickerText.Text (RichText) and animate its Position.X to scroll.
function Gui.ticker(part: BasePart, rng: Rng.Rng, o: { face: Enum.NormalId?, text: string?, pps: number? }?): TextLabel
	local opts = o or {}
	local gui = Gui.surface(part, opts.face or Enum.NormalId.Front, {
		glow = true,
		brightness = 1.6,
		pps = opts.pps or 30,
		name = "Ticker",
	})
	Gui.bg(gui, hex("#050608"))
	local view = Gui.frame(gui, 0, 0.08, 1, 0.84, hex("#050608"), 1)
	view.Name = "Viewport"
	view.ClipsDescendants = true
	local label = Gui.label(view, opts.text or Gui.tickerLine(rng), 0, 0, 1, 1, TEXT, {
		font = MONO,
		weight = Enum.FontWeight.Bold,
		rich = true,
		name = "TickerText",
	})
	label.TextWrapped = false
	return label
end

---------------------------------------------------------------------------------------------------
-- Abstract paintings (variant 1-8)
---------------------------------------------------------------------------------------------------
local PALETTES: { { Color3 } } = {
	{ hex("#C8553D"), hex("#F28F3B"), hex("#FFD5C2"), hex("#588B8B"), hex("#2D3047") },
	{ hex("#22577A"), hex("#38A3A5"), hex("#57CC99"), hex("#80ED99"), hex("#F1F7EE") },
	{ hex("#6B4226"), hex("#D9A441"), hex("#E8D8C3"), hex("#3E5641"), hex("#A24936") },
	{ hex("#111111"), hex("#3A3A3A"), hex("#9A9A9A"), hex("#F2F2F2"), hex("#C0392B") },
	{ hex("#2E1760"), hex("#7A1E48"), hex("#D4A017"), hex("#0F5257"), hex("#F4EBD9") },
	{ hex("#F7C5CC"), hex("#A0CED9"), hex("#FFEE93"), hex("#5B8C85"), hex("#FCF5EC") },
}
Gui.PALETTES = PALETTES
Gui.PAINTING_VARIANTS = 8

local function shuffled(rng: Rng.Rng, list: { Color3 }): { Color3 }
	return rng:shuffle(list)
end

local function paintColorField(root: Frame, _W: number, _H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = pal[1]
	local n = rng:int(2, 3)
	local y = 0.08
	local gap = 0.05
	local total = 0.84 - gap * (n - 1)
	for i = 1, n do
		local h = total / n * rng:range(0.8, 1.2)
		h = math.min(h, 0.92 - y)
		local f = Gui.frame(root, 0.1, y, 0.8, h, pal[i + 1])
		Gui.round(f, 0, 6)
		Gui.gradient(f, pal[i + 1], pal[i + 1]:Lerp(pal[1], 0.35), 90)
		y += h + gap
	end
end

local function paintGrid(root: Frame, _W: number, _H: number, rng: Rng.Rng, _pal: { Color3 })
	root.BackgroundColor3 = hex("#F4F1EA")
	local ink = hex("#151515")
	local xs = { rng:range(0.18, 0.3), rng:range(0.5, 0.62), rng:range(0.78, 0.88) }
	local ys = { rng:range(0.2, 0.35), rng:range(0.55, 0.7) }
	local fills = { hex("#C8102E"), hex("#0B3D91"), hex("#F2C230") }
	-- coloured cells first, so the black lines sit on top
	Gui.frame(root, 0, 0, xs[1], ys[1], fills[1])
	Gui.frame(root, xs[2], ys[2], 1 - xs[2], 1 - ys[2], fills[2])
	Gui.frame(root, xs[1], ys[2], xs[2] - xs[1], 1 - ys[2], fills[3])
	for _, x in xs do
		Gui.frame(root, x - 0.012, 0, 0.024, 1, ink)
	end
	for _, y in ys do
		Gui.frame(root, 0, y - 0.016, 1, 0.032, ink)
	end
end

local function paintCircles(root: Frame, W: number, H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = pal[5]
	local m = math.min(W, H)
	for i = 1, 6 do
		local d = m * rng:range(0.22, 0.55)
		local cx = rng:range(d / 2, W - d / 2)
		local cy = rng:range(d / 2, H - d / 2)
		Gui.dot(root, cx, cy, d, pal[(i - 1) % 4 + 1], rng:range(0.05, 0.35))
	end
end

local function paintStripes(root: Frame, W: number, H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = pal[1]
	local band = Gui.frame(root, 0, 0, 1, 1, pal[1])
	Gui.stripes(band, { pal[1], pal[2], pal[3], pal[4] }, rng:int(5, 9), rng:range(30, 60))
	local d = math.min(W, H) * 0.34
	Gui.dot(root, W * rng:range(0.3, 0.7), H * rng:range(0.35, 0.65), d, pal[5])
end

local function paintHorizon(root: Frame, W: number, H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = pal[3]
	Gui.gradient(root, pal[3], pal[2], 90)
	Gui.dot(root, W * rng:range(0.25, 0.75), H * rng:range(0.25, 0.45), math.min(W, H) * 0.3, pal[5])
	for i = 1, 3 do
		local top = 0.5 + i * 0.1 + rng:range(-0.04, 0.04)
		local hill = Gui.frame(root, rng:range(-0.6, -0.1), top, rng:range(1.4, 1.9), 0.8, pal[(i % 2) + 1]:Lerp(pal[4], i / 3))
		Gui.round(hill, 0.5)
	end
end

local function paintShards(root: Frame, W: number, H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = pal[1]:Lerp(Color3.new(0, 0, 0), 0.55)
	for i = 1, 7 do
		local w = W * rng:range(0.14, 0.3)
		local h = H * rng:range(0.05, 0.14)
		local r = math.sqrt(w * w + h * h) / 2
		local cx = rng:range(r, math.max(r, W - r))
		local cy = rng:range(r, math.max(r, H - r))
		local f = Gui.px(root, cx - w / 2, cy - h / 2, w, h, pal[(i - 1) % 5 + 1], rng:range(0, 0.25))
		f.Rotation = rng:range(-70, 70)
	end
end

local function paintDots(root: Frame, W: number, H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = pal[5]
	local cols, rows = 5, 4
	local cw, ch = W / cols, H / rows
	local m = math.min(cw, ch)
	for r = 1, rows do
		for c = 1, cols do
			local d = m * rng:range(0.35, 0.85)
			Gui.dot(root, cw * (c - 0.5), ch * (r - 0.5), d, pal[(r + c) % 4 + 1])
		end
	end
end

local function paintWaves(root: Frame, _W: number, _H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = pal[5]
	local y = 0
	for i = 1, 6 do
		local h = rng:range(0.13, 0.2)
		local f = Gui.frame(root, rng:range(-0.05, 0), y, 1.1, h + 0.03, pal[(i - 1) % 4 + 1])
		Gui.gradient(f, pal[(i - 1) % 4 + 1], pal[i % 4 + 1], rng:range(-12, 12))
		Gui.round(f, 0.4)
		y += h
		if y > 1 then
			break
		end
	end
end

local PAINTERS = { paintColorField, paintGrid, paintCircles, paintStripes, paintHorizon, paintShards, paintDots, paintWaves }

-- Paints an abstract artwork filling `gui` (pixel size W x H). variant 1-8; the palette comes from rng.
function Gui.painting(gui: Instance, W: number, H: number, variant: number, rng: Rng.Rng): Frame
	local root = Gui.frame(gui, 0, 0, 1, 1, hex("#FFFFFF"))
	root.Name = "Painting"
	root.ClipsDescendants = true
	local pal = shuffled(rng, PALETTES[rng:int(1, #PALETTES)])
	local v = math.clamp(math.floor(variant), 1, #PAINTERS)
	PAINTERS[v](root, W, H, rng, pal)
	return root
end

---------------------------------------------------------------------------------------------------
-- Boards, clocks, posters
---------------------------------------------------------------------------------------------------
function Gui.whiteboard(gui: Instance, W: number, H: number, rng: Rng.Rng)
	local blue = hex("#1F4FB5")
	local red = hex("#C62828")
	local black = hex("#202124")
	local marker = Enum.Font.PermanentMarker
	Gui.label(gui, Words.whiteboard[1], 0.04, 0.04, 0.4, 0.13, blue, { font = marker })
	-- flow of boxes with arrows
	local names = { "COMPS", "DCF", "LBO" }
	local bw, bh = 0.17, 0.14
	for i, n in names do
		local x = 0.05 + (i - 1) * 0.24
		local box = Gui.frame(gui, x, 0.27, bw, bh, hex("#FFFFFF"), 1)
		Gui.stroke(box, black, 2)
		Gui.label(box, n, 0.08, 0.1, 0.84, 0.8, black, { font = marker, align = Enum.TextXAlignment.Center })
		if i < #names then
			local x1 = (x + bw + 0.01) * W
			Gui.arrow(gui, x1, 0.34 * H, x1 + 0.05 * W, 0.34 * H, 2, black)
		end
	end
	Gui.label(gui, Words.whiteboard[2], 0.05, 0.5, 0.4, 0.12, black, { font = marker })
	Gui.label(gui, Words.whiteboard[3], 0.05, 0.64, 0.3, 0.11, red, { font = marker })
	Gui.label(gui, rng:pick({ Words.whiteboard[5], Words.whiteboard[6] }), 0.05, 0.8, 0.36, 0.12, red, {
		font = marker,
		rotation = -4,
	})
	-- hand-drawn chart
	local x0, y0, cw, ch = 0.62 * W, 0.2 * H, 0.33 * W, 0.62 * H
	Gui.line(gui, x0, y0 + ch, x0 + cw, y0 + ch, 2, black)
	Gui.line(gui, x0, y0, x0, y0 + ch, 2, black)
	local vals = Gui.series(rng, 6, 10, 0.12, 0.08)
	Gui.lineChart(gui, x0 + 4, y0 + 6, cw - 8, ch - 12, vals, blue, 3)
	Gui.dot(gui, x0 + cw - 6, y0 + 10, 16, red, 0.6)
end

function Gui.chalkboard(gui: Instance, W: number, H: number, rng: Rng.Rng)
	local chalk = hex("#ECEDE6")
	local yellow = hex("#F1E28A")
	local font = Enum.Font.Kalam
	local lines = rng:shuffle({ Words.chalkboard[1], Words.chalkboard[2], Words.chalkboard[5] })
	for i, l in lines do
		Gui.label(gui, l, 0.04, 0.06 + (i - 1) * 0.16, 0.5, 0.13, chalk, { font = font, transparency = 0.1 })
	end
	local box = Gui.frame(gui, 0.04, 0.62, 0.38, 0.2, chalk, 1)
	Gui.stroke(box, yellow, 2, 0.15)
	Gui.label(box, Words.chalkboard[3], 0.05, 0.1, 0.9, 0.8, yellow, { font = font, align = Enum.TextXAlignment.Center })
	-- supply and demand
	local x0, y0, cw, ch = 0.6 * W, 0.12 * H, 0.32 * W, 0.7 * H
	Gui.line(gui, x0, y0, x0, y0 + ch, 2, chalk, 0.1)
	Gui.line(gui, x0, y0 + ch, x0 + cw, y0 + ch, 2, chalk, 0.1)
	Gui.line(gui, x0 + cw * 0.08, y0 + ch * 0.1, x0 + cw * 0.92, y0 + ch * 0.9, 2, yellow, 0.1)
	Gui.line(gui, x0 + cw * 0.08, y0 + ch * 0.9, x0 + cw * 0.92, y0 + ch * 0.1, 2, chalk, 0.1)
	Gui.label(gui, Words.chalkboard[4], 0.6, 0.86, 0.32, 0.1, chalk, { font = font, align = Enum.TextXAlignment.Center })
end

-- Round clock dial: 12 ticks and two hands named "HourHand" and "MinuteHand" (pivot at the centre).
function Gui.clockFace(gui: Instance, W: number, H: number, hour: number, minute: number, ink: Color3)
	local cx, cy = W / 2, H / 2
	local r = math.min(W, H) / 2
	for i = 0, 11 do
		local a = math.rad(i * 30)
		local long = i % 3 == 0
		local len = if long then r * 0.16 else r * 0.09
		local rr = r * 0.82 - len / 2
		local f = Gui.px(gui, 0, 0, if long then r * 0.06 else r * 0.035, len, ink)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(cx + math.sin(a) * rr, cy - math.cos(a) * rr)
		f.Rotation = i * 30
	end
	local function hand(name: string, angleDeg: number, len: number, thick: number, color: Color3)
		local a = math.rad(angleDeg)
		local f = Gui.px(gui, 0, 0, thick, len, color)
		f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(cx + math.sin(a) * len / 2, cy - math.cos(a) * len / 2)
		f.Rotation = angleDeg
		Gui.round(f, 0.5)
	end
	hand("HourHand", (hour % 12) * 30 + minute * 0.5, r * 0.48, r * 0.07, ink)
	hand("MinuteHand", minute * 6, r * 0.72, r * 0.045, ink)
	Gui.dot(gui, cx, cy, r * 0.12, hex("#B8933F"))
end

-- Poster: title, body text and colour blocks. colors = {background, accent, text}.
function Gui.poster(gui: Instance, title: string, body: string, colors: { Color3 }, rng: Rng.Rng, font: Enum.Font?)
	local bgc = colors[1] or hex("#F4F1EA")
	local accent = colors[2] or hex("#C8553D")
	local ink = colors[3] or hex("#1A1A1A")
	Gui.bg(gui, bgc)
	local style = rng:int(1, 3)
	if style == 1 then
		Gui.frame(gui, 0, 0, 1, 0.3, accent)
		Gui.label(gui, title, 0.06, 0.04, 0.88, 0.22, bgc, { font = font or Enum.Font.GothamBlack, align = Enum.TextXAlignment.Center })
		Gui.label(gui, body, 0.08, 0.38, 0.84, 0.5, ink, { font = Enum.Font.Gotham, align = Enum.TextXAlignment.Center })
	elseif style == 2 then
		Gui.frame(gui, 0.06, 0.06, 0.88, 0.02, accent)
		Gui.label(gui, title, 0.06, 0.12, 0.88, 0.3, ink, { font = font or Enum.Font.Oswald })
		Gui.dot(gui, 0, 0, 1, accent, 1)
		Gui.frame(gui, 0.06, 0.46, 0.3, 0.3, accent)
		Gui.label(gui, body, 0.42, 0.46, 0.52, 0.42, ink, { font = Enum.Font.Gotham, yAlign = Enum.TextYAlignment.Top })
	else
		Gui.label(gui, title, 0.06, 0.06, 0.88, 0.28, accent, { font = font or Enum.Font.SpecialElite, align = Enum.TextXAlignment.Center })
		Gui.label(gui, body, 0.08, 0.38, 0.84, 0.36, ink, { font = Enum.Font.SpecialElite, align = Enum.TextXAlignment.Center })
		for i = 0, 5 do
			Gui.frame(gui, 0.04 + i * 0.16, 0.82, 0.12, 0.14, ink, 0.1)
		end
	end
end

return Gui
