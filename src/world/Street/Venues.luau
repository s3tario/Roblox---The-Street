--!strict
-- The Street's venue facades (their interiors are separate builders): Career Services on the plaza's west side,
-- the Galleria (a luxury arcade with display windows dressed on mannequins in premium Catalog pieces) on its east
-- side, The Executive Club, The Ashford Residences (with the doorman's spot under the canopy) and the Skyline
-- Rooftop tower. Each has its door trigger (door_street_<id>) where the doors are, a sign above it and its front
-- anchor (street_<id>_front) on the pavement. Bake-safe.
--
--   Venues.build(parent, rects) -> Model

local Deps = require(script.Parent.Deps)
local Look = require(script.Parent.Look)
local Mass = require(script.Parent.Mass)
local Plan = require(script.Parent.Plan)
local Text = require(script.Parent.Text)
local Brand = require(script.Parent.Brand)
local C = require(script.Parent.Towers.Common)

local Kit = Deps.Kit
local Props = Deps.Props
local Rng = Deps.Rng
local M = Enum.Material

local Venues = {}

local function ctxFor(
	parent: Instance,
	id: string,
	label: string,
	rects: { Plan.Rect },
	door: string,
	anchor: string
): C.Ctx
	local lot = Plan.venueLots[id]
	local m = Kit.model(parent, "Venue_" .. id)
	m:SetAttribute("VenueId", id)
	m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	return {
		m = m,
		frame = Plan.lotFrame(lot),
		lot = lot,
		def = { id = id, label = label, style = "venue", door = door, anchor = anchor },
		rects = rects,
		rid = "venue:" .. id,
		seed = "venue:" .. id,
		rng = Rng.new("venue:" .. id),
		w = lot.w,
		d = lot.d,
		h = lot.h,
		variant = 1,
	}
end

local function plate(ctx: C.Ctx, cf: CFrame, w: number, h: number, text: string, bg: Color3, ink: Color3)
	local p =
		Kit.detail(ctx.m, ctx.frame * cf * CFrame.new(0, h / 2, -0.08), Vector3.new(w, h, 0.16), bg, M.SmoothPlastic)
	Kit.sign(p, text, { color = ink, font = Enum.Font.GothamMedium, pixelsPerStud = 50, glow = true })
	return p
end

---------------------------------------------------------------------------------------------------
-- Career Services: a civic glass-and-limestone building facing the plaza
---------------------------------------------------------------------------------------------------
local function careerServices(parent: Instance, rects: { Plan.Rect })
	local ctx = ctxFor(
		parent,
		"career_services",
		Text.get("career_services_name"),
		rects,
		"door_street_career_services",
		"street_career_services_front"
	)
	local e = C.entrance(ctx, {
		mode = "arcade",
		bh = 18,
		stone = Look.limestone,
		stoneMat = M.Limestone,
		trim = Look.gold,
		recess = 8,
		lobbyDepth = 20,
		endPier = 8,
		columns = 6,
		revolving = 2,
		lobbyWall = Look.navy,
	})
	local b = C.stack(ctx, e.top, {
		{ top = ctx.h * 0.92, look = "glassBrass", ledge = Look.limestone, ledgeMat = M.Limestone, trim = Look.gold },
	})
	Mass.cornice(ctx.m, ctx.frame, b, b.y1 - 0.4, 2.4, 1.4, Look.limestone, M.Limestone)
	-- limestone frame around the glass front
	for _, sx in { -1, 1 } do
		Mass.slab(
			ctx.m,
			ctx.frame,
			C.box(sx * ctx.w / 2 - 3, sx * ctx.w / 2 + 3, -1.2, 2, e.top, b.y1),
			Look.limestone,
			M.Limestone,
			false
		)
	end
	Mass.roofKit(ctx.m, ctx.frame, b, ctx.seed .. ":roof", Look.limestoneDark)
	Brand.title(
		ctx.m,
		ctx.frame * e.fascia * CFrame.new(0, 0, -0.05),
		Text.get("career_services_name"),
		e.fasciaWidth * 0.7,
		{
			height = math.min(4, e.fasciaHeight - 1.2),
			lit = true,
		}
	)
	for _, sx in { -1, 1 } do
		plate(
			ctx,
			CFrame.new(sx * (ctx.w / 2 - 4), 7, 0),
			6.4,
			1.6,
			Text.get("career_services_sub"),
			Look.navy,
			Look.gold
		)
	end
end

---------------------------------------------------------------------------------------------------
-- The Galleria: a luxury arcade with an arched glass entrance and four dressed display windows
---------------------------------------------------------------------------------------------------
local LOOKS: { { [string]: string } } = {
	{
		outer = "bespoke_midnight_2b",
		top = "shirt_bespoke",
		bottom = "bespoke_midnight_trousers",
		shoes = "oxford_bespoke_black",
		neck = "tie_bar_gold",
		wrist = "watch_astra_moonphase",
	},
	{
		outer = "bespoke_vicuna_3p",
		top = "shirt_bespoke",
		bottom = "bespoke_flannel_trousers",
		shoes = "wholecut_bespoke",
		neck = "scarf_vicuna",
	},
	{
		top = "blouse_couture",
		bottom = "trousers_couture_wide",
		shoes = "heels_couture",
		eyes = "aviators_gold",
		wrist = "watch_astra_moonphase",
	},
	{
		top = "qzip_vicuna",
		bottom = "bespoke_chalk_trousers",
		shoes = "wholecut_bespoke",
		wrist = "watch_vanta_gold",
		bag = "attache_calf",
	},
}

local MANNEQUIN = Look.hex("#ECEBE6")

-- Only pieces the Catalog knows (it may change); an unknown id would make Wardrobe.apply complain.
local function known(equipped: { [string]: string }): { [string]: string }
	local Catalog = Deps.Catalog
	if Catalog == nil or type(Catalog.get) ~= "function" then
		return {}
	end
	local out: { [string]: string } = {}
	for slot, id in equipped do
		local ok, item = pcall(Catalog.get, id)
		if ok and item ~= nil then
			out[slot] = id
		end
	end
	return out
end

local function mannequin(parent: Instance, cf: CFrame, equipped: { [string]: string }, name: string)
	local NpcRig = Deps.NpcRig
	if NpcRig and type(NpcRig.build) == "function" then
		local ok, model = pcall(NpcRig.build, {
			name = name,
			equipped = known(equipped),
			humanoid = false,
			face = false,
			hairStyle = "none",
			skin = MANNEQUIN,
			pose = "stand",
			cframe = cf,
			anchored = true,
			seed = name,
		})
		if ok and typeof(model) == "Instance" then
			model.Parent = parent
			model:SetAttribute("Mannequin", true)
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
				elseif d:IsA("Humanoid") then
					d:Destroy()
				end
			end
			return
		end
		warn("[Street] mannequin rig failed: " .. tostring(model))
	end
	-- fallback dress form
	local g = Kit.model(parent, name)
	Kit.cylinder(g, cf * CFrame.new(0, 1.6, 0), 3.2, 0.3, Look.brass, M.Metal, { CanCollide = false })
	Kit.detail(g, cf * CFrame.new(0, 4.2, 0), Vector3.new(2, 2.4, 1.1), Look.navy, M.Fabric)
	Kit.ball(g, cf * CFrame.new(0, 5.9, 0), 1, MANNEQUIN, M.SmoothPlastic, { CanCollide = false })
end

local function galleria(parent: Instance, rects: { Plan.Rect })
	local ctx =
		ctxFor(parent, "galleria", Text.get("galleria_name"), rects, "door_street_galleria", "street_galleria_front")
	local f = ctx.frame
	local w, d, h = ctx.w, ctx.d, ctx.h
	local gh = 20 -- ground storey
	local ew = 12 -- entrance half-width
	local archTop = 42
	local stone = Look.limestoneWarm
	local trim = Look.gold
	-- display bays: { x0, x1, shop text key, look index or "decor" }
	local bays: { { x0: number, x1: number, shop: string, look: number } } = {
		{ x0 = -60, x1 = -39.5, shop = "galleria_shop_tailor", look = 1 },
		{ x0 = -36.5, x1 = -15, shop = "galleria_shop_tailor", look = 2 },
		{ x0 = 15, x1 = 36.5, shop = "galleria_shop_watch", look = 3 },
		{ x0 = 39.5, x1 = 60, shop = "galleria_shop_shoes", look = 4 },
	}
	-- ground storey: piers between the bays, the display back wall and the deep lobby behind the arch
	local piers = { { -w / 2, -60 }, { -39.5, -36.5 }, { -15, -ew }, { ew, 15 }, { 36.5, 39.5 }, { 60, w / 2 } }
	for _, p in piers do
		Mass.slab(ctx.m, f, C.box(p[1], p[2], 0, 4, 0, gh), stone, M.Limestone).Name = "Pier"
		Mass.slab(ctx.m, f, C.box(p[1] - 0.2, p[2] + 0.2, -0.3, 4, 0, 1.6), Look.blackGranite, M.Granite, false)
	end
	Mass.slab(ctx.m, f, C.box(-w / 2, -ew, 4, d, 0, gh), stone, M.Limestone).Name = "Base"
	Mass.slab(ctx.m, f, C.box(ew, w / 2, 4, d, 0, gh), stone, M.Limestone).Name = "Base"
	Mass.slab(ctx.m, f, C.box(-ew, ew, 16, d, 0, archTop), stone, M.Limestone).Name = "LobbyBack"
	-- upper storeys either side of the arch and over it
	local upper = Mass.look("limestoneWarm", { bay = 10, storey = 13, lit = 0.12 })
	for _, sx in { -1, 1 } do
		local x0, x1 = if sx < 0 then -w / 2 else ew, if sx < 0 then -ew else w / 2
		local b = C.box(x0, x1, 0, d, gh, h - 4)
		local hid = C.hidden(ctx, b)
		if sx < 0 then
			hid.right = math.huge
		else
			hid.left = math.huge
		end
		Mass.tier(ctx.m, f, b, upper, { hidden = hid, seed = ctx.seed .. sx, name = "Upper", noTop = true })
	end
	Mass.slab(ctx.m, f, C.box(-ew, ew, 0, d, archTop, h - 4), stone, M.Limestone).Name = "OverArch"
	Mass.slab(ctx.m, f, C.box(-w / 2, w / 2, 0, d, h - 4, h), Look.limestone, M.Limestone).Name = "Attic"
	Mass.cornice(ctx.m, f, C.box(-w / 2, w / 2, 0, d, gh, h), h - 4.4, 1.6, 1.6, Look.limestone, M.Limestone)
	Mass.slab(
		ctx.m,
		f,
		C.box(-w / 2 - 0.6, w / 2 + 0.6, -0.9, d, gh - 0.4, gh + 1.2),
		Look.limestone,
		M.Limestone,
		false
	)
	-- the arched glass entrance: a tall glazed bay closed by a half-round fanlight, brass ribs
	local glassC = Look.lobbyGlass
	local gx = ew - 1
	-- glazing above the revolving drums, and the narrow panes between and beside them
	local doorTop = 9.8
	local function pane(x0: number, x1: number, y0: number, y1: number)
		Kit.block(
			ctx.m,
			f * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0.6),
			Vector3.new(x1 - x0, y1 - y0, 0.4),
			glassC,
			M.Glass,
			{
				Transparency = 0.55,
				Reflectance = 0.2,
				CastShadow = false,
			}
		).Name =
			"ArchGlass"
	end
	pane(-gx, gx, doorTop, archTop - gx)
	pane(-gx, -10, 0, doorTop)
	pane(-1, 1, 0, doorTop)
	pane(10, gx, 0, doorTop)
	local fan = Kit.cylinder(
		ctx.m,
		f * CFrame.new(0, archTop - gx, 0.6) * CFrame.Angles(math.pi / 2, 0, 0),
		0.4,
		2 * gx,
		glassC,
		M.Glass,
		{
			Transparency = 0.55,
			Reflectance = 0.2,
			CastShadow = false,
		}
	)
	fan.Name = "Fanlight"
	for k = -2, 2 do
		local a = math.rad(k * 30)
		Kit.detail(
			ctx.m,
			f * CFrame.new(0, archTop - gx, 0.3) * CFrame.Angles(0, 0, a) * CFrame.new(0, gx / 2, 0),
			Vector3.new(0.4, gx, 0.3),
			trim,
			M.Metal
		)
	end
	for _, x in { -gx, gx } do
		Kit.detail(
			ctx.m,
			f * CFrame.new(x, (archTop - gx) / 2, 0.3),
			Vector3.new(0.6, archTop - gx, 0.4),
			trim,
			M.Metal
		)
	end
	Kit.detail(ctx.m, f * CFrame.new(0, 11.4, 0.3), Vector3.new(2 * gx, 0.4, 0.4), trim, M.Metal)
	-- the lobby seen through the arch: marble floor, a glowing chandelier, the arcade's far wall
	Mass.slab(ctx.m, f, C.box(-ew, ew, 0.8, 16, 0, 0.08), Look.marble, M.Marble, false)
	local chand = Kit.ball(
		ctx.m,
		f * CFrame.new(0, archTop - gx - 3, 8),
		3.4,
		Look.lampGlow,
		M.Neon,
		{ CanCollide = false, CastShadow = false }
	)
	chand.Transparency = 0.2
	chand:AddTag("InteriorLight")
	Kit.light(chand, "point", { Color = Look.lampGlow, Range = 30, Brightness = 1.3 })
	Mass.slab(ctx.m, f, C.box(-ew + 1, ew - 1, 15.6, 16, 0, archTop - 2), Look.marbleVein, M.Marble, false)
	-- revolving doors in the arch and the trigger in front of them
	for i, x in { -5.5, 5.5 } do
		Props.build("revolving_door", ctx.m, f * CFrame.new(x, 0, 0.6), { seed = "galleria-rev" .. i, accent = trim })
		Kit.block(ctx.m, f * CFrame.new(x, 4.75, 0.6), Vector3.new(7.4, 9.5, 7.4), Look.white, M.Glass, {
			Transparency = 1,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}).Name =
			"DoorBlocker"
	end
	local door = Kit.door(ctx.m, "door_street_galleria", f * CFrame.new(0, 5.2, -5.2), Vector3.new(21, 10, 2.4))
	door.Name = "door_street_galleria"
	Kit.anchor(ctx.m, "street_galleria_front", f * CFrame.new(0, 3, -12))
	-- the name over the arch, a clock above it
	Brand.title(
		ctx.m,
		f * CFrame.new(0, archTop + 1.2, -0.05),
		Text.get("galleria_name"),
		2 * ew + 18,
		{ height = 3.6, lit = true }
	)
	plate(ctx, CFrame.new(0, archTop + 7.6, 0), 2 * ew + 10, 1.4, Text.get("galleria_sub"), Look.black, Look.gold)
	local clockY = archTop + 15
	Kit.detail(ctx.m, f * CFrame.new(0, clockY, -0.1), Vector3.new(8, 8, 0.2), trim, M.Metal).Name = "ClockSurround"
	Kit.cylinder(
		ctx.m,
		f * CFrame.new(0, clockY, -0.45) * CFrame.Angles(math.pi / 2, 0, 0),
		0.5,
		7,
		Look.black,
		M.Metal,
		{
			CanCollide = false,
		}
	).Name =
		"ClockRim"
	local dial =
		Kit.detail(ctx.m, f * CFrame.new(0, clockY, -0.72), Vector3.new(6.4, 6.4, 0.02), Look.white, M.SmoothPlastic)
	dial.Name = "Dial"
	dial.Transparency = 1
	local cgui, cw, ch =
		Deps.Gui.Core.surface(dial, Enum.NormalId.Front, { pps = 40, maxDistance = 220, name = "ClockFace" })
	Deps.Gui.Art.clockFace(cgui, cw, ch, 10, 10, Look.black, Look.cream)
	dial:AddTag("WallClock")
	-- display windows: glass fronts, lit backs, plinths, mannequins (or furniture), shop names and awnings
	for i, bay in bays do
		local x0, x1 = bay.x0, bay.x1
		local cx, bw = (x0 + x1) / 2, x1 - x0
		Kit.block(ctx.m, f * CFrame.new(cx, 8.5, 0.35), Vector3.new(bw, 13, 0.3), glassC, M.Glass, {
			Transparency = 0.6,
			Reflectance = 0.15,
			CastShadow = false,
		}).Name =
			"DisplayGlass"
		Mass.slab(ctx.m, f, C.box(x0, x1, 0, 4, 15, gh), Look.black, M.Granite, false).Name = "ShopFascia"
		local back = Mass.slab(ctx.m, f, C.box(x0, x1, 3.7, 3.95, 2, 15), Look.lampGlow, M.Neon, false)
		back.Transparency = 0.55
		back.CastShadow = false
		back:AddTag("InteriorLight")
		Mass.slab(ctx.m, f, C.box(x0, x1, 0.5, 3.7, 0, 2), Look.walnut, M.Wood, false)
		local nameBand = Kit.detail(
			ctx.m,
			f * CFrame.new(cx, 17.5, -0.06),
			Vector3.new(bw - 2, 2.2, 0.1),
			Look.black,
			M.SmoothPlastic
		)
		Kit.sign(
			nameBand,
			Text.get(bay.shop),
			{ color = Look.gold, font = Enum.Font.Garamond, pixelsPerStud = 40, glow = true }
		)
		Props.build("awning", ctx.m, f * CFrame.new(cx, 13.4, 0), {
			width = bw - 1,
			depth = 4,
			color = Look.black,
			accent = Look.gold,
			stripes = false,
			seed = "galleria-awning" .. i,
		})
		local floor = f * CFrame.new(cx, 2, 2.2) -- mannequins face the street (the lot frame looks out)
		local lookIdx = bay.look
		mannequin(ctx.m, floor * CFrame.new(-bw * 0.18, 0, 0), LOOKS[lookIdx], "Mannequin_" .. i .. "a")
		if i == 1 or i == 4 then
			mannequin(
				ctx.m,
				floor * CFrame.new(bw * 0.2, 0, 0),
				LOOKS[(lookIdx % #LOOKS) + 1],
				"Mannequin_" .. i .. "b"
			)
		elseif i == 3 then
			Props.build("watch_case", ctx.m, f * CFrame.new(cx + bw * 0.2, 2, 2.2), { seed = "galleria-watch" })
		else
			Props.build("lamp_floor", ctx.m, f * CFrame.new(cx + bw * 0.22, 2, 2.6), { seed = "galleria-lamp" })
		end
	end
	C.baseSides(ctx, gh, trim)
	-- planters at the ends of the frontage
	for _, sx in { -1, 1 } do
		Props.build(
			"planter_tree",
			ctx.m,
			f * CFrame.new(sx * (w / 2 - 5), 0, -8),
			{ variant = "topiary", seed = "galleria-planter" .. sx }
		)
	end
end

---------------------------------------------------------------------------------------------------
-- The Executive Club: a dark brick clubhouse with a green canopy, velvet ropes and lanterns
---------------------------------------------------------------------------------------------------
local function club(parent: Instance, rects: { Plan.Rect })
	local ctx = ctxFor(parent, "club", Text.get("club_name"), rects, "door_street_club", "street_club_front")
	local e = C.entrance(ctx, {
		mode = "portal",
		bh = 18,
		stone = Look.blackGranite,
		stoneMat = M.Granite,
		trim = Look.brass,
		doorWidth = 10,
		doorHeight = 12,
		shopLook = Mass.look("brick", {
			pier = Look.brass,
			pierMat = M.Metal,
			band = Look.brass,
			bandMat = M.Metal,
			pierW = 0.8,
			bandH = 0.8,
			depth = 0.5,
			bay = 6,
			lit = 0.8,
			litColor = Look.lampGlow,
		}),
		canopy = "cantilever",
		canopyColor = Look.awningGreen,
		canopyText = Text.get("club_sub"),
	})
	local b = C.stack(ctx, e.top, {
		{
			top = ctx.h * 0.88,
			look = Mass.look("brick", { core = Look.brickDark, pier = Look.brickDark, lit = 0.2 }),
			ledge = Look.limestone,
			ledgeMat = M.Limestone,
		},
	})
	C.mansard(ctx, b, ctx.h - b.y1, Look.slate)
	Brand.title(
		ctx.m,
		ctx.frame * e.fascia * CFrame.new(0, 0, -0.05),
		Text.get("club_name"),
		e.fasciaWidth,
		{ height = math.min(3, e.fasciaHeight - 1.2), lit = true }
	)
	C.lanterns(ctx, 7.2, 9)
	-- a small brass plate on the door surround
	Deps.Signs.plaque(ctx.m, ctx.frame * CFrame.new(-7.0, 3.6, -0.62), {
		title = Text.get("club_est"),
		text = Text.get("club_sub"),
		width = 2.0,
		height = 1.4,
	})
	for _, sx in { -1, 1 } do
		Props.build(
			"velvet_rope",
			ctx.m,
			ctx.frame * CFrame.new(sx * 6.5, 0, -6) * CFrame.Angles(0, math.pi / 2, 0),
			{ length = 5, seed = "club-rope" .. sx }
		)
	end
end

---------------------------------------------------------------------------------------------------
-- The Ashford Residences: a limestone residential tower with balconies and a marquee to the curb
---------------------------------------------------------------------------------------------------
local function apartments(parent: Instance, rects: { Plan.Rect })
	local ctx = ctxFor(
		parent,
		"apartments",
		Text.get("apartments_name"),
		rects,
		"door_street_apartments",
		"street_apartments_front"
	)
	local e = C.entrance(ctx, {
		mode = "portal",
		bh = 18,
		stone = Look.limestoneDark,
		stoneMat = M.Limestone,
		trim = Look.brass,
		doorWidth = 11,
		doorHeight = 12,
		shopLook = Mass.look("limestone", {
			pier = Look.brass,
			pierMat = M.Metal,
			band = Look.brass,
			bandMat = M.Metal,
			pierW = 0.8,
			bandH = 0.8,
			depth = 0.6,
			bay = 7,
			lit = 0.7,
		}),
		canopy = "marquee",
		canopyColor = Look.navy,
		canopyText = Text.get("apartments_name"),
		anchorDepth = 4,
	})
	local h = ctx.h
	local resi = Mass.look("limestone", { bay = 10, storey = 12, lit = 0.16, litColor = Look.lampGlow })
	local b3 = C.stack(ctx, e.top, {
		{ top = h * 0.24, look = resi, trim = Look.brass },
		{ inset = 4, front = 4, back = 4, top = h * 0.74, look = resi },
		{ inset = 9, front = 9, back = 9, top = h * 0.93, look = resi, trim = Look.brass },
	})
	-- balconies with glass rails on the front of the middle tier
	for y = h * 0.24 + 24, h * 0.74 - 12, 36 do
		Mass.slab(
			ctx.m,
			ctx.frame,
			C.box(-ctx.w / 2 + 8, ctx.w / 2 - 8, 4 - 4.5, 4 - 1.2, y, y + 0.8),
			Look.limestone,
			M.Limestone,
			false
		)
		local rail = Mass.slab(
			ctx.m,
			ctx.frame,
			C.box(-ctx.w / 2 + 8, ctx.w / 2 - 8, 4 - 4.6, 4 - 4.4, y + 0.8, y + 4),
			Look.lobbyGlass,
			M.Glass,
			false
		)
		rail.Transparency = 0.5
	end
	C.lantern(ctx, b3, 6, h - b3.y1 - 1.2, Look.glassBronze, Look.lampGlow, Look.verdigris)
	Brand.title(
		ctx.m,
		ctx.frame * e.fascia * CFrame.new(0, 0, -0.05),
		Text.get("apartments_number"),
		e.fasciaWidth * 0.6,
		{ height = math.min(2.6, e.fasciaHeight - 1.2) }
	)
	-- the doorman waits under the canopy beside the door, facing the street
	Kit.npcSpot(ctx.m, "npc_doorman_street", ctx.frame * CFrame.new(7.2, 3, -2.4))
	for _, sx in { -1, 1 } do
		Props.build(
			"planter_tree",
			ctx.m,
			ctx.frame * CFrame.new(sx * 16, 0, -4.2),
			{ variant = "topiary", seed = "ashford" .. sx }
		)
	end
end

---------------------------------------------------------------------------------------------------
-- Skyline Rooftop: a dark glass hotel tower with a vertical blade sign and a lit rooftop bar on top
---------------------------------------------------------------------------------------------------
local function rooftop(parent: Instance, rects: { Plan.Rect })
	local ctx =
		ctxFor(parent, "rooftop", Text.get("rooftop_name"), rects, "door_street_rooftop", "street_rooftop_front")
	local e = C.entrance(ctx, {
		mode = "portal",
		bh = 18,
		stone = Look.blackGranite,
		stoneMat = M.Basalt,
		trim = Look.bronze,
		doorWidth = 12,
		doorHeight = 12,
		shopLook = Mass.look("glassBronze", {
			curtain = false,
			pier = Look.bronze,
			pierMat = M.Metal,
			band = Look.bronze,
			bandMat = M.Metal,
			pierW = 0.8,
			bandH = 0.8,
			depth = 0.6,
			bay = 6,
			lit = 0.6,
			core = Look.blackGranite,
			coreMat = M.Basalt,
		}),
		canopy = "cantilever",
		canopyColor = Look.bronzeDark,
		canopyText = Text.get("rooftop_name"),
	})
	local h = ctx.h
	local top = h * 0.96
	local b = C.stack(ctx, e.top, {
		{ top = top, look = "glassBronze", ledge = Look.bronze },
	})
	Brand.title(
		ctx.m,
		ctx.frame * e.fascia * CFrame.new(0, 0, -0.05),
		Text.get("rooftop_sub"),
		e.fasciaWidth,
		{ height = math.min(2.2, e.fasciaHeight - 1.2), lit = true }
	)
	-- vertical blade sign on the front corner
	local bladeH = 90
	local blade = Mass.slab(
		ctx.m,
		ctx.frame,
		C.box(ctx.w / 2 - 1, ctx.w / 2 + 1, -9, -1, e.top + 6, e.top + 6 + bladeH),
		Look.black,
		M.Metal,
		false
	)
	blade.Name = "BladeSign"
	local letters = table.concat(string.split(Text.get("rooftop_blade"), ""), "\n")
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		Kit.sign(blade, letters, {
			face = face,
			color = Look.neonGold,
			font = Enum.Font.GothamBlack,
			pixelsPerStud = 6,
			glow = true,
			padding = 0.04,
		})
	end
	for _, z in { -9.1, -0.9 } do
		local tube = Kit.detail(
			ctx.m,
			ctx.frame * CFrame.new(ctx.w / 2, e.top + 6 + bladeH / 2, z),
			Vector3.new(2.2, bladeH, 0.25),
			Look.neonGold,
			M.Neon
		)
		tube.CastShadow = false
		tube:AddTag("StreetLight")
	end
	-- the rooftop bar: glass balustrade, a pergola, string lights and a glowing bar
	local y = b.y1
	local hw, d0, d1 = ctx.w / 2 - 1, 1, ctx.d - 1
	local rails = {
		C.box(-hw, hw, d0, d0 + 0.3, y, y + 4),
		C.box(-hw, hw, d1 - 0.3, d1, y, y + 4),
		C.box(-hw, -hw + 0.3, d0, d1, y, y + 4),
		C.box(hw - 0.3, hw, d0, d1, y, y + 4),
	}
	for _, r in rails do
		local p = Mass.slab(ctx.m, ctx.frame, r, Look.lobbyGlass, M.Glass, false)
		p.Transparency = 0.5
	end
	Mass.slab(ctx.m, ctx.frame, C.box(-hw + 6, hw - 6, 12, 26, y + 10, y + 10.6), Look.walnut, M.Wood, false).Name =
		"Pergola"
	for _, px in { -hw + 6, hw - 6 } do
		for _, pz in { 12, 26 } do
			Mass.slab(
				ctx.m,
				ctx.frame,
				C.box(px - 0.4, px + 0.4, pz - 0.4, pz + 0.4, y, y + 10),
				Look.walnut,
				M.Wood,
				false
			)
		end
	end
	for k = 0, 2 do
		local z = 6 + k * 14
		local s = Mass.slab(
			ctx.m,
			ctx.frame,
			C.box(-hw + 2, hw - 2, z, z + 0.25, y + 8.5, y + 8.75),
			Look.lampGlow,
			M.Neon,
			false
		)
		s.CastShadow = false
		s:AddTag("StreetLight")
	end
	local bar =
		Mass.slab(ctx.m, ctx.frame, C.box(-12, 12, ctx.d - 16, ctx.d - 12, y, y + 3.6), Look.neonGold, M.Neon, false)
	bar.Transparency = 0.3
	bar:AddTag("StreetLight")
	Kit.light(bar, "point", { Color = Look.lampGlow, Range = 30, Brightness = 1.4 })
end

function Venues.build(parent: Instance, rects: { Plan.Rect }): Model
	local m = Kit.model(parent, "Venues")
	careerServices(m, rects)
	galleria(m, rects)
	club(m, rects)
	apartments(m, rects)
	rooftop(m, rects)
	return m
end

return Venues
