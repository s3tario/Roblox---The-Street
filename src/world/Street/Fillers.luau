--!strict
-- City fabric: the infill buildings that make every block solid (Plan.fillers) and the spare tower lots no company
-- has claimed yet (Plan.spareLots), with street-level storefronts where they face a sidewalk: lit shop windows,
-- doors, painted sign bands and awnings with fictional shop names (Text). Facades only go where they can be seen:
-- each face gets windows above the tallest neighbour in front of it, faces against the district edge stay blank.
-- Bake-safe.
--
--   Fillers.build(parent, rects) -> Model
--   Fillers.storefronts(parent, frame, w, shops?, seed)    a shop row on a lot-space facade (front at z = 0)

local Deps = require(script.Parent.Deps)
local Look = require(script.Parent.Look)
local Mass = require(script.Parent.Mass)
local Plan = require(script.Parent.Plan)
local Text = require(script.Parent.Text)

local Kit = Deps.Kit
local Props = Deps.Props
local Rng = Deps.Rng
local World = Deps.World
local M = Enum.Material

local Fillers = {}

local SHOP_H = 16 -- storefront storey
local SHOP_COLORS = {
	Look.awningGreen,
	Look.awningRed,
	Look.navy,
	Look.black,
	Look.bronzeDark,
	Look.hex("#2F4F6F"),
	Look.hex("#4A2A3A"),
}

local function box(x0: number, x1: number, z0: number, z1: number, y0: number, y1: number): Mass.Box
	return { x0 = x0, x1 = x1, z0 = z0, z1 = z1, y0 = y0, y1 = y1 }
end

-- Lot frame and lot-space size for a world rectangle whose front faces `face`.
local function frameFor(x0: number, z0: number, x1: number, z1: number, face: string): (CFrame, number, number)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	if face == "S" then
		return Plan.frame("S", z1, cx), x1 - x0, z1 - z0
	elseif face == "E" then
		return Plan.frame("E", x1, cz), z1 - z0, x1 - x0
	elseif face == "W" then
		return Plan.frame("W", x0, cz), z1 - z0, x1 - x0
	end
	return Plan.frame("N", z0, cx), x1 - x0, z1 - z0
end

-- Neighbour height in front of every face (math.huge past the district edge, where nobody looks).
local function hiddenAll(frame: CFrame, b: Mass.Box, rects: { Plan.Rect }, rid: string): { [string]: number }
	local out: { [string]: number } = {}
	for _, side in Mass.SIDES do
		local minH = math.huge
		for _, t in { 0.12, 0.5, 0.88 } do
			local lx, lz
			if side == "front" then
				lx, lz = b.x0 + (b.x1 - b.x0) * t, b.z0 - 3
			elseif side == "back" then
				lx, lz = b.x0 + (b.x1 - b.x0) * t, b.z1 + 3
			elseif side == "left" then
				lx, lz = b.x0 - 3, b.z0 + (b.z1 - b.z0) * t
			else
				lx, lz = b.x1 + 3, b.z0 + (b.z1 - b.z0) * t
			end
			local wp = frame:PointToWorldSpace(Vector3.new(lx, 0, lz))
			local hgt = if math.abs(wp.X) > Plan.EDGE or math.abs(wp.Z) > Plan.EDGE
				then math.huge
				else Plan.heightAt(rects, wp.X, wp.Z, rid)
			minH = math.min(minH, hgt)
		end
		out[side] = minH
	end
	return out
end

local function shopLook(): Mass.FacadeLook
	return Mass.look("limestone", {
		glass = Look.glassSmoke,
		pier = Look.steelDark,
		pierMat = M.Metal,
		band = Look.steelDark,
		bandMat = M.Metal,
		pierW = 0.7,
		bandH = 0.7,
		depth = 0.5,
		bay = 6,
		lit = 0.45,
		litColor = Look.lampGlow,
	})
end

