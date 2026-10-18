--!strict
-- "alloc" renderer (owned by `work`; contracts §8): one card per item with − / number / + controls (44 px) in
-- steps of payload.step, and a running total against payload.total. Answers { [itemId] = number }.

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Tasks"))
local C = require(script.Parent:WaitForChild("_Common"))

local Renderer = {}

local function show(v: number): string
	if v == math.floor(v) then
		return string.format("%d", v)
	end
	return (string.gsub(string.format("%.2f", v), "0+$", ""))
end

function Renderer.mount(container: Frame, payload: { [string]: any }, api: { [string]: any }): () -> ()
	local created: { any } = {}
	local total = if type(payload.total) == "number" and payload.total > 0 then payload.total else 100
	local step = if type(payload.step) == "number" and payload.step > 0 then payload.step else 1
	local minEach = if type(payload.minEach) == "number" then payload.minEach else 0
	local maxEach = if type(payload.maxEach) == "number" then payload.maxEach else total
	local unit = if type(payload.unit) == "string" then payload.unit else ""
	local decimals = if step < 1 then (if step * 10 == math.floor(step * 10) then 1 else 2) else 0
	local answers: { [string]: number } = {}
	if type(api.answers) == "table" then
		for k, v in api.answers do
			if type(k) == "string" and type(v) == "number" and v == v then
				answers[k] = math.clamp(v, minEach, maxEach)
			end
		end
	end
	local nextOrder = C.order()
	local summary = Kit.Panel({ color = "surface", list = true, gap = 6, name = "Summary", layoutOrder = nextOrder() })
	summary.frame.Parent = container
	table.insert(created, summary.frame)
	local totalLabel = C.text(summary.frame, "", { font = "bodyBold", order = 1, name = "Total" })
	local bar = Kit.ProgressBar({ value = 0, height = 10, layoutOrder = 2, name = "Bar" })
	bar.frame.Parent = summary.frame
	local function used(): number
		local s = 0
		for _, v in answers do
			s += v
		end
		return s
	end
	local function update()
		local u = used()
		local over = u > total + 1e-6
		totalLabel.setText(Config.text(if over then "alloc_over" else "alloc_total", {
			used = show(u),
			total = show(total),
			unit = unit,
			left = show(math.max(0, total - u)),
		}))
		totalLabel.setColor(if over then "bad" else "text")
		bar.set(math.clamp(u / total, 0, 1))
		bar.setColor(if over then "bad" else "accent")
	end
	for ii, item in payload.items or {} do
		local card = C.panel(container, nextOrder(), "Item" .. ii)
		table.insert(created, card)
		C.text(card, tostring(item.text), { font = "bodyBold", order = 1, name = "ItemText" })
		if type(item.detail) == "string" and item.detail ~= "" then
			C.text(card, item.detail, { size = "sm", color = "textDim", order = 2, name = "Detail" })
		end
		local input = Kit.NumberInput({
			value = answers[item.id] or minEach,
			min = minEach,
			max = maxEach,
			step = step,
			decimals = decimals,
			width = 220,
			format = function(v: number): string
				return show(v) .. (if unit ~= "" then " " .. unit else "")
			end,
			name = "Amount",
			layoutOrder = 3,
			onChange = function(v: number)
				answers[item.id] = v
				update()
				api.onChange(C.copy(answers))
			end,
		})
		input.frame.Parent = card
	end
	update()
	return function()
		C.cleanup(created)
	end
end

return Renderer
