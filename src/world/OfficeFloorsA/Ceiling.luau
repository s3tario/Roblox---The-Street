--!strict
-- Columns and everything overhead.
--   IB style (the owner's photo): round concrete columns with brass capital bands, an exposed concrete slab, silver
--   round and rectangular ductwork with joint rings and hangers, black cable trays and conduit, a red sprinkler
--   main, and black cylinder pendants on rods over the desk pods (a few carry SpotLights).
--   Plain style: plain columns and flush glowing ceiling panels.
-- Lamp parts are tagged "InteriorLight". Bake-safe.

local Deps = require(script.Parent.Deps)
local Layout = require(script.Parent.Layout)
local Furniture = require(script.Parent.Furniture)
local Geo = require(script.Parent.Geo)
local Style = require(script.Parent.Style)

local Kit = Deps.Kit
local M = Enum.Material
local V = Vector3.new

local Ceiling = {}

local H = Layout.HEIGHT
local X0, X1 = -63, 88 -- service runs span the open plan (the boardroom glass stops them in the west)

local function column(m: Instance, pos: Vector3, style: Style.Style)
	local d = Layout.COLUMN_D
	local shaft = Geo.cyl(
		m,
		CFrame.new(pos.X, H / 2, pos.Z),
		H,
		d,
		style.column,
		if style.plain then M.SmoothPlastic else M.Concrete,
		true
	)
	shaft.Name = "Column"
	if style.plain then
		return
	end
	local band = Geo.cyl(m, CFrame.new(pos.X, H - 1.9, pos.Z), 0.75, d + 0.22, style.columnBand, M.Metal)
	band.Reflectance = 0.18
	band.Name = "CapitalBand"
	local thin = Geo.cyl(m, CFrame.new(pos.X, H - 2.75, pos.Z), 0.16, d + 0.16, style.columnBand, M.Metal)
	thin.Reflectance = 0.18
	Geo.cyl(m, CFrame.new(pos.X, 0.2, pos.Z), 0.4, d + 0.3, Kit.shade(style.column, -0.3), M.Concrete)
end

local function roundDuct(m: Instance, z: number, y: number, d: number, step: number, style: Style.Style)
	local duct = Geo.pipe(m, V(X0, y, z), V(X1, y, z), d, style.duct, M.Metal)
	duct.Reflectance = 0.14
	duct.Name = "Duct"
	local x = X0 + step / 2
	local i = 0
	while x < X1 do
		i += 1
		Geo.pipe(m, V(x - 0.2, y, z), V(x + 0.2, y, z), d + 0.22, style.ductJoint, M.Metal)
		if i % 2 == 1 and d > 2 then
			Geo.pipe(m, V(x, y + d / 2, z), V(x, H, z), 0.1, style.tray, M.Metal)
		end
		x += step
	end
end

local function rectDuct(
	m: Instance,
	z0: number,
	z1: number,
	y0: number,
	y1: number,
	x0: number,
	x1: number,
	step: number,
	style: Style.Style
)
	local duct = Geo.box(m, V(x0, y0, z0), V(x1, y1, z1), style.duct, M.Metal)
	duct.Reflectance = 0.12
	duct.Name = "Duct"
	local x = x0 + step / 2
	while x < x1 do
		Geo.box(m, V(x - 0.15, y0 - 0.12, z0 - 0.12), V(x + 0.15, y1 + 0.05, z1 + 0.12), style.ductJoint, M.Metal)
		x += step
	end
end

local function tray(m: Instance, z: number, x0: number, x1: number, style: Style.Style)
	local y = 15.85
	Geo.box(m, V(x0, y, z - 1), V(x1, y + 0.1, z + 1), style.tray, M.Metal).Name = "CableTray"
	Geo.box(m, V(x0, y + 0.1, z - 1), V(x1, y + 0.5, z - 0.92), style.tray, M.Metal)
	Geo.box(m, V(x0, y + 0.1, z + 0.92), V(x1, y + 0.5, z + 1), style.tray, M.Metal)
	Geo.box(m, V(x0 + 1, y + 0.1, z - 0.7), V(x1 - 1, y + 0.36, z + 0.5), Color3.fromRGB(46, 48, 52), M.Rubber).Name =
		"Cables"
end

function Ceiling.build(parent: Instance, style: Style.Style): Model
	local m = Kit.model(parent, "Ceiling")
	for _, c in Layout.columns do
		column(m, c, style)
	end

	if style.plain then
		-- flush light panels over the open plan and the corridor
		local n = 0
		for _, z in { -20, 8, 34 } do
			for _, x in { -50, -28, -6, 16, 38 } do
				n += 1
				local p = Geo.box(m, V(x - 3, H - 0.08, z - 1.5), V(x + 3, H, z + 1.5), style.lamp, M.Neon)
				p.Name = "LightPanel"
				p:AddTag("InteriorLight")
				if n % 4 == 1 then
					Geo.light(
						p,
						"surface",
						{ Face = Enum.NormalId.Bottom, Range = 18, Brightness = 1, Angle = 120, Color = style.lamp }
					)
				end
			end
		end
		return m
	end

	-- ductwork, trays, conduit and sprinklers
	roundDuct(m, -10, 14.1, 2.8, 16, style)
	roundDuct(m, -34, 14.6, 1.8, 21, style)
	rectDuct(m, 14.2, 17.8, 14.2, 16, X0, X1, 17, style)
	rectDuct(m, 35.2, 37.6, 15, 16.3, Layout.corridor.minX + 1, Layout.corridor.maxX - 0.5, 24, style)
	tray(m, -2, X0, X1, style)
	tray(m, 26.5, X0, Layout.boss.minX - 1, style)
	Geo.pipe(m, V(X0, 16.45, -14), V(X1, 16.45, -14), 0.22, style.tray, M.Metal).Name = "Conduit"
	Geo.pipe(m, V(X0, 16.15, -14.6), V(X1, 16.15, -14.6), 0.22, style.tray, M.Metal).Name = "Conduit"
	Geo.pipe(m, V(X0, 16.3, 6), V(X1, 16.3, 6), 0.35, style.pipeRed, M.Metal).Name = "Sprinkler"

	-- pendants over every desk pod (the centre one of each lights the pod) and down the corridor
	for _, centre in Layout.benches do
		for i = -1, 1 do
			Furniture.pendant(
				m,
				V(centre.X + i * Layout.WS_WIDTH, H, centre.Z),
				9.6,
				style,
				if i == 0 then { kind = "spot", range = 20, brightness = 1.6, angle = 120 } else nil
			)
		end
	end
	for i, x in { -76, -46, -16, 14, 44 } do
		Furniture.pendant(
			m,
			V(x, H, 33.4),
			10.2,
			style,
			if i == 2 or i == 4 then { kind = "spot", range = 18, brightness = 1.2, angle = 110 } else nil
		)
	end
	return m
end

return Ceiling
