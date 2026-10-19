--!strict
-- Painted SurfaceGui content for the venues (Frames, gradients and text only: no image ids). Bake-safe.
--
--   Paint.surface(part, face, pps, o?) -> (SurfaceGui, W, H)       Gui.Core.surface with a pixels-per-stud density
--   Paint.skyline(gui, W, H, rng, o?)                               the city seen through a window or past a parapet
--       o = { mood = "day" | "dusk" | "night", horizon = 0..1 (from the top), sky = true (paint the sky; false keeps it
--             clear so the real sky shows above a transparent backdrop), view = "high" (above the rooftops) |
--             "street" (looking across at facades), density = 0.5..1.5 }
--   Paint.sky(gui, W, H, rng, mood?)                                a sky with soft clouds (skylights, lanterns)
--   Paint.marble(gui, W, H, rng, vein, count?)                      fine marble veining over a part's own colour
--   Paint.medallion(gui, W, H, colors)                              a floor inlay: rings and an eight-point star
--   Paint.grid(gui, W, H, step, color, transparency?)               seams (tiles, panels, pavers)
--   Paint.cityBelow(gui, W, H, rng, mood?)                          the street grid far below a roof
--   Paint.facade(gui, W, H, rng, color, mood?)                      a curtain-wall face for a nearby tower
--   Paint.fade(obj, keypoints, rotation)                            a transparency gradient on any GuiObject

local Deps = require(script.Parent.Deps)

local Core = Deps.Gui.Core
local hex = Deps.Palette.hex

local Paint = {}

export type SurfOpts = { glow: boolean?, brightness: number?, maxDistance: number?, name: string? }

export type SkylineOpts = {
	mood: string?,
	horizon: number?,
	sky: boolean?,
	view: string?,
	density: number?,
}

function Paint.surface(part: BasePart, face: Enum.NormalId, pps: number, o: SurfOpts?): (SurfaceGui, number, number)
	local opts: SurfOpts = o or {}
	return Core.surface(part, face, {
		pps = pps,
		glow = opts.glow,
		brightness = opts.brightness,
		maxDistance = opts.maxDistance,
		name = opts.name,
	})
end

function Paint.fade(obj: GuiObject, keypoints: { { number } }, rotation: number): UIGradient
	local kps = {}
	for _, k in keypoints do
		table.insert(kps, NumberSequenceKeypoint.new(k[1], k[2]))
	end
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new(kps)
	g.Rotation = rotation
	g.Parent = obj
	return g
end

local function gradient3(obj: GuiObject, a: Color3, b: Color3, c: Color3, mid: number, rotation: number)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, a),
		ColorSequenceKeypoint.new(mid, b),
		ColorSequenceKeypoint.new(1, c),
	})
	g.Rotation = rotation
	g.Parent = obj
end

type Mood = {
	skyTop: Color3,
	skyMid: Color3,
	skyLow: Color3,
	haze: Color3,
	far: Color3,
	mid: { Color3 },
	near: { Color3 },
	mass: Color3,
	massLow: Color3,
	winLit: Color3,
	winDark: Color3,
	litShare: number,
	cloud: Color3?,
}

