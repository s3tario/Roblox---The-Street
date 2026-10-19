local Kit = require(game:GetService("ReplicatedStorage").Shared.Build.Kit)
local Street = require(game:GetService("ServerStorage").WorldBuilders.Street)
return function(t)
	t.it("count", function()
		local m = Street.build(Instance.new("Folder"))
		local function dump(inst, depth)
			for _, c in inst:GetChildren() do
				local n = Kit.countParts(c)
				if n >= 20 then
					print(string.rep("  ", depth) .. c.Name, n)
					if depth < 1 then dump(c, depth + 1) end
				end
			end
		end
		dump(m, 0)
		print("TOTAL", Kit.countParts(m))
	end)
end
