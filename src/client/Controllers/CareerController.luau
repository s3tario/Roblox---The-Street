--!strict
-- CareerController (client, owned by `careerPath`): the career's client side.
--   * the "Career" menu tab (quick button) and a badge for pending job offers
--   * the weekly review: plays "Career.Meeting" payloads in the ReviewMeeting screen (a phone call waits for the
--     current screen to close), and shows a waypoint to the boss's office while career.reviewDue
--   * "Career.Open" (Career Services prompt) and "Career.Objective" (when the tutorial's quest tracker is absent)
--   * activity pings for ActivityService ("Activity.Ping"(idleSeconds) every 15 s)
--   * hides EmployeesOnly boss_review prompts for visitors (the server refuses them either way)
--
-- API (used by the Career screens):
--   CareerController:Call(remote, ...) -> (ok, errKey?, a?, b?)     RemoteFunction wrapper
--   CareerController:ErrorText(errKey?) -> string
--   CareerController:AcceptOffer(id) / :DeclineOffer(id) -> (ok, errKey?)
--   CareerController:GetServices() -> info?
--   CareerController:Reentry(action, answers?) -> (ok, errKey?, view?, result?)
--   CareerController:Reinstate() / :UseCapital() / :FreshStart() -> (ok, errKey?)
--   CareerController:HasStore() -> boolean / :OpenStore(productKey) -> boolean   the monetization Store, once it ships
--   CareerController:HasScreen(id) -> boolean
--   CareerController:MeetingClosed()                   ReviewMeeting calls this; the next queued meeting opens
--   CareerController.CareerChanged : Signal(career)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Tracks = require(Shared.Config.Tracks)
local CareerState = require(Shared.Logic.CareerState)
local Registry = require(script.Parent.Parent.Registry)

local CareerController = { Name = "CareerController", Priority = 40 }

CareerController.CareerChanged = Signal.new()

local MENU_ID = "career"
local MEETING_SCREEN = "ReviewMeeting"
local OPENABLE = { CareerServices = true, Career = true, Offers = true } :: { [string]: boolean }
local PING_EVERY = 15
local TARGET_EVERY = 6
local PHONE_WAIT = 45
local PROMPT_INTERACT = "boss_review"

local queue: { { [string]: any } } = {}
local meetingOpen = false
local lastInput = os.clock()

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

local function hud(): any
	return Registry.get("HudController")
end

local function flash(text: string, kind: string?)
	local h = hud()
	if h and type(h.Flash) == "function" then
		pcall(h.Flash, h, text, kind)
	end
end

---------------------------------------------------------------------------------------------------
-- Remote helpers
---------------------------------------------------------------------------------------------------
function CareerController:Call(name: string, ...: any): (boolean, string?, any, any)
	local ok, a, b, c, d = pcall(Net.invoke, name, ...)
	if not ok then
		return false, "generic", nil, nil
	end
	if a == true then
		return true, nil, c, d
	end
	if a == nil and type(b) == "string" then
		if b == "timeout" or b == "rate_limited" then
			return false, b, nil, nil
		end
		return false, "generic", nil, nil
	end
	return false, if type(b) == "string" then b else "generic", c, d
end

function CareerController:ErrorText(err: string?): string
	local key = err or "generic"
	local s = Tracks.strings
	return s["err_" .. key .. "_short"] or s["err_" .. key] or s.err_generic
end

function CareerController:AcceptOffer(id: string): (boolean, string?)
	local ok, err = CareerController:Call("Career.AcceptOffer", id)
	return ok, err
end

function CareerController:DeclineOffer(id: string): (boolean, string?)
	local ok, err = CareerController:Call("Career.DeclineOffer", id)
	return ok, err
end

function CareerController:GetServices(): { [string]: any }?
	local ok, info = pcall(Net.invoke, "Career.Services")
	if ok and type(info) == "table" then
		return info
	end
	return nil
end

function CareerController:Reentry(action: string, answers: any?): (boolean, string?, any, any)
	local ok, a, b, view, result = pcall(Net.invoke, "Career.Reentry", action, answers)
	if not ok then
		return false, "generic", nil, nil
	end
	if a == true then
		return true, nil, view, result
	end
	if a == nil and (b == "timeout" or b == "rate_limited") then
		return false, b, nil, nil
	end
	return false, if type(b) == "string" and b ~= "error" then b else "generic", view, result
end

function CareerController:Reinstate(): (boolean, string?)
	local ok, err = CareerController:Call("Career.Reinstate")
	return ok, err
end

function CareerController:UseCapital(): (boolean, string?)
	local ok, err = CareerController:Call("Career.UseCapital")
	return ok, err
end

function CareerController:FreshStart(): (boolean, string?)
	local ok, err = CareerController:Call("Career.FreshStart")
	return ok, err
end

function CareerController:HasScreen(id: string): boolean
	local u = ui()
	if not u or type(u.GetScreenIds) ~= "function" then
		return false
	end
	local ok, ids = pcall(u.GetScreenIds, u)
	return ok and type(ids) == "table" and table.find(ids, id) ~= nil
end

-- True when the monetization feature's Store can be opened (controller or screen).
function CareerController:HasStore(): boolean
	local storeController = Registry.get("StoreController")
	if storeController and type(storeController.Open) == "function" then
		return true
	end
	return CareerController:HasScreen("Store")
end

function CareerController:OpenStore(productKey: string): boolean
	local u = ui()
	if not u then
		return false
	end
	local storeController = Registry.get("StoreController")
	if storeController and type(storeController.Open) == "function" then
		local ok = pcall(storeController.Open, storeController, productKey)
		if ok then
			return true
		end
	end
	if CareerController:HasScreen("Store") then
		u:Open("Store", { focus = productKey })
		return true
	end
	return false
end

---------------------------------------------------------------------------------------------------
-- Review meetings
---------------------------------------------------------------------------------------------------
local function openNext()
	if meetingOpen or #queue == 0 then
		return
	end
	local u = ui()
	if not u then
		return
	end
	local payload = table.remove(queue, 1) :: { [string]: any }
	meetingOpen = true
	local ok = pcall(function()
		u:Open(MEETING_SCREEN, { payload = payload, hideHud = true })
	end)
	if not ok then
		meetingOpen = false
	end
end

function CareerController:MeetingClosed()
	meetingOpen = false
	task.defer(openNext)
end

local waitingForScreen = false
local function onMeeting(payload: any)
	if type(payload) ~= "table" or type(payload.lines) ~= "table" then
		return
	end
	table.insert(queue, payload)
	while #queue > 3 do
		table.remove(queue, 1)
	end
	local u = ui()
	if not u then
		return
	end
	local current = if type(u.Current) == "function" then u:Current() else nil
	local busy = current ~= nil and current ~= "Menu" and current ~= "Career" and current ~= MEETING_SCREEN
	if payload.mode == "office" or not busy then
		openNext()
		return
	end
	-- a phone call while the player is in another screen: ring, then pick up when that screen closes
	flash(
		Tracks.text("review_call", { boss = if type(payload.boss) == "table" then payload.boss.name else "" }),
		"info"
	)
	if waitingForScreen then
		return
	end
	waitingForScreen = true
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < PHONE_WAIT do
			local cur = u:Current()
			if cur == nil or cur == "Menu" or cur == "Career" then
				break
			end
			task.wait(0.5)
		end
		waitingForScreen = false
		openNext()
	end)
