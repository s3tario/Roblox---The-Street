-- Work task modules (contracts §8): every M1 module, over 50 seeds x 3 difficulties, builds a valid payload; perfect
-- answers score >= 95; garbage scores low without errors; generation is deterministic; partial credit falls
-- monotonically as more items go wrong; feedback is specific; module fields are well formed.
local Shared = game:GetService("ReplicatedStorage").Shared
local Rng = require(Shared.Util.Rng)
local Config = require(Shared.Config.Tasks)
local TasksFolder = Shared.Logic.Tasks
local Kinds = require(TasksFolder._shared.Kinds)
local Solve = require(TasksFolder._shared.Solve)
local TableUtil = require(Shared.Util.TableUtil)

local STUDENT = {
	"academics_problem_set",
	"finance_club_quiz",
	"mock_stock_pitch",
	"networking_chat",
	"coffee_chat",
	"mock_interview",
	"superday_interview",
	"interview_ib",
}
local IB = {
	"pitchbook_format",
	"comps_analysis",
	"dcf_build",
	"data_cleanup",
	"earnings_reaction",
	"deal_process",
	"review_analyst_output",
	"merger_model_check",
	"client_memo_ib",
	"deadline_triage",
	"buyer_qa",
	"mandate_pitch",
	"fee_negotiation",
	"coverage_call",
	"staffing_review",
}
local OTHER = { "reentry_case_study" }

local ALL: { string } = {}
for _, list in { STUDENT, IB, OTHER } do
	for _, id in list do
		table.insert(ALL, id)
	end
end

local STAT_IDS = {
	knowledge = true,
	skill = true,
	speed = true,
	charisma = true,
	network = true,
	discipline = true,
	risk = true,
	luck = true,
}
local DIFFICULTIES = { 0.1, 0.5, 0.9 }
local SEEDS = 50

local function load(id: string): any
	local inst = TasksFolder:FindFirstChild(id)
	assert(inst, "missing task module " .. id)
	return require(inst)
end

local function ctxFor(difficulty: number, extra: { [string]: any }?): { [string]: any }
	local c: { [string]: any } = {
		level = 12,
		rank = 1,
		track = "ib",
		difficulty = difficulty,
		hints = 2,
		toleranceMult = 1,
		charismaBonus = 0,
		stats = { knowledge = 60, skill = 50, speed = 50, charisma = 50 },
		now = 1792000000,
		offer = { companyName = "MG Freeman", companyId = "mg_freeman" },
	}
	if extra then
		for k, v in extra do
			c[k] = v
		end
	end
	return c
end

local GARBAGE: { any } = {
	nil,
	"garbage",
	42,
	true,
	{},
	{ 1, 2, 3 },
	{ "x", "y" },
	{ q1 = "seven", a = { 1, 2 }, [1] = { [1] = "?" } },
	{ { row = "a", col = {} }, { 999, 999 } },
}

