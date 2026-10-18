--!strict
-- pitchbook_format (owned by `work`; contracts §8): turning the MD's comments on a pitchbook page before it goes out.
-- Kind "format": six to eight lines of a page (cover, date, financial headline, valuation range, peers, precedents,
-- footer, contacts, share price). Three to five of them hide a real pitchbook error: a misspelt client or firm
-- name, a stale date, mixed units, a range that doesn't tie to the multiples, a missing source, off-template
-- formatting, or another client's confidential information. Clean lines must be left alone.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "pitchbook_format",
	title = "Pitchbook Page Check",
	desc = "The MD's pitch goes to the client in an hour. Catch every error on the page before it does.",
	kind = "format",
	tracks = { "ib" },
	ranks = { 1, 2 },
	category = "work",
	core = true,
	stats = { "skill", "discipline" },
	clientFacing = false,
	timeLimit = 210,
	baseXp = 60,
	basePay = 420,
	cooldown = 240,
}

local ISSUES: { Build.FormatIssue } = {
	{ id = "typo", text = "Typo or misspelt name" },
	{ id = "date", text = "Out-of-date or wrong date" },
	{ id = "units", text = "Wrong or mixed units" },
	{ id = "numbers", text = "Numbers don't tie out" },
	{ id = "source", text = "Missing source or footnote" },
	{ id = "format", text = "Off-template formatting" },
	{ id = "confidential", text = "Another client's confidential information" },
}

type Variant = { issue: string, text: string, note: string }
type Element = { kind: string, clean: string, broken: { Variant } }

local function elements(rng: Rng.Rng, v: { [string]: any }): { Element }
	local f = function(s: string): string
		return Common.fill(s, v)
	end
	return {
		{
			kind = "Cover",
			clean = f("{codename}: Discussion Materials for {client}"),
			broken = {
				{
					issue = "typo",
					text = f("{codename}: Discussion Materials for ") .. Common.typo(rng, v.client),
					note = f("The client's name is misspelt on the cover. It's the first thing {client}'s CEO reads."),
				},
				{
					issue = "confidential",
					text = f("{codename}: Discussion Materials for {other}"),
					note = f(
						"The cover names {other}, another client. Reusing a page without scrubbing it leaks their deal."
					),
				},
			},
		},
		{
			kind = "Date",
			clean = f("{month} {year} · Preliminary draft"),
			broken = {
				{
					issue = "date",
					text = f("{oldMonth} {oldYear} · Preliminary draft"),
					note = f("The date is from {oldYear}: an old template. Update it to {month} {year}."),
				},
			},
		},
		{
			kind = "Headline",
			clean = f("LTM revenue ${rev}M · EBITDA ${ebitda}M · {margin}% margin"),
			broken = {
				{
					issue = "units",
					text = f("LTM revenue ${rev}M · EBITDA ${ebitdaK}K · {margin}% margin"),
					note = "EBITDA is in thousands while revenue is in millions. Keep one unit across the page.",
				},
				{
					issue = "numbers",
					text = f("LTM revenue ${rev}M · EBITDA ${ebitda}M · {badMargin}% margin"),
					note = f(
						"{ebitda} ÷ {rev} is {margin}%, not {badMargin}%. The margin doesn't tie to the numbers."
					),
				},
			},
		},
		{
			kind = "Valuation",
			clean = f("Implied enterprise value ${lo}–${hi}M ({mLo}x–{mHi}x LTM EBITDA)"),
			broken = {
				{
					issue = "numbers",
					text = f("Implied enterprise value ${badLo}–${badHi}M ({mLo}x–{mHi}x LTM EBITDA)"),
					note = f(
						"{mLo}x–{mHi}x of ${ebitda}M EBITDA is ${lo}–${hi}M. The range doesn't tie to the multiples."
					),
				},
			},
		},
		{
			kind = "Peers chart",
			clean = f("Selected {sector} peers trade at {pLo}x–{pHi}x EV/EBITDA (Source: company filings, FactBase)"),
			broken = {
				{
					issue = "source",
					text = f("Selected {sector} peers trade at {pLo}x–{pHi}x EV/EBITDA"),
					note = "Every chart of market data needs a source line.",
				},
			},
		},
		{
			kind = "Bullet",
			clean = f("Strong recurring revenue base: {recurring}% under multi-year contracts"),
			broken = {
				{
					issue = "format",
					text = f(
						"STRONG RECURRING REVENUE BASE!!! {recurring}% under multi-year contracts (16pt bold, body text is 11pt)"
					),
					note = "One bullet breaks the template: caps, exclamation marks and a bigger font.",
				},
			},
		},
		{
			kind = "Precedents",
			clean = f("Precedent deals: {buyer1} / {target1} ({y1}), {buyer2} / {target2} ({y2})"),
			broken = {
				{
					issue = "confidential",
					text = f(
						"Precedent deals: {buyer1} / {target1} ({y1}), and {other}'s unannounced bid for {target2}"
					),
					note = f(
						"{other}'s bid hasn't been announced. Putting another client's live deal in a pitch is a serious breach."
					),
				},
				{
					issue = "date",
					text = f("Precedent deals: {buyer1} / {target1} ({y1}), {buyer2} / {target2} ({future})"),
					note = f("A precedent can't be dated {future}: that's in the future."),
				},
			},
		},
		{
			kind = "Footer",
			clean = f("Confidential · Prepared by {firm} · Page {page}"),
			broken = {
				{
					issue = "typo",
					text = "Confidential · Prepared by " .. Common.typo(rng, v.firm) .. f(" · Page {page}"),
					note = "Even our own firm's name is misspelt in the footer.",
				},
			},
		},
		{
			kind = "Contacts",
			clean = f("Contacts: {md} (Managing Director), {vp} (Vice President)"),
			broken = {
				{
					issue = "typo",
					text = f("Contacts: {md} (Manging Director), {vp} (Vice President)"),
					note = "“Manging Director”: a typo in the MD's own title.",
				},
			},
		},
		{
			kind = "Share price",
			clean = f("{client} share price ${px} as of {month} {day}, {year}"),
			broken = {
				{
					issue = "date",
					text = f("{client} share price ${px} as of {month} {day}, {oldYear}"),
					note = f("The share price is dated {oldYear}. Refresh it to today's close."),
				},
				{
					issue = "units",
					text = f("{client} share price {px}M as of {month} {day}, {year}"),
					note = "A share price is in dollars per share, not millions.",
				},
			},
		},
	}
