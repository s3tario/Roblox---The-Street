--!strict
-- Market news templates (owned by `market`). Shared/Logic/Market/News fills them; every name is fictional.
-- Placeholders: {name} {ticker} {sector} {eps} {cons} {pct} {move} {days} {odds} {up} {down} {level} {leaders}
-- {laggards} {reason}. Each kind lists variants; the server picks one with its seeded Rng.

export type Catalyst = { announce: string, good: string, bad: string }

local News = {}

News.templates = {
	consensus = {
		"{name} ({ticker}) reports in {days} days. Street consensus: EPS {cons}.",
		"Earnings watch: {ticker} due in {days} days, analysts expect EPS of {cons}.",
		"{ticker} preview: consensus sits at {cons} a share ahead of results in {days} days.",
	},
	beat = {
		"{name} beats: EPS {eps} vs {cons} expected. Shares {move} after hours.",
		"{ticker} tops estimates ({eps} vs {cons}); stock {move} in late trading.",
		"Strong quarter at {name}: EPS {eps} beats the {cons} consensus. {ticker} {move}.",
	},
	miss = {
		"{name} misses: EPS {eps} vs {cons} expected. Shares {move} after hours.",
		"{ticker} falls short ({eps} vs {cons}); stock {move} in late trading.",
		"Rough quarter at {name}: EPS {eps} misses the {cons} consensus. {ticker} {move}.",
	},
	inline = {
		"{name} reports in line: EPS {eps} vs {cons} expected. Shares {move}.",
		"No surprises at {ticker}: EPS {eps}, right on the {cons} consensus.",
	},
	mover_up = {
		"{name} ({ticker}) jumps {pct} as {reason}.",
		"{ticker} rallies {pct} on reports that {reason}.",
	},
	mover_down = {
		"{name} ({ticker}) slides {pct} as {reason}.",
		"{ticker} drops {pct} on reports that {reason}.",
	},
	close = {
		"Closing bell: STREET 10 at {level} ({pct}). Leaders: {leaders}. Laggards: {laggards}.",
		"Market close: ST10 {level} ({pct}). Up: {leaders}. Down: {laggards}.",
	},
	fed_hike = { "FED HIKES: the central bank raises rates unexpectedly. Stocks {move}." },
	fed_cut = { "FED CUTS: surprise rate cut sends the STREET 10 {move}." },
	fed_hold = { "FED HOLDS: rates unchanged, as expected. The STREET 10 {move}." },
	reopen = { "The exchange reopens after the market holiday. Trading resumes." },
}

-- Plausible reasons behind a big move, by sector and direction.
News.reasons = {
	tech = {
		up = { "a hyperscaler signs a huge chip order", "its new model wows the developer conference" },
		down = { "a key customer delays orders", "regulators open a probe into its data practices" },
	},
	financials = {
		up = { "loan growth surprises analysts", "it unveils a bigger buyback" },
		down = { "bad loans pile up in commercial property", "a trading desk posts a surprise loss" },
	},
	autos = {
		up = { "delivery numbers crush estimates", "a new battery plant comes online early" },
		down = { "a recall hits its best-selling model", "price cuts squeeze margins" },
	},
	realestate = {
		up = { "occupancy rebounds across its towers", "it sells a landmark building at a premium" },
		down = { "a major tenant breaks its lease", "office vacancies climb downtown" },
	},
	energy = {
		up = { "crude spikes on supply worries", "a new offshore field starts pumping" },
		down = { "crude slumps on a demand scare", "a refinery outage dents output" },
	},
	healthcare = {
		up = { "a late-stage drug trial succeeds", "it wins a big hospital contract" },
		down = { "a drug trial misses its target", "lawmakers float price caps" },
	},
	consumer = {
		up = { "foot traffic beats forecasts", "its online sales double" },
		down = { "shoppers pull back on spending", "a warehouse fire snarls deliveries" },
	},
	industrials = {
		up = { "it lands a record jet engine order", "a satellite launch goes perfectly" },
		down = { "a rocket test ends in a fireball", "an airline cancels a large order" },
	},
	staples = {
		up = { "a price rise sticks with shoppers", "its new cereal flies off shelves" },
		down = { "a product recall hits stores", "ingredient costs jump" },
	},
} :: { [string]: { up: { string }, down: { string } } }

