--!strict
-- Player data template: merges every sibling module. Each sibling returns { [topLevelKey] = default }.
-- Ownership of each key is listed in docs/contracts.md §3. Siblings may also return
-- `_private = { key = true }` to mark keys that must never replicate to the client.

local DataTemplate = {}

local template: { [string]: any } = {}
local private: { [string]: boolean } = {
	receipts = true,
	audit = true,
	flags = true,
	altCareers = true,
	_session = true,
}

-- Keys swapped in and out when switching between the main career and a Challenge Run.
DataTemplate.CAREER_SCOPED = { "profile", "career", "portfolio", "work", "realms", "campus" }

local children = script:GetChildren()
table.sort(children, function(a, b)
	return a.Name < b.Name
end)
for _, child in children do
	if child:IsA("ModuleScript") then
		local part = (require :: any)(child)
		for key, default in part do
			if key == "_private" then
				for k in default do
					private[k] = true
				end
			else
				assert(template[key] == nil, ("DataTemplate: key '%s' defined twice (%s)"):format(key, child.Name))
				template[key] = default
			end
		end
	end
end

DataTemplate.template = template
DataTemplate.private = private

return DataTemplate
