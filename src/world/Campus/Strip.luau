--!strict
-- The commercial strip on the south side of Eastbridge Avenue (storefronts face north at Plan.STRIP_Z): the Night Owl
-- Diner (open 24 hours, walk in and grab a booth), the Spin Cycle Laundromat (walk-in), Lucky Seven Pawn (shutter half
-- down), the alley, the Grind House (walk-up window where the barista serves), the vacant block "for lease", and the
-- Eastbridge Co-op corner store (walk-in; its counter is the campus_store shop interact). Bake-safe.

local Deps = require(script.Parent.Deps)
local Plan = require(script.Parent.Plan)
local Geo = require(script.Parent.Geo)
local Paint = require(script.Parent.Paint)
local Text = require(script.Parent.Text)
local Buildings = require(script.Parent.Buildings)
local Markers = require(script.Parent.Markers)
local Dress = require(script.Parent.Dress)

local Kit = Deps.Kit
local Props = Deps.Props
local Signs = Deps.Signs
local Core = Deps.Gui.Core
local Art = Deps.Gui.Art
local P = Deps.Palette
local C = P.campus
local hex = P.hex
local M = Enum.Material

local Strip = {}

local WALK = Plan.WALK
local Z = Plan.STRIP_Z

local function L(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, y, z)
end

type Spec = { x0: number, x1: number, d: number, h: number }

-- The building's frame: centre of its footprint on the ground, facing north (local +X = east, +Z = south/inside).
local function siteCf(s: Spec): CFrame
	return Plan.cf((s.x0 + s.x1) / 2, WALK, Z + s.d / 2, Plan.N)
end

-- Interior shop floor finish (on top of the lot asphalt) and an overhead fluorescent fixture row.
local function shopFloor(parent: Instance, front: CFrame, w: number, depth: number, color: Color3, mat: Enum.Material): Part
	local f = Kit.block(parent, L(front, 0, 0.05, depth / 2), Vector3.new(w, 0.1, depth), color, mat)
	f.Name = "ShopFloor"
	return f
end

