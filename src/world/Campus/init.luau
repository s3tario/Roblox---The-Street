--!strict
-- Campus (campus feature; v1 §9, v3 §19 M1): Eastbridge, the gritty college town on the edge of the city and the
-- tutorial world. Baked into Workspace.World by tools/bake (region "campus", budget in Config/World.builders).
--
--   build(parent?) -> Model "Campus"
--
-- Layout and every shared coordinate: Plan. Pieces: Ground (streets, sidewalks, river, boundary walls), University
-- (Halvorsen Hall, the Career Center, Marlow House, the quad), Strip (the avenue's shops: diner, laundromat, pawn,
-- Grind House, the vacant block, the Eastbridge Co-op), Depot (bus depot, spawn), Lot (construction lot and the back
-- alley), East (the elevated line, Eastbridge Station, storage, hardware, court, parking, the overlook), Backdrop (the
-- town beyond the boundary and the hazy Wall Street skyline), Streetscape (lamps, poles, wires, signs, cars, clutter).
--
-- Markers (Config/World; folder "Markers"): SpawnLocation Spawn_campus at the depot's boarding island (anchor
-- campus_spawn), the campus_* anchors, the four campus doors, NPC spots npc_alum / npc_barista / npc_bus_driver,
-- event spots muster_campus / recruiting_booths / pigeon_area_campus / briefcase_c1 / briefcase_c2, and the exterior
-- interacts: shop (Shop = "campus_store", the Co-op counter), bulletin (the recruiting board by the Career Center),
-- store_kiosk (the depot), leaderboard (BoardId "CareerPrestige", part "Screen"), company_directory (the station's
-- info kiosk). Bake-safe (contracts §15).

local Deps = require(script.Deps)
local Plan = require(script.Plan)
local Geo = require(script.Geo)
local Markers = require(script.Markers)
local Ground = require(script.Ground)
local University = require(script.University)
local Strip = require(script.Strip)
local Depot = require(script.Depot)
local Lot = require(script.Lot)
local East = require(script.East)
local Backdrop = require(script.Backdrop)
local Streetscape = require(script.Streetscape)

local Kit = Deps.Kit

local Campus = {}

local function markers(root: Instance): Folder
	local mk = Kit.folder(root, "Markers")
	for id, cf in Plan.anchors do
		Markers.anchor(mk, id, cf)
	end
	for id, cf in Plan.npcs do
		Markers.npc(mk, id, cf)
	end
	for id, e in Plan.events do
		Markers.event(mk, id, e.cf, e.size)
	end
	local sp = Plan.depot.spawn
	Kit.spawn(mk, "Spawn_campus", Plan.cf(sp.x, Plan.depot.island.top + 0.1, sp.z, Plan.E))
	return mk
end

function Campus.build(parent: Instance?): Model
	local root = Kit.model(nil, "Campus")
	root:SetAttribute("Region", "campus")
	root:SetAttribute("LightingPreset", "campus_exterior")
	local mk = markers(root)
	Ground.build(root)
	University.build(root, mk)
	Strip.build(root, mk)
	Depot.build(root, mk)
	Lot.build(root)
	East.build(root, mk)
	Backdrop.build(root)
	Streetscape.build(root)
	Geo.settle(root)
	root.Parent = parent
	return root
end

return Campus
