--!strict
-- TerminalController: EmployeesOnly market prompts (RUNTIME ONLY, client; the WardrobeController pattern).
-- MarketService creates the `terminal` ("TerminalPrompt") and `news_stand` ("NewsStandPrompt") ProximityPrompts on the
-- server; inside an office instance it marks them CompanyId = <id>, EmployeesOnly = true. This module disables those
-- prompts locally for visitors so they never see an interaction they can't use (the server refuses them anyway).
-- Streaming-safe: prompts are found through the replicated "Interact" tag as parts stream in (the prompt itself may
-- replicate a moment after its part) and forgotten when they stream out.
--
--   Prompts.start(canUse) -> evaluateAll      canUse(companyId) -> boolean; call evaluateAll when career/events change

local CollectionService = game:GetService("CollectionService")

local Prompts = {}

Prompts.TAG = "Interact"
Prompts.IDS = { terminal = "TerminalPrompt", news_stand = "NewsStandPrompt" } :: { [string]: string }

local function isOurs(prompt: Instance): boolean
	if not prompt:IsA("ProximityPrompt") then
		return false
	end
	local id = prompt:GetAttribute("InteractId")
	if type(id) == "string" and Prompts.IDS[id] ~= nil then
		return true
	end
	for _, name in Prompts.IDS do
		if prompt.Name == name then
			return true
		end
	end
	return false
end

function Prompts.start(canUse: (companyId: any) -> boolean): () -> ()
	local prompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local watched: { [Instance]: RBXScriptConnection } = {}

	local function evaluate(prompt: ProximityPrompt)
		if prompt:GetAttribute("EmployeesOnly") ~= true then
			if prompt.Enabled == false and prompt:GetAttribute("MarketHidden") == true then
				prompt.Enabled = true
				prompt:SetAttribute("MarketHidden", nil)
			end
			return
		end
		local ok, allowed = pcall(canUse, prompt:GetAttribute("CompanyId"))
		local show = ok and allowed == true
		if prompt.Enabled ~= show then
			prompt.Enabled = show
		end
		prompt:SetAttribute("MarketHidden", if show then nil else true)
	end

	local function track(inst: Instance)
		if prompts[inst :: any] or not isOurs(inst) then
			return
		end
		local prompt = inst :: ProximityPrompt
		prompts[prompt] = true
		prompt:GetAttributeChangedSignal("EmployeesOnly"):Connect(function()
			evaluate(prompt)
		end)
		prompt:GetAttributeChangedSignal("CompanyId"):Connect(function()
			evaluate(prompt)
		end)
		evaluate(prompt)
	end

	local function watch(inst: Instance)
		local id = inst:GetAttribute("InteractId")
		if type(id) ~= "string" or Prompts.IDS[id] == nil or watched[inst] then
			return
		end
		watched[inst] = inst.DescendantAdded:Connect(track)
		for _, d in inst:GetDescendants() do
			track(d)
		end
	end

	local function unwatch(inst: Instance)
		local conn = watched[inst]
		if conn then
			watched[inst] = nil
			conn:Disconnect()
		end
	end

	CollectionService:GetInstanceAddedSignal(Prompts.TAG):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(Prompts.TAG):Connect(unwatch)
	for _, inst in CollectionService:GetTagged(Prompts.TAG) do
		watch(inst)
	end

	return function()
		for prompt in prompts do
			if prompt.Parent then
				evaluate(prompt)
			end
		end
	end
end

return Prompts
