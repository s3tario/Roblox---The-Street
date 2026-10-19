--!strict
-- Open-plan desk pods (contracts §11; World.floorSlots). A bench is the shared structure (divider, leg panels and
-- two end panels: terrazzo in the IB style); each workstation on it is its own DeskSlot model:
--   Model "Desk_NN"  attribute DeskSlot = n, tag "DeskSlot", PrimaryPart "Top" (the desk surface, LookVector = the
--                    way the sitter faces, toward the monitors)
--     Top            work_desk interact
--     Screens*       4-6 monitors in 2-4 bezel panels (IB) / one dual panel (plain); the bottom-centre panel of every
--                    even-numbered desk carries the terminal interact
--     Chair          task chair model (OfficeService NPCs sit on it)
--     Nameplate      tent card facing the aisle; also the desk's housing_panel (Context "desk")
--     DecorSlot x5   3 x SlotKind "plaque" (plaque_1..3, newest first) + 2 x "desk_item" (desk_item, desk_monitor)

local Deps = require(script.Parent.Deps)
local Layout = require(script.Parent.Layout)
local Markers = require(script.Parent.Markers)
local Furniture = require(script.Parent.Furniture)
local Art = require(script.Parent.Art)
local Text = require(script.Parent.Text)
local Style = require(script.Parent.Style)

local Kit = Deps.Kit
local Rng = Deps.Rng
local M = Enum.Material

type Rng = typeof(Rng.new(0))

local Desks = {}

Desks.SCREEN_W = 1.55
Desks.SCREEN_H = 0.95
Desks.MON_Z = -1.55 -- monitor plane (desk-local, toward the divider)
Desks.ROW_Y = 1.725 -- bottom row centre above the desk surface
Desks.ROW_GAP = 1.0

local W, D = Layout.WS_WIDTH, Layout.WS_DEPTH

