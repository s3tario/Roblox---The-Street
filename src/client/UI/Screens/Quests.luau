--!strict
-- Quests (client screen, owned by `tutorial`): the Quests app. Three tabs:
--   Story          what to do right now (the HUD objective, the step's hint, a skip once one is on offer, shortcuts
--                  to the Work board / Recruiting Board / Offers / the review explainer) and the whole onboarding
--                  chain, Eastbridge then Wall Street, with done / skipped / current / upcoming marks
--   Side quests    every side quest with its progress and reward
--   Achievements   unlocked and locked achievements (hidden ones stay secret until earned)
-- Reads the replicated `campus` and `achievements` keys and the server's view ("Quest.Get" through
-- TutorialController) for the live objective and the skip state; refreshes while open.
--   args = { tab = "story" | "side" | "achievements" }?

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local Achievements = require(Shared.Config.Achievements)
local QuestLine = require(Shared.Logic.QuestLine)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

local QuestsScreen = { id = "Quests" }

type Scroll = { frame: ScrollingFrame, add: (child: any) -> GuiObject, clear: () -> () }

local TABS = { "story", "side", "achievements" }
local REFRESH_DEBOUNCE = 0.4
local VIEW_EVERY = 15 -- seconds between server view refreshes while open (the skip timer moves on its own)
local WORK_STEPS = { academics = true, pitch = true, mock_interview = true, first_task = true } :: { [string]: boolean }

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

local function storeGet(ctx: any, key: string): any
	local store = if type(ctx) == "table" then ctx.Store else nil
	if not store then
		return nil
	end
	local ok, v = pcall(function()
		return store:Get(key)
	end)
	return if ok then v else nil
end

local function hexColor(s: any, default: Color3): Color3
	if type(s) == "string" and string.match(s, "^#%x%x%x%x%x%x$") then
		local ok, c = pcall(Color3.fromHex, s)
		if ok then
			return c
		end
	end
	return default
end

local function openScreen(ctx: any, id: string, args: { [string]: any }?)
	local u = if type(ctx) == "table" then ctx.UI else nil
	if u and type(u.Open) == "function" then
		u:Open(id, args or {})
	end
end

local function notify(ctx: any, msg: string, kind: string?)
	local u = if type(ctx) == "table" then ctx.UI else nil
	if u and type(u.Notify) == "function" then
		u:Notify(msg, kind)
	end
end

---------------------------------------------------------------------------------------------------
-- Small building blocks
---------------------------------------------------------------------------------------------------
local function hrow(name: string, order: number, gap: number?): Frame
	local f = Kit.frame(name, UDim2.new(1, 0, 0, 0))
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = order
	local l = Kit.list(f, true, gap or 10)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	return f
end

local function glyphLabel(glyph: string, color: Kit.ColorSpec, order: number): Kit.Label
	local g = Kit.Label({
		text = glyph,
		size = "lg",
		font = "bodyBold",
		color = color,
		align = "center",
		autoSize = "none",
		width = UDim.new(0, 30),
		height = 28,
		name = "Glyph",
		layoutOrder = order,
	})
	return g
end

local STATE_GLYPH = { done = "✓", skipped = "↷", current = "●", todo = "○" } :: { [string]: string }
local STATE_COLOR = { done = "good", skipped = "textDim", current = "accent", todo = "textDim" } :: { [string]: string }

