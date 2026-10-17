local Shared = game:GetService("ReplicatedStorage").Shared
local FitScore = require(Shared.Logic.FitScore)
local Catalog = require(Shared.Config.Catalog)

local items: { [string]: any } = {
	tee = { slot = "top", tier = 1, rarity = "common" },
	shirt = { slot = "top", tier = 3, rarity = "uncommon" },
	jacket = { slot = "outer", tier = 5, rarity = "legendary" },
	trousers = { slot = "bottom", tier = 4, rarity = "rare" },
	loafers = { slot = "shoes", tier = 4, rarity = "rare" },
	sneakers = { slot = "shoes", tier = 1, rarity = "common" },
	watch = { slot = "wrist", tier = 5, rarity = "epic" },
	hidden = { slot = "top", tier = 5, hidden = true },
}
local function get(id: string): any
	return items[id]
end

return function(t)
	t.describe("Outfit Level", function()
		t.it("is the lowest of torso (better of top/outer), bottom and shoes", function()
			local level, parts =
				FitScore.outfitLevel({ top = "tee", outer = "jacket", bottom = "trousers", shoes = "loafers" }, get)
			t.expect(parts.torso).toBe(5)
			t.expect(level).toBe(4)
			local low, lowParts = FitScore.outfitLevel({ top = "shirt", bottom = "trousers", shoes = "sneakers" }, get)
			t.expect(low).toBe(1)
			t.expect(lowParts.lowest).toBe("shoes")
		end)
		t.it("treats empty, unknown, hidden and wrong-slot items as level 1", function()
			t.expect((FitScore.outfitLevel({}, get))).toBe(1)
			t.expect((FitScore.outfitLevel(nil, get))).toBe(1)
			t.expect((FitScore.outfitLevel({ top = "nope", bottom = "trousers", shoes = "loafers" }, get))).toBe(1)
			t.expect((FitScore.outfitLevel({ top = "hidden", bottom = "trousers", shoes = "loafers" }, get))).toBe(1)
			t.expect((FitScore.outfitLevel({ top = "trousers", bottom = "trousers", shoes = "loafers" }, get))).toBe(1)
		end)
		t.it("agrees with the wardrobe catalog's own rule", function()
			local equipped = { top = "base_tee", bottom = "base_trousers", shoes = "base_shoes" }
			t.expect((FitScore.outfitLevel(equipped, Catalog.get))).toBe((Catalog.outfitLevel(equipped)))
			-- every roll look is a real outfit with a sensible level
			for _, look in Catalog.looks do
				local eq: { [string]: string } = {}
				for _, id in look.itemIds do
					local item = Catalog.get(id)
					if item then
						eq[item.slot] = id
					end
				end
				t.expect((FitScore.outfitLevel(eq, Catalog.get))).toBe((Catalog.outfitLevel(eq)))
			end
		end)
	end)

	t.describe("Fit Score", function()
		t.it("is higher for a sharper outfit and stays within 0..100", function()
			local sharp = FitScore.score(
				{ top = "shirt", outer = "jacket", bottom = "trousers", shoes = "loafers", wrist = "watch" },
				get,
				4
			)
			local plain = FitScore.score({ top = "tee", bottom = "trousers", shoes = "sneakers" }, get, 4)
			t.expect(sharp).toBeGreaterThan(plain)
			t.expect(sharp).toBeBetween(0, 100)
			t.expect(plain).toBeBetween(0, 100)
		end)
		t.it("rewards meeting the dress level", function()
			local eq = { top = "shirt", outer = "jacket", bottom = "trousers", shoes = "loafers" }
			local meets, b1 = FitScore.score(eq, get, 4)
			local fails, b2 = FitScore.score(eq, get, 5)
			t.expect(b1.dress).toBe(13)
			t.expect(b2.dress).toBe(0)
			t.expect(meets).toBeGreaterThan(fails)
		end)
	end)

	t.describe("client bonus", function()
		t.it("is 1.0..1.1 and 1.0 when underdressed", function()
			t.expect(FitScore.clientBonus(100, 4, 4)).toBeCloseTo(1.1)
			t.expect(FitScore.clientBonus(0, 4, 4)).toBe(1)
			t.expect(FitScore.clientBonus(100, 2, 4)).toBe(1)
			t.expect(FitScore.clientBonus(0 / 0, 4, 4)).toBe(1)
		end)
		t.it("required level is the higher of the firm minimum and the title's dress level", function()
			t.expect(FitScore.requiredLevel({ minOutfitLevel = 3 }, { rank = 1 })).toBe(3)
			t.expect(FitScore.requiredLevel({ minOutfitLevel = 2 }, { rank = 3 })).toBe(4)
			t.expect(FitScore.requiredLevel(nil, { rank = 5 })).toBe(5)
			t.expect(FitScore.requiredLevel(nil, nil)).toBe(1)
		end)
	end)
end
