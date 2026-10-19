-- The Investment Banking floor matches the owner's reference photo (design v3 §14): open plan under an exposed
-- concrete slab with silver ductwork, black cable trays and conduit; round concrete columns with brass capital bands;
-- grey-blue carpet; white desk pods with terrazzo end panels and 4-6 monitor arrays; black mesh chairs with orange
-- seats; black cylinder pendants on rods; big windows onto a painted skyline; glass meeting rooms.

local Builders = game:GetService("ServerStorage").WorldBuilders
local OfficeFloorsA = require(Builders.OfficeFloorsA)
local Layout = require(Builders.OfficeFloorsA.Layout)
local Style = require(Builders.OfficeFloorsA.Style)

local floor = OfficeFloorsA.build("ib", nil)

local function named(root: Instance, name: string): { Instance }
	local out = {}
	for _, d in root:GetDescendants() do
		if d.Name == name then
			table.insert(out, d)
		end
	end
	return out
end

local function guis(root: Instance, name: string): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("SurfaceGui") and d.Name == name then
			n += 1
		end
	end
	return n
end

local function close(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.02
end

return function(t)
	t.describe("IB floor look", function()
		t.it("is dressed in the ib style", function()
			t.expect(floor:GetAttribute("Department")).toBe("ib")
			t.expect(floor:GetAttribute("FloorStyle")).toBe("ib")
		end)

		t.it("has grey-blue carpet under an exposed concrete slab", function()
			local shell = floor:FindFirstChild("Shell") :: Instance
			local carpet = shell:FindFirstChild("Floor") :: BasePart
			t.expect(carpet.Material).toBe(Enum.Material.Carpet)
			t.expect(carpet.Color.B).toBeGreaterThan(carpet.Color.R)
			local slab = shell:FindFirstChild("CeilingSlab") :: BasePart
			t.expect(slab.Material).toBe(Enum.Material.Concrete)
			t.expect(guis(slab, "Formwork")).toBe(1)
		end)

		t.it("runs silver ductwork, black cable trays and conduit overhead", function()
			local ducts = named(floor, "Duct")
			t.expect(#ducts).toBeGreaterThanOrEqual(4)
			local round, rect = 0, 0
			for _, d in ducts do
				local p = d :: Part
				t.expect(p.Material).toBe(Enum.Material.Metal)
				t.expect(close(p.Color, Style.ib.duct)).toBe(true)
				if p.Shape == Enum.PartType.Cylinder then
					round += 1
				else
					rect += 1
				end
			end
			t.expect(round).toBeGreaterThanOrEqual(1)
			t.expect(rect).toBeGreaterThanOrEqual(1)
			local trays = named(floor, "CableTray")
			t.expect(#trays).toBeGreaterThanOrEqual(1)
			for _, tr in trays do
				t.expect(close((tr :: BasePart).Color, Style.ib.tray)).toBe(true)
			end
			t.expect(#named(floor, "Conduit")).toBeGreaterThanOrEqual(1)
		end)

		t.it("stands on round concrete columns with brass capital bands", function()
			local columns = named(floor, "Column")
			t.expect(#columns).toBe(#Layout.columns)
			for _, c in columns do
				t.expect((c :: Part).Shape).toBe(Enum.PartType.Cylinder)
				t.expect((c :: Part).Material).toBe(Enum.Material.Concrete)
				t.expect((c :: Part).CanCollide).toBe(true)
			end
			local bands = named(floor, "CapitalBand")
			t.expect(#bands).toBe(#Layout.columns)
			for _, b in bands do
				t.expect(close((b :: BasePart).Color, Style.ib.columnBand)).toBe(true)
			end
		end)

		t.it("lines up white desk pods with terrazzo end panels", function()
			local ends = named(floor, "EndPanel")
			t.expect(#ends).toBe(#Layout.benches * 2)
			for _, e in ends do
				t.expect(guis(e, "Terrazzo")).toBeGreaterThanOrEqual(1)
			end
			for _, top in named(floor, "Top") do
				local desk = top.Parent
				if desk and desk:GetAttribute("DeskSlot") then
					t.expect(close((top :: BasePart).Color, Style.ib.deskTop)).toBe(true)
				end
			end
		end)

		t.it("gives every workstation a 4-6 screen array with live-looking screens", function()
			for _, desk in floor:GetDescendants() do
				if desk:GetAttribute("DeskSlot") then
					local monitors = desk:GetAttribute("Monitors") :: number
					t.expect(monitors).toBeBetween(4, 6)
					local screens = 0
					for _, d in desk:GetDescendants() do
						if d:IsA("Frame") and d:GetAttribute("ScreenKind") ~= nil then
							screens += 1
						end
					end
					t.expect(screens).toBe(monitors)
				end
			end
		end)

		t.it("seats everyone on black mesh chairs with orange cushions", function()
			local chairs = 0
			for _, desk in floor:GetDescendants() do
				if desk:GetAttribute("DeskSlot") then
					local chair = desk:FindFirstChild("Chair") :: Model
					local cushion = chair:FindFirstChild("Cushion") :: BasePart
					local back = chair:FindFirstChild("Back") :: BasePart
					t.expect(close(cushion.Color, Style.ib.chairSeat)).toBe(true)
					t.expect(cushion.Color.R).toBeGreaterThan(cushion.Color.B + 0.3)
					t.expect(close(back.Color, Style.ib.chairMesh)).toBe(true)
					chairs += 1
				end
			end
			t.expect(chairs).toBe(24)
		end)

		t.it("hangs black cylinder pendants on rods, a few with SpotLights", function()
			local pendants = named(floor, "Pendant")
			t.expect(#pendants).toBeGreaterThanOrEqual(12)
			local spots = 0
			for _, p in pendants do
				local shade = p:FindFirstChild("Shade") :: Part
				t.expect(shade.Shape).toBe(Enum.PartType.Cylinder)
				t.expect(close(shade.Color, Style.ib.pendant)).toBe(true)
				local diffuser = p:FindFirstChild("Diffuser") :: BasePart
				t.expect(diffuser:HasTag("InteriorLight")).toBe(true)
				if diffuser:FindFirstChildWhichIsA("SpotLight") then
					spots += 1
				end
			end
			t.expect(spots).toBeGreaterThanOrEqual(3)
		end)

		t.it("has big windows onto a painted skyline and glass meeting rooms", function()
			t.expect(#named(floor, "CurtainWall")).toBeGreaterThanOrEqual(4)
			t.expect(guis(floor, "Skyline")).toBe(4)
			local function glassIn(name: string): number
				local room = floor:FindFirstChild(name, true) :: Instance
				local n = 0
				for _, d in room:GetDescendants() do
					if d:IsA("BasePart") and d.Material == Enum.Material.Glass and d.CanCollide then
						n += 1
					end
				end
				return n
			end
			t.expect(glassIn("Boardroom")).toBeGreaterThanOrEqual(2)
			t.expect(glassIn("Huddles")).toBeGreaterThanOrEqual(4)
		end)
	end)
end
