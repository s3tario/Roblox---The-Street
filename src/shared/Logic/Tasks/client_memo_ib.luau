--!strict
-- client_memo_ib (owned by `work`; contracts §8): the associate's process-update email to the client's CEO.
-- Kind "multi": (1) "format" review of the draft: flag lines that misname the client, leak another client's
-- confidential information, promise outcomes we can't control, slip into a casual tone, don't tie out or end
-- without a clear ask; (2) "mcq" on client etiquette (subject line, recipients, press requests). Client-facing.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "client_memo_ib",
	title = "Client Update Email",
	desc = "Draft the process update to the client's CEO. One careless line can cost the mandate.",
	kind = "multi",
	tracks = { "ib" },
	ranks = { 2, 3 },
	category = "client",
	core = false,
	stats = { "charisma", "discipline" },
	clientFacing = true,
	timeLimit = 240,
	baseXp = 75,
	basePay = 520,
	cooldown = 300,
}

local ISSUES: { Build.FormatIssue } = {
	{ id = "name", text = "Wrong or misspelt name" },
	{ id = "confidential", text = "Shares confidential information" },
	{ id = "overpromise", text = "Promises what we can't control" },
	{ id = "tone", text = "Unprofessional tone" },
	{ id = "numbers", text = "Numbers don't tie out" },
	{ id = "vague", text = "Vague: no clear ask or date" },
}

type Line = { kind: string, clean: string, broken: { { issue: string, text: string, note: string } } }

local function lines(rng: Rng.Rng, v: { [string]: any }): { Line }
	local f = function(s: string): string
		return Common.fill(s, v)
	end
	return {
		{
			kind = "Greeting",
			clean = f("Dear {ceoFirst},"),
			broken = {
				{
					issue = "name",
					text = f("Dear {wrongFirst},"),
					note = f("The CEO is {ceoFirst}, not {wrongFirst}. Get the name right, always."),
				},
				{
					issue = "tone",
					text = f("Yo {ceoFirst}!!"),
					note = "Far too casual for a CEO, however friendly the relationship.",
				},
			},
		},
		{
			kind = "Status",
			clean = f("We received {bids} first-round bids for {codename}, between ${lo}M and ${hi}M."),
			broken = {
				{
					issue = "confidential",
					text = f(
						"We received {bids} bids. Between us, {other} (another client of ours) is quietly exploring a sale too."
					),
					note = f(
						"Never mention another client's plans. {other}'s confidentiality is as sacred as {client}'s."
					),
				},
			},
		},
		{
			kind = "Valuation",
			clean = f("The ${mid}M midpoint is {mult}x your LTM EBITDA of ${ebitda}M."),
			broken = {
				{
					issue = "numbers",
					text = f("The ${mid}M midpoint is {badMult}x your LTM EBITDA of ${ebitda}M."),
					note = f("{mid} ÷ {ebitda} is {mult}x, not {badMult}x. A CEO will check the maths."),
				},
			},
		},
		{
			kind = "Outlook",
			clean = "We expect final bids in about two weeks and will recommend next steps then.",
			broken = {
				{
					issue = "overpromise",
					text = f("We guarantee a final price above ${stretch}M."),
					note = "We can't guarantee what buyers will pay. Set expectations; don't promise outcomes.",
				},
			},
		},
		{
			kind = "Buyers",
			clean = "The buyers' main questions are on customer retention; our answers are ready.",
			broken = {
				{
					issue = "tone",
					text = "lol the buyers are kinda clueless about retention tbh",
					note = "Slang and mocking the buyers have no place in a client email.",
				},
			},
		},
		{
			kind = "Ask",
			clean = "Please confirm by Thursday whether we can share the updated forecast with the two leading bidders.",
			broken = {
				{
					issue = "vague",
					text = "We'll circle back on the forecast stuff at some point.",
					note = "Give the client a clear ask and a date.",
				},
			},
		},
		{
			kind = "Attachment",
			clean = "Attached: bid summary (PDF, marked Confidential).",
			broken = {
				{
					issue = "confidential",
					text = f("Attached: bid summary, plus our internal notes on {other}'s strategy."),
					note = f("Internal notes on {other} must never leave the building."),
				},
			},
		},
		{
			kind = "Sign-off",
			clean = f("Best regards, {you}, {firm}"),
			broken = {
				{ issue = "tone", text = f("Cheers!!! xoxo {you}"), note = "Keep the sign-off professional." },
				{
					issue = "name",
					text = f("Best regards, {you}, ") .. Common.typo(rng, v.firm),
					note = "You misspelt your own firm's name.",
				},
			},
		},
	}
end

