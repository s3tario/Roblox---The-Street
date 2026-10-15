--!strict
-- HUD toast stack (bottom-right, max 4 visible, newest at the bottom). Logic lives in Kit.ToastQueue;
-- this module turns its events into Kit.Toast instances with slide in/out.

local Kit = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))

local ToastQueue = Kit.ToastQueue

local Toasts = {}

export type Stack = {
	frame: Frame,
	push: (text: string, kind: string?, count: number?) -> boolean, -- true when a new toast appeared
	tick: (now: number) -> (),
	clear: () -> (),
	setOffsets: (right: number, bottom: number) -> (),
}

local WIDTH = 320
local SLIDE = WIDTH + 40

function Toasts.new(): Stack
	local frame = Kit.frame("Toasts", UDim2.new(0, WIDTH, 0.6, 0))
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -12, 1, -48)
	local layout = Kit.list(frame, false, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	local queue = ToastQueue.new({ maxVisible = 4, maxQueued = 8, duration = 4.5 })
	local live: { [number]: Kit.Toast } = {}

	local function apply(events: { Kit.ToastEvent })
		for _, ev in events do
			local item = ev.item
			if ev.type == "show" then
				local toast = Kit.Toast({
					text = item.text,
					kind = item.kind,
					count = item.count,
					name = "Toast" .. item.id,
					onClick = function()
						apply(ToastQueue.dismiss(queue, item.id, os.clock()))
					end,
				})
				toast.frame.LayoutOrder = item.id
				toast.inner.Position = UDim2.fromOffset(SLIDE, 0)
				toast.frame.Parent = frame
				live[item.id] = toast
				Kit.tween(toast.inner, 0.22, { Position = UDim2.fromOffset(0, 0) })
			elseif ev.type == "update" then
				local toast = live[item.id]
				if toast then
					toast.setCount(item.count)
				end
			elseif ev.type == "hide" then
				local toast = live[item.id]
				live[item.id] = nil
				if toast then
					if Kit.reducedMotion() then
						toast.frame:Destroy()
					else
						Kit.tween(toast.inner, 0.18, { Position = UDim2.fromOffset(SLIDE, 0) })
						task.delay(0.2, function()
							toast.frame:Destroy()
						end)
					end
				end
			end
		end
	end

	return {
		frame = frame,
		push = function(text: string, kind: string?, count: number?): boolean
			local events = ToastQueue.push(queue, text, kind, os.clock(), { count = count })
			apply(events)
			for _, ev in events do
				if ev.type == "show" then
					return true
				end
			end
			return false
		end,
		tick = function(now: number)
			apply(ToastQueue.tick(queue, now))
		end,
		clear = function()
			apply(ToastQueue.clear(queue))
		end,
		setOffsets = function(right: number, bottom: number)
			frame.Position = UDim2.new(1, -Kit.Core.px(right), 1, -Kit.Core.px(bottom))
		end,
	}
end

return Toasts
