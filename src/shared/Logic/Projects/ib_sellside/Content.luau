--!strict
-- Sell-side M&A content (owned by `projects`): every player-facing line of the ib_sellside deal. PURE data and
-- small template builders; the mechanics live in ib_sellside/init.luau. Fictional companies and people only.
-- Templates use "{var}" placeholders filled from the deal's facts (Common.fill).

export type CimVariant = { issue: string, text: string?, typo: string?, note: string }
export type CimElement = { kind: string, clean: string, broken: { CimVariant } }

local Content = {}

Content.title = "Sell-Side M&A"
Content.desc = "Run the sale of a founder-owned company: buyer list, CIM, management Q&A, the bid round and the "
	.. "final negotiation. The better the process, the higher the price above the seller's reserve."

-- Sectors that make good founder-owned sale stories (Logic/Tasks/_shared/Universe ids).
Content.sectors = { "consumer", "staples", "industrials", "healthcare", "software", "logistics", "media" }
Content.adjacent = { "tech", "consumer", "industrials", "logistics", "healthcare", "media" }

Content.fundSuffixes = { "Capital Partners", "Equity Partners", "Capital", "Partners" }
Content.familySuffixes = { "Family Office", "Holdings" }

---------------------------------------------------------------------------------------------------
-- Stage titles and narrative
---------------------------------------------------------------------------------------------------
Content.stages = {
	teaser = { title = "Teaser & Buyer List", brief = "Who gets the call, and what the teaser says" },
	cim = { title = "The CIM", brief = "Catch every error before 40 buyers read it" },
	management = { title = "Management Presentation", brief = "Coach the CEO through the buyers' Q&A" },
	bids = { title = "Bid Round", brief = "Compare the letters of intent and pick a lead" },
	negotiation = { title = "Final Negotiation", brief = "Push the price, protect the deal" },
}

Content.narrative = {
	teaser = "{founder} built {company} over twenty years and wants to sell. Draft the teaser and decide who hears "
		.. "about it.",
	cim = "{buyers} buyers signed NDAs. Your CIM goes out tonight: make it clean.",
	management = "Management presents to the buyers today. Coach {founder} through the Q&A.",
	bids = "First-round letters of intent are in. Compare them and choose who leads into the final round.",
	negotiation = "Final round with {winner}. Push the price without losing the deal.",
}

-- Headers of the parts inside a multi-part stage ("Part 1 of 2 · The teaser").
Content.sections = {
	teaserMcq = "The teaser",
	teaserMatch = "The long list",
	bidsFill = "The letters of intent",
	bidsMcq = "Pick the lead",
}

Content.prompts = {
	teaser = "Answer the teaser questions, then match each buyer on the long list to why they would buy {company}.",
	teaserMatch = "Match each buyer to their angle.",
	teaserMcq = "The teaser and the process.",
	cim = "{codename}'s CIM, page 3: flag every error. Leave the clean lines alone.",
	management = "{speaker} leads the buyer's questions. Pick the best answer each time.",
	bidsFill = "Work out the numbers for {clean}'s letter of intent. Net debt is ${netDebt}M.",
	bidsMcq = "A bid is only worth what you can close.",
	negotiation = "{speaker} calls with {winner}'s final position.",
}

---------------------------------------------------------------------------------------------------
-- Stage 1: teaser (mcq) + buyer list (match)
---------------------------------------------------------------------------------------------------
Content.teaserQuestions = {
	{
		id = "q_teaser",
		text = "The teaser goes to buyers before anyone signs an NDA. Which line must NOT be in it?",
		correct = "The company's name: {company}",
		wrong = {
			"Revenue of about ${rev}M last year",
			"A {sectorLower} business growing about {growth}% a year",
			"An EBITDA margin of about {margin}%",
		},
		explain = "A teaser is anonymous. Buyers only learn the name once they sign an NDA.",
	},
	{
		id = "q_process",
		text = "{founder} wants a quick, quiet sale at the best price. Which process do you run?",
		correct = "A targeted auction: 8–12 likely buyers, NDAs first, then the CIM",
		wrong = {
			"A broad auction: email the full CIM to 150 buyers on day one",
			"Call one buyer and accept their first offer",
			"Post the teaser publicly so anyone can bid",
		},
		explain = "A targeted auction creates competition without leaking the deal to the whole market.",
	},
	{
		id = "q_nda",
		text = "A buyer asks for the CIM before signing the NDA. What do you say?",
		correct = "Happy to send it the moment the NDA is signed",
		wrong = {
			"Send it now to keep them keen",
			"Send it, but ask them to delete it if they pass",
			"Tell them the company's name so they can decide",
		},
		explain = "No NDA, no confidential information. That rule protects the client.",
	},
}

