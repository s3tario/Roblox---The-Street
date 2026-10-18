local Shared = game:GetService("ReplicatedStorage").Shared
local Review = require(Shared.Logic.Review)
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)

return function(t)
	t.describe("bands at their edges", function()
		t.it("maps scores to bands exactly at the thresholds", function()
			t.expect(Review.band(100)).toBe("star")
			t.expect(Review.band(85)).toBe("star")
			t.expect(Review.band(84)).toBe("on_track")
			t.expect(Review.band(70)).toBe("on_track")
			t.expect(Review.band(69)).toBe("under")
			t.expect(Review.band(55)).toBe("under")
			t.expect(Review.band(54)).toBe("probation")
			t.expect(Review.band(40)).toBe("probation")
			t.expect(Review.band(39)).toBe("critical")
			t.expect(Review.band(0)).toBe("critical")
		end)
		t.it("orders bands", function()
			t.expect(Review.atLeast("star", "on_track")).toBeTruthy()
			t.expect(Review.atLeast("on_track", "on_track")).toBeTruthy()
			t.expect(Review.atLeast("under", "on_track")).toBeFalsy()
			t.expect(Review.bandOrder("critical")).toBe(1)
		end)
	end)

	t.describe("score", function()
		t.it("weights the components 35/25/25/15", function()
			t.expect(Review.score({ investment = 100, risk = 0, work = 0, reputation = 0 })).toBe(35)
			t.expect(Review.score({ investment = 0, risk = 100, work = 0, reputation = 0 })).toBe(25)
			t.expect(Review.score({ investment = 0, risk = 0, work = 100, reputation = 0 })).toBe(25)
			t.expect(Review.score({ investment = 0, risk = 0, work = 0, reputation = 100 })).toBe(15)
			t.expect(Review.score({ investment = 70, risk = 70, work = 70, reputation = 70 })).toBe(70)
		end)
		t.it("lands exactly on a band edge when components do", function()
			local r = Review.score({ investment = 85, risk = 85, work = 85, reputation = 85 })
			t.expect(Review.band(r)).toBe("star")
			local below = Review.score({ investment = 84, risk = 84, work = 84, reputation = 84 })
			t.expect(Review.band(below)).toBe("on_track")
		end)
	end)

	t.describe("investment component", function()
		t.it("is neutral 60 with no book and 55 with an idle book", function()
			local noBook, kind1 = Review.investmentScore(nil, false)
			t.expect(noBook).toBe(60)
			t.expect(kind1).toBe("no_book")
			local idle, kind2 = Review.investmentScore({ trades = 0 }, true)
			t.expect(idle).toBe(55)
			t.expect(kind2).toBe("idle")
		end)
		t.it("rewards beating the benchmark and penalises drawdown", function()
			local good =
				Review.investmentScore({ trades = 5, excess = 0.03, maxDrawdown = 0.01, volatility = 0.01 }, true)
			local flat = Review.investmentScore({ trades = 5, excess = 0, maxDrawdown = 0.01, volatility = 0.01 }, true)
			local deep = Review.investmentScore({ trades = 5, excess = 0, maxDrawdown = 0.15, volatility = 0.01 }, true)
			t.expect(good).toBeGreaterThan(flat)
			t.expect(deep).toBeLessThan(flat)
		end)
		t.it("is relative to the benchmark (a crash that hits everyone is not punished)", function()
			local crash = Review.investmentScore({ trades = 3, twr = -0.2, benchReturn = -0.2 }, true)
			local calm = Review.investmentScore({ trades = 3, twr = 0.01, benchReturn = 0.01 }, true)
			t.expect(crash).toBe(calm)
		end)
		t.it("ignores NaN and infinite metrics", function()
			local s = Review.investmentScore({ trades = 2, excess = 0 / 0, maxDrawdown = math.huge }, true)
			t.expect(s).toBeBetween(0, 100)
		end)
	end)

	t.describe("evaluate", function()
		t.it("uses the alternative route for great work with clean risk", function()
			local r = Review.evaluate({
				hasBook = true,
				metrics = { trades = 4, excess = -0.05, violations = 0 },
				work = { count = 10, qualitySum = 900 },
				recentViolations = 0,
				meetsDress = true,
			})
			t.expect(r.alternative).toBeTruthy()
			t.expect(r.components.investment).toBe(70)
		end)
		t.it("no work at all scores the work component low", function()
			local r = Review.evaluate({ hasBook = false })
			t.expect(r.components.work).toBe(15)
			t.expect(r.investmentKind).toBe("no_book")
		end)
		t.it("risk violations pull the risk component down", function()
			local clean = Review.riskScore({ trades = 3, violations = 0 }, true)
			local dirty = Review.riskScore({ trades = 3, violations = 2 }, true)
			t.expect(dirty).toBe(clean - 40)
		end)
	end)

	t.describe("pay", function()
		local analyst = Tracks.role("ib_analyst") :: Tracks.RoleDef
		t.it("pays salary x payMult and the bonus by band", function()
			local mg = Companies.get("mg_freeman")
			local star = Review.pay(analyst, mg, "star")
			local onTrack = Review.pay(analyst, mg, "on_track")
			local under = Review.pay(analyst, mg, "under")
			t.expect(star.salary).toBe(analyst.salary)
			t.expect(star.bonus).toBe(math.floor(analyst.bonus * 1.5 + 0.5))
			t.expect(onTrack.bonus).toBe(analyst.bonus)
			t.expect(under.bonus).toBe(math.floor(analyst.bonus * 0.5 + 0.5))
			local fired = Review.pay(analyst, mg, "critical", { fired = true })
			t.expect(fired.bonus).toBe(0)
			t.expect(fired.salary).toBe(analyst.salary)
		end)
		t.it("applies company pay multipliers and event bonus multipliers", function()
			local elite = Review.pay(analyst, Companies.get("evermoor"), "on_track")
			local regional = Review.pay(analyst, Companies.get("sterling_vance"), "on_track")
			t.expect(elite.salary).toBe(math.floor(analyst.salary * 1.15 + 0.5))
			t.expect(regional.salary).toBe(math.floor(analyst.salary * 0.8 + 0.5))
			local season = Review.pay(analyst, Companies.get("mg_freeman"), "on_track", { bonusMult = 2 })
			t.expect(season.bonus).toBe(analyst.bonus * 2)
		end)
		t.it("is calibrated to about 30% of the hourly salary scale (spec §11)", function()
			local scale = { 8000, 15000, 25000, 32000, 45000 }
			for rank, perHour in scale do
				local role = Tracks.rankDef("ib", rank) :: Tracks.RoleDef
				local weekly = role.salary + role.bonus
				local hourly = weekly * 60 / 40
				t.expect(hourly / perHour).toBeBetween(0.27, 0.33)
			end
		end)
		t.it("living cost is small and eased by Discipline", function()
			local mg = Companies.get("mg_freeman")
			local low = Review.livingCost(analyst, mg, 1)
			local high = Review.livingCost(analyst, mg, 99)
			t.expect(low).toBeGreaterThan(high)
			t.expect(low).toBeLessThan(analyst.salary * 0.15)
		end)
	end)

	t.describe("dialogue", function()
		local base = {
			seed = "p1:3",
			outcome = "keep_going",
			band = "on_track",
			components = { investment = 80, risk = 90, work = 50, reputation = 60 },
			investmentKind = "traded",
			workCount = 3,
			vars = { name = "Maya", boss = "Catherine Ashby", company = "MG Freeman", newTitle = "Associate" },
		}
		t.it("is deterministic per seed and fills placeholders", function()
			local a = Review.dialogue(base)
			local b = Review.dialogue(base)
			t.expect(#a).toBe(#b)
			for i, line in a do
				t.expect(line).toBe(b[i])
				t.expect(string.find(line, "{", 1, true)).toBeNil()
			end
		end)
		t.it("marks where the outcome lines begin", function()
			local lines, at = Review.dialogue(base)
			t.expect(at).toBeBetween(2, #lines)
			local promoted = table.clone(base)
			promoted.outcome = "promoted"
			local pLines, pAt = Review.dialogue(promoted)
			t.expect(pLines[pAt]).toContain("Associate")
		end)
		t.it("varies with the outcome", function()
			local promoted = table.clone(base)
			promoted.outcome = "promoted"
			local fired = table.clone(base)
			fired.outcome = "fired"
			fired.band = "critical"
			fired.fireReason = "critical"
			local lines1 = table.concat(Review.dialogue(promoted), "|")
			local lines2 = table.concat(Review.dialogue(fired), "|")
			t.expect(lines1).never(lines2)
			t.expect(lines2).toContain("Career Services")
		end)
		t.it("uses the lifeline line when the Alumni Lifeline saves the player", function()
			local saved = table.clone(base)
			saved.outcome = "warning"
			saved.band = "critical"
			saved.lifeline = true
			t.expect(table.concat(Review.dialogue(saved), "|")).toContain("alumni network")
		end)
		t.it("says 'Come back dressed for the role' when the outfit blocks a promotion", function()
			local blocked = table.clone(base)
			blocked.blocked = "outfit"
			blocked.vars = table.clone(base.vars)
			blocked.vars.need = 4
			t.expect(table.concat(Review.dialogue(blocked), "|")).toContain("Come back dressed for the role")
		end)
		t.it("calls out an idle book when investment is the weak spot", function()
			local idle = table.clone(base)
			idle.components = { investment = 40, risk = 90, work = 85, reputation = 75 }
			idle.investmentKind = "idle"
			local text = table.concat(Review.dialogue(idle), "|")
			t.expect(string.find(text, "book", 1, true) ~= nil).toBeTruthy()
		end)
		t.it("forced dismissals are phone calls with their own openings", function()
			local neutral = { investment = 65, risk = 65, work = 65, reputation = 65 }
			local layoff = table.clone(base)
			layoff.mode = "layoff"
			layoff.outcome = "fired"
			layoff.band = "under"
			layoff.fireReason = "mass"
			layoff.components = neutral
			local lines = Review.dialogue(layoff)
			t.expect(lines[1]).toContain("Catherine Ashby")
			t.expect(table.concat(lines, "|")).toContain("cutting headcount")
			local risk = table.clone(layoff)
			risk.mode = "discipline"
			risk.fireReason = "risk"
			local riskText = table.concat(Review.dialogue(risk), "|")
			t.expect(riskText).toContain("Risk")
			t.expect(riskText).toContain("risk-limit violation")
			-- the Lifeline saves a laid-off player too
			local saved = table.clone(layoff)
			saved.lifeline = true
			saved.outcome = "warning"
			t.expect(table.concat(Review.dialogue(saved), "|")).toContain("alumni network")
		end)
		t.it("every opening, outcome and closing line fills all of its placeholders", function()
			local D: any = Tracks.dialogue
			local vars = {
				name = "Maya",
				boss = "Catherine Ashby",
				company = "MG Freeman",
				title = "Analyst",
				newTitle = "Associate",
				score = 72,
				excess = "2.1%",
				need = 4,
				tier = "Rare",
				week = 3,
			}
			local function check(pool: any)
				for _, line in pool do
					local filled = string.gsub(line, "{([%w_]+)}", function(k: string): string
						t.expect(vars[k] ~= nil).toBeTruthy()
						return tostring(vars[k])
					end)
					t.expect(string.find(filled, "{", 1, true)).toBeNil()
				end
			end
			for _, group in { D.opening, D.strong, D.weak, D.outcome, D.blocked } do
				for _, pool in group do
					check(pool)
				end
			end
			check(D.closing)
			check(D.closing_fired)
		end)
	end)
end
