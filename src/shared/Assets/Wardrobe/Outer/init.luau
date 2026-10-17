--!strict
-- Outerwear layer builders (slot "outer"). Tailored garments (jackets, blazers, overcoats) are described as
-- a Tailored.Spec and built by Tailored.tailored; untailored pieces live in Casual.luau. Bake-safe.

local Fit = require(script.Parent.Fit)
local Tailored = require(script.Tailored)
local Casual = require(script.Casual)

type Ctx = Fit.Ctx
type Spec = Tailored.Spec

local SMOOTH = Enum.Material.SmoothPlastic
local tailored = Tailored.tailored

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
	elseif style == "shawl" then
		-- tuxedo with a satin shawl collar (Tom Fordham)
		spec.apex = 0.7
		spec.lapel = 0.22
		spec.shawl = true
		spec.buttons = "one"
		spec.lapelColor = col.secondary
		spec.lapelMaterial = SMOOTH
		spec.lapelEdge = Fit.shade(col.secondary, 0.12)
		spec.buttonColor = col.secondary
		spec.pockets = "jetted"
	elseif style == "kingsley" then
		-- William Kingsley Signature: chalk-stripe double-breasted, gold buttons, claret silk square
		spec.apex = 0.5
		spec.lapel = 0.27
		spec.peak = true
		spec.buttons = "double"
		spec.buttonColor = col.accent
		spec.pocketSquare = col.trim
		spec.lapelEdge = Fit.shade(col.primary, 0.18)
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
	elseif style == "heirloom" then
		-- the Vanderfeller crest blazer: gold crest buttons, gold-piped lapels, embroidered crest
		spec.buttonColor = col.accent
		spec.crest = col.accent
		spec.lapelEdge = col.accent
		spec.cuffButtons = true
		spec.structured = true
		spec.pockets = "flap"
		spec.peak = true
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

return {
	jacket = { build = jacket, covers = { torso = true, arms = true, waist = true } },
	blazer = { build = blazer, covers = { torso = true, arms = true, waist = true } },
	overcoat = { build = overcoat, covers = { torso = true, arms = true, waist = true, thighs = true } },
	vest = {
		build = Casual.vest,
		covers = function(item: any): { [string]: boolean }
			if item.style == "fleece" then
				return { torso = true, waist = true }
			end
			return { torso = true }
		end,
	},
	overshirt = { build = Casual.overshirt, covers = { arms = true, waist = true } },
	apron = { build = Casual.apron, covers = {} },
}
