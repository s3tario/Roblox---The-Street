--!strict
-- deadline_triage (owned by `work`; contracts §8): splitting tonight's team hours across competing deliverables.
-- Kind "multi": (1) "alloc" the hours (step 0.5) so the client-critical item gets the most and nice-to-haves the
-- least; full credit inside each target band, partial credit by distance; (2) "mcq" on handling new asks and
-- missed deadlines. Easy tiers label each item's priority; hard tiers make you read the deadlines.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "deadline_triage",
	title = "Deadline Triage",
	desc = "Four things are due and there aren't enough hours. Split the team's time where it matters.",
	kind = "multi",
	tracks = { "ib" },
	ranks = { 2, 3, 4 },
	category = "work",
	core = true,
	stats = { "discipline", "speed" },
	clientFacing = false,
	timeLimit = 210,
	baseXp = 70,
	basePay = 480,
	cooldown = 300,
}

type Item = { text: string, detail: string, label: string, note: string }

local POOLS: { [string]: { Item } } = {
	critical = {
		{
			text = "Pitch book for the 8am meeting with {client}'s CEO",
			detail = "Due 7:00 tomorrow · client meeting",
			label = "Critical",
			note = "The 8am CEO pitch is client-facing and first: it needs the biggest share of hours.",
		},
		{
			text = "Signing checklist for {codename}",
			detail = "Due 6:30 tomorrow · deal signs at 9:00",
			label = "Critical",
			note = "A signing can't slip: the checklist gets the most hours.",
		},
	},
	high = {
		{
			text = "Data-room answers the lead buyer needs",
			detail = "Due noon tomorrow · buyer waiting",
			label = "High",
			note = "The buyer's answers are due at noon: high priority, right after the critical item.",
		},
		{
			text = "Comps refresh the MD asked for",
			detail = "Due 3pm tomorrow · MD request",
			label = "High",
			note = "The MD's comps are due tomorrow afternoon: solid hours, but after the critical item.",
		},
		{
			text = "Lender presentation draft for {client2}",
			detail = "Due 5pm tomorrow · client review",
			label = "High",
			note = "The lender draft goes to the client tomorrow evening: give it a solid block.",
		},
	},
	medium = {
		{
			text = "Pipeline tracker for Monday's staffing meeting",
			detail = "Due Monday · internal",
			label = "Medium",
			note = "Monday's internal tracker can take a small slice tonight.",
		},
		{
			text = "First draft of next week's sector update",
			detail = "Due next Wednesday · internal",
			label = "Medium",
			note = "Next week's sector update needs only a little time tonight.",
		},
	},
	low = {
		{
			text = "Re-formatting an old deck nobody has asked for",
			detail = "No deadline",
			label = "Low",
			note = "Nobody asked for the old deck: it gets little or no time.",
		},
		{
			text = "Optional online training module",
			detail = "Due end of quarter · optional",
			label = "Low",
			note = "The optional module can wait for a quiet week.",
		},
	},
}

local SCENARIOS: { Bank.McqEntry } = {
	{
		text = "At 11pm your VP adds a new request. Best response?",
		correct = "Say what's already on the list and ask which item can slip",
		wrong = { "Say yes and quietly drop the client pitch", "Ignore it until morning", "Say no: you're busy" },
		explain = "Make the trade-off visible so the VP chooses. Never let a critical item slip silently.",
		hint = "When something new lands, make the trade-off explicit.",
	},
	{
		text = "At 2am it's clear the comps won't be done. When do you tell the MD?",
		correct = "Now, with what will be ready and when the rest will land",
		wrong = { "At 3pm when it's due", "Never: just send what you have", "After the client meeting" },
		explain = "Bad news early, with a plan, is always better than a surprise at the deadline.",
		hint = "Flag a missed deadline as early as possible, with a plan.",
	},
	{
		text = "An analyst is stuck on the data-room answers. You…",
		correct = "Spend ten minutes unblocking them, then return to the critical item",
		wrong = { "Take the task over completely", "Tell them to figure it out", "Drop everything and redo their work" },
		explain = "A short unblock keeps two workstreams moving; taking over stalls yours.",
	},
}

