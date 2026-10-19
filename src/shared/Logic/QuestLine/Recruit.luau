--!strict
-- QuestLine/Recruit (owned by `tutorial`; spec v2 §4b): the campus Recruiting Board pipeline, PURE. Eligibility and
-- odds come from careerPath's Logic/Recruiting; this module only runs the application stages.
--
-- An application (data.campus.applications[i]):
--   { companyId, stage, q1?, q2?, quality?, chance?, at, seed, tries, walkOn, sure?, offerId? }
-- Stages:
--   first_round   applied; the first-round interview (interview_ib) is waiting on the Work board
--   superday      passed the first round; the Superday (superday_interview) is waiting
--   retry         walk-on firms only: the Superday missed the bar, take it again (never a dead end)
--   decision      both rounds done; the exact offer odds are shown and the player asks for the decision
--   offer         an offer was granted (CareerService:GrantOffer)
--   rejected      the firm passed after the Superday          cut   the first round was too far under the bar
--
--   Recruit.find(apps, companyId) -> (App?, index?)       Recruit.slotsUsed(apps) -> n (walk-on seats are free)
--   Recruit.isWalkOn(company, track?) -> boolean           Recruit.walkOnBar(company, track?) -> number?
--   Recruit.canApply(apps, company, ctx) -> (ok, errKey?)
--       ctx = { built, hired, eligible, pendingOffer, max? }   errKey: no_profile employed unknown ineligible
--       applied full has_offer
--   Recruit.apply(apps, company, now, seed, track?) -> App  (re-applying to a walk-on firm reuses its record)
--   Recruit.cutFor(company, track?) -> number               first-round score needed to reach the Superday
--   Recruit.firstRound(app, quality, company, track?) -> stage   "superday" | "cut"
--   Recruit.superday(app, quality, company, track?) -> stage     "decision" | "retry"   (walk-on pass: sure = true)
--   Recruit.retry(app) -> boolean
--   Recruit.quality(app) -> number                          40% first round + 60% Superday
--   Recruit.chance(app, profile, company, mods?, track?) -> (chance, breakdown)   exact odds (1 when sure)
--   Recruit.decide(app, chance, u) -> "offer" | "rejected"  u in [0, 1) from Hash (the caller's seed)
--   Recruit.settle(app, outcome, offerId?)                  records the outcome
--   Recruit.preview(profile, company, mods?, track?) -> { { quality, chance } }   odds before applying
--   Recruit.nextTask(apps) -> (App?, taskId?)               the next interview to put on the Work board
--   Recruit.forTask(apps, taskId, companyId?, pendingId?) -> App?   the application a finished interview belongs to
--   Recruit.objective(apps) -> (textKey, vars)              Config/Quests strings recruit_obj_*
--   Recruit.isOpen(app) -> boolean                          still waiting on the player or the firm

local Quests = require(script.Parent.Parent.Parent.Config.Quests)
local Companies = require(script.Parent.Parent.Parent.Config.Companies)
local Recruiting = require(script.Parent.Parent.Recruiting)

export type App = {
	companyId: string,
	stage: string,
	q1: number?,
	q2: number?,
	quality: number?,
	chance: number?,
	at: number,
	seed: number,
	tries: number,
	walkOn: boolean,
	sure: boolean?,
	offerId: string?,
}
export type ApplyCtx = { built: boolean, hired: boolean, eligible: boolean, pendingOffer: boolean, max: number? }
export type Preview = { quality: number, chance: number }

local Recruit = {}

Recruit.OPEN = { first_round = true, superday = true, retry = true, decision = true } :: { [string]: boolean }
Recruit.CLOSED = { offer = true, rejected = true, cut = true } :: { [string]: boolean }

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

local function trackOf(track: string?): string
	return track or Quests.recruiting.track
end

local function hiring(company: any, track: string?): any
	if type(company) ~= "table" then
		return nil
	end
	return Companies.hiring(company.id, trackOf(track))
end

function Recruit.find(apps: { App }, companyId: string): (App?, number?)
	for i, a in apps do
		if type(a) == "table" and a.companyId == companyId then
			return a, i
		end
	end
	return nil, nil
end

function Recruit.isOpen(app: App?): boolean
	return app ~= nil and Recruit.OPEN[app.stage] == true
end

function Recruit.slotsUsed(apps: { App }): number
	local n = 0
	for _, a in apps do
		if type(a) == "table" and a.walkOn ~= true then
			n += 1
		end
	end
	return n
end

function Recruit.isWalkOn(company: any, track: string?): boolean
	local h = hiring(company, track)
	return h ~= nil and type(h.walkOn) == "table"
end

function Recruit.walkOnBar(company: any, track: string?): number?
	local h = hiring(company, track)
	if h and type(h.walkOn) == "table" then
		return num(h.walkOn.bar, 0)
	end
	return nil
end

function Recruit.canApply(apps: { App }, company: any, ctx: ApplyCtx): (boolean, string?)
	if not ctx.built then
		return false, "no_profile"
	end
	if ctx.hired then
		return false, "employed"
	end
	if type(company) ~= "table" or hiring(company, nil) == nil then
		return false, "unknown"
	end
	if not ctx.eligible then
		return false, "ineligible"
	end
	local walkOn = Recruit.isWalkOn(company, nil)
	local existing = Recruit.find(apps, company.id)
	if existing then
		if ctx.pendingOffer then
			return false, "has_offer"
		end
		-- a walk-on seat never closes: after a declined (or expired) offer you may apply again
		if walkOn and existing.stage == "offer" then
			return true, nil
		end
		return false, "applied"
	end
	if not walkOn and Recruit.slotsUsed(apps) >= (ctx.max or Quests.recruiting.maxApplications) then
		return false, "full"
	end
	return true, nil
end

function Recruit.apply(apps: { App }, company: any, now: number, seed: number, track: string?): App
	local walkOn = Recruit.isWalkOn(company, track)
	local existing = Recruit.find(apps, company.id)
	if existing then
		existing.stage = "first_round"
		existing.q1, existing.q2, existing.quality, existing.chance = nil, nil, nil, nil
		existing.sure, existing.offerId = nil, nil
		existing.at = now
		existing.seed = seed
		existing.tries = 0
		existing.walkOn = walkOn
		return existing
	end
	local app: App = {
		companyId = company.id,
		stage = "first_round",
		at = now,
		seed = seed,
		tries = 0,
		walkOn = walkOn,
	}
	table.insert(apps, app)
	return app
end

function Recruit.cutFor(company: any, track: string?): number
	local h = hiring(company, track)
	local cfg = Quests.recruiting
	local bar = if h then num(h.bar, 60) else 60
	return math.min(cfg.cutFloor, bar - cfg.cutMargin)
end

local function clampQ(q: any): number
	return math.clamp(math.floor(num(q, 0) + 0.5), 0, 100)
end

function Recruit.firstRound(app: App, quality: number, company: any, track: string?): string
	local q = clampQ(quality)
	app.q1 = q
	if app.walkOn or q >= Recruit.cutFor(company, track) then
		app.stage = "superday"
	else
		app.stage = "cut"
	end
	return app.stage
end

function Recruit.quality(app: App): number
	local cfg = Quests.recruiting
	local q1 = num(app.q1, num(app.q2, 0))
	local q2 = num(app.q2, q1)
	return clampQ(q1 * cfg.firstRoundWeight + q2 * cfg.superdayWeight)
end

function Recruit.superday(app: App, quality: number, company: any, track: string?): string
	local q = clampQ(quality)
	app.q2 = q
	app.tries = math.floor(num(app.tries, 0)) + 1
	app.quality = Recruit.quality(app)
	if app.walkOn then
		if Recruiting.walkOn(company, q, trackOf(track)) then
			app.sure = true
			app.stage = "decision"
		else
			app.stage = "retry"
		end
	else
		app.stage = "decision"
	end
	return app.stage
end

function Recruit.retry(app: App): boolean
	if app.stage ~= "retry" then
		return false
	end
	app.stage = "superday"
	return true
end

function Recruit.chance(app: App, profile: any, company: any, mods: Recruiting.Mods?, track: string?): (number, any)
	if app.sure then
		return 1, { walkOn = true }
	end
	local c, breakdown = Recruiting.offerChance(profile, company, Recruit.quality(app), mods, trackOf(track))
	return c, breakdown
end

function Recruit.decide(app: App, chance: number, u: number): string
	if app.sure then
		return "offer"
	end
	return if Recruiting.decide(chance, u) then "offer" else "rejected"
end

function Recruit.settle(app: App, outcome: string, offerId: string?)
	if outcome == "offer" then
		app.stage = "offer"
		app.offerId = offerId
	elseif outcome == "rejected" then
		app.stage = "rejected"
	end
end

function Recruit.preview(profile: any, company: any, mods: Recruiting.Mods?, track: string?): { Preview }
	local out: { Preview } = {}
	for _, q in Quests.recruiting.previewQualities do
		local c = Recruiting.offerChance(profile, company, q, mods, trackOf(track))
		table.insert(out, { quality = q, chance = c })
	end
	return out
end

function Recruit.nextTask(apps: { App }): (App?, string?)
	local cfg = Quests.recruiting
	for _, a in apps do
		if type(a) == "table" and a.stage == "first_round" then
			return a, cfg.interviewTask
		end
	end
	for _, a in apps do
		if type(a) == "table" and a.stage == "superday" then
			return a, cfg.superdayTask
		end
	end
	return nil, nil
end

function Recruit.forTask(apps: { App }, taskId: string, companyId: string?, pendingId: string?): App?
	local cfg = Quests.recruiting
	local stage = if taskId == cfg.interviewTask
		then "first_round"
		elseif taskId == cfg.superdayTask then "superday"
		else nil
	if not stage then
		return nil
	end
	for _, id in { companyId, pendingId } do
		if id then
			local a = Recruit.find(apps, id)
			if a and a.stage == stage then
				return a
			end
		end
	end
	-- no company on the result: the oldest application waiting on this round
	for _, a in apps do
		if type(a) == "table" and a.stage == stage then
			return a
		end
	end
	return nil
end

local function nameOf(companyId: string): string
	local c = Companies.get(companyId)
	return if c then c.name else companyId
end

function Recruit.objective(apps: { App }): (string, { [string]: any })
	local order = { "decision", "retry", "superday", "first_round" }
	local key = {
		decision = "recruit_obj_decision",
		retry = "recruit_obj_retry",
		superday = "recruit_obj_superday",
		first_round = "recruit_obj_interview",
	}
	for _, stage in order do
		for _, a in apps do
			if type(a) == "table" and a.stage == stage then
				return key[stage], { company = nameOf(a.companyId) }
			end
		end
	end
	-- nothing open: either nothing applied yet, or every application has closed
	if #apps > 0 then
		return "recruit_obj_more", {}
	end
	return "recruit_obj_apply", { apps = 0, max = Quests.recruiting.maxApplications }
end

return Recruit
