--!strict
-- SocialController (client, owned by `tutorial`; design v3 §14b): name tags over other players and click/tap any
-- player to open their profile card.
--   * Name tags: a BillboardGui per other player (kept in PlayerGui, adorned to their head, so respawns and streaming
--     never orphan it): the filtered full name (FullName attribute, else the display name), the title and company in
--     the company's colours, and the level. Redrawn when the player's Tag* / FullName attributes change. The default
--     Roblox name over their humanoid is hidden locally so names don't double up.
--   * Click or tap (a short press without dragging the camera) a character in the world: a camera raycast finds the
--     player and opens the ProfileCard screen. Taps on UI never count (gameProcessed).
--
-- API (used by UI/Screens/ProfileCard):
--   SocialController:GetCard(userId) -> (card?, errKey?)      "Social.GetCard"
--   SocialController:Exchange(userId) -> (ok, errKey?, card?)  "Social.Network"
--   SocialController:OpenCard(userId)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Quests = require(Shared.Config.Quests)
local Registry = require(script.Parent.Parent.Registry)

local SocialController = { Name = "SocialController", Priority = 60 }

local CARD_SCREEN = "ProfileCard"
local TAP_TIME = 0.35
local TAP_MOVE = 14
local RAY_LENGTH = 400
local RAY_SKIPS = 6
local TAG_MAX_DISTANCE = 70
local TAG_ATTRS = { "FullName", "TagTitle", "TagCompany", "TagPrimary", "TagAccent", "TagLevel" }

local localPlayer = Players.LocalPlayer

local function ui(): any
	return Registry.get("UIController")
end

local function text(key: string, vars: { [string]: any }?): string
	return Quests.text(key, vars)
end

---------------------------------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------------------------------
function SocialController:GetCard(userId: number): ({ [string]: any }?, string?)
	local ok, card, err = pcall(Net.invoke, "Social.GetCard", userId)
	if not ok then
		return nil, "generic"
	end
	if type(card) == "table" then
		return card, nil
	end
	return nil, if type(err) == "string" then err else "generic"
end

function SocialController:Exchange(userId: number): (boolean, string?, { [string]: any }?)
	local ok, a, b, c = pcall(Net.invoke, "Social.Network", userId)
	if not ok then
		return false, "generic", nil
	end
	if a == nil and type(b) == "string" then
		return false, "generic", nil -- rate limited, timed out or errored: "try again"
	end
	return a == true, if type(b) == "string" then b else nil, if type(c) == "table" then c else nil
end

function SocialController:OpenCard(userId: number)
	local u = ui()
	if u then
		u:Open(CARD_SCREEN, { userId = userId })
	end
end

---------------------------------------------------------------------------------------------------
-- Name tags
---------------------------------------------------------------------------------------------------
type Tag = {
	gui: BillboardGui,
	name: TextLabel,
	role: TextLabel,
	level: TextLabel,
	conns: { RBXScriptConnection },
	charConn: RBXScriptConnection?,
}

local tags: { [Player]: Tag } = {}

local function hex(s: any, default: Color3): Color3
	if type(s) == "string" and string.match(s, "^#%x%x%x%x%x%x$") then
		local ok, c = pcall(Color3.fromHex, s)
		if ok then
			return c
		end
	end
	return default
end

local function luminance(c: Color3): number
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

local function paintTag(player: Player, tag: Tag)
	local full = player:GetAttribute("FullName")
	tag.name.Text = if type(full) == "string" and full ~= "" then full else player.DisplayName
	local title = player:GetAttribute("TagTitle")
	local company = player:GetAttribute("TagCompany")
	local titleText = if type(title) == "string" and title ~= "" then title else text("tag_student")
	if type(company) == "string" and company ~= "" then
		tag.role.Text = titleText .. " · " .. company
		-- the brighter of the company's two colours reads best over the world
		local primary = hex(player:GetAttribute("TagPrimary"), Color3.fromRGB(233, 205, 128))
		local accent = hex(player:GetAttribute("TagAccent"), primary)
		tag.role.TextColor3 = if luminance(accent) >= luminance(primary) then accent else primary
	else
		tag.role.Text = titleText
		tag.role.TextColor3 = Color3.fromRGB(233, 205, 128)
	end
	local level = player:GetAttribute("TagLevel")
	tag.level.Text = if type(level) == "number" then text("tag_level", { level = math.floor(level) }) else ""
end

