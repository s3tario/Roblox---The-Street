--!strict
-- Face: a simple, friendly face drawn with GUI frames on a SurfaceGui on the head's front face (no decal
-- ids). Eyes sit 7% of the head height above centre and 20% of its width either side, which is where the
-- wardrobe's glasses expect them. Expressions: "smile" | "neutral" | "grin" | "focused". Bake-safe.

local Face = {}

Face.EXPRESSIONS = { "smile", "neutral", "grin", "focused" }
Face.EYE_Y = 0.07 -- fraction of head height above centre
Face.EYE_X = 0.2 -- fraction of head width from the centre line

local INK = Color3.fromRGB(38, 32, 30)

local function shade(c: Color3, f: number): Color3
	if f >= 0 then
		return c:Lerp(Color3.new(1, 1, 1), f)
	end
	return c:Lerp(Color3.new(0, 0, 0), -f)
end

local function frame(parent: Instance, name: string, x: number, y: number, w: number, h: number, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.Parent = parent
	return f
end

local function round(f: GuiObject, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r or 0.5, 0)
	c.Parent = f
end

export type FaceOpts = {
	skin: Color3,
	brow: Color3?, -- eyebrow colour (usually a darker hair colour)
	expression: string?,
	lashes: boolean?,
}

-- Adds the face to `head` (front = -Z). Returns the SurfaceGui.
function Face.build(head: BasePart, opts: FaceOpts): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 120
	gui.LightInfluence = 1
	gui.ClipsDescendants = true
	gui.Parent = head

	local expression = opts.expression or "smile"
	local eyeY = 0.5 - Face.EYE_Y
	local brow = opts.brow or shade(opts.skin, -0.55)

	for _, sx in { -1, 1 } do
		local x = 0.5 + sx * Face.EYE_X
		local eyeH = if expression == "focused" then 0.11 else 0.15
		local eye = frame(gui, "Eye", x, eyeY, 0.095, eyeH, INK)
		round(eye)
		local glint = frame(eye, "Glint", 0.68, 0.3, 0.36, 0.26, Color3.fromRGB(255, 255, 255))
		round(glint)
		if opts.lashes then
			local lash = frame(gui, "Lash", x + sx * 0.055, eyeY - eyeH * 0.42, 0.05, 0.03, INK)
			lash.Rotation = sx * 30
			round(lash)
		end
		local by = eyeY - (if expression == "focused" then 0.13 else 0.15)
		local b = frame(gui, "Brow", x, by, 0.17, 0.04, brow)
		b.Rotation = if expression == "focused" then sx * 10 elseif expression == "grin" then sx * -6 else sx * -3
		round(b)
	end

	-- nose: a soft shadow
	local nose = frame(gui, "Nose", 0.5, 0.56, 0.06, 0.07, shade(opts.skin, -0.14))
	nose.BackgroundTransparency = 0.25
	round(nose)

	-- mouth
	if expression == "neutral" or expression == "focused" then
		local m = frame(gui, "Mouth", 0.5, 0.7, 0.18, 0.035, INK)
		round(m)
	elseif expression == "grin" then
		local m = frame(gui, "Mouth", 0.5, 0.69, 0.26, 0.09, INK)
		round(m, 0.45)
		local teeth = frame(m, "Teeth", 0.5, 0.3, 0.84, 0.36, Color3.fromRGB(250, 248, 242))
		round(teeth, 0.3)
	else
		local m = frame(gui, "Mouth", 0.5, 0.7, 0.18, 0.04, INK)
		round(m)
		for _, sx in { -1, 1 } do
			local corner = frame(gui, "MouthCorner", 0.5 + sx * 0.1, 0.682, 0.06, 0.035, INK)
			corner.Rotation = sx * -32
			round(corner)
		end
	end

	-- a hint of warmth on the cheeks
	for _, sx in { -1, 1 } do
		local cheek = frame(gui, "Cheek", 0.5 + sx * 0.27, 0.62, 0.12, 0.07, Color3.fromRGB(226, 120, 110))
		cheek.BackgroundTransparency = 0.82
		round(cheek)
	end
	return gui
end

return Face
