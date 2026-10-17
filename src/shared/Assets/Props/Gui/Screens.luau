--!strict
-- Monitor screens (charts, candles, watchlists, terminals, inboxes, spreadsheets, decks, news) and LED
-- ticker surfaces. Everything is GUI Frames and TextLabels on glowing SurfaceGuis. Bake-safe.

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)
local Words = require(script.Parent.Parent.Words)
local Core = require(script.Parent.Core)

local Screens = {}

local hex = Core.hex
local UP, DOWN = Core.UP, Core.DOWN
local NAVY, NAVY2, TEXT, DIM, AMBER, MONO = Core.NAVY, Core.NAVY2, Core.TEXT, Core.DIM, Core.AMBER, Core.MONO
local frame, label = Core.frame, Core.label

Screens.KINDS = { "chart", "candles", "quotes", "terminal", "email", "sheet", "deck", "news" }

type ScreenFn = (gui: Instance, W: number, H: number, rng: Rng.Rng) -> ()

local function header(gui: Instance, title: string, right: string, rightColor: Color3)
	frame(gui, 0, 0, 1, 0.14, NAVY2)
	label(gui, title, 0.03, 0.015, 0.6, 0.11, TEXT, { font = MONO })
	label(gui, right, 0.55, 0.015, 0.42, 0.11, rightColor, { font = MONO, align = Enum.TextXAlignment.Right })
end

