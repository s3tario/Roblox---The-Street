--!strict
-- Wrist and eyewear layer builders.
--   wrist: "watch" (strap or bracelet, case and bezel, dial with hands; tier details: chronograph
--          sub-dials and pushers, gold indices, a platinum moonphase; opts.glint adds a sparkle) and
--          "band" (fitness band). Worn on the left wrist, face turned outward, standing proud of any cuff.
--   eyes:  "glasses" (round wire, black rectangles, gold aviators, tortoiseshell). The lens rims are drawn
--          crisply with a SurfaceGui (UICorner + UIStroke) on a clear plate in front of the face; bridge
--          hinges and temples are thin parts running back along the head.
-- Bake-safe.

local Fit = require(script.Parent.Fit)

type Ctx = Fit.Ctx

local rad = math.rad
local SMOOTH = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal
local LEATHER = Enum.Material.Leather
local NEON = Enum.Material.Neon

local WRIST = "LeftLowerArm"

local function colorDistance(a: Color3, b: Color3): number
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B)
end

local function hasTag(item: any, tag: string): boolean
	if type(item) ~= "table" or type(item.tags) ~= "table" then
		return false
	end
	return table.find(item.tags, tag) ~= nil
end

---------------------------------------------------------------------------------------------------
-- Watch
---------------------------------------------------------------------------------------------------
local CASE_METAL: { [string]: Color3 } = {
	steel = Fit.METALS.steel,
	bronze = Fit.METALS.bronze,
	gold = Fit.METALS.gold,
	platinum = Fit.METALS.platinum,
}

