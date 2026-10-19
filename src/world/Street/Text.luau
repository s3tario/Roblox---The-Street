--!strict
-- Every player-facing word baked into the Street (signs, plaques, boards, storefronts), kept in one table so it
-- can be localized later. All companies, people, places and products are fictional.
--   Text.get(key, vars?) -> string      "{name}" placeholders are filled from vars; unknown keys return the key

local Text = {}

Text.strings = {
	-- street names
	road_bank_row = "BANK ROW",
	road_exchange_ave = "EXCHANGE AVE",
	road_ledger_st = "LEDGER ST",
	road_charter_st = "CHARTER ST",

	-- the Metropolitan Exchange
	exchange_name = "METROPOLITAN EXCHANGE",
	exchange_monogram = "ME",
	exchange_founded = "MDCCCXCII",
	exchange_plaque_title = "THE METROPOLITAN EXCHANGE",
	exchange_plaque_text = "Where the city has traded since 1892.\nTrading floor: members and staff only.",
	exchange_ticker = "ST10  OPENING BELL  9:30",

	-- plaza
	plaza_name = "EXCHANGE PLAZA",
	plaza_statue_title = "THE CONTEST",
	plaza_statue_text = "Bull meets bear, every day, right here.\nA gift to the Street, 1987.",
	plaza_muster = "ASSEMBLY POINT",
	plaza_muster_sub = "Fire drills muster here",
	plaza_runway = "EXCHANGE PLAZA RUNWAY",
	board_footer = "Verified by the Street Integrity Desk",
	board_footer_supporter = "Supporter board: kept separate from skill rankings",
	board_tap = "Tap to view rankings",

	-- leaderboard monolith titles (BoardId -> title)
	board_CareerPrestige = "CAREER PRESTIGE",
	board_MarketSkill = "MARKET SKILL",
	board_DealMastery = "DEAL MASTERY",
	board_FastestRun = "FASTEST RUN",
	board_Comeback = "COMEBACK",
	board_RobuxSpent = "TOP SUPPORTERS",
	board_TimePlayed = "TIME ON THE STREET",
	board_LiveInvested = "MOST INVESTED (LIVE)",
	board_Rebirths = "MOST REBIRTHS",
	board_TopStats = "HIGHEST OVR",

	-- transit
	subway_station = "EXCHANGE PLAZA STATION",
	subway_title = "METRO",
	subway_line = "^ Line 1: Eastbridge",
	subway_line2 = "Trains every few minutes",
	subway_line3 = "Exit: Exchange Plaza",
	bus_stop = "BUS  M7  EXCHANGE AVE",

	-- kiosks
	newsstand_name = "BENEDETTO'S",
	store_kiosk_title = "THE STREET STORE",
	store_kiosk_sub = "Passes  |  Season Pass  |  Perks",
	directory_title = "COMPANY DIRECTORY",
	directory_sub = "Visit any firm's lobby",
	directory_hint = "Tap to open",
	phone_booth_note = "LOCAL CALLS 25c",

	-- tower directory boards (multi-tenant towers) and addresses
	tenants_title = "TENANTS",
	tenant_floor = "Lobby  >",
	address = "{n} {street}",
	ghost_sign = "VENTURE ROW\nLOFTS & STUDIOS",

	-- venues
	galleria_name = "THE GALLERIA",
	galleria_sub = "TAILORING  |  WATCHES  |  SHOES  |  HOME",
	galleria_shop_tailor = "HARTWELL TAILORS",
	galleria_shop_watch = "VANTA WATCHES & EYEWEAR",
	galleria_shop_shoes = "STRIDER SHOES & LEATHER",
	galleria_shop_decor = "GALLERIA HOME & OFFICE",
	apartments_name = "THE ASHFORD RESIDENCES",
	apartments_number = "One Ashford Place",
	career_services_name = "CAREER SERVICES",
	career_services_sub = "Offers  |  Laterals  |  Re-entry",
	club_name = "THE EXECUTIVE CLUB",
	club_sub = "MEMBERS ONLY",
	club_est = "EST. 1904",
	rooftop_name = "SKYLINE ROOFTOP",
	rooftop_blade = "SKYLINE",
	rooftop_sub = "Express elevator to the 52nd floor",

	-- filler storefronts
	shop_cafe = "TICKER & BEAN",
	shop_deli = "BOND ST DELI",
	shop_pharmacy = "LEDGER PHARMACY",
	shop_bank = "BLUEFIN BANK",
	shop_florist = "PETAL & STEM",
	shop_shine = "SHOE SHINE",
	shop_books = "MARGIN BOOKS",
	shop_wine = "VINTAGE CELLARS",
	shop_watch = "TIMEPIECE REPAIR",
	shop_bistro = "BISTRO 1892",

	-- district edge
	street_closed = "STREET CLOSED  |  DETOUR",

	-- construction
	scaffold_notice = "SIDEWALK SHED\nPermit 22-0419",
	billboard_brand = "LUMEN AIR",
	billboard_slogan = "First class, every class.",
	billboard_brand2 = "NORTHSTAR WATCHES",
	billboard_slogan2 = "Time is the only asset.",
}

function Text.get(key: string, vars: { [string]: any }?): string
	local s = Text.strings[key]
	if s == nil then
		return key
	end
	if vars then
		s = string.gsub(s, "{(%w+)}", function(k: string): string
			local v = vars[k]
			return if v ~= nil then tostring(v) else "{" .. k .. "}"
		end)
	end
	return s
end

return Text
