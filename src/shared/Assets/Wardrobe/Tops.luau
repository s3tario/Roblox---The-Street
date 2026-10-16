--!strict
-- Top layer builders (slot "top"): dress shirt, tee, polo, blouse, shell, quarter-zip, sweater, hoodie.
-- Tops paint the torso and sleeves, then add front details (collar, placket, buttons, pockets) only where
-- no jacket covers them. They record the collar type in ctx.state.topCollar so outerwear can draw the
-- matching collar inside its V. Bake-safe.

local Fit = require(script.Parent.Fit)

type Ctx = Fit.Ctx

local rad = math.rad
local SMOOTH = Enum.Material.SmoothPlastic
local FABRIC = Enum.Material.Fabric

local function isTie(item: any): boolean
	return type(item) == "table" and (item.builder == "tie" or item.builder == "bowtie")
end

-- Shared: torso dimensions and the starting front depth.
local function torso(ctx: Ctx): (number, number, number, number, number)
	local s = Fit.size(ctx, "UpperTorso") :: Vector3
	local front = -s.Z / 2
	ctx.state.torsoFront = front
	ctx.state.torsoBack = s.Z / 2
	return s.X, s.Y, s.Z, s.Y / 2, front
end

local function cuffs(ctx: Ctx, color: Color3, height: number, pad: number)
	if Fit.covered(ctx, "arms") then
		return
	end
	for _, side in Fit.SIDES do
		local s = Fit.size(ctx, side .. "LowerArm")
		if s then
			Fit.band(ctx, side .. "LowerArm", -s.Y / 2 + height / 2, height, pad, color, FABRIC, "top_Cuff")
		end
	end
end

local function sleeveHems(ctx: Ctx, color: Color3)
	if Fit.covered(ctx, "arms") then
		return
	end
	for _, side in Fit.SIDES do
		local s = Fit.size(ctx, side .. "UpperArm")
		if s then
			Fit.band(ctx, side .. "UpperArm", -s.Y / 2 + 0.06, 0.11, 0.025, color, FABRIC, "top_SleeveHem")
		end
	end
end

-- Ribbed hem over the waistband (sweaters, hoodies, quarter-zips stop at the hips).
local function hipHem(ctx: Ctx, color: Color3)
	local s = Fit.size(ctx, "LowerTorso")
	if not s or Fit.covered(ctx, "waist") then
		return
	end
	Fit.box(
		ctx,
		"LowerTorso",
		CFrame.new(0, s.Y / 2 - 0.085, 0),
		Vector3.new(s.X + 0.07, 0.17, s.Z + 0.07),
		color,
		FABRIC,
		"top_Hem"
	)
end

---------------------------------------------------------------------------------------------------
-- Dress shirt (oxford, bengal stripe)
---------------------------------------------------------------------------------------------------
local function shirt(ctx: Ctx)
	local W, H, _D, top, front = torso(ctx)
	local col = ctx.colors
	Fit.paint(ctx, "UpperTorso", col.primary)
	Fit.paintArms(ctx, col.primary, true)
	ctx.state.topCollar = "point"
	local tie = isTie(ctx.items.neck)

	if not Fit.covered(ctx, "torso") then
		if not tie then
			-- open neck: a little skin V under spread collar points
			Fit.vee(ctx, 0.34, top, top - 0.3, front, ctx.skin, SMOOTH, "top_Neck")
		end
		local collarZ = if tie then front else front - 0.02
		Fit.collarPoints(ctx, collarZ, Fit.shade(col.primary, 0.05), not tie, "top_Collar")
		-- placket and buttons
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, -0.08, front - 0.006),
			Vector3.new(0.12, H - 0.36, 0.012),
			col.secondary,
			FABRIC,
			"top_Placket"
		)
		local buttonColor = Fit.shade(col.accent, -0.05)
		for i = 0, 3 do
			local y = top - 0.42 - i * 0.3
			if not tie or i > 0 then
				Fit.button(ctx, "UpperTorso", 0, y, front - 0.012, 0.055, buttonColor, "top_Button")
			end
		end
		-- chest pocket (wearer's left)
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(-W * 0.27, top - 0.52, front - 0.008),
			Vector3.new(0.34, 0.36, 0.014),
			Fit.shade(col.primary, -0.06),
			FABRIC,
			"top_Pocket"
		)
		if ctx.item.pattern == "stripe" then
			for _, x in { -0.82, -0.6, -0.34, 0.34, 0.6, 0.82 } do
				Fit.box(
					ctx,
					"UpperTorso",
					CFrame.new(x * W / 2, 0, front - 0.004),
					Vector3.new(0.035, H - 0.02, 0.008),
					col.accent,
					FABRIC,
					"top_Stripe"
				)
			end
		end
	end
	if ctx.item.pattern == "stripe" and not Fit.covered(ctx, "arms") then
		for _, side in Fit.SIDES do
			for _, seg in { "UpperArm", "LowerArm" } do
				local s = Fit.size(ctx, side .. seg)
				if s then
					Fit.box(
						ctx,
						side .. seg,
						CFrame.new(0, 0, -s.Z / 2 - 0.004),
						Vector3.new(0.035, s.Y - 0.02, 0.008),
						col.accent,
						FABRIC,
						"top_Stripe"
					)
				end
			end
		end
	end
	cuffs(ctx, Fit.shade(col.primary, -0.04), 0.14, 0.025)
