--!strict
-- finance_club_quiz (owned by `work`; contracts §8): the Finance Club's weekly quiz night.
-- Kind "mcq": four to six questions on statements, valuation and markets, plus one fresh numeric question
-- (P/E, enterprise value, market cap or margin) every attempt. Harder tiers draw from deeper banks.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)

local Task = {
	id = "finance_club_quiz",
	title = "Finance Club Quiz",
	desc = "Quiz night at the Finance Club: statements, valuation and markets. Top scorers get noticed by the club president.",
	kind = "mcq",
	student = true,
	unemployed = true,
	category = "campus",
	core = true,
	stats = { "knowledge", "network" },
	clientFacing = false,
	timeLimit = 180,
	baseXp = 55,
	basePay = 250,
	cooldown = 240,
}

local EASY: { Bank.McqEntry } = {
	{
		text = "What does EBITDA stand for?",
		correct = "Earnings before interest, taxes, depreciation and amortization",
		wrong = {
			"Earnings before income, tax, debt and assets",
			"Equity before interest, taxes, dividends and amortization",
			"Expenses before interest, tariffs, depreciation and accruals",
		},
		explain = "EBITDA = earnings before interest, taxes, depreciation and amortization: a rough proxy for operating cash profit.",
		hint = "EBITDA strips out financing (interest), taxes and non-cash charges (D&A).",
	},
	{
		text = "When interest rates rise, the prices of existing bonds usually…",
		correct = "Fall",
		wrong = { "Rise", "Stay exactly the same", "Double" },
		explain = "Bond prices and rates move in opposite directions: new bonds pay more, so old ones are worth less.",
		hint = "Bond prices and interest rates move in opposite directions.",
	},
	{
		text = "Which statement shows assets, liabilities and equity at one point in time?",
		correct = "The balance sheet",
		wrong = { "The income statement", "The cash flow statement", "The proxy statement" },
		explain = "The balance sheet is a snapshot: assets = liabilities + equity on a given date.",
		hint = "One statement is a snapshot; the other two cover a period.",
	},
	{
		text = "A company's market capitalization equals…",
		correct = "Share price × shares outstanding",
		wrong = {
			"Revenue × the P/E ratio",
			"Total assets − total liabilities",
			"Net income × dividends per share",
		},
		explain = "Market cap = share price × shares outstanding: what the market values the equity at.",
		hint = "Market cap is the value of all the shares together.",
	},
	{
		text = "Revenue minus cost of goods sold is called…",
		correct = "Gross profit",
		wrong = { "Net income", "EBITDA", "Free cash flow" },
		explain = "Gross profit = revenue − cost of goods sold, before operating expenses.",
		hint = "Gross profit comes right after the cost of making the product.",
	},
	{
		text = "What is a dividend?",
		correct = "Cash a company pays out to its shareholders",
		wrong = { "Interest a company pays on its loans", "A tax on share sales", "A fee a bank charges to trade" },
		explain = "A dividend is a payout of profits to shareholders, usually in cash.",
	},
	{
		text = "Diversifying a portfolio across many stocks mainly reduces…",
		correct = "Company-specific risk",
		wrong = { "All market risk", "Inflation", "Taxes owed" },
		explain = "Diversification cancels out company-specific risk; market-wide risk remains.",
		hint = "Owning many stocks can't protect you from the whole market falling.",
	},
	{
		text = "Which of these is a liability?",
		correct = "A bank loan the company has to repay",
		wrong = { "Cash in the company's bank account", "Inventory in the warehouse", "A factory the company owns" },
		explain = "Liabilities are what a company owes; loans are the classic example.",
	},
	{
		text = "An IPO is…",
		correct = "A company's first sale of shares to the public",
		wrong = { "A loan from an investment bank", "A merger of two public companies", "A dividend paid in shares" },
		explain = "An initial public offering is when a private company first sells shares on a public exchange.",
	},
	{
		text = "Which investment usually carries the most risk and the highest expected return?",
		correct = "Common stock",
		wrong = { "Government bonds", "A savings account", "Cash" },
		explain = "Shareholders are paid last, so stocks carry more risk and demand a higher expected return.",
	},
}

