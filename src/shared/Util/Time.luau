--!strict
-- Game clocks. All gameplay timing derives from synced server time.
-- Logic modules must NOT call Time.now(); callers pass `now` in so logic stays testable.

local Time = {}

Time.SEASON_EPOCH = 1790812800 -- 2026-10-01 00:00:00 UTC
Time.SEASON_LEN = 28 * 24 * 3600 -- 2,419,200 s
Time.DAY_LEN = 360 -- one market day (real seconds)
Time.OPEN_LEN = 300 -- open session; the remaining 60 s are after-hours
Time.TICK = 2 -- display tick
Time.WEEK_DAYS = 5 -- market days per market week
Time.DAYS_PER_SEASON = Time.SEASON_LEN // Time.DAY_LEN -- 6720
Time.REVIEW_WINDOW = 40 * 60 -- active seconds per review window ("work week")
Time.WORKDAY = 8 * 60 -- active seconds per workday
Time.DAYNIGHT_LEN = 24 * 60 -- full cosmetic day/night cycle
Time.AFK_AFTER = 120 -- seconds without input before active time stops counting

-- Synced server time in seconds. Uses workspace:GetServerTimeNow() inside Roblox, os.time() in Lune.
function Time.now(): number
	local ws: any = workspace -- nil when running under Lune
	if ws ~= nil then
		return ws:GetServerTimeNow()
	end
	return os.time()
end

function Time.season(now: number): number
	return math.floor((now - Time.SEASON_EPOCH) / Time.SEASON_LEN)
end

function Time.seasonStart(season: number): number
	return Time.SEASON_EPOCH + season * Time.SEASON_LEN
end

-- Market day index within the season (0-based) and seconds into that day.
function Time.dayIndex(now: number): (number, number)
	local season = Time.season(now)
	local into = now - Time.seasonStart(season)
	local day = math.floor(into / Time.DAY_LEN)
	return day, into - day * Time.DAY_LEN
end

-- Absolute start time of market day `day` in `season`.
function Time.dayStart(season: number, day: number): number
	return Time.seasonStart(season) + day * Time.DAY_LEN
end

function Time.marketPhase(now: number): "open" | "after"
	local _, into = Time.dayIndex(now)
	return if into < Time.OPEN_LEN then "open" else "after"
end

-- Lighting.ClockTime for the cosmetic day/night cycle (0-24).
function Time.clockTime(now: number): number
	return ((now % Time.DAYNIGHT_LEN) / Time.DAYNIGHT_LEN) * 24
end

function Time.isNight(now: number): boolean
	local c = Time.clockTime(now)
	return c < 6.2 or c > 18.2
end

return Time
