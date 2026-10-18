--!strict
-- ProjectController (client, owned by `projects`; contracts §9): opens the Project screen ("Deals" menu tab) and
-- wraps the Project.* remotes for it.
--
-- Interact wiring (WardrobeController's pattern):
--   1. ProjectService/Prompts creates a ProximityPrompt (InteractId = "project_desk") on every tagged deal desk.
--      Inside an office instance it also sets CompanyId and EmployeesOnly = true; elsewhere EmployedOnly = true.
--   2. When it fires, the SERVER decides: employees get "Project.Open" (opens the screen here, filtered to their
--      track); visitors get a polite "Employees only" toast.
--   3. This controller hides EmployeesOnly prompts locally for visitors (Store `career.companyId`, plus a Merger
--      Mania pairing in the global `events`) and EmployedOnly prompts for students and players between jobs,
--      re-checked whenever career or events change. Streaming-safe: prompts are found through the replicated
--      "Interact" tag as parts stream in and dropped when they stream out.
--
-- API (used by UI/Screens/Project):
--   ProjectController:Open(args?)                    UIController:Open("Project", args)
--   ProjectController:List() -> (ok, list | errKey, vars?)
--   ProjectController:StartDeal(id) -> (ok, view | errKey, vars?)
--   ProjectController:View(id) -> (ok, view | errKey, vars?)
--   ProjectController:Act(id, answers, stageIndex) -> (ok, { result, view, rewards?, completed } | errKey, vars?)
--   ProjectController:Abandon(id) -> (ok, errKey?)
--   ProjectController:GetDraft(id, stageIndex) -> answers?   :SaveDraft(id, stageIndex, answers)   :ClearDraft(id)
--   ProjectController:NoteActive(n)                   the screen reports how many deals are in progress (menu badge)
--   ProjectController.Changed : Signal(info)          the server changed a run (fired, moved, reset, completed)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Registry = require(script.Parent.Parent.Registry)
local ProjectsRegistry = require(Shared:WaitForChild("Logic"):WaitForChild("Projects"):WaitForChild("_registry"))
local View = require(
	script.Parent.Parent:WaitForChild("UI"):WaitForChild("Screens"):WaitForChild("ProjectParts"):WaitForChild("View")
)

local ProjectController = { Name = "ProjectController" }

ProjectController.Changed = Signal.new()

local SCREEN_ID = "Project"
local TAB_ID = "deals"
local INTERACT_ID = "project_desk"
local PROMPT_NAME = "ProjectPrompt"
local MAX_DRAFTS = 8

---------------------------------------------------------------------------------------------------
-- Store access (optional: everything works without it)
---------------------------------------------------------------------------------------------------
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
-- RemoteFunction results arrive as (true, value) / (false, errKey, vars) or Net's (nil, "timeout"/"error"/...).
local function call(name: string, ...: any): (boolean, any, any)
	local ok, a, b, c = pcall(Net.invoke, name, ...)
	if not ok then
		return false, "generic", nil
	end
	if a == true then
		return true, b, nil
	end
	if a == nil and type(b) == "string" then
		if b == "timeout" or b == "rate_limited" then
			return false, b, nil
		end
		if b == "missing" then
			return false, "unavailable", nil
		end
		return false, "generic", nil
	end
	return false, if type(b) == "string" then b else "generic", c
end

function ProjectController:List(): (boolean, any, any)
	return call("Project.List")
end

function ProjectController:StartDeal(id: string): (boolean, any, any)
	return call("Project.Start", id)
end

function ProjectController:View(id: string): (boolean, any, any)
	return call("Project.View", id)
end

function ProjectController:Act(id: string, answers: any, stageIndex: number): (boolean, any, any)
	local ok, a, b = call("Project.Act", id, View.wire(answers or {}), stageIndex)
	if ok then
		ProjectController:ClearDraft(id)
	end
	return ok, a, b
end

function ProjectController:Abandon(id: string): (boolean, any)
	local ok, err = call("Project.Abandon", id)
	ProjectController:ClearDraft(id)
	return ok, if ok then nil else err
end

---------------------------------------------------------------------------------------------------
-- Drafts: answers typed into a stage survive closing and reopening the screen (this session only)
---------------------------------------------------------------------------------------------------
type Draft = { stage: number, answers: any, at: number }
local drafts: { [string]: Draft } = {}

function ProjectController:GetDraft(id: string, stageIndex: number): any
	local d = drafts[id]
	if d and d.stage == stageIndex then
		return d.answers
	end
	return nil
end

function ProjectController:SaveDraft(id: string, stageIndex: number, answers: any)
	if type(id) ~= "string" then
		return
	end
	drafts[id] = { stage = stageIndex, answers = answers, at = os.clock() }
	-- keep the table small: drop the oldest drafts
	local n = 0
	local oldestId, oldestAt = nil, math.huge
	for key, d in drafts do
		n += 1
		if d.at < oldestAt then
			oldestId, oldestAt = key, d.at
		end
	end
	if n > MAX_DRAFTS and oldestId then
		drafts[oldestId] = nil
	end
end

function ProjectController:ClearDraft(id: string)
	drafts[id] = nil
end

function ProjectController:Open(args: any?)
	local ui = Registry.get("UIController")
	if ui and type(ui.Open) == "function" then
		pcall(function()
			ui:Open(SCREEN_ID, args)
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- Prompt visibility (the server refuses visitors either way)
---------------------------------------------------------------------------------------------------
local function employed(career: any): boolean
	if type(career) ~= "table" then
		return false
	end
	local status = career.status
	if status == "student" or status == "fired" or career.roleId == "unemployed" then
		return false
	end
	return type(career.companyId) == "string" and career.companyId ~= ""
end

-- Merger Mania (contracts §11): two firms share offices while the corporate event pairs them.
local function paired(events: any, mine: string, companyId: string): boolean
	local corporate = if type(events) == "table" then events.corporate else nil
	if type(corporate) ~= "table" or corporate.id ~= "merger_mania" or type(corporate.data) ~= "table" then
		return false
	end
	local seen: { [string]: boolean } = {}
	local function scan(v: any, depth: number)
		if type(v) == "string" then
			seen[v] = true
		elseif type(v) == "table" and depth < 3 then
			for _, x in v do
				scan(x, depth + 1)
			end
		end
	end
	scan(corporate.data, 0)
	return seen[mine] == true and seen[companyId] == true
end

local function allowed(prompt: ProximityPrompt): boolean
	local career = storeGet("career")
	if prompt:GetAttribute("EmployeesOnly") == true then
		local companyId = prompt:GetAttribute("CompanyId")
		if type(companyId) ~= "string" or companyId == "" then
			return employed(career)
		end
		if not employed(career) then
			return false
		end
		local mine = career.companyId
		return mine == companyId or paired(storeGlobal("events"), mine, companyId)
	end
	if prompt:GetAttribute("EmployedOnly") == true then
		return employed(career)
	end
	return true
end

local prompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Instance]: { RBXScriptConnection } } = {}

