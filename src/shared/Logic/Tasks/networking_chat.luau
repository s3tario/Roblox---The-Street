--!strict
-- networking_chat (owned by `work`; contracts §8): working the room at a campus networking night.
-- Kind "dialogue": four to six turns with an alum at a parody bank. Good answers build rapport, ask about their
-- story, respect confidentiality and their time, and end with a follow-up; pushy, entitled or careless answers
-- score low with a specific note. Charisma adds quality points (ctx.charismaBonus).

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "networking_chat",
	title = "Networking Night",
	desc = "An alum from a big bank is at the campus mixer. Make a good impression without asking for a job.",
	kind = "dialogue",
	student = true,
	category = "networking",
	core = false,
	stats = { "network", "charisma" },
	clientFacing = false,
	timeLimit = 150,
	baseXp = 50,
	basePay = 200,
	cooldown = 240,
}

local OPEN: Bank.Turn = {
	says = {
		"Hi there. I'm {alum}, an associate at {firm}. Are you a student here?",
		"Hey! {alum}, {firm}. I graduated from here a few years ago. What are you studying?",
	},
	best = {
		{ text = "Great to meet you, {first}. I'm studying finance. What first got you interested in {firm}?" },
		{ text = "Nice to meet you! Finance major. I'd love to hear how you ended up at {firm}." },
	},
	good = {
		{
			text = "Hi {first}, I'm a finance student. Thanks for coming back to campus.",
			note = "Polite and warm. Add a question about them to get the conversation going.",
		},
	},
	weak = {
		{
			text = "Hi. I've heard of {firm}.",
			note = "Polite, but it gives them nothing to work with. Ask about their story.",
		},
	},
	bad = {
		{
			text = "Can you get me an internship at {firm}?",
			note = "Asking for a job in the first minute puts people off. Build rapport first.",
		},
		{
			text = "Cool. So how much do associates make?",
			note = "Opening with pay is a fast way to end a conversation.",
		},
	},
	hint = "Open with your name, one line about you, and a question about them.",
}

local WORK: Bank.Turn = {
	says = {
		"Honestly the hours are long, but the deals make it worth it. Last month we sold a {sector} company.",
		"It's intense. I spent the summer on a sale process for a {sector} business. Learned a ton.",
	},
	best = {
		{ text = "That sounds intense. What was your role on the deal day to day?" },
		{ text = "What did you learn on that deal that you couldn't have learned in class?" },
	},
	good = {
		{
			text = "That's impressive. How big was the team?",
			note = "Fine, but a question about THEIR role would show more interest.",
		},
	},
	weak = {
		{ text = "Cool.", note = "One-word answers stall the conversation. Follow up on what they just said." },
	},
	bad = {
		{
			text = "Which company was it? Is the deal public yet?",
			note = "Never press a banker for confidential deal details.",
		},
		{
			text = "Long hours? I don't think I could do that.",
			note = "Complaining about hours to a banker tells them you're not serious.",
		},
	},
	hint = "Ask follow-ups about their experience, never about confidential deal names.",
}

local WHY: Bank.Turn = {
	says = {
		"So what's drawing you to banking?",
		"What makes you want to work on the Street?",
	},
	best = {
		{
			text = "I ran the numbers on a local company's sale for a class project and loved how valuation drives the decision. I want to be in the room for that.",
		},
		{
			text = "I like fast-paced work with real stakes. Building the model for our club's pitch was the most fun I've had at school.",
		},
	},
	good = {
		{
			text = "I enjoy finance classes and want to learn how deals work.",
			note = "Okay, but generic. A short personal story would stick.",
		},
	},
	weak = {
		{
			text = "I'm not totally sure yet. Maybe banking, maybe consulting.",
			note = "Being unsure is fine, but sounding lukewarm to a banker costs you.",
		},
	},
	bad = {
		{
			text = "Honestly? The money.",
			note = "Everyone knows the pay. Saying it first makes you sound like you're only in it for that.",
		},
		{ text = "My parents want me to.", note = "Show it's your own drive, not someone else's plan." },
	},
	hint = "Have a 20-second story ready for “why banking”.",
}

