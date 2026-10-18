--!strict
-- Logic/LifeRoll: repairing a loaded profile and the public view of it (PURE).
--
--   View.normalize(profile) -> profile                repairs types after load and refreshes derived fields
--   View.publicView(profile, extra?) -> PublicProfile what other players may see (profile card, Stats screen)
--       extra = { userId?, displayName? }; unbuilt profiles show the display name and no school/family/clubs

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.LifeRoll)
local Stats = require(script.Parent.Parent.Stats)
local Apply = require(script.Parent.Apply)

export type PublicProfile = {
	userId: number?,
	displayName: string?,
	built: boolean,
	firstName: string,
	familyName: string,
	fullName: string,
	school: {
		id: string,
		rarity: string,
		name: string,
		short: string,
		initials: string,
		motto: string,
		colors: {
			primary: string,
			secondary: string,
		},
	}?,
	degree: { id: string, name: string, long: string, rarity: string },
	gpa: number,
	family: { id: string, rarity: string, name: string }?,
	clubs: { { id: string, rarity: string, name: string, glyph: string } },
	stats: { [string]: number },
	weekGains: { [string]: number },
	ovr: number,
	archetype: { id: string, name: string, desc: string },
	focus: { id: string, name: string, glyph: string }?,
	perks: { { id: string, name: string, glyph: string, desc: string, count: number } },
	rebirths: number,
	outfit: { name: string, brand: string, rarity: string }?,
}

local View = {}

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
-- Repair after load
---------------------------------------------------------------------------------------------------
local function ensureTable(p: any, key: string)
	if type(p[key]) ~= "table" then
		p[key] = {}
	end
end

function View.normalize(raw: any): any
	local p: any = if type(raw) == "table" then raw else {}
	p.built = p.built == true
	p.firstName = if type(p.firstName) == "string" then p.firstName else ""
	p.familyName = if type(p.familyName) == "string" then p.familyName else ""
	for _, key in { "clubs", "stats", "baseStats", "growth", "statXp", "perks", "perksUsed", "pending" } do
		ensureTable(p, key)
	end
	if type(p.credits) ~= "table" then
		p.credits = {}
	end
	p.credits.reroll = count(p.credits.reroll)
	p.credits.rebuild = count(p.credits.rebuild)
	p.rerollsLeft = count(p.rerollsLeft)
	p.refreshTokens = count(p.refreshTokens)
	p.rebirths = count(p.rebirths)
	p.incomeMult = Apply.incomeMult(p.rebirths)
	p.legacySeat = p.legacySeat == true
	p.startCash = count(p.startCash)
	p.cashPaid = p.cashPaid ~= false
	p.focus = if Config.focusDef(p.focus) then p.focus else ""
	p.focusKey = if type(p.focusKey) == "string" then p.focusKey else ""
	if type(p.weekGrowth) ~= "table" then
		p.weekGrowth = { key = "", gains = {} }
	end
	if type(p.weekGrowth.gains) ~= "table" then
		p.weekGrowth.gains = {}
	end
	if type(p.weekGrowth.key) ~= "string" then
		p.weekGrowth.key = ""
	end
	if p.built then
		if type(p.school) ~= "table" then
			p.school = { id = "", rarity = "common" }
		end
		if type(p.family) ~= "table" then
			p.family = { id = "", rarity = "common" }
		end
		local def = Config.school(p.school.id)
		if def then
			p.school.rarity = def.rarity
		end
		local fam = Config.family(p.family.id)
		if fam then
			p.family.rarity = fam.rarity
			p.familyName = fam.name
		end
		-- a profile without its rolled package (older data): derive it once from the stats it shows
		local complete = true
		for _, id in Config.STAT_IDS do
			if type(p.baseStats[id]) ~= "number" then
				complete = false
			end
		end
		if not complete then
			local boosts = Apply.boosts(p)
			for _, id in Config.STAT_IDS do
				local shown = Stats.clamp(p.stats[id])
				p.baseStats[id] = math.max(1, shown - (boosts[id] or 0) - count(p.growth[id]))
			end
		end
		Apply.recompute(p)
	else
		p.ovr = Stats.ovr(p.stats)
	end
	return p