local function tubes(parent: Instance, front: CFrame, y: number, xs: { number }, zs: { number }, lightAt: { number }?)
	for i, x in xs do
		for _, z in zs do
			local t = Kit.detail(parent, L(front, x, y, z), Vector3.new(0.8, 0.2, 5), hex("#F4F1E6"), M.Neon)
			t.Name = "Fluorescent"
			t.Transparency = 0.1
			t:AddTag("InteriorLight")
			if lightAt and table.find(lightAt, i) and z == zs[1] then
				Kit.light(t, "point", { Color = hex("#F4F1E6"), Range = 20, Brightness = 0.9 })
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Night Owl Diner
---------------------------------------------------------------------------------------------------
local function diner(m: Instance)
	local s: Spec = Plan.strip.diner
	local w = s.x1 - s.x0
	local depth, sh = 30, 13
	local bm, fr = Buildings.block(m, {
		name = "NightOwlDiner",
		cf = siteCf(s),
		w = w,
		d = s.d,
		h = s.h,
		seed = "diner",
		storeys = 1,
		color = hex("#B9B19C"),
		material = M.Metal,
		trim = hex("#8A2C2C"),
		shop = { depth = depth, height = sh },
		roof = { ac = 2, vents = 3 },
		graffiti = { "EB 4 LIFE" },
		graffitiFace = "left",
	})
	local front = fr.front
	-- chrome belt lines on the enamel
	for _, y in { 13.6, 15.6 } do
		Kit.detail(bm, L(front, 0, y, -0.15), Vector3.new(w + 0.2, 0.35, 0.3), hex("#C9CCCF"), M.Metal)
	end
	Buildings.storefront(bm, front, w, {
		height = sh,
		door = 13,
		open = true,
		glass = hex("#7E9096"),
		frame = hex("#A9ADB0"),
		bulkhead = hex("#8A2C2C"),
		seed = "diner-front",
	})
	Signs.neon(bm, L(fr.cf, 0, s.h + 0.6, -s.d / 2 + 2), {
		text = Text.diner,
		color = C.neonSign,
		width = 24,
		height = 4.2,
		font = "script",
		flicker = true,
	})
	Signs.neon(bm, L(front, -8, 6.5, 0.6), { text = Text.dinerOpen, color = hex("#5CE1FF"), width = 6, height = 1.6, flicker = true })
	-- inside: checkerboard floor, counter with stools, booths along the window, menu board, pie case, jukebox
	local floor = shopFloor(bm, front, w - 2.4, depth - 0.2, hex("#E6E0D2"), M.SmoothPlastic)
	local fg = Paint.surface(floor, Enum.NormalId.Top, 4)
	Core.checker(Core.bg(fg, hex("#E6E0D2")), 24, 18, hex("#E6E0D2"), hex("#2A2A2A"))
	local counter = L(front, -3, 0, 22)
	Kit.block(bm, L(counter, 0, 1.8, 0), Vector3.new(26, 3.6, 2.4), hex("#8A2C2C"), M.SmoothPlastic).Name = "Counter"
	Kit.block(bm, L(counter, 0, 3.75, -0.2), Vector3.new(26.6, 0.3, 3.2), hex("#D8D2C2"), M.Marble).Name = "CounterTop"
	for i = 0, 5 do
		Props.build("diner_counter_stool", bm, L(counter, -11 + i * 4.4, 0, -3.2), { seat = true, seed = "dstool" .. i })
	end
	for i, x in { -15, -6.5, 2 } do
		Props.build("diner_booth", bm, L(front, x, 0, 3.4), { seat = true, seed = "dbooth" .. i })
	end
	local back = Kit.detail(bm, L(front, -3, 9, depth - 0.15), Vector3.new(14, 3.6, 0.1), hex("#24262A"), M.SmoothPlastic)
	local mg = Paint.surface(back, Enum.NormalId.Front, 30, { glow = true, brightness = 0.9 })
	Art.menu(mg, "NIGHT OWL MENU", Text.dinerMenu, hex("#24262A"), hex("#F4F1E6"), C.mustard)
	-- the kitchen pass-through glows behind the counter
	local pass = Kit.detail(bm, L(front, -3, 5.6, depth - 0.12), Vector3.new(10, 2.4, 0.1), hex("#E8B66A"), M.Neon)
	pass.Name = "KitchenPass"
	pass.Transparency = 0.25
	pass:AddTag("InteriorLight")
	Kit.detail(bm, L(counter, 8, 4.6, 0), Vector3.new(2.6, 1.4, 1.6), hex("#AFC4CC"), M.Glass).Name = "PieCase"
	Kit.detail(bm, L(counter, -9, 4.4, 0.4), Vector3.new(1.6, 1.0, 1.0), hex("#2A2A2A"), M.Metal).Name = "CoffeeMaker"
	local jcf = L(front, -w / 2 + 2.4, 0, 12) * CFrame.Angles(0, math.rad(-90), 0)
	local juke = Kit.block(bm, L(jcf, 0, 2.6, 0), Vector3.new(3, 5.2, 2), hex("#6A2C1E"), M.Wood)
	juke.Name = "Jukebox"
	local jl = Kit.detail(bm, L(jcf, 0, 3.6, -1.05), Vector3.new(2.2, 2.4, 0.1), hex("#FF9A3C"), M.Neon)
	jl.Transparency = 0.3
	tubes(bm, front, sh - 0.4, { -10, 2, 13 }, { 8 }, { 2 })
	-- out back: grease bin and crates
	Props.build("dumpster", m, Plan.cf(-142, WALK, 76, Plan.S), { seed = "diner-dump" })
	Props.build("pallet_stack", m, Plan.cf(-126, WALK, 74, 12), { count = 2, seed = "diner-pallets" })
	Geo.pipe(m, Plan.v(-118, WALK + 2, Z + s.d + 0.6), Plan.v(-118, WALK + s.h + 4, Z + s.d + 0.6), 1.2, C.steel, M.CorrodedMetal, false).Name =
		"KitchenFlue"
end

