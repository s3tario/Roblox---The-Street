--!strict
-- Wardrobe screen view model (PURE: no services, no Instances; unit-tested in tests/wardrobe).
--   View.TABS                                   slot tabs in display order, then "presets"
--   View.items(slot, viewer) -> { Item }         what a tab lists (shop items + owned Life Roll / heirloom pieces)
--   View.state(item, viewer, equipped) -> State  badge text, colour token and the primary action for an item card
--   View.preview(equipped, slot?, itemId?) -> { [slot] = itemId }   the look on the preview figure
--   View.rarity(rarityId) -> { name, color: Color3, color2: Color3? }
--   View.brandLine(item) -> "Gapline · Common"
--   View.errorText(errKey) -> string
--   View.levelBadge(item) -> "Lv 3"              the clothing level (= tier, v3 §5) shown on cards and the preview
--   View.outfit(equipped) -> Outfit               the Outfit Level of a look, with the part holding it down
--   View.dressCode(level, minLevel?, companyName?) -> DressCode?   the firm's minimum Outfit Level vs the look
--   View.canUsePrompt(career, events, companyId?) -> boolean   hide "EmployeesOnly" prompts for visitors
-- viewer = { owned, rank, passes } (Catalog.Viewer); equipped = inventory.equipped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Format = require(Shared.Util.Format)
local Palette = require(Shared.Build.Palette)

local View = {}

export type Action = "equip" | "unequip" | "buy" | "none"
export type State = {
	state: string, -- wearing | owned | free | buy | rank | pass | roll | heirloom
	badge: string,
	badgeColor: string, -- Theme colour key
	action: Action,
	actionText: string,
	locked: boolean,
}

local tabs: { string } = {}
for _, slot in Catalog.TAB_ORDER do
	table.insert(tabs, slot)
end
table.insert(tabs, "presets")
View.TABS = tabs

function View.tabTitle(id: string): string
	if id == "presets" then
		return Catalog.text("tab_presets")
	end
	return Catalog.text("slot_" .. id)
end

function View.items(slot: string, viewer: Catalog.Viewer): { Catalog.Item }
	return Catalog.visibleFor(slot, viewer)
end

local function passName(item: Catalog.Item): string
	local key = item.pass or ""
	local label = Catalog.strings["pass_" .. key]
	return label or key
end

function View.state(item: Catalog.Item, viewer: Catalog.Viewer, equipped: { [string]: string }?): State
	local wearing = equipped ~= nil and equipped[item.slot] == item.id
	local access = Catalog.access(item, viewer)
	if wearing then
		return {
			state = "wearing",
			badge = Catalog.text("equipped"),
			badgeColor = "good",
			action = "unequip",
			actionText = Catalog.text("unequip"),
			locked = false,
		}
	end
	local canWear, err = Catalog.canWear(item, viewer)
	if canWear then
		return {
			state = access,
			badge = if access == "free" then Catalog.text("free") else Catalog.text("owned"),
			badgeColor = "surface",
			action = "equip",
			actionText = Catalog.text("equip"),
			locked = false,
		}
	end
	if err == "rank" and item.minRank then
		local text = Catalog.text("locked_rank", { role = Catalog.rankTitle(item.minRank) })
		return { state = "rank", badge = text, badgeColor = "warn", action = "none", actionText = text, locked = true }
	end
	if access == "pass" then
		local text = Catalog.text("locked_pass", { pass = passName(item) })
		return { state = "pass", badge = text, badgeColor = "accent", action = "none", actionText = text, locked = true }
	end
	if access == "roll" or access == "heirloom" then
		local text = Catalog.text("locked_" .. access)
		return {
			state = access,
			badge = text,
			badgeColor = "surface",
			action = "none",
			actionText = text,
			locked = true,
		}
	end
	local price = Format.money(item.price)
	return {
		state = "buy",
		badge = price,
		badgeColor = "accent",
		action = "buy",
		actionText = Catalog.text("buy", { price = price }),
		locked = false,
	}
end

function View.preview(equipped: { [string]: string }?, slot: string?, itemId: string?): { [string]: string }
	local out: { [string]: string } = {}
	if type(equipped) == "table" then
		for s, id in equipped do
			out[s] = id
		end
	end
	if slot and Catalog.SLOT_SET[slot] then
		if itemId then
			out[slot] = itemId
		else
			out[slot] = nil
		end
	end
	return out
end

local rarityCache: { [string]: { name: string, color: Color3, color2: Color3? } } = {}

