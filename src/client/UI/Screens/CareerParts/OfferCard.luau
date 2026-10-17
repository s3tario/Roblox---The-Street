--!strict
-- CareerParts/OfferCard (client): one job offer on the Offers screen: firm logo, tier, title, pay, prestige,
-- trading book, dress level (with a warning when the player's outfit is below it), boss, culture, the top-title
-- school gate and Accept / Decline.
--   OfferCard.build(offer, career, handlers) -> Kit.Card
--       handlers = { onAccept = (offer) -> (), onDecline = (offer) -> () }

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local Common = require(script.Parent.Common)
local Kit = Common.Kit

local OfferCard = {}

export type Handlers = { onAccept: (offer: any) -> (), onDecline: (offer: any) -> () }

local function num(x: any, default: number): number
	if type(x) == "number" and x == x then
		return x
	end
	return default
end

function OfferCard.build(offer: { [string]: any }, career: { [string]: any }, handlers: Handlers): any
	local company = Companies.get(offer.companyId)
	local track = Tracks.get(offer.track)
	local role = Tracks.rankDef(offer.track, offer.rank)
	if not company or not track or not role then
		return nil
	end
	local card = Kit.Card({ name = "Offer_" .. tostring(offer.id), padding = 14 })

	local top = Kit.frame("Top", UDim2.new(1, 0, 0, 64))
	top.LayoutOrder = 1
	top.Parent = card.content
	local logoBox = Kit.frame("Logo", UDim2.fromOffset(64, 64))
	logoBox.Parent = top
	Common.logo(logoBox, company.logo, { background = true, corner = 0.18, px = 64 }, company.short)
	local text = Kit.frame("Text", UDim2.new(1, -76, 1, 0))
	text.Position = UDim2.fromOffset(76, 0)
	text.Parent = top
	Kit.list(text, false, 2)
	Kit.Label({ text = company.name, size = "lg", font = "heading", layoutOrder = 1 }).frame.Parent = text
	Kit.Label({
		text = Common.text("offers_tier", { type = company.typeName, tier = company.tier }),
		size = "xs",
		color = "textDim",
		layoutOrder = 2,
	}).frame.Parent =
		text
	local chip = Common.chip(role.title .. " · " .. track.short, "accent")
	chip.frame.LayoutOrder = 3
	chip.frame.Parent = text

	local info = Kit.frame("Info", UDim2.new(1, 0, 0, 0))
	info.AutomaticSize = Enum.AutomaticSize.Y
	info.LayoutOrder = 2
	Kit.list(info, false, 4)
	info.Parent = card.content
	Common.row(
		info,
		Common.text("offers_pay"),
		Common.text("offers_pay_value", {
			salary = Common.money(role.salary * company.payMult),
			bonus = Common.money(role.bonus * company.payMult),
		}),
		1,
		true
	)
	Common.row(
		info,
		Common.text("offers_prestige"),
		Common.text("offers_prestige_value", { mult = company.prestigeMult }),
		2,
		true
	)
	Common.row(info, Common.text("offers_book"), Common.compact(role.book * company.bookMult), 3, true)
	local need = math.max(company.minOutfitLevel, Tracks.dressLevelFor(role))
	Common.row(info, Common.text("offers_dress"), Common.text("offers_dress_value", { need = need }), 4)
	Common.row(info, Common.text("offers_boss"), Companies.bossName(company.id, offer.track), 5)

	local current = math.floor(num(career.outfitLevel, 1))
	if current < need then
		card.add(Kit.Label({
			text = Common.text("offers_dress_short", { current = current }),
			size = "xs",
			color = "warn",
		}))
	end
	card.add(Kit.Label({ text = company.culture, size = "sm", color = "text" }))
	if company.tagline ~= "" then
		card.add(Kit.Label({ text = "“" .. company.tagline .. "”", size = "xs", color = "textDim" }))
	end
	local topRole = track.ladder[#track.ladder]
	if topRole and topRole.schoolGate then
		card.add(Kit.Label({
			text = Common.text("offers_gate", { title = topRole.title, tier = Tracks.tierName(topRole.schoolGate) }),
			size = "xs",
			color = "textDim",
		}))
	end
	local sourceKey = "source_" .. tostring(offer.source)
	if Tracks.strings[sourceKey] then
		card.add(Kit.Label({
			text = Common.text("offers_source", { source = Common.text(sourceKey) }),
			size = "xs",
			color = "textDim",
		}))
	end

	local buttons = Kit.List({ direction = "horizontal", gap = 8, autoSize = "y", name = "Buttons" })
	buttons.frame.Size = UDim2.new(1, 0, 0, 0)
	card.add(buttons)
	local accept = Kit.Button({
		text = Common.text("offers_accept"),
		style = "primary",
		size = UDim2.new(0.5, -4, 0, Kit.TAP),
		onClick = function()
			handlers.onAccept(offer)
		end,
	})
	buttons.add(accept)
	local decline = Kit.Button({
		text = Common.text("offers_decline"),
		style = "ghost",
		size = UDim2.new(0.5, -4, 0, Kit.TAP),
		onClick = function()
			handlers.onDecline(offer)
		end,
	})
	buttons.add(decline)
	return card
end

return OfferCard
