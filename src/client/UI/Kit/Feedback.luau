--!strict
-- Feedback and containers: Window, Confirm, Toast, ProgressBar, StatPips.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Strings = require(Shared.Config.Strings)
local Core = require(script.Parent.Core)
local Text = require(script.Parent.Text)
local Controls = require(script.Parent.Controls)

type Tokens = Core.Tokens
type ColorSpec = Core.ColorSpec

local Feedback = {}

---------------------------------------------------------------------------------------------------
-- Window: full-screen dimmed backdrop (sinks input) with a centred panel, header and content area.
-- The backdrop respects safe-area insets (Roblox top bar, notches) published by UIController.
---------------------------------------------------------------------------------------------------
export type WindowOpts = {
	title: string?,
	subtitle: string?,
	size: UDim2?, -- panel size inside the safe area (default fill)
	maxSize: Vector2?, -- panel max size (default 980 x 680)
	onClose: (() -> ())?, -- called when the player presses the close button
	closable: boolean?, -- show the close button (default true)
	backdrop: boolean?, -- dim the world behind (default true)
	padding: number?, -- content padding (default theme pad)
	accent: Color3?, -- header accent stripe (e.g. Theme.accentFor(realm))
	name: string?,
}
export type Window = {
	frame: Frame, -- full-size backdrop: parent this to the screen root
	panel: Frame,
	header: Frame,
	content: Frame,
	setTitle: (text: string) -> (),
	setSubtitle: (text: string?) -> (),
	close: () -> (),
}

local HEADER_H = 60

function Feedback.Window(opts: WindowOpts?): Window
	local o: WindowOpts = opts or {}
	local backdrop = Instance.new("Frame")
	backdrop.Name = o.name or "Window"
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundTransparency = 1
	backdrop.Active = o.backdrop ~= false
	local safe = Instance.new("UIPadding")
	safe.Parent = backdrop
	local function applyInsets()
		local i = Core.insets
		safe.PaddingTop = UDim.new(0, Core.px(i.top + 8))
		safe.PaddingBottom = UDim.new(0, Core.px(i.bottom + 8))
		safe.PaddingLeft = UDim.new(0, Core.px(i.left + 8))
		safe.PaddingRight = UDim.new(0, Core.px(i.right + 8))
	end
	applyInsets()
	local insetConn = Core.InsetsChanged:Connect(applyInsets)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Active = true
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = o.size or UDim2.fromScale(1, 1)
	panel.BorderSizePixel = 0
	panel.Parent = backdrop
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = o.maxSize or Vector2.new(980, 680)
	limit.Parent = panel
	local corner = Core.corner(panel)
	local stroke = Core.stroke(panel)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.96
	scale.Parent = panel

	local header = Core.frame("Header", UDim2.new(1, 0, 0, HEADER_H))
	header.Parent = panel
	local stripe = Instance.new("Frame")
	stripe.Name = "Accent"
	stripe.BorderSizePixel = 0
	stripe.Size = UDim2.new(1, 0, 0, 3)
	stripe.Parent = header
	local titles = Core.frame("Titles", UDim2.new(1, -(Core.TAP + 28), 1, 0))
	titles.Position = UDim2.fromOffset(16, 0)
	titles.Parent = header
	local titleList = Core.list(titles, false, 0)
	titleList.VerticalAlignment = Enum.VerticalAlignment.Center
	local title = Text.Heading({ text = o.title or "", level = 2, autoSize = "none", name = "Title", layoutOrder = 1 })
	title.frame.Size = UDim2.new(1, 0, 0, 30)
	title.frame.Parent = titles
	local subtitle = Text.Label({
		text = o.subtitle or "",
		size = "sm",
		color = "textDim",
		autoSize = "none",
		height = 18,
		name = "Subtitle",
		layoutOrder = 2,
	})
	subtitle.frame.Visible = o.subtitle ~= nil and o.subtitle ~= ""
	subtitle.frame.Parent = titles
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.BorderSizePixel = 0
	divider.AnchorPoint = Vector2.new(0, 1)
	divider.Position = UDim2.fromScale(0, 1)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Parent = header

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		insetConn:Disconnect()
		backdrop:Destroy()
	end

	if o.closable ~= false then
		local closeBtn = Controls.IconButton({
			glyph = "✕",
			style = "ghost",
			name = "Close",
			sound = "close",
			onClick = function()
				if o.onClose then
					o.onClose()
				else
					close()
				end
			end,
		})
		closeBtn.frame.AnchorPoint = Vector2.new(1, 0.5)
		closeBtn.frame.Position = UDim2.new(1, -8, 0.5, 0)
		closeBtn.frame.Parent = header
	end

	local content = Core.frame("Content", UDim2.new(1, 0, 1, -HEADER_H))
	content.Position = UDim2.fromOffset(0, HEADER_H)
	content.Parent = panel
	local pad = Core.padding(content, o.padding)

	Core.themed(panel, function(t)
		backdrop.BackgroundColor3 = t.colors.overlay
		panel.BackgroundColor3 = t.colors.panel
		corner.CornerRadius = UDim.new(0, t.radius + 2)
		stroke.Color = t.colors.border
		stroke.Thickness = t.stroke
		stripe.BackgroundColor3 = o.accent or t.colors.accent
		stripe.Visible = t.name == "street" or o.accent ~= nil
		divider.BackgroundColor3 = t.colors.border
		if o.padding == nil then
			pad.PaddingLeft = UDim.new(0, t.pad + 4)
			pad.PaddingRight = UDim.new(0, t.pad + 4)
			pad.PaddingTop = UDim.new(0, t.pad)
			pad.PaddingBottom = UDim.new(0, t.pad + 4)
		end
	end)
	Core.onDestroy(backdrop, function()
		if not closed then
			closed = true
			insetConn:Disconnect()
		end
	end)

	if o.backdrop ~= false then
		Core.tween(backdrop, 0.18, { BackgroundTransparency = 0.35 })
	end
	Core.tween(scale, 0.18, { Scale = 1 })

	return {
		frame = backdrop,
		panel = panel,
		header = header,
		content = content,
		setTitle = function(s: string)
			title.frame.Text = s
		end,
		setSubtitle = function(s: string?)
			subtitle.frame.Text = s or ""
			subtitle.frame.Visible = s ~= nil and s ~= ""
		end,
		close = close,
	}
