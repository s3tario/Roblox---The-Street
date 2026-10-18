--!strict
-- Work rewards, timers and difficulty (owned by `work`; contracts §8, spec §5/§11, design v3 §3). PURE.
--
--   Rewards.qualityFactor(q) -> 0..1        0 at quality 0, participation share at the floor, 1 at 100
--   Rewards.payScale(rank) / Rewards.xpScale(rank, Leveling?) -> number
--   Rewards.xp(baseXp, quality, rankScale, mult?) -> integer
--   Rewards.pay(basePay, quality, payScale, mult?, onTime?) -> integer
--   Rewards.timeLimit(base, timerMult?, buff?) -> seconds      Speed stat (Stats.timerMult) x event buff
--   Rewards.grace(limit, deadlineGrace?) -> seconds            network grace + Discipline share of the limit
--   Rewards.onTime(elapsed, limit, grace) -> boolean
--   Rewards.expired(elapsed, limit) -> boolean                 past timeLimit x Config.timing.expireMult
--   Rewards.difficulty(who, level, minLevel?, maxLevel?) -> 0..1
--   Rewards.effects(stats, Stats?) -> { timerMult, hints, toleranceMult, charismaBonus, deadlineGrace }
--       uses careerCore's Logic/Stats when given, else the same curves locally (design v3 §3)
--   Rewards.boostMult(x) -> number          reads a boost as a multiplier (1.1) or a bonus fraction (0.1)

local Config = require(script.Parent.Parent.Parent.Parent.Config.Tasks)

local Rewards = {}

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end
Rewards.num = num

function Rewards.qualityFactor(quality: any): number
	local r = Config.rewards
	local q = math.clamp(num(quality, 0), 0, 100)
	local floor = r.qualityFloor
	local share = r.participation
	if q <= floor then
		return share * q / floor
	end
	return share + (1 - share) * (q - floor) / (100 - floor)
end

local function scaleFrom(tbl: { [number]: number }, rank: number): number
	local r = math.max(0, math.floor(num(rank, 0)))
	local v = tbl[r]
	if v then
		return v
	end
	local top = 0
	for k in tbl do
		if k > top then
			top = k
		end
	end
	return tbl[top] or 1
end

function Rewards.payScale(rank: number): number
	return scaleFrom(Config.rewards.payScale, rank)
end

-- Leveling (careerPath) is the source of truth for XP pacing; the config mirrors it as a fallback.
function Rewards.xpScale(rank: number, leveling: any?): number
	if type(leveling) == "table" and type(leveling.rankXpScale) == "function" then
		local ok, v = pcall(leveling.rankXpScale, math.max(0, math.floor(num(rank, 0))))
		if ok and type(v) == "number" and v == v and v > 0 then
			return v
		end
	end
	return scaleFrom(Config.rewards.xpScale, rank)
end

function Rewards.xp(baseXp: number, quality: number, rankScale: number, mult: number?): number
	local v = num(baseXp, 0) * Rewards.qualityFactor(quality) * num(rankScale, 1) * num(mult, 1)
	return math.clamp(math.floor(v + 0.5), 0, Config.rewards.maxXp)
end

function Rewards.pay(basePay: number, quality: number, payScale: number, mult: number?, onTime: boolean?): number
	local late = if onTime == false then Config.rewards.lateMult else 1
	local v = num(basePay, 0) * Rewards.qualityFactor(quality) * num(payScale, 1) * num(mult, 1) * late
	return math.clamp(math.floor(v + 0.5), 0, Config.rewards.maxPay)
end

function Rewards.timeLimit(base: number, timerMult: number?, buff: number?): number
	local b = math.max(15, num(base, Config.timing.defaultLimit))
	local t = math.clamp(num(timerMult, 1), 0.5, 2)
	local f = math.clamp(num(buff, 1), 1, 2)
	return math.floor(b * t * f + 0.5)
end

