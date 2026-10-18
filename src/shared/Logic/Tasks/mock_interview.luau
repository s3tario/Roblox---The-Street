--!strict
-- mock_interview (owned by `work`; contracts §8): a behavioural ("fit") interview with a hiring panel.
-- Kind "dialogue": four to six classic questions (walk me through your résumé, why banking, a failure, teamwork,
-- a weakness, why this firm, questions for us). Strong answers are structured (situation, action, result), specific
-- and honest; generic, negative or arrogant answers score low with coaching notes. Charisma adds quality points.
-- careerPath's re-entry project also runs this module for its hiring-committee stage (it must stay "dialogue").

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)
local Interview = require(script.Parent._shared.Interview)

local Task = {
	id = "mock_interview",
	title = "Mock Interview",
	desc = "Career Services runs a practice fit interview. Structure your answers and keep them specific.",
	kind = "dialogue",
	student = true,
	unemployed = true,
	category = "interview",
	core = true,
	stats = { "charisma", "knowledge" },
	clientFacing = false,
	timeLimit = 180,
	baseXp = 65,
	basePay = 220,
	cooldown = 300,
}

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local vars = Interview.vars(rng, ctx)
	local count = 3 + tier -- 4 / 5 / 6 questions
	local middle = Common.pickN(rng, Interview.MIDDLE, count - 2)
	local turns: { Bank.Turn } = { Interview.FIT.RESUME }
	for _, t in middle do
		table.insert(turns, t)
	end
	table.insert(turns, Interview.FIT.QUESTIONS)
	local specs, hints = Bank.dialogue(rng, turns, vars, if tier >= 2 then 4 else 3)
	local lines, secret = Build.dialogue(rng, specs)
	secret.summary = {
		great = "The panel is impressed: “Structured, specific and honest. That's what we look for.”",
		bad = "The panel thanks you politely. Practise structured answers with real examples.",
	}
	local interviewer = Universe.person(rng)
	return {
		kind = "dialogue",
		title = Task.title,
		prompt = "Answer each question the way you would in the real thing.",
		speaker = interviewer .. ", Hiring panel",
		lines = lines,
		hints = Common.hints(ctx, hints),
	},
		secret
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
