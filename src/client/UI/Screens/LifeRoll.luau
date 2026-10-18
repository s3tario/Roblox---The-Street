--!strict
-- LifeRoll screen (client UI, careerCore; design v3 §2). Steps:
--   name    type a first name (2-16 letters; filtered on the server)
--   spin    seven reels spin to the SERVER's rolled life and land one after another (School, Degree, GPA, Family,
--           Clubs, Stats, Starting outfit), each flashing its rarity colour; Mythic bursts prismatic
--   review  reroll any ONE field at a time (free rerolls, then Refresh tokens, then Reroll credits, then the Store),
--           see the exact odds, edit the name, then lock in
--   done    the finished MyCareer card
--   built   (reopened after lock-in) the card, plus Background Rebuild when the player owns a credit
-- Opened automatically by CareerCoreController on a first join and by the campus "profile_builder" interact.
-- Screen contract: { id, hideHud, open(args, root, ctx) -> { close } }.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.LifeRoll)
local LifeRoll = require(Shared.Logic.LifeRoll)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Parts = script.Parent:WaitForChild("LifeRollParts")
local Common = require(Parts:WaitForChild("Common"))
local Rows = require(Parts:WaitForChild("Rows"))
local StatCard = require(Parts:WaitForChild("StatCard"))
local Odds = require(Parts:WaitForChild("Odds"))
local RebuildModal = require(Parts:WaitForChild("Rebuild"))

local LifeRollScreen = { id = "LifeRoll", hideHud = true }

local BAR_H = 56

