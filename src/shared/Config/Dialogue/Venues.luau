--!strict
-- Street venues: Laurent Duval (host of the Executive Club), Simone Hart (rooftop mixers) and Henry Osei (concierge at
-- The Ashford Residences).

return {
	---------------------------------------------------------------------------------------------- Executive Club host
	club_host = {
		start = "hub",
		nodes = {
			hub = {
				text = {
					"Good evening, and welcome to the Executive Club. Your usual table is wherever you'd like it to be.",
					"Ah, welcome back. The lounge is quiet tonight. The deals, I'm told, are not.",
				},
				options = {
					{ id = "what", text = "What happens here?", to = "what" },
					{ id = "plaques", text = "What are those lucite blocks on the shelf?", to = "plaques" },
					{ id = "etiquette", text = "Any etiquette tips?", to = "etiquette" },
					{ id = "bye", text = "Good evening, Laurent.", exit = true },
				} :: { any },
			},
			what = {
				text = "Deals are celebrated, rivals are toasted, and nobody discusses their bonus. Out loud. Members come here to think, to talk quietly, and occasionally to be seen thinking.",
				options = { { id = "back", text = "Sounds exclusive.", to = "hub" } } :: { any },
			},
			plaques = {
				text = "Deal plaques. Bankers call them tombstones, or deal toys. Close a big deal and the firm gives you a little lucite trophy with the deal's name and date. Some partners have hundreds. They pretend not to count. They count.",
				options = {
					{ id = "earn", text = "How do I earn one?", to = "earn" },
					{ id = "back", text = "I want a shelf full.", to = "hub" },
				} :: { any },
			},
			earn = {
				text = "Close a deal. For a young banker that usually means taking a company public: the valuation, the pitchbook, the investor questions and the pricing. Do it well and the plaque sits on your desk for everyone to see.",
				options = { { id = "back", text = "Noted.", to = "hub" } } :: { any },
			},
			etiquette = {
				text = "Remember names. Ask about their deals before you mention your own. And never order the most expensive wine when the client is paying. Especially then.",
				options = {
					{
						id = "names",
						text = "Names first, deals second.",
						to = "hub",
						actions = { { kind = "statXp", stats = { "charisma" }, quality = 55, key = "host_etiquette" } },
					},
				} :: { any },
			},
		},
	},

	---------------------------------------------------------------------------------------------- rooftop mixer host
	mixer_host = {
		start = "hub",
		nodes = {
			hub = {
				text = {
					"Welcome to the rooftop! Drinks to the left, views everywhere, and the managing directors are the ones pretending not to check their phones.",
					"Hey, you made it! The skyline's showing off tonight. So are the bankers.",
				},
				options = {
					{ id = "who", text = "Who comes to these?", to = "who" },
					{
						id = "room",
						text = "How do I work the room?",
						to = "room",
						actions = { { kind = "network", key = "npc_mixer_host" } },
					},
					{ id = "cards", text = "Can I exchange cards with people here?", to = "cards" },
					{ id = "bye", text = "Enjoy the night, Simone.", exit = true },
				} :: { any },
			},
			who = {
				text = "Bankers, fund people, a few founders hunting for money and one guy who swears he invented the term 'synergy'. When the market's good, the mixers get bigger. Do well in your reviews and the invitations start arriving.",
				options = { { id = "back", text = "Good reviews, better parties.", to = "hub" } } :: { any },
			},
			room = {
				text = "Join groups of three, not pairs: pairs are private conversations. Ask what someone's working on, then actually listen. Leave with one real follow-up, not twenty business cards you'll never use.",
				options = {
					{
						id = "follow",
						text = "One real follow-up.",
						to = "hub",
						actions = { { kind = "statXp", stats = { "network" }, quality = 55, key = "mixer_room" } },
					},
				} :: { any },
			},
			cards = {
				text = "Of course. Tap anyone and choose Exchange cards. Once a day per person, and every exchange builds your Network. The people you meet here are the people who call you about jobs later.",
				options = { { id = "back", text = "I'll make the rounds.", to = "hub" } } :: { any },
			},
		},
	},

	---------------------------------------------------------------------------------------------- Ashford concierge
	concierge = {
		start = "hub",
		nodes = {
			hub = {
				text = {
					"Welcome home to The Ashford. Anything I can do for you this evening?",
					"Good to see you. Your mail has been sorted and your doormat is, I assure you, still there.",
				},
				options = {
					{ id = "unit", text = "Which unit is mine?", to = "unit" },
					{ id = "decor", text = "Can I decorate my place?", to = "decor" },
					{ id = "advice", text = "Any advice for a new resident?", to = "advice" },
					{ id = "bye", text = "Thanks, Henry.", exit = true },
				} :: { any },
			},
			unit = {
				text = "Every resident has a unit here while they work on the Street. Your door is marked with your name. Make yourself at home, and please don't put a squat rack on the balcony. We've had incidents.",
				options = { { id = "back", text = "No squat racks. Promise.", to = "hub" } } :: { any },
			},
			decor = {
				text = "Of course. Use the Customize panel inside your unit. Furniture, art and desk pieces come from the Galleria Home & Office store, a short walk away.",
				options = { { id = "back", text = "Perfect.", to = "hub" } } :: { any },
			},
			advice = {
				text = "Budget like a professional: rent, food, then savings, then the fun. The residents who buy a forty-thousand-dollar watch in their second week are the ones I help move out in their sixth.",
				options = {
					{
						id = "budget",
						text = "Rent, food, savings, then fun.",
						to = "hub",
						actions = { { kind = "statXp", stats = { "discipline" }, quality = 55, key = "concierge_budget" } },
					},
				} :: { any },
			},
		},
	},
}
