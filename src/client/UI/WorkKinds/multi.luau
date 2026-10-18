--!strict
-- "multi" renderer (owned by `work`; contracts §8): each section under a "Part i of n" header, drawn by its own
-- kind's renderer. Answers { [i] = sectionAnswers } with every index present (an empty table until answered), so
-- the list never has holes when it crosses the network.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Tasks"))
local C = require(script.Parent:WaitForChild("_Common"))

local Renderer = {}

function Renderer.mount(container: Frame, payload: { [string]: any }, api: { [string]: any }): () -> ()
	local created: { any } = {}
	local cleanups: { () -> () } = {}
	local sections = if type(payload.sections) == "table" then payload.sections else {}
	local answers: { any } = {}
	for i = 1, #sections do
		local prev = if type(api.answers) == "table" then api.answers[i] else nil
		answers[i] = if type(prev) == "table" then C.copy(prev) else {}
	end
	local mounting = true
	for i, section in sections do
		local header = C.text(
			container,
			Config.text("runner_part", { i = i, n = #sections })
				.. (if type(section.title) == "string" then " · " .. section.title else ""),
			{ font = "bodyBold", size = "lg", color = "accent", order = i * 10, name = "PartHeader" .. i }
		)
		table.insert(created, header.frame)
		if type(section.prompt) == "string" and section.prompt ~= "" then
			local p =
				C.text(container, section.prompt, { color = "textDim", order = i * 10 + 1, name = "PartPrompt" .. i })
			table.insert(created, p.frame)
		end
		local holder = Instance.new("Frame")
		holder.Name = "Part" .. i
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, 0, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.LayoutOrder = i * 10 + 2
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		layout.Parent = holder
		holder.Parent = container
		table.insert(created, holder)
		local module = script.Parent:FindFirstChild(tostring(section.kind))
		local ok, renderer = false, nil
		if module and module:IsA("ModuleScript") and section.kind ~= "multi" then
			ok, renderer = pcall(require, module)
		end
		if ok and type(renderer) == "table" and type(renderer.mount) == "function" then
			local index = i
			local mounted, cleanup = pcall(renderer.mount, holder, section, {
				answers = answers[index],
				onChange = function(sub: any)
					answers[index] = if type(sub) == "table" then sub else {}
					if not mounting then
						api.onChange(C.copy(answers))
					end
				end,
			})
			if mounted and type(cleanup) == "function" then
				table.insert(cleanups, cleanup)
			elseif not mounted then
				warn("[Work] section renderer failed: " .. tostring(cleanup))
				C.text(holder, Config.text("runner_part_error"), { color = "bad", name = "Error" })
			end
		else
			C.text(holder, Config.text("runner_part_error"), { color = "bad", name = "Error" })
		end
	end
	mounting = false
	api.onChange(C.copy(answers))
	return function()
		for _, fn in cleanups do
			pcall(fn)
		end
		C.cleanup(created)
	end
end

return Renderer
