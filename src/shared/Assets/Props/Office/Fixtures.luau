--!strict
-- Office fixtures: water cooler, coffee station, wall art, wall clock, deal toy, glass partition,
-- reception desk, elevator bank and security speed gates.
-- Wall props (mount "wall"): cf = bottom-centre of the BACK face, on the wall surface; they extend up and
-- forward (-Z) into the room.

local Common = require(script.Parent.Parent.Common)
local Shapes = require(script.Parent.Parent.Shapes)
local Gui = require(script.Parent.Parent.Gui)
local Words = require(script.Parent.Parent.Words)
local Kit = require(script.Parent.Parent.Parent.Parent.Build.Kit)

type Ctx = Common.Ctx
type Def = Common.Def

local P, R = Common.P, Common.R
local V = Vector3.new
local M = Enum.Material
local col = Common.col
local S = Kit.Palette.street
local shade = Kit.shade
local hex = Kit.hex

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

---------------------------------------------------------------------------------------------------
-- water_cooler
---------------------------------------------------------------------------------------------------
add({
	id = "water_cooler",
	category = "office",
	footprint = V(1.5, 4.85, 1.45),
	maxParts = 10,
	tags = { "appliance", "break_room" },
	build = function(c: Ctx)
		local body = c.color("color", col.plasticWhite)
		c.part(P(0, 1.5, 0), V(1.3, 3.0, 1.3), body, M.SmoothPlastic)
		c.detail(P(0, 1.95, -0.62), V(0.9, 0.9, 0.08), shade(body, -0.4), M.SmoothPlastic)
		c.detail(P(-0.22, 2.2, -0.7), V(0.14, 0.18, 0.14), hex("#C8312F"), M.SmoothPlastic)
		c.detail(P(0.22, 2.2, -0.7), V(0.14, 0.18, 0.14), hex("#2F6FC8"), M.SmoothPlastic)
		c.detail(P(0, 1.56, -0.72), V(0.8, 0.06, 0.3), col.plasticGrey, M.DiamondPlate)
		c.dcyl(P(0, 3.06, 0), 0.12, 0.75, shade(body, -0.1), M.SmoothPlastic)
		local bottle = c.dcyl(P(0, 3.12 + 0.85, 0), 1.7, 1.15, hex("#9CC9EE"), M.Glass)
		bottle.Transparency = 0.5
		local water = c.dcyl(P(0, 3.12 + 0.6, 0), 1.2, 1.0, hex("#4C9AD6"), M.Glass)
		water.Transparency = 0.35
		c.dcyl(P(0.72, 2.3, 0), 0.9, 0.22, col.plasticWhite, M.SmoothPlastic)
		c.use(V(0, 2.2, -1))
	end,
})

