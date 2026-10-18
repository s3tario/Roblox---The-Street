--!strict
-- Terminal look (owned by `market`): a palette derived from the current Theme tokens plus small themed primitives.
--   street -> "terminal": a dark, slick trading terminal (near-black navy, gold section labels, mono numbers)
--   campus -> "laptop":   an old laptop (plastic bezel, cold LCD tint over charcoal, mustard labels)
-- Every primitive re-applies its colours on Theme.Changed (Kit.themed), so a hire mid-session restyles in place.
-- Text colours are keys ("text" | "dim" | "label" | "accent" | "up" | "down" | "warn" | "accentText") stored on the
-- instance, so Style.recolor survives theme changes.
--
--   Style.palette(tokens) -> Pal          Style.color(pal, key) -> Color3      Style.variant() -> "terminal"|"laptop"
--   Style.bind(inst, fn(pal, tokens))     Style.box(name, opts?) -> Frame      Style.text(name, text, opts?) -> TextLabel
--   Style.recolor(label, key)             Style.section(title, order?) -> TextLabel
--   Style.pill(name, text, colorKey) -> (Frame, TextLabel)   Style.hline(name?) -> Frame   Style.row(name, h?) -> Frame

local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Theme = require(script.Parent.Parent.Parent:WaitForChild("Theme"))

export type Pal = {
	variant: string,
	bg: Color3,
	panel: Color3,
	panelAlt: Color3,
	line: Color3,
	text: Color3,
	dim: Color3,
	label: Color3,
	accent: Color3,
	accentText: Color3,
	up: Color3,
	down: Color3,
	warn: Color3,
	bezel: Color3,
	bezelEdge: Color3,
	radius: number,
}

export type TextOpts = {
	size: (string | number)?, -- Theme text size key or px (default "sm")
	font: string?, -- "body" | "bold" | "mono" | "head" | "display" (default "body")
	color: string?, -- palette key (default "text")
	align: ("left" | "center" | "right")?,
	wrap: boolean?,
	autoSize: ("x" | "y" | "xy" | "none")?, -- default "xy"
	size2: UDim2?, -- explicit Size (with autoSize "none" or "y")
	order: number?,
	truncate: boolean?,
}

export type BoxOpts = {
	color: string?, -- palette key (default "panel")
	size: UDim2?,
	stroke: boolean?, -- default true
	radius: number?, -- default palette radius
	pad: number?, -- inner padding (none when nil)
	autoY: boolean?, -- automatic height
	transparency: number?,
	order: number?,
}

local Style = {}

local shade = Kit.shade
local LCD = Color3.fromRGB(34, 46, 54) -- cold LCD tint for the laptop screen

function Style.palette(t: Theme.Tokens): Pal
	local c = t.colors
	if t.name == "campus" then
		local bg = c.panel:Lerp(LCD, 0.45)
		return {
			variant = "laptop",
			bg = bg,
			panel = shade(bg, 0.05),
			panelAlt = shade(bg, 0.1),
			line = c.border,
			text = c.text,
			dim = c.textDim,
			label = c.accent,
			accent = c.accent,
			accentText = c.accentText,
			up = c.good,
			down = c.bad,
			warn = c.warn,
			bezel = c.surface,
			bezelEdge = shade(c.surface, 0.18),
			radius = 3,
		}
	end
	return {
		variant = "terminal",
		bg = shade(c.bg, -0.6),
		panel = shade(c.bg, -0.32),
		panelAlt = shade(c.panel, -0.1),
		line = shade(c.border, -0.15),
		text = c.text,
		dim = c.textDim,
		label = c.accent,
		accent = shade(c.accent, 0.12),
		accentText = c.accentText,
		up = c.good,
		down = c.bad,
		warn = c.warn,
		bezel = shade(c.bg, -0.6),
		bezelEdge = c.border,
		radius = 6,
	}
end

function Style.variant(): string
	return Style.palette(Theme.get()).variant
end

-- Theme colour keys (View.changeColor and Kit specs use them) map onto the terminal palette.
Style.ALIASES = { good = "up", bad = "down", textDim = "dim", surface = "panelAlt" } :: { [string]: string }

function Style.color(pal: Pal, key: any): Color3
	local k = if type(key) == "string" then (Style.ALIASES[key] or key) else "text"
	local v = (pal :: any)[k]
	if typeof(v) == "Color3" then
		return v
	end
	return pal.text
end

function Style.bind(inst: Instance, fn: (pal: Pal, t: Theme.Tokens) -> ())
	Kit.themed(inst, function(t)
		fn(Style.palette(t), t)
	end)
end

local function fontFor(t: Theme.Tokens, key: string?): Font
	if key == "mono" then
		return t.fonts.mono
	elseif key == "bold" then
		return t.fonts.bodyBold
	elseif key == "head" then
		return t.fonts.heading
	elseif key == "display" then
		return t.fonts.display
	end
	return t.fonts.body
end

local function sizeFor(t: Theme.Tokens, spec: (string | number)?): number
	if type(spec) == "number" then
		return spec
	end
	local n = (t.text :: any)[spec or "sm"]
	return if type(n) == "number" then n else t.text.sm
