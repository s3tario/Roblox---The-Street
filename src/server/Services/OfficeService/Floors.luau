--!strict
-- OfficeService/Floors (server, runtime): the live office instances and floors on this server.
-- One Model per company present ("Office_<companyId>" under Workspace.Offices, attribute CompanyId) holding its
-- lobby and department floors, each cloned lazily from ServerStorage.FirmTemplates, branded (Template.prepare)
-- and moved to World.officeOrigin(instanceIndex, floorIndex). Instance indices come from Logic/OfficeAlloc and
-- are reused once a company's last floor is gone.
--
--   Floors.bind(created, removed)                 the FloorCreated / FloorRemoved signals to fire
--   Floors.root() -> Folder                       Workspace.Offices
--   Floors.ensure(company, floor) -> (FloorState?, errKey?)   errKey "no_floor" | "opening_soon" | "full" | "error"
--   Floors.get(companyId, floor) -> FloorState?   a live floor
--   Floors.instance(companyId) -> InstanceState?
--   Floors.locate(position) -> (companyId?, floor?)   the live floor at a world position
--   Floors.arrival(fs, anchorName) -> CFrame      where a player arriving at that OfficeAnchor stands
--   Floors.sweep(occupied, now)                   removes floors empty for longer than OfficeAlloc.EMPTY_TTL
--   Floors.touch(fs, now)                         marks a floor occupied (a player just arrived)
--   Floors.liveCount() -> number
--   Floors.all() -> { FloorState }

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Time = require(Shared.Util.Time)
local World = require(Shared.Config.World)
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)
local Catalog = require(script.Parent.Catalog)
local Template = require(script.Parent.Template)
local Npcs = require(script.Parent.Npcs)

local LOBBY = OfficeAlloc.LOBBY

local Floors = {}

Floors.ROOT_NAME = "Offices"

local ARRIVE_LIFT = Vector3.new(0, 0.25, 0)
local ROOT_HEIGHT = 3.25 -- floor to HumanoidRootPart centre for the game's R15 characters, plus a hair
local GROUND_PROBE = 12
local ARRIVAL_FALLBACKS = { "entry", "floor_entry", "elevators", "review_spot" }

export type FloorState = {
	key: string,
	companyId: string,
	floor: string,
	floorIndex: number,
	instanceIndex: number,
	model: Model,
	anchors: { [string]: BasePart },
	rec: OfficeAlloc.FloorRec,
	alive: boolean,
}
export type InstanceState = { companyId: string, index: number, model: Model, floors: { [string]: FloorState } }

local alloc = OfficeAlloc.new()
local instances: { [string]: InstanceState } = {}
local floorRecs: { [string]: OfficeAlloc.FloorRec } = {}
local floorsByKey: { [string]: FloorState } = {}
local rootFolder: Folder? = nil
local warnedAnchors: { [string]: boolean } = {}
local createdSignal: Signal.Signal? = nil
local removedSignal: Signal.Signal? = nil

function Floors.bind(created: Signal.Signal, removed: Signal.Signal)
	createdSignal = created
	removedSignal = removed
end

function Floors.root(): Folder
	local f = rootFolder
	if f and f.Parent then
		return f
	end
	local existing = workspace:FindFirstChild(Floors.ROOT_NAME)
	if existing and existing:IsA("Folder") then
		rootFolder = existing
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = Floors.ROOT_NAME
	created.Parent = workspace
	rootFolder = created
	return created
end

local function warnOnce(key: string, text: string)
	if not warnedAnchors[key] then
		warnedAnchors[key] = true
		warn("[OfficeService] " .. text)
	end
end

---------------------------------------------------------------------------------------------------
-- Removal
---------------------------------------------------------------------------------------------------
local function releaseInstance(inst: InstanceState)
	if instances[inst.companyId] == inst then
		instances[inst.companyId] = nil
	end
	inst.model:Destroy()
	OfficeAlloc.release(alloc, inst.companyId)
end

local function removeFloor(key: string)
	local fs = floorsByKey[key]
	floorsByKey[key] = nil
	floorRecs[key] = nil
	if not fs then
		return
	end
	fs.alive = false
	local inst = instances[fs.companyId]
	if inst and inst.floors[fs.floor] == fs then
		inst.floors[fs.floor] = nil
	end
	fs.model:Destroy()
	local removed = removedSignal
	if removed then
		removed:Fire(fs.companyId, fs.floor)
	end
	if inst and next(inst.floors) == nil then
		releaseInstance(inst)
	end
