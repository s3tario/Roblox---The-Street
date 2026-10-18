local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Shared = game:GetService("ReplicatedStorage").Shared
local Signal = require(Shared.Util.Signal)
local Rng = require(Shared.Util.Rng)
local TableUtil = require(Shared.Util.TableUtil)
local DataTemplate = require(Shared.Config.DataTemplate)
local Config = require(Shared.Config.LifeRoll)
local LifeRoll = require(Shared.Logic.LifeRoll)
local Theme = require(Client.UI.Theme)
local LifeRollScreen = require(Client.UI.Screens.LifeRoll)
local StatsScreen = require(Client.UI.Screens.Stats)
local StatCard = require(Client.UI.Screens.LifeRollParts.StatCard)
local Odds = require(Client.UI.Screens.LifeRollParts.Odds)
local Reel = require(Client.UI.Screens.LifeRollParts.Reel)
local Common = require(Client.UI.Screens.LifeRollParts.Common)

local function profile(stage: string): any
	local p = LifeRoll.normalize(TableUtil.deepCopy(DataTemplate.template.profile))
	if stage == "fresh" then
		return p
	end
	p.firstName = "Maya"
	LifeRoll.startRoll(p, Rng.new("screens"))
	if stage == "pending" then
		return p
	end
	p.pending.school = { id = "harvale", rarity = "mythic" }
	p.pending.family = { id = "kennerly", rarity = "legendary" }
	p.pending.clubs = { { id = "golf_team", rarity = "mythic" }, { id = "finance_club", rarity = "uncommon" } }
	LifeRoll.lock(p, 1)
	p.credits.rebuild = 1
	return p
end

local function fakeCtx(p: any): any
	local changed = Signal.new()
	local storeData = { profile = p }
	local store = {}
	function store:Get(key: string)
		return storeData[key]
	end
	function store:Changed(_key: string)
		return changed
	end
	local notes = {}
	return {
		Store = store,
		UI = {
			Notify = function(_self, text)
				table.insert(notes, text)
			end,
		},
		close = function() end,
		_changed = changed,
		_data = storeData,
		_notes = notes,
	}
end

local function find(root: Instance, name: string): Instance?
	return root:FindFirstChild(name, true)
end

