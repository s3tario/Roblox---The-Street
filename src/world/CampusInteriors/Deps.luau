--!strict
-- The libraries the Eastbridge interiors use. They share the campus feature's helpers (Kit, Props, Signs, Paint, Text,
-- Markers, the guarded Logos loader) from the sibling Campus builder in ServerStorage.WorldBuilders. Bake-safe.
--
-- Config/Rarity and Config/Companies (careerCore, careerPath) are loaded guarded:
--   Deps.rarityColors() -> { Color3 }        the six tier colours (common .. mythic), else grey/green/blue/purple/
--                                            gold/prismatic
--   Deps.recruitingFirms(limit, fallback)    firms hiring now ({ id?, name, primary, text }), else the fallback names

local Campus = script.Parent.Parent.Campus
local CampusDeps = require(Campus.Deps)

local Shared = game:GetService("ReplicatedStorage").Shared

export type RngT = CampusDeps.RngT

local hex = CampusDeps.Palette.hex

local Deps = {
	Kit = CampusDeps.Kit,
	Palette = CampusDeps.Palette,
	Rng = CampusDeps.Rng,
	Hash = CampusDeps.Hash,
	World = CampusDeps.World,
	Props = CampusDeps.Props,
	Signs = CampusDeps.Signs,
	Gui = CampusDeps.Gui,
	logo = CampusDeps.logo,
	Paint = require(Campus.Paint),
	Text = require(Campus.Text),
	Markers = require(Campus.Markers),
	NpcRig = require(Shared.Assets.Npc.Rig),
}

local RARITY_FALLBACK = {
	hex("#9AA0A6"),
	hex("#4CAF50"),
	hex("#3D7BD9"),
	hex("#9C4DD9"),
	hex("#E3B341"),
	hex("#FF6FD8"),
}

local rarity: any = nil
do
	local config = Shared:FindFirstChild("Config")
	local mod = if config then config:FindFirstChild("Rarity") else nil
	if mod then
		local ok, result = pcall(require, mod :: any)
		if ok and type(result) == "table" then
			rarity = result
		end
	end
end

local companies: any = nil
do
	local config = Shared:FindFirstChild("Config")
	local mod = if config then config:FindFirstChild("Companies") else nil
	if mod then
		local ok, result = pcall(require, mod :: any)
		if ok and type(result) == "table" then
			companies = result
		end
	end
end

export type Firm = { id: string?, name: string, primary: Color3, text: Color3 }

-- Firms recruiting on campus right now (Config/Companies: available companies with at least one department, in
-- display order, at most `limit`), or the painted fallback names when the config is missing or broken.
function Deps.recruitingFirms(limit: number, fallback: { string }): { Firm }
	local out: { Firm } = {}
	if companies and type(companies.list) == "table" then
		pcall(function()
			for _, c in companies.list do
				if #out >= limit then
					break
				end
				local depts = c.departments
				if c.available ~= false and type(depts) == "table" and #depts > 0 and type(c.name) == "string" then
					local colors = if type(c.colors) == "table" then c.colors else {}
					table.insert(out, {
						id = if type(c.id) == "string" then c.id else nil,
						name = c.name,
						primary = if typeof(colors.primary) == "Color3" then colors.primary else hex("#1F2A44"),
						text = if typeof(colors.text) == "Color3" then colors.text else hex("#F4F1E6"),
					})
				end
			end
		end)
	end
	if #out == 0 then
		for i, name in fallback do
			if i > limit then
				break
			end
			table.insert(out, { id = nil, name = name, primary = hex("#1F2A44"), text = hex("#F4F1E6") })
		end
	end
	return out
end

-- The six rarity tier colours in order (common, uncommon, rare, epic, legendary, mythic).
function Deps.rarityColors(): { Color3 }
	local out: { Color3 } = table.clone(RARITY_FALLBACK)
	if rarity and type(rarity.list) == "table" then
		for i = 1, 6 do
			local def = rarity.list[i]
			if type(def) == "table" and typeof(def.color) == "Color3" then
				out[i] = def.color
			end
		end
	end
	return out
end

return Deps