---------------------------------------------------------------------------------------------------
-- coffee_machine: a self-contained coffee station (walnut cabinet, granite top, espresso machine)
---------------------------------------------------------------------------------------------------
add({
	id = "coffee_machine",
	category = "office",
	footprint = V(3.1, 5.35, 2.1),
	maxParts = 20,
	tags = { "appliance", "break_room" },
	surface = 3.15,
	build = function(c: Ctx)
		local cab = c.color("color", S.walnut)
		local steel = S.steelBrushed
		c.part(P(0, 1.55, 0), V(3, 2.9, 2), cab, M.Wood)
		c.detail(P(0, 0.05, 0.05), V(2.9, 0.1, 1.8), col.frameDark, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 0.74, 1.55, -1.02), V(1.42, 2.7, 0.04), shade(cab, -0.08), M.Wood)
			c.detail(P(sx * 0.12, 2.3, -1.07), V(0.05, 0.5, 0.06), col.chrome, M.Metal)
		end
		c.part(P(0, 3.075, 0), V(3.1, 0.15, 2.1), c.color("accent", S.granite), M.Granite)
		c.part(P(-0.3, 4.05, 0.2), V(1.5, 1.8, 1.3), col.plasticBlack, M.SmoothPlastic)
		c.detail(P(-0.3, 4.4, -0.47), V(1.3, 0.75, 0.04), steel, M.Metal)
		c.glow(P(-0.3, 4.55, -0.5), V(0.5, 0.2, 0.02), hex("#7FD1FF"), 0.15)
		c.detail(P(-0.3, 3.85, -0.35), V(0.4, 0.2, 0.3), steel, M.Metal)
		c.detail(P(-0.3, 3.19, -0.42), V(0.9, 0.08, 0.4), col.plasticGrey, M.DiamondPlate)
		c.dcyl(P(-0.3, 3.4, -0.4), 0.34, 0.26, col.ceramicWhite, M.SmoothPlastic)
		local hopper = c.dcyl(P(-0.3, 5.1, 0.35), 0.3, 0.7, hex("#6B4A2E"), M.Glass)
		hopper.Transparency = 0.25
		c.dcyl(P(-0.3, 5.28, 0.35), 0.06, 0.74, col.plasticBlack, M.SmoothPlastic)
		c.dcyl(P(0.9, 3.55, 0.1), 0.8, 0.3, col.paper, M.SmoothPlastic)
		c.detail(P(0.95, 3.25, -0.55), V(0.5, 0.2, 0.3), steel, M.Metal)
		c.use(V(-0.3, 4, -1.2))
	end,
})

---------------------------------------------------------------------------------------------------
-- wall_art: framed abstract painting. opts.variant 1-8 (painting style), opts.width/height,
-- opts.color (frame), opts.lit (brass picture light)
---------------------------------------------------------------------------------------------------
local FRAMES: { { any } } = {
	{ S.gold, M.Metal },
	{ col.plasticBlack, M.SmoothPlastic },
	{ S.walnut, M.Wood },
	{ S.white, M.SmoothPlastic },
}

