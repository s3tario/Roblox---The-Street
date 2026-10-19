--!strict
-- Small-format towers: Wealth House (style "townhouse": a brownstone with a stoop, iron railings, parlour windows
-- and a bracketed cornice), Venture Row (style "loft": a converted brick loft with steel windows, a painted ghost
-- sign and a rooftop water tower) and the Property Exchange (style "brick": brick over a limestone base).
-- Bake-safe.

local Deps = require(script.Parent.Parent.Deps)
local Look = require(script.Parent.Parent.Look)
local Mass = require(script.Parent.Parent.Mass)
local Brand = require(script.Parent.Parent.Brand)
local Text = require(script.Parent.Parent.Text)
local C = require(script.Parent.Common)

local Kit = Deps.Kit
local Props = Deps.Props
local M = Enum.Material

local Small = {}

local STOOP_STEPS = 5
local STOOP_RISE = 0.7
local STOOP_RUN = 1.3
local LANDING = 3

function Small.townhouse(ctx: C.Ctx)
	local w, d, h = ctx.w, ctx.d, ctx.h
	local stone = Look.brownstone
	local landY = STOOP_STEPS * STOOP_RISE
	local doorW = 6.5
	local doorH = 10
	local bandY = landY + doorH + 1.2
	-- the house: brownstone storeys above the parlour floor, plain stone below (doors, windows, the name band)
	local core = C.box(-w / 2, w / 2, 0, d, 0, h * 0.92)
	local look = C.lookOf("brownstone", ctx.seed)
	local hidden = C.hidden(ctx, core)
	hidden.front = bandY + 5
	Mass.tier(ctx.m, ctx.frame, core, look, { hidden = hidden, seed = ctx.seed, name = "House", noTop = true })
	-- bracketed cornice
	Mass.cornice(ctx.m, ctx.frame, core, core.y1 - 0.5, 2.6, 2.4, Look.bronzeDark, M.Metal)
	for i = 0, 5 do
		local x = -w / 2 + 2 + (w - 4) * i / 5
		Kit.detail(
			ctx.m,
			ctx.frame * CFrame.new(x, core.y1 - 1.6, -1.4),
			Vector3.new(0.8, 2.2, 2.4),
			Look.bronzeDark,
			M.Metal
		)
	end
	Mass.slab(ctx.m, ctx.frame, C.box(-w / 2 + 3, w / 2 - 3, 6, d - 6, core.y1, h), Look.slate, M.Slate, false)
	-- stoop: steps climbing toward the door, a landing and iron railings
	local base = ctx.frame
		* CFrame.new(0, 0, -LANDING - STOOP_RUN * STOOP_STEPS + STOOP_RUN / 2)
		* CFrame.Angles(0, math.pi, 0)
	Kit.stairs(ctx.m, base, 8, STOOP_STEPS, STOOP_RISE, STOOP_RUN, stone, M.Sandstone)
	Mass.slab(ctx.m, ctx.frame, C.box(-4, 4, -LANDING, 0, 0, landY), stone, M.Sandstone).Name = "Landing"
	local z0 = -LANDING - STOOP_RUN * STOOP_STEPS
	for _, sx in { -1, 1 } do
		local x = sx * 4.1
		local a = Vector3.new(x, 3.2, z0 + 0.3)
		local b = Vector3.new(x, landY + 3.2, -LANDING)
		local mid = (a + b) / 2
		Kit.detail(
			ctx.m,
			ctx.frame * CFrame.lookAt(mid, b),
			Vector3.new(0.25, 0.25, (b - a).Magnitude),
			Look.iron,
			M.Metal
		)
		Kit.detail(
			ctx.m,
			ctx.frame * CFrame.new(x, landY + 3.2, -LANDING / 2),
			Vector3.new(0.25, 0.25, LANDING),
			Look.iron,
			M.Metal
		)
		for _, post in { { z0 + 0.3, 3.2 }, { -LANDING, landY + 3.2 }, { -0.3, landY + 3.2 } } do
			local top = post[2]
			Kit.detail(
				ctx.m,
				ctx.frame * CFrame.new(x, top / 2, post[1]),
				Vector3.new(0.3, top, 0.3),
				Look.iron,
				M.Metal
			)
		end
		Kit.ball(ctx.m, ctx.frame * CFrame.new(x, 3.4, z0 + 0.3), 0.6, Look.brass, M.Metal, { CanCollide = false })
	end
	-- the front door at the top of the stoop, with a fanlight
	local doorZ = -0.15
	local glow = Kit.detail(
		ctx.m,
		ctx.frame * CFrame.new(0, landY + doorH / 2, doorZ + 0.3),
		Vector3.new(doorW - 1, doorH, 0.1),
		Look.lampGlow,
		M.Neon
	)
	glow.Transparency = 0.5
	glow.CastShadow = false
	glow:AddTag("InteriorLight")
	local leaf = Kit.block(
		ctx.m,
		ctx.frame * CFrame.new(0, landY + doorH / 2, doorZ),
		Vector3.new(doorW - 1, doorH, 0.3),
		Look.walnut,
		M.Wood
	)
	leaf.Name = "FrontDoor"
	for _, sx in { -1, 1 } do
		Kit.detail(
			ctx.m,
			ctx.frame * CFrame.new(sx * 1.4, landY + doorH * 0.62, doorZ - 0.2),
			Vector3.new(1.6, doorH * 0.5, 0.1),
			Look.glassBronze,
			M.Glass
		)
	end
	Mass.slab(
		ctx.m,
		ctx.frame,
		C.box(-doorW / 2 - 1, doorW / 2 + 1, -0.8, 0, landY, landY + doorH + 0.8),
		Look.limestoneDark,
		M.Limestone,
		false
	)
	-- parlour windows either side of the door and the garden-level windows below them
	for _, sx in { -1, 1 } do
		local cx = sx * (w / 4 + 2)
		for _, win in { { landY + 1.5, 9 }, { 0.8, 2.6 } } do
			local wy, wh = win[1], win[2]
			Mass.slab(
				ctx.m,
				ctx.frame,
				C.box(cx - 4.6, cx + 4.6, -0.5, 0, wy - 0.6, wy + wh + 0.6),
				Look.limestoneDark,
				M.Limestone,
				false
			)
			local pane = Kit.detail(
				ctx.m,
				ctx.frame * CFrame.new(cx, wy + wh / 2, -0.55),
				Vector3.new(8, wh, 0.12),
				Look.lampGlow,
				M.Neon
			)
			pane.Transparency = 0.45
			pane.CastShadow = false
			pane:AddTag("LitWindow")
		end
		-- flower box under the parlour window
		Mass.slab(
			ctx.m,
			ctx.frame,
			C.box(cx - 4.4, cx + 4.4, -1.8, -0.5, landY + 0.2, landY + 1.2),
			Look.iron,
			M.Metal,
			false
		)
		Mass.slab(
			ctx.m,
			ctx.frame,
			C.box(cx - 4.2, cx + 4.2, -1.7, -0.6, landY + 1.2, landY + 2.0),
			Look.foliageLight,
			M.LeafyGrass,
			false
		)
	end
	C.lanterns(ctx, doorW / 2 + 1.8, landY + 7.5)
	-- name band over the door, the tenant board on the sidewalk, and the door trigger on the landing
	Brand.title(ctx.m, ctx.frame * CFrame.new(0, bandY, -0.05), string.upper(ctx.def.label), w * 0.5, { height = 2.4 })
	local door = Kit.door(
		ctx.m,
		ctx.def.door or ("door_street_tower_" .. ctx.def.id),
		ctx.frame * CFrame.new(0, landY + 5.2, -1.4),
		Vector3.new(doorW, 10, 2.6)
	)
	door.Name = door:GetAttribute("DoorId") :: string
	Kit.anchor(
		ctx.m,
		ctx.def.anchor or ("street_tower_" .. ctx.def.id .. "_front"),
		ctx.frame * CFrame.new(0, 3, z0 - 2.2)
	)
	if ctx.def.picker and #ctx.def.picker > 0 then
		Brand.directory(ctx.m, ctx.frame * CFrame.new(w / 2 - 5, 0, -1.6), ctx.def.label, ctx.def.picker, { width = 5 })
	end
	if ctx.def.company then
		Brand.logo(ctx.m, ctx.frame * CFrame.new(-(doorW / 2 + 3.6), landY + 2.5, -0.1), 2.6, 2.6, ctx.def.company, {
			theme = "dark",
		})
	end
