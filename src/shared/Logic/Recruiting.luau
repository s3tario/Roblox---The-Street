--!strict
-- Recruiting rules (owned by `careerPath`; spec v2 §4b, design v3 §2-§4). PURE: no services, no clocks.
-- The tutorial's Recruiting Board and the M3 email offers use these to decide who may apply and how likely an
-- offer is; CareerService:GrantOffer then records the offer.
--
--   Recruiting.candidate(profile?) -> Candidate        { schoolTier, gpa, degree, stats, familyRarity, perks }
--       profile = the careerCore profile (contracts §3) or an already-built Candidate
--   Recruiting.eligibility(profile, company, trackId?) -> (ok, reasons)   reasons = { string } when not eligible
--   Recruiting.eligible(profile, trackId?) -> { { company, ok, reasons } }  every company hiring for a track
--   Recruiting.offerChance(profile, company, interviewQuality, mods?, trackId?) -> (chance 0..1, Breakdown)
--       mods = { offerBonus?, connections?, interviewBonus? }  (events: Hiring Spree offerBonus 0.15,
--              Recruiting Fair interviewBonus; M3 connections)
--   Recruiting.walkOn(company, interviewQuality, trackId?) -> boolean   Sterling & Vance's always-open seat
--   Recruiting.decide(chance, u) -> boolean            u in [0, 1) from the caller's Rng/Hash
--
-- Offer odds rise monotonically with interview quality: a logistic curve around the firm's bar scales the firm's
-- base odds (school and GPA shift it), plus additive edges from family connections, the Ivy Network perk, a
-- Master's degree, the Network stat and event/connection bonuses. Odds never exceed 95% (walk-ons are 100%).

local Tracks = require(script.Parent.Parent.Config.Tracks)

export type Candidate = {
	schoolTier: number,
	gpa: number,
	degree: string,
	stats: { [string]: number },
	familyRarity: string,
	perks: { [string]: any },
}
export type Mods = { offerBonus: number?, connections: number?, interviewBonus: number? }
export type Breakdown = {
	eligible: boolean,
	walkOn: boolean,
	quality: number,
	bar: number,
	base: number,
	curve: number,
	edge: number,
	bonus: number,
}

local Recruiting = {}

Recruiting.MAX_CHANCE = 0.95
Recruiting.CURVE_WIDTH = 8
-- Family connections (spec v2 §4 table; Epic sits between Rare and Legendary).
Recruiting.FAMILY_BONUS =
	{ common = 0, uncommon = 0.03, rare = 0.06, epic = 0.08, legendary = 0.10, mythic = 0.15 } :: {
		[string]: number,
	}
Recruiting.IVY_BONUS = 0.08
Recruiting.MASTERS_BONUS = 0.03

local STAT_NAMES: { [string]: string } = {
	knowledge = "Knowledge",
	skill = "Skill",
	speed = "Speed",
	charisma = "Charisma",
	network = "Network",
	discipline = "Discipline",
	risk = "Risk Sense",
	luck = "Luck",
}

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function Recruiting.candidate(profile: any): Candidate
	local p = if type(profile) == "table" then profile else {}
	if type(p.schoolTier) == "number" then
		return {
			schoolTier = math.clamp(math.floor(p.schoolTier), 1, 6),
			gpa = num(p.gpa, 3.0),
			degree = if p.degree == "ms" then "ms" else "bs",
			stats = if type(p.stats) == "table" then p.stats else {},
			familyRarity = if type(p.familyRarity) == "string" then p.familyRarity else "common",
			perks = if type(p.perks) == "table" then p.perks else {},
		}
	end
	local school = p.school
	local family = p.family
	return {
		schoolTier = Tracks.rarityOrder(if type(school) == "table" then school.rarity else nil),
		gpa = num(p.gpa, 3.0),
		degree = if p.degree == "ms" then "ms" else "bs",
		stats = if type(p.stats) == "table" then p.stats else {},
		familyRarity = if type(family) == "table" and type(family.rarity) == "string" then family.rarity else "common",
		perks = if type(p.perks) == "table" then p.perks else {},
	}
end

local function hasPerk(c: Candidate, perkId: string): boolean
	local v = c.perks[perkId]
	return v == true or (type(v) == "number" and v > 0)
end

local function hiringFor(company: any, trackId: string?): any
	if type(company) ~= "table" or company.available == false then
		return nil
	end
	local track = trackId or "ib"
	if type(company.departments) ~= "table" or not table.find(company.departments, track) then
		return nil
	end
	return if type(company.hiring) == "table" then company.hiring[track] else nil
end

local function passes(c: Candidate, crit: any): boolean
	if type(crit) ~= "table" then
		return true
	end
	if type(crit.schoolTier) == "number" and c.schoolTier < crit.schoolTier then
		return false
	end
	if type(crit.gpa) == "number" and c.gpa + 1e-9 < crit.gpa then
		return false
	end
	if type(crit.degree) == "string" and c.degree ~= crit.degree then
		return false
	end
	if type(crit.stats) == "table" then
		for statId, min in crit.stats do
			if num(c.stats[statId], 0) < num(min, 0) then
				return false
			end
		end
	end
	return true
end