local function adorn(player: Player, tag: Tag, character: Model?)
	if not character then
		(tag.gui :: any).Adornee = nil
		return
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		tag.gui.Adornee = head
	else
		(tag.gui :: any).Adornee = nil
		task.spawn(function()
			local h = character:WaitForChild("Head", 30)
			if h and h:IsA("BasePart") and tags[player] == tag and player.Character == character then
				tag.gui.Adornee = h
			end
		end)
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	else
		task.spawn(function()
			local h = character:WaitForChild("Humanoid", 30)
			if h and h:IsA("Humanoid") then
				h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end)
	end
end

local function label(
	parent: Instance,
	name: string,
	y: number,
	height: number,
	size: number,
	font: Enum.Font
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(0, y)
	l.Size = UDim2.new(1, 0, 0, height)
	l.TextSize = size
	l.FontFace = Font.fromEnum(font)
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	l.TextStrokeTransparency = 0.45
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = ""
	l.Parent = parent
	return l
end

local function addTag(player: Player)
	if player == localPlayer or tags[player] then
		return
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag_" .. player.UserId
	gui.Size = UDim2.fromOffset(260, 66)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = TAG_MAX_DISTANCE
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	local tag: Tag = {
		gui = gui,
		name = label(gui, "Name", 0, 26, 21, Enum.Font.GothamBold),
		role = label(gui, "Role", 26, 20, 15, Enum.Font.GothamMedium),
		level = label(gui, "Level", 46, 18, 13, Enum.Font.RobotoMono),
		conns = {},
		charConn = nil,
	}
	tags[player] = tag
	paintTag(player, tag)
	for _, attr in TAG_ATTRS do
		table.insert(
			tag.conns,
			player:GetAttributeChangedSignal(attr):Connect(function()
				paintTag(player, tag)
			end)
		)
	end
	table.insert(
		tag.conns,
		player.CharacterAdded:Connect(function(character: Model)
			adorn(player, tag, character)
		end)
	)
	adorn(player, tag, player.Character)
	gui.Parent = playerGui
end

local function removeTag(player: Player)
	local tag = tags[player]
	if not tag then
		return
	end
	tags[player] = nil
	for _, c in tag.conns do
		c:Disconnect()
	end
	tag.gui:Destroy()
end

---------------------------------------------------------------------------------------------------
-- Click / tap a player
---------------------------------------------------------------------------------------------------
local pressAt: number? = nil
local pressPos: Vector2? = nil

local function playerAt(screen: Vector2): Player?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = if localPlayer.Character then { localPlayer.Character } else {}
	params.IgnoreWater = true
	-- invisible queryable parts (interaction markers, trigger volumes) don't block the tap: skip past a few
	for _ = 1, RAY_SKIPS do
		params.FilterDescendantsInstances = exclude
		local hit = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
		if not hit then
			return nil
		end
		local node: Instance? = hit.Instance
		while node and node ~= workspace do
			if node:IsA("Model") then
				local p = Players:GetPlayerFromCharacter(node)
				if p then
					return p
				end
			end
			node = node.Parent
		end
		local part = hit.Instance
		if part:IsA("BasePart") and (part.Transparency >= 0.95 or not part.CanCollide) then
			table.insert(exclude, part)
		else
			return nil
		end
	end
	return nil
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function onBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or not isPress(input) then
		return
	end
	pressAt = os.clock()
	pressPos = Vector2.new(input.Position.X, input.Position.Y)
end

local function onEnded(input: InputObject, gameProcessed: boolean)
	if not isPress(input) then
		return
	end
	local at, from = pressAt, pressPos
	pressAt, pressPos = nil, nil
	if gameProcessed or not at or not from then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	if os.clock() - at > TAP_TIME or (pos - from).Magnitude > TAP_MOVE then
		return -- a drag (camera) or a long press, not a tap
	end
	local u = ui()
	if u and (u:IsOpen(nil) or u:HasModal()) then
		return
	end
	local target = playerAt(pos)
	if target and target ~= localPlayer then
		SocialController:OpenCard(target.UserId)
	end
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function SocialController:Init() end

function SocialController:Start()
	Players.PlayerAdded:Connect(addTag)
	Players.PlayerRemoving:Connect(removeTag)
	if not localPlayer:FindFirstChildOfClass("PlayerGui") then
		localPlayer:WaitForChild("PlayerGui", 60)
	end
	for _, p in Players:GetPlayers() do
		addTag(p)
	end
	UserInputService.InputBegan:Connect(onBegan)
	UserInputService.InputEnded:Connect(onEnded)
end

return SocialController
