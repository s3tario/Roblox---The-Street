--!strict
-- ProjectService (server, owned by `projects`; docs/contracts.md §9, design v3 §13, spec §7): big deals. Multi-stage
-- projects (the IB sell-side and the IB signature IPO in M1; every later track's deal plugs in the same way) that
-- close with a deal plaque. Server-authoritative: stages are generated here, the answer key never leaves the
-- server, and every reward is computed here.
--
-- Modules: every ModuleScript in Shared/Logic/Projects whose name doesn't start with "_" and that another service
-- doesn't run (Registry.EXTERNAL: careerPath's `reentry`), passing Registry.check. A broken module is skipped with a
-- warning; the rest keep working. The rules (availability, status, run lifecycle, rewards) live in the pure
-- Logic/Projects/_registry, unit-tested in tests/projects.
--
-- Data: data.projects[projectId] (Config/DataTemplate/Projects; private, never replicated: a run in progress holds
-- its answer key). The client only ever sees Project.List cards and Project.View views.
--
-- Remotes (RemoteFunctions answer (true, value) or (false, errKey, vars?); the client shows
-- Registry.text("err_" .. errKey, vars)):
--   Project.List()                          -> { who, cards = {Card}, activeCount, maxActive, now }
--   Project.Start(projectId)                -> view (a run in progress resumes; view.resumed = true)
--   Project.View(projectId)                 -> view of the run in progress, or of the last finished one
--   Project.Act(projectId, answers, stage?) -> { result, view, rewards?, completed }   stage = the stage index the
--                                              answers were written for (a double submit answers "stale")
--   Project.Abandon(projectId)              -> true
--   Project.Open    (server -> client)      open the Project screen: { source = "desk", filter = trackId }
--   Project.Changed (server -> client)      a run changed outside a remote call (fired, moved, reset): refetch
-- API (contracts §9 + extras):
--   ProjectService.ProjectCompleted : Signal(player, projectId, result)
--       result = { quality, closed, dealName, signature, repeatRun, xp, pay, rep, plaque, outcomeScore }
--   ProjectService.ProjectStarted : Signal(player, projectId)
--   ProjectService.ProjectCancelled : Signal(player, projectId, reason)   "abandoned" | "fired" | "role" | "reset"
--   :CancelActive(player, reason?) -> number   drops every run in progress (CareerService calls it when firing)
--   :GetActive(player) -> { projectId }        :HasClosed(player, projectId) -> boolean
--   :GetModule(projectId) -> module?           :ListModules() -> { {id, title, track, ranks, signature} }
--   :OpenFor(player, args?)                    opens the Project screen on that client
-- Parts: Deps (guarded cross-feature calls), Core (modules, player state, record helpers, signals), Flow (deal
--   context and rewards), Handlers (the remotes and the desk prompt), Prompts (project_desk prompts).
-- Interact: "project_desk" (ProjectService/Prompts). Inside an office instance only its employees may use it
-- (CareerService:IsEmployeeOf); visitors get a polite "Employees only" toast and a hidden prompt.
-- Lifecycle: CareerService.StatusChanged "fired" cancels runs in progress (reentry is never touched: it isn't
-- ours); a move to another firm or track hands them to another team; a module update resets runs it can't continue.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local ProjectsFolder = Shared:WaitForChild("Logic"):WaitForChild("Projects")
local Registry = require(ProjectsFolder:WaitForChild("_registry"))
local Deps = require(script.Deps)
local Prompts = require(script.Prompts)
local Core = require(script.Core)
local Handlers = require(script.Handlers)

local Runs = Registry.Runs
local text = Registry.text
local num = Deps.num

local ProjectService = {
	Name = "ProjectService",
	Priority = 45,
	ProjectCompleted = Core.ProjectCompleted, -- (player, projectId, result)
	ProjectStarted = Core.ProjectStarted, -- (player, projectId)
	ProjectCancelled = Core.ProjectCancelled, -- (player, projectId, reason)
}

local RESET_TOAST_DELAY = 8
local MAX_ANSWER_KEYS = 400
local MAX_ANSWER_DEPTH = 5

---------------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------------
function ProjectService:CancelActive(player: Player, reason: string?): number
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return 0
	end
	local data = Deps.data(player)
	if not data then
		return 0
	end
	local why = if type(reason) == "string" and reason ~= "" then string.sub(reason, 1, 24) else "role"
	local n = 0
	for _, id in Runs.activeIds(data.projects, Core.modules) do
		local record = Core.recordOf(data, id)
		if Core.cancelOne(player, id, record, why) then
			n += 1
			if why ~= "fired" then
				Deps.notify(player, text("toast_cancel_role", { title = Core.modules[id].title }), "warn")
			end
		end
	end
	if n > 0 then
		if why == "fired" then
			Deps.notify(player, text("toast_cancel_fired"), "warn")
		end
		Core.changed(player, { reason = why })
	end
	return n
end

function ProjectService:GetActive(player: Player): { string }
	local data = Deps.data(player)
	return if data then Runs.activeIds(data.projects, Core.modules) else {}
end

function ProjectService:HasClosed(player: Player, projectId: string): boolean
	local data = Deps.data(player)
	if not data or type(projectId) ~= "string" or type(data.projects) ~= "table" then
		return false
	end
	local raw = data.projects[projectId]
	return type(raw) == "table" and num(raw.closed, 0) > 0
end

function ProjectService:GetModule(projectId: string): any
	return if type(projectId) == "string" then Core.modules[projectId] else nil
