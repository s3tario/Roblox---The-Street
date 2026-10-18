--!strict
-- coffee_chat (owned by `work`; contracts §8): fifteen minutes over coffee with a junior banker.
-- Kind "multi": (1) "mcq" preparation (what to research, how long to take, when to follow up), then (2) the chat
-- itself as "dialogue". Good chats are prepared, curious, short and end with a thank-you.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "coffee_chat",
	title = "Coffee Chat",
	desc = "You landed fifteen minutes with an analyst at the corner café. Prepare, ask good questions, follow up.",
	kind = "multi",
	student = true,
	category = "networking",
	core = false,
	stats = { "network", "charisma" },
	clientFacing = false,
	timeLimit = 210,
	baseXp = 60,
	basePay = 220,
	cooldown = 300,
}

local PREP: { Bank.McqEntry } = {
	{
		text = "What's the most useful thing to research before the chat?",
		correct = "{name}'s background and a recent deal {firm} worked on",
		wrong = { "Nothing: it's more natural to wing it", "{firm}'s office address", "The café's menu" },
		explain = "Knowing their path and a recent deal lets you ask questions only they can answer.",
		hint = "Prepare questions about THEM and their firm's recent work.",
	},
	{
		text = "{name} offered fifteen minutes. How long should you plan to talk?",
		correct = "About fifteen minutes, and offer to wrap up on time",
		wrong = {
			"As long as possible: more time is more impressive",
			"Five minutes, then leave",
			"An hour, so you cover everything",
		},
		explain = "Respecting the time they offered is the easiest way to be invited back.",
		hint = "Respect the time they offered.",
	},
	{
		text = "When should you send a thank-you note?",
		correct = "Within a day, with one specific thing you learned",
		wrong = { "Only if they offered you a job", "A month later, so they remember you", "Never: it's awkward" },
		explain = "A prompt, specific thank-you shows you listened and keeps the door open.",
	},
	{
		text = "Who should pay for the coffee?",
		correct = "You offer to pay, since you asked for their time",
		wrong = { "They should: they earn more", "Split it exactly to the cent", "Nobody orders anything" },
		explain = "You asked for the meeting, so you offer. Many bankers will insist, and that's fine.",
	},
	{
		text = "What should you bring?",
		correct = "Two or three prepared questions and a printed résumé, just in case",
		wrong = { "A full slide deck about yourself", "Your laptop to show your grades", "Nothing at all" },
		explain = "Keep it light: prepared questions, and a résumé only if they ask.",
	},
}

