--!strict
-- Neckwear layer builders (slot "neck"): ties (solid, regimental stripe, square-end knit, satin, with a
-- gold tie bar), bow ties, scarves, ID lanyards with a badge, and the tailor's measuring tape.
-- A tie sits inside the jacket or waistcoat V when one is worn (ctx.state.vee, published by the outer
-- builder) and ends at the V's apex where the buttoned jacket covers it; otherwise it runs down the shirt
-- front to the belt with a pointed tip. Bake-safe.

local Fit = require(script.Parent.Fit)

type Ctx = Fit.Ctx

local rad = math.rad
local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal
local PLASTIC = Enum.Material.Plastic

local function torso(ctx: Ctx): (Vector3?, number, number)
	local s = Fit.size(ctx, "UpperTorso")
	if not s then
		return nil, 0, 0
	end
	return s, s.Y / 2, -s.Z / 2
end

---------------------------------------------------------------------------------------------------
-- Tie
---------------------------------------------------------------------------------------------------
local function tie(ctx: Ctx)
	local s, top, front = torso(ctx)
	if not s then
		return
	end
	local col = ctx.colors
	local style = ctx.item.style
	local knit = style == "knit"
	local mat = if style == "satin" or style == "bar" then SMOOTH else FABRIC
	local vee = ctx.state.vee
	local z: number
	local bottomY: number
	local tipped: boolean
	if vee then
		-- between the shirt V and the lapels; the buttoned jacket hides everything below the apex
		z = vee.z - 0.012
		bottomY = vee.apexY + 0.01
		tipped = false
	else
		-- clear of the shirt buttons, down to the belt
		z = front - 0.052
		bottomY = -s.Y / 2 + 0.1
		tipped = not knit
	end
	local thick = 0.022
	local knotH, knotW = 0.15, if knit then 0.15 else 0.18
	local knotY = top - 0.075
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, knotY, z - 0.008),
		Vector3.new(knotW, knotH, thick + 0.012),
		Fit.shade(col.primary, -0.06),
		mat,
		"neck_Knot"
	)
	-- blade: a narrow centre panel that widens toward the bottom (two side triangles)
	local bladeTop = knotY - knotH / 2 + 0.01
	local tipH = if tipped then 0.13 else 0
	local bladeBottom = bottomY + tipH
	local len = bladeTop - bladeBottom
	if len < 0.06 then
		return
	end
	local narrow = if knit then 0.14 else 0.12
	local wide = if knit then 0.15 else 0.21
	local midY = (bladeTop + bladeBottom) / 2
	local blade = Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, midY, z),
		Vector3.new(narrow, len, thick),
		col.primary,
		mat,
		"neck_Tie"
	)
	if blade and style == "satin" then
		blade.Reflectance = 0.12
	end
	local flare = (wide - narrow) / 2
	if flare > 0.004 then
		for _, sx in { -1, 1 } do
			Fit.tri(
				ctx,
				"UpperTorso",
				CFrame.new(sx * (narrow / 2 + flare / 2), midY, z),
				flare,
				len,
				thick,
				if sx < 0 then "br" else "bl",
				col.primary,
				mat,
				"neck_TieSide"
			)
		end
	end
	if tipped then
		-- the pointed tip: two triangles meeting at the centre line
		for _, sx in { -1, 1 } do
			Fit.tri(
				ctx,
				"UpperTorso",
				CFrame.new(sx * wide / 4, bottomY + tipH / 2, z),
				wide / 2,
				tipH,
				thick,
				if sx < 0 then "tr" else "tl",
				col.primary,
				mat,
				"neck_TieTip"
			)
		end
	end
	-- patterns sit just in front of the blade
	local pz = z - thick / 2 - 0.004
	if ctx.item.pattern == "stripe" then
		local step = math.max(0.17, len / 5)
		local y = bladeTop - 0.08
		while y > bladeBottom + 0.04 do
			local t = (bladeTop - y) / len
			local w = narrow + (wide - narrow) * t
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(0, y, pz) * CFrame.Angles(0, 0, rad(-35)),
				Vector3.new(w * 0.92, 0.035, 0.008),
				col.accent,
				mat,
				"neck_Stripe"
			)
			y -= step
		end
	elseif knit then
		-- knit ridges
		local y = bladeTop - 0.07
		while y > bladeBottom + 0.03 do
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(0, y, pz),
				Vector3.new(narrow - 0.01, 0.018, 0.006),
				col.secondary,
				FABRIC,
				"neck_Rib"
			)
			y -= math.max(0.11, len / 5)
		end
	else
		-- a soft sheen line down the centre
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, midY, pz),
			Vector3.new(0.025, len - 0.04, 0.006),
			Fit.shade(col.primary, 0.12),
			mat,
			"neck_Sheen"
		)
	end
	if style == "bar" then
		local barY = math.max(bladeBottom + 0.05, top - 0.55)
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, barY, pz - 0.006),
			Vector3.new(wide + 0.04, 0.03, 0.014),
			col.accent,
			METAL,
			"neck_TieBar"
		)
	end
