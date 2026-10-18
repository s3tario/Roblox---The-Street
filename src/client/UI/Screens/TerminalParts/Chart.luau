--!strict
-- Terminal part: the quote header and main chart (owned by `market`). Symbol, name and sector; the last price with
-- its change (and the after-hours move once earnings land); a 1D (today's path against yesterday's close) or 30D
-- (session closes) line chart; bid/ask and the day's range. "ST10" shows the benchmark.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Style = require(script.Parent.Style)
local View = require(script.Parent.View)
local Env = require(script.Parent.Env)

local Chart = {}

local INDEX = "ST10"

function Chart.new(env: Env.Env, height: number?): Env.Part
	local chartH = height or 200
	local root = Style.box("Quote", { color = "panel", autoY = true, pad = 12 })
	local stack = Style.stack("Stack", 6)
	stack.Parent = root

	local top = Style.row("Top", 30, 10)
	top.LayoutOrder = 1
	top.Parent = stack
	local symbol = Style.text("Symbol", "--", { size = "xl", font = "display", order = 1 })
	symbol.Parent = top
	local name = Style.text("Name", "", { size = "sm", color = "dim", order = 2 })
	name.Parent = top
	local sectorPill, sectorText = Style.pill("Sector", "", "panelAlt")
	sectorPill.LayoutOrder = 3
	sectorPill.Parent = top

	local priceRow = Style.row("PriceRow", 40, 12)
	priceRow.LayoutOrder = 2
	priceRow.Parent = stack
	local price = Style.text("Price", "--", { size = "xxl", font = "mono", order = 1 })
	price.Parent = priceRow
	local change = Style.text("Change", "", { size = "md", font = "mono", color = "dim", order = 2 })
	change.Parent = priceRow
	local after = Style.text("After", "", { size = "sm", color = "warn", order = 3 })
	after.Parent = priceRow

	local rangeRow = Style.row("Ranges", 44, 6)
	rangeRow.LayoutOrder = 3
	rangeRow.Parent = stack
	local buttons: { [string]: Kit.Button } = {}
	for i, r in { "1d", "30d" } do
		local b = Kit.Button({
			text = Tickers.text("range_" .. r),
			style = "secondary",
			size = UDim2.fromOffset(64, Kit.TAP),
			textSize = "sm",
			name = "Range_" .. r,
			layoutOrder = i,
			onClick = function()
				env.actions.setRange(r)
			end,
		})
		b.frame.Parent = rangeRow
		buttons[r] = b
	end
	local spacer = Kit.frame("Spacer", UDim2.fromOffset(8, 10))
	spacer.LayoutOrder = 10
	spacer.Parent = rangeRow
	local info = Style.text("Info", "", { size = "xs", color = "dim", order = 11 })
	info.Parent = rangeRow

	local chart = Kit.LineChart({
		series = {},
		size = UDim2.new(1, 0, 0, chartH),
		height = chartH,
		gridLines = 4,
		name = "Chart",
		layoutOrder = 4,
	})
	chart.frame.Parent = stack
	local empty = Style.text("Empty", Tickers.text("chart_empty"), { size = "sm", color = "dim", order = 5 })
	empty.Visible = false
	empty.Parent = stack

	local lastSig = ""

	local function update(st: Env.State)
		local cache = st.cache
		local id = st.selected
		for r, b in buttons do
			b.setStyle(if r == st.range then "primary" else "secondary")
		end
		local points: { number }
		local baseline: number?
		if id == INDEX then
			local idx = cache.index
			Style.setText(symbol, Tickers.BENCHMARK.id)
			Style.setText(name, Tickers.BENCHMARK.name)
			sectorPill.Visible = false
			local level = cache.indexLevel
			local pct = if idx.prevClose > 0 and level > 0 then level / idx.prevClose - 1 else nil
			Style.setText(price, if level > 0 then string.format("%.1f", level) else "--")
			Style.setText(
				change,
				if pct then string.format("%+.1f (%s)", level - idx.prevClose, View.pct(pct)) else "",
				View.changeColor(pct)
			)
			Style.setText(after, "")
			Style.setText(
				info,
				Tickers.text("day_range", { low = string.format("%.1f", idx.low), high = string.format("%.1f", idx.high) })
			)
			points = if st.range == "30d" then table.clone(idx.daily) else table.clone(idx.intraday)
			if st.range == "30d" and level > 0 then
				table.insert(points, level)
			end
			if #points == 0 and level > 0 then
				points = { idx.prevClose, level }
			end
			baseline = if st.range == "1d" and idx.prevClose > 0 then idx.prevClose else nil
		else
			local view = cache.byId[id]
			local def = Tickers.get(id)
			Style.setText(symbol, id)
			Style.setText(name, if def then def.name else id)
			sectorPill.Visible = view ~= nil
			if view then
				Style.setPill(sectorPill, sectorText, view.sectorName, "panelAlt")
			end
			local quote = view and view.quote
			if quote then
				Style.setText(price, View.price(quote.price))
				Style.setText(
					change,
					string.format("%s%s (%s)", if quote.change >= 0 then "+" else "-", View.price(math.abs(quote.change)), View.pct(quote.changePct)),
					View.changeColor(quote.changePct)
				)
				-- after hours, a report moves the price away from the session close
				local ahMove = if quote.close > 0 then quote.price / quote.close - 1 else 0
				if st.cache.phase ~= "open" and math.abs(ahMove) > 0.0005 then
					Style.setText(after, Tickers.text("after_hours", { price = View.price(quote.price), pct = View.pct(ahMove) }))
				else
					Style.setText(after, "")
				end
				Style.setText(
					info,
					Tickers.text("bid_ask", { bid = View.price(quote.bid), ask = View.price(quote.ask) })
						.. "   "
						.. Tickers.text("day_range", { low = View.price(quote.low), high = View.price(quote.high) })
				)
				baseline = if st.range == "1d" then quote.prevClose else nil
			else
				Style.setText(price, "--")
				Style.setText(change, "")
				Style.setText(after, "")
				Style.setText(info, "")
			end
			points = View.series(view, st.range)
		end
		local color = "accent"
		if #points >= 2 then
			color = if points[#points] >= (baseline or points[1]) then "good" else "bad"
		end
		local sig = string.format("%s|%s|%d|%s|%s", id, st.range, #points, tostring(points[#points]), color)
		if sig ~= lastSig then
			lastSig = sig
			chart.set({ { points = points, color = color, thickness = 2 } })
			chart.setBaseline(baseline)
		end
		empty.Visible = #points < 2
	end

	return { frame = root, update = update }
end

return Chart
