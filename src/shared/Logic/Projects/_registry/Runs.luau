--!strict
-- Big-deal run lifecycle (owned by `projects`; contracts §9). PURE: no services, no clocks, no Instances. Everything
-- ProjectService does to a player's data.projects[id] record lives here, so the rules are unit-tested and the
-- service stays thin (validate, call Runs, persist, reward, replicate).
--
--   Runs.isActive(record) -> boolean          a run in progress (state present and not done)
--   Runs.activeIds(projects, mods) -> { id }  in-progress runs of modules ProjectService runs (sorted)
--   Runs.stale(mod, record) -> boolean        an in-progress run the module can no longer continue (new version,
--                                             different stage list)
--   Runs.start(mod, record, who, now, opts) -> (ok, err?, vars?, resumed?)
--       opts = { seed, ctx, activeCount, maxActive?, companyId? }
--       err: unknown | not_employed | wrong_track | rank_low | rank_high | cooldown | too_many | broken
--   Runs.act(mod, record, answers, ctx, now, expectStage?) -> (ok, err?, result?, completion?)
--       err: unknown | not_active | done | stale | broken (the run is reset: the client restarts it)
--   Runs.complete(mod, record, now) -> Completion   (called by act when the last stage is graded)
--       Completion = { quality, closed, dealName, closedBefore, runsBefore, repeatRun, firstClose, outcome? }
--   Runs.abandon(record, now, cooldown?) -> boolean   drops a run in progress; a short cooldown follows
--   Runs.card(mod, record, who, now, opts?) -> Card     one entry of Project.List (no answers, no state)
--   Runs.list(mods, projects, who, now, opts?) -> { Card }   the deals relevant to this player, sorted
--       opts = { payMult?, xpMult?, eventMults? = { [modId] = number } }   (estimates on the cards)
--   Runs.publicView(mod, record, ctx, extra?) -> View?   the safe view the client may see (never the answer key)

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)

type Who = { [string]: any }
type Record = { [string]: any }

export type Completion = {
	quality: number,
	closed: boolean,
	dealName: string,
	closedBefore: number,
	runsBefore: number,
	repeatRun: boolean,
	firstClose: boolean,
	outcome: { [string]: any }?,
}

export type Card = {
	id: string,
	title: string,
	desc: string,
	glyph: string,
	track: string?,
	signature: boolean,
	stageCount: number,
	stages: { { [string]: any } },
	rankLo: number,
	rankHi: number?,
	status: string,
	reason: string?,
	vars: { [string]: any }?,
	cooldownLeft: number?,
	stageIndex: number?,
	dealName: string?,
	best: number,
	last: number,
	runs: number,
	closed: number,
	repeatRun: boolean,
	repeatPct: number,
	estimateXp: number,
	estimatePay: number,
	lastName: string?,
	lastClosed: boolean?,
}

local Runs = {}

-- Set by _registry/init (avoids a require cycle): the registry's helpers.
local R: any = nil
function Runs._bind(registry: any)
	R = registry
end

local MAX_NAME = 80

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

local function name(s: any, fallback: string): string
	if type(s) == "string" and s ~= "" then
		return string.sub(s, 1, MAX_NAME)
	end
	return fallback
end

function Runs.isActive(record: any): boolean
	if type(record) ~= "table" then
		return false
	end
	local state = record.state
	return type(state) == "table" and state.done ~= true
end

function Runs.activeIds(projects: any, mods: { [string]: any }): { string }
	local out: { string } = {}
	if type(projects) ~= "table" then
		return out
	end
	for id, record in projects do
		if type(id) == "string" and mods[id] ~= nil and Runs.isActive(record) then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

function Runs.stale(mod: any, record: any): boolean
	if not Runs.isActive(record) or type(mod) ~= "table" then
		return false
	end
	local state = record.state
	if state.id ~= nil and state.id ~= mod.id then
		return true
	end
	local version = if type(mod.version) == "number" then mod.version else 1
	if num(state.version, 1) ~= version then
		return true
	end
	local count = if type(mod.stages) == "table" then #mod.stages else 0
	if state.stageCount ~= nil and num(state.stageCount, count) ~= count then
		return true
	end
	return false
end

