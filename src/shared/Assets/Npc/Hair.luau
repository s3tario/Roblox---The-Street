--!strict
-- Hair: hairstyles built from parts around a head (front = -Z). Used by NpcRig.build (anchored) and by
-- NpcRig.spawn (welded to a real R15 head). Sized from the head part, so any head size works.
--   Hair.build(head, style, color, opts) -> Folder?   (nil for "bald" without a fringe)
--   styles: short side_part bun long curly buzz ponytail bald
--   opts = { anchored: boolean, parent: Instance, hatted: boolean? (drop pieces a hat would cover) }
-- Bake-safe.

local Hair = {}

Hair.STYLES = { "short", "side_part", "bun", "long", "curly", "buzz", "ponytail", "bald" }
Hair.FOLDER = "Hair"

export type Opts = { anchored: boolean, parent: Instance, hatted: boolean?, skin: Color3? }

type Builder = {
	head: BasePart,
	h: Vector3,
	top: number,
	folder: Folder,
	anchored: boolean,
	hatted: boolean,
	count: number,
}

local function shade(c: Color3, f: number): Color3
	if f >= 0 then
		return c:Lerp(Color3.new(1, 1, 1), f)
	end
	return c:Lerp(Color3.new(0, 0, 0), -f)
end

local function finish(b: Builder, p: BasePart, name: string)
	p.Name = name
	p.Anchored = b.anchored
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = b.folder
	if not b.anchored then
		local w = Instance.new("WeldConstraint")
		w.Part0 = b.head
		w.Part1 = p
		w.Parent = p
	end
	b.count += 1
end

-- `onTop` marks crown pieces that a hat replaces.
local function box(b: Builder, offset: CFrame, size: Vector3, color: Color3, onTop: boolean?, name: string?): Part?
	if onTop and b.hatted then
		return nil
	end
	local p = Instance.new("Part")
	p.Size = Vector3.new(math.max(size.X, 0.02), math.max(size.Y, 0.02), math.max(size.Z, 0.02))
	p.CFrame = b.head.CFrame * offset
	p.Color = color
	finish(b, p, name or "Hair")
	return p
end

local function ball(b: Builder, offset: CFrame, d: number, color: Color3, onTop: boolean?): Part?
	if onTop and b.hatted then
		return nil
	end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(d, d, d)
	p.CFrame = b.head.CFrame * offset
	p.Color = color
	finish(b, p, "Hair")
	return p
end

local function wedge(b: Builder, offset: CFrame, size: Vector3, color: Color3, onTop: boolean?): WedgePart?
	if onTop and b.hatted then
		return nil
	end
	local p = Instance.new("WedgePart")
	p.Size = size
	p.CFrame = b.head.CFrame * offset
	p.Color = color
	finish(b, p, "Hair")
	return p
end

---------------------------------------------------------------------------------------------------
-- Shared pieces
---------------------------------------------------------------------------------------------------
local function cap(b: Builder, c: Color3, pad: number, height: number)
	local h, top = b.h, b.top
	box(
		b,
		CFrame.new(0, top + height / 2 - 0.03, 0),
		Vector3.new(h.X + pad * 2, height, h.Z + pad * 2),
		c,
		true,
		"Hair_Crown"
	)
end

local function back(b: Builder, c: Color3, pad: number, drop: number)
	local h, top = b.h, b.top
	box(
		b,
		CFrame.new(0, top - drop / 2 + 0.01, h.Z / 2 + pad / 2 - 0.01),
		Vector3.new(h.X + pad * 2, drop, pad + 0.02),
		c,
		false,
		"Hair_Back"
	)
end

local function sides(b: Builder, c: Color3, pad: number, drop: number, depth: number)
	local h, top = b.h, b.top
	for _, sx in { -1, 1 } do
		box(
			b,
			CFrame.new(sx * (h.X / 2 + pad / 2 - 0.01), top - drop / 2 + 0.01, h.Z / 2 - depth / 2),
			Vector3.new(pad + 0.02, drop, depth),
			c,
			false,
			"Hair_Side"
		)
	end
