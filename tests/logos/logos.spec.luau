-- Logos: every required logo (contracts §16 company and school ids, the clothing brands) renders under Lune into
-- a 256 x 256 container in every theme, stays inside the container in scale space (clip groups honoured), is
-- deterministic and within budget; unknown ids fall back to a monogram; Logos.surface builds a SurfaceGui.

local Shared = game:GetService("ReplicatedStorage").Shared
local Logos = require(Shared.Assets.Logos)
local Colors = require(Shared.Assets.Logos.Colors)
local Catalog = require(Shared.Config.Catalog)

local COMPANIES = {
	"mg_freeman",
	"goldfield_saxe",
	"morrow_stanton",
	"merriweather_lynch",
	"evermoor",
	"lazaro_freres",
	"centerline",
	"harrow_williams",
	"blairmont",
	"houlton_lockey",
	"sterling_vance",
	"eastbridge_capital",
	"anaeio",
	"bluestone",
	"krk",
	"ironclad",
	"aresmont",
	"gray_heron",
	"bridgecrest",
	"citrine",
	"quantum_ridge",
	"lotus_wealth",
	"sequel",
	"a17z",
	"seedline",
	"brookfold",
	"keystone",
	"northwind",
	"applewood",
}

local SCHOOLS = {
	eastbridge_state = "common",
	coastal_cc = "common",
	midvale = "common",
	riverbend = "common",
	pinecrest_state = "common",
	union_valley_tech = "common",
	lakeshore = "uncommon",
	granite_tech = "uncommon",
	harborview = "uncommon",
	northfield = "rare",
	ridgemont = "rare",
	kingsbridge = "epic",
	ashworth = "epic",
	whartonia = "legendary",
	stanfjord = "legendary",
	harvale = "mythic",
}

local FIXED_BRANDS = {
	"kevin_kroos",
	"old_harbor",
	"gapline",
	"hanesworth",
	"j_crewson",
	"plantain_republic",
	"tommy_hillford",
	"ralph_lorenzo",
	"brooks_brethren",
	"vineyard_wines",
	"patagonio",
	"briani",
	"canale",
	"tom_fordham",
	"zegnatti",
	"bruno_cucina",
	"pan_miller",
}

local SIZE = 256
local EPS = 0.75 -- pixels of slack for float rounding

local function requiredIds(): { string }
	local out = {}
	local seen = {}
	local function add(id: string)
		if not seen[id] then
			seen[id] = true
			table.insert(out, id)
		end
	end
	for _, id in COMPANIES do
		add(id)
	end
	local schoolIds = {}
	for id in SCHOOLS do
		table.insert(schoolIds, id)
	end
	table.sort(schoolIds)
	for _, id in schoolIds do
		add(id)
	end
	for _, b in FIXED_BRANDS do
		add("brand_" .. b)
	end
	local brandIds = {}
	for id in Catalog.brands do
		table.insert(brandIds, id)
	end
	table.sort(brandIds)
	for _, id in brandIds do
		add("brand_" .. id)
	end
	return out
end

local function container(): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(SIZE, SIZE)
	return f
end

local function childOfClass(inst: Instance, cls: string): Instance?
	for _, ch in inst:GetChildren() do
		if ch.ClassName == cls then
			return ch
		end
	end
	return nil
end

