--!strict
-- World layout: the authoritative map of regions, interiors, zones, anchors, doors, interaction ids and
-- event spots. World builders place geometry ONLY inside their bounds and create the anchors/doors listed
-- for their zones. Services read this to wire doors, teleports, lighting and spawns.
-- Bake-safe (pure data + Vector3).

local World = {}

export type Bounds = { min: Vector3, max: Vector3 }
export type InteriorDef = { slot: number, builder: string, lighting: string, theme: string }
export type ZoneDef = { kind: string, lighting: string, theme: string, label: string }

---------------------------------------------------------------------------------------------------
-- Regions (exterior) and interior slots
---------------------------------------------------------------------------------------------------
-- Exterior regions. Ground level is y = 0 in every region.
World.regions = {
	campus = { min = Vector3.new(-1800, -40, -400), max = Vector3.new(-1000, 300, 400) },
	street = { min = Vector3.new(-450, -40, -450), max = Vector3.new(450, 700, 450) },
} :: { [string]: Bounds }

-- Interiors are pocket spaces far from the exterior regions, reached by doors.
-- Slot i occupies origin +/- (HALF, *, HALF) with floor at origin.Y.
World.INTERIOR_HALF = 300
World.INTERIOR_HEIGHT = 260

function World.slotOrigin(i: number): Vector3
	local col = (i - 1) % 4
	local row = (i - 1) // 4
	return Vector3.new(3000 + col * 700, 0, 3000 + row * 700)
end

-- id -> { slot, builder (module owning it), lighting preset, theme }
World.interiors = {
	career_center = { slot = 1, builder = "CampusInteriors", lighting = "campus_interior", theme = "campus" },
	lecture = { slot = 2, builder = "CampusInteriors", lighting = "campus_interior", theme = "campus" },
	dorm = { slot = 3, builder = "CampusInteriors", lighting = "campus_interior", theme = "campus" },
	subway = { slot = 4, builder = "CampusInteriors", lighting = "subway", theme = "campus" },
	hq_lobby = { slot = 5, builder = "HQ", lighting = "office_interior", theme = "street" },
	hq_office = { slot = 6, builder = "HQ", lighting = "office_interior", theme = "street" },
	hq_trading = { slot = 7, builder = "HQ", lighting = "trading_floor", theme = "street" },
	hq_exec = { slot = 8, builder = "HQ", lighting = "luxury_interior", theme = "street" },
	career_services = { slot = 9, builder = "CareerServices", lighting = "office_interior", theme = "street" },
	exec_club = { slot = 10, builder = "ExecClub", lighting = "luxury_interior", theme = "street" },
	rooftop = { slot = 11, builder = "Rooftop", lighting = "rooftop", theme = "street" },
	realm_pe = { slot = 12, builder = "RealmOffices", lighting = "office_interior", theme = "street" },
	realm_hf = { slot = 13, builder = "RealmOffices", lighting = "trading_floor", theme = "street" },
	realm_vc = { slot = 14, builder = "RealmOffices", lighting = "office_interior", theme = "street" },
	realm_re = { slot = 15, builder = "RealmOffices", lighting = "office_interior", theme = "street" },
	realm_cd = { slot = 16, builder = "RealmOffices", lighting = "office_interior", theme = "street" },
	partner_firm = { slot = 17, builder = "PartnerFirm", lighting = "luxury_interior", theme = "street" },
	apartments = { slot = 18, builder = "Apartments", lighting = "luxury_interior", theme = "street" },
	galleria = { slot = 19, builder = "Galleria", lighting = "luxury_interior", theme = "street" },
} :: { [string]: InteriorDef }

function World.interiorBounds(id: string): (Vector3, Vector3)
	local def = World.interiors[id]
	assert(def, "unknown interior " .. tostring(id))
	local o = World.slotOrigin(def.slot)
	local h = World.INTERIOR_HALF
	return Vector3.new(o.X - h, o.Y - 20, o.Z - h), Vector3.new(o.X + h, o.Y + World.INTERIOR_HEIGHT, o.Z + h)
