--!strict
-- mandate_pitch (owned by `work`; contracts §8): pitching a CEO to win the mandate to sell their company.
-- Kind "multi": (1) "mcq" pitch choices: the valuation range to lead with (computed from the peer multiples),
-- the buyer universe and why your bank; (2) "dialogue" with the CEO: rival promises, who does the work, risks
-- and leaks. Credible, specific and honest wins; overpromising loses. Client-facing.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "mandate_pitch",
	title = "Mandate Pitch",
	desc = "The CEO is choosing an adviser to sell the company. Win the mandate with a credible pitch.",
	kind = "multi",
	tracks = { "ib" },
	ranks = { 3, 4, 5 },
	category = "client",
	core = true,
	stats = { "charisma", "network" },
	clientFacing = true,
	timeLimit = 270,
	baseXp = 95,
	basePay = 680,
	cooldown = 300,
}

local CHOICES: { Bank.McqEntry } = {
	{
		text = "Which buyers do you lead with?",
		correct = "Strategic buyers in {sector}, plus two private equity funds that own platforms in the space",
		wrong = {
			"Every listed company, to maximise reach",
			"Only the client's fiercest competitor",
			"Retail investors through an app",
		},
		explain = "A focused list of strategics and well-matched sponsors creates real competition without leaks.",
		hint = "A good buyer list is focused: strategics who gain the most, plus sponsors with a fitting platform.",
	},
	{
		text = "Why should {ceo} pick {firm}?",
		correct = "Recent {sector} deals and the senior team that will actually run this one",
		wrong = {
			"We're the biggest bank in the world",
			"We'll charge the lowest fee",
			"We guarantee the highest price",
		},
		explain = "CEOs hire relevant experience and the people they'll actually work with, not size or promises.",
		hint = "Sell relevant experience and the actual team.",
	},
	{
		text = "How do you open the pitch?",
		correct = "With {ceo}'s goals for the sale, then how the process delivers them",
		wrong = { "With twenty pages on the bank's history", "With your fee", "With a joke about the competitor bank" },
		explain = "Start from the client's objectives; the rest of the book should serve them.",
	},
}

