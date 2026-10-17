local Shared = game:GetService("ReplicatedStorage").Shared
local Promotion = require(Shared.Logic.Promotion)
local Tracks = require(Shared.Config.Tracks)

local function ready(rank: number): { [string]: any }
	local role = Tracks.rankDef("ib", rank) :: Tracks.RoleDef
	local nextRole = Tracks.rankDef("ib", rank + 1) :: Tracks.RoleDef
	return {
		trackId = "ib",
		rank = rank,
		level = role.maxLevel,
		coreDone = role.coreToPromote or 0,
		band = "on_track",
		outfitLevel = 5,
		schoolTier = 6,
		ovr = nextRole.minOvr,
	}
end

local function only(result: Promotion.Result): string
	return table.concat(result.missingIds, ",")
end

return function(t)
	t.describe("requirements", function()
		t.it("passes when every requirement is met", function()
			for rank = 1, 4 do
				local r = Promotion.evaluate(ready(rank) :: any)
				t.expect(r.ready).toBeTruthy()
				t.expect(#r.missing).toBe(0)
			end
		end)
		t.it("reports the level cap", function()
			local input = ready(1)
			input.level = 20
			local r = Promotion.evaluate(input :: any)
			t.expect(r.ready).toBeFalsy()
			t.expect(only(r)).toBe("level")
			t.expect(r.missing[1]).toContain("Reach Level 24")
		end)
		t.it("reports missing core work", function()
			local input = ready(1)
			input.coreDone = 3
			local r = Promotion.evaluate(input :: any)
			t.expect(only(r)).toBe("core")
			t.expect(r.missing[1]).toContain("(3/12)")
		end)
		t.it("reports a weak score at the review", function()
			local input = ready(1)
			input.band = "under"
			local r = Promotion.evaluate(input :: any)
			t.expect(only(r)).toBe("score")
			t.expect(r.missing[1]).toContain("On track")
		end)
		t.it("reports the outfit level for the new title (min(5, rank + 1))", function()
			local input = ready(2) -- Associate -> VP needs Outfit Level 4
			input.outfitLevel = 3
			local r = Promotion.evaluate(input :: any)
			t.expect(only(r)).toBe("outfit")
			t.expect(r.needOutfit).toBe(4)
			t.expect(r.missing[1]).toContain("Come back dressed for the role")
			local md = ready(4)
			md.outfitLevel = 4
			t.expect(Promotion.evaluate(md :: any).needOutfit).toBe(5)
		end)
		t.it("reports the Managing Director school gate in plain words", function()
			local input = ready(4)
			input.schoolTier = 2
			local r = Promotion.evaluate(input :: any)
			t.expect(only(r)).toBe("school")
			t.expect(r.missing[1])
				.toBe("Managing Director requires a Rare+ school. Rebirth (coming soon) lets you reroll your school.")
			input.schoolTier = 3
			t.expect(Promotion.evaluate(input :: any).ready).toBeTruthy()
		end)
		t.it("reports the minimum OVR and skips it when unknown", function()
			local input = ready(3)
			input.ovr = 20
			local r = Promotion.evaluate(input :: any)
			t.expect(only(r)).toBe("ovr")
			input.ovr = nil
			t.expect(Promotion.evaluate(input :: any).ready).toBeTruthy()
		end)
		t.it("lists several missing requirements at once", function()
			local input = ready(4)
			input.level = 55
			input.outfitLevel = 2
			input.schoolTier = 1
			local r = Promotion.evaluate(input :: any)
			t.expect(only(r)).toBe("level,outfit,school")
			t.expect(Promotion.blocker(r)).toBe("outfit")
		end)
	end)

	t.describe("fast track", function()
		t.it("a Star review cuts the level and core requirements by 20%", function()
			local role = Tracks.rankDef("ib", 1) :: Tracks.RoleDef
			local input = ready(1)
			input.band = "star"
			input.level = Promotion.needLevel(role, true)
			input.coreDone = Promotion.needCore(role, true)
			local r = Promotion.evaluate(input :: any)
			t.expect(r.fastTrack).toBeTruthy()
			t.expect(r.ready).toBeTruthy()
			t.expect(r.needLevel).toBeLessThan(role.maxLevel)
			t.expect(r.needCore).toBe(math.ceil((role.coreToPromote :: number) * 0.8))
			input.band = "on_track"
			t.expect(Promotion.evaluate(input :: any).ready).toBeFalsy()
		end)
	end)

	t.describe("live checklist", function()
		t.it("leaves the score pending until the review", function()
			local input = ready(1)
			input.band = nil
			local r = Promotion.evaluate(input :: any)
			t.expect(r.ready).toBeTruthy()
			local scoreItem = nil
			for _, item in r.items do
				if item.id == "score" then
					scoreItem = item
				end
			end
			t.expect(scoreItem).toBeTruthy()
			t.expect((scoreItem :: any).pending).toBeTruthy()
			t.expect(r.headline).toContain("Ready for promotion to Associate")
		end)
		t.it("is not applicable to students and reports the top of the ladder", function()
			t.expect(Promotion.evaluate({ trackId = "ib", rank = 0, level = 3 }).applicable).toBeFalsy()
			local top = Promotion.evaluate({ trackId = "ib", rank = 5, level = 80 })
			t.expect(top.top).toBeTruthy()
			t.expect(top.ready).toBeFalsy()
		end)
		t.it("only the last rank carries a school gate on the IB ladder", function()
			for rank = 1, 3 do
				local input = ready(rank)
				input.schoolTier = 1
				t.expect(Promotion.evaluate(input :: any).ready).toBeTruthy()
			end
		end)
	end)
end
