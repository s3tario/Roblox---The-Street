--!strict
-- Terminal chrome (owned by `market`): the device the Terminal is drawn on, restyled live with the theme.
--   street -> a dark, slick trading terminal: a thin near-black bezel with a gold hairline and a glowing screen edge
--   campus -> an old student laptop: a thick plastic bezel with a webcam dot, a sticker-style club brand on the chin
--             and a cold LCD screen
-- The screen frame is where the Terminal lays out its parts.
--
--   Shell.new(parent) -> { frame, screen, variant() -> "terminal" | "laptop" }

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Style = require(script.Parent.Style)

local Shell = {}

export type Shell = { frame: Frame, screen: Frame, variant: () -> string }

local INSETS = {
	terminal = { left = 6, right = 6, top = 6, bottom = 6, radius = 10 },
	laptop = { left = 14, right = 14, top = 16, bottom = 30, radius = 16 },
}

function Shell.new(parent: Instance): Shell
	local bezel = Instance.new("Frame")
	bezel.Name = "Bezel"
	bezel.BorderSizePixel = 0
	bezel.Size = UDim2.fromScale(1, 1)
	bezel.Parent = parent
	local bezelCorner = Instance.new("UICorner")
	bezelCorner.Parent = bezel
	local bezelStroke = Instance.new("UIStroke")
	bezelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bezelStroke.Parent = bezel

	local webcam = Instance.new("Frame")
	webcam.Name = "Webcam"
	webcam.BorderSizePixel = 0
	webcam.AnchorPoint = Vector2.new(0.5, 0)
	webcam.Position = UDim2.new(0.5, 0, 0, 5)
	webcam.Size = UDim2.fromOffset(6, 6)
	webcam.Parent = bezel
	local camCorner = Instance.new("UICorner")
	camCorner.CornerRadius = UDim.new(1, 0)
	camCorner.Parent = webcam

	local brand = Style.text("Brand", Tickers.text("laptop_brand"), { size = "xs", font = "bold", color = "dim" })
	brand.AnchorPoint = Vector2.new(0.5, 1)
	brand.Position = UDim2.new(0.5, 0, 1, -7)
	brand.Parent = bezel

	local screen = Instance.new("Frame")
	screen.Name = "Screen"
	screen.BorderSizePixel = 0
	screen.ClipsDescendants = true
	screen.Parent = bezel
	local screenCorner = Instance.new("UICorner")
	screenCorner.Parent = screen
	local screenStroke = Instance.new("UIStroke")
	screenStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	screenStroke.Parent = screen
	Kit.padding(screen, 8, 8)

	local variant = "terminal"
	Style.bind(bezel, function(pal)
		variant = pal.variant
		local inset = INSETS[pal.variant] or INSETS.terminal
		bezel.BackgroundColor3 = pal.bezel
		bezelCorner.CornerRadius = UDim.new(0, inset.radius)
		bezelStroke.Color = pal.bezelEdge
		bezelStroke.Thickness = if pal.variant == "laptop" then 2 else 1
		screen.BackgroundColor3 = pal.bg
		screen.Position = UDim2.fromOffset(inset.left, inset.top)
		screen.Size = UDim2.new(1, -(inset.left + inset.right), 1, -(inset.top + inset.bottom))
		screenCorner.CornerRadius = UDim.new(0, if pal.variant == "laptop" then 4 else 8)
		screenStroke.Color = if pal.variant == "laptop" then pal.line else pal.accent
		screenStroke.Transparency = if pal.variant == "laptop" then 0.2 else 0.65
		webcam.Visible = pal.variant == "laptop"
		webcam.BackgroundColor3 = pal.bezelEdge
		brand.Visible = pal.variant == "laptop"
	end)

	return {
		frame = bezel,
		screen = screen,
		variant = function(): string
			return variant
		end,
	}
end

return Shell
