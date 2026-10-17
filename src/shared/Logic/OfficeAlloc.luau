--!strict
-- OfficeAlloc (offices, PURE): the bookkeeping behind per-company office instances (spec v3 §14).
--   * instance slots: each company present on a server gets the lowest free instance index; freed indices are
--     reused (World.officeOrigin(index, floor) places it)
--   * floors: floor 0 is the lobby, department i (1-based, in the company's department order) is floor i
--   * cleanup: floors nobody has been inside for `ttl` seconds expire
--   * companies: normalizes Config/Companies (whatever shape it exports) and Config/Tracks, decides which
--     companies and departments are open (a lobby template plus at least one department floor template), and
--     builds the Directory list (ordered like the Street's towers) and tower-picker lists
--   * NPC desks: picks free desks for ambient coworkers
-- No services, no clocks, no Instances.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local Text = require(script.Parent.DoorRules.Text)

local OfficeAlloc = {}

OfficeAlloc.LOBBY = "lobby"
OfficeAlloc.EMPTY_TTL = 180 -- seconds a floor may stay empty before it is removed
OfficeAlloc.MIN_COWORKERS = 4
OfficeAlloc.MAX_COWORKERS = 8
OfficeAlloc.BUSY_FLOORS = 6 -- with this many live floors, floors get the minimum number of coworkers

---------------------------------------------------------------------------------------------------
-- Instance slots
---------------------------------------------------------------------------------------------------
export type Alloc = { max: number, byCompany: { [string]: number }, byIndex: { [number]: string } }

function OfficeAlloc.new(maxInstances: number?): Alloc
	return { max = maxInstances or World.offices.maxInstances, byCompany = {}, byIndex = {} }
end

function OfficeAlloc.indexOf(alloc: Alloc, companyId: string): number?
	return alloc.byCompany[companyId]
end

function OfficeAlloc.companyAt(alloc: Alloc, index: number): string?
	return alloc.byIndex[index]
end

function OfficeAlloc.count(alloc: Alloc): number
	local n = 0
	for _ in alloc.byCompany do
		n += 1
	end
	return n
end

-- The company's index (existing, or the lowest free one). nil when every slot is taken.
function OfficeAlloc.acquire(alloc: Alloc, companyId: string): number?
	local existing = alloc.byCompany[companyId]
	if existing then
		return existing
	end
	for i = 1, alloc.max do
		if alloc.byIndex[i] == nil then
			alloc.byIndex[i] = companyId
			alloc.byCompany[companyId] = i
			return i
		end
	end
	return nil
end

function OfficeAlloc.release(alloc: Alloc, companyId: string): number?
	local i = alloc.byCompany[companyId]
	if i == nil then
		return nil
	end
	alloc.byCompany[companyId] = nil
	alloc.byIndex[i] = nil
	return i
end

---------------------------------------------------------------------------------------------------
-- Floors
---------------------------------------------------------------------------------------------------
local function maxDepartments(): number
	return World.offices.maxFloors - 1
end

-- 0 for the lobby, the department's 1-based position for a department, nil otherwise.
function OfficeAlloc.floorIndex(departments: { string }, floor: string?): number?
	if floor == nil or floor == OfficeAlloc.LOBBY then
		return 0
	end
	local i = table.find(departments, floor)
	if i == nil or i > maxDepartments() then
		return nil
	end
	return i
end

function OfficeAlloc.floorAt(departments: { string }, index: number): string?
	if index == 0 then
		return OfficeAlloc.LOBBY
	end
	if index < 1 or index > maxDepartments() then
		return nil
	end
	return departments[index]
end

function OfficeAlloc.floorKey(companyId: string, floor: string): string
	return companyId .. "/" .. floor
end

export type FloorRec = { companyId: string, floor: string, createdAt: number, lastOccupied: number }

function OfficeAlloc.newFloor(companyId: string, floor: string, now: number): FloorRec
	return { companyId = companyId, floor = floor, createdAt = now, lastOccupied = now }
end

-- Marks floors that have someone inside (occupied[key] = true) and returns the keys of floors that have been
-- empty for longer than ttl, sorted for determinism.
function OfficeAlloc.sweep(
	floors: { [string]: FloorRec },
	occupied: { [string]: boolean },
	now: number,
	ttl: number?
): { string }
	local limit = ttl or OfficeAlloc.EMPTY_TTL
	local out: { string } = {}
	for key, rec in floors do
		if occupied[key] then
			rec.lastOccupied = now
		elseif now - rec.lastOccupied > limit then
			table.insert(out, key)
		end
	end
	table.sort(out)
	return out
end

-- True when no floor of the company is still alive (its instance slot can be freed).
function OfficeAlloc.instanceEmpty(floors: { [string]: FloorRec }, companyId: string): boolean
	for _, rec in floors do
		if rec.companyId == companyId then
			return false
		end
	end
	return true
end

---------------------------------------------------------------------------------------------------
-- Config normalization
---------------------------------------------------------------------------------------------------
export type Company = {
	id: string,
	name: string,
	short: string,
	kind: string?,
	tier: any,
	tierLabel: string,
	departments: { string },
	primary: Color3?,
	accent: Color3?,
	textColor: Color3?,
	logo: string,
	tagline: string?,
	bossNames: { [string]: string },
	disabled: boolean,
}

export type Track = { id: string, name: string, topTitle: string?, disabled: boolean }

local function toColor(v: any): Color3?
	if typeof(v) == "Color3" then
		return v
	end
	if type(v) == "string" then
		local hex = string.match(v, "^#?(%x%x%x%x%x%x)$")
		if hex then
			local n = tonumber(hex, 16) :: number
			return Color3.fromRGB(bit32.rshift(n, 16) % 256, bit32.rshift(n, 8) % 256, n % 256)
		end
	end
	if type(v) == "table" then
		local r, g, b = v.r or v.R or v[1], v.g or v.G or v[2], v.b or v.B or v[3]
		if type(r) == "number" and type(g) == "number" and type(b) == "number" then
			if r > 1 or g > 1 or b > 1 then
				return Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
			end
			return Color3.new(math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
		end
	end
	return nil
end
OfficeAlloc.toColor = toColor

local function str(v: any): string?
	if type(v) == "string" and v ~= "" then
		return v
	end
	return nil
end

local function tierLabelOf(tier: any, kind: string?): string
	for _, v in { tier, kind } do
		if type(v) == "string" then
			local key = Text.tierKeys[string.lower(v)]
			if key then
				return Text.get(key)
			end
		end
	end
	if type(kind) == "string" and kind ~= "" then
		local words = {}
		for w in string.gmatch(kind, "[^_]+") do
			table.insert(words, string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2))
		end
		return table.concat(words, " ")
	end
	return ""
end

local function initials(name: string): string
	local out = ""
	for w in string.gmatch(name, "[%a]+") do
		out ..= string.upper(string.sub(w, 1, 1))
		if #out >= 3 then
			break
		end
	end
	return if out ~= "" then out else string.upper(string.sub(name, 1, 2))
end
OfficeAlloc.initials = initials

-- One company def -> Company (nil when it isn't a usable company record).
function OfficeAlloc.normalizeCompany(def: any, key: any?): Company?
	if type(def) ~= "table" then
		return nil
	end
	local id = str(def.id) or (if type(key) == "string" then key else nil)
	if id == nil or string.find(id, "^[%w_%-]+$") == nil then
		return nil
	end
	local name = str(def.name) or str(def.label)
	if name == nil and type(def.departments) ~= "table" then
		return nil -- some other table that happens to sit in the module
	end
	local departments: { string } = {}
	if type(def.departments) == "table" then
		for _, d in ipairs(def.departments) do
			if type(d) == "string" and not table.find(departments, d) then
				table.insert(departments, d)
			end
		end
	end
	local colors = if type(def.colors) == "table" then def.colors else {}
	local bossNames: { [string]: string } = {}
	if type(def.bossNames) == "table" then
		for track, n in def.bossNames do
			if type(track) == "string" and type(n) == "string" and n ~= "" then
				bossNames[track] = n
			end
		end
	end
	local kind = str(def.type) or str(def.kind)
	local resolvedName = name or id
	return {
		id = id,
		name = resolvedName,
		short = str(def.short) or initials(resolvedName),
		kind = kind,
		tier = def.tier,
		tierLabel = str(def.typeName) or tierLabelOf(def.tier, kind),
		departments = departments,
		primary = toColor(colors.primary) or toColor(def.primary),
		accent = toColor(colors.accent) or toColor(def.accent),
		textColor = toColor(colors.text),
		logo = str(def.logo) or id,
		tagline = str(def.tagline),
		bossNames = bossNames,
		disabled = def.available == false or def.comingSoon == true or def.disabled == true or def.hidden == true,
	}
end

-- Config/Companies may export a list, a map, {list = ...}, {byId = ...} or get(id) + ids. Returns a map by id
-- and the list in a stable order (source order for lists, id order for maps).
function OfficeAlloc.normalizeCompanies(mod: any): ({ [string]: Company }, { Company })
	local byId: { [string]: Company } = {}
	local list: { Company } = {}
	if type(mod) ~= "table" then
		return byId, list
	end
	local function add(def: any, key: any?)
		local c = OfficeAlloc.normalizeCompany(def, key)
		if c and byId[c.id] == nil then
			byId[c.id] = c
			table.insert(list, c)
		end
	end
	local source: any = nil
	for _, field in { "list", "companies", "all", "byId", "COMPANIES" } do
		if type(mod[field]) == "table" then
			source = mod[field]
			break
		end
	end
	if source == nil and type(mod.get) == "function" and type(mod.ids) == "table" then
		for _, id in ipairs(mod.ids) do
			if type(id) == "string" then
				local ok, def = pcall(mod.get, id)
				if ok then
					add(def, id)
				end
			end
		end
		return byId, list
	end
	source = source or mod
	if #source > 0 then
		for _, def in ipairs(source) do
			add(def, nil)
		end
	else
		local keys: { string } = {}
		for k in source do
			if type(k) == "string" then
				table.insert(keys, k)
			end
		end
		table.sort(keys)
		for _, k in keys do
			add(source[k], k)
		end
	end
	return byId, list
end

-- Config/Tracks in the same spirit: {list}, {byId}, a map or a list of {id, name, ladder}.
function OfficeAlloc.normalizeTracks(mod: any): { [string]: Track }
	local out: { [string]: Track } = {}
	if type(mod) ~= "table" then
		return out
	end
	local source: any = mod
	for _, field in { "list", "tracks", "all", "byId", "TRACKS" } do
		if type(mod[field]) == "table" then
			source = mod[field]
			break
		end
	end
	for key, def in source do
		if type(def) == "table" then
			local id = str(def.id) or (if type(key) == "string" then key else nil)
			if id and (str(def.name) or type(def.ladder) == "table") then
				local top: string? = str(def.topTitle)
				if top == nil and type(def.ladder) == "table" and #def.ladder > 0 then
					local last = def.ladder[#def.ladder]
					top = if type(last) == "table" then str(last.title) elseif type(last) == "string" then last else nil
				end
				out[id] = {
					id = id,
					name = str(def.name) or Text.get("dept_" .. id, id),
					topTitle = top,
					disabled = def.enabled == false or def.available == false or def.disabled == true,
				}
			end
		end
	end
	return out
end

function OfficeAlloc.departmentName(trackId: string, tracks: { [string]: Track }?): string
	local t = if tracks then tracks[trackId] else nil
	if t then
		return t.name
	end
	return Text.get("dept_" .. trackId, trackId)
end

---------------------------------------------------------------------------------------------------
-- Availability and the Directory
---------------------------------------------------------------------------------------------------
export type DeptEntry = { id: string, name: string, floor: number, available: boolean }
export type Entry = {
	id: string,
	name: string,
	short: string,
	tierLabel: string,
	tagline: string?,
	logo: string,
	primary: Color3?,
	accent: Color3?,
	departments: { DeptEntry },
	available: boolean,
	order: number,
	placeholder: boolean?,
}

-- templates = { [templateId] = true } for every template in ServerStorage.FirmTemplates.
function OfficeAlloc.departments(
	company: Company,
	templates: { [string]: boolean },
	tracks: { [string]: Track }?
): { DeptEntry }
	local out: { DeptEntry } = {}
	for i, d in company.departments do
		if i > maxDepartments() then
			break
		end
		local track = if tracks then tracks[d] else nil
		table.insert(out, {
			id = d,
			name = OfficeAlloc.departmentName(d, tracks),
			floor = i,
			available = templates[d] == true and not (track and track.disabled),
		})
	end
	return out
end

function OfficeAlloc.isAvailable(
	company: Company?,
	templates: { [string]: boolean },
	tracks: { [string]: Track }?
): boolean
	if company == nil or company.disabled or templates[OfficeAlloc.LOBBY] ~= true then
		return false
	end
	for _, d in OfficeAlloc.departments(company, templates, tracks) do
		if d.available then
			return true
		end
	end
	return false
end

function OfficeAlloc.floorOpen(
	company: Company,
	floor: string,
	templates: { [string]: boolean },
	tracks: { [string]: Track }?
): boolean
	if floor == OfficeAlloc.LOBBY then
		return OfficeAlloc.isAvailable(company, templates, tracks)
	end
	for _, d in OfficeAlloc.departments(company, templates, tracks) do
		if d.id == floor then
			return d.available
		end
	end
	return false
end

-- Position of each company along the Street (tower order, tenants in picker order).
function OfficeAlloc.streetOrder(towers: { World.TowerDef }?): { [string]: number }
	local order: { [string]: number } = {}
	local n = 0
	for _, t in towers or World.towers do
		local ids: { string } = {}
		if t.company then
			table.insert(ids, t.company)
		end
		local picker = t.picker
		if picker then
			for _, id in picker do
				table.insert(ids, id)
			end
		end
		for _, id in ids do
			if order[id] == nil then
				n += 1
				order[id] = n
			end
		end
	end
	return order
end

function OfficeAlloc.entry(
	company: Company,
	templates: { [string]: boolean },
	tracks: { [string]: Track }?,
	order: number
): Entry
	return {
		id = company.id,
		name = company.name,
		short = company.short,
		tierLabel = company.tierLabel,
		tagline = company.tagline,
		logo = company.logo,
		primary = company.primary,
		accent = company.accent,
		departments = OfficeAlloc.departments(company, templates, tracks),
		available = OfficeAlloc.isAvailable(company, templates, tracks),
		order = order,
	}
end

-- Every company, open ones first, then in Street order, then by name.
function OfficeAlloc.directory(
	companies: { Company },
	templates: { [string]: boolean },
	tracks: { [string]: Track }?,
	towers: { World.TowerDef }?
): { Entry }
	local street = OfficeAlloc.streetOrder(towers)
	local out: { Entry } = {}
	for i, c in companies do
		table.insert(out, OfficeAlloc.entry(c, templates, tracks, street[c.id] or (1000 + i)))
	end
	table.sort(out, function(a, b)
		if a.available ~= b.available then
			return a.available
		end
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.name < b.name
	end)
	return out
end

-- A placeholder for a tenant that Config/Companies doesn't know (shown greyed "Opening soon").
function OfficeAlloc.placeholder(companyId: string, label: string?): Entry
	local name = label
	if name == nil then
		local words = {}
		for w in string.gmatch(companyId, "[^_]+") do
			table.insert(words, string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2))
		end
		name = table.concat(words, " ")
	end
	local resolved = name :: string
	return {
		id = companyId,
		name = resolved,
		short = initials(resolved),
		tierLabel = "",
		tagline = nil,
		logo = companyId,
		primary = nil,
		accent = nil,
		departments = {},
		available = false,
		order = 0,
		placeholder = true,
	}
end

-- The tenants of a multi-tenant tower, in the tower's order. Unknown tenants become placeholders; nothing else
-- from the directory leaks in.
function OfficeAlloc.pickerEntries(entries: { Entry }, tenants: { string }): { Entry }
	local byId: { [string]: Entry } = {}
	for _, e in entries do
		byId[e.id] = e
	end
	local out: { Entry } = {}
	local seen: { [string]: boolean } = {}
	for _, id in tenants do
		if type(id) == "string" and not seen[id] then
			seen[id] = true
			table.insert(out, byId[id] or OfficeAlloc.placeholder(id))
		end
	end
	return out
end

-- Directory entries filtered for a Directory tab.
function OfficeAlloc.filterOpen(entries: { Entry }, openOnly: boolean): { Entry }
	if not openOnly then
		return entries
	end
	local out: { Entry } = {}
	for _, e in entries do
		if e.available then
			table.insert(out, e)
		end
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Ambient coworkers
---------------------------------------------------------------------------------------------------
type RngLike = { int: (any, number, number) -> number, shuffle: (any, { number }) -> { number } }

function OfficeAlloc.coworkerCount(rng: RngLike, liveFloors: number): number
	if liveFloors >= OfficeAlloc.BUSY_FLOORS then
		return OfficeAlloc.MIN_COWORKERS
	end
	return rng:int(OfficeAlloc.MIN_COWORKERS, OfficeAlloc.MAX_COWORKERS)
end

-- Picks n distinct desk indices out of 1..total, drawing from the back half first (players are assigned desks
-- from the front), each half shuffled.
function OfficeAlloc.pickDesks(total: number, n: number, rng: RngLike, skip: { [number]: boolean }?): { number }
	local half = math.floor(total / 2)
	local front: { number } = {}
	local back: { number } = {}
	for i = 1, total do
		if not (skip and skip[i]) then
			table.insert(if i > half then back else front, i)
		end
	end
	local pool: { number } = rng:shuffle(back)
	for _, i in rng:shuffle(front) do
		table.insert(pool, i)
	end
	local out: { number } = {}
	for i = 1, math.min(n, #pool) do
		table.insert(out, pool[i])
	end
	return out
end

return OfficeAlloc
