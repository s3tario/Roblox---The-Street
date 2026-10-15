--!strict
-- Numeric inputs: Slider, NumberInput.

local Core = require(script.Parent.Core)
local KitMath = require(script.Parent.Math)
local Text = require(script.Parent.Text)
local Controls = require(script.Parent.Controls)

type Tokens = Core.Tokens

local Inputs = {}

local function getUIS(): UserInputService?
	local ok, uis = pcall(function()
		return game:GetService("UserInputService")
	end)
	return if ok then uis else nil
end

---------------------------------------------------------------------------------------------------
-- Slider
---------------------------------------------------------------------------------------------------
export type SliderOpts = {
	min: number?, -- default 0
	max: number?, -- default 1
	step: number?, -- default (max - min) / 100
	value: number?,
	onChange: ((value: number) -> ())?, -- while dragging (live preview)
	onCommit: ((value: number) -> ())?, -- on release, tap or +/- nudge
	label: string?,
	format: ((value: number) -> string)?, -- value text (default: percent for 0..1, else 2 decimals)
	buttons: boolean?, -- show -/+ nudge buttons (default true)
	nudge: number?, -- nudge amount (default 5 steps or a tenth of the range)
	disabled: boolean?,
	name: string?,
	layoutOrder: number?,
}
export type Slider = {
	frame: Frame,
	set: (value: number, silent: boolean?) -> (),
	get: () -> number,
	setDisabled: (disabled: boolean) -> (),
}

local KNOB = 22

