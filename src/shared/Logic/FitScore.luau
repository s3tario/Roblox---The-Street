--!strict
-- Outfit Level and Fit Score (owned by `careerPath`; design v3 §5, spec v2 §16). PURE: no services, no clocks.
-- Items come from a lookup the caller passes in (Config/Catalog.get on the server and client), so this module
-- never depends on the wardrobe's internals.
--
--   FitScore.outfitLevel(equipped, getItem) -> (level 1..5, parts)
--       Outfit Level = the LOWEST level among the core slots: torso (the better of top and outer), bottom and
--       shoes. Empty or unknown core slots count as the plain level-1 base pieces.
--       parts = { torso, bottom, shoes, level, lowest = "torso" | "bottom" | "shoes" }
--   FitScore.score(equipped, getItem, requiredLevel?) -> (0..100, breakdown)
--       the social/cosmetic layer shown on profile cards: core tiers (60), accessories (12), rarity (15) and
--       meeting the employer's dress level (13)
--   FitScore.clientBonus(score, outfitLevel, requiredLevel) -> 1.0..1.1
--       reputation multiplier on client-facing work (never on graded quality); 1.0 when underdressed
--   FitScore.requiredLevel(company?, role?) -> number   the higher of the firm's minimum and the title's level

local FitScore = {}

FitScore.MAX_LEVEL = 5
FitScore.MAX_CLIENT_BONUS = 0.1
FitScore.ACCESSORY_SLOTS = { "neck", "wrist", "eyes", "head", "bag" }

local RARITY_ORDER: { [string]: number } = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 6 }

export type Item = { slot: string?, tier: number?, rarity: string?, hidden: boolean? }
export type GetItem = (id: string) -> any
export type Parts = { torso: number, bottom: number, shoes: number, level: number, lowest: string }
export type Breakdown = { core: number, accessories: number, rarity: number, dress: number }

local function itemIn(equipped: any, getItem: GetItem, slot: string): Item?
	if type(equipped) ~= "table" then
		return nil
	end
	local id = equipped[slot]
	if type(id) ~= "string" then
		return nil
	end
	local ok, item = pcall(getItem, id)
	if not ok or type(item) ~= "table" or item.hidden == true then
		return nil
	end
	if type(item.slot) == "string" and item.slot ~= slot then
		return nil
	end
	return item :: Item
end

local function tierOf(item: Item?): number
	if not item or type(item.tier) ~= "number" or item.tier ~= item.tier then
		return 0
	end
	return math.clamp(math.floor(item.tier), 1, FitScore.MAX_LEVEL)
end

function FitScore.outfitLevel(equipped: any, getItem: GetItem): (number, Parts)
	local torso = math.max(tierOf(itemIn(equipped, getItem, "top")), tierOf(itemIn(equipped, getItem, "outer")), 1)
	local bottom = math.max(tierOf(itemIn(equipped, getItem, "bottom")), 1)
	local shoes = math.max(tierOf(itemIn(equipped, getItem, "shoes")), 1)
	local level = math.min(torso, bottom, shoes)
	local lowest = if torso == level then "torso" elseif bottom == level then "bottom" else "shoes"
	return level, { torso = torso, bottom = bottom, shoes = shoes, level = level, lowest = lowest }
end

function FitScore.score(equipped: any, getItem: GetItem, requiredLevel: number?): (number, Breakdown)
	local level, parts = FitScore.outfitLevel(equipped, getItem)
	local coreAvg = (parts.torso + parts.bottom + parts.shoes) / 3
	local core = (coreAvg - 1) / (FitScore.MAX_LEVEL - 1) * 60

	local accessories = 0
	local raritySum, rarityCount = 0, 0
	for _, slot in { "top", "outer", "bottom", "shoes" } do
		local item = itemIn(equipped, getItem, slot)
		if item then
			raritySum += RARITY_ORDER[item.rarity or "common"] or 1
			rarityCount += 1
		end
	end
	for _, slot in FitScore.ACCESSORY_SLOTS do
		local item = itemIn(equipped, getItem, slot)
		if item then
			accessories += 2 + tierOf(item) * 0.4
			raritySum += RARITY_ORDER[item.rarity or "common"] or 1
			rarityCount += 1
		end
	end
	accessories = math.min(12, accessories)
	local rarity = if rarityCount > 0 then ((raritySum / rarityCount) - 1) / 5 * 15 else 0
	local need = if type(requiredLevel) == "number" then requiredLevel else 1
	local dress = if level >= need then 13 else 0
	local total = math.clamp(math.floor(core + accessories + rarity + dress + 0.5), 0, 100)
	return total,
		{
			core = math.floor(core + 0.5),
			accessories = math.floor(accessories + 0.5),
			rarity = math.floor(rarity + 0.5),
			dress = dress,
		}
end

function FitScore.clientBonus(score: number, outfitLevel: number, requiredLevel: number): number
	if type(score) ~= "number" or score ~= score then
		return 1
	end
	if outfitLevel < requiredLevel then
		return 1
	end
	return 1 + FitScore.MAX_CLIENT_BONUS * math.clamp(score, 0, 100) / 100
end

function FitScore.requiredLevel(company: any, role: any): number
	local need = 1
	if type(company) == "table" and type(company.minOutfitLevel) == "number" then
		need = math.max(need, company.minOutfitLevel)
	end
	if type(role) == "table" and type(role.rank) == "number" and role.rank >= 1 then
		local dress = if type(role.dressLevel) == "number" then role.dressLevel else math.min(5, role.rank + 1)
		need = math.max(need, dress)
	end
	return math.clamp(need, 1, FitScore.MAX_LEVEL)
end

return FitScore
