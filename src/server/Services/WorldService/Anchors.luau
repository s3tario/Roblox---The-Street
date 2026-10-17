--!strict
-- WorldService/Anchors (server, runtime): the named CFrame markers of the exterior regions and venues
-- (Config/World.anchors; Build/Kit.anchor parts: attribute AnchorId, tag "Anchor") and the stage spawns.
-- The server always has every part (StreamingEnabled only limits clients), so the index is complete once the
-- baked world is loaded. Anchors inside office instances belong to OfficeService and are ignored here.
--
--   Anchors.start(officeRoot?)      index tagged anchors in Workspace, including ones added later
--   Anchors.get(anchorId) -> BasePart?
--   Anchors.cframe(anchorId) -> CFrame?          upright, facing the anchor's look direction, lifted a touch
--   Anchors.arrival(part) -> CFrame
--   Anchors.spawnLocation(name) -> SpawnLocation?   "Spawn_campus" / "Spawn_street" anywhere in Workspace
--   Anchors.spawnCFrame(name) -> CFrame?          standing on that SpawnLocation (or its World.spawns anchor)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)

local Anchors = {}

Anchors.TAG = "Anchor"

local LIFT = Vector3.new(0, 0.25, 0)
local ROOT_HEIGHT = 3.25 -- floor to HumanoidRootPart centre for the game's R15 characters, plus a hair
local GROUND_PROBE = 12
local SPAWN_STAND = 3.2 -- studs above a SpawnLocation's top face for the character's root

local byId: { [string]: BasePart } = {}
local spawnCache: { [string]: SpawnLocation } = {}
local warned: { [string]: boolean } = {}
local excluded: Instance? = nil

local function isOfficeMarker(part: Instance): boolean
	if part:GetAttribute("OfficeAnchor") ~= nil then
		return true
	end
	local root = excluded
	return root ~= nil and part:IsDescendantOf(root)
end

local function add(inst: Instance)
	if not inst:IsA("BasePart") or not inst:IsDescendantOf(workspace) or isOfficeMarker(inst) then
		return
	end
	local id = inst:GetAttribute("AnchorId")
	if type(id) ~= "string" or id == "" then
		return
	end
	local existing = byId[id]
	if existing and existing ~= inst and existing.Parent and existing:IsDescendantOf(workspace) then
		if not warned["dup:" .. id] then
			warned["dup:" .. id] = true
			warn(
				("[WorldService] duplicate anchor %q (%s and %s); keeping the first"):format(
					id,
					existing:GetFullName(),
					inst:GetFullName()
				)
			)
		end
		return
	end
	byId[id] = inst
end

local function remove(inst: Instance)
	local id = inst:GetAttribute("AnchorId")
	if type(id) == "string" and byId[id] == inst then
		byId[id] = nil
	end
end

function Anchors.start(officeRoot: Instance?)
	excluded = officeRoot
	CollectionService:GetInstanceAddedSignal(Anchors.TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Anchors.TAG):Connect(remove)
	for _, inst in CollectionService:GetTagged(Anchors.TAG) do
		add(inst)
	end
end

-- Untagged anchors (a hand-made part with only the attribute) are found by name as a fallback.
local function search(anchorId: string): BasePart?
	for _, rootName in { "World", "Handmade" } do
		local root = workspace:FindFirstChild(rootName)
		local found = if root then root:FindFirstChild(anchorId, true) else nil
		if found and found:IsA("BasePart") and found:GetAttribute("AnchorId") == anchorId then
			return found
		end
	end
	return nil
end

function Anchors.get(anchorId: string): BasePart?
	local part = byId[anchorId]
	if part and part.Parent and part:IsDescendantOf(workspace) then
		return part
	end
	byId[anchorId] = nil
	local found = search(anchorId)
	if found then
		byId[anchorId] = found
		return found
	end
	if not warned[anchorId] then
		warned[anchorId] = true
		warn(("[WorldService] anchor %q is missing from the world"):format(anchorId))
	end
	return nil
end

-- Where a character's root stands at this anchor: Kit anchors sit at root height already, but a marker placed
-- on the floor is lifted so the feet land on the floor instead of inside it.
local function grounded(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local chars: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(chars, p.Character)
		end
	end
	params.FilterDescendantsInstances = chars
	params.IgnoreWater = true
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -GROUND_PROBE, 0), params)
	if hit then
		return Vector3.new(pos.X, math.max(pos.Y + LIFT.Y, hit.Position.Y + ROOT_HEIGHT), pos.Z)
	end
	return pos + LIFT
end

function Anchors.arrival(part: BasePart): CFrame
	local cf = part.CFrame
	local lv = cf.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	local pos = grounded(cf.Position)
	if flat.Magnitude < 1e-3 then
		return CFrame.new(pos)
	end
	return CFrame.lookAt(pos, pos + flat.Unit)
end

function Anchors.cframe(anchorId: string): CFrame?
	local part = Anchors.get(anchorId)
	return if part then Anchors.arrival(part) else nil
end

function Anchors.spawnLocation(name: string): SpawnLocation?
	local cached = spawnCache[name]
	if cached and cached.Parent and cached:IsDescendantOf(workspace) then
		return cached
	end
	spawnCache[name] = nil
	local found = workspace:FindFirstChild(name, true)
	if found and found:IsA("SpawnLocation") then
		spawnCache[name] = found
		return found
	end
	return nil
end

function Anchors.spawnCFrame(name: string): CFrame?
	local spawn = Anchors.spawnLocation(name)
	if spawn then
		local top = spawn.CFrame * CFrame.new(0, spawn.Size.Y / 2 + SPAWN_STAND, 0)
		local lv = spawn.CFrame.LookVector
		local flat = Vector3.new(lv.X, 0, lv.Z)
		if flat.Magnitude < 1e-3 then
			return CFrame.new(top.Position)
		end
		return CFrame.lookAt(top.Position, top.Position + flat.Unit)
	end
	local def = (World.spawns :: { [string]: any })[name]
	if type(def) == "table" and type(def.anchor) == "string" then
		return Anchors.cframe(def.anchor)
	end
	return nil
end

return Anchors
