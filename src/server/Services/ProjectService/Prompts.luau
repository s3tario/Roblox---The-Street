--!strict
-- ProjectService/Prompts (server, runtime only): the "project_desk" interact (Config/World.interactIds.project_desk).
--
-- Every CollectionService "Interact"-tagged instance with InteractId = "project_desk" under Workspace gets one
-- ProximityPrompt (named "ProjectPrompt", attribute InteractId = "project_desk"), including instances added later
-- (office floors are cloned at runtime) and instances that move into Workspace after being tagged. Templates in
-- ServerStorage never get a prompt, so clones never inherit a stale one.
--   * Inside an office instance (an ancestor carries attribute CompanyId) the prompt gets CompanyId = <id> and
--     EmployeesOnly = true: the client hides it for visitors, the server refuses them politely.
--   * Anywhere else it gets EmployedOnly = true: deals need a job, so the client hides it for students.
-- The company is re-read when the prompt fires (OfficeService may stamp CompanyId after parenting the clone).
--
--   Prompts.start(onTriggered)            onTriggered(player, prompt, companyId?) for every trigger (pcall'd)
--   Prompts.companyOf(inst) -> companyId?
--   Prompts.PROMPT_NAME, Prompts.INTERACT_ID

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("Logic"):WaitForChild("Projects"):WaitForChild("_registry"))

local Prompts = {}

Prompts.INTERACT_ID = "project_desk"
Prompts.PROMPT_NAME = "ProjectPrompt"
Prompts.TAG = "Interact"

type Handler = (player: Player, prompt: ProximityPrompt, companyId: string?) -> ()

-- prompts already wired (weak: a destroyed floor takes its prompts and their connections with it)
local wired: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- tagged instances outside Workspace waiting to move in
local waiting: { [Instance]: RBXScriptConnection } = setmetatable({}, { __mode = "k" }) :: any

function Prompts.companyOf(inst: Instance): string?
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

local function promptParent(inst: Instance): Instance?
	if inst:IsA("BasePart") or inst:IsA("Attachment") then
		return inst
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function mark(prompt: ProximityPrompt, companyId: string?)
	if companyId then
		prompt:SetAttribute("CompanyId", companyId)
		prompt:SetAttribute("EmployeesOnly", true)
		prompt:SetAttribute("EmployedOnly", nil)
	elseif prompt:GetAttribute("EmployeesOnly") ~= true then
		prompt:SetAttribute("EmployedOnly", true)
	end
end

local function wire(inst: Instance, onTriggered: Handler)
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
		prompt.ActionText = Registry.text("prompt_action")
		prompt.ObjectText = Registry.text("prompt_object")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	end
	prompt:SetAttribute("InteractId", Prompts.INTERACT_ID)
	mark(prompt, Prompts.companyOf(inst))
	wired[prompt] = true
	prompt.Triggered:Connect(function(player: Player)
		local companyId = Prompts.companyOf(inst) or Prompts.companyOf(prompt)
		if companyId and prompt:GetAttribute("EmployeesOnly") ~= true then
			mark(prompt, companyId)
		end
		local ok, err = pcall(function()
			onTriggered(player, prompt, companyId)
		end)
		if not ok then
			warn("[ProjectService] deal desk prompt failed: " .. tostring(err))
		end
	end)
	if prompt.Parent ~= parent then
		prompt.Parent = parent
	end
	-- OfficeService may stamp CompanyId right after parenting the clone: check again once that settles
	task.defer(function()
		if prompt.Parent and prompt:GetAttribute("EmployeesOnly") ~= true then
			local companyId = Prompts.companyOf(inst)
			if companyId then
				mark(prompt, companyId)
			end
		end
	end)
end

local function watch(inst: Instance, onTriggered: Handler)
	if inst:GetAttribute("InteractId") ~= Prompts.INTERACT_ID then
		return
	end
	if inst:IsDescendantOf(workspace) then
		wire(inst, onTriggered)
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
			wire(inst, onTriggered)
		elseif inst.Parent == nil then
			-- destroyed before it ever reached the world: let go of the connection
			local conn = waiting[inst]
			waiting[inst] = nil
			if conn then
				conn:Disconnect()
			end
		end
	end)
end

function Prompts.start(onTriggered: Handler)
	CollectionService:GetInstanceAddedSignal(Prompts.TAG):Connect(function(inst: Instance)
		watch(inst, onTriggered)
	end)
	for _, inst in CollectionService:GetTagged(Prompts.TAG) do
		watch(inst, onTriggered)
	end
end

return Prompts
