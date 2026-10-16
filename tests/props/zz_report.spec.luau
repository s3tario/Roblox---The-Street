local Shared = game:GetService("ReplicatedStorage").Shared
local Props = require(Shared.Assets.Props)
local Common = require(Shared.Assets.Props.Common)
return function(t)
	local CF = CFrame.new(10, 2, 3)
	for _, info in Props.list() do
		local m = Props.build(info.id, nil, CF, { seed = 7 })
		local mn, mx = Common.localBounds(m, CF, m.PrimaryPart)
		local s = mx - mn
		local n = 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		local fp = info.footprint
		print(
			string.format(
				"%-22s fp %5.2f %5.2f %5.2f | got %5.2f %5.2f %5.2f | c %5.2f %5.2f | minY %5.2f | parts %d/%d",
				info.id,
				fp.X,
				fp.Y,
				fp.Z,
				s.X,
				mx.Y,
				s.Z,
				(mn.X + mx.X) / 2,
				(mn.Z + mx.Z) / 2,
				mn.Y,
				n,
				info.maxParts
			)
		)
	end
end