end

---------------------------------------------------------------------------------------------------
-- Zones: what the client uses to pick lighting + ambience. Exterior regions and every interior.
---------------------------------------------------------------------------------------------------
World.zones = {
	campus = { kind = "region", lighting = "campus_exterior", theme = "campus", label = "Eastbridge" },
	street = { kind = "region", lighting = "street_exterior", theme = "street", label = "Wall Street" },
} :: { [string]: ZoneDef }
for id, def in World.interiors do
	World.zones[id] = { kind = "interior", lighting = def.lighting, theme = def.theme, label = id }
end

-- Returns zoneId containing position (or nil).
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
	return nil
end

-- Lighting presets referenced by zones (applied by EnvironmentController; weather layers on top).
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
-- Builders baked into Workspace.World (order matters only for readability). Budgets are part counts.
-- Each builder module lives at src/world/<module>.luau (or <module>/init.luau) and exports build(parent).
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
	{
		module = "HQ",
		zones = { "hq_lobby", "hq_office", "hq_trading", "hq_exec" },
		budget = 5500,
		owner = "interiorsA",
	},
	{ module = "CareerServices", zones = { "career_services" }, budget = 700, owner = "interiorsA" },
	{ module = "ExecClub", zones = { "exec_club" }, budget = 900, owner = "interiorsA" },
	{ module = "Rooftop", zones = { "rooftop" }, budget = 700, owner = "interiorsA" },
	{
		module = "RealmOffices",
		zones = { "realm_pe", "realm_hf", "realm_vc", "realm_re", "realm_cd" },
		budget = 4500,
		owner = "interiorsB",
	},
	{ module = "PartnerFirm", zones = { "partner_firm" }, budget = 900, owner = "interiorsB" },
	{ module = "Apartments", zones = { "apartments" }, budget = 2600, owner = "interiorsB" },
	{ module = "Galleria", zones = { "galleria" }, budget = 1400, owner = "interiorsB" },
}

-- SpawnLocations each exterior builder must create (Neutral = true). WorldService sets RespawnLocation.
World.spawns = {
	Spawn_campus = { zone = "campus", anchor = "campus_spawn" },
	Spawn_street = { zone = "street", anchor = "street_station_platform" },
}

---------------------------------------------------------------------------------------------------
-- Anchors: named CFrame markers. `zone` says which builder must create it.
---------------------------------------------------------------------------------------------------
World.anchors = {
	-- campus exterior
	campus_spawn = { zone = "campus" }, -- bus depot arrival
	campus_station_platform = { zone = "campus" }, -- subway arrival from the Street
	campus_career_center_front = { zone = "campus" },
	campus_lecture_front = { zone = "campus" },
	campus_dorm_front = { zone = "campus" },
	campus_quad = { zone = "campus" },
	-- campus interiors
	career_center_entry = { zone = "career_center" },
	lecture_entry = { zone = "lecture" },
	dorm_entry = { zone = "dorm" },
	subway_car_to_street = { zone = "subway" }, -- inside the moving car, heading downtown
	subway_car_to_campus = { zone = "subway" }, -- inside the car, heading uptown
	-- street exterior
	street_station_platform = { zone = "street" },
	street_hq_front = { zone = "street" },
	street_galleria_front = { zone = "street" },
	street_apartments_front = { zone = "street" },
	street_career_services_front = { zone = "street" },
	street_realm_pe_front = { zone = "street" },
	street_realm_hf_front = { zone = "street" },
	street_realm_vc_front = { zone = "street" },
	street_realm_re_front = { zone = "street" },
	street_realm_cd_front = { zone = "street" },
	street_partner_front = { zone = "street" },
	street_plaza = { zone = "street" },
	-- HQ
	hq_lobby_entry = { zone = "hq_lobby" },
	hq_lobby_elevators = { zone = "hq_lobby" },
	hq_office_entry = { zone = "hq_office" },
	hq_trading_entry = { zone = "hq_trading" },
	hq_exec_entry = { zone = "hq_exec" },
	career_services_entry = { zone = "career_services" },
	exec_club_entry = { zone = "exec_club" },
	rooftop_entry = { zone = "rooftop" },
	-- realms & others
	realm_pe_entry = { zone = "realm_pe" },
	realm_hf_entry = { zone = "realm_hf" },
	realm_vc_entry = { zone = "realm_vc" },
	realm_re_entry = { zone = "realm_re" },
	realm_cd_entry = { zone = "realm_cd" },
	partner_entry = { zone = "partner_firm" },
	apartments_entry = { zone = "apartments" },
	galleria_entry = { zone = "galleria" },
}

