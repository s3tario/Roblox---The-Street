-- Signs: every sign function builds under Lune at a rotated, off-origin CFrame with every style, stays
-- anchored and above its mount line, exposes the documented runtime hooks and is deterministic per seed.

local Shared = game:GetService("ReplicatedStorage").Shared
local Signs = require(Shared.Assets.Signs)
local Common = require(Shared.Assets.Props.Common)

local CF = CFrame.new(-42.5, 30.25, 118) * CFrame.Angles(0, math.rad(-63), 0)

local function parts(m: Instance): { BasePart }
	local out = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function texts(m: Instance): { string }
	local out = {}
	for _, d in m:GetDescendants() do
		if d:IsA("TextLabel") then
			table.insert(out, d.Text)
		end
	end
	return out
end

local function hasText(m: Instance, needle: string): boolean
	for _, s in texts(m) do
		if string.find(s, needle, 1, true) then
			return true
		end
	end
	return false
end

local function fingerprint(m: Model, cf: CFrame): string
	local bits = {}
	for _, p in parts(m) do
		local lp = cf:PointToObjectSpace(p.CFrame.Position)
		table.insert(
			bits,
			string.format(
				"%s:%d,%d,%d:%s:%.2f,%.2f,%.2f",
				p.Name,
				math.floor(p.Color.R * 255 + 0.5),
				math.floor(p.Color.G * 255 + 0.5),
				math.floor(p.Color.B * 255 + 0.5),
				p.Material.Name,
				lp.X,
				lp.Y,
				lp.Z
			)
		)
	end
	return #bits .. "|" .. table.concat(bits, ";") .. "|" .. table.concat(texts(m), "/")
end

