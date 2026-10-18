--!strict
-- "order" renderer (owned by `work`; contracts §8): the items as numbered rows. Tap a row to pick it, then use
-- the arrows (44 px) to move it up or down. Answers { itemId, ... } in the current order (the starting order
-- counts as an answer, so it is reported straight away).

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local C = require(script.Parent:WaitForChild("_Common"))

local Renderer = {}

function Renderer.mount(container: Frame, payload: { [string]: any }, api: { [string]: any }): () -> ()
	local created: { any } = {}
	local items: { [string]: string } = {}
	local order: { string } = {}
	for _, item in payload.items or {} do
		if type(item) == "table" and type(item.id) == "string" then
			items[item.id] = tostring(item.text)
			table.insert(order, item.id)
		end
	end
	-- restore a previous order when it lists exactly these items
	if type(api.answers) == "table" and #api.answers == #order then
		local seen: { [string]: boolean } = {}
		local ok = true
		for _, id in api.answers do
			if type(id) ~= "string" or items[id] == nil or seen[id] then
				ok = false
				break
			end
			seen[id] = true
		end
		if ok then
			order = table.clone(api.answers)
		end
	end
	local list = Kit.List({ gap = 6, layoutOrder = 1, name = "OrderList" })
	list.frame.Parent = container
	table.insert(created, list.frame)
	local selected: string? = nil
	type Row = { frame: Frame, choice: C.Choice, index: TextLabel }
	local rows: { [string]: Row } = {}

	local function refresh()
		for i, id in order do
			local row = rows[id]
			row.frame.LayoutOrder = i
			row.index.Text = tostring(i)
			row.choice.setSelected(selected == id)
		end
	end

	local function move(id: string, delta: number)
		local i = table.find(order, id)
		if not i then
			return
		end
		local j = math.clamp(i + delta, 1, #order)
		if j == i then
			return
		end
		order[i], order[j] = order[j], order[i]
		selected = id
		refresh()
		api.onChange(table.clone(order))
	end

	for i, id in order do
		local frame = Instance.new("Frame")
		frame.Name = "Row_" .. id
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.LayoutOrder = i
		local index = Instance.new("TextLabel")
		index.Name = "Index"
		index.BackgroundTransparency = 1
		index.Size = UDim2.fromOffset(28, Kit.TAP)
		index.Text = tostring(i)
		index.Parent = frame
		Kit.themed(index, function(t)
			index.FontFace = t.fonts.mono
			index.TextSize = t.text.lg
			index.TextColor3 = t.colors.accent
		end)
		local body = Instance.new("Frame")
		body.Name = "Body"
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(32, 0)
		body.Size = UDim2.new(1, -32 - (Kit.TAP + 6) * 2, 0, 0)
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.Parent = frame
		local choice = C.choice(body, {
			text = items[id],
			name = "Item",
			onClick = function()
				selected = if selected == id then nil else id
				refresh()
			end,
		})
		local up = Kit.IconButton({
			glyph = "▲",
			name = "Up",
			onClick = function()
				move(id, -1)
			end,
		})
		up.frame.AnchorPoint = Vector2.new(1, 0)
		up.frame.Position = UDim2.new(1, -(Kit.TAP + 6), 0, 0)
		up.frame.Parent = frame
		local down = Kit.IconButton({
			glyph = "▼",
			name = "Down",
			onClick = function()
				move(id, 1)
			end,
		})
		down.frame.AnchorPoint = Vector2.new(1, 0)
		down.frame.Position = UDim2.fromScale(1, 0)
		down.frame.Parent = frame
		frame.Parent = list.frame
		rows[id] = { frame = frame, choice = choice, index = index }
	end
	refresh()
	api.onChange(table.clone(order))
	return function()
		C.cleanup(created)
	end
end

return Renderer
