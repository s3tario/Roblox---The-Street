--!strict
-- Investment metrics over ACTIVE-time windows (owned by `market`; spec §6, design v3 §11). PURE.
--
-- PortfolioService samples the book while the player is in a session: { a = active seconds, e = equity,
-- b = STREET 10 level, g = segment, n = trades so far, v = violations so far }. A segment is a stretch with no
-- external flow on one server: every session starts a new one (the next server has its own benchmark level) and so
-- does every flow (book top-up, wipeout, paid capital: sampled just before and just after). Returns chain only
-- between consecutive samples of the same segment, so:
--   * flows never count as returns (time-weighted), and flattening at mid on leave changes nothing,
--   * the benchmark return is measured over exactly the same intervals as the player's,
--   * a review window spanning several sessions chains the per-session returns.
-- Samples taken while AFK (same active second) collapse into one, so idle hours can't evict the week.
--
--   Metrics.sample(log, sample)            append (or collapse) into log.samples; ring of SAMPLE_MAX
--   Metrics.newSegment(log) -> number
--   Metrics.window(samples, fromActive, toActive, live?) -> Window
--       Window = { twr, benchReturn, excess, maxDrawdown, volatility, trades, violations, active, sessions, pairs }
--   Metrics.series(samples, segment, maxPoints?) -> { number }     equity curve of one segment (downsampled)
--   Metrics.recordWeek(weekReturns, entry, max?)     Metrics.seasonSkill(weekReturns, season) -> number?

export type Sample = { a: number, e: number, b: number, g: number, n: number, v: number }
export type Log = { samples: { Sample }, seg: number, weekFrom: number, clock: number }
export type Window = {
	twr: number,
	benchReturn: number,
	excess: number,
	maxDrawdown: number,
	volatility: number,
	trades: number,
	violations: number,
	active: number,
	sessions: number,
	pairs: number,
}
export type Week = {
	s: number, -- season
	w: number, -- career week
	at: number,
	twr: number,
	bench: number,
	excess: number,
	dd: number,
	vol: number,
	trades: number,
}

local Metrics = {}

Metrics.SAMPLE_MAX = 1200
Metrics.WEEKS_MAX = 20
Metrics.MIN_WEEKS = 2 -- Market Skill needs this many traded weeks in the season (minimum activity threshold)
Metrics.DD_ALLOWANCE = 0.03

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function Metrics.newLog(): Log
	return { samples = {}, seg = 0, weekFrom = -1, clock = 0 }
end

function Metrics.normalize(raw: any): Log
	local log: Log = if type(raw) == "table" then raw else Metrics.newLog()
	if type(log.samples) ~= "table" then
		log.samples = {}
	end
	local clean: { Sample } = {}
	for _, s in log.samples do
		if type(s) == "table" and type(s.a) == "number" and type(s.e) == "number" and type(s.b) == "number" then
			table.insert(clean, {
				a = s.a,
				e = s.e,
				b = s.b,
				g = num(s.g, 0),
				n = num(s.n, 0),
				v = num(s.v, 0),
			})
		end
	end
	log.samples = clean
	log.seg = math.max(0, math.floor(num(log.seg, 0)))
	log.weekFrom = num(log.weekFrom, -1)
	log.clock = math.max(0, num(log.clock, 0))
	return log
end

function Metrics.newSegment(log: Log): number
	log.seg += 1
	return log.seg
end

function Metrics.sample(log: Log, s: Sample)
	local list = log.samples
	local last = list[#list]
	if last and last.g == s.g and last.a == s.a and #list >= 2 and list[#list - 1].g == s.g then
		-- idle (no active time passed): keep the latest values only
		list[#list] = s
		return
	end
	table.insert(list, s)
	while #list > Metrics.SAMPLE_MAX do
		table.remove(list, 1)
	end
end

function Metrics.window(samples: { Sample }, fromActive: number, toActive: number, live: Sample?): Window
	local list = samples
	if live then
		list = table.clone(samples)
		table.insert(list, live)
	end
	local idx, bench, peak = 1, 1, 1
	local maxDD, sq = 0, 0
	local trades, violations, covered, pairs = 0, 0, 0, 0
	local segs: { [number]: boolean } = {}
	local sessions = 0
	for i = 2, #list do
		local p, c = list[i - 1], list[i]
		if p.g == c.g and p.a >= fromActive and c.a <= toActive and p.e > 0 and p.b > 0 and c.e > 0 then
			local r = c.e / p.e - 1
			local rb = c.b / p.b - 1
			idx *= 1 + r
			bench *= 1 + rb
			if idx > peak then
				peak = idx
			end
			local dd = 1 - idx / peak
			if dd > maxDD then
				maxDD = dd
			end
			local lr = math.log(1 + r)
			sq += lr * lr
			trades += math.max(0, c.n - p.n)
			violations += math.max(0, c.v - p.v)
			covered += math.max(0, c.a - p.a)
			pairs += 1
			if not segs[c.g] then
				segs[c.g] = true
				sessions += 1
			end
		end
	end
	local twr = idx - 1
	local br = bench - 1
	return {
		twr = twr,
		benchReturn = br,
		excess = twr - br,
		maxDrawdown = maxDD,
		volatility = math.sqrt(sq),
		trades = trades,
		violations = violations,
		active = covered,
		sessions = sessions,
		pairs = pairs,
	}
end

function Metrics.series(samples: { Sample }, segment: number, maxPoints: number?): { number }
	local pts: { number } = {}
	for _, s in samples do
		if s.g == segment then
			table.insert(pts, s.e)
		end
	end
	local cap = maxPoints or 60
	if #pts <= cap then
		return pts
	end
	local out: { number } = {}
	for i = 1, cap do
		local j = math.floor(1 + (i - 1) * (#pts - 1) / (cap - 1) + 0.5)
		out[i] = pts[j]
	end
	return out
end

function Metrics.recordWeek(weekReturns: { Week }, entry: Week, max: number?)
	table.insert(weekReturns, entry)
	while #weekReturns > (max or Metrics.WEEKS_MAX) do
		table.remove(weekReturns, 1)
	end
end

-- Market Skill for a season: risk-adjusted excess return, summed over traded weeks and scaled by sqrt(weeks) so
-- consistency beats one lucky week. nil below the activity threshold. Paid capital never matters: returns are
-- time-weighted, so the size of the book (and any flow into it) doesn't change the score.
function Metrics.seasonSkill(weekReturns: { Week }, season: number): number?
	local n, sum = 0, 0
	for _, w in weekReturns do
		if type(w) == "table" and w.s == season and num(w.trades, 0) > 0 then
			n += 1
			sum += num(w.excess, 0) - 0.5 * math.max(0, num(w.dd, 0) - Metrics.DD_ALLOWANCE)
		end
	end
	if n < Metrics.MIN_WEEKS then
		return nil
	end
	return math.max(0, math.floor(1000 + 10000 * sum / math.sqrt(n) + 0.5))
end

return Metrics
