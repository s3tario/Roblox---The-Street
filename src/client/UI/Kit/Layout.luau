--!strict
-- Layout components: Panel, Card, List, Grid, Scroll, Divider, Spacer, Tile.

local Core = require(script.Parent.Core)
local Text = require(script.Parent.Text)

type ColorSpec = Core.ColorSpec

local Layout = {}

-- Adds children in order (LayoutOrder increments) and returns the child. Accepts a GuiObject or any Kit
-- component table (anything with a `frame`).
export type Child = any
local function makeAdder(parent: Instance): (child: Child) -> GuiObject
	local order = 0
	return function(child: Child): GuiObject
		local inst: any = if typeof(child) == "Instance"
			then child
			elseif type(child) == "table" then child.frame
			else nil
		assert(typeof(inst) == "Instance" and inst:IsA("GuiObject"), "Kit add() expects a GuiObject or a Kit component")
		order += 1
		inst.LayoutOrder = order
		inst.Parent = parent
		return inst
	end
end
Layout.makeAdder = makeAdder

---------------------------------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------------------------------
export type PanelOpts = {
	color: ColorSpec?, -- default "panel"
	transparency: number?, -- default theme panelTransparency
	padding: (number | boolean)?, -- true/nil = theme pad, false = none, number = px
	radius: number?,
	stroke: boolean?, -- default true
	size: UDim2?, -- default full width, automatic height
	autoSize: ("x" | "y" | "xy" | "none")?,
	list: boolean?, -- add a vertical UIListLayout (default false)
	gap: number?,
	name: string?,
	layoutOrder: number?,
}
export type Panel = { frame: Frame, add: (child: Child) -> GuiObject }

local function autoSizeEnum(a: string?, default: Enum.AutomaticSize): Enum.AutomaticSize
	if a == "x" then
		return Enum.AutomaticSize.X
	elseif a == "y" then
		return Enum.AutomaticSize.Y
	elseif a == "xy" then
		return Enum.AutomaticSize.XY
	elseif a == "none" then
		return Enum.AutomaticSize.None
	end
	return default
end
Layout.autoSizeEnum = autoSizeEnum

function Layout.Panel(opts: PanelOpts?): Panel
	local o: PanelOpts = opts or {}
	local f = Instance.new("Frame")
	f.Name = o.name or "Panel"
	f.BorderSizePixel = 0
	f.Size = o.size or UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = autoSizeEnum(o.autoSize, if o.size then Enum.AutomaticSize.None else Enum.AutomaticSize.Y)
	f.LayoutOrder = o.layoutOrder or 0
	local corner = Core.corner(f, o.radius)
	local stroke = if o.stroke ~= false then Core.stroke(f) else nil
	local pad: UIPadding? = nil
	if o.padding ~= false then
		pad = Core.padding(f, if type(o.padding) == "number" then o.padding else nil)
	end
	local list = if o.list then Core.list(f, false, o.gap) else nil
	Core.themed(f, function(t)
		f.BackgroundColor3 = Core.color(t, o.color, "panel")
		f.BackgroundTransparency = o.transparency or t.panelTransparency
		corner.CornerRadius = UDim.new(0, o.radius or t.radius)
		if stroke then
			stroke.Color = t.colors.border
			stroke.Thickness = t.stroke
		end
		if pad and type(o.padding) ~= "number" then
			local p = pad
			p.PaddingLeft = UDim.new(0, t.pad)
			p.PaddingRight = UDim.new(0, t.pad)
			p.PaddingTop = UDim.new(0, t.pad)
			p.PaddingBottom = UDim.new(0, t.pad)
		end
		if list and o.gap == nil then
			list.Padding = UDim.new(0, t.gap)
		end
	end)
	return { frame = f, add = makeAdder(f) }
end

---------------------------------------------------------------------------------------------------
-- Card: panelAlt surface with optional title/subtitle and a vertical content frame.
---------------------------------------------------------------------------------------------------
export type CardOpts = {
	title: string?,
	subtitle: string?,
	size: UDim2?,
	padding: number?,
	color: ColorSpec?, -- default "panelAlt"
	onClick: (() -> ())?, -- makes the whole card a button
	gap: number?,
	name: string?,
	layoutOrder: number?,
}
export type Card = {
	frame: GuiObject,
	content: Frame,
	add: (child: Child) -> GuiObject,
	setTitle: (text: string) -> (),
	setSubtitle: (text: string) -> (),
}

