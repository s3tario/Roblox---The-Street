--!strict
-- One Marlow House dorm room: a UnitSlot container (Model "DormRoom_NN", attributes UnitSlot = n, UnitKind = "dorm",
-- RoomNumber, tag "UnitSlot", PrimaryPart "Root" at the doorway) for HousingService (contracts §7):
--   * Nameplate (corridor side, beside the door)      * ThemeFloor carpet + ThemeWall liners (back, left, right)
--   * housing_panel (Context "dorm") inside the door  * wardrobe interact: the full-length mirror
--   * DecorSlots (unique SlotIds per room, Config/Decor slot kinds):
--       wall_bed (wall_art, over the bed)   wall_side (wall_art, right wall)   desk_top (desk_item)
--       floor_side (floor, by the right wall)   rug_center (rug)   lamp_corner (lamp, between bed and desk)
--   plus the furniture every room ships with: steel bed, laminate desk and chair, a window with a painted view,
--   the door left open and a ceiling light.
--
-- Room.build(parent, rc, unit, number, rng) -> Model
--   rc = the doorway's centre on the room side of the corridor wall, at floor level, LookVector into the room.
--   Room-local frame: x across the room (-6.5..6.5), depth d into the room (0..15), ceiling at Room.HEIGHT.
-- Room.SLOT_IDS lists the decor slot ids in build order. Bake-safe.

local Deps = require(script.Parent.Deps)

local Kit = Deps.Kit
local Paint = Deps.Paint
local Text = Deps.Text
local Markers = Deps.Markers
local Core = Deps.Gui.Core
local P = Deps.Palette
local hex = P.hex
local M = Enum.Material

local Room = {}

Room.WIDTH = 13 -- clear width between the partitions
Room.DEPTH = 15 -- clear depth from the corridor wall to the back wall
Room.HEIGHT = 12
Room.SLOT_IDS = { "wall_bed", "wall_side", "desk_top", "floor_side", "rug_center", "lamp_corner" }

local BLANKETS = { hex("#2C5E8A"), hex("#7A3B2E"), hex("#56613A"), hex("#5C6168"), hex("#8A6A2E"), hex("#4A3A5C") }
local CARPETS = { hex("#6E6A5F"), hex("#5C5A52"), hex("#7A7264"), hex("#5E5648") }
local WALLS = { hex("#D8D0BE"), hex("#CFC9B8"), hex("#D6CDB4"), hex("#C9C6BA") }

-- position in the room frame: x across, y up, d into the room
local function at(rc: CFrame, x: number, y: number, d: number): CFrame
	return rc * CFrame.new(x, y, -d)
end

-- rotations that make a part's front face look along the room's axes
local FACE_DOOR = CFrame.Angles(0, math.pi, 0) -- toward the door (+Z of rc)
local FACE_RIGHT = CFrame.Angles(0, math.rad(-90), 0) -- toward +X (from the left wall)
local FACE_LEFT = CFrame.Angles(0, math.rad(90), 0) -- toward -X (from the right wall)

