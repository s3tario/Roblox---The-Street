-- The Galleria (src/world/Galleria) under Lune: four boutiques, one per Config/Shop shop (tailor, watch, shoes,
-- decor), each with exactly one `shop` interact carrying its Shop id, staffed by its NPC within prompt range and
-- reachable by a customer; Hartwell's dressed mannequins (NpcRig + Wardrobe, anchored and passive), racks and fitting
-- mirror (the only wardrobe interact); Vanta's watch cases, Strider's shoe walls, Atelier Maison's three vignettes;
-- the glass barrel vault under its painted sky; and walkable shopfront doorways and promenade.

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Shop = require(Shared.Config.Shop)
local Builders = game:GetService("ServerStorage").WorldBuilders
local Galleria = require(Builders.Galleria)

local Plan = Galleria.Plan
local PROMPT_RANGE = 10

local SHOP_NPC = {
	tailor = "npc_tailor",
	watch = "npc_watchmaker",
	shoes = "npc_shoe_clerk",
	decor = "npc_decorator",
}

local cached: Model? = nil
local function galleria(): Model
	if not cached then
		cached = Galleria.build(Instance.new("Folder"))
	end
	return cached :: Model
end

local function origin(): Vector3
	return World.slotOrigin(World.interiors.galleria.slot)
end

local function boutique(shopId: string): Model
	local folder = galleria():FindFirstChild("Boutiques")
	assert(folder, "no Boutiques folder")
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("Shop") == shopId then
			return m
		end
	end
	error("no boutique for " .. shopId)
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

local function boutiqueOf(inst: Instance): Instance?
	local node = inst.Parent
	while node do
		if node:GetAttribute("Boutique") then
			return node
		end
		node = node.Parent
	end
	return nil
end

type Box = { cf: CFrame, half: Vector3, part: BasePart }
local solidCache: { Box }? = nil
local function solids(): { Box }
	if solidCache then
		return solidCache
	end
	local out: { Box } = {}
	for _, d in galleria():GetDescendants() do
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

local function standable(root: Vector3, what: string)
	for _, dy in { -2.4, 0, 2 } do
		local hit = solidAt(root + Vector3.new(0, dy, 0))
		if hit then
			error(what .. " is blocked by " .. hit:GetFullName())
		end
	end
	local d, ground = 2.5, false
	while d <= 4.5 and not ground do
		ground = solidAt(root - Vector3.new(0, d, 0)) ~= nil
		d += 0.25
	end
	if not ground then
		error(what .. " has no floor under it")
	end
end

