--!strict
-- CareerService/Prompts (server, runtime only): ProximityPrompts for careerPath's interacts (Config/World
-- interactIds career_services and boss_review). Same pattern as WardrobeService/Prompts:
--   * every CollectionService "Interact"-tagged part (or model) under Workspace with the InteractId gets one prompt,
--     including parts added later (office floors are cloned at runtime) and parts that only move into Workspace
--     after they were tagged; templates in ServerStorage never get one
--   * inside an office instance (an ancestor carries attribute CompanyId) the prompt gets CompanyId = <id> and
--     EmployeesOnly = true so the client hides it for visitors; the handler re-checks on the server
--
--   Prompts.start(spec) -> ()   spec = { interactId, promptName, actionText, objectText?, holdDuration?,
--                                        objectTextFor? = (inst, companyId?) -> string?,
--                                        onTriggered = (player, prompt, companyId?, inst) -> () }
--   Prompts.companyOf(inst) -> companyId?      Prompts.departmentOf(inst) -> trackId?
--   Prompts.find(interactId, companyId?, department?) -> { BasePart }   live interact parts (waypoints)
--   Prompts.wireInstance(inst, spec)            wires one instance directly (no tag needed), e.g. a boss NPC

local CollectionService = game:GetService("CollectionService")

local Prompts = {}

Prompts.TAG = "Interact"

export type Spec = {
	interactId: string,
	promptName: string,
	actionText: string,
	objectText: string?,
	holdDuration: number?,
	objectTextFor: ((inst: Instance, companyId: string?) -> string?)?,
	onTriggered: (player: Player, prompt: ProximityPrompt, companyId: string?, inst: Instance) -> (),
}

local wired: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local waiting: { [Instance]: RBXScriptConnection } = setmetatable({}, { __mode = "k" }) :: any

local function attrUp(inst: Instance, attr: string): string?
	local node: Instance? = inst
	while node and node ~= workspace and node ~= game do
		local v = node:GetAttribute(attr)
		if type(v) == "string" and v ~= "" then
			return v
		end
		node = node.Parent
	end
	return nil
end

function Prompts.companyOf(inst: Instance): string?
	return attrUp(inst, "CompanyId")
end

function Prompts.departmentOf(inst: Instance): string?
	return attrUp(inst, "Department")
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

local function markCompany(prompt: ProximityPrompt, companyId: string?)
	if companyId then
		prompt:SetAttribute("CompanyId", companyId)
		prompt:SetAttribute("EmployeesOnly", true)
	end
end

local function wire(inst: Instance, spec: Spec)
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
		prompt.ObjectText = spec.objectText or ""
		prompt.HoldDuration = spec.holdDuration or 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	end
	prompt:SetAttribute("InteractId", spec.interactId)
	local companyId = Prompts.companyOf(inst)
	markCompany(prompt, companyId)
	local objectTextFor = spec.objectTextFor
	if objectTextFor then
		local ok, text = pcall(objectTextFor, inst, companyId)
		if ok and type(text) == "string" then
			prompt.ObjectText = text
		end
	end
	wired[prompt] = true
	prompt.Triggered:Connect(function(player: Player)
		local company = Prompts.companyOf(inst) or Prompts.companyOf(prompt)
		if company and prompt:GetAttribute("EmployeesOnly") ~= true then
			markCompany(prompt, company)
		end
		local ok, err = pcall(function()
			spec.onTriggered(player, prompt, company, inst)
		end)
		if not ok then
			warn(("[CareerService] %s prompt failed: %s"):format(spec.interactId, tostring(err)))
		end
	end)
	if prompt.Parent ~= parent then
		prompt.Parent = parent
	end
	-- OfficeService stamps CompanyId right after parenting a cloned floor: look again once that settles
	task.defer(function()
		if not prompt.Parent then
			return
		end
		local late = Prompts.companyOf(inst)
		if late and prompt:GetAttribute("EmployeesOnly") ~= true then
			markCompany(prompt, late)
		end
		if late and objectTextFor then
			local ok, text = pcall(objectTextFor, inst, late)
			if ok and type(text) == "string" then
				prompt.ObjectText = text
			end
		end
	end)
end

local function watch(inst: Instance, spec: Spec)
	if inst:GetAttribute("InteractId") ~= spec.interactId then
		return
	end
	if inst:IsDescendantOf(workspace) then
		wire(inst, spec)
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
			wire(inst, spec)
		end
	end)
end

function Prompts.wireInstance(inst: Instance, spec: Spec)
	if inst:IsDescendantOf(workspace) then
		wire(inst, spec)
	end
end

function Prompts.start(spec: Spec)
	CollectionService:GetInstanceAddedSignal(Prompts.TAG):Connect(function(inst: Instance)
		watch(inst, spec)
	end)
	for _, inst in CollectionService:GetTagged(Prompts.TAG) do
		watch(inst, spec)
	end
end

-- Live interact parts with this id (optionally inside one company's office and department floor).
function Prompts.find(interactId: string, companyId: string?, department: string?): { BasePart }
	local out: { BasePart } = {}
	for _, inst in CollectionService:GetTagged(Prompts.TAG) do
		if inst:GetAttribute("InteractId") == interactId and inst:IsDescendantOf(workspace) then
			local okCompany = companyId == nil or Prompts.companyOf(inst) == companyId
			local okDept = department == nil
				or Prompts.departmentOf(inst) == nil
				or Prompts.departmentOf(inst) == department
			local part = promptParent(inst)
			if okCompany and okDept and part then
				table.insert(out, part)
			end
		end
	end
	return out
end

return Prompts
