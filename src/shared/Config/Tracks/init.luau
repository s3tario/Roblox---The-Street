--!strict
-- Career tracks (owned by `careerPath`; design v3 §4, contracts §5). Pure data plus small lookup helpers: safe on
-- the server, the client and under Lune.
--
-- Every track uses the same generic schema so later milestones only add data:
--   Tracks.list = { TrackDef }   (all 11 track ids from contracts §16, in display order)
--   TrackDef = {
--     id, name, short, available,          -- available = false: listed as "Coming soon" (M5+)
--     entryTitle, topTitle, difficulty,    -- recruiting difficulty blurb (v3 §4 table)
--     signatureDeal?,                      -- the track's big-deal project id (contracts §9)
--     ladder = { RoleDef },                -- rank 1..N (available tracks only)
--   }
--   RoleDef = {
--     rank, roleId, title, track,
--     minLevel, maxLevel,                  -- level band; XP can't push past maxLevel until promoted
--     salary, bonus,                       -- weekly base salary and on-target bonus (before company payMult)
--     book,                                -- trading book size (before company bookMult)
--     prestige,                            -- weekly Career Prestige at On track (before company prestigeMult)
--     minOvr,                              -- OVR needed to be promoted INTO this rank: a soft floor. Rolled
--                                          -- stats start near OVR 40 and grow ~0.6/active hour (Logic/Stats), so
--                                          -- a typical player clears it; one who never does graded work doesn't
--     coreToPromote?,                      -- core assignments at this rank needed to be promoted OUT of it
--     schoolGate?,                         -- school tier order needed for this title (1 common .. 6 mythic)
--     dressLevel?,                         -- outfit level needed for this title (default min(5, rank + 1))
--     office?,                             -- true: a private office instead of a desk (v3 §13: rank >= 3)
--   }
-- Rank 0 is the student pseudo-role (Tracks.STUDENT); "unemployed" marks a fired player between jobs.
--
-- Salary calibration (spec §11): about 30% of a rank's typical cash per active hour comes from the weekly pay
-- (2/3 base salary, 1/3 on-target bonus) over a 40-minute work week:
--   Analyst ~$8k/h, Associate ~$15k/h, VP ~$25k/h, Director ~$32k/h, MD ~$45k/h.
-- Level bands are tuned with the Logic/Leveling pacing simulator (tests/careerPath/leveling.spec.luau):
-- a typical engaged player reaches MD at about 30-35 active hours and L100 at about 55-65 hours.

export type RoleDef = {
	rank: number,
	roleId: string,
	title: string,
	track: string,
	minLevel: number,
	maxLevel: number,
	salary: number,
	bonus: number,
	book: number,
	prestige: number,
	minOvr: number,
	coreToPromote: number?,
	schoolGate: number?,
	dressLevel: number?,
	office: boolean?,
}

export type TrackDef = {
	id: string,
	name: string,
	short: string,
	available: boolean,
	entryTitle: string,
	topTitle: string,
	difficulty: string,
	signatureDeal: string?,
	ladder: { RoleDef },
}

local Tracks = {}

Tracks.IDS = { "ib", "st", "pe", "credit", "wm", "am", "er", "corpbank", "vc", "re", "corp" }

-- School tier names by order (v3 §1), used in school-gate explanations ("Rare+").
Tracks.TIER_NAMES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
Tracks.RARITY_ORDER = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 6 } :: {
	[string]: number,
}

Tracks.MAX_LEVEL = 100

-- The student pseudo-role (campus, levels 1-8).
Tracks.STUDENT = {
	rank = 0,
	roleId = "student",
	title = "College Student",
	track = "",
	minLevel = 1,
	maxLevel = 8,
	salary = 0,
	bonus = 0,
	book = 5000,
	prestige = 0,
	minOvr = 0,
} :: RoleDef

Tracks.UNEMPLOYED_ROLE = "unemployed"

