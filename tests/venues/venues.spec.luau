-- The five venue interiors (src/world/{CareerServices,ExecClub,Rooftop,Apartments,Galleria}) under Lune: each is
-- registered in Config/World with its budget and builds a Model inside its own interior slot; every anchor, door, NPC
-- spot, event spot and interact Config/World assigns to it exists exactly once with the right attributes and tags;
-- arrivals land on a floor, clear of walls, facing into the room; doors are big enough, reachable and signed; indoor
-- venues are visually sealed (every sight line ends on an opaque surface: walls or painted views) and tag their
-- light fixtures; builds are deterministic.

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Builders = game:GetService("ServerStorage").WorldBuilders

type VenueSpec = {
	module: string,
	zone: string,
	budget: number,
	minParts: number,
	indoor: boolean,
	interacts: { [string]: number }, -- exact counts of every InteractId except "npc"
	maxLights: number,
}

local VENUES: { VenueSpec } = {
	{
		module = "CareerServices",
		zone = "career_services",
		budget = 700,
		minParts = 350,
		indoor = true,
		interacts = { career_services = 3, store_kiosk = 1 },
		maxLights = 10,
	},
	{
		module = "ExecClub",
		zone = "exec_club",
		budget = 900,
		minParts = 450,
		indoor = true,
		interacts = { wardrobe = 1 },
		maxLights = 14,
	},
	{
		module = "Rooftop",
		zone = "rooftop",
		budget = 700,
		minParts = 300,
		indoor = false,
		interacts = {},
		maxLights = 8,
	},
	{
		module = "Apartments",
		zone = "apartments",
		budget = 2600,
		minParts = 1500,
		indoor = true,
		interacts = { housing_panel = 24, wardrobe = 24, terminal = 24 },
		maxLights = 40,
	},
	{
		module = "Galleria",
		zone = "galleria",
		budget = 1400,
		minParts = 800,
		indoor = true,
		interacts = { shop = 4, wardrobe = 1 },
		maxLights = 18,
	},
}

local ENTRY: { [string]: { anchor: string, door: string } } = {
	career_services = { anchor = "career_services_entry", door = "door_career_services_exit" },
	exec_club = { anchor = "exec_club_entry", door = "door_exec_club_exit" },
	rooftop = { anchor = "rooftop_entry", door = "door_rooftop_exit" },
	apartments = { anchor = "apartments_entry", door = "door_apartments_exit" },
	galleria = { anchor = "galleria_entry", door = "door_galleria_exit" },
}

---------------------------------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------------------------------
local built: { [string]: Model } = {}
local function venue(module: string): Model
	local m = built[module]
	if not m then
		local builder = require(Builders:FindFirstChild(module) :: any)
		m = builder.build(Instance.new("Folder"))
		built[module] = m
	end
	return m :: Model
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

type Box = { cf: CFrame, half: Vector3, part: BasePart }
local boxCache: { [string]: { solid: { Box }, opaque: { Box } } } = {}

-- solid = every colliding part (incl. invisible boundaries); opaque = every part you cannot see through
local function boxes(module: string): { solid: { Box }, opaque: { Box } }
	local c = boxCache[module]
	if c then
		return c
	end
	local solid, opaque = {}, {}
	for _, p in parts(venue(module)) do
		local b = { cf = p.CFrame, half = p.Size / 2, part = p }
		if p.CanCollide then
			table.insert(solid, b)
		end
		local painted = p:FindFirstChildWhichIsA("SurfaceGui") ~= nil
		if p.Transparency < 0.5 or painted then
			table.insert(opaque, b)
		end
	end
	c = { solid = solid, opaque = opaque }
	boxCache[module] = c
	return c
end

local function inside(list: { Box }, pos: Vector3): BasePart?
	for _, s in list do
		local l = s.cf:PointToObjectSpace(pos)
		if math.abs(l.X) < s.half.X - 0.05 and math.abs(l.Y) < s.half.Y - 0.05 and math.abs(l.Z) < s.half.Z - 0.05 then
			return s.part
		end
	end
	return nil
end

