--!strict
-- Logos: school crests (contracts §16 school ids; design v3 §2). Every crest is a heater shield in the school's
-- colours with an ordinary (chevron, band, quartering...), a charge and the school's initials. The trim is the
-- rarity colour, and the frame grows with the tier:
--   Common / Uncommon / Rare   a trimmed shield
--   Epic                       + a ribbon with the school's name
--   Legendary                  + a gold laurel
--   Mythic (Harvale)           + prismatic trim bands and a crown of three stars
-- Bands (pale, fess, chief, base, quarters) are the field's own shield cut to a rectangle by a clip group, so
-- they follow the curved point exactly. Canvas: 100 units.
--
--   Schools.list                    the designed crests
--   Schools.generic(id, name, rarity) -> Spec   a crest for a school id that has no designed entry

local P = require(script.Parent.Primitives)
local Colors = require(script.Parent.Colors)
local Hash = require(script.Parent.Parent.Parent.Util.Hash)

local hex = Colors.hex
local F = Enum.Font

type Box = { x: number, y: number, w: number, h: number }

export type Def = {
	id: string,
	name: string,
	short: string, -- ribbon text (Epic and above)
	rarity: string,
	initials: string,
	main: string, -- field
	accent: string, -- ordinary
	counter: string?, -- letters and charges (default white)
	ordinary: string, -- "chevron" | "fess" | "pale" | "perpale" | "chief" | "base" | "quarterly" | "cross" | "none"
	charge: string?, -- "stars" | "gear" | "anchor" | "peaks" | "fjord" | "crown" | "books" | "pine" | "waves" | "roundel"
	text: { number }?, -- initials box as fractions of the field {x, y, w, h}
	ink: string?, -- "counter" (default) | "main" | "accent": colour of the initials
	font: Enum.Font?,
}

local RANK = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 6 } :: { [string]: number }
local GOLD = hex("#D4AF37")

---------------------------------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------------------------------
local function inset(b: Box, t: number): Box
	return { x = b.x + t, y = b.y + t, w = b.w - 2 * t, h = b.h - 2.15 * t }
end

local function shield(cv: P.Canvas, b: Box, color: Color3, g: P.Group?)
	P.shield(cv, b.x, b.y, b.w, b.h, color, { g = g })
end

-- The field's shield in `color`, cut to the rectangle (x, y, w, h).
local function band(cv: P.Canvas, field: Box, x: number, y: number, w: number, h: number, color: Color3)
	local g = P.clip(cv, x, y, w, h, { name = "Band" })
	shield(cv, field, color, g)
end

local function ordinary(cv: P.Canvas, kind: string, f: Box, color: Color3)
	local cx = f.x + f.w / 2
	if kind == "chevron" then
		P.chevron(cv, cx, f.y + f.h * 0.53, f.w * 0.66, f.h * 0.24, f.w * 0.12, color, { cap = "flat" })
	elseif kind == "fess" then
		band(cv, f, f.x, f.y + f.h * 0.4, f.w, f.h * 0.17, color)
	elseif kind == "pale" then
		band(cv, f, cx - f.w * 0.13, f.y, f.w * 0.26, f.h + 1, color)
	elseif kind == "perpale" then
		band(cv, f, cx, f.y, f.w / 2 + 1, f.h + 1, color)
	elseif kind == "chief" then
		band(cv, f, f.x, f.y, f.w, f.h * 0.3, color)
	elseif kind == "base" then
		band(cv, f, f.x, f.y + f.h * 0.66, f.w, f.h * 0.35, color)
	elseif kind == "quarterly" then
		local midY = f.y + f.h * 0.46
		band(cv, f, f.x, f.y, f.w / 2, midY - f.y, color)
		band(cv, f, cx, midY, f.w / 2 + 1, f.h - (midY - f.y) + 1, color)
	elseif kind == "cross" then
		band(cv, f, cx - f.w * 0.1, f.y, f.w * 0.2, f.h + 1, color)
		band(cv, f, f.x, f.y + f.h * 0.36, f.w, f.h * 0.15, color)
	end
end

local function gear(cv: P.Canvas, cx: number, cy: number, r: number, color: Color3)
	for i = 0, 7 do
		local a = i * 45 + 22.5
		local x1, y1 = P.polar(cx, cy, r * 0.7, a)
		local x2, y2 = P.polar(cx, cy, r * 1.08, a)
		P.bar(cv, x1, y1, x2, y2, r * 0.36, color, { cap = "flat" })
	end
	P.ring(cv, cx, cy, r * 0.92, r * 0.34, color)