---------------------------------------------------------------------------------------------------
-- Track data
---------------------------------------------------------------------------------------------------
local defs: { [string]: any } = {
	ib = {
		id = "ib",
		name = "Investment Banking",
		short = "IB",
		available = true,
		entryTitle = "Analyst",
		topTitle = "Managing Director",
		difficulty = "Very hard at bulge brackets and elite boutiques, medium at middle-market firms, easy at regional desks.",
		signatureDeal = "ipo",
		ladder = {
			{
				rank = 1,
				roleId = "ib_analyst",
				title = "Analyst",
				minLevel = 9,
				maxLevel = 24,
				salary = 1100,
				bonus = 500,
				book = 250000,
				prestige = 10,
				minOvr = 0,
				coreToPromote = 12,
			},
			{
				rank = 2,
				roleId = "ib_associate",
				title = "Associate",
				minLevel = 25,
				maxLevel = 40,
				salary = 2000,
				bonus = 1000,
				book = 500000,
				prestige = 18,
				minOvr = 30,
				coreToPromote = 14,
			},
			{
				rank = 3,
				roleId = "ib_vp",
				title = "Vice President",
				minLevel = 41,
				maxLevel = 53,
				salary = 3300,
				bonus = 1700,
				book = 750000,
				prestige = 28,
				minOvr = 38,
				coreToPromote = 14,
				office = true,
			},
			{
				rank = 4,
				roleId = "ib_director",
				title = "Director",
				minLevel = 54,
				maxLevel = 65,
				salary = 4300,
				bonus = 2100,
				book = 900000,
				prestige = 40,
				minOvr = 44,
				coreToPromote = 16,
				office = true,
			},
			{
				rank = 5,
				roleId = "ib_md",
				title = "Managing Director",
				minLevel = 66,
				maxLevel = 100,
				salary = 6000,
				bonus = 3000,
				book = 1000000,
				prestige = 55,
				minOvr = 50,
				schoolGate = 3,
				office = true,
			},
		} :: { any },
	},
	-- Later milestones (M5+) fill in ladders, companies, floors and tasks for these.
	st = {
		id = "st",
		name = "Sales & Trading",
		short = "S&T",
		entryTitle = "Analyst",
		topTitle = "Managing Director",
		difficulty = "Hard.",
	},
	pe = {
		id = "pe",
		name = "Private Equity",
		short = "PE",
		entryTitle = "Analyst",
		topTitle = "Senior Partner",
		difficulty = "Extremely hard: few seats, Epic+ school or a Master's with a Rare+ school and a 3.7+ GPA.",
	},
	credit = {
		id = "credit",
		name = "Private Credit",
		short = "Credit",
		entryTitle = "Analyst",
		topTitle = "Managing Director",
		difficulty = "Hard.",
	},
	wm = {
		id = "wm",
		name = "Wealth Management",
		short = "WM",
		entryTitle = "Associate",
		topTitle = "Partner",
		difficulty = "Hard at the top firms; connections and Charisma matter.",
	},
	am = {
		id = "am",
		name = "Asset Management & Hedge Funds",
		short = "AM/HF",
		entryTitle = "Analyst",
		topTitle = "Chief Investment Officer",
		difficulty = "Very hard.",
	},
	er = {
		id = "er",
		name = "Equity Research",
		short = "ER",
		entryTitle = "Research Associate",
		topTitle = "Director of Research",
		difficulty = "Medium.",
	},
	corpbank = {
		id = "corpbank",
		name = "Corporate Banking",
		short = "Corp Banking",
		entryTitle = "Analyst",
		topTitle = "Managing Director",
		difficulty = "Medium-easy.",
	},
	vc = {
		id = "vc",
		name = "Venture Capital",
		short = "VC",
		entryTitle = "Analyst",
		topTitle = "General Partner",
		difficulty = "Very hard: rare seats.",
	},
	re = {
		id = "re",
		name = "Real Estate",
		short = "RE",
		entryTitle = "Analyst",
		topTitle = "Managing Director",
		difficulty = "Medium.",
	},
	corp = {
		id = "corp",
		name = "Corporate Finance",
		short = "Corporate",
		entryTitle = "Financial Analyst",
		topTitle = "Board Member",
		difficulty = "Easy: a walk-on seat is always available.",
	},
}

Tracks.list = {} :: { TrackDef }
Tracks.byId = {} :: { [string]: TrackDef }
Tracks.roles = {} :: { [string]: RoleDef }

