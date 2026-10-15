--!strict
-- Data display: Table (header + scrolling body), LineChart (rotated Frame segments), Sparkline.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Strings = require(Shared.Config.Strings)
local Core = require(script.Parent.Core)
local KitMath = require(script.Parent.Math)
local Layout = require(script.Parent.Layout)

type Tokens = Core.Tokens
type ColorSpec = Core.ColorSpec

local Data = {}

---------------------------------------------------------------------------------------------------
-- Table
---------------------------------------------------------------------------------------------------
export type Column = {
	key: (string | number)?, -- row field (default: column index for array rows)
	title: string?,
	width: number?, -- <= 1 scale fraction, > 1 pixels, nil = share the rest
	align: ("left" | "center" | "right")?,
	mono: boolean?, -- RobotoMono (numbers); default true for right-aligned columns
	format: ((value: any, row: any) -> string)?,
	color: ((value: any, row: any) -> ColorSpec?)?, -- per-cell text colour
}
export type TableOpts = {
	columns: { Column },
	rows: { any }?,
	rowHeight: number?, -- default 36
	size: UDim2?, -- default fill parent
	onRowClick: ((row: any, index: number) -> ())?,
	emptyText: string?,
	name: string?,
	layoutOrder: number?,
}
export type Table = {
	frame: Frame,
	body: ScrollingFrame,
	setRows: (rows: { any }) -> (),
	setColumns: (columns: { Column }) -> (),
}

local ALIGN = {
	left = Enum.TextXAlignment.Left,
	center = Enum.TextXAlignment.Center,
	right = Enum.TextXAlignment.Right,
}
local HEADER_H = 34

