--!strict
-- NpcService (server, owned by `tutorial`): the people of Eastbridge and the Street.
--
--   * Every "npc" Interact spot under Workspace (Kit.npcSpot: InteractId "npc", attribute NpcId), including spots
--     added later, gets its NPC from Config/Npcs: NpcRig.spawn (a real R15 dressed in its Catalog preset, anchored),
--     falling back to the part-built NpcRig.build, standing on the floor under the spot and facing the spot's front.
--     A BillboardGui shows the name and title, and a "Talk" ProximityPrompt opens the conversation (DialogueService).
--     If no rig can be built at all, the prompt goes on the spot itself so the conversation still works.
--   * Office staff are spawned by the offices feature (models with OfficeNpc = "receptionist" | "boss" in each floor's
--     OfficeNpcs folder). This service adds their Talk prompt: the boss is employees only (prompt attributes CompanyId
--     and EmployeesOnly, a polite toast for visitors); the receptionist greets everyone.
--
-- API:
--   NpcService:GetNpcModel(npcId) -> Model?       NpcService:GetNpcPosition(npcId) -> Vector3?
--   NpcService:FaceToward(model, position)        turns a standing NPC toward the person talking (eases back later)
--   NpcService:GetDef(npcId) -> NpcDef?
-- Workspace folder: "TutorialNpcs" (each NPC is a Model with attribute NpcId; ModelStreamingMode Atomic).
-- Every Talk prompt carries the CollectionService tag "TalkPrompt" (and InteractId "npc").

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Npcs = require(Shared.Config.Npcs)
local Quests = require(Shared.Config.Quests)
local Companies = require(Shared.Config.Companies)
local Deps = require(script.Parent.TutorialService.Deps)
local Interacts = require(script.Parent.TutorialService.Interacts)

local NpcService = { Name = "NpcService", Priority = 60 }

NpcService.FOLDER = "TutorialNpcs"
NpcService.PROMPT_NAME = "TalkPrompt"
NpcService.INTERACT_ID = "npc"
NpcService.PROMPT_TAG = "TalkPrompt" -- CollectionService tag on every Talk prompt (clients hide EmployeesOnly ones)

local FACE_RESET = 12
local OPEN_COOLDOWN = 0.75

type Placed = { id: string, spot: BasePart, model: Model?, home: CFrame?, faceSeq: number }

local placed: { [string]: { Placed } } = {}
local byModel: { [Model]: Placed } = setmetatable({}, { __mode = "k" }) :: any
local lastOpen: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
local warnedIds: { [string]: boolean } = {}
local spawnQueue: { () -> () } = {}
local spawning = false

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
local rigModule: any = nil
local function rig(): any
	if rigModule == nil then
		local ok, m = pcall(function()
			return (require :: any)(Shared.Assets.Npc.Rig)
		end)
		if ok and type(m) == "table" and (type(m.spawn) == "function" or type(m.build) == "function") then
			rigModule = m
		else
			rigModule = false
			warn("[NpcService] NpcRig unavailable, NPCs will be prompt-only: " .. tostring(m))
		end
	end
	return if rigModule then rigModule else nil
end

local folderRef: Folder? = nil
local function npcFolder(): Folder
	local f = folderRef
	if f and f.Parent then
		return f
	end
	local existing = workspace:FindFirstChild(NpcService.FOLDER)
	if existing and existing:IsA("Folder") then
		folderRef = existing
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = NpcService.FOLDER
	created.Parent = workspace
	folderRef = created
	return created
end

local stagingRef: Folder? = nil
local function staging(): Folder
	local f = stagingRef
	if f and f.Parent then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = "TutorialNpcStaging"
	created.Parent = ServerStorage
	stagingRef = created
	return created
end

local function flatRotation(cf: CFrame): CFrame
	local lv = cf.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	if flat.Magnitude < 1e-3 then
		return CFrame.identity
	end
	return CFrame.lookAt(Vector3.zero, flat.Unit)
end

