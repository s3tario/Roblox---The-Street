--!strict
-- staffing_review (owned by `work`; contracts §8): the senior banker's weekly staffing meeting.
-- Kind "multi": (1) "alloc" the group's bankers across live deals by stage and urgency (signing this week gets the
-- most, a paused deal the least); (2) "mcq" on leading the team (burnout, clashes, errors, feedback).

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "staffing_review",
	title = "Staffing Review",
	desc = "Monday staffing: put the group's bankers where the deals need them, and look after the team.",
	kind = "multi",
	tracks = { "ib" },
	ranks = { 3, 4, 5 },
	category = "work",
	core = true,
	stats = { "discipline", "charisma" },
	clientFacing = false,
	timeLimit = 210,
	baseXp = 85,
	basePay = 620,
	cooldown = 300,
}

type Deal = { text: string, detail: string, band: { number }, note: string }

local LEADERSHIP: { Bank.McqEntry } = {
	{
		text = "An analyst has pulled three all-nighters in a row. You…",
		correct = "Move one of their workstreams to someone with capacity, and tell them why",
		wrong = {
			"Tell them it's part of the job",
			"Give them another deal to show trust",
			"Wait for their annual review",
		},
		explain = "Burnout causes errors and departures. Rebalancing early protects the person and the deal.",
		hint = "Protect the team: rebalance work before burnout causes mistakes.",
	},
	{
		text = "Two deals need your best associate on the same day. You…",
		correct = "Put them on the deal closest to signing and arrange cover for the other",
		wrong = { "Split them 50/50 so both are half-covered", "Let the associate pick", "Delay both deals" },
		explain = "Prioritise by stage and client impact, then make sure the other deal is still covered.",
	},
	{
		text = "A junior's error reached the client. You…",
		correct = "Own it with the client, fix it fast, then coach the junior privately",
		wrong = { "Blame the junior on the client call", "Say nothing and hope", "Take the junior off every deal" },
		explain = "Seniors own the team's output in front of clients; coaching happens in private.",
		hint = "In front of clients, the senior banker owns every mistake.",
	},
	{
		text = "How do you give tough feedback to an associate?",
		correct = "Soon, in private and specific, with what good looks like next time",
		wrong = { "In the team meeting, so everyone learns", "Only at year-end reviews", "Through a vague email" },
		explain = "Timely, private, specific feedback changes behaviour; public criticism just damages trust.",
	},
}

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local total = if tier == 1 then 6 elseif tier == 2 then 8 else 10
	local names: { string } = {}
	for _ = 1, 5 do
		local name = Universe.codename(rng)
		local guard = 0
		while table.find(names, name) and guard < 20 do
			guard += 1
			name = Universe.codename(rng)
		end
		table.insert(names, name)
	end
	local function band(lo: number, hi: number): { number }
		local l = math.floor(lo * total + 0.5)
		local h = math.max(l, math.floor(hi * total + 0.5))
		return { l, h }
	end
	local deals: { Deal } = {
		{
			text = names[1] .. ": signing this week",
			detail = "Client CEO calls daily · documents in final turns",
			band = if tier >= 3 then band(0.3, 0.4) else band(0.3, 0.45),
			note = names[1] .. " signs this week: it needs the most bankers.",
		},
		{
			text = names[2] .. ": second-round bids in ten days",
			detail = "Data room open · buyer questions arriving",
			band = if tier >= 3 then band(0.15, 0.25) else band(0.2, 0.32),
			note = names[2] .. " is in its busiest stretch: solid coverage, after the signing.",
		},
		{
			text = names[3] .. ": pitch for a new mandate on Friday",
			detail = "Pitch book in draft",
			band = band(0.1, 0.22),
			note = names[3] .. " is a pitch: a small team can build the book.",
		},
		{
			text = names[4] .. ": paused",
			detail = "Client delayed the process to next quarter",
			band = band(0, 0.1),
			note = names[4] .. " is paused: at most one banker keeping an eye on it.",
		},
	}
	if tier >= 3 then
		table.insert(deals, {
			text = names[5] .. ": buyer diligence starts next week",
			detail = "Management presentations being scheduled",
			band = band(0.15, 0.25),
			note = names[5] .. " ramps up next week: staff it like the other live deal.",
		})
	end
	deals = rng:shuffle(deals)
	local items: { Build.AllocItem } = {}
	local targets: { { number } } = {}
	local notes: { string } = {}
	for _, d in deals do
		table.insert(items, { text = d.text, detail = d.detail })
		table.insert(targets, d.band)
		table.insert(notes, d.note .. Common.fill(" Aim for {lo}–{hi}.", { lo = d.band[1], hi = d.band[2] }))
	end
	local part, allocSecret = Build.alloc(items, total, 1, targets, { minEach = 0, maxEach = total, notes = notes })
	local qSpecs, qHints = Bank.mcq(rng, LEADERSHIP, if tier >= 2 then 2 else 1)
	local questions, mcqSecret = Build.mcq(rng, qSpecs)
	local hints: { string } = {
		"Staff by stage: signing first, live processes next, pitches light, paused deals minimal.",
	}
	for _, h in qHints do
		table.insert(hints, h)
	end
	local allocSection: { [string]: any } = {
		kind = "alloc",
		title = "Staff the deals",
		prompt = Common.fill("You have {n} bankers this week. Assign them to the deals.", { n = total }),
	}
	for k, v in part do
		allocSection[k] = v
	end
	return {
		kind = "multi",
		title = Task.title,
		prompt = "Monday 8am: the group's staffing meeting.",
		sections = {
			allocSection,
			{ kind = "mcq", title = "Running the team", prompt = "People questions.", questions = questions },
		} :: { any },
		hints = Common.hints(ctx, hints),
	}, {
		kind = "multi",
		sections = { allocSecret, mcqSecret },
		weights = { 0.65, 0.35 },
		summary = {
			great = "Every deal is covered and the team feels looked after. That's leadership.",
			bad = "Deals are under-staffed where it counts. Staff by stage and urgency.",
		},
	}
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
