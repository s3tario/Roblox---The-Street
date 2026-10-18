--!strict
-- ProjectService/Flow (server, runtime only): everything around a run that needs other features.
--
--   Flow.who(data) -> Who                                  Registry.who(data.career)
--   Flow.context(player, data, who) -> ctx                 the contracts §8 task context plus marketMood:
--       { level, rank, track, student, stats, ovr, difficulty, now, hints, toleranceMult, charismaBonus,
--         companyName?, firstName?, marketMood }
--   Flow.mults(player, who, mod?) -> Mults                 { payMult (company), xpMult (daily boost), eventMult
--                                                            (the module's EventService payModifier, e.g. IPO Frenzy) }
--   Flow.eventMults(mods) -> { [modId] = number }          for the list's estimates
--   Flow.stageStats(player, mod, stageId, score)           stat XP for one graded stage (source "task")
--   Flow.reward(player, mod, completion, who) -> Rewards   applies XP, salary cash, reputation, stat XP, Season XP,
--       the review's work record and (closed deals only) CareerService:RecordDeal -> plaque. Never throws.
--       Rewards = { xp, xpCapped, pay, paid, rep, repeatRun, repeatPct, pulled, plaque, stats = {label} }

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Time = require(Shared.Util.Time)
local Logic = Shared:WaitForChild("Logic")
local Registry = require(Logic:WaitForChild("Projects"):WaitForChild("_registry"))
local TaskRewards = require(Logic:WaitForChild("Tasks"):WaitForChild("_shared"):WaitForChild("Rewards"))
local Deps = require(script.Parent.Deps)

local StatsModule = Deps.require(Logic:FindFirstChild("Stats"))

export type Mults = { payMult: number, xpMult: number, eventMult: number }
export type Rewards = {
	xp: number,
	xpCapped: boolean,
	pay: number,
	paid: boolean,
	rep: number,
	repeatRun: boolean,
	repeatPct: number,
	pulled: boolean,
	plaque: boolean,
	stats: { string },
}

local Flow = {}

local num = Deps.num

function Flow.who(data: { [string]: any }): Registry.Who
	return Registry.who(data.career)
end

local function profileOf(data: { [string]: any }): { [string]: any }
	return if type(data.profile) == "table" then data.profile else {}
end

local function statsOf(player: Player, data: { [string]: any }): { [string]: number }
	local ok, stats = Deps.call("ProfileService", "GetStats", player)
	local source = if ok and type(stats) == "table" then stats else profileOf(data).stats
	local out: { [string]: number } = {}
	if type(source) == "table" then
		for k, v in source do
			if type(k) == "string" and type(v) == "number" and v == v then
				out[k] = v
			end
		end
	end
	return out
end

local function companyOf(player: Player): { [string]: any }?
	local ok, company = Deps.call("CareerService", "GetCompany", player)
	return if ok and type(company) == "table" then company else nil
end

-- How investors feel right now: market events (MarketService), the benchmark's move today (the global market
-- summary) and IPO Frenzy (EventService).
local function marketMood(): number
	local info: { [string]: any } = {}
	local okEvent, ev = Deps.call("MarketService", "GetActiveEvent")
	if okEvent and type(ev) == "table" and type(ev.id) == "string" then
		info.event = ev.id
	end
	local summary = Deps.global("market")
	if type(summary) == "table" then
		info.dayChange = num(summary.st10Pct, 0)
		if info.event == nil and type(summary.event) == "string" then
			info.event = summary.event
		end
	end
	local okFrenzy, frenzy = Deps.call("EventService", "IsActive", "ipo_frenzy")
	info.ipoFrenzy = okFrenzy and frenzy == true
	return Registry.marketMood(info)
end

function Flow.context(player: Player, data: { [string]: any }, who: Registry.Who): { [string]: any }
	local stats = statsOf(player, data)
	-- Logic/Stats curves (careerCore) when it loads; the work feature keeps identical local curves as the fallback
	local effects = TaskRewards.effects(stats, StatsModule)
	local profile = profileOf(data)
	local okOvr, ovr = Deps.call("ProfileService", "GetOVR", player)
	local minLevel, maxLevel = nil, nil
	local okRole, role = Deps.call("CareerService", "GetRole", player)
	if okRole and type(role) == "table" then
		minLevel = if type(role.minLevel) == "number" then role.minLevel else nil
		maxLevel = if type(role.maxLevel) == "number" then role.maxLevel else nil
	end
	local company = if who.employed then companyOf(player) else nil
	return {
		level = who.level,
		rank = who.rank,
		track = who.track,
		student = who.student,
		stats = stats,
		ovr = if okOvr and type(ovr) == "number" then ovr else num(profile.ovr, 40),
		difficulty = Registry.difficulty(who.rank, who.level, minLevel, maxLevel),
		now = Time.now(),
		hints = effects.hints,
		toleranceMult = effects.toleranceMult,
		charismaBonus = effects.charismaBonus,
		companyName = if company and type(company.name) == "string" then company.name else nil,
		firstName = if type(profile.firstName) == "string" and profile.firstName ~= "" then profile.firstName else nil,
		marketMood = marketMood(),
	}
end

local function eventMultFor(mod: any): number
	local name = if type(mod) == "table" then mod.payModifier else nil
	if type(name) ~= "string" or name == "" then
		return 1
	end
	local ok, v = Deps.call("EventService", "GetModifier", name)
	if ok and type(v) == "number" and v == v and v > 0 then
		return math.clamp(v, 0.1, 5)
	end
	return 1
end

function Flow.mults(player: Player, who: Registry.Who, mod: any?): Mults
	local payMult = 1
	if who.employed then
		local company = companyOf(player)
		if company then
			payMult = math.clamp(num(company.payMult, 1), 0.2, 3)
		end
	end
	local xpMult = 1
	local okDaily, daily = Deps.call("DailyService", "GetBoostMult", player, "xp")
	if okDaily then
		xpMult = TaskRewards.boostMult(daily)
	end
	return { payMult = payMult, xpMult = xpMult, eventMult = if mod then eventMultFor(mod) else 1 }
end

function Flow.eventMults(mods: { any }): { [string]: number }
	local out: { [string]: number } = {}
	for _, mod in mods do
		local m = eventMultFor(mod)
		if m ~= 1 then
			out[mod.id] = m
		end
	end
	return out
end

function Flow.statLabels(ids: { string }): { string }
	local out: { string } = {}
	for _, id in ids do
		table.insert(out, Registry.statLabel(id))
	end
	return out
end

function Flow.stageStats(player: Player, mod: any, stageId: string, score: number)
	Deps.call("ProfileService", "AwardStatXp", player, Registry.stageStats(mod, stageId), score, "task")
end

function Flow.reward(player: Player, mod: any, completion: Registry.Completion, who: Registry.Who): Rewards
	local quality = completion.quality
	local m = Flow.mults(player, who, mod)
	local r = Registry.rewards(mod, quality, who.rank, {
		runs = completion.closedBefore,
		closed = completion.closed,
		payMult = m.payMult,
		eventMult = m.eventMult,
		xpMult = m.xpMult,
	})
	local result: Rewards = {
		xp = 0,
		xpCapped = false,
		pay = 0,
		paid = false,
		rep = 0,
		repeatRun = r.repeatRun,
		repeatPct = math.floor(r.repeatMult * 100 + 0.5),
		pulled = r.pulled,
		plaque = false,
		stats = Flow.statLabels(Registry.statsOf(mod)),
	}

	-- the career record first: the weekly review counts the deal even if a later step fails
	Deps.call("CareerService", "RecordWork", player, {
		taskId = mod.id,
		quality = quality,
		onTime = true,
		core = true,
		category = "work",
		clientFacing = mod.clientFacing == true,
	})
	if completion.closed then
		local ok, plaque = Deps.call("CareerService", "RecordDeal", player, mod.id, completion.dealName, quality)
		result.plaque = ok and plaque ~= nil
	end

	-- the deal as a whole trains its stats a little more (careerCore applies focus and the source weight)
	Deps.call("ProfileService", "AwardStatXp", player, Registry.statsOf(mod), quality, "deal")

	if r.xp > 0 then
		local ok, added = Deps.call("CareerService", "AddXP", player, r.xp, "project")
		if ok and type(added) == "number" and added == added then
			result.xpCapped = added < r.xp
			result.xp = math.max(0, math.floor(added + 0.5))
		elseif not ok then
			result.xp = r.xp -- shown, though careerPath isn't there to bank it
		end
	end

	-- "salary" cash: EconomyService applies the salary event multiplier, daily money boosts and the rebirth mult
	if r.pay > 0 then
		local ok, credited = Deps.call("EconomyService", "AddCash", player, r.pay, "project", "salary")
		if ok then
			result.pay = if type(credited) == "number"
					and credited == credited
					and credited >= 0
				then math.floor(credited + 0.5)
				else r.pay
			result.paid = result.pay > 0
		end
	end

	if r.rep > 0 and Deps.call("CareerService", "AddReputation", player, r.rep, "deal") then
		result.rep = r.rep
	end

	local seasonXp = math.floor(result.xp * Registry.TUNING.seasonShare + 0.5)
	if seasonXp > 0 then
		Deps.call("SeasonService", "AddSeasonXP", player, seasonXp, "project")
	end
	return result
end

return Flow