-- The floor point under a spot, facing the spot's front face.
local function standPoint(spot: BasePart): CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { spot, npcFolder() }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	local from = spot.Position + Vector3.new(0, 2, 0)
	local hit = workspace:Raycast(from, Vector3.new(0, -30, 0), params)
	local base = if hit then hit.Position else spot.Position - Vector3.new(0, spot.Size.Y / 2, 0)
	return CFrame.new(base) * flatRotation(spot.CFrame)
end

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

local function nameTag(model: Model, name: string, title: string, color: string?)
	local head = model:FindFirstChild("Head")
	local adornee: BasePart? = if head and head:IsA("BasePart") then head else rootOf(model)
	if not adornee then
		return
	end
	local old = adornee:FindFirstChild("NpcNameTag")
	if old then
		old:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "NpcNameTag"
	bb.Adornee = adornee
	bb.Size = UDim2.fromOffset(240, 52)
	bb.StudsOffset = Vector3.new(0, if adornee == head then 2.4 else 4.5, 0)
	bb.MaxDistance = 45
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0, 28)
	nameLabel.Text = name
	nameLabel.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	nameLabel.TextSize = 22
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.45
	nameLabel.Parent = bb
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(0, 28)
	titleLabel.Size = UDim2.new(1, 0, 0, 20)
	titleLabel.Text = title
	titleLabel.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	titleLabel.TextSize = 16
	local tint = Color3.fromRGB(233, 205, 128)
	if type(color) == "string" then
		local okHex, c = pcall(Color3.fromHex, color)
		if okHex then
			tint = c
		end
	end
	titleLabel.TextColor3 = tint
	titleLabel.TextStrokeTransparency = 0.55
	titleLabel.Parent = bb
	bb.Parent = adornee
end

