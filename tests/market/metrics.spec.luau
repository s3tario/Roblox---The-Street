-- Window metrics keyed by active seconds: time-weighted returns that ignore flows, the benchmark over the same
-- intervals, returns chained across sessions on different servers, drawdown and volatility, window bounds, idle
-- collapsing, trade/violation counts, and the seasonal Market Skill score.
local Shared = game:GetService("ReplicatedStorage").Shared
local Metrics = require(Shared.Logic.Portfolio.Metrics)

local function s(a: number, e: number, b: number, g: number, n: number?, v: number?)
	return { a = a, e = e, b = b, g = g, n = n or 0, v = v or 0 }
end

return function(t)
	t.describe("window", function()
		t.it("measures return, benchmark, excess and drawdown inside one session", function()
			local samples = { s(0, 100, 1000, 1), s(10, 110, 1050, 1), s(20, 99, 1000, 1) }
			local w = Metrics.window(samples, 0, 100)
			t.expect(w.twr).toBeCloseTo(-0.01, 1e-9)
			t.expect(w.benchReturn).toBeCloseTo(0, 1e-9)
			t.expect(w.excess).toBeCloseTo(-0.01, 1e-9)
			t.expect(w.maxDrawdown).toBeCloseTo(1 - 99 / 110, 1e-9)
			t.expect(w.volatility).toBeCloseTo(math.sqrt(math.log(1.1) ^ 2 + math.log(0.9) ^ 2), 1e-9)
			t.expect(w.active).toBe(20)
			t.expect(w.sessions).toBe(1)
		end)
		t.it("ignores flows: a top-up between segments is not a return", function()
			local samples = {
				s(0, 100, 1000, 1),
				s(10, 110, 1000, 1), -- sampled just before the flow
				s(10, 210, 1000, 2), -- +100 flow starts a new segment
				s(20, 231, 1000, 2),
			}
			local w = Metrics.window(samples, 0, 100)
			t.expect(w.twr).toBeCloseTo(1.1 * 1.1 - 1, 1e-9)
		end)
		t.it("chains sessions on servers with different benchmark levels", function()
			local samples = {
				-- session 1 on server A (ST10 around 1000)
				s(0, 100, 1000, 1),
				s(30, 105, 1100, 1),
				-- session 2 on server B (ST10 around 5000), the book was flattened in between
				s(30, 105, 5000, 2),
				s(60, 94.5, 4500, 2),
			}
			local w = Metrics.window(samples, 0, 60)
			t.expect(w.twr).toBeCloseTo(1.05 * 0.9 - 1, 1e-9)
			t.expect(w.benchReturn).toBeCloseTo(1.1 * 0.9 - 1, 1e-9)
			t.expect(w.excess).toBeCloseTo((1.05 * 0.9) - (1.1 * 0.9), 1e-9)
			t.expect(w.sessions).toBe(2)
		end)
		t.it("chains consecutive windows into the whole", function()
			local samples = {}
			local e, b = 100, 1000
			for i = 0, 40 do
				table.insert(samples, s(i * 10, e, b, 1))
				e *= 1 + (if i % 3 == 0 then 0.02 else -0.005)
				b *= 1 + (if i % 2 == 0 then 0.01 else -0.004)
			end
			local whole = Metrics.window(samples, 0, 400)
			local first = Metrics.window(samples, 0, 200)
			local second = Metrics.window(samples, 200, 400)
			t.expect((1 + first.twr) * (1 + second.twr) - 1).toBeCloseTo(whole.twr, 1e-9)
			t.expect((1 + first.benchReturn) * (1 + second.benchReturn) - 1).toBeCloseTo(whole.benchReturn, 1e-9)
		end)
		t.it("counts trades and violations in the window and uses a live end sample", function()
			local samples = { s(0, 100, 1000, 1, 0, 0), s(10, 101, 1000, 1, 2, 0), s(20, 102, 1000, 1, 3, 1) }
			local w = Metrics.window(samples, 0, 100, s(25, 104, 1010, 1, 5, 1))
			t.expect(w.trades).toBe(5)
			t.expect(w.violations).toBe(1)
			t.expect(w.twr).toBeCloseTo(0.04, 1e-9)
			t.expect(w.benchReturn).toBeCloseTo(0.01, 1e-9)
			local outside = Metrics.window(samples, 15, 100)
			t.expect(outside.pairs).toBe(0)
			t.expect(outside.twr).toBe(0)
		end)
	end)

	t.describe("sampling", function()
		t.it("collapses idle samples but keeps each segment's base", function()
			local log = Metrics.newLog()
			local g = Metrics.newSegment(log)
			Metrics.sample(log, s(100, 100, 1000, g))
			Metrics.sample(log, s(100, 101, 1001, g))
			Metrics.sample(log, s(100, 102, 1002, g))
			Metrics.sample(log, s(100, 103, 1003, g))
			t.expect(#log.samples).toBe(2)
			t.expect(log.samples[1].e).toBe(100)
			t.expect(log.samples[2].e).toBe(103)
			Metrics.sample(log, s(110, 104, 1004, g))
			t.expect(#log.samples).toBe(3)
			for i = 1, Metrics.SAMPLE_MAX + 50 do
				Metrics.sample(log, s(110 + i, 100, 1000, g))
			end
			t.expect(#log.samples).toBe(Metrics.SAMPLE_MAX)
		end)
		t.it("downsamples a segment's equity curve", function()
			local samples = {}
			for i = 1, 200 do
				table.insert(samples, s(i, i, 1000, 7))
			end
			table.insert(samples, s(201, 999, 1000, 8))
			local pts = Metrics.series(samples, 7, 50)
			t.expect(#pts).toBe(50)
			t.expect(pts[1]).toBe(1)
			t.expect(pts[50]).toBe(200)
		end)
		t.it("repairs a malformed log", function()
			local log = Metrics.normalize({ samples = { { a = 1, e = 2, b = 3 }, "junk", { a = "x" } }, seg = -4 })
			t.expect(#log.samples).toBe(1)
			t.expect(log.samples[1].g).toBe(0)
			t.expect(log.seg).toBe(0)
		end)
	end)

	t.describe("Market Skill", function()
		t.it("needs two traded weeks in the season and rewards consistent excess return", function()
			local weeks = {}
			Metrics.recordWeek(weeks, { s = 5, w = 1, at = 0, twr = 0.03, bench = 0.01, excess = 0.02, dd = 0.01, vol = 0.02, trades = 4 })
			t.expect(Metrics.seasonSkill(weeks, 5)).toBeNil()
			Metrics.recordWeek(weeks, { s = 5, w = 2, at = 0, twr = 0, bench = 0, excess = 0, dd = 0, vol = 0, trades = 0 })
			t.expect(Metrics.seasonSkill(weeks, 5)).toBeNil() -- an untraded week doesn't count
			Metrics.recordWeek(weeks, { s = 5, w = 3, at = 0, twr = 0.02, bench = 0, excess = 0.02, dd = 0.08, vol = 0.03, trades = 2 })
			local skill = Metrics.seasonSkill(weeks, 5) :: number
			local expected = math.floor(1000 + 10000 * (0.02 + 0.02 - 0.5 * 0.05) / math.sqrt(2) + 0.5)
			t.expect(skill).toBe(expected)
			t.expect(Metrics.seasonSkill(weeks, 6)).toBeNil()
			for i = 1, 30 do
				Metrics.recordWeek(weeks, { s = 6, w = i, at = 0, twr = -0.5, bench = 0, excess = -0.5, dd = 0.5, vol = 0, trades = 1 })
			end
			t.expect(#weeks).toBe(Metrics.WEEKS_MAX)
			t.expect(Metrics.seasonSkill(weeks, 6)).toBe(0)
		end)
	end)
end
