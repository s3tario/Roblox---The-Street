--!strict
-- OfficeAlloc (offices, PURE): the bookkeeping behind per-company office instances (spec v3 §14).
--   * instance slots: each company present on a server gets the lowest free instance index; freed indices are
--     reused (World.officeOrigin(index, floor) places it)
--   * floors: floor 0 is the lobby, department i (1-based, in the company's department order) is floor i
--   * cleanup: floors nobody has been inside for `ttl` seconds expire
--   * the elevator panel's rows
--   * NPC desks: picks free desks for ambient coworkers
--   * companies, departments, the Directory and tower pickers: OfficeAlloc/Directory (re-exported here)
-- No services, no clocks, no Instances.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local Text = require(script.Parent.DoorRules.Text)
local Directory = require(script.Directory)

local OfficeAlloc = {}

OfficeAlloc.LOBBY = Directory.LOBBY
OfficeAlloc.EMPTY_TTL = 180 -- seconds a floor may stay empty before it is removed
OfficeAlloc.MIN_COWORKERS = 4
OfficeAlloc.MAX_COWORKERS = 8
OfficeAlloc.BUSY_FLOORS = 6 -- with this many live floors, floors get the minimum number of coworkers

export type Company = Directory.Company
export type Track = Directory.Track
export type DeptEntry = Directory.DeptEntry
export type Entry = Directory.Entry

OfficeAlloc.Directory = Directory
OfficeAlloc.toColor = Directory.toColor
OfficeAlloc.initials = Directory.initials
OfficeAlloc.prettify = Directory.prettify
OfficeAlloc.normalizeCompany = Directory.normalizeCompany
OfficeAlloc.normalizeCompanies = Directory.normalizeCompanies
OfficeAlloc.normalizeTracks = Directory.normalizeTracks
OfficeAlloc.departmentName = Directory.departmentName
OfficeAlloc.departments = Directory.departments
OfficeAlloc.isAvailable = Directory.isAvailable
OfficeAlloc.floorOpen = Directory.floorOpen
OfficeAlloc.streetOrder = Directory.streetOrder
OfficeAlloc.entry = Directory.entry
OfficeAlloc.directory = Directory.directory
OfficeAlloc.placeholder = Directory.placeholder
OfficeAlloc.pickerEntries = Directory.pickerEntries
OfficeAlloc.filterOpen = Directory.filterOpen
OfficeAlloc.departmentLine = Directory.departmentLine

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
-- Elevator panel
---------------------------------------------------------------------------------------------------
export type FloorLike = { id: string, name: string, floor: number, available: boolean }
export type ElevatorRow = {
	id: string,
	name: string,
	floor: number,
	badge: string, -- "L" for the lobby, else the floor number
	available: boolean,
	here: boolean,
}

-- The panel lists the top floor first (like a real elevator panel) and marks where the player is.
function OfficeAlloc.elevatorRows(floors: { FloorLike }, current: string?): { ElevatorRow }
	local rows: { ElevatorRow } = {}
	local seen: { [string]: boolean } = {}
	for _, f in floors do
		if type(f) == "table" and type(f.id) == "string" and not seen[f.id] and type(f.floor) == "number" then
			seen[f.id] = true
			table.insert(rows, {
				id = f.id,
				name = if type(f.name) == "string" then f.name else f.id,
				floor = f.floor,
				badge = if f.floor == 0 then Text.get("floor_short_lobby") else tostring(f.floor),
				available = f.available == true,
				here = f.id == current,
			})
		end
	end
	table.sort(rows, function(a, b)
		return a.floor > b.floor
	end)
	return rows
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
