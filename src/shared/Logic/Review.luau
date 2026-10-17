--!strict
-- Weekly review scoring (owned by `careerPath`; spec §6, design v3 §6). PURE: no services, no clocks, no Instances.
--
--   Review.evaluate(input) -> Result        { score, band, components = {investment, risk, work, reputation},
--                                             investmentKind, alternative }
--   Review.band(score) -> BandId            "star" (85+) | "on_track" (70-84) | "under" (55-69)
--                                           | "probation" (40-54) | "critical" (< 40)
--   Review.bandOrder(band) -> 1..5          critical 1 .. star 5;  Review.atLeast(band, "on_track")
--   Review.pay(role, company, band, mods?) -> { salary, bonus }
--   Review.prestige(role, company, band) -> number
--   Review.livingCost(role, company, discipline?) -> number
--   Review.dialogue(ctx) -> { string }       the boss's lines for the meeting (deterministic per seed)
--
-- Components and weights: 35% risk-adjusted investment, 25% risk management, 25% work quality, 15% team/client
-- reputation. Investment comes from PortfolioService:GetWindowMetrics over the week's active-time window, so a
-- market crash that hits everyone is judged against the benchmark over the same interval. No trading activity
-- is a neutral 55 (no book at all: 60). Alternative route: work >= 80 with zero recent risk violations lifts a weak
-- investment score to 70.

local Tracks = require(script.Parent.Parent.Config.Tracks)
local Hash = require(script.Parent.Parent.Util.Hash)

export type BandId = "star" | "on_track" | "under" | "probation" | "critical"
export type Metrics = {
	twr: number?,
	benchReturn: number?,
	excess: number?,
	maxDrawdown: number?,
	volatility: number?,
	trades: number?,
	violations: number?,
	active: number?,
}
export type WorkStats = {
	count: number?, -- graded tasks this week
	qualitySum: number?, -- sum of quality (late work counted at 80%)
	core: number?,
	clientCount: number?,
	clientSum: number?,
	best: number?,
}
export type Input = {
	metrics: Metrics?,
	hasBook: boolean,
	work: WorkStats?,
	repWeek: number?, -- reputation gained this week
	meetsDress: boolean?,
	recentViolations: number?, -- risk violations in the last two reviews (alternative route)
}
export type Components = { investment: number, risk: number, work: number, reputation: number }
export type Result = {
	score: number,
	band: BandId,
	components: Components,
	investmentKind: string, -- "traded" | "idle" | "no_book"
	alternative: boolean,
}

local Review = {}

Review.WEIGHTS = { investment = 0.35, risk = 0.25, work = 0.25, reputation = 0.15 }
Review.COMPONENTS = { "investment", "risk", "work", "reputation" }

Review.BANDS = {
	{ id = "star", min = 85, color = "accent" },
	{ id = "on_track", min = 70, color = "good" },
	{ id = "under", min = 55, color = "warn" },
	{ id = "probation", min = 40, color = "bad" },
	{ id = "critical", min = 0, color = "bad" },
}
local ORDER: { [string]: number } = { critical = 1, probation = 2, under = 3, on_track = 4, star = 5 }

Review.NEUTRAL_IDLE = 55
Review.NEUTRAL_NO_BOOK = 60

local function clamp(x: number, lo: number, hi: number): number
	if x ~= x then
		return lo
	end
	return math.max(lo, math.min(hi, x))
end

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function Review.band(score: number): BandId
	for _, b in Review.BANDS do
		if score >= b.min then
			return b.id :: BandId
		end
	end
	return "critical"
end

function Review.bandOrder(band: any): number
	return ORDER[band] or 0
end

function Review.atLeast(band: any, min: string): boolean
	return Review.bandOrder(band) >= Review.bandOrder(min)
end

function Review.bandColor(band: any): string
	for _, b in Review.BANDS do
		if b.id == band then
			return b.color
		end
	end
	return "textDim"
end

---------------------------------------------------------------------------------------------------
-- Components
---------------------------------------------------------------------------------------------------
local function traded(m: Metrics?): boolean
	return m ~= nil and num(m.trades, 0) > 0
end

-- Investment: excess return over the benchmark, penalised for drawdown and volatility.
function Review.investmentScore(metrics: Metrics?, hasBook: boolean): (number, string)
	if not hasBook then
		return Review.NEUTRAL_NO_BOOK, "no_book"
	end
	if not traded(metrics) then
		return Review.NEUTRAL_IDLE, "idle"
	end
	local m = metrics :: Metrics
	local excess = if m.excess ~= nil then num(m.excess, 0) else num(m.twr, 0) - num(m.benchReturn, 0)
	local dd = math.abs(num(m.maxDrawdown, 0))
	local vol = math.abs(num(m.volatility, 0))
	local s = 60 + excess * 600 - math.max(0, dd - 0.03) * 300 - math.max(0, vol - 0.04) * 120
	return clamp(s, 0, 100), "traded"
