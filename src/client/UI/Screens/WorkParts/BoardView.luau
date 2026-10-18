--!strict
-- Work screen, board view (owned by `work`): today's tasks as cards with tags, rewards, the time limit and one
-- big Start / Resume button each. Countdowns (cooldowns, offer expiry) tick once a second.
--
--   BoardView.build(parent, board, handlers) -> { destroy }
--   handlers = { onStart: (taskId) -> (), onResume: () -> (), onRefresh: () -> (), now: () -> number }

local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Tasks"))
local View = require(script.Parent:WaitForChild("View"))

local BoardView = {}

local FOOTER = Kit.TAP + 12

function BoardView.build(parent: Instance, board: any, handlers: { [string]: any }): { destroy: () -> () }
	local root = Kit.frame("BoardView")
	root.Parent = parent
	local now: () -> number = handlers.now
	local scroll = Kit.Scroll({ gap = 10, padding = 4, name = "BoardScroll" })
	scroll.frame.Size = UDim2.new(1, 0, 1, -FOOTER)
	scroll.frame.Parent = root

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- header: day, desk bonus and situation notes
	local head = Kit.Panel({ color = "surface", list = true, gap = 4, name = "Header", layoutOrder = nextOrder() })
	head.frame.Parent = scroll.content
	local deskText, deskColor = View.deskText(board)
	Kit.Label({ text = deskText, color = deskColor, size = "sm", name = "Desk", layoutOrder = 1 }).frame.Parent =
		head.frame
	if board.unemployed == true then
		Kit.Label({
			text = Config.text("board_unemployed"),
			color = "warn",
			size = "sm",
			name = "Note",
			layoutOrder = 2,
		}).frame.Parent =
			head.frame
	end
	Kit.Label({
		text = Config.text("board_core_hint"),
		color = "textDim",
		size = "xs",
		name = "CoreHint",
		layoutOrder = 3,
	}).frame.Parent =
		head.frame

	-- the attempt in progress
	local active = board.active
	if type(active) == "table" then
		local banner =
			Kit.Panel({ color = "panelAlt", list = true, gap = 8, name = "ActiveBanner", layoutOrder = nextOrder() })
		banner.frame.Parent = scroll.content
		Kit.Label({
			text = tostring(active.title),
			font = "bodyBold",
			size = "lg",
			name = "ActiveTitle",
			layoutOrder = 1,
		}).frame.Parent =
			banner.frame
		Kit.Button({
			text = Config.text("board_resume"),
			fill = true,
			name = "Resume",
			layoutOrder = 2,
			onClick = function()
				handlers.onResume()
			end,
		}).frame.Parent =
			banner.frame
	end

	local empty = View.emptyText(board)
	if empty then
		Kit.Label({ text = empty, color = "textDim", align = "center", name = "Empty", layoutOrder = nextOrder() }).frame.Parent =
			scroll.content
	end

	type Live = { card: any, button: Kit.Button, expires: Kit.Label? }
	local live: { Live } = {}
	for _, card in board.tasks or {} do
		local panel = Kit.Panel({
			color = "panelAlt",
			list = true,
			gap = 6,
			name = "Card_" .. tostring(card.id),
			layoutOrder = nextOrder(),
		})
		panel.frame.Parent = scroll.content
		local tags = Kit.List({ direction = "horizontal", wraps = true, gap = 6, name = "Tags", layoutOrder = 1 })
		tags.frame.Size = UDim2.new(1, 0, 0, 0)
		tags.frame.AutomaticSize = Enum.AutomaticSize.Y
		tags.frame.Parent = panel.frame
		for ti, tag in View.cardTags(card, now()) do
			Kit.Badge({ text = tag.text, color = tag.color, layoutOrder = ti }).frame.Parent = tags.frame
		end
		Kit.Label({ text = tostring(card.title), font = "bodyBold", size = "lg", name = "Title", layoutOrder = 2 }).frame.Parent =
			panel.frame
		if type(card.label) == "string" and card.label ~= "" then
			Kit.Label({ text = card.label, color = "accent", size = "sm", name = "OfferLabel", layoutOrder = 3 }).frame.Parent =
				panel.frame
		end
		local expiryText = View.expiryText(card, now())
		local expires: Kit.Label? = nil
		if expiryText then
			local label =
				Kit.Label({ text = expiryText, color = "warn", size = "xs", name = "Expires", layoutOrder = 3 })
			label.frame.Parent = panel.frame
			expires = label
		end
		Kit.Label({ text = tostring(card.desc or ""), color = "textDim", size = "sm", name = "Desc", layoutOrder = 4 }).frame.Parent =
			panel.frame
		Kit.Label({ text = View.cardMeta(card), size = "sm", font = "mono", name = "Meta", layoutOrder = 5 }).frame.Parent =
			panel.frame
		local stats = View.statsText(card)
		if stats then
			Kit.Label({ text = stats, size = "xs", color = "textDim", name = "Stats", layoutOrder = 6 }).frame.Parent =
				panel.frame
		end
		local act = View.cardAction(card, now(), active)
		local id = card.id
		local button = Kit.Button({
			text = act.text,
			style = act.style :: any,
			fill = true,
			disabled = not act.enabled,
			name = "Action",
			layoutOrder = 10,
			onClick = function()
				local current = View.cardAction(card, now(), active)
				if current.action == "start" then
					handlers.onStart(id)
				elseif current.action == "resume" then
					handlers.onResume()
				end
			end,
		})
		button.frame.Parent = panel.frame
		table.insert(live, { card = card, button = button, expires = expires })
	end

	-- footer
	local footer = Kit.frame("Footer", UDim2.new(1, 0, 0, FOOTER))
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Parent = root
	local refresh = Kit.Button({
		text = Config.text("board_refresh"),
		style = "secondary",
		fill = true,
		name = "Refresh",
		onClick = function()
			handlers.onRefresh()
		end,
	})
	refresh.frame.AnchorPoint = Vector2.new(0, 1)
	refresh.frame.Position = UDim2.fromScale(0, 1)
	refresh.frame.Parent = footer

	local stopTick = Kit.everySecond(function()
		local t = now()
		for _, l in live do
			local act = View.cardAction(l.card, t, active)
			l.button.setText(act.text)
			l.button.setDisabled(not act.enabled)
			local label = l.expires
			if label then
				label.setText(View.expiryText(l.card, t) or "")
			end
		end
	end)

	return {
		destroy = function()
			stopTick()
			root:Destroy()
		end,
	}
end

return BoardView
