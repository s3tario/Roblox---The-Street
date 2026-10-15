--!strict
-- Client bootstrap: discovers every ModuleScript in Controllers/, runs Init() in Priority order, then
-- Start() for each in its own thread.

local Registry = require(script.Parent.Registry)

local folder = script.Parent:WaitForChild("Controllers")
local list = {}
for _, child in folder:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, controller = pcall(require, child)
		if ok and type(controller) == "table" then
			controller.Name = controller.Name or child.Name
			Registry.register(controller.Name, controller)
			table.insert(list, controller)
		else
			warn(("[Main] failed to load controller %s: %s"):format(child.Name, tostring(controller)))
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

for _, controller in list do
	if type(controller.Init) == "function" then
		local ok, err = pcall(controller.Init, controller)
		if not ok then
			warn(("[Main] %s:Init failed: %s"):format(controller.Name, tostring(err)))
		end
	end
end

for _, controller in list do
	if type(controller.Start) == "function" then
		task.spawn(function()
			local ok, err = xpcall(function()
				controller:Start()
			end, debug.traceback)
			if not ok then
				warn(("[Main] %s:Start failed: %s"):format(controller.Name, tostring(err)))
			end
		end)
	end
end