---------------------------------------------------------------------------------------------------
-- Story tab
---------------------------------------------------------------------------------------------------
local function buildStory(scroll: Scroll?, ctx: any, campus: { [string]: any }, view: { [string]: any }?)
	if not scroll then
		return
	end
	local controller = controllerOf(ctx)
	local status = if view and type(view.status) == "table" then view.status else {}
	local step = QuestLine.current(campus)
	local finished = QuestLine.finished(campus)

	-- Right now
	local now = Kit.Card({ title = text("quests_current"), name = "Now", gap = 8 })
	scroll.add(now)
	local objective = if view and type(view.objective) == "string" then view.objective else nil
	if objective == nil and step then
		objective = Quests.fill(step.objective, QuestLine.vars(campus, QuestLine.facts({})))
	end
	now.add(Kit.Label({
		text = objective or (if finished then text("quests_done_all") else text("quests_none")),
		size = "md",
		font = "bodyBold",
		name = "Objective",
	}))
	if step and not finished and status.paused ~= true then
		now.add(Kit.Label({ text = step.hint, size = "sm", color = "textDim", name = "Hint" }))
	end

	local actions = hrow("Actions", 10, 8)
	local nActions = 0
	local function action(label: string, style: Kit.ButtonStyle, fn: () -> ())
		nActions += 1
		local b = Kit.Button({ text = label, style = style, name = "Action" .. nActions, onClick = fn })
		b.frame.LayoutOrder = nActions
		b.frame.Parent = actions
	end
	if step and not finished then
		if WORK_STEPS[step.id] then
			action(text("quests_open_work"), "primary", function()
				openScreen(ctx, "Work")
			end)
		elseif step.id == "recruiting" then
			action(text("recruit_title"), "primary", function()
				openScreen(ctx, "Recruiting")
			end)
		elseif step.id == "offers" then
			action(text("recruit_view_offers"), "primary", function()
				openScreen(ctx, "Offers")
			end)
		elseif step.id == "review_intro" then
			action(text("quests_review_intro"), "primary", function()
				if controller then
					controller:ShowInfo({
						id = "review_intro",
						title = Quests.reviewIntro.title,
						lines = Quests.reviewIntro.lines,
					})
				end
			end)
		end
		if status.canSkip == true then
			action(text("skip_button"), "ghost", function()
				local u = if type(ctx) == "table" then ctx.UI else nil
				if not u or not controller then
					return
				end
				u:Confirm({
					title = text("skip_confirm_title"),
					body = text("skip_confirm_body"),
					confirmText = text("skip_button"),
				}, function(yes: boolean)
					if not yes then
						return
					end
					local ok, err = controller:Skip()
					if not ok then
						notify(ctx, text(err or "skip_none"), "warn")
					end
				end)
			end)
		elseif not step.core and type(status.stuck) == "number" and type(status.skipAfter) == "number" then
			local left = math.max(0, status.skipAfter - status.stuck)
			if left > 0 and status.stuck >= status.skipAfter * 0.5 then
				now.add(Kit.Label({
					text = text("quests_skip_in", { min = math.max(1, math.ceil(left / 60)) }),
					size = "xs",
					color = "textDim",
					name = "SkipIn",
				}))
			end
		end
	end
	if finished then
		action(text("quests_open_career"), "secondary", function()
			openScreen(ctx, "Career")
		end)
		action(text("quests_review_intro"), "ghost", function()
			if controller then
				controller:ShowInfo({
					id = "review_intro",
					title = Quests.reviewIntro.title,
					lines = Quests.reviewIntro.lines,
				})
			end
		end)
	end
	if nActions > 0 then
		now.add(actions)
	else
		actions:Destroy()
	end

	-- The chain
	local rows = QuestLine.progress(campus)
	for _, phase in { "campus", "street" } do
		local card = Kit.Card({ title = text("quests_phase_" .. phase), name = "Phase_" .. phase, gap = 4 })
		scroll.add(card)
		local done, total = 0, 0
		for _, r in rows do
			if r.phase == phase then
				total += 1
				if r.state == "done" or r.state == "skipped" then
					done += 1
				end
				local line = hrow("Step_" .. r.id, total, 6)
				glyphLabel(STATE_GLYPH[r.state] or "○", STATE_COLOR[r.state] or "textDim", 1).frame.Parent = line
				local title = Kit.Label({
					text = if r.state == "skipped" then r.title .. "  " .. text("quests_skipped_tag") else r.title,
					size = "sm",
					font = if r.state == "current" then "bodyBold" else "body",
					color = if r.state == "current" then "text" elseif r.state == "todo" then "textDim" else "text",
					width = UDim.new(1, -40),
					name = "Title",
					layoutOrder = 2,
				})
				title.frame.Parent = line
				card.add(line)
			end
		end
		card.setSubtitle(text("quests_progress", { n = done, goal = total }))
	end
end

