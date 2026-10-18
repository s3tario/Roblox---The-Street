--!strict
-- Project screen, the results story (owned by `projects`): the big "DEAL CLOSED" moment (or "DEAL PULLED"), the
-- deal plaque with the tombstone name, the deal quality, the outcome headline and story, the key figures, what the
-- player earned and trained, and how each stage went.
--
--   Results.build(parent, view, rewards?, handlers) -> { destroy }
--   view     = a finished ProjectService view { dealName, title, glyph, signature, quality, outcome = { closed,
--              score, headline, lines, figures = {{label, value, tone?}} }, stages = {{title, score, debrief?}},
--              rewards? }
--   rewards  = { xp, xpCapped, pay, paid, rep, repeatRun, repeatPct, pulled, plaque, stats = {label} } (view.rewards
--              when nil)
--   handlers = { onBack: () -> (), onClose: () -> () }

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Time = require(Shared:WaitForChild("Util"):WaitForChild("Time"))
local Registry = require(Shared:WaitForChild("Logic"):WaitForChild("Projects"):WaitForChild("_registry"))
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local View = require(script.Parent:WaitForChild("View"))

local Results = {}

local text = Registry.text
local FOOTER = Kit.TAP + 12
local FIGURE_W = 150
local MONTHS = {
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
}

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

local function toneColor(tone: any): string
	return if tone == "good" then "good" elseif tone == "bad" then "bad" elseif tone == "warn" then "warn" else "text"
end

local function monthYear(): string
	local ok, d = pcall(function(): any
		return os.date("!*t", math.floor(Time.now()))
	end)
	if ok and type(d) == "table" then
		return (MONTHS[d.month] or "") .. " " .. tostring(d.year)
	end
	return ""
end

-- The hero: a stamped "DEAL CLOSED" that punches in, with the lucite plaque under it.
local function buildHero(parent: Instance, view: any, closed: boolean, order: number)
	local hero = Kit.Panel({
		color = if closed then "panelAlt" else "surface",
		list = true,
		gap = 10,
		padding = 18,
		name = "Hero",
		layoutOrder = order,
	})
	hero.frame.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = hero.frame
	local stamp = Kit.Label({
		text = if closed then text("result_closed") else text("result_pulled"),
		font = "display",
		size = "xxl",
		color = if closed then "accent" else "bad",
		align = "center",
		name = "Stamp",
		layoutOrder = 1,
	})
	stamp.frame.Parent = hero.frame
	local stampStroke = Kit.stroke(stamp.frame, 0, 1)
	stampStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	-- the plaque: a lucite block with the tombstone name
	local plaque = Kit.Panel({
		color = "surface",
		list = true,
		gap = 4,
		padding = 14,
		stroke = false,
		name = "Plaque",
		layoutOrder = 2,
	})
	plaque.frame.Parent = hero.frame
	local glow = Instance.new("UIStroke")
	glow.Name = "PlaqueGlow"
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	glow.Thickness = 3
	glow.Parent = plaque.frame
	Kit.themed(glow, function(t)
		glow.Color = if closed then t.colors.accent else t.colors.border
		glow.Transparency = if closed then 0.1 else 0.5
	end)
	Kit.Label({
		text = (if type(view.glyph) == "string" then view.glyph .. "  " else "") .. tostring(view.dealName or ""),
		font = "heading",
		size = "lg",
		align = "center",
		name = "DealName",
		layoutOrder = 1,
	}).frame.Parent =
		plaque.frame
	Kit.Label({
		text = monthYear(),
		size = "sm",
		color = "textDim",
		align = "center",
		name = "Date",
		layoutOrder = 2,
	}).frame.Parent =
		plaque.frame
	if view.signature == true then
		local row = Kit.List({ direction = "horizontal", justify = "center", name = "SignatureRow", layoutOrder = 3 })
		row.frame.Size = UDim2.new(1, 0, 0, 0)
		row.frame.AutomaticSize = Enum.AutomaticSize.Y
		row.frame.Parent = plaque.frame
		Kit.Badge({ text = text("card_signature"), color = "accent", size = "sm" }).frame.Parent = row.frame
	end

	-- punch in, with a little settle
	task.defer(function()
		if hero.frame.Parent == nil then
			return
		end
		local tween =
			Kit.tween(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		if tween == nil then
			scale.Scale = 1
		end
		if closed then
			stampStroke.Thickness = 0
			stampStroke.Transparency = 0.2
			Kit.themed(stampStroke, function(t)
				stampStroke.Color = t.colors.accent
			end)
			Kit.tween(stampStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Thickness = 2,
				Transparency = 1,
			})
		end
	end)
	Kit.sound(if closed then "promotion" else "bad")
