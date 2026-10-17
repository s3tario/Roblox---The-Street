--!strict
-- CareerParts/Overview (client): the MyCareer hub's first tab. Everything is read from the replicated career
-- (Store "career"), so it renders instantly and stays correct when other features are missing.
--   Overview.build(scroll, career, ctx)   adds the cards to a Kit.Scroll
-- Cards: header (logo, title, company, status, level + XP), this week, promotion checklist, career stats,
-- pending offers, and the between-jobs / student guidance.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Companies = require(Shared.Config.Companies)
local CareerState = require(Shared.Logic.CareerState)
local Common = require(script.Parent.Common)
local Kit = Common.Kit

local Overview = {}

local function num(x: any, default: number): number
	if type(x) == "number" and x == x then
		return x
	end
	return default
end

local function header(scroll: any, career: { [string]: any })
	local card = Kit.Card({ name = "Header", padding = 14 })
	scroll.add(card)
	local top = Kit.frame("Top", UDim2.new(1, 0, 0, 72))
	top.Parent = card.content
	top.LayoutOrder = 1

	local logoBox = Kit.frame("Logo", UDim2.fromOffset(72, 72))
	logoBox.Parent = top
	local company = Companies.get(career.companyId)
	if company and CareerState.isEmployed(career) then
		Common.logo(logoBox, company.logo, { background = true, corner = 0.18, px = 72 }, company.short)
	else
		local glyph = Kit.Label({
			text = if career.status == "fired" then "◇" else "🎓",
			size = "xxl",
			align = "center",
			autoSize = "none",
			height = 72,
		})
		glyph.frame.Size = UDim2.fromScale(1, 1)
		glyph.frame.Parent = logoBox
	end

	local text = Kit.frame("Text", UDim2.new(1, -84, 1, 0))
	text.Position = UDim2.fromOffset(84, 0)
	text.Parent = top
	Kit.list(text, false, 2)
	local title =
		Kit.Heading({ text = career.roleTitle or career.title or "", level = 2, name = "Title", layoutOrder = 1 })
	title.frame.Parent = text
	local sub = career.companyName
	if type(sub) ~= "string" or sub == "" then
		sub = if career.status == "fired" then Common.text("week_between") else Common.text("ui_company_none")
	end
	Kit.Label({ text = sub, size = "sm", color = "textDim", name = "Company", layoutOrder = 2 }).frame.Parent = text
	local chips = Kit.List({ direction = "horizontal", gap = 6, autoSize = "xy", name = "Chips", layoutOrder = 3 })
	chips.frame.Parent = text
	chips.add(Common.chip(Common.statusText(career.status), Common.statusColor(career.status)))
	if career.reviewDue then
		chips.add(Common.chip(Common.text("ui_review_chip"), "warn"))
	end

	-- level + XP
	local level = math.floor(num(career.level, 1))
	local need = math.max(1, num(career.xpToNext, 1))
	local xp = num(career.xp, 0)
	local capped = level >= num(career.levelCap, 100) and xp >= need
	local levelRow = Kit.frame("LevelRow", UDim2.new(1, 0, 0, 24))
	levelRow.LayoutOrder = 2
	levelRow.Parent = card.content
	local lv = Kit.Badge({ text = Common.text("ui_level", { level = level }), color = "accent", size = "sm" })
	lv.frame.Parent = levelRow
	local xpText = Kit.Label({
		text = if capped
			then Common.text("ui_xp_capped")
			else Common.text("ui_xp", { xp = Format.commas(math.floor(xp)), next = Format.commas(need) }),
		size = "xs",
		font = "mono",
		color = "textDim",
		align = "right",
		autoSize = "none",
		height = 24,
	})
	xpText.frame.Size = UDim2.new(1, -100, 1, 0)
	xpText.frame.Position = UDim2.new(0, 100, 0, 0)
	xpText.frame.Parent = levelRow
	local bar = Kit.ProgressBar({ value = math.clamp(xp / need, 0, 1), height = 10, layoutOrder = 3 })
	bar.frame.Parent = card.content
end

local function week(scroll: any, career: { [string]: any })
	if not CareerState.isEmployed(career) then
		return
	end
	local card = Kit.Card({ title = Common.text("ui_week"), subtitle = career.weekLabel, name = "Week" })
	scroll.add(card)
	local active = num(career.weekActive, 0)
	local progress = math.clamp(active / CareerState.DUE_AT, 0, 1)
	card.add(Kit.ProgressBar({ value = progress, height = 12, color = if career.reviewDue then "warn" else "accent" }))
	local line: string
	if career.reviewDue then
		line = Common.text("ui_review_due", { boss = career.bossName or "" })
	else
		local remaining = num(career.windowRemaining, -1)
		line = Common.text("ui_week_progress", {
			day = Common.text("day_long_" .. CareerState.weekday(active)),
			minutes = if remaining >= 0 then Common.minutes(remaining) else "?",
		})
	end
	card.add(Kit.Label({ text = line, size = "sm", color = if career.reviewDue then "warn" else "text" }))
	local w = if type(career.weekWork) == "table" then career.weekWork else {}
	local count = math.floor(num(w.count, 0))
	local avg = if count > 0 then math.floor(num(w.qualitySum, 0) / count + 0.5) else 0
	card.add(Kit.Label({
		text = Common.text("ui_week_work", { count = count, avg = avg, core = math.floor(num(w.core, 0)) }),
		size = "xs",
		color = "textDim",
	}))
end