end

-- Risk management: limit violations and deep drawdowns.
function Review.riskScore(metrics: Metrics?, hasBook: boolean): number
	if not hasBook then
		return 80
	end
	local m = metrics
	local violations = if m then math.max(0, num(m.violations, 0)) else 0
	if not traded(m) then
		return clamp(85 - violations * 20, 0, 100)
	end
	local dd = math.abs(num((m :: Metrics).maxDrawdown, 0))
	return clamp(100 - violations * 20 - math.max(0, dd - 0.08) * 250, 0, 100)
end

-- Work quality: average graded quality, scaled down when very little was done.
function Review.workScore(work: WorkStats?): number
	local w: WorkStats = work or {}
	local count = math.max(0, num(w.count, 0))
	if count <= 0 then
		return 15
	end
	local avg = clamp(num(w.qualitySum, 0) / count, 0, 100)
	local volume = math.min(1, 0.5 + 0.1 * count)
	return clamp(avg * volume, 0, 100)
end

-- Team and client reputation: steady work, reputation earned, client-facing quality and the dress code.
function Review.reputationScore(repWeek: number?, work: WorkStats?, meetsDress: boolean?): number
	local w: WorkStats = work or {}
	local count = math.max(0, num(w.count, 0))
	local s = 45 + math.min(12, count) * 1.5 + clamp(num(repWeek, 0) * 0.5, -20, 25)
	local clientCount = math.max(0, num(w.clientCount, 0))
	if clientCount > 0 then
		s += (num(w.clientSum, 0) / clientCount - 60) * 0.4
	end
	s += if meetsDress then 8 else -6
	return clamp(s, 0, 100)
end

function Review.score(c: Components): number
	local w = Review.WEIGHTS
	local raw = c.investment * w.investment + c.risk * w.risk + c.work * w.work + c.reputation * w.reputation
	return math.floor(clamp(raw, 0, 100) + 0.5)
end

function Review.evaluate(input: Input): Result
	local investment, kind = Review.investmentScore(input.metrics, input.hasBook)
	local risk = Review.riskScore(input.metrics, input.hasBook)
	local work = Review.workScore(input.work)
	local reputation = Review.reputationScore(input.repWeek, input.work, input.meetsDress)
	local alternative = false
	if work >= 80 and num(input.recentViolations, 0) <= 0 and investment < 70 then
		investment = 70
		alternative = true
	end
	local components: Components = {
		investment = math.floor(investment + 0.5),
		risk = math.floor(risk + 0.5),
		work = math.floor(work + 0.5),
		reputation = math.floor(reputation + 0.5),
	}
	local score = Review.score(components)
	return {
		score = score,
		band = Review.band(score),
		components = components,
		investmentKind = kind,
		alternative = alternative,
	}
end

---------------------------------------------------------------------------------------------------
-- Pay, prestige, living cost
---------------------------------------------------------------------------------------------------
type RoleLike = { salary: number, bonus: number, prestige: number }
type CompanyLike = { payMult: number, prestigeMult: number }

-- Bonus multiplier by band (spec §11): Star 1.5x, On track 1x, below that 0.5x. Fired players get no bonus.
function Review.bonusFactor(band: any, fired: boolean?): number
	if fired then
		return 0
	end
	if band == "star" then
		return 1.5
	elseif band == "on_track" then
		return 1
	end
	return 0.5
end

function Review.pay(
	role: RoleLike,
	company: CompanyLike?,
	band: any,
	mods: { bonusMult: number?, fired: boolean? }?
): { salary: number, bonus: number }
	local payMult = if company then company.payMult else 1
	local m = mods or {}
	local bonusMult = num(m.bonusMult, 1)
	local salary = math.floor(role.salary * payMult + 0.5)
	local bonus = math.floor(role.bonus * payMult * Review.bonusFactor(band, m.fired) * bonusMult + 0.5)
	return { salary = math.max(0, salary), bonus = math.max(0, bonus) }
end

local PRESTIGE_FACTOR: { [string]: number } = { star = 1.5, on_track = 1, under = 0.5, probation = 0.25, critical = 0 }