end

function Small.loft(ctx: C.Ctx)
	local e = C.entrance(ctx, {
		mode = "portal",
		bh = 18,
		stone = Look.brickDark,
		stoneMat = M.Brick,
		trim = Look.steelDark,
		doorWidth = 12,
		doorHeight = 12,
		shopLook = Mass.look("loft", {
			pier = Look.iron,
			pierMat = M.Metal,
			band = Look.iron,
			bandMat = M.Metal,
			pierW = 0.6,
			bandH = 0.6,
			depth = 0.5,
			bay = 4,
			lit = 0.7,
		}),
		canopy = "cantilever",
		canopyColor = Look.iron,
	})
	local h = ctx.h
	local b1 = C.stack(ctx, e.top, {
		{ top = h * 0.93, look = "loft", ledge = Look.brickDark, ledgeMat = M.Brick, blank = { right = true } },
	})
	Mass.cornice(ctx.m, ctx.frame, b1, b1.y1 - 0.5, 2.2, 1.2, Look.brickDark, M.Brick)
	-- painted ghost sign on the blank side wall (lot +X)
	local gh = math.min(b1.y1 - b1.y0 - 8, 34)
	local panel = Kit.detail(
		ctx.m,
		ctx.frame * CFrame.new(ctx.w / 2 + 0.06, b1.y1 - gh / 2 - 6, ctx.d * 0.45),
		Vector3.new(0.1, gh, ctx.d * 0.7),
		Look.brick,
		M.Brick
	)
	panel.Name = "GhostSign"
	panel.Transparency = 1
	Kit.sign(panel, Text.get("ghost_sign"), {
		face = Enum.NormalId.Right,
		color = Look.cream,
		font = Enum.Font.Bodoni,
		pixelsPerStud = 10,
	}).TextTransparency =
		0.3
	-- rooftop water tower on four legs
	local cx, cz = ctx.w * 0.2, ctx.d * 0.6
	local y = b1.y1 + 1.7
	for _, lx in { -2.6, 2.6 } do
		for _, lz in { -2.6, 2.6 } do
			Kit.detail(
				ctx.m,
				ctx.frame * CFrame.new(cx + lx, y + 5, cz + lz),
				Vector3.new(0.6, 10, 0.6),
				Look.iron,
				M.Metal
			)
		end
	end
	Kit.cylinder(ctx.m, ctx.frame * CFrame.new(cx, y + 10.2, cz), 0.4, 9, Look.iron, M.Metal, { CanCollide = false })
	Kit.cylinder(
		ctx.m,
		ctx.frame * CFrame.new(cx, y + 15, cz),
		9.6,
		8,
		Look.hex("#6B4E35"),
		M.WoodPlanks,
		{ CanCollide = false }
	)
	for _, hy in { 12, 15, 18 } do
		Kit.cylinder(
			ctx.m,
			ctx.frame * CFrame.new(cx, y + hy, cz),
			0.3,
			8.2,
			Look.iron,
			M.Metal,
			{ CanCollide = false }
		)
	end
	Kit.cylinder(ctx.m, ctx.frame * CFrame.new(cx, y + 20.3, cz), 1, 8.6, Look.iron, M.Metal, { CanCollide = false })
	Kit.cylinder(ctx.m, ctx.frame * CFrame.new(cx, y + 21.3, cz), 1, 5, Look.iron, M.Metal, { CanCollide = false })
	Kit.cylinder(ctx.m, ctx.frame * CFrame.new(cx, y + 22.2, cz), 0.8, 1.8, Look.iron, M.Metal, { CanCollide = false })
	C.brand(ctx, e, CFrame.new(ctx.w / 2 - 6, 0, -1.4))
