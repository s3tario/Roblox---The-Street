--!strict
-- The Career Center interior (interior "career_center"): a tired 1970s student-services floor with vinyl tiles, a drop
-- ceiling and fluorescent troffers, built around the Life Roll kiosk on its dais in the lobby.
--
--   lobby (south):  the Life Roll kiosk (profile_builder), the Career Services counter (career_services) with
--                   npc_advisor behind it, the Recruiting Board (bulletin) on the west wall, a wardrobe-clinic mannequin
--   north half:     the computer lab (terminal x2), the study carrels (work_desk x4), the pizza lounge
--                   (EventSpot pizza_table_campus) and the glass-walled recruiting suite where Superdays happen
--                   (npc_recruiter in its waiting area)
--   markers:        anchor career_center_entry inside the doors, door door_career_center_exit on the south wall
--
-- build(parent, mk, origin) -> Model. Bake-safe.

local Deps = require(script.Parent.Deps)
local Shell = require(script.Parent.Shell)

local Kit = Deps.Kit
local Props = Deps.Props
local Signs = Deps.Signs
local Paint = Deps.Paint
local Text = Deps.Text
local Markers = Deps.Markers
local Core = Deps.Gui.Core
local Art = Deps.Gui.Art
local P = Deps.Palette
local C = P.campus
local hex = P.hex
local M = Enum.Material

local CareerCenter = {}

-- Room extents (inner faces) and heights
local X0, X1, Z0, Z1, H = -64, 64, -56, 40, 14
local WALL = hex("#DCD5C3")
local WAINSCOT = hex("#7E6A52")
local FLOOR = hex("#CFC8B6")

CareerCenter.ENTRY = { x = 0, z = 33 }

local RARITY_FALLBACK = {
	hex("#9AA0A6"),
	hex("#4CAF50"),
	hex("#3D7BD9"),
	hex("#9C4DD9"),
	hex("#E3B341"),
	hex("#FF6FD8"),
}

-- Tier colours from Config/Rarity (careerCore) when it is present, else the documented grey..prismatic set.
local function rarityColors(): { Color3 }
	local config = game:GetService("ReplicatedStorage").Shared:FindFirstChild("Config")
	local mod = if config then config:FindFirstChild("Rarity") else nil
	if mod and mod:IsA("ModuleScript") then
		local ok, R = pcall(require, mod)
		if ok and type(R) == "table" and type((R :: any).list) == "table" then
			local out: { Color3 } = {}
			for i, def in (R :: any).list do
				out[i] = if typeof(def.color) == "Color3" then def.color else RARITY_FALLBACK[i]
			end
			if #out == 6 then
				return out
			end
		end
	end
	return RARITY_FALLBACK
end

