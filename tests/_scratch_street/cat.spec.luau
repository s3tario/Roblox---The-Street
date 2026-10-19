local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Config.Catalog)
return function(t)
	t.it("cat", function()
		local items = Catalog.items or Catalog.list
		local n = 0
		for k, v in (items :: any) do
			local it = if type(v) == "table" then v else nil
			if it and (it.tier or 0) >= 4 then
				n += 1
				print(it.id, it.slot, it.tier, it.currency, it.rarity, it.brand, it.name)
			end
		end
		print("n", n)
	end)
end
