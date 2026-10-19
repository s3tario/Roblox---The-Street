--!strict
-- TutorialController (client, owned by `tutorial`): the client side of the onboarding chain, NPC conversations,
-- the Quests app and the Recruiting Board.
--   * the quest waypoint: "Quest.Waypoint"(position?, label?) draws a local marker (BillboardGui arrow + label +
--     distance) and a Beam from the character, re-attached after every respawn. Hidden while a weekly review is due
--     (CareerController draws the way to the boss then). Streaming-safe: the marker is a local part at a position.
--   * conversations: "Dialogue.Node" opens / updates / closes the Dialogue screen; choices go back through
--     "Dialogue.Choose"; "Dialogue.OpenScreen" opens a screen a conversation asked for.
--   * "Recruiting.Open" opens the Recruiting screen; "Tutorial.Info" shows the weekly-review explainer;
--     "Tutorial.Skippable" badges the Quests tab when a skip is on offer.
--   * hides EmployeesOnly Talk prompts (the boss) for visitors; the server refuses them either way.
--   * registers the "Quests" menu tab.
--
-- API (used by the tutorial screens):
--   TutorialController:GetDialogue() -> payload?        TutorialController:Choose(optionId) -> payload (yields)
--   TutorialController:EndDialogue()                    TutorialController.DialogueChanged : Signal(payload?)
--   TutorialController:GetQuestView() -> view?          TutorialController:Skip() -> (ok, errKey?)
--   TutorialController:Ack(infoId)                      TutorialController:ShowInfo(info)
--   TutorialController:Recruiting(action, companyId?) -> (ok, errKey?, board?, result?)
--       action "Board" | "Apply" | "Start" | "Retry" | "Decide"
--   TutorialController:GetWaypoint() -> (Vector3?, label?)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Quests = require(Shared.Config.Quests)
local CareerState = require(Shared.Logic.CareerState)
local Registry = require(script.Parent.Parent.Registry)
local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))

local TutorialController = {
	Name = "TutorialController",
	Priority = 50,
	DialogueChanged = Signal.new(), -- (payload?)
}

local MENU_ID = "quests"
local DIALOGUE_SCREEN = "Dialogue"
local RECRUITING_SCREEN = "Recruiting"
local PROMPT_NAME = "TalkPrompt"
local PROMPT_TAG = "TalkPrompt"
local INTERACT_ID = "npc"
local MARKER_UPDATE = 0.25

local function ui(): any
	return Registry.get("UIController")
end

local function store(): any
	return Registry.get("Store")
end

local function storeGet(key: string): any
	local s = store()
	if not s then
		return nil
	end
	local ok, v = pcall(function()
		return s:Get(key)
	end)
	return if ok then v else nil
end

local function text(key: string, vars: { [string]: any }?): string
	return Quests.text(key, vars)
end

---------------------------------------------------------------------------------------------------
-- Conversations
---------------------------------------------------------------------------------------------------
local dialogue: { [string]: any }? = nil
local choosing = false

function TutorialController:GetDialogue(): { [string]: any }?
	return dialogue
end

local function setDialogue(p: { [string]: any }?)
	dialogue = p
	TutorialController.DialogueChanged:Fire(p)
end

local function onNode(p: any)
	if type(p) ~= "table" then
		return
	end
	if p.closed == true then
		if dialogue and (p.token == nil or dialogue.token == p.token) then
			local reason = p.reason
			setDialogue(nil)
			if reason == "far" then
				local u = ui()
				if u then
					u:Notify(text("dialogue_far"), "info")
				end
			end
		end
		return
	end
	if type(p.token) ~= "string" or type(p.options) ~= "table" then
		return
	end
	setDialogue(p)
	local u = ui()
	if u and u:Current() ~= DIALOGUE_SCREEN then
		u:Open(DIALOGUE_SCREEN, {})
	end
end

function TutorialController:Choose(optionId: string): { [string]: any }
	local current = dialogue
	if not current then
		return { closed = true, reason = "gone" }
	end
	if choosing then
		return current
	end
	choosing = true
	local ok, result = pcall(Net.invoke, "Dialogue.Choose", current.token, optionId)
	choosing = false
	if dialogue ~= current then
		-- the server pushed a new conversation (or closed this one) while we waited
		return dialogue or { closed = true, reason = "gone" }
	end
	if not ok or type(result) ~= "table" then
		setDialogue(nil)
		return { closed = true, reason = "error" }
	end
	if result.closed == true then
		setDialogue(nil)
		return result
	end
	setDialogue(result)
	return result
