--!strict
-- "dialogue" renderer (owned by `work`; contracts §8): a conversation with payload.speaker. Each turn shows what
-- they say and your possible replies; the next turn appears once you answer (earlier replies can still be
-- changed). Answers { [lineId] = optionId }.

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local C = require(script.Parent:WaitForChild("_Common"))

local Renderer = {}

function Renderer.mount(container: Frame, payload: { [string]: any }, api: { [string]: any }): () -> ()
	local created: { any } = {}
	local lines = if type(payload.lines) == "table" then payload.lines else {}
	local answers: { [string]: string } = {}
	if type(api.answers) == "table" then
		for k, v in api.answers do
			if type(k) == "string" and type(v) == "string" then
				answers[k] = v
			end
		end
	end
	local speaker = if type(payload.speaker) == "string" then payload.speaker else ""
	if speaker ~= "" then
		local head = C.text(container, speaker, { font = "bodyBold", color = "accent", order = 1, name = "Speaker" })
		table.insert(created, head.frame)
	end
	local turns: { Frame } = {}
	local function reveal()
		local open = true
		for i, line in lines do
			local turn = turns[i]
			if turn then
				turn.Visible = open
			end
			if answers[line.id] == nil then
				open = false
			end
		end
	end
	for i, line in lines do
		local turn = Kit.Panel({ color = "panelAlt", list = true, gap = 8, name = "Turn" .. i, layoutOrder = 10 + i })
		turn.frame.Parent = container
		table.insert(created, turn.frame)
		turns[i] = turn.frame
		local bubble = Kit.Panel({ color = "surface", padding = 10, name = "Bubble", layoutOrder = 1 })
		bubble.frame.Parent = turn.frame
		C.text(bubble.frame, "“" .. tostring(line.text) .. "”", { font = "body", name = "Says" })
		local choices: { [string]: C.Choice } = {}
		for oi, opt in line.options or {} do
			local optId = opt.id
			choices[optId] = C.choice(turn.frame, {
				text = tostring(opt.text),
				order = 10 + oi,
				name = "Reply" .. oi,
				selected = answers[line.id] == optId,
				onClick = function()
					answers[line.id] = optId
					for id, ch in choices do
						ch.setSelected(id == optId)
					end
					reveal()
					api.onChange(C.copy(answers))
				end,
			})
		end
	end
	reveal()
	return function()
		C.cleanup(created)
	end
end

return Renderer
