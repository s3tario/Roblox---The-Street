--!strict
-- TerminalController: the LIVE INVESTED chip on the HUD (RUNTIME ONLY, client; design v3 §11 "shown on the HUD").
-- A small top-centre chip in UIController's "hud" layer (so it hides with the HUD while a full screen is open):
-- the market value of the player's open positions, updated with every tick and every book change. Tapping it opens
-- the Terminal (a 44 px tap target). It stays out of the way: hidden until the book has replicated, and hidden on
-- screens too narrow to fit it between the career card (left) and the menu column (right).
--
--   Hud.new(layer, onClick) -> Chip      Chip.set(value?)  nil hides it      Chip.destroy()

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tickers = require(Shared.Config.Tickers)
local Format = require(Shared.Util.Format)
local UIFolder = script.Parent.Parent.Parent:WaitForChild("UI")
local Kit = require(UIFolder:WaitForChild("Kit"))

local Hud = {}

Hud.WIDTH = 176
Hud.HEIGHT = 44
Hud.CARD_EDGE = 10 + 300 + 8 -- HudController's career card column (left padding + width) plus a gap

export type Chip = { frame: TextButton, set: (value: number?) -> (), destroy: () -> () }

local function money(v: number): string
	if math.abs(v) >= 1e6 then
		return Format.compactMoney(v)
	end
	return Format.money(v, 0)
end

function Hud.new(layer: Frame, onClick: () -> ()): Chip
	local chip = Instance.new("TextButton")
	chip.Name = "LiveInvested"
	chip.Text = ""
	chip.AutoButtonColor = false
	chip.BorderSizePixel = 0
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Size = UDim2.fromOffset(Hud.WIDTH, Hud.HEIGHT)
	chip.Visible = false
	local corner = Kit.corner(chip)
	local stroke = Kit.stroke(chip, 1, 0.35)

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.BackgroundTransparency = 1
	key.Position = UDim2.fromOffset(0, 5)
	key.Size = UDim2.new(1, 0, 0, 13)
	key.Text = Tickers.text("hud_invested")
	key.TextXAlignment = Enum.TextXAlignment.Center
	key.Parent = chip
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Position = UDim2.fromOffset(0, 18)
	value.Size = UDim2.new(1, 0, 0, 22)
	value.Text = "--"
	value.TextXAlignment = Enum.TextXAlignment.Center
	value.TextTruncate = Enum.TextTruncate.AtEnd
	value.Parent = chip

	Kit.themed(chip, function(t)
		chip.BackgroundColor3 = t.colors.panel
		chip.BackgroundTransparency = t.panelTransparency
		corner.CornerRadius = UDim.new(0, t.radius)
		stroke.Color = t.colors.accent
		key.FontFace = t.fonts.bodyBold
		key.TextSize = t.text.xs
		key.TextColor3 = t.colors.accent
		value.FontFace = t.fonts.mono
		value.TextSize = t.text.md
		value.TextColor3 = t.colors.text
	end)

	local wanted = false
	local fits = true
	-- centred, it must clear the career card on the left (the menu column on the right is narrower)
	local function measure()
		local size = Kit.unscaledSize(layer)
		local need = 2 * (Kit.insets().left + Hud.CARD_EDGE + Hud.WIDTH / 2)
		fits = size == nil or size.X >= need
		chip.Visible = wanted and fits
	end
	local function place()
		chip.Position = UDim2.new(0.5, 0, 0, Kit.insets().top + 8)
		measure()
	end
	place()
	local insetConn = Kit.InsetsChanged:Connect(place)
	local sizeConn = Kit.propChanged(layer, "AbsoluteSize", measure)
	Kit.connect(chip, "Activated", function()
		Kit.sound("click")
		onClick()
	end)
	chip.Parent = layer
	measure()

	return {
		frame = chip,
		set = function(v: number?)
			wanted = v ~= nil
			if v ~= nil then
				local text = money(v)
				if value.Text ~= text then
					value.Text = text
				end
			end
			chip.Visible = wanted and fits
		end,
		destroy = function()
			insetConn:Disconnect()
			if sizeConn then
				sizeConn:Disconnect()
			end
			chip:Destroy()
		end,
	}
end

return Hud