end

local function fringe(b: Builder, c: Color3, pad: number, height: number, tilt: number?)
	local h, top = b.h, b.top
	box(
		b,
		CFrame.new(0, top - height / 2 + 0.02, -h.Z / 2 - pad / 2 + 0.01) * CFrame.Angles(0, 0, math.rad(tilt or 0)),
		Vector3.new(h.X + pad * 2 - 0.02, height, pad + 0.02),
		c,
		true,
		"Hair_Fringe"
	)
end

---------------------------------------------------------------------------------------------------
-- Styles
---------------------------------------------------------------------------------------------------
local STYLES: { [string]: (Builder, Color3) -> () } = {}

STYLES.short = function(b, c)
	local dark = shade(c, -0.1)
	cap(b, c, 0.06, 0.17)
	back(b, dark, 0.07, 0.62)
	sides(b, dark, 0.06, 0.4, b.h.Z * 0.62)
	fringe(b, c, 0.06, 0.15)
end

STYLES.side_part = function(b, c)
	local h, top = b.h, b.top
	local dark = shade(c, -0.1)
	cap(b, c, 0.06, 0.17)
	back(b, dark, 0.07, 0.62)
	sides(b, dark, 0.06, 0.42, h.Z * 0.62)
	fringe(b, c, 0.07, 0.16, -4)
	-- swept volume on the long side and the parting line
	wedge(
		b,
		CFrame.new(h.X * 0.14, top + 0.19, -h.Z * 0.12),
		Vector3.new(h.X * 0.7, 0.14, h.Z * 0.7),
		shade(c, 0.06),
		true
	)
	box(
		b,
		CFrame.new(-h.X * 0.23, top + 0.142, -h.Z * 0.1),
		Vector3.new(0.035, 0.012, h.Z * 0.6),
		shade(c, -0.35),
		true,
		"Hair_Part"
	)
end

STYLES.buzz = function(b, c)
	local h, top = b.h, b.top
	cap(b, c, 0.02, 0.06)
	back(b, c, 0.025, 0.46)
	sides(b, c, 0.02, 0.3, h.Z * 0.6)
	box(b, CFrame.new(0, top - 0.025, -h.Z / 2 - 0.006), Vector3.new(h.X + 0.03, 0.07, 0.03), c, true, "Hair_Line")
end

STYLES.bald = function(b, c)
	-- a neat horseshoe of short hair round the back and sides
	local h = b.h
	box(b, CFrame.new(0, -h.Y * 0.02, h.Z / 2 + 0.015), Vector3.new(h.X + 0.04, 0.3, 0.05), c, false, "Hair_Back")
	for _, sx in { -1, 1 } do
		box(
			b,
			CFrame.new(sx * (h.X / 2 + 0.015), -h.Y * 0.01, h.Z * 0.22),
			Vector3.new(0.05, 0.26, h.Z * 0.5),
			c,
			false,
			"Hair_Side"
		)
	end
end

STYLES.bun = function(b, c)
	local h, top = b.h, b.top
	local dark = shade(c, -0.08)
	cap(b, c, 0.05, 0.13)
	back(b, dark, 0.06, 0.6)
	sides(b, dark, 0.05, 0.5, h.Z * 0.7)
	fringe(b, c, 0.05, 0.12, 3)
	ball(b, CFrame.new(0, top + 0.1, h.Z / 2 + 0.14), 0.52, c, true)
	if not b.hatted then
		local band = Instance.new("Part")
		band.Shape = Enum.PartType.Cylinder
		band.Size = Vector3.new(0.08, 0.36, 0.36)
		band.CFrame = b.head.CFrame * CFrame.new(0, top + 0.02, h.Z / 2 + 0.07) * CFrame.Angles(0, math.rad(90), 0)
		band.Color = shade(c, -0.4)
		finish(b, band, "Hair_Band")
	end