-- A standing character's body (feet, waist, head) around a root position is free of solids.
local function bodyClear(module: string, root: Vector3): (boolean, BasePart?)
	for _, dy in { -2.4, 0, 2 } do
		local hit = inside(boxes(module).solid, root + Vector3.new(0, dy, 0))
		if hit then
			return false, hit
		end
	end
	return true, nil
end

local function groundUnder(module: string, root: Vector3, depth: number?): boolean
	local d = 2.5
	while d <= (depth or 4.5) do
		if inside(boxes(module).solid, root - Vector3.new(0, d, 0)) then
			return true
		end
		d += 0.25
	end
	return false
end

-- Distance along a ray to the first box hit (slab test against each oriented box), or nil.
local function rayHit(list: { Box }, origin: Vector3, dir: Vector3, maxDist: number): (number?, BasePart?)
	local best: number? = nil
	local bestPart: BasePart? = nil
	for _, s in list do
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
			bestPart = s.part
		end
	end
	return best, bestPart
end

local function marker(module: string, attr: string, id: string): BasePart
	local found = withAttr(venue(module), attr, id)
	assert(#found == 1, ("%s %s found %d times in %s"):format(attr, id, #found, module))
	local p = found[1]
	assert(p:IsA("BasePart"), id .. " is not a part")
	return p :: BasePart
end

local function floorY(module: string, root: Vector3): number
	-- the top of the first solid below a root position
	local y = root.Y
	while y > root.Y - 8 do
		if inside(boxes(module).solid, Vector3.new(root.X, y, root.Z)) then
			return y
		end
		y -= 0.1
	end
	return root.Y - 3
end

---------------------------------------------------------------------------------------------------
return function(t)
	for _, v in VENUES do
		t.describe(v.module, function()
			t.it("is registered in Config/World for its interior with its budget", function()
				local entry = nil
				for _, e in World.builders do
					if e.module == v.module then
						entry = e
					end
				end
				assert(entry, "no World.builders entry for " .. v.module)
				t.expect(entry.owner).toBe("venues")
				t.expect(entry.budget).toBe(v.budget)
				t.expect(#entry.zones).toBe(1)
				t.expect(entry.zones[1]).toBe(v.zone)
				t.expect(World.interiors[v.zone].builder).toBe(v.module)
			end)

			t.it("returns its Model, parented, with Interior and LightingPreset", function()
				local folder = Instance.new("Folder")
				local m = require(Builders:FindFirstChild(v.module) :: any).build(folder)
				t.expect(m:IsA("Model")).toBeTruthy()
				t.expect(m.Parent).toBe(folder)
				t.expect(m:GetAttribute("Interior")).toBe(v.zone)
				t.expect(m:GetAttribute("LightingPreset")).toBe(World.interiors[v.zone].lighting)
				t.expect(m:FindFirstChild("Markers") ~= nil).toBeTruthy()
			end)

			t.it("stays under budget with every part anchored inside its slot", function()
				local list = parts(venue(v.module))
				t.expect(#list).toBeLessThanOrEqual(v.budget)
				t.expect(#list).toBeGreaterThan(v.minParts)
				for _, p in list do
					if not inZone(p.CFrame.Position, v.zone) then
						error(
							p:GetFullName()
								.. " is outside the "
								.. v.zone
								.. " slot at "
								.. tostring(p.CFrame.Position)
						)
					end
					if not p.Anchored then
						error(p:GetFullName() .. " is not anchored")
					end
				end
			end)

			t.it("builds the same venue every time", function()
				local again = require(Builders:FindFirstChild(v.module) :: any).build(nil)
				t.expect(#parts(again)).toBe(#parts(venue(v.module)))
				local a = marker(v.module, "AnchorId", ENTRY[v.zone].anchor)
				local b = withAttr(again, "AnchorId", ENTRY[v.zone].anchor)[1] :: BasePart
				t.expect((a.CFrame.Position - b.CFrame.Position).Magnitude).toBeLessThan(1e-3)
			end)

			t.it("never stamps CompanyId (that marks office instances)", function()
				for _, d in venue(v.module):GetDescendants() do
					if d:GetAttribute("CompanyId") ~= nil then
						error(d:GetFullName() .. " carries CompanyId")
					end
				end
			end)

			t.it("creates its anchor, exit door, NPC spots and event spots exactly once", function()
				for _, id in sortedKeys(World.anchors, v.zone) do
					local p = marker(v.module, "AnchorId", id)
					t.expect(p:HasTag("Anchor")).toBeTruthy()
					t.expect(p.CanCollide).toBe(false)
					t.expect(inZone(p.CFrame.Position, v.zone)).toBeTruthy()
				end
				local doors = sortedKeys(World.doors, v.zone)
				t.expect(#doors).toBe(1)
				for _, id in doors do
					local d = marker(v.module, "DoorId", id)
					t.expect(d:HasTag("Door")).toBeTruthy()
					t.expect(d.CanQuery).toBe(true)
					t.expect(d.CanCollide).toBe(false)
					t.expect(d.Size.Y).toBeGreaterThanOrEqual(9)
					t.expect(math.max(d.Size.X, d.Size.Z)).toBeGreaterThanOrEqual(6)
				end
				local npcs = World.npcSpots[v.zone] or {}
				t.expect(#npcs).toBeGreaterThan(0)
				for _, id in npcs do
					local p = marker(v.module, "NpcId", id)
					t.expect(p:GetAttribute("InteractId")).toBe("npc")
					t.expect(p:HasTag("Interact")).toBeTruthy()
					t.expect(inZone(p.CFrame.Position, v.zone)).toBeTruthy()
				end
				for _, id in World.eventSpots[v.zone] or {} do
					local p = marker(v.module, "EventSpot", id)
					t.expect(p:HasTag("EventSpot")).toBeTruthy()
				end
				-- nothing from another zone sneaks in
				for _, d in venue(v.module):GetDescendants() do
					local a = d:GetAttribute("AnchorId")
					if a ~= nil then
						t.expect(World.anchors[a].zone).toBe(v.zone)
					end
					local door = d:GetAttribute("DoorId")
					if door ~= nil then
						t.expect(World.doors[door].zone).toBe(v.zone)
					end
					local npc = d:GetAttribute("NpcId")
					if npc ~= nil then
						t.expect(table.find(npcs, npc) ~= nil).toBeTruthy()
					end
				end
			end)

			t.it("uses only Config/World interact ids, with their attributes, in the expected numbers", function()
				local counts: { [string]: number } = {}
				for _, d in venue(v.module):GetDescendants() do
					local id = d:GetAttribute("InteractId")
					if id ~= nil then
						local def = World.interactIds[id]
						if not def then
							error(d:GetFullName() .. " uses unknown InteractId " .. tostring(id))
						end
						t.expect(d:IsA("BasePart")).toBeTruthy()
						t.expect((d :: BasePart).CanQuery).toBe(true)
						t.expect(d:HasTag("Interact")).toBeTruthy()
						for _, attr in (def :: any).attrs or {} do
							if type(d:GetAttribute(attr)) ~= "string" then
								error(d:GetFullName() .. " (" .. id .. ") is missing attribute " .. attr)
							end
						end
						if id ~= "npc" then
							counts[id] = (counts[id] or 0) + 1
						end
					end
				end
				for id, n in v.interacts do
					if counts[id] ~= n then
						error(("%s has %d %s interacts, expected %d"):format(v.module, counts[id] or 0, id, n))
					end
				end
				for id, n in counts do
					if v.interacts[id] == nil then
						error(("%s has %d unexpected %s interacts"):format(v.module, n, id))
					end
				end
			end)

			t.it("lands arrivals on a floor, clear of walls, facing into the room from the exit", function()
				local e = ENTRY[v.zone]
				local a = marker(v.module, "AnchorId", e.anchor)
				local d = marker(v.module, "DoorId", e.door)
				local root = a.CFrame.Position
				local ok, hit = bodyClear(v.module, root)
				if not ok then
					error(e.anchor .. " is inside " .. (hit :: BasePart):GetFullName())
				end
				t.expect(groundUnder(v.module, root)).toBeTruthy()
				local away = Vector3.new(root.X - d.Position.X, 0, root.Z - d.Position.Z)
				t.expect(away.Magnitude).toBeGreaterThan(4)
				t.expect(away.Magnitude).toBeLessThan(16)
				t.expect(a.CFrame.LookVector:Dot(away.Unit)).toBeGreaterThan(0.5)
				-- the trigger's front faces the player walking up to it from the room
				t.expect(d.CFrame.LookVector:Dot(away.Unit)).toBeGreaterThan(0.5)
				-- the doorway in front of the trigger is walkable
				local at = Vector3.new(d.CFrame.Position.X, floorY(v.module, root) + 3, d.CFrame.Position.Z)
				t.expect((bodyClear(v.module, at))).toBeTruthy()
			end)

			t.it("hangs a lit sign above its exit door", function()
				local d = marker(v.module, "DoorId", ENTRY[v.zone].door)
				local found = false
				for _, p in parts(venue(v.module)) do
					if p.Name == "ExitSign" and p:FindFirstChildWhichIsA("SurfaceGui") then
						local off = p.CFrame.Position - d.CFrame.Position
						if
							Vector3.new(off.X, 0, off.Z).Magnitude < 3
							and off.Y > d.Size.Y / 2 - 1
							and off.Y < d.Size.Y / 2 + 4
						then
							found = true
						end
					end
				end
				t.expect(found).toBeTruthy()
			end)

			t.it("stands every NPC on a floor with room to stand", function()
				for _, id in World.npcSpots[v.zone] do
					local p = marker(v.module, "NpcId", id)
					local root = p.CFrame.Position
					local ok, hit = bodyClear(v.module, root)
					if not ok then
						error(id .. " stands inside " .. (hit :: BasePart):GetFullName())
					end
					if not groundUnder(v.module, root) then
						error(id .. " has no floor under it")
					end
				end
			end)

			t.it("tags its light fixtures and keeps real Light instances sparing", function()
				local lights = 0
				for _, d in venue(v.module):GetDescendants() do
					if d:IsA("Light") then
						lights += 1
					end
				end
				t.expect(lights).toBeGreaterThan(0)
				t.expect(lights).toBeLessThanOrEqual(v.maxLights)
				if v.indoor then
					t.expect(#tagged(venue(v.module), "InteriorLight")).toBeGreaterThanOrEqual(4)
					t.expect(#tagged(venue(v.module), "StreetLight")).toBe(0)
				else
					t.expect(#tagged(venue(v.module), "StreetLight")).toBeGreaterThanOrEqual(20)
				end
			end)

			t.it(
				"paints colour gradients over white frames (a UIGradient's colours multiply the frame's own)",
				function()
					local function white(c: Color3): boolean
						return c.R > 0.999 and c.G > 0.999 and c.B > 0.999
					end
					local checked = 0
					for _, g in venue(v.module):GetDescendants() do
						if g:IsA("UIGradient") then
							local coloured = false
							for _, k in g.Color.Keypoints do
								if not white(k.Value) then
									coloured = true
								end
							end
							local f = g.Parent
							if coloured and f and f:IsA("Frame") and f.BackgroundTransparency < 1 then
								checked += 1
								if not white(f.BackgroundColor3) then
									error(
										("%s tints its gradient with %s: the painted colours come out darker"):format(
											f:GetFullName(),
											tostring(f.BackgroundColor3)
										)
									)
								end
							end
						end
					end
					t.expect(checked).toBeGreaterThan(0)
				end
			)

			if v.indoor then
				t.it(
					"is visually sealed: every sight line from the arrival ends on a wall or a painted view",
					function()
						local a = marker(v.module, "AnchorId", ENTRY[v.zone].anchor)
						local eye = a.CFrame.Position + Vector3.new(0, 1.5, 0)
						local opaque = boxes(v.module).opaque
						for i = 0, 15 do
							local yaw = i / 16 * math.pi * 2
							for _, pitch in { -0.3, 0, 0.5, 1.1 } do
								local dir = Vector3.new(
									math.cos(yaw) * math.cos(pitch),
									math.sin(pitch),
									math.sin(yaw) * math.cos(pitch)
								)
								if rayHit(opaque, eye, dir, 400) == nil then
									error(
										("%s: sight line %s from the arrival escapes the venue"):format(
											v.module,
											tostring(dir)
										)
									)
								end
							end
						end
						t.expect(rayHit(opaque, eye, Vector3.yAxis, 400) ~= nil).toBeTruthy()
					end
				)
			end
		end)
	end
end
