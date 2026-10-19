--!strict
-- Building masses and facades for the Street. Geometry is described in a LOT frame (Plan.frame): origin at the
-- front-centre on the sidewalk (y = 0 there is the sidewalk top), LookVector out of the front toward the street,
-- local +Z into the building, local X across the frontage. Towers stay cheap at height: one solid core per tier
-- plus one facade per visible face (an opaque glass sheet, stone piers or brass mullions, floor bands and a few lit
-- panes tagged "LitWindow"). Bake-safe.
--
--   Mass.LOOKS[id] / Mass.look(id, overrides?) -> FacadeLook     facade recipes (stone, brick, curtain walls)
--   Mass.faceCF(side, box, out?) -> (CFrame, width)                local plane of one face (LookVector out)
--   Mass.grid(parent, cf, w, h, look, seed, opts?) -> Model        a facade on a plane (cf in world space)
--   Mass.tier(parent, frame, box, look, opts) -> Part              solid core + facades on the visible faces
--   Mass.slab(parent, frame, box, color, mat, collide?) -> Part     any box in lot space (cornices, plinths, roofs)
--   Mass.at(frame, x, y, z) -> CFrame                              lot-local point to world CFrame
--
-- box = { x0, x1, z0, z1, y0, y1 } in lot space. A tier's opts.hidden[side] is the height (lot y) below which that
-- face is hidden by a neighbour: windows start above it, and a face hidden all the way up gets none.

local Deps = require(script.Parent.Deps)
local Look = require(script.Parent.Look)

local Kit = Deps.Kit
local Rng = Deps.Rng
local M = Enum.Material

local Mass = {}

export type Box = { x0: number, x1: number, z0: number, z1: number, y0: number, y1: number }

export type FacadeLook = {
	core: Color3,
	coreMat: Enum.Material,
	glass: Color3,
	refl: number?,
	pier: Color3,
	pierMat: Enum.Material,
	pierW: number,
	band: Color3,
	bandMat: Enum.Material,
	bandH: number,
	depth: number,
	bay: number,
	storey: number,
	rowEvery: number?, -- floor bands every n storeys (1 = every storey)
	lit: number, -- fraction of lit panes
	litColor: Color3?,
	curtain: boolean?, -- Kit.windowGrid curtain wall (thin equal mullions, glass in front)
	glassT: number?, -- curtain walls only
	vary: number?, -- colour variation between buildings (0..0.1)
}

local function L(t: { [string]: any }): FacadeLook
	return (t :: any) :: FacadeLook
end

local STONE = { pierW = 2.6, bandH = 3.4, depth = 1.3, bay = 9, storey = 15, lit = 0.05, vary = 0.05, refl = 0.18 }

local function stone(core: Color3, mat: Enum.Material, glass: Color3, extra: { [string]: any }?): FacadeLook
	local t: { [string]: any } = table.clone(STONE)
	t.core, t.coreMat, t.glass = core, mat, glass
	t.pier, t.pierMat, t.band, t.bandMat = core, mat, core, mat
	if extra then
		for k, v in extra do
			t[k] = v
		end
	end
	return L(t)
end

local function curtain(glass: Color3, mullion: Color3, extra: { [string]: any }?): FacadeLook
	local t: { [string]: any } = {
		curtain = true,
		core = Kit.shade(glass, -0.55),
		coreMat = M.Glass,
		glass = glass,
		glassT = 0.12,
		refl = 0.32,
		pier = mullion,
		pierMat = M.Metal,
		pierW = 0.55,
		band = mullion,
		bandMat = M.Metal,
		bandH = 0.55,
		depth = 0.7,
		bay = 6,
		storey = 15,
		lit = 0.035,
		vary = 0.03,
	}
	if extra then
		for k, v in extra do
			t[k] = v
		end
	end
	return L(t)
end

