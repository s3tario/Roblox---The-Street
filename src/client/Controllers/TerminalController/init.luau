--!strict
-- TerminalController (client, owned by `market`; contracts §6, design v3 §11): the client side of the per-server
-- market and the player's session book.
--
--   * Keeps the market cache (TerminalParts/Cache): the "Market.Snapshot" answer plus every 2-second "Market.Tick"
--     (unreliable: a dropped packet just carries the last price) and every "Market.News" headline. A new market day
--     or a new event marks the cache stale; it refetches while the Terminal is open, otherwise on the next open.
--   * Opens the Terminal: "Market.Open" from MarketService after a terminal / news stand prompt (mode "trade" or
--     "news"), the "Market" menu tab (a quick HUD button too), the Phone's Market app (M3, when PhoneController
--     exists) and the LIVE INVESTED HUD chip (TerminalController/Hud).
--   * Sends orders with a fresh client transaction id; a timed-out order is retried once with the SAME id, so the
--     server answers with the original fill instead of filling twice (Logic/Portfolio/Txn).
--   * Hides EmployeesOnly terminal prompts for visitors (TerminalController/Prompts) and scrolls the LED ticker
--     bands (TerminalController/Scroller).
--
-- API (used by UI/Screens/Terminal and its parts)
--   :Open(args?)   :Close()   args = { mode = "trade" | "news", ticker?, tab? }   :NoteOpen(mode) / :NoteClosed()
--   :GetCache() -> Cache   :Now() -> number   :GetBook() -> portfolio?   :GetLimits() -> Limits
--   :GetPanel() -> { week, curve, skill, summary, limits }?   :RefreshPanel(force?)   :RequestSnapshot(force?)
--   :GetSelected() / :SetSelected(id)    :ShortTitle() -> string    :Subtitle() -> string
--   :GetInvested() -> number             live market value of open positions (the HUD chip)
--   :Trade(order) -> (ok, errKey?, payload?)        order = { ticker, side = "buy" | "sell" | "close", qty?, fit?,
--                                                   stop?, take? }; payload = { trade, summary, replayed } | { vars }
--   :SetStops(ticker, stop?, take?) -> (ok, errKey?)    :Flatten() -> (ok, errKey?, closed?)
--   :ErrorText(errKey?, vars?) -> string            the player-facing message for a refusal
--   .Changed : Signal(kind)                          "tick" | "news" | "snapshot" | "book" | "career" | "panel" | "trade"

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Time = require(Shared.Util.Time)
local Format = require(Shared.Util.Format)
local Tickers = require(Shared.Config.Tickers)
local Ledger = require(Shared.Logic.Portfolio.Ledger)
local Registry = require(script.Parent.Parent.Registry)
local Screens = script.Parent.Parent:WaitForChild("UI"):WaitForChild("Screens")
local Parts = Screens:WaitForChild("TerminalParts")
local Cache = require(Parts:WaitForChild("Cache"))
local View = require(Parts:WaitForChild("View"))
local Prompts = require(script.Prompts)
local Hud = require(script.Hud)
local Scroller = require(script.Scroller)

local TerminalController = {
	Name = "TerminalController",
	Changed = Signal.new(),
}

TerminalController.SCREEN_ID = "Terminal"
TerminalController.SNAPSHOT_GAP = 3 -- seconds between snapshot requests
TerminalController.PANEL_GAP = 4 -- seconds between Portfolio.Panel requests (server allows 1/s, burst 4)
TerminalController.PANEL_TTL = 20 -- a panel older than this is refreshed on the next open

local cache = Cache.new()
local stale = true -- the cache needs a fresh snapshot
local snapshotInFlight = false
local lastSnapshotAt = -math.huge
local panel: { [string]: any }? = nil
local panelAt = -math.huge
local panelInFlight = false
local panelQueued = false
local selected = "APX"
local txnKey = ""
local txnSeq = 0
local chip: Hud.Chip? = nil
local openMode: string? = nil -- the mode of the Terminal currently on screen (NoteOpen / NoteClosed)

---------------------------------------------------------------------------------------------------
-- Guarded access to other features
---------------------------------------------------------------------------------------------------
local function store(): any
	return Registry.get("Store")
end

local function storeGet(key: string): any
	local s = store()
	if not s then
		return nil
	end
	local ok, v = pcall(function()
		return s:Get(key)
	end)
	return if ok then v else nil
end

local function ui(): any
	return Registry.get("UIController")
