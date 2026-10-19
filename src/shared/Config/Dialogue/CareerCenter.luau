--!strict
-- The Eastbridge Career Center: Dana Whitfield (career advisor, the tutorial's guide on campus) and Marcus Bell
-- (campus recruiter, interview coaching and the mock interview).

return {
	---------------------------------------------------------------------------------------------- advisor
	advisor = {
		start = {
			{ node = "pre_roll", cond = { built = false } },
			{ node = "fired", cond = { fired = true } },
			{ node = "alumni", cond = { employed = true } },
			{ node = "intro", cond = { notDone = "advisor" } },
			{ node = "hub" },
		} :: { any },
		nodes = {
			pre_roll = {
				text = "Welcome to Eastbridge! Before we talk careers I need to know who you are. The kiosk by the door runs your Life Roll: school, family, stats, the works. Come back when you're done.",
				options = {
					{ id = "what", text = "What's a Life Roll?", to = "explain_roll" },
					{ id = "ok", text = "On it.", exit = true },
				} :: { any },
			},
			explain_roll = {
				text = "It sets your school, degree, GPA, family, clubs, starting stats and starting outfit. Each one has a rarity, and the odds are printed right there on the screen. You get three rerolls, one field each. Your school decides which doors open first, but how you work decides how far you go.",
				options = { { id = "ok", text = "Let's roll.", exit = true } } :: { any },
			},
			intro = {
				text = "So you're {name}. {school}, huh? Good. Sit, sit. I've placed kids from this office at every bank on the Street, and every one of them started exactly where you are: nervous and slightly underdressed.",
				options = {
					{ id = "start", text = "Where do I even start?", to = "plan" },
					{ id = "banks", text = "Which banks recruit here?", to = "banks" },
					{ id = "dress", text = "Underdressed?", to = "dress" },
				} :: { any },
			},
			plan = {
				text = "Here's the playbook. One: join the Finance Club. Priya runs it out of Halvorsen Hall. Two: keep your grades up; Professor Okafor's problem sets land on your Work board. Three: meet people. Four: practise interviewing. Then recruiting opens and the Recruiting Board does the rest.",
				options = {
					{
						id = "go",
						text = "Got it. Finance Club first.",
						exit = true,
						actions = { { kind = "complete", step = "advisor" } },
					},
					{ id = "why", text = "Why does the club matter?", to = "club_why" },
					{ id = "banks", text = "Tell me about the banks first.", to = "banks" },
				} :: { any },
			},
			club_why = {
				text = "Because bankers hire people they've already met. The club runs the stock pitches and the alumni nights. It's networking with an actual reason to be in the room.",
				options = {
					{
						id = "go",
						text = "Makes sense. I'll find Priya.",
						exit = true,
						actions = { { kind = "complete", step = "advisor" } },
					},
				} :: { any },
			},
			banks = {
				text = "Four kinds. Bulge brackets like MG Freeman and Goldfield Saxe: huge deal flow, and they want a Rare school or a 3.6 GPA. Elite boutiques like Evermoor Partners: advice only, the best pay and the pickiest of all. Middle-market firms like Harrow Williams: real responsibility early. And regional desks like Sterling & Vance, who give anyone a fair shot.",
				options = {
					{ id = "walkon", text = "And if nobody takes me?", to = "walkon" },
					{ id = "plan", text = "So what's the plan?", to = "plan" },
				} :: { any },
			},
			walkon = {
				text = "Then Sterling & Vance does. Their walk-on seat is real: pass their Superday and you're in. Nobody leaves this office without a path to the Street. Nobody.",
				options = { { id = "plan", text = "Good to know. What's the plan?", to = "plan" } } :: { any },
			},
			dress = {
				text = "Banks have dress codes and they take them seriously. Your outfit level is the lowest level among your top, your bottoms and your shoes. Regional desks want level 2, most banks level 3, the boutiques level 4. The Wardrobe and the campus store will get you started.",
				options = {
					{
						id = "open",
						text = "Open my Wardrobe.",
						exit = true,
						actions = { { kind = "open", target = "wardrobe" } },
					},
					{ id = "plan", text = "Noted. What's the plan?", to = "plan" },
				} :: { any },
			},
			hub = {
				text = {
					"Back again, {name}? Good. Persistence is underrated in this business.",
					"{name}! How's the hunt going? Pull up a chair.",
					"There's my future banker. What do you need?",
				},
				options = {
					{ id = "club", text = "What's next?", to = "tip_club", cond = { step = "club" } },
					{
						id = "work",
						text = "What's next?",
						to = "tip_work",
						cond = { stepIn = { "academics", "pitch" } },
					},
					{ id = "network", text = "What's next?", to = "tip_network", cond = { step = "network" } },
					{ id = "mock", text = "What's next?", to = "tip_mock", cond = { step = "mock_interview" } },
					{
						id = "recruit",
						text = "How should I approach recruiting?",
						to = "tip_recruit",
						cond = { step = "recruiting" },
					},
					{ id = "offer", text = "I got an offer! Now what?", to = "tip_offer", cond = { step = "offers" } },
					{ id = "odds", text = "How do offers actually work?", to = "offers_explain" },
					{ id = "lesson", text = "Teach me something useful.", to = "lesson" },
					{ id = "bye", text = "Thanks, Dana.", exit = true },
				} :: { any },
			},
			tip_club = {
				text = "Halvorsen Hall, ask for Priya Shah. Tell her I sent you. She'll pretend to be unimpressed. She's impressed.",
				options = { { id = "back", text = "On my way.", to = "hub" } } :: { any },
			},
			tip_work = {
				text = "Grades and the club pitch. Open your Work board from the menu or a campus desk. Speed matters, but accuracy matters more. A fast wrong answer is still wrong.",
				options = { { id = "back", text = "Accuracy first.", to = "hub" } } :: { any },
			},
			tip_network = {
				text = "Meet three people. Jordan the alum is usually by the quad, Marcus is right over there, and Professor Okafor keeps office hours. You can also tap another student and exchange cards. It all counts.",
				options = { { id = "back", text = "Three people. Easy.", to = "hub" } } :: { any },
			},
			tip_mock = {
				text = "Do a mock interview with Marcus before the real thing. The first time you answer 'tell me about yourself' should not be in front of a managing director.",
				options = { { id = "back", text = "Fair point.", to = "hub" } } :: { any },
			},
			tip_recruit = {
				text = "Recruiting's open! Follow the arrow to the Recruiting Board. You have five applications: pick one reach, a few targets and keep Sterling & Vance as your safety. Their walk-on seat doesn't even use a slot.",
				options = {
					{
						id = "board",
						text = "Open the Recruiting Board.",
						exit = true,
						actions = { { kind = "open", target = "recruiting" } },
					},
					{ id = "back", text = "One reach, a few targets.", to = "hub" },
				} :: { any },
			},
			tip_offer = {
				text = "Congratulations! Open Career, then Offers. Compare the pay, the prestige and the dress code. Accepting one declines the rest, so take a breath first. Then ride the subway downtown.",
				options = {
					{
						id = "offers",
						text = "Show me my offers.",
						exit = true,
						actions = { { kind = "open", target = "offers" } },
					},
					{ id = "back", text = "Taking a breath.", to = "hub" },
				} :: { any },
			},
			offers_explain = {
				text = "Each firm's odds depend on your interview scores, your school, GPA, stats and family connections. The Recruiting Board shows the exact odds before you ask for a decision. No surprises, no fine print. Better interviews move the number more than anything else.",
				options = { { id = "back", text = "Interviews matter most. Got it.", to = "hub" } } :: { any },
			},
			lesson = {
				text = "Quick one. Enterprise value is what it costs to buy the whole business: equity value plus debt, minus cash. Two companies can have the same share price and wildly different enterprise values. Bankers live in EV.",
				options = {
					{
						id = "got",
						text = "EV = equity + debt - cash.",
						to = "hub",
						actions = { { kind = "statXp", stats = { "knowledge" }, quality = 55, key = "advisor_ev" } },
					},
				} :: { any },
			},
			alumni = {
				text = "Look at you! {title} at {company}. Come back and tell the freshmen it's possible. They don't believe me when I say it.",
				options = {
					{ id = "tip", text = "Any advice for the Street?", to = "street_tip" },
					{ id = "bye", text = "Thanks for everything, Dana.", exit = true },
				} :: { any },
			},
			street_tip = {
				text = "Your boss's checklist is your map. Read it every week. And dress one level above where you are. Promotions need the outfit too, and nobody wants to hear 'come back dressed for the role'.",
				options = { { id = "bye", text = "One level above. Got it.", exit = true } } :: { any },
			},
			fired = {
				text = "I heard. I'm sorry, {name}. It happens to good people far more often than anyone admits. Career Services downtown can get you back in, and if you'd rather start over, recruiting here never closes for you.",
				options = {
					{ id = "how", text = "How do people come back from this?", to = "fired_back" },
					{ id = "bye", text = "Thanks, Dana.", exit = true },
				} :: { any },
			},
			fired_back = {
				text = "One honest look at what went wrong, one plan, and one good week at a time. The re-entry interview gets you back on a desk. The comeback stories are my favourite part of this job.",
				options = { { id = "bye", text = "One good week at a time.", exit = true } } :: { any },
			},
		},
	},

	---------------------------------------------------------------------------------------------- recruiter
	recruiter = {
		start = {
			{ node = "pre_roll", cond = { built = false } },
			{ node = "employed", cond = { employed = true } },
			{ node = "hub" },
		} :: { any },
		nodes = {
			pre_roll = {
				text = "Marcus Bell, campus recruiting. Do your Life Roll at the kiosk first. I can't coach a blank résumé.",
				options = { { id = "ok", text = "Be right back.", exit = true } } :: { any },
			},
			hub = {
				text = {
					"Marcus Bell, campus recruiting. I've sat on both sides of the interview table. Want the inside track?",
					"Hey, {name}. Prepping? Good. Most people don't, which is great news for you.",
				},
				options = {
					{
						id = "mock",
						text = "Can I do a mock interview?",
						to = "mock",
						cond = { step = "mock_interview" },
						actions = { { kind = "offerTask", task = "mock_interview" } },
					},
					{ id = "process", text = "How do bank interviews work?", to = "process" },
					{ id = "tech", text = "Give me a technical question.", to = "tech_q" },
					{ id = "fit", text = "Any tips for fit questions?", to = "fit" },
					{
						id = "touch",
						text = "Could I stay in touch?",
						to = "touch",
						actions = { { kind = "network", key = "npc_recruiter" } },
					},
					{ id = "bye", text = "Thanks, Marcus.", exit = true },
				} :: { any },
			},
			mock = {
				text = "Absolutely. I put one on your Work board. Treat it like the real thing: sit up straight, answer the question they asked, and stop talking when you're done.",
				options = { { id = "back", text = "Stop talking when I'm done. Got it.", to = "hub" } } :: { any },
			},
			process = {
				text = "First round: fit questions and a few technicals, about thirty minutes. Then the Superday: back-to-back interviews with technicals, a senior banker and some mental math. Your scores feed straight into your offer odds, and the Recruiting Board shows those odds before you ask for a decision.",
				options = {
					{ id = "superday", text = "Why is it called a Superday?", to = "superday" },
					{ id = "back", text = "Makes sense.", to = "hub" },
				} :: { any },
			},
			superday = {
				text = "Because 'Exhausting Afternoon' tested poorly. It's the final round: four or five interviews in a row. Bring water, bring energy, and don't let one bad conversation spill into the next one.",
				options = { { id = "back", text = "Reset between rooms.", to = "hub" } } :: { any },
			},
			tech_q = {
				text = "Classic opener: walk me through the three financial statements. Quick version.",
				options = {
					{
						id = "right",
						text = "Net income flows from the income statement to the top of the cash flow statement, and ending cash lands on the balance sheet.",
						to = "tech_right",
						actions = { { kind = "statXp", stats = { "knowledge" }, quality = 65, key = "recruiter_tech" } },
					},
					{
						id = "wrong",
						text = "Revenue goes on the balance sheet and assets go on the income statement.",
						to = "tech_wrong",
					},
					{
						id = "dodge",
						text = "Honestly, I'd rather talk about my passion for finance.",
						to = "tech_dodge",
					},
				} :: { any },
			},
			tech_right = {
				text = "Exactly. The income statement shows profit over a period, the balance sheet is a snapshot, and the cash flow statement explains how cash moved between snapshots. Net income is the bridge. That answer gets you to round two.",
				options = { { id = "back", text = "Hit me with another sometime.", to = "hub" } } :: { any },
			},
			tech_wrong = {
				text = "Not quite. Revenue and profit live on the income statement, over a period. Assets, liabilities and equity live on the balance sheet, at a point in time. Net income connects them through the cash flow statement. Drill that before your Superday.",
				options = { { id = "back", text = "Drilling it tonight.", to = "hub" } } :: { any },
			},
			tech_dodge = {
				text = "Ha. Passion is lovely, but they WILL ask this question. Every time. Net income starts the cash flow statement; ending cash finishes on the balance sheet. Learn it cold.",
				options = { { id = "back", text = "Fine, fine. Learning it cold.", to = "hub" } } :: { any },
			},
			fit = {
				text = "Use situation, action, result. Be specific: names, numbers, what YOU did. Never trash a former team. Interviewers are quietly asking themselves one question: would I survive a 2 a.m. model fix with this person?",
				options = {
					{
						id = "weak",
						text = "What about 'what's your greatest weakness'?",
						to = "weakness",
						actions = { { kind = "statXp", stats = { "charisma" }, quality = 55, key = "recruiter_fit" } },
					},
					{ id = "back", text = "Situation, action, result.", to = "hub" },
				} :: { any },
			},
			weakness = {
				text = "Pick a real one, then show what you're doing about it. 'I'm a perfectionist' gets an eye roll. 'I used to over-polish slides, so now I set a time box and ask for feedback early' gets a nod.",
				options = { { id = "back", text = "Real weakness, real fix.", to = "hub" } } :: { any },
			},
			touch = {
				text = "Of course. Here's my card. If you land a Superday, email me the firm's name and I'll tell you what they love to ask.",
				options = { { id = "back", text = "Thank you!", to = "hub" } } :: { any },
			},
			employed = {
				text = "The one that got away! {company} snapped you up. Good for them, and good for you. Come back next season and sit on the other side of the table.",
				options = { { id = "bye", text = "Maybe I will.", exit = true } } :: { any },
			},
		},
	},
}
