--!strict
-- Recruiting (client screen, owned by `tutorial`; spec v2 §4b, design v3 §2-§4): the campus Recruiting Board.
-- Every investment bank from Config/Companies with its logo, tier, dress level and honest eligibility (the exact
-- reasons when a door is closed), the exact offer odds before you ask for a decision, and one action per firm:
-- Apply -> first-round interview -> Superday -> Request decision -> View offer. Sterling & Vance's walk-on seat
-- is always open and never uses one of the 5 application slots.
-- The board comes from the server ("Recruiting.Board" through TutorialController:Recruiting); every action returns
-- the fresh board. Interviews are real Work tasks: starting one opens the Work screen.
--   args = {}?   (opened by the bulletin prompt, the advisor, or the Quests app)
-- Parts: Firm (one firm's card and the shared text helpers).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Firm = require(script:WaitForChild("Firm"))

local Recruiting = { id = "Recruiting" }

type Scroll = { frame: ScrollingFrame, add: (child: any) -> GuiObject, clear: () -> () }

local REFRESH_DEBOUNCE = 0.6
local STAGE_ORDER = Firm.STAGE_ORDER
local pct = Firm.pct
local errText = Firm.errText

local function text(key: string, vars: { [string]: any }?): string
	return Quests.text(key, vars)
end

local function controllerOf(ctx: any): any
	local registry = if type(ctx) == "table" then ctx.Registry else nil
	if not registry then
		return nil
	end
	local ok, c = pcall(function()
		return registry.get("TutorialController")
	end)
	return if ok then c else nil
end

---------------------------------------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------------------------------------
function Recruiting.open(_args: any, root: Instance, ctx: any): { close: () -> () }
	local controller = controllerOf(ctx)
	local ui = if type(ctx) == "table" then ctx.UI else nil
	local closed = false
	local busy = false
	local conns: { any } = {}
	local board: { [string]: any }? = nil
	local loading = true
	local buttons: { Kit.Button } = {}

	local function notify(msg: string, kind: string?)
		if ui and type(ui.Notify) == "function" then
			ui:Notify(msg, kind)
		end
	end
	local function openScreen(id: string)
		if ui and type(ui.Open) == "function" then
			ui:Open(id, {})
		end
	end

	local win = Kit.Window({
		title = text("recruit_title"),
		subtitle = text("recruit_subtitle", { used = 0, max = Quests.recruiting.maxApplications }),
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(680, 760),
		onClose = if type(ctx) == "table" then ctx.close else nil,
		name = "RecruitingWindow",
	})
	win.frame.Parent = root
	local scroll: Scroll = Kit.Scroll({ padding = 2, gap = 10, name = "Scroll" })
	scroll.frame.Parent = win.content

	local render: () -> ()
	local run: (action: string, firm: { [string]: any }) -> ()

	local function setBusy(on: boolean)
		busy = on
		for _, b in buttons do
			b.setDisabled(on)
		end
	end

	local function firmCard(firm: { [string]: any })
		local panel, b = Firm.card(firm, { busy = busy, onAction = run })
		if b then
			table.insert(buttons, b)
		end
		scroll.add(panel)
	end

	local function section(title: string)
		scroll.add(Kit.Label({ text = title, size = "sm", font = "bodyBold", color = "textDim", name = "Section" }))
	end

	render = function()
		if closed then
			return
		end
		local keep = scroll.frame.CanvasPosition
		scroll.clear()
		table.clear(buttons)
		local b = board
		if not b then
			scroll.add(Kit.Label({
				text = if loading then text("card_loading") else text("recruit_err_generic"),
				color = "textDim",
				align = "center",
				name = "Loading",
			}))
			if not loading then
				local retry = Kit.Button({
					text = text("recruit_retry_load"),
					style = "secondary",
					name = "Reload",
					onClick = function()
						loading = true
						render()
						task.spawn(function()
							if controller then
								local ok, _err, fresh = controller:Recruiting("Board")
								if ok and type(fresh) == "table" then
									board = fresh
								end
							end
							loading = false
							render()
						end)
					end,
				})
				scroll.add(retry)
			end
			return
		end
		win.setSubtitle(
			text("recruit_subtitle", { used = b.used or 0, max = b.max or Quests.recruiting.maxApplications })
		)
		scroll.add(Kit.Label({
			text = text("recruit_intro", { max = b.max or Quests.recruiting.maxApplications }),
			size = "sm",
			color = "textDim",
			name = "Intro",
		}))
		if b.built ~= true then
			local card = Kit.Card({ title = text("recruit_err_no_profile"), name = "NotBuilt" })
			card.add(Kit.Button({
				text = text("recruit_open_life_roll"),
				fill = true,
				name = "LifeRoll",
				onClick = function()
					openScreen("LifeRoll")
				end,
			}))
			scroll.add(card)
		elseif b.hired == true then
			scroll.add(Kit.Label({ text = text("recruit_err_employed"), size = "sm", color = "warn", name = "Hired" }))
		end
		local offers = if type(b.offers) == "number" then b.offers else 0
		if offers > 0 and b.hired ~= true then
			local card = Kit.Card({
				title = text(if offers == 1 then "recruit_offers_one" else "recruit_offers_many", { n = offers }),
				name = "OffersWaiting",
			})
			card.add(Kit.Button({
				text = text("recruit_view_offers"),
				fill = true,
				name = "OpenOffers",
				onClick = function()
					openScreen("Offers")
				end,
			}))
			scroll.add(card)
		end

		local firms = if type(b.firms) == "table" then b.firms else {}
		local apps, open, shut = {}, {}, {}
		for i, f in firms do
			if type(f) == "table" then
				f._i = i
				if type(f.stage) == "string" then
					table.insert(apps, f)
				elseif f.eligible == true then
					table.insert(open, f)
				else
					table.insert(shut, f)
				end
			end
		end
		table.sort(apps, function(x: any, y: any): boolean
			local ox, oy = STAGE_ORDER[x.stage] or 99, STAGE_ORDER[y.stage] or 99
			if ox ~= oy then
				return ox < oy
			end
			return x._i < y._i
		end)
		if #apps > 0 then
			section(text("recruit_section_apps"))
			for _, f in apps do
				firmCard(f)
			end
		end
		if #open > 0 then
			section(text("recruit_section_open"))
			for _, f in open do
				firmCard(f)
			end
		end
		if #shut > 0 then
			section(text("recruit_section_closed"))
			for _, f in shut do
				firmCard(f)
			end
		end
		task.defer(function()
			if not closed and scroll.frame.Parent then
				scroll.frame.CanvasPosition = keep
			end
		end)
	end

	local function showResult(result: { [string]: any })
		local offer = result.outcome == "offer"
		local company = tostring(result.company or "")
		pcall(Kit.modal, { width = 420, dismissable = true, name = "RecruitingResult" }, function(card, close)
			Kit.list(card, false, 10)
			Kit.Heading({
				text = text(if offer then "recruit_result_offer" else "recruit_result_rejected"),
				level = 2,
				color = if offer then "good" else "text",
				layoutOrder = 1,
			}).frame.Parent =
				card
			Kit.Label({
				text = if offer
					then text("recruit_offer", { company = company })
					else text("recruit_rejected", { company = company, chance = pct(result.chance) }),
				size = "md",
				layoutOrder = 2,
			}).frame.Parent =
				card
			if offer then
				Kit.Button({
					text = text("recruit_view_offers"),
					fill = true,
					layoutOrder = 3,
					name = "OpenOffers",
					onClick = function()
						close()
						openScreen("Offers")
					end,
				}).frame.Parent =
					card
			end
			Kit.Button({
				text = text(if offer then "recruit_later" else "recruit_ok"),
				style = "ghost",
				fill = true,
				layoutOrder = 4,
				name = "Dismiss",
				onClick = close,
			}).frame.Parent =
				card
		end)
	end

	local function call(action: string, firm: { [string]: any })
		if busy or closed or not controller then
			return
		end
		setBusy(true)
		task.spawn(function()
			local ok, err, fresh, result = controller:Recruiting(action, firm.id)
			if closed then
				return
			end
			setBusy(false)
			if type(fresh) == "table" then
				board = fresh
			end
			if not ok then
				notify(errText(err), "warn")
			elseif action == "Decide" and type(result) == "table" then
				showResult(result)
			end
			render()
		end)
	end

	run = function(action: string, firm: { [string]: any })
		if action == "offers" then
			openScreen("Offers")
		elseif action == "apply" then
			call("Apply", firm)
		elseif action == "interview" or action == "superday" then
			call("Start", firm)
		elseif action == "retry" then
			call("Retry", firm)
		elseif action == "decide" then
			local body = text("recruit_confirm_body", {
				company = tostring(firm.name or firm.id),
				chance = pct(firm.chance),
			})
			if ui and type(ui.Confirm) == "function" then
				ui:Confirm({
					title = text("recruit_confirm_title"),
					body = body,
					confirmText = text("recruit_confirm_ok"),
				}, function(yes: boolean)
					if yes then
						call("Decide", firm)
					end
				end)
			else
				call("Decide", firm)
			end
		end
	end

	local fetching = false
	local function fetch()
		if fetching or closed or not controller then
			return
		end
		fetching = true
		task.spawn(function()
			local ok, _err, fresh = controller:Recruiting("Board")
			fetching = false
			loading = false
			if closed then
				return
			end
			if ok and type(fresh) == "table" then
				board = fresh
			end
			if not busy then
				render()
			end
		end)
	end

	render()
	if controller then
		fetch()
	else
		loading = false
		render()
	end

	local pending = false
	local function schedule()
		if pending or closed then
			return
		end
		pending = true
		task.delay(REFRESH_DEBOUNCE, function()
			pending = false
			if not busy then
				fetch()
			end
		end)
	end
	local store = if type(ctx) == "table" then ctx.Store else nil
	if store then
		for _, key in { "campus", "career", "profile" } do
			local ok, conn = pcall(function()
				return store:Changed(key):Connect(schedule)
			end)
			if ok and conn then
				table.insert(conns, conn)
			end
		end
	end

	return {
		close = function()
			if closed then
				return
			end
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

return Recruiting
