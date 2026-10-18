--!strict
-- WorkController (client, owned by `work`; contracts §8): the client side of WorkService.
--
-- Interact wiring (the WardrobeService / WardrobeController pattern):
--   1. WorkService/Prompts creates a "WorkPrompt" ProximityPrompt (InteractId = "work_desk") on every desk. Office
--      desks carry CompanyId + EmployeesOnly; campus desks carry StudentsOnly.
--   2. The SERVER decides when a prompt fires: allowed players get "Work.Open", which opens the Work screen here;
--      everyone else gets a polite toast ("Employees only", "Campus desks are for students").
--   3. This controller hides those prompts locally for players who can't use them (Store `career`, and Merger
--      Mania partners from the global `events` via careerPath's pure CareerState.mergerPartners), re-checked when
--      career or events change. Streaming-safe: prompts are found through the replicated "Interact" tag as parts
--      stream in and dropped when they stream out.
-- It also registers the "Work" menu tab (a HUD quick button) with a badge counting today's unfinished tasks.
--
-- API (used by UI/Screens/Work):
--   WorkController:GetBoard() -> (ok, boardView | errKey)        Work.Board
--   WorkController:StartTask(taskId) -> (ok, activeView | errKey) Work.Start
--   WorkController:Submit(instanceId, answers) -> (ok, result | errKey)   Work.Submit (clears the draft on success)
--   WorkController:Abandon(instanceId) -> (ok, errKey?)            Work.Abandon
--   WorkController:SaveDraft(instanceId, answers) / :GetDraft(instanceId) -> answers?
--   WorkController:Open(args?)                                     UIController:Open("Work", args)
--   WorkController.BoardChanged : Signal()                         the board replicated or the server pinged

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Time = require(Shared.Util.Time)
local Config = require(Shared.Config.Tasks)
local Registry = require(script.Parent.Parent.Registry)
local View = require(
	script.Parent.Parent:WaitForChild("UI"):WaitForChild("Screens"):WaitForChild("WorkParts"):WaitForChild("View")
)

local WorkController = { Name = "WorkController", BoardChanged = Signal.new() }

local INTERACT_ID = "work_desk"
local PROMPT_NAME = "WorkPrompt"
local SCREEN_ID = "Work"
local TAB_ID = "work"
local REMOTE_WAIT = 8

-- careerPath's pure merger-partner rule, when it's there (guarded: the work feature runs without it)
local mergerPartners: any = nil
do
	local logic = Shared:FindFirstChild("Logic")
	local module = if logic then logic:FindFirstChild("CareerState") else nil
	if module and module:IsA("ModuleScript") then
		local ok, mod = pcall(require, module)
		if ok and type(mod) == "table" and type(mod.mergerPartners) == "function" then
			mergerPartners = mod.mergerPartners
		end
	end
end

local drafts: { [string]: any } = {}

local function store(): any
	return Registry.get("Store")
end

local function storeGet(key: string): any
	local s = store()
	if not s then
		return nil
	end
	local ok, v = pcall(function()
		return s:Get(key)
	end)
	return if ok then v else nil
end

local function storeGlobal(key: string): any
	local s = store()
	if not s then
		return nil
	end
	local ok, v = pcall(function()
		return s:GetGlobal(key)
	end)
	return if ok then v else nil
end

---------------------------------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------------------------------
-- A missing WorkService means its remotes never appear: answer "unavailable" quickly instead of waiting 30 s.
local function remoteReady(name: string): boolean
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		or ReplicatedStorage:WaitForChild("Remotes", REMOTE_WAIT)
	local folder = if remotes then (remotes:FindFirstChild("F") or remotes:WaitForChild("F", REMOTE_WAIT)) else nil
	if not folder then
		return false
	end
	return (folder:FindFirstChild(name) or folder:WaitForChild(name, REMOTE_WAIT)) ~= nil
end

-- RemoteFunction results arrive as (true, value) / (false, errKey), or (nil, "timeout"/"error"/"rate_limited").
local function call(name: string, ...: any): (boolean, any)
	if not remoteReady(name) then
		return false, "unavailable"
	end
	local ok, a, b = pcall(Net.invoke, name, ...)
	if not ok then
		return false, "generic"
	end
	if a == true then
		return true, b
	end
	if a == nil then
		if b == "timeout" or b == "rate_limited" then
			return false, b
		elseif b == "missing" then
			return false, "unavailable"
		end
		return false, "generic"
	end
	return false, if type(b) == "string" then b else "generic"
end

function WorkController:GetBoard(): (boolean, any)
	return call("Work.Board")
end

function WorkController:StartTask(taskId: string): (boolean, any)
	return call("Work.Start", taskId)
end

function WorkController:Submit(instanceId: string, answers: any): (boolean, any)
	local ok, res = call("Work.Submit", instanceId, answers)
	if ok or res == "expired" or res == "void" or res == "no_active" or res == "wrong_task" then
		drafts[instanceId] = nil
	end
	return ok, res
end

function WorkController:Abandon(instanceId: string): (boolean, any)
	drafts[instanceId] = nil
	return call("Work.Abandon", instanceId)
