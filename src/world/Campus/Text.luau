--!strict
-- Every player-facing word painted into Eastbridge (signs, posters, flyers, plaques, screens), exterior and interiors,
-- kept in one table so it can be localized later. Fictional names only.

local Text = {}

Text.town = "EASTBRIDGE"
Text.university = "EASTBRIDGE STATE UNIVERSITY"
Text.founded = "EST. 1911"
Text.motto = "LABOR · LUX · LUCRUM"
Text.streets = { avenue = "EASTBRIDGE AVE", mill = "MILL ST" }

-- Buildings and their doors
Text.halvorsen = "HALVORSEN HALL"
Text.halvorsenSub = "SCHOOL OF BUSINESS & ECONOMICS"
Text.careerCenter = "CAREER CENTER"
Text.careerCenterSub = "EASTBRIDGE STATE · STUDENT CAREER SERVICES"
Text.dorm = "MARLOW HOUSE"
Text.dormSub = "RESIDENCE HALL"
Text.station = "EASTBRIDGE STATION"
Text.stationSub = "ROUTE 9 · DOWNTOWN · WALL ST"
Text.stationGlobe = "SUBWAY"
Text.depot = "EASTBRIDGE TRANSIT DEPOT"
Text.depotBays = { "BAY 1 · ROUTE 9 · DOWNTOWN LOOP", "BAY 2 · OUT OF SERVICE" }
Text.depotWaiting = "WAITING ROOM · TICKETS"
Text.depotNoIdle = "NO IDLING · BUSES ONLY"
Text.garage = "EASTBRIDGE TRANSIT · GARAGE 2"

-- Shops on the avenue
Text.diner = "NIGHT OWL DINER"
Text.dinerOpen = "OPEN 24 HRS"
Text.dinerMenu = { "PANCAKES  3.99", "EGGS ANY STYLE  4.50", "COFFEE (BOTTOMLESS)  1.25", "PIE OF THE DAY  2.75" }
Text.laundromat = "SPIN CYCLE LAUNDROMAT"
Text.laundromatSub = "WASH · DRY · FOLD · COIN-OP"
Text.pawn = "LUCKY SEVEN PAWN & LOAN"
Text.pawnSub = "WE BUY GOLD · CASH FOR TEXTBOOKS"
Text.grind = "THE GRIND HOUSE"
Text.grindSub = "COFFEE · BAGELS · FREE WIFI"
Text.grindWindow = "ORDER HERE"
Text.grindMenu =
	{ "DRIP  1.50", "LATTE  3.25", "COLD BREW  3.00", "EVERYTHING BAGEL  2.00", "ALL-NIGHTER (4 SHOTS)  4.75" }
Text.vacant = "FOR LEASE"
Text.vacantSub = "RETAIL SPACE AVAILABLE · CALL 555-0142"
Text.coop = "EASTBRIDGE CO-OP"
Text.coopSub = "GROCERY · SNACKS · CAMPUS GEAR"
Text.coopOpen = "OPEN"
Text.coopAisles = { "SNACKS", "INSTANT NOODLES", "CAMPUS GEAR", "SCHOOL SUPPLIES", "COLD DRINKS" }
Text.hardware = "EASTBRIDGE HARDWARE"
Text.hardwareSub = "STORE CLOSING · EVERYTHING MUST GO"
Text.storage = "U-STOR-IT SELF STORAGE"
Text.storageSub = "FIRST MONTH $1"
Text.court = "EASTBRIDGE REC · COURT CLOSES AT DUSK"
Text.parking = "PAY PARKING  $5 ALL DAY"
Text.billboard = { brand = "QUIKLOAN", slogan = "Student loans approved in 5 minutes*   *terms apply" }
Text.lotHoarding = "COMING 2027 · EASTBRIDGE COMMONS · LUXURY LOFTS FROM $2,400/MO"
Text.lotWarnings = { "HARD HAT AREA", "NO TRESPASSING", "POST NO BILLS" }
Text.overlook = "EASTBRIDGE OVERLOOK"
Text.overlookSub = "THE CITY, ONE STOP AWAY"
Text.roadClosed = "ROAD CLOSED · DETOUR"
Text.ghostSigns = {
	{ "HALVORSEN MILLING CO.", "FLOUR · FEED · SINCE 1889" },
	{ "DRINK FIZZ-O", "5¢ AT ANY FOUNTAIN" },
	{ "EASTBRIDGE SAVINGS", "A DOLLAR SAVED IS A DOLLAR EARNED" },
}
Text.graffiti = { "GRIND", "EB 4 LIFE", "NO SLEEP", "BULLS?", "WALL ST OR BUST", "STAY HUNGRY", "RENT IS DUE", "HODL" }

