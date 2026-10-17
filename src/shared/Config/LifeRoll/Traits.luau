--!strict
-- Config/LifeRoll: the eight attributes, archetypes and focus areas (design v3 §3). Pure data.
--
--   stats      { {id, name, short, desc} } in display order (knowledge skill speed charisma network discipline
--              risk luck); the ids are the keys of profile.stats (contracts §3)
--   archetypes { ["a|b"] = {id, name, desc} } one per pair of stat ids (a before b in `stats` order): the
--              archetype comes from the player's two highest attributes
--   focus      { {id, name, stats = {statA, statB}, desc, glyph} } (v3 §3: the linked stats grow 2x, the rest
--              0.75x; change once per career week)

export type StatDef = { id: string, name: string, short: string, desc: string }
export type ArchetypeDef = { id: string, name: string, desc: string }
export type FocusDef = { id: string, name: string, stats: { string }, desc: string, glyph: string }

local stats: { StatDef } = {
	{
		id = "knowledge",
		name = "Knowledge",
		short = "KNO",
		desc = "Finance concepts. More hint lines on graded work (1 at 30, 2 at 60, 3 at 85).",
	},
	{
		id = "skill",
		name = "Skill",
		short = "SKL",
		desc = "Excel and modeling craft. Widens number tolerance on fill and spot tasks (up to +50% at 99).",
	},
	{
		id = "speed",
		name = "Speed",
		short = "SPD",
		desc = "Work speed. Task timers run 0.4% longer per point above 50 (shorter below), up to 20%.",
	},
	{
		id = "charisma",
		name = "Charisma",
		short = "CHA",
		desc = "Interviews, pitches and dialogue. Up to +8 quality points on dialogue sections.",
	},
	{
		id = "network",
		name = "Network",
		short = "NET",
		desc = "Contacts and connections. Better job-offer odds and more networking invites.",
	},
	{
		id = "discipline",
		name = "Discipline",
		short = "DIS",
		desc = "Deadlines and habits. Extra grace on deadlines and lower living costs.",
	},
	{
		id = "risk",
		name = "Risk Sense",
		short = "RSK",
		desc = "Reads the downside. Up to +5% risk-limit headroom on concentration limits.",
	},
	{
		id = "luck",
		name = "Luck",
		short = "LCK",
		desc = "Cosmetic and event perks only. Never touches grades, returns or reviews.",
	},
}

local function a(id: string, name: string, desc: string): ArchetypeDef
	return { id = id, name = name, desc = desc }
end

-- Keys are "first|second" in the order of `stats` above.
local archetypes: { [string]: ArchetypeDef } = {
	["knowledge|skill"] = a("quant_machine", "Quant Machine", "Lives in the model. Every number has a source."),
	["knowledge|speed"] = a("quick_study", "Quick Study", "Learns the deal on the elevator ride up."),
	["knowledge|charisma"] = a("thought_leader", "Thought Leader", "Explains the thesis so clients repeat it."),
	["knowledge|network"] = a("insider", "Insider", "Knows the market and everyone who moves it."),
	["knowledge|discipline"] = a("scholar", "Scholar", "Reads the whole 10-K. Twice."),
	["knowledge|risk"] = a("macro_mind", "Macro Mind", "Sees the rate cycle before the desk does."),
	["knowledge|luck"] = a("savant", "Savant", "Brilliant, and somehow always in the right room."),
	["skill|speed"] = a("grinder", "Grinder", "Turns comments faster than anyone on the floor."),
	["skill|charisma"] = a("pitchbook_artist", "Pitchbook Artist", "Beautiful decks and the voice to present them."),
	["skill|network"] = a("deal_architect", "Deal Architect", "Builds the structure and knows who will buy it."),
	["skill|discipline"] = a("model_builder", "Model Builder", "Zero broken links. Ever."),
	["skill|risk"] = a("structurer", "Structurer", "Engineers the downside out of every deal."),
	["skill|luck"] = a("natural", "Natural", "Makes the hard stuff look easy."),
	["speed|charisma"] = a("closer", "Closer", "Gets the signature before the meeting ends."),
	["speed|network"] = a("hustler", "Hustler", "Ten coffees a week, every one a lead."),
	["speed|discipline"] = a("workhorse", "Workhorse", "First in, last out, never late."),
	["speed|risk"] = a("floor_trader", "Floor Trader", "Quick hands and a quicker stop-loss."),
	["speed|luck"] = a("wildcard", "Wildcard", "Moves fast and lands on their feet."),
	["charisma|network"] = a("rainmaker", "Rainmaker", "Clients call them first."),
	["charisma|discipline"] = a("diplomat", "Diplomat", "Calms the room and keeps the deal on schedule."),
	["charisma|risk"] = a("negotiator", "Negotiator", "Knows exactly how far to push."),
	["charisma|luck"] = a("showman", "Showman", "Every pitch is an event."),
	["network|discipline"] = a("operator", "Operator", "Runs the process and every person in it."),
	["network|risk"] = a("dealmaker", "Dealmaker", "Finds the trade and the counterparty."),
	["network|luck"] = a("connector", "Connector", "Somehow knows someone everywhere."),
	["discipline|risk"] = a("guardian", "Guardian", "The desk sleeps well when they sign off."),
	["discipline|luck"] = a("steady_hand", "Steady Hand", "Consistent, calm and quietly fortunate."),
	["risk|luck"] = a("gambler", "Gambler", "High conviction, higher stakes."),
}

local focus: { FocusDef } = {
	{
		id = "modeling",
		name = "Modeling",
		stats = { "skill", "knowledge" },
		desc = "Spreadsheets, valuation and technicals.",
		glyph = "📊",
	},
	{
		id = "markets",
		name = "Markets",
		stats = { "risk", "speed" },
		desc = "Reading tape, sizing trades and moving quickly.",
		glyph = "📈",
	},
	{
		id = "client",
		name = "Client Coverage",
		stats = { "charisma", "network" },
		desc = "Pitches, relationships and the room.",
		glyph = "🤝",
	},
	{
		id = "leadership",
		name = "Leadership",
		stats = { "discipline", "charisma" },
		desc = "Running the team and owning the outcome.",
		glyph = "⭐",
	},
	{
		id = "execution",
		name = "Execution",
		stats = { "speed", "skill" },
		desc = "Turning comments and hitting every deadline.",
		glyph = "⚡",
	},
	{
		id = "risk",
		name = "Risk",
		stats = { "risk", "discipline" },
		desc = "Limits, downside and doing it by the book.",
		glyph = "🛡",
	},
}

return { stats = stats, archetypes = archetypes, focus = focus }
