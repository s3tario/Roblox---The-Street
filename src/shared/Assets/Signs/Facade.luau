--!strict
-- Facade signage (all mount "wall": cf = bottom-centre of the sign's back face on the facade, LookVector
-- pointing out of the building; the sign extends up +Y and forward -Z).
--   buildingName  brass | neon | stone | paint | lightbox lettering for building and shop names
--   plaque        engraved brass plaque on a walnut backing
--   neon          glowing tube sign: Neon border tubes and corners plus glowing SurfaceGui text

local Base = require(script.Parent.Base)
local Common = require(script.Parent.Parent.Props.Common)
local Shapes = require(script.Parent.Parent.Props.Shapes)
local Gui = require(script.Parent.Parent.Props.Gui)
local Words = require(script.Parent.Parent.Props.Words)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)

type Ctx = Common.Ctx
type Opts = Base.Opts

local P = Common.P
local V = Vector3.new
local M = Enum.Material
local S = Kit.Palette.street
local C = Kit.Palette.campus
local shade = Kit.shade
local hex = Kit.hex

local Facade = {}

Facade.STYLES = { "brass", "neon", "stone", "paint", "lightbox" }

local FONTS: { [string]: Enum.Font } = {
	serif = Enum.Font.Bodoni,
	sans = Enum.Font.GothamBold,
	slab = Enum.Font.Merriweather,
	type = Enum.Font.SpecialElite,
	tech = Enum.Font.Michroma,
	script = Enum.Font.Fondamento,
	fun = Enum.Font.Bangers,
}
local FONT_NAMES = { "serif", "sans", "slab", "type", "tech", "script", "fun" }

local function fontFor(c: Ctx, default: string): Enum.Font
	return FONTS[c.pick("font", FONT_NAMES, default)]
end

-- Pixels per stud that keep a W-stud-wide canvas around 1600 px (SurfaceGui textures stay sharp).
local function ppsFor(w: number): number
	return math.clamp(1600 / math.max(w, 0.5), 6, 60)
end

-- Transparent carrier with one or two (shadowed) labels across it. Returns the main label.
local function letters(
	c: Ctx,
	lcf: CFrame,
	w: number,
	h: number,
	text: string,
	color: Color3,
	font: Enum.Font,
	o: { glow: boolean?, shadow: Color3?, stroke: Color3?, strokeT: number?, gradient: { Color3 }? }
): TextLabel
	local carrier = c.detail(lcf, V(w, h, 0.02), color)
	carrier.Transparency = 1
	carrier.CastShadow = false
	carrier.Name = "Letters"
	local gui = Gui.Core.surface(carrier, Enum.NormalId.Front, {
		glow = o.glow,
		brightness = 1.6,
		pps = ppsFor(w),
		maxDistance = 0,
		name = "Lettering",
	})
	if o.shadow then
		Gui.Core.label(gui, text, 0.006, 0.02, 1, 1, o.shadow, {
			font = font,
			align = Enum.TextXAlignment.Center,
			transparency = 0.45,
			name = "Shadow",
		})
	end
	local label = Gui.Core.label(gui, text, 0, 0, 1, 1, color, {
		font = font,
		align = Enum.TextXAlignment.Center,
		stroke = o.stroke,
		strokeT = o.strokeT,
		strokeW = if o.stroke then 2.5 else nil,
		name = "Text",
	})
	if o.gradient then
		Gui.Core.gradient(label, o.gradient[1], o.gradient[2], 90)
	end
	return label
end

-- Neon tube rectangle (4 tubes + 4 corner balls) plus glowing text, on a dark backer. Returns the backer.
local function neonPanel(
	c: Ctx,
	text: string,
	W: number,
	H: number,
	color: Color3,
	font: Enum.Font,
	lit: boolean,
	flicker: boolean
): Part
	local backer = c.part(P(0, H / 2, -0.06), V(W, H, 0.12), hex("#0C0D10"), M.SmoothPlastic)
	backer.Name = "Backer"
	local t = math.clamp(H * 0.05, 0.08, 0.3)
	local iw, ih = W - 0.3 - t, H - 0.3 - t
	local tube = if lit then color else shade(color, -0.55)
	local function tubeBar(lcf: CFrame, size: Vector3)
		local p = if lit then c.glow(lcf, size, tube, 0.05) else c.detail(lcf, size, tube, M.Glass)
		p.Name = "Tube"
		if flicker then
			p:SetAttribute("Flicker", true)
		end
	end
	for _, sy in { -1, 1 } do
		tubeBar(P(0, H / 2 + sy * ih / 2, -0.16 - t / 2), V(iw, t, t))
	end
	for _, sx in { -1, 1 } do
		tubeBar(P(sx * iw / 2, H / 2, -0.16 - t / 2), V(t, ih, t))
	end
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			local ball = Shapes.bulb(c, P(sx * iw / 2, H / 2 + sy * ih / 2, -0.16 - t / 2), t * 1.4, color, lit, 0.05)
			ball.Name = "Tube"
		end
	end
	letters(
		c,
		P(0, H / 2, -0.2 - t),
		W - 0.8 - t * 2,
		H - 0.7 - t * 2,
		text,
		if lit then shade(color, 0.35) else shade(color, -0.4),
		font,
		{
			glow = lit,
			stroke = if lit then color else nil,
			strokeT = 0.35,
		}
	)
	if lit then
		c.light(backer, "point", { Range = math.clamp(W * 0.8, 8, 30), Brightness = 1.1, Color = color })
		if flicker then
			backer:SetAttribute("Flicker", true)
		end
	end
	return backer