local function hideDefaultName(model: Model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
end

local function cooled(player: Player): boolean
	local now = os.clock()
	if now - (lastOpen[player] or 0) < OPEN_COOLDOWN then
		return false
	end
	lastOpen[player] = now
	return true
end

---------------------------------------------------------------------------------------------------
-- World NPCs
---------------------------------------------------------------------------------------------------
local function build(def: Npcs.NpcDef, cf: CFrame): Model?
	local NpcRig = rig()
	if not NpcRig then
		return nil
	end
	local opts: { [string]: any } = {
		name = def.name,
		preset = def.preset,
		pose = def.pose or "stand",
		expression = def.expression,
		hairStyle = def.hairStyle,
		cframe = cf,
		seed = def.id,
		parent = staging(),
		anchorRoot = true,
		anchored = true,
	}
	if type(NpcRig.spawn) == "function" then
		local ok, model = pcall(NpcRig.spawn, opts)
		if ok and typeof(model) == "Instance" and model:IsA("Model") then
			return model
		end
		if not ok then
			warn(("[NpcService] spawn %s failed, using the part-built rig: %s"):format(def.id, tostring(model)))
		end
	end
	if type(NpcRig.build) == "function" then
		local ok, model = pcall(NpcRig.build, opts)
		if ok and typeof(model) == "Instance" and model:IsA("Model") then
			return model
		end
		warn(("[NpcService] build %s failed: %s"):format(def.id, tostring(model)))
	end
	return nil
end

local function talk(player: Player, entry: Placed, def: Npcs.NpcDef)
	if not cooled(player) then
		return
	end
	local model = entry.model
	local origin = if model and rootOf(model) then (rootOf(model) :: BasePart).Position else entry.spot.Position
	Deps.call("DialogueService", "Open", player, def.id, def.dialogue, {
		model = model,
		origin = origin,
		name = def.name,
		title = def.title,
		color = def.color,
	})
end

local function wirePrompt(parent: Instance, entry: Placed, def: Npcs.NpcDef)
	local prompt = Interacts.prompt(parent, {
		name = NpcService.PROMPT_NAME,
		action = def.prompt or Npcs.TALK,
		object = def.name,
		interactId = NpcService.INTERACT_ID,
		distance = Npcs.TALK_RANGE,
	})
	prompt:SetAttribute("NpcId", def.id)
	prompt:AddTag(NpcService.PROMPT_TAG)
	prompt.Triggered:Connect(function(player: Player)
		local ok, err = pcall(function()
			talk(player, entry, def)
		end)
		if not ok then
			Deps.warnOnce("talk " .. def.id, err)
		end
	end)
end

local function place(spot: BasePart, def: Npcs.NpcDef)
	local entry: Placed = { id = def.id, spot = spot, model = nil, home = nil, faceSeq = 0 }
	local list = placed[def.id]
	if not list then
		list = {}
		placed[def.id] = list
	end
	table.insert(list, entry)
	local cf = standPoint(spot)
	local model = build(def, cf)
	if spot.Parent == nil then
		if model then
			model:Destroy()
		end
		return
	end
	if model then
		model.Name = def.id
		model:SetAttribute("NpcId", def.id)
		model:SetAttribute("DisplayName", def.name)
		model:SetAttribute("Title", def.title)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		hideDefaultName(model)
		nameTag(model, def.name, def.title, def.color)
		local root = rootOf(model)
		if root then
			root.Anchored = true
		end
		model.Parent = npcFolder()
		entry.model = model
		entry.home = model:GetPivot()
		byModel[model] = entry
		wirePrompt(root or spot, entry, def)
	else
		wirePrompt(spot, entry, def)
	end
	-- the spot going away (a removed venue or floor) takes its NPC with it
	spot.AncestryChanged:Connect(function()
		if spot:IsDescendantOf(workspace) then
			return
		end
		local m = entry.model
		if m then
			byModel[m] = nil
			m:Destroy()
		end
		entry.model = nil
		local l = placed[def.id]
		if l then
			local i = table.find(l, entry)
			if i then
				table.remove(l, i)
			end
		end
	end)
end

local function runQueue()
	if spawning then
		return
	end
	spawning = true
	task.spawn(function()
		while #spawnQueue > 0 do
			local job = table.remove(spawnQueue, 1) :: () -> ()
			local ok, err = pcall(function()
				job()
			end)
			if not ok then
				warn("[NpcService] spawning an NPC failed: " .. tostring(err))
			end
			task.wait(0.05)
		end
		spawning = false
	end)
end

local function onSpot(inst: Instance)
	local id = inst:GetAttribute("NpcId")
	if type(id) ~= "string" then
		return
	end
	local def = Npcs.get(id)
	if not def then
		if not warnedIds[id] then
			warnedIds[id] = true
			warn("[NpcService] no Config/Npcs entry for NpcId " .. id)
		end
		return
	end
	local spot: BasePart? = if inst:IsA("BasePart") then inst else nil
	if not spot then
		local p = Interacts.promptParent(inst)
		spot = if p and p:IsA("BasePart") then p else nil
	end
	if not spot then
		return
	end
	local s = spot :: BasePart
	table.insert(spawnQueue, function()
		place(s, def)
	end)
	runQueue()
end

---------------------------------------------------------------------------------------------------
-- Office staff (spawned by OfficeService)
---------------------------------------------------------------------------------------------------
local wiredOffice: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function companyName(id: string?): string
	local c = Companies.get(id)
	return if c then c.name else Quests.text("your_firm")
end

local function wireOfficeNpc(model: Model)
	if wiredOffice[model] then
		return
	end
	local role = model:GetAttribute("OfficeNpc")
	local def = if type(role) == "string" then Npcs.office[role] else nil
	if not def then
		return
	end
	local root = rootOf(model)
	if not root then
		return
	end
	wiredOffice[model] = true
	local attrCompany = model:GetAttribute("CompanyId")
	local companyId: string? = if type(attrCompany) == "string" and attrCompany ~= ""
		then attrCompany
		else Interacts.companyOf(model)
	local display = model:GetAttribute("DisplayName")
	local name = if type(display) == "string" and display ~= "" then display else Npcs.TALK
	local titleAttr = model:GetAttribute("Title")
	local title = if type(titleAttr) == "string" then titleAttr else ""
	local prompt = Interacts.prompt(root, {
		name = NpcService.PROMPT_NAME,
		action = Npcs.TALK,
		object = name,
		interactId = NpcService.INTERACT_ID,
		distance = Npcs.TALK_RANGE,
		companyId = companyId,
		employeesOnly = def.employeesOnly,
	})
	prompt:SetAttribute("OfficeRole", role)
	prompt:AddTag(NpcService.PROMPT_TAG)
	prompt.Triggered:Connect(function(player: Player)
		if not cooled(player) then
			return
		end
		local company = companyId or Interacts.companyOf(model)
		if def.employeesOnly and company and not Deps.isEmployeeOf(player, company) then
			Deps.notify(player, Quests.text("dialogue_employees_only", { name = name, company = companyName(company) }), "warn")
			return
		end
		Deps.call("DialogueService", "Open", player, "office_" .. tostring(role), def.dialogue, {
			model = model,
			origin = root.Position,
			name = name,
			title = title,
			companyId = company,
			office = true,
		})
	end)
end

local watchedFloors: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function watchFloor(floor: Instance)
	if typeof(floor) ~= "Instance" or watchedFloors[floor] then
		return
	end
	watchedFloors[floor] = true
	local function consider(inst: Instance)
		if inst:IsA("Model") and inst:GetAttribute("OfficeNpc") ~= nil then
			local ok, err = pcall(function()
				wireOfficeNpc(inst)
			end)
			if not ok then
				Deps.warnOnce("office npc", err)
			end
		end
	end
	floor.DescendantAdded:Connect(consider)
	for _, d in floor:GetDescendants() do
		consider(d)
	end
end

---------------------------------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------------------------------
function NpcService:GetDef(npcId: string): Npcs.NpcDef?
	return Npcs.get(npcId)
end

function NpcService:GetNpcModel(npcId: string): Model?
	local list = placed[npcId]
	if not list then
		return nil
	end
	for _, e in list do
		if e.model and e.model.Parent then
			return e.model
		end
	end
	return nil
end

function NpcService:GetNpcPosition(npcId: string): Vector3?
	local list = placed[npcId]
	if not list then
		return nil
	end
	for _, e in list do
		local m = e.model
		if m and m.Parent then
			local root = rootOf(m)
			if root then
				return root.Position
			end
		end
		if e.spot.Parent then
			return e.spot.Position
		end
	end
	return nil
end

function NpcService:FaceToward(model: Model?, position: Vector3?)
	if typeof(model) ~= "Instance" or typeof(position) ~= "Vector3" then
		return
	end
	local entry = byModel[model :: Model]
	if not entry or not entry.home then
		return
	end
	local def = Npcs.get(entry.id)
	if def and def.pose ~= nil and def.pose ~= "stand" and def.pose ~= "arms_crossed" then
		return -- seated or posed NPCs stay as they are
	end
	local m = model :: Model
	local home = entry.home :: CFrame
	local pos = home.Position
	local target = Vector3.new((position :: Vector3).X, pos.Y, (position :: Vector3).Z)
	if (target - pos).Magnitude < 0.5 then
		return
	end
	pcall(function()
		m:PivotTo(CFrame.lookAt(pos, target))
	end)
	entry.faceSeq += 1
	local mySeq = entry.faceSeq
	task.delay(FACE_RESET, function()
		if entry.faceSeq == mySeq and m.Parent then
			pcall(function()
				m:PivotTo(home)
			end)
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
function NpcService:Init() end

function NpcService:Start()
	Interacts.watch(NpcService.INTERACT_ID, onSpot)
	Deps.connect("OfficeService", "FloorCreated", function(_companyId: string, _floor: string, model: Instance)
		watchFloor(model)
	end)
	local ok, floors = Deps.call("OfficeService", "GetFloors")
	if ok and type(floors) == "table" then
		for _, f in floors do
			if type(f) == "table" and typeof(f.model) == "Instance" then
				watchFloor(f.model)
			end
		end
	end
end

return NpcService
