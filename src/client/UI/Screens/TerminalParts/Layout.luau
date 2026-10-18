--!strict
-- Terminal layouts (owned by `market`): place the parts on the Shell's screen.
--
--   wide  (desktop, tablet): the status strip and account bar across the top, then three columns:
--         watchlist | quote chart, positions, fundamentals, news | order ticket, risk, earnings calendar
--   phone (narrow or short screens): the status strip, a tab row and one page at a time (44 px tap targets):
--         Market (watchlist) · Quote (chart + fundamentals) · Trade (account + ticket) · Positions (+ risk) · News
-- The news stand (mode "news") is read-only: news first, no account, positions or risk panels.
--
--   Layout.build(parent, env, tab?) -> Built
--   Built = { parts, ticket?, tab() -> string?, setTab(id), tabs, destroy() }
--   Layout.tabsFor(mode) -> { tabId }      Layout.defaultTab(mode) -> tabId

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Style = require(script.Parent.Style)
local Env = require(script.Parent.Env)
local Watchlist = require(script.Parent.Watchlist)
local Chart = require(script.Parent.Chart)
local FactsCard = require(script.Parent.FactsCard)
local Ticket = require(script.Parent.Ticket)
local Positions = require(script.Parent.Positions)
local AccountBar = require(script.Parent.AccountBar)
local RiskPanel = require(script.Parent.RiskPanel)
local NewsFeed = require(script.Parent.NewsFeed)
local Calendar = require(script.Parent.Calendar)
local EventStrip = require(script.Parent.EventStrip)

type Scroll = typeof(Kit.Scroll())
type Tabs = typeof(Kit.Tabs())
type TabDef = { id: string, title: string, badge: string? }

export type Built = {
	parts: { Env.Part },
	ticket: Ticket.TicketPart?,
	tab: () -> string?,
	setTab: (id: string) -> (),
	tabs: { string },
	destroy: () -> (),
}

local Layout = {}

Layout.GAP = 8
Layout.TABS_TRADE = { "market", "quote", "trade", "positions", "news" }
Layout.TABS_NEWS = { "news", "market", "quote", "calendar" }
-- top-area heights used before the first layout pass (and under Lune)
Layout.TOP_WIDE = 110
Layout.TOP_PHONE = 86

function Layout.tabsFor(mode: string): { string }
	return if mode == "news" then Layout.TABS_NEWS else Layout.TABS_TRADE
end

function Layout.defaultTab(mode: string): string
	return Layout.tabsFor(mode)[1]
end

-- Keeps `body` filling the space under `top` (whose height is automatic).
local function fillBelow(top: GuiObject, body: GuiObject, fallback: number)
	local function place()
		local size = Kit.unscaledSize(top)
		local h = if size then size.Y else fallback
		body.Position = UDim2.fromOffset(0, h + Layout.GAP)
		body.Size = UDim2.new(1, 0, 1, -(h + Layout.GAP))
	end
	place()
	Kit.propChanged(top, "AbsoluteSize", place)
end

local function column(name: string, x: number, xOffset: number, w: number, wOffset: number): Scroll
	local scroll = Kit.Scroll({ name = name, gap = Layout.GAP, padding = 0 })
	scroll.frame.Position = UDim2.new(x, xOffset, 0, 0)
	scroll.frame.Size = UDim2.new(w, wOffset, 1, 0)
	return scroll
end

local function add(scroll: Scroll, part: Env.Part, order: number, parts: { Env.Part })
	part.frame.LayoutOrder = order
	part.frame.Parent = scroll.frame
	table.insert(parts, part)
end

