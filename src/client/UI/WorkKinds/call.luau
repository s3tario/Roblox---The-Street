--!strict
-- "call" renderer (owned by `work`; contracts §8): one card per item with its price chart, the news and a row
-- of call buttons (payload.options, shared by every item). Answers { [itemId] = optionIndex }.

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Tasks"))
local C = require(script.Parent:WaitForChild("_Common"))

local Renderer = {}

function Renderer.mount(container: Frame, payload: { [string]: any }, api: { [string]: any }): () -> ()
	local created: { any } = {}
	local options = if type(payload.options) == "table" then payload.options else {}
	local answers: { [string]: number } = {}
	if type(api.answers) == "table" then
		for k, v in api.answers do
			if type(k) == "string" and type(v) == "number" then
				answers[k] = v
			end
		end
	end
	local nextOrder = C.order()
	for ii, item in payload.items or {} do
		local card = C.panel(container, nextOrder(), "Call" .. ii)
		table.insert(created, card)
		C.text(card, tostring(item.label), { font = "bodyBold", size = "lg", order = 1, name = "Label" })
		local points: { number } = {}
		for _, v in item.chart or {} do
			if type(v) == "number" then
				table.insert(points, v)
			end
		end
		if #points >= 2 then
			local first, last = points[1], points[#points]
			local chart = Kit.LineChart({
				series = { { points = points, color = if last >= first then "good" else "bad", thickness = 2 } },
				size = UDim2.new(1, 0, 0, 110),
				showAxis = true,
				gridLines = 3,
				width = 300,
				height = 110,
				yFormat = function(v: number): string
					return string.format("%.0f", v)
				end,
				name = "Chart",
				layoutOrder = 2,
			})
			chart.frame.Parent = card
			local move = (last - first) / math.max(first, 1e-6)
			C.text(card, Config.text("call_move", { pct = string.format("%+.1f%%", move * 100) }), {
				size = "sm",
				color = if move >= 0 then "good" else "bad",
				order = 3,
				name = "Move",
			})
		end
		local news = item.news
		local list: { string } = {}
		if type(news) == "string" then
			table.insert(list, news)
		elseif type(news) == "table" then
			for _, n in news do
				if type(n) == "string" then
					table.insert(list, n)
				end
			end
		end
		for ni, n in list do
			C.text(card, "• " .. n, { order = 4 + ni, name = "News" .. ni })
		end
		local row = Kit.List({ direction = "horizontal", gap = 6, layoutOrder = 20, name = "Options" })
		row.frame.Size = UDim2.new(1, 0, 0, 0)
		row.frame.AutomaticSize = Enum.AutomaticSize.Y
		row.frame.Parent = card
		local count = math.max(1, #options)
		local choices: { C.Choice } = {}
		for oi, text in options do
			local choice = C.choice(row.frame, {
				text = tostring(text),
				order = oi,
				name = "Option" .. oi,
				selected = answers[item.id] == oi,
				onClick = function()
					answers[item.id] = oi
					for j, ch in choices do
						ch.setSelected(j == oi)
					end
					api.onChange(C.copy(answers))
				end,
			})
			choice.frame.Size = UDim2.new(1 / count, -math.ceil(6 * (count - 1) / count), 0, 0)
			table.insert(choices, choice)
		end
	end
	return function()
		C.cleanup(created)
	end
end

return Renderer
