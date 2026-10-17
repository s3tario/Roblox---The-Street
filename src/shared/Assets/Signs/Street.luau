--!strict
-- Free-standing street signage (mount "floor": cf = centre of the base on the ground, LookVector = the
-- side most people read from).
--   streetName  green street-name blades on a pole (two crossing blades by default)
--   wayfinding  lit directory totem with arrows and a "you are here" map
--   billboard   rooftop billboard: legs, frame, fictional advert, catwalk, rail and lamps

local Base = require(script.Parent.Base)
local Common = require(script.Parent.Parent.Props.Common)
local Shapes = require(script.Parent.Parent.Props.Shapes)
local Gui = require(script.Parent.Parent.Props.Gui)
local Words = require(script.Parent.Parent.Props.Words)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)

type Ctx = Common.Ctx
type Opts = Base.Opts

local P, R = Common.P, Common.R
local V = Vector3.new
local M = Enum.Material
local S = Kit.Palette.street
local shade = Kit.shade
local hex = Kit.hex

local SignsStreet = {}

local BLADE_GREEN = hex("#1E6B3A")
local POLE_GREEN = hex("#1F3B2E")

-- Street-sign blade face: green field, white inset border, white Highway lettering.
local function bladeFace(part: BasePart, face: Enum.NormalId, text: string, field: Color3)
	local gui = Gui.Core.surface(part, face, { pps = 40, maxDistance = 200, name = "Blade" })
	Gui.Core.bg(gui, field)
	local inset = Gui.Core.frame(gui, 0.02, 0.1, 0.96, 0.8, field, 1)
	Gui.Core.stroke(inset, S.white, 2)
	Gui.Core.label(gui, text, 0.05, 0.14, 0.9, 0.72, S.white, {
		font = Enum.Font.Highway,
		align = Enum.TextXAlignment.Center,
	})
end

