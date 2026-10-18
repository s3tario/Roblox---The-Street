--!strict
-- Logic/LifeRoll: what a roll means for the profile (PURE). Every function works on the `profile` table
-- (Config/DataTemplate/Profile) and mutates it in place where it says so.
--
-- Boosts and perks
--   Apply.boostSources(fields) -> { {source, id, stat, amount} }   school/club tier boosts, degree, family network
--   Apply.boosts(fields) -> { [statId] = n }
--   Apply.perks(fields) -> { [perkId] = count }   Legendary+ schools and clubs only
--   Apply.finalStats(base, boosts, growth?) -> stats (1..99)
--   (`fields` is a Roll or a locked profile: both carry school, degree, family, clubs)
-- Life Roll flow
--   Apply.validName(raw) -> (name?, errKey?)        2-16 letters (plus inner ' - and single spaces)
--   Apply.startRoll(profile, rng, ctx?) -> boolean  rolls every field into profile.pending (new Life Roll only)
--   Apply.rerollSource(profile) -> "free" | "token" | "credit" | nil   in that order
--   Apply.reroll(profile, field, rng, ctx?) -> (ok, errKey?, source?, value?)   one field of the pending roll
--   Apply.lock(profile, now) -> (LockResult?, errKey?)
-- After lock-in
--   Apply.recompute(profile)                         stats = base + boosts + growth, perks, ovr, archetype
--   Apply.hasPerk(profile, id) / Apply.consumePerk(profile, id) -> boolean
--   Apply.schoolTierOrder(profile) -> 1..6           rarity order, +1 with Boardroom Pedigree (capped at 6)
--   Apply.incomeMult(rebirths) -> 1 + 0.1 x rebirths (capped at 3.0)
--   Apply.weekKey(careerWeek, activeSeconds) -> string   "w12" once employed, "c3" on campus (40 active min)
--   Apply.setFocus(profile, focusId, weekKey) -> (ok, errKey?)
--   Apply.rebuildOptions(profile) -> { school = {id}, family = {id}, clubs = { {id} } }   same-rarity choices
--   Apply.rebuild(profile, edits) -> (ok, errKey?)   edits = { school = id?, family = id?, clubs = { [i] = id }? }
-- (load repair and the public view live in View.luau)

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.LifeRoll)
local Rarity = require(Shared.Config.Rarity)
local Time = require(Shared.Util.Time)
local Rng = require(Shared.Util.Rng)
local Stats = require(script.Parent.Parent.Stats)
local Roll = require(script.Parent.Roll)

export type BoostSource = { source: string, id: string, stat: string, amount: number }
export type LockResult = {
	startCash: number,
	heirloom: string?,
	lookId: string,
	itemIds: { string },
	mythics: { { field: string, text: string } },
}

local Apply = {}

local rules = Config.rules

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

local function count(x: any): number
	return math.max(0, math.floor(num(x, 0)))
end

---------------------------------------------------------------------------------------------------
-- Boosts and perks
---------------------------------------------------------------------------------------------------
local function tierBoosts(out: { BoostSource }, source: string, def: any)
	local amounts = Rarity.boostAmounts[def.rarity] or {}
	for i, stat in def.boosts do
		local amount = amounts[i]
		if amount and amount > 0 and Config.stat(stat) then
			table.insert(out, { source = source, id = def.id, stat = stat, amount = amount })
		end
	end
end

function Apply.boostSources(fields: any): { BoostSource }
	local out: { BoostSource } = {}
	if type(fields) ~= "table" then
		return out
	end
	local school = Config.school(if type(fields.school) == "table" then fields.school.id else nil)
	if school then
		tierBoosts(out, "school", school)
	end
	if type(fields.clubs) == "table" then
		for _, c in fields.clubs do
			local club = Config.club(if type(c) == "table" then c.id else nil)
			if club then
				tierBoosts(out, "club", club)
			end
		end
	end
	local degree = Config.degree(fields.degree)
	if degree then
		for _, stat in Config.STAT_IDS do
			local amount = degree.boosts[stat]
			if amount and amount > 0 then
				table.insert(out, { source = "degree", id = degree.id, stat = stat, amount = amount })
			end
		end
	end
	local family = Config.family(if type(fields.family) == "table" then fields.family.id else nil)
	if family and family.network > 0 then
		table.insert(out, { source = "family", id = family.id, stat = "network", amount = family.network })
	end
	return out
