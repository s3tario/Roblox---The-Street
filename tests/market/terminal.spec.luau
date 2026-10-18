-- The Terminal's client side: the view model (layout choice, previews, presets, limits, visitors' prompts), the
-- market cache fed by real server snapshots and ticks (nothing hidden crosses over, dropped and late ticks are
-- harmless, a new day or event marks it stale), and the screen itself opening in both themes and both layouts.
local Shared = game:GetService("ReplicatedStorage").Shared
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Model = require(Shared.Logic.Market.Model)
local Ledger = require(Shared.Logic.Portfolio.Ledger)
local Tickers = require(Shared.Config.Tickers)
local Signal = require(Shared.Util.Signal)
local Time = require(Shared.Util.Time)
local Theme = require(Client.UI.Theme)
local Terminal = require(Client.UI.Screens.Terminal)
local Parts = Client.UI.Screens.TerminalParts
local View = require(Parts.View)
local Cache = require(Parts.Cache)
local Layout = require(Parts.Layout)

local DAY = Time.DAY_LEN
local T0 = Time.SEASON_EPOCH + 1000 * DAY -- the open of a market day

local function step(state, from: number, to: number)
	for t = from, to, Time.TICK do
		Model.step(state, t)
	end
end

local function loadedCache(state, now: number)
	local cache = Cache.new()
	Cache.applySnapshot(cache, Model.snapshot(state, now))
	return cache
end

local function hasKey(v: any, key: string, depth: number?): boolean
	if type(v) ~= "table" or (depth or 0) > 8 then
		return false
	end
	for k, x in v do
		if k == key or hasKey(x, key, (depth or 0) + 1) then
			return true
		end
	end
	return false
end

local function bookWith(cash: number, positions: { [string]: { shares: number, avgCost: number } }, rank: number?)
	local b = Ledger.new(cash, false)
	b.positions = positions
	b.limits = Ledger.limits({ rank = rank or 1 })
	return b
end

local function fakeController(cache, book, now: number)
	local c = {
		Changed = Signal.new(),
		trades = {},
		selected = "APX",
		snapshots = 0,
		panels = 0,
	}
	function c:GetCache()
		return cache
	end
	function c:Now()
		return now
	end
	function c:GetBook()
		return book
	end
	function c:GetLimits()
		return View.limits(book)
	end
	function c:GetPanel()
		return {
			week = { twr = 0.012, benchReturn = 0.004, excess = 0.008, trades = 3 },
			skill = 1180,
		}
	end
	function c:RefreshPanel()
		self.panels += 1
	end
	function c:RequestSnapshot()
		self.snapshots += 1
	end
	function c:GetSelected()
		return self.selected
	end
	function c:SetSelected(id)
		self.selected = id
	end
	function c:ShortTitle()
		return "Associate"
	end
	function c:Subtitle()
		return "Analyst book"
	end
	function c:Trade(order)
		table.insert(self.trades, order)
		return true, nil, {}
	end
	function c:SetStops()
		return true, nil
	end
	function c:Flatten()
		return true, nil, 0
	end
	function c:ErrorText(err)
		return "error " .. tostring(err)
	end
	return c
end

local function fakeUI()
	local ui = { notes = {}, confirms = 0 }
	function ui:Notify(text, kind)
		table.insert(self.notes, { text, kind })
	end
	function ui:Confirm(_opts, callback)
		self.confirms += 1
		callback(false)
	end
	return ui
end

local function find(root: Instance, name: string): Instance?
	return root:FindFirstChild(name, true)
end

