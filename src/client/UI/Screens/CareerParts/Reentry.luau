--!strict
-- CareerParts/Reentry (client): the re-entry interview runner on the Career Services screen. Renders one stage
-- payload at a time (contracts §8 payload kinds "mcq" and "dialogue"; the server only builds stages this
-- renderer can draw), then the stage result with feedback, then the final verdict. No timer.
--   Reentry.build(scroll, state, handlers)
--       state = { view = View, result = Result? }   (Logic/Projects/reentry view and act result)
--       handlers = { submit = (answers) -> (), continue = () -> (), retry = () -> (), back = () -> (), busy = boolean }

local Common = require(script.Parent.Common)
local Kit = Common.Kit

local Reentry = {}

export type Handlers = {
	submit: (answers: { [string]: any }) -> (),
	continue: () -> (),
	retry: () -> (),
	back: () -> (),
	busy: boolean?,
}

local function num(x: any, default: number): number
	if type(x) == "number" and x == x then
		return x
	end
	return default
end

-- A full-width answer button whose text wraps (answers can be long on phone screens).
local function optionButton(text: string, onClick: () -> ()): (TextButton, (selected: boolean) -> ())
	local b = Instance.new("TextButton")
	b.Name = "Option"
	b.Text = ""
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Size = UDim2.new(1, 0, 0, 0)
	b.AutomaticSize = Enum.AutomaticSize.Y
	local min = Instance.new("UISizeConstraint")
	min.MinSize = Vector2.new(0, Kit.TAP)
	min.Parent = b
	local corner = Kit.corner(b)
	local stroke = Kit.stroke(b)
	Kit.padding(b, 10)
	local label = Kit.Label({ text = text, size = "sm", name = "Text" })
	label.frame.Parent = b
	local selected = false
	local function paint(t: any)
		b.BackgroundColor3 = if selected then t.colors.accent else t.colors.panelAlt
		corner.CornerRadius = UDim.new(0, t.radiusSm)
		stroke.Color = if selected then t.colors.accent else t.colors.border
		stroke.Thickness = t.stroke
	end
	Kit.themed(b, paint)
	Kit.connect(b, "Activated", function()
		Kit.sound("click")
		onClick()
	end)
	return b,
		function(on: boolean)
			selected = on
			label.setColor(if on then "accentText" else "text")
			paint(Kit.Theme.get())
		end
end

-- Option buttons: one choice per question / line. Calls onPick(value) and marks the chosen one.
local function optionList(parent: any, options: { any }, onPick: (value: any) -> ())
	local setters: { (boolean) -> () } = {}
	for i, opt in options do
		local value: any = i
		local label: string = ""
		if type(opt) == "table" then
			value = if opt.id ~= nil then opt.id else i
			label = tostring(opt.text or opt.label or "")
		else
			label = tostring(opt)
		end
		local index = i
		local button, setSelected = optionButton(label, function()
			for j, set in setters do
				set(j == index)
			end
			onPick(value)
		end)
		setters[i] = setSelected
		parent.add(button)
	end
end

local function payloadCard(scroll: any, payload: { [string]: any }, answers: { [string]: any }, onChange: () -> ())
	local kind = payload.kind
	local card = Kit.Card({ title = payload.title, subtitle = payload.prompt, name = "Stage" })
	scroll.add(card)
	if kind == "dialogue" then
		local lines = if type(payload.lines) == "table" then payload.lines else {}
		for _, line in lines do
			if type(line) == "table" then
				local block = Kit.Panel({ color = "surface", padding = 10, name = "Line_" .. tostring(line.id) })
				Kit.list(block.frame, false, 6)
				if type(payload.speaker) == "string" then
					block.add(Kit.Label({ text = payload.speaker, size = "xs", color = "accent", font = "bodyBold" }))
				end
				block.add(Kit.Label({ text = tostring(line.text or ""), size = "md" }))
				optionList(block, if type(line.options) == "table" then line.options else {}, function(value: any)
					answers[tostring(line.id)] = value
					onChange()
				end)
				card.add(block)
			end
		end
	else
		local questions = if type(payload.questions) == "table" then payload.questions else {}
		for qi, q in questions do
			if type(q) == "table" then
				local block = Kit.Panel({ color = "surface", padding = 10, name = "Question_" .. qi })
				Kit.list(block.frame, false, 6)
				block.add(Kit.Label({ text = tostring(qi) .. ". " .. tostring(q.text or ""), size = "md" }))
				if type(q.context) == "string" then
					block.add(Kit.Label({ text = q.context, size = "xs", color = "textDim" }))
				end
				optionList(block, if type(q.options) == "table" then q.options else {}, function(value: any)
					answers[tostring(q.id)] = value
					onChange()
				end)
				card.add(block)
			end
		end
	end
