--!strict
-- Market clock helpers (owned by `market`; spec §3). PURE: callers pass `now`.
-- A market day is Time.DAY_LEN (360 s): Time.OPEN_LEN (300 s) of open session in Time.TICK (2 s) ticks, then 60 s of
-- after-hours. Days follow the global season clock (Time.dayIndex), so every server shares the same bell times while
-- running its own prices.
--
--   Schedule.OPEN_TICKS                     open ticks per day (150)
--   Schedule.uShape(x) -> number            intraday volatility multiplier at session fraction x (0..1); U-shaped,
--                                           normalised so its mean square over the session is 1
--   Schedule.phase(now) -> "open" | "after"
--   Schedule.tickIndex(now) -> k?           open tick index 0..149 (nil after hours)
--   Schedule.dayStart(now) / closeAt(now) / nextOpenAt(now) -> number
--   Schedule.afterOpenTicks(now, n) -> number   wall time once n more open ticks have elapsed

local Time = require(script.Parent.Parent.Parent.Util.Time)

local Schedule = {}

Schedule.TICK = Time.TICK
Schedule.DAY_LEN = Time.DAY_LEN
Schedule.OPEN_LEN = Time.OPEN_LEN
Schedule.OPEN_TICKS = Time.OPEN_LEN // Time.TICK

-- u(x) = c * (1 + K * (2x - 1)^2); E[u^2] over x in [0, 1] = c^2 * (1 + 2K/3 + K^2/5) = 1.
local K = 1.5
local C = 1 / math.sqrt(1 + 2 * K / 3 + K * K / 5)
Schedule.U_K = K

function Schedule.uShape(x: number): number
	local d = 2 * math.clamp(x, 0, 1) - 1
	return C * (1 + K * d * d)
end

function Schedule.phase(now: number): "open" | "after"
	local _, into = Time.dayIndex(now)
	return if into < Time.OPEN_LEN then "open" else "after"
end

function Schedule.tickIndex(now: number): number?
	local _, into = Time.dayIndex(now)
	if into >= Time.OPEN_LEN then
		return nil
	end
	return math.floor(into / Time.TICK)
end

function Schedule.dayStart(now: number): number
	local _, into = Time.dayIndex(now)
	return now - into
end

function Schedule.closeAt(now: number): number
	return Schedule.dayStart(now) + Time.OPEN_LEN
end

function Schedule.nextOpenAt(now: number): number
	local _, into = Time.dayIndex(now)
	if into < Time.OPEN_LEN then
		return now - into -- already open: this session's open
	end
	return now - into + Time.DAY_LEN
end

function Schedule.afterOpenTicks(now: number, n: number): number
	local left = math.max(0, math.ceil(n))
	if left == 0 then
		return now
	end
	local _, into = Time.dayIndex(now)
	local start = now - into
	local t = now
	if into < Time.OPEN_LEN then
		local remaining = math.floor((Time.OPEN_LEN - into) / Time.TICK)
		if left <= remaining then
			return now + left * Time.TICK
		end
		left -= remaining
	end
	start += Time.DAY_LEN
	local per = Schedule.OPEN_TICKS
	local days = (left - 1) // per
	left -= days * per
	t = start + days * Time.DAY_LEN + left * Time.TICK
	return t
end

return Schedule
