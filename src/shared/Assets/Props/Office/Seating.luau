--!strict
-- Office seating: task chair, executive chair, visitor chair, office sofa and armchair.
-- Chairs face -Z (a seated player looks along cf.LookVector). opts.seat = true makes the cushions real Seat
-- parts; opts.color = upholstery, opts.accent = frame/legs.

local Common = require(script.Parent.Parent.Common)
local Shapes = require(script.Parent.Parent.Shapes)
local Kit = require(script.Parent.Parent.Parent.Parent.Build.Kit)

type Ctx = Common.Ctx
type Def = Common.Def

local P, R = Common.P, Common.R
local V = Vector3.new
local M = Enum.Material
local col = Common.col
local shade = Kit.shade

local defs: { Def } = {}
local function add(d: Def)
	table.insert(defs, d)
end

---------------------------------------------------------------------------------------------------
-- chair_task: mesh-back swivel chair on a five-star base
---------------------------------------------------------------------------------------------------
add({
	id = "chair_task",
	category = "office",
	footprint = V(2.6, 3.95, 2.6),
	maxParts = 24,
	tags = { "chair", "seat", "furniture" },
	build = function(c: Ctx)
		local fabric = c.color("color", col.fabricCharcoal)
		local frame = c.color("accent", col.plasticBlack)
		local hub = Shapes.starBase(c, 1.25, frame, M.SmoothPlastic)
		c.dcyl(P(0, hub + 0.5, 0), 1.0, 0.18, col.chrome, M.Metal)
		c.detail(P(0, hub + 1.06, 0.05), V(0.9, 0.12, 0.9), frame, M.SmoothPlastic)
		c.seat(P(0, 1.68, 0.05), V(1.9, 0.28, 1.75), fabric, M.Fabric)
		c.dcylX(P(0, 1.66, -0.82), 1.9, 0.3, fabric, M.Fabric) -- waterfall front edge
		c.detail(P(0, 2.2, 0.98) * R(6, 0, 0), V(0.25, 1.0, 0.12), frame, M.SmoothPlastic)
		c.detail(P(0, 3.05, 1.02) * R(8, 0, 0), V(1.8, 1.7, 0.2), shade(fabric, -0.1), M.Fabric)
		c.detail(P(0, 2.55, 0.9) * R(8, 0, 0), V(1.5, 0.35, 0.1), shade(fabric, 0.12), M.Fabric)
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 0.95, 2.02, 0.15), V(0.12, 0.6, 0.18), frame, M.SmoothPlastic)
			c.detail(P(sx * 0.95, 2.35, 0.05), V(0.22, 0.08, 0.9), frame, M.SmoothPlastic)
		end
		c.use(V(0, 2, 0))
	end,
})

---------------------------------------------------------------------------------------------------
-- chair_exec: high-back channel-stitched leather chair with headrest and padded arms
---------------------------------------------------------------------------------------------------
add({
	id = "chair_exec",
	category = "office",
	footprint = V(2.8, 4.75, 2.9),
	maxParts = 26,
	tags = { "chair", "seat", "furniture", "executive" },
	build = function(c: Ctx)
		local leather = c.color("color", col.leatherBlack)
		local frame = c.color("accent", col.chrome)
		local hub = Shapes.starBase(c, 1.35, frame, M.Metal)
		c.dcyl(P(0, hub + 0.5, 0), 1.0, 0.2, frame, M.Metal)
		c.seat(P(0, 1.72, 0.05), V(2.1, 0.36, 1.95), leather, M.Leather)
		c.dcylX(P(0, 1.68, -0.92), 2.1, 0.4, leather, M.Leather)
		local back = P(0, 3.3, 1.1) * R(10, 0, 0)
		c.detail(back, V(2.0, 2.6, 0.35), leather, M.Leather)
		for i = -1, 1 do
			c.detail(back * P(0, i * 0.62, -0.18), V(1.8, 0.05, 0.03), shade(leather, -0.4), M.Leather)
		end
		c.detail(P(0, 4.45, 0.95) * R(12, 0, 0), V(1.7, 0.5, 0.3), leather, M.Leather)
		for _, sx in { -1, 1 } do
			c.detail(P(sx * 1.12, 2.4, 0.05), V(0.32, 0.18, 1.5), leather, M.Leather)
			c.detail(P(sx * 1.12, 2.05, 0.25), V(0.1, 0.55, 0.14), frame, M.Metal)
		end
		c.use(V(0, 2, 0))
	end,
})

