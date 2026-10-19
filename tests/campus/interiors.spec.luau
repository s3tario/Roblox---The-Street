-- The Eastbridge interiors builder (src/world/CampusInteriors) under Lune: the four venues (career_center, lecture,
-- dorm, subway) each inside its Config/World interior slot and under the shared part budget; every anchor, door,
-- NPC spot, event spot and interact Config/World assigns to them exactly once; the dorm's 24 rooms with their
-- nameplates, theme surfaces, housing panels, mirrors and decor slots (cross-checked with HousingService's own marker
-- reader); and that every arrival lands on a floor, clear of walls, inside a closed room.

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Decor = require(Shared.Config.Decor)
local Builders = game:GetService("ServerStorage").WorldBuilders
local CampusInteriors = require(Builders.CampusInteriors)
local HousingMarkers = require(game:GetService("ServerScriptService").Server.Services.HousingService.Markers)

local ZONES = { "career_center", "lecture", "dorm", "subway" }

-- interacts each interior must hold (exact counts; npc spots are checked separately)
local INTERACTS: { [string]: { [string]: number } } = {
	career_center = { profile_builder = 1, career_services = 1, work_desk = 4, terminal = 2, bulletin = 1 },
	lecture = { work_desk = 5, terminal = 2 },
	dorm = { terminal = 1, housing_panel = 24, wardrobe = 24 },
	subway = {},
}

local cached: Model? = nil
local function interiors(): Model
	if not cached then
		cached = CampusInteriors.build(Instance.new("Folder"))
	end
	return cached :: Model
end

local function venue(id: string): Model
	local m = interiors():FindFirstChild(id)
	assert(m and m:IsA("Model"), "no interior model " .. id)
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

local function withAttr(root: Instance, attr: string, value: any): { Instance }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:GetAttribute(attr) == value then
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

local function entry(module: string): any
	for _, e in World.builders do
		if e.module == module then
			return e
		end
	end
	error("no World.builders entry for " .. module)
end

local function sortedKeys(t: { [string]: any }, zone: string): { string }
	local out = {}
	for id, def in t do
		if def.zone == zone then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

local function inZone(pos: Vector3, zone: string): boolean
	local mn, mx = World.interiorBounds(zone)
	return pos.X >= mn.X and pos.X <= mx.X and pos.Y >= mn.Y and pos.Y <= mx.Y and pos.Z >= mn.Z and pos.Z <= mx.Z
end

---------------------------------------------------------------------------------------------------
-- collision geometry
---------------------------------------------------------------------------------------------------
type Solid = { cf: CFrame, half: Vector3, part: BasePart }
local solidsCache: { Solid }? = nil
local function solids(): { Solid }
	if solidsCache then
		return solidsCache
	end
	local out: { Solid } = {}
	for _, p in parts(interiors()) do
		if p.CanCollide then
			table.insert(out, { cf = p.CFrame, half = p.Size / 2, part = p })
		end
	end
	solidsCache = out
	return out
end

local function solidAt(pos: Vector3): BasePart?
	for _, s in solids() do
		local l = s.cf:PointToObjectSpace(pos)
		if math.abs(l.X) < s.half.X - 0.05 and math.abs(l.Y) < s.half.Y - 0.05 and math.abs(l.Z) < s.half.Z - 0.05 then
			return s.part
		end
	end
	return nil
end

local function bodyClear(root: Vector3): (boolean, BasePart?)
	for _, dy in { -2.4, 0, 2 } do
		local hit = solidAt(root + Vector3.new(0, dy, 0))
		if hit then
			return false, hit
		end
	end
	return true, nil
end

local function groundUnder(root: Vector3, depth: number?): boolean
	local d = 2.5
	while d <= (depth or 4.5) do
		if solidAt(root - Vector3.new(0, d, 0)) then
			return true
		end
		d += 0.25
	end
	return false
end

