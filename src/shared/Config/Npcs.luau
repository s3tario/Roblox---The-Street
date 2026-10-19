--!strict
-- NPCs (owned by `tutorial`): every character placed at a World.npcSpots spot, plus the office staff the offices
-- feature spawns (receptionist, boss) whose conversations the tutorial provides. Fictional people only.
-- Pure data: safe on the server, the client and under Lune.
--
--   Npcs.list = { NpcDef }  (Npcs.byId[id])       Npcs.office[role] = OfficeDef ("receptionist" | "boss")
--   Npcs.get(id) -> NpcDef?                         Npcs.forZone(zone) -> { NpcDef }
--
--   NpcDef = {
--     id, name, title, zone (World.npcSpots zone), dialogue (Config/Dialogue tree id),
--     preset (Config/Catalog.presets outfit), pose?, expression?, hairStyle?,
--     prompt? (ProximityPrompt action text; default "Talk"), color? ("#RRGGBB" name-tag accent)
--   }
--   OfficeDef = { dialogue, prompt?, employeesOnly }

export type NpcDef = {
	id: string,
	name: string,
	title: string,
	zone: string,
	dialogue: string,
	preset: string,
	pose: string?,
	expression: string?,
	hairStyle: string?,
	prompt: string?,
	color: string?,
}
export type OfficeDef = { dialogue: string, prompt: string?, employeesOnly: boolean }

local Npcs = {}

Npcs.TALK = "Talk"
Npcs.TALK_RANGE = 10 -- ProximityPrompt distance
Npcs.STAY_RANGE = 24 -- walking further than this from the NPC ends the conversation

Npcs.list = {
	-- Eastbridge campus (outdoors)
	{
		id = "npc_alum",
		name = "Jordan Reyes",
		title = "Alum, Class of '19",
		zone = "campus",
		dialogue = "alum",
		preset = "alum",
		expression = "grin",
	},
	{
		id = "npc_barista",
		name = "Rosie Tran",
		title = "Barista, The Grind House",
		zone = "campus",
		dialogue = "barista",
		preset = "barista",
		expression = "smile",
	},
	{
		id = "npc_bus_driver",
		name = "Earl Mackey",
		title = "Route 9 Driver",
		zone = "campus",
		dialogue = "bus_driver",
		preset = "bus_driver",
		pose = "arms_crossed",
		expression = "neutral",
	},
	-- Career Center
	{
		id = "npc_advisor",
		name = "Dana Whitfield",
		title = "Career Advisor",
		zone = "career_center",
		dialogue = "advisor",
		preset = "advisor",
		expression = "smile",
		color = "#C9A13B",
	},
	{
		id = "npc_recruiter",
		name = "Marcus Bell",
		title = "Campus Recruiter",
		zone = "career_center",
		dialogue = "recruiter",
		preset = "recruiter",
		expression = "focused",
	},
	-- Halvorsen Hall
	{
		id = "npc_professor",
		name = "Prof. Helen Okafor",
		title = "Corporate Finance",
		zone = "lecture",
		dialogue = "professor",
		preset = "professor",
		expression = "focused",
	},
	{
		id = "npc_club_president",
		name = "Priya Shah",
		title = "Finance Club President",
		zone = "lecture",
		dialogue = "club_president",
		preset = "club_president",
		expression = "grin",
		color = "#C9A13B",
	},
	-- Dorms
	{
		id = "npc_roommate",
		name = "Theo Park",
		title = "Your Roommate",
		zone = "dorm",
		dialogue = "roommate",
		preset = "roommate",
		expression = "grin",
	},
	-- The Street
	{
		id = "npc_newsie",
		name = "Sal Benedetto",
		title = "Benedetto's Newsstand",
		zone = "street",
		dialogue = "newsie",
		preset = "newsie",
		expression = "grin",
	},
	{
		id = "npc_doorman_street",
		name = "Walter Greene",
		title = "Doorman",
		zone = "street",
		dialogue = "doorman",
		preset = "doorman",
		expression = "smile",
	},
	-- Career Services
	{
		id = "npc_career_counselor",
		name = "Ruth Alvarez",
		title = "Career Counselor",
		zone = "career_services",
		dialogue = "counselor",
		preset = "counselor",
		expression = "smile",
		color = "#8FB8DE",
	},
	-- Venues
	{
		id = "npc_club_host",
		name = "Laurent Duval",
		title = "Host, The Executive Club",
		zone = "exec_club",
		dialogue = "club_host",
		preset = "club_host",
		expression = "smile",
	},
	{
		id = "npc_mixer_host",
		name = "Simone Hart",
		title = "Skyline Rooftop Events",
		zone = "rooftop",
		dialogue = "mixer_host",
		preset = "vp",
		expression = "grin",
	},
	{
		id = "npc_concierge",
		name = "Henry Osei",
		title = "Concierge, The Ashford",
		zone = "apartments",
		dialogue = "concierge",
		preset = "concierge",
		expression = "smile",
	},
	-- The Galleria
	{
		id = "npc_tailor",
		name = "Vittorio Russo",
		title = "Master Tailor, Hartwell Tailors",
		zone = "galleria",
		dialogue = "tailor",
		preset = "tailor",
		expression = "focused",
	},
	{
		id = "npc_watchmaker",
		name = "Ingrid Larsen",
		title = "Watchmaker, Vanta Watches",
		zone = "galleria",
		dialogue = "watchmaker",
		preset = "watchmaker",
		expression = "neutral",
	},
	{
		id = "npc_shoe_clerk",
		name = "Dev Malhotra",
		title = "Strider Shoes & Leather",
		zone = "galleria",
		dialogue = "shoe_clerk",
		preset = "shoe_clerk",
		expression = "grin",
	},
	{
		id = "npc_decorator",
		name = "Camille Brooks",
		title = "Galleria Home & Office",
		zone = "galleria",
		dialogue = "decorator",
		preset = "decorator",
		expression = "smile",
	},
} :: { NpcDef }

-- Office staff: spawned by OfficeService (models carry OfficeNpc = role, CompanyId, DisplayName, Title); NpcService
-- adds the Talk prompt and DialogueService runs these trees.
Npcs.office = {
	receptionist = { dialogue = "receptionist", employeesOnly = false },
	boss = { dialogue = "boss", employeesOnly = true },
} :: { [string]: OfficeDef }

Npcs.byId = {} :: { [string]: NpcDef }
for _, def in Npcs.list do
	assert(Npcs.byId[def.id] == nil, "Npcs: duplicate id " .. def.id)
	Npcs.byId[def.id] = def
end

function Npcs.get(id: any): NpcDef?
	if type(id) ~= "string" then
		return nil
	end
	return Npcs.byId[id]
end

function Npcs.forZone(zone: string): { NpcDef }
	local out: { NpcDef } = {}
	for _, def in Npcs.list do
		if def.zone == zone then
			table.insert(out, def)
		end
	end
	return out
end

return Npcs
