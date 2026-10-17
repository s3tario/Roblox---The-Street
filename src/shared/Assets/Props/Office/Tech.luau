--!strict
-- Office tech: monitors (glowing SurfaceGui screens with fictional charts, quotes, inboxes and decks),
-- keyboard and mouse, banker's desk lamp, printer, and the wall LED ticker board.
-- Desk items (mount "desk") go on a desk top: cf = point on the surface, screen facing the user (-Z).
--   opts.lit (default true for screens, false for the lamp), opts.screens = kind or list of kinds
--   ("chart" "candles" "quotes" "terminal" "email" "sheet" "deck" "news").

local Common = require(script.Parent.Parent.Common)
local Shapes = require(script.Parent.Parent.Shapes)
local Gui = require(script.Parent.Parent.Gui)
local Kit = require(script.Parent.Parent.Parent.Parent.Build.Kit)

type Ctx = Common.Ctx
type Def = Common.Def

local P, R = Common.P, Common.R
local V = Vector3.new
local M = Enum.Material
local col = Common.col
local S = Kit.Palette.street
local shade = Kit.shade

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

local OFFICE_MIX = { "email", "sheet", "deck", "chart", "quotes", "terminal", "news", "candles" }

local function stand(c: Ctx, barWidth: number?)
	c.detail(P(0, 0.03, 0), V(0.9, 0.06, 0.6), col.frameDark, M.Metal)
	c.detail(P(0, 0.5, 0.18), V(0.16, 0.9, 0.08), col.frameDark, M.Metal)
	if barWidth then
		c.detail(P(0, 1.0, 0.22), V(barWidth, 0.1, 0.08), col.frameDark, M.Metal)
	end
end

---------------------------------------------------------------------------------------------------
-- Monitors
---------------------------------------------------------------------------------------------------
add({
	id = "monitor_single",
	category = "office",
	footprint = V(2.4, 1.78, 0.6),
	maxParts = 6,
	tags = { "monitor", "screen", "desk_item" },
	mount = "desk",
	build = function(c: Ctx)
		local kinds = Shapes.screenKinds(c, 1, { c.rng:pick(OFFICE_MIX) })
		stand(c, nil)
		Shapes.display(c, P(0, 1.08, 0.08), 2.4, 1.4, kinds[1], c.bool("lit", true), c.rng)
		c.use(V(0, 1.1, -0.8))
	end,
})

add({
	id = "monitor_dual",
	category = "office",
	footprint = V(4.5, 1.7, 0.6),
	maxParts = 10,
	tags = { "monitor", "screen", "desk_item" },
	mount = "desk",
	build = function(c: Ctx)
		local kinds = Shapes.screenKinds(c, 2, c.rng:shuffle(OFFICE_MIX))
		local lit = c.bool("lit", true)
		stand(c, 2.6)
		Shapes.display(c, P(-1.14, 1.05, 0.02) * R(0, -8, 0), 2.2, 1.3, kinds[1], lit, c.rng)
		Shapes.display(c, P(1.14, 1.05, 0.02) * R(0, 8, 0), 2.2, 1.3, kinds[2], lit, c.rng)
		c.use(V(0, 1.1, -0.8))
	end,
})

add({
	id = "monitor_triple",
	category = "office",
	footprint = V(6.4, 1.7, 1.15),
	maxParts = 13,
	tags = { "monitor", "screen", "desk_item", "trading" },
	mount = "desk",
	build = function(c: Ctx)
		local kinds = Shapes.screenKinds(c, 3, c.rng:shuffle({ "chart", "candles", "quotes", "terminal", "news" }))
		local lit = c.bool("lit", true)
		local w, h, a = 2.2, 1.3, 22
		local half = w / 2 + 0.03
		local ox = half + math.cos(math.rad(a)) * w / 2
		local oz = -math.sin(math.rad(a)) * w / 2
		stand(c, 4.2)
		Shapes.display(c, P(0, 1.05, 0.06), w, h, kinds[2], lit, c.rng)
		Shapes.display(c, P(-ox, 1.05, 0.06 + oz) * R(0, -a, 0), w, h, kinds[1], lit, c.rng)
		Shapes.display(c, P(ox, 1.05, 0.06 + oz) * R(0, a, 0), w, h, kinds[3], lit, c.rng)
		c.use(V(0, 1.1, -0.8))
	end,
})

---------------------------------------------------------------------------------------------------
-- keyboard_mouse
---------------------------------------------------------------------------------------------------
add({
	id = "keyboard_mouse",
	category = "office",
	footprint = V(2.5, 0.2, 0.65),
	maxParts = 7,
	tags = { "desk_item", "computer" },
	mount = "desk",
	build = function(c: Ctx)
		local kb = c.color("color", col.plasticBlack)
		c.detail(P(-0.3, 0.035, 0), V(1.7, 0.07, 0.58), kb, M.SmoothPlastic)
		c.detail(P(-0.3, 0.085, 0.03) * R(3, 0, 0), V(1.6, 0.03, 0.46), shade(kb, 0.14), M.SmoothPlastic)
		c.detail(P(-0.3, 0.105, -0.15), V(0.72, 0.012, 0.09), shade(kb, 0.3), M.SmoothPlastic)
		c.detail(P(0.95, 0.01, 0), V(0.8, 0.02, 0.65), col.fabricCharcoal, M.Fabric)
		c.detail(P(0.95, 0.06, 0.03), V(0.22, 0.08, 0.32), kb, M.SmoothPlastic)
		c.dball(P(0.95, 0.1, -0.04), 0.18, kb, M.SmoothPlastic)
	end,
})

