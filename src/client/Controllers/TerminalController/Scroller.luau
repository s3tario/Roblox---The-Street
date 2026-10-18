--!strict
-- TerminalController: scrolls the LED ticker bands (RUNTIME ONLY, client).
-- MarketService rewrites every "TickerText" label on "TickerBand" / "TickerDisplay" faces each tick with live quotes,
-- repeated TickerReps times so one copy can wrap seamlessly. Here each label slides left at SPEED canvas px/s and
-- wraps every TextBounds.X / TickerReps px. Segmented wide bands keep their segments aligned through the builder's
-- BaseOffsetPx attribute (Assets/Signs tickerBand: Position.X = BaseOffsetPx - scroll). Streaming-safe: faces are
-- tracked through their replicated tags as they stream in and out. Only bands within NEAR studs of the camera move,
-- and nothing moves with Reduced Motion on.
--
--   Scroller.start(reducedMotion: () -> boolean) -> { refresh: () -> () }

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Scroller = {}

Scroller.TAGS = { "TickerBand", "TickerDisplay" }
Scroller.LABEL = "TickerText"
Scroller.SPEED = 45 -- canvas px per second
Scroller.NEAR = 220 -- studs
Scroller.CHECK_EVERY = 1 -- seconds between distance checks

type Entry = { label: TextLabel, part: BasePart?, base: number, near: boolean }

function Scroller.start(reducedMotion: () -> boolean): { refresh: () -> () }
	local entries: { [TextLabel]: Entry } = {}
	local faces: { [Instance]: RBXScriptConnection } = {}
	local offset = 0
	local sinceCheck = math.huge
	local paused = false

	local function track(inst: Instance)
		if not inst:IsA("TextLabel") or inst.Name ~= Scroller.LABEL or entries[inst] then
			return
		end
		local base = inst:GetAttribute("BaseOffsetPx")
		entries[inst] = {
			label = inst,
			part = inst:FindFirstAncestorWhichIsA("BasePart"),
			base = if type(base) == "number" then base else inst.Position.X.Offset,
			near = false,
		}
	end

	local function watch(face: Instance)
		if faces[face] then
			return
		end
		faces[face] = face.DescendantAdded:Connect(track)
		for _, d in face:GetDescendants() do
			track(d)
		end
	end

	local function unwatch(face: Instance)
		local conn = faces[face]
		if conn then
			faces[face] = nil
			conn:Disconnect()
		end
		for label in entries do
			if label:IsDescendantOf(face) or label.Parent == nil then
				entries[label] = nil
			end
		end
	end

	local function reset()
		for label, e in entries do
			if label.Parent then
				label.Position = UDim2.new(0, e.base, label.Position.Y.Scale, label.Position.Y.Offset)
			end
		end
	end

	local function checkDistance()
		local cam = workspace.CurrentCamera
		local at = if cam then cam.CFrame.Position else nil
		for label, e in entries do
			if label.Parent == nil then
				entries[label] = nil
			else
				local part = e.part
				e.near = at ~= nil and part ~= nil and (part.Position - at).Magnitude <= Scroller.NEAR
			end
		end
	end

	for _, tag in Scroller.TAGS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(unwatch)
		for _, inst in CollectionService:GetTagged(tag) do
			watch(inst)
		end
	end

	RunService.Heartbeat:Connect(function(dt: number)
		local off = reducedMotion()
		if off then
			if not paused then
				paused = true
				reset()
			end
			return
		end
		paused = false
		sinceCheck += dt
		if sinceCheck >= Scroller.CHECK_EVERY then
			sinceCheck = 0
			checkDistance()
		end
		offset += Scroller.SPEED * dt
		if offset > 1e7 then
			offset = 0
		end
		for label, e in entries do
			if e.near then
				local reps = label:GetAttribute("TickerReps")
				local n = if type(reps) == "number" and reps >= 1 then reps else 1
				local period = label.TextBounds.X / n
				if period > 1 then
					local x = e.base - (offset % period)
					local pos = label.Position
					label.Position = UDim2.new(0, math.floor(x + 0.5), pos.Y.Scale, pos.Y.Offset)
				end
			end
		end
	end)

	return {
		refresh = function()
			sinceCheck = math.huge
		end,
	}
end

return Scroller
