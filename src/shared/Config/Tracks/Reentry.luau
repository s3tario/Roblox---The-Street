--!strict
-- Re-entry interview content (owned by `careerPath`; spec §6 "Recovery"). Used by Logic/Projects/reentry: a case
-- study, a risk review and a hiring-committee interview. Fictional companies only (the market's tickers).
--   mcq question: { id, text, options = { string }, correct = index, explain }
--   interview line: { id, text, options = { { text, score } } }   score 0..100

return {
	title = "Re-entry interview",
	summary = "Three short stages. Score 60 or better overall to get your career back on track.",
	pass = 60,
	speaker = "Hiring committee",

	stages = {
		{
			id = "case_study",
			title = "Case study",
			prompt = "A client wants your view on a valuation. Show the committee you still know the numbers.",
			count = 3,
		},
		{
			id = "risk_review",
			title = "Risk review",
			prompt = "Risk wants to know you've learned from what happened. Answer as the banker you are now.",
			count = 3,
		},
		{
			id = "interview",
			title = "Interview",
			prompt = "The hiring committee has a few questions. Be honest and specific.",
			count = 3,
		},
	},

	caseStudy = {
		{
			id = "cs_peer_multiple",
			text = "Crestline Retail trades at 8x EBITDA while its peers trade at 11x. Its EBITDA is $50M. What is its implied enterprise value at the peer multiple?",
			options = { "$550M", "$400M", "$600M", "$450M" },
			correct = 1,
			explain = "Implied EV = peer multiple x EBITDA = 11 x $50M = $550M.",
		},
		{
			id = "cs_equity_bridge",
			text = "Enterprise value is $900M, debt is $300M and cash is $100M. What is the equity value?",
			options = { "$1.1B", "$700M", "$500M", "$800M" },
			correct = 2,
			explain = "Equity value = EV - debt + cash = $900M - $300M + $100M = $700M.",
		},
		{
			id = "cs_leverage",
			text = "Leverage is 3.0x with $240M of debt. EBITDA then falls 20% and the debt stays the same. What is leverage now?",
			options = { "2.4x", "3.6x", "3.75x", "4.2x" },
			correct = 3,
			explain = "EBITDA was $80M and is now $64M, so leverage = $240M / $64M = 3.75x.",
		},
		{
			id = "cs_capital_structure",
			text = "Which multiple best compares companies with very different amounts of debt?",
			options = { "P/E", "Dividend yield", "Share price", "EV/EBITDA" },
			correct = 4,
			explain = "EV/EBITDA looks at the whole business before financing, so debt levels don't distort it.",
		},
		{
			id = "cs_terminal",
			text = "A DCF's terminal value is most sensitive to which inputs?",
			options = {
				"The discount rate and the terminal growth rate",
				"Last year's revenue and the tax rate",
				"The share count and the cash balance",
				"The listing date and the ticker",
			},
			correct = 1,
			explain = "Terminal value = cash flow x (1 + g) / (r - g): small changes in r or g move it a lot.",
		},
		{
			id = "cs_growth",
			text = "Bluefin Foods has $200M of revenue growing 4% a year. Roughly what is revenue after two years?",
			options = { "$208M", "$216M", "$224M", "$212M" },
			correct = 2,
			explain = "$200M x 1.04 x 1.04 = about $216M (growth compounds).",
		},
		{
			id = "cs_deal_multiple",
			text = "A buyer pays $1.2B for Orion Aerospace's widget unit, which makes $100M of EBITDA. What multiple is that?",
			options = { "10x", "8.3x", "12x", "14x" },
			correct = 3,
			explain = "$1.2B / $100M = 12x EBITDA.",
		},
		{
			id = "cs_comps_check",
			text = "You're checking a comps table before it goes to the client. Which of these is a real problem?",
			options = {
				"Peers are sorted by size",
				"The median is shown under each column",
				"Every number has a source footnote",
				"One peer appears twice with different multiples",
			},
			correct = 4,
			explain = "A duplicated peer with different numbers means the table is wrong. Fix it before it ships.",
		},
		{
			id = "cs_rates",
			text = "Interest rates rise sharply. What usually happens to valuation multiples for fast-growing companies?",
			options = { "They compress", "They expand", "Nothing changes", "They double" },
			correct = 1,
			explain = "Higher discount rates shrink the value of far-off cash flows, so growth multiples compress.",
		},
	},

	riskReview = {
		{
			id = "rr_limit",
			text = "Your book is $250,000 and the single-name limit is 40%. What's the most you can hold in one ticker?",
			options = { "$40,000", "$100,000", "$250,000", "$62,500" },
			correct = 2,
			explain = "40% of $250,000 is $100,000.",
		},
		{
			id = "rr_stop",
			text = "A position drops 12% after earnings and breaks your stop. What's the disciplined move?",
			options = {
				"Double down to lower the average cost",
				"Remove the stop and wait",
				"Exit as planned and review the thesis",
				"Move it to another account",
			},
			correct = 3,
			explain = "A stop is a decision you made with a clear head. Honour it, then review what you missed.",
		},
		{
			id = "rr_correlation",
			text = "Two of your positions move together almost perfectly. What does that mean for your risk?",
			options = {
				"It's effectively one concentrated bet",
				"Your risk is halved",
				"You're well diversified",
				"It has no effect",
			},
			correct = 1,
			explain = "Highly correlated positions behave like one big position, so the risk adds up.",
		},
		{
			id = "rr_breach",
			text = "Risk flags a limit breach on your book. What do you do first?",
			options = {
				"Wait for the price to recover",
				"Open another position to balance it",
				"Ask risk to raise the limit",
				"Cut the position back inside the limit",
			},
			correct = 4,
			explain = "Get back inside the limit first. Explanations come after the book is compliant.",
		},
		{
			id = "rr_relative",
			text = "Your book is down 6% in a week when the benchmark fell 8%. How did you do relative to the market?",
			options = { "Beat it by 2 points", "Lost 14 points", "Lost 6 points", "Matched it" },
			correct = 1,
			explain = "Relative return = -6% - (-8%) = +2 points. Reviews judge you against the benchmark.",
		},
		{
			id = "rr_drawdown",
			text = "What does maximum drawdown measure?",
			options = {
				"The average daily return",
				"The number of trades",
				"The largest fall from a peak to a trough",
				"The best single day",
			},
			correct = 3,
			explain = "Max drawdown is the worst peak-to-trough loss: how much pain the book went through.",
		},
		{
			id = "rr_binary",
			text = "A stock reports earnings tomorrow and could move 15% either way. How should you size it?",
			options = { "As large as the limit allows", "Smaller than usual", "All in", "With borrowed money" },
			correct = 2,
			explain = "Binary events deserve smaller size: you can't control the outcome, only your exposure.",
		},
	},

	interview = {
		{
			id = "iv_what_happened",
			text = "Walk us through what went wrong at your last firm.",
			options = {
				{
					text = "I took too much risk and ignored the warnings. Here's what I've changed since.",
					score = 100,
				},
				{ text = "The market was unfair to me.", score = 20 },
				{ text = "My boss never liked me.", score = 0 },
				{ text = "Honestly? Nothing went wrong.", score = 10 },
			},
		},
		{
			id = "iv_trust",
			text = "Why should we trust you with a book again?",
			options = {
				{ text = "I size every position inside the limits and write down a stop for each one.", score = 100 },
				{ text = "I'll trade bigger and win it all back quickly.", score = 10 },
				{ text = "Because I really need this job.", score = 35 },
				{ text = "You'll just have to trust me.", score = 15 },
			},
		},
		{
			id = "iv_client",
			text = "A client calls, angry about a late deliverable. What do you do?",
			options = {
				{ text = "Call back right away, own the delay and give a firm new time.", score = 100 },
				{ text = "Let the analyst handle it.", score = 30 },
				{ text = "Finish the work first, then send an email.", score = 45 },
				{ text = "Blame the data provider.", score = 5 },
			},
		},
		{
			id = "iv_five_years",
			text = "Where do you see yourself in five years?",
			options = {
				{ text = "Leading deals here, with a clean risk record.", score = 100 },
				{ text = "Running my own fund by next year.", score = 40 },
				{ text = "I'm not really sure.", score = 30 },
				{ text = "Wherever pays the most.", score = 10 },
			},
		},
		{
			id = "iv_team",
			text = "An analyst on your team made a mistake in a model that went to a client. What now?",
			options = {
				{
					text = "Fix it with them, tell the client it's corrected and add a check so it can't recur.",
					score = 100,
				},
				{ text = "Report them to the boss.", score = 25 },
				{ text = "Quietly fix it and say nothing.", score = 40 },
				{ text = "It's their problem, not mine.", score = 0 },
			},
		},
	},

	feedback = {
		perfect = "Flawless. The committee was impressed.",
		good = "Solid answers. A couple of details to tighten.",
		weak = "The committee has doubts. Review the notes below.",
		interviewGood = "The committee liked your honesty.",
		interviewWeak = "Own what happened and be specific about what you'll do differently.",
	},
}
