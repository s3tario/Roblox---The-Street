--!strict
-- IPO content (owned by `projects`): every player-facing line of the ipo deal. PURE data; the mechanics live in
-- ipo/init.luau. Fictional companies, funds and people only. Templates use "{var}" placeholders filled from the
-- deal's facts (Common.fill); money values arrive formatted unless a template shows "$" itself.

export type Variant = { issue: string, text: string?, typo: string?, note: string }
export type Element = { kind: string, clean: string, broken: { Variant } }
export type Option = { text: string, score: number, note: string? }
export type Line = { id: string, text: string, options: { Option } }

local Content = {}

Content.title = "Take a Company Public (IPO)"
Content.desc = "Pick the right client, value it, polish the pitchbook, win over investors on the roadshow and price "
	.. "the deal. The IPO-day pop tells the Street how you did: 10–25% is the sweet spot."

-- Sectors with good public comparables (Logic/Tasks/_shared/Universe ids).
Content.sectors = { "software", "tech", "healthcare", "consumer", "staples", "industrials", "logistics", "media" }

Content.fundNames = {
	"Granite Bay Investors",
	"Northgate Asset Management",
	"Silverline Funds",
	"Harborstone Capital",
	"Old Meadow Partners",
	"Bellwether Global",
	"Cedar Point Advisors",
	"Ravenhill Investments",
}

---------------------------------------------------------------------------------------------------
-- Stage titles and narrative
---------------------------------------------------------------------------------------------------
Content.stages = {
	pick = { title = "Choose the Client", brief = "Which company is ready for the public markets?" },
	valuation = { title = "Valuation", brief = "Comps and a DCF set the price range" },
	pitchbook = { title = "The Pitchbook", brief = "Catch every error before the client's board sees it" },
	roadshow = { title = "The Roadshow", brief = "Win over the investors who'll buy the shares" },
	pricing = { title = "Pricing & Allocation", brief = "Set the offer price and decide who gets the shares" },
}

Content.sections = {
	pickMcq = "The candidates",
	structureMcq = "The offering",
	bookFill = "The order book",
	alloc = "Allocation",
}

Content.narrative = {
	pick = "Your MD wants an IPO mandate this quarter. Three private companies took the meeting. Pick the one "
		.. "that's ready.",
	valuation = "{company} hired {firm} to take it public. Build the valuation that sets the price range.",
	pitchbook = "The board meets tomorrow. Your pitchbook goes in the pack tonight: make it clean.",
	roadshow = "Roadshow week: {company}'s CEO meets the biggest investors. Prepare the answers.",
	pricing = "The book is closed. Set the offer price and allocate the shares.",
}

Content.prompts = {
	pick = "Read the three profiles, then answer the questions.",
	valuation = "Peers trade at the multiples below. Next year's free cash flow is ${fcf}M, the WACC is {wacc}% "
		.. "and long-term growth is {g}%. Net debt is ${netDebt}M and there are {shares}M shares.",
	pitchbook = "{codename}'s pitchbook, page 4: flag every error. Leave the clean lines alone.",
	roadshow = "{speaker} has the first question.",
	bookFill = "{sold}M shares are on offer. The day-one price will settle where the book is exactly covered.",
	bookFillOrders = "{sold}M shares are on offer. The day-one price will settle where orders equal the shares on "
		.. "offer.",
	alloc = "Split the shares between investor types (percent of the deal).",
}

---------------------------------------------------------------------------------------------------
-- Stage 1: choose the client (mcq)
---------------------------------------------------------------------------------------------------
Content.candidateLine = "{name} ({sector}): revenue ${rev}M, growing {growth}% a year, {margin}% EBITDA margin. {note}"

Content.candidateNotes = {
	ready = "Three years of audited accounts, a strong finance team and an independent board.",
	governance = "The founder controls every vote through super-voting shares, and the company lends cash to the "
		.. "founder's other businesses.",
	slowing = "Growth fell from 30% last year and losses are widening.",
	early = "Only one year of audited accounts, and no finance chief yet.",
	cyclical = "Profits tripled this year on a commodity price spike that analysts expect to reverse.",
}

Content.flaws = {
	governance = "Investors balked at the founder's super-voting shares and the loans to related companies.",
	slowing = "Investors worried that growth was fading fast.",
	early = "Investors doubted the numbers: one year of audited accounts isn't enough.",
	cyclical = "Investors priced in the commodity spike reversing.",
}

