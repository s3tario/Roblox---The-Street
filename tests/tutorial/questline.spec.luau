-- tutorial: the onboarding chain (Logic/QuestLine) and the Recruiting Board pipeline (Logic/QuestLine/Recruit).
local Shared = game:GetService("ReplicatedStorage").Shared
local Quests = require(Shared.Config.Quests)
local Companies = require(Shared.Config.Companies)
local Template = require(Shared.Config.DataTemplate.Campus)
local QuestLine = require(Shared.Logic.QuestLine)
local Recruiting = require(Shared.Logic.Recruiting)

local Recruit = QuestLine.Recruit

local NOW = 1_800_000_000

local function freshCampus(): { [string]: any }
	-- a deep copy of the template default, as DataService would hand it over
	local function copy(v: any): any
		if type(v) ~= "table" then
			return v
		end
		local out = {}
		for k, x in v do
			out[k] = copy(x)
		end
		return out
	end
	return copy(Template.campus)
end

-- Facts builder: start from a brand-new student, override what a test needs.
local function facts(over: { [string]: any }?): QuestLine.Facts
	local raw: { [string]: any } = { tasksDone = {} }
	for k, v in over or {} do
		raw[k] = v
	end
	return QuestLine.facts(raw)
end

local function profile(over: { [string]: any }?): { [string]: any }
	local p: { [string]: any } = {
		built = true,
		school = { id = "eastbridge_state", rarity = "common" },
		degree = "bs",
		gpa = 3.1,
		family = { id = "smith", rarity = "common" },
		stats = {
			knowledge = 40,
			skill = 40,
			speed = 40,
			charisma = 40,
			network = 40,
			discipline = 40,
			risk = 40,
			luck = 40,
		},
		perks = {},
	}
	for k, v in over or {} do
		p[k] = v
	end
	return p
end

local function walkOnFirm(): any
	for _, c in Companies.forTrack("ib") do
		if Recruit.isWalkOn(c, "ib") then
			return c
		end
	end
	return nil
end

local function selectiveFirm(): any
	for _, c in Companies.forTrack("ib") do
		if not Recruit.isWalkOn(c, "ib") then
			return c
		end
	end
	return nil
end