for _, id in Tracks.IDS do
	local d = defs[id]
	assert(d ~= nil, "Tracks: missing definition for " .. id)
	local ladder: { RoleDef } = {}
	for i, r in (d.ladder or {}) :: { any } do
		assert(r.rank == i, ("Tracks: %s ladder rank %d out of order"):format(id, i))
		local role: RoleDef = {
			rank = r.rank,
			roleId = r.roleId,
			title = r.title,
			track = id,
			minLevel = r.minLevel,
			maxLevel = r.maxLevel,
			salary = r.salary,
			bonus = r.bonus,
			book = r.book,
			prestige = r.prestige,
			minOvr = r.minOvr or 0,
			coreToPromote = r.coreToPromote,
			schoolGate = r.schoolGate,
			dressLevel = r.dressLevel,
			office = r.office,
		}
		assert(Tracks.roles[role.roleId] == nil, "Tracks: duplicate role id " .. role.roleId)
		Tracks.roles[role.roleId] = role
		table.insert(ladder, role)
	end
	local def: TrackDef = {
		id = id,
		name = d.name,
		short = d.short or d.name,
		available = d.available == true and #ladder > 0,
		entryTitle = d.entryTitle,
		topTitle = d.topTitle,
		difficulty = d.difficulty or "",
		signatureDeal = d.signatureDeal,
		ladder = ladder,
	}
	table.insert(Tracks.list, def)
	Tracks.byId[id] = def
end
Tracks.roles[Tracks.STUDENT.roleId] = Tracks.STUDENT

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
function Tracks.get(id: any): TrackDef?
	if type(id) ~= "string" then
		return nil
	end
	return Tracks.byId[id]
end

function Tracks.isAvailable(id: any): boolean
	local t = Tracks.get(id)
	return t ~= nil and t.available
end

function Tracks.role(roleId: any): RoleDef?
	if type(roleId) ~= "string" then
		return nil
	end
	return Tracks.roles[roleId]
end

-- Rank definition (rank 0 = the student pseudo-role).
function Tracks.rankDef(trackId: any, rank: any): RoleDef?
	if rank == 0 then
		return Tracks.STUDENT
	end
	local t = Tracks.get(trackId)
	if not t or type(rank) ~= "number" then
		return nil
	end
	return t.ladder[rank]
end

function Tracks.topRank(trackId: any): number
	local t = Tracks.get(trackId)
	return if t then #t.ladder else 0
end

-- Outfit level a title requires (v3 §5: min(5, rank + 1) unless the role overrides it).
function Tracks.dressLevelFor(role: RoleDef): number
	if role.dressLevel then
		return role.dressLevel
	end
	return math.min(5, role.rank + 1)
end

function Tracks.tierName(order: number): string
	return Tracks.TIER_NAMES[math.clamp(math.floor(order), 1, #Tracks.TIER_NAMES)]
end

-- Tier order (1..6) of a rarity id; 1 for unknown values.
function Tracks.rarityOrder(rarity: any): number
	if type(rarity) ~= "string" then
		return 1
	end
	return Tracks.RARITY_ORDER[rarity] or 1
end

-- The role whose level band contains `level` on a track (nil for an unknown or unavailable track).
function Tracks.roleForLevel(trackId: any, level: number): RoleDef?
	local t = Tracks.get(trackId)
	if not t or #t.ladder == 0 then
		return nil
	end
	if level < t.ladder[1].minLevel then
		return Tracks.STUDENT
	end
	for _, r in t.ladder do
		if level >= r.minLevel and level <= r.maxLevel then
			return r
		end
	end
	return t.ladder[#t.ladder]
end

Tracks.strings = require(script.Strings)
Tracks.dialogue = require(script.Dialogue)

-- "{key}" substitution over Tracks.strings (unknown keys return the key itself).
function Tracks.text(key: string, vars: { [string]: any }?): string
	local s = Tracks.strings[key]
	if s == nil then
		return key
	end
	if vars then
		local v = vars
		s = string.gsub(s, "{([%w_]+)}", function(name: string): string
			local value = v[name]
			if value == nil then
				return "{" .. name .. "}"
			end
			return tostring(value)
		end)
	end
	return s
end

return Tracks
