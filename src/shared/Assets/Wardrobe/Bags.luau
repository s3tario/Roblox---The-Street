--!strict
-- Bag layer builders (slot "bag"): backpacks (waxed canvas with leather trim, or a sleek commuter pack),
-- a cross-body messenger with brass buckles, and briefcases held in the right hand (soft leather, or the
-- hard-sided attaché with gold corners). Straps run over the front of whatever is worn. Bake-safe.

local Fit = require(script.Parent.Fit)

type Ctx = Fit.Ctx

local rad = math.rad
local FABRIC = Enum.Material.Fabric
local LEATHER = Enum.Material.Leather
local SMOOTH = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal

---------------------------------------------------------------------------------------------------
-- Backpack
---------------------------------------------------------------------------------------------------
local function backpack(ctx: Ctx)
	local s = Fit.size(ctx, "UpperTorso")
	if not s then
		return
	end
	local col = ctx.colors
	local W, H = s.X, s.Y
	local top = H / 2
	local sleek = ctx.item.style == "sleek"
	local depth = if sleek then 0.4 else 0.5
	local back = Fit.backZ(ctx)
	local bodyH = H * 0.8
	local cy = -H * 0.06
	local bz = back + depth / 2 + 0.01
	local mat = if sleek then SMOOTH else FABRIC
	Fit.box(ctx, "UpperTorso", CFrame.new(0, cy, bz), Vector3.new(W * 0.66, bodyH, depth), col.primary, mat, "bag_Pack")
	-- rounded top: a cylinder lying across the pack
	Fit.cyl(
		ctx,
		"UpperTorso",
		CFrame.new(0, cy + bodyH / 2, bz) * CFrame.Angles(0, 0, rad(90)),
		W * 0.66,
		depth,
		col.primary,
		mat,
		"bag_PackTop"
	)
	-- base panel (leather trim) and the grab handle
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, cy - bodyH / 2 + 0.07, bz),
		Vector3.new(W * 0.66 + 0.02, 0.14, depth + 0.02),
		col.accent,
		LEATHER,
		"bag_Base"
	)
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, cy + bodyH / 2 + depth / 2 + 0.02, bz),
		Vector3.new(0.3, 0.05, 0.07),
		col.accent,
		LEATHER,
		"bag_Handle"
	)
	-- front pocket
	local pz = bz + depth / 2
	if sleek then
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, cy - bodyH * 0.12, pz + 0.03),
			Vector3.new(W * 0.5, bodyH * 0.45, 0.06),
			col.secondary,
			SMOOTH,
			"bag_Pocket"
		)
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, cy + bodyH * 0.18, pz + 0.008),
			Vector3.new(W * 0.56, 0.035, 0.016),
			col.accent,
			SMOOTH,
			"bag_Reflector"
		)
	else
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, cy - bodyH * 0.16, pz + 0.07),
			Vector3.new(W * 0.5, bodyH * 0.42, 0.14),
			col.secondary,
			FABRIC,
			"bag_Pocket"
		)
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, cy + bodyH * 0.02, pz + 0.075),
			Vector3.new(W * 0.52, 0.12, 0.155),
			col.accent,
			LEATHER,
			"bag_PocketFlap"
		)
		for _, sx in { -1, 1 } do
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(sx * W * 0.16, cy - bodyH * 0.06, pz + 0.15),
				Vector3.new(0.06, 0.2, 0.02),
				col.accent,
				LEATHER,
				"bag_PocketStrap"
			)
		end
	end
	-- shoulder straps down the front, ending at the sides of the ribs
	local z = Fit.chestFront(ctx) - 0.03
	for _, sx in { -1, 1 } do
		local x = sx * W * 0.25
		local strapLen = H * 0.66
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(x, top - strapLen / 2 + 0.01, z),
			Vector3.new(0.17, strapLen, 0.04),
			col.secondary,
			FABRIC,
			"bag_Strap"
		)
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(x, top - strapLen + 0.06, z - 0.025),
			Vector3.new(0.13, 0.06, 0.02),
			Fit.METALS.gunmetal,
			METAL,
			"bag_Adjuster"
		)
		Fit.strip(
			ctx,
			"UpperTorso",
			Vector3.new(x, top - strapLen + 0.02, z),
			Vector3.new(sx * (W / 2 + 0.01), -H / 2 + 0.14, z + 0.01),
			0.06,
			0.03,
			col.secondary,
			FABRIC,
			"bag_StrapEnd"
		)
	end
end

