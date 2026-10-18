--!strict
-- Market model types (owned by `market`), shared by Logic/Market/Model and Logic/Market/Events.
-- Nothing marked "hidden" ever leaves the server (fair values, surprises, reaction sizes).

local Tickers = require(script.Parent.Parent.Parent.Config.Tickers)
local Rng = require(script.Parent.Parent.Parent.Util.Rng)

export type Earnings = {
	day: number, -- global market day of the report (released after that day's close)
	natural: number, -- the scheduled cycle day (an Earnings Frenzy may pull `day` earlier)
	consensus: number, -- quarterly EPS consensus
	published: boolean, -- consensus is public (Tickers.CONSENSUS_LEAD days before)
	surprise: number, -- hidden: actual / consensus - 1
	mult: number, -- hidden: log price reaction per unit of surprise
	frenzy: boolean,
}

export type Result = {
	day: number,
	eps: number,
	consensus: number,
	surprise: number,
	reaction: number, -- price move at the release (ratio)
	result: string, -- "beat" | "miss" | "inline"
}

export type TickerState = {
	id: string,
	def: Tickers.TickerDef,
	price: number,
	fv: number, -- hidden fair value
	target: number, -- public analyst target (noisy fair value, refreshed daily)
	open: number,
	high: number,
	low: number,
	prevClose: number,
	close: number, -- last regular-session close
	intraday: { number }, -- one price per open tick of the current day
	daily: { number }, -- last HISTORY_DAYS session closes (oldest first)
	quarters: { number }, -- last four quarterly EPS (oldest first)
	eps: number, -- trailing twelve months
	revenue: number,
	ebitda: number,
	netIncome: number,
	dps: number, -- dividend per share
	next: Earnings,
	last: Result?,
}

export type Impulse = {
	scope: string, -- "market" | "sector" | "ticker"
	key: string?, -- sector id or ticker id
	perTick: number, -- log move per open tick
	left: number, -- open ticks remaining
	delay: number, -- open ticks to wait before starting
	fvShare: number, -- fraction of each move also applied to the fair value (how much of the shock persists)
	noMR: boolean, -- suspend mean reversion on the affected tickers while running
}

export type EventState = {
	id: string,
	startsAt: number,
	endsAt: number, -- wall time (estimated for events that run on open ticks)
	params: { [string]: any },
	ticks: number, -- open ticks since the start
	openTicks: number?, -- runs for this many open ticks (nil: runs until endsAt, e.g. a holiday)
	closes: boolean, -- the exchange is closed while it runs
	data: { [string]: any },
}

export type NewsItem = {
	id: number,
	at: number,
	day: number, -- server-relative day (1 = the day the server started)
	kind: string,
	ticker: string?,
	sector: string?,
	headline: string,
	tone: string, -- "good" | "bad" | "warn" | "info"
}

export type Catalyst = {
	day: number, -- global market day it resolves (CATALYST_TICK into the session)
	key: string,
	sector: string,
	odds: number, -- stated probability of the good outcome
	up: number, -- sector move on the good outcome (ratio)
	down: number, -- sector move on the bad outcome (negative ratio)
	resolved: boolean,
	good: boolean?,
}

export type IndexState = {
	level: number,
	open: number,
	high: number,
	low: number,
	prevClose: number,
	close: number,
	intraday: { number },
	daily: { number },
}

export type State = {
	seed: number,
	rng: Rng.Rng,
	divisor: number,
	startDay: number,
	day: number,
	phase: string, -- "open" | "after" | "closed"
	k: number, -- latest open tick index (-1 before the first)
	tickT: number, -- server time of the last processed tick
	openedDay: number, -- the last day the market traded
	closedDay: number, -- the last day whose close was processed
	tickers: { TickerState },
	byId: { [string]: TickerState },
	index: IndexState,
	news: { NewsItem },
	newsSeq: number,
	event: EventState?,
	impulses: { Impulse },
	catalyst: Catalyst?,
	outbox: { { [string]: any } },
}

-- The helpers Model hands to event overlays (Logic/Market/Events).
export type Kit = {
	impulse: (
		scope: string,
		key: string?,
		total: number,
		ticks: number,
		opts: { fvShare: number?, noMR: boolean?, delay: number? }?
	) -> (),
	news: (kind: string, vars: { [string]: any }, tone: string, extra: { [string]: any }?) -> (), -- a News template kind
	now: number,
}

return {}
