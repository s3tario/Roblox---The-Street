--!strict
-- Reusable composite shapes for prop builders (legs, frames, drawers, pots, foliage, books, wheels,
-- monitors, bikes, bottles, tubes). Every function takes a Ctx and LOCAL CFrames. Bake-safe.

local Common = require(script.Parent.Common)
local Gui = require(script.Parent.Gui)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)
local Rng = require(script.Parent.Parent.Parent.Util.Rng)

local Shapes = {}

type Ctx = Common.Ctx

local P, R = Common.P, Common.R
local col = Common.col
local V = Vector3.new

---------------------------------------------------------------------------------------------------
-- Struts and tubes
---------------------------------------------------------------------------------------------------
-- Round tube between two local points (non-colliding).
function Shapes.tube(c: Ctx, a: Vector3, b: Vector3, d: number, color: Color3, mat: Enum.Material?): Part
	local lcf, len = Common.between(a, b)
	return c.dcylZ(lcf, len, d, color, mat)
end

-- Square strut between two local points (non-colliding).
function Shapes.strut(c: Ctx, a: Vector3, b: Vector3, t: number, color: Color3, mat: Enum.Material?): Part
	local lcf, len = Common.between(a, b)
	return c.detail(lcf, V(t, t, len), color, mat)
end

---------------------------------------------------------------------------------------------------
-- Legs and frames
---------------------------------------------------------------------------------------------------
-- Four square legs under a w x d rectangle, legs of height h, inset from the edges.
function Shapes.legs4(c: Ctx, w: number, d: number, h: number, t: number, color: Color3, mat: Enum.Material?, inset: number?)
	local i = inset or t
	local x = w / 2 - i - t / 2
	local z = d / 2 - i - t / 2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			c.detail(P(sx * x, h / 2, sz * z), V(t, h, t), color, mat)
		end
	end
end

-- Four round legs (optionally tapered with a brass foot cap: +4 parts).
function Shapes.roundLegs4(
	c: Ctx,
	w: number,
	d: number,
	h: number,
	dia: number,
	color: Color3,
	mat: Enum.Material?,
	inset: number?,
	cap: Color3?
)
	local i = inset or dia
	local x = w / 2 - i
	local z = d / 2 - i
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			if cap then
				c.dcyl(P(sx * x, 0.08, sz * z), 0.16, dia * 0.8, cap, Enum.Material.Metal)
				c.dcyl(P(sx * x, 0.16 + (h - 0.16) / 2, sz * z), h - 0.16, dia, color, mat)
			else
				c.dcyl(P(sx * x, h / 2, sz * z), h, dia, color, mat)
			end
		end
	end
end

-- Rectangular frame of four strips around a w x h opening centred at `lcf` (in its XY plane).
function Shapes.frameRect(
	c: Ctx,
	lcf: CFrame,
	w: number,
	h: number,
	t: number,
	depth: number,
	color: Color3,
	mat: Enum.Material?
)
	c.detail(lcf * P(0, h / 2 + t / 2, 0), V(w + t * 2, t, depth), color, mat)
	c.detail(lcf * P(0, -h / 2 - t / 2, 0), V(w + t * 2, t, depth), color, mat)
	c.detail(lcf * P(-w / 2 - t / 2, 0, 0), V(t, h, depth), color, mat)
	c.detail(lcf * P(w / 2 + t / 2, 0, 0), V(t, h, depth), color, mat)
end

-- `n` proud drawer fronts with pulls (2n parts) on the -Z face of a w x h carcass face centred at lcf.
function Shapes.drawerFronts(
	c: Ctx,
	lcf: CFrame,
	w: number,
	h: number,
	n: number,
	front: Color3,
	frontMat: Enum.Material?,
	pull: Color3,
	pullWide: boolean?
)
	local gap = 0.06
	local fh = (h - gap * (n + 1)) / n
	for i = 1, n do
		local y = -h / 2 + gap * i + fh * (i - 0.5)
		c.detail(lcf * P(0, y, -0.03), V(w - 0.12, fh, 0.06), front, frontMat)
		local pw = if pullWide then w * 0.5 else math.min(0.5, w * 0.3)
		c.detail(lcf * P(0, y + fh * 0.22, -0.09), V(pw, 0.06, 0.06), pull, Enum.Material.Metal)
	end
end

-- Stack of `n` drawers: a solid carcass plus a proud front and a pull per drawer (1 + 2n parts).
-- lcf = centre of the carcass; drawers face -Z.
function Shapes.drawers(
	c: Ctx,
	lcf: CFrame,
	size: Vector3,
	n: number,
	body: Color3,
	bodyMat: Enum.Material?,
	front: Color3,
	frontMat: Enum.Material?,
	pull: Color3,
	pullWide: boolean?
): Part
	local carcass = c.part(lcf, size, body, bodyMat)
	Shapes.drawerFronts(c, lcf * P(0, 0, -size.Z / 2), size.X, size.Y, n, front, frontMat, pull, pullWide)
	return carcass
