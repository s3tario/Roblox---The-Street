--!strict
-- Offers (client screen, owned by `careerPath`): pending job offers (contracts §5 GrantOffer / AcceptOffer).
-- Each card shows the firm's logo and tier, the title, pay, prestige, book, dress level, boss and culture.
-- Accept asks for confirmation (other offers are declined); the server hires the player and the HUD banner,
-- objective and theme follow from the replicated career.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local CareerState = require(Shared.Logic.CareerState)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Parts = script.Parent:WaitForChild("CareerParts")
local Common = require(Parts:WaitForChild("Common"))
local OfferCard = require(Parts:WaitForChild("OfferCard"))

local Offers = { id = "Offers" }

function Offers.open(_args: any, root: Instance, ctx: any): { close: () -> () }
	local closed = false
	local busy = false
	local conns: { any } = {}
	local controller = Common.controller(ctx)

	local win = Kit.Window({
		title = Tracks.text("offers_title"),
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(620, 720),
		onClose = ctx.close,
		name = "OffersWindow",
	})
	win.frame.Parent = root
	local scroll = Kit.Scroll({ padding = 2, gap = 10, name = "Scroll" })
	scroll.frame.Parent = win.content

	local render: () -> ()

	local function accept(offer: any)
		if busy or not controller then
			return
		end
		local career = Common.careerOrEmpty(ctx)
		local company = Companies.get(offer.companyId)
		local role = Tracks.rankDef(offer.track, offer.rank)
		local current = Companies.get(career.companyId)
		local body = if CareerState.isEmployed(career) and current
			then Tracks.text("offers_confirm_lateral", {
				current = current.name,
				company = if company then company.name else "",
				title = if role then role.title else "",
			})
			else Tracks.text("offers_confirm_body", {
				company = if company then company.name else "",
				title = if role then role.title else "",
			})
		ctx.UI:Confirm({
			title = Tracks.text("offers_confirm_title"),
			body = body,
			confirmText = Tracks.text("offers_accept"),
			cancelText = Tracks.text("ui_cancel"),
		}, function(yes: boolean)
			if not yes or closed then
				return
			end
			busy = true
			task.spawn(function()
				local ok, err = controller:AcceptOffer(offer.id)
				busy = false
				if closed then
					return
				end
				if ok then
					if ctx.Sfx then
						pcall(ctx.Sfx.play, "promotion")
					end
					ctx.close()
				else
					Common.notify(ctx, controller:ErrorText(err), "bad")
					render()
				end
			end)
		end)
	end

	local function decline(offer: any)
		if busy or not controller then
			return
		end
		busy = true
		task.spawn(function()
			local ok, err = controller:DeclineOffer(offer.id)
			busy = false
			if closed then
				return
			end
			if ok then
				Common.notify(ctx, Tracks.text("offer_declined"), "info")
			else
				Common.notify(ctx, controller:ErrorText(err), "bad")
			end
		end)
	end

	render = function()
		if closed then
			return
		end
		local keep = scroll.frame.CanvasPosition
		scroll.clear()
		task.defer(function()
			if not closed and scroll.frame.Parent then
				scroll.frame.CanvasPosition = keep
			end
		end)
		local career = Common.careerOrEmpty(ctx)
		local offers = if type(career.offers) == "table" then career.offers else {}
		if #offers == 0 then
			local empty = Kit.Card({ name = "Empty" })
			empty.add(
				Kit.Label({ text = Tracks.text("offers_empty"), size = "md", color = "textDim", align = "center" })
			)
			scroll.add(empty)
			return
		end
		for _, offer in offers do
			if type(offer) == "table" then
				local card = OfferCard.build(offer, career, { onAccept = accept, onDecline = decline })
				if card then
					scroll.add(card)
				end
			end
		end
	end
	render()

	local store = ctx.Store
	if store then
		local ok, conn = pcall(function()
			-- re-render only when the offers themselves change (the career replicates often)
			local signature = ""
			local function sig(): string
				local c = Common.careerOrEmpty(ctx)
				local parts: { string } = {}
				for _, o in (if type(c.offers) == "table" then c.offers else {}) :: { any } do
					table.insert(parts, tostring(o.id) .. ":" .. tostring(o.rank))
				end
				return table.concat(parts, ",") .. "|" .. tostring(c.outfitLevel)
			end
			signature = sig()
			return store:Changed("career"):Connect(function()
				local now = sig()
				if now ~= signature then
					signature = now
					task.defer(render)
				end
			end)
		end)
		if ok and conn then
			table.insert(conns, conn)
		end
	end

	return {
		close = function()
			closed = true
			for _, c in conns do
				pcall(function()
					c:Disconnect()
				end)
			end
			win.close()
		end,
	}
end

return Offers
