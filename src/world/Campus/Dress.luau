--!strict
-- Street dressing for Eastbridge (bake-safe): the small things that make the town feel lived in and run down.
--
--   Dress.lamp(parent, x, z, yaw, opts?)            sodium cobra-head lamp (Props; lens tagged "StreetLight").
--                                                   opts.lit = false for a dead lamp, opts.y for raised ground
--   Dress.lantern(parent, cf, lit?)                 wall lantern on a bracket (cf = on the wall, LookVector out)
--   Dress.pole(parent, x, z, rng, o?) -> Vector3    creosote utility pole with a crossarm, insulators, a transformer
--                                                   and stapled flyers; returns the wire attachment point
--   Dress.wire(parent, a, b, sag)                   a sagging cable between two points (3 straight runs)
--   Dress.ironFence(parent, x0, x1, z, h, gates, rng)  wrought-iron fence along X with brick piers at the gates
--   Dress.flyerSheet(parent, cf, w, h, texts, seed) a cluster of stapled flyers on a wall (one carrier part)
--   Dress.poster(parent, cf, i, seed, w?, h?)       one of Text.posters on a wall (Signs.poster)
--   Dress.chainRun(parent, a, b, h, rng, o?)        a long chain-link run between two ground points (one painted mesh
--                                                   panel that collides, posts, top rail, optional barbed wire)
--   Dress.cone(parent, x, z, rng)                   a traffic cone, maybe knocked over
--   Dress.litter(parent, x0, z0, x1, z1, n, rng)    paper, cans and leaves blown into corners

local Deps = require(script.Parent.Deps)
local Plan = require(script.Parent.Plan)
local Geo = require(script.Parent.Geo)
local Paint = require(script.Parent.Paint)
local Text = require(script.Parent.Text)

local Kit = Deps.Kit
local Props = Deps.Props
local Signs = Deps.Signs
local Core = Deps.Gui.Core
local P = Deps.Palette
local C = P.campus
local hex = P.hex
local M = Enum.Material

local Dress = {}

local WALK = Plan.WALK

-- light = false keeps the lens glowing but drops its PointLight (most lamps: Light instances are kept sparse)
export type LampOpts = { lit: boolean?, light: boolean?, y: number?, seed: any? }

function Dress.lamp(parent: Instance, x: number, z: number, yaw: number, opts: LampOpts?): Model
	local o: LampOpts = opts or {}
	local lamp = Props.build("street_lamp_sodium", parent, Plan.cf(x, o.y or WALK, z, yaw), {
		lit = if o.lit == nil then true else o.lit,
		seed = o.seed or string.format("lamp_%d_%d", x, z),
	})
	if o.light == false then
		for _, d in lamp:GetDescendants() do
			if d:IsA("Light") then
				d:Destroy()
			end
		end
	end
	return lamp
end

function Dress.lantern(parent: Instance, cf: CFrame, lit: boolean?): Part
	local iron = hex("#23211F")
	Kit.detail(parent, cf * CFrame.new(0, 0, -0.5), Vector3.new(0.3, 0.3, 1.0), iron, M.Metal)
	Kit.detail(parent, cf * CFrame.new(0, 0.9, -1.1), Vector3.new(1.0, 0.25, 1.0), iron, M.Metal)
	local glass = Kit.detail(
		parent,
		cf * CFrame.new(0, 0.1, -1.1),
		Vector3.new(0.8, 1.3, 0.8),
		if lit == false then hex("#6A5A40") else C.sodium,
		if lit == false then M.Glass else M.Neon
	)
	glass.Name = "Lantern"
	glass.Transparency = 0.2
	glass:AddTag("StreetLight")
	if lit ~= false then
		Kit.light(glass, "point", { Color = C.sodium, Range = 18, Brightness = 1.1 })
	end
	return glass
end

export type PoleOpts = { h: number?, transformer: boolean?, flyers: number?, lean: number? }

function Dress.pole(parent: Instance, x: number, z: number, rng: Deps.RngT, o: PoleOpts?): Vector3
	local opts: PoleOpts = o or {}
	local m = Kit.model(parent, "UtilityPole")
	local h = opts.h or rng:range(26, 30)
	local wood = Geo.vary(hex("#3B2E24"), rng, 0.08)
	local base = Plan.v(x, WALK, z)
	local lean = opts.lean or rng:range(-0.5, 0.5)
	local top = base + Vector3.new(lean, h, lean * 0.6)
	Geo.pipe(m, base + Vector3.new(0, -1, 0), top, 1.1, wood, M.Wood, true)
	-- crossarm with insulators (runs along X so the wires follow the avenue)
	local arm = top + Vector3.new(0, -1.5, 0)
	Kit.detail(m, CFrame.new(arm), Vector3.new(7, 0.5, 0.5), wood, M.Wood)
	for _, dx in { -3, -1.2, 1.2, 3 } do
		Kit.detail(m, CFrame.new(arm + Vector3.new(dx, 0.5, 0)), Vector3.new(0.3, 0.6, 0.3), hex("#3E5A4E"), M.Glass)
	end
	if opts.transformer then
		local tc = Geo.vary(hex("#6E7173"), rng, 0.08)
		Kit.cylinder(m, CFrame.new(top + Vector3.new(0, -6, -1.2)), 3, 1.8, tc, M.Metal).CanCollide = false
	end
	-- staples, tags and flyers at eye height (one carrier with a painted collage)
	local n = opts.flyers or rng:int(1, 3)
	if n > 0 then
		local face = Kit.detail(
			m,
			CFrame.new(base + Vector3.new(0, 5.2, -0.58)),
			Vector3.new(1.1, 2.6, 0.02),
			Color3.new(1, 1, 1),
			M.SmoothPlastic
		)
		face.Transparency = 1
		local gui, W, H = Paint.surface(face, Enum.NormalId.Front, 40)
		local texts = {}
		for _ = 1, n do
			table.insert(texts, rng:pick(Text.flyers))
		end
		Paint.flyers(gui, W, H, rng, texts)
	end
	return arm + Vector3.new(0, 0.8, 0)
