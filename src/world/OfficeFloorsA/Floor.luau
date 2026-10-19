--!strict
-- Assembles one department floor template from the shared plan (Layout) in a given style, with every marker the
-- office system needs (contracts §11; Config/World templateMarkers / floorSlots / templateEventSpots):
--   root Model <templateId>: PrimaryPart "Root" at the origin; attributes LightingPreset, Department, Template
--   24 DeskSlot models, 8 OfficeSlot models, the boss office (boss_chair, review_spot, boss_review)
--   OfficeAnchor floor_entry (by the elevators) and rival_desk; OfficeDoor to_lobby at the elevators
--   interacts work_desk, terminal, project_desk, boss_review, housing_panel
--   EventSpots pizza_table, ceo_path_1..4, fire_alarm, briefcase_office
-- Bake-safe.

local Deps = require(script.Parent.Deps)
local Layout = require(script.Parent.Layout)
local Markers = require(script.Parent.Markers)
local Shell = require(script.Parent.Shell)
local Ceiling = require(script.Parent.Ceiling)
local Desks = require(script.Parent.Desks)
local Offices = require(script.Parent.Offices)
local Rooms = require(script.Parent.Rooms)
local Core = require(script.Parent.Core)
local Style = require(script.Parent.Style)

local Kit = Deps.Kit

local Floor = {}

export type FloorOpts = {
	lighting: string?,
}

function Floor.build(templateId: string, parent: Instance?, style: Style.Style, opts: FloorOpts?): Model
	local o: FloorOpts = opts or {}
	local root = Kit.model(nil, templateId)
	Shell.root(root)
	root:SetAttribute("LightingPreset", o.lighting or "office_interior")
	root:SetAttribute("Department", templateId)
	root:SetAttribute("Template", templateId)
	root:SetAttribute("FloorStyle", style.id)

	Shell.build(root, style, "floor:" .. templateId)
	Ceiling.build(root, style)
	Desks.build(root, style)
	local offices = Kit.folder(root, "Offices")
	for i, cf in Layout.offices() do
		Offices.private(offices, i, cf, style)
	end
	Offices.boss(root, style)
	Rooms.conference(root, style)
	Rooms.huddles(root, style)
	Rooms.lounge(root, style)
	Rooms.rivalDesk(root, style)
	Rooms.openPlan(root, style)
	Core.lobby(root, style)
	Core.pantry(root, style)

	-- markers
	local mk = Kit.folder(root, "Markers")
	Markers.anchor(mk, "floor_entry", Layout.anchors.floor_entry)
	Markers.anchor(mk, "rival_desk", Layout.anchors.rival_desk)
	Markers.door(mk, "to_lobby", Layout.toLobby, Layout.TO_LOBBY_SIZE)
	for i, p in Layout.ceoPath do
		local nextP = Layout.ceoPath[i % #Layout.ceoPath + 1]
		Markers.eventSpot(mk, "ceo_path_" .. i, CFrame.lookAt(p, Vector3.new(nextP.X, p.Y, nextP.Z)))
	end
	local t = Layout.pantryTable
	Markers.eventSpot(mk, "pizza_table", CFrame.new(t.X, t.Y + 0.2, t.Z), Vector3.new(8, 0.4, 3))
	Markers.eventSpot(mk, "fire_alarm", Layout.fireAlarm, Vector3.new(1, 1, 1))
	Markers.eventSpot(mk, "briefcase_office", CFrame.new(Layout.briefcase), Vector3.new(2, 1, 2))

	root.Parent = parent
	return root
end

return Floor
