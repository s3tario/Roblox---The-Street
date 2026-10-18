-- Housing rules (Logic/Economy/Housing): slot-kind compatibility, contexts, rank gates, size limits, the part
-- budget, one copy per context, themes and the Office Theme Pass.

local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Logic.Economy)
local Decor = require(Shared.Config.Decor)
local Props = require(Shared.Assets.Props)
local Housing = Economy.Housing

local function partsFor(propId: string): number
	local info = Props.get(propId)
	return if info then info.maxParts else 0
end

local function footprintFor(propId: string): Vector3?
	local info = Props.get(propId)
	return if info then info.footprint else nil
end

local function owning(ids: { string }): Housing.HousingData
	local h = Housing.normalize({})
	for _, id in ids do
		h.owned[id] = true
	end
	return h
end

local OPTS = { rank = 5, partsFor = partsFor, footprintFor = footprintFor }

return function(t)
	t.describe("normalize", function()
		t.it("fills every context and drops junk", function()
			local h = Housing.normalize({
				owned = { desk_mug_navy = true, [5] = true, bad = false },
				placed = { desk = { s1 = "desk_mug_navy", [3] = "x" }, nowhere = { a = "b" } },
				theme = { office = "walnut", desk = "nope", apartment = "nope" },
			})
			t.expect(h.owned.desk_mug_navy).toBe(true)
			t.expect(h.owned.bad).toBeNil()
			for ctx in Decor.CONTEXTS do
				t.expect(type(h.placed[ctx])).toBe("table")
			end
			t.expect(h.placed.desk.s1).toBe("desk_mug_navy")
			t.expect((h.placed :: any).nowhere).toBeNil()
			t.expect(h.theme.office).toBe("walnut")
			t.expect(h.theme.apartment).toBeNil()
		end)
	end)

	t.describe("slot-kind compatibility", function()
		t.it("each placeable kind takes its own items", function()
			t.expect(Housing.accepts("desk_item", Decor.get("desk_mug_navy"))).toBe(true)
			t.expect(Housing.accepts("wall_art", Decor.get("art_print_skyline"))).toBe(true)
			t.expect(Housing.accepts("rug", Decor.get("rug_persian_navy"))).toBe(true)
			t.expect(Housing.accepts("plant", Decor.get("plant_fig"))).toBe(true)
			t.expect(Housing.accepts("lamp", Decor.get("lamp_floor_brass"))).toBe(true)
			t.expect(Housing.accepts("floor", Decor.get("furn_armchair"))).toBe(true)
		end)
		t.it("floor spots also take floor plants and lamps, but not the other way round", function()
			t.expect(Housing.accepts("floor", Decor.get("plant_fig"))).toBe(true)
			t.expect(Housing.accepts("floor", Decor.get("lamp_arc_chrome"))).toBe(true)
			t.expect(Housing.accepts("plant", Decor.get("furn_armchair"))).toBe(false)
			t.expect(Housing.accepts("lamp", Decor.get("plant_fig"))).toBe(false)
		end)
		t.it("mismatches are refused", function()
			t.expect(Housing.accepts("desk_item", Decor.get("furn_armchair"))).toBe(false)
			t.expect(Housing.accepts("wall_art", Decor.get("desk_mug_navy"))).toBe(false)
			t.expect(Housing.accepts("rug", Decor.get("furn_armchair"))).toBe(false)
			t.expect(Housing.accepts("floor", Decor.get("rug_round_sand"))).toBe(false)
		end)
		t.it("plaque slots never take player decor", function()
			for _, item in Decor.list() do
				t.expect(Housing.accepts("plaque", item)).toBe(false)
			end
		end)
		t.it("unknown slot kinds and items are refused", function()
			t.expect(Housing.accepts("ceiling", Decor.get("desk_mug_navy"))).toBe(false)
			t.expect(Housing.accepts("desk_item", nil)).toBe(false)
		end)
	end)

	t.describe("checkPlace", function()
		local deskSlot = { id = "desk_item_1", kind = "desk_item" }
		local floorSlot = { id = "floor_1", kind = "floor" }
		local wallSlot = { id = "wall_art_1", kind = "wall_art" }
		t.it("places an owned item that fits", function()
			local h = owning({ "desk_mug_navy" })
			t.expect((Housing.checkPlace(h, "desk", deskSlot, "desk_mug_navy", OPTS))).toBe(true)
		end)
		t.it("refuses items the player doesn't own", function()
			local h = owning({})
			local ok, err = Housing.checkPlace(h, "desk", deskSlot, "desk_mug_navy", OPTS)
			t.expect(ok).toBe(false)
			t.expect(err).toBe("not_owned")
		end)
		t.it("refuses the wrong slot kind, unknown items, slots and contexts", function()
			local h = owning({ "desk_mug_navy", "furn_armchair" })
			t.expect(select(2, Housing.checkPlace(h, "desk", deskSlot, "furn_armchair", OPTS))).toBe("wrong_kind")
			t.expect(select(2, Housing.checkPlace(h, "desk", deskSlot, "ghost", OPTS))).toBe("unknown_item")
			t.expect(select(2, Housing.checkPlace(h, "desk", nil, "desk_mug_navy", OPTS))).toBe("bad_slot")
			t.expect(select(2, Housing.checkPlace(h, "moon", deskSlot, "desk_mug_navy", OPTS))).toBe("no_context")
			t.expect(select(2, Housing.checkPlace(h, "desk", { id = "p1", kind = "plaque" }, "desk_mug_navy", OPTS)))
				.toBe("wrong_kind")
		end)
		t.it("respects an item's contexts (no grand piano on the open-plan floor)", function()
			local h = owning({ "furn_leather_sofa", "campus_pizza_box" })
			t.expect(select(2, Housing.checkPlace(h, "desk", floorSlot, "furn_leather_sofa", OPTS))).toBe("context")
			t.expect((Housing.checkPlace(h, "apartment", floorSlot, "furn_leather_sofa", OPTS))).toBe(true)
			t.expect(select(2, Housing.checkPlace(h, "office", floorSlot, "campus_pizza_box", OPTS))).toBe("context")
			t.expect((Housing.checkPlace(h, "dorm", floorSlot, "campus_pizza_box", OPTS))).toBe(true)
		end)
		t.it("enforces rank gates on prestige pieces", function()
			local h = owning({ "art_canvas_masterwork" })
			local low = { rank = 3, partsFor = partsFor }
			t.expect(select(2, Housing.checkPlace(h, "office", wallSlot, "art_canvas_masterwork", low))).toBe("rank")
			t.expect((Housing.checkPlace(h, "office", wallSlot, "art_canvas_masterwork", OPTS))).toBe(true)
		end)
		t.it("enforces slot size limits (an item may turn to fit)", function()
			local h = owning({ "furn_grand_piano", "plant_fig" })
			local small = { id = "floor_2", kind = "floor", limits = { width = 4, depth = 4, height = 8 } }
			t.expect(select(2, Housing.checkPlace(h, "office", small, "furn_grand_piano", OPTS))).toBe("too_big")
			t.expect((Housing.checkPlace(h, "office", small, "plant_fig", OPTS))).toBe(true)
			t.expect(Housing.fits(Vector3.new(6, 2, 2), { width = 2, depth = 6 })).toBe(true) -- turned
			t.expect(Housing.fits(Vector3.new(6, 2, 2), { width = 2, depth = 2 })).toBe(false)
			t.expect(Housing.fits(Vector3.new(6, 9, 2), { height = 8 })).toBe(false)
			t.expect(Housing.fits(nil, { width = 1 })).toBe(true)
		end)
		t.it("keeps each context inside its part budget", function()
			local h = owning({ "furn_aquarium", "furn_trophy_shelf" })
			local tight = { rank = 5, partsFor = partsFor, budget = partsFor("aquarium") + 5 }
			t.expect((Housing.checkPlace(h, "office", floorSlot, "furn_aquarium", tight))).toBe(true)
			Housing.place(h, "office", "floor_1", "furn_aquarium")
			t.expect(
				select(
					2,
					Housing.checkPlace(h, "office", { id = "floor_9", kind = "floor" }, "furn_trophy_shelf", tight)
				)
			)
				.toBe("budget")
			-- replacing the item in the same slot frees its parts first
			t.expect(
				(
					Housing.checkPlace(
						h,
						"office",
						floorSlot,
						"furn_trophy_shelf",
						{ rank = 5, partsFor = partsFor, budget = 45 }
					)
				)
			).toBe(true)
		end)
		t.it("budget ignores placements in slots that no longer exist", function()
			local h = owning({ "furn_aquarium", "furn_trophy_shelf" })
			h.placed.office.gone_slot = "furn_aquarium"
			local opts = {
				rank = 5,
				partsFor = partsFor,
				budget = partsFor("trophy_shelf"),
				slots = { floorSlot },
			}
			t.expect((Housing.checkPlace(h, "office", floorSlot, "furn_trophy_shelf", opts))).toBe(true)
		end)
		t.it("clearing a slot is always allowed", function()
			t.expect((Housing.checkPlace(owning({}), "desk", deskSlot, nil, OPTS))).toBe(true)
		end)
	end)

	t.describe("place", function()
		t.it("writes and clears a slot", function()
			local h = owning({ "desk_mug_navy" })
			t.expect(Housing.place(h, "desk", "a", "desk_mug_navy")).toBeNil()
			t.expect(h.placed.desk.a).toBe("desk_mug_navy")
			Housing.place(h, "desk", "a", nil)
			t.expect(h.placed.desk.a).toBeNil()
		end)
		t.it("moves an item already standing elsewhere in the same context", function()
			local h = owning({ "desk_mug_navy" })
			Housing.place(h, "desk", "a", "desk_mug_navy")
			Housing.place(h, "office", "x", "desk_mug_navy") -- other contexts keep their own copy
			t.expect(Housing.place(h, "desk", "b", "desk_mug_navy")).toBe("a")
			t.expect(h.placed.desk.a).toBeNil()
			t.expect(h.placed.desk.b).toBe("desk_mug_navy")
			t.expect(h.placed.office.x).toBe("desk_mug_navy")
		end)
	end)

	t.describe("visible", function()
		t.it("draws only owned, matching, allowed items in live slots", function()
			local h = owning({ "desk_mug_navy", "furn_armchair" })
			h.placed.desk = { a = "desk_mug_navy", b = "furn_armchair", c = "ghost", d = "desk_mug_navy" }
			local slots = { { id = "a", kind = "desk_item" }, { id = "b", kind = "desk_item" } }
			local out = Housing.visible(h, "desk", slots, 1, partsFor)
			t.expect(out.a).toBe(Decor.get("desk_mug_navy"))
			t.expect(out.b).toBeNil()
			t.expect(out.c).toBeNil()
		end)
		t.it("drops items that are no longer owned or above the player's rank", function()
			local h = owning({})
			h.placed.office = { a = "desk_bull_bear" }
			t.expect(Housing.visible(h, "office", { { id = "a", kind = "desk_item" } }, 5).a).toBeNil()
			h.owned.desk_bull_bear = true
			t.expect(Housing.visible(h, "office", { { id = "a", kind = "desk_item" } }, 1).a).toBeNil()
			t.expect(Housing.visible(h, "office", { { id = "a", kind = "desk_item" } }, 2).a).toBeTruthy()
		end)
	end)

	t.describe("themes", function()
		t.it("only themed contexts take a theme", function()
			t.expect(select(2, Housing.checkTheme("desk", "walnut", {}))).toBe("not_themed")
			t.expect((Housing.checkTheme("office", "walnut", {}))).toBe(true)
			t.expect((Housing.checkTheme("apartment", "slate", {}))).toBe(true)
			t.expect(select(2, Housing.checkTheme("office", "nope", {}))).toBe("bad_theme")
			t.expect(select(2, Housing.checkTheme("moon", "walnut", {}))).toBe("no_context")
		end)
		t.it("pass themes need the Office Theme Pass", function()
			t.expect(select(2, Housing.checkTheme("office", "art_deco", {}))).toBe("pass")
			t.expect((Housing.checkTheme("office", "art_deco", { OfficeThemes = true }))).toBe(true)
		end)
		t.it("setTheme stores non-default themes and themeOf falls back safely", function()
			local h = owning({})
			Housing.setTheme(h, "office", "art_deco")
			t.expect(h.theme.office).toBe("art_deco")
			t.expect(Housing.themeOf(h, "office", { OfficeThemes = true }).id).toBe("art_deco")
			t.expect(Housing.themeOf(h, "office", {}).id).toBe(Decor.DEFAULT_THEME) -- pass gone
			Housing.setTheme(h, "office", Decor.DEFAULT_THEME)
			t.expect(h.theme.office).toBeNil()
			t.expect(Housing.themeOf(h, "desk", {}).id).toBe(Decor.DEFAULT_THEME)
		end)
	end)
end
