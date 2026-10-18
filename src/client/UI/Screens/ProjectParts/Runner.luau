--!strict
-- Project screen, stage runner (owned by `projects`): the stage stepper, the deal room (running summary and
-- metrics), the stage brief and hints, the stage payload drawn by the work feature's UI/WorkKinds/<kind> renderer
-- (required by name at runtime; a missing or broken renderer shows a polite note instead), and the footer with
-- answer progress, Abandon and Submit.
--
--   Runner.build(parent, view, handlers) -> { destroy, setBusy(busy), answers() -> any }
--   view     = ProjectService's view { id, title, glyph, dealName, stage, stageIndex, stageCount, stages, summary,
--              payload, signature }
--   handlers = { onSubmit: (answers) -> (), onAbandon: () -> (), confirm: (opts, cb) -> (), draft: any?,
--                onDraft: (answers) -> ()? }

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("Logic"):WaitForChild("Projects"):WaitForChild("_registry"))
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local View = require(script.Parent:WaitForChild("View"))

local Runner = {}

local text = Registry.text
local FOOTER = Kit.TAP + 12
local STEPPER = Kit.TAP + 8
local TILE_W = 150

local function renderer(kind: any): any
	if type(kind) ~= "string" then
		return nil
	end
	local UI = script.Parent.Parent.Parent
	local folder = UI:FindFirstChild("WorkKinds")
	local module = if folder then folder:FindFirstChild(kind) else nil
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, r = pcall(require, module)
	if ok and type(r) == "table" and type(r.mount) == "function" then
		return r
	end
	warn("[Project] renderer " .. kind .. " failed to load: " .. tostring(r))
	return nil
end

local function toneColor(tone: any): string
	return if tone == "good" then "good" elseif tone == "bad" then "bad" elseif tone == "warn" then "warn" else "text"
end

-- One chip per stage: done stages show their score, the current one is highlighted.
local function buildStepper(parent: Instance, view: any): ScrollingFrame
	local strip = Kit.Scroll({ direction = "horizontal", gap = 6, padding = 2, name = "Stepper" })
	strip.frame.Size = UDim2.new(1, 0, 0, STEPPER)
	strip.frame.Parent = parent
	local stages = if type(view.stages) == "table" then view.stages else {}
	for i, s in stages do
		local status = if type(s) == "table" then s.status else "next"
		local label: string
		if status == "done" then
			label = text("stage_done", { score = math.floor(tonumber(s.score) or 0) })
		elseif status == "current" then
			label = text("stage_now")
		else
			label = text("stage_next")
		end
		local chip = Kit.Badge({
			text = string.format("%d · %s · %s", i, tostring(s.title or ""), label),
			color = if status == "current" then "accent" elseif status == "done" then "surface" else "panelAlt",
			size = "sm",
			name = "Stage" .. i,
			layoutOrder = i,
		})
		local min = Instance.new("UISizeConstraint")
		min.MinSize = Vector2.new(0, Kit.TAP - 8)
		min.Parent = chip.frame
		chip.frame.Parent = strip.content
	end
	return strip.frame
end

local function buildDealRoom(parent: Instance, view: any, order: number)
	local summary = if type(view.summary) == "table" then view.summary else {}
	local panel = Kit.Panel({ color = "surface", list = true, gap = 8, name = "DealRoom", layoutOrder = order })
	panel.frame.Parent = parent
	Kit.Label({
		text = text("runner_metrics"),
		size = "xs",
		color = "textDim",
		font = "bodyBold",
		name = "RoomTitle",
		layoutOrder = 1,
	}).frame.Parent =
		panel.frame
	if type(summary.text) == "string" and summary.text ~= "" then
		Kit.Label({ text = summary.text, size = "sm", name = "Narrative", layoutOrder = 2 }).frame.Parent = panel.frame
	end
	local tiles = Kit.List({ direction = "horizontal", wraps = true, gap = 6, name = "Metrics", layoutOrder = 3 })
	tiles.frame.Size = UDim2.new(1, 0, 0, 0)
	tiles.frame.AutomaticSize = Enum.AutomaticSize.Y
	tiles.frame.Parent = panel.frame
	local metrics = if type(summary.metrics) == "table" then summary.metrics else {}
	for i, m in metrics do
		if type(m) == "table" then
			local tile = Kit.Panel({
				color = "panelAlt",
				list = true,
				gap = 2,
				padding = 8,
				size = UDim2.fromOffset(TILE_W, 0),
				autoSize = "y",
				name = "Metric" .. i,
				layoutOrder = i,
			})
			tile.frame.Parent = tiles.frame
			Kit.Label({ text = tostring(m.label or ""), size = "xs", color = "textDim", layoutOrder = 1 }).frame.Parent =
				tile.frame
			Kit.Label({
				text = tostring(m.value or "—"),
				size = "md",
				font = "bodyBold",
				color = toneColor(m.tone),
				name = "Value",
				layoutOrder = 2,
			}).frame.Parent =
				tile.frame
		end
	end
end