end

function TutorialController:EndDialogue()
	local current = dialogue
	if current then
		setDialogue(nil)
		Net.send("Dialogue.Close", current.token)
	end
end

---------------------------------------------------------------------------------------------------
-- Quests and recruiting
---------------------------------------------------------------------------------------------------
function TutorialController:GetQuestView(): { [string]: any }?
	local ok, view = pcall(Net.invoke, "Quest.Get")
	if ok and type(view) == "table" then
		return view
	end
	return nil
end

function TutorialController:Skip(): (boolean, string?)
	local ok, a, b = pcall(Net.invoke, "Quest.Skip")
	if not ok then
		return false, "skip_none"
	end
	if a == true then
		local u = ui()
		if u then
			pcall(u.SetMenuBadge, u, MENU_ID, nil)
		end
		return true, nil
	end
	return false, if type(b) == "string" then b else "skip_none"
end

function TutorialController:Ack(infoId: string)
	Net.send("Quest.Ack", infoId)
end

local VALID_ACTIONS = { Board = true, Apply = true, Start = true, Retry = true, Decide = true }

function TutorialController:Recruiting(action: string, companyId: string?): (boolean, string?, any, any)
	if not VALID_ACTIONS[action] then
		return false, "generic", nil, nil
	end
	if action == "Board" then
		local ok, board = pcall(Net.invoke, "Recruiting.Board")
		if ok and type(board) == "table" then
			return true, nil, board, nil
		end
		return false, "generic", nil, nil
	end
	local ok, a, b, c, d = pcall(Net.invoke, "Recruiting." .. action, companyId)
	if not ok then
		return false, "generic", nil, nil
	end
	if a == nil and (b == "timeout" or b == "rate_limited" or b == "error" or b == "missing") then
		return false, if b == "rate_limited" then "busy" else "generic", nil, nil
	end
	return a == true, if type(b) == "string" then b else nil, if type(c) == "table" then c else nil, d
end

---------------------------------------------------------------------------------------------------
-- The weekly-review explainer
---------------------------------------------------------------------------------------------------
local infoOpen = false

function TutorialController:ShowInfo(info: any)
	if infoOpen or type(info) ~= "table" then
		return
	end
	local lines = if type(info.lines) == "table" then info.lines else Quests.reviewIntro.lines
	local id = if type(info.id) == "string" then info.id else "review_intro"
	infoOpen = true
	local ok, err = pcall(Kit.modal, { width = 520, dismissable = true, name = "TutorialInfo" }, function(card, close)
		Kit.list(card, false, 10)
		local title = Kit.Heading({
			text = if type(info.title) == "string" then info.title else Quests.reviewIntro.title,
			level = 2,
			layoutOrder = 1,
		})
		title.frame.Parent = card
		for i, line in lines do
			if type(line) == "string" then
				local l = Kit.Label({ text = line, size = "md", layoutOrder = 1 + i, name = "Line" .. i })
				l.frame.Parent = card
			end
		end
		local button = Kit.Button({
			text = text("quests_got_it"),
			fill = true,
			layoutOrder = 100,
			name = "GotIt",
			onClick = function()
				TutorialController:Ack(id)
				close()
			end,
		})
		button.frame.Parent = card
		card.Destroying:Connect(function()
			infoOpen = false
		end)
	end)
	if not ok then
		infoOpen = false
		warn("[TutorialController] info modal failed: " .. tostring(err))
	end
end

---------------------------------------------------------------------------------------------------
-- Waypoint
---------------------------------------------------------------------------------------------------
local target: Vector3? = nil
local targetLabel: string? = nil
local marker: Part? = nil
local markerLabel: TextLabel? = nil
local markerDistance: TextLabel? = nil
local beam: Beam? = nil
local lastMarkerUpdate = 0

function TutorialController:GetWaypoint(): (Vector3?, string?)
	return target, targetLabel
end

