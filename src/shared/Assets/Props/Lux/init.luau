--!strict
-- Luxury interiors (category "lux") for the Executive Club, MD offices and penthouses.
--   Bar     bar counter, bar stool, wine rack, cigar humidor, velvet rope
--   Lounge  chandelier, chesterfield, fireplace, pool table, grand piano, art pedestal, lounge chair

local Common = require(script.Parent.Common)

local out: { Common.Def } = {}
local lists: { { Common.Def } } = {
	require(script.Bar),
	require(script.Lounge),
}
for _, list in lists do
	for _, d in list do
		table.insert(out, d)
	end
end
return out