local TURNS: { Bank.Turn } = {
	{
		says = {
			"Thanks for reaching out. So, what can I help with?",
			"Good to meet you. What did you want to chat about?",
		},
		best = {
			{
				text = "I read about {firm}'s {sector} deal and I'm curious what an analyst actually does on a sale like that.",
			},
		},
		good = {
			{
				text = "I'd love to hear about your path into banking.",
				note = "Solid, but tying it to something specific about them is stronger.",
			},
		},
		weak = {
			{
				text = "Just, you know, banking stuff.",
				note = "Vague openers waste their time. Lead with a specific question.",
			},
		},
		bad = {
			{
				text = "Could you forward my résumé to HR today?",
				note = "Asking for a referral before any rapport usually closes the door.",
			},
			{
				text = "Is it true analysts never sleep? That sounds awful.",
				note = "Leading with negatives about their job is a poor start.",
			},
		},
		hint = "Lead with a specific question about their work.",
	},
	{
		says = {
			"Honestly my first year was rough. I almost quit after a bad review.",
			"The first few months were a lot. I made a big error in a model once.",
		},
		best = {
			{ text = "That must have been tough. What did you change after that?" },
			{ text = "How did you bounce back? I'd love to learn from that." },
		},
		good = {
			{
				text = "That sounds hard. Glad it worked out.",
				note = "Kind, but a follow-up question shows you're really listening.",
			},
		},
		weak = {
			{
				text = "Oh. Anyway, what's the pay like?",
				note = "Brushing past their story to talk money looks self-interested.",
			},
		},
		bad = {
			{
				text = "I'd never make a mistake like that.",
				note = "Arrogance lands badly, especially when someone shares a weakness.",
			},
		},
		hint = "When they share a story, ask what they learned from it.",
	},
	{
		says = { "What kind of work are you most interested in?", "Do you know what group you'd want to join?" },
		best = {
			{
				text = "M&A, mostly. I liked valuing companies in my club. But I'm open: what made you pick your group?",
			},
		},
		good = {
			{
				text = "I'm interested in M&A because I like valuation.",
				note = "Good answer; turning it back to them keeps the chat flowing.",
			},
		},
		weak = { { text = "Whatever pays the most.", note = "Show genuine interest in the work itself." } },
		bad = {
			{
				text = "I'll take anything, I just need a job.",
				note = "Desperation reads poorly. Show focused interest.",
			},
		},
		hint = "Show interest in the work, then turn the question back to them.",
	},
	{
		says = { "I've got to run back to the office soon.", "Looks like my phone's buzzing, I should head back." },
		best = {
			{ text = "Thank you, {first}, this was really helpful. I'll send a quick note. Good luck tonight!" },
		},
		good = {
			{
				text = "Thanks so much for your time!",
				note = "Gracious. Mentioning a follow-up note would round it off.",
			},
		},
		weak = { { text = "Already? I had ten more questions.", note = "Respect their time and let them go." } },
		bad = {
			{
				text = "Can you introduce me to your MD before you go?",
				note = "A big ask at the door undoes a good chat. Build the relationship first.",
			},
		},
		hint = "Thank them, mention you'll follow up, and let them go on time.",
	},
}

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local first = Universe.first(rng)
	local name = first .. " " .. Universe.last(rng)
	local offer = ctx.offer
	local firm = if offer and type(offer.companyName) == "string" then offer.companyName else Universe.firm(rng)
	local vars = {
		name = name,
		first = first,
		firm = firm,
		sector = string.lower(Universe.sector(rng:pick(Universe.sectorIds)).name),
	}
	local prepSpecs, prepHints = Bank.mcq(rng, PREP, if tier >= 2 then 3 else 2, vars)
	local questions, mcqSecret = Build.mcq(rng, prepSpecs)
	local turns: { Bank.Turn } = { TURNS[1] }
	local middle = Common.pickN(rng, { TURNS[2], TURNS[3] }, if tier >= 2 then 2 else 1)
	for _, t in middle do
		table.insert(turns, t)
	end
	table.insert(turns, TURNS[4])
	local talkSpecs, talkHints = Bank.dialogue(rng, turns, vars, if tier >= 3 then 4 else 3)
	local lines, talkSecret = Build.dialogue(rng, talkSpecs)
	local hints: { string } = {}
	for i = 1, math.max(#prepHints, #talkHints) do
		if talkHints[i] then
			table.insert(hints, talkHints[i])
		end
		if prepHints[i] then
			table.insert(hints, prepHints[i])
		end
	end
	return {
		kind = "multi",
		title = Task.title,
		prompt = Common.fill("Coffee with {name} from {firm}.", vars),
		sections = {
			{ kind = "mcq", title = "Before you go", prompt = "Get ready for the chat.", questions = questions },
			{
				kind = "dialogue",
				title = "At the café",
				prompt = "Pick what you say.",
				speaker = name .. ", Analyst at " .. firm,
				lines = lines,
			},
		} :: { any },
		hints = Common.hints(ctx, hints),
	}, {
		kind = "multi",
		sections = { mcqSecret, talkSecret },
		weights = { 0.35, 0.65 },
		summary = {
			great = Common.fill(
				"{first} says: “Keep in touch. I'll put in a good word with our recruiting team.”",
				vars
			),
			bad = Common.fill("{first} is polite, but you can tell it didn't click. Prepare more next time.", vars),
		},
	}
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