end

---------------------------------------------------------------------------------------------------
-- Confirm: modal with title, body and two buttons. callback(true) on confirm, callback(false) on
-- cancel, tap outside or Back. Called exactly once.
---------------------------------------------------------------------------------------------------
export type ConfirmOpts = {
	title: string?,
	body: string?,
	confirmText: string?,
	cancelText: string?,
	danger: boolean?,
	dismissable: boolean?, -- default true
	parent: Instance?, -- default: UIController modal layer
}
export type Confirm = { frame: Frame, close: (result: boolean?) -> () }

function Feedback.Confirm(opts: ConfirmOpts?, callback: ((confirmed: boolean) -> ())?): Confirm
	local o: ConfirmOpts = opts or {}
	local answered = false
	local function answer(v: boolean)
		if answered then
			return
		end
		answered = true
		if callback then
			task.spawn(callback, v)
		end
	end
	local modal = Core.openModal({
		width = 440,
		dismissable = o.dismissable,
		parent = o.parent,
		name = "Confirm",
		onDismiss = function()
			answer(false)
		end,
	}, function(card, close)
		Core.list(card, false, 12)
		local heading = Text.Heading({ text = o.title or Strings.get("confirm"), level = 3, layoutOrder = 1 })
		heading.frame.Parent = card
		if o.body and o.body ~= "" then
			local body = Text.Label({ text = o.body, size = "md", color = "textDim", layoutOrder = 2 })
			body.frame.Parent = card
		end
		local row = Core.frame("Buttons", UDim2.new(1, 0, 0, Core.TAP))
		row.LayoutOrder = 3
		row.Parent = card
		local rowList = Core.list(row, true, 8)
		rowList.HorizontalAlignment = Enum.HorizontalAlignment.Right
		rowList.VerticalAlignment = Enum.VerticalAlignment.Center
		local cancel = Controls.Button({
			text = o.cancelText or Strings.get("cancel"),
			style = "secondary",
			layoutOrder = 1,
			name = "Cancel",
			sound = "close",
			onClick = function()
				close()
				answer(false)
			end,
		})
		cancel.frame.Parent = row
		local confirm = Controls.Button({
			text = o.confirmText or Strings.get("confirm"),
			style = if o.danger then "danger" else "primary",
			layoutOrder = 2,
			name = "Confirm",
			onClick = function()
				close()
				answer(true)
			end,
		})
		confirm.frame.Parent = row
	end)
	return {
		frame = modal.frame,
		close = function(result: boolean?)
			modal.close()
			answer(result == true)
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- Toast: one notification card (the HUD stacks and times them).
---------------------------------------------------------------------------------------------------
export type ToastOpts = { text: string?, kind: string?, count: number?, onClick: (() -> ())?, name: string? }
export type Toast = {
	frame: Frame, -- layout-managed outer frame
	inner: TextButton, -- slides in/out
	setText: (text: string) -> (),
	setCount: (count: number) -> (),
}

function Feedback.Toast(opts: ToastOpts?): Toast
	local o: ToastOpts = opts or {}
	local kindDef = Core.kinds[o.kind or "info"] or Core.kinds.info
	local outer = Core.frame(o.name or "Toast", UDim2.new(1, 0, 0, 0))
	outer.AutomaticSize = Enum.AutomaticSize.Y

	local inner = Instance.new("TextButton")
	inner.Name = "Inner"
	inner.Text = ""
	inner.AutoButtonColor = false
	inner.BorderSizePixel = 0
	inner.Size = UDim2.new(1, 0, 0, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	inner.Parent = outer
	local corner = Core.corner(inner)
	local stroke = Core.stroke(inner)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = inner

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BorderSizePixel = 0
	-- Stays inside the padded content box: a child that overhangs an AutomaticSize parent makes it grow.
	strip.Position = UDim2.fromOffset(-10, 0)
	strip.Size = UDim2.new(0, 3, 1, 0)
	strip.Parent = inner

	local row = Core.frame("Row", UDim2.new(1, 0, 0, 0))
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Parent = inner
	local rowList = Core.list(row, true, 10)
	rowList.VerticalAlignment = Enum.VerticalAlignment.Center

	local glyphBox = Instance.new("Frame")
	glyphBox.Name = "Glyph"
	glyphBox.Size = UDim2.fromOffset(28, 28)
	glyphBox.BorderSizePixel = 0
	glyphBox.LayoutOrder = 1
	glyphBox.Parent = row
	Core.corner(glyphBox, 999)
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Text"
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Text = kindDef.glyph
	glyph.Parent = glyphBox

	local label = Text.Label({
		text = o.text or "",
		size = "md",
		font = "bodyBold",
		width = UDim.new(1, -86),
		name = "Message",
		layoutOrder = 2,
	})
	label.frame.Parent = row

	local count = Text.Badge({ text = "", color = kindDef.color, name = "Count", layoutOrder = 3 })
	count.frame.Visible = false
	count.frame.Parent = row

	Core.themed(inner, function(t)
		local c = Core.color(t, kindDef.color)
		inner.BackgroundColor3 = t.colors.panel
		inner.BackgroundTransparency = 0.02
		corner.CornerRadius = UDim.new(0, t.radius)
		stroke.Color = c
		stroke.Thickness = t.stroke
		stroke.Transparency = 0.35
		strip.BackgroundColor3 = c
		glyphBox.BackgroundColor3 = c
		glyph.FontFace = t.fonts.bodyBold
		glyph.TextSize = t.text.md
		glyph.TextColor3 = Core.Theme.contrastText(c)
	end)

	local function setCount(n: number)
		if n > 1 then
			count.setText(Strings.format("count_suffix", { count = n }))
			count.frame.Visible = true
		else
			count.frame.Visible = false
		end
	end
	setCount(o.count or 1)
	if o.onClick then
		Core.connect(inner, "Activated", o.onClick)
	end

	return {
		frame = outer,
		inner = inner,
		setText = label.setText,
		setCount = setCount,
	}
end

---------------------------------------------------------------------------------------------------
-- ProgressBar
---------------------------------------------------------------------------------------------------
export type ProgressBarOpts = {
	value: number?, -- 0..1
	color: ColorSpec?, -- fill colour (default "accent")
	height: number?, -- px (default 10)
	label: string?, -- text drawn over the bar (needs height >= 16)
	width: UDim?, -- default full width
	name: string?,
	layoutOrder: number?,
}
export type ProgressBar = {
	frame: Frame,
	set: (value: number, instant: boolean?) -> (),
	get: () -> number,
	setColor: (color: ColorSpec) -> (),
	setLabel: (text: string?) -> (),
}

function Feedback.ProgressBar(opts: ProgressBarOpts?): ProgressBar
	local o: ProgressBarOpts = opts or {}
	local value = math.clamp(o.value or 0, 0, 1)
	local color: ColorSpec = o.color or "accent"
	local h = Core.px(o.height or 10)
	local w = o.width or UDim.new(1, 0)
	local track = Instance.new("Frame")
	track.Name = o.name or "ProgressBar"
	track.BorderSizePixel = 0
	track.Size = UDim2.new(w.Scale, w.Offset, 0, h)
	track.LayoutOrder = o.layoutOrder or 0
	track.ClipsDescendants = true
	local trackCorner = Core.corner(track, math.floor(h / 2))
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(value, 1)
	fill.Parent = track
	local fillCorner = Core.corner(fill, math.floor(h / 2))
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = o.label or ""
	label.Visible = o.label ~= nil
	label.ZIndex = 2
	label.Parent = track
	Core.themed(track, function(t)
		track.BackgroundColor3 = t.colors.surface
		fill.BackgroundColor3 = Core.color(t, color, "accent")
		trackCorner.CornerRadius = UDim.new(0, math.min(math.floor(h / 2), t.radius))
		fillCorner.CornerRadius = trackCorner.CornerRadius
		label.FontFace = t.fonts.bodyBold
		label.TextSize = math.max(10, math.min(t.text.sm, h - 2))
		label.TextColor3 = t.colors.text
		label.TextStrokeTransparency = 0.6
	end)
	return {
		frame = track,
		set = function(v: number, instant: boolean?)
			value = math.clamp(if v == v then v else 0, 0, 1)
			local target = UDim2.fromScale(value, 1)
			if instant then
				fill.Size = target
			else
				Core.tween(fill, 0.25, { Size = target })
			end
		end,
		get = function()
			return value
		end,
		setColor = function(c: ColorSpec)
			color = c
			fill.BackgroundColor3 = Core.color(Core.Theme.get(), c, "accent")
		end,
		setLabel = function(s: string?)
			label.Text = s or ""
			label.Visible = s ~= nil
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- StatPips: 1..10 rating as a row of small blocks.
---------------------------------------------------------------------------------------------------
export type StatPipsOpts = {
	value: number?,
	max: number?, -- default 10
	color: ColorSpec?, -- default "accent"
	size: number?, -- pip size px (default 10)
	name: string?,
	layoutOrder: number?,
}
export type StatPips = { frame: Frame, set: (value: number) -> (), get: () -> number }

function Feedback.StatPips(opts: StatPipsOpts?): StatPips
	local o: StatPipsOpts = opts or {}
	local max = math.clamp(math.floor(o.max or 10), 1, 20)
	local value = math.clamp(math.floor((o.value or 0) + 0.5), 0, max)
	local size = Core.px(o.size or 10)
	local row = Core.frame(o.name or "StatPips", UDim2.fromOffset(0, size))
	row.AutomaticSize = Enum.AutomaticSize.X
	row.LayoutOrder = o.layoutOrder or 0
	Core.list(row, true, 3)
	local pips: { Frame } = {}
	for i = 1, max do
		local p = Instance.new("Frame")
		p.Name = "Pip" .. i
		p.BorderSizePixel = 0
		p.Size = UDim2.fromOffset(size, size)
		p.LayoutOrder = i
		p.Parent = row
		Core.corner(p, 2)
		pips[i] = p
	end
	local function paint(t: Tokens)
		local on = Core.color(t, o.color, "accent")
		for i, p in pips do
			p.BackgroundColor3 = if i <= value then on else t.colors.surface
			p.BackgroundTransparency = if i <= value then 0 else 0.2
		end
	end
	Core.themed(row, paint)
	return {
		frame = row,
		set = function(v: number)
			value = math.clamp(math.floor(v + 0.5), 0, max)
			paint(Core.Theme.get())
		end,
		get = function()
			return value
		end,
	}
end

return Feedback