end

---------------------------------------------------------------------------------------------------
-- buildingName(parent, cf, {text, width, height, style, color, accent, font, lit})
--   style "brass" (default): raised gilt letters over a brass rule, optional uplights (lit)
--   "neon": tube-framed glowing name on a dark backer (lit default true)
--   "stone": engraved limestone tablet with a bevelled frame
--   "paint": hand-painted board (gritty campus shops), weathered
--   "lightbox": metal box sign with a glowing translucent face (lit default true)
-- width defaults to fit the text; height (0.6-20, default 2.4) is the letter band.
---------------------------------------------------------------------------------------------------
function Facade.buildingName(parent: Instance?, cf: CFrame, opts: Opts?): Model
	local model, c = Base.begin("buildingName", cf, opts)
	local text = c.str("text", Words.buildingDefault, 60)
	local style = c.pick("style", Facade.STYLES, "brass")
	local H = c.num("height", 2.4, 0.6, 20)
	local W = c.num("width", Base.fitWidth(text, H, 3, 120), 1, 160)
	model:SetAttribute("SignStyle", style)
	if style == "brass" then
		local gold = c.color("color", S.gold)
		letters(c, P(0, H / 2 + 0.2, -0.14), W, H, text, gold, fontFor(c, "serif"), {
			shadow = hex("#1A140A"),
			stroke = shade(gold, -0.45),
			strokeT = 0.2,
			gradient = { S.goldBright, shade(gold, -0.2) },
		})
		c.detail(P(0, 0.06, -0.05), V(W * 0.92, 0.08, 0.1), gold, M.Metal)
		if c.bool("lit", false) then
			for _, sx in { -1, 1 } do
				local fix = c.detail(P(sx * W * 0.3, 0.12, -0.5), V(0.35, 0.2, 0.35), S.black, M.Metal)
				c.light(
					fix,
					"spot",
					{ Face = Enum.NormalId.Top, Angle = 70, Range = H + 4, Brightness = 1.4, Color = S.warmLight }
				)
			end
		end
	elseif style == "neon" then
		local color = c.color("color", hex("#FF4F5E"))
		neonPanel(c, text, W + 0.8, H + 0.6, color, fontFor(c, "tech"), c.bool("lit", true), c.bool("flicker", false))
	elseif style == "stone" then
		local stone = c.color("color", S.limestone)
		local panel = c.part(P(0, H / 2 + 0.3, -0.2), V(W + 0.8, H + 0.6, 0.4), stone, M.Limestone)
		panel.Name = "Tablet"
		Shapes.frameRect(c, P(0, H / 2 + 0.3, -0.43), W + 0.4, H + 0.2, 0.15, 0.06, shade(stone, -0.12), M.Limestone)
		letters(
			c,
			P(0, H / 2 + 0.3, -0.41),
			W,
			H,
			string.upper(text),
			c.color("accent", shade(stone, -0.6)),
			fontFor(c, "serif"),
			{
				shadow = shade(stone, 0.3),
			}
		)
	elseif style == "paint" then
		local board = c.color("color", hex("#2E4A3A"))
		local ink = c.color("accent", C.paper)
		local bcf = P(0, H / 2 + 0.15, -0.08)
		local panel = c.part(bcf, V(W + 0.4, H + 0.3, 0.12), board, M.WoodPlanks)
		panel.Name = "Board"
		letters(c, bcf * P(0, 0, -0.07), W, H * 0.9, text, ink, fontFor(c, "type"), { shadow = shade(board, -0.5) })
		for _ = 1, 2 do
			c.detail(
				bcf
					* P(c.rng:range(-W / 2.5, W / 2.5), c.rng:range(-H / 3, H / 3), -0.065)
					* Common.R(0, 0, c.rng:range(-20, 20)),
				V(c.rng:range(0.4, 1.2), c.rng:range(0.2, 0.5), 0.01),
				shade(board, 0.18),
				M.WoodPlanks
			)
		end
		for _, sx in { -1, 1 } do
			c.detail(P(sx * W * 0.33, H + 0.45, -0.1), V(0.15, 0.3, 0.2), C.rust, M.CorrodedMetal)
		end
	else
		local lit = c.bool("lit", true)
		local face = c.color("color", S.white)
		local ink = c.color("accent", S.navy)
		c.part(P(0, H / 2 + 0.2, -0.4), V(W + 0.4, H + 0.4, 0.8), hex("#1E2126"), M.Metal)
		local panel = c.detail(P(0, H / 2 + 0.2, -0.82), V(W, H, 0.04), face, M.SmoothPlastic)
		panel.Name = "Face"
		local gui = Gui.Core.surface(
			panel,
			Enum.NormalId.Front,
			{ glow = lit, brightness = 1.2, pps = ppsFor(W), name = "Lightbox" }
		)
		Gui.Core.bg(gui, face)
		Gui.Core.label(
			gui,
			text,
			0.03,
			0.08,
			0.94,
			0.84,
			ink,
			{ font = fontFor(c, "sans"), align = Enum.TextXAlignment.Center }
		)
		if lit then
			c.light(panel, "surface", { Face = Enum.NormalId.Front, Range = 8, Brightness = 0.9, Color = S.warmLight })
		end
	end
	return Base.finish(model, parent, "wall")
