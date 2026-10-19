--!strict
-- Exchange Plaza, the centre block between Bank Row and Exchange Avenue: granite paving with marble inlays along
-- the processional axis, the fountain, "The Contest" (the fictional bull-and-bear bronze), the ten leaderboard
-- monoliths (each a "Screen" part with BoardId and a "leaderboard" interact), flags, the runway strip, the muster
-- point and the pigeon square, the subway entrance (door_street_subway) with the Spawn_street spawn and the
-- street_station_platform anchor, the newsstand (news_stand + npc_newsie), the store kiosk and the two company
-- directory kiosks. Bake-safe.
--
--   Plaza.build(parent) -> Model

local Deps = require(script.Parent.Deps)
local Look = require(script.Parent.Look)
local Plan = require(script.Parent.Plan)
local Text = require(script.Parent.Text)

local Kit = Deps.Kit
local Props = Deps.Props
local Signs = Deps.Signs
local Gui = Deps.Gui
local World = Deps.World
local M = Enum.Material

local Plaza = {}

local FLOOR = Plan.FLOOR
local P = Plan.plaza

local function at(v: Vector3, face: string): CFrame
	local pos = Vector3.new(v.X, FLOOR, v.Z)
	return CFrame.lookAt(pos, pos + Plan.FACE_DIR[face])
end

local function facing(v: Vector3, dir: Vector3): CFrame
	local pos = Vector3.new(v.X, FLOOR, v.Z)
	return CFrame.lookAt(pos, pos + dir)
end

-- Inlays lie flat on the paving. Each layer sits a hair higher than the one below it so crossing bands never
-- share a top plane (no z-fighting where the axis crosses the border, the ring or the runway).
local LAYER = { promenade = 0, border = 1, axis = 2, edge = 3, ring = 4, runway = 5, runwayEdge = 6 }

local function inlay(
	parent: Instance,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	color: Color3,
	mat: Enum.Material,
	layer: number
)
	local top = FLOOR + 0.02 + layer * 0.012
	local p = Kit.detail(
		parent,
		CFrame.new((x0 + x1) / 2, top - 0.02, (z0 + z1) / 2),
		Vector3.new(x1 - x0, 0.04, z1 - z0),
		color,
		mat
	)
	p.CastShadow = false
	return p
end

local function paving(m: Instance)
	local g = Kit.model(m, "Paving")
	-- processional axis from Bank Row to Exchange Avenue
	inlay(g, -6, 6, P.z0, P.z1, Look.marble, M.Marble, LAYER.axis).Name = "Axis"
	for _, sx in { -1, 1 } do
		inlay(g, sx * 6.6 - 0.3, sx * 6.6 + 0.3, P.z0, P.z1, Look.gold, M.Metal, LAYER.edge)
		-- darker granite promenades under the monolith rows
		inlay(g, sx * P.boardX - 7, sx * P.boardX + 7, -66, 66, Look.granite, M.Granite, LAYER.promenade)
	end
	-- a border band inset from the plaza edge
	local i = 8
	inlay(g, P.x0 + i, P.x1 - i, P.z0 + i, P.z0 + i + 1.2, Look.graniteLight, M.Granite, LAYER.border)
	inlay(g, P.x0 + i, P.x1 - i, P.z1 - i - 1.2, P.z1 - i, Look.graniteLight, M.Granite, LAYER.border)
	-- an octagonal marble ring around the fountain
	local f = P.fountain
	for k = 0, 7 do
		local a = k * math.pi / 4
		local r = 16
		local cf = CFrame.new(f.X + math.cos(a) * r, FLOOR + LAYER.ring * 0.012, f.Z + math.sin(a) * r)
			* CFrame.Angles(0, -a + math.pi / 2, 0)
		local seg = Kit.detail(g, cf, Vector3.new(13.6, 0.04, 2), Look.marble, M.Marble)
		seg.CastShadow = false
	end
	return g
end

