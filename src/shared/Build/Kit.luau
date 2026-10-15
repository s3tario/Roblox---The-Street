--!strict
-- Builder Kit: bake-safe primitives for constructing geometry, signage, markers and lights.
-- Runs identically in Roblox and in Lune (tools/bake). See docs/contracts.md §13 for the rules.
--
-- Conventions:
--   * Every function takes `parent` first and returns the created instance.
--   * CFrames place the CENTER of the part. LookVector (-Z) is "front".
--   * Defaults: Anchored = true, Material = SmoothPlastic, smooth surfaces, CastShadow = true.

local Palette = require(script.Parent.Palette)
local Rng = require(script.Parent.Parent.Util.Rng)

local Kit = {}
Kit.Palette = Palette
Kit.Mat = Enum.Material

---------------------------------------------------------------------------------------------------
-- Math helpers
---------------------------------------------------------------------------------------------------
local rad = math.rad

function Kit.at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Rotation in degrees (applied X, then Y, then Z like CFrame.Angles).
function Kit.rot(rx: number, ry: number, rz: number): CFrame
	return CFrame.Angles(rad(rx), rad(ry), rad(rz))
end

function Kit.rotY(deg: number): CFrame
	return CFrame.Angles(0, rad(deg), 0)
end

-- CFrame at `pos` facing toward `target` (horizontal by default).
function Kit.facing(pos: Vector3, target: Vector3, keepPitch: boolean?): CFrame
	local t = if keepPitch then target else Vector3.new(target.X, pos.Y, target.Z)
	if (t - pos).Magnitude < 1e-4 then
		return CFrame.new(pos)
	end
	return CFrame.lookAt(pos, t)
end

function Kit.hex(s: string): Color3
	return Palette.hex(s)
end

function Kit.rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- f > 0 lightens toward white, f < 0 darkens toward black (|f| in 0..1).
function Kit.shade(c: Color3, f: number): Color3
	if f >= 0 then
		return c:Lerp(Color3.new(1, 1, 1), f)
	end
	return c:Lerp(Color3.new(0, 0, 0), -f)
end

function Kit.lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

-- Deterministic RNG for variation (window lights, weathering, clutter).
function Kit.rng(seed: any)
	return Rng.new(seed)
end

