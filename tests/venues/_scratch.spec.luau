local Builders = game:GetService("ServerStorage").WorldBuilders
local TARGET = "Apartments"
return function(t)
	t.it("dump", function()
		local B = require(Builders:FindFirstChild(TARGET) :: any)
		local m = B.build(Instance.new("Folder"))
		local out = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				local c = d.CFrame
				local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
				local shape = "Block"
				if d:IsA("Part") then
					shape = tostring(d.Shape):gsub("Enum.PartType.", "")
				elseif d:IsA("WedgePart") then
					shape = "Wedge"
				elseif d:IsA("CornerWedgePart") then
					shape = "CornerWedge"
				end
				local col = d.Color
				table.insert(out, string.format("DUMP|%s|%s|%.3f,%.3f,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.2f|%s|%s|%s", d.ClassName, shape, x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22, d.Size.X, d.Size.Y, d.Size.Z, col.R, col.G, col.B, d.Transparency, tostring(d.Material):gsub("Enum.Material.", ""), tostring(d.CanCollide), d.Name))
			end
		end
		print(table.concat(out, "\n"))
	end)
end