end

---------------------------------------------------------------------------------------------------
-- Crew tee
---------------------------------------------------------------------------------------------------
local function tee(ctx: Ctx)
	local W, _H, _D, top, front = torso(ctx)
	local col = ctx.colors
	Fit.paint(ctx, "UpperTorso", col.primary)
	Fit.paintArms(ctx, col.primary, false)
	for _, side in Fit.SIDES do
		Fit.bare(ctx, side .. "LowerArm")
	end
	ctx.state.topCollar = "crew"
	if not Fit.covered(ctx, "torso") then
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, top - 0.04, front - 0.008),
			Vector3.new(0.66, 0.08, 0.016),
			col.secondary,
			FABRIC,
			"top_Rib"
		)
		if ctx.item.style == "pocket" then
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(-W * 0.27, top - 0.5, front - 0.008),
				Vector3.new(0.32, 0.34, 0.014),
				col.secondary,
				FABRIC,
				"top_Pocket"
			)
		end
	end
	sleeveHems(ctx, col.secondary)
end

---------------------------------------------------------------------------------------------------
-- Pique polo
---------------------------------------------------------------------------------------------------
local function polo(ctx: Ctx)
	local W, _H, _D, top, front = torso(ctx)
	local col = ctx.colors
	Fit.paint(ctx, "UpperTorso", col.primary)
	Fit.paintArms(ctx, col.primary, false)
	for _, side in Fit.SIDES do
		Fit.bare(ctx, side .. "LowerArm")
	end
	ctx.state.topCollar = "point"
	if not Fit.covered(ctx, "torso") then
		Fit.vee(ctx, 0.2, top, top - 0.2, front, ctx.skin, SMOOTH, "top_Neck")
		Fit.collarPoints(ctx, front - 0.02, Fit.shade(col.primary, 0.04), true, "top_Collar")
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, top - 0.42, front - 0.007),
			Vector3.new(0.13, 0.42, 0.014),
			col.secondary,
			FABRIC,
			"top_Placket"
		)
		for i = 0, 1 do
			Fit.button(ctx, "UpperTorso", 0, top - 0.36 - i * 0.16, front - 0.014, 0.05, Color3.fromRGB(240, 240, 236))
		end
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(-W * 0.27, top - 0.42, front - 0.006),
			Vector3.new(0.12, 0.1, 0.012),
			col.accent,
			SMOOTH,
			"top_Logo"
		)
	end
	sleeveHems(ctx, col.secondary)
end

