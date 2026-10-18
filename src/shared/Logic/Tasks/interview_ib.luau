--!strict
-- interview_ib (owned by `work`; contracts §8): a first-round investment banking interview at a firm you applied to.
-- Kind "multi": (1) fit questions as "dialogue", (2) IB technicals as "mcq". Offer-only: recruiting (the tutorial's
-- Recruiting Board, later M3 applications) puts it on the board with WorkService:OfferTask(player, "interview_ib",
-- { data = { companyId, companyName } }), and reads the quality from WorkService.TaskCompleted.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)
local Interview = require(script.Parent._shared.Interview)

local Task = {
	id = "interview_ib",
	title = "First-Round Interview",
	desc = "A first-round interview for an investment banking analyst seat: fit questions, then technicals.",
	kind = "multi",
	student = true,
	offerOnly = true,
	category = "interview",
	core = false,
	stats = { "charisma", "knowledge" },
	clientFacing = false,
	timeLimit = 240,
	baseXp = 80,
	basePay = 0,
	cooldown = 0,
}

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local vars = Interview.vars(rng, ctx)

	local turns: { Bank.Turn } = { Interview.FIT.RESUME, Interview.FIT.WHY_FIRM }
	local others = { Interview.FIT.WHY_BANKING, Interview.FIT.TEAM, Interview.FIT.FAILURE, Interview.FIT.CURVEBALL }
	for _, t in Common.pickN(rng, others, if tier >= 3 then 2 else 1) do
		table.insert(turns, t)
	end
	local talkSpecs, talkHints = Bank.dialogue(rng, turns, vars, if tier >= 2 then 4 else 3)
	local lines, talkSecret = Build.dialogue(rng, talkSpecs)

	-- technicals from distinct banks, so no question repeats: 3 easy / 2 easy + 1 medium / easy + medium + hard
	local techSpecs: { any } = {}
	local techHints: { string } = {}
	local plan: { { bank: { Bank.McqEntry }, n: number } } = if tier == 1
		then { { bank = Interview.TECH_EASY, n = 3 } }
		elseif tier == 2 then { { bank = Interview.TECH_EASY, n = 2 }, { bank = Interview.TECH_MEDIUM, n = 1 } }
		else {
			{ bank = Interview.TECH_EASY, n = 1 },
			{ bank = Interview.TECH_MEDIUM, n = 1 },
			{ bank = Interview.TECH_HARD, n = 1 },
		}
	for _, step in plan do
		local s, h = Bank.mcq(rng, step.bank, step.n, vars)
		for _, x in s do
			table.insert(techSpecs, x)
		end
		for _, x in h do
			table.insert(techHints, x)
		end
	end
	local questions, techSecret = Build.mcq(rng, techSpecs)

	local hints: { string } = {}
	for i = 1, math.max(#talkHints, #techHints) do
		if techHints[i] then
			table.insert(hints, techHints[i])
		end
		if talkHints[i] then
			table.insert(hints, talkHints[i])
		end
	end
	local interviewer = Universe.person(rng)
	return {
		kind = "multi",
		title = Common.fill("First round: {firm}", vars),
		prompt = Common.fill("{who} from {firm} has thirty minutes with you.", { who = interviewer, firm = vars.firm }),
		sections = {
			{
				kind = "dialogue",
				title = "Fit",
				prompt = "Tell them who you are.",
				speaker = interviewer .. ", " .. vars.firm,
				lines = lines,
			},
			{ kind = "mcq", title = "Technicals", prompt = "Now the technical questions.", questions = questions },
		} :: { any },
		hints = Common.hints(ctx, hints),
	}, {
		kind = "multi",
		sections = { talkSecret, techSecret },
		weights = { 0.55, 0.45 },
		summary = {
			great = Common.fill("{firm}'s interviewer smiles: “We'll be in touch about a Superday.”", vars),
			good = Common.fill("A solid first round at {firm}. You gave them reasons to move you forward.", vars),
			bad = Common.fill(
				"The {firm} interviewer checks the clock early. Practise your story and the basics.",
				vars
			),
		},
	}
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