local function screenChart(gui: Instance, W: number, H: number, rng: Rng.Rng)
	Core.bg(gui, NAVY)
	local t = rng:pick(Words.tickers)
	local vals = Core.series(rng, 18, rng:range(40, 300), 0.02, rng:range(-0.006, 0.01))
	local up = vals[#vals] >= vals[1]
	local pct = (vals[#vals] / vals[1] - 1) * 100
	header(gui, t .. "  " .. Core.price(vals[#vals]), string.format("%+.2f%%", pct), if up then UP else DOWN)
	for i = 1, 3 do
		frame(gui, 0.03, 0.14 + i * 0.17, 0.94, 0.006, DIM, 0.75)
	end
	Core.lineChart(gui, W * 0.04, H * 0.2, W * 0.92, H * 0.5, vals, if up then UP else DOWN, math.max(2, H * 0.018))
	for i = 1, 8 do
		local bh = rng:range(0.03, 0.13)
		frame(gui, 0.04 + (i - 1) * 0.118, 0.97 - bh, 0.08, bh, DIM, 0.45)
	end
end

local function screenCandles(gui: Instance, W: number, H: number, rng: Rng.Rng)
	Core.bg(gui, hex("#0A0F17"))
	local t = rng:pick(Words.tickers)
	local q = rng:range(30, 260)
	local chg = rng:normal(0.3, 1.5)
	header(gui, t .. " 1D  " .. Core.price(q), string.format("%+.2f%%", chg), if chg >= 0 then UP else DOWN)
	frame(gui, 0.03, 0.5, 0.94, 0.005, DIM, 0.8)
	Core.candles(gui, W * 0.04, H * 0.2, W * 0.92, H * 0.72, rng, 14)
end

local function screenQuotes(gui: Instance, _W: number, _H: number, rng: Rng.Rng)
	Core.bg(gui, NAVY)
	label(gui, "WATCHLIST", 0.03, 0.02, 0.6, 0.11, AMBER, { font = MONO })
	local order = rng:shuffle(Words.tickers)
	for i = 1, 7 do
		local y = 0.15 + (i - 1) * 0.12
		if i % 2 == 0 then
			frame(gui, 0, y, 1, 0.12, NAVY2)
		end
		local q = Core.quote(rng, order[i])
		label(gui, q, 0.04, y + 0.015, 0.92, 0.09, TEXT, { font = MONO, rich = true })
	end
end

type Key = { name: string, color: Color3 }

local function screenTerminal(gui: Instance, W: number, H: number, rng: Rng.Rng)
	Core.bg(gui, hex("#050505"))
	local keys: { Key } = {
		{ name = "EQ", color = hex("#E8B04A") },
		{ name = "FX", color = hex("#3A7BD5") },
		{ name = "NEWS", color = hex("#C0392B") },
		{ name = "MKT", color = hex("#27AE60") },
	}
	for i, k in keys do
		local f = frame(gui, 0.02 + (i - 1) * 0.16, 0.025, 0.145, 0.1, k.color)
		label(f, k.name, 0.08, 0.08, 0.84, 0.84, hex("#0A0A0A"), { font = MONO, align = Enum.TextXAlignment.Center })
	end
	local lines = {}
	for i = 1, 5 do
		local t = Words.tickers[(rng:int(1, #Words.tickers) + i) % #Words.tickers + 1]
		table.insert(lines, string.format("%-4s %8.2f  %+5.2f%%", t, rng:range(20, 400), rng:normal(0, 1.4)))
	end
	label(gui, table.concat(lines, "\n"), 0.03, 0.17, 0.6, 0.78, AMBER, {
		font = MONO,
		yAlign = Enum.TextYAlignment.Top,
		align = Enum.TextXAlignment.Left,
	})
	local vals = Core.series(rng, 9, 100, 0.03, 0.004)
	frame(gui, 0.66, 0.2, 0.31, 0.5, hex("#101010"))
	Core.lineChart(gui, W * 0.67, H * 0.24, W * 0.29, H * 0.4, vals, AMBER, math.max(2, H * 0.015))
	label(gui, "STREET TERMINAL", 0.66, 0.78, 0.31, 0.1, DIM, { font = MONO, align = Enum.TextXAlignment.Right })
end

local function screenEmail(gui: Instance, _W: number, _H: number, rng: Rng.Rng)
	Core.bg(gui, hex("#F7F8FA"))
	frame(gui, 0, 0, 1, 0.13, hex("#1F4E8C"))
	label(gui, "Inbox (" .. rng:int(12, 140) .. ")", 0.03, 0.015, 0.6, 0.1, hex("#FFFFFF"))
	frame(gui, 0, 0.13, 0.22, 0.87, hex("#E4E8EE"))
	for i = 1, 4 do
		frame(gui, 0.03, 0.18 + (i - 1) * 0.1, 0.16, 0.05, hex("#B8C2D0"))
	end
	local mails = rng:shuffle(Words.emails)
	for i = 1, 6 do
		local y = 0.16 + (i - 1) * 0.14
		local m = mails[(i - 1) % #mails + 1]
		local unread = i <= 2
		if unread then
			frame(gui, 0.22, y - 0.015, 0.78, 0.14, hex("#E3EDFB"))
		end
		label(gui, m.from, 0.25, y, 0.24, 0.1, hex("#1A1D21"), {
			font = if unread then Enum.Font.GothamBold else Enum.Font.Gotham,
		})
		label(gui, m.subject, 0.5, y, 0.48, 0.1, hex("#4A5260"), { font = Enum.Font.Gotham })
	end
end

local function screenSheet(gui: Instance, _W: number, _H: number, rng: Rng.Rng)
	Core.bg(gui, hex("#FFFFFF"))
	frame(gui, 0, 0, 1, 0.1, hex("#1E7145"))
	label(gui, "Model_v" .. rng:int(3, 41) .. ".xlsx", 0.03, 0.01, 0.6, 0.08, hex("#FFFFFF"), {
		font = Enum.Font.Gotham,
	})
	-- column header strip, then one label per cell so every value sits on its own grid row
	local top, rowH = 0.18, 0.115
	frame(gui, 0, 0.1, 1, 0.08, hex("#E6E6E6"))
	local grid = hex("#D0D4D9")
	for i = 1, 4 do
		frame(gui, i * 0.2, 0.1, 0.004, 0.9, grid)
	end
	for i = 1, 7 do
		frame(gui, 0, top + i * rowH, 1, 0.004, grid)
	end
	local ink, num = hex("#1A1D21"), hex("#0B3D91")
	for col, head in Words.sheetCols do
		label(gui, head, 0.2 * col + 0.015, 0.11, 0.17, 0.06, hex("#4A5260"), {
			font = MONO,
			align = Enum.TextXAlignment.Right,
		})
	end
	for row, name in Words.sheetRows do
		label(gui, name, 0.015, top + (row - 1) * rowH + rowH * 0.18, 0.18, rowH * 0.64, ink, {
			font = Enum.Font.Gotham,
		})
	end
	for col = 1, 4 do
		local base = rng:range(200, 900)
		for row = 1, 7 do
			local v = if row == 3
				then string.format("%.1f%%", rng:range(12, 38))
				elseif row >= 6 then string.format("%.1fx", rng:range(6, 14))
				else string.format("%.0f", base * (1 + col * 0.07) / row)
			label(gui, v, 0.2 * col + 0.015, top + (row - 1) * rowH + rowH * 0.18, 0.17, rowH * 0.64, num, {
				font = MONO,
				align = Enum.TextXAlignment.Right,
			})
		end
	end
	local sel = frame(gui, 0.6, top + rowH * rng:int(0, 6), 0.2, rowH, hex("#FFFFFF"), 1)
	Core.stroke(sel, hex("#1E7145"), 2)
end

local function screenDeck(gui: Instance, _W: number, _H: number, rng: Rng.Rng)
	Core.bg(gui, hex("#FFFFFF"))
	frame(gui, 0, 0, 1, 0.16, hex("#0B1F3A"))
	label(gui, rng:pick(Words.deckTitles), 0.04, 0.025, 0.7, 0.11, hex("#FFFFFF"))
	frame(gui, 0, 0.16, 1, 0.012, hex("#C9A54C"))
	for i = 1, 5 do
		local bh = 0.12 + i * 0.07 + rng:range(-0.03, 0.03)
		frame(gui, 0.06 + (i - 1) * 0.085, 0.88 - bh, 0.06, bh, if i == 5 then hex("#C9A54C") else hex("#173459"))
	end
	label(gui, Words.deckBullets, 0.52, 0.28, 0.45, 0.5, hex("#1A1D21"), {
		font = Enum.Font.Gotham,
		yAlign = Enum.TextYAlignment.Top,
	})
	label(gui, Words.confidential, 0.04, 0.91, 0.5, 0.06, hex("#8A8F98"), { font = Enum.Font.Gotham })
end

local function screenNews(gui: Instance, _W: number, _H: number, rng: Rng.Rng)
	Core.bg(gui, hex("#0E1A2B"))
	local tag = frame(gui, 0.03, 0.08, 0.3, 0.14, hex("#C0392B"))
	label(tag, Words.breaking, 0.06, 0.1, 0.88, 0.8, hex("#FFFFFF"), { align = Enum.TextXAlignment.Center })
	label(gui, rng:pick(Words.headlines), 0.03, 0.28, 0.94, 0.4, hex("#FFFFFF"), {
		font = Enum.Font.GothamBlack,
	})
	frame(gui, 0, 0.8, 1, 0.2, hex("#06101D"))
	label(gui, Core.tickerLine(rng, 3), 0.02, 0.83, 1.4, 0.14, TEXT, { font = MONO, rich = true, wrap = false })
end

local SCREENS: { [string]: ScreenFn } = {
	chart = screenChart,
	candles = screenCandles,
	quotes = screenQuotes,
	terminal = screenTerminal,
	email = screenEmail,
	sheet = screenSheet,
	deck = screenDeck,
	news = screenNews,
}

-- Fills a monitor display part's front face with a glowing screen of `kind` (see KINDS).
function Screens.screen(part: BasePart, kind: string, rng: Rng.Rng): SurfaceGui
	local gui, W, H = Core.surface(part, Enum.NormalId.Front, {
		glow = true,
		brightness = 1.2,
		pps = 100,
		maxDistance = 90,
		name = "Screen",
	})
	local fn: ScreenFn = SCREENS[kind] or screenChart
	fn(gui, W, H, rng)
	gui:SetAttribute("ScreenKind", if SCREENS[kind] then kind else "chart")
	return gui
end

export type TickerOpts = {
	face: Enum.NormalId?,
	text: string?,
	pps: number?,
	color: Color3?,
	background: Color3?,
}

-- LED ticker: SurfaceGui "Ticker" > Frame "Viewport" (clips) > TextLabel "TickerText" (RichText, one line,
-- left aligned, fixed TextSize). Runtime code may replace TickerText.Text and animate Position.X to scroll.
function Screens.ticker(part: BasePart, rng: Rng.Rng, o: TickerOpts?): TextLabel
	local opts: TickerOpts = o or {}
	local gui, _W, H = Core.surface(part, opts.face or Enum.NormalId.Front, {
		glow = true,
		brightness = 1.6,
		pps = opts.pps or 30,
		name = "Ticker",
	})
	local back = opts.background or hex("#050608")
	Core.bg(gui, back)
	-- faint LED dot rows give the band its matrix look
	for i = 0, 3 do
		frame(gui, 0, 0.12 + i * 0.25, 1, 0.02, hex("#16191E"), 0.2)
	end
	local view = frame(gui, 0, 0.08, 1, 0.84, back, 1)
	view.Name = "Viewport"
	view.ClipsDescendants = true
	local text = label(view, opts.text or Core.tickerLine(rng), 0, 0, 1, 1, opts.color or TEXT, {
		font = MONO,
		weight = Enum.FontWeight.Bold,
		rich = true,
		name = "TickerText",
		scaled = false,
		size = math.floor(H * 0.84 * 0.66),
		wrap = false,
	})
	text.TextTruncate = Enum.TextTruncate.None
	-- grow to the full line width so scrolling never relies on text overflowing the label's box
	text.AutomaticSize = Enum.AutomaticSize.X
	gui:SetAttribute("TickerPx", text.TextSize)
	return text
end

return Screens
