--!strict
-- Attribute rules (owned by `careerCore`; design v3 §3, contracts §4). PURE: no services, no clocks, no Instances.
--
-- Overall and archetype
--   Stats.IDS                                  the eight attribute ids in display order
--   Stats.clamp(v) -> 1..99 (whole number)     Stats.total(stats) -> number
--   Stats.ovr(stats) -> 1..99                  the rounded mean of the eight
--   Stats.topTwo(stats) -> (a, b)              highest two stat ids (ties: display order)
--   Stats.archetype(stats) -> ArchetypeDef     from the top two (Config/LifeRoll archetypes)
-- Growth (AwardStatXp is the only way stats grow; there are no direct upgrades)
--   Stats.qualityFactor(quality 0..100) -> 0..1   bad work gives almost nothing
--   Stats.focusMult(focusId, statId) -> 2 | 0.75 | 1 (no focus)
--   Stats.xpCost(value) -> xp for value -> value + 1 (rises with value, steeply from 90; math.huge at 99)
--   Stats.xpGain(quality, focusId, statId, source?) -> xp
--   Stats.award(profile, statIds, quality, source?, weekKey?) -> AwardResult
--       mutates profile.stats / statXp / growth / weekGrowth / ovr / archetype; returns the points gained
-- Effects used by work and project code (contracts §4)
--   Stats.timerMult(speed) -> 0.8..1.2         task timer: +-0.4% per point from 50
--   Stats.hintCount(knowledge) -> 0..3          0 / 1 / 2 / 3 at <30 / 30-59 / 60-84 / 85+
--   Stats.toleranceMult(skill) -> 1..1.5        numeric tolerance on fill/spot grading (+50% at 99)
--   Stats.charismaBonus(charisma) -> 0..8       quality points on dialogue sections (above 50)
--   Stats.networkOfferBonus(network) -> -0.08..0.08   offer-odds edge (the same curve as Logic/Recruiting)
--   Stats.riskHeadroom(risk) -> 0..0.05        extra concentration-limit headroom
--   Stats.deadlineGrace(discipline) -> 0..0.1  extra deadline grace as a fraction of a task's time limit
--   Stats.luckBonus(luck) -> 0..0.1            cosmetic/event drop bonus only (never grades or returns)
--   Stats.effects(stats) -> { timerMult, hints, toleranceMult, charismaBonus, networkOfferBonus, riskHeadroom,
--                             deadlineGrace, luckBonus }

local LifeRoll = require(game:GetService("ReplicatedStorage").Shared.Config.LifeRoll)

export type StatMap = { [string]: number }
export type Up = { stat: string, from: number, to: number }
export type AwardResult = { ups: { Up }, ovrFrom: number, ovrTo: number, xp: { [string]: number } }

local Stats = {}

Stats.IDS = LifeRoll.STAT_IDS
Stats.MIN = LifeRoll.rules.statFloor
Stats.MAX = LifeRoll.rules.statCap
Stats.BASE_XP = 10 -- xp per award at perfect quality, 1x focus, a plain task
Stats.FOCUS_MULT = 2
Stats.OFF_FOCUS_MULT = 0.75
Stats.MAX_UPS_PER_AWARD = 3
-- Weekly reviews award a band bonus; projects count more than a single task.
Stats.SOURCE_MULT = { review = 3, project = 2, deal = 2, task = 1 } :: { [string]: number }

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end
Stats.num = num

local function unit(x: number, lo: number, hi: number): number
	return math.clamp((x - lo) / (hi - lo), 0, 1)
end

function Stats.clamp(v: any): number
	return math.clamp(math.floor(num(v, Stats.MIN) + 0.5), Stats.MIN, Stats.MAX)
end

function Stats.total(stats: any): number
	local t = 0
	if type(stats) ~= "table" then
		return t
	end
	for _, id in Stats.IDS do
		t += Stats.clamp(stats[id])
	end
	return t
end

