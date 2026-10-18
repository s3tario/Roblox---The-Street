-- careerPath screens under Lune: the Career hub (every tab, for an employee, a player between jobs and a student),
-- the Offers list, Career Services (each mode), the re-entry runner, the review meeting (phone call) and its cards.
-- These are smoke tests: each screen must build its named sections from replicated-shaped data and close cleanly.
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Shared = game:GetService("ReplicatedStorage").Shared
local Signal = require(Shared.Util.Signal)
local Rng = require(Shared.Util.Rng)
local Tracks = require(Shared.Config.Tracks)
local Leveling = require(Shared.Logic.Leveling)
local Promotion = require(Shared.Logic.Promotion)
local Reentry = require(Shared.Logic.Projects.reentry)
-- Loaded up front: the screens require Logos lazily, and a first require can yield under Lune's loader.
local _Logos = require(Shared.Assets.Logos)
local Kit = require(Client.UI.Kit)
local Career = require(Client.UI.Screens.Career)
local Offers = require(Client.UI.Screens.Offers)
local CareerServices = require(Client.UI.Screens.CareerServices)
local ReviewMeeting = require(Client.UI.Screens.ReviewMeeting)
local Parts = Client.UI.Screens.CareerParts
local Breakdown = require(Parts.Breakdown)
local ReentryView = require(Parts.Reentry)
local OfferCard = require(Parts.OfferCard)

local AT = 1792000000

local function checklist(promo: any): { any }
	local out = {}
	for _, item in promo.items do
		table.insert(out, { id = item.id, ok = item.ok, pending = item.pending, text = item.text })
	end
	return out
end

local function employed(): { [string]: any }
	local promo = Promotion.evaluate({ trackId = "ib", rank = 1, level = 20, coreDone = 5, outfitLevel = 2 })
	return {
		level = 20,
		xp = 300,
		xpToNext = Leveling.xpForLevel(20),
		levelCap = 24,
		track = "ib",
		companyId = "mg_freeman",
		roleId = "ib_analyst",
		rank = 1,
		title = "Analyst",
		roleTitle = "Analyst",
		companyName = "MG Freeman",
		bossName = "Catherine Ashby",
		status = "active",
		week = 3,
		weekday = 2,
		weekActive = 700,
		windowRemaining = 1460,
		weekLabel = "Week 3 · Tue",
		reviewDue = true,
		weekWork = { count = 4, qualitySum = 300, core = 2 },
		reviews = {
			{
				id = "r1",
				week = 1,
				score = 72,
				band = "on_track",
				outcome = "keep_going",
				at = AT,
				components = { investment = 60, risk = 80, work = 75, reputation = 70 },
			},
			{
				id = "r2",
				week = 2,
				score = 51,
				band = "probation",
				outcome = "warning",
				lifeline = true,
				at = AT + 3000,
				components = { investment = 40, risk = 50, work = 60, reputation = 55 },
			},
		},
		history = {
			{ kind = "hired", at = AT, week = 0, title = "Analyst", companyId = "mg_freeman", level = 9 },
			{ kind = "deal", at = AT + 100, week = 1, name = "Apex AI IPO", level = 12 },
			{ kind = "lifeline", at = AT + 3000, week = 2, level = 15 },
		},
		plaques = {},
		plaqueCount = 1,
		prestige = 120,
		dealMastery = 80,
		reputation = 40,
		wipeouts = 0,
		comebacks = 0,
		promotion = {
			ready = promo.ready,
			missing = promo.missing,
			next = "Associate",
			headline = promo.headline,
			checklist = checklist(promo),
		},
		fitScore = 55,
		outfitLevel = 2,
		dressLevel = 3,
		offers = {
			{ id = "o1", companyId = "evermoor", track = "ib", rank = 1, source = "headhunter", at = AT },
		},
	}
end

