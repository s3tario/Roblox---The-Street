--!strict
-- World layout (design v3): the authoritative map of regions, venue interiors, the office-instance system,
-- anchors, doors, interaction ids, NPC spots and event spots. World builders place geometry ONLY inside their
-- bounds and create the markers listed for their zones. Services read this to wire doors, teleports, lighting
-- and spawns. Bake-safe (pure data + Vector3).

local World = {}

export type Bounds = { min: Vector3, max: Vector3 }
export type InteriorDef = { slot: number, builder: string, lighting: string, theme: string }
export type ZoneDef = { kind: string, lighting: string, theme: string, label: string }
export type TowerDef = {
	id: string,
	label: string,
	style: string,
	company: string?,
	picker: { string }?,
	door: string?,
	anchor: string?,
}

---------------------------------------------------------------------------------------------------
-- Exterior regions (ground level y = 0)
---------------------------------------------------------------------------------------------------
World.regions = {
	campus = { min = Vector3.new(-1800, -40, -400), max = Vector3.new(-1000, 300, 400) },
	street = { min = Vector3.new(-450, -40, -450), max = Vector3.new(450, 700, 450) },
} :: { [string]: Bounds }

---------------------------------------------------------------------------------------------------
-- Venue interiors: shared pocket spaces reached by doors. Slot i occupies origin +/- HALF.
---------------------------------------------------------------------------------------------------
World.INTERIOR_HALF = 300
World.INTERIOR_HEIGHT = 260

function World.slotOrigin(i: number): Vector3
	local col = (i - 1) % 4
	local row = (i - 1) // 4
	return Vector3.new(3000 + col * 700, 0, 3000 + row * 700)
end

World.interiors = {
	career_center = { slot = 1, builder = "CampusInteriors", lighting = "campus_interior", theme = "campus" },
	lecture = { slot = 2, builder = "CampusInteriors", lighting = "campus_interior", theme = "campus" },
	dorm = { slot = 3, builder = "CampusInteriors", lighting = "campus_interior", theme = "campus" },
	subway = { slot = 4, builder = "CampusInteriors", lighting = "subway", theme = "campus" },
	career_services = { slot = 5, builder = "CareerServices", lighting = "office_interior", theme = "street" },
	exec_club = { slot = 6, builder = "ExecClub", lighting = "luxury_interior", theme = "street" },
	rooftop = { slot = 7, builder = "Rooftop", lighting = "rooftop", theme = "street" },
	apartments = { slot = 8, builder = "Apartments", lighting = "luxury_interior", theme = "street" },
	galleria = { slot = 9, builder = "Galleria", lighting = "luxury_interior", theme = "street" },
} :: { [string]: InteriorDef }

function World.interiorBounds(id: string): (Vector3, Vector3)
	local def = World.interiors[id]
	assert(def, "unknown interior " .. tostring(id))
	local o = World.slotOrigin(def.slot)
	local h = World.INTERIOR_HALF
	return Vector3.new(o.X - h, o.Y - 20, o.Z - h), Vector3.new(o.X + h, o.Y + World.INTERIOR_HEIGHT, o.Z + h)
end

---------------------------------------------------------------------------------------------------
-- Company offices (spec v3 §14). Each company present on a server gets an INSTANCE: a lobby plus one floor
-- per department, cloned at runtime from baked templates in ServerStorage.FirmTemplates.
-- Instance i (1-based), floor index f (0 = lobby) sits at officeOrigin(i, f). Templates are built around the
-- origin within +/- TEMPLATE_HALF (XZ) and y in [-10, TEMPLATE_HEIGHT].
---------------------------------------------------------------------------------------------------
World.offices = {
	origin = Vector3.new(8000, 0, 0),
	instanceSpacing = 900,
	floorSpacing = 500,
	maxInstances = 24,
	maxFloors = 8,
}
World.TEMPLATE_HALF = 220
World.TEMPLATE_HEIGHT = 140