function Stats.ovr(stats: any): number
	return Stats.clamp(Stats.total(stats) / #Stats.IDS)
end

function Stats.topTwo(stats: any): (string, string)
	local s = if type(stats) == "table" then stats else {}
	local ranked = table.clone(Stats.IDS)
	table.sort(ranked, function(a, b)
		local va, vb = Stats.clamp(s[a]), Stats.clamp(s[b])
		if va == vb then
			return LifeRoll.STAT_ORDER[a] < LifeRoll.STAT_ORDER[b]
		end
		return va > vb
	end)
	return ranked[1], ranked[2]
end

function Stats.archetype(stats: any): LifeRoll.ArchetypeDef
	local a, b = Stats.topTwo(stats)
	local def = LifeRoll.archetypeFor(a, b)
	if def then
		return def
	end
	-- unreachable with the shipped config (every pair has an archetype); keeps callers total
	return { id = "generalist", name = "Generalist", desc = "" }
end

---------------------------------------------------------------------------------------------------
-- Growth
---------------------------------------------------------------------------------------------------
function Stats.qualityFactor(quality: any): number
	local q = math.clamp(num(quality, 0), 0, 100)
	if q <= 0 then
		return 0
	end
	local f = unit(q, 30, 100) ^ 1.5
	return math.max(0.04, f)
end

function Stats.focusMult(focusId: any, statId: string): number
	local def = LifeRoll.focusDef(focusId)
	if not def then
		return 1
	end
	if table.find(def.stats, statId) then
		return Stats.FOCUS_MULT
	end
	return Stats.OFF_FOCUS_MULT
end

function Stats.xpCost(value: any): number
	local v = math.floor(num(value, Stats.MIN))
	if v >= Stats.MAX then
		return math.huge
	end
	v = math.max(Stats.MIN, v)
	local cost = 30 + 60 * (v / Stats.MAX) ^ 2
	if v >= 90 then
		cost += (v - 89) * 25 -- growth slows sharply near the top
	end
	return math.floor(cost + 0.5)
end

function Stats.xpGain(quality: any, focusId: any, statId: string, source: string?): number
	local srcMult = if source then (Stats.SOURCE_MULT[source] or 1) else 1
	return Stats.BASE_XP * Stats.qualityFactor(quality) * Stats.focusMult(focusId, statId) * srcMult
end

local function tableField(p: any, key: string): { [string]: any }
	local t = p[key]
	if type(t) ~= "table" then
		t = {}
		p[key] = t
	end
	return t
end

-- Adds stat XP from one graded piece of work and turns it into points. Unknown ids are ignored, duplicates count
-- once. Stats at 99 take no XP.
function Stats.award(p: any, statIds: any, quality: any, source: string?, weekKey: string?): AwardResult
	local stats = tableField(p, "stats")
	local statXp = tableField(p, "statXp")
	local growth = tableField(p, "growth")
	local result: AwardResult = { ups = {}, ovrFrom = Stats.ovr(stats), ovrTo = 0, xp = {} }
	local wg = p.weekGrowth
	if type(wg) ~= "table" then
		wg = { key = "", gains = {} }
		p.weekGrowth = wg
	end
	if weekKey ~= nil and wg.key ~= weekKey then
		wg.key = weekKey
		wg.gains = {}
	end
	if type(wg.gains) ~= "table" then
		wg.gains = {}
	end
	local seen: { [string]: boolean } = {}
	if type(statIds) == "table" then
		for _, id in statIds do
			if type(id) == "string" and LifeRoll.stat(id) and not seen[id] then
				seen[id] = true
				local value = Stats.clamp(stats[id])
				stats[id] = value
				if value >= Stats.MAX then
					statXp[id] = 0
				else
					local gain = Stats.xpGain(quality, p.focus, id, source)
					local xp = num(statXp[id], 0) + gain
					result.xp[id] = gain
					local ups = 0
					while ups < Stats.MAX_UPS_PER_AWARD and value < Stats.MAX and xp >= Stats.xpCost(value) do
						xp -= Stats.xpCost(value)
						table.insert(result.ups, { stat = id, from = value, to = value + 1 })
						value += 1
						ups += 1
					end
					if value >= Stats.MAX then
						xp = 0
					end
					stats[id] = value
					statXp[id] = math.floor(xp * 100 + 0.5) / 100
					if ups > 0 then
						growth[id] = math.floor(num(growth[id], 0)) + ups
						wg.gains[id] = math.floor(num(wg.gains[id], 0)) + ups
					end
				end
			end
		end
	end
	result.ovrTo = Stats.ovr(stats)
	p.ovr = result.ovrTo
	p.archetype = Stats.archetype(stats).id
	return result
end

---------------------------------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------------------------------
function Stats.timerMult(speed: any): number
	return 1 + math.clamp((num(speed, 50) - 50) * 0.004, -0.2, 0.2)
end

function Stats.hintCount(knowledge: any): number
	local k = num(knowledge, 0)
	if k >= 85 then
		return 3
	elseif k >= 60 then
		return 2
	elseif k >= 30 then
		return 1
	end
	return 0
end

function Stats.toleranceMult(skill: any): number
	return 1 + 0.5 * unit(num(skill, 25), 25, Stats.MAX)
end

function Stats.charismaBonus(charisma: any): number
	return math.clamp((num(charisma, 50) - 50) / 49 * 8, 0, 8)
end

function Stats.networkOfferBonus(network: any): number
	return math.clamp((num(network, 50) - 50) * 0.002, -0.08, 0.08)
end

function Stats.riskHeadroom(risk: any): number
	return 0.05 * unit(num(risk, 25), 25, Stats.MAX)
end

function Stats.deadlineGrace(discipline: any): number
	return 0.1 * unit(num(discipline, 25), 25, Stats.MAX)
end

function Stats.luckBonus(luck: any): number
	return 0.1 * unit(num(luck, 25), 25, Stats.MAX)
end

function Stats.effects(stats: any): { [string]: number }
	local s = if type(stats) == "table" then stats else {}
	return {
		timerMult = Stats.timerMult(s.speed),
		hints = Stats.hintCount(s.knowledge),
		toleranceMult = Stats.toleranceMult(s.skill),
		charismaBonus = Stats.charismaBonus(s.charisma),
		networkOfferBonus = Stats.networkOfferBonus(s.network),
		riskHeadroom = Stats.riskHeadroom(s.risk),
		deadlineGrace = Stats.deadlineGrace(s.discipline),
		luckBonus = Stats.luckBonus(s.luck),
	}
end

return Stats
