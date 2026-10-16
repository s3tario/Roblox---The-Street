local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Config.Catalog)
local Wardrobe = require(Shared.Assets.Wardrobe)
local NpcRig = require(Shared.Assets.Npc.Rig)
local Fit = require(Shared.Assets.Wardrobe.Fit)

local MAX_PARTS = 120

local function layers(model: Instance): { BasePart }
	local out = {}
	local folder = model:FindFirstChild(Wardrobe.FOLDER)
	if folder then
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function corners(cf: CFrame, size: Vector3): { Vector3 }
	local out = {}
	local h = size / 2
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(out, (cf * CFrame.new(h.X * x, h.Y * y, h.Z * z)).Position)
			end
		end
	end
	return out
end

-- Gap between a layer's bounding box (in its body part's space) and the body part's box (0 = touching).
local function gapTo(body: BasePart, part: BasePart): number
	local rel = body.CFrame:Inverse() * part.CFrame
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, p in corners(rel, part.Size) do
		mn = mn:Min(p)
		mx = mx:Max(p)
	end
	local h = body.Size / 2
	local dx = math.max(0, mn.X - h.X, -h.X - mx.X)
	local dy = math.max(0, mn.Y - h.Y, -h.Y - mx.Y)
	local dz = math.max(0, mn.Z - h.Z, -h.Z - mx.Z)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function worldBox(part: BasePart): (Vector3, Vector3)
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, p in corners(part.CFrame, part.Size) do
		mn = mn:Min(p)
		mx = mx:Max(p)
	end
	return mn, mx
end

-- Every layer is within `limit` of its body part, or (for hanging pieces like a briefcase) connected
-- through touching layer parts to one that is.
local function checkFit(model: Model, limit: number, label: string)
	local parts = Wardrobe.bodyParts(model)
	local list = layers(model)
	local near: { [BasePart]: boolean } = {}
	local boxes = {}
	for _, p in list do
		local bodyName = p:GetAttribute(Fit.ATTR_PART)
		local body = parts[bodyName]
		if not body then
			error(("%s: %s has no body part (%s)"):format(label, p.Name, tostring(bodyName)))
		end
		local gap = gapTo(body, p)
		if gap > limit * 2 then
			error(("%s: %s floats %.2f studs from %s"):format(label, p.Name, gap, bodyName))
		end
		if gap <= limit then
			near[p] = true
		end
		local mn, mx = worldBox(p)
		boxes[p] = { mn = mn, mx = mx }
	end
	-- flood from the near parts through touching boxes
	local frontier = {}
	for p in near do
		table.insert(frontier, p)
	end
	while #frontier > 0 do
		local p = table.remove(frontier) :: BasePart
		local a = boxes[p]
		for _, q in list do
			if not near[q] then
				local b = boxes[q]
				local tol = 0.03
				if
					a.mn.X <= b.mx.X + tol
					and b.mn.X <= a.mx.X + tol
					and a.mn.Y <= b.mx.Y + tol
					and b.mn.Y <= a.mx.Y + tol
					and a.mn.Z <= b.mx.Z + tol
					and b.mn.Z <= a.mx.Z + tol
				then
					near[q] = true
					table.insert(frontier, q)
				end
			end
		end
	end
	for _, p in list do
		if not near[p] then
			error(
				("%s: %s is not attached to anything near %s"):format(
					label,
					p.Name,
					tostring(p:GetAttribute(Fit.ATTR_PART))
				)
			)
		end
	end
end

local function expectName(p: BasePart, label: string)
	if not string.find(p.Name, "_") then
		error(label .. ": layer part name should be <slot>_<Piece>, got " .. p.Name)
	end
end

local function checkLayerFlags(model: Model, anchored: boolean, label: string)
	local parts = Wardrobe.bodyParts(model)
	for _, p in layers(model) do
		if not p.Massless or p.CanCollide or p.CanQuery or p.CanTouch then
			error(label .. ": " .. p.Name .. " must be massless and non-colliding")
		end
		expectName(p, label)
		local weld = p:FindFirstChildOfClass("WeldConstraint")
		if anchored then
			if not p.Anchored or weld ~= nil then
				error(label .. ": " .. p.Name .. " should be anchored without a weld")
			end
		else
			if p.Anchored or weld == nil then
				error(label .. ": " .. p.Name .. " should be welded")
			end
			local w = weld :: WeldConstraint
			if w.Part0 ~= parts[p:GetAttribute(Fit.ATTR_PART)] or w.Part1 ~= p then
				error(label .. ": " .. p.Name .. " is welded to the wrong part")
			end
		end
	end
end

