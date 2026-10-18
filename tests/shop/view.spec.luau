-- Shop and Housing screens: the pure view models (UI/Screens/ShopParts/View, HousingView) and smoke tests that open
-- both screens under Lune with fake Store / ShopController / UIController.

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Shared = game:GetService("ReplicatedStorage").Shared
local Signal = require(Shared.Util.Signal)
local Shop = require(Shared.Config.Shop)
local Decor = require(Shared.Config.Decor)
local Catalog = require(Shared.Config.Catalog)
local View = require(Client.UI.Screens.ShopParts.View)
local HousingView = require(Client.UI.Screens.ShopParts.HousingView)
local ShopScreen = require(Client.UI.Screens.Shop)
local HousingScreen = require(Client.UI.Screens.Housing)

local function wearable(id: string): View.Entry
	return { kind = "wearable", item = Catalog.get(id) }
end

local function decor(id: string): View.Entry
	return { kind = "decor", item = Decor.get(id) }
end

local function viewer(over: { [string]: any }?): View.Viewer
	local v: { [string]: any } = { owned = {}, decor = {}, rank = 1, passes = {}, cash = 5000, track = "ib" }
	for k, x in over or {} do
		v[k] = x
	end
	return v :: any
end

local function fakeStore(values: { [string]: any })
	local signals: { [string]: any } = {}
	local s = {}
	function s:Get(key: string)
		return values[key]
	end
	function s:Changed(key: string)
		signals[key] = signals[key] or Signal.new()
		return signals[key]
	end
	function s:GetGlobal(_key: string)
		return nil
	end
	return s
end

local function find(root: Instance, name: string): Instance?
	return root:FindFirstChild(name, true)
end

local raw = {
	contexts = {
		{
			id = "apartment",
			held = true,
			live = true,
			where = "Unit 3",
			theme = "walnut",
			budget = 320,
			used = 30,
			slots = { { id = "floor_1", kind = "floor" }, { id = "floor_2", kind = "floor" } },
			plaqueSlots = 0,
		},
		{
			id = "desk",
			held = true,
			live = true,
			where = "Desk 5",
			budget = 90,
			used = 0,
			slots = { { id = "desk_item_1", kind = "desk_item" } },
			plaqueSlots = 3,
			plaquesShown = 2,
		},
		{ id = "bogus" },
	},
}

