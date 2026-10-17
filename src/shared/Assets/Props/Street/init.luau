--!strict
-- Wall Street district props (category "street", polished). Vehicles live in ../Vehicles.luau.
--   Fixtures   lamps, traffic lights, benches, planter trees, bollards, flag poles, hydrants, manholes,
--              crosswalks
--   Amenities  parking meter, street clock, litter bin, tree grate, ATM
--   Kiosks     newsstand, food carts, revolving door, awning, phone booth, bike-share dock, scaffold
--   Landmarks  subway entrance, fountain, bull-and-bear sculpture

local Common = require(script.Parent.Common)

local out: { Common.Def } = {}
local lists: { { Common.Def } } = {
	require(script.Fixtures),
	require(script.Amenities),
	require(script.Kiosks),
	require(script.Landmarks),
}
for _, list in lists do
	for _, d in list do
		table.insert(out, d)
	end
end
return out
