--!strict
-- Shared builder context for Assets/Props and Assets/Signs. Bake-safe (contracts §13).
--
-- A prop builder receives a Ctx whose helpers take LOCAL CFrames: (0, 0, 0) is the prop's floor contact
-- point, +Y is up and the prop's front faces -Z. Helpers convert to world space with ctx.cf, so builders
-- never multiply CFrames themselves.
--
--   part / cyl / ball / wedge     collidable, anchored
--   detail / dcyl / dball / ...   non-colliding trim (CanCollide/CanQuery/CanTouch off)
--   glow                          non-colliding Neon (use sparingly: lamp lenses, LEDs, embers)
--   glass                         Glass material, transparent, optionally collidable
--   seat                          a Seat when opts.seat == true (players can sit), otherwise a Part

local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local Rng = require(script.Parent.Parent.Parent.Util.Rng)

local Common = {}

export type Opts = { [string]: any }

export type Ctx = {
	id: string,
	m: Instance,
	cf: CFrame,
	o: Opts,
	rng: Rng.Rng,
	usePart: BasePart?,
	at: (lcf: CFrame) -> CFrame,
	part: (lcf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?) -> Part,
	detail: (lcf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?) -> Part,
	cyl: (lcf: CFrame, h: number, d: number, color: Color3, mat: Enum.Material?) -> Part,
	dcyl: (lcf: CFrame, h: number, d: number, color: Color3, mat: Enum.Material?) -> Part,
	cylX: (lcf: CFrame, len: number, d: number, color: Color3, mat: Enum.Material?) -> Part,
	dcylX: (lcf: CFrame, len: number, d: number, color: Color3, mat: Enum.Material?) -> Part,
	cylZ: (lcf: CFrame, len: number, d: number, color: Color3, mat: Enum.Material?) -> Part,
	dcylZ: (lcf: CFrame, len: number, d: number, color: Color3, mat: Enum.Material?) -> Part,
	ball: (lcf: CFrame, d: number, color: Color3, mat: Enum.Material?) -> Part,
	dball: (lcf: CFrame, d: number, color: Color3, mat: Enum.Material?) -> Part,
	wedge: (lcf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?) -> WedgePart,
	dwedge: (lcf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?) -> WedgePart,
	cwedge: (lcf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?) -> CornerWedgePart,
	glow: (lcf: CFrame, size: Vector3, color: Color3, transparency: number?) -> Part,
	glass: (lcf: CFrame, size: Vector3, color: Color3, transparency: number?, collide: boolean?) -> Part,
	seat: (lcf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?) -> BasePart,
	light: (part: BasePart, kind: string, props: { [string]: any }?) -> Light,
	use: (part: BasePart) -> (),
	sub: (id: string, lcf: CFrame, opts: Opts?) -> Model,
	color: (key: string, default: Color3) -> Color3,
	num: (key: string, default: number, lo: number, hi: number) -> number,
	int: (key: string, default: number, lo: number, hi: number) -> number,
	bool: (key: string, default: boolean) -> boolean,
	str: (key: string, default: string, maxLen: number?) -> string,
	pick: (key: string, choices: { string }, default: string) -> string,
	colors: (key: string, default: { Color3 }) -> { Color3 },
}

export type Def = {
	id: string,
	category: string,
	footprint: Vector3,
	maxParts: number,
	tags: { string },
	mount: string?, -- "floor" (default) | "wall" | "desk" | "ceiling"
	scaling: string?, -- option name that scales the prop's size and part count
	build: (c: Ctx) -> (),
}

export type SubBuilder = (parent: Ctx, id: string, lcf: CFrame, opts: Opts?) -> Model

---------------------------------------------------------------------------------------------------
-- Small math helpers (exported so builders can alias them)
---------------------------------------------------------------------------------------------------
local rad = math.rad

