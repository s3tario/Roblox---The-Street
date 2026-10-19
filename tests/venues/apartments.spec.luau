-- The Ashford Residences (src/world/Apartments) under Lune: exactly 24 apartments (UnitSlot 1..24, tag UnitSlot,
-- UnitKind "apartment"), 8 per floor on three floors; every unit carries its nameplate, home panel (housing_panel,
-- Context "apartment"), closet mirror (wardrobe), home-office terminal, theme surfaces and 6-8 decor slots with
-- unique ids and valid slot kinds; HousingService's own marker reader finds them all in order; no unit's prompts
-- reach into another unit or the corridor; stairs join the floors with headroom on every step; every unit doorway
-- and corridor is walkable.

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Decor = require(Shared.Config.Decor)
local Builders = game:GetService("ServerStorage").WorldBuilders
local Apartments = require(Builders.Apartments)
local HousingMarkers = require(game:GetService("ServerScriptService").Server.Services.HousingService.Markers)

local Plan = Apartments.Plan
local PROMPT_RANGE = 10 -- every interact owner's ProximityPrompt MaxActivationDistance

local cached: Model? = nil
local function building(): Model
	if not cached then
		cached = Apartments.build(Instance.new("Folder"))
	end
	return cached :: Model
end

local function units(): { Model }
	local out = {}
	for _, d in building():GetDescendants() do
		if d:IsA("Model") and d:HasTag("UnitSlot") then
			table.insert(out, d)
		end
	end
	table.sort(out, function(a, b)
		return (a:GetAttribute("UnitSlot") :: number) < (b:GetAttribute("UnitSlot") :: number)
	end)
	return out
end

local function origin(): Vector3
	return World.slotOrigin(World.interiors.apartments.slot)
end

type Box = { cf: CFrame, half: Vector3, part: BasePart }
local solidCache: { Box }? = nil
local function solids(): { Box }
	if solidCache then
		return solidCache
	end
	local out: { Box } = {}
	for _, d in building():GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			table.insert(out, { cf = d.CFrame, half = d.Size / 2, part = d })
		end
	end
	solidCache = out
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

local function groundUnder(root: Vector3): boolean
	local d = 2.5
	while d <= 4.5 do
		if solidAt(root - Vector3.new(0, d, 0)) then
			return true
		end
		d += 0.25
	end
	return false
end

local function standable(root: Vector3, what: string)
	local ok, hit = bodyClear(root)
	if not ok then
		error(what .. " is blocked by " .. (hit :: BasePart):GetFullName())
	end
	if not groundUnder(root) then
		error(what .. " has no floor under it at " .. tostring(root))
	end
end

-- Distance from a world point to where a character's root can be inside a unit (ProximityPrompt range is measured
-- from the HumanoidRootPart): a body's half width (1 stud) in from the walls, from standing height (2.5) up to the
-- top of a jump (10) above the unit's floor. Unit-local: ux across, ud depth from the corridor wall.
local ROOT_LO, ROOT_HI, BODY = 2.5, 10, 1
local function distanceToUnit(spot: any, p: Vector3): number
	local l = (CFrame.new(origin()) * spot.frame):PointToObjectSpace(p)
	local ux, uy, ud = l.X, l.Y, -l.Z
	local dx = math.max(0, math.abs(ux) - (Plan.HALF_W - BODY))
	local dy = math.max(0, ROOT_LO - uy, uy - ROOT_HI)
	local dd = math.max(0, BODY - ud, ud - (Plan.DEPTH - BODY))
	return math.sqrt(dx * dx + dy * dy + dd * dd)
end

