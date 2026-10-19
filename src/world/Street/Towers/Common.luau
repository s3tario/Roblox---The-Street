--!strict
-- Shared pieces for the company towers (Street/Towers/*): the build context, neighbour-aware facades, tier stacks
-- with setback ledges, crowns, and the branding every tower gets (a CompanyLogo-tagged fascia for single-company
-- towers, a building name plus a tenant directory board for multi-tenant towers). Bake-safe.
--
-- Lot space: see Street/Mass (origin front-centre on the sidewalk, -Z out of the front, +Z into the building).

local Deps = require(script.Parent.Parent.Deps)
local Look = require(script.Parent.Parent.Look)
local Mass = require(script.Parent.Parent.Mass)
local Plan = require(script.Parent.Parent.Plan)
local Brand = require(script.Parent.Parent.Brand)
local Entrance = require(script.Parent.Parent.Entrance)
local Text = require(script.Parent.Parent.Text)

local Kit = Deps.Kit
local Rng = Deps.Rng
local M = Enum.Material

local Common = {}

export type TowerDef = {
	id: string,
	label: string,
	style: string,
	company: string?,
	picker: { string }?,
	door: string?,
	anchor: string?,
}

export type Ctx = {
	m: Model,
	frame: CFrame,
	lot: Plan.Lot,
	def: TowerDef,
	rects: { Plan.Rect },
	rid: string, -- this building's rect id (ignored when testing neighbours)
	seed: string,
	rng: Deps.RngT,
	w: number,
	d: number,
	h: number,
	variant: number,
}

export type TierSpec = {
	inset: number?, -- side inset from the lot edges
	front: number?, -- front setback (default inset)
	back: number?, -- back setback (default inset)
	top: number, -- lot height of the tier's roof
	look: string | Mass.FacadeLook,
	ledge: Color3?, -- setback ledge colour (default: the look's pier colour)
	ledgeMat: Enum.Material?,
	trim: Color3?, -- metal edge on the ledge
	lit: number?,
	blank: { [string]: boolean }?, -- faces forced blank (party walls, painted ghost signs)
}

function Common.box(x0: number, x1: number, z0: number, z1: number, y0: number, y1: number): Mass.Box
	return { x0 = x0, x1 = x1, z0 = z0, z1 = z1, y0 = y0, y1 = y1 }
end

-- Height (lot y) below which each face of `b` is hidden by neighbours. Fronts always face the street; backs only
-- get windows when they face open ground (nobody can see the back of a tower above its neighbours).
function Common.hidden(ctx: Ctx, b: Mass.Box): { [string]: number }
	local out: { [string]: number } = { front = 0 }
	for _, side in { "left", "right", "back" } do
		local minH = math.huge
		for _, t in { 0.12, 0.5, 0.88 } do
			local lx, lz
			if side == "left" then
				lx, lz = b.x0 - 3, b.z0 + (b.z1 - b.z0) * t
			elseif side == "right" then
				lx, lz = b.x1 + 3, b.z0 + (b.z1 - b.z0) * t
			else
				lx, lz = b.x0 + (b.x1 - b.x0) * t, b.z1 + 3
			end
			local wp = ctx.frame:PointToWorldSpace(Vector3.new(lx, 0, lz))
			local hgt = if math.abs(wp.X) > Plan.EDGE or math.abs(wp.Z) > Plan.EDGE
				then math.huge
				else Plan.heightAt(ctx.rects, wp.X, wp.Z, ctx.rid)
			minH = math.min(minH, hgt)
		end
		if side == "back" then
			out[side] = if minH <= 0 then 0 else math.huge
		else
			out[side] = minH
		end
	end
	return out
end

local function lookOf(l: string | Mass.FacadeLook, seed: string): Mass.FacadeLook
	local base = if type(l) == "string" then Mass.look(l) else l
	return Mass.vary(base, seed)
end
Common.lookOf = lookOf

-- Stacks tiers from y0 upward. Each tier is a core + facades; each setback gets a ledge. Returns the last box.
function Common.stack(ctx: Ctx, y0: number, tiers: { TierSpec }): Mass.Box
	local y = y0
	local w, d = ctx.w, ctx.d
	local last: Mass.Box = Common.box(-w / 2, w / 2, 0, d, y0, y0)
	for i, t in tiers do
		local inset = t.inset or 0
		local b = Common.box(-w / 2 + inset, w / 2 - inset, t.front or inset, d - (t.back or inset), y, t.top)
		local look = lookOf(t.look, ctx.seed .. ":look" .. i)
		local hidden = Common.hidden(ctx, b)
		if t.blank then
			for side, on in t.blank do
				if on then
					hidden[side] = math.huge
				end
			end
		end
		Mass.tier(ctx.m, ctx.frame, b, look, {
			hidden = hidden,
			seed = ctx.seed .. ":tier" .. i,
			name = "Tier" .. i,
			noBottom = true,
			noTop = true,
			lit = t.lit,
		})
		-- ledge (setback roof edge) at the top of the tier
		local ledge = t.ledge or look.pier
		Mass.cornice(
			ctx.m,
			ctx.frame,
			b,
			t.top - 0.4,
			1.6,
			if look.curtain then 0.6 else look.depth + 0.4,
			ledge,
			t.ledgeMat or look.pierMat
		)
		if t.trim then
			Mass.cornice(
				ctx.m,
				ctx.frame,
				b,
				t.top + 1.2,
				0.35,
				if look.curtain then 0.7 else look.depth + 0.5,
				t.trim,
				M.Metal
			)
		end
		last = b
		y = t.top
	end
	return last
end

---------------------------------------------------------------------------------------------------
-- Crowns
---------------------------------------------------------------------------------------------------
local function detail(parent: Instance, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material): Part
	return Kit.detail(parent, cf, size, color, mat)
end

-- A neon outline band around a box at height y (crown lights). Tagged StreetLight (exterior light).
function Common.lightBand(ctx: Ctx, b: Mass.Box, y: number, color: Color3, over: number?)
	local o = over or 0.5
	local band = Mass.slab(
		ctx.m,
		ctx.frame,
		Common.box(b.x0 - o, b.x1 + o, b.z0 - o, b.z1 + o, y, y + 0.6),
		color,
		M.Neon,
		false
	)
	band.CastShadow = false
	band:AddTag("StreetLight")
end

-- Floodlights at the corners of a setback roof aimed up at the crown (sparing: two lights per crown).
function Common.floodlights(ctx: Ctx, b: Mass.Box, color: Color3?)
	for _, sx in { -1, 1 } do
		local fix = Kit.detail(
			ctx.m,
			ctx.frame * CFrame.new(sx * (b.x1 - b.x0) * 0.3 + (b.x0 + b.x1) / 2, b.y1 + 0.4, b.z0 + 1.2),
			Vector3.new(1, 0.6, 1),
			Look.iron,
			M.Metal
		)
		fix.Name = "Floodlight"
		Kit.light(fix, "spot", {
			Face = Enum.NormalId.Top,
			Angle = 50,
			Range = 60,
			Brightness = 2,
			Color = color or Look.warmLight,
		})
	end
end

-- Stepped Art Deco crown with a gold spire. Returns the top height.
function Common.decoCrown(ctx: Ctx, b: Mass.Box, gold: Color3, glow: Color3): number
	local y = b.y1
	local cx, cz = (b.x0 + b.x1) / 2, (b.z0 + b.z1) / 2
	local w, d = b.x1 - b.x0, b.z1 - b.z0
	local steps = { { 0.78, 9 }, { 0.56, 8 }, { 0.36, 7 } }
	for i, s in steps do
		local sw, sd = w * s[1], d * s[1]
		local part = Mass.slab(
			ctx.m,
			ctx.frame,
			Common.box(cx - sw / 2, cx + sw / 2, cz - sd / 2, cz + sd / 2, y, y + s[2]),
			if i == 1 then Look.limestone else gold,
			if i == 1 then M.Limestone else M.Foil,
			false
		)
		part.Name = "Crown" .. i
		-- glowing slots on the front of each step
		local slot = detail(
			ctx.m,
			ctx.frame * CFrame.new(cx, y + s[2] * 0.5, cz - sd / 2 - 0.06),
			Vector3.new(sw * 0.7, s[2] * 0.35, 0.12),
			glow,
			M.Neon
		)
		slot.CastShadow = false
		slot:AddTag("StreetLight")
		y += s[2]
	end
	local spireH = math.min(42, 680 - (ctx.frame.Position.Y + y))
	Kit.cylinder(ctx.m, ctx.frame * CFrame.new(cx, y + spireH * 0.3, cz), spireH * 0.6, 3, gold, M.Foil, {
		CanCollide = false,
	})
	Kit.cylinder(ctx.m, ctx.frame * CFrame.new(cx, y + spireH * 0.8, cz), spireH * 0.4, 1.2, gold, M.Foil, {
		CanCollide = false,
	})
	local tip = Kit.ball(ctx.m, ctx.frame * CFrame.new(cx, y + spireH, cz), 1.6, glow, M.Neon, {
		CanCollide = false,
		CastShadow = false,
	})
	tip:AddTag("StreetLight")
	return y + spireH
end

-- A glass lantern box on the roof, lit from inside. Returns the top height.
function Common.lantern(
	ctx: Ctx,
	b: Mass.Box,
	inset: number,
	h: number,
	glass: Color3,
	glow: Color3,
	frame: Color3
): number
	local box = Common.box(b.x0 + inset, b.x1 - inset, b.z0 + inset, b.z1 - inset, b.y1, b.y1 + h)
	local core = Mass.slab(ctx.m, ctx.frame, box, glow, M.Neon, false)
	core.Name = "LanternCore"
	core.Transparency = 0.35
	core.CastShadow = false
	core:AddTag("StreetLight")
	local shell = Mass.slab(
		ctx.m,
		ctx.frame,
		Common.box(box.x0 - 0.3, box.x1 + 0.3, box.z0 - 0.3, box.z1 + 0.3, box.y0, box.y1),
		glass,
		M.Glass,
		false
	)
	shell.Transparency = 0.45
	shell.Reflectance = 0.3
	Mass.cornice(ctx.m, ctx.frame, box, box.y1, 1.2, 0.8, frame, M.Metal)
	return box.y1 + 1.2
end

-- A copper mansard (four sloped faces) over a box. Returns the top height.
function Common.mansard(ctx: Ctx, b: Mass.Box, h: number, color: Color3): number
	local inset = h * 0.6
	local w, d = b.x1 - b.x0, b.z1 - b.z0
	local cx, cz = (b.x0 + b.x1) / 2, (b.z0 + b.z1) / 2
	local y = b.y1 + h / 2
	Mass.slab(
		ctx.m,
		ctx.frame,
		Common.box(b.x0 + inset, b.x1 - inset, b.z0 + inset, b.z1 - inset, b.y1, b.y1 + h),
		color,
		M.Metal,
		false
	)
	-- WedgePart: full height at its +Z, sloping to the front (-Z)
	local faces: { { cf: CFrame, len: number } } = {
		{ cf = CFrame.new(cx, y, b.z0 + inset / 2), len = w },
		{ cf = CFrame.new(cx, y, b.z1 - inset / 2) * CFrame.Angles(0, math.pi, 0), len = w },
		{ cf = CFrame.new(b.x0 + inset / 2, y, cz) * CFrame.Angles(0, math.pi / 2, 0), len = d },
		{ cf = CFrame.new(b.x1 - inset / 2, y, cz) * CFrame.Angles(0, -math.pi / 2, 0), len = d },
	}
	for _, f in faces do
		Kit.wedge(ctx.m, ctx.frame * f.cf, Vector3.new(f.len, h, inset), color, M.Metal, { CanCollide = false })
	end
	-- dormer lights
	local dormer = detail(
		ctx.m,
		ctx.frame * CFrame.new(cx, y - h * 0.1, b.z0 + inset * 0.45),
		Vector3.new(w * 0.5, h * 0.25, 0.2),
		Look.lampGlow,
		M.Neon
	)
	dormer.CastShadow = false
	dormer:AddTag("LitWindow")
	return b.y1 + h
end

-- A sloped glass crown rising toward the back. Returns the top height.
function Common.slope(ctx: Ctx, b: Mass.Box, h: number, glass: Color3, edge: Color3): number
	local w, d = b.x1 - b.x0, b.z1 - b.z0
	local cf = ctx.frame * CFrame.new((b.x0 + b.x1) / 2, b.y1 + h / 2, (b.z0 + b.z1) / 2)
	local wedge = Kit.wedge(ctx.m, cf, Vector3.new(w, h, d), glass, M.Glass, { CanCollide = false, Reflectance = 0.35 })
	wedge.Name = "SlopedCrown"
	local rise = math.atan2(h, d)
	local strip = Kit.detail(
		ctx.m,
		cf * CFrame.Angles(-rise, 0, 0) * CFrame.new(0, 0.1, 0),
		Vector3.new(0.6, 0.2, math.sqrt(h * h + d * d)),
		edge,
		M.Neon
	)
	strip.CastShadow = false
	strip:AddTag("StreetLight")
	return b.y1 + h
end

-- Bronze lanterns either side of a doorway (wall mounted on the facade plane z = 0, at +/- x).
function Common.lanterns(ctx: Ctx, x: number, y: number, z: number?)
	for _, sx in { -1, 1 } do
		local cf = ctx.frame * CFrame.new(sx * x, y, (z or 0) - 0.6)
		Kit.detail(ctx.m, cf * CFrame.new(0, 0, 0.4), Vector3.new(0.5, 0.5, 0.8), Look.bronzeDark, M.Metal)
		local lamp =
			Kit.detail(ctx.m, cf * CFrame.new(0, -0.3, -0.3), Vector3.new(0.9, 1.4, 0.9), Look.lampGlow, M.Neon)
		lamp.Transparency = 0.2
		lamp.CastShadow = false
		lamp:AddTag("StreetLight")
		Kit.detail(ctx.m, cf * CFrame.new(0, 0.5, -0.3), Vector3.new(1.2, 0.25, 1.2), Look.bronzeDark, M.Metal)
	end
end

-- Company flags on poles projecting from the facade above the entrance (seen along the street).
function Common.flags(ctx: Ctx, y: number, xs: { number })
	local company = ctx.def.company
	if not company then
		return
	end
	local primary, accent = Brand.colors(company)
	local L = 9
	local dir = Vector3.new(0, math.sin(math.rad(28)), -math.cos(math.rad(28)))
	for i, x in xs do
		local base = Vector3.new(x, y, -0.4)
		local tip = base + dir * L
		Kit.detail(
			ctx.m,
			ctx.frame * CFrame.new(base + Vector3.new(0, 0, 0.2)),
			Vector3.new(1, 1, 0.6),
			accent,
			M.Metal
		)
		local pole = Kit.detail(
			ctx.m,
			ctx.frame * CFrame.lookAt((base + tip) / 2, tip),
			Vector3.new(0.25, 0.25, L),
			Look.brass,
			M.Metal
		)
		pole.Name = "FlagPole"
		Kit.ball(ctx.m, ctx.frame * CFrame.new(tip), 0.45, Look.goldBright, M.Metal, { CanCollide = false })
		local flag = Kit.detail(
			ctx.m,
			ctx.frame * CFrame.new(base + dir * (L * 0.62) + Vector3.new(0, -3.4, 0)),
			Vector3.new(0.08, 6, 4.4),
			primary,
			M.Fabric
		)
		flag.Name = "CompanyFlag"
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local gui = Deps.Gui.Core.surface(flag, face, { pps = 40, maxDistance = 220, name = "Flag" .. i })
			Deps.Gui.Core.bg(gui, primary)
			local Logos = Deps.Logos
			local drew = false
			if Logos and type(Logos.render) == "function" then
				local holder = Deps.Gui.Core.frame(gui, 0.12, 0.2, 0.76, 0.45, primary, 1)
				drew = pcall(Logos.render, holder, company, { theme = "color", simple = true })
			end
			if not drew then
				Deps.Gui.Core.label(gui, Brand.name(company, ctx.def.label), 0.08, 0.25, 0.84, 0.4, accent, {
					font = Enum.Font.Garamond,
					align = Enum.TextXAlignment.Center,
				})
			end
			Deps.Gui.Core.frame(gui, 0, 0.9, 1, 0.04, accent)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Entrances and branding
---------------------------------------------------------------------------------------------------
-- Shop windows along the ground storey of every side (and the back) that faces open ground, so a corner lot shows
-- lit glass to the cross street instead of a blank stone wall. Faces against a neighbour stay plain.
function Common.baseSides(ctx: Ctx, storey: number, trim: Color3)
	local b = Common.box(-ctx.w / 2, ctx.w / 2, 0, ctx.d, 0, storey)
	local hidden = Common.hidden(ctx, b)
	local wh = math.min(storey - 5, 11)
	if wh < 5 then
		return
	end
	local look = Mass.look("limestone", {
		glass = Look.glassSmoke,
		pier = trim,
		pierMat = M.Metal,
		band = trim,
		bandMat = M.Metal,
		pierW = 0.7,
		bandH = 0.7,
		depth = 0.5,
		bay = 7,
		lit = 0.5,
		litColor = Look.lampGlow,
	})
	for _, side in { "left", "right", "back" } do
		if hidden[side] > 0 then
			continue
		end
		local plane, width = Mass.faceCF(side, b, 0.11)
		local gw = width - 10 -- solid stone at both corners
		if gw < 8 then
			continue
		end
		local face = ctx.frame * plane
		local g = Mass.grid(
			ctx.m,
			face * CFrame.new(0, 2.4 + wh / 2 - storey / 2, 0),
			gw,
			wh,
			look,
			ctx.seed .. ":base:" .. side,
			{ rows = 1 }
		)
		g.Name = "SideWindows"
		-- granite base course under the windows and a stone sill band over them
		Kit.detail(
			ctx.m,
			face * CFrame.new(0, 1.0 - storey / 2, -0.2),
			Vector3.new(width, 2.0, 0.6),
			Look.graniteDark,
			M.Granite
		)
		Kit.detail(
			ctx.m,
			face * CFrame.new(0, 2.4 + wh + 0.9 - storey / 2, -0.3),
			Vector3.new(gw + 1.4, 0.8, 0.8),
			Look.limestoneDark,
			M.Limestone
		)
	end
end

function Common.entrance(ctx: Ctx, spec: { [string]: any }): Entrance.Result
	local s: { [string]: any } = table.clone(spec)
	s.w = s.w or ctx.w
	s.d = s.d or ctx.d
	s.doorId = ctx.def.door or ("door_street_tower_" .. ctx.def.id)
	s.anchorId = ctx.def.anchor or ("street_tower_" .. ctx.def.id .. "_front")
	s.seed = ctx.seed
	local e = Entrance.build(ctx.m, ctx.frame, (s :: any) :: Entrance.Spec)
	Common.baseSides(ctx, s.bh, s.trim or Look.bronze)
	return e
end

-- The street the lot fronts, for its address.
local function streetFor(lot: Plan.Lot): string
	local dir = Plan.FACE_DIR[lot.face]
	local best, bestD = "road_bank_row", math.huge
	for _, r in Plan.roads do
		local perpendicular = (r.axis == "x" and dir.Z ~= 0) or (r.axis == "z" and dir.X ~= 0)
		if perpendicular then
			local dist = math.abs(r.c - lot.line)
			if dist < bestD then
				best, bestD = r.name, dist
			end
		end
	end
	return best
end

function Common.address(lot: Plan.Lot): string
	local n = math.floor((lot.at + Plan.HALF) / 12) * 2 + (if lot.face == "N" or lot.face == "E" then 1 else 2)
	return Text.get("address", { n = n, street = Text.get(streetFor(lot)) })
end

-- Branding for the tower's entrance: fascia (single company) or building name + tenant board (multi-tenant).
-- dirCF = where the tenant board stands (lot space, floor point, LookVector = reading side).
function Common.brand(ctx: Ctx, e: Entrance.Result, dirCF: CFrame?, plaqueCF: CFrame?)
	local def = ctx.def
	local mount = ctx.frame * e.fascia * CFrame.new(0, 0, -0.05)
	local room = math.max(1.5, e.fasciaHeight - 1.2)
	if def.company then
		Brand.fascia(
			ctx.m,
			mount,
			e.fasciaWidth,
			def.company,
			{ height = math.min(math.clamp(ctx.w * 0.07, 3.6, 6), room), lit = true }
		)
	else
		Brand.title(
			ctx.m,
			mount,
			string.upper(def.label),
			e.fasciaWidth,
			{ height = math.min(math.clamp(ctx.w * 0.05, 2.6, 4.2), room), lit = true }
		)
	end
	local tenants = def.picker
	if tenants and #tenants > 0 then
		local cf = dirCF or CFrame.new(ctx.w / 2 - 8, 0, -1.6)
		Brand.directory(ctx.m, ctx.frame * cf, def.label, tenants)
	end
	if plaqueCF then
		Brand.plaque(ctx.m, ctx.frame * plaqueCF, Common.address(ctx.lot), def.label)
	end
end

-- A big logo high on the tower (skyline branding), on a face plane given in lot space. `size` is the height;
-- wordmarks get their natural width (capped by maxW).
function Common.crownLogo(ctx: Ctx, cf: CFrame, size: number, theme: string?, maxW: number?, plate: Color3?)
	local company = ctx.def.company
	if not company then
		return
	end
	local aspect = Brand.aspect(company)
	local w = size * aspect
	local h = size
	if maxW and w > maxW then
		h = h * maxW / w
		w = maxW
	end
	Brand.logo(ctx.m, ctx.frame * cf, w, h, company, {
		label = Brand.name(company, ctx.def.label),
		theme = theme or "dark",
		plate = plate,
		glow = true,
		px = 768,
	})
end

-- A classical pediment (two mirrored wedges) centred at (cx, y) on the plane z, facing out.
function Common.pediment(
	ctx: Ctx,
	cx: number,
	y: number,
	z: number,
	width: number,
	height: number,
	thick: number,
	color: Color3,
	mat: Enum.Material
)
	for _, sx in { -1, 1 } do
		Kit.wedge(
			ctx.m,
			ctx.frame * CFrame.new(cx + sx * width / 4, y + height / 2, z) * CFrame.Angles(0, -sx * math.pi / 2, 0),
			Vector3.new(thick, height, width / 2),
			color,
			mat,
			{ CanCollide = false }
		)
	end
end

function Common.new(parent: Instance, def: TowerDef, lot: Plan.Lot, rects: { Plan.Rect }): Ctx
	local m = Kit.model(parent, "Tower_" .. def.id)
	m:SetAttribute("TowerId", def.id)
	m:SetAttribute("TowerStyle", def.style)
	if def.company then
		m:SetAttribute("TowerCompany", def.company)
	end
	m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	return {
		m = m,
		frame = Plan.lotFrame(lot),
		lot = lot,
		def = def,
		rects = rects,
		rid = "tower:" .. def.id,
		seed = "tower:" .. def.id,
		rng = Rng.new("tower:" .. def.id),
		w = lot.w,
		d = lot.d,
		h = lot.h,
		variant = lot.variant or 1,
	}
end

return Common