end

function WorkController:SaveDraft(instanceId: string, answers: any)
	if type(instanceId) == "string" then
		drafts[instanceId] = answers
	end
end

function WorkController:GetDraft(instanceId: string): any
	return if type(instanceId) == "string" then drafts[instanceId] else nil
end

function WorkController:Open(args: any?)
	local ui = Registry.get("UIController")
	if ui and type(ui.Open) == "function" then
		ui:Open(SCREEN_ID, args)
	end
end

---------------------------------------------------------------------------------------------------
-- Menu badge: unfinished tasks on today's board (from the replicated `work` key)
---------------------------------------------------------------------------------------------------
local function updateBadge()
	local ui = Registry.get("UIController")
	if not ui or type(ui.SetMenuBadge) ~= "function" then
		return
	end
	local work = storeGet("work")
	local n = 0
	local board = if type(work) == "table" then work.board else nil
	if type(board) == "table" and type(board.tasks) == "table" then
		for _, e in board.tasks do
			if type(e) == "table" and e.done ~= true then
				n += 1
			end
		end
	end
	pcall(function()
		ui:SetMenuBadge(TAB_ID, if n > 0 then tostring(n) else nil)
	end)
end

---------------------------------------------------------------------------------------------------
-- Desk prompts: hidden locally for players who can't use them (the server refuses them either way)
---------------------------------------------------------------------------------------------------
local prompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Instance]: { RBXScriptConnection } } = {}

local function evaluate(prompt: ProximityPrompt)
	local attrs = {
		employeesOnly = prompt:GetAttribute("EmployeesOnly") == true,
		companyId = prompt:GetAttribute("CompanyId"),
		studentsOnly = prompt:GetAttribute("StudentsOnly") == true,
	}
	if not attrs.employeesOnly and not attrs.studentsOnly then
		return
	end
	local allowed = View.canUsePrompt(storeGet("career"), storeGlobal("events"), attrs, Time.now(), mergerPartners)
	if prompt.Enabled ~= allowed then
		prompt.Enabled = allowed
	end
end

local function evaluateAll()
	for prompt in prompts do
		if prompt.Parent then
			evaluate(prompt)
		end
	end
end

local function track(inst: Instance)
	if not inst:IsA("ProximityPrompt") or prompts[inst] then
		return
	end
	if inst.Name ~= PROMPT_NAME and inst:GetAttribute("InteractId") ~= INTERACT_ID then
		return
	end
	local prompt = inst :: ProximityPrompt
	prompts[prompt] = true
	for _, attr in { "EmployeesOnly", "CompanyId", "StudentsOnly" } do
		prompt:GetAttributeChangedSignal(attr):Connect(function()
			evaluate(prompt)
		end)
	end
	evaluate(prompt)
end

local function unwatch(inst: Instance)
	local conns = watched[inst]
	if conns then
		watched[inst] = nil
		for _, c in conns do
			c:Disconnect()
		end
	end
end

local function watch(inst: Instance)
	if inst:GetAttribute("InteractId") ~= INTERACT_ID or watched[inst] then
		return
	end
	local conns: { RBXScriptConnection } = {}
	watched[inst] = conns
	-- the server parents the prompt under the part (or a Model's PrimaryPart); it may replicate a moment later
	table.insert(conns, inst.DescendantAdded:Connect(track))
	for _, d in inst:GetDescendants() do
		track(d)
	end
end

local function startPromptWatch()
	CollectionService:GetInstanceAddedSignal("Interact"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("Interact"):Connect(unwatch)
	for _, inst in CollectionService:GetTagged("Interact") do
		watch(inst)
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function WorkController:Init() end

function WorkController:Start()
	local ui = Registry.get("UIController")
	if ui and type(ui.RegisterMenuTab) == "function" then
		ui:RegisterMenuTab({
			id = TAB_ID,
			title = Config.text("menu"),
			glyph = "💼",
			order = 15,
			screen = SCREEN_ID,
			quick = true,
		})
	end
	-- a desk prompt the server accepted, or WorkService:StartTask / :OpenFor
	Net.listen("Work.Open", function(args: any)
		local open: { [string]: any } = {}
		if type(args) == "table" then
			if type(args.instanceId) == "string" then
				open.instanceId = args.instanceId
			end
			if type(args.taskId) == "string" then
				open.taskId = args.taskId
			end
			if type(args.source) == "string" then
				open.source = args.source
			end
		end
		WorkController:Open(open)
	end)
	Net.listen("Work.Changed", function()
		WorkController.BoardChanged:Fire()
	end)
	local s = store()
	if s then
		pcall(function()
			s:Changed("work"):Connect(function()
				updateBadge()
				WorkController.BoardChanged:Fire()
			end)
			s:Changed("career"):Connect(function()
				evaluateAll()
				WorkController.BoardChanged:Fire()
			end)
			s:GlobalChanged("events"):Connect(evaluateAll)
			s.Loaded:Connect(function()
				evaluateAll()
				updateBadge()
			end)
		end)
	end
	updateBadge()
	startPromptWatch()
end

return WorkController
