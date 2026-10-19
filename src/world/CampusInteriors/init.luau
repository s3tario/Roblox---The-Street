--!strict
-- CampusInteriors (campus feature; v1 §9, v3 §19 M1): the four Eastbridge venue interiors, each built in its own
-- Config/World interior slot and baked into Workspace.World.
--
--   build(parent?) -> Model "CampusInteriors" with one Model per interior (attributes Interior, LightingPreset):
--     career_center  CareerCenter: Life Roll kiosk, Career Services, recruiting suite, carrels, computer lab
--     lecture        Lecture: Halvorsen Hall's foyer, tiered lecture hall, Finance Club room and library nook
--     dorm           Dorm: Marlow House lobby, common room and two wings of 12 rooms (24 UnitSlots)
--     subway         Subway: two Route 9 cars (downtown and back), one ride anchor in each
--
-- Markers (folder "Markers"): every anchor, door, NPC spot, event spot and interact Config/World assigns to these
-- interiors (see each module's header). Bake-safe (contracts §15).

local Deps = require(script.Deps)
local CareerCenter = require(script.CareerCenter)
local Lecture = require(script.Lecture)
local Dorm = require(script.Dorm)
local Subway = require(script.Subway)

local Kit = Deps.Kit
local World = Deps.World

local CampusInteriors = {}

CampusInteriors.ZONES = { "career_center", "lecture", "dorm", "subway" }

local function settle(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Position = d.CFrame.Position
		end
	end
end

local function origin(id: string): Vector3
	return World.slotOrigin(World.interiors[id].slot)
end

function CampusInteriors.build(parent: Instance?): Model
	local root = Kit.model(nil, "CampusInteriors")
	local mk = Kit.folder(root, "Markers")
	CareerCenter.build(root, mk, origin("career_center"))
	Lecture.build(root, mk, origin("lecture"))
	Dorm.build(root, mk, origin("dorm"))
	Subway.build(root, mk, origin("subway"))
	settle(root)
	root.Parent = parent
	return root
end

return CampusInteriors