local MEDIUM: { Bank.McqEntry } = {
	{
		text = "Enterprise value is calculated as…",
		correct = "Equity value + debt − cash",
		wrong = { "Equity value − debt + cash", "Revenue × EBITDA margin", "Total assets + total liabilities" },
		explain = "EV = equity value + debt − cash: the value of the whole business to every capital provider.",
		hint = "Enterprise value adds the debt a buyer takes on and subtracts the cash they get.",
	},
	{
		text = "Buying new equipment (capex) appears in which part of the cash flow statement?",
		correct = "Investing activities",
		wrong = { "Operating activities", "Financing activities", "It doesn't appear there" },
		explain = "Capital expenditure is an investing cash outflow.",
	},
	{
		text = "A stock has a beta of 1.5. It tends to move…",
		correct = "About 50% more than the market",
		wrong = { "Half as much as the market", "Exactly with the market", "Opposite to the market" },
		explain = "Beta measures sensitivity to the market: 1.5 means roughly 1.5x the market's moves.",
		hint = "A beta of 1.0 moves with the market.",
	},
	{
		text = "Working capital equals…",
		correct = "Current assets − current liabilities",
		wrong = { "Total assets − total equity", "Cash + long-term debt", "Revenue − operating expenses" },
		explain = "Working capital = current assets − current liabilities: the cash tied up in running the business.",
	},
	{
		text = "Depreciation lowers net income, but in the cash flow statement it is…",
		correct = "Added back, because it isn't a cash expense",
		wrong = { "Subtracted again, because it is a cash cost", "Ignored completely", "Moved to financing activities" },
		explain = "Depreciation is non-cash, so the cash flow statement adds it back to net income.",
		hint = "Ask yourself: did any cash actually leave the company for depreciation?",
	},
	{
		text = "Compared with its peers, a company trading at a much higher P/E is usually expected to…",
		correct = "Grow its earnings faster",
		wrong = { "Go bankrupt soon", "Pay no taxes", "Have more debt" },
		explain = "Investors pay a higher multiple of today's earnings when they expect faster growth.",
	},
	{
		text = "The yield curve “inverts” when…",
		correct = "Short-term rates are higher than long-term rates",
		wrong = {
			"Long-term rates are higher than short-term rates",
			"All rates are zero",
			"Stocks yield more than bonds",
		},
		explain = "Normally long rates sit above short rates; an inversion flips that and often signals a slowdown.",
	},
	{
		text = "What does an investment bank's M&A team mostly do?",
		correct = "Advise companies on buying and selling businesses",
		wrong = { "Take customer deposits", "Trade the bank's own money", "Audit public companies" },
		explain = "M&A bankers advise on mergers, acquisitions and sales, and run the processes.",
	},
}

local HARD: { Bank.McqEntry } = {
	{
		text = "WACC is…",
		correct = "The blended cost of a company's debt and equity",
		wrong = { "The interest rate on its newest loan", "Its dividend yield", "The return on its cash balance" },
		explain = "The weighted average cost of capital blends the after-tax cost of debt and the cost of equity.",
		hint = "WACC weights each source of capital by how much of it the company uses.",
	},
	{
		text = "In a DCF, raising the discount rate makes the present value…",
		correct = "Lower",
		wrong = { "Higher", "Unchanged", "Negative by definition" },
		explain = "Future cash is divided by (1 + rate)^years, so a higher rate shrinks today's value.",
		hint = "Discounting divides by (1 + rate) for every year you wait.",
	},
	{
		text = "Why compare companies on EV/EBITDA rather than P/E when their debt levels differ?",
		correct = "EBITDA is before interest, so it isn't distorted by how the company is financed",
		wrong = {
			"EBITDA always equals free cash flow",
			"P/E can't be calculated for public companies",
			"EV ignores debt entirely",
		},
		explain = "EV and EBITDA both belong to all capital providers, so leverage doesn't skew the comparison.",
	},
	{
		text = "An acquisition is “accretive” when…",
		correct = "The buyer's earnings per share rise after the deal",
		wrong = { "The target's share price falls", "The buyer pays only in cash", "The deal closes early" },
		explain = "Accretive = pro forma EPS above the buyer's standalone EPS; dilutive = below.",
	},
	{
		text = "A company issues new shares. Existing shareholders' ownership is…",
		correct = "Diluted",
		wrong = { "Doubled", "Converted into bonds", "Unchanged" },
		explain = "More shares outstanding means each existing share owns a smaller slice.",
	},
	{
		text = "In a DCF, the terminal value represents…",
		correct = "The value of all cash flows after the forecast period",
		wrong = { "The final year's revenue", "The company's liquidation value", "The cash on the balance sheet" },
		explain = "Terminal value captures everything beyond the explicit forecast, often most of the total.",
	},
	{
		text = "A convertible bond is…",
		correct = "A bond that the holder can swap for shares",
		wrong = { "A bond with no maturity date", "A bond paid in foreign currency", "A loan that converts into cash" },
		explain = "Convertibles pay interest but let the holder exchange them for equity at a set price.",
	},
}

