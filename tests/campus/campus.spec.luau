-- The Eastbridge exterior builder (src/world/Campus) under Lune: every marker Config/World assigns to the "campus"
-- zone exactly once with the right attributes (anchors, doors, NPC spots, event spots, the spawn), the five exterior
-- interacts (Co-op shop, recruiting board, store kiosk, Wall of Fame leaderboard, station directory), the region
-- bounds and part budget, the closed boundary, signs over the doors, lamps tagged StreetLight, and that nobody
-- arrives inside a wall or floating in the air.

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Builders = game:GetService("ServerStorage").WorldBuilders
local Campus = require(Builders.Campus)
local Plan = require(Builders.Campus.Plan)

local EXTERIOR_INTERACTS = {
	shop = 1,
	bulletin = 1,
	store_kiosk = 1,
	leaderboard = 1,
	company_directory = 1,
}

local cached: Model? = nil
local function campus(): Model
	if not cached then
		cached = Campus.build(Instance.new("Folder"))
	end
	return cached :: Model
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

-- Collidable parts as oriented boxes, for "is this point inside something solid" checks.
type Solid = { cf: CFrame, half: Vector3, part: BasePart }
local solidsCache: { Solid }? = nil
local function solids(): { Solid }
	if solidsCache then
		return solidsCache
	end
	local out: { Solid } = {}
	for _, p in parts(campus()) do
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

-- A standing character around a root position: feet, waist, head.
local function bodyClear(root: Vector3): (boolean, BasePart?)
	for _, dy in { -2.4, 0, 2 } do
		local hit = solidAt(root + Vector3.new(0, dy, 0))
		if hit then
			return false, hit
		end
	end
	return true, nil
end

-- Something walkable within `depth` studs under a root position (the feet are ~3 studs below the root).
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

local function signedAbove(door: BasePart): boolean
	local top = door.Position.Y + door.Size.Y / 2
	for _, d in campus():GetDescendants() do
		if d:IsA("SurfaceGui") and d.Parent and d.Parent:IsA("BasePart") then
			local p = (d.Parent :: BasePart).Position
			local flat = Vector3.new(p.X - door.Position.X, 0, p.Z - door.Position.Z).Magnitude
			if flat < 12 and p.Y > top - 1 and p.Y < top + 22 then
				return true
			end
		end
	end
	return false
end

