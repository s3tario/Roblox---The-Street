--!strict
-- Untailored outerwear (slot "outer"): waistcoat and fleece vest (sleeveless, the shirt sleeves stay
-- visible), open overshirts (flannel, denim jacket) and the barista's bib apron. Bake-safe.

local Fit = require(script.Parent.Parent.Fit)
local Details = require(script.Parent.Parent.Details)

type Ctx = Fit.Ctx

local rad = math.rad
local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal

local function isTie(item: any): boolean
	return type(item) == "table" and (item.builder == "tie" or item.builder == "bowtie")
end

---------------------------------------------------------------------------------------------------
-- Waistcoat and fleece vest (sleeveless: the shirt sleeves stay visible)
---------------------------------------------------------------------------------------------------
local function vest(ctx: Ctx)
	local s = Fit.size(ctx, "UpperTorso")
	if not s then
		return
	end
	local col = ctx.colors
	local W, H, D = s.X, s.Y, s.Z
	local top = H / 2
	local front = -D / 2
	local shirt = Fit.shirtColor(ctx)
	local tie = isTie(ctx.items.neck)
	Fit.paint(ctx, "UpperTorso", col.primary)
	ctx.state.torsoFront = front
	local fleece = ctx.item.style == "fleece"

	if fleece then
		local vW, apexY = 0.36, top - 0.26
		Fit.vee(ctx, vW, top, apexY, front, shirt, FABRIC, "outer_ShirtV")
		ctx.state.vee = { width = vW, topY = top, apexY = apexY, z = front - 0.02 }
		if ctx.state.topCollar == "point" then
			Fit.collarPoints(ctx, front - 0.02, Fit.shade(shirt, 0.05), not tie, "outer_ShirtCollar")
		end
		for _, sx in { -1, 1 } do
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(sx * 0.36, top - 0.1, front - 0.035) * CFrame.Angles(rad(-6), 0, 0),
				Vector3.new(0.38, 0.2, 0.06),
				Fit.shade(col.primary, 0.04),
				FABRIC,
				"outer_Collar"
			)
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(sx * (W * 0.32), top + 0.06, 0.04),
				Vector3.new(0.14, 0.2, D * 0.74),
				Fit.shade(col.primary, 0.04),
				FABRIC,
				"outer_CollarSide"
			)
		end
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, -0.13, front - 0.008),
			Vector3.new(0.045, H - 0.26, 0.016),
			col.accent,
			METAL,
			"outer_Zip"
		)
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, apexY - 0.06, front - 0.03),
			Vector3.new(0.06, 0.13, 0.025),
			col.accent,
			METAL,
			"outer_ZipPull"
		)
		-- the house logo patch, unless a brand emblem or the company logo (Wardrobe.apply) takes the chest
		if not Details.lists(ctx.item, "emblem_") and ctx.state.logoSlot ~= ctx.slot then
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(-W * 0.27, top - 0.5, front - 0.006),
				Vector3.new(0.16, 0.1, 0.012),
				Fit.shade(col.primary, 0.25),
				FABRIC,
				"outer_Logo"
			)
		end
		local l = Fit.size(ctx, "LowerTorso")
		if l then
			Fit.box(
				ctx,
				"LowerTorso",
				CFrame.new(0, l.Y / 2 - 0.08, 0),
				Vector3.new(l.X + 0.08, 0.16, l.Z + 0.08),
				col.secondary,
				FABRIC,
				"outer_Binding"
			)
		end
		ctx.state.chestFront = front - 0.065
		return
	end

	-- Waistcoat: deep V, five buttons, welt pockets, pointed front hem, lining-coloured back.
	local vW, apexY = W * 0.43, top - H * 0.45
	Fit.vee(ctx, vW, top, apexY, front, shirt, FABRIC, "outer_ShirtV")
	ctx.state.vee = { width = vW, topY = top, apexY = apexY, z = front - 0.02 }
	if ctx.state.topCollar == "point" or ctx.state.topCollar == "round" then
		if not tie then
			Fit.vee(ctx, 0.3, top, top - 0.26, front - 0.02, ctx.skin, SMOOTH, "outer_Neck")
		end
		Fit.collarPoints(
			ctx,
			front - (if tie then 0.02 else 0.04),
			Fit.shade(shirt, 0.05),
			not tie,
			"outer_ShirtCollar"
		)
	end
	-- raised edges along the V
	for _, sx in { -1, 1 } do
		Fit.strip(
			ctx,
			"UpperTorso",
			Vector3.new(sx * (vW / 2 + 0.02), top - 0.01, front - 0.02),
			Vector3.new(sx * 0.02, apexY - 0.02, front - 0.02),
			0.05,
			0.03,
			Fit.shade(col.primary, 0.05),
			FABRIC,
			"outer_Edge"
		)
	end
	for i = 0, 4 do
		local y = apexY - 0.06 - i * 0.13
		if y > -H / 2 + 0.04 then
			Fit.button(ctx, "UpperTorso", 0, y, front, 0.055, col.secondary, "outer_Button")
		end
	end
	for _, p in { Vector2.new(-W * 0.26, -H * 0.2), Vector2.new(W * 0.26, -H * 0.2), Vector2.new(-W * 0.3, H * 0.12) } do
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(p.X, p.Y, front - 0.006),
			Vector3.new(0.3, 0.035, 0.012),
			Fit.shade(col.primary, -0.35),
			FABRIC,
			"outer_Welt"
		)
	end
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, 0, D / 2 + 0.008),
		Vector3.new(W - 0.08, H - 0.06, 0.016),
		col.accent,
		SMOOTH,
		"outer_Back"
	)
	local l = Fit.size(ctx, "LowerTorso")
	if l then
		local h = math.min(0.2, l.Y * 0.5)
		Fit.tri(
			ctx,
			"LowerTorso",
			CFrame.new(-l.X / 4, l.Y / 2 - h / 2, -l.Z / 2 - 0.012),
			l.X / 2,
			h,
			0.024,
			"tr",
			col.primary,
			FABRIC,
			"outer_Point"
		)
		Fit.tri(
			ctx,
			"LowerTorso",
			CFrame.new(l.X / 4, l.Y / 2 - h / 2, -l.Z / 2 - 0.012),
			l.X / 2,
			h,
			0.024,
			"tl",
			col.primary,
			FABRIC,
			"outer_Point"
		)
	end
	ctx.state.chestFront = front - 0.05
