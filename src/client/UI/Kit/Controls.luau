--!strict
-- Tappable controls: Button, IconButton, Toggle, Tabs.
-- Every tap target is at least Core.TAP (44 px) tall; presses give colour feedback on mouse, touch and
-- gamepad; nothing depends on hover.

local Core = require(script.Parent.Core)
local Text = require(script.Parent.Text)

type Tokens = Core.Tokens

local Controls = {}

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
Controls.isPress = isPress

-- Wires hover/press state on a GuiButton; repaint() is called on every change.
local function wireFeedback(b: GuiButton, state: { hover: boolean, pressed: boolean }, repaint: () -> ())
	Core.connect(b, "MouseEnter", function()
		state.hover = true
		repaint()
	end)
	Core.connect(b, "MouseLeave", function()
		state.hover = false
		state.pressed = false
		repaint()
	end)
	Core.connect(b, "InputBegan", function(input: InputObject)
		if isPress(input) or input.KeyCode == Enum.KeyCode.ButtonA then
			state.pressed = true
			repaint()
		end
	end)
	Core.connect(b, "InputEnded", function(input: InputObject)
		if isPress(input) or input.KeyCode == Enum.KeyCode.ButtonA then
			state.pressed = false
			repaint()
		end
	end)
	Core.connect(b, "SelectionGained", function()
		state.hover = true
		repaint()
	end)
	Core.connect(b, "SelectionLost", function()
		state.hover = false
		state.pressed = false
		repaint()
	end)
end
Controls.wireFeedback = wireFeedback

---------------------------------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------------------------------
export type ButtonStyle = "primary" | "secondary" | "ghost" | "danger"
export type ButtonOpts = {
	text: string?,
	style: ButtonStyle?, -- default "primary"
	onClick: (() -> ())?,
	size: UDim2?, -- default: automatic width, 44 px tall
	fill: boolean?, -- full width (ignored when size is given)
	icon: string?, -- text glyph shown before the label
	disabled: boolean?,
	textSize: (string | number)?, -- default "md"
	sound: string?, -- Sfx cue on click (default "click")
	name: string?,
	layoutOrder: number?,
}
export type Button = {
	frame: TextButton,
	label: TextLabel,
	setText: (text: string) -> (),
	setIcon: (glyph: string?) -> (),
	setStyle: (style: ButtonStyle) -> (),
	setDisabled: (disabled: boolean) -> (),
	isDisabled: () -> boolean,
}

local DEBOUNCE = 0.2

local function styleColors(t: Tokens, style: string): (Color3, Color3, number, boolean)
	-- returns background, foreground, background transparency, show stroke
	local c = t.colors
	if style == "secondary" then
		return c.surface, c.text, 0, true
	elseif style == "ghost" then
		return c.surface, c.accent, 1, false
	elseif style == "danger" then
		return c.bad, Color3.fromRGB(255, 255, 255), 0, false
	end
	return c.accent, c.accentText, 0, false
end