end

-- Read-only configs owned by careerPath (guarded: the market works without them).
local function config(name: string): any
	local folder = Shared:FindFirstChild("Config")
	local mod = folder and folder:FindFirstChild(name)
	if not mod or not mod:IsA("ModuleScript") then
		return nil
	end
	local ok, res = pcall(require, mod)
	return if ok and type(res) == "table" then res else nil
end
local tracksConfig: any = false
local companiesConfig: any = false
local function tracks(): any
	if tracksConfig == false then
		tracksConfig = config("Tracks")
	end
	return tracksConfig
end
local function companies(): any
	if companiesConfig == false then
		companiesConfig = config("Companies")
	end
	return companiesConfig
end

---------------------------------------------------------------------------------------------------
-- Market cache
---------------------------------------------------------------------------------------------------
local function isOpen(): boolean
	local u = ui()
	if not u or type(u.IsOpen) ~= "function" then
		return false
	end
	local ok, open = pcall(u.IsOpen, u, TerminalController.SCREEN_ID)
	return ok and open == true
end

function TerminalController:GetCache(): Cache.Cache
	return cache
end

function TerminalController:Now(): number
	return Time.now()
end

function TerminalController:RequestSnapshot(force: boolean?)
	if snapshotInFlight then
		return
	end
	if not force and not stale and cache.loaded then
		return
	end
	if os.clock() - lastSnapshotAt < TerminalController.SNAPSHOT_GAP then
		return
	end
	snapshotInFlight = true
	lastSnapshotAt = os.clock()
	task.spawn(function()
		local ok, snap = pcall(Net.invoke, "Market.Snapshot")
		snapshotInFlight = false
		if ok and type(snap) == "table" and type(snap.tickers) == "table" then
			Cache.applySnapshot(cache, snap)
			stale = not cache.loaded
			TerminalController.Changed:Fire("snapshot")
		end
	end)
end

local function updateChip()
	local c = chip
	if not c then
		return
	end
	local book = storeGet("portfolio")
	if type(book) ~= "table" then
		c.set(nil)
		return
	end
	local invested = View.invested(book, Cache.prices(cache))
	-- a student's untouched paper account doesn't need a HUD chip; a real book always shows it
	if book.paper == true and invested <= 0 then
		c.set(nil)
		return
	end
	c.set(invested)
end

local function onTick(payload: any)
	local wasStale, _dayChanged = Cache.applyTick(cache, payload)
	if wasStale then
		stale = true
	end
	if stale and isOpen() then
		TerminalController:RequestSnapshot(false)
	end
	updateChip()
	TerminalController.Changed:Fire("tick")
end

local function onNews(item: any)
	if Cache.addNews(cache, item) then
		TerminalController.Changed:Fire("news")
	end
end

---------------------------------------------------------------------------------------------------
-- Book
---------------------------------------------------------------------------------------------------
function TerminalController:GetBook(): { [string]: any }?
	local book = storeGet("portfolio")
	return if type(book) == "table" then book else nil
end

function TerminalController:GetLimits(): Ledger.Limits
	return View.limits(self:GetBook())
end

function TerminalController:GetInvested(): number
	return View.invested(self:GetBook(), Cache.prices(cache))
end

function TerminalController:GetSelected(): string
	return selected
end

function TerminalController:SetSelected(id: string)
	local valid = View.validSelection(id)
	if valid then
		selected = valid
	end
end

function TerminalController:GetPanel(): { [string]: any }?
	return panel
end

function TerminalController:RefreshPanel(force: boolean?)
	local age = os.clock() - panelAt
	if not force and (panelInFlight or (panel ~= nil and age < TerminalController.PANEL_TTL)) then
		return
	end
	if panelInFlight or age < TerminalController.PANEL_GAP then
		-- never faster than the server's rate limit: a forced refresh runs once the gap has passed
		if force and not panelQueued then
			panelQueued = true
			task.delay(math.max(0.5, TerminalController.PANEL_GAP - age + 0.05), function()
				panelQueued = false
				TerminalController:RefreshPanel(true)
			end)
		end
		return
	end
	panelInFlight = true
	panelAt = os.clock()
	task.spawn(function()
		local ok, result = pcall(Net.invoke, "Portfolio.Panel")
		panelInFlight = false
		if ok and type(result) == "table" then
			panel = result
			TerminalController.Changed:Fire("panel")
		end
	end)
end