end

local AUTOSIZE = {
	x = Enum.AutomaticSize.X,
	y = Enum.AutomaticSize.Y,
	xy = Enum.AutomaticSize.XY,
	none = Enum.AutomaticSize.None,
}
local ALIGN = {
	left = Enum.TextXAlignment.Left,
	center = Enum.TextXAlignment.Center,
	right = Enum.TextXAlignment.Right,
}

function Style.text(name: string, text: string, opts: TextOpts?): TextLabel
	local o: TextOpts = opts or {}
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Text = text
	l.RichText = false
	l.TextWrapped = o.wrap == true
	l.AutomaticSize = AUTOSIZE[o.autoSize or "xy"] or Enum.AutomaticSize.XY
	l.Size = o.size2 or UDim2.fromOffset(0, 0)
	l.TextXAlignment = ALIGN[o.align or "left"] or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.LayoutOrder = o.order or 0
	if o.truncate then
		l.TextTruncate = Enum.TextTruncate.AtEnd
	end
	l:SetAttribute("TermColor", o.color or "text")
	Style.bind(l, function(pal, t)
		l.FontFace = fontFor(t, o.font)
		l.TextSize = sizeFor(t, o.size)
		l.TextColor3 = Style.color(pal, l:GetAttribute("TermColor"))
	end)
	return l
end

function Style.recolor(label: TextLabel, key: string)
	if label:GetAttribute("TermColor") == key then
		return
	end
	label:SetAttribute("TermColor", key)
	label.TextColor3 = Style.color(Style.palette(Theme.get()), key)
end

function Style.setText(label: TextLabel, text: string, colorKey: string?)
	if label.Text ~= text then
		label.Text = text
	end
	if colorKey then
		Style.recolor(label, colorKey)
	end
end

function Style.box(name: string, opts: BoxOpts?): Frame
	local o: BoxOpts = opts or {}
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.Size = o.size or UDim2.new(1, 0, 0, 0)
	f.LayoutOrder = o.order or 0
	if o.autoY then
		f.AutomaticSize = Enum.AutomaticSize.Y
	end
	local corner = Instance.new("UICorner")
	corner.Parent = f
	local stroke: UIStroke? = nil
	if o.stroke ~= false then
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Thickness = 1
		s.Parent = f
		stroke = s
	end
	if o.pad then
		Kit.padding(f, o.pad)
	end
	f:SetAttribute("TermBg", o.color or "panel")
	Style.bind(f, function(pal)
		f.BackgroundColor3 = Style.color(pal, f:GetAttribute("TermBg"))
		f.BackgroundTransparency = o.transparency or 0
		corner.CornerRadius = UDim.new(0, o.radius or pal.radius)
		if stroke then
			stroke.Color = pal.line
		end
	end)
	return f
end

function Style.setBg(frame: Frame, key: string)
	if frame:GetAttribute("TermBg") == key then
		return
	end
	frame:SetAttribute("TermBg", key)
	frame.BackgroundColor3 = Style.color(Style.palette(Theme.get()), key)
end

-- Gold/mustard caps label that heads a section.
function Style.section(title: string, order: number?): TextLabel
	local l = Style.text("Title", string.upper(title), { size = "xs", font = "bold", color = "label", order = order })
	return l
end

function Style.pill(name: string, text: string, colorKey: string): (Frame, TextLabel)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.Size = UDim2.fromOffset(0, 0)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 999)
	corner.Parent = f
	Kit.padding(f, 8, 3)
	local l = Style.text("Text", text, { size = "xs", font = "bold", color = "accentText" })
	l.Parent = f
	f:SetAttribute("TermBg", colorKey)
	Style.bind(f, function(pal)
		f.BackgroundColor3 = Style.color(pal, f:GetAttribute("TermBg"))
		local bg = f.BackgroundColor3
		l.TextColor3 = Theme.contrastText(bg)
	end)
	return f, l
end

function Style.setPill(pill: Frame, label: TextLabel, text: string, colorKey: string)
	label.Text = text
	if pill:GetAttribute("TermBg") ~= colorKey then
		pill:SetAttribute("TermBg", colorKey)
		local bg = Style.color(Style.palette(Theme.get()), colorKey)
		pill.BackgroundColor3 = bg
		label.TextColor3 = Theme.contrastText(bg)
	end
end

function Style.hline(name: string?, order: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name or "Line"
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, 1)
	f.LayoutOrder = order or 0
	Style.bind(f, function(pal)
		f.BackgroundColor3 = pal.line
	end)
	return f
end

-- Transparent horizontal row (UIListLayout, vertically centred).
function Style.row(name: string, height: number?, gap: number?): Frame
	local f = Kit.frame(name, UDim2.new(1, 0, 0, height or 28))
	local l = Kit.list(f, true, gap or 8)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	return f
end

-- Transparent vertical stack with automatic height.
function Style.stack(name: string, gap: number?, order: number?): Frame
	local f = Kit.frame(name, UDim2.new(1, 0, 0, 0))
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = order or 0
	Kit.list(f, false, gap or 6)
	return f
end

return Style
