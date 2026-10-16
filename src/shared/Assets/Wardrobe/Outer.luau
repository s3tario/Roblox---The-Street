--!strict
-- Outerwear layer builders (slot "outer"): tailored jackets (two-button, double-breasted, three-piece,
-- dinner), unstructured blazers, overcoats, waistcoats and fleece vests, open overshirts, aprons.
--
-- A tailored jacket is a thin shell around the torso and hips. On its front sits the "V": the shirt (or
-- waistcoat) showing between the lapels, then the lapels themselves (flat triangles raised off the shell)
-- with a notch or a peak, the collar, buttons, pocket square, hip pocket flaps, a hem that drops below the
-- torso with a cutaway over the trousers, structured shoulders and sleeve cuffs with a sliver of shirt
-- cuff. The V is published in ctx.state.vee so ties and scarves can sit inside it. Bake-safe.

local Fit = require(script.Parent.Fit)

type Ctx = Fit.Ctx

local rad = math.rad
local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal

local function isTie(item: any): boolean
	return type(item) == "table" and (item.builder == "tie" or item.builder == "bowtie")
end

export type Spec = {
	apex: number, -- V depth as a fraction of the torso height
	vWidth: number, -- V width at the collar as a fraction of the torso width
	lapel: number, -- lapel width (studs)
	lapelColor: Color3?,
	lapelMaterial: Enum.Material?,
	peak: boolean?, -- peak lapels instead of notch
	hem: number, -- how far the jacket drops below the hips
	structured: boolean?, -- shoulder pads
	buttons: string, -- "one" | "two" | "three" | "double"
	buttonColor: Color3,
	pockets: string, -- "flap" | "patch" | "jetted"
	pocketSquare: Color3?,
	waistcoat: Color3?, -- three-piece: waistcoat shows in the V
	cuffButtons: boolean?,
	stripes: Color3?, -- pinstripe colour
	skirts: boolean?, -- overcoat panels over the thighs
	elbows: Color3?, -- elbow patches
	crest: Color3?, -- club crest on the chest
	badge: Color3?, -- trading-floor badge
	epaulettes: Color3?,
}

