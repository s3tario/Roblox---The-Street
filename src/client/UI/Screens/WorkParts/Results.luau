--!strict
-- Work screen, results (owned by `work`): the quality score, what you earned, what you trained and the grader's
-- specific feedback, with "Back to board" and "Close".
--
--   Results.build(parent, result, handlers) -> { destroy }
--   result   = WorkService's submit result { title, quality, correct, total, feedback, sections, onTime, xp,
--              xpCapped, pay, paid, rep, stats }
--   handlers = { onBack: () -> (), onClose: () -> () }

local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Tasks"))
local View = require(script.Parent:WaitForChild("View"))

local Results = {}

local FOOTER = Kit.TAP + 12

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function Results.build(parent: Instance, result: any, handlers: { [string]: any }): { destroy: () -> () }
	local root = Kit.frame("Results")
	root.Parent = parent
	local scroll = Kit.Scroll({ gap = 10, padding = 4, name = "ResultsScroll" })
	scroll.frame.Size = UDim2.new(1, 0, 1, -FOOTER)
	scroll.frame.Parent = root
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local q = math.floor(num(result.quality, 0))
	local color = View.qualityColor(q)
	local feedback: { string } = {}
	for _, line in result.feedback or {} do
		if type(line) == "string" then
			table.insert(feedback, line)
		end
	end

	Kit.Label({
		text = tostring(result.title or Config.text("result_title")),
		font = "bodyBold",
		size = "lg",
		name = "Title",
		layoutOrder = nextOrder(),
	}).frame.Parent =
		scroll.content

	-- the score
	local scoreCard = Kit.Panel({ color = "surface", list = true, gap = 6, name = "Score", layoutOrder = nextOrder() })
	scoreCard.frame.Parent = scroll.content
	Kit.Label({
		text = Config.text("result_quality"),
		size = "sm",
		color = "textDim",
		align = "center",
		layoutOrder = 1,
	}).frame.Parent =
		scoreCard.frame
	Kit.Label({
		text = tostring(q),
		font = "display",
		size = "xxl",
		color = color,
		align = "center",
		name = "Quality",
		layoutOrder = 2,
	}).frame.Parent =
		scoreCard.frame
	local bar = Kit.ProgressBar({ value = q / 100, color = color, height = 12, layoutOrder = 3, name = "QualityBar" })
	bar.frame.Parent = scoreCard.frame
	if feedback[1] then
		Kit.Label({ text = feedback[1], align = "center", layoutOrder = 4, name = "Summary" }).frame.Parent =
			scoreCard.frame
	end
	if num(result.total, 0) > 0 then
		Kit.Label({
			text = Config.text(
				"result_correct",
				{ correct = math.floor(num(result.correct, 0)), total = math.floor(num(result.total, 0)) }
			),
			size = "sm",
			color = "textDim",
			align = "center",
			layoutOrder = 5,
			name = "Correct",
		}).frame.Parent =
			scoreCard.frame
	end

	-- what you earned
	local earned =
		Kit.List({ direction = "horizontal", wraps = true, gap = 6, name = "Earned", layoutOrder = nextOrder() })
	earned.frame.Size = UDim2.new(1, 0, 0, 0)
	earned.frame.AutomaticSize = Enum.AutomaticSize.Y
	earned.frame.Parent = scroll.content
	local bi = 0
	local function badge(text: string, c: string)
		bi += 1
		Kit.Badge({ text = text, color = c, size = "sm", layoutOrder = bi }).frame.Parent = earned.frame
	end
	badge(
		if result.onTime == false then Config.text("result_late") else Config.text("result_on_time"),
		if result.onTime == false then "warn" else "good"
	)
	badge(Config.text("result_xp", { xp = Format.commas(math.floor(num(result.xp, 0))) }), "accent")
	if result.paid == true and num(result.pay, 0) > 0 then
		badge(Config.text("result_pay", { pay = Format.money(math.floor(num(result.pay, 0))) }), "good")
	end
	if num(result.rep, 0) > 0 then
		badge(Config.text("toast_client_rep", { rep = result.rep }), "good")
	end
	if result.xpCapped == true then
		Kit.Label({
			text = Config.text("toast_xp_capped"),
			size = "sm",
			color = "warn",
			layoutOrder = nextOrder(),
			name = "Capped",
		}).frame.Parent =
			scroll.content
	end
	if type(result.stats) == "table" and #result.stats > 0 then
		Kit.Label({
			text = Config.text("result_stats", { stats = table.concat(result.stats, ", ") }),
			size = "sm",
			color = "textDim",
			layoutOrder = nextOrder(),
			name = "Trained",
		}).frame.Parent =
			scroll.content
	end

	-- part scores for multi-part tasks
	local sections = if type(result.sections) == "table" then result.sections else {}
	if #sections > 1 then
		local parts = Kit.Panel({ color = "panelAlt", list = true, gap = 4, name = "Parts", layoutOrder = nextOrder() })
		parts.frame.Parent = scroll.content
		for i, s in sections do
			local kind = Config.kinds[s.kind]
			local score = math.floor(num(s.score, 0))
			Kit.Label({
				text = Config.text("runner_part", { i = i, n = #sections }) .. " · " .. (if kind
					then kind.name
					else tostring(s.kind)) .. ": " .. tostring(score),
				size = "sm",
				color = View.qualityColor(score),
				layoutOrder = i,
			}).frame.Parent =
				parts.frame
		end
	end

	-- the grader's notes
	if #feedback > 1 then
		local notes =
			Kit.Panel({ color = "panelAlt", list = true, gap = 6, name = "Feedback", layoutOrder = nextOrder() })
		notes.frame.Parent = scroll.content
		for i = 2, #feedback do
			Kit.Label({ text = "• " .. feedback[i], size = "sm", layoutOrder = i, name = "Note" .. (i - 1) }).frame.Parent =
				notes.frame
		end
	end

	-- footer
	local footer = Kit.frame("Footer", UDim2.new(1, 0, 0, FOOTER))
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Parent = root
	local buttons = Kit.List({ direction = "horizontal", gap = 8, justify = "end", name = "Buttons" })
	buttons.frame.AnchorPoint = Vector2.new(1, 0.5)
	buttons.frame.Position = UDim2.fromScale(1, 0.5)
	buttons.frame.Parent = footer
	Kit.Button({
		text = Config.text("result_close"),
		style = "secondary",
		name = "Close",
		layoutOrder = 1,
		onClick = function()
			handlers.onClose()
		end,
	}).frame.Parent =
		buttons.frame
	Kit.Button({
		text = Config.text("result_back"),
		name = "Back",
		layoutOrder = 2,
		onClick = function()
			handlers.onBack()
		end,
	}).frame.Parent =
		buttons.frame

	return {
		destroy = function()
			root:Destroy()
		end,
	}
end

return Results
