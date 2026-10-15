--!strict
-- Pure math used by Kit components (no Instances, no services): chart scaling and segment geometry,
-- nice axis ticks, table column widths and slider snapping. Unit-tested under Lune.

local KitMath = {}

KitMath.MAX_POINTS = 240

export type Point = { x: number, y: number }
-- A straight line piece: centre (x, y), length and rotation in degrees (Frame.Rotation).
export type Segment = { x: number, y: number, length: number, angle: number }
export type Line = { points: { Point }, segments: { Segment } }
export type Layout = { lo: number, hi: number, lines: { Line }, baselineY: number? }
export type BoundsOpts = { baseline: number?, minY: number?, maxY: number?, pad: number? }

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end
KitMath.finite = finite

-- Keeps finite numbers only (accepts nil / garbage safely).
function KitMath.clean(points: any): { number }
	local out: { number } = {}
	if type(points) ~= "table" then
		return out
	end
	for _, v in ipairs(points) do
		if finite(v) then
			table.insert(out, v)
		end
	end
	return out
end

-- Reduces a series to at most maxPoints while keeping the first and last points and each bucket's
-- minimum and maximum (so spikes such as a flash crash survive).
function KitMath.downsample(points: { number }, maxPoints: number?): { number }
	local n = #points
	local m = math.max(4, maxPoints or KitMath.MAX_POINTS)
	if n <= m then
		return table.clone(points)
	end
	local out: { number } = { points[1] }
	local interior = n - 2
	local buckets = math.floor((m - 2) / 2)
	for b = 0, buckets - 1 do
		local s = 2 + math.floor(b * interior / buckets)
		local e = 1 + math.floor((b + 1) * interior / buckets)
		local minI, maxI = s, s
		for i = s, e do
			if points[i] < points[minI] then
				minI = i
			end
			if points[i] > points[maxI] then
				maxI = i
			end
		end
		if minI == maxI then
			table.insert(out, points[minI])
		elseif minI < maxI then
			table.insert(out, points[minI])
			table.insert(out, points[maxI])
		else
			table.insert(out, points[maxI])
			table.insert(out, points[minI])
		end
	end
	table.insert(out, points[n])
	return out
end

-- Y range covering every series (and the baseline), padded by `pad` (fraction of the range, default 0.08).
-- A flat range is widened so lines sit in the middle instead of dividing by zero.
function KitMath.bounds(series: { { number } }, opts: BoundsOpts?): (number, number)
	local o: BoundsOpts = opts or {}
	local lo, hi = math.huge, -math.huge
	for _, pts in series do
		for _, v in pts do
			if finite(v) then
				if v < lo then
					lo = v
				end
				if v > hi then
					hi = v
				end
			end
		end
	end
	local baseline = o.baseline
	if baseline ~= nil and finite(baseline) then
		lo = math.min(lo, baseline)
		hi = math.max(hi, baseline)
	end
	if lo == math.huge then
		lo, hi = 0, 1
	end
	local minY, maxY = o.minY, o.maxY
	if minY ~= nil and finite(minY) then
		lo = minY
	end
	if maxY ~= nil and finite(maxY) then
		hi = maxY
	end
	if hi < lo then
		lo, hi = hi, lo
	end
	local span = hi - lo
	if span < 1e-9 then
		local d = if math.abs(hi) > 1e-9 then math.abs(hi) * 0.05 else 1
		return lo - d, hi + d
	end
	local p = span * (o.pad or 0.08)
	if minY == nil then
		lo -= p
	end
	if maxY == nil then
		hi += p
	end
	return lo, hi
end

-- Pixel y for value v inside a plot of height h (0 at the top).
function KitMath.yFor(v: number, lo: number, hi: number, h: number): number
	local span = hi - lo
	if span <= 0 then
		return h / 2
	end
	return h - (v - lo) / span * h
end

-- Points evenly spaced across width w, scaled into height h.
function KitMath.project(points: { number }, w: number, h: number, lo: number, hi: number): { Point }
	local n = #points
	local out: { Point } = table.create(n)
	for i, v in points do
		local x = if n <= 1 then w / 2 else (i - 1) / (n - 1) * w
		out[i] = { x = x, y = KitMath.yFor(v, lo, hi, h) }
	end
	return out
end

function KitMath.segment(a: Point, b: Point): Segment
	local dx, dy = b.x - a.x, b.y - a.y
	return {
		x = (a.x + b.x) / 2,
		y = (a.y + b.y) / 2,
		length = math.sqrt(dx * dx + dy * dy),
		angle = math.deg(math.atan2(dy, dx)),
	}
