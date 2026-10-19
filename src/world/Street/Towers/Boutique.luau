--!strict
-- The elite boutiques (style "elite": stone and bronze, discreet entrances under bronze canopies) and the regional
-- bank (style "regional": a modest brick-and-limestone tower with a classic rooftop name sign). Bake-safe.

local Deps = require(script.Parent.Parent.Deps)
local Look = require(script.Parent.Parent.Look)
local Mass = require(script.Parent.Parent.Mass)
local Brand = require(script.Parent.Parent.Brand)
local Text = require(script.Parent.Parent.Text)
local C = require(script.Parent.Common)

local Kit = Deps.Kit
local M = Enum.Material

local Boutique = {}

local function shopLook(glass: Color3, frame: Color3, mat: Enum.Material): Mass.FacadeLook
	return Mass.look("limestone", {
		glass = glass,
		pier = frame,
		pierMat = mat,
		band = frame,
		bandMat = mat,
		pierW = 1.2,
		bandH = 1.2,
		depth = 0.8,
		bay = 7,
		lit = 0.6,
		litColor = Look.lampGlow,
	})
end

-- Evermoor: warm limestone with bronze bands and a verdigris copper mansard.
local function mansard(ctx: C.Ctx)
	local _, accent = Brand.colors(ctx.def.company)
	local e = C.entrance(ctx, {
		mode = "portal",
		bh = 20,
		stone = Look.limestoneWarm,
		stoneMat = M.Limestone,
		trim = Look.bronze,
		doorWidth = 12,
		doorHeight = 13,
		shopLook = shopLook(Look.glassBronze, Look.bronze, M.Metal),
		canopy = "cantilever",
		canopyColor = Look.bronzeDark,
	})
	local h = ctx.h
	local b2 = C.stack(ctx, e.top, {
		{ top = h * 0.82, look = "bronzeStone", trim = accent },
		{ inset = 5, front = 5, back = 5, top = h * 0.92, look = "bronzeStone" },
	})
	C.mansard(ctx, b2, h - b2.y1, Look.verdigris)
	C.lanterns(ctx, 8.2, 9)
	C.brand(ctx, e, CFrame.new(ctx.w / 2 - 6, 0, -1.4))
end

-- Lazaro Freres: black granite and bronze, a deep bronze cornice, gold lettering.
local function noir(ctx: C.Ctx)
	local e = C.entrance(ctx, {
		mode = "portal",
		bh = 20,
		stone = Look.blackGranite,
		stoneMat = M.Basalt,
		trim = Look.gold,
		doorWidth = 11,
		doorHeight = 13,
		shopLook = shopLook(Look.glassBronze, Look.gold, M.Metal),
		canopy = "cantilever",
		canopyColor = Look.black,
	})
	local h = ctx.h
	local b1 = C.stack(ctx, e.top, {
		{ top = h * 0.95, look = "basalt", ledge = Look.bronze, ledgeMat = M.Metal, trim = Look.gold },
	})
	Mass.cornice(ctx.m, ctx.frame, b1, b1.y1 - 0.4, 3, 2.2, Look.bronzeDark, M.Metal)
	Mass.roofKit(ctx.m, ctx.frame, b1, ctx.seed .. ":roof", Look.blackGranite)
	C.lanterns(ctx, 7.7, 9)
	C.brand(ctx, e, CFrame.new(ctx.w / 2 - 6, 0, -1.4))
end

-- Centerline: sandstone with bronze, a stepped crown with a copper-accent band.
local function stepped(ctx: C.Ctx)
	local _, accent = Brand.colors(ctx.def.company)
	local e = C.entrance(ctx, {
		mode = "portal",
		bh = 20,
		stone = Look.sandstone,
		stoneMat = M.Sandstone,
		trim = Look.bronze,
		doorWidth = 12,
		doorHeight = 13,
		shopLook = shopLook(Look.glassSmoke, Look.bronze, M.Metal),
		canopy = "cantilever",
		canopyColor = Look.bronzeDark,
	})
	local h = ctx.h
	local b3 = C.stack(ctx, e.top, {
		{ top = h * 0.79, look = Mass.look("sandstone", { band = Look.bronze, bandMat = M.Metal, bandH = 2.4 }) },
		{ inset = 5, front = 5, back = 5, top = h * 0.91, look = "sandstone", trim = accent },
		{ inset = 12, front = 12, back = 12, top = h, look = "sandstone", trim = Look.bronze },
	})
	C.lightBand(ctx, b3, b3.y1 - 4, accent:Lerp(Look.lampGlow, 0.4), 1.6)
	C.lanterns(ctx, 8.2, 9)
	C.brand(ctx, e, CFrame.new(ctx.w / 2 - 6, 0, -1.4))
end

local ELITE = { mansard, noir, stepped }

function Boutique.elite(ctx: C.Ctx)
	ELITE[((ctx.variant - 1) % #ELITE) + 1](ctx)
end

-- Sterling & Vance: modest brick over a limestone base, a navy canopy and a rooftop name sign on a steel frame.
function Boutique.regional(ctx: C.Ctx)
	local primary = Brand.colors(ctx.def.company)
	local e = C.entrance(ctx, {
		mode = "portal",
		bh = 16,
		stone = Look.limestone,
		stoneMat = M.Limestone,
		trim = Look.steel,
		doorWidth = 11,
		doorHeight = 12,
		shopLook = shopLook(Look.glassNavy, Look.steelDark, M.Metal),
		canopy = "cantilever",
		canopyColor = primary,
	})
	local h = ctx.h
	local b1 = C.stack(ctx, e.top, {
		{ top = h * 0.9, look = "brick", ledge = Look.limestone, ledgeMat = M.Limestone },
	})
	Mass.cornice(ctx.m, ctx.frame, b1, b1.y1 - 0.4, 2.4, 1.8, Look.limestone, M.Limestone)
	-- rooftop sign: steel frame, white letters on navy, readable from Exchange Avenue
	local signW = math.min(ctx.w - 8, 44)
	local y = b1.y1 + 2
	for _, sx in { -0.4, 0, 0.4 } do
		Kit.detail(
			ctx.m,
			ctx.frame * CFrame.new(sx * signW, y + 3, 4),
			Vector3.new(0.5, 6, 0.5),
			Look.steelDark,
			M.Metal
		)
	end
	local board =
		Kit.detail(ctx.m, ctx.frame * CFrame.new(0, y + 5.5, 3.6), Vector3.new(signW, 6, 0.3), primary, M.Metal)
	board.Name = "RoofSign"
	Kit.sign(board, Text.get("sv_roof"), {
		color = Look.white,
		font = Enum.Font.GothamBlack,
		pixelsPerStud = 24,
		glow = true,
	})
	Mass.roofKit(ctx.m, ctx.frame, C.box(-12, 12, ctx.d * 0.4, ctx.d * 0.85, b1.y0, b1.y1), ctx.seed .. ":roof")
	C.brand(ctx, e, CFrame.new(ctx.w / 2 - 6, 0, -1.4))
end

return Boutique