-- Distance along a ray to the first collidable part (slab test against each oriented box), or nil.
local function rayHit(origin: Vector3, dir: Vector3, maxDist: number): number?
	local best: number? = nil
	for _, s in solids() do
		local o = s.cf:PointToObjectSpace(origin)
		local d = s.cf:VectorToObjectSpace(dir)
		local tmin, tmax = 0, maxDist
		local hit = true
		for _, axis in { "X", "Y", "Z" } do
			local oa, da, h = (o :: any)[axis] :: number, (d :: any)[axis] :: number, (s.half :: any)[axis] :: number
			if math.abs(da) < 1e-9 then
				if oa < -h or oa > h then
					hit = false
					break
				end
			else
				local t1, t2 = (-h - oa) / da, (h - oa) / da
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				tmin = math.max(tmin, t1)
				tmax = math.min(tmax, t2)
				if tmin > tmax then
					hit = false
					break
				end
			end
		end
		if hit and (best == nil or tmin < (best :: number)) then
			best = tmin
		end
	end
	return best
end

-- Every horizontal direction (and straight up) from a root position runs into a wall within `reach` studs.
local function enclosed(root: Vector3, reach: number): (boolean, string?)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		for _, dy in { -1.5, 1 } do
			if rayHit(root + Vector3.new(0, dy, 0), dir, reach) == nil then
				return false, ("open toward %s at dy %.1f"):format(tostring(dir), dy)
			end
		end
	end
	if rayHit(root, Vector3.yAxis, reach) == nil then
		return false, "no ceiling"
	end
	return true, nil
end

