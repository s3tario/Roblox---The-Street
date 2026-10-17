--!strict
-- The career record's state machine (owned by `careerPath`; spec §6, design v3 §6 and §10). PURE: no services,
-- no clocks, no Instances. Callers pass `now` (unix time) and `active` (ActivityService active seconds).
--
-- Statuses: "student" -> (hired) "active" <-> "coaching" | "probation" -> "fired" -> (reentry | reinstated |
-- fresh start) -> "active" | "student". The weekly review is a flag (career.reviewDue), not a status, so the
-- employment status other features read (contracts §5: active | probation | fired) is never hidden by it.
--
-- Week clock (active time, persists across sessions):
--   CareerState.tickWeek(career, dt) -> TickEvents   advances weekActive; Friday afternoon sets reviewDue;
--                                                    after 10 overdue active minutes asks for the phone review
--   CareerState.weekday(weekActive) -> 1..5          CareerState.windowRemaining(career) -> seconds | -1
--   CareerState.startWeek(career, active)            the next week after a review (counters reset)
-- Reviews:
--   CareerState.decide(input) -> Decision            outcome, new status, critical streak, firing
--   CareerState.recordReview(career, entry)          ring of 26 + lastBand
-- Employment:
--   CareerState.hire(career, opts) / CareerState.setRole(career, role, opts)
--   CareerState.wipeout(career, opts) -> Wipeout     the firing losses (25% band XP, book to 10%)
--   CareerState.restore(career, opts)                re-entry (one rank lower) / reinstatement (same rank)
--   CareerState.freshStart(career)                   back to campus recruiting
--   CareerState.resetForRebirth(career, template, active)   keeps plaques, signatures, prestige, counters
-- Queries:
--   CareerState.isEmployed(career) / CareerState.isEmployee(career, companyId, partners?)
--   CareerState.mergerPartners(events, companyId, now?) -> { [companyId] = true }
--   CareerState.massFiringSelect(entries) -> { fire, save, spare }
-- Rings: CareerState.pushRing(list, entry, max); CareerState.history(career, kind, now, extra?)

local Tracks = require(script.Parent.Parent.Config.Tracks)
local Leveling = require(script.Parent.Leveling)

local CareerState = {}

CareerState.WORKDAY = 8 * 60 -- active seconds per workday (Time.WORKDAY)
CareerState.WINDOW = 40 * 60 -- active seconds per work week (Time.REVIEW_WINDOW)
CareerState.DUE_AT = 36 * 60 -- Friday afternoon: the weekly review is ready
CareerState.REMOTE_AFTER = 10 * 60 -- overdue active seconds before the boss calls
CareerState.REVIEWS_KEPT = 26
CareerState.HISTORY_KEPT = 60
CareerState.PLAQUES_KEPT = 100
CareerState.OFFERS_MAX = 8
CareerState.WIPEOUT_XP = 0.25
CareerState.WIPEOUT_BOOK = 0.1
CareerState.WIPEOUT_BOOK_MIN = 5000

CareerState.STATUSES = { student = true, active = true, coaching = true, probation = true, fired = true } :: {
	[string]: boolean,
}

local BAND_ORDER: { [string]: number } = { critical = 1, probation = 2, under = 3, on_track = 4, star = 5 }

export type Career = { [string]: any }

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function CareerState.pushRing(list: { any }, entry: any, max: number)
	table.insert(list, entry)
	while #list > max do
		table.remove(list, 1)
	end
end

function CareerState.history(career: Career, kind: string, now: number, extra: { [string]: any }?)
	if type(career.history) ~= "table" then
		career.history = {}
	end
	local entry: { [string]: any } = {
		kind = kind,
		at = math.floor(now),
		week = num(career.week, 0),
		roleId = career.roleId,
		companyId = career.companyId,
		title = career.title,
		level = num(career.level, 1),
	}
	if extra then
		for k, v in extra do
			entry[k] = v
		end
	end
	CareerState.pushRing(career.history, entry, CareerState.HISTORY_KEPT)