end

---------------------------------------------------------------------------------------------------
-- plaque(parent, cf, {title, text, width, height, color, accent}): engraved brass plate on walnut
---------------------------------------------------------------------------------------------------
function Facade.plaque(parent: Instance?, cf: CFrame, opts: Opts?): Model
	local model, c = Base.begin("plaque", cf, opts)
	local W = c.num("width", 2.4, 0.8, 10)
	local H = c.num("height", 1.6, 0.5, 8)
	local brass = c.color("color", S.brass)
	local wood = c.color("accent", S.walnut)
	local title = c.str("title", Words.plaqueTitle, 40)
	local body = c.str("text", Words.plaqueBody, 240)
	local mid = (H + 0.3) / 2
	c.part(P(0, mid, -0.05), V(W + 0.3, H + 0.3, 0.1), wood, M.Wood)
	local plate = c.detail(P(0, mid, -0.13), V(W, H, 0.06), brass, M.Metal)
	plate.Name = "Plate"
	local gui = Gui.Core.surface(
		plate,
		Enum.NormalId.Front,
		{ pps = math.clamp(500 / W, 30, 160), maxDistance = 60, name = "Engraving" }
	)
	local ink = shade(brass, -0.7)
	Gui.Core.label(
		gui,
		title,
		0.08,
		0.08,
		0.84,
		0.26,
		ink,
		{ font = Enum.Font.Bodoni, align = Enum.TextXAlignment.Center }
	)
	Gui.Core.frame(gui, 0.2, 0.37, 0.6, 0.012, ink)
	Gui.Core.label(
		gui,
		body,
		0.08,
		0.44,
		0.84,
		0.46,
		ink,
		{ font = Enum.Font.Garamond, align = Enum.TextXAlignment.Center }
	)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			c.dcylZ(P(sx * (W / 2 - 0.12), mid + sy * (H / 2 - 0.12), -0.17), 0.03, 0.09, shade(brass, -0.3), M.Metal)
		end
	end
	return Base.finish(model, parent, "wall")
end

---------------------------------------------------------------------------------------------------
-- neon(parent, cf, {text, color, width, height, font, lit, flicker}): bar/diner style glowing sign.
-- Tube parts are named "Tube"; flicker = true marks them (and the backer light) with Flicker attributes.
---------------------------------------------------------------------------------------------------
function Facade.neon(parent: Instance?, cf: CFrame, opts: Opts?): Model
	local model, c = Base.begin("neon", cf, opts)
	local text = c.str("text", Words.neonDefault, 40)
	local H = c.num("height", 2.2, 0.8, 12)
	local W = c.num("width", Base.fitWidth(text, H * 0.6, 3, 40), 2, 60)
	local color = c.color("color", C.neonSign)
	neonPanel(c, text, W, H, color, fontFor(c, "fun"), c.bool("lit", true), c.bool("flicker", false))
	return Base.finish(model, parent, "wall")
end

return Facade
