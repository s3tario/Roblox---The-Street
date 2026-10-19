local Shared = game:GetService("ReplicatedStorage").Shared
local Props = require(Shared.Assets.Props)
return function(t)
	t.it("list", function()
		for _, i in Props.list() do
			print(string.format("%-26s %-10s fp=%-22s max=%4d mount=%s tags=%s", i.id, i.category, tostring(i.footprint), i.maxParts, i.mount, table.concat(i.tags, ",")))
		end
	end)
end