local ETIQUETTE: { Bank.McqEntry } = {
	{
		text = "Best subject line for this email?",
		correct = "{codename}: first-round bids and next steps",
		wrong = { "URGENT!!! READ NOW", "{client} sale: buyer names and prices inside", "hey quick update" },
		explain = "Use the codename and a clear topic. Never put names or prices in a subject line.",
		hint = "Subject lines use the codename, never the client's real name or prices.",
	},
	{
		text = "Who should the email go to?",
		correct = "The CEO and the client deal team the CEO approved",
		wrong = {
			"Everyone at {client}, for transparency",
			"The bidders too, so they know where they stand",
			"Your friends at other banks, for a sanity check",
		},
		explain = "A sale process runs on a need-to-know list. Even most of the client's staff aren't on it.",
		hint = "Deal emails go only to the approved working group.",
	},
	{
		text = "{ceoFirst} replies asking you to tell a journalist the bids are “strong”. You…",
		correct = "Explain the confidentiality agreements and advise against any comment",
		wrong = { "Call the journalist with the numbers", "Post it online to create buzz", "Ignore the email" },
		explain = "Leaks can break NDAs, spook buyers and move markets. Advise; don't comply.",
	},
	{
		text = "You spot a mistake in the email right after sending it. What now?",
		correct = "Send a short correction to the same people right away and tell your VP",
		wrong = { "Hope nobody notices", "Recall it and pretend it never happened", "Blame the analyst" },
		explain = "Own errors fast and cleanly. Clients forgive mistakes, not cover-ups.",
	},
}

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local sectorId = rng:pick(Universe.sectorIds)
	local sector = Universe.sector(sectorId)
	local client = Universe.company(rng, sectorId).name
	local other = Universe.company(rng, sectorId).name
	if other == client then
		other = Universe.company(rng, if sectorId == "tech" then "energy" else "tech").name
	end
	local ceoFirst = Universe.first(rng)
	local wrongFirst = Universe.first(rng)
	if wrongFirst == ceoFirst then
		wrongFirst = Common.typo(rng, ceoFirst)
	end
	local ebitda = rng:int(8, 60) * 5
	local mult = rng:int(math.floor(sector.evEbitda[1]), math.floor(sector.evEbitda[2]))
	local mid = ebitda * mult
	local spread = math.floor(mid * 0.12 / 10 + 0.5) * 10
	local vars: { [string]: any } = {
		ceoFirst = ceoFirst,
		wrongFirst = wrongFirst,
		client = client,
		other = other,
		codename = Universe.codename(rng),
		bids = rng:int(3, 7),
		lo = Common.commas(mid - spread),
		hi = Common.commas(mid + spread),
		mid = Common.commas(mid),
		ebitda = Common.commas(ebitda),
		mult = mult,
		badMult = mult + rng:pick({ -3, -2, 2, 3 }),
		stretch = Common.commas(math.floor((mid + spread) * 1.3 / 10 + 0.5) * 10),
		firm = if ctx.companyName then ctx.companyName else Universe.firm(rng),
		you = if ctx.firstName then ctx.firstName else "The deal team",
	}
	local lib = lines(rng, vars)
	local count = 5 + tier -- 6 / 7 / 8 lines (the greeting and the sign-off always appear)
	local middle: { number } = {}
	for i = 2, #lib - 1 do
		table.insert(middle, i)
	end
	local chosen = Common.pickN(rng, middle, math.min(count - 2, #middle))
	table.insert(chosen, 1)
	table.insert(chosen, #lib)
	table.sort(chosen)
	local broken: { [number]: boolean } = {}
	for _, i in Common.pickN(rng, chosen, 1 + tier) do -- 2 / 3 / 4 problems
		broken[i] = true
	end
	local specs: { Build.FormatElement } = {}
	local hintFor: { [string]: string } = {
		name = "Double-check every name: the client's and your own firm's.",
		confidential = "Anything about another client, or internal notes, never goes to a client.",
		overpromise = "Never guarantee what buyers or markets will do.",
		tone = "Write to a CEO the way you'd speak in their boardroom.",
		numbers = "Divide it out: the multiple must match the value and the EBITDA.",
		vague = "Every client email needs a clear ask with a date.",
	}
	local hintLines: { string } = {}
	for _, i in chosen do
		local line = lib[i]
		if broken[i] then
			local b = rng:pick(line.broken)
			table.insert(specs, { text = b.text, kind = line.kind, issues = { b.issue }, note = b.note })
			if not table.find(hintLines, hintFor[b.issue]) then
				table.insert(hintLines, hintFor[b.issue])
			end
		else
			table.insert(specs, { text = line.clean, kind = line.kind, issues = {} })
		end
	end
	local els, issues, formatSecret = Build.format(rng, specs, rng:shuffle(ISSUES))
	local qSpecs, qHints = Bank.mcq(rng, ETIQUETTE, if tier >= 3 then 2 else 1, vars)
	local questions, mcqSecret = Build.mcq(rng, qSpecs)
	for _, h in qHints do
		table.insert(hintLines, h)
	end
	return {
		kind = "multi",
		title = Task.title,
		prompt = Common.fill("Your draft to {ceoFirst}, CEO of {client}, about {codename}.", vars),
		sections = {
			{
				kind = "format",
				title = "Review the draft",
				prompt = "Flag what's wrong on each line. Leave clean lines alone.",
				elements = els,
				issues = issues,
			},
			{ kind = "mcq", title = "Before you hit send", prompt = "Client etiquette.", questions = questions },
		} :: { any },
		hints = Common.hints(ctx, hintLines),
	}, {
		kind = "multi",
		sections = { formatSecret, mcqSecret },
		weights = { 0.7, 0.3 },
		summary = {
			great = Common.fill("{ceoFirst} replies: “Clear and helpful, thank you.” The MD notices.", vars),
			bad = "Your VP stops the email before it goes out. Client emails need zero mistakes.",
		},
	}
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