---------------------------------------------------------------------------------------------------
-- Side quests tab
---------------------------------------------------------------------------------------------------
local function buildSide(scroll: Scroll?, campus: { [string]: any })
	if not scroll then
		return
	end
	local rows = QuestLine.Side.view(if type(campus.quests) == "table" then campus.quests else {}, Quests.side)
	if #rows == 0 then
		scroll.add(Kit.Label({ text = text("quests_side_empty"), color = "textDim", align = "center" }))
		return
	end
	-- open quests first, then the finished ones; config order within each group
	local ordered: { any } = {}
	for _, r in rows do
		if not r.done then
			table.insert(ordered, r)
		end
	end
	for _, r in rows do
		if r.done then
			table.insert(ordered, r)
		end
	end
	for _, r in ordered do
		local card = Kit.Card({
			title = r.title,
			subtitle = text(if r.phase == "street" then "quests_phase_street" else "quests_phase_campus"),
			name = "Side_" .. r.id,
			gap = 6,
		})
		scroll.add(card)
		card.add(Kit.Label({ text = r.desc, size = "sm", name = "Desc" }))
		local bar = Kit.ProgressBar({
			value = if r.goal > 0 then r.n / r.goal else 0,
			color = if r.done then "good" else "accent",
			height = 18,
			label = if r.done then text("quests_side_done") else text("quests_progress", { n = r.n, goal = r.goal }),
			name = "Progress",
		})
		card.add(bar)
		if r.reward ~= "" then
			card.add(Kit.Label({
				text = text("quests_side_reward", { reward = r.reward }),
				size = "xs",
				color = if r.done then "textDim" else "accent",
				name = "Reward",
			}))
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Achievements tab
---------------------------------------------------------------------------------------------------
local function dateText(t: any): string
	if type(t) ~= "number" or t <= 0 then
		return ""
	end
	local ok, s = pcall(function(): string
		return DateTime.fromUnixTimestamp(math.floor(t)):FormatLocalTime("ll", "en-us")
	end)
	return if ok and type(s) == "string" then s else ""
end

local function buildAchievements(scroll: Scroll?, unlocked: { [string]: any })
	if not scroll then
		return
	end
	local total = #Achievements.list
	local count = QuestLine.Awards.count(unlocked)
	scroll.add(Kit.Label({
		text = text("achievements_count", { n = count, total = total }),
		size = "md",
		font = "bodyBold",
		name = "Count",
	}))
	scroll.add(Kit.ProgressBar({ value = if total > 0 then count / total else 0, height = 8, name = "CountBar" }))
	-- unlocked first (newest first), then locked in config order
	local got: { Achievements.Def } = {}
	local locked: { Achievements.Def } = {}
	for _, def in Achievements.list do
		if unlocked[def.id] ~= nil then
			table.insert(got, def)
		else
			table.insert(locked, def)
		end
	end
	table.sort(got, function(a: Achievements.Def, b: Achievements.Def): boolean
		local ta = tonumber(unlocked[a.id]) or 0
		local tb = tonumber(unlocked[b.id]) or 0
		if ta ~= tb then
			return ta > tb
		end
		return a.id < b.id
	end)
	local function row(def: Achievements.Def, isUnlocked: boolean)
		local tier = Achievements.TIERS[def.tier]
		local tint = hexColor(if tier then tier.color else nil, Color3.fromRGB(180, 180, 180))
		local secret = def.hidden == true and not isUnlocked
		local panel = Kit.Panel({
			name = "Ach_" .. def.id,
			color = if isUnlocked then "panelAlt" else "panel",
			padding = 10,
			list = false,
		})
		local line = hrow("Line", 1, 10)
		line.Parent = panel.frame
		local glyph = Kit.Label({
			text = if secret then "?" else def.glyph,
			size = "xl",
			align = "center",
			autoSize = "none",
			width = UDim.new(0, 44),
			height = 44,
			transparency = if isUnlocked then 0 else 0.55,
			name = "Glyph",
			layoutOrder = 1,
		})
		glyph.frame.Parent = line
		local body = Kit.frame("Body", UDim2.new(1, -150, 0, 0))
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.LayoutOrder = 2
		body.Parent = line
		Kit.list(body, false, 2)
		local name = Kit.Label({
			text = if secret then text("achievement_hidden") else def.name,
			size = "md",
			font = "bodyBold",
			color = if isUnlocked then "text" else "textDim",
			name = "Name",
			layoutOrder = 1,
		})
		name.frame.Parent = body
		local desc = Kit.Label({
			text = if secret then text("achievement_hidden_desc") else def.desc,
			size = "sm",
			color = "textDim",
			name = "Desc",
			layoutOrder = 2,
		})
		desc.frame.Parent = body
		if isUnlocked then
			local when = dateText(unlocked[def.id])
			if when ~= "" then
				local d = Kit.Label({ text = when, size = "xs", color = "textDim", name = "When", layoutOrder = 3 })
				d.frame.Parent = body
			end
		end
		local badge = Kit.Badge({
			text = if isUnlocked then (if tier then tier.name else def.tier) else text("achievement_locked"),
			color = if isUnlocked then tint else "surface",
			size = "xs",
			name = "Tier",
			layoutOrder = 3,
		})
		badge.frame.Parent = line
		scroll.add(panel)
	end
	for _, def in got do
		row(def, true)
	end
	for _, def in locked do
		row(def, false)
	end