-- Kiosks and boards (the screens themselves are drawn by their owners at runtime)
Text.recruitingBoard = "RECRUITING BOARD"
Text.recruitingBoardSub = "INVESTMENT BANKING · ANALYST CLASS · APPLY NOW"
Text.recruitingPins = {
	"STERLING & VANCE · REGIONAL ANALYST · ALL MAJORS",
	"HARROW WILLIAMS · MIDDLE MARKET · GPA 3.3+",
	"MG FREEMAN · SUMMER ANALYST · SUPERDAY IN OCT",
	"EASTBRIDGE CAPITAL ADVISORS · WALK-INS WELCOME",
	"RESUME DROP · CAREER CENTER · RM 104",
}
Text.wallOfFame = "WALL OF FAME"
Text.wallOfFameSub = "CAREER PRESTIGE · TOP ALUMNI"
Text.storeKiosk = "EASTBRIDGE MARKETPLACE"
Text.storeKioskSub = "STORE & SEASON PASS"
Text.directory = "COMPANY DIRECTORY"
Text.directorySub = "FIND A FIRM DOWNTOWN"
Text.transitInfo = "TRANSIT INFO"

-- Flyers stapled to poles, hoardings and boards
Text.flyers = {
	"FINANCE CLUB\nSTOCK PITCH NIGHT\nTHU 7PM · HALVORSEN 210",
	"ROOMMATE WANTED\nNO DRUMMERS",
	"LOST CAT\n'SPREADSHEET'\nANSWERS TO 'CTRL'",
	"RECRUITING FAIR\nCAREER CENTER\nBRING 20 RESUMES",
	"CALCULUS TUTOR\n$15/HR",
	"SUPERDAY PREP\nWORKSHOP\nFREE PIZZA",
	"USED TEXTBOOKS\nCHEAP!!",
	"BAND TONIGHT\nTHE BEAR MARKETS\nNIGHT OWL DINER",
	"VOTE KESSLER\nSTUDENT COUNCIL",
	"MOCK INTERVIEWS\nSIGN UP RM 104",
	"FREE COUCH\n(SMELLS FINE)",
	"OPEN MIC\nGRIND HOUSE · FRI",
}
Text.posters = {
	{ title = "FINANCE CLUB", body = "Stock pitch night · Thursday 7 PM · Halvorsen 210" },
	{ title = "RECRUITING FAIR", body = "Twelve firms. One afternoon. Bring your resume." },
	{ title = "DRESS FOR THE JOB YOU WANT", body = "Career Center wardrobe clinic · Wednesdays" },
	{ title = "SUPERDAY PREP", body = "Technicals, behaviorals, free pizza" },
	{ title = "THE BEAR MARKETS", body = "Live at the Night Owl · Saturday" },
	{ title = "NETWORK · PREPARE · APPLY", body = "Eastbridge State Career Services" },
}

---------------------------------------------------------------------------------------------------
-- Interiors
---------------------------------------------------------------------------------------------------
Text.exit = "EXIT"
Text.exitTo = { career_center = "EXIT · TO THE QUAD", lecture = "EXIT · TO THE QUAD", dorm = "EXIT · TO THE QUAD" }

-- Career Center
Text.cc = {
	welcome = "WELCOME TO THE CAREER CENTER",
	lifeRoll = "LIFE ROLL",
	lifeRollSub = "TYPE YOUR NAME · SPIN YOUR LIFE",
	lifeRollTiers = { "COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC" },
	services = "CAREER SERVICES",
	servicesSub = "ADVISING · RESUMES · OFFERS",
	suite = "RECRUITING SUITE",
	suiteSub = "SUPERDAYS IN PROGRESS · PLEASE KNOCK",
	superday = "SUPERDAY SCHEDULE\n9:00  TECHNICALS\n10:30  CASE STUDY\n12:00  LUNCH W/ ANALYSTS\n1:30  FIT INTERVIEW\n3:00  OFFERS?",
	carrels = "STUDY CARRELS · QUIET PLEASE",
	lab = "COMPUTER LAB",
	labSub = "MARKET TERMINALS · STUDENT ACCESS",
	board = "RECRUITING BOARD",
	pizza = "FREE PIZZA FRIDAYS",
	tips = {
		"FIRM HANDSHAKE",
		"KNOW YOUR RESUME",
		"WALK ME THROUGH A DCF",
		"WHY BANKING?",
		"FOLLOW UP IN 24 HRS",
	},
	hours = "OPEN MON–FRI · 9–5 · WALK-INS WELCOME",
	study = "QUIET STUDY",
	firms = "ON CAMPUS THIS FALL",
	firmsSub = "FIRMS RECRUITING EASTBRIDGE STATE STUDENTS",
	nowServing = "NOW SERVING",
	ticket = "A-047",
	takeNumber = "TAKE A\nNUMBER",
	alumni = "WHERE ARE THEY NOW?",
	alumniList = {
		"D. PARK '04 · MANAGING DIRECTOR",
		"S. ALVAREZ '11 · VICE PRESIDENT",
		"M. BROOKS '15 · ASSOCIATE",
		"T. NWOSU '19 · ANALYST",
		"K. LINDQVIST '01 · PARTNER",
		"A. ROSSI '22 · ANALYST",
	},
	brochures = "TAKE ONE",
	-- the firms board falls back to these when Config/Companies is unavailable
	firmsFallback = {
		"STERLING & VANCE",
		"EASTBRIDGE CAPITAL",
		"HARROW WILLIAMS",
		"BLAIRMONT & CO.",
		"HOULTON LOCKEY",
		"MG FREEMAN",
		"GOLDFIELD SAXE",
		"MORROW STANTON",
		"MERRIWEATHER LYNCH",
		"EVERMOOR",
		"LAZARO FRÈRES",
		"CENTERLINE",
	},
}

