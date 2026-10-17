--!strict
-- ReviewMeeting (client screen, owned by `careerPath`; design v3 §6): the weekly boss review as a short cutscene.
--   office mode   the camera eases to frame the boss at the boss_chair, letterbox bars slide in, the boss's lines
--                 type out, the breakdown card shows the four components, then the outcome is revealed
--   phone mode    an incoming call card first ("Answer"), then the same meeting with a portrait panel
--   discipline    a major risk violation or a mass firing: lines and the outcome, no breakdown
-- The server already applied the result; this screen only plays it (closing early loses nothing).
--   args = { payload = Career.Meeting payload, hideHud = true }

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tracks = require(Shared.Config.Tracks)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Parts = script.Parent:WaitForChild("CareerParts")
local Common = require(Parts:WaitForChild("Common"))
local Cinematic = require(Parts:WaitForChild("Cinematic"))
local Breakdown = require(Parts:WaitForChild("Breakdown"))

local ReviewMeeting = { id = "ReviewMeeting", hideHud = true }

local TYPE_RATE = 45 -- characters per second
local READ_BASE = 2.2
local READ_PER_CHAR = 0.035
local RING_TIMEOUT = 25
local BAR_HEIGHT = 0.1

local function initials(name: string): string
	local out = ""
	for word in string.gmatch(name, "%S+") do
		out ..= string.upper(string.sub(word, 1, 1))
		if #out >= 2 then
			break
		end
	end
	return if out ~= "" then out else "?"
end

