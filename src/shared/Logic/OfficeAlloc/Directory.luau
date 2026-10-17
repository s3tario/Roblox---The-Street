--!strict
-- OfficeAlloc/Directory (offices, PURE): what the office system knows about companies and departments.
--   * normalizes Config/Companies (whatever shape it exports) and Config/Tracks
--   * decides which companies and department floors are open (a lobby template plus at least one department
--     floor template, the company and the track available)
--   * builds the Directory list (ordered like the Street's towers), tower-picker lists and the Directory tabs
-- No services, no clocks, no Instances. Re-exported by OfficeAlloc.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local Text = require(script.Parent.Parent.DoorRules.Text)

local Directory = {}

Directory.LOBBY = "lobby"

local function maxDepartments(): number
	return World.offices.maxFloors - 1
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
	departments: { string }, -- departments it runs now (one floor each)
	planned: { string }, -- departments it will run once their milestone ships (shown as "Opening soon")
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
Directory.toColor = toColor

local function str(v: any): string?
	if type(v) == "string" and v ~= "" then
		return v
	end
	return nil
end

local function prettify(id: string): string
	local words = {}
	for w in string.gmatch(id, "[^_]+") do
		table.insert(words, string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2))
	end
	return table.concat(words, " ")
end
Directory.prettify = prettify

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
		return prettify(kind)
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
Directory.initials = initials

local function idList(v: any): { string }
	local out: { string } = {}
	if type(v) == "table" then
		for _, d in ipairs(v) do
			if type(d) == "string" and d ~= "" and not table.find(out, d) then
				table.insert(out, d)
			end
		end
	end
	return out
end

-- One company def -> Company (nil when it isn't a usable company record).
function Directory.normalizeCompany(def: any, key: any?): Company?
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
	local departments = idList(def.departments)
	local planned = idList(def.plannedDepartments)
	for _, d in departments do
		if not table.find(planned, d) then
			table.insert(planned, d)
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
		planned = planned,
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
function Directory.normalizeCompanies(mod: any): ({ [string]: Company }, { Company })
	local byId: { [string]: Company } = {}
	local list: { Company } = {}
	if type(mod) ~= "table" then
		return byId, list
	end
	local function add(def: any, key: any?)
		local c = Directory.normalizeCompany(def, key)
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
function Directory.normalizeTracks(mod: any): { [string]: Track }
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

function Directory.departmentName(trackId: string, tracks: { [string]: Track }?): string
	if trackId == Directory.LOBBY then
		return Text.get("lobby")
	end
	local t = if tracks then tracks[trackId] else nil
	if t then
		return t.name
	end
	return Text.get("dept_" .. trackId, prettify(trackId))
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

-- The company's department floors (floor 1..n in department order). templates = { [templateId] = true } for every
-- template in ServerStorage.FirmTemplates.
function Directory.departments(
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
			name = Directory.departmentName(d, tracks),
			floor = i,
			available = not company.disabled and templates[d] == true and not (track and track.disabled),
		})
	end
	return out
end

function Directory.isAvailable(
	company: Company?,
	templates: { [string]: boolean },
	tracks: { [string]: Track }?
): boolean
	if company == nil or company.disabled or templates[Directory.LOBBY] ~= true then
		return false
	end
	for _, d in Directory.departments(company, templates, tracks) do
		if d.available then
			return true
		end
	end
	return false
end

function Directory.floorOpen(
	company: Company,
	floor: string,
	templates: { [string]: boolean },
	tracks: { [string]: Track }?
): boolean
	if floor == Directory.LOBBY then
		return Directory.isAvailable(company, templates, tracks)
	end
	if not Directory.isAvailable(company, templates, tracks) then
		return false
	end
	for _, d in Directory.departments(company, templates, tracks) do
		if d.id == floor then
			return d.available
		end
	end
	return false
end

-- Position of each company along the Street (tower order, tenants in picker order).
function Directory.streetOrder(towers: { World.TowerDef }?): { [string]: number }
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

-- What the Directory shows for a company: its open departments, or (for a company whose milestone hasn't
-- shipped) the departments it will run, all "Opening soon".
function Directory.entry(
	company: Company,
	templates: { [string]: boolean },
	tracks: { [string]: Track }?,
	order: number
): Entry
	local depts = Directory.departments(company, templates, tracks)
	if #depts == 0 then
		for i, d in company.planned do
			if i > maxDepartments() then
				break
			end
			table.insert(depts, { id = d, name = Directory.departmentName(d, tracks), floor = i, available = false })
		end
	end
	return {
		id = company.id,
		name = company.name,
		short = company.short,
		tierLabel = company.tierLabel,
		tagline = company.tagline,
		logo = company.logo,
		primary = company.primary,
		accent = company.accent,
		departments = depts,
		available = Directory.isAvailable(company, templates, tracks),
		order = order,
	}
end

-- Every company, open ones first, then in Street order, then by name.
function Directory.directory(
	companies: { Company },
	templates: { [string]: boolean },
	tracks: { [string]: Track }?,
	towers: { World.TowerDef }?
): { Entry }
	local street = Directory.streetOrder(towers)
	local out: { Entry } = {}
	for i, c in companies do
		table.insert(out, Directory.entry(c, templates, tracks, street[c.id] or (1000 + i)))
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
function Directory.placeholder(companyId: string, label: string?): Entry
	local name = label or prettify(companyId)
	return {
		id = companyId,
		name = name,
		short = initials(name),
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
function Directory.pickerEntries(entries: { Entry }, tenants: { string }): { Entry }
	local byId: { [string]: Entry } = {}
	for _, e in entries do
		byId[e.id] = e
	end
	local out: { Entry } = {}
	local seen: { [string]: boolean } = {}
	for _, id in tenants do
		if type(id) == "string" and not seen[id] then
			seen[id] = true
			table.insert(out, byId[id] or Directory.placeholder(id))
		end
	end
	return out
end

-- Directory entries filtered for a Directory tab ("open" = open firms only).
function Directory.filterOpen(entries: { Entry }, openOnly: boolean): { Entry }
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

-- "Investment Banking · Sales & Trading" (open departments only unless all = true).
function Directory.departmentLine(entry: Entry, all: boolean?): string
	local names: { string } = {}
	for _, d in entry.departments do
		if all or d.available then
			table.insert(names, d.name)
		end
	end
	if #names == 0 then
		return Text.get("departments_none")
	end
	return table.concat(names, Text.get("departments_sep"))
end

return Directory