Content.angles = {
	strategic = "Strategic: pays for cost and revenue synergies",
	addon = "Sponsor add-on: bolts it onto a company the fund already owns",
	platform = "Sponsor platform: a new leveraged buyout",
	adjacent = "Adjacent strategic: buys its way into a new market",
	family = "Patient capital: holds for decades, rarely pays the top price",
}
Content.angleDecoy = "Lender: provides debt, doesn't buy companies"

Content.buyerDesc = {
	strategic = "{name}: a {sectorLower} competitor three times {company}'s size",
	addon = "{name}: a private equity fund that already owns {addonTarget}",
	platform = "{name}: a private equity firm with a new ${fundSize}B fund to invest",
	adjacent = "{name}: a {adjacentSector} company expanding into {sectorLower}",
	family = "{name}: a family investment office",
}
Content.matchNotes = {
	strategic = "{name} is a direct competitor: synergies let it pay the most.",
	addon = "{name} already owns {addonTarget}: {company} would be an add-on.",
	platform = "{name} has a new fund: {company} would be a new platform buyout.",
	adjacent = "{name} wants into {sectorLower}: buying {company} is its way in.",
	family = "A family office is patient capital: it holds long and rarely pays top dollar.",
}

Content.teaserHints = {
	"A teaser never names the company. That's what the NDA is for.",
	"Strategic buyers pay for synergies; sponsors pay for cash flow and leverage.",
	"A fund that already owns a similar business is looking for an add-on.",
}

Content.teaserDebrief = {
	great = "{buyers} serious buyers signed NDAs. The long list was spot on.",
	good = "{buyers} buyers signed NDAs and received the CIM.",
	weak = "Only {buyers} buyers took a look. The long list missed obvious names.",
}

---------------------------------------------------------------------------------------------------
-- Stage 2: the CIM (format)
---------------------------------------------------------------------------------------------------
Content.cimIssues = {
	{ id = "typo", text = "Typo or misspelt name" },
	{ id = "numbers", text = "Numbers don't tie out" },
	{ id = "aggressive", text = "Aggressive or misleading claim" },
	{ id = "leak", text = "Gives away the seller's position" },
	{ id = "confidential", text = "Names a customer too early" },
	{ id = "source", text = "Missing source" },
	{ id = "date", text = "Wrong or stale date" },
}

Content.cimHints = {
	"Divide it out: margins and growth rates must tie to the numbers next to them.",
	"An add-back must be a true one-off. Costs that recur every year stay in EBITDA.",
	"The CIM never reveals the seller's minimum price or names customers.",
	"'Guaranteed' never belongs in a forecast.",
}

