--!strict
-- Player trading book (owned by `market`; docs/contracts.md §3 and §6, design v3 §11). PortfolioService is the only
-- writer; Shared/Logic/Portfolio/Ledger documents every field. Students start with the $5,000 paper account.
--
--   portfolio (replicated to its owner)
--     cash, positions = { [ticker] = {shares, avgCost} }   positions are session-only: flattened on leave
--     bookSize, realized, trades (ring of 25), weekReturns (ring of 20 weekly records), peak, violations,
--     credits = { capital }, paidCapital, paper, stops = { [ticker] = {stop?, take?} }, flows, tradeCount, tradeSeq,
--     limits = { rank, concentration, gross, short, margin, mult, headroom }   current risk limits
--     risk = { weekViolations, breaches = { {kind, ticker?, value, limit, deadline} }, max }
--     lastWipe = { lost, at, restored }, sessionStart
--   portfolioLog (private, saved): equity samples keyed by active seconds for review-window metrics
--     samples = { {a, e, b, g, n, v} }, seg, weekFrom, clock

return {
	portfolio = {
		cash = 5000,
		positions = {},
		bookSize = 5000,
		realized = 0,
		trades = {},
		weekReturns = {},
		peak = 5000,
		violations = 0,
		credits = { capital = 0 },
		paidCapital = 0,
		paper = true,
		stops = {},
		flows = 0,
		tradeCount = 0,
		tradeSeq = 0,
		limits = {
			rank = 0,
			concentration = 0.4,
			gross = 1,
			short = false,
			margin = false,
			mult = 1,
			headroom = 0,
		},
		risk = { weekViolations = 0, breaches = {}, max = 3 },
		lastWipe = { lost = 0, at = 0, restored = true },
		sessionStart = 5000,
	},
	portfolioLog = {
		samples = {},
		seg = 0,
		weekFrom = -1,
		clock = 0,
	},
	_private = { portfolioLog = true },
}