---------------------------------------------------------------------------------------------------
-- Spin Cycle Laundromat
---------------------------------------------------------------------------------------------------
local function laundromat(m: Instance)
	local s: Spec = Plan.strip.laundromat
	local w = s.x1 - s.x0
	local depth, sh = 22, 13
	local bm, fr = Buildings.block(m, {
		name = "SpinCycleLaundromat",
		cf = siteCf(s),
		w = w,
		d = s.d,
		h = s.h,
		seed = "laundromat",
		storeys = 3,
		groundH = 14,
		color = hex("#7A3B2E"),
		shop = { depth = depth, height = sh },
		windows = { cols = 3, from = 2, to = 3, lit = 0.25, ac = 0.4 },
		painted = {
			Buildings.face("left", 6, 2, { ghost = Text.ghostSigns[1] }),
			Buildings.face("back", 3, 2, { ac = 0.3 }),
		},
		roof = { tanks = 1, ac = 1, vents = 2 },
		fireEscape = { x = -7, floors = 2 },
	})
	local front = fr.front
	Buildings.storefront(bm, front, w, {
		height = sh,
		sign = Text.laundromat,
		signSub = Text.laundromatSub,
		signColor = hex("#2C5E8A"),
		door = 9,
		open = true,
		seed = "laundry-front",
	})
	shopFloor(bm, front, w - 2.4, depth - 0.2, hex("#C9C2B0"), M.Slate)
	-- a row of washers on the back wall, dryers stacked on the west wall, the folding table and plastic chairs
	for i = 0, 4 do
		Props.build("laundry_machine", bm, L(front, -9 + i * 3.1, 0, depth - 2), {
			seed = "washer" .. i,
		})
	end
	for i = 0, 2 do
		local dc = L(front, -12.6, 0, 6 + i * 4.2) * CFrame.Angles(0, math.rad(-90), 0)
		Kit.block(bm, L(dc, 0, 3, 0), Vector3.new(3.6, 6, 2.6), hex("#D8D2C2"), M.Metal).Name = "Dryer"
		local door = Kit.detail(bm, L(dc, 0, 4.4, -1.35), Vector3.new(2, 2, 0.1), hex("#3A4248"), M.Glass)
		door.Transparency = 0.2
	end
	Kit.block(bm, L(front, 4, 1.7, 9), Vector3.new(7, 0.3, 3), hex("#E9E7E2"), M.SmoothPlastic).Name = "FoldingTable"
	for _, x in { 1.2, 6.8 } do
		Kit.block(bm, L(front, x, 0.8, 9), Vector3.new(0.3, 1.6, 2.6), hex("#8E8A82"), M.Metal)
	end
	for i, x in { 2, 4.5, 7 } do
		local ch = L(front, x, 0, 4.2)
		Kit.block(bm, L(ch, 0, 1.0, 0), Vector3.new(1.8, 0.25, 1.8), hex("#C9A13B"), M.Plastic).Name = "Chair" .. i
		Kit.detail(bm, L(ch, 0, 2.2, 0.85), Vector3.new(1.8, 2, 0.2), hex("#C9A13B"), M.Plastic)
	end
	local change = Kit.block(bm, L(front, 12, 3, depth - 1.5), Vector3.new(2.4, 6, 1.6), hex("#3E4A52"), M.Metal)
	change.Name = "ChangeMachine"
	local cs = Kit.detail(bm, L(front, 12, 4.4, depth - 2.35), Vector3.new(1.8, 1, 0.05), hex("#E04040"), M.Neon)
	cs.Transparency = 0.2
	tubes(bm, front, sh - 0.4, { -6, 6 }, { 6, 15 }, { 1 })
	local sign = Kit.detail(bm, L(front, 0, 7.4, depth - 0.12), Vector3.new(8, 1.4, 0.05), hex("#F4F1E6"), M.SmoothPlastic)
	Kit.sign(sign, Text.dormInside.laundry, { font = Enum.Font.SpecialElite, color = C.ink, pixelsPerStud = 30 })
end

