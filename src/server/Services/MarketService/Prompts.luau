--!strict
-- MarketService: ProximityPrompts for the market's interact ids (RUNTIME ONLY, server; Config/World.interactIds
-- `terminal` and `news_stand`, owner "market").
--
-- Every CollectionService "Interact"-tagged instance with a matching InteractId that lives under Workspace gets one
-- prompt (named after the id), including instances added later (office floors are cloned at runtime) and instances
-- that move into Workspace after they were tagged. Templates in ServerStorage never get one, so clones never carry a
-- stale prompt. Inside an office instance (an ancestor Model carries attribute CompanyId) the prompt is marked
-- CompanyId = <id>, EmployeesOnly = true so the client can hide it for visitors; the service re-checks on trigger.
--
--   Prompts.start({ interactId, promptName, actionText, objectText, onTriggered, holdDuration? })
--       onTriggered(player, prompt, companyId?) runs for every trigger (pcall'd)
--   Prompts.companyOf(inst) -> companyId?

local CollectionService = game:GetService("CollectionService")

local Prompts = {}

Prompts.TAG = "Interact"

export type Spec = {
	interactId: string,
	promptName: string,
	actionText: string,
	objectText: string,
	holdDuration: number?,
	onTriggered: (player: Player, prompt: ProximityPrompt, companyId: string?) -> (),
}

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

function Prompts.start(spec: Spec)
	-- prompts already wired (weak keys: a destroyed floor takes its prompts and connections with it)
	local wired: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local waiting: { [Instance]: RBXScriptConnection } = setmetatable({}, { __mode = "k" }) :: any

	local function wire(inst: Instance)
		local parent = promptParent(inst)
		if not parent then
			return
		end
		local existing = parent:FindFirstChild(spec.promptName)
		local prompt: ProximityPrompt
		if existing and existing:IsA("ProximityPrompt") then
			if wired[existing] then
				return
			end
			prompt = existing
		else
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = spec.promptName
			prompt.ActionText = spec.actionText
			prompt.ObjectText = spec.objectText
			prompt.HoldDuration = spec.holdDuration or 0
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		end
		prompt:SetAttribute("InteractId", spec.interactId)
		markCompany(prompt, Prompts.companyOf(inst))
		wired[prompt] = true
		prompt.Triggered:Connect(function(player: Player)
			-- re-read at trigger time: OfficeService may stamp CompanyId after the clone was parented
			local companyId = Prompts.companyOf(inst) or Prompts.companyOf(prompt)
			if companyId and prompt:GetAttribute("EmployeesOnly") ~= true then
				markCompany(prompt, companyId)
			end
			local ok, err = pcall(function()
				spec.onTriggered(player, prompt, companyId)
			end)
			if not ok then
				warn(("[MarketService] %s prompt failed: %s"):format(spec.interactId, tostring(err)))
			end
		end)
		if prompt.Parent ~= parent then
			prompt.Parent = parent
		end
		task.defer(function()
			if prompt.Parent and prompt:GetAttribute("EmployeesOnly") ~= true then
				markCompany(prompt, Prompts.companyOf(inst))
			end
		end)
	end

	local function watch(inst: Instance)
		if inst:GetAttribute("InteractId") ~= spec.interactId then
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
			if inst:IsDescendantOf(workspace) then
				local conn = waiting[inst]
				waiting[inst] = nil
				if conn then
					conn:Disconnect()
				end
				wire(inst)
			elseif inst.Parent == nil then
				local conn = waiting[inst]
				waiting[inst] = nil
				if conn then
					conn:Disconnect()
				end
			end
		end)
	end

	CollectionService:GetInstanceAddedSignal(Prompts.TAG):Connect(watch)
	for _, inst in CollectionService:GetTagged(Prompts.TAG) do
		watch(inst)
	end
end

return Prompts