function Rewards.grace(limit: number, deadlineGrace: number?): number
	return Config.timing.graceSeconds + math.max(0, num(limit, 0)) * math.clamp(num(deadlineGrace, 0), 0, 0.5)
end

function Rewards.onTime(elapsed: number, limit: number, grace: number): boolean
	return num(elapsed, math.huge) <= num(limit, 0) + num(grace, 0)
end

function Rewards.expired(elapsed: number, limit: number): boolean
	return num(elapsed, 0) > math.max(60, num(limit, 0) * Config.timing.expireMult)
end

-- Students ramp from 0.1 to 0.35 over levels 1-8; employees from 0.25 at a fresh Analyst to ~0.95 at a seasoned MD.
function Rewards.difficulty(who: { [string]: any }, level: number, minLevel: number?, maxLevel: number?): number
	local lv = math.max(1, num(level, 1))
	if who.unemployed then
		return 0.4
	end
	if who.student then
		return math.clamp(0.1 + 0.25 * (lv - 1) / 7, 0.1, 0.35)
	end
	local rank = math.max(1, math.floor(num(who.rank, 1)))
	local lo = num(minLevel, lv)
	local hi = num(maxLevel, lv)
	local progress = if hi > lo then math.clamp((lv - lo) / (hi - lo), 0, 1) else 0
	return math.clamp(0.25 + 0.15 * (rank - 1) + 0.1 * progress, 0, 1)
end

-- Design v3 §3 effects; identical to Logic/Stats so the fallback never changes the game.
local function localEffects(stats: { [string]: any }): { [string]: number }
	local speed = num(stats.speed, 50)
	local knowledge = num(stats.knowledge, 0)
	local skill = num(stats.skill, 25)
	local charisma = num(stats.charisma, 50)
	local discipline = num(stats.discipline, 25)
	local hints = if knowledge >= 85 then 3 elseif knowledge >= 60 then 2 elseif knowledge >= 30 then 1 else 0
	return {
		timerMult = 1 + math.clamp((speed - 50) * 0.004, -0.2, 0.2),
		hints = hints,
		toleranceMult = 1 + 0.5 * math.clamp((skill - 25) / (99 - 25), 0, 1),
		charismaBonus = math.clamp((charisma - 50) / 49 * 8, 0, 8),
		deadlineGrace = 0.1 * math.clamp((discipline - 25) / (99 - 25), 0, 1),
	}
end
Rewards.localEffects = localEffects

function Rewards.effects(stats: any, statsModule: any?): { [string]: number }
	local s = if type(stats) == "table" then stats else {}
	local out = localEffects(s)
	if type(statsModule) == "table" then
		local function use(key: string, fnName: string, arg: any)
			local fn = statsModule[fnName]
			if type(fn) == "function" then
				local ok, v = pcall(fn, arg)
				if ok and type(v) == "number" and v == v then
					out[key] = v
				end
			end
		end
		use("timerMult", "timerMult", s.speed)
		use("hints", "hintCount", s.knowledge)
		use("toleranceMult", "toleranceMult", s.skill)
		use("charismaBonus", "charismaBonus", s.charisma)
		use("deadlineGrace", "deadlineGrace", s.discipline)
	end
	out.timerMult = math.clamp(out.timerMult, 0.8, 1.2)
	out.hints = math.clamp(math.floor(out.hints), 0, 3)
	out.toleranceMult = math.clamp(out.toleranceMult, 1, 1.5)
	out.charismaBonus = math.clamp(out.charismaBonus, 0, 8)
	out.deadlineGrace = math.clamp(out.deadlineGrace, 0, 0.5)
	return out
end

function Rewards.boostMult(x: any): number
	local v = num(x, 1)
	if v <= 0 then
		return 1
	elseif v < 1 then
		return 1 + v -- a bonus fraction (0.1 = +10%)
	end
	return math.min(v, 5)
end

return Rewards
