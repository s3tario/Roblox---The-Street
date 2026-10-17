-- Office template branding and markers (OfficeService/Template) on hand-built templates under Lune.
local Shared = game:GetService("ReplicatedStorage").Shared
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)
local Logos = require(Shared.Assets.Logos)
local Template = require(game:GetService("ServerScriptService").Server.Services.OfficeService.Template)

local COMPANY = (
	OfficeAlloc.normalizeCompany({
		id = "mg_freeman",
		name = "MG Freeman",
		type = "bulge",
		departments = { "ib" },
		colors = { primary = "#1B2A4A", accent = "#B8935A" },
	}) :: any
) :: OfficeAlloc.Company

local function part(parent: Instance, name: string, attrs: { [string]: any }?, tags: { string }?): Part
	local p = Instance.new("Part")
	p.Name = name
	for k, v in attrs or {} do
		p:SetAttribute(k, v)
	end
	for _, tag in tags or {} do
		p:AddTag(tag)
	end
	p.Parent = parent
	return p
end

local function floorTemplate(): Model
	local m = Instance.new("Model")
	m.Name = "ib"
	local wall = part(m, "LogoWall", { LogoFace = "Back" }, { "CompanyLogo" })
	part(m, "Sign", nil, { "CompanyLogo" })
	part(m, "Carpet", nil, { "FirmColor" })
	part(m, "Trim", nil, { "FirmAccent" })
	local board = Instance.new("SurfaceGui")
	board.Parent = wall
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "CompanyName"
	nameLabel.Text = "COMPANY"
	nameLabel.Parent = board
	local other = Instance.new("TextLabel")
	other.Name = "Other"
	other.Text = "keep"
	other.Parent = board
	part(m, "Entry", { OfficeAnchor = "floor_entry" })
	part(m, "Boss", { OfficeAnchor = "boss_chair" })
	part(m, "Legacy", { AnchorId = "review_spot" }, { "Anchor" })
	part(m, "Elevator", { OfficeDoor = "to_lobby" }, { "Door" })
	part(m, "Desk", { InteractId = "work_desk" }, { "Interact" })
	for i = 1, 3 do
		local desk = Instance.new("Model")
		desk.Name = "DeskSlot"
		desk:SetAttribute("DeskSlot", 4 - i)
		local top = part(desk, "Top")
		top.Position = Vector3.new(i * 10, 0, 0)
		local chair = Instance.new("Model")
		chair.Name = "Chair"
		chair:SetAttribute("PropId", "chair_mesh_orange")
		part(chair, "Seat")
		chair.Parent = desk
		desk.Parent = m
	end
	return m
end

return function(t)
	t.describe("OfficeService/Template", function()
		t.it("brands logos, names and firm colours with the Logos library", function()
			local m = floorTemplate()
			local result = Template.prepare(m, COMPANY, "ib", Logos)
			t.expect(result.logos).toBe(2)
			t.expect(result.names).toBe(1)
			t.expect(result.colors).toBe(2)
			t.expect(m:GetAttribute("CompanyId")).toBe("mg_freeman")
			t.expect(m:GetAttribute("Department")).toBe("ib")
			t.expect(m:GetAttribute("LightingPreset")).toBe("office_interior")
			local label = m:FindFirstChild("CompanyName", true) :: TextLabel
			t.expect(label.Text).toBe("MG Freeman")
			t.expect((m:FindFirstChild("Other", true) :: TextLabel).Text).toBe("keep")
			t.expect((m:FindFirstChild("Carpet") :: Part).Color).toEqual(COMPANY.primary)
			t.expect((m:FindFirstChild("Trim") :: Part).Color).toEqual(COMPANY.accent)
			local wall = m:FindFirstChild("LogoWall") :: Part
			local gui: any = nil
			for _, c in wall:GetChildren() do
				if c:IsA("SurfaceGui") and c:GetAttribute("OfficeLogo") == true then
					gui = c
				end
			end
			t.expect(gui ~= nil).toBeTruthy()
			t.expect(gui.Face).toBe(Enum.NormalId.Back)
		end)
		t.it("falls back to a name sign when the logo library fails or is missing", function()
			local broken = {
				surface = function()
					error("boom")
				end,
			}
			for _, lib in { broken, nil :: any } do
				local m = floorTemplate()
				local result = Template.brand(m, COMPANY, lib)
				t.expect(result.logos).toBe(2)
				local sign = m:FindFirstChild("Sign") :: Part
				local gui = sign:FindFirstChild(Template.LOGO_GUI) :: SurfaceGui
				t.expect(gui ~= nil).toBeTruthy()
				t.expect((gui:FindFirstChild("Name") :: TextLabel).Text).toBe("MG Freeman")
			end
		end)
		t.it("re-branding replaces the old logo instead of stacking a second one", function()
			local m = floorTemplate()
			Template.brand(m, COMPANY, nil)
			Template.brand(m, COMPANY, nil)
			local sign = m:FindFirstChild("Sign") :: Part
			local n = 0
			for _, c in sign:GetChildren() do
				if c:GetAttribute("OfficeLogo") == true then
					n += 1
				end
			end
			t.expect(n).toBe(1)
		end)
		t.it("stamps the company on interaction points, doors and anchors", function()
			local m = floorTemplate()
			Template.prepare(m, COMPANY, "ib", nil)
			for _, name in { "Desk", "Elevator", "Entry", "Boss" } do
				local p = m:FindFirstChild(name) :: Part
				t.expect(p:GetAttribute("CompanyId")).toBe("mg_freeman")
				t.expect(p:GetAttribute("Department")).toBe("ib")
			end
			t.expect((m:FindFirstChild("Carpet") :: Part):GetAttribute("CompanyId")).toBeNil()
		end)
		t.it("finds anchors (AnchorId as a fallback), doors and desks in slot order", function()
			local m = floorTemplate()
			local anchors = Template.anchors(m)
			t.expect(anchors.floor_entry.Name).toBe("Entry")
			t.expect(anchors.boss_chair.Name).toBe("Boss")
			t.expect(anchors.review_spot.Name).toBe("Legacy")
			local doors = Template.doors(m)
			t.expect(#doors).toBe(1)
			t.expect(doors[1].kind).toBe("to_lobby")
			local desks = Template.deskSlots(m)
			t.expect(#desks).toBe(3)
			t.expect(desks[1]:GetAttribute("DeskSlot")).toBe(1)
			t.expect(desks[3]:GetAttribute("DeskSlot")).toBe(3)
			local seat, chair = Template.chairOf(desks[1])
			t.expect(seat).toBeNil()
			t.expect((chair :: Model).Name).toBe("Chair")
		end)
		t.it("respects desks other features hand to players", function()
			local m = floorTemplate()
			local desk = Template.deskSlots(m)[2]
			t.expect(Template.isTaken(desk)).toBe(false)
			desk:SetAttribute("OwnerUserId", 1234)
			t.expect(Template.isTaken(desk)).toBe(true)
			desk:SetAttribute("OwnerUserId", 0)
			t.expect(Template.isTaken(desk)).toBe(false)
		end)
		t.it("keeps a template's own lighting preset and lights trading floors", function()
			local m = Instance.new("Model")
			t.expect(Template.lightingFor(m, "st")).toBe("trading_floor")
			t.expect(Template.lightingFor(m, "lobby")).toBe("office_interior")
			m:SetAttribute("LightingPreset", "luxury_interior")
			t.expect(Template.lightingFor(m, "ib")).toBe("luxury_interior")
			m:SetAttribute("LightingPreset", "disco")
			t.expect(Template.lightingFor(m, "ib")).toBe("office_interior")
		end)
	end)
end
