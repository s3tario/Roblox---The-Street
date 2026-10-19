--!strict
-- Bank Row's hero towers (style "bulge": the four bulge-bracket banks, the tallest and most imposing buildings on
-- the Street) and the black-glass Funds & Credit Tower (style "dark_glass"). Each bulge variant has its own
-- silhouette: an Art Deco limestone stepped spire, a silver glass slab with a sloped crown, a brass-and-dark-glass
-- tower with stone fins and a glowing lantern, and a granite-and-glass tower with a red crown band. Company accent
-- colours (Config/Companies) tint the trims and crown lights. Bake-safe.

local Deps = require(script.Parent.Parent.Deps)
local Look = require(script.Parent.Parent.Look)
local Mass = require(script.Parent.Parent.Mass)
local Brand = require(script.Parent.Parent.Brand)
local C = require(script.Parent.Common)

local Kit = Deps.Kit
local M = Enum.Material

local Bank = {}

local function dirAt(e: { fasciaWidth: number }, x: number, rc: number): CFrame
	return CFrame.new(x, 0, rc - 1.5)
end

-- MG Freeman: Art Deco limestone, three setbacks, a gilt stepped crown and spire.
local function deco(ctx: C.Ctx)
	local _, accent = Brand.colors(ctx.def.company)
	local gold = Look.gold:Lerp(accent, 0.35)
	local e = C.entrance(ctx, {
		mode = "arcade",
		bh = 26,
		stone = Look.limestone,
		stoneMat = M.Limestone,
		trim = gold,
		recess = 9,
		lobbyDepth = 24,
		endPier = 9,
		columns = 6,
		revolving = 2,
	})
	local h = ctx.h
	local b3 = C.stack(ctx, e.top, {
		{ top = h * 0.48, look = "deco", trim = gold },
		{ inset = 7, front = 7, back = 7, top = h * 0.72, look = "deco", trim = gold },
		{ inset = 15, front = 15, back = 15, top = h * 0.87, look = "deco", trim = gold },
	})
	local lantern = C.stack(ctx, b3.y1, {
		{
			inset = 23,
			front = 23,
			back = 23,
			top = h * 0.92,
			look = Mass.look("glassBrass", { lit = 0.45 }),
			trim = gold,
		},
	})
	C.floodlights(ctx, b3, Look.warmLight)
	C.decoCrown(ctx, lantern, gold, Look.warmLight)
	local size = math.min(22, (b3.x1 - b3.x0) * 0.4)
	C.crownLogo(ctx, CFrame.new(0, b3.y1 - size - 10, b3.z0 - 2.8), size)
	C.brand(ctx, e, nil, CFrame.new(ctx.w / 2 - 4.5, 4.5, 0))
	C.flags(ctx, e.top + 3, { -(ctx.w / 2 - 14), ctx.w / 2 - 14 })
end

-- Goldfield Saxe: a silver glass slab on a granite colonnade with a sloped glass crown.
local function slab(ctx: C.Ctx)
	local _, accent = Brand.colors(ctx.def.company)
	local e = C.entrance(ctx, {
		mode = "arcade",
		bh = 24,
		stone = Look.granite,
		stoneMat = M.Granite,
		trim = Look.steel,
		recess = 8,
		lobbyDepth = 22,
		endPier = 8,
		round = true,
		revolving = 2,
		lobbyLight = Look.coolLight,
	})
	local h = ctx.h
	local b2 = C.stack(ctx, e.top, {
		{ top = h * 0.78, look = "glassSilver", ledge = Look.steel },
		{ inset = 5, front = 12, back = 4, top = h * 0.935, look = "glassSilver", ledge = Look.steel },
	})
	C.slope(ctx, b2, h - b2.y1, Look.glassSilver, accent:Lerp(Look.white, 0.5))
	C.floodlights(ctx, b2, Look.coolLight)
	local size = math.min(22, (b2.x1 - b2.x0) * 0.36)
	C.crownLogo(ctx, CFrame.new(0, b2.y1 - size - 12, b2.z0 - 1.6), size, "dark")
	C.brand(ctx, e, nil, CFrame.new(ctx.w / 2 - 4, 4.5, 0))
	C.flags(ctx, e.top + 3, { -(ctx.w / 2 - 14), ctx.w / 2 - 14 })
end

