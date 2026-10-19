--!strict
-- SurfaceGui painters for Eastbridge: the details that would cost thousands of parts if modelled, drawn on the faces
-- of parts that already exist (Frames and TextLabels only, no image ids). Bake-safe (contracts §15).
--
--   Paint.surface(part, face, pps?, opts?) -> (gui, W, H)     Gui.Core.surface with campus defaults
--   Paint.windows(gui, W, H, rng, o)          painted window grid for secondary facades (sills, lit/boarded panes)
--   Paint.grime(gui, W, H, rng, o?)           rain streaks, soot band at the base, damp patches
--   Paint.graffiti(gui, W, H, rng, text, o?)  spray-painted tag (marker font, outline, drips)
--   Paint.ghostSign(gui, text, sub?, o?)      a faded hand-painted advert on brick
--   Paint.skyline(gui, W, H, rng, o)          layered city skyline silhouettes (hazy, lit windows, spires)
--   Paint.townscape(gui, W, H, rng, o?)       distant low-rise rooftops, water towers and bare trees
--   Paint.view(gui, W, H, rng, kind)          faked window views: "campus" | "night" | "river" | "tunnel"
--   Paint.muntins(gui, cols, rows, color, t?) sash bars over a window pane
--   Paint.cracks(gui, W, H, rng, n, o?)       hairline cracks on asphalt / concrete
--   Paint.flyers(gui, W, H, rng, texts)       a collage of stapled paper flyers

local Deps = require(script.Parent.Deps)

local Gui = Deps.Gui
local Core = Gui.Core
local hex = Deps.Palette.hex
local C = Deps.Palette.campus

local Paint = {}

local frame = Core.frame
local px = Core.px
local label = Core.label

export type SurfOpts = { glow: boolean?, brightness: number?, pps: number?, maxDistance: number?, name: string? }

-- Small surfaces (flyers, signs, trim) stop drawing beyond CULL studs unless opts.maxDistance says otherwise; big
-- facades and backdrops always draw.
local CULL = 240

function Paint.surface(part: BasePart, face: Enum.NormalId, pps: number?, opts: SurfOpts?): (SurfaceGui, number, number)
	local o: SurfOpts = if opts then table.clone(opts) else {}
	o.pps = pps or o.pps or 8
	if o.maxDistance == nil then
		local s = part.Size
		local area = if face == Enum.NormalId.Front or face == Enum.NormalId.Back
			then s.X * s.Y
			elseif face == Enum.NormalId.Left or face == Enum.NormalId.Right then s.Z * s.Y
			else s.X * s.Z
		o.maxDistance = if area < 600 then CULL else 0
	end
	return Core.surface(part, face, o)
end

---------------------------------------------------------------------------------------------------
-- Facades
---------------------------------------------------------------------------------------------------
export type WindowOpts = {
	cols: number,
	rows: number,
	marginX: number?, -- fraction of the width kept clear at each side
	top: number?, -- fraction of the height above the top row
	bottom: number?, -- fraction of the height below the bottom row (ground floor)
	winW: number?, -- window width as a fraction of a bay
	winH: number?, -- window height as a fraction of a storey
	lit: number?, -- chance a pane is lit
	boarded: number?, -- chance a pane is boarded
	frame: Color3?,
	sill: Color3?,
	glass: Color3?,
	litColor: Color3?,
	acUnits: number?, -- chance of a window AC box
}

function Paint.windows(gui: Instance, W: number, H: number, rng: Deps.RngT, o: WindowOpts)
	local mx = o.marginX or 0.06
	local top = o.top or 0.08
	local bottom = o.bottom or 0.12
	local bayW = W * (1 - mx * 2) / o.cols
	local storey = H * (1 - top - bottom) / o.rows
	local ww = bayW * (o.winW or 0.55)
	local wh = storey * (o.winH or 0.6)
	local glass = o.glass or C.windowDim
	local lit = o.litColor or C.windowWarm
	local fr = o.frame or hex("#2B2622")
	local sill = o.sill or C.mortar
	for r = 0, o.rows - 1 do
		for c = 0, o.cols - 1 do
			local x = W * mx + bayW * c + (bayW - ww) / 2
			local y = H * top + storey * r + (storey - wh) * 0.4
			-- lintel, frame, pane, sill
			px(gui, x - ww * 0.06, y - wh * 0.1, ww * 1.12, wh * 0.08, sill, 0.1)
			px(gui, x - 2, y - 2, ww + 4, wh + 4, fr)
			local roll = rng:next()
			local pane: Color3
			if roll < (o.boarded or 0) then
				pane = hex("#7A6650")
			elseif roll < (o.boarded or 0) + (o.lit or 0.15) then
				pane = lit:Lerp(glass, rng:range(0, 0.3))
			else
				pane = glass:Lerp(hex("#1A1D20"), rng:range(0, 0.5))
			end
			local p = px(gui, x, y, ww, wh, pane)
			-- sash bar and a drawn blind on some panes
			px(p, 0, wh * 0.48, ww, math.max(2, wh * 0.04), fr)
			if rng:chance(0.35) then
				px(p, 0, 0, ww, wh * rng:range(0.15, 0.45), hex("#CFC4A8"), 0.25)
			end
			px(gui, x - ww * 0.08, y + wh, ww * 1.16, wh * 0.07, sill)
			if o.acUnits and rng:chance(o.acUnits) then
				px(gui, x + ww * 0.2, y + wh * 0.62, ww * 0.6, wh * 0.36, hex("#B9B4A6"))
			end
		end
	end
