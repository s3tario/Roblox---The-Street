--!strict
-- "match" renderer (owned by `work`; contracts §8): one card per left-hand item with a picker of the right-hand
-- options (a phone-friendly sheet, so long texts stay readable). Answers { [leftId] = rightId }.

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Tasks"))
local C = require(script.Parent:WaitForChild("_Common"))

local Renderer = {}

function Renderer.mount(container: Frame, payload: { [string]: any }, api: { [string]: any }): () -> ()
	local created: { any } = {}
	local answers: { [string]: string } = {}
	local options: { any } = {}
	local valid: { [string]: boolean } = {}
	for _, r in payload.right or {} do
		if type(r) == "table" and type(r.id) == "string" then
			table.insert(options, { id = r.id, text = tostring(r.text) })
			valid[r.id] = true
		end
	end
	if type(api.answers) == "table" then
		for k, v in api.answers do
			if type(k) == "string" and type(v) == "string" and valid[v] then
				answers[k] = v
			end
		end
	end
	local nextOrder = C.order()
	for li, left in payload.left or {} do
		local card = C.panel(container, nextOrder(), "Pair" .. li)
		table.insert(created, card)
		C.text(card, tostring(left.text), { font = "bodyBold", order = 1, name = "LeftText" })
		local dd = Kit.Dropdown({
			options = options,
			value = answers[left.id],
			placeholder = Config.text("match_pick"),
			title = tostring(left.text),
			name = "Picker",
			layoutOrder = 2,
			onChange = function(id: string)
				answers[left.id] = id
				api.onChange(C.copy(answers))
			end,
		})
		dd.frame.Parent = card
	end
	return function()
		C.cleanup(created)
	end
end

return Renderer
