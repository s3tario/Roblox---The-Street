--!strict
-- Signature details (owner v2 brands): small decorations a catalog item lists in `details`, drawn after the
-- item's own layer builder in the same slot, so brand looks stay recognisable without a builder per brand.
-- Colour: the item's colors.trim (falls back to its accent).
--
--   chest emblems   emblem_pony, emblem_whale, emblem_flag, emblem_peak    (wearer's left chest)
--   chest marks     wordmark (small bar), logo_arch (arch logo across the chest)
--   knit / weave    cable (centre braid), gingham (semi-transparent check), rugby_stripes (hoops)
--   trims           tipping (sleeve hem stripes), buttondown (collar-point buttons), monogram_cuff (right cuff)
--   tailoring       lapel_pin (crest pin on the wearer's left lapel; needs a tailored jacket)
--   Emblems.luau    emblem_windmill (Pan Miller), pick_stitch (Briani), crest_c (Canalé)
--
-- When the company logo takes a garment's left chest (Wardrobe.apply, ctx.state.logoSlot), that garment's brand
-- emblem moves to the right chest.
--
-- Tops draw chest details only where no outer layer covers the torso. Bake-safe (contracts §13).

local Fit = require(script.Parent.Fit)
local Emblems = require(script.Parent.Emblems)

type Ctx = Fit.Ctx

local rad = math.rad
local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal

local Details = {}

local function torsoSize(ctx: Ctx): Vector3?
	return Fit.size(ctx, "UpperTorso")
end

-- Front surface of the garment this detail belongs to (set by the item's builder).
local function frontZ(ctx: Ctx, s: Vector3): number
	return ctx.state.torsoFront or -s.Z / 2
end

-- Chest details of a top are hidden under jackets and vests; outer pieces always show theirs.
local function chestVisible(ctx: Ctx): boolean
	return ctx.slot ~= "top" or not Fit.covered(ctx, "torso")
end

local function armsVisible(ctx: Ctx): boolean
	return ctx.slot ~= "top" or not Fit.covered(ctx, "arms")
end

-- Wearer's left chest, where emblems sit (the right chest when the company logo is on this garment).
local function emblemSpot(ctx: Ctx, s: Vector3): (number, number)
	local side = if ctx.state.logoSlot == ctx.slot then 1 else -1
	return side * s.X * 0.27, s.Y / 2 - 0.45
end

---------------------------------------------------------------------------------------------------
-- Emblems
---------------------------------------------------------------------------------------------------
local function emblemPony(ctx: Ctx)
	local s = torsoSize(ctx)
	if not s or not chestVisible(ctx) then
		return
	end
	local x, y = emblemSpot(ctx, s)
	local z = frontZ(ctx, s)
	local trim = ctx.colors.trim
	-- rider disc and the raised mallet
	Fit.cyl(
		ctx,
		"UpperTorso",
		CFrame.new(x, y, z - 0.008) * CFrame.Angles(rad(90), 0, 0),
		0.014,
		0.12,
		trim,
		SMOOTH,
		ctx.slot .. "_Emblem"
	)
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(x + 0.06, y + 0.07, z - 0.009) * CFrame.Angles(0, 0, rad(-30)),
		Vector3.new(0.018, 0.12, 0.012),
		trim,
		SMOOTH,
		ctx.slot .. "_Emblem"
	)
end

local function emblemWhale(ctx: Ctx)
	local s = torsoSize(ctx)
	if not s or not chestVisible(ctx) then
		return
	end
	local x, y = emblemSpot(ctx, s)
	local z = frontZ(ctx, s)
	local trim = ctx.colors.trim
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(x - 0.02, y, z - 0.008),
		Vector3.new(0.14, 0.06, 0.014),
		trim,
		SMOOTH,
		ctx.slot .. "_Emblem"
	)
	-- the tail flicks up behind the body
	Fit.tri(
		ctx,
		"UpperTorso",
		CFrame.new(x + 0.08, y + 0.03, z - 0.008),
		0.06,
		0.07,
		0.014,
		"bl",
		trim,
		SMOOTH,
		ctx.slot .. "_Emblem"
	)
end

local FLAG = {
	Color3.fromRGB(31, 42, 74),
	Color3.fromRGB(244, 244, 240),
	Color3.fromRGB(178, 34, 52),
}

local function emblemFlag(ctx: Ctx)
	local s = torsoSize(ctx)
	if not s or not chestVisible(ctx) then
		return
	end
	local x, y = emblemSpot(ctx, s)
	local z = frontZ(ctx, s)
	local widths = { 0.055, 0.022, 0.055 }
	local left = x - 0.066
	for i, w in widths do
		Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(left + w / 2, y, z - 0.008),
			Vector3.new(w, 0.075, 0.014),
			FLAG[i],
			SMOOTH,
			ctx.slot .. "_Emblem"
		)
		left += w
	end
