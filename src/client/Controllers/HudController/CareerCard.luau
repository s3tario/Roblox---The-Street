--!strict
-- HUD career card (top-left): role title, level, XP bar, cash and the review status chip.
-- Reads replicated data defensively: every field may be missing while other features are absent.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Strings = require(Shared.Config.Strings)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))

local CareerCard = {}

export type Card = {
	frame: Frame,
	setCareer: (career: any) -> (),
	setCash: (cash: any) -> (),
}

-- Shared/Config/Careers is owned by `career`; use it for titles and XP curves when it exists.
local careersCache: any = false
local function careers(): any
	if careersCache == false then
		careersCache = nil
		local config = Shared:FindFirstChild("Config")
		local mod = config and config:FindFirstChild("Careers")
		if mod and mod:IsA("ModuleScript") then
			local ok, res = pcall(require, mod)
			if ok and type(res) == "table" then
				careersCache = res
			end
		end
	end
	return careersCache
end

local function prettify(id: string): string
	local words = {}
	for word in string.gmatch(id, "[^_]+") do
		table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
	end
	return table.concat(words, " ")
end

function CareerCard.roleTitle(career: any): string
	if type(career) ~= "table" then
		return Strings.get("role_student")
	end
	if type(career.roleTitle) == "string" and career.roleTitle ~= "" then
		return career.roleTitle
	end
	local roleId = career.roleId
	if type(roleId) == "string" and roleId ~= "" then
		local c = careers()
		local role = c and type(c.roles) == "table" and c.roles[roleId]
		if type(role) == "table" and type(role.title) == "string" then
			return role.title
		end
		if roleId == "student" then
			return Strings.get("role_student")
		end
		return prettify(roleId)
	end
	return Strings.get("role_student")
end

function CareerCard.xpToNext(career: any, level: number): number?
	if type(career) == "table" and type(career.xpToNext) == "number" and career.xpToNext > 0 then
		return career.xpToNext
	end
	local c = careers()
	if c and type(c.xpForLevel) == "function" then
		local ok, n = pcall(c.xpForLevel, level)
		if ok and type(n) == "number" and n > 0 then
			return n
		end
	end
	return nil
end

-- Status chip text and colour key, or nil to hide it.
function CareerCard.statusChip(career: any): (string?, string)
	if type(career) ~= "table" then
		return nil, "accent"
	end
	local rank = career.rank
	local status = career.status
	if rank == 0 or (rank == nil and career.roleId == "student") then
		return nil, "accent"
	end
	local remaining = career.windowRemaining
	local timeText: string? = nil
	if type(remaining) == "number" and remaining >= 0 then
		local minutes = math.ceil(remaining / 60)
		timeText = if remaining >= 60 then tostring(minutes) .. "m" else tostring(math.floor(remaining)) .. "s"
	end
	if status == "review_due" then
		return Strings.get("status_review_due"), "warn"
	elseif status == "coaching" then
		return Strings.get("status_coaching") .. (if timeText then " · " .. timeText else ""), "warn"
	elseif status == "probation" then
		return Strings.get("status_probation") .. (if timeText then " · " .. timeText else ""), "bad"
	elseif status == "fired" then
		return Strings.get("status_fired"), "bad"
	end
	if timeText then
		return Strings.format("hud_review_in", { time = timeText }), "good"
	end
	if status == "active" then
		return Strings.get("status_active"), "good"
	end
	return nil, "accent"
end

function CareerCard.new(onLevelUp: (() -> ())?): Card
	local panel = Kit.Panel({ name = "CareerCard", size = UDim2.fromOffset(300, 0), autoSize = "y", padding = 10 })
	local frame = panel.frame
	Kit.list(frame, false, 6)

	-- Row 1: title + level
	local row1 = Kit.frame("TitleRow", UDim2.new(1, 0, 0, 26))
	row1.LayoutOrder = 1
	row1.Parent = frame
	local title = Kit.Label({
		text = Strings.get("role_student"),
		size = "lg",
		font = "heading",
		autoSize = "none",
		height = 26,
		name = "Role",
	})
	title.frame.Size = UDim2.new(1, -70, 1, 0)
	title.frame.Parent = row1
	local level = Kit.Badge({ text = Strings.format("hud_level", { level = 1 }), color = "accent", size = "sm" })
	level.frame.Name = "Level"
	level.frame.AnchorPoint = Vector2.new(1, 0.5)
	level.frame.Position = UDim2.fromScale(1, 0.5)
	level.frame.Parent = row1

	-- Row 2: XP bar + numbers
	local xpBar = Kit.ProgressBar({ value = 0, height = 8, name = "XPBar", layoutOrder = 2 })
	xpBar.frame.Parent = frame
	local xpText = Kit.Label({ text = "", size = "xs", font = "mono", color = "textDim", name = "XP", layoutOrder = 3 })
	xpText.frame.Parent = frame

	-- Row 3: cash + status chip
	local row3 = Kit.frame("CashRow", UDim2.new(1, 0, 0, 28))
	row3.LayoutOrder = 4
	row3.Parent = frame
	local cash = Kit.Label({
		text = Format.money(0),
		size = "lg",
		font = "mono",
		color = "good",
		autoSize = "none",
		height = 28,
	})
	cash.frame.Name = "Cash"
	cash.frame.Size = UDim2.new(0.55, 0, 1, 0)
	cash.frame.Parent = row3
	local chip = Kit.Badge({ text = "", color = "good", size = "xs" })
	chip.frame.Name = "Status"
	chip.frame.AnchorPoint = Vector2.new(1, 0.5)
	chip.frame.Position = UDim2.fromScale(1, 0.5)
	chip.frame.Visible = false
	chip.frame.Parent = row3

	local lastLevel: number? = nil
	local lastCash: number? = nil
	local cashColor = "good"

	local function setCareer(career: any)
		local c = if type(career) == "table" then career else {}
		title.setText(CareerCard.roleTitle(c))
		local lv = if type(c.level) == "number" then math.max(1, math.floor(c.level)) else 1
		level.setText(Strings.format("hud_level", { level = lv }))
		if lastLevel and lv > lastLevel and onLevelUp then
			onLevelUp()
		end
		lastLevel = lv
		local xp = if type(c.xp) == "number" then math.max(0, c.xp) else 0
		local toNext = CareerCard.xpToNext(c, lv)
		if toNext then
			xpBar.set(math.clamp(xp / toNext, 0, 1))
			xpText.setText(Strings.format("hud_xp", { xp = Format.commas(xp), next = Format.commas(toNext) }))
		else
			xpBar.set(0)
			xpText.setText(Strings.format("hud_xp_only", { xp = Format.commas(xp) }))
		end
		local text, color = CareerCard.statusChip(c)
		if text then
			chip.setText(text)
			chip.setColor(color)
			chip.frame.Visible = true
		else
			chip.frame.Visible = false
		end
	end

	local function setCash(value: any)
		local n = if type(value) == "number" and value == value then value else 0
		cash.setText(Format.money(n))
		if lastCash ~= nil and n ~= lastCash then
			-- Brief colour pulse: green up, red down, then back.
			local pulse = if n > lastCash then "good" else "bad"
			cash.setColor(pulse)
			task.delay(0.6, function()
				cash.setColor(cashColor)
			end)
		end
		lastCash = n
	end

	setCareer(nil)
	return { frame = frame, setCareer = setCareer, setCash = setCash }
end

return CareerCard
