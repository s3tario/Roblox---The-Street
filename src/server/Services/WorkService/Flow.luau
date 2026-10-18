--!strict
-- WorkService/Flow (server, runtime only): everything between "start" and "paid" that needs other features.
--
--   Flow.who(data) -> (Board.Who, career)
--   Flow.effects(player, data) -> effects             timerMult, hints, toleranceMult, charismaBonus, deadlineGrace
--   Flow.context(player, data, mod, entry, who) -> (ctx, effects)
--       ctx = { level, rank, track, student, stats, ovr, difficulty, facts?, now, hints, toleranceMult,
--               charismaBonus, offer = entry.data, companyName?, firstName? }   (contracts §8)
--   Flow.timer(player, mod, effects) -> (limit, grace)    Speed x pizza buff; network grace + Discipline share
--   Flow.multipliers(player, who, atDesk) -> Mults      XP: desk bonus x daily boost x social boost;
--                                                        pay: company payMult x event taskPayMult
--   Flow.estimate(mod, who, mults) -> { xp, pay }        at a typical quality (75), for the board cards
--   Flow.reward(player, mod, info) -> Result             applies XP, pay, stats, reputation, season XP; returns
--                                                        what the player earned (never throws)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Time = require(Shared.Util.Time)
local Format = require(Shared.Util.Format)
local Config = require(Shared.Config.Tasks)
local TasksFolder = Shared:WaitForChild("Logic"):WaitForChild("Tasks")
local Board = require(TasksFolder:WaitForChild("_shared"):WaitForChild("Board"))
local Rewards = require(TasksFolder._shared:WaitForChild("Rewards"))
local Universe = require(TasksFolder._shared:WaitForChild("Universe"))
local Deps = require(script.Parent.Deps)

local Logic = Shared:WaitForChild("Logic")
local StatsModule = Deps.require(Logic:FindFirstChild("Stats"))
local Leveling = Deps.require(Logic:FindFirstChild("Leveling"))

export type Mults = { xp: number, pay: number, social: number, desk: boolean }
export type RewardInfo = {
	quality: number,
	onTime: boolean,
	who: Board.Who,
	mults: Mults,
	entry: Board.Entry?,
	taskId: string,
}
export type Result = {
	xp: number,
	xpCapped: boolean,
	pay: number,
	paid: boolean,
	rep: number,
	stats: { string },
}

local Flow = {}

local num = Deps.num
local TYPICAL_QUALITY = 75

local function profileOf(data: { [string]: any }): { [string]: any }
	return if type(data.profile) == "table" then data.profile else {}
end

function Flow.who(data: { [string]: any }): (Board.Who, { [string]: any })
	local career = if type(data.career) == "table" then data.career else {}
	return Board.who(career), career
end

local function statsOf(player: Player, data: { [string]: any }): { [string]: number }
	local ok, stats = Deps.call("ProfileService", "GetStats", player)
	if ok and type(stats) == "table" then
		return stats
	end
	local p = profileOf(data)
	local out: { [string]: number } = {}
	if type(p.stats) == "table" then
		for k, v in p.stats do
			if type(k) == "string" and type(v) == "number" then
				out[k] = v
			end
		end
	end
	return out
end