Content.pickQuestion = "Which company is ready to go public?"
Content.pickExplain = "{ready} is profitable, growing and ready for public-company reporting. The others carry a flaw "
	.. "investors will punish."

Content.structureQuestions = {
	{
		id = "q_float",
		text = "How much of the company should the IPO sell?",
		correct = "15–25% of the shares: enough to trade freely, without the founders losing control",
		wrong = {
			"90% on day one, so the founders can cash out",
			"1%: just enough to get a listing",
			"Every share the founders own, all at once",
		},
		explain = "A 15–25% float gives the shares enough liquidity without flooding the market.",
	},
	{
		id = "q_proceeds",
		text = "What use of the money will IPO investors like best?",
		correct = "Growth: new capacity, R&D, and repaying expensive debt",
		wrong = {
			"A special dividend to the current owners",
			"Keep it secret: it's none of their business",
			"A new headquarters and a corporate jet",
		},
		explain = "Investors buy into growth. Proceeds that leave the company straight away are a red flag.",
	},
	{
		id = "q_lockup",
		text = "What should insiders agree to before the IPO?",
		correct = "A 180-day lock-up: no selling shares for six months after the listing",
		wrong = {
			"Nothing: they can sell on day one",
			"A promise to buy more shares if the price falls",
			"To sell half their shares in the first week",
		},
		explain = "A lock-up stops insiders dumping shares and crushing the price after the listing.",
	},
}

Content.pickHints = {
	"Look for growth, profits, clean governance and audited history.",
	"A 15–25% float is the norm for a first listing.",
	"Investors want proceeds that grow the business, not cash that walks out the door.",
}

Content.pickDebrief = {
	ready = "{company} signed the mandate letter. Good pick.",
	flawed = "{company} signed the mandate, but investors will have questions.",
}

---------------------------------------------------------------------------------------------------
-- Stage 2: valuation (fill)
---------------------------------------------------------------------------------------------------
Content.compColumns = { "Peer", "EV ($M)", "EBITDA ($M)", "EV / EBITDA" }

Content.valuationFields = {
	median = "Median peer EV / EBITDA",
	comps = "Enterprise value from comps: the median multiple × {company}'s ${ebitda}M EBITDA",
	dcf = "Enterprise value from the DCF: FCF ÷ (WACC − growth)",
	perShare = "Value per share: the average of the two EVs, minus net debt, divided by {shares}M shares",
}
Content.valuationShort = {
	median = "Median multiple",
	comps = "Comps EV",
	dcf = "DCF EV",
	perShare = "Value per share",
}
Content.valuationNotes = {
	median = "With four peers, the median is the average of the middle two: {a}x and {b}x.",
	dcf = "{fcf} ÷ ({wacc}% − {g}%) = {dcf}.",
	perShare = "(({comps} + {dcf}) ÷ 2 − {netDebt}) ÷ {shares}M shares = {perShare}.",
}

Content.valuationHints = {
	"The median of four numbers is the average of the middle two.",
	"A growing perpetuity is worth FCF ÷ (WACC − g). Use decimals: 9% − 3% = 0.06.",
	"Equity value = enterprise value − net debt. Divide by the share count for a per-share value.",
}

Content.valuationDebrief = {
	great = "A rock-solid valuation. The range is set at {range}.",
	good = "The valuation holds up. The range is set at {range}.",
	weak = "Shaky numbers, but the range is set at {range}. Investors will check your work.",
}

---------------------------------------------------------------------------------------------------
-- Stage 3: the pitchbook (format)
---------------------------------------------------------------------------------------------------
Content.issues = {
	{ id = "typo", text = "Typo or misspelt name" },
	{ id = "numbers", text = "Numbers don't tie out" },
	{ id = "scale", text = "Wrong units or scale" },
	{ id = "aggressive", text = "Aggressive or misleading claim" },
	{ id = "confidential", text = "Reveals confidential information" },
	{ id = "source", text = "Missing source" },
	{ id = "date", text = "Wrong or stale date" },
}

