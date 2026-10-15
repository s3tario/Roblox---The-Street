local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Shared = game:GetService("ReplicatedStorage").Shared
local Signal = require(Shared.Util.Signal)
local Theme = require(Client.UI.Theme)
local Menu = require(Client.UI.Screens.Menu)
local SettingsScreen = require(Client.UI.Screens.Settings)

-- Minimal stand-in for UIController (the real one needs Roblox services).
local function fakeUI(tabs)
	local ui = {
		MenuTabsChanged = Signal.new(),
		SettingsChanged = Signal.new(),
		tabs = tabs or {},
		activated = {},
		sets = {},
		settings = { music = 0.5, sfx = 0.8, reducedMotion = false, showTicker = true, uiScale = 1 },
	}
	function ui:GetMenuTabs()
		return self.tabs
	end
	function ui:ActivateTab(id)
		table.insert(self.activated, id)
	end
	function ui:GetSettings()
		return table.clone(self.settings)
	end
	function ui:SetSetting(key, value, localOnly)
		table.insert(self.sets, { key, value, localOnly })
		self.settings[key] = value
	end
	function ui:ResetSettings() end
	return ui
end

local function countTiles(root)
	local n = 0
	for _, d in root:GetDescendants() do
		if d.Name:sub(1, 4) == "App_" then
			n += 1
		end
	end
	return n
end

return function(t)
	for _, themeName in Theme.names do
		t.describe("Screens under " .. themeName, function()
			Theme.set(themeName)
			t.it("Menu opens empty and shows the hint", function()
				local root = Instance.new("Frame")
				local closed = false
				local handle = Menu.open({}, root, {
					UI = fakeUI({}),
					close = function()
						closed = true
					end,
				})
				t.expect(type(handle.close)).toBe("function")
				t.expect(countTiles(root)).toBe(0)
				local empty = root:FindFirstChild("Empty", true)
				t.expect(empty ~= nil and empty.Visible).toBeTruthy()
				handle.close()
				t.expect(closed).toBe(false) -- close() doesn't loop back into ctx.close
			end)
			t.it("Menu opens without any ctx at all", function()
				local root = Instance.new("Frame")
				local handle = Menu.open(nil, root, nil)
				handle.close()
			end)
			t.it("Menu builds a tile per tab and rebuilds on change", function()
				local ui = fakeUI({
					{ id = "terminal", title = "Terminal", glyph = "📈", order = 1 },
					{ id = "shop", title = "Shop", order = 2, badge = "1" },
					{ id = "locked", title = "Locked", order = 3, locked = true },
				})
				local root = Instance.new("Frame")
				local handle = Menu.open({}, root, { UI = ui, close = function() end })
				t.expect(countTiles(root)).toBe(3)
				table.insert(ui.tabs, { id = "settings", title = "Settings", order = 1000 })
				ui.MenuTabsChanged:Fire()
				t.expect(countTiles(root)).toBe(4)
				handle.close()
			end)
			t.it("Settings opens with every field and reports the current values", function()
				local ui = fakeUI()
				local root = Instance.new("Frame")
				local handle = SettingsScreen.open({}, root, { UI = ui, close = function() end })
				for _, field in SettingsScreen.fields do
					t.expect(root:FindFirstChild("Setting_" .. field.key, true) ~= nil).toBeTruthy()
				end
				ui.settings.music = 0.25
				ui.SettingsChanged:Fire(ui:GetSettings())
				handle.close()
			end)
			t.it("Settings works with only Net in ctx", function()
				local sent = {}
				local root = Instance.new("Frame")
				local handle = SettingsScreen.open({}, root, {
					Net = {
						send = function(...)
							table.insert(sent, { ... })
						end,
					},
				})
				handle.close()
				t.expect(#sent).toBe(0)
			end)
		end)
	end
end