end

export type GrimeOpts = { streaks: number?, soot: number?, color: Color3? }

function Paint.grime(gui: Instance, W: number, H: number, rng: Deps.RngT, o: GrimeOpts?)
	local opts: GrimeOpts = o or {}
	local dark = opts.color or hex("#1E1A16")
	-- soot band rising from the ground
	local band = frame(gui, 0, 1 - (opts.soot or 0.12), 1, opts.soot or 0.12, dark, 0.55)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new(1, 0.3)
	g.Parent = band
	-- rain streaks from the cornice and sills
	for _ = 1, opts.streaks or 10 do
		local x = rng:range(0.02, 0.96)
		local len = rng:range(0.12, 0.45)
		local y0 = rng:range(0, 0.5)
		local s = frame(gui, x, y0, rng:range(0.004, 0.018), len, dark, rng:range(0.55, 0.8))
		local sg = Instance.new("UIGradient")
		sg.Rotation = 90
		sg.Transparency = NumberSequence.new(0.2, 1)
		sg.Parent = s
	end
	-- damp / efflorescence patches
	for _ = 1, rng:int(1, 3) do
		local d = frame(
			gui,
			rng:range(0, 0.85),
			rng:range(0.5, 0.85),
			rng:range(0.06, 0.15),
			rng:range(0.05, 0.12),
			hex("#D8D2C2"),
			0.8
		)
		Core.round(d, 0.5)
	end
end

export type GraffitiOpts = {
	x: number?,
	y: number?,
	w: number?,
	h: number?,
	color: Color3?,
	outline: Color3?,
	font: Enum.Font?,
}

function Paint.graffiti(gui: Instance, W: number, H: number, rng: Deps.RngT, text: string, o: GraffitiOpts?)
	local opts: GraffitiOpts = o or {}
	local colors = { C.graffitiTeal, C.graffitiMagenta, hex("#E2B93B"), hex("#E8E4DA"), hex("#C8553D") }
	local col = opts.color or rng:pick(colors)
	local x = opts.x or rng:range(0.05, 0.5)
	local y = opts.y or rng:range(0.6, 0.78)
	local w = opts.w or rng:range(0.3, 0.45)
	local h = opts.h or rng:range(0.12, 0.2)
	local l = label(gui, text, x, y, w, h, col, {
		font = opts.font or rng:pick({ Enum.Font.PermanentMarker, Enum.Font.Bangers }),
		align = Enum.TextXAlignment.Center,
		stroke = opts.outline or hex("#141414"),
		strokeW = 3,
		rotation = rng:range(-8, 6),
	})
	l.Name = "Graffiti"
	-- paint drips
	for _ = 1, rng:int(2, 5) do
		local d = frame(gui, x + rng:range(0.05, w - 0.05), y + h * 0.8, 0.004, rng:range(0.02, 0.06), col, 0.2)
		d.Name = "Drip"
	end
end

export type GhostOpts = { color: Color3?, ink: Color3?, font: Enum.Font? }

function Paint.ghostSign(gui: Instance, text: string, sub: string?, o: GhostOpts?)
	local opts: GhostOpts = o or {}
	local bgc = opts.color or hex("#C9BFA4")
	local ink = opts.ink or hex("#6E2A20")
	local panel = frame(gui, 0.04, 0.04, 0.92, 0.92, bgc, 0.55)
	panel.Name = "GhostSign"
	label(panel, text, 0.04, 0.05, 0.92, if sub then 0.55 else 0.9, ink, {
		font = opts.font or Enum.Font.Oswald,
		align = Enum.TextXAlignment.Center,
		transparency = 0.35,
	})
	if sub then
		label(panel, sub, 0.08, 0.62, 0.84, 0.3, ink, {
			font = Enum.Font.Garamond,
			align = Enum.TextXAlignment.Center,
			transparency = 0.45,
		})
	end