-- One leaderboard monolith: black granite slab, gilt cap and title, a glowing Screen part carrying BoardId and
-- the "leaderboard" interact. The baked placeholder face shows the title until the leaderboards feature draws.
local function monolith(m: Instance, cf: CFrame, boardId: string)
	local g = Kit.model(m, "Monolith_" .. boardId)
	g:SetAttribute("BoardId", boardId)
	Kit.block(g, cf * CFrame.new(0, 0.5, 0), Vector3.new(9.4, 1, 4.4), Look.graniteDark, M.Granite).Name = "Plinth"
	Kit.block(g, cf * CFrame.new(0, 8.5, 0), Vector3.new(8.2, 15, 2.6), Look.blackGranite, M.Granite).Name = "Slab"
	Kit.detail(g, cf * CFrame.new(0, 16.3, 0), Vector3.new(8.8, 0.6, 3.2), Look.gold, M.Metal).Name = "Cap"
	for _, sx in { -1, 1 } do
		Kit.detail(g, cf * CFrame.new(sx * 4.0, 8.5, -1.32), Vector3.new(0.18, 15, 0.1), Look.gold, M.Metal)
	end
	local header = Kit.detail(g, cf * CFrame.new(0, 14.1, -1.35), Vector3.new(7.4, 2, 0.1), Look.black, M.SmoothPlastic)
	header.Name = "Header"
	Kit.sign(header, Text.get("board_" .. boardId), {
		color = Look.gold,
		font = Enum.Font.Garamond,
		pixelsPerStud = 60,
		glow = true,
		padding = 0.1,
	})
	local screen =
		Kit.detail(g, cf * CFrame.new(0, 7.6, -1.36), Vector3.new(7.4, 10.4, 0.12), Look.screen, M.SmoothPlastic)
	screen.Name = "Screen"
	screen:SetAttribute("BoardId", boardId)
	Kit.interact(screen, "leaderboard", { BoardId = boardId })
	local gui = Gui.Core.surface(screen, Enum.NormalId.Front, {
		glow = true,
		brightness = 1.15,
		pps = 50,
		maxDistance = 140,
		name = "BoardPlaceholder",
	})
	gui:SetAttribute("Placeholder", true)
	Gui.Core.bg(gui, Look.screen)
	Gui.Core.label(gui, Text.get("board_" .. boardId), 0.06, 0.04, 0.88, 0.09, Look.goldBright, {
		font = Enum.Font.GothamBold,
		align = Enum.TextXAlignment.Center,
	})
	Gui.Core.frame(gui, 0.08, 0.145, 0.84, 0.004, Look.gold)
	for r = 1, 5 do
		local y = 0.17 + (r - 1) * 0.105
		local row = Gui.Core.frame(gui, 0.06, y, 0.88, 0.09, Look.navy, if r % 2 == 0 then 0.6 else 0.3)
		Gui.Core.label(row, tostring(r), 0.03, 0.1, 0.12, 0.8, Look.gold, { font = Enum.Font.GothamBold })
		Gui.Core.frame(row, 0.18, 0.42, 0.5 - r * 0.04, 0.16, Look.white, 0.75)
		Gui.Core.frame(row, 0.78, 0.42, 0.16, 0.16, Look.white, 0.75)
	end
	Gui.Core.label(gui, Text.get("board_tap"), 0.08, 0.72, 0.84, 0.08, Look.white, {
		font = Enum.Font.GothamMedium,
		align = Enum.TextXAlignment.Center,
	})
	local footer = if boardId == "RobuxSpent" then "board_footer_supporter" else "board_footer"
	Gui.Core.label(gui, Text.get(footer), 0.06, 0.86, 0.88, 0.07, Look.limestoneDark, {
		font = Enum.Font.Gotham,
		align = Enum.TextXAlignment.Center,
	})
	return g
end

local function boards(m: Instance)
	local g = Kit.model(m, "Leaderboards")
	local perRow = #P.boardZ
	for i, id in Plan.boards do
		local west = i <= perRow
		local z = P.boardZ[((i - 1) % perRow) + 1]
		local x = if west then -P.boardX else P.boardX
		-- west row faces east, east row faces west: both read from the axis
		local dir = if west then Vector3.new(1, 0, 0) else Vector3.new(-1, 0, 0)
		monolith(g, facing(Vector3.new(x, 0, z), dir), id)
	end
	return g
end

