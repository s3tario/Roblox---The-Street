--!strict
-- OfficeService/Prompts (server, runtime): the two interacts the offices feature owns (Config/World.interactIds):
--   elevator_panel     lobby elevator panel: anyone may ride (visitors included), so it is never EmployeesOnly
--   company_directory  street kiosks: opens the Company Directory
-- Every CollectionService "Interact"-tagged instance with one of these InteractIds that lives under Workspace gets
-- one ProximityPrompt, including instances added later (office floors are cloned at runtime) and instances that
-- only move into Workspace after being tagged. Templates in ServerStorage never get prompts.
-- When a prompt fires, the SERVER decides what opens (WardrobeService pattern): onTriggered(player, id, inst,
-- prompt) runs pcall'd and normally fires "Office.OpenElevator" / "Office.OpenDirectory" to that player.
--
--   Prompts.start(onTriggered)
--   Prompts.companyOf(inst) -> (companyId?, department?)   nearest ancestor (or self) carrying CompanyId

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local DoorRules = require(Shared.Logic.DoorRules)

local Text = DoorRules.Text

local Prompts = {}

Prompts.TAG = "Interact"
Prompts.PROMPT_NAME = "OfficesPrompt"
Prompts.OWNED = { elevator_panel = true, company_directory = true } :: { [string]: boolean }

type Handler = (player: Player, interactId: string, inst: Instance, prompt: ProximityPrompt) -> ()

local wired: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local waiting: { [Instance]: RBXScriptConnection } = setmetatable({}, { __mode = "k" }) :: any

function Prompts.companyOf(inst: Instance): (string?, string?)
	local node: Instance? = inst
	while node and node ~= workspace and node ~= game do
		local id = node:GetAttribute("CompanyId")
		if type(id) == "string" and id ~= "" then
			local dept = node:GetAttribute("Department")
			return id, if type(dept) == "string" and dept ~= "" then dept else nil
		end
		node = node.Parent
	end
	return nil, nil
end

local function promptParent(inst: Instance): Instance?
	local base: Instance? = nil
	if inst:IsA("BasePart") or inst:IsA("Attachment") then
		base = inst
	elseif inst:IsA("Model") then
		base = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	if base and base:IsA("BasePart") then
		local use = base:FindFirstChild("Use")
		if use and use:IsA("Attachment") then
			return use
		end
	end
	return base
end

local function objectText(interactId: string, inst: Instance, companyName: (string) -> string?): string
	if interactId == "elevator_panel" then
		local companyId = Prompts.companyOf(inst)
		local name = if companyId then companyName(companyId) else nil
		return name or Text.get("elevator_title")
	end
	return Text.get("directory_title")
end

local function wire(inst: Instance, interactId: string, onTriggered: Handler, companyName: (string) -> string?)
	local parent = promptParent(inst)
	if not parent then
		return
	end
	local existing = parent:FindFirstChild(Prompts.PROMPT_NAME)
	local prompt: ProximityPrompt
	if existing and existing:IsA("ProximityPrompt") then
		if wired[existing] then
			return
		end
		prompt = existing
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = Prompts.PROMPT_NAME
		local def = World.interactIds[interactId]
		prompt.ActionText = if def then def.prompt else Text.get("office_elevator")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	end
	prompt.ObjectText = objectText(interactId, inst, companyName)
	prompt:SetAttribute("InteractId", interactId)
	-- Elevators are open to visitors: tag the company for the client but never mark the prompt EmployeesOnly.
	local companyId = Prompts.companyOf(inst)
	if companyId then
		prompt:SetAttribute("CompanyId", companyId)
	end
	prompt:SetAttribute("EmployeesOnly", false)
	wired[prompt] = true
	prompt.Triggered:Connect(function(player: Player)
		local ok, err = pcall(onTriggered, player, interactId, inst, prompt)
		if not ok then
			warn(("[OfficeService] %s prompt failed: %s"):format(interactId, tostring(err)))
		end
	end)
	if prompt.Parent ~= parent then
		prompt.Parent = parent
	end
	-- OfficeService stamps CompanyId before parenting a clone, but a template moved in by another feature may get
	-- it a moment later: refresh the label once that settles.
	task.defer(function()
		if prompt.Parent then
			prompt.ObjectText = objectText(interactId, inst, companyName)
			local later = Prompts.companyOf(inst)
			if later then
				prompt:SetAttribute("CompanyId", later)
			end
		end
	end)
end

local function watch(inst: Instance, onTriggered: Handler, companyName: (string) -> string?)
	local interactId = inst:GetAttribute("InteractId")
	if type(interactId) ~= "string" or not Prompts.OWNED[interactId] then
		return
	end
	if inst:IsDescendantOf(workspace) then
		wire(inst, interactId, onTriggered, companyName)
		return
	end
	if waiting[inst] then
		return
	end
	waiting[inst] = inst.AncestryChanged:Connect(function()
		if inst:IsDescendantOf(workspace) then
			local conn = waiting[inst]
			waiting[inst] = nil
			if conn then
				conn:Disconnect()
			end
			wire(inst, interactId, onTriggered, companyName)
		elseif inst.Parent == nil then
			-- destroyed or dropped before it ever reached Workspace
			local conn = waiting[inst]
			waiting[inst] = nil
			if conn then
				conn:Disconnect()
			end
		end
	end)
end

-- companyName(id) -> display name (OfficeService's catalog).
function Prompts.start(onTriggered: Handler, companyName: (string) -> string?)
	CollectionService:GetInstanceAddedSignal(Prompts.TAG):Connect(function(inst: Instance)
		watch(inst, onTriggered, companyName)
	end)
	for _, inst in CollectionService:GetTagged(Prompts.TAG) do
		watch(inst, onTriggered, companyName)
	end
end

return Prompts
