local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Shared = game:GetService("ReplicatedStorage").Shared
local Theme = require(Client.UI.Theme)
local Palette = require(Shared.Build.Palette)

return function(t)
	t.describe("Theme tokens", function()
		for _, name in Theme.names do
			t.it(name .. " has every token with the right type", function()
				local tokens = Theme.themes[name]
				t.expect(tokens).never(nil)
				t.expect(tokens.name).toBe(name)
				for _, key in Theme.COLOR_KEYS do
					if typeof(tokens.colors[key]) ~= "Color3" then
						error(name .. ".colors." .. key .. " is not a Color3")
					end
				end
				for _, key in Theme.FONT_KEYS do
					if typeof(tokens.fonts[key]) ~= "Font" then
						error(name .. ".fonts." .. key .. " is not a Font")
					end
				end
				local last = 0
				for _, key in Theme.TEXT_KEYS do
					local size = tokens.text[key]
					t.expect(type(size)).toBe("number")
					t.expect(size).toBeGreaterThan(last) -- xs < sm < md < lg < xl < xxl
					last = size
				end
				for _, key in { "radius", "radiusSm", "pad", "gap", "stroke", "panelTransparency" } do
					t.expect(type((tokens :: any)[key])).toBe("number")
				end
				t.expect(tokens.text.md).toBeGreaterThanOrEqual(16) -- legible on phones after 0.75 scaling
			end)
		end

		t.it("matches the spec palette", function()
			local campus, street = Theme.themes.campus, Theme.themes.street
			t.expect(campus.colors.panel).toEqual(Palette.hex("#24262A"))
			t.expect(campus.colors.text).toEqual(Palette.hex("#E9E2CF"))
			t.expect(campus.colors.accent).toEqual(Palette.hex("#C9A13B"))
			t.expect(street.colors.panel).toEqual(Palette.hex("#0B1F3A"))
			t.expect(street.colors.accent).toEqual(Palette.hex("#C9A54C"))
			t.expect(campus.fonts.heading).toEqual(Font.fromEnum(Enum.Font.SpecialElite))
			t.expect(campus.fonts.body).toEqual(Font.fromEnum(Enum.Font.SourceSans))
			t.expect(street.fonts.body).toEqual(Font.fromEnum(Enum.Font.Gotham))
			t.expect(street.fonts.mono).toEqual(Font.fromEnum(Enum.Font.RobotoMono))
		end)
	end)

	t.describe("Theme API", function()
		t.it("set/name/get and Changed", function()
			Theme.set("campus")
			local fired = {}
			local conn = Theme.Changed:Connect(function(tokens, name)
				table.insert(fired, name)
				t.expect(tokens.name).toBe(name)
			end)
			t.expect(Theme.set("street")).toBe(true)
			t.expect(Theme.name()).toBe("street")
			t.expect(Theme.get().name).toBe("street")
			t.expect(Theme.set("street")).toBe(false) -- no change, no event
			t.expect(Theme.set("nope")).toBe(false)
			t.expect(Theme.name()).toBe("street")
			Theme.set("campus")
			conn:Disconnect()
			t.expect(fired).toEqual({ "street", "campus" })
		end)
		t.it("forRank picks campus for students and unknown", function()
			t.expect(Theme.forRank(nil)).toBe("campus")
			t.expect(Theme.forRank(0)).toBe("campus")
			t.expect(Theme.forRank(1)).toBe("street")
			t.expect(Theme.forRank(12)).toBe("street")
		end)
		t.it("accentFor uses realm palettes", function()
			t.expect(Theme.accentFor("hf")).toEqual(Palette.realm.hf.accent)
			t.expect(Theme.accentFor("pe")).toEqual(Palette.realm.pe.accent)
			t.expect(Theme.accentFor("partner")).toEqual(Palette.realm.partner.accent)
			t.expect(Theme.accentFor("unknown")).toEqual(Theme.get().colors.accent)
			t.expect(Theme.accentFor(nil)).toEqual(Theme.get().colors.accent)
		end)
		t.it("uiScale clamps by viewport height and user scale", function()
			t.expect(Theme.uiScale(800)).toBeCloseTo(1, 1e-6)
			t.expect(Theme.uiScale(360)).toBeCloseTo(0.75, 1e-6) -- phone floor
			t.expect(Theme.uiScale(2160)).toBeCloseTo(1.15, 1e-6) -- 4K ceiling
			t.expect(Theme.uiScale(800, 1.2)).toBeCloseTo(1.2, 1e-6)
			t.expect(Theme.uiScale(800, 5)).toBeCloseTo(1.2, 1e-6) -- user scale clamped
			t.expect(Theme.uiScale(0)).toBeCloseTo(1, 1e-6)
			t.expect(Theme.uiScale(800, 0 / 0)).toBeCloseTo(1, 1e-6)
		end)
		t.it("contrastText is readable", function()
			t.expect(Theme.contrastText(Color3.new(1, 1, 1)).R).toBeLessThan(0.2)
			t.expect(Theme.contrastText(Color3.new(0, 0, 0)).R).toBeGreaterThan(0.9)
		end)
	end)
end
