--!strict
-- QuestLine (owned by `tutorial`): the onboarding chain as a PURE state machine over data.campus (no services, no
-- clocks, no Instances; callers pass `now` and a Facts snapshot). TutorialService gathers the facts from real
-- signals, calls reconcile, and turns the result into objectives, waypoints, banners and task offers.
--
--   QuestLine.normalize(campus) -> campus           repairs missing/odd fields of an old or hand-edited save
--   QuestLine.current(campus) -> StepDef?            nil before the chain starts and after it finishes
--   QuestLine.finished(campus) -> boolean            QuestLine.started(campus) -> boolean
--   QuestLine.start(campus, now) -> StepDef?         begins the chain at its first unfinished step
--   QuestLine.check(cond, facts, campus) -> boolean  the Config/Quests condition language
--   QuestLine.reconcile(campus, facts, now) -> Result
--       completes every step whose facts already hold (in order), bypasses campus steps once hired, skips the
--       campus fluff after a rebirth, and steps back when a step's holdWhile stops holding.
--       Result = { completed = { { id, how } }, entered = stepId?, finished = boolean, back = stepId? }
--       how: "auto" | "bypass" | "veteran"
--   QuestLine.complete(campus, stepId, now, how?) -> boolean   finishes the step if it is current (true), else
--                                                    marks it so the chain finishes it on arrival (false)
--   QuestLine.paused(campus, facts) -> boolean       a street step while fired: wait for the comeback
--   QuestLine.tick(campus, dt, facts) -> number      adds active seconds to the stuck timer (not while paused)
--   QuestLine.canSkip(campus, facts?) -> (ok, errKey?)   "skip_none" | "skip_core" | "skip_not_yet"
--   QuestLine.skip(campus, now) -> StepDef?          finishes the current step as skipped
--   QuestLine.vars(campus, facts) -> vars            QuestLine.objective(campus, facts) -> text?
--   QuestLine.progress(campus) -> { Row }            Row = { id, title, phase, state = done|skipped|current|todo }
--   QuestLine.resetRecruiting(campus)                a fresh start: back to the Recruiting Board, nothing else lost
--   QuestLine.facts(raw) -> Facts                    coerces a loose table into Facts (defaults for every field)
-- Sub-modules: QuestLine.Recruit (the Recruiting Board), .Network (card exchanges), .Side (side quests),
--   .Awards (achievement rules).

local Quests = require(script.Parent.Parent.Config.Quests)
local Recruit = require(script.Recruit)
local Network = require(script.Network)
local Side = require(script.Side)
local Awards = require(script.Awards)

export type StepDef = Quests.StepDef
export type Facts = {
	built: boolean,
	employed: boolean,
	fired: boolean,
	hired: boolean, -- employed or between jobs: the campus part of the story is over
	student: boolean,
	hasOffer: boolean,
	inOffice: boolean,
	inOwnOffice: boolean,
	onOwnFloor: boolean,
	onboarded: boolean,
	club: boolean,
	zone: string?,
	tasksDone: { [string]: number },
	networked: number,
	jobTasks: number,
	trades: number,
	reviews: number,
	rebirths: number,
	company: string?,
	boss: string?,
	department: string?,
	apps: number,
}
export type Completed = { id: string, how: string }
export type Result = { completed: { Completed }, entered: string?, finished: boolean, back: string? }
export type Row = { id: string, title: string, phase: string, state: string }

local QuestLine = {}

QuestLine.Recruit = Recruit
QuestLine.Network = Network
QuestLine.Side = Side
QuestLine.Awards = Awards
QuestLine.steps = Quests.steps
QuestLine.DONE = Quests.DONE

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

local function tbl(x: any): { [any]: any }
	return if type(x) == "table" then x else {}
end