function Runs.start(
	mod: any,
	record: Record,
	who: Who,
	now: number,
	opts: { [string]: any }
): (boolean, string?, { [string]: any }?, boolean?)
	if not R.listed(mod) then
		return false, "unknown", nil, nil
	end
	if Runs.isActive(record) then
		return true, nil, nil, true
	end
	local ok, reason, vars = R.available(mod, who)
	if not ok then
		return false, reason, vars, nil
	end
	local cooldownUntil = num(record.cooldownUntil, 0)
	if cooldownUntil > now then
		local left = math.ceil(cooldownUntil - now)
		return false, "cooldown", { seconds = left, time = R.timeText(left) }, nil
	end
	local maxActive = math.max(1, math.floor(num(opts.maxActive, R.TUNING.maxActive)))
	if num(opts.activeCount, 0) >= maxActive then
		return false, "too_many", { n = maxActive }, nil
	end
	local seed = math.floor(num(opts.seed, 1)) % 2147483646 + 1
	local okNew, state = pcall(mod.new, Rng.new(seed), opts.ctx)
	if not okNew or type(state) ~= "table" then
		return false, "broken", { detail = tostring(state) }, nil
	end
	local plain, why = R.plain(state)
	if not plain then
		return false, "broken", { detail = why }, nil
	end
	record.state = state
	record.attempts = num(record.attempts, 0) + 1
	record.startedAt = now
	record.stageAt = now
	record.companyId = if type(opts.companyId) == "string" then opts.companyId else nil
	record.lastRewards = nil
	return true, nil, nil, false
end

function Runs.complete(mod: any, record: Record, now: number): Completion
	local state = record.state
	local quality = 0
	local outcome: { [string]: any }? = nil
	if type(state) == "table" then
		quality = num(state.quality, 0)
		local okScore, score = pcall(mod.score, state)
		if okScore and type(score) == "table" then
			quality = num(score.quality, quality)
		end
		if type(state.outcome) == "table" then
			outcome = state.outcome
		end
	end
	quality = math.clamp(math.floor(quality + 0.5), 0, 100)
	local closed = outcome ~= nil and outcome.closed == true
	local dealName = name(if type(state) == "table" then state.dealName else nil, tostring(mod.title))
	local closedBefore = math.floor(num(record.closed, 0))
	local runsBefore = math.floor(num(record.runs, 0))
	record.runs = runsBefore + 1
	if closed then
		record.closed = closedBefore + 1
	end
	record.best = math.max(num(record.best, 0), quality)
	record.last = quality
	record.lastAt = now
	record.cooldownUntil = now + R.cooldownOf(mod)
	if type(record.history) ~= "table" then
		record.history = {}
	end
	table.insert(record.history, { at = now, quality = quality, closed = closed, name = dealName })
	while #record.history > R.TUNING.historyKept do
		table.remove(record.history, 1)
	end
	return {
		quality = quality,
		closed = closed,
		dealName = dealName,
		closedBefore = closedBefore,
		runsBefore = runsBefore,
		repeatRun = closedBefore > 0,
		firstClose = closed and closedBefore == 0,
		outcome = outcome,
	}
end

function Runs.act(
	mod: any,
	record: Record,
	answers: any,
	ctx: any,
	now: number,
	expectStage: number?
): (boolean, string?, { [string]: any }?, Completion?)
	if not R.listed(mod) then
		return false, "unknown", nil, nil
	end
	local state = record.state
	if type(state) ~= "table" then
		return false, "not_active", nil, nil
	end
	if state.done == true then
		return false, "done", nil, nil
	end
	if expectStage ~= nil and math.floor(num(state.stageIndex, 1)) ~= expectStage then
		return false, "stale", nil, nil
	end
	local okAct, newState, result = pcall(mod.act, state, answers, ctx)
	if not okAct or type(newState) ~= "table" or type(result) ~= "table" then
		record.state = nil
		return false, "broken", { detail = tostring(newState) }, nil
	end
	if result.ok ~= true then
		if result.err == "done" then
			return false, "done", nil, nil
		end
		record.state = nil
		return false, "broken", { detail = tostring(result.err) }, nil
	end
	local plain = R.plain(newState)
	if not plain then
		record.state = nil
		return false, "broken", { detail = "state" }, nil
	end
	record.state = newState
	record.stageAt = now
	local completion: Completion? = nil
	if newState.done == true then
		completion = Runs.complete(mod, record, now)
	end
	return true, nil, result, completion
end

function Runs.abandon(record: Record, now: number, cooldown: number?): boolean
	if not Runs.isActive(record) then
		return false
	end
	record.state = nil
	record.abandoned = num(record.abandoned, 0) + 1
	local wait = math.max(0, num(cooldown, R.TUNING.abandonCooldown))
	record.cooldownUntil = math.max(num(record.cooldownUntil, 0), now + wait)
	return true
end

