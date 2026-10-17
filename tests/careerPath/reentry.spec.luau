local Shared = game:GetService("ReplicatedStorage").Shared
local Rng = require(Shared.Util.Rng)
local reentry = require(Shared.Logic.Projects.reentry)

-- Answers every stage perfectly by reading the secret (what the server can do; the client never sees it).
local function perfect(stage: any): { [string]: any }
	local answers: { [string]: any } = {}
	if stage.kind == "mcq" then
		for qid, idx in stage.secret.answers do
			answers[qid] = idx
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
	return answers
end

return function(t)
	t.describe("shape", function()
		t.it("follows the project contract", function()
			t.expect(reentry.id).toBe("reentry")
			t.expect(type(reentry.new)).toBe("function")
			t.expect(type(reentry.view)).toBe("function")
			t.expect(type(reentry.act)).toBe("function")
			t.expect(type(reentry.score)).toBe("function")
		end)
		t.it("builds three stages (case study, risk review, interview) deterministically", function()
			local a = reentry.new(Rng.new(7))
			local b = reentry.new(Rng.new(7))
			t.expect(#a.stages).toBe(3)
			t.expect(a.stages[1].id).toBe("case_study")
			t.expect(a.stages[2].id).toBe("risk_review")
			t.expect(a.stages[3].id).toBe("interview")
			t.expect(a.stages[3].kind).toBe("dialogue")
			t.expect(a.stages[1].payload.questions[1].text).toBe(b.stages[1].payload.questions[1].text)
		end)
		t.it("never leaks the answers in the view", function()
			local s = reentry.new(Rng.new(3))
			local v = reentry.view(s)
			t.expect(v.stageIndex).toBe(1)
			t.expect(v.stageCount).toBe(3)
			t.expect(v.payload).toBeTruthy()
			t.expect((v.payload :: any).secret).toBeNil()
			for _, q in (v.payload :: any).questions do
				t.expect(q.correct).toBeNil()
				t.expect(#q.options).toBe(4)
			end
		end)
	end)

	t.describe("grading", function()
		t.it("passes with perfect answers", function()
			local s = reentry.new(Rng.new(11))
			local result
			for _ = 1, 3 do
				s, result = reentry.act(s, perfect(s.stages[s.stageIndex]), nil)
				t.expect(result.ok).toBeTruthy()
			end
			t.expect(result.done).toBeTruthy()
			t.expect(result.passed).toBeTruthy()
			t.expect(result.quality).toBe(100)
			t.expect(reentry.score(s).quality).toBe(100)
		end)
		t.it("fails with blank or garbage answers and explains why", function()
			local s = reentry.new(Rng.new(12))
			local r1
			s, r1 = reentry.act(s, nil, nil)
			t.expect(r1.score).toBe(0)
			t.expect(#r1.feedback).toBeGreaterThan(0)
			local r2
			s, r2 = reentry.act(s, { rr_limit = "two", [1] = 5 }, nil)
			t.expect(r2.score).toBe(0)
			local r3
			s, r3 = reentry.act(s, {}, nil)
			t.expect(r3.done).toBeTruthy()
			t.expect(r3.passed).toBeFalsy()
			local again
			s, again = reentry.act(s, {}, nil)
			t.expect(again.ok).toBeFalsy()
		end)
		t.it("Charisma adds a little to the interview", function()
			local s = reentry.new(Rng.new(21))
			s.stageIndex = 3
			local stage = s.stages[3]
			local answers: { [string]: string } = {}
			for lineId, opts in stage.secret.scores do
				for optId, sc in opts do
					if sc < 50 and sc > 0 then
						answers[lineId] = optId
						break
					end
				end
			end
			local plain = table.clone(s)
			plain.stages = { s.stages[1], s.stages[2], table.clone(stage) }
			local _, low = reentry.act(plain, answers, nil)
			local _, high = reentry.act(s, answers, { charismaBonus = 8 })
			t.expect(high.score).toBeGreaterThan(low.score)
		end)
	end)

	t.describe("work task modules", function()
		local fakeTask = {
			generate = function(_rng, _ctx)
				return { kind = "order", title = "Case", prompt = "Order these", items = { { id = "a", text = "A" } } }, {
					order = { "a" },
				}
			end,
			grade = function(secret, answers, _ctx)
				return { quality = if type(answers) == "table" and answers[1] == secret.order[1] then 90 else 10 }
			end,
		}
		t.it("uses reentry_case_study when the client can render it", function()
			local s = reentry.new(Rng.new(5), {
				tasks = { reentry_case_study = fakeTask },
				canRender = function(kind: string)
					return kind == "order"
				end,
			})
			t.expect(s.stages[1].taskId).toBe("reentry_case_study")
			t.expect(s.stages[1].kind).toBe("order")
			local _, r = reentry.act(s, { "a" }, { tasks = { reentry_case_study = fakeTask } })
			t.expect(r.score).toBe(90)
		end)
		t.it("falls back to the built-in stage when the payload can't be drawn", function()
			local s = reentry.new(Rng.new(5), {
				tasks = { reentry_case_study = fakeTask },
				canRender = function(kind: string)
					return kind == "mcq"
				end,
			})
			t.expect(s.stages[1].taskId).toBeNil()
			t.expect(s.stages[1].kind).toBe("mcq")
		end)
		t.it("refuses task payloads that can't be saved", function()
			local bad = {
				generate = function()
					return { kind = "mcq", fn = function() end }, {}
				end,
				grade = function()
					return { quality = 100 }
				end,
			}
			local s = reentry.new(Rng.new(5), {
				tasks = { reentry_case_study = bad },
				canRender = function()
					return true
				end,
			})
			t.expect(s.stages[1].taskId).toBeNil()
		end)
	end)
end