function Room.build(parent: Instance, rc: CFrame, unit: number, number: number, rng: Deps.RngT): Model
	local m = Kit.model(nil, string.format("DormRoom_%02d", unit))
	m:SetAttribute("UnitSlot", unit)
	m:SetAttribute("UnitKind", "dorm")
	m:SetAttribute("RoomNumber", number)
	m:AddTag("UnitSlot")
	local W2, D = Room.WIDTH / 2, Room.DEPTH

	local root = Kit.block(m, rc * CFrame.new(0, 0.5, 0), Vector3.new(1, 1, 1), nil, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	root.Name = "Root"
	m.PrimaryPart = root

	-- theme surfaces: carpet and wall liners (HousingService recolours these; the structure behind them collides)
	local carpet = Kit.detail(m, at(rc, 0, 0.03, D / 2), Vector3.new(Room.WIDTH, 0.06, D), rng:pick(CARPETS), M.Carpet)
	carpet.Name = "Carpet"
	Markers.theme(carpet, "floor")
	local wallC = rng:pick(WALLS)
	local liners = {
		{ cf = at(rc, 0, Room.HEIGHT / 2, D - 0.05), size = Vector3.new(Room.WIDTH, Room.HEIGHT, 0.1) },
		{ cf = at(rc, -W2 + 0.05, Room.HEIGHT / 2, D / 2), size = Vector3.new(0.1, Room.HEIGHT, D) },
		{ cf = at(rc, W2 - 0.05, Room.HEIGHT / 2, D / 2), size = Vector3.new(0.1, Room.HEIGHT, D) },
	}
	for _, l in liners do
		local p = Kit.detail(m, l.cf, l.size, wallC, M.SmoothPlastic)
		p.Name = "WallLiner"
		p.CastShadow = false
		Markers.theme(p, "wall")
	end

	-- the steel bunk-style bed against the left wall
	local frame = Kit.block(m, at(rc, -4.5, 0.7, 11), Vector3.new(4, 1.4, 8), hex("#3E4A52"), M.Metal)
	frame.Name = "BedFrame"
	Kit.block(m, at(rc, -4.5, 1.75, 11), Vector3.new(3.8, 0.7, 7.8), hex("#E6E2D8"), M.Fabric).Name = "Mattress"
	Kit.detail(m, at(rc, -4.5, 2.17, 10.2), Vector3.new(3.9, 0.16, 5.6), rng:pick(BLANKETS), M.Fabric).Name = "Blanket"
	Kit.detail(m, at(rc, -4.5, 2.35, 14), Vector3.new(2.6, 0.5, 1.2), hex("#F4F1EA"), M.Fabric).Name = "Pillow"

	-- desk and chair under the window
	Kit.block(m, at(rc, 4.25, 3.05, 14), Vector3.new(4.4, 0.3, 2), hex("#B8956A"), M.Wood).Name = "Desk"
	Kit.block(m, at(rc, 5.9, 1.45, 14), Vector3.new(1.1, 2.9, 1.8), hex("#9C7A52"), M.Wood).Name = "Drawers"
	local seat = Kit.block(m, at(rc, 4, 1.75, 11.8), Vector3.new(1.9, 0.3, 1.9), hex("#2A2A2A"), M.Plastic)
	seat.Name = "Chair"
	Kit.detail(m, at(rc, 4, 3.1, 10.95), Vector3.new(1.9, 2.4, 0.25), hex("#2A2A2A"), M.Plastic).Name = "ChairBack"
	Kit.detail(m, at(rc, 4, 0.8, 11.8), Vector3.new(0.3, 1.6, 0.3), hex("#5A5A5A"), M.Metal).Name = "ChairLeg"

	-- the window over the desk: a painted view and a sill
	local view =
		Kit.detail(m, at(rc, 2.6, 7.4, D - 0.12) * FACE_DOOR, Vector3.new(5, 4, 0.1), hex("#9AA2A6"), M.SmoothPlastic)
	view.Name = "WindowView"
	view.CastShadow = false
	local vg, VW, VH = Paint.surface(view, Enum.NormalId.Front, 10, { maxDistance = 120 })
	Paint.view(vg, VW, VH, rng, if unit % 3 == 0 then "night" else "campus")
	Paint.muntins(vg, 2, 2, hex("#E9E4D8"), 0.04)
	Kit.detail(m, at(rc, 2.6, 5.25, D - 0.35), Vector3.new(5.8, 0.3, 0.6), hex("#E9E4D8"), M.SmoothPlastic).Name =
		"Sill"

	-- the full-length mirror (wardrobe) on the right wall, just inside the door
	Kit.detail(m, at(rc, W2 - 0.15, 4, 4) * FACE_LEFT, Vector3.new(2.8, 6.6, 0.2), hex("#4A3A2C"), M.Wood).Name =
		"MirrorFrame"
	local mirror = Kit.block(m, at(rc, W2 - 0.3, 4, 4) * FACE_LEFT, Vector3.new(2.4, 6.2, 0.1), hex("#C9D6DC"), M.Glass)
	mirror.Name = "Mirror"
	mirror.Reflectance = 0.45
	mirror.CanCollide = false
	Markers.interact(mirror, "wardrobe")

	-- the housing panel on the door wall (room side), left of the doorway
	local panel = Kit.block(m, at(rc, -4.6, 4.8, 0.1), Vector3.new(1.8, 2.4, 0.15), hex("#1A1D20"), M.SmoothPlastic)
	panel.Name = "HousingPanel"
	panel.CanCollide = false
	Markers.interact(panel, "housing_panel", { Context = "dorm" })
	local pg = Paint.surface(panel, Enum.NormalId.Front, 40, { glow = true, brightness = 1, maxDistance = 120 })
	local pbg = Core.bg(pg, hex("#13243A"))
	Core.gradient(pbg, hex("#1F3A5C"), hex("#0E1A24"), 90)
	Core.label(pg, string.format(Text.dormInside.panel, number), 0.08, 0.15, 0.84, 0.7, hex("#F4F1E6"), {
		font = Enum.Font.GothamBold,
		align = Enum.TextXAlignment.Center,
	})

	-- the nameplate on the corridor side of the door wall (front face toward the corridor)
	Markers.nameplate(
		m,
		at(rc, 4.3, 6.6, -1.06) * FACE_DOOR,
		Vector3.new(2.6, 0.9, 0.1),
		string.format(Text.dormInside.room, number),
		{
			color = hex("#2A2622"),
			ink = hex("#E9E2CF"),
		}
	)

	-- the door, left open against the right side of the doorway, and the ceiling light
	Kit.detail(m, at(rc, 3.15, 4.5, 3), Vector3.new(0.2, 8.8, 5.8), hex("#6B4E35"), M.Wood).Name = "DoorLeaf"
	local light = Kit.detail(m, at(rc, 0, Room.HEIGHT - 0.1, 8), Vector3.new(2.4, 0.12, 2.4), hex("#F4EEDC"), M.Neon)
	light.Name = "CeilingLight"
	light.Transparency = 0.2
	light.CastShadow = false
	light:AddTag("InteriorLight")

	-- decor slots
	Markers.wallSlot(m, "wall_art", "wall_bed", at(rc, -W2 + 0.1, 4.2, 11) * FACE_RIGHT, Vector3.new(7.5, 5, 0.5), {
		width = 8.5,
		height = 5.5,
	})
	Markers.wallSlot(m, "wall_art", "wall_side", at(rc, W2 - 0.1, 4, 9.2) * FACE_LEFT, Vector3.new(5, 4, 0.4), {
		width = 6,
		height = 5,
	})
	Markers.surfaceSlot(m, "desk_item", "desk_top", at(rc, 3.4, 3.2, 14.1) * FACE_DOOR, Vector3.new(2, 1.2, 1.2), {
		width = 2.4,
		depth = 1.6,
		height = 2,
	})
	Markers.surfaceSlot(m, "floor", "floor_side", at(rc, 4.8, 0.06, 8.25) * FACE_LEFT, Vector3.new(4.5, 4, 3), {
		width = 4.5,
		depth = 3.2,
		height = 7.5,
	})
	Markers.surfaceSlot(m, "rug", "rug_center", at(rc, 0.5, 0.07, 7.5), Vector3.new(10, 0.1, 8), {
		width = 10,
		depth = 8,
		height = 0.5,
	})
	Markers.surfaceSlot(m, "lamp", "lamp_corner", at(rc, -0.4, 0.06, 13.9) * FACE_DOOR, Vector3.new(2, 4, 2), {
		width = 2.2,
		depth = 2.2,
		height = 7.5,
	})

	m.Parent = parent
	return m
end

return Room