-- A row of shops across a lot-space facade (front at z = 0, ground at y = 0, width w centred on x = 0).
function Fillers.storefronts(parent: Instance, frame: CFrame, w: number, shops: { string }?, seed: string)
	local m = Kit.model(parent, "Storefronts")
	local rng = Rng.new(seed)
	Mass.slab(m, frame, box(-w / 2, w / 2, -0.45, 0.05, 0, 1.3), Look.graniteDark, M.Granite, false).Name = "BaseCourse"
	Mass.slab(
		m,
		frame,
		box(-w / 2, w / 2, -0.6, 0.05, SHOP_H - 0.6, SHOP_H + 0.2),
		Look.limestoneDark,
		M.Limestone,
		false
	)
	local list: { string } = if shops then shops else {}
	local n = #list
	local usable = w - 4
	local bayW = if n > 0 then math.min(28, usable / n) else 0
	local x0 = -bayW * n / 2
	for i, key in list do
		local cx = x0 + bayW * (i - 0.5)
		local color = SHOP_COLORS[rng:int(1, #SHOP_COLORS)]
		local ww = bayW - 4.2
		-- lit interior behind dark glass
		local glow =
			Kit.detail(m, frame * CFrame.new(cx - 1.6, 6.4, -0.12), Vector3.new(ww, 9.2, 0.1), Look.lampGlow, M.Neon)
		glow.Transparency = 0.45
		glow.CastShadow = false
		glow:AddTag("LitWindow")
		Kit.block(m, frame * CFrame.new(cx - 1.6, 6.4, -0.32), Vector3.new(ww, 9.6, 0.25), Look.glassSmoke, M.Glass, {
			Transparency = 0.45,
			Reflectance = 0.2,
			CastShadow = false,
		}).Name =
			"ShopWindow"
		-- door at the right of the bay
		Kit.detail(
			m,
			frame * CFrame.new(cx + bayW / 2 - 2.3, 4.7, -0.25),
			Vector3.new(3.4, 9.2, 0.3),
			Look.glassBronze,
			M.Glass
		).Name =
			"ShopDoor"
		Kit.detail(m, frame * CFrame.new(cx + bayW / 2 - 2.3, 9.6, -0.42), Vector3.new(3.8, 0.5, 0.2), color, M.Metal)
		-- piers between the bays
		Mass.slab(
			m,
			frame,
			box(cx + bayW / 2 - 0.5, cx + bayW / 2 + 0.5, -0.6, 0, 0, SHOP_H - 0.6),
			Look.limestone,
			M.Limestone,
			false
		)
		-- sign band and awning
		local band =
			Kit.detail(m, frame * CFrame.new(cx, 13.3, -0.5), Vector3.new(bayW - 1.4, 2.6, 0.3), color, M.SmoothPlastic)
		band.Name = "ShopSign"
		Kit.sign(band, Text.get(key), {
			color = if color == Look.black then Look.gold else Look.cream,
			font = Enum.Font.Garamond,
			pixelsPerStud = 36,
			glow = true,
		})
		Props.build("awning", m, frame * CFrame.new(cx, 10.4, -0.1), {
			width = bayW - 2,
			depth = 4,
			color = color,
			accent = Look.cream,
			stripes = rng:chance(0.5),
			seed = seed .. ":awning" .. i,
		})
	end
	-- plain glazing on what the shops leave either side
	local left = (w - bayW * n) / 2
	if left > 7 then
		for _, sx in { -1, 1 } do
			local cx = sx * (bayW * n / 2 + left / 2)
			Mass.grid(
				m,
				frame * CFrame.new(cx, 7.2, -0.11),
				left - 3,
				10.4,
				shopLook(),
				seed .. ":glaze" .. sx,
				{ rows = 1 }
			)
		end
	end
	return m
end

export type Spec = {
	frame: CFrame,
	w: number,
	d: number,
	h: number,
	look: string,
	rid: string,
	seed: string,
	storefront: boolean,
	shops: { string }?,
	bareRoof: boolean?, -- a billboard stands on this roof: no penthouse
}

local function building(parent: Instance, s: Spec, rects: { Plan.Rect })
	local m = Kit.model(parent, "Building")
	m:SetAttribute("Infill", s.seed)
	m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	local rng = Rng.new(s.seed)
	local look = Mass.vary(Mass.look(s.look), s.seed)
	local w, d, h = s.w, s.d, s.h
	local tiers: { Mass.Box } = {}
	if h > 170 then
		local split = math.floor(h * rng:range(0.62, 0.78))
		local inset = math.min(rng:range(4, 8), w * 0.12, d * 0.12)
		table.insert(tiers, box(-w / 2, w / 2, 0, d, 0, split))
		table.insert(tiers, box(-w / 2 + inset, w / 2 - inset, inset, d - inset, split, h))
	else
		table.insert(tiers, box(-w / 2, w / 2, 0, d, 0, h))
	end
	for i, b in tiers do
		local hidden = hiddenAll(s.frame, b, rects, s.rid)
		if i == 1 and s.storefront then
			hidden.front = math.max(hidden.front, SHOP_H + 0.4)
		end
		Mass.tier(m, s.frame, b, look, {
			hidden = hidden,
			seed = s.seed .. ":" .. i,
			name = "Tier" .. i,
			noBottom = i > 1 or s.storefront,
			noTop = true,
		})
		Mass.cornice(
			m,
			s.frame,
			b,
			b.y1 - 0.4,
			1.8,
			if look.curtain then 0.7 else look.depth + 0.5,
			if look.curtain then Look.steel else look.pier,
			if look.curtain then M.Metal else look.pierMat
		)
	end
	if rng:chance(0.7) and not s.bareRoof then
		Mass.roofKit(m, s.frame, tiers[#tiers], s.seed .. ":roof", Look.slate)
	end
	if s.storefront then
		Fillers.storefronts(m, s.frame, w, s.shops, s.seed)
	end
	return m
end

local SPARE_LOOKS = { "glassBlue", "limestone", "glassDark", "sandstone" }

function Fillers.build(parent: Instance, rects: { Plan.Rect }): Model
	local m = Kit.model(parent, "Infill")
	for _, f in Plan.fillers do
		local frame, w, d = frameFor(f.x0, f.z0, f.x1, f.z1, f.front or "N")
		local billboard = false
		for _, b in Plan.billboards do
			if b.pos.X > f.x0 and b.pos.X < f.x1 and b.pos.Z > f.z0 and b.pos.Z < f.z1 then
				billboard = true
			end
		end
		building(m, {
			frame = frame,
			w = w,
			d = d,
			h = f.h,
			look = f.look,
			rid = "filler:" .. f.seed,
			seed = "filler:" .. f.seed,
			storefront = f.front ~= nil,
			shops = f.shops,
			bareRoof = billboard,
		}, rects)
	end
	local _, spare = Plan.assignLots(World.towers)
	for i, lot in spare do
		building(m, {
			frame = Plan.lotFrame(lot),
			w = lot.w,
			d = lot.d,
			h = lot.h,
			look = SPARE_LOOKS[((lot.variant or i) - 1) % #SPARE_LOOKS + 1],
			rid = "spare:" .. i,
			seed = "spare:" .. i,
			storefront = true,
			shops = lot.shops,
		}, rects)
	end
	return m
end

return Fillers
