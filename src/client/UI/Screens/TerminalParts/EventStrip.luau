--!strict
-- Terminal part: the status strip across the top (owned by `market`). The session phase (OPEN / AFTER HOURS /
-- CLOSED) with a live countdown to the bell, the market day, the STREET 10 level, and, while a server event runs
-- (crash, boom, Fed day, holiday ...), a coloured strip with its name, what it means and when it ends. Event
-- fairness is spelled out by the event's description; reviews always compare the book to the benchmark.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Format = require(Shared.Util.Format)
local Schedule = require(Shared.Logic.Market.Schedule)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Style = require(script.Parent.Style)
local View = require(script.Parent.View)
local Env = require(script.Parent.Env)

local EventStrip = {}

local ROW_H = 34

local function phaseKey(phase: string): string
	return if phase == "closed" then "phase_closed" elseif phase == "after" then "phase_after" else "phase_open"
end

local function phaseColor(phase: string): string
	return if phase == "closed" then "down" elseif phase == "after" then "warn" else "up"
end

function EventStrip.new(_env: Env.Env): Env.Part
	local root = Style.stack("Status", 4)
	root.Name = "EventStrip"

	-- row 1: phase, countdown, day | ST10
	local row = Kit.frame("Phase", UDim2.new(1, 0, 0, ROW_H))
	row.LayoutOrder = 1
	row.Parent = root
	local left = Kit.frame("Left", UDim2.new(1, -170, 1, 0))
	left.Parent = row
	local ll = Kit.list(left, true, 8)
	ll.VerticalAlignment = Enum.VerticalAlignment.Center
	local pill, pillText = Style.pill("PhasePill", Tickers.text("phase_open"), "up")
	pill.LayoutOrder = 1
	pill.Parent = left
	local countdown = Style.text("Countdown", "", { size = "sm", font = "mono", color = "dim", order = 2 })
	countdown.Parent = left
	local day = Style.text("Day", "", { size = "xs", color = "dim", order = 3 })
	day.Parent = left
	local index = Style.text("Index", "", { size = "sm", font = "mono", align = "right" })
	index.AnchorPoint = Vector2.new(1, 0.5)
	index.Position = UDim2.new(1, 0, 0.5, 0)
	index.Parent = row

	-- row 2: the active event
	local eventBox = Style.box("Event", { color = "panelAlt", autoY = true, pad = 8, order = 2 })
	eventBox.Visible = false
	eventBox.Parent = root
	local eventStack = Style.stack("Stack", 2)
	eventStack.Parent = eventBox
	local head = Style.row("Head", 22, 8)
	head.LayoutOrder = 1
	head.Parent = eventStack
	local livePill, livePillText = Style.pill("Live", Tickers.text("event_active"), "warn")
	livePill.LayoutOrder = 1
	livePill.Parent = head
	local eventName = Style.text("Name", "", { size = "sm", font = "bold", order = 2 })
	eventName.Parent = head
	local eventEnds = Style.text("Ends", "", { size = "xs", font = "mono", color = "dim", order = 3 })
	eventEnds.Parent = head
	local eventDesc = Style.text("Desc", "", {
		size = "xs",
		color = "dim",
		wrap = true,
		autoSize = "y",
		size2 = UDim2.new(1, 0, 0, 0),
		order = 2,
	})
	eventDesc.Parent = eventStack

	local phase = "open"
	local layout = "wide"
	local eventEndsAt: number? = nil

	local function tick(now: number)
		local short = layout == "phone"
		if phase == "closed" then
			Style.setText(countdown, Tickers.text(if short then "phase_closed_short" else "phase_closed_long"))
		elseif phase == "after" or Schedule.phase(now) == "after" then
			local t = Format.clock(Schedule.nextOpenAt(now) - now)
			Style.setText(
				countdown,
				Tickers.text(if short then "phase_after_short" else "phase_after_long", { time = t })
			)
		else
			local t = Format.clock(Schedule.closeAt(now) - now)
			Style.setText(
				countdown,
				Tickers.text(if short then "phase_open_short" else "phase_open_long", { time = t })
			)
		end
		if eventEndsAt then
			Style.setText(eventEnds, Tickers.text("event_ends", { time = Format.clock(eventEndsAt - now) }))
		end
	end

	local function update(st: Env.State)
		local cache = st.cache
		phase = cache.phase
		layout = st.layout
		Style.setPill(pill, pillText, Tickers.text(phaseKey(phase)), phaseColor(phase))
		day.Visible = st.layout == "wide"
		Style.setText(day, if cache.day > 0 then Tickers.text("day_label", { day = cache.day }) else "")
		local level = cache.indexLevel
		local prev = cache.index.prevClose
		local pct = if level > 0 and prev > 0 then level / prev - 1 else nil
		Style.setText(
			index,
			if level > 0
				then Tickers.text("index_line", { level = Format.commas(level, 1), pct = View.pct(pct) })
				else "",
			View.changeColor(pct)
		)
		local ev = View.event(cache.event, st.now)
		eventBox.Visible = ev ~= nil
		if ev then
			Style.setText(eventName, ev.glyph .. "  " .. ev.name)
			Style.setText(eventDesc, ev.desc)
			local tone = View.toneColor(ev.tone)
			Style.setPill(
				livePill,
				livePillText,
				Tickers.text("event_active"),
				if tone == "dim" then "accent" else tone
			)
			eventEndsAt = if ev.secondsLeft > 0 then st.now + ev.secondsLeft else nil
			eventEnds.Visible = eventEndsAt ~= nil
		else
			eventEndsAt = nil
		end
		tick(st.now)
	end

	return { frame = root :: GuiObject, update = update, tick = tick, destroy = nil }
end

return EventStrip