end

---------------------------------------------------------------------------------------------------
-- Distance: skylines and townscapes
---------------------------------------------------------------------------------------------------
export type SkylineOpts = {
	horizon: number?, -- fraction from the top where the ground line sits
	layers: number?,
	haze: Color3?, -- the colour distant layers fade into
	near: Color3?,
	litChance: number?,
	sky: boolean?, -- paint a sky gradient (false keeps the background transparent)
	landmarks: boolean?, -- tall signature towers (the Wall Street skyline)
	maxHeight: number?, -- tallest tower as a fraction of the canvas height
}

local function tower(
	parent: Instance,
	x: number,
	w: number,
	h: number,
	base: number,
	col: Color3,
	rng: Deps.RngT,
	lit: number,
	litCol: Color3
)
	local f = px(parent, x, base - h, w, h, col)
	f.Name = "Tower"
	local kind = rng:int(1, 6)
	if kind == 1 then -- stepped crown
		px(parent, x + w * 0.15, base - h - h * 0.08, w * 0.7, h * 0.08, col)
		px(parent, x + w * 0.32, base - h - h * 0.14, w * 0.36, h * 0.06, col)
	elseif kind == 2 then -- spire
		px(parent, x + w * 0.46, base - h - h * 0.22, math.max(2, w * 0.08), h * 0.22, col)
	elseif kind == 3 then -- slanted roof
		local r = px(parent, x, base - h - w * 0.2, w, w * 0.4, col)
		r.Rotation = rng:range(-14, 14)
	elseif kind == 4 then -- antenna pair
		px(parent, x + w * 0.25, base - h - h * 0.1, 2, h * 0.1, col)
		px(parent, x + w * 0.7, base - h - h * 0.07, 2, h * 0.07, col)
	end
	-- window rows: a few lit stripes and dots read as a city at dusk
	if lit > 0 then
		local rows = math.floor(h / 10)
		for r = 1, rows do
			if rng:chance(lit) then
				local y = base - h + r * 10
				local seg = rng:range(0.2, 0.8)
				px(parent, x + w * rng:range(0.05, 1 - seg), y, w * seg * 0.9, 2, litCol, rng:range(0.2, 0.6))
			end
		end
	end
end

function Paint.skyline(gui: Instance, W: number, H: number, rng: Deps.RngT, o: SkylineOpts)
	local horizon = H * (o.horizon or 0.92)
	local haze = o.haze or hex("#A9B0B6")
	local near = o.near or hex("#4E5862")
	if o.sky ~= false then
		local sky = Core.bg(gui, hex("#9AA3A8"))
		Core.gradient(sky, hex("#7F8A92"), hex("#C2C2BA"), 90)
	end
	local layers = o.layers or 3
	local maxH = H * (o.maxHeight or 0.75)
	for layer = 1, layers do
		local t = (layer - 1) / math.max(1, layers - 1) -- 0 = farthest
		local col = haze:Lerp(near, t * 0.8)
		local x = -rng:range(0, 30)
		local heightScale = 0.55 + (1 - t) * 0.45
		while x < W do
			local w = rng:range(18, 60) * (0.7 + t * 0.6)
			local h = rng:range(0.15, 0.75) * maxH * heightScale
			tower(gui, x, w, h, horizon, col, rng, (o.litChance or 0.25) * (0.4 + t), hex("#E9D9A8"))
			x += w + rng:range(-6, 10)
		end
	end
	if o.landmarks then
		-- the Street's signature towers rise above the rest: a crowned HQ tower, a needle and a twin slab
		local col = haze:Lerp(near, 0.45)
		local cx = W * rng:range(0.42, 0.55)
		local hq = px(gui, cx, horizon - maxH, 70, maxH, col)
		hq.Name = "HQTower"
		px(gui, cx + 8, horizon - maxH - 40, 54, 40, col)
		px(gui, cx + 22, horizon - maxH - 80, 26, 40, col)
		px(gui, cx + 33, horizon - maxH - 130, 4, 50, col)
		local nx = cx + W * 0.16
		px(gui, nx, horizon - maxH * 0.86, 46, maxH * 0.86, col)
		px(gui, nx + 21, horizon - maxH * 0.86 - 70, 4, 70, col)
		local tx = cx - W * 0.18
		px(gui, tx, horizon - maxH * 0.7, 40, maxH * 0.7, col)
		px(gui, tx + 48, horizon - maxH * 0.66, 40, maxH * 0.66, col)
		-- aircraft warning lights
		for _, p in { { cx + 35, horizon - maxH - 132 }, { nx + 23, horizon - maxH * 0.86 - 72 } } do
			Core.dot(gui, p[1], p[2], 6, hex("#FF5A4A"), 0.1)
		end
	end
	-- the near shore: a dark band of warehouses and the water's edge
	px(gui, 0, horizon - 4, W, H - horizon + 4, near:Lerp(hex("#1E2328"), 0.4))
