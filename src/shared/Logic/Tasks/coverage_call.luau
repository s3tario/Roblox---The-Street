--!strict
-- coverage_call (owned by `work`; contracts §8): the senior banker's Monday coverage list.
-- Kind "match": pair each client's situation with the idea to pitch them (refinance, sale, IPO, buyback,
-- acquisition, spin-off, activism defence, cross-border bond). Harder tiers add more clients and decoy ideas.
-- Client-facing.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "coverage_call",
	title = "Coverage Calls",
	desc = "Your Monday call list: pitch each client the idea that fits their situation.",
	kind = "match",
	tracks = { "ib" },
	ranks = { 3, 4, 5 },
	category = "client",
	core = false,
	stats = { "network", "knowledge" },
	clientFacing = true,
	timeLimit = 180,
	baseXp = 75,
	basePay = 560,
	cooldown = 300,
}

type Idea = { situation: string, idea: string, note: string }

local IDEAS: { Idea } = {
	{
		situation = "{c} has a large loan due next year, and rates just fell.",
		idea = "Refinance the debt early",
		note = "{c}: lower rates and a near maturity make an early refinancing the obvious call.",
	},
	{
		situation = "{c}'s founder wants to retire and there's no successor.",
		idea = "Run a sale process",
		note = "{c}: a retiring founder with no successor is a classic sale mandate.",
	},
	{
		situation = "{c} is private, growing 40% a year and needs capital to expand.",
		idea = "Prepare an IPO",
		note = "{c}: fast growth and a need for capital point to an IPO.",
	},
	{
		situation = "{c} is sitting on lots of cash and its shares trade below peers.",
		idea = "Propose a share buyback",
		note = "{c}: excess cash and a cheap share price make a buyback attractive.",
	},
	{
		situation = "{c}'s biggest rival just announced a merger.",
		idea = "Explore a strategic acquisition",
		note = "{c}: when a rival bulks up, the client needs its own acquisition options.",
	},
	{
		situation = "{c} owns a division that no longer fits its strategy.",
		idea = "Spin off or sell the division",
		note = "{c}: a non-core division is a spin-off or divestiture candidate.",
	},
	{
		situation = "An activist fund just bought 6% of {c} and wants board seats.",
		idea = "Offer activism defence advice",
		note = "{c}: an activist stake calls for defence advice, fast.",
	},
	{
		situation = "{c} is expanding abroad and needs funding in the local currency.",
		idea = "Arrange a cross-border bond",
		note = "{c}: local-currency funding for an overseas expansion means a cross-border bond.",
	},
}

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local n = 3 + tier -- 4 / 5 / 6 clients
	local decoys = tier - 1 -- 0 / 1 / 2 extra ideas
	local picks = Common.pickN(rng, IDEAS, math.min(#IDEAS, n + decoys))
	local used: { [string]: boolean } = {}
	local pairs: { Build.MatchPair } = {}
	for i = 1, n do
		local idea = picks[i]
		local name = Universe.company(rng).name
		local guard = 0
		while used[name] and guard < 10 do
			guard += 1
			name = Universe.company(rng).name
		end
		used[name] = true
		table.insert(pairs, {
			left = Common.fill(idea.situation, { c = name }),
			right = idea.idea,
			note = Common.fill(idea.note, { c = name }),
		})
	end
	local extra: { string } = {}
	for i = n + 1, #picks do
		table.insert(extra, picks[i].idea)
	end
	local left, right, secret = Build.match(rng, pairs, extra)
	secret.summary = {
		great = "Every client gets the right idea. Two of them ask for a follow-up meeting this week.",
		bad = "A few clients got pitches that don't fit. Read their situation first, then the product.",
	}
	return {
		kind = "match",
		title = Task.title,
		prompt = if decoys > 0
			then "Match each client to the idea you'd pitch. Some ideas fit nobody on today's list."
			else "Match each client to the idea you'd pitch.",
		left = left,
		right = right,
		hints = Common.hints(ctx, {
			"Start from the client's problem: debt, succession, growth, cash, competition, focus or a raider.",
			"Rates falling plus a near maturity means refinance; idle cash plus a cheap stock means buyback.",
			"An activist stake needs defence advice before anything else.",
		}),
	},
		secret
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