-- One bezel panel holding `count` screens. Its inner edge sits at desk-local x0 on the monitor plane; it extends
-- toward dir (+1 = the sitter's right) and turns `angle` degrees toward the sitter.
local function panel(
	m: Instance,
	desk: CFrame,
	x0: number,
	dir: number,
	angle: number,
	count: number,
	y: number,
	kinds: { string },
	rng: Rng,
	style: Style.Style
): Part
	local w = count * Desks.SCREEN_W
	local t = math.rad(angle)
	local centre = Vector3.new(x0 + dir * (w / 2) * math.cos(t), y, Desks.MON_Z + (w / 2) * math.sin(t))
	local normal = Vector3.new(-dir * math.sin(t), 0, math.cos(t))
	local p = Kit.detail(
		m,
		desk * CFrame.lookAt(centre, centre + normal),
		Vector3.new(w, Desks.SCREEN_H, 0.1),
		style.bezel,
		M.SmoothPlastic
	)
	p.Name = "Screens"
	p.CanQuery = true
	Art.monitors(p, count, kinds, rng)
	return p
end

local function centred(
	m: Instance,
	desk: CFrame,
	count: number,
	y: number,
	kinds: { string },
	rng: Rng,
	style: Style.Style
): Part
	return panel(m, desk, -count * Desks.SCREEN_W / 2, 1, 0, count, y, kinds, rng, style)
end

local function pickKinds(rng: Rng, n: number): { string }
	local out = {}
	for _ = 1, n do
		table.insert(out, rng:pick(Art.screenKinds))
	end
	return out
end

-- Monitor arrays: odd desks alternate 4 (two angled pairs) and 5 (3 + 2); even desks get 6 (3 + 3) and the terminal.
local function monitorsIb(m: Model, desk: CFrame, slot: number, rng: Rng, style: Style.Style): (Part?, number)
	local y0 = Desks.ROW_Y
	local y1 = y0 + Desks.ROW_GAP
	if slot % 2 == 1 and slot % 4 == 1 then
		panel(m, desk, -0.03, -1, 10, 2, y0, pickKinds(rng, 2), rng, style)
		panel(m, desk, 0.03, 1, 10, 2, y0, pickKinds(rng, 2), rng, style)
		return nil, 4
	end
	local half = Desks.SCREEN_W / 2 + 0.03
	local mid = centred(m, desk, 1, y0, { if slot % 2 == 0 then "terminal" else rng:pick(Art.screenKinds) }, rng, style)
	panel(m, desk, -half, -1, 16, 1, y0, pickKinds(rng, 1), rng, style)
	panel(m, desk, half, 1, 16, 1, y0, pickKinds(rng, 1), rng, style)
	local top = if slot % 2 == 0 then 3 else 2
	centred(m, desk, top, y1, pickKinds(rng, top), rng, style)
	return if slot % 2 == 0 then mid else nil, 3 + top
end

local function monitorsPlain(m: Model, desk: CFrame, slot: number, rng: Rng, style: Style.Style): (Part?, number)
	local p = centred(m, desk, 2, Desks.ROW_Y - 0.2, pickKinds(rng, 2), rng, style)
	return if slot % 2 == 0 then p else nil, 2
end

-- One workstation (a DeskSlot model) at ws.cf (desk surface centre).
function Desks.workstation(parent: Instance, ws: Layout.Workstation, style: Style.Style, seed: any): Model
	local rng = Rng.new(seed)
	local desk = ws.cf
	local m = Kit.model(parent, string.format("Desk_%02d", ws.slot))
	m:SetAttribute("DeskSlot", ws.slot)
	m:AddTag("DeskSlot")

	local top =
		Kit.block(m, desk * CFrame.new(0, -0.06, 0), Vector3.new(W - 0.04, 0.12, D), style.deskTop, M.SmoothPlastic)
	top.Name = "Top"
	Kit.interact(top, "work_desk")
	m.PrimaryPart = top

	local terminal: Part?, screens: number
	if style.plain then
		terminal, screens = monitorsPlain(m, desk, ws.slot, rng, style)
	else
		terminal, screens = monitorsIb(m, desk, ws.slot, rng, style)
	end
	if terminal then
		terminal.Name = "TerminalScreens"
		Kit.interact(terminal, "terminal")
	end
	m:SetAttribute("Monitors", screens)
	local poleH = if screens > 4 then 3.2 else 2.3
	Kit.detail(
		m,
		desk * CFrame.new(0, poleH / 2, Desks.MON_Z - 0.18),
		Vector3.new(0.22, poleH, 0.16),
		style.stand,
		M.Metal
	)

	-- desk pad with the keyboard and mouse drawn on it (one part instead of three)
	local pad =
		Kit.detail(m, desk * CFrame.new(0.3, 0.04, 0.75), Vector3.new(3.6, 0.08, 1.15), style.keyboard, M.Leather)
	pad.Name = "DeskPad"
	Art.keyboard(pad)

	-- the chair, pulled out a little and turned a touch so rows don't look stamped
	local yaw = rng:range(-14, 14)
	local pull = rng:range(2.9, 3.5)
	Furniture.taskChair(m, desk * CFrame.new(rng:range(-0.4, 0.4), -Layout.DESK_HEIGHT, pull) * Kit.rotY(yaw), {
		mesh = style.chairMesh,
		seat = style.chairSeat,
		base = style.chairBase,
	})

	-- tent-card nameplate facing the aisle; the owner customizes the desk from it
	local plate = Markers.nameplate(
		m,
		desk * CFrame.new(-2.55, 0.22, D / 2 - 0.28) * Kit.rotY(180),
		Vector3.new(1.5, 0.42, 0.06),
		Text.get("desk_nameplate")
	)
	Kit.interact(plate, "housing_panel", { Context = "desk" })

	-- 3 deal plaques along the left of the desk (newest in plaque_1), facing the aisle
	for k = 1, 3 do
		Markers.surfaceSlot(
			m,
			"plaque",
			desk * CFrame.new(-3.0 + (k - 1) * 0.95, 0, -0.62) * Kit.rotY(180),
			Vector3.new(0.9, 0.2, 0.42),
			{ id = "plaque_" .. k, index = k }
		)
	end
	Markers.surfaceSlot(m, "desk_item", desk * CFrame.new(2.55, 0, 0.95) * Kit.rotY(180), Vector3.new(1.1, 0.2, 1.1), {
		id = "desk_item",
		index = 1,
		maxWidth = 1.4,
		maxDepth = 1.4,
	})
	Markers.surfaceSlot(m, "desk_item", desk * CFrame.new(2.85, 0, -0.75) * Kit.rotY(180), Vector3.new(1, 0.2, 1), {
		id = "desk_monitor",
		index = 2,
		maxWidth = 1.2,
		maxDepth = 1.2,
	})
	return m
end

-- The shared bench structure under 2 x PER_SIDE workstations.
function Desks.bench(parent: Instance, index: number, centre: Vector3, style: Style.Style): Model
	local m = Kit.model(parent, "Bench_" .. index)
	local L = Layout.BENCH_LENGTH
	local depth = D * 2 + Layout.DIVIDER
	local divider = Kit.block(
		m,
		CFrame.new(centre.X, 2.15, centre.Z),
		Vector3.new(L, 4.3, Layout.DIVIDER),
		style.divider,
		style.dividerMat
	)
	divider.Name = "Divider"
	for _, sx in { -1, 1 } do
		local endPanel = Kit.block(
			m,
			CFrame.new(centre.X + sx * (L / 2 + 0.4), 1.45, centre.Z),
			Vector3.new(0.8, 2.9, depth + 0.3),
			style.endPanel,
			style.endPanelMat
		)
		endPanel.Name = "EndPanel"
		if style.terrazzo then
			Art.terrazzo(
				endPanel,
				if sx > 0 then Enum.NormalId.Right else Enum.NormalId.Left,
				Deps.Hash.u32("terrazzo", index, sx)
			)
			Art.terrazzo(endPanel, Enum.NormalId.Top, Deps.Hash.u32("terrazzo-top", index, sx), { density = 4 })
			Art.terrazzo(endPanel, Enum.NormalId.Front, Deps.Hash.u32("terrazzo-f", index, sx), { density = 4 })
			Art.terrazzo(endPanel, Enum.NormalId.Back, Deps.Hash.u32("terrazzo-b", index, sx), { density = 4 })
		end
		Kit.block(
			m,
			CFrame.new(centre.X + sx * W / 2, 1.35, centre.Z),
			Vector3.new(0.25, 2.7, depth - 0.4),
			style.deskFrame,
			M.SmoothPlastic
		).Name =
			"Leg"
	end
	return m
end

-- Every bench and workstation of the plan. Returns the desk models in slot order.
function Desks.build(parent: Instance, style: Style.Style): { Model }
	local folder = Kit.folder(parent, "Desks")
	for i, centre in Layout.benches do
		Desks.bench(folder, i, centre, style)
	end
	local out: { Model } = {}
	for _, ws in Layout.workstations() do
		table.insert(out, Desks.workstation(folder, ws, style, Deps.Hash.u32(style.id, "desk", ws.slot)))
	end
	return out
end

return Desks
