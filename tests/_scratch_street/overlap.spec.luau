local Street = require(game:GetService("ServerStorage").WorldBuilders.Street)
return function(t)
	t.it("overlap", function()
		local m = Street.build(Instance.new("Folder"))
		local solids = {}
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p.CanCollide and p.Transparency < 1 then
				table.insert(solids, p)
			end
		end
		local bad = 0
		for _, d in m:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("PropId") and d:GetAttribute("PropMount") ~= "wall" then
				local root = d:FindFirstChild("Root") :: BasePart
				local base = root.CFrame.Position
				for _, dy in { 0.8, 2.5 } do
					local pos = base + Vector3.new(0, dy, 0)
					for _, s in solids do
						if not s:IsDescendantOf(d) then
							local l = s.CFrame:PointToObjectSpace(pos)
							local h = s.Size / 2
							if math.abs(l.X) < h.X - 0.05 and math.abs(l.Y) < h.Y - 0.05 and math.abs(l.Z) < h.Z - 0.05 then
								bad += 1
								print(d:GetAttribute("PropId"), d:GetFullName(), base, "inside", s:GetFullName())
								break
							end
						end
					end
				end
			end
		end
		print("bad", bad)
	end)
end