function Layout.Card(opts: CardOpts?): Card
	local o: CardOpts = opts or {}
	local root: GuiObject
	local button: TextButton? = nil
	if o.onClick then
		local b = Instance.new("TextButton")
		b.Text = ""
		b.AutoButtonColor = false
		button = b
		root = b
	else
		root = Instance.new("Frame")
	end
	root.Name = o.name or "Card"
	root.BorderSizePixel = 0
	root.Size = o.size or UDim2.new(1, 0, 0, 0)
	root.AutomaticSize = if o.size then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
	root.LayoutOrder = o.layoutOrder or 0
	local corner = Core.corner(root)
	local stroke = Core.stroke(root)
	Core.padding(root, o.padding)
	Core.list(root, false, o.gap or 6)

	local title = Text.Label({ text = o.title or "", size = "lg", font = "heading", name = "Title", layoutOrder = 1 })
	title.frame.Visible = o.title ~= nil
	title.frame.Parent = root
	local subtitle =
		Text.Label({ text = o.subtitle or "", size = "sm", color = "textDim", name = "Subtitle", layoutOrder = 2 })
	subtitle.frame.Visible = o.subtitle ~= nil
	subtitle.frame.Parent = root

	local content = Core.frame("Content", UDim2.new(1, 0, 0, 0))
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.LayoutOrder = 3
	Core.list(content, false, o.gap or 6)
	content.Parent = root

	local pressed, hover = false, false
	local function paint(t: Core.Tokens)
		local base = Core.color(t, o.color, "panelAlt")
		root.BackgroundColor3 = if pressed
			then Core.shade(base, -0.12)
			elseif hover then Core.shade(base, 0.06)
			else base
		root.BackgroundTransparency = 0
		corner.CornerRadius = UDim.new(0, t.radius)
		stroke.Color = t.colors.border
		stroke.Thickness = t.stroke
	end
	Core.themed(root, paint)

	if button then
		local onClick = o.onClick :: () -> ()
		Core.connect(button, "Activated", function()
			Core.sound("click")
			onClick()
		end)
		Core.connect(button, "MouseEnter", function()
			hover = true
			paint(Core.Theme.get())
		end)
		Core.connect(button, "MouseLeave", function()
			hover = false
			pressed = false
			paint(Core.Theme.get())
		end)
		Core.connect(button, "InputBegan", function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				pressed = true
				paint(Core.Theme.get())
			end
		end)
		Core.connect(button, "InputEnded", function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				pressed = false
				paint(Core.Theme.get())
			end
		end)
	end

	return {
		frame = root,
		content = content,
		add = makeAdder(content),
		setTitle = function(s: string)
			title.frame.Text = s
			title.frame.Visible = s ~= ""
		end,
		setSubtitle = function(s: string)
			subtitle.frame.Text = s
			subtitle.frame.Visible = s ~= ""
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- List: transparent frame with a UIListLayout.
---------------------------------------------------------------------------------------------------
export type ListOpts = {
	direction: ("vertical" | "horizontal")?,
	gap: number?,
	padding: number?,
	align: ("start" | "center" | "end")?, -- cross-axis alignment
	justify: ("start" | "center" | "end")?, -- main-axis alignment
	wraps: boolean?,
	size: UDim2?,
	autoSize: ("x" | "y" | "xy" | "none")?,
	name: string?,
	layoutOrder: number?,
}
export type List = {
	frame: Frame,
	layout: UIListLayout,
	add: (child: Child) -> GuiObject,
	clear: () -> (),
}

local H_ALIGN = {
	start = Enum.HorizontalAlignment.Left,
	center = Enum.HorizontalAlignment.Center,
	["end"] = Enum.HorizontalAlignment.Right,
}
local V_ALIGN = {
	start = Enum.VerticalAlignment.Top,
	center = Enum.VerticalAlignment.Center,
	["end"] = Enum.VerticalAlignment.Bottom,
}

-- Destroys every GuiObject child (keeps layouts, padding and other UI components).
local function clearGuiChildren(parent: Instance)
	for _, c in parent:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end
Layout.clearGuiChildren = clearGuiChildren

function Layout.List(opts: ListOpts?): List
	local o: ListOpts = opts or {}
	local horizontal = o.direction == "horizontal"
	local f = Core.frame(o.name or "List")
	f.LayoutOrder = o.layoutOrder or 0
	if o.size then
		f.Size = o.size
		f.AutomaticSize = autoSizeEnum(o.autoSize, Enum.AutomaticSize.None)
	elseif horizontal then
		f.Size = UDim2.new(0, 0, 0, 0)
		f.AutomaticSize = autoSizeEnum(o.autoSize, Enum.AutomaticSize.XY)
	else
		f.Size = UDim2.new(1, 0, 0, 0)
		f.AutomaticSize = autoSizeEnum(o.autoSize, Enum.AutomaticSize.Y)
	end
	local layout = Core.list(f, horizontal, o.gap)
	layout.Wraps = o.wraps == true
	if horizontal then
		layout.VerticalAlignment = V_ALIGN[o.align or "center"] or Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = H_ALIGN[o.justify or "start"] or Enum.HorizontalAlignment.Left
	else
		layout.HorizontalAlignment = H_ALIGN[o.align or "start"] or Enum.HorizontalAlignment.Left
		layout.VerticalAlignment = V_ALIGN[o.justify or "start"] or Enum.VerticalAlignment.Top
	end
	if o.padding then
		Core.padding(f, o.padding)
	end
	if o.gap == nil then
		Core.themed(layout, function(t)
			layout.Padding = UDim.new(0, t.gap)
		end)
	end
	return {
		frame = f,
		layout = layout,
		add = makeAdder(f),
		clear = function()
			clearGuiChildren(f)
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- Grid: UIGridLayout with fixed cells or a fixed number of columns.
---------------------------------------------------------------------------------------------------
export type GridOpts = {
	columns: number?, -- fixed column count (cells stretch to fill the width)
	cellSize: (UDim2 | Vector2)?, -- used when columns is nil (default 120x120)
	cellHeight: number?, -- with columns (default 120)
	gap: number?,
	padding: number?,
	size: UDim2?,
	align: ("start" | "center" | "end")?,
	name: string?,
	layoutOrder: number?,
}
export type Grid = {
	frame: Frame,
	layout: UIGridLayout,
	add: (child: Child) -> GuiObject,
	clear: () -> (),
	setColumns: (n: number) -> (),
}

function Layout.Grid(opts: GridOpts?): Grid
	local o: GridOpts = opts or {}
	local f = Core.frame(o.name or "Grid", o.size or UDim2.new(1, 0, 0, 0))
	f.AutomaticSize = if o.size then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
	f.LayoutOrder = o.layoutOrder or 0
	local g = Instance.new("UIGridLayout")
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = H_ALIGN[o.align or "start"] or Enum.HorizontalAlignment.Left
	g.Parent = f
	if o.padding then
		Core.padding(f, o.padding)
	end
	local columns = o.columns
	local function apply(t: Core.Tokens)
		local gap = o.gap or t.gap
		g.CellPadding = UDim2.fromOffset(gap, gap)
		if columns and columns > 0 then
			local n = columns
			g.CellSize = UDim2.new(1 / n, -Core.px(gap * (n - 1) / n), 0, Core.px(o.cellHeight or 120))
			g.FillDirectionMaxCells = n
		else
			local cs = o.cellSize
			if typeof(cs) == "Vector2" then
				g.CellSize = UDim2.fromOffset(Core.px(cs.X), Core.px(cs.Y))
			elseif typeof(cs) == "UDim2" then
				g.CellSize = cs
			else
				g.CellSize = UDim2.fromOffset(120, 120)
			end
			g.FillDirectionMaxCells = 0
		end
	end
	Core.themed(g, apply)
	return {
		frame = f,
		layout = g,
		add = makeAdder(f),
		clear = function()
			clearGuiChildren(f)
		end,
		setColumns = function(n: number)
			columns = math.max(1, math.floor(n))
			apply(Core.Theme.get())
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- Scroll: ScrollingFrame with automatic canvas size and an optional list layout.
---------------------------------------------------------------------------------------------------
export type ScrollOpts = {
	direction: ("vertical" | "horizontal")?,
	gap: number?,
	padding: number?,
	layout: boolean?, -- default true
	size: UDim2?, -- default fill parent
	name: string?,
	layoutOrder: number?,
}
export type Scroll = {
	frame: ScrollingFrame,
	content: ScrollingFrame,
	layout: UIListLayout?,
	add: (child: Child) -> GuiObject,
	clear: () -> (),
	scrollToTop: () -> (),
}

function Layout.Scroll(opts: ScrollOpts?): Scroll
	local o: ScrollOpts = opts or {}
	local horizontal = o.direction == "horizontal"
	local s = Instance.new("ScrollingFrame")
	s.Name = o.name or "Scroll"
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = o.size or UDim2.fromScale(1, 1)
	s.LayoutOrder = o.layoutOrder or 0
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y
	s.ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y
	s.ScrollBarThickness = 6
	s.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	s.HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	s.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	s.ScrollingEnabled = true
	s.Selectable = false
	local pad = Core.padding(s, o.padding or 2)
	if not horizontal then
		pad.PaddingRight = UDim.new(0, (o.padding or 2) + 4)
	end
	local layout: UIListLayout? = nil
	if o.layout ~= false then
		local l = Core.list(s, horizontal, o.gap)
		if horizontal then
			l.VerticalAlignment = Enum.VerticalAlignment.Center
		end
		layout = l
	end
	Core.themed(s, function(t)
		s.ScrollBarImageColor3 = t.colors.textDim
		s.ScrollBarImageTransparency = 0.35
		if layout and o.gap == nil then
			layout.Padding = UDim.new(0, t.gap)
		end
	end)
	return {
		frame = s,
		content = s,
		layout = layout,
		add = makeAdder(s),
		clear = function()
			clearGuiChildren(s)
		end,
		scrollToTop = function()
			s.CanvasPosition = Vector2.new(0, 0)
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- Divider / Spacer
---------------------------------------------------------------------------------------------------
export type DividerOpts = { vertical: boolean?, color: ColorSpec?, thickness: number?, inset: number?, name: string? }

function Layout.Divider(opts: DividerOpts?): { frame: Frame }
	local o: DividerOpts = opts or {}
	local f = Instance.new("Frame")
	f.Name = o.name or "Divider"
	f.BorderSizePixel = 0
	local th = math.max(1, Core.px(o.thickness or 1))
	local inset = Core.px(o.inset or 0)
	if o.vertical then
		f.Size = UDim2.new(0, th, 1, -inset * 2)
	else
		f.Size = UDim2.new(1, -inset * 2, 0, th)
	end
	Core.themed(f, function(t)
		f.BackgroundColor3 = Core.color(t, o.color, "border")
		f.BackgroundTransparency = 0.2
	end)
	return { frame = f }
end

-- Fixed-size empty space (size in px along the parent's layout direction; both axes by default).
function Layout.Spacer(size: number?, horizontal: boolean?): { frame: Frame }
	local n = Core.px(size or 8)
	local f = Core.frame("Spacer")
	if horizontal then
		f.Size = UDim2.fromOffset(n, 1)
	else
		f.Size = UDim2.new(0, 1, 0, n)
	end
	return { frame = f }
end

---------------------------------------------------------------------------------------------------
-- Tile: square app-style button (glyph + title), used by the phone menu and quick pickers.
---------------------------------------------------------------------------------------------------
export type TileOpts = {
	glyph: string?,
	title: string?,
	onClick: (() -> ())?,
	badge: string?,
	locked: boolean?,
	color: ColorSpec?, -- glyph circle colour; default "accent"
	name: string?,
	layoutOrder: number?,
}
export type Tile = { frame: TextButton, setBadge: (text: string?) -> (), setLocked: (locked: boolean) -> () }

function Layout.Tile(opts: TileOpts?): Tile
	local o: TileOpts = opts or {}
	local locked = o.locked == true
	local b = Instance.new("TextButton")
	b.Name = o.name or "Tile"
	b.Text = ""
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(104, 112)
	b.LayoutOrder = o.layoutOrder or 0
	local list = Core.list(b, false, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.Size = UDim2.fromOffset(64, 64)
	icon.BorderSizePixel = 0
	icon.LayoutOrder = 1
	icon.Parent = b
	local iconCorner = Core.corner(icon)
	local iconStroke = Core.stroke(icon)
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Text = o.glyph or "•"
	glyph.TextScaled = false
	glyph.Parent = icon

	local badge = Text.Badge({ text = o.badge or "", color = "bad", name = "Badge" })
	badge.frame.AnchorPoint = Vector2.new(1, 0)
	badge.frame.Position = UDim2.new(1, 6, 0, -6)
	badge.frame.Visible = o.badge ~= nil and o.badge ~= ""
	badge.frame.ZIndex = 3
	badge.frame.Parent = icon

	local title = Text.Label({
		text = o.title or "",
		size = "sm",
		font = "bodyBold",
		align = "center",
		name = "Title",
		layoutOrder = 2,
	})
	title.frame.Parent = b

	local pressed = false
	local function paint(t: Core.Tokens)
		local c = Core.color(t, o.color, "accent")
		icon.BackgroundColor3 = if pressed then Core.shade(t.colors.surface, -0.15) else t.colors.surface
		icon.BackgroundTransparency = if locked then 0.5 else 0
		iconCorner.CornerRadius = UDim.new(0, t.radius + 6)
		iconStroke.Color = c
		iconStroke.Thickness = t.stroke + 1
		iconStroke.Transparency = if locked then 0.7 else 0
		glyph.FontFace = t.fonts.bodyBold
		glyph.TextSize = t.text.xxl
		glyph.TextColor3 = c
		glyph.TextTransparency = if locked then 0.6 else 0
		title.frame.TextTransparency = if locked then 0.5 else 0
	end
	Core.themed(b, paint)

	Core.connect(b, "Activated", function()
		if locked then
			Core.sound("error")
			return
		end
		Core.sound("click")
		if o.onClick then
			o.onClick()
		end
	end)
	Core.connect(b, "InputBegan", function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pressed = true
			paint(Core.Theme.get())
		end
	end)
	Core.connect(b, "InputEnded", function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pressed = false
			paint(Core.Theme.get())
		end
	end)

	return {
		frame = b,
		setBadge = function(text: string?)
			badge.setText(text or "")
			badge.frame.Visible = text ~= nil and text ~= ""
		end,
		setLocked = function(v: boolean)
			locked = v
			paint(Core.Theme.get())
		end,
	}
end

return Layout
