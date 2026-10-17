--!strict
-- Logos: Pan Miller (the Mythic clothing brand, design v3 §2), a classic American farm windmill: a tapered
-- lattice tower of crossed bars, a multi-blade wheel (18 slats radiating from a hub inside a rim) and a tail
-- vane on a boom. A traditional barn windmill, not a modern turbine. Canvas: 100 units.

local P = require(script.Parent.Primitives)
local Colors = require(script.Parent.Colors)

local hex = Colors.hex
local F = Enum.Font

local WHEEL_X, WHEEL_Y = 42, 31
local RIM = 25
local HUB = 8.5
local BLADES = 18

-- Tower: legs from the base corners up to the head, with girts (horizontal ties) at these heights.
local BASE_Y, HEAD_Y = 95, 52
local BASE_L, BASE_R = 23, 61
local HEAD_L, HEAD_R = 38.5, 45.5
local LEVELS = { 95, 81, 69, 59, 52 }

local function legX(y: number, bottom: number, top: number): number
	local t = (BASE_Y - y) / (BASE_Y - HEAD_Y)
	return bottom + (top - bottom) * t
end

local list: { P.Spec } = {
	{
		id = "brand_pan_miller",
		kind = "brand",
		name = "Pan Miller",
		rarity = "mythic",
		initials = "PM",
		colors = { main = hex("#22303F"), accent = hex("#C9A54C"), vane = hex("#7A1F2E"), counter = hex("#F4EBD8") },
		draw = function(cv, c, ctx)
			local ink = c.main
			-- Tail boom and vane, behind the wheel.
			P.bar(cv, WHEEL_X, WHEEL_Y, 84, WHEEL_Y - 2, 2.6, ink)
			P.bar(cv, WHEEL_X + 10, WHEEL_Y + 6, 80, WHEEL_Y - 1, 1.2, ink)
			P.rect(cv, 74, 17, 22, 22, c.vane, { radius = 1.5 })
			P.frameOutline(cv, 74, 17, 22, 22, 1.4, ink, { radius = 1.5 })
			if not ctx.simple then
				P.text(cv, "PM", 76, 21, 18, 14, c.counter, { font = F.Merriweather, weight = Enum.FontWeight.Bold })
			end

			-- Lattice tower: legs, girts and X braces between levels.
			local leg, girt, brace = 2.6, 1.6, 1.1
			P.bar(cv, BASE_L, BASE_Y, HEAD_L, HEAD_Y, leg, ink)
			P.bar(cv, BASE_R, BASE_Y, HEAD_R, HEAD_Y, leg, ink)
			for i, y in LEVELS do
				local l, r = legX(y, BASE_L, HEAD_L), legX(y, BASE_R, HEAD_R)
				P.bar(cv, l, y, r, y, girt, ink)
				local nextY = LEVELS[i + 1]
				if nextY then
					local nl, nr = legX(nextY, BASE_L, HEAD_L), legX(nextY, BASE_R, HEAD_R)
					P.bar(cv, l, y, nr, nextY, brace, ink)
					P.bar(cv, r, y, nl, nextY, brace, ink)
				end
			end
			-- Pump rod down the middle, the head platform and the ground.
			P.bar(cv, (HEAD_L + HEAD_R) / 2, HEAD_Y, (BASE_L + BASE_R) / 2, BASE_Y, 1, ink, { cap = "flat" })
			P.rect(cv, HEAD_L - 3, HEAD_Y - 3, HEAD_R - HEAD_L + 6, 3.4, ink)
			P.rect(cv, 10, BASE_Y, 66, 2.6, ink, { pill = true })
			-- Gearbox under the wheel.
			P.rect(cv, WHEEL_X - 3, WHEEL_Y + 4, 8, 15, ink, { radius = 1.5 })

			-- Wheel: slats pitched a few degrees off radial, between the hub ring and the rim.
			for i = 0, BLADES - 1 do
				local a = i * 360 / BLADES
				local x1, y1 = P.polar(WHEEL_X, WHEEL_Y, HUB, a)
				local x2, y2 = P.polar(WHEEL_X, WHEEL_Y, RIM - 1, a + 4)
				P.bar(cv, x1, y1, x2, y2, 3.3, ink, { cap = "flat" })
			end
			P.ring(cv, WHEEL_X, WHEEL_Y, RIM, 1.8, ink)
			P.ring(cv, WHEEL_X, WHEEL_Y, RIM * 0.66, 0.9, ink)
			P.ring(cv, WHEEL_X, WHEEL_Y, HUB + 0.8, 1.6, ink)
			P.circle(cv, WHEEL_X, WHEEL_Y, 3.6, c.accent)
		end,
	},
}

return list