local TURNS: { Bank.Turn } = {
	{
		says = {
			"{rival} told us we're worth {rivalMult}x EBITDA. Why is your range lower?",
			"Another bank promised us {rivalMult}x. Can you match that?",
		},
		best = {
			{
				text = "Peers trade at {lo}x–{hi}x and recent deals agree. We'd rather run a process that beats a credible range than promise a number the market won't pay.",
			},
		},
		good = {
			{
				text = "Our range is based on the comps.",
				note = "Right, but explain why credibility protects the outcome.",
			},
		},
		weak = { { text = "Every bank has its own view.", note = "Don't shrug it off. Show why yours is better." } },
		bad = {
			{
				text = "Fine, we'll say {rivalMult}x too.",
				note = "Matching an inflated promise sets the client up for disappointment.",
			},
			{
				text = "{rival} doesn't know what they're doing.",
				note = "Trashing a rival looks petty. Win on substance.",
			},
		},
		hint = "Defend a credible range with the comps; don't chase a rival's promise.",
	},
	{
		says = { "Who will actually run our deal day to day?", "Will we see you after the pitch, or only juniors?" },
		best = { { text = "Me, with the team in this room. I'll be on every buyer call and every key decision." } },
		good = { { text = "A strong team, with me overseeing.", note = "Be concrete about your own involvement." } },
		weak = { { text = "We'll staff it once we win.", note = "CEOs hire the team they meet. Name them." } },
		bad = {
			{
				text = "Mostly juniors, but they're very cheap.",
				note = "Telling a CEO the A-team won't show up loses the mandate.",
			},
		},
		hint = "CEOs want the senior people in the room on the deal itself.",
	},
	{
		says = { "What could go wrong with a sale?", "What's the biggest risk to the process?" },
		best = {
			{
				text = "Customer concentration could worry buyers. We'd get ahead of it with retention data and new contract wins in the first materials.",
			},
		},
		good = {
			{
				text = "Market conditions could change.",
				note = "True for every deal. Name a risk specific to this company.",
			},
		},
		weak = { { text = "Hard to say this early.", note = "You should have a view on the key risk already." } },
		bad = {
			{
				text = "Nothing. It's a guaranteed home run.",
				note = "No deal is risk-free. Saying so destroys credibility.",
			},
		},
		hint = "Name the specific risk and how you'll manage it.",
	},
	{
		says = { "We're worried our employees will hear about this.", "How do you stop the news leaking?" },
		best = {
			{
				text = "A codename, a tight insider list and NDAs with every buyer. Employees hear when you decide, not before.",
			},
		},
		good = {
			{ text = "We take confidentiality very seriously.", note = "Everyone says that. Explain the controls." },
		},
		weak = {
			{
				text = "Leaks happen, there's not much we can do.",
				note = "A leak can hurt staff and customers. Show the safeguards.",
			},
		},
		bad = {
			{
				text = "A bit of buzz can help the price.",
				note = "Leaking a sale is a breach and can damage the business.",
			},
		},
		hint = "Confidentiality: codename, insider list, NDAs.",
	},
}

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local sectorId = rng:pick(Universe.sectorIds)
	local sector = Universe.sector(sectorId)
	local client = Universe.company(rng, sectorId).name
	local ebitda = rng:int(10, 80) * 5
	local lo = rng:int(
		math.floor(sector.evEbitda[1]),
		math.max(math.floor(sector.evEbitda[1]), math.floor(sector.evEbitda[2]) - 2)
	)
	local hi = lo + rng:int(2, 3)
	local firm = if ctx.companyName then ctx.companyName else Universe.firm(rng)
	local vars = {
		ceo = Universe.person(rng),
		firm = firm,
		rival = Universe.firm(rng, firm),
		sector = string.lower(sector.name),
		lo = lo,
		hi = hi,
		rivalMult = hi + rng:int(4, 7),
	}
	local money = function(x: number): string
		return "$" .. Common.commas(x) .. "M"
	end
	local range: Bank.McqEntry = {
		text = Common.fill(
			"{client}'s LTM EBITDA is ${e}M and {sector} peers trade at {lo}x–{hi}x. Which valuation range goes on the summary page?",
			{ client = client, e = Common.commas(ebitda), sector = vars.sector, lo = lo, hi = hi }
		),
		correct = money(ebitda * lo) .. "–" .. money(ebitda * hi),
		wrong = {
			money(math.floor(ebitda * hi * 1.4)) .. "–" .. money(math.floor(ebitda * hi * 1.7)),
			money(math.floor(ebitda * lo * 0.5)) .. "–" .. money(math.floor(ebitda * lo * 0.7)),
			"Exactly " .. money(math.floor(ebitda * (lo + hi) / 2)) .. ", guaranteed",
		},
		explain = Common.fill(
			"{lo}x–{hi}x of ${e}M EBITDA is the credible range; promising more sets the client up to be disappointed.",
			{
				lo = lo,
				hi = hi,
				e = Common.commas(ebitda),
			}
		),
	}
	local mcqSpecs, mcqHints = Bank.mcq(rng, CHOICES, if tier >= 3 then 2 else 1, vars)
	table.insert(mcqSpecs, 1, Bank.mcqOne(range))
	local questions, mcqSecret = Build.mcq(rng, mcqSpecs)
	local turns = Common.pickN(rng, TURNS, 1 + tier) -- 2 / 3 / 4
	local talkSpecs, talkHints = Bank.dialogue(rng, turns, vars, if tier >= 2 then 4 else 3)
	local lines, talkSecret = Build.dialogue(rng, talkSpecs)
	local hints: { string } = { "The range on the summary page is the peer multiples × the client's EBITDA." }
	for _, h in talkHints do
		table.insert(hints, h)
	end
	for _, h in mcqHints do
		table.insert(hints, h)
	end
	return {
		kind = "multi",
		title = Task.title,
		prompt = Common.fill("{client}'s board is choosing an adviser. You're up against {rival}.", {
			client = client,
			rival = vars.rival,
		}),
		sections = {
			{ kind = "mcq", title = "The pitch book", prompt = "Build the story.", questions = questions },
			{
				kind = "dialogue",
				title = "In the boardroom",
				prompt = "The CEO pushes back.",
				speaker = vars.ceo .. ", CEO of " .. client,
				lines = lines,
			},
		} :: { any },
		hints = Common.hints(ctx, hints),
	}, {
		kind = "multi",
		sections = { mcqSecret, talkSecret },
		weights = { 0.45, 0.55 },
		summary = {
			great = Common.fill("{ceo} calls that evening: “We'd like {firm} to run the sale.” Mandate won.", vars),
			good = Common.fill("{ceo} is impressed. It's between you and {rival}.", vars),
			bad = Common.fill("{ceo} goes with {rival}. Credibility and the right team win mandates.", vars),
		},
	}
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
