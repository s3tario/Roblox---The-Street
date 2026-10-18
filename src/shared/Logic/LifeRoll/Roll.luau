--!strict
-- Logic/LifeRoll: rolling (PURE: no services, no clocks, no Instances). Every random draw comes from the caller's
-- Shared/Util/Rng, so rolls reproduce exactly from a seed in tests.
--
--   Roll.rollField(field, rng, ctx?) -> value      one field ("school" | "degree" | "gpa" | "family" | "clubs" |
--                                                  "stats" | "outfit")
--   Roll.rollAll(rng, ctx?) -> Roll                every field in spin order
--   Roll.rerollField(roll, field, rng, ctx?) -> Roll   a copy with exactly that one field re-rolled
--   Roll.normalize(raw) -> Roll?                   a stored roll repaired (rarities re-read from config), or nil
--   Roll.gpaCdf(x) -> 0..1 / Roll.gpaFromUnit(u)   the GPA triangle (2.70 .. 4.00, mode 3.45)
--   Roll.clubCount(u) -> 1..3
--   Roll.describe(field, value) -> string          display text ("Harvale University", "3.62", ...)
--   Roll.rarityOf(field, value) -> rarity?         the rarity colour of a field's value (clubs: the rarest club)
--   Roll.mythics(roll, fields?) -> { {field, text} }   Mythic results (server-wide banner)
-- ctx = { rebirths: number? } (rebirth luck, Config/Rarity.oddsFor)

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.LifeRoll)
local Rarity = require(Shared.Config.Rarity)
local Catalog = require(Shared.Config.Catalog)
local Rng = require(Shared.Util.Rng)

export type Pick = { id: string, rarity: string }
export type Outfit = { lookId: string, brand: string, rarity: string, itemIds: { string }, name: string }
export type Roll = {
	school: Pick,
	degree: string,
	gpa: number,
	family: Pick,
	clubs: { Pick },
	stats: { [string]: number },
	outfit: Outfit,
}
export type Ctx = { rebirths: number? }

local Roll = {}

local rules = Config.rules

local function rebirthsOf(ctx: Ctx?): number
	return if ctx and type(ctx.rebirths) == "number" then ctx.rebirths else 0
end

---------------------------------------------------------------------------------------------------
-- Tiered pools
---------------------------------------------------------------------------------------------------
-- A tier with options: the rolled tier, or (never with the shipped config) the nearest lower tier that has some.
local function tierWithOptions(kind: string, rarity: string): (string, { any })
	local order = Rarity.order(rarity)
	for o = order, 1, -1 do
		local id = Rarity.byOrder(o).id
		local pool = Config.pool(kind, id)
		if #pool > 0 then
			return id, pool
		end
	end
	return "common", Config.pool(kind, "common")
end

