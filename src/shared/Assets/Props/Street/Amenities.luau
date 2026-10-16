--!strict
-- Wall Street district sidewalk amenities (category "street"): parking meter, post clock, litter bin,
-- street tree in an iron grate and a fictional bank ATM. "Front" (-Z) faces the sidewalk user.

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

local IRON = hex("#1A1C1F")
local CLOCK_GREEN = hex("#1F3B2E")

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

---------------------------------------------------------------------------------------------------
-- parking_meter: twin-head meter on a steel post with lit displays
---------------------------------------------------------------------------------------------------
add({
	id = "parking_meter",
	category = "street",
	footprint = V(1.7, 4.9, 0.7),
	maxParts = 10,
	tags = { "street" },
	build = function(c: Ctx)
		local body = c.color("color", hex("#3A3D42"))
		local lit = c.bool("lit", true)
		c.dcyl(P(0, 0.06, 0), 0.12, 0.6, shade(body, -0.3), M.Metal)
		c.cyl(P(0, 1.9, 0), 3.7, 0.22, body, M.Metal)
		c.detail(P(0, 3.8, 0), V(1.0, 0.18, 0.4), body, M.Metal)
		for _, sx in { -1, 1 } do
			c.part(P(sx * 0.42, 4.3, 0), V(0.8, 1.0, 0.6), body, M.Metal)
			c.dball(P(sx * 0.42, 4.75, 0), 0.6, body, M.Metal)
			local screen = c.detail(P(sx * 0.42, 4.45, -0.31), V(0.5, 0.3, 0.02), hex("#0B1622"), M.Glass)
			c.sign(screen, string.format("%d:%02d", c.rng:int(0, 1), c.rng:int(0, 59)), {
				font = Enum.Font.Arcade,
				color = if lit then hex("#7CFC9A") else hex("#2A4A32"),
				glow = lit,
				pixelsPerStud = 80,
			})
		end
	end,
})

---------------------------------------------------------------------------------------------------
-- street_clock: ornate two-faced post clock (green and gold), the district's meeting point. Dials are
-- tagged "WallClock" with "HourHand"/"MinuteHand" frames, like wall_clock. opts.hour / opts.minute.
---------------------------------------------------------------------------------------------------
add({
	id = "street_clock",
	category = "street",
	footprint = V(2.6, 15.6, 2.6),
	maxParts = 18,
	tags = { "street", "clock", "landmark" },
	build = function(c: Ctx)
		local green = c.color("color", CLOCK_GREEN)
		local gold = c.color("accent", S.gold)
		local hour = c.int("hour", c.rng:int(1, 12), 0, 23)
		local minute = c.int("minute", c.rng:int(0, 59), 0, 59)
		c.part(P(0, 0.4, 0), V(2.6, 0.8, 2.6), S.granite, M.Granite)
		c.cyl(P(0, 1.6, 0), 1.6, 1.8, green, M.Metal)
		c.dcyl(P(0, 2.45, 0), 0.15, 2.0, gold, M.Metal)
		c.dcyl(P(0, 2.8, 0), 0.6, 1.3, green, M.Metal)
		c.cyl(P(0, 6.9, 0), 7.6, 0.7, green, M.Metal)
		c.dcyl(P(0, 5.0, 0), 0.12, 0.85, gold, M.Metal)
		c.dcyl(P(0, 10.8, 0), 0.3, 1.3, gold, M.Metal)
		-- clock head: a drum with a dial on each face
		c.cylZ(P(0, 12.6, 0), 0.9, 3.0, green, M.Metal)
		for _, sz in { -1, 1 } do
			c.dcylZ(P(0, 12.6, sz * 0.47), 0.06, 3.1, gold, M.Metal)
			c.dcylZ(P(0, 12.6, sz * 0.5), 0.02, 2.6, hex("#F4F1EA"), M.SmoothPlastic)
			local dial = c.detail(P(0, 12.6, sz * 0.52), V(2.5, 2.5, 0.004), Color3.new(1, 1, 1))
			dial.Name = "Dial"
			dial.Transparency = 1
			local face = if sz < 0 then Enum.NormalId.Front else Enum.NormalId.Back
			local gui, gw, gh = Gui.Core.surface(dial, face, { pps = 60, maxDistance = 120 })
			Gui.Art.clockFace(gui, gw, gh, hour, minute, IRON)
			c.tag(dial, "WallClock")
		end
		c.dball(P(0, 14.4, 0), 1.0, green, M.Metal)
		c.dcyl(P(0, 15.0, 0), 0.5, 0.25, gold, M.Metal)
		c.dball(P(0, 15.35, 0), 0.45, gold, M.Metal)
	end,
})