Content.elements = {
	{
		kind = "Cover",
		clean = "{codename}: Initial Public Offering · Discussion materials for the board of {company}",
		broken = {
			{ issue = "typo", typo = "company", note = "The client's name is misspelt on the cover." },
		},
	},
	{
		kind = "Financials",
		clean = "Revenue ${rev}M (+{growth}%) · EBITDA ${ebitda}M ({margin}% margin)",
		broken = {
			{
				issue = "numbers",
				text = "Revenue ${rev}M (+{growth}%) · EBITDA ${ebitda}M ({badMargin}% margin)",
				note = "{ebitda} ÷ {rev} is {margin}%, not {badMargin}%.",
			},
			{
				issue = "scale",
				text = "Revenue ${rev}B (+{growth}%) · EBITDA ${ebitda}M ({margin}% margin)",
				note = "Revenue is in millions, not billions. A units slip like that ends up in the newspapers.",
			},
		},
	},
	{
		kind = "Peer multiples",
		clean = "Peer median EV / EBITDA of {median}x (Source: market data as of {month} {year})",
		broken = {
			{
				issue = "source",
				text = "Peer median EV / EBITDA of {median}x",
				note = "Market data always needs a source and a date.",
			},
			{
				issue = "date",
				text = "Peer median EV / EBITDA of {median}x (Source: market data as of {month} {oldYear})",
				note = "Peer multiples from {oldYear} are stale. Markets have moved since.",
			},
		},
	},
	{
		kind = "Valuation",
		clean = "Implied value of ${valueLo}–${valueHi} per share",
		broken = {
			{
				issue = "numbers",
				text = "Implied value of ${valueHi}–${valueLo} per share",
				note = "The range runs backwards: the low end must come first.",
			},
		},
	},
	{
		kind = "Offering",
		clean = "Offering: {sold}M shares, {floatPct}% of the company",
		broken = {
			{
				issue = "numbers",
				text = "Offering: {sold}M shares, {badFloat}% of the company",
				note = "{sold}M of {shares}M shares is {floatPct}%, not {badFloat}%.",
			},
		},
	},
	{
		kind = "Use of proceeds",
		clean = "Use of proceeds: new capacity, R&D and repaying the ${loan}M term loan",
		broken = {
			{
				issue = "aggressive",
				text = "Use of proceeds: new capacity, R&D and a share price guaranteed to double within a year",
				note = "Nobody can promise a share price. Claims like that invite regulators and lawsuits.",
			},
		},
	},
	{
		kind = "Investors",
		clean = "Target investors: long-only funds and pensions, with a retail tranche",
		broken = {
			{
				issue = "confidential",
				text = "Anchor investor: {anchor} has privately agreed to buy 25% of the deal",
				note = "An anchor's private commitment stays confidential until the launch.",
			},
		},
	},
	{
		kind = "Footer",
		clean = "Strictly confidential · {firm} Equity Capital Markets · {month} {year}",
		broken = {
			{ issue = "typo", typo = "firm", note = "Our own firm's name is misspelt in the footer." },
			{
				issue = "date",
				text = "Strictly confidential · {firm} Equity Capital Markets · {month} {oldYear}",
				note = "The footer is dated {oldYear}: someone reused an old deck.",
			},
		},
	},
} :: { Element }

Content.pitchbookHints = {
	"Divide it out: margins, percentages and ranges must tie to the numbers next to them.",
	"Check units: millions and billions are easy to swap.",
	"Market data needs a source and a current date; private commitments stay private.",
}

Content.pitchbookSummary = {
	great = "A flawless pitchbook. The board noticed.",
	bad = "The board's lawyers will find these before the regulator does.",
}

Content.pitchbookDebrief = {
	great = "The board loved the pitchbook and approved the IPO on the spot.",
	good = "The board approved the IPO after a few questions about the deck.",
	weak = "The board approved the IPO, but asked who checked the pitchbook.",
}

---------------------------------------------------------------------------------------------------
-- Stage 4: the roadshow (dialogue)
---------------------------------------------------------------------------------------------------
Content.roadshowSpeaker = "{person}, Portfolio Manager at {fund}"

