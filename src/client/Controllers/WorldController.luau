--!strict
-- WorldController (client, owned by `offices`): the client side of doors and teleports (WorldService).
--   * "World.Fade"(phase, info): a full-screen fade to black while the server moves the character ("out"), back
--     in with a title card of where you arrived ("in": info.label / info.sublabel). A failsafe fades back in if
--     the server never says "in" (and a respawn always clears it).
--   * a zone title card ("Wall Street", "The Galleria") when the server-set "Zone" attribute changes without a
--     labelled teleport
--   * "World.DoorLocked"(info): the door's lock message as a warning toast
--   * "World.Ride"(info): the "Next stop" banner while riding the subway
--   * door prompts the local player can't use yet read "Locked" (requirements checked locally with
--     Logic/DoorRules against replicated data; the server re-checks every use)
--
-- API:
--   WorldController:ShowTitle(title, subtitle?)    a title card (other features may use it too)
--   WorldController:IsFaded() -> boolean

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local World = require(Shared.Config.World)
local DoorRules = require(Shared.Logic.DoorRules)
local Registry = require(script.Parent.Parent.Registry)
local UIFolder = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UIFolder:WaitForChild("Kit"))
local Sfx = require(UIFolder:WaitForChild("Sfx"))

local Text = DoorRules.Text

local WorldController = { Name = "WorldController", Priority = 25 }

local FADE_OUT = 0.25
local FADE_IN = 0.45
local FAILSAFE = 9
local TITLE_HOLD = 2.4
local TITLE_FADE = 0.5
local ZONE_CARD_GAP = 3.5
local LOCK_REPEAT = 1.5

local localPlayer = Players.LocalPlayer
local doorDefs = World.doors :: { [string]: { [string]: any } }

---------------------------------------------------------------------------------------------------
-- Overlay GUI (its own ScreenGui above the main UI, so the fade covers everything)
---------------------------------------------------------------------------------------------------
local gui: ScreenGui? = nil
local cover: Frame = nil :: any
local message: TextLabel = nil :: any
local titleFrame: Frame = nil :: any
local titleLabel: TextLabel = nil :: any
local subLabel: TextLabel = nil :: any

local fadedOut = false
local fadeToken = 0
local titleToken = 0
local lastTitleAt = -math.huge

local function label(name: string, parent: Instance, font: string, size: string): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	l.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	l.Text = ""
	Kit.themed(l, function(t)
		l.FontFace = Kit.font(t, font)
		l.TextSize = Kit.textSize(t, size) + (if size == "xxl" then 10 else 0)
	end)
	l.Parent = parent
	return l
end

local function buildGui(): ScreenGui
	local existing = gui
	if existing then
		return existing
	end
	local g = Instance.new("ScreenGui")
	g.Name = "WorldFade"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 50
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	cover = Instance.new("Frame")
	cover.Name = "Cover"
	cover.BorderSizePixel = 0
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	cover.BackgroundTransparency = 1
	cover.Visible = false
	cover.Active = false
	cover.Parent = g
	message = label("Message", cover, "body", "md")
	message.AnchorPoint = Vector2.new(0.5, 0.5)
	message.Position = UDim2.fromScale(0.5, 0.62)
	message.Size = UDim2.new(1, -48, 0, 0)
	message.TextTransparency = 0.15

	titleFrame = Instance.new("Frame")
	titleFrame.Name = "TitleCard"
	titleFrame.BackgroundTransparency = 1
	titleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	titleFrame.Position = UDim2.fromScale(0.5, 0.3)
	titleFrame.Size = UDim2.new(1, -48, 0, 0)
	titleFrame.AutomaticSize = Enum.AutomaticSize.Y
	titleFrame.Visible = false
	titleFrame.ZIndex = 2
	titleFrame.Parent = g
	local list = Kit.list(titleFrame, false, 4)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	titleLabel = label("Title", titleFrame, "display", "xxl")
	titleLabel.LayoutOrder = 1
	subLabel = label("Subtitle", titleFrame, "heading", "lg")
	subLabel.LayoutOrder = 2
	local accent = Instance.new("Frame")
	accent.Name = "Rule"
	accent.BorderSizePixel = 0
	accent.Size = UDim2.fromOffset(120, 2)
	accent.LayoutOrder = 3
	accent.Parent = titleFrame
	Kit.themed(accent, function(t)
		accent.BackgroundColor3 = t.colors.accent
	end)

	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		g.Parent = playerGui
	else
		task.spawn(function()
			local pg = localPlayer:WaitForChild("PlayerGui", 60)
			if pg then
				g.Parent = pg
			end
		end)
	end
	gui = g
	return g