---------------------------------------------------------------------------------------------------
-- Lucky Seven Pawn & Loan
---------------------------------------------------------------------------------------------------
local function pawn(m: Instance)
	local s: Spec = Plan.strip.pawn
	local w = s.x1 - s.x0
	local depth, sh = 14, 13
	local bm, fr = Buildings.block(m, {
		name = "LuckySevenPawn",
		cf = siteCf(s),
		w = w,
		d = s.d,
		h = s.h,
		seed = "pawn",
		storeys = 3,
		groundH = 14,
		color = hex("#6E3326"),
		shop = { depth = depth, height = sh },
		windows = { cols = 2, from = 2, to = 3, lit = 0.1 },
		painted = { Buildings.face("right", 5, 2), Buildings.face("back", 2, 2) },
		roof = { ac = 2, vents = 2 },
		graffiti = { "NO SLEEP", "BULLS?" },
		graffitiFace = "right",
	})
	local front = fr.front
	Buildings.storefront(bm, front, w, {
		height = sh,
		signStyle = "lightbox",
		sign = Text.pawn,
		signSub = Text.pawnSub,
		signColor = hex("#1A1A1A"),
		signInk = hex("#F2C94C"),
		door = 6,
		grille = 0.55,
		seed = "pawn-front",
	})
	shopFloor(bm, front, w - 2.4, depth - 0.2, hex("#6A5A48"), M.WoodPlanks)
	-- guitars on the back wall and a glass jewellery case
	for i = 0, 3 do
		local g = L(front, -7 + i * 4, 6.2, depth - 0.4) * CFrame.Angles(0, 0, math.rad(8 - i * 4))
		Kit.detail(bm, g, Vector3.new(1.4, 1.8, 0.3), ({ hex("#8A3B1E"), hex("#2A2A2A"), hex("#C9A13B"), hex("#6E8088") })[i + 1], M.Wood)
		Kit.detail(bm, L(g, 0, 1.9, 0), Vector3.new(0.3, 2.2, 0.2), hex("#2A2622"), M.Wood)
	end
	Kit.block(bm, L(front, -3, 1.8, 7), Vector3.new(10, 3.6, 2.2), hex("#3A2E24"), M.Wood).Name = "Case"
	local glass = Kit.detail(bm, L(front, -3, 4.2, 7), Vector3.new(10, 1.2, 2.2), hex("#AFC4CC"), M.Glass)
	glass.Transparency = 0.5
	Buildings.windowPoster(bm, L(front, -6, 6.6, -0.05), Vector3.new(4.4, 3, 0.05), "WE BUY GOLD", "Cash today · No questions", "pawn-poster")
	Signs.neon(bm, L(front, 7, 9.6, -1.2), { text = "LOANS", color = hex("#3CFF8A"), width = 4.2, height = 1.4 })
end