local function suppressed(): boolean
	local career = storeGet("career")
	return type(career) == "table" and career.reviewDue == true and CareerState.isEmployed(career)
end

local function clearMarker()
	if marker then
		marker:Destroy()
	end
	marker, markerLabel, markerDistance, beam = nil, nil, nil, nil
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local from = if root then root:FindFirstChild("QuestWaypointFrom") else nil
	if from then
		from:Destroy()
	end
end

local function ensureMarker(): Part
	local existing = marker
	if existing and existing.Parent then
		return existing
	end
	local accent = Kit.Theme.get().colors.accent
	local part = Instance.new("Part")
	part.Name = "QuestWaypoint"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	local attach = Instance.new("Attachment")
	attach.Name = "Target"
	attach.Parent = part
	local gui = Instance.new("BillboardGui")
	gui.Name = "Marker"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(200, 66)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = math.huge
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	label.Size = UDim2.new(1, 0, 0, 26)
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 15
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1.5
	stroke.Parent = label
	local distance = Instance.new("TextLabel")
	distance.Name = "Distance"
	distance.BackgroundTransparency = 1
	distance.Size = UDim2.new(1, 0, 0, 16)
	distance.Position = UDim2.fromOffset(0, 27)
	distance.Text = ""
	distance.TextColor3 = Color3.fromRGB(242, 230, 200)
	distance.TextStrokeTransparency = 0.4
	distance.TextSize = 13
	distance.FontFace = Font.fromEnum(Enum.Font.RobotoMono)
	distance.Parent = gui
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.new(1, 0, 0, 22)
	arrow.Position = UDim2.new(0, 0, 1, -22)
	arrow.Text = "▼"
	arrow.TextScaled = true
	arrow.TextColor3 = accent
	arrow.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	arrow.Parent = gui
	part.Parent = workspace
	marker = part
	markerLabel = label
	markerDistance = distance
	return part
end

local function attachBeam(part: Part)
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	local from = root:FindFirstChild("QuestWaypointFrom")
	if not from then
		local a = Instance.new("Attachment")
		a.Name = "QuestWaypointFrom"
		a.Position = Vector3.new(0, -2.5, 0)
		a.Parent = root
		from = a
	end
	local b = beam
	if b and b.Parent and b.Attachment0 == from then
		return
	end
	if b then
		b:Destroy()
	end
	local nb = Instance.new("Beam")
	nb.Name = "QuestWaypointBeam"
	nb.Attachment0 = from :: Attachment
	nb.Attachment1 = part:FindFirstChild("Target") :: Attachment
	nb.FaceCamera = true
	nb.Width0 = 0.3
	nb.Width1 = 0.3
	nb.Segments = 1
	nb.LightInfluence = 0
	nb.Color = ColorSequence.new(Kit.Theme.get().colors.accent)
	nb.Transparency = NumberSequence.new(0.4)
	nb.Parent = part
	beam = nb
end

local function refreshMarker()
	local pos = target
	if pos == nil or suppressed() then
		clearMarker()
		return
	end
	local part = ensureMarker()
	if (part.Position - pos).Magnitude > 0.1 then
		part.Position = pos
	end
	local label = markerLabel
	if label then
		label.Text = targetLabel or ""
		label.Visible = (targetLabel or "") ~= ""
	end
	attachBeam(part)
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local dist = markerDistance
	if dist and root and root:IsA("BasePart") then
		local d = (root.Position - pos).Magnitude
		dist.Text = if d < 12 then text("quests_waypoint") else string.format("%d m", math.floor(d * 0.28 + 0.5))
	end
end

local function setWaypoint(pos: any, label: any)
	target = if typeof(pos) == "Vector3" then pos else nil
	targetLabel = if type(label) == "string" then label else nil
	refreshMarker()
end