-- Walks the GUI tree in pixel space (scale + offset, aspect constraints, UIScale) and returns the visible
-- rectangle of every GuiObject that pokes outside the container. Rotation is ignored (scale-space check);
-- ClipsDescendants frames cut their children, as Roblox does for unrotated frames.
type Rect = { x0: number, y0: number, x1: number, y1: number }
local function outOfBounds(root: Instance, W: number, H: number): { string }
	local bad = {}
	local function walk(inst: Instance, px: number, py: number, pw: number, ph: number, clip: Rect)
		for _, ch in inst:GetChildren() do
			if ch:IsA("GuiObject") then
				local g = ch :: GuiObject
				local w = g.Size.X.Scale * pw + g.Size.X.Offset
				local h = g.Size.Y.Scale * ph + g.Size.Y.Offset
				local arc = childOfClass(g, "UIAspectRatioConstraint") :: UIAspectRatioConstraint?
				if arc then
					if w / math.max(h, 1e-9) > arc.AspectRatio then
						w = h * arc.AspectRatio
					else
						h = w / arc.AspectRatio
					end
				end
				local sc = childOfClass(g, "UIScale") :: UIScale?
				local s = if sc then sc.Scale else 1
				w, h = w * s, h * s
				local x = px + g.Position.X.Scale * pw + g.Position.X.Offset - g.AnchorPoint.X * w
				local y = py + g.Position.Y.Scale * ph + g.Position.Y.Offset - g.AnchorPoint.Y * h
				local vx0, vy0 = math.max(x, clip.x0), math.max(y, clip.y0)
				local vx1, vy1 = math.min(x + w, clip.x1), math.min(y + h, clip.y1)
				if vx1 > vx0 and vy1 > vy0 then
					if vx0 < -EPS or vy0 < -EPS or vx1 > W + EPS or vy1 > H + EPS then
						table.insert(
							bad,
							string.format("%s [%.1f,%.1f .. %.1f,%.1f]", g:GetFullName(), vx0, vy0, vx1, vy1)
						)
					end
				end
				local inner = clip
				if g.ClipsDescendants and g.Rotation == 0 then
					inner = {
						x0 = math.max(clip.x0, x),
						y0 = math.max(clip.y0, y),
						x1 = math.min(clip.x1, x + w),
						y1 = math.min(clip.y1, y + h),
					}
				end
				walk(g, x, y, w / s, h / s, inner)
			end
		end
	end
	walk(root, 0, 0, W, H, { x0 = -math.huge, y0 = -math.huge, x1 = math.huge, y1 = math.huge })
	return bad
end

local function fingerprint(root: Instance): string
	local bits = {}
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			local g = d :: GuiObject
			table.insert(
				bits,
				string.format(
					"%s:%.4f,%.4f,%.4f,%.4f:%.2f:%d",
					g.ClassName,
					g.Position.X.Scale,
					g.Position.Y.Scale,
					g.Size.X.Scale,
					g.Size.Y.Scale,
					g.Rotation,
					g.ZIndex
				)
			)
		end
	end
	return table.concat(bits, ";")
end

local function hasText(root: Instance, needle: string): boolean
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") and string.find((d :: TextLabel).Text, needle, 1, true) then
			return true
		end
	end
	return false
end