function Review.prestige(role: RoleLike, company: CompanyLike?, band: any): number
	local mult = if company then company.prestigeMult else 1
	return math.floor(role.prestige * mult * (PRESTIGE_FACTOR[band] or 0) + 0.5)
end

-- Weekly living cost: about 2% of a typical week's income, eased by Discipline (1..99 -> x1.15..x0.85).
function Review.livingCost(role: RoleLike, company: CompanyLike?, discipline: number?): number
	local payMult = if company then company.payMult else 1
	local d = clamp(num(discipline, 50), 1, 99)
	local disciplineMult = 1.15 - 0.3 * (d - 1) / 98
	return math.max(0, math.floor((role.salary + role.bonus) * payMult * 0.067 * disciplineMult + 0.5))
end

---------------------------------------------------------------------------------------------------
-- Boss dialogue
---------------------------------------------------------------------------------------------------
export type DialogueCtx = {
	seed: any,
	mode: string?, -- "office" | "phone" | "discipline"
	outcome: string, -- "promoted" | "keep_going" | "warning" | "fired"
	band: string,
	components: Components,
	investmentKind: string?,
	workCount: number?,
	lifeline: boolean?,
	fireReason: string?, -- "critical" | "risk" | "mass"
	blocked: string?, -- first missing promotion requirement id (outfit/school/level/core/ovr)
	vars: { [string]: any },
}

local function fill(template: string, vars: { [string]: any }): string
	return (string.gsub(template, "{([%w_]+)}", function(name: string): string
		local v = vars[name]
		if v == nil then
			return ""
		end
		return tostring(v)
	end))
end

local function pick(pool: any, seed: any, tag: string): string?
	if type(pool) ~= "table" or #pool == 0 then
		return nil
	end
	local i = (Hash.u32(seed, tag) % #pool) + 1
	return pool[i]
end

function Review.dialogue(ctx: DialogueCtx): { string }
	local D: any = Tracks.dialogue
	local lines: { string } = {}
	local function add(text: string?)
		if text then
			table.insert(lines, fill(text, ctx.vars))
		end
	end
	local mode = ctx.mode or "office"
	add(pick(D.opening[mode] or D.opening.office, ctx.seed, "open"))

	-- strongest and weakest components
	local best, bestScore = nil :: string?, -1
	local worst, worstScore = nil :: string?, 101
	for _, id in Review.COMPONENTS do
		local v = (ctx.components :: any)[id] :: number
		if v > bestScore then
			best, bestScore = id, v
		end
		if v < worstScore then
			worst, worstScore = id, v
		end
	end
	if best and bestScore >= 70 then
		add(pick(D.strong[best], ctx.seed, "strong"))
	end
	if worst and worstScore < 60 and worst ~= best then
		local key = worst
		if worst == "investment" and ctx.investmentKind ~= "traded" then
			key = "investment_none"
		elseif worst == "work" and (ctx.workCount or 0) <= 0 then
			key = "work_none"
		end
		add(pick(D.weak[key] or D.weak[worst], ctx.seed, "weak"))
	end

	local O = D.outcome
	if ctx.lifeline then
		add(pick(O.lifeline, ctx.seed, "outcome"))
	elseif ctx.outcome == "fired" then
		local pool = if ctx.fireReason == "risk"
			then O.fired_risk
			elseif ctx.fireReason == "mass" then O.fired_mass
			else O.fired
		add(pick(pool, ctx.seed, "outcome"))
	elseif ctx.outcome == "promoted" then
		add(pick(O.promoted, ctx.seed, "outcome"))
	elseif ctx.band == "star" then
		add(pick(O.star, ctx.seed, "outcome"))
	elseif ctx.band == "on_track" then
		add(pick(O.keep_going, ctx.seed, "outcome"))
	elseif ctx.band == "under" then
		add(pick(O.coaching, ctx.seed, "outcome"))
	elseif ctx.band == "probation" then
		add(pick(O.probation, ctx.seed, "outcome"))
	else
		add(pick(O.critical_warning, ctx.seed, "outcome"))
	end

	if
		ctx.outcome ~= "promoted"
		and ctx.outcome ~= "fired"
		and not ctx.lifeline
		and ctx.blocked
		and Review.atLeast(ctx.band, "on_track")
	then
		add(pick(D.blocked[ctx.blocked], ctx.seed, "blocked"))
	end

	if ctx.outcome == "fired" and not ctx.lifeline then
		add(pick(D.closing_fired, ctx.seed, "close"))
	else
		add(pick(D.closing, ctx.seed, "close"))
	end
	return lines
end

return Review
