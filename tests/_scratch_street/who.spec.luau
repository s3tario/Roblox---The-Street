local Street = require(game:GetService("ServerStorage").WorldBuilders.Street)
return function(t)
	t.it("who", function()
		local m = Street.build(Instance.new("Folder"))
		for _, pos in { Vector3.new(-100, 3.8, 86.6), Vector3.new(-100, 1.4, 86.6), Vector3.new(-100, 5.8, 86.6) } do
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") and p.CanCollide and p.Transparency < 1 then
					local l = p.CFrame:PointToObjectSpace(pos)
					local h = p.Size / 2
					if math.abs(l.X) < h.X and math.abs(l.Y) < h.Y and math.abs(l.Z) < h.Z then
						print(pos, p:GetFullName(), p.Size, p.CFrame.Position)
					end
				end
			end
		end
	end)
end
