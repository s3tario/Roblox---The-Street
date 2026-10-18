--!strict
-- Market headlines (owned by `market`). PURE: fills Config/Tickers/News templates with a seeded Rng.
--
--   News.pick(kind, vars, rng) -> string          a filled template of that kind (the kind itself when unknown)
--   News.reason(sectorId, up, rng) -> string       a plausible cause for a big move
--   News.catalyst(key, phase, vars) -> string      phase "announce" | "good" | "bad"
--   News.pct(ratio, decimals?) -> "+3.2%"          News.money(x) -> "$1.23"   News.level(x) -> "4,812.4"

local Tickers = require(script.Parent.Parent.Parent.Config.Tickers)
local Format = require(script.Parent.Parent.Parent.Util.Format)
local Rng = require(script.Parent.Parent.Parent.Util.Rng)

local News = {}

local templates: { [string]: { string } } = Tickers.news.templates :: any

function News.pct(ratio: number, decimals: number?): string
	return Format.pct(ratio, decimals or 1)
end

function News.money(x: number): string
	return Format.money(x, 2)
end

function News.level(x: number): string
	return Format.commas(x, 1)
end

function News.pick(kind: string, vars: { [string]: any }, rng: Rng.Rng): string
	local list = templates[kind]
	if not list or #list == 0 then
		return kind
	end
	return Tickers.fill(rng:pick(list), vars)
end

function News.reason(sectorId: string, up: boolean, rng: Rng.Rng): string
	local r = Tickers.news.reasons[sectorId]
	if not r then
		return if up then "buyers step in" else "sellers take control"
	end
	local list = if up then r.up else r.down
	return rng:pick(list)
end

function News.catalyst(key: string, phase: string, vars: { [string]: any }): string
	local c = Tickers.news.catalysts[key]
	if not c then
		return key
	end
	local template = if phase == "announce" then c.announce elseif phase == "good" then c.good else c.bad
	return Tickers.fill(template, vars)
end

return News
