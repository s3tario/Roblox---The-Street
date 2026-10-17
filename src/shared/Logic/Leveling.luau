--!strict
-- Levels 1-100 (owned by `careerPath`; spec §5, design v3 §4). PURE: no services, no clocks, no Instances.
--
--   Leveling.xpForLevel(level) -> number           XP needed to go from `level` to `level + 1`
--   Leveling.capFor(trackId?, rank) -> number      the role's max level (XP can't push past it until promoted)
--   Leveling.addXp(level, xp, amount, cap) -> (level, xp, added, levelsGained)
--   Leveling.xpInBand(level, xp, bandFloor) -> number              XP earned inside the current role band
--   Leveling.removeXp(level, xp, amount, floorLevel) -> (level, xp, removed)
--   Leveling.wipeoutLoss(level, xp, bandFloor, fraction?) -> number  25% of XP earned inside the band (spec §6)
--   Leveling.XP_RATE[rank]                         typical XP per active minute at a rank (tasks + projects).
--   Leveling.rankXpScale(rank) -> number           XP_RATE[rank] / XP_RATE[1]: work/project XP should scale so
--                                                  a typical engaged player (mean quality ~72) earns XP_RATE
--   Leveling.reviewXp(level, band) -> number       weekly review XP bonus by band
--   Leveling.simulate(opts) -> SimResult           the pacing simulator (tests assert MD at ~30-35 h and L100
--                                                  at ~55-65 h for the IB ladder)
--
-- At the cap, XP keeps banking until the bar is full (xp == xpForLevel(cap)); the level rises right after the
-- promotion lifts the cap, so time spent waiting for the Friday review is never wasted.

local Tracks = require(script.Parent.Parent.Config.Tracks)
local Rng = require(script.Parent.Parent.Util.Rng)

local Leveling = {}

Leveling.MAX_LEVEL = Tracks.MAX_LEVEL

-- Curve: xpForLevel(L) = round(BASE + LINEAR * L + QUAD * L^2), rounded to 5.
Leveling.CURVE = { base = 170, linear = 24, quad = 0.104 }

-- Typical XP per active minute by rank (rank 0 = student). Ranks above 5 are for longer ladders (M5+).
Leveling.XP_RATE = { [0] = 12, 20, 27, 34, 41, 47, 53, 59, 65 } :: { [number]: number }

-- Weekly review XP bonus as a fraction of the current level's XP requirement.
Leveling.REVIEW_XP = { star = 0.45, on_track = 0.25, under = 0.1, probation = 0.03, critical = 0 } :: {
	[string]: number,
}

function Leveling.xpForLevel(level: number): number
	local l = math.clamp(math.floor(level), 1, Leveling.MAX_LEVEL)
	local c = Leveling.CURVE
	local raw = c.base + c.linear * l + c.quad * l * l
	return math.floor(raw / 5 + 0.5) * 5
end

-- Total XP from level 1 to reach `level` (with 0 XP into it).
function Leveling.totalToReach(level: number): number
	local total = 0
	for l = 1, math.clamp(math.floor(level), 1, Leveling.MAX_LEVEL) - 1 do
		total += Leveling.xpForLevel(l)
	end
	return total
end

function Leveling.rate(rank: number): number
	local r = math.max(0, math.floor(rank))
	local rates = Leveling.XP_RATE
	local v = rates[r]
	if v then
		return v
	end
	local top = 0
	for k in rates do
		if k > top then
			top = k
		end
	end
	return rates[top] + (r - top) * 6
end

function Leveling.rankXpScale(rank: number): number
	if rank <= 0 then
		return Leveling.rate(0) / Leveling.rate(1)
	end
	return Leveling.rate(rank) / Leveling.rate(1)
end

-- The level cap for a rank on a track (rank 0 = student cap).
function Leveling.capFor(trackId: string?, rank: number): number
	local def = Tracks.rankDef(trackId, rank)
	if def then
		return def.maxLevel
	end
	if rank <= 0 then
		return Tracks.STUDENT.maxLevel
	end
	return Leveling.MAX_LEVEL
end

-- Adds XP with a level cap. Returns the new level, XP into that level, the XP actually added and levels gained.
-- An amount of 0 still settles banked XP (e.g. right after a promotion lifted the cap).
function Leveling.addXp(level: number, xp: number, amount: number, cap: number): (number, number, number, number)
	local startLevel = math.clamp(math.floor(level), 1, Leveling.MAX_LEVEL)
	local lv = startLevel
	local c = math.clamp(math.floor(cap), 1, Leveling.MAX_LEVEL)
	local cur = if xp == xp then math.max(0, xp) else 0
	local amt = if amount == amount and amount > 0 then amount else 0
	local pool = cur + amt
	local gained = 0
	while lv < c and lv < Leveling.MAX_LEVEL do
		local need = Leveling.xpForLevel(lv)
		if pool < need then
			break
		end
		pool -= need
		lv += 1
		gained += 1
	end
	if lv >= c or lv >= Leveling.MAX_LEVEL then
		-- at the cap: bank up to a full bar
		pool = math.min(pool, Leveling.xpForLevel(lv))
	end
	local added = Leveling.spent(startLevel, lv) + pool - cur
	return lv, pool, math.max(0, added), gained
end