---------------------------------------------------------------------------------------------------
-- EmployeesOnly Talk prompts (visitors don't see the boss's prompt)
---------------------------------------------------------------------------------------------------
local prompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function mayUse(companyId: any): boolean
	if type(companyId) ~= "string" or companyId == "" then
		return true
	end
	local career = storeGet("career")
	if type(career) ~= "table" or not CareerState.isEmployed(career) then
		return false
	end
	if career.companyId == companyId then
		return true
	end
	local s = store()
	local events = nil
	if s then
		local ok, v = pcall(function()
			return s:GetGlobal("events")
		end)
		events = if ok then v else nil
	end
	local corporate = if type(events) == "table" then events.corporate else nil
	if type(corporate) == "table" and corporate.id == "merger_mania" and type(corporate.data) == "table" then
		local seen: { [string]: boolean } = {}
		local function scan(v: any, depth: number)
			if type(v) == "string" then
				seen[v] = true
			elseif type(v) == "table" and depth < 3 then
				for _, x in v do
					scan(x, depth + 1)
				end
			end
		end
		scan(corporate.data, 0)
		return seen[career.companyId] == true and seen[companyId] == true
	end
	return false
end

local function evaluate(prompt: ProximityPrompt)
	if prompt:GetAttribute("EmployeesOnly") ~= true then
		return
	end
	local allowed = mayUse(prompt:GetAttribute("CompanyId"))
	if prompt.Enabled ~= allowed then
		prompt.Enabled = allowed
	end
end

local function track(inst: Instance)
	if not inst:IsA("ProximityPrompt") or prompts[inst] then
		return
	end
	if inst:GetAttribute("InteractId") ~= INTERACT_ID and inst.Name ~= PROMPT_NAME then
		return
	end
	prompts[inst] = true
	inst:GetAttributeChangedSignal("EmployeesOnly"):Connect(function()
		evaluate(inst)
	end)
	inst:GetAttributeChangedSignal("CompanyId"):Connect(function()
		evaluate(inst)
	end)
	evaluate(inst)
end

local function evaluateAll()
	for prompt in prompts do
		if prompt.Parent then
			evaluate(prompt)
		end
	end
end

local function watchPrompts()
	-- NpcService tags every Talk prompt; tagged prompts replicate (and stream) with their NPC models
	CollectionService:GetInstanceAddedSignal(PROMPT_TAG):Connect(track)
	for _, inst in CollectionService:GetTagged(PROMPT_TAG) do
		track(inst)
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function TutorialController:Init() end

function TutorialController:Start()
	local u = ui()
	if u and type(u.RegisterMenuTab) == "function" then
		u:RegisterMenuTab({
			id = MENU_ID,
			title = text("quests_menu"),
			glyph = "🎯",
			order = 12,
			screen = "Quests",
		})
	end
	Net.listen("Quest.Waypoint", setWaypoint)
	Net.listen("Dialogue.Node", onNode)
	Net.listen("Dialogue.OpenScreen", function(screenId: any, args: any)
		local ctrl = ui()
		if ctrl and type(screenId) == "string" then
			ctrl:Open(screenId, if type(args) == "table" then args else {})
		end
	end)
	Net.listen("Recruiting.Open", function()
		local ctrl = ui()
		if ctrl then
			ctrl:Open(RECRUITING_SCREEN, {})
		end
	end)
	Net.listen("Tutorial.Info", function(info: any)
		TutorialController:ShowInfo(info)
	end)
	Net.listen("Tutorial.Skippable", function(_stepId: any)
		local ctrl = ui()
		if ctrl and type(ctrl.SetMenuBadge) == "function" then
			pcall(ctrl.SetMenuBadge, ctrl, MENU_ID, "!")
		end
	end)

	local s = store()
	if s then
		pcall(function()
			s:Changed("career"):Connect(function()
				evaluateAll()
				refreshMarker()
			end)
			s:GlobalChanged("events"):Connect(evaluateAll)
		end)
	end
	Players.LocalPlayer.CharacterAdded:Connect(function()
		beam = nil
		task.defer(refreshMarker)
	end)
	watchPrompts()

	-- the objective and waypoint as they stand now (the HUD may have missed the first push)
	task.spawn(function()
		local ok, current = pcall(Net.invoke, "Quest.Current")
		if ok and type(current) == "table" then
			local hud = Registry.get("HudController")
			if hud and type(current.text) == "string" and type(hud.GetObjective) == "function" then
				if hud:GetObjective() == nil then
					hud:SetObjective(current.text)
				end
			end
			if target == nil then
				setWaypoint(current.position, current.label)
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if target ~= nil and now - lastMarkerUpdate >= MARKER_UPDATE then
			lastMarkerUpdate = now
			refreshMarker()
		end
	end)
end

return TutorialController
