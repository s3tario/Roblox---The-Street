--!strict
-- Boss lines for the weekly review meeting (owned by `careerPath`; design v3 §6). Logic/Review.dialogue picks one
-- line from each relevant pool, deterministically per player and week, so the meeting varies with the outcome and
-- with which review components were strong or weak. Placeholders: {name} {boss} {company} {title} {newTitle}
-- {score} {excess} {need} {tier} {week}.

return {
	opening = {
		office = {
			"Come in, {name}. Close the door and grab a seat.",
			"{name}. Good, you made it. Let's go through your week.",
			"Have a seat, {name}. I've got your numbers right here.",
			"Morning, {name}. Coffee's fresh. Let's talk about week {week}.",
		},
		phone = {
			"{name}, it's {boss}. You didn't make it up to my office, so let's do this over the phone.",
			"{name}? {boss} here. I'm between meetings, so we'll do your review on the phone.",
			"Got a minute, {name}? It's {boss}. Let's run through your week.",
		},
		discipline = {
			"{name}. Sit down. We need to talk about your book.",
			"{name}, this can't wait. Risk flagged your positions.",
		},
	},

	-- Component feedback: one line for the strongest and (when weak) the weakest component.
	strong = {
		investment = {
			"Your book beat the benchmark by {excess} this week. That's real alpha.",
			"The desk noticed your P/L. Beating the index like that gets people talking.",
		},
		risk = {
			"Clean risk sheet. No breaches, sensible sizing. That's how you stay in this business.",
			"Risk management was textbook. I never had to look twice at your positions.",
		},
		work = {
			"Your models came back clean and on time. The team trusts your work.",
			"The deliverables were sharp this week. That's the standard.",
		},
		reputation = {
			"Clients asked for you by name. That doesn't happen by accident.",
			"The team says you're the one they want on a deal. Keep that up.",
		},
	},
	weak = {
		investment = {
			"Your book lagged the benchmark by {excess}. Do the research before you trade.",
			"The market got the better of you this week. Study your entries and size smaller.",
		},
		investment_none = {
			"You barely touched your book. Markets are part of this job: make the trades.",
			"Your trading book sat idle all week. Open the terminal and put it to work.",
		},
		risk = {
			"Your risk sheet worries me. Respect the limits or they'll be enforced for you.",
			"Too many limit warnings. Size down and use your stops.",
		},
		work = {
			"The work had too many errors. Slow down and check your numbers.",
			"I need more from you on the desk. Finish your assignments and own the details.",
		},
		work_none = {
			"I didn't see much work from you this week. The assignments don't do themselves.",
		},
		reputation = {
			"The team needs to see more of you. Step up on the client calls.",
			"Your reputation on the floor is thin. Show up for the team and the clients notice.",
		},
	},

	-- Outcome lines.
	outcome = {
		promoted = {
			"I'm putting you up for promotion, and it's approved. Congratulations, {newTitle}.",
			"You've outgrown your seat. Starting Monday, you're our new {newTitle}.",
			"The committee signed off this morning. Welcome to {newTitle}.",
		},
		star = {
			"A Star week, {name}. Keep this pace and the next title comes fast.",
			"That was a standout week. Exactly what we hired you for.",
		},
		keep_going = {
			"Solid week. Keep up the good work.",
			"You're on track. Stay consistent and the results will follow.",
			"Good week. Nothing to fix, just keep stacking them.",
		},
		coaching = {
			"This week was below where you need to be. I'm assigning you some coaching. Let's turn it around.",
			"Underperforming, {name}. You can fix this, but it starts on Monday.",
		},
		probation = {
			"I have to put you on probation. Your risk limits are cut until your numbers recover. Next review is high stakes.",
			"This is a formal warning: you're on probation. I need to see a real turnaround.",
		},
		critical_warning = {
			"That was a critical week. One more like it and I can't protect you.",
			"Critical, {name}. This is your last warning. Next week has to be different.",
		},
		fired = {
			"I'm sorry, {name}. We're letting you go. Two critical reviews in a row is a line I can't move.",
			"This isn't easy to say. Today is your last day at {company}.",
		},
		fired_risk = {
			"A major risk-limit violation is a firing offence here. I'm sorry, {name}. Today is your last day.",
		},
		fired_mass = {
			"The firm is cutting headcount, and your last review put you on the list. I'm sorry, {name}.",
		},
		lifeline = {
			"I was ready to let you go. Then your alumni network called. Someone vouched for you, {name}. You keep your job, on probation. Don't waste it.",
		},
	},

	-- Why a ready-looking player wasn't promoted.
	blocked = {
		outfit = {
			"Your numbers say {newTitle}. Your outfit doesn't. Come back dressed for the role: Outfit Level {need}.",
		},
		school = {
			"I'd promote you today, but {newTitle} at this firm requires a {tier}+ school. That's the partnership's rule, not mine.",
		},
		level = {
			"You're doing well. You need a bit more experience before {newTitle}.",
		},
		core = {
			"Finish your core assignments and the promotion case writes itself.",
		},
		ovr = {
			"Keep building your skills. The committee wants a stronger Overall before {newTitle}.",
		},
	},

	closing = {
		"Back to it. My door's open.",
		"That's all. Go get Monday.",
		"Thanks, {name}. Same time next Friday.",
	},
	closing_fired = {
		"Career Services on the Street can help you plan what's next. Good luck.",
	},
}
