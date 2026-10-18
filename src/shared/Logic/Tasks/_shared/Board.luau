--!strict
-- The daily work board (owned by `work`; contracts §8, design v3 §6). PURE: callers pass the time and an Rng.
--
-- Each workday (8 active minutes) the board offers 3-5 fresh tasks valid for the player's track and rank (or the
-- campus tasks while a student), plus any tasks other features offered (interviews, events). Unfinished core
-- tasks carry over to the next day until they're done.
--
--   Board.who(career) -> Who                       { student, unemployed, track?, rank, level }
--   Board.roleKey(who) -> "student" | "unemployed" | "ib:2"
--   Board.dayKey(who, career, activeSec) -> (key, dayIndex, nextIn)   nextIn = active seconds to the next day
--   Board.eligible(mod, who) -> boolean            may this module appear on this player's board?
--   Board.build(prev, mods, who, key, day, rng, cooldowns, now, cfg?) -> BoardState
--   Board.offer(board, taskId, opts, now, cfg?) -> Entry      adds (or refreshes) an offered entry
--   Board.find(board, taskId) -> Entry?            Board.complete(board, taskId, quality, now) -> Entry?
--   Board.prune(board, now) -> boolean             drops expired offered entries (true when something changed)
--   Board.remaining(board) -> number               entries not done yet
--
-- Module fields read here: id, tracks?, ranks?, student?, unemployed?, offerOnly?, core?, weight?

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)
local Config = require(script.Parent.Parent.Parent.Parent.Config.Tasks)

export type Who = { student: boolean, unemployed: boolean, track: string?, rank: number, level: number }
export type Entry = {
	id: string,
	core: boolean,
	done: boolean,
	offered: boolean?,
	carried: boolean?,
	source: string?,
	data: { [string]: any }?,
	expiresAt: number?,
	quality: number?,
	at: number?,
}
export type BoardState = { key: string, role: string, day: number, at: number, tasks: { Entry } }
export type ModuleInfo = {
	id: string,
	tracks: { string }?,
	ranks: { number }?,
	student: boolean?,
	unemployed: boolean?,
	offerOnly: boolean?,
	core: boolean?,
	weight: number?,
}
export type OfferOpts = { source: string?, data: { [string]: any }?, ttl: number?, expiresAt: number? }

local Board = {}

local WORKDAY = 8 * 60

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function Board.who(career: any): Who
	local c = if type(career) == "table" then career else {}
	local status = if type(c.status) == "string" then c.status else "student"
	local roleId = if type(c.roleId) == "string" then c.roleId else "student"
	local rank = math.max(0, math.floor(num(c.rank, 0)))
	local unemployed = status == "fired" or roleId == "unemployed"
	local student = not unemployed and (status == "student" or roleId == "student" or rank <= 0)
	local track = if type(c.track) == "string" and c.track ~= "" and not student then c.track else nil
	return {
		student = student,
		unemployed = unemployed,
		track = track,
		rank = if student then 0 else rank,
		level = math.max(1, math.floor(num(c.level, 1))),
	}
end

function Board.roleKey(who: Who): string
	if who.unemployed then
		return "unemployed"
	elseif who.student then
		return "student"
	end
	return tostring(who.track or "none") .. ":" .. tostring(who.rank)
end

-- Employed players follow the career work week (career.week + weekday from weekActive); students and players
-- between jobs count workdays in lifetime active time.
function Board.dayKey(who: Who, career: any, activeSec: number): (string, number, number)
	local role = Board.roleKey(who)
	local c = if type(career) == "table" then career else {}
	if not who.student and not who.unemployed and num(c.week, 0) > 0 then
		local weekActive = math.max(0, num(c.weekActive, 0))
		local weekday = math.clamp(math.floor(weekActive / WORKDAY) + 1, 1, 5)
		local week = math.floor(num(c.week, 0))
		local nextIn = if weekday < 5 then weekday * WORKDAY - weekActive else -1
		return role .. "|w" .. week .. "d" .. weekday, (week - 1) * 5 + weekday, nextIn
	end
	local active = math.max(0, num(activeSec, 0))
	local day = math.floor(active / WORKDAY) + 1
	return role .. "|a" .. day, day, day * WORKDAY - active
end

function Board.eligible(mod: ModuleInfo, who: Who): boolean
	if mod.offerOnly == true then
		return false
	end
	if who.unemployed then
		return mod.unemployed == true
	end
	if who.student then
		return mod.student == true
	end
	if mod.tracks == nil then
		-- track-less modules are general (student-only modules excluded)
		if mod.student == true or mod.unemployed == true then
			return false
		end
	elseif not who.track or table.find(mod.tracks, who.track) == nil then
		return false
	end
	if mod.ranks ~= nil and table.find(mod.ranks, who.rank) == nil then
		return false
	end
	return true
end

function Board.find(board: BoardState?, taskId: string): Entry?
	if not board then
		return nil
	end
	for _, e in board.tasks do
		if e.id == taskId then
			return e
		end
	end
	return nil
end

function Board.remaining(board: BoardState?): number
	if not board then
		return 0
	end
	local n = 0
	for _, e in board.tasks do
		if not e.done then
			n += 1
		end
	end
	return n
end

local function expired(e: Entry, now: number): boolean
	return e.offered == true and not e.done and e.expiresAt ~= nil and e.expiresAt <= now
end

