--!strict
-- Quests (owned by `tutorial`; design v1 §2, v3 §2 and §19 M1): the onboarding chain from the Eastbridge bus depot to
-- the first weekly review, the side quests, the Recruiting Board tuning and every player-facing tutorial string.
-- Pure data plus a text helper: safe on the server, the client and under Lune. Logic/QuestLine runs the rules.
--
--   Quests.steps = { StepDef }        the chain, in order (Quests.stepById[id], Quests.stepIndex[id])
--   Quests.side = { SideDef }         side quests (Quests.sideById[id])
--   Quests.recruiting                 Recruiting Board tuning
--   Quests.text(key, vars?) -> string Quests.strings (Config/Quests/Strings), {placeholders} filled from vars
--
--   StepDef = {
--     id, phase = "campus" | "street", title, objective (text with {placeholders}), hint,
--     core = true?          never skippable (the Life Roll and getting a job)
--     veteran = true?       finished automatically after a rebirth (you have done campus before)
--     doneWhen = Cond       facts that complete the step (Logic/QuestLine.check)
--     enter = { offerTask = taskId }?   what happens when the step starts (TutorialService)
--     waypoint = Waypoint?  where the gold arrow points (TutorialService resolves it to a position)
--     skip = { teleport = anchorId } | { enter = "lobby" | "track" }?   moves the player when the step is skipped
--     milestone = true?     celebrate the step with a banner: banner = { title, subtitle } ({placeholders} from
--                           QuestLine.vars plus {name}); without one the step's title is used
--     holdWhile = Cond?, back = stepId?   when holdWhile stops holding, the chain steps back to `back` (declined
--                           every offer: back to recruiting; a fresh start after a firing: back to recruiting)
--   }
--   Cond keys (all must hold; `any` / `all` nest): built, employed, hired, hasOffer, inOffice, inOwnOffice,
--     onOwnFloor, onboarded, club, zone = id, zoneIn = { id }, mark = stepId, taskDone = taskId,
--     networked = n, jobTasks = n, trades = n, reviews = n
--   Waypoint kinds: door {id}, interact {id, zone?}, npc {id}, npcNext {ids}, tower, office {floor, anchor},
--     officeInteract {floor, id}, boss, desk, anchor {id}   (floor "track" = the player's department floor)
--   SideDef = { id, phase, title, desc, goal, on = Event filter, reward = { xp?, cash? } }
--     on.kind: task {taskId, minQuality?} | talk {npcs} | outfit {level} | deal | trade {profitable?} | review {band}

local Strings = require(script.Strings)

export type Cond = { [string]: any }
export type Waypoint = { kind: string, id: string?, ids: { string }?, zone: string?, floor: string?, anchor: string? }
export type StepDef = {
	id: string,
	phase: string,
	title: string,
	objective: string,
	hint: string,
	core: boolean?,
	veteran: boolean?,
	doneWhen: Cond,
	enter: { offerTask: string? }?,
	waypoint: Waypoint?,
	skip: { teleport: string?, enter: string? }?,
	milestone: boolean?,
	banner: { title: string, subtitle: string }?,
	holdWhile: Cond?,
	back: string?,
}
export type SideDef = {
	id: string,
	phase: string,
	title: string,
	desc: string,
	goal: number,
	on: { [string]: any },
	reward: { xp: number?, cash: number? },
}

local Quests = {}

Quests.CHAIN_ID = "onboarding" -- QuestService objective id for the chain
Quests.GUIDE_ID = "guide" -- QuestService objective id for ongoing guidance after the chain
Quests.CAREER_ID = "career" -- careerPath's objective id (review ready, report to your firm, after a firing)
Quests.SIDE_ID = "side"
Quests.DONE = "done"
Quests.SKIP_AFTER = 600 -- active seconds stuck on a non-core step before a skip is offered (v3: never soft-lock)
Quests.NETWORK_GOAL = 3
Quests.TRACK = "ib" -- milestone 1 recruits into Investment Banking

-- Objective priority on the HUD: the highest wins; ties go to the most recent.
Quests.priority = { career = 100, onboarding = 50, guide = 20, side = 10 } :: { [string]: number }

Quests.arrival = { title = "Eastbridge", subtitle = "Wall Street is 40 minutes and a whole world away." }

local CAMPUS_NPCS = { "npc_alum", "npc_barista", "npc_bus_driver", "npc_professor", "npc_roommate", "npc_recruiter" }
Quests.NETWORK_NPCS = CAMPUS_NPCS

Quests.steps = {
	---------------------------------------------------------------------------------------------- campus
	{
		id = "career_center",
		phase = "campus",
		title = "Find the Career Center",
		objective = "Head into the Eastbridge Career Center.",
		hint = "Follow the gold arrow across the quad. Everyone starts here.",
		veteran = true,
		doneWhen = { any = { { zone = "career_center" }, { built = true } } :: { any } },
		waypoint = { kind = "door", id = "door_campus_career_center" },
	},
	{
		id = "life_roll",
		phase = "campus",
		title = "Do your Life Roll",
		objective = "Do your Life Roll at the Career Center kiosk.",
		hint = "Type your first name, spin your school, family, stats and outfit, then lock it in.",
		core = true,
		doneWhen = { built = true },
		waypoint = { kind = "interact", id = "profile_builder", zone = "career_center" },
		milestone = true,
		banner = {
			title = "This is your life, {name}",
			subtitle = "Locked in. Now go meet Dana Whitfield, your career advisor.",
		},
	},
	{
		id = "advisor",
		phase = "campus",
		title = "Meet your advisor",
		objective = "Meet your career advisor, Dana Whitfield, in the Career Center.",
		hint = "Advisors know which firms recruit here and what they look for.",
		veteran = true,
		doneWhen = { mark = "advisor" },
		waypoint = { kind = "npc", id = "npc_advisor" },
	},
	{
		id = "club",
		phase = "campus",
		title = "Join the Finance Club",
		objective = "Find Priya Shah in Halvorsen Hall and join the Finance Club.",
		hint = "The club runs the stock pitches and the alumni nights. Banks recruit from it.",
		veteran = true,
		doneWhen = { any = { { club = true }, { mark = "club" } } :: { any } },
		waypoint = { kind = "npc", id = "npc_club_president" },
	},
	{
		id = "academics",
		phase = "campus",
		title = "Hand in a problem set",
		objective = "Finish your corporate finance problem set on the Work board.",
		hint = "Open the Work board (menu or a campus desk). Recruiters look at your grades.",
		veteran = true,
		doneWhen = { taskDone = "academics_problem_set" },
		enter = { offerTask = "academics_problem_set" },
		waypoint = { kind = "interact", id = "work_desk", zone = "lecture" },
	},
	{
		id = "pitch",
		phase = "campus",
		title = "Pitch a stock",
		objective = "Pitch a stock to the Finance Club judges (Work board).",
		hint = "Read each chart and its news, make the call, then defend your thesis.",
		veteran = true,
		doneWhen = { taskDone = "mock_stock_pitch" },
		enter = { offerTask = "mock_stock_pitch" },
		waypoint = { kind = "npc", id = "npc_club_president" },
	},
	{
		id = "network",
		phase = "campus",
		title = "Work the room",
		objective = "Network with 3 people: chat with campus regulars or exchange cards with players ({n}/{goal}).",
		hint = "Talk to the alum, the recruiter or the professor, or tap another player and exchange cards.",
		veteran = true,
		doneWhen = { networked = 3 },
		waypoint = { kind = "npcNext", ids = CAMPUS_NPCS },
	},
	{
		id = "mock_interview",
		phase = "campus",
		title = "Mock interview",
		objective = "Do a mock interview on the Work board before the real thing.",
		hint = "Structure your answers: situation, action, result. Keep them specific and honest.",
		veteran = true,
		doneWhen = { taskDone = "mock_interview" },
		enter = { offerTask = "mock_interview" },
		waypoint = { kind = "npc", id = "npc_recruiter" },
	},
	{
		id = "recruiting",
		phase = "campus",
		title = "Recruiting season",
		objective = "Apply to investment banks at the Recruiting Board ({apps}/{max} applications).",
		hint = "Eligible firms interview you, then invite you to a Superday. Sterling & Vance always has a seat.",
		core = true,
		doneWhen = { any = { { hasOffer = true }, { hired = true } } :: { any } },
		waypoint = { kind = "interact", id = "bulletin" },
		milestone = true,
		banner = {
			title = "You got an offer!",
			subtitle = "Open Career, then Offers. Compare them and accept the one you want.",
		},
	},
	{
		id = "offers",
		phase = "campus",
		title = "Accept an offer",
		objective = "You have an offer! Open Career, then Offers, and accept one.",
		hint = "Compare pay, prestige and dress code. Accepting declines the others.",
		core = true,
		doneWhen = { hired = true },
		holdWhile = { any = { { hasOffer = true }, { hired = true } } :: { any } },
		back = "recruiting",
	},
	---------------------------------------------------------------------------------------------- street
	{
		id = "subway",
		phase = "street",
		holdWhile = { hired = true },
		back = "recruiting",
		title = "Ride downtown",
		objective = "Ride the subway from Eastbridge Station to Wall Street.",
		hint = "The station is at the edge of campus. Your offer is your ticket.",
		doneWhen = {
			any = { { zone = "street" }, { inOffice = true }, { onboarded = true }, { reviews = 1 } } :: { any },
		},
		waypoint = { kind = "door", id = "door_campus_subway" },
		skip = { teleport = "street_station_platform" },
		milestone = true,
		banner = {
			title = "Welcome to Wall Street",
			subtitle = "Marble, glass and a lot of people walking fast. Find {company}'s tower on Bank Row.",
		},
	},
	{
		id = "tower",
		phase = "street",
		holdWhile = { hired = true },
		back = "recruiting",
		title = "Find your tower",
		objective = "Find {company}'s tower on Bank Row and go inside.",
		hint = "Bank Row runs off the plaza. Look for your firm's logo over the door.",
		doneWhen = { any = { { inOwnOffice = true }, { onboarded = true }, { reviews = 1 } } :: { any } },
		waypoint = { kind = "tower" },
		skip = { enter = "lobby" },
	},
	{
		id = "receptionist",
		phase = "street",
		holdWhile = { hired = true },
		back = "recruiting",
		title = "Check in",
		objective = "Check in with the receptionist in the {company} lobby.",
		hint = "First days start at the front desk: badge, laptop, a lanyard you will wear for years.",
		doneWhen = { any = { { mark = "receptionist" }, { onOwnFloor = true }, { reviews = 1 } } :: { any } },
		waypoint = { kind = "office", floor = "lobby", anchor = "receptionist" },
	},
	{
		id = "elevator",
		phase = "street",
		holdWhile = { hired = true },
		back = "recruiting",
		title = "Up to the floor",
		objective = "Take the elevator up to the {department} floor.",
		hint = "Use the elevator panel in the lobby and pick your department.",
		doneWhen = { any = { { onOwnFloor = true }, { mark = "elevator" }, { reviews = 1 } } :: { any } },
		waypoint = { kind = "officeInteract", floor = "lobby", id = "elevator_panel" },
		skip = { enter = "track" },
	},
	{
		id = "boss",
		phase = "street",
		holdWhile = { hired = true },
		back = "recruiting",
		title = "Meet your boss",
		objective = "Introduce yourself to {boss}, your managing director.",
		hint = "The boss's office is on your floor. First impressions count.",
		doneWhen = { any = { { mark = "boss" }, { reviews = 1 } } :: { any } },
		waypoint = { kind = "boss" },
		milestone = true,
		banner = {
			title = "First day on the desk",
			subtitle = "{boss} is expecting great things. Your first task is waiting.",
		},
	},
	{
		id = "first_task",
		phase = "street",
		holdWhile = { hired = true },
		back = "recruiting",
		title = "Your first desk task",
		objective = "Sit down at your desk and finish your first task on the Work board.",
		hint = "Core tasks count toward your weekly review and your promotion.",
		doneWhen = { any = { { jobTasks = 1 }, { reviews = 1 } } :: { any } },
		waypoint = { kind = "desk" },
	},
	{
		id = "first_trade",
		phase = "street",
		holdWhile = { hired = true },
		back = "recruiting",
		title = "Your first trade",
		objective = "Open the terminal and make your first trade.",
		hint = "Your book is measured against the ST10 benchmark. Size positions sensibly.",
		doneWhen = { any = { { trades = 1 }, { reviews = 1 } } :: { any } },
		waypoint = { kind = "officeInteract", floor = "track", id = "terminal" },
	},
	{
		id = "review_intro",
		phase = "street",
		holdWhile = { hired = true },
		back = "recruiting",
		title = "How reviews work",
		objective = "Your first weekly review is Friday. Read how it works.",
		hint = "Open the Quests app and tap How reviews work.",
		doneWhen = { any = { { mark = "review_intro" }, { reviews = 1 } } :: { any } },
	},
} :: { StepDef }

Quests.stepById = {} :: { [string]: StepDef }
Quests.stepIndex = {} :: { [string]: number }
for i, s in Quests.steps do
	assert(Quests.stepById[s.id] == nil, "Quests: duplicate step " .. s.id)
	Quests.stepById[s.id] = s
	Quests.stepIndex[s.id] = i
end

-- The review explainer (Tutorial.Info "review_intro").
Quests.reviewIntro = {
	title = "Your weekly review",
	lines = {
		"Every work week is Monday to Friday: 8 active minutes a day. Friday afternoon your boss calls you in.",
		"Your score: 35% investment (your book against the ST10 benchmark), 25% risk management, 25% work quality and 15% reputation with the team and clients.",
		"85+ is a Star. 70 to 84 is On track. 55 to 69 means coaching, 40 to 54 is probation, and below 40 is critical. Two criticals in a row and you are out.",
		"Promotions need the score, the level, your core work, the right outfit level and your school's ceiling. The Career app shows exactly what is missing.",
		"Miss the meeting and the boss phones you ten active minutes later. Nothing waits forever.",
	},
}

---------------------------------------------------------------------------------------------------
-- Side quests
---------------------------------------------------------------------------------------------------
Quests.side = {
	{
		id = "side_quiz_night",
		phase = "campus",
		title = "Quiz night regular",
		desc = "Score 70 or better at Finance Club quiz night.",
		goal = 1,
		on = { kind = "task", taskId = "finance_club_quiz", minQuality = 70 },
		reward = { xp = 60, cash = 150 },
	},
	{
		id = "side_coffee",
		phase = "campus",
		title = "Caffeinated networker",
		desc = "Finish two coffee chats with junior bankers.",
		goal = 2,
		on = { kind = "task", taskId = "coffee_chat" },
		reward = { xp = 80, cash = 200 },
	},
	{
		id = "side_networking_night",
		phase = "campus",
		title = "Name tag pro",
		desc = "Make a good impression at a campus networking night.",
		goal = 1,
		on = { kind = "task", taskId = "networking_chat", minQuality = 60 },
		reward = { xp = 50, cash = 120 },
	},
	{
		id = "side_campus_rounds",
		phase = "campus",
		title = "Know your campus",
		desc = "Talk to the barista, the bus driver, the professor, your roommate and the alum.",
		goal = 5,
		on = { kind = "talk", npcs = { "npc_barista", "npc_bus_driver", "npc_professor", "npc_roommate", "npc_alum" } },
		reward = { xp = 70, cash = 150 },
	},
	{
		id = "side_dress_up",
		phase = "campus",
		title = "Dress for the job you want",
		desc = "Reach Outfit Level 2 in the Wardrobe.",
		goal = 1,
		on = { kind = "outfit", level = 2 },
		reward = { xp = 40 },
	},
	{
		id = "side_headlines",
		phase = "street",
		title = "Read the tape",
		desc = "Get today's headline from the newsstand on the Street.",
		goal = 1,
		on = { kind = "talk", npcs = { "npc_newsie" } },
		reward = { xp = 40, cash = 100 },
	},
	{
		id = "side_galleria",
		phase = "street",
		title = "Window shopping",
		desc = "Meet the Galleria's four shopkeepers.",
		goal = 4,
		on = { kind = "talk", npcs = { "npc_tailor", "npc_watchmaker", "npc_shoe_clerk", "npc_decorator" } },
		reward = { xp = 80, cash = 250 },
	},
	{
		id = "side_green_screen",
		phase = "street",
		title = "Green on the screen",
		desc = "Close three profitable trades.",
		goal = 3,
		on = { kind = "trade", profitable = true },
		reward = { xp = 120, cash = 500 },
	},
	{
		id = "side_first_deal",
		phase = "street",
		title = "Tombstone",
		desc = "Close your first deal and earn a lucite deal plaque.",
		goal = 1,
		on = { kind = "deal" },
		reward = { xp = 200, cash = 1500 },
	},
	{
		id = "side_star",
		phase = "street",
		title = "Gold star",
		desc = "Earn a Star weekly review.",
		goal = 1,
		on = { kind = "review", band = "star" },
		reward = { xp = 250, cash = 2000 },
	},
} :: { SideDef }

Quests.sideById = {} :: { [string]: SideDef }
for _, q in Quests.side do
	assert(Quests.sideById[q.id] == nil, "Quests: duplicate side quest " .. q.id)
	Quests.sideById[q.id] = q
end

---------------------------------------------------------------------------------------------------
-- Recruiting Board (spec v2 §4b): apply to up to 5 firms; first round -> Superday -> offer roll
---------------------------------------------------------------------------------------------------
Quests.recruiting = {
	track = "ib",
	maxApplications = 5, -- walk-on firms (Sterling & Vance) are always open and don't use a slot
	firstRoundWeight = 0.4, -- the offer roll uses 40% first round + 60% Superday
	superdayWeight = 0.6,
	cutMargin = 20, -- a first round more than this far under the firm's bar ends the process...
	cutFloor = 35, -- ...but anything at or above this always reaches the Superday
	previewQualities = { 50, 70, 90 }, -- the odds table shown before you apply
	interviewTask = "interview_ib",
	superdayTask = "superday_interview",
	interviewTtl = 6 * 3600, -- how long an offered interview stays on the Work board
}

---------------------------------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------------------------------
Quests.strings = Strings

function Quests.fill(text: string, vars: { [string]: any }?): string
	if not vars then
		return text
	end
	return (
		string.gsub(text, "{([%w_]+)}", function(k: string): string
			local v = vars[k]
			if v == nil then
				return "{" .. k .. "}"
			end
			return tostring(v)
		end)
	)
end

function Quests.text(key: string, vars: { [string]: any }?): string
	local s = Strings[key]
	if type(s) ~= "string" then
		return key
	end
	return Quests.fill(s, vars)
end

return Quests