end

local function needed(payload: { [string]: any }): number
	if payload.kind == "dialogue" then
		return if type(payload.lines) == "table" then #payload.lines else 0
	end
	return if type(payload.questions) == "table" then #payload.questions else 0
end

function Reentry.build(scroll: any, state: { view: any, result: any? }, handlers: Handlers)
	local view = state.view
	if type(view) ~= "table" then
		return
	end
	local header = Kit.Card({ title = Common.text("reentry_title"), subtitle = view.summary, name = "ReentryHeader" })
	scroll.add(header)
	local count = math.max(1, math.floor(num(view.stageCount, 3)))
	local index = math.floor(num(view.stageIndex, 1))
	header.add(Kit.ProgressBar({ value = math.clamp((index - 1) / count, 0, 1), height = 8 }))
	if not view.done and type(view.stage) == "table" then
		header.add(Kit.Label({
			text = Common.text("reentry_stage", { index = index, count = count, name = view.stage.title }),
			size = "sm",
			font = "bodyBold",
		}))
	end

	local result = state.result
	-- the stage just graded (before moving on)
	if type(result) == "table" and result.ok and not result.done then
		local card =
			Kit.Card({ title = Common.text("reentry_result", { score = num(result.score, 0) }), name = "StageResult" })
		scroll.add(card)
		for _, line in (if type(result.feedback) == "table" then result.feedback else {}) :: { any } do
			if type(line) == "string" then
				card.add(Kit.Label({ text = "• " .. line, size = "sm", color = "textDim" }))
			end
		end
		card.add(Kit.Button({ text = Common.text("reentry_continue"), fill = true, onClick = handlers.continue }))
		return
	end

	if view.done then
		local passed = view.passed == true
		local card = Kit.Card({
			title = Common.text(if passed then "reentry_passed_title" else "reentry_failed_title"),
			subtitle = Common.text("reentry_final", { score = math.floor(num(view.quality, 0)) }),
			name = "Verdict",
			color = "surface",
		})
		scroll.add(card)
		if type(result) == "table" and type(result.feedback) == "table" then
			for _, line in result.feedback do
				if type(line) == "string" then
					card.add(Kit.Label({ text = "• " .. line, size = "sm", color = "textDim" }))
				end
			end
		end
		if passed then
			card.add(Kit.Button({ text = Common.text("reentry_continue"), fill = true, onClick = handlers.back }))
		else
			card.add(Kit.Button({ text = Common.text("reentry_retry"), fill = true, onClick = handlers.retry }))
			card.add(
				Kit.Button({ text = Common.text("ui_back"), style = "ghost", fill = true, onClick = handlers.back })
			)
		end
		return
	end

	local payload = view.payload
	if type(payload) ~= "table" then
		return
	end
	local answers: { [string]: any } = {}
	local submit: any
	local total = needed(payload)
	local function refresh()
		local n = 0
		for _ in answers do
			n += 1
		end
		submit.setDisabled(handlers.busy == true or n < total)
		submit.setText(if n < total then Common.text("reentry_pick_all") else Common.text("reentry_submit"))
	end
	payloadCard(scroll, payload, answers, function()
		refresh()
	end)
	submit = Kit.Button({
		text = Common.text("reentry_submit"),
		fill = true,
		onClick = function()
			if not submit.isDisabled() then
				submit.setDisabled(true)
				handlers.submit(answers)
			end
		end,
	})
	scroll.add(submit)
	scroll.add(Kit.Button({ text = Common.text("ui_back"), style = "ghost", fill = true, onClick = handlers.back }))
	refresh()
end

return Reentry
