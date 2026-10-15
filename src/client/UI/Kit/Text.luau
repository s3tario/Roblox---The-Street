--!strict
-- Text components: Label, Heading, Badge, Countdown.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Time = require(Shared.Util.Time)
local Core = require(script.Parent.Core)

type ColorSpec = Core.ColorSpec

local Text = {}

---------------------------------------------------------------------------------------------------
-- Label
---------------------------------------------------------------------------------------------------
export type LabelOpts = {
	text: string?,
	size: (string | number)?, -- text size token ("xs".."xxl") or px; default "md"
	font: string?, -- font token; default "body"
	color: ColorSpec?, -- colour token or Color3; default "text"
	align: ("left" | "center" | "right")?,
	wrap: boolean?, -- default true
	rich: boolean?,
	autoSize: ("x" | "y" | "xy" | "none")?, -- default "y" (full width, grows in height)
	width: UDim?, -- width when autoSize is "y" or "none" (default full width)
	height: number?, -- height when autoSize is "x" or "none"
	transparency: number?,
	name: string?,
	layoutOrder: number?,
}
export type Label = {
	frame: TextLabel,
	setText: (text: string) -> (),
	setColor: (color: ColorSpec) -> (),
}

local ALIGN = {
	left = Enum.TextXAlignment.Left,
	center = Enum.TextXAlignment.Center,
	right = Enum.TextXAlignment.Right,
}