end

---------------------------------------------------------------------------------------------------
-- Open overshirt (flannel, denim jacket): worn open over the top
---------------------------------------------------------------------------------------------------
local function overshirt(ctx: Ctx)
	local s = Fit.size(ctx, "UpperTorso")
	if not s then
		return
	end
	local col = ctx.colors
	local W, H, D = s.X, s.Y, s.Z
	local top = H / 2
	local t = 0.04
	local front = -D / 2 - t / 2
	local panelW = W * 0.36
	local denim = ctx.item.style == "denim"
	Fit.paintArms(ctx, col.primary, true)
	-- back, sides, two front panels (the open centre shows the top underneath)
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, 0, D / 2 + t / 2),
		Vector3.new(W + t * 2, H, t),
		col.primary,
		FABRIC,
		"outer_Back"
	)
	for _, sx in { -1, 1 } do
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(sx * (W / 2 + t / 2), 0, 0),
			Vector3.new(t, H, D),
			col.primary,
			FABRIC,
			"outer_Side"
		)
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(sx * (W / 2 - panelW / 2 + t), 0, front),
			Vector3.new(panelW + t * 2, H, t),
			col.primary,
			FABRIC,
			"outer_Front"
		)
		-- placket along the opening
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(sx * (W / 2 - panelW + t + 0.04), 0, front - t / 2 - 0.006),
			Vector3.new(0.09, H, 0.012),
			col.secondary,
			FABRIC,
			"outer_Placket"
		)
		-- collar lying open on the panels
		Fit.tri(
			ctx,
			"UpperTorso",
			CFrame.new(sx * (W / 2 - panelW + 0.2), top - 0.13, front - t / 2 - 0.02)
				* CFrame.Angles(0, 0, rad(sx * 14)),
			0.26,
			0.26,
			0.03,
			if sx < 0 then "tr" else "tl",
			Fit.shade(col.primary, 0.04),
			FABRIC,
			"outer_Collar"
		)
		-- chest pocket
		local pz = front - t / 2 - 0.01
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(sx * W * 0.28, top - 0.55, pz),
			Vector3.new(0.34, 0.34, 0.02),
			Fit.shade(col.primary, -0.05),
			FABRIC,
			"outer_Pocket"
		)
		if denim then
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(sx * W * 0.28, top - 0.4, pz - 0.015),
				Vector3.new(0.38, 0.12, 0.02),
				col.secondary,
				FABRIC,
				"outer_Flap"
			)
			-- yoke seam
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(sx * (W / 2 - panelW / 2), top - 0.28, front - t / 2 - 0.004),
				Vector3.new(panelW, 0.025, 0.008),
				col.accent,
				FABRIC,
				"outer_Stitch"
			)
		end
	end
	for i = 0, 2 do
		Fit.button(
			ctx,
			"UpperTorso",
			-(W / 2 - panelW + t + 0.04),
			top - 0.4 - i * 0.38,
			front - t / 2 - 0.012,
			0.06,
			if denim then Fit.METALS.brass else Fit.shade(col.secondary, 0.3),
			"outer_Button"
		)
	end
	if ctx.item.pattern == "plaid" then
		local band = col.secondary
		for _, y in { top - 0.42, -0.32 } do
			for _, sx in { -1, 1 } do
				Fit.box(
					ctx,
					"UpperTorso",
					CFrame.new(sx * (W / 2 - panelW / 2 + t), y, front - t / 2 - 0.003),
					Vector3.new(panelW, 0.12, 0.006),
					band,
					FABRIC,
					"outer_Plaid"
				)
			end
		end
		for _, sx in { -1, 1 } do
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(sx * (W / 2 - panelW * 0.35), 0, front - t / 2 - 0.004),
				Vector3.new(0.09, H, 0.008),
				Fit.shade(band, 0.12),
				FABRIC,
				"outer_Plaid"
			)
		end
		for _, side in Fit.SIDES do
			for _, seg in { "UpperArm", "LowerArm" } do
				local a = Fit.size(ctx, side .. seg)
				if a then
					Fit.band(ctx, side .. seg, 0, 0.12, 0.008, band, FABRIC, "outer_Plaid")
				end
			end
		end
	end
	-- hip: the shirt tails hang open over the trousers
	local l = Fit.size(ctx, "LowerTorso")
	if l then
		Fit.box(
			ctx,
			"LowerTorso",
			CFrame.new(0, -0.06, 0),
			Vector3.new(l.X + t * 2, l.Y + 0.12, l.Z + t * 2),
			col.primary,
			FABRIC,
			"outer_Tail"
		)
		Fit.box(
			ctx,
			"LowerTorso",
			CFrame.new(0, -0.06, -l.Z / 2 - t - 0.004),
			Vector3.new(W - panelW * 2, l.Y + 0.12, 0.01),
			Fit.legColor(ctx),
			FABRIC,
			"outer_TailGap"
		)
	end
	for _, side in Fit.SIDES do
		local a = Fit.size(ctx, side .. "LowerArm")
		if a then
			Fit.band(ctx, side .. "LowerArm", -a.Y / 2 + 0.08, 0.16, 0.035, col.secondary, FABRIC, "outer_Cuff")
		end
	end
	ctx.state.chestFront = front - t / 2 - 0.03
