--!strict
-- Fit: the toolbox every wardrobe layer builder uses. Layers are thin parts placed relative to a body
-- part (in that part's local space, front = -Z, wearer's left = -X) and either welded to it (players,
-- runtime NPCs) or anchored in place (baked mannequins, viewport previews). Sizes always come from the
-- real body part, so the same builder fits a standard R15 avatar and an NpcRig.
-- Bake-safe (contracts §13): Instance.new, properties, attributes and CFrame math only.

local Palette = require(script.Parent.Parent.Parent.Build.Palette)

local Fit = {}

-- Standard R15 body part names.
Fit.BODY = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}
Fit.BODY_SET = {} :: { [string]: boolean }
for _, n in Fit.BODY do
	Fit.BODY_SET[n] = true
end

Fit.SIDES = { "Left", "Right" }
Fit.FOLDER = "CareerLook"
Fit.ATTR_PART = "CareerLookPart" -- on each layer: the body part it belongs to
Fit.ATTR_COLOR = "CareerLookColor" -- on body parts: original colour (restored by clear)
Fit.ATTR_MATERIAL = "CareerLookMaterial" -- on body parts: original material name

-- Distances (studs).
Fit.SHELL = 0.06 -- jacket/coat shell stands this far off the torso
Fit.T = 0.03 -- default plate thickness
Fit.E = 0.012 -- tiny lift that keeps coplanar plates from z-fighting

export type Colors = { primary: Color3, secondary: Color3, accent: Color3 }

export type Ctx = {
	character: Model,
	folder: Folder,
	anchored: boolean,
	glint: boolean,
	skin: Color3,
	parts: { [string]: BasePart },
	items: { [string]: any }, -- slot -> catalog item being worn (fallbacks included)
	covers: { [string]: { [string]: boolean } }, -- slot -> regions that item covers
	item: any,
	slot: string,
	colors: Colors,
	state: { [string]: any }, -- shared between builders (torso front depth, jacket V, ...)
	count: number,
	painted: { [string]: string }, -- body part -> slot that painted it last
}

---------------------------------------------------------------------------------------------------
-- Colours
---------------------------------------------------------------------------------------------------
local colorCache: { [string]: Color3 } = {}

-- "#RRGGBB" -> Color3 (cached). Invalid strings give mid grey so a typo never breaks a look.
function Fit.color(spec: any, fallback: Color3?): Color3
	if typeof(spec) == "Color3" then
		return spec
	end
	if type(spec) == "string" then
		local c = colorCache[spec]
		if c then
			return c
		end
		if string.match(spec, "^#%x%x%x%x%x%x$") then
			local out = Palette.hex(spec)
			colorCache[spec] = out
			return out
		end
	end
	return fallback or Color3.fromRGB(128, 128, 128)
end

function Fit.shade(c: Color3, f: number): Color3
	if f >= 0 then
		return c:Lerp(Color3.new(1, 1, 1), f)
	end
	return c:Lerp(Color3.new(0, 0, 0), -f)
end

-- Resolves an item's colour table into Color3s with sensible defaults.
function Fit.colorsOf(item: any): Colors
	local c = if type(item) == "table" and type(item.colors) == "table" then item.colors else {}
	local primary = Fit.color(c.primary)
	return {
		primary = primary,
		secondary = Fit.color(c.secondary, Fit.shade(primary, -0.2)),
		accent = Fit.color(c.accent, Fit.shade(primary, 0.35)),
	}
end

-- Metal colours used by watches, buckles and buttons.
Fit.METALS = {
	steel = Color3.fromRGB(192, 196, 200),
	silver = Color3.fromRGB(205, 208, 212),
	bronze = Color3.fromRGB(156, 107, 60),
	gold = Color3.fromRGB(212, 175, 55),
	platinum = Color3.fromRGB(229, 228, 226),
	gunmetal = Color3.fromRGB(78, 82, 88),
	brass = Color3.fromRGB(184, 147, 63),
}

---------------------------------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------------------------------
function Fit.part(ctx: Ctx, name: string): BasePart?
	return ctx.parts[name]
end

function Fit.size(ctx: Ctx, name: string): Vector3?
	local p = ctx.parts[name]
	return if p then p.Size else nil
end

-- True when another worn item covers `region` (torso, arms, waist, thighs, neck, hands, feet).
function Fit.covered(ctx: Ctx, region: string): boolean
	for slot, set in ctx.covers do
		if slot ~= ctx.slot and set[region] then
			return true
		end
	end
	return false
end

function Fit.wearing(ctx: Ctx, slot: string): any
	return ctx.items[slot]
end

-- Colour of the shirt that shows at the collar/V/cuffs (top primary, white by default).
function Fit.shirtColor(ctx: Ctx): Color3
	local top = ctx.items.top
	if top then
		return Fit.colorsOf(top).primary
	end
	return Color3.fromRGB(244, 244, 240)
end