end

-- Five-star office chair base with casters; returns the hub height.
function Shapes.starBase(c: Ctx, radius: number, color: Color3, mat: Enum.Material?, casterColor: Color3?): number
	local hubY = 0.42
	local spoke = radius - 0.12
	for i = 0, 4 do
		local rot = R(0, i * 72, 0)
		c.detail(rot * P(0, hubY - 0.06, -spoke / 2) * R(-8, 0, 0), V(0.2, 0.12, spoke), color, mat)
		c.dball(rot * P(0, 0.14, -spoke), 0.28, casterColor or col.plasticBlack, Enum.Material.SmoothPlastic)
	end
	c.dcyl(P(0, hubY, 0), 0.22, 0.42, color, mat)
	return hubY
end

---------------------------------------------------------------------------------------------------
-- Plants
---------------------------------------------------------------------------------------------------
-- Round pot with a rim and soil; returns the soil height (local Y above lcf). 3 parts.
function Shapes.pot(c: Ctx, lcf: CFrame, d: number, h: number, color: Color3, mat: Enum.Material?, solid: boolean?): number
	if solid then
		c.cyl(lcf * P(0, h / 2, 0), h, d, color, mat)
	else
		c.dcyl(lcf * P(0, h / 2, 0), h, d, color, mat)
	end
	c.dcyl(lcf * P(0, h - 0.06, 0), 0.14, d * 1.08, color:Lerp(Color3.new(0, 0, 0), 0.12), mat)
	c.dcyl(lcf * P(0, h - 0.04, 0), 0.06, d * 0.92, col.soil, Enum.Material.Ground)
	return h - 0.02
end