return function(t)
	t.describe("View.cardState", function()
		t.it("prices an affordable item and offers Buy", function()
			local s = View.cardState(wearable("suit_navy_2b"), viewer(), 0, {})
			t.expect(s.state).toBe("buy")
			t.expect(s.badge).toBe("$1,500")
			t.expect(s.action).toBe("buy")
			t.expect(s.enabled).toBe(true)
			t.expect(s.actionText).toBe(Shop.text("buy_price", { price = "$1,500" }))
		end)
		t.it("shows the sale price and the old one", function()
			local s = View.cardState(wearable("suit_navy_2b"), viewer(), 0.25, {})
			t.expect(s.price).toBe(1125)
			t.expect(s.badge).toBe("$1,125")
			t.expect(s.wasText).toBe(Shop.text("price_was", { price = "$1,500" }))
		end)
		t.it("says how much cash is missing", function()
			local s = View.cardState(wearable("suit_navy_2b"), viewer({ cash = 1200 }), 0, {})
			t.expect(s.enabled).toBe(false)
			t.expect(s.badgeColor).toBe("bad")
			t.expect(s.actionText).toBe(Shop.text("buy_short", { missing = "$300" }))
		end)
		t.it("owned clothing offers Wear, worn clothing shows Wearing", function()
			local v = viewer({ owned = { suit_navy_2b = true } })
			t.expect(View.cardState(wearable("suit_navy_2b"), v, 0, {}).action).toBe("wear")
			local worn = View.cardState(wearable("suit_navy_2b"), v, 0, { outer = "suit_navy_2b" })
			t.expect(worn.state).toBe("wearing")
			t.expect(worn.action).toBe("none")
		end)
		t.it("owned decor offers Place", function()
			local s = View.cardState(decor("desk_mug_navy"), viewer({ decor = { desk_mug_navy = true } }), 0, {})
			t.expect(s.action).toBe("place")
		end)
		t.it("rank-gated items name the title they need", function()
			local s = View.cardState(wearable("suit_pinstripe_2b"), viewer({ rank = 1 }), 0, {})
			t.expect(s.state).toBe("rank")
			t.expect(s.locked).toBe(true)
			t.expect(s.enabled).toBe(false)
			t.expect(s.badge).toBe(Shop.text("requires_rank", { title = "Associate" }))
		end)
		t.it("pass items point to the Store", function()
			local s = View.cardState(wearable("co_velvet_dinner"), viewer(), 0, {})
			t.expect(s.state).toBe("pass")
			t.expect(s.action).toBe("pass")
			t.expect(s.badge).toBe(Shop.passName("CornerOffice"))
		end)
	end)

	t.describe("View helpers", function()
		t.it("picks the right default shop", function()
			t.expect(View.defaultShop(nil, true)).toBe("campus_store")
			t.expect(View.defaultShop(nil, false)).toBe("tailor")
			t.expect(View.defaultShop("watch", true)).toBe("watch")
			t.expect(View.defaultShop("nope", false)).toBe("tailor")
		end)
		t.it("shows clothing levels and the firm's dress code", function()
			t.expect(View.levelBadge(wearable("suit_navy_2b"))).toBe("Lv 3")
			t.expect(View.levelBadge(decor("desk_mug_navy"))).toBeNil()
			local note, ok = View.levelNote(wearable("suit_navy_2b"), 4)
			t.expect(note).toBe(Shop.text("level_below", { level = 4 }))
			t.expect(ok).toBe(false)
			t.expect((View.levelNote(wearable("bespoke_midnight_2b"), 4))).toBe(Shop.text("level_meets", { level = 4 }))
			t.expect(View.dressLine({ firmLevel = 4, outfitLevel = 3 }))
				.toBe(Shop.text("dress_firm_short", { level = 4, current = 3 }))
			t.expect(View.dressLine({ student = true, outfitLevel = 1 }))
				.toBe(Shop.text("dress_student", { level = Shop.STUDENT_TARGET_LEVEL, current = 1 }))
		end)
		t.it("describes decor and sales", function()
			t.expect(View.saleBadge(0.25)).toBe("Sale -25%")
			t.expect(View.saleBadge(0)).toBeNil()
			t.expect(View.decorWhere(Decor.get("desk_mug_navy") :: Decor.Item)).toBe(Shop.text("decor_everywhere"))
			t.expect(
				string.find(View.decorFits(Decor.get("plant_fig") :: Decor.Item), Decor.KIND_LABELS.floor, 1, true)
					~= nil
			)
				.toBe(true)
			t.expect(View.rarity(decor("art_canvas_masterwork")).name).toBe("Mythic")
			t.expect(View.rarity(decor("desk_mug_navy")).name).toBe("Common")
		end)
		t.it("swaps the selected piece into the preview look", function()
			local look = View.previewLook({ outer = "a", top = "b" }, Catalog.get("suit_navy_2b"))
			t.expect(look.outer).toBe("suit_navy_2b")
			t.expect(look.top).toBe("b")
		end)
	end)

	t.describe("HousingView", function()
		t.it("orders contexts and drops unknown ones", function()
			local list = HousingView.contexts(raw)
			t.expect(#list).toBe(2)
			t.expect(list[1].id).toBe("desk")
			t.expect(list[2].id).toBe("apartment")
		end)
		t.it("lists spots with what stands there", function()
			local list = HousingView.contexts(raw)
			local rows = HousingView.rows(list[2], { placed = { apartment = { floor_2 = "furn_armchair" } } })
			t.expect(#rows).toBe(2)
			t.expect(rows[1].text).toBe(Shop.text("housing_empty_slot"))
			t.expect(rows[2].label).toBe(Decor.KIND_LABELS.floor .. " 2")
			t.expect(rows[2].text).toBe("Club Armchair")
		end)
		t.it("offers only owned pieces that fit the spot and the place", function()
			local h =
				{ owned = { furn_armchair = true, plant_fig = true, desk_mug_navy = true, furn_leather_sofa = true } }
			local ids = {}
			for _, item in HousingView.candidates("desk", "floor", h, 1) do
				table.insert(ids, item.id)
			end
			table.sort(ids)
			t.expect(ids).toEqual({ "furn_armchair", "plant_fig" }) -- the sofa isn't allowed at a desk
			t.expect(#HousingView.candidates("desk", "desk_item", h, 1)).toBe(1)
			t.expect(#HousingView.candidates("desk", "plaque", h, 1)).toBe(0)
		end)
		t.it("marks pass themes locked without the Office Theme Pass", function()
			local cv = HousingView.contexts(raw)[2]
			local locked, selected = 0, nil
			for _, th in HousingView.themes(cv, {}) do
				if th.locked then
					locked += 1
				end
				if th.selected then
					selected = th.id
				end
			end
			t.expect(locked > 0).toBe(true)
			t.expect(selected).toBe("walnut")
			for _, th in HousingView.themes(cv, { OfficeThemes = true }) do
				t.expect(th.locked).toBe(false)
			end
			t.expect(#HousingView.themes(HousingView.contexts(raw)[1], {})).toBe(0) -- desks aren't themed
		end)
		t.it("summarises budget, plaques and where to go", function()
			local desk = HousingView.contexts(raw)[1]
			local f, text = HousingView.budget(desk)
			t.expect(f).toBe(0)
			t.expect(text).toBe(Shop.text("housing_budget", { used = 0, budget = 90 }))
			t.expect(HousingView.plaqueLine(desk, 2)).toBe(Shop.text("housing_plaques", { shown = 2, total = 2 }))
			t.expect(HousingView.plaqueLine(desk, 0)).toBe(Shop.text("housing_plaques_none"))
			t.expect(HousingView.status(desk)).toBe("Desk 5")
			local away = table.clone(desk)
			away.live = false
			t.expect(HousingView.status(away)).toBe(Shop.text("housing_not_live", { where = "Desk 5" }))
		end)
	end)

	t.describe("screens under Lune", function()
		t.it("the Shop screen builds, lists the shop and selects an item", function()
			local root = Instance.new("Frame")
			root.Size = UDim2.fromOffset(1000, 640)
			local store = fakeStore({
				inventory = { owned = {}, equipped = { outer = "suit_navy_2b" } },
				housing = { owned = {}, placed = {}, theme = {} },
				wallet = { cash = 2000 },
				career = { rank = 1, track = "ib", companyId = "mg_freeman", status = "active" },
			})
			local api = { InfoChanged = Signal.new() }
			function api:GetInfo()
				return { cash = 2000, discount = 0.25, firmLevel = 3, outfitLevel = 3, passes = {}, rank = 1 }
			end
			local handle = ShopScreen.open({ shopId = "tailor", item = "suit_navy_db" }, root, {
				Registry = {
					get = function(name: string)
						return if name == "ShopController" then api else nil
					end,
				},
				Store = store,
				close = function() end,
			})
			t.expect(find(root, "Item_suit_navy_db") ~= nil).toBe(true)
			t.expect(find(root, "ShopTabs") ~= nil).toBe(true)
			local nameLabel = find(root, "Name") :: TextLabel
			t.expect(nameLabel ~= nil).toBe(true)
			local preview = find(root, "Viewport") :: Instance
			t.expect(#preview:GetChildren() >= 2).toBe(true) -- camera, plinth (+ the figure)
			handle.close()
		end)
		t.it("the decor shop previews a prop", function()
			local root = Instance.new("Frame")
			local handle = ShopScreen.open(
				{ shopId = "decor" },
				root,
				{ Store = fakeStore({}), close = function() end }
			)
			t.expect(find(root, "Item_desk_mug_navy") ~= nil).toBe(true)
			handle.close()
		end)
		t.it("the Housing screen builds without a controller", function()
			local root = Instance.new("Frame")
			local handle = HousingScreen.open({}, root, { Store = fakeStore({}), close = function() end })
			t.expect(find(root, "HousingWindow") ~= nil).toBe(true)
			handle.close()
		end)
		t.it("the Housing screen shows the requested place and its spots", function()
			local root = Instance.new("Frame")
			root.Size = UDim2.fromOffset(800, 600)
			local api = { HousingChanged = Signal.new(), opened = nil :: string? }
			function api:GetHousing()
				return { loaded = true, rank = 1, passes = {}, plaqueCount = 2, contexts = raw.contexts }, nil
			end
			function api:Open(shopId: string?)
				self.opened = shopId
			end
			local store = fakeStore({ housing = { owned = {}, placed = { desk = { desk_item_1 = "desk_mug_navy" } } } })
			local handle = HousingScreen.open({ context = "desk" }, root, {
				Registry = {
					get = function(name: string)
						return if name == "ShopController" then api else nil
					end,
				},
				Store = store,
				close = function() end,
			})
			local spot = find(root, "Spot_desk_item_1")
			t.expect(spot ~= nil).toBe(true)
			local text = (spot :: Instance):FindFirstChild("Text") :: TextLabel
			t.expect(string.find(text.Text, "Street Mug", 1, true) ~= nil).toBe(true)
			t.expect(find(root, "Budget") ~= nil).toBe(true)
			t.expect(find(root, "Plaques") ~= nil).toBe(true)
			handle.close()
		end)
	end)
end
