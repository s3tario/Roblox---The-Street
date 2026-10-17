--!strict
-- Logos: clothing-brand marks for the Life Roll brands (Config/Catalog brands, logo id "brand_<brandId>"). All
-- are fictional parodies with original marks; the Pan Miller windmill lives in Windmill.luau and the house
-- labels in HouseBrands.luau. Square unless noted. Canvas: 100 units tall.

local P = require(script.Parent.Primitives)
local Colors = require(script.Parent.Colors)

local hex = Colors.hex
local F = Enum.Font

local list: { P.Spec } = {
	---------------------------------------------------------------------------------------------------
	-- Common
	---------------------------------------------------------------------------------------------------
	{
		-- Minimal monochrome: two light "k"s in a hairline square.
		id = "brand_kevin_kroos",
		kind = "brand",
		name = "Kevin Kroos",
		rarity = "common",
		initials = "KK",
		colors = { main = hex("#111111") },
		draw = function(cv, c, ctx)
			P.frameOutline(cv, 6, 6, 88, 88, 1.6, c.main)
			P.text(cv, "kk", 16, 18, 68, 50, c.main, { font = F.Gotham, weight = Enum.FontWeight.Light })
			if not ctx.simple then
				P.text(cv, "KEVIN KROOS", 16, 72, 68, 9, c.main, { font = F.Gotham, weight = Enum.FontWeight.Medium })
			end
		end,
	},
	{
		-- A ship's anchor over the name.
		id = "brand_old_harbor",
		kind = "brand",
		name = "Old Harbor",
		rarity = "common",
		initials = "OH",
		colors = { main = hex("#1D3557"), accent = hex("#E63946") },
		draw = function(cv, c, ctx)
			local cx = 50
			local top = if ctx.simple then 10 else 4
			local s = if ctx.simple then 80 else 66
			P.ring(cv, cx, top + s * 0.1, s * 0.09, s * 0.05, c.main)
			P.bar(cv, cx, top + s * 0.19, cx, top + s * 0.9, s * 0.08, c.main, { cap = "flat" })
			P.bar(cv, cx - s * 0.26, top + s * 0.3, cx + s * 0.26, top + s * 0.3, s * 0.07, c.accent)
			P.ring(cv, cx, top + s * 0.5, s * 0.42, s * 0.08, c.main, { keep = { { 0.5, 1 } }, dir = 90 })
			P.petal(cv, cx - s * 0.38, top + s * 0.54, s * 0.22, s * 0.13, -18, c.main)
			P.petal(cv, cx + s * 0.38, top + s * 0.54, s * 0.22, s * 0.13, 18, c.main)
			if not ctx.simple then
				P.text(cv, "OLD HARBOR", 10, 80, 80, 14, c.main, { font = F.Oswald, weight = Enum.FontWeight.Bold })
			end
		end,
	},
	{
		-- A navy tile with a white arch over a serif wordmark.
		id = "brand_gapline",
		kind = "brand",
		name = "Gapline",
		rarity = "common",
		initials = "G",
		colors = { main = hex("#1C2B4A"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.rect(cv, 4, 4, 92, 92, c.main)
			P.ring(cv, 50, 50, 30, 4.2, c.counter, { keep = { { 0, 0.5 } }, dir = 90 })
			P.text(cv, "gapline", 12, 54, 76, 28, c.counter, { font = F.Merriweather })
		end,
	},
	{
		-- A red rounded badge with a bold lowercase "hw".
		id = "brand_hanesworth",
		kind = "brand",
		name = "Hanesworth",
		rarity = "common",
		initials = "HW",
		colors = { main = hex("#C8102E"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.rect(cv, 4, 14, 92, 72, c.main, { radius = 22 })
			P.text(cv, "hw", 16, 24, 68, 48, c.counter, { font = F.GothamBlack })
			P.rect(cv, 30, 74, 40, 3, c.counter, { pill = true, t = 0.25 })
		end,
	},
	---------------------------------------------------------------------------------------------------
	-- Uncommon
	---------------------------------------------------------------------------------------------------
	{
		-- A spaced serif wordmark with a fine rule (wide).
		id = "brand_j_crewson",
		kind = "brand",
		name = "J. Crewson",
		rarity = "uncommon",
		initials = "JC",
		aspect = 2.6,
		colors = { main = hex("#1B2A41"), accent = hex("#E8A0A8") },
		draw = function(cv, c)
			P.text(cv, "J.CREWSON", 8, 24, 244, 46, c.main, { font = F.Garamond })
			P.rect(cv, 100, 78, 60, 2.2, c.accent)
		end,
	},
	{
		-- A plantain leaf with a midrib and veins over "PR".
		id = "brand_plantain_republic",
		kind = "brand",
		name = "Plantain Republic",
		rarity = "uncommon",
		initials = "PR",
		colors = { main = hex("#5C6B3A"), accent = hex("#C9BF9A"), ink = hex("#1F2A3A") },
		draw = function(cv, c, ctx)
			local cx, cy, len, ang = 50, 42, 78, 40
			P.lens(cv, cx, cy, len, 32, ang, c.main)
			-- Midrib along the leaf's axis, veins angled towards the tip.
			local x1, y1 = P.polar(cx, cy, len * 0.5, ang + 180)
			local x2, y2 = P.polar(cx, cy, len * 0.42, ang)
			P.bar(cv, x1, y1, x2, y2, 2, c.accent)
			for i = -2, 2 do
				local bx, by = P.polar(cx, cy, i * 9, ang)
				for _, side in { -1, 1 } do
					local ex, ey = P.polar(bx, by, 11 - math.abs(i) * 1.5, ang + side * 55)
					P.bar(cv, bx, by, ex, ey, 1.1, c.accent)
				end
			end
			-- Stalk.
			local sx, sy = P.polar(x1, y1, 9, ang + 180)
			P.bar(cv, x1, y1, sx, sy, 3, c.main)
			if not ctx.simple then
				P.text(cv, "PR", 58, 70, 34, 24, c.ink, { font = F.Garamond, weight = Enum.FontWeight.Bold })
			end
		end,
	},
	{
		-- A navy and red flag with a white hill rising across its foot.
		id = "brand_tommy_hillford",
		kind = "brand",
		keepColors = true,
		name = "Tommy Hillford",
		rarity = "uncommon",
		initials = "TH",
		aspect = 1.4,
		colors = { main = hex("#0B2A5B"), accent = hex("#C8102E"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.rect(cv, 4, 14, 132, 72, c.main)
			P.rect(cv, 70, 20, 60, 60, c.accent)
			P.rect(cv, 10, 20, 60, 60, c.main)
			local hill = P.clip(cv, 10, 20, 120, 60)
			P.circle(cv, 70, 104, 46, c.counter, { g = hill })
			P.frameOutline(cv, 4, 14, 132, 72, 6, c.main)
		end,
	},
	---------------------------------------------------------------------------------------------------
	-- Rare
	---------------------------------------------------------------------------------------------------
	{
		-- Crossed polo mallets and a ball.
		id = "brand_ralph_lorenzo",
		kind = "brand",
		name = "Ralph Lorenzo",
		rarity = "rare",
		initials = "RL",
		colors = { main = hex("#1F2A44"), accent = hex("#B8933F") },
		draw = function(cv, c)
			-- Shafts (top ends are the grips), then the mallet heads across the bottom ends.
			P.bar(cv, 22, 12, 72, 76, 4, c.main)
			P.bar(cv, 78, 12, 28, 76, 4, c.main)
			P.bar(cv, 64, 82, 82, 68, 7, c.main, { cap = "flat" })
			P.bar(cv, 18, 68, 36, 82, 7, c.main, { cap = "flat" })
			P.bar(cv, 19.5, 9, 25, 16, 6, c.main)
			P.bar(cv, 80.5, 9, 75, 16, 6, c.main)
			P.circle(cv, 50, 86, 6, c.accent)
		end,
	},
	{
		-- A golden fleece: a sheep slung from a ribbon.
		id = "brand_brooks_brethren",
		kind = "brand",
		name = "Brooks Brethren",
		rarity = "rare",
		initials = "BB",
		colors = { main = hex("#B8933F"), accent = hex("#1B2A41") },
		draw = function(cv, c)
			-- Ribbon from a ring.
			P.ring(cv, 50, 9, 5, 1.8, c.accent)
			P.bar(cv, 50, 13, 30, 40, 2.6, c.accent)
			P.bar(cv, 50, 13, 70, 40, 2.6, c.accent)
			-- Fleece: overlapping curls.
			for _, p in { { 34, 50 }, { 44, 45 }, { 55, 45 }, { 65, 50 }, { 40, 58 }, { 52, 58 }, { 63, 58 } } do
				P.circle(cv, p[1], p[2], 9, c.main)
			end
			-- Head hanging down at the left, legs folded below.
			P.lens(cv, 25, 64, 20, 11, 20, c.main)
			P.circle(cv, 23.5, 59, 1.4, c.accent)
			P.bar(cv, 40, 64, 38, 82, 3, c.main)
			P.bar(cv, 46, 65, 47, 84, 3, c.main)
			P.bar(cv, 58, 65, 60, 84, 3, c.main)
			P.bar(cv, 65, 63, 69, 82, 3, c.main)
		end,
	},
	{
		-- A pink whale with a raised tail.
		id = "brand_vineyard_wines",
		kind = "brand",
		name = "Vineyard Wines",
		rarity = "rare",
		initials = "VW",
		colors = { main = hex("#E8799A"), accent = hex("#1B2A41"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.circle(cv, 34, 56, 20, c.main)
			P.lens(cv, 54, 57, 58, 34, 96, c.main)
			P.bar(cv, 76, 56, 84, 40, 7, c.main)
			P.petal(cv, 84, 40, 17, 8, -40, c.main)
			P.petal(cv, 84, 40, 17, 8, 50, c.main)
			P.lens(cv, 50, 71, 14, 5, 115, c.main)
			P.circle(cv, 26, 52, 2, c.accent)
			P.bar(cv, 18, 63, 34, 64, 1.4, c.counter)
		end,
	},
	{
		-- A mountain patch: dark peaks against sunset bands, with the name under it.
		id = "brand_patagonio",
		kind = "brand",
		keepColors = true,
		name = "Patagonio",
		rarity = "rare",
		initials = "P",
		aspect = 1.45,
		colors = {
			main = hex("#1E2A3A"),
			sky1 = hex("#F2A541"),
			sky2 = hex("#E2546E"),
			sky3 = hex("#6B4E9B"),
			counter = hex("#FFFFFF"),
		},
		draw = function(cv, c, ctx)
			local x, y, w, h = 8, 6, 129, 64
			local sky = P.clip(cv, x, y, w, h)
			P.rect(cv, x, y, w, h * 0.34, c.sky3, { g = sky })
			P.rect(cv, x, y + h * 0.33, w, h * 0.34, c.sky2, { g = sky })
			P.rect(cv, x, y + h * 0.66, w, h * 0.35, c.sky1, { g = sky })
			local baseY = y + h
			P.triangle(cv, 30, 34, x, 64, baseY, c.main, { g = sky })
			P.triangle(cv, 62, 18, 36, 90, baseY, c.main, { g = sky })
			P.triangle(cv, 80, 28, 66, 98, baseY, c.main, { g = sky })
			P.triangle(cv, 108, 38, 86, w + x, baseY, c.main, { g = sky })
			P.frameOutline(cv, x, y, w, h, 2.4, c.main)
			if not ctx.simple then
				P.text(cv, "patagonio", 20, 74, 105, 22, c.main, { font = F.GothamBlack, italic = true })
			end
		end,
	},
	---------------------------------------------------------------------------------------------------
	-- Epic
	---------------------------------------------------------------------------------------------------
	{
		-- A Bodoni "B" in a navy roundel with a fine gold ring and the word ROMA.
		id = "brand_briani",
		kind = "brand",
		name = "Briani",
		rarity = "epic",
		initials = "B",
		colors = { main = hex("#1B2A41"), accent = hex("#C9A54C"), counter = hex("#FFFFFF") },
		draw = function(cv, c, ctx)
			P.circle(cv, 50, 50, 48, c.main)
			P.ring(cv, 50, 50, 43, 1.4, c.accent)
			P.text(cv, "B", 28, 18, 44, 52, c.counter, { font = F.Bodoni })
			P.rect(cv, 38, 70, 24, 1.2, c.accent)
			if not ctx.simple then
				P.text(cv, "ROMA", 36, 73, 28, 8, c.accent, { font = F.Garamond })
			end
		end,
	},
	{
		-- The gold C: a heavy open ring with ball terminals, over the name.
		id = "brand_canale",
		kind = "brand",
		name = "Canalé",
		rarity = "epic",
		initials = "C",
		colors = { main = hex("#C9A54C"), accent = hex("#2B2B2B") },
		draw = function(cv, c, ctx)
			local cx, cy, r, th = 50, 42, 34, 10
			local cut = 0.8
			P.ring(cv, cx, cy, r, th, c.main, { keep = { { 0, cut } }, dir = 0 })
			-- Terminals where the chord cuts the ring.
			local dx = (cut - 0.5) * 2 * r
			local mid = r - th / 2
			local dy = math.sqrt(math.max(mid * mid - dx * dx, 0))
			P.circle(cv, cx + dx, cy - dy, th * 0.62, c.main)
			P.circle(cv, cx + dx, cy + dy, th * 0.62, c.main)
			if not ctx.simple then
				P.text(cv, "CANALÉ", 18, 82, 64, 13, c.accent, { font = F.Garamond })
			end
		end,
	},
	---------------------------------------------------------------------------------------------------
	-- Legendary
	---------------------------------------------------------------------------------------------------
	{
		-- A Bodoni wordmark between two emerald rules (wide).
		id = "brand_tom_fordham",
		kind = "brand",
		name = "Tom Fordham",
		rarity = "legendary",
		initials = "TF",
		aspect = 2.8,
		colors = { main = hex("#0D0D0D"), accent = hex("#0B6E4F") },
		draw = function(cv, c)
			P.rect(cv, 10, 18, 260, 2, c.accent)
			P.text(cv, "TOM FORDHAM", 10, 28, 260, 44, c.main, { font = F.Bodoni })
			P.rect(cv, 10, 80, 260, 2, c.accent)
		end,
	},
	{
		-- A geometric "Z" of three bars in a blue-grey square.
		id = "brand_zegnatti",
		kind = "brand",
		name = "Zegnatti",
		rarity = "legendary",
		initials = "Z",
		colors = { main = hex("#4A6378"), counter = hex("#F4F1EA") },
		draw = function(cv, c)
			P.rect(cv, 4, 4, 92, 92, c.main, { radius = 4 })
			P.rect(cv, 26, 24, 48, 9, c.counter)
			P.rect(cv, 26, 67, 48, 9, c.counter)
			-- The diagonal: everything below-right of one edge, then the tile colour back beyond the other.
			local g = P.clip(cv, 26, 33, 48, 34)
			P.halfPlane(cv, g, 26, 67, 74 - 14, 33, c.counter)
			P.halfPlane(cv, g, 26 + 14, 67, 74, 33, c.main)
			P.frameOutline(cv, 10, 10, 80, 80, 1, c.counter, { t = 0.4 })
		end,
	},
	{
		-- Interlaced serif "B" and "C" in a hairline ring (quiet luxury).
		id = "brand_bruno_cucina",
		kind = "brand",
		name = "Bruno Cucina",
		rarity = "legendary",
		initials = "BC",
		colors = { main = hex("#7A6652"), accent = hex("#C8B8A2") },
		draw = function(cv, c, ctx)
			P.ring(cv, 50, 50, 47, 1.2, c.main)
			P.ring(cv, 50, 50, 43, 0.6, c.accent)
			P.text(cv, "B", 22, 22, 36, 50, c.main, { font = F.Garamond })
			P.text(cv, "C", 42, 28, 36, 50, c.accent, { font = F.Garamond })
			if not ctx.simple then
				P.text(cv, "BRUNO CUCINA", 26, 76, 48, 7, c.main, { font = F.Garamond })
			end
		end,
	},
}

return list
