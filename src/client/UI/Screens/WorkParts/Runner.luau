--!strict
-- Work screen, task runner (owned by `work`): the timer bar, how-it-works and hints, the payload drawn by its
-- UI/WorkKinds renderer, and the Submit / Abandon footer with answer progress.
--
--   Runner.build(parent, active, handlers) -> { destroy, setBusy(busy), answers() -> any }
--   active   = WorkService's active view { instanceId, title, kind, payload, endsAt, limit, grace, how, desk }
--   handlers = { onSubmit: (answers) -> (), onAbandon: () -> (), confirm: (opts, cb) -> (), now: () -> number,
--                draft: any?, onDraft: (answers) -> ()? }

local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Tasks"))
local View = require(script.Parent:WaitForChild("View"))
local WorkKinds = script.Parent.Parent.Parent:WaitForChild("WorkKinds")

local Runner = {}

local TOP = 52
local FOOTER = Kit.TAP + 12

local function renderer(kind: any): any
	if type(kind) ~= "string" then
		return nil
	end
	local module = WorkKinds:FindFirstChild(kind)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, r = pcall(require, module)
	if ok and type(r) == "table" and type(r.mount) == "function" then
		return r
	end
	warn("[Work] renderer " .. kind .. " failed to load: " .. tostring(r))
	return nil
end

function Runner.build(parent: Instance, active: any, handlers: { [string]: any }): { [string]: any }
	local now: () -> number = handlers.now
	local payload = if type(active.payload) == "table" then active.payload else {}
	local root = Kit.frame("Runner")
	root.Parent = parent

	-- top bar: title + timer
	local top = Kit.frame("TopBar", UDim2.new(1, 0, 0, TOP))
	top.Parent = root
	local title = Kit.Label({
		text = tostring(active.title or payload.title or ""),
		font = "bodyBold",
		size = "lg",
		wrap = false,
		autoSize = "none",
		width = UDim.new(1, -110),
		height = TOP,
		name = "Title",
	})
	title.frame.TextTruncate = Enum.TextTruncate.AtEnd
	title.frame.Parent = top
	local timer = Kit.Label({
		text = "",
		font = "mono",
		size = "xl",
		align = "right",
		autoSize = "none",
		width = UDim.new(0, 106),
		height = TOP,
		name = "Timer",
	})
	timer.frame.AnchorPoint = Vector2.new(1, 0)
	timer.frame.Position = UDim2.fromScale(1, 0)
	timer.frame.Parent = top

	-- body
	local scroll = Kit.Scroll({ gap = 10, padding = 4, name = "RunnerScroll" })
	scroll.frame.Position = UDim2.fromOffset(0, TOP)
	scroll.frame.Size = UDim2.new(1, 0, 1, -(TOP + FOOTER))
	scroll.frame.Parent = root
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	if type(active.how) == "string" and active.how ~= "" then
		Kit.Label({ text = active.how, size = "sm", color = "textDim", name = "How", layoutOrder = nextOrder() }).frame.Parent =
			scroll.content
	end
	if active.desk == true then
		Kit.Badge({
			text = Config.text("runner_desk", { pct = math.floor((Config.rewards.deskBonus - 1) * 100 + 0.5) }),
			color = "good",
			layoutOrder = nextOrder(),
		}).frame.Parent =
			scroll.content
	end
	local lateNote = Kit.Label({
		text = Config.text("runner_late_warn"),
		size = "sm",
		color = "warn",
		name = "LateNote",
		layoutOrder = nextOrder(),
	})
	lateNote.frame.Visible = false
	lateNote.frame.Parent = scroll.content
	local hints = if type(payload.hints) == "table" then payload.hints else {}
	if #hints > 0 then
		local panel =
			Kit.Panel({ color = "surface", list = true, gap = 4, name = "Hints", layoutOrder = nextOrder() + 1 })
		panel.frame.Visible = false
		for i, h in hints do
			Kit.Label({ text = "💡 " .. tostring(h), size = "sm", layoutOrder = i }).frame.Parent = panel.frame
		end
		local toggle: Kit.Button
		toggle = Kit.Button({
			text = Config.text("runner_hints_show", { n = #hints }),
			style = "ghost",
			name = "HintsToggle",
			layoutOrder = order,
			onClick = function()
				panel.frame.Visible = not panel.frame.Visible
				toggle.setText(
					if panel.frame.Visible
						then Config.text("runner_hints_hide")
						else Config.text("runner_hints_show", { n = #hints })
				)
			end,
		})
		toggle.frame.Parent = scroll.content
		order += 1
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
		width = UDim.new(0.34, 0),
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
		progress.setText(Config.text("runner_answered", { n = done, total = total }))
	end

	local abandon = Kit.Button({
		text = Config.text("runner_abandon"),
		style = "ghost",
		name = "Abandon",
		layoutOrder = 1,
		onClick = function()
			if busy then
				return
			end
			handlers.confirm({
				title = Config.text("runner_abandon_title"),
				body = Config.text("runner_abandon_body"),
				confirmText = Config.text("runner_abandon"),
				danger = true,
			}, function(yes: boolean)
				if yes then
					handlers.onAbandon()
				end
			end)
		end,
	})
	abandon.frame.Parent = buttons.frame
	local submit: Kit.Button
	submit = Kit.Button({
		text = Config.text("runner_submit"),
		name = "Submit",
		layoutOrder = 2,
		onClick = function()
			if busy then
				return
			end
			local done, total = counts()
			if done < total then
				handlers.confirm({
					title = Config.text("runner_incomplete_title"),
					body = Config.text("runner_incomplete", { left = total - done }),
					confirmText = Config.text("runner_submit"),
				}, function(yes: boolean)
					if yes then
						handlers.onSubmit(answers or {})
					end
				end)
			else
				handlers.onSubmit(answers or {})
			end
		end,
	})
	submit.frame.Parent = buttons.frame

	-- the payload
	local cleanup: (() -> ())? = nil
	local r = renderer(payload.kind)
	if r then
		local ok, result = pcall(r.mount, content, payload, {
			answers = handlers.draft,
			onChange = function(a: any)
				answers = a
				updateProgress()
				if handlers.onDraft then
					handlers.onDraft(a)
				end
			end,
		})
		if ok and type(result) == "function" then
			cleanup = result
		elseif not ok then
			warn("[Work] renderer failed: " .. tostring(result))
			Kit.Label({ text = Config.text("runner_part_error"), color = "bad", name = "RenderError" }).frame.Parent =
				content
		end
	else
		Kit.Label({ text = Config.text("runner_part_error"), color = "bad", name = "RenderError" }).frame.Parent =
			content
	end
	updateProgress()

	local endsAt = if type(active.endsAt) == "number" then active.endsAt else now() + 180
	local function tick()
		local text, overtime = View.timer(endsAt, now())
		timer.setText(text)
		timer.setColor(if overtime then "bad" elseif endsAt - now() <= 30 then "warn" else "text")
		lateNote.frame.Visible = overtime
	end
	tick()
	local stopTick = Kit.everySecond(tick)

	return {
		destroy = function()
			stopTick()
			if cleanup then
				pcall(cleanup)
			end
			root:Destroy()
		end,
		setBusy = function(b: boolean)
			busy = b
			submit.setDisabled(b)
			abandon.setDisabled(b)
			submit.setText(if b then Config.text("runner_submitting") else Config.text("runner_submit"))
		end,
		answers = function(): any
			return answers
		end,
	}
end

return Runner