return function(t)
	t.describe("module shape", function()
		for _, id in ALL do
			t.it(id .. " declares the contract fields", function()
				local mod = load(id)
				t.expect(mod.id).toBe(id)
				t.expect(type(mod.title) == "string" and #mod.title > 0).toBeTruthy()
				t.expect(type(mod.desc) == "string" and #mod.desc > 0).toBeTruthy()
				t.expect(Config.categories[mod.category] ~= nil).toBeTruthy()
				t.expect(type(mod.stats) == "table" and #mod.stats >= 1).toBeTruthy()
				for _, s in mod.stats do
					t.expect(STAT_IDS[s]).toBe(true)
				end
				t.expect(mod.timeLimit).toBeBetween(30, 900)
				t.expect(mod.baseXp).toBeBetween(10, 400)
				t.expect(mod.basePay).toBeBetween(0, 5000)
				t.expect(mod.cooldown).toBeGreaterThanOrEqual(0)
				t.expect(type(mod.generate)).toBe("function")
				t.expect(type(mod.grade)).toBe("function")
				t.expect(type(mod.clientFacing)).toBe("boolean")
				t.expect(Config.kinds[mod.kind] ~= nil).toBeTruthy()
			end)
		end
		t.it("student modules are student-only and IB modules declare tracks = {ib} and ranks within 1-5", function()
			for _, id in STUDENT do
				local mod = load(id)
				t.expect(mod.student == true or mod.offerOnly == true).toBeTruthy()
				t.expect(mod.tracks).toBeNil()
			end
			for _, id in IB do
				local mod = load(id)
				t.expect(mod.tracks).toEqual({ "ib" })
				t.expect(type(mod.ranks) == "table" and #mod.ranks >= 1).toBeTruthy()
				for _, r in mod.ranks do
					t.expect(r).toBeBetween(1, 5)
				end
				t.expect(mod.student).toBeFalsy()
			end
		end)
		t.it("every IB rank 1-5 has at least three tasks and at least one core task", function()
			for rank = 1, 5 do
				local n, core = 0, 0
				for _, id in IB do
					local mod = load(id)
					if table.find(mod.ranks, rank) then
						n += 1
						if mod.core then
							core += 1
						end
					end
				end
				t.expect(n).toBeGreaterThanOrEqual(3)
				t.expect(core).toBeGreaterThanOrEqual(1)
			end
		end)
		t.it("re-entry stages can use the work modules (mcq case study, dialogue interview)", function()
			local case = load("reentry_case_study")
			local p = case.generate(Rng.new(3), { difficulty = 0.4, hints = 1 })
			t.expect(p.kind).toBe("mcq")
			local interview = load("mock_interview")
			local q = interview.generate(Rng.new(3), { difficulty = 0.4, hints = 1 })
			t.expect(q.kind).toBe("dialogue")
		end)
	end)

	t.describe("payloads and grading", function()
		for _, id in ALL do
			t.it(id .. ": valid payloads, perfect >= 95, garbage low (50 seeds x 3 difficulties)", function()
				local mod = load(id)
				for _, d in DIFFICULTIES do
					for seed = 1, SEEDS do
						local ctx = ctxFor(d)
						local payload, secret = mod.generate(Rng.new(seed * 7919 + math.floor(d * 100)), ctx)
						local ok, err = Kinds.validate(payload)
						if not ok then
							error(("%s seed %d diff %.1f: %s"):format(id, seed, d, tostring(err)))
						end
						t.expect(payload.kind).toBe(mod.kind)
						t.expect(Kinds.plain(secret)).toBe(true)
						local perfect = mod.grade(secret, Solve.perfect(secret), ctx)
						if perfect.quality < 95 then
							error(
								("%s seed %d diff %.1f: perfect scored %s (%s)"):format(
									id,
									seed,
									d,
									tostring(perfect.quality),
									table.concat(perfect.feedback, " / ")
								)
							)
						end
						t.expect(perfect.correct).toBeLessThanOrEqual(perfect.total)
						t.expect(perfect.total).toBeGreaterThan(0)
						for gi, g in GARBAGE do
							local r = mod.grade(secret, g, ctx)
							if r.quality > 15 then
								error(("%s seed %d: garbage #%d scored %d"):format(id, seed, gi, r.quality))
							end
							t.expect(type(r.feedback) == "table" and #r.feedback >= 1).toBeTruthy()
						end
					end
				end
			end)
		end
	end)

	t.describe("determinism and variety", function()
		for _, id in ALL do
			t.it(id .. ": same seed -> same payload and secret; different seeds vary", function()
				local mod = load(id)
				local ctx = ctxFor(0.5)
				local p1, s1 = mod.generate(Rng.new(1234), ctx)
				local p2, s2 = mod.generate(Rng.new(1234), ctx)
				t.expect(TableUtil.deepEqual(p1, p2)).toBe(true)
				t.expect(TableUtil.deepEqual(s1, s2)).toBe(true)
				local distinct = 0
				for seed = 1, 12 do
					local p = mod.generate(Rng.new(seed), ctx)
					if not TableUtil.deepEqual(p, p1) then
						distinct += 1
					end
				end
				t.expect(distinct).toBeGreaterThanOrEqual(10)
			end)
		end
	end)

	t.describe("partial credit", function()
		for _, id in ALL do
			t.it(
				id .. ": quality never rises as more items go wrong, and an all-wrong attempt is well below perfect",
				function()
					local mod = load(id)
					for seed = 1, 20 do
						local ctx = ctxFor(0.5 + (seed % 3) * 0.2)
						local _, secret = mod.generate(Rng.new(seed * 31), ctx)
						local n = Solve.items(secret)
						t.expect(n).toBeGreaterThan(0)
						local prev = mod.grade(secret, Solve.perfect(secret), ctx).quality
						for k = 1, n do
							local q = mod.grade(secret, Solve.degrade(secret, k), ctx).quality
							if q > prev then
								error(("%s seed %d: k=%d scored %d > %d"):format(id, seed, k, q, prev))
							end
							prev = q
						end
						t.expect(prev).toBeLessThan(60)
					end
				end
			)
		end
		t.it("one wrong item earns partial (not zero, not full) credit", function()
			for _, id in ALL do
				local mod = load(id)
				local _, secret = mod.generate(Rng.new(77), ctxFor(0.9))
				local q = mod.grade(secret, Solve.degrade(secret, 1), ctxFor(0.9)).quality
				t.expect(q).toBeBetween(20, 99)
			end
		end)
	end)

	t.describe("feedback", function()
		t.it("misses produce specific notes beyond the summary line", function()
			for _, id in ALL do
				local mod = load(id)
				local _, secret = mod.generate(Rng.new(5), ctxFor(0.6))
				local r = mod.grade(secret, Solve.degrade(secret, 2), ctxFor(0.6))
				if #r.feedback < 2 then
					error(id .. " gave no specific feedback for two misses")
				end
				for _, line in r.feedback do
					t.expect(type(line) == "string" and #line > 3).toBeTruthy()
					t.expect(string.find(line, "{", 1, true)).toBeNil()
				end
			end
		end)
		t.it("hints appear only when ctx.hints > 0 and never exceed ctx.hints", function()
			for _, id in ALL do
				local mod = load(id)
				local none = mod.generate(Rng.new(9), ctxFor(0.5, { hints = 0 }))
				t.expect(none.hints == nil or #none.hints == 0).toBeTruthy()
				local some = mod.generate(Rng.new(9), ctxFor(0.5, { hints = 2 }))
				t.expect(type(some.hints) == "table" and #some.hints >= 1 and #some.hints <= 2).toBeTruthy()
			end
		end)
		t.it("modules tolerate an empty ctx (re-entry and other callers)", function()
			for _, id in ALL do
				local mod = load(id)
				local p, s = mod.generate(Rng.new(1), {})
				t.expect((Kinds.validate(p))).toBe(true)
				t.expect(mod.grade(s, Solve.perfect(s), nil).quality).toBeGreaterThanOrEqual(95)
			end
		end)
	end)
end