local function bladeWidth(text: string): number
	return math.clamp(#text * 0.42 + 1.2, 3.5, 8)
end

---------------------------------------------------------------------------------------------------
-- streetName(parent, cf, {text, text2, color, accent, height}): pole with a blade along X (text) and,
-- unless text2 == false, a second blade along Z (text2, default a different seeded street).
---------------------------------------------------------------------------------------------------
function SignsStreet.streetName(parent: Instance?, cf: CFrame, opts: Opts?): Model
	local model, c = Base.begin("streetName", cf, opts)
	local H = c.num("height", 10, 6, 16)
	local field = c.color("color", BLADE_GREEN)
	local pole = c.color("accent", POLE_GREEN)
	local names = c.rng:shuffle(Words.streets)
	local text = string.upper(c.str("text", names[1], 24))
	c.dcyl(P(0, 0.15, 0), 0.3, 0.7, pole, M.Metal)
	c.cyl(P(0, H / 2, 0), H, 0.28, pole, M.Metal)
	c.dball(P(0, H + 0.12, 0), 0.34, pole, M.Metal)
	local b1 = c.detail(P(0, H - 0.65, 0), V(bladeWidth(text), 0.9, 0.08), field, M.Metal)
	b1.Name = "Blade"
	bladeFace(b1, Enum.NormalId.Front, text, field)
	bladeFace(b1, Enum.NormalId.Back, text, field)
	c.detail(P(0, H - 0.65, 0), V(0.36, 1.0, 0.24), pole, M.Metal)
	if c.o.text2 ~= false then
		local text2 = string.upper(c.str("text2", names[2], 24))
		local b2 = c.detail(P(0, H - 1.7, 0) * R(0, 90, 0), V(bladeWidth(text2), 0.9, 0.08), field, M.Metal)
		b2.Name = "Blade"
		bladeFace(b2, Enum.NormalId.Front, text2, field)
		bladeFace(b2, Enum.NormalId.Back, text2, field)
		c.detail(P(0, H - 1.7, 0), V(0.24, 1.0, 0.36), pole, M.Metal)
	end
	return Base.finish(model, parent, "floor")
end

---------------------------------------------------------------------------------------------------
-- wayfinding(parent, cf, {title, entries = {string}, width, height, color, accent, lit}): navy directory
-- totem readable from both faces. Entries starting with "<", ">", "^" or "v" get a drawn arrow.
---------------------------------------------------------------------------------------------------
local ARROWS: { [string]: { number } } = {
	["<"] = { 0.8, 0.5, 0.2, 0.5 },
	[">"] = { 0.2, 0.5, 0.8, 0.5 },
	["^"] = { 0.5, 0.8, 0.5, 0.2 },
	["v"] = { 0.5, 0.2, 0.5, 0.8 },
}

local function entriesFrom(c: Ctx): { string }
	local raw = c.o.entries
	local out: { string } = {}
	if type(raw) == "table" then
		for _, e in raw :: { any } do
			if type(e) == "string" and e ~= "" then
				table.insert(out, string.sub(e, 1, 40))
			end
			if #out >= 8 then
				break
			end
		end
	end
	if #out == 0 then
		return table.clone(Words.wayfinding.entries)
	end
	return out
end

-- Wpx, Hpx = canvas size in pixels (from Gui.Core.surface).
local function directoryFace(
	gui: SurfaceGui,
	Wpx: number,
	Hpx: number,
	title: string,
	entries: { string },
	navy: Color3,
	gold: Color3
)
	Gui.Core.bg(gui, navy)
	Gui.Core.frame(gui, 0, 0, 1, 0.11, gold)
	Gui.Core.label(gui, title, 0.06, 0.015, 0.88, 0.08, navy, {
		font = Enum.Font.GothamBlack,
		align = Enum.TextXAlignment.Center,
	})
	local rowH = 0.6 / math.max(#entries, 1)
	-- one text size for every entry, so the list reads as a set instead of each line scaling itself to a
	-- different size. Sized so the longest entry fits on at most two wrapped lines of its row.
	local texts: { string } = {}
	local perLine = 1
	for i, e in entries do
		local text = if ARROWS[string.sub(e, 1, 1)] then string.gsub(string.sub(e, 2), "^%s+", "") else e
		texts[i] = text
		perLine = math.max(perLine, math.ceil(#text / 2) + 2)
		for word in string.gmatch(text, "%S+") do
			perLine = math.max(perLine, #word)
		end
	end
	local sideBox = rowH * 0.7 * Hpx / Wpx
	local textPx = math.floor(math.clamp(math.min(rowH * Hpx * 0.42, (0.85 - sideBox) * Wpx / (perLine * 0.7)), 6, 100))
	for i, e in entries do
		local y = 0.14 + (i - 1) * rowH
		local arrow = ARROWS[string.sub(e, 1, 1)]
		local text = texts[i]
		local side = rowH * 0.7 * Hpx -- square arrow box, in pixels
		local boxW = side / Wpx
		local box = Gui.Core.frame(gui, 0.05, y + rowH * 0.15, boxW, rowH * 0.7, gold)
		if arrow then
			Gui.Core.arrow(
				box,
				arrow[1] * side,
				arrow[2] * side,
				arrow[3] * side,
				arrow[4] * side,
				math.max(2, side * 0.08),
				navy
			)
		end
		Gui.Core.label(gui, text, 0.08 + boxW, y + rowH * 0.12, 0.85 - boxW, rowH * 0.76, S.white, {
			font = Enum.Font.GothamBold,
			scaled = false,
			size = textPx,
		})
		if i < #entries then
			Gui.Core.frame(gui, 0.05, y + rowH - 0.002, 0.9, 0.004, gold, 0.6)
		end
	end
	-- "you are here" map
	local map = Gui.Core.frame(gui, 0.08, 0.77, 0.84, 0.19, shade(navy, 0.12))
	for k = 1, 3 do
		Gui.Core.frame(map, k / 4, 0, 0.012, 1, shade(navy, 0.35))
		Gui.Core.frame(map, 0, k / 4, 1, 0.02, shade(navy, 0.35))
	end
	Gui.Core.frame(map, 0.4, 0.3, 0.2, 0.4, shade(gold, -0.2), 0.3)
	local dot = Gui.Core.frame(map, 0.47, 0.42, 0.06, 0.16, hex("#FF5A5F"))
	Gui.Core.round(dot, 0.5)
end

function SignsStreet.wayfinding(parent: Instance?, cf: CFrame, opts: Opts?): Model
	local model, c = Base.begin("wayfinding", cf, opts)
	local W = c.num("width", 3.2, 2, 8)
	local H = c.num("height", 7, 4, 12)
	local navy = c.color("color", S.navy)
	local gold = c.color("accent", S.gold)
	local lit = c.bool("lit", true)
	local title = string.upper(c.str("title", Words.wayfinding.title, 30))
	local entries = entriesFrom(c)
	c.part(P(0, 0.2, 0), V(W + 0.4, 0.4, 1.2), S.granite, M.Granite)
	local body = c.part(P(0, 0.4 + H / 2, 0), V(W, H, 0.5), navy, M.Metal)
	body.Name = "Directory"
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui, gw, gh = Gui.Core.surface(body, face, {
			glow = lit,
			brightness = 1.1,
			pps = math.clamp(600 / H, 20, 80),
			maxDistance = 120,
		})
		directoryFace(gui, gw, gh, title, entries, navy, gold)
	end
	c.detail(P(0, 0.4 + H + 0.08, 0), V(W + 0.2, 0.16, 0.6), gold, M.Metal)
	for _, sx in { -1, 1 } do
		c.detail(P(sx * (W / 2 + 0.03), 0.4 + H / 2, 0), V(0.06, H, 0.52), gold, M.Metal)
	end
	return Base.finish(model, parent, "floor")
end

---------------------------------------------------------------------------------------------------
-- billboard(parent, cf, {brand, slogan, width, height, legs, lit, color, accent}): rooftop billboard.
-- The advert faces -Z; legs (0-30 studs, default 6) lift it off the roof. Lamp lenses are tagged
-- "StreetLight" and carry SpotLights aimed at the advert when lit (default true).
---------------------------------------------------------------------------------------------------
function SignsStreet.billboard(parent: Instance?, cf: CFrame, opts: Opts?): Model
	local model, c = Base.begin("billboard", cf, opts)
	local W = c.num("width", 30, 8, 80)
	local H = c.num("height", 12, 4, 30)
	local legH = c.num("legs", 6, 0, 30)
	local lit = c.bool("lit", true)
	local steel = c.color("accent", hex("#4A4F55"))
	local frameC = c.color("color", hex("#2B2E33"))
	local ad = c.rng:pick(Words.ads)
	local brand = c.str("brand", ad[1], 30)
	local slogan = c.str("slogan", ad[2], 50)
	if legH >= 0.5 then
		local legs: { number } = if W > 40 then { -W / 3, 0, W / 3 } else { -W / 4, W / 4 }
		for _, x in legs do
			c.part(P(x, legH / 2, 0.6), V(0.8, legH, 0.8), steel, M.Metal)
			Shapes.strut(c, V(x, 0.3, 2.4), V(x, legH * 0.85, 0.9), 0.3, steel, M.Metal)
		end
	end
	local mid = legH + 0.3 + H / 2
	c.part(P(0, mid, 0.4), V(W + 0.6, H + 0.6, 0.6), frameC, M.Metal)
	local face = c.detail(P(0, mid, 0.06), V(W, H, 0.05), S.white, M.SmoothPlastic)
	face.Name = "Advert"
	local gui, gw, gh = Gui.Core.surface(face, Enum.NormalId.Front, {
		glow = false,
		pps = math.clamp(1600 / W, 8, 40),
		maxDistance = 0,
		name = "Advert",
	})
	Gui.Art.ad(gui, brand, slogan, c.rng, gw, gh)
	if legH >= 2 then
		c.part(P(0, legH + 0.08, -0.7), V(W, 0.15, 1.4), steel, M.DiamondPlate)
		Shapes.rail(
			c,
			V(-W / 2 + 0.2, legH + 0.15, -1.35),
			V(W / 2 - 0.2, legH + 0.15, -1.35),
			1.6,
			math.clamp(math.floor(W / 8) + 1, 2, 8),
			0.1,
			steel,
			M.Metal
		)
	end
	local n = math.clamp(math.floor(W / 8), 2, 8)
	local base = legH + 0.15
	for i = 1, n do
		local x = -W / 2 + W * (i - 0.5) / n
		Shapes.strut(c, V(x, base, -0.2), V(x, base + 0.9, -2.2), 0.14, steel, M.Metal)
		local head = P(x, base + 1.05, -2.35) * R(0, 180, 0) * R(50, 0, 0)
		c.detail(head, V(0.7, 0.4, 0.5), frameC, M.Metal)
		local lens = if lit
			then c.glow(head * P(0, 0, -0.26), V(0.6, 0.3, 0.02), S.warmLight, 0.1)
			else c.detail(head * P(0, 0, -0.26), V(0.6, 0.3, 0.02), shade(S.warmLight, -0.4), M.Glass)
		lens.Name = "Lamp"
		c.tag(lens, "StreetLight")
		if lit then
			c.light(
				lens,
				"spot",
				{ Face = Enum.NormalId.Front, Angle = 70, Range = H + 6, Brightness = 2, Color = S.warmLight }
			)
		end
	end
	return Base.finish(model, parent, "floor")
end

return SignsStreet