function QuestLine.normalize(campus: { [string]: any }): { [string]: any }
	for _, key in { "done", "skipped", "marks", "quests", "pending", "exchanges", "flags", "talked" } do
		if type(campus[key]) ~= "table" then
			campus[key] = {}
		end
	end
	if type(campus.applications) ~= "table" then
		campus.applications = {}
	end
	if type(campus.step) ~= "string" then
		campus.step = ""
	end
	if campus.step ~= "" and campus.step ~= Quests.DONE and Quests.stepById[campus.step] == nil then
		-- a step that no longer exists (renamed config): resume at the first unfinished one
		campus.step = ""
	end
	campus.stuck = math.max(0, num(campus.stuck, 0))
	campus.startedAt = num(campus.startedAt, 0)
	campus.jobTasks = math.max(0, math.floor(num(campus.jobTasks, 0)))
	campus.trades = math.max(0, math.floor(num(campus.trades, 0)))
	campus.offer = campus.offer == true
	campus.club = campus.club == true
	campus.bannerShown = campus.bannerShown == true
	local net = campus.network
	if type(net) ~= "table" then
		net = { count = 0, ids = {} }
		campus.network = net
	end
	if type(net.ids) ~= "table" then
		net.ids = {}
	end
	local n = 0
	for _ in net.ids do
		n += 1
	end
	net.count = n
	local boost = campus.xpBoost
	if type(boost) ~= "table" then
		campus.xpBoost = { mult = 1, left = 0, source = "" }
	else
		boost.mult = math.clamp(num(boost.mult, 1), 1, 2)
		boost.left = math.max(0, math.floor(num(boost.left, 0)))
		boost.source = if type(boost.source) == "string" then boost.source else ""
	end
	return campus
end

function QuestLine.facts(raw: any): Facts
	local r = tbl(raw)
	local employed = r.employed == true
	local fired = r.fired == true
	return {
		built = r.built == true,
		employed = employed,
		fired = fired,
		hired = employed or fired,
		student = not (employed or fired),
		hasOffer = r.hasOffer == true,
		inOffice = r.inOffice == true,
		inOwnOffice = r.inOwnOffice == true,
		onOwnFloor = r.onOwnFloor == true,
		onboarded = r.onboarded == true,
		club = r.club == true,
		zone = if type(r.zone) == "string" then r.zone else nil,
		tasksDone = if type(r.tasksDone) == "table" then r.tasksDone else {},
		networked = num(r.networked, 0),
		jobTasks = num(r.jobTasks, 0),
		trades = num(r.trades, 0),
		reviews = num(r.reviews, 0),
		rebirths = num(r.rebirths, 0),
		company = if type(r.company) == "string" and r.company ~= "" then r.company else nil,
		boss = if type(r.boss) == "string" and r.boss ~= "" then r.boss else nil,
		department = if type(r.department) == "string" and r.department ~= "" then r.department else nil,
		apps = num(r.apps, 0),
	}
end

---------------------------------------------------------------------------------------------------
-- Conditions
---------------------------------------------------------------------------------------------------
local BOOL_FACTS = {
	built = true,
	employed = true,
	fired = true,
	hired = true,
	student = true,
	hasOffer = true,
	inOffice = true,
	inOwnOffice = true,
	onOwnFloor = true,
	onboarded = true,
} :: { [string]: boolean }
local MIN_FACTS = { networked = true, jobTasks = true, trades = true, reviews = true } :: { [string]: boolean }

