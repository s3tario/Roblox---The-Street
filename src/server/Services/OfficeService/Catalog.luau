--!strict
-- OfficeService/Catalog (server, runtime): the companies, tracks and baked templates the office system can open,
-- loaded once and normalized through Logic/OfficeAlloc so a missing or reshaped Config/Companies / Config/Tracks
-- (owned by careerPath) never breaks offices: unknown firms simply show as "Opening soon".
--
--   Catalog.get() -> Catalog          { byId, list, tracks, templates, directory } (loaded on first use)
--   Catalog.company(id) -> Company?
--   Catalog.templatesFolder() -> Instance?    ServerStorage.FirmTemplates
--   Catalog.template(templateId) -> Instance? one baked template ("lobby" or a track id)
--   Catalog.logos() -> any?                   Shared/Assets/Logos (guarded require)
--   Catalog.departmentName(floor) -> string   "Lobby" or the track's name
--   Catalog.floors(company) -> { FloorEntry } the elevator panel's list (lobby first, then departments)
--   Catalog.elevatorPayload(company, current?) -> ElevatorPayload   what Office.OpenElevator sends

local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)
local DoorRules = require(Shared.Logic.DoorRules)

local Text = DoorRules.Text
local LOBBY = OfficeAlloc.LOBBY

local Catalog = {}

export type State = {
	loaded: boolean,
	byId: { [string]: OfficeAlloc.Company },
	list: { OfficeAlloc.Company },
	tracks: { [string]: OfficeAlloc.Track },
	templates: { [string]: boolean },
	directory: { OfficeAlloc.Entry },
}

export type FloorEntry = { id: string, name: string, floor: number, available: boolean }
export type ElevatorPayload = {
	companyId: string,
	name: string,
	short: string,
	logo: string,
	primary: Color3?,
	accent: Color3?,
	current: string?,
	floors: { FloorEntry },
	outage: boolean?,
}

local state: State = { loaded = false, byId = {}, list = {}, tracks = {}, templates = {}, directory = {} }

local function optionalModule(parent: Instance?, name: string): any
	local mod = if parent then parent:FindFirstChild(name) else nil
	if not (mod and mod:IsA("ModuleScript")) then
		return nil
	end
	local ok, result = pcall(function()
		return (require :: any)(mod)
	end)
	if not ok then
		warn(("[OfficeService] couldn't load %s: %s"):format(mod:GetFullName(), tostring(result)))
		return nil
	end
	return result
end
Catalog.optionalModule = optionalModule

function Catalog.templatesFolder(): Instance?
	return ServerStorage:FindFirstChild("FirmTemplates")
end

function Catalog.template(templateId: string): Instance?
	local folder = Catalog.templatesFolder()
	return if folder then folder:FindFirstChild(templateId) else nil
end

-- Without Config/Companies, the Street's firms are listed by their tower names, all "Opening soon".
local function towerPlaceholders(byId: { [string]: OfficeAlloc.Company }, list: { OfficeAlloc.Company })
	for _, t in World.towers do
		local ids: { string } = {}
		local labels: { [string]: string } = {}
		local own = t.company
		if own then
			table.insert(ids, own)
			labels[own] = t.label
		end
		local picker = t.picker
		if picker then
			for _, id in picker do
				table.insert(ids, id)
				labels[id] = labels[id] or DoorRules.prettify(id)
			end
		end
		for _, id in ids do
			if byId[id] == nil then
				local c = OfficeAlloc.normalizeCompany({ id = id, name = labels[id], departments = {} })
				if c then
					byId[id] = c
					table.insert(list, c)
				end
			end
		end
	end
end

function Catalog.get(): State
	if state.loaded then
		return state
	end
	state.loaded = true
	local config = Shared:FindFirstChild("Config")
	local byId, list = OfficeAlloc.normalizeCompanies(optionalModule(config, "Companies"))
	if #list == 0 then
		warn("[OfficeService] Config/Companies missing or empty; every office shows as opening soon")
		towerPlaceholders(byId, list)
	end
	state.byId = byId
	state.list = list
	state.tracks = OfficeAlloc.normalizeTracks(optionalModule(config, "Tracks"))
	local templates: { [string]: boolean } = {}
	local folder = Catalog.templatesFolder()
	if folder then
		for _, child in folder:GetChildren() do
			templates[child.Name] = true
		end
	else
		warn("[OfficeService] ServerStorage.FirmTemplates is missing; offices can't open")
	end
	state.templates = templates
	state.directory = OfficeAlloc.directory(list, templates, state.tracks)
	return state
end

function Catalog.company(id: any): OfficeAlloc.Company?
	if type(id) ~= "string" then
		return nil
	end
	return Catalog.get().byId[id]
end

local logosModule: any = nil
function Catalog.logos(): any
	if logosModule == nil then
		logosModule = optionalModule(Shared:FindFirstChild("Assets"), "Logos") or false
	end
	return if logosModule then logosModule else nil
end

function Catalog.departmentName(floor: string): string
	if floor == LOBBY then
		return Text.get("lobby")
	end
	return OfficeAlloc.departmentName(floor, Catalog.get().tracks)
end

function Catalog.floors(company: OfficeAlloc.Company): { FloorEntry }
	local s = Catalog.get()
	local out: { FloorEntry } = {
		{ id = LOBBY, name = Text.get("lobby"), floor = 0, available = s.templates[LOBBY] == true },
	}
	for _, d in OfficeAlloc.departments(company, s.templates, s.tracks) do
		table.insert(out, { id = d.id, name = d.name, floor = d.floor, available = d.available })
	end
	return out
end

function Catalog.elevatorPayload(company: OfficeAlloc.Company, current: string?, outage: boolean?): ElevatorPayload
	return {
		companyId = company.id,
		name = company.name,
		short = company.short,
		logo = company.logo,
		primary = company.primary,
		accent = company.accent,
		current = current,
		floors = Catalog.floors(company),
		outage = outage == true,
	}
end

return Catalog