local MOODS: { [string]: Mood } = {
	day = {
		skyTop = hex("#5E95CC"),
		skyMid = hex("#9CC2E2"),
		skyLow = hex("#E4EEF2"),
		haze = hex("#EEF3F4"),
		far = hex("#AFC1CE"),
		mid = { hex("#7F96A9"), hex("#8A9FB0"), hex("#74899C"), hex("#93A5B3"), hex("#A39A8C") },
		near = { hex("#566B80"), hex("#4D6176"), hex("#62778B"), hex("#6C6458") },
		mass = hex("#9AAEBD"),
		massLow = hex("#6E8497"),
		winLit = hex("#D7E3EC"),
		winDark = hex("#3B4B5C"),
		litShare = 0,
		cloud = hex("#FFFFFF"),
	},
	dusk = {
		skyTop = hex("#27345F"),
		skyMid = hex("#B8687A"),
		skyLow = hex("#F4B57A"),
		haze = hex("#F6C89A"),
		far = hex("#8A6F86"),
		mid = { hex("#4B4A6A"), hex("#544D6B"), hex("#46425E"), hex("#5D5470") },
		near = { hex("#2B2C44"), hex("#26283D"), hex("#33324A"), hex("#2E2A38") },
		mass = hex("#5A4E6A"),
		massLow = hex("#2A2638"),
		winLit = hex("#FFD49A"),
		winDark = hex("#2A2B3E"),
		litShare = 0.35,
		cloud = hex("#F2A88A"),
	},
	night = {
		skyTop = hex("#070D22"),
		skyMid = hex("#18224A"),
		skyLow = hex("#3B3F6E"),
		haze = hex("#5A5A86"),
		far = hex("#2C3156"),
		mid = { hex("#1C2240"), hex("#22284A"), hex("#1A1E36"), hex("#262B48") },
		near = { hex("#11152A"), hex("#0E1224"), hex("#161A30"), hex("#141526") },
		mass = hex("#1A1D36"),
		massLow = hex("#0B0D1A"),
		winLit = hex("#FFD08A"),
		winDark = hex("#151A30"),
		litShare = 0.6,
		cloud = nil,
	},
}

function Paint.mood(id: string?): Mood
	return MOODS[id or "day"] or MOODS.day
end

local function clouds(gui: Instance, W: number, H: number, rng: Deps.RngT, color: Color3, band: number)
	local n = rng:int(3, 6)
	for _ = 1, n do
		local cx = rng:range(0, W)
		local cy = rng:range(H * 0.05, H * band)
		local cw = rng:range(W * 0.12, W * 0.3)
		local ch = cw * rng:range(0.12, 0.22)
		for k = 0, 2 do
			local f = Core.px(
				gui,
				cx + (k - 1) * cw * 0.3 - cw * 0.3,
				cy - ch * (if k == 1 then 0.5 else 0.2),
				cw * 0.6,
				ch * (if k == 1 then 1.3 else 0.9),
				color,
				rng:range(0.45, 0.7)
			)
			Core.round(f, 0.5)
		end
	end
end

local function tower(
	gui: Instance,
	x: number,
	top: number,
	w: number,
	bottom: number,
	color: Color3,
	mood: Mood,
	rng: Deps.RngT,
	near: boolean
)
	local body = Core.px(gui, x, top, w, bottom - top, color)
	body.Name = "Tower"
	-- window columns and floor lines make the curtain wall; at night some floors stay lit
	local cols = Core.px(gui, x + w * 0.07, top + w * 0.08, w * 0.86, bottom - top, mood.winLit, 0.6)
	Core.stripes(cols, { mood.winLit, mood.winDark }, if near then 9 else rng:int(4, 8), 0)
	if near then
		local floors = Core.px(gui, x, top + w * 0.08, w, bottom - top, mood.winDark, 0.65)
		Core.stripes(floors, { mood.winDark, color }, 9, 90)
		local shade = Core.px(gui, x, top, w, bottom - top, hex("#0E141C"), 0.5)
		Paint.fade(shade, { { 0, 1 }, { 0.55, 0.9 }, { 1, 0.3 } }, 0)
	end
	if mood.litShare > 0 then
		local lit = math.floor((if near then 7 else 3) * mood.litShare * rng:range(0.6, 1.4))
		for _ = 1, lit do
			local ww = w * rng:range(0.12, 0.3)
			Core.px(gui, x + rng:range(w * 0.08, w * 0.9 - ww), rng:range(top + w * 0.1, bottom - 2), ww, w * 0.05 + 1, mood.winLit, 0.1)
		end
	end
	-- crowns, setbacks and masts
	local roll = rng:next()
	if roll < 0.35 then
		Core.px(gui, x + w * 0.2, top - w * 0.18, w * 0.6, w * 0.18 + 1, color)
	elseif roll < 0.55 then
		Core.px(gui, x + w * 0.47, top - w * 0.6, math.max(1, w * 0.06), w * 0.6, color)
		if mood.litShare > 0.3 then
			Core.dot(gui, x + w * 0.5, top - w * 0.6, math.max(2, w * 0.08), hex("#FF4A3D"))
		end
	elseif roll < 0.7 then
		Core.px(gui, x + w * 0.1, top - w * 0.3, w * 0.8, w * 0.3 + 1, color)
		Core.px(gui, x + w * 0.3, top - w * 0.52, w * 0.4, w * 0.24, color)
	end