function World.officeOrigin(instanceIndex: number, floorIndex: number): Vector3
	local o = World.offices
	return o.origin + Vector3.new((instanceIndex - 1) * o.instanceSpacing, 0, floorIndex * o.floorSpacing)
end

-- Department ids (= career track ids). Each has a floor template with the same id.
World.departments = { "ib", "st", "pe", "credit", "wm", "am", "er", "corpbank", "vc", "re", "corp" }

-- Template builders (src/world/<module>.luau export build(templateId, parent) -> Model at the origin).
-- Budgets are per template (part count).
World.templates = {
	{ module = "OfficeLobby", templates = { "lobby" }, budget = 1600, owner = "officesA" },
	{ module = "OfficeFloorsA", templates = { "ib", "st", "er", "corpbank" }, budget = 1500, owner = "officesA" },
	{ module = "OfficeFloorsB", templates = { "pe", "credit", "wm", "am" }, budget = 1500, owner = "officesB" },
	{ module = "OfficeFloorsC", templates = { "vc", "re", "corp" }, budget = 1500, owner = "officesB" },
}

-- Markers inside templates (attribute on a Kit marker part; the name of the attribute is the key):
World.templateMarkers = {
	OfficeAnchor = {
		"entry", -- lobby: arrival from the street (lobby only)
		"elevators", -- lobby: arrival from floors (lobby only)
		"floor_entry", -- floor: arrival from the elevator (floors only)
		"boss_chair", -- floor: boss NPC stands/sits here (floors only)
		"review_spot", -- floor: where the player stands for the weekly review (floors only)
		"rival_desk", -- floor: rival NPC spot (floors only)
		"receptionist", -- lobby: receptionist NPC spot (lobby only)
	},
	OfficeDoor = {
		"exit", -- lobby -> back to the street (WorldService: return to the entry door's exterior anchor)
		"to_lobby", -- floor -> lobby elevators
	},
}

-- Housing/plaque slots inside every FLOOR template (exact counts, tests enforce them).
World.floorSlots = { desks = 24, offices = 8, plaquesPerDesk = 3, plaquesPerShelf = 24 }

---------------------------------------------------------------------------------------------------
-- Zones (client lighting + ambience)
---------------------------------------------------------------------------------------------------
World.zones = {
	campus = { kind = "region", lighting = "campus_exterior", theme = "campus", label = "Eastbridge" },
	street = { kind = "region", lighting = "street_exterior", theme = "street", label = "Wall Street" },
	offices = { kind = "office", lighting = "office_interior", theme = "street", label = "Office" },
} :: { [string]: ZoneDef }
for id, def in World.interiors do
	World.zones[id] = { kind = "interior", lighting = def.lighting, theme = def.theme, label = id }
end

-- Office instance/floor at a position (or nil). Floor models also carry a "LightingPreset" attribute.
function World.officeAt(pos: Vector3): (number?, number?)
	local o = World.offices
	local dx = pos.X - o.origin.X
	local dz = pos.Z - o.origin.Z
	local i = math.floor(dx / o.instanceSpacing + 0.5) + 1
	local f = math.floor(dz / o.floorSpacing + 0.5)
	if i < 1 or i > o.maxInstances or f < 0 or f >= o.maxFloors then
		return nil, nil
	end
	local c = World.officeOrigin(i, f)
	if math.abs(pos.X - c.X) > World.TEMPLATE_HALF + 20 or math.abs(pos.Z - c.Z) > World.TEMPLATE_HALF + 20 then
		return nil, nil
	end
	return i, f
end

function World.zoneAt(pos: Vector3): string?
	for id, r in World.regions do
		if pos.X >= r.min.X and pos.X <= r.max.X and pos.Z >= r.min.Z and pos.Z <= r.max.Z then
			return id
		end
	end
	for id in World.interiors do
		local mn, mx = World.interiorBounds(id)
		if pos.X >= mn.X and pos.X <= mx.X and pos.Z >= mn.Z and pos.Z <= mx.Z then
			return id
		end
	end
	if World.officeAt(pos) then
		return "offices"
	end
	return nil
end

World.lightingPresets = {
	"campus_exterior",
	"street_exterior",
	"campus_interior",
	"office_interior",
	"trading_floor",
	"luxury_interior",
	"subway",
	"rooftop",
}

---------------------------------------------------------------------------------------------------
-- Builders baked into Workspace.World. Budgets are part counts.
---------------------------------------------------------------------------------------------------
World.builders = {
	{ module = "Campus", zones = { "campus" }, budget = 9000, owner = "campus" },
	{
		module = "CampusInteriors",
		zones = { "career_center", "lecture", "dorm", "subway" },
		budget = 3500,
		owner = "campus",
	},
	{ module = "Street", zones = { "street" }, budget = 17000, owner = "street" },
	{ module = "CareerServices", zones = { "career_services" }, budget = 700, owner = "venues" },
	{ module = "ExecClub", zones = { "exec_club" }, budget = 900, owner = "venues" },
	{ module = "Rooftop", zones = { "rooftop" }, budget = 700, owner = "venues" },
	{ module = "Apartments", zones = { "apartments" }, budget = 2600, owner = "venues" },
	{ module = "Galleria", zones = { "galleria" }, budget = 1400, owner = "venues" },
}

World.spawns = {
	Spawn_campus = { zone = "campus", anchor = "campus_spawn" },
	Spawn_street = { zone = "street", anchor = "street_station_platform" },
}

---------------------------------------------------------------------------------------------------
-- Company towers on the Street (spec v3 §14). `company` doors open that company's lobby instance;
-- `picker` doors (multi-tenant towers) open a tenant picker. Company ids must exist in Config/Companies.
-- The street builder creates every tower's door (Kit.door with its id) and front anchor.
---------------------------------------------------------------------------------------------------
World.towers = {
	-- Bank Row (each its own tower)
	{ id = "mg_freeman", label = "MG Freeman", style = "bulge", company = "mg_freeman" },
	{ id = "goldfield_saxe", label = "Goldfield Saxe", style = "bulge", company = "goldfield_saxe" },
	{ id = "morrow_stanton", label = "Morrow Stanton", style = "bulge", company = "morrow_stanton" },
	{ id = "merriweather_lynch", label = "Merriweather Lynch", style = "bulge", company = "merriweather_lynch" },
	{ id = "evermoor", label = "Evermoor Partners", style = "elite", company = "evermoor" },
	{ id = "lazaro_freres", label = "Lazaro Frères", style = "elite", company = "lazaro_freres" },
	{ id = "centerline", label = "Centerline Partners", style = "elite", company = "centerline" },
	{ id = "sterling_vance", label = "Sterling & Vance", style = "regional", company = "sterling_vance" },
	{ id = "anaeio", label = "Anaeio", style = "modern", company = "anaeio" },
	{ id = "applewood", label = "Applewood Industries", style = "corporate", company = "applewood" },
	-- Multi-tenant towers
	{
		id = "middle_market",
		label = "Middle Market Plaza",
		style = "glass",
		picker = { "harrow_williams", "blairmont", "houlton_lockey", "eastbridge_capital" },
	},
	{ id = "pe_tower", label = "Private Equity Tower", style = "stone", picker = { "bluestone", "krk", "ironclad" } },
	{
		id = "funds_tower",
		label = "Funds & Credit Tower",
		style = "dark_glass",
		picker = { "bridgecrest", "citrine", "quantum_ridge", "aresmont", "gray_heron" },
	},
	{ id = "wealth_house", label = "Wealth House", style = "townhouse", picker = { "lotus_wealth" } },
	{ id = "venture_row", label = "Venture Row", style = "loft", picker = { "sequel", "a17z", "seedline" } },
	{
		id = "property_exchange",
		label = "Property Exchange",
		style = "brick",
		picker = { "brookfold", "keystone", "northwind" },
	},
} :: { TowerDef }

---------------------------------------------------------------------------------------------------
-- Anchors (named CFrame markers) for the exterior regions and venues. Office anchors live in templates.
---------------------------------------------------------------------------------------------------
World.anchors = {
	-- campus exterior
	campus_spawn = { zone = "campus" },
	campus_station_platform = { zone = "campus" },
	campus_career_center_front = { zone = "campus" },
	campus_lecture_front = { zone = "campus" },
	campus_dorm_front = { zone = "campus" },
	campus_quad = { zone = "campus" },
	-- campus interiors
	career_center_entry = { zone = "career_center" },
	lecture_entry = { zone = "lecture" },
	dorm_entry = { zone = "dorm" },
	subway_car_to_street = { zone = "subway" },
	subway_car_to_campus = { zone = "subway" },
	-- street exterior
	street_station_platform = { zone = "street" },
	street_galleria_front = { zone = "street" },
	street_apartments_front = { zone = "street" },
	street_career_services_front = { zone = "street" },
	street_club_front = { zone = "street" },
	street_rooftop_front = { zone = "street" },
	street_plaza = { zone = "street" },
	-- venues
	career_services_entry = { zone = "career_services" },
	exec_club_entry = { zone = "exec_club" },
	rooftop_entry = { zone = "rooftop" },
	apartments_entry = { zone = "apartments" },
	galleria_entry = { zone = "galleria" },
}

---------------------------------------------------------------------------------------------------
-- Doors. Requirement fields (all optional, all must pass):
--   minRank = n            CareerService:GetRank(player) >= n
--   employed = true        CareerService:IsEmployed(player)
--   flag = "campus.offer"  dot path into player data must be truthy
--   orMinRank = n          passes if rank >= n even when `flag` fails
--   pass = "ExecutiveClub" MonetizationService:OwnsPass
-- Door kinds: `target` (anchor id), `ride` (timed transit), `company` (open that company's lobby instance),
-- `picker` (choose a tenant company). Office-internal doors are template markers (OfficeDoor).
---------------------------------------------------------------------------------------------------
World.doors = {
	-- campus exterior
	door_campus_career_center = { zone = "campus", target = "career_center_entry", label = "Career Center" },
	door_campus_lecture = { zone = "campus", target = "lecture_entry", label = "Halvorsen Hall" },
	door_campus_dorm = { zone = "campus", target = "dorm_entry", label = "Dorms" },
	door_campus_subway = {
		zone = "campus",
		label = "Subway: Downtown",
		ride = { via = "subway_car_to_street", seconds = 8, to = "street_station_platform" },
		requires = { flag = "campus.offer", orMinRank = 1 },
		lockedText = "You need a job offer before heading downtown.",
	},
	-- campus interiors
	door_career_center_exit = { zone = "career_center", target = "campus_career_center_front", label = "Exit" },
	door_lecture_exit = { zone = "lecture", target = "campus_lecture_front", label = "Exit" },
	door_dorm_exit = { zone = "dorm", target = "campus_dorm_front", label = "Exit" },
	-- street exterior
	door_street_subway = {
		zone = "street",
		label = "Subway: Eastbridge",
		ride = { via = "subway_car_to_campus", seconds = 8, to = "campus_station_platform" },
	},
	door_street_galleria = { zone = "street", target = "galleria_entry", label = "The Galleria" },
	door_street_apartments = {
		zone = "street",
		target = "apartments_entry",
		label = "The Ashford Residences",
		requires = { employed = true },
		lockedText = "Residents only. Land a job on the Street first.",
	},
	door_street_career_services = { zone = "street", target = "career_services_entry", label = "Career Services" },
	door_street_club = {
		zone = "street",
		target = "exec_club_entry",
		label = "The Executive Club",
		requires = { pass = "ExecutiveClub" },
		lockedText = "Executive Club members only.",
	},
	door_street_rooftop = {
		zone = "street",
		target = "rooftop_entry",
		label = "Skyline Rooftop",
		requires = { employed = true },
	},
	-- venues back to the Street
	door_career_services_exit = { zone = "career_services", target = "street_career_services_front", label = "Exit" },
	door_exec_club_exit = { zone = "exec_club", target = "street_club_front", label = "Exit" },
	door_rooftop_exit = { zone = "rooftop", target = "street_rooftop_front", label = "Exit" },
	door_apartments_exit = { zone = "apartments", target = "street_apartments_front", label = "Exit" },
	door_galleria_exit = { zone = "galleria", target = "street_galleria_front", label = "Exit" },
}

-- Generate tower doors + front anchors.
for _, t in World.towers do
	local doorId = "door_street_tower_" .. t.id
	local anchorId = "street_tower_" .. t.id .. "_front"
	World.doors[doorId] = {
		zone = "street",
		label = t.label,
		company = t.company,
		picker = t.picker,
		frontAnchor = anchorId,
	}
	World.anchors[anchorId] = { zone = "street" }
	t.door = doorId
	t.anchor = anchorId
end

---------------------------------------------------------------------------------------------------
-- Interaction ids (Kit.interact). The owner feature wires ProximityPrompts at runtime via the "Interact"
-- tag. Inside office instances, parts also carry CompanyId (set by OfficeService on clone); owners must
-- refuse non-employees ("Employees only").
---------------------------------------------------------------------------------------------------
World.interactIds = {
	terminal = { owner = "market", prompt = "Open Terminal" },
	work_desk = { owner = "work", prompt = "Work" },
	project_desk = { owner = "projects", prompt = "Deals & Projects" },
	profile_builder = { owner = "careerCore", prompt = "Life Roll" },
	career_services = { owner = "careerPath", prompt = "Career Services" },
	boss_review = { owner = "careerPath", prompt = "Weekly Review" },
	elevator_panel = { owner = "offices", prompt = "Elevator" },
	company_directory = { owner = "offices", prompt = "Company Directory" },
	wardrobe = { owner = "wardrobe", prompt = "Wardrobe" },
	shop = { owner = "shop", prompt = "Shop", attrs = { "Shop" } }, -- Shop = "tailor"|"watch"|"shoes"|"decor"|"campus_store"
	housing_panel = { owner = "shop", prompt = "Customize", attrs = { "Context" } }, -- Context = "dorm"|"apartment"|"desk"|"office"
	leaderboard = { owner = "leaderboards", prompt = "Rankings", attrs = { "BoardId" } },
	npc = { owner = "tutorial", prompt = "Talk", attrs = { "NpcId" } },
	store_kiosk = { owner = "monetization", prompt = "Store & Season Pass" },
	bulletin = { owner = "tutorial", prompt = "Recruiting Board" },
	news_stand = { owner = "market", prompt = "Market News" },
}

World.npcSpots = {
	campus = { "npc_alum", "npc_barista", "npc_bus_driver" },
	career_center = { "npc_advisor", "npc_recruiter" },
	lecture = { "npc_professor", "npc_club_president" },
	dorm = { "npc_roommate" },
	street = { "npc_newsie", "npc_doorman_street" },
	career_services = { "npc_career_counselor" },
	exec_club = { "npc_club_host" },
	rooftop = { "npc_mixer_host" },
	apartments = { "npc_concierge" },
	galleria = { "npc_tailor", "npc_watchmaker", "npc_shoe_clerk", "npc_decorator" },
}

World.eventSpots = {
	campus = { "muster_campus", "recruiting_booths", "pigeon_area_campus", "briefcase_c1", "briefcase_c2" },
	street = {
		"muster_street",
		"runway",
		"pigeon_area",
		"briefcase_s1",
		"briefcase_s2",
		"briefcase_s3",
		"briefcase_s4",
	},
	career_center = { "pizza_table_campus" },
	rooftop = { "mixer_area" },
}
-- Every office FLOOR template contains these EventSpot markers too:
World.templateEventSpots =
	{ "pizza_table", "ceo_path_1", "ceo_path_2", "ceo_path_3", "ceo_path_4", "fire_alarm", "briefcase_office" }

World.housing = {
	dorm = { attr = "UnitSlot", count = 24, zone = "dorm" },
	apartment = { attr = "UnitSlot", count = 24, zone = "apartments" },
	-- desk/office slots live in office floor templates (World.floorSlots)
}

World.MAX_PLAYERS = 24

return World
