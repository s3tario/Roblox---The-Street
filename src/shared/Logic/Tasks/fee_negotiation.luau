--!strict
-- fee_negotiation (owned by `work`; contracts §8): agreeing the engagement letter's fees with the client's CFO.
-- Kind "multi": (1) "fill": the success fee (rate × deal value, with a minimum), the net fee due at closing after
-- the retainer credit and (hard) an incentive fee on value above a target; (2) "dialogue": the CFO pushes back on
-- the rate, the retainer and guarantees. Hold value with structure, never cave or overpromise. Client-facing.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Bank = require(script.Parent._shared.Bank)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "fee_negotiation",
	title = "Fee Negotiation",
	desc = "The CFO wants to cut your fee. Price the engagement letter and hold your ground with structure.",
	kind = "multi",
	tracks = { "ib" },
	ranks = { 4, 5 },
	category = "client",
	core = false,
	stats = { "charisma", "risk" },
	clientFacing = true,
	timeLimit = 240,
	baseXp = 90,
	basePay = 650,
	cooldown = 300,
}

local TURNS: { Bank.Turn } = {
	{
		says = {
			"Your fee is too high. {rival} offered {rivalRate}%.",
			"{rival} will do this for {rivalRate}%. Why pay you more?",
		},
		best = {
			{
				text = "Our fee reflects the senior team and the buyers we'll bring. We'd add an incentive above the target price so we only earn more when you do.",
			},
		},
		good = {
			{
				text = "We think our fee is fair for the work.",
				note = "Defend the value, then offer structure instead of a cut.",
			},
		},
		weak = {
			{
				text = "Okay, we'll match {rivalRate}%.",
				note = "Caving at the first push tells the client your price was padding.",
			},
		},
		bad = {
			{ text = "Then go and hire {rival}.", note = "Daring the client to leave rarely ends well." },
			{
				text = "We'll do it for free to win the relationship.",
				note = "Working for free undervalues the bank and the team.",
			},
		},
		hint = "Answer price pressure with value and structure (an incentive fee), not a cut.",
	},
	{
		says = { "We don't want to pay a retainer.", "Can we drop the monthly retainer?" },
		best = {
			{
				text = "We can credit the retainer in full against the success fee, so it only covers us if the deal doesn't happen.",
			},
		},
		good = {
			{
				text = "The retainer covers our early work.",
				note = "True. Offering to credit it makes it painless for the client.",
			},
		},
		weak = {
			{
				text = "Sure, no retainer.",
				note = "A retainer shows commitment from both sides; credit it rather than drop it.",
			},
		},
		bad = { { text = "No retainer, no deal.", note = "Inflexible on a small point puts the mandate at risk." } },
		hint = "Crediting the retainer against the success fee is the standard compromise.",
	},
	{
		says = { "Can you guarantee the deal closes?", "If we sign with you, will you guarantee a buyer?" },
		best = {
			{
				text = "No one can guarantee that. We can guarantee a rigorous, competitive process and senior attention throughout.",
			},
		},
		good = { { text = "We're very confident.", note = "Be explicit that outcomes can't be guaranteed." } },
		weak = { { text = "Probably, yes.", note = "Vague assurances become broken promises." } },
		bad = {
			{
				text = "Yes, we guarantee it closes.",
				note = "Guaranteeing an outcome you don't control is a promise you can't keep.",
			},
		},
		hint = "Never guarantee a deal outcome.",
	},
	{
		says = { "We want the right to fire you anytime with no fee.", "What if we drop the sale halfway?" },
		best = {
			{
				text = "That's fair, with a tail: if you sell to a buyer we introduced within twelve months, the fee still applies.",
			},
		},
		good = { { text = "We'd want some protection for our work.", note = "Name the standard tail provision." } },
		weak = {
			{
				text = "Fine, whatever you prefer.",
				note = "Without a tail, the client could use your buyers and skip the fee.",
			},
		},
		bad = {
			{
				text = "Then we'll keep your data and call the buyers ourselves.",
				note = "Threatening to misuse client information is never acceptable.",
			},
		},
		hint = "A tail clause protects the fee if the client sells to a buyer you introduced.",
	},
}

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local client = Universe.company(rng).name
	local firm = if ctx.companyName then ctx.companyName else Universe.firm(rng)
	local value = rng:int(8, 60) * 50
	local rate = rng:pick({ 1.0, 1.25, 1.5, 1.75, 2.0 })
	local minimum = rng:int(4, 12) * 1
	local retainer = rng:pick({ 0.25, 0.5, 0.75, 1.0 })
	local raw_fee = value * rate / 100
	local success = math.max(raw_fee, minimum)
	local net = success - retainer
	local targetValue = math.floor(value * rng:range(0.75, 0.92) / 50 + 0.5) * 50
	local kicker = rng:pick({ 2, 3, 4 })
	local incentive = math.max(0, value - targetValue) * kicker / 100

	local fields: { any } = {}
	local secretFields: { [string]: any } = {}
	local order: { string } = {}
	local function add(id: string, label: string, v: number, opts: Build.FillOpts)
		local field, sf = Build.fillField(id, label, v, opts)
		table.insert(fields, field)
		secretFields[id] = sf
		table.insert(order, id)
	end
	add("success", "Success fee", success, {
		unit = "$M",
		tol = 0.01,
		short = "Success fee",
		note = if raw_fee >= minimum
			then Common.fill("{r}% × ${v}M = ${f}M (above the ${m}M minimum).", {
				r = rate,
				v = Common.commas(value),
				f = string.format("%.2f", raw_fee),
				m = minimum,
			})
			else Common.fill("{r}% × ${v}M is only ${f}M, so the ${m}M minimum applies.", {
				r = rate,
				v = Common.commas(value),
				f = string.format("%.2f", raw_fee),
				m = minimum,
			}),
	})
	add("net", "Due at closing after the retainer credit", net, {
		unit = "$M",
		tol = 0.01,
		short = "Net fee at closing",
		note = Common.fill("${s}M − ${r}M retainer already paid = ${n}M.", {
			s = string.format("%.2f", success),
			r = string.format("%.2f", retainer),
			n = string.format("%.2f", net),
		}),
	})
	if tier >= 3 then
		add("incentive", "Incentive fee", incentive, {
			unit = "$M",
			tol = 0.015,
			floor = 0.5,
			short = "Incentive fee",
			note = Common.fill("{k}% × (${v}M − ${t}M) = ${i}M.", {
				k = kicker,
				v = Common.commas(value),
				t = Common.commas(targetValue),
				i = string.format("%.2f", incentive),
			}),
		})
	end
	local terms = Common.fill(
		"Deal value ${v}M. Success fee {r}% of deal value, minimum ${m}M. Retainer of ${ret}M paid upfront, credited against the success fee.{inc}",
		{
			v = Common.commas(value),
			r = rate,
			m = minimum,
			ret = string.format("%.2f", retainer),
			inc = if tier >= 3
				then Common.fill(
					" Incentive: {k}% of any value above ${t}M.",
					{ k = kicker, t = Common.commas(targetValue) }
				)
				else "",
		}
	)
	local vars = {
		rival = Universe.firm(rng, firm),
		rivalRate = string.format("%.2g", math.max(0.5, rate - rng:pick({ 0.25, 0.5 }))),
	}
	local turns = Common.pickN(rng, TURNS, 1 + tier) -- 2 / 3 / 4
	local specs, talkHints = Bank.dialogue(rng, turns, vars, if tier >= 2 then 4 else 3)
	local lines, talkSecret = Build.dialogue(rng, specs)
	local hints: { string } = { "Success fee = rate × deal value, but never below the minimum." }
	for _, h in talkHints do
		table.insert(hints, h)
	end
	table.insert(hints, 2, "The retainer is credited: subtract it from the success fee due at closing.")
	local cfo = Universe.person(rng)
	return {
		kind = "multi",
		title = Task.title,
		prompt = Common.fill(
			"{client}'s CFO is reviewing {firm}'s engagement letter.",
			{ client = client, firm = firm }
		),
		sections = {
			{ kind = "fill", title = "Price the letter", prompt = terms, fields = fields },
			{
				kind = "dialogue",
				title = "The negotiation",
				prompt = "The CFO pushes back.",
				speaker = cfo .. ", CFO of " .. client,
				lines = lines,
			},
		} :: { any },
		hints = Common.hints(ctx, hints),
	}, {
		kind = "multi",
		sections = { { kind = "fill", fields = secretFields, fieldOrder = order }, talkSecret },
		weights = { 0.4, 0.6 },
		summary = {
			great = "The CFO signs the letter on your terms, with an incentive that aligns everyone.",
			bad = "You gave away too much, or nearly lost the client. Hold value, offer structure.",
		},
	}
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