end

export type TownOpts = { horizon: number?, haze: Color3?, near: Color3?, trees: boolean? }

function Paint.townscape(gui: Instance, W: number, H: number, rng: Deps.RngT, o: TownOpts?)
	local opts: TownOpts = o or {}
	local horizon = H * (opts.horizon or 0.95)
	local haze = opts.haze or hex("#9EA5A6")
	local near = opts.near or hex("#5C5650")
	for layer = 1, 2 do
		local col = haze:Lerp(near, (layer - 1) * 0.5)
		local x = -rng:range(0, 20)
		while x < W do
			local w = rng:range(20, 70)
			local h = rng:range(0.12, 0.42) * H * (if layer == 1 then 1 else 0.7)
			px(gui, x, horizon - h, w, h, col)
			if rng:chance(0.25) then -- a rooftop water tower
				local tx = x + w * rng:range(0.2, 0.7)
				px(gui, tx, horizon - h - 22, 14, 14, col)
				px(gui, tx + 1, horizon - h - 28, 12, 6, col)
				px(gui, tx + 2, horizon - h - 8, 2, 8, col)
				px(gui, tx + 10, horizon - h - 8, 2, 8, col)
			end
			if rng:chance(0.2) then -- a chimney stack
				px(gui, x + w * rng:range(0.1, 0.8), horizon - h - H * 0.12, 6, H * 0.12, col)
			end
			x += w + rng:range(0, 8)
		end
	end
	if opts.trees ~= false then
		local tcol = near:Lerp(hex("#2E2A26"), 0.3)
		for _ = 1, math.floor(W / 40) do
			local x = rng:range(0, W)
			local h = rng:range(16, 40)
			px(gui, x, horizon - h, 3, h, tcol)
			for _ = 1, 4 do
				Core.line(
					gui,
					x + 1,
					horizon - h * rng:range(0.4, 0.9),
					x + rng:range(-14, 14),
					horizon - h - rng:range(0, 10),
					2,
					tcol
				)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Windows seen from inside
---------------------------------------------------------------------------------------------------
function Paint.view(gui: Instance, W: number, H: number, rng: Deps.RngT, kind: string)
	if kind == "tunnel" then
		Core.bg(gui, hex("#121416"))
		for i = 1, 4 do
			local y = H * (0.2 + i * 0.15)
			px(gui, 0, y, W, 3, hex("#2A2E31"))
		end
		for _ = 1, 3 do
			local x = rng:range(0, W)
			px(gui, x, H * 0.35, W * 0.25, 4, hex("#F2C77A"), 0.3)
		end
		return
	end
	local night = kind == "night"
	local sky = Core.bg(gui, if night then hex("#1B2230") else hex("#9AA2A6"))
	Core.gradient(
		sky,
		if night then hex("#141A26") else hex("#8A949B"),
		if night then hex("#3A3A44") else hex("#C9C6BC"),
		90
	)
	if kind == "river" then
		Paint.skyline(gui, W, H * 0.8, rng, {
			horizon = 0.95,
			layers = 2,
			sky = false,
			landmarks = true,
			litChance = 0.35,
			maxHeight = 0.7,
		})
		local water = px(gui, 0, H * 0.76, W, H * 0.24, hex("#3A4A52"))
		Core.gradient(water, hex("#4A5A62"), hex("#26323A"), 90)
		for _ = 1, 6 do
			px(gui, rng:range(0, W * 0.9), rng:range(H * 0.78, H * 0.98), rng:range(10, 40), 2, hex("#8A9AA2"), 0.4)
		end
		return
	end
	-- campus: brick across the way, a distant skyline above the roofline
	Paint.skyline(gui, W, H * 0.45, rng, { horizon = 1, layers = 1, sky = false, litChance = 0.2, maxHeight = 0.9 })
	local brick = if night then hex("#3A2420") else C.brick:Lerp(hex("#8E8A80"), 0.25)
	local roofline = H * rng:range(0.38, 0.48)
	px(gui, 0, roofline, W, H - roofline, brick)
	px(gui, 0, roofline, W, 4, hex("#5F5D58"))
	local cols = math.max(2, math.floor(W / 46))
	for r = 0, 3 do
		for c = 0, cols - 1 do
			local x = (c + 0.25) * (W / cols)
			local y = roofline + 14 + r * 46
			if y + 30 < H then
				local litPane = rng:chance(if night then 0.45 else 0.15)
				px(gui, x, y, W / cols * 0.5, 30, if litPane then C.windowWarm else hex("#2C3236"))
			end
		end
	end
	-- a water tower on the roof
	local tx = rng:range(W * 0.1, W * 0.8)
	px(gui, tx, roofline - 30, 22, 22, hex("#5A4636"))
	px(gui, tx + 2, roofline - 36, 18, 6, hex("#4A3A2E"))
	px(gui, tx + 3, roofline - 8, 2, 8, hex("#3A3A3A"))
	px(gui, tx + 17, roofline - 8, 2, 8, hex("#3A3A3A"))
