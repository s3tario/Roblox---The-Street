--!strict
-- Research signals (owned by `market`; spec §7: "an honest, noisy signal of the surprise direction, an edge earned by
-- work, never sold"). PURE.
--
--   Research.accuracy(quality 0..100) -> 0.55 .. 0.90      0.55 + 0.35 * quality / 100
--   Research.signal(seed, ticker, reportDay, surprise, quality) -> Signal
--       Signal = { direction = "up" | "down", beat = boolean, confidence = accuracy }
--
-- One uniform draw per (server seed, ticker, report) decides the call: the call is right when the draw is below the
-- accuracy. Asking again (or asking with the same quality) never changes the answer, so research can't be
-- re-rolled; better work only ever turns a wrong call into a right one, never the reverse.

local Hash = require(script.Parent.Parent.Parent.Util.Hash)

export type Signal = { direction: string, beat: boolean, confidence: number }

local Research = {}

Research.BASE = 0.55
Research.SPAN = 0.35

function Research.accuracy(quality: any): number
	local q = if type(quality) == "number" and quality == quality then math.clamp(quality, 0, 100) else 0
	return Research.BASE + Research.SPAN * q / 100
end

function Research.correct(seed: number, ticker: string, reportDay: number, quality: any): boolean
	return Hash.unit(seed, "research", ticker, reportDay) < Research.accuracy(quality)
end

function Research.signal(seed: number, ticker: string, reportDay: number, surprise: number, quality: any): Signal
	local truth = surprise >= 0
	local beat = if Research.correct(seed, ticker, reportDay, quality) then truth else not truth
	return {
		direction = if beat then "up" else "down",
		beat = beat,
		confidence = math.floor(Research.accuracy(quality) * 100 + 0.5) / 100,
	}
end

return Research