---------------------------------------------------------------------------------------------------
return function(t)
	t.describe("CampusInteriors module", function()
		t.it("is registered for the four campus interiors with its budget", function()
			local e = entry("CampusInteriors")
			t.expect(e.owner).toBe("campus")
			t.expect(e.budget).toBe(3500)
			for _, z in ZONES do
				t.expect(table.find(e.zones, z) ~= nil).toBeTruthy()
				t.expect(World.interiors[z].builder).toBe("CampusInteriors")
			end
		end)

		t.it("returns a Model parented to the given parent with one Model per interior", function()
			local folder = Instance.new("Folder")
			local m = CampusInteriors.build(folder)
			t.expect(m:IsA("Model")).toBeTruthy()
			t.expect(m.Parent).toBe(folder)
			for _, z in ZONES do
				local v = m:FindFirstChild(z)
				t.expect(v ~= nil and v:IsA("Model")).toBeTruthy()
				t.expect((v :: Instance):GetAttribute("Interior")).toBe(z)
				t.expect((v :: Instance):GetAttribute("LightingPreset")).toBe(World.interiors[z].lighting)
			end
		end)

		t.it("stays under the part budget, with every part anchored and inside its own interior slot", function()
			local list = parts(interiors())
			t.expect(#list).toBeLessThanOrEqual(entry("CampusInteriors").budget)
			t.expect(#list).toBeGreaterThan(1500)
			for _, z in ZONES do
				for _, p in parts(venue(z)) do
					if not inZone(p.CFrame.Position, z) then
						error(p:GetFullName() .. " outside the " .. z .. " slot at " .. tostring(p.CFrame.Position))
					end
					if not p.Anchored then
						error(p:GetFullName() .. " is not anchored")
					end
				end
			end
			-- markers sit in their zones too
			for _, p in parts(interiors():FindFirstChild("Markers") :: Instance) do
				local ok = false
				for _, z in ZONES do
					ok = ok or inZone(p.CFrame.Position, z)
				end
				if not ok then
					error("marker " .. p.Name .. " is outside every campus interior")
				end
			end
		end)

		t.it("never stamps CompanyId (that marks office instances, where visitors are refused)", function()
			for _, d in interiors():GetDescendants() do
				if d:GetAttribute("CompanyId") ~= nil then
					error(d:GetFullName() .. " carries CompanyId")
				end
			end
		end)

		t.it("tags its light fixtures InteriorLight and keeps real Light instances sparing", function()
			for _, z in { "career_center", "lecture", "dorm", "subway" } do
				t.expect(#tagged(venue(z), "InteriorLight")).toBeGreaterThanOrEqual(2)
			end
			local lights = 0
			for _, d in interiors():GetDescendants() do
				if d:IsA("Light") then
					lights += 1
				end
			end
			t.expect(lights).toBeLessThanOrEqual(40)
		end)

		t.it("builds the same interiors every time (deterministic)", function()
			t.expect(#parts(CampusInteriors.build(nil))).toBe(#parts(interiors()))
		end)
	end)

	t.describe("markers", function()
		t.it("creates every interior anchor exactly once, inside its own slot", function()
			for _, z in ZONES do
				for _, id in sortedKeys(World.anchors, z) do
					local found = withAttr(interiors(), "AnchorId", id)
					if #found ~= 1 then
						error(("anchor %s found %d times"):format(id, #found))
					end
					local p = found[1] :: BasePart
					t.expect(p:HasTag("Anchor")).toBeTruthy()
					t.expect(inZone(p.Position, z)).toBeTruthy()
				end
			end
		end)

		t.it("creates every interior exit door exactly once (tag Door, queryable trigger, big enough)", function()
			local n = 0
			for _, z in ZONES do
				for _, id in sortedKeys(World.doors, z) do
					n += 1
					local found = withAttr(interiors(), "DoorId", id)
					if #found ~= 1 then
						error(("door %s found %d times"):format(id, #found))
					end
					local p = found[1] :: BasePart
					t.expect(p:HasTag("Door")).toBeTruthy()
					t.expect(p.CanQuery).toBe(true)
					t.expect(p.CanCollide).toBe(false)
					t.expect(p.Size.Y).toBeGreaterThanOrEqual(9)
					t.expect(math.max(p.Size.X, p.Size.Z)).toBeGreaterThanOrEqual(6)
					t.expect(inZone(p.Position, z)).toBeTruthy()
				end
			end
			t.expect(n).toBe(3)
		end)

		t.it("puts each entry anchor inside its exit door, close by and facing into the room", function()
			for _, pair in
				{
					{ "career_center_entry", "door_career_center_exit" },
					{ "lecture_entry", "door_lecture_exit" },
					{ "dorm_entry", "door_dorm_exit" },
				}
			do
				local a = withAttr(interiors(), "AnchorId", pair[1])[1] :: BasePart
				local d = withAttr(interiors(), "DoorId", pair[2])[1] :: BasePart
				local away = Vector3.new(a.Position.X - d.Position.X, 0, a.Position.Z - d.Position.Z)
				t.expect(away.Magnitude).toBeLessThan(16)
				-- far enough that arriving players aren't standing in the exit prompt's face
				t.expect(away.Magnitude).toBeGreaterThan(4)
				t.expect(a.CFrame.LookVector:Dot(away.Unit)).toBeGreaterThan(0.5)
				-- the door's front faces the player walking up to it from the room
				t.expect(d.CFrame.LookVector:Dot(-away.Unit)).toBeLessThan(-0.5)
			end
		end)

		t.it("hangs a lit sign above every exit door", function()
			for _, z in ZONES do
				for _, id in sortedKeys(World.doors, z) do
					local d = withAttr(interiors(), "DoorId", id)[1] :: BasePart
					local top = d.Position.Y + d.Size.Y / 2
					local found = false
					for _, s in venue(z):GetDescendants() do
						if s:IsA("SurfaceGui") and s.Parent and s.Parent:IsA("BasePart") then
							local p = (s.Parent :: BasePart).Position
							local flat = Vector3.new(p.X - d.Position.X, 0, p.Z - d.Position.Z).Magnitude
							if flat < 4 and p.Y > top - 1 and p.Y < top + 6 then
								found = true
							end
						end
					end
					if not found then
						error("no sign above " .. id)
					end
				end
			end
		end)

		t.it("creates the interior NPC spots exactly once, each in its own interior", function()
			for _, z in ZONES do
				for _, id in World.npcSpots[z] or {} do
					local found = withAttr(interiors(), "NpcId", id)
					if #found ~= 1 then
						error(("npc spot %s found %d times"):format(id, #found))
					end
					local p = found[1] :: BasePart
					t.expect(p:GetAttribute("InteractId")).toBe("npc")
					t.expect(inZone(p.Position, z)).toBeTruthy()
				end
			end
		end)

		t.it("creates the pizza table event spot in the Career Center", function()
			local found = withAttr(interiors(), "EventSpot", "pizza_table_campus")
			t.expect(#found).toBe(1)
			t.expect((found[1] :: Instance):HasTag("EventSpot")).toBeTruthy()
			t.expect(inZone((found[1] :: BasePart).Position, "career_center")).toBeTruthy()
		end)

		t.it("creates exactly the interacts each interior needs", function()
			for _, z in ZONES do
				local counts: { [string]: number } = {}
				for _, d in tagged(venue(z), "Interact") do
					local id = d:GetAttribute("InteractId")
					counts[id] = (counts[id] or 0) + 1
					t.expect((d :: BasePart).CanQuery).toBe(true)
				end
				for id, n in INTERACTS[z] do
					if counts[id] ~= n then
						error(("%s: interact %s found %d times, want %d"):format(z, id, counts[id] or 0, n))
					end
				end
				for id in counts do
					if INTERACTS[z][id] == nil then
						error(("%s: unexpected interact %s"):format(z, id))
					end
				end
			end
		end)

		t.it("keeps every interact reachable from somewhere a player can stand", function()
			for _, d in tagged(interiors(), "Interact") do
				local p = d :: BasePart
				local ok = false
				for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
					for _, reach in { 2.5, 4, 6 } do
						local probe = p.Position + dir * (reach + math.max(p.Size.X, p.Size.Z) / 2)
						for _, dy in { 0, -2, -4, 2 } do
							local root = Vector3.new(probe.X, probe.Y + dy, probe.Z)
							if bodyClear(root) and groundUnder(root) then
								ok = true
							end
						end
					end
				end
				if not ok then
					error("nowhere to stand near interact " .. p:GetFullName())
				end
			end
		end)
	end)

	t.describe("career center", function()
		t.it("has the Life Roll kiosk and Career Services desk in the lobby near the doors", function()
			local cc = venue("career_center")
			local entryA = withAttr(interiors(), "AnchorId", "career_center_entry")[1] :: BasePart
			for _, id in { "profile_builder", "career_services" } do
				local p = withAttr(cc, "InteractId", id)[1] :: BasePart
				t.expect((p.Position - entryA.Position).Magnitude).toBeLessThan(45)
			end
		end)

		t.it("has a recruiting suite for Superdays with the recruiter waiting outside it", function()
			local cc = venue("career_center")
			local suite = cc:FindFirstChild("RecruitingSuite")
			t.expect(suite ~= nil).toBeTruthy()
			local tables = 0
			for _, d in (suite :: Instance):GetDescendants() do
				if d.Name == "InterviewTable" then
					tables += 1
				end
			end
			t.expect(tables).toBeGreaterThanOrEqual(2)
			local r = withAttr(interiors(), "NpcId", "npc_recruiter")[1] :: BasePart
			local s = (suite :: Instance):FindFirstChild("SuperdaySchedule", true) :: BasePart
			t.expect((r.Position - s.Position).Magnitude).toBeLessThan(20)
		end)
	end)

	t.describe("dorm", function()
		local function units(): { Model }
			local out: { Model } = {}
			for _, d in venue("dorm"):GetDescendants() do
				if d:HasTag("UnitSlot") then
					table.insert(out, d :: Model)
				end
			end
			return out
		end

		t.it("has exactly 24 rooms tagged UnitSlot, numbered 1..24", function()
			local list = units()
			t.expect(#list).toBe(World.housing.dorm.count)
			t.expect(#list).toBe(24)
			local seen: { [number]: boolean } = {}
			for _, u in list do
				t.expect(u:IsA("Model")).toBeTruthy()
				local n = u:GetAttribute("UnitSlot")
				t.expect(type(n)).toBe("number")
				t.expect(n :: number).toBeBetween(1, 24)
				t.expect(seen[n :: number]).toBeNil()
				seen[n :: number] = true
				t.expect(u:GetAttribute("UnitKind")).toBe("dorm")
				t.expect(u.PrimaryPart ~= nil).toBeTruthy()
			end
			-- and nothing else in the campus interiors claims to be a unit
			local all = 0
			for _, d in interiors():GetDescendants() do
				if d:GetAttribute("UnitSlot") ~= nil or d:HasTag("UnitSlot") then
					all += 1
				end
			end
			t.expect(all).toBe(24)
		end)

		t.it(
			"gives every room a nameplate, theme surfaces, a dorm housing panel, a mirror and 4-6 decor slots",
			function()
				for _, u in units() do
					local name = u:GetFullName()
					local plates = 0
					local walls, floors = 0, 0
					local panels, mirrors = 0, 0
					local slotIds: { [string]: boolean } = {}
					local slots = 0
					for _, d in u:GetDescendants() do
						if d.Name == "Nameplate" or d:HasTag("Nameplate") then
							plates += 1
							t.expect(d:FindFirstChildWhichIsA("SurfaceGui", true) ~= nil).toBeTruthy()
						end
						if d:HasTag("ThemeWall") then
							walls += 1
						end
						if d:HasTag("ThemeFloor") then
							floors += 1
						end
						local iid = d:GetAttribute("InteractId")
						if iid == "housing_panel" then
							panels += 1
							t.expect(d:GetAttribute("Context")).toBe("dorm")
						elseif iid == "wardrobe" then
							mirrors += 1
						end
						if d:HasTag("DecorSlot") then
							slots += 1
							local kind = d:GetAttribute("SlotKind")
							local id = d:GetAttribute("SlotId")
							t.expect(Decor.ACCEPTS[kind] ~= nil).toBeTruthy()
							t.expect(kind ~= Decor.PLAQUE).toBeTruthy()
							t.expect(type(id)).toBe("string")
							if slotIds[id] then
								error(name .. " repeats decor slot id " .. tostring(id))
							end
							slotIds[id] = true
							t.expect((d :: BasePart).Transparency).toBe(1)
							t.expect((d :: BasePart).CanCollide).toBe(false)
						end
					end
					if plates ~= 1 then
						error(("%s has %d nameplates"):format(name, plates))
					end
					t.expect(walls).toBeGreaterThanOrEqual(1)
					t.expect(floors).toBeGreaterThanOrEqual(1)
					t.expect(panels).toBe(1)
					t.expect(mirrors).toBe(1)
					t.expect(slots).toBeBetween(4, 6)
				end
			end
		)

		t.it("reads back the same way through HousingService's marker reader", function()
			local list = HousingMarkers.containers(venue("dorm"), "unit")
			t.expect(#list).toBe(24)
			local firstIds: { string }? = nil
			for i, c in list do
				t.expect(c:GetAttribute("UnitSlot")).toBe(i)
				t.expect(HousingMarkers.unitKind(c)).toBe("dorm")
				local slots = HousingMarkers.slots(c)
				t.expect(#slots).toBeBetween(4, 6)
				local ids = {}
				for _, s in slots do
					table.insert(ids, s.id)
				end
				table.sort(ids)
				-- every room offers the same spots, so a layout carries over when a player gets another room
				if firstIds == nil then
					firstIds = ids
				else
					t.expect(ids).toEqual(firstIds)
				end
				t.expect(#HousingMarkers.nameplates(c)).toBe(1)
				local walls, floors = HousingMarkers.themeParts(c)
				t.expect(#walls).toBeGreaterThanOrEqual(1)
				t.expect(#floors).toBeGreaterThanOrEqual(1)
			end
		end)

		t.it("lets a player walk from the lobby into every room", function()
			for _, u in units() do
				local root = (u.PrimaryPart :: BasePart).CFrame
				-- just inside the doorway, and the middle of the room
				for _, depth in { 1.5, 7 } do
					local p = (root * CFrame.new(0, 2.5, -depth)).Position
					local ok, hit = bodyClear(p)
					if not ok then
						error(("%s blocked at depth %d by %s"):format(u.Name, depth, (hit :: BasePart):GetFullName()))
					end
					if not groundUnder(p) then
						error(u.Name .. " has no floor at depth " .. depth)
					end
				end
				-- the corridor outside the door
				local c = (root * CFrame.new(0, 2.5, 3)).Position
				t.expect(bodyClear(c)).toBeTruthy()
			end
		end)

		t.it("has a common room with a terminal and the roommate", function()
			local common = venue("dorm"):FindFirstChild("CommonRoom")
			t.expect(common ~= nil).toBeTruthy()
			t.expect(#withAttr(common :: Instance, "InteractId", "terminal")).toBe(1)
			local rm = withAttr(interiors(), "NpcId", "npc_roommate")[1] :: BasePart
			local tv = (common :: Instance):FindFirstChild("TVScreen", true) :: BasePart
			t.expect((rm.Position - tv.Position).Magnitude).toBeLessThan(30)
		end)
	end)

	t.describe("subway", function()
		t.it("puts the two ride anchors in two separate, closed cars", function()
			local a = withAttr(interiors(), "AnchorId", "subway_car_to_street")[1] :: BasePart
			local b = withAttr(interiors(), "AnchorId", "subway_car_to_campus")[1] :: BasePart
			t.expect((a.Position - b.Position).Magnitude).toBeGreaterThan(20)
			t.expect(a:IsDescendantOf(interiors())).toBeTruthy()
			local cars = venue("subway")
			t.expect(cars:FindFirstChild("ToStreet") ~= nil).toBeTruthy()
			t.expect(cars:FindFirstChild("ToCampus") ~= nil).toBeTruthy()
		end)
	end)

	t.describe("walkability", function()
		t.it("lands every arrival on a floor, clear of walls, inside a closed room", function()
			for _, z in ZONES do
				for _, id in sortedKeys(World.anchors, z) do
					local a = withAttr(interiors(), "AnchorId", id)[1] :: BasePart
					local ok, hit = bodyClear(a.Position)
					if not ok then
						error(("anchor %s is inside %s"):format(id, (hit :: BasePart):GetFullName()))
					end
					if not groundUnder(a.Position) then
						error("anchor " .. id .. " has no floor under it")
					end
					local closed, why = enclosed(a.Position, 280)
					if not closed then
						error(("anchor %s is not enclosed: %s"):format(id, why or "?"))
					end
				end
			end
		end)

		t.it("stands every NPC on a floor, clear of walls", function()
			for _, z in ZONES do
				for _, id in World.npcSpots[z] or {} do
					local p = withAttr(interiors(), "NpcId", id)[1] :: BasePart
					local ok, hit = bodyClear(p.Position)
					if not ok then
						error(("npc spot %s is inside %s"):format(id, (hit :: BasePart):GetFullName()))
					end
					if not groundUnder(p.Position) then
						error("npc spot " .. id .. " has no floor under it")
					end
				end
			end
		end)

		t.it("lets players walk up to every exit door", function()
			for _, z in ZONES do
				for _, id in sortedKeys(World.doors, z) do
					local d = withAttr(interiors(), "DoorId", id)[1] :: BasePart
					local front = d.CFrame * CFrame.new(0, 0, -(d.Size.Z / 2 + 2))
					local root = Vector3.new(front.Position.X, d.Position.Y - d.Size.Y / 2 + 3, front.Position.Z)
					local ok, hit = bodyClear(root)
					if not ok then
						error(("the approach to %s is blocked by %s"):format(id, (hit :: BasePart):GetFullName()))
					end
					if not groundUnder(root) then
						error("no floor in front of " .. id)
					end
				end
			end
		end)
	end)
end