-- Shared shape checks; returns the local bounds.
local function check(
	label: string,
	kind: string,
	mount: string,
	m: Model,
	cf: CFrame,
	maxParts: number
): (Vector3, Vector3)
	if not m:IsA("Model") then
		error(label .. ": not a Model")
	end
	local root = m.PrimaryPart
	if root == nil or root.Name ~= "Root" or root.Transparency ~= 1 or root.CanCollide then
		error(label .. ": PrimaryPart must be the invisible Root")
	end
	if (root.CFrame.Position - cf.Position).Magnitude > 1e-3 then
		error(label .. ": Root not at cf")
	end
	if m:GetAttribute("SignKind") ~= kind or m:GetAttribute("SignMount") ~= mount or not m:HasTag("Sign") then
		error(label .. ": missing SignKind/SignMount/Sign tag")
	end
	local list = parts(m)
	if #list < 2 or #list > maxParts then
		error(string.format("%s: %d parts (budget %d)", label, #list, maxParts))
	end
	for _, p in list do
		if not p.Anchored then
			error(label .. ": unanchored " .. p.Name)
		end
	end
	local mn, mx = Common.localBounds(m, cf, root)
	if mn.Y < -0.1 then
		error(string.format("%s: dips %.2f below its mount line", label, mn.Y))
	end
	if mount == "wall" and mx.Z > 0.15 then
		error(string.format("%s: pokes %.2f into the wall", label, mx.Z))
	end
	return mn, mx
end

return function(t)
	t.describe("Signs", function()
		t.it("lists eight kinds, each exposed as a function", function()
			local list = Signs.list()
			t.expect(#list).toBe(8)
			for _, info in list do
				t.expect(type((Signs :: any)[info.kind])).toBe("function")
				t.expect(Signs.has(info.kind)).toBe(true)
			end
			t.expect(Signs.has("nope")).toBe(false)
			t.expect(function()
				Signs.build("nope", nil, CF)
			end).toThrow("unknown sign kind")
		end)

		t.it("every kind builds with defaults (no opts) and via Signs.build", function()
			for _, info in Signs.list() do
				local parent = Instance.new("Folder")
				local m = (Signs :: any)[info.kind](parent, CF)
				t.expect(m.Parent).toBe(parent)
				check(info.kind, info.kind, info.mount, m, CF, 80)
				local m2 = Signs.build(info.kind, nil, CF, { seed = 3 })
				check(info.kind .. " (build)", info.kind, info.mount, m2, CF, 80)
			end
		end)

		t.it("buildingName builds every style with the text and a sensible size", function()
			for _, style in Signs.STYLES do
				for _, lit in { true, false } do
					local m =
						Signs.buildingName(nil, CF, { text = "HALCYON TOWER", style = style, lit = lit, height = 3 })
					local mn, mx = check("buildingName " .. style, "buildingName", "wall", m, CF, 20)
					t.expect(m:GetAttribute("SignStyle")).toBe(style)
					t.expect(hasText(m, "HALCYON TOWER")).toBe(true)
					local w = mx.X - mn.X
					t.expect(w).toBeBetween(8, 40)
					t.expect(mx.Y).toBeBetween(2.5, 5)
				end
			end
			-- explicit width wins; long text is clamped, never errors
			local m = Signs.buildingName(nil, CF, { text = "X", width = 12, style = "stone" })
			local mn, mx = check("buildingName width", "buildingName", "wall", m, CF, 20)
			t.expect(mx.X - mn.X).toBeGreaterThan(12)
			Signs.buildingName(nil, CF, { text = string.rep("LONG NAME ", 40) })
		end)

		t.it("buildingName firmBrand = true tags one BrandText carrier in every style", function()
			for _, style in Signs.STYLES do
				for _, brand in { true, false } do
					local m = Signs.buildingName(nil, CF, { style = style, text = "HALCYON", firmBrand = brand })
					local n = 0
					for _, d in m:GetDescendants() do
						if d:IsA("BasePart") and d:HasTag("FirmBrand") then
							for _, g in d:GetDescendants() do
								if g:IsA("TextLabel") and g.Name == "BrandText" and g.Text == "HALCYON" then
									n += 1
								end
							end
						end
					end
					t.expect(n).toBe(if brand then 1 else 0)
				end
			end
		end)

		t.it("neon signs glow when lit and carry flicker hooks", function()
			local m = Signs.neon(nil, CF, { text = "OPEN 24H", flicker = true })
			check("neon", "neon", "wall", m, CF, 20)
			local neon, flick, light = 0, 0, 0
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
					neon += 1
				end
				if d:IsA("BasePart") and d:GetAttribute("Flicker") == true then
					flick += 1
				end
				if d:IsA("PointLight") then
					light += 1
				end
			end
			t.expect(neon).toBeGreaterThanOrEqual(8)
			t.expect(flick).toBeGreaterThan(0)
			t.expect(light).toBe(1)
			t.expect(hasText(m, "OPEN 24H")).toBe(true)
			local off = Signs.neon(nil, CF, { lit = false })
			for _, d in off:GetDescendants() do
				t.expect(d:IsA("PointLight")).toBe(false)
			end
		end)

		t.it("tickerBand exposes TickerText labels on tagged faces, split into segments when wide", function()
			for _, w in { 12, 40, 150, 400 } do
				local m = Signs.tickerBand(nil, CF, { width = w })
				local mn, mx = check("tickerBand " .. w, "tickerBand", "wall", m, CF, 30)
				t.expect(mx.X - mn.X).toBeCloseTo(w, 0.01)
				local faces, labels = 0, 0
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") and d:HasTag("TickerDisplay") then
						faces += 1
						t.expect(d:GetAttribute("BandWidth")).toBe(w)
					end
					if d:IsA("TextLabel") and d.Name == "TickerText" then
						labels += 1
						t.expect(d.TextWrapped).toBe(false)
						t.expect(d.TextScaled).toBe(false)
						t.expect(d.AutomaticSize).toBe(Enum.AutomaticSize.X)
						t.expect(type(d:GetAttribute("BaseOffsetPx"))).toBe("number")
						t.expect(d.Parent and d.Parent.Name).toBe("Viewport")
					end
				end
				t.expect(faces).toBe(math.max(1, math.ceil(w / 32)))
				t.expect(labels).toBe(faces)
			end
			local m = Signs.tickerBand(nil, CF, { text = "ST10 4,812.40 +0.8%" })
			t.expect(hasText(m, "ST10 4,812.40 +0.8%")).toBe(true)
		end)

		t.it("streetName builds one or two blades with the given names", function()
			local two = Signs.streetName(nil, CF, { text = "Ledger Ave", text2 = "Broad St" })
			check("streetName", "streetName", "floor", two, CF, 12)
			t.expect(hasText(two, "LEDGER AVE")).toBe(true)
			t.expect(hasText(two, "BROAD ST")).toBe(true)
			local one = Signs.streetName(nil, CF, { text = "Mill St", text2 = false })
			local blades = 0
			for _, p in parts(one) do
				if p.Name == "Blade" then
					blades += 1
				end
			end
			t.expect(blades).toBe(1)
		end)

		t.it("wayfinding renders custom entries on both faces", function()
			local m = Signs.wayfinding(nil, CF, { title = "Campus", entries = { "< Library", "> Gym", "^ Dorms", 42 } })
			check("wayfinding", "wayfinding", "floor", m, CF, 12)
			local n = 0
			for _, s in texts(m) do
				if s == "Library" then
					n += 1
				end
			end
			t.expect(n).toBe(2)
			t.expect(hasText(m, "CAMPUS")).toBe(true)
		end)

		t.it("poster, plaque and billboard honour their options", function()
			local p = Signs.poster(nil, CF, { title = "MIXER", body = "Fri 8PM", frame = true, width = 3, height = 4 })
			check("poster", "poster", "wall", p, CF, 10)
			t.expect(hasText(p, "MIXER")).toBe(true)
			local q = Signs.plaque(nil, CF, { title = "EST. 1901", text = "Founders' Hall" })
			check("plaque", "plaque", "wall", q, CF, 10)
			t.expect(hasText(q, "Founders' Hall")).toBe(true)
			for _, legs in { 0, 6, 20 } do
				local b = Signs.billboard(nil, CF, { brand = "ORIOLE AIR", slogan = "Up.", width = 50, legs = legs })
				local _, mx = check("billboard", "billboard", "floor", b, CF, 80)
				t.expect(mx.Y).toBeGreaterThan(legs + 12)
				t.expect(hasText(b, "ORIOLE AIR")).toBe(true)
				local lamps = 0
				for _, d in b:GetDescendants() do
					if d:IsA("BasePart") and d:HasTag("StreetLight") then
						lamps += 1
					end
				end
				t.expect(lamps).toBeGreaterThanOrEqual(2)
			end
		end)

		t.it("garbage options never crash", function()
			local junk = {
				text = 5,
				text2 = {},
				style = "chrome",
				width = 0 / 0,
				height = -3,
				color = "red",
				entries = "nope",
				colors = "x",
				legs = math.huge,
				seed = {},
				font = 9,
			}
			for _, info in Signs.list() do
				local ok, err = pcall((Signs :: any)[info.kind], nil, CF, junk)
				if not ok then
					error(info.kind .. " crashed on junk options: " .. tostring(err))
				end
				check(info.kind .. " (junk)", info.kind, info.mount, err, CF, 80)
			end
		end)

		t.it("is deterministic for a seed and rotates rigidly with its placement", function()
			local cf2 = CFrame.new(5, 0, 5) * CFrame.Angles(0, math.rad(90), 0)
			for _, info in Signs.list() do
				local fn = (Signs :: any)[info.kind]
				local a = fingerprint(fn(nil, CF, { seed = 11 }), CF)
				local b = fingerprint(fn(nil, CF, { seed = 11 }), CF)
				if a ~= b then
					error(info.kind .. ": same seed built differently")
				end
				local c = fingerprint(fn(nil, cf2, { seed = 11 }), cf2)
				local function counts(s: string): string
					return string.match(s, "^%d+") or ""
				end
				t.expect(counts(c)).toBe(counts(a))
			end
		end)
	end)
end
