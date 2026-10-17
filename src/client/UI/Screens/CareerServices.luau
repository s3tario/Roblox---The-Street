--!strict
-- CareerServices (client screen, owned by `careerPath`): the Career Services venue (spec §6 "Recovery", design
-- v3 §6 and §9). Neutral and calm: no pop-ups, no timers.
--   between jobs   what you lost / what you kept, then the options: the free re-entry interview, Career
--                  Reinstatement (a credit, or a Store link), Capital Reconstruction (a credit, or a Store link)
--                  and a fresh start back at campus recruiting
--   employed       a career check-in: status, the promotion headline, Rebirth (when it ships), lateral moves note
--   student        how recruiting works, and any pending offers
-- Server data comes from "Career.Services"; every action goes through CareerController.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Tracks = require(Shared.Config.Tracks)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Parts = script.Parent:WaitForChild("CareerParts")
local Common = require(Parts:WaitForChild("Common"))
local ReentryView = require(Parts:WaitForChild("Reentry"))

local CareerServices = { id = "CareerServices" }

local STORE_REINSTATE = "CareerReinstatement"
local STORE_CAPITAL = "CapitalReconstruction"

local function num(x: any, default: number): number
	if type(x) == "number" and x == x then
		return x
	end
	return default
end

function CareerServices.open(_args: any, root: Instance, ctx: any): { close: () -> () }
	local closed = false
	local busy = false
	local controller = Common.controller(ctx)
	local mode = "info" -- "info" | "reentry"
	local info: { [string]: any }? = nil
	local reentryState: { view: any, result: any? }? = nil

	local win = Kit.Window({
		title = Tracks.text("services_title"),
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(620, 720),
		onClose = ctx.close,
		name = "CareerServicesWindow",
	})
	win.frame.Parent = root
	local scroll = Kit.Scroll({ padding = 2, gap = 10, name = "Scroll" })
	scroll.frame.Parent = win.content

	local render: () -> ()
	local load: () -> ()

	local function fail(err: string?)
		Common.notify(ctx, if controller then controller:ErrorText(err) else Tracks.text("err_generic"), "bad")
	end

	-- runs an action off the UI thread, then reloads
	local function act(fn: () -> (boolean, string?), okText: string?)
		if busy or not controller then
			return
		end
		busy = true
		task.spawn(function()
			local ok, err = fn()
			busy = false
			if closed then
				return
			end
			if ok then
				if okText then
					Common.notify(ctx, okText, "good")
				end
			else
				fail(err)
			end
			load()
		end)
	end

	---------------------------------------------------------------------------------------------------
	-- Re-entry
	---------------------------------------------------------------------------------------------------
	local function reentry(action: string, answers: any?)
		if busy or not controller then
			return
		end
		busy = true
		task.spawn(function()
			local ok, err, view, result = controller:Reentry(action, answers)
			busy = false
			if closed then
				return
			end
			if not ok then
				fail(err)
				if view then
					reentryState = { view = view, result = nil }
				end
				render()
				return
			end
			if type(view) == "table" then
				mode = "reentry"
				reentryState = { view = view, result = result }
				if type(result) == "table" and result.done and result.passed and ctx.Sfx then
					pcall(ctx.Sfx.play, "promotion")
				end
			end
			render()
		end)
	end

	local function renderReentry()
		local state = reentryState
		if not state then
			mode = "info"
			render()
			return
		end
		ReentryView.build(scroll, state, {
			busy = busy,
			submit = function(answers: { [string]: any })
				reentry("submit", answers)
			end,
			continue = function()
				if reentryState then
					reentryState.result = nil
				end
				render()
			end,
			retry = function()
				reentry("start")
			end,
			back = function()
				mode = "info"
				reentryState = nil
				load()
			end,
		})
	end

	---------------------------------------------------------------------------------------------------
	-- Info
	---------------------------------------------------------------------------------------------------
	local function optionCard(title: string, desc: string, buttons: { any })
		local card = Kit.Card({ title = title, name = "Option" })
		card.add(Kit.Label({ text = desc, size = "sm", color = "textDim" }))
		for _, b in buttons do
			card.add(b)
		end
		scroll.add(card)
	end

	local function storeButton(productKey: string): any
		local hasStore = controller ~= nil and controller:HasStore()
		return Kit.Button({
			text = Tracks.text(if hasStore then "services_store" else "services_store_soon"),
			style = "secondary",
			fill = true,
			disabled = not hasStore,
			onClick = function()
				if controller and not controller:OpenStore(productKey) then
					Common.notify(ctx, Tracks.text("services_store_soon"), "info")
				end
			end,
		})
	end

	local function renderFired(i: { [string]: any })
		local f = i.fired
		scroll.add(Kit.Label({ text = Tracks.text("services_intro_fired"), size = "md" }))
		local lost = Kit.Card({ title = Tracks.text("services_lost"), name = "Lost" })
		lost.add(Kit.Label({
			text = "• " .. Tracks.text("services_lost_job", { title = f.title or "", company = f.companyName or "" }),
			size = "sm",
		}))
		lost.add(Kit.Label({ text = "• " .. Tracks.text("services_lost_pipeline"), size = "sm" }))
		lost.add(Kit.Label({
			text = "• " .. Tracks.text("services_lost_xp", { xp = Format.commas(math.floor(num(f.lostXp, 0))) }),
			size = "sm",
		}))
		lost.add(Kit.Label({
			text = "• " .. Tracks.text("services_lost_book", { book = Common.money(num(f.newBook, 0)) }),
			size = "sm",
		}))
		scroll.add(lost)
		local kept = Kit.Card({ title = Tracks.text("services_kept"), name = "Kept" })
		kept.add(Kit.Label({ text = Tracks.text("services_kept_list"), size = "sm", color = "textDim" }))
		scroll.add(kept)

		scroll.add(Kit.Heading({ text = Tracks.text("services_options"), level = 3 }))
		local reentryInProgress = type(i.reentry) == "table" and not i.reentry.done
		optionCard(
			Tracks.text("services_reentry"),
			Tracks.text("services_reentry_desc", { company = f.returnCompany or "", title = f.reentryTitle or "" }),
			{
				Kit.Button({
					text = Tracks.text(
						if reentryInProgress then "services_reentry_continue" else "services_reentry_start"
					),
					fill = true,
					onClick = function()
						reentry("start")
					end,
				}),
			}
		)
		local credits = math.floor(num(i.reinstateCredits, 0))
		optionCard(
			Tracks.text("services_reinstate"),
			Tracks.text("services_reinstate_desc", { title = f.title or "", company = f.returnCompany or "" }),
			{
				if credits > 0
					then Kit.Button({
						text = Tracks.text("services_reinstate_use") .. " (" .. credits .. ")",
						fill = true,
						onClick = function()
							act(function()
								return controller:Reinstate()
							end, nil)
						end,
					})
					else storeButton(STORE_REINSTATE),
			}
		)
		local capital = math.floor(num(i.capitalCredits, 0))
		if not f.capitalUsed then
			optionCard(Tracks.text("services_capital"), Tracks.text("services_capital_desc"), {
				if capital > 0 and i.capitalUsable
					then Kit.Button({
						text = Tracks.text("services_capital_use") .. " (" .. capital .. ")",
						fill = true,
						onClick = function()
							act(function()
								return controller:UseCapital()
							end, nil)
						end,
					})
					else storeButton(STORE_CAPITAL),
			})
		end
		optionCard(Tracks.text("services_fresh"), Tracks.text("services_fresh_desc"), {
			Kit.Button({
				text = Tracks.text("services_fresh_button"),
				style = "secondary",
				fill = true,
				onClick = function()
					ctx.UI:Confirm({
						title = Tracks.text("services_fresh_confirm_title"),
						body = Tracks.text("services_fresh_confirm_body"),
						confirmText = Tracks.text("services_fresh_button"),
						cancelText = Tracks.text("ui_cancel"),
					}, function(yes: boolean)
						if yes then
							act(function()
								return controller:FreshStart()
							end, nil)
						end
					end)
				end,
			}),
		})
	end

	local function renderEmployed(i: { [string]: any })
		local career = Common.careerOrEmpty(ctx)
		scroll.add(Kit.Label({ text = Tracks.text("services_intro_employed"), size = "md" }))
		local status = Kit.Card({ title = tostring(i.title or ""), subtitle = i.companyName, name = "Status" })
		status.add(Common.chip(Common.statusText(career.status), Common.statusColor(career.status)))
		local promo = if type(career.promotion) == "table" then career.promotion else {}
		if type(promo.headline) == "string" and promo.headline ~= "" then
			status.add(Kit.Label({ text = promo.headline, size = "sm", font = "bodyBold" }))
		end
		for _, line in (if type(promo.missing) == "table" then promo.missing else {}) :: { any } do
			if type(line) == "string" then
				status.add(Kit.Label({ text = "• " .. line, size = "sm", color = "textDim" }))
			end
		end
		status.add(Kit.Button({
			text = Tracks.text("ui_open_career"),
			style = "secondary",
			fill = true,
			onClick = function()
				ctx.UI:Open("Career")
			end,
		}))
		scroll.add(status)
		local rebirth = if type(i.rebirth) == "table" then i.rebirth else {}
		local rebirthButtons: { any } = {}
		if rebirth.available and controller and controller:HasScreen("Rebirth") then
			table.insert(
				rebirthButtons,
				Kit.Button({
					text = Tracks.text("services_open_rebirth"),
					fill = true,
					disabled = rebirth.can ~= true,
					onClick = function()
						ctx.UI:Open("Rebirth")
					end,
				})
			)
		end
		optionCard(
			Tracks.text("services_rebirth"),
			if rebirth.available
				then (if rebirth.can
					then Tracks.text("services_rebirth_desc")
					else (rebirth.reason or Tracks.text("services_rebirth_locked")))
				else Tracks.text("services_rebirth_soon"),
			rebirthButtons
		)
		scroll.add(Kit.Label({ text = Tracks.text("services_lateral"), size = "xs", color = "textDim" }))
	end

	local function renderStudent(_i: { [string]: any })
		scroll.add(Kit.Label({ text = Tracks.text("services_intro_student"), size = "md" }))
		local card = Kit.Card({ title = Tracks.text("ui_recruiting"), name = "Recruiting" })
		card.add(Kit.Label({ text = Tracks.text("services_recruiting"), size = "sm", color = "textDim" }))
		scroll.add(card)
	end

	render = function()
		if closed then
			return
		end
		scroll.clear()
		if mode == "reentry" then
			renderReentry()
			return
		end
		local i = info
		if not i then
			scroll.add(
				Kit.Label({ text = Tracks.text("ui_loading"), size = "md", color = "textDim", align = "center" })
			)
			return
		end
		if i.loaded == false then
			scroll.add(Kit.Label({ text = Tracks.text("err_not_loaded_short"), size = "md", color = "textDim" }))
			scroll.add(Kit.Button({ text = Tracks.text("ui_retry"), fill = true, onClick = load }))
			return
		end
		Common.safe(function()
			if i.status == "fired" and type(i.fired) == "table" then
				renderFired(i)
			elseif i.employed then
				renderEmployed(i)
			else
				renderStudent(i)
			end
			if num(i.offers, 0) > 0 then
				scroll.add(Kit.Button({
					text = Tracks.text("services_offers") .. " (" .. math.floor(num(i.offers, 0)) .. ")",
					fill = true,
					onClick = function()
						ctx.UI:Open("Offers")
					end,
				}))
			end
		end)
	end

	load = function()
		task.spawn(function()
			local fresh = if controller then controller:GetServices() else nil
			if closed then
				return
			end
			info = fresh or { loaded = false }
			render()
		end)
	end

	render()
	load()

	return {
		close = function()
			closed = true
			win.close()
		end,
	}
end

return CareerServices