---------------------------------------------------------------------------------------------------
-- Silk blouse (rounded collar, pearl buttons, gathered cuffs)
---------------------------------------------------------------------------------------------------
local function blouse(ctx: Ctx)
	local _W, _H, _D, top, front = torso(ctx)
	local col = ctx.colors
	Fit.paint(ctx, "UpperTorso", col.primary, SMOOTH)
	Fit.paintArms(ctx, col.primary, true, SMOOTH)
	ctx.state.topCollar = "round"
	if not Fit.covered(ctx, "torso") then
		Fit.vee(ctx, 0.3, top, top - 0.26, front, ctx.skin, SMOOTH, "top_Neck")
		for _, sx in { -1, 1 } do
			Fit.cyl(
				ctx,
				"UpperTorso",
				CFrame.new(sx * 0.2, top - 0.12, front - 0.03) * CFrame.Angles(rad(90), 0, 0),
				0.03,
				0.32,
				col.accent,
				SMOOTH,
				"top_Collar"
			)
		end
		local pearl = Color3.fromRGB(246, 242, 232)
		for i = 0, 3 do
			Fit.ball(
				ctx,
				"UpperTorso",
				CFrame.new(0, top - 0.42 - i * 0.28, front - 0.02),
				0.07,
				pearl,
				SMOOTH,
				"top_Pearl"
			)
		end
	end
	cuffs(ctx, col.secondary, 0.16, 0.04)
end

---------------------------------------------------------------------------------------------------
-- Sleeveless shell top (scoop neck)
---------------------------------------------------------------------------------------------------
local function shell(ctx: Ctx)
	local W, H, _D, top, front = torso(ctx)
	local col = ctx.colors
	Fit.paint(ctx, "UpperTorso", col.primary, SMOOTH)
	for _, side in Fit.SIDES do
		Fit.bare(ctx, side .. "UpperArm")
		Fit.bare(ctx, side .. "LowerArm")
	end
	ctx.state.topCollar = "scoop"
	if not Fit.covered(ctx, "torso") then
		-- the lower half of a skin disc on the chest reads as a scoop neckline
		Fit.cyl(
			ctx,
			"UpperTorso",
			CFrame.new(0, top, front - 0.006) * CFrame.Angles(rad(90), 0, 0),
			0.012,
			0.66,
			ctx.skin,
			SMOOTH,
			"top_Neck"
		)
		for _, sx in { -1, 1 } do
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(sx * W * 0.2, -H * 0.22, front - 0.004),
				Vector3.new(0.025, H * 0.4, 0.008),
				col.secondary,
				SMOOTH,
				"top_Dart"
			)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Quarter-zip (stand collar, zipper and pull)
---------------------------------------------------------------------------------------------------
local function quarterzip(ctx: Ctx)
	local W, _H, D, top, front = torso(ctx)
	local col = ctx.colors
	Fit.paint(ctx, "UpperTorso", col.primary)
	Fit.paintArms(ctx, col.primary, true)
	ctx.state.topCollar = "stand"
	local metal = col.accent
	if not Fit.covered(ctx, "torso") then
		-- the half-open zip shows the inner fabric in a small V
		Fit.vee(ctx, 0.18, top, top - 0.2, front, col.secondary, FABRIC, "top_ZipV")
		for _, sx in { -1, 1 } do
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(sx * 0.29, top - 0.09, front - 0.03) * CFrame.Angles(rad(-8), 0, rad(sx * 4)),
				Vector3.new(0.4, 0.2, 0.05),
				Fit.shade(col.primary, 0.03),
				FABRIC,
				"top_Collar"
			)
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(sx * (W * 0.32), top + 0.06, 0.05),
				Vector3.new(0.14, 0.18, D * 0.72),
				Fit.shade(col.primary, 0.03),
				FABRIC,
				"top_CollarSide"
			)
		end
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, top - 0.38, front - 0.008),
			Vector3.new(0.045, 0.36, 0.016),
			metal,
			Enum.Material.Metal,
			"top_Zip"
		)
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, top - 0.25, front - 0.03),
			Vector3.new(0.06, 0.13, 0.025),
			metal,
			Enum.Material.Metal,
			"top_ZipPull"
		)
	end
	cuffs(ctx, col.secondary, 0.13, 0.03)
	hipHem(ctx, col.secondary)
end