function Board.prune(board: BoardState, now: number): boolean
	local changed = false
	for i = #board.tasks, 1, -1 do
		if expired(board.tasks[i], now) then
			table.remove(board.tasks, i)
			changed = true
		end
	end
	return changed
end

function Board.build(
	prev: BoardState?,
	mods: { ModuleInfo },
	who: Who,
	key: string,
	day: number,
	rng: Rng.Rng,
	cooldowns: { [string]: number }?,
	now: number,
	cfg: { [string]: any }?
): BoardState
	local c = cfg or Config.board
	local byId: { [string]: ModuleInfo } = {}
	for _, m in mods do
		byId[m.id] = m
	end
	local tasks: { Entry } = {}
	local taken: { [string]: boolean } = {}
	local recent: { [string]: boolean } = {}

	-- 1. what stays: offered tasks still valid, unfinished core tasks still valid for this role
	if prev then
		local carried = 0
		for _, e in prev.tasks do
			local m = byId[e.id]
			if e.done then
				recent[e.id] = true
			elseif m and e.offered and not expired(e, now) and not taken[e.id] then
				table.insert(tasks, e)
				taken[e.id] = true
			elseif
				m
				and c.carryCore
				and e.core
				and not e.offered
				and Board.eligible(m, who)
				and carried < num(c.maxCarry, 3)
				and not taken[e.id]
			then
				carried += 1
				table.insert(tasks, {
					id = e.id,
					core = true,
					done = false,
					carried = true,
					at = e.at,
				})
				taken[e.id] = true
			end
		end
	end

	-- 2. fresh draws
	local carriedCount = 0
	local coreCount = 0
	for _, e in tasks do
		if not e.offered then
			carriedCount += 1
			if e.core then
				coreCount += 1
			end
		end
	end
	local target = rng:int(math.floor(num(c.minTasks, 3)), math.floor(num(c.maxTasks, 5)))
	local fresh = math.max(1, target - carriedCount)
	local cd = cooldowns or {}
	local pool: { ModuleInfo } = {}
	local cooling: { ModuleInfo } = {}
	for _, m in mods do
		if not taken[m.id] and Board.eligible(m, who) then
			if num(cd[m.id], 0) > now then
				table.insert(cooling, m)
			else
				table.insert(pool, m)
			end
		end
	end
	-- never leave the board short because of cooldowns: cooling tasks are the fallback
	local function weightOf(m: ModuleInfo): number
		local w = num(m.weight, 1)
		if m.core then
			w *= num(c.coreWeight, 2)
		end
		if recent[m.id] then
			w *= num(c.recentPenalty, 0.35)
		end
		return math.max(w, 0.0001)
	end
	local maxCore = math.floor(num(c.maxCore, 3))
	local minCore = math.floor(num(c.minCore, 1))
	local function draw(list: { ModuleInfo }, wantCore: boolean?): ModuleInfo?
		local entries: { { any } } = {}
		for i, m in list do
			local isCore = m.core == true
			local allowed = if wantCore == true
				then isCore
				elseif coreCount >= maxCore then not isCore
				else true
			if allowed then
				table.insert(entries, { i, weightOf(m) })
			end
		end
		if #entries == 0 then
			return nil
		end
		local index: number = rng:weighted(entries)
		return table.remove(list, index)
	end
	local added = 0
	while added < fresh do
		local needCore = coreCount < minCore
		local m = (needCore and (draw(pool, true) or draw(cooling, true))) or draw(pool) or draw(cooling)
		if not m then
			break
		end
		table.insert(tasks, { id = m.id, core = m.core == true, done = false, at = now })
		taken[m.id] = true
		added += 1
		if m.core then
			coreCount += 1
		end
	end

	return { key = key, role = Board.roleKey(who), day = day, at = now, tasks = tasks }
end

function Board.offer(board: BoardState, taskId: string, opts: OfferOpts?, now: number, cfg: { [string]: any }?): Entry
	local c = cfg or Config.board
	local o: OfferOpts = opts or {}
	local expiresAt = if o.expiresAt then o.expiresAt else now + num(o.ttl, num(c.offerTtl, 2700))
	local existing = Board.find(board, taskId)
	if existing and not existing.done then
		existing.offered = true
		existing.carried = nil
		existing.source = o.source or existing.source
		existing.data = o.data or existing.data
		existing.expiresAt = expiresAt
		return existing
	end
	if existing and existing.done then
		-- a fresh offer of a finished task replaces the finished entry
		local idx = table.find(board.tasks, existing)
		if idx then
			table.remove(board.tasks, idx)
		end
	end
	-- cap offered entries: new offers go to the front, so the oldest sit at the highest indices
	local offered: { number } = {}
	for i, e in board.tasks do
		if e.offered and not e.done then
			table.insert(offered, i)
		end
	end
	local maxOffered = math.max(1, math.floor(num(c.maxOffered, 4)))
	while #offered >= maxOffered do
		table.remove(board.tasks, table.remove(offered) :: number)
	end
	local entry: Entry = {
		id = taskId,
		core = false,
		done = false,
		offered = true,
		source = o.source,
		data = o.data,
		expiresAt = expiresAt,
		at = now,
	}
	table.insert(board.tasks, 1, entry)
	return entry
end

function Board.complete(board: BoardState?, taskId: string, quality: number, now: number): Entry?
	local e = Board.find(board, taskId)
	if e then
		e.done = true
		e.quality = math.floor(quality + 0.5)
		e.at = now
	end
	return e
end

return Board
