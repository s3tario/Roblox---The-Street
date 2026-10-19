--!strict
-- The shared libraries the Street builder uses, required in one place. World builders live in
-- ServerStorage.WorldBuilders, so Shared is reached through ReplicatedStorage. The builder only runs at bake time
-- (tools/bake) and in Lune tests; the baked result is Workspace.World.Street.
--
-- Libraries owned by other features that may still be in progress (logos, company and catalog config, NPC rigs)
-- are required through pcall: when one is missing or broken the Street still bakes, with text fallbacks.

local Shared = game:GetService("ReplicatedStorage").Shared

local function optional(container: Instance, name: string): any?
	local mod = container:FindFirstChild(name)
	if not mod then
		return nil
	end
	local ok, result = pcall(require, mod :: any)
	if ok then
		return result
	end
	warn(("[Street] optional module %s failed to load: %s"):format(name, tostring(result)))
	return nil
end

local Assets = Shared.Assets
local Config = Shared.Config
local NpcFolder = Assets:FindFirstChild("Npc")

return {
	Kit = require(Shared.Build.Kit),
	Palette = require(Shared.Build.Palette),
	Rng = require(Shared.Util.Rng),
	Hash = require(Shared.Util.Hash),
	World = require(Config.World),
	Props = require(Assets.Props),
	Signs = require(Assets.Signs),
	Gui = require(Assets.Props.Gui),
	-- optional (guarded)
	Logos = optional(Assets, "Logos"),
	Companies = optional(Config, "Companies"),
	Catalog = optional(Config, "Catalog"),
	NpcRig = if NpcFolder then optional(NpcFolder, "Rig") else nil,
}
