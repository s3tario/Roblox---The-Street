--!strict
-- CareerParts/History (client): the Reviews tab (score chart + table) and the Timeline tab of the Career hub.
--   History.reviews(scroll, career)
--   History.timeline(scroll, career)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local Common = require(script.Parent.Common)
local Kit = Common.Kit

local History = {}

local function num(x: any, default: number): number
	if type(x) == "number" and x == x then
		return x
	end
	return default
end

local dateText = Common.date

function History.reviews(scroll: any, career: { [string]: any })
	local reviews = if type(career.reviews) == "table" then career.reviews else {}
	local card = Kit.Card({ title = Common.text("ui_reviews"), name = "ReviewChart" })
	scroll.add(card)
	if #reviews == 0 then
		card.add(Kit.Label({ text = Common.text("ui_reviews_empty"), size = "sm", color = "textDim" }))
		return
	end
	local points: { number } = {}
	for _, r in reviews do
		if type(r) == "table" then
			table.insert(points, num(r.score, 0))
		end
	end
	if #points == 1 then
		table.insert(points, 1, points[1])
	end
	card.add(Kit.LineChart({
		series = { { points = points, color = "accent", thickness = 2 } },
		baseline = 70,
		minY = 0,
		maxY = 100,
		size = UDim2.new(1, 0, 0, 170),
		yFormat = function(v: number): string
			return tostring(math.floor(v + 0.5))
		end,
	}))
	card.add(Kit.Label({ text = Common.text("ui_chart_hint"), size = "xs", color = "textDim" }))

	local last = reviews[#reviews]
	if type(last) == "table" and type(last.components) == "table" then
		local comps = Kit.Card({ title = Common.text("ui_last_review"), name = "LastReview", color = "surface" })
		scroll.add(comps)
		for i, id in { "investment", "risk", "work", "reputation" } do
			local value = math.floor(num(last.components[id], 0))
			local row = Kit.frame("Comp_" .. id, UDim2.new(1, 0, 0, 34))
			row.LayoutOrder = i
			local label = Kit.Label({ text = Common.text("comp_" .. id), size = "xs", color = "textDim" })
			label.frame.Parent = row
			local bar = Kit.ProgressBar({
				value = value / 100,
				height = 8,
				color = if value >= 70 then "good" elseif value >= 55 then "warn" else "bad",
				width = UDim.new(1, -44),
			})
			bar.frame.Position = UDim2.fromOffset(0, 20)
			bar.frame.Parent = row
			local v = Kit.Label({
				text = tostring(value),
				size = "sm",
				font = "mono",
				align = "right",
				autoSize = "none",
				height = 34,
			})
			v.frame.Size = UDim2.new(0, 40, 1, 0)
			v.frame.AnchorPoint = Vector2.new(1, 0)
			v.frame.Position = UDim2.fromScale(1, 0)
			v.frame.Parent = row
			comps.add(row)
		end
	end

	local list = Kit.Card({ title = Common.text("ui_review_list"), name = "ReviewList" })
	scroll.add(list)
	for i = #reviews, math.max(1, #reviews - 11), -1 do
		local r = reviews[i]
		if type(r) == "table" then
			local row = Kit.frame("Review_" .. i, UDim2.new(1, 0, 0, 44))
			local left = Kit.Label({
				text = Tracks.text("week_label", { week = math.floor(num(r.week, 0)), day = dateText(r.at) }),
				size = "sm",
				font = "bodyBold",
				autoSize = "none",
				height = 22,
			})
			left.frame.Size = UDim2.new(0.55, 0, 0, 22)
			left.frame.Parent = row
			local outcome = Common.text("outcome_" .. tostring(r.outcome))
			if r.lifeline then
				outcome = Common.text("outcome_saved")
			end
			local sub = Kit.Label({ text = outcome, size = "xs", color = "textDim", autoSize = "none", height = 20 })
			sub.frame.Size = UDim2.new(0.6, 0, 0, 20)
			sub.frame.Position = UDim2.fromOffset(0, 22)
			sub.frame.Parent = row
			local band = Common.chip(
				tostring(math.floor(num(r.score, 0))) .. " · " .. Common.text("band_" .. tostring(r.band)),
				Common.bandColor(r.band)
			)
			band.frame.AnchorPoint = Vector2.new(1, 0.5)
			band.frame.Position = UDim2.fromScale(1, 0.5)
			band.frame.Parent = row
			list.add(row)
		end
	end
end

local function entryText(e: { [string]: any }): string
	local company = Companies.get(e.companyId)
	local vars = {
		title = e.title or "",
		company = if company then company.name else "",
		name = e.name or "",
	}
	local key = "timeline_" .. tostring(e.kind)
	if Tracks.strings[key] then
		return Tracks.text(key, vars)
	end
	return tostring(e.kind)
end

function History.timeline(scroll: any, career: { [string]: any })
	local history = if type(career.history) == "table" then career.history else {}
	local card = Kit.Card({ title = Common.text("ui_timeline"), name = "Timeline" })
	scroll.add(card)
	if #history == 0 then
		card.add(Kit.Label({ text = Common.text("ui_timeline_empty"), size = "sm", color = "textDim" }))
		return
	end
	for i = #history, 1, -1 do
		local e = history[i]
		if type(e) == "table" then
			local row = Kit.frame("Entry_" .. i, UDim2.new(1, 0, 0, 0))
			row.AutomaticSize = Enum.AutomaticSize.Y
			local dot = Instance.new("Frame")
			dot.Name = "Dot"
			dot.Size = UDim2.fromOffset(10, 10)
			dot.Position = UDim2.fromOffset(2, 6)
			dot.BorderSizePixel = 0
			Kit.corner(dot, 5)
			local kind = tostring(e.kind)
			Kit.themed(dot, function(t)
				dot.BackgroundColor3 = if kind == "fired"
					then t.colors.bad
					elseif kind == "promotion" or kind == "top_title" then t.colors.accent
					else t.colors.good
			end)
			dot.Parent = row
			local body = Kit.frame("Body", UDim2.new(1, -20, 0, 0))
			body.AutomaticSize = Enum.AutomaticSize.Y
			body.Position = UDim2.fromOffset(20, 0)
			Kit.list(body, false, 0)
			body.Parent = row
			Kit.Label({ text = entryText(e), size = "sm", font = "bodyBold", layoutOrder = 1 }).frame.Parent = body
			local meta = Common.text("timeline_meta", {
				week = math.floor(num(e.week, 0)),
				level = math.floor(num(e.level, 1)),
				date = dateText(e.at),
			})
			Kit.Label({ text = meta, size = "xs", color = "textDim", layoutOrder = 2 }).frame.Parent = body
			card.add(row)
		end
	end
end

return History
