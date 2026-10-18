--!strict
-- LifeRollParts/Reel: one slot-machine reel (client UI, careerCore). It scrolls fast through filler values,
-- decelerates and lands on the SERVER's result, then flashes the rarity colour; Mythic gets a prismatic text,
-- border and burst. Under Lune (and with reduced motion) it lands instantly.
--
--   local reel = Reel.new({ name?, height? })
--   reel.frame.Parent = row
--   reel.spin(final, filler, duration, onLanded?)   final/filler = { text, rarity? }
--   reel.set(final)                                 show a value without spinning
--   reel.isSpinning() -> boolean
--   reel.skip()                                     land now (onLanded still runs once)
--   reel.destroy()

local Common = require(script.Parent.Common)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))

export type Entry = { text: string, rarity: string? }
export type Reel = {
	frame: Frame,
	spin: (final: Entry, filler: { Entry }, duration: number, onLanded: (() -> ())?) -> (),
	set: (final: Entry) -> (),
	isSpinning: () -> boolean,
	skip: () -> (),
	destroy: () -> (),
}

local Reel = {}

local DEFAULT_H = 40

type Opts = { name: string?, height: number? }

function Reel.new(opts: Opts?): Reel
	local o: Opts = opts or {}
	local h = o.height or DEFAULT_H

	local frame = Instance.new("Frame")
	frame.Name = o.name or "Reel"
	frame.Size = UDim2.new(1, 0, 0, h)
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	local corner = Kit.corner(frame)
	local stroke = Kit.stroke(frame)

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel = 0
	strip.Size = UDim2.new(1, 0, 0, h)
	strip.Parent = frame

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BorderSizePixel = 0
	flash.BackgroundTransparency = 1
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 3
	flash.Parent = frame

	Kit.themed(frame, function(t)
		frame.BackgroundColor3 = t.colors.surface
		corner.CornerRadius = UDim.new(0, t.radiusSm)
		stroke.Color = t.colors.border
		stroke.Thickness = t.stroke
	end)

	local spinning = false
	local cancelAnim: () -> () = function() end
	local cleanups: { () -> () } = {}
	local landedCb: (() -> ())? = nil
	local finalEntry: Entry? = nil
	local labels: { TextLabel } = {}

	local function clearFx()
		for _, c in cleanups do
			pcall(c)
		end
		table.clear(cleanups)
		stroke.Thickness = Kit.Theme.get().stroke
		stroke.Color = Kit.Theme.get().colors.border
	end

	local function makeLabel(entry: Entry, index: number, final: boolean): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = if final then "Final" else "Filler"
		l.BackgroundTransparency = 1
		l.BorderSizePixel = 0
		l.Size = UDim2.new(1, -16, 0, h)
		l.Position = UDim2.fromOffset(8, (index - 1) * h)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Text = entry.text
		l.ZIndex = 2
		Kit.themed(l, function(t)
			l.FontFace = if final then t.fonts.bodyBold else t.fonts.body
			l.TextSize = t.text.md
			l.TextColor3 = if final then t.colors.text else t.colors.textDim
		end)
		l.Parent = strip
		return l
	end

	local function build(entries: { Entry })
		for _, l in labels do
			l:Destroy()
		end
		table.clear(labels)
		for i, e in entries do
			table.insert(labels, makeLabel(e, i, i == #entries))
		end
		strip.Size = UDim2.new(1, 0, 0, #entries * h)
		strip.Position = UDim2.fromOffset(0, 0)
	end

	local function burst()
		local b = Instance.new("Frame")
		b.Name = "Burst"
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(0.5, 0.5)
		b.Size = UDim2.fromOffset(0, 0)
		b.BorderSizePixel = 0
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BackgroundTransparency = 0.25
		b.ZIndex = 1
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = b
		local stop = Common.prismatic(b, 240)
		b.Parent = frame
		Common.animate(0.8, function(a: number)
			local size = math.floor(a * 520)
			b.Size = UDim2.fromOffset(size, size)
			b.BackgroundTransparency = 0.25 + 0.75 * a
		end, function()
			stop()
			b:Destroy()
		end)
	end

	local function land()
		spinning = false
		local entry = finalEntry
		local top = labels[#labels]
		if top then
			strip.Position = UDim2.fromOffset(0, -(#labels - 1) * h)
		end
		if entry and top then
			local rarity = entry.rarity
			if rarity and rarity ~= "common" then
				top.TextColor3 = Common.rarityColor(rarity)
			end
			local color = if rarity then Common.rarityColor(rarity) else Kit.Theme.get().colors.accent
			flash.BackgroundColor3 = color
			flash.BackgroundTransparency = 0.45
			Common.animate(0.45, function(a: number)
				flash.BackgroundTransparency = 0.45 + 0.55 * a
			end)
			if rarity and rarity ~= "common" then
				stroke.Color = color
				stroke.Thickness = 2
			end
			if rarity == "mythic" then
				top.TextColor3 = Color3.new(1, 1, 1)
				table.insert(cleanups, Common.prismatic(top))
				table.insert(cleanups, Common.prismatic(stroke))
				burst()
			end
			Kit.sound(Common.landSound(rarity))
		end
		local cb = landedCb
		landedCb = nil
		if cb then
			cb()
		end
	end

	local function set(final: Entry)
		cancelAnim()
		clearFx()
		finalEntry = final
		build({ final })
		landedCb = nil
		spinning = false
		local top = labels[1]
		if top and final.rarity and final.rarity ~= "common" then
			top.TextColor3 = Common.rarityColor(final.rarity)
			stroke.Color = Common.rarityColor(final.rarity)
			stroke.Thickness = 2
		end
		if top and final.rarity == "mythic" then
			top.TextColor3 = Color3.new(1, 1, 1)
			table.insert(cleanups, Common.prismatic(top))
			table.insert(cleanups, Common.prismatic(stroke))
		end
	end

	local function spin(final: Entry, filler: { Entry }, duration: number, onLanded: (() -> ())?)
		cancelAnim()
		clearFx()
		local entries = table.clone(filler)
		table.insert(entries, final)
		finalEntry = final
		landedCb = onLanded
		build(entries)
		spinning = true
		local distance = (#entries - 1) * h
		local lastTick = 0
		cancelAnim = Common.animate(duration, function(a: number)
			-- fast scroll, then a long deceleration onto the result
			local eased = 1 - (1 - a) ^ 4
			local y = math.floor(eased * distance + 0.5)
			strip.Position = UDim2.fromOffset(0, -y)
			local idx = math.floor(y / h)
			if idx ~= lastTick and a < 0.97 then
				lastTick = idx
				Kit.sound("type")
			end
		end, land)
	end

	return {
		frame = frame,
		spin = spin,
		set = set,
		isSpinning = function(): boolean
			return spinning
		end,
		skip = function()
			if spinning then
				cancelAnim()
				land()
			end
		end,
		destroy = function()
			cancelAnim()
			clearFx()
			frame:Destroy()
		end,
	}
end

return Reel