end

function Apply.boosts(fields: any): { [string]: number }
	local out: { [string]: number } = {}
	for _, b in Apply.boostSources(fields) do
		out[b.stat] = (out[b.stat] or 0) + b.amount
	end
	return out
end

function Apply.perks(fields: any): { [string]: number }
	local out: { [string]: number } = {}
	if type(fields) ~= "table" then
		return out
	end
	local defs: { any } = {}
	local school = Config.school(if type(fields.school) == "table" then fields.school.id else nil)
	if school then
		table.insert(defs, school)
	end
	if type(fields.clubs) == "table" then
		for _, c in fields.clubs do
			local club = Config.club(if type(c) == "table" then c.id else nil)
			if club then
				table.insert(defs, club)
			end
		end
	end
	for _, def in defs do
		if Rarity.carriesPerk(def.rarity) then
			for _, perkId in def.perks do
				local perk = Config.perk(perkId)
				if perk then
					out[perkId] = if perk.stacks then (out[perkId] or 0) + 1 else 1
				end
			end
		end
	end
	return out
end

function Apply.finalStats(base: any, boosts: { [string]: number }, growth: any): { [string]: number }
	local out: { [string]: number } = {}
	local b = if type(base) == "table" then base else {}
	local g = if type(growth) == "table" then growth else {}
	for _, id in Config.STAT_IDS do
		out[id] = Stats.clamp(num(b[id], 40) + (boosts[id] or 0) + count(g[id]))
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Life Roll flow
---------------------------------------------------------------------------------------------------
function Apply.validName(raw: any): (string?, string?)
	if type(raw) ~= "string" then
		return nil, "bad_name"
	end
	local s = string.gsub(raw, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	s = string.gsub(s, "%s+", " ")
	if #s == 0 then
		return nil, "no_name"
	end
	if #s < rules.nameMin or #s > rules.nameMax then
		return nil, "bad_name"
	end
	if not string.find(s, "^%a[%a' %-]*%a$") or string.find(s, "[' %-][' %-]") then
		return nil, "bad_name"
	end
	return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2), nil
end

function Apply.hasPending(p: any): boolean
	return type(p) == "table" and Roll.normalize(p.pending) ~= nil
end

function Apply.startRoll(p: any, rng: Rng.Rng, ctx: Roll.Ctx?): boolean
	if p.built == true or Apply.hasPending(p) then
		return false
	end
	p.pending = Roll.rollAll(rng, ctx)
	p.rerollsLeft = rules.rerolls + (if p.legacySeat == true then rules.legacyBonus else 0)
	return true
end

function Apply.rerollSource(p: any): string?
	if count(p.rerollsLeft) > 0 then
		return "free"
	elseif count(p.refreshTokens) > 0 then
		return "token"
	elseif type(p.credits) == "table" and count(p.credits.reroll) > 0 then
		return "credit"
	end
	return nil
end

local function spend(p: any, source: string)
	if source == "free" then
		p.rerollsLeft = count(p.rerollsLeft) - 1
	elseif source == "token" then
		p.refreshTokens = count(p.refreshTokens) - 1
	elseif source == "credit" then
		p.credits.reroll = count(p.credits.reroll) - 1
	end
end

function Apply.reroll(p: any, field: any, rng: Rng.Rng, ctx: Roll.Ctx?): (boolean, string?, string?, any)
	if p.built == true then
		return false, "already_built", nil, nil
	end
	if type(field) ~= "string" or not Config.FIELD_SET[field] then
		return false, "bad_field", nil, nil
	end
	local roll = Roll.normalize(p.pending)
	if not roll then
		return false, "no_roll", nil, nil
	end
	local source = Apply.rerollSource(p)
	if not source then
		return false, "needs_purchase", nil, nil
	end
	spend(p, source)
	local fresh = Roll.rerollField(roll, field, rng, ctx)
	p.pending = fresh
	return true, nil, source, (fresh :: any)[field]
