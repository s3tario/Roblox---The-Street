--!strict
-- Low-part furniture for the venues, where Props pieces would blow the part budget (24 apartments, lounges full of
-- seating). Bake-safe. Every function takes `cf` = the floor point under the piece's centre with LookVector = its
-- front (where you sit, stand or look from), so local -Z is the front and +Z the back. Bodies people bump into
-- collide; trim, cushions and small parts are Kit.detail.
--
--   Furniture.sofa(parent, cf, width, color, o?) -> Model        seat, back, arms, cushion line (5 parts)
--   Furniture.armchair(parent, cf, color, o?) -> Model           seat, back, arms (3 parts)
--   Furniture.table(parent, cf, size, top, base?, mat?) -> Model rectangular top on a plinth (2 parts)
--   Furniture.roundTable(parent, cf, diameter, height, top, base?) -> Model   disc on a pedestal (2 parts)
--   Furniture.chair(parent, cf, color, o?) -> Model              seat, back, leg (3 parts)
--   Furniture.stool(parent, cf, height, seat, frame?) -> Model   seat and pole (2 parts)
--   Furniture.bed(parent, cf, width, length, o) -> Model         frame, mattress, duvet, pillows, headboard (6 parts)
--   Furniture.nightstand(parent, cf, color, lamp?) -> Model      cabinet and a lit shade (1-2 parts)
--   Furniture.plant(parent, cf, scale?, rng?) -> Model           pot and foliage (3 parts)
--   Furniture.screen(parent, cf, w, h, kind, rng) -> Part        a wall TV / display (cf on the wall face, LookVector out)
--   Furniture.kitchen(parent, cf, length, o) -> Model            a run of base and wall cabinets with a sink and hob,
--                                                               plus a fridge at the +X end (cf at the cabinets' front
--                                                               face centre on the floor, LookVector into the room)
--   Furniture.desk(parent, cf, width, depth, color, o?) -> Model top on two panel legs (3 parts)
--   Furniture.monitor(parent, cf, w, rng, kind?) -> Part         screen (returned) on a stand; cf on the desk top
--   Furniture.pendant(parent, cf, drop, shade?, light?) -> Part  ceiling pendant: cf = the ceiling point
--   Furniture.planter(parent, cf, size, o?) -> Model             a box planter with a hedge (2 parts)
--   Furniture.bench(parent, cf, length, color, o?) -> Model      a slab bench on two legs (3 parts)

local Deps = require(script.Parent.Deps)
local Shell = require(script.Parent.Shell)

local Kit = Deps.Kit
local Gui = Deps.Gui
local hex = Deps.Palette.hex
local M = Enum.Material

local Furniture = {}

local DARK_METAL = hex("#2B2B2D")

export type SofaOpts = { accent: Color3?, legs: Color3?, depth: number?, material: Enum.Material?, name: string? }

function Furniture.sofa(parent: Instance, cf: CFrame, width: number, color: Color3, o: SofaOpts?): Model
	local opts: SofaOpts = o or {}
	local m = Kit.model(parent, opts.name or "Sofa")
	local d = opts.depth or 3.4
	local mat = opts.material or M.Fabric
	local seat = Kit.block(m, cf * CFrame.new(0, 0.85, 0), Vector3.new(width, 1.3, d), color, mat)
	seat.Name = "SofaSeat"
	Kit.block(m, cf * CFrame.new(0, 2.3, d / 2 - 0.4), Vector3.new(width, 2.2, 0.8), color, mat).Name = "SofaBack"
	for _, s in { -1, 1 } do
		Kit.detail(m, cf * CFrame.new(s * (width / 2 - 0.35), 1.85, 0.1), Vector3.new(0.7, 1.1, d - 0.2), color, mat).Name =
			"SofaArm"
	end
	Kit.detail(
		m,
		cf * CFrame.new(0, 1.58, -0.25),
		Vector3.new(width - 1.5, 0.22, d - 1.1),
		opts.accent or Kit.shade(color, 0.12),
		mat
	).Name =
		"Cushions"
	return m
end

function Furniture.armchair(parent: Instance, cf: CFrame, color: Color3, o: SofaOpts?): Model
	local opts: SofaOpts = o or {}
	local m = Kit.model(parent, opts.name or "Armchair")
	local mat = opts.material or M.Fabric
	Kit.block(m, cf * CFrame.new(0, 0.85, 0), Vector3.new(3, 1.3, 3), color, mat).Name = "ChairSeat"
	Kit.detail(m, cf * CFrame.new(0, 2.4, 1.15), Vector3.new(3, 2.2, 0.7), color, mat).Name = "ChairBack"
	Kit.detail(
		m,
		cf * CFrame.new(0, 1.85, 0.1),
		Vector3.new(3.4, 0.8, 2.6),
		opts.accent or Kit.shade(color, -0.12),
		mat
	).Name =
		"ChairArms"
	return m
