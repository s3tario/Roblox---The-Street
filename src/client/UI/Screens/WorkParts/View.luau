--!strict
-- Work screen view rules (owned by `work`). PURE: no services, no Instances; tested under Lune.
--
--   View.title(board) / View.subtitle(board) -> string        board header ("Today's work" / "Campus to-do")
--   View.emptyText(board) -> string?                           why the list is empty or finished (nil otherwise)
--   View.deskText(board) -> (text, colorKey)
--   View.cardAction(card, now, active?) -> { action, text, enabled, style }
--       action = "start" | "resume" | "done" | "cooldown" | "busy"
--   View.cardTags(card, now) -> { { text, color } }             category, core, offered, carried, expiry
--   View.cardMeta(card) -> string                               "~120 XP · ~$480 · 3:30 limit"
--   View.qualityColor(q) -> colorKey   View.band(q) -> "great" | "good" | "ok" | "weak" | "bad"
--   View.progress(payload, answers) -> (answered, total)        Kinds.answered / Kinds.answerTotal
--   View.timer(endsAt, now) -> (text, overtime: boolean)
--   View.canUsePrompt(career, events, attrs, now, partnersFn?) -> boolean
--       attrs = { employeesOnly, companyId?, studentsOnly }: hide office desks from visitors (Merger Mania partners
--       allowed via partnersFn = CareerState.mergerPartners) and campus desks from employees
--   View.errorText(errKey) -> string

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Tasks"))
local Kinds = require(Shared:WaitForChild("Logic"):WaitForChild("Tasks"):WaitForChild("_shared"):WaitForChild("Kinds"))

local View = {}

export type Action = { action: string, text: string, enabled: boolean, style: string }
export type Tag = { text: string, color: string }

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function View.title(board: any): string
	if type(board) == "table" and board.student == true then
		return Config.text("board_title_student")
	end
	return Config.text("board_title")
end

function View.subtitle(board: any): string
	if type(board) ~= "table" then
		return ""
	end
	local day = if type(board.dayLabel) == "string" and board.dayLabel ~= "" then board.dayLabel else nil
	local done = math.floor(num(board.done, 0))
	local total = math.floor(num(board.total, 0))
	if day then
		return Config.text("board_subtitle", { day = day, done = done, total = total })
	end
	return string.format("%d/%d", done, total)
end

function View.emptyText(board: any): string?
	if type(board) ~= "table" then
		return Config.text("board_loading")
	end
	local total = math.floor(num(board.total, 0))
	local done = math.floor(num(board.done, 0))
	if total == 0 then
		if board.unemployed == true then
			return Config.text("board_unemployed")
		end
		return Config.text("board_empty")
	end
	if done >= total then
		local nextIn = num(board.nextIn, -1)
		if nextIn > 0 then
			return Config.text("board_all_done", { time = Format.duration(nextIn) })
		elseif nextIn < 0 and board.student ~= true and board.unemployed ~= true then
			return Config.text("board_friday")
		end
		return Config.text("board_all_done_soon")
	end
	return nil
end

function View.deskText(board: any): (string, string)
	local pct = if type(board) == "table" then math.floor(num(board.deskPct, 10)) else 10
	if type(board) == "table" and board.atDesk == true then
		return Config.text("board_desk_bonus", { pct = pct }), "good"
	end
	return Config.text("board_no_desk", { pct = pct }), "textDim"
end

function View.cardAction(card: any, now: number, active: any?): Action
	if type(card) ~= "table" then
		return { action = "busy", text = Config.text("board_start"), enabled = false, style = "secondary" }
	end
	if card.done == true then
		local q = card.quality
		return {
			action = "done",
			text = if type(q) == "number"
				then Config.text("board_quality", { q = math.floor(q) })
				else Config.text("board_done"),
			enabled = false,
			style = "ghost",
		}
	end
	if type(active) == "table" then
		if active.taskId == card.id then
			return { action = "resume", text = Config.text("board_resume"), enabled = true, style = "primary" }
		end
		return { action = "busy", text = Config.text("board_start"), enabled = false, style = "secondary" }
	end
	local cd = num(card.cooldownUntil, 0)
	if cd > now then
		return {
			action = "cooldown",
			text = Config.text("board_cooldown", { time = Format.clock(cd - now) }),
			enabled = false,
			style = "secondary",
		}
	end
	return { action = "start", text = Config.text("board_start"), enabled = true, style = "primary" }
