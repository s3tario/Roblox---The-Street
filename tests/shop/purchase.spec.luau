-- Purchase validation (Logic/Economy/Purchase): rank, pass, owned, afford, discount, clothing level and which shop
-- sells what. Every shop item in the catalogue is listed by at least one shop tab.

local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Logic.Economy)
local Shop = require(Shared.Config.Shop)
local Decor = require(Shared.Config.Decor)
local Catalog = require(Shared.Config.Catalog)
local Purchase = Economy.Purchase

local function viewer(over: { [string]: any }?): Purchase.Viewer
	local v: { [string]: any } = { owned = {}, decor = {}, rank = 1, passes = {}, cash = 1000000 }
	for k, x in over or {} do
		v[k] = x
	end
	return v :: any
end

return function(t)
	t.describe("resolve", function()
		t.it("finds wearables and decor, hides NPC pieces and junk", function()
			t.expect((Purchase.resolve("suit_navy_2b"))).toBe("wearable")
			t.expect((Purchase.resolve("desk_mug_navy"))).toBe("decor")
			t.expect((Purchase.resolve("base_tee"))).toBeNil() -- hidden NPC/base piece
			t.expect((Purchase.resolve("nope"))).toBeNil()
			t.expect((Purchase.resolve(42))).toBeNil()
			t.expect((Purchase.resolve(string.rep("a", 80)))).toBeNil()
		end)
	end)

	t.describe("discount and price", function()
		t.it("reads a fraction off, a multiplier, and neutral values", function()
			t.expect(Purchase.discount(0.25)).toBeCloseTo(0.25)
			t.expect(Purchase.discount(0.75)).toBeCloseTo(0.25) -- multiplier style
			t.expect(Purchase.discount(1)).toBe(0)
			t.expect(Purchase.discount(0)).toBe(0)
			t.expect(Purchase.discount(-0.3)).toBe(0)
			t.expect(Purchase.discount(0 / 0)).toBe(0)
			t.expect(Purchase.discount(nil)).toBe(0)
			t.expect(Purchase.discount(5)).toBe(0)
			t.expect(Purchase.discount(0.55)).toBeLessThanOrEqual(Shop.economy.maxDiscount)
		end)
		t.it("rounds to whole dollars and never makes a priced item free", function()
			t.expect(Purchase.price(1500, 0.25)).toBe(1125)
			t.expect(Purchase.price(1500, 0)).toBe(1500)
			t.expect(Purchase.price(1, 0.5)).toBe(1)
			t.expect(Purchase.price(0, 0.25)).toBe(0)
			t.expect(Purchase.price(1000, 0.9)).toBe(1000 - 1000 * Shop.economy.maxDiscount)
		end)
	end)

	t.describe("quote", function()
		t.it("accepts an affordable cash item and fills the quote", function()
			local q = Purchase.quote("suit_navy_2b", "tailor", viewer(), 0)
			t.expect(q.ok).toBe(true)
			t.expect(q.kind).toBe("wearable")
			t.expect(q.price).toBe(1500)
			t.expect(q.level).toBe(3)
			t.expect(q.shopId).toBe("tailor")
		end)
		t.it("defaults the shop to the first one that sells it", function()
			local q = Purchase.quote("watch_meridian_steel", nil, viewer(), 0)
			t.expect(q.ok).toBe(true)
			t.expect(q.shopId).toBe("watch")
		end)
		t.it("applies the discount", function()
			local q = Purchase.quote("suit_navy_2b", "tailor", viewer(), 0.25)
			t.expect(q.ok).toBe(true)
			t.expect(q.basePrice).toBe(1500)
			t.expect(q.price).toBe(1125)
		end)
		t.it("refuses a shop that doesn't sell the item", function()
			t.expect(Purchase.quote("suit_navy_2b", "watch", viewer(), 0).err).toBe("bad_shop")
			t.expect(Purchase.quote("desk_mug_navy", "tailor", viewer(), 0).err).toBe("bad_shop")
			t.expect(Purchase.quote("suit_navy_2b", "nowhere", viewer(), 0).err).toBe("bad_shop")
		end)
		t.it("refuses unknown and exclusive items", function()
			t.expect(Purchase.quote("nope", nil, viewer(), 0).err).toBe("unknown_item")
			t.expect(Purchase.quote("kk_tee_black", nil, viewer(), 0).err).toBe("roll")
			t.expect(Purchase.quote("heirloom_family_watch", nil, viewer(), 0).err).toBe("heirloom")
		end)
		t.it("refuses what the player already owns (including starter pieces)", function()
			t.expect(Purchase.quote("suit_navy_2b", nil, viewer({ owned = { suit_navy_2b = true } }), 0).err)
				.toBe("owned")
			t.expect(Purchase.quote("hoodie_heather", nil, viewer(), 0).err).toBe("owned") -- student starter
			t.expect(Purchase.quote("desk_mug_navy", nil, viewer({ decor = { desk_mug_navy = true } }), 0).err)
				.toBe("owned")
		end)
		t.it("pass items can't be bought with cash", function()
			t.expect(Purchase.quote("co_velvet_dinner", nil, viewer(), 0).err).toBe("pass")
			t.expect(Purchase.quote("co_velvet_dinner", nil, viewer({ passes = { CornerOffice = true } }), 0).err)
				.toBe("owned")
		end)
		t.it("enforces the rank gate", function()
			t.expect(Purchase.quote("suit_pinstripe_2b", nil, viewer({ rank = 1 }), 0).err).toBe("rank")
			t.expect(Purchase.quote("suit_pinstripe_2b", nil, viewer({ rank = 2 }), 0).ok).toBe(true)
			t.expect(Purchase.quote("desk_bull_bear", nil, viewer({ rank = 1 }), 0).err).toBe("rank")
			t.expect(Purchase.quote("desk_bull_bear", nil, viewer({ rank = 2 }), 0).ok).toBe(true)
		end)
		t.it("needs the cash (after the discount)", function()
			t.expect(Purchase.quote("suit_navy_2b", nil, viewer({ cash = 1499 }), 0).err).toBe("funds")
			t.expect(Purchase.quote("suit_navy_2b", nil, viewer({ cash = 1500 }), 0).ok).toBe(true)
			t.expect(Purchase.quote("suit_navy_2b", nil, viewer({ cash = 1125 }), 0.25).ok).toBe(true)
			t.expect(Purchase.quote("suit_navy_2b", nil, viewer({ cash = 1124 }), 0.25).err).toBe("funds")
			t.expect(Purchase.quote("suit_navy_2b", nil, viewer({ cash = 0 / 0 }), 0).err).toBe("funds")
		end)
		t.it("checks rank before money", function()
			t.expect(Purchase.quote("suit_pinstripe_2b", nil, viewer({ rank = 0, cash = 0 }), 0).err).toBe("rank")
		end)
	end)

	t.describe("clothing levels and the dress-code hint", function()
		t.it("wearables carry their catalogue tier as a level; decor has none", function()
			t.expect(Purchase.levelOf("wearable", Catalog.get("suit_navy_2b"))).toBe(3)
			t.expect(Purchase.levelOf("wearable", Catalog.get("bespoke_midnight_2b"))).toBe(5)
			t.expect(Purchase.levelOf("decor", Decor.get("desk_mug_navy"))).toBeNil()
		end)
		t.it("tells employees their firm's level, and students the Street's usual bar", function()
			local key, vars = Purchase.levelHint(4, 3, false)
			t.expect(key).toBe("dress_firm_short")
			t.expect(vars.level).toBe(4)
			t.expect(vars.current).toBe(3)
			t.expect((Purchase.levelHint(3, 4, false))).toBe("dress_firm_ok")
			local skey, svars = Purchase.levelHint(nil, 1, true)
			t.expect(skey).toBe("dress_student")
			t.expect(svars.level).toBe(Shop.STUDENT_TARGET_LEVEL)
			t.expect((Purchase.levelHint(nil, 2, false))).toBeNil()
		end)
		t.it("the hint text reads 'Your firm requires Level N'", function()
			t.expect(Shop.text("dress_firm", { level = 4 })).toBe("Your firm requires Level 4")
			local key, vars = Purchase.levelHint(4, 2, false)
			t.expect(string.find(Shop.text(key :: string, vars), "Your firm requires Level 4", 1, true)).toBe(1)
		end)
	end)

	t.describe("shop stock", function()
		t.it("every shop item in the catalogue is listed by some shop tab", function()
			for _, item in Catalog.shopItems() do
				local listed = false
				for _, shopId in Purchase.shopsFor("wearable", item) do
					local shop = Shop.get(shopId) :: Shop.ShopDef
					for _, tab in shop.tabs do
						if Purchase.inTab(tab, "wearable", item) then
							listed = true
						end
					end
				end
				if not listed then
					error("not listed in any shop tab: " .. item.id)
				end
			end
		end)
		t.it("every decor item is listed by a decor tab", function()
			local shop = Shop.get("decor") :: Shop.ShopDef
			for _, item in Decor.list() do
				local listed = false
				for _, tab in shop.tabs do
					if Purchase.inTab(tab, "decor", item) then
						listed = true
					end
				end
				if not listed then
					error("decor not listed: " .. item.id)
				end
			end
		end)
		t.it("campus wear sells at the campus store, suits at the tailor", function()
			t.expect(table.find(Purchase.shopsFor("wearable", Catalog.get("crewneck_oatmeal")), "campus_store"))
				.toBeTruthy()
			t.expect(table.find(Purchase.shopsFor("wearable", Catalog.get("suit_navy_2b")), "tailor")).toBeTruthy()
			t.expect(table.find(Purchase.shopsFor("wearable", Catalog.get("suit_navy_2b")), "campus_store")).toBeNil()
		end)
		t.it("listFor sorts wearables by level then price and filters by tab", function()
			local list = Purchase.listFor("tailor", "jackets")
			t.expect(#list).toBeGreaterThan(5)
			for i = 2, #list do
				local a, b = list[i - 1].item, list[i].item
				t.expect(a.slot).toBe("outer")
				t.expect(a.tier <= b.tier).toBe(true)
				if a.tier == b.tier then
					t.expect(a.price <= b.price).toBe(true)
				end
			end
			t.expect(#Purchase.listFor("decor", "desk")).toBe(#Decor.byCategory("desk"))
			t.expect(#Purchase.listFor("tailor", "nope")).toBe(0)
			t.expect(#Purchase.listFor("nope")).toBe(0)
		end)
	end)
end
