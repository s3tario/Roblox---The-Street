local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.LifeRoll)
local Rarity = require(Shared.Config.Rarity)
local Catalog = require(Shared.Config.Catalog)
local LifeRoll = require(Shared.Logic.LifeRoll)
local Rng = require(Shared.Util.Rng)
local TableUtil = require(Shared.Util.TableUtil)

local SCHOOL_IDS = {
	common = { "eastbridge_state", "coastal_cc", "midvale", "riverbend", "pinecrest_state", "union_valley_tech" },
	uncommon = { "lakeshore", "granite_tech", "harborview" },
	rare = { "northfield", "ridgemont" },
	epic = { "kingsbridge", "ashworth" },
	legendary = { "whartonia", "stanfjord" },
	mythic = { "harvale" },
}

local function sumOdds(rows: { any }): number
	local s = 0
	for _, r in rows do
		s += r.odds
	end
	return s
end

return function(t)
	t.describe("Config/LifeRoll", function()
		t.it("has exactly the contract school ids in each tier", function()
			for tier, ids in SCHOOL_IDS do
				local pool = Config.pool("school", tier)
				t.expect(#pool).toBe(#ids)
				for _, id in ids do
					local def = Config.school(id)
					t.expect(def ~= nil).toBeTruthy()
					t.expect((def :: any).rarity).toBe(tier)
					t.expect((def :: any).logo).toBe(id)
				end
			end
			t.expect(#Config.schools).toBe(16)
		end)

		t.it("names the schools as the owner wrote them", function()
			t.expect(Config.school("harvale").name).toBe("Harvale University")
			t.expect(Config.school("kingsbridge").name).toBe("Kingsbridge College")
			t.expect(Config.school("ashworth").name).toBe("Ashworth University")
			t.expect(Config.school("whartonia").name).toBe("Whartonia School of Business")
			t.expect(Config.school("coastal_cc").name).toBe("Coastal Community College")
		end)

		t.it("holds exactly one Mythic option per pool and shrinking pools", function()
			for _, kind in { "school", "family", "club" } do
				t.expect(#Config.pool(kind, "mythic")).toBe(1)
				t.expect(#Config.pool(kind, "common") > #Config.pool(kind, "rare")).toBeTruthy()
				for _, tier in Rarity.ids do
					t.expect(#Config.pool(kind, tier) >= 1).toBeTruthy()
				end
			end
			t.expect(#Catalog.rollPools.mythic).toBe(1)
			t.expect(Config.pool("family", "mythic")[1].name).toBe("Vanderfeller")
		end)

		t.it("gives tier stat boosts: +5 to 0/1/2/3/3 stats, Mythic +8/+5/+5", function()
			local want = { common = 0, uncommon = 1, rare = 2, epic = 3, legendary = 3, mythic = 3 }
			for _, kind in { "school", "club" } do
				for _, tier in Rarity.ids do
					for _, def in Config.pool(kind, tier) do
						t.expect(#def.boosts).toBe(want[tier])
						for _, stat in def.boosts do
							t.expect(Config.stat(stat) ~= nil).toBeTruthy()
						end
						local boosts = LifeRoll.boosts(
							if kind == "school" then { school = { id = def.id } } else { clubs = { { id = def.id } } }
						)
						local total = 0
						for _, n in boosts do
							total += n
						end
						t.expect(total).toBe(if tier == "mythic" then 18 else 5 * want[tier])
					end
				end
			end
		end)

		t.it("carries perks only at Legendary and Mythic; Harvale has two", function()
			for _, kind in { "school", "club" } do
				for _, tier in Rarity.ids do
					for _, def in Config.pool(kind, tier) do
						if Rarity.carriesPerk(tier) then
							t.expect(#def.perks >= 1).toBeTruthy()
						else
							t.expect(#def.perks).toBe(0)
						end
						for _, perkId in def.perks do
							t.expect(Config.perk(perkId) ~= nil).toBeTruthy()
						end
					end
				end
			end
			t.expect(#Config.school("harvale").perks).toBe(2)
			for _, perkId in { "alumni_lifeline", "ivy_network", "legacy_seat", "boardroom_pedigree" } do
				t.expect(Config.perk(perkId) ~= nil).toBeTruthy()
			end
		end)

		t.it("families: the dynasty tiers, cash, connections and existing heirlooms", function()
			local cash = { common = 500, uncommon = 2000, rare = 6000, epic = 10000, legendary = 15000, mythic = 40000 }
			local sizes = { common = 12, uncommon = 4, rare = 3, epic = 2, legendary = 3, mythic = 1 }
			local lastBonus = -1
			for _, tier in Rarity.ids do
				local pool = Config.pool("family", tier)
				t.expect(#pool).toBe(sizes[tier])
				for _, def in pool do
					t.expect(def.cash).toBe(cash[tier])
					if Rarity.atLeast(tier, "rare") then
						t.expect(def.heirloom ~= nil and Catalog.get(def.heirloom) ~= nil).toBeTruthy()
						t.expect(def.heirloom).toBe(Catalog.heirloomFor(tier))
					else
						t.expect(def.heirloom).toBeNil()
					end
				end
				t.expect(pool[1].offerBonus >= lastBonus).toBeTruthy()
				lastBonus = pool[1].offerBonus
			end
			t.expect(Config.family("okafor").name).toBe("Okafor")
			t.expect(Config.family("dumont").name).toBe("DuMont")
		end)

		t.it("has 12 clubs, an archetype for every stat pair and six focus areas", function()
			t.expect(#Config.clubs).toBe(12)
			local ids = Config.STAT_IDS
			t.expect(#ids).toBe(8)
			for i = 1, #ids do
				for j = i + 1, #ids do
					t.expect(Config.archetypeFor(ids[i], ids[j]) ~= nil).toBeTruthy()
					t.expect(Config.archetypeFor(ids[j], ids[i])).toBe(Config.archetypeFor(ids[i], ids[j]))
				end
			end
			t.expect(#Config.focus).toBe(6)
			for _, f in Config.focus do
				t.expect(#f.stats).toBe(2)
			end
		end)

		t.it("fills text placeholders", function()
			t.expect(Config.text("stat_up", { stat = "Skill" })).toBe("+1 Skill")
			t.expect(Config.text("missing_key")).toBe("missing_key")
			t.expect(Config.err("busy")).toBe(Config.strings.err_busy)
			t.expect(Config.err("not_a_key")).toBe(Config.strings.err_generic)
		end)
	end)

	t.describe("Logic/LifeRoll rolling", function()
		t.it("rolls a complete, valid life deterministically from a seed", function()
			local a = LifeRoll.rollAll(Rng.new(77))
			local b = LifeRoll.rollAll(Rng.new(77))
			t.expect(TableUtil.deepEqual(a, b)).toBe(true)
			local n = LifeRoll.normalizeRoll(a)
			t.expect(n ~= nil).toBeTruthy()
			t.expect(TableUtil.deepEqual(n, a)).toBe(true)
		end)

		t.it("every field stays in range over many rolls", function()
			local rng = Rng.new("ranges")
			for _ = 1, 3000 do
				local roll = LifeRoll.rollAll(rng)
				t.expect(LifeRoll.normalizeRoll(roll) ~= nil).toBeTruthy()
				local total = 0
				for _, id in Config.STAT_IDS do
					local v = roll.stats[id]
					t.expect(v).toBeBetween(25, 55)
					total += v
				end
				t.expect(total).toBeBetween(304, 336)
				t.expect(roll.gpa).toBeBetween(2.70, 4.00)
				t.expect(#roll.clubs).toBeBetween(1, 3)
				local seen = {}
				for _, c in roll.clubs do
					t.expect(seen[c.id]).toBeNil()
					seen[c.id] = true
					t.expect(Config.club(c.id).rarity).toBe(c.rarity)
				end
				t.expect(Catalog.looks[roll.outfit.lookId] ~= nil).toBeTruthy()
			end
		end)

		t.it("degree is 80/20 and GPA peaks near 3.45", function()
			local rng = Rng.new("degree-gpa")
			local ms, n = 0, 20000
			local buckets: { [number]: number } = {}
			local sum = 0
			for _ = 1, n do
				if LifeRoll.rollField("degree", rng) == "ms" then
					ms += 1
				end
				local g = LifeRoll.rollField("gpa", rng)
				sum += g
				local b = math.floor((g - 2.7) / 0.1)
				buckets[b] = (buckets[b] or 0) + 1
			end
			t.expect(ms / n).toBeBetween(0.19, 0.21)
			local best, bestCount = -1, -1
			for b, c in buckets do
				if c > bestCount then
					best, bestCount = b, c
				end
			end
			t.expect(2.7 + best * 0.1).toBeBetween(3.3, 3.5)
			t.expect(sum / n).toBeBetween(3.34, 3.44) -- triangle mean (2.70 + 3.45 + 4.00) / 3 = 3.383
		end)

		t.it("school tiers match the disclosed odds within 1% (base and 10 rebirths)", function()
			for _, rebirths in { 0, 10 } do
				local rng = Rng.new("school-odds-" .. rebirths)
				local counts: { [string]: number } = {}
				local n = 100000
				for _ = 1, n do
					local s = LifeRoll.rollField("school", rng, { rebirths = rebirths })
					counts[s.rarity] = (counts[s.rarity] or 0) + 1
				end
				local odds = Rarity.oddsFor(rebirths)
				for _, id in Rarity.ids do
					t.expect(math.abs((counts[id] or 0) / n - odds[id])).toBeLessThan(0.01)
				end
			end
		end)

		t.it("rerollField changes exactly one field", function()
			local rng = Rng.new("reroll")
			for _ = 1, 200 do
				local roll = LifeRoll.rollAll(rng)
				for _, field in LifeRoll.FIELDS do
					local before = LifeRoll.copyRoll(roll)
					local after = LifeRoll.rerollField(roll, field, rng)
					t.expect(TableUtil.deepEqual(roll, before)).toBe(true) -- input untouched
					for _, other in LifeRoll.FIELDS do
						if other ~= field then
							t.expect(TableUtil.deepEqual((after :: any)[other], (before :: any)[other])).toBe(true)
						end
					end
				end
			end
		end)

		t.it("rerolled fields actually re-roll", function()
			local rng = Rng.new("reroll-varies")
			local roll = LifeRoll.rollAll(rng)
			for _, field in { "school", "gpa", "family", "stats", "outfit", "clubs" } do
				local changed = false
				for _ = 1, 40 do
					local after = LifeRoll.rerollField(roll, field, rng)
					if not TableUtil.deepEqual((after :: any)[field], (roll :: any)[field]) then
						changed = true
						break
					end
				end
				t.expect(changed).toBe(true)
			end
		end)

		t.it("rejects tampered stored rolls", function()
			local roll = LifeRoll.rollAll(Rng.new(5)) :: any
			local bad = LifeRoll.copyRoll(roll) :: any
			bad.school = { id = "harvale_fake", rarity = "mythic" }
			t.expect(LifeRoll.normalizeRoll(bad)).toBeNil()
			bad = LifeRoll.copyRoll(roll) :: any
			bad.stats.luck = 99
			t.expect(LifeRoll.normalizeRoll(bad)).toBeNil()
			bad = LifeRoll.copyRoll(roll) :: any
			bad.school.rarity = "mythic" -- the stored rarity is never trusted
			local fixed = LifeRoll.normalizeRoll(bad) :: any
			t.expect(fixed.school.rarity).toBe(Config.school(roll.school.id).rarity)
			t.expect(LifeRoll.normalizeRoll({})).toBeNil()
			t.expect(LifeRoll.normalizeRoll(nil)).toBeNil()
		end)

		t.it("lists Mythic results for the banner", function()
			local roll = LifeRoll.rollAll(Rng.new(9)) :: any
			roll.school = { id = "harvale", rarity = "mythic" }
			local found = LifeRoll.mythics(roll, { "school" })
			t.expect(#found).toBe(1)
			t.expect(found[1].text).toBe("Harvale University")
			roll.school = { id = "midvale", rarity = "common" }
			t.expect(#LifeRoll.mythics(roll, { "school" })).toBe(0)
		end)
	end)

	t.describe("Odds disclosure", function()
		t.it("every field's rows and tiers sum to exactly 1", function()
			for _, rebirths in { 0, 4, 10 } do
				local all = LifeRoll.oddsAll(rebirths)
				for _, field in { "school", "family", "outfit", "degree", "gpa" } do
					t.expect(sumOdds(all[field].rows)).toBeCloseTo(1, 1e-9)
				end
				for _, field in { "school", "family", "outfit", "clubs" } do
					t.expect(sumOdds(all[field].tiers :: any)).toBeCloseTo(1, 1e-9)
				end
				t.expect(sumOdds(all.clubs.counts :: any)).toBeCloseTo(1, 1e-9)
				t.expect(#all.stats.notes >= 1).toBeTruthy()
			end
		end)

		t.it("a school's odds are its tier's odds over the pool size", function()
			local tbl = LifeRoll.odds("school", 0)
			for _, row in tbl.rows do
				if row.id == "harvale" then
					t.expect(row.odds).toBeCloseTo(0.01, 1e-12)
				elseif row.id == "whartonia" then
					t.expect(row.odds).toBeCloseTo(0.02, 1e-12)
				end
			end
		end)

		t.it("GPA band odds match sampling", function()
			local tbl = LifeRoll.odds("gpa", 0)
			local rng = Rng.new("gpa-bands")
			local n = 50000
			local hits = table.create(#tbl.rows, 0)
			local edges = { 2.995, 3.295, 3.595, 3.795, 4.1 }
			for _ = 1, n do
				local g = LifeRoll.rollField("gpa", rng)
				for i, e in edges do
					if g < e then
						hits[i] += 1
						break
					end
				end
			end
			for i, row in tbl.rows do
				t.expect(math.abs(hits[i] / n - row.odds)).toBeLessThan(0.01)
			end
		end)

		t.it("club counts and tiers match sampling", function()
			local rng = Rng.new("clubs")
			local n = 30000
			local counts = { 0, 0, 0 }
			local firstTier: { [string]: number } = {}
			for _ = 1, n do
				local u = rng:next()
				counts[LifeRoll.clubCount(u)] += 1
				local clubs = LifeRoll.rollField("clubs", rng)
				firstTier[clubs[1].rarity] = (firstTier[clubs[1].rarity] or 0) + 1
			end
			for i, p in Config.rules.clubCountOdds do
				t.expect(math.abs(counts[i] / n - p)).toBeLessThan(0.01)
			end
			local odds = Rarity.oddsFor(0)
			for _, id in Rarity.ids do
				t.expect(math.abs((firstTier[id] or 0) / n - odds[id])).toBeLessThan(0.01)
			end
		end)
	end)
end
