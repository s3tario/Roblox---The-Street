-- Market event overlays: each one's signature shape on the price path, the closed holiday, and the one-at-a-time rule.
local Shared = game:GetService("ReplicatedStorage").Shared
local Model = require(Shared.Logic.Market.Model)
local Time = require(Shared.Util.Time)

local DAY = Time.DAY_LEN
local T0 = Time.SEASON_EPOCH + 2000 * DAY

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

-- A fresh market at the open of day 0 with its first tick processed.
local function fresh(seed: number)
	local s = Model.new(seed, T0)
	Model.step(s, T0)
	return s
end

local function mean(list: { number }): number
	local m = 0
	for _, x in list do
		m += x
	end
	return m / #list
end

return function(t)
	t.describe("crash and boom", function()
		t.it("crashes the index 15-25% in ~3 minutes, then recovers only partly", function()
			for seed = 1, 4 do
				local s = fresh(seed)
				local start = Model.indexLevel(s)
				t.expect((Model.trigger(s, "crash", nil, T0))).toBeTruthy()
				local ev = Model.activeEvent(s) :: any
				t.expect(ev.id).toBe("crash")
				t.expect(ev.endsAt).toBeGreaterThan(ev.startsAt)
				run(s, T0 + 2, T0 + 180)
				local trough = Model.indexLevel(s)
				t.expect(1 - trough / start).toBeBetween(0.11, 0.29)
				run(s, T0 + 182, T0 + 3 * DAY)
				local later = Model.indexLevel(s)
				t.expect(later).toBeGreaterThan(trough)
				t.expect(later).toBeLessThan(start)
				t.expect(Model.activeEvent(s)).toBeNil()
			end
		end)
		t.it("lifts the index 10-20% in a boom", function()
			local s = fresh(9)
			local start = Model.indexLevel(s)
			t.expect((Model.trigger(s, "boom", { depth = 0.15 }, T0))).toBeTruthy()
			run(s, T0 + 2, T0 + 240)
			t.expect(Model.indexLevel(s) / start - 1).toBeBetween(0.1, 0.21)
		end)
		t.it("drops fast in a flash crash and recovers about 70% by the close", function()
			local recovered = {}
			for seed = 1, 5 do
				local s = fresh(seed * 7)
				local start = Model.indexLevel(s)
				Model.trigger(s, "flash_crash", { depth = 0.08 }, T0)
				run(s, T0 + 2, T0 + 40)
				local bottom = Model.indexLevel(s)
				t.expect(1 - bottom / start).toBeBetween(0.05, 0.11)
				run(s, T0 + 42, T0 + 298)
				table.insert(recovered, (Model.indexLevel(s) - bottom) / (start - bottom))
			end
			t.expect(mean(recovered)).toBeBetween(0.5, 1.0)
		end)
	end)

	t.describe("single-name and sector overlays", function()
		t.it("sends one meme stock +30-80% and fades it over two days", function()
			local s = fresh(4)
			Model.trigger(s, "meme_rally", { ticker = "CRL", size = 0.6 }, T0)
			local start = s.byId.CRL.price
			run(s, T0 + 2, T0 + 180)
			local peak = s.byId.CRL.price
			t.expect(peak / start - 1).toBeBetween(0.35, 0.95)
			local ev = Model.activeEvent(s) :: any
			t.expect(ev.data.ticker).toBe("CRL")
			run(s, T0 + 182, T0 + 3 * DAY)
			local faded = s.byId.CRL.price
			t.expect(faded).toBeLessThan(peak * 0.85)
			t.expect(Model.activeEvent(s)).toBeNil() -- the slot frees after a day; the fade carries on
		end)
		t.it("hits banks and real estate hardest in a rate shock", function()
			local sum: { [string]: number } = {}
			local seeds = 10
			for seed = 1, seeds do
				local s = fresh(seed)
				local before = Model.prices(s)
				Model.trigger(s, "rate_shock", { size = 0.06 }, T0)
				run(s, T0 + 2, T0 + 120)
				for id, p in Model.prices(s) do
					sum[id] = (sum[id] or 0) + math.log(p / before[id]) / seeds
				end
			end
			local order = {}
			for id, r in sum do
				table.insert(order, { id = id, r = r })
			end
			table.sort(order, function(a, b)
				return a.r < b.r
			end)
			local worstTwo = { order[1].id, order[2].id }
			table.sort(worstTwo)
			t.expect(table.concat(worstTwo, ",")).toBe("MRB,SMT")
			t.expect(sum.SMT).toBeBetween(-0.12, -0.04)
			t.expect(sum.TTN).toBeGreaterThan(sum.APX) -- money rotates into energy
		end)
		t.it("makes three companies report at today's close in an earnings frenzy", function()
			local s = fresh(13)
			Model.trigger(s, "earnings_frenzy", nil, T0)
			local ev = Model.activeEvent(s) :: any
			local list = string.split(ev.data.list, ", ")
			t.expect(#list).toBe(3)
			local reported: { [string]: boolean } = {}
			for _, o in run(s, T0 + 2, T0 + 302) do
				if o.kind == "earnings" then
					reported[o.ticker] = true
				end
			end
			for _, id in list do
				t.expect(reported[id]).toBe(true)
				t.expect(s.byId[id].next.day).toBeGreaterThan(s.day)
			end
			t.expect(Model.activeEvent(s)).toBeNil()
		end)
	end)

	t.describe("volatility overlays", function()
		local function tickVol(s, from: number, to: number): number
			local prev = Model.indexLevel(s)
			local sum, n = 0, 0
			run(s, from, to, function()
				local level = Model.indexLevel(s)
				if level ~= prev then
					sum += (math.log(level / prev)) ^ 2
					n += 1
				end
				prev = level
			end)
			return math.sqrt(sum / math.max(n, 1))
		end
		t.it("triples volatility on a crazy day", function()
			local ratios = {}
			for seed = 1, 4 do
				local s = fresh(seed * 3)
				local normal = tickVol(s, T0 + 2, T0 + 298)
				Model.step(s, T0 + DAY)
				Model.trigger(s, "crazy_day", nil, T0 + DAY)
				local crazy = tickVol(s, T0 + DAY + 2, T0 + DAY + 298)
				table.insert(ratios, crazy / normal)
			end
			t.expect(mean(ratios)).toBeBetween(2.2, 3.8)
		end)
		t.it("announces a rate decision on fed day with a volatility spike around it", function()
			local s = fresh(21)
			Model.trigger(s, "fed_day", { decisionTick = 40, outcome = "hike" }, T0)
			t.expect((Model.activeEvent(s) :: any).data.outcome).toBeNil()
			local before = Model.indexLevel(s)
			local out = run(s, T0 + 2, T0 + 100)
			local fed = false
			for _, o in out do
				if o.kind == "news" and o.item.kind == "fed_hike" then
					fed = true
				end
			end
			t.expect(fed).toBeTruthy()
			t.expect(Model.indexLevel(s)).toBeLessThan(before * 1.01)
			t.expect((Model.activeEvent(s) :: any).data.outcome).toBe("hike")
		end)
	end)

	t.describe("holiday", function()
		t.it("closes the exchange, freezes prices, postpones earnings and reopens", function()
			local s = fresh(17)
			Model.trigger(s, "holiday", { duration = DAY }, T0)
			t.expect(s.phase).toBe("closed")
			t.expect(Model.isOpen(s, T0 + 2)).toBeFalsy()
			local before = Model.priceList(s)
			local due: { string } = {}
			for _, ts in s.tickers do
				if ts.next.day == s.day then
					table.insert(due, ts.id)
				end
			end
			local out = run(s, T0 + 2, T0 + DAY - 2)
			t.expect(Model.priceList(s)).toEqual(before)
			for _, o in out do
				t.expect(o.kind ~= "earnings").toBeTruthy()
			end
			for _, id in due do
				t.expect(s.byId[id].next.day).toBe(s.day + 1)
			end
			t.expect(Model.tickPayload(s, T0 + 100).ph).toBe("closed")
			local reopened = false
			for _, o in run(s, T0 + DAY, T0 + DAY + 20) do
				if o.kind == "news" and o.item.kind == "reopen" then
					reopened = true
				end
			end
			t.expect(reopened).toBeTruthy()
			t.expect(Model.isOpen(s, T0 + DAY + 20)).toBeTruthy()
			t.expect(Model.priceList(s)).never(before)
		end)
	end)

	t.describe("one event at a time", function()
		t.it("refuses a second event unless forced and rejects unknown ids", function()
			local s = fresh(1)
			t.expect((Model.trigger(s, "crazy_day", nil, T0))).toBeTruthy()
			local ok, err = Model.trigger(s, "boom", nil, T0)
			t.expect(ok).toBeFalsy()
			t.expect(err).toBe("busy")
			t.expect((Model.trigger(s, "boom", { force = true }, T0))).toBeTruthy()
			t.expect((Model.activeEvent(s) :: any).id).toBe("boom")
			local ok2, err2 = Model.trigger(s, "alien_invasion", nil, T0)
			t.expect(ok2).toBeFalsy()
			t.expect(err2).toBe("unknown_event")
			t.expect(Model.stopEvent(s, T0)).toBeTruthy()
			t.expect(Model.activeEvent(s)).toBeNil()
		end)
	end)
end