---------------------------------------------------------------------------------------------------
-- The Grind House: walk-up coffee window
---------------------------------------------------------------------------------------------------
local function grind(m: Instance)
	local s: Spec = Plan.strip.grind
	local w = s.x1 - s.x0
	local depth, sh = 18, 12
	local bm, fr = Buildings.block(m, {
		name = "GrindHouse",
		cf = siteCf(s),
		w = w,
		d = s.d,
		h = s.h,
		seed = "grind",
		storeys = 3,
		groundH = 13,
		color = hex("#5C2A21"),
		shop = { depth = depth, height = sh },
		windows = { cols = 3, from = 2, to = 3, lit = 0.35, ac = 0.3 },
		painted = { Buildings.face("back", 3, 2) },
		roof = { tanks = 1, ac = 1, vents = 2 },
		graffiti = { "STAY HUNGRY", "GRIND" },
		graffitiFace = "left",
	})
	local front = fr.front
	-- the barista stands at (Plan.npcs.npc_barista) behind the hatch counter
	local bx = Plan.npcs.npc_barista.Position.X - (s.x0 + s.x1) / 2 - Plan.ORIGIN.X
	Buildings.storefront(bm, front, w, {
		height = sh,
		sign = Text.grind,
		signSub = Text.grindSub,
		signColor = hex("#2F3A32"),
		signInk = hex("#ECE6DA"),
		door = -10,
		awning = hex("#2F5A3A"),
		awningStripe = hex("#E9E2CF"),
		hatch = { x = bx, w = 8, sill = 3.8 },
		seed = "grind-front",
	})
	shopFloor(bm, front, w - 2.4, depth - 0.2, hex("#5A4636"), M.WoodPlanks)
	local orderSign = Kit.detail(bm, L(front, bx, 8.3, -0.5), Vector3.new(5, 0.9, 0.08), hex("#ECE6DA"), M.SmoothPlastic)
	Kit.sign(orderSign, Text.grindWindow, { font = Enum.Font.Oswald, color = hex("#2F3A32"), pixelsPerStud = 40 })
	-- the inside counter under the hatch, espresso machine, pastry case, menu board, and a few seats
	Kit.block(bm, L(front, bx, 1.9, 1.4), Vector3.new(9, 3.8, 1.8), hex("#3E2A1E"), M.Wood).Name = "BarCounter"
	Kit.block(bm, L(front, 0, 1.9, 8.5), Vector3.new(w - 6, 3.8, 2.2), hex("#3E2A1E"), M.Wood).Name = "BackBar"
	Kit.detail(bm, L(front, bx - 1, 4.8, 8.5), Vector3.new(3, 2, 1.6), hex("#B8B8B0"), M.Metal).Name = "Espresso"
	local pc = Kit.detail(bm, L(front, bx + 4, 4.5, 8.5), Vector3.new(3.4, 1.4, 1.8), hex("#AFC4CC"), M.Glass)
	pc.Transparency = 0.4
	pc.Name = "PastryCase"
	local mb = Kit.detail(bm, L(front, 0, 8, depth - 0.12), Vector3.new(10, 3.6, 0.1), hex("#1E2420"), M.Slate)
	local mg = Paint.surface(mb, Enum.NormalId.Front, 30)
	Art.menu(mg, Text.grind, Text.grindMenu, hex("#1E2420"), hex("#ECE6DA"), C.mustard)
	tubes(bm, front, sh - 0.4, { -6, 6 }, { 7 }, { 1 })
	-- sidewalk seating and an A-frame
	for i, x in { 7, 12.2 } do
		local t = Plan.cf((s.x0 + s.x1) / 2 + x, WALK, Z - 4.5)
		Kit.cylinder(bm, L(t, 0, 3.1, 0), 0.15, 2.6, hex("#2A2A2A"), M.Metal)
		Kit.detail(bm, L(t, 0, 1.5, 0), Vector3.new(0.3, 3, 0.3), hex("#2A2A2A"), M.Metal)
		for _, sx in { -1, 1 } do
			local ch = L(t, sx * 2.2, 0, 0)
			Kit.block(bm, L(ch, 0, 1.8, 0), Vector3.new(1.6, 0.2, 1.6), hex("#2F5A3A"), M.Metal).Name = "CafeChair" .. i
			Kit.detail(bm, L(ch, 0, 0.9, 0), Vector3.new(0.2, 1.8, 0.2), hex("#2A2A2A"), M.Metal)
		end
	end
	local af = Plan.cf((s.x0 + s.x1) / 2 + 3, WALK, Z - 8, Plan.N)
	for _, sd in { -1, 1 } do
		local leaf = Kit.detail(bm, af * CFrame.new(0, 1.5, sd * 0.4) * CFrame.Angles(math.rad(12 * sd), 0, 0), Vector3.new(2, 3, 0.1), hex("#1E2420"), M.Wood)
		if sd < 0 then
			local g = Paint.surface(leaf, Enum.NormalId.Front, 40)
			Core.label(g, "ALL-NIGHTER\n4 SHOTS\n$4.75", 0.08, 0.1, 0.84, 0.8, hex("#ECE6DA"), {
				font = Enum.Font.PatrickHand,
				align = Enum.TextXAlignment.Center,
			})
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The vacant block (for lease)
---------------------------------------------------------------------------------------------------
local function vacant(m: Instance)
	local s: Spec = Plan.strip.vacant
	local w = s.x1 - s.x0
	local bm, fr = Buildings.block(m, {
		name = "VacantBlock",
		cf = siteCf(s),
		w = w,
		d = s.d,
		h = s.h,
		seed = "vacant",
		storeys = 5,
		groundH = 13,
		color = hex("#8A4632"),
		shop = { depth = 10, height = 12 },
		windows = { cols = 4, from = 2, to = 5, lit = 0.04, ac = 0.1 },
		painted = {
			Buildings.face("left", 6, 4, { lit = 0.02, ghost = Text.ghostSigns[2] }),
			Buildings.face("right", 6, 4, { lit = 0.02, ghost = Text.ghostSigns[3] }),
			Buildings.face("back", 4, 4, { lit = 0.02 }),
		},
		roof = { tanks = 1, vents = 3, hatch = true },
		fireEscape = { x = -6, floors = 4 },
	})
	local front = fr.front
	Buildings.storefront(bm, front, w, {
		height = 12,
		sign = Text.vacant,
		signColor = hex("#3A3A38"),
		signInk = hex("#C9C2B0"),
		grille = 1,
		seed = "vacant-front",
	})
	Buildings.windowPoster(bm, L(front, -8, 6, -0.95), Vector3.new(6, 4, 0.05), Text.vacant, Text.vacantSub, "lease-poster")
	Dress.flyerSheet(bm, L(front, 9, 5.5, -0.9), 5, 4, { Text.flyers[5], Text.flyers[7], Text.flyers[11], Text.flyers[2] }, "vacant-flyers")
	-- plywood over some upper windows
	local rng = Deps.Rng.new("vacant-boards")
	for _ = 1, 6 do
		local x = rng:range(-w / 2 + 5, w / 2 - 5)
		local y = rng:range(18, s.h - 6)
		Kit.detail(bm, L(front, x, y, -0.3), Vector3.new(5, 6.8, 0.2), Geo.vary(C.woodWorn, rng, 0.1), M.WoodPlanks).Name =
			"Plywood"
	end
