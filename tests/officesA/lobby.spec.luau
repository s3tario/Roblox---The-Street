-- The company lobby template (OfficeLobby) under Lune: root and attributes, the lobby's OfficeAnchors (entry,
-- elevators, receptionist) and OfficeDoor exit, the elevator panels, the branded parts OfficeService re-skins,
-- passable gates, bounds, budget and determinism.

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Builders = game:GetService("ServerStorage").WorldBuilders
local OfficeLobby = require(Builders.OfficeLobby)
local Plan = require(Builders.OfficeLobby.Plan)

local FLOOR_ONLY_ANCHORS = { floor_entry = true, boss_chair = true, review_spot = true, rival_desk = true }

local function entryFor(module: string): any
	for _, e in World.templates do
		if e.module == module then
			return e
		end
	end
	error("no World.templates entry for " .. module)
end

local ENTRY = entryFor("OfficeLobby")

local built: Model? = nil
local function lobby(): Model
	if not built then
		built = OfficeLobby.build("lobby", nil)
	end
	return built :: Model
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

local function anchor(id: string): BasePart
	local found = withAttr(lobby(), "OfficeAnchor", id)
	assert(#found == 1, ("OfficeAnchor %s found %d times"):format(id, #found))
	return found[1] :: BasePart
end

-- Is the point inside a solid (colliding) part's box?
local function insideSolid(root: Instance, p: Vector3): BasePart?
	for _, part in parts(root) do
		if part.CanCollide and part.Transparency < 1 then
			local l = part.CFrame:PointToObjectSpace(p)
			local h = part.Size / 2
			if math.abs(l.X) < h.X and math.abs(l.Y) < h.Y and math.abs(l.Z) < h.Z then
				return part
			end
		end
	end
	return nil
end

return function(t)
	t.describe("OfficeLobby", function()
		t.it("builds exactly the template Config/World assigns to it", function()
			t.expect(OfficeLobby.TEMPLATES).toEqual(ENTRY.templates)
			t.expect(ENTRY.owner).toBe("officesA")
			t.expect(function()
				OfficeLobby.build("ib", nil)
			end).toThrow("unknown template")
		end)

		t.it("has a Root PrimaryPart at the origin and LightingPreset office_interior", function()
			local m = lobby()
			t.expect(m.Name).toBe("lobby")
			t.expect(m.PrimaryPart ~= nil).toBeTruthy()
			t.expect((m.PrimaryPart :: BasePart).CFrame.Position.Magnitude).toBeLessThan(0.001)
			t.expect(m:GetAttribute("LightingPreset")).toBe("office_interior")
		end)

		t.it("stays inside the template bounds and the part budget, all parts anchored", function()
			local list = parts(lobby())
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

		t.it("has exactly one of each lobby OfficeAnchor and no floor anchors", function()
			local m = lobby()
			for _, id in World.templateMarkers.OfficeAnchor do
				local found = withAttr(m, "OfficeAnchor", id)
				if FLOOR_ONLY_ANCHORS[id] then
					t.expect(#found).toBe(0)
				else
					local a = anchor(id)
					t.expect(a:GetAttribute("AnchorId")).toBe(id)
					t.expect(a:HasTag("Anchor")).toBeTruthy()
					t.expect(a.CFrame.Position.Y).toBeBetween(2.5, 3.5)
					t.expect(math.abs(a.CFrame.LookVector.Y)).toBeLessThan(0.01)
					-- a standing spot: nothing solid where the character's body goes
					t.expect(insideSolid(m, a.CFrame.Position)).toBeNil()
					t.expect(insideSolid(m, a.CFrame.Position + Vector3.new(0, 1.5, 0))).toBeNil()
				end
			end
		end)

		t.it("puts the entry just inside the revolving door, facing in, and the exit trigger at the door", function()
			local m = lobby()
			local doors = withAttr(m, "OfficeDoor")
			t.expect(#doors).toBe(1)
			local door = doors[1] :: BasePart
			t.expect(door:GetAttribute("OfficeDoor")).toBe("exit")
			t.expect(door:HasTag("Door")).toBeTruthy()
			t.expect(type(door:GetAttribute("DoorId"))).toBe("string")
			t.expect(door.CanQuery).toBe(true)
			t.expect(door.CanCollide).toBe(false)
			t.expect(door.Size.X).toBeGreaterThanOrEqual(6)
			t.expect(door.Size.Y).toBeGreaterThanOrEqual(9)
			-- the trigger's front faces the hall (north) and sits at the facade's door
			t.expect(door.CFrame.LookVector.Z).toBeGreaterThan(0.99)
			t.expect(math.abs(door.CFrame.Position.X - Plan.door.x)).toBeLessThan(0.5)
			t.expect(door.CFrame.Position.Z).toBeLessThan(Plan.door.z + Plan.door.radius + 3)
			local entry = anchor("entry")
			t.expect(entry.CFrame.LookVector.Z).toBeGreaterThan(0.99)
			local gap = entry.CFrame.Position.Z - door.CFrame.Position.Z
			t.expect(gap).toBeGreaterThan(door.Size.Z / 2)
			t.expect(gap).toBeLessThan(10)
			-- a sign above the door
			local signed = false
			for _, d in m:GetDescendants() do
				if d:IsA("SurfaceGui") and d.Parent and d.Parent.Name == "Transom" then
					signed = true
				end
			end
			t.expect(signed).toBe(true)
		end)

		t.it("puts the receptionist behind the desk facing the entrance", function()
			local r = anchor("receptionist")
			t.expect(r.CFrame.LookVector.Z).toBeLessThan(-0.99)
			t.expect(r.CFrame.Position.Z).toBeGreaterThan(Plan.reception.z + Plan.reception.depth / 2)
			t.expect(math.abs(r.CFrame.Position.X - Plan.reception.x)).toBeLessThan(Plan.reception.length / 2)
		end)

		t.it("has elevator panels in reach of the elevators anchor", function()
			local m = lobby()
			local panels = {}
			for _, d in tagged(m, "Interact") do
				if d:GetAttribute("InteractId") == "elevator_panel" then
					table.insert(panels, d)
				end
			end
			t.expect(#panels).toBeGreaterThanOrEqual(1)
			local e = anchor("elevators")
			local nearest = math.huge
			for _, p in panels do
				t.expect(p:IsA("BasePart")).toBeTruthy()
				t.expect((p :: BasePart).CanQuery).toBe(true)
				nearest = math.min(nearest, ((p :: BasePart).CFrame.Position - e.CFrame.Position).Magnitude)
			end
			-- OfficeService's prompts reach 10 studs
			t.expect(nearest).toBeLessThan(10)
			-- the anchor stands inside the elevator hall
			local h = Plan.elevatorHall
			local p = e.CFrame.Position
			t.expect(p.X > h.minX and p.X < h.maxX and p.Z > h.minZ and p.Z < h.maxZ).toBe(true)
		end)

		t.it("only uses known interact ids", function()
			for _, d in tagged(lobby(), "Interact") do
				local iid = d:GetAttribute("InteractId")
				if World.interactIds[iid] == nil then
					error(d:GetFullName() .. " has unknown InteractId " .. tostring(iid))
				end
			end
		end)

		t.it("carries the branded parts: a big CompanyLogo, CompanyName on a FirmColor band", function()
			local m = lobby()
			local logos = tagged(m, "CompanyLogo")
			t.expect(#logos).toBeGreaterThanOrEqual(1)
			local biggest = 0
			for _, l in logos do
				t.expect(l:IsA("BasePart")).toBeTruthy()
				t.expect(l:GetAttribute("LogoFace")).toBe("Front")
				local s = (l :: BasePart).Size
				biggest = math.max(biggest, s.X * s.Y)
			end
			t.expect(biggest).toBeGreaterThan(150)
			local onBand = 0
			for _, d in m:GetDescendants() do
				if d:IsA("TextLabel") and d.Name == "CompanyName" then
					local gui = d:FindFirstAncestorWhichIsA("SurfaceGui")
					local part = gui and gui.Parent
					if part and part:HasTag("FirmColor") then
						onBand += 1
					end
				end
			end
			t.expect(onBand).toBeGreaterThanOrEqual(1)
			t.expect(#tagged(m, "FirmColor")).toBeGreaterThanOrEqual(3)
		end)

		t.it("keeps the speed-gate lanes passable", function()
			local m = lobby()
			local cabs = {}
			for _, p in parts(m) do
				if p.Name == "GateCabinet" then
					table.insert(cabs, p)
				end
			end
			t.expect(#cabs).toBeGreaterThanOrEqual(2)
			table.sort(cabs, function(a, b)
				return a.CFrame.Position.Z < b.CFrame.Position.Z
			end)
			for i = 2, #cabs do
				local a, b = cabs[i - 1], cabs[i]
				local lane = (b.CFrame.Position.Z - b.Size.Z / 2) - (a.CFrame.Position.Z + a.Size.Z / 2)
				t.expect(lane).toBeGreaterThanOrEqual(4)
			end
			for _, p in parts(m) do
				if p.Name == "GateWing" then
					t.expect(p.CanCollide).toBe(false)
				end
			end
		end)

		t.it("seals the facade so nobody walks out onto the painted street", function()
			local m = lobby()
			local barriers = 0
			for _, p in parts(m) do
				if p.Name == "Boundary" then
					barriers += 1
					t.expect(p.CanCollide).toBe(true)
					t.expect(p.Transparency).toBe(1)
				end
			end
			t.expect(barriers).toBeGreaterThanOrEqual(2)
			-- the door drum is blocked across its middle
			local blocked = false
			for _, p in parts(m) do
				if p.Name == "Boundary" and p.CanCollide then
					local l = p.CFrame:PointToObjectSpace(Vector3.new(Plan.door.x, 3, Plan.door.z))
					local h = p.Size / 2
					if math.abs(l.X) < h.X and math.abs(l.Y) < h.Y and math.abs(l.Z) < h.Z then
						blocked = true
					end
				end
			end
			t.expect(blocked).toBe(true)
		end)

		t.it("tags light sources and keeps Light instances sparing", function()
			local m = lobby()
			t.expect(#tagged(m, "InteriorLight")).toBeGreaterThan(4)
			local lights = 0
			for _, d in m:GetDescendants() do
				if d:IsA("Light") then
					lights += 1
				end
			end
			t.expect(lights).toBeGreaterThan(0)
			t.expect(lights).toBeLessThanOrEqual(16)
		end)

		t.it("has a walkable floor under every anchor", function()
			local m = lobby()
			for _, id in { "entry", "elevators", "receptionist" } do
				local a = anchor(id)
				local below = a.CFrame.Position - Vector3.new(0, 3.5, 0)
				local hit = insideSolid(m, below)
				if not hit then
					error("no solid floor under " .. id)
				end
			end
		end)

		t.it("is deterministic", function()
			local a = OfficeLobby.build("lobby", nil)
			local b = OfficeLobby.build("lobby", nil)
			local pa, pb = parts(a), parts(b)
			t.expect(#pa).toBe(#pb)
			for i = 1, #pa, 13 do
				t.expect(pa[i].Name).toBe(pb[i].Name)
				t.expect((pa[i].CFrame.Position - pb[i].CFrame.Position).Magnitude).toBeLessThan(1e-6)
			end
		end)
	end)
end
