--!strict
-- Rarity tiers for everything the Life Roll rolls (owned by `careerCore`; design v3 §1, contracts §4).
-- Pure data plus pure helpers: safe on the server, the client, in builders (Logos reads the colours) and in Lune.
--
--   Rarity.ids                          { "common", "uncommon", "rare", "epic", "legendary", "mythic" }
--   Rarity.list = { {id, name, odds, color, color2?, hex, order} }   base odds sum to exactly 1
--   Rarity.get(id) -> def?              Rarity.order(id) -> 1..6 (unknown ids count as common: 1)
--   Rarity.byOrder(order) -> def        Rarity.name(id) -> string     Rarity.color(id) -> Color3
--   Rarity.hex(id) -> "#RRGGBB"         Rarity.atLeast(id, minId) -> boolean
--   Rarity.oddsFor(rebirths) -> { [id] = probability }   the v3 §1 rebirth shift (capped at 10 rebirths)
--   Rarity.oddsList(rebirths) -> { {id, odds} }          the same in tier order (for odds tables)
--   Rarity.pick(u, rebirths) -> id      u in [0, 1) from Shared/Util/Rng picks a tier with oddsFor(rebirths)
--   Rarity.boostAmounts[id] -> { number }   stat boosts a school or club of that tier grants, in order
--                                           (Mythic: +8 to the first listed stat, +5 to the other two)
--   Rarity.carriesPerk(id) -> boolean   Legendary and Mythic schools/clubs carry perks
--   Rarity.PRISMATIC                    the Mythic gradient colours (Color3 list, for UIGradient)
--   Rarity.percent(p) -> "12.5%"        exact percentage text for odds tables (up to 2 decimals)
--
-- Rebirth luck (v3 §1): each rebirth moves 0.4 percentage points from Common to the other tiers, split
-- 40/30/16/10/4 across Uncommon..Mythic, capped at 10 rebirths (Common 50% -> 46%, Mythic 1% -> 1.16%).

export type RarityId = string
export type RarityDef = {
	id: string,
	name: string,
	odds: number,
	color: Color3,
	color2: Color3?,
	hex: string,
	order: number,
}

local Rarity = {}

Rarity.ids = { "common", "uncommon", "rare", "epic", "legendary", "mythic" }

Rarity.REBIRTH_STEP = 0.004 -- probability moved out of Common per rebirth
Rarity.REBIRTH_CAP = 10 -- rebirths beyond this add no more luck
Rarity.SHIFT_SPLIT = { uncommon = 0.40, rare = 0.30, epic = 0.16, legendary = 0.10, mythic = 0.04 } :: {
	[string]: number,
}

local function rgb(hex: string): Color3
	local r = tonumber(string.sub(hex, 2, 3), 16) or 0
	local g = tonumber(string.sub(hex, 4, 5), 16) or 0
	local b = tonumber(string.sub(hex, 6, 7), 16) or 0
	return Color3.fromRGB(r, g, b)
end

-- Same grey/green/blue/purple/gold/prismatic colours as the wardrobe catalog (Config/Catalog/Brands).
local DEFS: { { id: string, name: string, odds: number, hex: string, hex2: string? } } = {
	{ id = "common", name = "Common", odds = 0.50, hex = "#9AA0A6" },
	{ id = "uncommon", name = "Uncommon", odds = 0.25, hex = "#4CAF6A" },
	{ id = "rare", name = "Rare", odds = 0.13, hex = "#3D7DD8" },
	{ id = "epic", name = "Epic", odds = 0.07, hex = "#9B5DE5" },
	{ id = "legendary", name = "Legendary", odds = 0.04, hex = "#D4AF37" },
	{ id = "mythic", name = "Mythic", odds = 0.01, hex = "#D946EF", hex2 = "#22D3EE" },
}

Rarity.list = {} :: { RarityDef }
local byId: { [string]: RarityDef } = {}
for i, d in DEFS do
	local def: RarityDef = {
		id = d.id,
		name = d.name,
		odds = d.odds,
		color = rgb(d.hex),
		color2 = if d.hex2 then rgb(d.hex2) else nil,
		hex = d.hex,
		order = i,
	}
	table.insert(Rarity.list, def)
	byId[d.id] = def
end
Rarity.byId = byId

-- Mythic "prismatic" sweep: magenta -> violet -> blue -> cyan -> mint -> gold.
Rarity.PRISMATIC = {
	rgb("#D946EF"),
	rgb("#8B5CF6"),
	rgb("#3B82F6"),
	rgb("#22D3EE"),
	rgb("#34D399"),
	rgb("#FACC15"),
} :: { Color3 }

Rarity.boostAmounts = {
	common = {},
	uncommon = { 5 },
	rare = { 5, 5 },
	epic = { 5, 5, 5 },
	legendary = { 5, 5, 5 },
	mythic = { 8, 5, 5 },
} :: { [string]: { number } }

function Rarity.get(id: any): RarityDef?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function Rarity.order(id: any): number
	local def = Rarity.get(id)
	return if def then def.order else 1
end

function Rarity.byOrder(order: number): RarityDef
	local i = math.clamp(math.floor(if order == order then order else 1), 1, #Rarity.list)
	return Rarity.list[i]
end

function Rarity.name(id: any): string
	local def = Rarity.get(id)
	return if def then def.name else Rarity.list[1].name
end

function Rarity.color(id: any): Color3
	local def = Rarity.get(id)
	return if def then def.color else Rarity.list[1].color
end

function Rarity.hex(id: any): string
	local def = Rarity.get(id)
	return if def then def.hex else Rarity.list[1].hex
end

function Rarity.atLeast(id: any, minId: string): boolean
	return Rarity.order(id) >= Rarity.order(minId)
end

function Rarity.carriesPerk(id: any): boolean
	return Rarity.order(id) >= Rarity.order("legendary")
end

local function rebirthCount(rebirths: any): number
	if type(rebirths) ~= "number" or rebirths ~= rebirths or rebirths < 0 then
		return 0
	end
	return math.min(math.floor(rebirths), Rarity.REBIRTH_CAP)
end
Rarity.rebirthCount = rebirthCount

function Rarity.oddsFor(rebirths: any): { [string]: number }
	local n = rebirthCount(rebirths)
	local moved = Rarity.REBIRTH_STEP * n
	local out: { [string]: number } = {}
	for _, def in Rarity.list do
		local share = Rarity.SHIFT_SPLIT[def.id]
		if def.id == "common" then
			out[def.id] = def.odds - moved
		else
			out[def.id] = def.odds + moved * (share or 0)
		end
	end
	return out
end

function Rarity.oddsList(rebirths: any): { { id: string, odds: number } }
	local odds = Rarity.oddsFor(rebirths)
	local out: { { id: string, odds: number } } = {}
	for _, def in Rarity.list do
		table.insert(out, { id = def.id, odds = odds[def.id] })
	end
	return out
end

function Rarity.pick(u: number, rebirths: any): string
	local x = if type(u) == "number" and u == u then math.clamp(u, 0, 1) else 0
	local odds = Rarity.oddsFor(rebirths)
	local acc = 0
	for _, def in Rarity.list do
		acc += odds[def.id]
		if x < acc then
			return def.id
		end
	end
	return Rarity.list[#Rarity.list].id -- float rounding just below u = 1: the last tier's slice
end

-- 0.125 -> "12.5%", 0.0116 -> "1.16%", 0.5 -> "50%"
function Rarity.percent(p: number): string
	local v = math.floor(p * 10000 + 0.5) / 100
	local s = string.format("%.2f", v)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	return s .. "%"
end

return Rarity