-- Morrow Stanton: dark glass with brass mullions between limestone corner fins, a lit lantern and a mast.
local function brass(ctx: C.Ctx)
	local e = C.entrance(ctx, {
		mode = "arcade",
		bh = 24,
		stone = Look.limestoneWarm,
		stoneMat = M.Limestone,
		trim = Look.brass,
		recess = 8,
		lobbyDepth = 22,
		endPier = 8,
		columns = 5,
		revolving = 2,
	})
	local h = ctx.h
	local b1 = C.stack(ctx, e.top, {
		{ top = h * 0.67, look = "glassBrass", ledge = Look.limestoneWarm, ledgeMat = M.Limestone, trim = Look.brass },
	})
	-- limestone fins framing the front corners of the shaft
	for _, sx in { -1, 1 } do
		Mass.slab(
			ctx.m,
			ctx.frame,
			C.box(sx * ctx.w / 2 - 2.5, sx * ctx.w / 2 + 2.5, -1.5, 3.5, e.top, b1.y1),
			Look.limestoneWarm,
			M.Limestone,
			false
		).Name =
			"Fin"
	end
	local b3 = C.stack(ctx, b1.y1, {
		{ inset = 8, front = 8, back = 8, top = h * 0.88, look = "glassBrass", trim = Look.brass },
		{ inset = 16, front = 16, back = 16, top = h * 0.945, look = "glassBrass", trim = Look.brass },
	})
	local top = C.lantern(ctx, b3, 4, h - b3.y1 - 12, Look.glassNavy, Look.warmLight, Look.brass)
	Kit.cylinder(
		ctx.m,
		ctx.frame * CFrame.new(0, top + 8, (b3.z0 + b3.z1) / 2),
		16,
		0.8,
		Look.brass,
		M.Metal,
		{ CanCollide = false }
	)
	C.floodlights(ctx, b3, Look.warmLight)
	local size = math.min(20, (b3.x1 - b3.x0) * 0.42)
	C.crownLogo(ctx, CFrame.new(0, b3.y0 + 4, b3.z0 - 1.6), size)
	C.brand(ctx, e, nil, CFrame.new(ctx.w / 2 - 4, 4.5, 0))
	C.flags(ctx, e.top + 3, { -(ctx.w / 2 - 14), ctx.w / 2 - 14 })
end

-- Merriweather Lynch: a granite shaft, dark glass upper tiers and a crown band in the company red.
local function granite(ctx: C.Ctx)
	local _, accent = Brand.colors(ctx.def.company)
	local e = C.entrance(ctx, {
		mode = "arcade",
		bh = 22,
		stone = Look.graniteDark,
		stoneMat = M.Granite,
		trim = Look.steel,
		recess = 8,
		lobbyDepth = 22,
		endPier = 8,
		round = true,
		columns = 5,
		revolving = 1,
	})
	local h = ctx.h
	local b3 = C.stack(ctx, e.top, {
		{ top = h * 0.64, look = "granite", trim = Look.steel },
		{
			inset = 7,
			front = 7,
			back = 7,
			top = h * 0.88,
			look = "glassDark",
			ledge = Look.granite,
			ledgeMat = M.Granite,
		},
		{
			inset = 15,
			front = 15,
			back = 15,
			top = h * 0.95,
			look = "glassDark",
			ledge = Look.granite,
			ledgeMat = M.Granite,
		},
	})
	C.lightBand(ctx, b3, b3.y1 - 6, accent, 0.9)
	C.lightBand(ctx, b3, b3.y1 - 2, accent, 0.9)
	Mass.roofKit(ctx.m, ctx.frame, b3, ctx.seed .. ":roof", Look.graniteDark)
	C.floodlights(ctx, b3, Look.warmLight)
	local size = math.min(20, (b3.x1 - b3.x0) * 0.4)
	C.crownLogo(ctx, CFrame.new(0, b3.y0 - size - 16, 7 - 2.0), size)
	C.brand(ctx, e, nil, CFrame.new(ctx.w / 2 - 4, 4.5, 0))
	C.flags(ctx, e.top + 3, { -(ctx.w / 2 - 14), ctx.w / 2 - 14 })
end

local VARIANTS = { deco, slab, brass, granite }

function Bank.bulge(ctx: C.Ctx)
	local fn = VARIANTS[((ctx.variant - 1) % #VARIANTS) + 1]
	fn(ctx)
end

-- Funds & Credit Tower: a black glass monolith with cyan LED corner fins (multi-tenant).
function Bank.darkGlass(ctx: C.Ctx)
	local e = C.entrance(ctx, {
		mode = "arcade",
		bh = 22,
		stone = Look.blackGranite,
		stoneMat = M.Basalt,
		trim = Look.steel,
		recess = 8,
		lobbyDepth = 20,
		endPier = 8,
		columns = 4,
		revolving = 1,
		lobbyLight = Look.coolLight,
	})
	local h = ctx.h
	local b2 = C.stack(ctx, e.top, {
		{ top = h * 0.91, look = "glassBlack", ledge = Look.iron },
		{ inset = 8, front = 8, back = 8, top = h * 0.985, look = "glassBlack", ledge = Look.iron },
	})
	for _, sx in { -1, 1 } do
		local fin = Mass.slab(
			ctx.m,
			ctx.frame,
			C.box(sx * ctx.w / 2 - 0.5, sx * ctx.w / 2 + 0.5, -1.2, -0.2, e.top + 2, h * 0.91),
			Look.neonCyan,
			M.Neon,
			false
		)
		fin.CastShadow = false
		fin:AddTag("StreetLight")
	end
	C.lightBand(ctx, b2, b2.y1 - 1.5, Look.neonCyan, 0.7)
	Mass.roofKit(ctx.m, ctx.frame, b2, ctx.seed .. ":roof", Look.iron)
	C.brand(ctx, e, dirAt(e, -(ctx.w / 2 - 8 - 4.5), 8), CFrame.new(ctx.w / 2 - 4, 4.5, 0))
end

return Bank
