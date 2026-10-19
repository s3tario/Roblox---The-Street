-- The Street builder (src/world/Street) under Lune: every marker Config/World assigns to the "street" zone exactly
-- once with the right attributes (anchors, doors, NPC spots, event spots, the spawn), a door and an anchor for every
-- tower, branding on every tower, the ten leaderboard Screens, the Exchange's ticker band, the interact points, the
-- region bounds and part budget, and that nobody arrives inside a wall.

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Builders = game:GetService("ServerStorage").WorldBuilders
local Street = require(Builders.Street)

local BOARD_IDS = {
	"CareerPrestige",
	"MarketSkill",
	"DealMastery",
	"FastestRun",
	"Comeback",
	"RobuxSpent",
	"TimePlayed",
	"LiveInvested",
	"Rebirths",
	"TopStats",
}

local cached: Model? = nil
local function street(): Model
	if not cached then
		cached = Street.build(Instance.new("Folder"))
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
	for _, p in parts(street()) do
		if p.CanCollide and p.Name ~= "InvisibleWall" then
			table.insert(out, { cf = p.CFrame, half = p.Size / 2, part = p })
		end
	end
	solidsCache = out
	return out
end

local function insideSolid(pos: Vector3): boolean
	for _, s in solids() do
		local l = s.cf:PointToObjectSpace(pos)
		if math.abs(l.X) < s.half.X - 0.05 and math.abs(l.Y) < s.half.Y - 0.05 and math.abs(l.Z) < s.half.Z - 0.05 then
			return true
		end
	end
	return false
end

-- The exterior anchor a street door's players come back out to: a tower's frontAnchor, or for a venue the target
-- of that venue's exit door. Ride doors (the subway) have none.
local function frontAnchorOf(doorId: string): string?
	local def = World.doors[doorId] :: any
	if def.frontAnchor then
		return def.frontAnchor
	end
	local inner = if def.target then World.anchors[def.target] else nil
	if inner then
		for _, other in World.doors do
			local o = other :: any
			local back = if type(o.target) == "string" then World.anchors[o.target] else nil
			if o.zone == inner.zone and back and back.zone == "street" then
				return o.target
			end
		end
	end
	return nil
end

-- A standing character around a root position: feet, waist, head.
local function bodyClear(root: Vector3): boolean
	for _, dy in { -2.4, 0, 2 } do
		if insideSolid(root + Vector3.new(0, dy, 0)) then
			return false
		end
	end
	return true
end