---------------------------------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------------------------------
-- Generic creator: applies props, then sets Parent last.
function Kit.new(className: string, props: { [string]: any }?, parent: Instance?): Instance
	local inst = Instance.new(className)
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(inst :: any)[k] = v
			end
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.model(parent: Instance?, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	if parent then
		m.Parent = parent
	end
	return m
end

function Kit.folder(parent: Instance?, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	if parent then
		f.Parent = parent
	end
	return f
end

local function applyPartDefaults(p: BasePart, props: { [string]: any }?)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(p :: any)[k] = v
			end
		end
	end
end

-- Kit.part(parent, {Size=..., CFrame=..., Color=..., Material=..., Name=...})
function Kit.part(parent: Instance?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	applyPartDefaults(p, props)
	if parent then
		p.Parent = parent
	end
	return p
end

-- Most common call: a box at `cf` of `size`.
function Kit.block(
	parent: Instance?,
	cf: CFrame,
	size: Vector3,
	color: Color3?,
	material: Enum.Material?,
	props: { [string]: any }?
): Part
	local p = Instance.new("Part")
	applyPartDefaults(p, props)
	p.Size = size
	p.CFrame = cf
	if color then
		p.Color = color
	end
	if material then
		p.Material = material
	end
	if parent then
		p.Parent = parent
	end
	return p
end

-- WedgePart: full height at the back (+Z), sloping down to zero height at the front (-Z);
-- the sloped face points forward and up.
function Kit.wedge(
	parent: Instance?,
	cf: CFrame,
	size: Vector3,
	color: Color3?,
	material: Enum.Material?,
	props: { [string]: any }?
): WedgePart
	local p = Instance.new("WedgePart")
	applyPartDefaults(p, props)
	p.Size = size
	p.CFrame = cf
	if color then
		p.Color = color
	end
	if material then
		p.Material = material
	end
	if parent then
		p.Parent = parent
	end
	return p
end

function Kit.cornerWedge(
	parent: Instance?,
	cf: CFrame,
	size: Vector3,
	color: Color3?,
	material: Enum.Material?,
	props: { [string]: any }?
): CornerWedgePart
	local p = Instance.new("CornerWedgePart")
	applyPartDefaults(p, props)
	p.Size = size
	p.CFrame = cf
	if color then
		p.Color = color
	end
	if material then
		p.Material = material
	end
	if parent then
		p.Parent = parent
	end
	return p
end

-- Cylinder whose axis runs along cf.UpVector (Roblox cylinders natively run along X).
function Kit.cylinder(
	parent: Instance?,
	cf: CFrame,
	height: number,
	diameter: number,
	color: Color3?,
	material: Enum.Material?,
	props: { [string]: any }?
): Part
	local p = Instance.new("Part")
	applyPartDefaults(p, props)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = cf * CFrame.Angles(0, 0, rad(90))
	if color then
		p.Color = color
	end
	if material then
		p.Material = material
	end
	if parent then
		p.Parent = parent
	end
	return p
end

function Kit.ball(
	parent: Instance?,
	cf: CFrame,
	diameter: number,
	color: Color3?,
	material: Enum.Material?,
	props: { [string]: any }?
): Part
	local p = Instance.new("Part")
	applyPartDefaults(p, props)
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.CFrame = cf
	if color then
		p.Color = color
	end
	if material then
		p.Material = material
	end
	if parent then
		p.Parent = parent
	end
	return p
end

-- Non-colliding decorative detail (trim, small props): saves physics cost.
function Kit.detail(
	parent: Instance?,
	cf: CFrame,
	size: Vector3,
	color: Color3?,
	material: Enum.Material?,
	props: { [string]: any }?
): Part
	local p = Kit.block(parent, cf, size, color, material, props)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = size.Magnitude > 4
	return p
end

function Kit.weld(a: BasePart, b: BasePart): WeldConstraint
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
	return w
end

---------------------------------------------------------------------------------------------------
-- Markers (anchors, doors, interaction points, event spots)
---------------------------------------------------------------------------------------------------
local function marker(parent: Instance?, name: string, cf: CFrame, size: Vector3): Part
	local p = Instance.new("Part")
	applyPartDefaults(p, nil)
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if parent then
		p.Parent = parent
	end
	return p
end

-- Spawn/teleport target. cf = where the character's root should stand (feet on floor ~3 studs below).
function Kit.anchor(parent: Instance?, anchorId: string, cf: CFrame): Part
	local p = marker(parent, anchorId, cf, Vector3.new(2, 1, 2))
	p:SetAttribute("AnchorId", anchorId)
	p:AddTag("Anchor")
	return p
end

-- Door trigger volume. WorldService adds the ProximityPrompt. Front face should face the approaching player.
-- opts.visible = true keeps it visible (e.g. glass doors built as the trigger itself).
function Kit.door(parent: Instance?, doorId: string, cf: CFrame, size: Vector3, opts: { visible: boolean? }?): Part
	local p = marker(parent, doorId, cf, size)
	p.CanQuery = true -- prompts need queryable parts
	if opts and opts.visible then
		p.Transparency = 0
	end
	p:SetAttribute("DoorId", doorId)
	p:AddTag("Door")
	return p
end

-- Marks an existing part as an interaction point. attrs = extra attributes (e.g. {Shop = "tailor"}).
function Kit.interact(part: BasePart, interactId: string, attrs: { [string]: any }?): BasePart
	part:SetAttribute("InteractId", interactId)
	if attrs then
		for k, v in attrs do
			part:SetAttribute(k, v)
		end
	end
	part:AddTag("Interact")
	part.CanQuery = true
	return part
end

-- Invisible interaction marker when there is no natural part to use.
function Kit.interactPoint(parent: Instance?, interactId: string, cf: CFrame, attrs: { [string]: any }?): Part
	local p = marker(parent, "Interact_" .. interactId, cf, Vector3.new(2, 3, 2))
	Kit.interact(p, interactId, attrs)
	return p
end

function Kit.eventSpot(parent: Instance?, spotId: string, cf: CFrame, size: Vector3?): Part
	local p = marker(parent, "EventSpot_" .. spotId, cf, size or Vector3.new(4, 1, 4))
	p:SetAttribute("EventSpot", spotId)
	p:AddTag("EventSpot")
	return p
end

-- NPC standing spot (front face = direction the NPC faces).
function Kit.npcSpot(parent: Instance?, npcId: string, cf: CFrame): Part
	local p = marker(parent, "NpcSpot_" .. npcId, cf, Vector3.new(2, 1, 2))
	Kit.interact(p, "npc", { NpcId = npcId })
	return p
end

function Kit.spawn(parent: Instance?, name: string, cf: CFrame, color: Color3?): SpawnLocation
	local s = Instance.new("SpawnLocation")
	applyPartDefaults(s, nil)
	s.Name = name
	s.Size = Vector3.new(6, 1, 6)
	s.CFrame = cf
	s.Neutral = true
	s.Duration = 0
	s.Transparency = 1
	s.CanCollide = false
	if color then
		s.Color = color
	end
	if parent then
		s.Parent = parent
	end
	return s
end

---------------------------------------------------------------------------------------------------
-- Signage and light
---------------------------------------------------------------------------------------------------
export type SignOpts = {
	face: Enum.NormalId?,
	font: Enum.Font?,
	weight: Enum.FontWeight?,
	color: Color3?,
	bg: Color3?,
	bgTransparency: number?,
	align: Enum.TextXAlignment?,
	scaled: boolean?,
	textSize: number?,
	glow: boolean?, -- true = unaffected by lighting (neon-ish signs, screens)
	pixelsPerStud: number?,
	padding: number?, -- fraction of the surface (0..0.4)
	stroke: Color3?,
	italic: boolean?,
}

-- Adds a SurfaceGui with text to `part` on opts.face (default Front). Returns the TextLabel.
function Kit.sign(part: BasePart, text: string, opts: SignOpts?): TextLabel
	local o: SignOpts = opts or ({} :: any)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = o.face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = o.pixelsPerStud or 40
	gui.LightInfluence = if o.glow then 0 else 1
	gui.Brightness = if o.glow then 1.6 else 1
	gui.ResetOnSpawn = false
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	local pad = o.padding or 0.08
	label.Size = UDim2.fromScale(1 - pad * 2, 1 - pad * 2)
	label.Position = UDim2.fromScale(pad, pad)
	label.BackgroundTransparency = if o.bg then (o.bgTransparency or 0) else 1
	if o.bg then
		label.BackgroundColor3 = o.bg
	end
	label.BorderSizePixel = 0
	label.Text = text
	label.TextColor3 = o.color or Color3.new(1, 1, 1)
	label.FontFace = Font.fromEnum(o.font or Enum.Font.GothamBold)
	if o.weight then
		label.FontFace =
			Font.new(label.FontFace.Family, o.weight, if o.italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
	end
	label.TextScaled = if o.scaled == nil then true else o.scaled
	label.TextSize = o.textSize or 48
	label.TextWrapped = true
	label.TextXAlignment = o.align or Enum.TextXAlignment.Center
	if o.stroke then
		local s = Instance.new("UIStroke")
		s.Color = o.stroke
		s.Thickness = 2
		s.Parent = label
	end
	label.Parent = gui
	return label
end

-- A ready-made sign panel: a thin part with text on its front face.
function Kit.signPanel(
	parent: Instance?,
	cf: CFrame,
	size: Vector3,
	text: string,
	panelColor: Color3,
	opts: SignOpts?
): (Part, TextLabel)
	local p = Kit.block(parent, cf, size, panelColor, Enum.Material.SmoothPlastic, { CanCollide = false })
	p.Name = "Sign"
	return p, Kit.sign(p, text, opts)
end

-- kind: "point" | "spot" | "surface"
function Kit.light(part: BasePart, kind: string, props: { [string]: any }?): Light
	local className = if kind == "spot" then "SpotLight" elseif kind == "surface" then "SurfaceLight" else "PointLight"
	local l = Instance.new(className) :: Light
	l.Shadows = false
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	l.Parent = part
	return l
end

---------------------------------------------------------------------------------------------------
-- Composite helpers
---------------------------------------------------------------------------------------------------
export type WindowGridOpts = {
	cf: CFrame, -- centre of the facade plane; LookVector points OUT of the building
	width: number,
	height: number,
	cols: number,
	rows: number,
	glassColor: Color3,
	frameColor: Color3,
	frameMaterial: Enum.Material?,
	frameThickness: number?, -- mullion width
	depth: number?, -- mullion depth (protrusion)
	glassTransparency: number?,
	glassReflectance: number?,
	litChance: number?, -- fraction of panes rendered as warm lit windows
	litColor: Color3?,
	seed: any?,
	glassMaterial: Enum.Material?,
}

-- Curtain-wall facade: one big glass sheet + mullion grid (cheap: rows + cols + 1 parts), optional lit panes.
function Kit.windowGrid(parent: Instance, o: WindowGridOpts): Model
	local m = Kit.model(parent, "WindowGrid")
	local t = o.frameThickness or 0.4
	local d = o.depth or 0.4
	local cf = o.cf
	local glass =
		Kit.block(m, cf, Vector3.new(o.width, o.height, 0.2), o.glassColor, o.glassMaterial or Enum.Material.Glass)
	glass.Name = "Glass"
	glass.Transparency = o.glassTransparency or 0.15
	glass.Reflectance = o.glassReflectance or 0.25
	glass.CastShadow = false
	local fm = o.frameMaterial or Enum.Material.Metal
	-- vertical mullions
	for c = 0, o.cols do
		local x = -o.width / 2 + (o.width / o.cols) * c
		Kit.detail(m, cf * CFrame.new(x, 0, -d / 2), Vector3.new(t, o.height, d), o.frameColor, fm)
	end
	-- horizontal transoms
	for r = 0, o.rows do
		local y = -o.height / 2 + (o.height / o.rows) * r
		Kit.detail(m, cf * CFrame.new(0, y, -d / 2), Vector3.new(o.width, t, d), o.frameColor, fm)
	end
	-- lit panes (thin neon-ish rectangles just behind the glass)
	local lit = o.litChance or 0
	if lit > 0 then
		local rng = Rng.new(o.seed or "windows")
		local pw, ph = o.width / o.cols, o.height / o.rows
		for r = 0, o.rows - 1 do
			for c = 0, o.cols - 1 do
				if rng:chance(lit) then
					local x = -o.width / 2 + pw * (c + 0.5)
					local y = -o.height / 2 + ph * (r + 0.5)
					local pane = Kit.detail(
						m,
						cf * CFrame.new(x, y, 0.25),
						Vector3.new(pw - t * 1.5, ph - t * 1.5, 0.1),
						o.litColor or Color3.fromRGB(255, 226, 176),
						Enum.Material.Neon
					)
					pane.Transparency = 0.35
					pane:AddTag("LitWindow")
				end
			end
		end
	end
	return m
end

-- Straight staircase rising along cfBase.LookVector. cfBase = centre of the bottom step's footprint at floor level.
function Kit.stairs(
	parent: Instance,
	cfBase: CFrame,
	width: number,
	steps: number,
	rise: number,
	run: number,
	color: Color3,
	material: Enum.Material?
): Model
	local m = Kit.model(parent, "Stairs")
	for i = 0, steps - 1 do
		local h = rise * (i + 1)
		Kit.block(
			m,
			cfBase * CFrame.new(0, h / 2, -run * i),
			Vector3.new(width, h, run),
			color,
			material or Enum.Material.Concrete
		)
	end
	return m
end

-- Places `count` copies produced by fn(i, cf) on a circle of `radius` around cf (facing outward).
function Kit.ring(parent: Instance, cf: CFrame, radius: number, count: number, fn: (number, CFrame) -> ())
	for i = 0, count - 1 do
		local a = (i / count) * math.pi * 2
		local pos = cf * CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		fn(i, CFrame.lookAt(pos.Position, pos.Position + (pos.Position - cf.Position)))
	end
end

-- Hollow rectangular room shell: floor, 4 walls (with optional door gaps on walls), ceiling.
export type RoomOpts = {
	cf: CFrame, -- centre of the floor's TOP surface
	size: Vector3, -- interior width (X), height (Y), depth (Z)
	wall: number?, -- wall thickness
	floorColor: Color3,
	floorMaterial: Enum.Material?,
	wallColor: Color3,
	wallMaterial: Enum.Material?,
	ceilingColor: Color3?,
	ceilingMaterial: Enum.Material?,
	noCeiling: boolean?,
	-- gaps: list of {side = "front"|"back"|"left"|"right", offset = along-wall centre, width, height}
	gaps: { { side: string, offset: number, width: number, height: number } }?,
}

function Kit.room(parent: Instance, o: RoomOpts): Model
	local m = Kit.model(parent, "Room")
	local w = o.wall or 1
	local sx, sy, sz = o.size.X, o.size.Y, o.size.Z
	local cf = o.cf
	Kit.block(
		m,
		cf * CFrame.new(0, -0.5, 0),
		Vector3.new(sx + w * 2, 1, sz + w * 2),
		o.floorColor,
		o.floorMaterial or Enum.Material.WoodPlanks
	).Name =
		"Floor"
	if not o.noCeiling then
		Kit.block(
			m,
			cf * CFrame.new(0, sy + 0.5, 0),
			Vector3.new(sx + w * 2, 1, sz + w * 2),
			o.ceilingColor or Color3.fromRGB(235, 235, 230),
			o.ceilingMaterial or Enum.Material.SmoothPlastic
		).Name =
			"Ceiling"
	end
	local sides: { [string]: { cf: CFrame, len: number, axis: string } } = {
		front = { cf = cf * CFrame.new(0, sy / 2, -sz / 2 - w / 2), len = sx + w * 2, axis = "x" },
		back = { cf = cf * CFrame.new(0, sy / 2, sz / 2 + w / 2), len = sx + w * 2, axis = "x" },
		left = { cf = cf * CFrame.new(-sx / 2 - w / 2, sy / 2, 0), len = sz, axis = "z" },
		right = { cf = cf * CFrame.new(sx / 2 + w / 2, sy / 2, 0), len = sz, axis = "z" },
	}
	local allGaps: { { side: string, offset: number, width: number, height: number } } = o.gaps or {}
	for sideName, s in sides do
		local gaps = {}
		for _, g in allGaps do
			if g.side == sideName then
				table.insert(gaps, g)
			end
		end
		table.sort(gaps, function(a, b)
			return a.offset < b.offset
		end)
		-- walk along the wall from -len/2 to +len/2, emitting solid segments between gaps
		local cursor = -s.len / 2
		local function seg(fromA: number, toA: number, yLo: number, yHi: number)
			local L = toA - fromA
			local H = yHi - yLo
			if L <= 0.01 or H <= 0.01 then
				return
			end
			local mid = (fromA + toA) / 2
			local ymid = (yLo + yHi) / 2 - sy / 2
			local size = if s.axis == "x" then Vector3.new(L, H, w) else Vector3.new(w, H, L)
			local off = if s.axis == "x" then CFrame.new(mid, ymid, 0) else CFrame.new(0, ymid, mid)
			Kit.block(m, s.cf * off, size, o.wallColor, o.wallMaterial or Enum.Material.SmoothPlastic).Name = "Wall"
		end
		for _, g in gaps do
			local a, b = g.offset - g.width / 2, g.offset + g.width / 2
			seg(cursor, a, 0, sy)
			seg(a, b, g.height, sy) -- lintel above the gap
			cursor = b
		end
		seg(cursor, s.len / 2, 0, sy)
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- Inspection
---------------------------------------------------------------------------------------------------
function Kit.countParts(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

return Kit
