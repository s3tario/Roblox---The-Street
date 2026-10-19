--!strict
-- Security and the elevator bank (east wing):
--   Elevators.gates(parent)   speed gates across the elevator hall's mouth: four steel cabinets with lit strips and
--                             three 4.4-stud lanes (glass wings stand open and never collide), a security podium and
--                             the "Elevators" sign over the mouth
--   Elevators.hall(parent)    the walnut-panelled elevator hall: six cars (three per long wall) in brass surrounds with
--                             floor indicators, a call-button panel on each wall carrying the `elevator_panel` interact
--                             (OfficeService opens the Elevator screen), and the end wall with the FirmColor field, a
--                             second CompanyLogo panel and a CompanyName band. OfficeAnchor "elevators" (init) stands
--                             in the middle of the hall.
-- Bake-safe.

local Deps = require(script.Parent.Deps)
local Plan = require(script.Parent.Plan)
local Look = require(script.Parent.Look)

local Kit = Deps.Kit
local Geo = Deps.Geo
local Art = Deps.Art
local Text = Deps.Text
local Core = Deps.Core
local Style = Deps.Style
local Furniture = Deps.Furniture
local hex = Deps.Palette.hex
local M = Enum.Material
local V = Vector3.new

local Elevators = {}

local E = Plan.elevatorHall
local GATE_GLOW = hex("#3FD1E6")
local READY = hex("#2BD67B")

---------------------------------------------------------------------------------------------------
-- Security gates
---------------------------------------------------------------------------------------------------
function Elevators.gates(parent: Instance): Model
	local m = Kit.model(parent, "SecurityGates")
	local gx, L = Plan.gateX, Plan.GATE_LEN
	local cabW = 1.2
	local span = E.maxZ - E.minZ
	local lane = (span - cabW * 4) / 3
	for k = 0, 3 do
		local z = E.minZ + cabW / 2 + k * (cabW + lane)
		local cab = Kit.block(m, CFrame.new(gx, 1.7, z), V(L, 3.4, cabW), Look.steel, M.Metal)
		cab.Name = "GateCabinet"
		local top = Kit.detail(m, CFrame.new(gx, 3.45, z), V(L + 0.05, 0.1, cabW + 0.05), Look.black, M.Glass)
		top.Name = "GateTop"
		local gui = Deps.Gui.Core.surface(top, Enum.NormalId.Top, { pps = 20, glow = true, name = "Reader" })
		Deps.Gui.Core.frame(gui, 0.05, 0.25, 0.14, 0.5, READY, 0.1)
		Deps.Gui.Core.frame(gui, 0.81, 0.25, 0.14, 0.5, READY, 0.1)
		local strip = Kit.detail(m, CFrame.new(gx, 3.1, z), V(L - 0.3, 0.08, cabW + 0.04), GATE_GLOW, M.Neon)
		strip.Name = "GateGlow"
		strip:AddTag("InteriorLight")
	end
	-- glass wings, folded open along each cabinet (non-colliding)
	for k = 1, 3 do
		local zl = E.minZ + cabW + (k - 1) * (cabW + lane)
		for _, side in { 0, 1 } do
			local z = if side == 0 then zl + 0.12 else zl + lane - 0.12
			local wing = Kit.detail(m, CFrame.new(gx, 2.3, z), V(1.8, 1.7, 0.06), Look.glass, M.Glass)
			wing.Name = "GateWing"
			wing.Transparency = 0.55
		end
	end

	-- the security podium beside the gates
	local px, pz = gx - 4, E.maxZ + 5
	Kit.block(m, CFrame.new(px, 1.9, pz), V(2.4, 3.8, 4.8), Look.walnut, M.Wood).Name = "Podium"
	Kit.detail(m, CFrame.new(px, 3.85, pz), V(2.6, 0.12, 5), Look.nero, M.Marble).Name = "PodiumTop"
	local screen = Kit.detail(
		m,
		CFrame.lookAt(V(px + 0.2, 4.5, pz), V(px + 2, 4.5, pz)),
		V(1.8, 1.1, 0.1),
		Look.black,
		M.SmoothPlastic
	)
	screen.Name = "Screens"
	Art.monitors(screen, 1, { "email" }, Deps.Rng.new("lobby-security"), { pps = 60 })
	local badge =
		Kit.detail(m, CFrame.lookAt(V(px - 1.25, 2.8, pz), V(px - 3, 2.8, pz)), V(2.6, 0.7, 0.06), Look.brass, M.Metal)
	badge.Name = "SecuritySign"
	Kit.sign(badge, Text.get("lobby_security"), {
		color = Look.nero,
		font = Enum.Font.GothamMedium,
		pixelsPerStud = 50,
		padding = 0.12,
	})

	-- the sign over the mouth, on the main hall side
	local sign = Kit.signPanel(
		m,
		CFrame.lookAt(
			V(Plan.HALF_X - 0.12, E.height + 2.6, (E.minZ + E.maxZ) / 2),
			V(0, E.height + 2.6, (E.minZ + E.maxZ) / 2)
		),
		V(16, 2.6, 0.12),
		Text.get("lobby_elevators"),
		Look.nero,
		{ color = Look.brass, font = Enum.Font.GothamMedium, glow = true, pixelsPerStud = 40 }
	)
	sign.Name = "ElevatorSign"
	local sub = Kit.signPanel(
		m,
		CFrame.lookAt(
			V(Plan.HALF_X - 0.12, E.height + 0.95, (E.minZ + E.maxZ) / 2),
			V(0, E.height + 0.95, (E.minZ + E.maxZ) / 2)
		),
		V(16, 0.7, 0.1),
		Text.get("lobby_elevators_sub"),
		Look.nero,
		{ color = Look.marbleVein, font = Enum.Font.Gotham, pixelsPerStud = 40 }
	)
	sub.Name = "ElevatorSign"
	return m