---------------------------------------------------------------------------------------------------
-- Knit sweater (crew or V-neck over a collar)
---------------------------------------------------------------------------------------------------
local function sweater(ctx: Ctx)
	local W, H, _D, top, front = torso(ctx)
	local col = ctx.colors
	Fit.paint(ctx, "UpperTorso", col.primary)
	Fit.paintArms(ctx, col.primary, true)
	local vneck = ctx.item.style == "vneck"
	ctx.state.topCollar = if vneck then "point" else "crew"
	if not Fit.covered(ctx, "torso") then
		if vneck then
			Fit.vee(ctx, 0.62, top, top - 0.62, front, col.secondary, FABRIC, "top_ShirtV")
			Fit.collarPoints(ctx, front - 0.02, col.secondary, true, "top_Collar")
		else
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(0, top - 0.045, front - 0.012),
				Vector3.new(0.7, 0.09, 0.024),
				col.secondary,
				FABRIC,
				"top_Rib"
			)
			-- cable-knit ribs
			for _, sx in { -1, 1 } do
				Fit.box(
					ctx,
					"UpperTorso",
					CFrame.new(sx * W * 0.2, -0.05, front - 0.006),
					Vector3.new(0.09, H - 0.3, 0.012),
					Fit.shade(col.primary, 0.07),
					FABRIC,
					"top_Cable"
				)
			end
		end
	end
	cuffs(ctx, col.secondary, 0.12, 0.03)
	hipHem(ctx, col.secondary)
end

---------------------------------------------------------------------------------------------------
-- Hoodie (hood bunched at the neck, drawstrings, kangaroo pocket)
---------------------------------------------------------------------------------------------------
local function hoodie(ctx: Ctx)
	local W, H, D, top, front = torso(ctx)
	local col = ctx.colors
	Fit.paint(ctx, "UpperTorso", col.primary)
	Fit.paintArms(ctx, col.primary, true)
	ctx.state.topCollar = "hood"
	local hood = Fit.shade(col.primary, -0.04)
	-- hood: a thick roll behind the neck and two side rolls running forward to the neckline
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, top + 0.1, D / 2 + 0.02) * CFrame.Angles(rad(-10), 0, 0),
		Vector3.new(W * 0.76, 0.36, 0.5),
		hood,
		FABRIC,
		"top_Hood"
	)
	for _, sx in { -1, 1 } do
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(sx * W * 0.33, top + 0.06, 0.02),
			Vector3.new(0.22, 0.26, D * 0.92),
			hood,
			FABRIC,
			"top_HoodSide"
		)
	end
	if not Fit.covered(ctx, "torso") then
		Fit.vee(ctx, 0.5, top, top - 0.24, front, hood, FABRIC, "top_HoodFront")
		for _, sx in { -1, 1 } do
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(sx * 0.17, top - 0.47, front - 0.035),
				Vector3.new(0.045, 0.5, 0.03),
				col.accent,
				SMOOTH,
				"top_Drawstring"
			)
		end
		-- kangaroo pocket with slanted openings
		local py = -H / 2 + H * 0.2
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, py, front - 0.012),
			Vector3.new(W * 0.62, H * 0.3, 0.024),
			Fit.shade(col.primary, -0.07),
			FABRIC,
			"top_Pocket"
		)
		for _, sx in { -1, 1 } do
			Fit.strip(
				ctx,
				"UpperTorso",
				Vector3.new(sx * W * 0.31, py + H * 0.13, front - 0.03),
				Vector3.new(sx * W * 0.2, py - H * 0.13, front - 0.03),
				0.035,
				0.012,
				Fit.shade(col.primary, -0.3),
				FABRIC,
				"top_PocketEdge"
			)
		end
		if ctx.item.style == "college" then
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(0, top - 0.62, front - 0.005),
				Vector3.new(W * 0.98, 0.09, 0.01),
				col.accent,
				FABRIC,
				"top_Stripe"
			)
		end
	end
	cuffs(ctx, col.secondary, 0.14, 0.035)
	hipHem(ctx, col.secondary)
end

return {
	shirt = { build = shirt, covers = {} },
	tee = { build = tee, covers = {} },
	polo = { build = polo, covers = {} },
	blouse = { build = blouse, covers = {} },
	shell = { build = shell, covers = {} },
	quarterzip = { build = quarterzip, covers = { waist = true } },
	sweater = { build = sweater, covers = { waist = true } },
	hoodie = { build = hoodie, covers = { waist = true, neck = true } },
}