end

---------------------------------------------------------------------------------------------------
-- Creation
---------------------------------------------------------------------------------------------------
local function ensureInstance(company: OfficeAlloc.Company): (InstanceState?, string?)
	local inst = instances[company.id]
	if inst and inst.model.Parent then
		return inst, nil
	elseif inst then
		-- something destroyed the instance model behind our back: drop its floors and start over
		local keys: { string } = {}
		for _, fs in inst.floors do
			table.insert(keys, fs.key)
		end
		for _, key in keys do
			removeFloor(key)
		end
		if instances[company.id] == inst then
			releaseInstance(inst)
		end
	end
	local index = OfficeAlloc.acquire(alloc, company.id)
	if index == nil then
		return nil, "full"
	end
	local model = Instance.new("Model")
	model.Name = "Office_" .. company.id
	model:SetAttribute("CompanyId", company.id)
	model:SetAttribute("CompanyName", company.name)
	model:SetAttribute("InstanceIndex", index)
	model.Parent = Floors.root()
	local fresh: InstanceState = { companyId = company.id, index = index, model = model, floors = {} }
	instances[company.id] = fresh
	return fresh, nil
end

local function spawnNpcs(fs: FloorState, company: OfficeAlloc.Company)
	local track = Catalog.get().tracks[fs.floor]
	local ctx: Npcs.Ctx = {
		model = fs.model,
		company = company,
		floor = fs.floor,
		departmentName = Catalog.departmentName(fs.floor),
		bossTitle = if track then track.topTitle else nil,
		anchors = fs.anchors,
		liveFloors = Floors.liveCount(),
		alive = function(): boolean
			return fs.alive and fs.model.Parent ~= nil
		end,
	}
	task.spawn(function()
		local ok, err = pcall(function(): string?
			Npcs.populate(ctx)
			return nil
		end)
		if not ok then
			warn(("[OfficeService] office NPCs for %s/%s failed: %s"):format(company.id, fs.floor, tostring(err)))
		end
	end)
end

local function cloneTemplate(template: Instance, floor: string): Model?
	local ok, cloned = pcall(function(): Instance
		return template:Clone()
	end)
	if not ok or typeof(cloned) ~= "Instance" then
		warn(("[OfficeService] couldn't clone template %s: %s"):format(floor, tostring(cloned)))
		return nil
	end
	if cloned:IsA("Model") then
		return cloned
	end
	-- a Folder (or a single part) template: wrap it so it can be pivoted and streamed as one unit
	local model = Instance.new("Model")
	cloned.Parent = model
	return model
end

function Floors.ensure(company: OfficeAlloc.Company, floor: string): (FloorState?, string?)
	local key = OfficeAlloc.floorKey(company.id, floor)
	local existing = floorsByKey[key]
	if existing and existing.alive and existing.model.Parent then
		return existing, nil
	elseif existing then
		removeFloor(key) -- something destroyed it behind our back
	end
	local floorIndex = OfficeAlloc.floorIndex(company.departments, floor)
	if floorIndex == nil then
		return nil, "no_floor"
	end
	local template = Catalog.template(floor)
	if not template then
		return nil, "opening_soon"
	end
	local inst, err = ensureInstance(company)
	if not inst then
		return nil, err
	end

	local model = cloneTemplate(template, floor)
	if not model then
		if next(inst.floors) == nil then
			releaseInstance(inst)
		end
		return nil, "error"
	end
	model.Name = if floor == LOBBY then "Lobby" else "Floor_" .. floor
	local okBrand, brandErr = pcall(Template.prepare, model, company, floor, Catalog.logos())
	if not okBrand then
		warn(("[OfficeService] branding %s/%s failed: %s"):format(company.id, floor, tostring(brandErr)))
	end
	model:SetAttribute("InstanceIndex", inst.index)
	model:SetAttribute("FloorIndex", floorIndex)
	-- Streamed as one unit, so a client never sees half a floor (and anchors arrive with their room).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- Templates are baked around the world origin: shift the clone's pivot (PrimaryPart-relative, rotation kept)
	-- by this instance/floor's origin.
	local origin = World.officeOrigin(inst.index, floorIndex)
	model:PivotTo(CFrame.new(origin) * model:GetPivot())
	local anchors = Template.anchors(model)
	model.Parent = inst.model

	local rec = OfficeAlloc.newFloor(company.id, floor, Time.now())
	local fs: FloorState = {
		key = key,
		companyId = company.id,
		floor = floor,
		floorIndex = floorIndex,
		instanceIndex = inst.index,
		model = model,
		anchors = anchors,
		rec = rec,
		alive = true,
	}
	floorsByKey[key] = fs
	floorRecs[key] = rec
	inst.floors[floor] = fs

	local created = createdSignal
	if created then
		created:Fire(company.id, floor, model)
	end
	spawnNpcs(fs, company)
	return fs, nil