function LifeRollScreen.open(_args: any, root: Instance, ctx: any): { close: () -> () }
	local c = if type(ctx) == "table" then ctx else {}
	local api = Common.api(c)
	local store = c.Store
	local ui = c.UI
	local closeScreen: (() -> ())? = if type(c.close) == "function" then c.close else nil

	local alive = true
	local mode = ""
	local busy = false
	local spinning = false
	local counts: { [string]: any }? = nil -- latest reroll counts from a remote answer (until the Store catches up)
	local cleanups: { () -> () } = {}
	local rows: { [string]: Rows.Row } = {}

	local function notify(text: string, kind: string?)
		if ui and type(ui.Notify) == "function" then
			ui:Notify(text, kind)
		end
	end

	local function getProfile(): any
		if store and type(store.Get) == "function" then
			local ok, p = pcall(function()
				return store:Get("profile")
			end)
			if ok and type(p) == "table" then
				return p
			end
		end
		local p = api:GetProfile()
		return if type(p) == "table" then p else nil
	end

	local win = Kit.Window({
		title = Config.text("title_liferoll"),
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(760, 720),
		onClose = closeScreen,
		name = "LifeRollWindow",
	})
	win.frame.Parent = root

	local body = Kit.frame("Body")
	body.Parent = win.content

	local function clearBody()
		for _, fn in cleanups do
			pcall(fn)
		end
		table.clear(cleanups)
		table.clear(rows)
		for _, child in body:GetChildren() do
			child:Destroy()
		end
	end

	local showName: (rename: boolean) -> ()
	local showRows: (spinFirst: boolean) -> ()
	local showDone: (view: any) -> ()
	local showBuilt: () -> ()

	local function route()
		local p = getProfile()
		if not p then
			clearBody()
			mode = "loading"
			local wait = Kit.Label({ text = Config.err("not_loaded"), align = "center", color = "textDim" })
			wait.frame.Parent = body
		elseif p.built == true then
			if mode ~= "done" then
				showBuilt()
			end
		elseif LifeRoll.hasPending(p) and type(p.firstName) == "string" and p.firstName ~= "" then
			showRows(false)
		else
			showName(false)
		end
	end

	---------------------------------------------------------------------------------------------------
	-- Name
	---------------------------------------------------------------------------------------------------
	showName = function(rename: boolean)
		clearBody()
		mode = "name"
		win.setSubtitle(nil)
		local scroll = Kit.Scroll({ gap = 12, name = "NameStep" })
		scroll.frame.Parent = body
		scroll.add(Kit.Heading({ text = Config.text("name_title"), level = 1 }))
		scroll.add(Kit.Label({ text = Config.text("name_body"), color = "textDim" }))
		local p = getProfile()
		local input = Kit.TextInput({
			value = if p and type(p.firstName) == "string" then p.firstName else "",
			placeholder = Config.text("name_placeholder"),
			maxLength = Config.rules.nameMax,
			name = "NameInput",
		})
		scroll.add(input)
		scroll.add(Kit.Label({ text = Config.text("name_hint"), size = "sm", color = "textDim" }))
		local go: Kit.Button
		local function submit()
			if busy then
				return
			end
			local name, err = LifeRoll.validName(input.get())
			if not name then
				Kit.sound("error")
				notify(Config.err(err), "warn")
				return
			end
			busy = true
			go.setText(Config.text("name_checking"))
			go.setDisabled(true)
			task.spawn(function()
				local ok, errKey, payload = api:SetName(name)
				busy = false
				if not alive or mode ~= "name" then
					return
				end
				if ok then
					showRows(type(payload) == "table" and payload.started == true)
				else
					go.setText(Config.text(if rename then "name_rename" else "name_go"))
					go.setDisabled(false)
					Kit.sound("error")
					notify(Config.err(errKey), "warn")
				end
			end)
		end
		go = Kit.Button({
			text = Config.text(if rename then "name_rename" else "name_go"),
			icon = if rename then nil else "🎰",
			fill = true,
			name = "NameGo",
			onClick = submit,
		})
		scroll.add(go)
		if rename then
			scroll.add(Kit.Button({
				text = Config.text("lock_cancel"),
				style = "ghost",
				fill = true,
				onClick = function()
					showRows(false)
				end,
			}))
		end
	end

	---------------------------------------------------------------------------------------------------
	-- Spin / review
	---------------------------------------------------------------------------------------------------
	-- (button text, true when nothing is left to spend and the button leads to the Store)
	local function rerollState(p: any): (string, boolean)
		local src = if counts then counts else p
		local probe = {
			rerollsLeft = src and src.rerollsLeft,
			refreshTokens = src and src.refreshTokens,
			credits = src and src.credits or {},
		}
		local source = LifeRoll.rerollSource(probe)
		if source == "free" then
			return Config.text("reroll_free", { n = probe.rerollsLeft }), false
		elseif source == "token" then
			return Config.text("reroll_token", { n = probe.refreshTokens }), false
		elseif source == "credit" then
			return Config.text("reroll_credit", { n = probe.credits.reroll }), false
		end
		return Config.text("reroll_buy"), true
	end

	local lockBtn: Kit.Button? = nil
	local skipBtn: Kit.Button? = nil
	local renameBtn: Kit.Button? = nil
	local oddsBtn: Kit.Button? = nil

	local function refreshButtons()
		if mode ~= "rows" then
			return
		end
		local p = getProfile()
		local text, buy = rerollState(p)
		for _, row in rows do
			row.setButton(text, if buy then "primary" else "secondary", busy or spinning)
		end
		if lockBtn then
			lockBtn.setDisabled(busy or spinning)
		end
		if renameBtn then
			renameBtn.setDisabled(busy or spinning)
		end
		if skipBtn then
			skipBtn.frame.Visible = spinning
		end
		if lockBtn then
			lockBtn.frame.Visible = not spinning
		end
		local src = counts or p or {}
		win.setSubtitle(
			Config.text("rerolls_left", { n = tonumber(src.rerollsLeft) or 0 })
				.. "  ·  "
				.. Config.text("tokens_left", { n = tonumber(src.refreshTokens) or 0 })
				.. "  ·  "
				.. Config.text("credits_left", {
					n = if type(src.credits) == "table" then tonumber(src.credits.reroll) or 0 else 0,
				})
		)
	end

	local function buyRerolls()
		api:BuyReroll()
	end

	local function reroll(field: string)
		if busy or spinning then
			return
		end
		local p = getProfile()
		if not p then
			return
		end
		local probe = counts or p
		if
			LifeRoll.rerollSource({
				rerollsLeft = probe.rerollsLeft,
				refreshTokens = probe.refreshTokens,
				credits = probe.credits or {},
			}) == nil
		then
			buyRerolls()
			return
		end
		busy = true
		refreshButtons()
		task.spawn(function()
			local ok, err, payload = api:Reroll(field)
			if not alive or mode ~= "rows" then
				busy = false
				return
			end
			local row = rows[field]
			if ok and type(payload) == "table" and row then
				counts = {
					rerollsLeft = payload.rerollsLeft,
					refreshTokens = payload.refreshTokens,
					credits = payload.credits,
				}
				spinning = true
				busy = false
				refreshButtons()
				row.set(payload.value, true, Config.SPIN.reroll, function()
					spinning = false
					refreshButtons()
				end)
			else
				busy = false
				refreshButtons()
				if err == "needs_purchase" then
					buyRerolls()
				else
					notify(Config.err(err), "bad")
				end
			end
		end)
	end

	local function confirmLock()
		local p = getProfile()
		if busy or spinning or not p then
			return
		end
		local pending = LifeRoll.normalizeRoll(p.pending)
		if not pending then
			return
		end
		local left = tonumber((counts or p).rerollsLeft) or 0
		local vars = {
			name = p.firstName,
			school = LifeRoll.describe("school", pending.school),
			n = left,
		}
		Kit.Confirm({
			title = Config.text("lock_title"),
			body = Config.text(if left > 0 then "lock_body_rerolls" else "lock_body", vars),
			confirmText = Config.text("lock_confirm"),
			cancelText = Config.text("lock_cancel"),
		}, function(yes: boolean)
			if not yes or not alive or busy then
				return
			end
			busy = true
			refreshButtons()
			task.spawn(function()
				local ok, err, view = api:Lock()
				busy = false
				if not alive then
					return
				end
				if ok then
					showDone(if type(view) == "table" then view else api:PublicView(getProfile()))
				else
					refreshButtons()
					notify(Config.err(err), "bad")
				end
			end)
		end)
	end

	showRows = function(spinFirst: boolean)
		clearBody()
		mode = "rows"
		counts = nil
		local p = getProfile()
		local pending = if p then LifeRoll.normalizeRoll(p.pending) else nil
		if not pending then
			showName(false)
			return
		end

		local scroll = Kit.Scroll({ gap = 8, name = "Rows", size = UDim2.new(1, 0, 1, -(BAR_H + 8)) })
		scroll.frame.Parent = body
		scroll.add(Kit.Label({
			text = Config.text("review_body"),
			size = "sm",
			color = "textDim",
			name = "Hint",
		}))
		for i, field in Config.FIELDS do
			local row = Rows.new(field, {
				layoutOrder = i + 1,
				onReroll = function()
					reroll(field)
				end,
			})
			rows[field] = row
			scroll.add(row.frame)
		end

		local bar = Kit.List({
			direction = "horizontal",
			gap = 8,
			justify = "end",
			name = "Bar",
			size = UDim2.new(1, 0, 0, BAR_H),
			autoSize = "none",
		})
		bar.frame.AnchorPoint = Vector2.new(0, 1)
		bar.frame.Position = UDim2.fromScale(0, 1)
		bar.frame.Parent = body
		oddsBtn = Kit.Button({
			text = Config.text("odds"),
			icon = "%",
			style = "ghost",
			name = "Odds",
			onClick = function()
				local prof = getProfile()
				table.insert(cleanups, Odds.open(if prof then tonumber(prof.rebirths) else 0))
			end,
		})
		bar.add(oddsBtn)
		renameBtn = Kit.Button({
			text = Config.text("name_rename"),
			icon = "✎",
			style = "ghost",
			name = "Rename",
			onClick = function()
				if not busy and not spinning then
					showName(true)
				end
			end,
		})
		bar.add(renameBtn)
		skipBtn = Kit.Button({
			text = Config.text("spin_skip"),
			style = "secondary",
			name = "Skip",
			onClick = function()
				for _, field in Config.FIELDS do
					local row = rows[field]
					if row then
						row.skip()
					end
				end
			end,
		})
		bar.add(skipBtn)
		lockBtn = Kit.Button({
			text = Config.text("lock_in"),
			icon = "🔒",
			name = "Lock",
			onClick = confirmLock,
		})
		bar.add(lockBtn)

		if spinFirst then
			win.setTitle(Config.text("spin_title"))
			spinning = true
			local remaining = #Config.FIELDS
			for i, field in Config.FIELDS do
				rows[field].set((pending :: any)[field], true, Config.revealDelay(i), function()
					remaining -= 1
					if remaining == 0 then
						spinning = false
						if alive and mode == "rows" then
							win.setTitle(Config.text("review_title"))
							refreshButtons()
						end
					end
				end)
			end
		else
			win.setTitle(Config.text("review_title"))
			spinning = false
			for _, field in Config.FIELDS do
				rows[field].set((pending :: any)[field], false)
			end
		end
		refreshButtons()
	end

	---------------------------------------------------------------------------------------------------
	-- Done / built
	---------------------------------------------------------------------------------------------------
	local function cardScreen(title: string, text: string, view: any, extra: (scroll: any) -> ())
		clearBody()
		win.setTitle(Config.text("title_liferoll"))
		win.setSubtitle(nil)
		local scroll = Kit.Scroll({ gap = 12, name = "Card" })
		scroll.frame.Parent = body
		scroll.add(Kit.Heading({ text = title, level = 2 }))
		scroll.add(Kit.Label({ text = text, color = "textDim" }))
		local holder = Kit.frame("CardHolder", UDim2.new(1, 0, 0, 0))
		holder.AutomaticSize = Enum.AutomaticSize.Y
		scroll.add(holder)
		table.insert(cleanups, StatCard.mount(holder, view))
		extra(scroll)
	end

	showDone = function(view: any)
		mode = "done"
		cardScreen(
			Config.text("done_title"),
			Config.text("done_body", {
				name = if type(view) == "table" then view.fullName else "",
				archetype = if type(view) == "table" and type(view.archetype) == "table"
					then view.archetype.name
					else "",
			}),
			view,
			function(scroll: any)
				scroll.add(Kit.Button({
					text = Config.text("done_stats"),
					style = "secondary",
					fill = true,
					onClick = function()
						api:OpenStats()
					end,
				}))
				scroll.add(Kit.Button({
					text = Config.text("done_continue"),
					fill = true,
					name = "Continue",
					onClick = function()
						if closeScreen then
							closeScreen()
						end
					end,
				}))
			end
		)
		Kit.sound("promotion")
	end

	showBuilt = function()
		mode = "built"
		local p = getProfile()
		cardScreen(Config.text("built_title"), Config.text("built_body"), api:PublicView(p), function(scroll: any)
			local credits = if p and type(p.credits) == "table" then tonumber(p.credits.rebuild) or 0 else 0
			if credits > 0 then
				scroll.add(Kit.Button({
					text = Config.text("rebuild_open", { n = credits }),
					style = "secondary",
					fill = true,
					name = "Rebuild",
					onClick = function()
						local fresh = getProfile()
						if fresh then
							table.insert(cleanups, RebuildModal.open(fresh, api, notify))
						end
					end,
				}))
			end
			scroll.add(Kit.Button({
				text = Config.text("done_stats"),
				fill = true,
				onClick = function()
					api:OpenStats()
				end,
			}))
		end)
	end

	---------------------------------------------------------------------------------------------------
	-- Live updates
	---------------------------------------------------------------------------------------------------
	local conns: { any } = {}
	if store and type(store.Changed) == "function" then
		local ok, sig = pcall(function()
			return store:Changed("profile")
		end)
		if ok and type(sig) == "table" then
			table.insert(
				conns,
				sig:Connect(function()
					if not alive then
						return
					end
					counts = nil
					if mode == "rows" then
						refreshButtons()
					elseif mode == "built" or mode == "loading" then
						route()
					end
				end)
			)
		end
	end

	route()

	return {
		close = function()
			alive = false
			for _, conn in conns do
				pcall(function()
					conn:Disconnect()
				end)
			end
			clearBody()
			win.close()
		end,
	}
end

return LifeRollScreen
