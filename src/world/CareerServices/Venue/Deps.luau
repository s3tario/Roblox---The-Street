--!strict
-- The libraries the five venue builders (venues feature: CareerServices, ExecClub, Rooftop, Apartments, Galleria)
-- share, required in one place. World builders live in ServerStorage.WorldBuilders, so Shared is reached through
-- ReplicatedStorage. They only run at bake time (tools/bake) and in Lune tests. Bake-safe (contracts §15).
--
-- Libraries owned by features that may still be in progress (logos, the catalog, NPC rigs) are loaded through pcall:
-- when one is missing or broken the venues still bake, with painted-text and dress-form fallbacks.
--
--   Deps.logo(part, face, logoId, opts?) -> boolean       true when Shared/Assets/Logos drew the mark
--   Deps.hasLogo(logoId) -> boolean                        Logos has a designed mark (not just a generated monogram)
--   Deps.known(equipped) -> equipped                       only the Catalog ids that exist
--   Deps.mannequin(parent, cf, equipped, name) -> Model     an anchored, non-colliding display figure (NpcRig +
--                                                          Wardrobe), or a plain dress form when rigs are missing
--   Deps.rarityColors() -> { Color3 }                      common .. mythic (Config/Rarity, else the fallback set)

local Shared = game:GetService("ReplicatedStorage").Shared

local function optional(container: Instance?, name: string): any?
	if container == nil then
		return nil
	end
	local mod = container:FindFirstChild(name)
	if not mod then
		return nil
	end
	local ok, result = pcall(require, mod :: any)
	if ok then
		return result
	end
	warn(("[Venues] optional module %s failed to load: %s"):format(name, tostring(result)))
	return nil
end

local RngModule = require(Shared.Util.Rng)
export type RngT = RngModule.Rng

local Kit = require(Shared.Build.Kit)
local Palette = require(Shared.Build.Palette)
local Assets = Shared.Assets
local Config = Shared.Config

local Deps = {
	Kit = Kit,
	Palette = Palette,
	Rng = RngModule,
	Hash = require(Shared.Util.Hash),
	World = require(Config.World),
	Props = require(Assets.Props),
	Signs = require(Assets.Signs),
	Gui = require(Assets.Props.Gui),
	-- optional (guarded)
	Logos = optional(Assets, "Logos"),
	Catalog = optional(Config, "Catalog"),
	Rarity = optional(Config, "Rarity"),
	NpcRig = optional(Assets:FindFirstChild("Npc"), "Rig"),
}

-- True when Shared/Assets/Logos has a designed mark for logoId (it draws a generic monogram for unknown ids, so
-- callers with their own fallback check this first).
function Deps.hasLogo(logoId: string): boolean
	local Logos = Deps.Logos
	if Logos == nil or type(Logos.has) ~= "function" then
		return false
	end
	local ok, has = pcall(Logos.has, logoId)
	return ok and has == true
end

function Deps.logo(part: BasePart, face: Enum.NormalId, logoId: string, opts: { [string]: any }?): boolean
	local Logos = Deps.Logos
	if Logos == nil or type(Logos.surface) ~= "function" then
		return false
	end
	local ok = pcall(Logos.surface, part, face, logoId, opts)
	return ok
end

-- Only pieces the Catalog knows (it may change): an unknown id would make Wardrobe.apply warn.
function Deps.known(equipped: { [string]: string }): { [string]: string }
	local Catalog = Deps.Catalog
	if Catalog == nil or type(Catalog.get) ~= "function" then
		return {}
	end
	local out: { [string]: string } = {}
	for slot, id in equipped do
		local ok, item = pcall(Catalog.get, id)
		if ok and item ~= nil then
			out[slot] = id
		end
	end
	return out
end

local MANNEQUIN = Palette.hex("#ECEBE6")

-- A display figure standing on `cf` (the floor point, facing cf.LookVector). Everything is anchored and passive, so
-- shoppers walk around it and nothing ever moves at runtime.
function Deps.mannequin(parent: Instance, cf: CFrame, equipped: { [string]: string }, name: string): Model
	local NpcRig = Deps.NpcRig
	if NpcRig and type(NpcRig.build) == "function" then
		local ok, model = pcall(NpcRig.build, {
			name = name,
			equipped = Deps.known(equipped),
			humanoid = false,
			face = false,
			hairStyle = "none",
			skin = MANNEQUIN,
			pose = "stand",
			cframe = cf,
			anchored = true,
			seed = name,
		})
		if ok and typeof(model) == "Instance" and model:IsA("Model") then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
				elseif d:IsA("Humanoid") then
					d:Destroy()
				end
			end
			model:SetAttribute("Mannequin", true)
			model.Parent = parent
			return model
		end
		warn("[Venues] mannequin rig failed: " .. tostring(model))
	end
	-- fallback dress form: pole, torso and head
	local g = Kit.model(parent, name)
	g:SetAttribute("Mannequin", true)
	Kit.cylinder(g, cf * CFrame.new(0, 1.6, 0), 3.2, 0.3, Palette.street.brass, Enum.Material.Metal, {
		CanCollide = false,
	})
	Kit.detail(g, cf * CFrame.new(0, 4.2, 0), Vector3.new(2, 2.4, 1.1), Palette.street.navy, Enum.Material.Fabric)
	Kit.ball(g, cf * CFrame.new(0, 5.9, 0), 1, MANNEQUIN, Enum.Material.SmoothPlastic, { CanCollide = false })
	return g
end

local hex = Palette.hex
local RARITY_FALLBACK = {
	hex("#9AA0A6"),
	hex("#4CAF50"),
	hex("#3D7BD9"),
	hex("#9C4DD9"),
	hex("#E3B341"),
	hex("#FF6FD8"),
}

function Deps.rarityColors(): { Color3 }
	local out: { Color3 } = table.clone(RARITY_FALLBACK)
	local rarity = Deps.Rarity
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
