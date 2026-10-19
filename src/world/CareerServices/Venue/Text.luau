--!strict
-- Every player-facing word baked into the venue interiors (signs, plaques, menus, labels), kept in one table so it can
-- be localized later. All companies, people, places and products are fictional.
--   Text.get(key, vars?) -> string      "{name}" placeholders are filled from vars; unknown keys return the key

local Text = {}

Text.strings = {
	-- shared
	exit = "EXIT TO THE STREET",
	exit_short = "EXIT",

	-- Career Services
	cs_name = "CAREER SERVICES",
	cs_sub = "Offers  |  Laterals  |  Re-entry",
	cs_motto = "Every career has a second act.",
	cs_welcome = "Welcome. Take a seat, or step up to any open desk.",
	cs_desk = "CONSULTATION {n}",
	cs_desk_sub = "Open: step up to begin",
	cs_waiting = "WAITING AREA",
	cs_now_serving = "NOW SERVING",
	cs_now_serving_no = "A{n}",
	cs_reception = "RECEPTION",
	cs_resources = "RESOURCE LIBRARY",
	cs_board_title = "OPEN ROLES THIS WEEK",
	cs_board_lines = "Analyst  ·  Harrow Williams\nAssociate  ·  Blairmont\nAnalyst  ·  Sterling & Vance\nVP  ·  Houlton Lockey\nAnalyst  ·  Eastbridge Capital",
	cs_guide_1 = "The Re-entry Handbook",
	cs_guide_2 = "Interviews, Second Time Around",
	cs_guide_3 = "Lateral Moves 101",
	cs_poster_title = "RE-ENTRY PROGRAM",
	cs_poster_body = "Three tasks, one interview,\nand you're back on the Street.",
	cs_poster2_title = "LATERAL MOVES",
	cs_poster2_body = "Same seniority, new firm.\nAsk any consultant.",
	cs_kiosk = "STORE",
	cs_privacy = "All conversations are confidential.",

	-- Executive Club
	club_name = "THE EXECUTIVE CLUB",
	club_est = "EST. 1904",
	club_motto = "Fortuna favet audacibus",
	club_bar = "THE LEDGER BAR",
	club_dressing = "MEMBERS' DRESSING ROOM",
	club_billiards = "BILLIARDS",
	club_menu_title = "TONIGHT",
	club_menu = { "Old Fashioned · 18", "Vesper Martini · 21", "Sazerac · 19", "Single Malt, 18 yr · 32", "Club Soda · 4" },
	club_founders = "THE FOUNDERS",
	club_portrait_1 = "A. T. Whitcombe, 1904",
	club_portrait_2 = "E. M. Hartley, 1911",
	club_rules = "House rules: jackets after six. Phones on silent. Deals stay in the room.",
	club_locker = "MEMBER",

	-- Skyline Rooftop
	roof_name = "SKYLINE",
	roof_sub = "ROOFTOP  ·  52ND FLOOR",
	roof_elevator = "EXPRESS ELEVATOR  ·  STREET LEVEL",
	roof_bar = "THE HIGH NOTE",
	roof_menu_title = "MIXER MENU",
	roof_menu = { "Skyline Spritz · 16", "Bull Market Mule · 15", "Closing Bell · 17", "Sparkling Water · 4" },
	roof_mixer = "MIXER LAWN",
	roof_dj = "SKYLINE SOUND",
	roof_compass_n = "UPTOWN",
	roof_compass_s = "THE HARBOR",
	roof_compass_e = "EXCHANGE PLAZA",
	roof_compass_w = "EASTBRIDGE",

	-- The Ashford Residences
	apt_name = "THE ASHFORD",
	apt_sub = "RESIDENCES",
	apt_address = "One Ashford Place",
	apt_concierge = "CONCIERGE",
	apt_mail = "RESIDENT MAIL",
	apt_unit = "Unit {n}",
	apt_floor = "FLOOR {n}",
	apt_floor_units = "Units {a} – {b}",
	apt_directory_title = "RESIDENCES",
	apt_directory_1 = "Floor 1   Units 1 – 8",
	apt_directory_2 = "Floor 2   Units 9 – 16",
	apt_directory_3 = "Floor 3   Units 17 – 24",
	apt_directory_hint = "Stairs straight ahead. Your unit number is on your nameplate.",
	apt_stairs = "STAIRS",
	apt_stairs_up = "STAIRS  ▲  FLOORS 2 – 3",
	apt_panel = "HOME",
	apt_panel_sub = "Customize",
	apt_lounge = "RESIDENTS' LOUNGE",

	-- The Galleria
	gal_name = "THE GALLERIA",
	gal_sub = "TAILORING  ·  WATCHES  ·  SHOES  ·  HOME",
	gal_tailor = "HARTWELL TAILORS",
	gal_tailor_sub = "Bespoke & Ready-to-Wear",
	gal_tailor_fitting = "FITTING ROOM",
	gal_watch = "VANTA WATCHES",
	gal_watch_sub = "Watches & Eyewear",
	gal_shoes = "STRIDER SHOES",
	gal_shoes_sub = "Shoes & Leather",
	gal_decor = "ATELIER MAISON",
	gal_decor_sub = "Galleria Home & Office",
	gal_counter = "Service",
	gal_directory_title = "THE GALLERIA",
	gal_directory = "West  ·  Hartwell Tailors\nWest  ·  Vanta Watches\nEast  ·  Strider Shoes\nEast  ·  Atelier Maison",
	gal_fabric = "SUPER 150s  ·  FRESCO  ·  FLANNEL  ·  CASHMERE",
	gal_vignette_living = "The Park Avenue Living Room",
	gal_vignette_office = "The Corner Office",
	gal_vignette_bedroom = "The Penthouse Suite",
	gal_watch_case = "THE ASTRA COLLECTION",
	gal_hours = "Open daily  ·  Complimentary alterations",
} :: { [string]: any }

function Text.get(key: string, vars: { [string]: any }?): string
	local s = Text.strings[key]
	if type(s) ~= "string" then
		return key
	end
	if vars then
		s = string.gsub(s, "{(%w+)}", function(k: string): string
			local v = vars[k]
			if v == nil then
				return "{" .. k .. "}"
			end
			return tostring(v)
		end)
	end
	return s
end

function Text.list(key: string): { string }
	local s = Text.strings[key]
	if type(s) == "table" then
		return s :: any
	end
	return {}
end

return Text