end

---------------------------------------------------------------------------------------------------
-- Waypoint to the boss's office (while career.reviewDue)
---------------------------------------------------------------------------------------------------
local waypoint: Part? = nil
local waypointLabel: TextLabel? = nil
local waypointDistance: TextLabel? = nil
local waypointBeam: Beam? = nil
local targetLoop = 0

local function clearWaypoint()
	if waypoint then
		waypoint:Destroy()
	end
	waypoint, waypointLabel, waypointDistance, waypointBeam = nil, nil, nil, nil
end

local function ensureWaypoint(): Part
	local existing = waypoint
	if existing and existing.Parent then
		return existing
	end
	local part = Instance.new("Part")
	part.Name = "CareerWaypoint"
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
	gui.Size = UDim2.fromOffset(190, 64)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = math.huge
	gui.Parent = part
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.new(1, 0, 0, 20)
	arrow.Position = UDim2.new(0, 0, 1, -20)
	arrow.Text = "▼"
	arrow.TextScaled = true
	arrow.TextColor3 = Color3.fromRGB(201, 165, 76)
	arrow.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	arrow.Parent = gui
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(11, 31, 58)
	label.Size = UDim2.new(1, 0, 0, 26)
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 15
	label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
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
	part.Parent = workspace
	waypoint = part
	waypointLabel = label
	waypointDistance = distance
	return part