end

local function emblemPeak(ctx: Ctx)
	local s = torsoSize(ctx)
	if not s or not chestVisible(ctx) then
		return
	end
	local x, y = emblemSpot(ctx, s)
	local z = frontZ(ctx, s)
	-- a dark label with a mountain ridge in the trim colour
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(x, y, z - 0.007),
		Vector3.new(0.21, 0.11, 0.014),
		Color3.fromRGB(30, 36, 48),
		FABRIC,
		ctx.slot .. "_Patch"
	)
	Fit.tri(
		ctx,
		"UpperTorso",
		CFrame.new(x - 0.035, y - 0.012, z - 0.016),
		0.08,
		0.06,
		0.008,
		"br",
		ctx.colors.trim,
		SMOOTH,
		ctx.slot .. "_Peak"
	)
	Fit.tri(
		ctx,
		"UpperTorso",
		CFrame.new(x + 0.035, y - 0.012, z - 0.016),
		0.08,
		0.06,
		0.008,
		"bl",
		ctx.colors.trim,
		SMOOTH,
		ctx.slot .. "_Peak"
	)
end

---------------------------------------------------------------------------------------------------
-- Chest marks
---------------------------------------------------------------------------------------------------
local function wordmark(ctx: Ctx)
	local s = torsoSize(ctx)
	if not s or not chestVisible(ctx) then
		return
	end
	local z = frontZ(ctx, s)
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, s.Y / 2 - 0.36, z - 0.007),
		Vector3.new(0.3, 0.045, 0.014),
		ctx.colors.trim,
		SMOOTH,
		ctx.slot .. "_Wordmark"
	)
end

local function logoArch(ctx: Ctx)
	local s = torsoSize(ctx)
	if not s or not chestVisible(ctx) then
		return
	end
	local z = frontZ(ctx, s) - 0.008
	local trim = ctx.colors.trim
	-- a flat arc of lettering across the chest, between the drawstrings' ends and the pocket
	local cy = -s.Y * 0.08
	local halfW = s.X * 0.3
	local rise = 0.13
	local segments = 5
	local prev: Vector3? = nil
	for i = 0, segments do
		local u = i / segments * 2 - 1 -- -1 .. 1
		local pt = Vector3.new(u * halfW, cy + rise * (1 - u * u), z)
		if prev then
			Fit.strip(ctx, "UpperTorso", prev, pt, 0.07, 0.014, trim, FABRIC, ctx.slot .. "_Arch")
		end
		prev = pt
	end
end

