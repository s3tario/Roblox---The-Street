--!strict
-- Shop screen: the 3D preview. A ViewportFrame shows either a figure (Assets/Npc NpcRig in the player's skin tone)
-- wearing the current look with the selected piece swapped in, or a decor piece built with Props.build and framed
-- by its footprint. Drag (mouse or touch) turns it. Builds only bake-safe instances, so it also constructs under
-- Lune; input wiring is skipped there.
--
--   Preview.new(opts?) -> Preview      opts = { name?, skin?: Color3, hint? }
--   preview.frame                      root Frame (fills its parent)
--   preview.showWearable(look, focusSlot?, logoId?)   the figure in `look`; the camera favours focusSlot
--   preview.showDecor(item)            a Config/Decor item on a plinth
--   preview.clear()                    empty stage
--   preview.destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local NpcRig = require(Shared.Assets.Npc.Rig)
local Props = require(Shared.Assets.Props)
local Decor = require(Shared.Config.Decor)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))

local Preview = {}

export type Opts = { name: string?, skin: Color3?, hint: string? }
export type Preview = {
	frame: Frame,
	viewport: ViewportFrame,
	showWearable: (look: { [string]: string }, focusSlot: string?, logoId: string?) -> (),
	showDecor: (item: Decor.Item) -> (),
	clear: () -> (),
	destroy: () -> (),
	current: () -> Model?,
}

type Frame3 = { focus: Vector3, distance: number }

local FOV = 30
local PITCH = math.rad(8)
local START_YAW = math.rad(-22)

-- Camera framing per wearable slot (a standing rig, feet at y = 0).
local SLOT_FRAMES: { [string]: Frame3 } = {
	shoes = { focus = Vector3.new(0, 0.7, 0), distance = 7 },
	head = { focus = Vector3.new(0, 4.5, 0), distance = 6.5 },
	eyes = { focus = Vector3.new(0, 4.5, 0), distance = 5.5 },
	wrist = { focus = Vector3.new(0, 2.4, 0), distance = 8.5 },
	neck = { focus = Vector3.new(0, 3.5, 0), distance = 8 },
}
local FIGURE: Frame3 = { focus = Vector3.new(0, 2.65, 0), distance = 13 }

