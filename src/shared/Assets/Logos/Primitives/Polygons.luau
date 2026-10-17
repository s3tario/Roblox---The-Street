--!strict
-- Logos primitives: straight-edged fills. A half-plane is a large frame rotated onto a line and cut by a clip
-- group; triangles and trapezoids are half-planes inside clip boxes that each hold one slanted edge.

local Core = require(script.Parent.Core)

type Canvas = Core.Canvas
type Group = Core.Group
type Opts = Core.Opts

local NO_OPTS = Core.NO_OPTS
local frame = Core.frame
local maskGradient = Core.maskGradient
local Shapes = require(script.Parent.Shapes)

local Polygons = {}

-- Fills the part of clip group `g` to the right of the directed line (x1, y1) -> (x2, y2). In screen
-- coordinates (y down) "right" of an eastward line is below it. A large frame rotated onto the line, cut by
-- the group: half-plane ∩ box is how triangles and trapezoids are built.
function Polygons.halfPlane(
	cv: Canvas,
	g: Group,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	color: Color3,
	opts: Opts?
): Frame?
	local o = opts or NO_OPTS
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 1e-6 then
		return nil
	end
	local nx, ny = -dy / len, dx / len
	local span = 2 * math.sqrt(g.w * g.w + g.h * g.h) + len
	local mx, my = (x1 + x2) / 2 + nx * span / 2, (y1 + y2) / 2 + ny * span / 2
	local f = frame(cv, { g = g, t = o.t, name = o.name }, mx - span / 2, my - span / 2, span, span, color)
	f.Rotation = math.deg(math.atan2(dy, dx))
	if o.colors then
		maskGradient(f, o, o.colors)
	end
	return f
end

local SEAM = 0.06 -- overlap between neighbouring clip boxes (units), hides scissor rounding seams

-- Triangle with its apex at (ax, ay) and a horizontal base from (x1, by) to (x2, by), x1 < x2. The apex may
-- sit above or below the base and anywhere along it (or past either end for a right triangle).
function Polygons.triangle(
	cv: Canvas,
	ax: number,
	ay: number,
	x1: number,
	x2: number,
	by: number,
	color: Color3,
	opts: Opts?
)
	local o = opts or NO_OPTS
	local parent = o.g or cv.top
	local top, bottom = math.min(ay, by), math.max(ay, by)
	if bottom - top < 1e-3 or x2 - x1 < 1e-3 then
		return
	end
	local up = ay < by
	local sub: Opts = { t = o.t, name = o.name, colors = o.colors, gradRot = o.gradRot }
	local mid = math.clamp(ax, x1, x2)
	if mid > x1 then
		local g = Core.clip(cv, x1, top, mid - x1 + SEAM, bottom - top, { g = parent, name = "Tri" })
		if up then
			Polygons.halfPlane(cv, g, x1, by, ax, ay, color, sub)
		else
			Polygons.halfPlane(cv, g, ax, ay, x1, by, color, sub)
		end
	end
	if mid < x2 then
		local g = Core.clip(cv, mid, top, x2 - mid, bottom - top, { g = parent, name = "Tri" })
		if up then
			Polygons.halfPlane(cv, g, ax, ay, x2, by, color, sub)
		else
			Polygons.halfPlane(cv, g, x2, by, ax, ay, color, sub)
		end
	end
end

-- Sideways triangle: apex at (ax, ay) and a vertical base from (bx, y1) to (bx, y2), y1 < y2.
function Polygons.triangleV(
	cv: Canvas,
	ax: number,
	ay: number,
	bx: number,
	y1: number,
	y2: number,
	color: Color3,
	opts: Opts?
)
	local o = opts or NO_OPTS
	local parent = o.g or cv.top
	local left, right = math.min(ax, bx), math.max(ax, bx)
	if right - left < 1e-3 or y2 - y1 < 1e-3 then
		return
	end
	local pointsRight = ax > bx
	local sub: Opts = { t = o.t, name = o.name, colors = o.colors, gradRot = o.gradRot }
	local mid = math.clamp(ay, y1, y2)
	if mid > y1 then
		local g = Core.clip(cv, left, y1, right - left, mid - y1 + SEAM, { g = parent, name = "Tri" })
		if pointsRight then
			Polygons.halfPlane(cv, g, bx, y1, ax, ay, color, sub)
		else
			Polygons.halfPlane(cv, g, ax, ay, bx, y1, color, sub)
		end
	end
	if mid < y2 then
		local g = Core.clip(cv, left, mid, right - left, y2 - mid, { g = parent, name = "Tri" })
		if pointsRight then
			Polygons.halfPlane(cv, g, ax, ay, bx, y2, color, sub)
		else
			Polygons.halfPlane(cv, g, bx, y2, ax, ay, color, sub)
		end
	end
end

-- Trapezoid with horizontal top (tx1..tx2 at ty) and bottom (bx1..bx2 at by) edges, ty < by.
function Polygons.trapezoid(
	cv: Canvas,
	tx1: number,
	tx2: number,
	ty: number,
	bx1: number,
	bx2: number,
	by: number,
	color: Color3,
	opts: Opts?
)
	local o = opts or NO_OPTS
	local parent = o.g or cv.top
	local h = by - ty
	if h < 1e-3 then
		return
	end
	local sub: Opts = { t = o.t, name = o.name }
	local innerL, innerR = math.max(tx1, bx1), math.min(tx2, bx2)
	local outerL, outerR = math.min(tx1, bx1), math.max(tx2, bx2)
	if innerR > innerL then
		Shapes.rect(cv, innerL, ty, innerR - innerL, h, color, { g = parent, t = o.t, name = o.name })
	end
	if innerL - outerL > 1e-3 then
		local g = Core.clip(cv, outerL, ty, innerL - outerL + SEAM, h, { g = parent, name = "Trap" })
		Polygons.halfPlane(cv, g, bx1, by, tx1, ty, color, sub)
	end
	if outerR - innerR > 1e-3 then
		local g = Core.clip(cv, innerR - SEAM, ty, outerR - innerR + SEAM, h, { g = parent, name = "Trap" })
		Polygons.halfPlane(cv, g, tx2, ty, bx2, by, color, sub)
	end
end

return Polygons
