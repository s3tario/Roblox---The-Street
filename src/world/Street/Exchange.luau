--!strict
-- The Metropolitan Exchange: the neoclassical temple of the market that closes Exchange Plaza's axis from the south
-- side of Exchange Avenue. A wide granite stair climbs to a portico of eight giant columns under an entablature with
-- the name in gilt letters and a live LED ticker band (tagged "TickerBand", label "TickerText", rewritten by
-- MarketService and scrolled by the client), a sculpted pediment, two limestone pavilions with hanging banners,
-- rooftop flags and bronze lamp standards. The steps and the portico are walkable; the bronze doors are closed (the
-- trading floor is members only). Bake-safe.
--
--   Exchange.build(parent, rects) -> Model

local Deps = require(script.Parent.Deps)
local Look = require(script.Parent.Look)
local Mass = require(script.Parent.Mass)
local Plan = require(script.Parent.Plan)
local Text = require(script.Parent.Text)

local Kit = Deps.Kit
local Props = Deps.Props
local Signs = Deps.Signs
local Gui = Deps.Gui
local M = Enum.Material

local Exchange = {}

local STEPS = 14
local RISE = 0.5
local RUN = 1
local FLOOR_Y = STEPS * RISE -- portico floor
local STAIR_D = STEPS * RUN
local PORTICO_D = 22
local COL_H = 52
local COL_D = 6

local function box(x0: number, x1: number, z0: number, z1: number, y0: number, y1: number): Mass.Box
	return { x0 = x0, x1 = x1, z0 = z0, z1 = z1, y0 = y0, y1 = y1 }
end

local function lampStandard(m: Instance, frame: CFrame, x: number, z: number, y: number)
	local cf = frame * CFrame.new(x, y, z)
	Kit.block(m, cf * CFrame.new(0, 1, 0), Vector3.new(2.4, 2, 2.4), Look.bronzeDark, M.Metal)
	Kit.cylinder(m, cf * CFrame.new(0, 6, 0), 8, 0.7, Look.bronzeDark, M.Metal)
	Kit.detail(m, cf * CFrame.new(0, 10, 0), Vector3.new(4.2, 0.4, 0.4), Look.bronzeDark, M.Metal)
	for _, sx in { -1, 0, 1 } do
		local globe =
			Kit.ball(m, cf * CFrame.new(sx * 2, 11 + (if sx == 0 then 0.8 else 0), 0), 1.5, Look.lampGlow, M.Neon, {
				CanCollide = false,
				CastShadow = false,
			})
		globe.Transparency = 0.15
		globe:AddTag("StreetLight")
		if sx == 0 then
			Kit.light(globe, "point", { Color = Look.lampGlow, Range = 22, Brightness = 1.1 })
		end
	end
end

