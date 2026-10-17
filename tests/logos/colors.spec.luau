-- Logos: the pure colour/theme maths (Colors.luau), the hard-edged mask sequences (Primitives.bandSequence)
-- and a check that every gradient in every logo is a sequence Roblox accepts (first keypoint at 0, last at 1,
-- strictly increasing times, at most 20 keypoints, transparency in 0..1). Lune does not enforce those rules;
-- the engine errors on them.

local Shared = game:GetService("ReplicatedStorage").Shared
local Logos = require(Shared.Assets.Logos)
local Colors = require(Shared.Assets.Logos.Colors)
local P = require(Shared.Assets.Logos.Primitives)

local function checkTimes(label: string, times: { number })
	if #times < 2 or #times > 20 then
		error(label .. ": " .. #times .. " keypoints")
	end
	if math.abs(times[1]) > 1e-9 or math.abs(times[#times] - 1) > 1e-9 then
		error(label .. ": keypoints must start at 0 and end at 1")
	end
	for i = 2, #times do
		if times[i] <= times[i - 1] then
			error(label .. ": keypoint times not increasing")
		end
	end
end

local function numberTimes(ns: NumberSequence): { number }
	local out = {}
	for _, k in ns.Keypoints do
		table.insert(out, k.Time)
		if k.Value < 0 or k.Value > 1 then
			error("transparency out of range")
		end
	end
	return out
end

local function colorTimes(cs: ColorSequence): { number }
	local out = {}
	for _, k in cs.Keypoints do
		table.insert(out, k.Time)
	end
	return out
end

return function(t)
	t.describe("Colors", function()
		t.it("parses and prints hex", function()
			local c = Colors.hex("#1B2A4A")
			t.expect(c).toEqual(Color3.fromRGB(0x1B, 0x2A, 0x4A))
			t.expect(Colors.toHex(c)).toBe("#1B2A4A")
			t.expect(Colors.hex("C9A54C")).toEqual(Color3.fromRGB(0xC9, 0xA5, 0x4C))
		end)

		t.it("measures luminance and contrast (WCAG)", function()
			t.expect(Colors.luminance(Colors.WHITE)).toBeCloseTo(1, 1e-6)
			t.expect(Colors.luminance(Colors.BLACK)).toBeCloseTo(0, 1e-6)
			t.expect(Colors.contrast(Colors.WHITE, Colors.BLACK)).toBeCloseTo(21, 1e-6)
			t.expect(Colors.contrast(Colors.BLACK, Colors.WHITE)).toBeCloseTo(21, 1e-6)
		end)

		t.it("keeps brand colours on light and falls back to main for unknown roles", function()
			local base = { main = Colors.hex("#0B1F3A"), accent = Colors.hex("#C9A54C") }
			local pal, bg = Colors.resolve(base, "light")
			t.expect(pal.main).toEqual(base.main)
			t.expect(pal.accent).toEqual(base.accent)
			t.expect(pal.counter).toEqual(Colors.WHITE)
			t.expect(pal.whatever).toEqual(base.main)
			t.expect(bg).toEqual(Colors.LIGHT_BG)
		end)

		t.it("lifts dark inks on the dark theme and keeps badge counters readable", function()
			local base = { main = Colors.hex("#101820"), counter = Colors.WHITE }
			local pal, bg = Colors.resolve(base, "dark")
			t.expect(bg).toEqual(Colors.DARK_BG)
			t.expect(Colors.contrast(pal.main, bg)).toBeGreaterThan(4.5)
			-- The counter takes the original badge colour so it still reads on the lifted badge.
			t.expect(pal.counter).toEqual(base.main)
		end)

		t.it("reverses out of the brand colour on the colour theme", function()
			local base = { main = Colors.hex("#1B2A4A"), accent = Colors.hex("#B8935A") }
			local pal, bg = Colors.resolve(base, "color")
			t.expect(bg).toEqual(base.main)
			t.expect(pal.main).toEqual(Colors.WHITE)
			t.expect(pal.counter).toEqual(base.main)
			t.expect(Colors.contrast(pal.accent, bg)).toBeGreaterThan(2.2)
		end)

		t.it("renders a single ink when tinted", function()
			local tint = Color3.fromRGB(200, 170, 90)
			local pal = Colors.resolve({ main = Colors.hex("#123456"), accent = Colors.hex("#FF0000") }, "light", tint)
			t.expect(pal.main).toEqual(tint)
			t.expect(pal.accent).toEqual(tint)
			t.expect(pal.counter ~= tint).toBe(true)
		end)

		t.it("applies per-theme overrides", function()
			local pal = Colors.resolve(
				{ main = Colors.hex("#101820") },
				"dark",
				nil,
				{ dark = { main = Colors.hex("#38B2AC") } }
			)
			t.expect(pal.main).toEqual(Colors.hex("#38B2AC"))
		end)

		t.it("has a fallback colour for every rarity", function()
			for _, r in { "common", "uncommon", "rare", "epic", "legendary", "mythic" } do
				t.expect(typeof(Colors.RARITY_FALLBACK[r])).toBe("Color3")
			end
			t.expect(#Colors.PRISM).toBeGreaterThan(3)
		end)
	end)

	t.describe("mask sequences", function()
		t.it("builds hard-edged bands that Roblox accepts", function()
			local cases = {
				{ { 0, 0.5 } },
				{ { 0.5, 1 } },
				{ { 0.2, 0.7 } },
				{ { 0, 0.45 }, { 0.55, 1 } },
				{ { 0.1, 0.2 }, { 0.4, 0.5 }, { 0.8, 0.9 } },
				{ { 0, 1 } },
				{ { 0.999, 1 } },
			}
			for i, bands in cases do
				local ns = P.bandSequence(bands)
				checkTimes("case " .. i, numberTimes(ns))
			end
		end)

		t.it("is visible inside the bands and hidden outside", function()
			local ns = P.bandSequence({ { 0.3, 0.6 } })
			local function at(x: number): number
				local kps = ns.Keypoints
				for i = 2, #kps do
					local a, b = kps[i - 1], kps[i]
					if x <= b.Time then
						local f = (x - a.Time) / (b.Time - a.Time)
						return a.Value + (b.Value - a.Value) * f
					end
				end
				return kps[#kps].Value
			end
			t.expect(at(0.1)).toBeCloseTo(1, 1e-6)
			t.expect(at(0.45)).toBeCloseTo(0, 1e-6)
			t.expect(at(0.9)).toBeCloseTo(1, 1e-6)
			-- A narrower edge for big discs.
			local fine = P.bandSequence({ { 0.3, 0.6 } }, 0.0005)
			t.expect(fine.Keypoints[2].Time).toBeCloseTo(0.3 - 0.00025, 1e-9)
			t.expect(P.segmentEdge(500)).toBeLessThan(0.001)
		end)

		t.it("every gradient in every logo and theme is a valid sequence", function()
			for _, id in Logos.list() do
				for _, opts in { {}, { theme = "dark" }, { theme = "color" }, { tint = Color3.new(1, 1, 1) } } do
					local box = Instance.new("Frame")
					box.Size = UDim2.fromOffset(128, 128)
					local root = Logos.render(box, id, opts :: any)
					for _, d in root:GetDescendants() do
						if d:IsA("UIGradient") then
							local g = d :: UIGradient
							checkTimes(id .. " transparency", numberTimes(g.Transparency))
							checkTimes(id .. " colour", colorTimes(g.Color))
						end
					end
				end
			end
		end)
	end)

	t.describe("geometry", function()
		t.it("polar measures clockwise from straight up", function()
			local x, y = P.polar(0, 0, 10, 0)
			t.expect(x).toBeCloseTo(0, 1e-9)
			t.expect(y).toBeCloseTo(-10, 1e-9)
			x, y = P.polar(0, 0, 10, 90)
			t.expect(x).toBeCloseTo(10, 1e-9)
			t.expect(y).toBeCloseTo(0, 1e-9)
		end)

		t.it("half-planes sit on the right of their line", function()
			local root = Instance.new("Frame")
			local cv = P.new(root, 100, 100, nil, nil, 1, false)
			local g = P.clip(cv, 0, 0, 100, 100)
			-- An eastward line along y = 50: the fill is below it, so the frame's centre is below the line.
			local f = P.halfPlane(cv, g, 0, 50, 100, 50, Colors.BLACK) :: Frame
			t.expect(f.Rotation).toBeCloseTo(0, 1e-9)
			local cy = (f.Position.Y.Scale + f.Size.Y.Scale / 2) * 100
			t.expect(cy).toBeGreaterThan(50)
			t.expect(P.halfPlane(cv, g, 5, 5, 5, 5, Colors.BLACK)).toBe(nil)
		end)
	end)
end
