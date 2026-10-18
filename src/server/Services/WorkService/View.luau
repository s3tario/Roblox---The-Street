--!strict
-- WorkService/View (server, runtime only): the board as the client sees it (Work.Board).
--   View.board(player) -> (true, BoardView) | (false, errKey)
--   BoardView = { role, student, unemployed, track?, rank, day, dayLabel, nextIn, now, atDesk, deskPct,
--                 tasks = { Card }, done, total, active = ActiveView?, totals }
--   Card = { id, title, desc, kind, category, core, done, offered, carried, label?, expiresAt?, quality?,
--            cooldownUntil?, timeLimit, xp, pay, stats, clientFacing, best? }

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Time = require(Shared.Util.Time)
local Config = require(Shared.Config.Tasks)
local SharedTasks = Shared:WaitForChild("Logic"):WaitForChild("Tasks"):WaitForChild("_shared")
local Board = require(SharedTasks:WaitForChild("Board"))
local Rewards = require(SharedTasks:WaitForChild("Rewards"))
local Deps = require(script.Parent.Deps)
local Flow = require(script.Parent.Flow)
local Core = require(script.Parent.Core)
local Runner = require(script.Parent.Runner)

local View = {}

local num = Deps.num
local modules = Core.modules
local stateOf = Core.stateOf
local workOf = Core.workOf
local ensureBoard = Core.ensureBoard
local deskNear = Core.deskNear
local activeSeconds = Core.activeSeconds
local activeView = Runner.activeView

local function dayLabel(who: Board.Who, career: { [string]: any }, board: Board.BoardState): string
	if who.student then
		return Config.text("board_day_student", { n = board.day })
	end
	if who.unemployed then
		return ""
	end
	local week = math.floor(num(career.week, 0))
	if week <= 0 then
		return ""
	end
	local weekday = math.clamp(math.floor(num(career.weekActive, 0) / (8 * 60)) + 1, 1, 5)
	return Config.text("board_week", { week = week, day = Config.WEEKDAYS[weekday] })
end

local function offerLabel(entry: Board.Entry): string?
	local d = entry.data
	if type(d) == "table" then
		if type(d.label) == "string" and d.label ~= "" then
			return d.label
		elseif type(d.companyName) == "string" and d.companyName ~= "" then
			return d.companyName
		end
	end
	return nil
end

local function boardView(player: Player): (boolean, any)
	local now = Time.now()
	local board, data = ensureBoard(player, now)
	if not board or not data then
		return false, "not_loaded"
	end
	local w = workOf(data)
	local who, career = Flow.who(data)
	local atDesk = deskNear(player, who)
	local mults = Flow.multipliers(player, who, atDesk)
	local effects = Flow.effects(player, data)
	local _, _, nextIn = Board.dayKey(who, career, activeSeconds(player, data))
	local cards: { any } = {}
	local done = 0
	for _, e in board.tasks do
		local mod = modules[e.id]
		if mod then
			local est = Flow.estimate(mod, who, mults)
			local cd = num(w.cooldowns[e.id], 0)
			if e.done then
				done += 1
			end
			table.insert(cards, {
				id = mod.id,
				title = mod.title,
				desc = mod.desc,
				kind = if type(mod.kind) == "string" then mod.kind else "multi",
				category = mod.category,
				core = e.core,
				done = e.done,
				offered = e.offered == true,
				carried = e.carried == true,
				label = offerLabel(e),
				expiresAt = e.expiresAt,
				quality = e.quality,
				cooldownUntil = if not e.done and e.offered ~= true and cd > now then cd else nil,
				timeLimit = Rewards.timeLimit(mod.timeLimit, effects.timerMult, 1),
				xp = est.xp,
				pay = est.pay,
				stats = Flow.statNames(mod),
				clientFacing = mod.clientFacing == true,
				best = w.best[mod.id],
			})
		end
	end
	local st = stateOf(player)
	local active = st.active
	if active and Rewards.expired(now - active.startedAt, active.limit) then
		st.active = nil
		active = nil
	end
	return true,
		{
			role = board.role,
			student = who.student,
			unemployed = who.unemployed,
			track = who.track,
			rank = who.rank,
			day = board.day,
			dayLabel = dayLabel(who, career, board),
			nextIn = nextIn,
			now = now,
			atDesk = atDesk,
			deskPct = math.floor((Config.rewards.deskBonus - 1) * 100 + 0.5),
			tasks = cards,
			done = done,
			total = #cards,
			active = if active then activeView(active) else nil,
			totals = table.clone(w.totals),
		}
end

View.board = boardView

return View
