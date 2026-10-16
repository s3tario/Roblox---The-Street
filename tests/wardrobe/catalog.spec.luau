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
				if item.currency ~= "cash" and item.currency ~= "pass" then
					fail("bad currency")
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

		t.it("has a full catalogue: about 60-100 visible items, every slot stocked", function()
			local visible = Catalog.list()
			t.expect(#visible).toBeBetween(60, 100)
			t.expect(#Catalog.list(true)).toBeGreaterThan(#visible)
			for _, slot in Catalog.SLOTS do
				t.expect(#Catalog.bySlot(slot)).toBeGreaterThanOrEqual(3)
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
			t.expect(tiers[5].minRank).toBe(6) -- MD-only flagship
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
			t.expect(Catalog.stageFor(1)).toBe("intern")
			t.expect(Catalog.stageFor(9)).toBe("analyst")
			t.expect(Catalog.starterFor(1).neck).toBe("lanyard_intern")
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
		local vp = { owned = { suit_pinstripe_db = true }, rank = 4, passes = {} }
		local member = { owned = {}, rank = 0, passes = { ExecutiveClub = true, CornerOffice = true } }

		t.it("reports owned, free, buy, rank and pass states", function()
			t.expect(Catalog.access(Catalog.get("hoodie_heather") :: any, student)).toBe("owned") -- starter piece
			t.expect(Catalog.access(Catalog.get("lanyard_intern") :: any, student)).toBe("free")
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
			t.expect(Catalog.rankTitle(6)).toBe("Managing Director")
			t.expect(Catalog.rankTitle(8)).toBe("Managing Director")
		end)
	end)
end