function Exchange.build(parent: Instance, rects: { Plan.Rect }): Model
	local lot = Plan.exchange
	local frame = Plan.lotFrame(lot)
	local m = Kit.model(parent, "MetropolitanExchange")
	m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	local W, D, H = lot.w, lot.d, lot.h
	local hw = W / 2
	local pav = 20 -- pavilion width
	local core = hw - pav -- main block half-width
	local zPortico = STAIR_D
	local zWall = STAIR_D + PORTICO_D
	local stone = Look.limestone

	-- grand stair across the portico, with solid cheek walls carrying lamp standards
	local stairW = 2 * (core - 18)
	local base = frame * CFrame.new(0, 0, RUN / 2) * CFrame.Angles(0, math.pi, 0)
	Kit.stairs(m, base, stairW, STEPS, RISE, RUN, Look.graniteLight, M.Granite).Name = "ExchangeSteps"
	for _, sx in { -1, 1 } do
		local xa, xb = sx * stairW / 2, sx * core
		Mass.slab(
			m,
			frame,
			box(math.min(xa, xb), math.max(xa, xb), 0, zPortico, 0, FLOOR_Y + 1.5),
			Look.granite,
			M.Granite
		).Name =
			"Cheek"
		lampStandard(m, frame, sx * (stairW / 2 + 4), 2.5, FLOOR_Y + 1.5)
	end
	-- portico floor
	Mass.slab(m, frame, box(-core, core, zPortico, zWall + 1, 0, FLOOR_Y), Look.graniteLight, M.Granite).Name =
		"Portico"
	Mass.slab(
		m,
		frame,
		box(-core + 0.3, core - 0.3, zPortico + 0.3, zWall, FLOOR_Y - 0.02, FLOOR_Y + 0.04),
		Look.marble,
		M.Marble,
		false
	)

	-- main block behind the portico: tall windows, three bronze doors
	local mainTop = H * 0.86
	local mainBox = box(-core, core, zWall, D, 0, mainTop)
	local look = Mass.look("limestone", { bay = 15, storey = 21, pierW = 3, bandH = 3, lit = 0.25 })
	Mass.tier(m, frame, mainBox, look, {
		hidden = { front = FLOOR_Y + 22, left = math.huge, right = math.huge },
		seed = "exchange:main",
		name = "MainBlock",
		noTop = true,
	})
	for i = -1, 1 do
		local x = i * 22
		Mass.slab(m, frame, box(x - 5.6, x + 5.6, zWall - 0.6, zWall, FLOOR_Y, FLOOR_Y + 19), stone, M.Limestone, false)
		Mass.slab(
			m,
			frame,
			box(x - 4.5, x + 4.5, zWall - 0.8, zWall - 0.4, FLOOR_Y, FLOOR_Y + 17),
			Look.bronzeDark,
			M.Metal,
			false
		).Name =
			"BronzeDoor"
		Mass.slab(
			m,
			frame,
			box(x - 0.15, x + 0.15, zWall - 0.9, zWall - 0.6, FLOOR_Y, FLOOR_Y + 17),
			Look.bronze,
			M.Metal,
			false
		)
	end

	-- the portico: eight giant columns
	local n = 8
	local span = 2 * core - 14
	for i = 0, n - 1 do
		local x = -span / 2 + span * i / (n - 1)
		local z = zPortico + 6
		local cf = frame * CFrame.new(x, FLOOR_Y, z)
		Kit.block(
			m,
			cf * CFrame.new(0, 0.9, 0),
			Vector3.new(COL_D + 1.6, 1.8, COL_D + 1.6),
			Look.limestoneDark,
			M.Limestone
		).Name =
			"ColumnBase"
		Kit.cylinder(m, cf * CFrame.new(0, 1.8 + (COL_H - 4.4) / 2, 0), COL_H - 4.4, COL_D, stone, M.Limestone).Name =
			"Column"
		Kit.cylinder(m, cf * CFrame.new(0, COL_H - 2.0, 0), 1.6, COL_D + 1.2, Look.limestoneWarm, M.Limestone, {
			CanCollide = false,
		})
		Kit.detail(
			m,
			cf * CFrame.new(0, COL_H - 0.6, 0),
			Vector3.new(COL_D + 2.2, 1.2, COL_D + 2.2),
			stone,
			M.Limestone
		)
	end

	-- entablature: architrave (carrying the ticker band), frieze (the name), cornice
	local yE = FLOOR_Y + COL_H
	local eW = core + 2
	Mass.slab(m, frame, box(-eW, eW, zPortico + 1, zWall, yE, yE + 4), stone, M.Limestone).Name = "Architrave"
	Mass.slab(m, frame, box(-eW, eW, zPortico + 1.6, zWall, yE + 4, yE + 10), Look.limestoneWarm, M.Limestone).Name =
		"Frieze"
	Mass.slab(m, frame, box(-eW - 1.5, eW + 1.5, zPortico - 0.5, zWall, yE + 10, yE + 13), stone, M.Limestone).Name =
		"Cornice"
	local band = Signs.tickerBand(m, frame * CFrame.new(0, yE + 0.6, zPortico + 1), {
		width = 2 * eW - 6,
		height = 2.8,
		text = Text.get("exchange_ticker"),
		accent = Look.gold,
		seed = "exchange:ticker",
	})
	band.Name = "TickerBand"
	band:AddTag("TickerBand")
	Signs.buildingName(m, frame * CFrame.new(0, yE + 5.0, zPortico + 1.6), {
		text = Text.get("exchange_name"),
		style = "brass",
		height = 4,
		width = 2 * eW - 30,
		font = "serif",
		lit = true,
		seed = "exchange:name",
	})

	-- pediment with a sculpted tympanum
	local pedH = 20
	local pedW = 2 * eW + 2
	-- the gabled roof over the portico: its front face is the pediment
	local roofD = zWall - zPortico - 1
	for _, sx in { -1, 1 } do
		Kit.wedge(
			m,
			frame
				* CFrame.new(sx * pedW / 4, yE + 13 + pedH / 2, zPortico + 1 + roofD / 2)
				* CFrame.Angles(0, -sx * math.pi / 2, 0),
			Vector3.new(roofD, pedH, pedW / 2),
			stone,
			M.Limestone
		).Name =
			"Pediment"
	end
	local tym = Look.limestoneWarm
	local reliefs = { { 0, 9, 7 }, { -12, 6, 6 }, { 12, 6, 6 }, { -24, 3.5, 7 }, { 24, 3.5, 7 } }
	for _, r in reliefs do
		Kit.detail(
			m,
			frame * CFrame.new(r[1], yE + 13.5 + r[2] / 2, zPortico + 0.45),
			Vector3.new(r[3], r[2], 1.2),
			tym,
			M.Limestone
		)
	end
	local medallion = Kit.cylinder(
		m,
		frame * CFrame.new(0, yE + 13 + 11.5, zPortico + 0.5) * CFrame.Angles(math.pi / 2, 0, 0),
		0.6,
		5,
		Look.gold,
		M.Foil,
		{ CanCollide = false }
	)
	medallion.Name = "Medallion"

	-- pavilions either side, with banners
	for _, sx in { -1, 1 } do
		local x0, x1 = math.min(sx * core, sx * hw), math.max(sx * core, sx * hw)
		local pb = box(x0, x1, 0, D, 0, H * 0.82)
		local pl = Mass.look("limestone", { bay = 10, storey = 18, lit = 0.2 })
		local hidden = { front = 0, back = math.huge, left = 0, right = 0 }
		-- the inner side meets the main block: hidden; the outer side faces the passage to the next tower
		if sx > 0 then
			hidden.left = math.huge
		else
			hidden.right = math.huge
		end
		local wp = frame:PointToWorldSpace(Vector3.new(sx * (hw + 3), 0, D / 2))
		if Plan.heightAt(rects, wp.X, wp.Z, "exchange") > 0 then
			hidden[if sx > 0 then "right" else "left"] = Plan.heightAt(rects, wp.X, wp.Z, "exchange")
		end
		Mass.tier(m, frame, pb, pl, { hidden = hidden, seed = "exchange:pav" .. sx, name = "Pavilion" })
		Mass.cornice(m, frame, pb, pb.y1 - 0.4, 2, 1.6, stone, M.Limestone)
		-- rusticated base course
		Mass.slab(m, frame, box(x0 - 0.4, x1 + 0.4, -0.4, D, 0, 3), Look.limestoneDark, M.Limestone, false)
		local banner = Kit.detail(
			m,
			frame * CFrame.new((x0 + x1) / 2, pb.y1 - 30, -1.8),
			Vector3.new(10, 40, 0.2),
			Look.navy,
			M.Fabric
		)
		banner.Name = "Banner"
		local gui = Gui.Core.surface(banner, Enum.NormalId.Front, { pps = 12, name = "Banner" })
		Gui.Core.bg(gui, Look.navy)
		for _, edge in
			{
				{ 0.04, 0.02, 0.92, 0.006 },
				{ 0.04, 0.974, 0.92, 0.006 },
				{ 0.04, 0.02, 0.02, 0.96 },
				{ 0.94, 0.02, 0.02, 0.96 },
			}
		do
			Gui.Core.frame(gui, edge[1], edge[2], edge[3], edge[4], Look.gold)
		end
		Gui.Core.label(gui, "ME", 0.15, 0.06, 0.7, 0.22, Look.gold, {
			font = Enum.Font.Bodoni,
			align = Enum.TextXAlignment.Center,
		})
		Gui.Core.frame(gui, 0.3, 0.31, 0.4, 0.006, Look.gold)
		Gui.Core.label(gui, Text.get("exchange_name"), 0.08, 0.36, 0.84, 0.42, Look.white, {
			font = Enum.Font.Bodoni,
			align = Enum.TextXAlignment.Center,
		})
		Gui.Core.label(gui, Text.get("exchange_founded"), 0.1, 0.82, 0.8, 0.1, Look.gold, {
			font = Enum.Font.Bodoni,
			align = Enum.TextXAlignment.Center,
		})
		Kit.detail(
			m,
			frame * CFrame.new((x0 + x1) / 2, pb.y1 - 9.6, -2.2),
			Vector3.new(11, 0.5, 0.5),
			Look.gold,
			M.Metal
		)
	end

	-- attic and rooftop flags
	Mass.slab(m, frame, box(-core, core, zWall, D, mainTop, H), stone, M.Limestone).Name = "Attic"
	Mass.cornice(m, frame, box(-core, core, zWall, D, mainTop, H), H - 0.4, 1.4, 1.2, Look.limestoneDark, M.Limestone)
	for i = -1, 1 do
		Props.build(
			"flag_pole",
			m,
			frame * CFrame.new(i * 40, H + 1, zWall + 4),
			{ variant = 2, seed = "exchange:flag" .. i }
		)
	end

	-- floodlights on the cheeks washing the columns, bollards, the plaque
	for _, sx in { -1, 1 } do
		local fix = Kit.detail(
			m,
			frame * CFrame.new(sx * (stairW / 2 + 9), FLOOR_Y + 1.8, zPortico - 2),
			Vector3.new(1.2, 0.6, 1.2),
			Look.iron,
			M.Metal
		)
		Kit.light(
			fix,
			"spot",
			{ Face = Enum.NormalId.Top, Angle = 60, Range = 70, Brightness = 1.6, Color = Look.warmLight }
		)
	end
	for i = 0, 5 do
		local x = -stairW / 2 + 6 + (stairW - 12) * i / 5
		Props.build("bollard", m, frame * CFrame.new(x, 0, -3), { seed = "exchange:bollard" .. i })
	end
	Signs.plaque(m, frame * CFrame.new(-(stairW / 2 + 9), 2.4, -0.02), {
		title = Text.get("exchange_plaque_title"),
		text = Text.get("exchange_plaque_text"),
		width = 4.6,
		height = 2.6,
	})
	return m
end

return Exchange