end

---------------------------------------------------------------------------------------------------
-- Bow tie
---------------------------------------------------------------------------------------------------
local function bowtie(ctx: Ctx)
	local s, top, front = torso(ctx)
	if not s then
		return
	end
	local col = ctx.colors
	local vee = ctx.state.vee
	local z = if vee then vee.z - 0.02 else front - 0.045
	local y = top - 0.08
	for _, sx in { -1, 1 } do
		-- each wing: a block that flares out from the knot, slightly tilted
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(sx * 0.13, y, z) * CFrame.Angles(0, 0, rad(sx * 7)),
			Vector3.new(0.2, 0.14, 0.035),
			col.primary,
			SMOOTH,
			"neck_Bow"
		)
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(sx * 0.15, y, z - 0.019) * CFrame.Angles(0, 0, rad(sx * 7)),
			Vector3.new(0.12, 0.025, 0.006),
			col.accent,
			SMOOTH,
			"neck_BowFold"
		)
	end
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, y, z - 0.012),
		Vector3.new(0.07, 0.1, 0.05),
		col.secondary,
		SMOOTH,
		"neck_BowKnot"
	)
end

---------------------------------------------------------------------------------------------------
-- Scarf (wrapped round the neck, tails down the front)
---------------------------------------------------------------------------------------------------
local function scarf(ctx: Ctx)
	local s, top = torso(ctx)
	if not s then
		return
	end
	local col = ctx.colors
	local head = Fit.size(ctx, "Head") or Vector3.new(1.2, 1.2, 1.2)
	local hx, hz = math.max(head.X, s.X * 0.5) / 2, math.max(head.Z, s.Z) / 2
	local t, h = 0.16, 0.26
	local y = top + 0.07
	local wrapColor = Fit.shade(col.primary, -0.03)
	-- the wrap: four blocks around the base of the head
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, y, -hz - t / 2 + 0.04),
		Vector3.new(hx * 2 + t * 2 - 0.04, h, t),
		wrapColor,
		FABRIC,
		"neck_Wrap"
	)
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, y, hz + t / 2 - 0.04),
		Vector3.new(hx * 2 + t * 2 - 0.04, h, t),
		wrapColor,
		FABRIC,
		"neck_Wrap"
	)
	for _, sx in { -1, 1 } do
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(sx * (hx + t / 2 - 0.04), y, 0),
			Vector3.new(t, h, hz * 2 - 0.02),
			wrapColor,
			FABRIC,
			"neck_Wrap"
		)
	end
	-- two tails hanging down the front, one longer than the other
	local z = Fit.chestFront(ctx) - 0.035
	local tails = { { x = -0.3, len = s.Y * 0.62, tilt = 4 }, { x = -0.08, len = s.Y * 0.44, tilt = -3 } }
	for i, tail in tails do
		local tz = z - (i - 1) * 0.03
		local ty = top - tail.len / 2 + 0.02
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(tail.x, ty, tz) * CFrame.Angles(0, 0, rad(tail.tilt)),
			Vector3.new(0.27, tail.len, 0.05),
			col.primary,
			FABRIC,
			"neck_Tail"
		)
		-- fringe at the end
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(tail.x, top - tail.len - 0.02, tz) * CFrame.Angles(0, 0, rad(tail.tilt)),
			Vector3.new(0.25, 0.07, 0.03),
			col.accent,
			FABRIC,
			"neck_Fringe"
		)
		if ctx.item.pattern == "stripe" then
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(tail.x, top - tail.len + 0.08 + 0.12, tz - 0.027) * CFrame.Angles(0, 0, rad(tail.tilt)),
				Vector3.new(0.27, 0.045, 0.006),
				col.accent,
				FABRIC,
				"neck_Stripe"
			)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- ID lanyard with a badge (students and interns)