local function pickTiered(kind: string, rng: Rng.Rng, ctx: Ctx?): Pick
	local rarity = Rarity.pick(rng:next(), rebirthsOf(ctx))
	local tier, pool = tierWithOptions(kind, rarity)
	local def = pool[rng:int(1, #pool)]
	return { id = def.id, rarity = tier }
end

---------------------------------------------------------------------------------------------------
-- GPA: triangular on [gpaMin, gpaMax] with mode gpaMode, rounded to 0.01
---------------------------------------------------------------------------------------------------
local A, C, B = rules.gpaMin, rules.gpaMode, rules.gpaMax

function Roll.gpaCdf(x: number): number
	if x <= A then
		return 0
	elseif x <= C then
		return (x - A) ^ 2 / ((B - A) * (C - A))
	elseif x < B then
		return 1 - (B - x) ^ 2 / ((B - A) * (B - C))
	end
	return 1
end

function Roll.gpaFromUnit(u: number): number
	local x = math.clamp(u, 0, 1)
	local fc = (C - A) / (B - A)
	local raw = if x < fc then A + math.sqrt(x * (B - A) * (C - A)) else B - math.sqrt((1 - x) * (B - A) * (B - C))
	return math.clamp(math.floor(raw * 100 + 0.5) / 100, A, B)
end

---------------------------------------------------------------------------------------------------
-- Fields
---------------------------------------------------------------------------------------------------
local function rollDegree(rng: Rng.Rng): string
	local u = rng:next()
	local acc = 0
	for _, d in Config.degrees do
		acc += d.odds
		if u < acc then
			return d.id
		end
	end
	return Config.degrees[#Config.degrees].id
end

function Roll.clubCount(u: number): number
	local acc = 0
	for n, p in rules.clubCountOdds do
		acc += p
		if u < acc then
			return n
		end
	end
	return #rules.clubCountOdds
end

-- 1-3 different clubs. Each club rolls its tier with the Rarity odds; a tier whose clubs are all taken drops out
-- and the remaining tiers keep their relative odds (disclosed in the odds table).
local function rollClubs(rng: Rng.Rng, ctx: Ctx?): { Pick }
	local odds = Rarity.oddsFor(rebirthsOf(ctx))
	local count = Roll.clubCount(rng:next())
	local used: { [string]: boolean } = {}
	local out: { Pick } = {}
	for _ = 1, count do
		local avail: { { id: string, odds: number, free: { any } } } = {}
		local total = 0
		for _, tier in Rarity.list do
			local free = {}
			for _, def in Config.pool("club", tier.id) do
				if not used[def.id] then
					table.insert(free, def)
				end
			end
			if #free > 0 then
				table.insert(avail, { id = tier.id, odds = odds[tier.id], free = free })
				total += odds[tier.id]
			end
		end
		if #avail == 0 or total <= 0 then
			break
		end
		local x = rng:next() * total
		local chosen = avail[#avail]
		for _, a in avail do
			x -= a.odds
			if x < 0 then
				chosen = a
				break
			end
		end
		local def = chosen.free[rng:int(1, #chosen.free)]
		used[def.id] = true
		table.insert(out, { id = def.id, rarity = chosen.id })
	end
	return out
end

-- Eight attributes, each statMin..statMax, summing to statTotal +- statSpread (two dice).
local function rollStats(rng: Rng.Rng): { [string]: number }
	local half = rules.statSpread // 2
	local target = rules.statTotal + rng:int(-half, half) + rng:int(-half, half)
	local values: { [string]: number } = {}
	local sum = 0
	for _, id in Config.STAT_IDS do
		local v = rng:int(rules.statMin, rules.statMax)
		values[id] = v
		sum += v
	end
	local guard = 0
	while sum ~= target and guard < 1000 do
		guard += 1
		local up = sum < target
		local room: { string } = {}
		for _, id in Config.STAT_IDS do
			if (up and values[id] < rules.statMax) or (not up and values[id] > rules.statMin) then
				table.insert(room, id)
			end
		end
		if #room == 0 then
			break
		end
		local id = room[rng:int(1, #room)]
		values[id] += if up then 1 else -1
		sum += if up then 1 else -1
	end
	return values
end

local function lookToOutfit(look: Catalog.Look, rarity: string): Outfit
	return {
		lookId = look.id,
		brand = look.brand,
		rarity = if Rarity.get(look.rarity) then look.rarity else rarity,
		itemIds = table.clone(look.itemIds),
		name = look.name,
	}
end

local function rollOutfit(rng: Rng.Rng, ctx: Ctx?): Outfit
	local rarity = Rarity.pick(rng:next(), rebirthsOf(ctx))
	local u = rng:next()
	for o = Rarity.order(rarity), 1, -1 do
		local id = Rarity.byOrder(o).id
		local look = Catalog.pickLook(id, u)
		if look then
			return lookToOutfit(look, id)
		end
	end
	return { lookId = "", brand = "", rarity = "common", itemIds = {}, name = "" }
end

function Roll.rollField(field: string, rng: Rng.Rng, ctx: Ctx?): any
	if field == "school" then
		return pickTiered("school", rng, ctx)
	elseif field == "family" then
		return pickTiered("family", rng, ctx)
	elseif field == "degree" then
		return rollDegree(rng)
	elseif field == "gpa" then
		return Roll.gpaFromUnit(rng:next())
	elseif field == "clubs" then
		return rollClubs(rng, ctx)
	elseif field == "stats" then
		return rollStats(rng)
	elseif field == "outfit" then
		return rollOutfit(rng, ctx)
	end
	error("LifeRoll: unknown field " .. tostring(field))
end

function Roll.rollAll(rng: Rng.Rng, ctx: Ctx?): Roll
	local out: { [string]: any } = {}
	for _, field in Config.FIELDS do
		out[field] = Roll.rollField(field, rng, ctx)
	end
	return (out :: any) :: Roll
end

local function copyRoll(roll: Roll): Roll
	local clubs: { Pick } = {}
	for _, c in roll.clubs do
		table.insert(clubs, { id = c.id, rarity = c.rarity })
	end
	return {
		school = { id = roll.school.id, rarity = roll.school.rarity },
		degree = roll.degree,
		gpa = roll.gpa,
		family = { id = roll.family.id, rarity = roll.family.rarity },
		clubs = clubs,
		stats = table.clone(roll.stats),
		outfit = {
			lookId = roll.outfit.lookId,
			brand = roll.outfit.brand,
			rarity = roll.outfit.rarity,
			itemIds = table.clone(roll.outfit.itemIds),
			name = roll.outfit.name,
		},
	}
end
Roll.copy = copyRoll

function Roll.rerollField(roll: Roll, field: string, rng: Rng.Rng, ctx: Ctx?): Roll
	assert(Config.FIELD_SET[field], "LifeRoll: unknown field " .. tostring(field))
	local out = copyRoll(roll);
	(out :: any)[field] = Roll.rollField(field, rng, ctx)
	return out
end

---------------------------------------------------------------------------------------------------
-- Validation (stored rolls come back from the DataStore)
---------------------------------------------------------------------------------------------------
local function pickOf(kind: string, raw: any): Pick?
	if type(raw) ~= "table" then
		return nil
	end
	local def: any = if kind == "school"
		then Config.school(raw.id)
		elseif kind == "family" then Config.family(raw.id)
		else Config.club(raw.id)
	if not def then
		return nil
	end
	return { id = def.id, rarity = def.rarity }
end

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Roll.normalize(raw: any): Roll?
	if type(raw) ~= "table" then
		return nil
	end
	local school = pickOf("school", raw.school)
	local family = pickOf("family", raw.family)
	local degree = if Config.degree(raw.degree) then raw.degree :: string else nil
	local gpa = if finite(raw.gpa) and raw.gpa >= A - 1e-9 and raw.gpa <= B + 1e-9 then raw.gpa :: number else nil
	if not school or not family or not degree or not gpa then
		return nil
	end
	local clubs: { Pick } = {}
	local seen: { [string]: boolean } = {}
	if type(raw.clubs) ~= "table" then
		return nil
	end
	for _, c in raw.clubs do
		local p = pickOf("club", c)
		if not p or seen[p.id] then
			return nil
		end
		seen[p.id] = true
		table.insert(clubs, p)
	end
	if #clubs < 1 or #clubs > #rules.clubCountOdds then
		return nil
	end
	if type(raw.stats) ~= "table" then
		return nil
	end
	local stats: { [string]: number } = {}
	for _, id in Config.STAT_IDS do
		local v = raw.stats[id]
		if not finite(v) or v < rules.statMin or v > rules.statMax then
			return nil
		end
		stats[id] = math.floor(v)
	end
	local o = raw.outfit
	if type(o) ~= "table" or type(o.lookId) ~= "string" then
		return nil
	end
	local look = Catalog.looks[Catalog.canonical(o.lookId)]
	if not look then
		return nil
	end
	return {
		school = school,
		degree = degree,
		gpa = gpa,
		family = family,
		clubs = clubs,
		stats = stats,
		outfit = lookToOutfit(look, if type(o.rarity) == "string" then o.rarity else "common"),
	}
end

---------------------------------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------------------------------
function Roll.describe(field: string, value: any): string
	if field == "school" then
		local def = Config.school(if type(value) == "table" then value.id else nil)
		return if def then def.name else ""
	elseif field == "family" then
		local def = Config.family(if type(value) == "table" then value.id else nil)
		return if def then def.name else ""
	elseif field == "degree" then
		local def = Config.degree(value)
		return if def then def.name else ""
	elseif field == "gpa" then
		return if finite(value) then string.format("%.2f", value) else ""
	elseif field == "clubs" then
		local names: { string } = {}
		if type(value) == "table" then
			for _, c in value do
				local def = Config.club(if type(c) == "table" then c.id else nil)
				if def then
					table.insert(names, def.name)
				end
			end
		end
		return table.concat(names, ", ")
	elseif field == "stats" then
		local total = 0
		if type(value) == "table" then
			for _, id in Config.STAT_IDS do
				total += if finite(value[id]) then value[id] else 0
			end
		end
		return tostring(math.floor(total))
	elseif field == "outfit" then
		return if type(value) == "table" and type(value.name) == "string" then value.name else ""
	end
	return ""
end

function Roll.rarityOf(field: string, value: any): string?
	if field == "degree" then
		local def = Config.degree(value)
		return if def then def.rarity else nil
	end
	if type(value) ~= "table" then
		return nil
	end
	if field == "school" or field == "family" or field == "outfit" then
		return if Rarity.get(value.rarity) then value.rarity else nil
	elseif field == "clubs" then
		local best: string? = nil
		for _, c in value do
			if
				type(c) == "table"
				and Rarity.get(c.rarity)
				and (best == nil or Rarity.order(c.rarity) > Rarity.order(best))
			then
				best = c.rarity
			end
		end
		return best
	end
	return nil
end

-- Mythic results among `fields` (default: every field), for the server-wide banner.
function Roll.mythics(roll: Roll, fields: { string }?): { { field: string, text: string } }
	local out: { { field: string, text: string } } = {}
	for _, field in fields or Config.FIELDS do
		local value = (roll :: any)[field]
		if field == "clubs" then
			for _, c in roll.clubs do
				if c.rarity == "mythic" then
					local def = Config.club(c.id)
					table.insert(out, { field = "clubs" :: string, text = if def then def.name else c.id })
				end
			end
		elseif Roll.rarityOf(field, value) == "mythic" then
			table.insert(out, { field = field, text = Roll.describe(field, value) })
		end
	end
	return out
end

return Roll
