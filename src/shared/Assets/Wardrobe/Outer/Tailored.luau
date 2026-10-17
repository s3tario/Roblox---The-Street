--!strict
-- Outerwear layer builders (slot "outer"): tailored jackets (two-button, double-breasted, three-piece,
-- dinner), unstructured blazers, overcoats, waistcoats and fleece vests, open overshirts, aprons.
--
-- A tailored jacket is a thin shell around the torso and hips. On its front sits the "V": the shirt (or
-- waistcoat) showing between the lapels, then the lapels themselves (flat triangles raised off the shell)
-- with a notch or a peak, the collar, buttons, pocket square, hip pocket flaps, a hem that drops below the
-- torso with a cutaway over the trousers, structured shoulders and sleeve cuffs with a sliver of shirt
-- cuff. The V is published in ctx.state.vee so ties and scarves can sit inside it. Bake-safe.
--
-- Tailored.luau holds the shared construction; Outer/init.luau defines each garment as a Spec.

local Fit = require(script.Parent.Parent.Fit)

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
	shawl: boolean?, -- rounded shawl collar: no notch or peak, the lapel runs unbroken round the neck
	lapelEdge: Color3?, -- piping along the lapel's roll line (default: a darker shade of the jacket)
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
	-- lapels catch the light: a touch lighter than the body of the jacket so they read at a distance
	local color = spec.lapelColor or Fit.shade(ctx.colors.primary, 0.07)
	local mat = spec.lapelMaterial or FABRIC
	local edge = spec.lapelEdge or Fit.shade(ctx.colors.primary, -0.3)
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
	if spec.shawl then
		-- shawl: no break at the gorge; a rounded roll carries the lapel up round the neck
		Fit.tri(
			ctx,
			"UpperTorso",
			place(Vector3.new(side * (w - 0.06), L + 0.03, -0.002)),
			0.12,
			0.06,
			0.05,
			if side < 0 then "tl" else "tr",
			color,
			mat,
			"outer_ShawlRoll"
		)
	elseif spec.peak then
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
			place(Vector3.new(side * (w - 0.04), L - 0.03, -0.027)),
			0.08,
			0.06,
			0.006,
			if side < 0 then "tl" else "tr",
			Fit.shade(ctx.colors.primary, -0.18),
			FABRIC,
			"outer_Notch"
		)
	end
	-- the lapel's outer edge (roll line) from the gorge down to the button point
	local gorge = place(Vector3.new(side * w + tuck, L, 0)).Position
	local apexPoint = place(Vector3.new(tuck, 0, 0)).Position
	Fit.strip(
		ctx,
		"UpperTorso",
		Vector3.new(gorge.X, gorge.Y, z - 0.027),
		Vector3.new(apexPoint.X, apexPoint.Y + 0.02, z - 0.027),
		0.022,
		0.006,
		edge,
		FABRIC,
		"outer_LapelEdge"
	)
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
		Fit.shade(color, -0.04),
		mat,
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
		for _, x in { -0.84, -0.52, 0.52, 0.84 } do
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
			for _, seg in { "UpperArm" } do
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
	-- the lapel line, for details that sit on a lapel (Details.lapel_pin): front = lapel front face
	ctx.state.lapelV = { width = vW, topY = top, apexY = apexY, lapel = spec.lapel, front = lz - 0.025 }

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
		Fit.tri(
			ctx,
			"UpperTorso",
			CFrame.new(px - 0.06, py + 0.07, zf - 0.012),
			0.12,
			0.1,
			0.02,
			"br",
			spec.pocketSquare,
			SMOOTH,
			"outer_PocketSquare"
		)
		Fit.tri(
			ctx,
			"UpperTorso",
			CFrame.new(px + 0.06, py + 0.07, zf - 0.012),
			0.12,
			0.1,
			0.02,
			"bl",
			spec.pocketSquare,
			SMOOTH,
			"outer_PocketSquare"
		)
	end
	if spec.crest then
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(px, py - 0.12, zf - 0.01),
			Vector3.new(0.36, 0.34, 0.02),
			Fit.shade(col.primary, -0.1),
			FABRIC,
			"outer_CrestPocket"
		)
		Fit.tri(
			ctx,
			"UpperTorso",
			CFrame.new(px - 0.06, py - 0.1, zf - 0.024),
			0.12,
			0.16,
			0.012,
			"tr",
			spec.crest,
			METAL,
			"outer_Crest"
		)
		Fit.tri(
			ctx,
			"UpperTorso",
			CFrame.new(px + 0.06, py - 0.1, zf - 0.024),
			0.12,
			0.16,
			0.012,
			"tl",
			spec.crest,
			METAL,
			"outer_Crest"
		)
		-- the shield's chief (top band) and a coronet bar above it
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(px, py - 0.01, zf - 0.026),
			Vector3.new(0.24, 0.035, 0.012),
			Fit.shade(spec.crest, -0.2),
			METAL,
			"outer_Crest"
		)
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(px, py + 0.03, zf - 0.024),
			Vector3.new(0.14, 0.03, 0.012),
			spec.crest,
			METAL,
			"outer_Crest"
		)
	end
	if spec.badge then
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(px, py - 0.12, zf - 0.012),
			Vector3.new(0.4, 0.36, 0.024),
			Fit.shade(col.primary, -0.12),
			FABRIC,
			"outer_BadgePocket"
		)
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(px, py - 0.02, zf - 0.03),
			Vector3.new(0.28, 0.2, 0.012),
			spec.badge,
			SMOOTH,
			"outer_Badge"
		)
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
			Fit.tri(
				ctx,
				"LowerTorso",
				CFrame.new(-0.09, hemBottom + ch / 2, lzf - 0.008),
				0.18,
				ch,
				0.016,
				"br",
				legs,
				FABRIC,
				"outer_Cutaway"
			)
			Fit.tri(
				ctx,
				"LowerTorso",
				CFrame.new(0.09, hemBottom + ch / 2, lzf - 0.008),
				0.18,
				ch,
				0.016,
				"bl",
				legs,
				FABRIC,
				"outer_Cutaway"
			)
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

return {
	tailored = tailored,
}
