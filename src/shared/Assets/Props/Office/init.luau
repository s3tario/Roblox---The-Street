--!strict
-- Office props (category "office"): desks, seating, screens, furniture and building fixtures.

local Common = require(script.Parent.Common)

local out: { Common.Def } = {}
local lists: { { Common.Def } } = {
	require(script.Desks),
	require(script.Seating),
	require(script.Tech),
	require(script.Furniture),
	require(script.Fixtures),
}
for _, list in lists do
	for _, d in list do
		table.insert(out, d)
	end
end
return out