end

function ProjectService:ListModules(): { { [string]: any } }
	local out: { { [string]: any } } = {}
	for _, mod in Core.moduleList do
		table.insert(out, {
			id = mod.id,
			title = mod.title,
			track = mod.track,
			ranks = if type(mod.ranks) == "table" then table.clone(mod.ranks) else nil,
			signature = mod.signature == true,
		})
	end
	return out
end

function ProjectService:OpenFor(player: Player, args: { [string]: any }?)
	pcall(Net.fire, "Project.Open", player, if type(args) == "table" then args else {})
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
-- After a move (another firm, another track) runs started for the old team are handed over; a promotion on the
-- same team keeps them, so a deal you started is always yours to finish.
local function onRoleChanged(player: Player, _newRole: any, _oldRole: any, reason: any)
	if reason == "fired" then
		ProjectService:CancelActive(player, "fired")
		return
	end
	local data = Deps.data(player)
	if not data then
		return
	end
	local career = if type(data.career) == "table" then data.career else {}
	local any = false
	for _, id in Runs.activeIds(data.projects, Core.modules) do
		local mod = Core.modules[id]
		local record = Core.recordOf(data, id)
		local movedFirm = record.companyId ~= nil and record.companyId ~= Core.careerCompany(data)
		local movedTrack = mod.track ~= nil and mod.track ~= career.track
		if (movedFirm or movedTrack) and Core.cancelOne(player, id, record, "role") then
			any = true
			Deps.notify(player, text("toast_cancel_role", { title = mod.title }), "warn")
		end
	end
	Core.changed(player, { reason = if any then "role" else "career" })
end

-- A saved run the current module can't continue (the deal was updated since) is reset, with a note once the
-- player's UI is up.
local function onLoaded(player: Player, data: any)
	if type(data) ~= "table" then
		return
	end
	local reset: { string } = {}
	for _, id in Runs.activeIds(data.projects, Core.modules) do
		local record = Core.recordOf(data, id)
		if Runs.stale(Core.modules[id], record) and Core.cancelOne(player, id, record, "reset") then
			table.insert(reset, Core.modules[id].title)
		end
	end
	if #reset > 0 then
		task.delay(RESET_TOAST_DELAY, function()
			if player.Parent ~= nil then
				for _, title in reset do
					Deps.notify(player, text("toast_cancel_reset", { title = title }), "warn")
				end
			end
		end)
	end
end

function ProjectService:Init()
	Core.loadModules()
	Net.declare("Project.Open")
	Net.declare("Project.Changed")
	Net.handle("Project.List", function(player: Player)
		return Handlers.list(player)
	end, { rate = 2, burst = 6 })
	Net.handle("Project.Start", function(player: Player, projectId: any)
		local id = Guard.id(projectId)
		if not id then
			return false, "unknown"
		end
		return Core.exclusive(player, function()
			return Handlers.start(player, id)
		end)
	end, { rate = 1, burst = 3 })
	Net.handle("Project.View", function(player: Player, projectId: any)
		local id = Guard.id(projectId)
		if not id then
			return false, "unknown"
		end
		return Handlers.view(player, id)
	end, { rate = 3, burst = 8 })
	Net.handle("Project.Act", function(player: Player, projectId: any, answers: any, stageIndex: any)
		local id = Guard.id(projectId)
		if not id then
			return false, "unknown"
		end
		local clean: any = {}
		if answers ~= nil then
			clean = Guard.map(answers, MAX_ANSWER_KEYS, MAX_ANSWER_DEPTH)
			if clean == nil then
				return false, "bad_answers"
			end
		end
		local stage = if stageIndex ~= nil then Guard.int(stageIndex, 1, 64) else nil
		if stageIndex ~= nil and stage == nil then
			return false, "bad_answers"
		end
		return Core.exclusive(player, function()
			return Handlers.act(player, id, clean, stage)
		end)
	end, { rate = 1, burst = 4 })
	Net.handle("Project.Abandon", function(player: Player, projectId: any)
		local id = Guard.id(projectId)
		if not id then
			return false, "unknown"
		end
		return Core.exclusive(player, function()
			return Handlers.abandon(player, id)
		end)
	end, { rate = 1, burst = 3 })
	Players.PlayerRemoving:Connect(function(player: Player)
		Core.drop(player)
	end)
end

function ProjectService:Start()
	Prompts.start(Handlers.prompt)
	Deps.connect("CareerService", "StatusChanged", function(player: Player, new: any)
		if new == "fired" then
			ProjectService:CancelActive(player, "fired")
		end
	end)
	Deps.connect("CareerService", "RoleChanged", function(player: Player, newRole: any, oldRole: any, reason: any)
		-- deferred: CareerService finishes writing the new role before we compare against it
		task.defer(function()
			if player.Parent ~= nil then
				onRoleChanged(player, newRole, oldRole, reason)
			end
		end)
	end)
	Deps.connect("RebirthService", "Rebirthed", function(player: Player)
		-- RebirthService resets data.projects itself (contracts §4); open screens refetch
		task.defer(Core.changed, player, { reason = "rebirth" })
	end)
	Deps.connect("DataService", "ProfileLoaded", function(player: Player, data: any)
		onLoaded(player, data)
	end)
	for _, player in Players:GetPlayers() do
		local data = Deps.data(player)
		if data then
			task.spawn(onLoaded, player, data)
		end
	end
end

return ProjectService
