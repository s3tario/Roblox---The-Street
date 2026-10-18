--!strict
-- Config/LifeRoll (owned by `careerCore`; design v3 §1-§3, contracts §4 and §16). Pure data plus lookups: safe on
-- the server, the client, in builders (Logos reads `schools`) and in Lune.
--
--   LifeRoll.FIELDS                  { "school", "degree", "gpa", "family", "clubs", "stats", "outfit" } (spin order)
--   LifeRoll.schools / families / clubs / perks   lists (Schools.luau, Families.luau, Clubs.luau, Perks.luau)
--   LifeRoll.degrees                 { {id = "bs"|"ms", name, long, odds, rarity, boosts, offerBonus} }
--   LifeRoll.stats / archetypes / focus           Traits.luau (attributes, archetype per top-two pair, focus areas)
--   LifeRoll.rules                   roll ranges, GPA triangle, club count odds, rerolls, name rules, stat caps
--   LifeRoll.SPIN                    reel timing shared by the client animation and the server's Mythic banner
--   LifeRoll.school(id) / family(id) / club(id) / perk(id) / degree(id) / stat(id) / focusDef(id) -> def?
--   LifeRoll.pool(kind, rarity) -> { def }        options of one tier ("school" | "family" | "club")
--   LifeRoll.archetypeFor(statA, statB) -> def?   the archetype of a pair of stat ids (any order)
--   LifeRoll.revealDelay(index) -> seconds        when the reel of field #index lands, from the spin start
--   LifeRoll.text(key, vars?) -> string           Strings.luau with {placeholders} filled
--   LifeRoll.err(key) -> string                   the error text for an error key (err_<key>, generic fallback)

local Schools = require(script.Schools)
local Families = require(script.Families)
local Clubs = require(script.Clubs)
local Perks = require(script.Perks)
local Traits = require(script.Traits)
local Strings = require(script.Strings)

export type SchoolDef = Schools.SchoolDef
export type FamilyDef = Families.FamilyDef
export type ClubDef = Clubs.ClubDef
export type PerkDef = Perks.PerkDef
export type StatDef = Traits.StatDef
export type ArchetypeDef = Traits.ArchetypeDef
export type FocusDef = Traits.FocusDef
export type DegreeDef = {
	id: string,
	name: string,
	long: string,
	odds: number,
	rarity: string,
	boosts: { [string]: number },
	offerBonus: number,
}

local LifeRoll = {}

LifeRoll.FIELDS = { "school", "degree", "gpa", "family", "clubs", "stats", "outfit" }
LifeRoll.FIELD_SET = {} :: { [string]: boolean }
for _, f in LifeRoll.FIELDS do
	LifeRoll.FIELD_SET[f] = true
end

LifeRoll.schools = Schools
LifeRoll.families = Families.list
LifeRoll.familyTiers = Families.tiers
LifeRoll.clubs = Clubs
LifeRoll.perks = Perks
LifeRoll.stats = Traits.stats
LifeRoll.archetypes = Traits.archetypes
LifeRoll.focus = Traits.focus
LifeRoll.strings = Strings

LifeRoll.degrees = {
	{
		id = "bs",
		name = "B.S.",
		long = "Bachelor of Science in Finance",
		odds = 0.8,
		rarity = "common",
		boosts = {},
		offerBonus = 0,
	},
	{
		id = "ms",
		name = "Master's",
		long = "Master of Science in Finance",
		odds = 0.2,
		rarity = "uncommon",
		boosts = { knowledge = 5 },
		offerBonus = 0.03,
	},
} :: { DegreeDef }

LifeRoll.rules = {
	statMin = 25, -- each rolled attribute
	statMax = 55,
	statTotal = 320, -- the package always sums to statTotal +- statSpread (two dice of +-8)
	statSpread = 16,
	statFloor = 1, -- attributes after boosts and growth
	statCap = 99,
	gpaMin = 2.70,
	gpaMode = 3.45,
	gpaMax = 4.00,
	clubCountOdds = { 0.35, 0.40, 0.25 }, -- 1, 2 or 3 clubs
	rerolls = 3, -- free single-field rerolls per Life Roll
	legacyBonus = 1, -- extra rerolls with the Legacy Seat (from an earlier life)
	nameMin = 2,
	nameMax = 16,
	nameFallback = "Rookie",
	incomeStep = 0.1, -- rebirth income multiplier per rebirth (M4)
	incomeCap = 3.0,
}