function Preview.new(opts: Opts?): Preview
	local o: Opts = opts or {}
	local root = Kit.frame("Preview", UDim2.fromScale(1, 1))

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BorderSizePixel = 0
	stage.Size = UDim2.fromScale(1, 1)
	stage.ClipsDescendants = true
	stage.Parent = root
	Kit.corner(stage)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = stage
	Kit.themed(stage, function(t)
		stage.BackgroundColor3 = t.colors.surface
		gradient.Color = ColorSequence.new(Kit.shade(t.colors.surface, 0.12), Kit.shade(t.colors.panel, -0.1))
	end)

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(165, 165, 172)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(0.35, -1, 0.55)
	viewport.Active = true
	viewport.Parent = stage

	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local plinth = Instance.new("Part")
	plinth.Name = "Plinth"
	plinth.Anchored = true
	plinth.Shape = Enum.PartType.Cylinder
	plinth.Size = Vector3.new(0.1, 3.6, 3.6)
	plinth.CFrame = CFrame.new(0, -0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
	plinth.Material = Enum.Material.SmoothPlastic
	plinth.Color = Color3.fromRGB(40, 44, 52)
	plinth.Parent = viewport

	local hint = Kit.Label({
		text = o.hint or "",
		size = "xs",
		color = "textDim",
		align = "center",
		autoSize = "none",
		height = 18,
		name = "Hint",
	})
	hint.frame.AnchorPoint = Vector2.new(0.5, 1)
	hint.frame.Position = UDim2.new(0.5, 0, 1, -6)
	hint.frame.Size = UDim2.new(1, -12, 0, 18)
	hint.frame.Visible = (o.hint or "") ~= ""
	hint.frame.Parent = stage

	local yaw = START_YAW
	local framing: Frame3 = FIGURE
	local function aim()
		local d = framing.distance
		local offset = Vector3.new(math.sin(yaw) * d, math.sin(PITCH) * d, -math.cos(yaw) * d)
		camera.CFrame = CFrame.lookAt(framing.focus + offset, framing.focus)
	end
	aim()

	local current: Model? = nil
	local dead = false

	local function setModel(model: Model?)
		if current then
			current:Destroy()
		end
		current = model
		if model then
			model.Parent = viewport
		end
	end

	local function showWearable(look: { [string]: string }, focusSlot: string?, logoId: string?)
		if dead then
			return
		end
		local ok, model = pcall(function()
			return NpcRig.build({
				name = o.name or "Preview",
				skin = o.skin,
				equipped = look,
				humanoid = false,
				anchored = true,
				glint = true,
				companyLogo = logoId,
			})
		end)
		if not ok then
			warn("[Shop] preview failed: " .. tostring(model))
			setModel(nil)
			return
		end
		plinth.Size = Vector3.new(0.1, 3.6, 3.6)
		setModel(model)
		framing = if focusSlot and SLOT_FRAMES[focusSlot] then SLOT_FRAMES[focusSlot] else FIGURE
		yaw = START_YAW
		aim()
	end

	local function showDecor(item: Decor.Item)
		if dead then
			return
		end
		local info = Props.get(item.prop)
		local opts: { [string]: any } = if item.opts then table.clone(item.opts) else {}
		opts.seed = opts.seed or item.id
		local model = Props.tryBuild(item.prop, nil, CFrame.identity, opts)
		if not model or not info then
			setModel(nil)
			return
		end
		local fp = info.footprint
		local off = info.offset or Vector3.zero
		-- wall pieces hang forward of their back face; everything else stands on its contact point
		local center = if info.mount == "wall"
			then Vector3.new(off.X, fp.Y / 2, -fp.Z / 2)
			else Vector3.new(off.X, fp.Y / 2, off.Z)
		local radius = math.max(0.4, fp.Magnitude / 2)
		local distance = radius / math.tan(math.rad(FOV / 2)) * 1.12
		local base = math.max(fp.X, fp.Z) + 0.6
		plinth.Size = Vector3.new(0.1, base, base)
		setModel(model)
		framing = { focus = center, distance = distance }
		yaw = START_YAW
		aim()
	end

	-- Drag to turn: started on the viewport, tracked anywhere until release.
	local dragging: InputObject? = nil
	local lastX = 0
	local conns: { RBXScriptConnection } = {}
	local function track(c: RBXScriptConnection?)
		if c then
			table.insert(conns, c)
		end
	end
	track(Kit.connect(viewport, "InputBegan", function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = input
			lastX = input.Position.X
		end
	end))
	if Kit.Core.LIVE then
		local UserInputService = game:GetService("UserInputService")
		track(UserInputService.InputChanged:Connect(function(input: InputObject)
			local d = dragging
			if not d then
				return
			end
			local moving = (
				d.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseMovement
			) or (d.UserInputType == Enum.UserInputType.Touch and input == d)
			if moving then
				local x = input.Position.X
				yaw -= (x - lastX) * 0.012
				lastX = x
				aim()
			end
		end))
		track(UserInputService.InputEnded:Connect(function(input: InputObject)
			if input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = nil
			end
		end))
	end

	local function disconnect()
		dead = true
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
	end
	Kit.onDestroy(root, disconnect)

	return {
		frame = root,
		viewport = viewport,
		showWearable = showWearable,
		showDecor = showDecor,
		clear = function()
			setModel(nil)
		end,
		destroy = function()
			if not dead then
				disconnect()
			end
			setModel(nil)
			root:Destroy()
		end,
		current = function()
			return current
		end,
	}
end

return Preview
