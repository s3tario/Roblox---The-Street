--!strict
-- Terminal part: open positions (owned by `market`). One row per position, largest first: ticker, shares (negative =
-- short), average cost, last, market value, P/L and weight of the book, with Close (a market order for the whole
-- position) and an inline stop-loss / take-profit editor. "Flatten all" closes everything after a confirmation.
-- Books are session-based (design v3 §11): positions close flat when the player leaves the server.
-- Every button is at least 44 px tall; phones show ticker, value and P/L (tap a row for its stops).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Style = require(script.Parent.Style)
local View = require(script.Parent.View)
local Env = require(script.Parent.Env)

local Positions = {}

local ROW_H = 48
local BUTTONS_W = 132

type Col = { id: string, key: string, wide: number, phone: number?, align: string }

-- widths are scale fractions of the data area; phone = nil hides the column on phones
local COLS: { Col } = {
	{ id = "ticker", key = "col_ticker", wide = 0.17, phone = 0.36, align = "left" },
	{ id = "shares", key = "col_shares", wide = 0.11, phone = nil, align = "right" },
	{ id = "avg", key = "col_avg", wide = 0.13, phone = nil, align = "right" },
	{ id = "last", key = "col_last", wide = 0.13, phone = nil, align = "right" },
	{ id = "value", key = "col_value", wide = 0.16, phone = 0.32, align = "right" },
	{ id = "pnl", key = "col_pnl", wide = 0.19, phone = 0.32, align = "right" },
	{ id = "weight", key = "col_weight", wide = 0.11, phone = nil, align = "right" },
}

type TextInput = { frame: Frame, box: TextBox, get: () -> string, set: (text: string) -> () }

type Row = {
	ticker: string,
	frame: Frame,
	cells: { [string]: GuiObject }, -- what the column layout sizes
	labels: { [string]: TextLabel }, -- the value labels (every column but the ticker block)
	sub: TextLabel,
	stopsBtn: Kit.Button,
	closeBtn: Kit.Button,
	editor: Frame,
	stopInput: TextInput,
	takeInput: TextInput,
	editorStatus: TextLabel,
	open: boolean,
}

local function parseLevel(text: string): (boolean, number?)
	local s = string.gsub(text, "[%s,$]", "")
	if s == "" then
		return true, nil
	end
	local n = tonumber(s)
	if not n or n ~= n or n <= 0 or n > 1e7 then
		return false, nil
	end
	return true, math.floor(n * 100 + 0.5) / 100
end
Positions.parseLevel = parseLevel

local function levelText(v: any): string
	return if type(v) == "number" then string.format("%.2f", v) else ""
end