return function(t)
	t.describe("view model", function()
		t.it("picks the tabbed layout on narrow or short screens", function()
			t.expect(View.layoutMode(1240, 700)).toBe("wide")
			t.expect(View.layoutMode(700, 900)).toBe("phone")
			t.expect(View.layoutMode(1100, 380)).toBe("phone") -- a phone in landscape
			t.expect(View.layoutMode(nil, nil)).toBe("wide")
			t.expect(View.variant("campus")).toBe("laptop")
			t.expect(View.variant("street")).toBe("terminal")
		end)

		t.it("validates selections and replicated limits", function()
			t.expect(View.validSelection("APX")).toBe("APX")
			t.expect(View.validSelection("ST10")).toBe("ST10")
			t.expect(View.validSelection("ZZZ")).toBeNil()
			t.expect(View.validSelection(42)).toBeNil()
			local senior = View.limits({ limits = Ledger.limits({ rank = 2, mult = 0.6 }) })
			t.expect(senior.short).toBe(true)
			t.expect(senior.concentration).toBeCloseTo(0.3)
			local fallback = View.limits({ limits = { concentration = "lots" } })
			t.expect(fallback.concentration).toBeCloseTo(Ledger.CONC_JUNIOR)
			t.expect(View.limits(nil).short).toBe(false)
		end)

		t.it("names the rank that unlocks shorting", function()
			local rows = View.limitRows(Ledger.limits({ rank = 1 }), "Associate")
			t.expect(rows[3].value).toContain("Associate")
			local open = View.limitRows(Ledger.limits({ rank = 2 }), "Associate")
			t.expect(open[3].value).toBe(Tickers.text("short_allowed"))
			t.expect(View.limitRows(Ledger.limits({ rank = 0 }))[3].value)
				.toContain(Tickers.text("short_title_default"))
		end)

		t.it("previews concentration with the server's own rules and sizes presets inside the limits", function()
			local prices = { APX = 100, MRB = 50 }
			local b = bookWith(10000, {}, 1)
			local limits = View.limits(b)
			local ok = View.preview(b, prices, "APX", "buy", 30, limits)
			t.expect(ok.ok).toBe(true)
			t.expect(ok.weight).toBeBetween(0.29, 0.31)
			local tooBig = View.preview(b, prices, "APX", "buy", 50, limits)
			t.expect(tooBig.ok).toBe(false)
			t.expect(tooBig.err).toBe("concentration")
			local max = View.presetQty(b, prices, "APX", "buy", "max", limits)
			t.expect(View.preview(b, prices, "APX", "buy", max, limits).ok).toBe(true)
			t.expect(View.preview(b, prices, "APX", "buy", max + 1, limits).ok).toBe(false)
			t.expect(View.presetQty(b, prices, "APX", "buy", "p25", limits)).toBe(25)
			-- a junior can't short; selling what you hold is fine
			t.expect(View.preview(b, prices, "MRB", "sell", 10, limits).err).toBe("no_short")
			local held = bookWith(5000, { MRB = { shares = 40, avgCost = 45 } }, 1)
			t.expect(View.side(40, "sell")).toBe("sell")
			t.expect(View.side(-5, "buy")).toBe("cover")
			t.expect(View.presetQty(held, prices, "MRB", "sell", "close", limits)).toBe(40)
			t.expect(View.preview(held, prices, "MRB", "sell", 40, limits).ok).toBe(true)
		end)

		t.it("computes LIVE INVESTED as the market value of open positions", function()
			local b = bookWith(1000, { APX = { shares = 10, avgCost = 90 }, MRB = { shares = -4, avgCost = 60 } }, 2)
			t.expect(View.invested(b, { APX = 100, MRB = 50 })).toBeCloseTo(1000 + 200)
			t.expect(View.invested(nil, {})).toBe(0)
			t.expect(View.invested(bookWith(1000, {}), {})).toBe(0)
			local rows = View.positions(b, { APX = 100, MRB = 50 })
			t.expect(#rows).toBe(2)
			t.expect(rows[1].ticker).toBe("APX")
			t.expect(rows[2].long).toBe(false)
			t.expect(rows[2].pnl).toBeCloseTo(40) -- short from 60 to 50
		end)

		t.it("hides employees-only terminals from visitors, except merger partners", function()
			local mine = { companyId = "mg_freeman", status = "active" }
			t.expect(View.canUsePrompt(mine, nil, nil)).toBe(true)
			t.expect(View.canUsePrompt(mine, nil, "mg_freeman")).toBe(true)
			t.expect(View.canUsePrompt(mine, nil, "evermoor")).toBe(false)
			t.expect(View.canUsePrompt({ companyId = "", status = "student" }, nil, "evermoor")).toBe(false)
			t.expect(View.canUsePrompt({ companyId = "mg_freeman", status = "fired" }, nil, "mg_freeman")).toBe(false)
			local merger = { corporate = { id = "merger_mania", data = { companies = { "mg_freeman", "evermoor" } } } }
			t.expect(View.canUsePrompt(mine, merger, "evermoor")).toBe(true)
			t.expect(View.canUsePrompt(mine, merger, "blairmont")).toBe(false)
		end)

		t.it("formats breaches, events, the calendar and news ages", function()
			local rows = View.breaches({
				breaches = { { kind = "concentration", ticker = "APX", value = 0.47, limit = 0.4, deadline = 160 } },
			}, 100)
			t.expect(#rows).toBe(1)
			t.expect(rows[1].text).toContain("APX")
			t.expect(rows[1].secondsLeft).toBe(60)
			local ev = View.event({ id = "meme_rally", endsAt = 400, data = { ticker = "VLT", name = "Volt" } }, 100)
			t.expect(ev and ev.name).toBe(Tickers.events.meme_rally.name)
			t.expect(ev and ev.secondsLeft).toBe(300)
			t.expect(View.event({ id = "nope" }, 0)).toBeNil()
			local cal = View.calendar({
				{ day = 3, inDays = 0, tickers = { { id = "APX", consensus = 1.5, frenzy = true } } },
				{ day = 5, inDays = 2, tickers = { { id = "MRB" } } },
			})
			t.expect(cal[1].when).toBe(Tickers.text("cal_today"))
			t.expect(cal[1].frenzy).toBe(true)
			t.expect(cal[2].first).toBe("MRB")
			t.expect(View.age(100, 100)).toBe(Tickers.text("age_now"))
			t.expect(View.age(0, 300)).toContain("5")
		end)
	end)

	t.describe("market cache", function()
		t.it("loads a server snapshot with nothing hidden in it", function()
			local state = Model.new(7, T0 + 60)
			local snap = Model.snapshot(state, T0 + 60)
			for _, hidden in { "fv", "surprise", "mult", "seed", "rng", "impulses" } do
				t.expect(hasKey(snap, hidden)).toBe(false)
			end
			local cache = loadedCache(state, T0 + 60)
			t.expect(cache.loaded).toBe(true)
			t.expect(#cache.tickers).toBe(#Tickers.IDS)
			for i, view in cache.tickers do
				t.expect(view.id).toBe(Tickers.IDS[i])
				t.expect(view.quote.price).toBeGreaterThan(0)
				t.expect(#view.daily).toBe(Model.HISTORY_DAYS)
			end
			t.expect(cache.indexLevel).toBeGreaterThan(0)
		end)

		t.it("follows server ticks, ignores late packets and carries prices over dropped ones", function()
			local state = Model.new(11, T0 + 20)
			local cache = loadedCache(state, T0 + 20)
			step(state, T0 + 22, T0 + 40)
			local p1 = Model.tickPayload(state, T0 + 40)
			Cache.applyTick(cache, p1)
			for i, id in Tickers.IDS do
				t.expect(cache.prices[id]).toBeCloseTo(p1.p[i], 0.01)
			end
			t.expect(cache.indexLevel).toBeCloseTo(p1.ix, 0.1)
			-- skip a few ticks (dropped unreliable packets)
			step(state, T0 + 42, T0 + 60)
			local p2 = Model.tickPayload(state, T0 + 60)
			Cache.applyTick(cache, p2)
			local apx = cache.byId.APX
			t.expect(#apx.intraday).toBe(p2.k + 1)
			t.expect(apx.intraday[#apx.intraday]).toBeCloseTo(p2.p[1], 0.01)
			-- an older packet arriving late changes nothing
			Cache.applyTick(cache, p1)
			t.expect(cache.prices.APX).toBeCloseTo(p2.p[1], 0.01)
		end)

		t.it("marks itself stale on a new market day or a new event", function()
			local state = Model.new(5, T0 + 10)
			local cache = loadedCache(state, T0 + 10)
			step(state, T0 + 12, T0 + 30)
			local stale = Cache.applyTick(cache, Model.tickPayload(state, T0 + 30))
			t.expect(stale).toBe(false)
			t.expect(Model.trigger(state, "crazy_day", nil, T0 + 31)).toBe(true)
			step(state, T0 + 32, T0 + 32)
			t.expect((Cache.applyTick(cache, Model.tickPayload(state, T0 + 32)))).toBe(true)
			step(state, T0 + 34, T0 + DAY + 4)
			local staleDay, dayChanged = Cache.applyTick(cache, Model.tickPayload(state, T0 + DAY + 4))
			t.expect(staleDay).toBe(true)
			t.expect(dayChanged).toBe(true)
		end)

		t.it("keeps news newest first without duplicates", function()
			local cache = Cache.new()
			t.expect(Cache.addNews(cache, { id = 1, headline = "a" })).toBe(true)
			t.expect(Cache.addNews(cache, { id = 2, headline = "b" })).toBe(true)
			t.expect(Cache.addNews(cache, { id = 2, headline = "b" })).toBe(false)
			t.expect(Cache.addNews(cache, { nope = true })).toBe(false)
			t.expect(cache.news[1].id).toBe(2)
			for i = 3, 60 do
				Cache.addNews(cache, { id = i, headline = "h" .. i })
			end
			t.expect(#cache.news).toBe(Cache.NEWS_MAX)
		end)
	end)

	local state = Model.new(21, T0 + 90)
	step(state, T0 + 92, T0 + 120)
	local now = T0 + 120
	local held = Model.price(state, "APX") :: number

	-- Kit can't see Destroying under Lune, so a closed screen would stay in its restyle list and warn on the next
	-- theme change: the theme switches while the screen is open instead (which also tests the live restyle).
	t.describe("Terminal screen", function()
		t.it("opens wide with every panel and restyles live from the campus laptop to the street terminal", function()
			Theme.set("campus")
			local cache = loadedCache(state, now)
			local book = bookWith(20000, { APX = { shares = 20, avgCost = held * 0.95 } }, 1)
			local controller = fakeController(cache, book, now)
			local root = Instance.new("Frame")
			local handle = Terminal.open({ layout = "wide" }, root, { controller = controller, UI = fakeUI() })
			for _, name in { "Watchlist", "Quote", "Facts", "Ticket", "Positions", "Account", "Risk", "News" } do
				t.expect(find(root, name) ~= nil).toBeTruthy()
			end
			t.expect(find(root, "Calendar") ~= nil).toBeTruthy()
			t.expect(find(root, "Row_APX") ~= nil).toBeTruthy()
			t.expect(find(root, "Row_ST10") ~= nil).toBeTruthy()
			-- LIVE INVESTED shows the position's market value
			local account = find(root, "Account") :: Instance
			local cell = account:FindFirstChild("Cell_invested", true) :: Instance
			local value = cell:FindFirstChild("Value") :: TextLabel
			t.expect(value.Text).never("--")
			t.expect(controller.snapshots).toBeGreaterThan(0)
			-- campus: an old laptop with a webcam and the club sticker; street: the dark terminal
			local window = root:FindFirstChild("TerminalWindow") :: any
			local title = window.Panel.Header.Titles.Title :: TextLabel
			local webcam = find(root, "Webcam") :: GuiObject
			t.expect(title.Text).toBe(Tickers.text("title_laptop"))
			t.expect(webcam.Visible).toBe(true)
			Theme.set("street")
			t.expect(title.Text).toBe(Tickers.text("title_terminal"))
			t.expect(webcam.Visible).toBe(false)
			handle.close()
			handle.close() -- idempotent
		end)
	end)

	t.describe("Terminal screen layouts", function()
		t.it("opens on phones with one page per tab", function()
			local cache = loadedCache(state, now)
			local book = bookWith(5000, {}, 0)
			book.paper = true
			local controller = fakeController(cache, book, now)
			local root = Instance.new("Frame")
			local handle = Terminal.open({ layout = "phone", tab = "trade" }, root, { controller = controller })
			for _, id in Layout.tabsFor("trade") do
				t.expect(find(root, "Page_" .. id) ~= nil).toBeTruthy()
				t.expect(find(root, "Tab_" .. id) ~= nil).toBeTruthy()
			end
			local trade = find(root, "Page_trade") :: GuiObject
			local market = find(root, "Page_market") :: GuiObject
			t.expect(trade.Visible).toBe(true)
			t.expect(market.Visible).toBe(false)
			handle.close()
		end)

		t.it("opens the news stand read-only", function()
			local cache = loadedCache(state, now)
			local controller = fakeController(cache, bookWith(5000, {}), now)
			local root = Instance.new("Frame")
			local handle = Terminal.open({ mode = "news", layout = "wide" }, root, { controller = controller })
			t.expect(find(root, "News") ~= nil).toBeTruthy()
			t.expect(find(root, "Account")).toBeNil()
			t.expect(find(root, "Positions")).toBeNil()
			local ro = find(root, "ReadOnly") :: GuiObject
			t.expect(ro.Visible).toBe(true)
			handle.close()
			local phoneRoot = Instance.new("Frame")
			local phone = Terminal.open({ mode = "news", layout = "phone" }, phoneRoot, { controller = controller })
			t.expect(find(phoneRoot, "Page_news") ~= nil).toBeTruthy()
			t.expect(find(phoneRoot, "Page_trade")).toBeNil()
			phone.close()
		end)

		t.it("opens offline without a controller", function()
			local root = Instance.new("Frame")
			local handle = Terminal.open({ layout = "wide" }, root, {})
			t.expect(find(root, "Watchlist") ~= nil).toBeTruthy()
			handle.close()
		end)
	end)
end
