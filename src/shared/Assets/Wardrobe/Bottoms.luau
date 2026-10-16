--!strict
-- Bottom layer builders (slot "bottom"): tailored trousers (suit, wide-leg, evening), chinos, jeans,
-- cargo pants, pencil and A-line skirts. Trousers paint the hips and legs, then add a belt and buckle
-- (hidden under jackets and sweaters), a pressed crease, turn-ups or a break, and fabric details.
-- Skirts paint the hips and thighs (so the moving legs read as fabric) and add a shell over the hips
-- and upper legs. Bake-safe.

local Fit = require(script.Parent.Fit)

type Ctx = Fit.Ctx

local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic
local LEATHER = Enum.Material.Leather
local METAL = Enum.Material.Metal

local function belt(ctx: Ctx, strap: Color3, buckle: Color3, height: number?)
	local l = Fit.size(ctx, "LowerTorso")
	if not l or Fit.covered(ctx, "waist") then
		return
	end
	local h = height or 0.12
	local y = l.Y / 2 - h / 2 - 0.01
	Fit.band(ctx, "LowerTorso", y, h, 0.03, strap, LEATHER, "bottom_Belt")
	Fit.box(
		ctx,
		"LowerTorso",
		CFrame.new(0, y, -l.Z / 2 - 0.045),
		Vector3.new(0.2, h + 0.01, 0.035),
		buckle,
		METAL,
		"bottom_Buckle"
	)
end

local function each(ctx: Ctx, segment: string, fn: (name: string, size: Vector3, sx: number) -> ())
	for i, side in Fit.SIDES do
		local name = side .. segment
		local s = Fit.size(ctx, name)
		if s then
			fn(name, s, if i == 1 then -1 else 1)
		end
	end
end

local function crease(ctx: Ctx, color: Color3)
	for _, seg in { "UpperLeg", "LowerLeg" } do
		if seg == "UpperLeg" and Fit.covered(ctx, "thighs") then
			continue
		end
		each(ctx, seg, function(name, s)
			Fit.box(
				ctx,
				name,
				CFrame.new(0, 0, -s.Z / 2 - 0.006),
				Vector3.new(0.03, s.Y - 0.04, 0.012),
				color,
				FABRIC,
				"bottom_Crease"
			)
		end)
	end
end

local function turnUps(ctx: Ctx, color: Color3, height: number, pad: number)
	each(ctx, "LowerLeg", function(name, s)
		Fit.band(ctx, name, -s.Y / 2 + height / 2, height, pad, color, FABRIC, "bottom_Cuff")
	end)
end

---------------------------------------------------------------------------------------------------
-- Tailored trousers (suit / plain / wide-leg / evening)
---------------------------------------------------------------------------------------------------
local function trousers(ctx: Ctx)
	local col = ctx.colors
	local style = ctx.item.style
	Fit.paint(ctx, "LowerTorso", col.primary)
	Fit.paintLegs(ctx, col.primary, true)
	if style ~= "evening" then
		belt(ctx, col.secondary, col.accent)
	end
	if style ~= "plain" then
		crease(ctx, Fit.shade(col.primary, 0.12))
	end
	if style == "wide" then
		-- the leg flares out below the knee
		each(ctx, "LowerLeg", function(name, s)
			local h = s.Y * 0.8
			Fit.box(
				ctx,
				name,
				CFrame.new(0, -s.Y / 2 + h / 2, 0),
				Vector3.new(s.X + 0.12, h, s.Z + 0.12),
				col.primary,
				FABRIC,
				"bottom_Flare"
			)
		end)
	elseif style == "evening" then
		for _, seg in { "UpperLeg", "LowerLeg" } do
			each(ctx, seg, function(name, s, sx)
				Fit.box(
					ctx,
					name,
					CFrame.new(sx * (s.X / 2 + 0.006), 0, 0),
					Vector3.new(0.012, s.Y, 0.09),
					col.secondary,
					SMOOTH,
					"bottom_Satin"
				)
			end)
		end
	else
		turnUps(ctx, Fit.shade(col.primary, -0.06), 0.12, 0.025)
	end
	if ctx.item.pattern == "pinstripe" then
		local stripe = Color3.fromRGB(196, 198, 204)
		for _, seg in { "UpperLeg", "LowerLeg" } do
			if seg == "UpperLeg" and Fit.covered(ctx, "thighs") then
				continue
			end
			each(ctx, seg, function(name, s)
				for _, x in { -0.27, 0.27 } do
					Fit.box(
						ctx,
						name,
						CFrame.new(x * s.X, 0, -s.Z / 2 - 0.004),
						Vector3.new(0.02, s.Y, 0.008),
						stripe,
						FABRIC,
						"bottom_Stripe"
					)
				end
			end)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Chinos (slanted pockets, turn-ups)
