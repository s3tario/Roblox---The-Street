--!strict
-- PortfolioService: per-tick book processing (RUNTIME ONLY, server; MarketService.Tick every 2 s). For every player in
-- session: stop-loss / take-profit fills, the risk ladder (Logic/Portfolio/Desk.process) with its toasts and signals,
-- equity samples every Session.SAMPLE_EVERY seconds and the LiveInvested leaderboard every Session.LIVE_EVERY.
--
--   Tick.process(svc, now, prices)     svc = PortfolioService (for its Traded / RiskViolation signals)

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Ledger = require(Shared.Logic.Portfolio.Ledger)
local Desk = require(Shared.Logic.Portfolio.Desk)
local Risk = require(Shared.Logic.Portfolio.Risk)
local Deps = require(script.Parent.Parent.MarketService.Deps)
local Session = require(script.Parent.Session)

local Tick = {}

local pct = Desk.pct

local function warnToast(player: Player, a: Risk.Active, now: number)
	local secs = math.max(0, math.floor(a.deadline - now))
	if a.kind == "gross" then
		Deps.notify(
			player,
			Tickers.text("risk_warn_gross", { value = pct(a.value), limit = pct(a.limit), secs = secs }),
			"warn"
		)
	elseif a.kind == "concentration" then
		Deps.notify(
			player,
			Tickers.text(
				"risk_warn_conc",
				{ ticker = a.ticker or "", value = pct(a.value), limit = pct(a.limit), secs = secs }
			),
			"warn"
		)
	elseif a.kind == "short" then
		Deps.notify(player, Tickers.text("risk_warn_short", { ticker = a.ticker or "", secs = secs }), "warn")
	elseif a.kind == "cash" then
		Deps.notify(player, Tickers.text("risk_warn_cash", { value = Session.money(a.value), secs = secs }), "warn")
	end
end

local function processPlayer(svc: any, player: Player, ps: Session.PState, now: number, p: { [string]: number }, open: boolean)
	local book, data = Session.bookOf(player)
	if not book or not data then
		return
	end
	local limits = Session.refreshLimits(player) or ps.limits
	local tick = Desk.process(book, ps.risk, p, limits, now, open)
	for _, fill in tick.fills do
		local trade = fill.trade
		if fill.reason == "stop" or fill.reason == "take" then
			Deps.notify(
				player,
				Tickers.text(if fill.reason == "stop" then "stop_hit" else "take_hit", {
					qty = math.abs(trade.q),
					ticker = trade.tk,
					price = string.format("%.2f", trade.px),
				}),
				if trade.pnl >= 0 then "good" else "warn"
			)
			svc.Traded:Fire(player, table.clone(trade))
		end
	end
	for _, a in tick.warn do
		warnToast(player, a, now)
	end
	for i, a in tick.violate do
		local count = ps.risk.weekViolations
		Deps.notify(
			player,
			Tickers.text(if a.ticker then "risk_violation" else "risk_violation_gross", {
				count = count,
				ticker = a.ticker or "",
			}),
			"bad"
		)
		local major = tick.major and i == #tick.violate
		if major then
			Deps.notify(player, Tickers.text("risk_major"), "bad")
		end
		Deps.audit(player, "risk_violation", {
			kind = a.kind,
			ticker = a.ticker,
			value = a.value,
			limit = a.limit,
			count = count,
			major = major,
		})
		svc.RiskViolation:Fire(player, {
			kind = a.kind,
			ticker = a.ticker,
			value = a.value,
			limit = a.limit,
			count = count,
			major = major,
			severity = if major then "major" else "violation",
		})
	end
	if #tick.resolved > 0 and #tick.violate == 0 and #tick.warn == 0 then
		Deps.notify(player, Tickers.text("risk_resolved"), "good")
	end
	if tick.changed then
		Session.publishRisk(book, ps.risk, now)
		Session.replicate(player)
	end
	local clock = os.clock()
	if clock - ps.lastSample >= Session.SAMPLE_EVERY then
		ps.lastSample = clock
		Session.sample(player, data, book, p, ps.segment)
		Ledger.updatePeak(book, Ledger.equity(book, p))
	end
	if clock - ps.lastLive >= Session.LIVE_EVERY then
		ps.lastLive = clock
		Deps.submitBoard(player, "LiveInvested", math.floor(Ledger.invested(book, p)))
	end
end

function Tick.process(svc: any, now: number, p: { [string]: number })
	local open = Session.marketOpen()
	for player, ps in Session.states do
		if player.Parent == Players then
			local ok, err = pcall(function()
				processPlayer(svc, player, ps, now, p, open)
			end)
			if not ok then
				warn(("[PortfolioService] tick for %s failed: %s"):format(player.Name, tostring(err)))
			end
		end
	end
end

return Tick
