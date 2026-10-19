--!strict
-- Recruiting/Firm (client UI, owned by `tutorial`): one firm's card on the Recruiting Board, plus the text helpers
-- the screen shares. The firm's logo (Assets/Logos, guarded: a monogram tile in its colours if it can't be drawn),
-- type and tagline, an eligibility badge, the dress level, honest reasons when the door is closed, the application
-- stage and scores, the exact odds, and the one action that applies now.
--
--   Firm.card(firm, opts) -> (Panel, Button?)   opts = { busy: boolean?, onAction: (action, firm) -> () }
--       firm = a row of TutorialService/Recruiting.board(); action = "apply" | "interview" | "superday" |
--       "retry" | "decide" | "offers"
--   Firm.pct(x) -> "37%"        Firm.errText(errKey?) -> string        Firm.STAGE_ORDER[stage] -> number

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))

export type Opts = { busy: boolean?, onAction: (action: string, firm: { [string]: any }) -> () }

local Firm = {}

local LOGO_SIZE = 56
Firm.STAGE_ORDER = {
	decision = 1,
	retry = 2,
	superday = 3,
	first_round = 4,
	offer = 5,
	rejected = 6,
	cut = 7,
} :: { [string]: number }
local ACTION_TEXT = {
	apply = "recruit_apply",
	interview = "recruit_interview",
	superday = "recruit_superday",
	retry = "recruit_retry",
	decide = "recruit_decide",
	offers = "recruit_view_offer",
} :: { [string]: string }

local function text(key: string, vars: { [string]: any }?): string
	return Quests.text(key, vars)
end

function Firm.pct(x: any): string
	local n = if type(x) == "number" and x == x then x else 0
	return string.format("%d%%", math.floor(math.clamp(n, 0, 1) * 100 + 0.5))
end

function Firm.errText(err: string?): string
	if err == "no_offer_service" then
		return text("recruit_no_offer_service")
	end
	local key = "recruit_err_" .. tostring(err)
	local s = Quests.strings[key]
	if type(s) == "string" then
		return Quests.fill(s, { max = Quests.recruiting.maxApplications })
	end
	return text("recruit_err_generic")
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

local logosModule: any = nil
local logosTried = false
local function logos(): any
	if not logosTried then
		logosTried = true
		local ok, mod = pcall(function()
			local assets = Shared:FindFirstChild("Assets")
			local m = assets and assets:FindFirstChild("Logos")
			return if m and m:IsA("ModuleScript") then (require :: any)(m) else nil
		end)
		if ok and type(mod) == "table" and type(mod.render) == "function" then
			logosModule = mod
		elseif not ok then
			warn("[Recruiting] Logos unavailable: " .. tostring(mod))
		end
	end
	return logosModule
end

-- The firm's logo in a square box; a monogram tile in its colours if the logo can't be drawn.
local function logoBox(parent: Instance, firm: { [string]: any }, order: number): Frame
	local colors = if type(firm.colors) == "table" then firm.colors else {}
	local primary = hexColor(colors.primary, Color3.fromRGB(40, 50, 70))
	local box = Instance.new("Frame")
	box.Name = "Logo"
	box.Size = UDim2.fromOffset(LOGO_SIZE, LOGO_SIZE)
	box.BackgroundColor3 = Color3.fromRGB(245, 243, 238)
	box.BorderSizePixel = 0
	box.ClipsDescendants = true
	box.LayoutOrder = order
	Kit.corner(box, 8)
	box.Parent = parent
	local L = logos()
	local drawn = false
	if L and type(firm.logo) == "string" then
		local ok = pcall(function()
			L.render(box, firm.logo, { px = LOGO_SIZE, simple = true, padding = 0.1, name = "Mark" })
		end)
		drawn = ok
	end
	if not drawn then
		box.BackgroundColor3 = primary
		local mono = Instance.new("TextLabel")
		mono.Name = "Monogram"
		mono.BackgroundTransparency = 1
		mono.Size = UDim2.fromScale(1, 1)
		mono.Text = string.upper(string.sub(tostring(firm.short or firm.name or "?"), 1, 2))
		mono.TextScaled = true
		mono.FontFace = Font.fromEnum(Enum.Font.GothamBold)
		mono.TextColor3 = hexColor(colors.text, Color3.new(1, 1, 1))
		mono.Parent = box
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 10)
		pad.PaddingBottom = UDim.new(0, 10)
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = mono
	end
	return box
end

local function hrow(name: string, order: number, gap: number?): Frame
	local f = Kit.frame(name, UDim2.new(1, 0, 0, 0))
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = order
	local l = Kit.list(f, true, gap or 10)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	return f
end

local function stageText(firm: { [string]: any }): string?
	local stage = firm.stage
	if stage == "first_round" then
		return text("recruit_stage_first_round")
	elseif stage == "superday" then
		return text("recruit_stage_superday")
	elseif stage == "retry" then
		return text("recruit_stage_retry", { q = firm.q2 or 0 })
	elseif stage == "decision" then
		return text("recruit_stage_decision")
	elseif stage == "offer" then
		return text("recruit_stage_offer")
	elseif stage == "rejected" then
		return text("recruit_stage_rejected")
	elseif stage == "cut" then
		return text("recruit_stage_cut", { q = firm.q1 or 0 })
	end
	return nil
end

local SETTLED = { rejected = true, offer = true } :: { [string]: boolean }

