--!strict
-- Stats screen (client UI, careerCore; design v3 §3 and §14b): the MyCareer card (big OVR, archetype, school crest,
-- degree / GPA / clubs / family with rarity colours, the eight attribute bars with this week's growth, perks), the
-- focus picker (two stats grow 2x, the rest 0.75x; one change per week) and the player's reroll / rebuild credits.
-- Menu tab "Stats" (quick button), registered by CareerCoreController.
-- Screen contract: { id, open(args, root, ctx) -> { close } }.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.LifeRoll)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Parts = script.Parent:WaitForChild("LifeRollParts")
local Common = require(Parts:WaitForChild("Common"))
local StatCard = require(Parts:WaitForChild("StatCard"))
local RebuildModal = require(Parts:WaitForChild("Rebuild"))

local StatsScreen = { id = "Stats" }

local function focusLabel(def: Config.FocusDef): string
	local a, b = Config.stat(def.stats[1]), Config.stat(def.stats[2])
	return def.name .. "  " .. (if a then a.short else "") .. "+" .. (if b then b.short else "")
end

function StatsScreen.open(_args: any, root: Instance, ctx: any): { close: () -> () }
	local c = if type(ctx) == "table" then ctx else {}
	local api = Common.api(c)
	local store = c.Store
	local ui = c.UI
	local closeScreen: (() -> ())? = if type(c.close) == "function" then c.close else nil

	local alive = true
	local busy = false
	local canChange: boolean? = nil -- nil until the server answers
	local cleanups: { () -> () } = {}

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
		title = Config.text("title_stats"),
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(760, 720),
		onClose = closeScreen,
		name = "StatsWindow",
	})
	win.frame.Parent = root
	local scroll = Kit.Scroll({ gap = 12, name = "StatsScroll" })
	scroll.frame.Parent = win.content

	local render: () -> ()

	local function fetchFocusState()
		task.spawn(function()
			local ok, _err, payload = api:FetchState()
			if not alive then
				return
			end
			if ok and type(payload) == "table" then
				canChange = payload.canChangeFocus == true
				render()
			end
		end)
	end

	local function pickFocus(id: string)
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local ok, err = api:SetFocus(id)
			busy = false
			if not alive then
				return
			end
			if not ok then
				Kit.sound("error")
				notify(Config.err(err), "warn")
			end
			fetchFocusState()
		end)
	end

	render = function()
		for _, fn in cleanups do
			pcall(fn)
		end
		table.clear(cleanups)
		scroll.clear()
		local p = getProfile()
		if not p then
			scroll.add(Kit.Label({ text = Config.err("not_loaded"), align = "center", color = "textDim" }))
			return
		end
		if p.built ~= true then
			scroll.add(Kit.Heading({ text = Config.text("stats_unbuilt"), level = 3 }))
			scroll.add(Kit.Button({
				text = Config.text("stats_start"),
				icon = "🎰",
				fill = true,
				name = "StartLifeRoll",
				onClick = function()
					api:OpenLifeRoll()
				end,
			}))
			return
		end

		local holder = Kit.frame("CardHolder", UDim2.new(1, 0, 0, 0))
		holder.AutomaticSize = Enum.AutomaticSize.Y
		scroll.add(holder)
		table.insert(cleanups, StatCard.mount(holder, api:PublicView(p)))

		-- Focus picker
		local focusCard = Kit.Card({ title = Config.text("stats_focus"), subtitle = Config.text("stats_focus_body") })
		scroll.add(focusCard)
		local current = Config.focusDef(p.focus)
		local status = if current
			then Config.text("stats_focus_current") .. ": " .. current.glyph .. " " .. current.name
			else Config.text("stats_focus_none")
		if canChange == false then
			status ..= "  ·  " .. Config.text("stats_focus_locked")
		end
		focusCard.add(Kit.Label({ text = status, size = "sm", color = if canChange == false then "warn" else "text" }))
		local grid = Kit.Grid({ columns = 2, cellHeight = Kit.TAP + 8, gap = 8, name = "FocusGrid" })
		focusCard.add(grid)
		for i, def in Config.focus do
			local isCurrent = current ~= nil and current.id == def.id
			local btn = Kit.Button({
				text = focusLabel(def),
				icon = def.glyph,
				style = if isCurrent then "primary" else "secondary",
				textSize = "sm",
				disabled = canChange == false and not isCurrent,
				name = "Focus_" .. def.id,
				layoutOrder = i,
				onClick = function()
					if not isCurrent then
						pickFocus(def.id)
					end
				end,
			})
			grid.add(btn)
		end

		scroll.add(Kit.Label({ text = Config.text("stats_growth_hint"), size = "sm", color = "textDim" }))
		local credits = if type(p.credits) == "table" then p.credits else {}
		scroll.add(Kit.Label({
			text = Config.text("stats_tokens", {
				tokens = tonumber(p.refreshTokens) or 0,
				reroll = tonumber(credits.reroll) or 0,
				rebuild = tonumber(credits.rebuild) or 0,
			}),
			size = "xs",
			color = "textDim",
		}))
		local rebuilds = tonumber(credits.rebuild) or 0
		if rebuilds > 0 then
			scroll.add(Kit.Button({
				text = Config.text("rebuild_open", { n = rebuilds }),
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
	end

	local conns: { any } = {}
	if store and type(store.Changed) == "function" then
		local ok, sig = pcall(function()
			return store:Changed("profile")
		end)
		if ok and type(sig) == "table" then
			table.insert(
				conns,
				sig:Connect(function()
					if alive then
						render()
					end
				end)
			)
		end
	end

	render()
	fetchFocusState()

	return {
		close = function()
			alive = false
			for _, conn in conns do
				pcall(function()
					conn:Disconnect()
				end)
			end
			for _, fn in cleanups do
				pcall(fn)
			end
			table.clear(cleanups)
			win.close()
		end,
	}
end

return StatsScreen
