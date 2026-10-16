--!strict
-- SurfaceGui content for props and signs (no image ids; Frames and TextLabels only). Bake-safe.
--   Gui.Core     primitives: surface, frame, px, dot, line, label, gradients; fake market data and charts
--   Gui.Screens  monitor screens and LED tickers
--   Gui.Art      paintings, boards, clocks, posters, ads, flags, rugs, photos, menus

local Core = require(script.Core)
local Screens = require(script.Screens)
local Art = require(script.Art)

return {
	Core = Core,
	Screens = Screens,
	Art = Art,
}
