--!strict
-- Shoe layer builders (slot "shoes"): oxfords (cap-toe, derby, wholecut), loafers (penny, horsebit, tassel,
-- boat shoe), sneakers (leather court, canvas) and heels (block heel, pump). item.finish "suede" or "patent"
-- changes the upper's surface. Each shoe paints the foot in the upper
-- colour, then adds a sole band at the bottom of the foot, a toe box that runs past the front of the foot
-- (a wedge sloping down to the tip), a heel and the style details on the top of the foot. Nothing goes
-- below the foot, so shoes never sink a character into the floor. Bake-safe.

local Fit = require(script.Parent.Fit)

type Ctx = Fit.Ctx

local rad = math.rad
local LEATHER = Enum.Material.Leather
local SMOOTH = Enum.Material.SmoothPlastic
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal

type Foot = { name: string, s: Vector3, sx: number }

local function feet(ctx: Ctx): { Foot }
	local out: { Foot } = {}
	for i, side in Fit.SIDES do
		local name = side .. "Foot"
		local s = Fit.size(ctx, name)
		if s then
			table.insert(out, { name = name, s = s, sx = if i == 1 then -1 else 1 })
		end
	end
	return out
end

export type ShoeSpec = {
	upper: Color3,
	upperMaterial: Enum.Material,
	sole: Color3,
	soleHeight: number,
	toeLength: number,
	toeHeight: number, -- fraction of the foot height
	toeWidth: number, -- extra width of the toe box (negative = narrower, pointed shoes)
	heel: Color3?,
	heelHeight: number,
	shine: number?, -- reflectance on the toe box (polished leather)
}

-- Sole, toe box and heel shared by every shoe. Returns the toe part's top-front reference (y, z).
local function base(ctx: Ctx, f: Foot, spec: ShoeSpec): (number, number)
	local s = f.s
	local bottom = -s.Y / 2
	-- item finish overrides the leather: suede is matte nap, patent a mirror shine
	local finish = ctx.item.finish
	if finish == "suede" then
		spec.upperMaterial = FABRIC
		spec.shine = nil
	elseif finish == "patent" then
		spec.upperMaterial = SMOOTH
		spec.shine = 0.28
	end
	Fit.paint(ctx, f.name, spec.upper, spec.upperMaterial)
	-- sole: a band at the bottom of the foot, running slightly past the toe and heel
	local soleLen = s.Z + spec.toeLength + 0.04
	Fit.box(
		ctx,
		f.name,
		CFrame.new(0, bottom + spec.soleHeight / 2, -(spec.toeLength - 0.04) / 2),
		Vector3.new(s.X + 0.05, spec.soleHeight, soleLen),
		spec.sole,
		SMOOTH,
		"shoes_Sole"
	)
	-- toe box: tall where it meets the foot, sloping down to the tip
	local th = math.max(0.06, s.Y * spec.toeHeight)
	local toeZ = -s.Z / 2 - spec.toeLength / 2 + 0.01
	local toe = Fit.wedge(
		ctx,
		f.name,
		CFrame.new(0, bottom + spec.soleHeight + th / 2 - 0.005, toeZ),
		Vector3.new(s.X + spec.toeWidth, th, spec.toeLength + 0.02),
		spec.upper,
		spec.upperMaterial,
		"shoes_Toe"
	)
	if toe and spec.shine then
		toe.Reflectance = spec.shine
		toe.Material = SMOOTH
	end
	-- heel block at the back of the sole
	if spec.heel and spec.heelHeight > 0 then
		Fit.box(
			ctx,
			f.name,
			CFrame.new(0, bottom + spec.heelHeight / 2, s.Z / 2 - 0.13),
			Vector3.new(s.X + 0.055, spec.heelHeight, 0.28),
			spec.heel,
			SMOOTH,
			"shoes_Heel"
		)
	end
	return bottom + spec.soleHeight + th, toeZ
end

-- Thin strip lying on the top surface of the foot.
local function topStrip(
	ctx: Ctx,
	f: Foot,
	x: number,
	z: number,
	w: number,
	d: number,
	color: Color3,
	mat: Enum.Material?
)
	Fit.box(
		ctx,
		f.name,
		CFrame.new(x, f.s.Y / 2 + 0.006, z),
		Vector3.new(w, 0.014, d),
		color,
		mat or LEATHER,
		"shoes_Detail"
	)
end

