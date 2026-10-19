--!strict
-- The Ashford Residences (venues feature; interior "apartments"): the Street's apartment building, where employed
-- players get a unit (HousingService, contracts §7). Three residential floors of eight units (24 UnitSlots,
-- numbered 1..24) along double-loaded corridors, joined by a U-stair in the stair hall, above a double-height
-- marble lobby with the concierge.
--
--   Plan     the floor plan (unit numbering, positions, the stair hall and lobby extents): pure numbers
--   Core     slabs, corridors (unit fronts with doorways), party walls, the stair hall
--   Lobby    the lobby, the street doors (door_apartments_exit), apartments_entry and npc_concierge
--   Unit     one apartment (see its header for the markers inside)
--
-- build(parent?) -> Model "Apartments" (attributes Interior, LightingPreset) with folders Markers and Units.
-- Bake-safe (contracts §15).

local Venue = script.Parent.CareerServices.Venue
local Deps = require(Venue.Deps)
local Shell = require(Venue.Shell)
local Plan = require(script.Plan)
local Core = require(script.Core)
local Lobby = require(script.Lobby)
local Unit = require(script.Unit)

local Kit = Deps.Kit

local Apartments = {}

Apartments.ZONE = "apartments"
Apartments.Plan = Plan
Apartments.SLOTS = Unit.SLOTS

local function origin(): Vector3
	return Deps.World.slotOrigin(Deps.World.interiors[Apartments.ZONE].slot)
end

function Apartments.build(parent: Instance?): Model
	local root = Kit.model(nil, "Apartments")
	root:SetAttribute("Interior", Apartments.ZONE)
	root:SetAttribute("LightingPreset", Deps.World.interiors[Apartments.ZONE].lighting)
	local mk = Kit.folder(root, "Markers")
	local o = origin()
	local F = Shell.frame(o)
	local rng = Deps.Rng.new("venue:apartments")
	Core.build(root, F, rng)
	Lobby.build(root, mk, F, rng)
	local units = Kit.folder(root, "Units")
	for _, spot in Plan.units() do
		Unit.build(units, CFrame.new(o) * spot.frame, spot.n, spot.level, Deps.Rng.new("apartment:" .. spot.n))
	end
	Shell.settle(root)
	root.Parent = parent
	return root
end

return Apartments