local function subway(m: Instance)
	local g = Kit.model(m, "Subway")
	local cf = at(Plan.subway.pos, Plan.subway.face)
	Props.build("subway_entrance", g, cf, { seed = "street-subway" })
	-- door trigger over the top of the stairs (between the side walls), under the SUBWAY sign
	local door = Kit.door(g, "door_street_subway", cf * CFrame.new(0, 5.2, -3.4), Vector3.new(5.4, 10, 4))
	door.Name = "door_street_subway"
	-- station name plate on posts behind the stairs
	for _, sx in { -1, 1 } do
		Kit.detail(g, cf * CFrame.new(sx * 2.8, 2.6, 6.7), Vector3.new(0.25, 3.2, 0.25), Look.iron, M.Metal)
	end
	local plate = Kit.detail(g, cf * CFrame.new(0, 4.6, 6.7), Vector3.new(7, 1.4, 0.2), Look.black, M.SmoothPlastic)
	Kit.sign(
		plate,
		Text.get("subway_station"),
		{ color = Look.white, font = Enum.Font.GothamBold, glow = true, pixelsPerStud = 40 }
	)
	Kit.sign(plate, Text.get("subway_line"), {
		face = Enum.NormalId.Back,
		color = Look.white,
		font = Enum.Font.GothamBold,
		glow = true,
		pixelsPerStud = 40,
	})
	-- arrivals: the spawn and the platform anchor a few strides in front of the stairs, facing the plaza
	local st = Plan.station
	local spawnCF = facing(Vector3.new(st.X, 0, st.Z), Vector3.new(0, 0, -1)) * CFrame.new(0, -0.45, 0)
	Kit.spawn(g, "Spawn_street", spawnCF)
	Kit.anchor(
		g,
		"street_station_platform",
		facing(Vector3.new(st.X, 0, st.Z), Vector3.new(0, 0, -1)) * CFrame.new(0, 3, 0)
	)
	-- wayfinding totem at the station exit
	Signs.wayfinding(g, at(Vector3.new(st.X - 9, 0, st.Z + 4), "N"), {
		title = Text.get("subway_title"),
		entries = {
			Text.get("subway_line3"),
			"^ " .. Text.get("road_bank_row"),
			"> " .. Text.get("galleria_name"),
			"< " .. Text.get("career_services_name"),
		},
		seed = "station-wayfinding",
	})
	return g
end

local function newsstand(m: Instance)
	local g = Kit.model(m, "Newsstand")
	local cf = at(Plan.newsstand.pos, Plan.newsstand.face)
	Props.build("newsstand", g, cf, { seed = "benedetto" })
	local fp = Props.get("newsstand")
	local half = if fp then fp.footprint.Z / 2 else 3.5
	Kit.interactPoint(g, "news_stand", cf * CFrame.new(0, 3, -half - 0.8))
	-- the newsie stands at the corner of the kiosk, facing the plaza
	local hx = if fp then fp.footprint.X / 2 else 4.3
	Kit.npcSpot(g, "npc_newsie", cf * CFrame.new(-hx - 1.8, 3, -half + 1))
	-- name board on the kiosk roof
	local board = Kit.detail(
		g,
		cf * CFrame.new(0, (if fp then fp.footprint.Y else 7.7) + 0.9, -half + 0.6),
		Vector3.new(6.4, 1.4, 0.2),
		Look.awningGreen,
		M.SmoothPlastic
	)
	Kit.sign(board, Text.get("newsstand_name"), { color = Look.gold, font = Enum.Font.Garamond, pixelsPerStud = 40 })
	return g
end