end

function KitMath.segments(points: { Point }): { Segment }
	local out: { Segment } = {}
	for i = 2, #points do
		table.insert(out, KitMath.segment(points[i - 1], points[i]))
	end
	return out
end

-- Full chart layout: shared bounds, projected points and segments per series.
function KitMath.layout(series: { { number } }, w: number, h: number, opts: BoundsOpts?): Layout
	local cleaned: { { number } } = {}
	for i, pts in series do
		cleaned[i] = KitMath.downsample(KitMath.clean(pts), KitMath.MAX_POINTS)
	end
	local lo, hi = KitMath.bounds(cleaned, opts)
	local lines: { Line } = {}
	for i, pts in cleaned do
		local projected = KitMath.project(pts, w, h, lo, hi)
		lines[i] = { points = projected, segments = KitMath.segments(projected) }
	end
	local baselineY: number? = nil
	local baseline = opts and opts.baseline
	if baseline ~= nil and finite(baseline) then
		baselineY = KitMath.yFor(baseline, lo, hi, h)
	end
	return { lo = lo, hi = hi, lines = lines, baselineY = baselineY }
end

-- "Nice" step (1, 2, 5 x 10^k) for about `count` intervals over `range`.
function KitMath.niceStep(range: number, count: number): number
	if range <= 0 or not finite(range) then
		return 1
	end
	local raw = range / math.max(1, count)
	local mag = 10 ^ math.floor(math.log10(raw))
	local norm = raw / mag
	local step
	if norm < 1.5 then
		step = 1
	elseif norm < 3 then
		step = 2
	elseif norm < 7 then
		step = 5
	else
		step = 10
	end
	return step * mag
end

-- Tick values inside [lo, hi] on nice steps.
function KitMath.ticks(lo: number, hi: number, count: number): { number }
	local out: { number } = {}
	if not (finite(lo) and finite(hi)) or hi <= lo or count <= 0 then
		return out
	end
	local step = KitMath.niceStep(hi - lo, count)
	-- Decimals that represent the step exactly; used to snap away float noise (0.30000000000000004 -> 0.3).
	local decimals = math.clamp(math.ceil(-math.log10(step)) + 1, 0, 12)
	local first = math.ceil(lo / step - 1e-9)
	local guard = 0
	local i = first
	while guard < 64 do
		local v = i * step
		if v > hi + step * 1e-9 then
			break
		end
		local snapped = tonumber(string.format("%." .. decimals .. "f", v)) or v
		if math.abs(snapped) < step * 1e-9 then
			snapped = 0
		end
		table.insert(out, snapped)
		i += 1
		guard += 1
	end
	return out
end

-- Column widths for Table: width <= 1 is a scale fraction, > 1 is pixels, nil shares what's left.
-- Returns one UDim-like {scale, offset} per column; the columns exactly fill the row.
function KitMath.columnWidths(widths: { number? }, count: number): { { scale: number, offset: number } }
	local fixedPx, fixedScale, autoCount = 0, 0, 0
	for i = 1, count do
		local w = widths[i]
		if w == nil then
			autoCount += 1
		elseif w > 1 then
			fixedPx += w
		else
			fixedScale += w
		end
	end
	local out: { { scale: number, offset: number } } = {}
	local remainingScale = math.max(0, 1 - fixedScale)
	for i = 1, count do
		local w = widths[i]
		if w == nil then
			out[i] = { scale = remainingScale / autoCount, offset = -math.floor(fixedPx / autoCount + 0.5) }
		elseif w > 1 then
			out[i] = { scale = 0, offset = math.floor(w + 0.5) }
		else
			out[i] = { scale = w, offset = 0 }
		end
	end
	return out
end

-- Clamp v into [lo, hi] and round to the nearest step from lo (float noise removed).
function KitMath.snap(v: number, lo: number, hi: number, step: number?): number
	if not finite(v) then
		v = lo
	end
	local x = math.clamp(v, math.min(lo, hi), math.max(lo, hi))
	local s = step or 0
	if s > 0 then
		x = lo + math.floor((x - lo) / s + 0.5) * s
		x = math.clamp(x, math.min(lo, hi), math.max(lo, hi))
	end
	return math.floor(x * 1e6 + 0.5) / 1e6
end

-- Fraction (0..1) of v between lo and hi.
function KitMath.fraction(v: number, lo: number, hi: number): number
	if hi == lo then
		return 0
	end
	return math.clamp((v - lo) / (hi - lo), 0, 1)
end

return KitMath
