--!strict
-- TutorialService/Interacts (server, runtime only): the "Interact"-tag wiring shared by the tutorial's interacts
-- (`bulletin` here, `npc` in NpcService). Follows the WardrobeService pattern: every CollectionService "Interact"
-- instance with the InteractId under Workspace is handed to `onFound` once, including instances added later (office
-- floors are cloned at runtime) and instances that move into Workspace after being tagged (a staged template).
-- Instances sitting in ServerStorage templates are never wired.
--
--   Interacts.watch(interactId, onFound)        onFound(inst) runs once per instance (pcall'd)
--   Interacts.companyOf(inst) -> companyId?      the CompanyId of an office instance the part sits in
--   Interacts.prompt(parent, opts) -> ProximityPrompt
--       opts = { name, action, object?, interactId, distance?, hold?, companyId?, employeesOnly? }
--   Interacts.promptParent(inst) -> Instance?    the part (or a Model's PrimaryPart) a prompt can live on

local CollectionService = game:GetService("CollectionService")

local Interacts = {}

Interacts.TAG = "Interact"

local seen: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local waiting: { [Instance]: RBXScriptConnection } = setmetatable({}, { __mode = "k" }) :: any

function Interacts.companyOf(inst: Instance): string?
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

function Interacts.promptParent(inst: Instance): Instance?
	if inst:IsA("BasePart") or inst:IsA("Attachment") then
		return inst
	end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

export type PromptOpts = {
	name: string,
	action: string,
	object: string?,
	interactId: string,
	distance: number?,
	hold: number?,
	companyId: string?,
	employeesOnly: boolean?,
}

function Interacts.prompt(parent: Instance, opts: PromptOpts): ProximityPrompt
	local existing = parent:FindFirstChild(opts.name)
	local prompt: ProximityPrompt
	if existing and existing:IsA("ProximityPrompt") then
		prompt = existing
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = opts.name
	end
	prompt.ActionText = opts.action
	prompt.ObjectText = opts.object or ""
	prompt.HoldDuration = opts.hold or 0
	prompt.MaxActivationDistance = opts.distance or 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt:SetAttribute("InteractId", opts.interactId)
	if opts.companyId then
		prompt:SetAttribute("CompanyId", opts.companyId)
		if opts.employeesOnly then
			prompt:SetAttribute("EmployeesOnly", true)
		end
	end
	if prompt.Parent ~= parent then
		prompt.Parent = parent
	end
	return prompt
end

local function found(inst: Instance, interactId: string, onFound: (Instance) -> ())
	if seen[inst] then
		return
	end
	seen[inst] = true
	local ok, err = pcall(function()
		onFound(inst)
	end)
	if not ok then
		warn(("[Tutorial] %s interact failed: %s"):format(interactId, tostring(err)))
	end
end

local function consider(inst: Instance, interactId: string, onFound: (Instance) -> ())
	if inst:GetAttribute("InteractId") ~= interactId or seen[inst] then
		return
	end
	if inst:IsDescendantOf(workspace) then
		found(inst, interactId, onFound)
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
			found(inst, interactId, onFound)
		end
	end)
end

function Interacts.watch(interactId: string, onFound: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(Interacts.TAG):Connect(function(inst: Instance)
		consider(inst, interactId, onFound)
	end)
	for _, inst in CollectionService:GetTagged(Interacts.TAG) do
		consider(inst, interactId, onFound)
	end
end

return Interacts
