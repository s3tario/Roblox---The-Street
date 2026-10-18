local Shared = game:GetService("ReplicatedStorage").Shared
local Rarity = require(Shared.Config.Rarity)
local Rng = require(Shared.Util.Rng)

local SAMPLES = 100000

local function sample(rebirths: number, seed: any): { [string]: number }
	local rng = Rng.new(seed)
	local counts: { [string]: number } = {}
	for _, id in Rarity.ids do
		counts[id] = 0
	end
	for _ = 1, SAMPLES do
		local id = Rarity.pick(rng:next(), rebirths)
		counts[id] += 1
	end
	return counts
end

return function(t)
	t.describe("Rarity tiers", function()
		t.it("has the six v3 tiers in order with base odds 50/25/13/7/4/1", function()
			t.expect(#Rarity.list).toBe(6)
			local expected =
				{ common = 0.50, uncommon = 0.25, rare = 0.13, epic = 0.07, legendary = 0.04, mythic = 0.01 }
			local sum = 0
			for i, def in Rarity.list do
				t.expect(def.id).toBe(Rarity.ids[i])
				t.expect(def.order).toBe(i)
				t.expect(def.odds).toBeCloseTo(expected[def.id], 1e-12)
				t.expect(typeof(def.color)).toBe("Color3")
				sum += def.odds
			end
			t.expect(sum).toBeCloseTo(1, 1e-12)
			t.expect(Rarity.get("mythic").color2 ~= nil).toBeTruthy()
			t.expect(#Rarity.PRISMATIC >= 4).toBeTruthy()
		end)

		t.it("lookups are total for unknown ids", function()
			t.expect(Rarity.get("nope")).toBeNil()
			t.expect(Rarity.order("nope")).toBe(1)
			t.expect(Rarity.name(nil)).toBe("Common")
			t.expect(Rarity.atLeast("legendary", "rare")).toBe(true)
			t.expect(Rarity.atLeast("uncommon", "rare")).toBe(false)
			t.expect(Rarity.carriesPerk("epic")).toBe(false)
			t.expect(Rarity.carriesPerk("legendary")).toBe(true)
			t.expect(Rarity.carriesPerk("mythic")).toBe(true)
		end)

		t.it("boost amounts follow the v3 table", function()
			t.expect(#Rarity.boostAmounts.common).toBe(0)
			t.expect(Rarity.boostAmounts.uncommon).toEqual({ 5 })
			t.expect(Rarity.boostAmounts.rare).toEqual({ 5, 5 })
			t.expect(Rarity.boostAmounts.epic).toEqual({ 5, 5, 5 })
			t.expect(Rarity.boostAmounts.legendary).toEqual({ 5, 5, 5 })
			t.expect(Rarity.boostAmounts.mythic).toEqual({ 8, 5, 5 })
		end)

		t.it("formats exact percentages", function()
			t.expect(Rarity.percent(0.5)).toBe("50%")
			t.expect(Rarity.percent(0.125)).toBe("12.5%")
			t.expect(Rarity.percent(0.0116)).toBe("1.16%")
		end)
	end)

	t.describe("Rebirth luck", function()
		t.it("moves 0.4 points per rebirth from Common, split 40/30/16/10/4, capped at 10", function()
			local base = Rarity.oddsFor(0)
			local one = Rarity.oddsFor(1)
			t.expect(base.common - one.common).toBeCloseTo(0.004, 1e-12)
			t.expect(one.uncommon - base.uncommon).toBeCloseTo(0.0016, 1e-12)
			t.expect(one.rare - base.rare).toBeCloseTo(0.0012, 1e-12)
			t.expect(one.epic - base.epic).toBeCloseTo(0.00064, 1e-12)
			t.expect(one.legendary - base.legendary).toBeCloseTo(0.0004, 1e-12)
			t.expect(one.mythic - base.mythic).toBeCloseTo(0.00016, 1e-12)
			local ten = Rarity.oddsFor(10)
			t.expect(ten.common).toBeCloseTo(0.46, 1e-12)
			t.expect(ten.mythic).toBeCloseTo(0.0116, 1e-12)
			t.expect(Rarity.oddsFor(25)).toEqual(ten)
			t.expect(Rarity.oddsFor(-3)).toEqual(base)
			t.expect(Rarity.oddsFor(0 / 0)).toEqual(base)
			for _, n in { 0, 1, 5, 10, 40 } do
				local sum = 0
				for _, p in Rarity.oddsFor(n) do
					sum += p
				end
				t.expect(sum).toBeCloseTo(1, 1e-12)
			end
		end)

		t.it("oddsList keeps tier order", function()
			local list = Rarity.oddsList(3)
			t.expect(#list).toBe(6)
			t.expect(list[1].id).toBe("common")
			t.expect(list[6].id).toBe("mythic")
		end)
	end)

	t.describe("Sampling (100k draws)", function()
		for _, rebirths in { 0, 10 } do
			t.it(("matches the disclosed odds within 1%% at %d rebirths"):format(rebirths), function()
				local counts = sample(rebirths, "rarity-sample-" .. rebirths)
				local odds = Rarity.oddsFor(rebirths)
				for _, id in Rarity.ids do
					t.expect(math.abs(counts[id] / SAMPLES - odds[id])).toBeLessThan(0.01)
				end
			end)
		end

		t.it("pick handles edge inputs", function()
			t.expect(Rarity.pick(0, 0)).toBe("common")
			t.expect(Rarity.pick(0.4999, 0)).toBe("common")
			t.expect(Rarity.pick(0.5, 0)).toBe("uncommon")
			t.expect(Rarity.pick(0.995, 0)).toBe("mythic")
			t.expect(Rarity.pick(0.9999999, 0)).toBe("mythic")
			t.expect(Rarity.pick(1, 0)).toBe("mythic")
			t.expect(Rarity.pick(0 / 0, 0)).toBe("common")
		end)
	end)
end