---------------------------------------------------------------------------------------------------
-- Wide
---------------------------------------------------------------------------------------------------
local function buildWide(parent: Instance, env: Env.Env): Built
	local root = Kit.frame("Wide", UDim2.fromScale(1, 1))
	root.Parent = parent
	local parts: { Env.Part } = {}
	local news = env.mode == "news"

	local top = Style.stack("Top", 6)
	top.Parent = root
	local strip = EventStrip.new(env)
	strip.frame.LayoutOrder = 1
	strip.frame.Parent = top
	table.insert(parts, strip)
	if not news then
		local account = AccountBar.new(env)
		account.frame.LayoutOrder = 2
		account.frame.Parent = top
		table.insert(parts, account)
	end

	local body = Kit.frame("Body", UDim2.fromScale(1, 1))
	body.Parent = root
	fillBelow(top, body, if news then 40 else Layout.TOP_WIDE)

	local left = Kit.frame("Left", UDim2.new(0.25, -4, 1, 0))
	left.Parent = body
	local watch = Watchlist.new(env)
	watch.frame.Parent = left
	table.insert(parts, watch)

	local center = column("Center", 0.25, 4, 0.43, -8)
	center.frame.Parent = body
	local right = column("Right", 0.68, 4, 0.32, -4)
	right.frame.Parent = body

	local ticket = Ticket.new(env)
	if news then
		add(center, NewsFeed.new(env), 1, parts)
		add(center, Chart.new(env, 200), 2, parts)
		add(center, FactsCard.new(env, 2), 3, parts)
		add(right, Calendar.new(env), 1, parts)
		add(right, ticket, 2, parts)
	else
		add(center, Chart.new(env, 200), 1, parts)
		add(center, Positions.new(env), 2, parts)
		add(center, FactsCard.new(env, 2), 3, parts)
		add(center, NewsFeed.new(env), 4, parts)
		add(right, ticket, 1, parts)
		add(right, RiskPanel.new(env), 2, parts)
		add(right, Calendar.new(env), 3, parts)
	end

	return {
		parts = parts,
		ticket = ticket,
		tab = function(): string?
			return nil
		end,
		setTab = function(_id: string) end,
		tabs = {},
		destroy = function()
			for _, p in parts do
				if p.destroy then
					pcall(p.destroy)
				end
			end
			root:Destroy()
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- Phone
---------------------------------------------------------------------------------------------------
local function buildPhone(parent: Instance, env: Env.Env, initialTab: string?): Built
	local root = Kit.frame("Phone", UDim2.fromScale(1, 1))
	root.Parent = parent
	local parts: { Env.Part } = {}
	local news = env.mode == "news"
	local ids = Layout.tabsFor(env.mode)
	local current = if initialTab and table.find(ids, initialTab) then initialTab else ids[1]

	local top = Style.stack("Top", 4)
	top.Parent = root
	local strip = EventStrip.new(env)
	strip.frame.LayoutOrder = 1
	strip.frame.Parent = top
	table.insert(parts, strip)

	local pages: { [string]: GuiObject } = {}
	local tabs: Tabs
	local function show(id: string)
		if not pages[id] then
			return
		end
		current = id
		for pid, page in pages do
			page.Visible = pid == id
		end
		if tabs.getSelected() ~= id then
			tabs.select(id, true)
		end
	end
	local defs: { TabDef } = {}
	for _, id in ids do
		table.insert(defs, { id = id, title = Tickers.text("tab_" .. id) })
	end
	tabs = Kit.Tabs({
		tabs = defs,
		selected = current,
		name = "Tabs",
		layoutOrder = 2,
		onSelect = function(id: string)
			show(id)
		end,
	})
	tabs.frame.Parent = top

	local body = Kit.frame("Body", UDim2.fromScale(1, 1))
	body.Parent = root
	fillBelow(top, body, Layout.TOP_PHONE)

	local function scrollPage(id: string): Scroll
		local scroll = Kit.Scroll({ name = "Page_" .. id, gap = Layout.GAP, padding = 0 })
		scroll.frame.Parent = body
		pages[id] = scroll.frame
		return scroll
	end

	-- the market page is the watchlist itself (it scrolls on its own)
	local marketPage = Kit.frame("Page_market", UDim2.fromScale(1, 1))
	marketPage.Parent = body
	pages.market = marketPage
	local watch = Watchlist.new(env)
	watch.frame.Parent = marketPage
	table.insert(parts, watch)

	local quote = scrollPage("quote")
	add(quote, Chart.new(env, 150), 1, parts)
	add(quote, FactsCard.new(env, 2), 2, parts)

	local ticket: Ticket.TicketPart? = nil
	if news then
		add(scrollPage("news"), NewsFeed.new(env), 1, parts)
		add(scrollPage("calendar"), Calendar.new(env), 1, parts)
	else
		local trade = scrollPage("trade")
		add(trade, AccountBar.new(env), 1, parts)
		local t = Ticket.new(env)
		add(trade, t, 2, parts)
		ticket = t
		local positions = scrollPage("positions")
		add(positions, Positions.new(env), 1, parts)
		add(positions, RiskPanel.new(env), 2, parts)
		local feed = scrollPage("news")
		add(feed, NewsFeed.new(env), 1, parts)
		add(feed, Calendar.new(env), 2, parts)
	end
	show(current)

	return {
		parts = parts,
		ticket = ticket,
		tab = function(): string?
			return current
		end,
		setTab = function(id: string)
			show(id)
		end,
		tabs = ids,
		destroy = function()
			for _, p in parts do
				if p.destroy then
					pcall(p.destroy)
				end
			end
			root:Destroy()
		end,
	}
end

function Layout.build(parent: Instance, env: Env.Env, tab: string?): Built
	if env.layout == "phone" then
		return buildPhone(parent, env, tab)
	end
	return buildWide(parent, env)
end

return Layout