local ASK: Bank.Turn = {
	says = {
		"Do you have any questions for me?",
		"Anything you want to ask while I'm here?",
	},
	best = {
		{ text = "What do you wish you'd known before your first year as an analyst?" },
		{ text = "What separates the analysts who get great reviews from the rest?" },
	},
	good = {
		{
			text = "What's a typical day like at {firm}?",
			note = "Fair question, but a sharper one shows you've done your homework.",
		},
	},
	weak = {
		{
			text = "What's the dress code like?",
			note = "Easy to look up. Use the moment for something only they can answer.",
		},
	},
	bad = {
		{ text = "No, I think I'm good.", note = "Having no questions reads as no interest." },
		{ text = "How do I get your job?", note = "Too blunt. Ask about what they did to get there instead." },
	},
	hint = "Prepare one thoughtful question only this person can answer.",
}

local INTERRUPT: Bank.Turn = {
	says = {
		"Another student cuts in: “Hey, can I get your card?” {first} glances back at you.",
		"A classmate walks up mid-sentence and starts pitching themselves to {first}.",
	},
	best = {
		{ text = "Smile and include them: “We were just talking about {first}'s deal work. Join us.”" },
	},
	good = {
		{
			text = "Wait politely for them to finish, then pick the thread back up.",
			note = "Gracious. Including them would have looked even better.",
		},
	},
	weak = {
		{
			text = "Say nothing and look at your phone.",
			note = "Checking out of the conversation hands it to someone else.",
		},
	},
	bad = {
		{
			text = "“Excuse me, we were talking.”",
			note = "Being territorial in front of a banker looks bad. Stay gracious.",
		},
		{ text = "Roll your eyes at {first}.", note = "Never put someone down in front of a contact." },
	},
	hint = "Stay gracious when others join; bankers watch how you treat people.",
}

local CLOSE: Bank.Turn = {
	says = {
		"Great chatting. I should go say hi to a few more people.",
		"I need to grab my colleague, but this was fun.",
	},
	best = {
		{ text = "Thanks so much for your time, {first}. Would it be okay if I emailed you a quick follow-up?" },
		{ text = "Really appreciate it. Could I send you a short note to stay in touch?" },
	},
	good = {
		{ text = "Thanks, it was great meeting you!", note = "Warm, but ask for a way to follow up before they go." },
	},
	weak = {
		{ text = "Okay, bye.", note = "Close with thanks and a follow-up, or the contact fades." },
	},
	bad = {
		{
			text = "Wait, one more thing. Can you refer me tomorrow?",
			note = "Respect their time. A referral comes after a relationship, not a single chat.",
		},
		{ text = "Can I add you on every social app?", note = "Ask for one sensible way to follow up, usually email." },
	},
	hint = "End by thanking them and asking to follow up by email.",
}

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local first, last = Universe.first(rng), Universe.last(rng)
	local offer = ctx.offer
	local firm = if offer and type(offer.companyName) == "string" then offer.companyName else Universe.firm(rng)
	local vars = {
		alum = first .. " " .. last,
		first = first,
		firm = firm,
		sector = string.lower(Universe.sector(rng:pick(Universe.sectorIds)).name),
	}
	local middle = { WORK, WHY, ASK, INTERRUPT }
	local chosen = Common.pickN(rng, middle, math.min(1 + tier, #middle)) -- 2 / 3 / 4 middle turns (4-6 lines)
	local turns: { Bank.Turn } = { OPEN }
	for _, t in chosen do
		table.insert(turns, t)
	end
	table.insert(turns, CLOSE)
	local specs, hints = Bank.dialogue(rng, turns, vars, if tier >= 2 then 4 else 3)
	local lines, secret = Build.dialogue(rng, specs)
	secret.summary = {
		great = Common.fill("{first} hands you a card: “Email me. I'll introduce you to our recruiter.”", vars),
		bad = Common.fill("{first} drifts off to talk to someone else. Rapport first, asks later.", vars),
	}
	return {
		kind = "dialogue",
		title = Task.title,
		prompt = "Pick what you say at each turn.",
		speaker = vars.alum .. ", " .. firm,
		lines = lines,
		hints = Common.hints(ctx, hints),
	},
		secret
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
