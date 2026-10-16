--!strict
-- Campus props (category "campus"): gritty Eastbridge street furniture, yards and interiors.

local Common = require(script.Parent.Common)

local out: { Common.Def } = {}
local lists: { { Common.Def } } = {
	require(script.Outdoor),
	require(script.Yard),
	require(script.Indoor),
}
for _, list in lists do
	for _, d in list do
		table.insert(out, d)
	end
end
return out
