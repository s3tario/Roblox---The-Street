--!strict
-- WorkService/Prompts (server, runtime only): the "work_desk" interact (Config/World.interactIds.work_desk).
--
-- Every CollectionService "Interact"-tagged instance with InteractId = "work_desk" under Workspace gets one
-- ProximityPrompt (named "WorkPrompt", attribute InteractId = "work_desk"), including instances added later (office
-- floors are cloned at runtime) and instances that move into Workspace after being tagged. Templates in
-- ServerStorage never get a prompt.
--   * Inside an office instance (an ancestor carries attribute CompanyId) the prompt gets CompanyId = <id> and
--     EmployeesOnly = true: the client hides it for visitors, the server refuses them.
--   * Anywhere else it's a campus desk: StudentsOnly = true (the client hides it once you're employed).
-- The desks are also remembered (weakly) so WorkService can tell whether a player is working at a desk they may use.
--
--   Prompts.start(onTriggered)            onTriggered(player, part, companyId?) for every trigger (pcall'd)
--   Prompts.companyOf(inst) -> companyId?
--   Prompts.desks() -> { [BasePart]: true } the wired desk parts still in the world
--   Prompts.PROMPT_NAME, Prompts.INTERACT_ID

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Tasks)

local Prompts = {}

Prompts.INTERACT_ID = "work_desk"
Prompts.PROMPT_NAME = "WorkPrompt"
Prompts.TAG = "Interact"

type Handler = (player: Player, part: BasePart, companyId: string?) -> ()

local wired: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local deskParts: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any
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

local function promptParent(inst: Instance): BasePart?
	if inst:IsA("BasePart") then
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
		prompt:SetAttribute("StudentsOnly", nil)
	else
		prompt:SetAttribute("StudentsOnly", true)
	end
end

local function wire(inst: Instance, onTriggered: Handler)
	local part = promptParent(inst)
	if not part then
		return
	end
	local existing = part:FindFirstChild(Prompts.PROMPT_NAME)
	local prompt: ProximityPrompt
	if existing and existing:IsA("ProximityPrompt") then
		if wired[existing] then
			return
		end
		prompt = existing
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = Prompts.PROMPT_NAME
		prompt.ActionText = Config.text("prompt")
		prompt.ObjectText = Config.text("prompt_object")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	end
	prompt:SetAttribute("InteractId", Prompts.INTERACT_ID)
	mark(prompt, Prompts.companyOf(inst))
	wired[prompt] = true
	deskParts[part] = true
	prompt.Triggered:Connect(function(player: Player)
		-- re-read the company at trigger time: OfficeService may stamp CompanyId after parenting the clone
		local companyId = Prompts.companyOf(inst) or Prompts.companyOf(prompt)
		if companyId and prompt:GetAttribute("EmployeesOnly") ~= true then
			mark(prompt, companyId)
		end
		local ok, err = pcall(onTriggered :: any, player, part, companyId)
		if not ok then
			warn("[WorkService] desk prompt failed: " .. tostring(err))
		end
	end)
	if prompt.Parent ~= part then
		prompt.Parent = part
	end
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

function Prompts.desks(): { [BasePart]: boolean }
	local out: { [BasePart]: boolean } = {}
	for part in deskParts do
		if part.Parent ~= nil and part:IsDescendantOf(workspace) then
			out[part] = true
		end
	end
	return out
end

return Prompts