---------------------------------------------------------------------------------------------------
-- trash_bin_street: polished black litter bin with a brass band, domed hood and a dark opening
---------------------------------------------------------------------------------------------------
add({
	id = "trash_bin_street",
	category = "street",
	footprint = V(2.0, 3.6, 2.0),
	maxParts = 8,
	tags = { "street", "trash" },
	build = function(c: Ctx)
		local body = c.color("color", IRON)
		local brass = c.color("accent", S.brass)
		c.dcyl(P(0, 0.08, 0), 0.16, 2.0, shade(body, -0.2), M.Metal)
		c.cyl(P(0, 1.45, 0), 2.6, 1.8, body, M.Metal)
		c.dcyl(P(0, 2.2, 0), 0.14, 1.86, brass, M.Metal)
		c.dcyl(P(0, 2.85, 0), 0.1, 1.9, body, M.Metal)
		c.dball(P(0, 3.0, 0), 1.2, body, M.Metal)
		c.detail(P(0, 2.95, -0.75), V(0.9, 0.35, 0.3), hex("#050505"), M.SmoothPlastic)
		local plate = c.detail(P(0, 1.4, -0.91), V(0.7, 0.4, 0.02), brass, M.Metal)
		c.sign(plate, Words.litter, { font = Enum.Font.GothamBold, color = IRON, pixelsPerStud = 80, padding = 0.12 })
	end,
})

---------------------------------------------------------------------------------------------------
-- tree_grate: street tree planted in the sidewalk: iron grate (painted grid), trunk guard and canopy.
-- Walkable: only the grate collides.
---------------------------------------------------------------------------------------------------
add({
	id = "tree_grate",
	category = "street",
	footprint = V(6.6, 14.3, 6.6),
	maxParts = 20,
	tags = { "street", "plant", "tree" },
	build = function(c: Ctx)
		local iron = c.color("accent", IRON)
		local grate = c.part(P(0, 0.03, 0), V(4, 0.06, 4), iron, M.Metal)
		grate.Name = "Grate"
		local gui = Gui.Core.surface(grate, Enum.NormalId.Top, { pps = 20, maxDistance = 60 })
		for i = 1, 7 do
			Gui.Core.frame(gui, i / 8 - 0.01, 0.05, 0.02, 0.9, shade(iron, 0.35))
			Gui.Core.frame(gui, 0.05, i / 8 - 0.01, 0.9, 0.02, shade(iron, 0.35))
		end
		Gui.Core.dot(gui, 40, 40, 30, col.soil)
		for k = 0, 3 do
			local a = k * 90 + 45
			Shapes.strut(c, (P(0, 0, 0) * R(0, a, 0) * P(0.75, 0.06, 0)).Position, (R(0, a, 0) * P(0.75, 3.0, 0)).Position, 0.08, iron, M.Metal)
		end
		c.dcyl(P(0, 2.9, 0), 0.08, 1.6, iron, M.Metal)
		c.dcyl(P(0, 1.5, 0), 0.08, 1.6, iron, M.Metal)
		c.cyl(P(0, 4.0, 0), 8.0, 0.5, col.trunk, M.Wood)
		Shapes.strut(c, V(0, 6.5, 0), V(1.2, 8.6, 0.4), 0.28, col.trunk, M.Wood)
		Shapes.strut(c, V(0, 6.9, 0), V(-1.0, 8.9, -0.5), 0.28, col.trunk, M.Wood)
		local pal = { S.foliage, S.foliageLight, col.leafDark }
		local j = function(): number
			return c.rng:range(-0.2, 0.2)
		end
		c.dball(P(0, 10.6, 0), 4.4, pal[1], M.Grass)
		c.dball(P(1.75 + j(), 9.9, 0.3), 3.1, pal[2], M.Grass)
		c.dball(P(-1.6 + j(), 10.2, -0.5), 3.1, pal[3], M.Grass)
		c.dball(P(0.3, 10.1, 1.75 + j()), 3.1, pal[2], M.Grass)
		c.dball(P(-0.3, 10.0, -1.7 + j()), 3.1, pal[1], M.Grass)
		c.dball(P(0.1 + j(), 12.4, 0), 3.0, pal[2], M.Grass)
	end,
})