end

function View.cardTags(card: any, now: number): { Tag }
	local tags: { Tag } = {}
	if type(card) ~= "table" then
		return tags
	end
	local cat = Config.category(card.category)
	table.insert(tags, { text = cat.glyph .. " " .. cat.name, color = cat.color })
	if card.core == true then
		table.insert(tags, { text = Config.text("board_core"), color = "warn" })
	end
	if card.offered == true then
		table.insert(tags, { text = Config.text("board_offered"), color = "good" })
		local exp = num(card.expiresAt, 0)
		if exp > now and card.done ~= true then
			table.insert(
				tags,
				{ text = Config.text("board_expires", { time = Format.duration(exp - now) }), color = "textDim" }
			)
		end
	end
	if card.carried == true then
		table.insert(tags, { text = Config.text("board_carry"), color = "textDim" })
	end
	if card.done == true then
		table.insert(tags, { text = Config.text("board_done"), color = "good" })
	end
	return tags
end

function View.cardMeta(card: any): string
	if type(card) ~= "table" then
		return ""
	end
	local xp = math.floor(num(card.xp, 0))
	local pay = math.floor(num(card.pay, 0))
	local parts: { string } = {}
	if pay > 0 then
		table.insert(parts, Config.text("board_estimate", { xp = Format.commas(xp), pay = Format.money(pay) }))
	else
		table.insert(parts, "~" .. Format.commas(xp) .. " XP")
	end
	table.insert(parts, Config.text("board_time", { time = Format.clock(num(card.timeLimit, 0)) }))
	return table.concat(parts, " · ")
end

function View.statsText(card: any): string?
	if type(card) ~= "table" or type(card.stats) ~= "table" or #card.stats == 0 then
		return nil
	end
	return Config.text("board_trained", { stats = table.concat(card.stats, ", ") })
end

function View.band(q: number): string
	return if q >= 90
		then "great"
		elseif q >= 75 then "good"
		elseif q >= 55 then "ok"
		elseif q >= 35 then "weak"
		else "bad"
end

function View.qualityColor(q: number): string
	return if q >= 75 then "good" elseif q >= 55 then "accent" elseif q >= 35 then "warn" else "bad"
end

function View.progress(payload: any, answers: any): (number, number)
	return Kinds.answered(payload, answers), Kinds.answerTotal(payload)
end

function View.timer(endsAt: number, now: number): (string, boolean)
	local left = endsAt - now
	if left >= 0 then
		return Format.clock(left), false
	end
	return Config.text("runner_overtime", { time = Format.clock(-left) }), true
end

local function isEmployed(career: any): boolean
	if type(career) ~= "table" then
		return false
	end
	local status = career.status
	if status == "student" or status == "fired" or career.roleId == "unemployed" then
		return false
	end
	return type(career.companyId) == "string" and career.companyId ~= ""
end

function View.canUsePrompt(
	career: any,
	events: any,
	attrs: { [string]: any },
	now: number,
	partnersFn: ((events: any, companyId: string, now: number?) -> { [string]: boolean })?
): boolean
	if attrs.studentsOnly == true then
		return not isEmployed(career)
	end
	if attrs.employeesOnly ~= true then
		return true
	end
	local companyId = attrs.companyId
	if type(companyId) ~= "string" or companyId == "" then
		return true -- the server will decide
	end
	if not isEmployed(career) then
		return false
	end
	local mine = career.companyId
	if mine == companyId then
		return true
	end
	if partnersFn then
		local ok, partners = pcall(partnersFn, events, mine, now)
		if ok and type(partners) == "table" and partners[companyId] == true then
			return true
		end
	end
	return false
end

function View.errorText(errKey: any): string
	return Config.errorText(errKey)
end

return View
