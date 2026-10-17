--!strict
-- Wardrobe screen: item cards. Each card shows the item's colour swatches, its name, the brand line in the
-- rarity colour (a prismatic gradient for Mythic), a rarity strip along the top, the clothing level ("Lv 3",
-- v3 §5) in the top corner and a state badge (price, Owned, Wearing, or the lock reason). The whole card is one
-- tap target.
--
--   Cards.item(item, state: View.State, opts) -> Card
--     opts = { selected: boolean?, onClick: () -> () }
--   card.frame                          TextButton (fills its grid cell)
--   card.update(state, selected)
--   Cards.rarityPaint(frame, rarityId)  colours a frame (or its UIStroke) with the rarity colour / gradient

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local View = require(script.Parent.View)

local Cards = {}

export type Card = {
	frame: TextButton,
	update: (state: View.State, selected: boolean) -> (),
}

-- Fills `frame` with the rarity colour; mythic gets a magenta-to-cyan gradient.
function Cards.rarityPaint(frame: GuiObject, rarity: string?)
	local r = View.rarity(rarity)
	frame.BackgroundColor3 = r.color
	local existing = frame:FindFirstChild("RarityGradient")
	if r.color2 then
		local g = if existing and existing:IsA("UIGradient") then existing else Instance.new("UIGradient")
		g.Name = "RarityGradient"
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, r.color),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 240, 255)),
			ColorSequenceKeypoint.new(1, r.color2),
		})
		g.Parent = frame
	elseif existing then
		existing:Destroy()
	end
end

local function swatchRow(item: Catalog.Item): Frame
	local row = Kit.frame("Swatches", UDim2.new(1, 0, 0, 18))
	local list = Kit.list(row, true, 4)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	for i, c in View.swatches(item) do
		local dot = Instance.new("Frame")
		dot.Name = "Swatch" .. i
		dot.BorderSizePixel = 0
		dot.Size = UDim2.fromOffset(16, 16)
		dot.BackgroundColor3 = c
		dot.LayoutOrder = i
		Kit.corner(dot, 999)
		local s = Kit.stroke(dot, 1, 0.4)
		s.Color = Color3.new(0, 0, 0)
		dot.Parent = row
	end
	return row
end

function Cards.item(item: Catalog.Item, state: View.State, opts: { selected: boolean?, onClick: () -> () }): Card
	local root = Instance.new("TextButton")
	root.Name = "Item_" .. item.id
	root.Text = ""
	root.AutoButtonColor = false
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ClipsDescendants = true
	local corner = Kit.corner(root)
	local stroke = Kit.stroke(root, 1.5)

	local strip = Instance.new("Frame")
	strip.Name = "Rarity"
	strip.BorderSizePixel = 0
	strip.Size = UDim2.new(1, 0, 0, 5)
	strip.Parent = root
	Cards.rarityPaint(strip, item.rarity)

	local body = Kit.frame("Body", UDim2.new(1, 0, 1, -5))
	body.Position = UDim2.fromOffset(0, 5)
	body.Parent = root
	Kit.padding(body, 8, 6)
	Kit.list(body, false, 4)

	local swatches = swatchRow(item)
	swatches.LayoutOrder = 1
	swatches.Parent = body

	-- clothing level, top-right over the swatch row (outside the list layout)
	local level = Kit.Badge({ text = View.levelBadge(item), color = "surface", name = "Level", size = "xs" })
	level.frame.AnchorPoint = Vector2.new(1, 0)
	level.frame.Position = UDim2.new(1, -6, 0, 10)
	level.frame.ZIndex = 3
	level.label.ZIndex = 3
	level.frame.Parent = root

	local name = Kit.Label({
		text = item.name,
		size = "sm",
		font = "bodyBold",
		autoSize = "none",
		height = 36,
		name = "Name",
		layoutOrder = 2,
	})
	name.frame.TextTruncate = Enum.TextTruncate.AtEnd
	name.frame.TextYAlignment = Enum.TextYAlignment.Top
	name.frame.Parent = body

	local rarity = View.rarity(item.rarity)
	local brand = Kit.Label({
		text = View.brandLine(item),
		size = "xs",
		color = rarity.color,
		autoSize = "none",
		height = 16,
		name = "Brand",
		layoutOrder = 3,
	})
	brand.frame.TextTruncate = Enum.TextTruncate.AtEnd
	brand.frame.Parent = body
	if rarity.color2 then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(rarity.color, rarity.color2)
		g.Parent = brand.frame
		brand.setColor(Color3.new(1, 1, 1))
	end

	local badge = Kit.Badge({ text = state.badge, color = state.badgeColor, name = "State", layoutOrder = 4 })
	badge.frame.Parent = body

	local selected = opts.selected == true
	local current = state
	local function paint(t: Kit.Tokens)
		root.BackgroundColor3 = if selected then Kit.shade(t.colors.panelAlt, 0.08) else t.colors.panelAlt
		corner.CornerRadius = UDim.new(0, t.radius)
		stroke.Color = if selected then t.colors.accent else rarity.color
		stroke.Thickness = if selected then 3 else 1.5
		stroke.Transparency = if selected then 0 else 0.35
		root.BackgroundTransparency = if current.locked then 0.25 else 0
	end
	Kit.themed(root, paint)

	Kit.connect(root, "Activated", function()
		Kit.sound("click")
		opts.onClick()
	end)

	return {
		frame = root,
		update = function(s: View.State, sel: boolean)
			current = s
			selected = sel
			badge.setText(s.badge)
			badge.setColor(s.badgeColor)
			paint(Kit.Theme.get())
		end,
	}
end

return Cards
