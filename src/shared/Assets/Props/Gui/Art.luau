--!strict
-- Painted SurfaceGui content: abstract paintings (8 styles), whiteboard and chalkboard scribbles, clock
-- dials, posters and flyers, fictional flags, rug patterns, photos, billboard ads, vending fronts,
-- newspapers and menu boards. Frames and TextLabels only. Bake-safe.

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)
local Words = require(script.Parent.Parent.Words)
local Core = require(script.Parent.Core)

local Art = {}

local hex = Core.hex
local frame, label, px, dot = Core.frame, Core.label, Core.px, Core.dot

---------------------------------------------------------------------------------------------------
-- Abstract paintings (variant 1-8)
---------------------------------------------------------------------------------------------------
local PALETTES: { { Color3 } } = {
	{ hex("#C8553D"), hex("#F28F3B"), hex("#FFD5C2"), hex("#588B8B"), hex("#2D3047") },
	{ hex("#22577A"), hex("#38A3A5"), hex("#57CC99"), hex("#80ED99"), hex("#F1F7EE") },
	{ hex("#6B4226"), hex("#D9A441"), hex("#E8D8C3"), hex("#3E5641"), hex("#A24936") },
	{ hex("#111111"), hex("#3A3A3A"), hex("#9A9A9A"), hex("#F2F2F2"), hex("#C0392B") },
	{ hex("#2E1760"), hex("#7A1E48"), hex("#D4A017"), hex("#0F5257"), hex("#F4EBD9") },
	{ hex("#F7C5CC"), hex("#A0CED9"), hex("#FFEE93"), hex("#5B8C85"), hex("#FCF5EC") },
}
Art.PALETTES = PALETTES
Art.PAINTING_VARIANTS = 8

type Painter = (root: Frame, W: number, H: number, rng: Rng.Rng, pal: { Color3 }) -> ()