-- The store kiosk: a black lacquer pillar with a glowing touch screen (store_kiosk interact).
local function storeKiosk(m: Instance)
	local g = Kit.model(m, "StoreKiosk")
	local cf = at(Plan.storeKiosk.pos, Plan.storeKiosk.face)
	Kit.block(g, cf * CFrame.new(0, 0.25, 0), Vector3.new(5.2, 0.5, 3.4), Look.graniteDark, M.Granite)
	Kit.block(g, cf * CFrame.new(0, 4, 0), Vector3.new(4.2, 7, 2.2), Look.black, M.SmoothPlastic).Name = "Pillar"
	Kit.detail(g, cf * CFrame.new(0, 7.6, 0), Vector3.new(4.6, 0.4, 2.6), Look.gold, M.Metal)
	for _, sx in { -1, 1 } do
		Kit.detail(g, cf * CFrame.new(sx * 2.12, 4, -1.12), Vector3.new(0.12, 7, 0.12), Look.gold, M.Metal)
	end
	local header = Kit.detail(g, cf * CFrame.new(0, 6.7, -1.13), Vector3.new(3.8, 1, 0.06), Look.black, M.SmoothPlastic)
	Kit.sign(
		header,
		Text.get("store_kiosk_title"),
		{ color = Look.goldBright, font = Enum.Font.GothamBold, glow = true, pixelsPerStud = 60 }
	)
	local screen =
		Kit.detail(g, cf * CFrame.new(0, 4.1, -1.14), Vector3.new(3.4, 4, 0.06), Look.screen, M.SmoothPlastic)
	screen.Name = "Screen"
	Kit.interact(screen, "store_kiosk")
	local gui =
		Gui.Core.surface(screen, Enum.NormalId.Front, { glow = true, pps = 60, maxDistance = 80, name = "Kiosk" })
	Gui.Core.bg(gui, Look.navy)
	Gui.Core.gradient(Gui.Core.frame(gui, 0, 0, 1, 1, Look.white, 0), Look.navy, Look.screen, 90)
	Gui.Core.label(gui, Text.get("store_kiosk_title"), 0.08, 0.1, 0.84, 0.16, Look.goldBright, {
		font = Enum.Font.GothamBold,
		align = Enum.TextXAlignment.Center,
	})
	Gui.Core.label(gui, Text.get("store_kiosk_sub"), 0.08, 0.34, 0.84, 0.2, Look.white, {
		font = Enum.Font.GothamMedium,
		align = Enum.TextXAlignment.Center,
	})
	local btn = Gui.Core.frame(gui, 0.2, 0.66, 0.6, 0.16, Look.gold)
	Gui.Core.round(btn, 0.3)
	Gui.Core.label(btn, Text.get("directory_hint"), 0.05, 0.1, 0.9, 0.8, Look.navy, {
		font = Enum.Font.GothamBold,
		align = Enum.TextXAlignment.Center,
	})
	return g
end

local function directories(m: Instance)
	local g = Kit.model(m, "Directories")
	local entries: { string } = {}
	for _, t in World.towers do
		if #entries >= 7 then
			break
		end
		table.insert(entries, "> " .. t.label)
	end
	table.insert(entries, Text.get("directory_sub"))
	for i, d in Plan.directories do
		local sign = Signs.wayfinding(g, at(d.pos, d.face), {
			title = Text.get("directory_title"),
			entries = entries,
			seed = "directory" .. i,
		})
		sign.Name = "CompanyDirectory"
		local body = sign:FindFirstChild("Directory", true)
		if body and body:IsA("BasePart") then
			Kit.interact(body, "company_directory")
		else
			Kit.interactPoint(g, "company_directory", at(d.pos, d.face) * CFrame.new(0, 3, -1.5))
		end
	end
	return g
end

