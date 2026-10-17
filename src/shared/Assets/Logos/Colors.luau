--!strict
-- Logos: colour helpers and theme resolution. Pure (no services, no Instances): safe in bakes and Lune.
--
-- Every logo spec names its colours by role:
--   main      the principal ink (or the solid badge a mark sits in)
--   counter   details knocked out of a solid badge (letters inside an octagon, etc.); white by default
--   accent    the second brand colour; any other key is an extra ink
-- Colors.resolve turns those into the colours to draw for a theme:
--   "light"   the brand colours for a light background (the default)
--   "dark"    for a dark background: very dark inks are lifted to near-white and badge counters invert
--   "color"   reversed out of the brand colour: the background becomes `main` and the mark goes light
--   tint      a single-ink version (engraving, embossing, signage); counters take a contrasting shade

local Colors = {}

export type Palette = { [string]: Color3 }

function Colors.hex(s: string): Color3
	local h = string.gsub(s, "#", "")
	return Color3.fromRGB(
		tonumber(string.sub(h, 1, 2), 16) or 0,
		tonumber(string.sub(h, 3, 4), 16) or 0,
		tonumber(string.sub(h, 5, 6), 16) or 0
	)
end
local hex = Colors.hex

function Colors.toHex(c: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.clamp(math.floor(c.R * 255 + 0.5), 0, 255),
		math.clamp(math.floor(c.G * 255 + 0.5), 0, 255),
		math.clamp(math.floor(c.B * 255 + 0.5), 0, 255)
	)
end

Colors.WHITE = hex("#FFFFFF")
Colors.BLACK = hex("#000000")
Colors.INK = hex("#15171B")
Colors.LIGHT_BG = hex("#F7F6F2")
Colors.DARK_BG = hex("#121418")

-- Linear blend of two colours (t = 0 gives a, t = 1 gives b).
function Colors.mix(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, math.clamp(t, 0, 1))
end

function Colors.lighten(c: Color3, t: number): Color3
	return c:Lerp(Colors.WHITE, math.clamp(t, 0, 1))
end

function Colors.darken(c: Color3, t: number): Color3
	return c:Lerp(Colors.BLACK, math.clamp(t, 0, 1))
end

local function channel(v: number): number
	if v <= 0.04045 then
		return v / 12.92
	end
	return ((v + 0.055) / 1.055) ^ 2.4
end

-- WCAG relative luminance (0 black .. 1 white).
function Colors.luminance(c: Color3): number
	return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
end

-- WCAG contrast ratio (1 .. 21).
function Colors.contrast(a: Color3, b: Color3): number
	local la, lb = Colors.luminance(a), Colors.luminance(b)
	if la < lb then
		la, lb = lb, la
	end
	return (la + 0.05) / (lb + 0.05)
end

-- A shade of `c` that reads clearly against `c` itself (for counters in a single-ink logo).
function Colors.counterShade(c: Color3): Color3
	if Colors.luminance(c) > 0.4 then
		return Colors.darken(c, 0.68)
	end
	return Colors.lighten(c, 0.78)
end

-- Prismatic (Mythic) gradient stops.
Colors.PRISM = {
	hex("#D946EF"),
	hex("#8B5CF6"),
	hex("#22D3EE"),
	hex("#34D399"),
	hex("#FDE047"),
	hex("#F472B6"),
}

-- Rarity colours used when Config/Rarity (careerCore) is not available. Mythic's main colour is the first
-- prismatic stop; renderers that can show a gradient use Colors.PRISM.
Colors.RARITY_FALLBACK = {
	common = hex("#9AA0A6"),
	uncommon = hex("#4CAF6A"),
	rare = hex("#3D7DD8"),
	epic = hex("#9B5DE5"),
	legendary = hex("#D4AF37"),
	mythic = hex("#D946EF"),
} :: { [string]: Color3 }

local function lift(c: Color3, bg: Color3): Color3
	if Colors.luminance(c) < 0.06 then
		return Colors.lighten(c, 0.9)
	end
	if Colors.contrast(c, bg) < 3 then
		return Colors.lighten(c, 0.55)
	end
	return c
end

-- Resolve a spec's role colours for a theme. Returns the palette to draw with and the theme's background
-- colour. Missing roles fall back to `main` when read, so a draw function can never get nil.
function Colors.resolve(
	base: Palette,
	theme: string?,
	tint: Color3?,
	overrides: { [string]: Palette }?
): (Palette, Color3)
	local th = theme or "light"
	local main = base.main or Colors.INK
	local counter = base.counter or Colors.WHITE
	local out: Palette = {}
	local bg: Color3

	if tint then
		bg = if th == "dark" then Colors.DARK_BG elseif th == "color" then main else Colors.LIGHT_BG
		local shade = Colors.counterShade(tint)
		for k in base do
			out[k] = tint
		end
		out.main = tint
		out.counter = shade
	elseif th == "dark" then
		bg = Colors.DARK_BG
		for k, v in base do
			out[k] = if k == "counter" then v else lift(v, bg)
		end
		out.main = lift(main, bg)
		-- A dark badge that was lifted to near-white keeps its letters in the original badge colour.
		out.counter = if out.main ~= main then main else counter
	elseif th == "color" then
		bg = base.field or main
		for k, v in base do
			if k ~= "counter" and k ~= "field" then
				out[k] = if Colors.contrast(v, bg) < 2.2 then Colors.lighten(v, 0.85) else v
			end
		end
		out.main = if Colors.contrast(counter, bg) >= 2.2 then counter else Colors.WHITE
		out.counter = bg
	else
		bg = Colors.LIGHT_BG
		for k, v in base do
			out[k] = v
		end
		out.main = main
		out.counter = counter
	end

	if not tint and overrides then
		local o = overrides[th]
		if o then
			for k, v in o do
				out[k] = v
			end
		end
	end
	out.bg = bg

	local resolvedMain = out.main
	setmetatable(out :: any, {
		__index = function()
			return resolvedMain
		end,
	})
	return out, bg
end

return Colors
