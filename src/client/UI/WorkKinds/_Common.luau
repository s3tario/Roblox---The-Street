--!strict
-- Shared building blocks for the work payload renderers (owned by `work`; contracts §8). Not a kind itself.
--
-- Renderer contract (every UI/WorkKinds/<kind>.luau):
--   Renderer.mount(container: Frame, payload, api: Api) -> cleanup: () -> ()
--   Api = { answers: any?,                 previous answers to restore (resume), in the kind's answer shape
--           onChange: (answers: any) -> () called with the full answer value after every change }
--   The container has a vertical UIListLayout and automatic height; renderers append children in order and must
--   leave nothing behind after cleanup. Phone first: every tap target is at least 44 px, text wraps, wide tables
--   scroll sideways, and nothing needs hover.
--
--   C.order() -> () -> number                   increasing LayoutOrder values
--   C.text(parent, text, opts?) -> Kit.Label     wrapped label (opts: size, font, color, order, name, rich)
--   C.panel(parent, order, name?) -> Frame       a themed card with a vertical list inside
--   C.choice(parent, opts) -> Choice             full-width wrapping option button (selected = accent)
--       opts = { text, order?, name?, selected?, onClick, compact? }   Choice = { frame, setSelected, setText }
--   C.chip(parent, opts) -> Choice              small auto-width toggle button (issue tags, flags)
--   C.grid(parent, columns, rows, opts?) -> Grid  a sideways-scrolling table (opts.onCell(r, c) makes cells tappable)
--       Grid = { frame, setMarked(r, c, on), cell(r, c) -> TextButton? }
--   C.number(text) -> number?                    reads "1,250", "$40", "12%", "8.5x"
--   C.track(list, conn?)                         remembers connections for cleanup; C.cleanup(list)

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

local C = {}

export type Choice = { frame: TextButton, setSelected: (on: boolean) -> (), setText: (text: string) -> () }
export type Grid = {
	frame: ScrollingFrame,
	setMarked: (r: number, c: number, on: boolean) -> (),
	cell: (r: number, c: number) -> TextButton?,
}

function C.order(): () -> number
	local n = 0
	return function(): number
		n += 1
		return n
	end
end

function C.text(parent: Instance, text: string, opts: { [string]: any }?): Kit.Label
	local o: { [string]: any } = opts or {}
	local label = Kit.Label({
		text = text,
		size = o.size or "md",
		font = o.font or "body",
		color = o.color or "text",
		rich = o.rich,
		name = o.name or "Text",
		layoutOrder = o.order or 0,
		align = o.align,
	})
	label.frame.Parent = parent
	return label
end

function C.panel(parent: Instance, order: number, name: string?): Frame
	local p = Kit.Panel({ color = "panelAlt", list = true, gap = 8, name = name or "Card", layoutOrder = order })
	p.frame.Parent = parent
	return p.frame
end

local function paintChoice(
	b: TextButton,
	label: TextLabel,
	corner: UICorner,
	stroke: UIStroke,
	selected: boolean,
	t: Kit.Tokens
)
	b.BackgroundColor3 = if selected then t.colors.accent else t.colors.surface
	b.BackgroundTransparency = 0
	label.TextColor3 = if selected then t.colors.accentText else t.colors.text
	label.FontFace = if selected then t.fonts.bodyBold else t.fonts.body
	label.TextSize = t.text.md
	corner.CornerRadius = UDim.new(0, t.radiusSm)
	stroke.Color = if selected then t.colors.accent else t.colors.border
	stroke.Thickness = t.stroke
end

