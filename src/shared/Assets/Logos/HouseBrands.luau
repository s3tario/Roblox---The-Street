--!strict
-- Logos: marks for the house labels sold in the world's shops, the premium lines and family pieces (the
-- Config/Catalog brands with roll = false). Fictional, original marks. Canvas: 100 units.

local P = require(script.Parent.Primitives)
local Colors = require(script.Parent.Colors)

local hex = Colors.hex
local F = Enum.Font

local list: { P.Spec } = {
	{
		-- Collegiate "E" in a maroon roundel with a gold ring.
		id = "brand_eastbridge",
		kind = "brand",
		name = "Eastbridge Campus Store",
		rarity = "common",
		initials = "E",
		colors = { main = hex("#6E1F2B"), accent = hex("#D4A537"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.circle(cv, 50, 50, 48, c.main)
			P.ring(cv, 50, 50, 42, 3, c.accent)
			P.text(cv, "E", 28, 22, 44, 54, c.accent, { font = F.Merriweather, weight = Enum.FontWeight.Heavy })
		end,
	},
	{
		-- An ID badge: a card with a clip slot, a photo square and name lines.
		id = "brand_standard_issue",
		kind = "brand",
		name = "Standard Issue",
		rarity = "common",
		initials = "SI",
		colors = { main = hex("#2E5E8C"), accent = hex("#E8EEF4"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.rect(cv, 20, 6, 60, 88, c.main, { radius = 8 })
			P.rect(cv, 38, 12, 24, 6, c.accent, { pill = true })
			P.rect(cv, 30, 26, 40, 34, c.accent, { radius = 3 })
			P.circle(cv, 50, 38, 7, c.main)
			P.circle(cv, 50, 60, 12, c.main, { keep = { { 0, 0.42 } }, dir = 90 })
			P.rect(cv, 30, 68, 40, 4, c.counter, { pill = true })
			P.rect(cv, 36, 77, 28, 3.4, c.counter, { pill = true, t = 0.35 })
		end,
	},
	{
		-- Tailor's shears, opened, under an "H".
		id = "brand_hartwell",
		kind = "brand",
		name = "Hartwell Tailors",
		rarity = "rare",
		initials = "H",
		colors = { main = hex("#2B2B2B"), accent = hex("#B8933F") },
		draw = function(cv, c)
			P.lens(cv, 38, 34, 62, 9, 14, c.main)
			P.lens(cv, 62, 34, 62, 9, -14, c.main)
			P.ring(cv, 34, 78, 13, 4.2, c.main)
			P.ring(cv, 66, 78, 13, 4.2, c.main)
			P.bar(cv, 39, 66, 47, 52, 4.4, c.main)
			P.bar(cv, 61, 66, 53, 52, 4.4, c.main)
			P.circle(cv, 50, 48, 3.6, c.accent)
		end,
	},
	{
		-- A coat hanger with its hook, over the house initials.
		id = "brand_hartwell_bespoke",
		kind = "brand",
		name = "Hartwell Bespoke",
		rarity = "legendary",
		initials = "HB",
		colors = { main = hex("#1C1C1C"), accent = hex("#B8933F") },
		draw = function(cv, c, ctx)
			P.ring(cv, 50, 17, 8, 3, c.accent, { keep = { { 0, 0.62 } }, dir = 90 })
			P.bar(cv, 57.5, 18, 50, 30, 3, c.accent)
			P.bar(cv, 50, 30, 10, 58, 4, c.main)
			P.bar(cv, 50, 30, 90, 58, 4, c.main)
			P.bar(cv, 10, 58, 90, 58, 4, c.main)
			if not ctx.simple then
				P.text(cv, "HARTWELL", 14, 68, 72, 13, c.main, { font = F.Garamond, weight = Enum.FontWeight.Bold })
				P.text(cv, "BESPOKE", 26, 83, 48, 9, c.accent, { font = F.Garamond })
			end
		end,
	},
	{
		-- A footprint: sole, heel and toes, set at a striding angle.
		id = "brand_strider",
		kind = "brand",
		name = "Strider Shoes",
		rarity = "uncommon",
		initials = "S",
		colors = { main = hex("#6B4226") },
		draw = function(cv, c)
			P.lens(cv, 54, 48, 46, 28, 16, c.main)
			P.circle(cv, 46, 77, 13, c.main)
			local toes = { { 61, 16, 6 }, { 70, 21, 4.6 }, { 76, 28, 4 }, { 79, 36, 3.5 }, { 80, 44, 3 } }
			for _, t in toes do
				P.circle(cv, t[1], t[2], t[3], c.main)
			end
		end,
	},
	{
		-- A watch dial: a steel bezel, twelve indices and the hands at ten past ten.
		id = "brand_vanta",
		kind = "brand",
		name = "Vanta Watches",
		rarity = "rare",
		initials = "V",
		colors = { main = hex("#2F3640"), accent = hex("#C9A54C"), counter = hex("#F4F1EA") },
		draw = function(cv, c)
			P.circle(cv, 50, 50, 47, c.main)
			P.circle(cv, 50, 50, 39, c.counter)
			for i = 0, 11 do
				local long = i % 3 == 0
				local x1, y1 = P.polar(50, 50, if long then 28 else 31, i * 30)
				local x2, y2 = P.polar(50, 50, 35, i * 30)
				P.bar(
					cv,
					x1,
					y1,
					x2,
					y2,
					if long then 3 else 1.6,
					if i == 0 then c.accent else c.main,
					{ cap = "flat" }
				)
			end
			local hx, hy = P.polar(50, 50, 17, 305)
			local mx, my = P.polar(50, 50, 26, 60)
			P.bar(cv, 50, 50, hx, hy, 3.6, c.main)
			P.bar(cv, 50, 50, mx, my, 2.4, c.main)
			P.circle(cv, 50, 50, 3, c.accent)
		end,
	},
	{
		-- A midnight square with a gold corner bracket and "CO".
		id = "brand_corner_office",
		kind = "brand",
		name = "Corner Office Collection",
		rarity = "legendary",
		initials = "CO",
		colors = { main = hex("#141B2D"), accent = hex("#C9A54C"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.rect(cv, 4, 4, 92, 92, c.main, { radius = 6 })
			P.rect(cv, 60, 14, 26, 5, c.accent)
			P.rect(cv, 81, 14, 5, 26, c.accent)
			P.rect(cv, 14, 81, 26, 5, c.accent)
			P.rect(cv, 14, 60, 5, 26, c.accent)
			P.text(cv, "CO", 22, 30, 56, 40, c.counter, { font = F.Bodoni })
		end,
	},
	{
		-- The club crest: a navy shield with "EC" under a gold crown.
		id = "brand_executive_club",
		kind = "brand",
		name = "Executive Club",
		rarity = "legendary",
		initials = "EC",
		colors = { main = hex("#14213D"), accent = hex("#C9A54C"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			-- Crown.
			P.rect(cv, 34, 18, 32, 5, c.accent)
			P.triangle(cv, 37, 5, 34, 44, 18.2, c.accent)
			P.triangle(cv, 50, 2, 44, 56, 18.2, c.accent)
			P.triangle(cv, 63, 5, 56, 66, 18.2, c.accent)
			-- Shield.
			P.shield(cv, 22, 26, 56, 72, c.accent)
			P.shield(cv, 25.5, 29.5, 49, 63, c.main)
			P.text(cv, "EC", 30, 40, 40, 26, c.counter, { font = F.Merriweather, weight = Enum.FontWeight.Bold })
			P.rect(cv, 38, 70, 24, 2, c.accent)
		end,
	},
	{
		-- A signet ring seen from above: a heavy band with an oval face bearing a tiny crest.
		id = "brand_family_heirloom",
		kind = "brand",
		name = "Family Heirloom",
		rarity = "rare",
		initials = "FH",
		colors = { main = hex("#A07C3A"), accent = hex("#5A3E1B"), counter = hex("#F1E3C2") },
		draw = function(cv, c)
			P.ring(cv, 50, 60, 34, 8, c.main)
			P.ovalRing(cv, 50, 34, 40, 32, 4, c.main)
			P.rect(cv, 32, 20, 36, 28, c.counter, { radius = 12 })
			P.shield(cv, 42.5, 24, 15, 20, c.accent)
			P.rect(cv, 46, 29, 8, 1.6, c.counter)
		end,
	},
	{
		-- A work badge: a rounded hexagon with a bold "S" and two service bars.
		id = "brand_staff",
		kind = "brand",
		name = "Staff Uniform",
		rarity = "common",
		initials = "S",
		colors = { main = hex("#3A4F63"), accent = hex("#F0B429"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.hexagon(cv, 50, 50, 47, c.main, { rot = 30 })
			P.text(cv, "S", 30, 20, 40, 44, c.counter, { font = F.GothamBlack })
			P.rect(cv, 32, 68, 36, 4.4, c.accent)
			P.rect(cv, 38, 76, 24, 4.4, c.accent)
		end,
	},
}

return list