---------------------------------------------------------------------------------------------------
local function badgeGui(card: BasePart, text: string, header: Color3, ink: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Badge"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 200
	gui.LightInfluence = 1
	gui.Parent = card
	local band = Instance.new("Frame")
	band.Name = "Header"
	band.BorderSizePixel = 0
	band.BackgroundColor3 = header
	band.Size = UDim2.fromScale(1, 0.3)
	band.Parent = gui
	local label = Instance.new("TextLabel")
	label.Name = "Role"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	label.Parent = band
	local photo = Instance.new("Frame")
	photo.Name = "Photo"
	photo.BorderSizePixel = 0
	photo.BackgroundColor3 = Fit.shade(header, 0.55)
	photo.Size = UDim2.fromScale(0.42, 0.32)
	photo.Position = UDim2.fromScale(0.29, 0.36)
	photo.Parent = gui
	for i = 0, 1 do
		local line = Instance.new("Frame")
		line.Name = "Line"
		line.BorderSizePixel = 0
		line.BackgroundColor3 = ink
		line.Size = UDim2.fromScale(if i == 0 then 0.7 else 0.5, 0.05)
		line.Position = UDim2.fromScale(if i == 0 then 0.15 else 0.25, 0.75 + i * 0.1)
		line.Parent = gui
	end
end

local function lanyard(ctx: Ctx)
	local s, top = torso(ctx)
	if not s then
		return
	end
	local col = ctx.colors
	local z = Fit.chestFront(ctx) - 0.025
	local clipY = top - s.Y * 0.4
	-- the cord: down from either side of the neck to the clip
	for _, sx in { -1, 1 } do
		Fit.strip(
			ctx,
			"UpperTorso",
			Vector3.new(sx * 0.32, top + 0.01, z),
			Vector3.new(sx * 0.03, clipY, z),
			0.055,
			0.016,
			col.primary,
			FABRIC,
			"neck_Cord"
		)
	end
	-- round the back of the neck (the head hides the cord over the shoulders)
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, top - 0.03, Fit.backZ(ctx) + 0.012),
		Vector3.new(0.7, 0.055, 0.016),
		col.primary,
		FABRIC,
		"neck_Cord"
	)
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, clipY - 0.04, z - 0.01),
		Vector3.new(0.08, 0.1, 0.03),
		Fit.METALS.steel,
		METAL,
		"neck_Clip"
	)
	local cardH, cardW = 0.46, 0.34
	local card = Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, clipY - 0.09 - cardH / 2, z - 0.012),
		Vector3.new(cardW, cardH, 0.02),
		col.secondary,
		PLASTIC,
		"neck_Badge"
	)
	if card then
		badgeGui(card, ctx.item.text or "ID", col.accent, Fit.shade(col.secondary, -0.55))
	end
end

---------------------------------------------------------------------------------------------------
-- Tailor's measuring tape (draped round the neck)
---------------------------------------------------------------------------------------------------
local function tape(ctx: Ctx)
	local s, top = torso(ctx)
	if not s then
		return
	end
	local col = ctx.colors
	local z = Fit.chestFront(ctx) - 0.02
	local len = s.Y * 0.62
	for i, sx in { -1, 1 } do
		local l = if i == 1 then len else len * 0.82
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(sx * 0.4, top - l / 2 + 0.01, z),
			Vector3.new(0.1, l, 0.012),
			col.primary,
			SMOOTH,
			"neck_Tape"
		)
		for k = 1, 4 do
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(sx * 0.4 - 0.025, top - k * l / 5, z - 0.008),
				Vector3.new(0.045, 0.012, 0.004),
				col.accent,
				SMOOTH,
				"neck_Tick"
			)
		end
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(sx * 0.4, top - l, z - 0.004),
			Vector3.new(0.11, 0.04, 0.02),
			col.secondary,
			METAL,
			"neck_TapeEnd"
		)
	end
	-- the loop behind the neck
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, top - 0.04, Fit.backZ(ctx) + 0.01),
		Vector3.new(0.9, 0.1, 0.012),
		col.primary,
		SMOOTH,
		"neck_Tape"
	)
end

return {
	tie = { build = tie, covers = {} },
	bowtie = { build = bowtie, covers = {} },
	scarf = { build = scarf, covers = { neck = true } },
	lanyard = { build = lanyard, covers = {} },
	tape = { build = tape, covers = {} },
}