end

---------------------------------------------------------------------------------------------------
-- Title card
---------------------------------------------------------------------------------------------------
local function setTitleAlpha(a: number)
	titleLabel.TextTransparency = a
	titleLabel.TextStrokeTransparency = 0.4 + 0.6 * a
	subLabel.TextTransparency = a
	subLabel.TextStrokeTransparency = 0.5 + 0.5 * a
end

function WorldController:ShowTitle(title: string, subtitle: string?)
	if type(title) ~= "string" or title == "" then
		return
	end
	buildGui()
	titleToken += 1
	local token = titleToken
	lastTitleAt = os.clock()
	titleLabel.Text = title
	subLabel.Text = if type(subtitle) == "string" and subtitle ~= title then subtitle else ""
	subLabel.Visible = subLabel.Text ~= ""
	setTitleAlpha(1)
	titleFrame.Visible = true
	Kit.tween(titleLabel, TITLE_FADE, { TextTransparency = 0, TextStrokeTransparency = 0.4 })
	Kit.tween(subLabel, TITLE_FADE, { TextTransparency = 0, TextStrokeTransparency = 0.5 })
	task.delay(TITLE_FADE + TITLE_HOLD, function()
		if titleToken ~= token then
			return
		end
		Kit.tween(titleLabel, TITLE_FADE, { TextTransparency = 1, TextStrokeTransparency = 1 })
		Kit.tween(subLabel, TITLE_FADE, { TextTransparency = 1, TextStrokeTransparency = 1 })
		task.delay(TITLE_FADE, function()
			if titleToken == token then
				titleFrame.Visible = false
			end
		end)
	end)
end

---------------------------------------------------------------------------------------------------
-- Fade
---------------------------------------------------------------------------------------------------
local function fadeIn(info: { [string]: any }?)
	if not fadedOut then
		return
	end
	fadedOut = false
	fadeToken += 1
	local token = fadeToken
	message.Text = ""
	Kit.tween(cover, FADE_IN, { BackgroundTransparency = 1 })
	task.delay(FADE_IN, function()
		if fadeToken == token then
			cover.Visible = false
		end
	end)
	if info and type(info.label) == "string" and info.label ~= "" then
		WorldController:ShowTitle(info.label, if type(info.sublabel) == "string" then info.sublabel else nil)
	end
end

local function fadeOut(info: { [string]: any }?)
	buildGui()
	fadedOut = true
	fadeToken += 1
	local token = fadeToken
	message.Text = if info and type(info.message) == "string" then info.message else ""
	cover.Visible = true
	Kit.tween(cover, FADE_OUT, { BackgroundTransparency = 0 })
	task.delay(FAILSAFE, function()
		if fadeToken == token and fadedOut then
			fadeIn(nil)
		end
	end)
end

function WorldController:IsFaded(): boolean
	return fadedOut
end

---------------------------------------------------------------------------------------------------
-- HUD helpers (guarded: the HUD belongs to the ui feature)
---------------------------------------------------------------------------------------------------
local function hud(): any
	return Registry.get("HudController")
end

local lastLock: { text: string, at: number }? = nil
local function onDoorLocked(info: any)
	local given = if type(info) == "table" and type(info.text) == "string" then info.text else ""
	local text: string = if given ~= "" then given else Text.get("door_locked_default")
	local now = os.clock()
	local last = lastLock
	if last and last.text == text and now - last.at < LOCK_REPEAT then
		return
	end
	lastLock = { text = text, at = now }
	Sfx.play("error")
	local h = hud()
	if h and type(h.Flash) == "function" then
		h:Flash(text, "warn")
	end
end