---------------------------------------------------------------------------------------------------
-- atm: free-standing BLUEFIN BANK cash machine with a lit screen, keypad, card slot and cash slot
---------------------------------------------------------------------------------------------------
add({
	id = "atm",
	category = "street",
	footprint = V(2.6, 6.0, 2.3),
	maxParts = 14,
	tags = { "street", "bank", "machine" },
	build = function(c: Ctx)
		local body = c.color("color", S.navy)
		local trim = c.color("accent", S.steelBrushed)
		local lit = c.bool("lit", true)
		c.part(P(0, 0.15, 0), V(2.6, 0.3, 2.2), shade(body, -0.3), M.Metal)
		c.part(P(0, 3.0, 0.15), V(2.4, 5.4, 1.9), body, M.Metal)
		local header = c.detail(P(0, 5.35, -0.82), V(2.2, 0.6, 0.04), S.white, M.SmoothPlastic)
		c.sign(header, Words.atmBrand, { font = Enum.Font.GothamBlack, color = body, pixelsPerStud = 50, glow = lit })
		-- recessed fascia with a hood
		c.detail(P(0, 3.3, -0.82), V(2.0, 2.6, 0.04), trim, M.Metal)
		c.detail(P(0, 4.65, -1.0), V(2.2, 0.12, 0.4), shade(body, -0.2), M.Metal)
		local screen = c.detail(P(0, 3.95, -0.86) * R(-8, 0, 0), V(1.3, 0.95, 0.04), hex("#0B1622"), M.Glass)
		screen.Name = "Screen"
		local gui = Gui.Core.surface(screen, Enum.NormalId.Front, { glow = lit, pps = 80, maxDistance = 30 })
		Gui.Core.bg(gui, hex("#123A6B"))
		Gui.Core.label(gui, Words.atmWelcome, 0.08, 0.15, 0.84, 0.3, S.white, {
			font = Enum.Font.GothamBold,
			align = Enum.TextXAlignment.Center,
		})
		Gui.Core.label(gui, Words.atmInsert, 0.08, 0.55, 0.84, 0.2, hex("#9EC2FF"), {
			font = Enum.Font.Gotham,
			align = Enum.TextXAlignment.Center,
		})
		local pad = c.detail(P(-0.25, 2.9, -0.95) * R(35, 0, 0), V(0.9, 0.08, 0.6), col.plasticGrey, M.Metal)
		local kg = Gui.Core.surface(pad, Enum.NormalId.Top, { pps = 80, maxDistance = 20 })
		for r = 0, 3 do
			for k = 0, 2 do
				Gui.Core.frame(kg, 0.08 + k * 0.3, 0.08 + r * 0.23, 0.24, 0.17, trim)
			end
		end
		c.detail(P(0.6, 2.95, -0.86), V(0.4, 0.12, 0.06), IRON, M.SmoothPlastic)
		c.glow(P(0.6, 3.05, -0.89), V(0.3, 0.03, 0.02), hex("#2BD67B"), if lit then 0.1 else 0.7)
		c.detail(P(0, 2.35, -0.86), V(1.1, 0.14, 0.06), IRON, M.SmoothPlastic)
		c.use(V(0, 3.5, -1.6))
	end,
})

return defs
