--!strict
-- The Galleria shopkeepers. Each one opens their shop (ShopService:OpenFor with the shop id) and explains a piece of
-- the dress-code system or a money idea in their own voice.

return {
	---------------------------------------------------------------------------------------------- tailor
	tailor = {
		start = "hub",
		nodes = {
			hub = {
				text = {
					"Ah, a new face. Stand still. Hmm. The shoulders are wrong, the trousers are wrong, but the posture... the posture we can work with.",
					"Welcome back to Hartwell. Let me guess: a client meeting, and you want to look like you've had a hundred of them.",
				},
				options = {
					{
						id = "shop",
						text = "Show me what you have.",
						exit = true,
						actions = { { kind = "open", target = "shop", args = { shopId = "tailor" } } },
					},
					{ id = "level", text = "What's an outfit level?", to = "level" },
					{ id = "style", text = "Any style advice?", to = "style" },
					{ id = "bye", text = "Maybe later.", exit = true },
				} :: { any },
			},
			level = {
				text = "Every garment has a level from one to five. Your outfit level is the lowest among your top, your trousers and your shoes. Firms set a minimum to hire you, and promotions ask for more: a vice president needs level four, a managing director level five. A cheap shoe ruins a fine suit, every time.",
				options = { { id = "back", text = "The lowest piece sets the level.", to = "hub" } } :: { any },
			},
			style = {
				text = "Navy and charcoal for interviews. Black for funerals and restaurants that try too hard. And the jacket buttons, top to bottom: sometimes, always, never.",
				options = {
					{
						id = "buttons",
						text = "Sometimes, always, never.",
						to = "hub",
						actions = { { kind = "statXp", stats = { "charisma" }, quality = 50, key = "tailor_style" } },
					},
				} :: { any },
			},
		},
	},

	---------------------------------------------------------------------------------------------- watchmaker
	watchmaker = {
		start = "hub",
		nodes = {
			hub = {
				text = {
					"Welcome to Vanta. Precision is a habit. So is punctuality, I hope.",
					"Back again? Every second counts here. Some of them more than others.",
				},
				options = {
					{
						id = "shop",
						text = "Let me see the watches.",
						exit = true,
						actions = { { kind = "open", target = "shop", args = { shopId = "watch" } } },
					},
					{ id = "why", text = "Why do bankers care so much about watches?", to = "why" },
					{ id = "value", text = "Does a watch hold its value?", to = "value" },
					{ id = "bye", text = "Thank you.", exit = true },
				} :: { any },
			},
			why = {
				text = "Partly status, partly habit. A banker's day is counted in minutes: calls, deadlines, closings. The joke is that the watch gets more expensive as the title gets longer. The truth is the best of them wear something reliable and are never late.",
				options = { { id = "back", text = "Reliable and never late.", to = "hub" } } :: { any },
			},
			value = {
				text = "Like any asset: scarcity, quality and demand. Most watches lose value the moment you leave the shop. A few appreciate. Buy what you'll wear, not what you hope to flip. Speculating on your wrist is still speculating.",
				options = {
					{
						id = "wear",
						text = "Buy to wear, not to flip.",
						to = "hub",
						actions = { { kind = "statXp", stats = { "risk" }, quality = 50, key = "watch_value" } },
					},
				} :: { any },
			},
		},
	},

	---------------------------------------------------------------------------------------------- shoe clerk
	shoe_clerk = {
		start = "hub",
		nodes = {
			hub = {
				text = {
					"Welcome to Strider! The floor's polished so you can see your reflection in your future shoes.",
					"Hey, good to see you! Those shoes have been through something. Let's fix that.",
				},
				options = {
					{
						id = "shop",
						text = "Show me some shoes.",
						exit = true,
						actions = { { kind = "open", target = "shop", args = { shopId = "shoes" } } },
					},
					{ id = "matter", text = "Do shoes really matter?", to = "matter" },
					{ id = "oxford", text = "Oxford or derby?", to = "oxford" },
					{ id = "bye", text = "See you, Dev.", exit = true },
				} :: { any },
			},
			matter = {
				text = "They're one of the three pieces that set your outfit level. Sneakers say campus. Oxfords say client meeting. Scuffed oxfords say 'I slept at the office.' Which, fair, sometimes you will.",
				options = { { id = "back", text = "No scuffs.", to = "hub" } } :: { any },
			},
			oxford = {
				text = "Oxfords have closed lacing: sleeker, more formal. Derbies have open lacing: comfier, a little more casual. For your first client meeting, oxfords. Black or dark brown. Polished. Always polished.",
				options = {
					{
						id = "polish",
						text = "Oxfords, polished.",
						to = "hub",
						actions = { { kind = "statXp", stats = { "charisma" }, quality = 50, key = "shoe_tip" } },
					},
				} :: { any },
			},
		},
	},

	---------------------------------------------------------------------------------------------- decorator
	decorator = {
		start = "hub",
		nodes = {
			hub = {
				text = {
					"Hi! Your desk is a billboard. Let's make it say something.",
					"Welcome back! I saved you a lamp. It's very you. Well, the future you.",
				},
				options = {
					{
						id = "shop",
						text = "Browse furniture and decor.",
						exit = true,
						actions = { { kind = "open", target = "shop", args = { shopId = "decor" } } },
					},
					{ id = "what", text = "What can I decorate?", to = "what" },
					{ id = "tips", text = "Any tips?", to = "tips" },
					{ id = "bye", text = "Thanks, Camille!", exit = true },
				} :: { any },
			},
			what = {
				text = "Your dorm room, your apartment at The Ashford, your desk at work, and once you're senior enough, your own office. Each has slots for furniture, art and desk pieces. Your deal plaques go on the desk, then on a bookshelf once you have an office.",
				options = { { id = "back", text = "Desk first, office later.", to = "hub" } } :: { any },
			},
			tips = {
				text = "Buy one great piece instead of five cheap ones. Same rule as investing: quality compounds. And plants. Plants make any office look like the person in it has their life together.",
				options = {
					{
						id = "quality",
						text = "Quality compounds. And plants.",
						to = "hub",
						actions = { { kind = "statXp", stats = { "discipline" }, quality = 50, key = "decor_tip" } },
					},
				} :: { any },
			},
		},
	},
}
