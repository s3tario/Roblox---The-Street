--!strict
-- deal_process (owned by `work`; contracts §8): putting a deal's workplan in order for the kickoff meeting.
-- Kind "order": the steps of a sell-side M&A sale, an IPO, a buy-side acquisition or a loan refinancing, shuffled.
-- Easy tiers show five steps (first and last always included), hard tiers the full process.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "deal_process",
	title = "Deal Workplan",
	desc = "The kickoff is tomorrow. Put the deal's workplan in the right order.",
	kind = "order",
	tracks = { "ib" },
	ranks = { 1, 2 },
	category = "work",
	core = false,
	stats = { "knowledge", "discipline" },
	clientFacing = false,
	timeLimit = 150,
	baseXp = 50,
	basePay = 360,
	cooldown = 240,
}

type Process = { name: string, prompt: string, steps: { string }, hints: { string } }

local PROCESSES: { Process } = {
	{
		name = "Sell-side sale",
		prompt = "{client} hired {firm} to sell the company. Order the workplan.",
		steps = {
			"Sign the engagement letter with {client}",
			"Draft the teaser and the confidential information memorandum",
			"Contact likely buyers and sign NDAs",
			"Collect first-round indications of interest",
			"Open the data room and host management presentations",
			"Receive final bids with marked-up purchase agreements",
			"Negotiate and sign the purchase agreement",
			"Get regulatory and shareholder approvals",
			"Close the deal and announce it",
		},
		hints = {
			"Nothing happens before the engagement letter is signed.",
			"Buyers sign NDAs before they see confidential material.",
			"First-round bids come before the data room; final bids after it.",
		},
	},
	{
		name = "IPO",
		prompt = "{client} wants to go public with {firm} as lead underwriter. Order the IPO timeline.",
		steps = {
			"Kick off with {client}, the lawyers and the auditors",
			"Run due diligence on the business",
			"Draft the prospectus and file it with the regulator",
			"Answer the regulator's comments",
			"Launch the roadshow and meet investors",
			"Build the order book",
			"Price the offering",
			"Shares start trading; support the stock in its first days",
		},
		hints = {
			"Diligence comes before you can write the prospectus.",
			"Investors hear the roadshow before they place orders.",
			"The price is set only once the order book is built.",
		},
	},
	{
		name = "Buy-side acquisition",
		prompt = "{client} wants to buy a competitor. Order {firm}'s buy-side workplan.",
		steps = {
			"Agree the acquisition strategy and screening criteria with {client}",
			"Screen the market and shortlist targets",
			"Approach the preferred target's board",
			"Sign an NDA and receive initial information",
			"Submit a non-binding offer",
			"Complete confirmatory due diligence",
			"Negotiate and sign the merger agreement",
			"Close after approvals",
		},
		hints = {
			"Strategy and screening come before any approach.",
			"You can't see information before an NDA is signed.",
			"Non-binding offer first, binding agreement after diligence.",
		},
	},
	{
		name = "Loan refinancing",
		prompt = "{client} needs to refinance its debt before it matures. Order the financing timeline.",
		steps = {
			"Agree the size and terms {client} needs",
			"Get a credit rating from the agencies",
			"Prepare the lender presentation",
			"Launch syndication to lenders",
			"Take commitments and set the final pricing",
			"Allocate the loan and close the financing",
		},
		hints = {
			"Lenders want a rating and a presentation before they commit.",
			"Pricing is set once commitments are in.",
			"Allocation and closing come last.",
		},
	},
}

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local process = rng:pick(PROCESSES)
	local vars = {
		client = Universe.company(rng).name,
		firm = if ctx.companyName then ctx.companyName else "the bank",
	}
	local total = #process.steps
	local want = math.min(total, if tier == 1 then 5 elseif tier == 2 then 7 else total)
	-- keep the first and last step, then a random set of the middle ones, in their real order
	local middle: { number } = {}
	for i = 2, total - 1 do
		table.insert(middle, i)
	end
	local keep = Common.pickN(rng, middle, want - 2)
	table.insert(keep, 1)
	table.insert(keep, total)
	table.sort(keep)
	local steps: { string } = {}
	for _, i in keep do
		table.insert(steps, Common.fill(process.steps[i], vars))
	end
	local items, secret = Build.order(
		rng,
		steps,
		Common.fill("{name}: the steps above run in this order, from the start through to closing.", {
			name = process.name,
		})
	)
	secret.summary = {
		great = "Workplan approved. The MD uses it as the kickoff agenda.",
		bad = "The VP rewrites your workplan. Learn the order: it drives every deal timeline.",
	}
	return {
		kind = "order",
		title = Task.title .. ": " .. process.name,
		prompt = Common.fill(process.prompt, vars),
		items = items,
		hints = Common.hints(ctx, process.hints),
	},
		secret
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