function Common.P(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Rotation in degrees.
function Common.R(rx: number, ry: number, rz: number): CFrame
	return CFrame.Angles(rad(rx), rad(ry), rad(rz))
end

-- Position + rotation in degrees.
function Common.PR(x: number, y: number, z: number, rx: number, ry: number, rz: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(rad(rx), rad(ry), rad(rz))
end

Common.V = Vector3.new

---------------------------------------------------------------------------------------------------
-- Colours and finishes
---------------------------------------------------------------------------------------------------
local hex = Kit.hex

Common.col = {
	laminate = hex("#E9E7E2"),
	laminateGrey = hex("#C9C7C2"),
	frame = hex("#3B3F45"),
	frameDark = hex("#24272B"),
	chrome = hex("#C8CCD0"),
	aluminum = hex("#B4B8BC"),
	plasticBlack = hex("#16181B"),
	plasticGrey = hex("#6B7077"),
	plasticWhite = hex("#ECEDEE"),
	fabricGrey = hex("#5C6168"),
	fabricCharcoal = hex("#3A3D42"),
	fabricNavy = hex("#22345A"),
	leatherBlack = hex("#1E1B19"),
	leatherBrown = hex("#4A2F22"),
	leatherCognac = hex("#8A4F2A"),
	oxblood = hex("#5A1E1E"),
	ebony = hex("#2A1C14"),
	cherry = hex("#7A3E2A"),
	paper = hex("#F4F1EA"),
	soil = hex("#3A2A1E"),
	terracotta = hex("#B5643C"),
	ceramicWhite = hex("#EFEDE8"),
	bronze = hex("#8C6A3E"),
	bronzeDark = hex("#5E4526"),
	velvetRed = hex("#7A1022"),
	felt = hex("#1F6B43"),
	water = hex("#3F7FA6"),
	leaf = hex("#3F6B3A"),
	leafLight = hex("#5A8A4A"),
	leafDark = hex("#2C4F2A"),
	trunk = hex("#5A4030"),
	rubber = hex("#1B1B1C"),
	warmBulb = hex("#FFD9A0"),
}

export type Finish = {
	wood: Color3,
	woodMat: Enum.Material,
	metal: Color3,
	metalMat: Enum.Material,
	accent: Color3,
	top: Color3,
	topMat: Enum.Material,
	fabric: Color3,
	fabricMat: Enum.Material,
}

-- Quality ladder used by opts.tier (1 laminate, 2 oak, 3 walnut, 4 ebony + brass + marble).
function Common.finish(tier: number): Finish
	local S = Kit.Palette.street
	local col = Common.col
	if tier <= 1 then
		return {
			wood = col.laminate,
			woodMat = Enum.Material.SmoothPlastic,
			metal = col.frame,
			metalMat = Enum.Material.Metal,
			accent = col.aluminum,
			top = col.laminate,
			topMat = Enum.Material.SmoothPlastic,
			fabric = col.fabricGrey,
			fabricMat = Enum.Material.Fabric,
		}
	elseif tier == 2 then
		return {
			wood = S.oak,
			woodMat = Enum.Material.Wood,
			metal = col.frameDark,
			metalMat = Enum.Material.Metal,
			accent = col.chrome,
			top = S.oak,
			topMat = Enum.Material.Wood,
			fabric = col.fabricNavy,
			fabricMat = Enum.Material.Fabric,
		}
	elseif tier == 3 then
		return {
			wood = S.walnut,
			woodMat = Enum.Material.Wood,
			metal = S.steelBrushed,
			metalMat = Enum.Material.Metal,
			accent = S.brass,
			top = S.walnut,
			topMat = Enum.Material.Wood,
			fabric = col.leatherBrown,
			fabricMat = Enum.Material.Leather,
		}
	end
	return {
		wood = col.ebony,
		woodMat = Enum.Material.Wood,
		metal = S.gold,
		metalMat = Enum.Material.Metal,
		accent = S.goldBright,
		top = S.marble,
		topMat = Enum.Material.Marble,
		fabric = col.leatherBlack,
		fabricMat = Enum.Material.Leather,
	}
end

---------------------------------------------------------------------------------------------------
-- Option parsing (tolerant: wrong types fall back to defaults, numbers are clamped)
---------------------------------------------------------------------------------------------------
local function toColor(v: any): Color3?
	local t = typeof(v)
	if t == "Color3" then
		return v :: Color3
	elseif t == "BrickColor" then
		return (v :: BrickColor).Color
	elseif t == "string" and string.match(v, "^#?%x%x%x%x%x%x$") then
		return hex(v)
	end
	return nil
end
Common.toColor = toColor

function Common.optColor(o: Opts, key: string, default: Color3): Color3
	return toColor(o[key]) or default
end

function Common.optNum(o: Opts, key: string, default: number, lo: number, hi: number): number
	local v = o[key]
	if type(v) ~= "number" or v ~= v then
		return default
	end
	return math.clamp(v, lo, hi)
end

function Common.optInt(o: Opts, key: string, default: number, lo: number, hi: number): number
	return math.floor(Common.optNum(o, key, default, lo, hi) + 0.5)
end

function Common.optBool(o: Opts, key: string, default: boolean): boolean
	local v = o[key]
	if type(v) == "boolean" then
		return v
	end
	return default
end

function Common.optStr(o: Opts, key: string, default: string, maxLen: number?): string
	local v = o[key]
	if type(v) == "number" then
		v = tostring(v)
	end
	if type(v) ~= "string" or v == "" then
		return default
	end
	local limit = maxLen or 120
	if #v > limit then
		return string.sub(v, 1, limit)
	end
	return v
end

-- opts[key] may be one of `choices` (string) or a 1-based index into it.
function Common.optPick(o: Opts, key: string, choices: { string }, default: string): string
	local v = o[key]
	if type(v) == "number" then
		local i = math.floor(v)
		if i >= 1 and i <= #choices then
			return choices[i]
		end
		return default
	elseif type(v) == "string" then
		local lower = string.lower(v)
		for _, c in choices do
			if c == lower then
				return c
			end
		end
	end
	return default
end

function Common.optColors(o: Opts, key: string, default: { Color3 }): { Color3 }
	local v = o[key]
	if type(v) ~= "table" then
		return default
	end
	local out = {}
	for _, x in v :: { any } do
		local c = toColor(x)
		if c then
			table.insert(out, c)
		end
		if #out >= 16 then
			break
		end
	end
	if #out == 0 then
		return default
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Context
---------------------------------------------------------------------------------------------------
local NO_COLLIDE = { CanCollide = false, CanQuery = false, CanTouch = false }

local function noCollide(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
end

local function makeCyl(parent: Instance, wcf: CFrame, len: number, d: number, color: Color3, mat: Enum.Material?): Part
	-- Roblox cylinders run along the part's X axis.
	local p = Kit.block(parent, wcf, Vector3.new(len, d, d), color, mat)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local Y90 = CFrame.Angles(0, rad(90), 0)
local Z90 = CFrame.Angles(0, 0, rad(90))

function Common.ctx(m: Instance, cf: CFrame, o: Opts, rng: Rng.Rng, id: string, subBuilder: SubBuilder?): Ctx
	local c = {} :: Ctx
	c.id = id
	c.m = m
	c.cf = cf
	c.o = o
	c.rng = rng
	c.usePart = nil

	function c.at(lcf: CFrame): CFrame
		return cf * lcf
	end
	function c.part(lcf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?): Part
		return Kit.block(m, cf * lcf, size, color, mat)
	end
	function c.detail(lcf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?): Part
		return Kit.detail(m, cf * lcf, size, color, mat)
	end
	-- Vertical cylinder (axis = local Y).
	function c.cyl(lcf: CFrame, h: number, d: number, color: Color3, mat: Enum.Material?): Part
		return makeCyl(m, cf * lcf * Z90, h, d, color, mat)
	end
	function c.dcyl(lcf: CFrame, h: number, d: number, color: Color3, mat: Enum.Material?): Part
		local p = makeCyl(m, cf * lcf * Z90, h, d, color, mat)
		noCollide(p)
		p.CastShadow = math.max(h, d) > 2
		return p
	end
	-- Cylinder along local X.
	function c.cylX(lcf: CFrame, len: number, d: number, color: Color3, mat: Enum.Material?): Part
		return makeCyl(m, cf * lcf, len, d, color, mat)
	end
	function c.dcylX(lcf: CFrame, len: number, d: number, color: Color3, mat: Enum.Material?): Part
		local p = makeCyl(m, cf * lcf, len, d, color, mat)
		noCollide(p)
		p.CastShadow = math.max(len, d) > 2
		return p
	end
	-- Cylinder along local Z.
	function c.cylZ(lcf: CFrame, len: number, d: number, color: Color3, mat: Enum.Material?): Part
		return makeCyl(m, cf * lcf * Y90, len, d, color, mat)
	end
	function c.dcylZ(lcf: CFrame, len: number, d: number, color: Color3, mat: Enum.Material?): Part
		local p = makeCyl(m, cf * lcf * Y90, len, d, color, mat)
		noCollide(p)
		p.CastShadow = math.max(len, d) > 2
		return p
	end
	function c.ball(lcf: CFrame, d: number, color: Color3, mat: Enum.Material?): Part
		return Kit.ball(m, cf * lcf, d, color, mat)
	end
	function c.dball(lcf: CFrame, d: number, color: Color3, mat: Enum.Material?): Part
		local p = Kit.ball(m, cf * lcf, d, color, mat, NO_COLLIDE)
		p.CastShadow = d > 2
		return p
	end
	-- WedgePart: full height at local +Z, sloping down toward -Z.
	function c.wedge(lcf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?): WedgePart
		return Kit.wedge(m, cf * lcf, size, color, mat)
	end
	function c.dwedge(lcf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?): WedgePart
		local p = Kit.wedge(m, cf * lcf, size, color, mat, NO_COLLIDE)
		p.CastShadow = size.Magnitude > 4
		return p
	end
	function c.cwedge(lcf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?): CornerWedgePart
		local p = Kit.cornerWedge(m, cf * lcf, size, color, mat, NO_COLLIDE)
		p.CastShadow = size.Magnitude > 4
		return p
	end
	function c.glow(lcf: CFrame, size: Vector3, color: Color3, transparency: number?): Part
		local p = Kit.detail(m, cf * lcf, size, color, Enum.Material.Neon)
		p.Transparency = transparency or 0
		p.CastShadow = false
		return p
	end
	function c.glass(lcf: CFrame, size: Vector3, color: Color3, transparency: number?, collide: boolean?): Part
		local p = Kit.block(m, cf * lcf, size, color, Enum.Material.Glass)
		p.Transparency = transparency or 0.55
		p.Reflectance = 0.08
		p.CastShadow = false
		if not collide then
			noCollide(p)
		end
		return p
	end
	function c.seat(lcf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?): BasePart
		if o.seat == true then
			local s = Instance.new("Seat")
			s.Anchored = true
			s.TopSurface = Enum.SurfaceType.Smooth
			s.BottomSurface = Enum.SurfaceType.Smooth
			s.Material = mat or Enum.Material.SmoothPlastic
			s.Color = color
			s.Size = size
			s.CFrame = cf * lcf
			s.Parent = m
			return s
		end
		return Kit.block(m, cf * lcf, size, color, mat)
	end
	function c.light(part: BasePart, kind: string, props: { [string]: any }?): Light
		return Kit.light(part, kind, props)
	end
	function c.use(part: BasePart)
		if c.usePart == nil then
			c.usePart = part
		end
	end
	function c.sub(subId: string, lcf: CFrame, subOpts: Opts?): Model
		assert(subBuilder, "Props: sub-builds are not available in this context")
		return subBuilder(c, subId, lcf, subOpts)
	end
	function c.color(key: string, default: Color3): Color3
		return Common.optColor(o, key, default)
	end
	function c.num(key: string, default: number, lo: number, hi: number): number
		return Common.optNum(o, key, default, lo, hi)
	end
	function c.int(key: string, default: number, lo: number, hi: number): number
		return Common.optInt(o, key, default, lo, hi)
	end
	function c.bool(key: string, default: boolean): boolean
		return Common.optBool(o, key, default)
	end
	function c.str(key: string, default: string, maxLen: number?): string
		return Common.optStr(o, key, default, maxLen)
	end
	function c.pick(key: string, choices: { string }, default: string): string
		return Common.optPick(o, key, choices, default)
	end
	function c.colors(key: string, default: { Color3 }): { Color3 }
		return Common.optColors(o, key, default)
	end
	return c
end

---------------------------------------------------------------------------------------------------
-- Model shell shared by Props and Signs
---------------------------------------------------------------------------------------------------
-- Creates the (unparented) model and its invisible Root part at `cf` (the floor contact point).
function Common.shell(name: string, cf: CFrame): (Model, Part)
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local root = Kit.part(model, {
		Name = "Root",
		Size = Vector3.new(0.4, 0.1, 0.4),
		CFrame = cf,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	model.PrimaryPart = root
	return model, root
end

-- Axis-aligned bounds of every BasePart under `root`, measured in `cf`'s local space.
-- Returns (min, max); both zero when there are no parts. `skip` excludes one part (the Root).
function Common.localBounds(root: Instance, cf: CFrame, skip: BasePart?): (Vector3, Vector3)
	local huge = math.huge
	local minX, minY, minZ = huge, huge, huge
	local maxX, maxY, maxZ = -huge, -huge, -huge
	local any = false
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d ~= skip then
			any = true
			local s = d.Size / 2
			local pcf = cf:ToObjectSpace(d.CFrame)
			for ix = -1, 1, 2 do
				for iy = -1, 1, 2 do
					for iz = -1, 1, 2 do
						local p = pcf * Vector3.new(s.X * ix, s.Y * iy, s.Z * iz)
						minX = math.min(minX, p.X)
						minY = math.min(minY, p.Y)
						minZ = math.min(minZ, p.Z)
						maxX = math.max(maxX, p.X)
						maxY = math.max(maxY, p.Y)
						maxZ = math.max(maxZ, p.Z)
					end
				end
			end
		end
	end
	if not any then
		return Vector3.zero, Vector3.zero
	end
	return Vector3.new(minX, minY, minZ), Vector3.new(maxX, maxY, maxZ)
end

---------------------------------------------------------------------------------------------------
-- Reusable composite shapes
---------------------------------------------------------------------------------------------------
-- Four legs under a rectangle of width w (X) and depth d (Z), legs of height h, inset from the edges.
function Common.legs4(c: Ctx, w: number, d: number, h: number, t: number, color: Color3, mat: Enum.Material?, inset: number?)
	local i = inset or t
	local x = w / 2 - i - t / 2
	local z = d / 2 - i - t / 2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			c.detail(Common.P(sx * x, h / 2, sz * z), Vector3.new(t, h, t), color, mat)
		end
	end
end

-- Four round legs.
function Common.roundLegs4(
	c: Ctx,
	w: number,
	d: number,
	h: number,
	dia: number,
	color: Color3,
	mat: Enum.Material?,
	inset: number?
)
	local i = inset or dia
	local x = w / 2 - i
	local z = d / 2 - i
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			c.dcyl(Common.P(sx * x, h / 2, sz * z), h, dia, color, mat)
		end
	end
end

-- Rectangular frame of four strips around a w x h opening centred at `lcf` (in its XY plane).
-- `t` = strip width, `depth` = strip depth along Z.
function Common.frameRect(
	c: Ctx,
	lcf: CFrame,
	w: number,
	h: number,
	t: number,
	depth: number,
	color: Color3,
	mat: Enum.Material?
)
	c.detail(lcf * CFrame.new(0, h / 2 + t / 2, 0), Vector3.new(w + t * 2, t, depth), color, mat)
	c.detail(lcf * CFrame.new(0, -h / 2 - t / 2, 0), Vector3.new(w + t * 2, t, depth), color, mat)
	c.detail(lcf * CFrame.new(-w / 2 - t / 2, 0, 0), Vector3.new(t, h, depth), color, mat)
	c.detail(lcf * CFrame.new(w / 2 + t / 2, 0, 0), Vector3.new(t, h, depth), color, mat)
end

-- Five-star office chair base with casters; returns the hub height.
function Common.starBase(c: Ctx, radius: number, color: Color3, mat: Enum.Material?, casterColor: Color3?): number
	local hubY = 0.42
	local spoke = radius - 0.12
	for i = 0, 4 do
		local a = i * 72
		local rot = Common.R(0, a, 0)
		c.detail(rot * CFrame.new(0, hubY - 0.04, -spoke / 2) * Common.R(-6, 0, 0), Vector3.new(0.2, 0.12, spoke), color, mat)
		c.dball(rot * CFrame.new(0, 0.14, -spoke), 0.28, casterColor or Common.col.plasticBlack, Enum.Material.SmoothPlastic)
	end
	c.dcyl(Common.P(0, hubY, 0), 0.22, 0.42, color, mat)
	return hubY
end

-- Bicycle standing upright, wheels along local Z, centred at lcf (floor contact). ~11 parts.
function Common.bike(c: Ctx, lcf: CFrame, frameColor: Color3, opts: { basket: boolean? }?)
	local P = Common.P
	local R = Common.R
	local wheelD = 2.3
	local r = wheelD / 2
	local tire = Common.col.rubber
	local metal = Common.col.chrome
	local front, back = -1.75, 1.75
	-- wheels (discs along X so the flat faces point sideways)
	c.dcylX(lcf * P(0, r, front), 0.14, wheelD, tire, Enum.Material.Rubber)
	c.dcylX(lcf * P(0, r, back), 0.14, wheelD, tire, Enum.Material.Rubber)
	c.dcylX(lcf * P(0, r, front), 0.18, 0.5, metal, Enum.Material.Metal)
	c.dcylX(lcf * P(0, r, back), 0.18, 0.5, metal, Enum.Material.Metal)
	-- frame: down tube, top tube, seat tube, chain stay
	local bb = Vector3.new(0, r - 0.1, 0.25) -- bottom bracket
	local head = Vector3.new(0, r + 1.25, front + 0.55)
	local seatTop = Vector3.new(0, r + 1.35, back - 0.95)
	local function tube(a: Vector3, b: Vector3, t: number)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		c.detail(lcf * CFrame.lookAt(mid, b), Vector3.new(t, t, len), frameColor, Enum.Material.Metal)
	end
	tube(bb, head, 0.16)
	tube(head - Vector3.new(0, 0.15, 0), seatTop, 0.14)
	tube(bb, seatTop, 0.14)
	tube(bb, Vector3.new(0, r, back), 0.1)
	-- fork + handlebar + saddle
	tube(head, Vector3.new(0, r, front), 0.12)
	c.dcylX(lcf * P(0, head.Y + 0.35, head.Z + 0.1), 1.3, 0.1, Common.col.frameDark, Enum.Material.Metal)
	c.detail(lcf * P(0, seatTop.Y + 0.12, seatTop.Z) * R(0, 0, 0), Vector3.new(0.35, 0.12, 0.7), Common.col.plasticBlack)
	if opts and opts.basket then
		c.detail(lcf * P(0, head.Y + 0.05, front - 0.25), Vector3.new(0.9, 0.55, 0.65), frameColor, Enum.Material.Metal)
	end
end

-- Wine/liquor bottle (2 parts): body + neck, base at lcf.
function Common.bottle(c: Ctx, lcf: CFrame, h: number, d: number, color: Color3, glassy: boolean?)
	local mat = if glassy then Enum.Material.Glass else Enum.Material.SmoothPlastic
	local body = c.dcyl(lcf * Common.P(0, h * 0.34, 0), h * 0.68, d, color, mat)
	local neck = c.dcyl(lcf * Common.P(0, h * 0.82, 0), h * 0.36, d * 0.36, color, mat)
	if glassy then
		body.Transparency = 0.15
		neck.Transparency = 0.15
	end
end

-- Leafy foliage cluster of `n` balls around lcf, radius `spread`, sizes in [lo, hi].
function Common.foliage(c: Ctx, lcf: CFrame, n: number, spread: number, lo: number, hi: number, palette: { Color3 }?)
	local pal = palette or { Common.col.leaf, Common.col.leafLight, Common.col.leafDark }
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + c.rng:range(-0.4, 0.4)
		local rr = if i == 1 then 0 else spread * c.rng:range(0.45, 1)
		local y = if i == 1 then 0 else c.rng:range(-spread * 0.45, spread * 0.5)
		local d = c.rng:range(lo, hi)
		c.dball(lcf * Common.P(math.cos(a) * rr, y, math.sin(a) * rr), d, pal[(i - 1) % #pal + 1], Enum.Material.Grass)
	end
end

return Common
