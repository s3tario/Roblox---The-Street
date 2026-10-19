--!strict
-- The Route 9 subway (interior "subway"): two worn stainless cars, one for each direction of the ride
-- (Config/World doors door_campus_subway / door_street_subway use them as their `via` anchors for the 8 second trip).
--
--   car "ToStreet"  anchor subway_car_to_street (NEXT STOP: WALL ST)
--   car "ToCampus"  anchor subway_car_to_campus (NEXT STOP: EASTBRIDGE)
--
-- Each car is fully enclosed: rubber floor, longitudinal plastic benches, grab poles and rails, the tunnel streaking
-- past painted in the windows, adverts over the windows, the strip map over the doors and a glowing next-stop sign at
-- each end. build(parent, mk, origin) -> Model. Bake-safe.

local Deps = require(script.Parent.Deps)
local Shell = require(script.Parent.Shell)

local Kit = Deps.Kit
local Paint = Deps.Paint
local Text = Deps.Text
local Markers = Deps.Markers
local Core = Deps.Gui.Core
local Art = Deps.Gui.Art
local P = Deps.Palette
local hex = P.hex
local M = Enum.Material

local Subway = {}

local LEN = 56 -- interior length (along the car's local Z)
local WID = 9 -- interior width (local X)
local HT = 8.4 -- floor to ceiling
local STEEL = hex("#A7ABB0")
local SEAT = { hex("#C9762E"), hex("#2C5E8A") }

-- door positions along each side (centre, local Z)
local DOORS = { -14, 14 }

local function car(m: Instance, mk: Instance, cf: CFrame, name: string, anchorId: string, dest: string, rng: Deps.RngT)
	local c = Kit.model(m, name)
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	-- shell: floor, ceiling with curved coves, sides, ends
	local floor = Kit.block(c, at(0, -0.5, 0), Vector3.new(WID + 2, 1, LEN + 2), hex("#4A4C50"), M.Rubber)
	floor.Name = "CarFloor"
	local fg, FW, FH = Paint.surface(floor, Enum.NormalId.Top, 4)
	for _ = 1, 90 do
		Core.px(fg, rng:range(0, FW), rng:range(0, FH), 2, 2, hex("#6E7074"), 0.4)
	end
	Kit.block(c, at(0, HT + 0.5, 0), Vector3.new(WID + 2, 1, LEN + 2), hex("#D8D8D2"), M.SmoothPlastic).Name =
		"CarCeiling"
	for _, s in { -1, 1 } do
		Kit.wedge(
			c,
			at(s * (WID / 2 - 0.6), HT - 0.6, 0) * CFrame.Angles(0, math.rad(90 * s), 0),
			Vector3.new(LEN, 1.2, 1.2),
			hex("#C9C9C2"),
			M.SmoothPlastic
		).Name =
			"Cove"
		Kit.block(c, at(s * (WID / 2 + 0.5), HT / 2, 0), Vector3.new(1, HT, LEN + 2), STEEL, M.Metal).Name = "CarSide"
	end
	for _, s in { -1, 1 } do
		Kit.block(c, at(0, HT / 2, s * (LEN / 2 + 0.5)), Vector3.new(WID, HT, 1), STEEL, M.Metal).Name = "CarEnd"
	end
	-- the windows: one long tunnel strip per side (the doors painted in as panels)
	for _, s in { -1, 1 } do
		local strip = Kit.detail(
			c,
			at(s * (WID / 2 - 0.05), 4.6, 0) * CFrame.Angles(0, math.rad(-90 * s), 0),
			Vector3.new(LEN, 2.8, 0.1),
			hex("#121416"),
			M.SmoothPlastic
		)
		strip.Name = "TunnelWindows"
		local g, W, H = Paint.surface(strip, Enum.NormalId.Front, 6, { glow = true, brightness = 0.6 })
		Paint.view(g, W, H, rng, "tunnel")
		-- window pillars between the panes
		for k = 0, 7 do
			Core.px(g, k * W / 8, 0, 6, H, hex("#8E9397"))
		end
		-- the doors on this side: steel leaves with their own little windows, a rubber seal down the middle
		for _, dz in DOORS do
			local d = Kit.detail(
				c,
				at(s * (WID / 2 - 0.12), 3.6, dz) * CFrame.Angles(0, math.rad(-90 * s), 0),
				Vector3.new(5, 7.2, 0.1),
				hex("#9AA0A6"),
				M.Metal
			)
			d.Name = "CarDoor"
			local dg, DW, DH = Paint.surface(d, Enum.NormalId.Front, 10)
			Core.bg(dg, hex("#9AA0A6"))
			Core.px(dg, DW / 2 - 1, 0, 2, DH, hex("#2A2A2A"))
			for _, wx in { 0.12, 0.6 } do
				local win = Core.frame(dg, wx, 0.12, 0.28, 0.32, hex("#121416"))
				Core.round(win, 0.1)
			end
			Core.label(dg, Text.subway.doors, 0.05, 0.86, 0.9, 0.08, hex("#E9E2CF"), {
				font = Enum.Font.Highway,
				align = Enum.TextXAlignment.Center,
			})
		end
	end
	-- benches between the doors (and at the ends), with backrests
	local runs = { { -LEN / 2 + 1, DOORS[1] - 3 }, { DOORS[1] + 3, DOORS[2] - 3 }, { DOORS[2] + 3, LEN / 2 - 1 } }
	for i, r in runs do
		local len = r[2] - r[1]
		local mid = (r[1] + r[2]) / 2
		for _, s in { -1, 1 } do
			local col = SEAT[((i + (if s > 0 then 1 else 0)) % 2) + 1]
			Kit.block(c, at(s * (WID / 2 - 1), 1.6, mid), Vector3.new(2, 0.4, len), col, M.Plastic).Name = "Bench"
			Kit.detail(c, at(s * (WID / 2 - 0.2), 2.6, mid), Vector3.new(0.4, 1.8, len), col, M.Plastic).Name =
				"Backrest"
			Kit.detail(c, at(s * (WID / 2 - 1), 0.7, mid), Vector3.new(1.6, 1.4, len - 1), hex("#5A5F63"), M.Metal).Name =
				"BenchBase"
		end
	end
	-- grab poles at the doors and down the middle, rails along the ceiling
	for _, z in { DOORS[1], 0, DOORS[2] } do
		Kit.cylinder(c, at(0, HT / 2, z), HT, 0.25, hex("#C9CCCF"), M.Metal).Name = "Pole"
	end
	for _, z in DOORS do
		for _, s in { -1, 1 } do
			Kit.cylinder(c, at(s * 2.6, HT / 2, z + s * 2), HT, 0.25, hex("#C9CCCF"), M.Metal).Name = "Pole"
		end
	end
	for _, s in { -1, 1 } do
		Kit.detail(
			c,
			at(s * 2.4, HT - 0.9, 0) * CFrame.Angles(math.rad(90), 0, 0),
			Vector3.new(0.2, LEN - 2, 0.2),
			hex("#C9CCCF"),
			M.Metal
		).Name =
			"Rail"
	end
	-- hanging straps along the rails (a strap and a grab handle each)
	for _, s in { -1, 1 } do
		for z = -24, 24, 6 do
			local sway = rng:range(-6, 6)
			local strap = at(s * 2.4, HT - 1.55, z) * CFrame.Angles(math.rad(sway), 0, 0)
			Kit.detail(c, strap, Vector3.new(0.1, 1.1, 0.3), hex("#2A2C30"), M.Plastic).Name = "Strap"
			Kit.detail(c, strap * CFrame.new(0, -0.7, 0), Vector3.new(0.12, 0.45, 0.6), hex("#E9E2CF"), M.Plastic).Name =
				"Handle"
		end
	end
	-- adverts over the windows, the strip map over the doors
	for _, s in { -1, 1 } do
		local ads = Kit.detail(
			c,
			at(s * (WID / 2 - 0.4), 6.9, 0)
				* CFrame.Angles(0, math.rad(-90 * s), 0)
				* CFrame.Angles(math.rad(-15), 0, 0),
			Vector3.new(LEN - 4, 1.4, 0.1),
			hex("#E9E2CF"),
			M.SmoothPlastic
		)
		ads.Name = "AdStrip"
		local g, W, H = Paint.surface(ads, Enum.NormalId.Front, 10)
		local n = #Text.subway.ads * 2
		for k = 0, n - 1 do
			local a = Text.subway.ads[(k % #Text.subway.ads) + 1]
			local card = Core.frame(g, k / n + 0.004, 0.06, 1 / n - 0.008, 0.88, hex("#F4F1EA"))
			if k % 2 == 0 then
				Art.ad(card, a.title, a.body, rng, W / n, H)
			else
				Core.label(
					card,
					a.title,
					0.05,
					0.05,
					0.9,
					0.45,
					hex("#1F2A44"),
					{ font = Enum.Font.Oswald, align = Enum.TextXAlignment.Center }
				)
				Core.label(
					card,
					a.body,
					0.05,
					0.5,
					0.9,
					0.45,
					hex("#2A2622"),
					{ font = Enum.Font.SourceSans, align = Enum.TextXAlignment.Center }
				)
			end
		end
	end
	-- next-stop signs at both ends and the route strip map on the front end
	for _, s in { -1, 1 } do
		local led = Kit.detail(
			c,
			at(0, 7.2, s * (LEN / 2 - 0.08)) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0),
			Vector3.new(6, 1, 0.1),
			hex("#141414"),
			M.SmoothPlastic
		)
		led.Name = "NextStop"
		Kit.sign(
			led,
			Text.subway.next .. ": " .. dest,
			{ font = Enum.Font.Code, color = hex("#FF6A3C"), pixelsPerStud = 40, glow = true }
		)
		local map = Kit.detail(
			c,
			at(0, 5.2, s * (LEN / 2 - 0.08)) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0),
			Vector3.new(7.6, 1.6, 0.05),
			hex("#F4F1EA"),
			M.SmoothPlastic
		)
		map.Name = "RouteMap"
		local mg = Paint.surface(map, Enum.NormalId.Front, 30)
		Core.bg(mg, hex("#F4F1EA"))
		Core.label(
			mg,
			Text.subway.line,
			0.03,
			0.04,
			0.94,
			0.3,
			hex("#1F2A44"),
			{ font = Enum.Font.Highway, align = Enum.TextXAlignment.Center }
		)
		Core.label(
			mg,
			Text.subway.map,
			0.03,
			0.42,
			0.94,
			0.5,
			hex("#2F8C4E"),
			{ font = Enum.Font.Code, align = Enum.TextXAlignment.Center }
		)
		-- the storm door through to the next car, its window black
		Kit.detail(
			c,
			at(0, 2.4, s * (LEN / 2 - 0.06)) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0),
			Vector3.new(3, 4.6, 0.08),
			hex("#8E9397"),
			M.Metal
		).Name =
			"StormDoor"
	end
	local seat = Kit.detail(
		c,
		at(-(WID / 2 - 0.12), 6.1, -LEN / 2 + 4) * CFrame.Angles(0, math.rad(-90), 0),
		Vector3.new(3, 0.6, 0.05),
		hex("#2C5E8A"),
		M.SmoothPlastic
	)
	Kit.sign(seat, Text.subway.seat, { font = Enum.Font.Highway, color = hex("#F4F1EA"), pixelsPerStud = 40 })
	local hold = Kit.detail(
		c,
		at(WID / 2 - 0.12, 6.1, LEN / 2 - 4) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(3, 0.6, 0.05),
		hex("#C9762E"),
		M.SmoothPlastic
	)
	Kit.sign(hold, Text.subway.hold, { font = Enum.Font.Highway, color = hex("#F4F1EA"), pixelsPerStud = 40 })
	-- ceiling light strips (one real light per car), a newspaper and a coffee cup left behind
	for i, x in { -1.6, 1.6 } do
		local l = Kit.detail(c, at(x, HT - 0.05, 0), Vector3.new(0.8, 0.1, LEN - 6), hex("#F4F1E6"), M.Neon)
		l.Name = "LightStrip"
		l.Transparency = 0.1
		l:AddTag("InteriorLight")
		if i == 1 then
			Kit.light(l, "point", { Color = hex("#F4EEDC"), Range = 30, Brightness = 1.1 })
		end
	end
	local paper = Kit.detail(
		c,
		at(WID / 2 - 1.2, 1.82, -20) * CFrame.Angles(0, math.rad(20), 0),
		Vector3.new(1.4, 0.04, 1.9),
		hex("#E9E2CF"),
		M.SmoothPlastic
	)
	paper.Name = "Newspaper"
	local ng = Paint.surface(paper, Enum.NormalId.Top, 40)
	Art.newspaper(ng, rng)
	Kit.cylinder(c, at(-(WID / 2 - 1.2), 2.15, 22), 0.7, 0.5, hex("#E9E2CF"), M.SmoothPlastic).Name = "CoffeeCup"
	-- the ride anchor: in the aisle between the middle pole and the front doors, facing the direction of travel
	Markers.anchor(mk, anchorId, at(0, 3, -7))
	return c
end

function Subway.build(parent: Instance, mk: Instance, origin: Vector3): Model
	local m = Kit.model(parent, "subway")
	m:SetAttribute("Interior", "subway")
	m:SetAttribute("LightingPreset", "subway")
	local F = Shell.frame(origin)
	local rng = Deps.Rng.new("route9-cars")
	-- the cars run along X; their local -Z (front) points east
	car(m, mk, F.cf(0, 0, -30, Shell.E), "ToStreet", "subway_car_to_street", Text.subway.toStreet, rng)
	car(m, mk, F.cf(0, 0, 30, Shell.E), "ToCampus", "subway_car_to_campus", Text.subway.toCampus, rng)
	return m
end

return Subway