---------------------------------------------------------------------------------------------------
-- desk_lamp: brass banker's lamp with a green glass shade (opts.lit for a warm spot light)
---------------------------------------------------------------------------------------------------
add({
	id = "desk_lamp",
	category = "office",
	footprint = V(1.05, 1.22, 0.75),
	maxParts = 8,
	tags = { "lamp", "desk_item", "light" },
	mount = "desk",
	build = function(c: Ctx)
		local brass = c.color("accent", S.brass)
		local glassC = c.color("color", Kit.hex("#1F6B43"))
		local lit = c.bool("lit", false)
		c.dcyl(P(0, 0.05, 0), 0.1, 0.75, brass, M.Metal)
		c.dcyl(P(0, 0.13, 0), 0.06, 0.5, shade(brass, -0.2), M.Metal)
		c.dcyl(P(0, 0.52, 0.12), 0.78, 0.07, brass, M.Metal)
		c.detail(P(0, 0.93, 0.06), V(0.07, 0.07, 0.16), brass, M.Metal)
		local glass = c.dcylX(P(0, 1.03, 0), 1.05, 0.38, glassC, M.Glass)
		glass.Transparency = 0.1
		glass.Reflectance = 0.15
		-- opal glow strip just under the shade's lower lip (inside the green glass it would be hidden)
		local bulb = if lit
			then c.glow(P(0, 0.83, 0), V(0.86, 0.02, 0.22), col.warmBulb, 0.1)
			else c.detail(P(0, 0.83, 0), V(0.86, 0.02, 0.22), shade(col.warmBulb, -0.2), M.SmoothPlastic)
		c.detail(P(0.22, 0.74, -0.12), V(0.02, 0.24, 0.02), brass, M.Metal)
		if lit then
			c.light(bulb, "spot", {
				Face = Enum.NormalId.Bottom,
				Angle = 110,
				Range = 9,
				Brightness = 1.4,
				Color = col.warmBulb,
			})
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- printer: floor-standing multifunction printer with paper trays, feeder and a lit control panel
---------------------------------------------------------------------------------------------------
add({
	id = "printer",
	category = "office",
	footprint = V(2.4, 3.9, 2.1),
	maxParts = 16,
	tags = { "appliance", "office" },
	build = function(c: Ctx)
		local body = c.color("color", Kit.hex("#E3E4E6"))
		local dark = col.plasticGrey
		c.part(P(0, 0.9, 0), V(2.4, 1.8, 2.0), body, M.SmoothPlastic)
		for _, y in { 0.5, 1.25 } do
			c.detail(P(0, y, -1.02), V(2.2, 0.6, 0.04), shade(body, -0.06), M.SmoothPlastic)
			c.detail(P(0, y + 0.15, -1.06), V(0.8, 0.06, 0.05), dark, M.SmoothPlastic)
		end
		c.part(P(0, 2.55, 0.1), V(2.4, 1.5, 1.8), body, M.SmoothPlastic)
		c.detail(P(0, 2.35, -0.81), V(1.8, 0.25, 0.04), dark, M.SmoothPlastic)
		c.detail(P(0, 2.33, -0.95), V(1.4, 0.04, 0.3), col.paper, M.SmoothPlastic)
		c.part(P(0, 3.45, 0.1), V(2.4, 0.3, 1.8), shade(body, -0.04), M.SmoothPlastic)
		c.detail(P(-0.2, 3.72, 0.2), V(1.6, 0.24, 1.2), shade(body, -0.1), M.SmoothPlastic)
		c.detail(P(-0.2, 3.85, 0.2), V(1.3, 0.02, 0.9), col.paper, M.SmoothPlastic)
		c.detail(P(0.7, 3.62, -0.72) * R(-25, 0, 0), V(0.9, 0.08, 0.5), dark, M.SmoothPlastic)
		c.glow(P(0.7, 3.67, -0.74) * R(-25, 0, 0), V(0.45, 0.02, 0.28), Kit.hex("#4FA3E0"), 0.15)
		c.use(V(0, 3.2, -1.2))
	end,
})

---------------------------------------------------------------------------------------------------
-- ticker_board: wall-mounted LED stock ticker. The face part carries SurfaceGui "Ticker" with the
-- TextLabel "TickerText" (RichText) and the tag "TickerDisplay", so runtime code can update/scroll it.
-- opts.width (6-60), opts.height (1.2-6), opts.text (initial text).
---------------------------------------------------------------------------------------------------
add({
	id = "ticker_board",
	category = "office",
	footprint = V(16, 2.6, 0.56),
	maxParts = 6,
	tags = { "screen", "ticker", "wall" },
	mount = "wall",
	build = function(c: Ctx)
		local W = c.num("width", 16, 6, 60)
		local Hh = c.num("height", 2.6, 1.2, 6)
		c.part(P(0, Hh / 2, -0.25), V(W, Hh, 0.5), c.color("color", col.plasticBlack), M.Metal)
		local face = c.detail(P(0, Hh / 2, -0.51), V(W - 0.3, Hh - 0.4, 0.02), Kit.hex("#050608"), M.SmoothPlastic)
		face.Name = "TickerFace"
		local text = c.o.text
		Gui.Screens.ticker(face, c.rng, {
			pps = math.min(30, 1800 / W),
			text = if type(text) == "string" and #text > 0 then string.sub(text, 1, 400) else nil,
		})
		c.tag(face, "TickerDisplay")
		local brass = c.color("accent", S.brass)
		c.detail(P(0, 0.05, -0.53), V(W, 0.1, 0.06), brass, M.Metal)
		c.detail(P(0, Hh - 0.05, -0.53), V(W, 0.1, 0.06), brass, M.Metal)
		c.use(V(0, Hh / 2, -1.5))
	end,
})

return defs