-- XP consumed by levelling from `fromLevel` to `toLevel` (helper for addXp's accounting).
function Leveling.spent(fromLevel: number, toLevel: number): number
	local total = 0
	for l = math.floor(fromLevel), math.floor(toLevel) - 1 do
		total += Leveling.xpForLevel(l)
	end
	return total
end

-- XP earned inside the current role band (from bandFloor with 0 XP up to level + xp).
function Leveling.xpInBand(level: number, xp: number, bandFloor: number): number
	local lv = math.floor(level)
	local floorLv = math.floor(bandFloor)
	if lv < floorLv then
		return 0
	end
	return Leveling.spent(floorLv, lv) + math.max(0, xp)
end

-- Removes XP, never dropping below floorLevel with 0 XP. Returns the new level, XP and the amount removed.
function Leveling.removeXp(level: number, xp: number, amount: number, floorLevel: number): (number, number, number)
	local lv = math.floor(level)
	local cur = math.max(0, xp)
	local remaining = math.max(0, math.floor(amount))
	local removed = 0
	while remaining > 0 do
		if cur >= remaining then
			cur -= remaining
			removed += remaining
			remaining = 0
		else
			remaining -= cur
			removed += cur
			cur = 0
			if lv <= floorLevel or lv <= 1 then
				break
			end
			lv -= 1
			cur = Leveling.xpForLevel(lv)
		end
	end
	return lv, cur, removed
end

-- The wipeout XP loss (spec §6): `fraction` (default 25%) of the XP earned inside the current role band.
function Leveling.wipeoutLoss(level: number, xp: number, bandFloor: number, fraction: number?): number
	return math.floor(Leveling.xpInBand(level, xp, bandFloor) * (fraction or 0.25))
end

function Leveling.reviewXp(level: number, band: string): number
	local f = Leveling.REVIEW_XP[band] or 0
	return math.floor(Leveling.xpForLevel(level) * f + 0.5)
end

---------------------------------------------------------------------------------------------------
-- Pacing simulator
---------------------------------------------------------------------------------------------------
export type SimOpts = {
	trackId: string?, -- default "ib"
	seed: any?,
	hireAtMin: number?, -- active minutes spent on campus before the first offer (default 180)
	reviewMean: number?, -- typical weekly review score (default 76)
	reviewSd: number?, -- spread of review scores (default 7)
	visitDelayMin: number?, -- minutes between "review ready" and the meeting (default 4)
	rateNoise: number?, -- +/- fraction of XP rate per minute (default 0.25)
	maxMinutes: number?, -- stop after this many active minutes (default 150 h)
}
export type SimResult = {
	rankAtMin: { [number]: number }, -- rank -> active minute it was reached
	levelAtMin: { [number]: number }, -- level -> active minute it was reached
	mdMinutes: number?, -- top rank reached
	l100Minutes: number?,
	reviews: number,
	promotionsBlocked: number,
}

local DUE_AT_MIN = 36 -- Friday afternoon (Time.REVIEW_WINDOW - WORKDAY / 2, in minutes)

function Leveling.simulate(opts: SimOpts?): SimResult
	local o: SimOpts = opts or {}
	local trackId = o.trackId or "ib"
	local track = Tracks.get(trackId)
	assert(track and #track.ladder > 0, "Leveling.simulate: unknown or unavailable track " .. tostring(trackId))
	local rng = Rng.new(o.seed or 1)
	local hireAt = o.hireAtMin or 180
	local mean = o.reviewMean or 76
	local sd = o.reviewSd or 7
	local delay = o.visitDelayMin or 4
	local noise = o.rateNoise or 0.25
	local maxMin = o.maxMinutes or 150 * 60
	local top = #track.ladder

	local level, xp, rank = 1, 0, 0
	local weekMin = 0
	local dueAt: number? = nil
	local result: SimResult = {
		rankAtMin = {},
		levelAtMin = { [1] = 0 },
		mdMinutes = nil,
		l100Minutes = nil,
		reviews = 0,
		promotionsBlocked = 0,
	}

	local function noteLevel(t: number)
		if result.levelAtMin[level] == nil then
			result.levelAtMin[level] = t
		end
		if level >= Leveling.MAX_LEVEL and result.l100Minutes == nil then
			result.l100Minutes = t
		end
	end

	for t = 1, maxMin do
		local cap = Leveling.capFor(trackId, rank)
		local gain = Leveling.rate(rank) * (1 + (rng:next() * 2 - 1) * noise)
		level, xp = Leveling.addXp(level, xp, gain, cap)
		noteLevel(t)

		if rank == 0 then
			if t >= hireAt then
				rank = 1
				result.rankAtMin[1] = t
				local floorLv = track.ladder[1].minLevel
				if level < floorLv then
					level, xp = floorLv, 0
				end
				level, xp = Leveling.addXp(level, xp, 0, Leveling.capFor(trackId, rank))
				noteLevel(t)
				weekMin = 0
			end
		else
			weekMin += 1
			if weekMin >= DUE_AT_MIN and dueAt == nil then
				dueAt = t
			end
			if dueAt and t >= dueAt + delay then
				dueAt = nil
				weekMin = 0
				result.reviews += 1
				local score = math.clamp(rng:normal(mean, sd), 0, 100)
				local band = if score >= 85
					then "star"
					elseif score >= 70 then "on_track"
					elseif score >= 55 then "under"
					elseif score >= 40 then "probation"
					else "critical"
				level, xp = Leveling.addXp(level, xp, Leveling.reviewXp(level, band), Leveling.capFor(trackId, rank))
				noteLevel(t)
				if rank < top and (band == "star" or band == "on_track") then
					local role = track.ladder[rank]
					local need = role.maxLevel
					if band == "star" then
						need = role.maxLevel - math.floor((role.maxLevel - role.minLevel + 1) * 0.2)
					end
					if level >= need then
						rank += 1
						result.rankAtMin[rank] = t
						level, xp = Leveling.addXp(level, xp, 0, Leveling.capFor(trackId, rank))
						noteLevel(t)
						if rank == top then
							result.mdMinutes = t
						end
					else
						result.promotionsBlocked += 1
					end
				end
			end
		end
		if result.l100Minutes then
			break
		end
	end
	return result
end

return Leveling