end

---------------------------------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------------------------------
function CareerState.isEmployed(career: any): boolean
	if type(career) ~= "table" then
		return false
	end
	if type(career.companyId) ~= "string" or career.companyId == "" then
		return false
	end
	if career.status == "fired" or career.status == "student" then
		return false
	end
	return num(career.rank, 0) >= 1
end

-- Companies paired with `companyId` by an active merger_mania event (design v3 §10). Accepts the global
-- `events` table ({corporate = {id, startsAt, endsAt, data}, ...}) with data.companies, data.pair or data.a/b.
function CareerState.mergerPartners(events: any, companyId: string, now: number?): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(events) ~= "table" or type(companyId) ~= "string" then
		return out
	end
	local function consider(entry: any)
		if type(entry) ~= "table" or entry.id ~= "merger_mania" then
			return
		end
		if now ~= nil then
			if type(entry.startsAt) == "number" and now < entry.startsAt then
				return
			end
			if type(entry.endsAt) == "number" and now >= entry.endsAt then
				return
			end
		end
		local d = entry.data
		if type(d) ~= "table" then
			return
		end
		local lists: { any } = { d.companies, d.pair }
		if type(d.a) == "string" and type(d.b) == "string" then
			table.insert(lists, { d.a, d.b })
		end
		for _, list in lists do
			if type(list) == "table" and table.find(list, companyId) then
				for _, other in list do
					if type(other) == "string" and other ~= companyId then
						out[other] = true
					end
				end
			end
		end
	end
	for key, value in events do
		if type(value) == "table" and key ~= "upcoming" then
			if value.id ~= nil then
				consider(value)
			else
				for _, e in ipairs(value) do
					consider(e)
				end
			end
		end
	end
	return out
end

function CareerState.isEmployee(career: any, companyId: any, partners: { [string]: boolean }?): boolean
	if type(companyId) ~= "string" or companyId == "" or not CareerState.isEmployed(career) then
		return false
	end
	if career.companyId == companyId then
		return true
	end
	return partners ~= nil and partners[companyId] == true
end

---------------------------------------------------------------------------------------------------
-- Week clock
---------------------------------------------------------------------------------------------------
function CareerState.weekday(weekActive: number): number
	return math.clamp(math.floor(math.max(0, num(weekActive, 0)) / CareerState.WORKDAY) + 1, 1, 5)
end

function CareerState.windowRemaining(career: Career): number
	if not CareerState.isEmployed(career) or career.reviewDue == true then
		return -1
	end
	return math.max(0, CareerState.DUE_AT - num(career.weekActive, 0))
end

export type TickEvents = { dayChanged: number?, reviewDue: boolean, remoteReview: boolean }

function CareerState.tickWeek(career: Career, dt: number): TickEvents
	local events: TickEvents = { dayChanged = nil, reviewDue = false, remoteReview = false }
	local step = math.clamp(num(dt, 0), 0, 30)
	if step <= 0 or not CareerState.isEmployed(career) then
		return events
	end
	if career.reviewDue == true then
		career.overdueActive = num(career.overdueActive, 0) + step
		career.weekActive = math.min(CareerState.WINDOW, num(career.weekActive, 0) + step)
		if career.overdueActive >= CareerState.REMOTE_AFTER and career.remoteCalled ~= true then
			career.remoteCalled = true
			events.remoteReview = true
		end
		return events
	end
	local before = CareerState.weekday(num(career.weekActive, 0))
	career.weekActive = math.min(CareerState.WINDOW, num(career.weekActive, 0) + step)
	local after = CareerState.weekday(career.weekActive)
	career.weekday = after
	if after ~= before then
		events.dayChanged = after
	end
	if career.weekActive >= CareerState.DUE_AT then
		career.reviewDue = true
		career.overdueActive = 0
		career.remoteCalled = false
		events.reviewDue = true
	end
	return events
end

local function freshWeek(): { [string]: number }
	return { count = 0, qualitySum = 0, core = 0, clientCount = 0, clientSum = 0, best = 0 }
