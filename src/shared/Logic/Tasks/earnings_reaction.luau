--!strict
-- earnings_reaction (owned by `work`; contracts §8): the morning-after earnings note for the coverage team.
-- Kind "call": three to five listed companies (the per-server market's tickers) with a price chart and the
-- overnight news; call each stock "likely up", "roughly flat" or "likely down". Harder tiers add traps (a beat
-- with a guidance cut, a miss with a raise, a beat already priced in) and charts that point the other way.
-- When WorkService passes market facts (ctx.facts[ticker].price), the chart ends near the live price.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Grade = require(script.Parent._shared.Grade)
local Tape = require(script.Parent._shared.Tape)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "earnings_reaction",
	title = "Earnings Reaction",
	desc = "Earnings landed overnight. Read each print and call how the stock trades at the open.",
	kind = "call",
	tracks = { "ib" },
	ranks = { 1, 2 },
	category = "work",
	core = false,
	facts = true,
	stats = { "knowledge", "risk" },
	clientFacing = false,
	timeLimit = 180,
	baseXp = 55,
	basePay = 400,
	cooldown = 240,
}

local OPTIONS = { "Likely up", "Roughly flat", "Likely down" }
local ORDER = { "up", "flat", "down" }

local function livePrice(ctx: Common.Ctx, ticker: string): number?
	local facts = ctx.facts
	if type(facts) ~= "table" then
		return nil
	end
	local f = facts[ticker]
	if type(f) ~= "table" then
		return nil
	end
	local p = f.price
	if type(p) == "number" and p == p and p > 0 and p < 1e7 then
		return p
	end
	return nil
end

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local picks = Common.pickN(rng, Universe.LISTED, 2 + tier) -- 3 / 4 / 5
	local specs: { Build.CallSpec } = {}
	local anyTrap = false
	for _, co in picks do
		local outcome = rng:pick(Tape.OUTCOMES)
		local story = Tape.story(rng, co.name, outcome, tier, { price = livePrice(ctx, co.ticker) })
		anyTrap = anyTrap or story.trap
		table.insert(specs, {
			label = co.name .. " (" .. co.ticker .. ")",
			chart = story.chart,
			news = story.news,
			credit = Tape.credit(outcome, ORDER),
			note = story.note,
		})
	end
	local items, secret = Build.call(rng, specs)
	secret.summary = {
		great = "Your calls are spot on. The desk forwards your note to the whole coverage team.",
		bad = "The open went the other way on most of your calls. Weigh guidance over the headline.",
	}
	local hintLines = {
		"Guidance about next year usually moves a stock more than last quarter's numbers.",
		"A beat that everyone expected after a big run-up is often already in the price.",
		"The chart shows the past; the news decides what happens next.",
	}
	if anyTrap then
		table.insert(hintLines, 2, "At least one print is a trap: read past the headline number.")
	end
	return {
		kind = "call",
		title = Task.title,
		prompt = "Make a call for each company before the opening bell.",
		items = items,
		options = table.clone(OPTIONS),
		hints = Common.hints(ctx, hintLines),
	},
		secret
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