end

local function anchor(cv: P.Canvas, cx: number, cy: number, s: number, color: Color3)
	local th = s * 0.085
	P.ring(cv, cx, cy - s * 0.4, s * 0.11, th * 0.8, color)
	P.bar(cv, cx, cy - s * 0.29, cx, cy + s * 0.44, th, color, { cap = "flat" })
	P.bar(cv, cx - s * 0.24, cy - s * 0.2, cx + s * 0.24, cy - s * 0.2, th, color)
	P.ring(cv, cx, cy + s * 0.06, s * 0.4, th, color, { keep = { { 0.5, 1 } }, dir = 90 })
	P.petal(cv, cx - s * 0.36, cy + s * 0.1, s * 0.2, th * 1.6, -20, color)
	P.petal(cv, cx + s * 0.36, cy + s * 0.1, s * 0.2, th * 1.6, 20, color)
end

local function crown(cv: P.Canvas, cx: number, cy: number, w: number, color: Color3)
	local baseH = w * 0.2
	P.rect(cv, cx - w / 2, cy, w, baseH, color)
	P.triangle(cv, cx - w * 0.42, cy - w * 0.36, cx - w / 2, cx - w * 0.18, cy + 0.2, color)
	P.triangle(cv, cx, cy - w * 0.5, cx - w * 0.2, cx + w * 0.2, cy + 0.2, color)
	P.triangle(cv, cx + w * 0.42, cy - w * 0.36, cx + w * 0.18, cx + w / 2, cy + 0.2, color)
	local d = w * 0.07
	P.circle(cv, cx - w * 0.42, cy - w * 0.36, d, color)
	P.circle(cv, cx, cy - w * 0.5, d, color)
	P.circle(cv, cx + w * 0.42, cy - w * 0.36, d, color)
end

local function book(cv: P.Canvas, cx: number, cy: number, w: number, color: Color3, page: Color3)
	local h = w * 0.62
	local gap = w * 0.06
	P.rect(cv, cx - w / 2, cy - h / 2, w / 2 - gap / 2, h, color, { radius = w * 0.04 })
	P.rect(cv, cx + gap / 2, cy - h / 2, w / 2 - gap / 2, h, color, { radius = w * 0.04 })
	-- Lines of text on each page.
	for i = 0, 2 do
		local y = cy - h * 0.24 + i * h * 0.22
		P.rect(cv, cx - w * 0.4, y, w * 0.3, h * 0.07, page)
		P.rect(cv, cx + w * 0.1, y, w * 0.3, h * 0.07, page)
	end
end

local function pine(cv: P.Canvas, cx: number, top: number, s: number, color: Color3)
	P.rect(cv, cx - s * 0.07, top + s * 0.78, s * 0.14, s * 0.22, color)
	P.triangle(cv, cx, top + s * 0.32, cx - s * 0.4, cx + s * 0.4, top + s * 0.82, color)
	P.triangle(cv, cx, top, cx - s * 0.3, cx + s * 0.3, top + s * 0.5, color)
end

local function charge(cv: P.Canvas, kind: string, f: Box, c: { [string]: Color3 })
	local cx = f.x + f.w / 2
	local ink = c.counter
	if kind == "stars" then
		for i = -1, 1 do
			P.star(cv, cx + i * f.w * 0.27, f.y + f.h * 0.15, f.w * 0.09, c.main)
		end
	elseif kind == "gear" then
		gear(cv, cx, f.y + f.h * 0.4, f.w * 0.3, c.accent)
	elseif kind == "anchor" then
		anchor(cv, cx, f.y + f.h * 0.58, f.w * 0.62, ink)
	elseif kind == "peaks" then
		local baseY = f.y + f.h * 0.74
		P.triangle(cv, cx - f.w * 0.16, f.y + f.h * 0.44, f.x + f.w * 0.1, cx + f.w * 0.12, baseY, c.accent)
		P.triangle(cv, cx + f.w * 0.14, f.y + f.h * 0.36, cx - f.w * 0.12, f.x + f.w * 0.9, baseY, ink)
	elseif kind == "crown" then
		crown(cv, cx, f.y + f.h * 0.27, f.w * 0.5, c.accent)
	elseif kind == "books" then
		book(cv, cx - f.w * 0.215, f.y + f.h * 0.17, f.w * 0.38, ink, c.main)
		book(cv, cx + f.w * 0.215, f.y + f.h * 0.17, f.w * 0.38, ink, c.main)
		book(cv, cx, f.y + f.h * 0.72, f.w * 0.36, ink, c.main)
	elseif kind == "fjord" then
		local baseY = f.y + f.h * 0.66
		P.triangle(cv, cx - f.w * 0.18, f.y + f.h * 0.38, f.x + f.w * 0.06, cx + f.w * 0.1, baseY, c.accent)
		P.triangle(cv, cx + f.w * 0.16, f.y + f.h * 0.3, cx - f.w * 0.1, f.x + f.w * 0.94, baseY, ink)
		for i = 0, 1 do
			local y = baseY + f.h * (0.06 + i * 0.08)
			P.rect(cv, cx - f.w * (0.28 - i * 0.08), y, f.w * (0.56 - i * 0.16), f.h * 0.035, ink, { pill = true })
		end
	elseif kind == "pine" then
		pine(cv, cx, f.y + f.h * 0.36, f.h * 0.42, ink)
	elseif kind == "waves" then
		for i = 0, 1 do
			local y = f.y + f.h * (0.72 + i * 0.1)
			P.rect(cv, cx - f.w * (0.3 - i * 0.08), y, f.w * (0.6 - i * 0.16), f.h * 0.035, ink, { pill = true })
		end
	elseif kind == "roundel" then
		local cy = f.y + f.h * 0.435
		P.circle(cv, cx, cy, f.w * 0.21, c.main)
		P.ring(cv, cx, cy, f.w * 0.21, f.w * 0.035, c.accent)
	end