-- Design v3 §3 effects for this player (Logic/Stats curves, or Rewards' identical local fallback).
function Flow.effects(player: Player, data: { [string]: any }): { [string]: number }
	return Rewards.effects(statsOf(player, data), StatsModule)
end

-- Market facts for modules that declare facts = true (earnings_reaction): live prices of the listed tickers.
local function factsFor(): { [string]: any }?
	if not Deps.has("MarketService", "GetPrice") and not Deps.has("MarketService", "GetCompanyFacts") then
		return nil
	end
	local out: { [string]: any } = {}
	for _, co in Universe.LISTED do
		local entry: { [string]: any } = {}
		local okFacts, facts = Deps.call("MarketService", "GetCompanyFacts", co.ticker)
		if okFacts and type(facts) == "table" then
			for k, v in facts do
				if type(k) == "string" and (type(v) == "number" or type(v) == "string" or type(v) == "boolean") then
					entry[k] = v
				end
			end
		end
		local okPrice, price = Deps.call("MarketService", "GetPrice", co.ticker)
		if okPrice and type(price) == "number" and price == price and price > 0 then
			entry.price = price
		end
		if next(entry) ~= nil then
			out[co.ticker] = entry
		end
	end
	return if next(out) ~= nil then out else nil
end

local function companyName(player: Player, who: Board.Who): string?
	if who.student or who.unemployed then
		return nil
	end
	local ok, company = Deps.call("CareerService", "GetCompany", player)
	if ok and type(company) == "table" and type(company.name) == "string" then
		return company.name
	end
	return nil
end

function Flow.context(
	player: Player,
	data: { [string]: any },
	mod: any,
	entry: Board.Entry?,
	who: Board.Who
): ({ [string]: any }, { [string]: number })
	local stats = statsOf(player, data)
	-- Logic/Stats curves (careerCore) when it loads; Rewards keeps identical local curves as the fallback
	local effects = Rewards.effects(stats, StatsModule)
	local profile = profileOf(data)
	local okOvr, ovr = Deps.call("ProfileService", "GetOVR", player)
	local minLevel, maxLevel = nil, nil
	if not who.student and not who.unemployed then
		local okRole, role = Deps.call("CareerService", "GetRole", player)
		if okRole and type(role) == "table" then
			minLevel = if type(role.minLevel) == "number" then role.minLevel else nil
			maxLevel = if type(role.maxLevel) == "number" then role.maxLevel else nil
		end
	end
	local ctx: { [string]: any } = {
		level = who.level,
		rank = who.rank,
		track = who.track,
		student = who.student,
		unemployed = who.unemployed,
		stats = stats,
		ovr = if okOvr and type(ovr) == "number" then ovr else num(profile.ovr, 40),
		difficulty = Rewards.difficulty(who, who.level, minLevel, maxLevel),
		now = Time.now(),
		hints = effects.hints,
		toleranceMult = effects.toleranceMult,
		charismaBonus = effects.charismaBonus,
		companyName = companyName(player, who),
		firstName = if type(profile.firstName) == "string" and profile.firstName ~= "" then profile.firstName else nil,
	}
	if entry and type(entry.data) == "table" then
		ctx.offer = table.clone(entry.data)
	end
	if mod.facts == true then
		ctx.facts = factsFor()
	end
	return ctx, effects
end

local BUFF_NAMES = { "taskTimer", "pizza_party", "pizza" }

function Flow.timer(player: Player, mod: any, effects: { [string]: number }): (number, number)
	local buff = 1
	for _, name in BUFF_NAMES do
		local ok, v = Deps.call("EventService", "GetPlayerBuff", player, name)
		if ok and type(v) == "number" then
			buff = math.max(buff, Rewards.boostMult(v))
		end
	end
	local limit = Rewards.timeLimit(mod.timeLimit, effects.timerMult, buff)
	return limit, Rewards.grace(limit, effects.deadlineGrace)
end

function Flow.multipliers(player: Player, who: Board.Who, atDesk: boolean): Mults
	local xp = if atDesk then Config.rewards.deskBonus else 1
	local okDaily, daily = Deps.call("DailyService", "GetBoostMult", player, "xp")
	if okDaily then
		xp *= Rewards.boostMult(daily)
	end
	local social = 1
	local okSocial, boost = Deps.call("SocialService", "GetXpBoost", player)
	if okSocial and boost ~= nil and boost ~= false then
		social = if type(boost) == "number" then Rewards.boostMult(boost) elseif boost == true then 1.1 else 1
	end
	xp *= social
	local pay = 1
	if not who.student and not who.unemployed then
		local okCompany, company = Deps.call("CareerService", "GetCompany", player)
		if okCompany and type(company) == "table" then
			pay *= math.clamp(num(company.payMult, 1), 0.2, 3)
		end
	end
	local okMod, eventMult = Deps.call("EventService", "GetModifier", "taskPayMult")
	if okMod and type(eventMult) == "number" and eventMult == eventMult and eventMult > 0 then
		pay *= math.clamp(eventMult, 0.1, 5)
	end
	return { xp = xp, pay = pay, social = social, desk = atDesk }
end

local function rewardRank(who: Board.Who): number
	return if who.student or who.unemployed then 0 else who.rank
end

function Flow.estimate(mod: any, who: Board.Who, mults: Mults): { xp: number, pay: number }
	local rank = rewardRank(who)
	return {
		xp = Rewards.xp(mod.baseXp, TYPICAL_QUALITY, Rewards.xpScale(rank, Leveling), mults.xp),
		pay = Rewards.pay(mod.basePay, TYPICAL_QUALITY, Rewards.payScale(rank), mults.pay, true),
	}
end

function Flow.statNames(mod: any): { string }
	local out: { string } = {}
	for _, s in mod.stats or {} do
		table.insert(out, Config.STAT_NAMES[s] or s)
	end
	return out
end

function Flow.reward(player: Player, mod: any, info: RewardInfo): Result
	local who = info.who
	local rank = rewardRank(who)
	local quality = info.quality
	local result: Result = { xp = 0, xpCapped = false, pay = 0, paid = false, rep = 0, stats = Flow.statNames(mod) }

	-- career record first: the review counts the work even if a later step fails
	Deps.call("CareerService", "RecordWork", player, {
		taskId = mod.id,
		quality = quality,
		onTime = info.onTime,
		core = mod.core == true and not (info.entry and info.entry.offered == true),
		category = mod.category,
		clientFacing = mod.clientFacing == true,
	})

	-- stats grow only from graded work (careerCore applies the focus multipliers)
	Deps.call("ProfileService", "AwardStatXp", player, mod.stats, quality, "task")

	-- XP
	local xp = Rewards.xp(mod.baseXp, quality, Rewards.xpScale(rank, Leveling), info.mults.xp)
	if xp > 0 then
		local ok, added = Deps.call("CareerService", "AddXP", player, xp, "work")
		if ok and type(added) == "number" and added == added then
			result.xpCapped = added < xp
			result.xp = math.max(0, math.floor(added + 0.5))
		elseif not ok then
			result.xp = xp -- shown, though careerPath isn't there to bank it
		end
	end
	if info.mults.social > 1 then
		Deps.call("SocialService", "ConsumeXpBoost", player)
	end

	-- pay (EconomyService applies the salary event multiplier, daily money boosts and the rebirth income mult)
	local pay = Rewards.pay(mod.basePay, quality, Rewards.payScale(rank), info.mults.pay, info.onTime)
	if pay > 0 then
		local ok, credited = Deps.call("EconomyService", "AddCash", player, pay, "work", "salary")
		if ok then
			result.paid = true
			result.pay = if type(credited) == "number"
					and credited == credited
					and credited >= 0
				then math.floor(credited + 0.5)
				else pay
		end
	end

	-- client-facing work done brilliantly earns a little extra reputation, nudged by dress code and Fit Score
	if mod.clientFacing == true and quality >= Config.rewards.repExcellent and not who.student then
		local okBonus, bonus = Deps.call("CareerService", "GetClientBonus", player)
		local rep = math.floor(
			1 * (if okBonus and type(bonus) == "number" then math.clamp(bonus, 1, 1.5) else 1) * 10 + 0.5
		) / 10
		if Deps.call("CareerService", "AddReputation", player, rep, "client_work") then
			result.rep = rep
		end
	end

	-- Season XP (monetization) when the season pass exists
	local seasonXp = math.floor(result.xp * Config.rewards.seasonXpShare + 0.5)
	if seasonXp > 0 then
		Deps.call("SeasonService", "AddSeasonXP", player, seasonXp, "work")
	end
	return result
end

function Flow.toast(mod: any, quality: number, result: Result): string
	if result.paid and result.pay > 0 then
		return Config.text(
			"toast_done",
			{ title = mod.title, q = quality, xp = Format.commas(result.xp), pay = Format.money(result.pay) }
		)
	end
	return Config.text("toast_done_nopay", { title = mod.title, q = quality, xp = Format.commas(result.xp) })
end

return Flow
