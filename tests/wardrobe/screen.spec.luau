-- Wardrobe screen: the pure view model (UI/Screens/Wardrobe/View) and a smoke test of the whole screen under Lune.
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Config.Catalog)
local Signal = require(Shared.Util.Signal)
local Wardrobe = require(Shared.Assets.Wardrobe)
local Theme = require(Client.UI.Theme)
local View = require(Client.UI.Screens.Wardrobe.View)
local Screen = require(Client.UI.Screens.Wardrobe)

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
	function s:set(key: string, value: any)
		values[key] = value
		if signals[key] then
			signals[key]:Fire(value)
		end
	end
	return s
end

local function fakeApi(access: { [string]: any })
	local api = { AccessChanged = Signal.new(), calls = {} }
	function api:GetAccess()
		return access
	end
	function api:Equip(slot, itemId)
		table.insert(self.calls, { "equip", slot, itemId })
		return true, nil
	end
	function api:SetWearAvatar(on)
		table.insert(self.calls, { "avatar", on })
		return true, nil
	end
	function api:SavePreset()
		return true, nil
	end
	function api:LoadPreset()
		return true, nil, 0
	end
	function api:Buy()
		return false, "shop_closed"
	end
	return api
end

local function find(root: Instance, name: string): Instance?
	return root:FindFirstChild(name, true)
end

local function badgeText(badge: Instance?): string?
	local label = badge and badge:FindFirstChild("Text")
	return if label and label:IsA("TextLabel") then label.Text else nil
end

local function open(values: { [string]: any }, access: { [string]: any }, args: any?)
	local root = Instance.new("Frame")
	root.Size = UDim2.fromOffset(1000, 640)
	local store = fakeStore(values)
	local api = fakeApi(access)
	local registry = {
		get = function(name: string)
			return if name == "WardrobeController" then api else nil
		end,
	}
	local handle = Screen.open(args, root, { Registry = registry, Store = store, close = function() end })
	return root, handle, store, api
end

