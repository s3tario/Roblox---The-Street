-- Career Services, the Executive Club and the Skyline Rooftop (src/world/{CareerServices,ExecClub,Rooftop}) under
-- Lune: the pieces each room is for (three consultation desks and a discreet store kiosk; the club's bar, billiards,
-- piano, fireplace, chandeliers, skyline and dressing-room mirror; the rooftop's open-sky mixer lawn under string
-- lights inside a parapet and invisible boundary), and that furniture faces the way people use it.

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Builders = game:GetService("ServerStorage").WorldBuilders

local PROMPT_RANGE = 10

local built: { [string]: Model } = {}
local function venue(module: string): Model
	local m = built[module]
	if not m then
		m = require(Builders:FindFirstChild(module) :: any).build(Instance.new("Folder"))
		built[module] = m
	end
	return m :: Model
end

local function originOf(zone: string): Vector3
	return World.slotOrigin(World.interiors[zone].slot)
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

local function props(root: Instance, id: string): { Model }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("PropId") == id then
			table.insert(out, d)
		end
	end
	return out
end

local function pivot(m: Model): CFrame
	local root = m.PrimaryPart or m:FindFirstChild("Root")
	assert(root and root:IsA("BasePart"), m:GetFullName() .. " has no root part")
	return root.CFrame
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-6 then f.Unit else f
end

type Box = { cf: CFrame, half: Vector3, part: BasePart }
local solidCache: { [string]: { Box } } = {}
local function solids(module: string): { Box }
	local c = solidCache[module]
	if c then
		return c
	end
	local out: { Box } = {}
	for _, d in venue(module):GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			table.insert(out, { cf = d.CFrame, half = d.Size / 2, part = d })
		end
	end
	solidCache[module] = out
	return out
end

local function solidAt(module: string, pos: Vector3): BasePart?
	for _, s in solids(module) do
		local l = s.cf:PointToObjectSpace(pos)
		if math.abs(l.X) < s.half.X - 0.05 and math.abs(l.Y) < s.half.Y - 0.05 and math.abs(l.Z) < s.half.Z - 0.05 then
			return s.part
		end
	end
	return nil
end

local function standable(module: string, root: Vector3, what: string)
	for _, dy in { -2.4, 0, 2 } do
		local hit = solidAt(module, root + Vector3.new(0, dy, 0))
		if hit then
			error(what .. " is blocked by " .. hit:GetFullName())
		end
	end
	local d, ground = 2.5, false
	while d <= 4.5 and not ground do
		ground = solidAt(module, root - Vector3.new(0, d, 0)) ~= nil
		d += 0.25
	end
	if not ground then
		error(what .. " has no floor under it")
	end
end

local function rayHit(module: string, origin: Vector3, dir: Vector3, maxDist: number): number?
	local best: number? = nil
	for _, s in solids(module) do
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

