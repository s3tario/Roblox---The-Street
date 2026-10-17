local Shared = game:GetService("ReplicatedStorage").Shared
local Recruiting = require(Shared.Logic.Recruiting)
local Companies = require(Shared.Config.Companies)

local function profile(rarity: string, gpa: number, extra: { [string]: any }?): { [string]: any }
	local p: { [string]: any } = {
		school = { id = "x", rarity = rarity },
		gpa = gpa,
		degree = "bs",
		family = { id = "smith", rarity = "common" },
		stats = { network = 50, charisma = 50 },
		perks = {},
	}
	if extra then
		for k, v in extra do
			p[k] = v
		end
	end
	return p
end

return function(t)
	local mg = Companies.get("mg_freeman")
	local evermoor = Companies.get("evermoor")
	local harrow = Companies.get("harrow_williams")
	local sv = Companies.get("sterling_vance")
	local eastbridge = Companies.get("eastbridge_capital")

	t.describe("eligibility by tier and GPA", function()
		t.it("bulge brackets: Rare+ school or GPA >= 3.6", function()
			t.expect((Recruiting.eligibility(profile("rare", 3.0), mg))).toBeTruthy()
			t.expect((Recruiting.eligibility(profile("common", 3.6), mg))).toBeTruthy()
			local ok, reasons = Recruiting.eligibility(profile("uncommon", 3.59), mg)
			t.expect(ok).toBeFalsy()
			t.expect(reasons[1]).toContain("Rare+ school")
			t.expect(reasons[1]).toContain("3.60")
		end)
		t.it("elite boutiques: Epic+ school, or Rare+ with GPA >= 3.7", function()
			t.expect((Recruiting.eligibility(profile("epic", 2.8), evermoor))).toBeTruthy()
			t.expect((Recruiting.eligibility(profile("rare", 3.7), evermoor))).toBeTruthy()
			t.expect((Recruiting.eligibility(profile("rare", 3.69), evermoor))).toBeFalsy()
			t.expect((Recruiting.eligibility(profile("common", 4.0), evermoor))).toBeFalsy()
		end)
		t.it("middle market: Uncommon+ or GPA >= 3.3", function()
			t.expect((Recruiting.eligibility(profile("uncommon", 2.7), harrow))).toBeTruthy()
			t.expect((Recruiting.eligibility(profile("common", 3.3), harrow))).toBeTruthy()
			t.expect((Recruiting.eligibility(profile("common", 3.29), harrow))).toBeFalsy()
		end)
		t.it("regional: anyone", function()
			t.expect((Recruiting.eligibility(profile("common", 2.7), sv))).toBeTruthy()
			t.expect((Recruiting.eligibility(profile("common", 2.7), eastbridge))).toBeTruthy()
		end)
		t.it("companies that don't hire for the track are never eligible", function()
			local ok, reasons = Recruiting.eligibility(profile("mythic", 4.0), Companies.get("bluestone"), "pe")
			t.expect(ok).toBeFalsy()
			t.expect(#reasons).toBe(1)
		end)
		t.it("accepts a prebuilt candidate", function()
			t.expect((Recruiting.eligibility({ schoolTier = 4, gpa = 3.0 }, evermoor))).toBeTruthy()
		end)
		t.it("eligible() lists every IB firm with reasons", function()
			local list = Recruiting.eligible(profile("common", 3.0), Companies.forTrack("ib"), "ib")
			t.expect(#list).toBe(12)
			local open = 0
			for _, e in list do
				if e.ok then
					open += 1
				end
			end
			t.expect(open).toBe(2) -- only the regional desks
		end)
	end)

	t.describe("offer odds", function()
		t.it("rise monotonically with interview quality", function()
			for _, company in Companies.forTrack("ib") do
				local p = profile("legendary", 3.9)
				local prev = -1
				for q = 0, 100, 2 do
					local chance = Recruiting.offerChance(p, company, q)
					t.expect(chance).toBeGreaterThanOrEqual(prev)
					t.expect(chance).toBeBetween(0, 1)
					prev = chance
				end
			end
		end)
		t.it("stay monotonic with a weak Network stat", function()
			local p = profile("rare", 3.5, { stats = { network = 1 } })
			local prev = -1
			for q = 0, 100 do
				local chance = Recruiting.offerChance(p, mg, q)
				t.expect(chance).toBeGreaterThanOrEqual(prev)
				prev = chance
			end
		end)
		t.it("are zero when not eligible", function()
			t.expect((Recruiting.offerChance(profile("common", 2.9), mg, 100))).toBe(0)
		end)
		t.it("are capped at 95% (except walk-ons)", function()
			local p =
				profile("mythic", 4.0, { family = { rarity = "mythic" }, perks = { ivy_network = 1 }, degree = "ms" })
			t.expect((Recruiting.offerChance(p, eastbridge, 100))).toBeLessThanOrEqual(0.95)
		end)
		t.it("Sterling & Vance always offers a walk-on seat at its Superday bar", function()
			local p = profile("common", 2.7, { stats = { network = 1 } })
			local chance, breakdown = Recruiting.offerChance(p, sv, 40)
			t.expect(chance).toBe(1)
			t.expect(breakdown.walkOn).toBeTruthy()
			t.expect(Recruiting.walkOn(sv, 40)).toBeTruthy()
			t.expect(Recruiting.walkOn(sv, 39)).toBeFalsy()
			t.expect(Recruiting.walkOn(eastbridge, 100)).toBeFalsy()
		end)
		t.it("better schools, families, perks and events help", function()
			local q = 70
			local base = Recruiting.offerChance(profile("rare", 3.5), mg, q)
			t.expect((Recruiting.offerChance(profile("legendary", 3.5), mg, q))).toBeGreaterThan(base)
			t.expect((Recruiting.offerChance(profile("rare", 3.5, { family = { rarity = "legendary" } }), mg, q)))
				.toBeGreaterThan(base)
			t.expect((Recruiting.offerChance(profile("rare", 3.5, { perks = { ivy_network = 1 } }), mg, q)))
				.toBeGreaterThan(base)
			t.expect((Recruiting.offerChance(profile("rare", 3.5), mg, q, { offerBonus = 0.15 }))).toBeGreaterThan(base)
		end)
		t.it("decide compares a uniform draw with the chance", function()
			t.expect(Recruiting.decide(0.3, 0.29)).toBeTruthy()
			t.expect(Recruiting.decide(0.3, 0.3)).toBeFalsy()
		end)
	end)
end