local function laces(ctx: Ctx, f: Foot, facing: Color3, lace: Color3, open: boolean)
	local s = f.s
	-- facing (the eyelet panels) then two lace bars across it
	topStrip(ctx, f, 0, s.Z * 0.08, if open then s.X * 0.46 else s.X * 0.3, s.Z * 0.36, facing)
	for i = 0, 1 do
		Fit.box(
			ctx,
			f.name,
			CFrame.new(0, s.Y / 2 + 0.016, s.Z * 0.08 - s.Z * 0.08 + i * s.Z * 0.16),
			Vector3.new(if open then s.X * 0.4 else s.X * 0.26, 0.012, 0.035),
			lace,
			FABRIC,
			"shoes_Lace"
		)
	end
end

---------------------------------------------------------------------------------------------------
-- Oxford / derby / wholecut
---------------------------------------------------------------------------------------------------
local function oxford(ctx: Ctx)
	local col = ctx.colors
	local style = ctx.item.style
	local wholecut = style == "wholecut"
	for _, f in feet(ctx) do
		base(ctx, f, {
			upper = col.primary,
			upperMaterial = if wholecut then SMOOTH else LEATHER,
			sole = col.secondary,
			soleHeight = 0.06,
			toeLength = 0.2,
			toeHeight = 0.72,
			toeWidth = -0.02,
			heel = col.secondary,
			heelHeight = 0.1,
			shine = if wholecut then 0.18 else 0.06,
		})
		local s = f.s
		if style == "derby" then
			laces(ctx, f, Fit.shade(col.primary, 0.08), col.accent, true)
		elseif wholecut then
			laces(ctx, f, col.primary, Fit.shade(col.primary, 0.15), false)
		else
			laces(ctx, f, Fit.shade(col.primary, -0.12), col.accent, false)
			-- cap-toe seam across the vamp
			topStrip(ctx, f, 0, -s.Z * 0.3, s.X + 0.012, 0.035, Fit.shade(col.primary, -0.35))
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Loafers (penny strap or horsebit, moc-toe seam)
---------------------------------------------------------------------------------------------------
local function loafer(ctx: Ctx)
	local col = ctx.colors
	local style = ctx.item.style
	local bit = style == "bit"
	local boat = style == "boat"
	local tassel = style == "tassel"
	for _, f in feet(ctx) do
		base(ctx, f, {
			upper = col.primary,
			upperMaterial = LEATHER,
			sole = col.secondary,
			soleHeight = if boat then 0.07 else 0.05,
			toeLength = 0.18,
			toeHeight = 0.7,
			toeWidth = 0,
			heel = col.secondary,
			heelHeight = 0.08,
			shine = 0.08,
		})
		local s = f.s
		local seam = Fit.shade(col.primary, -0.3)
		-- moc-toe apron seam across the front of the vamp
		topStrip(ctx, f, 0, -s.Z * 0.36, s.X * 0.66, 0.03, seam)
		if boat then
			-- rawhide lace threaded round the collar, tied in a bow over the two eyelets
			Fit.band(ctx, f.name, s.Y / 2 - 0.025, 0.03, 0.018, col.accent, LEATHER, "shoes_CollarLace")
			laces(ctx, f, Fit.shade(col.primary, 0.06), col.accent, true)
		elseif tassel then
			-- thin strap with a pair of tassels on the vamp
			topStrip(ctx, f, 0, s.Z * 0.04, s.X + 0.02, 0.05, Fit.shade(col.primary, -0.12))
			for _, sx in { -1, 1 } do
				Fit.ball(
					ctx,
					f.name,
					CFrame.new(sx * s.X * 0.12, s.Y / 2 + 0.03, -s.Z * 0.06),
					0.075,
					col.accent,
					FABRIC,
					"shoes_Tassel"
				)
			end
		elseif bit then
			-- gold horsebit across the instep
			Fit.box(
				ctx,
				f.name,
				CFrame.new(0, s.Y / 2 + 0.02, s.Z * 0.06),
				Vector3.new(s.X * 0.64, 0.035, 0.06),
				col.accent,
				METAL,
				"shoes_Bit"
			)
		else
			-- penny strap with its slot
			topStrip(ctx, f, 0, s.Z * 0.05, s.X + 0.02, 0.12, col.secondary)
			Fit.box(
				ctx,
				f.name,
				CFrame.new(0, s.Y / 2 + 0.016, s.Z * 0.05),
				Vector3.new(s.X * 0.22, 0.008, 0.035),
				Fit.shade(col.secondary, -0.5),
				SMOOTH,
				"shoes_Slot"
			)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Sneakers (leather court sneaker or vulcanised canvas)
