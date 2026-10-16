--!strict
-- Flat wall panels (mount "wall": cf = bottom-centre of the back face, LookVector out of the wall).
--   tickerBand  long LED stock ticker band (Metropolitan Exchange, trading floors)
--   poster      paper poster taped (or framed) to a wall

local Base = require(script.Parent.Base)
local Common = require(script.Parent.Parent.Props.Common)
local Shapes = require(script.Parent.Parent.Props.Shapes)
local Gui = require(script.Parent.Parent.Props.Gui)
local Words = require(script.Parent.Parent.Props.Words)
local Kit = require(script.Parent.Parent.Parent.Build.Kit)

type Opts = Base.Opts

local P, R = Common.P, Common.R
local V = Vector3.new
local M = Enum.Material
local S = Kit.Palette.street
local C = Kit.Palette.campus
local hex = Kit.hex

local Panels = {}

local SEGMENT = 32 -- max studs per LED segment (keeps each SurfaceGui canvas under ~1000 px wide)
local PPS = 30

---------------------------------------------------------------------------------------------------
-- tickerBand(parent, cf, {width, height, text, color, background, accent})
-- A housing with one or more LED face parts ("TickerFace", tag "TickerDisplay"). Each face carries
-- SurfaceGui "Ticker" > Frame "Viewport" > TextLabel "TickerText" (RichText, one line, fixed TextSize).
-- Wide bands are split into segments that show consecutive slices of ONE line: each TickerText is shifted
-- left by its attribute BaseOffsetPx, so a runtime scroller should set
--   Position.X.Offset = BaseOffsetPx - scrollPx   (same scrollPx for every segment)
-- Faces carry attributes TickerSegment (1..n), TickerSegments (n), SegmentOffset (studs from the left end)
-- and BandWidth (studs); the model carries BandWidth and TickerPps.
---------------------------------------------------------------------------------------------------
function Panels.tickerBand(parent: Instance?, cf: CFrame, opts: Opts?): Model
	local model, c = Base.begin("tickerBand", cf, opts)
	local W = c.num("width", 40, 4, 400)
	local H = c.num("height", 2.5, 0.8, 12)
	local housing = c.color("background", hex("#0F1114"))
	local trim = c.color("accent", S.brass)
	c.part(P(0, H / 2, -0.3), V(W, H, 0.6), housing, M.Metal)
	for _, sy in { -1, 1 } do
		c.detail(P(0, H / 2 + sy * (H / 2 - 0.05), -0.63), V(W, 0.1, 0.06), trim, M.Metal)
	end
	local n = math.max(1, math.ceil(W / SEGMENT))
	local segW = W / n
	local faceH = H - 0.3
	local textPx = math.floor(faceH * PPS * 0.84 * 0.66)
	local raw = c.o.text
	local line = if type(raw) == "string" and raw ~= "" then string.sub(raw, 1, 600) else Gui.Core.tickerLine(c.rng)
	-- repeat the line until it spans the band (approximate glyph width 0.62 em; RichText tags stripped)
	local plain = string.gsub(line, "<[^>]+>", "")
	local needChars = W * PPS / math.max(textPx * 0.62, 1)
	local reps = math.clamp(math.ceil(needChars / math.max(#plain, 1)), 1, 6)
	local parts = {}
	for _ = 1, reps do
		table.insert(parts, line)
	end
	local full = table.concat(parts, "     ")
	local color = c.o.color
	for k = 1, n do
		local face = c.detail(
			P(-W / 2 + segW * (k - 0.5), H / 2, -0.61),
			V(segW - 0.04, faceH, 0.02),
			hex("#050608"),
			M.SmoothPlastic
		)
		face.Name = "TickerFace"
		local label = Gui.Screens.ticker(face, c.rng, {
			pps = PPS,
			text = full,
			color = if typeof(color) == "Color3" then color :: Color3 else nil,
		})
		local offsetPx = -math.floor((k - 1) * segW * PPS + 0.5)
		label.Position = UDim2.new(0, offsetPx, 0, 0)
		label:SetAttribute("BaseOffsetPx", offsetPx)
		face:SetAttribute("TickerSegment", k)
		face:SetAttribute("TickerSegments", n)
		face:SetAttribute("SegmentOffset", (k - 1) * segW)
		face:SetAttribute("BandWidth", W)
		c.tag(face, "TickerDisplay")
	end
	model:SetAttribute("BandWidth", W)
	model:SetAttribute("TickerPps", PPS)
	return Base.finish(model, parent, "wall")
end

---------------------------------------------------------------------------------------------------
-- poster(parent, cf, {title, body, colors = {background, accent, text}, width, height, frame})
-- A slightly crooked paper poster held by tape, or (frame = true) a straight poster in a black frame.
---------------------------------------------------------------------------------------------------
function Panels.poster(parent: Instance?, cf: CFrame, opts: Opts?): Model
	local model, c = Base.begin("poster", cf, opts)
	local W = c.num("width", 2.4, 0.8, 12)
	local H = c.num("height", 3.4, 1, 16)
	local framed = c.bool("frame", false)
	local flyer = c.rng:pick(Words.flyers)
	local title = c.str("title", flyer[1], 40)
	local body = c.str("body", flyer[2], 160)
	local colors = c.colors("colors", {
		c.rng:pick({ C.paper, hex("#F2C230"), hex("#FFFFFF"), hex("#CFE3EA") }),
		c.rng:pick({ hex("#C8553D"), S.navy, hex("#2F8C8C"), hex("#1F4D3A") }),
		C.ink,
	})
	local tilt = if framed then 0 else c.rng:range(-2.5, 2.5)
	local sheetCf = P(0, H / 2 + 0.12, -0.04) * R(0, 0, tilt)
	local sheet = c.detail(sheetCf, V(W, H, 0.02), colors[1], M.SmoothPlastic)
	sheet.Name = "Poster"
	local gui = Gui.Core.surface(sheet, Enum.NormalId.Front, {
		pps = math.clamp(360 / math.max(W, H), 8, 80),
		maxDistance = 120,
		name = "Poster",
	})
	Gui.Art.poster(gui, title, body, colors, c.rng)
	if framed then
		Shapes.frameRect(c, sheetCf * P(0, 0, -0.01), W, H, 0.1, 0.06, S.black, M.SmoothPlastic)
	else
		local tape = hex("#E8E2C8")
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				if sy > 0 or c.rng:chance(0.6) then
					local strip = c.detail(
						sheetCf * P(sx * (W / 2 - 0.08), sy * (H / 2 - 0.08), -0.015) * R(0, 0, sx * sy * 40),
						V(0.5, 0.14, 0.01),
						tape,
						M.SmoothPlastic
					)
					strip.Transparency = 0.35
				end
			end
		end
	end
	return Base.finish(model, parent, "wall")
end

return Panels
