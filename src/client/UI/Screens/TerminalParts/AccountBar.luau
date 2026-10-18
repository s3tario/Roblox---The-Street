--!strict
-- Terminal part: the account bar (owned by `market`; design v3 §11). LIVE INVESTED (the market value of open
-- positions, the number the leaderboard shows) leads in gold, then equity, cash, unrealized and session P/L, this
-- review week's return against the STREET 10 (Portfolio.Panel, time-weighted over active time) and the season's
-- Market Skill. Students see their $5,000 paper account flagged as practice money. Phones show the first three
-- cells only; the rest live in the Positions tab's risk panel and the wide layout.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Style = require(script.Parent.Style)
local View = require(script.Parent.View)
local Env = require(script.Parent.Env)

local AccountBar = {}

type Cell = { frame: Frame, key: TextLabel, value: TextLabel, phone: boolean }

local CELLS = {
	{ id = "invested", key = "live_invested", phone = true },
	{ id = "equity", key = "equity", phone = true },
	{ id = "session", key = "session_pnl", phone = true },
	{ id = "cash", key = "cash", phone = false },
	{ id = "unrealized", key = "unrealized", phone = false },
	{ id = "week", key = "week_vs", phone = false },
	{ id = "skill", key = "skill_label", phone = false },
}

function AccountBar.new(_env: Env.Env): Env.Part
	local root = Style.box("Account", { color = "panel", autoY = true, pad = 10 })
	local stack = Style.stack("Stack", 6)
	stack.Parent = root

	local badgeRow = Style.row("Badges", 22, 8)
	badgeRow.LayoutOrder = 1
	badgeRow.Parent = stack
	local badge, badgeText = Style.pill("Mode", Tickers.text("book_badge"), "accent")
	badge.LayoutOrder = 1
	badge.Parent = badgeRow
	local note = Style.text("Note", "", { size = "xs", color = "dim", order = 2 })
	note.Parent = badgeRow

	local grid = Kit.frame("Cells", UDim2.new(1, 0, 0, 0))
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.LayoutOrder = 2
	grid.Parent = stack
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(8, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local cells: { [string]: Cell } = {}
	for i, def in CELLS do
		local f = Kit.frame("Cell_" .. def.id, UDim2.fromScale(1, 1))
		f.LayoutOrder = i
		f.Parent = grid
		Kit.list(f, false, 0)
		local key = Style.text("Key", Tickers.text(def.key), {
			size = "xs",
			font = if def.id == "invested" then "bold" else "body",
			color = if def.id == "invested" then "label" else "dim",
			order = 1,
		})
		key.Parent = f
		local value = Style.text("Value", "--", {
			size = if def.id == "invested" then "lg" else "md",
			font = "mono",
			color = if def.id == "invested" then "accent" else "text",
			order = 2,
			autoSize = "none",
			size2 = UDim2.new(1, 0, 0, 24),
			truncate = true,
		})
		value.Parent = f
		cells[def.id] = { frame = f, key = key, value = value, phone = def.phone }
	end

	local lastLayout = ""

	local function update(st: Env.State)
		if st.layout ~= lastLayout then
			lastLayout = st.layout
			local visible = 0
			for _, def in CELLS do
				local c = cells[def.id]
				c.frame.Visible = st.layout == "wide" or c.phone
				if c.frame.Visible then
					visible += 1
				end
			end
			layout.CellSize = UDim2.new(1 / visible, -8, 0, 42)
		end
		local book = st.book
		local paper = type(book) == "table" and book.paper == true
		Style.setPill(
			badge,
			badgeText,
			Tickers.text(if paper then "paper_badge" else "book_badge"),
			if paper then "warn" else "accent"
		)
		note.Visible = st.layout == "wide"
		if type(book) ~= "table" then
			Style.setText(note, Tickers.text("err_not_loaded"))
			for _, c in cells do
				Style.setText(c.value, "--", "dim")
			end
			return
		end
		Style.setText(
			note,
			if paper
				then Tickers.text("paper_note")
				else Tickers.text("book_size") .. " " .. View.money(tonumber(book.bookSize) or 0)
		)
		local s = View.account(book, st.prices)
		Style.setText(cells.invested.value, View.money(s.invested), "accent")
		Style.setText(cells.equity.value, View.money(s.equity))
		Style.setText(cells.cash.value, View.money(s.cash), if s.cash < 0 then "down" else "text")
		Style.setText(cells.unrealized.value, View.signedMoney(s.unrealized), View.changeColor(s.unrealized))
		Style.setText(cells.session.value, View.signedMoney(s.sessionPnl), View.changeColor(s.sessionPnl))
		local panel = st.panel
		local week = if type(panel) == "table" then panel.week else nil
		if type(week) == "table" and type(week.twr) == "number" then
			local trades = tonumber(week.trades) or 0
			if trades <= 0 and math.abs(week.twr) < 1e-6 then
				Style.setText(cells.week.value, Tickers.text("week_none"), "dim")
			else
				Style.setText(
					cells.week.value,
					Tickers.text("week_value", {
						twr = View.pct(week.twr, 1),
						bench = View.pct(tonumber(week.benchReturn) or 0, 1),
					}),
					View.changeColor(tonumber(week.excess) or 0)
				)
			end
		else
			Style.setText(cells.week.value, "--", "dim")
		end
		local skill = if type(panel) == "table" then panel.skill else nil
		if type(skill) == "number" then
			Style.setText(cells.skill.value, string.format("%d", math.floor(skill)), "text")
		else
			Style.setText(cells.skill.value, Tickers.text("skill_none"), "dim")
		end
	end

	return { frame = root :: GuiObject, update = update, tick = nil, destroy = nil }
end

return AccountBar
