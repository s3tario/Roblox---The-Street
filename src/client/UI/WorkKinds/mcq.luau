--!strict
-- "mcq" renderer (owned by `work`; contracts §8): one card per question with an optional context line and
-- full-width answer buttons. Answers { [questionId] = optionIndex }.

local C = require(script.Parent:WaitForChild("_Common"))

local Renderer = {}

local LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H" }

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
	local questions = if type(payload.questions) == "table" then payload.questions else {}
	for qi, q in questions do
		local card = C.panel(container, nextOrder(), "Question" .. qi)
		table.insert(created, card)
		if type(q.context) == "string" and q.context ~= "" then
			C.text(card, q.context, { size = "sm", color = "textDim", order = 1 })
		end
		C.text(card, tostring(qi) .. ". " .. tostring(q.text), { font = "bodyBold", order = 2, name = "QuestionText" })
		local choices: { C.Choice } = {}
		for oi, optionText in q.options or {} do
			local choice = C.choice(card, {
				text = (LETTERS[oi] or tostring(oi)) .. ".  " .. tostring(optionText),
				order = 10 + oi,
				name = "Option" .. oi,
				selected = answers[q.id] == oi,
				onClick = function()
					answers[q.id] = oi
					for j, other in choices do
						other.setSelected(j == oi)
					end
					api.onChange(C.copy(answers))
				end,
			})
			table.insert(choices, choice)
		end
	end
	return function()
		C.cleanup(created)
	end
end

return Renderer
