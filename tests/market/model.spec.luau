-- Market model: construction, determinism for a seed, positivity and volatility sanity, mean reversion, the U-shaped
-- intraday curve, the earnings cycle, catalysts, research accuracy, and that nothing hidden reaches the snapshot.
local Shared = game:GetService("ReplicatedStorage").Shared
local Model = require(Shared.Logic.Market.Model)
local Schedule = require(Shared.Logic.Market.Schedule)
local Research = require(Shared.Logic.Market.Research)
local Band = require(Shared.Logic.Market.Band)
local Facts = require(Shared.Logic.Market.Facts)
local Tickers = require(Shared.Config.Tickers)
local Time = require(Shared.Util.Time)
local Rng = require(Shared.Util.Rng)

local DAY = Time.DAY_LEN
local T0 = Time.SEASON_EPOCH + 1000 * DAY -- the open of a market day

local function run(state, from: number, to: number, each: ((number) -> ())?)
	local out = {}
	for t = from, to, Time.TICK do
		for _, o in Model.step(state, t) do
			table.insert(out, o)
		end
		if each then
			each(t)
		end
	end
	return out
end

local function hasKey(v: any, key: string, depth: number?): boolean
	if type(v) ~= "table" or (depth or 0) > 8 then
		return false
	end
	for k, x in v do
		if k == key then
			return true
		end
		if hasKey(x, key, (depth or 0) + 1) then
			return true
		end
	end
	return false
end

