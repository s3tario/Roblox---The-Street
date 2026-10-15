--!strict
-- Server service registry. Populated by Main.server.luau before any Init() runs.
--   local Registry = require(path.to.Registry)
--   Registry.CareerService:AddXP(player, 50, "task")   -- errors if the service doesn't exist
--   local lb = Registry.get("LeaderboardService")      -- nil (logged once) if missing

local services: { [string]: any } = {}
local warned: { [string]: boolean } = {}

local Registry = {}

function Registry.register(name: string, service: any)
	assert(services[name] == nil, "service registered twice: " .. name)
	services[name] = service
end

function Registry.get(name: string): any
	local s = services[name]
	if s == nil and not warned[name] then
		warned[name] = true
		warn("[Registry] optional service missing: " .. name)
	end
	return s
end

function Registry.all(): { [string]: any }
	return services
end

setmetatable(Registry, {
	__index = function(_, key)
		local s = services[key]
		if s == nil then
			error("[Registry] unknown service: " .. tostring(key), 2)
		end
		return s
	end,
})

return Registry