function ReviewMeeting.open(args: any, root: Instance, ctx: any): { close: () -> () }
	local payload = if type(args) == "table" and type(args.payload) == "table" then args.payload else nil
	local controller = Common.controller(ctx)
	if not payload or type(payload.lines) ~= "table" then
		task.defer(ctx.close)
		return {
			close = function()
				if controller then
					controller:MeetingClosed()
				end
			end,
		}
	end
	local closed = false
	local tapped = false
	local cine: Cinematic.Handle? = nil
	local reduced = Kit.reducedMotion()
	local sfx = ctx.Sfx
	local function play(name: string)
		if sfx then
			pcall(sfx.play, name)
		end
	end

	local company = if type(payload.company) == "table" then payload.company else {}
	local bossName = if type(payload.boss) == "table" and type(payload.boss.name) == "string"
		then payload.boss.name
		else ""
	local primary = if typeof(company.primary) == "Color3" then company.primary else Color3.fromRGB(11, 31, 58)
	local accent = if typeof(company.accent) == "Color3" then company.accent else Color3.fromRGB(201, 165, 76)

	-- full-screen layer: tap anywhere to advance
	local layer = Kit.frame("Meeting")
	layer.Parent = root
	local catcher = Instance.new("TextButton")
	catcher.Name = "TapCatcher"
	catcher.Text = ""
	catcher.AutoButtonColor = false
	catcher.BackgroundTransparency = 1
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.ZIndex = 1
	catcher.Parent = layer
	Kit.connect(catcher, "Activated", function()
		tapped = true
	end)

	-- letterbox bars
	local function bar(name: string, top: boolean): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		f.Position = UDim2.fromScale(0, if top then 0 else 1)
		f.Size = UDim2.fromScale(1, 0)
		f.ZIndex = 2
		f.Parent = layer
		return f
	end
	local topBar = bar("TopBar", true)
	local bottomBar = bar("BottomBar", false)

	-- dialogue box
	local box = Instance.new("Frame")
	box.Name = "Dialogue"
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1 - BAR_HEIGHT, -10)
	box.Size = UDim2.new(1, -24, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.BorderSizePixel = 0
	box.ZIndex = 4
	box.Visible = false
	box.Parent = layer
	local boxLimit = Instance.new("UISizeConstraint")
	boxLimit.MaxSize = Vector2.new(760, math.huge)
	boxLimit.MinSize = Vector2.new(0, 110)
	boxLimit.Parent = box
	local boxCorner = Kit.corner(box)
	local boxStroke = Kit.stroke(box)
	Kit.padding(box, 14)
	Kit.themed(box, function(t)
		box.BackgroundColor3 = t.colors.panel
		box.BackgroundTransparency = 0.06
		boxCorner.CornerRadius = UDim.new(0, t.radius)
		boxStroke.Color = accent
		boxStroke.Thickness = t.stroke + 1
	end)

	local portrait = Instance.new("Frame")
	portrait.Name = "Portrait"
	portrait.Size = UDim2.fromOffset(64, 64)
	portrait.BackgroundColor3 = primary
	portrait.BorderSizePixel = 0
	portrait.ZIndex = 5
	portrait.Visible = false
	Kit.corner(portrait, 32)
	local portraitStroke = Kit.stroke(portrait)
	portraitStroke.Color = accent
	portraitStroke.Thickness = 2
	local portraitText = Instance.new("TextLabel")
	portraitText.BackgroundTransparency = 1
	portraitText.Size = UDim2.fromScale(1, 1)
	portraitText.Text = initials(bossName)
	portraitText.TextColor3 = accent
	portraitText.TextScaled = true
	portraitText.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	portraitText.ZIndex = 6
	portraitText.Parent = portrait
	local portraitPad = Instance.new("UIPadding")
	portraitPad.PaddingTop = UDim.new(0, 14)
	portraitPad.PaddingBottom = UDim.new(0, 14)
	portraitPad.Parent = portraitText
	portrait.Parent = box

	local textArea = Kit.frame("Text", UDim2.new(1, 0, 0, 0))
	textArea.AutomaticSize = Enum.AutomaticSize.Y
	textArea.ZIndex = 5
	Kit.list(textArea, false, 4)
	textArea.Parent = box
	local speaker = Kit.Label({ text = bossName, size = "sm", font = "bodyBold", color = "accent", layoutOrder = 1 })
	speaker.frame.ZIndex = 6
	speaker.frame.Parent = textArea
	local line = Kit.Label({ text = "", size = "lg", layoutOrder = 2 })
	line.frame.ZIndex = 6
	line.frame.Parent = textArea
	local hint = Kit.Label({
		text = Tracks.text("meeting_skip"),
		size = "xs",
		color = "textDim",
		align = "right",
		layoutOrder = 3,
	})
	hint.frame.ZIndex = 6
	hint.frame.Parent = textArea

	local function usePortrait(on: boolean)
		portrait.Visible = on
		textArea.Size = if on then UDim2.new(1, -76, 0, 0) else UDim2.new(1, 0, 0, 0)
		textArea.Position = if on then UDim2.fromOffset(76, 0) else UDim2.fromOffset(0, 0)
	end

	local function waitTap(timeout: number?): boolean
		tapped = false
		local started = os.clock()
		while not closed and not tapped do
			if timeout and os.clock() - started >= timeout then
				return false
			end
			task.wait(0.03)
		end
		tapped = false
		return not closed
	end

	local function say(text: string)
		if closed then
			return
		end
		line.setText(text)
		local label = line.frame
		local total = utf8.len(text) or #text
		play("type")
		if reduced then
			label.MaxVisibleGraphemes = -1
		else
			label.MaxVisibleGraphemes = 0
			tapped = false
			local shown = 0
			local last = os.clock()
			while not closed and shown < total do
				if tapped then
					break
				end
				task.wait(1 / 60)
				local now = os.clock()
				shown = math.min(total, shown + (now - last) * TYPE_RATE)
				last = now
				label.MaxVisibleGraphemes = math.floor(shown)
			end
			label.MaxVisibleGraphemes = -1
		end
		waitTap(READ_BASE + total * READ_PER_CHAR)
	end

	local function letterbox(show: boolean)
		local size = if show then UDim2.fromScale(1, BAR_HEIGHT) else UDim2.fromScale(1, 0)
		Kit.tween(topBar, 0.45, { Size = size })
		Kit.tween(bottomBar, 0.45, { Size = size })
	end

	-- phone mode: ring until answered
	local function ring(): boolean
		local card = Instance.new("Frame")
		card.Name = "IncomingCall"
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.45)
		card.Size = UDim2.fromOffset(300, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.BorderSizePixel = 0
		card.ZIndex = 8
		Kit.corner(card, 18)
		local stroke = Kit.stroke(card)
		Kit.padding(card, 18)
		Kit.list(card, false, 10).HorizontalAlignment = Enum.HorizontalAlignment.Center
		Kit.themed(card, function(t)
			card.BackgroundColor3 = t.colors.panel
			stroke.Color = t.colors.border
		end)
		card.Parent = layer
		local function child(inst: GuiObject, order: number)
			inst.LayoutOrder = order
			inst.ZIndex = 9
			inst.Parent = card
		end
		child(
			Kit.Label({ text = Tracks.text("meeting_phone"), size = "sm", color = "textDim", align = "center" }).frame,
			1
		)
		local avatar = portrait:Clone()
		avatar.Visible = true
		avatar.Size = UDim2.fromOffset(84, 84)
		child(avatar, 2)
		child(Kit.Label({ text = bossName, size = "lg", font = "heading", align = "center" }).frame, 3)
		child(
			Kit.Label({
				text = Tracks.text(
					"meeting_phone_from",
					{ boss = Tracks.text("meeting_boss_title"), company = company.name or "" }
				),
				size = "xs",
				color = "textDim",
				align = "center",
			}).frame,
			4
		)
		local answered = false
		local answer = Kit.Button({
			text = Tracks.text("meeting_answer"),
			icon = "📞",
			size = UDim2.fromOffset(200, 56),
			onClick = function()
				answered = true
			end,
		})
		child(answer.frame, 5)
		local started = os.clock()
		local lastRing = -math.huge
		while not closed and not answered and os.clock() - started < RING_TIMEOUT do
			if os.clock() - lastRing >= 1.4 then
				lastRing = os.clock()
				play("notify")
			end
			task.wait(0.05)
		end
		card:Destroy()
		return not closed
	end

	local function finish()
		if not closed then
			ctx.close()
		end
	end

	local function run()
		local mode = payload.mode
		if mode == "phone" then
			if not ring() then
				return
			end
		end
		local handle = Cinematic.start(if mode == "office" then payload.camera else nil, reduced)
		cine = handle
		if closed then
			-- closed while the call was ringing or the camera was starting: restore at once
			handle.stop()
			return
		end
		usePortrait(not handle.framed)
		letterbox(true)
		task.wait(if reduced then 0.1 else 0.9)
		if closed then
			return
		end
		box.Visible = true
		local lines = payload.lines :: { any }
		local outcomeAt = if type(payload.outcomeAt) == "number" then payload.outcomeAt else #lines
		for i = 1, math.min(outcomeAt - 1, #lines) do
			if type(lines[i]) == "string" then
				say(lines[i])
			end
		end
		if payload.breakdown and not closed then
			box.Visible = false
			local card = Breakdown.card(layer, payload)
			play("chime")
			waitTap(nil)
			card:Destroy()
			box.Visible = true
		end
		for i = math.max(1, outcomeAt), #lines do
			if type(lines[i]) == "string" then
				say(lines[i])
			end
		end
		if closed then
			return
		end
		box.Visible = false
		local _, sound = Breakdown.reveal(layer, payload, finish)
		play(sound)
	end

	task.spawn(function()
		local ok, err = pcall(function()
			run()
		end)
		if not ok then
			warn("[ReviewMeeting] " .. tostring(err))
			finish()
		end
	end)

	return {
		close = function()
			if closed then
				return
			end
			closed = true
			local handle = cine
			if handle then
				handle.stop()
			end
			layer:Destroy()
			if controller then
				controller:MeetingClosed()
			end
		end,
	}
end

return ReviewMeeting