local function fired(): { [string]: any }
	local c = employed()
	c.status = "fired"
	c.roleId = "unemployed"
	c.title = "Between jobs"
	c.roleTitle = "Between jobs"
	c.companyId = ""
	c.companyName = ""
	c.reviewDue = false
	c.weekLabel = "Between jobs"
	c.promotion = { ready = false, missing = { Tracks.text("promo_fired") }, checklist = {} }
	c.fired = { rank = 2, track = "ib", companyId = "mg_freeman", title = "Associate" }
	c.wipeouts = 1
	c.offers = {}
	return c
end

local function student(): { [string]: any }
	return {
		level = 4,
		xp = 50,
		xpToNext = Leveling.xpForLevel(4),
		levelCap = 8,
		track = "",
		companyId = "",
		roleId = "student",
		rank = 0,
		title = "College Student",
		roleTitle = "College Student",
		status = "student",
		weekLabel = "Campus",
		reviews = {},
		history = {},
		offers = {
			{ id = "o1", companyId = "sterling_vance", track = "ib", rank = 1, source = "walk_on", at = AT },
			{ id = "o2", companyId = "harrow_williams", track = "ib", rank = 1, source = "recruiting", at = AT },
			{ id = "o3", companyId = "not_a_firm", track = "ib", rank = 1, source = "recruiting", at = AT },
		},
		promotion = { ready = false, missing = { Tracks.text("promo_student") }, checklist = {} },
		outfitLevel = 1,
		dressLevel = 1,
	}
end

local function fakeStore(career: any)
	local signal = Signal.new()
	return {
		career = career,
		Get = function(self, key: string)
			return if key == "career" then self.career else nil
		end,
		Changed = function(_self, _key: string)
			return signal
		end,
		GetGlobal = function()
			return nil
		end,
	}
end

local function fakeController(info: any)
	local c = { calls = {}, meetingsClosed = 0, info = info }
	function c:GetServices()
		return self.info
	end
	function c:ErrorText(err)
		return "error: " .. tostring(err)
	end
	function c:AcceptOffer(id)
		table.insert(self.calls, "accept:" .. tostring(id))
		return true, nil
	end
	function c:DeclineOffer(id)
		table.insert(self.calls, "decline:" .. tostring(id))
		return true, nil
	end
	function c:Reentry(action)
		table.insert(self.calls, "reentry:" .. tostring(action))
		return false, "generic", nil, nil
	end
	function c:HasStore()
		return false
	end
	function c:OpenStore()
		return false
	end
	function c:HasScreen()
		return false
	end
	function c:MeetingClosed()
		self.meetingsClosed += 1
	end
	return c
end

local function ctxFor(career: any, controller: any)
	local notes: { string } = {}
	local closed = { n = 0 }
	local ctx = {
		Store = fakeStore(career),
		Registry = {
			get = function(name: string)
				return if name == "CareerController" then controller else nil
			end,
		},
		UI = {
			Notify = function(_self, text: string)
				table.insert(notes, text)
			end,
			Open = function() end,
			Confirm = function(_self, _opts, callback)
				callback(true)
			end,
		},
		Sfx = { play = function() end },
		close = function()
			closed.n += 1
		end,
	}
	return ctx, notes, closed
end

local function find(root: Instance, name: string): Instance?
	return root:FindFirstChild(name, true)
end