end

---------------------------------------------------------------------------------------------------
-- Elevator hall
---------------------------------------------------------------------------------------------------
-- One car on a long wall. wallZ = the wall's hall-side face; dir = +1 for the south wall (car faces north).
local function car(m: Instance, x: number, wallZ: number, dir: number, index: number)
	local face = if dir > 0 then Enum.NormalId.Back else Enum.NormalId.Front
	local cw, ch = Plan.CAR_W, Plan.CAR_H
	Kit.detail(m, CFrame.new(x, (ch + 0.8) / 2, wallZ + dir * 0.08), V(cw + 1.6, ch + 0.8, 0.16), Look.brass, M.Metal).Name =
		"Surround"
	local door = Kit.block(m, CFrame.new(x, ch / 2, wallZ + dir * 0.2), V(cw, ch, 0.14), Look.steel, M.Metal)
	door.Name = "ElevatorDoor"
	Art.elevatorDoor(door, face)
	Kit.detail(m, CFrame.new(x, 0.02, wallZ + dir * 0.55), V(cw, 0.04, 0.8), Look.steel, M.Metal).Name = "Threshold"
	local ind =
		Kit.detail(m, CFrame.new(x, ch + 1.4, wallZ + dir * 0.1), V(1.8, 0.55, 0.1), Look.black, M.SmoothPlastic)
	ind.Name = "Indicator"
	if dir > 0 then
		ind.CFrame = ind.CFrame * Kit.rotY(180)
	end
	Art.indicator(
		ind,
		Enum.NormalId.Front,
		string.format("%s  %d", if index % 2 == 0 then "▲" else "▼", 2 + index * 3)
	)
end

local function callPanel(m: Instance, x: number, wallZ: number, dir: number): Part
	local cf = CFrame.lookAt(V(x, 4.6, wallZ + dir * 0.1), V(x, 4.6, wallZ + dir * 2))
	local panel = Kit.detail(m, cf, V(0.9, 1.6, 0.12), Look.brass, M.Metal)
	panel.Name = "CallPanel"
	Art.board(panel, Enum.NormalId.Front, "▲", "▼", {
		bg = hex("#2A2620"),
		accent = hex("#FFE7B0"),
		ink = hex("#FFE7B0"),
		align = Enum.TextXAlignment.Center,
		pps = 40,
	})
	Kit.interact(panel, "elevator_panel")
	return panel
end