---------------------------------------------------------------------------------------------------
local function sneaker(ctx: Ctx)
	local col = ctx.colors
	local canvas = ctx.item.style == "canvas"
	for _, f in feet(ctx) do
		local s = f.s
		base(ctx, f, {
			upper = col.primary,
			upperMaterial = if canvas then FABRIC else LEATHER,
			sole = col.secondary,
			soleHeight = 0.1,
			toeLength = 0.16,
			toeHeight = 0.62,
			toeWidth = 0.02,
			heel = nil,
			heelHeight = 0,
		})
		laces(
			ctx,
			f,
			if canvas then col.primary else Fit.shade(col.primary, -0.04),
			Color3.fromRGB(245, 245, 240),
			true
		)
		if canvas then
			-- rubber toe cap and the foxing stripe along the sole
			Fit.box(
				ctx,
				f.name,
				CFrame.new(0, -s.Y / 2 + 0.1 + 0.035, -s.Z / 2 - 0.02),
				Vector3.new(s.X + 0.03, 0.07, 0.1),
				col.accent,
				SMOOTH,
				"shoes_ToeCap"
			)
			Fit.box(
				ctx,
				f.name,
				CFrame.new(0, -s.Y / 2 + 0.075, -0.06),
				Vector3.new(s.X + 0.06, 0.018, s.Z + 0.2),
				Fit.shade(col.primary, -0.2),
				SMOOTH,
				"shoes_Foxing"
			)
		else
			-- heel tab and a side panel stripe in the accent colour
			Fit.box(
				ctx,
				f.name,
				CFrame.new(0, s.Y / 2 - 0.04, s.Z / 2 + 0.012),
				Vector3.new(s.X * 0.32, s.Y * 0.9, 0.025),
				col.accent,
				LEATHER,
				"shoes_HeelTab"
			)
			Fit.box(
				ctx,
				f.name,
				CFrame.new(f.sx * (s.X / 2 + 0.007), 0.0, 0.05) * CFrame.Angles(rad(-14), 0, 0),
				Vector3.new(0.014, 0.05, s.Z * 0.55),
				col.accent,
				LEATHER,
				"shoes_Stripe"
			)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Heels (block heel / pump): pointed toe box, skin showing at the instep, heel at the back
---------------------------------------------------------------------------------------------------
local function heel(ctx: Ctx)
	local col = ctx.colors
	local block = ctx.item.style == "block"
	for _, f in feet(ctx) do
		local s = f.s
		base(ctx, f, {
			upper = col.primary,
			upperMaterial = if block then LEATHER else SMOOTH,
			sole = col.secondary,
			soleHeight = 0.035,
			toeLength = if block then 0.2 else 0.28,
			toeHeight = 0.6,
			toeWidth = if block then -0.06 else -0.16,
			heel = nil,
			heelHeight = 0,
			shine = if block then nil else 0.2,
		})
		-- the open instep shows skin
		topStrip(ctx, f, 0, s.Z * 0.12, s.X * 0.64, s.Z * 0.5, ctx.skin, SMOOTH)
		-- heel: a column at the back of the shoe (wide for block heels, slim for pumps)
		local hw = if block then 0.3 else 0.13
		Fit.box(
			ctx,
			f.name,
			CFrame.new(0, -s.Y / 2 + s.Y * 0.45, s.Z / 2 + 0.03),
			Vector3.new(hw, s.Y * 0.9, if block then 0.24 else 0.16),
			col.secondary,
			SMOOTH,
			"shoes_Heel"
		)
		if not block then
			-- metal heel tip
			Fit.box(
				ctx,
				f.name,
				CFrame.new(0, -s.Y / 2 + 0.02, s.Z / 2 + 0.03),
				Vector3.new(hw + 0.01, 0.04, 0.17),
				col.accent,
				METAL,
				"shoes_HeelTip"
			)
		end
	end
end

return {
	oxford = { build = oxford, covers = { feet = true } },
	loafer = { build = loafer, covers = { feet = true } },
	sneaker = { build = sneaker, covers = { feet = true } },
	heel = { build = heel, covers = { feet = true } },
}