-- The title that unlocks shorting on the player's track (Config/Tracks rank Ledger.SHORT_RANK, e.g. "Associate").
function TerminalController:ShortTitle(): string
	local career = storeGet("career")
	local track = if type(career) == "table" and type(career.track) == "string" then career.track else "ib"
	local t = tracks()
	if t and type(t.rankDef) == "function" then
		local ok, def = pcall(t.rankDef, track, Ledger.SHORT_RANK)
		if not ok or type(def) ~= "table" then
			ok, def = pcall(t.rankDef, "ib", Ledger.SHORT_RANK)
		end
		if ok and type(def) == "table" and type(def.title) == "string" then
			return def.title
		end
	end
	return Tickers.text("short_title_default")
end

function TerminalController:Subtitle(): string
	local book = self:GetBook()
	if not book then
		return Tickers.text("loading")
	end
	if book.paper == true then
		return Tickers.text("subtitle_paper", { cash = Format.money(tonumber(book.bookSize) or 0, 0) })
	end
	local career = storeGet("career")
	local title = if type(career) == "table" and type(career.title) == "string" then career.title else nil
	local companyId = if type(career) == "table" then career.companyId else nil
	local name: string? = nil
	local c = companies()
	if c and type(c.get) == "function" and type(companyId) == "string" then
		local ok, def = pcall(c.get, companyId)
		if ok and type(def) == "table" and type(def.name) == "string" then
			name = def.name
		end
	end
	if title and name then
		return Tickers.text("subtitle_book", { title = title, company = name })
	end
	return Tickers.text("subtitle_book_plain")
end

---------------------------------------------------------------------------------------------------
-- Orders
---------------------------------------------------------------------------------------------------
local function nextTxn(): string
	txnSeq += 1
	return string.format("%s-%d", txnKey, txnSeq)
end

-- RemoteFunction results arrive as (ok, err, payload) or, from Net itself, (nil, "timeout" | "error" |
-- "rate_limited" | "missing").
local function invoke(name: string, ...: any): (boolean, string?, any)
	local ok, a, b, c = pcall(Net.invoke, name, ...)
	if not ok then
		return false, "generic", nil
	end
	if a == true then
		return true, nil, c
	end
	if a == nil and type(b) == "string" then
		return false, b, nil
	end
	return false, if type(b) == "string" then b else "generic", c
end

local function afterOrder()
	TerminalController:RefreshPanel(true)
	TerminalController.Changed:Fire("trade")
end

function TerminalController:Trade(order: { [string]: any }): (boolean, string?, any)
	if type(order) ~= "table" then
		return false, "generic", nil
	end
	local txn = nextTxn()
	local ok, err, payload = invoke("Portfolio.Trade", order, txn)
	if not ok and err == "timeout" then
		-- same id: if the first attempt filled, the server replays that fill instead of trading again
		ok, err, payload = invoke("Portfolio.Trade", order, txn)
	end
	if ok then
		afterOrder()
	end
	return ok, err, payload
end

function TerminalController:SetStops(ticker: string, stop: number?, take: number?): (boolean, string?)
	local ok, err = invoke("Portfolio.SetStops", ticker, stop, take)
	if ok then
		TerminalController.Changed:Fire("trade")
	end
	return ok, err
end

function TerminalController:Flatten(): (boolean, string?, number?)
	local txn = nextTxn()
	local ok, err, n = invoke("Portfolio.Flatten", txn)
	if not ok and err == "timeout" then
		ok, err, n = invoke("Portfolio.Flatten", txn)
	end
	if ok then
		afterOrder()
	end
	return ok, err, if type(n) == "number" then n else nil
end

local ERR_ALIAS: { [string]: string } = {
	timeout = "timeout",
	rate_limited = "rate",
	error = "generic",
	missing = "generic",
	offline = "generic",
}

function TerminalController:ErrorText(err: string?, vars: { [string]: any }?): string
	local key = if type(err) == "string" then (ERR_ALIAS[err] or err) else "generic"
	local v: { [string]: any } = {}
	if type(vars) == "table" then
		for k, x in vars do
			if type(k) == "string" and (type(x) == "string" or type(x) == "number") then
				v[k] = x
			end
		end
	end
	if v.title == nil then
		v.title = self:ShortTitle()
	end
	if Tickers.hasText("err_" .. key) then
		return Tickers.text("err_" .. key, v)
	end
	return Tickers.text("err_generic")
end

