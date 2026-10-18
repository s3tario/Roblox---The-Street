--!strict
-- Logic/LifeRoll: exact odds disclosure (PURE). Odds are always shown and always exact (design v3 §1, Roblox
-- paid-random policy); every number here comes from the same tables the rolls use.
--
--   Odds.table(field, rebirths?) -> OddsTable
--   Odds.all(rebirths?) -> { [field] = OddsTable }
-- OddsTable = { field, rows = { Row }, tiers = { Row }?, counts = { Row }?, notes = { string } }
--   rows    every possible result with its exact probability (school, family, outfit looks, degree, GPA bands)
--   tiers   rarity tiers with their odds and option counts (school, family, clubs per club, outfit)
--   counts  clubs only: how many clubs (1-3)
-- Row = { id, name, rarity?, odds, count? }

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.LifeRoll)
local Rarity = require(Shared.Config.Rarity)
local Catalog = require(Shared.Config.Catalog)
local Roll = require(script.Parent.Roll)

export type Row = { id: string, name: string, rarity: string?, odds: number, count: number? }
export type OddsTable = {
	field: string,
	rows: { Row },
	tiers: { Row }?,
	counts: { Row }?,
	notes: { string },
}

local Odds = {}

local function tierRows(kind: string, rebirths: number?): ({ Row }, { Row })
	local odds = Rarity.oddsFor(rebirths)
	local tiers: { Row } = {}
	local rows: { Row } = {}
	for _, tier in Rarity.list do
		local pool: { any }
		if kind == "outfit" then
			pool = Catalog.rollPools[tier.id] or {}
		else
			pool = Config.pool(kind, tier.id)
		end
		table.insert(tiers, { id = tier.id, name = tier.name, rarity = tier.id, odds = odds[tier.id], count = #pool })
		for _, def in pool do
			table.insert(rows, {
				id = def.id,
				name = def.name,
				rarity = tier.id,
				odds = if #pool > 0 then odds[tier.id] / #pool else 0,
			})
		end
	end
	return tiers, rows
end

local GPA_BANDS = { { 2.70, 2.99 }, { 3.00, 3.29 }, { 3.30, 3.59 }, { 3.60, 3.79 }, { 3.80, 4.00 } }

function Odds.table(field: string, rebirths: number?): OddsTable
	local notes: { string } = {}
	if field == "school" or field == "family" or field == "outfit" then
		local tiers, rows = tierRows(field, rebirths)
		if field == "outfit" then
			table.insert(notes, Config.text("odds_outfit_note"))
		end
		return { field = field, rows = rows, tiers = tiers, notes = notes }
	elseif field == "clubs" then
		local tiers = tierRows("club", rebirths)
		local _, rows = tierRows("club", rebirths)
		local counts: { Row } = {}
		for n, p in Config.rules.clubCountOdds do
			table.insert(counts, { id = tostring(n), name = tostring(n), odds = p })
		end
		table.insert(notes, Config.text("odds_clubs_note"))
		return { field = field, rows = rows, tiers = tiers, counts = counts, notes = notes }
	elseif field == "degree" then
		local rows: { Row } = {}
		for _, d in Config.degrees do
			table.insert(rows, { id = d.id, name = d.name, rarity = d.rarity, odds = d.odds })
		end
		table.insert(notes, Config.text("odds_degree_note"))
		return { field = field, rows = rows, notes = notes }
	elseif field == "gpa" then
		local rows: { Row } = {}
		local lo0, hi0 = Config.rules.gpaMin, Config.rules.gpaMax
		for i, band in GPA_BANDS do
			local lo = math.max(lo0, band[1] - 0.005)
			local hi = math.min(hi0, band[2] + 0.005)
			table.insert(rows, {
				id = "gpa_" .. i,
				name = Config.text(
					"gpa_band",
					{ lo = string.format("%.2f", band[1]), hi = string.format("%.2f", band[2]) }
				),
				odds = Roll.gpaCdf(hi) - Roll.gpaCdf(lo),
			})
		end
		table.insert(notes, Config.text("odds_gpa_note"))
		return { field = field, rows = rows, notes = notes }
	elseif field == "stats" then
		table.insert(notes, Config.text("odds_stats_note"))
		return { field = field, rows = {}, notes = notes }
	end
	return { field = field, rows = {}, notes = notes }
end

function Odds.all(rebirths: number?): { [string]: OddsTable }
	local out: { [string]: OddsTable } = {}
	for _, field in Config.FIELDS do
		out[field] = Odds.table(field, rebirths)
	end
	return out
end

return Odds
