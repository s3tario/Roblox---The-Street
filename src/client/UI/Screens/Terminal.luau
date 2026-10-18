--!strict
-- The Terminal screen (owned by `market`; design v3 §11, spec §7, contracts §6). Opened by a `terminal` prompt, the
-- "Market" menu tab, a `news_stand` prompt (read-only) or TerminalController:Open(args).
--
--   street theme -> a dark, slick trading terminal;  campus theme -> an old student laptop (TerminalParts/Shell)
--   wide screens -> status strip + account bar over three columns;  phones -> tabs (TerminalParts/Layout)
--
-- Parts (TerminalParts/*): watchlist with sparklines, the quote chart (1D / 30D), the fundamentals card, the order
-- ticket with presets and a concentration preview, positions with stops, the account bar with LIVE INVESTED, the
-- risk panel, news, the earnings calendar and the active-event strip. Every part gets the same State on each
-- refresh (market cache, the replicated book, live prices, limits, the review-week panel) and owns its own diffing.
-- Refreshes are coalesced (one per frame) and driven by TerminalController.Changed: 2 s ticks, news, the book,
-- the panel and fresh snapshots. Countdowns tick once a second.
--
-- args = { mode = "trade" | "news", ticker?, tab?, layout? = "wide" | "phone" (forced) }
-- ctx  = UIController ctx; ctx.controller (tests) overrides Registry.get("TerminalController").

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local UIFolder = script.Parent.Parent
local Kit = require(UIFolder:WaitForChild("Kit"))
local Theme = require(UIFolder:WaitForChild("Theme"))
local PartsFolder = script.Parent:WaitForChild("TerminalParts")
local Shell = require(PartsFolder:WaitForChild("Shell"))
local View = require(PartsFolder:WaitForChild("View"))
local Cache = require(PartsFolder:WaitForChild("Cache"))
local Env = require(PartsFolder:WaitForChild("Env"))
local Layout = require(PartsFolder:WaitForChild("Layout"))
local Offline = require(PartsFolder:WaitForChild("Offline"))

local Terminal = { id = "Terminal", hideHud = true }

Terminal.MAX_SIZE = Vector2.new(1320, 860)
Terminal.PANEL_EVERY = 15 -- seconds between review-week panel refreshes while open
-- chrome between the screen container and the shell's screen (window header + padding + bezel), for the first
-- layout guess before the GUI has been laid out
local CHROME_W = 48
local CHROME_H = 120

local function controllerFor(ctx: any): any
	if type(ctx) == "table" and type(ctx.controller) == "table" then
		return ctx.controller
	end
	local registry = if type(ctx) == "table" then ctx.Registry else nil
	if type(registry) == "table" and type(registry.get) == "function" then
		local ok, c = pcall(registry.get, "TerminalController")
		if ok and type(c) == "table" and type(c.GetCache) == "function" then
			return c
		end
	end
	return Offline.new()
end

local function call(controller: any, method: string, ...: any): any
	local fn = controller[method]
	if type(fn) ~= "function" then
		return nil
	end
	local ok, result = pcall(fn, controller, ...)
	if not ok then
		warn(("[Terminal] %s failed: %s"):format(method, tostring(result)))
		return nil
	end
	return result
end

function Terminal.open(args: any, root: Frame, ctx: any): { close: () -> () }
	local a = if type(args) == "table" then args else {}
	local mode = if a.mode == "news" then "news" else "trade"
	local forced: string? = if a.layout == "phone" or a.layout == "wide" then a.layout else nil
	local controller = controllerFor(ctx)
	local ui = if type(ctx) == "table" then ctx.UI else nil
	local closeScreen = if type(ctx) == "table" and type(ctx.close) == "function" then ctx.close else nil

	local selected = View.validSelection(a.ticker) or View.validSelection(call(controller, "GetSelected")) or "APX"
	local range = "1d"
	local tab: string? = if type(a.tab) == "string" then a.tab else nil
	local closed = false
	local conns: { any } = {}

	local function titleText(): string
		if mode == "news" then
			return Tickers.text("title_news")
		end
		return Tickers.text(if Theme.name() == "campus" then "title_laptop" else "title_terminal")
	end
	local function subtitleText(): string
		if mode == "news" then
			return Tickers.text("news_title_hint")
		end
		local s = call(controller, "Subtitle")
		return if type(s) == "string" then s else ""
	end

	local win = Kit.Window({
		title = titleText(),
		subtitle = subtitleText(),
		size = UDim2.fromScale(1, 1),
		maxSize = Terminal.MAX_SIZE,
		onClose = closeScreen,
		padding = 10,
		name = "TerminalWindow",
	})
	win.frame.Parent = root
	local shell = Shell.new(win.content)

	local built: Layout.Built? = nil
	local layoutMode = ""
	local scheduled = false

	local function state(): Env.State
		local cache = call(controller, "GetCache") or Cache.new()
		local book = call(controller, "GetBook")
		local limits = call(controller, "GetLimits") or View.limits(book)
		local now = call(controller, "Now")
		local short = call(controller, "ShortTitle")
		return {
			cache = cache,
			book = book,
			prices = Cache.prices(cache),
			now = if type(now) == "number" then now else 0,
			selected = selected,
			range = range,
			limits = limits,
			panel = call(controller, "GetPanel"),
			mode = mode,
			layout = layoutMode,
			shortTitle = if type(short) == "string" then short else Tickers.text("short_title_default"),
		}
	end

	local function refreshNow()
		local b = built
		if closed or not b then
			return
		end
		local st = state()
		for _, part in b.parts do
			local ok, err = pcall(part.update :: any, st)
			if not ok then
				warn("[Terminal] part update failed: " .. tostring(err))
			end
		end
	end

	-- one refresh per frame however many signals arrive
	local function refresh()
		if scheduled or closed then
			return
		end
		scheduled = true
		task.defer(function()
			scheduled = false
			refreshNow()
		end)
	end

	local actions: Env.Actions
	local function rebuild(newMode: string)
		local old = built
		if old then
			tab = old.tab() or tab
			old.destroy()
		end
		layoutMode = newMode
		local env: Env.Env = {
			controller = controller,
			ui = ui,
			actions = actions,
			mode = mode,
			layout = newMode,
		}
		local ok, result = pcall(Layout.build, shell.screen, env, tab)
		if ok then
			built = result
		else
			built = nil
			warn("[Terminal] layout failed: " .. tostring(result))
		end
		refreshNow()
	end

	actions = {
		select = function(id: string)
			local valid = View.validSelection(id)
			if not valid then
				return
			end
			selected = valid
			call(controller, "SetSelected", valid)
			local b = built
			if b and layoutMode == "phone" and b.tab() == "market" then
				b.setTab("quote")
			end
			refresh()
		end,
		setRange = function(r: string)
			if r == "1d" or r == "30d" then
				range = r
				refresh()
			end
		end,
		setTab = function(id: string)
			local b = built
			if b then
				b.setTab(id)
			end
		end,
		trade = function(side: string)
			local b = built
			if not b then
				return
			end
			if b.ticket then
				b.ticket.setSide(side)
			end
			if layoutMode == "phone" then
				b.setTab("trade")
			end
		end,
		notify = function(text: string, kind: string?)
			if type(ui) == "table" and type(ui.Notify) == "function" then
				pcall(ui.Notify, ui, text, kind)
			end
		end,
		refresh = function()
			call(controller, "RefreshPanel", true)
			refresh()
		end,
		confirm = function(opts: { [string]: any }, callback: (ok: boolean) -> ())
			if type(ui) == "table" and type(ui.Confirm) == "function" then
				ui:Confirm(opts, callback)
			else
				Kit.Confirm(opts :: any, callback)
			end
		end,
	}

	-- wide or phone: measured from the shell's screen once laid out, estimated from the container before that
	local function measure(): string
		if forced then
			return forced
		end
		local size = Kit.unscaledSize(shell.screen)
		if size then
			return View.layoutMode(size.X, size.Y)
		end
		local outer = Kit.unscaledSize(root)
		if outer then
			local w = math.min(outer.X, Terminal.MAX_SIZE.X) - CHROME_W
			local h = math.min(outer.Y, Terminal.MAX_SIZE.Y) - CHROME_H
			return View.layoutMode(w, h)
		end
		return if layoutMode ~= "" then layoutMode else "wide"
	end

	rebuild(measure())

	local sizeConn = Kit.propChanged(shell.screen, "AbsoluteSize", function()
		if closed then
			return
		end
		local m = measure()
		if m ~= layoutMode then
			rebuild(m)
		end
	end)
	if sizeConn then
		table.insert(conns, sizeConn)
	end

	local changed = controller.Changed
	if type(changed) == "table" and type(changed.Connect) == "function" then
		table.insert(
			conns,
			changed:Connect(function(kind: string?)
				if closed then
					return
				end
				if kind == "book" or kind == "career" then
					win.setSubtitle(subtitleText())
				end
				refresh()
			end)
		)
	end
	table.insert(
		conns,
		Theme.Changed:Connect(function()
			if not closed then
				win.setTitle(titleText())
				win.setSubtitle(subtitleText())
				refresh()
			end
		end)
	)

	local sincePanel = 0
	local stopTicker = Kit.everySecond(function()
		local b = built
		if closed or not b then
			return
		end
		local now = call(controller, "Now")
		if type(now) == "number" then
			for _, part in b.parts do
				local tick = part.tick
				if tick then
					local ok, err = pcall(tick :: any, now)
					if not ok then
						warn("[Terminal] part tick failed: " .. tostring(err))
					end
				end
			end
		end
		sincePanel += 1
		if sincePanel >= Terminal.PANEL_EVERY then
			sincePanel = 0
			call(controller, "RefreshPanel", false)
		end
	end)

	-- fresh data for this visit (both calls are throttled and never yield)
	call(controller, "RequestSnapshot", false)
	call(controller, "RefreshPanel", false)
	call(controller, "NoteOpen", mode)

	return {
		close = function()
			if closed then
				return
			end
			closed = true
			call(controller, "NoteClosed")
			stopTicker()
			for _, c in conns do
				pcall(function()
					c:Disconnect()
				end)
			end
			table.clear(conns)
			local b = built
			built = nil
			if b then
				pcall(b.destroy)
			end
			win.close()
		end,
	}
end

return Terminal
