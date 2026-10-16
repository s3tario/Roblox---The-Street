--!strict
-- Hat layer builders (slot "head"): ribbed fold-over beanie, six-panel ball cap (and the doorman's peaked
-- cap), felt fedora with a round brim and grosgrain band. Sized from the Head part; everything sits on or
-- just around the top of the head, above the brows. Bake-safe.

local Fit = require(script.Parent.Fit)

type Ctx = Fit.Ctx

local rad = math.rad
local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal

local HEAD = "Head"

local function beanie(ctx: Ctx)
	local h = Fit.size(ctx, HEAD)
	if not h then
		return
	end
	local col = ctx.colors
	local top = h.Y / 2
	Fit.box(
		ctx,
		HEAD,
		CFrame.new(0, top - 0.1, 0),
		Vector3.new(h.X + 0.1, 0.44, h.Z + 0.1),
		col.primary,
		FABRIC,
		"head_Beanie"
	)
	Fit.box(
		ctx,
		HEAD,
		CFrame.new(0, top + 0.17, 0),
		Vector3.new(h.X - 0.1, 0.1, h.Z - 0.1),
		col.primary,
		FABRIC,
		"head_Crown"
	)
	-- folded cuff with ribs
	local foldY = top - 0.27
	Fit.box(
		ctx,
		HEAD,
		CFrame.new(0, foldY, 0),
		Vector3.new(h.X + 0.16, 0.18, h.Z + 0.16),
		col.secondary,
		FABRIC,
		"head_Fold"
	)
	for k = -1, 1 do
		Fit.box(
			ctx,
			HEAD,
			CFrame.new(k * h.X * 0.25, foldY, -h.Z / 2 - 0.085),
			Vector3.new(0.035, 0.16, 0.012),
			Fit.shade(col.secondary, -0.18),
			FABRIC,
			"head_Rib"
		)
	end
end

local function cap(ctx: Ctx)
	local h = Fit.size(ctx, HEAD)
	if not h then
		return
	end
	local col = ctx.colors
	local top = h.Y / 2
	local doorman = ctx.item.style == "doorman"
	if doorman then
		Fit.box(
			ctx,
			HEAD,
			CFrame.new(0, top - 0.04, 0),
			Vector3.new(h.X + 0.08, 0.36, h.Z + 0.08),
			col.primary,
			FABRIC,
			"head_Cap"
		)
		Fit.cyl(ctx, HEAD, CFrame.new(0, top + 0.17, -0.03), 0.08, h.X + 0.34, col.primary, FABRIC, "head_CapTop")
		Fit.box(
			ctx,
			HEAD,
			CFrame.new(0, top - 0.18, 0),
			Vector3.new(h.X + 0.11, 0.09, h.Z + 0.11),
			col.accent,
			METAL,
			"head_Braid"
		)
		local visor = Fit.box(
			ctx,
			HEAD,
			CFrame.new(0, top - 0.23, -h.Z / 2 - 0.19) * CFrame.Angles(rad(-12), 0, 0),
			Vector3.new(h.X * 0.8, 0.04, 0.34),
			col.secondary,
			SMOOTH,
			"head_Visor"
		)
		if visor then
			visor.Reflectance = 0.15
		end
		Fit.box(
			ctx,
			HEAD,
			CFrame.new(0, top + 0.02, -h.Z / 2 - 0.05),
			Vector3.new(0.18, 0.16, 0.025),
			col.accent,
			METAL,
			"head_Badge"
		)
		return
	end
	Fit.box(
		ctx,
		HEAD,
		CFrame.new(0, top - 0.07, 0),
		Vector3.new(h.X + 0.07, 0.32, h.Z + 0.07),
		col.primary,
		FABRIC,
		"head_Cap"
	)
	Fit.box(
		ctx,
		HEAD,
		CFrame.new(0, top + 0.125, 0),
		Vector3.new(h.X - 0.1, 0.07, h.Z - 0.1),
		col.primary,
		FABRIC,
		"head_CapTop"
	)
	Fit.cyl(ctx, HEAD, CFrame.new(0, top + 0.17, 0), 0.03, 0.12, col.secondary, FABRIC, "head_Button")
	-- panel seams over the crown
	for _, sx in { -1, 1 } do
		Fit.box(
			ctx,
			HEAD,
			CFrame.new(sx * h.X * 0.22, top + 0.092, 0),
			Vector3.new(0.025, 0.006, h.Z + 0.07),
			col.secondary,
			FABRIC,
			"head_Seam"
		)
	end
	local brimLen = 0.5
	Fit.box(
		ctx,
		HEAD,
		CFrame.new(0, top - 0.205, -h.Z / 2 - 0.035 - brimLen / 2 + 0.03) * CFrame.Angles(rad(-8), 0, 0),
		Vector3.new(h.X * 0.84, 0.045, brimLen),
		col.secondary,
		FABRIC,
		"head_Brim"
	)
	Fit.box(
		ctx,
		HEAD,
		CFrame.new(0, top - 0.06, -h.Z / 2 - 0.045),
		Vector3.new(0.34, 0.2, 0.02),
		col.accent,
		FABRIC,
		"head_Patch"
	)
end

local function fedora(ctx: Ctx)
	local h = Fit.size(ctx, HEAD)
	if not h then
		return
	end
	local col = ctx.colors
	local top = h.Y / 2
	local crownD = h.X * 0.96
	Fit.cyl(ctx, HEAD, CFrame.new(0, top - 0.17, 0), 0.045, h.X + 0.72, col.primary, FABRIC, "head_Brim")
	Fit.cyl(ctx, HEAD, CFrame.new(0, top + 0.07, 0), 0.48, crownD, col.primary, FABRIC, "head_Crown")
	Fit.cyl(ctx, HEAD, CFrame.new(0, top - 0.09, 0), 0.11, crownD + 0.025, col.accent, FABRIC, "head_Band")
	-- the dent along the top and the front pinch
	Fit.box(
		ctx,
		HEAD,
		CFrame.new(0, top + 0.3, 0.04),
		Vector3.new(0.12, 0.03, crownD * 0.6),
		Fit.shade(col.primary, -0.2),
		FABRIC,
		"head_Dent"
	)
	for _, sx in { -1, 1 } do
		Fit.box(
			ctx,
			HEAD,
			CFrame.new(sx * 0.17, top + 0.18, -crownD / 2 + 0.03) * CFrame.Angles(0, rad(sx * 25), 0),
			Vector3.new(0.12, 0.2, 0.02),
			Fit.shade(col.primary, -0.12),
			FABRIC,
			"head_Pinch"
		)
	end
	-- bow on the wearer's left of the band
	Fit.box(
		ctx,
		HEAD,
		CFrame.new(-crownD / 2 - 0.01, top - 0.09, 0.12),
		Vector3.new(0.03, 0.1, 0.12),
		Fit.shade(col.accent, -0.1),
		FABRIC,
		"head_Bow"
	)
end

return {
	beanie = { build = beanie, covers = { hair = true } },
	cap = { build = cap, covers = { hair = true } },
	fedora = { build = fedora, covers = { hair = true } },
}
