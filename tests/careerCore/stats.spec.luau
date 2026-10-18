local Shared = game:GetService("ReplicatedStorage").Shared
local Stats = require(Shared.Logic.Stats)
local Config = require(Shared.Config.LifeRoll)

local function flat(v: number): { [string]: number }
	local out = {}
	for _, id in Config.STAT_IDS do
		out[id] = v
	end
	return out
end

local function profileWith(v: number, focus: string?): any
	return { stats = flat(v), statXp = {}, growth = {}, weekGrowth = { key = "", gains = {} }, focus = focus or "" }
end

return function(t)
	t.describe("Overall and archetype", function()
		t.it("OVR is the rounded mean, clamped 1..99", function()
			t.expect(Stats.ovr(flat(40))).toBe(40)
			local s = flat(40)
			s.skill = 44 -- mean 40.5 -> 41
			t.expect(Stats.ovr(s)).toBe(41)
			t.expect(Stats.ovr(flat(150))).toBe(99)
			t.expect(Stats.ovr({})).toBe(1)
			t.expect(Stats.ovr(nil)).toBe(1)
		end)

		t.it("archetype comes from the top two stats", function()
			local s = flat(40)
			s.charisma = 60
			s.network = 55
			t.expect(Stats.archetype(s).id).toBe("rainmaker")
			s = flat(40)
			s.knowledge = 70
			s.skill = 65
			t.expect(Stats.archetype(s).id).toBe("quant_machine")
			s = flat(40)
			s.speed = 70
			s.skill = 70
			t.expect(Stats.archetype(s).id).toBe("grinder")
			t.expect(Stats.archetype(flat(50)).id).toBe("quant_machine") -- ties: display order
		end)
	end)

	t.describe("Growth", function()
		t.it("xp cost rises with the value and is infinite at 99", function()
			local last = 0
			for v = 1, 98 do
				local c = Stats.xpCost(v)
				t.expect(c >= last).toBeTruthy()
				last = c
			end
			t.expect(Stats.xpCost(95) > Stats.xpCost(85) * 2).toBeTruthy() -- slows near the top
			t.expect(Stats.xpCost(99)).toBe(math.huge)
		end)

		t.it("quality factor is monotonic and bad work gives almost nothing", function()
			local last = -1
			for q = 0, 100, 5 do
				local f = Stats.qualityFactor(q)
				t.expect(f >= last).toBeTruthy()
				t.expect(f).toBeBetween(0, 1)
				last = f
			end
			t.expect(Stats.qualityFactor(0)).toBe(0)
			t.expect(Stats.qualityFactor(20) <= 0.05).toBeTruthy()
			t.expect(Stats.qualityFactor(100)).toBe(1)
			t.expect(Stats.qualityFactor(0 / 0)).toBe(0)
		end)

		t.it("focus doubles its two stats and slows the rest to 0.75x", function()
			t.expect(Stats.focusMult("modeling", "skill")).toBe(2)
			t.expect(Stats.focusMult("modeling", "knowledge")).toBe(2)
			t.expect(Stats.focusMult("modeling", "charisma")).toBe(0.75)
			t.expect(Stats.focusMult("", "skill")).toBe(1)
			t.expect(Stats.focusMult(nil, "skill")).toBe(1)
			t.expect(Stats.xpGain(80, "client", "charisma")).toBeCloseTo(Stats.xpGain(80, "", "charisma") * 2)
			t.expect(Stats.xpGain(80, "client", "skill")).toBeCloseTo(Stats.xpGain(80, "", "skill") * 0.75)
			t.expect(Stats.xpGain(80, "", "skill", "review")).toBeCloseTo(Stats.xpGain(80, "", "skill") * 3)
		end)

		t.it("award grows only the named stats and records the week's gains", function()
			local p = profileWith(40, "modeling")
			local ups = 0
			for _ = 1, 30 do
				local r = Stats.award(p, { "skill", "knowledge", "skill", "nope" }, 90, "task", "w3")
				ups += #r.ups
			end
			t.expect(ups > 0).toBeTruthy()
			t.expect(p.stats.skill > 40).toBeTruthy()
			t.expect(p.stats.knowledge > 40).toBeTruthy()
			t.expect(p.stats.charisma).toBe(40)
			t.expect(p.growth.skill).toBe(p.stats.skill - 40)
			t.expect(p.weekGrowth.key).toBe("w3")
			t.expect(p.weekGrowth.gains.skill).toBe(p.stats.skill - 40)
			Stats.award(p, { "skill" }, 90, "task", "w4")
			t.expect(p.weekGrowth.key).toBe("w4")
			t.expect((p.weekGrowth.gains.skill or 0) <= 1).toBeTruthy()
			t.expect(p.ovr).toBe(Stats.ovr(p.stats))
			t.expect(type(p.archetype)).toBe("string")
		end)

		t.it("better work and focus grow faster", function()
			local function pointsAfter(quality: number, focus: string): number
				local p = profileWith(45, focus)
				for _ = 1, 60 do
					Stats.award(p, { "skill" }, quality, "task")
				end
				return p.stats.skill
			end
			t.expect(pointsAfter(95, "") > pointsAfter(60, "")).toBeTruthy()
			t.expect(pointsAfter(60, "") >= pointsAfter(20, "")).toBeTruthy()
			t.expect(pointsAfter(80, "execution") > pointsAfter(80, "")).toBeTruthy()
			t.expect(pointsAfter(80, "") > pointsAfter(80, "client")).toBeTruthy()
		end)

		t.it("never passes 99 and stops taking xp there", function()
			local p = profileWith(97, "modeling")
			for _ = 1, 2000 do
				Stats.award(p, { "skill" }, 100, "review")
			end
			t.expect(p.stats.skill).toBe(99)
			t.expect(p.statXp.skill).toBe(0)
			local r = Stats.award(p, { "skill" }, 100, "review")
			t.expect(#r.ups).toBe(0)
		end)

		t.it("OVR is monotonic under growth", function()
			local p = profileWith(30, "")
			local last = Stats.ovr(p.stats)
			for i = 1, 400 do
				local id = Config.STAT_IDS[(i % 8) + 1]
				local r = Stats.award(p, { id }, 85, "task")
				t.expect(r.ovrTo >= last).toBeTruthy()
				last = r.ovrTo
			end
		end)
	end)

	t.describe("Effect helpers", function()
		t.it("timerMult: +-0.4% per point from 50, capped +-20%", function()
			t.expect(Stats.timerMult(50)).toBeCloseTo(1)
			t.expect(Stats.timerMult(75)).toBeCloseTo(1.1)
			t.expect(Stats.timerMult(99)).toBeCloseTo(1.196)
			t.expect(Stats.timerMult(1)).toBeCloseTo(0.804)
			t.expect(Stats.timerMult(500)).toBeCloseTo(1.2)
			t.expect(Stats.timerMult(-500)).toBeCloseTo(0.8)
		end)

		t.it("hintCount: 0/1/2/3 at <30 / 30-59 / 60-84 / 85+", function()
			t.expect(Stats.hintCount(29)).toBe(0)
			t.expect(Stats.hintCount(30)).toBe(1)
			t.expect(Stats.hintCount(59)).toBe(1)
			t.expect(Stats.hintCount(60)).toBe(2)
			t.expect(Stats.hintCount(84)).toBe(2)
			t.expect(Stats.hintCount(85)).toBe(3)
			t.expect(Stats.hintCount(99)).toBe(3)
		end)

		t.it("every helper stays in its documented range", function()
			for v = -10, 120 do
				t.expect(Stats.timerMult(v)).toBeBetween(0.8, 1.2)
				t.expect(Stats.hintCount(v)).toBeBetween(0, 3)
				t.expect(Stats.toleranceMult(v)).toBeBetween(1, 1.5)
				t.expect(Stats.charismaBonus(v)).toBeBetween(0, 8)
				t.expect(Stats.networkOfferBonus(v)).toBeBetween(-0.08, 0.08)
				t.expect(Stats.riskHeadroom(v)).toBeBetween(0, 0.05)
				t.expect(Stats.deadlineGrace(v)).toBeBetween(0, 0.1)
				t.expect(Stats.luckBonus(v)).toBeBetween(0, 0.1)
			end
			t.expect(Stats.toleranceMult(99)).toBeCloseTo(1.5)
			t.expect(Stats.charismaBonus(99)).toBeCloseTo(8)
			t.expect(Stats.charismaBonus(50)).toBe(0)
			t.expect(Stats.riskHeadroom(99)).toBeCloseTo(0.05)
			local e = Stats.effects(flat(60))
			t.expect(e.hints).toBe(2)
			t.expect(e.timerMult).toBeCloseTo(1.04)
			t.expect(type(Stats.effects(nil).timerMult)).toBe("number")
		end)
	end)
end