local function evaluate(prompt: ProximityPrompt)
	local ok, yes = pcall(allowed, prompt)
	local visible = ok and yes
	if prompt.Enabled ~= visible then
		prompt.Enabled = visible
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
	prompts[inst] = true
	for _, attr in { "EmployeesOnly", "EmployedOnly", "CompanyId" } do
		inst:GetAttributeChangedSignal(attr):Connect(function()
			evaluate(inst)
		end)
	end
	evaluate(inst)
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
	local s = store()
	if s then
		pcall(function()
			s:Changed("career"):Connect(evaluateAll)
			s:GlobalChanged("events"):Connect(evaluateAll)
			s.Loaded:Connect(evaluateAll)
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- Menu badge: deals in progress
---------------------------------------------------------------------------------------------------
local function setBadge(n: number)
	local ui = Registry.get("UIController")
	if ui and type(ui.SetMenuBadge) == "function" then
		pcall(function()
			ui:SetMenuBadge(TAB_ID, if n > 0 then tostring(n) else nil)
		end)
	end
end

function ProjectController:NoteActive(n: number)
	setBadge(math.max(0, math.floor(tonumber(n) or 0)))
end

local refreshing = false
local function refreshBadge()
	if refreshing then
		return
	end
	refreshing = true
	task.spawn(function()
		local career = storeGet("career")
		if employed(career) then
			local ok, list = ProjectController:List()
			if ok and type(list) == "table" and type(list.activeCount) == "number" then
				setBadge(list.activeCount)
			end
		else
			setBadge(0)
		end
		refreshing = false
	end)
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function ProjectController:Init() end

function ProjectController:Start()
	local ui = Registry.get("UIController")
	if ui and type(ui.RegisterMenuTab) == "function" then
		pcall(function()
			ui:RegisterMenuTab({
				id = TAB_ID,
				title = ProjectsRegistry.text("menu"),
				glyph = "🤝",
				order = 25,
				screen = SCREEN_ID,
			})
		end)
	end
	-- the server accepted a deal desk prompt (or another feature asked ProjectService:OpenFor)
	Net.listen("Project.Open", function(args: any)
		local open: { [string]: any } = {}
		if type(args) == "table" then
			if type(args.filter) == "string" then
				open.filter = args.filter
			end
			if type(args.id) == "string" then
				open.id = args.id
			end
			if type(args.source) == "string" then
				open.source = args.source
			end
		end
		ProjectController:Open(open)
	end)
	Net.listen("Project.Changed", function(info: any)
		local i = if type(info) == "table" then info else {}
		if type(i.id) == "string" and (i.reason == "reset" or i.reason == "completed") then
			ProjectController:ClearDraft(i.id)
		elseif i.reason == "fired" or i.reason == "role" or i.reason == "rebirth" then
			table.clear(drafts)
		end
		ProjectController.Changed:Fire(i)
		refreshBadge()
	end)
	startPromptWatch()
	local s = store()
	if s then
		pcall(function()
			if s:IsLoaded() then
				refreshBadge()
			end
			s.Loaded:Connect(refreshBadge)
			-- leaving the Street (fired, rebirth) empties the pipeline; the server's Project.Changed refreshes the rest
			s:Changed("career"):Connect(function(career: any)
				if not employed(career) then
					setBadge(0)
				end
			end)
		end)
	end
end

return ProjectController
