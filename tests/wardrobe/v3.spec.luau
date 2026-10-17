-- Design v3 wardrobe changes: Pan Miller (ex William Kingsley), the Epic tier, clothing level = tier 1..5 with cash
-- items at every level in every slot, and the company logo ONLY on vests and quarter-zips.
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Config.Catalog)
local Brands = require(Shared.Config.Catalog.Brands)
local Wardrobe = require(Shared.Assets.Wardrobe)
local NpcRig = require(Shared.Assets.Npc.Rig)
local Inventory = require(game:GetService("ServerScriptService").Server.Services.WardrobeService.Inventory)

local LOGO = "mg_freeman"

local function rig(): Model
	return NpcRig.build({ name = "LogoTest", hairStyle = "none", equipped = {}, strict = true })
end

-- Every layer part named `<slot>_CompanyLogo` in the character's Career Look.
local function logoPlates(model: Instance): { BasePart }
	local out = {}
	local folder = model:FindFirstChild(Wardrobe.FOLDER)
	if folder then
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") and string.sub(d.Name, -12) == "_CompanyLogo" then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function named(model: Instance, name: string): { BasePart }
	local out = {}
	local folder = model:FindFirstChild(Wardrobe.FOLDER)
	if folder then
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") and d.Name == name then
				table.insert(out, d)
			end
		end
	end
	return out
end

-- A plate's SurfaceGui actually draws something (Logos.render output or the inline fallback).
local function drawsSomething(plate: BasePart): boolean
	local gui = plate:FindFirstChildOfClass("SurfaceGui")
	if not gui then
		return false
	end
	local n = 0
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiObject") then
			n += 1
		end
	end
	return n >= 2 -- the canvas plus at least one shape or label
end

local CORE = { bottom = "suit_navy_trousers", shoes = "oxford_black" }

local function look(extra: { [string]: string }): { [string]: string }
	local eq = table.clone(CORE)
	for k, v in extra do
		eq[k] = v
	end
	return eq
end

