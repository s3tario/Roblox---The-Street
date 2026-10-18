-- Shop and decor configuration: every decor prop exists in Props.list() with the mount its slot kinds need, every
-- slot kind is covered, prices follow the spec §11 anchors, themes are well formed (incl. Office Theme Pass ones),
-- every placed prop fits its context's part budget, and every string the services use exists.

local Shared = game:GetService("ReplicatedStorage").Shared
local Decor = require(Shared.Config.Decor)
local Shop = require(Shared.Config.Shop)
local Props = require(Shared.Assets.Props)
local Wallet = require(Shared.Config.DataTemplate.Wallet)
local HousingTemplate = require(Shared.Config.DataTemplate.Housing)

return function(t)
	local propInfo: { [string]: any } = {}
	for _, info in Props.list() do
		propInfo[info.id] = info
	end

	t.describe("decor catalogue", function()
		t.it("has 40+ items", function()
			t.expect(#Decor.list() >= 40).toBe(true)
		end)
		t.it("every item's prop exists in Props.list()", function()
			for _, item in Decor.list() do
				if propInfo[item.prop] == nil then
					error(("%s uses unknown prop %s"):format(item.id, item.prop))
				end
			end
		end)
		t.it("every item's prop has the mount its slot kinds need", function()
			for _, item in Decor.list() do
				local mount = propInfo[item.prop].mount
				for _, kind in item.slots do
					t.expect(Decor.MOUNT_FOR[kind]).toBe(mount)
				end
			end
		end)
		t.it("every placeable slot kind has items", function()
			local seen: { [string]: number } = {}
			for _, item in Decor.list() do
				t.expect(#item.slots > 0).toBe(true)
				for _, kind in item.slots do
					t.expect(table.find(Decor.PLACEABLE, kind) ~= nil).toBe(true)
					seen[kind] = (seen[kind] or 0) + 1
				end
			end
			for _, kind in Decor.PLACEABLE do
				if (seen[kind] or 0) < 3 then
					error("too few items for slot kind " .. kind)
				end
			end
		end)
		t.it("every slot kind has a label, a mount and an accept rule", function()
			for _, kind in Decor.SLOT_KINDS do
				t.expect(type(Decor.KIND_LABELS[kind])).toBe("string")
				t.expect(type(Decor.MOUNT_FOR[kind])).toBe("string")
				t.expect(type(Decor.ACCEPTS[kind])).toBe("table")
			end
		end)
		t.it("prices sit inside the spec §11 anchors for their category", function()
			for _, item in Decor.list() do
				local range = Decor.PRICE_RANGES[item.category]
				if range == nil then
					error("no price range for category " .. item.category)
				end
				if item.price < range[1] or item.price > range[2] then
					error(("%s costs %d, outside %d..%d"):format(item.id, item.price, range[1], range[2]))
				end
				t.expect(item.currency).toBe("cash")
			end
		end)
		t.it("each shop category tab has stock and categories are known", function()
			local cats: { [string]: boolean } = {}
			for _, c in Decor.CATEGORIES do
				cats[c.id] = true
				t.expect(#Decor.byCategory(c.id) > 0).toBe(true)
			end
			for _, item in Decor.list() do
				t.expect(cats[item.category]).toBe(true)
			end
		end)
		t.it("item contexts are real contexts, and every item fits at least one context's budget", function()
			for _, item in Decor.list() do
				for _, ctx in item.contexts or {} do
					t.expect(Decor.CONTEXTS[ctx] ~= nil).toBe(true)
				end
				local fits = false
				for ctx, def in Decor.CONTEXTS do
					if Decor.allowedIn(item, ctx) and propInfo[item.prop].maxParts <= def.budget then
						fits = true
					end
				end
				if not fits then
					error(item.id .. " fits no context budget")
				end
			end
		end)
		t.it("ids are unique and lookups work", function()
			local seen: { [string]: boolean } = {}
			for _, item in Decor.list() do
				t.expect(seen[item.id]).toBeNil()
				seen[item.id] = true
				t.expect(Decor.get(item.id)).toBe(item)
				t.expect(#item.name > 0).toBe(true)
				t.expect(#item.desc > 0).toBe(true)
			end
			t.expect(Decor.get("nope")).toBeNil()
			t.expect(Decor.get(5)).toBeNil()
		end)
		t.it("every decor prop builds under Lune within its part budget", function()
			for _, item in Decor.list() do
				local m = Props.build(item.prop, nil, CFrame.new(10, 2, 3), item.opts)
				local parts = 0
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						parts += 1
					end
				end
				-- Root + the prop's own parts
				t.expect(parts <= propInfo[item.prop].maxParts + 1).toBe(true)
				m:Destroy()
			end
		end)
	end)

	t.describe("themes", function()
		t.it("has free themes and Office Theme Pass themes", function()
			local free, pass = 0, 0
			for _, th in Decor.themes do
				if th.pass then
					t.expect(th.pass).toBe(Decor.THEME_PASS)
					pass += 1
				else
					free += 1
				end
			end
			t.expect(free >= 3).toBe(true)
			t.expect(pass >= 4).toBe(true)
			t.expect(Decor.theme(Decor.DEFAULT_THEME)).toBeTruthy()
		end)
		t.it("every non-default theme sets walls and floors with valid colours", function()
			for _, th in Decor.themes do
				if th.id ~= Decor.DEFAULT_THEME then
					for _, surf in { th.wall, th.floor } do
						t.expect(surf ~= nil).toBe(true)
						local s = surf :: Decor.Surface
						t.expect(string.match(s.color, "^#%x%x%x%x%x%x$") ~= nil).toBe(true)
						t.expect(typeof(s.material)).toBe("EnumItem")
					end
				end
			end
		end)
	end)

	t.describe("contexts", function()
		t.it("dorm, apartment, desk and office exist with budgets", function()
			for _, id in Decor.CONTEXT_ORDER do
				local c = Decor.CONTEXTS[id]
				t.expect(c ~= nil).toBe(true)
				t.expect(c.budget > 0).toBe(true)
			end
			t.expect(Decor.CONTEXTS.desk.themed).toBe(false)
			t.expect(Decor.CONTEXTS.office.themed).toBe(true)
		end)
		t.it("the housing template has a placed table per context", function()
			for id in Decor.CONTEXTS do
				t.expect(type(HousingTemplate.housing.placed[id])).toBe("table")
			end
			t.expect(Wallet.wallet.cash).toBe(0)
		end)
	end)

	t.describe("shops and strings", function()
		t.it("has the five shops", function()
			for _, id in { "tailor", "watch", "shoes", "decor", "campus_store" } do
				local s = Shop.get(id)
				t.expect(s ~= nil).toBe(true)
				t.expect(#(s :: Shop.ShopDef).tabs > 0).toBe(true)
			end
		end)
		t.it("every error key has text", function()
			for _, err in
				{
					"unknown_item",
					"not_for_sale",
					"owned",
					"rank",
					"pass",
					"funds",
					"not_loaded",
					"shop",
					"bad_shop",
					"grant",
					"roll",
					"heirloom",
					"busy",
					"not_owned",
					"bad_slot",
					"wrong_kind",
					"context",
					"too_big",
					"budget",
					"no_context",
					"not_live",
					"bad_theme",
					"not_themed",
					"timeout",
					"rate_limited",
				}
			do
				if Shop.strings["err_" .. err] == nil then
					error("missing err_" .. err)
				end
			end
			t.expect(Shop.errorText("zzz")).toBe(Shop.strings.err_generic)
		end)
		t.it("text fills placeholders and leaves unknown ones", function()
			t.expect(Shop.text("bought", { name = "Mug", price = "$50" })).toBe("Bought Mug for $50.")
			t.expect(Shop.text("bought", { name = "Mug" })).toBe("Bought Mug for {price}.")
			t.expect(Shop.text("no_such_key")).toBe("no_such_key")
		end)
	end)
end