-- Each element: { kind, clean, broken = { {issue, text, note} } }. The typo variants are built in init.luau.
Content.cimElements = {
	{
		kind = "Cover",
		clean = "{codename}: Confidential Information Memorandum · {company}",
		broken = {
			{
				issue = "leak",
				text = "{codename}: Confidential Information Memorandum · Seller will accept ${reserve}M or more",
				note = "Never put the seller's minimum price in the CIM. Buyers will bid exactly that.",
			},
			{ issue = "typo", typo = "company", note = "The client's name is misspelt on the cover." },
		},
	},
	{
		kind = "Financials",
		clean = "Revenue ${rev}M · Adj. EBITDA ${ebitda}M ({margin}% margin)",
		broken = {
			{
				issue = "numbers",
				text = "Revenue ${rev}M · Adj. EBITDA ${ebitda}M ({badMargin}% margin)",
				note = "{ebitda} ÷ {rev} is {margin}%, not {badMargin}%. The margin doesn't tie.",
			},
		},
	},
	{
		kind = "Growth",
		clean = "Revenue grew {growth}% last year, from ${prevRev}M to ${rev}M",
		broken = {
			{
				issue = "numbers",
				text = "Revenue grew {badGrowth}% last year, from ${prevRev}M to ${rev}M",
				note = "${prevRev}M to ${rev}M is {growth}% growth, not {badGrowth}%.",
			},
		},
	},
	{
		kind = "EBITDA bridge",
		clean = "Adj. EBITDA ${ebitda}M = reported ${reported}M + ${addback}M one-off plant closure costs",
		broken = {
			{
				issue = "aggressive",
				text = "Adj. EBITDA ${ebitda}M = reported ${reported}M + ${addback}M of normal yearly marketing spend",
				note = "Marketing happens every year. Adding it back inflates EBITDA, and diligence will find it.",
			},
		},
	},
	{
		kind = "Customers",
		clean = "Top 10 customers: {top10}% of revenue; the largest is {top1}%",
		broken = {
			{
				issue = "confidential",
				text = "Largest customer: {customer} ({top1}% of revenue, renewal due in March)",
				note = "Customer names stay out of the CIM until the final round.",
			},
		},
	},
	{
		kind = "Market",
		clean = "The {sectorLower} market grows about {market}% a year (Source: industry association data)",
		broken = {
			{
				issue = "source",
				text = "The {sectorLower} market grows about {market}% a year",
				note = "Every market statistic needs a source line.",
			},
		},
	},
	{
		kind = "Outlook",
		clean = "Management case: EBITDA of ${projEbitda}M by {year2}, backed by signed contracts",
		broken = {
			{
				issue = "aggressive",
				text = "Management case: EBITDA of ${bigEbitda}M by {year2}. Guaranteed.",
				note = "Nobody can guarantee projections. 'Guaranteed' kills credibility and invites lawsuits.",
			},
		},
	},
	{
		kind = "Footer",
		clean = "Strictly confidential · Prepared by {firm} · {month} {year}",
		broken = {
			{
				issue = "date",
				text = "Strictly confidential · Prepared by {firm} · {month} {oldYear}",
				note = "The footer is dated {oldYear}: someone used an old template.",
			},
			{ issue = "typo", typo = "firm", note = "Even our own firm's name is misspelt in the footer." },
		},
	},
} :: { CimElement }

Content.cimSummary = {
	great = "A clean CIM. Buyers will read the story, not the typos.",
	bad = "Buyers will find these errors before you do, and bid lower for it.",
}

Content.cimDebrief = {
	great = "Buyers called it the cleanest CIM they'd seen all year.",
	good = "The CIM did its job, with a few questions from buyers.",
	weak = "Buyers spotted errors in the CIM, and their bids got more cautious.",
}

---------------------------------------------------------------------------------------------------
-- Stage 3: management presentation Q&A (dialogue)
---------------------------------------------------------------------------------------------------
Content.managementSpeaker = "{person}, Head of M&A at {buyer}"