end

function CareerState.startWeek(career: Career, active: number)
	career.week = math.max(1, num(career.week, 0) + 1)
	career.weekday = 1
	career.weekActive = 0
	career.weekStartActive = math.max(0, num(active, 0))
	career.reviewDue = false
	career.overdueActive = 0
	career.remoteCalled = false
	career.weekWork = freshWeek()
	career.weekRep = 0
	career.weekViolations = 0
end

---------------------------------------------------------------------------------------------------
-- Review decisions
---------------------------------------------------------------------------------------------------
export type DecideInput = {
	status: string,
	criticalStreak: number?,
	band: string,
	promotable: boolean, -- every promotion requirement passed (score included)
	hasLifeline: boolean?,
	forceFire: string?, -- "risk" | "mass": fired regardless of the band
}
export type Decision = {
	outcome: string, -- "promoted" | "keep_going" | "warning" | "fired"
	status: string,
	criticalStreak: number,
	fired: boolean,
	fireReason: string?, -- "critical" | "probation" | "risk" | "mass"
	lifelineUsed: boolean,
}

-- Bands (spec §6): Star / On track keep you active (and may promote), Underperforming means coaching, Probation
-- cuts risk limits until an On track week, Critical is a final warning. Firing: two Critical reviews in a row, a
-- Critical review while on probation (its "high stakes" review), a major risk violation or a mass firing. The
-- Alumni Lifeline turns one firing into probation.
function CareerState.decide(input: DecideInput): Decision
	local streak = math.max(0, math.floor(num(input.criticalStreak, 0)))
	local status = input.status
	local band = input.band
	local d: Decision = {
		outcome = "keep_going",
		status = "active",
		criticalStreak = 0,
		fired = false,
		fireReason = nil,
		lifelineUsed = false,
	}
	local fireReason: string? = input.forceFire
	if not fireReason then
		if band == "critical" then
			streak += 1
			if streak >= 2 then
				fireReason = "critical"
			elseif status == "probation" then
				fireReason = "probation"
			end
		else
			streak = 0
		end
	end
	if fireReason then
		if input.hasLifeline then
			d.outcome = "warning"
			d.status = "probation"
			d.criticalStreak = 0
			d.lifelineUsed = true
			d.fireReason = fireReason
			return d
		end
		d.outcome = "fired"
		d.status = "fired"
		d.criticalStreak = 0
		d.fired = true
		d.fireReason = fireReason
		return d
	end
	d.criticalStreak = streak
	local order = BAND_ORDER[band] or 1
	if order >= BAND_ORDER.on_track then
		d.status = "active"
		d.outcome = if input.promotable then "promoted" else "keep_going"
	elseif band == "under" then
		-- probation lasts until an On track week
		d.status = if status == "probation" then "probation" else "coaching"
		d.outcome = "warning"
	else
		d.status = "probation"
		d.outcome = "warning"
	end
	return d
end

function CareerState.recordReview(career: Career, entry: { [string]: any })
	if type(career.reviews) ~= "table" then
		career.reviews = {}
	end
	CareerState.pushRing(career.reviews, entry, CareerState.REVIEWS_KEPT)
	career.lastBand = entry.band
end

-- Mass firing (design v3 §10): employees whose last review was below On track are let go (the Alumni Lifeline
-- saves its owner); new hires without a review and everyone On track or better are spared.
export type FiringEntry = { id: any, lastBand: string?, hasLifeline: boolean? }
function CareerState.massFiringSelect(entries: { FiringEntry }): { fire: { any }, save: { any }, spare: { any } }
	local out = { fire = {}, save = {}, spare = {} }
	for _, e in entries do
		local band = e.lastBand
		local below = type(band) == "string" and band ~= "" and (BAND_ORDER[band] or 0) < BAND_ORDER.on_track
		if not below then
			table.insert(out.spare, e.id)
		elseif e.hasLifeline then
			table.insert(out.save, e.id)
		else
			table.insert(out.fire, e.id)
		end
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Employment changes
---------------------------------------------------------------------------------------------------
export type RoleOpts = { companyId: string?, status: string?, now: number?, active: number? }

