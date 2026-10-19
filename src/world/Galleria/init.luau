--!strict
-- The Galleria (venues feature; interior "galleria"): the Street's shopping arcade. A marble atrium under a glass
-- barrel vault with four boutiques behind glazed shopfronts (v1 §9, contracts §7 shops):
--
--   west / north  Hartwell Tailors       (Shop "tailor", npc_tailor, suit racks, dressed mannequins, the fitting mirror)
--   west / south  Vanta Watches          (Shop "watch", npc_watchmaker, glass watch cases, the eyewear wall)
--   east / north  Strider Shoes          (Shop "shoes", npc_shoe_clerk, shoe walls, fitting benches)
--   east / south  Atelier Maison         (Shop "decor", npc_decorator, staged room vignettes)
--   south         the street doors (door_galleria_exit) and the arrival point (galleria_entry)
--
--   Plan      the floor plan and boutique frames (pure numbers)
--   Atrium    the shell, the vault and its painted sky, the atrium furnishings, entrance and markers
--   Boutique  the shared shopfront and shop shell, and the `shop` service-card interact
--   Tailor, Watches, Shoes, Maison   the four boutiques
--
-- build(parent?) -> Model "Galleria" (attributes Interior, LightingPreset) with a Markers folder. Bake-safe.

local Venue = script.Parent.CareerServices.Venue
local Deps = require(Venue.Deps)
local Shell = require(Venue.Shell)
local Plan = require(script.Plan)
local Atrium = require(script.Atrium)
local Tailor = require(script.Tailor)
local Watches = require(script.Watches)
local Shoes = require(script.Shoes)
local Maison = require(script.Maison)

local Kit = Deps.Kit

local Galleria = {}

Galleria.ZONE = "galleria"
Galleria.Plan = Plan
Galleria.LOOKS = Tailor.LOOKS

type Builder = (parent: Instance, mk: Instance, spot: Plan.ShopSpot, F: Shell.Frame, rng: Deps.RngT) -> Model

local SHOPS: { [string]: Builder } = {
	tailor = Tailor.build,
	watch = Watches.build,
	shoes = Shoes.build,
	decor = Maison.build,
}

local function origin(): Vector3
	return Deps.World.slotOrigin(Deps.World.interiors[Galleria.ZONE].slot)
end

function Galleria.build(parent: Instance?): Model
	local root = Kit.model(nil, "Galleria")
	root:SetAttribute("Interior", Galleria.ZONE)
	root:SetAttribute("LightingPreset", Deps.World.interiors[Galleria.ZONE].lighting)
	local mk = Kit.folder(root, "Markers")
	local F = Shell.frame(origin())
	local rng = Deps.Rng.new("venue:galleria")
	Atrium.build(root, mk, F, rng)
	local boutiques = Kit.folder(root, "Boutiques")
	for _, spot in Plan.shops do
		local build = SHOPS[spot.id]
		if build then
			build(boutiques, mk, spot, F, Deps.Rng.new("galleria:" .. spot.id))
		end
	end
	Shell.settle(root)
	root.Parent = parent
	return root
end

return Galleria
