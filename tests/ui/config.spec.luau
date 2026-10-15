local Shared = game:GetService("ReplicatedStorage").Shared
local Server = game:GetService("ServerScriptService").Server
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Strings = require(Shared.Config.Strings)
local Sounds = require(Shared.Config.Sounds)
local SettingsTemplate = require(Shared.Config.DataTemplate.Settings)
local DataTemplate = require(Shared.Config.DataTemplate)
local SettingsService = require(Server.Services.SettingsService)
local SettingsScreen = require(Client.UI.Screens.Settings)

return function(t)
	t.describe("Strings", function()
		t.it("returns text, fallback or key", function()
			t.expect(Strings.get("close")).toBe("Close")
			t.expect(Strings.get("coming_soon")).toBe("Coming soon")
			t.expect(Strings.get("no_such_key", "Fallback")).toBe("Fallback")
			t.expect(Strings.get("no_such_key")).toBe("no_such_key")
		end)
		t.it("has the common UI words", function()
			for _, key in { "close", "back", "confirm", "cancel", "buy", "equip", "locked", "coming_soon", "ok" } do
				t.expect(Strings.has(key)).toBe(true)
			end
		end)
		t.it("formats placeholders", function()
			t.expect(Strings.format("hud_level", { level = 7 })).toBe("Lv 7")
			t.expect(Strings.format("hud_xp", { xp = "1,200", next = "2,000" })).toBe("1,200 / 2,000 XP")
			t.expect(Strings.format("hud_xp", { xp = 5 })).toBe("5 / {next} XP") -- unknown stays
			t.expect(Strings.fill("{a}-{b}", { a = 1, b = "x" })).toBe("1-x")
		end)
		t.it("every value is a non-empty string", function()
			for k, v in Strings.en do
				if type(v) ~= "string" or v == "" then
					error("bad string " .. k)
				end
			end
		end)
	end)

	t.describe("Sounds", function()
		t.it("defines every cue with a built-in or uploaded id", function()
			for _, name in Sounds.names do
				local cue = Sounds.cues[name]
				if cue == nil then
					error("missing cue " .. name)
				end
				local okId = string.match(cue.id, "^rbxasset://sounds/") or string.match(cue.id, "^rbxassetid://%d+$")
				t.expect(okId ~= nil).toBeTruthy()
				t.expect(cue.volume).toBeBetween(0, 1)
				for _, note in cue.notes or {} do
					t.expect(note.delay).toBeGreaterThanOrEqual(0)
				end
			end
			for _, name in
				{
					"click",
					"open",
					"close",
					"notify",
					"good",
					"bad",
					"cash",
					"levelup",
					"promotion",
					"alarm",
					"chime",
					"error",
					"type",
				}
			do
				t.expect(Sounds.cues[name] ~= nil).toBeTruthy()
			end
		end)
	end)

	t.describe("Settings data", function()
		t.it("template has the documented defaults and merges under 'settings'", function()
			local s = SettingsTemplate.settings
			t.expect(s.music).toBeBetween(0, 1)
			t.expect(s.sfx).toBeBetween(0, 1)
			t.expect(s.reducedMotion).toBe(false)
			t.expect(s.showTicker).toBe(true)
			t.expect(s.uiScale).toBe(1)
			t.expect(DataTemplate.template.settings).never(nil)
		end)
		t.it("validate accepts whitelisted keys and rejects everything else", function()
			local k, v = SettingsService.validate("music", 0.456)
			t.expect(k).toBe("music")
			t.expect(v).toBeCloseTo(0.46, 1e-9)
			t.expect((SettingsService.validate("reducedMotion", true))).toBe("reducedMotion")
			t.expect((SettingsService.validate("uiScale", 1.2))).toBe("uiScale")
			t.expect((SettingsService.validate("uiScale", 1.3))).toBeNil()
			t.expect((SettingsService.validate("uiScale", 0.79))).toBeNil()
			t.expect((SettingsService.validate("music", -0.1))).toBeNil()
			t.expect((SettingsService.validate("music", 0 / 0))).toBeNil()
			t.expect((SettingsService.validate("music", math.huge))).toBeNil()
			t.expect((SettingsService.validate("music", "0.5"))).toBeNil()
			t.expect((SettingsService.validate("showTicker", 1))).toBeNil()
			t.expect((SettingsService.validate("admin", true))).toBeNil()
			t.expect((SettingsService.validate("__index", true))).toBeNil()
			t.expect((SettingsService.validate(nil, true))).toBeNil()
			t.expect((SettingsService.validate({}, true))).toBeNil()
			t.expect((SettingsService.validate(string.rep("a", 100), true))).toBeNil()
		end)
		t.it("schema covers exactly the template keys", function()
			for key in SettingsTemplate.settings do
				t.expect(SettingsService.SCHEMA[key] ~= nil).toBeTruthy()
			end
			for key in SettingsService.SCHEMA do
				t.expect(SettingsTemplate.settings[key] ~= nil).toBeTruthy()
			end
		end)
		t.it("the Settings screen ranges match the server schema", function()
			for _, field in SettingsScreen.fields do
				local spec = SettingsService.SCHEMA[field.key]
				t.expect(spec ~= nil).toBeTruthy()
				if field.kind == "slider" then
					t.expect(spec.kind).toBe("number")
					t.expect(field.min).toBe(spec.min)
					t.expect(field.max).toBe(spec.max)
					t.expect((SettingsService.validate(field.key, field.min))).toBe(field.key)
					t.expect((SettingsService.validate(field.key, field.max))).toBe(field.key)
					-- every slider step value is accepted unchanged
					local v = field.min
					while v <= field.max + 1e-9 do
						local _, cleaned = SettingsService.validate(field.key, v)
						t.expect(cleaned).toBeCloseTo(math.floor(v * 100 + 0.5) / 100, 1e-9)
						v += field.step
					end
				else
					t.expect(spec.kind).toBe("boolean")
				end
			end
		end)
	end)
end
