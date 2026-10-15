--!strict
-- HUD banner (top-centre): big title + subtitle for events, promotions, warnings and celebrations.
-- Banners queue and show one at a time, then hide on their own.

local UIFolder = script.Parent.Parent.Parent:WaitForChild("UI")
local Kit = require(UIFolder:WaitForChild("Kit"))
local Sfx = require(UIFolder:WaitForChild("Sfx"))

local Banner = {}

export type Opts = { title: string?, subtitle: string?, style: string?, duration: number? }
export type Banner = {
	frame: Frame,
	show: (opts: Opts) -> (),
	setTop: (px: number) -> (),
	clear: () -> (),
}

-- style -> colour token, glyph, sound cue
Banner.styles = {
	event = { color = "accent", glyph = "★", sound = "chime" },
	promotion = { color = "accent", glyph = "▲", sound = "promotion" },
	warning = { color = "warn", glyph = "!", sound = "alarm" },
	celebration = { color = "good", glyph = "✦", sound = "levelup" },
} :: { [string]: { color: string, glyph: string, sound: string } }

local MAX_QUEUE = 4
local HIDDEN_Y = -260

function Banner.new(): Banner
	local top = 12
	local frame = Kit.frame("Banner", UDim2.new(0.92, 0, 0, 0))
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, HIDDEN_Y)
	frame.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(580, math.huge)
	limit.Parent = frame

	local panel = Kit.Panel({ name = "Panel", padding = 14 })
	panel.frame.Parent = frame
	local row = Kit.frame("Row", UDim2.new(1, 0, 0, 0))
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Parent = panel.frame
	local rowList = Kit.list(row, true, 14)
	rowList.VerticalAlignment = Enum.VerticalAlignment.Center

	local glyphBox = Instance.new("Frame")
	glyphBox.Name = "Glyph"
	glyphBox.Size = UDim2.fromOffset(52, 52)
	glyphBox.BorderSizePixel = 0
	glyphBox.LayoutOrder = 1
	glyphBox.Parent = row
	Kit.corner(glyphBox, 999)
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Text"
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Text = "★"
	glyph.Parent = glyphBox

	local texts = Kit.frame("Texts", UDim2.new(1, -66, 0, 0))
	texts.AutomaticSize = Enum.AutomaticSize.Y
	texts.LayoutOrder = 2
	texts.Parent = row
	Kit.list(texts, false, 2)
	local title = Kit.Heading({ text = "", level = 1, name = "Title", layoutOrder = 1 })
	title.frame.Parent = texts
	local subtitle = Kit.Label({ text = "", size = "md", color = "textDim", name = "Subtitle", layoutOrder = 2 })
	subtitle.frame.Parent = texts

	local stroke = panel.frame:FindFirstChildOfClass("UIStroke")
	local styleKey = "event"
	local function paint(t: Kit.Tokens)
		local def = Banner.styles[styleKey] or Banner.styles.event
		local c = Kit.color(t, def.color)
		glyphBox.BackgroundColor3 = c
		glyph.FontFace = t.fonts.bodyBold
		glyph.TextSize = t.text.xl
		glyph.TextColor3 = Kit.Theme.contrastText(c)
		if stroke then
			stroke.Color = c
			stroke.Thickness = t.stroke + 1
		end
	end
	Kit.themed(frame, paint)

	local queue: { Opts } = {}
	local running = false
	local generation = 0

	local function display(opts: Opts)
		styleKey = if opts.style and Banner.styles[opts.style] then opts.style else "event"
		local def = Banner.styles[styleKey]
		glyph.Text = def.glyph
		title.setText(opts.title or "")
		subtitle.setText(opts.subtitle or "")
		subtitle.frame.Visible = opts.subtitle ~= nil and opts.subtitle ~= ""
		paint(Kit.Theme.get())
		frame.Visible = true
		frame.Position = UDim2.new(0.5, 0, 0, HIDDEN_Y)
		Kit.tween(frame, 0.3, { Position = UDim2.new(0.5, 0, 0, top) })
		Sfx.play(def.sound)
	end

	local function run()
		if running then
			return
		end
		running = true
		local myGen = generation
		task.spawn(function()
			while #queue > 0 and myGen == generation do
				local opts = table.remove(queue, 1) :: Opts
				display(opts)
				local duration = math.clamp(tonumber(opts.duration) or 4.5, 1.5, 15)
				task.wait(duration)
				if myGen ~= generation then
					break
				end
				Kit.tween(frame, 0.25, { Position = UDim2.new(0.5, 0, 0, HIDDEN_Y) })
				task.wait(if Kit.reducedMotion() then 0.05 else 0.3)
				if myGen ~= generation then
					break
				end
				frame.Visible = false
			end
			if myGen == generation then
				running = false
			end
		end)
	end

	return {
		frame = frame,
		show = function(opts: Opts)
			if type(opts) ~= "table" then
				return
			end
			local title0 = if type(opts.title) == "string" then opts.title else nil
			if title0 == nil or title0 == "" then
				return
			end
			table.insert(queue, {
				title = title0,
				subtitle = if type(opts.subtitle) == "string" then opts.subtitle else nil,
				style = if type(opts.style) == "string" then opts.style else nil,
				duration = if type(opts.duration) == "number" then opts.duration else nil,
			})
			while #queue > MAX_QUEUE do
				table.remove(queue, 1)
			end
			run()
		end,
		setTop = function(px: number)
			top = Kit.Core.px(px)
			if frame.Visible then
				frame.Position = UDim2.new(0.5, 0, 0, top)
			end
		end,
		clear = function()
			generation += 1
			running = false
			table.clear(queue)
			frame.Visible = false
			frame.Position = UDim2.new(0.5, 0, 0, HIDDEN_Y)
		end,
	}
end

return Banner
