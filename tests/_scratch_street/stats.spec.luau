local Street = require(game:GetService("ServerStorage").WorldBuilders.Street)
return function(t)
	t.it("stats", function()
		local m = Street.build(Instance.new("Folder"))
		local lights, street, interior, lit, guis, emit = 0, 0, 0, 0, 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("Light") then lights += 1 end
			if d:HasTag("StreetLight") then street += 1 end
			if d:HasTag("InteriorLight") then interior += 1 end
			if d:HasTag("LitWindow") then lit += 1 end
			if d:IsA("SurfaceGui") then guis += 1 end
			if d:IsA("ParticleEmitter") then emit += 1 end
		end
		print("lights", lights, "StreetLight", street, "InteriorLight", interior, "LitWindow", lit, "SurfaceGuis", guis, "emitters", emit)
	end)
end
