--!strict
-- WardrobeService: the "wardrobe" interact (RUNTIME ONLY, server; Config/World.interactIds.wardrobe).
--
-- Every CollectionService "Interact"-tagged instance with InteractId = "wardrobe" that lives under Workspace gets one
-- ProximityPrompt (named "WardrobePrompt", attribute InteractId = "wardrobe"), including instances added later (office
-- floors are cloned at runtime) and instances that only move into Workspace after they were tagged (a template staged
-- elsewhere first). Templates sitting in ServerStorage never get a prompt, so clones never inherit a stale one.
--
-- Inside an office instance (the instance or an ancestor carries attribute CompanyId) the prompt also gets
-- CompanyId = <id> and EmployeesOnly = true, so the client can hide it for visitors. The server re-checks the
-- company when the prompt fires; the service refuses visitors with a polite toast.
--
--   Prompts.start(onTriggered)   onTriggered(player, prompt, companyId?) runs for every trigger (pcall'd)
--   Prompts.companyOf(inst) -> companyId?
--   Prompts.PROMPT_NAME, Prompts.INTERACT_ID

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)

local Prompts = {}

Prompts.INTERACT_ID = "wardrobe"
Prompts.PROMPT_NAME = "WardrobePrompt"
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

local function markCompany(prompt: ProximityPrompt, companyId: string?)
	if companyId then
		prompt:SetAttribute("CompanyId", companyId)
		prompt:SetAttribute("EmployeesOnly", true)
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
		prompt.ActionText = Catalog.text("prompt")
		prompt.ObjectText = Catalog.text("title")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	end
	prompt:SetAttribute("InteractId", Prompts.INTERACT_ID)
	markCompany(prompt, Prompts.companyOf(inst))
	wired[prompt] = true
	prompt.Triggered:Connect(function(player: Player)
		-- the company is re-read at trigger time: attributes stamped after the clone was parented still count
		local companyId = Prompts.companyOf(inst) or Prompts.companyOf(prompt)
		if companyId and prompt:GetAttribute("EmployeesOnly") ~= true then
			markCompany(prompt, companyId)
		end
		local ok, err = pcall(function()
			onTriggered(player, prompt, companyId)
		end)
		if not ok then
			warn("[WardrobeService] wardrobe prompt failed: " .. tostring(err))
		end
	end)
	if prompt.Parent ~= parent then
		prompt.Parent = parent
	end
	-- OfficeService may stamp CompanyId right after parenting the clone: check again once that settles
	task.defer(function()
		if prompt.Parent and prompt:GetAttribute("EmployeesOnly") ~= true then
			markCompany(prompt, Prompts.companyOf(inst))
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

return Prompts
