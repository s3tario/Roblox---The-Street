--!strict
-- Terminal part: the order ticket (owned by `market`). Buy / Sell (selling more than you hold opens a short once your
-- rank allows it), a share count with presets (10% / 25% / 50% of the book, Max within the limits, Close the
-- position), optional stop-loss and take-profit, and a live concentration preview computed with the same Ledger
-- rules the server enforces. Market orders only, during the open session. Every order carries a fresh client
-- transaction id (TerminalController), so a retry never fills twice.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Style = require(script.Parent.Style)
local View = require(script.Parent.View)
local Env = require(script.Parent.Env)

local Ticket = {}

local INDEX = "ST10"

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

export type TicketPart = {
	frame: GuiObject,
	update: (state: Env.State) -> (),
	tick: ((now: number) -> ())?,
	destroy: (() -> ())?,
	setSide: (side: string) -> (),
}

function Ticket.new(env: Env.Env): TicketPart
	local root = Style.box("Ticket", { color = "panel", autoY = true, pad = 12 })
	local stack = Style.stack("Stack", 8)
	stack.Parent = root
	Style.section(Tickers.text("ticket"), 1).Parent = stack
	local who = Style.text("Ticker", "", { size = "md", font = "bold", order = 2 })
	who.Parent = stack
	local held = Style.text("Held", "", { size = "xs", color = "dim", order = 3 })
	held.Parent = stack

	local readOnly = Style.text("ReadOnly", Tickers.text("read_only"), {
		size = "sm",
		color = "dim",
		wrap = true,
		autoSize = "y",
		size2 = UDim2.new(1, 0, 0, 0),
		order = 4,
	})
	readOnly.Visible = env.mode == "news"
	readOnly.Parent = stack

	local form = Style.stack("Form", 8, 5)
	form.Visible = env.mode ~= "news"
	form.Parent = stack

	local side = "buy"
	local qty = 0
	local fit = false
	local busy = false
	local status = ""
	local statusColor = "dim"
	local last: Env.State? = nil

	-- side
	local sides = Kit.frame("Sides", UDim2.new(1, 0, 0, Kit.TAP))
	sides.LayoutOrder = 1
	sides.Parent = form
	local buyBtn: Kit.Button
	local sellBtn: Kit.Button
	local update: (st: Env.State) -> ()
	local function rerender()
		if last then
			update(last)
		end
	end
	buyBtn = Kit.Button({
		text = Tickers.text("buy"),
		style = "primary",
		size = UDim2.new(0.5, -4, 0, Kit.TAP),
		name = "Buy",
		onClick = function()
			side = "buy"
			fit = false
			rerender()
		end,
	})
	buyBtn.frame.Parent = sides
	sellBtn = Kit.Button({
		text = Tickers.text("sell"),
		style = "secondary",
		size = UDim2.new(0.5, -4, 0, Kit.TAP),
		name = "Sell",
		onClick = function()
			side = "sell"
			fit = false
			rerender()
		end,
	})
	sellBtn.frame.AnchorPoint = Vector2.new(1, 0)
	sellBtn.frame.Position = UDim2.fromScale(1, 0)
	sellBtn.frame.Parent = sides

	-- quantity
	local qtyRow = Style.row("Qty", Kit.TAP, 8)
	qtyRow.LayoutOrder = 2
	qtyRow.Parent = form
	Style.text("Label", Tickers.text("shares"), { size = "sm", color = "dim", order = 1 }).Parent = qtyRow
	local input = Kit.NumberInput({
		value = 0,
		min = 0,
		max = 10000000,
		step = 1,
		width = 190,
		name = "Shares",
		layoutOrder = 2,
		onChange = function(v: number)
			qty = math.max(0, math.floor(v))
			fit = false
			rerender()
		end,
	})
	input.frame.Parent = qtyRow

	-- presets
	local presets = Kit.frame("Presets", UDim2.new(1, 0, 0, Kit.TAP))
	presets.LayoutOrder = 3
	presets.Parent = form
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.2, -4, 0, Kit.TAP)
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = presets
	for i, preset in View.PRESETS do
		local key = if preset == "p10"
			then "preset_10"
			elseif preset == "p25" then "preset_25"
			elseif preset == "p50" then "preset_50"
			elseif preset == "max" then "preset_max"
			else "preset_close"
		local b = Kit.Button({
			text = Tickers.text(key),
			style = "secondary",
			textSize = "sm",
			name = "Preset_" .. preset,
			layoutOrder = i,
			onClick = function()
				local st = last
				if not st or st.selected == INDEX then
					return
				end
				if preset == "close" then
					local h = View.held(st.book, st.selected)
					if h == 0 then
						return
					end
					side = if h > 0 then "sell" else "buy"
				end
				qty = View.presetQty(st.book, st.prices, st.selected, side, preset, st.limits)
				fit = preset == "max"
				input.set(qty, true)
				rerender()
			end,
		})
		b.frame.Parent = presets
	end

	-- stops
	local stops = Kit.frame("Stops", UDim2.new(1, 0, 0, Kit.TAP))
	stops.LayoutOrder = 4
	stops.Parent = form
	local stopInput = Kit.TextInput({
		placeholder = Tickers.text("stop") .. " (" .. Tickers.text("optional") .. ")",
		maxLength = 12,
		mono = true,
		size = UDim2.new(0.5, -4, 0, Kit.TAP),
		name = "Stop",
		onChange = function()
			rerender()
		end,
	})
	stopInput.frame.Parent = stops
	local takeInput = Kit.TextInput({
		placeholder = Tickers.text("take") .. " (" .. Tickers.text("optional") .. ")",
		maxLength = 12,
		mono = true,
		size = UDim2.new(0.5, -4, 0, Kit.TAP),
		name = "Take",
		onChange = function()
			rerender()
		end,
	})
	takeInput.frame.AnchorPoint = Vector2.new(1, 0)
	takeInput.frame.Position = UDim2.fromScale(1, 0)
	takeInput.frame.Parent = stops

	-- preview
	local concText = Style.text("Concentration", "", {
		size = "xs",
		color = "dim",
		wrap = true,
		autoSize = "y",
		size2 = UDim2.new(1, 0, 0, 0),
		order = 5,
	})
	concText.Parent = form
	local bar = Kit.ProgressBar({ value = 0, height = 8, color = "good", name = "ConcBar", layoutOrder = 6 })
	bar.frame.Parent = form
	local grossText = Style.text("Gross", "", { size = "xs", color = "dim", order = 7 })
	grossText.Parent = form
	local costText = Style.text("Cost", "", { size = "sm", font = "mono", order = 8 })
	costText.Parent = form
	Style.text("Spread", Tickers.text("spread_note"), { size = "xs", color = "dim", order = 9 }).Parent = form

	local place = Kit.Button({
		text = Tickers.text("buy"),
		style = "primary",
		fill = true,
		name = "Place",
		layoutOrder = 10,
		onClick = function()
			local st = last
			if busy or not st or st.selected == INDEX or qty <= 0 then
				return
			end
			local okStop, stop = parseLevel(stopInput.get())
			local okTake, take = parseLevel(takeInput.get())
			if not okStop then
				status, statusColor = Tickers.text("err_bad_stop"), "down"
				rerender()
				return
			end
			if not okTake then
				status, statusColor = Tickers.text("err_bad_take"), "down"
				rerender()
				return
			end
			local order = {
				ticker = st.selected,
				side = side,
				qty = qty,
				fit = fit or nil,
				stop = stop,
				take = take,
			}
			busy = true
			status, statusColor = Tickers.text("placing"), "dim"
			rerender()
			task.spawn(function()
				local ok, ok2, err, payload = pcall(function()
					return env.controller:Trade(order)
				end)
				busy = false
				if ok and ok2 == true then
					local trade = if type(payload) == "table" then payload.trade else nil
					if type(trade) == "table" then
						local q = tonumber(trade.q) or 0
						status = Tickers.text("filled", {
							side = Tickers.text(if q > 0 then "buy" else "sell"),
							qty = math.abs(q),
							ticker = tostring(trade.tk),
							price = View.price(tonumber(trade.px)),
						})
						env.actions.notify(status, "good")
					else
						status = ""
					end
					statusColor = "up"
					qty = 0
					fit = false
					input.set(0, true)
					stopInput.set("")
					takeInput.set("")
				else
					local vars = if ok and type(payload) == "table" then payload.vars else nil
					status = env.controller:ErrorText(if ok then err else "generic", vars)
					statusColor = "down"
					env.actions.notify(status, "warn")
				end
				env.actions.refresh()
			end)
		end,
	})
	place.frame.Parent = form
	local statusLabel = Style.text("Status", "", {
		size = "xs",
		color = "dim",
		wrap = true,
		autoSize = "y",
		size2 = UDim2.new(1, 0, 0, 0),
		order = 11,
	})
	statusLabel.Parent = form

	update = function(st: Env.State)
		last = st
		local isIndex = st.selected == INDEX
		local def = Tickers.get(st.selected)
		Style.setText(
			who,
			if isIndex then Tickers.BENCHMARK.name else st.selected .. " · " .. (if def then def.name else "")
		)
		local h = View.held(st.book, st.selected)
		Style.setText(held, if h ~= 0 then string.format("%s %d", Tickers.text("shares"), h) else "")
		buyBtn.setStyle(if side == "buy" then "primary" else "secondary")
		sellBtn.setStyle(if side == "sell" then "danger" else "secondary")
		local shown = View.side(h, side)
		buyBtn.setText(Tickers.text(if h < 0 then "cover" else "buy"))
		sellBtn.setText(Tickers.text(if h > 0 or not st.limits.short then "sell" else "short"))
		if isIndex then
			Style.setText(concText, Tickers.text("selected_index"), "dim")
			Style.setText(grossText, "")
			Style.setText(costText, "")
			Style.setText(statusLabel, "")
			bar.set(0, true)
			place.setDisabled(true)
			place.setText(Tickers.text("buy"))
			return
		end
		local p = View.preview(st.book, st.prices, st.selected, side, qty, st.limits)
		local ratio = if p.limit > 0 then p.weight / p.limit else 0
		bar.set(math.clamp(ratio, 0, 1), true)
		bar.setColor(if p.err == "concentration" or ratio > 1 then "bad" elseif ratio > 0.8 then "warn" else "good")
		Style.setText(
			concText,
			Tickers.text("conc_preview", {
				ticker = st.selected,
				pct = View.plainPct(p.weight, 1),
				limit = View.plainPct(p.limit, 0),
			}),
			if p.err == "concentration" then "down" else "dim"
		)
		Style.setText(
			grossText,
			Tickers.text(
				"gross_preview",
				{ pct = View.plainPct(p.grossRatio, 0), limit = View.plainPct(p.grossLimit, 0) }
			),
			if p.err == "gross" then "down" else "dim"
		)
		if qty > 0 and p.fill > 0 then
			Style.setText(
				costText,
				if p.cost >= 0
					then Tickers.text("est_cost", { amount = View.money(p.cost, 2) })
					else Tickers.text("est_proceeds", { amount = View.money(-p.cost, 2) })
			)
		else
			Style.setText(costText, "")
		end
		local open = st.cache.phase == "open"
		local key = "place_" .. shown
		if busy then
			place.setText(Tickers.text("placing"))
			place.setDisabled(true)
		elseif not open then
			place.setText(Tickers.text("ticket_closed"))
			place.setDisabled(true)
		else
			place.setText(Tickers.text(key, { qty = qty, ticker = st.selected }))
			place.setDisabled(qty <= 0 or (p.err ~= nil and p.err ~= "bad_qty" and not fit))
		end
		local message = status
		local color = statusColor
		if message == "" and qty > 0 and p.err and p.err ~= "bad_qty" and not fit then
			message = env.controller:ErrorText(p.err, {
				ticker = st.selected,
				pct = View.plainPct(if p.err == "gross" then p.grossRatio else p.weight, 0),
				limit = View.plainPct(if p.err == "gross" then p.grossLimit else p.limit, 0),
			})
			color = "down"
		end
		Style.setText(statusLabel, message, color)
	end

	return {
		frame = root :: GuiObject,
		update = update,
		tick = nil,
		destroy = nil,
		setSide = function(s: string)
			side = if s == "sell" then "sell" else "buy"
			fit = false
			status = ""
			rerender()
		end,
	}
end

return Ticket
