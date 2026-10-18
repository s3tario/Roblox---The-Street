--!strict
-- reentry_case_study (owned by `work`; contracts §8): the re-entry case after a firing, and practice between jobs.
-- Kind "mcq" (careerPath's re-entry project renders only mcq and dialogue stages): a short acquisition case with
-- fresh numbers (implied EV from a multiple, the bridge to equity value, the premium a buyer can afford) plus
-- judgement on synergies, risks, funding and risk limits.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "reentry_case_study",
	title = "Re-entry Case Study",
	desc = "Show the hiring committee you can still think like a banker: a short acquisition case.",
	kind = "mcq",
	unemployed = true,
	category = "reentry",
	core = false,
	stats = { "knowledge", "discipline" },
	clientFacing = false,
	timeLimit = 240,
	baseXp = 60,
	basePay = 200,
	cooldown = 240,
}

local JUDGEMENT: { Bank.McqEntry } = {
	{
		text = "{buyer} expects synergies. Which are most credible?",
		correct = "Cost savings from combining the two back offices",
		wrong = {
			"“Cross-selling everything to everyone”",
			"Raising prices 30% on day one",
			"Synergies are always guaranteed",
		},
		explain = "Cost synergies are within the buyer's control; revenue synergies are much harder to deliver.",
		hint = "Cost synergies are more reliable than revenue synergies.",
	},
	{
		text = "What's the biggest risk to flag about {target}?",
		correct = "Its top customer is {conc}% of revenue",
		wrong = { "Its logo is out of date", "Its office is in another city", "It has a fiscal year ending in June" },
		explain = "Heavy customer concentration means one lost contract can sink the earnings you're paying for.",
		hint = "Concentration risk: one customer being a big share of revenue.",
	},
	{
		text = "How much premium above the peer multiple can {buyer} justify?",
		correct = "Only up to the value of the synergies it can actually deliver",
		wrong = { "Whatever it takes to win", "None: never pay a premium", "Exactly 50% in every deal" },
		explain = "A premium above standalone value is only worth paying if synergies cover it.",
	},
	{
		text = "Funding the deal with debt instead of shares usually…",
		correct = "Raises EPS but adds financial risk if earnings fall",
		wrong = { "Has no effect on risk", "Always lowers EPS", "Removes the need for due diligence" },
		explain = "Debt is cheaper than equity, so EPS often rises, but leverage magnifies a downturn.",
	},
	{
		text = "Your trading book breaches a risk limit. The first thing you do is…",
		correct = "Cut back inside the limit and tell the risk team",
		wrong = { "Wait for the position to recover", "Add to it to average down", "Hide it until the review" },
		explain = "Limits are hard lines. Get back inside and be transparent; that's what reviewers check.",
		hint = "Risk limits: get back inside first, explain second.",
	},
}

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local sectorId = rng:pick(Universe.sectorIds)
	local sector = Universe.sector(sectorId)
	local buyer = Universe.company(rng, sectorId).name
	local target = Universe.company(rng, sectorId).name
	if target == buyer then
		target = Universe.company(rng, if sectorId == "tech" then "energy" else "tech").name
	end
	local ebitda = rng:int(8, 60) * 5
	local mult = rng:int(math.floor(sector.evEbitda[1]), math.floor(sector.evEbitda[2]))
	local ev = ebitda * mult
	local netDebt = math.floor(ev * rng:range(0.1, 0.4) / 5 + 0.5) * 5
	local equity = ev - netDebt
	local money = function(x: number): string
		return "$" .. Common.commas(x) .. "M"
	end
	local vars = { buyer = buyer, target = target, conc = rng:int(30, 55) }
	local specs: { Build.McqSpec } = {
		Bank.mcqOne({
			text = Common.fill(
				"{t} has EBITDA of ${e}M; {sector} peers trade at {m}x. What's the implied enterprise value?",
				{
					t = target,
					e = Common.commas(ebitda),
					sector = string.lower(sector.name),
					m = mult,
				}
			),
			correct = money(ev),
			wrong = { money(ev + netDebt), money(ebitda * (mult + 4)), money(math.floor(ev / 2)) },
			explain = Common.fill("{e} × {m} = {ev}.", { e = Common.commas(ebitda), m = mult, ev = money(ev) }),
		}),
		Bank.mcqOne({
			text = Common.fill("{t} has net debt of ${nd}M. What equity value does {buyer} pay to shareholders?", {
				t = target,
				nd = Common.commas(netDebt),
				buyer = buyer,
			}),
			correct = money(equity),
			wrong = { money(ev + netDebt), money(ev), money(netDebt) },
			explain = Common.fill("Equity value = EV − net debt = {ev} − {nd} = {eq}.", {
				ev = money(ev),
				nd = money(netDebt),
				eq = money(equity),
			}),
		}),
	}
	local judgement, judgeHints = Bank.mcq(rng, JUDGEMENT, 1 + tier, vars) -- 2 / 3 / 4
	for _, s in judgement do
		table.insert(specs, s)
	end
	local questions, secret = Build.mcq(rng, specs)
	secret.summary = {
		great = "The committee nods along: “That's the analyst we remember.”",
		bad = "The committee isn't convinced yet. Rework the valuation bridge and the risks.",
	}
	local hints: { string } = { "Implied EV = multiple × EBITDA; equity value = EV − net debt." }
	for _, h in judgeHints do
		table.insert(hints, h)
	end
	return {
		kind = "mcq",
		title = Task.title,
		prompt = Common.fill(
			"Case: {buyer} is weighing an acquisition of {target}. Walk the committee through it.",
			vars
		),
		questions = questions,
		hints = Common.hints(ctx, hints),
	},
		secret
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