local function snap(x: number, step: number, up: boolean): number
	local q = x / step
	return (if up then math.ceil(q - 1e-9) else math.floor(q + 1e-9)) * step
end

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local vars = {
		client = Universe.company(rng).name,
		client2 = Universe.company(rng).name,
		codename = Universe.codename(rng),
	}
	local total = if tier == 1 then 10 elseif tier == 2 then 12 else 14
	local step = 0.5
	local classes: { string } = if tier >= 3
		then { "critical", "high", "high", "medium", "low" }
		else { "critical", "high", "medium", "low" }
	local bands: { [string]: { number } } = if tier >= 3
		then { critical = { 0.3, 0.42 }, high = { 0.15, 0.25 }, medium = { 0.07, 0.15 }, low = { 0, 0.05 } }
		else { critical = { 0.35, 0.5 }, high = { 0.2, 0.32 }, medium = { 0.08, 0.18 }, low = { 0, 0.06 } }
	local usedHigh: { [Item]: boolean } = {}
	local entries: { { item: Item, band: { number } } } = {}
	for _, cls in classes do
		local pool = POOLS[cls]
		local item: Item = rng:pick(pool)
		if cls == "high" then
			local guard = 0
			while usedHigh[item] and guard < 10 do
				guard += 1
				item = rng:pick(pool)
			end
			usedHigh[item] = true
		end
		local b = bands[cls]
		local lo = snap(b[1] * total, step, true)
		local hi = math.max(lo, snap(b[2] * total, step, false))
		table.insert(entries, { item = item, band = { lo, hi } })
	end
	entries = rng:shuffle(entries)
	local items: { Build.AllocItem } = {}
	local targets: { { number } } = {}
	local notes: { string } = {}
	for _, e in entries do
		local detail = Common.fill(e.item.detail, vars)
		if tier == 1 then
			detail = e.item.label .. " · " .. detail
		end
		table.insert(items, { text = Common.fill(e.item.text, vars), detail = detail })
		table.insert(targets, e.band)
		table.insert(
			notes,
			Common.fill(e.item.note, vars)
				.. Common.fill(
					" Aim for {lo}–{hi}h.",
					{ lo = string.format("%g", e.band[1]), hi = string.format("%g", e.band[2]) }
				)
		)
	end
	local part, allocSecret =
		Build.alloc(items, total, step, targets, { minEach = 0, maxEach = total, unit = "h", notes = notes })
	allocSecret.unit = "h"
	local qSpecs, qHints = Bank.mcq(rng, SCENARIOS, if tier >= 2 then 2 else 1, vars)
	local questions, mcqSecret = Build.mcq(rng, qSpecs)
	local hints: { string } = {
		"Client-facing deadlines first, then what the MD needs, then internal work.",
		"Low-value work gets little or no time when hours are short.",
	}
	for _, h in qHints do
		table.insert(hints, h)
	end
	local allocSection: { [string]: any } = {
		kind = "alloc",
		title = "Tonight's hours",
		prompt = Common.fill("Split {n} team-hours across the work. You don't have to use every hour.", { n = total }),
	}
	for k, v in part do
		allocSection[k] = v
	end
	return {
		kind = "multi",
		title = Task.title,
		prompt = "It's 9pm and everything is due. Decide where the team's time goes.",
		sections = {
			allocSection,
			{ kind = "mcq", title = "Curveballs", prompt = "The night gets busier.", questions = questions },
		} :: { any },
		hints = Common.hints(ctx, hints),
	}, {
		kind = "multi",
		sections = { allocSecret, mcqSecret },
		weights = { 0.7, 0.3 },
		summary = {
			great = "Everything critical lands on time. The VP: “Exactly the right calls last night.”",
			bad = "The client pitch was short of hours. Put the client-critical work first.",
		},
	}
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