-- Depth (UpperTorso local Z) of the front-most worn surface on the chest: the lapels or overshirt when an
-- outer layer is worn, else the top. Pieces worn over everything (lanyards, bag straps, scarf tails) sit
-- just in front of it.
function Fit.chestFront(ctx: Ctx): number
	local s = Fit.size(ctx, "UpperTorso")
	local base = if s then -s.Z / 2 else -0.5
	local z = ctx.state.chestFront or ctx.state.torsoFront or base
	return math.min(z, base)
end

-- Back surface of the torso layers (backpacks sit behind it).
function Fit.backZ(ctx: Ctx): number
	local s = Fit.size(ctx, "UpperTorso")
	local base = if s then s.Z / 2 else 0.5
	return math.max(ctx.state.torsoBack or base, base)
end

-- Colour of whatever covers the legs (bottom primary, dark grey by default).
function Fit.legColor(ctx: Ctx): Color3
	local bottom = ctx.items.bottom
	if bottom then
		return Fit.colorsOf(bottom).primary
	end
	return Color3.fromRGB(58, 60, 64)
end

---------------------------------------------------------------------------------------------------
-- Painting body parts
---------------------------------------------------------------------------------------------------
function Fit.paint(ctx: Ctx, partName: string, color: Color3, material: Enum.Material?)
	local p = ctx.parts[partName]
	if not p then
		return
	end
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	ctx.painted[partName] = ctx.slot
end

function Fit.paintArms(ctx: Ctx, color: Color3, lower: boolean, material: Enum.Material?)
	for _, side in Fit.SIDES do
		Fit.paint(ctx, side .. "UpperArm", color, material)
		if lower then
			Fit.paint(ctx, side .. "LowerArm", color, material)
		end
	end
end

function Fit.paintLegs(ctx: Ctx, color: Color3, lower: boolean, material: Enum.Material?)
	for _, side in Fit.SIDES do
		Fit.paint(ctx, side .. "UpperLeg", color, material)
		if lower then
			Fit.paint(ctx, side .. "LowerLeg", color, material)
		end
	end
end

-- Exposed skin (sleeveless tops, skirts): back to the skin tone, smooth.
function Fit.bare(ctx: Ctx, partName: string)
	Fit.paint(ctx, partName, ctx.skin, Enum.Material.SmoothPlastic)
end

---------------------------------------------------------------------------------------------------
-- Layer parts
---------------------------------------------------------------------------------------------------
local function finish(ctx: Ctx, body: BasePart, partName: string, p: BasePart, name: string?)
	p.Name = name or (ctx.slot .. "_Detail")
	p.Anchored = ctx.anchored
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute(Fit.ATTR_PART, partName)
	p.Parent = ctx.folder
	if not ctx.anchored then
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = p
		w.Parent = p
	end
	ctx.count += 1
end

local function clampSize(s: Vector3): Vector3
	return Vector3.new(math.max(s.X, 0.02), math.max(s.Y, 0.02), math.max(s.Z, 0.02))
end

-- Box at `offset` (body-part local space).
function Fit.box(
	ctx: Ctx,
	partName: string,
	offset: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	name: string?
): Part?
	local body = ctx.parts[partName]
	if not body then
		return nil
	end
	local p = Instance.new("Part")
	p.Size = clampSize(size)
	p.CFrame = body.CFrame * offset
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	p.CastShadow = size.Magnitude > 1.2
	finish(ctx, body, partName, p, name)
	return p
end

-- WedgePart (full height at local +Z, sloping to zero at -Z; slope faces forward and up).
function Fit.wedge(
	ctx: Ctx,
	partName: string,
	offset: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	name: string?
): WedgePart?
	local body = ctx.parts[partName]
	if not body then
		return nil
	end
	local p = Instance.new("WedgePart")
	p.Size = clampSize(size)
	p.CFrame = body.CFrame * offset
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	p.CastShadow = size.Magnitude > 1.2
	finish(ctx, body, partName, p, name)
	return p
end

-- Cylinder whose axis runs along offset.UpVector.
function Fit.cyl(
	ctx: Ctx,
	partName: string,
	offset: CFrame,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?,
	name: string?
): Part?
	local body = ctx.parts[partName]
	if not body then
		return nil
	end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = clampSize(Vector3.new(height, diameter, diameter))
	p.CFrame = body.CFrame * offset * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CastShadow = false
	finish(ctx, body, partName, p, name)
	return p
end

function Fit.ball(
	ctx: Ctx,
	partName: string,
	offset: CFrame,
	diameter: number,
	color: Color3,
	material: Enum.Material?,
	name: string?
): Part?
	local body = ctx.parts[partName]
	if not body then
		return nil
	end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = clampSize(Vector3.new(diameter, diameter, diameter))
	p.CFrame = body.CFrame * offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CastShadow = false
	finish(ctx, body, partName, p, name)
	return p
end

-- In-plane rotations that turn a WedgePart into a flat right triangle lying in the body part's X/Y plane
-- (thickness along Z), with the right angle at the named corner of its bounding box.
local TRI = {
	br = CFrame.Angles(0, math.rad(90), 0),
	bl = CFrame.Angles(0, math.rad(-90), 0),
	tl = CFrame.Angles(0, 0, math.rad(180)) * CFrame.Angles(0, math.rad(90), 0),
	tr = CFrame.Angles(0, 0, math.rad(180)) * CFrame.Angles(0, math.rad(-90), 0),
}
Fit.TRI = TRI

