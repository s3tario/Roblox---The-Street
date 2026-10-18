--!strict
-- LifeRollParts/Crest: a school crest in a square box (client UI, careerCore). Draws the logos feature's crest
-- (Shared/Assets/Logos.render(container, schoolId)); if Logos is missing or errors, it falls back to a shield-like
-- tile in the school's colours with its initials, so the card never shows an empty hole.
--
--   Crest.mount(parent, school?, size) -> Frame   school = PublicProfile.school ({id, initials, colors, rarity})

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Common = require(script.Parent.Common)

local Crest = {}

local logosModule: any = nil
local logosTried = false
local function logos(): any
	if not logosTried then
		logosTried = true
		local ok, mod = pcall(function()
			local assets = Shared:FindFirstChild("Assets")
			local m = assets and assets:FindFirstChild("Logos")
			return if m and m:IsA("ModuleScript") then (require :: any)(m) else nil
		end)
		if ok and type(mod) == "table" and type(mod.render) == "function" then
			logosModule = mod
		elseif not ok then
			warn("[LifeRoll] Logos unavailable: " .. tostring(mod))
		end
	end
	return logosModule
end

local function hexColor(hex: any, default: Color3): Color3
	if type(hex) ~= "string" then
		return default
	end
	local h = string.gsub(hex, "#", "")
	if #h ~= 6 then
		return default
	end
	local r, g, b =
		tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16)
	if not r or not g or not b then
		return default
	end
	return Color3.fromRGB(r, g, b)
end

local function fallback(box: Frame, school: any, size: number)
	local main = hexColor(school and school.colors and school.colors.primary, Color3.fromRGB(60, 64, 72))
	local accent = hexColor(school and school.colors and school.colors.secondary, Color3.fromRGB(201, 165, 76))
	local tile = Instance.new("Frame")
	tile.Name = "CrestFallback"
	tile.AnchorPoint = Vector2.new(0.5, 0.5)
	tile.Position = UDim2.fromScale(0.5, 0.5)
	tile.Size = UDim2.fromScale(0.82, 0.92)
	tile.BackgroundColor3 = main
	tile.BorderSizePixel = 0
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.18, 0)
	round.Parent = tile
	local trim = Instance.new("UIStroke")
	trim.Thickness = math.max(2, math.floor(size / 28))
	trim.Color = Common.rarityColor(school and school.rarity)
	trim.Parent = tile
	local letters = Instance.new("TextLabel")
	letters.Name = "Initials"
	letters.BackgroundTransparency = 1
	letters.Size = UDim2.fromScale(1, 1)
	letters.Text = if school and type(school.initials) == "string" then school.initials else "?"
	letters.TextColor3 = accent
	letters.TextScaled = true
	letters.FontFace = Font.fromEnum(Enum.Font.Merriweather)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.2, 0)
	pad.PaddingBottom = UDim.new(0.2, 0)
	pad.PaddingLeft = UDim.new(0.14, 0)
	pad.PaddingRight = UDim.new(0.14, 0)
	pad.Parent = letters
	letters.Parent = tile
	tile.Parent = box
end

function Crest.mount(parent: Instance, school: any, size: number): Frame
	local box = Instance.new("Frame")
	box.Name = "Crest"
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	box.Size = UDim2.fromOffset(size, size)
	box.Parent = parent
	local id = if type(school) == "table" and type(school.id) == "string" and school.id ~= "" then school.id else nil
	local L = if id then logos() else nil
	local drawn = false
	if L and id then
		local ok, err = pcall(function()
			L.render(box, id, { px = size, name = "CrestLogo" })
		end)
		drawn = ok
		if not ok then
			warn("[LifeRoll] crest render failed for " .. id .. ": " .. tostring(err))
			for _, c in box:GetChildren() do
				c:Destroy()
			end
		end
	end
	if not drawn then
		fallback(box, school, size)
	end
	return box
end

return Crest
