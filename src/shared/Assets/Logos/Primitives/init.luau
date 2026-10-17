--!strict
-- Logos: a small vector kit built from GUI objects only (Frames, UICorner, UIStroke, UIGradient, UIScale,
-- TextLabels). Bake-safe (contracts §15): no services, no clocks, no asset ids.
--
-- Every logo is drawn on a Canvas measured in abstract units (H = 100, W = 100 * aspect). Primitives take
-- unit coordinates and write Position/Size in scale space, so a logo looks identical at 64 px and 512 px.
-- Stroke widths are scale-correct too: UIStroke uses ScaledSize (a fraction of the frame's smaller side)
-- unless the canvas knows its exact pixel size (SurfaceGuis), in which case strokes are set in pixels.
--
-- Techniques
--   ring      a transparent circle with an inner UIStroke (the hole stays transparent)
--   arcs      a ring or disc with a hard-edged UIGradient transparency mask: `keep` lists the visible bands
--             along the mask direction (chord cuts, as in typeface terminals); clip groups mask rectangles
--   lens      a pointed petal/leaf: two disc segments meeting on the long axis (intersection of two discs)
--   shield    a rectangle over a lens: straight sides that curve into a point
--   peak      a rotated square inside a clip group (a triangle with the square's corner as its apex)
--   text      a TextLabel with TextScaled inside a UIScale, so glyphs can exceed the 100 px TextSize cap
--
-- Every GuiObject gets an increasing ZIndex (the canvas counter), so drawing order is painter's order in
-- both Sibling and Global ZIndexBehavior.
--
-- Folder module: Core (canvas, geometry, plumbing, groups, text), Shapes, Polygons (half-planes, triangles,
-- trapezoids) and Ornaments (stars, laurels). This file re-exports them as one typed table.

local Core = require(script.Core)
local Shapes = require(script.Shapes)
local Polygons = require(script.Polygons)
local Ornaments = require(script.Ornaments)

export type Group = Core.Group
export type Canvas = Core.Canvas
export type Opts = Core.Opts
export type Ctx = Core.Ctx
export type Spec = Core.Spec

local P = {
	new = Core.new,
	polar = Core.polar,
	bandSequence = Core.bandSequence,
	segmentEdge = Core.segmentEdge,
	colorGradient = Core.colorGradient,
	clip = Core.clip,
	layer = Core.layer,
	text = Core.text,
	rect = Shapes.rect,
	box = Shapes.box,
	frameOutline = Shapes.frameOutline,
	circle = Shapes.circle,
	dot = Shapes.dot,
	ring = Shapes.ring,
	ovalRing = Shapes.ovalRing,
	bar = Shapes.bar,
	polyline = Shapes.polyline,
	segment = Shapes.segment,
	lens = Shapes.lens,
	petal = Shapes.petal,
	diamond = Shapes.diamond,
	diamondRing = Shapes.diamondRing,
	octagon = Shapes.octagon,
	hexagon = Shapes.hexagon,
	shield = Shapes.shield,
	chevron = Shapes.chevron,
	peak = Shapes.peak,
	halfPlane = Polygons.halfPlane,
	triangle = Polygons.triangle,
	triangleV = Polygons.triangleV,
	trapezoid = Polygons.trapezoid,
	star = Ornaments.star,
	sparkle = Ornaments.sparkle,
	arcDots = Ornaments.arcDots,
	laurel = Ornaments.laurel,
}

return P