end

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local year = Common.year(ctx)
	local sectorId = rng:pick(Universe.sectorIds)
	local sector = Universe.sector(sectorId)
	local client = Universe.company(rng, sectorId).name
	local other = Universe.company(rng, sectorId).name
	if other == client then
		other = Universe.company(rng, if sectorId == "tech" then "energy" else "tech").name
	end
	local peers = Universe.peers(rng, sectorId, 4, { client, other })
	local rev = rng:int(30, 300) * 10
	local margin = rng:int(math.floor(sector.margin[1] * 100), math.floor(sector.margin[2] * 100))
	local ebitda = math.floor(rev * margin / 100 + 0.5)
	local mLo = rng:int(math.floor(sector.evEbitda[1]), math.floor(sector.evEbitda[2]) - 2)
	local mHi = mLo + rng:int(2, 3)
	local oldMonth = Universe.month(rng)
	local badMargin = margin + rng:pick({ -6, -4, 4, 6, 9 })
	local vars: { [string]: any } = {
		codename = Universe.codename(rng),
		client = client,
		other = other,
		firm = if ctx.companyName then ctx.companyName else Universe.firm(rng),
		month = Universe.month(rng),
		oldMonth = oldMonth,
		year = year,
		oldYear = year - rng:int(2, 4),
		future = year + rng:int(1, 2),
		day = rng:int(2, 27),
		rev = Common.commas(rev),
		ebitda = Common.commas(ebitda),
		ebitdaK = Common.commas(ebitda * 1000),
		margin = margin,
		badMargin = math.max(1, badMargin),
		lo = Common.commas(ebitda * mLo),
		hi = Common.commas(ebitda * mHi),
		badLo = Common.commas(math.floor(ebitda * mLo * 1.25 / 10 + 0.5) * 10),
		badHi = Common.commas(math.floor(ebitda * mHi * 1.25 / 10 + 0.5) * 10),
		mLo = string.format("%.1f", mLo),
		mHi = string.format("%.1f", mHi),
		pLo = string.format("%.1f", sector.evEbitda[1]),
		pHi = string.format("%.1f", sector.evEbitda[2]),
		sector = string.lower(sector.name),
		recurring = rng:int(55, 85),
		buyer1 = peers[1],
		target1 = peers[2],
		buyer2 = peers[3],
		target2 = peers[4],
		y1 = year - rng:int(1, 3),
		y2 = year - rng:int(1, 2),
		md = Universe.person(rng),
		vp = Universe.person(rng),
		page = rng:int(3, 14),
		px = string.format("%.2f", rng:range(12, 140)),
	}
	local lib = elements(rng, vars)
	local count = 5 + tier -- 6 / 7 / 8 lines
	local errors = 2 + tier -- 3 / 4 / 5 errors
	-- keep page order: choose which library lines appear, then which of them are broken
	local indices: { number } = {}
	for i = 1, #lib do
		indices[i] = i
	end
	local chosen = Common.pickN(rng, indices, count)
	table.sort(chosen)
	local brokenSet: { [number]: boolean } = {}
	for _, i in Common.pickN(rng, chosen, errors) do
		brokenSet[i] = true
	end
	local specs: { Build.FormatElement } = {}
	local hintLines: { string } = {}
	local hintFor: { [string]: string } = {
		typo = "Read every name letter by letter: client, firm and titles.",
		date = "Check every date against today and against common sense.",
		units = "Make sure every number on the page uses the same units.",
		numbers = "Multiply it out: margins and ranges must tie to the numbers beside them.",
		source = "Every chart of market data needs a source line.",
		format = "Bullets follow the template: same font, size and case.",
		confidential = "Any other client's name or unannounced deal is a confidentiality breach.",
	}
	local seenHint: { [string]: boolean } = {}
	for _, i in chosen do
		local e = lib[i]
		if brokenSet[i] then
			local variant = rng:pick(e.broken)
			table.insert(specs, { text = variant.text, kind = e.kind, issues = { variant.issue }, note = variant.note })
			if not seenHint[variant.issue] then
				seenHint[variant.issue] = true
				table.insert(hintLines, hintFor[variant.issue])
			end
		else
			table.insert(specs, { text = e.clean, kind = e.kind, issues = {} })
		end
	end
	local shownIssues = rng:shuffle(ISSUES)
	local els, issues, secret = Build.format(rng, specs, shownIssues)
	secret.summary = {
		great = "Clean page. The MD sends it to the client without a single comment.",
		bad = "The MD's reply is a wall of red. Errors on a client page cost the bank credibility.",
	}
	return {
		kind = "format",
		title = Task.title,
		prompt = Common.fill("{codename} for {client}: flag every error on this page. Leave clean lines alone.", vars),
		elements = els,
		issues = issues,
		hints = Common.hints(ctx, rng:shuffle(hintLines)),
	},
		secret
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