---------------------------------------------------------------------------------------------------
return function(t)
	t.describe("Career Services", function()
		local M = "CareerServices"
		t.it("has three consultation desks whose screens face their guest chairs", function()
			local desks = withAttr(venue(M), "InteractId", "career_services")
			t.expect(#desks).toBe(3)
			local seen: { [number]: boolean } = {}
			local chairs = props(venue(M), "chair_visitor")
			t.expect(#chairs).toBe(6)
			for _, d in desks do
				local screen = d :: BasePart
				local idx = screen:GetAttribute("DeskIndex") :: number
				t.expect(seen[idx] == nil).toBeTruthy()
				seen[idx] = true
				local near = 0
				for _, c in chairs do
					local to = pivot(c).Position - screen.CFrame.Position
					if Vector3.new(to.X, 0, to.Z).Magnitude < 8 then
						near += 1
						t.expect(flat(screen.CFrame.LookVector):Dot(flat(to))).toBeGreaterThan(0.5)
						-- and the chairs face the desk
						t.expect(flat(pivot(c).LookVector):Dot(flat(-to))).toBeGreaterThan(0.5)
					end
				end
				t.expect(near).toBe(2)
				local guest = screen.CFrame.Position + flat(screen.CFrame.LookVector) * 4.5
				local root = Vector3.new(guest.X, originOf("career_services").Y + 3, guest.Z)
				standable(M, root, "desk " .. idx .. " guest spot")
				t.expect((root - screen.CFrame.Position).Magnitude).toBeLessThan(PROMPT_RANGE)
			end
			t.expect(seen[1] and seen[2] and seen[3]).toBeTruthy()
		end)

		t.it("tucks the store kiosk into a corner, its screen turned to the room", function()
			local list = withAttr(venue(M), "InteractId", "store_kiosk")
			t.expect(#list).toBe(1)
			local screen = list[1] :: BasePart
			local o = originOf("career_services")
			local l = screen.CFrame.Position - o
			t.expect(math.abs(l.X)).toBeGreaterThan(30)
			t.expect(math.abs(l.Z)).toBeGreaterThan(20)
			t.expect(flat(screen.CFrame.LookVector):Dot(flat(o - screen.CFrame.Position))).toBeGreaterThan(0.5)
			local front = screen.CFrame.Position + flat(screen.CFrame.LookVector) * 3
			standable(M, Vector3.new(front.X, o.Y + 3, front.Z), "kiosk customer spot")
		end)

		t.it("seats the waiting area and the reading table facing each other", function()
			t.expect(#props(venue(M), "sofa_office")).toBe(2)
			t.expect(#props(venue(M), "water_cooler")).toBe(1)
			t.expect(venue(M):FindFirstChild("NowServing", true) ~= nil).toBeTruthy()
			local library = venue(M):FindFirstChild("Library") :: Instance
			local tableTop = library:FindFirstChild("TableTop", true) :: BasePart
			local n = 0
			for _, c in library:GetDescendants() do
				if c:IsA("Model") and c.Name == "Chair" then
					n += 1
					local seat = c:FindFirstChild("Seat") :: BasePart
					local to = tableTop.CFrame.Position - seat.CFrame.Position
					t.expect(flat(seat.CFrame.LookVector):Dot(flat(to))).toBeGreaterThan(0.5)
				end
			end
			t.expect(n).toBe(4)
		end)
	end)

	t.describe("The Executive Club", function()
		local M = "ExecClub"
		t.it("has the bar, billiards, piano, fireplace, chandeliers and leather lounges", function()
			local m = venue(M)
			t.expect(#props(m, "bar_counter")).toBe(1)
			t.expect(#props(m, "pool_table")).toBe(1)
			t.expect(#props(m, "piano_grand")).toBe(1)
			t.expect(#props(m, "fireplace")).toBe(1)
			t.expect(#props(m, "chandelier")).toBeGreaterThanOrEqual(3)
			t.expect(#props(m, "leather_sofa")).toBeGreaterThanOrEqual(2)
			t.expect(#props(m, "wine_rack")).toBeGreaterThanOrEqual(2)
		end)

		t.it("paints the night skyline behind its window wall", function()
			local sky = venue(M):FindFirstChild("Skyline", true)
			assert(sky and sky:IsA("BasePart"), "no skyline backdrop")
			t.expect(sky:FindFirstChild("Skyline") ~= nil).toBeTruthy()
			local o = originOf("exec_club")
			t.expect(sky.CFrame.Position.Z - o.Z).toBeLessThan(-34)
		end)

		t.it("turns the fireside chairs to the hearth", function()
			local fire = props(venue(M), "fireplace")[1]
			local chairs = props(venue(M), "lounge_chair")
			t.expect(#chairs).toBe(2)
			for _, c in chairs do
				-- angled in toward the hearth: within about 25 degrees of it
				local to = pivot(fire).Position - pivot(c).Position
				t.expect(flat(pivot(c).LookVector):Dot(flat(to))).toBeGreaterThan(0.9)
			end
		end)

		t.it("puts the wardrobe mirror in the members' dressing room, through a walkable doorway", function()
			local list = withAttr(venue(M), "InteractId", "wardrobe")
			t.expect(#list).toBe(1)
			local mirror = list[1] :: BasePart
			local room = venue(M):FindFirstChild("DressingRoom") :: Instance
			t.expect(mirror:IsDescendantOf(room)).toBeTruthy()
			local o = originOf("exec_club")
			-- walk from the lounge through the doorway (x = -29.5, z = 24) to the mirror
			for _, x in { -24, -27, -29.5, -32, -36, -40 } do
				standable(M, o + Vector3.new(x, 3, 24), ("dressing room path x=%d"):format(x))
			end
			local front = mirror.CFrame.Position + flat(mirror.CFrame.LookVector) * 3
			t.expect((Vector3.new(front.X, o.Y + 3, front.Z) - mirror.CFrame.Position).Magnitude)
				.toBeLessThan(PROMPT_RANGE)
		end)
	end)

	t.describe("The Skyline Rooftop", function()
		local M = "Rooftop"
		local function spot(): BasePart
			local list = withAttr(venue(M), "EventSpot", "mixer_area")
			t.expect(#list).toBe(1)
			return list[1] :: BasePart
		end

		t.it("leaves the sky open above the mixer lawn", function()
			local s = spot()
			t.expect(s.Size.X).toBeGreaterThanOrEqual(30)
			t.expect(s.Size.Z).toBeGreaterThanOrEqual(30)
			for _, dx in { -0.4, -0.2, 0, 0.2, 0.4 } do
				for _, dz in { -0.4, -0.2, 0, 0.2, 0.4 } do
					local p = s.CFrame.Position + Vector3.new(dx * s.Size.X, 2, dz * s.Size.Z)
					if rayHit(M, p, Vector3.yAxis, 300) ~= nil then
						error("something solid hangs over the mixer lawn at " .. tostring(p))
					end
					standable(M, p + Vector3.new(0, 1, 0), "mixer lawn")
				end
			end
		end)

		t.it("strings outdoor lights over the deck and keeps its host by the lawn", function()
			local bulbs = 0
			for _, d in venue(M):GetDescendants() do
				if d.Name == "Bulb" and d:HasTag("StreetLight") then
					bulbs += 1
					t.expect((d :: BasePart).Material).toBe(Enum.Material.Neon)
				end
			end
			t.expect(bulbs).toBeGreaterThanOrEqual(60)
			-- the host greets guests between the elevator and the lawn
			local host = withAttr(venue(M), "NpcId", "npc_mixer_host")[1] :: BasePart
			local s = spot()
			local l = s.CFrame:PointToObjectSpace(host.CFrame.Position)
			local dx = math.max(0, math.abs(l.X) - s.Size.X / 2)
			local dz = math.max(0, math.abs(l.Z) - s.Size.Z / 2)
			t.expect(math.sqrt(dx * dx + dz * dz)).toBeLessThan(12)
			local entry = withAttr(venue(M), "AnchorId", "rooftop_entry")[1] :: BasePart
			t.expect((host.CFrame.Position - entry.CFrame.Position).Magnitude).toBeLessThan(22)
		end)

		t.it("rings the deck with a painted skyline and fences it in so nobody falls", function()
			local panels = 0
			for _, d in venue(M):GetDescendants() do
				if d.Name == "SkylinePanel" then
					panels += 1
					t.expect(d:FindFirstChildWhichIsA("SurfaceGui") ~= nil).toBeTruthy()
				end
			end
			t.expect(panels).toBe(16)
			local boundaries = 0
			for _, d in venue(M):GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Boundary" then
					boundaries += 1
					t.expect(d.CanCollide).toBe(true)
					t.expect(d.Transparency).toBe(1)
					t.expect(d.Size.Y).toBeGreaterThan(30)
				end
			end
			t.expect(boundaries).toBe(4)
			-- from the middle of the deck every way out runs into the parapet, glass or boundary
			local c = originOf("rooftop") + Vector3.new(0, 3, 0)
			for i = 0, 23 do
				local a = i / 24 * math.pi * 2
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				for _, dy in { -1.5, 1, 6 } do
					if rayHit(M, c + Vector3.new(0, dy, 0), dir, 120) == nil then
						error("the deck is open toward " .. tostring(dir))
					end
				end
			end
		end)

		t.it("stands guests on the teak decking, not inside it", function()
			local deck: BasePart? = nil
			for _, d in venue(M):GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Decking" then
					deck = d
				end
			end
			assert(deck, "no decking")
			t.expect(deck.CanCollide).toBe(true)
			local top = deck.CFrame.Position.Y + deck.Size.Y / 2
			t.expect(top - originOf("rooftop").Y).toBeGreaterThan(0.1)
			-- the host's floor (and every guest's on the deck) is the decking's top face
			local host = withAttr(venue(M), "NpcId", "npc_mixer_host")[1] :: BasePart
			local p = host.CFrame.Position
			t.expect(solidAt(M, Vector3.new(p.X, top - 0.06, p.Z))).toBe(deck)
			t.expect(solidAt(M, Vector3.new(p.X, top + 0.1, p.Z))).toBeNil()
		end)

		t.it("paints the ring's horizon haze solid where the other venue slots would show through", function()
			-- the other interior slots stand 500+ studs out at about -4..+5 degrees from the deck (camera heights the
			-- zoom allows), which lands between y ~ 3 and ~ 38 on the ring: that band must be opaque paint
			local base = originOf("rooftop").Y
			local panels = 0
			for _, d in venue(M):GetDescendants() do
				if d:IsA("BasePart") and d.Name == "SkylinePanel" then
					panels += 1
					local gui = d:FindFirstChildWhichIsA("SurfaceGui")
					assert(gui, "SkylinePanel without its painting")
					local pps = gui.PixelsPerStud
					local topY = d.CFrame.Position.Y + d.Size.Y / 2 - base
					local solidTop, solidBottom = nil, nil
					for _, f in gui:GetChildren() do
						local g = f:FindFirstChildWhichIsA("UIGradient")
						-- the haze: clear at its top edge, solid from partway down to its foot on the horizon
						local kps = if g then g.Transparency.Keypoints else {}
						if f:IsA("Frame") and g and f.BackgroundTransparency == 0 and kps[1].Value == 1 then
							for _, k in kps do
								if k.Value == 0 and k.Time > 0 and k.Time < 1 then
									solidTop = topY - (f.Position.Y.Offset + k.Time * f.Size.Y.Offset) / pps
									solidBottom = topY - (f.Position.Y.Offset + f.Size.Y.Offset) / pps
									break
								end
							end
						end
					end
					assert(solidTop and solidBottom, d:GetFullName() .. " has no solid horizon haze")
					t.expect(solidTop).toBeGreaterThanOrEqual(38)
					-- it meets the painted city below the horizon, which is opaque down to the panel's foot
					t.expect(solidBottom).toBeLessThanOrEqual(6)
					t.expect(topY - d.Size.Y).toBeLessThan(-15)
				end
			end
			t.expect(panels).toBe(16)
		end)

		t.it("turns the bar's menu board toward guests arriving from the elevator", function()
			local menu = nil
			for _, d in venue(M):GetDescendants() do
				if d.Name == "Menu" and d:IsA("BasePart") then
					menu = d
				end
			end
			assert(menu, "no menu board")
			local entry = withAttr(venue(M), "AnchorId", "rooftop_entry")[1] :: BasePart
			local to = entry.CFrame.Position - menu.CFrame.Position
			t.expect(flat(menu.CFrame.LookVector):Dot(flat(to))).toBeGreaterThan(0.3)
		end)
	end)
end
