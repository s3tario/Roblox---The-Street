--!strict
-- Shop screen: the details panel for the selected item. Name, subtitle (brand and rarity, or category and slot
-- kinds), the clothing level with the firm's dress code ("Meets your firm's Level 4", v3 §5), the description, where
-- a decor piece fits, the price (with the struck "was" price during a sale) and one action button whose text and
-- enabled state come from View.cardState (Buy · $1,500 / Short $300 / Wear it / Place it / Open Store).
--
--   Detail.build(opts) -> Detail     opts = { onAction: (entry, state) -> () }
--   detail.frame                     a Frame that fills its parent (scrolls when short)
--   detail.show(entry?, state?, firmLevel?)   nil entry shows the "tap an item" hint
--   detail.setBusy(busy)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared.Config.Shop)
local Format = require(Shared.Util.Format)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local View = require(script.Parent.View)

local Detail = {}

export type Detail = {
	frame: Frame,
	show: (entry: View.Entry?, state: View.CardState?, firmLevel: number?) -> (),
	setBusy: (busy: boolean) -> (),
}
export type Opts = { onAction: (entry: View.Entry, state: View.CardState) -> () }

local BUTTON_H = 48

function Detail.build(opts: Opts): Detail
	local root = Kit.frame("Detail", UDim2.fromScale(1, 1))

	local scroll = Kit.Scroll({ gap = 6, name = "Info", padding = 2 })
	scroll.frame.Size = UDim2.new(1, 0, 1, -(BUTTON_H + 8))
	scroll.frame.Parent = root

	local hint = Kit.Label({ text = Shop.text("select_hint"), color = "textDim", name = "Hint", layoutOrder = 0 })
	scroll.add(hint)
	local name = Kit.Heading({ text = "", level = 3, name = "Name", layoutOrder = 1 })
	scroll.add(name)
	local subtitle = Kit.Label({ text = "", size = "sm", color = "textDim", name = "Subtitle", layoutOrder = 2 })
	scroll.add(subtitle)

	local badges = Kit.List({ direction = "horizontal", gap = 6, wraps = true, name = "Badges", layoutOrder = 3 })
	badges.frame.Size = UDim2.new(1, 0, 0, 0)
	badges.frame.AutomaticSize = Enum.AutomaticSize.Y
	scroll.add(badges)
	local level = Kit.Badge({ text = "", color = "surface", name = "Level", layoutOrder = 1 })
	badges.add(level)
	local levelNote = Kit.Badge({ text = "", color = "good", name = "LevelNote", layoutOrder = 2 })
	badges.add(levelNote)
	local stateBadge = Kit.Badge({ text = "", color = "surface", name = "State", layoutOrder = 3 })
	badges.add(stateBadge)

	local desc = Kit.Label({ text = "", size = "sm", name = "Desc", layoutOrder = 4 })
	scroll.add(desc)
	local fits = Kit.Label({ text = "", size = "xs", color = "textDim", name = "Fits", layoutOrder = 5 })
	scroll.add(fits)
	local where = Kit.Label({ text = "", size = "xs", color = "textDim", name = "Where", layoutOrder = 6 })
	scroll.add(where)

	local priceRow = Kit.List({ direction = "horizontal", gap = 8, name = "PriceRow", layoutOrder = 7 })
	scroll.add(priceRow)
	local price = Kit.Label({ text = "", size = "lg", font = "mono", autoSize = "xy", name = "Price", layoutOrder = 1 })
	priceRow.add(price)
	local was = Kit.Label({ text = "", size = "sm", color = "textDim", autoSize = "xy", name = "Was", layoutOrder = 2 })
	priceRow.add(was)
	local reason = Kit.Label({ text = "", size = "xs", color = "warn", name = "Reason", layoutOrder = 8 })
	scroll.add(reason)

	local current: View.Entry? = nil
	local currentState: View.CardState? = nil
	local busy = false

	local action = Kit.Button({
		text = "",
		style = "primary",
		fill = true,
		name = "Action",
		onClick = function()
			local e, s = current, currentState
			if busy or not e or not s or not s.enabled then
				return
			end
			opts.onAction(e, s)
		end,
	})
	action.frame.AnchorPoint = Vector2.new(0, 1)
	action.frame.Position = UDim2.fromScale(0, 1)
	action.frame.Size = UDim2.new(1, 0, 0, BUTTON_H)
	action.frame.Parent = root

	local function paintAction()
		local s = currentState
		if not current or not s then
			action.frame.Visible = false
			return
		end
		action.frame.Visible = s.actionText ~= ""
		action.setText(if busy then Shop.text("busy") else s.actionText)
		action.setStyle(if s.action == "buy" then "primary" else "secondary")
		action.setDisabled(busy or not s.enabled)
	end

	local function show(entry: View.Entry?, state: View.CardState?, firmLevel: number?)
		current = entry
		currentState = state
		local has = entry ~= nil and state ~= nil
		hint.frame.Visible = not has
		local frames: { GuiObject } = { name.frame, subtitle.frame, badges.frame, desc.frame, priceRow.frame }
		for _, f in frames do
			f.Visible = has
		end
		if not entry or not state then
			fits.frame.Visible = false
			where.frame.Visible = false
			reason.frame.Visible = false
			paintAction()
			return
		end
		local item = entry.item
		name.setText(item.name)
		subtitle.setText(View.subtitle(entry))
		local rarity = View.rarity(entry)
		subtitle.setColor(if entry.kind == "wearable" then rarity.color else "textDim")
		local levelText = View.levelBadge(entry)
		level.setText(levelText or "")
		level.frame.Visible = levelText ~= nil
		local note, ok = View.levelNote(entry, firmLevel)
		levelNote.setText(note or "")
		levelNote.setColor(if ok then "good" else "warn")
		levelNote.frame.Visible = note ~= nil
		stateBadge.setText(state.badge)
		stateBadge.setColor(state.badgeColor)
		stateBadge.frame.Visible = state.state == "owned" or state.state == "wearing"
		desc.setText(item.desc or "")
		local isDecor = entry.kind == "decor"
		fits.frame.Visible = isDecor
		where.frame.Visible = isDecor
		if isDecor then
			fits.setText(View.decorFits(item))
			where.setText(View.decorWhere(item))
		end
		local showPrice = state.state == "buy" or state.state == "free" or state.state == "rank"
		priceRow.frame.Visible = showPrice
		price.setText(if state.price > 0 then Format.money(state.price) else Shop.text("free"))
		was.setText(state.wasText or "")
		was.frame.Visible = state.wasText ~= nil
		reason.setText(state.reason or "")
		reason.frame.Visible = state.reason ~= nil
		paintAction()
	end

	show(nil, nil, nil)

	return {
		frame = root,
		show = show,
		setBusy = function(b: boolean)
			busy = b
			paintAction()
		end,
	}
end

return Detail
