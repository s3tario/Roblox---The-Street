--!strict
-- ProjectService/Core (server, runtime only): the loaded deal modules, per-player request state, the signals and the
-- small record helpers every part of the service shares.
--
--   Core.modules : { [id] = module }   Core.moduleList : { module } (sorted)   Core.loadModules()
--   Core.ProjectCompleted / ProjectStarted / ProjectCancelled : Signal   (re-exported by ProjectService)
--   Core.stateOf(player) -> { busy, lastPrompt }   Core.drop(player)
--   Core.projectsOf(data) / Core.recordOf(data, id) -> Record   Core.activeCount(data)   Core.careerCompany(data)
--   Core.cancelOne(player, id, record, reason) -> boolean      "abandoned" keeps the short cooldown, others don't
--   Core.exclusive(player, fn) -> ...    one mutating request per player at a time ("busy" otherwise)
--   Core.changed(player, info?)          Project.Changed to that client
--   Core.companyName(id) / Core.trackName(id) -> string?

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Time = require(Shared.Util.Time)
local ProjectsFolder = Shared:WaitForChild("Logic"):WaitForChild("Projects")
local Registry = require(ProjectsFolder:WaitForChild("_registry"))
local Deps = require(script.Parent.Deps)

local Runs = Registry.Runs

local ConfigFolder = Shared:WaitForChild("Config")
local Companies = Deps.require(ConfigFolder:FindFirstChild("Companies"))
local Tracks = Deps.require(ConfigFolder:FindFirstChild("Tracks"))

local Core = {
	ProjectCompleted = Signal.new(), -- (player, projectId, result)
	ProjectStarted = Signal.new(), -- (player, projectId)
	ProjectCancelled = Signal.new(), -- (player, projectId, reason)
}

local modules: { [string]: any } = {}
Core.modules = modules
Core.moduleList = {} :: { any }

type PlayerState = { busy: boolean, lastPrompt: number }
local states: { [Player]: PlayerState } = {}

function Core.stateOf(player: Player): PlayerState
	local st = states[player]
	if not st then
		st = { busy = false, lastPrompt = -math.huge }
		states[player] = st
	end
	return st
end

function Core.drop(player: Player)
	states[player] = nil
end

function Core.companyName(id: any): string?
	if type(id) ~= "string" or not Companies or type(Companies.get) ~= "function" then
		return nil
	end
	local ok, def = pcall(Companies.get, id)
	if ok and type(def) == "table" and type(def.name) == "string" then
		return def.name
	end
	return nil
end

function Core.trackName(id: any): string?
	if type(id) ~= "string" or not Tracks or type(Tracks.get) ~= "function" then
		return nil
	end
	local ok, def = pcall(Tracks.get, id)
	if ok and type(def) == "table" and type(def.name) == "string" then
		return def.name
	end
	return nil
end

function Core.loadModules()
	local moduleList: { any } = {}
	for _, child in ProjectsFolder:GetChildren() do
		local name = child.Name
		if child:IsA("ModuleScript") and string.sub(name, 1, 1) ~= "_" and not Registry.EXTERNAL[name] then
			local mod = Deps.require(child)
			if mod ~= nil then
				local ok, err = Registry.check(mod)
				if ok and Registry.listed(mod) then
					if modules[mod.id] then
						warn(("[ProjectService] duplicate project id %s (%s): skipped"):format(mod.id, name))
					else
						modules[mod.id] = mod
						table.insert(moduleList, mod)
					end
				else
					warn(("[ProjectService] skipping project module %s: %s"):format(name, tostring(err)))
				end
			end
		end
	end
	Core.moduleList = Registry.sorted(moduleList)
end

function Core.projectsOf(data: { [string]: any }): { [string]: any }
	local p = data.projects
	if type(p) ~= "table" then
		p = {}
		data.projects = p
	end
	return p
end

function Core.recordOf(data: { [string]: any }, id: string): Registry.Record
	local projects = Core.projectsOf(data)
	local r = Registry.record(projects[id])
	projects[id] = r
	return r
end

function Core.activeCount(data: { [string]: any }): number
	return #Runs.activeIds(data.projects, modules)
end

function Core.changed(player: Player, info: { [string]: any }?)
	if player.Parent ~= nil then
		pcall(Net.fire, "Project.Changed", player, info or {})
	end
end

function Core.careerCompany(data: { [string]: any }): string?
	local career = data.career
	if type(career) == "table" and type(career.companyId) == "string" and career.companyId ~= "" then
		return career.companyId
	end
	return nil
end

-- Drops one run in progress; cancellations other than the player's own choice carry no cooldown.
function Core.cancelOne(player: Player, id: string, record: Registry.Record, reason: string): boolean
	local cooldown = if reason == "abandoned" then nil else 0
	if Runs.abandon(record, Time.now(), cooldown) then
		Core.ProjectCancelled:Fire(player, id, reason)
		Deps.audit(player, "project_cancel", { id = id, reason = reason })
		return true
	end
	return false
end

-- Serializes a player's mutating requests: a second Start/Act/Abandon while the first one is still yielding (reward
-- calls into other services) answers "busy" instead of interleaving.
function Core.exclusive(player: Player, fn: () -> (boolean, any, any)): (boolean, any, any)
	local st = Core.stateOf(player)
	if st.busy then
		return false, "busy", nil
	end
	st.busy = true
	local ok, a, b, c = pcall(fn)
	st.busy = false
	if not ok then
		Deps.warnOnce("remote", a)
		return false, "generic", nil
	end
	return a, b, c
end

return Core