end

---------------------------------------------------------------------------------------------------
-- Eastbridge Co-op (campus_store) and the walk-up to the apartments above
---------------------------------------------------------------------------------------------------
local PRODUCT_COLORS = {
	hex("#C8553D"),
	hex("#E2B93B"),
	hex("#2C5E8A"),
	hex("#3F6B3A"),
	hex("#E9E2CF"),
	hex("#8A2C2C"),
	hex("#5CB8D6"),
}

local function shelfFace(part: BasePart, face: Enum.NormalId, rng: Deps.RngT)
	local gui, W, H = Paint.surface(part, face, 10)
	Core.bg(gui, hex("#D8D2C2"))
	local rows = 4
	for r = 0, rows - 1 do
		local y = H * (r / rows)
		Core.px(gui, 0, y + H / rows - 4, W, 4, hex("#8E8A82"))
		local x = 2
		while x < W - 6 do
			local bw = rng:range(4, 10)
			local bh = rng:range(H / rows * 0.4, H / rows * 0.85)
			Core.px(gui, x, y + H / rows - 4 - bh, bw, bh, rng:pick(PRODUCT_COLORS))
			x += bw + rng:range(0.5, 2)
		end
	end
end

local function coop(m: Instance, mk: Instance)
	local s: Spec = Plan.strip.coop
	local w = s.x1 - s.x0
	local CS = Plan.coopShop
	local depth = CS.z1 - Z
	local sh = 13
	local cx = (s.x0 + s.x1) / 2
	local bm, fr = Buildings.block(m, {
		name = "EastbridgeCoop",
		cf = siteCf(s),
		w = w,
		d = s.d,
		h = s.h,
		seed = "coop",
		storeys = 2,
		groundH = 14,
		color = hex("#7A3B2E"),
		shop = { depth = depth, height = sh },
		windows = { cols = 6, from = 2, to = 2, lit = 0.35, ac = 0.35 },
		painted = {
			Buildings.face("right", 5, 1, { lit = 0.2 }),
			Buildings.face("back", 6, 1, { ac = 0.3 }),
		},
		roof = { tanks = 1, ac = 3, vents = 2 },
	})
	local front = fr.front
	local shopW = CS.x1 + 0 - s.x0 -- the store runs from the west wall to the partition
	local partitionX = CS.x1 - cx
	local storeCx = (s.x0 + CS.x1) / 2 - cx
	local storeFront = L(front, storeCx, 0, 0)
	Buildings.storefront(bm, storeFront, shopW, {
		height = sh,
		signStyle = "lightbox",
		sign = Text.coop,
		signColor = hex("#2F5A3A"),
		signInk = hex("#F4F1E6"),
		signSub = Text.coopSub,
		door = CS.doorX - (s.x0 + CS.x1) / 2,
		open = true,
		awning = hex("#2F5A3A"),
		awningStripe = hex("#C9A13B"),
		seed = "coop-front",
	})
	-- the apartments' street door beside the store (closed)
	local aptW = s.x1 - CS.x1
	Buildings.storefront(bm, L(front, (CS.x1 + s.x1) / 2 - cx, 0, 0), aptW, {
		height = sh,
		sign = "APTS 2A–2F",
		signColor = hex("#3A3A38"),
		door = 0,
		doorWidth = 6,
		seed = "coop-apts",
	})
	Kit.block(bm, L(front, partitionX, sh / 2, depth / 2), Vector3.new(1, sh, depth), hex("#C9C2B0"), M.SmoothPlastic).Name =
		"Partition"
	Kit.block(bm, L(front, partitionX, sh / 2, -0.4), Vector3.new(1.4, sh, 0.9), Kit.shade(hex("#7A3B2E"), -0.1), M.Brick).Name =
		"Pier"
	-- the apartments' stair rising behind their glass door
	Kit.stairs(bm, L(front, (CS.x1 + s.x1) / 2 - cx + 2, 0, 5) * CFrame.Angles(0, math.pi, 0), 5, 9, 1.2, 1.6, hex("#6A5A48"), M.WoodPlanks).Name =
		"AptStairs"
	Signs.neon(bm, L(storeFront, -11, 6.8, 0.6), { text = Text.coopOpen, color = hex("#FF4F5E"), width = 4, height = 1.6 })
	-- inside the store
	shopFloor(bm, storeFront, shopW - 2.4, depth - 0.2, hex("#D9D4C6"), M.SmoothPlastic)
	local rng = Deps.Rng.new("coop-shelves")
	for i, x in { -9, -2, 5 } do
		local sc = L(storeFront, x, 0, 14)
		local shelf = Kit.block(bm, L(sc, 0, 3.2, 0), Vector3.new(2.2, 6.4, 12), hex("#B8B2A4"), M.Metal)
		shelf.Name = "Gondola" .. i
		shelfFace(shelf, Enum.NormalId.Left, rng)
		shelfFace(shelf, Enum.NormalId.Right, rng)
		local tag = Kit.detail(bm, L(sc, 0, 9.4, 0), Vector3.new(0.2, 1.2, 6), hex("#2F5A3A"), M.SmoothPlastic)
		for _, f in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local tg = Paint.surface(tag, f, 30)
			Core.bg(tg, hex("#2F5A3A"))
			Core.label(tg, Text.coopAisles[i], 0.05, 0.1, 0.9, 0.8, hex("#F4F1E6"), {
				font = Enum.Font.Oswald,
				align = Enum.TextXAlignment.Center,
			})
		end
		Kit.detail(bm, L(sc, 0, 10.6, 0), Vector3.new(0.1, 1.6, 0.1), hex("#5A5A5A"), M.Metal)
	end
	-- a cooler wall along the back with glowing doors
	local cooler = Kit.block(bm, L(storeFront, -1, 4, depth - 1.6), Vector3.new(shopW - 6, 8, 3), hex("#E9E7E2"), M.Metal)
	cooler.Name = "Cooler"
	local cg, CW, CH = Paint.surface(cooler, Enum.NormalId.Front, 10, { glow = true, brightness = 1.1 })
	Core.bg(cg, hex("#CFE6EE"))
	local doors = 8
	for k = 0, doors - 1 do
		Core.px(cg, k * CW / doors, 0, 3, CH, hex("#8E9397"))
		for r = 1, 4 do
			Core.px(cg, k * CW / doors + 6, r * CH / 5, CW / doors - 12, 3, hex("#9AA3A8"))
			for q = 0, 4 do
				Core.px(cg, k * CW / doors + 8 + q * 5, r * CH / 5 - 9, 4, 9, rng:pick(PRODUCT_COLORS))
			end
		end
	end
	Kit.detail(bm, L(storeFront, -1, 8.6, depth - 3.15), Vector3.new(shopW - 6, 1.2, 0.1), hex("#2F5A3A"), M.SmoothPlastic).Name =
		"CoolerSign"
	-- the checkout counter by the door: the campus_store shop interact
	local doorLocal = CS.doorX - (s.x0 + CS.x1) / 2
	local co = L(storeFront, doorLocal - 9.5, 0, 6)
	local counter = Kit.block(bm, L(co, 0, 1.9, 0), Vector3.new(7, 3.8, 2.6), hex("#2F5A3A"), M.SmoothPlastic)
	counter.Name = "Checkout"
	Markers.interact(counter, "shop", { Shop = "campus_store" })
	Kit.detail(bm, L(co, 0, 3.85, 0), Vector3.new(7.4, 0.2, 3), hex("#D8D2C2"), M.Marble)
	local reg = Kit.detail(bm, L(co, -1.6, 4.6, 0.4), Vector3.new(1.6, 1.2, 1.2), hex("#2A2A2A"), M.Metal)
	reg.Name = "Register"
	local rs = Kit.detail(bm, L(co, -1.6, 5.1, -0.22), Vector3.new(1.2, 0.5, 0.05), hex("#3CFF8A"), M.Neon)
	rs.Transparency = 0.2
	Kit.detail(bm, L(co, 2, 4.4, 0), Vector3.new(2.4, 0.8, 1.6), hex("#C8553D"), M.SmoothPlastic).Name = "CandyRack"
	tubes(bm, storeFront, sh - 0.4, { -10, 0, 10 }, { 7, 17 }, { 2 })
	-- produce crates on the sidewalk under the awning
	for i, x in { -14, -10.5 } do
		local cr = L(storeFront, x, 0, -3)
		Kit.block(bm, L(cr, 0, 1.2, 0), Vector3.new(3, 2.4, 2.2), hex("#7F6A55"), M.WoodPlanks).Name = "Crate" .. i
		for k = 0, 5 do
			Kit.ball(bm, L(cr, -1 + (k % 3), 2.6, -0.5 + (k // 3)), 0.8, if i == 1 then hex("#C8553D") else hex("#E2B93B"), M.SmoothPlastic).CanCollide =
				false
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The alley between the pawn shop and the Grind House
---------------------------------------------------------------------------------------------------
local function alley(m: Instance)
	local a = Plan.alley
	local cx = (a.x0 + a.x1) / 2
	local rng = Deps.Rng.new("alley")
	Props.build("dumpster", m, Plan.cf(a.x0 + 3.6, WALK, 60, Plan.E), { seed = "alley-dump" })
	Props.build("trash_can", m, Plan.cf(a.x1 - 1.6, WALK, 44, 0), { seed = "alley-can" })
	for i = 1, 5 do
		Kit.ball(
			m,
			Plan.cf(a.x1 - 1.4 - rng:range(0, 2), WALK + 0.9, 48 + i * 1.6),
			rng:range(1.6, 2.2),
			hex("#1C1C1C"),
			M.Plastic
		).Name =
			"TrashBag"
	end
	Props.build("chainlink_fence", m, Plan.cf(cx - 2.5, WALK, 72, 8), { length = 7, seed = "alley-gate" })
	Dress.litter(m, a.x0, Z, a.x1, 84, 14, rng)
	-- a steam vent and a lone pipe
	Kit.detail(m, Plan.cf(cx, WALK + 0.04, 36), Vector3.new(2.4, 0.08, 2.4), hex("#2A2826"), M.DiamondPlate).Name = "Grate"
end

---------------------------------------------------------------------------------------------------
-- Back alley behind the strip
---------------------------------------------------------------------------------------------------
local function backAlley(m: Instance)
	local b = Plan.backAlley
	local rng = Deps.Rng.new("back-alley")
	Props.build("dumpster", m, Plan.cf(-96, WALK, 86.6, Plan.N), { seed = "ba-d1" })
	Props.build("dumpster", m, Plan.cf(-30, WALK, 86.6, Plan.N), { seed = "ba-d2" })
	Props.build("dumpster", m, Plan.cf(30, WALK, 86.6, Plan.N), { seed = "ba-d3" })
	Props.build("pallet_stack", m, Plan.cf(-70, WALK, 87, 4), { count = 3, seed = "ba-p1" })
	Props.build("pallet_stack", m, Plan.cf(50, WALK, 87.5, -8), { count = 5, seed = "ba-p2" })
	Props.build("ac_unit", m, Plan.cf(-4, WALK, 86.4, Plan.N), { seed = "ba-ac" })
	-- back doors and caged bulbs
	for i, x in { -104, -66, -30, -4, 30, 58 } do
		local d = Plan.cf(x + 3, WALK, b.z0, Plan.S)
		Kit.detail(m, L(d, 0, 4.25, -0.12), Vector3.new(3.6, 8.5, 0.25), Geo.vary(hex("#4A4E52"), rng, 0.1), M.DiamondPlate).Name =
			"BackDoor" .. i
		if i % 2 == 1 then
			Dress.lantern(m, L(d, 0, 10, 0), i ~= 3)
		end
	end
	Dress.litter(m, b.x0, b.z0, b.x1, b.z1, 24, rng)
end

---------------------------------------------------------------------------------------------------
function Strip.build(parent: Instance, mk: Instance): Model
	local m = Kit.model(parent, "Strip")
	diner(m)
	laundromat(m)
	pawn(m)
	grind(m)
	vacant(m)
	coop(m, mk)
	alley(m)
	backAlley(m)
	return m
end

return Strip
