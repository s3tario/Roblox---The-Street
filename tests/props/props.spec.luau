-- Props registry: every prop builds under Lune at a rotated, off-origin CFrame, stays inside its part
-- budget and footprint, never dips below the floor, and is deterministic for a given seed.

local Shared = game:GetService("ReplicatedStorage").Shared
local Props = require(Shared.Assets.Props)
local Common = require(Shared.Assets.Props.Common)

local CF = CFrame.new(137.5, 12.25, -81.75) * CFrame.Angles(0, math.rad(37), 0)
local CATEGORIES =
	{ office = true, decor = true, campus = true, street = true, vehicles = true, lux = true, retail = true }
local MOUNTS = { floor = true, desk = true, wall = true, ceiling = true }

-- ids the brief requires (more are welcome)
local REQUIRED = {
	"desk_bullpen",
	"desk_associate",
	"desk_vp",
	"desk_md",
	"desk_trading",
	"chair_task",
	"chair_exec",
	"chair_visitor",
	"monitor_single",
	"monitor_dual",
	"monitor_triple",
	"keyboard_mouse",
	"desk_lamp",
	"filing_cabinet",
	"bookshelf",
	"conference_table",
	"whiteboard",
	"water_cooler",
	"coffee_machine",
	"printer",
	"plant_floor",
	"plant_desk",
	"sofa_office",
	"armchair",
	"coffee_table",
	"rug_office",
	"wall_art",
	"wall_clock",
	"deal_toy",
	"trophy_shelf",
	"ticker_board",
	"glass_partition",
	"reception_desk",
	"elevator_door",
	"security_gate",
	"divider_planter",
	"nameplate",
	"photo_frame",
	"globe",
	"bonsai",
	"stress_ball",
	"coffee_mug",
	"desk_organizer",
	"mini_bull_bear",
	"cactus",
	"book_stack",
	"award_plaque",
	"rug_round",
	"rug_persian",
	"rug_modern",
	"lamp_floor",
	"lamp_arc",
	"art_canvas_large",
	"sculpture_abstract",
	"aquarium",
	"record_player",
	"bar_cart",
	"dumpster",
	"trash_can",
	"chainlink_fence",
	"bench_worn",
	"bus_shelter",
	"street_lamp_sodium",
	"fire_hydrant",
	"newspaper_box",
	"vending_machine",
	"picnic_table",
	"bike_rack",
	"traffic_cone",
	"jersey_barrier",
	"mailbox",
	"cafeteria_table",
	"lecture_desk_row",
	"chalkboard",
	"lockers",
	"bunk_bed",
	"dorm_desk",
	"mini_fridge",
	"poster_wall",
	"pizza_box",
	"laundry_machine",
	"diner_booth",
	"diner_counter_stool",
	"fire_escape",
	"ac_unit",
	"pallet_stack",
	"puddle",
	"taxi",
	"sedan",
	"town_car",
	"city_bus",
	"street_lamp_classic",
	"traffic_light",
	"bench_classic",
	"planter_tree",
	"bollard",
	"flag_pole",
	"newsstand",
	"food_cart",
	"revolving_door",
	"awning",
	"subway_entrance",
	"fountain",
	"bull_bear_statue",
	"phone_booth",
	"bike_share_dock",
	"hydrant_brass",
	"manhole",
	"crosswalk",
	"scaffold",
	"bar_counter",
	"bar_stool",
	"chandelier",
	"leather_sofa",
	"fireplace",
	"wine_rack",
	"pool_table",
	"piano_grand",
	"art_pedestal",
	"lounge_chair",
	"cigar_humidor",
	"velvet_rope",
	"clothing_rack",
	"display_table",
	"mannequin_stand",
	"shoe_wall",
	"watch_case",
	"cash_counter",
	"mirror_full",
	"shopping_bag",
}

local function parts(m: Instance): { BasePart }
	local out = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