local function makeButton(parent: Instance, opts: { [string]: any }, chip: boolean): Choice
	local selected = opts.selected == true
	local b = Instance.new("TextButton")
	b.Name = opts.name or (if chip then "Chip" else "Choice")
	b.Text = ""
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.LayoutOrder = opts.order or 0
	if chip then
		b.Size = UDim2.fromOffset(0, Kit.TAP)
		b.AutomaticSize = Enum.AutomaticSize.X
	else
		b.Size = UDim2.new(1, 0, 0, 0)
		b.AutomaticSize = Enum.AutomaticSize.Y
	end
	local min = Instance.new("UISizeConstraint")
	min.MinSize = Vector2.new(Kit.TAP, Kit.TAP)
	min.Parent = b
	local corner = Instance.new("UICorner")
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = b
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Text = opts.text or ""
	label.TextWrapped = not chip
	label.TextXAlignment = if chip then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	if chip then
		label.Size = UDim2.fromScale(0, 1)
		label.AutomaticSize = Enum.AutomaticSize.X
	else
		label.Size = UDim2.new(1, 0, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
	end
	label.Parent = b
	Kit.themed(b, function(t)
		paintChoice(b, label, corner, stroke, selected, t)
	end)
	Kit.connect(b, "Activated", function()
		Kit.sound("click")
		local fn = opts.onClick
		if fn then
			fn()
		end
	end)
	b.Parent = parent
	return {
		frame = b,
		setSelected = function(on: boolean)
			selected = on
			paintChoice(b, label, corner, stroke, selected, Kit.Theme.get())
		end,
		setText = function(text: string)
			label.Text = text
		end,
	}
end

function C.choice(parent: Instance, opts: { [string]: any }): Choice
	return makeButton(parent, opts, false)
end

function C.chip(parent: Instance, opts: { [string]: any }): Choice
	return makeButton(parent, opts, true)
end

-- Column width from its longest text (px), so a 6-8 column table stays readable and scrolls on phones.
local function columnWidths(columns: { string }, rows: { { string } }): { number }
	local widths: { number } = {}
	for c, title in columns do
		local longest = utf8.len(title) or #title
		for _, row in rows do
			local cell = row[c]
			if type(cell) == "string" then
				longest = math.max(longest, utf8.len(cell) or #cell)
			end
		end
		widths[c] = math.clamp(longest * 8 + 20, 64, 220)
	end
	return widths
end

function C.grid(parent: Instance, columns: { string }, rows: { { string } }, opts: { [string]: any }?): Grid
	local o: { [string]: any } = opts or {}
	local onCell = o.onCell
	local widths = columnWidths(columns, rows)
	local total = 0
	for _, w in widths do
		total += w + 2
	end
	local rowH = if onCell then Kit.TAP else 34
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = o.name or "Table"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = o.order or 0
	local height = (#rows + 1) * (rowH + 2)
	scroll.Size = UDim2.new(1, 0, 0, height + 10) -- room for the sideways scroll bar
	scroll.CanvasSize = UDim2.fromOffset(total, height)
	scroll.ScrollingDirection = Enum.ScrollingDirection.X
	scroll.ScrollBarThickness = 6
	scroll.HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	Kit.themed(scroll, function(t)
		scroll.ScrollBarImageColor3 = t.colors.textDim
	end)
	local cells: { [string]: TextButton } = {}
	local marked: { [string]: boolean } = {}
	local function paintCell(btn: TextButton, r: number, isHeader: boolean, isMarked: boolean, t: Kit.Tokens)
		local label = btn:FindFirstChild("Label") :: TextLabel?
		if isHeader then
			btn.BackgroundColor3 = t.colors.surface
		elseif isMarked then
			btn.BackgroundColor3 = t.colors.bad
		else
			btn.BackgroundColor3 = if r % 2 == 0 then t.colors.panelAlt else t.colors.panel
		end
		btn.BackgroundTransparency = 0
		if label then
			label.FontFace = if isHeader or isMarked then t.fonts.bodyBold else t.fonts.mono
			label.TextSize = t.text.sm
			label.TextColor3 = if isMarked then Color3.fromRGB(255, 255, 255) else t.colors.text
		end
	end
	local function addRow(r: number, values: { string }, isHeader: boolean)
		local x = 0
		for c = 1, #columns do
			local btn = Instance.new("TextButton")
			btn.Name = if isHeader then ("H" .. c) else ("R" .. r .. "C" .. c)
			btn.Text = ""
			btn.AutoButtonColor = false
			btn.BorderSizePixel = 0
			btn.Position = UDim2.fromOffset(x, if isHeader then 0 else r * (rowH + 2))
			btn.Size = UDim2.fromOffset(widths[c], rowH)
			btn.Active = onCell ~= nil and not isHeader
			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, -8, 1, 0)
			label.Position = UDim2.fromOffset(4, 0)
			label.Text = values[c] or ""
			label.TextWrapped = true
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextXAlignment = if c == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
			label.Parent = btn
			local key = r .. ":" .. c
			Kit.themed(btn, function(t)
				paintCell(btn, r, isHeader, marked[key] == true, t)
			end)
			if not isHeader then
				cells[key] = btn
				if onCell then
					Kit.connect(btn, "Activated", function()
						onCell(r, c)
					end)
				end
			end
			btn.Parent = scroll
			x += widths[c] + 2
		end
	end
	addRow(0, columns, true)
	for r, values in rows do
		addRow(r, values, false)
	end
	scroll.Parent = parent
	return {
		frame = scroll,
		setMarked = function(r: number, c: number, on: boolean)
			local key = r .. ":" .. c
			marked[key] = on
			local btn = cells[key]
			if btn then
				paintCell(btn, r, false, on, Kit.Theme.get())
			end
		end,
		cell = function(r: number, c: number): TextButton?
			return cells[r .. ":" .. c]
		end,
	}
end

function C.number(text: any): number?
	if type(text) == "number" then
		return if text == text and text ~= math.huge and text ~= -math.huge then text else nil
	end
	if type(text) ~= "string" or #text > 40 then
		return nil
	end
	local cleaned = string.gsub(text, "[,%s%$%%xX]", "")
	if cleaned == "" then
		return nil
	end
	local n = tonumber(cleaned)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return n
end

function C.track(list: { any }, conn: any)
	if conn ~= nil then
		table.insert(list, conn)
	end
end

function C.cleanup(list: { any })
	for _, item in list do
		local t = typeof(item)
		if t == "RBXScriptConnection" then
			(item :: RBXScriptConnection):Disconnect()
		elseif t == "Instance" then
			(item :: Instance):Destroy()
		elseif type(item) == "function" then
			pcall(item)
		elseif type(item) == "table" and type(item.Disconnect) == "function" then
			pcall(function()
				item:Disconnect()
			end)
		end
	end
	table.clear(list)
end

-- Plain copy of an answers value (renderers hand the runner a fresh table on every change).
function C.copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out: { [any]: any } = {}
	for k, v in value do
		out[k] = C.copy(v)
	end
	return out
end

return C