---------------------------------------------------------------------------------------------------
-- Knit and weave
---------------------------------------------------------------------------------------------------
local function cable(ctx: Ctx)
	local s = torsoSize(ctx)
	if not s or not chestVisible(ctx) then
		return
	end
	local z = frontZ(ctx, s)
	local H = s.Y
	-- relief reads as shadow on pale knits and as highlight on dark ones
	local p = ctx.colors.primary
	local k = if (p.R + p.G + p.B) / 3 > 0.6 then -1 else 1
	local raised = Fit.shade(p, 0.08 * k)
	Fit.box(
		ctx,
		"UpperTorso",
		CFrame.new(0, -0.05, z - 0.006),
		Vector3.new(0.18, H - 0.3, 0.012),
		raised,
		FABRIC,
		ctx.slot .. "_Cable"
	)
	-- braid: a zigzag of twisted strands down the centre panel
	local count = 4
	local span = H - 0.4
	local step = span / count
	for i = 0, count - 1 do
		local y0 = (H / 2 - 0.25) - i * step
		local dir = if i % 2 == 0 then 1 else -1
		Fit.strip(
			ctx,
			"UpperTorso",
			Vector3.new(-0.06 * dir, y0, z - 0.015),
			Vector3.new(0.06 * dir, y0 - step, z - 0.015),
			0.05,
			0.01,
			Fit.shade(p, 0.16 * k),
			FABRIC,
			ctx.slot .. "_Braid"
		)
	end
end

local function gingham(ctx: Ctx)
	local s = torsoSize(ctx)
	if not s or not chestVisible(ctx) then
		return
	end
	local z = frontZ(ctx, s)
	local W, H = s.X, s.Y
	local trim = ctx.colors.trim
	local band = 0.12
	for _, fx in { -0.75, -0.45, -0.15, 0.15, 0.45, 0.75 } do
		local p = Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(fx * W / 2, 0, z - 0.002),
			Vector3.new(band, H - 0.02, 0.004),
			trim,
			SMOOTH,
			ctx.slot .. "_Check"
		)
		if p then
			p.Transparency = 0.45
		end
	end
	for _, fy in { -0.75, -0.375, 0, 0.375, 0.75 } do
		local p = Fit.box(
			ctx,
			"UpperTorso",
			CFrame.new(0, fy * H / 2, z - 0.006),
			Vector3.new(W - 0.02, band, 0.004),
			trim,
			SMOOTH,
			ctx.slot .. "_Check"
		)
		if p then
			p.Transparency = 0.45
		end
	end
end

local function rugbyStripes(ctx: Ctx)
	local s = torsoSize(ctx)
	if not s then
		return
	end
	local stripe = ctx.colors.secondary
	if chestVisible(ctx) then
		for _, fy in { 0.3, -0.12, -0.54 } do
			Fit.box(
				ctx,
				"UpperTorso",
				CFrame.new(0, fy * s.Y / 2 + 0.0, 0),
				Vector3.new(s.X + 0.012, 0.17, s.Z + 0.012),
				stripe,
				FABRIC,
				ctx.slot .. "_Hoop"
			)
		end
	end
	if armsVisible(ctx) then
		for _, side in Fit.SIDES do
			local a = Fit.size(ctx, side .. "UpperArm")
			if a then
				Fit.band(ctx, side .. "UpperArm", 0.08, 0.17, 0.006, stripe, FABRIC, ctx.slot .. "_Hoop")
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Trims
---------------------------------------------------------------------------------------------------
local function tipping(ctx: Ctx)
	if not armsVisible(ctx) then
		return
	end
	for _, side in Fit.SIDES do
		local a = Fit.size(ctx, side .. "UpperArm")
		if a then
			Fit.band(
				ctx,
				side .. "UpperArm",
				-a.Y / 2 + 0.04,
				0.035,
				0.032,
				ctx.colors.trim,
				FABRIC,
				ctx.slot .. "_Tipping"
			)
		end
	end
end