---------------------------------------------------------------------------------------------------
return function(t)
	t.describe("the 24 apartments", function()
		t.it("has exactly 24 UnitSlot apartments numbered 1..24, eight per floor", function()
			local list = units()
			t.expect(#list).toBe(24)
			t.expect(World.housing.apartment.count).toBe(24)
			local perFloor: { [number]: number } = {}
			for i, u in list do
				t.expect(u:GetAttribute("UnitSlot")).toBe(i)
				t.expect(u:GetAttribute("UnitKind")).toBe("apartment")
				t.expect(u.PrimaryPart ~= nil).toBeTruthy()
				local f = u:GetAttribute("Floor") :: number
				perFloor[f] = (perFloor[f] or 0) + 1
			end
			for f = 1, Plan.LEVELS do
				t.expect(perFloor[f]).toBe(8)
			end
			t.expect(#Plan.units()).toBe(24)
		end)

		t.it("gives every unit its nameplate, home panel, closet mirror, terminal and theme surfaces", function()
			for _, u in units() do
				local n = u:GetAttribute("UnitSlot") :: number
				local name = u:GetFullName()
				local plates, panels, mirrors, terminals, walls, floors = 0, 0, 0, 0, 0, 0
				for _, d in u:GetDescendants() do
					if d.Name == "Nameplate" or d:HasTag("Nameplate") then
						plates += 1
						local label = d:FindFirstChildWhichIsA("TextLabel", true)
						t.expect(label ~= nil).toBeTruthy()
						t.expect(string.find((label :: TextLabel).Text, tostring(n), 1, true) ~= nil).toBeTruthy()
					end
					local iid = d:GetAttribute("InteractId")
					if iid == "housing_panel" then
						panels += 1
						t.expect(d:GetAttribute("Context")).toBe("apartment")
					elseif iid == "wardrobe" then
						mirrors += 1
					elseif iid == "terminal" then
						terminals += 1
					end
					if d:HasTag("ThemeWall") then
						walls += 1
					end
					if d:HasTag("ThemeFloor") then
						floors += 1
					end
				end
				if plates ~= 1 or panels ~= 1 or mirrors ~= 1 or terminals ~= 1 then
					error(
						("%s: %d nameplates, %d panels, %d mirrors, %d terminals"):format(
							name,
							plates,
							panels,
							mirrors,
							terminals
						)
					)
				end
				t.expect(walls).toBeGreaterThanOrEqual(1)
				t.expect(floors).toBeGreaterThanOrEqual(1)
			end
		end)

		t.it("gives every unit 6-8 decor slots with unique ids and placeable slot kinds", function()
			for _, u in units() do
				local ids: { [string]: boolean } = {}
				local n = 0
				for _, d in u:GetDescendants() do
					if d:HasTag("DecorSlot") then
						n += 1
						local kind = d:GetAttribute("SlotKind")
						local id = d:GetAttribute("SlotId")
						t.expect(type(id)).toBe("string")
						if ids[id] then
							error(u:GetFullName() .. " repeats decor slot id " .. tostring(id))
						end
						ids[id] = true
						t.expect(table.find(Decor.PLACEABLE, kind) ~= nil).toBeTruthy()
						local p = d :: BasePart
						t.expect(p.Transparency).toBe(1)
						t.expect(p.CanCollide).toBe(false)
						t.expect(p.CanQuery).toBe(false)
					end
				end
				t.expect(n).toBeBetween(6, 8)
			end
		end)

		t.it("uses the same slot ids in every unit, so a resident's decor follows them to any unit", function()
			local first: { string }? = nil
			for _, u in units() do
				local list = {}
				for _, d in u:GetDescendants() do
					if d:HasTag("DecorSlot") then
						table.insert(list, d:GetAttribute("SlotId") :: string)
					end
				end
				table.sort(list)
				if first == nil then
					first = list
				else
					t.expect(table.concat(list, ",")).toBe(table.concat(first :: { string }, ","))
				end
			end
			t.expect(#Apartments.SLOTS).toBe(#(first :: { string }))
		end)

		t.it("furnishes every unit: a city-view window, a bed nook, a kitchenette, a sofa and a desk", function()
			for _, u in units() do
				local view = u:FindFirstChild("WindowView", true)
				t.expect(view ~= nil and view:FindFirstChild("View") ~= nil).toBeTruthy()
				for _, child in { "Bed", "Kitchenette", "Sofa", "Desk" } do
					local m = u:FindFirstChild(child, true)
					if not (m and m:IsA("Model")) then
						error(u:GetFullName() .. " has no " .. child)
					end
				end
			end
		end)

		t.it("reads back through HousingService's marker reader in slot order with the explicit ids", function()
			local list = HousingMarkers.containers(building(), "unit")
			t.expect(#list).toBe(24)
			for i, c in list do
				t.expect(c:GetAttribute("UnitSlot")).toBe(i)
				t.expect(HousingMarkers.unitKind(c)).toBe("apartment")
				local slots = HousingMarkers.slots(c)
				t.expect(#slots).toBeBetween(6, 8)
				for _, s in slots do
					t.expect(s.id).toBe(s.part:GetAttribute("SlotId"))
					t.expect(s.kind).toBe(s.part:GetAttribute("SlotKind"))
				end
				t.expect(#HousingMarkers.nameplates(c)).toBe(1)
				local walls, floors = HousingMarkers.themeParts(c)
				t.expect(#walls).toBeGreaterThanOrEqual(1)
				t.expect(#floors).toBeGreaterThanOrEqual(1)
			end
		end)

		t.it("keeps each unit's prompts out of reach of other units and the corridors", function()
			local spots = Plan.units()
			for _, u in units() do
				local n = u:GetAttribute("UnitSlot") :: number
				for _, d in u:GetDescendants() do
					if d:IsA("BasePart") and d:GetAttribute("InteractId") ~= nil then
						local p = d.CFrame.Position
						for _, s in spots do
							if s.n ~= n then
								local dist = distanceToUnit(s, p)
								if dist < PROMPT_RANGE then
									error(("%s's %s is %.1f studs from unit %d"):format(u.Name, d.Name, dist, s.n))
								end
							end
						end
						-- the corridor runs along z = 0 (local); a root there stays a body's width inside |z| <= COR_HALF
						local l = p - origin()
						t.expect(math.abs(l.Z) - (Plan.COR_HALF - BODY)).toBeGreaterThanOrEqual(PROMPT_RANGE)
					end
				end
			end
		end)
	end)

	t.describe("circulation", function()
		t.it("joins the three floors with stairs that have headroom on every step", function()
			local flights = 0
			for _, d in building():GetDescendants() do
				if d:IsA("Model") and d.Name == "Stairs" then
					flights += 1
					local steps = {}
					for _, s in d:GetChildren() do
						if s:IsA("BasePart") then
							table.insert(steps, s)
						end
					end
					t.expect(#steps).toBe(Plan.STEPS)
					table.sort(steps, function(a, b)
						return a.Size.Y < b.Size.Y
					end)
					for i, s in steps do
						local top = s.CFrame.Position.Y + s.Size.Y / 2
						if i > 1 then
							local prev = steps[i - 1]
							local rise = top - (prev.CFrame.Position.Y + prev.Size.Y / 2)
							t.expect(rise).toBeLessThanOrEqual(1.05)
						end
						standable(
							Vector3.new(s.CFrame.Position.X, top + 3, s.CFrame.Position.Z),
							d:GetFullName() .. " step " .. i
						)
					end
				end
			end
			t.expect(flights).toBe(2 * (Plan.LEVELS - 1))
		end)

		t.it("lets residents walk every corridor, landing and unit doorway", function()
			local o = origin()
			for level = 1, Plan.LEVELS do
				local y = (level - 1) * Plan.LEVEL_H + 3
				standable(o + Vector3.new((Plan.NEAR_X0 + Plan.STAIR_X1) / 2, y, 0), "floor " .. level .. " landing")
				for x = Plan.COR_X0 + 2, Plan.COR_X1 - 2, 4 do
					standable(o + Vector3.new(x, y, 0), ("floor %d corridor x=%d"):format(level, x))
				end
			end
			for _, s in Plan.units() do
				local frame = CFrame.new(o) * s.frame
				for _, ud in { -2, 0.75, 3 } do
					for _, dx in { -2, 0, 2 } do
						local p = (frame * CFrame.new(Plan.DOOR_UX + dx, 3, -ud)).Position
						standable(p, ("unit %d doorway (ud %.1f, dx %d)"):format(s.n, ud, dx))
					end
				end
				-- and the living area by the window
				standable((frame * CFrame.new(8.5, 3, -20)).Position, ("unit %d living area"):format(s.n))
			end
			-- the lobby's opening into the stair hall
			standable(
				o + Vector3.new((Plan.NEAR_X0 + Plan.LOBBY_X1) / 2, 3, Plan.STAIR_HALF + 0.5),
				"lobby to stair hall"
			)
		end)
	end)
end
