--!strict
-- Logos: banks and advisory firms (bulge bracket, elite boutiques, middle market, regional). Fictional
-- parodies only; every mark is an original design in the firm's colours. Canvas: 100 units tall.

local P = require(script.Parent.Primitives)
local Colors = require(script.Parent.Colors)

local hex = Colors.hex
local F = Enum.Font

local list: { P.Spec } = {
	{
		-- A bold serif monogram in a navy octagon with a gold keyline.
		id = "mg_freeman",
		kind = "company",
		name = "MG Freeman",
		initials = "MG",
		colors = { main = hex("#1B2A4A"), accent = hex("#B8935A"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.octagon(cv, 50, 50, 96, c.main)
			P.octagon(cv, 50, 50, 87, c.accent)
			P.octagon(cv, 50, 50, 83, c.main)
			P.text(cv, "MG", 15, 29, 70, 40, c.counter, { font = F.Merriweather, weight = Enum.FontWeight.Bold })
			P.rect(cv, 38, 72, 24, 1.8, c.accent)
		end,
	},
	{
		-- A gold square with a classic serif "GS" and a fine inner keyline.
		id = "goldfield_saxe",
		kind = "company",
		name = "Goldfield Saxe",
		initials = "GS",
		colors = { main = hex("#A8843A"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.rect(cv, 2, 2, 96, 96, c.main, { radius = 3 })
			P.frameOutline(cv, 8, 8, 84, 84, 1.2, c.counter, { t = 0.3 })
			P.text(cv, "GS", 14, 22, 72, 48, c.counter, { font = F.Bodoni })
			P.rect(cv, 32, 75, 36, 1.2, c.counter)
		end,
	},
	{
		-- A serif wordmark under a thin rule.
		id = "morrow_stanton",
		kind = "company",
		name = "Morrow Stanton",
		initials = "MS",
		aspect = 3.2,
		colors = { main = hex("#0E3B5B"), accent = hex("#8FB8DE") },
		draw = function(cv, c)
			P.rect(cv, 6, 18, 308, 1.8, c.main)
			P.text(cv, "Morrow Stanton", 6, 28, 308, 56, c.main, { font = F.Garamond })
		end,
	},
	{
		-- A fictional crest: a bull's head with sweeping horns in a navy roundel.
		id = "merriweather_lynch",
		kind = "company",
		name = "Merriweather Lynch",
		initials = "ML",
		colors = { main = hex("#23262B"), accent = hex("#C2272D"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.circle(cv, 50, 50, 49, c.accent)
			P.circle(cv, 50, 50, 46.5, c.main)
			-- Horns: quarter arcs sweeping out and up from the brow, with rounded tips.
			local left = P.clip(cv, 12, 22, 30, 28)
			local right = P.clip(cv, 58, 22, 30, 28)
			P.ring(cv, 42, 22, 27, 7.5, c.counter, { g = left })
			P.ring(cv, 58, 22, 27, 7.5, c.counter, { g = right })
			P.circle(cv, 18.75, 22.5, 3.75, c.counter)
			P.circle(cv, 81.25, 22.5, 3.75, c.counter)
			-- Ears, head and face.
			P.lens(cv, 30, 50, 15, 6.5, -72, c.counter)
			P.lens(cv, 70, 50, 15, 6.5, 72, c.counter)
			P.shield(cv, 37, 40, 26, 44, c.counter)
			P.circle(cv, 44, 55, 2.2, c.main)
			P.circle(cv, 56, 55, 2.2, c.main)
			P.circle(cv, 46, 76, 1.8, c.main)
			P.circle(cv, 54, 76, 1.8, c.main)
		end,
	},
	{
		-- A laurel wreath around a serif "E".
		id = "evermoor",
		kind = "company",
		name = "Evermoor",
		initials = "E",
		colors = { main = hex("#1F4D3A"), accent = hex("#C2A464") },
		draw = function(cv, c)
			P.laurel(cv, 50, 52, 38, 195, 335, 6, 14, c.main)
			P.laurel(cv, 50, 52, 38, 165, 25, 6, 14, c.main)
			P.circle(cv, 50, 90.5, 2.6, c.accent)
			P.text(cv, "E", 30, 28, 40, 46, c.main, { font = F.Bodoni })
			P.rect(cv, 42, 74, 16, 1.2, c.accent)
		end,
	},
	{
		-- A calligraphic "LF" over a gold rule and a small-caps line.
		id = "lazaro_freres",
		kind = "company",
		name = "Lazaro Frères",
		initials = "LF",
		colors = { main = hex("#141414"), accent = hex("#C8A951") },
		draw = function(cv, c, ctx)
			P.text(cv, "LF", 6, 8, 88, 62, c.main, { font = F.Fondamento, italic = true })
			P.rect(cv, 24, 73, 52, 1.4, c.accent)
			if not ctx.simple then
				P.text(cv, "LAZARO FRÈRES", 12, 79, 76, 10, c.main, { font = F.Garamond })
			end
		end,
	},
	{
		-- Concentric circles crossed by a centre line.
		id = "centerline",
		kind = "company",
		name = "Centerline",
		initials = "C",
		colors = { main = hex("#3B4552"), accent = hex("#C77D4A") },
		draw = function(cv, c)
			P.ring(cv, 50, 50, 47, 4.5, c.main)
			P.ring(cv, 50, 50, 34, 4.5, c.main)
			P.ring(cv, 50, 50, 21, 4.5, c.main)
			P.bar(cv, 3, 50, 97, 50, 2.6, c.accent, { cap = "flat" })
			P.circle(cv, 50, 50, 6.5, c.accent)
		end,
	},
	{
		-- A rounded diamond with "HW" inside a fine keyline.
		id = "harrow_williams",
		kind = "company",
		name = "Harrow Williams",
		initials = "HW",
		colors = { main = hex("#6B1E2E"), accent = hex("#E3D3B5"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.diamond(cv, 50, 50, 48, c.main, { radius = 5 })
			P.diamondRing(cv, 50, 50, 41, 1.4, c.accent, { radius = 3 })
			P.text(cv, "HW", 25, 38, 50, 24, c.counter, { font = F.GothamBlack })
		end,
	},
	{
		-- A classical bank front: pediment, four columns, stepped base.
		id = "blairmont",
		kind = "company",
		name = "Blairmont & Co.",
		initials = "B",
		colors = { main = hex("#0F5C5C"), accent = hex("#F0B429") },
		draw = function(cv, c)
			local left = P.clip(cv, 8, 6, 42, 20.5)
			local right = P.clip(cv, 50, 6, 42, 20.5)
			P.peak(cv, left, 50, 7, 26.5, c.main, 70)
			P.peak(cv, right, 50, 7, 26.5, c.main, 20)
			P.rect(cv, 10, 28, 80, 5, c.main)
			for _, x in { 15.5, 32.5, 59.5, 76.5 } do
				P.rect(cv, x, 35.5, 8, 41, c.main)
				P.rect(cv, x - 1.5, 35.5, 11, 2.4, c.main)
			end
			P.rect(cv, 10, 79, 80, 5, c.main)
			P.rect(cv, 5, 86, 90, 6, c.main)
			P.circle(cv, 50, 19.5, 2.6, c.accent)
		end,
	},
	{
		-- A bold key, set on the diagonal.
		id = "houlton_lockey",
		kind = "company",
		name = "Houlton Lockey",
		initials = "HL",
		colors = { main = hex("#4B2A63"), accent = hex("#B9A2D4") },
		draw = function(cv, c)
			local g = P.layer(cv, 0, 0, 100, 100, -38)
			P.ring(cv, 28, 50, 19, 7.5, c.main, { g = g })
			P.circle(cv, 28, 50, 4, c.accent, { g = g })
			P.bar(cv, 47, 50, 92, 50, 7.5, c.main, { g = g })
			P.rect(cv, 72, 52, 6, 15, c.main, { g = g })
			P.rect(cv, 83, 52, 6, 11, c.main, { g = g })
		end,
	},
	{
		-- "S&V" in a serif inside a double gold ring.
		id = "sterling_vance",
		kind = "company",
		name = "Sterling & Vance",
		initials = "SV",
		colors = { main = hex("#2F3E55"), accent = hex("#C9A54C") },
		draw = function(cv, c)
			P.ring(cv, 50, 50, 48, 3.6, c.accent)
			P.ring(cv, 50, 50, 42, 1.2, c.accent)
			P.text(cv, "S&V", 16, 33, 68, 34, c.main, { font = F.Bodoni })
			P.circle(cv, 50, 20, 1.8, c.accent)
			P.circle(cv, 50, 80, 1.8, c.accent)
		end,
	},
	{
		-- A steel arch bridge over two water lines.
		id = "eastbridge_capital",
		kind = "company",
		name = "Eastbridge Capital Advisors",
		initials = "EC",
		colors = { main = hex("#8A3B1F"), accent = hex("#E8B04B") },
		draw = function(cv, c)
			local arch = P.clip(cv, 8, 28, 84, 42)
			P.ring(cv, 50, 70, 42, 5.5, c.main, { g = arch })
			P.bar(cv, 4, 63, 96, 63, 4.5, c.main, { cap = "flat" })
			local rc = 42 - 5.5 / 2
			for _, x in { 22, 32, 42, 58, 68, 78 } do
				local dx = x - 50
				local top = 70 - math.sqrt(rc * rc - dx * dx) + 1.5
				P.rect(cv, x - 1, top, 2, 63 - top, c.main)
			end
			P.rect(cv, 22, 75, 56, 3, c.accent, { pill = true })
			P.rect(cv, 32, 82, 36, 3, c.accent, { pill = true })
		end,
	},
}

return list
