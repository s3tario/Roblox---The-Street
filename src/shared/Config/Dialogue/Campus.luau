--!strict
-- Campus regulars (outdoors and the dorms): the alum, the barista, the Route 9 driver and your roommate.
-- Each one counts as a contact for the networking step (action `network`) and teaches one idea in passing.

return {
	---------------------------------------------------------------------------------------------- alum
	alum = {
		start = {
			{ node = "colleague", cond = { employed = true } },
			{ node = "hub" },
		} :: { any },
		nodes = {
			hub = {
				text = {
					"Hey! Jordan Reyes, class of '19. I'm back recruiting for Morrow Stanton. Don't worry, I don't bite. Usually.",
					"Oh, hi again! Still surviving recruiting season? Grab a seat, I've got ten minutes before my next coffee chat.",
				},
				options = {
					{ id = "life", text = "What's banking actually like?", to = "life" },
					{ id = "story", text = "How did you get in?", to = "story" },
					{ id = "quiz", text = "Ask me a technical question.", to = "quiz" },
					{ id = "bye", text = "Thanks, Jordan. See you around.", exit = true },
				} :: { any },
			},
			life = {
				text = "Long hours, sharp people, steep learning curve. Year one you build models, format pitchbooks and learn more spreadsheet shortcuts than you knew existed. You will be tired. You will also never learn faster in your life.",
				options = {
					{ id = "hours", text = "How long are the hours, really?", to = "hours" },
					{ id = "back", text = "Good to know.", to = "hub" },
				} :: { any },
			},
			hours = {
				text = "Depends on the deal. A quiet week, you're home for dinner. A live deal, you'll see the sunrise from the 30th floor and the cleaners will know your coffee order. Protect your sleep when you can. Nobody does good math at 4 a.m.",
				options = { { id = "back", text = "Noted. Sleep is an asset.", to = "hub" } } :: { any },
			},
			story = {
				text = "Not from a fancy school, if that's what you're asking. I joined the Finance Club, pitched stocks, and wrote a thank-you note to every person I met. One of them pulled my résumé out of the pile. Networking isn't schmoozing. It's being memorable for the right reasons.",
				options = {
					{
						id = "card",
						text = "Could I keep in touch with you?",
						to = "card",
						actions = { { kind = "network", key = "npc_alum" } },
					},
					{ id = "back", text = "That's encouraging.", to = "hub" },
				} :: { any },
			},
			card = {
				text = "Of course. Here's my card. Email me before your Superday and I'll tell you what my team cares about. And {name}? Actually follow up. Ninety percent of people don't.",
				options = { { id = "back", text = "I will. Thank you.", to = "hub" } } :: { any },
			},
			quiz = {
				text = "Okay, quick one. A company trades at a P/E of 20 and earns $5 a share. What's the stock price?",
				options = {
					{
						id = "a100",
						text = "$100.",
						to = "right",
						actions = { { kind = "statXp", stats = { "knowledge" }, quality = 60, key = "alum_pe" } },
					},
					{ id = "a25", text = "$25.", to = "wrong" },
					{ id = "a4", text = "$4.", to = "wrong" },
				} :: { any },
			},
			right = {
				text = "Nailed it. P/E is price over earnings, so price is P/E times EPS: 20 times $5 is $100. Multiples are just shortcuts for price. You'll use them in every comps table you ever build.",
				options = { { id = "back", text = "Another one sometime?", to = "hub" } } :: { any },
			},
			wrong = {
				text = "Close, but no. P/E is price divided by earnings per share, so the price is P/E times EPS: 20 times $5 = $100. Write that one on your hand before the Superday.",
				options = { { id = "back", text = "Price equals P/E times EPS. Got it.", to = "hub" } } :: { any },
			},
			colleague = {
				text = "Look who made it! {title} at {company}. Welcome to the club. First rule of the Street: the coffee on the 30th floor is better than the coffee on the 3rd.",
				options = {
					{ id = "tip", text = "Any advice for my first weeks?", to = "colleague_tip" },
					{ id = "bye", text = "Thanks, Jordan!", exit = true },
				} :: { any },
			},
			colleague_tip = {
				text = "Write everything down, check your numbers twice, and never send a model you haven't footed. One typo in a pitchbook and the managing director remembers it forever.",
				options = { { id = "bye", text = "Footing everything. Got it.", exit = true } } :: { any },
			},
		},
	},

	---------------------------------------------------------------------------------------------- barista
	barista = {
		start = "hub",
		nodes = {
			hub = {
				text = {
					"Welcome to the Grind House. We're open whenever the library is, which is to say always. What can I get you?",
					"Back again? You've got that recruiting-season look. I'll make it a double.",
				},
				options = {
					{ id = "coffee", text = "Just a black coffee, please.", to = "coffee" },
					{
						id = "gossip",
						text = "Heard any good gossip?",
						to = "gossip",
						actions = { { kind = "network", key = "npc_barista" } },
					},
					{ id = "math", text = "Do bankers really drink this much coffee?", to = "math" },
					{ id = "bye", text = "See you later, Rosie.", exit = true },
				} :: { any },
			},
			coffee = {
				text = "Black coffee, no nonsense. You'll fit right in downtown. The bankers come back every recruiting season looking like they haven't slept since the last one. Because they haven't.",
				options = { { id = "back", text = "Thanks!", to = "hub" } } :: { any },
			},
			gossip = {
				text = "Word is Priya's stock-pitch night got heated last week. Somebody pitched shorting the dining hall's taco supplier. On paper. People were genuinely upset. Also, the alum by the quad tips well, so be nice to him.",
				options = { { id = "back", text = "Ha. Good to know.", to = "hub" } } :: { any },
			},
			math = {
				text = "Honey, a $4 latte every workday is about a thousand dollars a year. Put that in an index fund at 7% for ten years and you'd have around fourteen thousand. I tell the analysts this every single time. They tip me in guilt.",
				options = {
					{
						id = "compound",
						text = "So that's compounding.",
						to = "compound",
						actions = { { kind = "statXp", stats = { "discipline" }, quality = 55, key = "barista_math" } },
					},
					{ id = "back", text = "I'll still take the latte.", to = "hub" },
				} :: { any },
			},
			compound = {
				text = "That's compounding. Your money earns money, then that money earns money. Small amounts plus time beat big amounts plus impatience. Now, oat milk or regular?",
				options = { { id = "back", text = "Regular. I'm on a budget.", to = "hub" } } :: { any },
			},
		},
	},

	---------------------------------------------------------------------------------------------- bus driver
	bus_driver = {
		start = "hub",
		nodes = {
			hub = {
				text = {
					"Route 9. Campus loop, the depot and back. Thirty-one years. I've driven three future CEOs and one fella who tried to pay with a stock certificate.",
					"You again. Bus doesn't leave for six minutes. Sit if you're sitting.",
				},
				options = {
					{ id = "downtown", text = "What's it like downtown?", to = "downtown" },
					{ id = "stock", text = "Someone paid with a stock certificate?", to = "stock" },
					{
						id = "chat",
						text = "How's the route treating you?",
						to = "chat",
						actions = { { kind = "network", key = "npc_bus_driver" } },
					},
					{ id = "bye", text = "Have a good one, Earl.", exit = true },
				} :: { any },
			},
			downtown = {
				text = "The Street? Forty minutes on the subway and a whole world away. Marble everywhere and nobody looks up from their phones. You'll need a job offer before they let you through those turnstiles, kid.",
				options = { { id = "back", text = "Working on it.", to = "hub" } } :: { any },
			},
			stock = {
				text = "Swore it was worth more than the fare. Maybe it was, that morning. Company went bust a month later. That's when I learned the difference between price and value. Price is what you pay. Value is what you get.",
				options = {
					{
						id = "lesson",
						text = "Price is what you pay, value is what you get.",
						to = "lesson",
						actions = { { kind = "statXp", stats = { "risk" }, quality = 55, key = "bus_value" } },
					},
					{ id = "back", text = "Did you take it?", to = "took" },
				} :: { any },
			},
			lesson = {
				text = "Now you're talking like one of those finance folks. Write it down. Most of them forget it right around bonus season.",
				options = { { id = "back", text = "I'll remember.", to = "hub" } } :: { any },
			},
			took = {
				text = "Took it, framed it, it's above my kitchen table. Most expensive bus fare in Eastbridge history. Cheapest lesson I ever got.",
				options = { { id = "back", text = "Worth it.", to = "hub" } } :: { any },
			},
			chat = {
				text = "Same as always. Potholes on Fifth, pigeons on the quad, students running for the bus like it's the last one on earth. You're alright, though. You ever need directions, you ask Earl.",
				options = { { id = "back", text = "Will do. Thanks, Earl.", to = "hub" } } :: { any },
			},
		},
	},

	---------------------------------------------------------------------------------------------- roommate
	roommate = {
		start = {
			{ node = "employed", cond = { employed = true } },
			{ node = "hub" },
		} :: { any },
		nodes = {
			hub = {
				text = {
					"Oh hey, roomie. Don't mind me, I'm 'studying'.",
					"You're back! I ordered pizza. It's mostly gone. The crusts are all yours.",
				},
				options = {
					{ id = "up", text = "What are you up to?", to = "up" },
					{
						id = "food",
						text = "Want to grab food later?",
						to = "food",
						actions = { { kind = "network", key = "npc_roommate" } },
					},
					{ id = "bye", text = "Catch you later, Theo.", exit = true },
				} :: { any },
			},
			up = {
				text = "Watching the market. I put my entire summer-job savings into one stock. Volt Automotive. It's either going to the moon or I'm eating ramen until graduation.",
				options = {
					{ id = "all", text = "All of it? In one stock?", to = "diversify" },
					{ id = "bold", text = "Bold strategy.", to = "hub" },
				} :: { any },
			},
			diversify = {
				text = "I know, I know. 'Diversify.' My mom said that too. Spread it across companies and sectors so one bad day doesn't wreck you. But what if the one stock is AMAZING?",
				options = {
					{
						id = "sleep",
						text = "Then you'd still sleep better owning ten of them.",
						to = "convinced",
						actions = { { kind = "statXp", stats = { "risk" }, quality = 60, key = "roommate_div" } },
					},
					{ id = "moon", text = "To the moon, Theo.", to = "moon" },
				} :: { any },
			},
			convinced = {
				text = "...Fine. FINE. I'll buy an index fund. A small one. Do not tell my mom she was right. She'll put it on a mug.",
				options = { { id = "back", text = "Your secret's safe.", to = "hub" } } :: { any },
			},
			moon = {
				text = "THANK you. Finally, someone who believes. If it crashes, I'm borrowing your blazer for the job fair.",
				options = { { id = "back", text = "You can borrow it either way.", to = "hub" } } :: { any },
			},
			food = {
				text = "Always. The dining hall is doing 'mystery taco Tuesday' on a Wednesday. Bold move. I respect it.",
				options = { { id = "back", text = "It's a date with destiny.", to = "hub" } } :: { any },
			},
			employed = {
				text = "Dude. You got a job on Wall Street. {title} at {company}! Does this mean you'll finally pay for the pizza?",
				options = {
					{ id = "pizza", text = "Pizza's on me.", to = "pizza" },
					{ id = "bye", text = "Gotta run. Big day tomorrow.", exit = true },
				} :: { any },
			},
			pizza = {
				text = "Legend. Pure legend. I'm telling everyone my roommate is a banker. I'll leave out the part where you hum spreadsheet formulas in your sleep.",
				options = { { id = "bye", text = "That was ONE time.", exit = true } } :: { any },
			},
		},
	},
}
