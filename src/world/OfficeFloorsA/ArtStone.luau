--!strict
-- Stonework, street facades and deal tombstones for the office templates (SurfaceGui Frames and TextLabels only, no
-- image ids; bake-safe). Re-exported by Art (Art.tiles, Art.veins, Art.facade, Art.tombstone):
--   Stone.tiles(part, face, sx, sy, color, opts?)    stone joints every sx/sy studs (lobby floors, cladding)
--   Stone.veins(part, face, seed, color, opts?)      soft marble veining
--   Stone.facade(part, face, opts)                   a painted street-level building front (shop band + windows)
--   Stone.tombstone(part, face, title, seed)         a lucite deal tombstone's engraving

local Deps = require(script.Parent.Deps)

local Core = Deps.Gui.Core
local Rng = Deps.Rng
local hex = Deps.Palette.hex

local MONO = Core.MONO
local CENTER = Enum.TextXAlignment.Center

local Stone = {}

---------------------------------------------------------------------------------------------------
-- Lobby stonework, street facades and deal tombstones
---------------------------------------------------------------------------------------------------
-- Face size in studs (width, height) as a SurfaceGui sees it.
local function faceSize(part: BasePart, face: Enum.NormalId): (number, number)
	local s = part.Size
	if face == Enum.NormalId.Front or face == Enum.NormalId.Back then
		return s.X, s.Y
	elseif face == Enum.NormalId.Left or face == Enum.NormalId.Right then
		return s.Z, s.Y
	end
	return s.X, s.Z
end

-- Pixels per stud that keep the canvas under `limit` pixels on its longer side (big faces stay cheap).
local function fitPps(part: BasePart, face: Enum.NormalId, want: number, limit: number?): number
	local w, h = faceSize(part, face)
	local cap = (limit or 1000) / math.max(w, h, 1)
	return math.max(0.5, math.min(want, cap))
end

export type TileOpts = { pps: number?, transparency: number?, offsetX: number?, offsetY: number?, maxDistance: number? }

-- Joints every sx (across) and sy (down) studs: one 1 px line each, so even a big floor stays a few dozen frames.
function Stone.tiles(
	part: BasePart,
	face: Enum.NormalId,
	sx: number,
	sy: number,
	color: Color3,
	o: TileOpts?
): SurfaceGui
	local opts: TileOpts = o or {}
	local pps = fitPps(part, face, opts.pps or 8)
	local gui, W, H = Core.surface(part, face, { pps = pps, maxDistance = opts.maxDistance or 0, name = "Tiles" })
	local t = opts.transparency or 0.55
	local x = ((opts.offsetX or 0) % sx) * pps
	if x < 1 then
		x += sx * pps
	end
	while x < W - 1 do
		Core.px(gui, x, 0, 1, H, color, t)
		x += sx * pps
	end
	local y = ((opts.offsetY or 0) % sy) * pps
	if y < 1 then
		y += sy * pps
	end
	while y < H - 1 do
		Core.px(gui, 0, y, W, 1, color, t)
		y += sy * pps
	end
	return gui
end

export type VeinOpts = { count: number?, pps: number?, transparency: number?, maxDistance: number? }

-- Soft veins drifting across a stone face (long thin rotated frames, mostly diagonal).
function Stone.veins(part: BasePart, face: Enum.NormalId, seed: any, color: Color3, o: VeinOpts?): SurfaceGui
	local opts: VeinOpts = o or {}
	local pps = fitPps(part, face, opts.pps or 10)
	local gui, W, H = Core.surface(part, face, { pps = pps, maxDistance = opts.maxDistance or 160, name = "Veins" })
	local rng = Rng.new(seed)
	local n = opts.count or math.clamp(math.floor((W + H) / (pps * 3)), 6, 22)
	for _ = 1, n do
		local x = rng:range(-W * 0.1, W * 1.1)
		local y = rng:range(-H * 0.1, H * 1.1)
		local len = rng:range(0.25, 0.7) * math.max(W, H)
		local ang = math.rad(rng:range(20, 65) * (if rng:chance(0.5) then 1 else -1))
		local thick = rng:range(1, 2.6)
		Core.line(
			gui,
			x,
			y,
			x + math.cos(ang) * len,
			y + math.sin(ang) * len,
			thick,
			color,
			opts.transparency or rng:range(0.45, 0.8)
		)
		-- a hairline branch off the main vein
		if rng:chance(0.6) then
			local bx, by = x + math.cos(ang) * len * 0.4, y + math.sin(ang) * len * 0.4
			local b = ang + math.rad(rng:range(-35, 35))
			Core.line(gui, bx, by, bx + math.cos(b) * len * 0.35, by + math.sin(b) * len * 0.35, 1, color, 0.75)
		end
	end
	return gui
end