function Inputs.Slider(opts: SliderOpts?): Slider
	local o: SliderOpts = opts or {}
	local lo = o.min or 0
	local hi = o.max or 1
	if hi < lo then
		lo, hi = hi, lo
	end
	local step = o.step or ((hi - lo) / 100)
	local nudge = o.nudge or math.max(step * 5, (hi - lo) / 10)
	local value = KitMath.snap(o.value or lo, lo, hi, step)
	local disabled = o.disabled == true
	local function fmt(v: number): string
		if o.format then
			return o.format(v)
		end
		if lo >= 0 and hi <= 1 then
			return string.format("%d%%", math.floor(v * 100 + 0.5))
		end
		return string.format("%.2f", v)
	end

	local root = Core.frame(o.name or "Slider", UDim2.new(1, 0, 0, 0))
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.LayoutOrder = o.layoutOrder or 0
	Core.list(root, false, 2)

	local header = Core.frame("Header", UDim2.new(1, 0, 0, 22))
	header.LayoutOrder = 1
	header.Visible = o.label ~= nil
	header.Parent = root
	local title = Text.Label({ text = o.label or "", size = "md", font = "bodyBold", autoSize = "none", height = 22 })
	title.frame.Size = UDim2.new(1, -80, 1, 0)
	title.frame.Parent = header
	local valueText = Text.Label({
		text = fmt(value),
		size = "md",
		font = "mono",
		color = "textDim",
		align = "right",
		autoSize = "none",
		height = 22,
	})
	valueText.frame.Name = "Value"
	valueText.frame.AnchorPoint = Vector2.new(1, 0)
	valueText.frame.Position = UDim2.fromScale(1, 0)
	valueText.frame.Size = UDim2.new(0, 80, 1, 0)
	valueText.frame.Parent = header

	local row = Core.frame("Row", UDim2.new(1, 0, 0, Core.TAP))
	row.LayoutOrder = 2
	row.Parent = root
	local showButtons = o.buttons ~= false
	local side = if showButtons then Core.TAP + 6 else 0

	local hit = Instance.new("TextButton")
	hit.Name = "Track"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.BorderSizePixel = 0
	hit.Position = UDim2.fromOffset(side, 0)
	hit.Size = UDim2.new(1, -side * 2, 1, 0)
	hit.Parent = row

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.fromScale(0, 0.5)
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.Parent = hit
	Core.corner(bar, 999)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(KitMath.fraction(value, lo, hi), 1)
	fill.Parent = bar
	Core.corner(fill, 999)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(KNOB, KNOB)
	knob.Position = UDim2.fromScale(KitMath.fraction(value, lo, hi), 0.5)
	knob.ZIndex = 2
	knob.Parent = hit
	Core.corner(knob, 999)
	local knobStroke = Core.stroke(knob, 2)

	local dragging = false
	local function paint(t: Tokens)
		bar.BackgroundColor3 = t.colors.surface
		fill.BackgroundColor3 = t.colors.accent
		knob.BackgroundColor3 = if dragging then Core.shade(t.colors.accent, 0.25) else t.colors.accent
		knobStroke.Color = t.colors.panel
		local a = if disabled then 0.5 else 0
		bar.BackgroundTransparency = a
		fill.BackgroundTransparency = a
		knob.BackgroundTransparency = a
	end
	Core.themed(root, paint)

	local function render()
		local f = KitMath.fraction(value, lo, hi)
		fill.Size = UDim2.fromScale(f, 1)
		knob.Position = UDim2.fromScale(f, 0.5)
		valueText.frame.Text = fmt(value)
	end

	local function set(v: number, silent: boolean?)
		local nv = KitMath.snap(v, lo, hi, step)
		local changed = nv ~= value
		value = nv
		render()
		if changed and not silent and o.onChange then
			o.onChange(value)
		end
	end
	local function commit()
		if o.onCommit then
			o.onCommit(value)
		end
	end

	if showButtons then
		local minus = Controls.IconButton({
			glyph = "−",
			style = "secondary",
			name = "Minus",
			onClick = function()
				if disabled then
					return
				end
				set(value - nudge)
				commit()
			end,
		})
		minus.frame.Parent = row
		local plus = Controls.IconButton({
			glyph = "+",
			style = "secondary",
			name = "Plus",
			onClick = function()
				if disabled then
					return
				end
				set(value + nudge)
				commit()
			end,
		})
		plus.frame.AnchorPoint = Vector2.new(1, 0)
		plus.frame.Position = UDim2.fromScale(1, 0)
		plus.frame.Parent = row
	end

	local moveConn: RBXScriptConnection? = nil
	local endConn: RBXScriptConnection? = nil
	local function setFromX(x: number)
		local w = hit.AbsoluteSize.X
		if w <= 0 then
			return
		end
		local f = math.clamp((x - hit.AbsolutePosition.X) / w, 0, 1)
		set(lo + f * (hi - lo))
	end
	local function stopDrag()
		if moveConn then
			moveConn:Disconnect()
			moveConn = nil
		end
		if endConn then
			endConn:Disconnect()
			endConn = nil
		end
		if dragging then
			dragging = false
			paint(Core.Theme.get())
			commit()
		end
	end
	Core.connect(hit, "InputBegan", function(input: InputObject)
		if disabled or dragging or not Controls.isPress(input) then
			return
		end
		local uis = getUIS()
		dragging = true
		paint(Core.Theme.get())
		setFromX(input.Position.X)
		if uis then
			moveConn = uis.InputChanged:Connect(function(i: InputObject)
				if
					i.UserInputType == Enum.UserInputType.MouseMovement
					or (i.UserInputType == Enum.UserInputType.Touch and i == input)
				then
					setFromX(i.Position.X)
				end
			end)
			endConn = uis.InputEnded:Connect(function(i: InputObject)
				if i == input or i.UserInputType == Enum.UserInputType.MouseButton1 then
					stopDrag()
				end
			end)
		else
			stopDrag()
		end
	end)
	Core.onDestroy(root, function()
		if moveConn then
			moveConn:Disconnect()
		end
		if endConn then
			endConn:Disconnect()
		end
	end)

	return {
		frame = root,
		set = set,
		get = function()
			return value
		end,
		setDisabled = function(v: boolean)
			disabled = v
			if v then
				stopDrag()
			end
			paint(Core.Theme.get())
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- NumberInput: [-] [ value ] [+]
---------------------------------------------------------------------------------------------------
export type NumberInputOpts = {
	value: number?,
	min: number?,
	max: number?,
	step: number?, -- default 1
	onChange: ((value: number) -> ())?,
	format: ((value: number) -> string)?, -- display text (default: up to `decimals` decimals)
	decimals: number?, -- default 0
	width: number?, -- total width px (default 200)
	disabled: boolean?,
	name: string?,
	layoutOrder: number?,
}
export type NumberInput = {
	frame: Frame,
	box: TextBox,
	set: (value: number, silent: boolean?) -> (),
	get: () -> number,
	setDisabled: (disabled: boolean) -> (),
}

function Inputs.NumberInput(opts: NumberInputOpts?): NumberInput
	local o: NumberInputOpts = opts or {}
	local lo = o.min or -math.huge
	local hi = o.max or math.huge
	local step = o.step or 1
	local decimals = o.decimals or 0
	local disabled = o.disabled == true
	local function clampSnap(v: number): number
		local x = v
		if x < lo then
			x = lo
		end
		if x > hi then
			x = hi
		end
		if step > 0 then
			local base = if lo > -math.huge then lo else 0
			x = base + math.floor((x - base) / step + 0.5) * step
			if x < lo then
				x += step
			end
			if x > hi then
				x -= step
			end
		end
		local m = 10 ^ decimals
		return math.floor(x * m + 0.5) / m
	end
	local value = clampSnap(o.value or (if lo > -math.huge then lo else 0))
	local function fmt(v: number): string
		if o.format then
			return o.format(v)
		end
		return string.format("%." .. decimals .. "f", v)
	end

	local root = Core.frame(o.name or "NumberInput", UDim2.fromOffset(o.width or 200, Core.TAP))
	root.LayoutOrder = o.layoutOrder or 0

	local boxFrame = Instance.new("Frame")
	boxFrame.Name = "Field"
	boxFrame.BorderSizePixel = 0
	boxFrame.Position = UDim2.fromOffset(Core.TAP + 4, 0)
	boxFrame.Size = UDim2.new(1, -(Core.TAP + 4) * 2, 1, 0)
	boxFrame.Parent = root
	local corner = Core.corner(boxFrame)
	local stroke = Core.stroke(boxFrame)
	local box = Instance.new("TextBox")
	box.Name = "Box"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.ClearTextOnFocus = false
	box.Text = fmt(value)
	box.TextXAlignment = Enum.TextXAlignment.Center
	box.Parent = boxFrame
	local focused = false
	Core.themed(boxFrame, function(t)
		boxFrame.BackgroundColor3 = t.colors.surface
		corner.CornerRadius = UDim.new(0, t.radiusSm)
		stroke.Color = if focused then t.colors.accent else t.colors.border
		stroke.Thickness = t.stroke
		box.FontFace = t.fonts.mono
		box.TextSize = t.text.md
		box.TextColor3 = t.colors.text
		box.PlaceholderColor3 = t.colors.textDim
	end)

	local function set(v: number, silent: boolean?)
		local nv = clampSnap(v)
		local changed = nv ~= value
		value = nv
		box.Text = fmt(value)
		if changed and not silent and o.onChange then
			o.onChange(value)
		end
	end

	local minus = Controls.IconButton({
		glyph = "−",
		name = "Minus",
		onClick = function()
			if not disabled then
				set(value - step)
			end
		end,
	})
	minus.frame.Parent = root
	local plus = Controls.IconButton({
		glyph = "+",
		name = "Plus",
		onClick = function()
			if not disabled then
				set(value + step)
			end
		end,
	})
	plus.frame.AnchorPoint = Vector2.new(1, 0)
	plus.frame.Position = UDim2.fromScale(1, 0)
	plus.frame.Parent = root

	Core.connect(box, "Focused", function()
		focused = true
		stroke.Color = Core.Theme.get().colors.accent
	end)
	Core.connect(box, "FocusLost", function()
		focused = false
		stroke.Color = Core.Theme.get().colors.border
		local raw = string.gsub(box.Text, "[,%s%$]", "")
		local n = tonumber(raw)
		if n and KitMath.finite(n) and not disabled then
			set(n)
		else
			box.Text = fmt(value)
		end
	end)

	local function setDisabled(v: boolean)
		disabled = v
		box.TextEditable = not v
		minus.setDisabled(v)
		plus.setDisabled(v)
	end
	if disabled then
		setDisabled(true)
	end

	return {
		frame = root,
		box = box,
		set = set,
		get = function()
			return value
		end,
		setDisabled = setDisabled,
	}
end

return Inputs
