--!strict
-- LED ticker band text (owned by `market`). PURE: builds the RichText line MarketService writes into every
-- "TickerBand" / "TickerDisplay" TextLabel named "TickerText" (Assets/Signs tickerBand, Props ticker_board).
--
--   Band.line(quotes, index, phaseText?) -> string    quotes = { {id, price, changePct} }, index = {level, changePct}
--   Band.fit(line, widthStuds?, pps?, textPx?) -> (text, reps)
--       repeats the line (5-space gap) until it spans the band, the way the baked builder did, so a client
--       scroller can wrap at TextBounds.X / reps

local Band = {}

Band.UP = "#2BD67B"
Band.DOWN = "#FF5A5F"
Band.FLAT = "#A7B3C6"
Band.TEXT = "#E8EEF5"
Band.GOLD = "#E3C46F"
Band.GAP = "     "
Band.MAX_REPS = 6

local function change(pct: number): (string, string)
	local v = pct * 100
	if math.abs(v) < 0.005 then
		return Band.FLAT, "0.00%"
	end
	local sign = if v > 0 then "+" else "-"
	return if v > 0 then Band.UP else Band.DOWN, string.format("%s%.2f%%", sign, math.abs(v))
end

function Band.quote(id: string, price: number, pct: number): string
	local color, text = change(pct)
	return string.format(
		'<font color="%s">%s</font> %.2f <font color="%s">%s</font>',
		Band.TEXT,
		id,
		price,
		color,
		text
	)
end

function Band.line(
	quotes: { { id: string, price: number, changePct: number } },
	index: { level: number, changePct: number }?,
	phaseText: string?
): string
	local parts: { string } = {}
	for _, q in quotes do
		table.insert(parts, Band.quote(q.id, q.price, q.changePct))
	end
	if index then
		local color, text = change(index.changePct)
		table.insert(
			parts,
			string.format(
				'<font color="%s">ST10 %.1f</font> <font color="%s">%s</font>',
				Band.GOLD,
				index.level,
				color,
				text
			)
		)
	end
	if phaseText and phaseText ~= "" then
		table.insert(parts, string.format('<font color="%s">%s</font>', Band.GOLD, phaseText))
	end
	return table.concat(parts, Band.GAP)
end

function Band.plainLength(line: string): number
	local plain = string.gsub(line, "<[^>]+>", "")
	return #plain
end

function Band.fit(line: string, widthStuds: number?, pps: number?, textPx: number?): (string, number)
	local w = if type(widthStuds) == "number" and widthStuds > 0 then widthStuds else 40
	local p = if type(pps) == "number" and pps > 0 then pps else 30
	local px = if type(textPx) == "number" and textPx > 0 then textPx else 30
	local needChars = w * p / math.max(px * 0.62, 1)
	local reps = math.clamp(math.ceil(needChars / math.max(Band.plainLength(line), 1)), 1, Band.MAX_REPS)
	-- one extra copy so a scroller can wrap seamlessly
	reps = math.min(Band.MAX_REPS, reps + 1)
	local parts: { string } = table.create(reps, line .. Band.GAP)
	return table.concat(parts), reps
end

return Band