end

local function ribbon(cv: P.Canvas, b: Box, text: string, color: Color3, ink: Color3, ctx: P.Ctx, prism: boolean)
	local tab = b.h * 0.8
	local dark = Colors.darken(color, 0.3)
	P.rect(cv, b.x, b.y + b.h * 0.35, tab, b.h * 0.85, dark)
	P.rect(cv, b.x + b.w - tab, b.y + b.h * 0.35, tab, b.h * 0.85, dark)
	local opts: P.Opts = { radius = b.h * 0.12 }
	if prism then
		opts.colors = Colors.PRISM
	end
	P.rect(cv, b.x + tab * 0.55, b.y, b.w - tab * 1.1, b.h, color, opts)
	if not ctx.simple then
		P.text(cv, string.upper(text), b.x + tab, b.y + b.h * 0.2, b.w - tab * 2, b.h * 0.6, ink, {
			font = F.Merriweather,
			weight = Enum.FontWeight.Bold,
		})
	end
end

---------------------------------------------------------------------------------------------------
-- Crest
---------------------------------------------------------------------------------------------------
local function drawCrest(def: Def, cv: P.Canvas, c: { [string]: Color3 }, ctx: P.Ctx)
	local rank = RANK[def.rarity] or 1
	local prism = rank >= 6 and not ctx.tinted
	local outer: Box
	local ribbonBox: Box? = nil
	if rank >= 6 then
		outer = { x = 26, y = 14, w = 48, h = 62 }
		ribbonBox = { x = 13, y = 78, w = 74, h = 12 }
	elseif rank == 5 then
		outer = { x = 27, y = 8, w = 46, h = 66 }
		ribbonBox = { x = 13, y = 78, w = 74, h = 12 }
	elseif rank == 4 then
		outer = { x = 17, y = 2, w = 66, h = 84 }
		ribbonBox = { x = 9, y = 76, w = 82, h = 14 }
	else
		outer = { x = 14, y = 3, w = 72, h = 94 }
	end

	-- Behind the shield: the laurel (Legendary+).
	if rank >= 5 then
		local leaf = if ctx.tinted then c.tier else GOLD
		P.laurel(cv, 50, 47, 40, 205, 330, 5, 11, leaf)
		P.laurel(cv, 50, 47, 40, 155, 30, 5, 11, leaf)
	end

	-- Trim (rarity), then the field.
	local trim = math.max(2.6, outer.w * 0.06)
	if prism then
		local step = trim / 3
		shield(cv, outer, Colors.PRISM[1])
		shield(cv, inset(outer, step), Colors.PRISM[3])
		shield(cv, inset(outer, step * 2), Colors.PRISM[5])
	else
		shield(cv, outer, c.tier)
	end
	local field = inset(outer, trim)
	shield(cv, field, c.main)
	ordinary(cv, def.ordinary, field, c.accent)
	if def.charge then
		charge(cv, def.charge, field, c)
	end

	local tb = def.text or { 0.12, 0.2, 0.76, 0.4 }
	local ink = if def.ink == "main" then c.main elseif def.ink == "accent" then c.accent else c.counter
	P.text(
		cv,
		def.initials,
		field.x + field.w * tb[1],
		field.y + field.h * tb[2],
		field.w * tb[3],
		field.h * tb[4],
		ink,
		{
			font = def.font or F.Merriweather,
			weight = Enum.FontWeight.Bold,
		}
	)

	if ribbonBox then
		local rc = if rank >= 5 and not ctx.tinted then GOLD else c.tier
		ribbon(cv, ribbonBox, def.short, rc, if prism then hex("#2A1035") else c.counter, ctx, prism)
	end
	-- A crown of three stars over the Mythic crest.
	if rank >= 6 then
		local colors = if ctx.tinted then { c.tier, c.tier, c.tier } else { Colors.PRISM[1], GOLD, Colors.PRISM[3] }
		P.star(cv, 38, 9, 4.2, colors[1])
		P.star(cv, 50, 6.5, 5.4, colors[2])
		P.star(cv, 62, 9, 4.2, colors[3])
	end