end

---------------------------------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------------------------------
function Floors.get(companyId: string, floor: string): FloorState?
	local fs = floorsByKey[OfficeAlloc.floorKey(companyId, floor)]
	if fs and fs.alive and fs.model.Parent then
		return fs
	end
	return nil
end

function Floors.instance(companyId: string): InstanceState?
	local inst = instances[companyId]
	if inst and inst.model.Parent then
		return inst
	end
	return nil
end

function Floors.locate(pos: Vector3): (string?, string?)
	local i, f = World.officeAt(pos)
	if i == nil or f == nil then
		return nil, nil
	end
	local companyId = OfficeAlloc.companyAt(alloc, i)
	local inst = if companyId then instances[companyId] else nil
	if not inst then
		return nil, nil
	end
	for floorId, fs in inst.floors do
		if fs.floorIndex == f and fs.alive then
			return inst.companyId, floorId
		end
	end
	return nil, nil
end

function Floors.liveCount(): number
	local n = 0
	for _ in floorsByKey do
		n += 1
	end
	return n
end

function Floors.all(): { FloorState }
	local out: { FloorState } = {}
	for _, fs in floorsByKey do
		if fs.alive then
			table.insert(out, fs)
		end
	end
	return out
end

-- Upright at the anchor, facing its look direction, with the root at standing height above the floor below
-- (template anchors may sit at root height like Kit anchors, or on the floor).
local function standAt(fs: FloorState, cf: CFrame): CFrame
	local pos = cf.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { fs.model }
	params.IgnoreWater = true
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -GROUND_PROBE, 0), params)
	local y = if hit then math.max(pos.Y + ARRIVE_LIFT.Y, hit.Position.Y + ROOT_HEIGHT) else pos.Y + ARRIVE_LIFT.Y
	local at = Vector3.new(pos.X, y, pos.Z)
	local lv = cf.LookVector
	local f = Vector3.new(lv.X, 0, lv.Z)
	if f.Magnitude < 1e-3 then
		return CFrame.new(at)
	end
	return CFrame.lookAt(at, at + f.Unit)
end

function Floors.arrival(fs: FloorState, name: string): CFrame
	local anchor: BasePart? = fs.anchors[name]
	if not (anchor and anchor.Parent) then
		anchor = nil
		for _, alt in ARRIVAL_FALLBACKS do
			local a = fs.anchors[alt]
			if a and a.Parent then
				anchor = a
				break
			end
		end
	end
	if anchor then
		return standAt(fs, anchor.CFrame)
	end
	warnOnce(
		fs.floor .. "/" .. name,
		("template %s has no OfficeAnchor %q; arriving at the floor origin"):format(fs.floor, name)
	)
	return CFrame.new(World.officeOrigin(fs.instanceIndex, fs.floorIndex) + Vector3.new(0, 5, 0))
end

---------------------------------------------------------------------------------------------------
-- Occupancy
---------------------------------------------------------------------------------------------------
function Floors.touch(fs: FloorState, now: number)
	fs.rec.lastOccupied = math.max(fs.rec.lastOccupied, now)
end

function Floors.sweep(occupied: { [string]: boolean }, now: number)
	for _, key in OfficeAlloc.sweep(floorRecs, occupied, now) do
		removeFloor(key)
	end
	-- floors something else destroyed (a reset, an admin command): drop the bookkeeping too
	local dead: { string } = {}
	for key, fs in floorsByKey do
		if fs.model.Parent == nil then
			table.insert(dead, key)
		end
	end
	for _, key in dead do
		removeFloor(key)
	end
end

return Floors
