-- The built templates against the services that consume them (pure, Lune-safe modules): OfficeService/Template
-- brands and reads them (logos, names, colours, anchors, doors, desks, chairs) and HousingService/Markers finds every
-- desk, office, decor slot, nameplate and theme part with the ids the housing system expects.

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)
local Logos = require(Shared.Assets.Logos)
local Services = game:GetService("ServerScriptService").Server.Services
local Template = require(Services.OfficeService.Template)
local Markers = require(Services.HousingService.Markers)
local Builders = game:GetService("ServerStorage").WorldBuilders
local OfficeLobby = require(Builders.OfficeLobby)
local OfficeFloorsA = require(Builders.OfficeFloorsA)

local COMPANY = (
	OfficeAlloc.normalizeCompany({
		id = "goldfield_saxe",
		name = "Goldfield Saxe",
		type = "bulge",
		departments = { "ib" },
		colors = { primary = "#4F79B8", accent = "#E8EEF6" },
	}) :: any
) :: OfficeAlloc.Company

local function count(list: { any }): number
	return #list
end

return function(t)
	t.describe("OfficeService/Template on the officesA templates", function()
		for _, spec in
			{
				{ build = OfficeLobby.build, id = "lobby", floor = "lobby" },
				{ build = OfficeFloorsA.build, id = "ib", floor = "ib" },
				{ build = OfficeFloorsA.build, id = "corpbank", floor = "corpbank" },
			}
		do
			t.it("brands the " .. spec.id .. " template", function()
				local m = spec.build(spec.id, nil)
				local result = Template.prepare(m, COMPANY, spec.floor, Logos)
				t.expect(result.logos).toBe(count((function()
					local n = {}
					for _, d in m:GetDescendants() do
						if d:HasTag(Template.TAG_LOGO) then
							table.insert(n, d)
						end
					end
					return n
				end)()))
				t.expect(result.logos).toBeGreaterThanOrEqual(1)
				t.expect(result.names).toBeGreaterThanOrEqual(1)
				t.expect(result.colors).toBeGreaterThanOrEqual(2)
				t.expect(Template.lightingFor(m, spec.floor)).toBe("office_interior")
				-- every logo part now carries exactly one logo GUI and every name label the company name
				for _, d in m:GetDescendants() do
					if d:HasTag(Template.TAG_LOGO) then
						local n = 0
						for _, c in d:GetChildren() do
							if c:GetAttribute("OfficeLogo") == true then
								n += 1
							end
						end
						t.expect(n).toBe(1)
					elseif d:IsA("TextLabel") and d.Name == Template.NAME_LABEL then
						t.expect(d.Text).toBe("Goldfield Saxe")
					elseif d:IsA("BasePart") and d:HasTag(Template.TAG_PRIMARY) then
						t.expect(d.Color).toEqual(COMPANY.primary)
					end
				end
				-- markers are stamped with the company
				for _, d in m:GetDescendants() do
					if
						d:GetAttribute("OfficeAnchor") ~= nil
						or d:GetAttribute("OfficeDoor") ~= nil
						or d:HasTag("Interact")
					then
						t.expect(d:GetAttribute("CompanyId")).toBe("goldfield_saxe")
					end
				end
			end)
		end

		t.it("finds the lobby's anchors and exit door", function()
			local m = OfficeLobby.build("lobby", nil)
			local anchors = Template.anchors(m)
			for _, id in { "entry", "elevators", "receptionist" } do
				t.expect(anchors[id] ~= nil).toBeTruthy()
			end
			local doors = Template.doors(m)
			t.expect(#doors).toBe(1)
			t.expect(doors[1].kind).toBe("exit")
			t.expect(#Template.deskSlots(m)).toBe(0)
		end)

		for _, id in OfficeFloorsA.TEMPLATES do
			t.it(
				"finds the " .. id .. " floor's anchors, door, desks in slot order and a chair at every desk",
				function()
					local m = OfficeFloorsA.build(id, nil)
					local anchors = Template.anchors(m)
					for _, name in { "floor_entry", "boss_chair", "review_spot", "rival_desk" } do
						t.expect(anchors[name] ~= nil).toBeTruthy()
					end
					local doors = Template.doors(m)
					t.expect(#doors).toBe(1)
					t.expect(doors[1].kind).toBe("to_lobby")
					local desks = Template.deskSlots(m)
					t.expect(#desks).toBe(World.floorSlots.desks)
					for i, desk in desks do
						t.expect(desk:GetAttribute("DeskSlot")).toBe(i)
						t.expect(Template.isTaken(desk)).toBe(false)
						local seat, chair = Template.chairOf(desk)
						t.expect(seat ~= nil or chair ~= nil).toBeTruthy()
					end
				end
			)
		end
	end)

	t.describe("HousingService/Markers on the officesA floors", function()
		for _, id in OfficeFloorsA.TEMPLATES do
			t.it("finds 24 desks and 8 offices with their slots on the " .. id .. " floor", function()
				local m = OfficeFloorsA.build(id, nil)
				local desks = Markers.containers(m, "desk")
				local offices = Markers.containers(m, "office")
				t.expect(#desks).toBe(World.floorSlots.desks)
				t.expect(#offices).toBe(World.floorSlots.offices)
				t.expect(#Markers.containers(m, "unit")).toBe(0)
				for _, desk in desks do
					t.expect(Markers.containerKind(desk)).toBe("desk")
					local plaques, others = {}, 0
					for _, slot in Markers.slots(desk) do
						if slot.kind == "plaque" then
							table.insert(plaques, slot.id)
						else
							others += 1
						end
					end
					t.expect(#plaques).toBe(World.floorSlots.plaquesPerDesk)
					t.expect(plaques).toEqual({ "plaque_1", "plaque_2", "plaque_3" })
					t.expect(others).toBe(2)
					t.expect(#Markers.nameplates(desk)).toBe(1)
				end
				for _, office in offices do
					t.expect(Markers.containerKind(office)).toBe("office")
					local plaques, others = 0, 0
					local seen = {}
					for _, slot in Markers.slots(office) do
						t.expect(seen[slot.id]).toBeNil()
						seen[slot.id] = true
						if slot.kind == "plaque" then
							plaques += 1
						else
							others += 1
						end
					end
					t.expect(plaques).toBe(World.floorSlots.plaquesPerShelf)
					t.expect(others).toBeGreaterThanOrEqual(5)
					t.expect(#Markers.nameplates(office)).toBe(1)
					local walls, floors = Markers.themeParts(office)
					t.expect(#walls).toBeGreaterThanOrEqual(1)
					t.expect(#floors).toBeGreaterThanOrEqual(1)
					-- the housing panel and the nameplate belong to this office, not a neighbour
					for _, d in office:GetDescendants() do
						if d:GetAttribute("InteractId") == "housing_panel" then
							local owner = Markers.containerOf(d)
							t.expect(owner).toBe(office)
						end
					end
				end
			end)
		end

		t.it("keeps slot ids identical across two copies of a floor (any company, same ids)", function()
			local a = Markers.containers(OfficeFloorsA.build("ib", nil), "office")
			local b = Markers.containers(OfficeFloorsA.build("ib", nil), "office")
			for i = 1, #a do
				local ia, ib = {}, {}
				for _, s in Markers.slots(a[i]) do
					table.insert(ia, s.id)
				end
				for _, s in Markers.slots(b[i]) do
					table.insert(ib, s.id)
				end
				t.expect(ia).toEqual(ib)
			end
		end)
	end)
end
