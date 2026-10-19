--!strict
-- Placeholder department floors ("st", "er", "corpbank" in milestone 1): the shared plan in the plain style, with
-- every marker and slot the office system needs, dressed as a floor under renovation (a banner on the welcome wall,
-- an easel sign where the elevator lets you out, cones, tape and a scaffold in the lounge). Later milestones replace
-- each one with its department's own floor (design v3 §14, §19). Bake-safe.

local Deps = require(script.Parent.Deps)
local Layout = require(script.Parent.Layout)
local Floor = require(script.Parent.Floor)
local Geo = require(script.Parent.Geo)
local Art = require(script.Parent.Art)
local Text = require(script.Parent.Text)
local Style = require(script.Parent.Style)

local Kit = Deps.Kit
local Props = Deps.Props
local hex = Deps.Palette.hex
local M = Enum.Material
local V = Vector3.new

local Placeholder = {}

Placeholder.TEMPLATES = { "st", "er", "corpbank" }

local YELLOW = hex("#F2C230")
local INK = hex("#1B1A17")

function Placeholder.supports(templateId: string): boolean
	return table.find(Placeholder.TEMPLATES, templateId) ~= nil
end

local function prop(parent: Instance, id: string, cf: CFrame, opts: { [string]: any }?)
	local ok = Props.tryBuild(id, parent, cf, opts)
	return ok
end

local function tape(parent: Instance, a: Vector3, b: Vector3)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local strip = Kit.detail(parent, CFrame.lookAt(mid, b) * Kit.rotY(90), V(len, 0.35, 0.05), YELLOW, M.Fabric)
	strip.Name = "CautionTape"
	Art.stripes(strip, Enum.NormalId.Front, YELLOW, INK, 9, 0)
	Art.stripes(strip, Enum.NormalId.Back, YELLOW, INK, 9, 0)
end

local function dress(root: Model, templateId: string)
	local m = Kit.model(root, "Renovation")
	local dept = Text.department(templateId)
	local body = string.format(Text.get("renovation_body"), dept)
	local L = Layout.lobby

	-- the banner on the welcome wall's floor side
	local banner =
		Kit.detail(m, CFrame.new(0, 7, L.wallZ + 0.68) * Kit.rotY(180), V(22, 6, 0.12), YELLOW, M.SmoothPlastic)
	banner.Name = "RenovationBanner"
	Art.board(banner, Enum.NormalId.Front, Text.get("renovation_title"), body, {
		bg = YELLOW,
		accent = INK,
		ink = INK,
		font = Enum.Font.GothamBlack,
		bodyFont = Enum.Font.GothamBold,
		align = Enum.TextXAlignment.Center,
	})

	-- an easel sign where the elevator lets you out
	local ex, ez = -9, -45.5
	local board =
		Kit.detail(m, CFrame.new(ex, 3.6, ez) * Kit.rot(-12, 180, 0), V(3.6, 4.4, 0.15), YELLOW, M.SmoothPlastic)
	board.Name = "EaselSign"
	Art.board(board, Enum.NormalId.Front, Text.get("renovation_short"), dept, {
		bg = YELLOW,
		accent = INK,
		ink = INK,
		font = Enum.Font.GothamBlack,
		bodyFont = Enum.Font.GothamBold,
		align = Enum.TextXAlignment.Center,
	})
	for _, sx in { -1, 1 } do
		Kit.detail(m, CFrame.new(ex + sx * 1.4, 2.1, ez + 0.7) * Kit.rot(18, 0, 0), V(0.18, 4.4, 0.18), INK, M.Wood)
	end

	-- the lounge is the work zone: tape, cones, a scaffold, buckets and a dust sheet over the sofa
	local z0, z1 = Layout.lounge.minZ + 1, Layout.lounge.maxZ - 1
	local x0 = Layout.lounge.minX - 1
	tape(m, V(x0, 3.2, z0), V(x0, 3.2, z1))
	tape(m, V(x0, 3.2, z0), V(Layout.lounge.maxX, 3.2, z0))
	for _, z in { z0, (z0 + z1) / 2, z1 } do
		prop(m, "traffic_cone", CFrame.new(x0, 0, z))
	end
	prop(m, "traffic_cone", CFrame.new(-6, 0, -36) * Kit.rotY(30))
	prop(m, "scaffold", CFrame.lookAt(V(78, 0, 12), V(78, 0, 20)))
	for i, p in { V(70.5, 0, 6), V(71.6, 0, 6.8), V(84, 0, -26) } do
		local can = Geo.cyl(
			m,
			CFrame.new(p + V(0, 0.55, 0)),
			1.1,
			0.9,
			if i == 2 then hex("#D9D4C8") else hex("#E8E6E1"),
			M.SmoothPlastic,
			true
		)
		can.Name = "PaintBucket"
	end
	local sheet =
		Kit.detail(m, CFrame.new(84.6, 1.95, -8) * Kit.rot(0, 0, 4), V(3.6, 2.6, 10), hex("#E7E3D8"), M.Fabric)
	sheet.Name = "DustSheet"
end

function Placeholder.build(templateId: string, parent: Instance?): Model
	assert(Placeholder.supports(templateId), "OfficeFloorsA: no placeholder for " .. tostring(templateId))
	local root = Floor.build(templateId, nil, Style.plain)
	root:SetAttribute("Placeholder", true)
	dress(root, templateId)
	root.Parent = parent
	return root
end

return Placeholder