-- The heaviest item per slot (most layer parts when worn alone), for worst-case outfits.
local heaviest: { [string]: string } = {}
local function computeHeaviest()
	if next(heaviest) then
		return
	end
	local best: { [string]: number } = {}
	for id, item in Catalog.items do
		if not item.hidden then
			local base = NpcRig.build({ equipped = { [item.slot] = id }, hairStyle = "none", strict = true })
			local n = #layers(base)
			if n > (best[item.slot] or -1) then
				best[item.slot] = n
				heaviest[item.slot] = id
			end
		end
	end
end

-- A complete outfit with every slot filled, wearing `id` in its own slot.
local FULL = {
	top = "oxford_white",
	outer = "suit_navy_3p",
	bottom = "suit_navy_trousers",
	shoes = "oxford_black",
	neck = "tie_regimental",
	wrist = "watch_halden_chrono",
	eyes = "glasses_round_wire",
	head = "fedora_charcoal",
	bag = "briefcase_leather",
}

local function outfitWith(id: string): { [string]: string }
	local item = Catalog.get(id) :: Catalog.Item
	local eq = table.clone(FULL)
	eq[item.slot] = id
	return eq
end

return function(t)
	t.describe("Wardrobe.apply", function()
		t.it("builds every catalogue item alone without errors, fitted to the body", function()
			for id, item in Catalog.items do
				local rig = NpcRig.build({ equipped = { [item.slot] = id }, hairStyle = "none", strict = true })
				local result = Wardrobe.apply(rig, { [item.slot] = id }, { anchored = true, strict = true })
				t.expect(result.ok).toBeTruthy()
				if result.items[item.slot] ~= id then
					error(id .. " was not worn")
				end
				t.expect(#result.failed).toBe(0)
				t.expect(result.count).toBeGreaterThan(0)
				checkFit(rig, 0.6, id)
				checkLayerFlags(rig, true, id)
			end
		end)

		t.it("builds every item inside a full outfit (every slot filled), welded", function()
			for id in Catalog.items do
				local eq = outfitWith(id)
				local rig = NpcRig.build({ equipped = eq, hairStyle = "short", anchored = false, strict = true })
				local folder = rig:FindFirstChild(Wardrobe.FOLDER)
				t.expect(folder ~= nil).toBeTruthy()
				local worn = 0
				for _ in eq do
					worn += 1
				end
				local result = Wardrobe.apply(rig, eq, { anchored = false, strict = true })
				local got = 0
				for _ in result.items do
					got += 1
				end
				t.expect(got).toBe(worn)
				checkFit(rig, 0.6, "full+" .. id)
				checkLayerFlags(rig, false, "full+" .. id)
				if result.count > MAX_PARTS then
					error(("full outfit with %s uses %d parts"):format(id, result.count))
				end
			end
		end)

		t.it("keeps the heaviest possible outfit and every NPC preset within the part budget", function()
			computeHeaviest()
			local rig = NpcRig.build({ equipped = heaviest, hairStyle = "curly", strict = true, glint = true })
			local n = #layers(rig)
			t.expect(n).toBeLessThanOrEqual(MAX_PARTS)
			checkFit(rig, 0.6, "heaviest")
			for preset in Catalog.presets do
				local npc = NpcRig.build({ preset = preset, strict = true })
				t.expect(#layers(npc)).toBeLessThanOrEqual(MAX_PARTS)
			end
		end)

		t.it("recolours the body: jacket on torso and arms, trousers on legs, shoes on feet, skin on hands", function()
			local skin = Color3.fromRGB(141, 90, 58)
			local rig = NpcRig.build({ skin = skin, hairStyle = "none", equipped = FULL, strict = true })
			local parts = Wardrobe.bodyParts(rig)
			local jacket = Fit.colorsOf(Catalog.get("suit_navy_3p")).primary
			local trousers = Fit.colorsOf(Catalog.get("suit_navy_trousers")).primary
			local shoes = Fit.colorsOf(Catalog.get("oxford_black")).primary
			for _, name in { "UpperTorso", "LeftUpperArm", "RightLowerArm" } do
				t.expect(parts[name].Color).toEqual(jacket)
			end
			for _, name in { "LowerTorso", "LeftUpperLeg", "RightLowerLeg" } do
				t.expect(parts[name].Color).toEqual(trousers)
			end
			t.expect(parts.LeftFoot.Color).toEqual(shoes)
			t.expect(parts.LeftHand.Color).toEqual(skin)
			t.expect(parts.RightHand.Color).toEqual(skin)
			t.expect(parts.Head.Color).toEqual(skin)
		end)

		t.it("fills required slots with plain base pieces and ignores bad entries", function()
			local rig = NpcRig.build({ hairStyle = "none", equipped = {}, strict = true })
			local result = Wardrobe.apply(rig, { top = "jeans_indigo", hat = "beanie_charcoal", neck = "nope" }, {
				strict = true,
				anchored = true,
			})
			t.expect(result.items.top).toBe("base_tee")
			t.expect(result.items.bottom).toBe("base_trousers")
			t.expect(result.items.shoes).toBe("base_shoes")
			t.expect(result.items.neck).toBeNil()
			local bare = Wardrobe.apply(rig, {}, { fallbacks = false, anchored = true })
			t.expect(bare.count).toBe(0)
			t.expect(next(bare.items)).toBeNil()
		end)

		t.it("is idempotent: applying again replaces the old look", function()
			local rig = NpcRig.build({ preset = "md", strict = true })
			local first = #layers(rig)
			Wardrobe.apply(rig, Catalog.presets.md.equipped, { anchored = true })
			Wardrobe.apply(rig, Catalog.presets.md.equipped, { anchored = true })
			local folders = 0
			for _, c in rig:GetChildren() do
				if c.Name == Wardrobe.FOLDER then
					folders += 1
				end
			end
			t.expect(folders).toBe(1)
			t.expect(#layers(rig)).toBe(first)
			t.expect(Wardrobe.appliedSignature(rig)).toContain("wrist=watch_astra_moonphase")
		end)

		t.it("fits scaled and real-R15-proportioned bodies", function()
			local realR15 = {
				Head = Vector3.new(1.2, 1.2, 1.2),
				UpperArm = Vector3.new(1, 1.169, 1),
				LowerArm = Vector3.new(1, 1.052, 1),
				Hand = Vector3.new(1, 0.3, 1),
				UpperLeg = Vector3.new(1, 1.217, 1),
				LowerLeg = Vector3.new(1, 1.193, 1),
				Foot = Vector3.new(1, 0.3, 1),
			}
			local cases = {
				{ label = "scale 0.8", opts = { scale = 0.8 }, limit = 0.6 },
				{ label = "scale 1.25", opts = { scale = 1.25 }, limit = 0.75 },
				{ label = "real R15", opts = { dims = realR15 }, limit = 0.6 },
			}
			for _, case in cases do
				for id, item in Catalog.items do
					local o = table.clone(case.opts) :: any
					o.equipped = outfitWith(id)
					o.hairStyle = "none"
					o.strict = true
					local rig = NpcRig.build(o)
					checkFit(rig, case.limit, case.label .. " " .. id .. " (" .. item.slot .. ")")
				end
			end
		end)
	end)

	t.describe("Wardrobe.clear", function()
		t.it("restores every original colour and material and removes all layers", function()
			local model = Instance.new("Model")
			local originals = {}
			for i, name in Fit.BODY do
				local p = Instance.new("Part")
				p.Name = name
				p.Size = if name == "UpperTorso"
					then Vector3.new(2, 1.6, 1)
					elseif name == "LowerTorso" then Vector3.new(2, 0.4, 1)
					elseif name == "Head" then Vector3.new(1.2, 1.2, 1.2)
					else Vector3.new(1, 1, 1)
				p.CFrame = CFrame.new(0, i * 0.5, 0)
				p.Color = Color3.fromRGB(10 * i, 200 - 5 * i, 90)
				p.Material = if i % 2 == 0 then Enum.Material.Plastic else Enum.Material.Granite
				p.Parent = model
				originals[name] = { color = p.Color, material = p.Material }
			end
			local result = Wardrobe.apply(model, FULL, { strict = true })
			t.expect(result.ok).toBeTruthy()
			t.expect(Wardrobe.isApplied(model)).toBeTruthy()
			t.expect((model:FindFirstChild("UpperTorso") :: BasePart).Color == originals.UpperTorso.color).toBeFalsy()
			Wardrobe.clear(model)
			t.expect(Wardrobe.isApplied(model)).toBeFalsy()
			t.expect(model:FindFirstChild(Wardrobe.FOLDER)).toBeNil()
			for name, o in originals do
				local p = model:FindFirstChild(name) :: BasePart
				t.expect(p.Color).toEqual(o.color)
				t.expect(p.Material).toBe(o.material)
				t.expect(p:GetAttribute(Fit.ATTR_COLOR)).toBeNil()
				t.expect(p:GetAttribute(Fit.ATTR_MATERIAL)).toBeNil()
			end
			-- clear on a clean model, and apply/clear on a non-R15 model, are harmless
			Wardrobe.clear(model)
			local empty = Instance.new("Model")
			t.expect(Wardrobe.apply(empty, FULL).ok).toBeFalsy()
			Wardrobe.clear(empty)
		end)

		t.it("restores the skin on an NpcRig", function()
			local skin = Color3.fromRGB(230, 185, 143)
			local rig = NpcRig.build({ preset = "trader", skin = skin, strict = true })
			Wardrobe.clear(rig)
			for name, p in Wardrobe.bodyParts(rig) do
				if p.Color ~= skin then
					error(name .. " was not restored")
				end
			end
			t.expect(#layers(rig)).toBe(0)
			t.expect(rig:FindFirstChild("Hair") ~= nil).toBeTruthy() -- hair isn't clothing
		end)
	end)
end
