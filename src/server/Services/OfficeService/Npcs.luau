--!strict
-- OfficeService/Npcs (server, runtime only): the people who make an office feel staffed.
--   lobby  a receptionist at OfficeAnchor "receptionist"
--   floor  the department boss at OfficeAnchor "boss_chair" (seated when the anchor is over a chair) and
--          4-8 ambient coworkers seated at free desks (DeskSlot chairs), 4 when the server is busy
-- Staff get a BillboardGui with name and title. Every NPC lives in the floor's "OfficeNpcs" folder, so it goes
-- away with the floor. Uses NpcRig.spawn (Shared/Assets/Npc/Rig), guarded: a missing or failing rig just
-- means an emptier office.
--
--   Npcs.populate(ctx)                       yields (NpcRig.spawn loads a HumanoidDescription per NPC)
--   Npcs.bossName(company, floor) -> string  the name shown on the boss (Config/Companies bossNames, else a
--                                            stable fictional name)

local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Hash = require(Shared.Util.Hash)
local Rng = require(Shared.Util.Rng)
local Palette = require(Shared.Build.Palette)
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)
local Text = require(Shared.Logic.DoorRules.Text)
local Template = require(script.Parent.Template)

local Npcs = {}

Npcs.FOLDER = "OfficeNpcs"

export type Ctx = {
	model: Model, -- the floor model, already in Workspace
	company: OfficeAlloc.Company,
	floor: string, -- "lobby" or a track id
	departmentName: string,
	bossTitle: string?, -- the track's top title (Config/Tracks), if known
	anchors: { [string]: BasePart },
	liveFloors: number,
	alive: () -> boolean,
}

type Run = Ctx & { folder: Folder, include: { Instance } }

local HAIR_STYLES = { "short", "side_part", "bun", "long", "curly", "buzz", "ponytail" }
local COWORKER_PRESETS: { [string]: { string } } = {
	ib = { "analyst", "associate", "banker", "vp", "intern", "analyst" },
	st = { "trader", "trader", "analyst", "associate" },
	default = { "analyst", "associate", "banker", "vp" },
}
local STAFF_PRESET = { receptionist = "receptionist", boss = "md" }

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
local rigModule: any = nil
local function rig(): any
	if rigModule == nil then
		local ok, m = pcall(function()
			return (require :: any)(Shared.Assets.Npc.Rig)
		end)
		if ok and type(m) == "table" and type(m.spawn) == "function" then
			rigModule = m
		else
			rigModule = false
			warn("[OfficeService] NpcRig unavailable, offices will have no NPCs: " .. tostring(m))
		end
	end
	return if rigModule then rigModule else nil
end

local stagingFolder: Folder? = nil
local function staging(): Folder
	local f = stagingFolder
	if f and f.Parent then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = "OfficeNpcStaging"
	created.Parent = ServerStorage
	stagingFolder = created
	return created
end

