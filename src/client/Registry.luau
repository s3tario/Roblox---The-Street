--!strict
-- Client controller registry. Populated by Main.client.luau.
--   local Registry = require(path.to.Client.Registry)
--   Registry.UIController:Open("Terminal")
--   Registry.get("TerminalController") -- nil (logged once) if missing

local controllers: { [string]: any } = {}
local warned: { [string]: boolean } = {}

local Registry = {}

function Registry.register(name: string, controller: any)
	assert(controllers[name] == nil, "controller registered twice: " .. name)
	controllers[name] = controller
end

function Registry.get(name: string): any
	local c = controllers[name]
	if c == nil and not warned[name] then
		warned[name] = true
		warn("[Registry] optional controller missing: " .. name)
	end
	return c
end

function Registry.all(): { [string]: any }
	return controllers
end

setmetatable(Registry, {
	__index = function(_, key)
		local c = controllers[key]
		if c == nil then
			error("[Registry] unknown controller: " .. tostring(key), 2)
		end
		return c
	end,
})

return Registry