---------------------------------------------------------------------------------------------------
return function(t)
	t.describe("boutiques", function()
		t.it("has four boutiques, one for each Galleria shop in Config/Shop", function()
			local seen: { [string]: boolean } = {}
			for _, m in (galleria():FindFirstChild("Boutiques") :: Instance):GetChildren() do
				local id = m:GetAttribute("Shop")
				t.expect(type(id)).toBe("string")
				t.expect(seen[id] == nil).toBeTruthy()
				seen[id] = true
				t.expect(Shop.get(id) ~= nil).toBeTruthy()
			end
			for id in SHOP_NPC do
				t.expect(seen[id]).toBe(true)
			end
			t.expect(#Plan.shops).toBe(4)
		end)

		t.it("puts exactly one shop interact in each boutique, carrying that boutique's Shop id", function()
			local list = withAttr(galleria(), "InteractId", "shop")
			t.expect(#list).toBe(4)
			local seen: { [string]: number } = {}
			for _, p in list do
				local id = p:GetAttribute("Shop") :: string
				seen[id] = (seen[id] or 0) + 1
				local b = boutiqueOf(p)
				t.expect(b ~= nil).toBeTruthy()
				t.expect((b :: Instance):GetAttribute("Shop")).toBe(id)
				t.expect(p:HasTag("Interact")).toBeTruthy()
				t.expect((p :: BasePart).CanQuery).toBe(true)
			end
			for id in SHOP_NPC do
				t.expect(seen[id]).toBe(1)
			end
		end)

		t.it("staffs every counter: its NPC within prompt range and a customer spot in front of the card", function()
			for shopId, npcId in SHOP_NPC do
				local card = nil
				for _, p in withAttr(galleria(), "InteractId", "shop") do
					if p:GetAttribute("Shop") == shopId then
						card = p :: BasePart
					end
				end
				assert(card, "no service card for " .. shopId)
				local npcs = withAttr(galleria(), "NpcId", npcId)
				t.expect(#npcs).toBe(1)
				local npc = npcs[1] :: BasePart
				t.expect(boutiqueOf(npc) == nil).toBeTruthy() -- markers live in the Markers folder
				t.expect((npc.CFrame.Position - card.CFrame.Position).Magnitude).toBeLessThan(PROMPT_RANGE)
				-- the card faces its customer, who stands on the shop floor within reach of the prompt
				local front = card.CFrame.Position + card.CFrame.LookVector * 2.4
				local customer = Vector3.new(front.X, origin().Y + 3, front.Z)
				standable(customer, shopId .. " customer spot")
				t.expect((customer - card.CFrame.Position).Magnitude).toBeLessThan(PROMPT_RANGE)
				-- the NPC looks toward the counter's customer side
				local toCustomer = Vector3.new(customer.X - npc.Position.X, 0, customer.Z - npc.Position.Z)
				t.expect(npc.CFrame.LookVector:Dot(toCustomer.Unit)).toBeGreaterThan(0.3)
			end
		end)

		t.it("dresses Hartwell's mannequins (anchored, passive) and racks its suits", function()
			local tailor = boutique("tailor")
			local mannequins = {}
			for _, d in tailor:GetDescendants() do
				if d:IsA("Model") and d:GetAttribute("Mannequin") then
					table.insert(mannequins, d)
				end
			end
			t.expect(#mannequins).toBeGreaterThanOrEqual(3)
			local dressed = 0
			for _, m in mannequins do
				t.expect(m:FindFirstChildWhichIsA("Humanoid", true)).toBeNil()
				for _, p in m:GetDescendants() do
					if p:IsA("BasePart") then
						t.expect(p.Anchored).toBe(true)
						t.expect(p.CanCollide).toBe(false)
					end
				end
				local look = m:FindFirstChild("CareerLook", true)
				if look and #look:GetDescendants() > 0 then
					dressed += 1
				end
			end
			-- NpcRig and Wardrobe exist in this repo, so every mannequin wears its Catalog look
			t.expect(dressed).toBe(#mannequins)
			t.expect(#props(tailor, "clothing_rack")).toBeGreaterThanOrEqual(2)
			t.expect(#props(tailor, "cash_counter")).toBe(1)
		end)

		t.it("makes Hartwell's fitting mirror the Galleria's only wardrobe interact", function()
			local list = withAttr(galleria(), "InteractId", "wardrobe")
			t.expect(#list).toBe(1)
			local mirror = list[1] :: BasePart
			t.expect(boutiqueOf(mirror)).toBe(boutique("tailor"))
			t.expect(mirror.Reflectance).toBeGreaterThan(0.4)
			-- someone standing in front of the glass can use it
			local front = mirror.CFrame.Position + mirror.CFrame.LookVector * 3.5
			local root = Vector3.new(front.X, origin().Y + 3.5, front.Z)
			t.expect((root - mirror.CFrame.Position).Magnitude).toBeLessThan(PROMPT_RANGE)
		end)

		t.it("fills Vanta with watch cases, Strider with shoe walls and Atelier Maison with three vignettes", function()
			t.expect(#props(boutique("watch"), "watch_case")).toBeGreaterThanOrEqual(3)
			t.expect(#props(boutique("shoes"), "shoe_wall")).toBeGreaterThanOrEqual(2)
			local decor = boutique("decor")
			for _, name in { "LivingRoom", "CornerOffice", "PenthouseSuite" } do
				local v = decor:FindFirstChild(name, true)
				assert(v and v:IsA("Model"), "Atelier Maison has no " .. name)
				t.expect(v:FindFirstChild("Platform") ~= nil).toBeTruthy()
				t.expect(v:FindFirstChild("VignetteWall") ~= nil).toBeTruthy()
				local label = v:FindFirstChild("VignetteLabel")
				t.expect(label ~= nil and label:FindFirstChildWhichIsA("SurfaceGui") ~= nil).toBeTruthy()
			end
		end)

		t.it("signs every shopfront with its name on a lit fascia", function()
			for shopId in SHOP_NPC do
				local fascia = boutique(shopId):FindFirstChild("Fascia", true)
				assert(fascia and fascia:IsA("BasePart"), shopId .. " has no fascia")
				local label = fascia:FindFirstChildWhichIsA("TextLabel", true)
				t.expect(label ~= nil and #(label :: TextLabel).Text > 3).toBeTruthy()
				t.expect(fascia:HasTag("InteriorLight")).toBeTruthy()
			end
		end)
	end)

	t.describe("atrium", function()
		t.it("roofs the atrium with a glass barrel vault on iron ribs under a painted sky", function()
			local glass, ribs = 0, 0
			for _, d in galleria():GetDescendants() do
				if d.Name == "VaultGlass" then
					glass += 1
					t.expect((d :: BasePart).Transparency).toBeGreaterThan(0.4)
				elseif d.Name == "Rib" then
					ribs += 1
				end
			end
			t.expect(glass).toBe(Plan.VAULT_SEGMENTS)
			t.expect(ribs).toBe(Plan.VAULT_SEGMENTS * #Plan.RIB_Z)
			local lid = galleria():FindFirstChild("SkyLid", true)
			t.expect(lid ~= nil and lid:FindFirstChild("Sky") ~= nil).toBeTruthy()
		end)

		t.it("lets shoppers walk through every shopfront doorway into the boutique", function()
			local o = origin()
			for _, spot in Plan.shops do
				local frame = CFrame.new(o) * spot.frame
				for _, sd in { -3, 0.5, 3, 7, 12 } do
					for _, sx in { -2.4, 0, 2.4 } do
						local p = Plan.point(frame, sx, 3, sd).Position
						standable(p, ("%s doorway (sx %.1f, sd %.1f)"):format(spot.id, sx, sd))
					end
				end
			end
		end)

		t.it("keeps the promenade clear from the doors to the fountain and along the shopfronts", function()
			local o = origin()
			for z = Plan.ENTRY_Z, -4, -3 do
				standable(o + Vector3.new(0, 3, z), ("centre aisle z=%d"):format(z))
			end
			for _, x in { -15.8, 15.8 } do
				for z = -32, 32, 4 do
					standable(o + Vector3.new(x, 3, z), ("shopfront walk x=%.1f z=%d"):format(x, z))
				end
			end
		end)
	end)
end