function Positions.new(env: Env.Env): Env.Part
	local root = Style.box("Positions", { color = "panel", autoY = true, pad = 12 })
	local stack = Style.stack("Stack", 6)
	stack.Parent = root

	local header = Kit.frame("Header", UDim2.new(1, 0, 0, Kit.TAP))
	header.LayoutOrder = 1
	header.Parent = stack
	local titles = Kit.frame("Titles", UDim2.new(1, -150, 1, 0))
	titles.Parent = header
	local tl = Kit.list(titles, true, 8)
	tl.VerticalAlignment = Enum.VerticalAlignment.Center
	Style.section(Tickers.text("positions"), 1).Parent = titles
	local count = Style.text("Count", "", { size = "xs", color = "dim", order = 2 })
	count.Parent = titles

	local busy = false

	local flatten = Kit.Button({
		text = Tickers.text("flatten_all"),
		style = "danger",
		size = UDim2.fromOffset(140, Kit.TAP),
		textSize = "sm",
		name = "FlattenAll",
		onClick = function()
			if busy or env.mode == "news" then
				return
			end
			env.actions.confirm({
				title = Tickers.text("flatten_confirm_title"),
				body = Tickers.text("flatten_confirm_body"),
				confirmText = Tickers.text("flatten_confirm_ok"),
				cancelText = Tickers.text("cancel"),
				danger = true,
			}, function(ok: boolean)
				if not ok then
					return
				end
				busy = true
				local okCall, okFlat, err = pcall(function()
					return env.controller:Flatten()
				end)
				busy = false
				if okCall and okFlat == true then
					env.actions.notify(Tickers.text("flattened"), "good")
				else
					env.actions.notify(env.controller:ErrorText(if okCall then err else "generic", nil), "warn")
				end
				env.actions.refresh()
			end)
		end,
	})
	flatten.frame.AnchorPoint = Vector2.new(1, 0.5)
	flatten.frame.Position = UDim2.new(1, 0, 0.5, 0)
	flatten.frame.Parent = header

	local colHeader = Kit.frame("Columns", UDim2.new(1, 0, 0, 20))
	colHeader.LayoutOrder = 2
	colHeader.Parent = stack
	local colData = Kit.frame("Data", UDim2.new(1, -BUTTONS_W, 1, 0))
	colData.Parent = colHeader
	Kit.list(colData, true, 0)
	local colLabels: { [string]: TextLabel } = {}
	for i, col in COLS do
		local l = Style.text("H_" .. col.id, Tickers.text(col.key), {
			size = "xs",
			color = "dim",
			align = col.align :: any,
			autoSize = "none",
			size2 = UDim2.new(col.wide, -6, 1, 0),
			order = i,
		})
		l.Parent = colData
		colLabels[col.id] = l
	end

	local list = Style.stack("Rows", 4, 3)
	list.Parent = stack
	local empty = Style.text("Empty", Tickers.text("no_positions"), {
		size = "sm",
		color = "dim",
		wrap = true,
		autoSize = "y",
		size2 = UDim2.new(1, 0, 0, 0),
		order = 4,
	})
	empty.Parent = stack

	local rows: { [string]: Row } = {}
	local layoutMode = ""

	local function applyLayout(row: Row?, mode: string)
		local function size(col: Col): (boolean, number)
			if mode == "phone" then
				return col.phone ~= nil, col.phone or 0
			end
			return true, col.wide
		end
		if row then
			for _, col in COLS do
				local visible, w = size(col)
				local cell = row.cells[col.id]
				cell.Visible = visible
				cell.Size = UDim2.new(w, -6, 1, 0)
			end
			row.stopsBtn.frame.Visible = mode == "wide" and env.mode ~= "news"
			return
		end
		for _, col in COLS do
			local visible, w = size(col)
			colLabels[col.id].Visible = visible
			colLabels[col.id].Size = UDim2.new(w, -6, 1, 0)
		end
		colHeader.Visible = mode == "wide"
	end

	local function setEditorStatus(row: Row, text: string, color: string)
		Style.setText(row.editorStatus, text, color)
	end

	local function saveStops(row: Row, clear: boolean)
		if busy then
			return
		end
		local stop: number? = nil
		local take: number? = nil
		if not clear then
			local okStop, s = parseLevel(row.stopInput.get())
			local okTake, t = parseLevel(row.takeInput.get())
			if not okStop then
				setEditorStatus(row, Tickers.text("err_bad_stop"), "down")
				return
			end
			if not okTake then
				setEditorStatus(row, Tickers.text("err_bad_take"), "down")
				return
			end
			stop, take = s, t
		end
		busy = true
		setEditorStatus(row, Tickers.text("placing"), "dim")
		task.spawn(function()
			local okCall, ok, err = pcall(function()
				return env.controller:SetStops(row.ticker, stop, take)
			end)
			busy = false
			if okCall and ok == true then
				local msg = if stop == nil and take == nil
					then Tickers.text("stops_cleared", { ticker = row.ticker })
					else Tickers.text("stops_saved", { ticker = row.ticker })
				setEditorStatus(row, msg, "up")
				if clear then
					row.stopInput.set("")
					row.takeInput.set("")
				end
			else
				setEditorStatus(row, env.controller:ErrorText(if okCall then err else "generic", nil), "down")
			end
			env.actions.refresh()
		end)
	end

	local function closePosition(row: Row)
		if busy or env.mode == "news" then
			return
		end
		busy = true
		row.closeBtn.setText(Tickers.text("closing"))
		row.closeBtn.setDisabled(true)
		task.spawn(function()
			local okCall, ok, err, payload = pcall(function()
				return env.controller:Trade({ ticker = row.ticker, side = "close" })
			end)
			busy = false
			row.closeBtn.setText(Tickers.text("close_position"))
			row.closeBtn.setDisabled(false)
			if okCall and ok == true then
				env.actions.notify(Tickers.text("closed_position", { ticker = row.ticker }), "good")
			else
				local vars = if okCall and type(payload) == "table" then payload.vars else nil
				env.actions.notify(env.controller:ErrorText(if okCall then err else "generic", vars), "warn")
			end
			env.actions.refresh()
		end)
	end

	local function makeRow(ticker: string): Row
		local f = Style.box("Row_" .. ticker, { color = "panelAlt", autoY = true, stroke = false, radius = 4 })
		f.BackgroundTransparency = 0.2
		Kit.list(f, false, 0)
		local main = Instance.new("TextButton")
		main.Name = "Main"
		main.Text = ""
		main.AutoButtonColor = false
		main.BackgroundTransparency = 1
		main.BorderSizePixel = 0
		main.Size = UDim2.new(1, 0, 0, ROW_H)
		main.LayoutOrder = 1
		main.Parent = f
		local data = Kit.frame("Data", UDim2.new(1, -BUTTONS_W, 1, 0))
		data.Position = UDim2.fromOffset(8, 0)
		data.Parent = main
		local dl = Kit.list(data, true, 0)
		dl.VerticalAlignment = Enum.VerticalAlignment.Center
		local cells: { [string]: GuiObject } = {}
		local labels: { [string]: TextLabel } = {}
		local sub: TextLabel = nil :: any
		for i, col in COLS do
			if col.id == "ticker" then
				local holder = Kit.frame("C_ticker", UDim2.new(col.wide, -6, 1, 0))
				holder.LayoutOrder = i
				holder.Parent = data
				local hl = Kit.list(holder, false, 0)
				hl.VerticalAlignment = Enum.VerticalAlignment.Center
				local top = Style.text("Ticker", ticker, { size = "md", font = "bold", order = 1 })
				top.Parent = holder
				sub = Style.text("Sub", "", {
					size = "xs",
					color = "dim",
					order = 2,
					autoSize = "none",
					size2 = UDim2.new(1, 0, 0, 14),
					truncate = true,
				})
				sub.Parent = holder
				cells.ticker = holder
			else
				local l = Style.text("C_" .. col.id, "--", {
					size = "sm",
					font = "mono",
					align = col.align :: any,
					autoSize = "none",
					size2 = UDim2.new(col.wide, -6, 1, 0),
					order = i,
				})
				l.Parent = data
				cells[col.id] = l
				labels[col.id] = l
			end
		end
		local buttons = Kit.frame("Buttons", UDim2.new(0, BUTTONS_W - 8, 1, 0))
		buttons.AnchorPoint = Vector2.new(1, 0)
		buttons.Position = UDim2.new(1, -4, 0, 0)
		buttons.Parent = main
		local bl = Kit.list(buttons, true, 4)
		bl.VerticalAlignment = Enum.VerticalAlignment.Center
		bl.HorizontalAlignment = Enum.HorizontalAlignment.Right

		local row: Row = nil :: any
		local stopsBtn = Kit.Button({
			text = Tickers.text("edit_stops"),
			style = "ghost",
			size = UDim2.fromOffset(58, Kit.TAP),
			textSize = "xs",
			name = "Stops",
			layoutOrder = 1,
			onClick = function()
				row.open = not row.open
				row.editor.Visible = row.open
			end,
		})
		stopsBtn.frame.Parent = buttons
		local closeBtn = Kit.Button({
			text = Tickers.text("close_position"),
			style = "secondary",
			size = UDim2.fromOffset(62, Kit.TAP),
			textSize = "xs",
			name = "Close",
			layoutOrder = 2,
			onClick = function()
				closePosition(row)
			end,
		})
		closeBtn.frame.Parent = buttons
		closeBtn.frame.Visible = env.mode ~= "news"

		-- stops editor
		local editor = Style.stack("Editor", 6, 2)
		editor.Visible = false
		editor.Parent = f
		Kit.padding(editor, 8, 6)
		local inputs = Kit.frame("Inputs", UDim2.new(1, 0, 0, Kit.TAP))
		inputs.LayoutOrder = 1
		inputs.Parent = editor
		local stopInput = Kit.TextInput({
			placeholder = Tickers.text("stop"),
			maxLength = 12,
			mono = true,
			size = UDim2.new(0.5, -4, 0, Kit.TAP),
			name = "Stop",
		})
		stopInput.frame.Parent = inputs
		local takeInput = Kit.TextInput({
			placeholder = Tickers.text("take"),
			maxLength = 12,
			mono = true,
			size = UDim2.new(0.5, -4, 0, Kit.TAP),
			name = "Take",
		})
		takeInput.frame.AnchorPoint = Vector2.new(1, 0)
		takeInput.frame.Position = UDim2.fromScale(1, 0)
		takeInput.frame.Parent = inputs
		local actions = Style.row("Actions", Kit.TAP, 8)
		actions.LayoutOrder = 2
		actions.Parent = editor
		local save = Kit.Button({
			text = Tickers.text("set_stops"),
			style = "primary",
			textSize = "sm",
			name = "Save",
			layoutOrder = 1,
			onClick = function()
				saveStops(row, false)
			end,
		})
		save.frame.Parent = actions
		local clear = Kit.Button({
			text = Tickers.text("clear_stops"),
			style = "secondary",
			textSize = "sm",
			name = "Clear",
			layoutOrder = 2,
			onClick = function()
				saveStops(row, true)
			end,
		})
		clear.frame.Parent = actions
		local status = Style.text("Status", "", {
			size = "xs",
			color = "dim",
			wrap = true,
			autoSize = "y",
			size2 = UDim2.new(1, 0, 0, 0),
			order = 3,
		})
		status.Parent = editor

		row = {
			ticker = ticker,
			frame = f,
			cells = cells,
			labels = labels,
			sub = sub,
			stopsBtn = stopsBtn,
			closeBtn = closeBtn,
			editor = editor,
			stopInput = stopInput,
			takeInput = takeInput,
			editorStatus = status,
			open = false,
		}
		Kit.connect(main, "Activated", function()
			Kit.sound("click")
			env.actions.select(ticker)
			if env.mode ~= "news" and (layoutMode == "phone" or row.open) then
				row.open = not row.open
				editor.Visible = row.open
			end
		end)
		applyLayout(row, layoutMode)
		return row
	end

	local function update(st: Env.State)
		if st.layout ~= layoutMode then
			layoutMode = st.layout
			applyLayout(nil, layoutMode)
			for _, row in rows do
				applyLayout(row, layoutMode)
			end
		end
		local data = View.positions(st.book, st.prices)
		Style.setText(count, if #data > 0 then Tickers.text("positions_count", { n = #data }) else "")
		flatten.frame.Visible = #data > 0 and env.mode ~= "news"
		flatten.setDisabled(busy or st.cache.phase ~= "open")
		empty.Visible = #data == 0
		colHeader.Visible = #data > 0 and layoutMode == "wide"
		local seen: { [string]: boolean } = {}
		for i, p in data do
			seen[p.ticker] = true
			local existing = rows[p.ticker]
			local fresh = existing == nil
			local r: Row
			if existing then
				r = existing
			else
				r = makeRow(p.ticker)
				rows[p.ticker] = r
				r.frame.Parent = list
			end
			r.frame.LayoutOrder = i
			local sideText = if p.long then "" else " " .. Tickers.text("short")
			Style.setText(r.sub, View.price(p.price) .. sideText, if p.long then "dim" else "warn")
			Style.setText(r.labels.shares, string.format("%d", p.shares), if p.long then "text" else "warn")
			Style.setText(r.labels.avg, View.price(p.avgCost))
			Style.setText(r.labels.last, View.price(p.price))
			Style.setText(r.labels.value, View.money(math.abs(p.value)))
			Style.setText(
				r.labels.pnl,
				View.signedMoney(p.pnl) .. " (" .. View.pct(p.pnlPct, 1) .. ")",
				View.changeColor(p.pnl)
			)
			local overLimit = p.weight > st.limits.concentration + 1e-6
			Style.setText(r.labels.weight, View.plainPct(p.weight, 0), if overLimit then "down" else "dim")
			if fresh or not r.open then
				-- keep what the player is typing; refresh the saved levels otherwise
				r.stopInput.set(levelText(p.stop))
				r.takeInput.set(levelText(p.take))
			end
			r.closeBtn.setDisabled(busy or st.cache.phase ~= "open")
			local hasStops = p.stop ~= nil or p.take ~= nil
			r.stopsBtn.setStyle(if hasStops then "primary" else "ghost")
		end
		for ticker, row in rows do
			if not seen[ticker] then
				row.frame:Destroy()
				rows[ticker] = nil
			end
		end
	end

	return { frame = root :: GuiObject, update = update, tick = nil, destroy = nil }
end

return Positions
