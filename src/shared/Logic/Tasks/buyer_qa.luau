--!strict
-- buyer_qa (owned by `work`; contracts §8): fielding a buyer's questions on a sell-side management call.
-- Kind "dialogue": four to six questions from the buyer's head of corporate development. The best answers are
-- honest and positive, protect confidential information (customer names, other bidders) and the seller's
-- negotiating leverage; leaks, lies and overpromises score low. Client-facing; Charisma adds quality points.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "buyer_qa",
	title = "Buyer Q&A",
	desc = "Lead the call with a bidder's corporate development team. Sell the story, protect the client.",
	kind = "dialogue",
	tracks = { "ib" },
	ranks = { 3, 4, 5 },
	category = "client",
	core = false,
	stats = { "charisma", "knowledge" },
	clientFacing = true,
	timeLimit = 180,
	baseXp = 80,
	basePay = 600,
	cooldown = 300,
}

local TURNS: { Bank.Turn } = {
	{
		says = { "Why is the founder selling now?", "Help us understand the timing. Why sell this year?" },
		best = {
			{
				text = "After {years} years, {founder} wants a partner with the scale to fund the next phase, and the business is at a record high.",
			},
		},
		good = {
			{
				text = "It's part of long-term succession planning.",
				note = "True but thin. Tie the timing to the growth story.",
			},
		},
		weak = {
			{
				text = "You'd have to ask {founder}.",
				note = "You run the process: answer the obvious question confidently.",
			},
		},
		bad = {
			{
				text = "Between us, {founder} is burnt out and next year might be softer.",
				note = "Never undercut your own client. That just lowered every bid.",
			},
			{ text = "Honestly, they need the cash.", note = "Signalling a forced seller destroys your leverage." },
		},
		hint = "Answer “why now” with the growth story, never with weakness.",
	},
	{
		says = { "Can you send the names of the top ten customers?", "We need the customer list to model churn." },
		best = {
			{
				text = "Not at this stage. We'll share anonymised concentration data now and names in confirmatory diligence under clean-team rules.",
			},
		},
		good = {
			{
				text = "We'll share names in the next round.",
				note = "Right direction; offering anonymised data now keeps them engaged.",
			},
		},
		weak = { { text = "Let me check and get back to you.", note = "You should know the disclosure plan already." } },
		bad = {
			{
				text = "Sure, I'll email you the list after the call.",
				note = "Customer names before final bids is a serious confidentiality breach.",
			},
			{
				text = "No, and please stop asking.",
				note = "Refuse politely and offer an alternative. Hostility costs bids.",
			},
		},
		hint = "Sensitive data is staged: anonymised first, names later under clean-team rules.",
	},
	{
		says = {
			"What's growth without that one-off contract last year?",
			"Strip out the one-off deal. What's the real growth rate?",
		},
		best = {
			{
				text = "Excluding it, revenue grew {g}%. The bridge is in the data room, so you can check every number.",
			},
		},
		good = {
			{
				text = "It's still healthy, high single digits or so.",
				note = "Be precise. Buyers trust exact, checkable numbers.",
			},
		},
		weak = { { text = "I don't have that to hand.", note = "Know the adjusted numbers cold before a buyer call." } },
		bad = {
			{
				text = "About {gHigh}%, give or take.",
				note = "That overstates growth. Misleading a buyer can unwind the whole deal.",
			},
			{
				text = "Ignore the one-off, it doesn't matter.",
				note = "Dismissing a fair question makes buyers suspicious.",
			},
		},
		hint = "Give exact, verifiable numbers, and point to where they're documented.",
	},
	{
		says = { "Is there flexibility on price?", "Off the record: what number gets this done?" },
		best = { { text = "It's a competitive process. The best way to stand out is a strong, clean final bid." } },
		good = {
			{
				text = "The seller will look at the whole package, not just price.",
				note = "Okay, but don't hint there's room below the market.",
			},
		},
		weak = { { text = "I'd rather not say.", note = "Fine, but use the moment to push for their best bid." } },
		bad = {
			{ text = "Between us, they'd take a lot less.", note = "You just negotiated against your own client." },
			{
				text = "No flexibility. Take it or leave it.",
				note = "Bluster can push a serious buyer out of the process.",
			},
		},
		hint = "Never negotiate against your client; keep the competitive tension.",
	},
	{
		says = { "Will management stay after closing?", "Is the team staying on if we buy it?" },
		best = {
			{
				text = "The team intends to stay and is open to rolling some equity. We can set up a session with them next round.",
			},
		},
		good = { { text = "Most of them plan to stay.", note = "Back it up: offer a management session." } },
		weak = { { text = "Hard to say.", note = "Buyers need confidence in the team; prepare this answer." } },
		bad = {
			{
				text = "I guarantee every one of them stays for five years.",
				note = "You can't guarantee people's choices. Overpromising creates liability.",
			},
			{
				text = "They'll probably all leave after the payout.",
				note = "That's the single fastest way to lose a buyer.",
			},
		},
		hint = "Back statements about people with something the buyer can verify.",
	},
	{
		says = { "We heard another bidder dropped out. True?", "Is {rival} still in the process?" },
		best = { { text = "We don't comment on other parties, but interest has been strong." } },
		good = {
			{
				text = "I can't get into that.",
				note = "Right call. Adding that interest is strong keeps the pressure on.",
			},
		},
		weak = { { text = "Why do you ask?", note = "Deflecting with a question sounds evasive." } },
		bad = {
			{
				text = "Yes, you're basically the only one left.",
				note = "Revealing the field kills competitive tension and breaks process rules.",
			},
			{
				text = "Yes, {rival} dropped over the pension issue.",
				note = "Disclosing another bidder's reasons is a confidentiality breach.",
			},
		},
		hint = "Never discuss other bidders.",
	},
}

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local seller = Universe.company(rng).name
	local buyer = Universe.company(rng).name
	local g = rng:int(6, 14)
	local vars = {
		founder = Universe.person(rng),
		years = rng:int(12, 30),
		g = g,
		gHigh = g + rng:int(8, 15),
		rival = Universe.company(rng).name,
	}
	local turns = Common.pickN(rng, TURNS, 3 + tier) -- 4 / 5 / 6
	local specs, hints = Bank.dialogue(rng, turns, vars, 4)
	local lines, secret = Build.dialogue(rng, specs)
	secret.summary = {
		great = "The buyer leaves the call keen and asks to accelerate. The seller couldn't be happier.",
		bad = "The buyer smells weakness. Expect lower bids, and an awkward call with your client.",
	}
	local who = Universe.person(rng)
	return {
		kind = "dialogue",
		title = Task.title,
		prompt = Common.fill("You represent {seller}. {buyer} is a bidder.", { seller = seller, buyer = buyer }),
		speaker = who .. ", Head of Corp Dev, " .. buyer,
		lines = lines,
		hints = Common.hints(ctx, hints),
	},
		secret
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
