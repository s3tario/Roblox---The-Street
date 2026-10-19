--!strict
-- The shared libraries the Eastbridge builders use (Campus and CampusInteriors, both owned by `campus`), required in
-- one place. World builders live in ServerStorage.WorldBuilders, so Shared is reached through ReplicatedStorage.
-- Builders only run at bake time (tools/bake) and in Lune tests. Bake-safe (contracts §15).
--
-- Logos may still be in progress elsewhere, so it is loaded guarded: Deps.logo(part, face, logoId) returns false
-- when the module is missing or errors, and callers fall back to painted text.

local Shared = game:GetService("ReplicatedStorage").Shared

local Kit = require(Shared.Build.Kit)
local Rng = require(Shared.Util.Rng)

export type RngT = Rng.Rng

local Deps = {
	Kit = Kit,
	Palette = require(Shared.Build.Palette),
	Rng = Rng,
	Hash = require(Shared.Util.Hash),
	World = require(Shared.Config.World),
	Props = require(Shared.Assets.Props),
	Signs = require(Shared.Assets.Signs),
	Gui = require(Shared.Assets.Props.Gui),
}

local logos: any = nil
do
	local assets = Shared:FindFirstChild("Assets")
	local mod = if assets then assets:FindFirstChild("Logos") else nil
	if mod then
		local ok, result = pcall(require, mod)
		if ok and type(result) == "table" then
			logos = result
		end
	end
end

-- Draws a logo / crest on a part face. Returns true when the Logos module drew it.
function Deps.logo(part: BasePart, face: Enum.NormalId, logoId: string, opts: { [string]: any }?): boolean
	if logos == nil or type(logos.surface) ~= "function" then
		return false
	end
	local ok = pcall(logos.surface, part, face, logoId, opts)
	return ok
end

return Deps
