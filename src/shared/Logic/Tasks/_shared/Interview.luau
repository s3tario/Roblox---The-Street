--!strict
-- Interview content shared by the interview tasks (owned by `work`; contracts §8). PURE data plus generators.
-- mock_interview (practice), interview_ib (first round), superday_interview (final round) and the re-entry
-- case draw from here, so every interview sounds like the same industry.
--
--   Interview.FIT = { RESUME, WHY_BANKING, FAILURE, TEAM, WEAKNESS, WHY_FIRM, QUESTIONS, CURVEBALL }   Bank.Turn
--       vars: {firm}, {field}, {sector}
--   Interview.TECH_EASY / TECH_MEDIUM / TECH_HARD = { Bank.McqEntry }   IB technical questions
--   Interview.math(rng, tier) -> { {id, label, value, unit, tol, scales?, floor?, short, note, hint} }
--       mental-math questions for a fill section (percentages, growth, multiples)
--   Interview.vars(rng, ctx) -> { firm, field, sector }

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)
local Bank = require(script.Parent.Bank)
local Common = require(script.Parent.Common)
local Universe = require(script.Parent.Universe)

local Interview = {}

local RESUME: Bank.Turn = {
	says = { "Walk me through your résumé.", "Tell me about yourself." },
	best = {
		{
			text = "A two-minute story: where I started, why I moved toward finance, what I've done about it, and why that leads me here.",
		},
	},
	good = {
		{
			text = "I go through each line of my résumé in order.",
			note = "Accurate but flat. Tell it as a story that ends with why you're here.",
		},
	},
	weak = {
		{
			text = "Well, I was born in a small town…",
			note = "Too far back. Start where your path toward finance begins.",
		},
	},
	bad = {
		{ text = "It's all on the paper in front of you.", note = "They know. They want to hear you tell it." },
		{
			text = "A ten-minute tour of every job I've had, including the lifeguarding.",
			note = "Keep it to about two minutes and relevant.",
		},
	},
	hint = "Résumé walk-through: about two minutes, told as a story that ends with “which is why I'm here”.",
}

local WHY_BANKING: Bank.Turn = {
	says = { "Why {field}?", "What draws you to {field}?" },
	best = {
		{
			text = "A specific moment: building a valuation for our club showed me I love fast, high-stakes analytical work, and {field} is where that happens every day.",
		},
	},
	good = {
		{ text = "I like finance and I want to learn quickly.", note = "True for everyone. Add a personal example." },
	},
	weak = { { text = "It seemed like the obvious next step.", note = "Show it's a choice you made, not a default." } },
	bad = {
		{ text = "The bonus.", note = "Pay is fine to want, terrible to lead with." },
		{ text = "I didn't get into my first choice.", note = "Never frame the role as a fallback." },
	},
	hint = "Why this field: one personal example, then what you'll bring.",
}

local FAILURE: Bank.Turn = {
	says = { "Tell me about a time you failed.", "Describe a mistake you made and what happened." },
	best = {
		{
			text = "I missed a deadline on a group project because I didn't flag a problem early. I told the team, fixed it overnight, and now I raise risks the day I see them.",
		},
	},
	good = {
		{
			text = "I once got a bad grade and studied harder after.",
			note = "Okay, but say what you specifically changed.",
		},
	},
	weak = {
		{
			text = "I work too hard sometimes.",
			note = "That dodges the question. Interviewers want a real failure and what you learned.",
		},
	},
	bad = {
		{
			text = "I can't think of a time I failed.",
			note = "Everyone fails. Saying you haven't sounds either dishonest or unaware.",
		},
		{ text = "My teammates let me down on a project.", note = "Blaming others is a red flag. Own your part." },
	},
	hint = "Failure question: own it, say what you did, say what you changed.",
}

local TEAM: Bank.Turn = {
	says = {
		"Tell me about a time you worked in a team under pressure.",
		"Give me an example of teamwork on a deadline.",
	},
	best = {
		{
			text = "Situation, my role, the action I took to unblock the team, and the result: we submitted on time and won the case competition.",
		},
	},
	good = {
		{
			text = "I'm a great team player and I get along with everyone.",
			note = "Claims need an example. Give the situation, your action, the result.",
		},
	},
	weak = {
		{ text = "I usually prefer to work alone.", note = "Banking is team work. Show you can deliver with others." },
	},
	bad = {
		{
			text = "I did all the work while the others slacked off.",
			note = "Even if true, it sounds like you can't work with people.",
		},
	},
	hint = "Use situation, action, result. Say what YOU did.",
}

