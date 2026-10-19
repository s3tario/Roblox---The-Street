--!strict
-- The libraries the Eastbridge interiors use. They share the campus feature's helpers (Kit, Props, Signs, Paint, Text,
-- Markers, the guarded Logos loader) from the sibling Campus builder in ServerStorage.WorldBuilders. Bake-safe.

local Campus = script.Parent.Parent.Campus
local CampusDeps = require(Campus.Deps)

local Shared = game:GetService("ReplicatedStorage").Shared

export type RngT = CampusDeps.RngT

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

return Deps