Content.managementLines = {
	{
		id = "why_sell",
		text = "Why is {founder} selling now?",
		options = {
			{
				text = "{founder} wants a partner with the scale to take {company} national, and will stay on "
					.. "through the transition.",
				score = 100,
			},
			{
				text = "Honestly, growth is about to slow, so it's a good time to get out.",
				score = 30,
				note = "Never talk down the business you're selling.",
			},
			{
				text = "We're just testing the market. We may not sell at all.",
				score = 15,
				note = "Buyers spend real money on diligence. 'Just testing' sends them home.",
			},
			{
				text = "That's a personal matter for the founder.",
				score = 55,
				note = "Fair, but buyers need a credible reason or they assume the worst.",
			},
		},
	},
	{
		id = "customer",
		text = "Your largest customer is {top1}% of revenue. What if they leave?",
		options = {
			{
				text = "They've renewed for nine years running and are under contract until {year3}. The renewal "
					.. "history is in the data room.",
				score = 100,
			},
			{
				text = "That will never happen. Guaranteed.",
				score = 25,
				note = "Overpromising on the biggest risk destroys credibility.",
			},
			{
				text = "We'd rather not discuss customers.",
				score = 45,
				note = "Dodging the biggest risk makes buyers price it in.",
			},
			{
				text = "If they leave, we'll cut costs to hit the numbers anyway.",
				score = 30,
				note = "Answer the risk with facts, not panic.",
			},
		},
	},
	{
		id = "other_bids",
		text = "Can you tell us what the other bidders are offering?",
		options = {
			{
				text = "We don't share other parties' terms. Interest is strong, and we're keeping to the timetable.",
				score = 100,
			},
			{
				text = "Between us, the top bid so far is around ${reserve}M.",
				score = 0,
				note = "Leaking bids breaks the process and hands away the seller's leverage.",
			},
			{
				text = "There are no other bidders, so make us an offer.",
				score = 10,
				note = "That's a lie about the process, and it kills your leverage.",
			},
			{
				text = "Just put in your best number.",
				score = 55,
				note = "Not wrong, but you missed the chance to signal competition.",
			},
		},
	},
	{
		id = "projections",
		text = "Your plan shows EBITDA up {planUp}% in two years. What's driving it?",
		options = {
			{
				text = "Three contracts already signed for next year, plus price increases customers have "
					.. "accepted. The bridge is on page 31.",
				score = 100,
			},
			{
				text = "{founder} has a strong feeling about it.",
				score = 15,
				note = "Projections need evidence, not feelings.",
			},
			{
				text = "The market is booming. It's a sure thing.",
				score = 30,
				note = "'Sure thing' is a red flag. Show the drivers.",
			},
			{
				text = "We'd suggest you build your own case.",
				score = 50,
				note = "Buyers will, but you should defend yours.",
			},
		},
	},
	{
		id = "team",
		text = "Will the management team stay after a sale?",
		options = {
			{
				text = "The CEO and CFO are open to staying three years and rolling some equity, subject to terms.",
				score = 100,
			},
			{
				text = "They'll all leave the day it closes.",
				score = 20,
				note = "Buyers pay less for a business whose leaders walk out.",
			},
			{
				text = "They'll do whatever you want.",
				score = 45,
				note = "Too eager: you just gave away a negotiating point.",
			},
			{
				text = "We'll discuss that in the final round.",
				score = 60,
				note = "Fine, but a positive signal now would lift the bids.",
			},
		},
	},
	{
		id = "litigation",
		text = "Any litigation or regulatory issues we should know about?",
		options = {
			{
				text = "One small warranty claim, fully reserved and disclosed in the data room. Nothing else.",
				score = 100,
			},
			{
				text = "None at all.",
				score = 5,
				note = "There's a disclosed warranty claim. Denying it is a lie diligence will catch.",
			},
			{
				text = "Nothing that will come out in diligence.",
				score = 0,
				note = "That's hiding a problem. It can sink the deal and your reputation with it.",
			},
			{
				text = "You'd have to ask our lawyers.",
				score = 50,
				note = "Deflecting a basic question looks evasive.",
			},
		},
	},
	{
		id = "seasonality",
		text = "Is the business seasonal? How should we think about working capital?",
		options = {
			{
				text = "Inventory builds ahead of the fourth quarter. The data room has 36 months of monthly "
					.. "working capital so you can set a fair peg.",
				score = 100,
			},
			{
				text = "No seasonality at all.",
				score = 30,
				note = "Almost every {sectorLower} business has some. Overclaiming hurts trust.",
			},
			{
				text = "We'll get back to you on that.",
				score = 50,
				note = "Have the data ready: buyers set their price on it.",
			},
			{
				text = "Just assume it's zero.",
				score = 20,
				note = "A wrong working-capital peg costs the seller real money at closing.",
			},
		},
	},
}

Content.managementHints = {
	"Honest and positive beats clever. Diligence finds everything.",
	"Never share other bidders' terms, and never invent bidders either.",
	"Answer a risk with evidence: contracts, history, data-room pages.",
}

Content.managementDebrief = {
	great = "The buyers left the presentation excited. Expect strong bids.",
	good = "A solid presentation. A couple of answers raised eyebrows.",
	weak = "The Q&A went badly. Buyers will bid with caution.",
}

---------------------------------------------------------------------------------------------------
-- Stage 4: bid round (fill + mcq)
---------------------------------------------------------------------------------------------------
Content.bidColumns = { "Bidder", "Headline EV", "Payment", "Conditions" }

