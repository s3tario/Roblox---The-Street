-- Department floor templates (OfficeFloorsA: "ib" + the "st", "er", "corpbank" placeholders) under Lune: every marker
-- and slot the office system needs, exactly as contracts §11 and Config/World (templateMarkers, floorSlots,
-- templateEventSpots, templates) define them, inside the template bounds and the part budget.

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Decor = require(Shared.Config.Decor)
local Builders = game:GetService("ServerStorage").WorldBuilders
local OfficeFloorsA = require(Builders.OfficeFloorsA)
local Text = require(Builders.OfficeFloorsA.Text)

local LOBBY_ONLY_ANCHORS = { entry = true, elevators = true, receptionist = true }

local function entryFor(module: string): any
	for _, e in World.templates do
		if e.module == module then
			return e
		end
	end
	error("no World.templates entry for " .. module)
end

local ENTRY = entryFor("OfficeFloorsA")

local cache: { [string]: Model } = {}
local function floor(id: string): Model
	local m = cache[id]
	if not m then
		m = OfficeFloorsA.build(id, nil)
		cache[id] = m
	end
	return m
end

local function parts(root: Instance): { BasePart }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function withAttr(root: Instance, attr: string, value: any?): { Instance }
	local out = {}
	for _, d in root:GetDescendants() do
		local v = d:GetAttribute(attr)
		if v ~= nil and (value == nil or v == value) then
			table.insert(out, d)
		end
	end
	return out
end

local function tagged(root: Instance, tag: string): { Instance }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:HasTag(tag) then
			table.insert(out, d)
		end
	end
	return out
end

local function interacts(root: Instance, id: string): { BasePart }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("InteractId") == id then
			table.insert(out, d)
		end
	end
	return out
end

local function decorSlots(root: Instance): { BasePart }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d:HasTag("DecorSlot") then
			table.insert(out, d)
		end
	end
	return out
end

local function sortedBy(list: { Instance }, attr: string): { Instance }
	local copy = table.clone(list)
	table.sort(copy, function(a, b)
		return (a:GetAttribute(attr) :: number) < (b:GetAttribute(attr) :: number)
	end)
	return copy
end

