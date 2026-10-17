--!strict
-- Logos: venture capital, real estate and corporations. Fictional parodies only; every mark is an original
-- design in the firm's colours (Config/Companies). Canvas: 100 units tall.

local P = require(script.Parent.Primitives)
local Colors = require(script.Parent.Colors)

local hex = Colors.hex
local F = Enum.Font

local list: { P.Spec } = {
	{
		-- A tall conifer of three stacked tiers inside a fine ring.
		id = "sequel",
		kind = "company",
		name = "Sequel Capital",
		initials = "SC",
		colors = { main = hex("#0B3D2E"), accent = hex("#7ED6A5") },
		draw = function(cv, c)
			P.ring(cv, 50, 50, 48, 2.6, c.main)
			P.rect(cv, 46.5, 72, 7, 16, c.main)
			P.triangle(cv, 50, 38, 24, 76, 76, c.main)
			P.triangle(cv, 50, 24, 30, 70, 58, c.main)
			P.triangle(cv, 50, 10, 36, 64, 40, c.main)
			-- A light tier edge on the right of each layer.
			P.triangle(cv, 50, 38, 50, 76, 76, Colors.mix(c.main, c.accent, 0.35))
			P.triangle(cv, 50, 24, 50, 70, 58, Colors.mix(c.main, c.accent, 0.35))
			P.triangle(cv, 50, 10, 50, 64, 40, Colors.mix(c.main, c.accent, 0.35))
		end,
	},
	{
		-- A lowercase wordmark in a black tile with an orange cursor.
		id = "a17z",
		kind = "company",
		name = "a17z",
		initials = "a",
		colors = { main = hex("#1A1A1A"), accent = hex("#F25F2C"), counter = hex("#FFFFFF") },
		draw = function(cv, c)
			P.rect(cv, 3, 3, 94, 94, c.main, { radius = 18 })
			P.text(cv, "a17z", 10, 28, 80, 38, c.counter, { font = F.GothamBlack })
			P.rect(cv, 66, 69, 16, 6, c.accent)
		end,
	},
	{
		-- A seedling: two leaves on a stem rising from a seed below the ground line.
		id = "seedline",
		kind = "company",
		name = "Seedline Ventures",
		initials = "SV",
		colors = { main = hex("#5B8C3A"), accent = hex("#1A1A1A"), seed = hex("#8A6A3E") },
		draw = function(cv, c)
			P.bar(cv, 50, 76, 50, 40, 4.2, c.main)
			P.petal(cv, 49, 54, 32, 15, -58, c.main)
			P.petal(cv, 51, 44, 36, 16, 52, c.main)
			P.rect(cv, 14, 74, 72, 3.4, c.accent, { pill = true })
			P.lens(cv, 50, 85, 13, 9, 90, c.seed)
		end,
	},
	{
		-- Three towers (the middle one with a folded roof) over a brook.
		id = "brookfold",
		kind = "company",
		name = "Brookfold Properties",
		initials = "BP",
		colors = { main = hex("#2F3B2F"), accent = hex("#C2A878") },
		draw = function(cv, c)
			P.rect(cv, 14, 40, 22, 38, c.main)
			P.rect(cv, 64, 30, 22, 48, c.main)
			P.rect(cv, 39, 26, 22, 52, c.main)
			P.triangle(cv, 39, 12, 39, 61, 26, c.main)
			-- Windows: accent slits.
			for i = 0, 3 do
				local y = 34 + i * 10
				P.rect(cv, 43, y, 14, 2.4, c.accent)
			end
			for i = 0, 2 do
				P.rect(cv, 18, 47 + i * 9, 14, 2.4, c.accent)
			end
			for i = 0, 3 do
				P.rect(cv, 68, 37 + i * 9, 14, 2.4, c.accent)
			end
			P.rect(cv, 8, 81, 84, 3, c.main, { pill = true })
			P.rect(cv, 20, 87, 60, 2.6, c.accent, { pill = true })
			P.rect(cv, 32, 92.5, 36, 2.6, c.accent, { pill = true })
		end,
	},
	{
		-- A stone arch on two piers with an amber keystone.
		id = "keystone",
		kind = "company",
		name = "Keystone Realty",
		initials = "KR",
		colors = { main = hex("#3D3328"), accent = hex("#D49A4A") },
		draw = function(cv, c)
			local cx, cy, r, th = 50, 62, 40, 13
			local arch = P.clip(cv, cx - r, cy - r, 2 * r, r)
			P.ring(cv, cx, cy, r, th, c.main, { g = arch })
			P.rect(cv, cx - r, cy - 0.2, th, 24, c.main)
			P.rect(cv, cx + r - th, cy - 0.2, th, 24, c.main)
			P.rect(cv, 4, 88, 92, 5, c.main)
			P.trapezoid(cv, 40, 60, 14, 44, 56, 37, c.accent)
		end,
	},
	{
		-- A compass rose: four two-tone cardinal points, finer diagonals and a ring.
		id = "northwind",
		kind = "company",
		name = "Northwind Holdings",
		initials = "NH",
		colors = { main = hex("#1E2B3A"), accent = hex("#7FA7D9") },
		draw = function(cv, c)
			local cx, cy = 50, 50
			P.ring(cv, cx, cy, 36, 2.4, c.main)
			for _, a in { 45, 135, 225, 315 } do
				P.petal(cv, cx, cy, 34, 9, a, c.accent)
			end
			local w, long = 9, 46
			-- North and south (dark half, light half), then east and west.
			P.triangle(cv, cx, cy - long, cx - w, cx, cy, c.main)
			P.triangle(cv, cx, cy - long, cx, cx + w, cy, c.accent)
			P.triangle(cv, cx, cy + long, cx - w, cx, cy, c.accent)
			P.triangle(cv, cx, cy + long, cx, cx + w, cy, c.main)
			P.triangleV(cv, cx + long, cy, cx, cy - w, cy, c.main)
			P.triangleV(cv, cx + long, cy, cx, cy, cy + w, c.accent)
			P.triangleV(cv, cx - long, cy, cx, cy - w, cy, c.accent)
			P.triangleV(cv, cx - long, cy, cx, cy, cy + w, c.main)
			P.circle(cv, cx, cy, 3.4, c.main)
		end,
	},
	{
		-- A red apple with a leaf and a highlight.
		id = "applewood",
		kind = "company",
		name = "Applewood Industries",
		initials = "AI",
		colors = { main = hex("#D9534F"), accent = hex("#2D4A22"), stem = hex("#5A3B22"), counter = hex("#FFFFFF") },
		draw = function(cv, c, ctx)
			P.circle(cv, 41, 58, 27, c.main)
			P.circle(cv, 59, 58, 27, c.main)
			P.bar(cv, 50, 36, 53, 18, 3.6, c.stem)
			P.petal(cv, 52, 28, 24, 11, 62, c.accent)
			if not ctx.tinted then
				P.lens(cv, 33, 50, 16, 6, -30, c.counter, { t = 0.55 })
			end
		end,
	},
}

return list