---------------------------------------------------------------------------------------------------
-- Doors. The builder of `zone` creates the Door part. WorldService teleports to `target` when the
-- requirement passes. `ride` = a timed transit through an intermediate anchor.
-- Requirement fields (all optional, all must pass):
--   minRank = n            CareerService:GetRank(player) >= n
--   employed = true        CareerService:IsEmployed(player)
--   flag = "campus.offer"  data.campus.offer == true (dot path into player data)
--   orMinRank = n          alternative: passes if rank >= n even when `flag` fails
--   realm = "pe"           data.career.track == realm (or rank >= realmVisitRank)
--   realmVisitRank = n
--   pass = "ExecutiveClub" MonetizationService:OwnsPass
--   elevator = true        blocked while event "elevator_outage" is active
--   stairs = true          only usable while "elevator_outage" is active (10 s climb)
--   firm = "mg_freeman"    data.career.firmId must match (badge access to your own firm's tower)
-- Door flag `returnToEntry = true`: send the player back to the exterior anchor of the door they came in through
-- (WorldService remembers it per player); `target` is the fallback.
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
		lockedText = "You need an internship offer before heading downtown.",
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
	door_street_hq = {
		zone = "street",
		target = "hq_lobby_entry",
		label = "Sterling & Vance",
		requires = { firm = "sterling_vance" },
		lockedText = "Badge access only: Sterling & Vance employees.",
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
	door_street_realm_pe = {
		zone = "street",
		target = "realm_pe_entry",
		label = "Private Equity Tower",
		requires = { realm = "pe", realmVisitRank = 6 },
	},
	door_street_realm_hf = {
		zone = "street",
		target = "realm_hf_entry",
		label = "Asset Management Tower",
		requires = { realm = "hf", realmVisitRank = 6 },
	},
	door_street_realm_vc = {
		zone = "street",
		target = "realm_vc_entry",
		label = "Venture Row",
		requires = { realm = "vc", realmVisitRank = 6 },
	},
	door_street_realm_re = {
		zone = "street",
		target = "realm_re_entry",
		label = "Real Estate Exchange",
		requires = { realm = "re", realmVisitRank = 6 },
	},
	door_street_realm_cd = {
		zone = "street",
		target = "realm_cd_entry",
		label = "Corporate Plaza",
		requires = { realm = "cd", realmVisitRank = 6 },
	},
	door_street_partner = {
		zone = "street",
		target = "partner_entry",
		label = "Your Firm",
		requires = { minRank = 10 },
		lockedText = "Make Partner to open your own firm.",
	},
	-- HQ lobby
	door_hq_lobby_exit = {
		zone = "hq_lobby",
		target = "street_hq_front",
		label = "Exit to Street",
		returnToEntry = true,
	},
	elev_office = {
		zone = "hq_lobby",
		target = "hq_office_entry",
		label = "Floor 22: Investment Banking",
		requires = { minRank = 1, elevator = true },
	},
	elev_trading = {
		zone = "hq_lobby",
		target = "hq_trading_entry",
		label = "Floor 9: Trading",
		requires = { minRank = 1, elevator = true },
	},
	elev_exec = {
		zone = "hq_lobby",
		target = "hq_exec_entry",
		label = "Floor 40: Executive",
		requires = { minRank = 1, elevator = true },
	},
	elev_club = {
		zone = "hq_lobby",
		target = "exec_club_entry",
		label = "Floor 51: Executive Club",
		requires = { pass = "ExecutiveClub", elevator = true },
		lockedText = "Executive Club members only.",
	},
	elev_rooftop = {
		zone = "hq_lobby",
		target = "rooftop_entry",
		label = "Roof Terrace",
		requires = { minRank = 1, elevator = true },
	},
	door_hq_stairs = {
		zone = "hq_lobby",
		target = "hq_office_entry",
		label = "Stairs (Floor 22)",
		requires = { minRank = 1, stairs = true },
	},
	-- HQ floors back to lobby
	door_hq_office_elev = { zone = "hq_office", target = "hq_lobby_elevators", label = "Elevators" },
	door_hq_trading_elev = { zone = "hq_trading", target = "hq_lobby_elevators", label = "Elevators" },
	door_hq_exec_elev = { zone = "hq_exec", target = "hq_lobby_elevators", label = "Elevators" },
	door_exec_club_elev = { zone = "exec_club", target = "hq_lobby_elevators", label = "Elevators" },
	door_rooftop_elev = { zone = "rooftop", target = "hq_lobby_elevators", label = "Elevators" },
	-- other interiors back to the Street
	door_career_services_exit = { zone = "career_services", target = "street_career_services_front", label = "Exit" },
	door_realm_pe_exit = { zone = "realm_pe", target = "street_realm_pe_front", label = "Exit" },
	door_realm_hf_exit = { zone = "realm_hf", target = "street_realm_hf_front", label = "Exit" },
	door_realm_vc_exit = { zone = "realm_vc", target = "street_realm_vc_front", label = "Exit" },
	door_realm_re_exit = { zone = "realm_re", target = "street_realm_re_front", label = "Exit" },
	door_realm_cd_exit = { zone = "realm_cd", target = "street_realm_cd_front", label = "Exit" },
	door_partner_exit = { zone = "partner_firm", target = "street_partner_front", label = "Exit" },
	door_apartments_exit = { zone = "apartments", target = "street_apartments_front", label = "Exit" },
	door_galleria_exit = { zone = "galleria", target = "street_galleria_front", label = "Exit" },
}

---------------------------------------------------------------------------------------------------
-- Bank Row: one branded tower per investment-banking firm (spec §4b). Each tower's door leads into the
-- shared HQ interior, where the client re-skins FirmBrand signage. Sterling & Vance uses door_street_hq.
-- Firm ids must exist in Config/Firms (career feature).
---------------------------------------------------------------------------------------------------
World.firmTowers = {
	{ id = "mg_freeman", label = "MG Freeman", tier = "bulge" },
	{ id = "goldfield_saxe", label = "Goldfield Saxe", tier = "bulge" },
	{ id = "morrow_stanton", label = "Morrow Stanton", tier = "bulge" },
	{ id = "merriweather_lynch", label = "Merriweather Lynch", tier = "bulge" },
	{ id = "evermoor", label = "Evermoor Partners", tier = "elite" },
	{ id = "lazaro_freres", label = "Lazaro Frères", tier = "elite" },
	{ id = "centerline", label = "Centerline Partners", tier = "elite" },
	{ id = "harrow_williams", label = "Harrow Williams", tier = "middle" },
	{ id = "blairmont", label = "Blairmont & Co.", tier = "middle" },
	{ id = "houlton_lockey", label = "Houlton Lockey", tier = "middle" },
	{ id = "eastbridge_capital", label = "Eastbridge Capital Advisors", tier = "regional" },
	{
		id = "sterling_vance",
		label = "Sterling & Vance",
		tier = "regional",
		door = "door_street_hq",
		anchor = "street_hq_front",
	},
}
for _, t in World.firmTowers do
	if not t.door then
		local doorId = "door_street_firm_" .. t.id
		local anchorId = "street_firm_" .. t.id .. "_front"
		World.doors[doorId] = {
			zone = "street",
			target = "hq_lobby_entry",
			label = t.label,
			requires = { firm = t.id },
			lockedText = "Badge access only: " .. t.label .. " employees.",
		}
		World.anchors[anchorId] = { zone = "street" }
		t.door = doorId
		t.anchor = anchorId
	end
end

---------------------------------------------------------------------------------------------------
-- Interaction ids (Kit.interact). The owner feature wires ProximityPrompts at runtime via the
-- "Interact" tag. Builders may add attributes listed in `attrs`.
---------------------------------------------------------------------------------------------------
World.interactIds = {
	terminal = { owner = "market", prompt = "Open Terminal" },
	work_desk = { owner = "work", prompt = "Work" },
	project_desk = { owner = "realmsA", prompt = "Projects", attrs = { "Realm" } }, -- Realm = "ib"|"pe"|...|"partner"
	profile_builder = { owner = "career", prompt = "Build Profile" },
	career_services = { owner = "career", prompt = "Career Services" },
	wardrobe = { owner = "wardrobe", prompt = "Wardrobe" },
	shop = { owner = "shop", prompt = "Shop", attrs = { "Shop" } }, -- Shop = "tailor"|"watch"|"shoes"|"decor"|"campus_store"
	housing_panel = { owner = "shop", prompt = "Customize", attrs = { "Context" } }, -- Context = "dorm"|"apartment"|"desk"|"office"|"firm"
	leaderboard = { owner = "leaderboards", prompt = "Rankings", attrs = { "BoardId" } },
	npc = { owner = "tutorial", prompt = "Talk", attrs = { "NpcId" } },
	store_kiosk = { owner = "monetization", prompt = "Store & Season Pass" },
	bulletin = { owner = "tutorial", prompt = "Read Board" },
	news_stand = { owner = "market", prompt = "Market News" },
}

-- NPC ids that world builders place via Kit.interact(part, "npc", {NpcId = id}). Part = standing spot
-- (2x1x2 marker on the floor, front face = facing direction).
World.npcSpots = {
	campus = { "npc_alum", "npc_barista", "npc_bus_driver" },
	career_center = { "npc_advisor", "npc_recruiter_sv" },
	lecture = { "npc_professor", "npc_club_president" },
	dorm = { "npc_roommate" },
	street = { "npc_newsie", "npc_doorman_street" },
	hq_lobby = { "npc_hq_receptionist" },
	hq_office = { "npc_mentor" },
	hq_trading = { "npc_trader" },
	hq_exec = { "npc_md" },
	career_services = { "npc_career_counselor" },
	exec_club = { "npc_club_host" },
	realm_pe = { "npc_realm_pe_head" },
	realm_hf = { "npc_realm_hf_head" },
	realm_vc = { "npc_realm_vc_head" },
	realm_re = { "npc_realm_re_head" },
	realm_cd = { "npc_realm_cd_head" },
	apartments = { "npc_concierge" },
	galleria = { "npc_tailor", "npc_watchmaker", "npc_shoe_clerk", "npc_decorator" },
}

-- Event spots (Kit.eventSpot). Builders of the listed zone must create them.
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
	hq_lobby = { "briefcase_h1" },
	hq_office = { "ceo_path_1", "ceo_path_2", "ceo_path_3", "ceo_path_4", "pizza_table_1", "fire_alarm_office" },
	hq_trading = { "ceo_path_5", "ceo_path_6", "pizza_table_2", "fire_alarm_trading", "briefcase_h2" },
	rooftop = { "mixer_area" },
}

-- Housing slot counts (interiors builders must create exactly these many slot models).
World.housing = {
	dorm = { attr = "UnitSlot", count = 24, zone = "dorm" },
	apartment = { attr = "UnitSlot", count = 24, zone = "apartments" },
	desk = { attr = "DeskSlot", count = 24, zone = "hq_office" },
	office = { attr = "OfficeSlot", count = 8, zone = "hq_exec" },
	firm = { attr = "FirmSlot", count = 6, zone = "partner_firm" }, -- one suite per partner on the server
}

World.MAX_PLAYERS = 24

return World