function Runner.build(parent: Instance, view: any, handlers: { [string]: any }): { [string]: any }
	local payload = if type(view.payload) == "table" then view.payload else {}
	local stage = if type(view.stage) == "table" then view.stage else {}
	local stageIndex = math.floor(tonumber(view.stageIndex) or 1)
	local stageCount = math.floor(tonumber(view.stageCount) or 1)
	local final = stageIndex >= stageCount
	local root = Kit.frame("Runner")
	root.Parent = parent

	buildStepper(root, view)

	local scroll = Kit.Scroll({ gap = 10, padding = 4, name = "RunnerScroll" })
	scroll.frame.Position = UDim2.fromOffset(0, STEPPER + 4)
	scroll.frame.Size = UDim2.new(1, 0, 1, -(STEPPER + 4 + FOOTER))
	scroll.frame.Parent = root
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	Kit.Label({
		text = (if type(view.glyph) == "string" then view.glyph .. "  " else "") .. tostring(view.dealName or ""),
		font = "heading",
		size = "lg",
		color = "accent",
		name = "DealName",
		layoutOrder = nextOrder(),
	}).frame.Parent =
		scroll.content
	buildDealRoom(scroll.content, view, nextOrder())

	Kit.Label({
		text = text("runner_stage", { i = stageIndex, n = stageCount }) .. " · " .. tostring(stage.title or ""),
		font = "bodyBold",
		size = "lg",
		name = "StageTitle",
		layoutOrder = nextOrder(),
	}).frame.Parent =
		scroll.content
	if type(stage.brief) == "string" and stage.brief ~= "" then
		Kit.Label({ text = stage.brief, size = "sm", color = "textDim", name = "Brief", layoutOrder = nextOrder() }).frame.Parent =
			scroll.content
	end

	local hints = if type(payload.hints) == "table" then payload.hints else {}
	if #hints > 0 then
		local toggleOrder = nextOrder()
		local panel = Kit.Panel({ color = "surface", list = true, gap = 4, name = "Hints", layoutOrder = nextOrder() })
		panel.frame.Visible = false
		for i, h in hints do
			Kit.Label({ text = "💡 " .. tostring(h), size = "sm", layoutOrder = i }).frame.Parent = panel.frame
		end
		local toggle: Kit.Button
		toggle = Kit.Button({
			text = text("runner_hints_show", { n = #hints }),
			style = "ghost",
			name = "HintsToggle",
			layoutOrder = toggleOrder,
			onClick = function()
				panel.frame.Visible = not panel.frame.Visible
				toggle.setText(
					if panel.frame.Visible then text("runner_hints_hide") else text("runner_hints_show", { n = #hints })
				)
			end,
		})
		toggle.frame.Parent = scroll.content
		panel.frame.Parent = scroll.content
	end
	if type(payload.prompt) == "string" and payload.prompt ~= "" then
		Kit.Label({ text = payload.prompt, name = "Prompt", layoutOrder = nextOrder() }).frame.Parent = scroll.content
	end
	local content = Kit.frame("Content", UDim2.new(1, 0, 0, 0))
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.LayoutOrder = nextOrder()
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = content
	content.Parent = scroll.content

	-- footer: progress + abandon + submit
	local footer = Kit.frame("Footer", UDim2.new(1, 0, 0, FOOTER))
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Parent = root
	local progress = Kit.Label({
		text = "",
		size = "sm",
		color = "textDim",
		autoSize = "none",
		width = UDim.new(0.3, 0),
		height = FOOTER,
		name = "Progress",
	})
	progress.frame.Parent = footer
	local buttons = Kit.List({ direction = "horizontal", gap = 8, justify = "end", name = "Buttons" })
	buttons.frame.AnchorPoint = Vector2.new(1, 0.5)
	buttons.frame.Position = UDim2.fromScale(1, 0.5)
	buttons.frame.Parent = footer

	local answers: any = handlers.draft
	local busy = false
	local function counts(): (number, number)
		return View.progress(payload, answers or {})
	end
	local function updateProgress()
		local done, total = counts()
		progress.setText(text("runner_answered", { n = done, total = total }))
	end

	local abandon = Kit.Button({
		text = text("runner_abandon"),
		style = "ghost",
		name = "Abandon",
		layoutOrder = 1,
		onClick = function()
			if busy then
				return
			end
			handlers.confirm({
				title = text("runner_abandon_title"),
				body = text("runner_abandon_body"),
				confirmText = text("runner_abandon"),
				danger = true,
			}, function(yes: boolean)
				if yes and not busy then
					handlers.onAbandon()
				end
			end)
		end,
	})
	abandon.frame.Parent = buttons.frame
	local submitText = if final then text("runner_final") else text("runner_submit")
	local submit: Kit.Button
	submit = Kit.Button({
		text = submitText,
		icon = if final then "🔔" else nil,
		name = "Submit",
		layoutOrder = 2,
		onClick = function()
			if busy then
				return
			end
			local done, total = counts()
			if done < total then
				handlers.confirm({
					title = text("runner_incomplete_title"),
					body = text("runner_incomplete", { left = total - done }),
					confirmText = submitText,
				}, function(yes: boolean)
					if yes and not busy then
						handlers.onSubmit(answers or {})
					end
				end)
			else
				handlers.onSubmit(answers or {})
			end
		end,
	})
	submit.frame.Parent = buttons.frame

	-- the stage payload
	local cleanup: (() -> ())? = nil
	local r = renderer(payload.kind)
	local function partError()
		Kit.Label({ text = text("runner_part_error"), color = "bad", name = "RenderError" }).frame.Parent = content
	end
	if r then
		local ok, result = pcall(r.mount, content, payload, {
			answers = handlers.draft,
			onChange = function(a: any)
				answers = a
				updateProgress()
				local onDraft = handlers.onDraft
				if onDraft then
					onDraft(a)
				end
			end,
		})
		if ok and type(result) == "function" then
			cleanup = result
		elseif not ok then
			warn("[Project] renderer failed: " .. tostring(result))
			partError()
		end
	else
		partError()
	end
	updateProgress()

	return {
		destroy = function()
			if cleanup then
				pcall(cleanup)
			end
			root:Destroy()
		end,
		setBusy = function(b: boolean)
			busy = b
			submit.setDisabled(b)
			abandon.setDisabled(b)
			submit.setText(if b then text("runner_submitting") else submitText)
		end,
		answers = function(): any
			return answers
		end,
	}
end

return Runner