end

function Furniture.table(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	top: Color3,
	base: Color3?,
	mat: Enum.Material?
): Model
	local m = Kit.model(parent, "Table")
	Kit.block(m, cf * CFrame.new(0, size.Y - 0.15, 0), Vector3.new(size.X, 0.3, size.Z), top, mat or M.Wood).Name =
		"TableTop"
	Kit.block(
		m,
		cf * CFrame.new(0, (size.Y - 0.3) / 2, 0),
		Vector3.new(math.max(0.6, size.X - 1.2), size.Y - 0.3, math.max(0.6, size.Z - 1.2)),
		base or Kit.shade(top, -0.35),
		M.SmoothPlastic
	).Name =
		"TableBase"
	return m
end

function Furniture.roundTable(
	parent: Instance,
	cf: CFrame,
	diameter: number,
	height: number,
	top: Color3,
	base: Color3?
): Model
	local m = Kit.model(parent, "RoundTable")
	Kit.cylinder(m, cf * CFrame.new(0, height - 0.12, 0), 0.24, diameter, top, M.Marble).Name = "TableTop"
	Kit.cylinder(m, cf * CFrame.new(0, (height - 0.24) / 2, 0), height - 0.24, 0.5, base or DARK_METAL, M.Metal).Name =
		"Pedestal"
	return m
end

export type ChairOpts = { back: Color3?, leg: Color3?, material: Enum.Material? }

function Furniture.chair(parent: Instance, cf: CFrame, color: Color3, o: ChairOpts?): Model
	local opts: ChairOpts = o or {}
	local m = Kit.model(parent, "Chair")
	local mat = opts.material or M.Fabric
	Kit.block(m, cf * CFrame.new(0, 1.75, 0), Vector3.new(1.9, 0.3, 1.9), color, mat).Name = "Seat"
	Kit.detail(m, cf * CFrame.new(0, 3.1, 0.85), Vector3.new(1.9, 2.4, 0.25), opts.back or color, mat).Name =
		"ChairBack"
	Kit.detail(m, cf * CFrame.new(0, 0.8, 0), Vector3.new(0.3, 1.6, 0.3), opts.leg or DARK_METAL, M.Metal).Name =
		"ChairLeg"
	return m
end

function Furniture.stool(parent: Instance, cf: CFrame, height: number, seat: Color3, frame: Color3?): Model
	local m = Kit.model(parent, "Stool")
	Kit.cylinder(m, cf * CFrame.new(0, height - 0.2, 0), 0.4, 1.7, seat, M.Leather).Name = "StoolSeat"
	Kit.cylinder(m, cf * CFrame.new(0, (height - 0.4) / 2, 0), height - 0.4, 0.35, frame or hex("#B8933F"), M.Metal).Name =
		"StoolPole"
	return m
end

export type BedOpts = {
	frame: Color3,
	sheet: Color3?,
	duvet: Color3,
	pillow: Color3?,
	headboard: Color3?,
	headboardHeight: number?,
}

-- The headboard is at the back (+Z): cf's LookVector points from the head of the bed toward its foot.
function Furniture.bed(parent: Instance, cf: CFrame, width: number, length: number, o: BedOpts): Model
	local m = Kit.model(parent, "Bed")
	Kit.block(m, cf * CFrame.new(0, 0.6, 0), Vector3.new(width, 1.2, length), o.frame, M.Wood).Name = "BedFrame"
	Kit.block(
		m,
		cf * CFrame.new(0, 1.55, 0.1),
		Vector3.new(width - 0.3, 0.7, length - 0.4),
		o.sheet or hex("#F1EEE8"),
		M.Fabric
	).Name =
		"Mattress"
	Kit.detail(
		m,
		cf * CFrame.new(0, 1.97, -length * 0.14),
		Vector3.new(width - 0.1, 0.16, length * 0.68),
		o.duvet,
		M.Fabric
	).Name =
		"Duvet"
	local pw = math.min(2.6, (width - 0.8) / 2)
	for _, s in { -1, 1 } do
		Kit.detail(
			m,
			cf * CFrame.new(s * (pw / 2 + 0.15), 2.2, length / 2 - 1.1),
			Vector3.new(pw, 0.55, 1.2),
			o.pillow or hex("#FAF8F3"),
			M.Fabric
		).Name =
			"Pillow"
	end
	local hh = o.headboardHeight or 4.6
	Kit.block(
		m,
		cf * CFrame.new(0, hh / 2, length / 2 + 0.25),
		Vector3.new(width + 0.6, hh, 0.5),
		o.headboard or o.frame,
		M.Fabric
	).Name =
		"Headboard"
	return m
end