---------------------------------------------------------------------------------------------------
-- Opening
---------------------------------------------------------------------------------------------------
function TerminalController:Open(args: { [string]: any }?)
	local u = ui()
	if not u or type(u.Open) ~= "function" then
		return
	end
	local a: { [string]: any } = {}
	if type(args) == "table" then
		a.mode = if args.mode == "news" then "news" else "trade"
		a.ticker = View.validSelection(args.ticker)
		a.tab = if type(args.tab) == "string" then args.tab else nil
	end
	stale = stale or not cache.loaded
	self:RequestSnapshot(false)
	local mode = a.mode or "trade"
	if openMode == mode and isOpen() and a.ticker == nil and a.tab == nil then
		return -- already showing this terminal (a second prompt press, the HUD chip)
	end
	pcall(u.Open, u, TerminalController.SCREEN_ID, a)
end

-- The Terminal screen reports what it shows, so a repeated open doesn't rebuild it.
function TerminalController:NoteOpen(mode: string)
	openMode = if mode == "news" then "news" else "trade"
end

function TerminalController:NoteClosed()
	openMode = nil
end

function TerminalController:Close()
	local u = ui()
	if u and type(u.Close) == "function" then
		pcall(u.Close, u, TerminalController.SCREEN_ID)
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function TerminalController:Init()
	local rng = Random.new()
	txnKey = string.format("c%d-%x", Players.LocalPlayer.UserId, rng:NextInteger(0, 0x7FFFFFFF))
end

local function canUsePrompt(companyId: any): boolean
	local s = store()
	local events = nil
	if s then
		local ok, v = pcall(function()
			return s:GetGlobal("events")
		end)
		events = if ok then v else nil
	end
	return View.canUsePrompt(storeGet("career"), events, companyId)
end

local function reducedMotion(): boolean
	local u = ui()
	if not u or type(u.GetSettings) ~= "function" then
		return false
	end
	local ok, settings = pcall(u.GetSettings, u)
	return ok and type(settings) == "table" and settings.reducedMotion == true
end

function TerminalController:Start()
	Net.listen("Market.Tick", onTick, true)
	Net.listen("Market.News", onNews)
	Net.listen("Market.Open", function(payload: any)
		local p = if type(payload) == "table" then payload else {}
		TerminalController:Open({ mode = if p.mode == "news" then "news" else "trade" })
	end)

	local u = ui()
	if u and type(u.RegisterMenuTab) == "function" then
		u:RegisterMenuTab({
			id = "market",
			title = Tickers.text("menu_market"),
			glyph = "📈",
			order = 30,
			screen = TerminalController.SCREEN_ID,
			quick = true,
		})
	end
	if u and type(u.GetLayer) == "function" then
		local ok, layer = pcall(u.GetLayer, u, "hud")
		if ok and typeof(layer) == "Instance" and layer:IsA("Frame") then
			local built, result = pcall(Hud.new, layer, function()
				TerminalController:Open({ mode = "trade" })
			end)
			if built then
				chip = result
			else
				warn("[TerminalController] HUD chip failed: " .. tostring(result))
			end
		end
	end

	-- the Phone's Market app (phone feature, M3)
	local phone = Registry.get("PhoneController")
	if phone and type(phone.RegisterApp) == "function" then
		pcall(phone.RegisterApp, phone, {
			id = "market",
			title = Tickers.text("phone_app"),
			glyph = "📈",
			order = 50,
			open = function()
				TerminalController:Open({ mode = "trade" })
			end,
		})
	end

	local evaluatePrompts = Prompts.start(canUsePrompt)
	local s = store()
	if s then
		pcall(function()
			s:Changed("portfolio"):Connect(function()
				updateChip()
				TerminalController.Changed:Fire("book")
			end)
			s:Changed("career"):Connect(function()
				evaluatePrompts()
				TerminalController.Changed:Fire("career")
			end)
			s:GlobalChanged("events"):Connect(evaluatePrompts)
			s.Loaded:Connect(function()
				evaluatePrompts()
				updateChip()
				TerminalController.Changed:Fire("book")
			end)
		end)
	end
	updateChip()

	local okScroll, errScroll = pcall(Scroller.start, reducedMotion)
	if not okScroll then
		warn("[TerminalController] ticker scroller failed: " .. tostring(errScroll))
	end

	-- warm the cache so the first open is instant
	task.delay(2, function()
		TerminalController:RequestSnapshot(true)
	end)
end

return TerminalController
