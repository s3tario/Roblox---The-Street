-- The big-deal registry and run lifecycle (Logic/Projects/_registry): availability by track and rank, run status,
-- reward maths (quality, rank, repeat runs, pulled deals), the start/act/abandon lifecycle ProjectService applies to
-- data.projects, the list cards and client view (never the answer key, always JSON-safe), the market mood, record
-- repair and the JSON-safety check itself.
local Shared = game:GetService("ReplicatedStorage").Shared
local Rng = require(Shared.Util.Rng)
local Solve = require(Shared.Logic.Tasks._shared.Solve)
local Registry = require(Shared.Logic.Projects._registry)
local sellside = require(Shared.Logic.Projects.ib_sellside)
local ipo = require(Shared.Logic.Projects.ipo)

local Runs = Registry.Runs
local NOW = 1790812800

local function career(rank: number, overrides: { [string]: any }?): { [string]: any }
	local c: { [string]: any } = {
		status = "active",
		track = "ib",
		rank = rank,
		level = 10 + rank * 12,
		companyId = "harrow_williams",
		roleId = "ib_role_" .. rank,
	}
	for k, v in overrides or {} do
		c[k] = v
	end
	return c
end

local function ctxFor(rank: number): { [string]: any }
	return { level = 10 + rank * 12, rank = rank, track = "ib", difficulty = 0.5, hints = 1, now = NOW }
end

local SECRET_KEYS =
	{ key = true, scores = true, best = true, target = true, credit = true, valid = true, secret = true }

local function hasSecret(v: any, depth: number, skipTop: { [string]: boolean }?): boolean
	if type(v) ~= "table" or depth > 10 then
		return false
	end
	for k, x in v do
		if type(k) == "string" and SECRET_KEYS[k] and not (skipTop and skipTop[k]) then
			return true
		end
		if hasSecret(x, depth + 1, nil) then
			return true
		end
	end
	return false
end

-- Plays a whole deal through Runs, perfectly or with k mistakes per stage.
local function playRun(mod: any, record: any, rank: number, k: number, now: number): any
	local ctx = ctxFor(rank)
	local completion = nil
	local guard = 0
	while Runs.isActive(record) do
		guard += 1
		assert(guard < 20, "run never finished")
		local answers = Solve.degrade(record.state.current.secret, k)
		local ok, err, _, c = Runs.act(mod, record, answers, ctx, now, record.state.stageIndex)
		assert(ok, "act failed: " .. tostring(err))
		completion = c
	end
	return completion
end