end

local function buildQuality(parent: Instance, quality: number, order: number)
	local color = View.qualityColor(quality)
	local card = Kit.Panel({ color = "surface", list = true, gap = 6, name = "Quality", layoutOrder = order })
	card.frame.Parent = parent
	Kit.Label({
		text = text("result_quality"),
		size = "sm",
		color = "textDim",
		align = "center",
		layoutOrder = 1,
	}).frame.Parent =
		card.frame
	Kit.Label({
		text = tostring(quality),
		font = "display",
		size = "xxl",
		color = color,
		align = "center",
		name = "Score",
		layoutOrder = 2,
	}).frame.Parent =
		card.frame
	local bar = Kit.ProgressBar({ value = 0, color = color, height = 12, name = "QualityBar", layoutOrder = 3 })
	bar.frame.Parent = card.frame
	bar.set(quality / 100)
	Kit.Label({
		text = text("result_band_" .. View.band(quality)),
		align = "center",
		name = "Band",
		layoutOrder = 4,
	}).frame.Parent =
		card.frame
end

local function buildStory(parent: Instance, outcome: any, order: number)
	local panel = Kit.Panel({ color = "panelAlt", list = true, gap = 6, name = "Story", layoutOrder = order })
	panel.frame.Parent = parent
	if type(outcome.headline) == "string" then
		Kit.Label({ text = outcome.headline, font = "bodyBold", size = "lg", name = "Headline", layoutOrder = 1 }).frame.Parent =
			panel.frame
	end
	local lines = if type(outcome.lines) == "table" then outcome.lines else {}
	for i, line in lines do
		if type(line) == "string" then
			Kit.Label({ text = "• " .. line, size = "sm", layoutOrder = 1 + i }).frame.Parent = panel.frame
		end
	end
	local figures = if type(outcome.figures) == "table" then outcome.figures else {}
	if #figures > 0 then
		local tiles = Kit.List({ direction = "horizontal", wraps = true, gap = 6, name = "Figures", layoutOrder = 100 })
		tiles.frame.Size = UDim2.new(1, 0, 0, 0)
		tiles.frame.AutomaticSize = Enum.AutomaticSize.Y
		tiles.frame.Parent = panel.frame
		for i, f in figures do
			if type(f) == "table" then
				local tile = Kit.Panel({
					color = "surface",
					list = true,
					gap = 2,
					padding = 8,
					size = UDim2.fromOffset(FIGURE_W, 0),
					autoSize = "y",
					name = "Figure" .. i,
					layoutOrder = i,
				})
				tile.frame.Parent = tiles.frame
				Kit.Label({ text = tostring(f.label or ""), size = "xs", color = "textDim", layoutOrder = 1 }).frame.Parent =
					tile.frame
				Kit.Label({
					text = tostring(f.value or "—"),
					font = "mono",
					size = "lg",
					color = toneColor(f.tone),
					name = "Value",
					layoutOrder = 2,
				}).frame.Parent =
					tile.frame
			end
		end
	end
end

