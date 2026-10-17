local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local DoorRules = require(Shared.Logic.DoorRules)
local Text = DoorRules.Text

return function(t)
	t.describe("DoorRules.check", function()
		t.it("passes when there are no requirements", function()
			t.expect((DoorRules.check(nil, {}))).toBe(true)
			t.expect((DoorRules.check({}, nil))).toBe(true)
		end)
		t.it("enforces minRank", function()
			local ok, reason = DoorRules.check({ minRank = 3 }, { rank = 2 })
			t.expect(ok).toBe(false)
			t.expect(reason).toBe("rank")
			t.expect((DoorRules.check({ minRank = 3 }, { rank = 3 }))).toBe(true)
			t.expect((DoorRules.check({ minRank = 1 }, {}))).toBe(false) -- unknown rank counts as 0
		end)
		t.it("enforces employed", function()
			local ok, reason = DoorRules.check({ employed = true }, { rank = 4, employed = false })
			t.expect(ok).toBe(false)
			t.expect(reason).toBe("employed")
			t.expect((DoorRules.check({ employed = true }, { employed = true }))).toBe(true)
		end)
		t.it("checks a data flag by dot path, with orMinRank as the alternative", function()
			local req = { flag = "campus.offer", orMinRank = 1 }
			local ok, reason = DoorRules.check(req, { rank = 0, data = { campus = { offer = false } } })
			t.expect(ok).toBe(false)
			t.expect(reason).toBe("flag")
			t.expect((DoorRules.check(req, { rank = 0, data = { campus = { offer = true } } }))).toBe(true)
			t.expect((DoorRules.check(req, { rank = 0, data = { campus = { offer = { companyId = "x" } } } })))
				.toBe(true)
			t.expect((DoorRules.check(req, { rank = 1, data = {} }))).toBe(true)
			t.expect((DoorRules.check(req, { rank = 0 }))).toBe(false) -- no data loaded yet
			t.expect((DoorRules.check({ flag = "campus.offer" }, { rank = 9, data = {} }))).toBe(false)
		end)
		t.it("treats orMinRank without a flag like minRank", function()
			t.expect((DoorRules.check({ orMinRank = 2 }, { rank = 1 }))).toBe(false)
			t.expect((DoorRules.check({ orMinRank = 2 }, { rank = 2 }))).toBe(true)
		end)
		t.it("checks passes", function()
			local req = { pass = "ExecutiveClub" }
			local ok, reason = DoorRules.check(req, { passes = {} })
			t.expect(ok).toBe(false)
			t.expect(reason).toBe("pass")
			t.expect((DoorRules.check(req, { passes = { ExecutiveClub = true } }))).toBe(true)
			t.expect((DoorRules.check(req, {}))).toBe(false)
		end)
		t.it("requires every listed condition", function()
			local req = { minRank = 2, employed = true, pass = "ExecutiveClub" }
			local full = { rank = 2, employed = true, passes = { ExecutiveClub = true } }
			t.expect((DoorRules.check(req, full))).toBe(true)
			local _, r1 = DoorRules.check(req, { rank = 2, employed = true, passes = {} })
			t.expect(r1).toBe("pass")
			local _, r2 = DoorRules.check(req, { rank = 1, employed = true, passes = { ExecutiveClub = true } })
			t.expect(r2).toBe("rank")
		end)
		t.it("every World door with requirements evaluates against a crafted student and an MD", function()
			local student = { rank = 0, employed = false, data = { campus = { offer = false } }, passes = {} }
			local md =
				{ rank = 5, employed = true, data = { campus = { offer = true } }, passes = { ExecutiveClub = true } }
			for id, door in World.doors do
				if door.requires then
					local okMd = DoorRules.check(door.requires, md)
					if not okMd then
						error("an employed MD with every pass is locked out of " .. id)
					end
					local okStudent, reason = DoorRules.check(door.requires, student)
					t.expect(okStudent).toBe(false)
					t.expect(type(DoorRules.lockedText(door, reason))).toBe("string")
				end
			end
		end)
	end)

	t.describe("DoorRules doors and text", function()
		t.it("classifies every World door", function()
			for id, door in World.doors do
				local kind = DoorRules.kind(door)
				if kind == nil then
					error("door " .. id .. " has no kind")
				end
				if door.company or door.picker then
					t.expect(kind == "company" or kind == "picker").toBeTruthy()
				end
			end
			t.expect(DoorRules.kind(World.doors.door_campus_subway)).toBe("ride")
			t.expect(DoorRules.kind(World.doors.door_street_galleria)).toBe("target")
			t.expect(DoorRules.kind(World.doors.door_street_tower_mg_freeman)).toBe("company")
			t.expect(DoorRules.kind(World.doors.door_street_tower_pe_tower)).toBe("picker")
			t.expect(DoorRules.kind(nil)).toBeNil()
		end)
		t.it("uses the door's lockedText, else a reason line", function()
			t.expect(DoorRules.lockedText(World.doors.door_street_club, "pass")).toBe("Executive Club members only.")
			t.expect(DoorRules.lockedText(World.doors.door_street_rooftop, "employed"))
				.toBe(Text.get("locked_employed"))
			t.expect(DoorRules.lockedText(nil, nil)).toBe(Text.get("door_locked_default"))
		end)
		t.it("formats text with placeholders", function()
			t.expect(Text.format("opening_soon_named", { name = "Anaeio" })).toBe("Anaeio is opening soon.")
			t.expect(Text.format("visitor_at", {})).toBe("Visitor · {name}")
			t.expect(Text.get("no_such_key", "fallback")).toBe("fallback")
		end)
		t.it("labels every zone", function()
			for zoneId in World.zones do
				local label = DoorRules.zoneLabel(zoneId)
				t.expect(#label > 0).toBeTruthy()
				t.expect(label ~= zoneId).toBeTruthy()
			end
			t.expect(DoorRules.zoneLabel("street")).toBe("Wall Street")
			t.expect(DoorRules.zoneLabel(nil)).toBe("")
		end)
		t.it("gates campus -> Street with the subway's rules", function()
			local ok, text = DoorRules.streetAccess({ rank = 0, data = { campus = { offer = false } } })
			t.expect(ok).toBe(false)
			t.expect(text).toBe(World.doors.door_campus_subway.lockedText)
			t.expect((DoorRules.streetAccess({ rank = 0, data = { campus = { offer = true } } }))).toBe(true)
			t.expect((DoorRules.streetAccess({ rank = 1 }))).toBe(true)
		end)
	end)

	t.describe("DoorRules exits", function()
		t.it("returns to the remembered entry for the same company", function()
			local mem = { companyId = "harrow_williams", anchor = "street_tower_middle_market_front" }
			t.expect(DoorRules.resolveExit(mem, "harrow_williams")).toBe("street_tower_middle_market_front")
		end)
		t.it("falls back to the company's own tower when the memory is for another company", function()
			local mem = { companyId = "goldfield_saxe", anchor = "street_tower_goldfield_saxe_front" }
			t.expect(DoorRules.resolveExit(mem, "mg_freeman")).toBe("street_tower_mg_freeman_front")
		end)
		t.it("falls back to the tenant's tower for picker tenants", function()
			t.expect(DoorRules.resolveExit(nil, "krk")).toBe("street_tower_pe_tower_front")
			t.expect(DoorRules.resolveExit({ companyId = "krk" }, "krk")).toBe("street_tower_pe_tower_front")
		end)
		t.it("falls back to the plaza for a company with no tower", function()
			t.expect(DoorRules.resolveExit(nil, "nowhere_inc")).toBe(DoorRules.FALLBACK_EXIT)
			t.expect(World.anchors[DoorRules.FALLBACK_EXIT] ~= nil).toBeTruthy()
		end)
		t.it("every company in the towers resolves to an anchor that exists", function()
			for _, tower in World.towers do
				local ids = { tower.company }
				for _, id in tower.picker or {} do
					table.insert(ids, id)
				end
				for _, id in ids do
					local anchor = DoorRules.resolveExit(nil, id)
					if World.anchors[anchor] == nil then
						error(id .. " exits to unknown anchor " .. anchor)
					end
				end
			end
		end)
		t.it("finds towers by company and by tenant", function()
			t.expect((DoorRules.towerFor("mg_freeman") :: any).id).toBe("mg_freeman")
			t.expect((DoorRules.towerFor("lotus_wealth") :: any).id).toBe("wealth_house")
			t.expect(DoorRules.towerFor("nobody")).toBeNil()
		end)
	end)

	t.describe("DoorRules employees and visitors", function()
		local career = { companyId = "mg_freeman", rank = 1, status = "active" }
		t.it("knows employment from career data", function()
			t.expect(DoorRules.isEmployedCareer(career)).toBe(true)
			t.expect(DoorRules.isEmployedCareer({ companyId = "mg_freeman", rank = 2, status = "fired" })).toBe(false)
			t.expect(DoorRules.isEmployedCareer({ companyId = "mg_freeman", rank = 0 })).toBe(false)
			t.expect(DoorRules.isEmployedCareer({ rank = 2 })).toBe(false)
			t.expect(DoorRules.isEmployedCareer(nil)).toBe(false)
			t.expect(DoorRules.isEmployedCareer({ companyId = "anaeio" })).toBe(true) -- rank not replicated yet
		end)
		t.it("employees of the company are not visitors; everyone else is", function()
			t.expect(DoorRules.isEmployee(career, "mg_freeman")).toBe(true)
			t.expect(DoorRules.isEmployee(career, "goldfield_saxe")).toBe(false)
			t.expect(DoorRules.isEmployee(nil, "mg_freeman")).toBe(false)
			t.expect(DoorRules.isEmployee({ companyId = "mg_freeman", rank = 3, status = "fired" }, "mg_freeman"))
				.toBe(false)
			t.expect(DoorRules.isEmployee(career, nil)).toBe(false)
		end)
		t.it("honours an active merger pair in both directions", function()
			local events = {
				corporate = {
					id = "merger_mania",
					startsAt = 100,
					endsAt = 400,
					data = { companies = { "mg_freeman", "evermoor" } },
				},
			}
			t.expect(DoorRules.isEmployee(career, "evermoor", events, 200)).toBe(true)
			local evermoorCareer = { companyId = "evermoor", rank = 2, status = "probation" }
			t.expect(DoorRules.isEmployee(evermoorCareer, "mg_freeman", events, 200)).toBe(true)
			t.expect(DoorRules.isEmployee(career, "goldfield_saxe", events, 200)).toBe(false)
		end)
		t.it("ignores merger pairs outside their window and other events", function()
			local events = {
				corporate = {
					id = "merger_mania",
					startsAt = 100,
					endsAt = 400,
					data = { pair = { "mg_freeman", "krk" } },
				},
				market = { id = "crash", startsAt = 0, endsAt = 1000, data = { companies = { "mg_freeman", "a17z" } } },
			}
			t.expect(DoorRules.isEmployee(career, "krk", events, 50)).toBe(false)
			t.expect(DoorRules.isEmployee(career, "krk", events, 400)).toBe(false)
			t.expect(DoorRules.isEmployee(career, "krk", events, 399)).toBe(true)
			t.expect(DoorRules.isEmployee(career, "a17z", events, 200)).toBe(false)
		end)
		t.it("accepts the other merger data shapes", function()
			local shapes = {
				{ a = "mg_freeman", b = "krk" },
				{ companyA = "krk", companyB = "mg_freeman" },
				{ pairs = { { "sequel", "a17z" }, { "krk", "mg_freeman" } } },
			}
			for _, data in shapes do
				local events = { corporate = { id = "merger_mania", data = data } }
				t.expect(DoorRules.isEmployee(career, "krk", events, nil)).toBe(true)
				t.expect(DoorRules.partnersOf("mg_freeman", events)["krk"]).toBe(true)
			end
			local upcoming =
				{ upcoming = { { id = "merger_mania", startsAt = 900, data = { pair = { "mg_freeman", "krk" } } } } }
			t.expect(DoorRules.isEmployee(career, "krk", upcoming, 100)).toBe(false)
			t.expect(DoorRules.isEmployee(career, "krk", upcoming, nil)).toBe(false)
			t.expect(DoorRules.isEmployee(career, "krk", "garbage", 100)).toBe(false)
		end)
	end)

	t.describe("DoorRules stages and safety", function()
		t.it("puts students on campus and anyone with a career on the Street", function()
			t.expect(DoorRules.stageFor({ employed = false, rank = 0 })).toBe("campus")
			t.expect(DoorRules.stageFor(nil)).toBe("campus")
			t.expect(DoorRules.stageFor({ employed = true })).toBe("street")
			t.expect(DoorRules.stageFor({ employed = false, rank = 2 })).toBe("street")
			t.expect(DoorRules.stageFor({ employed = false, rank = 0, status = "fired" })).toBe("street")
			t.expect(World.spawns[DoorRules.STAGE_SPAWNS.campus] ~= nil).toBeTruthy()
			t.expect(World.spawns[DoorRules.STAGE_SPAWNS.street] ~= nil).toBeTruthy()
		end)
		t.it("knows the campus side", function()
			t.expect(DoorRules.isCampusSide("campus")).toBe(true)
			t.expect(DoorRules.isCampusSide("dorm")).toBe(true)
			t.expect(DoorRules.isCampusSide("subway")).toBe(true)
			t.expect(DoorRules.isCampusSide("street")).toBe(false)
			t.expect(DoorRules.isCampusSide("offices")).toBe(false)
			t.expect(DoorRules.isCampusSide(nil)).toBe(false)
		end)
		t.it("returns fallers at once and wanderers after 3 s out of zone", function()
			local action = DoorRules.safety(-60, "street", nil, 10)
			t.expect(action).toBe("fall")
			local a1, since = DoorRules.safety(5, nil, nil, 10)
			t.expect(a1).toBeNil()
			t.expect(since).toBe(10)
			local a2, since2 = DoorRules.safety(5, nil, since, 12.5)
			t.expect(a2).toBeNil()
			t.expect(since2).toBe(10)
			local a3 = DoorRules.safety(5, nil, since2, 13.5)
			t.expect(a3).toBe("out_of_zone")
			local a4, since4 = DoorRules.safety(5, "street", since2, 13.5)
			t.expect(a4).toBeNil()
			t.expect(since4).toBeNil()
		end)
		t.it("flags only implausible horizontal jumps", function()
			local from = Vector3.new(0, 0, 0)
			t.expect(DoorRules.impossibleMove(from, Vector3.new(18, 0, 0), 1)).toBe(false)
			t.expect(DoorRules.impossibleMove(from, Vector3.new(0, -400, 0), 1)).toBe(false) -- falling is fine
			t.expect(DoorRules.impossibleMove(from, Vector3.new(60, 0, 0), 0.1)).toBe(false) -- below the min jump
			t.expect(DoorRules.impossibleMove(from, Vector3.new(500, 0, 0), 1)).toBe(true)
			t.expect(DoorRules.impossibleMove(from, Vector3.new(500, 0, 0), 5)).toBe(false)
		end)
	end)

	t.describe("DoorRules prompt texts and client state", function()
		t.it("labels every kind of World door", function()
			local action, object = DoorRules.promptText(World.doors.door_street_galleria)
			t.expect(action).toBe(Text.get("door_enter"))
			t.expect(object).toBe("The Galleria")
			local exitAction, exitObject = DoorRules.promptText(World.doors.door_galleria_exit)
			t.expect(exitAction).toBe(Text.get("door_exit"))
			t.expect(exitObject).toBe("Wall Street")
			local campusExit, campusObject = DoorRules.promptText(World.doors.door_dorm_exit)
			t.expect(campusExit).toBe(Text.get("door_exit"))
			t.expect(campusObject).toBe("Eastbridge")
			local ride, line = DoorRules.promptText(World.doors.door_campus_subway)
			t.expect(ride).toBe(Text.get("door_board"))
			t.expect(line).toBe("Subway: Downtown")
			local tower, name = DoorRules.promptText(World.doors.door_street_tower_mg_freeman)
			t.expect(tower).toBe(Text.get("door_enter"))
			t.expect(name).toBe("MG Freeman")
			local picker, plaza = DoorRules.promptText(World.doors.door_street_tower_middle_market)
			t.expect(picker).toBe(Text.get("door_enter"))
			t.expect(plaza).toBe("Middle Market Plaza")
			for id, door in World.doors do
				local a, o = DoorRules.promptText(door)
				if a == "" or o == "" then
					error("door " .. id .. " has an empty prompt text")
				end
			end
		end)
		t.it("labels the office template doors", function()
			local a1, o1 = DoorRules.officeDoorText("exit")
			t.expect(a1).toBe(Text.get("door_exit"))
			t.expect(o1).toBe(Text.get("office_exit"))
			local a2, o2 = DoorRules.officeDoorText("to_lobby")
			t.expect(a2).toBe(Text.get("office_elevator"))
			t.expect(o2).toBe(Text.get("office_to_lobby"))
			t.expect(DoorRules.OFFICE_DOORS.exit).toBe(true)
			t.expect(DoorRules.OFFICE_DOORS.to_lobby).toBe(true)
			t.expect(DoorRules.OFFICE_DOORS.elevators).toBeNil()
			for _, kind in World.templateMarkers.OfficeDoor do
				t.expect(DoorRules.OFFICE_DOORS[kind]).toBe(true)
			end
		end)
		t.it("builds requirement state from replicated data", function()
			local student = DoorRules.stateFromData({ career = { rank = 0 }, campus = { offer = true } })
			t.expect(student.rank).toBe(0)
			t.expect(student.employed).toBe(false)
			t.expect((DoorRules.check(World.doors.door_campus_subway.requires, student))).toBe(true)
			t.expect((DoorRules.check(World.doors.door_street_apartments.requires, student))).toBe(false)
			local analyst = DoorRules.stateFromData({
				career = { rank = 1, companyId = "mg_freeman", status = "active" },
				entitlements = { passes = { "ExecutiveClub" } },
			})
			t.expect(analyst.employed).toBe(true)
			t.expect((DoorRules.check(World.doors.door_street_apartments.requires, analyst))).toBe(true)
			t.expect((DoorRules.check(World.doors.door_street_club.requires, analyst))).toBe(true)
			local mapPasses = DoorRules.stateFromData({ entitlements = { passes = { ExecutiveClub = true } } })
			t.expect((mapPasses.passes :: any).ExecutiveClub).toBe(true)
			local empty = DoorRules.stateFromData(nil)
			t.expect(empty.rank).toBe(0)
			t.expect((DoorRules.check(World.doors.door_street_club.requires, empty))).toBe(false)
			-- data read through a lazy view (the client's Store proxy)
			local lazy = setmetatable({}, {
				__index = function(_, k)
					return if k == "campus" then { offer = { companyId = "sterling_vance" } } else nil
				end,
			})
			t.expect((DoorRules.check(World.doors.door_campus_subway.requires, DoorRules.stateFromData(lazy))))
				.toBe(true)
		end)
	end)

	t.describe("DoorRules visitor prompts and badge", function()
		local career = { companyId = "mg_freeman", rank = 2, status = "active" }
		local merger = {
			corporate = {
				id = "merger_mania",
				startsAt = 0,
				endsAt = 600,
				data = { companies = { "mg_freeman", "evermoor" } },
			},
		}
		t.it("shows EmployeesOnly prompts to employees and merger partners only", function()
			t.expect(DoorRules.promptAllowed(career, true, "mg_freeman")).toBe(true)
			t.expect(DoorRules.promptAllowed(career, true, "goldfield_saxe")).toBe(false)
			t.expect(DoorRules.promptAllowed(nil, true, "goldfield_saxe")).toBe(false)
			t.expect(DoorRules.promptAllowed(career, true, "evermoor", merger, 100)).toBe(true)
			t.expect(DoorRules.promptAllowed(career, true, "evermoor", merger, 700)).toBe(false)
			-- prompts that aren't EmployeesOnly, or aren't in an office, always show
			t.expect(DoorRules.promptAllowed(nil, false, "goldfield_saxe")).toBe(true)
			t.expect(DoorRules.promptAllowed(nil, nil, "goldfield_saxe")).toBe(true)
			t.expect(DoorRules.promptAllowed(nil, true, nil)).toBe(true)
			-- a fired player is a visitor in their old office
			t.expect(
				DoorRules.promptAllowed({ companyId = "mg_freeman", rank = 2, status = "fired" }, true, "mg_freeman")
			)
				.toBe(false)
		end)
		t.it("badges visitors in another company's office", function()
			t.expect(DoorRules.visitorBadge(career, "goldfield_saxe", "Goldfield Saxe"))
				.toBe("Visitor · Goldfield Saxe")
			t.expect(DoorRules.visitorBadge(career, "goldfield_saxe", nil)).toBe(Text.get("visitor"))
			t.expect(DoorRules.visitorBadge(career, "mg_freeman", "MG Freeman")).toBeNil()
			t.expect(DoorRules.visitorBadge(career, nil, nil)).toBeNil()
			t.expect(DoorRules.visitorBadge(career, "evermoor", "Evermoor", merger, 100)).toBeNil()
			t.expect(DoorRules.visitorBadge(career, "evermoor", "Evermoor", merger, 900)).toBe("Visitor · Evermoor")
			t.expect(DoorRules.visitorBadge(nil, "mg_freeman", "MG Freeman")).toBe("Visitor · MG Freeman")
		end)
	end)
end
