--!strict
-- The shared libraries the office template builders use, required in one place. World builders live in
-- ServerStorage.WorldBuilders, so Shared is reached through ReplicatedStorage. Builders only run at bake time
-- (tools/bake) and in Lune tests; the baked templates are cloned at runtime by OfficeService.

local Shared = game:GetService("ReplicatedStorage").Shared

return {
	Kit = require(Shared.Build.Kit),
	Palette = require(Shared.Build.Palette),
	Rng = require(Shared.Util.Rng),
	Hash = require(Shared.Util.Hash),
	World = require(Shared.Config.World),
	Props = require(Shared.Assets.Props),
	Gui = require(Shared.Assets.Props.Gui),
	Words = require(Shared.Assets.Props.Words),
}