-- Fingerprint of a build: part count plus every part's class, colour, material and local position.
local function fingerprint(m: Model, cf: CFrame): string
	local bits = {}
	for _, p in parts(m) do
		local lp = cf:PointToObjectSpace(p.CFrame.Position)
		table.insert(
			bits,
			string.format(
				"%s:%s:%d,%d,%d:%s:%.2f,%.2f,%.2f",
				p.ClassName,
				p.Name,
				math.floor(p.Color.R * 255 + 0.5),
				math.floor(p.Color.G * 255 + 0.5),
				math.floor(p.Color.B * 255 + 0.5),
				p.Material.Name,
				lp.X,
				lp.Y,
				lp.Z
			)
		)
	end
	return #bits .. "|" .. table.concat(bits, ";")
end

-- Local-space snapshot (class, colour, material, position, size) for tolerance comparisons.
local function snapshot(m: Model, cf: CFrame): { { any } }
	local out = {}
	for _, p in parts(m) do
		local l = cf:ToObjectSpace(p.CFrame)
		table.insert(out, { p.ClassName, p.Color, p.Material, l.Position, l.LookVector, l.UpVector, p.Size })
	end
	return out
end

local function sameSnapshot(a: { { any } }, b: { { any } }): boolean
	if #a ~= #b then
		return false
	end
	for i, x in a do
		local y = b[i]
		if x[1] ~= y[1] or x[2] ~= y[2] or x[3] ~= y[3] then
			return false
		end
		for k = 4, 7 do
			if (x[k] - y[k]).Magnitude > 1e-3 then
				return false
			end
		end
	end
	return true
end

