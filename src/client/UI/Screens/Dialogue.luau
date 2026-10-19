--!strict
-- Dialogue (client screen, owned by `tutorial`): an NPC conversation as a bottom sheet over the world. Shows the
-- speaker's name and title, the line (typed out unless reduced motion is on; tap it to finish) and one 44 px+
-- button per option. Every choice goes to the server (TutorialController:Choose -> "Dialogue.Choose"), which
-- validates it and answers with the next node or the end of the talk. The conversation itself lives in
-- TutorialController; this screen just renders it and closes when it ends.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

local Dialogue = { id = "Dialogue" }

local MAX_WIDTH = 760
local TYPE_RATE = 70 -- graphemes per second

local function controllerOf(ctx: any): any
	local registry = if type(ctx) == "table" then ctx.Registry else nil
	if not registry then
		return nil
	end
	local ok, c = pcall(function()
		return registry.get("TutorialController")
	end)
	return if ok then c else nil
end

local function hexColor(s: any): Color3?
	if type(s) == "string" and string.match(s, "^#%x%x%x%x%x%x$") then
		local ok, c = pcall(Color3.fromHex, s)
		if ok then
			return c
		end
	end
	return nil
end

function Dialogue.open(_args: any, root: Instance, ctx: any): { close: () -> () }
	local controller = controllerOf(ctx)
	local closed = false
	local busy = false
	local conn: any = nil
	local typing = 0
	local closeScreen = function()
		if type(ctx) == "table" and type(ctx.close) == "function" then
			ctx.close()
		end
	end

	local sheet = Kit.Panel({
		name = "Sheet",
		size = UDim2.new(1, -24, 0, 0),
		autoSize = "y",
		padding = 14,
		list = true,
		gap = 10,
	})
	sheet.frame.AnchorPoint = Vector2.new(0.5, 1)
	sheet.frame.Position = UDim2.new(0.5, 0, 1, -24)
	local maxSize = Instance.new("UISizeConstraint")
	maxSize.MaxSize = Vector2.new(MAX_WIDTH, math.huge)
	maxSize.Parent = sheet.frame
	sheet.frame.Parent = root

	-- header: name + title on the left, close on the right
	local header = Kit.frame("Header", UDim2.new(1, 0, 0, 48))
	header.LayoutOrder = 1
	header.Parent = sheet.frame
	local who = Kit.frame("Who", UDim2.new(1, -56, 1, 0))
	who.Parent = header
	Kit.list(who, false, 0)
	local nameLabel = Kit.Label({ text = "", size = "lg", font = "heading", name = "Name", layoutOrder = 1 })
	nameLabel.frame.Parent = who
	local titleLabel = Kit.Label({ text = "", size = "sm", color = "textDim", name = "Title", layoutOrder = 2 })
	titleLabel.frame.Parent = who
	local closeButton = Kit.IconButton({
		glyph = "✕",
		style = "ghost",
		name = "Close",
		onClick = function()
			closeScreen()
		end,
	})
	closeButton.frame.AnchorPoint = Vector2.new(1, 0)
	closeButton.frame.Position = UDim2.fromScale(1, 0)
	closeButton.frame.Parent = header

	-- the line itself (a button so a tap finishes the typing)
	local lineHolder = Instance.new("TextButton")
	lineHolder.Name = "LineHolder"
	lineHolder.Text = ""
	lineHolder.AutoButtonColor = false
	lineHolder.BackgroundTransparency = 1
	lineHolder.Size = UDim2.new(1, 0, 0, 0)
	lineHolder.AutomaticSize = Enum.AutomaticSize.Y
	lineHolder.LayoutOrder = 2
	lineHolder.Parent = sheet.frame
	local line = Kit.Label({ text = "", size = "md", name = "Line" })
	line.frame.Parent = lineHolder

	local optionsFrame = Kit.frame("Options", UDim2.new(1, 0, 0, 0))
	optionsFrame.AutomaticSize = Enum.AutomaticSize.Y
	optionsFrame.LayoutOrder = 3
	optionsFrame.Parent = sheet.frame
	Kit.list(optionsFrame, false, 8)

	local buttons: { Kit.Button } = {}

	local function finishTyping()
		typing += 1
		line.frame.MaxVisibleGraphemes = -1
	end
	Kit.connect(lineHolder, "Activated", finishTyping)

	local function typeOut(s: string)
		typing += 1
		local mine = typing
		if Kit.reducedMotion() then
			line.frame.MaxVisibleGraphemes = -1
			return
		end
		local total = utf8.len(s) or #s
		line.frame.MaxVisibleGraphemes = 0
		task.spawn(function()
			local shown = 0
			local elapsed = 0
			while not closed and typing == mine and shown < total do
				elapsed += task.wait()
				shown = math.min(total, math.floor(elapsed * TYPE_RATE))
				line.frame.MaxVisibleGraphemes = shown
			end
			if typing == mine then
				line.frame.MaxVisibleGraphemes = -1
			end
		end)
	end

	local render: (p: { [string]: any }) -> ()

	local function choose(optionId: string)
		if busy or closed or not controller then
			return
		end
		busy = true
		for _, b in buttons do
			b.setDisabled(true)
		end
		task.spawn(function()
			local ok, result = pcall(function()
				return controller:Choose(optionId)
			end)
			busy = false
			if closed then
				return
			end
			if not ok or type(result) ~= "table" or result.closed == true then
				closeScreen()
				return
			end
			render(result)
		end)
	end

	render = function(p: { [string]: any })
		if closed then
			return
		end
		nameLabel.setText(if type(p.name) == "string" then p.name else "")
		titleLabel.setText(if type(p.title) == "string" then p.title else "")
		titleLabel.frame.Visible = type(p.title) == "string" and p.title ~= ""
		local tint = hexColor(p.color)
		if tint then
			nameLabel.setColor(tint)
		else
			nameLabel.setColor("accent")
		end
		local s = if type(p.text) == "string" then p.text else ""
		line.setText(s)
		typeOut(s)
		Kit.clear(optionsFrame)
		table.clear(buttons)
		local options = if type(p.options) == "table" then p.options else {}
		for i, o in options do
			if type(o) == "table" and type(o.id) == "string" then
				local optionId = o.id
				local b = Kit.Button({
					text = if type(o.text) == "string" then o.text else Quests.text("dialogue_continue"),
					style = if o.exit == true then "ghost" else "secondary",
					fill = true,
					name = "Option_" .. optionId,
					layoutOrder = i,
					onClick = function()
						choose(optionId)
					end,
				})
				b.label.TextWrapped = true
				b.label.TextXAlignment = Enum.TextXAlignment.Left
				b.frame.Parent = optionsFrame
				table.insert(buttons, b)
			end
		end
		if #buttons == 0 then
			local bye = Kit.Button({
				text = Quests.text("dialogue_bye"),
				style = "ghost",
				fill = true,
				name = "Option_bye",
				onClick = closeScreen,
			})
			bye.frame.Parent = optionsFrame
		end
	end

	local current = if controller then controller:GetDialogue() else nil
	if type(current) == "table" then
		render(current)
	else
		task.defer(closeScreen) -- nothing to show (e.g. reopened from history after the talk ended)
	end

	if controller and type(controller.DialogueChanged) == "table" then
		conn = controller.DialogueChanged:Connect(function(p: any)
			if closed then
				return
			end
			if type(p) ~= "table" then
				closeScreen()
			elseif not busy then
				render(p)
			end
		end)
	end

	return {
		close = function()
			if closed then
				return
			end
			closed = true
			typing += 1
			if conn then
				conn:Disconnect()
				conn = nil
			end
			if controller and controller:GetDialogue() ~= nil then
				controller:EndDialogue()
			end
			sheet.frame:Destroy()
		end,
	}
end

return Dialogue
