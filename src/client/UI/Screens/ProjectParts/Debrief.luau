--!strict
-- Project screen, stage debrief (owned by `projects`): shown after every graded stage. The stage score, what that
-- did to the deal (the module's one-line debrief: "9 buyers signed NDAs and received the CIM."), the team's notes
-- on what was wrong, and what comes next.
--
--   Debrief.build(parent, info, handlers) -> { destroy }
--   info     = { result = ProjectService stage result { stageTitle, score, debrief?, feedback, nextStage? },
--                final: boolean }
--   handlers = { onContinue: () -> () }

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("Logic"):WaitForChild("Projects"):WaitForChild("_registry"))
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local View = require(script.Parent:WaitForChild("View"))

local Debrief = {}

local text = Registry.text
local FOOTER = Kit.TAP + 12

function Debrief.build(parent: Instance, info: { [string]: any }, handlers: { [string]: any }): { destroy: () -> () }
	local result = if type(info.result) == "table" then info.result else {}
	local final = info.final == true
	local score = math.clamp(math.floor(tonumber(result.score) or 0), 0, 100)
	local color = View.qualityColor(score)

	local root = Kit.frame("Debrief")
	root.Parent = parent
	local scroll = Kit.Scroll({ gap = 10, padding = 4, name = "DebriefScroll" })
	scroll.frame.Size = UDim2.new(1, 0, 1, -FOOTER)
	scroll.frame.Parent = root

	local card = Kit.Panel({ color = "surface", list = true, gap = 8, name = "ScoreCard", layoutOrder = 1 })
	card.frame.Parent = scroll.content
	Kit.Label({
		text = text("debrief_title", { stage = tostring(result.stageTitle or "") }),
		font = "heading",
		size = "lg",
		align = "center",
		name = "Stage",
		layoutOrder = 1,
	}).frame.Parent =
		card.frame
	local big = Kit.Label({
		text = tostring(score),
		font = "display",
		size = "xxl",
		color = color,
		align = "center",
		name = "Score",
		layoutOrder = 2,
	})
	big.frame.Parent = card.frame
	Kit.Label({
		text = text("debrief_score", { score = score }),
		size = "sm",
		color = "textDim",
		align = "center",
		layoutOrder = 3,
	}).frame.Parent =
		card.frame
	local bar = Kit.ProgressBar({ value = 0, color = color, height = 12, name = "ScoreBar", layoutOrder = 4 })
	bar.frame.Parent = card.frame
	bar.set(score / 100)

	if type(result.debrief) == "string" and result.debrief ~= "" then
		local story = Kit.Panel({ color = "panelAlt", list = true, gap = 4, name = "Story", layoutOrder = 2 })
		story.frame.Parent = scroll.content
		Kit.Label({ text = "📰  " .. result.debrief, font = "bodyBold", name = "Debrief", layoutOrder = 1 }).frame.Parent =
			story.frame
	end

	local notes = if type(result.feedback) == "table" then result.feedback else {}
	if #notes > 0 then
		Kit.Label({
			text = text("result_feedback"),
			font = "bodyBold",
			color = "textDim",
			size = "sm",
			name = "NotesTitle",
			layoutOrder = 3,
		}).frame.Parent =
			scroll.content
		local list = Kit.Panel({ color = "panelAlt", list = true, gap = 6, name = "Notes", layoutOrder = 4 })
		list.frame.Parent = scroll.content
		for i, line in notes do
			if type(line) == "string" then
				Kit.Label({ text = "• " .. line, size = "sm", layoutOrder = i }).frame.Parent = list.frame
			end
		end
	end

	if not final and type(result.nextStage) == "string" then
		Kit.Label({
			text = text("debrief_next", { stage = result.nextStage }),
			color = "accent",
			font = "bodyBold",
			name = "Next",
			layoutOrder = 5,
		}).frame.Parent =
			scroll.content
	end

	local footer = Kit.frame("Footer", UDim2.new(1, 0, 0, FOOTER))
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Parent = root
	local buttons = Kit.List({ direction = "horizontal", gap = 8, justify = "end", name = "Buttons" })
	buttons.frame.AnchorPoint = Vector2.new(1, 0.5)
	buttons.frame.Position = UDim2.fromScale(1, 0.5)
	buttons.frame.Parent = footer
	Kit.Button({
		text = if final then text("debrief_final") else text("debrief_continue"),
		icon = if final then "🔔" else nil,
		name = "Continue",
		layoutOrder = 1,
		onClick = function()
			handlers.onContinue()
		end,
	}).frame.Parent =
		buttons.frame

	Kit.sound(if score >= 60 then "good" else "bad")

	return {
		destroy = function()
			root:Destroy()
		end,
	}
end

return Debrief