-- Sets the role fields for (track, rank). Returns the previous roleId.
function CareerState.setRole(career: Career, trackId: string, rank: number, opts: RoleOpts?): string
	local o: RoleOpts = opts or {}
	local old = if type(career.roleId) == "string" then career.roleId else "student"
	local role = Tracks.rankDef(trackId, rank)
	assert(role ~= nil, ("CareerState.setRole: unknown rank %s/%s"):format(tostring(trackId), tostring(rank)))
	career.track = trackId
	career.rank = rank
	career.roleId = role.roleId
	career.title = role.title
	if o.companyId then
		career.companyId = o.companyId
	end
	if o.status then
		career.status = o.status
	end
	career.coreAtRank = 0
	return old
end

export type HireOpts = { companyId: string, trackId: string, rank: number, now: number, active: number }

-- Hired (first job, a job after a fresh start, or a lateral move). Starts a new work week.
function CareerState.hire(career: Career, opts: HireOpts): string
	local old = CareerState.setRole(career, opts.trackId, opts.rank, { companyId = opts.companyId, status = "active" })
	career.criticalStreak = 0
	career.lastBand = ""
	career.fired = {}
	career.week = math.max(0, math.floor(num(career.week, 0)))
	CareerState.startWeek(career, opts.active)
	local role = Tracks.rankDef(opts.trackId, opts.rank)
	if role and num(career.level, 1) < role.minLevel then
		career.level = role.minLevel
		career.xp = 0
	end
	return old
end

export type WipeoutOpts = { reason: string, now: number, bookSize: number? }
export type Wipeout = {
	lostXp: number,
	newBook: number,
	lostBook: number,
	companyId: string,
	roleId: string,
	rank: number,
	title: string,
	track: string,
}

-- The firing (spec §6 "Wipeout"): the job, the active deal pipeline (caller), 25% of the XP earned inside the
-- current role band and the trading book reset to 10% (minimum $5,000). Never lost: cash, cosmetics, housing,
-- achievements, plaques and history. Mutates the career and returns what was lost.
function CareerState.wipeout(career: Career, opts: WipeoutOpts): Wipeout
	local trackId = if type(career.track) == "string" then career.track else ""
	local rank = math.floor(num(career.rank, 1))
	local role = Tracks.rankDef(trackId, rank)
	local bandFloor = if role then role.minLevel else 1
	local level = math.floor(num(career.level, 1))
	local xp = num(career.xp, 0)
	local loss = Leveling.wipeoutLoss(level, xp, bandFloor, CareerState.WIPEOUT_XP)
	local newLevel, newXp, removed = Leveling.removeXp(level, xp, loss, bandFloor)
	career.level = newLevel
	career.xp = newXp
	local book = math.max(0, num(opts.bookSize, 0))
	local newBook = math.max(CareerState.WIPEOUT_BOOK_MIN, math.floor(book * CareerState.WIPEOUT_BOOK))
	local w: Wipeout = {
		lostXp = removed,
		newBook = newBook,
		lostBook = math.max(0, book - newBook),
		companyId = if type(career.companyId) == "string" then career.companyId else "",
		roleId = if type(career.roleId) == "string" then career.roleId else "",
		rank = rank,
		title = if type(career.title) == "string" then career.title else "",
		track = trackId,
	}
	career.fired = {
		at = math.floor(opts.now),
		reason = opts.reason,
		companyId = w.companyId,
		roleId = w.roleId,
		rank = w.rank,
		title = w.title,
		track = w.track,
		lostXp = w.lostXp,
		lostBook = w.lostBook,
		newBook = w.newBook,
		week = num(career.week, 0),
		attempts = 0,
	}
	career.status = "fired"
	career.roleId = Tracks.UNEMPLOYED_ROLE
	career.title = Tracks.text("role_unemployed")
	career.companyId = ""
	career.reviewDue = false
	career.overdueActive = 0
	career.remoteCalled = false
	career.criticalStreak = 0
	career.coreAtRank = 0
	career.wipeouts = num(career.wipeouts, 0) + 1
	return w