-- Flat right triangle. `at` is the centre of its w x h bounding box (body-part local, may carry an
-- in-plane rotation about Z); corner = "br" | "bl" | "tl" | "tr" (where the right angle sits).
function Fit.tri(
	ctx: Ctx,
	partName: string,
	at: CFrame,
	w: number,
	h: number,
	thick: number,
	corner: string,
	color: Color3,
	material: Enum.Material?,
	name: string?
): WedgePart?
	local rot = TRI[corner] or TRI.br
	return Fit.wedge(ctx, partName, at * rot, Vector3.new(thick, h, w), color, material, name)
end

-- A thin box running from point a to point b (both body-part local, same Z plane), width w.
function Fit.strip(
	ctx: Ctx,
	partName: string,
	a: Vector3,
	b: Vector3,
	w: number,
	thick: number,
	color: Color3,
	material: Enum.Material?,
	name: string?
): Part?
	local d = b - a
	local len = d.Magnitude
	if len < 1e-4 then
		return nil
	end
	local mid = (a + b) / 2
	-- rotate local +Y onto the a->b direction (in the X/Y plane)
	local angle = math.atan2(-d.X, d.Y)
	return Fit.box(
		ctx,
		partName,
		CFrame.new(mid) * CFrame.Angles(0, 0, angle),
		Vector3.new(w, len, thick),
		color,
		material,
		name
	)
end

-- Band wrapped around a limb segment: `y` is the band centre (part local), `pad` how far it stands off.
function Fit.band(
	ctx: Ctx,
	partName: string,
	y: number,
	height: number,
	pad: number,
	color: Color3,
	material: Enum.Material?,
	name: string?
): Part?
	local s = Fit.size(ctx, partName)
	if not s then
		return nil
	end
	return Fit.box(
		ctx,
		partName,
		CFrame.new(0, y, 0),
		Vector3.new(s.X + pad * 2, height, s.Z + pad * 2),
		color,
		material,
		name
	)
end

-- Small round button facing front (-Z) at (x, y) on a surface whose front is at depth z.
function Fit.button(
	ctx: Ctx,
	partName: string,
	x: number,
	y: number,
	z: number,
	diameter: number,
	color: Color3,
	name: string?
): Part?
	return Fit.cyl(
		ctx,
		partName,
		CFrame.new(x, y, z - 0.012) * CFrame.Angles(math.rad(90), 0, 0),
		0.025,
		diameter,
		color,
		Enum.Material.SmoothPlastic,
		name
	)
end

---------------------------------------------------------------------------------------------------
-- Torso helpers shared by tops and outerwear
---------------------------------------------------------------------------------------------------
-- The inverted-triangle "V" opening at the top of the torso front: two flat triangles meeting at the
-- apex. topY/apexY are UpperTorso-local, z = front of the surface it sits on.
function Fit.vee(
	ctx: Ctx,
	width: number,
	topY: number,
	apexY: number,
	z: number,
	color: Color3,
	material: Enum.Material?,
	name: string?
)
	local h = topY - apexY
	if h <= 0.02 or width <= 0.02 then
		return
	end
	local cy = apexY + h / 2
	local thick = 0.02
	Fit.tri(
		ctx,
		"UpperTorso",
		CFrame.new(-width / 4, cy, z - thick / 2),
		width / 2,
		h,
		thick,
		"tr",
		color,
		material,
		name
	)
	Fit.tri(
		ctx,
		"UpperTorso",
		CFrame.new(width / 4, cy, z - thick / 2),
		width / 2,
		h,
		thick,
		"tl",
		color,
		material,
		name
	)
end

-- Pair of shirt-collar points either side of the neck on the torso front. `spread` = open collar.
function Fit.collarPoints(ctx: Ctx, z: number, color: Color3, spread: boolean, name: string?)
	local s = Fit.size(ctx, "UpperTorso")
	if not s then
		return
	end
	local top = s.Y / 2
	local w, h = 0.24, 0.24
	local inner = if spread then 0.2 else 0.07
	-- Each point is a flat triangle hanging from the top edge with its right angle at the inner top
	-- corner, so the tip points down beside the knot (tilted outward when the collar is open).
	Fit.tri(
		ctx,
		"UpperTorso",
		CFrame.new(-(inner + w / 2), top - h / 2 + 0.01, z - 0.02)
			* CFrame.Angles(0, 0, math.rad(if spread then -12 else -4)),
		w,
		h,
		0.035,
		"tr",
		color,
		Enum.Material.Fabric,
		name
	)
	Fit.tri(
		ctx,
		"UpperTorso",
		CFrame.new(inner + w / 2, top - h / 2 + 0.01, z - 0.02)
			* CFrame.Angles(0, 0, math.rad(if spread then 12 else 4)),
		w,
		h,
		0.035,
		"tl",
		color,
		Enum.Material.Fabric,
		name
	)
end

return Fit
