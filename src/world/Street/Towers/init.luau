--!strict
-- Company towers on the Street (Config/World.towers, design v3 §14 "Bank Row"). Every tower gets the lot the
-- Plan reserves for it (towers added to Config/World later take the spare lots in order), a facade in its style,
-- a lobby entrance with its door trigger (World.towers[i].door) and front anchor (World.towers[i].anchor), and its
-- branding: a CompanyLogo-tagged fascia for single-company towers, a building name and a tenant directory board for
-- multi-tenant towers. Unknown styles fall back to a glass curtain-wall tower, so new tracks plug in with data
-- only. Bake-safe.
--
--   Towers.build(parent, rects) -> (Model, { [towerId]: Model })
--   Towers.STYLES -> { [style]: builder }

local Deps = require(script.Parent.Deps)
local Plan = require(script.Parent.Plan)
local C = require(script.Common)
local Bank = require(script.Bank)
local Boutique = require(script.Boutique)
local Modern = require(script.Modern)
local Small = require(script.Small)

local Kit = Deps.Kit
local World = Deps.World

local Towers = {}

Towers.STYLES = {
	bulge = Bank.bulge,
	dark_glass = Bank.darkGlass,
	elite = Boutique.elite,
	regional = Boutique.regional,
	modern = Modern.modern,
	corporate = Modern.corporate,
	glass = Modern.glass,
	stone = Modern.stone,
	townhouse = Small.townhouse,
	loft = Small.loft,
	brick = Small.brick,
} :: { [string]: (C.Ctx) -> () }

function Towers.build(parent: Instance, rects: { Plan.Rect }): (Model, { [string]: Model })
	local m = Kit.model(parent, "Towers")
	local byId: { [string]: Model } = {}
	local towers = World.towers :: { C.TowerDef }
	local assigned = Plan.assignLots(towers)
	for _, def in towers do
		local lot = assigned[def.id]
		if lot then
			local ctx = C.new(m, def, lot, rects)
			local fn = Towers.STYLES[def.style] or Modern.glass
			fn(ctx)
			byId[def.id] = ctx.m
		else
			warn(("[Street] no lot left for tower %s: add one to Street/Plan.spareLots"):format(def.id))
		end
	end
	return m, byId
end

return Towers