local function buildButton(opts: ButtonOpts, square: number?): Button
	local style: string = opts.style or "primary"
	local disabled = opts.disabled == true
	local state = { hover = false, pressed = false }
	local lastClick = -math.huge

	local b = Instance.new("TextButton")
	b.Name = opts.name or "Button"
	b.Text = ""
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.LayoutOrder = opts.layoutOrder or 0
	b.ClipsDescendants = false
	if square then
		b.Size = UDim2.fromOffset(square, square)
	elseif opts.size then
		b.Size = opts.size
	elseif opts.fill then
		b.Size = UDim2.new(1, 0, 0, Core.TAP)
	else
		b.Size = UDim2.fromOffset(0, Core.TAP)
		b.AutomaticSize = Enum.AutomaticSize.X
	end
	local minSize = Instance.new("UISizeConstraint")
	minSize.MinSize = Vector2.new(Core.TAP, Core.TAP)
	minSize.Parent = b

	local corner = Core.corner(b)
	local stroke = Core.stroke(b)
	if not square then
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 16)
		pad.PaddingRight = UDim.new(0, 16)
		pad.Parent = b
	end
	local row = Core.list(b, true, 6)
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AutomaticSize = Enum.AutomaticSize.XY
	icon.Size = UDim2.fromOffset(0, 0)
	icon.Text = opts.icon or ""
	icon.Visible = opts.icon ~= nil and opts.icon ~= ""
	icon.LayoutOrder = 1
	icon.Parent = b

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.Text = opts.text or ""
	label.Visible = label.Text ~= ""
	label.LayoutOrder = 2
	label.Parent = b

	local function paint(t: Tokens)
		local bg, fg, bgT, showStroke = styleColors(t, style)
		local shade = if state.pressed then -0.18 elseif state.hover then 0.1 else 0
		b.BackgroundColor3 = Core.shade(bg, shade)
		if style == "ghost" then
			b.BackgroundTransparency = if state.pressed then 0.55 elseif state.hover then 0.8 else bgT
		else
			b.BackgroundTransparency = if disabled then 0.5 else bgT
		end
		corner.CornerRadius = UDim.new(0, t.radius)
		stroke.Color = if state.hover and not disabled then t.colors.accent else t.colors.border
		stroke.Thickness = t.stroke
		stroke.Transparency = if showStroke then (if disabled then 0.6 else 0) else 1
		local textT = if disabled then 0.5 else 0
		label.FontFace = t.fonts.bodyBold
		label.TextSize = Core.textSize(t, opts.textSize, "md")
		label.TextColor3 = fg
		label.TextTransparency = textT
		icon.FontFace = t.fonts.bodyBold
		icon.TextSize = if square then t.text.xl else Core.textSize(t, opts.textSize, "md") + 2
		icon.TextColor3 = fg
		icon.TextTransparency = textT
	end
	local function repaint()
		paint(Core.Theme.get())
	end
	Core.themed(b, paint)
	wireFeedback(b, state, repaint)

	Core.connect(b, "Activated", function()
		if disabled then
			Core.sound("error")
			return
		end
		local now = os.clock()
		if now - lastClick < DEBOUNCE then
			return
		end
		lastClick = now
		Core.sound(opts.sound or "click")
		if opts.onClick then
			opts.onClick()
		end
	end)

	local function setDisabled(v: boolean)
		disabled = v
		b.Active = not v
		b.Selectable = not v
		if v then
			state.pressed = false
		end
		repaint()
	end
	if disabled then
		setDisabled(true)
	end

	return {
		frame = b,
		label = label,
		setText = function(s: string)
			label.Text = s
			label.Visible = s ~= ""
		end,
		setIcon = function(glyph: string?)
			icon.Text = glyph or ""
			icon.Visible = glyph ~= nil and glyph ~= ""
		end,
		setStyle = function(s: ButtonStyle)
			style = s
			repaint()
		end,
		setDisabled = setDisabled,
		isDisabled = function()
			return disabled
		end,
	}
end

function Controls.Button(opts: ButtonOpts?): Button
	return buildButton(opts or {}, nil)
end

---------------------------------------------------------------------------------------------------
-- IconButton: square glyph button (min 44 px).
---------------------------------------------------------------------------------------------------
export type IconButtonOpts = {
	glyph: string?,
	onClick: (() -> ())?,
	size: number?, -- px, default 44 (never smaller)
	style: ButtonStyle?, -- default "secondary"
	disabled: boolean?,
	sound: string?,
	name: string?,
	layoutOrder: number?,
}
export type IconButton = {
	frame: TextButton,
	setGlyph: (glyph: string) -> (),
	setStyle: (style: ButtonStyle) -> (),
	setDisabled: (disabled: boolean) -> (),
}

function Controls.IconButton(opts: IconButtonOpts?): IconButton
	local o: IconButtonOpts = opts or {}
	local btn = buildButton({
		icon = o.glyph or "•",
		style = o.style or "secondary",
		onClick = o.onClick,
		disabled = o.disabled,
		sound = o.sound,
		name = o.name or "IconButton",
		layoutOrder = o.layoutOrder,
	}, math.max(Core.TAP, o.size or Core.TAP))
	return {
		frame = btn.frame,
		setGlyph = function(g: string)
			btn.setIcon(g)
		end,
		setStyle = btn.setStyle,
		setDisabled = btn.setDisabled,
	}
end

---------------------------------------------------------------------------------------------------
-- Toggle: switch with an optional label and hint; the whole row is the tap target.
---------------------------------------------------------------------------------------------------
export type ToggleOpts = {
	value: boolean?,
	onChange: ((value: boolean) -> ())?,
	label: string?,
	hint: string?,
	disabled: boolean?,
	name: string?,
	layoutOrder: number?,
}
export type Toggle = {
	frame: TextButton,
	set: (value: boolean, silent: boolean?) -> (),
	get: () -> boolean,
	setDisabled: (disabled: boolean) -> (),
}

local TRACK_W, TRACK_H, KNOB = 52, 28, 22

