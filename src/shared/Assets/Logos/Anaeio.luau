--!strict
-- Logos: Anaeio, the owner's wordmark rebuilt geometrically (design v3 §16). Lowercase "anaeio" in a rounded
-- geometric sans, one stroke weight throughout:
--   a   a ring with a short diagonal tail stroke leaving its bottom right
--   n   an arch (a half ring on two straight legs)
--   e   a ring with a horizontal bar, open on the right below the bar
--   i   a stem with a round dot
--   o   a ring split by small horizontal gaps at its left and right middle
-- Black on light by default (the dark theme lifts it to near-white). Canvas: 100 units tall.

local P = require(script.Parent.Primitives)
local Colors = require(script.Parent.Colors)

local hex = Colors.hex

-- Letter metrics (units). Every glyph shares the x-height band CY - R .. CY + R.
local R = 26.5 -- outer radius of the round letters
local TH = 8.6 -- stroke weight
local RN = R * 0.86 -- outer radius of the n's arch
local GAP = 7.5 -- letter spacing
local MARGIN = 5
local CY = 58.5 -- x-height centre line (keeps the i-dot and the baseline evenly inset)

-- The a's tail: leaves the ring's centre line at TAIL_FROM degrees (clockwise from up) and runs TAIL_LEN
-- units at TAIL_ANGLE degrees below horizontal, ending on the baseline.
local TAIL_FROM = 132
local TAIL_ANGLE = 42
local CENTRE_R = R - TH / 2
local tailStartX = CENTRE_R * math.sin(math.rad(TAIL_FROM))
local tailStartY = -CENTRE_R * math.cos(math.rad(TAIL_FROM))
local TAIL_LEN = (R - TH / 2 - tailStartY) / math.sin(math.rad(TAIL_ANGLE))
local tailEndX = tailStartX + TAIL_LEN * math.cos(math.rad(TAIL_ANGLE))
local tailEndY = tailStartY + TAIL_LEN * math.sin(math.rad(TAIL_ANGLE))
local A_RIGHT = math.max(R, tailEndX + TH / 2) -- the a's right extent from its ring centre

-- Glyph advance widths, in order.
local ADV_A = R + A_RIGHT
local ADV_N = 2 * RN
local ADV_E = 2 * R
local ADV_I = TH
local ADV_O = 2 * R
-- The tail sits low, so the letter after an "a" tucks in slightly.
local TUCK = 2.5

local WIDTH = MARGIN * 2 + ADV_A * 2 + ADV_N + ADV_E + ADV_I + ADV_O + GAP * 5 - TUCK * 2
local ASPECT = WIDTH / 100

local function letterA(cv: P.Canvas, left: number, ink: Color3)
	local cx = left + R
	P.ring(cv, cx, CY, R, TH, ink)
	P.bar(cv, cx + tailStartX, CY + tailStartY, cx + tailEndX, CY + tailEndY, TH, ink)
end

local function letterN(cv: P.Canvas, left: number, ink: Color3)
	local cx = left + RN
	local archCy = CY - R + RN
	local foot = CY + R - TH / 2
	-- Top half of the ring, then two legs from the arch's widest point down to the baseline.
	P.ring(cv, cx, archCy, RN, TH, ink, { keep = { { 0, 0.5 } }, dir = 90 })
	local legX = RN - TH / 2
	P.bar(cv, cx - legX, archCy, cx - legX, foot, TH, ink)
	P.bar(cv, cx + legX, archCy, cx + legX, foot, TH, ink)
end

local function letterE(cv: P.Canvas, left: number, ink: Color3)
	local cx = left + R
	-- Closed upper bowl, the lower bowl cut short on the right (the opening), and the bar.
	P.ring(cv, cx, CY, R, TH, ink, { keep = { { 0, 0.5 } }, dir = 90 })
	local low = P.clip(cv, cx - R, CY, R * 1.62, R + 0.5, { name = "EBowl" })
	P.ring(cv, cx, CY, R, TH, ink, { g = low })
	-- The bar stops where the bowl's outer edge is at the bar's top and bottom, so no corner pokes out.
	local barH = TH * 0.86
	local reach = math.sqrt(R * R - (barH / 2) ^ 2)
	P.rect(cv, cx - reach + 0.4, CY - barH / 2, 2 * reach - 0.4, barH, ink)
end

local function letterI(cv: P.Canvas, left: number, ink: Color3)
	local x = left + TH / 2
	P.bar(cv, x, CY - R + TH / 2, x, CY + R - TH / 2, TH, ink)
	local dotR = TH * 0.64
	P.circle(cv, x, CY - R - TH * 0.72 - dotR, dotR, ink)
end

local function letterO(cv: P.Canvas, left: number, ink: Color3)
	local cx = left + R
	local gap = 2.4 / (2 * R) -- half the gap height, as a fraction of the ring
	P.ring(cv, cx, CY, R, TH, ink, { keep = { { 0, 0.5 - gap }, { 0.5 + gap, 1 } }, dir = 90 })
end

local list: { P.Spec } = {
	{
		id = "anaeio",
		kind = "company",
		name = "Anaeio",
		initials = "A",
		aspect = ASPECT,
		colors = { main = hex("#101820"), accent = hex("#38B2AC") },
		draw = function(cv, c)
			local ink = c.main
			local x = MARGIN
			letterA(cv, x, ink)
			x += ADV_A + GAP - TUCK
			letterN(cv, x, ink)
			x += ADV_N + GAP
			letterA(cv, x, ink)
			x += ADV_A + GAP - TUCK
			letterE(cv, x, ink)
			x += ADV_E + GAP
			letterI(cv, x, ink)
			x += ADV_I + GAP
			letterO(cv, x, ink)
		end,
	},
}

return list