local function oddsText(firm: { [string]: any }): string?
	local stage: any = firm.stage
	if stage == "decision" and type(firm.chance) == "number" then
		return text("recruit_odds_now", { chance = Firm.pct(firm.chance), quality = firm.quality or 0 })
	end
	if firm.walkOn == true and stage ~= "offer" then
		return text("recruit_odds_walk_on", { bar = firm.walkOnBar or 0 })
	end
	if SETTLED[stage] and type(firm.chance) == "number" then
		return text("recruit_odds_was", { chance = Firm.pct(firm.chance) })
	end
	local preview = firm.preview
	if firm.eligible == true and stage == nil and type(preview) == "table" and #preview >= 3 then
		return text("recruit_odds_preview", {
			a = preview[1].quality,
			b = preview[2].quality,
			c = preview[3].quality,
			pa = Firm.pct(preview[1].chance),
			pb = Firm.pct(preview[2].chance),
			pc = Firm.pct(preview[3].chance),
		})
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- The card
---------------------------------------------------------------------------------------------------
function Firm.card(firm: { [string]: any }, opts: Opts): (Kit.Panel, Kit.Button?)
	local button: Kit.Button? = nil
	local colors = if type(firm.colors) == "table" then firm.colors else {}
	local panel = Kit.Panel({ name = "Firm_" .. tostring(firm.id), color = "panelAlt", list = true, gap = 6 })
	local stripe = Instance.new("Frame")
	stripe.Name = "Stripe"
	stripe.BorderSizePixel = 0
	stripe.Size = UDim2.new(1, 0, 0, 3)
	stripe.BackgroundColor3 = hexColor(colors.primary, Color3.fromRGB(80, 90, 110))
	panel.add(stripe)

	local header = hrow("Header", 1, 10)
	panel.add(header)
	logoBox(header, firm, 1)
	local info = Kit.frame("Info", UDim2.new(1, -(LOGO_SIZE + 130), 0, 0))
	info.AutomaticSize = Enum.AutomaticSize.Y
	info.LayoutOrder = 2
	info.Parent = header
	Kit.list(info, false, 2)
	Kit.Label({
		text = tostring(firm.name or firm.id),
		size = "lg",
		font = "bodyBold",
		name = "Name",
		layoutOrder = 1,
	}).frame.Parent =
		info
	local sub = tostring(firm.typeName or "")
	if type(firm.tagline) == "string" and firm.tagline ~= "" then
		sub = if sub ~= "" then sub .. " · " .. firm.tagline else firm.tagline
	end
	if sub ~= "" then
		Kit.Label({ text = sub, size = "xs", color = "textDim", name = "Type", layoutOrder = 2 }).frame.Parent = info
	end
	local badgeText, badgeColor
	if firm.walkOn == true then
		badgeText, badgeColor = text("recruit_walk_on_badge"), "good"
	elseif firm.eligible == true then
		badgeText, badgeColor = text("recruit_eligible"), "accent"
	else
		badgeText, badgeColor = text("recruit_ineligible"), "surface"
	end
	Kit.Badge({ text = badgeText, color = badgeColor, size = "xs", name = "Eligibility", layoutOrder = 3 }).frame.Parent =
		header

	local meta = text("recruit_dress", { level = firm.minOutfitLevel or 1 })
	if type(firm.culture) == "string" and firm.culture ~= "" then
		meta = meta .. " · " .. firm.culture
	end
	panel.add(Kit.Label({ text = meta, size = "xs", color = "textDim", name = "Meta" }))
	if firm.walkOn == true then
		panel.add(Kit.Label({ text = text("recruit_walk_on"), size = "sm", color = "good", name = "WalkOn" }))
	end
	if firm.eligible ~= true and type(firm.reasons) == "table" then
		for i, r in firm.reasons do
			if type(r) == "string" and r ~= "" then
				panel.add(Kit.Label({ text = r, size = "sm", color = "warn", name = "Reason" .. i }))
			end
		end
	end
	local stage = stageText(firm)
	if stage then
		local color = if firm.stage == "offer"
			then "good"
			elseif firm.stage == "rejected" or firm.stage == "cut" then "bad"
			else "accent"
		panel.add(Kit.Label({ text = stage, size = "md", font = "bodyBold", color = color, name = "Stage" }))
		if type(firm.q1) == "number" then
			local scores = if type(firm.q2) == "number"
				then text("recruit_scores_both", { q1 = firm.q1, q2 = firm.q2 })
				else text("recruit_scores_first", { q1 = firm.q1 })
			panel.add(Kit.Label({ text = scores, size = "xs", color = "textDim", name = "Scores" }))
		end
	end
	local odds = oddsText(firm)
	if odds then
		panel.add(Kit.Label({ text = odds, size = "sm", name = "Odds" }))
	end
	if firm.pendingOffer == true and firm.stage ~= "offer" then
		panel.add(Kit.Label({ text = text("recruit_err_has_offer"), size = "xs", color = "textDim", name = "Pending" }))
	end
	local action = if type(firm.action) == "string" then firm.action else nil
	local key = if action then ACTION_TEXT[action] else nil
	if action and key then
		local label = if action == "apply" and firm.stage == "offer" then text("recruit_reapply") else text(key)
		local b = Kit.Button({
			text = label,
			style = if action == "offers" then "secondary" else "primary",
			fill = true,
			disabled = opts.busy == true,
			name = "Action",
			onClick = function()
				opts.onAction(action, firm)
			end,
		})
		panel.add(b)
		button = b
	end
	return panel, button
end

return Firm