end

function Paint.skyline(gui: Instance, W: number, H: number, rng: Deps.RngT, o: SkylineOpts?)
	local opts: SkylineOpts = o or {}
	local mood = Paint.mood(opts.mood)
	local view = opts.view or "high"
	local hz = math.floor(H * (opts.horizon or (if view == "street" then 0.92 else 0.62)))
	if opts.sky ~= false then
		local sky = Core.px(gui, 0, 0, W, hz + 2, mood.skyTop)
		sky.Name = "Sky"
		gradient3(sky, mood.skyTop, mood.skyMid, mood.skyLow, 0.62, 90)
		if mood.cloud then
			clouds(gui, W, H, rng, mood.cloud, hz / H * 0.7)
		else
			for _ = 1, 18 do
				Core.dot(gui, rng:range(0, W), rng:range(0, hz * 0.6), rng:range(1, 2.4), hex("#E8ECFF"), rng:range(0.2, 0.6))
			end
		end
	end
	-- haze glowing just above the horizon
	local haze = Core.px(gui, 0, hz - H * 0.22, W, H * 0.22 + 2, mood.haze)
	Paint.fade(haze, { { 0, 1 }, { 0.7, 0.5 }, { 1, 0.2 } }, 90)
	-- the city below the horizon
	local mass = Core.px(gui, 0, hz, W, H - hz, mood.mass)
	Core.gradient(mass, mood.mass, mood.massLow, 90)
	if mood.litShare > 0.3 then
		for _ = 1, math.floor(26 * mood.litShare) do
			Core.dot(gui, rng:range(0, W), rng:range(hz + 2, H), rng:range(1.5, 3.5), mood.winLit, rng:range(0.1, 0.5))
		end
	end
	-- distant towers along the horizon
	local x = 0
	while x < W do
		local w = rng:range(W * 0.006, W * 0.022)
		local h = rng:range(H * 0.01, H * 0.1)
		Core.px(gui, x, hz - h, w, h + 2, mood.far)
		x += w + rng:range(0, W * 0.012)
	end
	local density = opts.density or 1
	if view == "street" then
		-- facades across the street: tall masses that run off the top of the view
		local cursor = -rng:range(0, W * 0.05)
		while cursor < W do
			local w = rng:range(W * 0.12, W * 0.24)
			local top = rng:range(-H * 0.2, H * 0.3)
			tower(gui, cursor, top, w, H, mood.near[rng:int(1, #mood.near)], mood, rng, true)
			cursor += w + rng:range(W * 0.02, W * 0.08)
		end
		return
	end
	-- mid towers around eye level (we are high up)
	for _ = 1, math.floor(14 * density) do
		local w = rng:range(W * 0.025, W * 0.06)
		local px = rng:range(-w * 0.3, W - w * 0.7)
		local top = hz - rng:range(H * 0.04, H * 0.34)
		tower(gui, px, top, w, H, mood.mid[rng:int(1, #mood.mid)], mood, rng, false)
	end
	-- a few near skyscrapers rising above us
	local slots = rng:shuffle({ 0.04, 0.22, 0.42, 0.62, 0.8 })
	for i = 1, rng:int(2, 4) do
		local w = rng:range(W * 0.07, W * 0.12)
		local px = slots[i] * W + rng:range(-W * 0.03, W * 0.03)
		local top = rng:range(H * 0.04, H * 0.34)
		tower(gui, px, top, w, H, mood.near[rng:int(1, #mood.near)], mood, rng, true)
	end
end

function Paint.sky(gui: Instance, W: number, H: number, rng: Deps.RngT, moodId: string?)
	local mood = Paint.mood(moodId)
	local sky = Core.px(gui, 0, 0, W, H, mood.skyMid)
	sky.Name = "Sky"
	gradient3(sky, mood.skyTop, mood.skyMid, mood.skyLow, 0.5, 90)
	if mood.cloud then
		clouds(gui, W, H, rng, mood.cloud, 0.9)
		clouds(gui, W, H, rng, mood.cloud, 0.9)
	end
end

function Paint.marble(gui: Instance, W: number, H: number, rng: Deps.RngT, vein: Color3, count: number?)
	for _ = 1, count or 10 do
		local x1, y1 = rng:range(0, W), rng:range(0, H)
		local len = rng:range(math.min(W, H) * 0.3, math.max(W, H) * 0.6)
		local a = rng:range(-0.7, 0.7) + (if W > H then 0 else math.pi / 2)
		local segs = rng:int(2, 4)
		for _ = 1, segs do
			local x2 = x1 + math.cos(a) * len / segs
			local y2 = y1 + math.sin(a) * len / segs
			Core.line(gui, x1, y1, x2, y2, rng:range(1, 2.5), vein, rng:range(0.35, 0.7))
			x1, y1 = x2, y2
			a += rng:range(-0.5, 0.5)
		end
	end
end

function Paint.medallion(gui: Instance, W: number, H: number, colors: { Color3 })
	local cx, cy = W / 2, H / 2
	local r = math.min(W, H) * 0.48
	for i, c in colors do
		local d = r * 2 * (1 - (i - 1) * 0.16)
		if d > 4 then
			Core.dot(gui, cx, cy, d, c)
		end
	end
	-- an eight-point compass star
	local star = colors[#colors] or hex("#C9A54C")
	for k = 0, 3 do
		local f = Core.px(gui, cx - r * 0.06, cy - r * 0.78, r * 0.12, r * 1.56, star)
		f.AnchorPoint = Vector2.new(0, 0)
		f.Rotation = k * 45
	end
end

function Paint.grid(gui: Instance, W: number, H: number, step: number, color: Color3, transparency: number?)
	local t = transparency or 0.5
	local x = step
	while x < W do
		Core.px(gui, x, 0, 1, H, color, t)
		x += step
	end
	local y = step
	while y < H do
		Core.px(gui, 0, y, W, 1, color, t)
		y += step
	end
end

function Paint.cityBelow(gui: Instance, W: number, H: number, rng: Deps.RngT, moodId: string?)
	local night = moodId == "night" or moodId == "dusk"
	local base = if night then hex("#151827") else hex("#6E7781")
	local street = if night then hex("#FFC67A") else hex("#A9B0B6")
	local blocks = if night
		then { hex("#232842"), hex("#1C2036"), hex("#2A2F4A") }
		else { hex("#5D6670"), hex("#8A939B"), hex("#7A7368"), hex("#4E5862") }
	Core.bg(gui, base)
	local step = math.max(24, W / 16)
	local x = rng:range(0, step)
	while x < W do
		Core.px(gui, x, 0, math.max(2, step * 0.12), H, street, if night then 0.55 else 0.2)
		x += step * rng:range(0.8, 1.3)
	end
	local y = rng:range(0, step)
	while y < H do
		Core.px(gui, 0, y, W, math.max(2, step * 0.12), street, if night then 0.6 else 0.25)
		y += step * rng:range(0.8, 1.3)
	end
	for _ = 1, 60 do
		local s = rng:range(step * 0.25, step * 0.7)
		Core.px(gui, rng:range(0, W), rng:range(0, H), s, s * rng:range(0.6, 1.4), blocks[rng:int(1, #blocks)], 0.05)
	end
end

-- A curtain-wall facade filling the canvas: mullion columns, floor bands and a few lit or shaded panes.
function Paint.facade(gui: Instance, W: number, H: number, rng: Deps.RngT, color: Color3, moodId: string?)
	local mood = Paint.mood(moodId)
	Core.bg(gui, color)
	local cols = Core.px(gui, W * 0.03, 0, W * 0.94, H, mood.winLit, 0.55)
	Core.stripes(cols, { mood.winLit, mood.winDark }, rng:int(6, 9), 0)
	local floors = Core.px(gui, 0, 0, W, H, mood.winDark, 0.6)
	Core.stripes(floors, { mood.winDark, color }, 9, 90)
	local shade = Core.px(gui, 0, 0, W, H, hex("#0E141C"), 0.6)
	Paint.fade(shade, { { 0, 0.95 }, { 1, 0.4 } }, 90)
end

return Paint
