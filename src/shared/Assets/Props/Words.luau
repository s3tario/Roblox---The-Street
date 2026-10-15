--!strict
-- Decorative text baked into props and signs (screens, flyers, deal toys, ads). Kept in one table so it
-- can be localized later. Every company, person and product here is fictional.

local Words = {}

Words.tickers = { "APX", "NMB", "MRB", "VLT", "SMT", "TTN", "HBR", "CRL", "ORN", "BLF" }
Words.benchmark = "ST10"

Words.firms = {
	"STERLING & VANCE",
	"IRONCLAD CAPITAL",
	"QUANTUM RIDGE",
	"SEEDLINE VENTURES",
	"KEYSTONE REALTY",
	"NORTHWIND HOLDINGS",
	"METROPOLITAN EXCHANGE",
}

Words.deals = {
	"PROJECT ATLAS\n$2.4B IPO\nSole Bookrunner",
	"HALCYON / RIDGEWAY\n$850M Merger\nFinancial Advisor",
	"PROJECT LANTERN\n$1.1B Term Loan\nLead Arranger",
	"BRIGHTWATER\n$640M Follow-On\nJoint Bookrunner",
	"PROJECT KESTREL\n$3.2B Acquisition\nAdvisor to Buyer",
	"MERIDIAN FOODS\n$420M Notes\nCo-Manager",
	"PROJECT OBSIDIAN\n$5.0B Spin-Off\nLead Advisor",
	"CASCADE ROBOTICS\n$310M Series D\nPlacement Agent",
}

Words.headlines = {
	"ST10 CLOSES AT RECORD HIGH",
	"RATE DECISION DUE THURSDAY",
	"APX BEATS ON REVENUE",
	"VOLATILITY ADVISORY ISSUED",
	"TTN ANNOUNCES BUYBACK",
	"ORN GUIDES HIGHER",
	"MERGER MONDAY: 4 DEALS",
	"BOND YIELDS EDGE LOWER",
}

Words.emails = {
	{ "M. Vance", "RE: Pitchbook v14 - turn comments" },
	{ "Staffing", "You're staffed on Project Atlas" },
	{ "J. Okafor", "Comps need refresh by 7am" },
	{ "HR", "Reminder: review window closes Fri" },
	{ "Deal Team", "Model check - circularity off?" },
	{ "Facilities", "Pizza in the 12th floor kitchen" },
	{ "R. Lindqvist", "Can you hop on a call?" },
}

Words.whiteboard = {
	"Q3 PIPELINE",
	"EV = EBITDA x 8.5",
	"WACC ~ 9%",
	"COMPS -> DCF -> LBO",
	"CLOSE BY 30th!",
	"ACCRETIVE?",
}

Words.chalkboard = {
	"NPV = SUM CF / (1+r)^t",
	"P/E = PRICE / EPS",
	"MIDTERM: THURSDAY",
	"Ch. 7  CAPM",
	"r = rf + B(rm - rf)",
}

Words.flyers = {
	{ "FINANCE CLUB", "Mock trading night\nThurs 7PM - Rm 204" },
	{ "ROOMMATE WANTED", "2BR near campus\n$450/mo, no pets" },
	{ "LOST CAT", "Answers to Biscuit\nPlease call!" },
	{ "TUTORING", "Accounting & Stats\n$15/hr" },
	{ "LIVE MUSIC", "The Overdrafts\nFri @ Cellar Bar" },
	{ "CAREER FAIR", "Bring 20 resumes\nGym - 10AM" },
	{ "BIKE FOR SALE", "Barely used\n$80 OBO" },
	{ "STUDY GROUP", "Corp Fin final\nLibrary 3F" },
	{ "OPEN MIC", "Every Wed\nDiner basement" },
	{ "FREE PIZZA", "Info session\nBusiness Hall" },
}

Words.ads = {
	{ "VANTA WATCHES", "Time is capital." },
	{ "STRIDER SHOES", "Walk the Street." },
	{ "HARTWELL TAILORS", "Dress for the corner office." },
	{ "ORIOLE AIR", "Nonstop to everywhere." },
	{ "BLUEFIN BANK", "Your money, on deck." },
	{ "CORAL COLA", "Ice cold. Always." },
}

Words.vending = { "COOL DRINKS", "SNAX", "FIZZ" }

Words.diner = "EASTBRIDGE DINER"
Words.subway = "SUBWAY"
Words.taxi = "TAXI"
Words.busRoute = "M15  WALL ST"
Words.campusBus = "9  EASTBRIDGE"
Words.newsstand = "NEWS"
Words.phone = "TELEPHONE"
Words.bikeShare = "STREETCYCLE"
Words.mail = "EASTBRIDGE POST"
Words.waste = "EASTBRIDGE WASTE"
Words.laundry = { "OUT OF ORDER", "50c / 30 MIN" }
Words.pizza = "SAL'S PIZZA"
Words.sewer = "METRO WATER"
Words.statue = "THE CONTEST"
Words.statueSub = "Bronze, gift of the Metropolitan Exchange"
Words.foodCart = { hotdog = "HOT DOGS", coffee = "COFFEE", pretzel = "PRETZELS" }
Words.awards = { "ANALYST OF THE YEAR", "DEAL OF THE YEAR", "TOP PERFORMER", "10 YEARS OF SERVICE" }
Words.nameplate = "ANALYST"
Words.scaffold = "POST NO BILLS"
Words.noTrespass = "NO TRESPASSING"
Words.elevator = "LOBBY"
Words.reception = "STERLING & VANCE"

return Words
