--!strict
-- CareerParts/Common (client): helpers shared by the Career, CareerServices, Offers and ReviewMeeting screens.
--   Common.text(key, vars?)                Tracks.text
--   Common.career(ctx) -> career?          Store "career" (read-only)
--   Common.controller(ctx) -> CareerController?
--   Common.logo(container, logoId, opts?)  Logos.render, guarded (an empty frame when logos are missing)
--   Common.money(n) / Common.compact(n)    Format.money / Format.compactMoney
--   Common.bandColor(band) -> theme key    Common.statusColor(status) -> theme key
--   Common.row(parent, label, value, order) -> (Frame, valueLabel)   a two-column info row
--   Common.chip(text, color) -> Badge
--   Common.notify(ctx, text, kind?)        HUD toast
--   Common.safe(fn, ...)                   pcall with a warning (UI callbacks never break the screen)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Tracks = require(Shared.Config.Tracks)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))

local Common = {}

Common.Kit = Kit
Common.Tracks = Tracks

function Common.text(key: string, vars: { [string]: any }?): string
	return Tracks.text(key, vars)
end

function Common.career(ctx: any): { [string]: any }?
	local store = if type(ctx) == "table" then ctx.Store else nil
	if not store then
		return nil
	end
	local ok, v = pcall(function()
		return store:Get("career")
	end)
	return if ok and type(v) == "table" then v else nil
end

-- The career, or an empty table while it hasn't replicated yet.
function Common.careerOrEmpty(ctx: any): { [string]: any }
	return Common.career(ctx) or {}
end

-- "Oct 17" in the player's locale (DateTime; empty when unavailable).
function Common.date(at: any): string
	if type(at) ~= "number" or at <= 0 then
		return ""
	end
	local ok, s = pcall(function(): string
		return DateTime.fromUnixTimestamp(math.floor(at)):FormatLocalTime("MMM D", "en-us")
	end)
	return if ok and type(s) == "string" then s else ""
end

function Common.controller(ctx: any): any
	local registry = if type(ctx) == "table" then ctx.Registry else nil
	if not registry then
		return nil
	end
	local ok, c = pcall(function()
		return registry.get("CareerController")
	end)
	return if ok then c else nil
end

local logosModule: any = false
local function logos(): any
	if logosModule == false then
		logosModule = nil
		local assets = Shared:FindFirstChild("Assets")
		local mod = assets and assets:FindFirstChild("Logos")
		if mod and mod:IsA("ModuleScript") then
			local ok, res = pcall(require, mod)
			if ok and type(res) == "table" and type(res.render) == "function" then
				logosModule = res
			end
		end
	end
	return logosModule
end

-- Draws a company logo into `container` (sized by the caller). Falls back to the short name on a tile.
function Common.logo(container: GuiObject, logoId: string, opts: { [string]: any }?, fallbackText: string?)
	local L = logos()
	if L then
		local ok = pcall(L.render, container, logoId, opts)
		if ok then
			return
		end
	end
	local label = Instance.new("TextLabel")
	label.Name = "LogoFallback"
	label.BackgroundTransparency = 0
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Text = fallbackText or string.upper(string.sub(logoId, 1, 2))
	Kit.themed(label, function(t)
		label.BackgroundColor3 = t.colors.surface
		label.TextColor3 = t.colors.text
		label.FontFace = t.fonts.display
	end)
	Kit.corner(label, 8)
	label.Parent = container
end

function Common.money(n: number): string
	return Format.money(math.floor(n + 0.5))
end

function Common.compact(n: number): string
	return Format.compactMoney(n)
end

local BAND_COLORS: { [string]: string } = {
	star = "accent",
	on_track = "good",
	under = "warn",
	probation = "bad",
	critical = "bad",
}
function Common.bandColor(band: any): string
	return BAND_COLORS[band] or "textDim"
end

local STATUS_COLORS: { [string]: string } = {
	active = "good",
	coaching = "warn",
	probation = "bad",
	fired = "bad",
	student = "accent",
}
function Common.statusColor(status: any): string
	return STATUS_COLORS[status] or "textDim"
end

function Common.statusText(status: any): string
	local key = "status_" .. tostring(status)
	if Tracks.strings[key] then
		return Tracks.text(key)
	end
	return Tracks.text("status_active")
end

function Common.chip(text: string, color: string): Kit.Badge
	return Kit.Badge({ text = text, color = color, size = "sm" })
end

-- A label/value row: label on the left (dim), value on the right (mono when numeric).
function Common.row(parent: Instance, label: string, value: string, order: number, mono: boolean?): (Frame, Kit.Label)
	local row = Kit.frame("Row_" .. order, UDim2.new(1, 0, 0, 0))
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.LayoutOrder = order
	local left = Kit.Label({ text = label, size = "sm", color = "textDim", autoSize = "y", width = UDim.new(0.42, -6) })
	left.frame.Parent = row
	local right = Kit.Label({
		text = value,
		size = "sm",
		font = if mono then "mono" else "bodyBold",
		align = "right",
		autoSize = "y",
		width = UDim.new(0.58, 0),
	})
	right.frame.AnchorPoint = Vector2.new(1, 0)
	right.frame.Position = UDim2.fromScale(1, 0)
	right.frame.Parent = row
	row.Parent = parent
	return row, right
end

function Common.notify(ctx: any, text: string, kind: string?)
	local ui = if type(ctx) == "table" then ctx.UI else nil
	if ui and type(ui.Notify) == "function" then
		pcall(ui.Notify, ui, text, kind)
	end
end

function Common.safe(fn: (...any) -> (), ...: any)
	local args = table.pack(...)
	local ok, err = pcall(function()
		fn(table.unpack(args, 1, args.n))
	end)
	if not ok then
		warn("[Career UI] " .. tostring(err))
	end
end

-- Seconds -> "12 min" for the week countdown.
function Common.minutes(seconds: number): string
	return tostring(math.max(1, math.ceil(seconds / 60)))
end

return Common