local function describe(crit: any): string
	local parts: { string } = {}
	if type(crit) ~= "table" then
		return ""
	end
	if type(crit.schoolTier) == "number" then
		table.insert(parts, Tracks.text("req_school", { tier = Tracks.tierName(crit.schoolTier) }))
	end
	if type(crit.gpa) == "number" then
		table.insert(parts, Tracks.text("req_gpa", { gpa = string.format("%.2f", crit.gpa) }))
	end
	if crit.degree == "ms" then
		table.insert(parts, Tracks.text("req_masters"))
	end
	if type(crit.stats) == "table" then
		local ids: { string } = {}
		for statId in crit.stats do
			table.insert(ids, statId)
		end
		table.sort(ids)
		for _, statId in ids do
			table.insert(
				parts,
				Tracks.text("req_stat", { stat = STAT_NAMES[statId] or statId, min = math.floor(crit.stats[statId]) })
			)
		end
	end
	return table.concat(parts, Tracks.text("req_and"))
end

function Recruiting.eligibility(profile: any, company: any, trackId: string?): (boolean, { string })
	local c = Recruiting.candidate(profile)
	local hiring = hiringFor(company, trackId)
	if not hiring then
		local name = if type(company) == "table" and type(company.name) == "string" then company.name else "?"
		return false, { Tracks.text("elig_not_hiring", { company = name }) }
	end
	local alternatives = if type(hiring.anyOf) == "table" then hiring.anyOf else {}
	if #alternatives == 0 then
		return true, {}
	end
	local needs: { string } = {}
	for _, crit in alternatives do
		if passes(c, crit) then
			return true, {}
		end
		local text = describe(crit)
		if text ~= "" then
			table.insert(needs, text)
		end
	end
	return false,
		{
			Tracks.text("elig_needs", {
				needs = table.concat(needs, Tracks.text("req_or")),
				tier = Tracks.tierName(c.schoolTier),
				gpa = string.format("%.2f", c.gpa),
			}),
		}
end

function Recruiting.eligible(
	profile: any,
	companies: { any },
	trackId: string?
): { { company: any, ok: boolean, reasons: { string } } }
	local out = {}
	for _, company in companies do
		if hiringFor(company, trackId) then
			local ok, reasons = Recruiting.eligibility(profile, company, trackId)
			table.insert(out, { company = company, ok = ok, reasons = reasons })
		end
	end
	return out
end

function Recruiting.walkOn(company: any, interviewQuality: number, trackId: string?): boolean
	local hiring = hiringFor(company, trackId)
	if not hiring or type(hiring.walkOn) ~= "table" then
		return false
	end
	return num(interviewQuality, 0) >= num(hiring.walkOn.bar, 101)
end

function Recruiting.offerChance(
	profile: any,
	company: any,
	interviewQuality: number,
	mods: Mods?,
	trackId: string?
): (number, Breakdown)
	local c = Recruiting.candidate(profile)
	local m: Mods = mods or {}
	local q = math.clamp(num(interviewQuality, 0) + num(m.interviewBonus, 0), 0, 100)
	local hiring = hiringFor(company, trackId)
	local breakdown: Breakdown = {
		eligible = false,
		walkOn = false,
		quality = q,
		bar = 0,
		base = 0,
		curve = 0,
		edge = 0,
		bonus = 0,
	}
	if not hiring then
		return 0, breakdown
	end
	local ok = Recruiting.eligibility(c, company, trackId)
	if not ok then
		return 0, breakdown
	end
	breakdown.eligible = true
	local bar = num(hiring.bar, 60)
	breakdown.bar = bar
	if type(hiring.walkOn) == "table" and q >= num(hiring.walkOn.bar, 101) then
		breakdown.walkOn = true
		return 1, breakdown
	end
	local base = math.clamp(num(hiring.baseOdds, 0.3), 0, 1)
	local curve = 2 / (1 + math.exp(-(q - bar) / Recruiting.CURVE_WIDTH))
	local schoolEdge = math.clamp(0.06 * (c.schoolTier - 3), -0.12, 0.18)
	local gpaEdge = math.clamp(0.4 * (c.gpa - 3.45), -0.3, 0.22)
	local edge = schoolEdge + gpaEdge
	local scaledBase = math.max(0.01, base * (1 + edge))
	-- additive edges never go below zero, so a weak Network only cancels other edges (odds stay monotonic)
	local bonus = (Recruiting.FAMILY_BONUS[c.familyRarity] or 0)
		+ (if hasPerk(c, "ivy_network") then Recruiting.IVY_BONUS else 0)
		+ (if c.degree == "ms" then Recruiting.MASTERS_BONUS else 0)
		+ math.clamp((num(c.stats.network, 50) - 50) * 0.002, -0.08, 0.08)
		+ math.max(0, num(m.offerBonus, 0))
		+ math.clamp(num(m.connections, 0) * 0.01, 0, 0.1)
	bonus = math.max(0, bonus)
	local chance = scaledBase * curve + bonus * math.min(1, curve)
	breakdown.base = base
	breakdown.curve = curve
	breakdown.edge = edge
	breakdown.bonus = bonus
	return math.clamp(chance, 0, Recruiting.MAX_CHANCE), breakdown
end

function Recruiting.decide(chance: number, u: number): boolean
	return num(u, 1) < num(chance, 0)
end

return Recruiting