local WEAKNESS: Bank.Turn = {
	says = { "What's your biggest weakness?", "What would your last manager say you need to work on?" },
	best = {
		{
			text = "I used to over-polish slides before checking the numbers. Now I lock the numbers first and ask for feedback earlier.",
		},
	},
	good = {
		{
			text = "Public speaking, but I joined the debate team to work on it.",
			note = "Good: a real weakness plus action. Add what's improved.",
		},
	},
	weak = { { text = "I'm a perfectionist.", note = "The cliché answer. Pick something real and show progress." } },
	bad = {
		{ text = "I don't really have any.", note = "Shows a lack of self-awareness." },
		{
			text = "I struggle to meet deadlines.",
			note = "Honest, but it's the core of the job. Pick a weakness you're actively fixing.",
		},
	},
	hint = "Weakness: real, not fatal for the job, and paired with what you're doing about it.",
}

local WHY_FIRM: Bank.Turn = {
	says = { "Why {firm}?", "Why do you want to work at {firm} specifically?" },
	best = {
		{
			text = "The people I met from {firm} talked about real responsibility early, and your recent {sector} deals are exactly the work I want to learn.",
		},
	},
	good = {
		{
			text = "{firm} has a great reputation.",
			note = "Every firm hears that. Name people you met or deals they did.",
		},
	},
	weak = { { text = "You're hiring and I need a job.", note = "Make them feel chosen, not convenient." } },
	bad = {
		{ text = "Honestly, I applied everywhere.", note = "Never tell a firm it's one of many." },
		{ text = "Your competitor rejected me.", note = "Never present a firm as your backup." },
	},
	hint = "Why this firm: people you met plus specific work they do.",
}

local QUESTIONS: Bank.Turn = {
	says = { "Do you have any questions for us?", "We have a few minutes left. Anything you'd like to ask?" },
	best = {
		{ text = "What does a first-year who really stands out do differently?" },
		{ text = "How does the team give feedback to new analysts?" },
	},
	good = {
		{
			text = "What's the team culture like?",
			note = "Fine, but a sharper question leaves a stronger last impression.",
		},
	},
	weak = { { text = "How many vacation days do I get?", note = "Save logistics for after the offer." } },
	bad = {
		{ text = "No, I'm good.", note = "Always have a question ready. It's your last impression." },
	},
	hint = "Always end with a thoughtful question.",
}

local CURVEBALL: Bank.Turn = {
	says = {
		"Our analysts often work past midnight. How do you feel about that?",
		"It's 11pm and your VP sends new comments due by morning. What do you do?",
	},
	best = {
		{ text = "I'd confirm what's most urgent, get it done, and flag early if anything risks the deadline." },
	},
	good = { { text = "I'm fine with long hours.", note = "Okay, but show HOW you'd handle the pressure." } },
	weak = { { text = "I'd try my best, I guess.", note = "Sound confident and concrete." } },
	bad = {
		{
			text = "I'd reply first thing tomorrow.",
			note = "In banking, a late-night ask usually means tonight. Ask about priorities instead.",
		},
		{
			text = "That sounds like bad management.",
			note = "Criticising the job to the interviewer ends the interview.",
		},
	},
	hint = "Pressure questions: show you prioritise and communicate early.",
}

Interview.FIT = {
	RESUME = RESUME,
	WHY_BANKING = WHY_BANKING,
	FAILURE = FAILURE,
	TEAM = TEAM,
	WEAKNESS = WEAKNESS,
	WHY_FIRM = WHY_FIRM,
	QUESTIONS = QUESTIONS,
	CURVEBALL = CURVEBALL,
}

-- Fit turns that can sit between the opener and the closing question.
Interview.MIDDLE = { WHY_BANKING, FAILURE, TEAM, WEAKNESS, WHY_FIRM, CURVEBALL }

