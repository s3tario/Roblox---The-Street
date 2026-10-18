--!strict
-- Big-deal registry (owned by `projects`; contracts §9). PURE: no services, no clocks, no Instances. Everything
-- ProjectService and the Project screen need to know about project modules without running one: the contract check,
-- availability by track and rank, a run's status, reward maths, JSON-safety, the shared stage Machine and the
-- strings. Names starting with "_" are never project modules (ProjectService skips them).
--
--   Registry.EXTERNAL[id]                  modules another service runs (reentry: careerPath's Career Services)
--   Registry.TUNING                        reward and pacing numbers (below)
--   Registry.check(mod) -> (ok, err?)      contract shape (contracts §9)
--   Registry.listed(mod) -> boolean        a regular big deal ProjectService runs (valid and not external)
--   Registry.who(career) -> Who            { employed, status, track?, rank, level, student, fired }
--   Registry.rankRange(mod) -> (lo, hi)    from mod.ranks (nil = every employed rank)
--   Registry.relevant(mod, who) -> boolean belongs in this player's list (their track, or a track-less deal)
--   Registry.available(mod, who) -> (ok, reason?, vars?)   not_employed | wrong_track | rank_low | rank_high
--   Registry.record(raw) -> Record         normalizes data.projects[id] (repairs the table in place)
--   Registry.status(mod, record, who, now) -> Status
--       { status = "active" | "available" | "cooldown" | "locked", reason?, vars?, cooldownLeft?, stageIndex?,
--         stageCount? }
--   Registry.qualityFactor(q) -> 0..1      participation share up to the floor, then linear to 1 at 100
--   Registry.difficulty(rank, level, minLevel?, maxLevel?) -> 0..1
--   Registry.rewards(mod, quality, rank, opts?) -> Rewards   { xp, pay, rep, repeatRun, repeatMult, pulled }
--       opts = { runs?, closed?, xpScale?, payMult?, eventMult?, xpMult? }
--   Registry.estimate(mod, rank, opts?) -> { xp, pay }      at a typical quality, closed
--   Registry.cooldownOf(mod) -> seconds    Registry.statsOf(mod) -> { statId }
--   Registry.sorted(mods) -> { mod }       by lowest rank, then title
--   Registry.stagesOf(mod) -> { {id, title, kind, brief?} }
--   Registry.plain(value) -> (ok, err?)    JSON-safe for a DataStore: dense arrays or string-keyed maps, finite
--                                          numbers, valid UTF-8, no metatables, bounded size
--   Registry.rankTitle(track?, rank) -> string
--   Registry.stageStats(mod, stageId) -> { statId }   what a stage trains (stage.stats, else the deal's stats)
--   Registry.marketMood(info) -> 0.8..1.2  info = { event?, dayChange?, ipoFrenzy? } (the ctx.marketMood deals read)
--   Registry.statLabel(statId) -> string   Registry.timeText(seconds) -> "4m 05s"
--   Registry.text(key, vars?) -> string    Registry.strings (Strings.luau)
--   Registry.Machine                       the shared stage machine (Machine.luau)
--   Registry.Runs                          the run lifecycle ProjectService applies to records (Runs.luau)
--   Registry.DealKit                       helpers deal modules share (DealKit.luau); Plain.luau backs plain()

local Machine = require(script.Machine)
local Strings = require(script.Strings)
local Runs = require(script.Runs)
local Plain = require(script.Plain)
local DealKit = require(script.DealKit)

-- careerPath's ladder titles and XP pacing, when they load (guarded: this registry works without them).
local Tracks: any = nil
local Leveling: any = nil
do
	local config = script.Parent.Parent.Parent:FindFirstChild("Config")
	local tracksModule = if config then config:FindFirstChild("Tracks") else nil
	if tracksModule and tracksModule:IsA("ModuleScript") then
		local ok, mod = pcall(require, tracksModule)
		if ok and type(mod) == "table" then
			Tracks = mod
		end
	end
	local levelingModule = script.Parent.Parent:FindFirstChild("Leveling")
	if levelingModule and levelingModule:IsA("ModuleScript") then
		local ok, mod = pcall(require, levelingModule)
		if ok and type(mod) == "table" then
			Leveling = mod
		end
	end
end

export type Completion = Runs.Completion
export type Card = Runs.Card

export type Who = {
	employed: boolean,
	status: string,
	track: string?,
	rank: number,
	level: number,
	student: boolean,
	fired: boolean,
}
export type HistoryEntry = { at: number, quality: number, closed: boolean, name: string }
export type Record = {
	state: any,
	companyId: string?,
	lastRewards: { [string]: any }?,
	runs: number,
	closed: number,
	best: number,
	last: number,
	lastAt: number,
	startedAt: number,
	stageAt: number,
	attempts: number,
	abandoned: number,
	cooldownUntil: number,
	history: { HistoryEntry },
}
export type Status = {
	status: string,
	reason: string?,
	vars: { [string]: any }?,
	cooldownLeft: number?,
	stageIndex: number?,
	stageCount: number?,
}
export type Rewards = {
	xp: number,
	pay: number,
	rep: number,
	repeatRun: boolean,
	repeatMult: number,
	pulled: boolean,
}

local Registry = {}

Registry.Machine = Machine
Registry.Runs = Runs
Registry.DealKit = DealKit
Registry.strings = Strings

-- Run by another service, never listed or touched by ProjectService.
Registry.EXTERNAL = { reentry = true } :: { [string]: boolean }

-- Pacing (spec §5/§11): a deal takes ~10-15 active minutes, so at a typical quality (75) it pays about what that
-- time at a desk would (Leveling.XP_RATE x minutes; ~70% of cash/hour comes from work), plus a little for the
-- plaque. XP and pay scale with rank like work tasks (Leveling.rankXpScale; the work feature's pay scale).
Registry.TUNING = {
	baseXp = 420, -- XP of a first run at quality 100, rank 1 (before scales and boosts)
	basePay = 3000, -- cash of a first run at quality 100, rank 1 (before the company and event multipliers)
	typicalQuality = 75,
	qualityFloor = 20, -- below this quality only the participation share is paid
	participation = 0.1,
	repeatMult = 0.5, -- every run after the first closed one
	pulledMult = 0.6, -- a deal that fell through still pays for the work, at this share
	repPerQuality = 0.05, -- reputation per quality point on a closed deal (100 -> 5)
	cooldown = 600, -- seconds before the same deal can start again after it finishes
	abandonCooldown = 60, -- seconds after abandoning
	maxActive = 2, -- deals in progress at once
	historyKept = 5,
	maxXp = 60000,
	maxPay = 2000000,
	seasonShare = 0.25, -- Season XP = this share of the deal's XP
	payScale = { [0] = 0.08, 1, 1.9, 3.1, 4.0, 5.6, 6.6, 7.6, 8.8 } :: { [number]: number },
	xpScale = { [0] = 0.6, 1, 1.35, 1.7, 2.05, 2.35, 2.65, 2.95, 3.25 } :: { [number]: number },
}

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end
Registry.num = num

local function str(x: any): string?
	if type(x) == "string" and x ~= "" then
		return x
	end
	return nil
end

function Registry.text(key: string, vars: { [string]: any }?): string
	local template = (Strings :: any)[key]
	if type(template) ~= "string" then
		return key
	end
	if not vars then
		return template
	end
	local v = vars
	return (
		string.gsub(template, "{([%w_]+)}", function(name: string): string
			local value = v[name]
			if value == nil then
				return "{" .. name .. "}"
			end
			return tostring(value)
		end)
	)
end

---------------------------------------------------------------------------------------------------
-- Module contract
---------------------------------------------------------------------------------------------------
function Registry.check(mod: any): (boolean, string?)
	if type(mod) ~= "table" then
		return false, "not a table"
	end
	if type(mod.id) ~= "string" or string.find(mod.id, "^[%w_]+$") == nil then
		return false, "id"
	end
	if type(mod.title) ~= "string" or mod.title == "" then
		return false, "title"
	end
	for _, fn in { "new", "view", "act", "score" } do
		if type(mod[fn]) ~= "function" then
			return false, "missing " .. fn
		end
	end
	if mod.track ~= nil and type(mod.track) ~= "string" then
		return false, "track"
	end
	if mod.ranks ~= nil then
		if type(mod.ranks) ~= "table" or #mod.ranks == 0 then
			return false, "ranks"
		end
		for _, r in mod.ranks do
			if type(r) ~= "number" or r < 1 or r ~= math.floor(r) then
				return false, "ranks"
			end
		end
	end
	if type(mod.stages) ~= "table" or #mod.stages == 0 then
		return false, "stages"
	end
	for i, s in mod.stages do
		if type(s) ~= "table" or type(s.id) ~= "string" or type(s.title) ~= "string" then
			return false, "stage " .. i
		end
	end
	return true, nil
end

function Registry.listed(mod: any): boolean
	if type(mod) ~= "table" or type(mod.id) ~= "string" then
		return false
	end
	if Registry.EXTERNAL[mod.id] or string.sub(mod.id, 1, 1) == "_" then
		return false
	end
	return (Registry.check(mod))
end

function Registry.stagesOf(mod: any): { { [string]: any } }
	local out: { { [string]: any } } = {}
	if type(mod) ~= "table" or type(mod.stages) ~= "table" then
		return out
	end
	for _, s in mod.stages do
		if type(s) == "table" and type(s.id) == "string" then
			table.insert(out, {
				id = s.id,
				title = if type(s.title) == "string" then s.title else s.id,
				kind = if type(s.kind) == "string" then s.kind else "",
				brief = if type(s.brief) == "string" then s.brief else nil,
				stats = Registry.stageStats(mod, s.id),
			})
		end
	end
	return out
end

function Registry.statsOf(mod: any): { string }
	local out: { string } = {}
	if type(mod) == "table" and type(mod.stats) == "table" then
		for _, s in mod.stats do
			if type(s) == "string" then
				table.insert(out, s)
			end
		end
	end
	if #out == 0 then
		out = { "knowledge", "skill" }
	end
	return out
end

local STAT_IDS = {
	knowledge = true,
	skill = true,
	speed = true,
	charisma = true,
	network = true,
	discipline = true,
	risk = true,
	luck = true,
} :: { [string]: boolean }
Registry.STAT_IDS = STAT_IDS

function Registry.stageStats(mod: any, stageId: string): { string }
	if type(mod) == "table" and type(mod.stages) == "table" then
		for _, s in mod.stages do
			if type(s) == "table" and s.id == stageId and type(s.stats) == "table" then
				local out: { string } = {}
				for _, id in s.stats do
					if type(id) == "string" and STAT_IDS[id] then
						table.insert(out, id)
					end
				end
				if #out > 0 then
					return out
				end
			end
		end
	end
	return Registry.statsOf(mod)
end

function Registry.statLabel(statId: string): string
	local label = (Strings :: any)["stat_" .. tostring(statId)]
	return if type(label) == "string" then label else tostring(statId)
end

-- "45s", "4m 05s", "1h 02m" (cooldowns on the deal cards).
function Registry.timeText(seconds: number): string
	local s = math.max(0, math.ceil(num(seconds, 0)))
	if s < 60 then
		return tostring(s) .. "s"
	elseif s < 3600 then
		return string.format("%dm %02ds", s // 60, s % 60)
	end
	return string.format("%dh %02dm", s // 3600, (s % 3600) // 60)
end

-- How the market treats new deals right now (ctx.marketMood): a boom or an IPO Frenzy warms investors up, a crash
-- cools them down, and the benchmark's move today nudges it either way.
Registry.MOOD_EVENTS = {
	boom = 1.15,
	meme_rally = 1.1,
	earnings_frenzy = 1.05,
	crazy_day = 0.97,
	rate_shock = 0.9,
	flash_crash = 0.88,
	crash = 0.82,
} :: { [string]: number }

function Registry.marketMood(info: any): number
	local i: { [string]: any } = if type(info) == "table" then info else {}
	local mood = if type(i.event) == "string" then Registry.MOOD_EVENTS[i.event] or 1 else 1
	mood += math.clamp(num(i.dayChange, 0) * 3, -0.06, 0.06)
	if i.ipoFrenzy == true then
		mood += 0.08
	end
	return math.clamp(math.floor(mood * 100 + 0.5) / 100, 0.8, 1.2)
end

function Registry.cooldownOf(mod: any): number
	if type(mod) == "table" then
		return math.max(0, num(mod.cooldown, Registry.TUNING.cooldown))
	end
	return Registry.TUNING.cooldown
end

---------------------------------------------------------------------------------------------------
-- Who, availability, status
---------------------------------------------------------------------------------------------------
function Registry.who(career: any): Who
	local c: { [string]: any } = if type(career) == "table" then career else {}
	local status = str(c.status) or "student"
	local rank = math.max(0, math.floor(num(c.rank, 0)))
	local employed = str(c.companyId) ~= nil
		and status ~= "fired"
		and status ~= "student"
		and rank >= 1
		and c.roleId ~= "unemployed"
	return {
		employed = employed,
		status = status,
		track = str(c.track),
		rank = rank,
		level = math.max(1, math.floor(num(c.level, 1))),
		student = status == "student",
		fired = status == "fired",
	}
end

function Registry.rankRange(mod: any): (number, number)
	local ranks = if type(mod) == "table" then mod.ranks else nil
	if type(ranks) ~= "table" or #ranks == 0 then
		return 1, math.huge
	end
	local lo, hi = math.huge, -math.huge
	for _, r in ranks do
		if type(r) == "number" then
			lo = math.min(lo, r)
			hi = math.max(hi, r)
		end
	end
	if lo == math.huge then
		return 1, math.huge
	end
	return lo, hi
end

function Registry.rankTitle(track: string?, rank: number): string
	if Tracks and type(Tracks.rankDef) == "function" and track then
		local ok, def = pcall(Tracks.rankDef, track, rank)
		if ok and type(def) == "table" and type(def.title) == "string" then
			return def.title
		end
	end
	return "Rank " .. tostring(rank)
end

function Registry.relevant(mod: any, who: Who): boolean
	if not Registry.listed(mod) then
		return false
	end
	return mod.track == nil or mod.track == who.track
end

function Registry.available(mod: any, who: Who): (boolean, string?, { [string]: any }?)
	if not who.employed then
		return false, "not_employed", nil
	end
	if mod.track ~= nil and mod.track ~= who.track then
		return false, "wrong_track", nil
	end
	local ranks = mod.ranks
	local lo, hi = Registry.rankRange(mod)
	if type(ranks) == "table" and table.find(ranks, who.rank) == nil then
		if who.rank < lo then
			return false, "rank_low", { title = Registry.rankTitle(who.track, lo), rank = lo }
		end
		if who.rank > hi then
			return false, "rank_high", { title = Registry.rankTitle(who.track, hi), rank = hi }
		end
		-- a gap inside the list (e.g. ranks = {1, 3}): the next listed rank above the player's
		local nextRank = hi
		for _, r in ranks do
			if r > who.rank and r < nextRank then
				nextRank = r
			end
		end
		return false, "rank_low", { title = Registry.rankTitle(who.track, nextRank), rank = nextRank }
	end
	return true, nil, nil
end

function Registry.record(raw: any): Record
	local r: { [string]: any } = if type(raw) == "table" then raw else {}
	for _, key in { "runs", "closed", "best", "last", "lastAt", "startedAt", "stageAt", "attempts", "abandoned" } do
		r[key] = math.max(0, num(r[key], 0))
	end
	r.cooldownUntil = num(r.cooldownUntil, 0)
	if type(r.history) ~= "table" then
		r.history = {}
	end
	if r.companyId ~= nil and type(r.companyId) ~= "string" then
		r.companyId = nil
	end
	if r.lastRewards ~= nil and type(r.lastRewards) ~= "table" then
		r.lastRewards = nil
	end
	if r.state ~= nil and type(r.state) ~= "table" then
		r.state = nil
	end
	return r :: any
end

function Registry.status(mod: any, record: Record, who: Who, now: number): Status
	local state = record.state
	if type(state) == "table" and state.done ~= true then
		return {
			status = "active",
			stageIndex = math.floor(num(state.stageIndex, 1)),
			stageCount = math.floor(num(state.stageCount, if type(mod.stages) == "table" then #mod.stages else 1)),
		}
	end
	local ok, reason, vars = Registry.available(mod, who)
	if not ok then
		return { status = "locked", reason = reason, vars = vars }
	end
	if record.cooldownUntil > now then
		return { status = "cooldown", cooldownLeft = math.ceil(record.cooldownUntil - now) }
	end
	return { status = "available" }
end

---------------------------------------------------------------------------------------------------
-- Rewards
---------------------------------------------------------------------------------------------------
function Registry.qualityFactor(quality: any): number
	local t = Registry.TUNING
	local q = math.clamp(num(quality, 0), 0, 100)
	if q <= t.qualityFloor then
		return t.participation * q / t.qualityFloor
	end
	return t.participation + (1 - t.participation) * (q - t.qualityFloor) / (100 - t.qualityFloor)
end

local function scaleFrom(tbl: { [number]: number }, rank: number): number
	local r = math.max(0, math.floor(num(rank, 0)))
	local v = tbl[r]
	if v then
		return v
	end
	local top = 0
	for k in tbl do
		if k > top then
			top = k
		end
	end
	return tbl[top] or 1
end

function Registry.xpScale(rank: number): number
	if Leveling and type(Leveling.rankXpScale) == "function" then
		local ok, v = pcall(Leveling.rankXpScale, math.max(0, math.floor(num(rank, 0))))
		if ok and type(v) == "number" and v == v and v > 0 then
			return v
		end
	end
	return scaleFrom(Registry.TUNING.xpScale, rank)
end

function Registry.payScale(rank: number): number
	return scaleFrom(Registry.TUNING.payScale, rank)
end

-- Students ramp up over the campus levels; bankers from 0.25 at a fresh Analyst to ~0.95 for a seasoned MD
-- (the same curve as work tasks, so a deal feels like the desk work around it).
function Registry.difficulty(rank: number, level: number, minLevel: number?, maxLevel: number?): number
	local r = math.max(1, math.floor(num(rank, 1)))
	local lv = math.max(1, num(level, 1))
	local lo = num(minLevel, lv)
	local hi = num(maxLevel, lv)
	local progress = if hi > lo then math.clamp((lv - lo) / (hi - lo), 0, 1) else 0
	return math.clamp(0.25 + 0.15 * (r - 1) + 0.1 * progress, 0, 1)
end

function Registry.rewards(mod: any, quality: number, rank: number, opts: { [string]: any }?): Rewards
	local t = Registry.TUNING
	local o: { [string]: any } = opts or {}
	local m: { [string]: any } = if type(mod) == "table" then mod else {}
	local qf = Registry.qualityFactor(quality)
	local repeatRun = num(o.runs, 0) > 0
	local repeatMult = if repeatRun then math.clamp(num(m.repeatMult, t.repeatMult), 0, 1) else 1
	local pulled = o.closed == false
	local closedMult = if pulled then t.pulledMult else 1
	local xpScale = num(o.xpScale, Registry.xpScale(rank))
	local payMult = math.clamp(num(o.payMult, 1), 0, 5)
	local eventMult = math.clamp(num(o.eventMult, 1), 0, 5)
	local xpMult = math.clamp(num(o.xpMult, 1), 0, 5)
	local xp = num(m.baseXp, t.baseXp) * qf * xpScale * repeatMult * closedMult * xpMult
	local pay = num(m.basePay, t.basePay) * qf * Registry.payScale(rank) * repeatMult * closedMult * payMult * eventMult
	local rep = if pulled then 0 else math.floor(math.clamp(num(quality, 0), 0, 100) * t.repPerQuality * 10 + 0.5) / 10
	return {
		xp = math.clamp(math.floor(xp + 0.5), 0, t.maxXp),
		pay = math.clamp(math.floor(pay + 0.5), 0, t.maxPay),
		rep = rep,
		repeatRun = repeatRun,
		repeatMult = repeatMult,
		pulled = pulled,
	}
end

function Registry.estimate(mod: any, rank: number, opts: { [string]: any }?): { xp: number, pay: number }
	local o: { [string]: any } = if opts then table.clone(opts) else {}
	o.closed = true
	local r = Registry.rewards(mod, Registry.TUNING.typicalQuality, rank, o)
	return { xp = r.xp, pay = r.pay }
end

---------------------------------------------------------------------------------------------------
-- Lists
---------------------------------------------------------------------------------------------------
function Registry.sorted(mods: { any }): { any }
	local out = table.clone(mods)
	table.sort(out, function(a, b)
		local la = Registry.rankRange(a)
		local lb = Registry.rankRange(b)
		if la ~= lb then
			return la < lb
		end
		return tostring(a.title) < tostring(b.title)
	end)
	return out
end

function Registry.plain(value: any): (boolean, string?)
	return Plain.check(value)
end

Runs._bind(Registry)

return Registry
