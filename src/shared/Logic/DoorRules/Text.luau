--!strict
-- Player-facing text for the offices feature (world doors, teleports, office instances, the Directory and the
-- elevator). Pure data, shared by server and client so it can be localized later.
--   Text.get("visit")                                  --> "Visit"
--   Text.format("opening_soon_named", { name = "Anaeio" })  --> "Anaeio is opening soon."

local Text = {}

Text.en = {
	-- World doors
	door_enter = "Enter",
	door_exit = "Exit",
	door_board = "Board",
	door_locked = "Locked",
	door_locked_default = "This door is locked.",
	locked_rank = "You need a more senior position to go in there.",
	locked_employed = "Land a job on the Street first.",
	locked_flag = "You can't go in there yet.",
	locked_pass = "Members only.",
	ride_next_stop = "Next stop",
	ride_now_boarding = "Now boarding",

	-- Office template doors
	office_exit = "Exit to the Street",
	office_to_lobby = "Back to the lobby",
	office_elevator = "Elevator",

	-- Teleports
	tp_cooldown = "One moment...",
	tp_busy = "You're already on your way.",
	tp_no_character = "Your character isn't ready yet.",
	tp_failed = "Couldn't get you there. Please try again.",
	tp_stairs = "Taking the stairs...",

	-- Offices
	opening_soon = "Opening soon",
	opening_soon_named = "{name} is opening soon.",
	unknown_company = "That firm isn't on the Street yet. Opening soon.",
	no_floor = "{name} doesn't have that floor.",
	floor_opening_soon = "The {department} floor is opening soon.",
	offices_full = "Every office is busy right now. Try again in a minute.",
	not_in_office = "Use the elevator inside a company lobby.",
	elevator_outage = "The elevators are out of service. You take the stairs.",
	employees_only = "Employees only",
	visitor = "Visitor",
	visitor_at = "Visitor · {name}",
	your_firm = "Your firm",
	lobby = "Lobby",
	floor_short_lobby = "L",
	you_are_here = "You are here",
	office_label = "{name}",
	office_floor_label = "{department}",

	-- Directory
	directory_title = "Company Directory",
	directory_subtitle = "Visit any firm on the Street.",
	directory_menu = "Directory",
	picker_subtitle = "Choose a firm in this building.",
	tab_open = "Open now",
	tab_all = "All firms",
	visit = "Visit",
	visiting = "On your way...",
	directory_loading = "Loading the directory...",
	directory_empty = "No firms are listed yet.",
	directory_none_open = "No firms are open yet. Check back soon.",
	directory_error = "Couldn't load the directory.",
	retry = "Retry",
	departments_none = "No departments yet",
	departments_sep = " · ",

	-- Elevator
	elevator_title = "Elevator",
	elevator_choose = "Choose a floor",
	elevator_floor = "Floor {n}",

	-- NPCs
	receptionist_title = "Front Desk",
	boss_title = "{title}, {department}",
	boss_title_default = "Managing Director",

	-- Tiers / company kinds (Config/Companies `tier` or `type`)
	tier_bulge = "Bulge Bracket",
	tier_elite = "Elite Boutique",
	tier_middle = "Middle Market",
	tier_regional = "Regional",
	tier_asset = "Asset Management",
	tier_pe = "Private Equity",
	tier_credit = "Private Credit",
	tier_hedge = "Hedge Fund",
	tier_wealth = "Wealth Management",
	tier_vc = "Venture Capital",
	tier_realestate = "Real Estate",
	tier_corporate = "Corporation",
	tier_bank = "Bank",

	-- Departments (fallback when Config/Tracks has no name)
	dept_ib = "Investment Banking",
	dept_st = "Sales & Trading",
	dept_pe = "Private Equity",
	dept_credit = "Private Credit",
	dept_wm = "Wealth Management",
	dept_am = "Asset Management",
	dept_er = "Equity Research",
	dept_corpbank = "Corporate Banking",
	dept_vc = "Venture Capital",
	dept_re = "Real Estate",
	dept_corp = "Corporate Finance",

	-- Zones (labels shown on arrival)
	zone_campus = "Eastbridge",
	zone_street = "Wall Street",
	zone_offices = "Office",
	zone_career_center = "Eastbridge Career Center",
	zone_lecture = "Halvorsen Hall",
	zone_dorm = "Eastbridge Dorms",
	zone_subway = "Subway",
	zone_career_services = "Career Services",
	zone_exec_club = "The Executive Club",
	zone_rooftop = "Skyline Rooftop",
	zone_apartments = "The Ashford Residences",
	zone_galleria = "The Galleria",
}

-- Tier/type ids in Config/Companies -> Text key (several spellings accepted).
Text.tierKeys = {
	bulge = "tier_bulge",
	bulge_bracket = "tier_bulge",
	bb = "tier_bulge",
	elite = "tier_elite",
	elite_boutique = "tier_elite",
	boutique = "tier_elite",
	middle = "tier_middle",
	middle_market = "tier_middle",
	mm = "tier_middle",
	regional = "tier_regional",
	asset = "tier_asset",
	asset_management = "tier_asset",
	am = "tier_asset",
	pe = "tier_pe",
	private_equity = "tier_pe",
	credit = "tier_credit",
	private_credit = "tier_credit",
	hedge = "tier_hedge",
	hedge_fund = "tier_hedge",
	hf = "tier_hedge",
	wealth = "tier_wealth",
	wealth_management = "tier_wealth",
	wm = "tier_wealth",
	vc = "tier_vc",
	venture = "tier_vc",
	venture_capital = "tier_vc",
	re = "tier_realestate",
	real_estate = "tier_realestate",
	realestate = "tier_realestate",
	corp = "tier_corporate",
	corporate = "tier_corporate",
	corporation = "tier_corporate",
	bank = "tier_bank",
} :: { [string]: string }

-- Fictional fallback names (Config/Companies bossNames wins when present).
Text.bossNames = {
	"Victoria Hale",
	"Martin Kessler",
	"Diane Okoro",
	"Graham Pryce",
	"Eleanor Whitcombe",
	"Julian Ashby",
	"Naomi Castellanos",
	"Theodore Brandt",
	"Priya Raman",
	"Sofia Marchetti",
	"Marcus Delacroix",
	"Helen Ostrander",
}

Text.receptionistNames = {
	"Ava Lindqvist",
	"Leo Marsh",
	"Maya Fontaine",
	"Sam Oduya",
	"Iris Calloway",
	"Noah Brennan",
	"June Takahashi",
	"Felix Navarro",
}

local current: { [string]: string } = Text.en

function Text.get(key: string, fallback: string?): string
	local s = current[key]
	if s ~= nil then
		return s
	end
	local base = Text.en[key]
	if base ~= nil then
		return base
	end
	return fallback or key
end

-- Replaces {name} placeholders with vars[name] (tostring'd). Unknown placeholders are left as they are.
function Text.format(key: string, vars: { [string]: any }?): string
	local s = Text.get(key)
	if vars == nil then
		return s
	end
	return (string.gsub(s, "{([%w_]+)}", function(name: string): string
		local v = vars[name]
		if v == nil then
			return "{" .. name .. "}"
		end
		return tostring(v)
	end))
end

return Text