end

---------------------------------------------------------------------------------------------------
-- Bib apron (barista)
---------------------------------------------------------------------------------------------------
local function apron(ctx: Ctx)
	local s = Fit.size(ctx, "UpperTorso")
	if not s then
		return
	end
	local col = ctx.colors
	local W, H, D = s.X, s.Y, s.Z
	local front = (ctx.state.torsoFront or -D / 2) - 0.02
	local bibTop = H / 2 - 0.3
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, (bibTop - H / 2) / 2, front),
		Vector3.new(W * 0.62, bibTop + H / 2, 0.03),
		col.primary,
		FABRIC,
		"outer_Bib"
	)
	for _, sx in { -1, 1 } do
		Fit.strip(
			ctx,
			"UpperTorso",
			Vector3.new(sx * W * 0.29, bibTop, front),
			Vector3.new(sx * W * 0.2, H / 2 + 0.02, front + 0.01),
			0.07,
			0.025,
			col.secondary,
			FABRIC,
			"outer_Strap"
		)
	end
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, -H * 0.12, front - 0.02),
		Vector3.new(W * 0.4, 0.3, 0.02),
		col.accent,
		FABRIC,
		"outer_Pocket"
	)
	local l = Fit.size(ctx, "LowerTorso")
	if l then
		Fit.band(ctx, "LowerTorso", l.Y / 2 - 0.06, 0.09, 0.04, col.secondary, FABRIC, "outer_Tie")
		local u = Fit.size(ctx, "LeftUpperLeg")
		local drop = if u then u.Y * 0.75 else 0.9
		Fit.box(
			ctx,
			"LowerTorso",
			CFrame.new(0, l.Y / 2 - (l.Y + drop) / 2, -l.Z / 2 - 0.035),
			Vector3.new(W * 0.74, l.Y + drop, 0.03),
			col.primary,
			FABRIC,
			"outer_Skirt"
		)
	end
	ctx.state.chestFront = front - 0.02
end

return {
	vest = vest,
	overshirt = overshirt,
	apron = apron,
}