local function count(root: Instance, prefix: string): number
	local n = 0
	for _, d in root:GetDescendants() do
		if string.sub(d.Name, 1, #prefix) == prefix then
			n += 1
		end
	end
	return n
end

local function texts(root: Instance): string
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			table.insert(out, (d :: any).Text)
		end
	end
	return table.concat(out, "|")
end

return function(t)
	Kit.setReducedMotion(true)

	t.describe("Career hub", function()
		t.it("an employee sees the header, week, checklist and stats on the overview", function()
			local root = Instance.new("Frame")
			local ctx = ctxFor(employed(), fakeController(nil))
			local handle = Career.open({}, root, ctx)
			for _, name in { "Header", "Week", "Promotion", "Stats", "Offers" } do
				t.expect(find(root, name) ~= nil).toBeTruthy()
			end
			t.expect(find(root, "Item_level") ~= nil).toBeTruthy()
			t.expect(find(root, "Item_outfit") ~= nil).toBeTruthy()
			local all = texts(root)
			t.expect(all).toContain("Analyst")
			t.expect(all).toContain("MG Freeman")
			t.expect(all).toContain(Tracks.text("ui_score_pending"))
			handle.close()
		end)
		t.it("renders the reviews, timeline and ladder tabs", function()
			local career = employed()
			local reviews = Instance.new("Frame")
			local h1 = Career.open({ tab = "reviews" }, reviews, ctxFor(career, nil))
			t.expect(find(reviews, "ReviewChart") ~= nil).toBeTruthy()
			t.expect(find(reviews, "LastReview") ~= nil).toBeTruthy()
			t.expect(count(reviews, "Review_")).toBe(2)
			t.expect(texts(reviews)).toContain(Tracks.text("outcome_saved"))
			h1.close()

			local timeline = Instance.new("Frame")
			local h2 = Career.open({ tab = "timeline" }, timeline, ctxFor(career, nil))
			t.expect(count(timeline, "Entry_")).toBe(3)
			t.expect(texts(timeline)).toContain("Apex AI IPO")
			h2.close()

			local ladder = Instance.new("Frame")
			local h3 = Career.open({ tab = "ladder" }, ladder, ctxFor(career, nil))
			t.expect(count(ladder, "Rank_")).toBe(5)
			t.expect(count(ladder, "Track_")).toBe(10)
			local ladderText = texts(ladder)
			t.expect(ladderText).toContain("Managing Director")
			t.expect(ladderText).toContain(Tracks.text("ui_coming_soon"))
			t.expect(ladderText).toContain(Tracks.text("ui_ladder_you"))
			h3.close()
		end)
		t.it("a player between jobs is pointed to Career Services; a student to recruiting", function()
			local root = Instance.new("Frame")
			local h1 = Career.open({}, root, ctxFor(fired(), nil))
			t.expect(find(root, "Fired") ~= nil).toBeTruthy()
			t.expect(find(root, "Week")).toBeNil()
			t.expect(find(root, "Promotion")).toBeNil()
			h1.close()

			local campus = Instance.new("Frame")
			local h2 = Career.open({}, campus, ctxFor(student(), nil))
			t.expect(find(campus, "Student") ~= nil).toBeTruthy()
			t.expect(texts(campus)).toContain("College Student")
			h2.close()
		end)
		t.it("opens before the career has replicated", function()
			local root = Instance.new("Frame")
			local handle = Career.open({}, root, ctxFor(nil, nil))
			t.expect(find(root, "Header") ~= nil).toBeTruthy()
			handle.close()
		end)
	end)

	t.describe("Offers", function()
		t.it("shows a card per valid offer with pay, dress level and the school gate", function()
			local root = Instance.new("Frame")
			local handle = Offers.open({}, root, ctxFor(student(), fakeController(nil)))
			t.expect(count(root, "Offer_")).toBe(2) -- the unknown firm is skipped
			local all = texts(root)
			t.expect(all).toContain("Sterling & Vance")
			t.expect(all).toContain(Tracks.text("offers_dress_value", { need = 3 }))
			t.expect(all).toContain(Tracks.text("offers_gate", { title = "Managing Director", tier = "Rare" }))
			t.expect(all).toContain(Tracks.text("source_walk_on"))
			handle.close()
		end)
		t.it("shows the empty state", function()
			local root = Instance.new("Frame")
			local c = student()
			c.offers = {}
			local handle = Offers.open({}, root, ctxFor(c, fakeController(nil)))
			t.expect(find(root, "Empty") ~= nil).toBeTruthy()
			handle.close()
		end)
		t.it("builds a card with Accept and Decline for a known firm, nothing for an unknown one", function()
			local card = OfferCard.build(student().offers[1], student(), {
				onAccept = function() end,
				onDecline = function() end,
			})
			t.expect(card ~= nil).toBeTruthy()
			local cardText = texts(card.frame)
			t.expect(cardText).toContain(Tracks.text("offers_accept"))
			t.expect(cardText).toContain(Tracks.text("offers_decline"))
			t.expect(OfferCard.build({ id = "x", companyId = "nope", track = "ib", rank = 1 }, {}, {
				onAccept = function() end,
				onDecline = function() end,
			})).toBeNil()
		end)
	end)

	t.describe("Career Services", function()
		local firedInfo = {
			loaded = true,
			status = "fired",
			employed = false,
			reinstateCredits = 1,
			capitalCredits = 0,
			capitalUsable = false,
			offers = 0,
			fired = {
				reason = "critical",
				companyName = "MG Freeman",
				title = "Associate",
				lostXp = 1234,
				lostBook = 450000,
				newBook = 50000,
				reentryTitle = "Analyst",
				returnCompany = "MG Freeman",
			},
			rebirth = { available = false, can = false },
		}
		t.it("between jobs: what was lost and kept, then every way back", function()
			local root = Instance.new("Frame")
			local handle = CareerServices.open({}, root, ctxFor(fired(), fakeController(firedInfo)))
			t.expect(find(root, "Lost") ~= nil).toBeTruthy()
			t.expect(find(root, "Kept") ~= nil).toBeTruthy()
			t.expect(count(root, "Option")).toBeGreaterThanOrEqual(4)
			local all = texts(root)
			t.expect(all).toContain("1,234")
			t.expect(all).toContain(Tracks.text("services_reentry_start"))
			t.expect(all).toContain(Tracks.text("services_reinstate_use"))
			t.expect(all).toContain(Tracks.text("services_store_soon")) -- capital: no credit, no store yet
			t.expect(all).toContain(Tracks.text("services_fresh_button"))
			handle.close()
		end)
		t.it("employed and student check-ins, and a retry when the server can't answer", function()
			local employedInfo = {
				loaded = true,
				status = "active",
				employed = true,
				title = "Analyst",
				companyName = "MG Freeman",
				offers = 1,
				rebirth = { available = false },
			}
			local root = Instance.new("Frame")
			local h1 = CareerServices.open({}, root, ctxFor(employed(), fakeController(employedInfo)))
			t.expect(find(root, "Status") ~= nil).toBeTruthy()
			t.expect(texts(root)).toContain(Tracks.text("services_rebirth_soon"))
			t.expect(texts(root)).toContain(Tracks.text("services_offers"))
			h1.close()

			local campus = Instance.new("Frame")
			local studentInfo = { loaded = true, status = "student" }
			local h2 = CareerServices.open({}, campus, ctxFor(student(), fakeController(studentInfo)))
			t.expect(find(campus, "Recruiting") ~= nil).toBeTruthy()
			h2.close()

			local offline = Instance.new("Frame")
			local h3 = CareerServices.open({}, offline, ctxFor(nil, fakeController(nil)))
			t.expect(texts(offline)).toContain(Tracks.text("ui_retry"))
			h3.close()
		end)
	end)

	t.describe("re-entry runner", function()
		t.it("draws the current stage's questions and the final verdict", function()
			local state = Reentry.new(Rng.new(7))
			local view = Reentry.view(state)
			local scroll = Kit.Scroll({ name = "Scroll" })
			ReentryView.build(scroll, { view = view, result = nil }, {
				submit = function() end,
				continue = function() end,
				retry = function() end,
				back = function() end,
			})
			t.expect(count(scroll.frame, "Question_")).toBe(3)
			t.expect(texts(scroll.frame)).toContain(Tracks.text("reentry_pick_all"))

			for i = 1, 3 do
				local stage = state.stages[i]
				local answers = {}
				if stage.kind == "mcq" then
					for qid, right in stage.secret.answers do
						answers[qid] = right
					end
				else
					for lineId, opts in stage.secret.scores do
						local best, bestScore = nil, -1
						for optId, s in opts do
							if s > bestScore then
								best, bestScore = optId, s
							end
						end
						answers[lineId] = best
					end
				end
				Reentry.act(state, answers)
			end
			local done = Kit.Scroll({ name = "Done" })
			ReentryView.build(done, { view = Reentry.view(state), result = nil }, {
				submit = function() end,
				continue = function() end,
				retry = function() end,
				back = function() end,
			})
			t.expect(find(done.frame, "Verdict") ~= nil).toBeTruthy()
			t.expect(texts(done.frame)).toContain(Tracks.text("reentry_passed_title"))
		end)
	end)

	t.describe("review meeting", function()
		local payload = {
			id = "r3",
			mode = "phone",
			week = 3,
			score = 86,
			band = "star",
			bandName = "Star",
			outcome = "promoted",
			status = "active",
			lines = { "Line one.", "Line two.", "Promoted line.", "Closing." },
			outcomeAt = 3,
			breakdown = true,
			components = { investment = 90, risk = 85, work = 80, reputation = 88 },
			weights = { investment = 0.35, risk = 0.25, work = 0.25, reputation = 0.15 },
			company = { id = "mg_freeman", name = "MG Freeman", primary = Color3.new(0, 0, 0) },
			boss = { name = "Catherine Ashby" },
			title = "Analyst",
			newTitle = "Associate",
			pay = { salary = 1100, bonus = 750, living = 90 },
			xp = 120,
			prestige = 13,
		}
		t.it("a phone review rings first and closing hands control back", function()
			local root = Instance.new("Frame")
			local controller = fakeController(nil)
			local ctx = ctxFor(employed(), controller)
			local handle = ReviewMeeting.open({ payload = payload }, root, ctx)
			t.expect(find(root, "IncomingCall") ~= nil).toBeTruthy()
			t.expect(find(root, "TapCatcher") ~= nil).toBeTruthy()
			handle.close()
			t.expect(controller.meetingsClosed).toBe(1)
			t.expect(find(root, "Meeting")).toBeNil()
			handle.close()
			t.expect(controller.meetingsClosed).toBe(1)
		end)
		t.it("a broken payload closes itself", function()
			local root = Instance.new("Frame")
			local controller = fakeController(nil)
			local ctx, _, closed = ctxFor(nil, controller)
			local handle = ReviewMeeting.open({ payload = { mode = "office" } }, root, ctx)
			task.wait()
			t.expect(closed.n).toBe(1)
			handle.close()
			t.expect(controller.meetingsClosed).toBe(1)
		end)
		t.it("the breakdown card shows all four weighted components and Friday's pay", function()
			local root = Instance.new("Frame")
			Breakdown.card(root, payload)
			for _, id in { "investment", "risk", "work", "reputation" } do
				t.expect(find(root, "Comp_" .. id) ~= nil).toBeTruthy()
			end
			local all = texts(root)
			t.expect(all).toContain("35%")
			t.expect(all).toContain("86")
			t.expect(all).toContain("Star")
			t.expect(all).toContain("$1,100")
		end)
		t.it("reveals each outcome with its own headline", function()
			local cases = {
				{ { outcome = "promoted", newTitle = "Associate" }, "promoted", "meeting_promoted" },
				{ { outcome = "keep_going", missing = { "Reach Level 24." } }, "keep_going", "meeting_keep_going" },
				{ { outcome = "warning", status = "coaching" }, "warning", "meeting_warning" },
				{ { outcome = "warning", status = "probation" }, "probation", "meeting_probation" },
				{ { outcome = "fired", status = "fired" }, "fired", "meeting_fired" },
				{ { outcome = "warning", status = "probation", lifeline = true }, "saved", "meeting_saved" },
				{ { outcome = "mystery" }, "keep_going", "meeting_keep_going" },
			}
			for _, case in cases do
				t.expect(Breakdown.revealKind(case[1])).toBe(case[2])
				local root = Instance.new("Frame")
				local _, sound = Breakdown.reveal(root, case[1], function() end)
				t.expect(type(sound)).toBe("string")
				t.expect(texts(root)).toContain(Tracks.text(case[3]))
			end
		end)
	end)
end