return function(t)
	t.describe("v3: Pan Miller replaces William Kingsley", function()
		t.it("is the one Mythic brand, with its windmill logo id", function()
			local b = Catalog.brand("pan_miller") :: any
			t.expect(b ~= nil).toBeTruthy()
			t.expect(b.name).toBe("Pan Miller")
			t.expect(b.rarity).toBe("mythic")
			t.expect(b.roll).toBe(true)
			t.expect(b.logo).toBe("brand_pan_miller")
			t.expect(#Catalog.rollPools.mythic).toBe(1)
			local signature = Catalog.rollPools.mythic[1]
			t.expect(signature.id).toBe("pm_signature")
			t.expect(signature.brand).toBe("pan_miller")
			for _, id in signature.itemIds do
				local item = Catalog.get(id) :: any
				t.expect(item.brand).toBe("pan_miller")
				t.expect(item.rarity).toBe("mythic")
				t.expect(item.tier).toBe(5)
			end
		end)

		t.it("leaves no trace of the old name in brands, items, looks or strings", function()
			local function clean(s: any, where: string)
				if type(s) == "string" and string.find(string.lower(s), "kingsley", 1, true) then
					error(where .. " still says Kingsley: " .. s)
				end
			end
			for id, b in Catalog.brands do
				clean(id, "brand id")
				clean(b.name, id)
				clean(b.blurb, id)
				clean(b.signature, id)
				clean(b.logo, id)
			end
			for id, item in Catalog.items do
				clean(id, "item id")
				clean(item.name, id)
				clean(item.desc, id)
				clean(item.brand, id)
				clean(item.style, id)
			end
			for id, l in Catalog.looks do
				clean(id, "look id")
				clean(l.name, id)
			end
			for key, s in Catalog.strings do
				clean(s, "string " .. key)
			end
		end)

		t.it("maps the old v2 ids to the Pan Miller pieces in saved inventories", function()
			t.expect(Catalog.canonical("wk_jacket")).toBe("pm_jacket")
			t.expect(Catalog.canonical("wk_signature")).toBe("pm_signature")
			t.expect(Catalog.canonical("oxford_white")).toBe("oxford_white")
			local inv = Inventory.normalize({
				owned = { wk_jacket = true, wk_tie = true, oxford_white = true },
				equipped = { outer = "wk_jacket", neck = "wk_tie" },
				presets = { ["1"] = { name = "Old", equipped = { outer = "wk_jacket" } } },
			})
			t.expect(inv.owned.pm_jacket).toBe(true)
			t.expect(inv.owned.pm_tie).toBe(true)
			t.expect(inv.owned.wk_jacket).toBeNil()
			t.expect(inv.equipped.outer).toBe("pm_jacket")
			t.expect(inv.equipped.neck).toBe("pm_tie")
			t.expect(inv.presets["1"].equipped.outer).toBe("pm_jacket")
			-- a v2 profile that rolled the old look still earns the new pieces
			local pieces, lookId = Inventory.profilePieces({ outfitRoll = { lookId = "wk_signature" } })
			t.expect(lookId).toBe("pm_signature")
			t.expect(pieces).toContain("pm_jacket")
			t.expect(pieces).toContain("pm_watch")
		end)

		t.it("keeps the signature detailing and adds the windmill emblem", function()
			local jacket = Catalog.get("pm_jacket") :: any
			t.expect(jacket.details).toContain("emblem_windmill")
			t.expect(jacket.details).toContain("lapel_pin")
			local model = NpcRig.build({
				equipped = { top = "pm_shirt", outer = "pm_jacket", neck = "pm_tie", bottom = "pm_trousers" },
				hairStyle = "none",
				strict = true,
			})
			local mills = named(model, "outer_Windmill")
			t.expect(#mills).toBe(1)
			t.expect(drawsSomething(mills[1])).toBeTruthy()
			t.expect(#named(model, "top_Windmill")).toBe(0) -- the shirt's windmill hides under the jacket
			t.expect(#named(model, "outer_LapelPin")).toBe(1)
			local shirtOnly = NpcRig.build({ equipped = { top = "pm_shirt" }, hairStyle = "none", strict = true })
			local shirtMills = named(shirtOnly, "top_Windmill")
			t.expect(#shirtMills).toBe(1)
			t.expect(drawsSomething(shirtMills[1])).toBeTruthy()
		end)

		t.it("draws the inline windmill when the logos module is unavailable", function()
			local canvas = Instance.new("Frame")
			Wardrobe.Emblems.drawWindmill(canvas, Color3.new(1, 1, 1))
			local blades, legs = 0, 0
			for _, c in canvas:GetChildren() do
				if c.Name == "Blade" then
					blades += 1
				elseif c.Name == "Leg" then
					legs += 1
				end
			end
			t.expect(blades).toBe(12) -- the multi-blade wheel
			t.expect(legs).toBe(2) -- the lattice tower
			t.expect(canvas:FindFirstChild("Vane") ~= nil).toBeTruthy() -- the tail vane
			t.expect(canvas:FindFirstChild("Hub") ~= nil).toBeTruthy()
		end)
	end)

	t.describe("v3: the Epic tier", function()
		t.it("sits between Rare and Legendary in purple", function()
			t.expect(Catalog.RARITIES[4]).toBe("epic")
			t.expect(Catalog.RARITY.epic.order).toBe(4)
			t.expect(Catalog.rarityOrder("epic")).toBeGreaterThan(Catalog.rarityOrder("rare"))
			t.expect(Catalog.rarityOrder("epic")).toBeLessThan(Catalog.rarityOrder("legendary"))
			local c = Catalog.RARITY.epic.color
			local r, g, b =
				tonumber(string.sub(c, 2, 3), 16), tonumber(string.sub(c, 4, 5), 16), tonumber(c:sub(6, 7), 16)
			t.expect((b :: number) > (g :: number) and (r :: number) > (g :: number)).toBeTruthy() -- purple
			t.expect(Catalog.text("rarity_epic")).toBe("Epic")
			for _, rarity in Catalog.RARITIES do
				t.expect(Catalog.strings["rarity_" .. rarity] ~= nil).toBeTruthy()
			end
		end)

		t.it("has Briani and Canalé with tailored pieces in a pool of 4", function()
			t.expect(#Catalog.rollPools.epic).toBe(4)
			local byBrand: { [string]: number } = {}
			for _, l in Catalog.rollPools.epic do
				byBrand[l.brand] = (byBrand[l.brand] or 0) + 1
			end
			t.expect(byBrand.briani).toBe(2)
			t.expect(byBrand.canale).toBe(2)
			for _, brandId in { "briani", "canale" } do
				local b = Catalog.brand(brandId) :: any
				t.expect(b.rarity).toBe("epic")
				t.expect(b.logo).toBe("brand_" .. brandId)
				local tailored = 0
				for _, item in Catalog.items do
					if item.brand == brandId then
						t.expect(item.rarity).toBe("epic")
						t.expect(item.tier).toBe(4)
						t.expect(item.currency).toBe("roll")
						if item.slot == "outer" and item.builder == "jacket" then
							tailored += 1
						end
					end
				end
				t.expect(tailored).toBeGreaterThanOrEqual(1)
			end
			t.expect(Catalog.brand("canale").name).toBe("Canalé")
			t.expect(Catalog.brand("briani").name).toBe("Briani")
		end)

		t.it("pools follow the v3 sizes: 12 / 8 / 6 / 4 / 3 / 1", function()
			local want = { common = 12, uncommon = 8, rare = 6, epic = 4, legendary = 3, mythic = 1 }
			for rarity, n in want do
				t.expect(#Catalog.rollPools[rarity]).toBe(n)
			end
		end)

		t.it("gives roll pieces the clothing level of their rarity", function()
			for _, item in Catalog.items do
				if item.currency == "roll" then
					t.expect(item.tier).toBe(Brands.LEVEL_OF_RARITY[item.rarity])
				end
			end
			-- an Epic roll dresses you for any Elite Boutique / PE / WM door (Outfit Level 4)
			for _, l in Catalog.rollPools.epic do
				local eq = {}
				for _, id in l.itemIds do
					eq[(Catalog.get(id) :: any).slot] = id
				end
				t.expect((Catalog.outfitLevel(eq))).toBe(4)
			end
			local signature = { top = "pm_shirt", outer = "pm_jacket", bottom = "pm_trousers", shoes = "pm_oxford" }
			t.expect((Catalog.outfitLevel(signature))).toBe(5)
		end)
	end)

	t.describe("v3: clothing level = tier 1..5", function()
		t.it("sells cash items at every level 1-5 in every slot", function()
			for _, slot in Catalog.SLOTS do
				for level = 1, 5 do
					local found = false
					for _, item in Catalog.shopItems() do
						if
							item.slot == slot
							and item.currency == "cash"
							and item.price > 0
							and Catalog.levelOf(item) == level
						then
							found = true
						end
					end
					if not found then
						error(("no purchasable %s at level %d"):format(slot, level))
					end
				end
			end
		end)

		t.it("prices suits at about $1-2k (Lv 3), $3-6k (Lv 4) and $8-25k (Lv 5)", function()
			local bands = { [3] = { 1000, 2000 }, [4] = { 3000, 6000 }, [5] = { 8000, 25000 } }
			local seen: { [number]: number } = {}
			for _, item in Catalog.shopItems() do
				if item.category == "suits" and item.slot == "outer" and item.builder == "jacket" then
					local band = bands[item.tier]
					if not band then
						error(item.id .. " is a suit jacket below level 3")
					end
					if item.price < band[1] or item.price > band[2] then
						error(
							("%s (Lv %d) costs %d, outside %d-%d"):format(
								item.id,
								item.tier,
								item.price,
								band[1],
								band[2]
							)
						)
					end
					seen[item.tier] = (seen[item.tier] or 0) + 1
				end
			end
			for level = 3, 5 do
				t.expect((seen[level] or 0) >= 3).toBeTruthy()
			end
		end)

		t.it("makes every dress requirement reachable at the rank it is needed", function()
			-- hiring needs up to Lv 4 as a student (rank 0); promotions need min(5, newRank + 1), bought one rank
			-- below, so Lv 5 (Director) has to be on sale to a VP (rank 3)
			local buyRank = { [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 3 }
			for level = 1, 5 do
				local cheapest: { [string]: any } = {}
				for _, item in Catalog.shopItems() do
					local part = if item.slot == "top" or item.slot == "outer"
						then "torso"
						elseif item.slot == "bottom" then "bottom"
						elseif item.slot == "shoes" then "shoes"
						else nil
					if
						part
						and item.currency == "cash"
						and Catalog.levelOf(item) >= level
						and (item.minRank or 0) <= buyRank[level]
					then
						local best = cheapest[part]
						if not best or item.price < best.price then
							cheapest[part] = item
						end
					end
				end
				for _, part in { "torso", "bottom", "shoes" } do
					if not cheapest[part] then
						error(("no %s at level %d for rank %d"):format(part, level, buyRank[level]))
					end
				end
				local eq = {
					[cheapest.torso.slot] = cheapest.torso.id,
					bottom = cheapest.bottom.id,
					shoes = cheapest.shoes.id,
				}
				t.expect((Catalog.outfitLevel(eq)) >= level).toBeTruthy()
			end
		end)

		t.it("Outfit Level is the lowest of torso (best of top/outer), bottom and shoes", function()
			local level, parts = Catalog.outfitLevel({
				top = "tee_white",
				outer = "suit_navy_2b",
				bottom = "suit_navy_trousers",
				shoes = "oxford_black",
			})
			t.expect(level).toBe(3)
			t.expect(parts.torso).toBe(3)
			level, parts = Catalog.outfitLevel({ outer = "bespoke_midnight_2b", bottom = "bespoke_midnight_trousers" })
			t.expect(level).toBe(1) -- no shoes: the plain base shoes are level 1
			t.expect(parts.lowest).toBe("shoes")
			t.expect((Catalog.outfitLevel({}))).toBe(1)
			t.expect((Catalog.outfitLevel(nil))).toBe(1)
			t.expect((Catalog.outfitLevel({ top = "nope", bottom = "oxford_black" }))).toBe(1)
			t.expect(Catalog.levelOf("watch_astra_moonphase")).toBe(5)
			t.expect(Catalog.levelOf("missing")).toBe(0)
		end)
	end)

	t.describe("v3: company logo only on vests and quarter-zips", function()
		t.it("never draws it on a suit, then draws it on a vest", function()
			local model = rig()
			local suit = Wardrobe.apply(
				model,
				look({ top = "oxford_white", outer = "suit_navy_2b", neck = "tie_navy" }),
				{ anchored = true, strict = true, companyLogo = LOGO }
			)
			t.expect(suit.ok).toBe(true)
			t.expect(suit.logoSlot).toBeNil()
			t.expect(#logoPlates(model)).toBe(0)
			t.expect(Wardrobe.appliedLogo(model)).toBeNil()

			local vest = Wardrobe.apply(
				model,
				look({ top = "oxford_white", outer = "vest_fleece" }),
				{ anchored = true, strict = true, companyLogo = LOGO }
			)
			t.expect(vest.logoSlot).toBe("outer")
			local plates = logoPlates(model)
			t.expect(#plates).toBe(1)
			t.expect(plates[1].Name).toBe("outer_CompanyLogo")
			t.expect(plates[1]:GetAttribute("LogoId")).toBe(LOGO)
			t.expect(drawsSomething(plates[1])).toBeTruthy()
			t.expect(Wardrobe.appliedLogo(model)).toBe(LOGO)
			-- left chest: the wearer's left is -X on the torso's front
			local torso = model:FindFirstChild("UpperTorso") :: BasePart
			local rel = torso.CFrame:PointToObjectSpace(plates[1].CFrame.Position)
			t.expect(rel.X).toBeLessThan(0)
			t.expect(rel.Y).toBeGreaterThan(0)
			t.expect(rel.Z).toBeLessThan(0)

			-- back into the suit: the emblem goes away
			Wardrobe.apply(model, look({ top = "oxford_white", outer = "suit_navy_2b" }), {
				anchored = true,
				strict = true,
				companyLogo = LOGO,
			})
			t.expect(#logoPlates(model)).toBe(0)
		end)

		t.it("draws it on a quarter-zip, unless a jacket covers it", function()
			local model = rig()
			local qz = Wardrobe.apply(
				model,
				look({ top = "qzip_navy" }),
				{ anchored = true, strict = true, companyLogo = LOGO }
			)
			t.expect(qz.logoSlot).toBe("top")
			local plates = logoPlates(model)
			t.expect(#plates).toBe(1)
			t.expect(plates[1].Name).toBe("top_CompanyLogo")

			local covered = Wardrobe.apply(
				model,
				look({ top = "qzip_navy", outer = "blazer_navy" }),
				{ anchored = true, strict = true, companyLogo = LOGO }
			)
			t.expect(covered.logoSlot).toBeNil()
			t.expect(#logoPlates(model)).toBe(0)

			-- a quarter-zip under a vest: one emblem, on the vest
			local layered = Wardrobe.apply(
				model,
				look({ top = "qzip_navy", outer = "vest_gilet_navy" }),
				{ anchored = true, strict = true, companyLogo = LOGO }
			)
			t.expect(layered.logoSlot).toBe("outer")
			t.expect(#logoPlates(model)).toBe(1)
		end)

		t.it("needs a company: no logo id, no emblem", function()
			local model = rig()
			local r = Wardrobe.apply(model, look({ outer = "vest_fleece" }), { anchored = true, strict = true })
			t.expect(r.logoSlot).toBeNil()
			t.expect(#logoPlates(model)).toBe(0)
			r = Wardrobe.apply(
				model,
				look({ outer = "vest_fleece" }),
				{ anchored = true, strict = true, companyLogo = "" }
			)
			t.expect(#logoPlates(model)).toBe(0)
		end)

		t.it("only vests and quarter-zips qualify across the whole catalogue", function()
			local eligible = 0
			for _, item in Catalog.list() do
				if item.slot ~= "top" and item.slot ~= "outer" then
					t.expect(Catalog.logoEligible(item)).toBe(false)
					continue
				end
				local ok = Catalog.logoEligible(item)
				local isVest = item.builder == "vest" and item.slot == "outer" and item.style ~= "waistcoat"
				local isQzip = item.builder == "quarterzip" and item.slot == "top"
				if ok ~= (isVest or isQzip) then
					error(item.id .. " (" .. item.builder .. ") has the wrong logo eligibility")
				end
				if ok then
					eligible += 1
				end
				local model = rig()
				local r = Wardrobe.apply(
					model,
					look({ [item.slot] = item.id }),
					{ anchored = true, strict = true, companyLogo = LOGO }
				)
				local plates = #logoPlates(model)
				if ok and (plates ~= 1 or r.logoSlot ~= item.slot) then
					error(item.id .. " should carry the company logo")
				elseif not ok and plates ~= 0 then
					error(item.id .. " (" .. item.builder .. ") must never carry the company logo")
				end
			end
			t.expect(eligible).toBeGreaterThanOrEqual(8)
			-- the named exclusions from v3 §16
			for _, id in { "suit_navy_2b", "oxford_white", "blouse_ivory", "hoodie_heather", "vest_waistcoat" } do
				t.expect(Catalog.logoEligible(Catalog.get(id))).toBe(false)
			end
			t.expect(Catalog.logoEligible(nil)).toBe(false)
		end)

		t.it("dresses office NPCs (and the preview) through NpcRig the same way", function()
			local npc = NpcRig.build({
				equipped = look({ top = "oxford_blue", outer = "vest_fleece" }),
				companyLogo = LOGO,
				hairStyle = "none",
				strict = true,
			})
			t.expect(#logoPlates(npc)).toBe(1)
			t.expect(Wardrobe.logoSlotFor(look({ outer = "vest_fleece" }))).toBe("outer")
			t.expect(Wardrobe.logoSlotFor(look({ top = "qzip_navy", outer = "suit_navy_db" }))).toBeNil()
		end)
	end)
end