local function landmarks(m: Instance)
	local g = Kit.model(m, "Landmarks")
	Props.build("fountain", g, at(P.fountain, "N"), { seed = "plaza-fountain" })
	local statue = facing(P.statue, Vector3.new(0, 0, 1))
	Props.build("bull_bear_statue", g, statue, { seed = "the-contest" })
	-- a granite lectern with the statue's plaque, south of it on the axis
	local lect = statue * CFrame.new(0, 0, -7.5) * CFrame.Angles(0, math.pi, 0)
	Kit.block(g, lect * CFrame.new(0, 1.6, 0), Vector3.new(3.4, 3.2, 1.2), Look.graniteDark, M.Granite).Name = "Lectern"
	Signs.plaque(g, lect * CFrame.new(0, 1.0, -0.62), {
		title = Text.get("plaza_statue_title"),
		text = Text.get("plaza_statue_text"),
		width = 3,
		height = 1.9,
	})
	for i, f in P.flags do
		Props.build("flag_pole", g, at(f, "S"), { variant = ((i - 1) % 3) + 1, seed = "plaza-flag" .. i })
	end
	-- plaza lamps along the axis
	for _, z in { -60, 10, 70 } do
		for _, sx in { -1, 1 } do
			Props.build(
				"street_lamp_classic",
				g,
				at(Vector3.new(sx * 14, 0, z), "N"),
				{ seed = "plaza-lamp" .. z .. sx }
			)
		end
	end
	-- planters and benches
	-- (the plaza's south corners belong to the subway entrance and the coffee cart)
	for _, z in { -85, -45, 45 } do
		for _, sx in { -1, 1 } do
			Props.build("planter_tree", g, at(Vector3.new(sx * 98, 0, z), "N"), {
				variant = if z < -60 then "maple" else "topiary",
				seed = "plaza-planter" .. z .. sx,
			})
		end
	end
	for _, sx in { -1, 1 } do
		-- either side of the fountain, facing it
		Props.build("bench_classic", g, facing(Vector3.new(sx * 22, 0, P.fountain.Z), Vector3.new(-sx, 0, 0)), {
			seat = true,
			seed = "fountain-bench" .. sx,
		})
		-- facing the monoliths across the promenade
		for _, z in { -39, 13, 39 } do
			Props.build("bench_classic", g, facing(Vector3.new(sx * (P.boardX - 11), 0, z), Vector3.new(sx, 0, 0)), {
				seat = true,
				seed = "board-bench" .. z .. sx,
			})
		end
	end
	return g
end

local function events(m: Instance)
	local g = Kit.model(m, "EventSpots")
	Kit.anchor(g, "street_plaza", facing(P.anchor, Vector3.new(0, 0, -1)) * CFrame.new(0, 3, 0))
	-- the runway: a marble strip edged in gold
	local r = P.runway
	inlay(g, r.x0, r.x1, r.z - r.w / 2, r.z + r.w / 2, Look.marble, M.Marble, LAYER.runway).Name = "Runway"
	inlay(g, r.x0, r.x1, r.z - r.w / 2 - 0.5, r.z - r.w / 2, Look.gold, M.Metal, LAYER.runwayEdge)
	inlay(g, r.x0, r.x1, r.z + r.w / 2, r.z + r.w / 2 + 0.5, Look.gold, M.Metal, LAYER.runwayEdge)
	Kit.eventSpot(g, "runway", CFrame.new((r.x0 + r.x1) / 2, FLOOR + 0.5, r.z), Vector3.new(r.x1 - r.x0, 1, r.w))
	-- muster point: a green assembly sign on a post
	local mu = facing(P.muster, Vector3.new(0, 0, 1))
	Kit.cylinder(g, mu * CFrame.new(0, 4, 2), 8, 0.35, Look.steel, M.Metal)
	local sign =
		Kit.detail(g, mu * CFrame.new(0, 7.2, 1.8), Vector3.new(3.6, 2.6, 0.12), Look.awningGreen, M.SmoothPlastic)
	Kit.sign(sign, Text.get("plaza_muster") .. "\n" .. Text.get("plaza_muster_sub"), {
		color = Look.white,
		font = Enum.Font.GothamBold,
		pixelsPerStud = 50,
	})
	Kit.eventSpot(g, "muster_street", CFrame.new(P.muster.X, FLOOR + 0.5, P.muster.Z), Vector3.new(16, 1, 16))
	-- the pigeon square (and a few regulars already there)
	local pg = P.pigeons
	Kit.eventSpot(g, "pigeon_area", CFrame.new(pg.X, FLOOR + 0.5, pg.Z), Vector3.new(20, 1, 20))
	local rng = Deps.Rng.new("pigeons")
	for k = 1, 4 do
		local pos = Vector3.new(pg.X + rng:range(-6, 6), FLOOR, pg.Z + rng:range(-6, 6))
		local cf = CFrame.new(pos) * CFrame.Angles(0, rng:range(0, math.pi * 2), 0)
		local grey = Kit.shade(Look.slate, rng:range(-0.1, 0.25))
		Kit.ball(g, cf * CFrame.new(0, 0.45, 0), 0.8, grey, M.SmoothPlastic, { CanCollide = false }).Name = "Pigeon"
		Kit.ball(
			g,
			cf * CFrame.new(0, 0.95, -0.35),
			0.45,
			Kit.shade(grey, -0.2),
			M.SmoothPlastic,
			{ CanCollide = false }
		)
	end
	return g
end

function Plaza.build(parent: Instance): Model
	local m = Kit.model(parent, "ExchangePlaza")
	paving(m)
	landmarks(m)
	boards(m)
	subway(m)
	newsstand(m)
	storeKiosk(m)
	directories(m)
	events(m)
	return m
end

return Plaza
