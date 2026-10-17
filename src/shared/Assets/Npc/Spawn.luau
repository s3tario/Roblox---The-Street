--!strict
-- NpcRig.spawn (RUNTIME ONLY, server): builds a real Roblox R15 character with
-- Players:CreateHumanoidModelFromDescriptionAsync (skin colour, default blocky body parts, no clothing), adds
-- part-built hair welded to the head and dresses it with Wardrobe.apply. Not bake-safe: never require this
-- from a builder (Rig.luau requires it lazily inside NpcRig.spawn).
--
--   Spawn.spawn(opts) -> Model?   opts = NpcRig.build options plus
--       anchorRoot: boolean?      -- default true: the HumanoidRootPart is anchored (static stand-in)
--   Placement: opts.cframe is the floor point (or the seat top for pose "sit"); the model is pivoted so its
--   feet rest there. Falls back to NpcRig.build (anchored, part-built) if the description can't be loaded.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Wardrobe = require(script.Parent.Parent.Wardrobe)
local Body = require(script.Parent.Body)
local Hair = require(script.Parent.Hair)
local Rig = require(script.Parent.Rig)

local Spawn = {}

local function describe(skin: Color3, scale: number): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = skin
	desc.TorsoColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.LeftLegColor = skin
	desc.RightLegColor = skin
	desc.Head = 0
	desc.Torso = 0
	desc.LeftArm = 0
	desc.RightArm = 0
	desc.LeftLeg = 0
	desc.RightLeg = 0
	desc.Shirt = 0
	desc.Pants = 0
	desc.GraphicTShirt = 0
	desc.HeightScale = scale
	desc.WidthScale = scale
	desc.DepthScale = scale
	desc.HeadScale = scale
	desc.BodyTypeScale = 0
	desc.ProportionScale = 0
	return desc
end

local function applyPose(model: Model, pose: string)
	local rotations = Body.POSES[pose]
	if not rotations or pose == "stand" then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			local rot = rotations[d.Name]
			if rot then
				d.C0 = d.C0 * rot
			end
		end
	end
end

function Spawn.spawn(opts: Rig.BuildOpts): Model?
	assert(RunService:IsServer(), "NpcRig.spawn is server-only")
	local r = Rig.resolve(opts)
	local desc = describe(r.skin, r.scale)
	-- CreateHumanoidModelFromDescriptionAsync (current API), falling back to the older name
	local players: any = Players
	local ok, result = pcall(function()
		return players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok and string.find(tostring(result), "not a valid member", 1, true) then
		ok, result = pcall(function()
			return players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
	end
	desc:Destroy()
	if not ok or typeof(result) ~= "Instance" then
		warn("[NpcRig] CreateHumanoidModelFromDescription failed, using a part-built rig: " .. tostring(result))
		local fallback = table.clone(opts)
		fallback.anchored = true
		return Rig.build(fallback)
	end
	local model = result :: Model
	model.Name = r.name
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = model:FindFirstChild("Head") :: BasePart?
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.BreakJointsOnDeath = false
	end
	if head and r.hairColor and r.hairStyle ~= "none" then
		Hair.build(head, r.hairStyle, r.hairColor, {
			anchored = false,
			parent = model,
			hatted = r.equipped.head ~= nil,
		})
	end
	Wardrobe.apply(model, r.equipped, { anchored = false, skin = r.skin, glint = opts.glint })
	applyPose(model, r.pose)
	model:SetAttribute("NpcRig", true)
	model:SetAttribute("Pose", r.pose)
	if opts.preset then
		model:SetAttribute("Preset", opts.preset)
	end

	if root then
		root.Anchored = opts.anchorRoot ~= false
		model.PrimaryPart = root
		-- feet on the floor point (or thighs on the seat top for "sit")
		local hip = if hum then hum.HipHeight else 2 * r.scale
		local lift = hip + root.Size.Y / 2
		if r.pose == "sit" then
			local solved = Body.solve(Body.dims(r.scale), Body.POSES.sit)
			lift = solved.cframes.HumanoidRootPart.Position.Y - solved.seatHeight
		end
		local cf = opts.cframe or CFrame.new()
		model:PivotTo(cf * CFrame.new(0, lift, 0))
	end
	model.Parent = opts.parent or workspace
	return model
end

return Spawn