return function(t)
	t.describe("registry", function()
		t.it("has every required company, school and brand id, without duplicates", function()
			local listed = {}
			for _, id in Logos.list() do
				t.expect(listed[id]).toBe(nil)
				listed[id] = true
			end
			for _, id in requiredIds() do
				if not Logos.has(id) then
					error("missing logo " .. id)
				end
				t.expect(listed[id]).toBe(true)
			end
		end)

		t.it("lists by kind and reports info", function()
			local schools = Logos.list("school")
			t.expect(#schools).toBe(16)
			for _, id in schools do
				local info = Logos.info(id)
				t.expect(info ~= nil).toBe(true)
				t.expect((info :: any).kind).toBe("school")
				t.expect((info :: any).rarity).toBe(SCHOOLS[id])
			end
			for _, id in COMPANIES do
				t.expect((Logos.info(id) :: any).kind).toBe("company")
			end
			for _, id in Logos.list("brand") do
				t.expect(string.sub(id, 1, 6)).toBe("brand_")
			end
			t.expect(Logos.info("no_such_logo")).toBe(nil)
		end)

		t.it("gives wordmarks a wide aspect and marks a square one", function()
			t.expect(Logos.aspect("anaeio")).toBeGreaterThan(2.5)
			t.expect(Logos.aspect("morrow_stanton")).toBeGreaterThan(2.5)
			t.expect(Logos.aspect("mg_freeman")).toBe(1)
			t.expect(Logos.aspect("harvale")).toBe(1)
			t.expect(Logos.aspect("unknown_thing")).toBe(1)
		end)
	end)

	t.describe("render", function()
		t.it("renders every required id into a 256 x 256 container, inside its bounds", function()
			for _, id in requiredIds() do
				local box = container()
				local ok, root = pcall(Logos.render, box, id)
				if not ok then
					error(id .. ": " .. tostring(root))
				end
				t.expect(root.Parent).toBe(box)
				t.expect(root:GetAttribute("LogoId")).toBe(id)
				t.expect(root:GetAttribute("LogoKind") ~= "monogram").toBe(true)
				local count = #root:GetDescendants()
				if count <= 3 then
					error(id .. ": only " .. count .. " descendants")
				end
				if count > 420 then
					error(id .. ": " .. count .. " descendants (budget 420)")
				end
				local bad = outOfBounds(box, SIZE, SIZE)
				if #bad > 0 then
					error(id .. " pokes outside its container: " .. table.concat(bad, "; ", 1, math.min(#bad, 3)))
				end
			end
		end)

		t.it("renders every theme, a tint and the simple variant", function()
			local variants = {
				{ theme = "light" },
				{ theme = "dark" },
				{ theme = "color" },
				{ theme = "color", corner = 0.2 },
				{ tint = Color3.fromRGB(200, 170, 90) },
				{ simple = true },
				{ background = Color3.new(1, 1, 1), padding = 0.1 },
				{ px = 64 },
				{ px = 512 },
			}
			for _, id in Logos.list() do
				for _, v in variants do
					local box = container()
					local ok, err = pcall(Logos.render, box, id, v :: any)
					if not ok then
						error(id .. ": " .. tostring(err))
					end
					local bad = outOfBounds(box, SIZE, SIZE)
					if #bad > 0 then
						error(id .. " (variant) pokes outside: " .. bad[1])
					end
				end
			end
		end)

		t.it("letterboxes with an aspect constraint and fills the container", function()
			local box = container()
			local root = Logos.render(box, "anaeio")
			local arc = childOfClass(root, "UIAspectRatioConstraint") :: UIAspectRatioConstraint
			t.expect(arc ~= nil).toBe(true)
			t.expect(arc.AspectRatio).toBeCloseTo(Logos.aspect("anaeio"), 1e-6)
			t.expect(root.Size).toEqual(UDim2.fromScale(1, 1))
			t.expect(root.AnchorPoint).toEqual(Vector2.new(0.5, 0.5))
			t.expect(root.BackgroundTransparency).toBe(1)
		end)

		t.it("puts a background behind the colour theme and none behind light", function()
			local light = Logos.render(container(), "mg_freeman")
			t.expect(light.BackgroundTransparency).toBe(1)
			local color = Logos.render(container(), "mg_freeman", { theme = "color" })
			t.expect(color.BackgroundTransparency).toBe(0)
			t.expect(color.BackgroundColor3).toEqual(Color3.fromRGB(0x1B, 0x2A, 0x4A))
		end)

		t.it("is deterministic", function()
			for _, id in { "lotus_wealth", "anaeio", "harvale", "brand_pan_miller", "unknown_firm" } do
				local a = fingerprint(Logos.render(container(), id))
				local b = fingerprint(Logos.render(container(), id))
				t.expect(a).toBe(b)
			end
		end)

		t.it("uses only GUI shapes and text (no images, no asset ids)", function()
			for _, id in Logos.list() do
				local root = Logos.render(container(), id)
				for _, d in root:GetDescendants() do
					local cls = d.ClassName
					local allowed = cls == "Frame"
						or cls == "TextLabel"
						or cls == "UICorner"
						or cls == "UIStroke"
						or cls == "UIGradient"
						or cls == "UIScale"
						or cls == "UIAspectRatioConstraint"
					if not allowed then
						error(id .. " uses " .. cls)
					end
					if d:IsA("TextLabel") then
						t.expect((d :: TextLabel).AutoLocalize).toBe(false)
					end
				end
			end
		end)

		t.it("increases ZIndex in drawing order under the root", function()
			local box = container()
			box.ZIndex = 5
			local root = Logos.render(box, "harvale")
			t.expect(root.ZIndex).toBe(6)
			for _, d in root:GetDescendants() do
				if d:IsA("GuiObject") then
					t.expect((d :: GuiObject).ZIndex).toBeGreaterThan(6)
				end
			end
		end)
	end)

	t.describe("signature logos", function()
		t.it("Lotus: seven petals and a stipple under 150 dots that `simple` drops", function()
			local root = Logos.render(container(), "lotus_wealth")
			local petals, dots = 0, 0
			for _, d in root:GetDescendants() do
				if d.Name == "Stipple" then
					dots += 1
				elseif d.Name == "Petal" and d.Parent and d.Parent.Name == "Lens" then
					petals += 1
				end
			end
			t.expect(petals).toBe(14) -- two disc segments per petal
			t.expect(dots).toBeGreaterThan(40)
			t.expect(dots).toBeLessThan(150)
			local simple = Logos.render(container(), "lotus_wealth", { simple = true })
			for _, d in simple:GetDescendants() do
				t.expect(d.Name ~= "Stipple").toBe(true)
			end
		end)

		t.it("Anaeio: a black wordmark with rings, the n's arch, the e's bowl and the i-dot", function()
			local root = Logos.render(container(), "anaeio")
			local rings, masked, ink = 0, 0, Colors.hex("#101820")
			for _, d in root:GetDescendants() do
				if d:IsA("UIStroke") then
					rings += 1
					t.expect((d :: UIStroke).Color).toEqual(ink)
					if childOfClass(d, "UIGradient") then
						masked += 1
					end
				end
			end
			-- a, a, e (two halves), o, n arch: six rings; the n, the e's top half and the split o are masked.
			t.expect(rings).toBe(6)
			t.expect(masked).toBe(3)
			t.expect(hasText(root, "anaeio")).toBe(false)
		end)

		t.it("Pan Miller: a windmill wheel of at least 16 blades", function()
			local root = Logos.render(container(), "brand_pan_miller", { simple = true })
			local rotated = 0
			for _, d in root:GetDescendants() do
				if d:IsA("Frame") and (d :: Frame).Rotation ~= 0 then
					rotated += 1
				end
			end
			-- 18 blades plus the tower's legs, braces and tail boom.
			t.expect(rotated).toBeGreaterThan(18 + 8)
		end)

		t.it("Harvale: prismatic trim unless tinted; Legendary and Mythic crests carry a ribbon", function()
			local function usesPrism(root: Instance): boolean
				for _, d in root:GetDescendants() do
					if d:IsA("Frame") and (d :: Frame).BackgroundColor3 == Colors.PRISM[1] then
						return true
					end
				end
				return false
			end
			t.expect(usesPrism(Logos.render(container(), "harvale"))).toBe(true)
			t.expect(usesPrism(Logos.render(container(), "harvale", { tint = Color3.new(1, 1, 1) }))).toBe(false)
			t.expect(usesPrism(Logos.render(container(), "eastbridge_state"))).toBe(false)
			t.expect(hasText(Logos.render(container(), "whartonia"), "WHARTONIA")).toBe(true)
			t.expect(hasText(Logos.render(container(), "harvale"), "HARVALE")).toBe(true)
			t.expect(hasText(Logos.render(container(), "midvale"), "MIDVALE")).toBe(false)
		end)

		t.it("crests keep their field colours on dark and colour backgrounds", function()
			local crimson = Colors.hex("#A51C30")
			local function hasFill(root: Instance, c: Color3): boolean
				for _, d in root:GetDescendants() do
					if
						d:IsA("Frame")
						and (d :: Frame).BackgroundTransparency < 1
						and (d :: Frame).BackgroundColor3 == c
					then
						return true
					end
				end
				return false
			end
			t.expect(hasFill(Logos.render(container(), "harvale", { theme = "dark" }), crimson)).toBe(true)
			local colored = Logos.render(container(), "harvale", { theme = "color" })
			t.expect(colored.BackgroundColor3).toEqual(crimson)
			-- Ink marks lift instead: the Anaeio wordmark goes light on dark.
			local dark = Logos.render(container(), "anaeio", { theme = "dark" })
			for _, d in dark:GetDescendants() do
				if d:IsA("UIStroke") then
					t.expect(Colors.luminance((d :: UIStroke).Color)).toBeGreaterThan(0.5)
				end
			end
		end)

		t.it("school trims take the rarity colour", function()
			local root = Logos.render(container(), "northfield")
			local found = false
			local blue = Colors.RARITY_FALLBACK.rare
			for _, d in root:GetDescendants() do
				if d:IsA("Frame") and (d :: Frame).BackgroundColor3 == blue then
					found = true
				end
			end
			t.expect(found).toBe(true)
		end)
	end)

	t.describe("fallback", function()
		t.it("renders a monogram for unknown ids", function()
			t.expect(Logos.has("hollow_point_partners")).toBe(false)
			t.expect(Logos.has("brand_nobody_knows")).toBe(false)
			t.expect(Logos.has(nil :: any)).toBe(false)
			local box = container()
			local root = Logos.render(box, "hollow_point_partners")
			t.expect(root:GetAttribute("LogoKind")).toBe("monogram")
			t.expect(hasText(root, "HP")).toBe(true)
			t.expect(#root:GetDescendants()).toBeGreaterThan(3)
			t.expect(#outOfBounds(box, SIZE, SIZE)).toBe(0)
			local brand = Logos.render(container(), "brand_nobody_knows")
			t.expect(hasText(brand, "NK")).toBe(true)
			local empty = Logos.render(container(), "")
			t.expect(empty:GetAttribute("LogoKind")).toBe("monogram")
		end)
	end)

	t.describe("surface", function()
		t.it("creates a PixelsPerStud SurfaceGui on the part with a transparent background", function()
			local part = Instance.new("Part")
			part.Size = Vector3.new(12, 6, 1)
			local gui = Logos.surface(part, Enum.NormalId.Front, "goldfield_saxe")
			t.expect(gui:IsA("SurfaceGui")).toBe(true)
			t.expect(gui.Parent).toBe(part)
			t.expect(gui.Face).toBe(Enum.NormalId.Front)
			t.expect(gui.SizingMode).toBe(Enum.SurfaceGuiSizingMode.PixelsPerStud)
			t.expect(gui.LightInfluence).toBeCloseTo(0.6, 1e-6)
			t.expect(gui.PixelsPerStud).toBeCloseTo(32, 1e-6) -- 384 px across the 12-stud side
			t.expect(gui:GetAttribute("LogoId")).toBe("goldfield_saxe")
			local root = gui:FindFirstChild("Logo") :: Frame
			t.expect(root ~= nil).toBe(true)
			t.expect(root.BackgroundTransparency).toBe(1)
			t.expect(#root:GetDescendants()).toBeGreaterThan(3)
			-- Exact pixel strokes on a SurfaceGui.
			for _, d in root:GetDescendants() do
				if d:IsA("UIStroke") then
					t.expect((d :: UIStroke).StrokeSizingMode).toBe(Enum.StrokeSizingMode.FixedSize)
				end
			end
		end)

		t.it("honours a background, other faces, unknown ids and replaces nothing else", function()
			local part = Instance.new("Part")
			part.Size = Vector3.new(1, 8, 4)
			local other = Instance.new("Decal")
			other.Parent = part
			local gui = Logos.surface(part, Enum.NormalId.Left, "brand_pan_miller", { background = true })
			t.expect(gui.Face).toBe(Enum.NormalId.Left)
			t.expect((gui:FindFirstChild("Logo") :: Frame).BackgroundTransparency).toBe(0)
			t.expect(other.Parent).toBe(part)
			local mono = Logos.surface(part, Enum.NormalId.Top, "unheard_of")
			t.expect((mono:FindFirstChild("Logo") :: Frame):GetAttribute("LogoKind")).toBe("monogram")
			Logos.clear(part)
			t.expect(#part:GetChildren()).toBe(1)
		end)
	end)
end
