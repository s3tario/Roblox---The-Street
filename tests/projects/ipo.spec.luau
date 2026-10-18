-- ipo mechanics (the IB signature deal): the IPO-day pop decides the outcome. 10-25% is ideal; pricing too low
-- leaves money on the table; pricing at the top of the book leaves nothing for day one; pricing above the book
-- breaks the deal (postponed). The client pick, the roadshow and the allocation all feed the order book.
local Shared = game:GetService("ReplicatedStorage").Shared
local Rng = require(Shared.Util.Rng)
local Solve = require(Shared.Logic.Tasks._shared.Solve)
local ipo = require(Shared.Logic.Projects.ipo)

local CTX = { level = 40, rank = 3, track = "ib", difficulty = 0.55, hints = 1, now = 1790812800, marketMood = 1 }

-- Plays stages 1-4 perfectly (or with `pickWrong` choosing a flawed client) and stops at pricing.
local function toPricing(seed: number, opts: { [string]: any }?): any
	local o = opts or {}
	local ctx = o.ctx or CTX
	local state = ipo.new(Rng.new(seed), ctx)
	-- stage 1: the client
	local answers = Solve.perfect(state.current.secret)
	if o.pickWrong then
		local key = state.current.secret.key.q_pick
		answers.q_pick = if key == 1 then 2 else 1
	end
	state = ipo.act(state, answers, ctx)
	for _ = 2, 4 do
		local a = if o.weakRoadshow and state.current.id == "roadshow"
			then Solve.degrade(state.current.secret, 99)
			else Solve.perfect(state.current.secret)
		state = ipo.act(state, a, ctx)
	end
	assert(state.current.id == "pricing", "expected the pricing stage")
	return state
end

-- Prices the deal at `factor` x the book's clearing price (allocation perfect unless `badAlloc`).
local function priceAt(state: any, factor: number, badAlloc: boolean?): any
	local answers = Solve.perfect(state.current.secret)
	if badAlloc then
		answers[2] = Solve.degrade({ kind = "multi", sections = { state.current.secret.sections[2] } }, 99)[1]
	end
	answers[1].offer = math.floor(state.current.meta.clearing * factor * 100 + 0.5) / 100
	return ipo.act(state, answers, CTX)
end

return function(t)
	t.describe("pop curve", function()
		t.it("rewards a 10-25% pop most", function()
			t.expect(ipo.popScore(0.1)).toBe(100)
			t.expect(ipo.popScore(0.175)).toBe(100)
			t.expect(ipo.popScore(0.25)).toBe(100)
			t.expect(ipo.popScore(0.05)).toBeLessThan(100)
			t.expect(ipo.popScore(0.05)).toBeGreaterThan(ipo.popScore(0))
			t.expect(ipo.popScore(0.4)).toBeLessThan(ipo.popScore(0.3))
			t.expect(ipo.popScore(-0.1)).toBeLessThanOrEqual(40)
			t.expect(ipo.popScore(1.5)).toBeLessThanOrEqual(20)
		end)
	end)

	t.describe("pricing", function()
		t.it("perfect pricing pops 10-25% and closes", function()
			for seed = 1, 12 do
				local state = priceAt(toPricing(seed), 1 / 1.175)
				local data = state.outcome.data
				t.expect(state.outcome.closed).toBe(true)
				t.expect(data.pop).toBeGreaterThanOrEqual(0.1)
				t.expect(data.pop).toBeLessThanOrEqual(0.25)
				t.expect(state.quality).toBeGreaterThanOrEqual(85)
			end
		end)
		t.it("pricing too low leaves money on the table", function()
			local ideal = priceAt(toPricing(3), 1 / 1.175)
			local cheap = priceAt(toPricing(3), 0.6)
			t.expect(cheap.outcome.closed).toBe(true)
			t.expect(cheap.outcome.data.pop).toBeGreaterThan(0.25)
			t.expect(cheap.quality).toBeLessThan(ideal.quality)
			local labels = {}
			for _, fig in cheap.outcome.figures do
				labels[fig.label] = fig.value
			end
			t.expect(labels["Left on the table"]).toBeTruthy()
			t.expect(cheap.outcome.headline).toContain("on the table")
		end)
		t.it("pricing at the top of the book leaves no pop", function()
			local state = priceAt(toPricing(5), 1)
			t.expect(state.outcome.closed).toBe(true)
			t.expect(state.outcome.data.pop).toBeLessThan(0.1)
			t.expect(state.quality).toBeLessThan(priceAt(toPricing(5), 1 / 1.175).quality)
		end)
		t.it("pricing above the book breaks the deal", function()
			local state = priceAt(toPricing(7), 1.15)
			t.expect(state.outcome.closed).toBe(false)
			t.expect(state.outcome.data.pulled).toBe(true)
			t.expect(state.dealName).toContain("(postponed)")
			t.expect(state.quality).toBeLessThan(70)
		end)
		t.it("letting fast money flip the shares trims the day-one close", function()
			local good = priceAt(toPricing(9), 1 / 1.175)
			local flipped = priceAt(toPricing(9), 1 / 1.175, true)
			t.expect(flipped.outcome.data.trade).toBeLessThan(good.outcome.data.trade)
			t.expect(table.concat(flipped.outcome.lines, " ")).toContain("fast money")
		end)
	end)

	t.describe("order book", function()
		t.it("a flawed client and a weak roadshow make a colder book", function()
			for seed = 1, 8 do
				local hot = toPricing(seed)
				local cold = toPricing(seed, { pickWrong = true, weakRoadshow = true })
				local hotRatio = hot.current.meta.clearing / hot.facts.perShare
				local coldRatio = cold.current.meta.clearing / cold.facts.perShare
				t.expect(coldRatio).toBeLessThan(hotRatio)
				t.expect(cold.facts.pickedKind).never("ready")
			end
		end)
		t.it("a risk-on market lifts the book a little", function()
			local calm = toPricing(4)
			local hotCtx = table.clone(CTX) :: any
			hotCtx.marketMood = 1.2
			local hot = toPricing(4, { ctx = hotCtx })
			t.expect(hot.current.meta.clearing).toBeGreaterThanOrEqual(calm.current.meta.clearing)
		end)
	end)

	t.describe("story", function()
		t.it("names the plaque after the codename, the raise and the client", function()
			local state = priceAt(toPricing(2), 1 / 1.175)
			t.expect(state.dealName).toContain(state.facts.codename)
			t.expect(state.dealName).toContain(state.facts.company)
			t.expect(state.dealName).toContain("IPO of")
			t.expect(string.find(state.dealName, "%$[%d%.,]+[MB]") ~= nil).toBe(true)
		end)
		t.it("hides the client until it is picked", function()
			local state = ipo.new(Rng.new(6), CTX)
			local view = ipo.view(state, CTX)
			t.expect(view.dealName).toContain("mandate")
			for _, m in view.summary.metrics do
				if m.id == "client" or m.id == "value" or m.id == "range" or m.id == "offer" then
					t.expect(m.value).toBe("—")
				end
			end
		end)
		t.it("the filed range brackets the value per share", function()
			for seed = 1, 10 do
				local state = toPricing(seed)
				local f = state.facts
				t.expect(f.valueLo).toBeLessThan(f.perShare)
				t.expect(f.valueHi).toBeGreaterThan(f.valueLo)
				t.expect(f.floatPct).toBeGreaterThan(0)
				t.expect(f.sold).toBeLessThan(f.shares)
			end
		end)
	end)
end