end

local function attachBeam(part: Part)
	local player = Players.LocalPlayer
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	local beam = waypointBeam
	local from = root:FindFirstChild("CareerWaypointFrom")
	if not from then
		local a = Instance.new("Attachment")
		a.Name = "CareerWaypointFrom"
		a.Position = Vector3.new(0, -2.5, 0)
		a.Parent = root
		from = a
	end
	if beam and beam.Parent and beam.Attachment0 == from then
		return
	end
	if beam then
		beam:Destroy()
	end
	local b = Instance.new("Beam")
	b.Name = "CareerWaypointBeam"
	b.Attachment0 = from :: Attachment
	b.Attachment1 = part:FindFirstChild("Target") :: Attachment
	b.FaceCamera = true
	b.Width0 = 0.35
	b.Width1 = 0.35
	b.Segments = 1
	b.LightInfluence = 0
	b.Color = ColorSequence.new(Color3.fromRGB(201, 165, 76))
	b.Transparency = NumberSequence.new(0.35)
	b.Parent = part
	waypointBeam = b
end

local function updateDistance()
	local part = waypoint
	local text = waypointDistance
	if not part or not text then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		local d = (root.Position - part.Position).Magnitude
		text.Text = string.format("%d m", math.floor(d * 0.28 + 0.5))
		if d < 12 then
			text.Text = Tracks.text("waypoint_here")
		end
	end
end

local function reviewWanted(): boolean
	local career = storeGet("career")
	return type(career) == "table" and career.reviewDue == true and CareerState.isEmployed(career)
end

local function startTargetLoop()
	targetLoop += 1
	local id = targetLoop
	task.spawn(function()
		while id == targetLoop and reviewWanted() do
			local ok, target = pcall(Net.invoke, "Career.ReviewTarget")
			if id ~= targetLoop then
				return
			end
			if ok and type(target) == "table" and typeof(target.position) == "Vector3" then
				local part = ensureWaypoint()
				part.Position = target.position
				local label = waypointLabel
				if label then
					label.Text = if type(target.label) == "string" then target.label else ""
				end
				attachBeam(part)
			else
				clearWaypoint()
			end
			for _ = 1, TARGET_EVERY * 2 do
				if id ~= targetLoop then
					return
				end
				updateDistance()
				task.wait(0.5)
			end
		end
		if id == targetLoop then
			clearWaypoint()
		end
	end)
end

local wasDue = false
local function onCareer(career: any)
	local due = type(career) == "table" and career.reviewDue == true and CareerState.isEmployed(career)
	if due and not wasDue then
		startTargetLoop()
	elseif not due and wasDue then
		targetLoop += 1
		clearWaypoint()
	end
	wasDue = due
	local u = ui()
	if u and type(u.SetMenuBadge) == "function" then
		local offers = if type(career) == "table" and type(career.offers) == "table" then #career.offers else 0
		local badge = if offers > 0 then tostring(offers) elseif due then "!" else nil
		pcall(u.SetMenuBadge, u, MENU_ID, badge)
	end
	CareerController.CareerChanged:Fire(career)
end

---------------------------------------------------------------------------------------------------
-- EmployeesOnly boss_review prompts
---------------------------------------------------------------------------------------------------
local prompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local hiddenByUs: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Instance]: RBXScriptConnection } = {}