local function watch(ctx: Ctx)
	local s = Fit.size(ctx, WRIST)
	if not s then
		return
	end
	local col = ctx.colors
	local item = ctx.item
	local style = item.style or "steel"
	local case = col.primary
	if CASE_METAL[style] and colorDistance(case, CASE_METAL[style]) > 0.6 then
		case = CASE_METAL[style]
	end
	local bracelet = colorDistance(col.secondary, col.primary) < 0.25
	local y = -s.Y / 2 + 0.075
	local pad = 0.05
	-- strap (leather) or bracelet (metal links: a band plus two link lines)
	Fit.band(ctx, WRIST, y, 0.1, pad, col.secondary, if bracelet then METAL else LEATHER, "wrist_Strap")
	if bracelet then
		for _, dy in { -0.028, 0.028 } do
			Fit.band(ctx, WRIST, y + dy, 0.012, pad + 0.004, Fit.shade(col.secondary, -0.25), METAL, "wrist_Link")
		end
	end
	local d = if style == "platinum" then 0.32 elseif style == "gold" then 0.26 else 0.29
	local caseX = -(s.X / 2 + pad + 0.024)
	local face = CFrame.Angles(0, 0, rad(90)) -- cylinder axis along X (facing out from the left wrist)
	local bezel = Fit.cyl(ctx, WRIST, CFrame.new(caseX, y, 0) * face, 0.05, d, case, METAL, "wrist_Case")
	if bezel then
		bezel.Reflectance = if ctx.glint then 0.3 else 0.12
	end
	local dialX = caseX - 0.03
	Fit.cyl(ctx, WRIST, CFrame.new(dialX, y, 0) * face, 0.014, d * 0.8, col.accent, SMOOTH, "wrist_Dial")
	-- crown at "3 o'clock" (toward the front of the arm)
	Fit.box(
		ctx,
		WRIST,
		CFrame.new(caseX, y, -d / 2 - 0.012),
		Vector3.new(0.03, 0.035, 0.03),
		case,
		METAL,
		"wrist_Crown"
	)
	-- hands: hour toward 10 o'clock, minute toward 2 o'clock (dial plane = the arm's Y/Z plane)
	local handX = dialX - 0.009
	local ink = if (col.accent.R + col.accent.G + col.accent.B) > 1.6
		then Color3.fromRGB(30, 30, 34)
		else Color3.fromRGB(235, 235, 230)
	for _, h in { { len = d * 0.24, angle = 60 }, { len = d * 0.34, angle = -55 } } do
		local a = rad(h.angle)
		Fit.box(
			ctx,
			WRIST,
			CFrame.new(handX, y + math.cos(a) * h.len / 2, math.sin(a) * h.len / 2) * CFrame.Angles(a, 0, 0),
			Vector3.new(0.006, h.len, 0.016),
			ink,
			SMOOTH,
			"wrist_Hand"
		)
	end
	if hasTag(item, "chronograph") then
		for _, dz in { -1, 1 } do
			Fit.cyl(
				ctx,
				WRIST,
				CFrame.new(handX + 0.002, y - d * 0.12, dz * d * 0.18) * face,
				0.006,
				d * 0.2,
				Fit.shade(col.accent, -0.35),
				SMOOTH,
				"wrist_SubDial"
			)
			Fit.box(
				ctx,
				WRIST,
				CFrame.new(caseX, y + dz * d * 0.32, -d * 0.4),
				Vector3.new(0.025, 0.03, 0.04),
				case,
				METAL,
				"wrist_Pusher"
			)
		end
	elseif style == "platinum" then
		-- moonphase aperture with a gold moon
		Fit.cyl(
			ctx,
			WRIST,
			CFrame.new(handX + 0.002, y - d * 0.2, 0) * face,
			0.006,
			d * 0.26,
			Fit.shade(col.accent, 0.25),
			SMOOTH,
			"wrist_Moonphase"
		)
		Fit.ball(
			ctx,
			WRIST,
			CFrame.new(handX - 0.004, y - d * 0.2, d * 0.04),
			0.045,
			Fit.METALS.gold,
			METAL,
			"wrist_Moon"
		)
	elseif style == "gold" then
		for k = 0, 3 do
			local a = rad(k * 90)
			Fit.box(
				ctx,
				WRIST,
				CFrame.new(handX + 0.002, y + math.cos(a) * d * 0.32, math.sin(a) * d * 0.32),
				Vector3.new(0.006, 0.03, 0.03),
				case,
				METAL,
				"wrist_Index"
			)
		end
	end
	if ctx.glint then
		-- a small four-point sparkle on the bezel rim
		for _, a in { 45, -45 } do
			Fit.box(
				ctx,
				WRIST,
				CFrame.new(caseX - 0.03, y + d * 0.36, -d * 0.3) * CFrame.Angles(rad(a), 0, 0),
				Vector3.new(0.01, 0.09, 0.012),
				Color3.fromRGB(255, 252, 235),
				NEON,
				"wrist_Glint"
			)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Fitness band
---------------------------------------------------------------------------------------------------
local function band(ctx: Ctx)
	local s = Fit.size(ctx, WRIST)
	if not s then
		return
	end
	local col = ctx.colors
	local y = -s.Y / 2 + 0.075
	Fit.band(ctx, WRIST, y, 0.09, 0.04, col.primary, SMOOTH, "wrist_Band")
	local x = -(s.X / 2 + 0.04 + 0.014)
	Fit.box(ctx, WRIST, CFrame.new(x, y, 0), Vector3.new(0.028, 0.08, 0.3), col.secondary, SMOOTH, "wrist_Screen")
	Fit.box(
		ctx,
		WRIST,
		CFrame.new(x - 0.016, y, -0.07),
		Vector3.new(0.006, 0.03, 0.05),
		col.accent,
		NEON,
		"wrist_Pulse"
	)
end

---------------------------------------------------------------------------------------------------
-- Glasses
---------------------------------------------------------------------------------------------------
type LensStyle = {
	w: number,
	h: number,
	corner: number, -- UICorner radius as a fraction of the lens size
	stroke: number, -- rim thickness (studs)
	tint: Color3?,
	tintAlpha: number,
	brow: boolean?,
	doubleBridge: boolean?,
	gradient: boolean?,
	metal: boolean?,
}

local LENSES: { [string]: LensStyle } = {
	round = { w = 0.3, h = 0.3, corner = 0.5, stroke = 0.022, tintAlpha = 0.85, metal = true },
	rect = { w = 0.34, h = 0.22, corner = 0.12, stroke = 0.04, tintAlpha = 0.85, brow = true },
	aviator = {
		w = 0.36,
		h = 0.3,
		corner = 0.42,
		stroke = 0.02,
		tintAlpha = 0.25,
		doubleBridge = true,
		metal = true,
	},
	tortoise = { w = 0.34, h = 0.25, corner = 0.3, stroke = 0.045, tintAlpha = 0.85, gradient = true },
}

local PPS = 250

local function guiFrame(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3, alpha: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BackgroundTransparency = alpha
	f.Parent = parent
	return f
end

local function glasses(ctx: Ctx)
	local h = Fit.size(ctx, "Head")
	if not h then
		return
	end
	local col = ctx.colors
	local lens = LENSES[ctx.item.style or "rect"] or LENSES.rect
	local frameColor = col.primary
	local eyeY = h.Y * 0.07
	local eyeX = h.X * 0.2
	local plateW, plateH = h.X * 0.86, 0.38
	local plateZ = -h.Z / 2 - 0.035
	local plate = Fit.box(
		ctx,
		"Head",
		CFrame.new(0, eyeY, plateZ),
		Vector3.new(plateW, plateH, 0.02),
		frameColor,
		SMOOTH,
		"eyes_Frame"
	)
	if plate then
		plate.Transparency = 1
		plate.CastShadow = false
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Lenses"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = PPS
		gui.LightInfluence = 1
		gui.Parent = plate
		local function sx(studs: number): number
			return studs / plateW
		end
		local function sy(studs: number): number
			return studs / plateH
		end
		local tint = if lens.tintAlpha < 0.5 then col.secondary else Color3.fromRGB(200, 214, 224)
		for _, side in { -1, 1 } do
			local lensFrame = guiFrame(
				gui,
				"Lens",
				UDim2.fromScale(sx(lens.w), sy(lens.h)),
				UDim2.fromScale(0.5 + sx(side * eyeX), 0.5),
				tint,
				lens.tintAlpha
			)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(lens.corner, 0)
			corner.Parent = lensFrame
			local rim = Instance.new("UIStroke")
			rim.Color = frameColor
			rim.Thickness = math.max(2, math.floor(lens.stroke * PPS + 0.5))
			rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			rim.Parent = lensFrame
			if lens.gradient then
				local g = Instance.new("UIGradient")
				g.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, col.primary),
					ColorSequenceKeypoint.new(0.35, col.secondary),
					ColorSequenceKeypoint.new(0.6, col.accent),
					ColorSequenceKeypoint.new(1, col.primary),
				})
				g.Rotation = 35
				g.Parent = rim
			end
			if lens.brow then
				guiFrame(
					gui,
					"Brow",
					UDim2.fromScale(sx(lens.w + lens.stroke), sy(lens.stroke * 1.4)),
					UDim2.fromScale(0.5 + sx(side * eyeX), 0.5 - sy(lens.h / 2)),
					frameColor,
					0
				)
			end
			-- end piece from the rim to the plate edge (where the hinge sits)
			local outer = eyeX + lens.w / 2
			local span = plateW / 2 - outer
			if span > 0 then
				guiFrame(
					gui,
					"EndPiece",
					UDim2.fromScale(sx(span + lens.stroke), sy(lens.stroke * 1.2)),
					UDim2.fromScale(0.5 + sx(side * (outer + span / 2)), 0.5 - sy(lens.h * 0.3)),
					frameColor,
					0
				)
			end
		end
		local gap = eyeX * 2 - lens.w
		guiFrame(
			gui,
			"Bridge",
			UDim2.fromScale(sx(gap + lens.stroke * 2), sy(math.max(0.022, lens.stroke))),
			UDim2.fromScale(0.5, 0.5 - sy(lens.h * 0.18)),
			frameColor,
			0
		)
		if lens.doubleBridge then
			guiFrame(
				gui,
				"TopBar",
				UDim2.fromScale(sx(gap + lens.stroke * 2), sy(0.018)),
				UDim2.fromScale(0.5, 0.5 - sy(lens.h * 0.42)),
				frameColor,
				0
			)
		end
	end
	-- hinges and temples (arms) back along the sides of the head
	local mat = if lens.metal then METAL else SMOOTH
	local templeX = h.X / 2 + 0.018
	local armY = eyeY + 0.035
	for _, side in { -1, 1 } do
		local hingeW = templeX - plateW / 2 + 0.012
		Fit.box(
			ctx,
			"Head",
			CFrame.new(side * (plateW / 2 + hingeW / 2 - 0.012), armY, plateZ),
			Vector3.new(hingeW, 0.04, 0.03),
			frameColor,
			mat,
			"eyes_Hinge"
		)
		local len = h.Z * 0.62
		Fit.box(
			ctx,
			"Head",
			CFrame.new(side * templeX, armY, plateZ - 0.015 + len / 2),
			Vector3.new(0.025, 0.035, len),
			frameColor,
			mat,
			"eyes_Temple"
		)
	end
end

return {
	watch = { build = watch, covers = {} },
	band = { build = band, covers = {} },
	glasses = { build = glasses, covers = {} },
}
