--!strict
-- Project screen, the deal list (owned by `projects`): one card per big deal of the player's track, with its stages,
-- the ranks it runs at, the best score so far, the typical rewards and one action (start, resume, wait for the
-- cooldown, or the rank it unlocks at). Cooldowns count down live.
--
--   ListView.build(parent, list, handlers) -> { destroy }
--   list     = Project.List result { who, cards = {Card}, activeCount, maxActive }
--   handlers = { onStart: (id) -> (), onResume: (id) -> (), onRefresh: () -> (), clock: () -> number }

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("Logic"):WaitForChild("Projects"):WaitForChild("_registry"))
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local View = require(script.Parent:WaitForChild("View"))

local ListView = {}

local text = Registry.text

type CardUi = { card: any, button: Kit.Button, lastKind: string }

local function buildCard(parent: Instance, card: any, order: number, handlers: { [string]: any }): CardUi
	local active = card.status == "active"
	local panel = Kit.Panel({
		color = if active then "surface" else "panelAlt",
		list = true,
		gap = 8,
		name = "Deal_" .. tostring(card.id),
		layoutOrder = order,
	})
	panel.frame.Parent = parent

	-- title row
	local titleRow = Kit.List({
		direction = "horizontal",
		gap = 8,
		align = "center",
		wraps = true,
		name = "TitleRow",
		layoutOrder = 1,
	})
	titleRow.frame.Size = UDim2.new(1, 0, 0, 0)
	titleRow.frame.AutomaticSize = Enum.AutomaticSize.Y
	titleRow.frame.Parent = panel.frame
	Kit.Label({
		text = tostring(card.glyph or "💼"),
		size = "xl",
		autoSize = "xy",
		name = "Glyph",
		layoutOrder = 1,
	}).frame.Parent =
		titleRow.frame
	Kit.Label({
		text = tostring(card.title or ""),
		font = "heading",
		size = "lg",
		autoSize = "xy",
		name = "Title",
		layoutOrder = 2,
	}).frame.Parent =
		titleRow.frame
	if card.signature == true then
		Kit.Badge({ text = text("card_signature"), color = "accent", size = "xs", layoutOrder = 3 }).frame.Parent =
			titleRow.frame
	end
	if active then
		Kit.Badge({ text = text("card_active"), color = "good", size = "xs", layoutOrder = 4 }).frame.Parent =
			titleRow.frame
	end

	if type(card.desc) == "string" and card.desc ~= "" then
		Kit.Label({ text = card.desc, size = "sm", color = "textDim", name = "Desc", layoutOrder = 2 }).frame.Parent =
			panel.frame
	end

	-- the stages, in order
	local stages = if type(card.stages) == "table" then card.stages else {}
	if #stages > 0 then
		local titles: { string } = {}
		for i, s in stages do
			local mark = if active and type(card.stageIndex) == "number" and i < card.stageIndex then "✓ " else ""
			table.insert(titles, mark .. tostring(s.title or ""))
		end
		Kit.Label({
			text = table.concat(titles, "  →  "),
			size = "xs",
			color = "textDim",
			name = "Stages",
			layoutOrder = 3,
		}).frame.Parent =
			panel.frame
	end

	-- meta chips
	local meta = Kit.List({ direction = "horizontal", wraps = true, gap = 6, name = "Meta", layoutOrder = 4 })
	meta.frame.Size = UDim2.new(1, 0, 0, 0)
	meta.frame.AutomaticSize = Enum.AutomaticSize.Y
	meta.frame.Parent = panel.frame
	for i, line in View.cardMeta(card) do
		Kit.Badge({ text = line, color = "surface", size = "xs", layoutOrder = i }).frame.Parent = meta.frame
	end
	if card.repeatRun == true and card.status ~= "locked" then
		Kit.Badge({
			text = text("card_repeat", { pct = math.floor(tonumber(card.repeatPct) or 50) }),
			color = "warn",
			size = "xs",
			layoutOrder = 99,
		}).frame.Parent =
			meta.frame
	end

	if active and type(card.dealName) == "string" then
		Kit.Label({ text = card.dealName, font = "bodyBold", color = "accent", name = "DealName", layoutOrder = 5 }).frame.Parent =
			panel.frame
	elseif type(card.lastName) == "string" then
		Kit.Label({
			text = (if card.lastClosed == true then "🏆 " else "• ") .. card.lastName,
			size = "xs",
			color = "textDim",
			name = "LastDeal",
			layoutOrder = 5,
		}).frame.Parent =
			panel.frame
	end

	local action = View.cardAction(card, 0)
	local button: Kit.Button
	local ui: CardUi
	button = Kit.Button({
		text = action.label,
		style = if action.enabled then "primary" else "secondary",
		disabled = not action.enabled,
		fill = true,
		name = "Action",
		layoutOrder = 6,
		onClick = function()
			local now = View.cardAction(card, handlers.clock())
			if not now.enabled then
				return
			end
			if now.kind == "resume" then
				handlers.onResume(card.id)
			else
				handlers.onStart(card.id)
			end
		end,
	})
	button.frame.Parent = panel.frame
	ui = { card = card, button = button, lastKind = action.kind }
	return ui
end

function ListView.build(parent: Instance, list: any, handlers: { [string]: any }): { destroy: () -> () }
	local root = Kit.frame("DealList")
	root.Parent = parent
	local scroll = Kit.Scroll({ gap = 10, padding = 4, name = "ListScroll" })
	scroll.frame.Parent = root

	local cards = if type(list.cards) == "table" then list.cards else {}
	local empty = View.emptyText(list)
	if empty then
		local panel = Kit.Panel({ color = "panelAlt", list = true, gap = 10, name = "Empty", layoutOrder = 1 })
		panel.frame.Parent = scroll.content
		Kit.Label({ text = "🤝", size = "xxl", align = "center", layoutOrder = 1 }).frame.Parent = panel.frame
		Kit.Label({ text = empty, align = "center", color = "textDim", name = "EmptyText", layoutOrder = 2 }).frame.Parent =
			panel.frame
		return {
			destroy = function()
				root:Destroy()
			end,
		}
	end

	Kit.Label({ text = text("list_intro"), size = "sm", color = "textDim", name = "Intro", layoutOrder = 1 }).frame.Parent =
		scroll.content
	local maxActive = math.floor(tonumber(list.maxActive) or 2)
	local activeCount = math.floor(tonumber(list.activeCount) or 0)
	if activeCount > 0 then
		Kit.Badge({
			text = string.format("%s · %d/%d", text("card_active"), activeCount, maxActive),
			color = "good",
			size = "sm",
			layoutOrder = 2,
		}).frame.Parent =
			scroll.content
	end

	local uis: { CardUi } = {}
	for i, card in cards do
		if type(card) == "table" then
			table.insert(uis, buildCard(scroll.content, card, 10 + i, handlers))
		end
	end

	-- live cooldowns: relabel waiting cards every second and wake them up when they're ready
	local stop = Kit.everySecond(function()
		local elapsed = handlers.clock()
		for _, ui in uis do
			if ui.card.status == "cooldown" then
				local action = View.cardAction(ui.card, elapsed)
				ui.button.setText(action.label)
				if action.kind ~= ui.lastKind then
					ui.lastKind = action.kind
					ui.button.setDisabled(not action.enabled)
					ui.button.setStyle(if action.enabled then "primary" else "secondary")
				end
			end
		end
	end)

	return {
		destroy = function()
			stop()
			root:Destroy()
		end,
	}
end

return ListView
