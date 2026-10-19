--!strict
-- The Street: Sal the newsie (a live headline from MarketService), Walter the doorman, and Ruth Alvarez at Career
-- Services (kind and neutral, especially after a firing; never pushes a purchase).

return {
	---------------------------------------------------------------------------------------------- newsie
	newsie = {
		start = "hub",
		nodes = {
			hub = {
				text = {
					"Getcha headlines here! Hot off the tape: {headline}",
					"Extra, extra! {headline} The ST10 is sitting at {index}, if you're keeping score.",
					"Paper, pal? Today's big one: {headline}",
				},
				options = {
					{
						id = "means",
						text = "What does that mean for the market?",
						to = "means",
						actions = { { kind = "statXp", stats = { "knowledge" }, quality = 50, key = "newsie_tape" } },
					},
					{ id = "st10", text = "What's the ST10?", to = "st10" },
					{ id = "tip", text = "Got any hot tips?", to = "tip" },
					{ id = "bye", text = "Thanks, Sal.", exit = true },
				} :: { any },
			},
			means = {
				text = "Means somebody's making money and somebody's losing it. Read the headline, then check the price. If the price already moved, the news is old. The market reads faster than you do. Faster than me, and I've been reading this tape forty years.",
				options = { { id = "back", text = "If the price moved, the news is old.", to = "hub" } } :: { any },
			},
			st10 = {
				text = "The Street Ten. Ten big companies, weighted by size. It's the benchmark your boss grades your book against. Beat it and you're a genius. Trail it and, well, there's always the newspaper business. Pays great. Ask me how I know.",
				options = { { id = "back", text = "Beat the ST10. Got it.", to = "hub" } } :: { any },
			},
			tip = {
				text = "Kid, if I had hot tips I'd be on the 40th floor, not on this corner. Here's the only tip that ever worked: don't bet more than you can afford to be wrong about.",
				options = { { id = "back", text = "Size the bet to the doubt.", to = "hub" } } :: { any },
			},
		},
	},

	---------------------------------------------------------------------------------------------- doorman
	doorman = {
		start = "hub",
		nodes = {
			hub = {
				text = {
					"Good day. Welcome to the Street.",
					"Morning! Mind the step, it's polished. They polish everything around here.",
				},
				options = {
					{ id = "tower", text = "Where's my firm's tower?", to = "tower", cond = { step = "tower" } },
					{ id = "around", text = "What's around here?", to = "around" },
					{ id = "advice", text = "Any advice for a new face?", to = "advice" },
					{ id = "bye", text = "Thank you, Walter.", exit = true },
				} :: { any },
			},
			tower = {
				text = "{company}? Bank Row, straight off the plaza. Look for their name over the door. You can't miss it. They spent a fortune on that sign.",
				options = { { id = "back", text = "Thanks!", to = "hub" } } :: { any },
			},
			around = {
				text = "Career Services is across the plaza if you ever need it. The Galleria has the tailors, the watchmakers and the shoe men. The Ashford Residences are for folks with a badge. And the rooftop throws mixers when the market's in a good mood.",
				options = { { id = "back", text = "Good to know.", to = "hub" } } :: { any },
			},
			advice = {
				text = "Stand up straight, learn people's names, and never let your shoes get scuffed. I've held this door for thirty years. The ones who say good morning to me are the ones who make partner. Funny how that works.",
				options = {
					{
						id = "morning",
						text = "Good morning, Walter.",
						to = "morning",
						actions = { { kind = "statXp", stats = { "charisma" }, quality = 50, key = "doorman_advice" } },
					},
				} :: { any },
			},
			morning = {
				text = "Good morning to you. See? You're already ahead of half this street.",
				options = { { id = "bye", text = "Have a great day.", exit = true } } :: { any },
			},
		},
	},

	---------------------------------------------------------------------------------------------- career counselor
	counselor = {
		start = {
			{ node = "fired", cond = { fired = true } },
			{ node = "probation", cond = { probation = true } },
			{ node = "student", cond = { student = true } },
			{ node = "hub" },
		} :: { any },
		nodes = {
			fired = {
				text = "Come in, {name}. Sit down. Take a breath. Being let go is a moment, not a verdict. Plenty of the people I've sat with in this chair are running desks now. Let's look at your options together, at whatever pace you need.",
				options = {
					{ id = "options", text = "What are my options?", to = "choices" },
					{ id = "why", text = "How did this happen?", to = "why" },
					{ id = "minute", text = "I need a minute.", to = "minute" },
				} :: { any },
			},
			choices = {
				text = "You can do a re-entry interview and rejoin a desk one rank lower. You can take a fresh start and go back through recruiting at Eastbridge. Or you can simply take a breather. There's no timer and no pressure. The Career Services desk shows every option and exactly what it means.",
				options = {
					{
						id = "open",
						text = "Show me the options.",
						exit = true,
						actions = { { kind = "open", target = "careerServices" } },
					},
					{ id = "why", text = "First, how did this happen?", to = "why" },
					{ id = "later", text = "I'll come back to it.", exit = true },
				} :: { any },
			},
			why = {
				text = "Usually it's a couple of rough reviews in a row, or a risk breach that got out of hand. Your review history is in the Career app. Look at it when you're ready, not before. Understanding it is how the comeback starts.",
				options = { { id = "options", text = "Okay. What are my options?", to = "choices" } } :: { any },
			},
			minute = {
				text = "Take all the time you need. I'll be right here. The door's always open, and so is the Street.",
				options = { { id = "bye", text = "Thank you, Ruth.", exit = true } } :: { any },
			},
			probation = {
				text = "Probation is a warning, not a sentence, {name}. Focus on clean risk, steady work and one good review. That's usually all it takes.",
				options = {
					{
						id = "off",
						text = "How do I get off probation?",
						to = "off_probation",
						actions = {
							{ kind = "statXp", stats = { "discipline" }, quality = 55, key = "counselor_prob" },
						},
					},
					{ id = "bye", text = "Thanks, Ruth.", exit = true },
				} :: { any },
			},
			off_probation = {
				text = "Hit On track or better at your next review. Size positions sensibly, finish your core tasks, and don't chase losses. Chasing losses is how a warning becomes something worse.",
				options = { { id = "bye", text = "No chasing losses.", exit = true } } :: { any },
			},
			student = {
				text = "Hi there. Career Services mostly helps working professionals, but we're always happy to see students. Have you visited the Recruiting Board back at Eastbridge? That's where it starts.",
				options = { { id = "bye", text = "Heading there now.", exit = true } } :: { any },
			},
			hub = {
				text = {
					"Hello, {name}. How's life at {company}?",
					"Good to see you, {name}. What can I help with today?",
				},
				options = {
					{
						id = "open",
						text = "Open Career Services.",
						exit = true,
						actions = { { kind = "open", target = "careerServices" } },
					},
					{ id = "promo", text = "Any advice on getting promoted?", to = "promo" },
					{ id = "bad", text = "How do I handle a bad week?", to = "bad" },
					{ id = "bye", text = "Thank you, Ruth.", exit = true },
				} :: { any },
			},
			promo = {
				text = "Promotions need the whole checklist: the review score, the level, your core work, the right outfit level, and your school's ceiling for the top titles. The Career app shows exactly what's missing. Work the list one item at a time.",
				options = { { id = "back", text = "One item at a time.", to = "hub" } } :: { any },
			},
			bad = {
				text = "Own it, fix what you can control, and don't double down to win it back. Revenge trading has ended more careers than bad luck ever did. A flat week is a fine week.",
				options = {
					{
						id = "flat",
						text = "A flat week is a fine week.",
						to = "hub",
						actions = { { kind = "statXp", stats = { "risk" }, quality = 55, key = "counselor_bad" } },
					},
				} :: { any },
			},
		},
	},
}