-- Sector catalysts announced one market day ahead with stated odds (spec §7).
News.catalysts = {
	chip_export = {
		announce = "Tomorrow: trade officials rule on chip export rules. Desk odds {odds} for approval ({sector} {up}), else {down}.",
		good = "Chip exports approved. {sector} stocks rally.",
		bad = "Chip exports blocked. {sector} stocks slide.",
	},
	ai_summit = {
		announce = "Tomorrow: the Downtown AI Summit. Desk odds {odds} for upbeat guidance ({sector} {up}), else {down}.",
		good = "Upbeat guidance at the AI Summit lifts {sector}.",
		bad = "The AI Summit disappoints. {sector} stocks sag.",
	},
	stress_test = {
		announce = "Tomorrow: bank stress test results. Desk odds {odds} for a clean pass ({sector} {up}), else {down}.",
		good = "Banks sail through the stress test. {sector} rally.",
		bad = "Stress test flags weak spots. {sector} sell off.",
	},
	capital_rules = {
		announce = "Tomorrow: regulators vote on capital rules. Desk odds {odds} for relief ({sector} {up}), else {down}.",
		good = "Capital rules eased. {sector} climb.",
		bad = "Tougher capital rules pass. {sector} drop.",
	},
	ev_credit = {
		announce = "Tomorrow: lawmakers vote on EV tax credits. Desk odds {odds} it passes ({sector} {up}), else {down}.",
		good = "EV credits pass. {sector} stocks surge.",
		bad = "EV credits voted down. {sector} stocks slump.",
	},
	auto_sales = {
		announce = "Tomorrow: monthly auto sales. Desk odds {odds} for a beat ({sector} {up}), else {down}.",
		good = "Auto sales beat forecasts. {sector} rise.",
		bad = "Auto sales disappoint. {sector} fall.",
	},
	housing_data = {
		announce = "Tomorrow: housing and office data. Desk odds {odds} for a strong print ({sector} {up}), else {down}.",
		good = "Strong property data. {sector} gain.",
		bad = "Weak property data. {sector} slip.",
	},
	zoning_vote = {
		announce = "Tomorrow: the city council votes on downtown zoning. Desk odds {odds} it passes ({sector} {up}), else {down}.",
		good = "Zoning reform passes. {sector} jump.",
		bad = "Zoning reform fails. {sector} sink.",
	},
	opex_meeting = {
		announce = "Tomorrow: the OPEX+ producers meet. Desk odds {odds} for a supply cut ({sector} {up}), else {down}.",
		good = "OPEX+ cuts supply. {sector} stocks jump with crude.",
		bad = "OPEX+ opens the taps. {sector} stocks fall with crude.",
	},
	pipeline = {
		announce = "Tomorrow: a ruling on the Northline pipeline. Desk odds {odds} for approval ({sector} {up}), else {down}.",
		good = "Northline pipeline approved. {sector} rally.",
		bad = "Northline pipeline rejected. {sector} drop.",
	},
	drug_panel = {
		announce = "Tomorrow: an advisory panel reviews a blockbuster drug. Desk odds {odds} for a yes ({sector} {up}), else {down}.",
		good = "The drug panel votes yes. {sector} climb.",
		bad = "The drug panel votes no. {sector} slide.",
	},
	pricing_bill = {
		announce = "Tomorrow: a vote on drug pricing reform. Desk odds {odds} it fails ({sector} {up}), else {down}.",
		good = "Drug pricing bill fails. {sector} rally.",
		bad = "Drug pricing bill passes. {sector} fall.",
	},
	holiday_sales = {
		announce = "Tomorrow: early holiday sales figures. Desk odds {odds} for a strong season ({sector} {up}), else {down}.",
		good = "Holiday sales boom. {sector} stocks rise.",
		bad = "Holiday sales flop. {sector} stocks slide.",
	},
	consumer_mood = {
		announce = "Tomorrow: the consumer confidence survey. Desk odds {odds} for a rebound ({sector} {up}), else {down}.",
		good = "Consumer confidence rebounds. {sector} gain.",
		bad = "Consumer confidence sinks. {sector} drop.",
	},
	defense_budget = {
		announce = "Tomorrow: the defense budget vote. Desk odds {odds} for an increase ({sector} {up}), else {down}.",
		good = "Defense budget rises. {sector} climb.",
		bad = "Defense budget trimmed. {sector} dip.",
	},
	airline_orders = {
		announce = "Tomorrow: the Skyport air show order tally. Desk odds {odds} for record orders ({sector} {up}), else {down}.",
		good = "Record orders at the air show. {sector} jump.",
		bad = "Thin orders at the air show. {sector} fall.",
	},
	crop_report = {
		announce = "Tomorrow: the harvest report. Desk odds {odds} for a bumper crop ({sector} {up}), else {down}.",
		good = "Bumper harvest cuts costs. {sector} rise.",
		bad = "Poor harvest lifts costs. {sector} slip.",
	},
} :: { [string]: Catalyst }

return News
