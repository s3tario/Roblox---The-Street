--!strict
-- CareerParts/Cinematic (client, runtime only): the review meeting's camera move (design v3 §6). Eases the camera
-- to frame the boss NPC at OfficeAnchor boss_chair, from the side of the review spot, and freezes the character's
-- controls while the meeting plays. Everything is restored on stop(), whatever happened in between.
--   Cinematic.start(cameraInfo?, reducedMotion?) -> Handle    Handle = { framed: boolean, stop: () -> () }
--       cameraInfo = payload.camera: { bossModel?, bossCFrame?, headPosition?, spotCFrame? }
-- framed = false when there is nothing to look at (phone call, or the boss isn't on this client); the screen then
-- shows a portrait panel instead.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Cinematic = {}

export type Handle = { framed: boolean, stop: () -> () }

local EASE = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local BACK = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local DISTANCE = 6.5
local SIDE = 2.4
local FOV = 45

local function controls(): any
	local player = Players.LocalPlayer
	local scripts = player:FindFirstChildOfClass("PlayerScripts")
	local mod = if scripts then scripts:FindFirstChild("PlayerModule") else nil
	if not mod or not mod:IsA("ModuleScript") then
		return nil
	end
	local ok, pm = pcall(require, mod)
	if not ok or type(pm) ~= "table" or type((pm :: any).GetControls) ~= "function" then
		return nil
	end
	local okControls, c = pcall(function()
		return (pm :: any):GetControls()
	end)
	return if okControls then c else nil
end

local function setControls(enabled: boolean)
	local c = controls()
	if c then
		pcall(function()
			if enabled then
				c:Enable()
			else
				c:Disable()
			end
		end)
	end
end

local function flat(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return nil
	end
	return f.Unit
end

-- Where the camera sits: in front of the boss, toward the review spot, a little to the side.
local function framing(info: { [string]: any }): (CFrame?, Vector3?)
	local focus: Vector3? = nil
	local facing: CFrame? = nil
	local model = info.bossModel
	if typeof(model) == "Instance" and model:IsA("Model") and model:IsDescendantOf(workspace) then
		local head = model:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			focus = head.Position
		end
		local ok, pivot = pcall(function()
			return model:GetPivot()
		end)
		if ok then
			facing = pivot
		end
	end
	if not focus and typeof(info.headPosition) == "Vector3" then
		focus = info.headPosition
	end
	if typeof(info.bossCFrame) == "CFrame" then
		local cf = info.bossCFrame :: CFrame
		facing = facing or cf
		focus = focus or (cf.Position + Vector3.new(0, 1.6, 0))
	end
	if not focus or not facing then
		return nil, nil
	end
	local f = focus :: Vector3
	local dir = flat((facing :: CFrame).LookVector)
	if typeof(info.spotCFrame) == "CFrame" then
		dir = flat((info.spotCFrame :: CFrame).Position - f) or dir
	end
	if not dir then
		return nil, nil
	end
	local d = dir :: Vector3
	local side = d:Cross(Vector3.yAxis)
	local pos = f + d * DISTANCE + side * SIDE + Vector3.new(0, 0.35, 0)
	return CFrame.lookAt(pos, f - Vector3.new(0, 0.15, 0)), f
end

function Cinematic.start(cameraInfo: any, reducedMotion: boolean?): Handle
	local camera = workspace.CurrentCamera
	local info = if type(cameraInfo) == "table" then cameraInfo else {}
	local target = if camera then framing(info) else nil
	setControls(false)
	if not camera or not target then
		local stopped = false
		return {
			framed = false,
			stop = function()
				if not stopped then
					stopped = true
					setControls(true)
				end
			end,
		}
	end
	local cam = camera :: Camera
	local savedType = cam.CameraType
	local savedFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	local tween: Tween? = nil
	if reducedMotion then
		cam.CFrame = target
		cam.FieldOfView = FOV
	else
		local t = TweenService:Create(cam, EASE, { CFrame = target, FieldOfView = FOV })
		t:Play()
		tween = t
	end
	local stopped = false
	return {
		framed = true,
		stop = function()
			if stopped then
				return
			end
			stopped = true
			if tween then
				tween:Cancel()
			end
			if cam.Parent then
				if reducedMotion then
					cam.FieldOfView = savedFov
				else
					TweenService:Create(cam, BACK, { FieldOfView = savedFov }):Play()
				end
				cam.CameraType = if savedType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else savedType
			end
			setControls(true)
		end,
	}
end

return Cinematic