function Furniture.nightstand(parent: Instance, cf: CFrame, color: Color3, lamp: boolean?): Model
	local m = Kit.model(parent, "Nightstand")
	Kit.block(m, cf * CFrame.new(0, 1.1, 0), Vector3.new(2, 2.2, 1.8), color, M.Wood).Name = "Cabinet"
	if lamp then
		local shade = Shell.glow(m, cf * CFrame.new(0, 3, 0.2), Vector3.new(0.9, 1.1, 0.9), hex("#FFE7BF"))
		shade.Name = "LampShade"
		shade.Transparency = 0.15
	end
	return m
end

local FOLIAGE = { hex("#3F6B3A"), hex("#4C7A3F"), hex("#355E33"), hex("#5A8A4A") }

function Furniture.plant(parent: Instance, cf: CFrame, scale: number?, rng: Deps.RngT?): Model
	local s = scale or 1
	local m = Kit.model(parent, "Plant")
	local leaf = if rng then rng:pick(FOLIAGE) else FOLIAGE[1]
	Kit.cylinder(m, cf * CFrame.new(0, 0.9 * s, 0), 1.8 * s, 1.8 * s, hex("#2E2C2A"), M.SmoothPlastic).Name = "Pot"
	Kit.ball(m, cf * CFrame.new(0, 3.1 * s, 0), 2.8 * s, leaf, M.Grass, { CanCollide = false }).Name = "Foliage"
	Kit.ball(m, cf * CFrame.new(0.35 * s, 4.4 * s, -0.2 * s), 1.9 * s, Kit.shade(leaf, 0.12), M.Grass, {
		CanCollide = false,
	}).Name =
		"Foliage"
	return m
end

-- kind: a Gui.Screens kind ("chart", "news", ...) or "art" (an abstract painting) or "tv" (a news broadcast).
function Furniture.screen(parent: Instance, cf: CFrame, w: number, h: number, kind: string, rng: Deps.RngT): Part
	local p = Kit.detail(parent, cf * CFrame.new(0, 0, -0.12), Vector3.new(w, h, 0.24), hex("#0D0F12"), M.SmoothPlastic)
	p.Name = "Screen"
	if kind == "art" then
		local gui, W, H = Gui.Core.surface(p, Enum.NormalId.Front, { pps = 12, maxDistance = 140 })
		Gui.Art.painting(gui, W, H, rng:int(1, Gui.Art.PAINTING_VARIANTS), rng)
	else
		Gui.Screens.screen(p, if kind == "tv" then "news" else kind, rng)
	end
	return p
end

export type KitchenOpts = { cabinet: Color3, counter: Color3, splash: Color3?, fridge: Color3?, uppers: boolean? }

function Furniture.kitchen(parent: Instance, cf: CFrame, length: number, o: KitchenOpts): Model
	local m = Kit.model(parent, "Kitchenette")
	local depth = 2.4
	local run = length - 3 -- the fridge takes the last 3 studs at +X
	local runC = cf * CFrame.new(-1.5, 0, depth / 2)
	Kit.block(m, runC * CFrame.new(0, 1.55, 0), Vector3.new(run, 3.1, depth), o.cabinet, M.Wood).Name = "BaseCabinets"
	Kit.detail(m, runC * CFrame.new(0, 3.22, -0.05), Vector3.new(run + 0.1, 0.24, depth + 0.15), o.counter, M.Marble).Name =
		"Countertop"
	Kit.detail(
		m,
		runC * CFrame.new(0, 4.6, depth / 2 - 0.05),
		Vector3.new(run, 2.5, 0.1),
		o.splash or hex("#E8E4DC"),
		M.Glass
	).Name =
		"Backsplash"
	if o.uppers ~= false then
		Kit.detail(m, runC * CFrame.new(0, 7.4, depth / 2 - 0.75), Vector3.new(run, 3, 1.4), o.cabinet, M.Wood).Name =
			"WallCabinets"
		Shell.glow(m, runC * CFrame.new(0, 5.84, depth / 2 - 0.75), Vector3.new(run - 0.6, 0.08, 0.3), hex("#FFE9C4"))
	end
	Kit.detail(m, runC * CFrame.new(-run * 0.22, 3.36, 0), Vector3.new(2.2, 0.06, 1.4), hex("#9EA3A8"), M.Metal).Name =
		"Sink"
	Kit.detail(m, runC * CFrame.new(-run * 0.22, 3.9, 0.85), Vector3.new(0.2, 1.1, 0.2), hex("#C9CDD2"), M.Metal).Name =
		"Faucet"
	Kit.detail(m, runC * CFrame.new(run * 0.2, 3.36, 0), Vector3.new(2.4, 0.06, 1.7), hex("#141416"), M.Glass).Name =
		"Cooktop"
	local fridgeC = cf * CFrame.new(length / 2 - 1.5, 0, depth / 2 + 0.1)
	Kit.block(m, fridgeC * CFrame.new(0, 4.6, 0), Vector3.new(3, 9.2, depth + 0.2), o.fridge or hex("#BFC3C7"), M.Metal).Name =
		"Fridge"
	Kit.detail(
		m,
		fridgeC * CFrame.new(-1.1, 4.8, -depth / 2 - 0.2),
		Vector3.new(0.15, 3.2, 0.15),
		hex("#E4E6E8"),
		M.Metal
	).Name =
		"FridgeHandle"
	return m