end

---------------------------------------------------------------------------------------------------
-- Public view
---------------------------------------------------------------------------------------------------
function View.publicView(p: any, extra: { userId: number?, displayName: string? }?): PublicProfile
	local profile = if type(p) == "table" then p else {}
	local built = profile.built == true
	local firstName = if type(profile.firstName) == "string" and profile.firstName ~= ""
		then profile.firstName
		else if extra and extra.displayName then extra.displayName else ""
	local familyName = if built and type(profile.familyName) == "string" then profile.familyName else ""
	local schoolDef = if built and type(profile.school) == "table" then Config.school(profile.school.id) else nil
	local familyDef = if built and type(profile.family) == "table" then Config.family(profile.family.id) else nil
	local degreeDef = Config.degree(profile.degree) or Config.degrees[1]
	local clubs = {}
	if built and type(profile.clubs) == "table" then
		for _, c in profile.clubs do
			local def = Config.club(if type(c) == "table" then c.id else nil)
			if def then
				table.insert(clubs, { id = def.id, rarity = def.rarity, name = def.name, glyph = def.glyph })
			end
		end
	end
	local stats: { [string]: number } = {}
	local src = if type(profile.stats) == "table" then profile.stats else {}
	for _, id in Config.STAT_IDS do
		stats[id] = Stats.clamp(src[id])
	end
	local gains: { [string]: number } = {}
	local wg = profile.weekGrowth
	if type(wg) == "table" and type(wg.gains) == "table" then
		for _, id in Config.STAT_IDS do
			local n = count(wg.gains[id])
			if n > 0 then
				gains[id] = n
			end
		end
	end
	local perks = {}
	if built and type(profile.perks) == "table" then
		for _, def in Config.perks do
			local n = count(profile.perks[def.id])
			if n > 0 then
				table.insert(perks, { id = def.id, name = def.name, glyph = def.glyph, desc = def.desc, count = n })
			end
		end
	end
	local focusDef = Config.focusDef(profile.focus)
	local arche = Stats.archetype(stats)
	local outfit = profile.outfitRoll
	return {
		userId = extra and extra.userId,
		displayName = extra and extra.displayName,
		built = built,
		firstName = firstName,
		familyName = familyName,
		fullName = if familyName ~= "" then firstName .. " " .. familyName else firstName,
		school = if schoolDef
			then {
				id = schoolDef.id,
				rarity = schoolDef.rarity,
				name = schoolDef.name,
				short = schoolDef.short,
				initials = schoolDef.initials,
				motto = schoolDef.motto,
				colors = { primary = schoolDef.colors.primary, secondary = schoolDef.colors.secondary },
			}
			else nil,
		degree = { id = degreeDef.id, name = degreeDef.name, long = degreeDef.long, rarity = degreeDef.rarity },
		gpa = if built then num(profile.gpa, 0) else 0,
		family = if familyDef then { id = familyDef.id, rarity = familyDef.rarity, name = familyDef.name } else nil,
		clubs = clubs,
		stats = stats,
		weekGains = gains,
		ovr = Stats.ovr(stats),
		archetype = { id = arche.id, name = arche.name, desc = arche.desc },
		focus = if focusDef then { id = focusDef.id, name = focusDef.name, glyph = focusDef.glyph } else nil,
		perks = perks,
		rebirths = count(profile.rebirths),
		outfit = if built
				and type(outfit) == "table"
				and type(outfit.name) == "string"
				and outfit.name ~= ""
			then { name = outfit.name, brand = tostring(outfit.brand), rarity = tostring(outfit.rarity) }
			else nil,
	}
end

return View
