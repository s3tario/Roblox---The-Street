--!strict
-- SurfaceGui artwork for the office templates (Frames and TextLabels only, no image ids; bake-safe):
--   Art.skyline(part, face, opts)            layered city skyline for the faked window views (sky left clear, so
--                                            the real sky shows above the towers when the part is invisible)
--   Art.terrazzo(part, face, seed, opts?)    terrazzo chips (the IB desk pods' end panels, pantry island)
--   Art.monitors(part, count, kinds, rng, opts?)   `count` screens side by side with bezels on the Front face
--   Art.screenKinds                          the screen kinds monitors cycle through
--   Art.painting(part, face, variant, rng)   abstract artwork (Props Gui painting)
--   Art.clock(part, face, city, hour, minute)
--   Art.board(part, face, title, body, opts?)     text board (deal pipeline, menus, directories)
--   Art.stripes(part, face, a, b, bands, rotation)   hazard tape and accents
--   Art.formwork(part, face, spacing, color)       board-formed concrete joints on a ceiling slab
--   Art.indicator(part, face, text)          elevator floor indicator
--   Art.glow(part, face, color, brightness?) an evenly glowing face (light diffusers, backlit signs)
--   Art.elevatorDoor(part, face)             brushed steel leaves with the centre seam
--   Art.keyboard(pad)                        keyboard and mouse drawn on a desk pad's top face
--   Art.lockers(part, face)                  locker doors with pulls
--   Art.whiteboard(part, face, rng)          marker scribbles (Props Gui whiteboard)

local Deps = require(script.Parent.Deps)
local Text = require(script.Parent.Text)

local Core = Deps.Gui.Core
local GuiArt = Deps.Gui.Art
local Words = Deps.Words
local Rng = Deps.Rng
local hex = Deps.Palette.hex

type Rng = typeof(Rng.new(0))

local Art = {}

local UP, DOWN, TEXT, DIM, AMBER = Core.UP, Core.DOWN, Core.TEXT, Core.DIM, Core.AMBER
local NAVY, NAVY2, MONO = Core.NAVY, Core.NAVY2, Core.MONO
local RIGHT = Enum.TextXAlignment.Right
local CENTER = Enum.TextXAlignment.Center

local function transparencyGradient(obj: GuiObject, points: { { number } }, rotation: number): UIGradient
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new(kps)
	g.Rotation = rotation
	g.Parent = obj
	return g
end

---------------------------------------------------------------------------------------------------
-- Skyline
---------------------------------------------------------------------------------------------------
export type SkylineOpts = {
	seed: any,
	horizon: number?, -- fraction of the height (from the top) where the horizon sits (eye level)
	pps: number?,
	density: number?, -- 0.5..1.5 (mid-layer tower count multiplier)
}

local FAR = hex("#AFC1CE")
local MASS_TOP = hex("#9AAEBD")
local MASS_BOTTOM = hex("#71879A")
local MID = { hex("#7F96A9"), hex("#8A9FB0"), hex("#74899C"), hex("#93A5B3") }
local NEAR = { hex("#566B80"), hex("#4D6176"), hex("#62778B"), hex("#5B6470") }
local WINDOW_LIGHT = hex("#D7E3EC")
local WINDOW_DARK = hex("#3B4B5C")

local function tower(
	gui: Instance,
	x: number,
	top: number,
	w: number,
	bottom: number,
	color: Color3,
	rng: Rng,
	near: boolean
)
	local body = Core.px(gui, x, top, w, bottom - top, color)
	body.Name = "Tower"
	-- window columns: alternating light/dark vertical bands, slightly see-through so the body colour reads through
	local cols = Core.px(gui, x + w * 0.06, top + w * 0.08, w * 0.88, bottom - top, WINDOW_LIGHT, 0.55)
	Core.stripes(cols, { WINDOW_LIGHT, WINDOW_DARK }, if near then 9 else rng:int(5, 8), 0)
	if near then
		-- floor lines over the columns give a curtain-wall grid; sun on one side shades the tower
		local floors = Core.px(gui, x, top + w * 0.08, w, bottom - top, WINDOW_DARK, 0.7)
		Core.stripes(floors, { WINDOW_DARK, color }, 9, 90)
		local shade = Core.px(gui, x, top, w, bottom - top, hex("#1E2A36"), 0.55)
		transparencyGradient(shade, { { 0, 1 }, { 0.55, 0.9 }, { 1, 0.35 } }, 0)
	end
	-- crowns, setbacks and masts
	local roll = rng:next()
	if roll < 0.35 then
		Core.px(gui, x + w * 0.2, top - w * 0.18, w * 0.6, w * 0.18 + 1, color)
	elseif roll < 0.55 then
		Core.px(gui, x + w * 0.47, top - w * 0.6, math.max(1, w * 0.06), w * 0.6, color)
	elseif roll < 0.7 then
		local cap = Core.px(gui, x + w * 0.1, top - w * 0.3, w * 0.8, w * 0.3 + 1, color)
		cap.Rotation = 0
		Core.px(gui, x + w * 0.3, top - w * 0.52, w * 0.4, w * 0.24, color)
	end
end

function Art.skyline(part: BasePart, face: Enum.NormalId, o: SkylineOpts): SurfaceGui
	local gui, W, H = Core.surface(part, face, {
		pps = o.pps or 3,
		glow = true,
		brightness = 1,
		name = "Skyline",
	})
	local rng = Rng.new(o.seed)
	local hz = math.floor(H * (o.horizon or 0.8))
	-- warm haze glowing just above the horizon
	local haze = Core.px(gui, 0, hz - H * 0.28, W, H * 0.28 + 2, hex("#E6EDF1"))
	transparencyGradient(haze, { { 0, 1 }, { 0.65, 0.45 }, { 1, 0.15 } }, 90)
	-- the city far below, fading into the distance
	local mass = Core.px(gui, 0, hz, W, H - hz, MASS_TOP)
	Core.gradient(mass, MASS_TOP, MASS_BOTTOM, 90)
	-- distant towers along the horizon
	local x = 0
	while x < W do
		local w = rng:range(W * 0.006, W * 0.022)
		local h = rng:range(H * 0.01, H * 0.11)
		Core.px(gui, x, hz - h, w, h + 2, FAR)
		x += w + rng:range(0, W * 0.012)
	end
	-- mid towers (around eye level: we are high up)
	local mids = math.floor(14 * (o.density or 1))
	for _ = 1, mids do
		local w = rng:range(W * 0.025, W * 0.06)
		local px = rng:range(-w * 0.3, W - w * 0.7)
		local top = hz - rng:range(H * 0.06, H * 0.42)
		tower(gui, px, top, w, H, MID[rng:int(1, #MID)], rng, false)
	end
	-- a few near skyscrapers rising above us
	local nears = rng:int(3, 5)
	local slots = rng:shuffle({ 0.04, 0.22, 0.42, 0.62, 0.8 })
	for i = 1, nears do
		local w = rng:range(W * 0.07, W * 0.12)
		local px = slots[i] * W + rng:range(-W * 0.03, W * 0.03)
		local top = rng:range(H * 0.02, H * 0.32)
		tower(gui, px, top, w, H, NEAR[rng:int(1, #NEAR)], rng, true)
	end
	return gui
end

---------------------------------------------------------------------------------------------------
-- Terrazzo
---------------------------------------------------------------------------------------------------
local CHIPS: { { any } } = {
	{ hex("#8E8D88"), 34 },
	{ hex("#3E3D3A"), 18 },
	{ hex("#F4EFE6"), 14 },
	{ hex("#B4694A"), 12 },
	{ hex("#7E937A"), 10 },
	{ hex("#1F1F1E"), 7 },
	{ hex("#C9A46A"), 5 },
}

export type TerrazzoOpts = { pps: number?, density: number?, maxDistance: number? }

function Art.terrazzo(part: BasePart, face: Enum.NormalId, seed: any, o: TerrazzoOpts?): SurfaceGui
	local opts: TerrazzoOpts = o or {}
	local pps = opts.pps or 16
	local gui, W, H = Core.surface(part, face, { pps = pps, maxDistance = opts.maxDistance or 140, name = "Terrazzo" })
	local rng = Rng.new(seed)
	local area = (W / pps) * (H / pps)
	local n = math.clamp(math.floor(area * (opts.density or 3)), 12, 110)
	for _ = 1, n do
		local color: Color3 = rng:weighted(CHIPS)
		local s = rng:range(pps * 0.08, pps * 0.32)
		local f = Core.px(gui, rng:range(0, W - 2), rng:range(0, H - 2), s, s * rng:range(0.45, 1.1), color)
		f.Rotation = rng:range(0, 180)
	end
	return gui
end

---------------------------------------------------------------------------------------------------
-- Monitor screens (each draws into a Frame of pixel size W x H; Core.px / line coordinates are relative to it)
---------------------------------------------------------------------------------------------------
type ScreenFn = (f: Frame, W: number, H: number, rng: Rng) -> ()

local function header(f: Frame, left: string, right: string, rightColor: Color3)
	Core.frame(f, 0, 0, 1, 0.14, NAVY2)
	Core.label(f, left, 0.03, 0.015, 0.62, 0.11, TEXT, { font = MONO })
	Core.label(f, right, 0.6, 0.015, 0.37, 0.11, rightColor, { font = MONO, align = RIGHT })
end

local function ticker(rng: Rng): string
	return rng:pick(Words.tickers)
end

local function screenChart(f: Frame, W: number, H: number, rng: Rng)
	f.BackgroundColor3 = NAVY
	local vals = Core.series(rng, 16, rng:range(40, 300), 0.02, rng:range(-0.006, 0.01))
	local up = vals[#vals] >= vals[1]
	local pct = (vals[#vals] / vals[1] - 1) * 100
	header(f, ticker(rng) .. "  " .. Core.price(vals[#vals]), string.format("%+.2f%%", pct), if up then UP else DOWN)
	for i = 1, 3 do
		Core.frame(f, 0.03, 0.14 + i * 0.2, 0.94, 0.006, DIM, 0.75)
	end
	Core.lineChart(f, W * 0.04, H * 0.22, W * 0.92, H * 0.62, vals, if up then UP else DOWN, math.max(2, H * 0.02))
end

local function screenCandles(f: Frame, W: number, H: number, rng: Rng)
	f.BackgroundColor3 = hex("#0A0F17")
	local chg = rng:normal(0.3, 1.5)
	header(f, ticker(rng) .. " 1D", string.format("%+.2f%%", chg), if chg >= 0 then UP else DOWN)
	Core.frame(f, 0.03, 0.55, 0.94, 0.005, DIM, 0.8)
	Core.candles(f, W * 0.04, H * 0.2, W * 0.92, H * 0.72, rng, 11)
end

local function screenSheet(f: Frame, _W: number, _H: number, rng: Rng)
	f.BackgroundColor3 = hex("#FBFBFA")
	Core.frame(f, 0, 0, 1, 0.12, hex("#1D6B45"))
	Core.label(f, Text.get("screen_model"), 0.03, 0.01, 0.9, 0.1, hex("#FFFFFF"), { font = MONO })
	Core.frame(f, 0, 0.12, 0.16, 0.88, hex("#E9ECEF"))
	Core.frame(f, 0, 0.12, 1, 0.08, hex("#E9ECEF"))
	for i = 1, 7 do
		Core.frame(f, 0, 0.2 + i * 0.1, 1, 0.004, hex("#C9CED3"))
	end
	for i = 1, 4 do
		Core.frame(f, 0.16 + i * 0.2, 0.12, 0.004, 0.88, hex("#C9CED3"))
	end
	local lines = {}
	for _ = 1, 7 do
		table.insert(
			lines,
			string.format(
				"%7.1f  %7.1f  %7.1f  %6.1f%%",
				rng:range(80, 900),
				rng:range(80, 900),
				rng:range(80, 900),
				rng:range(-8, 24)
			)
		)
	end
	Core.label(f, table.concat(lines, "\n"), 0.19, 0.21, 0.8, 0.72, hex("#1F4EA8"), {
		font = MONO,
		yAlign = Enum.TextYAlignment.Top,
	})
	Core.frame(f, 0.36 + rng:int(0, 2) * 0.2, 0.3 + rng:int(0, 5) * 0.1, 0.2, 0.1, hex("#F7E27A"), 0.45)
end

local function screenDeck(f: Frame, W: number, H: number, rng: Rng)
	f.BackgroundColor3 = hex("#FFFFFF")
	Core.frame(f, 0, 0, 1, 0.16, hex("#0B1F3A"))
	Core.label(f, Text.get("screen_deck"), 0.04, 0.02, 0.7, 0.12, hex("#FFFFFF"), { font = Enum.Font.GothamBold })
	Core.label(f, Text.get("screen_deck_sub"), 0.04, 0.2, 0.5, 0.08, hex("#5A6470"), { font = Enum.Font.Gotham })
	for i = 1, 3 do
		Core.frame(f, 0.05, 0.36 + i * 0.13, rng:range(0.25, 0.38), 0.035, hex("#C3C8CE"))
	end
	local bars = 5
	for i = 1, bars do
		local h = rng:range(0.15, 0.5) + i * 0.04
		Core.px(
			f,
			W * (0.52 + (i - 1) * 0.085),
			H * (0.9 - h),
			W * 0.06,
			H * h,
			if i == bars then hex("#C9A54C") else hex("#173459")
		)
	end
	Core.frame(f, 0.5, 0.9, 0.46, 0.006, hex("#5A6470"))
end

local function screenTerminal(f: Frame, _W: number, _H: number, rng: Rng)
	f.BackgroundColor3 = hex("#050505")
	local colors = { hex("#E8B04A"), hex("#3A7BD5"), hex("#C0392B"), hex("#27AE60") }
	local keys = Text.list("screen_keys")
	for i, c in colors do
		local k = Core.frame(f, 0.02 + (i - 1) * 0.16, 0.03, 0.145, 0.1, c)
		Core.label(k, keys[i] or "", 0.08, 0.08, 0.84, 0.84, hex("#0A0A0A"), { font = MONO, align = CENTER })
	end
	local lines = {}
	for _ = 1, 6 do
		table.insert(lines, string.format("%-4s %8.2f  %+5.2f%%", ticker(rng), rng:range(20, 400), rng:normal(0, 1.4)))
	end
	Core.label(f, table.concat(lines, "\n"), 0.03, 0.17, 0.94, 0.8, AMBER, {
		font = MONO,
		yAlign = Enum.TextYAlignment.Top,
	})
end

local function screenEmail(f: Frame, _W: number, _H: number, rng: Rng)
	f.BackgroundColor3 = hex("#F5F7FA")
	Core.frame(f, 0, 0, 1, 0.13, hex("#1F4E8C"))
	Core.label(f, Text.get("screen_inbox") .. " (" .. rng:int(12, 140) .. ")", 0.03, 0.015, 0.6, 0.1, hex("#FFFFFF"))
	for i = 1, 6 do
		local y = 0.15 + (i - 1) * 0.14
		if i % 2 == 0 then
			Core.frame(f, 0, y, 1, 0.14, hex("#E8EDF3"))
		end
		Core.frame(f, 0.06, y + 0.04, rng:range(0.3, 0.55), 0.035, hex("#3B4654"))
		Core.frame(f, 0.06, y + 0.09, rng:range(0.4, 0.8), 0.025, hex("#9AA5B1"))
		if rng:chance(0.4) then
			Core.frame(f, 0.015, y + 0.05, 0.02, 0.04, hex("#2F7BEA"))
		end
	end
end

local function screenQuotes(f: Frame, _W: number, _H: number, rng: Rng)
	f.BackgroundColor3 = NAVY
	Core.label(f, Text.get("screen_watchlist"), 0.03, 0.02, 0.6, 0.11, AMBER, { font = MONO })
	local order = rng:shuffle(Words.tickers)
	for i = 1, 6 do
		local y = 0.15 + (i - 1) * 0.135
		if i % 2 == 0 then
			Core.frame(f, 0, y, 1, 0.135, NAVY2)
		end
		local q = Core.quote(rng, order[i])
		Core.label(f, q, 0.04, y + 0.02, 0.92, 0.1, TEXT, { font = MONO, rich = true })
	end
end

local function screenComps(f: Frame, _W: number, _H: number, rng: Rng)
	f.BackgroundColor3 = hex("#0D1117")
	Core.label(f, Text.get("screen_comps"), 0.03, 0.02, 0.9, 0.1, hex("#9FB3C8"), { font = MONO })
	Core.frame(f, 0.03, 0.14, 0.94, 0.006, DIM, 0.4)
	local lines, colsUp = {}, {}
	for _ = 1, 6 do
		local g = rng:normal(4, 6)
		table.insert(lines, string.format("%-4s %5.1fx %5.1fx", ticker(rng), rng:range(6, 18), rng:range(9, 30)))
		table.insert(colsUp, string.format("%+5.1f%%", g))
	end
	Core.label(
		f,
		table.concat(lines, "\n"),
		0.04,
		0.18,
		0.62,
		0.78,
		TEXT,
		{ font = MONO, yAlign = Enum.TextYAlignment.Top }
	)
	Core.label(f, table.concat(colsUp, "\n"), 0.66, 0.18, 0.3, 0.78, UP, {
		font = MONO,
		yAlign = Enum.TextYAlignment.Top,
		align = RIGHT,
	})
end

local SCREENS: { [string]: ScreenFn } = {
	chart = screenChart,
	candles = screenCandles,
	sheet = screenSheet,
	deck = screenDeck,
	terminal = screenTerminal,
	email = screenEmail,
	quotes = screenQuotes,
	comps = screenComps,
}

Art.screenKinds = { "chart", "sheet", "candles", "email", "deck", "quotes", "comps", "terminal" }

export type MonitorOpts = {
	pps: number?,
	bezel: number?, -- bezel in studs
	maxDistance: number?,
	brightness: number?,
}

-- `count` screens side by side across `part`'s Front face; the part's own colour shows as the bezels.
function Art.monitors(part: BasePart, count: number, kinds: { string }, rng: Rng, o: MonitorOpts?): SurfaceGui
	local opts: MonitorOpts = o or {}
	local pps = opts.pps or 80
	local gui, W, H = Core.surface(part, Enum.NormalId.Front, {
		pps = pps,
		glow = true,
		brightness = opts.brightness or 1.15,
		maxDistance = opts.maxDistance or 75,
		name = "Screens",
	})
	local bez = math.max(2, (opts.bezel or 0.06) * pps)
	local sw = W / count
	for i = 1, count do
		local w, h = sw - bez * 2, H - bez * 2
		local f = Core.px(gui, (i - 1) * sw + bez, bez, w, h, NAVY)
		f.Name = "Screen" .. i
		f.ClipsDescendants = true
		local kind = kinds[((i - 1) % math.max(#kinds, 1)) + 1] or "chart"
		local fn: ScreenFn = SCREENS[kind] or screenChart
		fn(f, math.floor(w + 0.5), math.floor(h + 0.5), rng)
		f:SetAttribute("ScreenKind", kind)
	end
	return gui
end

---------------------------------------------------------------------------------------------------
-- Boards, clocks, art
---------------------------------------------------------------------------------------------------
function Art.painting(part: BasePart, face: Enum.NormalId, variant: number, rng: Rng): SurfaceGui
	local gui, W, H = Core.surface(part, face, { pps = 20, maxDistance = 160, name = "Painting" })
	GuiArt.painting(gui, W, H, variant, rng)
	return gui
end

function Art.clock(part: BasePart, face: Enum.NormalId, city: string, hour: number, minute: number): SurfaceGui
	local gui, W, H = Core.surface(part, face, { pps = 60, maxDistance = 90, name = "Clock" })
	local dial = Core.px(gui, 0, 0, W, W, hex("#F4F1EA"), 1)
	dial.Name = "Dial"
	GuiArt.clockFace(dial, W, W, hour, minute, hex("#1B1C1F"), hex("#F4F1EA"))
	Core.label(gui, city, 0, W / H + 0.02, 1, math.max(0.05, 1 - W / H - 0.04), hex("#E9E2CF"), {
		font = Enum.Font.GothamMedium,
		align = CENTER,
	})
	return gui
end

export type BoardOpts = {
	bg: Color3?,
	ink: Color3?,
	accent: Color3?,
	font: Enum.Font?,
	bodyFont: Enum.Font?,
	glow: boolean?,
	pps: number?,
	align: Enum.TextXAlignment?,
}

function Art.board(part: BasePart, face: Enum.NormalId, title: string, body: string, o: BoardOpts?): SurfaceGui
	local opts: BoardOpts = o or {}
	local gui = Core.surface(part, face, {
		pps = opts.pps or 30,
		glow = opts.glow,
		brightness = 1.1,
		maxDistance = 120,
		name = "Board",
	})
	Core.bg(gui, opts.bg or hex("#14171C"))
	Core.frame(gui, 0.05, 0.2, 0.9, 0.012, opts.accent or hex("#C9A54C"))
	Core.label(gui, title, 0.05, 0.04, 0.9, 0.14, opts.accent or hex("#C9A54C"), {
		font = opts.font or Enum.Font.GothamBold,
		align = opts.align or Enum.TextXAlignment.Left,
	})
	Core.label(gui, body, 0.05, 0.26, 0.9, 0.68, opts.ink or hex("#E8EEF5"), {
		font = opts.bodyFont or MONO,
		yAlign = Enum.TextYAlignment.Top,
		align = opts.align or Enum.TextXAlignment.Left,
	})
	return gui
end

function Art.stripes(
	part: BasePart,
	face: Enum.NormalId,
	a: Color3,
	b: Color3,
	bands: number,
	rotation: number
): SurfaceGui
	local gui = Core.surface(part, face, { pps = 10, maxDistance = 140, name = "Stripes" })
	local f = Core.bg(gui, a)
	Core.stripes(f, { a, b }, bands, rotation)
	return gui
end

-- Faint board-formed joints every `spacing` studs (a cheap way to make a big slab read as poured concrete).
function Art.formwork(part: BasePart, face: Enum.NormalId, spacing: number, color: Color3): SurfaceGui
	local pps = 2
	local gui, W, H = Core.surface(part, face, { pps = pps, maxDistance = 0, name = "Formwork" })
	local step = spacing * pps
	local x = step
	while x < W do
		Core.px(gui, x, 0, 1, H, color, 0.82)
		x += step
	end
	local y = step * 0.5
	while y < H do
		Core.px(gui, 0, y, W, 1, color, 0.88)
		y += step * 0.5
	end
	return gui
end

function Art.indicator(part: BasePart, face: Enum.NormalId, label: string): SurfaceGui
	local gui =
		Core.surface(part, face, { pps = 40, glow = true, brightness = 1.4, maxDistance = 80, name = "Indicator" })
	Core.bg(gui, hex("#08090B"))
	Core.label(gui, label, 0.05, 0.1, 0.9, 0.8, AMBER, { font = MONO, align = CENTER })
	return gui
end

function Art.glow(part: BasePart, face: Enum.NormalId, color: Color3, brightness: number?): SurfaceGui
	local gui = Core.surface(part, face, { pps = 4, glow = true, brightness = brightness or 2, name = "Glow" })
	Core.bg(gui, color)
	return gui
end

function Art.elevatorDoor(part: BasePart, face: Enum.NormalId): SurfaceGui
	local gui = Core.surface(part, face, { pps = 12, maxDistance = 120, name = "Leaves" })
	local f = Core.bg(gui, Color3.new(1, 1, 1), 0.82)
	Core.gradient(f, hex("#FFFFFF"), hex("#9AA3AD"), 0)
	Core.frame(gui, 0.494, 0, 0.012, 1, hex("#30343A"))
	Core.frame(gui, 0, 0.965, 1, 0.035, hex("#30343A"), 0.4)
	return gui
end

function Art.keyboard(pad: BasePart): SurfaceGui
	local gui = Core.surface(pad, Enum.NormalId.Top, { pps = 40, maxDistance = 45, name = "Keyboard" })
	local kb = Core.frame(gui, 0.05, 0.22, 0.62, 0.56, hex("#2A2C30"))
	Core.round(kb, 0, 3)
	local keys = Core.frame(kb, 0.04, 0.12, 0.92, 0.76, hex("#45484E"))
	Core.stripes(keys, { hex("#4C4F55"), hex("#2E3035") }, 9, 90)
	local mouse = Core.frame(gui, 0.78, 0.3, 0.09, 0.42, hex("#2A2C30"))
	Core.round(mouse, 0.5)
	return gui
end

function Art.lockers(part: BasePart, face: Enum.NormalId): SurfaceGui
	local gui, W, H = Core.surface(part, face, { pps = 10, maxDistance = 120, name = "Lockers" })
	local doorW = 2 * 10
	local x = doorW
	while x < W - 2 do
		Core.px(gui, x, 0, 1, H, hex("#B9BBBD"), 0.2)
		x += doorW
	end
	local n = math.floor(W / doorW)
	for i = 0, n - 1 do
		Core.px(gui, i * doorW + doorW - 5, H * 0.42, 2, H * 0.16, hex("#8A8D91"))
	end
	return gui
end

function Art.whiteboard(part: BasePart, face: Enum.NormalId, rng: Rng): SurfaceGui
	local gui, W, H = Core.surface(part, face, { pps = 30, maxDistance = 90, name = "Whiteboard" })
	GuiArt.whiteboard(gui, W, H, rng)
	return gui
end

return Art