function Controls.Toggle(opts: ToggleOpts?): Toggle
	local o: ToggleOpts = opts or {}
	local value = o.value == true
	local disabled = o.disabled == true
	local state = { hover = false, pressed = false }

	local b = Instance.new("TextButton")
	b.Name = o.name or "Toggle"
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.LayoutOrder = o.layoutOrder or 0
	local hasText = o.label ~= nil or o.hint ~= nil
	if hasText then
		b.Size = UDim2.new(1, 0, 0, Core.TAP)
		b.AutomaticSize = Enum.AutomaticSize.Y
	else
		b.Size = UDim2.fromOffset(TRACK_W + 8, Core.TAP)
	end
	local minSize = Instance.new("UISizeConstraint")
	minSize.MinSize = Vector2.new(Core.TAP, Core.TAP)
	minSize.Parent = b

	if hasText then
		-- Top-anchored (no scale position on the automatic axis, so AutomaticSize can't feed back) with a
		-- 44 px minimum and centred contents.
		local texts = Core.frame("Texts", UDim2.new(1, -(TRACK_W + 16), 0, 0))
		texts.AutomaticSize = Enum.AutomaticSize.Y
		local textsMin = Instance.new("UISizeConstraint")
		textsMin.MinSize = Vector2.new(0, Core.TAP)
		textsMin.Parent = texts
		local textsList = Core.list(texts, false, 2)
		textsList.VerticalAlignment = Enum.VerticalAlignment.Center
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.Parent = texts
		texts.Parent = b
		if o.label then
			local l = Text.Label({ text = o.label, size = "md", font = "bodyBold", name = "Label", layoutOrder = 1 })
			l.frame.Parent = texts
		end
		if o.hint then
			local h = Text.Label({ text = o.hint, size = "sm", color = "textDim", name = "Hint", layoutOrder = 2 })
			h.frame.Parent = texts
		end
	end

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.fromOffset(TRACK_W, TRACK_H)
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, 0, 0.5, 0)
	track.BorderSizePixel = 0
	track.Parent = b
	Core.corner(track, 999)
	local trackStroke = Core.stroke(track)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(KNOB, KNOB)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.BorderSizePixel = 0
	knob.Parent = track
	Core.corner(knob, 999)

	local function knobPos(): UDim2
		local inset = (TRACK_H - KNOB) / 2
		return if value then UDim2.new(1, -(KNOB + inset), 0.5, 0) else UDim2.new(0, inset, 0.5, 0)
	end
	knob.Position = knobPos()

	local function paint(t: Tokens)
		track.BackgroundColor3 = if value then t.colors.accent else t.colors.surface
		track.BackgroundTransparency = if disabled then 0.5 else 0
		trackStroke.Color = if state.hover then t.colors.accent else t.colors.border
		trackStroke.Thickness = t.stroke
		knob.BackgroundColor3 = if value then t.colors.accentText else t.colors.textDim
		if state.pressed then
			knob.BackgroundColor3 = Core.shade(knob.BackgroundColor3, 0.2)
		end
	end
	local function repaint()
		paint(Core.Theme.get())
	end
	Core.themed(b, paint)
	wireFeedback(b, state, repaint)

	local function set(v: boolean, silent: boolean?)
		local changed = v ~= value
		value = v
		Core.tween(knob, 0.12, { Position = knobPos() })
		repaint()
		if changed and not silent and o.onChange then
			o.onChange(value)
		end
	end

	Core.connect(b, "Activated", function()
		if disabled then
			Core.sound("error")
			return
		end
		Core.sound("click")
		set(not value)
	end)

	return {
		frame = b,
		set = set,
		get = function()
			return value
		end,
		setDisabled = function(v: boolean)
			disabled = v
			b.Active = not v
			repaint()
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- Tabs: horizontal, scrollable tab strip.
---------------------------------------------------------------------------------------------------
export type TabDef = { id: string, title: string, badge: string? }
export type TabsOpts = {
	tabs: { TabDef }?,
	onSelect: ((id: string) -> ())?,
	selected: string?, -- default: first tab
	name: string?,
	layoutOrder: number?,
}
export type Tabs = {
	frame: ScrollingFrame,
	select: (id: string, silent: boolean?) -> (),
	getSelected: () -> string?,
	setTabs: (tabs: { TabDef }) -> (),
	setBadge: (id: string, text: string?) -> (),
}

function Controls.Tabs(opts: TabsOpts?): Tabs
	local o: TabsOpts = opts or {}
	local selected: string? = o.selected
	local s = Instance.new("ScrollingFrame")
	s.Name = o.name or "Tabs"
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = UDim2.new(1, 0, 0, Core.TAP + 4)
	s.LayoutOrder = o.layoutOrder or 0
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.X
	s.ScrollingDirection = Enum.ScrollingDirection.X
	s.ScrollBarThickness = 0
	s.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	s.Selectable = false
	local row = Core.list(s, true, 4)
	row.VerticalAlignment = Enum.VerticalAlignment.Top

	type TabEntry = {
		def: TabDef,
		button: TextButton,
		label: TextLabel,
		underline: Frame,
		badge: Text.Badge,
		state: { hover: boolean, pressed: boolean },
	}
	local entries: { TabEntry } = {}

	local function paintEntry(e: TabEntry, t: Tokens)
		local on = e.def.id == selected
		e.button.BackgroundColor3 = t.colors.surface
		e.button.BackgroundTransparency = if e.state.pressed then 0.5 elseif e.state.hover or on then 0.8 else 1
		e.label.FontFace = if on then t.fonts.bodyBold else t.fonts.body
		e.label.TextSize = t.text.md
		e.label.TextColor3 = if on then t.colors.accent else t.colors.textDim
		e.underline.BackgroundColor3 = t.colors.accent
		e.underline.Visible = on
	end
	local function paintAll(t: Tokens)
		for _, e in entries do
			paintEntry(e, t)
		end
	end

	local function select(id: string, silent: boolean?)
		local changed = id ~= selected
		selected = id
		paintAll(Core.Theme.get())
		if changed and not silent and o.onSelect then
			o.onSelect(id)
		end
	end

	local function setTabs(tabs: { TabDef })
		for _, e in entries do
			e.button:Destroy()
		end
		table.clear(entries)
		local found = false
		for i, def in tabs do
			local b = Instance.new("TextButton")
			b.Name = "Tab_" .. def.id
			b.Text = ""
			b.AutoButtonColor = false
			b.BorderSizePixel = 0
			b.Size = UDim2.fromOffset(0, Core.TAP)
			b.AutomaticSize = Enum.AutomaticSize.X
			b.LayoutOrder = i
			Core.corner(b, 6)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 14)
			pad.PaddingRight = UDim.new(0, 14)
			pad.Parent = b
			local content = Core.frame("Content", UDim2.new(0, 0, 1, 0))
			content.AutomaticSize = Enum.AutomaticSize.X
			content.Parent = b
			local inner = Core.list(content, true, 6)
			inner.VerticalAlignment = Enum.VerticalAlignment.Center
			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.BackgroundTransparency = 1
			label.AutomaticSize = Enum.AutomaticSize.XY
			label.Size = UDim2.fromOffset(0, 0)
			label.Text = def.title
			label.LayoutOrder = 1
			label.Parent = content
			local badge = Text.Badge({ text = def.badge or "", color = "bad", name = "Badge", layoutOrder = 2 })
			badge.frame.Visible = def.badge ~= nil and def.badge ~= ""
			badge.frame.Parent = content
			local underline = Instance.new("Frame")
			underline.Name = "Underline"
			underline.BorderSizePixel = 0
			underline.AnchorPoint = Vector2.new(0.5, 1)
			underline.Position = UDim2.fromScale(0.5, 1)
			underline.Size = UDim2.new(1, 0, 0, 3)
			underline.Parent = b
			local entry: TabEntry = {
				def = def,
				button = b,
				label = label,
				underline = underline,
				badge = badge,
				state = { hover = false, pressed = false },
			}
			table.insert(entries, entry)
			wireFeedback(b, entry.state, function()
				paintEntry(entry, Core.Theme.get())
			end)
			Core.connect(b, "Activated", function()
				Core.sound("click")
				select(def.id)
			end)
			b.Parent = s
			if def.id == selected then
				found = true
			end
		end
		if not found then
			selected = if tabs[1] then tabs[1].id else nil
		end
		paintAll(Core.Theme.get())
	end

	setTabs(o.tabs or {})
	Core.themed(s, paintAll)

	return {
		frame = s,
		select = select,
		getSelected = function()
			return selected
		end,
		setTabs = setTabs,
		setBadge = function(id: string, text: string?)
			for _, e in entries do
				if e.def.id == id then
					e.badge.setText(text or "")
					e.badge.frame.Visible = text ~= nil and text ~= ""
				end
			end
		end,
	}
end

return Controls
