--!strict
-- CareerParts/Breakdown (client): the two cards of the review meeting.
--   Breakdown.card(parent, payload) -> Frame        the four components (weights, animated bars), the score and
--                                                   band, and Friday's pay
--   Breakdown.reveal(parent, payload, onContinue) -> (Frame, sound)   the outcome reveal: Promoted / Keep up the
--                                                   good work / Warning / Probation / Fired / Saved by the Lifeline
-- Both are centred cards sized for phones (max 460 px wide).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Common = require(script.Parent.Common)
local Kit = Common.Kit

local Breakdown = {}

local COMPONENTS = { "investment", "risk", "work", "reputation" }

local function num(x: any, default: number): number
	if type(x) == "number" and x == x then
		return x
	end
	return default
end

local function centred(parent: Instance, name: string): Frame
	local card = Instance.new("Frame")
	card.Name = name
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.47)
	card.Size = UDim2.new(1, -24, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BorderSizePixel = 0
	card.ZIndex = 5
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, math.huge)
	limit.Parent = card
	local corner = Kit.corner(card)
	local stroke = Kit.stroke(card)
	Kit.padding(card, 18)
	Kit.list(card, false, 10)
	Kit.themed(card, function(t)
		card.BackgroundColor3 = t.colors.panel
		card.BackgroundTransparency = 0.02
		corner.CornerRadius = UDim.new(0, t.radius)
		stroke.Color = t.colors.accent
		stroke.Thickness = t.stroke + 1
	end)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.92
	scale.Parent = card
	card.Parent = parent
	Kit.tween(scale, 0.25, { Scale = 1 })
	return card
end

function Breakdown.card(parent: Instance, payload: { [string]: any }): Frame
	local card = centred(parent, "Breakdown")
	local order = 0
	local function add(inst: GuiObject)
		order += 1
		inst.LayoutOrder = order
		inst.Parent = card
	end
	add(Kit.Label({
		text = Common.text("meeting_breakdown", { week = math.floor(num(payload.week, 1)) }),
		size = "lg",
		font = "heading",
		align = "center",
	}).frame)

	local scoreRow = Kit.frame("Score", UDim2.new(1, 0, 0, 56))
	local score = Kit.Label({
		text = tostring(math.floor(num(payload.score, 0))),
		size = "xxl",
		font = "mono",
		align = "center",
		autoSize = "none",
		height = 40,
	})
	score.frame.Size = UDim2.new(1, 0, 0, 40)
	score.frame.Parent = scoreRow
	local band = Common.chip(tostring(payload.bandName or ""), Common.bandColor(payload.band))
	band.frame.AnchorPoint = Vector2.new(0.5, 0)
	band.frame.Position = UDim2.new(0.5, 0, 0, 38)
	band.frame.Parent = scoreRow
	add(scoreRow)

	local comps = if type(payload.components) == "table" then payload.components else {}
	local weights = if type(payload.weights) == "table" then payload.weights else {}
	for i, id in COMPONENTS do
		local value = math.clamp(math.floor(num(comps[id], 0)), 0, 100)
		local row = Kit.frame("Comp_" .. id, UDim2.new(1, 0, 0, 38))
		local label = Kit.Label({
			text = Common.text("comp_" .. id),
			size = "sm",
			autoSize = "none",
			height = 18,
		})
		label.frame.Size = UDim2.new(1, -90, 0, 18)
		label.frame.Parent = row
		local weight = Kit.Label({
			text = Common.text("meeting_weight", { weight = math.floor(num(weights[id], 0) * 100 + 0.5) }),
			size = "xs",
			color = "textDim",
			align = "right",
			autoSize = "none",
			height = 18,
		})
		weight.frame.Size = UDim2.new(0, 40, 0, 18)
		weight.frame.AnchorPoint = Vector2.new(1, 0)
		weight.frame.Position = UDim2.new(1, -44, 0, 0)
		weight.frame.Parent = row
		local v = Kit.Label({
			text = tostring(value),
			size = "sm",
			font = "mono",
			align = "right",
			autoSize = "none",
			height = 18,
		})
		v.frame.Size = UDim2.new(0, 40, 0, 18)
		v.frame.AnchorPoint = Vector2.new(1, 0)
		v.frame.Position = UDim2.fromScale(1, 0)
		v.frame.Parent = row
		local bar = Kit.ProgressBar({
			value = 0,
			height = 10,
			color = if value >= 70 then "good" elseif value >= 55 then "warn" else "bad",
		})
		bar.frame.Position = UDim2.fromOffset(0, 24)
		bar.frame.Parent = row
		add(row)
		task.delay(0.15 + i * 0.18, function()
			if bar.frame.Parent then
				bar.set(value / 100)
			end
		end)
	end

	local pay = payload.pay
	if type(pay) == "table" then
		local payBox = Kit.frame("Pay", UDim2.new(1, 0, 0, 0))
		payBox.AutomaticSize = Enum.AutomaticSize.Y
		Kit.list(payBox, false, 2)
		Common.row(payBox, Common.text("meeting_salary"), "+" .. Common.money(num(pay.salary, 0)), 1, true)
		if num(pay.bonus, 0) > 0 then
			Common.row(payBox, Common.text("meeting_bonus"), "+" .. Common.money(num(pay.bonus, 0)), 2, true)
		end
		if num(pay.living, 0) > 0 then
			Common.row(payBox, Common.text("meeting_living"), "-" .. Common.money(num(pay.living, 0)), 3, true)
		end
		if num(payload.xp, 0) > 0 then
			Common.row(payBox, Common.text("meeting_xp"), "+" .. Format.commas(math.floor(num(payload.xp, 0))), 4, true)
		end
		if num(payload.prestige, 0) > 0 then
			Common.row(
				payBox,
				Common.text("ui_prestige"),
				"+" .. Format.commas(math.floor(num(payload.prestige, 0))),
				5,
				true
			)
		end
		add(payBox)
	end
	add(Kit.Label({ text = Common.text("meeting_skip"), size = "xs", color = "textDim", align = "center" }).frame)
	return card