Content.bidTerms = {
	clean = { payment = "All cash", conditions = "Committed financing · 3 weeks of confirmatory diligence" },
	trap = {
		payment = "All cash",
		conditions = "Subject to raising the debt (nothing committed) · 8 weeks of diligence",
	},
	stock = { payment = "60% in its own shares (down 30% this year)", conditions = "4 weeks of diligence" },
	addon = { payment = "All cash", conditions = "Committed financing · 3 weeks of diligence" },
	family = { payment = "All cash", conditions = "No conditions · can close in 2 weeks" },
}

Content.bidFields = {
	mult = "{clean}'s headline bid as a multiple of {company}'s ${ebitda}M EBITDA",
	equity = "Equity value to the seller under {clean}'s bid, after ${netDebt}M of net debt",
	premium = "{clean}'s premium to the seller's ${reserve}M reserve",
}

Content.leadQuestion = "Who leads into the final round?"
Content.leadExplain = "{clean}'s bid is the highest one you can actually close: committed cash, short diligence. "
	.. "A bigger headline with no financing, or in falling shares, is worth less than it looks."
Content.leadOption = "{name}: ${ev}M ({payment})"

Content.backupQuestion = "And the runner-up?"
Content.backupCorrect = "Keep them warm as a backup in case the lead stumbles"
Content.backupWrong = {
	"Tell them they lost and close the process",
	"Share the lead's price so they can top it",
	"Stop answering their calls",
}
Content.backupExplain = "Until the contract is signed, a warm backup bidder is the seller's insurance."

Content.bidHints = {
	"Multiple = bid ÷ EBITDA. Equity value = enterprise value − net debt.",
	"Check the conditions: an uncommitted financing or a stock payment can shrink a big headline.",
	"Premium = bid ÷ reserve − 1.",
}

Content.bidDebrief = "{winner} leads into the final round at ${ev}M."

---------------------------------------------------------------------------------------------------
-- Stage 5: final negotiation (dialogue)
---------------------------------------------------------------------------------------------------
Content.negotiationSpeaker = "{person}, Head of Corporate Development at {winner}"

Content.negotiationLines = {
	{
		id = "best_final",
		text = "We're at ${bid}M. That's our best and final offer.",
		options = {
			{
				text = "We appreciate it. The board needs ${ask}M to sign this week, and another party is still in "
					.. "the process.",
				score = 100,
			},
			{
				text = "Done, we accept.",
				score = 35,
				note = "Accepting a 'best and final' on the spot leaves money on the table.",
			},
			{
				text = "We have three higher offers on the table.",
				score = 5,
				note = "Bluffing about bids you don't have can blow up the deal.",
			},
			{
				text = "Then we're done here.",
				score = 15,
				note = "Walking away from the lead bidder risks the whole sale.",
			},
		},
	},
	{
		id = "exclusivity",
		text = "We need 60 days of exclusivity before we sign.",
		options = {
			{ text = "We can do 21 days, tied to a signed agreement and committed financing.", score = 100 },
			{
				text = "Take as long as you need.",
				score = 30,
				note = "Long exclusivity ends the competition and invites a re-trade.",
			},
			{ text = "No exclusivity, ever.", score = 45, note = "Too rigid: a serious buyer needs some." },
			{
				text = "Sixty days, and we'll stop talking to everyone else today.",
				score = 20,
				note = "You just gave away all of the seller's leverage.",
			},
		},
	},
	{
		id = "guarantee",
		text = "We want {founder} to personally guarantee the projections.",
		options = {
			{
				text = "Nobody guarantees projections. We'll give standard warranties, backed by an insurance policy.",
				score = 100,
			},
			{
				text = "Sure, he'll guarantee them.",
				score = 10,
				note = "That puts the founder's own money behind a forecast.",
			},
			{
				text = "Then we'll lower the projections.",
				score = 40,
				note = "Cutting your own numbers to dodge a bad term lowers the price.",
			},
			{
				text = "Let's leave that to the lawyers.",
				score = 55,
				note = "Push back clearly on off-market terms yourself.",
			},
		},
	},
	{
		id = "earnout",
		text = "Can we pay 30% of the price as an earn-out?",
		options = {
			{
				text = "We could consider 10% tied to next year's EBITDA, with a clear definition and a cap.",
				score = 100,
			},
			{
				text = "Sure, earn-outs are fine.",
				score = 30,
				note = "A big earn-out shifts the risk to the seller, and they're often never paid.",
			},
			{
				text = "No earn-out. The price is the price.",
				score = 60,
				note = "Firm, but a small one can bridge a gap.",
			},
			{ text = "Make it 50% if you like.", score = 15, note = "That's half the price at risk." },
		},
	},
	{
		id = "timing",
		text = "Our board meets Friday. Can you get the seller to sign by Thursday?",
		options = {
			{
				text = "Yes, if we agree ${ask}M today and your markup of the contract comes back by Tuesday.",
				score = 100,
			},
			{ text = "Sure, whatever works for you.", score = 40, note = "Speed is leverage: trade it for price." },
			{ text = "We need at least another month.", score = 25, note = "Delay invites the buyer to cool off." },
			{ text = "Let's see how it goes.", score = 50, note = "A missed chance to tie timing to price." },
		},
	},
	{
		id = "break_fee",
		text = "If our shareholders vote the deal down, we'd rather not owe you anything.",
		options = {
			{
				text = "Then we need a 3% break fee. The seller can't carry the risk of a failed vote for free.",
				score = 100,
			},
			{
				text = "No problem, no fee.",
				score = 35,
				note = "The seller would carry all the risk if the vote fails.",
			},
			{
				text = "We'd want a fee of 20% of the price.",
				score = 50,
				note = "Off-market. Asks like that stall the talks.",
			},
			{
				text = "Then we'll find another buyer.",
				score = 20,
				note = "Threats without a plan weaken your hand.",
			},
		},
	},
}

