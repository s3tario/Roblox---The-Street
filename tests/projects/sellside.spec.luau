-- ib_sellside mechanics: the process drives the sale price against the seller's reserve; a bidder who can't close
-- costs money in the outcome (re-trade or stock slide) unless a backup bidder was kept warm; the deal name and
-- results story read like a real tombstone.
local Shared = game:GetService("ReplicatedStorage").Shared
local Rng = require(Shared.Util.Rng)
local Solve = require(Shared.Logic.Tasks._shared.Solve)
local sellside = require(Shared.Logic.Projects.ib_sellside)

local CTX = { level = 22, rank = 1, track = "ib", difficulty = 0.3, hints = 1, now = 1790812800, marketMood = 1 }

-- Plays stages 1-3 perfectly and stops at the bid round.
local function toBids(seed: number): any
	local state = sellside.new(Rng.new(seed), CTX)
	for _ = 1, 3 do
		state = sellside.act(state, Solve.perfect(state.current.secret), CTX)
	end
	assert(state.current.id == "bids", "expected the bid round")
	return state
end

-- Perfect bid-round answers, with the lead swapped to `kind` and the backup answer chosen.
local function bidAnswers(state: any, kind: string, keepBackup: boolean): any
	local answers = Solve.perfect(state.current.secret)
	local meta = state.current.meta
	for i, k in meta.leadKinds do
		if k == kind then
			answers[2].q_lead = i
		end
	end
	if not keepBackup then
		answers[2].q_backup = if meta.backupKey == 1 then 2 else 1
	end
	return answers
end

local function finishPerfect(state: any): any
	while not state.done do
		state = sellside.act(state, Solve.perfect(state.current.secret), CTX)
	end
	return state
end