-- One fresh numeric question per attempt.
local function numeric(rng: Rng.Rng): (Bank.McqEntry, string)
	local which = rng:int(1, 4)
	if which == 1 then
		local eps = rng:int(10, 60) / 10
		local pe = rng:int(8, 30)
		local price = eps * pe
		return {
			text = Common.fill(
				"A stock trades at ${p} and earned ${e} per share. What is its P/E ratio?",
				{ p = string.format("%.2f", price), e = string.format("%.2f", eps) }
			),
			correct = tostring(pe) .. "x",
			wrong = {
				tostring(pe + rng:int(3, 6)) .. "x",
				tostring(math.max(2, pe - rng:int(3, 6))) .. "x",
				string.format("%.1fx", eps),
			},
			explain = Common.fill("P/E = price ÷ EPS = {p} ÷ {e} = {pe}x.", {
				p = string.format("%.2f", price),
				e = string.format("%.2f", eps),
				pe = pe,
			}),
		},
			"P/E = share price ÷ earnings per share."
	elseif which == 2 then
		local equity = rng:int(20, 90) * 50
		local debt = rng:int(14, 40) * 50 -- always more than cash, so the distractors differ
		local cash = rng:int(1, 12) * 50
		local ev = equity + debt - cash
		local commas = Common.commas
		return {
			text = Common.fill(
				"Equity value is ${e}M, debt is ${d}M and cash is ${c}M. What is the enterprise value?",
				{ e = commas(equity), d = commas(debt), c = commas(cash) }
			),
			correct = "$" .. commas(ev) .. "M",
			wrong = {
				"$" .. commas(equity - debt + cash) .. "M",
				"$" .. commas(equity + debt + cash) .. "M",
				"$" .. commas(equity) .. "M",
			},
			explain = Common.fill(
				"EV = {e} + {d} − {c} = ${ev}M.",
				{ e = commas(equity), d = commas(debt), c = commas(cash), ev = commas(ev) }
			),
		},
			"Enterprise value = equity value + debt − cash."
	elseif which == 3 then
		local shares = rng:int(20, 300)
		local price = rng:int(8, 90)
		local cap = shares * price
		local commas = Common.commas
		return {
			text = Common.fill("{s} million shares trade at ${p}. What is the market cap?", { s = shares, p = price }),
			correct = "$" .. commas(cap) .. "M",
			wrong = {
				"$" .. commas(cap * 10) .. "M",
				"$" .. commas(shares + price) .. "M",
				"$" .. commas(math.floor(cap / 10)) .. "M",
			},
			explain = Common.fill("{s}M × ${p} = ${c}M.", { s = shares, p = price, c = commas(cap) }),
		},
			"Market cap = share price × shares outstanding."
	end
	local revenue = rng:int(20, 120) * 10
	local margin = rng:int(5, 30)
	local profit = revenue * margin / 100
	return {
		text = Common.fill(
			"Revenue is ${r}M and operating profit is ${p}M. What is the operating margin?",
			{ r = Common.commas(revenue), p = Common.commas(profit, if profit % 1 == 0 then 0 else 1) }
		),
		correct = tostring(margin) .. "%",
		wrong = {
			tostring(margin * 2) .. "%",
			tostring(math.max(1, margin - rng:int(3, 5))) .. "%",
			tostring(100 - margin) .. "%",
		},
		explain = Common.fill("Margin = profit ÷ revenue = {m}%.", { m = margin }),
	},
		"Margin = profit ÷ revenue."
end

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local specs: { Build.McqSpec } = {}
	local hints: { string } = {}
	local function add(bank: { Bank.McqEntry }, n: number)
		local s, h = Bank.mcq(rng, bank, n)
		for _, x in s do
			table.insert(specs, x)
		end
		for _, x in h do
			table.insert(hints, x)
		end
	end
	if tier == 1 then
		add(EASY, 3)
	elseif tier == 2 then
		add(EASY, 2)
		add(MEDIUM, 2)
	else
		add(EASY, 1)
		add(MEDIUM, 2)
		add(HARD, 2)
	end
	local entry, numericHint = numeric(rng)
	table.insert(specs, rng:int(1, #specs + 1), Bank.mcqOne(entry))
	table.insert(hints, 1, numericHint)
	local questions, secret = Build.mcq(rng, specs)
	secret.summary = {
		great = "Top of the room. The club president asks if you'd like to help run next week's quiz.",
		bad = "Rough night. The club posts its study sheet: worth a read before next week.",
	}
	return {
		kind = "mcq",
		title = Task.title,
		prompt = "Answer each question. The club president reads the scores out at the end.",
		questions = questions,
		hints = Common.hints(ctx, hints),
	},
		secret
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