end

function Small.brick(ctx: C.Ctx)
	local e = C.entrance(ctx, {
		mode = "portal",
		bh = 18,
		stone = Look.limestone,
		stoneMat = M.Limestone,
		trim = Look.bronze,
		doorWidth = 12,
		doorHeight = 12,
		shopLook = Mass.look("limestone", {
			pier = Look.bronze,
			pierMat = M.Metal,
			band = Look.bronze,
			bandMat = M.Metal,
			pierW = 1,
			bandH = 1,
			depth = 0.6,
			bay = 7,
			lit = 0.6,
		}),
		canopy = "cantilever",
		canopyColor = Look.black,
	})
	local h = ctx.h
	local b1 = C.stack(ctx, e.top, {
		{ top = h * 0.94, look = "brick", ledge = Look.limestone, ledgeMat = M.Limestone },
	})
	Mass.cornice(ctx.m, ctx.frame, b1, b1.y1 - 0.4, 2.6, 2, Look.limestone, M.Limestone)
	Props.build(
		"flag_pole",
		ctx.m,
		ctx.frame * CFrame.new(-ctx.w * 0.25, b1.y1 + 2.2, ctx.d * 0.3),
		{ variant = 3, seed = ctx.seed }
	)
	Mass.roofKit(
		ctx.m,
		ctx.frame,
		C.box(0, ctx.w / 2 - 6, ctx.d * 0.4, ctx.d - 6, b1.y0, b1.y1),
		ctx.seed .. ":roof",
		Look.slate
	)
	C.lanterns(ctx, 8.2, 9)
	C.brand(ctx, e, CFrame.new(ctx.w / 2 - 6, 0, -1.4))
end

return Small