---------------------------------------------------------------------------------------------------
-- Messenger (strap from the left shoulder to the bag at the back of the right hip)
---------------------------------------------------------------------------------------------------
local function messenger(ctx: Ctx)
	local s = Fit.size(ctx, "UpperTorso")
	if not s then
		return
	end
	local col = ctx.colors
	local W, H = s.X, s.Y
	local top = H / 2
	local front = Fit.chestFront(ctx) - 0.03
	local back = Fit.backZ(ctx) + 0.025
	local a = Vector3.new(-W * 0.36, top + 0.01, 0)
	local b = Vector3.new(W * 0.46, -H / 2 + 0.02, 0)
	for _, z in { front, back } do
		Fit.strip(
			ctx,
			"UpperTorso",
			Vector3.new(a.X, a.Y, z),
			Vector3.new(b.X, b.Y, z),
			0.12,
			0.035,
			col.secondary,
			LEATHER,
			"bag_Strap"
		)
	end
	local l = Fit.size(ctx, "LowerTorso")
	if not l then
		return
	end
	local bw, bh, bd = 0.95, 0.72, 0.28
	local bx, by, bz = l.X * 0.24, -0.26, l.Z / 2 + Fit.SHELL + bd / 2 + 0.02
	Fit.box(ctx, "LowerTorso", CFrame.new(bx, by, bz), Vector3.new(bw, bh, bd), col.primary, FABRIC, "bag_Messenger")
	-- flap over the outer face with two brass-buckled straps
	local flapH = bh * 0.62
	local fz = bz + bd / 2 + 0.015
	Fit.box(
		ctx,
		"LowerTorso",
		CFrame.new(bx, by + bh / 2 - flapH / 2 + 0.01, fz),
		Vector3.new(bw + 0.02, flapH, 0.03),
		Fit.shade(col.primary, -0.08),
		FABRIC,
		"bag_Flap"
	)
	for _, dx in { -0.26, 0.26 } do
		Fit.box(
			ctx,
			"LowerTorso",
			CFrame.new(bx + dx, by + bh / 2 - flapH * 0.55, fz + 0.02),
			Vector3.new(0.08, flapH * 0.8, 0.012),
			col.accent,
			LEATHER,
			"bag_FlapStrap"
		)
		Fit.box(
			ctx,
			"LowerTorso",
			CFrame.new(bx + dx, by + bh / 2 - flapH * 0.95, fz + 0.03),
			Vector3.new(0.12, 0.08, 0.02),
			Fit.METALS.brass,
			METAL,
			"bag_Buckle"
		)
	end
end

---------------------------------------------------------------------------------------------------
-- Briefcase (held in the right hand: thin across X, long front to back)
---------------------------------------------------------------------------------------------------
local function briefcase(ctx: Ctx)
	local s = Fit.size(ctx, "RightHand")
	if not s then
		return
	end
	local col = ctx.colors
	local hard = ctx.item.style == "attache"
	local hand = "RightHand"
	local bottom = -s.Y / 2
	local mat = if hard then SMOOTH else LEATHER
	-- handle: a grip inside the closed hand plus two posts down to the case
	Fit.box(
		ctx,
		hand,
		CFrame.new(0, bottom - 0.02, 0),
		Vector3.new(0.08, 0.07, 0.38),
		col.secondary,
		LEATHER,
		"bag_Grip"
	)
	for _, dz in { -0.16, 0.16 } do
		Fit.box(
			ctx,
			hand,
			CFrame.new(0, bottom - 0.09, dz),
			Vector3.new(0.06, 0.1, 0.05),
			col.accent,
			METAL,
			"bag_Post"
		)
	end
	local ch, cl, cw = 0.86, 1.3, if hard then 0.34 else 0.3
	local cy = bottom - 0.14 - ch / 2
	local body = Fit.box(ctx, hand, CFrame.new(0, cy, 0), Vector3.new(cw, ch, cl), col.primary, mat, "bag_Case")
	if body and hard then
		body.Reflectance = 0.08
	end
	-- frame along the top edge and a seam round the sides
	Fit.box(
		ctx,
		hand,
		CFrame.new(0, cy + ch / 2 - 0.025, 0),
		Vector3.new(cw + 0.02, 0.05, cl + 0.02),
		col.secondary,
		mat,
		"bag_Frame"
	)
	Fit.box(
		ctx,
		hand,
		CFrame.new(0, cy - 0.05, 0),
		Vector3.new(cw + 0.012, 0.02, cl + 0.012),
		Fit.shade(col.primary, -0.3),
		mat,
		"bag_Seam"
	)
	for _, dz in { -0.4, 0.4 } do
		Fit.box(
			ctx,
			hand,
			CFrame.new(0, cy + ch / 2 - 0.1, dz),
			Vector3.new(cw + 0.04, 0.09, 0.11),
			col.accent,
			METAL,
			"bag_Clasp"
		)
	end
	if hard then
		for _, dz in { -1, 1 } do
			Fit.box(
				ctx,
				hand,
				CFrame.new(0, cy - ch / 2 + 0.04, dz * (cl / 2 - 0.04)),
				Vector3.new(cw + 0.03, 0.09, 0.09),
				col.accent,
				METAL,
				"bag_Corner"
			)
		end
	end
end

return {
	backpack = { build = backpack, covers = { back = true } },
	messenger = { build = messenger, covers = {} },
	briefcase = { build = briefcase, covers = {} },
}
