local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.LifeRoll)
local DataTemplate = require(Shared.Config.DataTemplate)
local LifeRoll = require(Shared.Logic.LifeRoll)
local Stats = require(Shared.Logic.Stats)
local Rng = require(Shared.Util.Rng)
local TableUtil = require(Shared.Util.TableUtil)
local DataUtil = require(Shared.Logic.DataUtil)

local function fresh(): any
	return LifeRoll.normalize(TableUtil.deepCopy(DataTemplate.template.profile))
end

-- A pending roll with chosen school / family / clubs (the rest rolled from a seed).
local function rolled(seed: any, school: string?, family: string?, clubs: { string }?): any
	local p = fresh()
	p.firstName = "Maya"
	LifeRoll.startRoll(p, Rng.new(seed))
	if school then
		p.pending.school = { id = school, rarity = Config.school(school).rarity }
	end
	if family then
		p.pending.family = { id = family, rarity = Config.family(family).rarity }
	end
	if clubs then
		local list = {}
		for _, id in clubs do
			table.insert(list, { id = id, rarity = Config.club(id).rarity })
		end
		p.pending.clubs = list
	end
	return p
end

return function(t)
	t.describe("Profile template", function()
		t.it("has every contract field and is saveable", function()
			local p = DataTemplate.template.profile
			for _, key in
				{
					"built",
					"firstName",
					"familyName",
					"school",
					"degree",
					"gpa",
					"family",
					"clubs",
					"perks",
					"stats",
					"statXp",
					"ovr",
					"archetype",
					"focus",
					"outfitRoll",
					"rerollsLeft",
					"refreshTokens",
					"credits",
					"rebirths",
					"incomeMult",
					"pending",
				}
			do
				t.expect(p[key] ~= nil).toBeTruthy()
			end
			t.expect(p.rerollsLeft).toBe(3)
			t.expect(p.rebirths).toBe(0)
			t.expect(p.incomeMult).toBe(1)
			local _, issues = DataUtil.toSaveable({ profile = p })
			t.expect(#issues).toBe(0)
		end)
	end)

	t.describe("Life Roll flow", function()
		t.it("validates first names", function()
			t.expect((LifeRoll.validName("maya"))).toBe("Maya")
			t.expect((LifeRoll.validName("  Mary   Kate "))).toBe("Mary Kate")
			t.expect((LifeRoll.validName("O'Neil"))).toBe("O'Neil")
			t.expect((LifeRoll.validName("Jean-Luc"))).toBe("Jean-Luc")
			for _, bad in { "", "a", "M4ya", "Ma--ya", "-Maya", "Abcdefghijklmnopq", "Maya!", 12 } do
				t.expect((LifeRoll.validName(bad))).toBeNil()
			end
			local _, err = LifeRoll.validName("   ")
			t.expect(err).toBe("no_name")
		end)

		t.it("starts a roll once with 3 rerolls (+1 with a Legacy Seat)", function()
			local p = fresh()
			t.expect(LifeRoll.startRoll(p, Rng.new(1))).toBe(true)
			t.expect(p.rerollsLeft).toBe(3)
			local pending = TableUtil.deepCopy(p.pending)
			t.expect(LifeRoll.startRoll(p, Rng.new(2))).toBe(false) -- no free re-roll by starting again
			t.expect(TableUtil.deepEqual(p.pending, pending)).toBe(true)
			local q = fresh()
			q.legacySeat = true
			LifeRoll.startRoll(q, Rng.new(1))
			t.expect(q.rerollsLeft).toBe(4)
		end)

		t.it("spends free rerolls, then tokens, then credits, then asks for a purchase", function()
			local p = rolled(3)
			p.refreshTokens = 1
			p.credits.reroll = 1
			local rng = Rng.new(4)
			local sources = {}
			for _ = 1, 5 do
				local ok, _, source = LifeRoll.reroll(p, "gpa", rng)
				t.expect(ok).toBe(true)
				table.insert(sources, source)
			end
			t.expect(sources).toEqual({ "free", "free", "free", "token", "credit" })
			local ok, err = LifeRoll.reroll(p, "gpa", rng)
			t.expect(ok).toBe(false)
			t.expect(err).toBe("needs_purchase")
			t.expect(p.rerollsLeft).toBe(0)
			t.expect(p.refreshTokens).toBe(0)
			t.expect(p.credits.reroll).toBe(0)
		end)

		t.it("a reroll changes only the chosen pending field", function()
			local p = rolled(5)
			local before = TableUtil.deepCopy(p.pending)
			local ok = LifeRoll.reroll(p, "family", Rng.new(6))
			t.expect(ok).toBe(true)
			for _, field in LifeRoll.FIELDS do
				if field ~= "family" then
					t.expect(TableUtil.deepEqual(p.pending[field], before[field])).toBe(true)
				end
			end
			t.expect((LifeRoll.reroll(p, "nonsense", Rng.new(1)))).toBe(false)
		end)

		t.it("lock applies base stats + boosts, perks, cash and the outfit", function()
			local p = rolled(7, "harvale", "vanderfeller", { "golf_team", "finance_club" })
			p.pending.degree = "ms"
			local base = table.clone(p.pending.stats)
			local result, err = LifeRoll.lock(p, 1_800_000_000)
			t.expect(err).toBeNil()
			assert(result)
			t.expect(p.built).toBe(true)
			t.expect(p.familyName).toBe("Vanderfeller")
			t.expect(p.school.id).toBe("harvale")
			t.expect(result.startCash).toBe(40000)
			t.expect(result.heirloom).toBe("heirloom_vanderfeller_crest_blazer")
			t.expect(p.cashPaid).toBe(false)
			t.expect(#result.mythics >= 3).toBeTruthy() -- school, family, Golf Team
			-- Harvale: network +8, knowledge +5, charisma +5; Golf Team: network +8, charisma +5, luck +5;
			-- Finance Club: knowledge +5; Master's: knowledge +5; Vanderfeller: network +7
			t.expect(p.stats.network).toBe(math.min(99, base.network + 8 + 8 + 7))
			t.expect(p.stats.knowledge).toBe(base.knowledge + 5 + 5 + 5)
			t.expect(p.stats.charisma).toBe(base.charisma + 5 + 5)
			t.expect(p.stats.luck).toBe(base.luck + 5)
			t.expect(p.stats.speed).toBe(base.speed)
			t.expect(p.perks.ivy_network).toBe(1)
			t.expect(p.perks.legacy_seat).toBe(1)
			t.expect(p.perks.alumni_lifeline).toBe(1)
			t.expect(p.legacySeat).toBe(true)
			t.expect(p.ovr).toBe(Stats.ovr(p.stats))
			t.expect(p.archetype).toBe(Stats.archetype(p.stats).id)
			t.expect(p.outfitRoll.lookId ~= "").toBeTruthy()
			t.expect(next(p.pending)).toBeNil()
			local again = LifeRoll.lock(p, 1)
			t.expect(again).toBeNil()
		end)

		t.it("a Common life has no perks and the plain starting cash", function()
			local p = rolled(8, "midvale", "smith", { "debate_team" })
			p.pending.degree = "bs"
			local result = LifeRoll.lock(p, 1) :: any
			t.expect(next(p.perks)).toBeNil()
			t.expect(result.startCash).toBe(500)
			t.expect(result.heirloom).toBeNil()
			for _, id in Config.STAT_IDS do
				t.expect(p.stats[id]).toBe(p.baseStats[id])
			end
		end)

		t.it("refuses to lock without a name or a roll", function()
			local p = fresh()
			t.expect(select(2, LifeRoll.lock(p, 1))).toBe("no_roll")
			LifeRoll.startRoll(p, Rng.new(1))
			t.expect(select(2, LifeRoll.lock(p, 1))).toBe("no_name")
		end)
	end)

	t.describe("After lock-in", function()
		t.it("consumes the Alumni Lifeline exactly as many times as it was granted", function()
			local p = rolled(9, "stanfjord", "smith", { "golf_team" })
			LifeRoll.lock(p, 1)
			t.expect(p.perks.alumni_lifeline).toBe(2) -- Stanfjord and the Golf Team each grant one
			t.expect(LifeRoll.hasPerk(p, "alumni_lifeline")).toBe(true)
			t.expect(LifeRoll.consumePerk(p, "alumni_lifeline")).toBe(true)
			t.expect(LifeRoll.consumePerk(p, "alumni_lifeline")).toBe(true)
			t.expect(LifeRoll.consumePerk(p, "alumni_lifeline")).toBe(false)
			t.expect(LifeRoll.hasPerk(p, "alumni_lifeline")).toBe(false)
			t.expect(p.perks.alumni_lifeline).toBeNil()
			LifeRoll.recompute(p) -- used lifelines stay used
			t.expect(LifeRoll.hasPerk(p, "alumni_lifeline")).toBe(false)
			t.expect(LifeRoll.consumePerk(p, "ivy_network")).toBe(false)
		end)

		t.it("school tier order adds one for Boardroom Pedigree, capped at Mythic", function()
			local p = rolled(10, "midvale", "smith", { "debate_team" })
			t.expect(LifeRoll.schoolTierOrder(p)).toBe(1) -- not locked yet
			LifeRoll.lock(p, 1)
			t.expect(LifeRoll.schoolTierOrder(p)).toBe(1)
			local q = rolled(11, "northfield", "smith", { "student_government" })
			LifeRoll.lock(q, 1)
			t.expect(LifeRoll.schoolTierOrder(q)).toBe(4) -- Rare + pedigree
			local r = rolled(12, "harvale", "smith", { "student_government" })
			LifeRoll.lock(r, 1)
			t.expect(LifeRoll.schoolTierOrder(r)).toBe(6)
		end)

		t.it("income multiplier is 1 + 0.1 per rebirth, capped at 3", function()
			t.expect(LifeRoll.incomeMult(0)).toBeCloseTo(1)
			t.expect(LifeRoll.incomeMult(1)).toBeCloseTo(1.1)
			t.expect(LifeRoll.incomeMult(7)).toBeCloseTo(1.7)
			t.expect(LifeRoll.incomeMult(50)).toBeCloseTo(3)
			t.expect(LifeRoll.incomeMult(nil)).toBeCloseTo(1)
		end)

		t.it("focus: first pick is free, then one change per week", function()
			local p = rolled(13)
			t.expect(select(2, LifeRoll.setFocus(p, "modeling", "w1"))).toBe("not_built")
			LifeRoll.lock(p, 1)
			t.expect(select(2, LifeRoll.setFocus(p, "nope", "w1"))).toBe("bad_focus")
			t.expect((LifeRoll.setFocus(p, "modeling", "w1"))).toBe(true)
			t.expect(LifeRoll.canChangeFocus(p, "w1")).toBe(true)
			t.expect((LifeRoll.setFocus(p, "markets", "w1"))).toBe(true)
			t.expect(LifeRoll.canChangeFocus(p, "w1")).toBe(false)
			t.expect(select(2, LifeRoll.setFocus(p, "client", "w1"))).toBe("focus_locked")
			t.expect((LifeRoll.setFocus(p, "markets", "w1"))).toBe(true) -- same focus is a no-op
			t.expect((LifeRoll.setFocus(p, "client", "w2"))).toBe(true)
			t.expect(p.focus).toBe("client")
		end)

		t.it("week keys follow the career week, or 40 active minutes on campus", function()
			t.expect(LifeRoll.weekKey(12, 99999)).toBe("w12")
			t.expect(LifeRoll.weekKey(0, 0)).toBe("c0")
			t.expect(LifeRoll.weekKey(0, 2400 * 3 + 5)).toBe("c3")
		end)

		t.it("rebuild swaps within the same rarity only and keeps growth", function()
			local p = rolled(14, "northfield", "vandermont", { "investment_society", "finance_club" })
			LifeRoll.lock(p, 1)
			p.growth.speed = 4
			LifeRoll.recompute(p)
			local speed = p.stats.speed
			local opts = LifeRoll.rebuildOptions(p)
			t.expect(table.find(opts.school, "ridgemont") ~= nil).toBeTruthy()
			t.expect(table.find(opts.school, "harvale")).toBeNil()
			t.expect(table.find(opts.clubs[1], "finance_club")).toBeNil() -- can't duplicate another club
			t.expect(select(2, LifeRoll.rebuild(p, { school = "harvale" }))).toBe("bad_rebuild")
			t.expect(select(2, LifeRoll.rebuild(p, { clubs = { [2] = "golf_team" } }))).toBe("bad_rebuild")
			t.expect(select(2, LifeRoll.rebuild(p, {}))).toBe("no_change")
			local ok =
				LifeRoll.rebuild(p, { school = "ridgemont", family = "dumont", clubs = { [2] = "trading_club" } })
			t.expect(ok).toBe(true)
			t.expect(p.school.id).toBe("ridgemont")
			t.expect(p.familyName).toBe("DuMont")
			t.expect(p.clubs[2].id).toBe("trading_club")
			t.expect(p.stats.speed).toBe(speed) -- growth survives (neither school boosts speed)
			t.expect(p.stats.risk).toBe(math.min(99, p.baseStats.risk + 5 + 5)) -- Ridgemont + Trading Club
		end)

		t.it("normalize repairs bad types and derives a missing base package", function()
			local p = rolled(15, "lakeshore", "smith", { "debate_team" })
			LifeRoll.lock(p, 1)
			local shown = table.clone(p.stats)
			p.baseStats = {}
			p.credits = "lots"
			p.rerollsLeft = -4
			p.focus = "nonsense"
			LifeRoll.normalize(p)
			t.expect(p.credits.reroll).toBe(0)
			t.expect(p.rerollsLeft).toBe(0)
			t.expect(p.focus).toBe("")
			t.expect(TableUtil.deepEqual(p.stats, shown)).toBe(true)
		end)

		t.it("public view carries the profile card fields", function()
			local p = rolled(16, "whartonia", "kennerly", { "quant_society" })
			LifeRoll.lock(p, 1)
			Stats.award(p, { "skill" }, 100, "review", "w1")
			local v = LifeRoll.publicView(p, { userId = 7, displayName = "maya_7" })
			t.expect(v.fullName).toBe("Maya Kennerly")
			t.expect((v.school :: any).name).toBe("Whartonia School of Business")
			t.expect((v.school :: any).rarity).toBe("legendary")
			t.expect((v.family :: any).name).toBe("Kennerly")
			t.expect(#v.clubs).toBe(1)
			t.expect(v.ovr).toBe(Stats.ovr(p.stats))
			t.expect(#v.perks).toBe(1)
			t.expect(v.perks[1].id).toBe("ivy_network")
			t.expect(v.userId).toBe(7)
			local unbuilt = LifeRoll.publicView(fresh(), { displayName = "guest" })
			t.expect(unbuilt.built).toBe(false)
			t.expect(unbuilt.school).toBeNil()
			t.expect(unbuilt.fullName).toBe("guest")
		end)
	end)
end