local function checkModel(t: any, id: string, m: Model, cf: CFrame, maxParts: number, label: string?)
	local name = label or id
	t.expect(m:IsA("Model")).toBe(true)
	local root = m.PrimaryPart
	if root == nil or root.Name ~= "Root" then
		error(name .. ": PrimaryPart must be the Root part")
	end
	if root.Transparency ~= 1 or root.CanCollide or root.CanQuery or root.CanTouch then
		error(name .. ": Root must be invisible and non-colliding")
	end
	if (root.CFrame.Position - cf.Position).Magnitude > 1e-3 then
		error(name .. ": Root must sit at the placement CFrame")
	end
	if m:GetAttribute("PropId") ~= id then
		error(name .. ": missing PropId attribute")
	end
	local list = parts(m)
	if #list > maxParts then
		error(string.format("%s: %d parts > maxParts %d", name, #list, maxParts))
	end
	if #list < 2 then
		error(name .. ": builds no geometry")
	end
	for _, p in list do
		if not p.Anchored then
			error(name .. ": unanchored part " .. p.Name)
		end
		local s = p.Size
		if not (s.X > 0 and s.Y > 0 and s.Z > 0) or s.X ~= s.X or s.Y ~= s.Y or s.Z ~= s.Z then
			error(name .. ": bad size on " .. p.Name .. " " .. tostring(s))
		end
		local pos = p.CFrame.Position
		if pos.X ~= pos.X or pos.Y ~= pos.Y or pos.Z ~= pos.Z then
			error(name .. ": NaN position on " .. p.Name)
		end
	end
	local mn = Common.localBounds(m, cf, root)
	if mn.Y < -0.1 then
		error(string.format("%s: lowest corner %.3f below the floor", name, mn.Y))
	end
	local use = root:FindFirstChild("Use")
	if use == nil or not use:IsA("Attachment") then
		error(name .. ": missing Use attachment")
	end
end

-- Footprint fit: each extent within ±25% (plus a small absolute slack for tiny props) and placed as the
-- mount convention says.
local function checkFootprint(id: string, info: any, m: Model, cf: CFrame)
	local mn, mx = Common.localBounds(m, cf, m.PrimaryPart)
	local size = mx - mn
	local fp: Vector3 = info.footprint
	local function within(axis: string, got: number, want: number)
		local slack = 0.25 * want + 0.15
		if math.abs(got - want) > slack then
			error(string.format("%s: %s extent %.2f vs footprint %.2f (±25%%)", id, axis, got, want))
		end
	end
	within("X", size.X, fp.X)
	within("Y", mx.Y, fp.Y)
	within("Z", size.Z, fp.Z)
	local off: Vector3 = info.offset or Vector3.zero
	local cx = (mn.X + mx.X) / 2 - off.X
	if math.abs(cx) > 0.25 * fp.X + 0.15 then
		error(string.format("%s: not centred in X (%.2f)", id, cx))
	end
	if info.mount == "wall" then
		if mx.Z > 0.15 then
			error(string.format("%s: wall prop pokes %.2f behind the wall", id, mx.Z))
		end
	else
		local cz = (mn.Z + mx.Z) / 2 - off.Z
		if math.abs(cz) > 0.25 * fp.Z + 0.15 then
			error(string.format("%s: not centred in Z (%.2f)", id, cz))
		end
	end
end

return function(t)
	t.describe("Props registry", function()
		local list = Props.list()

		t.it("lists well-formed entries with unique ids", function()
			t.expect(#list).toBeGreaterThanOrEqual(#REQUIRED)
			local seen = {}
			for _, info in list do
				t.expect(type(info.id)).toBe("string")
				t.expect(seen[info.id]).toBeNil()
				seen[info.id] = true
				if not CATEGORIES[info.category] then
					error(info.id .. ": unknown category " .. tostring(info.category))
				end
				if not MOUNTS[info.mount] then
					error(info.id .. ": unknown mount " .. tostring(info.mount))
				end
				t.expect(typeof(info.footprint)).toBe("Vector3")
				t.expect(info.maxParts).toBeGreaterThan(1)
				t.expect(type(info.tags)).toBe("table")
				t.expect(#info.tags).toBeGreaterThan(0)
				t.expect(Props.has(info.id)).toBe(true)
				t.expect(Props.get(info.id) ~= nil).toBe(true)
			end
		end)

		t.it("covers every required id", function()
			local missing = {}
			for _, id in REQUIRED do
				if not Props.has(id) then
					table.insert(missing, id)
				end
			end
			if #missing > 0 then
				error("missing props: " .. table.concat(missing, ", "))
			end
		end)

		t.it("rejects unknown ids cleanly", function()
			t.expect(Props.has("no_such_prop")).toBe(false)
			t.expect(Props.has(nil)).toBe(false)
			t.expect(function()
				Props.build("no_such_prop", nil, CF)
			end).toThrow("unknown prop id")
			local m, err = Props.tryBuild("no_such_prop", nil, CF)
			t.expect(m).toBeNil()
			t.expect(type(err)).toBe("string")
		end)

		t.it("ids(category) filters by category", function()
			local office = Props.ids("office")
			t.expect(#office).toBeGreaterThan(30)
			for _, id in office do
				t.expect((Props.get(id) :: any).category).toBe("office")
			end
			t.expect(#Props.ids()).toBe(#list)
		end)
	end)

	t.describe("every prop", function()
		for _, info in Props.list() do
			t.it(info.id .. " builds within budget, anchored, above the floor and inside its footprint", function()
				local parent = Instance.new("Folder")
				local m = Props.build(info.id, parent, CF, { seed = 7 })
				t.expect(m.Parent).toBe(parent)
				checkModel(t, info.id, m, CF, info.maxParts)
				checkFootprint(info.id, info, m, CF)
				t.expect(m:GetAttribute("PropCategory")).toBe(info.category)
				t.expect(m:GetAttribute("PropMount")).toBe(info.mount)
				t.expect(m:HasTag("Prop")).toBe(true)
			end)
		end
	end)

	t.describe("options", function()
		t.it("the largest scaled builds stay inside maxParts", function()
			for _, info in Props.list() do
				if info.maxOpts then
					local opts = table.clone(info.maxOpts)
					opts.seed = 3
					local m = Props.build(info.id, nil, CF, opts)
					checkModel(t, info.id, m, CF, info.maxParts, info.id .. " (max)")
				end
			end
		end)

		t.it("many seeds, tiers, variants and lit states build cleanly", function()
			local variants: { any } = { 1, 2, 3, 4, 5, 6, 7, 8, "hotdog", "coffee", "pretzel", 0, 99, "bogus" }
			for _, info in Props.list() do
				for i = 1, 6 do
					local opts = {
						seed = i * 101,
						tier = (i - 1) % 4 + 1,
						variant = variants[(i * 3) % #variants + 1],
						lit = i % 2 == 0,
						seat = i == 3,
					}
					local m = Props.build(info.id, nil, CF, opts)
					checkModel(t, info.id, m, CF, info.maxParts, info.id .. " (opts " .. i .. ")")
				end
			end
		end)

		t.it("garbage options never crash a build", function()
			local junk = {
				color = "not a colour",
				accent = 12,
				variant = {},
				seed = 0 / 0,
				lit = "yes",
				text = string.rep("X", 500),
				tier = math.huge,
				seats = -4,
				count = 1e9,
				length = -1,
				floors = 0 / 0,
				width = "wide",
				colors = { 1, "#ZZZZZZ", Color3.new(1, 0, 0) },
				screens = 5,
			}
			for _, info in Props.list() do
				local ok, err = pcall(Props.build, info.id, nil, CF, junk)
				if not ok then
					error(info.id .. " crashed on junk options: " .. tostring(err))
				end
				checkModel(t, info.id, err :: any, CF, info.maxParts, info.id .. " (junk)")
			end
		end)

		t.it("colour overrides apply", function()
			local red = Color3.fromRGB(200, 10, 10)
			local found = false
			for _, p in parts(Props.build("desk_bullpen", nil, CF, { color = red })) do
				if p.Color == red then
					found = true
				end
			end
			t.expect(found).toBe(true)
		end)

		t.it("text options reach the SurfaceGuis", function()
			local function hasText(m: Instance, needle: string): boolean
				for _, d in m:GetDescendants() do
					if d:IsA("TextLabel") and string.find(d.Text, needle, 1, true) then
						return true
					end
				end
				return false
			end
			t.expect(hasText(Props.build("nameplate", nil, CF, { text = "A. Rivera" }), "A. Rivera")).toBe(true)
			t.expect(hasText(Props.build("deal_toy", nil, CF, { text = "PROJECT ZEPHYR" }), "PROJECT ZEPHYR"))
				.toBe(true)
		end)

		t.it("seat = true creates real Seats on chairs", function()
			local seats = 0
			for _, d in Props.build("chair_task", nil, CF, { seat = true }):GetDescendants() do
				if d:IsA("Seat") then
					seats += 1
				end
			end
			t.expect(seats).toBeGreaterThan(0)
		end)
	end)

	t.describe("determinism", function()
		t.it("the same seed gives the same parts and colours; placement seeds are stable", function()
			for _, info in Props.list() do
				local a = fingerprint(Props.build(info.id, nil, CF, { seed = 42 }), CF)
				local b = fingerprint(Props.build(info.id, nil, CF, { seed = 42 }), CF)
				if a ~= b then
					error(info.id .. ": same seed built differently")
				end
				local c = fingerprint(Props.build(info.id, nil, CF), CF)
				local d = fingerprint(Props.build(info.id, nil, CF), CF)
				if c ~= d then
					error(info.id .. ": same placement built differently")
				end
			end
		end)

		t.it("gritty campus props vary with the seed", function()
			local varied = 0
			for _, id in Props.ids("campus") do
				local a = fingerprint(Props.build(id, nil, CF, { seed = 1 }), CF)
				for s = 2, 6 do
					if fingerprint(Props.build(id, nil, CF, { seed = s }), CF) ~= a then
						varied += 1
						break
					end
				end
			end
			t.expect(varied).toBeGreaterThan(#Props.ids("campus") * 0.6)
		end)

		t.it("rotating the placement rotates the prop rigidly", function()
			local cf2 = CFrame.new(-20, 3, 44) * CFrame.Angles(0, math.rad(-120), 0)
			for _, id in { "desk_md", "taxi", "bench_classic", "chandelier", "wall_art" } do
				local a = snapshot(Props.build(id, nil, CF, { seed = 5 }), CF)
				local b = snapshot(Props.build(id, nil, cf2, { seed = 5 }), cf2)
				if not sameSnapshot(a, b) then
					error(id .. ": rotated placement built a different prop")
				end
			end
		end)
	end)
end