---------------------------------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------------------------------
-- One lapel: a flat right triangle whose long leg runs along the V edge from the apex up to the collar
-- and whose short leg (the gorge line) points outward. side = -1 (wearer's left) or 1.
local function lapel(ctx: Ctx, side: number, vW: number, top: number, apexY: number, w: number, z: number, spec: Spec)
	local dx, dy = vW / 2, top - apexY
	local L = math.sqrt(dx * dx + dy * dy)
	local theta = math.atan2(dx, dy)
	local rot = CFrame.Angles(0, 0, if side < 0 then theta else -theta)
	local function place(local2: Vector3): CFrame
		local p = rot * local2
		return CFrame.new(p.X, apexY + p.Y, z + p.Z) * rot
	end
	local color = spec.lapelColor or ctx.colors.primary
	local mat = spec.lapelMaterial or FABRIC
	-- tuck 0.02 over the V edge so no seam shows
	local tuck = -side * 0.02
	Fit.tri(
		ctx,
		"UpperTorso",
		place(Vector3.new(side * w / 2 + tuck, L / 2, 0)),
		w,
		L,
		0.05,
		if side < 0 then "tr" else "tl",
		color,
		mat,
		"outer_Lapel"
	)
	if spec.peak then
		-- peak: a point rising from the outer end of the gorge line
		Fit.tri(
			ctx,
			"UpperTorso",
			place(Vector3.new(side * (w - 0.08), L + 0.065, -0.004)),
			0.16,
			0.13,
			0.05,
			if side < 0 then "bl" else "br",
			color,
			mat,
			"outer_Peak"
		)
	else
		-- notch: a small shadowed cut where the collar meets the lapel
		Fit.tri(
			ctx,
			"UpperTorso",
			place(Vector3.new(side * (w - 0.055), L - 0.045, -0.03)),
			0.11,
			0.09,
			0.012,
			if side < 0 then "tl" else "tr",
			Fit.shade(ctx.colors.primary, -0.45),
			FABRIC,
			"outer_Notch"
		)
	end
	-- upper collar along the gorge, from the neck to just short of the notch
	local a = Vector3.new(side * (dx - 0.02), top - 0.02, z - 0.012)
	local outer = place(Vector3.new(side * w * 0.62, L, 0)).Position
	Fit.strip(
		ctx,
		"UpperTorso",
		a,
		Vector3.new(outer.X, outer.Y + 0.035, z - 0.012),
		0.09,
		0.04,
		Fit.shade(ctx.colors.primary, -0.03),
		FABRIC,
		"outer_Collar"
	)
end

local function buttons(ctx: Ctx, spec: Spec, apexY: number, z: number, bottomY: number)
	local list: { Vector2 } = {}
	if spec.buttons == "one" then
		list = { Vector2.new(0, apexY - 0.06) }
	elseif spec.buttons == "two" then
		list = { Vector2.new(0, apexY - 0.07), Vector2.new(0, apexY - 0.37) }
	elseif spec.buttons == "three" then
		list = { Vector2.new(0, apexY - 0.07), Vector2.new(0, apexY - 0.33), Vector2.new(0, apexY - 0.59) }
	elseif spec.buttons == "double" then
		for row = 0, 2 do
			local y = apexY - 0.07 - row * 0.24
			table.insert(list, Vector2.new(-0.24, y))
			table.insert(list, Vector2.new(0.24, y))
		end
	end
	for _, b in list do
		if b.Y > bottomY + 0.04 then
			Fit.button(ctx, "UpperTorso", b.X, b.Y, z, 0.075, spec.buttonColor, "outer_Button")
		end
	end
end

local function cuffsAndShoulders(ctx: Ctx, spec: Spec)
	local shirt = Fit.shirtColor(ctx)
	local cuffColor = Fit.shade(ctx.colors.primary, -0.05)
	for i, side in Fit.SIDES do
		local sx = if i == 1 then -1 else 1
		local lower = side .. "LowerArm"
		local s = Fit.size(ctx, lower)
		if s then
			local bottom = -s.Y / 2
			Fit.band(ctx, lower, bottom + 0.035, 0.07, 0.025, shirt, FABRIC, "outer_ShirtCuff")
			Fit.band(ctx, lower, bottom + 0.07 + 0.08, 0.16, 0.045, cuffColor, FABRIC, "outer_Cuff")
			if spec.cuffButtons then
				Fit.cyl(
					ctx,
					lower,
					CFrame.new(sx * (s.X / 2 + 0.05), bottom + 0.15, s.Z * 0.22),
					0.02,
					0.065,
					spec.buttonColor,
					SMOOTH,
					"outer_CuffButton"
				)
			end
			if spec.elbows then
				Fit.box(
					ctx,
					lower,
					CFrame.new(0, s.Y / 2 - 0.2, s.Z / 2 + 0.015),
					Vector3.new(s.X * 0.62, 0.36, 0.03),
					spec.elbows,
					FABRIC,
					"outer_Elbow"
				)
			end
		end
		local upper = side .. "UpperArm"
		local u = Fit.size(ctx, upper)
		if u and spec.structured then
			Fit.box(
				ctx,
				upper,
				CFrame.new(0, u.Y / 2 - 0.05, 0),
				Vector3.new(u.X + Fit.SHELL * 2, 0.12, u.Z + Fit.SHELL * 2),
				ctx.colors.primary,
				FABRIC,
				"outer_Shoulder"
			)
		end
		if u and spec.epaulettes then
			Fit.box(
				ctx,
				upper,
				CFrame.new(0, u.Y / 2 + 0.02, 0),
				Vector3.new(u.X * 0.45, 0.05, u.Z + 0.1),
				spec.epaulettes,
				METAL,
				"outer_Epaulette"
			)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Tailored garment (jackets, blazers, overcoats)
---------------------------------------------------------------------------------------------------
local function tailored(ctx: Ctx, spec: Spec)
	local s = Fit.size(ctx, "UpperTorso")
	if not s then
		return
	end
	local col = ctx.colors
	local W, H, D = s.X, s.Y, s.Z
	local top, bottom = H / 2, -H / 2
	local SH = Fit.SHELL
	local zf = -D / 2 - SH -- front of the shell

	Fit.paint(ctx, "UpperTorso", col.primary)
	Fit.paintArms(ctx, col.primary, true)
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, 0.005, 0),
		Vector3.new(W + SH * 2, H + 0.01, D + SH * 2),
		col.primary,
		FABRIC,
		"outer_Shell"
	)
	ctx.state.torsoFront = zf
	ctx.state.torsoBack = D / 2 + SH

	if spec.stripes then
		for _, x in { -0.84, -0.56, -0.28, 0.28, 0.56, 0.84 } do
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(x * W / 2, 0, zf - 0.004),
				Vector3.new(0.022, H, 0.008),
				spec.stripes,
				FABRIC,
				"outer_Stripe"
			)
		end
		for _, side in Fit.SIDES do
			for _, seg in { "UpperArm", "LowerArm" } do
				local a = Fit.size(ctx, side .. seg)
				if a then
					Fit.box(
						ctx,
						side .. seg,
						CFrame.new(0, 0, -a.Z / 2 - 0.004),
						Vector3.new(0.022, a.Y, 0.008),
						spec.stripes,
						FABRIC,
						"outer_Stripe"
					)
				end
			end
		end
	end

	-- The V: shirt (or waistcoat, then shirt) between the lapels.
	local vW = W * spec.vWidth
	local apexY = top - H * spec.apex
	local shirt = Fit.shirtColor(ctx)
	local tie = isTie(ctx.items.neck)
	local vee: { [string]: number }
	if spec.waistcoat then
		Fit.vee(ctx, vW, top, apexY, zf, spec.waistcoat, FABRIC, "outer_Waistcoat")
		local innerApex = top - H * 0.3
		local innerW = vW * 0.62
		Fit.vee(ctx, innerW, top, innerApex, zf - 0.02, shirt, FABRIC, "outer_ShirtV")
		for i = 0, 2 do
			Fit.button(
				ctx,
				"UpperTorso",
				0,
				innerApex - 0.07 - i * 0.12,
				zf - 0.02,
				0.05,
				Fit.shade(spec.waistcoat, -0.3),
				"outer_WaistcoatButton"
			)
		end
		vee = { width = innerW, topY = top, apexY = innerApex, z = zf - 0.04 }
	else
		Fit.vee(ctx, vW, top, apexY, zf, shirt, FABRIC, "outer_ShirtV")
		vee = { width = vW, topY = top, apexY = apexY, z = zf - 0.02 }
	end
	ctx.state.vee = vee

	-- Shirt collar inside the V (open neck when there's no tie).
	local collarType = ctx.state.topCollar
	if collarType == "point" or collarType == "round" or collarType == nil then
		if not tie then
			Fit.vee(ctx, 0.3, top, top - 0.26, vee.z, ctx.skin, SMOOTH, "outer_Neck")
		end
		Fit.collarPoints(ctx, vee.z - (if tie then 0 else 0.02), Fit.shade(shirt, 0.05), not tie, "outer_ShirtCollar")
	elseif collarType == "scoop" or collarType == "crew" then
		Fit.vee(ctx, 0.28, top, top - 0.18, vee.z, ctx.skin, SMOOTH, "outer_Neck")
	end

	-- Lapels, collar, notch or peak.
	local lz = zf - 0.045
	lapel(ctx, -1, vW, top, apexY, spec.lapel, lz, spec)
	lapel(ctx, 1, vW, top, apexY, spec.lapel, lz, spec)
	ctx.state.chestFront = zf - 0.075

	buttons(ctx, spec, apexY, zf, bottom)

	-- Pocket square (wearer's left breast) or crest/badge.
	local px, py = -W * 0.31, top - H * 0.3
	if spec.pocketSquare then
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(px, py, zf - 0.008),
			Vector3.new(0.34, 0.04, 0.016),
			Fit.shade(col.primary, -0.3),
			FABRIC,
			"outer_Welt"
		)
		Fit.tri(ctx, "UpperTorso", CFrame.new(px - 0.06, py + 0.07, zf - 0.012), 0.12, 0.1, 0.02, "br", spec.pocketSquare, SMOOTH, "outer_PocketSquare")
		Fit.tri(ctx, "UpperTorso", CFrame.new(px + 0.06, py + 0.07, zf - 0.012), 0.12, 0.1, 0.02, "bl", spec.pocketSquare, SMOOTH, "outer_PocketSquare")
	end
	if spec.crest then
		Fit.box(ctx, "UpperTorso", CFrame.new(px, py - 0.12, zf - 0.01), Vector3.new(0.36, 0.34, 0.02), Fit.shade(col.primary, -0.1), FABRIC, "outer_CrestPocket")
		Fit.tri(ctx, "UpperTorso", CFrame.new(px - 0.06, py - 0.1, zf - 0.024), 0.12, 0.16, 0.012, "tr", spec.crest, METAL, "outer_Crest")
		Fit.tri(ctx, "UpperTorso", CFrame.new(px + 0.06, py - 0.1, zf - 0.024), 0.12, 0.16, 0.012, "tl", spec.crest, METAL, "outer_Crest")
	end
	if spec.badge then
		Fit.box(ctx, "UpperTorso", CFrame.new(px, py - 0.12, zf - 0.012), Vector3.new(0.4, 0.36, 0.024), Fit.shade(col.primary, -0.12), FABRIC, "outer_BadgePocket")
		Fit.box(ctx, "UpperTorso", CFrame.new(px, py - 0.02, zf - 0.03), Vector3.new(0.28, 0.2, 0.012), spec.badge, SMOOTH, "outer_Badge")
	end

	-- Hips: shell over the lower torso with a hem dropping below it.
	local l = Fit.size(ctx, "LowerTorso")
	if l then
		local hem = spec.hem
		local lzf = -l.Z / 2 - SH
		Fit.box(
			ctx,
			"LowerTorso",
			CFrame.new(0, -hem / 2 + 0.005, 0),
			Vector3.new(l.X + SH * 2, l.Y + hem + 0.01, l.Z + SH * 2),
			col.primary,
			FABRIC,
			"outer_Hem"
		)
		local hemBottom = -l.Y / 2 - hem
		-- cutaway: the quarters open over the trousers below the last button
		if not spec.skirts then
			local legs = Fit.legColor(ctx)
			local ch = math.min(0.2, hem + l.Y * 0.5)
			Fit.tri(ctx, "LowerTorso", CFrame.new(-0.09, hemBottom + ch / 2, lzf - 0.008), 0.18, ch, 0.016, "br", legs, FABRIC, "outer_Cutaway")
			Fit.tri(ctx, "LowerTorso", CFrame.new(0.09, hemBottom + ch / 2, lzf - 0.008), 0.18, ch, 0.016, "bl", legs, FABRIC, "outer_Cutaway")
		end
		-- hip pockets
		for _, sx in { -1, 1 } do
			if spec.pockets == "patch" then
				Fit.box(
					ctx,
					"LowerTorso",
					CFrame.new(sx * l.X * 0.28, -hem / 2 + 0.02, lzf - 0.012),
					Vector3.new(0.52, math.min(0.4, l.Y + hem - 0.08), 0.024),
					Fit.shade(col.primary, -0.06),
					FABRIC,
					"outer_PatchPocket"
				)
			elseif spec.pockets == "jetted" then
				Fit.box(
					ctx,
					"LowerTorso",
					CFrame.new(sx * l.X * 0.28, l.Y / 2 - 0.12, lzf - 0.006),
					Vector3.new(0.46, 0.03, 0.012),
					Fit.shade(col.primary, -0.4),
					FABRIC,
					"outer_Jet"
				)
			else
				Fit.box(
					ctx,
					"LowerTorso",
					CFrame.new(sx * l.X * 0.28, l.Y / 2 - 0.12, lzf - 0.014) * CFrame.Angles(rad(-6), 0, 0),
					Vector3.new(0.5, 0.1, 0.028),
					Fit.shade(col.primary, -0.04),
					FABRIC,
					"outer_Flap"
				)
			end
		end
		-- centre back vent
		Fit.box(
			ctx,
			"LowerTorso",
			CFrame.new(0, -hem / 2, l.Z / 2 + SH + 0.004),
			Vector3.new(0.025, l.Y + hem - 0.04, 0.008),
			Fit.shade(col.primary, -0.4),
			FABRIC,
			"outer_Vent"
		)
	end

	-- Overcoat skirts hang from the hips over each thigh (they swing with the legs).
	if spec.skirts then
		for _, side in Fit.SIDES do
			local name = side .. "UpperLeg"
			local u = Fit.size(ctx, name)
			if u then
				local h = u.Y * 0.82
				Fit.box(
					ctx,
					name,
					CFrame.new(0, u.Y / 2 - h / 2, 0),
					Vector3.new(u.X + SH * 2 + 0.02, h, u.Z + SH * 2 + 0.02),
					col.primary,
					FABRIC,
					"outer_Skirt"
				)
			end
		end
	end

	cuffsAndShoulders(ctx, spec)
end

---------------------------------------------------------------------------------------------------
-- Jackets
---------------------------------------------------------------------------------------------------
local function buttonColorFor(primary: Color3): Color3
	return Fit.shade(primary, -0.45)
end

local function jacket(ctx: Ctx)
	local col = ctx.colors
	local style = ctx.item.style or "two_button"
	local spec: Spec = {
		apex = 0.62,
		vWidth = 0.46,
		lapel = 0.22,
		hem = 0.3,
		structured = true,
		buttons = "two",
		buttonColor = buttonColorFor(col.primary),
		pockets = "flap",
		pocketSquare = col.accent,
		cuffButtons = true,
		stripes = if ctx.item.pattern == "pinstripe" then Color3.fromRGB(196, 198, 204) else nil,
	}
	if style == "double_breasted" then
		spec.apex = 0.5
		spec.lapel = 0.26
		spec.peak = true
		spec.buttons = "double"
	elseif style == "three_piece" then
		spec.apex = 0.6
		spec.waistcoat = Fit.shade(col.primary, -0.08)
	elseif style == "dinner" then
		spec.apex = 0.72
		spec.lapel = 0.24
		spec.peak = true
		spec.buttons = "one"
		spec.lapelColor = col.secondary
		spec.lapelMaterial = SMOOTH
		spec.buttonColor = col.secondary
		spec.pockets = "jetted"
	end
	tailored(ctx, spec)
end

local function blazer(ctx: Ctx)
	local col = ctx.colors
	local style = ctx.item.style
	local spec: Spec = {
		apex = 0.62,
		vWidth = 0.46,
		lapel = 0.2,
		hem = 0.24,
		structured = false,
		buttons = "two",
		buttonColor = Fit.shade(col.accent, -0.15),
		pockets = "patch",
		cuffButtons = false,
	}
	if style == "elbow" then
		spec.elbows = col.accent
		spec.buttonColor = Fit.shade(col.primary, -0.4)
	elseif style == "club" then
		spec.buttonColor = col.accent
		spec.crest = col.accent
		spec.cuffButtons = true
		spec.structured = true
		spec.pockets = "flap"
	elseif style == "trader" then
		spec.badge = col.accent
		spec.buttons = "three"
		spec.apex = 0.4
		spec.lapel = 0.16
		spec.buttonColor = Fit.shade(col.primary, -0.4)
	end
	tailored(ctx, spec)
end

local function overcoat(ctx: Ctx)
	local col = ctx.colors
	local style = ctx.item.style
	local spec: Spec = {
		apex = 0.5,
		vWidth = 0.5,
		lapel = 0.28,
		hem = 0.0,
		structured = true,
		buttons = "three",
		buttonColor = Fit.shade(col.primary, -0.45),
		pockets = "flap",
		skirts = true,
		cuffButtons = true,
	}
	if style == "doorman" then
		spec.buttons = "double"
		spec.buttonColor = col.accent
		spec.epaulettes = col.accent
		spec.peak = true
		spec.apex = 0.4
	elseif style == "chesterfield" then
		spec.lapelColor = Fit.shade(col.primary, -0.05)
		spec.buttonColor = col.accent
	end
	tailored(ctx, spec)
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
		Fit.box(ctx, "UpperTorso", CFrame.new(0, apexY - 0.06, front - 0.03), Vector3.new(0.06, 0.13, 0.025), col.accent, METAL, "outer_ZipPull")
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(-W * 0.27, top - 0.5, front - 0.006),
			Vector3.new(0.16, 0.1, 0.012),
			Fit.shade(col.primary, 0.25),
			FABRIC,
			"outer_Logo"
		)
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
		Fit.collarPoints(ctx, front - (if tie then 0.02 else 0.04), Fit.shade(shirt, 0.05), not tie, "outer_ShirtCollar")
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
		Fit.tri(ctx, "LowerTorso", CFrame.new(-l.X / 4, l.Y / 2 - h / 2, -l.Z / 2 - 0.012), l.X / 2, h, 0.024, "tr", col.primary, FABRIC, "outer_Point")
		Fit.tri(ctx, "LowerTorso", CFrame.new(l.X / 4, l.Y / 2 - h / 2, -l.Z / 2 - 0.012), l.X / 2, h, 0.024, "tl", col.primary, FABRIC, "outer_Point")
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
	Fit.box(ctx, "UpperTorso", CFrame.new(0, 0, D / 2 + t / 2), Vector3.new(W + t * 2, H, t), col.primary, FABRIC, "outer_Back")
	for _, sx in { -1, 1 } do
		Fit.box(ctx, "UpperTorso", CFrame.new(sx * (W / 2 + t / 2), 0, 0), Vector3.new(t, H, D), col.primary, FABRIC, "outer_Side")
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
			CFrame.new(sx * (W / 2 - panelW + 0.2), top - 0.13, front - t / 2 - 0.02) * CFrame.Angles(0, 0, rad(sx * 14)),
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
		Fit.box(ctx, "UpperTorso", CFrame.new(sx * W * 0.28, top - 0.55, pz), Vector3.new(0.34, 0.34, 0.02), Fit.shade(col.primary, -0.05), FABRIC, "outer_Pocket")
		if denim then
			Fit.box(ctx, "UpperTorso", CFrame.new(sx * W * 0.28, top - 0.4, pz - 0.015), Vector3.new(0.38, 0.12, 0.02), col.secondary, FABRIC, "outer_Flap")
			-- yoke seam
			Fit.box(ctx, "UpperTorso", CFrame.new(sx * (W / 2 - panelW / 2), top - 0.28, front - t / 2 - 0.004), Vector3.new(panelW, 0.025, 0.008), col.accent, FABRIC, "outer_Stitch")
		end
	end
	for i = 0, 2 do
		Fit.button(ctx, "UpperTorso", -(W / 2 - panelW + t + 0.04), top - 0.4 - i * 0.38, front - t / 2 - 0.012, 0.06, if denim then Fit.METALS.brass else Fit.shade(col.secondary, 0.3), "outer_Button")
	end
	if ctx.item.pattern == "plaid" then
		local band = col.secondary
		for _, y in { top - 0.42, -0.32 } do
			for _, sx in { -1, 1 } do
				Fit.box(ctx, "UpperTorso", CFrame.new(sx * (W / 2 - panelW / 2 + t), y, front - t / 2 - 0.003), Vector3.new(panelW, 0.12, 0.006), band, FABRIC, "outer_Plaid")
			end
		end
		for _, sx in { -1, 1 } do
			Fit.box(ctx, "UpperTorso", CFrame.new(sx * (W / 2 - panelW * 0.35), 0, front - t / 2 - 0.004), Vector3.new(0.09, H, 0.008), Fit.shade(band, 0.12), FABRIC, "outer_Plaid")
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
		Fit.box(ctx, "LowerTorso", CFrame.new(0, -0.06, 0), Vector3.new(l.X + t * 2, l.Y + 0.12, l.Z + t * 2), col.primary, FABRIC, "outer_Tail")
		Fit.box(ctx, "LowerTorso", CFrame.new(0, -0.06, -l.Z / 2 - t - 0.004), Vector3.new(W - panelW * 2, l.Y + 0.12, 0.01), Fit.legColor(ctx), FABRIC, "outer_TailGap")
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
	Fit.box(ctx, "UpperTorso", CFrame.new(0, (bibTop - H / 2) / 2, front), Vector3.new(W * 0.62, bibTop + H / 2, 0.03), col.primary, FABRIC, "outer_Bib")
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
	Fit.box(ctx, "UpperTorso", CFrame.new(0, -H * 0.12, front - 0.02), Vector3.new(W * 0.4, 0.3, 0.02), col.accent, FABRIC, "outer_Pocket")
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
	jacket = { build = jacket, covers = { torso = true, arms = true, waist = true } },
	blazer = { build = blazer, covers = { torso = true, arms = true, waist = true } },
	overcoat = { build = overcoat, covers = { torso = true, arms = true, waist = true, thighs = true } },
	vest = {
		build = vest,
		covers = function(item: any): { [string]: boolean }
			if item.style == "fleece" then
				return { torso = true, waist = true }
			end
			return { torso = true }
		end,
	},
	overshirt = { build = overshirt, covers = { arms = true, waist = true } },
	apron = { build = apron, covers = {} },
}
