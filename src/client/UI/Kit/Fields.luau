--!strict
-- Text and choice fields: TextInput, Dropdown.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Strings = require(Shared.Config.Strings)
local Core = require(script.Parent.Core)
local Text = require(script.Parent.Text)
local Controls = require(script.Parent.Controls)
local Layout = require(script.Parent.Layout)

type Tokens = Core.Tokens

local Fields = {}

---------------------------------------------------------------------------------------------------
-- TextInput
---------------------------------------------------------------------------------------------------
export type TextInputOpts = {
	value: string?,
	placeholder: string?,
	maxLength: number?, -- characters, default 200
	onChange: ((text: string) -> ())?,
	onSubmit: ((text: string, enterPressed: boolean) -> ())?, -- on focus lost
	multiline: boolean?,
	size: UDim2?, -- default full width, 44 px (multiline: 120 px)
	mono: boolean?,
	name: string?,
	layoutOrder: number?,
}
export type TextInput = {
	frame: Frame,
	box: TextBox,
	get: () -> string,
	set: (text: string) -> (),
	focus: () -> (),
	release: () -> (),
}

function Fields.TextInput(opts: TextInputOpts?): TextInput
	local o: TextInputOpts = opts or {}
	local maxLength = o.maxLength or 200
	local root = Instance.new("Frame")
	root.Name = o.name or "TextInput"
	root.BorderSizePixel = 0
	root.Size = o.size or UDim2.new(1, 0, 0, if o.multiline then 120 else Core.TAP)
	root.LayoutOrder = o.layoutOrder or 0
	local corner = Core.corner(root)
	local stroke = Core.stroke(root)
	Core.padding(root, 10, 6)
	local box = Instance.new("TextBox")
	box.Name = "Box"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.ClearTextOnFocus = false
	box.MultiLine = o.multiline == true
	box.TextWrapped = o.multiline == true
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = if o.multiline then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center
	box.PlaceholderText = o.placeholder or Strings.get("text_placeholder")
	box.Text = Core.truncate(o.value or "", maxLength)
	box.Parent = root
	local focused = false
	Core.themed(root, function(t)
		root.BackgroundColor3 = t.colors.surface
		corner.CornerRadius = UDim.new(0, t.radiusSm)
		stroke.Color = if focused then t.colors.accent else t.colors.border
		stroke.Thickness = t.stroke
		box.FontFace = if o.mono then t.fonts.mono else t.fonts.body
		box.TextSize = t.text.md
		box.TextColor3 = t.colors.text
		box.PlaceholderColor3 = t.colors.textDim
	end)

	local lastText = box.Text
	Core.propChanged(box, "Text", function()
		local s = box.Text
		local cut = Core.truncate(s, maxLength)
		if cut ~= s then
			box.Text = cut -- fires again with the trimmed text
			return
		end
		if s ~= lastText then
			lastText = s
			if o.onChange then
				o.onChange(s)
			end
		end
	end)
	Core.connect(box, "Focused", function()
		focused = true
		stroke.Color = Core.Theme.get().colors.accent
	end)
	Core.connect(box, "FocusLost", function(enterPressed: boolean)
		focused = false
		stroke.Color = Core.Theme.get().colors.border
		if o.onSubmit then
			o.onSubmit(box.Text, enterPressed)
		end
	end)

	return {
		frame = root,
		box = box,
		get = function()
			return box.Text
		end,
		set = function(s: string)
			box.Text = Core.truncate(s, maxLength)
		end,
		focus = function()
			if Core.LIVE then
				box:CaptureFocus()
			end
		end,
		release = function()
			if Core.LIVE then
				box:ReleaseFocus()
			end
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- Dropdown: shows the current choice; tapping opens a picker sheet in the modal layer.
---------------------------------------------------------------------------------------------------
export type DropdownOption = string | { id: string, text: string }
export type DropdownOpts = {
	options: { DropdownOption }?,
	value: string?, -- selected id
	onChange: ((id: string) -> ())?,
	placeholder: string?,
	title: string?, -- picker title (default: placeholder)
	size: UDim2?, -- default full width, 44 px
	name: string?,
	layoutOrder: number?,
}
export type Dropdown = {
	frame: TextButton,
	set: (id: string?, silent: boolean?) -> (),
	get: () -> string?,
	setOptions: (options: { DropdownOption }) -> (),
	open: () -> (),
}

local function normalize(options: { DropdownOption }): { { id: string, text: string } }
	local out: { { id: string, text: string } } = {}
	for _, opt in options do
		if type(opt) == "string" then
			table.insert(out, { id = opt, text = opt })
		elseif type(opt) == "table" and type(opt.id) == "string" then
			table.insert(out, { id = opt.id, text = if type(opt.text) == "string" then opt.text else opt.id })
		end
	end
	return out
end

function Fields.Dropdown(opts: DropdownOpts?): Dropdown
	local o: DropdownOpts = opts or {}
	local options = normalize(o.options or {})
	local value: string? = o.value
	local placeholder = o.placeholder or Strings.get("dropdown_placeholder")
	local state = { hover = false, pressed = false }

	local b = Instance.new("TextButton")
	b.Name = o.name or "Dropdown"
	b.Text = ""
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Size = o.size or UDim2.new(1, 0, 0, Core.TAP)
	b.LayoutOrder = o.layoutOrder or 0
	local minSize = Instance.new("UISizeConstraint")
	minSize.MinSize = Vector2.new(Core.TAP, Core.TAP)
	minSize.Parent = b
	local corner = Core.corner(b)
	local stroke = Core.stroke(b)
	Core.padding(b, 12, 0)
	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -24, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = b
	local caret = Instance.new("TextLabel")
	caret.Name = "Caret"
	caret.BackgroundTransparency = 1
	caret.AnchorPoint = Vector2.new(1, 0)
	caret.Position = UDim2.fromScale(1, 0)
	caret.Size = UDim2.new(0, 20, 1, 0)
	caret.Text = "▾"
	caret.Parent = b

	local function currentText(): string?
		for _, opt in options do
			if opt.id == value then
				return opt.text
			end
		end
		return nil
	end
	local function paint(t: Tokens)
		local txt = currentText()
		label.Text = txt or placeholder
		b.BackgroundColor3 = if state.pressed then Core.shade(t.colors.surface, -0.12) else t.colors.surface
		corner.CornerRadius = UDim.new(0, t.radiusSm)
		stroke.Color = if state.hover then t.colors.accent else t.colors.border
		stroke.Thickness = t.stroke
		label.FontFace = t.fonts.body
		label.TextSize = t.text.md
		label.TextColor3 = if txt then t.colors.text else t.colors.textDim
		caret.FontFace = t.fonts.bodyBold
		caret.TextSize = t.text.md
		caret.TextColor3 = t.colors.textDim
	end
	local function repaint()
		paint(Core.Theme.get())
	end
	Core.themed(b, paint)
	Controls.wireFeedback(b, state, repaint)

	local function set(id: string?, silent: boolean?)
		local changed = id ~= value
		value = id
		repaint()
		if changed and not silent and id ~= nil and o.onChange then
			o.onChange(id)
		end
	end

	local function open()
		Core.openModal({ width = 380, name = "DropdownPicker" }, function(card, close)
			Core.list(card, false, 8)
			local heading = Text.Heading({ text = o.title or placeholder, level = 3, layoutOrder = 1 })
			heading.frame.Parent = card
			local scroll = Layout.Scroll({ size = UDim2.new(1, 0, 0, math.min(#options, 6) * (Core.TAP + 6) + 8) })
			scroll.frame.LayoutOrder = 2
			scroll.frame.Parent = card
			for _, opt in options do
				local choice = Controls.Button({
					text = opt.text,
					style = if opt.id == value then "primary" else "secondary",
					fill = true,
					name = "Option_" .. opt.id,
					onClick = function()
						close()
						set(opt.id)
					end,
				})
				scroll.add(choice.frame)
			end
			local cancel = Controls.Button({
				text = Strings.get("cancel"),
				style = "ghost",
				fill = true,
				layoutOrder = 3,
				onClick = close,
			})
			cancel.frame.Parent = card
		end)
	end
	Core.connect(b, "Activated", function()
		Core.sound("click")
		open()
	end)

	return {
		frame = b,
		set = set,
		get = function()
			return value
		end,
		setOptions = function(list: { DropdownOption })
			options = normalize(list)
			repaint()
		end,
		open = open,
	}
end

return Fields