local function checklist(scroll: any, career: { [string]: any })
	local promo = if type(career.promotion) == "table" then career.promotion else {}
	local card = Kit.Card({ title = Common.text("ui_promotion"), name = "Promotion" })
	scroll.add(card)
	local headline = promo.headline
	if type(headline) ~= "string" or headline == "" then
		headline = if type(promo.missing) == "table" and type(promo.missing[1]) == "string"
			then promo.missing[1]
			else ""
	end
	if headline ~= "" then
		card.add(Kit.Label({
			text = headline,
			size = "md",
			font = "bodyBold",
			color = if promo.ready then "good" else "text",
		}))
	end
	if promo.fastTrack then
		card.add(Kit.Label({ text = Common.text("fast_track"), size = "xs", color = "accent" }))
	end
	local items = if type(promo.checklist) == "table" then promo.checklist else {}
	for _, item in items do
		if type(item) == "table" and type(item.text) == "string" then
			local row = Kit.frame("Item_" .. tostring(item.id), UDim2.new(1, 0, 0, 0))
			row.AutomaticSize = Enum.AutomaticSize.Y
			local glyph = if item.ok then "✓" elseif item.pending then "…" else "✗"
			local color = if item.ok then "good" elseif item.pending then "textDim" else "bad"
			local mark = Kit.Label({
				text = glyph,
				size = "md",
				font = "bodyBold",
				color = color,
				autoSize = "none",
				height = 22,
			})
			mark.frame.Size = UDim2.fromOffset(24, 22)
			mark.frame.Parent = row
			local textLabel = Kit.Label({
				text = if item.pending then Common.text("ui_score_pending") else item.text,
				size = "sm",
				color = if item.ok then "textDim" else "text",
				width = UDim.new(1, -28),
			})
			textLabel.frame.Position = UDim2.fromOffset(28, 1)
			textLabel.frame.Parent = row
			card.add(row)
		end
	end
end

local function stats(scroll: any, career: { [string]: any })
	local card = Kit.Card({ title = Common.text("ui_stats"), name = "Stats" })
	scroll.add(card)
	local grid = Kit.Grid({ columns = 2, cellHeight = 58, gap = 8, name = "StatGrid" })
	card.add(grid)
	local function tile(label: string, value: string, color: string?)
		local cell = Kit.Panel({ color = "surface", padding = 8, autoSize = "none", size = UDim2.fromScale(1, 1) })
		Kit.list(cell.frame, false, 2)
		cell.add(Kit.Label({ text = label, size = "xs", color = "textDim" }))
		cell.add(Kit.Label({ text = value, size = "lg", font = "mono", color = color or "text" }))
		grid.add(cell)
	end
	tile(Common.text("ui_prestige"), Format.commas(math.floor(num(career.prestige, 0))), "accent")
	tile(Common.text("ui_plaques"), tostring(math.floor(num(career.plaqueCount, 0))))
	tile(Common.text("ui_deal_mastery"), Format.commas(math.floor(num(career.dealMastery, 0))))
	tile(Common.text("ui_reputation"), Format.commas(math.floor(num(career.reputation, 0))))
	local outfit = math.floor(num(career.outfitLevel, 1))
	local dress = math.floor(num(career.dressLevel, 1))
	tile(
		Common.text("ui_outfit_level"),
		tostring(outfit) .. " / " .. tostring(dress),
		if outfit >= dress then "good" else "warn"
	)
	tile(Common.text("ui_fit_score"), tostring(math.floor(num(career.fitScore, 0))))
	if num(career.wipeouts, 0) > 0 or num(career.comebacks, 0) > 0 then
		tile(Common.text("ui_wipeouts"), tostring(math.floor(num(career.wipeouts, 0))), "bad")
		tile(Common.text("ui_comebacks"), tostring(math.floor(num(career.comebacks, 0))), "good")
	end
	if outfit < dress and CareerState.isEmployed(career) then
		card.add(Kit.Label({ text = Common.text("ui_dress_hint", { need = dress }), size = "xs", color = "warn" }))
	end
end

local function offers(scroll: any, career: { [string]: any }, ctx: any)
	local count = if type(career.offers) == "table" then #career.offers else 0
	if count == 0 then
		return
	end
	local card = Kit.Card({ name = "Offers", color = "surface" })
	scroll.add(card)
	card.add(Kit.Label({ text = Common.text("ui_offers_pending", { count = count }), size = "md", font = "bodyBold" }))
	card.add(Kit.Button({
		text = Common.text("ui_view_offers"),
		fill = true,
		onClick = function()
			if ctx.UI then
				ctx.UI:Open("Offers")
			end
		end,
	}))
end

local function guidance(scroll: any, career: { [string]: any }, ctx: any)
	if career.status == "fired" then
		local card = Kit.Card({ name = "Fired", color = "surface" })
		scroll.add(card)
		card.add(Kit.Label({ text = Common.text("ui_fired_card"), size = "md" }))
		card.add(Kit.Button({
			text = Common.text("ui_career_services"),
			fill = true,
			onClick = function()
				if ctx.UI then
					ctx.UI:Open("CareerServices")
				end
			end,
		}))
	elseif not CareerState.isEmployed(career) then
		local card = Kit.Card({ name = "Student", color = "surface" })
		scroll.add(card)
		card.add(Kit.Label({ text = Common.text("promo_student"), size = "md" }))
		card.add(Kit.Label({ text = Common.text("services_recruiting"), size = "sm", color = "textDim" }))
	end
end

function Overview.build(scroll: any, career: { [string]: any }, ctx: any)
	header(scroll, career)
	offers(scroll, career, ctx)
	guidance(scroll, career, ctx)
	week(scroll, career)
	if CareerState.isEmployed(career) then
		checklist(scroll, career)
	end
	stats(scroll, career)
end

return Overview