export type FacadeOpts = {
	seed: any,
	base: Color3, -- stone / cladding colour
	window: Color3?,
	floorH: number?, -- studs per storey
	bays: number?, -- window columns (rounded to groups of 4)
	shopH: number?, -- ground-floor shopfront height in studs
	shop: string?, -- shop sign text
	awning: Color3?,
	litChance: number?,
}

-- A street-level building front seen across the road: ground-floor shopfront with a sign band and warm interior,
-- a grid of windows above (column stripes + one spandrel per storey) and a cornice.
function Stone.facade(part: BasePart, face: Enum.NormalId, o: FacadeOpts): SurfaceGui
	local pps = fitPps(part, face, 6, 960)
	local gui, W, H = Core.surface(part, face, { pps = pps, maxDistance = 0, name = "Facade" })
	local rng = Rng.new(o.seed)
	local base = o.base
	local win = o.window or hex("#3E5466")
	Core.bg(gui, base)
	local shopH = (o.shopH or 12) * pps
	local floorH = (o.floorH or 10) * pps
	local top = H - shopH
	-- cornice and parapet
	Core.px(gui, 0, 0, W, pps * 1.6, base:Lerp(Color3.new(0, 0, 0), 0.25))
	Core.px(gui, 0, pps * 1.6, W, pps * 0.6, base:Lerp(Color3.new(1, 1, 1), 0.25))
	-- window columns in groups of 4 (Core.stripes takes at most 9 bands: pier, window, ..., pier)
	local groups = math.max(1, math.floor(((o.bays or 8) + 2) / 4))
	local gw = W / groups
	for g = 0, groups - 1 do
		local f = Core.px(gui, g * gw + pps * 0.6, pps * 3, gw - pps * 1.2, top - pps * 4, win)
		Core.stripes(f, { base, win }, 9, 0)
	end
	-- spandrels: one band per storey hides the window grid between floors
	local y = pps * 3 + floorH * 0.72
	while y < top - pps * 2 do
		Core.px(gui, 0, y, W, floorH * 0.28, base:Lerp(Color3.new(0, 0, 0), 0.08))
		y += floorH
	end
	-- a few lit windows
	local cols = groups * 4
	local cw = (W - pps * 1.2) / cols
	local lit = o.litChance or 0.12
	local row = pps * 3
	while row + floorH * 0.7 < top - pps * 2 do
		for c = 0, cols - 1 do
			if rng:chance(lit) then
				Core.px(
					gui,
					pps * 0.6 + c * cw + cw * 0.2,
					row + floorH * 0.1,
					cw * 0.6,
					floorH * 0.55,
					hex("#F4DDB0"),
					0.25
				)
			end
		end
		row += floorH
	end
	-- ground floor: sign band, awning, glowing shop window and a door
	local band = Core.px(gui, 0, top, W, pps * 2.2, o.awning or hex("#1F4D3A"))
	if o.shop and o.shop ~= "" then
		Core.label(
			band,
			o.shop,
			0.08,
			0.12,
			0.84,
			0.76,
			hex("#F3E9D2"),
			{ font = Enum.Font.GothamBold, align = CENTER }
		)
	end
	local glass = Core.px(gui, pps * 1.2, top + pps * 2.4, W - pps * 2.4, shopH - pps * 3, hex("#2A2F33"))
	Core.gradient(glass, hex("#E9C27E"), hex("#3A3128"), 90)
	local doorX = rng:range(0.2, 0.7) * W
	Core.px(gui, doorX, top + pps * 4.5, pps * 3.5, shopH - pps * 5, hex("#1B1D20"))
	Core.px(gui, 0, H - pps * 0.6, W, pps * 0.6, base:Lerp(Color3.new(0, 0, 0), 0.4))
	return gui
end

-- Engraving on a lucite deal tombstone: deal type, a rule and a few lines of "terms".
function Stone.tombstone(part: BasePart, face: Enum.NormalId, title: string, seed: any): SurfaceGui
	local gui = Core.surface(part, face, { pps = 60, maxDistance = 40, name = "Tombstone" })
	local rng = Rng.new(seed)
	local ink = hex("#2F3A44")
	Core.label(
		gui,
		title,
		0.1,
		0.08,
		0.8,
		0.26,
		ink,
		{ font = Enum.Font.GothamBlack, align = CENTER, transparency = 0.15 }
	)
	Core.frame(gui, 0.2, 0.4, 0.6, 0.02, ink, 0.4)
	Core.label(
		gui,
		string.format("$%d,%03d,000,000", rng:int(1, 9), rng:int(0, 999)),
		0.08,
		0.48,
		0.84,
		0.16,
		ink,
		{ font = MONO, align = CENTER, transparency = 0.25 }
	)
	for i = 1, 2 do
		Core.frame(gui, 0.22, 0.7 + i * 0.09, rng:range(0.4, 0.56), 0.025, ink, 0.55)
	end
	return gui
end

return Stone