end

function Paint.muntins(gui: Instance, cols: number, rows: number, color: Color3, t: number?)
	local th = t or 0.025
	for c = 1, cols - 1 do
		frame(gui, c / cols - th / 2, 0, th, 1, color)
	end
	for r = 1, rows - 1 do
		frame(gui, 0, r / rows - th / 2, 1, th, color)
	end
	-- outer frame
	frame(gui, 0, 0, 1, th, color)
	frame(gui, 0, 1 - th, 1, th, color)
	frame(gui, 0, 0, th, 1, color)
	frame(gui, 1 - th, 0, th, 1, color)
end

---------------------------------------------------------------------------------------------------
-- Ground and paper
---------------------------------------------------------------------------------------------------
export type CrackOpts = { color: Color3?, thick: number?, branches: number? }

function Paint.cracks(gui: Instance, W: number, H: number, rng: Deps.RngT, n: number, o: CrackOpts?)
	local opts: CrackOpts = o or {}
	local col = opts.color or hex("#141516")
	for _ = 1, n do
		local x, y = rng:range(0, W), rng:range(0, H)
		local a = rng:range(0, math.pi * 2)
		for _ = 1, rng:int(3, 7) do
			local len = rng:range(10, 40)
			local nx, ny = x + math.cos(a) * len, y + math.sin(a) * len
			Core.line(gui, x, y, nx, ny, opts.thick or 2, col, 0.15)
			if rng:chance(0.3) then
				local b = a + rng:range(-1.2, 1.2)
				Core.line(gui, nx, ny, nx + math.cos(b) * len * 0.6, ny + math.sin(b) * len * 0.6, 1, col, 0.3)
			end
			x, y = nx, ny
			a += rng:range(-0.7, 0.7)
		end
	end
end

function Paint.flyers(gui: Instance, W: number, H: number, rng: Deps.RngT, texts: { string })
	local papers = { hex("#EDE6D2"), hex("#F2D95C"), hex("#E9A9B8"), hex("#A9D2E9"), hex("#C9E9A9"), hex("#F4F1EA") }
	local n = #texts
	if n == 0 then
		return
	end
	local cols = math.max(1, math.ceil(math.sqrt(n * W / math.max(H, 1))))
	local rows = math.ceil(n / cols)
	for i, text in texts do
		local c = (i - 1) % cols
		local r = (i - 1) // cols
		local w = 1 / cols
		local h = 1 / rows
		local f = frame(
			gui,
			c * w + w * rng:range(0.03, 0.1),
			r * h + h * rng:range(0.03, 0.1),
			w * 0.82,
			h * 0.82,
			rng:pick(papers)
		)
		f.Rotation = rng:range(-7, 7)
		f.Name = "Flyer"
		label(f, text, 0.08, 0.08, 0.84, 0.84, C.ink, {
			font = rng:pick({ Enum.Font.SpecialElite, Enum.Font.Oswald, Enum.Font.PatrickHand, Enum.Font.Kalam }),
			align = Enum.TextXAlignment.Center,
		})
		-- staple
		frame(f, 0.45, 0.02, 0.1, 0.02, hex("#9A9A9A"))
		if rng:chance(0.4) then -- tear-off tabs
			for k = 0, 4 do
				frame(f, 0.06 + k * 0.18, 0.86, 0.14, 0.12, Color3.new(1, 1, 1), 0.3)
			end
		end
	end
end

return Paint
