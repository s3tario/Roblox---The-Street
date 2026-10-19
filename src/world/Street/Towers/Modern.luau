--!strict
-- Contemporary towers: Anaeio (style "modern": sleek white ribbon bands, an open crown frame holding its
-- wordmark), Applewood Industries (style "corporate": a green glass HQ with its logo on the crown), Middle Market
-- Plaza (style "glass": a blue curtain-wall tower for four advisory firms) and the Private Equity Tower (style
-- "stone": limestone and bronze with a pedimented doorway and a copper roof). Bake-safe.

local Deps = require(script.Parent.Parent.Deps)
local Look = require(script.Parent.Parent.Look)
local Mass = require(script.Parent.Parent.Mass)
local Brand = require(script.Parent.Parent.Brand)
local C = require(script.Parent.Common)

local M = Enum.Material

local Modern = {}

function Modern.modern(ctx: C.Ctx)
	local _, accent = Brand.colors(ctx.def.company)
	local e = C.entrance(ctx, {
		mode = "arcade",
		bh = 22,
		stone = Look.marble,
		stoneMat = M.Marble,
		trim = Look.aluminum,
		recess = 8,
		lobbyDepth = 22,
		endPier = 7,
		round = true,
		columns = 4,
		revolving = 1,
		lobbyWall = Look.white,
		lobbyLight = Look.coolLight,
	})
	local h = ctx.h
	local top = h * 0.92
	local b1 = C.stack(ctx, e.top, {
		{ top = top, look = "ribbon", ledge = Look.white, ledgeMat = M.SmoothPlastic },
	})
	-- a slim LED blade down the front-left corner in the brand accent
	local blade = Mass.slab(
		ctx.m,
		ctx.frame,
		C.box(-ctx.w / 2 - 0.4, -ctx.w / 2 + 0.6, -2.0, -1.0, e.top + 4, top + 26),
		accent,
		M.Neon,
		false
	)
	blade.CastShadow = false
	blade:AddTag("StreetLight")
	-- open crown frame: two white blades and a lintel, the wordmark hung inside
	local fh = h - top - 2
	for _, sx in { -1, 1 } do
		Mass.slab(
			ctx.m,
			ctx.frame,
			C.box(sx * ctx.w / 2 - 2, sx * ctx.w / 2 + 2, 0, 4, top, top + fh),
			Look.white,
			M.SmoothPlastic,
			false
		).Name =
			"CrownBlade"
	end
	Mass.slab(
		ctx.m,
		ctx.frame,
		C.box(-ctx.w / 2 - 2, ctx.w / 2 + 2, 0, 4, top + fh - 3, top + fh),
		Look.white,
		M.SmoothPlastic,
		false
	)
	C.lightBand(ctx, C.box(b1.x0, b1.x1, b1.z0, b1.z1, b1.y0, b1.y1), top + 0.2, Look.coolLight, 0.4)
	C.crownLogo(ctx, CFrame.new(0, top + 4, 2), fh - 10, "light", ctx.w - 10, Look.white)
	Mass.roofKit(
		ctx.m,
		ctx.frame,
		C.box(b1.x0 + 6, b1.x1 - 6, 10, b1.z1 - 4, b1.y0, b1.y1),
		ctx.seed .. ":roof",
		Look.aluminum
	)
	C.brand(ctx, e, nil, CFrame.new(ctx.w / 2 - 3.5, 4.5, 0))
end

function Modern.corporate(ctx: C.Ctx)
	local e = C.entrance(ctx, {
		mode = "arcade",
		bh = 24,
		stone = Look.marble,
		stoneMat = M.Marble,
		trim = Look.aluminum,
		recess = 9,
		lobbyDepth = 24,
		endPier = 7,
		columns = 4,
		revolving = 1,
		lobbyWall = Look.white,
		lobbyLight = Look.coolLight,
	})
	local h = ctx.h
	local b2 = C.stack(ctx, e.top, {
		{ top = h * 0.86, look = "glassGreen", ledge = Look.aluminum },
		{ inset = 5, front = 5, back = 5, top = h * 0.97, look = "glassGreen", ledge = Look.aluminum },
	})
	local size = math.min(24, (b2.x1 - b2.x0) * 0.5)
	C.crownLogo(ctx, CFrame.new(0, b2.y1 - size - 4, b2.z0 - 1.6), size, "dark")
	C.lightBand(ctx, b2, b2.y1 + 0.4, Look.coolLight, 0.7)
	Mass.roofKit(ctx.m, ctx.frame, b2, ctx.seed .. ":roof", Look.aluminum)
	C.brand(ctx, e, nil, CFrame.new(ctx.w / 2 - 3.5, 4.5, 0))
end

function Modern.glass(ctx: C.Ctx)
	local e = C.entrance(ctx, {
		mode = "arcade",
		bh = 20,
		stone = Look.limestone,
		stoneMat = M.Limestone,
		trim = Look.aluminum,
		recess = 8,
		lobbyDepth = 20,
		endPier = 7,
		columns = 5,
		revolving = 1,
	})
	local b1 = C.stack(ctx, e.top, {
		{ top = ctx.h, look = "glassBlue", ledge = Look.aluminum },
	})
	Mass.roofKit(ctx.m, ctx.frame, b1, ctx.seed .. ":roof", Look.aluminum)
	C.brand(ctx, e, CFrame.new(-(ctx.w / 2 - 7 - 5), 0, 8 - 1.5), CFrame.new(ctx.w / 2 - 3.5, 4.5, 0))
end

function Modern.stone(ctx: C.Ctx)
	local e = C.entrance(ctx, {
		mode = "portal",
		bh = 22,
		stone = Look.limestoneWarm,
		stoneMat = M.Limestone,
		trim = Look.bronze,
		doorWidth = 14,
		doorHeight = 14,
		signRoom = 12.5, -- the pediment sits under the name
		shopLook = Mass.look("bronzeStone", { pierW = 1.4, bandH = 1.4, depth = 0.8, bay = 8, lit = 0.6 }),
	})
	-- pedimented doorway (the name band starts 5.5 studs higher)
	C.pediment(ctx, 0, 14 + 1.6, -0.9, 20, 4.6, 1.2, Look.limestoneWarm, M.Limestone)
	e.fascia = e.fascia * CFrame.new(0, 5.4, 0)
	e.fasciaHeight -= 5.4
	local h = ctx.h
	local b2 = C.stack(ctx, e.top, {
		{ top = h * 0.84, look = "bronzeStone", trim = Look.bronze },
		{ inset = 6, front = 6, back = 6, top = h * 0.93, look = "bronzeStone" },
	})
	C.mansard(ctx, b2, h - b2.y1, Look.verdigris)
	C.brand(ctx, e, CFrame.new(ctx.w / 2 - 6, 0, -1.4))
end

return Modern