local function pickFrom<T>(list: { T }, ...: any): T
	return list[(Hash.u32(...) % #list) + 1]
end

local function flatRotation(cf: CFrame): CFrame
	local lv = cf.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	if flat.Magnitude < 1e-3 then
		return CFrame.identity
	end
	return CFrame.lookAt(Vector3.zero, flat.Unit)
end

local function raycastDown(from: Vector3, dist: number, include: { Instance }): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	params.IgnoreWater = true
	return workspace:Raycast(from, Vector3.new(0, -dist, 0), params)
end

-- Seat top under the hips, facing the way the chair faces.
local function seatPoint(seat: BasePart?, chair: Model?): CFrame?
	if seat then
		return CFrame.new((seat.CFrame * CFrame.new(0, seat.Size.Y / 2, 0)).Position) * flatRotation(seat.CFrame)
	end
	if chair then
		local root = chair.PrimaryPart or chair:FindFirstChild("Root")
		local base: CFrame = if root and root:IsA("BasePart") then root.CFrame else chair:GetPivot()
		local hit = raycastDown(base.Position + Vector3.new(0, 4, 0), 4.5, { chair })
		local top = if hit then hit.Position else (base * CFrame.new(0, 1.8, 0)).Position
		return CFrame.new(top) * flatRotation(base)
	end
	return nil
end

local function chairAncestor(inst: Instance, stop: Instance): Model?
	local node: Instance? = inst
	while node and node ~= stop do
		if node:IsA("Model") then
			local prop = node:GetAttribute("PropId")
			if
				(type(prop) == "string" and string.sub(prop, 1, 5) == "chair")
				or string.find(string.lower(node.Name), "chair", 1, true)
			then
				return node
			end
		end
		node = node.Parent
	end
	return nil
end

-- Where an NPC at this anchor goes: seated when the anchor is over a seat or chair, standing on the floor
-- otherwise. Returns (cframe, pose, seat?).
local function placeAt(run: Run, anchor: BasePart): (CFrame, string, BasePart?)
	local hit = raycastDown(anchor.Position + Vector3.new(0, 2, 0), 14, run.include)
	if hit then
		local inst = hit.Instance
		if inst:IsA("Seat") then
			return seatPoint(inst, nil) :: CFrame, "sit", inst
		end
		local chair = chairAncestor(inst, run.model)
		if chair then
			local seat, sub = Template.chairOf(chair)
			local cf = seatPoint(seat, sub or chair)
			if cf then
				return cf, "sit", seat
			end
		end
		return CFrame.new(hit.Position) * flatRotation(anchor.CFrame), "stand", nil
	end
	return CFrame.new(anchor.Position - Vector3.new(0, 3, 0)) * flatRotation(anchor.CFrame), "stand", nil
end

local function looks(seed: string): (Color3, Color3, string)
	return pickFrom(Palette.skin, seed, "skin"),
		pickFrom(Palette.hair, seed, "hair"),
		pickFrom(HAIR_STYLES, seed, "style")
end

local function nameTag(model: Model, name: string, title: string)
	local head = model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "OfficeNameTag"
	bb.Adornee = head
	bb.Size = UDim2.fromOffset(240, 52)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
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
	titleLabel.TextColor3 = Color3.fromRGB(233, 205, 128)
	titleLabel.TextStrokeTransparency = 0.55
	titleLabel.Parent = bb
	bb.Parent = head
end

-- Spawns one NPC in a staging folder and moves it into the floor only if the floor still exists.
local function spawnOne(run: Run, opts: { [string]: any }, role: string): Model?
	local NpcRig = rig()
	if not NpcRig then
		return nil
	end
	opts.parent = staging()
	local ok, model = pcall(NpcRig.spawn, opts)
	if not ok then
		warn(("[OfficeService] NPC spawn failed (%s): %s"):format(role, tostring(model)))
		return nil
	end
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return nil
	end
	if not run.alive() or run.folder.Parent == nil then
		model:Destroy()
		return nil
	end
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("OfficeNpc", role)
	model:SetAttribute("CompanyId", run.company.id)
	model:SetAttribute("Department", run.floor)
	model.Parent = run.folder
	return model
end

---------------------------------------------------------------------------------------------------
-- Staff and coworkers
---------------------------------------------------------------------------------------------------
function Npcs.bossName(company: OfficeAlloc.Company, floor: string): string
	local configured = company.bossNames[floor]
	if configured then
		return configured
	end
	return pickFrom(Text.bossNames, company.id, floor, "boss")
end

local function receptionistName(company: OfficeAlloc.Company): string
	return pickFrom(Text.receptionistNames, company.id, "reception")
end

local function spawnStaff(run: Run, anchor: BasePart, role: string, name: string, title: string)
	local cf, pose, seat = placeAt(run, anchor)
	local seed = run.company.id .. "/" .. run.floor .. "/" .. role
	local skin, hairColor, hairStyle = looks(seed)
	if seat and seat:IsA("Seat") then
		seat.Disabled = true
	end
	local model = spawnOne(run, {
		name = if role == "boss" then "Boss" else "Receptionist",
		preset = STAFF_PRESET[role],
		pose = pose,
		cframe = cf,
		skin = skin,
		hairColor = hairColor,
		hairStyle = if role == "boss" then "side_part" else hairStyle,
		seed = seed,
		companyLogo = run.company.logo,
		companyMonogram = run.company.short,
	}, role)
	if model then
		model:SetAttribute("DisplayName", name)
		model:SetAttribute("Title", title)
		nameTag(model, name, title)
	elseif seat and seat:IsA("Seat") then
		seat.Disabled = false
	end
end

local function standAtDesk(run: Run, desk: Instance): CFrame?
	if not desk:IsA("PVInstance") then
		return nil
	end
	local pivot = desk:GetPivot()
	local hit = raycastDown(pivot.Position + Vector3.new(0, 3, 0), 10, run.include)
	local pos = if hit then hit.Position else pivot.Position
	return CFrame.new(pos + pivot.LookVector * -2.5) * flatRotation(pivot)
end

local function coworkers(run: Run)
	local desks = Template.deskSlots(run.model)
	if #desks == 0 then
		return
	end
	local skip: { [number]: boolean } = {}
	for i, d in desks do
		if Template.isTaken(d) then
			skip[i] = true
		end
	end
	local rng = Rng.new(Hash.u32(run.company.id, run.floor, os.clock()))
	local n = OfficeAlloc.coworkerCount(rng, run.liveFloors)
	local presets = COWORKER_PRESETS[run.floor] or COWORKER_PRESETS.default
	for k, i in OfficeAlloc.pickDesks(#desks, n, rng, skip) do
		if not run.alive() then
			return
		end
		local desk = desks[i]
		if Template.isTaken(desk) then
			continue
		end
		local seat, chair = Template.chairOf(desk)
		if seat and seat:IsA("Seat") and seat.Occupant ~= nil then
			continue
		end
		local cf = seatPoint(seat, chair)
		local pose = "sit"
		if cf == nil then
			cf = standAtDesk(run, desk)
			pose = "stand"
		end
		if cf == nil then
			continue
		end
		if seat and seat:IsA("Seat") then
			seat.Disabled = true
		end
		local seed = run.company.id .. "/" .. run.floor .. "/desk" .. i .. "/" .. k .. "/" .. rng:int(0, 1e6)
		local skin, hairColor, hairStyle = looks(seed)
		local model = spawnOne(run, {
			name = "Coworker",
			preset = rng:pick(presets),
			pose = pose,
			cframe = cf,
			skin = skin,
			hairColor = hairColor,
			hairStyle = hairStyle,
			seed = seed,
			companyLogo = run.company.logo,
			companyMonogram = run.company.short,
		}, "coworker")
		if model then
			-- Give the desk back the moment another feature assigns it to a player.
			local conn: RBXScriptConnection? = nil
			conn = desk.AttributeChanged:Connect(function(attr: string)
				if table.find(Template.OWNER_ATTRS, attr) and Template.isTaken(desk) then
					if conn then
						conn:Disconnect()
					end
					model:Destroy()
					if seat and seat:IsA("Seat") then
						seat.Disabled = false
					end
				end
			end)
			model.Destroying:Connect(function()
				if conn then
					conn:Disconnect()
				end
			end)
		elseif seat and seat:IsA("Seat") then
			seat.Disabled = false
		end
		task.wait(0.05)
	end
end

function Npcs.populate(ctx: Ctx)
	if not rig() or not ctx.alive() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = Npcs.FOLDER
	folder.Parent = ctx.model
	local include: { Instance } = {}
	for _, c in ctx.model:GetChildren() do
		if c ~= folder then
			table.insert(include, c)
		end
	end
	local run: Run = table.clone(ctx) :: any
	run.folder = folder
	run.include = include

	if ctx.floor == OfficeAlloc.LOBBY then
		local anchor = ctx.anchors.receptionist
		if anchor then
			spawnStaff(run, anchor, "receptionist", receptionistName(ctx.company), Text.get("receptionist_title"))
		end
		return
	end
	local bossAnchor = ctx.anchors.boss_chair
	if bossAnchor then
		local title = Text.format("boss_title", {
			title = ctx.bossTitle or Text.get("boss_title_default"),
			department = ctx.departmentName,
		})
		spawnStaff(run, bossAnchor, "boss", Npcs.bossName(ctx.company, ctx.floor), title)
	end
	coworkers(run)
end

return Npcs
