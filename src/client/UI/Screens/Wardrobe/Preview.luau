--!strict
-- Wardrobe screen: live 3D preview. A ViewportFrame shows an NpcRig (the player's skin tone) wearing the
-- look being browsed; drag (mouse or touch) turns it. Builds only bake-safe instances, so it also constructs
-- under Lune; input wiring is skipped there.
--
--   Preview.new(opts) -> Preview
--     opts = { name: string?, skin: Color3?, hairStyle: string?, hairColor: Color3?, hint: string? }
--   preview.frame                 root Frame (parent it yourself; fills its parent)
--   preview.set(equipped)         rebuild the figure in this look (coalesced to one rebuild per frame)
--   preview.reset()               face the camera again
--   preview.destroy()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local NpcRig = require(Shared.Assets.Npc.Rig)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))

local Preview = {}

export type Opts = {
	name: string?,
	skin: Color3?,
	hairStyle: string?,
	hairColor: Color3?,
	hint: string?,
}
export type Preview = {
	frame: Frame,
	viewport: ViewportFrame,
	set: (equipped: { [string]: string }) -> (),
	reset: () -> (),
	destroy: () -> (),
	rig: () -> Model?,
}

local FOCUS = Vector3.new(0, 2.65, 0) -- chest height of a standing rig (feet at y = 0)
local DISTANCE = 13
local PITCH = math.rad(6)
local START_YAW = math.rad(-18)

function Preview.new(opts: Opts?): Preview
	local o: Opts = opts or {}
	local root = Kit.frame("Preview", UDim2.fromScale(1, 1))

	local card = Instance.new("Frame")
	card.Name = "Stage"
	card.BorderSizePixel = 0
	card.Size = UDim2.fromScale(1, 1)
	card.Parent = root
	Kit.corner(card)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = card
	Kit.themed(card, function(t)
		card.BackgroundColor3 = t.colors.surface
		gradient.Color = ColorSequence.new(Kit.shade(t.colors.surface, 0.12), Kit.shade(t.colors.panel, -0.1))
	end)

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(165, 165, 170)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(0.35, -1, 0.55)
	viewport.Active = true
	viewport.Parent = card

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- floor disc so the figure stands on something
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(0.1, 3.4, 3.4)
	floor.CFrame = CFrame.new(0, -0.05, 0) * CFrame.Angles(0, 0, math.rad(90))
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = Color3.fromRGB(40, 44, 52)
	floor.Parent = viewport

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
	hint.frame.Parent = card

	local yaw = START_YAW
	local function aim()
		local offset = Vector3.new(math.sin(yaw) * DISTANCE, math.sin(PITCH) * DISTANCE, -math.cos(yaw) * DISTANCE)
		camera.CFrame = CFrame.lookAt(FOCUS + offset, FOCUS)
	end
	aim()

	local current: Model? = nil
	local pending: { [string]: string }? = nil
	local scheduled = false
	local dead = false

	local function rebuild()
		scheduled = false
		local look = pending
		pending = nil
		if dead or not look then
			return
		end
		local ok, model = pcall(function()
			return NpcRig.build({
				name = o.name or "Preview",
				skin = o.skin,
				hairStyle = o.hairStyle,
				hairColor = o.hairColor,
				equipped = look,
				humanoid = false,
				anchored = true,
				glint = true,
			})
		end)
		if not ok then
			warn("[Wardrobe] preview failed: " .. tostring(model))
			return
		end
		if current then
			current:Destroy()
		end
		current = model
		model.Parent = viewport
	end

	local function set(equipped: { [string]: string })
		pending = equipped
		if scheduled then
			return
		end
		scheduled = true
		if Kit.Core.LIVE then
			task.defer(rebuild)
		else
			rebuild()
		end
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
			local moving = (d.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
				or (d.UserInputType == Enum.UserInputType.Touch and input == d)
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

	local function destroy()
		if dead then
			return
		end
		dead = true
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		if current then
			current:Destroy()
			current = nil
		end
		root:Destroy()
	end
	Kit.onDestroy(root, function()
		dead = true
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
	end)

	return {
		frame = root,
		viewport = viewport,
		set = set,
		reset = function()
			yaw = START_YAW
			aim()
		end,
		destroy = destroy,
		rig = function()
			return current
		end,
	}
end

return Preview