return function(t)
	t.describe("OfficeFloorsA module", function()
		t.it("builds exactly the templates Config/World assigns to it", function()
			t.expect(OfficeFloorsA.TEMPLATES).toEqual(ENTRY.templates)
			t.expect(ENTRY.owner).toBe("officesA")
		end)
		t.it("refuses unknown template ids", function()
			t.expect(function()
				OfficeFloorsA.build("nope", nil)
			end).toThrow("unknown template")
		end)
		t.it("parents the template to the given parent", function()
			local folder = Instance.new("Folder")
			local m = OfficeFloorsA.build("st", folder)
			t.expect(m.Parent).toBe(folder)
		end)
	end)

	for _, id in ENTRY.templates do
		t.describe("floor template " .. id, function()
			t.it("has a Root PrimaryPart at the origin and the floor attributes", function()
				local m = floor(id)
				t.expect(m.Name).toBe(id)
				t.expect(m.PrimaryPart ~= nil).toBeTruthy()
				local p = (m.PrimaryPart :: BasePart).CFrame.Position
				t.expect(p.Magnitude).toBeLessThan(0.001)
				t.expect(m:GetAttribute("LightingPreset")).toBe("office_interior")
				t.expect(table.find(World.lightingPresets, m:GetAttribute("LightingPreset")) ~= nil).toBeTruthy()
				t.expect(m:GetAttribute("Department")).toBe(id)
			end)

			t.it("stays inside the template bounds and the part budget, all parts anchored", function()
				local m = floor(id)
				local list = parts(m)
				t.expect(#list).toBeLessThanOrEqual(ENTRY.budget)
				for _, p in list do
					local pos = p.CFrame.Position
					if math.abs(pos.X) > World.TEMPLATE_HALF or math.abs(pos.Z) > World.TEMPLATE_HALF then
						error(p:GetFullName() .. " outside the template XZ bounds at " .. tostring(pos))
					end
					if pos.Y < -10 or pos.Y > World.TEMPLATE_HEIGHT then
						error(p:GetFullName() .. " outside the template height at " .. tostring(pos))
					end
					if not p.Anchored then
						error(p:GetFullName() .. " is not anchored")
					end
				end
			end)

			t.it("has exactly one of each floor OfficeAnchor and no lobby anchors", function()
				local m = floor(id)
				for _, name in World.templateMarkers.OfficeAnchor do
					local found = withAttr(m, "OfficeAnchor", name)
					if LOBBY_ONLY_ANCHORS[name] then
						t.expect(#found).toBe(0)
					else
						if #found ~= 1 then
							error(("OfficeAnchor %s found %d times"):format(name, #found))
						end
						local a = found[1] :: BasePart
						t.expect(a:IsA("BasePart")).toBeTruthy()
						t.expect(a:GetAttribute("AnchorId")).toBe(name)
						t.expect(a:HasTag("Anchor")).toBeTruthy()
						t.expect(a.CanCollide).toBe(false)
						t.expect(a.Transparency).toBe(1)
						-- root height: about 3 studs over the floor (y = 0), facing level
						t.expect(a.CFrame.Position.Y).toBeBetween(2.5, 3.5)
						t.expect(math.abs(a.CFrame.LookVector.Y)).toBeLessThan(0.01)
					end
				end
			end)

			t.it("has one OfficeDoor to_lobby trigger (and no exit door)", function()
				local m = floor(id)
				local doors = withAttr(m, "OfficeDoor")
				t.expect(#doors).toBe(1)
				local d = doors[1] :: BasePart
				t.expect(d:GetAttribute("OfficeDoor")).toBe("to_lobby")
				t.expect(d:HasTag("Door")).toBeTruthy()
				t.expect(type(d:GetAttribute("DoorId"))).toBe("string")
				t.expect(d.CanQuery).toBe(true)
				t.expect(d.CanCollide).toBe(false)
				t.expect(d.Size.X).toBeGreaterThanOrEqual(6)
				t.expect(d.Size.Y).toBeGreaterThanOrEqual(9)
			end)

			t.it("has every template EventSpot exactly once", function()
				local m = floor(id)
				for _, spot in World.templateEventSpots do
					local found = withAttr(m, "EventSpot", spot)
					if #found ~= 1 then
						error(("EventSpot %s found %d times"):format(spot, #found))
					end
					t.expect(found[1]:HasTag("EventSpot")).toBeTruthy()
				end
				t.expect(#tagged(m, "EventSpot")).toBe(#World.templateEventSpots)
			end)

			t.it("has exactly World.floorSlots.desks desk pods, each fully equipped", function()
				local m = floor(id)
				local desks = tagged(m, "DeskSlot")
				t.expect(#desks).toBe(World.floorSlots.desks)
				t.expect(#withAttr(m, "DeskSlot")).toBe(World.floorSlots.desks)
				local terminals = 0
				for i, desk in sortedBy(desks, "DeskSlot") do
					t.expect(desk:IsA("Model")).toBeTruthy()
					t.expect(desk:GetAttribute("DeskSlot")).toBe(i)
					t.expect((desk :: Model).PrimaryPart ~= nil).toBeTruthy()
					t.expect(#interacts(desk, "work_desk")).toBe(1)
					local term = #interacts(desk, "terminal")
					t.expect(term <= 1).toBeTruthy()
					if i % 2 == 0 then
						t.expect(term).toBe(1)
					end
					terminals += term
					local housing = interacts(desk, "housing_panel")
					t.expect(#housing).toBe(1)
					t.expect(housing[1]:GetAttribute("Context")).toBe("desk")
					local plates = 0
					for _, d in desk:GetDescendants() do
						if d.Name == "Nameplate" and d:IsA("BasePart") then
							plates += 1
						end
					end
					t.expect(plates).toBe(1)
					local plaques, other, ids = 0, 0, {}
					for _, s in decorSlots(desk) do
						local kind = s:GetAttribute("SlotKind")
						t.expect(table.find(Decor.SLOT_KINDS, kind) ~= nil).toBeTruthy()
						local sid = s:GetAttribute("SlotId")
						t.expect(type(sid)).toBe("string")
						t.expect(ids[sid]).toBeNil()
						ids[sid] = true
						if kind == "plaque" then
							plaques += 1
						else
							other += 1
						end
					end
					t.expect(plaques).toBe(World.floorSlots.plaquesPerDesk)
					t.expect(other).toBe(2)
					t.expect(ids["desk_item"]).toBe(true)
					t.expect(ids["desk_monitor"]).toBe(true)
					-- a chair for the sitter (OfficeService NPCs sit on it)
					local chair = desk:FindFirstChild("Chair")
					t.expect(chair ~= nil and chair:IsA("Model")).toBeTruthy()
				end
				t.expect(terminals).toBeGreaterThanOrEqual(World.floorSlots.desks // 2)
			end)

			t.it("plaque slots sit on the desk surface", function()
				local m = floor(id)
				for _, desk in tagged(m, "DeskSlot") do
					local top = (desk :: Model).PrimaryPart :: BasePart
					local surface = top.CFrame.Position.Y + top.Size.Y / 2
					for _, s in decorSlots(desk) do
						if s:GetAttribute("SlotKind") == "plaque" then
							local bottom = s.CFrame.Position.Y - s.Size.Y / 2
							t.expect(math.abs(bottom - surface)).toBeLessThan(0.05)
						end
					end
				end
			end)

			t.it("has exactly World.floorSlots.offices private offices, each fully equipped", function()
				local m = floor(id)
				local offices = tagged(m, "OfficeSlot")
				t.expect(#offices).toBe(World.floorSlots.offices)
				for i, office in sortedBy(offices, "OfficeSlot") do
					t.expect(office:IsA("Model")).toBeTruthy()
					t.expect(office:GetAttribute("OfficeSlot")).toBe(i)
					t.expect(#interacts(office, "work_desk")).toBe(1)
					t.expect(#interacts(office, "terminal")).toBe(1)
					local housing = interacts(office, "housing_panel")
					t.expect(#housing).toBe(1)
					t.expect(housing[1]:GetAttribute("Context")).toBe("office")
					t.expect(#tagged(office, "ThemeWall")).toBeGreaterThanOrEqual(1)
					t.expect(#tagged(office, "ThemeFloor")).toBeGreaterThanOrEqual(1)
					local glass = 0
					for _, d in office:GetDescendants() do
						if d:IsA("BasePart") and d.Material == Enum.Material.Glass and d.CanCollide then
							glass += 1
						end
					end
					t.expect(glass).toBeGreaterThanOrEqual(1)
					local plates = 0
					for _, d in office:GetDescendants() do
						if d.Name == "Nameplate" and d:IsA("BasePart") then
							plates += 1
						end
					end
					t.expect(plates).toBe(1)
					local shelf = office:FindFirstChild("Bookshelf")
					t.expect(shelf ~= nil).toBeTruthy()
					local shelfPlaques, ids = 0, {}
					for _, s in decorSlots(shelf :: Instance) do
						t.expect(s:GetAttribute("SlotKind")).toBe("plaque")
						shelfPlaques += 1
						local sid = s:GetAttribute("SlotId")
						t.expect(ids[sid]).toBeNil()
						ids[sid] = true
					end
					t.expect(shelfPlaques).toBe(World.floorSlots.plaquesPerShelf)
					local plaques, other, all = 0, 0, {}
					for _, s in decorSlots(office) do
						local kind = s:GetAttribute("SlotKind")
						t.expect(table.find(Decor.SLOT_KINDS, kind) ~= nil).toBeTruthy()
						local sid = s:GetAttribute("SlotId")
						t.expect(all[sid]).toBeNil()
						all[sid] = true
						if kind == "plaque" then
							plaques += 1
						else
							other += 1
						end
					end
					t.expect(plaques).toBe(World.floorSlots.plaquesPerShelf)
					t.expect(other).toBeGreaterThanOrEqual(5)
				end
			end)

			t.it("has the boss office, the conference table and the branding", function()
				local m = floor(id)
				t.expect(#interacts(m, "boss_review")).toBe(1)
				t.expect(#interacts(m, "project_desk")).toBeGreaterThanOrEqual(1)
				local boss = m:FindFirstChild("BossOffice", true)
				t.expect(boss ~= nil).toBeTruthy()
				local chair = withAttr(m, "OfficeAnchor", "boss_chair")[1] :: BasePart
				local spot = withAttr(m, "OfficeAnchor", "review_spot")[1] :: BasePart
				local desk = interacts(m, "boss_review")[1]
				t.expect(chair:IsDescendantOf(boss :: Instance)).toBeTruthy()
				t.expect(spot:IsDescendantOf(boss :: Instance)).toBeTruthy()
				-- boss behind the desk facing the review spot, the player in front facing the boss
				local toSpot = (spot.CFrame.Position - chair.CFrame.Position).Unit
				t.expect(chair.CFrame.LookVector:Dot(toSpot)).toBeGreaterThan(0.9)
				t.expect(spot.CFrame.LookVector:Dot(-toSpot)).toBeGreaterThan(0.9)
				local d = desk.CFrame.Position
				local between = (d - chair.CFrame.Position):Dot(toSpot)
				t.expect(between).toBeGreaterThan(0)
				t.expect(between).toBeLessThan((spot.CFrame.Position - chair.CFrame.Position).Magnitude)
				-- the pantry's pizza spot stands on a table
				t.expect(#withAttr(m, "EventSpot", "pizza_table")).toBe(1)
				-- CompanyLogo / CompanyName / FirmColor for OfficeService's branding
				local logos = tagged(m, "CompanyLogo")
				t.expect(#logos).toBeGreaterThanOrEqual(1)
				for _, l in logos do
					t.expect(l:IsA("BasePart")).toBeTruthy()
					t.expect(l:GetAttribute("LogoFace")).toBe("Front")
				end
				local names = 0
				for _, d2 in m:GetDescendants() do
					if d2:IsA("TextLabel") and d2.Name == "CompanyName" then
						names += 1
					end
				end
				t.expect(names).toBeGreaterThanOrEqual(1)
				t.expect(#tagged(m, "FirmColor")).toBeGreaterThanOrEqual(2)
			end)

			t.it("tags light sources and keeps Light instances sparing", function()
				local m = floor(id)
				t.expect(#tagged(m, "InteriorLight")).toBeGreaterThan(4)
				t.expect(#tagged(m, "StreetLight")).toBe(0)
				local lights = 0
				for _, d in m:GetDescendants() do
					if d:IsA("Light") then
						lights += 1
						t.expect(d.Parent ~= nil and d.Parent:IsA("BasePart")).toBeTruthy()
					end
				end
				t.expect(lights).toBeGreaterThan(0)
				t.expect(lights).toBeLessThanOrEqual(30)
			end)

			t.it("names every interact with a known InteractId", function()
				local m = floor(id)
				for _, d in tagged(m, "Interact") do
					local iid = d:GetAttribute("InteractId")
					if World.interactIds[iid] == nil then
						error(d:GetFullName() .. " has unknown InteractId " .. tostring(iid))
					end
					t.expect((d :: BasePart).CanQuery).toBe(true)
				end
			end)

			t.it("is deterministic", function()
				local a = OfficeFloorsA.build(id, nil)
				local b = OfficeFloorsA.build(id, nil)
				local pa, pb = parts(a), parts(b)
				t.expect(#pa).toBe(#pb)
				for i = 1, #pa, 37 do
					t.expect(pa[i].Name).toBe(pb[i].Name)
					t.expect((pa[i].CFrame.Position - pb[i].CFrame.Position).Magnitude).toBeLessThan(1e-6)
					t.expect(pa[i].Color).toEqual(pb[i].Color)
				end
			end)
		end)
	end

	t.describe("placeholder floors", function()
		for _, id in ENTRY.templates do
			if id ~= "ib" then
				t.it(id .. " is marked as a placeholder under renovation", function()
					local m = floor(id)
					t.expect(m:GetAttribute("Placeholder")).toBe(true)
					local found = false
					for _, d in m:GetDescendants() do
						if d:IsA("TextLabel") and d.Text == Text.get("renovation_title") then
							found = true
						end
					end
					t.expect(found).toBe(true)
				end)
			end
		end
		t.it("the IB floor is not a placeholder", function()
			t.expect(floor("ib"):GetAttribute("Placeholder")).toBeNil()
		end)
	end)
end