Content.roadshowLines = {
	{
		id = "why_now",
		text = "Why is {company} going public now?",
		options = {
			{
				text = "To fund the next stage of growth. The business is profitable, growing {growth}% a year, and "
					.. "ready for public-company reporting.",
				score = 100,
			},
			{
				text = "The founders want to cash out before growth slows.",
				score = 20,
				note = "Never suggest the insiders are selling at the top.",
			},
			{ text = "The market is hot, so why not?", score = 40, note = "Timing alone isn't a reason to own a stock." },
			{
				text = "We need the money to cover our losses.",
				score = 25,
				note = "Investors fund growth, not holes in the balance sheet.",
			},
		},
	},
	{
		id = "insiders",
		text = "Are the insiders selling any shares in the IPO?",
		options = {
			{
				text = "No. Management isn't selling, and every insider has signed a 180-day lock-up.",
				score = 100,
			},
			{ text = "Some, but we can't say how much.", score = 40, note = "Vague answers on insider selling spook investors." },
			{
				text = "Yes, the founders are selling most of their stake.",
				score = 15,
				note = "If the founders are leaving, why should anyone buy in?",
			},
			{ text = "Whatever the market wants.", score = 45, note = "Have a clear answer ready on insider selling." },
		},
	},
	{
		id = "guidance",
		text = "Can you tell us how next quarter is going?",
		options = {
			{
				text = "We stick to what's in the prospectus: our long-term targets and the risk factors. We don't "
					.. "give new numbers on the roadshow.",
				score = 100,
			},
			{
				text = "Between us, next quarter is tracking 20% ahead of plan.",
				score = 0,
				note = "Sharing numbers outside the prospectus is selective disclosure. It can stop the deal.",
			},
			{
				text = "We'll beat every estimate. Guaranteed.",
				score = 15,
				note = "Promises like that come back as lawsuits when a quarter misses.",
			},
			{ text = "No comment.", score = 55, note = "Right to hold back, but explain why: the prospectus is the rulebook." },
		},
	},
	{
		id = "competition",
		text = "{peer} is three times your size. Why do you win?",
		options = {
			{
				text = "We're growing twice as fast, and {retention}% of our customers renew every year. The cohort "
					.. "data is on page 47 of the prospectus.",
				score = 100,
			},
			{ text = "We don't really have competitors.", score = 20, note = "Everyone has competitors. Denial looks naive." },
			{ text = "They copy everything we do.", score = 35, note = "Complaining isn't a strategy. Show the evidence." },
			{
				text = "We're the cheapest option.",
				score = 50,
				note = "Competing on price alone makes investors worry about margins.",
			},
		},
	},
	{
		id = "proceeds",
		text = "How will you spend the money you raise?",
		options = {
			{
				text = "Most of it on new capacity and R&D, and the rest to repay the ${loan}M term loan, as the "
					.. "prospectus sets out.",
				score = 100,
			},
			{ text = "We haven't decided yet.", score = 30, note = "Investors won't fund a plan you don't have." },
			{
				text = "A special dividend to the current owners.",
				score = 15,
				note = "Money that leaves the company straight away is a red flag.",
			},
			{
				text = "Acquisitions, but we can't say which.",
				score = 50,
				note = "Possible, but give a framework so investors can judge it.",
			},
		},
	},
	{
		id = "risk",
		text = "What's your biggest risk?",
		options = {
			{
				text = "Customer concentration: our largest customer is {top1}% of revenue. They've signed a five-year "
					.. "renewal, and the risk factors explain how we're diversifying.",
				score = 100,
			},
			{ text = "There aren't any real risks.", score = 10, note = "Every prospectus lists risks. Denying them destroys trust." },
			{
				text = "A market crash, I suppose.",
				score = 40,
				note = "Generic. Investors want the company-specific risks you're managing.",
			},
			{
				text = "Honestly, our accounting systems are a bit of a mess.",
				score = 25,
				note = "If that were true it would have to be in the prospectus, not blurted out on the roadshow.",
			},
		},
	},
	{
		id = "valuation",
		text = "Why should we pay {rangeMult}x EBITDA when the peers trade at {median}x?",
		options = {
			{
				text = "We're growing faster than the peer median and converting more of our profit into cash. "
					.. "Adjusted for growth, the range is in line with peers.",
				score = 100,
			},
			{ text = "Because we're worth it.", score = 25, note = "Defend the valuation with numbers, not attitude." },
			{
				text = "We can lower the price if you'd like.",
				score = 30,
				note = "Never negotiate the price on the roadshow. Let the order book decide.",
			},
			{
				text = "That's just the bank's number.",
				score = 20,
				note = "Never throw your own valuation under the bus.",
			},
		},
	},
} :: { Line }

Content.roadshowHints = {
	"Stick to the prospectus: no new numbers, no promises.",
	"Lock-ups and growth-focused proceeds reassure investors.",
	"Answer risks and valuation questions with evidence.",
}