local TECH_EASY: { Bank.McqEntry } = {
	{
		text = "Walk me through the three financial statements. Which one ties them together?",
		correct = "Net income from the income statement starts the cash flow statement, which ends in the cash on the balance sheet",
		wrong = {
			"The balance sheet starts with revenue and ends with net income",
			"They are independent and never link",
			"The cash flow statement is just the income statement with taxes removed",
		},
		explain = "Net income flows into cash flow from operations; the ending cash lands on the balance sheet.",
		hint = "Net income links the income statement to the cash flow statement; cash links it to the balance sheet.",
	},
	{
		text = "What's the difference between enterprise value and equity value?",
		correct = "Enterprise value is the whole business (equity + debt − cash); equity value is just the shareholders' part",
		wrong = {
			"They are the same thing",
			"Equity value always includes debt",
			"Enterprise value only counts cash",
		},
		explain = "EV = equity value + net debt. Buyers of the business inherit the debt and get the cash.",
		hint = "Enterprise value = equity value + debt − cash.",
	},
	{
		text = "Name the three most common ways to value a company.",
		correct = "Comparable companies, precedent transactions and a DCF",
		wrong = {
			"Revenue, profit and headcount",
			"Book value, market share and brand",
			"Dividends, buybacks and stock splits",
		},
		explain = "Trading comps, deal comps and a discounted cash flow are the standard toolkit.",
	},
	{
		text = "Depreciation goes up by $10 and the tax rate is 25%. What happens to net income?",
		correct = "It falls by $7.50",
		wrong = { "It falls by $10", "It rises by $2.50", "Nothing changes" },
		explain = "Pre-tax income drops $10, taxes drop $2.50, so net income falls $7.50.",
		hint = "Remember taxes: a $10 expense costs $10 × (1 − tax rate) after tax.",
	},
}

local TECH_MEDIUM: { Bank.McqEntry } = {
	{
		text = "Walk me through a DCF in one sentence.",
		correct = "Project free cash flows, add a terminal value, and discount it all back at the WACC",
		wrong = {
			"Multiply this year's earnings by the peer P/E",
			"Add up the company's assets and subtract its debt",
			"Average the last three years of revenue",
		},
		explain = "A DCF values the cash the business will generate, discounted for time and risk.",
		hint = "DCF: forecast cash flows, add terminal value, discount at WACC.",
	},
	{
		text = "Which multiple is better for comparing companies with very different debt loads?",
		correct = "EV/EBITDA",
		wrong = { "P/E", "Price/book", "Dividend yield" },
		explain = "EV/EBITDA is capital-structure neutral; P/E is distorted by interest costs.",
	},
	{
		text = "Why do precedent transactions usually show higher multiples than trading comps?",
		correct = "Buyers pay a control premium to take over a company",
		wrong = {
			"Old deals always used bad data",
			"Public companies are always worth more",
			"Precedents ignore debt",
		},
		explain = "Acquirers pay a premium for control and synergies, which shows up in deal multiples.",
	},
	{
		text = "A company raises $100 of debt and holds it as cash. What happens to enterprise value?",
		correct = "Nothing: debt and cash rise by the same amount",
		wrong = { "It rises by $100", "It falls by $100", "It doubles" },
		explain = "EV adds debt and subtracts cash, so +100 and −100 cancel.",
		hint = "Enterprise value adds debt and subtracts cash.",
	},
}

local TECH_HARD: { Bank.McqEntry } = {
	{
		text = "In a DCF, what usually makes up most of the value?",
		correct = "The terminal value",
		wrong = { "Year one's cash flow", "The cash on the balance sheet", "The tax shield on depreciation" },
		explain = "For most companies the terminal value is well over half of the enterprise value.",
	},
	{
		text = "A buyer with a P/E of 20 buys a target at a P/E of 15 using only stock. Accretive or dilutive?",
		correct = "Accretive: the buyer issues expensive paper to buy cheaper earnings",
		wrong = {
			"Dilutive: stock deals always dilute",
			"Neutral: P/E doesn't matter in stock deals",
			"Impossible to tell without the target's revenue",
		},
		explain = "In an all-stock deal, buying a lower P/E target with higher P/E stock raises EPS.",
		hint = "All-stock deal: compare the buyer's P/E with the price paid for the target's earnings.",
	},
	{
		text = "Should the WACC go up or down if a company becomes much riskier?",
		correct = "Up: investors demand a higher return for more risk",
		wrong = { "Down: risk lowers the cost of capital", "It never changes", "Only the tax rate changes" },
		explain = "More risk means a higher cost of equity and debt, so a higher WACC and a lower value.",
	},
	{
		text = "What's a reasonable long-term growth rate in a terminal value?",
		correct = "Roughly the long-run economy's growth, around 2–3%",
		wrong = { "The last year's revenue growth, say 25%", "Exactly the WACC", "Zero: companies never grow forever" },
		explain = "No company can outgrow the economy forever; terminal growth sits near long-run GDP growth.",
	},
}

