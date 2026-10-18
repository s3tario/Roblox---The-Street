-- Work board (Logic/Tasks/_shared/Board) and module catalog (Catalog): who sees what, daily draws, carry-over of
-- core work, offered tasks, cooldowns and the workday key.
local Shared = game:GetService("ReplicatedStorage").Shared
local Rng = require(Shared.Util.Rng)
local TasksFolder = Shared.Logic.Tasks
local Board = require(TasksFolder._shared.Board)
local Catalog = require(TasksFolder._shared.Catalog)
local Config = require(Shared.Config.Tasks)

local function allModules(): ({ any }, { [string]: any })
	local list: { any } = {}
	local byId: { [string]: any } = {}
	for _, child in TasksFolder:GetChildren() do
		local name = child.Name
		if string.sub(name, 1, 1) ~= "_" then
			local mod = require(child)
			table.insert(list, mod)
			byId[mod.id] = mod
		end
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list, byId
end

local MODS, BY_ID = allModules()
local INFOS: { any } = {}
for _, m in MODS do
	table.insert(INFOS, Catalog.info(m))
end

local STUDENT = { status = "student", roleId = "student", rank = 0, track = "", level = 3 }
local function ib(rank: number, level: number?): any
	return {
		status = "active",
		roleId = "ib_rank" .. rank,
		rank = rank,
		track = "ib",
		level = level or (9 + rank * 10),
		week = 3,
		weekActive = 0,
	}
end
local FIRED = { status = "fired", roleId = "unemployed", rank = 2, track = "ib", level = 30 }

local function build(career: any, seed: number, prev: any?, cooldowns: any?, now: number?): any
	local who = Board.who(career)
	local key, day = Board.dayKey(who, career, 0)
	return Board.build(prev, INFOS, who, key, day, Rng.new(seed), cooldowns or {}, now or 1000)
end

