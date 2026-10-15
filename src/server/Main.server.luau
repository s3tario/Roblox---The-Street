--!strict
-- Server bootstrap: discovers every ModuleScript in Services/, registers it, runs Init() in Priority
-- order, then Start() for each in its own thread. A failing service is reported but never stops the others.

local Registry = require(script.Parent.Registry)

local folder = script.Parent:WaitForChild("Services")
local list = {}
for _, child in folder:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, service = pcall(require, child)
		if ok and type(service) == "table" then
			service.Name = service.Name or child.Name
			Registry.register(service.Name, service)
			table.insert(list, service)
		else
			warn(("[Main] failed to load service %s: %s"):format(child.Name, tostring(service)))
		end
	end
end

table.sort(list, function(a, b)
	local pa, pb = a.Priority or 100, b.Priority or 100
	if pa == pb then
		return a.Name < b.Name
	end
	return pa < pb
end)

for _, service in list do
	if type(service.Init) == "function" then
		local ok, err = pcall(service.Init, service)
		if not ok then
			warn(("[Main] %s:Init failed: %s"):format(service.Name, tostring(err)))
		end
	end
end

for _, service in list do
	if type(service.Start) == "function" then
		task.spawn(function()
			local ok, err = xpcall(function()
				service:Start()
			end, debug.traceback)
			if not ok then
				warn(("[Main] %s:Start failed: %s"):format(service.Name, tostring(err)))
			end
		end)
	end
end

workspace:SetAttribute("ServerReady", true)
print(("[The Street] server ready with %d services"):format(#list))