local function buildRewards(parent: Instance, rewards: any, closed: boolean, order: number)
	local row = Kit.List({ direction = "horizontal", wraps = true, gap = 6, name = "Earned", layoutOrder = order })
	row.frame.Size = UDim2.new(1, 0, 0, 0)
	row.frame.AutomaticSize = Enum.AutomaticSize.Y
	row.frame.Parent = parent
	local n = 0
	local function badge(s: string, color: string)
		n += 1
		Kit.Badge({ text = s, color = color, size = "sm", layoutOrder = n }).frame.Parent = row.frame
	end
	local r = if type(rewards) == "table" then rewards else {}
	if num(r.xp, 0) > 0 then
		badge(text("result_xp", { xp = View.commas(r.xp) }), "accent")
	end
	if r.paid == true and num(r.pay, 0) > 0 then
		badge(text("result_pay", { pay = View.money(r.pay) }), "good")
	end
	if num(r.rep, 0) > 0 then
		badge(text("result_rep", { rep = r.rep }), "good")
	end
	if closed then
		badge(text("result_plaque"), "accent")
	else
		badge(text("result_no_plaque"), "warn")
	end
	if r.repeatRun == true then
		badge(text("result_repeat"), "surface")
	end
	local stats = if type(r.stats) == "table" then r.stats else {}
	if #stats > 0 then
		Kit.Label({
			text = text("result_stats", { stats = table.concat(stats, ", ") }),
			size = "sm",
			color = "textDim",
			name = "Trained",
			layoutOrder = order + 1,
		}).frame.Parent =
			parent
	end
end

local function buildStages(parent: Instance, view: any, order: number)
	local stages = if type(view.stages) == "table" then view.stages else {}
	if #stages == 0 then
		return
	end
	Kit.Label({
		text = text("result_stages"),
		font = "bodyBold",
		color = "textDim",
		size = "sm",
		name = "StagesTitle",
		layoutOrder = order,
	}).frame.Parent =
		parent
	local panel = Kit.Panel({ color = "panelAlt", list = true, gap = 8, name = "Stages", layoutOrder = order + 1 })
	panel.frame.Parent = parent
	for i, s in stages do
		if type(s) == "table" then
			local score = math.floor(num(s.score, 0))
			Kit.Label({
				text = string.format("%d. %s · %d", i, tostring(s.title or ""), score),
				font = "bodyBold",
				color = View.qualityColor(score),
				layoutOrder = i * 2,
			}).frame.Parent =
				panel.frame
			if type(s.debrief) == "string" and s.debrief ~= "" then
				Kit.Label({ text = s.debrief, size = "sm", color = "textDim", layoutOrder = i * 2 + 1 }).frame.Parent =
					panel.frame
			end
		end
	end
end

function Results.build(parent: Instance, view: any, rewards: any, handlers: { [string]: any }): { destroy: () -> () }
	local outcome = if type(view.outcome) == "table" then view.outcome else {}
	local closed = outcome.closed == true
	local quality = math.clamp(math.floor(num(view.quality, 0)), 0, 100)
	local r = if type(rewards) == "table" then rewards else view.rewards

	local root = Kit.frame("Results")
	root.Parent = parent
	local scroll = Kit.Scroll({ gap = 12, padding = 4, name = "ResultsScroll" })
	scroll.frame.Size = UDim2.new(1, 0, 1, -FOOTER)
	scroll.frame.Parent = root

	buildHero(scroll.content, view, closed, 1)
	buildQuality(scroll.content, quality, 2)
	buildStory(scroll.content, outcome, 3)
	buildRewards(scroll.content, r, closed, 4)
	buildStages(scroll.content, view, 10)

	local footer = Kit.frame("Footer", UDim2.new(1, 0, 0, FOOTER))
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Parent = root
	local buttons = Kit.List({ direction = "horizontal", gap = 8, justify = "end", name = "Buttons" })
	buttons.frame.AnchorPoint = Vector2.new(1, 0.5)
	buttons.frame.Position = UDim2.fromScale(1, 0.5)
	buttons.frame.Parent = footer
	Kit.Button({
		text = text("result_back"),
		style = "secondary",
		name = "Back",
		layoutOrder = 1,
		onClick = function()
			handlers.onBack()
		end,
	}).frame.Parent =
		buttons.frame
	Kit.Button({
		text = text("result_close"),
		name = "Close",
		layoutOrder = 2,
		onClick = function()
			handlers.onClose()
		end,
	}).frame.Parent =
		buttons.frame

	return {
		destroy = function()
			root:Destroy()
		end,
	}
end

return Results