add({
	id = "wall_art",
	category = "office",
	footprint = V(5, 3.5, 0.26),
	maxParts = 10,
	tags = { "art", "wall_art", "wall" },
	mount = "wall",
	build = function(c: Ctx)
		local W = c.num("width", 5, 1.5, 14)
		local Hh = c.num("height", 3.5, 1.5, 10)
		local variant = c.int("variant", c.rng:int(1, 8), 1, 8)
		local fr = c.rng:pick(FRAMES)
		local frameC = c.color("color", fr[1] :: Color3)
		local frameM = fr[2] :: Enum.Material
		local fw = math.clamp(math.min(W, Hh) * 0.07, 0.12, 0.35)
		local iw, ih = W - fw * 2, Hh - fw * 2
		c.detail(P(0, Hh / 2, -0.08), V(iw, ih, 0.1), hex("#EDE6D6"), M.Fabric)
		local canvas = c.detail(P(0, Hh / 2, -0.15), V(iw - 0.3, ih - 0.3, 0.04), Color3.new(1, 1, 1))
		canvas.Name = "Canvas"
		local gui, gw, gh = Gui.Core.surface(canvas, Enum.NormalId.Front, { pps = 30, maxDistance = 120 })
		Gui.Art.painting(gui, gw, gh, variant, c.rng)
		Shapes.frameRect(c, P(0, Hh / 2, -0.12), iw, ih, fw, 0.24, frameC, frameM)
		if c.bool("lit", false) then
			local brass = c.color("accent", S.brass)
			c.detail(P(0, Hh + 0.1, -0.2), V(0.1, 0.1, 0.4), brass, M.Metal)
			c.dcylX(P(0, Hh + 0.12, -0.45), W * 0.5, 0.18, brass, M.Metal)
			local glow = c.glow(P(0, Hh + 0.04, -0.45), V(W * 0.45, 0.03, 0.1), col.warmBulb, 0.1)
			c.light(glow, "spot", { Face = Enum.NormalId.Bottom, Angle = 90, Range = Hh + 3, Brightness = 1.2 })
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- wall_clock: round clock. The dial part carries tag "WallClock" with Frames "HourHand"/"MinuteHand"
-- (rotate them about the centre at runtime). opts.hour / opts.minute set the baked time.
---------------------------------------------------------------------------------------------------
add({
	id = "wall_clock",
	category = "office",
	footprint = V(2.2, 2.2, 0.23),
	maxParts = 4,
	tags = { "clock", "wall_art", "wall" },
	mount = "wall",
	build = function(c: Ctx)
		local d = 2.2
		local rim = c.color("color", col.plasticBlack)
		c.dcylZ(P(0, d / 2, -0.1), 0.2, d, rim, M.Metal)
		c.dcylZ(P(0, d / 2, -0.21), 0.02, d - 0.24, c.color("accent", col.ceramicWhite), M.SmoothPlastic)
		local dial = c.detail(P(0, d / 2, -0.224), V(d - 0.3, d - 0.3, 0.004), Color3.new(1, 1, 1))
		dial.Name = "Dial"
		dial.Transparency = 1
		local gui, gw, gh = Gui.Core.surface(dial, Enum.NormalId.Front, { pps = 70, maxDistance = 70 })
		Gui.Art.clockFace(
			gui,
			gw,
			gh,
			c.int("hour", c.rng:int(1, 12), 0, 23),
			c.int("minute", c.rng:int(0, 59), 0, 59),
			rim
		)
		c.tag(dial, "WallClock")
	end,
})

---------------------------------------------------------------------------------------------------
-- deal_toy: the IB trophy, a lucite tombstone engraved with the deal. opts.text (deal text),
-- opts.variant "tombstone" | "obelisk" | "cube", opts.color (base)
---------------------------------------------------------------------------------------------------
add({
	id = "deal_toy",
	category = "office",
	footprint = V(0.9, 1.2, 0.4),
	maxParts = 4,
	tags = { "trophy", "desk_item" },
	mount = "desk",
	build = function(c: Ctx)
		local style = c.pick("variant", { "tombstone", "obelisk", "cube" }, "tombstone")
		local text = c.str("text", c.rng:pick(Words.deals), 90)
		Shapes.tombstone(c, CFrame.identity, style, text, c.color("color", col.ebony))
	end,
})

---------------------------------------------------------------------------------------------------
-- glass_partition: frameless glass wall with aluminium channels and a frosted privacy band.
-- opts.width (2-40), opts.height (4-14). The glass collides.
---------------------------------------------------------------------------------------------------
add({
	id = "glass_partition",
	category = "office",
	footprint = V(10, 8, 0.32),
	maxParts = 7,
	tags = { "partition", "glass", "structure" },
	build = function(c: Ctx)
		local W = c.num("width", 10, 2, 40)
		local Hh = c.num("height", 8, 4, 14)
		local alu = c.color("accent", col.aluminum)
		c.part(P(0, 0.15, 0), V(W, 0.3, 0.3), alu, M.Metal)
		c.detail(P(0, Hh - 0.1, 0), V(W, 0.2, 0.3), alu, M.Metal)
		local glass = c.glass(P(0, Hh / 2, 0), V(W - 0.1, Hh - 0.5, 0.1), c.color("color", hex("#CFE3EA")), 0.78, true)
		glass.Name = "Glass"
		local frost = c.detail(P(0, math.min(4, Hh - 1), 0), V(W - 0.3, 0.5, 0.11), Color3.new(1, 1, 1), M.Glass)
		frost.Transparency = 0.45
		for _, sx in { -1, 1 } do
			c.detail(P(sx * (W / 2 - 0.08), Hh / 2, 0), V(0.16, Hh, 0.32), alu, M.Metal)
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- reception_desk: marble-fronted reception counter with a walnut transaction ledge, brass band, gold
-- firm name (opts.text) and a lit monitor and orchid for the receptionist. Visitors stand at -Z.
-- opts.firmBrand = true tags the name plate FirmBrand + FirmColor (label "BrandText") for per-player re-skins.
---------------------------------------------------------------------------------------------------
add({
	id = "reception_desk",
	category = "office",
	footprint = V(12.2, 4.75, 3.6),
	maxParts = 24,
	tags = { "desk", "furniture", "lobby" },
	surface = 2.8,
	build = function(c: Ctx)
		local W, D = 12, 3.5
		local face = c.color("color", S.marble)
		local wood = c.color("accent", S.walnut)
		local brass = S.brass
		c.part(P(0, 0.15, -D / 2 + 0.3), V(W - 0.2, 0.3, 0.4), col.frameDark, M.SmoothPlastic)
		c.part(P(0, 0.3 + 1.7, -D / 2 + 0.2), V(W, 3.4, 0.4), face, M.Marble)
		c.part(P(0, 3.775, -D / 2 + 0.35), V(W + 0.2, 0.15, 0.9), wood, M.Wood)
		for _, sx in { -1, 1 } do
			c.part(P(sx * (W / 2 - 0.2), 1.4, 0.2), V(0.4, 2.8, D - 0.4), face, M.Marble)
		end
		c.part(P(0, 2.74, 0.35), V(W - 0.8, 0.12, 2.6), wood, M.Wood)
		c.detail(P(0, 3.2, -D / 2 - 0.01), V(W, 0.1, 0.02), brass, M.Metal)
		for _, x in { -4.9, -3.3, 3.3, 4.9 } do
			c.detail(P(x, 1.75, -D / 2 - 0.02), V(0.12, 2.6, 0.04), shade(face, -0.12), M.Marble)
		end
		local plate = c.detail(P(0, 2.0, -D / 2 - 0.03), V(5, 1.0, 0.06), S.navy, M.SmoothPlastic)
		plate.Name = "NamePlate"
		local name = c.sign(plate, c.str("text", Words.reception, 40), {
			font = Enum.Font.Bodoni,
			color = S.goldBright,
			pixelsPerStud = 40,
			padding = 0.12,
		})
		if c.bool("firmBrand", false) then
			-- contracts §11: each client re-skins FirmBrand signage with its own player's firm name/colour
			name.Name = "BrandText"
			c.tag(plate, "FirmBrand")
			c.tag(plate, "FirmColor")
		end
		c.sub("monitor_single", P(-2.5, 2.8, 0.15) * R(0, 180, 0), { screens = "email" })
		local vase = c.dcyl(P(3.8, 3.85 + 0.3, -D / 2 + 0.35), 0.6, 0.3, hex("#DCEBF0"), M.Glass)
		vase.Transparency = 0.4
		c.dcyl(P(3.8, 4.15 + 0.2, -D / 2 + 0.35), 0.4, 0.05, col.leaf, M.Grass)
		c.dball(P(3.8, 4.15 + 0.45, -D / 2 + 0.3), 0.3, hex("#F3E6F0"), M.SmoothPlastic)
		c.use(V(0, 4, -D / 2 - 0.8))
	end,
})

---------------------------------------------------------------------------------------------------
-- elevator_door: bank of opts.count (1-4, default 2) elevator doors set in brass frames on marble, with
-- glowing floor indicators (TextLabel "Indicator") and call buttons. Leaves are named "DoorL<i>"/"DoorR<i>".
---------------------------------------------------------------------------------------------------
add({
	id = "elevator_door",
	category = "office",
	footprint = V(13.4, 9.5, 0.55),
	maxParts = 44,
	tags = { "door", "structure", "lobby" },
	mount = "wall",
	scales = { count = 4 },
	build = function(c: Ctx)
		local n = c.int("count", 2, 1, 4)
		local pitch = 7
		local brass = c.color("accent", S.brass)
		local steel = c.color("color", S.steelBrushed)
		local marble = S.marble
		local amber = hex("#FFB547")
		local function bayX(i: number): number
			return (i - (n + 1) / 2) * pitch
		end
		for i = 1, n do
			local x = bayX(i)
			c.detail(P(x, 4.75, -0.03), V(6.4, 9.5, 0.06), marble, M.Marble)
			for _, sx in { -1, 1 } do
				local leaf = c.part(P(x + sx * 1.04, 3.8, -0.2), V(2.06, 7.6, 0.12), steel, M.Metal)
				leaf.Name = (if sx < 0 then "DoorL" else "DoorR") .. i
				c.detail(P(x + sx * 2.35, 4.05, -0.22), V(0.5, 8.1, 0.44), brass, M.Metal)
			end
			c.detail(P(x, 8.35, -0.22), V(5.2, 0.5, 0.44), brass, M.Metal)
			c.detail(P(x, 0.02, -0.3), V(4.4, 0.04, 0.5), steel, M.Metal)
			local ind = c.detail(P(x, 9.12, -0.1), V(1.6, 0.66, 0.14), col.plasticBlack, M.SmoothPlastic)
			ind.Name = "Indicator" .. i
			local gui = Gui.Core.surface(ind, Enum.NormalId.Front, { glow = true, pps = 60, maxDistance = 90 })
			local up = c.rng:chance(0.5)
			Gui.Core.label(
				gui,
				string.format("%s %d", if up then "▲" else "▼", c.rng:int(2, 48)),
				0.08,
				0.1,
				0.84,
				0.8,
				amber,
				{ font = Enum.Font.RobotoMono, align = Enum.TextXAlignment.Center, name = "Indicator" }
			)
		end
		local panels = math.max(1, n - 1)
		for k = 1, panels do
			local xm = if n == 1 then bayX(1) + pitch / 2 - 0.2 else (bayX(k) + bayX(k + 1)) / 2
			c.detail(P(xm, 4.0, -0.07), V(0.55, 1.1, 0.08), brass, M.Metal)
			c.glow(P(xm, 4.2, -0.115), V(0.2, 0.2, 0.02), amber, 0.2)
			c.glow(P(xm, 3.8, -0.115), V(0.2, 0.2, 0.02), Color3.new(1, 1, 1), 0.3)
		end
		c.use(V(0, 4, -1.5))
	end,
})

---------------------------------------------------------------------------------------------------
-- security_gate: lobby speed gates. opts.lanes (1-4, default 2): steel cabinets with lit strips and card
-- readers, glass wings (non-colliding "GateWing" parts; WorldService gates access, not physics).
---------------------------------------------------------------------------------------------------
add({
	id = "security_gate",
	category = "office",
	footprint = V(7.65, 3.25, 5.06),
	maxParts = 30,
	tags = { "structure", "lobby", "security" },
	scales = { lanes = 4 },
	build = function(c: Ctx)
		local lanes = c.int("lanes", 2, 1, 4)
		local cw, lw, L = 0.8, 2.6, 5
		local total = lanes * lw + (lanes + 1) * cw
		local steel = c.color("color", S.steelBrushed)
		local glowC = c.color("accent", hex("#3FD1E6"))
		for k = 0, lanes do
			local x = -total / 2 + cw / 2 + k * (lw + cw)
			c.part(P(x, 1.55, 0), V(cw, 3.1, L), steel, M.Metal)
			c.detail(P(x, 3.15, 0), V(cw + 0.06, 0.1, L + 0.06), S.black, M.Glass)
			c.glow(P(x, 2.9, 0), V(cw + 0.02, 0.06, L - 0.3), glowC, 0.2)
			c.glow(P(x, 3.21, -L / 2 + 0.6), V(0.5, 0.02, 0.5), hex("#2BD67B"), 0.3)
		end
		for k = 1, lanes do
			local x = -total / 2 + cw + lw / 2 + (k - 1) * (lw + cw)
			for _, sx in { -1, 1 } do
				local wing = c.glass(P(x + sx * 0.64, 2.0, 0), V(1.22, 1.6, 0.06), hex("#DDEFF5"), 0.5)
				wing.Name = "GateWing"
			end
		end
		c.use(V(0, 3, -L / 2 - 0.5))
	end,
})

return defs