local function buttondown(ctx: Ctx)
	local s = torsoSize(ctx)
	if not s or not chestVisible(ctx) then
		return
	end
	local neck = Fit.wearing(ctx, "neck")
	local tie = type(neck) == "table" and (neck.builder == "tie" or neck.builder == "bowtie")
	-- matches Fit.collarPoints: points hang from the collar beside the knot (spread when there's no tie)
	local inner = if tie then 0.07 else 0.2
	-- front face of the collar point (shirt: collar plane, minus the point's offset and half its thickness)
	local collarFront = frontZ(ctx, s) - (if tie then 0 else 0.02) - 0.02 - 0.0175
	local z = collarFront - 0.007
	local y = s.Y / 2 - 0.16
	for _, sx in { -1, 1 } do
		Fit.cyl(
			ctx,
			"UpperTorso",
			CFrame.new(sx * (inner + 0.028), y, z) * CFrame.Angles(rad(90), 0, 0),
			0.018,
			0.04,
			Fit.shade(ctx.colors.accent, -0.05),
			SMOOTH,
			ctx.slot .. "_CollarButton"
		)
	end
end

local function monogramCuff(ctx: Ctx)
	local name = "RightLowerArm"
	local a = Fit.size(ctx, name)
	if not a then
		return
	end
	-- just outside the shirt cuff on the outer side of the right wrist (the watch sits on the left)
	local x = a.X / 2 + 0.025 + 0.007
	local y = -a.Y / 2 + 0.04
	for i, dz in { -0.026, 0.026 } do
		Fit.box(
			ctx,
			name,
			CFrame.new(x, y, dz),
			Vector3.new(0.014, 0.045, if i == 1 then 0.034 else 0.03),
			ctx.colors.trim,
			SMOOTH,
			ctx.slot .. "_Monogram"
		)
	end
end

---------------------------------------------------------------------------------------------------
-- Tailoring
---------------------------------------------------------------------------------------------------
local function lapelPin(ctx: Ctx)
	local v = ctx.state.lapelV
	if type(v) ~= "table" then
		return -- only tailored jackets publish their lapel line
	end
	local dx, dy = v.width / 2, v.topY - v.apexY
	local L = math.sqrt(dx * dx + dy * dy)
	if L < 0.05 then
		return
	end
	local t = 0.7
	-- along the wearer's left V edge from the apex, then out across the lapel
	local ex, ey = -dx * t, v.apexY + dy * t
	local nx, ny = -dy / L, -dx / L
	local off = v.lapel * t * 0.5
	local px, py = ex + nx * off, ey + ny * off
	local z = v.front - 0.012
	Fit.cyl(
		ctx,
		"UpperTorso",
		CFrame.new(px, py, z) * CFrame.Angles(rad(90), 0, 0),
		0.022,
		0.1,
		ctx.colors.accent,
		METAL,
		ctx.slot .. "_LapelPin"
	)
	Fit.cyl(
		ctx,
		"UpperTorso",
		CFrame.new(px, py, z - 0.014) * CFrame.Angles(rad(90), 0, 0),
		0.01,
		0.055,
		ctx.colors.trim,
		SMOOTH,
		ctx.slot .. "_LapelPinEnamel"
	)
end

---------------------------------------------------------------------------------------------------
-- Registry
---------------------------------------------------------------------------------------------------
local builders: { [string]: (Ctx) -> () } = {
	emblem_pony = emblemPony,
	emblem_whale = emblemWhale,
	emblem_flag = emblemFlag,
	emblem_peak = emblemPeak,
	wordmark = wordmark,
	logo_arch = logoArch,
	cable = cable,
	gingham = gingham,
	rugby_stripes = rugbyStripes,
	tipping = tipping,
	buttondown = buttondown,
	monogram_cuff = monogramCuff,
	lapel_pin = lapelPin,
}
for id, fn in Emblems.builders do
	assert(builders[id] == nil, "Details: duplicate detail " .. id)
	builders[id] = fn
end
Details.builders = builders

function Details.has(id: any): boolean
	return type(id) == "string" and builders[id] ~= nil
end

-- True when the item lists a detail whose id starts with `prefix` (builders skip their default logo when the
-- brand draws its own emblem).
function Details.lists(item: any, prefix: string): boolean
	if type(item) ~= "table" or type(item.details) ~= "table" then
		return false
	end
	for _, id in item.details do
		if type(id) == "string" and string.sub(id, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

-- Draws every detail the current item lists (ctx.item / ctx.slot / ctx.colors are already set).
function Details.apply(ctx: Ctx)
	local list = if type(ctx.item) == "table" then ctx.item.details else nil
	if type(list) ~= "table" then
		return
	end
	for _, id in list do
		local fn = builders[id]
		if fn then
			fn(ctx)
		end
	end
end

return Details
