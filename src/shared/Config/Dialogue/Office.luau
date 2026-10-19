--!strict
-- Office staff spawned by the offices feature in every company instance: the lobby receptionist and the department
-- boss. {npc} is the name the model wears, {place} the company whose office this is, {company} the player's own firm.
-- Visitors (not employees of this office) get a polite, short conversation.

return {
	---------------------------------------------------------------------------------------------- receptionist
	receptionist = {
		start = {
			{ node = "visitor", cond = { visitor = true } },
			{ node = "first", cond = { notDone = "receptionist" } },
			{ node = "hub" },
		} :: { any },
		nodes = {
			visitor = {
				text = "Welcome to {place}. Visitors are welcome to look around the lobby. The floors upstairs are for employees only, I'm afraid.",
				options = {
					{ id = "job", text = "How would I get a job here?", to = "job", cond = { student = true } },
					{ id = "bye", text = "Thanks.", exit = true },
				} :: { any },
			},
			job = {
				text = "Our analysts are hired through campus recruiting. If you're a student, the Recruiting Board at Eastbridge is where it starts. Good luck!",
				options = { { id = "bye", text = "Thank you!", exit = true } } :: { any },
			},
			first = {
				text = "You must be {name}! We've been expecting you. Here's your badge, your laptop, and a lanyard you'll be wearing for the next few years. {boss} is upstairs on the {department} floor.",
				actions = { { kind = "complete", step = "receptionist" } } :: { any },
				options = {
					{ id = "elevator", text = "Where's the elevator?", to = "elevator" },
					{ id = "nervous", text = "Is it normal to be this nervous?", to = "nervous" },
					{ id = "thanks", text = "Thanks!", exit = true },
				} :: { any },
			},
			nervous = {
				text = "Completely. Every analyst who's walked through that door looked exactly like you do right now. Most of them looked worse. You'll be fine. Just don't call {boss} by their first name until they tell you to.",
				options = { { id = "elevator", text = "Noted. Where's the elevator?", to = "elevator" } } :: { any },
			},
			elevator = {
				text = "Right behind me. Tap the panel and choose {department}. And welcome to {place}.",
				options = { { id = "bye", text = "Thank you!", exit = true } } :: { any },
			},
			hub = {
				text = {
					"Morning, {name}. {boss} was asking about you.",
					"Good to see you, {name}. Coffee's fresh upstairs. Well, fresh-ish.",
					"Hi, {name}! Busy day upstairs. Everyone's got a deal on.",
				},
				options = {
					{ id = "review", text = "Anything I should know?", to = "review", cond = { reviewDue = true } },
					{ id = "elevator", text = "Where's the elevator again?", to = "elevator" },
					{ id = "bye", text = "Thanks!", exit = true },
				} :: { any },
			},
			review = {
				text = "Your weekly review is on {boss}'s calendar for this afternoon. I wouldn't keep them waiting.",
				options = { { id = "bye", text = "On my way up.", exit = true } } :: { any },
			},
		},
	},

	---------------------------------------------------------------------------------------------- boss
	boss = {
		start = {
			{ node = "visitor", cond = { visitor = true } },
			{ node = "due", cond = { reviewDue = true } },
			{ node = "first", cond = { notDone = "boss" } },
			{ node = "probation", cond = { probation = true } },
			{ node = "hub" },
		} :: { any },
		nodes = {
			visitor = {
				text = "I don't believe we've met. This floor is for {place} staff. If you're here about a job, our recruiting team visits Eastbridge every season.",
				options = { { id = "bye", text = "Sorry to bother you.", exit = true } } :: { any },
			},
			due = {
				text = "It's Friday, {name}. Your weekly review is ready. Come stand by my desk and we'll go through your week.",
				options = { { id = "ok", text = "On my way.", exit = true } } :: { any },
			},
			first = {
				text = "So you're the new analyst. {name}, right? I'm {npc}. I run {department} here at {company}. Sit down for a second.",
				options = {
					{ id = "hi", text = "Nice to meet you. I'm ready to work.", to = "expect" },
					{ id = "honest", text = "Honestly? I'm a little terrified.", to = "honest" },
				} :: { any },
			},
			honest = {
				text = "Good. Terrified people check their numbers. It's the confident ones who send me models with the balance sheet off by a million dollars. Now, let me tell you what I expect.",
				options = { { id = "go", text = "I'm listening.", to = "expect" } } :: { any },
			},
			expect = {
				text = "Your desk tasks, done well and on time. A trading book you can explain. Clean risk: no limit breaches, ever. And you show up dressed like you belong in a client meeting, because sometimes you will be in one.",
				options = {
					{ id = "judged", text = "How will I be judged?", to = "judged" },
					{ id = "understood", text = "Understood.", to = "firstday" },
				} :: { any },
			},
			judged = {
				text = "Every Friday afternoon you come to my office for your weekly review. I score your book against the ST10, your risk management, your work and what the team thinks of you. Star reviews get noticed. Two criticals in a row and we part ways. Promotions come from the checklist in your Career app, and from nothing else.",
				options = { { id = "got", text = "Got it.", to = "firstday" } } :: { any },
			},
			firstday = {
				text = "Good. Your desk is out on the floor. There's a task waiting on your Work board, and the terminal is right there. Make your first trade today. Don't be a hero.",
				actions = { { kind = "complete", step = "boss" } } :: { any },
				options = { { id = "on_it", text = "On it.", exit = true } } :: { any },
			},
			probation = {
				text = "{name}. I need to see a better week from you. Clean risk, steady work, no surprises. You can turn this around, but it starts now.",
				options = {
					{
						id = "advice",
						text = "What would you do in my shoes?",
						to = "probation_advice",
						actions = {
							{ kind = "statXp", stats = { "discipline" }, quality = 55, key = "boss_probation" },
						},
					},
					{ id = "fix", text = "I'll fix it.", exit = true },
				} :: { any },
			},
			probation_advice = {
				text = "Shrink your positions until you're sure of them, finish every core task, and ask for help before a deadline, not after. Nobody gets fired for asking a question. People get fired for guessing.",
				options = { { id = "bye", text = "Thank you. I won't let you down.", exit = true } } :: { any },
			},
			hub = {
				text = {
					"{name}. Make it quick, I've got a client call in ten.",
					"What's up, {name}? Walk with me.",
					"Come in. Shut the door, the floor's loud today.",
				},
				options = {
					{ id = "doing", text = "How am I doing?", to = "doing" },
					{ id = "advice", text = "Any advice?", to = "advice" },
					{ id = "star", text = "What makes a Star review?", to = "star" },
					{ id = "bye", text = "Back to work.", exit = true },
				} :: { any },
			},
			doing = {
				text = "Check the Career app. It shows your checklist to the next title: score, level, core work, outfit level and the rest. I don't promote on vibes, {name}. I promote on the list.",
				options = { { id = "back", text = "Working the list.", to = "hub" } } :: { any },
			},
			advice = {
				text = "Know your numbers cold. If a client asks a question, answer it or say you'll find out. Never guess. Guessing is how deals die.",
				options = {
					{
						id = "never",
						text = "Never guess.",
						to = "hub",
						actions = { { kind = "statXp", stats = { "knowledge" }, quality = 55, key = "boss_advice" } },
					},
				} :: { any },
			},
			star = {
				text = "Beat the benchmark without blowing a risk limit, deliver clean work, and keep the team and the clients happy. All four, in the same week. Most people only manage two.",
				options = { { id = "back", text = "All four. Same week.", to = "hub" } } :: { any },
			},
		},
	},
}