end

function Apply.lock(p: any, now: number): (LockResult?, string?)
	if p.built == true then
		return nil, "already_built"
	end
	local roll = Roll.normalize(p.pending)
	if not roll then
		return nil, "no_roll"
	end
	if not Apply.validName(p.firstName) then
		return nil, "no_name"
	end
	local family = Config.family(roll.family.id) :: Config.FamilyDef
	p.school = { id = roll.school.id, rarity = roll.school.rarity }
	p.degree = roll.degree
	p.gpa = roll.gpa
	p.family = { id = roll.family.id, rarity = roll.family.rarity }
	p.familyName = family.name
	local clubs = {}
	for _, c in roll.clubs do
		table.insert(clubs, { id = c.id, rarity = c.rarity })
	end
	p.clubs = clubs
	p.baseStats = table.clone(roll.stats)
	p.growth = {}
	p.statXp = {}
	p.weekGrowth = { key = "", gains = {} }
	p.perksUsed = {}
	p.focus = ""
	p.focusKey = ""
	p.outfitRoll = {
		lookId = roll.outfit.lookId,
		brand = roll.outfit.brand,
		rarity = roll.outfit.rarity,
		itemIds = table.clone(roll.outfit.itemIds),
		name = roll.outfit.name,
	}
	p.built = true
	p.lockedAt = now
	p.pending = {}
	p.rerollsLeft = 0
	p.startCash = family.cash
	p.cashPaid = family.cash <= 0
	Apply.recompute(p)
	return {
		startCash = family.cash,
		heirloom = family.heirloom,
		lookId = roll.outfit.lookId,
		itemIds = table.clone(roll.outfit.itemIds),
		mythics = Roll.mythics(roll),
	},
		nil
end

---------------------------------------------------------------------------------------------------
-- After lock-in
---------------------------------------------------------------------------------------------------
function Apply.recompute(p: any)
	if type(p.baseStats) ~= "table" then
		p.baseStats = {}
	end
	if type(p.growth) ~= "table" then
		p.growth = {}
	end
	if type(p.perksUsed) ~= "table" then
		p.perksUsed = {}
	end
	p.stats = Apply.finalStats(p.baseStats, Apply.boosts(p), p.growth)
	local perks: { [string]: number } = {}
	for perkId, n in Apply.perks(p) do
		local left = n - count(p.perksUsed[perkId])
		if left > 0 then
			perks[perkId] = left
		end
	end
	p.perks = perks
	if perks.legacy_seat then
		p.legacySeat = true
	end
	p.ovr = Stats.ovr(p.stats)
	p.archetype = Stats.archetype(p.stats).id
end

function Apply.hasPerk(p: any, perkId: any): boolean
	if type(p) ~= "table" or p.built ~= true or type(p.perks) ~= "table" or type(perkId) ~= "string" then
		return false
	end
	return count(p.perks[perkId]) > 0
end

function Apply.consumePerk(p: any, perkId: any): boolean
	if not Apply.hasPerk(p, perkId) then
		return false
	end
	local left = count(p.perks[perkId]) - 1
	p.perks[perkId] = if left > 0 then left else nil
	if type(p.perksUsed) ~= "table" then
		p.perksUsed = {}
	end
	p.perksUsed[perkId] = count(p.perksUsed[perkId]) + 1
	return true
end