end

function Dress.wire(parent: Instance, a: Vector3, b: Vector3, sag: number)
	local mid = (a + b) / 2 - Vector3.new(0, sag, 0)
	local q1 = a:Lerp(mid, 0.55) - Vector3.new(0, sag * 0.25, 0)
	local q2 = b:Lerp(mid, 0.55) - Vector3.new(0, sag * 0.25, 0)
	local col = hex("#1A1A1A")
	for _, seg in { { a, q1 }, { q1, q2 }, { q2, b } } do
		local p = Geo.pipe(parent, seg[1], seg[2], 0.12, col, M.SmoothPlastic, false)
		p.Name = "Wire"
		p.CastShadow = false
	end
end

export type Gate = { x: number, w: number }

-- Wrought-iron fence along X at z: brick piers at both ends of every gate opening and at the fence ends, iron rails
-- between them, and the pickets painted on an invisible collision panel (both faces).
function Dress.ironFence(parent: Instance, x0: number, x1: number, z: number, h: number, gates: { Gate }, rng: Deps.RngT)
	local m = Kit.model(parent, "IronFence")
	local iron = hex("#1F2122")
	table.sort(gates, function(a, b)
		return a.x < b.x
	end)
	local runs: { { number } } = {}
	local cursor = x0
	local piers: { number } = { x0 }
	for _, g in gates do
		table.insert(runs, { cursor, g.x - g.w / 2 })
		table.insert(piers, g.x - g.w / 2)
		table.insert(piers, g.x + g.w / 2)
		cursor = g.x + g.w / 2
	end
	table.insert(runs, { cursor, x1 })
	table.insert(piers, x1)
	table.sort(piers)
	local last = -math.huge
	for _, px in piers do
		if px - last < 0.5 then
			continue
		end
		last = px
		local brick = Geo.brick(rng)
		Geo.lbox(m, px - 1.2, WALK, z - 1.2, px + 1.2, WALK + h + 1.5, z + 1.2, brick, M.Brick)
		Geo.lbox(m, px - 1.5, WALK + h + 1.5, z - 1.5, px + 1.5, WALK + h + 2.1, z + 1.5, hex("#A9A396"), M.Concrete)
	end
	for _, r in runs do
		local a, b = r[1] + 1.2, r[2] - 1.2
		local len = b - a
		if len > 1 then
			local cx = (a + b) / 2
			-- rails
			for _, y in { 1.0, h - 0.6 } do
				Kit.detail(m, Plan.cf(cx, WALK + y, z), Vector3.new(len, 0.25, 0.25), iron, M.Metal)
			end
			-- invisible collision panel carrying the painted pickets
			local panel = Kit.block(m, Plan.cf(cx, WALK + h / 2, z), Vector3.new(len, h, 0.3), iron, M.Metal)
			panel.Name = "FencePanel"
			panel.Transparency = 1
			panel.CastShadow = false
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local gui, W, H = Paint.surface(panel, face, 10)
				for xp = 4, W - 4, 10 do
					local bent = rng:chance(0.04)
					local f = Core.px(gui, xp, if bent then H * 0.25 else 0, 2, H, iron)
					if bent then
						f.Rotation = rng:range(-8, 8)
					else
						Core.px(gui, xp - 1, 0, 4, 4, iron) -- spear tip
					end
				end
			end
			-- a few posts
			local posts = math.max(1, math.floor(len / 10))
			for k = 1, posts - 1 do
				local px = a + len * k / posts
				Kit.detail(m, Plan.cf(px, WALK + h / 2, z), Vector3.new(0.4, h, 0.4), iron, M.Metal)
			end
		end
	end
	return m
end

function Dress.flyerSheet(parent: Instance, cf: CFrame, w: number, h: number, texts: { string }, seed: any): Part
	local p = Kit.detail(parent, cf, Vector3.new(w, h, 0.04), Color3.new(1, 1, 1), M.SmoothPlastic)
	p.Name = "Flyers"
	p.Transparency = 1
	local gui, W, H = Paint.surface(p, Enum.NormalId.Front, 24)
	Paint.flyers(gui, W, H, Deps.Rng.new(seed), texts)
	return p