local function onRide(info: any)
	if type(info) ~= "table" then
		return
	end
	local h = hud()
	if h and type(h.Banner) == "function" then
		h:Banner({
			title = if type(info.title) == "string" then info.title else Text.get("ride_next_stop"),
			subtitle = if type(info.subtitle) == "string" then info.subtitle else nil,
			style = "event",
			duration = math.clamp(if type(info.seconds) == "number" then info.seconds else 6, 2, 30),
		})
	end
	Sfx.play("chime")
end

---------------------------------------------------------------------------------------------------
-- Zone cards
---------------------------------------------------------------------------------------------------
local lastZone: string? = nil
local function onZone()
	local zone = localPlayer:GetAttribute("Zone")
	if type(zone) ~= "string" or zone == lastZone then
		return
	end
	local first = lastZone == nil
	lastZone = zone
	if zone == "offices" then
		return -- office arrivals carry their own company / floor title
	end
	task.delay(0.6, function()
		if lastZone ~= zone or fadedOut then
			return
		end
		if first or os.clock() - lastTitleAt > ZONE_CARD_GAP then
			WorldController:ShowTitle(DoorRules.zoneLabel(zone))
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Door prompts: "Locked" for doors whose requirements the local player doesn't meet yet
---------------------------------------------------------------------------------------------------
local doorPrompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local doorRoots: { [Instance]: RBXScriptConnection } = {}

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

-- Player data as the client sees it (read lazily, key by key, for DoorRules dot paths).
local dataView = setmetatable({}, {
	__index = function(_, key: any): any
		return if type(key) == "string" then storeGet(key) else nil
	end,
})

local function evaluateDoor(prompt: ProximityPrompt)
	local doorId = prompt:GetAttribute("DoorId")
	local def = if type(doorId) == "string" then doorDefs[doorId] else nil
	if not def or def.requires == nil then
		return
	end
	local base = prompt:GetAttribute("ActionBase")
	local action = if type(base) == "string" and base ~= "" then base else (DoorRules.promptText(def))
	local ok = DoorRules.check(def.requires, DoorRules.stateFromData(dataView))
	local want = if ok then action else Text.get("door_locked")
	if prompt.ActionText ~= want then
		prompt.ActionText = want
	end
end

local function evaluateDoors()
	for prompt in doorPrompts do
		if prompt.Parent then
			evaluateDoor(prompt)
		end
	end
end

local function trackDoorPrompt(inst: Instance)
	if not inst:IsA("ProximityPrompt") or doorPrompts[inst] then
		return
	end
	-- WorldService sets DoorId before parenting the prompt, so it replicates with it; office doors have none.
	if type(inst:GetAttribute("DoorId")) ~= "string" then
		return
	end
	doorPrompts[inst] = true
	evaluateDoor(inst)
end

local function watchDoor(part: Instance)
	if doorRoots[part] then
		return
	end
	doorRoots[part] = part.ChildAdded:Connect(trackDoorPrompt)
	for _, c in part:GetChildren() do
		trackDoorPrompt(c)
	end
end

local function unwatchDoor(part: Instance)
	local conn = doorRoots[part]
	if conn then
		doorRoots[part] = nil
		conn:Disconnect()
	end
end

local function startDoorWatch()
	CollectionService:GetInstanceAddedSignal("Door"):Connect(watchDoor)
	CollectionService:GetInstanceRemovedSignal("Door"):Connect(unwatchDoor)
	for _, part in CollectionService:GetTagged("Door") do
		watchDoor(part)
	end
	local s = store()
	if s then
		pcall(function()
			for _, key in { "career", "campus", "entitlements" } do
				s:Changed(key):Connect(evaluateDoors)
			end
			s.Loaded:Connect(evaluateDoors)
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function WorldController:Init()
	buildGui()
end

function WorldController:Start()
	Net.listen("World.Fade", function(phase: any, info: any)
		local i = if type(info) == "table" then info else nil
		if phase == "out" then
			fadeOut(i)
		elseif phase == "in" then
			fadeIn(i)
		end
	end)
	Net.listen("World.DoorLocked", onDoorLocked)
	Net.listen("World.Ride", onRide)
	localPlayer:GetAttributeChangedSignal("Zone"):Connect(onZone)
	localPlayer.CharacterAdded:Connect(function()
		if fadedOut then
			fadeIn(nil)
		end
	end)
	onZone()
	startDoorWatch()
end

return WorldController