-- Hides the prompt for visitors; only ever re-enables a prompt this controller hid (OfficeController applies the
-- same rule to every EmployeesOnly prompt, and the server may disable prompts for its own reasons).
local function evaluate(prompt: ProximityPrompt)
	if prompt:GetAttribute("EmployeesOnly") ~= true then
		if hiddenByUs[prompt] then
			hiddenByUs[prompt] = nil
			prompt.Enabled = true
		end
		return
	end
	local companyId = prompt:GetAttribute("CompanyId")
	local career = storeGet("career")
	local s = store()
	local events = nil
	if s then
		local ok, v = pcall(function()
			return s:GetGlobal("events")
		end)
		events = if ok then v else nil
	end
	local partners = if type(career) == "table" and type(career.companyId) == "string"
		then CareerState.mergerPartners(events, career.companyId, workspace:GetServerTimeNow())
		else nil
	local allowed = CareerState.isEmployee(career, companyId, partners)
	if not allowed then
		if prompt.Enabled then
			prompt.Enabled = false
			hiddenByUs[prompt] = true
		end
	elseif hiddenByUs[prompt] then
		hiddenByUs[prompt] = nil
		prompt.Enabled = true
	end
end

local function evaluateAll()
	for prompt in prompts do
		if prompt.Parent then
			evaluate(prompt)
		end
	end
end

local function track(inst: Instance)
	if not inst:IsA("ProximityPrompt") or prompts[inst] then
		return
	end
	if inst:GetAttribute("InteractId") ~= PROMPT_INTERACT then
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

local function watch(inst: Instance)
	if inst:GetAttribute("InteractId") ~= PROMPT_INTERACT or watched[inst] then
		return
	end
	watched[inst] = inst.DescendantAdded:Connect(function(d: Instance)
		-- the InteractId attribute may replicate a frame after the prompt itself
		task.defer(track, d)
	end)
	for _, d in inst:GetDescendants() do
		track(d)
	end
end

local function startPromptWatch()
	CollectionService:GetInstanceAddedSignal("Interact"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("Interact"):Connect(function(inst: Instance)
		local conn = watched[inst]
		if conn then
			watched[inst] = nil
			conn:Disconnect()
		end
	end)
	for _, inst in CollectionService:GetTagged("Interact") do
		watch(inst)
	end
end

---------------------------------------------------------------------------------------------------
-- Activity pings
---------------------------------------------------------------------------------------------------
local function startActivity()
	local function mark()
		lastInput = os.clock()
	end
	UserInputService.InputBegan:Connect(mark)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local t = input.UserInputType
		if
			t == Enum.UserInputType.MouseMovement
			or t == Enum.UserInputType.Touch
			or t == Enum.UserInputType.Gamepad1
			or t == Enum.UserInputType.MouseWheel
		then
			mark()
		end
	end)
	UserInputService.TouchStarted:Connect(mark)
	UserInputService.WindowFocused:Connect(mark)
	task.spawn(function()
		while true do
			pcall(Net.send, "Activity.Ping", math.max(0, os.clock() - lastInput))
			task.wait(PING_EVERY)
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function CareerController:Init() end

function CareerController:Start()
	local u = ui()
	if u and type(u.RegisterMenuTab) == "function" then
		u:RegisterMenuTab({
			id = MENU_ID,
			title = Tracks.text("menu_career"),
			glyph = "💼",
			order = 20,
			screen = "Career",
			quick = true,
		})
	end
	Net.listen("Career.Meeting", onMeeting)
	Net.listen("Career.Objective", function(text: any)
		local h = hud()
		if h and type(h.SetObjective) == "function" then
			pcall(h.SetObjective, h, if type(text) == "string" and text ~= "" then text else nil)
		end
	end)
	Net.listen("Career.Open", function(screenId: any, args: any)
		local target = ui()
		if target and type(screenId) == "string" and OPENABLE[screenId] then
			target:Open(screenId, if type(args) == "table" then args else nil)
		end
	end)
	startActivity()
	startPromptWatch()
	local s = store()
	if s then
		pcall(function()
			onCareer(s:Get("career"))
			s:Changed("career"):Connect(function(career: any)
				onCareer(career)
				evaluateAll()
			end)
			s:GlobalChanged("events"):Connect(evaluateAll)
			s.Loaded:Connect(function()
				onCareer(s:Get("career"))
				evaluateAll()
			end)
		end)
	end
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.delay(1, function()
			local part = waypoint
			if part and part.Parent then
				attachBeam(part)
			end
		end)
	end)
end

return CareerController
