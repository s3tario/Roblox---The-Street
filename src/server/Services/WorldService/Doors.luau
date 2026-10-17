--!strict
-- WorldService/Doors (server, runtime): one ProximityPrompt per door, created on the server.
--   * World doors: every CollectionService "Door"-tagged part in Workspace whose DoorId is in Config/World.doors
--     (Build/Kit.door), including doors added later and doors that only move into Workspace after being tagged.
--   * Office template doors: parts with attribute OfficeDoor = "exit" | "to_lobby" inside cloned office floors
--     (tagged or not; Doors.wireModel scans each new floor). They carry CompanyId (stamped on clone).
-- Templates in ServerStorage never get prompts. The prompt carries attributes the client reads: DoorId or
-- OfficeDoor, DoorKind, CompanyId and ActionBase (the unlocked ActionText, so WorldController can show
-- "Locked" locally and restore it).
--
--   Doors.start(handlers)    handlers = { world = fn(player, doorId, def, part), office = fn(player, kind, part) }
--   Doors.wireModel(model)   wires every office door inside a freshly cloned floor
--   Doors.companyOf(inst) -> companyId?

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local DoorRules = require(Shared.Logic.DoorRules)

local Doors = {}

Doors.TAG = "Door"
Doors.PROMPT_NAME = "DoorPrompt"
Doors.DEBOUNCE = 1
Doors.MAX_DISTANCE = 12

export type Handlers = {
	world: (player: Player, doorId: string, def: { [string]: any }, part: BasePart) -> (),
	office: (player: Player, kind: string, part: BasePart) -> (),
}

local handlers: Handlers? = nil
local wired: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local waiting: { [Instance]: RBXScriptConnection } = setmetatable({}, { __mode = "k" }) :: any
local lastUse: { [Player]: number } = {}
local warned: { [string]: boolean } = {}

local doorDefs = World.doors :: { [string]: { [string]: any } }

function Doors.companyOf(inst: Instance): string?
	local node: Instance? = inst
	while node and node ~= workspace and node ~= game do
		local id = node:GetAttribute("CompanyId")
		if type(id) == "string" and id ~= "" then
			return id
		end
		node = node.Parent
	end
	return nil
end

local function warnOnce(key: string, text: string)
	if not warned[key] then
		warned[key] = true
		warn("[WorldService] " .. text)
	end
end

local function makePrompt(part: BasePart, action: string, object: string): ProximityPrompt
	local existing = part:FindFirstChild(Doors.PROMPT_NAME)
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Doors.PROMPT_NAME
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Doors.MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("ActionBase", action)
	return prompt
end

local function debounce(player: Player): boolean
	local now = os.clock()
	if now - (lastUse[player] or -math.huge) < Doors.DEBOUNCE then
		return false
	end
	lastUse[player] = now
	return true
end

local function run(label: string, fn: () -> ())
	task.spawn(function()
		local ok, err = pcall(function(): string?
			fn()
			return nil
		end)
		if not ok then
			warn(("[WorldService] %s failed: %s"):format(label, tostring(err)))
		end
	end)
end

local function wireOffice(part: BasePart, kind: string)
	if not DoorRules.OFFICE_DOORS[kind] then
		warnOnce("office:" .. kind, ("unknown OfficeDoor kind %q on %s"):format(kind, part:GetFullName()))
		return
	end
	local action, object = DoorRules.officeDoorText(kind)
	local prompt = makePrompt(part, action, object)
	prompt:SetAttribute("OfficeDoor", kind)
	prompt:SetAttribute("DoorKind", "office_" .. kind)
	local companyId = Doors.companyOf(part)
	if companyId then
		prompt:SetAttribute("CompanyId", companyId)
	end
	prompt.Triggered:Connect(function(player: Player)
		local h = handlers
		if not h or player.Parent ~= Players or not debounce(player) then
			return
		end
		run("office door " .. kind, function()
			h.office(player, kind, part)
		end)
	end)
	prompt.Parent = part
end

local function wireWorld(part: BasePart, doorId: string)
	local def = doorDefs[doorId]
	if not def then
		warnOnce("door:" .. doorId, ("door %q (%s) is not in Config/World.doors"):format(doorId, part:GetFullName()))
		return
	end
	local kind = DoorRules.kind(def)
	if not kind then
		warnOnce("kind:" .. doorId, ("door %q has no target, ride, company or picker"):format(doorId))
		return
	end
	local action, object = DoorRules.promptText(def)
	local prompt = makePrompt(part, action, object)
	prompt:SetAttribute("DoorId", doorId)
	prompt:SetAttribute("DoorKind", kind)
	prompt.Triggered:Connect(function(player: Player)
		local h = handlers
		if not h or player.Parent ~= Players or not debounce(player) then
			return
		end
		run("door " .. doorId, function()
			h.world(player, doorId, def, part)
		end)
	end)
	prompt.Parent = part
end

local function wire(part: BasePart)
	if wired[part] then
		return
	end
	local officeKind = part:GetAttribute("OfficeDoor")
	local doorId = part:GetAttribute("DoorId")
	if type(officeKind) == "string" and officeKind ~= "" then
		wired[part] = true
		wireOffice(part, officeKind)
	elseif type(doorId) == "string" and doorId ~= "" then
		wired[part] = true
		wireWorld(part, doorId)
	end
end

local function watch(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	if inst:IsDescendantOf(workspace) then
		wire(inst)
		return
	end
	if waiting[inst] then
		return
	end
	waiting[inst] = inst.AncestryChanged:Connect(function()
		if inst:IsDescendantOf(workspace) or inst.Parent == nil then
			local conn = waiting[inst]
			waiting[inst] = nil
			if conn then
				conn:Disconnect()
			end
			if inst.Parent ~= nil then
				wire(inst)
			end
		end
	end)
end

function Doors.wireModel(model: Instance)
	if not model:IsDescendantOf(workspace) then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("OfficeDoor") ~= nil then
			wire(d)
		end
	end
end

function Doors.forget(player: Player)
	lastUse[player] = nil
end

function Doors.start(h: Handlers)
	handlers = h
	CollectionService:GetInstanceAddedSignal(Doors.TAG):Connect(watch)
	for _, inst in CollectionService:GetTagged(Doors.TAG) do
		watch(inst)
	end
end

return Doors