---------------------------------------------------------------------------------------------------
-- Cards (Project.List)
---------------------------------------------------------------------------------------------------
function Runs.card(mod: any, record: Record, who: Who, now: number, opts: { [string]: any }?): Card
	local o: { [string]: any } = opts or {}
	local st = R.status(mod, record, who, now)
	local lo, hi = R.rankRange(mod)
	local closed = math.floor(num(record.closed, 0))
	local repeatRun = closed > 0
	local repeatMult = if repeatRun then math.clamp(num(mod.repeatMult, R.TUNING.repeatMult), 0, 1) else 1
	local eventMults = if type(o.eventMults) == "table" then o.eventMults else {}
	local estimate = R.estimate(mod, math.max(lo, who.rank), {
		runs = closed,
		payMult = o.payMult,
		xpMult = o.xpMult,
		eventMult = eventMults[mod.id],
	})
	local state = record.state
	local history = if type(record.history) == "table" then record.history else {}
	local lastEntry = history[#history]
	local card: Card = {
		id = mod.id,
		title = mod.title,
		desc = if type(mod.desc) == "string" then mod.desc else "",
		glyph = if type(mod.glyph) == "string" then mod.glyph else "💼",
		track = if type(mod.track) == "string" then mod.track else nil,
		signature = mod.signature == true,
		stageCount = if type(mod.stages) == "table" then #mod.stages else 0,
		stages = R.stagesOf(mod),
		rankLo = lo,
		rankHi = if hi == math.huge then nil else hi,
		status = st.status,
		reason = st.reason,
		vars = st.vars,
		cooldownLeft = st.cooldownLeft,
		stageIndex = st.stageIndex,
		dealName = if st.status == "active"
				and type(state) == "table"
				and type(state.dealName) == "string"
			then state.dealName
			else nil,
		best = math.floor(num(record.best, 0)),
		last = math.floor(num(record.last, 0)),
		runs = math.floor(num(record.runs, 0)),
		closed = closed,
		repeatRun = repeatRun,
		repeatPct = math.floor(repeatMult * 100 + 0.5),
		estimateXp = estimate.xp,
		estimatePay = estimate.pay,
		lastName = if type(lastEntry) == "table" and type(lastEntry.name) == "string" then lastEntry.name else nil,
		lastClosed = if type(lastEntry) == "table" then lastEntry.closed == true else nil,
	}
	return card
end

local STATUS_ORDER = { active = 1, available = 2, cooldown = 3, locked = 4 } :: { [string]: number }

function Runs.list(mods: { any }, projects: any, who: Who, now: number, opts: { [string]: any }?): { Card }
	local out: { Card } = {}
	local saved = if type(projects) == "table" then projects else {}
	for _, mod in mods do
		if R.relevant(mod, who) then
			local record = R.record(saved[mod.id])
			table.insert(out, Runs.card(mod, record, who, now, opts))
		end
	end
	table.sort(out, function(a, b)
		local sa, sb = STATUS_ORDER[a.status] or 9, STATUS_ORDER[b.status] or 9
		if sa ~= sb then
			return sa < sb
		end
		if a.rankLo ~= b.rankLo then
			return a.rankLo < b.rankLo
		end
		return a.title < b.title
	end)
	return out
end

---------------------------------------------------------------------------------------------------
-- The client's view of a run
---------------------------------------------------------------------------------------------------
-- Builds the module view and copies only display fields out of it (the module view never holds the answer key;
-- copying field by field keeps it that way even if a later module adds something by mistake).
function Runs.publicView(mod: any, record: Record, ctx: any, extra: { [string]: any }?): { [string]: any }?
	local state = record.state
	if type(state) ~= "table" then
		return nil
	end
	local okView, v = pcall(mod.view, state, ctx)
	if not okView or type(v) ~= "table" then
		return nil
	end
	local out: { [string]: any } = {
		id = mod.id,
		title = if type(v.title) == "string" then v.title else mod.title,
		glyph = if type(mod.glyph) == "string" then mod.glyph else "💼",
		signature = mod.signature == true,
		dealName = if type(v.dealName) == "string" then v.dealName else mod.title,
		stage = v.stage,
		stageIndex = v.stageIndex,
		stageCount = v.stageCount,
		stages = v.stages,
		summary = v.summary,
		payload = if v.done ~= true then v.payload else nil,
		done = v.done == true,
		quality = num(v.quality, 0),
		outcome = if v.done == true then v.outcome else nil,
		startedAt = num(record.startedAt, 0),
		stageAt = num(record.stageAt, 0),
		rewards = if v.done == true then record.lastRewards else nil,
	}
	if extra then
		for k, x in extra do
			out[k] = x
		end
	end
	return out
end

return Runs
