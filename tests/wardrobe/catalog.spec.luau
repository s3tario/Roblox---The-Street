local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Config.Catalog)
local Wardrobe = require(Shared.Assets.Wardrobe)
local Hair = require(Shared.Assets.Npc.Hair)
local Body = require(Shared.Assets.Npc.Body)

local function isHex(s: any): boolean
	return type(s) == "string" and string.match(s, "^#%x%x%x%x%x%x$") ~= nil
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

return function(t)
	t.describe("Catalog items", function()
		t.it("every item has a valid slot, builder, price, currency, colours and tier", function()
			for id, item in Catalog.items do
				local function fail(msg: string)
					error(("%s: %s"):format(id, msg))
				end
				if item.id ~= id then
					fail("id mismatch")
				end
				if not Catalog.SLOT_SET[item.slot] then
					fail("bad slot " .. tostring(item.slot))
				end
				if not Wardrobe.hasBuilder(item.builder) then
					fail("unknown builder " .. tostring(item.builder))
				end
				if type(item.price) ~= "number" or item.price < 0 or item.price ~= math.floor(item.price) then
					fail("bad price")
				end
				if not Catalog.CURRENCIES[item.currency] then
					fail("bad currency")
				end
				local brand = Catalog.brand(item.brand)
				if not brand then
					fail("unknown brand " .. tostring(item.brand))
				end
				if not Catalog.RARITY[item.rarity] then
					fail("bad rarity " .. tostring(item.rarity))
				end
				if (brand :: any).roll then
					if item.currency ~= "roll" or item.rarity ~= (brand :: any).rarity then
						fail("roll-brand items must be currency roll with the brand's rarity")
					end
				elseif item.currency == "roll" then
					fail("roll items must use a roll brand")
				end
				if
					Catalog.EXCLUSIVE[item.currency] and (item.price ~= 0 or item.pass ~= nil or item.minRank ~= nil)
				then
					fail("exclusive items are never sold or gated")
				end
				if item.finish ~= nil and not Catalog.FINISHES[item.finish] then
					fail("bad finish " .. tostring(item.finish))
				end
				if item.details ~= nil then
					for _, d in item.details do
						if not Wardrobe.Details.has(d) then
							fail("unknown detail " .. tostring(d))
						end
					end
				end
				if item.colors.trim ~= nil and not isHex(item.colors.trim) then
					fail("bad trim colour")
				end
				if not isHex(item.colors.primary) then
					fail("bad primary colour")
				end
				if item.colors.secondary ~= nil and not isHex(item.colors.secondary) then
					fail("bad secondary colour")
				end
				if item.colors.accent ~= nil and not isHex(item.colors.accent) then
					fail("bad accent colour")
				end
				if
					type(item.tier) ~= "number"
					or item.tier < 1
					or item.tier > 5
					or item.tier ~= math.floor(item.tier)
				then
					fail("bad tier")
				end
				if type(item.name) ~= "string" or #item.name < 3 or type(item.desc) ~= "string" or #item.desc < 8 then
					fail("missing name/desc")
				end
				if type(item.tags) ~= "table" then
					fail("missing tags")
				end
				if
					item.minRank ~= nil and (type(item.minRank) ~= "number" or item.minRank < 0 or item.minRank > 12)
				then
					fail("bad minRank")
				end
				if not table.find(Catalog.CATEGORIES, item.category) then
					fail("bad category " .. tostring(item.category))
				end
			end
		end)

		t.it("pass items reference a known pass, cost no cash and are not hidden", function()
			for id, item in Catalog.items do
				if item.currency == "pass" or item.pass ~= nil then
					if not (item.pass and Catalog.PASSES[item.pass]) then
						error(id .. " references unknown pass " .. tostring(item.pass))
					end
					t.expect(item.currency).toBe("pass")
					t.expect(item.price).toBe(0)
					t.expect(item.hidden).toBeNil()
				end
			end
		end)

		t.it("cash prices follow the spec §11 price anchors", function()
			for id, item in Catalog.items do
				if item.currency == "cash" and item.price > 0 then
					local range = if item.slot == "shoes"
						then Catalog.SHOE_RANGE
						else Catalog.PRICE_RANGES[item.category]
					if not range then
						error(id .. " has no price range for category " .. item.category)
					end
					if item.price < range[1] or item.price > range[2] then
						error(("%s price %d outside [%d, %d]"):format(id, item.price, range[1], range[2]))
					end
				end
			end
		end)

		t.it("has a full catalogue: about 100-160 shop items, every slot stocked", function()
			local shop = Catalog.shopItems()
			t.expect(#shop).toBeBetween(100, 160)
			t.expect(#Catalog.list(true)).toBeGreaterThan(#Catalog.list())
			for _, slot in Catalog.SLOTS do
				local n = 0
				for _, item in shop do
					if item.slot == slot then
						n += 1
					end
				end
				t.expect(n).toBeGreaterThanOrEqual(3)
			end
			for slot, id in Catalog.REQUIRED do
				local item = Catalog.get(id)
				t.expect(item ~= nil).toBeTruthy()
				t.expect((item :: any).slot).toBe(slot)
			end
		end)

		t.it("sells every suit cut in every colour, with matching trousers", function()
			local jackets, trousers = 0, 0
			for _, colour in { "navy", "charcoal", "black", "grey", "pinstripe", "camel" } do
				for _, cut in { "2b", "db", "3p" } do
					local item = Catalog.get("suit_" .. colour .. "_" .. cut)
					t.expect(item ~= nil).toBeTruthy()
					t.expect((item :: any).slot).toBe("outer")
					jackets += 1
				end
				local tr = Catalog.get("suit_" .. colour .. "_trousers")
				t.expect(tr ~= nil).toBeTruthy()
				t.expect((tr :: any).slot).toBe("bottom")
				trousers += 1
			end
			t.expect(jackets).toBe(18)
			t.expect(trousers).toBe(6)
		end)

		t.it("has the premium collections and the watch ladder", function()
			local corner, club = 0, 0
			for _, item in Catalog.items do
				if item.pass == "CornerOffice" then
					corner += 1
				elseif item.pass == "ExecutiveClub" then
					club += 1
				end
			end
			t.expect(corner).toBeBetween(8, 10)
			t.expect(club).toBeBetween(4, 6)
			local tiers = {}
			for _, item in Catalog.bySlot("wrist") do
				if item.category == "watches" then
					tiers[item.tier] = item
				end
			end
			for tier = 1, 5 do
				t.expect(tiers[tier] ~= nil).toBeTruthy()
			end
			t.expect(tiers[5].minRank).toBe(5) -- MD-only flagship (v3 rank 5)
			t.expect(tiers[5].price).toBe(80000)
		end)

		t.it("bySlot is sorted by tier then price and hides NPC pieces", function()
			for _, slot in Catalog.SLOTS do
				local list = Catalog.bySlot(slot)
				for i = 2, #list do
					local a, b = list[i - 1], list[i]
					t.expect(a.tier < b.tier or (a.tier == b.tier and a.price <= b.price)).toBeTruthy()
				end
				for _, item in list do
					t.expect(item.hidden).toBeNil()
				end
			end
		end)
	end)

	t.describe("Brands, rarity and Life Roll pools", function()
		t.it("every brand has a valid rarity, a name and a blurb", function()
			t.expect(#Catalog.RARITIES).toBe(6)
			t.expect(Catalog.RARITIES).toEqual({ "common", "uncommon", "rare", "epic", "legendary", "mythic" })
			for i, r in Catalog.RARITIES do
				local def = Catalog.RARITY[r]
				t.expect(def ~= nil).toBeTruthy()
				t.expect(def.order).toBe(i)
				t.expect(isHex(def.color)).toBeTruthy()
			end
			t.expect(isHex(Catalog.RARITY.mythic.color2)).toBeTruthy()
			local count = 0
			for id, b in Catalog.brands do
				count += 1
				t.expect(b.id).toBe(id)
				if not Catalog.RARITY[b.rarity] then
					error(id .. " has bad rarity " .. tostring(b.rarity))
				end
				t.expect(#b.name).toBeGreaterThan(2)
				t.expect(#b.blurb).toBeGreaterThan(8)
				t.expect(#b.signature).toBeGreaterThan(8)
				t.expect(b.logo).toBe("brand_" .. id)
			end
			t.expect(count).toBe(#Catalog.brandList)
		end)

		t.it("puts the owner's roll brands in the right tiers", function()
			local expected = {
				common = { "kevin_kroos", "old_harbor", "gapline", "hanesworth" },
				uncommon = { "j_crewson", "plantain_republic", "tommy_hillford" },
				rare = { "ralph_lorenzo", "brooks_brethren", "vineyard_wines", "patagonio" },
				epic = { "briani", "canale" },
				legendary = { "tom_fordham", "zegnatti", "bruno_cucina" },
				mythic = { "pan_miller" },
			}
			local rollBrands = 0
			for _, b in Catalog.brands do
				if b.roll then
					rollBrands += 1
				end
			end
			local total = 0
			for rarity, ids in expected do
				for _, id in ids do
					total += 1
					local b = Catalog.brand(id)
					if not b or not b.roll or b.rarity ~= rarity then
						error(id .. " should be a " .. rarity .. " roll brand")
					end
				end
			end
			t.expect(rollBrands).toBe(total)
			t.expect(Catalog.brand("pan_miller").name).toBe("Pan Miller")
			t.expect(Catalog.brand("pan_miller").logo).toBe("brand_pan_miller")
			t.expect(Catalog.brand("william_kingsley")).toBeNil()
			t.expect(Catalog.brand("canale").name).toBe("Canalé")
		end)

		t.it("roll pools have the spec sizes and mythic has exactly one look", function()
			local sizes = { common = 12, uncommon = 8, rare = 6, epic = 4, legendary = 3, mythic = 1 }
			for rarity, n in sizes do
				local pool = Catalog.rollPools[rarity]
				t.expect(pool ~= nil).toBeTruthy()
				t.expect(#pool).toBe(n)
			end
			-- every roll brand appears in its tier's pool
			for id, b in Catalog.brands do
				if b.roll then
					local found = false
					for _, look in Catalog.rollPools[b.rarity] do
						if look.brand == id then
							found = true
						end
					end
					if not found then
						error(id .. " has no look in the " .. b.rarity .. " pool")
					end
				end
			end
			t.expect(Catalog.rollPools.mythic[1].brand).toBe("pan_miller")
			-- common pools hold the most options, each higher tier fewer (v3 §1)
			for i = 2, #Catalog.RARITIES do
				local lower, higher = Catalog.RARITIES[i - 1], Catalog.RARITIES[i]
				t.expect(#Catalog.rollPools[higher]).toBeLessThan(#Catalog.rollPools[lower])
			end
		end)

		t.it("every pool item exists with the look's brand and rarity, and every look is complete", function()
			local seenLook = {}
			local usedItems = {}
			for rarity, pool in Catalog.rollPools do
				for _, look in pool do
					t.expect(seenLook[look.id]).toBeNil()
					seenLook[look.id] = true
					t.expect(look.rarity).toBe(rarity)
					t.expect(#look.name).toBeGreaterThan(3)
					local slots = {}
					for _, id in look.itemIds do
						local item = Catalog.get(id)
						if not item then
							error(look.id .. " references unknown item " .. id)
						end
						if item.brand ~= look.brand or item.rarity ~= rarity then
							error(
								("%s: %s is %s/%s, look is %s/%s"):format(
									look.id,
									id,
									item.brand,
									item.rarity,
									look.brand,
									rarity
								)
							)
						end
						t.expect(item.currency).toBe("roll")
						if slots[item.slot] then
							error(look.id .. " has two " .. item.slot .. " pieces")
						end
						slots[item.slot] = id
						usedItems[id] = true
					end
					for _, need in { "top", "bottom", "shoes" } do
						if not slots[need] then
							error(look.id .. " has no " .. need)
						end
					end
				end
			end
			-- no orphan roll pieces
			for id, item in Catalog.items do
				if item.currency == "roll" and not usedItems[id] then
					error(id .. " is a roll item in no look")
				end
			end
		end)

		t.it("pickLook maps [0, 1) across the pool and lookOf finds a piece's look", function()
			t.expect(Catalog.pickLook("mythic", 0.99).id).toBe("pm_signature")
			t.expect(Catalog.pickLook("epic", 0).brand).toBe("briani")
			t.expect(Catalog.pickLook("epic", 0.99).brand).toBe("canale")
			t.expect(Catalog.pickLook("common", 0).id).toBe(Catalog.rollPools.common[1].id)
			t.expect(Catalog.pickLook("common", 0.9999).id).toBe(Catalog.rollPools.common[12].id)
			t.expect(Catalog.pickLook("common", 1.5).id).toBe(Catalog.rollPools.common[12].id)
			t.expect(Catalog.pickLook("common", -1).id).toBe(Catalog.rollPools.common[1].id)
			t.expect(Catalog.pickLook("nope", 0.5)).toBeNil()
			t.expect((Catalog.lookOf("pm_tie") :: any).id).toBe("pm_signature")
			t.expect(Catalog.lookOf("oxford_white")).toBeNil()
		end)

		t.it("has a family heirloom for every rarity from Rare up", function()
			local want = {
				heirloom_signet_ring = "rare",
				heirloom_family_scarf = "epic",
				heirloom_family_watch = "legendary",
				heirloom_vanderfeller_crest_blazer = "mythic",
			}
			for id, rarity in want do
				local item = Catalog.get(id)
				if not item then
					error("missing heirloom " .. id)
				end
				t.expect(item.currency).toBe("heirloom")
				t.expect(item.rarity).toBe(rarity)
				t.expect(item.brand).toBe("family_heirloom")
			end
			t.expect(#Catalog.heirlooms()).toBe(4)
			for id, rarity in want do
				t.expect(Catalog.heirloomFor(rarity)).toBe(id)
			end
			t.expect(Catalog.heirloomFor("common")).toBeNil()
			t.expect(Catalog.heirloomFor("uncommon")).toBeNil()
			t.expect(Catalog.heirloomFor(nil)).toBeNil()
			-- mythic is reserved for the Pan Miller look and the Vanderfeller blazer
			for id, item in Catalog.items do
				if item.rarity == "mythic" then
					t.expect(item.brand == "pan_miller" or id == "heirloom_vanderfeller_crest_blazer").toBeTruthy()
				end
			end
		end)

		t.it("shop items carry a house brand and a rarity that follows their tier", function()
			for _, item in Catalog.shopItems() do
				local b = Catalog.brand(item.brand) :: any
				t.expect(b.roll).toBe(false)
				t.expect(item.rarity).toBe(Catalog.TIER_RARITY[item.tier])
			end
			t.expect(Catalog.get("suit_navy_2b").brand).toBe("hartwell")
			t.expect(Catalog.get("watch_astra_moonphase").brand).toBe("vanta")
			t.expect(Catalog.get("oxford_black").brand).toBe("strider")
			t.expect(Catalog.get("co_velvet_dinner").brand).toBe("corner_office")
			t.expect(Catalog.get("hoodie_maroon").brand).toBe("eastbridge")
		end)
	end)

	t.describe("Starter outfits and presets", function()
		t.it("starter outfits reference free-to-wear items in the right slots", function()
			for stage, outfit in Catalog.starter do
				t.expect(count(outfit)).toBeGreaterThanOrEqual(3)
				for slot, id in outfit do
					local item = Catalog.get(id)
					if not item or item.slot ~= slot then
						error(("starter %s: %s is not a %s item"):format(stage, id, slot))
					end
					t.expect(item.currency).toBe("cash")
					t.expect(item.hidden).toBeNil()
				end
			end
			t.expect(Catalog.stageFor(0)).toBe("student")
			t.expect(Catalog.stageFor(1)).toBe("analyst")
			t.expect(Catalog.stageFor(9)).toBe("associate")
			t.expect(Catalog.starterFor(1).neck).toBe("lanyard_staff")
			local items = Catalog.starterItems(2)
			t.expect(items).toContain("hoodie_heather")
			t.expect(items).toContain("oxford_white")
			t.expect(Catalog.isStarter("tie_navy", 1)).toBeFalsy()
			t.expect(Catalog.isStarter("tie_navy", 2)).toBeTruthy()
		end)

		t.it("every NPC preset references real items, hair styles, poses and colours", function()
			local roles = { "barista", "professor", "recruiter", "receptionist", "trader", "md", "tailor", "doorman" }
			for _, role in roles do
				t.expect(Catalog.presets[role] ~= nil).toBeTruthy()
			end
			for role, preset in Catalog.presets do
				for slot, id in preset.equipped do
					local item = Catalog.get(id)
					if not item or item.slot ~= slot then
						error(("preset %s: %s is not a %s item"):format(role, id, slot))
					end
				end
				if preset.hairStyle and not Hair.isStyle(preset.hairStyle) then
					error(("preset %s: unknown hair style %s"):format(role, preset.hairStyle))
				end
				if preset.hairColor ~= nil then
					t.expect(isHex(preset.hairColor)).toBeTruthy()
				end
				if preset.skin ~= nil then
					t.expect(isHex(preset.skin)).toBeTruthy()
				end
				if preset.pose ~= nil then
					t.expect(Body.POSES[preset.pose] ~= nil).toBeTruthy()
				end
			end
		end)
	end)

	t.describe("Access rules", function()
		local student = { owned = {}, rank = 0, passes = {} }
		local vp = { owned = { suit_pinstripe_db = true }, rank = 3, passes = {} }
		local member = { owned = {}, rank = 0, passes = { ExecutiveClub = true, CornerOffice = true } }

		t.it("reports owned, free, buy, rank and pass states", function()
			t.expect(Catalog.access(Catalog.get("hoodie_heather") :: any, student)).toBe("owned") -- starter piece
			t.expect(Catalog.access(Catalog.get("lanyard_staff") :: any, student)).toBe("free")
			t.expect(Catalog.access(Catalog.get("hoodie_maroon") :: any, student)).toBe("buy")
			t.expect(Catalog.access(Catalog.get("watch_astra_moonphase") :: any, vp)).toBe("rank")
			t.expect(Catalog.access(Catalog.get("suit_pinstripe_db") :: any, vp)).toBe("owned")
			t.expect(Catalog.access(Catalog.get("co_velvet_dinner") :: any, student)).toBe("pass")
			t.expect(Catalog.access(Catalog.get("co_velvet_dinner") :: any, member)).toBe("owned")
		end)

		t.it("canWear needs ownership (or free/starter) and the rank requirement", function()
			t.expect((Catalog.canWear(Catalog.get("hoodie_heather") :: any, student))).toBeTruthy()
			local ok, err = Catalog.canWear(Catalog.get("hoodie_maroon") :: any, student)
			t.expect(ok).toBeFalsy()
			t.expect(err).toBe("not_owned")
			ok, err = Catalog.canWear(Catalog.get("ec_club_blazer") :: any, student)
			t.expect(ok).toBeFalsy()
			t.expect(err).toBe("pass")
			-- owned but under-ranked (e.g. a granted prize) still can't be worn
			ok, err = Catalog.canWear(
				Catalog.get("watch_astra_moonphase") :: any,
				{ owned = { watch_astra_moonphase = true }, rank = 2 }
			)
			t.expect(ok).toBeFalsy()
			t.expect(err).toBe("rank")
			-- hidden NPC pieces are never wearable by players
			ok, err = Catalog.canWear(Catalog.get("doorman_coat") :: any, member)
			t.expect(ok).toBeFalsy()
			t.expect(err).toBe("unknown_item")
		end)

		t.it("checkEquip validates slot, item and unequip", function()
			t.expect((Catalog.checkEquip("top", "hoodie_heather", student))).toBeTruthy()
			t.expect((Catalog.checkEquip("hat", "hoodie_heather", student))).toBeFalsy()
			local ok, err = Catalog.checkEquip("bottom", "hoodie_heather", student)
			t.expect(ok).toBeFalsy()
			t.expect(err).toBe("bad_slot")
			ok, err = Catalog.checkEquip("top", "nope", student)
			t.expect(ok).toBeFalsy()
			t.expect(err).toBe("unknown_item")
			t.expect((Catalog.checkEquip("neck", nil, student))).toBeTruthy()
			t.expect((Catalog.checkEquip(5, nil, student))).toBeFalsy()
		end)

		t.it("sanitizeEquipped drops pieces the viewer can no longer wear", function()
			local cleaned, dropped = Catalog.sanitizeEquipped({
				top = "hoodie_heather",
				outer = "co_velvet_dinner",
				wrist = "watch_astra_moonphase",
				bottom = "hoodie_heather",
				bogus = "jeans_indigo",
			}, student)
			t.expect(cleaned).toEqual({ top = "hoodie_heather" })
			t.expect(#dropped).toBe(4)
			local kept = Catalog.sanitizeEquipped({ outer = "co_velvet_dinner" }, member)
			t.expect(kept.outer).toBe("co_velvet_dinner")
			t.expect(count(Catalog.sanitizeEquipped("junk", student))).toBe(0)
		end)

		t.it("exclusive pieces are wearable only once granted, and listed only when owned", function()
			local item = Catalog.get("pm_jacket") :: any
			t.expect(Catalog.access(item, member)).toBe("roll")
			local ok, err = Catalog.canWear(item, member)
			t.expect(ok).toBeFalsy()
			t.expect(err).toBe("roll")
			local heir = Catalog.get("heirloom_signet_ring") :: any
			t.expect(Catalog.access(heir, student)).toBe("heirloom")
			local granted = { owned = { pm_jacket = true, heirloom_signet_ring = true }, rank = 0 }
			t.expect(Catalog.access(item, granted)).toBe("owned")
			t.expect((Catalog.checkEquip("outer", "pm_jacket", granted))).toBeTruthy()
			t.expect((Catalog.checkEquip("wrist", "heirloom_signet_ring", granted))).toBeTruthy()
			t.expect(Catalog.isShopItem(item)).toBeFalsy()
			t.expect(Catalog.isExclusive(item)).toBeTruthy()
			-- the wardrobe lists owned exclusives first, never unowned ones
			local outer = Catalog.visibleFor("outer", granted)
			t.expect(outer[1].id).toBe("pm_jacket")
			for _, it in Catalog.visibleFor("outer", student) do
				t.expect(Catalog.isExclusive(it)).toBeFalsy()
				t.expect(it.hidden).toBeNil()
			end
			t.expect(#Catalog.visibleFor("outer", granted)).toBe(#Catalog.visibleFor("outer", student) + 1)
		end)

		t.it("preset slots and names", function()
			t.expect(Catalog.presetSlotsFor(student)).toBe(Catalog.PRESET_SLOTS.free)
			t.expect(Catalog.presetSlotsFor(member)).toBe(Catalog.PRESET_SLOTS.max)
			t.expect(Catalog.presetName("  Monday   Look ", 1)).toBe("Monday Look")
			t.expect(Catalog.presetName("", 2)).toBe("Outfit 2")
			t.expect(Catalog.presetName(nil, 3)).toBe("Outfit 3")
			t.expect(Catalog.presetName("bad\0name\n", 1)).toBe("bad name")
			t.expect(utf8.len(Catalog.presetName(string.rep("é", 40), 1))).toBe(Catalog.PRESET_SLOTS.nameMax)
			t.expect(Catalog.presetName(string.char(255, 254), 4)).toBe("Outfit 4")
		end)

		t.it("text substitutes placeholders and falls back to the key", function()
			t.expect(Catalog.text("buy", { price = "$120" })).toBe("Buy $120")
			t.expect(Catalog.text("no_such_key")).toBe("no_such_key")
			t.expect(Catalog.rankTitle(5)).toBe("Managing Director")
			t.expect(Catalog.rankTitle(8)).toBe("Managing Director")
			t.expect(Catalog.rankTitle(3)).toBe("Vice President")
		end)
	end)
end