return function(t)
	t.describe("Street module", function()
		t.it("is registered for the street region with its budget", function()
			local e = entry("Street")
			t.expect(e.owner).toBe("street")
			t.expect(table.find(e.zones, "street") ~= nil).toBeTruthy()
		end)

		t.it("returns a Model parented to the given parent", function()
			local folder = Instance.new("Folder")
			local m = Street.build(folder)
			t.expect(m:IsA("Model")).toBeTruthy()
			t.expect(m.Parent).toBe(folder)
		end)

		t.it("stays inside the region and under the part budget, all parts anchored", function()
			local r = World.regions.street
			local list = parts(street())
			t.expect(#list).toBeLessThanOrEqual(entry("Street").budget)
			t.expect(#list).toBeGreaterThan(5000)
			for _, p in list do
				local pos = p.CFrame.Position
				if pos.X < r.min.X or pos.X > r.max.X or pos.Z < r.min.Z or pos.Z > r.max.Z then
					error(p:GetFullName() .. " outside the street region at " .. tostring(pos))
				end
				if pos.Y < r.min.Y or pos.Y > r.max.Y then
					error(p:GetFullName() .. " outside the street height range at " .. tostring(pos))
				end
				if not p.Anchored then
					error(p:GetFullName() .. " is not anchored")
				end
			end
		end)

		t.it("never stamps CompanyId (that marks office instances, where visitors are refused)", function()
			for _, d in street():GetDescendants() do
				if d:GetAttribute("CompanyId") ~= nil then
					error(d:GetFullName() .. " carries CompanyId")
				end
			end
		end)
	end)

	t.describe("markers", function()
		t.it("creates every street anchor exactly once (tag Anchor, AnchorId)", function()
			for _, id in sortedKeys(World.anchors, "street") do
				local found = withAttr(street(), "AnchorId", id)
				t.expect(#found).toBe(1)
				local p = found[1] :: BasePart
				t.expect(p:HasTag("Anchor")).toBeTruthy()
				t.expect(p.CanCollide).toBe(false)
				t.expect(p.Transparency).toBe(1)
			end
		end)

		t.it("creates every street door exactly once (tag Door, DoorId, queryable trigger)", function()
			for _, id in sortedKeys(World.doors, "street") do
				local found = withAttr(street(), "DoorId", id)
				t.expect(#found).toBe(1)
				local p = found[1] :: BasePart
				t.expect(p:HasTag("Door")).toBeTruthy()
				t.expect(p.CanQuery).toBe(true)
				t.expect(p.CanCollide).toBe(false)
				t.expect(p.Size.Y).toBeGreaterThanOrEqual(9)
				t.expect(math.max(p.Size.X, p.Size.Z)).toBeGreaterThanOrEqual(5)
			end
		end)

		t.it("gives every tower in Config/World its door and front anchor", function()
			for _, tower in World.towers do
				t.expect(#withAttr(street(), "DoorId", tower.door)).toBe(1)
				t.expect(#withAttr(street(), "AnchorId", tower.anchor)).toBe(1)
				t.expect(street():FindFirstChild("Tower_" .. tower.id, true) ~= nil).toBeTruthy()
			end
		end)

		t.it("puts each front anchor in front of its door, facing away from it", function()
			local checked = 0
			for _, id in sortedKeys(World.doors, "street") do
				local anchorId = frontAnchorOf(id)
				if anchorId then
					checked += 1
					local door = withAttr(street(), "DoorId", id)[1] :: BasePart
					local found = withAttr(street(), "AnchorId", anchorId)
					t.expect(#found).toBe(1)
					local a = found[1] :: BasePart
					local away = Vector3.new(a.Position.X - door.Position.X, 0, a.Position.Z - door.Position.Z)
					t.expect(away.Magnitude).toBeLessThan(30)
					t.expect(away.Magnitude).toBeGreaterThan(2)
					t.expect(a.CFrame.LookVector:Dot(away.Unit)).toBeGreaterThan(0.5)
				end
			end
			t.expect(checked).toBe(#World.towers + 5)
		end)

		t.it("creates the street NPC spots exactly once (npc interact, NpcId)", function()
			for _, id in World.npcSpots.street do
				local found = withAttr(street(), "NpcId", id)
				t.expect(#found).toBe(1)
				local p = found[1] :: BasePart
				t.expect(p:GetAttribute("InteractId")).toBe("npc")
				t.expect(p:HasTag("Interact")).toBeTruthy()
			end
		end)

		t.it("creates the street event spots exactly once", function()
			for _, id in World.eventSpots.street do
				local found = withAttr(street(), "EventSpot", id)
				t.expect(#found).toBe(1)
				t.expect((found[1] :: Instance):HasTag("EventSpot")).toBeTruthy()
			end
		end)

		t.it("has exactly one Spawn_street SpawnLocation at the station platform", function()
			local spawns = {}
			for _, d in street():GetDescendants() do
				if d:IsA("SpawnLocation") then
					table.insert(spawns, d)
				end
			end
			t.expect(#spawns).toBe(1)
			local s = spawns[1] :: SpawnLocation
			t.expect(s.Name).toBe("Spawn_street")
			t.expect(World.spawns.Spawn_street.anchor).toBe("street_station_platform")
			local a = withAttr(street(), "AnchorId", "street_station_platform")[1] :: BasePart
			local flat = Vector3.new(a.Position.X - s.Position.X, 0, a.Position.Z - s.Position.Z)
			t.expect(flat.Magnitude).toBeLessThan(1)
			t.expect(s.Neutral).toBe(true)
		end)

		t.it("keeps the subway prompt out of reach of a fresh spawn", function()
			local s = street():FindFirstChild("Spawn_street", true) :: BasePart
			local door = withAttr(street(), "DoorId", "door_street_subway")[1] :: BasePart
			t.expect((s.Position - door.Position).Magnitude).toBeGreaterThan(12.5)
		end)

		t.it("never lands an arrival inside a wall", function()
			for _, id in sortedKeys(World.anchors, "street") do
				local a = withAttr(street(), "AnchorId", id)[1] :: BasePart
				if not bodyClear(a.Position) then
					error("anchor " .. id .. " is inside a solid part at " .. tostring(a.Position))
				end
			end
			local s = street():FindFirstChild("Spawn_street", true) :: BasePart
			if not bodyClear(s.Position + Vector3.new(0, 3.5, 0)) then
				error("Spawn_street is inside a solid part")
			end
		end)

		t.it("lets players walk up to every door trigger", function()
			for _, id in sortedKeys(World.doors, "street") do
				local door = withAttr(street(), "DoorId", id)[1] :: BasePart
				local front = door.CFrame * CFrame.new(0, 0, -(door.Size.Z / 2 + 2))
				local foot = Vector3.new(front.Position.X, door.Position.Y - door.Size.Y / 2 + 3, front.Position.Z)
				if not bodyClear(foot) then
					error("the approach to " .. id .. " is blocked at " .. tostring(foot))
				end
			end
		end)
	end)

	t.describe("towers and branding", function()
		t.it("brands single-company towers with a CompanyLogo part carrying the company's LogoId", function()
			for _, tower in World.towers do
				local model = street():FindFirstChild("Tower_" .. tower.id, true) :: Instance
				if tower.company then
					local logos = tagged(model, "CompanyLogo")
					t.expect(#logos).toBeGreaterThanOrEqual(1)
					for _, l in logos do
						t.expect(l:IsA("BasePart")).toBeTruthy()
						t.expect(l:GetAttribute("LogoId")).toBe(tower.company)
					end
					-- something is drawn on it (the logo, or the gilt fallback label)
					local plate = logos[1]
					t.expect(plate:FindFirstChildWhichIsA("SurfaceGui") ~= nil).toBeTruthy()
				else
					local boards = {}
					for _, d in model:GetDescendants() do
						if d.Name == "TenantDirectory" then
							table.insert(boards, d)
						end
					end
					t.expect(#boards).toBe(1)
				end
			end
		end)

		t.it("lists every tenant of a multi-tenant tower on its directory board", function()
			for _, tower in World.towers do
				if tower.picker then
					local model = street():FindFirstChild("Tower_" .. tower.id, true) :: Instance
					local board = model:FindFirstChild("TenantDirectory", true) :: Instance
					local rows = 0
					for _, d in board:GetDescendants() do
						if d:IsA("TextLabel") and d.Text == "Lobby  >" then
							rows += 1
						end
					end
					t.expect(rows).toBe(#tower.picker)
				end
			end
		end)

		t.it("gives every tower a distinct style builder (no tower falls back silently)", function()
			local Towers = require(Builders.Street.Towers)
			for _, tower in World.towers do
				t.expect(Towers.STYLES[tower.style] ~= nil).toBeTruthy()
			end
		end)

		t.it("makes the bulge-bracket banks the tallest towers on the Street", function()
			local Plan = require(Builders.Street.Plan)
			local lots = Plan.assignLots(World.towers)
			local minBulge, maxOther = math.huge, 0
			for _, tower in World.towers do
				local h = (lots[tower.id] :: any).h
				if tower.style == "bulge" then
					minBulge = math.min(minBulge, h)
				else
					maxOther = math.max(maxOther, h)
				end
			end
			t.expect(minBulge).toBeGreaterThan(maxOther)
		end)
	end)

	t.describe("plaza and landmarks", function()
		t.it("has ten leaderboard Screens, one per BoardId, each a leaderboard interact", function()
			local screens = {}
			for _, d in street():GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Screen" and d:GetAttribute("BoardId") ~= nil then
					table.insert(screens, d)
				end
			end
			t.expect(#screens).toBe(#BOARD_IDS)
			for _, id in BOARD_IDS do
				local n = 0
				for _, s in screens do
					if s:GetAttribute("BoardId") == id then
						n += 1
						t.expect(s:GetAttribute("InteractId")).toBe("leaderboard")
						t.expect(s:HasTag("Interact")).toBeTruthy()
						t.expect(s.CanQuery).toBe(true)
					end
				end
				t.expect(n).toBe(1)
			end
		end)

		t.it("has the Exchange's TickerBand holding a TickerText label", function()
			local bands = tagged(street(), "TickerBand")
			t.expect(#bands).toBeGreaterThanOrEqual(1)
			local labels = 0
			for _, b in bands do
				t.expect(b:IsDescendantOf(street():FindFirstChild("MetropolitanExchange") :: Instance)).toBeTruthy()
				for _, d in b:GetDescendants() do
					if d:IsA("TextLabel") and d.Name == "TickerText" then
						labels += 1
					end
				end
			end
			t.expect(labels).toBeGreaterThanOrEqual(1)
		end)

		t.it("places the street interact points", function()
			local function count(id: string): number
				return #withAttr(street(), "InteractId", id)
			end
			t.expect(count("news_stand")).toBe(1)
			t.expect(count("store_kiosk")).toBe(1)
			t.expect(count("company_directory")).toBe(2)
			t.expect(count("leaderboard")).toBe(10)
			for _, id in { "news_stand", "store_kiosk", "company_directory", "leaderboard" } do
				for _, p in withAttr(street(), "InteractId", id) do
					t.expect((p :: Instance):HasTag("Interact")).toBeTruthy()
					t.expect(World.interactIds[id] ~= nil).toBeTruthy()
				end
			end
		end)

		t.it("dresses the Galleria windows on mannequins", function()
			local galleria = street():FindFirstChild("Venue_galleria", true) :: Instance
			t.expect(galleria ~= nil).toBeTruthy()
			t.expect(#withAttr(galleria, "Mannequin", true)).toBeGreaterThanOrEqual(4)
		end)

		t.it("never plants a free-standing prop inside another solid", function()
			for _, d in street():GetDescendants() do
				if d:IsA("Model") and d:GetAttribute("PropId") and d:GetAttribute("PropMount") ~= "wall" then
					local root = d:FindFirstChild("Root") :: BasePart
					for _, dy in { 0.8, 2.5 } do
						local pos = root.CFrame.Position + Vector3.new(0, dy, 0)
						for _, sol in solids() do
							-- (revolving drums are deliberately filled with an invisible DoorBlocker)
							if not sol.part:IsDescendantOf(d) and sol.part.Name ~= "DoorBlocker" then
								local l = sol.cf:PointToObjectSpace(pos)
								local h = sol.half
								if
									math.abs(l.X) < h.X - 0.05
									and math.abs(l.Y) < h.Y - 0.05
									and math.abs(l.Z) < h.Z - 0.05
								then
									error(
										("%s at %s is inside %s"):format(
											d:GetFullName(),
											tostring(root.Position),
											sol.part:GetFullName()
										)
									)
								end
							end
						end
					end
				end
			end
		end)

		t.it("has the fountain, The Contest, the subway entrance and the newsstand", function()
			for _, propId in
				{
					"fountain",
					"bull_bear_statue",
					"subway_entrance",
					"newsstand",
					"bike_share_dock",
					"phone_booth",
					"scaffold",
					"food_cart",
				}
			do
				t.expect(#withAttr(street(), "PropId", propId)).toBeGreaterThanOrEqual(1)
			end
		end)
	end)

	t.describe("street life and light", function()
		t.it("tags lamps StreetLight and keeps real lights sparing", function()
			local lamps = tagged(street(), "StreetLight")
			t.expect(#lamps).toBeGreaterThan(80)
			local lights = 0
			for _, d in street():GetDescendants() do
				if d:IsA("Light") then
					lights += 1
					local p = d.Parent :: Instance
					t.expect(p:IsA("BasePart")).toBeTruthy()
				end
			end
			t.expect(lights).toBeGreaterThan(20)
			t.expect(lights).toBeLessThan(160)
		end)

		t.it("parks taxis and town cars on the road", function()
			local n = 0
			for _, id in { "taxi", "town_car", "sedan", "city_bus" } do
				n += #withAttr(street(), "PropId", id)
			end
			t.expect(n).toBeGreaterThanOrEqual(10)
			t.expect(#withAttr(street(), "PropId", "taxi")).toBeGreaterThanOrEqual(4)
			t.expect(#withAttr(street(), "PropId", "town_car")).toBeGreaterThanOrEqual(2)
		end)

		t.it("closes the district with invisible boundary walls", function()
			local walls = {}
			for _, d in street():GetDescendants() do
				if d:IsA("BasePart") and d.Name == "InvisibleWall" then
					table.insert(walls, d)
				end
			end
			t.expect(#walls).toBe(4)
			for _, w in walls do
				t.expect(w.CanCollide).toBe(true)
				t.expect(w.Transparency).toBe(1)
			end
		end)
	end)
end