---------------------------------------------------------------------------------------------------
local function chinos(ctx: Ctx)
	local col = ctx.colors
	Fit.paint(ctx, "LowerTorso", col.primary)
	Fit.paintLegs(ctx, col.primary, true)
	belt(ctx, col.secondary, col.accent)
	if not Fit.covered(ctx, "thighs") then
		each(ctx, "UpperLeg", function(name, s, sx)
			Fit.strip(
				ctx,
				name,
				Vector3.new(sx * s.X * 0.1, s.Y / 2 - 0.02, -s.Z / 2 - 0.008),
				Vector3.new(sx * s.X * 0.46, s.Y / 2 - 0.34, -s.Z / 2 - 0.008),
				0.03,
				0.012,
				Fit.shade(col.primary, -0.3),
				FABRIC,
				"bottom_Pocket"
			)
		end)
	end
	turnUps(ctx, Fit.shade(col.primary, 0.06), 0.14, 0.03)
end

---------------------------------------------------------------------------------------------------
-- Jeans (copper stitching, back pockets, rolled cuffs)
---------------------------------------------------------------------------------------------------
local function jeans(ctx: Ctx)
	local col = ctx.colors
	local stitch = col.accent
	Fit.paint(ctx, "LowerTorso", col.primary)
	Fit.paintLegs(ctx, col.primary, true)
	belt(ctx, col.secondary, Fit.METALS.brass)
	local l = Fit.size(ctx, "LowerTorso")
	if l and not Fit.covered(ctx, "waist") then
		Fit.box(
			ctx,
			"LowerTorso",
			CFrame.new(0.1, -0.06, -l.Z / 2 - 0.005),
			Vector3.new(0.025, l.Y * 0.6, 0.01),
			stitch,
			FABRIC,
			"bottom_Fly"
		)
	end
	if not Fit.covered(ctx, "thighs") then
		each(ctx, "UpperLeg", function(name, s, sx)
			Fit.strip(
				ctx,
				name,
				Vector3.new(sx * s.X * 0.08, s.Y / 2 - 0.02, -s.Z / 2 - 0.006),
				Vector3.new(sx * s.X * 0.46, s.Y / 2 - 0.28, -s.Z / 2 - 0.006),
				0.025,
				0.01,
				stitch,
				FABRIC,
				"bottom_Stitch"
			)
			Fit.box(
				ctx,
				name,
				CFrame.new(0, s.Y / 2 - 0.26, s.Z / 2 + 0.01),
				Vector3.new(s.X * 0.56, 0.36, 0.02),
				Fit.shade(col.primary, -0.06),
				FABRIC,
				"bottom_BackPocket"
			)
		end)
	end
	turnUps(ctx, Fit.shade(col.primary, 0.28), 0.14, 0.035)
end

---------------------------------------------------------------------------------------------------
-- Cargo pants (side pockets with flaps, web belt)
---------------------------------------------------------------------------------------------------
local function cargo(ctx: Ctx)
	local col = ctx.colors
	Fit.paint(ctx, "LowerTorso", col.primary)
	Fit.paintLegs(ctx, col.primary, true)
	belt(ctx, col.secondary, col.accent, 0.1)
	if not Fit.covered(ctx, "thighs") then
		each(ctx, "UpperLeg", function(name, s, sx)
			Fit.box(
				ctx,
				name,
				CFrame.new(sx * (s.X / 2 + 0.03), -0.12, 0),
				Vector3.new(0.06, 0.46, s.Z * 0.56),
				Fit.shade(col.primary, -0.05),
				FABRIC,
				"bottom_CargoPocket"
			)
			Fit.box(
				ctx,
				name,
				CFrame.new(sx * (s.X / 2 + 0.065), 0.13, 0),
				Vector3.new(0.05, 0.11, s.Z * 0.6),
				Fit.shade(col.primary, 0.05),
				FABRIC,
				"bottom_CargoFlap"
			)
		end)
	end
	turnUps(ctx, Fit.shade(col.primary, -0.08), 0.1, 0.02)
