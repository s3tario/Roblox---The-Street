local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Config.Catalog)
local Template = require(Shared.Config.DataTemplate.Inventory)
local ClothingIds = require(Shared.Config.ClothingIds)
local Inventory = require(game:GetService("ServerScriptService").Server.Services.WardrobeService.Inventory)

local function fresh(): any
	local t = Template.inventory
	return Inventory.normalize({
		owned = table.clone(t.owned),
		equipped = table.clone(t.equipped),
		presets = table.clone(t.presets),
		wearAvatar = t.wearAvatar,
		stages = table.clone(t.stages),
	})
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

return function(t)
	t.describe("Inventory template and ClothingIds", function()
		t.it("has the contract fields", function()
			local inv = Template.inventory
			t.expect(type(inv.owned)).toBe("table")
			t.expect(type(inv.equipped)).toBe("table")
			t.expect(type(inv.presets)).toBe("table")
			t.expect(inv.wearAvatar).toBe(false)
		end)

		t.it("lists only real top/outer/bottom items, all 0 by default", function()
			local shirts, pants = 0, 0
			for id, n in ClothingIds.shirts do
				local item = Catalog.get(id)
				if not item or (item.slot ~= "top" and item.slot ~= "outer") or item.hidden then
					error("ClothingIds.shirts has a bad entry " .. id)
				end
				t.expect(type(n)).toBe("number")
				shirts += 1
			end
			for id, n in ClothingIds.pants do
				local item = Catalog.get(id)
				if not item or item.slot ~= "bottom" or item.hidden then
					error("ClothingIds.pants has a bad entry " .. id)
				end
				t.expect(type(n)).toBe("number")
				pants += 1
			end
			t.expect(shirts).toBeGreaterThan(40)
			t.expect(pants).toBeGreaterThan(15)
		end)
	end)

	t.describe("Inventory rules", function()
		t.it("normalize repairs junk from the DataStore", function()
			local inv = Inventory.normalize({
				owned = { oxford_white = true, gone_item = true, [5] = true, tie_navy = false },
				equipped = { top = "oxford_white", bottom = "oxford_white", hat = "beanie_charcoal", outer = "doorman_coat" },
				presets = { ["1"] = { name = "  Work  ", equipped = { top = "oxford_white", shoes = "nope" } }, ["9"] = {} },
				wearAvatar = "yes",
				stages = { student = true, wizard = true },
			})
			t.expect(inv.owned).toEqual({ oxford_white = true })
			t.expect(inv.equipped).toEqual({ top = "oxford_white" })
			t.expect(inv.presets["1"].name).toBe("Work")
			t.expect(inv.presets["1"].equipped).toEqual({ top = "oxford_white" })
			t.expect(inv.presets["9"]).toBeNil()
			t.expect(inv.wearAvatar).toBe(false)
			t.expect(inv.stages).toEqual({ student = true })
			local empty = Inventory.normalize(nil)
			t.expect(count(empty.owned)).toBe(0)
			t.expect(empty.wearAvatar).toBe(false)
		end)

		t.it("grants starters once per stage and dresses a new profile", function()
			local inv = fresh()
			local items, stages, equipped = Inventory.grantStarters(inv, 0)
			t.expect(#stages).toBe(1)
			t.expect(equipped).toBe(true)
			t.expect(inv.equipped).toEqual(Catalog.starter.student)
			for _, id in items do
				t.expect(inv.owned[id]).toBe(true)
			end
			local again = Inventory.grantStarters(inv, 0)
			t.expect(#again).toBe(0)
			-- promoted to analyst: intern and analyst kits arrive, the current look stays on
			local more, newStages, reequipped = Inventory.grantStarters(inv, 2)
			t.expect(#newStages).toBe(2)
			t.expect(reequipped).toBe(false)
			t.expect(table.find(more, "tie_navy") ~= nil).toBeTruthy()
			t.expect(inv.equipped.top).toBe(Catalog.starter.student.top)
		end)

		t.it("equip validates ownership, slot, rank and passes", function()
			local inv = fresh()
			Inventory.grantStarters(inv, 0)
			local student = Inventory.viewer(inv, 0, {})
			t.expect((Inventory.equip(inv, "top", "hoodie_heather", student))).toBeTruthy()
			local ok, err = Inventory.equip(inv, "top", "hoodie_maroon", student)
			t.expect(ok).toBe(false)
			t.expect(err).toBe("not_owned")
			ok, err = Inventory.equip(inv, "bottom", "hoodie_heather", student)
			t.expect(err).toBe("bad_slot")
			ok, err = Inventory.equip(inv, "outer", "co_velvet_dinner", student)
			t.expect(err).toBe("pass")
			ok = Inventory.equip(inv, "outer", "co_velvet_dinner", Inventory.viewer(inv, 0, { CornerOffice = true }))
			t.expect(ok).toBe(true)
			inv.owned.watch_astra_moonphase = true
			ok, err = Inventory.equip(inv, "wrist", "watch_astra_moonphase", student)
			t.expect(err).toBe("rank")
			t.expect((Inventory.equip(inv, "wrist", "watch_astra_moonphase", Inventory.viewer(inv, 6, {})))).toBe(true)
			-- unequip
			t.expect((Inventory.equip(inv, "outer", nil, student))).toBe(true)
			t.expect(inv.equipped.outer).toBeNil()
			-- what goes on the character drops pieces the viewer can't wear right now, without losing them
			local wearable, dropped = Inventory.wearable(inv, student)
			t.expect(wearable.wrist).toBeNil()
			t.expect(dropped).toContain("wrist")
			t.expect(inv.equipped.wrist).toBe("watch_astra_moonphase")
		end)

		t.it("grant adds catalog items once and refuses unknown or NPC pieces", function()
			local inv = fresh()
			t.expect((Inventory.grant(inv, "wk_jacket"))).toBe(true)
			local isNew, err = Inventory.grant(inv, "wk_jacket")
			t.expect(isNew).toBe(false)
			t.expect(err).toBeNil()
			isNew, err = Inventory.grant(inv, "doorman_coat")
			t.expect(isNew).toBe(false)
			t.expect(err).toBe("unknown_item")
			isNew, err = Inventory.grant(inv, 42)
			t.expect(err).toBe("unknown_item")
		end)

		t.it("wearLook puts a rolled look on and takes an unrelated jacket off", function()
			local inv = fresh()
			Inventory.grantStarters(inv, 2)
			inv.equipped.outer = "blazer_navy"
			inv.owned.blazer_navy = true
			local look = Catalog.looks.gl_classic
			for _, id in look.itemIds do
				Inventory.grant(inv, id)
			end
			local changed = Inventory.wearLook(inv, look.itemIds, Inventory.viewer(inv, 2, {}))
			t.expect(changed).toContain("outer")
			t.expect(inv.equipped.outer).toBeNil()
			t.expect(inv.equipped.top).toBe("gl_hoodie_navy")
			t.expect(inv.equipped.shoes).toBe("gl_sneaker_white")
			-- a look with a jacket keeps it on; unowned pieces are skipped
			local wk = Catalog.looks.wk_signature
			local skipped = Inventory.wearLook(inv, wk.itemIds, Inventory.viewer(inv, 2, {}))
			t.expect(#skipped).toBe(0)
			for _, id in wk.itemIds do
				Inventory.grant(inv, id)
			end
			Inventory.wearLook(inv, wk.itemIds, Inventory.viewer(inv, 2, {}))
			t.expect(inv.equipped.outer).toBe("wk_jacket")
			t.expect(inv.equipped.wrist).toBe("wk_watch")
		end)

		t.it("saves and loads presets within the open slots", function()
			local inv = fresh()
			Inventory.grantStarters(inv, 0)
			local free = Inventory.viewer(inv, 0, {})
			t.expect((Inventory.savePreset(inv, 1, "Lecture", free))).toBe(true)
			t.expect(inv.presets["1"].name).toBe("Lecture")
			t.expect(inv.presets["1"].equipped).toEqual(inv.equipped)
			local ok, err = Inventory.savePreset(inv, 3, "Locked", free)
			t.expect(ok).toBe(false)
			t.expect(err).toBe("locked")
			local member = Inventory.viewer(inv, 0, { ExecutiveClub = true })
			t.expect((Inventory.savePreset(inv, 5, nil, member))).toBe(true)
			t.expect(inv.presets["5"].name).toBe("Outfit 5")
			ok, err = Inventory.savePreset(inv, 2, 12, free)
			t.expect(err).toBe("bad_name")
			ok, err = Inventory.savePreset(inv, 0, "x", member)
			t.expect(err).toBe("locked")
			ok, err = Inventory.savePreset(inv, 1.5, "x", member)
			t.expect(err).toBe("locked")
			-- change the look, then load the preset back
			inv.equipped = { top = "hoodie_heather" }
			local loaded, lerr, dropped = Inventory.loadPreset(inv, 1, free)
			t.expect(loaded).toBe(true)
			t.expect(lerr).toBeNil()
			t.expect(#(dropped :: any)).toBe(0)
			t.expect(inv.equipped).toEqual(Catalog.starter.student)
			ok, err = Inventory.loadPreset(inv, 2, free)
			t.expect(err).toBe("empty")
			-- a preset holding a pass piece the player no longer has drops just that piece
			inv.presets["2"] = { name = "Gala", equipped = { top = "oxford_white", outer = "co_velvet_dinner" } }
			inv.owned.oxford_white = true
			local _, _, gone = Inventory.loadPreset(inv, 2, free)
			t.expect(gone).toEqual({ "outer" })
			t.expect(inv.equipped).toEqual({ top = "oxford_white" })
		end)
	end)
end
