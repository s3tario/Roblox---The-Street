--!strict
-- HUD news ticker band (bottom edge). New lines play first; when the queue is empty the band cycles
-- through the recent history. With reduced motion the text swaps in place instead of scrolling.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Strings = require(Shared.Config.Strings)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))

local Ticker = {}

export type Ticker = {
	frame: Frame,
	push: (line: string) -> (),
	setHistory: (lines: { string }) -> (),
	setEnabled: (enabled: boolean) -> (),
	setBottom: (px: number) -> (),
	step: (dt: number) -> (),
	hasLines: () -> boolean,
}

Ticker.HEIGHT = 30
local SPEED = 85 -- px per second
local STATIC_SECONDS = 7
local HISTORY_MAX = 20
local QUEUE_MAX = 20

function Ticker.new(): Ticker
	local band = Instance.new("Frame")
	band.Name = "Ticker"
	band.BorderSizePixel = 0
	band.AnchorPoint = Vector2.new(0, 1)
	band.Position = UDim2.fromScale(0, 1)
	band.Size = UDim2.new(1, 0, 0, Ticker.HEIGHT)
	band.Visible = false
	band.Active = false
	local topLine = Instance.new("Frame")
	topLine.Name = "Edge"
	topLine.BorderSizePixel = 0
	topLine.Size = UDim2.new(1, 0, 0, 1)
	topLine.Parent = band

	local tag = Instance.new("TextLabel")
	tag.Name = "Tag"
	tag.BorderSizePixel = 0
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Size = UDim2.new(0, 0, 1, 0)
	tag.Text = Strings.get("ticker_campus")
	tag.ZIndex = 2
	tag.Parent = band
	local tagPad = Instance.new("UIPadding")
	tagPad.PaddingLeft = UDim.new(0, 12)
	tagPad.PaddingRight = UDim.new(0, 12)
	tagPad.Parent = tag

	local clip = Kit.frame("Clip", UDim2.new(1, -140, 1, 0))
	clip.Position = UDim2.fromOffset(140, 0)
	clip.ClipsDescendants = true
	clip.Parent = band
	local text = Instance.new("TextLabel")
	text.Name = "Line"
	text.BackgroundTransparency = 1
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.new(0, 0, 1, 0)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Text = ""
	text.Parent = clip

	Kit.themed(band, function(t)
		band.BackgroundColor3 = t.colors.bg
		band.BackgroundTransparency = 0.12
		topLine.BackgroundColor3 = t.colors.accent
		tag.BackgroundColor3 = t.colors.accent
		tag.TextColor3 = t.colors.accentText
		tag.FontFace = t.fonts.bodyBold
		tag.TextSize = t.text.sm
		tag.Text = Strings.get(if t.name == "street" then "ticker_street" else "ticker_campus")
		text.FontFace = t.fonts.mono
		text.TextSize = t.text.sm
		text.TextColor3 = t.colors.text
	end)

	local queue: { string } = {}
	local history: { string } = {}
	local historyIndex = 0
	local enabled = true
	local x = 0
	local playing = false
	local staticLeft = 0

	local function clipWidth(): number
		local s = Kit.unscaledSize(clip)
		return if s then s.X else 600
	end
	local function textWidth(): number
		local s = Kit.unscaledSize(text)
		return if s then s.X else #text.Text * 8
	end

	local function nextLine(): boolean
		local line: string? = nil
		if #queue > 0 then
			line = table.remove(queue, 1)
		elseif #history > 0 then
			historyIndex = (historyIndex % #history) + 1
			line = history[historyIndex]
		end
		if line == nil then
			playing = false
			text.Text = ""
			return false
		end
		text.Text = "◆  " .. line
		playing = true
		if Kit.reducedMotion() then
			x = 8
			staticLeft = STATIC_SECONDS
		else
			x = clipWidth()
		end
		text.Position = UDim2.new(0, Kit.Core.px(x), 0, 0)
		return true
	end

	local function refreshVisible()
		band.Visible = enabled and (playing or #queue > 0 or #history > 0)
	end

	local function remember(line: string)
		table.insert(history, line)
		while #history > HISTORY_MAX do
			table.remove(history, 1)
		end
	end

	return {
		frame = band,
		push = function(line: string)
			if type(line) ~= "string" or line == "" then
				return
			end
			table.insert(queue, line)
			while #queue > QUEUE_MAX do
				table.remove(queue, 1)
			end
			remember(line)
			-- Breaking news interrupts a history replay straight away.
			if not playing then
				nextLine()
			end
			refreshVisible()
		end,
		setHistory = function(lines: { string })
			for _, line in lines do
				if type(line) == "string" and line ~= "" and not table.find(history, line) then
					remember(line)
				end
			end
			if not playing then
				nextLine()
			end
			refreshVisible()
		end,
		setEnabled = function(on: boolean)
			enabled = on
			refreshVisible()
		end,
		setBottom = function(px: number)
			band.Position = UDim2.new(0, 0, 1, -Kit.Core.px(px))
		end,
		step = function(dt: number)
			if not enabled or not band.Visible then
				return
			end
			if not playing then
				nextLine()
				return
			end
			if Kit.reducedMotion() then
				staticLeft -= dt
				if staticLeft <= 0 then
					nextLine()
				end
				return
			end
			x -= SPEED * dt
			if x + textWidth() < 0 then
				nextLine()
			else
				text.Position = UDim2.new(0, Kit.Core.px(x), 0, 0)
			end
		end,
		hasLines = function()
			return #queue > 0 or #history > 0
		end,
	}
end

return Ticker
