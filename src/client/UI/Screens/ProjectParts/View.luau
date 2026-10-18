--!strict
-- Project screen, view helpers (owned by `projects`). PURE: no services, no Instances; text comes from
-- Logic/Projects/_registry/Strings so it can be localized later.
--
--   View.errorText(errKey, vars?) -> string           the remote's error key as player-facing text
--   View.subtitle(list) -> string                     "Investment Banking · Associate"
--   View.emptyText(list) -> string?                   why the list is empty (student, fired, no deals yet)
--   View.cardAction(card, elapsed) -> Action           { kind = "start"|"resume"|"wait"|"locked", label, enabled }
--                                                      (elapsed = seconds since the list arrived, for cooldowns)
--   View.cardMeta(card) -> { string }                  stage count, rank range, best/closed, estimate
--   View.rankText(card) -> string                      "Analyst to Associate" / "Vice President to Managing Director"
--   View.qualityColor(q) -> colour token               View.band(q) -> "great"|"good"|"ok"|"weak"|"bad"
--   View.progress(payload, answers) -> (done, total)
--   View.wire(answers) -> any                          answers safe to send through a RemoteFunction (a table with
--                                                      holes or mixed keys gets string keys, which graders accept)
--   View.money(n) -> "$12,400"   View.commas(n) -> "12,400"

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Logic = Shared:WaitForChild("Logic")
local Registry = require(Logic:WaitForChild("Projects"):WaitForChild("_registry"))
local Kinds = require(Logic:WaitForChild("Tasks"):WaitForChild("_shared"):WaitForChild("Kinds"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local View = {}

local text = Registry.text

export type Action = { kind: string, label: string, enabled: boolean }

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function View.money(n: any): string
	return Format.money(math.floor(num(n, 0) + 0.5))
end

function View.commas(n: any): string
	return Format.commas(math.floor(num(n, 0) + 0.5))
end

-- Remote failures arrive as (false, key, vars) or Net's own (nil, "timeout" | "rate_limited" | "error" | "missing").
function View.errorText(errKey: any, vars: any): string
	local key = if type(errKey) == "string" and errKey ~= "" then errKey else "generic"
	if key == "error" or key == "missing" then
		key = if key == "missing" then "unavailable" else "generic"
	end
	local v: { [string]: any } = if type(vars) == "table" then vars else {}
	local t = text("err_" .. key, v)
	if t == "err_" .. key then
		return text("err_generic")
	end
	-- a template variable the server didn't send stays readable
	return (string.gsub(t, "{[%w_]+}", "…"))
end

function View.subtitle(list: any): string
	local who = if type(list) == "table" and type(list.who) == "table" then list.who else nil
	if who and who.employed == true and type(who.title) == "string" then
		local track = if type(who.trackName) == "string" then who.trackName else ""
		local base = if track ~= "" then text("subtitle_role", { track = track, title = who.title }) else who.title
		if type(who.company) == "string" and who.company ~= "" then
			return base .. " · " .. who.company
		end
		return base
	end
	return text("subtitle_none")
end

function View.emptyText(list: any): string?
	local who = if type(list) == "table" and type(list.who) == "table" then list.who else {}
	local cards = if type(list) == "table" and type(list.cards) == "table" then list.cards else {}
	if who.fired == true then
		return text("empty_fired")
	end
	if who.employed ~= true then
		return text("empty_student")
	end
	if #cards == 0 then
		return text("empty_track")
	end
	return nil
end

function View.rankText(card: any): string
	local lo = math.floor(num(card.rankLo, 1))
	local hi = card.rankHi
	local track = if type(card.track) == "string" then card.track else nil
	local loTitle = Registry.rankTitle(track, lo)
	if type(hi) ~= "number" then
		return text("card_ranks", { lo = loTitle, hi = "…" })
	end
	if hi == lo then
		return text("card_rank_one", { lo = loTitle })
	end
	return text("card_ranks", { lo = loTitle, hi = Registry.rankTitle(track, hi) })
end

function View.cardAction(card: any, elapsed: number): Action
	local status = card.status
	if status == "active" then
		return {
			kind = "resume",
			label = text("card_resume", {
				i = math.floor(num(card.stageIndex, 1)),
				n = math.floor(num(card.stageCount, 1)),
			}),
			enabled = true,
		}
	elseif status == "available" then
		return { kind = "start", label = text("card_start"), enabled = true }
	elseif status == "cooldown" then
		local left = math.max(0, num(card.cooldownLeft, 0) - math.max(0, elapsed))
		if left <= 0 then
			return { kind = "start", label = text("card_start"), enabled = true }
		end
		return { kind = "wait", label = text("card_cooldown", { time = Registry.timeText(left) }), enabled = false }
	end
	local vars = if type(card.vars) == "table" then card.vars else {}
	local title = if type(vars.title) == "string" then vars.title else ""
	if card.reason == "rank_low" then
		return { kind = "locked", label = text("card_locked_rank", { title = title }), enabled = false }
	elseif card.reason == "rank_high" then
		return { kind = "locked", label = text("card_locked_past", { title = title }), enabled = false }
	end
	return { kind = "locked", label = text("card_unavailable"), enabled = false }
end

function View.cardMeta(card: any): { string }
	local out: { string } = {
		text("card_stages", { n = math.floor(num(card.stageCount, 0)) }),
		View.rankText(card),
	}
	if num(card.best, 0) > 0 then
		table.insert(out, text("card_best", { q = math.floor(num(card.best, 0)) }))
	end
	if num(card.closed, 0) > 0 then
		table.insert(out, text("card_closed", { n = math.floor(num(card.closed, 0)) }))
	end
	local xp = num(card.estimateXp, 0)
	local pay = num(card.estimatePay, 0)
	if xp > 0 and pay > 0 then
		table.insert(out, text("card_estimate", { xp = View.commas(xp), pay = View.money(pay) }))
	elseif xp > 0 then
		table.insert(out, text("card_estimate_xp", { xp = View.commas(xp) }))
	end
	return out
end

function View.band(q: number): string
	if q >= 90 then
		return "great"
	elseif q >= 75 then
		return "good"
	elseif q >= 60 then
		return "ok"
	elseif q >= 40 then
		return "weak"
	end
	return "bad"
end

function View.qualityColor(q: number): string
	return if q >= 75 then "good" elseif q >= 50 then "warn" else "bad"
end

function View.progress(payload: any, answers: any): (number, number)
	local total = Kinds.answerTotal(payload)
	local done = math.min(total, Kinds.answered(payload, answers or {}))
	return done, total
end

local function isDense(t: { [any]: any }): boolean
	local n = #t
	local count = 0
	for k in t do
		count += 1
		if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then
			return false
		end
	end
	return count == n
end

local function wire(v: any, depth: number): any
	if type(v) ~= "table" or depth > 8 then
		return v
	end
	local hasNumber = false
	for k in v do
		if type(k) == "number" then
			hasNumber = true
			break
		end
	end
	local stringify = hasNumber and not isDense(v)
	local out: { [any]: any } = {}
	for k, x in v do
		local key: any = if stringify then tostring(k) else k
		out[key] = wire(x, depth + 1)
	end
	return out
end

function View.wire(answers: any): any
	return wire(answers, 1)
end

return View