function QuestLine.check(cond: any, facts: Facts, campus: { [string]: any }): boolean
	if type(cond) ~= "table" then
		return false
	end
	for key, want in cond do
		if key == "any" then
			local hit = false
			for _, c in tbl(want) do
				if QuestLine.check(c, facts, campus) then
					hit = true
					break
				end
			end
			if not hit then
				return false
			end
		elseif key == "all" then
			for _, c in tbl(want) do
				if not QuestLine.check(c, facts, campus) then
					return false
				end
			end
		elseif BOOL_FACTS[key] then
			if ((facts :: any)[key] == true) ~= (want == true) then
				return false
			end
		elseif key == "club" then
			if (facts.club or campus.club == true) ~= (want == true) then
				return false
			end
		elseif MIN_FACTS[key] then
			if num((facts :: any)[key], 0) < num(want, math.huge) then
				return false
			end
		elseif key == "zone" then
			if facts.zone ~= want then
				return false
			end
		elseif key == "zoneIn" then
			if type(want) ~= "table" or table.find(want, facts.zone) == nil then
				return false
			end
		elseif key == "mark" then
			if tbl(campus.marks)[want] ~= true then
				return false
			end
		elseif key == "taskDone" then
			if num(facts.tasksDone[want], 0) < 1 then
				return false
			end
		else
			return false
		end
	end
	return true
end

---------------------------------------------------------------------------------------------------
-- Moving through the chain
---------------------------------------------------------------------------------------------------
function QuestLine.started(campus: { [string]: any }): boolean
	return type(campus.step) == "string" and campus.step ~= ""
end

function QuestLine.finished(campus: { [string]: any }): boolean
	return campus.step == Quests.DONE
end

function QuestLine.current(campus: { [string]: any }): StepDef?
	if type(campus.step) ~= "string" then
		return nil
	end
	return Quests.stepById[campus.step]
end

local function firstOpen(campus: { [string]: any }, from: number): string
	local done = tbl(campus.done)
	for i = from, #Quests.steps do
		local s = Quests.steps[i]
		if done[s.id] == nil then
			return s.id
		end
	end
	return Quests.DONE
end

local function enter(campus: { [string]: any }, stepId: string)
	campus.step = stepId
	campus.stuck = 0
end

function QuestLine.start(campus: { [string]: any }, now: number): StepDef?
	QuestLine.normalize(campus)
	if QuestLine.started(campus) then
		return QuestLine.current(campus)
	end
	if num(campus.startedAt, 0) <= 0 then
		campus.startedAt = now
	end
	enter(campus, firstOpen(campus, 1))
	return QuestLine.current(campus)
end

local function finishCurrent(campus: { [string]: any }, now: number, how: string): string
	local cur = QuestLine.current(campus)
	if not cur then
		return campus.step
	end
	campus.done[cur.id] = now
	if how == "skip" then
		campus.skipped[cur.id] = true
	end
	campus.marks[cur.id] = nil
	local nextId = firstOpen(campus, (Quests.stepIndex[cur.id] or 0) + 1)
	enter(campus, nextId)
	return nextId
end

function QuestLine.complete(campus: { [string]: any }, stepId: string, now: number, how: string?): boolean
	QuestLine.normalize(campus)
	if Quests.stepById[stepId] == nil then
		return false
	end
	if campus.step == stepId then
		finishCurrent(campus, now, how or "auto")
		return true
	end
	if campus.done[stepId] == nil then
		campus.marks[stepId] = true
	end
	return false
end

-- Back to an earlier step: it and everything after it are open again (completion times and marks cleared).
local function stepBack(campus: { [string]: any }, toId: string)
	local from = Quests.stepIndex[toId]
	if not from then
		return
	end
	for i = from, #Quests.steps do
		local id = Quests.steps[i].id
		campus.done[id] = nil
		campus.skipped[id] = nil
		campus.marks[id] = nil
	end
	enter(campus, toId)
end