end

---------------------------------------------------------------------------------------------------
-- Skirts
---------------------------------------------------------------------------------------------------
local function skirtBase(ctx: Ctx): (Vector3?, Vector3?)
	local col = ctx.colors
	Fit.paint(ctx, "LowerTorso", col.primary)
	Fit.paintLegs(ctx, col.primary, false)
	each(ctx, "LowerLeg", function(name)
		Fit.bare(ctx, name)
	end)
	return Fit.size(ctx, "LowerTorso"), Fit.size(ctx, "LeftUpperLeg")
end

local function waistband(ctx: Ctx, l: Vector3)
	Fit.box(
		ctx,
		"LowerTorso",
		CFrame.new(0, l.Y / 2 - 0.05, 0),
		Vector3.new(l.X + 0.13, 0.1, l.Z + 0.13),
		ctx.colors.secondary,
		FABRIC,
		"bottom_Waistband"
	)
end

local function pencil_skirt(ctx: Ctx)
	local l, u = skirtBase(ctx)
	if not l then
		return
	end
	local drop = if u then u.Y * 0.86 else 1
	local h = l.Y + drop
	Fit.box(
		ctx,
		"LowerTorso",
		CFrame.new(0, l.Y / 2 - h / 2, 0),
		Vector3.new(l.X + 0.1, h, l.Z + 0.1),
		ctx.colors.primary,
		FABRIC,
		"bottom_Skirt"
	)
	waistband(ctx, l)
	Fit.box(
		ctx,
		"LowerTorso",
		CFrame.new(0, l.Y / 2 - h + 0.18, l.Z / 2 + 0.055),
		Vector3.new(0.03, 0.34, 0.012),
		ctx.colors.accent,
		FABRIC,
		"bottom_Vent"
	)
end

local function aline_skirt(ctx: Ctx)
	local l, u = skirtBase(ctx)
	if not l then
		return
	end
	local col = ctx.colors
	local drop = if u then u.Y * 0.72 else 0.85
	local h = l.Y + drop
	local w, d = l.X + 0.1, l.Z + 0.1
	local bottomY = l.Y / 2 - h
	Fit.box(ctx, "LowerTorso", CFrame.new(0, l.Y / 2 - h / 2, 0), Vector3.new(w, h, d), col.primary, FABRIC, "bottom_Skirt")
	waistband(ctx, l)
	-- flare: four wedges whose sloped faces open outward toward the hem
	local fh = drop * 0.8
	local flare = 0.18
	local y = bottomY + fh / 2
	Fit.wedge(ctx, "LowerTorso", CFrame.new(0, y, -d / 2 - flare / 2), Vector3.new(w, fh, flare), col.primary, FABRIC, "bottom_Flare")
	Fit.wedge(
		ctx,
		"LowerTorso",
		CFrame.new(0, y, d / 2 + flare / 2) * CFrame.Angles(0, math.rad(180), 0),
		Vector3.new(w, fh, flare),
		col.primary,
		FABRIC,
		"bottom_Flare"
	)
	Fit.wedge(
		ctx,
		"LowerTorso",
		CFrame.new(w / 2 + flare / 2, y, 0) * CFrame.Angles(0, math.rad(-90), 0),
		Vector3.new(d, fh, flare),
		col.primary,
		FABRIC,
		"bottom_Flare"
	)
	Fit.wedge(
		ctx,
		"LowerTorso",
		CFrame.new(-w / 2 - flare / 2, y, 0) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(d, fh, flare),
		col.primary,
		FABRIC,
		"bottom_Flare"
	)
end

return {
	trousers = { build = trousers, covers = {} },
	chinos = { build = chinos, covers = {} },
	jeans = { build = jeans, covers = {} },
	cargo = { build = cargo, covers = {} },
	pencil_skirt = { build = pencil_skirt, covers = { thighs = true } },
	aline_skirt = { build = aline_skirt, covers = { thighs = true } },
}