local function paintColorField(root: Frame, _W: number, _H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = pal[1]
	local n = rng:int(2, 3)
	local y = 0.08
	local gap = 0.05
	local total = 0.84 - gap * (n - 1)
	for i = 1, n do
		local h = math.min(total / n * rng:range(0.8, 1.2), 0.92 - y)
		local f = frame(root, 0.1, y, 0.8, h, pal[i + 1])
		Core.round(f, 0, 6)
		Core.gradient(f, pal[i + 1], pal[i + 1]:Lerp(pal[1], 0.35), 90)
		y += h + gap
	end
end

local function paintGrid(root: Frame, _W: number, _H: number, rng: Rng.Rng, _pal: { Color3 })
	root.BackgroundColor3 = hex("#F4F1EA")
	local ink = hex("#151515")
	local xs = { rng:range(0.18, 0.3), rng:range(0.5, 0.62), rng:range(0.78, 0.88) }
	local ys = { rng:range(0.2, 0.35), rng:range(0.55, 0.7) }
	local fills = { hex("#C8102E"), hex("#0B3D91"), hex("#F2C230") }
	-- coloured cells first, so the black lines sit on top
	frame(root, 0, 0, xs[1], ys[1], fills[1])
	frame(root, xs[2], ys[2], 1 - xs[2], 1 - ys[2], fills[2])
	frame(root, xs[1], ys[2], xs[2] - xs[1], 1 - ys[2], fills[3])
	for _, x in xs do
		frame(root, x - 0.012, 0, 0.024, 1, ink)
	end
	for _, y in ys do
		frame(root, 0, y - 0.016, 1, 0.032, ink)
	end
end

local function paintCircles(root: Frame, W: number, H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = pal[5]
	local m = math.min(W, H)
	for i = 1, 6 do
		local d = m * rng:range(0.22, 0.55)
		local cx = rng:range(d / 2, math.max(d / 2, W - d / 2))
		local cy = rng:range(d / 2, math.max(d / 2, H - d / 2))
		dot(root, cx, cy, d, pal[(i - 1) % 4 + 1], rng:range(0.05, 0.35))
	end
end

local function paintStripes(root: Frame, W: number, H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = pal[1]
	local band = frame(root, 0, 0, 1, 1, Color3.new(1, 1, 1))
	Core.stripes(band, { pal[1], pal[2], pal[3], pal[4] }, rng:int(5, 9), rng:range(30, 60))
	local d = math.min(W, H) * 0.34
	dot(root, W * rng:range(0.3, 0.7), H * rng:range(0.35, 0.65), d, pal[5])
end

local function paintHorizon(root: Frame, W: number, H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = Color3.new(1, 1, 1)
	Core.gradient(root, pal[3], pal[2], 90)
	dot(root, W * rng:range(0.25, 0.75), H * rng:range(0.25, 0.45), math.min(W, H) * 0.3, pal[5])
	for i = 1, 3 do
		local top = 0.5 + i * 0.1 + rng:range(-0.04, 0.04)
		local hill =
			frame(root, rng:range(-0.6, -0.1), top, rng:range(1.4, 1.9), 0.8, pal[(i % 2) + 1]:Lerp(pal[4], i / 3))
		Core.round(hill, 0.5)
	end
end

local function paintShards(root: Frame, W: number, H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = pal[1]:Lerp(Color3.new(0, 0, 0), 0.55)
	for i = 1, 7 do
		local w = W * rng:range(0.14, 0.3)
		local h = H * rng:range(0.05, 0.14)
		local r = math.sqrt(w * w + h * h) / 2
		local cx = rng:range(r, math.max(r, W - r))
		local cy = rng:range(r, math.max(r, H - r))
		local f = px(root, cx - w / 2, cy - h / 2, w, h, pal[(i - 1) % 5 + 1], rng:range(0, 0.25))
		f.Rotation = rng:range(-70, 70)
	end
end

local function paintDots(root: Frame, W: number, H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = pal[5]
	local cols, rows = 5, 4
	local cw, ch = W / cols, H / rows
	local m = math.min(cw, ch)
	for r = 1, rows do
		for c = 1, cols do
			local d = m * rng:range(0.35, 0.85)
			dot(root, cw * (c - 0.5), ch * (r - 0.5), d, pal[(r + c) % 4 + 1])
		end
	end
end

local function paintWaves(root: Frame, _W: number, _H: number, rng: Rng.Rng, pal: { Color3 })
	root.BackgroundColor3 = pal[5]
	local y = 0
	for i = 1, 6 do
		local h = rng:range(0.13, 0.2)
		local f = frame(root, rng:range(-0.05, 0), y, 1.1, h + 0.03, Color3.new(1, 1, 1))
		Core.gradient(f, pal[(i - 1) % 4 + 1], pal[i % 4 + 1], rng:range(-12, 12))
		Core.round(f, 0.4)
		y += h
		if y > 1 then
			break
		end
	end
end

local PAINTERS: { Painter } =
	{ paintColorField, paintGrid, paintCircles, paintStripes, paintHorizon, paintShards, paintDots, paintWaves }

-- Paints an abstract artwork filling `gui` (pixel size W x H). variant 1-8; the palette comes from rng.
function Art.painting(gui: Instance, W: number, H: number, variant: number, rng: Rng.Rng): Frame
	local root = frame(gui, 0, 0, 1, 1, hex("#FFFFFF"))
	root.Name = "Painting"
	root.ClipsDescendants = true
	local pal = rng:shuffle(PALETTES[rng:int(1, #PALETTES)])
	local v = math.clamp(math.floor(variant), 1, #PAINTERS)
	PAINTERS[v](root, W, H, rng, pal)
	return root
end

---------------------------------------------------------------------------------------------------
-- Boards and dials
---------------------------------------------------------------------------------------------------
function Art.whiteboard(gui: Instance, W: number, H: number, rng: Rng.Rng)
	local blue = hex("#1F4FB5")
	local red = hex("#C62828")
	local black = hex("#202124")
	local marker = Enum.Font.PermanentMarker
	label(gui, Words.whiteboard[1], 0.04, 0.04, 0.4, 0.13, blue, { font = marker })
	-- flow of boxes with arrows
	local names = { "COMPS", "DCF", "LBO" }
	local bw, bh = 0.17, 0.14
	for i, n in names do
		local x = 0.05 + (i - 1) * 0.24
		local box = frame(gui, x, 0.27, bw, bh, hex("#FFFFFF"), 1)
		Core.stroke(box, black, 2)
		label(box, n, 0.08, 0.1, 0.84, 0.8, black, { font = marker, align = Enum.TextXAlignment.Center })
		if i < #names then
			local x1 = (x + bw + 0.01) * W
			Core.arrow(gui, x1, 0.34 * H, x1 + 0.05 * W, 0.34 * H, 2, black)
		end
	end
	label(gui, Words.whiteboard[2], 0.05, 0.5, 0.4, 0.12, black, { font = marker })
	label(gui, Words.whiteboard[3], 0.05, 0.64, 0.3, 0.11, red, { font = marker })
	label(gui, rng:pick({ Words.whiteboard[5], Words.whiteboard[6] }), 0.05, 0.8, 0.36, 0.12, red, {
		font = marker,
		rotation = -4,
	})
	-- hand-drawn chart
	local x0, y0, cw, ch = 0.62 * W, 0.2 * H, 0.33 * W, 0.62 * H
	Core.line(gui, x0, y0 + ch, x0 + cw, y0 + ch, 2, black)
	Core.line(gui, x0, y0, x0, y0 + ch, 2, black)
	local vals = Core.series(rng, 6, 10, 0.12, 0.08)
	Core.lineChart(gui, x0 + 4, y0 + 6, cw - 8, ch - 12, vals, blue, 3)
	dot(gui, x0 + cw - 6, y0 + 10, 16, red, 0.6)
end

function Art.chalkboard(gui: Instance, W: number, H: number, rng: Rng.Rng)
	local chalk = hex("#ECEDE6")
	local yellow = hex("#F1E28A")
	local font = Enum.Font.Kalam
	local lines = rng:shuffle({ Words.chalkboard[1], Words.chalkboard[2], Words.chalkboard[5] })
	for i, l in lines do
		label(gui, l, 0.04, 0.06 + (i - 1) * 0.16, 0.5, 0.13, chalk, { font = font, transparency = 0.1 })
	end
	local box = frame(gui, 0.04, 0.62, 0.38, 0.2, chalk, 1)
	Core.stroke(box, yellow, 2, 0.15)
	label(box, Words.chalkboard[3], 0.05, 0.1, 0.9, 0.8, yellow, { font = font, align = Enum.TextXAlignment.Center })
	-- supply and demand
	local x0, y0, cw, ch = 0.6 * W, 0.12 * H, 0.32 * W, 0.7 * H
	Core.line(gui, x0, y0, x0, y0 + ch, 2, chalk, 0.1)
	Core.line(gui, x0, y0 + ch, x0 + cw, y0 + ch, 2, chalk, 0.1)
	Core.line(gui, x0 + cw * 0.08, y0 + ch * 0.1, x0 + cw * 0.92, y0 + ch * 0.9, 2, yellow, 0.1)
	Core.line(gui, x0 + cw * 0.08, y0 + ch * 0.9, x0 + cw * 0.92, y0 + ch * 0.1, 2, chalk, 0.1)
	label(gui, Words.chalkboard[4], 0.6, 0.86, 0.32, 0.1, chalk, { font = font, align = Enum.TextXAlignment.Center })
	-- smudges of half-erased chalk
	for _ = 1, 3 do
		frame(gui, rng:range(0.05, 0.5), rng:range(0.45, 0.9), rng:range(0.1, 0.25), 0.05, chalk, 0.88)
	end
end

-- Round dial: 12 ticks and hands named "HourHand" and "MinuteHand" (centred, rotated about the centre).
function Art.clockFace(gui: Instance, W: number, H: number, hour: number, minute: number, ink: Color3, face: Color3?)
	local cx, cy = W / 2, H / 2
	local r = math.min(W, H) / 2
	if face then
		dot(gui, cx, cy, r * 2, face)
	end
	for i = 0, 11 do
		local a = math.rad(i * 30)
		local long = i % 3 == 0
		local len = if long then r * 0.16 else r * 0.09
		local rr = r * 0.82 - len / 2
		local f = px(gui, 0, 0, if long then r * 0.06 else r * 0.035, len, ink)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = Core.off(cx + math.sin(a) * rr, cy - math.cos(a) * rr)
		f.Rotation = i * 30
	end
	local function hand(name: string, angleDeg: number, len: number, thick: number, color: Color3)
		local a = math.rad(angleDeg)
		local f = px(gui, 0, 0, thick, len, color)
		f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = Core.off(cx + math.sin(a) * len / 2, cy - math.cos(a) * len / 2)
		f.Rotation = angleDeg
		Core.round(f, 0.5)
	end
	hand("HourHand", (hour % 12) * 30 + minute * 0.5, r * 0.48, r * 0.07, ink)
	hand("MinuteHand", minute * 6, r * 0.72, r * 0.045, ink)
	dot(gui, cx, cy, r * 0.12, hex("#B8933F"))
end

---------------------------------------------------------------------------------------------------
-- Posters, flyers, ads
---------------------------------------------------------------------------------------------------
-- Poster: title, body text and colour blocks. colors = {background, accent, text}.
function Art.poster(gui: Instance, title: string, body: string, colors: { Color3 }, rng: Rng.Rng, font: Enum.Font?)
	local bgc = colors[1] or hex("#F4F1EA")
	local accent = colors[2] or hex("#C8553D")
	local ink = colors[3] or hex("#1A1A1A")
	Core.bg(gui, bgc)
	local style = rng:int(1, 3)
	if style == 1 then
		frame(gui, 0, 0, 1, 0.3, accent)
		label(gui, title, 0.06, 0.04, 0.88, 0.22, bgc, {
			font = font or Enum.Font.GothamBlack,
			align = Enum.TextXAlignment.Center,
		})
		label(gui, body, 0.08, 0.38, 0.84, 0.5, ink, { font = Enum.Font.Gotham, align = Enum.TextXAlignment.Center })
	elseif style == 2 then
		frame(gui, 0.06, 0.06, 0.88, 0.02, accent)
		label(gui, title, 0.06, 0.12, 0.88, 0.3, ink, { font = font or Enum.Font.Oswald })
		frame(gui, 0.06, 0.46, 0.3, 0.3, accent)
		label(gui, body, 0.42, 0.46, 0.52, 0.42, ink, { font = Enum.Font.Gotham, yAlign = Enum.TextYAlignment.Top })
	else
		label(gui, title, 0.06, 0.06, 0.88, 0.28, accent, {
			font = font or Enum.Font.SpecialElite,
			align = Enum.TextXAlignment.Center,
		})
		label(gui, body, 0.08, 0.38, 0.84, 0.36, ink, {
			font = Enum.Font.SpecialElite,
			align = Enum.TextXAlignment.Center,
		})
		-- tear-off phone tabs
		for i = 0, 5 do
			frame(gui, 0.04 + i * 0.16, 0.82, 0.12, 0.14, ink, 0.85)
		end
	end
end

-- Billboard / bus-shelter advert for a fictional brand.
function Art.ad(gui: Instance, brand: string, slogan: string, rng: Rng.Rng)
	local schemes: { { Color3 } } = {
		{ hex("#0B1F3A"), hex("#C9A54C"), hex("#FFFFFF") },
		{ hex("#7A1F24"), hex("#F2C230"), hex("#FFFFFF") },
		{ hex("#1F4D3A"), hex("#E8D8C3"), hex("#FFFFFF") },
		{ hex("#F4F1EA"), hex("#C8553D"), hex("#1A1A1A") },
		{ hex("#111111"), hex("#2BD6C0"), hex("#FFFFFF") },
	}
	local s = schemes[rng:int(1, #schemes)]
	local root = Core.bg(gui, s[1])
	Core.gradient(root, s[1], s[1]:Lerp(Color3.new(0, 0, 0), 0.35), rng:range(20, 70))
	-- product silhouette: a big disc (watch face, bottle cap, globe ...) and a swoosh band
	local band = frame(gui, -0.1, rng:range(0.55, 0.7), 1.2, 0.12, s[2], 0.1)
	band.Rotation = rng:range(-8, -3)
	local d = frame(gui, 0.66, 0.16, 0.26, 0.26 * 2.4, s[2], 0)
	d.SizeConstraint = Enum.SizeConstraint.RelativeYY
	d.Size = UDim2.fromScale(0.62, 0.62)
	Core.round(d, 0.5)
	Core.stroke(d, s[3], 4, 0.2)
	label(gui, brand, 0.05, 0.12, 0.6, 0.3, s[3], { font = Enum.Font.GothamBlack })
	label(gui, slogan, 0.05, 0.44, 0.58, 0.14, s[2], { font = Enum.Font.Gotham, italic = true })
	label(gui, Words.adFooter, 0.05, 0.84, 0.5, 0.08, s[3], { font = Enum.Font.Gotham, transparency = 0.3 })
end

---------------------------------------------------------------------------------------------------
-- Flags, rugs, photos
---------------------------------------------------------------------------------------------------
-- Fictional flags. variant: 1 Street district, 2 Metropolitan Exchange, 3 city tricolour, 4 Eastbridge.
function Art.flag(gui: Instance, W: number, H: number, variant: number, _rng: Rng.Rng)
	local v = math.clamp(math.floor(variant), 1, 4)
	if v == 1 then
		Core.bg(gui, hex("#0B1F3A"))
		frame(gui, 0, 0.42, 1, 0.16, hex("#C9A54C"))
		local d = math.min(W, H) * 0.46
		dot(gui, W * 0.25, H * 0.5, d, hex("#0B1F3A"))
		dot(gui, W * 0.25, H * 0.5, d * 0.78, hex("#C9A54C"))
		local s = px(gui, W * 0.25 - d * 0.22, H * 0.5 - d * 0.22, d * 0.44, d * 0.44, hex("#0B1F3A"))
		s.Rotation = 45
	elseif v == 2 then
		Core.bg(gui, hex("#F7F6F2"))
		frame(gui, 0, 0, 0.32, 1, hex("#173459"))
		for i = 0, 2 do
			frame(gui, 0.4, 0.18 + i * 0.26, 0.56, 0.1, hex("#173459"))
		end
		label(gui, "ME", 0.02, 0.3, 0.28, 0.4, hex("#E3C46F"), {
			font = Enum.Font.Bodoni,
			align = Enum.TextXAlignment.Center,
		})
	elseif v == 3 then
		Core.bg(gui, hex("#1F4D3A"))
		frame(gui, 0.333, 0, 0.334, 1, hex("#F4F1EA"))
		frame(gui, 0.667, 0, 0.333, 1, hex("#7A1F24"))
		dot(gui, W * 0.5, H * 0.5, math.min(W, H) * 0.32, hex("#C9A54C"))
	else
		Core.bg(gui, hex("#5C2A21"))
		local diag = frame(gui, -0.2, 0.4, 1.4, 0.2, hex("#C9A13B"))
		diag.Rotation = -18
		label(gui, "E", 0.06, 0.1, 0.25, 0.5, hex("#E9E2CF"), { font = Enum.Font.Merriweather })
	end
end

-- Rug top patterns. style: "persian" | "modern" | "round" | "office". The background stays clear so the
-- rug part's own colour and Carpet/Fabric texture show through; pattern frames are slightly translucent.
function Art.rug(gui: Instance, W: number, H: number, style: string, rng: Rng.Rng, base: Color3, accent: Color3)
	local A = 0.12
	Core.bg(gui, base, 1)
	local m = math.min(W, H)
	if style == "persian" then
		local cream = hex("#E8D8B8")
		local navy = hex("#1B2A44")
		frame(gui, 0.03, 0.05, 0.94, 0.9, navy, A)
		frame(gui, 0.06, 0.1, 0.88, 0.8, base, A)
		frame(gui, 0.09, 0.16, 0.82, 0.68, accent:Lerp(base, 0.4), A)
		-- central medallion and corner spandrels from rotated squares
		for i, sz in { 0.5, 0.36, 0.22 } do
			local c = if i == 2 then cream elseif i == 1 then navy else accent
			local d = m * sz
			local f = px(gui, W / 2 - d / 2, H / 2 - d / 2, d, d, c, A)
			f.Rotation = 45
		end
		for _, cx in { 0.16, 0.84 } do
			for _, cy in { 0.24, 0.76 } do
				local d = m * 0.14
				local f = px(gui, W * cx - d / 2, H * cy - d / 2, d, d, cream, A)
				f.Rotation = 45
			end
		end
		-- border motif dots
		for i = 0, 11 do
			dot(gui, W * (0.08 + i * 0.076), H * 0.075, m * 0.03, cream, A)
			dot(gui, W * (0.08 + i * 0.076), H * 0.925, m * 0.03, cream, A)
		end
	elseif style == "modern" then
		local cols = { accent, base:Lerp(Color3.new(1, 1, 1), 0.5), hex("#1A1A1A"), accent:Lerp(base, 0.5) }
		for i = 1, 5 do
			frame(
				gui,
				rng:range(-0.1, 0.7),
				rng:range(-0.1, 0.7),
				rng:range(0.25, 0.55),
				rng:range(0.2, 0.5),
				cols[(i - 1) % 4 + 1],
				rng:range(A, 0.3)
			)
		end
		local line = frame(gui, -0.2, rng:range(0.3, 0.7), 1.4, 0.02, hex("#F4F1EA"), A)
		line.Rotation = rng:range(-25, 25)
	elseif style == "round" then
		for i, sz in { 0.86, 0.66, 0.42, 0.18 } do
			dot(gui, W / 2, H / 2, m * sz, if i % 2 == 1 then accent else base:Lerp(Color3.new(1, 1, 1), 0.25), A)
		end
	else
		frame(gui, 0.04, 0.06, 0.92, 0.88, accent, A)
		frame(gui, 0.06, 0.1, 0.88, 0.8, base, A)
		frame(gui, 0.1, 0.18, 0.8, 0.64, base:Lerp(accent, 0.18), A)
	end
end

-- Little framed snapshot: sky, sun, hills and two figures.
function Art.photo(gui: Instance, W: number, H: number, rng: Rng.Rng)
	local sky = rng:pick({ hex("#8FC1E3"), hex("#F2B880"), hex("#B7A6D9") })
	local root = Core.bg(gui, Color3.new(1, 1, 1))
	Core.gradient(root, sky, sky:Lerp(Color3.new(1, 1, 1), 0.6), 90)
	dot(gui, W * rng:range(0.2, 0.8), H * 0.3, math.min(W, H) * 0.22, hex("#FFF1C1"))
	local hill = frame(gui, -0.3, 0.62, 1.6, 0.8, rng:pick({ hex("#5A8A4A"), hex("#3E6B8A"), hex("#C9B27A") }))
	Core.round(hill, 0.5)
	for i = 0, 1 do
		local x = W * (0.38 + i * 0.2)
		local skin = rng:pick({ hex("#F1D2B6"), hex("#B07A4F"), hex("#6B4128") })
		dot(gui, x, H * 0.48, H * 0.12, skin)
		local body = px(
			gui,
			x - H * 0.08,
			H * 0.55,
			H * 0.16,
			H * 0.3,
			rng:pick({ hex("#173459"), hex("#7A1F24"), hex("#2F5A3A") })
		)
		Core.round(body, 0.3)
	end
end

-- Newspaper front page for newsstands and boxes.
function Art.newspaper(gui: Instance, rng: Rng.Rng)
	local ink = hex("#1A1A1A")
	Core.bg(gui, hex("#EFEBE1"))
	label(gui, Words.paperName, 0.04, 0.02, 0.92, 0.16, ink, {
		font = Enum.Font.Bodoni,
		align = Enum.TextXAlignment.Center,
	})
	frame(gui, 0.04, 0.19, 0.92, 0.01, ink)
	label(gui, rng:pick(Words.headlines), 0.04, 0.22, 0.92, 0.2, ink, { font = Enum.Font.Merriweather })
	frame(gui, 0.04, 0.45, 0.44, 0.3, hex("#9A958A"))
	for col = 0, 1 do
		for row = 0, 5 do
			frame(gui, 0.52 + col * 0.23, 0.46 + row * 0.08, 0.2, 0.025, ink, 0.6)
		end
	end
	for row = 0, 1 do
		frame(gui, 0.04, 0.8 + row * 0.07, 0.92, 0.025, ink, 0.6)
	end
end

-- Menu / price board for food carts and the diner.
function Art.menu(gui: Instance, title: string, items: { string }, bgc: Color3, ink: Color3, accent: Color3)
	Core.bg(gui, bgc)
	frame(gui, 0, 0, 1, 0.3, accent)
	label(gui, title, 0.05, 0.03, 0.9, 0.24, bgc, { font = Enum.Font.LuckiestGuy, align = Enum.TextXAlignment.Center })
	label(gui, table.concat(items, "\n"), 0.08, 0.36, 0.84, 0.6, ink, {
		font = Enum.Font.Oswald,
		yAlign = Enum.TextYAlignment.Top,
		align = Enum.TextXAlignment.Center,
	})
end

-- Vending machine glass front: rows of coloured products with price tags.
function Art.vending(gui: Instance, brand: string, rng: Rng.Rng)
	Core.bg(gui, hex("#0E1116"))
	label(gui, brand, 0.05, 0.01, 0.9, 0.1, hex("#FFFFFF"), {
		font = Enum.Font.LuckiestGuy,
		align = Enum.TextXAlignment.Center,
	})
	local cans = { hex("#C0392B"), hex("#2E86C1"), hex("#F1C40F"), hex("#27AE60"), hex("#8E44AD"), hex("#E67E22") }
	for row = 0, 4 do
		local y = 0.14 + row * 0.17
		frame(gui, 0.04, y + 0.13, 0.92, 0.012, hex("#9AA3AD"))
		local c = rng:pick(cans)
		for i = 0, 4 do
			local can =
				frame(gui, 0.07 + i * 0.18, y + 0.02, 0.12, 0.11, if rng:chance(0.12) then hex("#0E1116") else c)
			Core.round(can, 0.2)
		end
	end
end

-- Chain-link mesh: two sets of diagonal wires `spacing` pixels apart (the canvas clips the overflow).
function Art.chainlink(gui: Instance, W: number, H: number, spacing: number, color: Color3)
	local n = math.floor((W + H) / spacing) + 1
	for i = 0, n do
		local o = i * spacing
		Core.line(gui, o, 0, o - H, H, 1, color)
		Core.line(gui, o - H, 0, o, H, 1, color)
	end
end

-- Painted stairwell receding into the dark (used where a prop cannot cut a real hole in the ground).
function Art.stairwell(gui: Instance, steps: number, lit: Color3, dark: Color3)
	Core.bg(gui, dark)
	for i = 0, steps - 1 do
		local t = i / steps
		local tread = frame(gui, 0.04, t, 0.92, 1 / steps * 0.62, lit:Lerp(dark, t * 0.92))
		tread.Name = "Tread"
		frame(gui, 0.04, t + 1 / steps * 0.62, 0.92, 1 / steps * 0.06, hex("#C9B458"):Lerp(dark, t), 0.2)
	end
end

-- Generic magazine/cover grid (newsstand racks).
function Art.covers(gui: Instance, cols: number, rows: number, rng: Rng.Rng)
	Core.bg(gui, hex("#2A2A2A"))
	local palette = { hex("#C0392B"), hex("#F2C230"), hex("#2E86C1"), hex("#F4F1EA"), hex("#27AE60"), hex("#8E44AD") }
	local cw, ch = 1 / cols, 1 / rows
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local f = frame(gui, c * cw + cw * 0.06, r * ch + ch * 0.06, cw * 0.88, ch * 0.88, rng:pick(palette))
			frame(f, 0.08, 0.06, 0.84, 0.18, Color3.new(1, 1, 1), 0.2)
			frame(f, 0.08, 0.7, 0.6, 0.06, Color3.new(0, 0, 0), 0.4)
		end
	end
end

return Art