end

---------------------------------------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------------------------------------
function QuestsScreen.open(args: any, root: Instance, ctx: any): { close: () -> () }
	local a = if type(args) == "table" then args else {}
	local selected: string = if type(a.tab) == "string" and table.find(TABS, a.tab) then a.tab else "story"
	local closed = false
	local conns: { any } = {}
	local controller = controllerOf(ctx)
	local view: { [string]: any }? = nil

	local win = Kit.Window({
		title = text("quests_title"),
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(640, 720),
		onClose = if type(ctx) == "table" then ctx.close else nil,
		name = "QuestsWindow",
	})
	win.frame.Parent = root

	local scroll: Scroll? = nil
	local render: () -> ()
	local tabs = Kit.Tabs({
		tabs = {
			{ id = "story", title = text("tab_story") },
			{ id = "side", title = text("tab_side") },
			{ id = "achievements", title = text("tab_achievements") },
		},
		selected = selected,
		onSelect = function(id: string)
			if id ~= selected then
				selected = id
				local s = scroll
				if s then
					s.frame.CanvasPosition = Vector2.zero
				end
				render()
			end
		end,
		name = "Tabs",
	})
	tabs.frame.Parent = win.content

	local body = Kit.frame("Body", UDim2.new(1, 0, 1, -56))
	body.Position = UDim2.fromOffset(0, 56)
	body.Parent = win.content
	local list = Kit.Scroll({ padding = 2, gap = 10, name = "Scroll" })
	list.frame.Parent = body
	scroll = list

	local function badges(campus: { [string]: any }, unlocked: { [string]: any })
		local openSide = 0
		for _, r in QuestLine.Side.view(if type(campus.quests) == "table" then campus.quests else {}, Quests.side) do
			if not r.done then
				openSide += 1
			end
		end
		tabs.setBadge("side", if openSide > 0 then tostring(openSide) else nil)
		tabs.setBadge("achievements", tostring(QuestLine.Awards.count(unlocked)))
		local status = if view and type(view.status) == "table" then view.status else {}
		tabs.setBadge("story", if status.canSkip == true then "!" else nil)
	end

	render = function()
		if closed then
			return
		end
		local campusRaw = storeGet(ctx, "campus")
		local campus = QuestLine.normalize(if type(campusRaw) == "table" then table.clone(campusRaw) else {})
		local unlockedRaw = storeGet(ctx, "achievements")
		local unlocked: { [string]: any } = if type(unlockedRaw) == "table" then unlockedRaw else {}
		local keep = list.frame.CanvasPosition
		list.clear()
		local ok, err = pcall(function()
			if selected == "side" then
				buildSide(list, campus)
			elseif selected == "achievements" then
				buildAchievements(list, unlocked)
			else
				buildStory(list, ctx, campus, view)
			end
			badges(campus, unlocked)
		end)
		if not ok then
			warn("[Quests] render failed: " .. tostring(err))
		end
		task.defer(function()
			if not closed and list.frame.Parent then
				list.frame.CanvasPosition = keep
			end
		end)
	end

	local pending = false
	local function schedule()
		if pending or closed then
			return
		end
		pending = true
		task.delay(REFRESH_DEBOUNCE, function()
			pending = false
			render()
		end)
	end

	local fetching = false
	local function fetchView()
		if fetching or closed or not controller then
			return
		end
		fetching = true
		task.spawn(function()
			local ok, v = pcall(function()
				return controller:GetQuestView()
			end)
			fetching = false
			if closed then
				return
			end
			if ok and type(v) == "table" then
				view = v
			end
			render()
		end)
	end

	render()
	fetchView()

	local store = if type(ctx) == "table" then ctx.Store else nil
	if store then
		for _, key in { "campus", "achievements", "career" } do
			local ok, conn = pcall(function()
				return store:Changed(key):Connect(function()
					schedule()
					if key ~= "achievements" then
						fetchView()
					end
				end)
			end)
			if ok and conn then
				table.insert(conns, conn)
			end
		end
	end
	-- the skip timer and the objective move without a data change: refresh the server view now and then
	task.spawn(function()
		while not closed do
			task.wait(VIEW_EVERY)
			if not closed and selected == "story" then
				fetchView()
			end
		end
	end)

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

return QuestsScreen