function View.rarity(id: string?): { name: string, color: Color3, color2: Color3? }
	local key = id or "common"
	local cached = rarityCache[key]
	if cached then
		return cached
	end
	local def = Catalog.RARITY[key] or Catalog.RARITY.common
	local entry = {
		name = Catalog.text("rarity_" .. def.id),
		color = Palette.hex(def.color),
		color2 = if def.color2 then Palette.hex(def.color2) else nil,
	}
	rarityCache[key] = entry
	return entry
end

function View.brandLine(item: Catalog.Item): string
	local brand = Catalog.brand(item.brand)
	return Catalog.text("brand_line", {
		brand = if brand then brand.name else item.brand,
		rarity = View.rarity(item.rarity).name,
	})
end

function View.errorText(err: string?): string
	local key = "err_" .. (err or "generic")
	if Catalog.strings[key] then
		return Catalog.strings[key]
	end
	return Catalog.strings.err_generic
end

---------------------------------------------------------------------------------------------------
-- Clothing level and Outfit Level (v3 §5)
---------------------------------------------------------------------------------------------------
function View.levelBadge(item: Catalog.Item): string
	return Catalog.text("level_badge", { level = Catalog.levelOf(item) })
end

export type Outfit = {
	level: number,
	text: string, -- "Outfit Lv 3"
	held: string?, -- "Held at Lv 2 by your shoes" when a part is below the others
	parts: Catalog.OutfitParts,
}

function View.outfit(equipped: { [string]: string }?): Outfit
	local level, parts = Catalog.outfitLevel(equipped)
	local held: string? = nil
	if math.max(parts.torso, parts.bottom, parts.shoes) > level then
		-- every part sitting at the Outfit Level ("Held at Lv 3 by your bottoms and shoes")
		local names: { string } = {}
		for _, part in { "torso", "bottom", "shoes" } do
			if (parts :: any)[part] == level then
				table.insert(names, Catalog.text("part_" .. part))
			end
		end
		local list = names[1] or ""
		for i = 2, #names do
			list = Catalog.text("list_and", { a = list, b = names[i] })
		end
		held = Catalog.text("outfit_held_by", { part = list, level = level })
	end
	return { level = level, text = Catalog.text("outfit_level", { level = level }), held = held, parts = parts }
end

export type DressCode = { required: number, ok: boolean, text: string, color: string }

-- nil when there is no requirement to show (no firm, or the firm's level is unknown).
function View.dressCode(level: number, minLevel: any, companyName: any): DressCode?
	if type(minLevel) ~= "number" or minLevel ~= minLevel or minLevel < 1 then
		return nil
	end
	local required = math.clamp(math.floor(minLevel), 1, Catalog.LEVELS)
	local ok = level >= required
	local text = if type(companyName) == "string" and companyName ~= ""
		then Catalog.text("dress_code", { company = companyName, level = required })
		else if ok then Catalog.text("dress_code_ok") else Catalog.text("dress_code_short", { level = required })
	return { required = required, ok = ok, text = text, color = if ok then "good" else "bad" }
end

-- Whether this client should show an "EmployeesOnly" prompt of companyId: the player works there, or the two
-- firms are paired by a Merger Mania event (the server checks again either way: CareerService:IsEmployeeOf).
--   career = the replicated `career` key; events = the global `events` key (contracts §13)
function View.canUsePrompt(career: any, events: any, companyId: any): boolean
	if type(companyId) ~= "string" or companyId == "" then
		return true
	end
	local mine = if type(career) == "table" then career.companyId else nil
	if type(mine) ~= "string" or mine == "" then
		return false
	end
	if mine == companyId then
		return true
	end
	local corporate = if type(events) == "table" then events.corporate else nil
	if type(corporate) == "table" and corporate.id == "merger_mania" and type(corporate.data) == "table" then
		local seen: { [string]: boolean } = {}
		local function scan(v: any, depth: number)
			if type(v) == "string" then
				seen[v] = true
			elseif type(v) == "table" and depth < 3 then
				for _, x in v do
					scan(x, depth + 1)
				end
			end
		end
		scan(corporate.data, 0)
		return seen[mine] == true and seen[companyId] == true
	end
	return false
end

-- Item colour swatches for a card ("#RRGGBB" -> Color3), primary first.
function View.swatches(item: Catalog.Item): { Color3 }
	local out: { Color3 } = {}
	for _, key in { "primary", "secondary", "accent" } do
		local hex = (item.colors :: any)[key]
		if type(hex) == "string" and string.match(hex, "^#%x%x%x%x%x%x$") then
			table.insert(out, Palette.hex(hex))
		end
	end
	return out
end

return View