return function(t)
	t.describe("Tickers config", function()
		t.it("lists the ten fictional tickers with sane fundamentals and staggered earnings", function()
			t.expect(#Tickers.IDS).toBe(10)
			t.expect(table.concat(Tickers.IDS, " ")).toBe("APX NMB MRB VLT SMT TTN HBR CRL ORN BLF")
			local offsets = {}
			for _, def in Tickers.list do
				t.expect(Tickers.sector(def.sector)).never(nil)
				t.expect(Tickers.basePrice(def)).toBeBetween(10, 500)
				t.expect(def.beta).toBeBetween(0.3, 2)
				t.expect(def.earningsOffset).toBeBetween(0, Tickers.EARNINGS_EVERY - 1)
				offsets[def.earningsOffset] = true
				t.expect(#def.desc > 10).toBeTruthy()
			end
			local spread = 0
			for _ in offsets do
				spread += 1
			end
			t.expect(spread).toBeGreaterThanOrEqual(6)
			t.expect(Tickers.text("err_concentration", { pct = "45%", ticker = "APX", limit = "40%" })).toContain(
				"45%"
			)
			for _, id in Tickers.EVENT_IDS do
				t.expect(Tickers.events[id]).never(nil)
			end
		end)
	end)

	t.describe("Schedule", function()
		t.it("normalises the U-shaped curve and is highest at the bells", function()
			local s2 = 0
			for i = 0, 999 do
				local u = Schedule.uShape(i / 999)
				s2 += u * u
			end
			t.expect(s2 / 1000).toBeCloseTo(1, 0.02)
			t.expect(Schedule.uShape(0)).toBeGreaterThan(Schedule.uShape(0.5) * 2)
			t.expect(Schedule.uShape(1)).toBeCloseTo(Schedule.uShape(0), 1e-9)
		end)
		t.it("finds wall times after n open ticks across the after-hours gap", function()
			t.expect(Schedule.afterOpenTicks(T0, 10)).toBe(T0 + 20)
			local nearClose = T0 + 290 -- 5 ticks left today
			t.expect(Schedule.afterOpenTicks(nearClose, 5)).toBe(T0 + 300)
			t.expect(Schedule.afterOpenTicks(nearClose, 6)).toBe(T0 + DAY + 2)
			t.expect(Schedule.afterOpenTicks(T0 + 320, 150)).toBe(T0 + DAY + 300)
			t.expect(Schedule.phase(T0 + 299)).toBe("open")
			t.expect(Schedule.phase(T0 + 300)).toBe("after")
			t.expect(Schedule.nextOpenAt(T0 + 330)).toBe(T0 + DAY)
		end)
	end)

	t.describe("construction", function()
		t.it("starts every ticker positive with 30 days of history and a scheduled report", function()
			local s = Model.new(42, T0 + 100)
			t.expect(#s.tickers).toBe(10)
			for _, ts in s.tickers do
				t.expect(ts.price).toBeGreaterThan(0)
				t.expect(#ts.daily).toBe(Model.HISTORY_DAYS)
				t.expect(#ts.intraday).toBe(51) -- ticks 0..50 of the session so far
				t.expect(ts.next.day).toBeGreaterThanOrEqual(s.day)
				t.expect(ts.next.day - s.day).toBeLessThan(Tickers.EARNINGS_EVERY)
				t.expect((ts.next.day - ts.def.earningsOffset) % Tickers.EARNINGS_EVERY).toBe(0)
			end
			t.expect(Model.indexLevel(s)).toBeBetween(4000, 6000)
			t.expect(#s.index.daily).toBe(Model.HISTORY_DAYS)
		end)
		t.it("is deterministic for a seed and differs between seeds", function()
			local a, b, c = Model.new(7, T0), Model.new(7, T0), Model.new(8, T0)
			run(a, T0, T0 + 3 * DAY)
			run(b, T0, T0 + 3 * DAY)
			run(c, T0, T0 + 3 * DAY)
			local pa, pb, pc = Model.priceList(a), Model.priceList(b), Model.priceList(c)
			t.expect(pa).toEqual(pb)
			local same = 0
			for i = 1, #pa do
				if pa[i] == pc[i] then
					same += 1
				end
			end
			t.expect(same).toBeLessThan(3)
			t.expect(Model.news(a, 40)).toEqual(Model.news(b, 40))
		end)
		t.it("never puts hidden values in the snapshot or tick payload", function()
			local s = Model.new(3, T0)
			run(s, T0, T0 + 2 * DAY)
			local snap = Model.snapshot(s, T0 + 2 * DAY)
			t.expect(hasKey(snap, "fv")).toBeFalsy()
			t.expect(hasKey(snap, "mult")).toBeFalsy()
			for _, entry in snap.tickers do
				t.expect(entry.next.surprise).toBeNil()
				t.expect(entry.quote.price).toBeGreaterThan(0)
			end
			t.expect(#snap.tickers).toBe(10)
			local tick = Model.tickPayload(s, T0 + 2 * DAY)
			t.expect(#tick.p).toBe(10)
			t.expect(tick.k).toBe(0)
		end)
	end)

	t.describe("price dynamics", function()
		t.it("keeps prices positive with sane daily volatility over 120 market days", function()
			local s = Model.new(1234, T0)
			local closes = {}
			local minSeen = math.huge
			local finite = true
			run(s, T0, T0 + 120 * DAY, function(time)
				for _, ts in s.tickers do
					if ts.price ~= ts.price or ts.price == math.huge then
						finite = false
					end
					minSeen = math.min(minSeen, ts.price)
				end
				if (time - T0) % DAY == 300 then
					table.insert(closes, Model.indexLevel(s))
				end
			end)
			t.expect(finite).toBeTruthy()
			t.expect(minSeen).toBeGreaterThan(Model.MIN_PRICE - 1e-9)
			local rets = {}
			for i = 2, #closes do
				table.insert(rets, math.log(closes[i] / closes[i - 1]))
			end
			local m, v = 0, 0
			for _, r in rets do
				m += r
			end
			m /= #rets
			for _, r in rets do
				v += (r - m) ^ 2
			end
			local sd = math.sqrt(v / (#rets - 1))
			t.expect(sd).toBeBetween(0.004, 0.025)
			-- fair values grow with expected earnings, so the index drifts up rather than collapsing
			t.expect(closes[#closes] / closes[1]).toBeBetween(0.6, 2.5)
		end)
		t.it("mean-reverts toward fair value with roughly the configured half-life", function()
			local ratios = {}
			for seed = 1, 6 do
				local s = Model.new(seed, T0)
				for _, ts in s.tickers do
					ts.price = ts.fv * 1.5
				end
				local gap0 = 0
				for _, ts in s.tickers do
					gap0 += math.log(ts.price / ts.fv)
				end
				run(s, T0, T0 + Model.HALF_LIFE_DAYS * DAY - Time.TICK)
				local gap = 0
				for _, ts in s.tickers do
					gap += math.log(ts.price / ts.fv)
				end
				table.insert(ratios, gap / gap0)
			end
			local avg = 0
			for _, r in ratios do
				avg += r
			end
			avg /= #ratios
			t.expect(avg).toBeBetween(0.3, 0.75)
		end)
		t.it("is more volatile near the bells than at midday (U-shaped)", function()
			local s = Model.new(99, T0)
			local edge, mid, nEdge, nMid = 0, 0, 0, 0
			local prev = Model.indexLevel(s)
			run(s, T0, T0 + 40 * DAY, function(time)
				local into = (time - T0) % DAY
				local level = Model.indexLevel(s)
				if into < 300 then
					local k = into // 2
					local r = math.abs(math.log(level / prev))
					if k >= 1 and k <= 15 or k >= 135 then
						edge += r
						nEdge += 1
					elseif k >= 60 and k <= 90 then
						mid += r
						nMid += 1
					end
				end
				prev = level
			end)
			t.expect((edge / nEdge) / (mid / nMid)).toBeGreaterThan(1.5)
		end)
		t.it("does not move prices after hours", function()
			local s = Model.new(5, T0)
			run(s, T0, T0 + 300)
			local before = Model.priceList(s)
			local reported = false
			for _, ts in s.tickers do
				if ts.last and ts.last.day == s.day then
					reported = true
				end
			end
			run(s, T0 + 302, T0 + 358)
			local after = Model.priceList(s)
			if not reported then
				t.expect(after).toEqual(before)
			end
			t.expect(Model.isOpen(s, T0 + 320)).toBeFalsy()
			t.expect(Model.isOpen(s, T0 + DAY + 10)).toBeFalsy() -- not stepped there yet
			run(s, T0 + 360, T0 + DAY + 10)
			t.expect(Model.isOpen(s, T0 + DAY + 10)).toBeTruthy()
		end)
	end)

	t.describe("earnings", function()
		t.it("reports every ticker every 8 days with consensus published 2 days ahead", function()
			local s = Model.new(77, T0)
			local releases: { [string]: { number } } = {}
			local consensusDay: { [string]: number } = {}
			local leadOk = true
			local surprises = {}
			local out = run(s, T0, T0 + 48 * DAY)
			for _, o in out do
				if o.kind == "news" and o.item.kind == "consensus" then
					consensusDay[o.item.ticker] = o.item.day
				elseif o.kind == "earnings" then
					local list = releases[o.ticker] or {}
					releases[o.ticker] = list
					table.insert(list, o.result.day)
					local published = consensusDay[o.ticker]
					if published and Model.relDay(s, o.result.day) - published < Tickers.CONSENSUS_LEAD then
						leadOk = false
					end
					table.insert(surprises, o.result.surprise)
				end
			end
			t.expect(leadOk).toBeTruthy()
			for _, id in Tickers.IDS do
				local list = releases[id]
				t.expect(list).never(nil)
				t.expect(#list).toBeBetween(5, 7)
				for i = 2, #list do
					t.expect(list[i] - list[i - 1]).toBe(Tickers.EARNINGS_EVERY)
				end
			end
			local m = 0
			for _, x in surprises do
				m += x
			end
			m /= #surprises
			t.expect(m).toBeBetween(-0.02, 0.03)
		end)
		t.it("moves the price after hours in the direction of the surprise", function()
			local agree, total = 0, 0
			for seed = 1, 8 do
				local s = Model.new(seed * 31, T0)
				for _, o in run(s, T0, T0 + 9 * DAY) do
					if o.kind == "earnings" then
						total += 1
						if (o.result.surprise >= 0) == (o.result.reaction >= 0) then
							agree += 1
						end
					end
				end
			end
			t.expect(total).toBeGreaterThan(50)
			t.expect(agree).toBe(total)
		end)
	end)

	t.describe("catalysts", function()
		t.it("announces a day ahead and resolves with the stated odds", function()
			local announced, resolved, good, oddsSum = 0, 0, 0, 0
			for seed = 1, 12 do
				local s = Model.new(seed, T0)
				for _, o in run(s, T0, T0 + 30 * DAY) do
					if o.kind == "catalyst" then
						if o.catalyst.resolved then
							resolved += 1
							oddsSum += o.catalyst.odds
							if o.catalyst.good then
								good += 1
							end
						else
							announced += 1
						end
					end
				end
			end
			t.expect(announced).toBeGreaterThan(60)
			t.expect(resolved).toBeGreaterThanOrEqual(announced - 12)
			t.expect(math.abs(good / resolved - oddsSum / resolved)).toBeLessThan(0.12)
		end)
	end)

	t.describe("research", function()
		t.it("follows the accuracy curve 0.55 + 0.35 q / 100", function()
			t.expect(Research.accuracy(0)).toBeCloseTo(0.55)
			t.expect(Research.accuracy(100)).toBeCloseTo(0.9)
			t.expect(Research.accuracy(250)).toBeCloseTo(0.9)
			local rng = Rng.new(5)
			for _, q in { 0, 50, 100 } do
				local right = 0
				local n = 6000
				for i = 1, n do
					local surprise = rng:normal(0, 0.05)
					local sig = Research.signal(1000 + i, "APX", i, surprise, q)
					if sig.beat == (surprise >= 0) then
						right += 1
					end
				end
				t.expect(right / n).toBeCloseTo(Research.accuracy(q), 0.025)
			end
		end)
		t.it("can't be re-rolled and better research never flips a right call", function()
			local s = Model.new(11, T0)
			for _, id in Tickers.IDS do
				local a = Model.research(s, id, 40) :: any
				local b = Model.research(s, id, 40) :: any
				t.expect(a.direction).toBe(b.direction)
				local truth = s.byId[id].next.surprise >= 0
				local hi = Model.research(s, id, 100) :: any
				if a.beat == truth then
					t.expect(hi.beat).toBe(truth)
				end
				t.expect(a.confidence).toBeCloseTo(0.69, 0.001)
			end
		end)
	end)

	t.describe("facts and band", function()
		t.it("derives market cap, P/E and EV from fundamentals and the live price", function()
			local s = Model.new(2, T0)
			local f = Model.facts(s, "APX") :: any
			t.expect(f.ticker).toBe("APX")
			t.expect(f.marketCap).toBeCloseTo(f.shares * f.price, 1)
			t.expect(f.pe).toBeCloseTo(f.price / f.eps, 0.2)
			t.expect(f.ev).toBeCloseTo(f.marketCap + f.debt - f.cash, 1)
			t.expect(#f.chart).toBe(Model.HISTORY_DAYS + 1)
			t.expect(f.nextEarnings.inDays).toBeGreaterThanOrEqual(0)
			local again = Facts.derive(Model.fundamentals(s, "APX") :: any, 100)
			t.expect(again.marketCap).toBe(f.shares * 100)
		end)
		t.it("formats the LED band line and repeats it to fill a band", function()
			local line = Band.line({ { id = "APX", price = 219.4, changePct = 0.012 } }, { level = 5012.3, changePct = -0.004 })
			t.expect(line).toContain("APX")
			t.expect(line).toContain("+1.20%")
			t.expect(line).toContain("ST10 5012.3")
			t.expect(line).toContain("-0.40%")
			local text, reps = Band.fit(line, 400, 30, 40)
			t.expect(reps).toBeBetween(2, Band.MAX_REPS)
			t.expect(#text).toBe(reps * (#line + #Band.GAP))
		end)
	end)
end