return function(t)
	t.describe("Wardrobe view model", function()
		t.it("labels clothing levels and the Outfit Level", function()
			t.expect(View.levelBadge(Catalog.get("suit_navy_2b") :: any)).toBe("Lv 3")
			t.expect(View.levelBadge(Catalog.get("pm_jacket") :: any)).toBe("Lv 5")
			local o = View.outfit({ outer = "suit_navy_db", bottom = "suit_navy_trousers", shoes = "oxford_black" })
			t.expect(o.level).toBe(3)
			t.expect(o.text).toBe("Outfit Lv 3")
			t.expect(o.held).toBe("Held at Lv 3 by your bottoms and shoes")
			local even = View.outfit({ outer = "suit_navy_2b", bottom = "suit_navy_trousers", shoes = "oxford_black" })
			t.expect(even.held).toBeNil()
			t.expect(View.outfit({ outer = "bespoke_chalk_db", bottom = "bespoke_chalk_trousers" }).held)
				.toBe("Held at Lv 1 by your shoes")
		end)

		t.it("compares the look with the firm's dress code", function()
			local code = View.dressCode(3, 4, "Evermoor") :: any
			t.expect(code.ok).toBe(false)
			t.expect(code.color).toBe("bad")
			t.expect(code.text).toBe("Evermoor dress code: Lv 4")
			t.expect((View.dressCode(4, 4, nil) :: any).ok).toBe(true)
			t.expect((View.dressCode(5, 9, "X") :: any).required).toBe(5)
			t.expect(View.dressCode(3, nil, "X")).toBeNil()
			t.expect(View.dressCode(3, 0 / 0, "X")).toBeNil()
		end)

		t.it("shows EmployeesOnly prompts to employees and merger partners only", function()
			local mine = { companyId = "mg_freeman" }
			t.expect(View.canUsePrompt(mine, nil, "mg_freeman")).toBe(true)
			t.expect(View.canUsePrompt(mine, nil, "evermoor")).toBe(false)
			t.expect(View.canUsePrompt({}, nil, "evermoor")).toBe(false)
			t.expect(View.canUsePrompt(nil, nil, "evermoor")).toBe(false)
			t.expect(View.canUsePrompt(nil, nil, nil)).toBe(true) -- not an office prompt
			local merger = { corporate = { id = "merger_mania", data = { companies = { "mg_freeman", "evermoor" } } } }
			t.expect(View.canUsePrompt(mine, merger, "evermoor")).toBe(true)
			t.expect(View.canUsePrompt(mine, merger, "centerline")).toBe(false)
			local other = { corporate = { id = "bonus_season", data = { companies = { "mg_freeman", "evermoor" } } } }
			t.expect(View.canUsePrompt(mine, other, "evermoor")).toBe(false)
		end)

		t.it("names every rarity and maps unknown errors to the generic text", function()
			for _, r in Catalog.RARITIES do
				t.expect(View.rarity(r).name).toBe(Catalog.text("rarity_" .. r))
			end
			t.expect(View.errorText("funds")).toBe(Catalog.strings.err_funds)
			t.expect(View.errorText("no_such_error")).toBe(Catalog.strings.err_generic)
			t.expect(View.errorText(nil)).toBe(Catalog.strings.err_generic)
		end)
	end)

	t.describe("Wardrobe screen", function()
		do
			t.it("restyles live between the campus (student) and street (employed) themes", function()
				local root, handle = open({
					inventory = { owned = {}, equipped = { top = "qzip_navy" }, presets = {}, wearAvatar = false },
					career = { rank = 0 },
				}, { rank = 0, passes = {} })
				local card = find(root, "Item_qzip_navy") :: TextButton
				local before = card.BackgroundColor3
				Theme.set("campus")
				local campus = card.BackgroundColor3
				Theme.set("street")
				t.expect(card.BackgroundColor3 ~= campus).toBeTruthy()
				t.expect(typeof(before)).toBe("Color3")
				handle.close()
			end)

			t.it("shows a Lv badge on every card and the Outfit Level on the preview", function()
				local root, handle = open({
					inventory = {
						owned = {},
						equipped = { top = "oxford_white", outer = "suit_navy_2b", bottom = "suit_navy_trousers" },
						presets = {},
						wearAvatar = false,
					},
					career = { rank = 1, companyId = "mg_freeman" },
				}, { rank = 1, passes = {} })
				local cards = 0
				for _, item in View.items("top", { owned = {}, rank = 1, passes = {} }) do
					local card = find(root, "Item_" .. item.id)
					if not card then
						error("no card for " .. item.id)
					end
					t.expect(badgeText(card:FindFirstChild("Level"))).toBe("Lv " .. Catalog.levelOf(item))
					cards += 1
				end
				t.expect(cards).toBeGreaterThan(10)
				-- no shoes equipped: the base shoes (Lv 1) hold the outfit down
				t.expect(badgeText(find(root, "OutfitLevel"))).toBe("Outfit Lv 1")
				local held = find(root, "OutfitHeld") :: TextLabel
				t.expect(held.Visible).toBe(true)
				handle.close()
			end)

			t.it("shows the firm's dress code when the player has one", function()
				local root, handle = open({
					inventory = {
						owned = {},
						equipped = { outer = "suit_navy_db", bottom = "suit_navy_trousers", shoes = "oxford_black" },
						presets = {},
						wearAvatar = false,
					},
					career = { rank = 1, companyId = "mg_freeman" },
				}, { rank = 1, passes = {} })
				local code = find(root, "DressCode") :: Frame
				t.expect(code ~= nil).toBeTruthy()
				local text = badgeText(code) or ""
				t.expect(string.find(text, "dress code: Lv", 1, true) ~= nil).toBeTruthy()
				handle.close()
				local student = open({ inventory = {}, career = { rank = 0 } }, { rank = 0, passes = {} })
				t.expect((find(student, "DressCode") :: Frame).Visible).toBe(false)
			end)

			t.it("opens on a deep-linked item (old ids too) and previews the company logo on a vest", function()
				local root, handle = open({
					inventory = {
						owned = { pm_jacket = true },
						equipped = { top = "oxford_white", outer = "vest_fleece" },
						presets = {},
						wearAvatar = false,
					},
					career = { rank = 2, companyId = "mg_freeman" },
				}, { rank = 2, passes = {}, companyLogo = "mg_freeman" }, { slot = "outer", item = "wk_jacket" })
				local card = find(root, "Item_pm_jacket")
				t.expect(card ~= nil).toBeTruthy()
				-- the selected Pan Miller jacket is tried on in the preview: no logo on a suit jacket
				local viewport = find(root, "Viewport") :: ViewportFrame
				local function previewLogo(): number
					local n = 0
					for _, d in viewport:GetDescendants() do
						if d:IsA("BasePart") and string.sub(d.Name, -12) == "_CompanyLogo" then
							n += 1
						end
					end
					return n
				end
				t.expect(previewLogo()).toBe(0)
				-- reset the try-on: the equipped vest shows the company emblem, like the real character
				local reset = find(root, "ResetPreview") :: TextButton
				t.expect(reset ~= nil).toBeTruthy()
				handle.close()
				local root2, handle2 = open({
					inventory = { owned = {}, equipped = { outer = "vest_fleece" }, presets = {}, wearAvatar = false },
					career = { rank = 1, companyId = "mg_freeman" },
				}, { rank = 1, passes = {}, companyLogo = "mg_freeman" })
				local vp = find(root2, "Viewport") :: ViewportFrame
				local found = 0
				for _, d in vp:GetDescendants() do
					if d:IsA("BasePart") and d.Name == "outer_CompanyLogo" then
						found += 1
					end
				end
				t.expect(found).toBe(1)
				local model = vp:FindFirstChildWhichIsA("Model")
				t.expect(model ~= nil and Wardrobe.appliedLogo(model :: Model) == "mg_freeman").toBeTruthy()
				handle2.close()
			end)

			t.it("repaints when the inventory replicates and closes cleanly", function()
				local root, handle, store = open({
					inventory = { owned = {}, equipped = {}, presets = {}, wearAvatar = false },
					career = { rank = 0 },
				}, { rank = 0, passes = {} })
				t.expect(badgeText(find(root, "OutfitLevel"))).toBe("Outfit Lv 1")
				store:set("inventory", {
					owned = {},
					equipped = {
						top = "shirt_bespoke",
						bottom = "bespoke_chalk_trousers",
						shoes = "oxford_bespoke_black",
					},
					presets = {},
					wearAvatar = false,
				})
				t.expect(badgeText(find(root, "OutfitLevel"))).toBe("Outfit Lv 5")
				handle.close()
				handle.close() -- twice is harmless
			end)
		end
	end)
end