function QuestLine.reconcile(campus: { [string]: any }, facts: Facts, now: number): Result
	QuestLine.normalize(campus)
	local result: Result = { completed = {}, entered = nil, finished = false, back = nil }
	if not QuestLine.started(campus) then
		QuestLine.start(campus, now)
		result.entered = campus.step
	end
	local before = campus.step
	for _ = 1, #Quests.steps + 2 do
		local cur = QuestLine.current(campus)
		if not cur then
			break
		end
		if cur.holdWhile and cur.back and not QuestLine.check(cur.holdWhile, facts, campus) then
			if campus.step ~= cur.back then
				stepBack(campus, cur.back)
				result.back = cur.back
				continue
			end
		end
		local how: string? = nil
		if cur.phase == "campus" and facts.hired then
			how = "bypass"
		elseif cur.veteran and facts.rebirths > 0 then
			how = "veteran"
		elseif QuestLine.check(cur.doneWhen, facts, campus) then
			how = "auto"
		end
		if not how then
			break
		end
		table.insert(result.completed, { id = cur.id, how = how })
		finishCurrent(campus, now, how)
	end
	if campus.step ~= before then
		result.entered = campus.step
	end
	result.finished = QuestLine.finished(campus)
	return result
end

function QuestLine.paused(campus: { [string]: any }, facts: Facts): boolean
	local cur = QuestLine.current(campus)
	return cur ~= nil and cur.phase == "street" and facts.fired
end

function QuestLine.tick(campus: { [string]: any }, dt: number, facts: Facts): number
	if QuestLine.current(campus) and not QuestLine.paused(campus, facts) then
		campus.stuck = math.max(0, num(campus.stuck, 0)) + math.clamp(num(dt, 0), 0, 60)
	end
	return num(campus.stuck, 0)
end

function QuestLine.canSkip(campus: { [string]: any }, facts: Facts?): (boolean, string?)
	local cur = QuestLine.current(campus)
	if not cur then
		return false, "skip_none"
	end
	if cur.core then
		return false, "skip_core"
	end
	if facts and QuestLine.paused(campus, facts) then
		return false, "skip_none"
	end
	if num(campus.stuck, 0) < Quests.SKIP_AFTER then
		return false, "skip_not_yet"
	end
	return true, nil
end

function QuestLine.skip(campus: { [string]: any }, now: number): StepDef?
	local cur = QuestLine.current(campus)
	if not cur or cur.core then
		return nil
	end
	finishCurrent(campus, now, "skip")
	return cur
end

function QuestLine.resetRecruiting(campus: { [string]: any })
	QuestLine.normalize(campus)
	campus.applications = {}
	campus.pending = {}
	campus.offer = false
	stepBack(campus, "recruiting")
end

---------------------------------------------------------------------------------------------------
-- Text and views
---------------------------------------------------------------------------------------------------
function QuestLine.vars(campus: { [string]: any }, facts: Facts): { [string]: any }
	local cfg = Quests.recruiting
	return {
		company = facts.company or Quests.text("your_firm"),
		boss = facts.boss or Quests.text("your_boss"),
		department = facts.department or Quests.text("department_ib"),
		n = math.min(facts.networked, Quests.NETWORK_GOAL),
		goal = Quests.NETWORK_GOAL,
		apps = Recruit.slotsUsed(tbl(campus.applications)),
		max = cfg.maxApplications,
	}
end

function QuestLine.objective(campus: { [string]: any }, facts: Facts): string?
	local cur = QuestLine.current(campus)
	if not cur or QuestLine.paused(campus, facts) then
		return nil
	end
	local vars = QuestLine.vars(campus, facts)
	if cur.id == "recruiting" then
		local key, extra = Recruit.objective(tbl(campus.applications))
		for k, v in extra do
			vars[k] = v
		end
		return Quests.text(key, vars)
	end
	return Quests.fill(cur.objective, vars)
end

function QuestLine.progress(campus: { [string]: any }): { Row }
	local rows: { Row } = {}
	local done = tbl(campus.done)
	local skipped = tbl(campus.skipped)
	for _, s in Quests.steps do
		local state = if skipped[s.id]
			then "skipped"
			elseif done[s.id] ~= nil then "done"
			elseif campus.step == s.id then "current"
			else "todo"
		table.insert(rows, { id = s.id, title = s.title, phase = s.phase, state = state })
	end
	return rows
end

return QuestLine