return function(t)
	for _, themeName in Theme.names do
		t.describe("careerCore screens under " .. themeName, function()
			Theme.set(themeName)

			t.it("LifeRoll opens on the name step for a fresh profile", function()
				local root = Instance.new("Frame")
				local handle = LifeRollScreen.open({}, root, fakeCtx(profile("fresh")))
				t.expect(find(root, "NameInput") ~= nil).toBeTruthy()
				t.expect(find(root, "NameGo") ~= nil).toBeTruthy()
				handle.close()
			end)

			t.it("LifeRoll shows one row per field for a pending roll", function()
				local root = Instance.new("Frame")
				local p = profile("pending")
				local handle = LifeRollScreen.open({}, root, fakeCtx(p))
				for _, field in Config.FIELDS do
					local row = find(root, "Row_" .. field)
					t.expect(row ~= nil).toBeTruthy()
					local final = (row :: Instance):FindFirstChild("Final", true) :: TextLabel?
					t.expect(final ~= nil).toBeTruthy()
					t.expect((final :: TextLabel).Text).toBe(Common.valueText(field, p.pending[field]))
				end
				t.expect(find(root, "Lock") ~= nil).toBeTruthy()
				t.expect(find(root, "Odds") ~= nil).toBeTruthy()
				handle.close()
			end)

			t.it("LifeRoll shows the locked-in card with a Rebuild button", function()
				local root = Instance.new("Frame")
				local ctx = fakeCtx(profile("built"))
				local handle = LifeRollScreen.open({}, root, ctx)
				t.expect(find(root, "StatCard") ~= nil).toBeTruthy()
				t.expect(find(root, "Rebuild") ~= nil).toBeTruthy()
				ctx._changed:Fire(ctx._data.profile) -- live update re-renders without errors
				handle.close()
			end)

			t.it("LifeRoll works with no ctx and with no profile yet", function()
				local root = Instance.new("Frame")
				LifeRollScreen.open(nil, root, nil).close()
				local ctx = fakeCtx(nil)
				local h = LifeRollScreen.open({}, Instance.new("Frame"), ctx)
				ctx._data.profile = profile("fresh")
				ctx._changed:Fire(ctx._data.profile)
				h.close()
			end)

			t.it("Stats shows the card and six focus buttons once built", function()
				local root = Instance.new("Frame")
				local handle = StatsScreen.open({}, root, fakeCtx(profile("built")))
				t.expect(find(root, "StatCard") ~= nil).toBeTruthy()
				for _, def in Config.focus do
					t.expect(find(root, "Focus_" .. def.id) ~= nil).toBeTruthy()
				end
				handle.close()
			end)

			t.it("Stats offers the Life Roll before lock-in", function()
				local root = Instance.new("Frame")
				local handle = StatsScreen.open({}, root, fakeCtx(profile("pending")))
				t.expect(find(root, "StartLifeRoll") ~= nil).toBeTruthy()
				handle.close()
			end)
		end)
	end

	t.describe("StatCard", function()
		t.it("mounts every attribute, the OVR and the background, and cleans up", function()
			local p = profile("built")
			p.weekGrowth = { key = "w1", gains = { skill = 2 } }
			local view = LifeRoll.publicView(p, { userId = 1, displayName = "maya" })
			local container = Instance.new("Frame")
			local cleanup = StatCard.mount(container, view)
			for _, id in Config.STAT_IDS do
				t.expect(find(container, "Stat_" .. id) ~= nil).toBeTruthy()
			end
			local ovr = find(container, "OVR")
			t.expect(ovr ~= nil).toBeTruthy()
			local value = (ovr :: Instance):FindFirstChild("Value") :: TextLabel
			t.expect(value.Text).toBe(tostring(view.ovr))
			t.expect(find(container, "Gain") ~= nil).toBeTruthy()
			t.expect(find(container, "Crest") ~= nil).toBeTruthy()
			t.expect(find(container, "Perk_ivy_network") ~= nil).toBeTruthy()
			cleanup()
			t.expect(find(container, "StatCard")).toBeNil()
			cleanup() -- idempotent
		end)

		t.it("renders an empty or unbuilt view without errors", function()
			StatCard.mount(Instance.new("Frame"), nil)()
			StatCard.mount(Instance.new("Frame"), LifeRoll.publicView(profile("fresh")), { compact = true })()
		end)
	end)

	t.describe("Parts", function()
		t.it("the odds sheet has a section per field", function()
			local parent = Instance.new("Frame")
			Odds.build(parent, 3)
			for _, field in Config.FIELDS do
				t.expect(parent:FindFirstChild("Odds_" .. field) ~= nil).toBeTruthy()
			end
		end)

		t.it("a reel lands on the final value (instantly under Lune)", function()
			local reel = Reel.new()
			local landed = 0
			reel.spin(
				{ text = "Harvale University", rarity = "mythic" },
				Common.reelFiller("school", 12, 1),
				1.5,
				function()
					landed += 1
				end
			)
			t.expect(landed).toBe(1)
			t.expect(reel.isSpinning()).toBe(false)
			local final = reel.frame:FindFirstChild("Final", true) :: TextLabel
			t.expect(final.Text).toBe("Harvale University")
			reel.set({ text = "3.45" })
			reel.destroy()
		end)

		t.it("filler and text helpers cover every field", function()
			local roll = LifeRoll.rollAll(Rng.new(3))
			for _, field in Config.FIELDS do
				t.expect(#Common.reelFiller(field, 10, "x")).toBe(10)
				t.expect(Common.valueText(field, (roll :: any)[field]) ~= "").toBeTruthy()
			end
			t.expect(Common.boostText("school", { id = "harvale" })).toContain("+8 Network")
			t.expect(Common.boostText("gpa", 3.4)).toBe("")
		end)
	end)
end