-- Leafy foliage cluster of `n` balls around lcf, radius `spread`, sizes in [lo, hi].
function Shapes.foliage(c: Ctx, lcf: CFrame, n: number, spread: number, lo: number, hi: number, palette: { Color3 }?)
	local pal = palette or { col.leaf, col.leafLight, col.leafDark }
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + c.rng:range(-0.4, 0.4)
		local rr = if i == 1 then 0 else spread * c.rng:range(0.45, 1)
		local y = if i == 1 then 0 else c.rng:range(-spread * 0.35, spread * 0.45)
		local d = c.rng:range(lo, hi)
		c.dball(lcf * P(math.cos(a) * rr, y, math.sin(a) * rr), d, pal[(i - 1) % #pal + 1], Enum.Material.Grass)
	end
end

-- Fan of long blade leaves (snake plant / palm) rising from lcf.
function Shapes.blades(c: Ctx, lcf: CFrame, n: number, h: number, w: number, color: Color3, lean: number)
	for i = 1, n do
		local a = (i / n) * 360 + c.rng:range(-20, 20)
		local tilt = c.rng:range(lean * 0.4, lean)
		local hh = h * c.rng:range(0.7, 1)
		c.detail(lcf * R(0, a, 0) * R(tilt, 0, 0) * P(0, hh / 2, 0), V(w, hh, 0.06), color, Enum.Material.Grass)
	end
end

---------------------------------------------------------------------------------------------------
-- Books, bottles
---------------------------------------------------------------------------------------------------
local BOOK_COLORS = {
	Color3.fromRGB(122, 31, 36),
	Color3.fromRGB(23, 52, 89),
	Color3.fromRGB(31, 77, 58),
	Color3.fromRGB(201, 165, 76),
	Color3.fromRGB(60, 60, 64),
	Color3.fromRGB(150, 110, 70),
	Color3.fromRGB(232, 226, 207),
	Color3.fromRGB(94, 50, 24),
}
Shapes.BOOK_COLORS = BOOK_COLORS

-- A row of 1..maxGroups book groups filling `width` on a shelf (one part per group, so the part count is
-- bounded by maxGroups). lcf = centre of the shelf surface. Some groups lean, some slots stay empty.
function Shapes.books(c: Ctx, lcf: CFrame, width: number, maxH: number, depth: number, maxGroups: number)
	local n = c.rng:int(math.max(1, maxGroups - 2), maxGroups)
	local weights = {}
	local total = 0
	for i = 1, n do
		weights[i] = c.rng:range(0.6, 1.4)
		total += weights[i]
	end
	local x = -width / 2
	for i = 1, n do
		local gw = width * weights[i] / total
		local empty = n > 2 and c.rng:chance(0.12)
		if not empty then
			local h = maxH * c.rng:range(0.72, 1)
			local d = depth * c.rng:range(0.8, 1)
			local w = math.max(gw - 0.04, 0.1)
			local lean = if gw < width * 0.25 and c.rng:chance(0.2) then c.rng:range(-14, 14) else 0
			local bottom = if lean ~= 0 then math.abs(math.sin(math.rad(lean))) * w / 2 else 0
			c.detail(
				lcf * P(x + gw / 2, h / 2 + bottom, 0) * R(0, 0, lean),
				V(w, h, d),
				c.rng:pick(BOOK_COLORS),
				Enum.Material.SmoothPlastic
			)
		end
		x += gw
	end
end

-- Bottle (2 parts): body + neck, base at lcf.
function Shapes.bottle(c: Ctx, lcf: CFrame, h: number, d: number, color: Color3, glassy: boolean?)
	local mat = if glassy then Enum.Material.Glass else Enum.Material.SmoothPlastic
	local body = c.dcyl(lcf * P(0, h * 0.34, 0), h * 0.68, d, color, mat)
	local neck = c.dcyl(lcf * P(0, h * 0.82, 0), h * 0.36, d * 0.36, color, mat)
	if glassy then
		body.Transparency = 0.15
		neck.Transparency = 0.15
	end
end

---------------------------------------------------------------------------------------------------
-- Wheels, bikes
---------------------------------------------------------------------------------------------------
-- Wheel with its axle along local X (tyre + hub cap = 2 parts). lcf = wheel centre.
function Shapes.wheel(c: Ctx, lcf: CFrame, d: number, w: number, hub: Color3?, tire: Color3?)
	c.dcylX(lcf, w, d, tire or col.rubber, Enum.Material.Rubber)
	c.dcylX(lcf, w + 0.04, d * 0.56, hub or col.chrome, Enum.Material.Metal)
end

-- Bicycle standing upright, wheels along local Z, centred at lcf (floor contact).
-- Full bike is 11 parts (+1 with a basket); `simple` gives a 7-part version for docks and racks.
function Shapes.bike(c: Ctx, lcf: CFrame, frameColor: Color3, opts: { basket: boolean?, simple: boolean? }?)
	local o: { basket: boolean?, simple: boolean? } = opts or {}
	local wheelD = 2.3
	local r = wheelD / 2
	local tire = col.rubber
	local metal = col.chrome
	local front, back = -1.75, 1.75
	c.dcylX(lcf * P(0, r, front), 0.14, wheelD, tire, Enum.Material.Rubber)
	c.dcylX(lcf * P(0, r, back), 0.14, wheelD, tire, Enum.Material.Rubber)
	if not o.simple then
		c.dcylX(lcf * P(0, r, front), 0.18, 0.5, metal, Enum.Material.Metal)
		c.dcylX(lcf * P(0, r, back), 0.18, 0.5, metal, Enum.Material.Metal)
	end
	local bb = V(0, r - 0.1, 0.25)
	local head = V(0, r + 1.25, front + 0.55)
	local seatTop = V(0, r + 1.35, back - 0.95)
	local function tube(a: Vector3, b: Vector3, t: number)
		local cfm, len = Common.between(a, b)
		c.detail(lcf * cfm, V(t, t, len), frameColor, Enum.Material.Metal)
	end
	tube(bb, head, 0.16)
	if not o.simple then
		tube(head - V(0, 0.15, 0), seatTop, 0.14)
		tube(bb, V(0, r, back), 0.1)
	end
	tube(bb, seatTop, 0.14)
	tube(head, V(0, r, front), 0.12)
	c.dcylX(lcf * P(0, head.Y + 0.35, head.Z + 0.1), 1.3, 0.1, col.frameDark, Enum.Material.Metal)
	c.detail(lcf * P(0, seatTop.Y + 0.12, seatTop.Z), V(0.35, 0.12, 0.7), col.plasticBlack)
	if o.basket then
		c.detail(lcf * P(0, head.Y + 0.05, front - 0.25), V(0.9, 0.55, 0.65), frameColor, Enum.Material.Metal)
	end
end

---------------------------------------------------------------------------------------------------
-- Screens
---------------------------------------------------------------------------------------------------
local OFF_SCREEN = Color3.fromRGB(14, 16, 20)

-- Flat-panel display (3 parts: bezel, screen, back housing). lcf = centre of the panel, screen faces -Z.
-- Returns the screen part (its front face carries the SurfaceGui when lit).
function Shapes.display(c: Ctx, lcf: CFrame, w: number, h: number, kind: string, lit: boolean, rng: Rng.Rng): Part
	c.detail(lcf, V(w, h, 0.12), col.plasticBlack, Enum.Material.SmoothPlastic)
	local screen = c.detail(lcf * P(0, 0.02, -0.065), V(w - 0.1, h - 0.14, 0.02), OFF_SCREEN, Enum.Material.Glass)
	screen.Name = "Screen"
	screen.Reflectance = 0.05
	if lit then
		Gui.Screens.screen(screen, kind, rng)
	end
	c.detail(lcf * P(0, -0.05, 0.11), V(w * 0.55, h * 0.5, 0.12), col.frameDark, Enum.Material.SmoothPlastic)
	return screen
end

-- Picks screen kinds for n displays from opts.screens (list or single string) or a trading-floor mix.
function Shapes.screenKinds(c: Ctx, n: number, default: { string }): { string }
	local raw = c.o.screens
	local out = {}
	for i = 1, n do
		local k: any = nil
		if type(raw) == "table" then
			k = (raw :: { any })[(i - 1) % math.max(#(raw :: { any }), 1) + 1]
		elseif type(raw) == "string" then
			k = raw
		end
		if type(k) ~= "string" or not table.find(Gui.Screens.KINDS, k) then
			k = default[(i - 1) % #default + 1]
		end
		table.insert(out, k)
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Seating helpers
---------------------------------------------------------------------------------------------------
-- Compact swivel meeting chair facing -Z (5 parts). lcf = floor contact.
function Shapes.meetingChair(c: Ctx, lcf: CFrame, fabric: Color3, frame: Color3)
	c.dcyl(lcf * P(0, 0.06, 0), 0.12, 1.6, frame, Enum.Material.Metal)
	c.dcyl(lcf * P(0, 0.85, 0), 1.5, 0.22, col.chrome, Enum.Material.Metal)
	c.seat(lcf * P(0, 1.72, 0), V(1.8, 0.36, 1.7), fabric, Enum.Material.Leather)
	c.detail(lcf * P(0, 2.85, 0.82) * R(8, 0, 0), V(1.7, 1.9, 0.25), fabric, Enum.Material.Leather)
	c.detail(lcf * P(0, 2.0, 0.78), V(0.9, 0.5, 0.12), frame, Enum.Material.Metal)
end

---------------------------------------------------------------------------------------------------
-- Deal toys (lucite tombstones)
---------------------------------------------------------------------------------------------------
Shapes.TOMBSTONES = {
	tombstone = V(0.8, 1.1, 0.3),
	obelisk = V(0.55, 1.5, 0.4),
	cube = V(0.75, 0.75, 0.75),
}

-- Lucite deal toy on a small base (3 parts): base block, clear block with the deal text engraved on its
-- front face, and an embedded gold coin. lcf = bottom centre. Returns the overall height.
function Shapes.tombstone(c: Ctx, lcf: CFrame, style: string, text: string, baseColor: Color3): number
	local size = Shapes.TOMBSTONES[style] or Shapes.TOMBSTONES.tombstone
	local bh = 0.1
	c.detail(lcf * P(0, bh / 2, 0), V(size.X + 0.1, bh, size.Z + 0.1), baseColor, Enum.Material.SmoothPlastic)
	local block = c.detail(lcf * P(0, bh + size.Y / 2, 0), size, col.lucite, Enum.Material.Glass)
	block.Name = "Lucite"
	block.Transparency = 0.3
	block.Reflectance = 0.12
	local gui = Gui.Core.surface(block, Enum.NormalId.Front, { pps = 160, maxDistance = 40, name = "Engraving" })
	Gui.Core.label(gui, text, 0.08, 0.34, 0.84, 0.58, Color3.fromRGB(27, 42, 68), {
		font = Enum.Font.GothamBold,
		align = Enum.TextXAlignment.Center,
	})
	c.dcylZ(lcf * P(0, bh + size.Y * 0.8, 0), 0.04, math.min(size.X, size.Y) * 0.32, Kit.Palette.street.gold, Enum.Material.Metal)
	return bh + size.Y
end

---------------------------------------------------------------------------------------------------
-- Rails, lights
---------------------------------------------------------------------------------------------------
-- Handrail from a to b (local floor points) at `height`: a top tube plus `posts` evenly spaced posts
-- (posts >= 2 includes both ends). 1 + posts parts.
function Shapes.rail(c: Ctx, a: Vector3, b: Vector3, height: number, posts: number, d: number, color: Color3, mat: Enum.Material?)
	local up = V(0, height, 0)
	Shapes.tube(c, a + up, b + up, d, color, mat)
	for i = 0, posts - 1 do
		local t = if posts <= 1 then 0.5 else i / (posts - 1)
		local p = a:Lerp(b, t)
		c.dcyl(P(p.X, p.Y + height / 2, p.Z), height, d * 0.8, color, mat)
	end
end

-- Warm point light on `part` (only when lit).
function Shapes.lamp(part: BasePart, lit: boolean, color: Color3, range: number, brightness: number): PointLight?
	if not lit then
		return nil
	end
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
	return l
end

return Shapes