end

local REVEAL: { [string]: { key: string, color: string, sound: string } } = {
	promoted = { key = "meeting_promoted", color = "accent", sound = "promotion" },
	keep_going = { key = "meeting_keep_going", color = "good", sound = "good" },
	warning = { key = "meeting_warning", color = "warn", sound = "bad" },
	probation = { key = "meeting_probation", color = "bad", sound = "bad" },
	fired = { key = "meeting_fired", color = "bad", sound = "bad" },
	saved = { key = "meeting_saved", color = "accent", sound = "chime" },
}

function Breakdown.revealKind(payload: { [string]: any }): string
	if payload.lifeline then
		return "saved"
	end
	if payload.outcome == "warning" and payload.status == "probation" then
		return "probation"
	end
	if REVEAL[payload.outcome] then
		return payload.outcome
	end
	return "keep_going"
end

function Breakdown.reveal(parent: Instance, payload: { [string]: any }, onContinue: () -> ()): (Frame, string)
	local kind = Breakdown.revealKind(payload)
	local spec = REVEAL[kind]
	local card = centred(parent, "Reveal")
	local order = 0
	local function add(inst: GuiObject)
		order += 1
		inst.LayoutOrder = order
		inst.Parent = card
	end
	local big = Kit.Label({
		text = Common.text(spec.key),
		size = "xxl",
		font = "display",
		align = "center",
		color = spec.color,
	})
	add(big.frame)
	if type(payload.newTitle) == "string" and payload.newTitle ~= "" then
		add(Kit.Label({
			text = Common.text("meeting_new_title", { title = payload.newTitle }),
			size = "lg",
			font = "heading",
			align = "center",
		}).frame)
		if payload.newOffice then
			add(
				Kit.Label({ text = Common.text("office_earned"), size = "sm", color = "textDim", align = "center" }).frame
			)
		end
	end
	if kind == "keep_going" and type(payload.missing) == "table" and #payload.missing > 0 then
		add(Kit.Label({ text = Common.text("meeting_next_steps"), size = "sm", font = "bodyBold" }).frame)
		for i, line in payload.missing do
			if type(line) == "string" and i <= 4 then
				add(Kit.Label({ text = "• " .. line, size = "sm", color = "textDim" }).frame)
			end
		end
	end
	if kind == "probation" then
		add(
			Kit.Label({ text = Common.text("meeting_probation_hint"), size = "sm", color = "textDim", align = "center" }).frame
		)
	end
	if kind == "fired" then
		add(
			Kit.Label({ text = Common.text("meeting_services_hint"), size = "sm", color = "textDim", align = "center" }).frame
		)
	end
	if kind == "saved" then
		add(
			Kit.Label({ text = Common.text("lifeline_subtitle"), size = "sm", color = "textDim", align = "center" }).frame
		)
	end
	local button = Kit.Button({ text = Common.text("meeting_continue"), fill = true, onClick = onContinue })
	add(button.frame)
	return card, spec.sound
end

return Breakdown