Mass.LOOKS = {
	-- stone (punched windows between piers and floor bands)
	limestone = stone(Look.limestone, M.Limestone, Look.glassNavy),
	limestoneWarm = stone(Look.limestoneWarm, M.Limestone, Look.glassSmoke, { litColor = Look.warmLight }),
	sandstone = stone(Look.sandstone, M.Sandstone, Look.glassSmoke),
	marble = stone(Look.marble, M.Marble, Look.glassNavy, { pierW = 2.2 }),
	granite = stone(Look.granite, M.Granite, Look.glassBlack, { pierW = 3, bandH = 2.6 }),
	basalt = stone(Look.blackGranite, M.Basalt, Look.glassBronze, {
		band = Look.bronze,
		bandMat = M.Metal,
		bandH = 2.2,
		litColor = Look.lampGlow,
	}),
	-- Art Deco: deep limestone piers with dark bronze spandrels between them
	deco = stone(Look.limestone, M.Limestone, Look.glassSmoke, {
		pierW = 3.2,
		depth = 2.2,
		bay = 8,
		band = Look.bronzeDark,
		bandMat = M.Metal,
		bandH = 4.2,
		litColor = Look.warmLight,
	}),
	-- stone piers, bronze floor bands (elite boutiques, the PE tower)
	bronzeStone = stone(Look.limestoneWarm, M.Limestone, Look.glassBronze, {
		band = Look.bronze,
		bandMat = M.Metal,
		bandH = 2.4,
		litColor = Look.lampGlow,
	}),
	brownstone = stone(Look.brownstone, M.Sandstone, Look.glassSmoke, {
		pierW = 3.4,
		bandH = 4.4,
		bay = 8,
		storey = 13,
		band = Look.limestoneDark,
		bandMat = M.Limestone,
		litColor = Look.lampGlow,
		lit = 0.12,
	}),
	brick = stone(Look.brick, M.Brick, Look.glassSmoke, {
		pierW = 3.2,
		bandH = 4,
		bay = 8,
		storey = 13,
		band = Look.limestoneDark,
		bandMat = M.Limestone,
		lit = 0.08,
		litColor = Look.lampGlow,
	}),
	loft = stone(Look.brickRed, M.Brick, Look.glassSmoke, {
		pierW = 3.6,
		bandH = 3.4,
		bay = 10,
		storey = 16,
		lit = 0.12,
		litColor = Look.lampGlow,
	}),
	-- white aluminium ribbon bands with slim glass mullions (Anaeio)
	ribbon = stone(Look.white, M.SmoothPlastic, Look.glassSilver, {
		pierW = 0.6,
		pierMat = M.Metal,
		pier = Look.aluminum,
		bandH = 4.6,
		depth = 1.6,
		bay = 7,
		band = Look.white,
		bandMat = M.SmoothPlastic,
		lit = 0.05,
		litColor = Look.coolLight,
		refl = 0.35,
	}),
	-- curtain walls
	glass = curtain(Look.glass, Look.aluminum),
	glassSilver = curtain(Look.glassSilver, Look.steel, { bay = 5 }),
	glassBlue = curtain(Look.glassTint, Look.aluminum),
	glassGreen = curtain(Look.glassGreen, Look.aluminum, { litColor = Look.coolLight }),
	glassTeal = curtain(Look.glassTeal, Look.steelDark),
	glassDark = curtain(Look.glassSmoke, Look.steelDark, { refl = 0.4, lit = 0.03 }),
	glassBlack = curtain(Look.glassBlack, Look.iron, { refl = 0.45, lit = 0.025, litColor = Look.coolLight }),
	glassBrass = curtain(Look.glassNavy, Look.brass, { refl = 0.35, litColor = Look.warmLight }),
	glassBronze = curtain(Look.glassBronze, Look.bronze, { refl = 0.3, litColor = Look.lampGlow }),
} :: { [string]: FacadeLook }

function Mass.look(id: string, overrides: { [string]: any }?): FacadeLook
	local base = Mass.LOOKS[id] or Mass.LOOKS.limestone
	if not overrides then
		return base
	end
	local t: { [string]: any } = table.clone(base :: any)
	for k, v in overrides do
		t[k] = v
	end
	return L(t)
end

-- A slightly different tone of the same look per building (deterministic): the district never looks pasted.
function Mass.vary(look: FacadeLook, seed: any): FacadeLook
	local amt = look.vary or 0
	if amt <= 0 then
		return look
	end
	local rng = Rng.new(seed)
	local f = rng:range(-amt, amt)
	local t: { [string]: any } = table.clone(look :: any)
	t.core = Kit.shade(look.core, f)
	t.pier = Kit.shade(look.pier, f)
	if look.band ~= look.pier then
		t.band = Kit.shade(look.band, f * 0.5)
	else
		t.band = t.pier
	end
	return L(t)
end

---------------------------------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------------------------------
function Mass.at(frame: CFrame, x: number, y: number, z: number): CFrame
	return frame * CFrame.new(x, y, z)
end

local ROT_BACK = CFrame.Angles(0, math.pi, 0)
local ROT_LEFT = CFrame.Angles(0, math.pi / 2, 0) -- LookVector -X
local ROT_RIGHT = CFrame.Angles(0, -math.pi / 2, 0) -- LookVector +X