function Text.Label(opts: LabelOpts?): Label
	local o: LabelOpts = opts or {}
	local color: ColorSpec = o.color or "text"
	local l = Instance.new("TextLabel")
	l.Name = o.name or "Label"
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Text = o.text or ""
	l.RichText = o.rich == true
	l.TextWrapped = o.wrap ~= false
	l.TextXAlignment = ALIGN[o.align or "left"] or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextTransparency = o.transparency or 0
	l.LayoutOrder = o.layoutOrder or 0
	local auto = o.autoSize or "y"
	local width = o.width or UDim.new(1, 0)
	if auto == "xy" then
		l.AutomaticSize = Enum.AutomaticSize.XY
		l.Size = UDim2.fromOffset(0, 0)
		l.TextWrapped = false
	elseif auto == "x" then
		l.AutomaticSize = Enum.AutomaticSize.X
		l.Size = UDim2.new(0, 0, 0, o.height or 24)
		l.TextWrapped = false
	elseif auto == "none" then
		l.AutomaticSize = Enum.AutomaticSize.None
		l.Size = UDim2.new(width.Scale, width.Offset, 0, o.height or 24)
		l.TextWrapped = o.wrap == true
		l.TextTruncate = Enum.TextTruncate.AtEnd
	else
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Size = UDim2.new(width.Scale, width.Offset, 0, 0)
	end
	Core.themed(l, function(t)
		l.FontFace = Core.font(t, o.font)
		l.TextSize = Core.textSize(t, o.size)
		l.TextColor3 = Core.color(t, color)
	end)
	return {
		frame = l,
		setText = function(s: string)
			l.Text = s
		end,
		setColor = function(c: ColorSpec)
			color = c
			l.TextColor3 = Core.color(Core.Theme.get(), c)
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- Heading
---------------------------------------------------------------------------------------------------
export type HeadingOpts = {
	text: string?,
	level: number?, -- 1 (display, xxl), 2 (heading, xl), 3 (heading, lg); default 2
	color: ColorSpec?,
	align: ("left" | "center" | "right")?,
	autoSize: ("x" | "y" | "xy" | "none")?,
	name: string?,
	layoutOrder: number?,
}

function Text.Heading(opts: HeadingOpts?): Label
	local o: HeadingOpts = opts or {}
	local level = math.clamp(o.level or 2, 1, 3)
	return Text.Label({
		text = o.text,
		size = if level == 1 then "xxl" elseif level == 2 then "xl" else "lg",
		font = if level == 1 then "display" else "heading",
		color = o.color or "text",
		align = o.align,
		autoSize = o.autoSize,
		name = o.name or "Heading",
		layoutOrder = o.layoutOrder,
	})
end

---------------------------------------------------------------------------------------------------
-- Badge (pill)
---------------------------------------------------------------------------------------------------
export type BadgeOpts = {
	text: string?,
	color: ColorSpec?, -- background; default "accent"
	textColor: ColorSpec?, -- default: readable contrast colour
	size: (string | number)?, -- text size; default "xs"
	name: string?,
	layoutOrder: number?,
}
export type Badge = {
	frame: Frame,
	label: TextLabel,
	setText: (text: string) -> (),
	setColor: (color: ColorSpec) -> (),
}

function Text.Badge(opts: BadgeOpts?): Badge
	local o: BadgeOpts = opts or {}
	local color: ColorSpec = o.color or "accent"
	local f = Instance.new("Frame")
	f.Name = o.name or "Badge"
	f.BorderSizePixel = 0
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.Size = UDim2.fromOffset(0, 0)
	f.LayoutOrder = o.layoutOrder or 0
	local corner = Core.corner(f, 999)
	Core.padding(f, 8, 3)
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.BackgroundTransparency = 1
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.fromOffset(0, 0)
	l.Text = o.text or ""
	l.Parent = f
	Core.themed(f, function(t)
		local bg = Core.color(t, color, "accent")
		f.BackgroundColor3 = bg
		corner.CornerRadius = UDim.new(0, 999)
		l.FontFace = t.fonts.bodyBold
		l.TextSize = Core.textSize(t, o.size, "xs")
		l.TextColor3 = if o.textColor then Core.color(t, o.textColor) else Core.Theme.contrastText(bg)
	end)
	return {
		frame = f,
		label = l,
		setText = function(s: string)
			l.Text = s
		end,
		setColor = function(c: ColorSpec)
			color = c
			local t = Core.Theme.get()
			local bg = Core.color(t, c, "accent")
			f.BackgroundColor3 = bg
			l.TextColor3 = if o.textColor then Core.color(t, o.textColor) else Core.Theme.contrastText(bg)
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- Countdown
---------------------------------------------------------------------------------------------------
export type CountdownOpts = {
	endsAt: number?, -- absolute synced time (Shared/Util/Time.now() clock)
	seconds: number?, -- alternative: seconds from now
	prefix: string?, -- e.g. "Ends in"
	format: ("clock" | "duration")?, -- default "clock" (4:05)
	doneText: string?,
	onDone: (() -> ())?,
	size: (string | number)?,
	color: ColorSpec?,
	font: string?, -- default "mono"
	now: (() -> number)?, -- clock override (tests)
	name: string?,
	layoutOrder: number?,
}
export type Countdown = {
	frame: TextLabel,
	set: (endsAt: number?) -> (),
	remaining: () -> number,
	stop: () -> (),
}

function Text.Countdown(opts: CountdownOpts?): Countdown
	local o: CountdownOpts = opts or {}
	local clock = o.now or Time.now
	local endsAt: number? = o.endsAt or (if o.seconds then clock() + o.seconds else nil)
	local fired = false
	local label = Text.Label({
		text = "",
		size = o.size or "md",
		font = o.font or "mono",
		color = o.color or "text",
		autoSize = "xy",
		name = o.name or "Countdown",
		layoutOrder = o.layoutOrder,
	})

	local function remaining(): number
		if endsAt == nil then
			return 0
		end
		return math.max(0, (endsAt :: number) - clock())
	end

	local function render()
		local left = remaining()
		local body
		if endsAt == nil then
			body = "--:--"
		elseif left <= 0 and o.doneText then
			body = o.doneText
		elseif o.format == "duration" then
			body = Format.duration(left)
		else
			body = Format.clock(left)
		end
		label.frame.Text = if o.prefix and not (left <= 0 and o.doneText) then o.prefix .. " " .. body else body
		if endsAt ~= nil and left <= 0 and not fired then
			fired = true
			if o.onDone then
				task.spawn(o.onDone)
			end
		end
	end

	render()
	local stopTicker = Core.everySecond(render)
	Core.onDestroy(label.frame, stopTicker)

	return {
		frame = label.frame,
		set = function(newEndsAt: number?)
			endsAt = newEndsAt
			fired = false
			render()
		end,
		remaining = remaining,
		stop = stopTicker,
	}
end

return Text