end

local function spec(def: Def): P.Spec
	return {
		id = def.id,
		kind = "school",
		name = def.name,
		rarity = def.rarity,
		initials = def.initials,
		keepColors = true,
		colors = {
			main = hex(def.main),
			accent = hex(def.accent),
			counter = hex(def.counter or "#FFFFFF"),
		},
		draw = function(cv, c, ctx)
			drawCrest(def, cv, c, ctx)
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- The schools (contracts §16)
---------------------------------------------------------------------------------------------------
local DEFS: { Def } = {
	-- Common
	{
		id = "eastbridge_state",
		name = "Eastbridge State",
		short = "Eastbridge",
		rarity = "common",
		initials = "ES",
		main = "#6E1F2B",
		accent = "#D4A537",
		ordinary = "chevron",
		text = { 0.12, 0.1, 0.76, 0.3 },
	},
	{
		id = "coastal_cc",
		name = "Coastal Community College",
		short = "Coastal",
		rarity = "common",
		initials = "CC",
		main = "#13616B",
		accent = "#E9D8A6",
		ordinary = "base",
		charge = "waves",
		ink = "counter",
		text = { 0.12, 0.16, 0.76, 0.38 },
	},
	{
		id = "midvale",
		name = "Midvale University",
		short = "Midvale",
		rarity = "common",
		initials = "M",
		main = "#2F5D3A",
		accent = "#5E8F68",
		ordinary = "perpale",
		text = { 0.15, 0.18, 0.7, 0.44 },
	},
	{
		id = "riverbend",
		name = "Riverbend College",
		short = "Riverbend",
		rarity = "common",
		initials = "RC",
		main = "#1F4E79",
		accent = "#8EC5E8",
		ordinary = "fess",
		text = { 0.12, 0.06, 0.76, 0.32 },
	},
	{
		id = "pinecrest_state",
		name = "Pinecrest State",
		short = "Pinecrest",
		rarity = "common",
		initials = "PS",
		main = "#234F3A",
		accent = "#C9B37E",
		ordinary = "chief",
		charge = "pine",
		ink = "main",
		text = { 0.2, 0.04, 0.6, 0.22 },
	},
	{
		id = "union_valley_tech",
		name = "Union Valley Tech",
		short = "Union Valley",
		rarity = "common",
		initials = "UV",
		main = "#3E4A59",
		accent = "#E07A2F",
		ordinary = "none",
		charge = "gear",
		text = { 0.27, 0.31, 0.46, 0.18 },
	},
	-- Uncommon
	{
		id = "lakeshore",
		name = "Lakeshore University",
		short = "Lakeshore",
		rarity = "uncommon",
		initials = "L",
		main = "#1D5C8C",
		accent = "#5FA8D3",
		ordinary = "base",
		charge = "waves",
		text = { 0.15, 0.14, 0.7, 0.46 },
	},
	{
		id = "granite_tech",
		name = "Granite Institute of Technology",
		short = "Granite Tech",
		rarity = "uncommon",
		initials = "GT",
		main = "#3F444A",
		accent = "#8E979F",
		ordinary = "quarterly",
		text = { 0.12, 0.24, 0.76, 0.34 },
	},
	{
		id = "harborview",
		name = "Harborview College",
		short = "Harborview",
		rarity = "uncommon",
		initials = "HC",
		main = "#14365E",
		accent = "#E3E7EC",
		ordinary = "chief",
		charge = "anchor",
		ink = "main",
		text = { 0.2, 0.04, 0.6, 0.22 },
	},
	-- Rare
	{
		id = "northfield",
		name = "Northfield University",
		short = "Northfield",
		rarity = "rare",
		initials = "N",
		main = "#1B2F5E",
		accent = "#F2F2F2",
		ordinary = "chief",
		charge = "stars",
		text = { 0.15, 0.34, 0.7, 0.42 },
	},
	{
		id = "ridgemont",
		name = "Ridgemont University",
		short = "Ridgemont",
		rarity = "rare",
		initials = "R",
		main = "#3C2F5C",
		accent = "#9C8FC4",
		ordinary = "none",
		charge = "peaks",
		text = { 0.2, 0.06, 0.6, 0.32 },
	},
	-- Epic
	{
		id = "kingsbridge",
		name = "Kingsbridge University",
		short = "Kingsbridge",
		rarity = "epic",
		initials = "K",
		main = "#8C1C2B",
		accent = "#E8C25A",
		ordinary = "none",
		charge = "crown",
		text = { 0.18, 0.4, 0.64, 0.44 },
	},
	{
		id = "ashworth",
		name = "Ashworth College",
		short = "Ashworth",
		rarity = "epic",
		initials = "A",
		main = "#1E5A5A",
		accent = "#E7D8B0",
		ordinary = "cross",
		charge = "roundel",
		text = { 0.32, 0.31, 0.36, 0.25 },
	},
	-- Legendary
	{
		id = "whartonia",
		name = "Whartonia School of Business",
		short = "Whartonia",
		rarity = "legendary",
		initials = "W",
		main = "#0B2545",
		accent = "#A61C2E",
		ordinary = "perpale",
		text = { 0.1, 0.16, 0.8, 0.46 },
	},
	{
		id = "stanfjord",
		name = "Stanfjord University",
		short = "Stanfjord",
		rarity = "legendary",
		initials = "S",
		main = "#8C1515",
		accent = "#D8C9A8",
		ordinary = "none",
		charge = "fjord",
		text = { 0.2, 0.03, 0.6, 0.3 },
	},
	-- Mythic
	{
		id = "harvale",
		name = "Harvale University",
		short = "Harvale",
		rarity = "mythic",
		initials = "H",
		main = "#A51C30",
		accent = "#F4E6C8",
		ordinary = "none",
		charge = "books",
		ink = "accent",
		text = { 0.3, 0.33, 0.4, 0.22 },
	},
}

local Schools = {}

Schools.list = {} :: { P.Spec }
for _, def in DEFS do
	table.insert(Schools.list, spec(def))
end

-- A crest for a school with no designed entry: colours and ordinary from a stable hash of its id.
local GENERIC_COLORS = {
	{ "#5A1E2C", "#D9B45A" },
	{ "#1E3F66", "#9CC3E6" },
	{ "#24543C", "#C9B37E" },
	{ "#3D2F5B", "#C2B4E2" },
	{ "#4A3A26", "#D8B878" },
	{ "#1F4F4F", "#E3D7B4" },
	{ "#3A3F47", "#E07A2F" },
}
local GENERIC_ORDINARIES = { "chevron", "fess", "pale", "perpale", "chief", "quarterly", "cross" }

local function initialsOf(name: string): string
	local letters = {}
	for word in string.gmatch(name, "[%a']+") do
		local lw = string.lower(word)
		if lw ~= "of" and lw ~= "the" and lw ~= "and" and lw ~= "university" and lw ~= "college" then
			table.insert(letters, string.upper(string.sub(word, 1, 1)))
		end
		if #letters >= 2 then
			break
		end
	end
	return if #letters > 0 then table.concat(letters) else "U"
end

function Schools.generic(id: string, name: string, rarity: string): P.Spec
	local h = Hash.u32("logo-school", id)
	local pair = GENERIC_COLORS[h % #GENERIC_COLORS + 1]
	local ord = GENERIC_ORDINARIES[(h // 11) % #GENERIC_ORDINARIES + 1]
	local initials = initialsOf(name)
	local text: { number } = if ord == "chevron"
		then { 0.12, 0.1, 0.76, 0.3 }
		elseif ord == "chief" then { 0.15, 0.36, 0.7, 0.4 }
		elseif ord == "fess" then { 0.12, 0.06, 0.76, 0.32 }
		else { 0.12, 0.2, 0.76, 0.4 }
	return spec({
		id = id,
		name = name,
		short = string.match(name, "^[%a']+") or name,
		rarity = if RANK[rarity] then rarity else "common",
		initials = initials,
		main = pair[1],
		accent = pair[2],
		ordinary = ord,
		text = text,
	})
end

return Schools
