--!strict
-- Logos: private equity, private credit and hedge funds. Fictional parodies only; every mark is an original
-- design in the firm's colours (Config/Companies). Canvas: 100 units tall.

local P = require(script.Parent.Primitives)
local Colors = require(script.Parent.Colors)

local hex = Colors.hex
local F = Enum.Font

local SQRT3 = math.sqrt(3)

local list: { P.Spec } = {
	{
		-- A blue hexagon read as a cut stone: three light edges meet at the centre like a cube's corner.
		id = "bluestone",
		kind = "company",
		name = "Bluestone Group",
		initials = "B",
		colors = { main = hex("#1C3D5A"), accent = hex("#A7C4DD"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.hexagon(cv, 50, 50, 48, c.main, { rot = 30 })
			-- The top face, lifted towards the accent.
			local cx, cy, r = 50, 50, 48
			local topY = cy - r
			local midY = cy - r / 2
			local half = r * SQRT3 / 2
			P.triangle(cv, cx, topY, cx - half, cx + half, midY, Colors.mix(c.main, c.accent, 0.35))
			P.triangle(cv, cx, cy, cx - half, cx + half, midY, Colors.mix(c.main, c.accent, 0.35))
			-- Cube edges: up-left, up-right and straight down from the centre.
			local th = 3.2
			local lx, ly = P.polar(cx, cy, r * 0.93, 300)
			local rx, ry = P.polar(cx, cy, r * 0.93, 60)
			P.bar(cv, cx, cy, lx, ly, th, c.counter)
			P.bar(cv, cx, cy, rx, ry, th, c.counter)
			P.bar(cv, cx, cy, cx, cy + r * 0.93, th, c.counter)
		end,
	},
	{
		-- A bold three-letter block with a gold underscore.
		id = "krk",
		kind = "company",
		name = "KRK Partners",
		initials = "KRK",
		aspect = 1.6,
		colors = { main = hex("#2E2A24"), accent = hex("#C9A227"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.rect(cv, 3, 8, 154, 84, c.main, { radius = 4 })
			P.text(cv, "KRK", 14, 20, 132, 50, c.counter, { font = F.GothamBlack })
			P.rect(cv, 20, 74, 120, 5, c.accent)
		end,
	},
	{
		-- A riveted iron shield with a rust chevron.
		id = "ironclad",
		kind = "company",
		name = "Ironclad Capital",
		initials = "IC",
		colors = { main = hex("#2B2B2B"), accent = hex("#B5482F"), counter = hex("#D9D4CC") },
		draw = function(cv, c)
			P.shield(cv, 12, 3, 76, 94, c.main)
			P.shield(cv, 18.5, 9, 63, 82, c.counter)
			P.shield(cv, 21.5, 12, 57, 76, c.main)
			-- Chevron: two broad bars rising to a point under the rivets.
			P.chevron(cv, 50, 59, 46, 22, 9, c.accent, { cap = "flat" })
			for _, x in { 28, 40, 60, 72 } do
				P.circle(cv, x, 22, 2.6, c.counter)
			end
			P.text(cv, "IC", 36, 30, 28, 18, c.counter, { font = F.GothamBlack })
		end,
	},
	{
		-- A rising "A": a navy roundel with a white peak and a green credit line climbing through it.
		id = "aresmont",
		kind = "company",
		name = "Aresmont Credit",
		initials = "AC",
		colors = { main = hex("#243447"), accent = hex("#5FB49C"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.circle(cv, 50, 50, 48, c.main)
			P.triangle(cv, 50, 18, 22, 78, 76, c.counter)
			P.triangle(cv, 50, 38, 35, 65, 76, c.main)
			P.bar(cv, 18, 70, 84, 40, 6, c.accent)
			P.circle(cv, 84, 40, 5.5, c.accent)
		end,
	},
	{
		-- A grey heron standing in a pale roundel: lens body, curved neck, dagger bill and stilt legs.
		id = "gray_heron",
		kind = "company",
		name = "Gray Heron Capital",
		initials = "GH",
		colors = { main = hex("#4A5560"), accent = hex("#D9DEE3"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.circle(cv, 50, 50, 48, c.accent)
			P.ring(cv, 50, 50, 48, 2.2, c.main)
			-- Body and tail.
			P.lens(cv, 55, 52, 38, 17, 118, c.main)
			P.lens(cv, 72, 61, 16, 6, 125, c.main)
			-- Neck: a quarter ring rising from the breast to the head.
			local neck = P.clip(cv, 30, 22, 13.5, 26)
			P.ring(cv, 43, 35, 13, 5, c.main, { g = neck })
			P.circle(cv, 42.5, 24.5, 4.6, c.main)
			-- Bill, crest and eye.
			P.lens(cv, 29.5, 26.5, 22, 3.6, -97, c.main)
			P.bar(cv, 45, 21.5, 53, 19, 1.4, c.main)
			P.circle(cv, 41.5, 23.6, 1, c.counter)
			-- Legs and the waterline.
			P.bar(cv, 52, 60, 49, 84, 1.8, c.main)
			P.bar(cv, 57, 60, 60, 84, 1.8, c.main)
			P.rect(cv, 30, 84, 40, 2, c.main, { pill = true })
		end,
	},
	{
		-- A geometric "B" (a stem and two bowls) under an orange crest arc.
		id = "bridgecrest",
		kind = "company",
		name = "Bridgecrest Associates",
		initials = "BA",
		colors = { main = hex("#14213D"), accent = hex("#FCA311"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.rect(cv, 3, 3, 94, 94, c.main, { radius = 14 })
			-- The crest: the top of a ring over the letter.
			P.ring(cv, 50, 46, 34, 5, c.accent, { keep = { { 0, 0.22 } }, dir = 90 })
			local th = 8
			local x0, top, bottom = 33, 32, 82
			local mid = (top + bottom) / 2
			P.rect(cv, x0, top, th, bottom - top, c.counter)
			-- Bowls: the right halves of two rings, joined to the stem by straight bars.
			local r1 = (mid - top) / 2 + th / 4
			local r2 = (bottom - mid) / 2 + th / 4
			local bx1 = x0 + 14
			local bx2 = x0 + 16
			P.ring(cv, bx1, top + r1, r1, th, c.counter, { keep = { { 0.5, 1 } }, dir = 0 })
			P.ring(cv, bx2, bottom - r2, r2, th, c.counter, { keep = { { 0.5, 1 } }, dir = 0 })
			P.rect(cv, x0, top, bx1 - x0, th, c.counter)
			P.rect(cv, x0, mid - th / 2, bx2 - x0, th, c.counter)
			P.rect(cv, x0, bottom - th, bx2 - x0, th, c.counter)
		end,
	},
	{
		-- A faceted citrine: a gold crown and pavilion with fine facet lines, on a black disc.
		id = "citrine",
		kind = "company",
		name = "Citrine Capital",
		initials = "CC",
		colors = { main = hex("#1E1E24"), accent = hex("#E4B429"), counter = hex("#FFF4CC") },
		draw = function(cv, c)
			P.circle(cv, 50, 50, 48, c.main)
			local top, girdle, tip = 28, 44, 80
			local hw, tw = 30, 17
			-- Crown (trapezoid) and pavilion (triangle pointing down).
			P.trapezoid(cv, 50 - tw, 50 + tw, top, 50 - hw, 50 + hw, girdle, c.accent)
			P.triangle(cv, 50, tip, 50 - hw, 50 + hw, girdle, Colors.darken(c.accent, 0.18))
			-- Facets.
			local fine = 1.1
			P.bar(cv, 50 - hw + 1.5, girdle, 50 + hw - 1.5, girdle, fine, c.main, { cap = "flat" })
			P.bar(cv, 50 - tw * 0.5, top + 0.8, 50 - hw * 0.62, girdle, fine, c.main)
			P.bar(cv, 50 + tw * 0.5, top + 0.8, 50 + hw * 0.62, girdle, fine, c.main)
			P.bar(cv, 50 - hw * 0.62, girdle, 50, tip - 2, fine, c.main)
			P.bar(cv, 50 + hw * 0.62, girdle, 50, tip - 2, fine, c.main)
			P.bar(cv, 50, girdle, 50, tip - 2, fine, c.main)
			P.sparkle(cv, 33, 32, 5, c.counter)
		end,
	},
	{
		-- Mountain peaks: a tall teal ridge between two navy peaks, with a signal line along the ridge.
		id = "quantum_ridge",
		kind = "company",
		name = "Quantum Ridge",
		initials = "QR",
		colors = { main = hex("#0E1A24"), accent = hex("#2BD6C0"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			local base = 80
			P.triangle(cv, 30, 38, 2, 62, base, c.main)
			P.triangle(cv, 74, 44, 46, 98, base, c.main)
			P.triangle(cv, 52, 14, 20, 84, base, c.accent)
			-- A darker cap on the tall peak (a cut-out snow line would need a known backdrop).
			P.triangle(cv, 52, 14, 43.7, 60.3, 32, Colors.darken(c.accent, 0.35))
			P.rect(cv, 2, base + 4, 96, 3, c.main, { pill = true })
			P.rect(cv, 30, base + 10, 40, 2, c.accent, { pill = true })
		end,
	},
}

return list
