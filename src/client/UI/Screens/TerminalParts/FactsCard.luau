--!strict
-- Terminal part: the fundamentals card (owned by `market`). Disclosed facts for the selected company with live ratios
-- (Shared/Logic/Market/Facts.derive on the latest price): market cap, P/E, EPS, revenue, EBITDA, margins, EV/EBITDA,
-- net debt, dividend, beta, the analyst target, and the earnings schedule (consensus once published, the last report).
-- For the STREET 10 it explains the benchmark and lists the biggest weights.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Facts = require(Shared.Logic.Market.Facts)
local Format = require(Shared.Util.Format)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Style = require(script.Parent.Style)
local View = require(script.Parent.View)
local Env = require(script.Parent.Env)

local FactsCard = {}

local INDEX = "ST10"
local KEYS = {
	"fact_mcap",
	"fact_pe",
	"fact_eps",
	"fact_rev",
	"fact_ebitda",
	"fact_margin",
	"fact_ev",
	"fact_debt",
	"fact_div",
	"fact_beta",
	"fact_target",
	"fact_next",
	"fact_cons",
	"fact_last",
}

function FactsCard.new(_env: Env.Env, columns: number?): Env.Part
	local cols = columns or 2
	local root = Style.box("Facts", { color = "panel", autoY = true, pad = 12 })
	local stack = Style.stack("Stack", 8)
	stack.Parent = root
	Style.section(Tickers.text("facts"), 1).Parent = stack
	local desc = Style.text("Desc", "", {
		size = "xs",
		color = "dim",
		wrap = true,
		autoSize = "y",
		size2 = UDim2.new(1, 0, 0, 0),
		order = 2,
	})
	desc.Parent = stack

	local grid = Kit.frame("Grid", UDim2.new(1, 0, 0, 0))
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.LayoutOrder = 3
	grid.Parent = stack
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / cols, -6, 0, 34)
	layout.CellPadding = UDim2.fromOffset(6, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local indexInfo = Style.stack("Index", 4, 4)
	indexInfo.Visible = false
	indexInfo.Parent = stack
	local indexChange = Style.text("Change30", "", { size = "sm", font = "mono", order = 1 })
	indexChange.Parent = indexInfo
	local indexCap = Style.text("Cap", "", { size = "sm", font = "mono", order = 2 })
	indexCap.Parent = indexInfo
	local indexWeights = Style.text("Weights", "", {
		size = "sm",
		wrap = true,
		autoSize = "y",
		size2 = UDim2.new(1, 0, 0, 0),
		order = 3,
	})
	indexWeights.Parent = indexInfo

	local cells: { [string]: { frame: Frame, value: TextLabel } } = {}
	for i, key in KEYS do
		local cell = Kit.frame("Cell_" .. key, UDim2.fromScale(1, 1))
		cell.LayoutOrder = i
		cell.Parent = grid
		Kit.list(cell, false, 0)
		Style.text("Key", Tickers.text(key), { size = "xs", color = "dim", order = 1 }).Parent = cell
		local value = Style.text("Value", "--", {
			size = "sm",
			font = "mono",
			order = 2,
			autoSize = "none",
			size2 = UDim2.new(1, 0, 0, 18),
			truncate = true,
		})
		value.Parent = cell
		cells[key] = { frame = cell, value = value }
	end

	local function set(key: string, text: string, color: string?)
		local c = cells[key]
		if c then
			c.frame.Visible = true
			Style.setText(c.value, text, color or "text")
		end
	end

	local function update(st: Env.State)
		local cache = st.cache
		local isIndex = st.selected == INDEX
		grid.Visible = not isIndex
		indexInfo.Visible = isIndex
		if isIndex then
			Style.setText(desc, Tickers.text("index_desc"))
			local caps: { { id: string, cap: number } } = {}
			local total = 0
			for _, view in cache.tickers do
				local def = Tickers.get(view.id)
				if def then
					local cap = def.shares * (st.prices[view.id] or view.quote.price)
					total += cap
					table.insert(caps, { id = view.id, cap = cap })
				end
			end
			table.sort(caps, function(a, b)
				return a.cap > b.cap
			end)
			local first = cache.index.daily[1]
			local change30 = if first and first > 0 and cache.indexLevel > 0 then cache.indexLevel / first - 1 else nil
			Style.setText(
				indexChange,
				Tickers.text("index_change30", { pct = View.pct(change30) }),
				View.changeColor(change30)
			)
			local top: { string } = {}
			for i = 1, math.min(3, #caps) do
				table.insert(top, caps[i].id .. " " .. View.plainPct(caps[i].cap / math.max(total, 1), 1))
			end
			Style.setText(indexWeights, Tickers.text("index_weights", { list = table.concat(top, ", ") }))
			Style.setText(indexCap, Tickers.text("index_cap", { cap = View.millions(total) }))
			return
		end
		local view = cache.byId[st.selected]
		local fund = if view then view.fund else nil
		if not view or type(fund) ~= "table" then
			Style.setText(desc, Tickers.text("loading"))
			for _, c in cells do
				Style.setText(c.value, "--", "dim")
			end
			return
		end
		Style.setText(desc, if type(fund.desc) == "string" then fund.desc else "")
		local price = st.prices[view.id] or view.quote.price
		local ok, f = pcall(Facts.derive, fund :: any, price)
		if not ok or type(f) ~= "table" then
			return
		end
		set("fact_mcap", View.millions(f.marketCap))
		set("fact_pe", if f.pe then string.format("%.1fx", f.pe) else "--")
		set("fact_eps", Format.money(f.eps, 2))
		set("fact_rev", View.millions(f.revenue))
		set("fact_ebitda", View.millions(f.ebitda))
		set("fact_margin", View.plainPct(f.netMargin, 1))
		set("fact_ev", if f.evEbitda then string.format("%.1fx", f.evEbitda) else "--")
		set("fact_debt", View.millions(f.netDebt))
		set("fact_div", if f.dividendYield > 0 then View.plainPct(f.dividendYield, 1) else "--")
		set("fact_beta", string.format("%.2f", f.beta))
		set(
			"fact_target",
			string.format("%s (%s)", View.price(f.target), View.pct(f.upside, 1)),
			View.changeColor(f.upside)
		)
		local nxt = view.next
		if type(nxt) == "table" then
			local inDays = math.floor(tonumber(nxt.inDays) or 0)
			set(
				"fact_next",
				if inDays <= 0
					then Tickers.text("fact_next_today")
					else Tickers.text("fact_next_value", { day = nxt.day, days = inDays }),
				if nxt.frenzy then "warn" else "text"
			)
			set(
				"fact_cons",
				if type(nxt.consensus) == "number"
					then Format.money(nxt.consensus, 2)
					else Tickers.text("fact_cons_pending"),
				if type(nxt.consensus) == "number" then "text" else "dim"
			)
		end
		local last = view.last
		if type(last) == "table" and type(last.eps) == "number" then
			local result = if type(last.result) == "string" then last.result else "inline"
			set(
				"fact_last",
				Tickers.text("fact_last_value", {
					eps = Format.money(last.eps, 2),
					cons = Format.money(tonumber(last.consensus) or 0, 2),
					result = Tickers.text("result_" .. result),
				}),
				if result == "beat" then "up" elseif result == "miss" then "down" else "text"
			)
		else
			set("fact_last", "--", "dim")
		end
	end

	return { frame = root, update = update }
end

return FactsCard