end

STYLES.long = function(b, c)
	local h, top = b.h, b.top
	local dark = shade(c, -0.1)
	cap(b, c, 0.07, 0.17)
	fringe(b, c, 0.07, 0.17, -5)
	local drop = h.Y + 0.4
	box(
		b,
		CFrame.new(0, top - drop / 2 + 0.05, h.Z / 2 + 0.06),
		Vector3.new(h.X + 0.16, drop, 0.16),
		dark,
		false,
		"Hair_Back"
	)
	for _, sx in { -1, 1 } do
		local sd = h.Y * 0.98
		box(
			b,
			CFrame.new(sx * (h.X / 2 + 0.06), top - sd / 2 + 0.04, h.Z * 0.12),
			Vector3.new(0.13, sd, h.Z * 0.8),
			dark,
			false,
			"Hair_Side"
		)
		-- strands framing the face
		box(
			b,
			CFrame.new(sx * (h.X / 2 - 0.03), top - sd * 0.45, -h.Z / 2 - 0.03),
			Vector3.new(0.15, sd * 0.85, 0.08),
			c,
			false,
			"Hair_Strand"
		)
	end
end

STYLES.curly = function(b, c)
	local h, top = b.h, b.top
	local d = h.X * 0.36
	cap(b, shade(c, -0.08), 0.03, 0.18)
	local light = shade(c, 0.05)
	for _, x in { -0.36, 0, 0.36 } do
		for _, z in { -0.32, 0, 0.32 } do
			ball(b, CFrame.new(x * h.X, top + 0.06 + (if z == 0 then 0.04 else 0), z * h.Z), d, light, true)
		end
	end
	for _, x in { -0.36, 0, 0.36 } do
		ball(b, CFrame.new(x * h.X, top - 0.28, h.Z / 2 + 0.02), d * 0.95, c, false)
	end
	for _, sx in { -1, 1 } do
		ball(b, CFrame.new(sx * (h.X / 2 + 0.02), top - 0.16, h.Z * 0.12), d * 0.85, c, false)
	end
end

STYLES.ponytail = function(b, c)
	local h, top = b.h, b.top
	local dark = shade(c, -0.08)
	cap(b, c, 0.05, 0.14)
	back(b, dark, 0.06, 0.55)
	sides(b, dark, 0.05, 0.42, h.Z * 0.66)
	fringe(b, c, 0.05, 0.13, 2)
	local band = Instance.new("Part")
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(0.1, 0.24, 0.24)
	band.CFrame = b.head.CFrame * CFrame.new(0, top - 0.12, h.Z / 2 + 0.1) * CFrame.Angles(0, math.rad(90), 0)
	band.Color = shade(c, -0.45)
	finish(b, band, "Hair_Band")
	box(
		b,
		CFrame.new(0, top - 0.52, h.Z / 2 + 0.18) * CFrame.Angles(math.rad(-12), 0, 0),
		Vector3.new(0.24, 0.78, 0.2),
		c,
		false,
		"Hair_Tail"
	)
	ball(b, CFrame.new(0, top - 0.92, h.Z / 2 + 0.26), 0.24, dark, false)
end

---------------------------------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------------------------------
function Hair.isStyle(style: any): boolean
	return type(style) == "string" and STYLES[style] ~= nil
end

function Hair.build(head: BasePart, style: string?, color: Color3, opts: Opts): Folder?
	local fn = STYLES[style or "short"] or STYLES.short
	local folder = Instance.new("Folder")
	folder.Name = Hair.FOLDER
	local b: Builder = {
		head = head,
		h = head.Size,
		top = head.Size.Y / 2,
		folder = folder,
		anchored = opts.anchored,
		hatted = opts.hatted == true,
		count = 0,
	}
	fn(b, color)
	if b.count == 0 then
		folder:Destroy()
		return nil
	end
	folder:SetAttribute("HairStyle", style or "short")
	folder.Parent = opts.parent
	return folder
end

return Hair