return function(t)
	t.describe("catalog", function()
		t.it("every shipped module passes the contract check", function()
			for _, child in TasksFolder:GetChildren() do
				if string.sub(child.Name, 1, 1) ~= "_" then
					local ok, err = Catalog.check(require(child), child.Name)
					if not ok then
						error(child.Name .. ": " .. tostring(err))
					end
				end
			end
		end)
		t.it("rejects malformed modules with a reason", function()
			local good = BY_ID.finance_club_quiz
			t.expect((Catalog.check(nil))).toBe(false)
			t.expect((Catalog.check({}))).toBe(false)
			t.expect((Catalog.check(good, "other_name"))).toBe(false)
			local bad = table.clone(good)
			bad.stats = { "strength" }
			t.expect((Catalog.check(bad, bad.id))).toBe(false)
			bad = table.clone(good)
			bad.category = "nope"
			t.expect((Catalog.check(bad, bad.id))).toBe(false)
			bad = table.clone(good)
			bad.timeLimit = 0 / 0
			t.expect((Catalog.check(bad, bad.id))).toBe(false)
			bad = table.clone(good)
			bad.ranks = { 1.5 }
			t.expect((Catalog.check(bad, bad.id))).toBe(false)
			t.expect((Catalog.check(good, good.id))).toBe(true)
		end)
		t.it("summaries carry card data only", function()
			local s = Catalog.summary(BY_ID.comps_analysis)
			t.expect(s.id).toBe("comps_analysis")
			t.expect(s.kind).toBe("fill")
			t.expect(rawget(s :: any, "generate")).toBeNil()
			t.expect(rawget(s :: any, "grade")).toBeNil()
		end)
	end)

	t.describe("who and eligibility", function()
		t.it("reads students, employees and players between jobs", function()
			local s = Board.who(STUDENT)
			t.expect(s.student).toBe(true)
			t.expect(s.rank).toBe(0)
			t.expect(s.track).toBeNil()
			local e = Board.who(ib(2))
			t.expect(e.student).toBe(false)
			t.expect(e.track).toBe("ib")
			t.expect(e.rank).toBe(2)
			local f = Board.who(FIRED)
			t.expect(f.unemployed).toBe(true)
			t.expect(f.student).toBe(false)
			local junk = Board.who(nil)
			t.expect(junk.student).toBe(true)
		end)
		t.it("students see campus work only, never offer-only interviews", function()
			local who = Board.who(STUDENT)
			for _, info in INFOS do
				local mod = BY_ID[info.id]
				local expected = mod.student == true and mod.offerOnly ~= true
				t.expect(Board.eligible(info, who)).toBe(expected)
			end
			t.expect(Board.eligible(Catalog.info(BY_ID.interview_ib), who)).toBe(false)
			t.expect(Board.eligible(Catalog.info(BY_ID.academics_problem_set), who)).toBe(true)
		end)
		t.it("IB employees see their rank's IB tasks and no campus tasks", function()
			for rank = 1, 5 do
				local who = Board.who(ib(rank))
				local n = 0
				for _, info in INFOS do
					local mod = BY_ID[info.id]
					local ok = Board.eligible(info, who)
					local expected = mod.tracks ~= nil
						and table.find(mod.tracks, "ib") ~= nil
						and table.find(mod.ranks, rank) ~= nil
					t.expect(ok).toBe(expected)
					if ok then
						n += 1
					end
				end
				t.expect(n).toBeGreaterThanOrEqual(3)
			end
			local analyst = Board.who(ib(1))
			t.expect(Board.eligible(Catalog.info(BY_ID.data_cleanup), analyst)).toBe(true)
			t.expect(Board.eligible(Catalog.info(BY_ID.mandate_pitch), analyst)).toBe(false)
			local md = Board.who(ib(5))
			t.expect(Board.eligible(Catalog.info(BY_ID.fee_negotiation), md)).toBe(true)
			t.expect(Board.eligible(Catalog.info(BY_ID.pitchbook_format), md)).toBe(false)
		end)
		t.it("another track sees none of the IB tasks", function()
			local who = Board.who({ status = "active", roleId = "st_analyst", rank = 1, track = "st", level = 10 })
			for _, info in INFOS do
				t.expect(Board.eligible(info, who)).toBe(false)
			end
		end)
		t.it("players between jobs see the practice and re-entry tasks", function()
			local who = Board.who(FIRED)
			local ids: { string } = {}
			for _, info in INFOS do
				if Board.eligible(info, who) then
					table.insert(ids, info.id)
				end
			end
			t.expect(table.find(ids, "reentry_case_study") ~= nil).toBeTruthy()
			t.expect(table.find(ids, "comps_analysis")).toBeNil()
		end)
	end)

	t.describe("daily board", function()
		t.it("draws 3-5 distinct eligible tasks with at least one core, for every role", function()
			for _, career in { STUDENT, ib(1), ib(2), ib(3), ib(4), ib(5) } do
				local who = Board.who(career)
				for seed = 1, 40 do
					local b = build(career, seed)
					t.expect(#b.tasks).toBeBetween(Config.board.minTasks, Config.board.maxTasks)
					local seen: { [string]: boolean } = {}
					local core = 0
					for _, e in b.tasks do
						t.expect(seen[e.id]).toBeNil()
						seen[e.id] = true
						t.expect(Board.eligible(Catalog.info(BY_ID[e.id]), who)).toBe(true)
						if e.core then
							core += 1
						end
					end
					t.expect(core).toBeBetween(1, Config.board.maxCore)
				end
			end
		end)
		t.it("is deterministic for the same seed", function()
			local a = build(ib(2), 99)
			local b = build(ib(2), 99)
			t.expect(#a.tasks).toBe(#b.tasks)
			for i, e in a.tasks do
				t.expect(b.tasks[i].id).toBe(e.id)
			end
		end)
		t.it("keeps unfinished core tasks and offered tasks; finished ones roll off", function()
			local first = build(ib(1), 5)
			local coreEntry: any = nil
			for _, e in first.tasks do
				if e.core then
					coreEntry = e
					break
				end
			end
			t.expect(coreEntry ~= nil).toBeTruthy()
			Board.offer(
				first,
				"interview_ib",
				{ source = "recruiting", data = { companyId = "mg_freeman" }, ttl = 600 },
				1000
			)
			local doneId: string? = nil
			for _, e in first.tasks do
				if not e.core and not e.offered then
					doneId = e.id
					Board.complete(first, e.id, 80, 1001)
					break
				end
			end
			local second = build(ib(1), 6, first, {}, 1100)
			t.expect(Board.find(second, coreEntry.id) ~= nil).toBeTruthy()
			t.expect(Board.find(second, coreEntry.id).carried).toBe(true)
			local offered = Board.find(second, "interview_ib")
			t.expect(offered ~= nil and offered.offered == true).toBeTruthy()
			t.expect(offered.data.companyId).toBe("mg_freeman")
			if doneId then
				local again = Board.find(second, doneId)
				t.expect(again == nil or again.done == false).toBeTruthy()
			end
		end)
		t.it("drops carried core tasks that no longer fit the role (promotion)", function()
			local analyst = build(ib(1), 11)
			local promoted = build(ib(3), 12, analyst, {}, 2000)
			local who = Board.who(ib(3))
			for _, e in promoted.tasks do
				if not e.offered then
					t.expect(Board.eligible(Catalog.info(BY_ID[e.id]), who)).toBe(true)
				end
			end
		end)
		t.it("prefers tasks off cooldown but never leaves the board short", function()
			local who = Board.who(STUDENT)
			local cooling: { [string]: number } = {}
			local eligible = 0
			for _, info in INFOS do
				if Board.eligible(info, who) then
					eligible += 1
					cooling[info.id] = 5000
				end
			end
			cooling.networking_chat = nil
			local b = build(STUDENT, 3, nil, cooling, 1000)
			t.expect(#b.tasks).toBeGreaterThanOrEqual(math.min(eligible, Config.board.minTasks))
			local hasFree = Board.find(b, "networking_chat") ~= nil
			t.expect(hasFree).toBe(true)
		end)
	end)

	t.describe("offers", function()
		t.it("adds offered entries at the top, refreshes duplicates and caps the count", function()
			local b = build(STUDENT, 1)
			local e =
				Board.offer(b, "interview_ib", { source = "recruiting", data = { companyId = "a" }, ttl = 60 }, 100)
			t.expect(b.tasks[1]).toBe(e)
			t.expect(e.expiresAt).toBe(160)
			local again = Board.offer(b, "interview_ib", { data = { companyId = "b" }, ttl = 120 }, 110)
			t.expect(again).toBe(e)
			t.expect(e.data.companyId).toBe("b")
			t.expect(e.expiresAt).toBe(230)
			for i = 1, 10 do
				Board.offer(b, "x_task_" .. i, { ttl = 60 }, 120 + i)
			end
			local offered = 0
			for _, x in b.tasks do
				if x.offered then
					offered += 1
				end
			end
			t.expect(offered).toBe(Config.board.maxOffered)
		end)
		t.it("prunes expired offers but keeps finished ones until the day rolls", function()
			local b = build(STUDENT, 2)
			Board.offer(b, "interview_ib", { ttl = 50 }, 100)
			Board.offer(b, "superday_interview", { ttl = 500 }, 100)
			t.expect(Board.prune(b, 120)).toBe(false)
			t.expect(Board.prune(b, 151)).toBe(true)
			t.expect(Board.find(b, "interview_ib")).toBeNil()
			t.expect(Board.find(b, "superday_interview") ~= nil).toBeTruthy()
			Board.complete(b, "superday_interview", 77, 200)
			t.expect(Board.prune(b, 9999)).toBe(false)
			t.expect(Board.find(b, "superday_interview").quality).toBe(77)
		end)
		t.it("counts what's left", function()
			local b = build(STUDENT, 4)
			local n = #b.tasks
			t.expect(Board.remaining(b)).toBe(n)
			Board.complete(b, b.tasks[1].id, 50, 10)
			t.expect(Board.remaining(b)).toBe(n - 1)
			t.expect(Board.remaining(nil)).toBe(0)
		end)
	end)

	t.describe("workday key", function()
		t.it("employees follow the career week; students count active time", function()
			local c = ib(1)
			c.week = 4
			c.weekActive = 0
			local key1, day1, next1 = Board.dayKey(Board.who(c), c, 99999)
			c.weekActive = 8 * 60 + 5
			local key2, day2 = Board.dayKey(Board.who(c), c, 99999)
			t.expect(key1 ~= key2).toBeTruthy()
			t.expect(day2).toBe(day1 + 1)
			t.expect(next1).toBe(8 * 60)
			c.weekActive = 39 * 60
			local _, _, nextFri = Board.dayKey(Board.who(c), c, 0)
			t.expect(nextFri).toBe(-1)
			local s1 = Board.dayKey(Board.who(STUDENT), STUDENT, 100)
			local s2 = Board.dayKey(Board.who(STUDENT), STUDENT, 470)
			local s3 = Board.dayKey(Board.who(STUDENT), STUDENT, 490)
			t.expect(s1).toBe(s2)
			t.expect(s1 ~= s3).toBeTruthy()
		end)
		t.it("a role change changes the key", function()
			local a = Board.dayKey(Board.who(ib(1)), ib(1), 0)
			local b = Board.dayKey(Board.who(ib(2)), ib(2), 0)
			t.expect(a ~= b).toBeTruthy()
		end)
	end)
end
