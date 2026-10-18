-- Work rewards (Logic/Tasks/_shared/Rewards) and the design v3 §3 stat effects as the task graders see them:
-- Speed -> timer, Knowledge -> hints, Skill -> fill/spot tolerance, Charisma -> dialogue points, Discipline -> grace.
local Shared = game:GetService("ReplicatedStorage").Shared
local Rng = require(Shared.Util.Rng)
local TasksFolder = Shared.Logic.Tasks
local Rewards = require(TasksFolder._shared.Rewards)
local Grade = require(TasksFolder._shared.Grade)
local Build = require(TasksFolder._shared.Build)
local Solve = require(TasksFolder._shared.Solve)
local Config = require(Shared.Config.Tasks)
local Stats = require(Shared.Logic.Stats)
local Leveling = require(Shared.Logic.Leveling)

return function(t)
	t.describe("quality, XP and pay", function()
		t.it("quality factor runs 0 -> participation at the floor -> 1, monotonic", function()
			t.expect(Rewards.qualityFactor(0)).toBe(0)
			t.expect(Rewards.qualityFactor(Config.rewards.qualityFloor)).toBeCloseTo(Config.rewards.participation, 1e-9)
			t.expect(Rewards.qualityFactor(100)).toBeCloseTo(1, 1e-9)
			local prev = -1
			for q = 0, 100, 5 do
				local f = Rewards.qualityFactor(q)
				t.expect(f).toBeGreaterThanOrEqual(prev)
				prev = f
			end
			t.expect(Rewards.qualityFactor(0 / 0)).toBe(0)
			t.expect(Rewards.qualityFactor(500)).toBeCloseTo(1, 1e-9)
		end)
		t.it("XP scales with the rank (Leveling) and boosts; pay with rank, multipliers and lateness", function()
			local base = Rewards.xp(100, 100, Rewards.xpScale(1, Leveling))
			t.expect(base).toBe(100)
			t.expect(Rewards.xp(100, 100, Rewards.xpScale(3, Leveling))).toBeGreaterThan(base)
			t.expect(Rewards.xp(100, 100, Rewards.xpScale(0, Leveling))).toBeLessThan(base)
			t.expect(Rewards.xp(100, 100, 1, 1.25)).toBe(125)
			t.expect(Rewards.xpScale(2, nil)).toBe(Config.rewards.xpScale[2])
			local onTime = Rewards.pay(500, 100, Rewards.payScale(2), 1, true)
			local late = Rewards.pay(500, 100, Rewards.payScale(2), 1, false)
			t.expect(late).toBe(math.floor(onTime * Config.rewards.lateMult + 0.5))
			t.expect(Rewards.pay(500, 100, Rewards.payScale(5), 1, true)).toBeGreaterThan(onTime)
			t.expect(Rewards.pay(500, 100, Rewards.payScale(0), 1, true)).toBeLessThan(onTime)
			t.expect(Rewards.pay(1e9, 100, 1e9, 1e9, true)).toBe(Config.rewards.maxPay)
			t.expect(Rewards.xp(0 / 0, 100, 1)).toBe(0)
		end)
		t.it("pay ratios follow the spec §11 salary scale (Analyst 8k ... MD 45k per hour)", function()
			local ratio = Rewards.payScale(5) / Rewards.payScale(1)
			t.expect(ratio).toBeBetween(45 / 8 * 0.9, 45 / 8 * 1.1)
			t.expect(Rewards.payScale(2) / Rewards.payScale(1)).toBeBetween(15 / 8 * 0.9, 15 / 8 * 1.1)
		end)
		t.it("boost multipliers accept 1.1 or 0.1 and ignore junk", function()
			t.expect(Rewards.boostMult(1.1)).toBeCloseTo(1.1, 1e-9)
			t.expect(Rewards.boostMult(0.1)).toBeCloseTo(1.1, 1e-9)
			t.expect(Rewards.boostMult(nil)).toBe(1)
			t.expect(Rewards.boostMult(-3)).toBe(1)
			t.expect(Rewards.boostMult(99)).toBe(5)
		end)
	end)

	t.describe("timers", function()
		t.it("Speed and the pizza buff stretch the timer; grace adds network slack and Discipline", function()
			t.expect(Rewards.timeLimit(200, 1, 1)).toBe(200)
			t.expect(Rewards.timeLimit(200, 1.2, 1)).toBe(240)
			t.expect(Rewards.timeLimit(200, 0.8, 1.1)).toBe(176)
			t.expect(Rewards.timeLimit(200, 99, 99)).toBe(800)
			local g0 = Rewards.grace(200, 0)
			local g1 = Rewards.grace(200, 0.1)
			t.expect(g0).toBe(Config.timing.graceSeconds)
			t.expect(g1).toBeCloseTo(Config.timing.graceSeconds + 20, 1e-9)
			t.expect(Rewards.onTime(204, 200, g0)).toBe(true)
			t.expect(Rewards.onTime(206, 200, g0)).toBe(false)
			t.expect(Rewards.onTime(0 / 0, 200, g0)).toBe(false)
			t.expect(Rewards.expired(200 * Config.timing.expireMult + 1, 200)).toBe(true)
			t.expect(Rewards.expired(200, 200)).toBe(false)
		end)
		t.it("difficulty ramps through the campus and up the ladder", function()
			local student = Rewards.difficulty({ student = true }, 1)
			local senior = Rewards.difficulty({ student = true }, 8)
			t.expect(senior).toBeGreaterThan(student)
			local analyst = Rewards.difficulty({ rank = 1 }, 9, 9, 24)
			local lateAnalyst = Rewards.difficulty({ rank = 1 }, 24, 9, 24)
			local md = Rewards.difficulty({ rank = 5 }, 60, 55, 70)
			t.expect(lateAnalyst).toBeGreaterThan(analyst)
			t.expect(md).toBeGreaterThan(lateAnalyst)
			t.expect(md).toBeLessThanOrEqual(1)
		end)
	end)

	t.describe("stat effects", function()
		t.it("uses careerCore's Logic/Stats curves, and the local fallback matches them", function()
			for _, v in { 1, 25, 30, 45, 50, 60, 72, 85, 99 } do
				local stats = { speed = v, knowledge = v, skill = v, charisma = v, discipline = v }
				local withStats = Rewards.effects(stats, Stats)
				local fallback = Rewards.effects(stats, nil)
				t.expect(withStats.timerMult).toBeCloseTo(Stats.timerMult(v), 1e-9)
				t.expect(withStats.hints).toBe(Stats.hintCount(v))
				t.expect(withStats.toleranceMult).toBeCloseTo(Stats.toleranceMult(v), 1e-9)
				t.expect(withStats.charismaBonus).toBeCloseTo(Stats.charismaBonus(v), 1e-9)
				t.expect(fallback.timerMult).toBeCloseTo(withStats.timerMult, 1e-6)
				t.expect(fallback.hints).toBe(withStats.hints)
				t.expect(fallback.toleranceMult).toBeCloseTo(withStats.toleranceMult, 1e-6)
				t.expect(fallback.charismaBonus).toBeCloseTo(withStats.charismaBonus, 1e-6)
				t.expect(fallback.deadlineGrace).toBeCloseTo(withStats.deadlineGrace, 1e-6)
			end
		end)
		t.it("a broken Stats module falls back safely", function()
			local broken = {
				timerMult = function()
					error("boom")
				end,
				hintCount = function()
					return 0 / 0
				end,
			}
			local e = Rewards.effects({ speed = 70, knowledge = 90 }, broken)
			t.expect(e.timerMult).toBeCloseTo(1.08, 1e-9)
			t.expect(e.hints).toBe(3)
			local junk = Rewards.effects("nope", nil)
			t.expect(junk.hints).toBe(0)
			t.expect(junk.toleranceMult).toBe(1)
		end)
		t.it("Skill widens fill tolerance: a near miss scores more at toleranceMult 1.5", function()
			local field, sf = Build.fillField("x", "X", 100, { tol = 0.02 })
			local secret = { kind = "fill", fields = { x = sf }, fieldOrder = { "x" } }
			t.expect(field.id).toBe("x")
			local low = Grade.auto(secret, { x = 102.8 }, { toleranceMult = 1 }).quality
			local high = Grade.auto(secret, { x = 102.8 }, { toleranceMult = 1.5 }).quality
			t.expect(high).toBe(100)
			t.expect(low).toBeLessThan(100)
			t.expect(low).toBeGreaterThan(50)
		end)
		t.it("Skill softens false spot flags", function()
			local tbl, secret = Build.spotTable({ "a", "b" }, { { "1", "2" }, { "3", "4" } }, {
				{ cells = { { 1, 1 } }, note = "first" },
				{ cells = { { 2, 2 } }, note = "second" },
			}, 4)
			t.expect(#tbl.rows).toBe(2)
			local answers = { { 1, 1 }, { 2, 2 }, { 1, 2 } }
			local plain = Grade.auto(secret, answers, { toleranceMult = 1 }).quality
			local skilled = Grade.auto(secret, answers, { toleranceMult = 1.5 }).quality
			t.expect(skilled).toBeGreaterThan(plain)
			t.expect(Grade.auto(secret, { { 1, 1 }, { 2, 2 } }, { toleranceMult = 1 }).quality).toBe(100)
		end)
		t.it("Charisma adds up to 8 points on dialogue, only for answered lines", function()
			local rng = Rng.new(1)
			local lines, secret = Build.dialogue(rng, {
				{ text = "a", options = { { text = "good", score = 70 }, { text = "bad", score = 10, note = "n" } } },
				{ text = "b", options = { { text = "good", score = 70 }, { text = "bad", score = 10, note = "n" } } },
			})
			local answers: { [string]: string } = {}
			for _, line in lines do
				for _, opt in line.options do
					if secret.scores[line.id][opt.id] == 70 then
						answers[line.id] = opt.id
					end
				end
			end
			local base = Grade.auto(secret, answers, { charismaBonus = 0 }).quality
			local charming = Grade.auto(secret, answers, { charismaBonus = 8 }).quality
			t.expect(base).toBe(70)
			t.expect(charming).toBe(78)
			t.expect(Grade.auto(secret, {}, { charismaBonus = 8 }).quality).toBe(0)
			local half = { [lines[1].id] = answers[lines[1].id] }
			t.expect(Grade.auto(secret, half, { charismaBonus = 8 }).quality).toBe(39)
		end)
		t.it("Knowledge decides how many hint lines a task shows", function()
			local mod = require(TasksFolder.comps_analysis)
			for _, knowledge in { 10, 40, 70, 90 } do
				local hints = Stats.hintCount(knowledge)
				local payload = mod.generate(Rng.new(4), { difficulty = 0.5, hints = hints })
				local n = if payload.hints then #payload.hints else 0
				t.expect(n).toBe(hints)
			end
		end)
		t.it("perfect answers stay perfect under every stat profile", function()
			local mod = require(TasksFolder.buyer_qa)
			local payload, secret = mod.generate(Rng.new(8), { difficulty = 0.9 })
			t.expect(payload.kind).toBe("dialogue")
			for _, ctx in { { charismaBonus = 0 }, { charismaBonus = 8 }, { toleranceMult = 1.5 } } do
				t.expect(mod.grade(secret, Solve.perfect(secret), ctx).quality).toBe(100)
			end
		end)
	end)
end
