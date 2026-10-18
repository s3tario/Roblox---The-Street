--!strict
-- Shop screen: item cards. A rarity strip along the top (decor uses its price band), colour swatches for clothing or
-- a category glyph for decor, the name, a subtitle (brand and rarity, or category and slot kinds), the clothing
-- level ("Lv 3", v3 §5) in the top corner, and a state badge: the price (struck "was" price during a sale), Owned,
-- Wearing, or the lock reason. The whole card is one tap target (>= 44 px).
--
--   Cards.item(entry, state, opts) -> Card     opts = { selected: boolean?, onClick: () -> () }
--   card.frame (TextButton filling its grid cell)    card.update(state, selected)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Build.Palette)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local View = require(script.Parent.View)

local Cards = {}

export type Card = { frame: TextButton, update: (state: View.CardState, selected: boolean) -> () }

local GLYPHS: { [string]: string } = {
	desk = "✎",
	art = "▣",
	furniture = "▤",
	plants = "✿",
	lighting = "☀",
	rugs = "▦",
	campus = "★",
}

local function paintRarity(frame: GuiObject, r: View.RarityView)
	frame.BackgroundColor3 = r.color
	if r.color2 then
		local g = Instance.new("UIGradient")
		g.Name = "RarityGradient"
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, r.color),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 240, 255)),
			ColorSequenceKeypoint.new(1, r.color2),
		})
		g.Parent = frame
	end
end

local function swatches(entry: View.Entry, rarity: View.RarityView): Frame
	local row = Kit.frame("Swatches", UDim2.new(1, -44, 0, 20))
	local list = Kit.list(row, true, 4)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	if entry.kind == "wearable" then
		local colors = entry.item.colors or {}
		local i = 0
		for _, key in { "primary", "secondary", "accent", "trim" } do
			local hex = colors[key]
			if type(hex) == "string" then
				i += 1
				local dot = Instance.new("Frame")
				dot.Name = "Swatch" .. i
				dot.BorderSizePixel = 0
				dot.Size = UDim2.fromOffset(16, 16)
				dot.BackgroundColor3 = Palette.hex(hex)
				dot.LayoutOrder = i
				Kit.corner(dot, 999)
				local s = Kit.stroke(dot, 1, 0.4)
				s.Color = Color3.new(0, 0, 0)
				dot.Parent = row
			end
		end
	else
		local glyph = Instance.new("TextLabel")
		glyph.Name = "Glyph"
		glyph.BackgroundTransparency = 1
		glyph.Size = UDim2.fromOffset(20, 20)
		glyph.Text = GLYPHS[entry.item.category] or "◆"
		glyph.TextScaled = true
		glyph.TextColor3 = rarity.color
		glyph.Parent = row
	end
	return row
end

function Cards.item(entry: View.Entry, state: View.CardState, opts: { selected: boolean?, onClick: () -> () }): Card
	local item = entry.item
	local rarity = View.rarity(entry)
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
	paintRarity(strip, rarity)

	local body = Kit.frame("Body", UDim2.new(1, 0, 1, -5))
	body.Position = UDim2.fromOffset(0, 5)
	body.Parent = root
	Kit.padding(body, 8, 6)
	Kit.list(body, false, 3)

	local top = swatches(entry, rarity)
	top.LayoutOrder = 1
	top.Parent = body

	local levelText = View.levelBadge(entry)
	if levelText then
		local level = Kit.Badge({ text = levelText, color = "surface", name = "Level", size = "xs" })
		level.frame.AnchorPoint = Vector2.new(1, 0)
		level.frame.Position = UDim2.new(1, -6, 0, 10)
		level.frame.ZIndex = 3
		level.label.ZIndex = 3
		level.frame.Parent = root
	end

	local name = Kit.Label({
		text = item.name,
		size = "sm",
		font = "bodyBold",
		autoSize = "none",
		height = 34,
		name = "Name",
		layoutOrder = 2,
	})
	name.frame.TextTruncate = Enum.TextTruncate.AtEnd
	name.frame.TextYAlignment = Enum.TextYAlignment.Top
	name.frame.Parent = body

	local sub = Kit.Label({
		text = View.subtitle(entry),
		size = "xs",
		color = if entry.kind == "wearable" then rarity.color else "textDim",
		autoSize = "none",
		height = 16,
		name = "Subtitle",
		layoutOrder = 3,
	})
	sub.frame.TextTruncate = Enum.TextTruncate.AtEnd
	sub.frame.Parent = body

	local badgeRow = Kit.List({ direction = "horizontal", gap = 6, name = "BadgeRow", layoutOrder = 4 })
	badgeRow.frame.Parent = body
	local badge = Kit.Badge({ text = state.badge, color = state.badgeColor, name = "State", layoutOrder = 1 })
	badgeRow.add(badge)
	local was = Kit.Label({
		text = state.wasText or "",
		size = "xs",
		color = "textDim",
		autoSize = "xy",
		name = "Was",
		layoutOrder = 2,
	})
	was.frame.Visible = state.wasText ~= nil
	badgeRow.add(was)

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
		update = function(s: View.CardState, sel: boolean)
			current = s
			selected = sel
			badge.setText(s.badge)
			badge.setColor(s.badgeColor)
			was.setText(s.wasText or "")
			was.frame.Visible = s.wasText ~= nil
			paint(Kit.Theme.get())
		end,
	}
end

return Cards
