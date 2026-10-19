--!strict
-- Halvorsen Hall: Professor Helen Okafor (corporate finance, the academics step) and Priya Shah (Finance Club
-- president: joining the club and the mock stock pitch).

return {
	---------------------------------------------------------------------------------------------- professor
	professor = {
		start = {
			{ node = "alumni", cond = { employed = true } },
			{ node = "hub" },
		} :: { any },
		nodes = {
			hub = {
				text = {
					"Office hours are for questions, not for telling me the dog ate your spreadsheet. What can I do for you?",
					"Ah, {name}. Sit down. You have the look of someone with a question about discount rates.",
				},
				options = {
					{
						id = "pset",
						text = "About the problem set...",
						to = "pset",
						cond = { step = "academics" },
						actions = { { kind = "offerTask", task = "academics_problem_set" } },
					},
					{ id = "dcf", text = "Can you explain discounting?", to = "dcf" },
					{ id = "gpa", text = "Does my GPA really matter?", to = "gpa" },
					{
						id = "rec",
						text = "Could I ask you for a recommendation one day?",
						to = "rec",
						actions = { { kind = "network", key = "npc_professor" } },
					},
					{ id = "bye", text = "Thank you, Professor.", exit = true },
				} :: { any },
			},
			pset = {
				text = "It's on your Work board. Compounding, discounting, growth rates and margins. Fresh numbers every attempt, so don't bother copying your roommate. Show your work, or at least get the right answers.",
				options = { { id = "back", text = "I'll get it done.", to = "hub" } } :: { any },
			},
			dcf = {
				text = "A dollar today is worth more than a dollar next year, because today's dollar can earn interest. To value a future cash flow, divide by one plus the rate, once for every year you wait. Discount every future cash flow, add them up, and you've done a DCF. Bankers just do it with more decimals and less sleep.",
				options = {
					{
						id = "rate",
						text = "So a higher discount rate means a lower value?",
						to = "rate",
						actions = { { kind = "statXp", stats = { "knowledge" }, quality = 65, key = "prof_dcf" } },
					},
					{ id = "back", text = "I think I follow.", to = "hub" },
				} :: { any },
			},
			rate = {
				text = "Precisely. Riskier cash flows deserve a higher rate, so they're worth less today. One hundred dollars a year from now at a 10% rate is worth about ninety-one today. That intuition will carry you through every valuation you ever build.",
				options = {
					{ id = "terminal", text = "What about cash flows forever?", to = "terminal" },
					{ id = "back", text = "Thank you, that helps.", to = "hub" },
				} :: { any },
			},
			terminal = {
				text = "The terminal value. Take the final year's cash flow, grow it one more year, and divide by the rate minus the growth rate. And please, keep that growth rate modest. Nothing grows faster than the economy forever, no matter what the pitchbook says.",
				options = { { id = "back", text = "Modest growth. Noted.", to = "hub" } } :: { any },
			},
			gpa = {
				text = "Banks screen on it, so yes. A 3.6 opens bulge-bracket doors even from a modest school, and the boutiques want more. But once you're in the room, a great interview beats a great transcript. Do both if you can.",
				options = { { id = "back", text = "Both. Understood.", to = "hub" } } :: { any },
			},
			rec = {
				text = "If you earn it. Come to class, do the work, and my door is open. I've written letters for students who now run trading desks. I've also declined to write some. Be the first kind.",
				options = { { id = "back", text = "I'll be the first kind.", to = "hub" } } :: { any },
			},
			alumni = {
				text = "{name}! I hear you're at {company}. Tell me you still discount your cash flows properly. Tell me they haven't taught you to use a 2% discount rate.",
				options = {
					{ id = "proper", text = "Still discounting properly, Professor.", to = "proud" },
					{ id = "bye", text = "I should get going.", exit = true },
				} :: { any },
			},
			proud = {
				text = "Good. Now go make the rest of them do it too.",
				options = { { id = "bye", text = "Will do.", exit = true } } :: { any },
			},
		},
	},

	---------------------------------------------------------------------------------------------- club president
	club_president = {
		start = {
			{ node = "pre_roll", cond = { built = false } },
			{ node = "alumni", cond = { employed = true } },
			{ node = "pitch_club", cond = { club = false } },
			{ node = "hub" },
		} :: { any },
		nodes = {
			pre_roll = {
				text = "Hi! I'm Priya. Do your Life Roll at the Career Center first, then come find me. I need your name for the roster, and 'person in the hallway' doesn't fit on the form.",
				options = { { id = "ok", text = "Back soon.", exit = true } } :: { any },
			},
			pitch_club = {
				text = "Priya Shah, Finance Club president. We pitch stocks, host alumni nights, and once a semester somebody cries over a DCF. Usually me. You in?",
				options = {
					{
						id = "join",
						text = "I'm in.",
						to = "joined",
						actions = { { kind = "joinClub" }, { kind = "complete", step = "club" } },
					},
					{ id = "about", text = "What does the club actually do?", to = "about" },
					{ id = "later", text = "Maybe later.", exit = true },
				} :: { any },
			},
			about = {
				text = "Stock pitches, mock interviews, alumni nights, and a trading competition where the prize is bragging rights and a slightly better parking spot. Every bank on the Street recruits from our roster. That's the real prize.",
				options = {
					{
						id = "join",
						text = "Sign me up.",
						to = "joined",
						actions = { { kind = "joinClub" }, { kind = "complete", step = "club" } },
					},
					{ id = "later", text = "Let me think about it.", exit = true },
				} :: { any },
			},
			joined = {
				text = "Welcome aboard, {name}! Meetings happen whenever there's free pizza. Professor Okafor's problem set is due first, then come pitch the judges a stock. They're tough, but they're fair. Mostly.",
				options = {
					{ id = "pitch", text = "How do I build a good pitch?", to = "howto" },
					{ id = "bye", text = "See you at the next meeting.", exit = true },
				} :: { any },
			},
			hub = {
				text = {
					"Hey {name}! Club business or are you just hiding from your problem set?",
					"Oh good, a member who actually shows up. What's up?",
				},
				options = {
					{
						id = "pitch",
						text = "I'm ready to pitch.",
						to = "pitch",
						cond = { step = "pitch" },
						actions = { { kind = "offerTask", task = "mock_stock_pitch" } },
					},
					{ id = "howto", text = "How do I build a good pitch?", to = "howto" },
					{ id = "quiz", text = "When's quiz night?", to = "quiz" },
					{ id = "bye", text = "Bye, Priya!", exit = true },
				} :: { any },
			},
			pitch = {
				text = "Love it. It's on your Work board. Pick your stocks, read each chart and its news, make the call, then defend it. The judges will grill your thesis, so have one.",
				options = { { id = "go", text = "Let's go.", exit = true } } :: { any },
			},
			howto = {
				text = "Three parts: what the market is missing, why that's about to change, and what could go wrong. 'It went up last month' is not a thesis. 'Margins expand when their new plant opens next quarter' is a thesis.",
				options = {
					{
						id = "risk",
						text = "Why talk about what could go wrong?",
						to = "risks",
						actions = { { kind = "statXp", stats = { "knowledge" }, quality = 60, key = "club_pitch" } },
					},
					{ id = "back", text = "Missing, changing, risks.", to = "hub" },
				} :: { any },
			},
			risks = {
				text = "Because the judges will think of them anyway, and it's better if you got there first. Naming your risks shows you've done the work. Pretending there are none shows you haven't.",
				options = { { id = "back", text = "Name the risks first.", to = "hub" } } :: { any },
			},
			quiz = {
				text = "Whenever you open your Work board, honestly. It's the Finance Club Quiz. Score 70 or better and I'll mention you to the alumni. They notice.",
				options = { { id = "back", text = "Seventy or better.", to = "hub" } } :: { any },
			},
			alumni = {
				text = "{name}! Our newest alum on the Street! I'm putting your name on the 'where are they now' board. Any chance {company} sponsors our pizza?",
				options = {
					{ id = "ask", text = "I'll ask around.", to = "thanks" },
					{ id = "bye", text = "Good luck with the club!", exit = true },
				} :: { any },
			},
			thanks = {
				text = "You're the best. Free pizza is how future bankers are made.",
				options = { { id = "bye", text = "See you, Priya.", exit = true } } :: { any },
			},
		},
	},
}