end

function Dress.poster(parent: Instance, cf: CFrame, i: number, seed: any, w: number?, h: number?): Model
	local spec = Text.posters[((i - 1) % #Text.posters) + 1]
	local rng = Deps.Rng.new(seed)
	local palettes = {
		{ hex("#E9E2CF"), hex("#C8553D"), hex("#1A1A1A") },
		{ hex("#F2D95C"), hex("#24262A"), hex("#24262A") },
		{ hex("#2F5A3A"), hex("#E9E2CF"), hex("#F4F1EA") },
		{ hex("#1F2A44"), hex("#C9A13B"), hex("#F4F1EA") },
	}
	return Signs.poster(parent, cf, {
		title = spec.title,
		body = spec.body,
		colors = rng:pick(palettes),
		width = w or 3.2,
		height = h or 4.4,
		seed = seed,
	})
end

export type ChainOpts = { barbed: boolean?, postEvery: number?, signs: { string }? }

function Dress.chainRun(parent: Instance, a: Vector3, b: Vector3, h: number, rng: Deps.RngT, o: ChainOpts?): Model
	local opts: ChainOpts = o or {}
	local m = Kit.model(parent, "ChainLink")
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local mid = Vector3.new((a.X + b.X) / 2, a.Y, (a.Z + b.Z) / 2)
	local frame = CFrame.lookAt(mid, mid + flat) * CFrame.Angles(0, math.rad(90), 0) -- local X runs a -> b
	local metal = Geo.vary(C.chainlink, rng, 0.05)
	local panel = Kit.block(m, frame * CFrame.new(0, h / 2, 0), Vector3.new(len, h, 0.2), metal, M.Metal)
	panel.Name = "Mesh"
	panel.Transparency = 1
	panel.CastShadow = false
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui, W, H = Paint.surface(panel, face, 4, { maxDistance = 260 })
		Deps.Gui.Art.chainlink(gui, W, H, 7, metal)
	end
	local every = opts.postEvery or 10
	local posts = math.max(1, math.floor(len / every + 0.5))
	for i = 0, posts do
		local x = -len / 2 + len * i / posts
		local tilt = if rng:chance(0.15) then rng:range(-6, 6) else 0
		local p = Kit.block(
			m,
			frame * CFrame.new(x, h / 2, 0) * CFrame.Angles(math.rad(tilt), 0, 0),
			Vector3.new(0.35, h + 0.4, 0.35),
			Kit.shade(metal, -0.15),
			M.Metal
		)
		p.Name = "Post"
		p.CanCollide = false
	end
	Kit.detail(m, frame * CFrame.new(0, h - 0.1, 0), Vector3.new(len, 0.2, 0.2), metal, M.Metal).Name = "TopRail"
	if opts.barbed then
		for _, dz in { -0.25, 0.25 } do
			Kit.detail(m, frame * CFrame.new(0, h + 0.5, dz), Vector3.new(len, 0.08, 0.08), hex("#5A5A5A"), M.Metal).Name =
				"Barbed"
		end
	end
	local signs = opts.signs
	for i, t in signs or {} :: { string } do
		local x = -len / 2 + len * (i - 0.5) / #(signs :: { string })
		local sgn = Kit.detail(m, frame * CFrame.new(x, h * 0.55, -0.2), Vector3.new(3, 1.6, 0.06), hex("#E9E2CF"), M.Metal)
		Kit.sign(sgn, t, { font = Enum.Font.Highway, color = hex("#8A2C2C"), pixelsPerStud = 40, padding = 0.1 })
	end
	return m
end

function Dress.cone(parent: Instance, x: number, z: number, rng: Deps.RngT): Model
	local cf = Plan.cf(x, WALK, z, rng:range(0, 360))
	if rng:chance(0.3) then
		cf = Plan.cf(x, WALK + 0.55, z, rng:range(0, 360)) * CFrame.Angles(math.rad(90), 0, 0)
	end
	return Props.build("traffic_cone", parent, cf, { seed = string.format("cone_%d_%d", x, z) })
end

function Dress.litter(parent: Instance, x0: number, z0: number, x1: number, z1: number, n: number, rng: Deps.RngT)
	local colors = { C.paper, hex("#B8B0A0"), hex("#6B5A3A"), hex("#8A3B2E"), hex("#9C9C9C"), hex("#5E4A30") }
	for _ = 1, n do
		local x, z = rng:range(x0, x1), rng:range(z0, z1)
		local s = rng:range(0.4, 1.1)
		local p = Kit.detail(
			parent,
			Plan.cf(x, WALK + 0.03, z, rng:range(0, 360)),
			Vector3.new(s, 0.05, s * rng:range(0.6, 1.2)),
			rng:pick(colors),
			M.SmoothPlastic
		)
		p.Name = "Litter"
		p.CastShadow = false
	end
end

return Dress