end

export type RestoreOpts = { kind: string, now: number, active: number, companyId: string? }

-- Back to work after a firing. kind "reentry": one rank lower, status active. kind "reinstated": the former
-- rank, on probation. The level is capped to the new role's band (excess XP banks as a full bar).
function CareerState.restore(career: Career, opts: RestoreOpts): (boolean, string?)
	local f = career.fired
	if career.status ~= "fired" or type(f) ~= "table" or type(f.track) ~= "string" then
		return false, "not_fired"
	end
	local trackId = f.track
	local formerRank = math.max(1, math.floor(num(f.rank, 1)))
	local rank = if opts.kind == "reentry" then math.max(1, formerRank - 1) else formerRank
	local role = Tracks.rankDef(trackId, rank)
	if not role then
		return false, "no_role"
	end
	local companyId = opts.companyId or f.companyId
	if type(companyId) ~= "string" or companyId == "" then
		return false, "no_company"
	end
	CareerState.hire(
		career,
		{ companyId = companyId, trackId = trackId, rank = rank, now = opts.now, active = opts.active }
	)
	career.status = if opts.kind == "reinstated" then "probation" else "active"
	local level = math.floor(num(career.level, 1))
	if level > role.maxLevel then
		career.level = role.maxLevel
		career.xp = Leveling.xpForLevel(role.maxLevel)
	end
	career.comebacks = num(career.comebacks, 0) + 1
	career.fired = {}
	return true, nil
end

function CareerState.freshStart(career: Career)
	career.track = ""
	career.companyId = ""
	career.rank = 0
	career.roleId = Tracks.STUDENT.roleId
	career.title = Tracks.STUDENT.title
	career.status = "student"
	career.reviewDue = false
	career.overdueActive = 0
	career.remoteCalled = false
	career.weekActive = 0
	career.weekday = 1
	career.criticalStreak = 0
	career.coreAtRank = 0
	career.lastBand = ""
	career.fired = {}
	career.offers = {}
end

-- Rebirth (contracts §4): a new life. Keeps plaques, signatures, prestige, deal mastery, the wipeout/comeback
-- counters, the history, the best fastest run and reinstatement credits; everything else returns to the template.
function CareerState.resetForRebirth(career: Career, template: Career, active: number)
	local keep: { [string]: any } = {
		plaques = career.plaques,
		plaqueCount = career.plaqueCount,
		signatures = career.signatures,
		prestige = career.prestige,
		dealMastery = career.dealMastery,
		wipeouts = career.wipeouts,
		comebacks = career.comebacks,
		history = career.history,
		fastestRunSec = career.fastestRunSec,
		reinstateCredits = career.reinstateCredits,
		nextPlaqueId = career.nextPlaqueId,
		nextReviewId = career.nextReviewId,
		nextOfferId = career.nextOfferId,
	}
	for k in table.clone(career) do
		career[k] = nil
	end
	for k, v in template do
		career[k] = if type(v) == "table" then table.clone(v) else v
	end
	for k, v in keep do
		if v ~= nil then
			career[k] = v
		end
	end
	career.weekWork = freshWeek()
	career.promotion = { ready = false, missing = {}, next = "", checklist = {} }
	career.lifeStartActive = math.max(0, num(active, 0))
	career.topTitleAt = 0
end

-- The level and XP a career may hold at its rank (used after loading old saves and after rank changes).
function CareerState.capFor(career: Career): number
	local rank = math.floor(num(career.rank, 0))
	if career.status == "fired" and type(career.fired) == "table" then
		rank = math.floor(num(career.fired.rank, rank))
	end
	return Leveling.capFor(if type(career.track) == "string" and career.track ~= "" then career.track else nil, rank)
end

return CareerState
