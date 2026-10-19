--!strict
-- What the lobby builder shares with the department floors (both modules belong to officesA): the shared libraries
-- (through OfficeFloorsA/Deps), the geometry, marker, artwork and furniture helpers, the template Root and the
-- painted skyline, and the one table of player-facing template text. Bake-safe.

local Floors = script.Parent.Parent.OfficeFloorsA

local Base = require(Floors.Deps)

return {
	Kit = Base.Kit,
	Palette = Base.Palette,
	Rng = Base.Rng,
	Hash = Base.Hash,
	World = Base.World,
	Props = Base.Props,
	Gui = Base.Gui,
	Geo = require(Floors.Geo),
	Art = require(Floors.Art),
	Markers = require(Floors.Markers),
	Text = require(Floors.Text),
	Furniture = require(Floors.Furniture),
	Shell = require(Floors.Shell),
	Style = require(Floors.Style),
	Core = require(Floors.Core), -- Core.logoPanel / Core.nameBand: the branded parts OfficeService re-skins
}