Content.roadshowDebrief = {
	great = "Investors queued for meetings. The order book is filling fast.",
	good = "A solid roadshow. The book is building nicely.",
	weak = "A rocky roadshow. Some investors cancelled their orders.",
}

---------------------------------------------------------------------------------------------------
-- Stage 5: pricing and allocation (fill + alloc)
---------------------------------------------------------------------------------------------------
Content.bookColumns = { "Price per share", "Coverage" }
Content.bookColumnsOrders = { "Price per share", "Orders (M shares)" }

Content.pricingFields = {
	clearing = "At what price is the book exactly covered (orders = shares on offer)?",
	offer = "Your offer price per share",
}
Content.pricingShort = { clearing = "Clearing price", offer = "Offer price" }
Content.offerHint = "Price for a 10–25% pop: about 15–20% below the clearing price."
Content.offerNote = "Pricing near ${ideal} would have given a 10–25% day-one pop."

Content.allocItems = {
	{ id = "longonly", text = "Long-only funds", detail = "Buy and hold for years." },
	{ id = "pension", text = "Pension & sovereign funds", detail = "The longest-term money there is." },
	{ id = "hedge", text = "Hedge funds", detail = "Big orders, but many sell on day one." },
	{ id = "retail", text = "Retail investors", detail = "Loyal fans of the brand, small orders." },
}
Content.allocBands = {
	longonly = { 35, 55 },
	pension = { 15, 30 },
	hedge = { 5, 20 },
	retail = { 10, 20 },
}
Content.allocNotes = {
	longonly = "Long-only funds should get the biggest share (35–55%): they're the stable base of the register.",
	pension = "Pensions and sovereign funds deserve 15–30%: they hold for decades.",
	hedge = "Keep hedge funds to 5–20%. Too many and they flip the stock on day one.",
	retail = "Give retail 10–20%: enough to build a loyal following, not so much that the register gets jumpy.",
}

Content.pricingHints = {
	"Find the row where coverage is exactly 1.0x: that's where the stock will trade.",
	"Price the deal 15–20% below the clearing price for a healthy pop.",
	"Long-term holders first; hedge funds that flip get a small slice.",
}

Content.pricingDebrief = "Priced at ${offer} per share. The shares start trading tomorrow morning."

---------------------------------------------------------------------------------------------------
-- Outcome
---------------------------------------------------------------------------------------------------
Content.outcome = {
	ideal = "{company} opened at ${trade}, up {pop} on the offer price: a textbook IPO.",
	quiet = "{company} edged {popWord} {pop} on its first day. A quiet debut.",
	broke = "{company} broke issue: the shares closed {pop} below the ${offer} offer price.",
	table = "{company} soared {pop} on day one. Great for investors, but the client left {left} on the table.",
	pulled = "The book wasn't covered at ${offer}. {company} postponed its IPO.",
	pulledLine = "Orders only covered the deal up to about ${clearing} a share. Pricing above the book breaks the deal.",
	idealLine = "A 10–25% pop rewards the investors and leaves the client with a fair price.",
	quietLine = "Priced a little rich: buyers had little reason to celebrate.",
	brokeLine = "Pricing too close to the top of the book left nothing for the first day of trading.",
	tableLine = "Priced too cheaply: the client sold its shares for less than investors would pay.",
	allocGood = "A long-term shareholder register kept the trading calm.",
	allocBad = "Too many shares went to fast money, and the flipping dragged the price down.",
	roadshowGood = "A strong roadshow built a deep order book.",
	roadshowWeak = "A weak roadshow left the order book thin.",
	dealName = "{codename}: {raised} IPO of {company}",
	dealNameRunning = "{codename}: IPO of {company}",
	dealNameMandate = "{codename}: IPO mandate",
	dealNamePulled = "{codename}: IPO of {company} (postponed)",
	up = "up",
	down = "down",
	figures = {
		offer = "Offer price",
		close = "Day-one close",
		pop = "Day-one pop",
		raised = "Raised",
		marketCap = "Market value",
		left = "Left on the table",
		fees = "Underwriting fees",
	},
}

Content.metrics = {
	client = "Client",
	value = "Value per share",
	range = "Filed range",
	demand = "Investor demand",
	market = "Market mood",
	offer = "Offer price",
	pending = "—",
	hot = "Hot",
	healthy = "Healthy",
	lukewarm = "Lukewarm",
	riskOn = "Risk-on",
	steady = "Steady",
	riskOff = "Risk-off",
}

return Content
