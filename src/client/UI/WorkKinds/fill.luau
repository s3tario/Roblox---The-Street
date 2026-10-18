--!strict
-- "fill" renderer (owned by `work`; contracts §8): an optional data table, then one card per field with a
-- number box and its unit. Commas, "$", "%" and "x" are accepted. Answers { [fieldId] = number }.

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Tasks"))
local C = require(script.Parent:WaitForChild("_Common"))

local Renderer = {}

function Renderer.mount(container: Frame, payload: { [string]: any }, api: { [string]: any }): () -> ()
	local created: { any } = {}
	local answers: { [string]: number } = {}
	if type(api.answers) == "table" then
		for k, v in api.answers do
			if type(k) == "string" and type(v) == "number" then
				answers[k] = v
			end
		end
	end
	local nextOrder = C.order()
	local tbl = payload.table
	if type(tbl) == "table" and type(tbl.columns) == "table" and type(tbl.rows) == "table" then
		local grid = C.grid(container, tbl.columns, tbl.rows, { order = nextOrder(), name = "DataTable" })
		table.insert(created, grid.frame)
	end
	for fi, field in payload.fields or {} do
		local card = C.panel(container, nextOrder(), "Field" .. fi)
		table.insert(created, card)
		C.text(card, tostring(field.label), { font = "bodyBold", order = 1, name = "FieldLabel" })
		local row =
			Kit.List({ direction = "horizontal", gap = 8, align = "center", layoutOrder = 2, name = "InputRow" })
		row.frame.Size = UDim2.new(1, 0, 0, Kit.TAP)
		row.frame.AutomaticSize = Enum.AutomaticSize.None
		row.frame.Parent = card
		local unit = if type(field.unit) == "string" then field.unit else ""
		local warnLabel: Kit.Label? = nil
		local existing = answers[field.id]
		local input = Kit.TextInput({
			value = if existing ~= nil then tostring(existing) else "",
			placeholder = Config.text("fill_placeholder"),
			maxLength = 24,
			mono = true,
			size = UDim2.new(1, if unit ~= "" then -72 else 0, 0, Kit.TAP),
			name = "Input",
			layoutOrder = 1,
			onChange = function(text: string)
				local n = C.number(text)
				if n ~= nil then
					answers[field.id] = n
				else
					answers[field.id] = nil
				end
				if warnLabel then
					warnLabel.frame.Visible = text ~= "" and n == nil
				end
				api.onChange(C.copy(answers))
			end,
		})
		input.frame.Parent = row.frame
		if unit ~= "" then
			local u = C.text(row.frame, unit, { color = "textDim", order = 2, name = "Unit" })
			u.frame.AutomaticSize = Enum.AutomaticSize.XY
			u.frame.Size = UDim2.fromOffset(0, 0)
		end
		local w =
			C.text(card, Config.text("fill_not_number"), { size = "sm", color = "warn", order = 3, name = "Warn" })
		w.frame.Visible = false
		warnLabel = w
		if type(field.hint) == "string" and field.hint ~= "" then
			C.text(card, field.hint, { size = "sm", color = "textDim", order = 4, name = "Hint" })
		end
	end
	return function()
		C.cleanup(created)
	end
end

return Renderer
