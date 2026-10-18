--!strict
-- Market event overlays (owned by `market`; design v3 §10, spec §8, contracts §13): ids, display names, blurbs and
-- the headline each posts when it starts. The behaviour lives in Shared/Logic/Market/Events. EventService (events
-- feature) decides WHEN they happen and calls MarketService:TriggerEvent(id, params).

export type EventInfo = {
	id: string,
	name: string,
	desc: string,
	headline: string,
	tone: string, -- "good" | "bad" | "warn" | "info"
	glyph: string,
}

local Events = {}

Events.IDS = {
	"crash",
	"boom",
	"flash_crash",
	"meme_rally",
	"rate_shock",
	"earnings_frenzy",
	"crazy_day",
	"fed_day",
	"holiday",
}

Events.info = {
	crash = {
		id = "crash",
		name = "Market Crash",
		desc = "Sellers everywhere. The STREET 10 is sliding hard; expect a slow, partial recovery.",
		headline = "MARKET CRASH: panic selling sweeps the STREET 10",
		tone = "bad",
		glyph = "!",
	},
	boom = {
		id = "boom",
		name = "Market Boom",
		desc = "Buyers pile in across the board. Momentum is strong, but booms rarely hold all their gains.",
		headline = "MARKET BOOM: a buying frenzy lifts every sector",
		tone = "good",
		glyph = "^",
	},
	flash_crash = {
		id = "flash_crash",
		name = "Flash Crash",
		desc = "A sudden air pocket. Prices dropped in seconds; most of it usually comes back by the close.",
		headline = "FLASH CRASH: algorithms dump stocks in seconds",
		tone = "bad",
		glyph = "!",
	},
	meme_rally = {
		id = "meme_rally",
		name = "Meme Rally",
		desc = "One stock is going to the moon on internet hype. It tends to fade over the next two days.",
		headline = "MEME RALLY: {name} ({ticker}) rockets as online traders pile in",
		tone = "warn",
		glyph = "*",
	},
	rate_shock = {
		id = "rate_shock",
		name = "Rate Shock",
		desc = "Bond yields spiked. Banks and real estate are hit hardest; money rotates into energy and staples.",
		headline = "RATE SHOCK: yields jump, rate-sensitive stocks tumble",
		tone = "bad",
		glyph = "%",
	},
	earnings_frenzy = {
		id = "earnings_frenzy",
		name = "Earnings Frenzy",
		desc = "Three companies report at today's close. Surprises will be bigger than usual.",
		headline = "EARNINGS FRENZY: {list} all report after today's close",
		tone = "warn",
		glyph = "$",
	},
	crazy_day = {
		id = "crazy_day",
		name = "Crazy Day",
		desc = "Volatility is three times normal for a full market day. Size your trades carefully.",
		headline = "VOLATILITY ADVISORY: wild swings expected all session",
		tone = "warn",
		glyph = "~",
	},
	fed_day = {
		id = "fed_day",
		name = "Fed Day",
		desc = "The central bank announces its rate decision mid-session. Expect fireworks around the moment.",
		headline = "FED DAY: rate decision due this session",
		tone = "warn",
		glyph = "%",
	},
	holiday = {
		id = "holiday",
		name = "Market Holiday",
		desc = "The exchange is closed. No trading until it reopens; enjoy the social events.",
		headline = "MARKET HOLIDAY: the exchange is closed today",
		tone = "info",
		glyph = "-",
	},
} :: { [string]: EventInfo }

return Events
