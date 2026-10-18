--!strict
-- Terminal part: the earnings calendar (owned by `market`; spec §7). Who reports over the next eight market days,
-- with each consensus once it's published (two days before the report) and Earnings Frenzy reports flagged, plus the
-- announced sector catalyst with its stated odds and the size of the move either way. Tap a day's row to select its
-- first company.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Style = require(script.Parent.Style)
local View = require(script.Parent.View)
local Env = require(script.Parent.Env)

local Calendar = {}

function Calendar.new(env: Env.Env): Env.Part
	local root = Style.box("Calendar", { color = "panel", autoY = true, pad = 12 })
	local stack = Style.stack("Stack", 6)
	stack.Parent = root

	-- catalyst card
	local catalyst = Style.box("Catalyst", { color = "panelAlt", autoY = true, pad = 8, order = 1 })
	catalyst.Visible = false
	catalyst.Parent = stack
	local cs = Style.stack("Stack", 2)
	cs.Parent = catalyst
	local cHead = Style.row("Head", 22, 8)
	cHead.LayoutOrder = 1
	cHead.Parent = cs
	local cPill, cPillText = Style.pill("Tag", Tickers.text("catalyst"), "warn")
	cPill.LayoutOrder = 1
	cPill.Parent = cHead
	local cWhen = Style.text("When", "", { size = "xs", color = "dim", order = 2 })
	cWhen.Parent = cHead
	local cText = Style.text("Text", "", {
		size = "sm",
		wrap = true,
		autoSize = "y",
		size2 = UDim2.new(1, 0, 0, 0),
		order = 2,
	})
	cText.Parent = cs
	local cOdds = Style.text("Odds", "", {
		size = "xs",
		color = "dim",
		wrap = true,
		autoSize = "y",
		size2 = UDim2.new(1, 0, 0, 0),
		order = 3,
	})
	cOdds.Parent = cs

	Style.section(Tickers.text("calendar"), 2).Parent = stack
	local list = Style.stack("Days", 4, 3)
	list.Parent = stack
	local empty = Style.text("Empty", Tickers.text("no_calendar"), { size = "sm", color = "dim", order = 4 })
	empty.Parent = stack

	local rowFrames: { GuiObject } = {}
	local lastSig = ""

	local function update(st: Env.State)
		local cache = st.cache
		local c = cache.catalyst
		local showCatalyst = type(c) == "table" and type(c.text) == "string"
		catalyst.Visible = showCatalyst
		if showCatalyst then
			local cat = c :: { [string]: any }
			Style.setText(cText, cat.text)
			if cat.resolved then
				Style.setPill(cPill, cPillText, Tickers.text("catalyst_done"), if cat.good then "up" else "down")
				Style.setText(cWhen, Tickers.text("day_label", { day = cat.day }))
				cOdds.Visible = false
			else
				Style.setPill(cPill, cPillText, Tickers.text("catalyst"), "warn")
				Style.setText(cWhen, Tickers.text("catalyst_when", { day = cat.day }))
				cOdds.Visible = true
				Style.setText(
					cOdds,
					Tickers.text("catalyst_odds", {
						sector = tostring(cat.sectorName or cat.sector),
						odds = View.plainPct(tonumber(cat.odds) or 0, 0),
						up = View.pct(tonumber(cat.up) or 0, 1),
						down = View.pct(tonumber(cat.down) or 0, 1),
					})
				)
			end
		end

		local rows = View.calendar(cache.calendar)
		local parts: { string } = {}
		for _, r in rows do
			table.insert(parts, r.label .. r.when .. r.tickers .. tostring(r.frenzy))
		end
		local sig = table.concat(parts, ";")
		empty.Visible = #rows == 0
		if sig == lastSig then
			return
		end
		lastSig = sig
		for _, f in rowFrames do
			f:Destroy()
		end
		table.clear(rowFrames)
		for i, r in rows do
			local b = Instance.new("TextButton")
			b.Name = "Day" .. i
			b.Text = ""
			b.AutoButtonColor = false
			b.BorderSizePixel = 0
			b.BackgroundTransparency = if r.inDays <= 0 then 0.1 else 0.5
			b.Size = UDim2.new(1, 0, 0, 0)
			b.AutomaticSize = Enum.AutomaticSize.Y
			b.LayoutOrder = i
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 4)
			corner.Parent = b
			local min = Instance.new("UISizeConstraint")
			min.MinSize = Vector2.new(0, Kit.TAP)
			min.Parent = b
			Style.bind(b, function(pal)
				b.BackgroundColor3 = pal.panelAlt
			end)
			local body = Style.stack("Body", 2)
			body.Parent = b
			Kit.padding(body, 8, 5)
			local head = Style.row("Head", 18, 8)
			head.LayoutOrder = 1
			head.Parent = body
			Style.text("Label", r.label, { size = "sm", font = "bold", order = 1 }).Parent = head
			Style.text("When", r.when, { size = "xs", color = if r.inDays <= 0 then "accent" else "dim", order = 2 }).Parent =
				head
			if r.frenzy then
				local tag, _ = Style.pill("Frenzy", Tickers.text("frenzy_tag"), "warn")
				tag.LayoutOrder = 3
				tag.Parent = head
			end
			Style.text("Tickers", r.tickers, {
				size = "xs",
				font = "mono",
				wrap = true,
				autoSize = "y",
				size2 = UDim2.new(1, 0, 0, 0),
				order = 2,
			}).Parent =
				body
			local first: string? = r.first
			Kit.connect(b, "Activated", function()
				if first then
					Kit.sound("click")
					env.actions.select(first)
				end
			end)
			b.Parent = list
			table.insert(rowFrames, b)
		end
	end

	return { frame = root :: GuiObject, update = update, tick = nil, destroy = nil }
end

return Calendar