return function(t)
	t.describe("Campus module", function()
		t.it("is registered for the campus region with its budget", function()
			local e = entry("Campus")
			t.expect(e.owner).toBe("campus")
			t.expect(table.find(e.zones, "campus") ~= nil).toBeTruthy()
			t.expect(e.budget).toBe(9000)
		end)

		t.it("returns a Model parented to the given parent, tagged with its region and lighting", function()
			local folder = Instance.new("Folder")
			local m = Campus.build(folder)
			t.expect(m:IsA("Model")).toBeTruthy()
			t.expect(m.Parent).toBe(folder)
			t.expect(m.Name).toBe("Campus")
			t.expect(m:GetAttribute("Region")).toBe("campus")
			t.expect(m:GetAttribute("LightingPreset")).toBe(World.zones.campus.lighting)
		end)

		t.it("builds the same town every time (deterministic)", function()
			local a = Campus.build(nil)
			t.expect(#parts(a)).toBe(#parts(campus()))
		end)

		t.it("stays inside the region and under the part budget, all parts anchored", function()
			local r = World.regions.campus
			local list = parts(campus())
			t.expect(#list).toBeLessThanOrEqual(entry("Campus").budget)
			t.expect(#list).toBeGreaterThan(4000)
			for _, p in list do
				local pos = p.CFrame.Position
				if pos.X < r.min.X or pos.X > r.max.X or pos.Z < r.min.Z or pos.Z > r.max.Z then
					error(p:GetFullName() .. " outside the campus region at " .. tostring(pos))
				end
				if pos.Y < r.min.Y or pos.Y > r.max.Y then
					error(p:GetFullName() .. " outside the campus height range at " .. tostring(pos))
				end
				if not p.Anchored then
					error(p:GetFullName() .. " is not anchored")
				end
			end
		end)

		t.it("never stamps CompanyId (that marks office instances, where visitors are refused)", function()
			for _, d in campus():GetDescendants() do
				if d:GetAttribute("CompanyId") ~= nil then
					error(d:GetFullName() .. " carries CompanyId")
				end
			end
		end)

		t.it("closes the play area with invisible boundary walls on all four sides", function()
			local B = Plan.PLAY
			local walls = {}
			for _, p in parts(campus()) do
				if p.Name == "Boundary" then
					t.expect(p.Transparency).toBe(1)
					t.expect(p.CanCollide).toBe(true)
					table.insert(walls, p)
				end
			end
			t.expect(#walls).toBeGreaterThanOrEqual(4)
			local o = Plan.ORIGIN
			local function covered(pos: Vector3): boolean
				for _, w in walls do
					local l = w.CFrame:PointToObjectSpace(pos)
					local h = w.Size / 2
					if math.abs(l.X) <= h.X and math.abs(l.Y) <= h.Y and math.abs(l.Z) <= h.Z then
						return true
					end
				end
				return false
			end
			-- walk the perimeter just outside the play area at head height: every point is walled
			for x = B.x0, B.x1, 4 do
				t.expect(covered(o + Vector3.new(x, 4, B.z0 - 2))).toBeTruthy()
				t.expect(covered(o + Vector3.new(x, 4, B.z1 + 2))).toBeTruthy()
			end
			for z = B.z0, B.z1, 4 do
				t.expect(covered(o + Vector3.new(B.x0 - 2, 4, z))).toBeTruthy()
				t.expect(covered(o + Vector3.new(B.x1 + 1.5, 4, z))).toBeTruthy()
			end
		end)

		t.it("tags its lamps StreetLight, with only a handful of real Light instances", function()
			t.expect(#tagged(campus(), "StreetLight")).toBeGreaterThanOrEqual(20)
			local lights = 0
			for _, d in campus():GetDescendants() do
				if d:IsA("Light") then
					lights += 1
				end
			end
			t.expect(lights).toBeLessThanOrEqual(60)
		end)
	end)

	t.describe("markers", function()
		t.it("keeps every marker in the Markers folder", function()
			local mk = campus():FindFirstChild("Markers")
			t.expect(mk ~= nil and mk:IsA("Folder")).toBeTruthy()
		end)

		t.it("creates every campus anchor exactly once (tag Anchor, AnchorId)", function()
			local ids = sortedKeys(World.anchors, "campus")
			t.expect(#ids).toBe(6)
			for _, id in ids do
				local found = withAttr(campus(), "AnchorId", id)
				if #found ~= 1 then
					error(("anchor %s found %d times"):format(id, #found))
				end
				local p = found[1] :: BasePart
				t.expect(p:HasTag("Anchor")).toBeTruthy()
				t.expect(p.CanCollide).toBe(false)
				t.expect(p.Transparency).toBe(1)
			end
		end)

		t.it("creates every campus door exactly once (tag Door, DoorId, queryable trigger)", function()
			local ids = sortedKeys(World.doors, "campus")
			t.expect(#ids).toBe(4)
			for _, id in ids do
				local found = withAttr(campus(), "DoorId", id)
				if #found ~= 1 then
					error(("door %s found %d times"):format(id, #found))
				end
				local p = found[1] :: BasePart
				t.expect(p:HasTag("Door")).toBeTruthy()
				t.expect(p.CanQuery).toBe(true)
				t.expect(p.CanCollide).toBe(false)
				t.expect(p.Size.Y).toBeGreaterThanOrEqual(9)
				t.expect(math.max(p.Size.X, p.Size.Z)).toBeGreaterThanOrEqual(6)
			end
		end)

		t.it("hangs a sign above every door", function()
			for _, id in sortedKeys(World.doors, "campus") do
				local door = withAttr(campus(), "DoorId", id)[1] :: BasePart
				if not signedAbove(door) then
					error("no sign above " .. id)
				end
			end
		end)

		t.it("puts each building's front anchor just outside its door, facing away from it", function()
			local pairsChecked = 0
			for _, def in World.doors do
				local d = def :: any
				local back = if type(d.target) == "string" then World.anchors[d.target] else nil
				if back and back.zone == "campus" then
					-- an interior exit returns here; find the exterior door that leads into that interior
					for outerId, outer in World.doors do
						local o = outer :: any
						if o.zone == "campus" and o.target and World.anchors[o.target].zone == d.zone then
							pairsChecked += 1
							local door = withAttr(campus(), "DoorId", outerId)[1] :: BasePart
							local a = withAttr(campus(), "AnchorId", d.target)[1] :: BasePart
							local away = Vector3.new(a.Position.X - door.Position.X, 0, a.Position.Z - door.Position.Z)
							t.expect(away.Magnitude).toBeLessThan(30)
							t.expect(away.Magnitude).toBeGreaterThan(2)
							t.expect(a.CFrame.LookVector:Dot(away.Unit)).toBeGreaterThan(0.5)
						end
					end
				end
			end
			t.expect(pairsChecked).toBe(3)
		end)

		t.it("puts the station platform anchor by the subway entrance", function()
			local door = withAttr(campus(), "DoorId", "door_campus_subway")[1] :: BasePart
			local a = withAttr(campus(), "AnchorId", "campus_station_platform")[1] :: BasePart
			local flat = Vector3.new(a.Position.X - door.Position.X, 0, a.Position.Z - door.Position.Z)
			t.expect(flat.Magnitude).toBeLessThan(30)
			-- not on top of the prompt, or arriving players would be offered the ride straight back
			t.expect((a.Position - door.Position).Magnitude).toBeGreaterThan(5)
		end)

		t.it("creates the campus NPC spots exactly once (npc interact, NpcId)", function()
			for _, id in World.npcSpots.campus do
				local found = withAttr(campus(), "NpcId", id)
				if #found ~= 1 then
					error(("npc spot %s found %d times"):format(id, #found))
				end
				local p = found[1] :: BasePart
				t.expect(p:GetAttribute("InteractId")).toBe("npc")
				t.expect(p:HasTag("Interact")).toBeTruthy()
			end
		end)

		t.it("creates the campus event spots exactly once", function()
			for _, id in World.eventSpots.campus do
				local found = withAttr(campus(), "EventSpot", id)
				if #found ~= 1 then
					error(("event spot %s found %d times"):format(id, #found))
				end
				t.expect((found[1] :: Instance):HasTag("EventSpot")).toBeTruthy()
			end
		end)

		t.it("has exactly one Spawn_campus SpawnLocation at the bus depot's campus_spawn anchor", function()
			local spawns = {}
			for _, d in campus():GetDescendants() do
				if d:IsA("SpawnLocation") then
					table.insert(spawns, d)
				end
			end
			t.expect(#spawns).toBe(1)
			local s = spawns[1] :: SpawnLocation
			t.expect(s.Name).toBe("Spawn_campus")
			t.expect(World.spawns.Spawn_campus.anchor).toBe("campus_spawn")
			t.expect(s.Neutral).toBe(true)
			t.expect(s.CanCollide).toBe(false)
			local a = withAttr(campus(), "AnchorId", "campus_spawn")[1] :: BasePart
			local flat = Vector3.new(a.Position.X - s.Position.X, 0, a.Position.Z - s.Position.Z)
			t.expect(flat.Magnitude).toBeLessThan(1)
			-- the depot: inside the depot yard of the plan
			local yard = Plan.depot.yard
			local lp = s.Position - Plan.ORIGIN
			t.expect(lp.X).toBeBetween(yard.x0, yard.x1)
			t.expect(lp.Z).toBeBetween(yard.z0, yard.z1)
		end)

		t.it("keeps door prompts out of reach of a fresh spawn", function()
			local s = campus():FindFirstChild("Spawn_campus", true) :: BasePart
			for _, id in sortedKeys(World.doors, "campus") do
				local door = withAttr(campus(), "DoorId", id)[1] :: BasePart
				t.expect((s.Position - door.Position).Magnitude).toBeGreaterThan(14)
			end
		end)
	end)

	t.describe("interacts", function()
		t.it("creates exactly the exterior interacts Config/World assigns to the campus", function()
			local counts: { [string]: number } = {}
			for _, d in tagged(campus(), "Interact") do
				local id = d:GetAttribute("InteractId")
				t.expect(type(id)).toBe("string")
				if id ~= "npc" then
					counts[id] = (counts[id] or 0) + 1
				end
				t.expect(World.interactIds[id] ~= nil).toBeTruthy()
				t.expect((d :: BasePart).CanQuery).toBe(true)
			end
			for id, n in EXTERIOR_INTERACTS do
				if counts[id] ~= n then
					error(("interact %s found %d times, want %d"):format(id, counts[id] or 0, n))
				end
			end
			for id in counts do
				t.expect(EXTERIOR_INTERACTS[id] ~= nil).toBeTruthy()
			end
		end)

		t.it("makes the Co-op counter the campus_store shop", function()
			local found = withAttr(campus(), "InteractId", "shop")
			t.expect(#found).toBe(1)
			t.expect((found[1] :: Instance):GetAttribute("Shop")).toBe("campus_store")
		end)

		t.it("names the Wall of Fame part Screen with BoardId CareerPrestige", function()
			local found = withAttr(campus(), "InteractId", "leaderboard")
			t.expect(#found).toBe(1)
			local s = found[1] :: BasePart
			t.expect(s.Name).toBe("Screen")
			t.expect(s:GetAttribute("BoardId")).toBe("CareerPrestige")
		end)

		t.it("puts the recruiting board by the Career Center entrance", function()
			local board = withAttr(campus(), "InteractId", "bulletin")[1] :: BasePart
			local door = withAttr(campus(), "DoorId", "door_campus_career_center")[1] :: BasePart
			t.expect((board.Position - door.Position).Magnitude).toBeLessThan(30)
		end)

		t.it("puts the company directory kiosk at the station", function()
			local kiosk = withAttr(campus(), "InteractId", "company_directory")[1] :: BasePart
			local door = withAttr(campus(), "DoorId", "door_campus_subway")[1] :: BasePart
			t.expect((kiosk.Position - door.Position).Magnitude).toBeLessThan(40)
		end)

		t.it("keeps every interact reachable from somewhere a player can stand", function()
			for _, d in tagged(campus(), "Interact") do
				local p = d :: BasePart
				if p:GetAttribute("InteractId") ~= "npc" then
					local ok = false
					for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
						for _, reach in { 3, 4.5, 6 } do
							local probe = p.Position + dir * (reach + math.max(p.Size.X, p.Size.Z) / 2)
							for _, dy in { 0, -2, 2 } do
								local root = probe + Vector3.new(0, dy, 0)
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
			end
		end)
	end)

	t.describe("walkability", function()
		t.it("never lands an arrival inside a wall, and always on solid ground", function()
			for _, id in sortedKeys(World.anchors, "campus") do
				local a = withAttr(campus(), "AnchorId", id)[1] :: BasePart
				local ok, hit = bodyClear(a.Position)
				if not ok then
					error(("anchor %s is inside %s"):format(id, (hit :: BasePart):GetFullName()))
				end
				if not groundUnder(a.Position) then
					error("anchor " .. id .. " has no floor under it")
				end
			end
			local s = campus():FindFirstChild("Spawn_campus", true) :: BasePart
			t.expect(bodyClear(s.Position + Vector3.new(0, 3.5, 0))).toBeTruthy()
			t.expect(groundUnder(s.Position + Vector3.new(0, 3, 0))).toBeTruthy()
		end)

		t.it("stands every NPC on the ground, clear of walls", function()
			for _, id in World.npcSpots.campus do
				local p = withAttr(campus(), "NpcId", id)[1] :: BasePart
				local ok, hit = bodyClear(p.Position)
				if not ok then
					error(("npc spot %s is inside %s"):format(id, (hit :: BasePart):GetFullName()))
				end
				if not groundUnder(p.Position) then
					error("npc spot " .. id .. " has no floor under it")
				end
			end
		end)

		t.it("lets players walk up to every door trigger", function()
			for _, id in sortedKeys(World.doors, "campus") do
				local door = withAttr(campus(), "DoorId", id)[1] :: BasePart
				local front = door.CFrame * CFrame.new(0, 0, -(door.Size.Z / 2 + 2))
				local root = Vector3.new(front.Position.X, door.Position.Y - door.Size.Y / 2 + 3, front.Position.Z)
				local ok, hit = bodyClear(root)
				if not ok then
					error(("the approach to %s is blocked by %s"):format(id, (hit :: BasePart):GetFullName()))
				end
				if not groundUnder(root) then
					error("no floor in front of " .. id)
				end
			end
		end)

		t.it("puts the event spots on open ground", function()
			for _, id in World.eventSpots.campus do
				local p = withAttr(campus(), "EventSpot", id)[1] :: BasePart
				local root = p.Position + Vector3.new(0, 2.5, 0)
				local ok, hit = bodyClear(root)
				if not ok then
					error(("event spot %s is inside %s"):format(id, (hit :: BasePart):GetFullName()))
				end
				if not groundUnder(root) then
					error("event spot " .. id .. " floats")
				end
			end
		end)
	end)
end
