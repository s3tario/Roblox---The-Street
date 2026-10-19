--!strict
-- OfficeLobby (officesA; design v3 §14, §19 M1; contracts §11): the company lobby template, baked into
-- build/Templates.rbxm (ServerStorage.FirmTemplates.lobby) and cloned per company at runtime by OfficeService, which
-- brands it (CompanyLogo panels, CompanyName labels, FirmColor / FirmAccent parts).
--
--   build("lobby", parent?) -> Model     the lobby built around the origin (World.TEMPLATE_HALF bounds)
--   TEMPLATES                            the template ids this module builds (= Config/World.templates entry)
--
-- The root Model "lobby": PrimaryPart "Root" at the origin; attributes LightingPreset = "office_interior",
-- Template = "lobby". Markers (contracts §11; Config/World.templateMarkers):
--   OfficeAnchor entry (just inside the revolving door, facing in), elevators (in the elevator hall),
--   receptionist (behind the reception desk); OfficeDoor exit (the revolving door); elevator_panel interacts on the
--   call-button panels.
-- Layout: Plan. Pieces: Hall (shell + facade), Brand (logo wall, reception, chandelier, banners), Elevators (gates + hall),
-- Lounge (lounge, vitrine, café, waiting area, planters), Street (the painted view). Bake-safe.

local Deps = require(script.Deps)
local Plan = require(script.Plan)
local Hall = require(script.Hall)
local Brand = require(script.Brand)
local Elevators = require(script.Elevators)
local Lounge = require(script.Lounge)
local Street = require(script.Street)

local Kit = Deps.Kit
local Markers = Deps.Markers

local OfficeLobby = {}

OfficeLobby.TEMPLATES = { "lobby" }

local function build(): Model
	local root = Kit.model(nil, "lobby")
	Deps.Shell.root(root)
	root:SetAttribute("LightingPreset", "office_interior")
	root:SetAttribute("Template", "lobby")

	Hall.build(root)
	Street.build(root)
	Brand.logoWall(root)
	Brand.reception(root)
	Brand.chandelier(root)
	Brand.banners(root)
	Elevators.gates(root)
	Elevators.hall(root)
	local dressing = Kit.folder(root, "Dressing")
	Lounge.lounge(dressing)
	Lounge.vitrine(dressing)
	Lounge.cafe(dressing)
	Lounge.waiting(dressing)
	Lounge.plants(dressing)

	local mk = Kit.folder(root, "Markers")
	for _, id in { "entry", "elevators", "receptionist" } do
		Markers.anchor(mk, id, Plan.anchors[id])
	end
	Markers.door(mk, "exit", Plan.exitDoor, Plan.EXIT_SIZE)
	return root
end

function OfficeLobby.build(templateId: string, parent: Instance?): Model
	if templateId ~= "lobby" then
		error("OfficeLobby: unknown template " .. tostring(templateId), 2)
	end
	local root = build()
	Deps.Geo.settle(root)
	root.Parent = parent
	return root
end

return OfficeLobby