Content.negotiationHints = {
	"Trade what they want (speed, certainty) for what the seller wants (price).",
	"Never bluff about bids you don't have, and never walk out on your lead bidder.",
	"Push back on off-market terms: personal guarantees, giant earn-outs, endless exclusivity.",
}

Content.negotiationDebrief = {
	great = "You squeezed the last dollars out of {winner} without spooking them.",
	good = "A fair negotiation. {winner} gave a little.",
	weak = "{winner} walked you down. The seller noticed.",
}

---------------------------------------------------------------------------------------------------
-- Outcome
---------------------------------------------------------------------------------------------------
Content.outcome = {
	-- money values arrive formatted ("$640M", "$1.2B")
	closedHeadline = "{buyer} agreed to buy {company} for {price}.",
	pulledHeadline = "No deal: {founder}'s board walked away from a {price} offer.",
	above = "That's {pct} above the board's {reserve} reserve.",
	below = "That's {pct} below the {reserve} reserve, but the board took the certainty.",
	short = "The board's reserve was {reserve}, and the final offer fell {pct} short.",
	competition = "{buyers} buyers in the process kept the pressure on.",
	thin = "With only {buyers} buyers in the process, there was little competition.",
	retradePivot = "{winner} couldn't raise its debt and tried to cut the price. Your backup bidder, {buyer}, stepped "
		.. "in.",
	retradeCut = "{winner} couldn't raise its debt and re-traded the price {cut}% lower after weeks of exclusivity.",
	stockSlide = "{winner}'s shares kept falling during diligence, shaving {cut}% off the value of its offer.",
	familyLow = "{winner} was the safest bidder, and also the cheapest.",
	negotiationUp = "Your final negotiation added {pct} to the price.",
	negotiationDown = "The final negotiation gave away {pct}.",
	dealName = "{codename}: {price} sale of {company}",
	dealNameRunning = "{codename}: sale of {company}",
	dealNamePulled = "{codename}: sale of {company} (pulled)",
	figures = {
		price = "Sale price",
		reserve = "vs. reserve",
		multiple = "EV / EBITDA",
		buyers = "Buyers in",
		fee = "Advisory fee",
	},
}

Content.metrics = {
	client = "Client",
	ebitda = "EBITDA",
	reserve = "Seller's reserve",
	buyers = "Buyers in",
	confidence = "Buyer confidence",
	lead = "Lead bidder",
	pending = "—",
	longList = "Long list",
	high = "High",
	steady = "Steady",
	cautious = "Cautious",
}

return Content
