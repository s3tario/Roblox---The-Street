--!strict
-- TutorialService/Waypoints (server, runtime only): turns a step's Config/Quests waypoint spec into a world position
-- for the gold arrow (QuestService:SetWaypoint -> "Quest.Waypoint"). The server sees the whole world, so this works
-- with StreamingEnabled; the client only draws a local marker at the position it is sent.
--
--   Waypoints.resolve(player, spec, ctx) -> (Vector3?, label?)
--       ctx = { career, campus }   nil when the target doesn't exist (yet): the caller simply tries again later
--   Waypoints.towerDoorFor(companyId) -> doorId?

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local Npcs = require(Shared.Config.Npcs)
local Companies = require(Shared.Config.Companies)
local Deps = require(script.Parent.Deps)
local Interacts = require(script.Parent.Interacts)

local Waypoints = {}

type Ctx = { career: { [string]: any }, campus: { [string]: any } }

local function positionOf(inst: Instance?): Vector3?
	if not inst then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst.Position
	end
	if inst:IsA("Model") then
		local ok, pivot = pcall(function()
			return inst:GetPivot()
		end)
		if ok then
			return pivot.Position
		end
	end
	if inst:IsA("Attachment") then
		return inst.WorldPosition
	end
	return nil
end

local function rootPos(player: Player): Vector3?
	local root = Deps.root(player)
	return if root then root.Position else nil
end

local function nearest(player: Player, list: { Instance }): Instance?
	local from = rootPos(player)
	local best: Instance? = nil
	local bestD = math.huge
	for _, inst in list do
		local p = positionOf(inst)
		if p then
			local d = if from then (p - from).Magnitude else 0
			if d < bestD then
				best, bestD = inst, d
			end
		end
	end
	return best
end

local function tagged(tag: string, attr: string, value: string, filter: ((Instance) -> boolean)?): { Instance }
	local out: { Instance } = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:GetAttribute(attr) == value and inst:IsDescendantOf(workspace) and (not filter or filter(inst)) then
			table.insert(out, inst)
		end
	end
	return out
end

function Waypoints.towerDoorFor(companyId: string): string?
	for _, t in World.towers do
		if t.company == companyId then
			return t.door
		end
	end
	for _, t in World.towers do
		if t.picker and table.find(t.picker, companyId) then
			return t.door
		end
	end
	return nil
end

local function npcPos(npcId: string): Vector3?
	local ok, pos = Deps.call("NpcService", "GetNpcPosition", npcId)
	if ok and typeof(pos) == "Vector3" then
		return pos
	end
	local spots = tagged("Interact", "NpcId", npcId)
	local first = spots[1]
	return positionOf(first)
end

local function floorFor(spec: any, career: { [string]: any }): string
	if spec.floor == "track" then
		return if type(career.track) == "string" and career.track ~= "" then career.track else "ib"
	end
	return if type(spec.floor) == "string" then spec.floor else "lobby"
end

local function officeInteract(player: Player, career: { [string]: any }, floor: string, id: string): Instance?
	local ok, model = Deps.call("OfficeService", "GetFloor", career.companyId, floor)
	if not ok or typeof(model) ~= "Instance" then
		return nil
	end
	local list: { Instance } = {}
	for _, d in (model :: Instance):GetDescendants() do
		if d:GetAttribute("InteractId") == id then
			table.insert(list, d)
		end
	end
	return nearest(player, list)
end

function Waypoints.resolve(player: Player, spec: any, ctx: Ctx): (Vector3?, string?)
	if type(spec) ~= "table" then
		return nil, nil
	end
	local career = ctx.career
	local kind = spec.kind
	if kind == "door" then
		local inst = nearest(player, tagged("Door", "DoorId", spec.id))
		local def = World.doors[spec.id]
		return positionOf(inst), if def then def.label else nil
	elseif kind == "interact" then
		local list = tagged("Interact", "InteractId", spec.id, function(inst: Instance): boolean
			if Interacts.companyOf(inst) ~= nil then
				return false
			end
			if spec.zone then
				local p = positionOf(inst)
				return p ~= nil and World.zoneAt(p) == spec.zone
			end
			return true
		end)
		if #list == 0 and spec.zone then
			-- the zone filter found nothing: any matching interact outside offices will do
			list = tagged("Interact", "InteractId", spec.id, function(inst: Instance): boolean
				return Interacts.companyOf(inst) == nil
			end)
		end
		local prompt = World.interactIds[spec.id]
		return positionOf(nearest(player, list)), if prompt then prompt.prompt else nil
	elseif kind == "npc" then
		local def = Npcs.get(spec.id)
		return npcPos(spec.id), if def then def.name else nil
	elseif kind == "npcNext" then
		local ids = if type(spec.ids) == "table" then spec.ids else {}
		local met = if type(ctx.campus.network) == "table" and type(ctx.campus.network.ids) == "table"
			then ctx.campus.network.ids
			else {}
		local from = rootPos(player)
		local bestPos: Vector3? = nil
		local bestName: string? = nil
		local bestD = math.huge
		for _, npcId in ids do
			if met["npc:" .. npcId] ~= true then
				local p = npcPos(npcId)
				if p then
					local d = if from then (p - from).Magnitude else 0
					if d < bestD then
						local def = Npcs.get(npcId)
						bestPos, bestName, bestD = p, if def then def.name else nil, d
					end
				end
			end
		end
		return bestPos, bestName
	elseif kind == "tower" then
		local doorId = Waypoints.towerDoorFor(career.companyId)
		if not doorId then
			return nil, nil
		end
		local company = Companies.get(career.companyId)
		return positionOf(nearest(player, tagged("Door", "DoorId", doorId))), if company then company.name else nil
	elseif kind == "office" then
		local ok, anchor =
			Deps.call("OfficeService", "GetAnchor", career.companyId, floorFor(spec, career), spec.anchor)
		if ok and typeof(anchor) == "Instance" then
			return positionOf(anchor), nil
		end
		return nil, nil
	elseif kind == "officeInteract" then
		local floor = floorFor(spec, career)
		local prompt = World.interactIds[spec.id]
		return positionOf(officeInteract(player, career, floor, spec.id)), if prompt then prompt.prompt else nil
	elseif kind == "boss" then
		local track = floorFor({ floor = "track" }, career)
		local ok, npc = Deps.call("OfficeService", "GetBossNpc", career.companyId, track)
		local name = if type(career.bossName) == "string" then career.bossName else nil
		if ok and typeof(npc) == "Instance" then
			return positionOf(npc), name
		end
		local okA, anchor = Deps.call("OfficeService", "GetAnchor", career.companyId, track, "boss_chair")
		if okA and typeof(anchor) == "Instance" then
			return positionOf(anchor), name
		end
		return nil, nil
	elseif kind == "desk" then
		local track = floorFor({ floor = "track" }, career)
		local ok, model = Deps.call("OfficeService", "GetFloor", career.companyId, track)
		if ok and typeof(model) == "Instance" then
			for _, d in (model :: Instance):GetDescendants() do
				if d:GetAttribute("OwnerUserId") == player.UserId then
					local p = positionOf(d)
					if p then
						return p, nil
					end
				end
			end
		end
		return positionOf(officeInteract(player, career, track, "work_desk")), nil
	elseif kind == "anchor" then
		local ok, anchor = Deps.call("WorldService", "GetAnchor", spec.id)
		if ok and typeof(anchor) == "Instance" then
			return positionOf(anchor), nil
		end
		return nil, nil
	end
	return nil, nil
end

return Waypoints
