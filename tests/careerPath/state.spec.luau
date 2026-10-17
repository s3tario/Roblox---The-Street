local Shared = game:GetService("ReplicatedStorage").Shared
local CareerState = require(Shared.Logic.CareerState)
local Leveling = require(Shared.Logic.Leveling)
local Template = require(Shared.Config.DataTemplate.Career)

local function fresh(): { [string]: any }
	local c = table.clone(Template.career)
	for k, v in c do
		if type(v) == "table" then
			c[k] = table.clone(v)
		end
	end
	return c
end

local function employed(): { [string]: any }
	local c = fresh()
	c.level = 12
	CareerState.hire(c, { companyId = "mg_freeman", trackId = "ib", rank = 1, now = 1000, active = 500 })
	return c
end

return function(t)
	t.describe("hire", function()
		t.it("hires a student as an analyst and starts week 1", function()
			local c = fresh()
			local old =
				CareerState.hire(c, { companyId = "mg_freeman", trackId = "ib", rank = 1, now = 1, active = 77 })
			t.expect(old).toBe("student")
			t.expect(c.roleId).toBe("ib_analyst")
			t.expect(c.title).toBe("Analyst")
			t.expect(c.status).toBe("active")
			t.expect(c.week).toBe(1)
			t.expect(c.weekStartActive).toBe(77)
			t.expect(c.level).toBe(9) -- lifted to the analyst band floor
			t.expect(CareerState.isEmployed(c)).toBeTruthy()
		end)
	end)

	t.describe("week clock", function()
		t.it("moves through Monday..Friday and sets the review due on Friday afternoon", function()
			local c = employed()
			local days = {}
			local due = false
			for _ = 1, CareerState.DUE_AT do
				local ev = CareerState.tickWeek(c, 1)
				if ev.dayChanged then
					table.insert(days, ev.dayChanged)
				end
				due = due or ev.reviewDue
			end
			t.expect(table.concat(days, ",")).toBe("2,3,4,5")
			t.expect(due).toBeTruthy()
			t.expect(c.reviewDue).toBeTruthy()
			t.expect(c.weekday).toBe(5)
			t.expect(CareerState.windowRemaining(c)).toBe(-1)
		end)
		t.it("asks for the phone review once after 10 overdue active minutes", function()
			local c = employed()
			c.weekActive = CareerState.DUE_AT
			c.reviewDue = true
			local calls = 0
			for _ = 1, CareerState.REMOTE_AFTER + 120 do
				if CareerState.tickWeek(c, 1).remoteReview then
					calls += 1
				end
			end
			t.expect(calls).toBe(1)
			t.expect(c.weekActive).toBe(CareerState.WINDOW)
		end)
		t.it("does not tick for students or players between jobs", function()
			local c = fresh()
			CareerState.tickWeek(c, 30)
			t.expect(c.weekActive).toBe(0)
		end)
		t.it("clamps silly deltas", function()
			local c = employed()
			CareerState.tickWeek(c, 10 ^ 9)
			t.expect(c.weekActive).toBe(30)
			CareerState.tickWeek(c, -5)
			t.expect(c.weekActive).toBe(30)
		end)
		t.it("startWeek resets the week counters", function()
			local c = employed()
			c.weekWork.count = 5
			c.reviewDue = true
			c.weekRep = 9
			CareerState.startWeek(c, 3000)
			t.expect(c.week).toBe(2)
			t.expect(c.weekWork.count).toBe(0)
			t.expect(c.reviewDue).toBeFalsy()
			t.expect(c.weekRep).toBe(0)
			t.expect(c.weekStartActive).toBe(3000)
		end)
	end)

	t.describe("review decisions", function()
		t.it("On track or better keeps you active and promotes when everything passes", function()
			local d = CareerState.decide({ status = "active", band = "on_track", promotable = true })
			t.expect(d.outcome).toBe("promoted")
			local k = CareerState.decide({ status = "coaching", band = "star", promotable = false })
			t.expect(k.outcome).toBe("keep_going")
			t.expect(k.status).toBe("active")
		end)
		t.it("Underperforming means coaching; probation lasts until On track", function()
			t.expect(CareerState.decide({ status = "active", band = "under", promotable = false }).status)
				.toBe("coaching")
			t.expect(CareerState.decide({ status = "probation", band = "under", promotable = false }).status)
				.toBe("probation")
			t.expect(CareerState.decide({ status = "probation", band = "on_track", promotable = false }).status)
				.toBe("active")
		end)
		t.it("a first Critical is a warning on probation; two in a row is fired", function()
			local first =
				CareerState.decide({ status = "active", band = "critical", criticalStreak = 0, promotable = false })
			t.expect(first.outcome).toBe("warning")
			t.expect(first.status).toBe("probation")
			t.expect(first.criticalStreak).toBe(1)
			local second =
				CareerState.decide({ status = "active", band = "critical", criticalStreak = 1, promotable = false })
			t.expect(second.outcome).toBe("fired")
			t.expect(second.fireReason).toBe("critical")
		end)
		t.it("a Critical review while on probation is the high-stakes firing", function()
			local d =
				CareerState.decide({ status = "probation", band = "critical", criticalStreak = 0, promotable = false })
			t.expect(d.fired).toBeTruthy()
			t.expect(d.fireReason).toBe("probation")
		end)
		t.it("a good week resets the critical streak", function()
			local d =
				CareerState.decide({ status = "probation", band = "probation", criticalStreak = 1, promotable = false })
			t.expect(d.criticalStreak).toBe(0)
		end)
		t.it("forced firings (risk, mass) ignore the band", function()
			local d = CareerState.decide({ status = "active", band = "star", promotable = true, forceFire = "risk" })
			t.expect(d.outcome).toBe("fired")
			t.expect(d.fireReason).toBe("risk")
		end)
	end)

	t.describe("Alumni Lifeline", function()
		t.it("turns a firing into probation once", function()
			local d = CareerState.decide({
				status = "active",
				band = "critical",
				criticalStreak = 1,
				promotable = false,
				hasLifeline = true,
			})
			t.expect(d.fired).toBeFalsy()
			t.expect(d.lifelineUsed).toBeTruthy()
			t.expect(d.outcome).toBe("warning")
			t.expect(d.status).toBe("probation")
			t.expect(d.criticalStreak).toBe(0)
		end)
		t.it("saves from a mass firing too", function()
			local d = CareerState.decide({
				status = "active",
				band = "under",
				promotable = false,
				forceFire = "mass",
				hasLifeline = true,
			})
			t.expect(d.lifelineUsed).toBeTruthy()
			t.expect(d.fireReason).toBe("mass")
		end)
	end)

	t.describe("mass firing selection", function()
		t.it("lets go everyone below On track, saves Lifeline owners and spares new hires", function()
			local out = CareerState.massFiringSelect({
				{ id = "star", lastBand = "star" },
				{ id = "ok", lastBand = "on_track" },
				{ id = "under", lastBand = "under" },
				{ id = "prob", lastBand = "probation" },
				{ id = "crit", lastBand = "critical" },
				{ id = "saved", lastBand = "critical", hasLifeline = true },
				{ id = "newHire", lastBand = "" },
				{ id = "nilBand" },
			})
			table.sort(out.fire)
			table.sort(out.spare)
			t.expect(table.concat(out.fire, ",")).toBe("crit,prob,under")
			t.expect(table.concat(out.save, ",")).toBe("saved")
			t.expect(table.concat(out.spare, ",")).toBe("newHire,nilBand,ok,star")
		end)
	end)

	t.describe("wipeout and recovery", function()
		t.it("takes the job, 25% of band XP and resets the book to 10% (min $5k)", function()
			local c = employed()
			c.level = 20
			c.xp = 100
			local before = Leveling.xpInBand(20, 100, 9)
			local w = CareerState.wipeout(c, { reason = "critical", now = 5000, bookSize = 300000 })
			t.expect(w.lostXp).toBe(math.floor(before * 0.25))
			t.expect(w.newBook).toBe(30000)
			t.expect(w.lostBook).toBe(270000)
			t.expect(c.status).toBe("fired")
			t.expect(c.roleId).toBe("unemployed")
			t.expect(c.companyId).toBe("")
			t.expect(c.fired.companyId).toBe("mg_freeman")
			t.expect(c.wipeouts).toBe(1)
			t.expect(CareerState.isEmployed(c)).toBeFalsy()
			local small = employed()
			local w2 = CareerState.wipeout(small, { reason = "risk", now = 1, bookSize = 20000 })
			t.expect(w2.newBook).toBe(5000)
		end)
		t.it("re-entry rejoins one rank lower; reinstatement keeps the rank on probation", function()
			local c = employed()
			CareerState.setRole(c, "ib", 3, {})
			c.level = 50
			CareerState.wipeout(c, { reason = "critical", now = 1, bookSize = 1000000 })
			local ok = CareerState.restore(c, { kind = "reentry", now = 2, active = 10 })
			t.expect(ok).toBeTruthy()
			t.expect(c.rank).toBe(2)
			t.expect(c.roleId).toBe("ib_associate")
			t.expect(c.status).toBe("active")
			t.expect(c.companyId).toBe("mg_freeman")
			t.expect(c.level).toBeLessThanOrEqual(40)
			t.expect(c.comebacks).toBe(1)

			local d = employed()
			CareerState.setRole(d, "ib", 2, {})
			CareerState.wipeout(d, { reason = "critical", now = 1, bookSize = 1 })
			t.expect(CareerState.restore(d, { kind = "reinstated", now = 2, active = 10 })).toBeTruthy()
			t.expect(d.rank).toBe(2)
			t.expect(d.status).toBe("probation")
		end)
		t.it("re-entry from the entry rank stays at rank 1", function()
			local c = employed()
			CareerState.wipeout(c, { reason = "critical", now = 1, bookSize = 1 })
			CareerState.restore(c, { kind = "reentry", now = 2, active = 10 })
			t.expect(c.rank).toBe(1)
		end)
		t.it("restore refuses players who aren't between jobs", function()
			local ok, err = CareerState.restore(employed(), { kind = "reentry", now = 1, active = 1 })
			t.expect(ok).toBeFalsy()
			t.expect(err).toBe("not_fired")
		end)
		t.it("fresh start returns to campus recruiting", function()
			local c = employed()
			CareerState.wipeout(c, { reason = "critical", now = 1, bookSize = 1 })
			CareerState.freshStart(c)
			t.expect(c.status).toBe("student")
			t.expect(c.rank).toBe(0)
			t.expect(c.roleId).toBe("student")
		end)
	end)

	t.describe("rebirth", function()
		t.it("keeps plaques, signatures, prestige and counters; resets the rest", function()
			local c = employed()
			c.plaques = { { id = "p1", name = "Apex IPO" } }
			c.plaqueCount = 1
			c.signatures = { ipo = 1 }
			c.prestige = 500
			c.wipeouts = 2
			c.comebacks = 1
			c.level = 60
			CareerState.resetForRebirth(c, Template.career, 9000)
			t.expect(c.level).toBe(1)
			t.expect(c.rank).toBe(0)
			t.expect(c.status).toBe("student")
			t.expect(#c.plaques).toBe(1)
			t.expect(c.signatures.ipo).toBe(1)
			t.expect(c.prestige).toBe(500)
			t.expect(c.wipeouts).toBe(2)
			t.expect(c.comebacks).toBe(1)
			t.expect(c.lifeStartActive).toBe(9000)
			-- the template itself is untouched
			t.expect(#Template.career.plaques).toBe(0)
		end)
	end)

	t.describe("employees and merger partners", function()
		t.it("IsEmployeeOf matches the own company and merger partners only while active", function()
			local c = employed()
			t.expect(CareerState.isEmployee(c, "mg_freeman")).toBeTruthy()
			t.expect(CareerState.isEmployee(c, "goldfield_saxe")).toBeFalsy()
			local events = {
				corporate = {
					id = "merger_mania",
					startsAt = 100,
					endsAt = 200,
					data = { companies = { "mg_freeman", "evermoor" } },
				},
			}
			local during = CareerState.mergerPartners(events, "mg_freeman", 150)
			t.expect(CareerState.isEmployee(c, "evermoor", during)).toBeTruthy()
			local after = CareerState.mergerPartners(events, "mg_freeman", 250)
			t.expect(CareerState.isEmployee(c, "evermoor", after)).toBeFalsy()
			local pairEvents = { corporate = { id = "merger_mania", data = { a = "evermoor", b = "mg_freeman" } } }
			t.expect(CareerState.mergerPartners(pairEvents, "mg_freeman").evermoor).toBeTruthy()
		end)
		t.it("fired players are not employees", function()
			local c = employed()
			CareerState.wipeout(c, { reason = "critical", now = 1, bookSize = 1 })
			t.expect(CareerState.isEmployee(c, "mg_freeman")).toBeFalsy()
		end)
	end)

	t.describe("rings", function()
		t.it("pushRing keeps the newest entries", function()
			local list = {}
			for i = 1, 10 do
				CareerState.pushRing(list, i, 4)
			end
			t.expect(table.concat(list, ",")).toBe("7,8,9,10")
		end)
	end)
end
