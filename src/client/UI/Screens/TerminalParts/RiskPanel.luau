--!strict
-- Terminal part: the risk panel (owned by `market`; spec §6-§7). The player's current limits (single-name
-- concentration, gross exposure, shorting by rank), the probation multiplier and Risk Sense headroom when they apply,
-- this week's violations out of the three that make a major breach, the drawdown from the book's peak, and every
-- live breach with the time left to fix it before the risk desk logs a violation and trims the position.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Format = require(Shared.Util.Format)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Style = require(script.Parent.Style)
local View = require(script.Parent.View)
local Env = require(script.Parent.Env)

local RiskPanel = {}

local MAX_PIPS = 3

type Breach = { frame: Frame, text: TextLabel, timer: TextLabel, deadline: number }

function RiskPanel.new(_env: Env.Env): Env.Part
	local root = Style.box("Risk", { color = "panel", autoY = true, pad = 12 })
	local stack = Style.stack("Stack", 6)
	stack.Parent = root
	Style.section(Tickers.text("risk"), 1).Parent = stack

	local limitsBox = Style.stack("Limits", 2, 2)
	limitsBox.Parent = stack
	local limitRows: { { key: TextLabel, value: TextLabel } } = {}
	for i = 1, 3 do
		local row = Kit.frame("Limit" .. i, UDim2.new(1, 0, 0, 22))
		row.LayoutOrder = i
		row.Parent = limitsBox
		local key = Style.text("Key", "", { size = "xs", color = "dim" })
		key.AnchorPoint = Vector2.new(0, 0.5)
		key.Position = UDim2.fromScale(0, 0.5)
		key.Parent = row
		local value = Style.text("Value", "", { size = "sm", font = "mono", align = "right" })
		value.AnchorPoint = Vector2.new(1, 0.5)
		value.Position = UDim2.fromScale(1, 0.5)
		value.Parent = row
		table.insert(limitRows, { key = key, value = value })
	end
	local probation = Style.text("Probation", "", { size = "xs", font = "bold", color = "warn", order = 3 })
	probation.Parent = stack
	local headroom = Style.text("Headroom", "", { size = "xs", color = "dim", order = 4 })
	headroom.Parent = stack

	-- violations this week: n of 3 pips
	local vRow = Kit.frame("Violations", UDim2.new(1, 0, 0, 22))
	vRow.LayoutOrder = 5
	vRow.Parent = stack
	local vText = Style.text("Text", Tickers.text("violations_label"), { size = "xs", color = "dim" })
	vText.AnchorPoint = Vector2.new(0, 0.5)
	vText.Position = UDim2.fromScale(0, 0.5)
	vText.Parent = vRow
	local pipsFrame = Kit.frame("Pips", UDim2.fromOffset(MAX_PIPS * 18, 14))
	pipsFrame.AnchorPoint = Vector2.new(1, 0.5)
	pipsFrame.Position = UDim2.fromScale(1, 0.5)
	pipsFrame.Parent = vRow
	Kit.list(pipsFrame, true, 4)
	local pips: { Frame } = {}
	for i = 1, MAX_PIPS do
		local p = Style.box("Pip" .. i, { color = "panelAlt", size = UDim2.fromOffset(14, 14), radius = 3 })
		p.LayoutOrder = i
		p.Parent = pipsFrame
		pips[i] = p
	end

	local ddRow = Kit.frame("Drawdown", UDim2.new(1, 0, 0, 22))
	ddRow.LayoutOrder = 6
	ddRow.Parent = stack
	local ddKey = Style.text("Key", Tickers.text("drawdown"), { size = "xs", color = "dim" })
	ddKey.AnchorPoint = Vector2.new(0, 0.5)
	ddKey.Position = UDim2.fromScale(0, 0.5)
	ddKey.Parent = ddRow
	local ddValue = Style.text("Value", "--", { size = "sm", font = "mono", align = "right" })
	ddValue.AnchorPoint = Vector2.new(1, 0.5)
	ddValue.Position = UDim2.fromScale(1, 0.5)
	ddValue.Parent = ddRow

	Style.hline("Line", 7).Parent = stack
	local clear = Style.text("Clear", Tickers.text("no_breaches"), { size = "sm", color = "up", order = 8 })
	clear.Parent = stack
	local breachList = Style.stack("Breaches", 4, 9)
	breachList.Parent = stack

	local breaches: { Breach } = {}
	local lastSig = ""

	local function tick(now: number)
		for _, b in breaches do
			local left = math.max(0, b.deadline - now)
			Style.setText(
				b.timer,
				Tickers.text("breach_deadline", { time = Format.clock(left) }),
				if left < 15 then "down" else "warn"
			)
		end
	end

	local function update(st: Env.State)
		local limits = st.limits
		for i, r in View.limitRows(limits, st.shortTitle) do
			local row = limitRows[i]
			if row then
				Style.setText(row.key, r.key)
				Style.setText(row.value, r.value)
			end
		end
		probation.Visible = limits.mult < 1
		Style.setText(probation, Tickers.text("risk_mult", { mult = limits.mult }))
		headroom.Visible = limits.headroom > 0
		Style.setText(headroom, Tickers.text("risk_headroom", { pct = View.plainPct(limits.headroom, 1) }))

		local book = st.book
		local risk = if type(book) == "table" then book.risk else nil
		local count = if type(risk) == "table" then math.floor(tonumber(risk.weekViolations) or 0) else 0
		for i, p in pips do
			Style.setBg(p, if i <= count then (if count >= MAX_PIPS then "down" else "warn") else "panelAlt")
		end
		Style.setText(vText, Tickers.text("violations_label") .. string.format("  %d / %d", count, MAX_PIPS))

		local summary = View.account(book, st.prices)
		Style.setText(
			ddValue,
			View.plainPct(summary.drawdown, 1),
			if summary.drawdown >= 0.1 then "down" elseif summary.drawdown >= 0.03 then "warn" else "text"
		)

		local rows = View.breaches(risk, st.now)
		local sig = ""
		for _, r in rows do
			sig ..= r.text .. "|" .. tostring(math.floor(r.deadline)) .. ";"
		end
		clear.Visible = #rows == 0
		if sig ~= lastSig then
			lastSig = sig
			for _, b in breaches do
				b.frame:Destroy()
			end
			table.clear(breaches)
			for i, r in rows do
				local f = Style.box("Breach" .. i, { color = "panelAlt", autoY = true, pad = 8, order = i })
				f.Parent = breachList
				local s = Style.stack("Stack", 2)
				s.Parent = f
				local text = Style.text("Text", r.text, {
					size = "xs",
					color = "down",
					wrap = true,
					autoSize = "y",
					size2 = UDim2.new(1, 0, 0, 0),
					order = 1,
				})
				text.Parent = s
				local timer = Style.text("Timer", "", { size = "xs", font = "mono", color = "warn", order = 2 })
				timer.Parent = s
				table.insert(breaches, { frame = f, text = text, timer = timer, deadline = r.deadline })
			end
		end
		tick(st.now)
	end

	return { frame = root :: GuiObject, update = update, tick = tick, destroy = nil }
end

return RiskPanel
