--!strict
-- Kit core: helpers shared by every Kit component.
--   * safe event wiring (no-ops under Lune, where Instances have no events)
--   * theme binding: Core.themed(inst, apply) applies now and again on Theme.Changed
--   * tweens through Core.tween (instant when TweenService is unavailable or reduced motion is on)
--   * host hooks set by UIController: modal layer, modal stack, click sounds, safe-area insets
-- Pure: no service calls at construction.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Theme = require(script.Parent.Parent.Theme)

export type Tokens = Theme.Tokens
export type ColorSpec = string | Color3 -- a Theme colour key ("accent") or an explicit Color3
export type Insets = { top: number, bottom: number, left: number, right: number }
export type Host = {
	modal: Instance?, -- parent for modals (UIController's modal layer)
	push: ((close: () -> ()) -> () -> ())?, -- registers a modal on the Back stack, returns release()
	sound: ((name: string) -> ())?, -- Sfx.play
}

local Core = {}

-- True inside Roblox (workspace exists), false under Lune.
Core.LIVE = (workspace :: any) ~= nil
Core.TAP = 44 -- minimum tap target (px)
Core.reducedMotion = false
Core.Theme = Theme
Core.host = {} :: Host
Core.insets = { top = 0, bottom = 0, left = 0, right = 0 } :: Insets
Core.InsetsChanged = Signal.new()

-- Rounds to a whole pixel (UDim offsets are int32: Roblox truncates, Lune rejects fractions).
function Core.px(n: number): number
	if n ~= n then
		return 0
	end
	return math.floor(n + 0.5)
end

-- Toast/notification kinds: colour token + glyph.
Core.kinds = {
	info = { color = "accent", glyph = "i" },
	good = { color = "good", glyph = "✓" },
	bad = { color = "bad", glyph = "✕" },
	warn = { color = "warn", glyph = "!" },
	cash = { color = "good", glyph = "$" },
	xp = { color = "accent", glyph = "★" },
} :: { [string]: { color: string, glyph: string } }

---------------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------------
-- Connects inst[eventName] if it exists (always nil under Lune).
function Core.connect(inst: Instance, eventName: string, fn: (...any) -> ()): RBXScriptConnection?
	if not Core.LIVE then
		return nil
	end
	local ok, sig = pcall(function()
		return (inst :: any)[eventName]
	end)
	if ok and typeof(sig) == "RBXScriptSignal" then
		return (sig :: RBXScriptSignal):Connect(fn)
	end
	return nil
end

function Core.propChanged(inst: Instance, prop: string, fn: () -> ()): RBXScriptConnection?
	if not Core.LIVE then
		return nil
	end
	local ok, sig = pcall(function()
		return inst:GetPropertyChangedSignal(prop)
	end)
	if ok and sig then
		return sig:Connect(fn)
	end
	return nil
end

-- Runs fn once when inst is destroyed (Roblox only).
function Core.onDestroy(inst: Instance, fn: () -> ())
	local conn: RBXScriptConnection? = nil
	conn = Core.connect(inst, "Destroying", function()
		if conn then
			conn:Disconnect()
		end
		fn()
	end)
end

-- First maxChars characters of s (UTF-8 aware; invalid UTF-8 falls back to bytes).
function Core.truncate(s: string, maxChars: number): string
	local len = utf8.len(s)
	if len == nil then
		return string.sub(s, 1, maxChars)
	end
	if len <= maxChars then
		return s
	end
	local cut = utf8.offset(s, maxChars + 1)
	return if cut then string.sub(s, 1, cut - 1) else s
end

function Core.sound(name: string)
	local s = Core.host.sound
	if s then
		local ok, err = pcall(s :: any, name)
		if not ok then
			warn("[Kit] sound hook failed: " .. tostring(err))
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Theme binding
---------------------------------------------------------------------------------------------------
local styled: { [Instance]: { (Tokens) -> () } } = {}

-- Calls apply(tokens) now and whenever the theme changes, until inst is destroyed.
function Core.themed(inst: Instance, apply: (Tokens) -> ())
	apply(Theme.get())
	local list = styled[inst]
	if list == nil then
		local fresh: { (Tokens) -> () } = {}
		styled[inst] = fresh
		list = fresh
		Core.onDestroy(inst, function()
			styled[inst] = nil
		end)
	end
	table.insert(list :: { (Tokens) -> () }, apply)
end

-- Re-applies every binding (used after Theme.Changed; also exposed for tests).
function Core.restyleAll(tokens: Tokens?)
	local t = tokens or Theme.get()
	local snapshot: { { (Tokens) -> () } } = {}
	for _, list in styled do
		table.insert(snapshot, table.clone(list))
	end
	for _, list in snapshot do
		for _, fn in list do
			local ok, err = pcall(fn :: any, t)
			if not ok then
				warn("[Kit] restyle failed: " .. tostring(err))
			end
		end
	end
end

Theme.Changed:Connect(function(tokens: Tokens)
	Core.restyleAll(tokens)
end)

function Core.styledCount(): number
	local n = 0
	for _ in styled do
		n += 1
	end
	return n
end

function Core.color(t: Tokens, spec: ColorSpec?, default: string?): Color3
	if typeof(spec) == "Color3" then
		return spec
	end
	local key = if type(spec) == "string" then spec else (default or "text")
	local c = (t.colors :: any)[key]
	if typeof(c) == "Color3" then
		return c
	end
	return t.colors.text
end

function Core.font(t: Tokens, key: string?): Font
	local f = (t.fonts :: any)[key or "body"]
	if typeof(f) == "Font" then
		return f
	end
	return t.fonts.body
end

function Core.textSize(t: Tokens, spec: (string | number)?, default: string?): number
	if type(spec) == "number" then
		return spec
	end
	local key = if type(spec) == "string" then spec else (default or "md")
	local n = (t.text :: any)[key]
	if type(n) == "number" then
		return n
	end
	return t.text.md
end

-- f > 0 lightens toward white, f < 0 darkens toward black.
function Core.shade(c: Color3, f: number): Color3
	if f >= 0 then
		return c:Lerp(Color3.new(1, 1, 1), f)
	end
	return c:Lerp(Color3.new(0, 0, 0), -f)
end

---------------------------------------------------------------------------------------------------
-- Decorators
---------------------------------------------------------------------------------------------------
function Core.corner(parent: Instance, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Core.px(radius or Theme.get().radius))
	c.Parent = parent
	return c
end

function Core.stroke(parent: Instance, thickness: number?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Thickness = thickness or Theme.get().stroke
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

function Core.padding(parent: Instance, all: number?, vertical: number?): UIPadding
	local p = Instance.new("UIPadding")
	local h = all or Theme.get().pad
	local v = vertical or h
	p.PaddingLeft = UDim.new(0, Core.px(h))
	p.PaddingRight = UDim.new(0, Core.px(h))
	p.PaddingTop = UDim.new(0, Core.px(v))
	p.PaddingBottom = UDim.new(0, Core.px(v))
	p.Parent = parent
	return p
end

function Core.list(parent: Instance, horizontal: boolean?, gap: number?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, Core.px(gap or Theme.get().gap))
	l.Parent = parent
	return l
end

-- Transparent container frame.
function Core.frame(name: string?, size: UDim2?): Frame
	local f = Instance.new("Frame")
	f.Name = name or "Frame"
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = size or UDim2.fromScale(1, 1)
	return f
end

-- Plain text label with theme font/size/colour bindings.
function Core.text(
	name: string,
	text: string,
	size: (string | number)?,
	font: string?,
	color: ColorSpec?,
	transparency: number?
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Text = text
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.fromOffset(0, 0)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTransparency = transparency or 0
	Core.themed(l, function(t)
		l.FontFace = Core.font(t, font)
		l.TextSize = Core.textSize(t, size)
		l.TextColor3 = Core.color(t, color)
	end)
	return l
end

---------------------------------------------------------------------------------------------------
-- Tweens
---------------------------------------------------------------------------------------------------
local tweenService: TweenService? = nil
local function getTweenService(): TweenService?
	if not Core.LIVE then
		return nil
	end
	if tweenService == nil then
		local ok, ts = pcall(function()
			return game:GetService("TweenService")
		end)
		if ok then
			tweenService = ts
		end
	end
	return tweenService
end

local function setProps(inst: Instance, props: { [string]: any })
	for k, v in props do
		(inst :: any)[k] = v
	end
end

-- Tweens props on inst. info is a TweenInfo or a duration in seconds (Quad Out). Applies instantly
-- (returns nil) when reduced motion is on or TweenService is unavailable.
function Core.tween(inst: Instance, info: TweenInfo | number, props: { [string]: any }, force: boolean?): Tween?
	local ts = getTweenService()
	if ts == nil or (Core.reducedMotion and not force) then
		setProps(inst, props)
		return nil
	end
	local ti: TweenInfo
	if type(info) == "number" then
		ti = TweenInfo.new(info, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	else
		ti = info
	end
	local ok, tw = pcall(function()
		return ts:Create(inst, ti, props)
	end)
	if not ok then
		setProps(inst, props)
		return nil
	end
	tw:Play()
	return tw
end

---------------------------------------------------------------------------------------------------
-- Shared 1 Hz ticker (Countdown labels). Only runs inside Roblox.
---------------------------------------------------------------------------------------------------
local tickers: { [number]: () -> () } = {}
local tickerId = 0
local tickerRunning = false

function Core.everySecond(fn: () -> ()): () -> ()
	tickerId += 1
	local id = tickerId
	tickers[id] = fn
	if Core.LIVE and not tickerRunning then
		tickerRunning = true
		task.spawn(function()
			while true do
				task.wait(1)
				local list: { () -> () } = {}
				for _, f in tickers do
					table.insert(list, f)
				end
				for _, f in list do
					local ok, err = pcall(f :: any)
					if not ok then
						warn("[Kit] ticker callback failed: " .. tostring(err))
					end
				end
			end
		end)
	end
	return function()
		tickers[id] = nil
	end
end

---------------------------------------------------------------------------------------------------
-- Geometry
---------------------------------------------------------------------------------------------------
-- AbsoluteSize divided by every ancestor UIScale, i.e. in the same units as Offset sizes.
-- nil under Lune or before layout.
function Core.unscaledSize(gui: GuiObject): Vector2?
	if not Core.LIVE then
		return nil
	end
	local abs = gui.AbsoluteSize
	if abs.X <= 0 or abs.Y <= 0 then
		return nil
	end
	local scale = 1
	local node: Instance? = gui
	while node do
		local s = node:FindFirstChildOfClass("UIScale")
		if s then
			scale *= s.Scale
		end
		node = node.Parent
	end
	if scale <= 0 then
		scale = 1
	end
	return abs / scale
end

function Core.setInsets(insets: Insets)
	local cur = Core.insets
	if
		cur.top == insets.top
		and cur.bottom == insets.bottom
		and cur.left == insets.left
		and cur.right == insets.right
	then
		return
	end
	Core.insets = { top = insets.top, bottom = insets.bottom, left = insets.left, right = insets.right }
	Core.InsetsChanged:Fire(Core.insets)
end

---------------------------------------------------------------------------------------------------
-- Modal host
---------------------------------------------------------------------------------------------------
export type ModalOpts = {
	width: number?, -- max card width (default 440)
	dismissable: boolean?, -- tap outside / Back closes (default true)
	parent: Instance?, -- default: host modal layer
	onDismiss: (() -> ())?, -- called when closed by tapping outside or Back
	name: string?,
}
export type Modal = { frame: Frame, card: Frame, close: () -> () }

-- Builds a centred modal card over a dimmed overlay that sinks input. build(card, close) fills the card.
function Core.openModal(opts: ModalOpts, build: (card: Frame, close: () -> ()) -> ()): Modal
	local container = Core.frame(opts.name or "Modal")
	container.ZIndex = 10

	local overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.Active = true
	overlay.Modal = true
	overlay.Selectable = false
	overlay.ZIndex = 1
	overlay.Parent = container
	Core.themed(overlay, function(t)
		overlay.BackgroundColor3 = t.colors.overlay
	end)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Active = true
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.new(1, -32, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BorderSizePixel = 0
	card.ZIndex = 2
	card.Parent = container
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(opts.width or 440, math.huge)
	limit.Parent = card
	local corner = Core.corner(card)
	local stroke = Core.stroke(card)
	Core.padding(card, 18)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.94
	scale.Parent = card
	Core.themed(card, function(t)
		card.BackgroundColor3 = t.colors.panel
		corner.CornerRadius = UDim.new(0, t.radius)
		stroke.Color = t.colors.border
		stroke.Thickness = t.stroke
	end)

	local closed = false
	local release: (() -> ())? = nil
	local function close()
		if closed then
			return
		end
		closed = true
		if release then
			local r = release
			release = nil
			pcall(r)
		end
		container:Destroy()
	end
	local function dismiss()
		if closed or opts.dismissable == false then
			return
		end
		close()
		if opts.onDismiss then
			opts.onDismiss()
		end
	end

	build(card, close)

	Core.connect(overlay, "Activated", dismiss)
	local push = Core.host.push
	if push then
		local ok, rel = pcall(push, dismiss)
		if ok and type(rel) == "function" then
			release = rel
		end
	end

	container.Parent = opts.parent or Core.host.modal
	Core.tween(overlay, 0.15, { BackgroundTransparency = 0.4 })
	Core.tween(scale, 0.15, { Scale = 1 })
	Core.sound("open")
	return { frame = container, card = card, close = close }
end

return Core