return function(t)
	t.describe("scenario", function()
		t.it("is a founder-owned company with numbers that tie", function()
			for seed = 1, 20 do
				local f = sellside.facts(sellside.new(Rng.new(seed), CTX)) :: any
				t.expect(f.ebitda).toBeGreaterThan(0)
				t.expect(math.abs(f.ebitda / f.rev * 100 - f.margin)).toBeLessThanOrEqual(0.6)
				t.expect(math.abs((f.rev / f.prevRev - 1) * 100 - f.growth)).toBeLessThanOrEqual(0.6)
				t.expect(f.reserve).toBeLessThanOrEqual(f.fairEv)
				t.expect(f.reported + f.addback).toBe(f.ebitda)
				t.expect(#f.longList).toBe(5)
				local names = {}
				for _, b in f.longList do
					t.expect(names[b.name]).toBeNil()
					names[b.name] = true
				end
				t.expect(names[f.company]).toBeNil()
			end
		end)
		t.it("uses the player's firm in the documents when it is known", function()
			local mine = table.clone(CTX) :: any
			mine.companyName = "Harrow Williams"
			local state = sellside.new(Rng.new(3), mine)
			t.expect((sellside.facts(state) :: any).firm).toBe("Harrow Williams")
			local cim = sellside.new(Rng.new(3), mine)
			cim = sellside.act(cim, Solve.perfect(cim.current.secret), mine)
			local text = {}
			for _, el in cim.current.payload.elements do
				table.insert(text, el.text)
			end
			t.expect(table.concat(text, " ")).toContain("Harrow")
			-- without a known firm the documents still name a fictional bank
			local generic = sellside.facts(sellside.new(Rng.new(3), CTX)) :: any
			t.expect(type(generic.firm)).toBe("string")
			t.expect(#generic.firm).toBeGreaterThan(0)
		end)
	end)

	t.describe("bid round", function()
		t.it(
			"ranks the headlines trap > stock > clean > family, so the right answer isn't the biggest number",
			function()
				for seed = 1, 15 do
					local state = toBids(seed)
					state = sellside.act(state, Solve.perfect(state.current.secret), CTX)
					local f = sellside.facts(state) :: any
					local ev = {}
					for _, b in f.bids do
						ev[b.kind] = b.ev
					end
					t.expect(ev.trap).toBeGreaterThan(ev.stock)
					t.expect(ev.stock).toBeGreaterThan(ev.clean)
					t.expect(ev.clean).toBeGreaterThan(ev.family)
					t.expect(f.winner).toBe("clean")
					t.expect(f.backupWarm).toBe(true)
				end
			end
		)
		t.it("a trap bid with no backup re-trades the price down", function()
			local clean = finishPerfect(toBids(4))
			local state = toBids(4)
			state = sellside.act(state, bidAnswers(state, "trap", false), CTX)
			local f = sellside.facts(state) :: any
			t.expect(f.winner).toBe("trap")
			t.expect(f.backupWarm).toBe(false)
			state = finishPerfect(state)
			t.expect(state.outcome.data.price).toBeLessThan(clean.outcome.data.price)
			t.expect(state.quality).toBeLessThan(clean.quality)
			t.expect(table.concat(state.outcome.lines, " ")).toContain("re-traded")
		end)
		t.it("a warm backup rescues a trap bid", function()
			local cut = toBids(6)
			cut = finishPerfect(sellside.act(cut, bidAnswers(cut, "trap", false), CTX))
			local pivot = toBids(6)
			pivot = finishPerfect(sellside.act(pivot, bidAnswers(pivot, "trap", true), CTX))
			t.expect(pivot.outcome.data.price).toBeGreaterThan(cut.outcome.data.price)
			t.expect(table.concat(pivot.outcome.lines, " ")).toContain("backup bidder")
			t.expect(pivot.outcome.data.buyer).never(pivot.outcome.data.winner)
		end)
		t.it("a stock offer loses value as the bidder's shares slide", function()
			local state = toBids(8)
			state = finishPerfect(sellside.act(state, bidAnswers(state, "stock", true), CTX))
			t.expect(table.concat(state.outcome.lines, " ")).toContain("shares kept falling")
		end)
	end)

	t.describe("outcome", function()
		t.it("perfect play sells well above the reserve; reckless play falls short", function()
			for seed = 1, 10 do
				local good = finishPerfect(sellside.new(Rng.new(seed), CTX))
				t.expect(good.outcome.closed).toBe(true)
				t.expect(good.outcome.data.ratio).toBeGreaterThanOrEqual(1.15)
				local bad = sellside.new(Rng.new(seed), CTX)
				while not bad.done do
					bad = sellside.act(bad, Solve.degrade(bad.current.secret, 99), CTX)
				end
				t.expect(bad.outcome.data.ratio).toBeLessThan(0.95)
				t.expect(bad.outcome.closed).toBe(false)
			end
		end)
		t.it("names the plaque after the codename, price and company", function()
			local state = finishPerfect(sellside.new(Rng.new(2), CTX))
			local f = sellside.facts(state) :: any
			t.expect(state.dealName).toContain(f.codename)
			t.expect(state.dealName).toContain(f.company)
			t.expect(state.dealName).toContain("sale of")
			t.expect(string.find(state.dealName, "%$[%d%.,]+[MB]") ~= nil).toBe(true)
			t.expect(sellside.score(state).metrics.dealName).toBe(state.dealName)
		end)
		t.it("a pulled deal says so in its name", function()
			local state = sellside.new(Rng.new(2), CTX)
			while not state.done do
				state = sellside.act(state, nil, CTX)
			end
			t.expect(state.outcome.closed).toBe(false)
			t.expect(state.dealName).toContain("(pulled)")
		end)
		t.it("the running summary never shows the lead before the bid round", function()
			local state = sellside.new(Rng.new(5), CTX)
			local view = sellside.view(state, CTX)
			for _, m in view.summary.metrics do
				if m.id == "lead" or m.id == "buyers" or m.id == "confidence" then
					t.expect(m.value).toBe("—")
				end
			end
		end)
	end)
end
