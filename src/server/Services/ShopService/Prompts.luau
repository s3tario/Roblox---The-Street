--!strict
-- Shop feature: ProximityPrompts for the interacts it owns (RUNTIME ONLY, server; Config/World.interactIds): `shop`
-- (attribute Shop = a Config/Shop id) and `housing_panel` (attribute Context = dorm | apartment | desk | office).
--
-- Every CollectionService "Interact"-tagged instance with a matching InteractId that lives under Workspace gets one
-- ProximityPrompt (attribute InteractId), including instances added later (office floors are cloned at runtime) and
-- instances that only move into Workspace after they were tagged. Templates in ServerStorage never get a prompt, so
-- clones never inherit a stale one. Inside an office instance (an ancestor carries attribute CompanyId) the prompt
-- gets CompanyId = <id> and EmployeesOnly = true, so clients hide it for visitors; the owning service re-checks
-- CareerService:IsEmployeeOf when it fires.
--
--   Prompts.watch(spec) -> ()
--     spec = { interactId, promptName, actionText, objectText: (inst) -> string?, maxDistance?, holdDuration?,
--              onTriggered = (player, inst, prompt, companyId?) -> () }
--   Prompts.companyOf(inst) -> companyId?

local CollectionService = game:GetService("CollectionService")

local Prompts = {}

Prompts.TAG = "Interact"

export type Spec = {
	interactId: string,
	promptName: string,
	actionText: string,
	objectText: ((inst: Instance) -> string?)?,
	maxDistance: number?,
	holdDuration: number?,
	onTriggered: (player: Player, inst: Instance, prompt: ProximityPrompt, companyId: string?) -> (),
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

function Prompts.watch(spec: Spec)
	-- prompts already wired (weak: a destroyed floor takes its prompts and their connections with it)
	local wired: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	-- tagged instances outside Workspace waiting to move in
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
			prompt.HoldDuration = spec.holdDuration or 0
			prompt.MaxActivationDistance = spec.maxDistance or 10
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		end
		local objectText = spec.objectText
		if objectText then
			local ok, text = pcall(objectText, inst)
			if ok and type(text) == "string" then
				prompt.ObjectText = text
			end
		end
		prompt:SetAttribute("InteractId", spec.interactId)
		markCompany(prompt, Prompts.companyOf(inst))
		wired[prompt] = true
		prompt.Triggered:Connect(function(player: Player)
			-- the company is re-read at trigger time: attributes stamped after the clone was parented still count
			local companyId = Prompts.companyOf(inst) or Prompts.companyOf(prompt)
			if companyId and prompt:GetAttribute("EmployeesOnly") ~= true then
				markCompany(prompt, companyId)
			end
			local ok, err = pcall(function()
				spec.onTriggered(player, inst, prompt, companyId)
			end)
			if not ok then
				warn(("[Shop] %s prompt failed: %s"):format(spec.interactId, tostring(err)))
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
