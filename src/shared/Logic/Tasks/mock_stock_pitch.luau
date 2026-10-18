--!strict
-- mock_stock_pitch (owned by `work`; contracts §8): the Finance Club stock-pitch competition.
-- Kind "multi": (1) a "call" round on two to four listed companies, reading each chart and its news to make a
-- Buy / Hold / Sell call, then (2) "mcq" judge questions: a price target from a multiple, the thesis and the risks.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Tape = require(script.Parent._shared.Tape)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "mock_stock_pitch",
	title = "Mock Stock Pitch",
	desc = "Pitch stocks to the Finance Club judges: read the charts and the news, make the call, then defend it.",
	kind = "multi",
	student = true,
	category = "campus",
	core = false,
	stats = { "knowledge", "charisma" },
	clientFacing = false,
	timeLimit = 240,
	baseXp = 70,
	basePay = 300,
	cooldown = 300,
}

local OPTIONS = { "Buy", "Hold", "Sell" }
local ORDER = { "up", "flat", "down" } -- outcome each option bets on

local JUDGES: { Bank.McqEntry } = {
	{
		text = "A judge asks what belongs in your investment thesis. Best answer?",
		correct = "Two or three specific reasons the market is mispricing the stock, with catalysts",
		wrong = {
			"The company's full history since it was founded",
			"That the stock went up last month, so it will keep going",
			"Every number from the annual report",
		},
		explain = "A thesis is a short, specific argument for why the price is wrong, plus what will make it right.",
		hint = "Judges want to hear why the market is wrong, not what the company does.",
	},
	{
		text = "Which risk is the most useful one to raise in a pitch?",
		correct = "A specific risk that could break your thesis, and how you'd know",
		wrong = {
			"“There are no real risks”",
			"“The whole market could crash”",
			"“I might be wrong”",
		},
		explain = "Name the risk that would sink your idea and the signal you'd watch. Generic risks add nothing.",
		hint = "A good risk is one that could actually break YOUR idea.",
	},
	{
		text = "A catalyst is…",
		correct = "An upcoming event that should make the market re-price the stock",
		wrong = {
			"The company's largest shareholder",
			"A chart pattern that guarantees a move",
			"Another word for the dividend",
		},
		explain = "Earnings, a product launch, a sale process: catalysts are events that close the gap to your target.",
	},
	{
		text = "Your stock has already doubled this year. A judge asks why it's still a buy. Best response?",
		correct = "Walk through why next year's earnings justify a higher price than today",
		wrong = {
			"“Momentum: it only goes up”",
			"“Everyone in the club owns it”",
			"Agree it's expensive but say it's a buy anyway",
		},
		explain = "Past returns don't matter; only whether today's price undervalues future earnings.",
	},
}

local function priceTarget(rng: Rng.Rng, name: string): (Bank.McqEntry, string)
	local eps = rng:int(15, 60) / 10
	local mult = rng:int(12, 24)
	local target = eps * mult
	local price = math.floor(target * rng:range(0.72, 0.9) + 0.5)
	local fmt = function(x: number): string
		return "$" .. string.format("%.0f", x)
	end
	return {
		text = Common.fill(
			"{name} trades at ${price}. You expect EPS of ${eps} next year and think it deserves the peer multiple of {mult}x. What's your price target?",
			{ name = name, price = price, eps = string.format("%.2f", eps), mult = mult }
		),
		correct = fmt(target),
		wrong = { fmt(price * 1.1), fmt(eps * (mult - 6)), fmt(target * 1.5) },
		explain = Common.fill("Target = EPS × multiple = {eps} × {mult} ≈ {t}.", {
			eps = string.format("%.2f", eps),
			mult = mult,
			t = fmt(target),
		}),
	},
		"Price target = expected EPS × the multiple you think it deserves."
end

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local hints: { string } = {
		"Read the news first: earnings surprises and guidance move stocks more than last month's chart.",
	}

	-- 1. calls
	local count = 1 + tier -- 2 / 3 / 4
	local picks = Common.pickN(rng, Universe.LISTED, count)
	local callSpecs: { Build.CallSpec } = {}
	for _, co in picks do
		local outcome = rng:pick(Tape.OUTCOMES)
		local story = Tape.story(rng, co.name, outcome, tier)
		table.insert(callSpecs, {
			label = co.name .. " (" .. co.ticker .. ")",
			chart = story.chart,
			news = story.news,
			credit = Tape.credit(outcome, ORDER),
			note = story.note,
		})
	end
	local items, callSecret = Build.call(rng, callSpecs)

	-- 2. judges
	local target, targetHint = priceTarget(rng, picks[1].name)
	local judgeSpecs, judgeHints = Bank.mcq(rng, JUDGES, if tier >= 3 then 2 else 1)
	table.insert(judgeSpecs, 1, Bank.mcqOne(target))
	table.insert(hints, targetHint)
	for _, h in judgeHints do
		table.insert(hints, h)
	end
	local questions, mcqSecret = Build.mcq(rng, judgeSpecs)

	local payload = {
		kind = "multi",
		title = Task.title,
		prompt = "Make your calls, then take the judges' questions.",
		sections = {
			{
				kind = "call",
				title = "Your calls",
				prompt = "For each stock: Buy, Hold or Sell?",
				items = items,
				options = table.clone(OPTIONS),
			},
			{
				kind = "mcq",
				title = "Judges' questions",
				prompt = "The judges push back on your pitch.",
				questions = questions,
			},
		} :: { any },
		hints = Common.hints(ctx, hints),
	}
	return payload,
		{
			kind = "multi",
			sections = { callSecret, mcqSecret },
			weights = { 0.6, 0.4 },
			summary = {
				great = "The judges award you first place. Your pitch goes in the club's newsletter.",
				bad = "The judges weren't convinced. Next time, lead with the news and a clear target.",
			},
		}
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
