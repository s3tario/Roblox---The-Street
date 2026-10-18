--!strict
-- Terminal part: the watchlist (owned by `market`). STREET 10 first, then the ten tickers: symbol, name, a sparkline
-- of today's path, last price and change. Tap a row to show that name in the quote, facts and ticket (48 px rows).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Style = require(script.Parent.Style)
local View = require(script.Parent.View)
local Env = require(script.Parent.Env)

local Watchlist = {}

local ROW_H = 48
local INDEX = "ST10"

type Row = {
	id: string,
	button: TextButton,
	bar: Frame,
	price: TextLabel,
	pct: TextLabel,
	spark: typeof(Kit.Sparkline(nil :: any)),
	sig: string,
}

local function sparkPoints(path: { number }): { number }
	-- at most ~40 points keeps ten sparklines cheap
	local n = #path
	if n <= 40 then
		return path
	end
	local out: { number } = {}
	for i = 1, 40 do
		out[i] = path[math.floor(1 + (i - 1) * (n - 1) / 39 + 0.5)]
	end
	return out
end

function Watchlist.new(env: Env.Env): Env.Part
	local root = Style.box("Watchlist", { color = "panel", size = UDim2.fromScale(1, 1) })
	local header = Style.row("Header", 30, 8)
	header.Position = UDim2.fromOffset(10, 4)
	header.Size = UDim2.new(1, -20, 0, 30)
	header.Parent = root
	Style.section(Tickers.text("watchlist"), 1).Parent = header

	local scroll = Kit.Scroll({ padding = 4, gap = 2, name = "Rows" })
	scroll.frame.Position = UDim2.fromOffset(0, 36)
	scroll.frame.Size = UDim2.new(1, 0, 1, -40)
	scroll.frame.Parent = root

	local rows: { Row } = {}
	local function makeRow(id: string, title: string, subtitle: string, order: number)
		local b = Instance.new("TextButton")
		b.Name = "Row_" .. id
		b.Text = ""
		b.AutoButtonColor = false
		b.BorderSizePixel = 0
		b.Size = UDim2.new(1, 0, 0, ROW_H)
		b.LayoutOrder = order
		b.BackgroundTransparency = 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = b
		Style.bind(b, function(pal)
			b.BackgroundColor3 = pal.panelAlt
		end)
		local bar = Instance.new("Frame")
		bar.Name = "Selected"
		bar.BorderSizePixel = 0
		bar.Size = UDim2.new(0, 3, 1, -12)
		bar.Position = UDim2.fromOffset(0, 6)
		bar.Visible = false
		bar.Parent = b
		Style.bind(bar, function(pal)
			bar.BackgroundColor3 = pal.accent
		end)
		local left = Kit.frame("Left", UDim2.new(0.38, -8, 1, 0))
		left.Position = UDim2.fromOffset(10, 0)
		left.Parent = b
		local ll = Kit.list(left, false, 0)
		ll.VerticalAlignment = Enum.VerticalAlignment.Center
		Style.text("Symbol", title, { size = "md", font = "bold", order = 1 }).Parent = left
		local sub = Style.text("Name", subtitle, {
			size = "xs",
			color = "dim",
			order = 2,
			autoSize = "none",
			size2 = UDim2.new(1, 0, 0, 14),
			truncate = true,
		})
		sub.Parent = left
		local spark = Kit.Sparkline({ points = {}, size = UDim2.fromOffset(64, 24), name = "Spark" })
		spark.frame.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.frame.Position = UDim2.new(0.5, 0, 0.5, 0)
		spark.frame.Parent = b
		local right = Kit.frame("Right", UDim2.new(0.34, -10, 1, 0))
		right.AnchorPoint = Vector2.new(1, 0)
		right.Position = UDim2.new(1, -10, 0, 0)
		right.Parent = b
		local rl = Kit.list(right, false, 0)
		rl.VerticalAlignment = Enum.VerticalAlignment.Center
		rl.HorizontalAlignment = Enum.HorizontalAlignment.Right
		local price = Style.text("Price", "--", { size = "sm", font = "mono", align = "right", order = 1 })
		price.Parent = right
		local pct =
			Style.text("Change", "--", { size = "xs", font = "mono", align = "right", color = "dim", order = 2 })
		pct.Parent = right
		Kit.connect(b, "Activated", function()
			Kit.sound("click")
			env.actions.select(id)
		end)
		b.Parent = scroll.frame
		table.insert(rows, { id = id, button = b, bar = bar, price = price, pct = pct, spark = spark, sig = "" })
	end

	makeRow(INDEX, Tickers.BENCHMARK.id, Tickers.BENCHMARK.name, 1)
	for i, def in Tickers.list do
		makeRow(def.id, def.id, def.name, i + 1)
	end

	local function update(st: Env.State)
		local cache = st.cache
		for _, row in rows do
			local selected = row.id == st.selected
			row.bar.Visible = selected
			row.button.BackgroundTransparency = if selected then 0.15 else 1
			local price: number?
			local changePct: number?
			local path: { number }
			if row.id == INDEX then
				local idx = cache.index
				price = if cache.indexLevel > 0 then cache.indexLevel else nil
				changePct = if idx.prevClose > 0 and price then price / idx.prevClose - 1 else nil
				path = idx.intraday
			else
				local view = cache.byId[row.id]
				price = st.prices[row.id]
				if view then
					changePct = view.quote.changePct
					path = view.intraday
				else
					path = {}
				end
			end
			Style.setText(
				row.price,
				if price then (if row.id == INDEX then string.format("%.1f", price) else View.price(price)) else "--"
			)
			Style.setText(row.pct, View.pct(changePct), View.changeColor(changePct))
			local sig = #path .. ":" .. tostring(path[#path])
			if sig ~= row.sig then
				row.sig = sig
				row.spark.set(sparkPoints(path))
			end
		end
	end

	return { frame = root, update = update }
end

return Watchlist
