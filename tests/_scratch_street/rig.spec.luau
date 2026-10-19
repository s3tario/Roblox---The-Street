local Shared = game:GetService("ReplicatedStorage").Shared
local NpcRig = require(Shared.Assets.Npc.Rig)
local Kit = require(Shared.Build.Kit)
local Catalog = require(Shared.Config.Catalog)
local Logos = require(Shared.Assets.Logos)
return function(t)
	t.it("dump", function()
		local looks = {
			{ outer = "bespoke_midnight_2b", top = "shirt_bespoke", bottom = "bespoke_midnight_trousers", shoes = "oxford_bespoke_black", neck = "tie_bar_gold", wrist = "watch_astra_moonphase" },
			{ top = "blouse_couture", bottom = "trousers_couture_wide", shoes = "heels_couture", eyes = "aviators_gold" },
		}
		for _, eq in looks do
			for slot, id in eq do
				if not Catalog.get(id) then print("MISSING", id) end
			end
			local m = NpcRig.build({ name = "Mannequin", equipped = eq, humanoid = false, face = false, hairStyle = "none", cframe = CFrame.new(0, 0, 0), skin = Color3.fromRGB(235,235,232) })
			print("parts", Kit.countParts(m))
			local kinds = {}
			for _, d in m:GetDescendants() do kinds[d.ClassName] = (kinds[d.ClassName] or 0) + 1 end
			for k, v in kinds do print(k, v) end
		end
		for _, id in { "mg_freeman", "goldfield_saxe", "anaeio", "applewood", "sterling_vance", "lazaro_freres" } do
			print(id, Logos.has(id), Logos.aspect(id))
		end
	end)
end
