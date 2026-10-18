-- HousingService markers and drawing (HousingService/Markers + Render) on hand-built desk, office and unit
-- containers under Lune: container discovery and order, stable slot ids across rotated copies, slots of nested
-- containers kept apart, mount points, plaque layout on desks (3) and bookshelves (24), nameplates, themes, and a
-- full clear back to the template.

local Shared = game:GetService("ReplicatedStorage").Shared
local Decor = require(Shared.Config.Decor)
local World = require(Shared.Config.World)
local Plaques = require(Shared.Logic.Economy.Plaques)
local Services = game:GetService("ServerScriptService").Server.Services
local Markers = require(Services.HousingService.Markers)
local Render = require(Services.HousingService.Render)

local BASE = 1792281600

local function part(parent: Instance, name: string, cf: CFrame, attrs: { [string]: any }?, tags: { string }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(1, 0.2, 1)
	p.CFrame = cf
	for k, v in attrs or {} do
		p:SetAttribute(k, v)
	end
	for _, tag in tags or {} do
		p:AddTag(tag)
	end
	p.Parent = parent
	return p
end

-- A desk with 2 desk spots, 3 plaque spots and a nameplate, built around `origin`.
local function desk(parent: Instance, index: number, origin: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "DeskSlot"
	m:SetAttribute("DeskSlot", index)
	local top = part(m, "Top", origin, nil)
	top.Size = Vector3.new(6, 0.2, 3)
	m.PrimaryPart = top
	-- listed out of order on purpose: ids come from position, not child order
	part(m, "DecorSlot", origin * CFrame.new(2, 0.2, 0), { SlotKind = "desk_item" })
	part(m, "DecorSlot", origin * CFrame.new(-2, 0.2, 0), { SlotKind = "desk_item" })
	for i = 3, 1, -1 do
		part(m, "DecorSlot", origin * CFrame.new(-1.5 + (i - 1) * 1.5, 0.2, 1), { SlotKind = "plaque" })
	end
	part(m, "Nameplate", origin * CFrame.new(0, 0.3, -1.2), nil)
	part(
		m,
		"Panel",
		origin * CFrame.new(0, 1, -1.5),
		{ InteractId = "housing_panel", Context = "desk" },
		{ "Interact" }
	)
	m.Parent = parent
	return m
end

local function office(parent: Instance, origin: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "OfficeSlot"
	m:SetAttribute("OfficeSlot", 1)
	local floor = part(m, "Floor", origin, nil, { "ThemeFloor" })
	floor.Size = Vector3.new(20, 1, 20)
	floor.Color = Color3.fromRGB(10, 20, 30)
	floor.Material = Enum.Material.Carpet
	m.PrimaryPart = floor
	local wall = part(m, "Wall", origin * CFrame.new(0, 6, 10), nil, { "ThemeWall" })
	wall.Color = Color3.fromRGB(200, 200, 200)
	part(m, "Wall2", origin * CFrame.new(10, 6, 0), { Theme = "wall" })
	local shelf = Instance.new("Model")
	shelf.Name = "Bookshelf"
	shelf.Parent = m
	for row = 1, 4 do
		for col = 1, 6 do
			part(shelf, "DecorSlot", origin * CFrame.new(-4 + col, row * 1.5, 9), { SlotKind = "plaque" })
		end
	end
	part(m, "DecorSlot", origin * CFrame.new(3, 0.5, 3), { SlotKind = "floor" })
	part(m, "DecorSlot", origin * CFrame.new(-3, 0.5, 3), { SlotKind = "rug", SlotId = "center_rug" })
	part(m, "DecorSlot", origin * CFrame.new(0, 5, 9.8), { SlotKind = "wall_art", MaxWidth = 6, MaxHeight = 4 })
	local plate = Instance.new("Model")
	plate.Name = "Nameplate"
	local platePart = part(plate, "Plate", origin * CFrame.new(0, 3, -9), nil)
	local gui = Instance.new("SurfaceGui")
	gui.Parent = platePart
	local label = Instance.new("TextLabel")
	label.Text = "VACANT"
	label.Parent = gui
	plate.Parent = m
	-- a desk inside the office keeps its own slots
	desk(m, 99, origin * CFrame.new(0, 0, -5))
	m.Parent = parent
	return m
end

local function plaques(n: number): { any }
	local list = {}
	for i = 1, n do
		table.insert(list, { id = "p" .. i, name = "Deal " .. i, at = BASE + i * 60, quality = 50 + i })
	end
	return list
end

local function idsOf(slots: { Markers.Slot }, kind: string): { string }
	local out = {}
	for _, s in slots do
		if s.kind == kind then
			table.insert(out, s.id)
		end
	end
	return out
end

local function countModels(container: Instance, folder: string): number
	local f = container:FindFirstChild(folder)
	return if f then #f:GetChildren() else 0
end

return function(t)
	t.describe("containers", function()
		t.it("finds desks in slot order and offices", function()
			local floor = Instance.new("Model")
			desk(floor, 3, CFrame.new(30, 0, 0))
			desk(floor, 1, CFrame.new(10, 0, 0))
			desk(floor, 2, CFrame.new(20, 0, 0))
			office(floor, CFrame.new(0, 0, 100))
			local desks = Markers.containers(floor, "desk")
			t.expect(#desks).toBe(4) -- the desk inside the office counts as a desk too
			t.expect(desks[1]:GetAttribute("DeskSlot")).toBe(1)
			t.expect(desks[3]:GetAttribute("DeskSlot")).toBe(3)
			t.expect(#Markers.containers(floor, "office")).toBe(1)
			t.expect(#Markers.containers(floor, "unit")).toBe(0)
		end)
		t.it("containerOf walks up to the nearest container", function()
			local floor = Instance.new("Model")
			local d = desk(floor, 1, CFrame.new())
			local panel = d:FindFirstChild("Panel") :: Instance
			local c, kind = Markers.containerOf(panel)
			t.expect(c).toBe(d)
			t.expect(kind).toBe("desk")
			t.expect((Markers.containerOf(floor))).toBeNil()
		end)
		t.it("classifies units by attribute or by the zone they stand in", function()
			local a = Instance.new("Model")
			a:SetAttribute("UnitSlot", 1)
			a:SetAttribute("UnitKind", "apartment")
			t.expect(Markers.unitKind(a)).toBe("apartment")
			local dorm = Instance.new("Model")
			dorm:SetAttribute("UnitSlot", 2)
			local mn, mx = World.interiorBounds("dorm")
			part(dorm, "Floor", CFrame.new((mn + mx) / 2), nil)
			t.expect(Markers.unitKind(dorm)).toBe("dorm")
			local nowhere = Instance.new("Model")
			part(nowhere, "Floor", CFrame.new(99999, 0, 99999), nil)
			t.expect(Markers.unitKind(nowhere)).toBeNil()
		end)
	end)

	t.describe("slots", function()
		t.it("numbers slots per kind by position, the same in every rotated copy", function()
			local a = desk(Instance.new("Model"), 1, CFrame.new(10, 0, 0))
			local b = desk(Instance.new("Model"), 2, CFrame.new(-50, 3, 40) * CFrame.Angles(0, math.rad(90), 0))
			local sa, sb = Markers.slots(a), Markers.slots(b)
			t.expect(#sa).toBe(5)
			t.expect(idsOf(sa, "desk_item")).toEqual({ "desk_item_1", "desk_item_2" })
			t.expect(idsOf(sa, "plaque")).toEqual({ "plaque_1", "plaque_2", "plaque_3" })
			for i, s in sa do
				t.expect(sb[i].id).toBe(s.id)
				-- same local position in both copies
				local la = (a.PrimaryPart :: BasePart).CFrame:PointToObjectSpace(s.part.CFrame.Position)
				local lb = (b.PrimaryPart :: BasePart).CFrame:PointToObjectSpace(sb[i].part.CFrame.Position)
				t.expect((la - lb).Magnitude < 1e-3).toBe(true)
			end
		end)
		t.it("keeps explicit SlotIds and reads size limits", function()
			local o = office(Instance.new("Model"), CFrame.new())
			local slots = Markers.slots(o)
			local byId: { [string]: Markers.Slot } = {}
			for _, s in slots do
				byId[s.id] = s
			end
			t.expect(byId.center_rug ~= nil).toBe(true)
			t.expect(byId.center_rug.kind).toBe("rug")
			local limits = byId.wall_art_1.limits :: Markers.Limits
			t.expect(limits.width).toBe(6)
			t.expect(limits.height).toBe(4)
			t.expect(limits.depth).toBeNil()
		end)
		t.it("an office has 24 bookshelf plaque slots and none of its inner desk's slots", function()
			local o = office(Instance.new("Model"), CFrame.new())
			local slots = Markers.slots(o)
			t.expect(#idsOf(slots, "plaque")).toBe(World.floorSlots.plaquesPerShelf)
			t.expect(#idsOf(slots, "desk_item")).toBe(0)
		end)
		t.it("floor and desk items stand on the slot's bottom face; wall items hang from its back", function()
			local p = Instance.new("Part")
			p.Size = Vector3.new(2, 1, 0.4)
			p.CFrame = CFrame.new(5, 10, 5)
			t.expect((Markers.mountCFrame(p, "floor").Position - Vector3.new(5, 9.5, 5)).Magnitude < 1e-4).toBe(true)
			t.expect((Markers.mountCFrame(p, "wall").Position - Vector3.new(5, 9.5, 5.2)).Magnitude < 1e-4).toBe(true)
		end)
		t.it("finds nameplates and theme parts", function()
			local o = office(Instance.new("Model"), CFrame.new())
			t.expect(#Markers.nameplates(o)).toBe(1)
			local walls, floors = Markers.themeParts(o)
			t.expect(#walls).toBe(2)
			t.expect(#floors).toBe(1)
		end)
	end)

	t.describe("render", function()
		t.it("draws placed decor on its slots and clears it again", function()
			local d = desk(Instance.new("Model"), 1, CFrame.new(0, 3, 0))
			local slots = Markers.slots(d)
			local decorSlots = {}
			for _, s in slots do
				if s.kind ~= "plaque" then
					table.insert(decorSlots, s)
				end
			end
			local parts = Render.decor(d, decorSlots, {
				desk_item_1 = Decor.get("desk_mug_navy") :: Decor.Item,
				desk_item_2 = Decor.get("desk_globe") :: Decor.Item,
			})
			t.expect(parts > 0).toBe(true)
			t.expect(countModels(d, Render.DECOR_FOLDER)).toBe(2)
			local mug = (d:FindFirstChild(Render.DECOR_FOLDER) :: Instance):FindFirstChild("desk_mug_navy") :: Model
			t.expect(mug:GetAttribute("HousingSlot")).toBe("desk_item_1")
			-- the mug's root stands on the slot's bottom face
			local slotPart = decorSlots[1].part
			local root = mug.PrimaryPart :: BasePart
			t.expect(math.abs(root.CFrame.Position.Y - (slotPart.CFrame.Position.Y - slotPart.Size.Y / 2)) < 1e-3)
				.toBe(true)
			Render.decor(d, decorSlots, {})
			t.expect(d:FindFirstChild(Render.DECOR_FOLDER)).toBeNil()
		end)
		t.it("puts the newest 3 plaques on a desk, engraved with name and date", function()
			local d = desk(Instance.new("Model"), 1, CFrame.new())
			local slots = Markers.slots(d)
			local plaqueSlots, ids = {}, {}
			for _, s in slots do
				if s.kind == "plaque" then
					table.insert(plaqueSlots, s)
					table.insert(ids, s.id)
				end
			end
			local layout = Plaques.layout(plaques(7), ids, Plaques.DESK)
			t.expect(Render.plaques(d, plaqueSlots, layout)).toBe(3)
			local folder = d:FindFirstChild(Render.PLAQUE_FOLDER) :: Instance
			t.expect(#folder:GetChildren()).toBe(3)
			local newest = folder:FindFirstChild("Plaque_p7") :: Model
			t.expect(newest ~= nil).toBe(true)
			local found = false
			for _, x in newest:GetDescendants() do
				if x:IsA("TextLabel") and x.Text == "Deal 7\n" .. Plaques.dateText(BASE + 7 * 60) then
					found = true
				end
			end
			t.expect(found).toBe(true)
			t.expect(Render.plaques(d, plaqueSlots, {})).toBe(0)
			t.expect(d:FindFirstChild(Render.PLAQUE_FOLDER)).toBeNil()
		end)
		t.it("fills an office bookshelf with up to 24", function()
			local o = office(Instance.new("Model"), CFrame.new())
			local slots = Markers.slots(o)
			local plaqueSlots, ids = {}, {}
			for _, s in slots do
				if s.kind == "plaque" then
					table.insert(plaqueSlots, s)
					table.insert(ids, s.id)
				end
			end
			t.expect(Render.plaques(o, plaqueSlots, Plaques.layout(plaques(30), ids, Plaques.SHELF))).toBe(24)
		end)
		t.it("writes nameplates, applies themes, marks the owner and restores the template", function()
			local o = office(Instance.new("Model"), CFrame.new())
			local floor = o:FindFirstChild("Floor") :: BasePart
			local label = (o:FindFirstChild("Nameplate") :: Instance):FindFirstChildWhichIsA(
					"TextLabel",
					true
				) :: TextLabel
			Render.setOwner(o, 42, "Avery")
			Render.nameplate(o, "Avery Whitmore\nVice President")
			Render.theme(o, Decor.theme("art_deco"))
			t.expect(o:GetAttribute("OwnerUserId")).toBe(42)
			t.expect(label.Text).toBe("Avery Whitmore\nVice President")
			t.expect(floor.Material).toBe(Enum.Material.Marble)
			-- a second theme still restores to the template's original look
			Render.theme(o, Decor.theme("walnut"))
			t.expect(floor.Material).toBe(Enum.Material.Carpet)
			Render.clear(o)
			t.expect(o:GetAttribute("OwnerUserId")).toBeNil()
			t.expect(o:GetAttribute("OwnerName")).toBeNil()
			t.expect(label.Text).toBe("VACANT")
			t.expect(floor.Material).toBe(Enum.Material.Carpet)
			t.expect(floor.Color).toEqual(Color3.fromRGB(10, 20, 30))
		end)
		t.it("adds a nameplate label to a bare nameplate part and removes it on clear", function()
			local d = desk(Instance.new("Model"), 1, CFrame.new())
			local plate = d:FindFirstChild("Nameplate") :: BasePart
			Render.nameplate(d, "Sam Lee\nAnalyst")
			local gui = plate:FindFirstChild(Render.NAMEPLATE_GUI)
			t.expect(gui ~= nil).toBe(true)
			t.expect((gui :: Instance):FindFirstChildWhichIsA("TextLabel").Text).toBe("Sam Lee\nAnalyst")
			Render.clear(d)
			t.expect(plate:FindFirstChild(Render.NAMEPLATE_GUI)).toBeNil()
		end)
	end)
end
