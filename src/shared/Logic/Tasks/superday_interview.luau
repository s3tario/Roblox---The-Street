--!strict
-- superday_interview (owned by `work`; contracts §8): the final-round Superday, back-to-back interviews in one go.
-- Kind "multi": (1) a technical grilling ("mcq"), (2) a fit interview with a senior banker ("dialogue"), (3) a
-- mental-math round ("fill"). Offer-only: recruiting offers it after a strong first round with
-- WorkService:OfferTask(player, "superday_interview", { data = { companyId, companyName } }).

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)
local Interview = require(script.Parent._shared.Interview)

local Task = {
	id = "superday_interview",
	title = "Superday",
	desc = "The final round: technicals, a senior banker's fit interview and a mental-math round, back to back.",
	kind = "multi",
	student = true,
	offerOnly = true,
	category = "interview",
	core = false,
	stats = { "knowledge", "charisma" },
	clientFacing = false,
	timeLimit = 330,
	baseXp = 120,
	basePay = 0,
	cooldown = 0,
}

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local vars = Interview.vars(rng, ctx)
	local hints: { string } = {}

	-- 1. technicals: always a medium question, more depth with difficulty
	local techSpecs: { any } = {}
	local function add(bank: { Bank.McqEntry }, n: number)
		local s, h = Bank.mcq(rng, bank, n, vars)
		for _, x in s do
			table.insert(techSpecs, x)
		end
		for _, x in h do
			table.insert(hints, x)
		end
	end
	if tier == 1 then
		add(Interview.TECH_EASY, 2)
		add(Interview.TECH_MEDIUM, 1)
	elseif tier == 2 then
		add(Interview.TECH_EASY, 1)
		add(Interview.TECH_MEDIUM, 2)
		add(Interview.TECH_HARD, 1)
	else
		add(Interview.TECH_MEDIUM, 2)
		add(Interview.TECH_HARD, 2)
	end
	local questions, techSecret = Build.mcq(rng, techSpecs)

	-- 2. fit with a senior banker
	local turns: { Bank.Turn } = {}
	for _, t in Common.pickN(rng, Interview.MIDDLE, if tier >= 2 then 3 else 2) do
		table.insert(turns, t)
	end
	table.insert(turns, Interview.FIT.QUESTIONS)
	local talkSpecs, talkHints = Bank.dialogue(rng, turns, vars, 4)
	local lines, talkSecret = Build.dialogue(rng, talkSpecs)
	for _, h in talkHints do
		table.insert(hints, h)
	end

	-- 3. mental math
	local fields: { any } = {}
	local secretFields: { [string]: any } = {}
	local order: { string } = {}
	for _, q in Interview.math(rng, if tier >= 3 then 3 else 2) do
		local field, sf = Build.fillField(q.id, q.label, q.value, {
			unit = q.unit ~= "" and q.unit or nil,
			tol = q.tol,
			scales = q.scales,
			floor = q.floor,
			note = q.note,
			short = q.short,
		})
		table.insert(fields, field)
		secretFields[q.id] = sf
		table.insert(order, q.id)
		table.insert(hints, q.hint)
	end

	local senior = Universe.person(rng)
	return {
		kind = "multi",
		title = Common.fill("Superday: {firm}", vars),
		prompt = Common.fill("Three rounds at {firm}'s office. Stay sharp to the end.", vars),
		sections = {
			{
				kind = "mcq",
				title = "Technical round",
				prompt = "An associate tests the basics.",
				questions = questions,
			},
			{
				kind = "dialogue",
				title = "Senior banker",
				prompt = "A managing director wants to know who you are.",
				speaker = senior .. ", Managing Director",
				lines = lines,
			},
			{
				kind = "fill",
				title = "Mental math",
				prompt = "No calculator in the interview room. Close answers earn partial credit.",
				fields = fields,
			},
		} :: { any },
		hints = Common.hints(ctx, hints),
	}, {
		kind = "multi",
		sections = { techSecret, talkSecret, { kind = "fill", fields = secretFields, fieldOrder = order } },
		weights = { 0.4, 0.4, 0.2 },
		summary = {
			great = Common.fill("You leave {firm} on a high. The recruiter says to keep your phone close.", vars),
			good = Common.fill("A strong Superday at {firm}. It'll come down to the committee.", vars),
			bad = Common.fill("A tough day at {firm}. Brush up on technicals and your fit stories.", vars),
		},
	}
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