return function(t)
	t.describe("Config/Quests", function()
		t.it("has the v3 onboarding chain in order", function()
			local ids = {}
			for _, s in Quests.steps do
				table.insert(ids, s.id)
			end
			t.expect(table.concat(ids, ",")).toBe(table.concat({
				"career_center",
				"life_roll",
				"advisor",
				"club",
				"academics",
				"pitch",
				"network",
				"mock_interview",
				"recruiting",
				"offers",
				"subway",
				"tower",
				"receptionist",
				"elevator",
				"boss",
				"first_task",
				"first_trade",
				"review_intro",
			}, ","))
		end)
		t.it("every step is well formed", function()
			for _, s in Quests.steps do
				t.expect(s.phase == "campus" or s.phase == "street").toBe(true)
				t.expect(#s.title > 0 and #s.objective > 0 and #s.hint > 0).toBe(true)
				t.expect(type(s.doneWhen)).toBe("table")
				if s.back then
					assert(Quests.stepById[s.back], s.id .. " steps back to unknown " .. s.back)
					assert(s.holdWhile, s.id .. " has back without holdWhile")
				end
				local offer = if s.enter then s.enter.offerTask else nil
				if offer then
					assert(Shared.Logic.Tasks:FindFirstChild(offer), s.id .. " offers missing task " .. offer)
				end
				if s.milestone and s.banner then
					t.expect(#s.banner.title > 0 and #s.banner.subtitle > 0).toBe(true)
				end
			end
			for _, id in { Quests.recruiting.interviewTask, Quests.recruiting.superdayTask } do
				assert(Shared.Logic.Tasks:FindFirstChild(id), "missing recruiting task " .. id)
			end
		end)
		t.it("the arrival banner says what the owner wrote", function()
			t.expect(Quests.arrival.subtitle).toBe("Wall Street is 40 minutes and a whole world away.")
		end)
		t.it("every objective fills its placeholders", function()
			local campus = QuestLine.normalize(freshCampus())
			local f = facts({ company = "MG Freeman", boss = "Catherine Ashby", department = "Investment Banking" })
			for _, s in Quests.steps do
				campus.step = s.id
				local text = QuestLine.objective(campus, f)
				assert(text, "no objective for " .. s.id)
				assert(not string.find(text :: string, "{", 1, true), s.id .. " left a placeholder: " .. tostring(text))
			end
		end)
	end)

	t.describe("QuestLine chain", function()
		t.it("starts at the Career Center and walks the happy path to the end", function()
			local campus = freshCampus()
			local r = QuestLine.reconcile(campus, facts(), NOW)
			t.expect(campus.step).toBe("career_center")
			t.expect(r.entered).toBe("career_center")
			t.expect(QuestLine.started(campus)).toBe(true)

			-- walk into the Career Center
			QuestLine.reconcile(campus, facts({ zone = "career_center" }), NOW + 1)
			t.expect(campus.step).toBe("life_roll")
			-- Life Roll locked
			QuestLine.reconcile(campus, facts({ built = true }), NOW + 2)
			t.expect(campus.step).toBe("advisor")
			-- the advisor conversation completes the step directly
			t.expect(QuestLine.complete(campus, "advisor", NOW + 3)).toBe(true)
			t.expect(campus.step).toBe("club")
			-- joining the club (TutorialService:JoinClub sets campus.club)
			campus.club = true
			QuestLine.reconcile(campus, facts({ built = true }), NOW + 4)
			t.expect(campus.step).toBe("academics")
			local done = { academics_problem_set = 1 }
			QuestLine.reconcile(campus, facts({ built = true, tasksDone = done }), NOW + 5)
			t.expect(campus.step).toBe("pitch")
			done.mock_stock_pitch = 1
			QuestLine.reconcile(campus, facts({ built = true, tasksDone = done }), NOW + 6)
			t.expect(campus.step).toBe("network")
			QuestLine.reconcile(campus, facts({ built = true, tasksDone = done, networked = 2 }), NOW + 7)
			t.expect(campus.step).toBe("network")
			QuestLine.reconcile(campus, facts({ built = true, tasksDone = done, networked = 3 }), NOW + 8)
			t.expect(campus.step).toBe("mock_interview")
			done.mock_interview = 1
			QuestLine.reconcile(campus, facts({ built = true, tasksDone = done }), NOW + 9)
			t.expect(campus.step).toBe("recruiting")
			QuestLine.reconcile(campus, facts({ built = true, hasOffer = true }), NOW + 10)
			t.expect(campus.step).toBe("offers")
			-- accepted: hired, still on campus
			local hired = { built = true, employed = true, company = "MG Freeman", boss = "Catherine Ashby" }
			QuestLine.reconcile(campus, facts(hired), NOW + 11)
			t.expect(campus.step).toBe("subway")
			hired.zone = "street"
			QuestLine.reconcile(campus, facts(hired), NOW + 12)
			t.expect(campus.step).toBe("tower")
			hired.inOffice, hired.inOwnOffice, hired.onboarded = true, true, true
			QuestLine.reconcile(campus, facts(hired), NOW + 13)
			t.expect(campus.step).toBe("receptionist")
			QuestLine.complete(campus, "receptionist", NOW + 14)
			t.expect(campus.step).toBe("elevator")
			hired.onOwnFloor = true
			QuestLine.reconcile(campus, facts(hired), NOW + 15)
			t.expect(campus.step).toBe("boss")
			QuestLine.complete(campus, "boss", NOW + 16)
			t.expect(campus.step).toBe("first_task")
			hired.jobTasks = 1
			QuestLine.reconcile(campus, facts(hired), NOW + 17)
			t.expect(campus.step).toBe("first_trade")
			hired.trades = 1
			QuestLine.reconcile(campus, facts(hired), NOW + 18)
			t.expect(campus.step).toBe("review_intro")
			QuestLine.complete(campus, "review_intro", NOW + 19)
			t.expect(QuestLine.finished(campus)).toBe(true)
			t.expect(QuestLine.current(campus)).toBeNil()
			t.expect(QuestLine.objective(campus, facts(hired))).toBeNil()
			for _, row in QuestLine.progress(campus) do
				t.expect(row.state).toBe("done")
			end
		end)

		t.it("a reconcile completes everything an old save already did, in order", function()
			local campus = freshCampus()
			campus.club = true
			local r = QuestLine.reconcile(
				campus,
				facts({
					built = true,
					tasksDone = { academics_problem_set = 2, mock_stock_pitch = 1, mock_interview = 1 },
					networked = 4,
				}),
				NOW
			)
			-- the advisor has no fact of its own: the chain waits there
			t.expect(campus.step).toBe("advisor")
			t.expect(r.completed[1].id).toBe("career_center")
			t.expect(r.completed[2].id).toBe("life_roll")
			-- a step finished out of order is marked and completes on arrival
			t.expect(QuestLine.complete(campus, "mock_interview", NOW)).toBe(false)
			QuestLine.complete(campus, "advisor", NOW)
			r = QuestLine.reconcile(
				campus,
				facts({
					built = true,
					tasksDone = { academics_problem_set = 2, mock_stock_pitch = 1, mock_interview = 1 },
					networked = 4,
				}),
				NOW + 1
			)
			t.expect(campus.step).toBe("recruiting")
		end)

		t.it("campus steps are bypassed once hired, street steps run in order", function()
			local campus = freshCampus()
			QuestLine.reconcile(campus, facts({ built = true, employed = true }), NOW)
			t.expect(campus.step).toBe("subway")
			for _, row in QuestLine.progress(campus) do
				if row.phase == "campus" then
					t.expect(row.state).toBe("done")
				end
			end
		end)

		t.it("a rebirth skips the campus fluff but not the Life Roll or recruiting", function()
			local campus = freshCampus()
			QuestLine.reconcile(campus, facts({ rebirths = 1 }), NOW)
			t.expect(campus.step).toBe("life_roll")
			QuestLine.reconcile(campus, facts({ rebirths = 1, built = true }), NOW + 1)
			t.expect(campus.step).toBe("recruiting")
		end)

		t.it("declining every offer steps back to recruiting", function()
			local campus = freshCampus()
			campus.step = "offers"
			for _, s in Quests.steps do
				if s.id == "offers" then
					break
				end
				campus.done[s.id] = NOW
			end
			table.insert(
				campus.applications,
				{ companyId = "sterling_vance", stage = "offer", at = NOW, seed = 1, tries = 1, walkOn = true }
			)
			local r = QuestLine.reconcile(campus, facts({ built = true, hasOffer = false }), NOW + 1)
			t.expect(r.back).toBe("recruiting")
			t.expect(campus.step).toBe("recruiting")
			-- the applications survive a decline (slots stay used)
			t.expect(#campus.applications).toBe(1)
		end)

		t.it("a fresh start after a firing goes back to recruiting with a clean pipeline", function()
			local campus = freshCampus()
			QuestLine.reconcile(campus, facts({ built = true, employed = true }), NOW)
			t.expect(campus.step).toBe("subway")
			table.insert(
				campus.applications,
				{ companyId = "mg_freeman", stage = "offer", at = NOW, seed = 1, tries = 1, walkOn = false }
			)
			-- fired: the street step pauses (no skip, no objective) but stays
			local fired = facts({ built = true, fired = true })
			QuestLine.reconcile(campus, fired, NOW + 1)
			t.expect(campus.step).toBe("subway")
			t.expect(QuestLine.paused(campus, fired)).toBe(true)
			t.expect(QuestLine.objective(campus, fired)).toBeNil()
			campus.stuck = 0
			QuestLine.tick(campus, 30, fired)
			t.expect(campus.stuck).toBe(0)
			-- fresh start: a student again
			local r = QuestLine.reconcile(campus, facts({ built = true }), NOW + 2)
			t.expect(r.back).toBe("recruiting")
			t.expect(campus.step).toBe("recruiting")
			t.expect(#campus.applications).toBe(0)
			t.expect(campus.done.recruiting).toBeNil()
			t.expect(campus.done.subway).toBeNil()
		end)

		t.it("resetRecruiting reopens the Recruiting Board without touching campus progress", function()
			local campus = freshCampus()
			QuestLine.reconcile(campus, facts({ built = true, employed = true }), NOW)
			table.insert(
				campus.applications,
				{ companyId = "mg_freeman", stage = "offer", at = NOW, seed = 1, tries = 1, walkOn = false }
			)
			QuestLine.resetRecruiting(campus)
			t.expect(campus.step).toBe("recruiting")
			t.expect(#campus.applications).toBe(0)
			t.expect(campus.done.mock_interview).never(nil)
		end)

		t.it("normalize repairs a broken save", function()
			local campus: { [string]: any } = {
				step = "renamed_step",
				done = "oops",
				stuck = -5,
				network = { ids = { ["npc:npc_alum"] = true, ["player:1"] = true } },
				xpBoost = { mult = 9, left = -2 },
			}
			QuestLine.normalize(campus)
			t.expect(campus.step).toBe("")
			t.expect(type(campus.done)).toBe("table")
			t.expect(campus.stuck).toBe(0)
			t.expect(campus.network.count).toBe(2)
			t.expect(campus.xpBoost.mult).toBe(2)
			t.expect(campus.xpBoost.left).toBe(0)
			QuestLine.reconcile(campus, facts(), NOW)
			t.expect(campus.step).toBe("career_center")
		end)
	end)

	t.describe("skips and soft-locks", function()
		t.it("a non-core step can be skipped only after 10 active minutes", function()
			local campus = freshCampus()
			QuestLine.reconcile(campus, facts({ built = true }), NOW)
			t.expect(campus.step).toBe("advisor")
			local ok, err = QuestLine.canSkip(campus, facts({ built = true }))
			t.expect(ok).toBe(false)
			t.expect(err).toBe("skip_not_yet")
			for _ = 1, 9 do
				QuestLine.tick(campus, 60, facts({ built = true }))
			end
			t.expect((QuestLine.canSkip(campus))).toBe(false)
			QuestLine.tick(campus, 61, facts({ built = true }))
			t.expect((QuestLine.canSkip(campus))).toBe(true)
			local skipped = QuestLine.skip(campus, NOW + 600)
			t.expect(skipped and skipped.id).toBe("advisor")
			t.expect(campus.step).toBe("club")
			t.expect(campus.skipped.advisor).toBe(true)
			t.expect(campus.stuck).toBe(0)
			local rows = QuestLine.progress(campus)
			t.expect(rows[3].state).toBe("skipped")
		end)

		t.it("a single tick can't be used to jump the timer", function()
			local campus = freshCampus()
			QuestLine.reconcile(campus, facts({ built = true }), NOW)
			QuestLine.tick(campus, 10_000, facts({ built = true }))
			t.expect(campus.stuck).toBe(60)
		end)

		t.it("core steps are never skippable", function()
			for _, id in { "life_roll", "recruiting", "offers" } do
				local campus = freshCampus()
				campus.step = id
				campus.stuck = 10_000
				local ok, err = QuestLine.canSkip(campus)
				t.expect(ok).toBe(false)
				t.expect(err).toBe("skip_core")
				t.expect(QuestLine.skip(campus, NOW)).toBeNil()
				t.expect(campus.step).toBe(id)
			end
		end)

		t.it(
			"every step has a way forward: skippable after the timer, or a core step with a guaranteed route",
			function()
				for _, s in Quests.steps do
					local campus = freshCampus()
					campus.step = s.id
					if s.core then
						-- core steps: the Life Roll is always available, recruiting always has the walk-on seat, and
						-- the offers step falls back to recruiting if every offer goes away
						t.expect(s.id == "life_roll" or s.id == "recruiting" or s.id == "offers").toBe(true)
					else
						QuestLine.tick(campus, 60, facts({ built = true }))
						campus.stuck = Quests.SKIP_AFTER
						t.expect((QuestLine.canSkip(campus, facts({ built = true })))).toBe(true)
						local before = campus.step
						QuestLine.skip(campus, NOW)
						t.expect(campus.step ~= before).toBe(true)
					end
				end
			end
		)

		t.it("the walk-on seat is always open to any built student, even with every slot used", function()
			local firm = walkOnFirm()
			assert(firm, "an IB walk-on firm (Sterling & Vance) must exist")
			t.expect(firm.id).toBe("sterling_vance")
			local worst = profile({ school = { id = "coastal_cc", rarity = "common" }, gpa = 2.7 })
			local eligible = Recruiting.eligibility(worst, firm, "ib")
			t.expect(eligible).toBe(true)
			local apps = {}
			for i, c in Companies.forTrack("ib") do
				if c.id ~= firm.id and i <= 8 then
					table.insert(
						apps,
						{ companyId = c.id, stage = "rejected", at = NOW, seed = i, tries = 1, walkOn = false }
					)
				end
			end
			t.expect(Recruit.slotsUsed(apps) >= Quests.recruiting.maxApplications).toBe(true)
			local ok =
				Recruit.canApply(apps, firm, { built = true, hired = false, eligible = true, pendingOffer = false })
			t.expect(ok).toBe(true)
			local other = selectiveFirm()
			local okOther, err = Recruit.canApply(apps, other, {
				built = true,
				hired = false,
				eligible = true,
				pendingOffer = false,
			})
			if Recruit.find(apps, other.id) == nil then
				t.expect(okOther).toBe(false)
				t.expect(err).toBe("full")
			end
		end)
	end)

	t.describe("Recruiting Board pipeline", function()
		t.it("a Superday miss at the walk-on firm can be retaken until it passes, then the offer is certain", function()
			local firm = walkOnFirm()
			local apps = {}
			local app = Recruit.apply(apps, firm, NOW, 42, "ib")
			t.expect(app.stage).toBe("first_round")
			t.expect(app.walkOn).toBe(true)
			t.expect(Recruit.slotsUsed(apps)).toBe(0)
			local nextApp, taskId = Recruit.nextTask(apps)
			t.expect(nextApp).toBe(app)
			t.expect(taskId).toBe(Quests.recruiting.interviewTask)
			-- even a weak first round reaches the walk-on Superday
			t.expect(Recruit.firstRound(app, 12, firm, "ib")).toBe("superday")
			local bar = Recruit.walkOnBar(firm, "ib") :: number
			t.expect(Recruit.superday(app, bar - 1, firm, "ib")).toBe("retry")
			t.expect(app.tries).toBe(1)
			t.expect(Recruit.objective(apps)).toBe("recruit_obj_retry")
			-- retry puts the Superday back on the board
			t.expect(Recruit.retry(app)).toBe(true)
			t.expect(app.stage).toBe("superday")
			local _, again = Recruit.nextTask(apps)
			t.expect(again).toBe(Quests.recruiting.superdayTask)
			t.expect(Recruit.retry(app)).toBe(false) -- only from "retry"
			t.expect(Recruit.superday(app, bar, firm, "ib")).toBe("decision")
			t.expect(app.tries).toBe(2)
			t.expect(app.sure).toBe(true)
			local chance = Recruit.chance(app, profile(), firm, nil, "ib")
			t.expect(chance).toBe(1)
			t.expect(Recruit.decide(app, chance, 0.999)).toBe("offer")
			Recruit.settle(app, "offer", "o1")
			t.expect(app.stage).toBe("offer")
			t.expect(app.offerId).toBe("o1")
			t.expect(Recruit.isOpen(app)).toBe(false)
		end)

		t.it("a selective firm: cut after a bad first round, exact odds at the decision", function()
			local firm = selectiveFirm()
			local apps = {}
			local p = profile({ school = { id = "harvale", rarity = "mythic" }, gpa = 3.9 })
			local app = Recruit.apply(apps, firm, NOW, 7, "ib")
			t.expect(Recruit.slotsUsed(apps)).toBe(1)
			local cut = Recruit.cutFor(firm, "ib")
			t.expect(Recruit.firstRound(app, cut - 1, firm, "ib")).toBe("cut")
			t.expect(Recruit.isOpen(app)).toBe(false)
			t.expect(Recruit.objective(apps)).toBe("recruit_obj_more")

			local apps2 = {}
			local app2 = Recruit.apply(apps2, firm, NOW, 8, "ib")
			t.expect(Recruit.firstRound(app2, 80, firm, "ib")).toBe("superday")
			t.expect(Recruit.superday(app2, 90, firm, "ib")).toBe("decision")
			t.expect(app2.quality).toBe(math.floor(80 * 0.4 + 90 * 0.6 + 0.5))
			local chance = Recruit.chance(app2, p, firm, nil, "ib")
			local direct = Recruiting.offerChance(p, firm, app2.quality :: number, nil, "ib")
			t.expect(chance).toBeCloseTo(direct, 1e-9)
			t.expect(chance).toBeBetween(0.01, Recruiting.MAX_CHANCE)
			-- the roll honours the odds exactly: below the chance is an offer, at or above is a no
			t.expect(Recruit.decide(app2, chance, chance - 1e-6)).toBe("offer")
			t.expect(Recruit.decide(app2, chance, chance)).toBe("rejected")
			-- better interviews never lower the odds
			local low = Recruit.preview(p, firm, nil, "ib")
			t.expect(#low).toBe(#Quests.recruiting.previewQualities)
			for i = 2, #low do
				t.expect(low[i].chance >= low[i - 1].chance).toBe(true)
			end
		end)

		t.it("the board won't take a second application to the same firm or one past the limit", function()
			local apps = {}
			local list = Companies.forTrack("ib")
			local ctx = { built = true, hired = false, eligible = true, pendingOffer = false }
			local applied = 0
			for _, c in list do
				if not Recruit.isWalkOn(c, "ib") then
					local ok, err = Recruit.canApply(apps, c, ctx)
					if applied < Quests.recruiting.maxApplications then
						t.expect(ok).toBe(true)
						Recruit.apply(apps, c, NOW, applied, "ib")
						applied += 1
						local again, why = Recruit.canApply(apps, c, ctx)
						t.expect(again).toBe(false)
						t.expect(why).toBe("applied")
					else
						t.expect(ok).toBe(false)
						t.expect(err).toBe("full")
					end
				end
			end
			t.expect(Recruit.slotsUsed(apps)).toBe(Quests.recruiting.maxApplications)
			local no, why = Recruit.canApply(
				{},
				list[1],
				{ built = false, hired = false, eligible = true, pendingOffer = false }
			)
			t.expect(no).toBe(false)
			t.expect(why).toBe("no_profile")
			no, why = Recruit.canApply(
				{},
				list[1],
				{ built = true, hired = true, eligible = true, pendingOffer = false }
			)
			t.expect(why).toBe("employed")
			no, why = Recruit.canApply(
				{},
				list[1],
				{ built = true, hired = false, eligible = false, pendingOffer = false }
			)
			t.expect(why).toBe("ineligible")
		end)

		t.it(
			"a finished interview finds its application by company, by the pending marker, or the oldest waiting",
			function()
				local list = Companies.forTrack("ib")
				local apps = {}
				local a = Recruit.apply(apps, list[1], NOW, 1, "ib")
				local b = Recruit.apply(apps, list[2], NOW, 2, "ib")
				t.expect(Recruit.forTask(apps, Quests.recruiting.interviewTask, list[2].id, nil)).toBe(b)
				t.expect(Recruit.forTask(apps, Quests.recruiting.interviewTask, nil, list[2].id)).toBe(b)
				t.expect(Recruit.forTask(apps, Quests.recruiting.interviewTask, nil, nil)).toBe(a)
				t.expect(Recruit.forTask(apps, Quests.recruiting.superdayTask, list[1].id, nil)).toBeNil()
				t.expect(Recruit.forTask(apps, "coffee_chat", nil, nil)).toBeNil()
			end
		)

		t.it("the recruiting objective names the most urgent application", function()
			local list = Companies.forTrack("ib")
			local apps = {}
			t.expect(Recruit.objective(apps)).toBe("recruit_obj_apply")
			local a = Recruit.apply(apps, list[1], NOW, 1, "ib")
			local key, vars = Recruit.objective(apps)
			t.expect(key).toBe("recruit_obj_interview")
			t.expect(vars.company).toBe(list[1].name)
			Recruit.firstRound(a, 90, list[1], "ib")
			Recruit.superday(a, 90, list[1], "ib")
			t.expect((Recruit.objective(apps))).toBe("recruit_obj_decision")
			local campus = QuestLine.normalize(freshCampus())
			campus.step = "recruiting"
			campus.applications = apps
			local text = QuestLine.objective(campus, facts({ built = true }))
			t.expect(string.find(text :: string, list[1].name, 1, true) ~= nil).toBe(true)
		end)
	end)
end