---------------------------------------------------------------------------------------------------
local function shell(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local floor = Shell.box(m, F, X0 - 1, -1, Z0 - 1, X1 + 1, 0, Z1 + 1, FLOOR, M.SmoothPlastic)
	floor.Name = "Floor"
	local fg, FW, FH = Paint.surface(floor, Enum.NormalId.Top, 2, { maxDistance = 0 })
	for x = 0, FW, 8 do
		Core.px(fg, x, 0, 1, FH, hex("#A9A292"), 0.5)
	end
	for y = 0, FH, 8 do
		Core.px(fg, 0, y, FW, 1, hex("#A9A292"), 0.5)
	end
	for _ = 1, 30 do
		Core.dot(fg, rng:range(0, FW), rng:range(0, FH), rng:range(4, 14), hex("#9A9282"), 0.6)
	end
	local ceil = Shell.box(m, F, X0 - 1, H, Z0 - 1, X1 + 1, H + 1, Z1 + 1, hex("#E6E2D6"), M.SmoothPlastic)
	ceil.Name = "DropCeiling"
	local cg, CW, CH = Paint.surface(ceil, Enum.NormalId.Bottom, 2, { maxDistance = 0 })
	for x = 0, CW, 8 do
		Core.px(cg, x, 0, 1, CH, hex("#B8B2A4"), 0.3)
	end
	for y = 0, CH, 8 do
		Core.px(cg, 0, y, CW, 1, hex("#B8B2A4"), 0.3)
	end
	-- a few water-stained tiles
	for _ = 1, 6 do
		Core.dot(cg, rng:range(0, CW), rng:range(0, CH), rng:range(10, 24), hex("#C9B98A"), 0.5)
	end
	Shell.wallX(m, F, Z0 - 0.5, X0 - 1, X1 + 1, 0, H, 1, WALL)
	Shell.wallX(m, F, Z1 + 0.5, X0 - 1, X1 + 1, 0, H, 1, WALL)
	Shell.wallZ(m, F, X0 - 0.5, Z0, Z1, 0, H, 1, WALL)
	Shell.wallZ(m, F, X1 + 0.5, Z0, Z1, 0, H, 1, WALL)
	-- wood wainscot and a chair rail all round
	Shell.box(m, F, X0, 0, Z0, X1, 3.6, Z0 + 0.15, WAINSCOT, M.Wood, false)
	Shell.box(m, F, X0, 0, Z1 - 0.15, X1, 3.6, Z1, WAINSCOT, M.Wood, false)
	Shell.box(m, F, X0, 0, Z0, X0 + 0.15, 3.6, Z1, WAINSCOT, M.Wood, false)
	Shell.box(m, F, X1 - 0.15, 0, Z0, X1, 3.6, Z1, WAINSCOT, M.Wood, false)
	-- troffers: a grid, four of them actually lighting the floor
	local lit = { ["-32,4"] = true, ["32,20"] = true, ["0,-28"] = true, ["-48,-44"] = true, ["48,-44"] = true }
	for x = -48, 48, 16 do
		for z = -44, 36, 16 do
			local key = x .. "," .. z
			local t = Shell.troffer(m, F.cf(x, H - 0.1, z), Vector3.new(2.4, 0.15, 4.4), lit[key] == true)
			if rng:chance(0.06) then
				t.Transparency = 0.7
				t:SetAttribute("Flicker", true)
			end
		end
	end
	-- windows onto the campus (faked views)
	local windows = {
		{ cf = F.cf(X1, 6.5, 22, Shell.W), w = 8 },
		{ cf = F.cf(X1, 6.5, -20, Shell.W), w = 8 },
		{ cf = F.cf(X1, 6.5, -45, Shell.W), w = 8 },
		{ cf = F.cf(-12, 6.5, Z0, Shell.S), w = 8 },
		{ cf = F.cf(12, 6.5, Z0, Shell.S), w = 8 },
		{ cf = F.cf(-22, 6.5, Z1, Shell.N), w = 8 },
		{ cf = F.cf(22, 6.5, Z1, Shell.N), w = 8 },
	}
	for _, wd in windows do
		Shell.window(m, wd.cf, wd.w, 5.5, rng, "campus")
	end
end

---------------------------------------------------------------------------------------------------
-- The Life Roll kiosk (profile_builder) on its dais
---------------------------------------------------------------------------------------------------
local function lifeRoll(m: Instance, F: Shell.Frame)
	local k = Kit.model(m, "LifeRollKiosk")
	local c = F.cf(0, 0, 12)
	local colors = rarityColors()
	Kit.cylinder(k, c * CFrame.new(0, 0.3, 0), 0.6, 15, hex("#2A2C30"), M.SmoothPlastic).Name = "Dais"
	Kit.cylinder(k, c * CFrame.new(0, 0.62, 0), 0.05, 12.6, hex("#3A3D42"), M.Metal).CanCollide = false
	-- six tier arcs round the edge, each in its rarity colour
	Kit.ring(k, c * CFrame.new(0, 0.66, 0), 6.9, 6, function(i, rcf)
		local arc = Kit.detail(k, rcf, Vector3.new(6.6, 0.12, 0.5), colors[i + 1], M.Neon)
		arc.Name = "TierArc" .. (i + 1)
		arc:AddTag("InteriorLight")
	end)
	-- the machine: a tall cabinet with a glowing screen facing the doors, a pull lever on its side
	local body = Kit.block(k, c * CFrame.new(0, 5.1, 0), Vector3.new(5, 9, 2.2), hex("#1F2A44"), M.Metal)
	body.Name = "Cabinet"
	Markers.interact(body, "profile_builder")
	Kit.detail(k, c * CFrame.new(0, 9.9, 0), Vector3.new(5.6, 0.6, 2.8), C.mustard, M.Metal).Name = "Crown"
	-- the screen faces south, toward the doors
	local screen = Kit.detail(
		k,
		c * CFrame.new(0, 5.6, 1.16) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(4.2, 5.4, 0.1),
		hex("#0E1A24"),
		M.SmoothPlastic
	)
	screen.Name = "LifeRollScreen"
	local g = Paint.surface(screen, Enum.NormalId.Front, 40, { glow = true, brightness = 1.3, maxDistance = 0 })
	local bg = Core.bg(g, hex("#13243A"))
	Core.gradient(bg, hex("#22385A"), hex("#0B1622"), 90)
	Core.label(g, Text.cc.lifeRoll, 0.05, 0.04, 0.9, 0.16, C.mustard, { font = Enum.Font.Bangers, align = Enum.TextXAlignment.Center })
	Core.label(g, Text.cc.lifeRollSub, 0.05, 0.2, 0.9, 0.08, hex("#E8EEF5"), {
		font = Enum.Font.SourceSansBold,
		align = Enum.TextXAlignment.Center,
	})
	for i, tier in Text.cc.lifeRollTiers do
		local y = 0.32 + (i - 1) * 0.105
		local bar = Core.frame(g, 0.1, y, 0.8, 0.085, colors[i], 0.15)
		Core.round(bar, 0.3)
		Core.label(bar, tier, 0.05, 0.05, 0.9, 0.9, hex("#0B1622"), { font = Enum.Font.GothamBold, align = Enum.TextXAlignment.Center })
	end
	Kit.light(screen, "point", { Color = hex("#9FC2FF"), Range = 18, Brightness = 1.1 })
	-- the lever
	Kit.cylinder(k, c * CFrame.new(2.9, 5, 0) * CFrame.Angles(0, 0, math.rad(90)), 0.8, 0.8, hex("#B8B8B0"), M.Metal)
	Kit.detail(k, c * CFrame.new(3.4, 6.4, 0), Vector3.new(0.25, 3, 0.25), hex("#B8B8B0"), M.Metal).Name = "Lever"
	Kit.ball(k, c * CFrame.new(3.4, 8, 0), 0.9, hex("#C83A2A"), M.SmoothPlastic).CanCollide = false
	-- the hanging banner above
	local ban = Kit.detail(k, F.cf(0, H - 2.2, 12, Shell.N), Vector3.new(14, 2.2, 0.2), hex("#1F2A44"), M.Fabric)
	ban.Name = "LifeRollBanner"
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local bg2 = Paint.surface(ban, face, 20)
		Core.bg(bg2, hex("#1F2A44"))
		Core.label(bg2, Text.cc.lifeRoll .. "  ·  " .. Text.cc.lifeRollSub, 0.03, 0.1, 0.94, 0.8, C.mustard, {
			font = Enum.Font.Oswald,
			align = Enum.TextXAlignment.Center,
		})
	end
	for _, x in { -6.5, 6.5 } do
		Kit.detail(k, F.cf(x, H - 0.55, 12), Vector3.new(0.1, 1.1, 0.1), hex("#5A5A5A"), M.Metal)
	end
end

---------------------------------------------------------------------------------------------------
-- Career Services counter (career_services) and the advisor's corner
---------------------------------------------------------------------------------------------------
local function services(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local s = Kit.model(m, "CareerServicesDesk")
	local counter = Shell.box(s, F, 34, 0, 6, 36.6, 3.8, 30, hex("#6B4E35"), M.Wood)
	counter.Name = "ServicesCounter"
	Markers.interact(counter, "career_services")
	Shell.box(s, F, 33.6, 3.8, 5.6, 37, 4.1, 30.4, hex("#D8D2C2"), M.Marble).Name = "CounterTop"
	local face = Shell.box(s, F, 33.9, 0.6, 9, 33.95, 3.2, 27, hex("#1F2A44"), M.SmoothPlastic, false)
	local fg = Paint.surface(face, Enum.NormalId.Left, 20)
	Core.bg(fg, hex("#1F2A44"))
	Core.label(fg, Text.cc.services, 0.03, 0.15, 0.94, 0.7, C.mustard, { font = Enum.Font.Oswald, align = Enum.TextXAlignment.Center })
	Shell.sign(s, F.cf(X1, 10.8, 18, Shell.W), 18, 2.2, Text.cc.services .. "\n" .. Text.cc.servicesSub, {
		color = hex("#1F2A44"),
		ink = C.mustard,
	})
	-- the advisor's desk, monitor, filing cabinets and a pile of resumes
	Shell.box(s, F, 46, 0, 12, 50, 3.1, 22, hex("#8E7A5A"), M.Wood).Name = "AdvisorDesk"
	Props.build("monitor_single", s, F.cf(48.6, 3.1, 17, Shell.W), { seed = "advisor-monitor", lit = true })
	Props.build("keyboard_mouse", s, F.cf(47.2, 3.1, 17, Shell.W), { seed = "advisor-kb" })
	Shell.chair(s, F.cf(44, 0, 17, Shell.E), hex("#2A2A2A"))
	for i, z in { 4, 6.4 } do
		Props.build("filing_cabinet", s, F.cf(62.6, 0, z, Shell.W), { seed = "cc-file" .. i })
	end
	for i = 0, 4 do
		Shell.box(s, F, 34.6 + rng:range(-0.1, 0.1), 4.1 + i * 0.12, 24 + rng:range(-0.2, 0.2), 36, 4.2 + i * 0.12, 25.6, C.paper, M.SmoothPlastic, false).Name =
			"Resumes"
	end
	Props.build("plant_floor", s, F.cf(38, 0, 33, 0), { seed = "cc-plant1" })
	-- a queue of plastic chairs facing the counter
	for i = 0, 3 do
		local ch = F.cf(26, 0, 9 + i * 3.2, Shell.E)
		Kit.block(s, ch * CFrame.new(0, 1.7, 0), Vector3.new(2, 0.25, 2), hex("#C9A13B"), M.Plastic).Name = "Chair"
		Kit.detail(s, ch * CFrame.new(0, 2.9, 0.9), Vector3.new(2, 2, 0.2), hex("#C9A13B"), M.Plastic)
	end
end

---------------------------------------------------------------------------------------------------
-- The Recruiting Board (bulletin) and the lobby furniture
---------------------------------------------------------------------------------------------------
local function lobby(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local l = Kit.model(m, "Lobby")
	local board = Kit.block(l, F.cf(X0 + 0.35, 6.4, 18, Shell.E), Vector3.new(18, 6.8, 0.5), hex("#9A7650"), M.Wood)
	board.Name = "RecruitingBoard"
	Markers.interact(board, "bulletin")
	local bg = Paint.surface(board, Enum.NormalId.Front, 20)
	Core.bg(bg, hex("#A07C55"))
	local pins = Kit.detail(l, F.cf(X0 + 0.62, 5.9, 18, Shell.E), Vector3.new(17, 5.2, 0.02), Color3.new(1, 1, 1), M.SmoothPlastic)
	pins.Transparency = 1
	local pg, PW, PH = Paint.surface(pins, Enum.NormalId.Front, 20)
	local postings = table.clone(Text.recruitingPins)
	for _, t in Text.flyers do
		if string.find(t, "RECRUIT") or string.find(t, "SUPERDAY") or string.find(t, "MOCK") then
			table.insert(postings, t)
		end
	end
	Paint.flyers(pg, PW, PH, Deps.Rng.new("cc-board"), postings)
	Shell.sign(l, F.cf(X0, 10.6, 18, Shell.E), 18, 1.6, Text.cc.board, { color = hex("#1F2A44"), ink = C.mustard })
	-- lounge chairs facing the board, a coffee table with brochures
	for i, z in { 13, 18, 23 } do
		Props.build("armchair", l, F.cf(X0 + 9, 0, z, Shell.W), { color = hex("#5C6168"), seed = "cc-arm" .. i })
	end
	Props.build("coffee_table", l, F.cf(X0 + 5, 0, 18, Shell.W), { seed = "cc-table" })
	-- the wardrobe clinic mannequin by the doors
	local mq = Deps.NpcRig.build({ preset = "mannequin", humanoid = false, face = false, cframe = F.cf(-40, 0.4, 34, Shell.N) })
	mq.Name = "Mannequin"
	mq.Parent = l
	Kit.cylinder(l, F.cf(-40, 0.2, 34), 0.4, 3.4, hex("#2A2A2A"), M.Metal).Name = "MannequinBase"
	local tip = Text.posters[3]
	Signs.poster(l, F.cf(-34, 4, Z1 - 0.02, Shell.N), {
		title = tip.title,
		body = tip.body,
		colors = { hex("#1F2A44"), C.mustard, hex("#F4F1E6") },
		width = 3.6,
		height = 4.8,
		frame = true,
		seed = "cc-wardrobe-poster",
	})
	-- welcome sign over the doors, a clock, plants, the water cooler
	Shell.sign(l, F.cf(0, 11.4, Z1, Shell.N), 26, 1.8, Text.cc.welcome, { color = hex("#24262A"), ink = hex("#F4F1E6") })
	Props.build("wall_clock", l, F.cf(14, 9, Z1, Shell.N), { seed = "cc-clock" })
	Props.build("plant_floor", l, F.cf(-8, 0, 37.6, 0), { seed = "cc-plant2" })
	Props.build("water_cooler", l, F.cf(-62.6, 0, 33, Shell.E), { seed = "cc-cooler" })
	Props.build("trash_can", l, F.cf(8, 0, 37.8, 0), { seed = "cc-bin1" })
	-- interview tips posted around the lobby
	local tipX = { -60, -55, -50, 30, 36 }
	for i, tip2 in Text.cc.tips do
		local x = tipX[((i - 1) % #tipX) + 1]
		local p = Kit.detail(
			l,
			F.cf(x, 6.5, Z1 - 0.04, Shell.N) * CFrame.Angles(0, 0, math.rad(rng:range(-3, 3))),
			Vector3.new(3, 2.2, 0.05),
			hex("#E9E2CF"),
			M.SmoothPlastic
		)
		p.Name = "Tip"
		Kit.sign(p, tip2, { font = Enum.Font.PatrickHand, color = C.ink, pixelsPerStud = 40 })
	end
	-- entry mats
	Shell.box(l, F, -5, 0, 34, 5, 0.06, 39.4, hex("#3A3A38"), M.Fabric, false).Name = "DoorMat"
end

---------------------------------------------------------------------------------------------------
-- Study carrels (work_desk x4) and the computer lab (terminal x2)
---------------------------------------------------------------------------------------------------
local function carrels(m: Instance, F: Shell.Frame)
	local c = Kit.model(m, "StudyCarrels")
	local divider = hex("#8E8A80")
	for i = 0, 4 do
		local z = -32 + i * 7
		Shell.box(c, F, X0, 0, z - 0.15, X0 + 6, 5.2, z + 0.15, divider, M.Fabric).Name = "Divider"
	end
	for i = 0, 3 do
		local z = -28.5 + i * 7
		local desk = Shell.box(c, F, X0, 2.8, z - 3.1, X0 + 2.6, 3.1, z + 3.1, hex("#B8956A"), M.Wood)
		desk.Name = "CarrelDesk"
		Markers.interact(desk, "work_desk")
		Shell.box(c, F, X0, 0, z - 3, X0 + 0.4, 2.8, z + 3, hex("#6B5A40"), M.Wood).Name = "Modesty"
		Props.build("desk_lamp", c, F.cf(X0 + 0.9, 3.1, z + 2, Shell.E), { seed = "carrel-lamp" .. i, lit = i % 2 == 0 })
		Props.build("book_stack", c, F.cf(X0 + 1, 3.1, z - 1.8, Shell.E), { seed = "carrel-books" .. i })
		Shell.chair(c, F.cf(X0 + 4, 0, z, Shell.W), hex("#5C2A21"))
	end
	Shell.sign(c, F.cf(X0, 9, -18, Shell.E), 14, 1.6, Text.cc.carrels, { color = hex("#2F3A32"), ink = hex("#ECE6DA") })
end

local function lab(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local l = Kit.model(m, "ComputerLab")
	Shell.box(l, F, X0, 0, -38.15, -22, 4.2, -37.85, hex("#8E8A80"), M.Fabric).Name = "LabDivider"
	for i, x in { -57, -47, -37, -27 } do
		local desk = Shell.box(l, F, x - 3.6, 2.8, Z0, x + 3.6, 3.1, Z0 + 3, hex("#C9C2B0"), M.SmoothPlastic)
		desk.Name = "LabDesk"
		Shell.box(l, F, x - 3.4, 0, Z0, x - 3, 2.8, Z0 + 2.8, hex("#5A5F63"), M.Metal)
		Shell.box(l, F, x + 3, 0, Z0, x + 3.4, 2.8, Z0 + 2.8, hex("#5A5F63"), M.Metal)
		local working = i == 2 or i == 3
		local mon = Shell.box(l, F, x - 1.6, 3.4, Z0 + 0.6, x + 1.6, 5.6, Z0 + 0.9, hex("#1A1A1A"), M.SmoothPlastic)
		mon.Name = if working then "TerminalScreen" else "DeadMonitor"
		Shell.box(l, F, x - 0.3, 3.1, Z0 + 0.7, x + 0.3, 3.4, Z0 + 1.2, hex("#2A2A2A"), M.Metal, false)
		Shell.box(l, F, x + 2.2, 3.1, Z0 + 0.4, x + 3.2, 5.4, Z0 + 2.4, hex("#D8D2C2"), M.SmoothPlastic, false).Name = "Tower"
		local sg = Paint.surface(mon, Enum.NormalId.Back, 50, { glow = working, brightness = 1.1 })
		if working then
			Markers.interact(mon, "terminal")
			local bgs = Core.bg(sg, hex("#0B1622"))
			Core.lineChart(bgs, 8, 20, 140, 60, Core.series(rng, 30, 100, 2, 0.1), Core.UP, 2)
			Core.label(bgs, "EASTBRIDGE STATE · MARKET TERMINAL", 0.04, 0.02, 0.92, 0.14, Core.AMBER, { font = Enum.Font.Code })
		else
			Core.bg(sg, hex("#121212"))
			local note = Kit.detail(l, F.cf(x, 4.4, Z0 + 0.95, Shell.S), Vector3.new(1.6, 1, 0.02), C.paper, M.SmoothPlastic)
			Kit.sign(note, "OUT OF\nORDER", { font = Enum.Font.PermanentMarker, color = hex("#8A2C2C"), pixelsPerStud = 60 })
		end
		Props.build("keyboard_mouse", l, F.cf(x, 3.1, Z0 + 2.2, Shell.S), { seed = "lab-kb" .. i })
		Shell.chair(l, F.cf(x, 0, Z0 + 5, Shell.N), hex("#2A2A2A"))
	end
	Shell.sign(l, F.cf(-42, 10.4, Z0, Shell.S), 16, 2, Text.cc.lab .. "\n" .. Text.cc.labSub, {
		color = hex("#1F2A44"),
		ink = hex("#F4F1E6"),
	})
	Props.build("printer", l, F.cf(-62.6, 0, -50, Shell.E), { seed = "lab-printer" })
end

---------------------------------------------------------------------------------------------------
-- Pizza lounge (pizza_table_campus) and the recruiting suite
---------------------------------------------------------------------------------------------------
local function pizza(m: Instance, F: Shell.Frame, mk: Instance)
	local p = Kit.model(m, "PizzaLounge")
	local top = Shell.box(p, F, -9, 2.8, -26, 9, 3.2, -22, hex("#D8CDB4"), M.SmoothPlastic)
	top.Name = "LongTable"
	for _, x in { -8, 8 } do
		for _, z in { -25.5, -22.5 } do
			Shell.box(p, F, x - 0.2, 0, z - 0.2, x + 0.2, 2.8, z + 0.2, hex("#5A5F63"), M.Metal, false)
		end
	end
	for _, z in { -28.4, -19.6 } do
		Shell.box(p, F, -8.5, 1.6, z - 0.7, 8.5, 1.9, z + 0.7, hex("#2C5E8A"), M.Plastic).Name = "Bench"
		Shell.box(p, F, -0.2, 0, z - 0.2, 0.2, 1.6, z + 0.2, hex("#5A5F63"), M.Metal, false)
	end
	Markers.event(mk, "pizza_table_campus", F.cf(0, 3.2 + 0.2, -24), Vector3.new(8, 0.4, 3))
	Props.build("pizza_box", p, F.cf(6, 3.2, -24, 12), { count = 1, seed = "cc-pizza" })
	local ban = Kit.detail(p, F.cf(0, 11, Z0 + 0.12, Shell.S), Vector3.new(14, 2.4, 0.1), hex("#C8553D"), M.Fabric)
	local bg = Paint.surface(ban, Enum.NormalId.Front, 20)
	Core.bg(bg, hex("#C8553D"))
	Core.label(bg, Text.cc.pizza, 0.03, 0.1, 0.94, 0.8, hex("#F4F1E6"), { font = Enum.Font.Bangers, align = Enum.TextXAlignment.Center })
	Props.build("vending_machine", p, F.cf(20, 0, Z0 + 1.6, Shell.S), { seed = "cc-vend" })
	Props.build("trash_can", p, F.cf(23.5, 0, Z0 + 1.4, 0), { seed = "cc-bin2" })
end

local function suite(m: Instance, F: Shell.Frame, rng: Deps.RngT)
	local s = Kit.model(m, "RecruitingSuite")
	local glass = hex("#9FB3BC")
	local frameC = hex("#3A3D40")
	local function glassWall(parts: { Part })
		for _, p in parts do
			p.Transparency = 0.6
			p.Reflectance = 0.1
			p.Material = M.Glass
			p.CastShadow = false
		end
	end
	-- two interview rooms: glass fronts with doorways, a glass wall between them and on the west side
	glassWall(Shell.wallX(s, F, -34, 26, X1, 0, 10, 0.3, glass, M.Glass, {
		{ c = 35, w = 6, h = 9.2 },
		{ c = 55, w = 6, h = 9.2 },
	}))
	glassWall(Shell.wallZ(s, F, 45, Z0, -34, 0, 10, 0.3, glass, M.Glass))
	glassWall(Shell.wallZ(s, F, 26, Z0, -34, 0, 10, 0.3, glass, M.Glass))
	-- a solid band over the glass up to the ceiling, and mullions
	Shell.box(s, F, 26, 10, -34.4, X1, H, -33.6, WALL, M.SmoothPlastic).Name = "Bulkhead"
	Shell.box(s, F, 25.6, 10, Z0, 26.4, H, -34, WALL, M.SmoothPlastic).Name = "Bulkhead"
	for _, x in { 26, 31.5, 38.5, 45, 51.5, 58.5 } do
		Shell.box(s, F, x - 0.15, 0, -34.25, x + 0.15, 10, -33.75, frameC, M.Metal, false)
	end
	for i, rx in { 35, 55 } do
		-- the interview table, chairs on both sides, a whiteboard with someone's DCF
		Shell.box(s, F, rx - 4, 2.8, -48, rx + 4, 3.1, -44, hex("#5A3A26"), M.Wood).Name = "InterviewTable"
		Shell.box(s, F, rx - 0.4, 0, -46.4, rx + 0.4, 2.8, -45.6, hex("#2A2A2A"), M.Metal, false)
		Props.build("chair_exec", s, F.cf(rx, 0, -50, Shell.S), { seed = "suite-exec" .. i })
		for _, dx in { -2.4, 2.4 } do
			Shell.chair(s, F.cf(rx + dx, 0, -42, Shell.N), hex("#3C4A5E"))
		end
		local wb = Kit.detail(s, F.cf(rx, 6.2, Z0 + 0.1, Shell.S), Vector3.new(8, 4.4, 0.1), hex("#F4F4F0"), M.SmoothPlastic)
		wb.Name = "Whiteboard"
		local wg, WW, WH = Paint.surface(wb, Enum.NormalId.Front, 20)
		Art.whiteboard(wg, WW, WH, rng)
		Props.build("plant_desk", s, F.cf(rx + 3, 3.1, -45, 0), { seed = "suite-plant" .. i })
	end
	-- the waiting area outside: chairs, a coat rack, the Superday schedule
	for i = 0, 3 do
		Shell.chair(s, F.cf(30 + i * 3.2, 0, -30, Shell.S), hex("#C9A13B"))
	end
	Shell.box(s, F, 49.8, 0, -29.2, 50.2, 6.4, -28.8, hex("#2A2A2A"), M.Metal).Name = "CoatRack"
	local sched = Kit.detail(s, F.cf(48, 6.2, -33.5, 180), Vector3.new(6, 5, 0.1), hex("#F4F1E6"), M.SmoothPlastic)
	sched.Name = "SuperdaySchedule"
	Kit.sign(sched, Text.cc.superday, { font = Enum.Font.SpecialElite, color = C.ink, pixelsPerStud = 30, padding = 0.06 })
	Shell.sign(s, F.cf(45, 12, -33.55, 180), 30, 1.8, Text.cc.suite .. " · " .. Text.cc.suiteSub, {
		color = hex("#1F2A44"),
		ink = C.mustard,
	})
end

---------------------------------------------------------------------------------------------------
function CareerCenter.build(parent: Instance, mk: Instance, origin: Vector3): Model
	local m = Kit.model(parent, "career_center")
	m:SetAttribute("Interior", "career_center")
	m:SetAttribute("LightingPreset", "campus_interior")
	local F = Shell.frame(origin)
	local rng = Deps.Rng.new("career-center-interior")
	shell(m, F, rng)
	lifeRoll(m, F)
	services(m, F, rng)
	lobby(m, F, rng)
	carrels(m, F)
	lab(m, F, rng)
	pizza(m, F, mk)
	suite(m, F, rng)
	Markers.anchor(mk, "career_center_entry", F.cf(CareerCenter.ENTRY.x, 3, CareerCenter.ENTRY.z, Shell.N))
	Shell.exit(m, mk, "door_career_center_exit", F.cf(0, 0, Z1, Shell.N), { label = Text.exitTo.career_center, glass = true })
	Markers.npc(mk, "npc_advisor", F.cf(40.5, 3, 18, Shell.W))
	Markers.npc(mk, "npc_recruiter", F.cf(40, 3, -24, Shell.S))
	return m
end

return CareerCenter