-- Client reel animation timing (seconds). The server delays the Mythic banner until the reel lands.
LifeRoll.SPIN = {
	duration = 1.7, -- one reel from fast scroll to landing
	stagger = 0.6, -- next reel lands this much later during the first spin
	reroll = 1.9, -- a single reroll reel
	flash = 0.45, -- rarity colour flash after landing
}

function LifeRoll.revealDelay(index: number): number
	return LifeRoll.SPIN.duration + (math.max(1, index) - 1) * LifeRoll.SPIN.stagger
end

---------------------------------------------------------------------------------------------------
-- Lookups
---------------------------------------------------------------------------------------------------
local function index<T>(list: { T }): { [string]: T }
	local out: { [string]: T } = {}
	for _, d in list do
		out[(d :: any).id] = d
	end
	return out
end

local schoolById = index(Schools)
local familyById = index(Families.list)
local clubById = index(Clubs)
local perkById = index(Perks)
local degreeById = index(LifeRoll.degrees)
local statById = index(Traits.stats)
local focusById = index(Traits.focus)

LifeRoll.schoolById = schoolById
LifeRoll.familyById = familyById
LifeRoll.clubById = clubById
LifeRoll.perkById = perkById

LifeRoll.STAT_IDS = {} :: { string }
LifeRoll.STAT_ORDER = {} :: { [string]: number }
for i, d in Traits.stats do
	table.insert(LifeRoll.STAT_IDS, d.id)
	LifeRoll.STAT_ORDER[d.id] = i
end

local function lookup<T>(map: { [string]: T }, id: any): T?
	if type(id) ~= "string" then
		return nil
	end
	return map[id]
end

function LifeRoll.school(id: any): SchoolDef?
	return lookup(schoolById, id)
end

function LifeRoll.family(id: any): FamilyDef?
	return lookup(familyById, id)
end

function LifeRoll.club(id: any): ClubDef?
	return lookup(clubById, id)
end

function LifeRoll.perk(id: any): PerkDef?
	return lookup(perkById, id)
end

function LifeRoll.degree(id: any): DegreeDef?
	return lookup(degreeById, id)
end

function LifeRoll.stat(id: any): StatDef?
	return lookup(statById, id)
end

function LifeRoll.focusDef(id: any): FocusDef?
	return lookup(focusById, id)
end

local pools: { [string]: { [string]: { any } } } = { school = {}, family = {}, club = {} }
local function addPool(kind: string, list: { any })
	local byTier = pools[kind]
	for _, d in list do
		local tier = byTier[d.rarity]
		if not tier then
			tier = {}
			byTier[d.rarity] = tier
		end
		table.insert(tier, d)
	end
end
addPool("school", Schools)
addPool("family", Families.list)
addPool("club", Clubs)

-- Options of one rarity tier, in config order (empty for unknown kinds or tiers).
function LifeRoll.pool(kind: string, rarity: string): { any }
	local byTier = pools[kind]
	return if byTier and byTier[rarity] then byTier[rarity] else {}
end

function LifeRoll.archetypeFor(a: string, b: string): ArchetypeDef?
	local oa, ob = LifeRoll.STAT_ORDER[a], LifeRoll.STAT_ORDER[b]
	if not oa or not ob or a == b then
		return nil
	end
	local key = if oa < ob then a .. "|" .. b else b .. "|" .. a
	return Traits.archetypes[key]
end

---------------------------------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------------------------------
function LifeRoll.text(key: string, vars: { [string]: any }?): string
	local template = Strings[key]
	if template == nil then
		return key
	end
	if not vars then
		return template
	end
	local values: { [string]: any } = vars
	return (
		string.gsub(template, "{(%w+)}", function(name: string): string
			local v = values[name]
			if v == nil then
				return "{" .. name .. "}"
			end
			return tostring(v)
		end)
	)
end

function LifeRoll.err(key: any): string
	local k = if type(key) == "string" then "err_" .. key else "err_generic"
	if Strings[k] then
		return Strings[k]
	end
	return Strings.err_generic
end

return LifeRoll
