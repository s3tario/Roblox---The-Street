--!strict
-- Player-facing text baked into the office templates (lobby + department floors). Everything a player can read on
-- a sign, screen or nameplate in these templates comes from here, so it can be localized later. Company names are
-- never baked: parts tagged CompanyLogo and TextLabels named CompanyName are branded at runtime by OfficeService.
-- Bake-safe (pure data).

local Text = {}

Text.strings = {
	-- shared wayfinding
	elevators = "Elevators",
	elevators_lobby = "Elevators  ·  Lobby",
	elevator_indicator = "▼  L",
	company_placeholder = "Company Name",
	firm_tagline = "Est. on the Street",

	-- desks and offices
	desk_nameplate = "Open Desk",
	office_nameplate = "Private Office",
	boss_nameplate = "Managing Director",

	-- rooms
	room_boardroom = "Boardroom",
	room_pantry = "Pantry",
	room_huddle_1 = "Huddle Room 1",
	room_huddle_2 = "Huddle Room 2",
	room_boss = "Executive Suite",
	pantry_menu_title = "TODAY",
	pantry_menu = "Cold brew\nOat flat white\nFruit bowl\nAvocado toast\nTrail mix",

	-- screens and boards
	deal_board_title = "DEAL PIPELINE",
	deal_board_lines = "Project Falcon      IPO        Live\nProject Harbor     M&A        Diligence\nProject Ember      Follow-on  Launch\nProject Summit     Debt       Mandate",
	tv_title = "MARKETS",
	screen_watchlist = "WATCHLIST",
	screen_inbox = "Inbox",
	screen_model = "OPERATING MODEL",
	screen_comps = "TRADING COMPS",
	screen_deck = "PROJECT FALCON",
	screen_deck_sub = "Discussion materials",
	screen_keys = { "EQ", "FX", "NEWS", "MKT" },
	clock_cities = { "NEW YORK", "LONDON", "HONG KONG", "TOKYO" },
	fire_alarm = "FIRE",
	fire_alarm_pull = "PULL DOWN",

	-- placeholder floors (later milestones replace them)
	renovation_title = "Floor under renovation",
	renovation_body = "The %s floor opens soon.\nPardon our dust.",
	renovation_short = "Under renovation",
	renovation_tape = "CAUTION   ·   WORK IN PROGRESS   ·   CAUTION   ·   WORK IN PROGRESS",

	-- lobby
	lobby_reception = "Reception",
	lobby_welcome = "Welcome",
	lobby_security = "Badge in",
	lobby_visitors = "Visitors please check in at reception",
	lobby_exit = "Exit to the Street",
	lobby_directory_title = "FLOOR DIRECTORY",
	lobby_directory = "Lobby ·  Reception\nDepartment floors ·  use the elevator panel",
	lobby_street = "Wall Street",
	lobby_hours = "Open 24 hours",
} :: { [string]: any }

-- Display names of the departments whose floors are still placeholders in this milestone.
Text.departments = {
	ib = "Investment Banking",
	st = "Sales & Trading",
	er = "Equity Research",
	corpbank = "Corporate Banking",
} :: { [string]: string }

function Text.get(key: string): string
	local v = Text.strings[key]
	if type(v) == "string" then
		return v
	end
	return key
end

function Text.list(key: string): { string }
	local v = Text.strings[key]
	if type(v) == "table" then
		return v :: { string }
	end
	return {}
end

function Text.department(id: string): string
	return Text.departments[id] or id
end

return Text