function Elevators.hall(parent: Instance): Model
	local m = Kit.model(parent, "ElevatorHall")
	local x0, x1, z0, z1, h = E.minX, E.maxX, E.minZ, E.maxZ, E.height
	local w = 1.2
	-- floor, ceiling and walls
	local floor = Geo.box(m, V(x0 + w, -1, z0 - w), V(x1 + w, 0, z1 + w), Look.nero, M.Marble, true)
	floor.Name = "Floor"
	Art.tiles(floor, Enum.NormalId.Top, 4, 4, Look.neroVein, { pps = 10, transparency = 0.7 })
	Geo.box(m, V(x0, 0, (z0 + z1) / 2 - 0.15), V(x1, 0.03, (z0 + z1) / 2 + 0.15), Look.brass, M.Metal).Name =
		"BrassInlay"
	local ceil = Geo.box(m, V(x0, h, z0 - w), V(x1 + w, h + 1, z1 + w), Look.plaster, M.Plaster, true)
	ceil.Name = "Ceiling"
	for _, wz in { z0 - w, z1 } do
		Geo.box(m, V(x0 + w, 0, wz), V(x1, h, wz + w), Look.walnut, M.Wood, true).Name = "Wall"
	end
	Geo.box(m, V(x1, 0, z0 - w), V(x1 + w, h, z1 + w), Look.walnut, M.Wood, true).Name = "Wall"
	-- slim brass reveals in the panelling and a nero skirting on both long walls
	for _, wz in { z0, z1 } do
		local dir = if wz == z0 then 1 else -1
		for _, x in { 56, 64.2, 72, 80 } do
			Geo.box(m, V(x - 0.08, 0, wz + dir * 0.02), V(x + 0.08, h, wz), Look.brass, M.Metal).Name = "Reveal"
		end
		Geo.box(m, V(x0 + w, 0, wz + dir * 0.1), V(x1, 0.8, wz), Look.nero, M.Marble).Name = "Skirting"
	end
	-- linear light slots in the ceiling
	for i, z in { z0 + 4, z1 - 4 } do
		local slot = Geo.box(m, V(x0 + 3, h - 0.06, z - 0.35), V(x1 - 3, h, z + 0.35), Look.coolLight, M.Neon)
		slot.Name = "LightSlot"
		slot:AddTag("InteriorLight")
		if i == 1 then
			Geo.light(slot, "surface", {
				Face = Enum.NormalId.Bottom,
				Range = 16,
				Brightness = 1,
				Angle = 120,
				Color = Look.warmLight,
			})
		end
	end

	-- the cars and their call panels
	for i, x in Plan.cars do
		car(m, x, z1, -1, i)
		car(m, x, z0, 1, i + 3)
	end
	callPanel(m, Plan.panelX, z1, -1)
	callPanel(m, Plan.panelX, z0, 1)

	-- the end wall: FirmColor field, the logo and the company name
	local ex = x1 - 0.1
	local field = Geo.box(m, V(ex - 0.2, 1, z0 + 2), V(ex, h - 1, z1 - 2), Look.firm, M.SmoothPlastic)
	field.Name = "FirmField"
	field:AddTag("FirmColor")
	for _, z in { z0 + 1.8, z1 - 1.8 } do
		local trim = Geo.box(m, V(ex - 0.3, 1, z - 0.2), V(ex, h - 1, z + 0.2), Look.firmAccent, M.Metal)
		trim.Name = "FirmTrim"
		trim:AddTag("FirmAccent")
	end
	local logo = Core.logoPanel(
		m,
		CFrame.lookAt(V(ex - 0.45, 8.4, (z0 + z1) / 2), V(ex - 5, 8.4, (z0 + z1) / 2)),
		V(9, 4.5, 0.3),
		Look.onyx,
		M.SmoothPlastic
	)
	logo.CastShadow = false
	Core.nameBand(
		m,
		CFrame.lookAt(V(ex - 0.35, 4.6, (z0 + z1) / 2), V(ex - 5, 4.6, (z0 + z1) / 2)),
		V(10, 1.2, 0.15),
		Style.ib,
		Look.onyx
	)
	for _, z in { z0 + 2.2, z1 - 2.2 } do
		Furniture.plant(m, V(x1 - 2.2, 0, z), "tall", Style.ib)
	end
	return m
end

return Elevators