-- Halvorsen Hall
Text.lecture = {
	foyer = "HALVORSEN HALL",
	foyerSub = "DEDICATED 1911 · REBUILT 1974 · STILL LEAKS",
	hall = "LECTURE HALL 101",
	course = "FIN 301 · CORPORATE FINANCE · PROF. OKAFOR",
	board = "NPV = Σ CFt / (1 + r)^t\nWACC = E/V·Re + D/V·Rd·(1 − T)\nEV = Equity + Debt − Cash\nQUIZ FRIDAY",
	club = "FINANCE CLUB",
	clubSub = "EASTBRIDGE FINANCE CLUB · EST. 1987",
	clubBoard = "PITCH NIGHT\nLONG: VLT (thesis?)\nSHORT: ORN\nVOTE AT 8",
	library = "LIBRARY · QUIET STUDY",
	trophies = "FINANCE CLUB · REGIONAL STOCK PITCH · 3RD PLACE 2019",
	portraits = { "DEAN HALVORSEN · 1911", "DEAN MARLOW · 1958", "DEAN KESSLER · 1990" },
	stacks = { "ACCOUNTING", "ECONOMICS", "FINANCE", "STATISTICS", "BUSINESS LAW", "REFERENCE" },
	joinClub = "JOIN THE FINANCE CLUB",
	joinClubSub = "PITCH NIGHT THURSDAY · ALL MAJORS",
	easel = "STOCK PITCH\nTHURSDAY 7 PM\nROOM 210",
}

-- Marlow House (dorm)
Text.dormInside = {
	lobby = "MARLOW HOUSE",
	lobbySub = "RESIDENCE HALL · RESIDENTS & GUESTS",
	common = "COMMON ROOM",
	mail = "MAIL",
	quiet = "QUIET HOURS 11 PM – 7 AM",
	wingA = "WING A · ROOMS 101–112",
	wingB = "WING B · ROOMS 113–124",
	alarm = "EMERGENCY EXIT ONLY · ALARM WILL SOUND",
	laundry = "LAUNDRY ROOM CLOSED (AGAIN)",
	ra = "RESIDENT ADVISOR",
	tv = "MARKET CLOSE · LIVE",
	room = "ROOM %d",
	panel = "ROOM %d\nCUSTOMIZE",
	vacant = "ROOM %d · VACANT",
	laundryDoor = "LAUNDRY",
}

-- Route 9 subway car
Text.subway = {
	line = "ROUTE 9 · DOWNTOWN EXPRESS",
	map = "EASTBRIDGE ● ─── RIVERSIDE ● ─── CANAL ST ● ─── WALL ST ●",
	hold = "PLEASE HOLD THE RAIL",
	next = "NEXT STOP",
	toStreet = "WALL ST",
	toCampus = "EASTBRIDGE",
	doors = "STAND CLEAR OF THE CLOSING DOORS",
	ads = {
		{ title = "QUIKLOAN", body = "Tuition due? Approved in 5 minutes.* *terms apply" },
		{ title = "GET HIRED", body = "Eastbridge State Career Services · Room 104" },
		{ title = "THE ASHFORD RESIDENCES", body = "Live where you work. Wall Street." },
		{ title = "HARTWELL TAILORS", body = "Your first suit should not be your last." },
	},
	seat = "PRIORITY SEATING",
}

return Text
