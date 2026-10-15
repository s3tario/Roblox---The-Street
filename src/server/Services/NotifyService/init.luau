--!strict
-- NotifyService (server, Priority 5): toasts, banners and the news ticker (contracts §12).
--   NotifyService:Notify(player, text, kind?)        kind "info"|"good"|"bad"|"warn"|"cash"|"xp"
--   NotifyService:NotifyAll(text, kind?)
--   NotifyService:Banner(playerOrNil, {title, subtitle?, style?, duration?})   style "event"|"promotion"|"warning"|"celebration"
--   NotifyService:Ticker(text)                        news ticker line for everyone (last 20 kept)
--   NotifyService:GetTickerHistory() -> {string}
-- Remotes (server -> client): UI.Notify(text, kind, count?), UI.Banner(opts), UI.Ticker(text).
-- RemoteFunction UI.TickerHistory() -> {string} lets joining clients fetch the recent ticker lines.
-- Per-player limits protect clients from buggy spam: max 6 toasts / 2 s with duplicates coalesced
-- ("text x3"), max 3 banners / 6 s; the ticker is limited globally.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Limiter = require(script.Limiter)
local TextClean = require(script.TextClean)

local NotifyService = { Name = "NotifyService", Priority = 5 }

NotifyService.KINDS = { info = true, good = true, bad = true, warn = true, cash = true, xp = true }
NotifyService.STYLES = { event = true, promotion = true, warning = true, celebration = true }
NotifyService.TICKER_MAX = 20
NotifyService.clean = TextClean.clean

local TOAST_LIMITS = { max = 6, window = 2, dupWindow = 2, maxPending = 6 }
local BANNER_LIMITS = { max = 3, window = 6, dupWindow = 6, maxPending = 3 }
local TICKER_LIMITS = { max = 6, window = 10, dupWindow = 20, maxPending = 6 }
local MAX_TEXT = 200
local MAX_TITLE = 80
local MAX_SUBTITLE = 160
local FLUSH_EVERY = 0.25

local toastState: { [Player]: Limiter.State } = {}
local bannerState: { [Player]: Limiter.State } = {}
local tickerState: Limiter.State = Limiter.new(TICKER_LIMITS)
local tickerLines: { string } = {}

local function isLivePlayer(p: any): boolean
	return typeof(p) == "Instance" and p:IsA("Player") and p.Parent == Players
end

local function sendToast(player: Player, entry: Limiter.Entry)
	local payload = entry.payload
	Net.fire("UI.Notify", player, payload.text, payload.kind, if entry.count > 1 then entry.count else nil)
end

local function sendBanner(player: Player, entry: Limiter.Entry)
	Net.fire("UI.Banner", player, entry.payload)
end

local function pushTickerLine(text: string)
	table.insert(tickerLines, text)
	while #tickerLines > NotifyService.TICKER_MAX do
		table.remove(tickerLines, 1)
	end
	Net.fireAll("UI.Ticker", text)
end

local function stateFor(map: { [Player]: Limiter.State }, player: Player, limits: Limiter.Config): Limiter.State
	local st = map[player]
	if st == nil then
		local fresh = Limiter.new(limits)
		map[player] = fresh
		return fresh
	end
	return st
end

---------------------------------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------------------------------
function NotifyService:Notify(player: Player, text: any, kind: string?)
	if not isLivePlayer(player) then
		return
	end
	local clean = TextClean.clean(text, MAX_TEXT)
	if clean == nil then
		return
	end
	local k = if type(kind) == "string" and NotifyService.KINDS[kind] then kind else "info"
	local st = stateFor(toastState, player, TOAST_LIMITS)
	for _, entry in Limiter.offer(st, k .. "\0" .. clean, { text = clean, kind = k }, os.clock()) do
		sendToast(player, entry)
	end
end

function NotifyService:NotifyAll(text: any, kind: string?)
	for _, player in Players:GetPlayers() do
		self:Notify(player, text, kind)
	end
end

export type BannerOpts = { title: string?, subtitle: string?, style: string?, duration: number? }

function NotifyService:Banner(playerOrNil: Player?, opts: BannerOpts)
	if type(opts) ~= "table" then
		return
	end
	local title = TextClean.clean(opts.title, MAX_TITLE)
	if title == nil then
		return
	end
	local subtitle = TextClean.clean(opts.subtitle, MAX_SUBTITLE, true)
	local style = if type(opts.style) == "string" and NotifyService.STYLES[opts.style] then opts.style else "event"
	local duration = if type(opts.duration) == "number" and opts.duration == opts.duration
		then math.clamp(opts.duration, 1.5, 15)
		else 4.5
	local payload = { title = title, subtitle = subtitle, style = style, duration = duration }
	local key = title .. "\0" .. (subtitle or "")
	local targets: { Player } = if playerOrNil == nil then Players:GetPlayers() else { playerOrNil }
	local now = os.clock()
	for _, player in targets do
		if isLivePlayer(player) then
			local st = stateFor(bannerState, player, BANNER_LIMITS)
			for _, entry in Limiter.offer(st, key, payload, now) do
				sendBanner(player, entry)
			end
		end
	end
end

function NotifyService:Ticker(text: any)
	local clean = TextClean.clean(text, MAX_SUBTITLE)
	if clean == nil then
		return
	end
	-- A line already among the most recent ones is news nobody needs twice.
	for i = #tickerLines, math.max(1, #tickerLines - 2), -1 do
		if tickerLines[i] == clean then
			return
		end
	end
	for _, entry in Limiter.offer(tickerState, clean, clean, os.clock()) do
		pushTickerLine(entry.payload)
	end
end

function NotifyService:GetTickerHistory(): { string }
	return table.clone(tickerLines)
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function NotifyService:Init()
	Net.declare("UI.Notify")
	Net.declare("UI.Banner")
	Net.declare("UI.Ticker")
	Net.handle("UI.TickerHistory", function(_player: Player)
		return table.clone(tickerLines)
	end, { rate = 1, burst = 3 })
	Players.PlayerRemoving:Connect(function(player: Player)
		toastState[player] = nil
		bannerState[player] = nil
	end)
end

local function flush()
	local now = os.clock()
	for player, st in toastState do
		if not isLivePlayer(player) then
			toastState[player] = nil
		else
			for _, entry in Limiter.drain(st, now) do
				sendToast(player, entry)
			end
			if Limiter.idle(st, now) then
				toastState[player] = nil
			end
		end
	end
	for player, st in bannerState do
		if not isLivePlayer(player) then
			bannerState[player] = nil
		else
			for _, entry in Limiter.drain(st, now) do
				sendBanner(player, entry)
			end
			if Limiter.idle(st, now) then
				bannerState[player] = nil
			end
		end
	end
	for _, entry in Limiter.drain(tickerState, now) do
		pushTickerLine(entry.payload)
	end
end

function NotifyService:Start()
	while true do
		task.wait(FLUSH_EVERY)
		local ok, err = pcall(flush :: any)
		if not ok then
			warn("[NotifyService] flush failed: " .. tostring(err))
		end
	end
end

return NotifyService