Interview.TECH_EASY = TECH_EASY
Interview.TECH_MEDIUM = TECH_MEDIUM
Interview.TECH_HARD = TECH_HARD

export type MathQ = {
	id: string,
	label: string,
	value: number,
	unit: string,
	tol: number,
	scales: { number }?,
	floor: number?,
	short: string,
	note: string,
	hint: string,
}

local function pctOf(rng: Rng.Rng, id: string): MathQ
	local p = rng:pick({ 5, 10, 15, 20, 25, 30, 40 })
	local x = rng:int(4, 60) * 20
	local v = x * p / 100
	return {
		id = id,
		label = Common.fill("Quick: what's {p}% of {x}?", { p = p, x = Common.commas(x) }),
		value = v,
		unit = "",
		tol = 0.005,
		short = Common.fill("{p}% of {x}", { p = p, x = Common.commas(x) }),
		note = Common.fill(
			"{x} × {p}% = {v}.",
			{ x = Common.commas(x), p = p, v = Common.commas(v, if v % 1 == 0 then 0 else 1) }
		),
		hint = "Percentages: 10% is one decimal place; build the rest from there.",
	}
end

local function compound(rng: Rng.Rng, id: string): MathQ
	local base = rng:int(2, 9) * 100
	local g = rng:pick({ 10, 20, 50 })
	local v = base * (1 + g / 100) ^ 2
	return {
		id = id,
		label = Common.fill("Revenue is ${b}M and grows {g}% a year. What is it after two years?", { b = base, g = g }),
		value = v,
		unit = "$M",
		tol = 0.01,
		short = "Revenue after two years",
		note = Common.fill(
			"{b} × 1.{gg}² = {v}.",
			{ b = base, gg = string.format("%02d", g), v = Common.commas(v, 0) }
		),
		hint = "Growth compounds: apply the rate once per year.",
	}
end

local function multiple(rng: Rng.Rng, id: string): MathQ
	local ebitda = rng:int(4, 30) * 10
	local m = rng:int(6, 14)
	local v = ebitda * m
	return {
		id = id,
		label = Common.fill(
			"EBITDA is ${e}M and peers trade at {m}x EBITDA. Implied enterprise value?",
			{ e = ebitda, m = m }
		),
		value = v,
		unit = "$M",
		tol = 0.005,
		short = "Implied EV",
		note = Common.fill("{e} × {m} = ${v}M.", { e = ebitda, m = m, v = Common.commas(v) }),
		hint = "Implied value = the metric × the multiple.",
	}
end

local function margin(rng: Rng.Rng, id: string): MathQ
	local rev = rng:int(5, 40) * 20
	local m = rng:pick({ 10, 15, 20, 25, 30, 35, 40 })
	local profit = rev * m / 100
	return {
		id = id,
		label = Common.fill(
			"Revenue is ${r}M and EBITDA is ${p}M. What's the EBITDA margin?",
			{ r = rev, p = Common.commas(profit, if profit % 1 == 0 then 0 else 1) }
		),
		value = m,
		unit = "%",
		tol = 0.01,
		scales = { 1, 100 },
		short = "EBITDA margin",
		note = Common.fill(
			"{p} ÷ {r} = {m}%.",
			{ p = Common.commas(profit, if profit % 1 == 0 then 0 else 1), r = rev, m = m }
		),
		hint = "Margin = profit ÷ revenue.",
	}
end

function Interview.math(rng: Rng.Rng, count: number): { MathQ }
	local makers = rng:shuffle({ pctOf, compound, multiple, margin })
	local out: { MathQ } = {}
	for i = 1, math.min(count, #makers) do
		table.insert(out, makers[i](rng, "m" .. tostring(i)))
	end
	return out
end

function Interview.vars(rng: Rng.Rng, ctx: Common.Ctx): { [string]: string }
	local offer = ctx.offer
	local firm = if offer and type(offer.companyName) == "string"
		then offer.companyName
		else (ctx.companyName or Universe.firm(rng))
	return {
		firm = firm,
		field = if ctx.track == nil or ctx.track == "ib" then "investment banking" else "finance",
		sector = string.lower(Universe.sector(rng:pick(Universe.sectorIds)).name),
	}
end

return Interview