---------------------------------------------------------------------------------------------------
-- chair_visitor: chrome sled-base guest chair with wood arms
---------------------------------------------------------------------------------------------------
add({
	id = "chair_visitor",
	category = "office",
	footprint = V(2.15, 3.45, 2.0),
	maxParts = 14,
	tags = { "chair", "seat", "furniture" },
	build = function(c: Ctx)
		local fabric = c.color("color", col.fabricNavy)
		local frame = c.color("accent", col.chrome)
		local f = Common.finish(c.int("tier", 2, 1, 4))
		for _, sx in { -1, 1 } do
			local x = sx * 0.95
			c.detail(P(x, 0.05, 0), V(0.12, 0.1, 2.0), frame, M.Metal)
			c.detail(P(x, 0.85, -0.9), V(0.12, 1.6, 0.12), frame, M.Metal)
			c.detail(P(x, 1.2, 0.9), V(0.12, 2.3, 0.12), frame, M.Metal)
			c.detail(P(x, 2.41, 0), V(0.22, 0.12, 2.0), f.wood, f.woodMat)
		end
		c.seat(P(0, 1.6, -0.05), V(1.8, 0.3, 1.8), fabric, M.Fabric)
		c.detail(P(0, 2.7, 0.92) * R(6, 0, 0), V(1.8, 1.4, 0.2), fabric, M.Fabric)
		c.use(V(0, 2, 0))
	end,
})

---------------------------------------------------------------------------------------------------
-- sofa_office / armchair: low modern lounge seating on chrome legs
---------------------------------------------------------------------------------------------------
local function lounge(c: Ctx, n: number, W: number)
	local fabric = c.color("color", col.fabricCharcoal)
	local legC = c.color("accent", col.chrome)
	local D = 3
	local legH = 0.35
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			c.detail(P(sx * (W / 2 - 0.3), legH / 2, sz * (D / 2 - 0.3)), V(0.14, legH, 0.14), legC, M.Metal)
		end
	end
	c.part(P(0, legH + 0.35, 0), V(W - 0.1, 0.7, D - 0.1), shade(fabric, -0.15), M.Fabric)
	local armW = 0.5
	local inner = W - armW * 2
	local cw = inner / n
	for i = 1, n do
		local x = -inner / 2 + cw * (i - 0.5)
		c.seat(P(x, legH + 0.7 + 0.22, -0.25), V(cw - 0.05, 0.44, D - 1.0), fabric, M.Fabric)
		c.detail(P(x, 2.0, D / 2 - 0.85) * R(10, 0, 0), V(cw - 0.08, 1.15, 0.45), shade(fabric, 0.06), M.Fabric)
	end
	c.part(P(0, legH + 0.7 + 0.9, D / 2 - 0.3), V(W - 0.1, 1.8, 0.6), fabric, M.Fabric)
	for _, sx in { -1, 1 } do
		c.part(P(sx * (W / 2 - armW / 2), legH + 0.85, 0), V(armW, 1.7, D), fabric, M.Fabric)
	end
	c.use(V(0, 2, 0))
end

add({
	id = "sofa_office",
	category = "office",
	footprint = V(7, 2.85, 3),
	maxParts = 16,
	tags = { "sofa", "seat", "furniture" },
	build = function(c: Ctx)
		lounge(c, 3, 7)
	end,
})

add({
	id = "armchair",
	category = "office",
	footprint = V(3.2, 2.85, 3),
	maxParts = 12,
	tags = { "chair", "seat", "furniture" },
	build = function(c: Ctx)
		lounge(c, 1, 3.2)
	end,
})

return defs
