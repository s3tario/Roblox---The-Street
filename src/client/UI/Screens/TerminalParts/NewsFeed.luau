--!strict
-- Terminal part: the news feed (owned by `market`). The server's fictional headlines, newest first: earnings
-- previews and results, sector catalysts, big movers, the closing bell and market events, each with a tone bar and
-- its age. A filter narrows the feed to the selected ticker. Tapping a company headline selects that ticker.
-- The news stand opens the Terminal read-only with this feed in front.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Style = require(script.Parent.Style)
local View = require(script.Parent.View)
local Env = require(script.Parent.Env)

local NewsFeed = {}

local INDEX = "ST10"
local MAX_ROWS = 25

type Row = { frame: GuiObject, age: TextLabel, at: number }

function NewsFeed.new(env: Env.Env, maxRows: number?): Env.Part
	local limit = maxRows or MAX_ROWS
	local root = Style.box("News", { color = "panel", autoY = true, pad = 12 })
	local stack = Style.stack("Stack", 6)
	stack.Parent = root

	local header = Kit.frame("Header", UDim2.new(1, 0, 0, Kit.TAP))
	header.LayoutOrder = 1
	header.Parent = stack
	local title = Style.section(Tickers.text("news"))
	title.AnchorPoint = Vector2.new(0, 0.5)
	title.Position = UDim2.fromScale(0, 0.5)
	title.Parent = header

	local onlySelected = false
	local last: Env.State? = nil
	local update: (st: Env.State) -> ()

	local filter = Kit.Button({
		text = Tickers.text("filter_all"),
		style = "ghost",
		textSize = "xs",
		size = UDim2.fromOffset(120, Kit.TAP),
		name = "Filter",
		onClick = function()
			onlySelected = not onlySelected
			if last then
				update(last)
			end
		end,
	})
	filter.frame.AnchorPoint = Vector2.new(1, 0.5)
	filter.frame.Position = UDim2.new(1, 0, 0.5, 0)
	filter.frame.Parent = header

	local list = Style.stack("Items", 4, 2)
	list.Parent = stack
	local empty = Style.text("Empty", Tickers.text("no_news"), {
		size = "sm",
		color = "dim",
		wrap = true,
		autoSize = "y",
		size2 = UDim2.new(1, 0, 0, 0),
		order = 3,
	})
	empty.Parent = stack

	local rows: { Row } = {}
	local lastSig = ""

	local function makeRow(item: { [string]: any }, order: number, now: number): Row
		local b = Instance.new("TextButton")
		b.Name = "Item" .. order
		b.Text = ""
		b.AutoButtonColor = false
		b.BorderSizePixel = 0
		b.BackgroundTransparency = 0.3
		b.Size = UDim2.new(1, 0, 0, 0)
		b.AutomaticSize = Enum.AutomaticSize.Y
		b.LayoutOrder = order
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = b
		local min = Instance.new("UISizeConstraint")
		min.MinSize = Vector2.new(0, Kit.TAP)
		min.Parent = b
		Style.bind(b, function(pal)
			b.BackgroundColor3 = pal.panelAlt
		end)
		local bar = Instance.new("Frame")
		bar.Name = "Tone"
		bar.BorderSizePixel = 0
		bar.Size = UDim2.new(0, 3, 1, -8)
		bar.Position = UDim2.fromOffset(0, 4)
		bar.Parent = b
		local toneKey = View.toneColor(item.tone)
		Style.bind(bar, function(pal)
			bar.BackgroundColor3 = Style.color(pal, if toneKey == "dim" then "accent" else toneKey)
		end)
		local body = Style.stack("Body", 2)
		body.Position = UDim2.fromOffset(10, 0)
		body.Size = UDim2.new(1, -14, 0, 0)
		body.Parent = b
		Kit.padding(body, 0, 6)
		local headline = Style.text("Headline", tostring(item.headline), {
			size = "sm",
			wrap = true,
			autoSize = "y",
			size2 = UDim2.new(1, 0, 0, 0),
			order = 1,
		})
		headline.Parent = body
		local meta = Style.row("Meta", 16, 6)
		meta.LayoutOrder = 2
		meta.Parent = body
		if type(item.ticker) == "string" then
			local chip, _ = Style.pill("Ticker", item.ticker, "panel")
			chip.LayoutOrder = 1
			chip.Parent = meta
		end
		local day = tonumber(item.day)
		if day then
			Style.text(
				"Day",
				Tickers.text("day_label", { day = math.floor(day) }),
				{ size = "xs", color = "dim", order = 2 }
			).Parent =
				meta
		end
		local at = tonumber(item.at) or now
		local age = Style.text("Age", View.age(at, now), { size = "xs", color = "dim", order = 3 })
		age.Parent = meta
		local ticker = item.ticker
		Kit.connect(b, "Activated", function()
			if type(ticker) == "string" and Tickers.get(ticker) then
				Kit.sound("click")
				env.actions.select(ticker)
			end
		end)
		b.Parent = list
		return { frame = b, age = age, at = at }
	end

	local function tick(now: number)
		for _, r in rows do
			Style.setText(r.age, View.age(r.at, now))
		end
	end

	update = function(st: Env.State)
		last = st
		local ticker = if st.selected ~= INDEX then st.selected else nil
		filter.frame.Visible = ticker ~= nil
		local active = onlySelected and ticker ~= nil
		filter.setText(
			if active then Tickers.text("filter_all") else Tickers.text("filter_ticker", { ticker = ticker or "" })
		)
		local items = View.news(st.cache.news, if active then ticker else nil)
		local first = items[1]
		local sig = string.format(
			"%s|%d|%s",
			if first then tostring(first.id) .. tostring(first.headline) else "",
			#items,
			if active then ticker or "" else ""
		)
		empty.Visible = #items == 0
		if sig ~= lastSig then
			lastSig = sig
			for _, r in rows do
				r.frame:Destroy()
			end
			table.clear(rows)
			for i = 1, math.min(limit, #items) do
				table.insert(rows, makeRow(items[i], i, st.now))
			end
		end
		tick(st.now)
	end

	return { frame = root :: GuiObject, update = update, tick = tick, destroy = nil }
end

return NewsFeed
