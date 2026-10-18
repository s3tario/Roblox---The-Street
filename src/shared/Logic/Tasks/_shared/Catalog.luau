--!strict
-- Task module catalog rules (owned by `work`; contracts §8). PURE: WorkService requires the modules (it owns the
-- Instances), then uses these to decide which ones it accepts and what the client may see about them.
--
--   Catalog.check(mod, name?) -> (ok, err?)     contract shape: id (= the file name), title, desc, category,
--                                               stats (known stat ids), generate/grade functions, numeric
--                                               timeLimit/baseXp/basePay/cooldown, tracks/ranks lists when present
--   Catalog.info(mod) -> Board.ModuleInfo       the fields the board draws on
--   Catalog.summary(mod) -> Summary             client-safe card data (never the generator or answers)
--   Catalog.STAT_IDS                            the eight attribute ids (design v3 §3)
--   Catalog.CATEGORIES                          contracts §8 category ids

local Config = require(script.Parent.Parent.Parent.Parent.Config.Tasks)

export type Summary = {
	id: string,
	title: string,
	desc: string,
	kind: string,
	category: string,
	core: boolean,
	clientFacing: boolean,
	timeLimit: number,
	stats: { string },
	baseXp: number,
	basePay: number,
}

local Catalog = {}

Catalog.STAT_IDS = {
	knowledge = true,
	skill = true,
	speed = true,
	charisma = true,
	network = true,
	discipline = true,
	risk = true,
	luck = true,
} :: { [string]: boolean }

Catalog.CATEGORIES = {} :: { [string]: boolean }
for _, id in Config.CATEGORY_IDS do
	Catalog.CATEGORIES[id] = true
end

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function isStrList(x: any): boolean
	if type(x) ~= "table" or #x == 0 then
		return false
	end
	for _, v in x do
		if type(v) ~= "string" then
			return false
		end
	end
	return true
end

local function isNumList(x: any): boolean
	if type(x) ~= "table" or #x == 0 then
		return false
	end
	for _, v in x do
		if not finite(v) or v ~= math.floor(v) then
			return false
		end
	end
	return true
end

function Catalog.check(mod: any, name: string?): (boolean, string?)
	if type(mod) ~= "table" then
		return false, "module did not return a table"
	end
	if type(mod.id) ~= "string" or mod.id == "" then
		return false, "missing id"
	end
	if name ~= nil and mod.id ~= name then
		return false, "id " .. mod.id .. " doesn't match the file name " .. name
	end
	if type(mod.title) ~= "string" or mod.title == "" then
		return false, "missing title"
	end
	if type(mod.desc) ~= "string" then
		return false, "missing desc"
	end
	if type(mod.category) ~= "string" or not Catalog.CATEGORIES[mod.category] then
		return false, "unknown category " .. tostring(mod.category)
	end
	if not isStrList(mod.stats) then
		return false, "stats must be a list of stat ids"
	end
	for _, s in mod.stats do
		if not Catalog.STAT_IDS[s] then
			return false, "unknown stat " .. tostring(s)
		end
	end
	if type(mod.generate) ~= "function" or type(mod.grade) ~= "function" then
		return false, "generate/grade must be functions"
	end
	for _, key in { "timeLimit", "baseXp", "basePay", "cooldown" } do
		local v = mod[key]
		if not finite(v) or v < 0 then
			return false, key .. " must be a number >= 0"
		end
	end
	if mod.timeLimit < 15 then
		return false, "timeLimit too short"
	end
	if mod.tracks ~= nil and not isStrList(mod.tracks) then
		return false, "tracks must be a list of track ids"
	end
	if mod.ranks ~= nil and not isNumList(mod.ranks) then
		return false, "ranks must be a list of integers"
	end
	if mod.kind ~= nil and (type(mod.kind) ~= "string" or Config.kinds[mod.kind] == nil) then
		return false, "unknown kind " .. tostring(mod.kind)
	end
	return true, nil
end

function Catalog.info(mod: any): { [string]: any }
	return {
		id = mod.id,
		tracks = mod.tracks,
		ranks = mod.ranks,
		student = mod.student == true,
		unemployed = mod.unemployed == true,
		offerOnly = mod.offerOnly == true,
		core = mod.core == true,
		weight = if finite(mod.weight) then mod.weight else nil,
	}
end

function Catalog.summary(mod: any): Summary
	local stats: { string } = {}
	for _, s in mod.stats or {} do
		if type(s) == "string" then
			table.insert(stats, s)
		end
	end
	return {
		id = mod.id,
		title = mod.title,
		desc = if type(mod.desc) == "string" then mod.desc else "",
		kind = if type(mod.kind) == "string" then mod.kind else "multi",
		category = mod.category,
		core = mod.core == true,
		clientFacing = mod.clientFacing == true,
		timeLimit = mod.timeLimit,
		stats = stats,
		baseXp = mod.baseXp,
		basePay = mod.basePay,
	}
end

return Catalog
