local Shared = game:GetService("ReplicatedStorage").Shared
local Hash = require(Shared.Util.Hash)
local Rng = require(Shared.Util.Rng)
local Format = require(Shared.Util.Format)
local TableUtil = require(Shared.Util.TableUtil)
local Guard = require(Shared.Guard)
local Time = require(Shared.Util.Time)

return function(t)
	t.describe("Hash", function()
		t.it("is deterministic and separates arguments", function()
			t.expect(Hash.u32("APX", 12)).toBe(Hash.u32("APX", 12))
			t.expect(Hash.u32("ab", "c")).never(Hash.u32("a", "bc"))
			t.expect(Hash.u32(1)).never(Hash.u32(2))
		end)
		t.it("unit() is in [0,1) and roughly uniform", function()
			local buckets = { 0, 0, 0, 0 }
			for i = 1, 4000 do
				local u = Hash.unit("seed", i)
				t.expect(u).toBeBetween(0, 0.9999999)
				local b = math.floor(u * 4) + 1
				buckets[b] += 1
			end
			for _, n in buckets do
				t.expect(n).toBeBetween(850, 1150)
			end
		end)
		t.it("normal() has ~zero mean and ~unit sd", function()
			local s, s2, n = 0, 0, 5000
			for i = 1, n do
				local z = Hash.normal("z", i)
				s += z
				s2 += z * z
			end
			local mean = s / n
			local sd = math.sqrt(s2 / n - mean * mean)
			t.expect(math.abs(mean)).toBeLessThan(0.06)
			t.expect(sd).toBeBetween(0.94, 1.06)
		end)
	end)

	t.describe("Rng", function()
		t.it("reproduces sequences from the same seed", function()
			local a, b = Rng.new(42), Rng.new(42)
			for _ = 1, 50 do
				t.expect(a:next()).toBe(b:next())
			end
			t.expect(Rng.new("x"):next()).never(Rng.new("y"):next())
		end)
		t.it("int() stays in range and hits both ends", function()
			local r = Rng.new(7)
			local seenLo, seenHi = false, false
			for _ = 1, 2000 do
				local v = r:int(1, 6)
				t.expect(v).toBeBetween(1, 6)
				t.expect(v % 1).toBe(0)
				seenLo = seenLo or v == 1
				seenHi = seenHi or v == 6
			end
			t.expect(seenLo and seenHi).toBeTruthy()
		end)
		t.it("weighted() respects weights", function()
			local r = Rng.new(9)
			local counts = { a = 0, b = 0 }
			for _ = 1, 4000 do
				local v = r:weighted({ { "a", 3 }, { "b", 1 } })
				counts[v] += 1
			end
			t.expect(counts.a / 4000).toBeBetween(0.71, 0.79)
		end)
		t.it("state round-trips", function()
			local r = Rng.new(3)
			r:next()
			local copy = Rng.fromState(r:state())
			t.expect(copy:next()).toBe(r:next())
		end)
		t.it("shuffle returns a permutation without mutating input", function()
			local list = { 1, 2, 3, 4, 5, 6 }
			local s = Rng.new(1):shuffle(list)
			t.expect(list).toEqual({ 1, 2, 3, 4, 5, 6 })
			table.sort(s)
			t.expect(s).toEqual(list)
		end)
	end)

	t.describe("Format", function()
		t.it("formats money and percentages", function()
			t.expect(Format.money(1234567)).toBe("$1,234,567")
			t.expect(Format.money(-1500.5, 2)).toBe("-$1,500.50")
			t.expect(Format.money(999)).toBe("$999")
			t.expect(Format.compactMoney(1250000)).toBe("$1.25M")
			t.expect(Format.pct(0.0321)).toBe("+3.21%")
			t.expect(Format.pct(-0.05, 1)).toBe("-5.0%")
			t.expect(Format.clock(245)).toBe("4:05")
			t.expect(Format.clock(3725)).toBe("1:02:05")
		end)
	end)

	t.describe("TableUtil", function()
		t.it("deepFill adds missing keys without overwriting", function()
			local data = { a = 1, nested = { x = 5 } }
			TableUtil.deepFill(data, { a = 9, b = 2, nested = { x = 0, y = 3 }, list = { 1, 2 } })
			t.expect(data).toEqual({ a = 1, b = 2, nested = { x = 5, y = 3 }, list = { 1, 2 } })
		end)
		t.it("deepCopy is independent", function()
			local src = { a = { b = 1 } }
			local c = TableUtil.deepCopy(src)
			c.a.b = 2
			t.expect(src.a.b).toBe(1)
		end)
	end)

	t.describe("Guard", function()
		t.it("rejects NaN, infinity and out-of-range numbers", function()
			t.expect(Guard.num(0 / 0)).toBeNil()
			t.expect(Guard.num(math.huge)).toBeNil()
			t.expect(Guard.int(2.5)).toBeNil()
			t.expect(Guard.int(5, 1, 4)).toBeNil()
			t.expect(Guard.int(3, 1, 4)).toBe(3)
		end)
		t.it("validates ids and strings", function()
			t.expect(Guard.id("pitchbook_format")).toBe("pitchbook_format")
			t.expect(Guard.id("bad id")).toBeNil()
			t.expect(Guard.id(string.rep("a", 65))).toBeNil()
			t.expect(Guard.str("hello", 3)).toBeNil()
			t.expect(Guard.str(5)).toBeNil()
		end)
		t.it("validates maps and lists", function()
			t.expect(Guard.map({ a = 1, b = { c = true } })).toBeTruthy()
			t.expect(Guard.map(setmetatable({}, {}))).toBeNil()
			t.expect(Guard.map({ a = { b = { c = { d = 1 } } } }, 64, 3)).toBeNil()
			t.expect(Guard.list({ 1, 2, 3 }, 5, Guard.int)).toBeTruthy()
			t.expect(Guard.list({ 1, 2, 3 }, 2)).toBeNil()
			t.expect(Guard.list({ a = 1 })).toBeNil()
			t.expect(Guard.oneOf("buy", { "buy", "sell" })).toBe("buy")
			t.expect(Guard.oneOf("hold", { "buy", "sell" })).toBeNil()
		end)
	end)

	t.describe("Time", function()
		t.it("splits seasons and market days", function()
			local s0 = Time.SEASON_EPOCH
			t.expect(Time.season(s0)).toBe(0)
			t.expect(Time.season(s0 + Time.SEASON_LEN)).toBe(1)
			local day, into = Time.dayIndex(s0 + Time.DAY_LEN * 3 + 10)
			t.expect(day).toBe(3)
			t.expect(into).toBe(10)
			t.expect(Time.marketPhase(s0 + 10)).toBe("open")
			t.expect(Time.marketPhase(s0 + 310)).toBe("after")
			t.expect(Time.DAYS_PER_SEASON).toBe(6720)
		end)
	end)
end
