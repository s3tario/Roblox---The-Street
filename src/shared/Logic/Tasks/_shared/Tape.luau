--!strict
-- Market stories for "call" payloads (owned by `work`; contracts §8 call kind). PURE.
-- A story is a short price chart plus news lines whose content decides what the stock should do next. Easy stories
-- have a chart that agrees with the news; harder ones add traps (a beat with a guidance cut, a miss with a raise,
-- good news already priced in) and charts that point the other way, so the player learns that news and guidance
-- move a stock more than its last few weeks do.
--
--   Tape.OUTCOMES = { "up", "flat", "down" } :: { string }
--   Tape.chart(rng, start, n, trend, vol) -> {number}          n prices; trend = total move over the window
--   Tape.story(rng, name, outcome, tier, opts?) -> Story        opts = { price? (anchors the chart) }
--       Story = { outcome, chart, news = {string}, note, trap: boolean }
--   Tape.credit(outcome, order?) -> { [optionIndex] = credit }  order = outcome per option (default up/flat/down):
--       the right call 1, a neighbouring call 0.35, the opposite call 0

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent.Common)

export type Story = { outcome: string, chart: { number }, news: { string }, note: string, trap: boolean }

local Tape = {}

Tape.OUTCOMES = { "up", "flat", "down" } :: { string }

local function r2(x: number): number
	return math.floor(x * 100 + 0.5) / 100
end

function Tape.chart(rng: Rng.Rng, start: number, n: number, trend: number, vol: number): { number }
	local out: { number } = {}
	local p = math.max(1, start)
	local step = trend / math.max(1, n - 1)
	table.insert(out, r2(p))
	for _ = 2, n do
		p = math.max(0.5, p * (1 + step + rng:normal(0, vol)))
		table.insert(out, r2(p))
	end
	return out
end

type Template = { text: string, note: string }

-- {name} plus numbers filled by story(): beat, miss, growth, raise, cut, deal, buyback, run
local CLEAN: { [string]: { Template } } = {
	up = {
		{
			text = "{name} beat quarterly earnings estimates by {beat}% and raised full-year guidance.",
			note = "{name}: a beat AND a raise is the classic set-up for a move up.",
		},
		{
			text = "{name} reported record revenue, up {growth}% from last year, and announced a ${buyback}M share buyback.",
			note = "{name}: strong growth plus a buyback signals confidence; the stock should rise.",
		},
		{
			text = "{name} won a multi-year contract worth about ${deal}M and lifted its margin target.",
			note = "{name}: a big new contract and higher margins raise future earnings.",
		},
	},
	flat = {
		{
			text = "{name} reported results in line with estimates and kept its guidance unchanged.",
			note = "{name}: no surprise either way usually means little movement.",
		},
		{
			text = "Mixed quarter at {name}: revenue slightly ahead, margins slightly behind, guidance reaffirmed.",
			note = "{name}: the good and the bad roughly cancel out.",
		},
	},
	down = {
		{
			text = "{name} missed earnings estimates by {miss}% and cut full-year guidance.",
			note = "{name}: a miss plus a guidance cut is the classic set-up for a drop.",
		},
		{
			text = "{name}'s largest customer is switching to a competitor, and the CFO resigned unexpectedly.",
			note = "{name}: losing a key customer and a surprise CFO exit both hit future earnings.",
		},
		{
			text = "Regulators opened an inquiry into how {name} books its revenue.",
			note = "{name}: an accounting inquiry adds risk investors won't wait to price in.",
		},
	},
}

local TRAPS: { [string]: { Template } } = {
	up = {
		{
			text = "{name} missed this quarter by {miss}% on a one-off charge, but raised next year's guidance well above consensus.",
			note = "{name}: the miss was a one-off; the raised guidance is what investors pay for.",
		},
	},
	flat = {
		{
			text = "{name} beat estimates by {beat}%, but the beat was widely expected after a {run}% run-up into the print.",
			note = "{name}: an expected beat after a big run-up is already in the price.",
		},
	},
	down = {
		{
			text = "{name} beat estimates by {beat}%, but guided next year {cut}% below consensus as demand slows.",
			note = "{name}: guidance matters more than the last quarter; a weak outlook outweighs the beat.",
		},
	},
}

local NOISE = {
	"Sector peers traded {peer}% {dir} this week.",
	"Options volume in {name} was about twice its usual level ahead of the report.",
	"A brokerage repeated its neutral rating on {name}.",
	"The wider market was {calm} on the day.",
}

function Tape.story(rng: Rng.Rng, name: string, outcome: string, tier: number, opts: { price: number? }?): Story
	local o: { price: number? } = opts or {}
	local price = o.price
	local trap = tier >= 2 and rng:chance(if tier >= 3 then 0.5 else 0.25)
	local pool = (if trap then TRAPS else CLEAN)[outcome] or CLEAN.flat
	local tpl = rng:pick(pool)
	local vars = {
		name = name,
		beat = rng:int(3, 14),
		miss = rng:int(3, 12),
		growth = rng:int(12, 38),
		raise = rng:int(4, 12),
		cut = rng:int(6, 18),
		deal = rng:int(12, 90) * 10,
		buyback = rng:int(5, 40) * 50,
		run = rng:int(18, 45),
		peer = rng:int(1, 4),
		dir = if rng:chance(0.5) then "higher" else "lower",
		calm = rng:pick({ "calm", "slightly lower", "slightly higher", "quiet" }),
	}
	local news: { string } = { Common.fill(tpl.text, vars) }
	if tier >= 2 then
		table.insert(news, Common.fill(rng:pick(NOISE), vars))
	end
	-- easy charts agree with the news; harder ones may point the other way (the news decides)
	local trend: number
	local fit = outcome
	if tier >= 2 and rng:chance(if tier >= 3 then 0.5 else 0.3) then
		fit = rng:pick(Tape.OUTCOMES)
	end
	if trap and outcome == "flat" then
		fit = "up" -- the run-up into the print
	end
	if fit == "up" then
		trend = rng:range(0.06, 0.18)
	elseif fit == "down" then
		trend = -rng:range(0.06, 0.18)
	else
		trend = rng:range(-0.02, 0.02)
	end
	local start = if price and price > 0 then price / (1 + trend) else rng:range(20, 180)
	local chart = Tape.chart(rng, start, 16, trend, if tier >= 3 then 0.018 else 0.012)
	return { outcome = outcome, chart = chart, news = news, note = Common.fill(tpl.note, vars), trap = trap }
end

function Tape.credit(outcome: string, order: { string }?): { [number]: number }
	local list: { string } = order or Tape.OUTCOMES
	local rankOf: { [string]: number } = { up = 1, flat = 2, down = 3 }
	local out: { [number]: number } = {}
	for i, o in list do
		local d = math.abs((rankOf[o] or 2) - (rankOf[outcome] or 2))
		out[i] = if d == 0 then 1 elseif d == 1 then 0.35 else 0
	end
	return out
end

return Tape