function Apply.schoolTierOrder(p: any): number
	if type(p) ~= "table" or p.built ~= true or type(p.school) ~= "table" then
		return 1
	end
	local def = Config.school(p.school.id)
	local order = Rarity.order(if def then def.rarity else p.school.rarity)
	if Apply.hasPerk(p, "boardroom_pedigree") then
		order += 1
	end
	return math.clamp(order, 1, #Rarity.list)
end

function Apply.incomeMult(rebirths: any): number
	return math.min(rules.incomeCap, 1 + rules.incomeStep * count(rebirths))
end

function Apply.weekKey(careerWeek: any, activeSeconds: any): string
	local w = count(careerWeek)
	if w >= 1 then
		return "w" .. w
	end
	return "c" .. math.floor(count(activeSeconds) / Time.REVIEW_WINDOW)
end

function Apply.setFocus(p: any, focusId: any, weekKey: string): (boolean, string?)
	if p.built ~= true then
		return false, "not_built"
	end
	local def = Config.focusDef(focusId)
	if not def then
		return false, "bad_focus"
	end
	if p.focus == def.id then
		return true, nil
	end
	local current = Config.focusDef(p.focus)
	if current and p.focusKey == weekKey then
		return false, "focus_locked"
	end
	-- the first pick is free; every change after it uses this week's change
	p.focusKey = if current then weekKey else ""
	p.focus = def.id
	return true, nil
end

function Apply.canChangeFocus(p: any, weekKey: string): boolean
	if type(p) ~= "table" or p.built ~= true then
		return false
	end
	return Config.focusDef(p.focus) == nil or p.focusKey ~= weekKey
end

local function idsOf(list: { any }, except: { [string]: boolean }?): { string }
	local out: { string } = {}
	for _, def in list do
		if not (except and except[def.id]) then
			table.insert(out, def.id)
		end
	end
	return out
end

function Apply.rebuildOptions(p: any): { school: { string }, family: { string }, clubs: { { string } } }
	local out = { school = {}, family = {}, clubs = {} }
	if type(p) ~= "table" or p.built ~= true then
		return out
	end
	local school = Config.school(if type(p.school) == "table" then p.school.id else nil)
	if school then
		out.school = idsOf(Config.pool("school", school.rarity))
	end
	local family = Config.family(if type(p.family) == "table" then p.family.id else nil)
	if family then
		out.family = idsOf(Config.pool("family", family.rarity))
	end
	if type(p.clubs) == "table" then
		for i, c in p.clubs do
			local club = Config.club(if type(c) == "table" then c.id else nil)
			local others: { [string]: boolean } = {}
			for j, o in p.clubs do
				if j ~= i and type(o) == "table" and type(o.id) == "string" then
					others[o.id] = true
				end
			end
			out.clubs[i] = if club then idsOf(Config.pool("club", club.rarity), others) else {}
		end
	end
	return out
end

function Apply.rebuild(p: any, edits: any): (boolean, string?)
	if p.built ~= true then
		return false, "not_built"
	end
	if type(edits) ~= "table" then
		return false, "bad_rebuild"
	end
	local options = Apply.rebuildOptions(p)
	local school = p.school.id
	local family = p.family.id
	local clubs: { string } = {}
	for _, c in p.clubs do
		table.insert(clubs, c.id)
	end
	if edits.school ~= nil then
		if not table.find(options.school, edits.school) then
			return false, "bad_rebuild"
		end
		school = edits.school
	end
	if edits.family ~= nil then
		if not table.find(options.family, edits.family) then
			return false, "bad_rebuild"
		end
		family = edits.family
	end
	if edits.clubs ~= nil then
		if type(edits.clubs) ~= "table" then
			return false, "bad_rebuild"
		end
		for key, id in edits.clubs do
			local i = tonumber(key)
			if not i or not clubs[i] or not options.clubs[i] or not table.find(options.clubs[i], id) then
				return false, "bad_rebuild"
			end
			clubs[i] = id
		end
		local seen: { [string]: boolean } = {}
		for _, id in clubs do
			if seen[id] then
				return false, "bad_rebuild"
			end
			seen[id] = true
		end
	end
	local changed = school ~= p.school.id or family ~= p.family.id
	for i, id in clubs do
		changed = changed or id ~= p.clubs[i].id
	end
	if not changed then
		return false, "no_change"
	end
	local sd = Config.school(school) :: Config.SchoolDef
	local fd = Config.family(family) :: Config.FamilyDef
	p.school = { id = sd.id, rarity = sd.rarity }
	p.family = { id = fd.id, rarity = fd.rarity }
	p.familyName = fd.name
	local newClubs = {}
	for _, id in clubs do
		local cd = Config.club(id) :: Config.ClubDef
		table.insert(newClubs, { id = cd.id, rarity = cd.rarity })
	end
	p.clubs = newClubs
	Apply.recompute(p)
	return true, nil
end

return Apply