function Data.Table(opts: TableOpts): Table
	local columns: { Column } = opts.columns or {}
	local rows: { any } = opts.rows or {}
	local rowH = math.max(28, opts.rowHeight or 36)
	local root = Core.frame(opts.name or "Table", opts.size or UDim2.fromScale(1, 1))
	root.LayoutOrder = opts.layoutOrder or 0

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, HEADER_H)
	header.Parent = root
	local headerCorner = Core.corner(header)

	local body = Layout.Scroll({ gap = 0, padding = 0, name = "Body" })
	body.frame.Position = UDim2.fromOffset(0, HEADER_H + 2)
	body.frame.Size = UDim2.new(1, 0, 1, -(HEADER_H + 2))
	body.frame.Parent = root

	local empty = Instance.new("TextLabel")
	empty.Name = "Empty"
	empty.BackgroundTransparency = 1
	empty.Size = UDim2.new(1, 0, 0, 48)
	empty.Position = UDim2.fromOffset(0, HEADER_H + 8)
	empty.Text = opts.emptyText or Strings.get("empty")
	empty.TextWrapped = true
	empty.Parent = root

	local function cellWidths(): { { scale: number, offset: number } }
		local widths: { number? } = {}
		for i, c in columns do
			widths[i] = c.width
		end
		return KitMath.columnWidths(widths, #columns)
	end

	local function makeCell(
		parent: Instance,
		text: string,
		col: Column,
		x: { scale: number, offset: number },
		at: UDim
	): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.new(at.Scale, at.Offset, 0, 0)
		l.Size = UDim2.new(x.scale, x.offset, 1, 0)
		l.Text = text
		l.TextXAlignment = ALIGN[col.align or "left"] or Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = l
		l.Parent = parent
		return l
	end

	local function cellValue(row: any, col: Column, index: number): any
		if type(row) ~= "table" then
			return if index == 1 then row else nil
		end
		local key = col.key
		if key == nil then
			return row[index]
		end
		return row[key]
	end

	local function cellText(row: any, col: Column, index: number): string
		local v = cellValue(row, col, index)
		if col.format then
			local ok, s = pcall(col.format, v, row)
			return if ok and type(s) == "string" then s else "-"
		end
		if v == nil then
			return ""
		end
		if type(v) == "number" then
			return if v == math.floor(v) then Format.commas(v) else string.format("%.2f", v)
		end
		return tostring(v)
	end

	local headerCells: { TextLabel } = {}
	local function buildHeader()
		for _, c in headerCells do
			c:Destroy()
		end
		table.clear(headerCells)
		local widths = cellWidths()
		local at = UDim.new(0, 0)
		for i, col in columns do
			local w = widths[i]
			local cell = makeCell(header, col.title or "", col, w, at)
			cell.Name = "H" .. i
			table.insert(headerCells, cell)
			at = UDim.new(at.Scale + w.scale, at.Offset + w.offset)
		end
	end

	type RowRecord = { frame: GuiObject, cells: { { label: TextLabel, col: Column, value: any, row: any } } }
	local rowRecords: { RowRecord } = {}

	local function paintRows(t: Tokens)
		for i, rec in rowRecords do
			local f = rec.frame
			f.BackgroundColor3 = if i % 2 == 0 then t.colors.panelAlt else t.colors.panel
			f.BackgroundTransparency = if i % 2 == 0 then 0.2 else 0.6
			for _, cell in rec.cells do
				local col = cell.col
				local mono = if col.mono ~= nil then col.mono else col.align == "right"
				cell.label.FontFace = if mono then t.fonts.mono else t.fonts.body
				cell.label.TextSize = t.text.sm
				local cspec: ColorSpec? = nil
				if col.color then
					local ok, res = pcall(col.color, cell.value, cell.row)
					if ok then
						cspec = res
					end
				end
				cell.label.TextColor3 = Core.color(t, cspec, "text")
			end
		end
	end

	local function buildRows()
		for _, rec in rowRecords do
			rec.frame:Destroy()
		end
		table.clear(rowRecords)
		local widths = cellWidths()
		for r, row in rows do
			local f: GuiObject
			if opts.onRowClick then
				local b = Instance.new("TextButton")
				b.Text = ""
				b.AutoButtonColor = false
				local onRowClick = opts.onRowClick
				local index = r
				Core.connect(b, "Activated", function()
					Core.sound("click")
					onRowClick(row, index)
				end)
				f = b
			else
				f = Instance.new("Frame")
			end
			f.Name = "Row" .. r
			f.BorderSizePixel = 0
			f.Size = UDim2.new(1, 0, 0, rowH)
			f.LayoutOrder = r
			local rec: RowRecord = { frame = f, cells = {} }
			local at = UDim.new(0, 0)
			for i, col in columns do
				local w = widths[i]
				local label = makeCell(f, cellText(row, col, i), col, w, at)
				label.Name = "C" .. i
				table.insert(rec.cells, { label = label, col = col, value = cellValue(row, col, i), row = row })
				at = UDim.new(at.Scale + w.scale, at.Offset + w.offset)
			end
			f.Parent = body.frame
			table.insert(rowRecords, rec)
		end
		empty.Visible = #rows == 0
		paintRows(Core.Theme.get())
	end

	local function paintHeader(t: Tokens)
		header.BackgroundColor3 = t.colors.panelAlt
		headerCorner.CornerRadius = UDim.new(0, t.radiusSm)
		for _, cell in headerCells do
			cell.FontFace = t.fonts.bodyBold
			cell.TextSize = t.text.sm
			cell.TextColor3 = t.colors.textDim
		end
		empty.FontFace = t.fonts.body
		empty.TextSize = t.text.md
		empty.TextColor3 = t.colors.textDim
	end

	buildHeader()
	buildRows()
	Core.themed(root, function(t)
		paintHeader(t)
		paintRows(t)
	end)

	return {
		frame = root,
		body = body.frame,
		setRows = function(newRows: { any })
			rows = newRows or {}
			buildRows()
		end,
		setColumns = function(newColumns: { Column })
			columns = newColumns or {}
			buildHeader()
			paintHeader(Core.Theme.get())
			buildRows()
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- LineChart
---------------------------------------------------------------------------------------------------
export type Series = {
	points: { number },
	color: ColorSpec?, -- default cycles accent, good, bad, warn, textDim
	thickness: number?, -- px (default 2)
	dot: boolean?, -- end-point dot (default true)
}
export type LineChartOpts = {
	series: { Series }?,
	yFormat: ((value: number) -> string)?,
	baseline: number?, -- dashed reference line (e.g. starting value)
	minY: number?,
	maxY: number?,
	size: UDim2?, -- default full width, 180 px
	showAxis: boolean?, -- y-axis labels + grid lines (default true)
	gridLines: number?, -- approximate count (default 4)
	width: number?, -- fallback plot size before layout / under Lune
	height: number?,
	name: string?,
	layoutOrder: number?,
}
export type LineChart = {
	frame: Frame,
	plot: Frame,
	set: (series: { Series }) -> (),
	setBaseline: (value: number?) -> (),
	render: () -> (),
	segmentCount: () -> number,
	bounds: () -> (number, number),
}

local AXIS_W = 58
local SERIES_COLORS = { "accent", "good", "bad", "warn", "textDim" }

local function defaultYFormat(lo: number, hi: number): (number) -> string
	local span = hi - lo
	return function(v: number): string
		local a = math.abs(v)
		if a >= 1e6 then
			return (string.gsub(Format.compactMoney(v), "%$", ""))
		elseif span < 0.1 then
			return string.format("%.3f", v)
		elseif span < 10 then
			return string.format("%.2f", v)
		end
		return Format.commas(v)
	end
end

function Data.LineChart(opts: LineChartOpts?): LineChart
	local o: LineChartOpts = opts or {}
	local series: { Series } = o.series or {}
	local baseline = o.baseline
	local showAxis = o.showAxis ~= false
	local axisW = if showAxis then AXIS_W else 0
	local lo, hi = 0, 1

	local root = Core.frame(o.name or "LineChart", o.size or UDim2.new(1, 0, 0, 180))
	root.LayoutOrder = o.layoutOrder or 0
	local plot = Core.frame("Plot", UDim2.new(1, -axisW, 1, if showAxis then -8 else 0))
	plot.Position = UDim2.fromOffset(axisW, if showAxis then 4 else 0)
	plot.Parent = root
	local gridFolder = Instance.new("Folder")
	gridFolder.Name = "Grid"
	gridFolder.Parent = plot
	local axisFolder = Instance.new("Folder")
	axisFolder.Name = "Axis"
	axisFolder.Parent = root
	local baselineFrame = Instance.new("Frame")
	baselineFrame.Name = "Baseline"
	baselineFrame.BorderSizePixel = 0
	baselineFrame.Size = UDim2.new(1, 0, 0, 1)
	baselineFrame.Visible = false
	baselineFrame.ZIndex = 2
	baselineFrame.Parent = plot
	local baselineGradient = Instance.new("UIGradient")
	-- Dashed look: alternating transparency along the line.
	local keys: { NumberSequenceKeypoint } = {}
	local dashes = 18
	for i = 0, dashes do
		local x = i / dashes
		table.insert(keys, NumberSequenceKeypoint.new(x, if i % 2 == 0 then 0.1 else 0.85))
	end
	baselineGradient.Transparency = NumberSequence.new(keys)
	baselineGradient.Parent = baselineFrame

	local lineFolders: { Folder } = {}
	local pools: { { Frame } } = {}
	local dots: { Frame } = {}
	local segmentTotal = 0

	local function plotSize(): (number, number)
		local s = Core.unscaledSize(plot)
		if s then
			return s.X, s.Y
		end
		return o.width or 320, o.height or 160
	end

	local function seriesColor(t: Tokens, s: Series, i: number): Color3
		local spec: ColorSpec = s.color or SERIES_COLORS[((i - 1) % #SERIES_COLORS) + 1]
		return Core.color(t, spec, "accent")
	end

	local function render()
		local t = Core.Theme.get()
		local w, h = plotSize()
		local pts: { { number } } = {}
		for i, s in series do
			pts[i] = s.points or {}
		end
		local layout = KitMath.layout(pts, w, h, { baseline = baseline, minY = o.minY, maxY = o.maxY, pad = 0.08 })
		lo, hi = layout.lo, layout.hi
		segmentTotal = 0

		-- Lines (pooled segment frames per series).
		for i, line in layout.lines do
			local s = series[i]
			local folder: Folder? = lineFolders[i]
			if folder == nil then
				local nf = Instance.new("Folder")
				nf.Name = "Series" .. i
				nf.Parent = plot
				folder = nf
				lineFolders[i] = nf
				pools[i] = {}
			end
			local pool = pools[i]
			local color = seriesColor(t, s, i)
			local thick = s.thickness or 2
			for j, seg in line.segments do
				local existing: Frame? = pool[j]
				local f: Frame
				if existing then
					f = existing
				else
					f = Instance.new("Frame")
					f.Name = "S" .. j
					f.BorderSizePixel = 0
					f.AnchorPoint = Vector2.new(0.5, 0.5)
					f.ZIndex = 3
					f.Parent = folder
					pool[j] = f
				end
				f.Position = UDim2.fromOffset(Core.px(seg.x), Core.px(seg.y))
				f.Size = UDim2.fromOffset(Core.px(seg.length + thick * 0.6), math.max(1, Core.px(thick)))
				f.Rotation = seg.angle
				f.BackgroundColor3 = color
				f.Visible = true
			end
			for j = #line.segments + 1, #pool do
				pool[j].Visible = false
			end
			segmentTotal += #line.segments
			-- End-point dot.
			local existingDot: Frame? = dots[i]
			local dot: Frame
			if existingDot then
				dot = existingDot
			else
				dot = Instance.new("Frame")
				dot.Name = "Dot"
				dot.BorderSizePixel = 0
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.Size = UDim2.fromOffset(7, 7)
				dot.ZIndex = 4
				dot.Parent = folder
				Core.corner(dot, 999)
				dots[i] = dot
			end
			local last = line.points[#line.points]
			dot.Visible = last ~= nil and s.dot ~= false
			if last then
				dot.Position = UDim2.fromOffset(Core.px(last.x), Core.px(last.y))
				dot.BackgroundColor3 = color
			end
		end
		-- Series that were removed.
		for i = #layout.lines + 1, #lineFolders do
			for _, f in pools[i] do
				f.Visible = false
			end
			if dots[i] then
				dots[i].Visible = false
			end
		end

		-- Baseline.
		if layout.baselineY then
			baselineFrame.Visible = true
			baselineFrame.Position = UDim2.fromOffset(0, Core.px(layout.baselineY))
			baselineFrame.BackgroundColor3 = t.colors.textDim
		else
			baselineFrame.Visible = false
		end

		-- Grid lines and y labels (few instances; rebuilt).
		for _, c in gridFolder:GetChildren() do
			c:Destroy()
		end
		for _, c in axisFolder:GetChildren() do
			c:Destroy()
		end
		if showAxis then
			local fmt = o.yFormat or defaultYFormat(lo, hi)
			for k, v in KitMath.ticks(lo, hi, o.gridLines or 4) do
				local y = KitMath.yFor(v, lo, hi, h)
				local g = Instance.new("Frame")
				g.Name = "G" .. k
				g.BorderSizePixel = 0
				g.Size = UDim2.new(1, 0, 0, 1)
				g.Position = UDim2.fromOffset(0, Core.px(y))
				g.BackgroundColor3 = t.colors.border
				g.BackgroundTransparency = 0.55
				g.ZIndex = 1
				g.Parent = gridFolder
				local l = Instance.new("TextLabel")
				l.Name = "Y" .. k
				l.BackgroundTransparency = 1
				l.AnchorPoint = Vector2.new(0, 0.5)
				l.Position = UDim2.fromOffset(0, Core.px(y + 4))
				l.Size = UDim2.fromOffset(axisW - 6, 14)
				l.TextXAlignment = Enum.TextXAlignment.Right
				local ok, txt = pcall(fmt, v)
				l.Text = if ok and type(txt) == "string" then txt else tostring(v)
				l.FontFace = t.fonts.mono
				l.TextSize = t.text.xs
				l.TextColor3 = t.colors.textDim
				l.Parent = axisFolder
			end
		end
	end

	render()
	Core.propChanged(plot, "AbsoluteSize", render)
	Core.themed(root, function()
		render()
	end)

	return {
		frame = root,
		plot = plot,
		set = function(newSeries: { Series })
			series = newSeries or {}
			render()
		end,
		setBaseline = function(v: number?)
			baseline = v
			render()
		end,
		render = render,
		segmentCount = function()
			return segmentTotal
		end,
		bounds = function()
			return lo, hi
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- Sparkline: tiny axis-less line chart.
---------------------------------------------------------------------------------------------------
export type SparklineOpts = {
	points: { number }?,
	color: ColorSpec?, -- default: good when last >= first, else bad
	size: UDim2?, -- default 120 x 36
	baseline: number?,
	thickness: number?,
	name: string?,
	layoutOrder: number?,
}
export type Sparkline = { frame: Frame, set: (points: { number }) -> (), chart: LineChart }

function Data.Sparkline(opts: SparklineOpts?): Sparkline
	local o: SparklineOpts = opts or {}
	local function seriesFor(points: { number }): { Series }
		local color: ColorSpec? = o.color
		if color == nil then
			local first, last = points[1], points[#points]
			color = if first and last and last < first then "bad" else "good"
		end
		return { { points = points, color = color, thickness = o.thickness or 1.5, dot = false } }
	end
	local size = o.size or UDim2.fromOffset(120, 36)
	local chart = Data.LineChart({
		series = seriesFor(o.points or {}),
		baseline = o.baseline,
		size = size,
		showAxis = false,
		width = if size.X.Scale == 0 then size.X.Offset else nil,
		height = if size.Y.Scale == 0 then size.Y.Offset else nil,
		name = o.name or "Sparkline",
		layoutOrder = o.layoutOrder,
	})
	return {
		frame = chart.frame,
		set = function(points: { number })
			chart.set(seriesFor(points or {}))
		end,
		chart = chart,
	}
end

return Data