return function(t)
	t.describe("who", function()
		t.it("reads the career record", function()
			local student = Registry.who({ status = "student", rank = 0 })
			t.expect(student.employed).toBe(false)
			t.expect(student.student).toBe(true)
			local banker = Registry.who(career(2))
			t.expect(banker.employed).toBe(true)
			t.expect(banker.rank).toBe(2)
			t.expect(banker.track).toBe("ib")
			local fired = Registry.who(career(2, { status = "fired" }))
			t.expect(fired.employed).toBe(false)
			t.expect(fired.fired).toBe(true)
			t.expect(Registry.who(career(1, { roleId = "unemployed" })).employed).toBe(false)
			t.expect(Registry.who(nil).employed).toBe(false)
			t.expect(Registry.who({ rank = "x", level = math.huge }).rank).toBe(0)
		end)
	end)

	t.describe("availability by rank", function()
		t.it("the sell-side runs for Analysts and Associates, the IPO from VP up", function()
			for rank = 1, 5 do
				local who = Registry.who(career(rank))
				local okSell, sellReason = Registry.available(sellside, who)
				local okIpo, ipoReason, vars = Registry.available(ipo, who)
				t.expect(okSell).toBe(rank <= 2)
				t.expect(okIpo).toBe(rank >= 3)
				if rank > 2 then
					t.expect(sellReason).toBe("rank_high")
				end
				if rank < 3 then
					t.expect(ipoReason).toBe("rank_low")
					t.expect(vars and vars.rank).toBe(3)
					t.expect(type(vars and vars.title)).toBe("string")
				end
			end
		end)
		t.it("refuses students, fired players and other tracks", function()
			t.expect(select(2, Registry.available(ipo, Registry.who({ status = "student" })))).toBe("not_employed")
			t.expect(select(2, Registry.available(ipo, Registry.who(career(3, { status = "fired" })))))
				.toBe("not_employed")
			t.expect(select(2, Registry.available(ipo, Registry.who(career(3, { track = "st" }))))).toBe("wrong_track")
			t.expect(Registry.relevant(ipo, Registry.who(career(3, { track = "st" })))).toBe(false)
			t.expect(Registry.relevant(ipo, Registry.who(career(1)))).toBe(true)
		end)
		t.it("a gap in the rank list points at the next listed rank", function()
			local mod = table.clone(sellside)
			mod.ranks = { 1, 3 }
			local ok, reason, vars = Registry.available(mod, Registry.who(career(2)))
			t.expect(ok).toBe(false)
			t.expect(reason).toBe("rank_low")
			t.expect(vars and vars.rank).toBe(3)
		end)
		t.it("status follows the record: active, cooldown, locked, available", function()
			local who = Registry.who(career(1))
			local record = Registry.record(nil)
			t.expect(Registry.status(sellside, record, who, NOW).status).toBe("available")
			record.cooldownUntil = NOW + 90
			local cd = Registry.status(sellside, record, who, NOW)
			t.expect(cd.status).toBe("cooldown")
			t.expect(cd.cooldownLeft).toBe(90)
			t.expect(Registry.status(ipo, Registry.record(nil), who, NOW).status).toBe("locked")
			record.state = { done = false, stageIndex = 2, stageCount = 5 }
			local active = Registry.status(sellside, record, who, NOW)
			t.expect(active.status).toBe("active")
			t.expect(active.stageIndex).toBe(2)
		end)
	end)

	t.describe("rewards", function()
		t.it("scale with quality and rank", function()
			local lo = Registry.rewards(sellside, 40, 1)
			local hi = Registry.rewards(sellside, 95, 1)
			t.expect(hi.xp).toBeGreaterThan(lo.xp)
			t.expect(hi.pay).toBeGreaterThan(lo.pay)
			local r1 = Registry.rewards(ipo, 80, 3)
			local r5 = Registry.rewards(ipo, 80, 5)
			t.expect(r5.xp).toBeGreaterThan(r1.xp)
			t.expect(r5.pay).toBeGreaterThan(r1.pay)
			t.expect(Registry.rewards(ipo, 0, 3).xp).toBe(0)
			t.expect(Registry.qualityFactor(100)).toBe(1)
			t.expect(Registry.qualityFactor(-5)).toBe(0)
			t.expect(Registry.qualityFactor(10)).toBeLessThan(Registry.TUNING.participation)
		end)
		t.it("repeat runs and pulled deals pay less; only closed deals earn reputation", function()
			local first = Registry.rewards(ipo, 90, 3, { runs = 0, closed = true })
			local again = Registry.rewards(ipo, 90, 3, { runs = 2, closed = true })
			local pulled = Registry.rewards(ipo, 90, 3, { runs = 0, closed = false })
			t.expect(again.repeatRun).toBe(true)
			t.expect(again.xp).toBeLessThan(first.xp)
			t.expect(again.pay).toBeLessThan(first.pay)
			t.expect(pulled.pulled).toBe(true)
			t.expect(pulled.xp).toBeLessThan(first.xp)
			t.expect(pulled.rep).toBe(0)
			t.expect(first.rep).toBeGreaterThan(0)
		end)
		t.it("multipliers apply and stay bounded", function()
			local base = Registry.rewards(sellside, 80, 1)
			local boosted = Registry.rewards(sellside, 80, 1, { payMult = 1.5, eventMult = 2, xpMult = 1.25 })
			t.expect(boosted.pay).toBe(math.floor(base.pay * 3 + 0.5))
			t.expect(boosted.xp).toBeCloseTo(base.xp * 1.25, 1.01)
			local wild = Registry.rewards(sellside, 100, 99, { payMult = 1e9, eventMult = 0 / 0, xpMult = math.huge })
			t.expect(wild.pay).toBeLessThanOrEqual(Registry.TUNING.maxPay)
			t.expect(wild.xp).toBeLessThanOrEqual(Registry.TUNING.maxXp)
			t.expect(wild.xp == wild.xp).toBe(true)
		end)
	end)

	t.describe("run lifecycle", function()
		t.it("starts, plays and completes a deal, recording the run", function()
			local record = Registry.record(nil)
			local who = Registry.who(career(1))
			local ok, err, _, resumed = Runs.start(sellside, record, who, NOW, {
				seed = 42,
				ctx = ctxFor(1),
				activeCount = 0,
				companyId = "harrow_williams",
			})
			t.expect(err).toBeNil()
			t.expect(ok).toBe(true)
			t.expect(resumed).toBe(false)
			t.expect(record.attempts).toBe(1)
			t.expect(record.companyId).toBe("harrow_williams")
			t.expect(Runs.isActive(record)).toBe(true)
			-- starting again resumes the same run
			local again, _, _, resumedAgain = Runs.start(sellside, record, who, NOW + 5, { seed = 7, ctx = ctxFor(1) })
			t.expect(again).toBe(true)
			t.expect(resumedAgain).toBe(true)
			t.expect(record.attempts).toBe(1)
			local c = playRun(sellside, record, 1, 0, NOW + 60)
			t.expect(c).toBeTruthy()
			t.expect(c.closed).toBe(true)
			t.expect(c.quality).toBeGreaterThanOrEqual(85)
			t.expect(c.firstClose).toBe(true)
			t.expect(c.repeatRun).toBe(false)
			t.expect(record.runs).toBe(1)
			t.expect(record.closed).toBe(1)
			t.expect(record.best).toBe(c.quality)
			t.expect(#record.history).toBe(1)
			t.expect(record.history[1].name).toBe(c.dealName)
			t.expect(record.cooldownUntil).toBe(NOW + 60 + Registry.cooldownOf(sellside))
			t.expect(Runs.isActive(record)).toBe(false)
			t.expect(record.state.done).toBe(true)
			-- the finished state stays for the results story but can't be acted on
			local okAct, errAct = Runs.act(sellside, record, {}, ctxFor(1), NOW + 61)
			t.expect(okAct).toBe(false)
			t.expect(errAct).toBe("done")
			-- the cooldown blocks a new run, then a repeat run is flagged
			local okCd, errCd, vars = Runs.start(sellside, record, who, NOW + 61, { seed = 1, ctx = ctxFor(1) })
			t.expect(okCd).toBe(false)
			t.expect(errCd).toBe("cooldown")
			t.expect(type(vars and vars.time)).toBe("string")
			local later = record.cooldownUntil + 1
			t.expect((Runs.start(sellside, record, who, later, { seed = 2, ctx = ctxFor(1) }))).toBe(true)
			local c2 = playRun(sellside, record, 1, 1, later + 30)
			t.expect(c2.repeatRun).toBe(true)
			t.expect(c2.closedBefore).toBe(1)
			t.expect(record.runs).toBe(2)
		end)
		t.it("refuses a stale stage submission (double submit) without changing the run", function()
			local record = Registry.record(nil)
			Runs.start(ipo, record, Registry.who(career(3)), NOW, { seed = 5, ctx = ctxFor(3) })
			local answers = Solve.perfect(record.state.current.secret)
			t.expect((Runs.act(ipo, record, answers, ctxFor(3), NOW, 1))).toBe(true)
			local before = record.state.stageIndex
			local ok, err = Runs.act(ipo, record, answers, ctxFor(3), NOW, 1)
			t.expect(ok).toBe(false)
			t.expect(err).toBe("stale")
			t.expect(record.state.stageIndex).toBe(before)
		end)
		t.it("caps deals in progress and refuses locked deals", function()
			local record = Registry.record(nil)
			local ok, err, vars = Runs.start(
				sellside,
				record,
				Registry.who(career(1)),
				NOW,
				{ seed = 1, ctx = ctxFor(1), activeCount = 2 }
			)
			t.expect(ok).toBe(false)
			t.expect(err).toBe("too_many")
			t.expect(vars and vars.n).toBe(Registry.TUNING.maxActive)
			local okIpo, errIpo = Runs.start(ipo, record, Registry.who(career(1)), NOW, { seed = 1, ctx = ctxFor(1) })
			t.expect(okIpo).toBe(false)
			t.expect(errIpo).toBe("rank_low")
			t.expect(record.state).toBeNil()
			t.expect((Runs.start({ id = "nope" }, record, Registry.who(career(1)), NOW, { seed = 1 }))).toBe(false)
		end)
		t.it("abandoning drops the run and starts a short cooldown", function()
			local record = Registry.record(nil)
			Runs.start(sellside, record, Registry.who(career(2)), NOW, { seed = 3, ctx = ctxFor(2) })
			t.expect(Runs.abandon(record, NOW + 10)).toBe(true)
			t.expect(record.state).toBeNil()
			t.expect(record.abandoned).toBe(1)
			t.expect(record.cooldownUntil).toBe(NOW + 10 + Registry.TUNING.abandonCooldown)
			t.expect(Runs.abandon(record, NOW + 11)).toBe(false)
			-- a cancellation (fired) can skip the cooldown
			Runs.start(sellside, record, Registry.who(career(2)), NOW + 500, { seed = 4, ctx = ctxFor(2) })
			Runs.abandon(record, NOW + 501, 0)
			t.expect(record.cooldownUntil).toBeLessThanOrEqual(NOW + 501)
			t.expect(Registry.status(sellside, record, Registry.who(career(2)), NOW + 501).status).toBe("available")
		end)
		t.it("a module that throws resets the run instead of wedging it", function()
			local broken = table.clone(sellside)
			broken.act = function()
				error("boom")
			end
			local record = Registry.record(nil)
			Runs.start(broken, record, Registry.who(career(1)), NOW, { seed = 3, ctx = ctxFor(1) })
			local ok, err = Runs.act(broken, record, {}, ctxFor(1), NOW)
			t.expect(ok).toBe(false)
			t.expect(err).toBe("broken")
			t.expect(record.state).toBeNil()
		end)
		t.it("flags runs a newer module version can't continue", function()
			local record = Registry.record(nil)
			Runs.start(sellside, record, Registry.who(career(1)), NOW, { seed = 3, ctx = ctxFor(1) })
			t.expect(Runs.stale(sellside, record)).toBe(false)
			local bumped = table.clone(sellside)
			bumped.version = sellside.version + 1
			t.expect(Runs.stale(bumped, record)).toBe(true)
		end)
		t.it("lists active runs of known modules only", function()
			local projects = {
				ib_sellside = { state = { done = false } },
				ipo = { state = { done = true } },
				reentry = { state = { done = false } },
				gone = { state = { done = false } },
			}
			local ids = Runs.activeIds(projects, { ib_sellside = sellside, ipo = ipo })
			t.expect(#ids).toBe(1)
			t.expect(ids[1]).toBe("ib_sellside")
		end)
	end)

	t.describe("cards and views", function()
		t.it(
			"lists the player's track deals with status, best score and estimates, JSON-safe and secret-free",
			function()
				local who = Registry.who(career(2))
				local projects: { [string]: any } = {}
				projects.ib_sellside = Registry.record(nil)
				Runs.start(sellside, projects.ib_sellside, who, NOW, { seed = 9, ctx = ctxFor(2) })
				local cards = Runs.list({ ipo, sellside }, projects, who, NOW, { payMult = 1.2 })
				t.expect(#cards).toBe(2)
				t.expect(cards[1].id).toBe("ib_sellside")
				t.expect(cards[1].status).toBe("active")
				t.expect(cards[1].stageIndex).toBe(1)
				t.expect(type(cards[1].dealName)).toBe("string")
				t.expect(cards[2].id).toBe("ipo")
				t.expect(cards[2].status).toBe("locked")
				t.expect(cards[2].reason).toBe("rank_low")
				t.expect(cards[2].signature).toBe(true)
				t.expect(cards[2].rankLo).toBe(3)
				t.expect(cards[2].rankHi).toBe(5)
				t.expect(cards[1].estimateXp).toBeGreaterThan(0)
				t.expect(cards[1].estimatePay).toBeGreaterThan(0)
				t.expect(#cards[1].stages).toBe(#sellside.stages)
				t.expect(#cards[1].stages[1].stats).toBeGreaterThan(0)
				local ok, err = Registry.plain(cards)
				t.expect(err).toBeNil()
				t.expect(ok).toBe(true)
				for _, card in cards do
					-- "best" is the player's best score here, not an answer key
					t.expect(hasSecret(card, 1, { best = true })).toBe(false)
				end
				-- other tracks and students see nothing
				t.expect(#Runs.list({ ipo, sellside }, {}, Registry.who(career(2, { track = "st" })), NOW)).toBe(0)
				t.expect(#Runs.list({ ipo, sellside }, {}, Registry.who({ status = "student" }), NOW)).toBe(0)
			end
		)
		t.it("the client view carries the payload but never the answer key, and the rewards once done", function()
			local record = Registry.record(nil)
			Runs.start(ipo, record, Registry.who(career(3)), NOW, { seed = 11, ctx = ctxFor(3) })
			local v = Runs.publicView(ipo, record, ctxFor(3))
			t.expect(v).toBeTruthy()
			local view = v :: any
			t.expect(view.payload.kind).toBe("mcq")
			t.expect(view.done).toBe(false)
			t.expect(hasSecret(view, 1, nil)).toBe(false)
			t.expect((Registry.plain(view))).toBe(true)
			playRun(ipo, record, 3, 0, NOW + 30)
			record.lastRewards = { xp = 500, pay = 9000, rep = 4 }
			local done = Runs.publicView(ipo, record, ctxFor(3)) :: any
			t.expect(done.done).toBe(true)
			t.expect(done.payload).toBeNil()
			t.expect(done.outcome.closed).toBe(true)
			t.expect(done.rewards.xp).toBe(500)
			t.expect(hasSecret(done, 1, nil)).toBe(false)
			t.expect(Runs.publicView(ipo, Registry.record(nil), ctxFor(3))).toBeNil()
		end)
	end)

	t.describe("helpers", function()
		t.it("market mood follows market events, the benchmark and IPO Frenzy, clamped", function()
			t.expect(Registry.marketMood(nil)).toBe(1)
			t.expect(Registry.marketMood({ event = "boom" })).toBeGreaterThan(1.1)
			t.expect(Registry.marketMood({ event = "crash" })).toBeLessThan(0.9)
			t.expect(Registry.marketMood({ dayChange = 0.02 })).toBe(1.06)
			t.expect(Registry.marketMood({ dayChange = -0.5 })).toBe(0.94)
			t.expect(Registry.marketMood({ ipoFrenzy = true })).toBe(1.08)
			t.expect(Registry.marketMood({ event = "boom", dayChange = 1, ipoFrenzy = true })).toBe(1.2)
			t.expect(Registry.marketMood({ event = "crash", dayChange = -1 })).toBe(0.8)
		end)
		t.it("repairs a damaged record in place", function()
			local raw: any =
				{ runs = "lots", best = 0 / 0, history = 5, state = "nope", companyId = 7, cooldownUntil = "x" }
			local r = Registry.record(raw)
			t.expect(r).toBe(raw)
			t.expect(r.runs).toBe(0)
			t.expect(r.best).toBe(0)
			t.expect(type(r.history)).toBe("table")
			t.expect(r.state).toBeNil()
			t.expect(r.companyId).toBeNil()
			t.expect(r.cooldownUntil).toBe(0)
		end)
		t.it("the JSON-safety check catches what DataStores would mangle", function()
			t.expect((Registry.plain({ a = 1, b = { 1, 2, 3 }, c = "x", d = true }))).toBe(true)
			t.expect((Registry.plain({ 1, 2, x = 3 }))).toBe(false)
			t.expect((Registry.plain({ [1] = 1, [3] = 3 }))).toBe(false)
			t.expect((Registry.plain({ a = 0 / 0 }))).toBe(false)
			t.expect((Registry.plain({ a = math.huge }))).toBe(false)
			t.expect((Registry.plain({ a = function() end }))).toBe(false)
			t.expect((Registry.plain(setmetatable({}, {})))).toBe(false)
			t.expect((Registry.plain({ [true] = 1 } :: any))).toBe(false)
		end)
		t.it("checks the module contract", function()
			t.expect((Registry.check(nil))).toBe(false)
			t.expect((Registry.check({ id = "bad id", title = "x" }))).toBe(false)
			local noAct = table.clone(sellside)
			noAct.act = nil
			t.expect((Registry.check(noAct))).toBe(false)
			local badRanks = table.clone(sellside)
			badRanks.ranks = { 0.5 }
			t.expect((Registry.check(badRanks))).toBe(false)
			t.expect(Registry.listed({ id = "reentry" })).toBe(false)
		end)
		t.it("stage stats come from the stage, then the deal", function()
			t.expect(table.concat(Registry.stageStats(sellside, "cim"), ",")).toBe("discipline,skill")
			t.expect(#Registry.stageStats(sellside, "nope")).toBe(#sellside.stats)
			t.expect(Registry.statLabel("risk")).toBe("Risk Sense")
		end)
		t.it("formats time and fills text", function()
			t.expect(Registry.timeText(45)).toBe("45s")
			t.expect(Registry.timeText(245)).toBe("4m 05s")
			t.expect(Registry.timeText(3725)).toBe("1h 02m")
			t.expect(Registry.text("card_stages", { n = 5 })).toBe("5 stages")
			t.expect(Registry.text("no_such_key")).toBe("no_such_key")
			t.expect(Registry.text("err_rank_low", {})).toContain("{title}")
		end)
	end)
end