-- The plane of one face of `box` (lot space), pushed `out` studs outward, with LookVector pointing out of the
-- building. Returns the plane's centre CFrame and the face width.
function Mass.faceCF(side: string, b: Box, out: number?): (CFrame, number)
	local o = out or 0
	local cy = (b.y0 + b.y1) / 2
	local cx = (b.x0 + b.x1) / 2
	local cz = (b.z0 + b.z1) / 2
	if side == "front" then
		return CFrame.new(cx, cy, b.z0 - o), b.x1 - b.x0
	elseif side == "back" then
		return CFrame.new(cx, cy, b.z1 + o) * ROT_BACK, b.x1 - b.x0
	elseif side == "left" then
		return CFrame.new(b.x0 - o, cy, cz) * ROT_LEFT, b.z1 - b.z0
	end
	return CFrame.new(b.x1 + o, cy, cz) * ROT_RIGHT, b.z1 - b.z0
end

Mass.SIDES = { "front", "left", "right", "back" }

function Mass.slab(parent: Instance, frame: CFrame, b: Box, color: Color3, mat: Enum.Material, collide: boolean?): Part
	local size = Vector3.new(math.abs(b.x1 - b.x0), math.abs(b.y1 - b.y0), math.abs(b.z1 - b.z0))
	local cf = frame * CFrame.new((b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2, (b.z0 + b.z1) / 2)
	if collide == false then
		return Kit.detail(parent, cf, size, color, mat)
	end
	return Kit.block(parent, cf, size, color, mat)
end

---------------------------------------------------------------------------------------------------
-- Facades
---------------------------------------------------------------------------------------------------
export type GridOpts = {
	noBottom: boolean?, -- skip the lowest floor band (a base or another tier sits below)
	noTop: boolean?, -- skip the highest band (a cornice covers it)
	cols: number?,
	rows: number?,
	lit: number?,
}

local function litPane(m: Instance, cf: CFrame, w: number, h: number, color: Color3)
	if w <= 0.4 or h <= 0.4 then
		return
	end
	local pane = Kit.detail(m, cf, Vector3.new(w, h, 0.1), color, M.Neon)
	pane.Transparency = 0.4
	pane.CastShadow = false
	pane:AddTag("LitWindow")
end

-- A facade on the plane `cf` (world space, LookVector out): `w` wide and `h` tall, centred on cf.
function Mass.grid(parent: Instance, cf: CFrame, w: number, h: number, look: FacadeLook, seed: any, o: GridOpts?): Model
	local opts: GridOpts = o or {}
	local every = look.rowEvery or 1
	local cols = opts.cols or math.max(1, math.floor(w / look.bay + 0.5))
	local rows = opts.rows or math.max(1, math.floor(h / (look.storey * every) + 0.5))
	local lit = opts.lit or look.lit
	local litColor = look.litColor or Look.warmLight
	if look.curtain then
		local g = Kit.windowGrid(parent, {
			cf = cf,
			width = w,
			height = h,
			cols = cols,
			rows = rows,
			glassColor = look.glass,
			frameColor = look.pier,
			frameMaterial = look.pierMat,
			frameThickness = look.pierW,
			depth = look.depth,
			glassTransparency = look.glassT or 0.12,
			glassReflectance = look.refl or 0.3,
			litChance = lit,
			litColor = litColor,
			seed = seed,
		})
		g.Name = "Facade"
		return g
	end
	local m = Kit.model(parent, "Facade")
	local glass = Kit.block(m, cf, Vector3.new(w, h, 0.2), look.glass, M.Glass, {
		Reflectance = look.refl or 0.18,
		CastShadow = false,
	})
	glass.Name = "Glass"
	local d = look.depth
	local pw = w / cols
	for i = 0, cols do
		local x = -w / 2 + pw * i
		Kit.detail(m, cf * CFrame.new(x, 0, -d / 2), Vector3.new(look.pierW, h, d), look.pier, look.pierMat)
	end
	local ph = h / rows
	local bd = d * 0.8
	for j = 0, rows do
		if (j == 0 and opts.noBottom) or (j == rows and opts.noTop) then
			continue
		end
		local y = -h / 2 + ph * j
		Kit.detail(
			m,
			cf * CFrame.new(0, y, -bd / 2),
			Vector3.new(w + look.pierW, look.bandH, bd),
			look.band,
			look.bandMat
		)
	end
	if lit > 0 then
		local rng = Rng.new(seed)
		local paneW = pw - look.pierW - 0.4
		local paneH = ph - look.bandH - 0.4
		for j = 0, rows - 1 do
			for i = 0, cols - 1 do
				if rng:chance(lit) then
					local x = -w / 2 + pw * (i + 0.5)
					local y = -h / 2 + ph * (j + 0.5)
					litPane(m, cf * CFrame.new(x, y, -0.16), paneW, paneH, litColor)
				end
			end
		end
	end
	return m
end

export type TierOpts = {
	hidden: { [string]: number }?, -- per side: lot height below which the face is hidden (math.huge = all)
	seed: any,
	name: string?,
	noBottom: boolean?, -- the tier sits on another tier or a base: skip the lowest floor band
	noTop: boolean?,
	lit: number?,
	cols: { [string]: number }?, -- per side bay override
}

-- A solid core for `box` with a facade on every face that isn't hidden. Returns the core part.
function Mass.tier(parent: Instance, frame: CFrame, b: Box, look: FacadeLook, opts: TierOpts): Part
	local model = Kit.model(parent, opts.name or "Tier")
	local core = Mass.slab(model, frame, b, look.core, look.coreMat)
	core.Name = "Mass"
	local hidden = opts.hidden or {}
	local out = if look.curtain then 0.45 else 0.11
	for _, side in Mass.SIDES do
		local hid = hidden[side]
		if hid == nil then
			hid = if side == "back" then math.huge else 0
		end
		local y0 = math.max(b.y0, hid)
		if b.y1 - y0 < look.storey * 0.75 then
			continue
		end
		local fb: Box = { x0 = b.x0, x1 = b.x1, z0 = b.z0, z1 = b.z1, y0 = y0, y1 = b.y1 }
		local lcf, width = Mass.faceCF(side, fb, out)
		local h = b.y1 - y0
		-- keep whole storeys from the top down so floor bands line up between faces
		local storeys = math.max(1, math.floor(h / look.storey + 0.25))
		local hh = math.min(h, storeys * look.storey)
		local shift = (h - hh) / 2
		local cols = if opts.cols then opts.cols[side] else nil
		Mass.grid(
			model,
			frame * lcf * CFrame.new(0, shift, 0),
			width,
			hh,
			look,
			Deps.Hash.u32("facade", tostring(opts.seed), side, math.floor(b.y0)),
			{
				noBottom = opts.noBottom or y0 > b.y0,
				noTop = opts.noTop,
				lit = opts.lit,
				cols = cols,
				rows = math.max(1, math.floor(storeys / (look.rowEvery or 1) + 0.5)),
			}
		)
	end
	return core
end

-- A projecting cornice/parapet slab around the top of a box (lot space): `over` studs past each face.
function Mass.cornice(
	parent: Instance,
	frame: CFrame,
	b: Box,
	y: number,
	h: number,
	over: number,
	color: Color3,
	mat: Enum.Material
): Part
	return Mass.slab(parent, frame, {
		x0 = b.x0 - over,
		x1 = b.x1 + over,
		z0 = b.z0 - over,
		z1 = b.z1 + over,
		y0 = y,
		y1 = y + h,
	}, color, mat, false)
end

-- Rooftop mechanical penthouse and an antenna mast (cheap skyline detail). Returns the roof top height.
function Mass.roofKit(parent: Instance, frame: CFrame, b: Box, seed: any, color: Color3?): number
	local rng = Rng.new(seed)
	local w, d = b.x1 - b.x0, b.z1 - b.z0
	local pw, pd = w * rng:range(0.3, 0.5), d * rng:range(0.3, 0.5)
	local cx = (b.x0 + b.x1) / 2 + rng:range(-w * 0.15, w * 0.15)
	local cz = (b.z0 + b.z1) / 2 + rng:range(-d * 0.1, d * 0.1)
	local ph = rng:range(6, 11)
	local c = color or Look.slate
	Mass.slab(
		parent,
		frame,
		{ x0 = cx - pw / 2, x1 = cx + pw / 2, z0 = cz - pd / 2, z1 = cz + pd / 2, y0 = b.y1, y1 = b.y1 + ph },
		c,
		M.Concrete,
		false
	).Name =
		"Penthouse"
	if rng:chance(0.6) then
		local mh = rng:range(14, 30)
		Kit.cylinder(parent, frame * CFrame.new(cx, b.y1 + ph + mh / 2, cz), mh, 0.6, Look.steelDark, M.Metal, {
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		local beacon = Kit.ball(parent, frame * CFrame.new(cx, b.y1 + ph + mh, cz), 1, Look.neonRed, M.Neon, {
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		beacon.Name = "Beacon"
		beacon:AddTag("StreetLight")
		return b.y1 + ph + mh
	end
	return b.y1 + ph
end

return Mass