end

export type DeskOpts = { legs: Color3?, material: Enum.Material?, height: number? }

function Furniture.desk(parent: Instance, cf: CFrame, width: number, depth: number, color: Color3, o: DeskOpts?): Model
	local opts: DeskOpts = o or {}
	local h = opts.height or 3.1
	local m = Kit.model(parent, "Desk")
	Kit.block(m, cf * CFrame.new(0, h - 0.15, 0), Vector3.new(width, 0.3, depth), color, opts.material or M.Wood).Name =
		"DeskTop"
	for _, s in { -1, 1 } do
		Kit.block(
			m,
			cf * CFrame.new(s * (width / 2 - 0.2), (h - 0.3) / 2, 0),
			Vector3.new(0.3, h - 0.3, depth - 0.3),
			opts.legs or DARK_METAL,
			M.Metal
		).Name =
			"DeskLeg"
	end
	return m
end

function Furniture.monitor(parent: Instance, cf: CFrame, w: number, rng: Deps.RngT, kind: string?): Part
	local h = w * 0.58
	Kit.detail(parent, cf * CFrame.new(0, 0.55, 0.15), Vector3.new(0.3, 1.1, 0.3), DARK_METAL, M.Metal).Name =
		"MonitorStand"
	local screen = Kit.block(
		parent,
		cf * CFrame.new(0, 1.05 + h / 2, 0),
		Vector3.new(w, h, 0.2),
		hex("#101215"),
		M.SmoothPlastic,
		{
			CanCollide = false,
		}
	)
	screen.Name = "Monitor"
	Gui.Screens.screen(screen, kind or "chart", rng)
	return screen
end

export type PendantLight = { range: number?, brightness: number?, color: Color3? }

function Furniture.pendant(parent: Instance, cf: CFrame, drop: number, shade: Color3?, light: PendantLight?): Part
	Kit.detail(parent, cf * CFrame.new(0, -drop / 2, 0), Vector3.new(0.1, drop, 0.1), DARK_METAL, M.Metal).Name =
		"PendantCord"
	local s = Kit.cylinder(parent, cf * CFrame.new(0, -drop - 0.5, 0), 1, 1.6, shade or hex("#FFE7BF"), M.Neon, {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	s.Name = "PendantShade"
	s:AddTag("InteriorLight")
	if light then
		Kit.light(s, "point", {
			Color = light.color or hex("#FFE2B0"),
			Range = light.range or 18,
			Brightness = light.brightness or 0.8,
		})
	end
	return s
end

export type PlanterOpts = { box: Color3?, leaf: Color3?, material: Enum.Material? }

function Furniture.planter(parent: Instance, cf: CFrame, size: Vector3, o: PlanterOpts?): Model
	local opts: PlanterOpts = o or {}
	local m = Kit.model(parent, "Planter")
	Kit.block(m, cf * CFrame.new(0, size.Y / 2, 0), size, opts.box or hex("#3B3F3A"), opts.material or M.Concrete).Name =
		"PlanterBox"
	Kit.detail(
		m,
		cf * CFrame.new(0, size.Y + 0.6, 0),
		Vector3.new(size.X - 0.4, 1.4, size.Z - 0.4),
		opts.leaf or FOLIAGE[2],
		M.Grass
	).Name =
		"Hedge"
	return m
end

export type BenchOpts = { legs: Color3?, material: Enum.Material?, depth: number? }

function Furniture.bench(parent: Instance, cf: CFrame, length: number, color: Color3, o: BenchOpts?): Model
	local opts: BenchOpts = o or {}
	local m = Kit.model(parent, "Bench")
	local d = opts.depth or 2
	Kit.block(m, cf * CFrame.new(0, 1.55, 0), Vector3.new(length, 0.4, d), color, opts.material or M.Wood).Name =
		"BenchSeat"
	for _, s in { -1, 1 } do
		Kit.detail(
			m,
			cf * CFrame.new(s * (length / 2 - 0.8), 0.68, 0),
			Vector3.new(0.4, 1.35, d - 0.2),
			opts.legs or DARK_METAL,
			M.Metal
		).Name =
			"BenchLeg"
	end
	return m
end

return Furniture
